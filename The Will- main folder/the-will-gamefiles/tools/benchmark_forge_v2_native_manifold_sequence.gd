extends SceneTree

const FIXTURE_PATH := "C:/WORKSPACE/godot_runs/forge_v2_exact_regional_fixture_v1.json"
const FIXTURE_FILE_SHA256 := "1fda9d2012131f72a1b3fbec9cb1d1174caf8351662b8f60d1b10ed9d2304415"
const FIXTURE_CANONICAL_SHA256 := "4b92d114ac472a98006bb70131ea28286e2b8689df5a7e2db52df2905a1705a0"
const EXTENSION_PATH := "res://native/forge_v2_manifold/forge_v2_manifold.gdextension"
const RESULT_DIRECTORY := "C:/WORKSPACE/godot_runs"
const WINDOW_SECONDS := 60.0
const MAX_STROKES := 1000
const HARD_STROKE_TIMEOUT_MS := 5000.0
const TRANSLATION_STEP_METERS := 0.004
const COLLISION_LAYER := 1 << 20

var _report: Dictionary = {
	"schema": "forge_v2_native_manifold_sequence_benchmark",
	"schema_version": 1,
	"proof_passed": false,
	"production_files_touched": false,
}
var _result_path := ""
var _sequence_mode := "chain"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_sequence_mode = OS.get_environment("FORGE_NATIVE_SEQUENCE_MODE").strip_edges().to_lower()
	if _sequence_mode not in ["chain", "bounded_workpiece"]:
		_sequence_mode = "chain"
	_result_path = RESULT_DIRECTORY.path_join(
		"benchmark_forge_v2_native_manifold_sequence_%s.json" % _sequence_mode
	)
	DirAccess.make_dir_recursive_absolute(RESULT_DIRECTORY)
	var fixture := _load_fixture()
	if not bool(fixture.get("ok", false)):
		_fail(String(fixture.get("error", "fixture load failed")))
		return
	var extension_resource: Resource = load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(&"ForgeV2ManifoldBoolean"):
		_fail("native extension did not load or register")
		return
	var backend: Object = ClassDB.instantiate(&"ForgeV2ManifoldBoolean")
	if backend == null:
		_fail("native backend could not be instantiated")
		return

	var base_vertices: PackedVector3Array = fixture.get("base_vertices", PackedVector3Array())
	var base_indices: PackedInt32Array = fixture.get("base_indices", PackedInt32Array())
	var stroke_vertices: PackedVector3Array = fixture.get("stroke_vertices", PackedVector3Array())
	var stroke_indices: PackedInt32Array = fixture.get("stroke_indices", PackedInt32Array())
	var reset_result: Dictionary = backend.call(
		"reset_mesh", base_vertices, base_indices
	) as Dictionary
	if not bool(reset_result.get("ok", false)):
		_fail("native state reset failed: %s" % String(reset_result.get("error_message", "unknown")))
		return

	var visual := MeshInstance3D.new()
	visual.name = "NativeSequenceVisual"
	root.add_child(visual)
	var body := StaticBody3D.new()
	body.name = "NativeSequenceCollision"
	body.collision_layer = COLLISION_LAYER
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = "NativeSequenceShape"
	body.add_child(collision)
	root.add_child(body)
	await process_frame
	await physics_frame

	var rows: Array[Dictionary] = []
	var run_start_us := Time.get_ticks_usec()
	var deadline_us := run_start_us + int(WINDOW_SECONDS * 1000000.0)
	var stop_reason := "max_strokes"
	for stroke_number in range(1, MAX_STROKES + 1):
		var stroke_start_us := Time.get_ticks_usec()
		if stroke_start_us >= deadline_us:
			stop_reason = "deadline_before_next_stroke"
			break
		var translation := _stroke_translation(stroke_number)
		var translated_vertices := _translated(stroke_vertices, translation)
		var native_start_us := Time.get_ticks_usec()
		var native_result: Dictionary = backend.call(
			"add_mesh", translated_vertices, stroke_indices
		) as Dictionary
		var native_end_us := Time.get_ticks_usec()
		if not bool(native_result.get("ok", false)):
			stop_reason = "native_failure"
			rows.append({
				"stroke": stroke_number,
				"stroke_start_us": stroke_start_us,
				"failure": String(native_result.get("error_message", "unknown")),
			})
			break
		var output_vertices: PackedVector3Array = native_result.get(
			"vertices", PackedVector3Array()
		)
		var output_indices: PackedInt32Array = native_result.get(
			"indices", PackedInt32Array()
		)

		var visual_start_us := Time.get_ticks_usec()
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = output_vertices
		arrays[Mesh.ARRAY_INDEX] = output_indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		visual.mesh = mesh
		var visual_end_us := Time.get_ticks_usec()

		var collision_start_us := Time.get_ticks_usec()
		var faces := PackedVector3Array()
		faces.resize(output_indices.size())
		for index_position in range(output_indices.size()):
			faces[index_position] = output_vertices[output_indices[index_position]]
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = false
		shape.set_faces(faces)
		collision.shape = shape
		var collision_end_us := Time.get_ticks_usec()

		await process_frame
		await physics_frame
		var physics_ready_us := Time.get_ticks_usec()
		var probe := _probe_newest_surface(body, output_vertices, output_indices)
		var stroke_end_us := Time.get_ticks_usec()
		var total_ms := float(stroke_end_us - stroke_start_us) / 1000.0
		var row := {
			"stroke": stroke_number,
			"revision": int(native_result.get("revision", -1)),
			"stroke_start_us": stroke_start_us,
			"native_start_us": native_start_us,
			"native_end_us": native_end_us,
			"visual_start_us": visual_start_us,
			"visual_end_us": visual_end_us,
			"collision_start_us": collision_start_us,
			"collision_end_us": collision_end_us,
			"physics_ready_us": physics_ready_us,
			"stroke_end_us": stroke_end_us,
			"start_from_run_ms": float(stroke_start_us - run_start_us) / 1000.0,
			"ready_from_run_ms": float(stroke_end_us - run_start_us) / 1000.0,
			"native_call_ms": float(native_end_us - native_start_us) / 1000.0,
			"native_pack_ms": float(native_result.get("pack_ms", INF)),
			"native_import_ms": float(native_result.get("import_ms", INF)),
			"native_boolean_ms": float(native_result.get("boolean_ms", INF)),
			"native_export_ms": float(native_result.get("export_ms", INF)),
			"native_commit_ms": float(native_result.get("commit_ms", INF)),
			"native_total_ms": float(native_result.get("total_native_ms", INF)),
			"visual_arraymesh_ms": float(visual_end_us - visual_start_us) / 1000.0,
			"collision_packet_ms": float(collision_end_us - collision_start_us) / 1000.0,
			"deferred_physics_wait_ms": float(physics_ready_us - collision_end_us) / 1000.0,
			"physics_probe_ms": float(stroke_end_us - physics_ready_us) / 1000.0,
			"release_to_targetable_ms": total_ms,
			"output_vertices": output_vertices.size(),
			"output_triangles": output_indices.size() / 3,
			"physics_probe_hit": bool(probe.get("hit", false)),
			"physics_probe_error_m": float(probe.get("error_m", INF)),
			"completed_before_deadline": stroke_end_us <= deadline_us,
		}
		rows.append(row)
		if total_ms > HARD_STROKE_TIMEOUT_MS:
			stop_reason = "hard_stroke_timeout"
			break
		if stroke_end_us >= deadline_us:
			stop_reason = "deadline_reached"
			break
		if stroke_number % 100 == 0:
			print("NATIVE_SEQUENCE_HEARTBEAT stroke=%d total_ms=%.3f triangles=%d" % [
				stroke_number,
				total_ms,
				output_indices.size() / 3,
			])

	var loop_end_us := Time.get_ticks_usec()
	_backfill_cycle_boundaries(rows)
	var completed_rows: Array[Dictionary] = []
	for row: Dictionary in rows:
		if bool(row.get("completed_before_deadline", false)):
			completed_rows.append(row)
	var final_state: Dictionary = backend.call("get_state_info") as Dictionary
	var metrics := _summarize_rows(completed_rows)
	var cycles := _cycle_samples(completed_rows)
	var full_window_reached := loop_end_us >= deadline_us
	var strict_spm: Variant = (
		float(completed_rows.size())
		if full_window_reached
		else null
	)
	var measured_seconds := float(loop_end_us - run_start_us) / 1000000.0
	var measured_spm := (
		float(completed_rows.size()) * 60.0 / measured_seconds
		if measured_seconds > 0.0
		else 0.0
	)
	var all_probes_hit := true
	for row: Dictionary in completed_rows:
		all_probes_hit = all_probes_hit and bool(row.get("physics_probe_hit", false))
	var gates := {
		"state_reset_and_all_completed_adds_succeeded": (
			bool(reset_result.get("ok", false))
			and stop_reason not in ["native_failure", "hard_stroke_timeout"]
		),
		"every_completed_revision_became_physically_targetable": all_probes_hit,
		"native_state_revision_matches_completed_strokes": (
			int(final_state.get("revision", -1)) == completed_rows.size() + 1
			or not rows.is_empty() and not bool(rows[-1].get("completed_before_deadline", true))
		),
		"at_least_ten_strokes_were_measured": completed_rows.size() >= 10,
	}
	var proof_passed := true
	for value: Variant in gates.values():
		proof_passed = proof_passed and bool(value)
	_report.merge({
		"outcome": "pass" if proof_passed else "fail",
		"proof_passed": proof_passed,
		"stop_reason": stop_reason,
		"window_seconds": WINDOW_SECONDS,
		"max_strokes": MAX_STROKES,
		"completed_strokes_within_window": completed_rows.size(),
		"strict_window_spm": strict_spm,
		"strict_window_spm_status": "observed" if full_window_reached else "cap_reached_before_window",
		"measured_duration_seconds": measured_seconds,
		"measured_duration_spm": measured_spm,
		"fixture_file_sha256": FIXTURE_FILE_SHA256,
		"sequence_mode": _sequence_mode,
		"backend": backend.call("get_backend_info"),
		"reset": _strip_arrays(reset_result),
		"final_state": final_state,
		"metrics": metrics,
		"head_and_tail_cycles": cycles,
		"rows": rows,
		"gates": gates,
		"scope": {
			"native_persistent_union": true,
			"arraymesh_and_concave_collision_rebuilt_each_stroke": true,
			"physics_frame_and_surface_probe_each_stroke": true,
			"render_normals_materials_and_resolver_metadata_not_included": true,
			"production_cutover_performed": false,
		},
	}, true)
	_write_report()
	print("FORGE_V2_NATIVE_MANIFOLD_SEQUENCE: %s" % (
		"PASS" if proof_passed else "FAIL"
	))
	print(JSON.stringify({
		"completed": completed_rows.size(),
		"strict_spm": strict_spm,
		"measured_spm": measured_spm,
		"total_ms": metrics.get("release_to_targetable_ms", {}),
		"boolean_ms": metrics.get("native_boolean_ms", {}),
		"collision_ms": metrics.get("collision_packet_ms", {}),
	}))
	quit(0 if proof_passed else 1)


func _load_fixture() -> Dictionary:
	if not FileAccess.file_exists(FIXTURE_PATH):
		return {"ok": false, "error": "fixture is missing"}
	if FileAccess.get_sha256(FIXTURE_PATH).to_lower() != FIXTURE_FILE_SHA256:
		return {"ok": false, "error": "fixture file SHA256 mismatch"}
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if not (parsed is Dictionary):
		return {"ok": false, "error": "fixture JSON is invalid"}
	var fixture := parsed as Dictionary
	if String(fixture.get("canonical_sha256", "")) != FIXTURE_CANONICAL_SHA256:
		return {"ok": false, "error": "fixture canonical hash mismatch"}
	var packets: Dictionary = fixture.get("packets", {}) as Dictionary
	var base := _packet_arrays(packets.get("stroke_a", {}) as Dictionary)
	var stroke := _packet_arrays(packets.get("stroke_b", {}) as Dictionary)
	if not bool(base.get("ok", false)) or not bool(stroke.get("ok", false)):
		return {"ok": false, "error": "fixture mesh packet is invalid"}
	return {
		"ok": true,
		"base_vertices": base.get("vertices"),
		"base_indices": base.get("indices"),
		"stroke_vertices": stroke.get("vertices"),
		"stroke_indices": stroke.get("indices"),
	}


func _packet_arrays(packet: Dictionary) -> Dictionary:
	var vertices := PackedVector3Array()
	for value: Variant in packet.get("vertices", []) as Array:
		if not (value is Array) or (value as Array).size() != 3:
			return {"ok": false}
		var coordinate := value as Array
		vertices.append(Vector3(float(coordinate[0]), float(coordinate[1]), float(coordinate[2])))
	var indices := PackedInt32Array()
	for value: Variant in packet.get("triangles", []) as Array:
		if not (value is Dictionary):
			return {"ok": false}
		var triangle: Array = (value as Dictionary).get("indices", []) as Array
		if triangle.size() != 3:
			return {"ok": false}
		for index: Variant in triangle:
			indices.append(int(index))
	return {"ok": true, "vertices": vertices, "indices": indices}


func _translated(vertices: PackedVector3Array, translation: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	result.resize(vertices.size())
	for index in range(vertices.size()):
		result[index] = vertices[index] + translation
	return result


func _stroke_translation(stroke_number: int) -> Vector3:
	if _sequence_mode == "bounded_workpiece":
		# Forty-eight overlapping stations span a weapon-sized workpiece. The
		# irrational phase offsets add bounded surface variation without changing
		# the exact operand triangles or growing a multi-meter artificial chain.
		return Vector3(
			float((stroke_number - 1) % 48) * TRANSLATION_STEP_METERS,
			0.004 * sin(float(stroke_number) * TAU * 0.61803398875),
			0.003 * cos(float(stroke_number) * TAU * 0.41421356237)
		)
	return Vector3(
		float(stroke_number - 1) * TRANSLATION_STEP_METERS,
		0.0,
		0.0
	)


func _probe_newest_surface(
	body: StaticBody3D,
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> Dictionary:
	var best_triangle := -1
	var best_x := -INF
	for triangle in range(indices.size() / 3):
		var a := vertices[indices[triangle * 3]]
		var b := vertices[indices[triangle * 3 + 1]]
		var c := vertices[indices[triangle * 3 + 2]]
		var cross := (b - a).cross(c - a)
		var center_x := (a.x + b.x + c.x) / 3.0
		if cross.length_squared() > 0.000000000001 and center_x > best_x:
			best_x = center_x
			best_triangle = triangle
	if best_triangle < 0:
		return {"hit": false, "error_m": INF}
	var a := vertices[indices[best_triangle * 3]]
	var b := vertices[indices[best_triangle * 3 + 1]]
	var c := vertices[indices[best_triangle * 3 + 2]]
	var center := (a + b + c) / 3.0
	var normal := (b - a).cross(c - a).normalized()
	var query := PhysicsRayQueryParameters3D.create(
		# Forge output uses the established negative signed-volume winding, so
		# the raw triangle cross points inward. Start from the exterior.
		center - normal * 0.003,
		center + normal * 0.003,
		COLLISION_LAYER
	)
	var hit: Dictionary = root.world_3d.direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.get("collider") != body:
		return {"hit": false, "error_m": INF}
	return {
		"hit": true,
		"error_m": (hit.get("position", Vector3(INF, INF, INF)) as Vector3).distance_to(center),
	}


func _backfill_cycle_boundaries(rows: Array[Dictionary]) -> void:
	for index in range(rows.size() - 1):
		var row := rows[index]
		var next_row := rows[index + 1]
		if not row.has("stroke_end_us") or not next_row.has("stroke_start_us"):
			continue
		var next_start_us := int(next_row.get("stroke_start_us", 0))
		row["next_stroke_start_us"] = next_start_us
		row["ready_to_next_start_ms"] = float(next_start_us - int(row.get("stroke_end_us", 0))) / 1000.0
		row["start_to_next_start_ms"] = float(next_start_us - int(row.get("stroke_start_us", 0))) / 1000.0


func _cycle_samples(rows: Array[Dictionary]) -> Dictionary:
	var head: Array[Dictionary] = []
	for stroke in [2, 3, 4]:
		if rows.size() > stroke and rows[stroke - 1].has("next_stroke_start_us"):
			head.append(_cycle_row(rows[stroke - 1]))
	var tail: Array[Dictionary] = []
	if rows.size() >= 4:
		for index in range(rows.size() - 4, rows.size() - 1):
			if rows[index].has("next_stroke_start_us"):
				tail.append(_cycle_row(rows[index]))
	return {"head_strokes_2_3_4": head, "tail_last_three_complete_cycles": tail}


func _cycle_row(row: Dictionary) -> Dictionary:
	var keys := [
		"stroke", "output_triangles", "native_call_ms", "native_boolean_ms",
		"native_export_ms", "visual_arraymesh_ms", "collision_packet_ms",
		"deferred_physics_wait_ms", "physics_probe_ms", "release_to_targetable_ms",
		"ready_to_next_start_ms", "start_to_next_start_ms",
	]
	var result := {}
	for key: String in keys:
		result[key] = row.get(key)
	return result


func _summarize_rows(rows: Array[Dictionary]) -> Dictionary:
	var fields := [
		"native_call_ms", "native_pack_ms", "native_import_ms", "native_boolean_ms",
		"native_export_ms", "native_commit_ms", "visual_arraymesh_ms",
		"collision_packet_ms", "deferred_physics_wait_ms", "physics_probe_ms",
		"release_to_targetable_ms", "output_triangles",
	]
	var result := {}
	for field: String in fields:
		var values: Array[float] = []
		for row: Dictionary in rows:
			values.append(float(row.get(field, INF)))
		result[field] = _summary(values)
	return result


func _summary(values: Array[float]) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value: float in sorted:
		total += value
	return {
		"count": sorted.size(),
		"min": sorted[0] if not sorted.is_empty() else INF,
		"mean": total / float(sorted.size()) if not sorted.is_empty() else INF,
		"p50": _percentile(sorted, 0.50),
		"p95": _percentile(sorted, 0.95),
		"p99": _percentile(sorted, 0.99),
		"max": sorted[-1] if not sorted.is_empty() else INF,
	}


func _percentile(sorted: Array[float], fraction: float) -> float:
	if sorted.is_empty():
		return INF
	return sorted[mini(sorted.size() - 1, int(ceil(fraction * float(sorted.size()))) - 1)]


func _strip_arrays(value: Dictionary) -> Dictionary:
	var result := value.duplicate(false)
	for key in ["vertices", "indices", "source_original_ids", "source_face_ids"]:
		result.erase(key)
	return result


func _fail(message: String) -> void:
	_report["outcome"] = "fail"
	_report["failure_reason"] = message
	_write_report()
	push_error("FORGE_V2_NATIVE_MANIFOLD_SEQUENCE: %s" % message)
	quit(1)


func _write_report() -> void:
	var path := _result_path if not _result_path.is_empty() else RESULT_DIRECTORY.path_join(
		"benchmark_forge_v2_native_manifold_sequence_failure.json"
	)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))
