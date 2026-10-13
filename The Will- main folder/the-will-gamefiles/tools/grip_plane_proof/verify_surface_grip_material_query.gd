extends SceneTree

## Closed analytical boxes exercise the real TriangleMesh BVH and production
## material query. No character, CSG, saved weapon mutation or grip solve runs.
const SurfaceQuery = preload("res://runtime/player/grip/grip_surface_query.gd")
const GripSolver = preload("res://runtime/player/grip/surface_driven_grip_solver.gd")
const CAP_M := 0.00048
const GAP_TOLERANCE_M := 0.000002
var _checks := 0
var _failures: Array[String] = []
var _observations: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_usec()
	var ordinary := _box(Vector3(0.01, 0.01, 0.01))
	var thin := _box(Vector3(0.00005, 0.01, 0.01))
	var separated := _combine(_box(Vector3(0.005, 0.01, 0.01), Vector3(-0.005, 0.0, 0.0)),
		_box(Vector3(0.005, 0.01, 0.01), Vector3(0.025, 0.0, 0.0)))
	_check(ordinary.get("valid", false) and thin.get("valid", false) and separated.get("valid", false), "closed box native BVHs build")
	if ordinary.get("valid", false) and thin.get("valid", false) and separated.get("valid", false):
		var frames: Array[Transform3D] = [Transform3D.IDENTITY,
			Transform3D(Basis(Vector3(0.3, 1.0, -0.2).normalized(), 0.71), Vector3(0.4, -0.2, 0.1))]
		for frame_index: int in frames.size():
			var frame := frames[frame_index]
			var suffix := " / rigid frame %d" % frame_index
			_case(ordinary, frame, Vector3(-0.012, 0.0011, 0.0017), Vector3.RIGHT,
				"gap", 0.002, "outside facing toward material" + suffix)
			_case(ordinary, frame, Vector3(0.0101, 0.0011, 0.0017), Vector3.RIGHT,
				"outside", 0.0, "outside facing away with buried ray start inside" + suffix)
			_case(ordinary, frame, Vector3(-0.0101, 0.0011, 0.0017), Vector3.LEFT,
				"outside", 0.0, "opposite outside face pointing away" + suffix)
			_case(ordinary, frame, Vector3(-0.0098, 0.0011, 0.0017), Vector3.RIGHT,
				"gap", -0.0002, "inside allowed directional depth" + suffix)
			_case(ordinary, frame, Vector3(-0.0094, 0.0011, 0.0017), Vector3.RIGHT,
				"over_cap", 0.0, "inside deeper than permitted flesh" + suffix)
			_case(ordinary, frame, Vector3(-0.0095, 0.0011, 0.0017), Vector3.RIGHT,
				"gap", -0.0005, "exact over-cap entry remains measurable inside probe reach" + suffix)
			_case(thin, frame, Vector3(0.0002, 0.0011, 0.0017), Vector3.RIGHT,
				"outside", 0.0, "thin solid entirely behind actual skin point" + suffix)
			_case(thin, frame, Vector3(0.0002, 0.0011, 0.0017), Vector3.LEFT,
				"gap", 0.00015, "same thin solid ahead of reversed normal" + suffix)
			_case(separated, frame, Vector3(0.0005737, 0.0011, 0.0017), Vector3.RIGHT,
				"gap", 0.0194263, "skin outside between separate walls despite buried origin inside near wall" + suffix)
			_case(ordinary, frame, Vector3(-0.0101, 0.0011, 0.0017), Vector3.UP,
				"outside", 0.0, "outside tangent ray misses material" + suffix)
			_case(ordinary, frame, Vector3(-0.0101, 0.0011, 0.0017), Vector3(0.001, 1.0, 0.0).normalized(),
				"outside", 0.0, "near-tangent ray clears finite solid before entering" + suffix)
			_case(ordinary, frame, Vector3(-0.01, 0.0011, 0.0017), Vector3.RIGHT,
				"gap", 0.0, "actual skin point on entry boundary" + suffix)
			_case(ordinary, frame, Vector3(-0.01002, 0.0011, 0.0017), Vector3.RIGHT,
				"gap", 0.00002, "outside boundary retains contact band" + suffix)
			_case(ordinary, frame, Vector3(-0.00998, 0.0011, 0.0017), Vector3.RIGHT,
				"gap", -0.00002, "inside boundary retains contact band" + suffix)
			# This query measures depth along the anatomical ray, not Euclidean
			# closest-point distance: an inside tangent ray remains conservative.
			_case(ordinary, frame, Vector3(-0.0098, 0.0011, 0.0017), Vector3.UP,
				"over_cap", 0.0, "inside tangent direction does not waive material limit" + suffix)
	var report := {"schema": "surface_grip_material_query_verification_v1", "ok": _failures.is_empty(),
		"checks": _checks, "failures": _failures, "observations": _observations,
		"elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"grip_solve_run": false, "production_save_written": false,
		"metric": "signed entry distance along anatomical skin normal; conservative lower bound when beyond probe"}
	var path := "C:/WORKSPACE/test_artifacts/verify_surface_grip_material_query_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write material query verifier output")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SURFACE_GRIP_MATERIAL_RESULT=" + path)
	print("SURFACE_GRIP_MATERIAL_SUMMARY=" + JSON.stringify({"ok": report.ok, "checks": _checks, "failures": _failures, "elapsed_ms": report.elapsed_ms}))
	quit(0 if report.ok else 1)


func _case(surface: Dictionary, frame: Transform3D, point: Vector3, normal: Vector3,
		expected_kind: String, expected_gap: float, label: String) -> void:
	var solver := GripSolver.new()
	solver.set("_surface", {"valid": true, "surfaces": {&"physical": surface}, "source_origin_id": surface.source_origin_id})
	solver.set("_weapon", frame)
	solver.set("_source_to_weapon", Transform3D.IDENTITY)
	solver.set("_reach", 0.2)
	solver.set("_metrics", {"native_surface_queries": 0})
	var sample := {"point_world": frame * point, "normal_world": (frame.basis * normal).normalized(), "cap_m": CAP_M}
	var observed: Dictionary = solver.call("_skin_material", sample)
	var hit := bool(observed.get("hit", false))
	var gap := float(observed.get("gap_m", INF))
	_observations.append({"label": label, "expected_kind": expected_kind, "expected_gap_m": expected_gap,
		"actual": observed, "native_surface_queries": solver.get("_metrics").get("native_surface_queries", 0)})
	if expected_kind == "outside":
		_check(not hit, label + "; no false penetration/contact")
	elif expected_kind == "gap":
		_check(hit and is_finite(gap), label + "; signed boundary found")
		_check(hit and absf(gap - expected_gap) <= GAP_TOLERANCE_M, label + "; expected gap %.9f, actual %.9f" % [expected_gap, gap])
		_check(not observed.get("depth_is_lower_bound", false), label + "; exact boundary is not replaced by a cap lower bound")
	elif expected_kind == "over_cap":
		_check(hit and gap < -CAP_M, label + "; physical overlap still rejected")
		_check(observed.get("depth_is_lower_bound", false), label + "; unreachable entry remains an explicit conservative bound")


func _box(half: Vector3, center: Vector3 = Vector3.ZERO) -> Dictionary:
	var vertices := PackedVector3Array([
		Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z),
		Vector3(half.x, half.y, -half.z), Vector3(-half.x, half.y, -half.z),
		Vector3(-half.x, -half.y, half.z), Vector3(half.x, -half.y, half.z),
		Vector3(half.x, half.y, half.z), Vector3(-half.x, half.y, half.z)])
	var indices := PackedInt32Array([0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7,
		0, 1, 5, 0, 5, 4, 3, 7, 6, 3, 6, 2, 0, 4, 7, 0, 7, 3, 1, 2, 6, 1, 6, 5])
	for index: int in vertices.size(): vertices[index] += center
	return SurfaceQuery._build_surface(vertices, indices)


func _combine(first: Dictionary, second: Dictionary) -> Dictionary:
	var vertices: PackedVector3Array = first.vertices_m.duplicate()
	var indices: PackedInt32Array = first.indices.duplicate()
	var offset := vertices.size()
	vertices.append_array(second.vertices_m)
	for index: int in second.indices: indices.append(index + offset)
	return SurfaceQuery._build_surface(vertices, indices)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error(label)
