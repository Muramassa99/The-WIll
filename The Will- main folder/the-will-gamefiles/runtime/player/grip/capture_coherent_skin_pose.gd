extends RefCounted

const Origins = preload("res://core/models/combat_origin_record.gd")
const OWNER := &"coherent_skin_pose_capture"
const MESH_ORIGIN := &"CoherentCharacterSkinMeshOrigin"

## Read one complete current pose, without advancing animation, resetting bones,
## applying a solver, or measuring anatomy again. The supplied signature belongs
## to a validated prepared definition; its reference geometry must still match.
func capture(skeleton: Skeleton3D, mesh: MeshInstance3D, reference: Dictionary, anatomy_signature: String, pose_id: StringName, phase: StringName = &"editor_preview") -> Dictionary:
	var started := Time.get_ticks_usec()
	if skeleton == null or mesh == null or mesh.mesh == null or mesh.skin == null:
		return _fail("missing_current_character_skin")
	if not skeleton.is_inside_tree() or not mesh.is_inside_tree() or mesh.get_node_or_null(mesh.skeleton) != skeleton:
		return _fail("mesh_does_not_use_supplied_live_skeleton")
	if anatomy_signature.is_empty() or pose_id == StringName():
		return _fail("missing_anatomy_signature_or_pose_id")
	if phase not in [Origins.PHASE_BAKE_TIME, Origins.PHASE_EDITOR_PREVIEW, Origins.PHASE_POST_FINAL_POSE]:
		return _fail("unsupported_capture_phase")
	var matched := _reference_matches(skeleton, mesh, reference)
	if not bool(matched.get("valid", false)):
		return matched
	var reference_validation_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var root_index := skeleton.find_bone(Origins.ORIGIN_RL_BONE_ROOT)
	if root_index < 0:
		return _fail("missing_machine_root_bone")
	var skeleton_to_world := skeleton.global_transform
	var machine_to_world: Transform3D = skeleton_to_world * skeleton.get_bone_global_pose(root_index)
	if not _valid_frame(skeleton_to_world) or not _valid_frame(machine_to_world) or not _valid_frame(mesh.global_transform):
		return _fail("invalid_current_character_frame")
	var world_to_machine := machine_to_world.affine_inverse()
	var records: Array[Dictionary] = [_record(Origins.ORIGIN_RL_BONE_ROOT, StringName(), Transform3D.IDENTITY, phase, Origins.SPACE_TYPE_MACHINE)]
	var bone_ids := {}
	var source_parent_ids := {}
	for name: StringName in reference.bind_bone_names:
		if bone_ids.has(name):
			continue
		var bone := skeleton.find_bone(name)
		if not _descends_from(skeleton, bone, root_index):
			return _fail("skin_bind_does_not_descend_from_machine_root", {"bone_name": name})
		var parent := skeleton.get_bone_parent(bone)
		source_parent_ids[name] = StringName(skeleton.get_bone_name(parent)) if parent >= 0 else StringName()
		if name == Origins.ORIGIN_RL_BONE_ROOT:
			bone_ids[name] = Origins.ORIGIN_RL_BONE_ROOT
			continue
		var id := StringName(String(name) + "CoherentSkinPoseOrigin")
		var frame: Transform3D = world_to_machine * skeleton_to_world * skeleton.get_bone_global_pose(bone)
		if not _valid_frame(frame):
			return _fail("invalid_current_skin_bind_frame", {"bone_name": name})
		bone_ids[name] = id
		records.append(_record(id, Origins.ORIGIN_RL_BONE_ROOT, frame, phase, Origins.SPACE_TYPE_BONE_FRAME))
	var mesh_to_machine: Transform3D = world_to_machine * mesh.global_transform
	if not _valid_frame(mesh_to_machine):
		return _fail("invalid_current_mesh_frame")
	records.append(_record(MESH_ORIGIN, Origins.ORIGIN_RL_BONE_ROOT, mesh_to_machine, phase, Origins.SPACE_TYPE_PRESENTATION))
	return {"valid": true, "schema": &"coherent_skin_pose_capture_v1", "anatomy_signature": anatomy_signature,
		"root_origin_id": Origins.ORIGIN_RL_BONE_ROOT, "pose_id": pose_id, "resolve_phase": phase,
		"machine_to_world": machine_to_world, "mesh_origin_id": MESH_ORIGIN, "bone_origin_ids": bone_ids,
		"origin_records": records, "source_bone_parent_ids": source_parent_ids,
		"reference_correspondence_verified": true, "all_skin_bind_poses_captured": true,
		"pose_read_without_scene_writes": true, "anatomy_measurement_ran": false,
		"production_pose_written": false, "actual_3d_grip_verified": false,
		"reference_validation_ms": reference_validation_ms,
		"capture_timing_scope": &"reference_validation_and_scene_pose_read_diagnostic_only",
		"capture_ms": float(Time.get_ticks_usec() - started) / 1000.0}


func _reference_matches(skeleton: Skeleton3D, mesh: MeshInstance3D, reference: Dictionary) -> Dictionary:
	for field: String in ["bind_bone_names", "bind_poses", "bind_global_rests", "surfaces"]:
		if not reference.get(field) is Array or reference[field].is_empty():
			return _fail("missing_prepared_reference_" + field)
	var count := mesh.skin.get_bind_count()
	if reference.bind_bone_names.size() != count or reference.bind_poses.size() != count or reference.bind_global_rests.size() != count:
		return _fail("current_skin_bind_count_changed")
	for bind: int in range(count):
		var name := mesh.skin.get_bind_name(bind)
		var bone := skeleton.find_bone(name) if name != StringName() else mesh.skin.get_bind_bone(bind)
		if bone < 0 or bone >= skeleton.get_bone_count():
			return _fail("unresolved_current_skin_bind")
		name = skeleton.get_bone_name(bone)
		if name != reference.bind_bone_names[bind]:
			return _fail("current_skin_bind_names_changed", {"bind_index": bind})
		if mesh.skin.get_bind_pose(bind) != reference.bind_poses[bind] or skeleton.get_bone_global_rest(bone) != reference.bind_global_rests[bind]:
			return _fail("current_bind_or_bone_rest_changed", {"bone_name": name,
				"bind_pose_equal": mesh.skin.get_bind_pose(bind) == reference.bind_poses[bind],
				"global_rest_equal": skeleton.get_bone_global_rest(bone) == reference.bind_global_rests[bind]})
	# Saved geometry already includes its preparation morph state. This initial
	# capture adapter proves zero-morph correspondence only; it never substitutes
	# unmorphed vertices or triggers a mesh bake to conceal an unsupported case.
	for index: int in range(mesh.mesh.get_blend_shape_count()):
		if mesh.get_blend_shape_value(index) != 0.0:
			return _fail("active_morph_requires_explicit_reference_validation")
	if mesh.mesh.get_surface_count() != reference.surfaces.size():
		return _fail("current_reference_surface_count_changed")
	for index: int in range(reference.surfaces.size()):
		var arrays: Array = mesh.mesh.surface_get_arrays(index)
		if arrays.size() != Mesh.ARRAY_MAX or not reference.surfaces[index] is Dictionary:
			return _fail("invalid_current_or_saved_surface", {"surface_index": index})
		var saved: Dictionary = reference.surfaces[index]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		if arrays[Mesh.ARRAY_VERTEX] != saved.get("vertices") or arrays[Mesh.ARRAY_BONES] != saved.get("bones") or arrays[Mesh.ARRAY_WEIGHTS] != saved.get("weights") or indices != saved.get("indices"):
			return _fail("current_reference_surface_arrays_changed", {"surface_index": index})
	return {"valid": true}


func _descends_from(skeleton: Skeleton3D, bone: int, root: int) -> bool:
	for _step: int in range(skeleton.get_bone_count()):
		if bone == root:
			return true
		if bone < 0 or bone >= skeleton.get_bone_count():
			return false
		bone = skeleton.get_bone_parent(bone)
	return false


func _record(id: StringName, parent: StringName, frame: Transform3D, phase: StringName, space: StringName) -> Dictionary:
	return {"origin_id": id, "parent_origin_id": parent, "transform_to_parent": frame,
		"owner_system": OWNER, "resolve_phase": phase, "space_type": space,
		"is_dynamic": id != Origins.ORIGIN_RL_BONE_ROOT}


func _valid_frame(frame: Transform3D) -> bool:
	return frame.is_finite() and is_finite(frame.basis.determinant()) and absf(frame.basis.determinant()) > 1.0e-12


func _fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"valid": false, "reason": reason, "details": details,
		"production_pose_written": false, "actual_3d_grip_verified": false}
