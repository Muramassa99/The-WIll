extends SceneTree

const PlayerScene = preload("res://scenes/player/player_character.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_hand_grip_pose_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var player_root: Node = PlayerScene.instantiate()
	root.add_child(player_root)
	await process_frame
	await process_frame

	var player = player_root as PlayerController3D
	var rig: PlayerHumanoidRig = player.humanoid_rig as PlayerHumanoidRig if player != null else null
	var skeleton: Skeleton3D = rig.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if rig != null else null

	var hand_index: int = skeleton.find_bone("CC_Base_R_Hand") if skeleton != null else -1
	var index_1: int = skeleton.find_bone("CC_Base_R_Index1") if skeleton != null else -1
	var index_2: int = skeleton.find_bone("CC_Base_R_Index2") if skeleton != null else -1
	var thumb_1: int = skeleton.find_bone("CC_Base_R_Thumb1") if skeleton != null else -1

	var hand_before: Quaternion = skeleton.get_bone_pose_rotation(hand_index) if skeleton != null and hand_index >= 0 else Quaternion.IDENTITY
	var index1_before: Quaternion = skeleton.get_bone_pose_rotation(index_1) if skeleton != null and index_1 >= 0 else Quaternion.IDENTITY
	var index2_before: Quaternion = skeleton.get_bone_pose_rotation(index_2) if skeleton != null and index_2 >= 0 else Quaternion.IDENTITY
	var thumb1_before: Quaternion = skeleton.get_bone_pose_rotation(thumb_1) if skeleton != null and thumb_1 >= 0 else Quaternion.IDENTITY
	var desired_offsets: Dictionary = rig._build_hand_grip_offsets(&"hand_right", true) if rig != null else {}

	if rig != null:
		rig.set_hand_grip_active(&"hand_right", true)
		rig._apply_bone_pose_rotation(&"CC_Base_R_Index1", rig.finger_grip_proximal_rotation_degrees)
	await process_frame
	await process_frame

	var hand_grip: Quaternion = skeleton.get_bone_pose_rotation(hand_index) if skeleton != null and hand_index >= 0 else Quaternion.IDENTITY
	var index1_grip: Quaternion = skeleton.get_bone_pose_rotation(index_1) if skeleton != null and index_1 >= 0 else Quaternion.IDENTITY
	var index2_grip: Quaternion = skeleton.get_bone_pose_rotation(index_2) if skeleton != null and index_2 >= 0 else Quaternion.IDENTITY
	var thumb1_grip: Quaternion = skeleton.get_bone_pose_rotation(thumb_1) if skeleton != null and thumb_1 >= 0 else Quaternion.IDENTITY

	if rig != null:
		rig.set_hand_grip_active(&"hand_right", false)
	await process_frame
	await process_frame

	var hand_after_clear: Quaternion = skeleton.get_bone_pose_rotation(hand_index) if skeleton != null and hand_index >= 0 else Quaternion.IDENTITY
	var index1_after_clear: Quaternion = skeleton.get_bone_pose_rotation(index_1) if skeleton != null and index_1 >= 0 else Quaternion.IDENTITY

	var lines: PackedStringArray = []
	lines.append("player_loaded=%s" % str(player != null))
	lines.append("rig_loaded=%s" % str(rig != null))
	lines.append("skeleton_loaded=%s" % str(skeleton != null))
	lines.append("apply_runtime_hand_grip_pose=%s" % str(rig.apply_runtime_hand_grip_pose if rig != null else false))
	lines.append("finger_grip_proximal_rotation=%s" % str(rig.finger_grip_proximal_rotation_degrees if rig != null else Vector3.ZERO))
	lines.append("finger_grip_middle_rotation=%s" % str(rig.finger_grip_middle_rotation_degrees if rig != null else Vector3.ZERO))
	lines.append("finger_grip_distal_rotation=%s" % str(rig.finger_grip_distal_rotation_degrees if rig != null else Vector3.ZERO))
	lines.append("right_thumb_grip_rotations=%s" % str(rig.right_thumb_grip_rotations_degrees if rig != null else []))
	lines.append("hand_bone_exists=%s" % str(hand_index >= 0))
	lines.append("index1_exists=%s" % str(index_1 >= 0))
	lines.append("index2_exists=%s" % str(index_2 >= 0))
	lines.append("thumb1_exists=%s" % str(thumb_1 >= 0))
	lines.append("desired_offset_count=%d" % desired_offsets.size())
	lines.append("desired_offsets_has_hand=%s" % str(hand_index >= 0 and desired_offsets.has(hand_index)))
	lines.append("desired_offsets_has_index1=%s" % str(index_1 >= 0 and desired_offsets.has(index_1)))
	lines.append("desired_offsets_has_index2=%s" % str(index_2 >= 0 and desired_offsets.has(index_2)))
	lines.append("desired_offsets_has_thumb1=%s" % str(thumb_1 >= 0 and desired_offsets.has(thumb_1)))
	lines.append("hand_rotated_for_grip=%s" % str(not hand_before.is_equal_approx(hand_grip)))
	lines.append("index1_rotated_for_grip=%s" % str(not index1_before.is_equal_approx(index1_grip)))
	lines.append("index2_rotated_for_grip=%s" % str(not index2_before.is_equal_approx(index2_grip)))
	lines.append("thumb1_rotated_for_grip=%s" % str(not thumb1_before.is_equal_approx(thumb1_grip)))
	lines.append("hand_released_from_grip_pose=%s" % str(not hand_grip.is_equal_approx(hand_after_clear)))
	lines.append("index1_released_from_grip_pose=%s" % str(not index1_grip.is_equal_approx(index1_after_clear)))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
