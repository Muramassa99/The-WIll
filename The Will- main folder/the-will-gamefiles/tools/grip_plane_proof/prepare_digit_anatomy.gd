extends RefCounted

const SolverScript = preload("res://runtime/player/player_finger_surface_grip_solver.gd")
const OriginScript = preload("res://core/models/combat_origin_record.gd")
const RegistryScript = preload("res://core/resolvers/combat_origin_registry.gd")
const CENTRAL_SPAN := Vector2(0.2, 0.8)

## Proof preparation only: reference skin patches are rigidly carried by their
## named bones into a copied, calibrated zero pose. Their measured hulls are
## projections; the central-span capsules/ellipses are approximate proxies.
## No skeleton, source snapshot, skin samples or production rule is changed.
func prepare(source_snapshot: Dictionary, skin_samples_by_bone: Dictionary, sample_context: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var reason: String = _input_reason(source_snapshot, skin_samples_by_bone, sample_context)
	if not reason.is_empty():
		return {"valid": false, "reason": reason}
	var snapshot: Dictionary = source_snapshot.duplicate(true)
	var neutrals: Array = snapshot["neutral_local_rotations"].duplicate()
	# Same operation as the existing Thumb2/Thumb3 collinear preparer. This
	# generic diagnostic also applies it to the ordinary digit's joints 2/3;
	# imported bone rests, joint 1, hinge axes and signed limits are preserved.
	for index: int in [1, 2]:
		neutrals[index] = (snapshot["base_pose_rotations"][index] as Quaternion).inverse().normalized()
	snapshot["neutral_local_rotations"] = neutrals
	var solver = SolverScript.new()
	var zero_angles: Array[float] = [0.0, 0.0, 0.0]
	var fk: Dictionary = solver._forward_kinematics(snapshot, zero_angles)
	var transforms: Array = fk["joint_transforms_world"]
	var names: Array = snapshot["bone_names"]
	var skin_world: Array[PackedVector3Array] = []
	for index: int in range(3):
		var frame: Transform3D = transforms[index]
		if not _frame_valid(frame):
			return {"valid": false, "reason": "invalid_prepared_bone_frame", "bone": names[index]}
		var points := PackedVector3Array()
		for point: Vector3 in skin_samples_by_bone[names[index]]["points_bone_local"]:
			points.append(frame * point)
		skin_world.append(points)
	# Use the named rule's direction only; its old terminal magnitude is not
	# anatomy. The actual outer extent comes from the terminal skin patch.
	var terminal_local_direction: Vector3 = (snapshot["tip_offset_local"] as Vector3).normalized()
	var terminal_frame: Transform3D = transforms[2]
	var terminal_scale: float = (terminal_frame.basis * terminal_local_direction).length()
	var terminal_axis: Vector3 = (terminal_frame.basis * terminal_local_direction).normalized()
	var terminal_extent: float = -INF
	for point: Vector3 in skin_world[2]:
		terminal_extent = maxf(terminal_extent, (point - terminal_frame.origin).dot(terminal_axis))
	if not is_finite(terminal_extent) or terminal_extent <= 0.0:
		return {"valid": false, "reason": "no_positive_measured_terminal_extent"}
	var points: Array[Vector3] = [transforms[0].origin, transforms[1].origin, transforms[2].origin,
		terminal_frame.origin + terminal_axis * terminal_extent]
	var normal: Vector3 = (transforms[0] as Transform3D).basis.x.cross((transforms[0] as Transform3D).basis.y).normalized()
	var first_segment: Vector3 = points[1] - points[0]
	var axis_u: Vector3 = first_segment - normal * first_segment.dot(normal)
	if axis_u.length_squared() <= 1.0e-12 or normal.length_squared() < 0.5:
		return {"valid": false, "reason": "degenerate_prepared_motion_plane"}
	axis_u = axis_u.normalized()
	var plane := Transform3D(Basis(axis_u, normal.cross(axis_u).normalized(), normal), points[0])
	var machine: Transform3D = sample_context["machine_to_world"]
	var phase: StringName = sample_context["resolve_phase"]
	var registry = RegistryScript.new()
	var plane_id := StringName(String(names[0]) + "PreparedAnatomyPlaneOrigin")
	if not _register_frame(registry, plane_id, plane, machine, phase):
		return {"valid": false, "reason": "prepared_plane_registration_failed"}
	var section_lengths: Array[float] = []
	var capsule_lengths: Array[float] = []
	var radii: Array[float] = []
	var sections: Array[Dictionary] = []
	var total_samples: int = 0
	for index: int in range(3):
		var frame: Transform3D = transforms[index]
		var bone_origin_id := StringName(String(names[index]) + "PreparedAnatomyOrigin")
		if not _register_frame(registry, bone_origin_id, frame, machine, phase):
			return {"valid": false, "reason": "prepared_bone_registration_failed", "bone": names[index]}
		var section: Dictionary = _measure_section(skin_world[index], points[index], points[index + 1], normal, plane, index == 2)
		if not bool(section.get("valid", false)):
			return {"valid": false, "reason": section.get("reason"), "bone": names[index]}
		section["bone_name"] = names[index]
		section["source_points_origin_id"] = skin_samples_by_bone[names[index]]["origin_id"]
		section["prepared_origin_id"] = bone_origin_id
		section["bone_to_machine"] = machine.affine_inverse() * frame
		section["origin_chain"] = registry.validate_origin_chain(bone_origin_id)
		section["selection"] = skin_samples_by_bone[names[index]].get("selection", "provided_bone_local_patch")
		sections.append(section)
		section_lengths.append(float(section["skin_section_length_m"]))
		capsule_lengths.append(float(section["capsule_centerline_length_m"]))
		radii.append(float(section["radius_m"]))
		total_samples += int(section["sample_count"])
	snapshot["tip_offset_local"] = terminal_local_direction * (capsule_lengths[2] / terminal_scale)
	snapshot["tip_offset_origin_id"] = names[2]
	snapshot["capsule_radii_m"] = radii.duplicate()
	# Keep diagnostic consumers' cached zero frames coherent with the new
	# neutralization. FK itself obtains frames from parent/relative transforms.
	snapshot["base_bone_world"] = transforms.duplicate()
	var metrics: Dictionary = _plane_metrics(solver, snapshot, plane)
	return {
		"valid": true, "schema": "digit_anatomy_proof_v1", "prepared_snapshot": snapshot,
		"section_lengths_m": section_lengths, "capsule_section_lengths_m": capsule_lengths,
		"radii_m": radii, "sections": sections, "skin_sample_count": total_samples,
		"model_identity": sample_context.get("model_identity", {}).duplicate(true),
		"sampling_method": sample_context.get("sampling_method", "provided_bone_local_samples"),
		"root_origin_id": OriginScript.ORIGIN_RL_BONE_ROOT, "resolve_phase": phase,
		"machine_to_world": machine, "plane_to_world": plane,
		"plane_to_machine": machine.affine_inverse() * plane, "plane_origin_id": plane_id,
		"origin_chain": registry.validate_origin_chain(plane_id), "registry": registry,
		"plane_metrics": metrics, "terminal_skin_extent_m": terminal_extent,
		"terminal_skin_tip_offset_local": terminal_local_direction * (terminal_extent / terminal_scale),
		"terminal_skin_tip_origin_id": names[2], "tip_derived_from_actual_mesh_samples": true,
		"neutralization": "joint_2_and_3_inverse_base_pose_rotation; joint_1_and_rules_preserved",
		"proxy_is_approximation": true, "skin_weights_are_not_anatomical_boundaries": true,
		"measurements_use_world_meters_after_full_bone_transform": true,
		"projection_is_not_a_contact_certificate": true, "path_safety_checked": false,
		"elapsed_milliseconds": float(Time.get_ticks_usec() - started) / 1000.0,
	}


func _measure_section(samples: PackedVector3Array, start: Vector3, end: Vector3, normal: Vector3, plane: Transform3D, terminal: bool) -> Dictionary:
	var length_m: float = start.distance_to(end)
	if length_m <= 0.0:
		return {"valid": false, "reason": "degenerate_measured_section"}
	var axis: Vector3 = (end - start).normalized()
	var transverse_u: Vector3 = normal.cross(axis).normalized()
	if transverse_u.length_squared() < 0.5:
		return {"valid": false, "reason": "degenerate_transverse_measurement_frame"}
	var transverse_v: Vector3 = axis.cross(transverse_u).normalized()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var radius: float = 0.0
	var central_count: int = 0
	var projected := PackedVector2Array()
	var depth_bounds := Vector2(INF, -INF)
	var axial_bounds := Vector2(INF, -INF)
	var plane_inverse: Transform3D = plane.affine_inverse()
	for point: Vector3 in samples:
		var delta: Vector3 = point - start
		var axial: float = delta.dot(axis)
		axial_bounds.x = minf(axial_bounds.x, axial)
		axial_bounds.y = maxf(axial_bounds.y, axial)
		var plane_point: Vector3 = plane_inverse * point
		projected.append(Vector2(plane_point.x, plane_point.y))
		depth_bounds.x = minf(depth_bounds.x, plane_point.z)
		depth_bounds.y = maxf(depth_bounds.y, plane_point.z)
		if axial < length_m * CENTRAL_SPAN.x or axial > length_m * CENTRAL_SPAN.y:
			continue
		var transverse := Vector2(delta.dot(transverse_u), delta.dot(transverse_v))
		low = low.min(transverse)
		high = high.max(transverse)
		radius = maxf(radius, transverse.length())
		central_count += 1
	if central_count < 3 or radius <= 0.0 or low.x >= high.x or low.y >= high.y:
		return {"valid": false, "reason": "insufficient_central_skin_cross_section", "central_sample_count": central_count}
	# A capsule's hemispherical end already adds its radius. Its distal center
	# must stop this far before the measured skin tip, rather than overshoot it.
	var centerline_length: float = length_m - radius if terminal else length_m
	if centerline_length <= 0.0:
		return {"valid": false, "reason": "terminal_radius_exceeds_measured_extent"}
	var outside: float = 0.0
	for point: Vector3 in samples:
		var center: Vector3 = start + axis * clampf((point - start).dot(axis), 0.0, centerline_length)
		outside = maxf(outside, point.distance_to(center) - radius)
	return {
		"valid": true, "skin_section_length_m": length_m,
		"capsule_centerline_length_m": centerline_length, "radius_m": radius,
		"ellipse_semiaxes_m": (high - low) * 0.5, "ellipse_center_offsets_m": (high + low) * 0.5,
		"ellipse_is_transverse_bounds_proxy": true, "central_span_fraction": CENTRAL_SPAN,
		"sample_count": samples.size(), "central_sample_count": central_count,
		"skin_axial_bounds_m": axial_bounds, "skin_plane_depth_bounds_m": depth_bounds,
		"skin_convex_outline_plane_m": Geometry2D.convex_hull(projected),
		"transverse_u_world": transverse_u, "transverse_v_world": transverse_v,
		"max_sample_outside_capsule_m": outside,
		"capsule_contains_all_assigned_samples": outside <= 1.0e-7,
	}


func _plane_metrics(solver, snapshot: Dictionary, plane: Transform3D) -> Dictionary:
	var angle_sets: Array[Array] = [[0.0, 0.0, 0.0]]
	for index: int in range(3):
		for key: String in ["min_angles_rad", "max_angles_rad"]:
			var angles: Array = [0.0, 0.0, 0.0]
			angles[index] = float(snapshot[key][index])
			angle_sets.append(angles)
	var max_depth: float = 0.0
	var max_tilt: float = 0.0
	var samples: Array[Dictionary] = []
	for values: Array in angle_sets:
		var angles: Array[float] = [float(values[0]), float(values[1]), float(values[2])]
		var fk: Dictionary = solver._forward_kinematics(snapshot, angles)
		var positions: Array = fk["joint_origins_world"].duplicate()
		positions.append(fk["tip_world"])
		var depths: Array[float] = []
		var projected := PackedVector2Array()
		for position: Vector3 in positions:
			var local: Vector3 = plane.affine_inverse() * position
			depths.append(local.z)
			projected.append(Vector2(local.x, local.y))
			max_depth = maxf(max_depth, absf(local.z))
		var tilts: Array[float] = []
		for transform: Transform3D in fk["joint_transforms_world"]:
			var local_normal: Vector3 = transform.basis.x.cross(transform.basis.y).normalized()
			var tilt: float = rad_to_deg(acos(clampf(absf(local_normal.dot(plane.basis.z)), 0.0, 1.0)))
			tilts.append(tilt)
			max_tilt = maxf(max_tilt, tilt)
		samples.append({"angles_rad": angles, "points_plane_m": projected, "depths_m": depths, "normal_tilts_degrees": tilts})
	return {"max_sample_depth_m": max_depth, "max_sample_normal_tilt_degrees": max_tilt,
		"samples": samples, "sampled_only": true, "combined_angle_extrema_not_exhaustive": true}


func _register_frame(registry, origin_id: StringName, frame: Transform3D, machine: Transform3D, phase: StringName) -> bool:
	var record = OriginScript.new()
	record.origin_id = origin_id
	record.parent_origin_id = OriginScript.ORIGIN_RL_BONE_ROOT
	record.transform_to_parent = machine.affine_inverse() * frame
	record.owner_system = &"digit_anatomy_proof_preparator"
	record.resolve_phase = phase
	record.space_type = OriginScript.SPACE_TYPE_BONE_FRAME
	record.is_dynamic = true
	return registry.register_origin(record) and bool(registry.validate_origin_chain(origin_id).get("ok", false))


func _input_reason(snapshot: Dictionary, samples: Dictionary, context: Dictionary) -> String:
	if not bool(snapshot.get("valid", false)):
		return "invalid_source_snapshot"
	if context.get("machine_origin_id") != OriginScript.ORIGIN_RL_BONE_ROOT or snapshot.get("bone_root_origin_id") != OriginScript.ORIGIN_RL_BONE_ROOT:
		return "missing_RL_BoneRoot_source"
	if not context.get("machine_to_world") is Transform3D or not _frame_valid(context["machine_to_world"]):
		return "invalid_machine_to_world"
	if context.get("resolve_phase") != OriginScript.PHASE_EDITOR_PREVIEW and context.get("resolve_phase") != OriginScript.PHASE_BAKE_TIME:
		return "unsupported_preparation_phase"
	for key: String in ["bone_names", "relative_transforms", "base_pose_rotations", "neutral_local_rotations", "hinge_axes_local", "min_angles_rad", "max_angles_rad"]:
		if not snapshot.get(key) is Array or snapshot[key].size() != 3:
			return "missing_three_element_" + key
	if not snapshot.get("root_parent_world") is Transform3D or not _frame_valid(snapshot["root_parent_world"]):
		return "invalid_parent_frame"
	if not snapshot.get("tip_offset_local") is Vector3 or not (snapshot["tip_offset_local"] as Vector3).is_finite() or (snapshot["tip_offset_local"] as Vector3).length_squared() <= 0.0 or snapshot.get("tip_offset_origin_id") != snapshot["bone_names"][2]:
		return "missing_named_terminal_direction"
	for index: int in range(3):
		if not snapshot["relative_transforms"][index] is Transform3D or not _frame_valid(snapshot["relative_transforms"][index]):
			return "invalid_relative_frame"
		for key: String in ["base_pose_rotations", "neutral_local_rotations"]:
			if not snapshot[key][index] is Quaternion or not (snapshot[key][index] as Quaternion).is_finite() or (snapshot[key][index] as Quaternion).length_squared() <= 0.0:
				return "invalid_" + key
		if not snapshot["hinge_axes_local"][index] is Vector3 or not (snapshot["hinge_axes_local"][index] as Vector3).is_equal_approx(Vector3(0.0, 0.0, 1.0)):
			return "unsupported_declared_hinge_axis"
		for key: String in ["min_angles_rad", "max_angles_rad"]:
			if not (snapshot[key][index] is float or snapshot[key][index] is int) or not is_finite(float(snapshot[key][index])):
				return "invalid_" + key
		if float(snapshot["min_angles_rad"][index]) > float(snapshot["max_angles_rad"][index]):
			return "inverted_angle_limits"
		var name: StringName = snapshot["bone_names"][index]
		if not samples.get(name) is Dictionary or samples[name].get("origin_id") != name or samples[name].get("root_origin_id") != OriginScript.ORIGIN_RL_BONE_ROOT:
			return "missing_named_bone_skin_patch:" + String(name)
		if not samples[name].get("points_bone_local") is PackedVector3Array or samples[name]["points_bone_local"].size() < 3:
			return "insufficient_bone_skin_samples:" + String(name)
		for point: Vector3 in samples[name]["points_bone_local"]:
			if not point.is_finite():
				return "nonfinite_skin_point"
	return ""


func _frame_valid(frame: Transform3D) -> bool:
	return frame.is_finite() and is_finite(frame.basis.determinant()) and frame.basis.determinant() != 0.0
