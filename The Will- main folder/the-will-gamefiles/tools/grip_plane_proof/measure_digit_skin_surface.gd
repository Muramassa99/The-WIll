extends RefCounted

const SolverScript = preload("res://runtime/player/player_finger_surface_grip_solver.gd")
const OriginScript = preload("res://core/models/combat_origin_record.gd")
const RegistryScript = preload("res://core/resolvers/combat_origin_registry.gd")
const RAY_EPSILON_M: float = 1.0e-7

## Offline linear blend skinning. Other bones use hand-rebased global rests;
## only the requested three bone frames use the supplied calibrated FK pose.
## Input weights are summed unchanged, never normalized or threshold-filtered.
func build_skin_world(snapshot: Dictionary, reference: Dictionary, context: Dictionary, angles: Array[float]) -> Dictionary:
	var reason: String = _input_reason(snapshot, reference, context, angles)
	if not reason.is_empty():
		return {"valid": false, "reason": reason}
	var started: int = Time.get_ticks_usec()
	var solver = SolverScript.new()
	var fk: Dictionary = solver._forward_kinematics(snapshot, angles)
	var joint_frames: Array = fk["joint_transforms_world"]
	var names: Array = snapshot["bone_names"]
	var hand_rest: Transform3D = reference["hand_global_rests"][context["hand_bone_name"]]
	var skeleton_to_world: Transform3D = (snapshot["root_parent_world"] as Transform3D) * hand_rest.affine_inverse()
	var root_bind_index: int = reference["bind_bone_names"].find(OriginScript.ORIGIN_RL_BONE_ROOT)
	var mesh_to_skeleton: Transform3D = (reference["bind_global_rests"][root_bind_index] as Transform3D) * (reference["mesh_origin_record"]["transform_to_parent"] as Transform3D)
	var mesh_to_world: Transform3D = skeleton_to_world * mesh_to_skeleton
	if not _frame_valid(mesh_to_world):
		return {"valid": false, "reason": "invalid_hand_rebased_mesh_frame"}
	var registry = RegistryScript.new()
	var mesh_origin = OriginScript.new()
	mesh_origin.origin_id = &"HandRebasedSkinMeshOrigin"
	mesh_origin.parent_origin_id = OriginScript.ORIGIN_RL_BONE_ROOT
	mesh_origin.transform_to_parent = (context["machine_to_world"] as Transform3D).affine_inverse() * mesh_to_world
	mesh_origin.owner_system = &"digit_skin_surface_measurement"
	mesh_origin.resolve_phase = context["resolve_phase"]
	mesh_origin.space_type = OriginScript.SPACE_TYPE_PRESENTATION
	mesh_origin.is_dynamic = true
	if not registry.register_origin(mesh_origin) or not bool(registry.validate_origin_chain(mesh_origin.origin_id).get("ok", false)):
		return {"valid": false, "reason": "hand_rebased_mesh_registration_failed"}
	var skin_frames: Array[Transform3D] = []
	var bind_is_digit: Array[bool] = []
	for index: int in range(reference["bind_bone_names"].size()):
		var bone_world: Transform3D = skeleton_to_world * reference["bind_global_rests"][index]
		var digit_index: int = names.find(reference["bind_bone_names"][index])
		if digit_index >= 0:
			bone_world = joint_frames[digit_index]
		skin_frames.append(bone_world * reference["bind_poses"][index])
		bind_is_digit.append(digit_index >= 0)
	var surfaces: Array[Dictionary] = []
	var triangles := PackedVector3Array()
	var triangle_surfaces := PackedInt32Array()
	var triangle_local_ids := PackedInt32Array()
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var weight_min: float = INF
	var weight_max: float = -INF
	var vertex_count: int = 0
	var digit_vertex_count: int = 0
	for surface_index: int in range(reference["surfaces"].size()):
		var source: Dictionary = reference["surfaces"][surface_index]
		var vertices: PackedVector3Array = source["vertices"]
		var bones: PackedInt32Array = source["bones"]
		var weights: PackedFloat32Array = source["weights"]
		var influence_count: int = weights.size() / vertices.size()
		var world := PackedVector3Array()
		var digit_mask := PackedByteArray()
		for vertex_index: int in range(vertices.size()):
			var position := Vector3.ZERO
			var weight_sum: float = 0.0
			var touches_digit: bool = false
			for influence: int in range(influence_count):
				var offset: int = vertex_index * influence_count + influence
				var weight: float = weights[offset]
				if weight == 0.0:
					continue
				var bind_index: int = bones[offset]
				if bind_index < 0 or bind_index >= skin_frames.size() or not is_finite(weight) or weight < 0.0:
					return {"valid": false, "reason": "invalid_vertex_influence", "surface": surface_index, "vertex": vertex_index}
				position += weight * (skin_frames[bind_index] * vertices[vertex_index])
				weight_sum += weight
				touches_digit = touches_digit or bind_is_digit[bind_index]
			# Renderer skinning writes weighted local XYZ, then presentation adds
			# the mesh translation once. Summing world-space bone transforms above
			# included that translation weight_sum times. Correct only this term;
			# the bake API's additional residual rest vertex is not rendered skin.
			position += (1.0 - weight_sum) * mesh_to_world.origin
			if not position.is_finite() or weight_sum <= 0.0:
				return {"valid": false, "reason": "invalid_skinned_vertex", "surface": surface_index, "vertex": vertex_index}
			world.append(position)
			digit_mask.append(1 if touches_digit else 0)
			weight_min = minf(weight_min, weight_sum)
			weight_max = maxf(weight_max, weight_sum)
			low = low.min(position)
			high = high.max(position)
			vertex_count += 1
			digit_vertex_count += 1 if touches_digit else 0
		var indices: PackedInt32Array = source["indices"].duplicate()
		if indices.is_empty():
			for vertex_index: int in range(vertices.size()):
				indices.append(vertex_index)
		if indices.size() % 3 != 0:
			return {"valid": false, "reason": "non_triangle_surface"}
		for offset: int in range(0, indices.size(), 3):
			for corner: int in range(3):
				var index: int = indices[offset + corner]
				if index < 0 or index >= world.size():
					return {"valid": false, "reason": "invalid_triangle_index"}
				triangles.append(world[index])
			triangle_surfaces.append(surface_index)
			triangle_local_ids.append(offset / 3)
		surfaces.append({"vertices_world": world, "indices": indices, "digit_influence_mask": digit_mask})
	if triangles.is_empty():
		return {"valid": false, "reason": "no_skin_triangles"}
	return {"valid": true, "surfaces": surfaces, "triangles_world": triangles,
		"reference_vertices_origin_id": reference["vertices_origin_id"],
		"reference_mesh_origin_record": reference["mesh_origin_record"].duplicate(true),
		"reference_bone_origin_records": reference["bone_origin_records"].duplicate(true),
		"resolved_vertices_origin_id": OriginScript.ORIGIN_RL_BONE_ROOT,
		"posed_mesh_origin_id": mesh_origin.origin_id, "mesh_to_skeleton": mesh_to_skeleton,
		"mesh_to_world": mesh_to_world, "posed_mesh_to_machine": mesh_origin.transform_to_parent,
		"posed_mesh_origin_record": mesh_origin, "posed_mesh_origin_chain": registry.validate_origin_chain(mesh_origin.origin_id), "registry": registry,
		"triangle_surface_ids": triangle_surfaces, "triangle_local_ids": triangle_local_ids,
		"joint_transforms_world": joint_frames, "skeleton_to_world": skeleton_to_world,
		"machine_to_world": context["machine_to_world"], "root_origin_id": OriginScript.ORIGIN_RL_BONE_ROOT,
		"resolve_phase": context["resolve_phase"], "hand_bone_name": context["hand_bone_name"],
		"bounds_world": AABB(low, high - low), "weight_sum_min": weight_min, "weight_sum_max": weight_max,
		"vertex_count": vertex_count, "digit_influenced_vertex_count": digit_vertex_count,
		"weights_normalized_by_tool": false, "other_bones_use_hand_rebased_rest": true,
		"rendering_convention": "weighted_local_xyz_then_mesh_world_translation_once",
		"bake_api_adds_residual_rest_vertex": true,
		"bake_minus_render_world_formula": "(1 - weight_sum) * mesh_to_world.basis * reference_vertex",
		"engine_bake_parity_validated": false, "elapsed_milliseconds": float(Time.get_ticks_usec() - started) / 1000.0}


## Nearest positive ray hits are measurements of the posed triangle surface.
## Four hits do not certify an ellipse, interior classification or full contact.
func measure(snapshot: Dictionary, reference: Dictionary, context: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var zero_angles: Array[float] = [0.0, 0.0, 0.0]
	var skin: Dictionary = build_skin_world(snapshot, reference, context, zero_angles)
	if not bool(skin.get("valid", false)):
		return skin
	var frames: Array = skin["joint_transforms_world"]
	var first: Transform3D = frames[0]
	var normal: Vector3 = first.basis.x.cross(first.basis.y).normalized()
	var direction: Vector3 = (frames[1] as Transform3D).origin - first.origin
	var axis_u: Vector3 = (direction - normal * direction.dot(normal)).normalized()
	if axis_u.length_squared() < 0.5:
		return {"valid": false, "reason": "degenerate_digit_motion_plane"}
	var plane := Transform3D(Basis(axis_u, normal.cross(axis_u).normalized(), normal), first.origin)
	var machine: Transform3D = context["machine_to_world"]
	var plane_id := StringName(String(snapshot["bone_names"][0]) + "SkinRayPlaneOrigin")
	var registry = skin["registry"]
	var record = OriginScript.new()
	record.origin_id = plane_id
	record.parent_origin_id = OriginScript.ORIGIN_RL_BONE_ROOT
	record.transform_to_parent = machine.affine_inverse() * plane
	record.owner_system = &"digit_skin_surface_measurement"
	record.resolve_phase = context["resolve_phase"]
	record.space_type = OriginScript.SPACE_TYPE_BONE_FRAME
	record.is_dynamic = true
	if not registry.register_origin(record) or not bool(registry.validate_origin_chain(plane_id).get("ok", false)):
		return {"valid": false, "reason": "skin_ray_plane_registration_failed"}
	var terminal: Transform3D = frames[2]
	var terminal_axis: Vector3 = (terminal.basis * (snapshot["tip_offset_local"] as Vector3).normalized()).normalized()
	var tip: Dictionary = _ray(skin, terminal.origin, terminal_axis, plane, plane_id)
	tip["source_bone_name"] = snapshot["bone_names"][2]
	tip["direction_source_origin_id"] = snapshot["tip_offset_origin_id"]
	var sections: Array[Dictionary] = []
	var complete: bool = bool(tip["hit"])
	for index: int in range(3):
		if index == 2 and not bool(tip["hit"]):
			sections.append({"available": false, "reason": "missing_positive_terminal_skin_hit", "bone_name": snapshot["bone_names"][index]})
			continue
		var start: Vector3 = (frames[index] as Transform3D).origin
		var end: Vector3 = (frames[index + 1] as Transform3D).origin if index < 2 else tip["position_world"]
		var section_axis: Vector3 = (end - start).normalized()
		var transverse: Vector3 = normal.cross(section_axis).normalized()
		if start.distance_to(end) <= RAY_EPSILON_M or transverse.length_squared() < 0.5:
			return {"valid": false, "reason": "degenerate_skin_measurement_section", "section": index}
		var fractions: Array = [0.3, 0.5, 0.7] if index == 2 else [0.2, 0.5, 0.8]
		var cross_sections: Array[Dictionary] = []
		for fraction: float in fractions:
			var center: Vector3 = start.lerp(end, fraction)
			var rays: Dictionary = {}
			var available: bool = true
			for pair: Array in [["u_plus", transverse], ["u_minus", -transverse], ["normal_plus", normal], ["normal_minus", -normal]]:
				rays[pair[0]] = _ray(skin, center, pair[1], plane, plane_id)
				available = available and bool(rays[pair[0]]["hit"])
			var row: Dictionary = {"fraction": fraction, "origin_id": plane_id, "center_world": center,
				"center_in_plane_m": plane.affine_inverse() * center, "available": available, "rays": rays}
			if available:
				var plus := Vector2(rays["u_plus"]["distance_m"], rays["normal_plus"]["distance_m"])
				var minus := Vector2(rays["u_minus"]["distance_m"], rays["normal_minus"]["distance_m"])
				row["ellipse_semiaxes_from_four_rays_m"] = (plus + minus) * 0.5
				row["ellipse_center_offsets_from_four_rays_m"] = (plus - minus) * 0.5
			complete = complete and available
			cross_sections.append(row)
		sections.append({"available": true, "bone_name": snapshot["bone_names"][index],
			"axis_length_m": start.distance_to(end), "cross_sections": cross_sections})
	return {"valid": true, "complete": complete, "sections": sections, "terminal_tip_ray": tip,
		"posed_mesh_origin_id": skin["posed_mesh_origin_id"], "mesh_to_world": skin["mesh_to_world"],
		"posed_mesh_origin_record": skin["posed_mesh_origin_record"], "posed_mesh_origin_chain": skin["posed_mesh_origin_chain"],
		"rendering_convention": skin["rendering_convention"], "bake_api_adds_residual_rest_vertex": true,
		"reference_vertices_origin_id": reference["vertices_origin_id"],
		"reference_mesh_origin_record": reference["mesh_origin_record"].duplicate(true),
		"plane_origin_id": plane_id, "plane_to_world": plane, "plane_to_machine": machine.affine_inverse() * plane,
		"machine_to_world": machine, "root_origin_id": OriginScript.ORIGIN_RL_BONE_ROOT, "resolve_phase": context["resolve_phase"],
		"origin_chain": registry.validate_origin_chain(plane_id), "registry": registry,
		"weight_sum_min": skin["weight_sum_min"], "weight_sum_max": skin["weight_sum_max"],
		"triangle_count": (skin["triangles_world"] as PackedVector3Array).size() / 3,
		"skinning_elapsed_milliseconds": skin["elapsed_milliseconds"], "engine_bake_parity_validated": false,
		"ray_measurement_only": true, "interior_classification_validated": false, "ellipse_fit_or_contact_certified": false,
		"elapsed_milliseconds": float(Time.get_ticks_usec() - started) / 1000.0}


func _ray(skin: Dictionary, start: Vector3, direction: Vector3, plane: Transform3D, origin_id: StringName) -> Dictionary:
	var bounds: AABB = skin["bounds_world"]
	# This finite segment reaches beyond the entire measured mesh from the
	# requested origin. A miss stays a miss; there is no guessed local radius.
	var length_m: float = start.distance_to(bounds.get_center()) + bounds.size.length() + RAY_EPSILON_M
	var end: Vector3 = start + direction * length_m
	var triangles: PackedVector3Array = skin["triangles_world"]
	var nearest: float = INF
	var triangle_id: int = -1
	var origin_hits: int = 0
	var position := Vector3.ZERO
	var ray_low: Vector3 = start.min(end) - Vector3.ONE * RAY_EPSILON_M
	var ray_high: Vector3 = start.max(end) + Vector3.ONE * RAY_EPSILON_M
	for offset: int in range(0, triangles.size(), 3):
		var a: Vector3 = triangles[offset]
		var b: Vector3 = triangles[offset + 1]
		var c: Vector3 = triangles[offset + 2]
		var low: Vector3 = a.min(b).min(c)
		var high: Vector3 = a.max(b).max(c)
		if low.x > ray_high.x or high.x < ray_low.x or low.y > ray_high.y or high.y < ray_low.y or low.z > ray_high.z or high.z < ray_low.z:
			continue
		var hit: Variant = Geometry3D.segment_intersects_triangle(start, end, a, b, c)
		if not hit is Vector3:
			continue
		var distance: float = (hit as Vector3).distance_to(start)
		if distance <= RAY_EPSILON_M:
			origin_hits += 1
		elif distance < nearest:
			nearest = distance
			position = hit
			triangle_id = offset / 3
	var result: Dictionary = {"hit": triangle_id >= 0, "origin_id": origin_id, "start_world": start,
		"segment_end_world": end, "direction_world": direction, "start_in_plane_m": plane.affine_inverse() * start,
		"origin_hit_count": origin_hits, "positive_hit_epsilon_m": RAY_EPSILON_M}
	if triangle_id >= 0:
		result.merge({"distance_m": nearest, "position_world": position, "position_in_plane_m": plane.affine_inverse() * position,
			"surface_index": skin["triangle_surface_ids"][triangle_id], "surface_triangle_index": skin["triangle_local_ids"][triangle_id]})
	return result


func _input_reason(snapshot: Dictionary, reference: Dictionary, context: Dictionary, angles: Array[float]) -> String:
	if snapshot.get("bone_root_origin_id") != OriginScript.ORIGIN_RL_BONE_ROOT or context.get("machine_origin_id") != OriginScript.ORIGIN_RL_BONE_ROOT:
		return "missing_named_machine_frame"
	if not context.get("machine_to_world") is Transform3D or not _frame_valid(context["machine_to_world"]) or not snapshot.get("root_parent_world") is Transform3D or not _frame_valid(snapshot["root_parent_world"]):
		return "invalid_machine_or_hand_frame"
	if context.get("resolve_phase") != OriginScript.PHASE_EDITOR_PREVIEW and context.get("resolve_phase") != OriginScript.PHASE_BAKE_TIME:
		return "unsupported_skin_measurement_phase"
	if not reference.get("mesh_origin_record") is Dictionary or not reference.get("bone_origin_records") is Dictionary:
		return "missing_reference_origin_records"
	var mesh_record: Dictionary = reference["mesh_origin_record"]
	if StringName(reference.get("vertices_origin_id", &"")) == StringName() or mesh_record.get("origin_id") != reference["vertices_origin_id"] or mesh_record.get("parent_origin_id") != OriginScript.ORIGIN_RL_BONE_ROOT or mesh_record.get("resolve_phase") != OriginScript.PHASE_BAKE_TIME or not mesh_record.get("transform_to_parent") is Transform3D or not _frame_valid(mesh_record["transform_to_parent"]):
		return "invalid_named_reference_mesh_frame"
	if not reference.get("hand_global_rests") is Dictionary or not reference["hand_global_rests"].get(context.get("hand_bone_name")) is Transform3D or not _frame_valid(reference["hand_global_rests"][context["hand_bone_name"]]):
		return "missing_explicit_hand_rest"
	for key: String in ["bone_names", "relative_transforms", "neutral_local_rotations", "hinge_axes_local"]:
		if not snapshot.get(key) is Array or snapshot[key].size() != 3:
			return "invalid_three_joint_" + key
	if angles.size() != 3 or not snapshot.get("tip_offset_local") is Vector3 or not (snapshot["tip_offset_local"] as Vector3).is_finite() or (snapshot["tip_offset_local"] as Vector3).length_squared() <= 0.0 or snapshot.get("tip_offset_origin_id") != snapshot["bone_names"][2]:
		return "invalid_angles_or_named_terminal_direction"
	for index: int in range(3):
		if not is_finite(angles[index]) or not snapshot["relative_transforms"][index] is Transform3D or not _frame_valid(snapshot["relative_transforms"][index]):
			return "invalid_joint_angle_or_frame"
		if not snapshot["neutral_local_rotations"][index] is Quaternion or not (snapshot["neutral_local_rotations"][index] as Quaternion).is_finite() or (snapshot["neutral_local_rotations"][index] as Quaternion).length_squared() <= 0.0:
			return "invalid_joint_neutral_rotation"
		if not snapshot["hinge_axes_local"][index] is Vector3 or not (snapshot["hinge_axes_local"][index] as Vector3).is_finite() or (snapshot["hinge_axes_local"][index] as Vector3).length_squared() <= 0.0:
			return "invalid_declared_hinge_axis"
	for key: String in ["bind_bone_names", "bind_poses", "bind_global_rests", "surfaces"]:
		if not reference.get(key) is Array or reference[key].is_empty():
			return "missing_reference_" + key
	if reference["bind_bone_names"].size() != reference["bind_poses"].size() or reference["bind_bone_names"].size() != reference["bind_global_rests"].size():
		return "mismatched_skin_bind_arrays"
	if not reference["bind_bone_names"].has(OriginScript.ORIGIN_RL_BONE_ROOT):
		return "missing_RL_BoneRoot_bind_rest_for_mesh_frame"
	for index: int in range(reference["bind_bone_names"].size()):
		var name: StringName = reference["bind_bone_names"][index]
		var record: Dictionary = reference["bone_origin_records"].get(name, {})
		var expected_parent: StringName = StringName() if name == OriginScript.ORIGIN_RL_BONE_ROOT else OriginScript.ORIGIN_RL_BONE_ROOT
		if record.get("origin_id") != name or record.get("parent_origin_id") != expected_parent or record.get("resolve_phase") != OriginScript.PHASE_BAKE_TIME or not record.get("transform_to_parent") is Transform3D or not _frame_valid(record["transform_to_parent"]):
			return "invalid_named_reference_bone_frame"
		for key: String in ["bind_poses", "bind_global_rests"]:
			if not reference[key][index] is Transform3D or not _frame_valid(reference[key][index]):
				return "invalid_" + key
	for surface: Dictionary in reference["surfaces"]:
		if not surface.get("vertices") is PackedVector3Array or surface["vertices"].is_empty() or not surface.get("indices") is PackedInt32Array or not surface.get("bones") is PackedInt32Array or not surface.get("weights") is PackedFloat32Array:
			return "invalid_skin_surface_arrays"
		if surface["weights"].is_empty() or surface["weights"].size() % surface["vertices"].size() != 0 or surface["bones"].size() != surface["weights"].size():
			return "mismatched_skin_influences"
		for vertex: Vector3 in surface["vertices"]:
			if not vertex.is_finite():
				return "nonfinite_reference_vertex"
	return ""


func _frame_valid(frame: Transform3D) -> bool:
	return frame.is_finite() and is_finite(frame.basis.determinant()) and frame.basis.determinant() != 0.0
