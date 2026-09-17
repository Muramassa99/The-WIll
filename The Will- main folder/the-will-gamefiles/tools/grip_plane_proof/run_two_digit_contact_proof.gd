extends SceneTree

const Preparator = preload("res://tools/grip_plane_proof/prepare_digit_anatomy.gd")
const Slicer = preload("res://tools/grip_plane_proof/slice_reachable_surface.gd")
const PlanarSolver = preload("res://tools/grip_plane_proof/planar_digit_contact_solver.gd")
const SpatialSolver = preload("res://runtime/player/player_finger_surface_grip_solver.gd")
const SkinMeasurement = preload("res://tools/grip_plane_proof/measure_digit_skin_surface.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var input_path := OS.get_environment("THE_WILL_GRIP_CAPTURE_PATH")
	var skin_path := OS.get_environment("THE_WILL_CHARACTER_SAMPLES_PATH")
	var input := _read(input_path)
	var skin := _read(skin_path)
	if input.is_empty() or not bool(skin.get("valid", false)) or not skin.get("reference_skin") is Dictionary:
		push_error("Provide coherent grip input and measured character samples.")
		quit(1)
		return
	var surface: Dictionary = input.get("object_contact", {}).get("surface", {})
	if not bool(surface.get("valid", false)):
		push_error("Capture lacks the authoritative whole-object surface.")
		quit(1)
		return
	var context: Dictionary = input["capture_frame"].duplicate(true)
	context["model_identity"] = skin["model_identity"]
	context["sampling_method"] = skin["sampling_method"]
	var hand_names := {&"hand_right": &"CC_Base_R_Hand", &"hand_left": &"CC_Base_L_Hand"}
	context["hand_bone_name"] = hand_names.get(StringName(input["slot"]), StringName())
	var output := {"schema": "two_digit_contact_proof_v1", "input": input_path, "skin_input": skin_path, "slot": input["slot"], "digits": {}, "object_triangle_count": surface["triangle_count"], "object_topology": surface["capsule_surface_topology"], "production_pose_written": false}
	var spatial = SpatialSolver.new()
	for digit: String in ["middle", "thumb"]:
		var started := Time.get_ticks_usec()
		var source: Dictionary = input["digits"][digit]["snapshot"]
		var preparator = Preparator.new()
		var preparation: Dictionary = preparator.prepare(source, skin["samples"], context)
		if not bool(preparation.get("valid", false)):
			_store_blocked(output, digit, preparation, {}, {"status": preparation.get("reason", "preparation_failed")}, started)
			continue
		var snapshot: Dictionary = preparation["prepared_snapshot"].duplicate(true)
		var measurement: Dictionary = SkinMeasurement.new().measure(snapshot, skin["reference_skin"], context)
		measurement.erase("registry")
		preparation.erase("registry")
		var proxy_started := Time.get_ticks_usec()
		var proxy: Dictionary = _measured_candidate_proxy(spatial, snapshot, measurement)
		if not bool(proxy.get("valid", false)):
			_store_blocked(output, digit, preparation, measurement, proxy, started)
			continue
		var plane: Transform3D = measurement["plane_to_world"]
		var lengths: Array = proxy["lengths_m"]
		var radii: Array = proxy["radii_m"]
		preparation["rejected_weight_membership_proxy"] = {"sampling_method": preparation["sampling_method"], "radii_m": preparation["radii_m"], "section_lengths_m": preparation["section_lengths_m"], "terminal_skin_extent_m": preparation["terminal_skin_extent_m"], "sections": preparation["sections"], "used_for_candidate": false}
		preparation["prepared_snapshot"] = snapshot
		preparation["radii_m"] = radii.duplicate()
		preparation["capsule_section_lengths_m"] = lengths.duplicate()
		preparation["section_lengths_m"] = proxy["measured_axis_lengths_m"].duplicate()
		preparation["sections"] = measurement["sections"].duplicate(true)
		preparation["sampling_method"] = "actual_posed_skin_cardinal_rays_candidate_proxy_only"
		preparation["terminal_skin_extent_m"] = proxy["terminal_outer_ray_m"]
		preparation["terminal_skin_tip_offset_local"] = proxy["terminal_outer_tip_offset_local"]
		for key: String in ["plane_origin_id", "plane_to_world", "plane_to_machine", "origin_chain"]:
			preparation[key] = measurement[key]
		preparation["plane_metrics"] = preparator._plane_metrics(spatial, snapshot, plane)
		preparation["candidate_proxy"] = proxy.duplicate(true)
		preparation["actual_skin_contact_verified"] = false
		var proxy_ms := float(Time.get_ticks_usec() - proxy_started) / 1000.0
		var one_time_preparation_ms := float(Time.get_ticks_usec() - started) / 1000.0
		var reach: float = float(lengths[0]) + float(lengths[1]) + float(lengths[2])
		var padding: float = maxf(float(radii[0]), maxf(float(radii[1]), float(radii[2])))
		var slice_started := Time.get_ticks_usec()
		var slice: Dictionary = Slicer.new().slice(surface, plane, measurement["plane_origin_id"], reach, padding)
		var slice_ms := float(Time.get_ticks_usec() - slice_started) / 1000.0
		var zero: Array[float] = [0.0, 0.0, 0.0]
		var fk: Dictionary = spatial._forward_kinematics(snapshot, zero)
		var positions: Array = fk["joint_origins_world"].duplicate()
		positions.append(fk["tip_world"])
		var zero_angles: Array[float] = []
		var signs: Array[float] = []
		var previous_angle: float = 0.0
		for i: int in range(3):
			var delta: Vector3 = positions[i + 1] - positions[i]
			var angle: float = atan2(delta.dot(plane.basis.y), delta.dot(plane.basis.x))
			zero_angles.append(angle - previous_angle)
			previous_angle = angle
			signs.append(signf(float(snapshot["preferred_angles_rad"][i])))
		var hand := {"lengths_m": lengths, "radii_m": radii, "zero_angles_rad": zero_angles, "min_angles_rad": snapshot["min_angles_rad"], "max_angles_rad": snapshot["max_angles_rad"], "closure_signs": signs}
		var solve_started := Time.get_ticks_usec()
		var candidate: Dictionary = PlanarSolver.new().solve(hand, slice)
		var solve_ms := float(Time.get_ticks_usec() - solve_started) / 1000.0
		var validation: Dictionary = {}
		if candidate.has("angles_rad"):
			validation = _validate(spatial, snapshot, surface, plane, candidate)
		var validation_ms := float(validation.get("timing_ms", 0.0))
		var summary := {"digit": digit, "skin_lengths_mm": _mm(preparation["section_lengths_m"]), "radii_mm": _mm(radii), "max_sample_plane_depth_mm": float(preparation["plane_metrics"]["max_sample_depth_m"]) * 1000.0, "slice_counts": slice["counts"], "candidate_status": candidate.get("status"), "angles_degrees": _degrees(candidate.get("angles_rad", [])), "contact_count": candidate.get("contact_count", 0), "evaluations": candidate.get("evaluations", 0), "validation": validation, "preparation_ms": one_time_preparation_ms, "calibration_ms": preparation["elapsed_milliseconds"], "skin_measurement_ms": measurement.get("elapsed_milliseconds", 0.0), "skin_reconstruction_ms": measurement.get("skinning_elapsed_milliseconds", 0.0), "candidate_proxy_ms": proxy_ms, "one_time_preparation_ms": one_time_preparation_ms, "slice_ms": slice_ms, "solve_ms": solve_ms, "validation_ms": validation_ms, "runtime_query_ms": slice_ms + solve_ms + validation_ms, "runtime_query_work_ran": true, "skin_measurement_complete": measurement.get("complete", false), "candidate_proxy_is_skin_certified": false, "total_ms": float(Time.get_ticks_usec() - started) / 1000.0}
		print("TWO_DIGIT_CONTACT_PROOF=" + JSON.stringify(summary))
		preparation.erase("registry")
		output["digits"][digit] = {"preparation": preparation, "skin_surface_measurement": measurement, "hand": hand, "slice": slice, "candidate": candidate, "summary": summary}
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var result_path := "C:/WORKSPACE/test_artifacts/two_digit_contact_proof_" + String(input["slot"]) + "_" + stamp
	var binary := FileAccess.open(result_path + ".bin", FileAccess.WRITE)
	binary.store_var(output)
	binary.close()
	var json := FileAccess.open(result_path + ".json", FileAccess.WRITE)
	json.store_string(JSON.stringify(_numbers(output), "\t"))
	json.close()
	print("TWO_DIGIT_CONTACT_PROOF_RESULT=" + result_path)
	quit(0)

func _store_blocked(output: Dictionary, digit: String, preparation: Dictionary, measurement: Dictionary, proxy: Dictionary, started: int) -> void:
	preparation.erase("registry")
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	var status: Variant = proxy.get("status", "candidate_proxy_unavailable")
	var summary := {"digit": digit, "candidate_status": status, "evaluations": 0, "preparation_ms": elapsed, "one_time_preparation_ms": elapsed, "calibration_ms": preparation.get("elapsed_milliseconds", 0.0), "skin_measurement_ms": measurement.get("elapsed_milliseconds", 0.0), "skin_reconstruction_ms": measurement.get("skinning_elapsed_milliseconds", 0.0), "runtime_query_work_ran": false, "skin_measurement_complete": measurement.get("complete", false), "candidate_proxy_is_skin_certified": false, "validation": {"actual_skin_contact_verified": false}, "total_ms": elapsed}
	output["digits"][digit] = {"preparation": preparation, "skin_surface_measurement": measurement, "candidate_proxy": proxy, "candidate": {"status": status, "valid": false, "safe": false, "evaluations": 0}, "summary": summary}
	print("TWO_DIGIT_CONTACT_PROOF=" + JSON.stringify(summary))

func _measured_candidate_proxy(spatial: RefCounted, snapshot: Dictionary, measurement: Dictionary) -> Dictionary:
	if not bool(measurement.get("valid", false)) or not bool(measurement.get("complete", false)):
		return {"valid": false, "status": "incomplete_actual_skin_measurement", "measurement_reason": measurement.get("reason", "one_or_more_required_rays_missed")}
	var sections: Array = measurement.get("sections", [])
	if sections.size() != 3 or not bool(measurement.get("terminal_tip_ray", {}).get("hit", false)):
		return {"valid": false, "status": "missing_actual_skin_sections_or_terminal"}
	var radii: Array[float] = []
	var measured_lengths: Array[float] = []
	for section: Dictionary in sections:
		var radius: float = 0.0
		if not bool(section.get("available", false)) or section.get("cross_sections", []).is_empty():
			return {"valid": false, "status": "missing_actual_skin_cross_sections"}
		for row: Dictionary in section["cross_sections"]:
			for key: String in ["u_plus", "u_minus", "normal_plus", "normal_minus"]:
				var ray: Dictionary = row.get("rays", {}).get(key, {})
				var distance: float = float(ray.get("distance_m", -1.0))
				if not bool(row.get("available", false)) or not bool(ray.get("hit", false)) or not is_finite(distance) or distance <= 0.0:
					return {"valid": false, "status": "incomplete_actual_skin_cardinal_rays"}
				radius = maxf(radius, distance)
		var length_m: float = float(section.get("axis_length_m", -1.0))
		if not is_finite(length_m) or length_m <= 0.0:
			return {"valid": false, "status": "nonpositive_actual_skin_axis_length"}
		radii.append(radius)
		measured_lengths.append(length_m)
	var outer: float = float(measurement["terminal_tip_ray"]["distance_m"])
	var centerline: float = outer - radii[2]
	if not is_finite(centerline) or centerline <= 0.0:
		return {"valid": false, "status": "measured_terminal_radius_exceeds_outer_ray", "terminal_outer_ray_m": outer, "radii_m": radii}
	var zero: Array[float] = [0.0, 0.0, 0.0]
	var frame: Transform3D = spatial._forward_kinematics(snapshot, zero)["joint_transforms_world"][2]
	var direction: Vector3 = (snapshot["tip_offset_local"] as Vector3).normalized()
	var directional_scale: float = (frame.basis * direction).length()
	if not is_finite(directional_scale) or directional_scale <= 0.0:
		return {"valid": false, "status": "invalid_named_terminal_direction_scale"}
	var lengths: Array[float] = [measured_lengths[0], measured_lengths[1], centerline]
	snapshot["capsule_radii_m"] = radii.duplicate()
	snapshot["tip_offset_local"] = direction * (centerline / directional_scale)
	snapshot["tip_offset_origin_id"] = snapshot["bone_names"][2]
	# Maximum transverse ray distance bounds sampled radial distances, but the
	# terminal hemisphere can still miss a sampled bulge. Measure that separately.
	var proxy_fk: Dictionary = spatial._forward_kinematics(snapshot, zero)
	var proxy_points: Array = proxy_fk["joint_origins_world"].duplicate()
	proxy_points.append(proxy_fk["tip_world"])
	var outside_by_section: Array[float] = []
	for i: int in range(3):
		var outside: float = 0.0
		var start: Vector3 = proxy_points[i]
		var axis: Vector3 = (proxy_points[i + 1] as Vector3) - start
		for row: Dictionary in sections[i]["cross_sections"]:
			for ray: Dictionary in row["rays"].values():
				var point: Vector3 = ray["position_world"]
				var weight: float = clampf((point - start).dot(axis) / axis.length_squared(), 0.0, 1.0)
				outside = maxf(outside, point.distance_to(start + axis * weight) - radii[i])
		outside_by_section.append(outside)
	return {"valid": true, "status": "measured_cardinal_ray_candidate_proxy", "lengths_m": lengths, "radii_m": radii, "measured_axis_lengths_m": measured_lengths, "terminal_outer_ray_m": outer, "terminal_outer_tip_offset_local": direction * (outer / directional_scale), "terminal_origin_id": snapshot["bone_names"][2], "radius_rule": "maximum_of_all_measured_cardinal_ray_distances_per_section", "centered_radius_bounds_measured_cardinal_distances_only": true, "max_measured_sample_outside_capsule_m": outside_by_section, "unmeasured_surface_coverage_certified": false, "measured_asymmetry_preserved_in_skin_surface_measurement": true, "actual_skin_contact_verified": false}

func _validate(solver: RefCounted, snapshot: Dictionary, surface: Dictionary, plane: Transform3D, candidate: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	var angles: Array[float] = []
	angles.assign(candidate["angles_rad"])
	var fk: Dictionary = solver._forward_kinematics(snapshot, angles)
	var points: Array = fk["joint_origins_world"].duplicate()
	points.append(fk["tip_world"])
	var safe: bool = true
	var sections: Array = []
	var projection_error: float = 0.0
	var depth: float = 0.0
	for i: int in range(4):
		var local: Vector3 = plane.affine_inverse() * (points[i] as Vector3)
		projection_error = maxf(projection_error, Vector2(local.x, local.y).distance_to(candidate["points_m"][i]))
		depth = maxf(depth, absf(local.z))
	for i: int in range(3):
		var query: Dictionary = solver.capsule_surface_query.query_prepared_surface(surface, points[i], snapshot["bone_names"][i], points[i + 1], snapshot["bone_names"][mini(i + 1, 2)], snapshot["capsule_radii_m"][i], surface["surface_source_origin_id"], &"RL_BoneRoot", {"classify_inside_solid": true, "surface_topology_state": surface["capsule_surface_topology"]})
		var cap: float = [0.0005, 0.0004, 0.0003][i]
		var valid: bool = bool(query.get("valid", false)) and bool(query.get("signed_distance_valid", false))
		var section_safe: bool = valid and float(query.get("penetration_meters", INF)) <= cap + 0.0000001
		safe = safe and section_safe
		sections.append({"valid": valid, "safe": section_safe, "distance_query_valid": bool(query.get("valid", false)), "signed_distance_valid": bool(query.get("signed_distance_valid", false)), "signed_overlap_mm": _finite_mm(query.get("signed_overlap_meters")), "axis_surface_distance_mm": _finite_mm(query.get("axis_surface_distance_meters")), "capsule_surface_signed_distance_mm": _finite_mm(query.get("capsule_surface_signed_distance_meters")), "surface_gap_mm": _finite_mm(query.get("surface_gap_meters")), "inside_classification_status": query.get("inside_classification_status", "unavailable"), "surface_topology_closed": query.get("surface_topology_closed", false)})
	return {"capsules_safe_in_3d": safe, "sections": sections, "planar_fk_error_mm": projection_error * 1000.0, "out_of_plane_mm": depth * 1000.0, "timing_ms": float(Time.get_ticks_usec() - started) / 1000.0, "actual_skin_contact_verified": false}

func _finite_mm(value: Variant) -> Variant:
	return float(value) * 1000.0 if (value is float or value is int) and is_finite(float(value)) else null

func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var result: Variant = file.get_var()
	file.close()
	return result if result is Dictionary else {}

func _mm(values: Array) -> Array:
	return values.map(func(value: float) -> float: return value * 1000.0)

func _degrees(values: Array) -> Array:
	return values.map(func(value: float) -> float: return rad_to_deg(value))

func _numbers(value: Variant) -> Variant:
	if value is Vector2:
		return [value.x, value.y]
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Transform3D:
		return {"basis_columns": [_numbers(value.basis.x), _numbers(value.basis.y), _numbers(value.basis.z)], "origin_m": _numbers(value.origin)}
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value:
			out[key] = _numbers(value[key])
		return out
	if value is Array or value is PackedVector2Array or value is PackedVector3Array or value is PackedFloat32Array:
		var out: Array = []
		for entry: Variant in value:
			out.append(_numbers(entry))
		return out
	return value
