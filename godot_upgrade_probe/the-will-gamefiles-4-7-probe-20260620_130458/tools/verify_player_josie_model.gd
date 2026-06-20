extends SceneTree

const PlayerScene = preload("res://scenes/player/player_character.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_josie_model_results.txt"

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
	var animation_player: AnimationPlayer = rig.get_node_or_null("JosieModel/AnimationPlayer") as AnimationPlayer if rig != null else null
	var right_anchor: Node3D = rig.get_right_hand_item_anchor() if rig != null else null
	var left_anchor: Node3D = rig.get_left_hand_item_anchor() if rig != null else null
	var right_attachment: BoneAttachment3D = right_anchor.get_parent() as BoneAttachment3D if right_anchor != null else null
	var left_attachment: BoneAttachment3D = left_anchor.get_parent() as BoneAttachment3D if left_anchor != null else null
	var visual_height_meters: float = rig.get_visual_height_meters() if rig != null else 0.0
	var max_model_arm_reach_meters: float = rig.get_max_model_arm_reach_meters() if rig != null else 0.0
	var max_model_arm_reach_combat_meters: float = rig.get_max_model_arm_reach_combat_meters() if rig != null else 0.0
	var pole_grip_negative_limit_meters: float = rig.get_pole_grip_negative_limit_meters() if rig != null else 0.0
	var pole_grip_positive_limit_meters: float = rig.get_pole_grip_positive_limit_meters() if rig != null else 0.0
	var default_animation_target: StringName = rig.default_animation_name if rig != null else StringName()
	var post_spawn_animation: StringName = animation_player.current_animation if animation_player != null else StringName()

	var lines: PackedStringArray = []
	lines.append("player_loaded=%s" % str(player != null))
	lines.append("rig_loaded=%s" % str(rig != null))
	lines.append("skeleton_loaded=%s" % str(skeleton != null))
	lines.append("animation_player_loaded=%s" % str(animation_player != null))
	lines.append("standing_height_target=%s" % str(rig.get_standing_height_meters() if rig != null else 0.0))
	lines.append("visual_height_meters=%s" % str(snappedf(visual_height_meters, 0.001)))
	lines.append("visual_height_is_two_meters=%s" % str(is_equal_approx(visual_height_meters, 2.0)))
	lines.append("max_model_arm_reach_meters=%s" % str(snappedf(max_model_arm_reach_meters, 0.001)))
	lines.append("max_model_arm_reach_valid=%s" % str(max_model_arm_reach_meters > 0.0))
	lines.append("max_model_arm_reach_combat_meters=%s" % str(snappedf(max_model_arm_reach_combat_meters, 0.001)))
	lines.append("pole_grip_negative_limit_meters=%s" % str(snappedf(pole_grip_negative_limit_meters, 0.001)))
	lines.append("pole_grip_positive_limit_meters=%s" % str(snappedf(pole_grip_positive_limit_meters, 0.001)))
	lines.append("default_animation_target=%s" % String(default_animation_target))
	lines.append("post_spawn_animation=%s" % String(post_spawn_animation))
	lines.append("right_anchor_exists=%s" % str(right_anchor != null))
	lines.append("left_anchor_exists=%s" % str(left_anchor != null))
	lines.append("right_anchor_local_position=%s" % str(right_anchor.position if right_anchor != null else Vector3.ZERO))
	lines.append("left_anchor_local_position=%s" % str(left_anchor.position if left_anchor != null else Vector3.ZERO))
	lines.append("right_anchor_is_offset=%s" % str(right_anchor != null and not right_anchor.position.is_zero_approx()))
	lines.append("left_anchor_is_offset=%s" % str(left_anchor != null and not left_anchor.position.is_zero_approx()))
	lines.append("right_attachment_bone=%s" % String(right_attachment.bone_name if right_attachment != null else StringName()))
	lines.append("left_attachment_bone=%s" % String(left_attachment.bone_name if left_attachment != null else StringName()))
	lines.append("right_hand_bone_exists=%s" % str(skeleton != null and skeleton.find_bone("CC_Base_R_Hand") >= 0))
	lines.append("left_hand_bone_exists=%s" % str(skeleton != null and skeleton.find_bone("CC_Base_L_Hand") >= 0))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
