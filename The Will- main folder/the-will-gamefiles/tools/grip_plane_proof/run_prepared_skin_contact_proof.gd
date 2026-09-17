extends SceneTree

const Store = preload("res://tools/grip_plane_proof/character_hand_anatomy_store.gd")
const InputAdapter = preload("res://tools/grip_plane_proof/prepared_anatomy_contact_input.gd")
const Slicer = preload("res://tools/grip_plane_proof/slice_reachable_surface.gd")
const SkinQuery = preload("res://tools/grip_plane_proof/prepared_digit_skin_query.gd")
const Contact = preload("res://tools/grip_plane_proof/skin_plane_contact_query.gd")
const Spatial = preload("res://runtime/player/player_finger_surface_grip_solver.gd")
const Search = preload("res://tools/grip_plane_proof/prepared_skin_contact_solver.gd")
const SIGNATURE := "0fb9e5dbe88cd71e342f4efe106676026345d283374abede7dc98853dd784bf5"
const DEFINITION_PATH := "res://tools/grip_plane_proof/prepared_characters/josie/" + SIGNATURE + ".tres"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var load_start := Time.get_ticks_usec()
	var loaded: Dictionary = Store.new().load_matching(DEFINITION_PATH, SIGNATURE, "rest_middle_thumb_surface_measurements_v1")
	if not bool(loaded.get("valid", false)):
		push_error(JSON.stringify(loaded))
		quit(1)
		return
	var load_ms := float(Time.get_ticks_usec() - load_start) / 1000.0
	var paths: Array[String] = []
	var explicit_path := OS.get_environment("THE_WILL_GRIP_CAPTURE_PATH")
	if not explicit_path.is_empty():
		paths.append(explicit_path)
	else:
		paths.assign(["C:/WORKSPACE/test_artifacts/grip_solver_inputs_hand_right_2026-09-15T04-36-47.bin", "C:/WORKSPACE/test_artifacts/grip_solver_inputs_hand_left_2026-09-15T04-36-57.bin"])
	var report := {"schema": "prepared_skin_contact_proof_v1", "anatomy_path": DEFINITION_PATH,
		"source_signature": SIGNATURE, "anatomy_load_validation_ms": load_ms,
		"anatomy_recomputed": false, "production_pose_written": false, "actual_3d_grip_verified": false, "digits": []}
	var failed := false
	for path: String in paths:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("Missing capture: " + path)
			quit(1)
			return
		var capture: Dictionary = file.get_var()
		file.close()
		for digit: StringName in [&"middle", &"thumb"]:
			var result := _digit(loaded.resource, capture, digit)
			result["capture_path"] = path
			result["slot"] = capture.get("slot")
			result["digit"] = digit
			report.digits.append(result)
			failed = failed or not bool(result.get("valid", false))
			print("PREPARED_SKIN_CONTACT_DIGIT=" + JSON.stringify(_brief(result)))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var output := "C:/WORKSPACE/test_artifacts/prepared_skin_contact_" + stamp + ".json"
	var out_file := FileAccess.open(output, FileAccess.WRITE)
	out_file.store_string(JSON.stringify(_numbers(report), "\t"))
	out_file.close()
	print("PREPARED_SKIN_CONTACT_RESULT=" + output)
	quit(1 if failed else 0)

func _digit(definition: Resource, capture: Dictionary, digit_id: StringName) -> Dictionary:
	var started := Time.get_ticks_usec()
	var input: Dictionary = InputAdapter.new().build(definition, capture, digit_id)
	if not bool(input.get("valid", false)):
		return input
	var surface: Dictionary = capture.get("object_contact", {}).get("surface", {})
	if not bool(surface.get("valid", false)):
		return {"valid": false, "reason": "missing_captured_whole_object_surface"}
	var plane: Transform3D = input.plane_to_world
	var reach := 0.0
	for length_m: float in input.digit.section_lengths_m:
		reach += length_m
	# Keep full intersections solely for solid parity. Contact candidates stay
	# inside measured reach; no cropped contour receives an invented closing cap.
	var outer_bound := 0.0
	for point: Vector3 in surface.triangles_world:
		outer_bound = maxf(outer_bound, point.distance_to(plane.origin))
	var slice_start := Time.get_ticks_usec()
	var target_slice: Dictionary = Slicer.new().slice(surface, plane, input.plane_origin_id, outer_bound + 0.00001, 0.0)
	if not bool(target_slice.get("valid", false)):
		return {"valid": false, "reason": "whole_object_slice_failed", "details": target_slice}
	var contact = Contact.new()
	var target: Dictionary = contact.prepare_target(target_slice.segments, input.plane_origin_id)
	target["classification_incomplete"] = target_slice.classification_incomplete
	var slicing_ms := float(Time.get_ticks_usec() - slice_start) / 1000.0
	var query_start := Time.get_ticks_usec()
	var skin = SkinQuery.new()
	var query: Dictionary = skin.prepare(input.snapshot, input.reference_skin, input.context, plane, input.plane_origin_id)
	if not bool(query.get("valid", false)):
		return {"valid": false, "reason": "prepared_skin_query_failed", "details": query}
	var query_setup_ms := float(Time.get_ticks_usec() - query_start) / 1000.0
	var poses: Array = []
	for fraction: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var angles: Array[float] = []
		for preferred: float in input.snapshot.preferred_angles_rad:
			angles.append(preferred * fraction)
		poses.append(_evaluate(skin, query, contact, target, input, angles, reach, "preferred_" + str(fraction)))
	var search_result: Dictionary = {}
	if OS.get_environment("THE_WILL_PREPARED_SKIN_SEARCH") == "1":
		var callback := func(angles: Array[float]) -> Dictionary:
			return _evaluate(skin, query, contact, target, input, angles, reach, "search", false)
		search_result = Search.new().solve(input.snapshot, input.plane_origin_id, callback)
		if search_result.has("angles_rad"):
			var selected_angles: Array[float] = []
			selected_angles.assign(search_result.angles_rad)
			poses.append(_evaluate(skin, query, contact, target, input, selected_angles, reach, "selected"))
	return {"valid": true, "origin_id": input.plane_origin_id, "origin_records": input.origin_records,
		"origin_chain": input.origin_chain, "plane_to_world": plane, "machine_to_world": input.context.machine_to_world,
		"section_length_round_trip_error_m": input.section_length_round_trip_error_m,
		"metric_axis_roundoff_correction": input.metric_axis_roundoff_correction,
		"query_radius_m": reach, "target_segments": target_slice.segments, "target_slice_counts": target_slice.counts,
		"target_slice_classification_incomplete": target_slice.classification_incomplete,
		"source_object_topology": surface.get("capsule_surface_topology", {}), "search": search_result,
		"slicing_and_target_setup_ms": slicing_ms, "skin_query_setup_ms": query_setup_ms,
		"poses": poses, "total_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"other_bones_use_hand_rebased_rest": true, "anatomy_recomputed": false,
		"full_3d_validation_performed": false, "combined_digits_validated": false}

func _evaluate(skin: RefCounted, query: Dictionary, contact: RefCounted, target: Dictionary, input: Dictionary, angles: Array[float], reach: float, label: String, retain_geometry: bool = true) -> Dictionary:
	var started := Time.get_ticks_usec()
	var posed: Dictionary = skin.pose(query, angles)
	if not bool(posed.get("valid", false)):
		return {"valid": false, "reason": posed.get("reason"), "label": label}
	var contact_start := Time.get_ticks_usec()
	var measured: Dictionary = contact.evaluate(posed.segments, target, input.plane_origin_id, {"reach_m": reach, "skip_skin_solid_classification": true})
	var contact_ms := float(Time.get_ticks_usec() - contact_start) / 1000.0
	if not retain_geometry:
		return {"valid": bool(measured.get("valid", false)), "contact": measured}
	var fk: Dictionary = Spatial.new()._forward_kinematics(input.snapshot, angles)
	var points: Array = fk.joint_origins_world.duplicate()
	points.append(fk.tip_world)
	var points_2d: Array = []
	for point: Vector3 in points:
		var p: Vector3 = input.plane_to_world.affine_inverse() * point
		points_2d.append(Vector2(p.x, p.y))
	return {"valid": bool(measured.get("valid", false)), "label": label, "angles_rad": angles, "joint_points_m": points_2d,
		"skin_segments": posed.segments, "contact": measured, "contact_ms": contact_ms,
		"skin_pose_ms": posed.elapsed_ms, "updated_vertex_count": posed.updated_vertex_count, "updated_triangle_count": posed.updated_triangle_count,
		"total_pose_ms": float(Time.get_ticks_usec() - started) / 1000.0}

func _brief(result: Dictionary) -> Dictionary:
	var out := {}
	for key: String in ["valid", "reason", "slot", "digit", "section_length_round_trip_error_m", "slicing_and_target_setup_ms", "skin_query_setup_ms", "total_ms", "target_slice_classification_incomplete"]:
		if result.has(key):
			out[key] = result[key]
	out["poses"] = []
	for pose: Dictionary in result.get("poses", []):
		var detail: Dictionary = pose.get("contact", {})
		out.poses.append({"label": pose.label, "valid": pose.get("valid"), "reason": detail.get("reason"), "total_pose_ms": pose.get("total_pose_ms"),
			"crossings": detail.get("dynamic", {}).get("proper_crossings"), "gap_m": detail.get("dynamic", {}).get("gap_m"),
			"skin_inside_target_classified": detail.get("skin_inside_target_classification_complete"), "target_topology": detail.get("target_topology")})
	if not result.get("search", {}).is_empty():
		out["search"] = result.search.duplicate()
		out.search.erase("contact")
	return _numbers(out)

func _numbers(value: Variant) -> Variant:
	if value is Vector2:
		return [value.x, value.y]
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Transform3D:
		return {"basis_columns": [_numbers(value.basis.x), _numbers(value.basis.y), _numbers(value.basis.z)], "origin_m": _numbers(value.origin)}
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			if not value[key] is Object:
				out[str(key)] = _numbers(value[key])
		return out
	if value is Array or value is PackedVector2Array or value is PackedVector3Array or value is PackedFloat32Array or value is PackedInt32Array:
		var out: Array = []
		for item: Variant in value:
			out.append(_numbers(item))
		return out
	return value
