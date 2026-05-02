extends RefCounted
class_name PlayerRigModelPresenter

func apply_target_height_scale(josie_model: Node3D, mesh_instance: MeshInstance3D, standing_height_meters: float) -> float:
	if josie_model == null or mesh_instance == null or mesh_instance.mesh == null:
		return 0.0
	var source_height_meters: float = mesh_instance.mesh.get_aabb().size.y
	if source_height_meters <= 0.001:
		return 0.0
	var scale_factor: float = standing_height_meters / source_height_meters
	josie_model.scale = Vector3.ONE * scale_factor
	return source_height_meters * scale_factor

func ensure_hand_attachment(
	skeleton: Skeleton3D,
	attachment_name: String,
	bone_name: StringName,
	anchor_name: String,
	anchor_position: Vector3,
	anchor_rotation_degrees: Vector3
) -> void:
	if skeleton == null:
		return
	var attachment: BoneAttachment3D = skeleton.get_node_or_null(attachment_name) as BoneAttachment3D
	if attachment == null:
		attachment = BoneAttachment3D.new()
		attachment.name = attachment_name
		skeleton.add_child(attachment)
	attachment.bone_name = bone_name

	var anchor: Node3D = attachment.get_node_or_null(anchor_name) as Node3D
	if anchor == null:
		anchor = Node3D.new()
		anchor.name = anchor_name
		attachment.add_child(anchor)
	anchor.position = anchor_position
	anchor.rotation_degrees = anchor_rotation_degrees

func ensure_stow_attachment(
	skeleton: Skeleton3D,
	attachment_name: String,
	bone_name: StringName,
	anchor_name: String,
	anchor_position: Vector3,
	anchor_rotation_degrees: Vector3
) -> void:
	ensure_hand_attachment(skeleton, attachment_name, bone_name, anchor_name, anchor_position, anchor_rotation_degrees)

func get_right_hand_item_anchor(root: Node) -> Node3D:
	return root.get_node_or_null("JosieModel/Josie/Skeleton3D/RightHandAttachment/RightHandItemAnchor") as Node3D

func get_left_hand_item_anchor(root: Node) -> Node3D:
	return root.get_node_or_null("JosieModel/Josie/Skeleton3D/LeftHandAttachment/LeftHandItemAnchor") as Node3D

func get_weapon_stow_anchor(root: Node, stow_mode: StringName, slot_id: StringName) -> Node3D:
	var normalized_mode: StringName = CraftedItemWIP.normalize_stow_position_mode(stow_mode)
	if normalized_mode == CraftedItemWIP.STOW_SIDE_HIP:
		if slot_id == &"hand_right":
			return root.get_node_or_null("JosieModel/Josie/Skeleton3D/LeftHipStowAttachment/LeftHipStowAnchor") as Node3D
		if slot_id == &"hand_left":
			return root.get_node_or_null("JosieModel/Josie/Skeleton3D/RightHipStowAttachment/RightHipStowAnchor") as Node3D
	elif normalized_mode == CraftedItemWIP.STOW_LOWER_BACK:
		if slot_id == &"hand_right":
			return root.get_node_or_null("JosieModel/Josie/Skeleton3D/RightLowerBackStowAttachment/RightLowerBackStowAnchor") as Node3D
		if slot_id == &"hand_left":
			return root.get_node_or_null("JosieModel/Josie/Skeleton3D/LeftLowerBackStowAttachment/LeftLowerBackStowAnchor") as Node3D
	else:
		if slot_id == &"hand_right":
			return root.get_node_or_null("JosieModel/Josie/Skeleton3D/LeftShoulderStowAttachment/LeftShoulderStowAnchor") as Node3D
		if slot_id == &"hand_left":
			return root.get_node_or_null("JosieModel/Josie/Skeleton3D/RightShoulderStowAttachment/RightShoulderStowAnchor") as Node3D
	return null

func resolve_max_model_arm_reach_meters(
	skeleton: Skeleton3D,
	right_hand_bone_name: StringName,
	left_hand_bone_name: StringName,
	right_hand_anchor_position: Vector3,
	left_hand_anchor_position: Vector3,
	bone_index_cache: Dictionary
) -> float:
	if skeleton == null:
		return 0.0
	var right_hand_bone_index: int = get_bone_index(skeleton, right_hand_bone_name, bone_index_cache)
	var left_hand_bone_index: int = get_bone_index(skeleton, left_hand_bone_name, bone_index_cache)
	if right_hand_bone_index < 0 or left_hand_bone_index < 0:
		return 0.0
	var right_hand_anchor_rest_position: Vector3 = resolve_anchor_rest_global_position(skeleton, right_hand_bone_index, right_hand_anchor_position)
	var left_hand_anchor_rest_position: Vector3 = resolve_anchor_rest_global_position(skeleton, left_hand_bone_index, left_hand_anchor_position)
	return right_hand_anchor_rest_position.distance_to(left_hand_anchor_rest_position)

func resolve_arm_chain_reach_meters(
	skeleton: Skeleton3D,
	clavicle_bone_name: StringName,
	upperarm_bone_name: StringName,
	forearm_bone_name: StringName,
	hand_bone_name: StringName,
	hand_anchor_position: Vector3,
	bone_index_cache: Dictionary
) -> float:
	if skeleton == null:
		return 0.0
	var clavicle_index: int = get_bone_index(skeleton, clavicle_bone_name, bone_index_cache)
	var upperarm_index: int = get_bone_index(skeleton, upperarm_bone_name, bone_index_cache)
	var forearm_index: int = get_bone_index(skeleton, forearm_bone_name, bone_index_cache)
	var hand_index: int = get_bone_index(skeleton, hand_bone_name, bone_index_cache)
	if clavicle_index < 0 or upperarm_index < 0 or forearm_index < 0 or hand_index < 0:
		return 0.0
	var clavicle_rest_world: Vector3 = resolve_bone_rest_global_position(skeleton, clavicle_index)
	var upperarm_rest_world: Vector3 = resolve_bone_rest_global_position(skeleton, upperarm_index)
	var forearm_rest_world: Vector3 = resolve_bone_rest_global_position(skeleton, forearm_index)
	var hand_rest_world: Vector3 = resolve_bone_rest_global_position(skeleton, hand_index)
	var hand_anchor_rest_world: Vector3 = resolve_anchor_rest_global_position(skeleton, hand_index, hand_anchor_position)
	return clavicle_rest_world.distance_to(upperarm_rest_world) \
		+ upperarm_rest_world.distance_to(forearm_rest_world) \
		+ forearm_rest_world.distance_to(hand_rest_world) \
		+ hand_rest_world.distance_to(hand_anchor_rest_world)

func get_bone_world_position(
	owner_global_position: Vector3,
	skeleton: Skeleton3D,
	bone_name: StringName,
	bone_index_cache: Dictionary
) -> Vector3:
	var bone_idx: int = get_bone_index(skeleton, bone_name, bone_index_cache)
	if bone_idx < 0 or skeleton == null:
		return owner_global_position
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_idx).origin)

func get_bone_index(skeleton: Skeleton3D, bone_name: StringName, bone_index_cache: Dictionary) -> int:
	if bone_name == StringName():
		return -1
	if bone_index_cache.has(bone_name):
		return int(bone_index_cache[bone_name])
	var bone_idx: int = skeleton.find_bone(String(bone_name)) if skeleton != null else -1
	bone_index_cache[bone_name] = bone_idx
	return bone_idx

func resolve_anchor_rest_global_position(skeleton: Skeleton3D, bone_index: int, anchor_local_position: Vector3) -> Vector3:
	if skeleton == null or bone_index < 0:
		return Vector3.ZERO
	var bone_global_rest: Transform3D = get_bone_global_rest_transform(skeleton, bone_index)
	var anchor_local_rest_position: Vector3 = bone_global_rest * anchor_local_position
	return skeleton.to_global(anchor_local_rest_position)

func resolve_bone_rest_global_position(skeleton: Skeleton3D, bone_index: int) -> Vector3:
	if skeleton == null or bone_index < 0:
		return Vector3.ZERO
	return skeleton.to_global(get_bone_global_rest_transform(skeleton, bone_index).origin)

func get_bone_global_rest_transform(skeleton: Skeleton3D, bone_index: int) -> Transform3D:
	if skeleton == null or bone_index < 0:
		return Transform3D.IDENTITY
	var bone_rest: Transform3D = skeleton.get_bone_rest(bone_index)
	var parent_bone_index: int = skeleton.get_bone_parent(bone_index)
	if parent_bone_index < 0:
		return bone_rest
	return get_bone_global_rest_transform(skeleton, parent_bone_index) * bone_rest
