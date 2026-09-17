extends RefCounted

## Character preparation input, independent of the held object. Skin bind poses
## map mesh reference vertices into named bone frames. Contributing skin weights
## select the source patch; the subsequent envelope is an approximation of it.
func capture(skeleton: Skeleton3D, mesh_instance: MeshInstance3D, bone_names: Array) -> Dictionary:
	if skeleton == null or mesh_instance == null or mesh_instance.mesh == null or mesh_instance.skin == null:
		return {"valid": false, "reason": "missing_character_mesh_or_skin"}
	var mesh: Mesh = mesh_instance.mesh
	var skin: Skin = mesh_instance.skin
	var bind_bones: Array[StringName] = []
	var bind_frames: Array[Transform3D] = []
	var bind_global_rests: Array[Transform3D] = []
	var bind_rest_error: float = 0.0
	for bind_index: int in range(skin.get_bind_count()):
		var name: StringName = skin.get_bind_name(bind_index)
		var index: int = skeleton.find_bone(name) if name != StringName() else skin.get_bind_bone(bind_index)
		if index < 0 or index >= skeleton.get_bone_count():
			return {"valid": false, "reason": "unresolved_skin_bind"}
		name = skeleton.get_bone_name(index)
		bind_bones.append(name)
		bind_frames.append(skin.get_bind_pose(bind_index))
		bind_global_rests.append(skeleton.get_bone_global_rest(index))
		var reference: Transform3D = skeleton.global_transform * skeleton.get_bone_global_rest(index) * skin.get_bind_pose(bind_index)
		bind_rest_error = maxf(bind_rest_error, reference.origin.distance_to(mesh_instance.global_transform.origin))
		for axis: int in range(3):
			bind_rest_error = maxf(bind_rest_error, (reference.basis[axis] - mesh_instance.global_basis[axis]).length())
	# This check establishes the bind-frame convention for the current imported
	# model before those coordinates are used as anatomy data.
	if bind_rest_error > 0.0001:
		return {"valid": false, "reason": "skin_bind_reference_mismatch", "max_bind_reference_component_error": bind_rest_error}
	var blend_values: Array[float] = []
	var has_blend: bool = false
	for index: int in range(mesh.get_blend_shape_count()):
		var weight: float = mesh_instance.get_blend_shape_value(index)
		blend_values.append(weight)
		has_blend = has_blend or not is_zero_approx(weight)
	var geometry: Mesh = mesh_instance.bake_mesh_from_current_blend_shape_mix() if has_blend else mesh
	if geometry == null or geometry.get_surface_count() != mesh.get_surface_count():
		return {"valid": false, "reason": "missing_blended_character_geometry"}
	var samples: Dictionary = {}
	var influenced_counts: Dictionary = {}
	for name: StringName in bone_names:
		samples[name] = {"points_bone_local": PackedVector3Array(), "skin_weights": PackedFloat32Array(), "origin_id": name, "root_origin_id": &"RL_BoneRoot", "selection": "contributing_skin_weight_above_0.0001"}
		influenced_counts[name] = 0
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	var reference_surfaces: Array = []
	for surface_index: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var geometry_arrays: Array = geometry.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = geometry_arrays[Mesh.ARRAY_VERTEX]
		var bone_indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var indices: PackedInt32Array = geometry_arrays[Mesh.ARRAY_INDEX] if geometry_arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		reference_surfaces.append({"vertices": vertices, "indices": indices, "bones": bone_indices, "weights": weights})
		if vertices.is_empty() or weights.size() % vertices.size() != 0 or bone_indices.size() != weights.size():
			return {"valid": false, "reason": "invalid_skin_vertex_arrays"}
		var influences: int = weights.size() / vertices.size()
		hash_context.update(var_to_bytes([vertices, bone_indices, weights]))
		for vertex_index: int in range(vertices.size()):
			for influence: int in range(influences):
				var offset: int = vertex_index * influences + influence
				if weights[offset] > 0.0001 and bone_indices[offset] >= 0 and bone_indices[offset] < bind_bones.size():
					var influenced_bone: StringName = bind_bones[bone_indices[offset]]
					if influenced_counts.has(influenced_bone):
						influenced_counts[influenced_bone] += 1
						var local_points: PackedVector3Array = samples[influenced_bone]["points_bone_local"]
						var sample_weights: PackedFloat32Array = samples[influenced_bone]["skin_weights"]
						local_points.append(bind_frames[bone_indices[offset]] * vertices[vertex_index])
						sample_weights.append(weights[offset])
						samples[influenced_bone]["points_bone_local"] = local_points
						samples[influenced_bone]["skin_weights"] = sample_weights
	var rests: Array = []
	for name: StringName in bone_names:
		var index: int = skeleton.find_bone(name)
		if index < 0 or (samples[name]["points_bone_local"] as PackedVector3Array).is_empty():
			var counts: Dictionary = {}
			for sampled: StringName in samples:
				counts[sampled] = samples[sampled]["points_bone_local"].size()
			return {"valid": false, "reason": "digit_has_no_skin_samples", "bone": name, "sample_counts": counts, "any_influence_counts": influenced_counts}
		rests.append([name, skeleton.get_bone_rest(index)])
	hash_context.update(var_to_bytes([rests, bind_bones, bind_frames, blend_values]))
	var hand_rests: Dictionary = {}
	for hand_name: StringName in [&"CC_Base_R_Hand", &"CC_Base_L_Hand"]:
		var index: int = skeleton.find_bone(hand_name)
		if index >= 0:
			hand_rests[hand_name] = skeleton.get_bone_global_rest(index)
	var root_index: int = skeleton.find_bone("RL_BoneRoot")
	if root_index < 0:
		return {"valid": false, "reason": "missing_character_machine_root"}
	var root_rest: Transform3D = skeleton.get_bone_global_rest(root_index)
	var mesh_to_skeleton: Transform3D = skeleton.global_transform.affine_inverse() * mesh_instance.global_transform
	var reference_origin := {"origin_id": &"CharacterSkinReferenceMeshOrigin", "parent_origin_id": &"RL_BoneRoot", "transform_to_parent": root_rest.affine_inverse() * mesh_to_skeleton, "owner_system": &"character_contact_measurement", "resolve_phase": &"bake_time", "is_dynamic": false}
	var bone_origins: Dictionary = {}
	for index: int in range(bind_bones.size()):
		bone_origins[bind_bones[index]] = {"origin_id": bind_bones[index], "parent_origin_id": StringName() if bind_bones[index] == &"RL_BoneRoot" else &"RL_BoneRoot", "transform_to_parent": root_rest.affine_inverse() * bind_global_rests[index], "owner_system": &"character_contact_measurement", "resolve_phase": &"bake_time", "is_dynamic": false}
	return {"valid": true, "samples": samples, "sampling_method": "contributing_weight_reference_vertices_via_skin_bind_pose", "model_identity": {"mesh_resource_path": mesh.resource_path, "skeleton_scene_path": skeleton.get_path(), "geometry_and_bind_sha256": hash_context.finish().hex_encode(), "blend_shape_values": blend_values}, "max_bind_reference_component_error": bind_rest_error,
		"reference_skin": {"surfaces": reference_surfaces, "vertices_origin_id": &"CharacterSkinReferenceMeshOrigin", "mesh_origin_record": reference_origin, "bone_origin_records": bone_origins, "bind_bone_names": bind_bones, "bind_poses": bind_frames, "bind_global_rests": bind_global_rests, "hand_global_rests": hand_rests}}
