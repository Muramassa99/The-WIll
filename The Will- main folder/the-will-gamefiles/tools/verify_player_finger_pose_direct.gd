extends SceneTree

const PlayerScene = preload("res://scenes/player/player_character.tscn")
const RESULT_FILE_PATH := "C:/WORKSPACE/player_finger_pose_direct_results.txt"

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
	var thumb_1: int = skeleton.find_bone("CC_Base_R_Thumb1") if skeleton != null else -1

	var hand_before: Quaternion = skeleton.get_bone_pose_rotation(hand_index) if skeleton != null and hand_index >= 0 else Quaternion.IDENTITY
	var index1_before: Quaternion = skeleton.get_bone_pose_rotation(index_1) if skeleton != null and index_1 >= 0 else Quaternion.IDENTITY
	var thumb1_before: Quaternion = skeleton.get_bone_pose_rotation(thumb_1) if skeleton != null and thumb_1 >= 0 else Quaternion.IDENTITY

	if skeleton != null:
		if hand_index >= 0:
			skeleton.set_bone_pose_rotation(hand_index, hand_before * _degrees_to_quaternion(Vector3(-10.0, 8.0, -12.0)))
		if index_1 >= 0:
			skeleton.set_bone_pose_rotation(index_1, index1_before * _degrees_to_quaternion(Vector3(28.0, 0.0, 0.0)))
		if thumb_1 >= 0:
			skeleton.set_bone_pose_rotation(thumb_1, thumb1_before * _degrees_to_quaternion(Vector3(8.0, -18.0, 24.0)))

	await process_frame
	await process_frame

	var hand_after: Quaternion = skeleton.get_bone_pose_rotation(hand_index) if skeleton != null and hand_index >= 0 else Quaternion.IDENTITY
	var index1_after: Quaternion = skeleton.get_bone_pose_rotation(index_1) if skeleton != null and index_1 >= 0 else Quaternion.IDENTITY
	var thumb1_after: Quaternion = skeleton.get_bone_pose_rotation(thumb_1) if skeleton != null and thumb_1 >= 0 else Quaternion.IDENTITY

	var lines: PackedStringArray = []
	lines.append("player_loaded=%s" % str(player != null))
	lines.append("rig_loaded=%s" % str(rig != null))
	lines.append("skeleton_loaded=%s" % str(skeleton != null))
	lines.append("hand_direct_rotation_changed=%s" % str(not hand_before.is_equal_approx(hand_after)))
	lines.append("index1_direct_rotation_changed=%s" % str(not index1_before.is_equal_approx(index1_after)))
	lines.append("thumb1_direct_rotation_changed=%s" % str(not thumb1_before.is_equal_approx(thumb1_after)))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _degrees_to_quaternion(local_rotation_degrees: Vector3) -> Quaternion:
	return Quaternion.from_euler(Vector3(
		deg_to_rad(local_rotation_degrees.x),
		deg_to_rad(local_rotation_degrees.y),
		deg_to_rad(local_rotation_degrees.z)
	))
