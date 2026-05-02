extends SceneTree

const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const RESULT_FILE_PATH := "C:/WORKSPACE/player_upper_body_authoring_pose_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var rig_root: PlayerHumanoidRig = RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig_root)
	await process_frame
	await process_frame

	var skeleton: Skeleton3D = rig_root.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D
	var waist_index: int = skeleton.find_bone("CC_Base_Waist") if skeleton != null else -1
	var spine_index: int = skeleton.find_bone("CC_Base_Spine02") if skeleton != null else -1
	var right_clavicle_index: int = skeleton.find_bone("CC_Base_R_Clavicle") if skeleton != null else -1
	var left_clavicle_index: int = skeleton.find_bone("CC_Base_L_Clavicle") if skeleton != null else -1
	var right_upperarm_index: int = skeleton.find_bone("CC_Base_R_Upperarm") if skeleton != null else -1
	var left_upperarm_index: int = skeleton.find_bone("CC_Base_L_Upperarm") if skeleton != null else -1
	var right_forearm_index: int = skeleton.find_bone("CC_Base_R_Forearm") if skeleton != null else -1
	var left_forearm_index: int = skeleton.find_bone("CC_Base_L_Forearm") if skeleton != null else -1

	var waist_before: Quaternion = skeleton.get_bone_pose_rotation(waist_index) if waist_index >= 0 else Quaternion.IDENTITY
	var spine_before: Quaternion = skeleton.get_bone_pose_rotation(spine_index) if spine_index >= 0 else Quaternion.IDENTITY
	var right_clavicle_before: Quaternion = skeleton.get_bone_pose_rotation(right_clavicle_index) if right_clavicle_index >= 0 else Quaternion.IDENTITY
	var left_clavicle_before: Quaternion = skeleton.get_bone_pose_rotation(left_clavicle_index) if left_clavicle_index >= 0 else Quaternion.IDENTITY
	var right_upperarm_before: Quaternion = skeleton.get_bone_pose_rotation(right_upperarm_index) if right_upperarm_index >= 0 else Quaternion.IDENTITY
	var left_upperarm_before: Quaternion = skeleton.get_bone_pose_rotation(left_upperarm_index) if left_upperarm_index >= 0 else Quaternion.IDENTITY
	var right_forearm_before: Quaternion = skeleton.get_bone_pose_rotation(right_forearm_index) if right_forearm_index >= 0 else Quaternion.IDENTITY
	var left_forearm_before: Quaternion = skeleton.get_bone_pose_rotation(left_forearm_index) if left_forearm_index >= 0 else Quaternion.IDENTITY

	rig_root.set_upper_body_authoring_state({
		"active": true,
		"blend": 1.0,
		"two_hand": true,
		"dominant_slot_id": &"hand_right",
		"primary_target_world": rig_root.global_position + Vector3(0.32, 1.20, -0.68),
		"secondary_target_world": rig_root.global_position + Vector3(-0.22, 1.18, -0.52),
		"tip_world": rig_root.global_position + Vector3(0.58, 1.42, -1.08),
		"pommel_world": rig_root.global_position + Vector3(0.18, 1.02, -0.44),
	})

	for _step: int in range(8):
		await process_frame

	var waist_after: Quaternion = skeleton.get_bone_pose_rotation(waist_index) if waist_index >= 0 else Quaternion.IDENTITY
	var spine_after: Quaternion = skeleton.get_bone_pose_rotation(spine_index) if spine_index >= 0 else Quaternion.IDENTITY
	var right_clavicle_after: Quaternion = skeleton.get_bone_pose_rotation(right_clavicle_index) if right_clavicle_index >= 0 else Quaternion.IDENTITY
	var left_clavicle_after: Quaternion = skeleton.get_bone_pose_rotation(left_clavicle_index) if left_clavicle_index >= 0 else Quaternion.IDENTITY
	var right_upperarm_after: Quaternion = skeleton.get_bone_pose_rotation(right_upperarm_index) if right_upperarm_index >= 0 else Quaternion.IDENTITY
	var left_upperarm_after: Quaternion = skeleton.get_bone_pose_rotation(left_upperarm_index) if left_upperarm_index >= 0 else Quaternion.IDENTITY
	var right_forearm_after: Quaternion = skeleton.get_bone_pose_rotation(right_forearm_index) if right_forearm_index >= 0 else Quaternion.IDENTITY
	var left_forearm_after: Quaternion = skeleton.get_bone_pose_rotation(left_forearm_index) if left_forearm_index >= 0 else Quaternion.IDENTITY

	var lines: PackedStringArray = []
	lines.append("rig_loaded=%s" % str(rig_root != null))
	lines.append("skeleton_loaded=%s" % str(skeleton != null))
	lines.append("waist_changed=%s" % str(waist_before.angle_to(waist_after) > 0.0001))
	lines.append("spine_changed=%s" % str(spine_before.angle_to(spine_after) > 0.0001))
	lines.append("right_clavicle_changed=%s" % str(right_clavicle_before.angle_to(right_clavicle_after) > 0.0001))
	lines.append("left_clavicle_changed=%s" % str(left_clavicle_before.angle_to(left_clavicle_after) > 0.0001))
	lines.append("right_upperarm_changed=%s" % str(right_upperarm_before.angle_to(right_upperarm_after) > 0.0001))
	lines.append("left_upperarm_changed=%s" % str(left_upperarm_before.angle_to(left_upperarm_after) > 0.0001))
	lines.append("right_forearm_changed=%s" % str(right_forearm_before.angle_to(right_forearm_after) > 0.0001))
	lines.append("left_forearm_changed=%s" % str(left_forearm_before.angle_to(left_forearm_after) > 0.0001))
	lines.append("waist_angle_delta=%s" % str(snapped(waist_before.angle_to(waist_after), 0.0001)))
	lines.append("spine_angle_delta=%s" % str(snapped(spine_before.angle_to(spine_after), 0.0001)))
	lines.append("right_clavicle_angle_delta=%s" % str(snapped(right_clavicle_before.angle_to(right_clavicle_after), 0.0001)))
	lines.append("left_clavicle_angle_delta=%s" % str(snapped(left_clavicle_before.angle_to(left_clavicle_after), 0.0001)))
	lines.append("right_upperarm_angle_delta=%s" % str(snapped(right_upperarm_before.angle_to(right_upperarm_after), 0.0001)))
	lines.append("left_upperarm_angle_delta=%s" % str(snapped(left_upperarm_before.angle_to(left_upperarm_after), 0.0001)))
	lines.append("right_forearm_angle_delta=%s" % str(snapped(right_forearm_before.angle_to(right_forearm_after), 0.0001)))
	lines.append("left_forearm_angle_delta=%s" % str(snapped(left_forearm_before.angle_to(left_forearm_after), 0.0001)))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
