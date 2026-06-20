extends SceneTree

const PlayerScene = preload("res://scenes/player/player_character.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_skin_binding_results.txt"

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
	var mesh_instance: MeshInstance3D = rig.get_node_or_null("JosieModel/Josie/Skeleton3D/Mesh") as MeshInstance3D if rig != null else null
	var animation_player: AnimationPlayer = rig.get_node_or_null("JosieModel/AnimationPlayer") as AnimationPlayer if rig != null else null

	var upperarm_index: int = skeleton.find_bone("CC_Base_R_Upperarm") if skeleton != null else -1
	var hand_index: int = skeleton.find_bone("CC_Base_R_Hand") if skeleton != null else -1
	var upperarm_pose_before: Transform3D = skeleton.get_bone_global_pose_no_override(upperarm_index) if skeleton != null and upperarm_index >= 0 else Transform3D.IDENTITY
	var hand_pose_before: Transform3D = skeleton.get_bone_global_pose_no_override(hand_index) if skeleton != null and hand_index >= 0 else Transform3D.IDENTITY
	var hand_anchor_before: Transform3D = rig.get_right_hand_item_anchor().global_transform if rig != null and rig.get_right_hand_item_anchor() != null else Transform3D.IDENTITY

	if animation_player != null and animation_player.has_animation("Run"):
		animation_player.play("Run")
	for _i in range(12):
		await process_frame

	var upperarm_pose_after: Transform3D = skeleton.get_bone_global_pose_no_override(upperarm_index) if skeleton != null and upperarm_index >= 0 else Transform3D.IDENTITY
	var hand_pose_after: Transform3D = skeleton.get_bone_global_pose_no_override(hand_index) if skeleton != null and hand_index >= 0 else Transform3D.IDENTITY
	var hand_anchor_after: Transform3D = rig.get_right_hand_item_anchor().global_transform if rig != null and rig.get_right_hand_item_anchor() != null else Transform3D.IDENTITY

	var lines: PackedStringArray = []
	lines.append("player_loaded=%s" % str(player != null))
	lines.append("rig_loaded=%s" % str(rig != null))
	lines.append("skeleton_loaded=%s" % str(skeleton != null))
	lines.append("mesh_loaded=%s" % str(mesh_instance != null))
	lines.append("animation_player_loaded=%s" % str(animation_player != null))
	lines.append("mesh_has_skin=%s" % str(mesh_instance != null and mesh_instance.skin != null))
	lines.append("mesh_skeleton_path=%s" % String(mesh_instance.skeleton if mesh_instance != null else NodePath()))
	lines.append("skin_bind_count=%d" % (mesh_instance.skin.get_bind_count() if mesh_instance != null and mesh_instance.skin != null else -1))
	lines.append("skeleton_bone_count=%d" % (skeleton.get_bone_count() if skeleton != null else -1))
	lines.append("upperarm_bone_exists=%s" % str(upperarm_index >= 0))
	lines.append("hand_bone_exists=%s" % str(hand_index >= 0))
	lines.append("upperarm_pose_changed=%s" % str(not upperarm_pose_before.is_equal_approx(upperarm_pose_after)))
	lines.append("hand_pose_changed=%s" % str(not hand_pose_before.is_equal_approx(hand_pose_after)))
	lines.append("hand_anchor_changed=%s" % str(not hand_anchor_before.is_equal_approx(hand_anchor_after)))
	lines.append("current_animation=%s" % String(animation_player.current_animation if animation_player != null else StringName()))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
