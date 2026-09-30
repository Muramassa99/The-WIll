extends "res://runtime/player/grip/weighted_skin_plane_slicer.gd"

const SkinMeasurement = preload("res://tools/grip_plane_proof/measure_digit_skin_surface.gd")
const Spatial = preload("res://runtime/player/player_finger_surface_grip_solver.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
const Slicer = preload("res://tools/grip_plane_proof/slice_reachable_surface.gd")

# Per-acquisition coefficient preparation, using already exported anatomy.
# No rays, guessed radii, weight normalization or dominant-bone selection.
# The captured hand and plane stay fixed for the lifetime of this query.
func prepare(snapshot: Dictionary, reference: Dictionary, context: Dictionary, plane: Transform3D, plane_origin_id: StringName) -> Dictionary:
	var started := Time.get_ticks_usec()
	if plane_origin_id == StringName() or plane_origin_id == Origins.ORIGIN_RL_BONE_ROOT or not Slicer.new()._valid_plane(plane):
		return {"valid": false, "reason": "missing_named_metric_plane"}
	var baseline: Dictionary = SkinMeasurement.new().build_skin_world(snapshot, reference, context, [0.0, 0.0, 0.0])
	if not bool(baseline.get("valid", false)):
		return baseline
	var names: Array = snapshot["bone_names"].duplicate()
	var registry = baseline["registry"]
	var plane_record = Origins.new()
	plane_record.origin_id = plane_origin_id
	plane_record.parent_origin_id = Origins.ORIGIN_RL_BONE_ROOT
	plane_record.transform_to_parent = (context["machine_to_world"] as Transform3D).affine_inverse() * plane
	plane_record.owner_system = &"prepared_digit_skin_query"
	plane_record.resolve_phase = context["resolve_phase"]
	plane_record.space_type = Origins.SPACE_TYPE_BONE_FRAME
	plane_record.is_dynamic = true
	if registry.has_origin(plane_origin_id) or not registry.register_origin(plane_record) or not bool(registry.validate_origin_chain(plane_origin_id).get("ok", false)):
		return {"valid": false, "reason": "invalid_plane_origin_chain"}
	var fixed_frames: Array[Transform3D] = []
	var selected_indices: Array[int] = []
	for index: int in range(reference["bind_bone_names"].size()):
		fixed_frames.append((baseline["skeleton_to_world"] as Transform3D) * reference["bind_global_rests"][index] * reference["bind_poses"][index])
		selected_indices.append(names.find(reference["bind_bone_names"][index]))
	var vertices := PackedVector3Array()
	var constants := PackedVector3Array()
	var coefficients: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array(), PackedVector3Array()]
	var selected_weights := PackedVector3Array()
	var dynamic_vertices := PackedInt32Array()
	var triangles := PackedInt32Array()
	var triangle_surface_ids := PackedInt32Array()
	var triangle_local_ids := PackedInt32Array()
	var dynamic_triangles := PackedInt32Array()
	var static_triangles := PackedInt32Array()
	var surface_ranges: Array[Dictionary] = []
	for surface_index: int in range(reference["surfaces"].size()):
		var source: Dictionary = reference["surfaces"][surface_index]
		var points: PackedVector3Array = source["vertices"]
		var bones: PackedInt32Array = source["bones"]
		var weights: PackedFloat32Array = source["weights"]
		var influences: int = weights.size() / points.size()
		var first_vertex := vertices.size()
		var first_triangle: int = triangles.size() / 3
		for vertex_index: int in range(points.size()):
			var constant := Vector3.ZERO
			var selected := Vector3.ZERO
			var weighted: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
			var weight_sum := 0.0
			for influence: int in range(influences):
				var offset := vertex_index * influences + influence
				var weight: float = weights[offset]
				if weight == 0.0:
					continue
				var bind: int = bones[offset]
				var joint: int = selected_indices[bind]
				if joint >= 0:
					weighted[joint] += weight * ((reference["bind_poses"][bind] as Transform3D) * points[vertex_index])
					selected[joint] += weight
				else:
					constant += weight * (fixed_frames[bind] * points[vertex_index])
				weight_sum += weight
			# Renderer adds presentation translation once after weighted local XYZ.
			constant += (1.0 - weight_sum) * (baseline["mesh_to_world"] as Transform3D).origin
			constants.append(constant)
			selected_weights.append(selected)
			for joint: int in range(3):
				coefficients[joint].append(weighted[joint])
			vertices.append(baseline["surfaces"][surface_index]["vertices_world"][vertex_index])
			if selected.x > 0.0 or selected.y > 0.0 or selected.z > 0.0:
				dynamic_vertices.append(first_vertex + vertex_index)
		var indices: PackedInt32Array = baseline["surfaces"][surface_index]["indices"]
		for offset: int in range(0, indices.size(), 3):
			var triangle_id: int = triangles.size() / 3
			var dynamic := false
			for corner: int in range(3):
				var vertex_id := first_vertex + indices[offset + corner]
				triangles.append(vertex_id)
				var selected: Vector3 = selected_weights[vertex_id]
				dynamic = dynamic or selected.x > 0.0 or selected.y > 0.0 or selected.z > 0.0
			triangle_surface_ids.append(surface_index)
			triangle_local_ids.append(offset / 3)
			if dynamic:
				dynamic_triangles.append(triangle_id)
			else:
				static_triangles.append(triangle_id)
		surface_ranges.append({"surface_index": surface_index, "first_vertex": first_vertex, "vertex_count": points.size(), "first_triangle": first_triangle, "triangle_count": indices.size() / 3})
	var query := {"valid": true, "snapshot": snapshot.duplicate(true), "context": context.duplicate(true),
		"plane_to_world": plane, "plane_origin_id": plane_origin_id, "plane_origin_record": plane_record,
		"plane_origin_chain": registry.validate_origin_chain(plane_origin_id), "registry": registry,
		"bone_ids": names, "weighted_bind_point_origin_ids": names.duplicate(),
		"fixed_contributions_world": constants, "weighted_bind_points": coefficients, "selected_weights": selected_weights,
		"baseline_vertices_world": vertices, "dynamic_vertex_ids": dynamic_vertices,
		"triangle_indices": triangles, "triangle_surface_ids": triangle_surface_ids, "triangle_local_ids": triangle_local_ids,
		"dynamic_triangle_ids": dynamic_triangles, "static_triangle_ids": static_triangles, "surface_ranges": surface_ranges,
		"root_origin_id": Origins.ORIGIN_RL_BONE_ROOT, "resolved_world_origin_id": Origins.ORIGIN_RL_BONE_ROOT,
		"machine_to_world": context["machine_to_world"], "resolve_phase": context["resolve_phase"],
		"reference_vertices_origin_id": reference["vertices_origin_id"], "reference_mesh_origin_record": reference["mesh_origin_record"].duplicate(true),
		"reference_bone_origin_records": reference["bone_origin_records"].duplicate(true),
		"posed_mesh_origin_id": baseline["posed_mesh_origin_id"], "posed_mesh_origin_record": baseline["posed_mesh_origin_record"],
		"posed_mesh_origin_chain": baseline["posed_mesh_origin_chain"], "other_bones_use_hand_rebased_rest": true,
		"weights_normalized_by_tool": false, "anatomy_measurement_ran": false, "classification_incomplete": true}
	query["static_segments"] = _slice_triangles(query, vertices, static_triangles, false)
	query["preparation_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	return query

func pose(query: Dictionary, angles: Array[float]) -> Dictionary:
	var started := Time.get_ticks_usec()
	if not bool(query.get("valid", false)) or angles.size() != 3:
		return {"valid": false, "reason": "invalid_prepared_query_or_angles"}
	for index: int in range(3):
		if not is_finite(angles[index]):
			return {"valid": false, "reason": "nonfinite_joint_angle"}
		for field: String in ["min_angles_rad", "max_angles_rad"]:
			if not query["snapshot"].get(field) is Array or query["snapshot"][field].size() != 3:
				return {"valid": false, "reason": "missing_declared_joint_ranges"}
		if angles[index] < float(query["snapshot"]["min_angles_rad"][index]) or angles[index] > float(query["snapshot"]["max_angles_rad"][index]):
			return {"valid": false, "reason": "angle_outside_declared_joint_range"}
	var fk: Dictionary = Spatial.new()._forward_kinematics(query["snapshot"], angles)
	var joints: Array = fk["joint_transforms_world"]
	var vertices: PackedVector3Array = query["baseline_vertices_world"].duplicate()
	var constants: PackedVector3Array = query["fixed_contributions_world"]
	var coefficients: Array = query["weighted_bind_points"]
	var weights: PackedVector3Array = query["selected_weights"]
	for vertex: int in query["dynamic_vertex_ids"]:
		var point: Vector3 = constants[vertex]
		for joint: int in range(3):
			if weights[vertex][joint] > 0.0:
				var frame: Transform3D = joints[joint]
				point += frame.basis * coefficients[joint][vertex] + frame.origin * weights[vertex][joint]
		vertices[vertex] = point
	var skinning_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var dynamic_segments := _slice_triangles(query, vertices, query["dynamic_triangle_ids"], true)
	var segments: Array = query["static_segments"].duplicate()
	segments.append_array(dynamic_segments)
	var joint_ids: Array[StringName] = []
	var joint_records: Array[Dictionary] = []
	for index: int in range(3):
		var id := StringName(String(query["bone_ids"][index]) + "PreparedSkinPoseOrigin")
		joint_ids.append(id)
		joint_records.append({"origin_id": id, "parent_origin_id": Origins.ORIGIN_RL_BONE_ROOT,
			"transform_to_parent": (query["machine_to_world"] as Transform3D).affine_inverse() * joints[index],
			"owner_system": &"prepared_digit_skin_query", "resolve_phase": query["resolve_phase"],
			"space_type": Origins.SPACE_TYPE_BONE_FRAME, "is_dynamic": true})
	return {"valid": true, "vertices_world": vertices, "surface_ranges": query["surface_ranges"],
		"segments": segments, "dynamic_segments": dynamic_segments, "static_segment_count": query["static_segments"].size(),
		"joint_transforms_world": joints, "joint_origin_ids": joint_ids, "joint_origin_records": joint_records,
		"joint_origins_world": fk["joint_origins_world"], "tip_world": fk["tip_world"], "tip_origin_id": joint_ids[2],
		"angles_rad": angles.duplicate(), "bone_ids": query["bone_ids"], "plane_origin_id": query["plane_origin_id"],
		"plane_to_world": query["plane_to_world"], "plane_origin_record": query["plane_origin_record"], "plane_origin_chain": query["plane_origin_chain"],
		"root_origin_id": query["root_origin_id"], "resolved_world_origin_id": query["resolved_world_origin_id"],
		"machine_to_world": query["machine_to_world"], "resolve_phase": query["resolve_phase"],
		"posed_mesh_origin_id": query["posed_mesh_origin_id"], "posed_mesh_origin_record": query["posed_mesh_origin_record"], "posed_mesh_origin_chain": query["posed_mesh_origin_chain"],
		"vertex_count": vertices.size(), "updated_vertex_count": query["dynamic_vertex_ids"].size(),
		"triangle_count": query["triangle_indices"].size() / 3, "updated_triangle_count": query["dynamic_triangle_ids"].size(),
		"skinning_ms": skinning_ms, "elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"anatomy_measurement_ran": false, "classification_incomplete": true, "segment_soup_is_not_closed_solid": true,
		"other_bones_use_hand_rebased_rest": true, "weights_normalized_by_tool": false}
