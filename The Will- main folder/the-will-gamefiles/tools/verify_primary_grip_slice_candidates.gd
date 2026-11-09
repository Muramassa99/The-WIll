extends SceneTree

const Seat = preload("res://core/resolvers/primary_grip_seat_resolver.gd")
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for turns: float in [0.0, 1.5, -2.0]:
		for transformed: bool in [false, true]:
			var mesh := _mesh(turns, transformed)
			_compare(mesh, 0.01, "turns %s transformed %s" % [turns, transformed])
			_compare(mesh, 0.013, "between rings %s %s" % [turns, transformed])
	var broken := _mesh(0.0, false)
	broken.indices.resize(broken.indices.size() - 3)
	_compare(broken, 0.01, "open mesh")
	broken = _mesh(0.0, false)
	broken.indices[broken.indices.size() - 1] = broken.vertices.size() + 5
	_compare(broken, 0.01, "invalid late index remains visible")
	# A dense long Handle: check candidate count, without making the verifier
	# repeat the original billion-triangle workload.
	var dense := _mesh(30.0, true, 2160, 4.2)
	var span: Vector3 = dense.end - dense.start
	var count := int(ceil(span.length() / 0.001))
	var index: Dictionary = Seat._build_mesh_slice_candidates(
		dense.vertices, dense.indices, dense.start, span.normalized(), span.length(), count)
	var active: Dictionary = {}
	var tested := 0
	for station: int in range(count + 1):
		for offset: int in index.ends[station]: active.erase(offset)
		for offset: int in index.starts[station]: active[offset] = true
		tested += active.size()
	var exhaustive: int = (count + 1) * (dense.indices.size() / 3)
	_check(tested < exhaustive / 100, "dense Handle removes >99% of unrelated candidate visits")
	print("SLICE_CANDIDATES visits=", tested, " exhaustive=", exhaustive)
	for failure: String in failures: push_error(failure)
	print("SLICE_CANDIDATES_VERIFY: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func _compare(mesh: Dictionary, interval: float, label: String) -> void:
	var expected := _exhaustive(mesh, interval)
	var actual: Dictionary = Seat.build_mesh_slice_center_path(
		mesh.vertices, mesh.indices, mesh.start, mesh.end, interval)
	_check(bool(actual.valid) == bool(expected.valid), label + " validity")
	if not bool(expected.valid):
		_check(actual.get("error") == expected.get("error"), label + " error preserved")
		_check(actual.get("sample_index") == expected.get("sample_index"), label + " failing station preserved")
		return
	_check(actual.ratios == expected.ratios, label + " station ratios identical")
	_check(actual.centers_meters == expected.centers_meters, label + " exact contour centers identical")

func _exhaustive(mesh: Dictionary, interval: float) -> Dictionary:
	var span: Vector3 = mesh.end - mesh.start
	var normal := span.normalized()
	var count := maxi(int(ceil(span.length() / maxf(interval, 0.0001))), 1)
	var ratios := PackedFloat32Array()
	var centers := PackedVector3Array()
	for station: int in range(count + 1):
		var ratio := float(station) / float(count)
		var origin: Vector3 = mesh.start + span * ratio
		var result: Dictionary = Seat.resolve_mesh_plane_slice_center(mesh.vertices, mesh.indices, origin, normal)
		if not result.valid and result.error == "slice_contour_not_closed":
			result = Seat._resolve_singular_mesh_plane_slice_center(mesh.vertices, mesh.indices, origin, normal)
		if not result.valid:
			return {"valid": false, "error": result.error, "sample_index": station}
		ratios.append(ratio)
		centers.append(result.center_meters)
	return {"valid": Seat.sampled_path_is_valid(ratios, centers), "ratios": ratios, "centers_meters": centers}

func _mesh(turns: float, transformed: bool, spans: int = 30, length: float = 0.3) -> Dictionary:
	var transform := Transform3D.IDENTITY
	if transformed:
		transform = Transform3D(Basis(Vector3(1, 2, 3).normalized(), 0.83), Vector3(-2.7, 0.31, 0.22))
	var profile := PackedVector2Array([Vector2(-0.02, -0.015), Vector2(0.025, -0.01), Vector2(0.01, 0.03), Vector2(-0.015, 0.02)])
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for ring: int in range(spans + 1):
		var t := float(ring) / float(spans)
		var bend := Vector3(length * t, sin(t * PI) * 0.012, sin(t * TAU) * 0.008)
		for point: Vector2 in profile:
			var rotated := point.rotated(turns * TAU * t)
			vertices.append(transform * (bend + Vector3(0, rotated.x, rotated.y)))
	for ring: int in range(spans):
		for edge: int in range(4):
			var next := (edge + 1) % 4
			var a := ring * 4 + edge
			var b := ring * 4 + next
			indices.append_array(PackedInt32Array([a, b, b + 4, a, b + 4, a + 4]))
	indices.append_array(PackedInt32Array([0, 2, 1, 0, 3, 2]))
	var end_ring := spans * 4
	indices.append_array(PackedInt32Array([end_ring, end_ring + 1, end_ring + 2, end_ring, end_ring + 2, end_ring + 3]))
	return {"vertices": vertices, "indices": indices, "start": transform * Vector3.ZERO, "end": transform * Vector3(length, 0, 0)}

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
