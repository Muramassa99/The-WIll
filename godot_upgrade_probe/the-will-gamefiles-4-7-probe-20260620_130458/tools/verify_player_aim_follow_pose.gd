extends SceneTree

const PlayerScene = preload("res://scenes/player/player_character.tscn")
const RESULT_FILE_PATH := "C:/WORKSPACE/player_aim_follow_pose_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var player_root: Node = PlayerScene.instantiate()
	root.add_child(player_root)
	await process_frame
	await process_frame

	var player := player_root as PlayerController3D
	var rig: PlayerHumanoidRig = player.humanoid_rig as PlayerHumanoidRig if player != null else null
	var skeleton: Skeleton3D = rig.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if rig != null else null

	var waist_index: int = skeleton.find_bone("CC_Base_Waist") if skeleton != null else -1
	var spine02_index: int = skeleton.find_bone("CC_Base_Spine02") if skeleton != null else -1
	var head_index: int = skeleton.find_bone("CC_Base_Head") if skeleton != null else -1

	var waist_before: Quaternion = skeleton.get_bone_pose_rotation(waist_index) if waist_index >= 0 else Quaternion.IDENTITY
	var spine02_before: Quaternion = skeleton.get_bone_pose_rotation(spine02_index) if spine02_index >= 0 else Quaternion.IDENTITY
	var head_before: Quaternion = skeleton.get_bone_pose_rotation(head_index) if head_index >= 0 else Quaternion.IDENTITY

	if player != null:
		player.camera_pivot.rotation = Vector3(deg_to_rad(-22.0), deg_to_rad(28.0), 0.0)
		player._refresh_aim_context()
		player._sync_humanoid_aim_follow()

	for _i in range(14):
		await process_frame

	var waist_after: Quaternion = skeleton.get_bone_pose_rotation(waist_index) if waist_index >= 0 else Quaternion.IDENTITY
	var spine02_after: Quaternion = skeleton.get_bone_pose_rotation(spine02_index) if spine02_index >= 0 else Quaternion.IDENTITY
	var head_after: Quaternion = skeleton.get_bone_pose_rotation(head_index) if head_index >= 0 else Quaternion.IDENTITY

	var waist_angle_delta: float = waist_before.angle_to(waist_after)
	var spine02_angle_delta: float = spine02_before.angle_to(spine02_after)
	var head_angle_delta: float = head_before.angle_to(head_after)

	var lines: PackedStringArray = []
	lines.append("player_loaded=%s" % str(player != null))
	lines.append("rig_loaded=%s" % str(rig != null))
	lines.append("skeleton_loaded=%s" % str(skeleton != null))
	lines.append("waist_bone_exists=%s" % str(waist_index >= 0))
	lines.append("spine02_bone_exists=%s" % str(spine02_index >= 0))
	lines.append("head_bone_exists=%s" % str(head_index >= 0))
	lines.append("waist_changed=%s" % str(waist_angle_delta > 0.0001))
	lines.append("spine02_changed=%s" % str(spine02_angle_delta > 0.0001))
	lines.append("head_changed=%s" % str(head_angle_delta > 0.0001))
	lines.append("waist_angle_delta=%s" % str(snapped(waist_angle_delta, 0.0001)))
	lines.append("spine02_angle_delta=%s" % str(snapped(spine02_angle_delta, 0.0001)))
	lines.append("head_angle_delta=%s" % str(snapped(head_angle_delta, 0.0001)))
	lines.append("head_leads_waist=%s" % str(head_angle_delta > waist_angle_delta))
	lines.append("spine_leads_waist=%s" % str(spine02_angle_delta > waist_angle_delta))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
