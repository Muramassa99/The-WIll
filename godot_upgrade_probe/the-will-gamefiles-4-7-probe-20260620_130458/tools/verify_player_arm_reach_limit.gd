extends SceneTree

const RigScene: PackedScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const RESULT_FILE_PATH := "C:/WORKSPACE/player_arm_reach_limit_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var rig_root: PlayerHumanoidRig = RigScene.instantiate() as PlayerHumanoidRig
	rig_root.usable_arm_motion_range_ratio = 0.98
	root.add_child(rig_root)
	await process_frame
	await process_frame

	var skeleton: Skeleton3D = rig_root.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D
	var right_target: Node3D = Node3D.new()
	right_target.name = "VerifyRightFarReachTarget"
	root.add_child(right_target)
	var left_target: Node3D = Node3D.new()
	left_target.name = "VerifyLeftFarReachTarget"
	root.add_child(left_target)

	var right_limit: float = rig_root.get_usable_arm_chain_reach_meters(&"hand_right")
	var left_limit: float = rig_root.get_usable_arm_chain_reach_meters(&"hand_left")
	var right_clavicle: Vector3 = _get_bone_world_position(skeleton, "CC_Base_R_Clavicle")
	var left_clavicle: Vector3 = _get_bone_world_position(skeleton, "CC_Base_L_Clavicle")
	var right_direction: Vector3 = (rig_root.global_basis.z + rig_root.global_basis.x * -0.25 + Vector3.UP * 0.08).normalized()
	var left_direction: Vector3 = (rig_root.global_basis.z + rig_root.global_basis.x * 0.25 + Vector3.UP * 0.08).normalized()
	right_target.global_position = right_clavicle + right_direction * right_limit * 1.35
	left_target.global_position = left_clavicle + left_direction * left_limit * 1.35

	rig_root.set_dominant_grip_slot(&"hand_right")
	rig_root.set_arm_guidance_target(&"hand_right", right_target)
	rig_root.set_arm_guidance_active(&"hand_right", true)
	rig_root.set_arm_guidance_target(&"hand_left", left_target)
	rig_root.set_arm_guidance_active(&"hand_left", true)
	rig_root.apply_authoring_preview_frame_now()
	await process_frame
	rig_root.apply_authoring_preview_frame_now()
	await process_frame

	var right_ik_target: Node3D = rig_root.get_node_or_null("IkTargets/RightHandIkTarget") as Node3D
	var left_ik_target: Node3D = rig_root.get_node_or_null("IkTargets/LeftHandIkTarget") as Node3D
	var right_requested_distance: float = right_clavicle.distance_to(right_target.global_position)
	var left_requested_distance: float = left_clavicle.distance_to(left_target.global_position)
	var right_clamped_distance: float = right_clavicle.distance_to(right_ik_target.global_position) if right_ik_target != null else -1.0
	var left_clamped_distance: float = left_clavicle.distance_to(left_ik_target.global_position) if left_ik_target != null else -1.0
	var epsilon: float = 0.001

	var lines: PackedStringArray = []
	lines.append("rig_loaded=%s" % str(rig_root != null))
	lines.append("skeleton_loaded=%s" % str(skeleton != null))
	lines.append("usable_arm_motion_range_ratio=%s" % str(snapped(rig_root.get_usable_arm_motion_range_ratio(), 0.0001)))
	lines.append("right_max_arm_chain_reach_meters=%s" % str(snapped(rig_root.get_max_arm_chain_reach_meters(&"hand_right"), 0.0001)))
	lines.append("left_max_arm_chain_reach_meters=%s" % str(snapped(rig_root.get_max_arm_chain_reach_meters(&"hand_left"), 0.0001)))
	lines.append("right_usable_arm_chain_reach_meters=%s" % str(snapped(right_limit, 0.0001)))
	lines.append("left_usable_arm_chain_reach_meters=%s" % str(snapped(left_limit, 0.0001)))
	lines.append("right_requested_distance_meters=%s" % str(snapped(right_requested_distance, 0.0001)))
	lines.append("left_requested_distance_meters=%s" % str(snapped(left_requested_distance, 0.0001)))
	lines.append("right_clamped_distance_meters=%s" % str(snapped(right_clamped_distance, 0.0001)))
	lines.append("left_clamped_distance_meters=%s" % str(snapped(left_clamped_distance, 0.0001)))
	lines.append("right_requested_exceeded_limit=%s" % str(right_requested_distance > right_limit))
	lines.append("left_requested_exceeded_limit=%s" % str(left_requested_distance > left_limit))
	lines.append("right_limit_respected=%s" % str(right_clamped_distance >= 0.0 and right_clamped_distance <= right_limit + epsilon))
	lines.append("left_limit_respected=%s" % str(left_clamped_distance >= 0.0 and left_clamped_distance <= left_limit + epsilon))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _get_bone_world_position(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var bone_index: int = skeleton.find_bone(bone_name)
	if bone_index < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)
