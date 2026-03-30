extends SceneTree

const PlayerScene = preload("res://scenes/player/player_character.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_locomotion_animation_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var player_root: Node = PlayerScene.instantiate()
	root.add_child(player_root)
	await process_frame
	await process_frame

	var player = player_root as PlayerController3D
	var rig: PlayerHumanoidRig = player.humanoid_rig as PlayerHumanoidRig if player != null else null
	var animation_player: AnimationPlayer = rig.get_node_or_null("JosieModel/AnimationPlayer") as AnimationPlayer if rig != null else null

	var lines: PackedStringArray = []
	lines.append("player_loaded=%s" % str(player != null))
	lines.append("rig_loaded=%s" % str(rig != null))
	lines.append("animation_player_loaded=%s" % str(animation_player != null))
	lines.append("has_idle=%s" % str(rig != null and rig.has_animation_name(&"Idle")))
	lines.append("has_walk=%s" % str(rig != null and rig.has_animation_name(&"Walk")))
	lines.append("has_slow_run=%s" % str(rig != null and rig.has_animation_name(&"SlowRun")))
	lines.append("has_run=%s" % str(rig != null and rig.has_animation_name(&"Run")))
	lines.append("has_jump_pose=%s" % str(rig != null and rig.has_animation_name(&"Jump(Pose)")))
	lines.append("has_fall_pose=%s" % str(rig != null and rig.has_animation_name(&"Fall(Pose)")))

	if rig != null:
		rig.update_locomotion_state(0.0, 5.5, true, 0.0, false)
		lines.append("idle_state_animation=%s" % String(rig.get_current_animation_name()))
		rig.update_locomotion_state(1.0, 5.5, true, 0.0, false)
		lines.append("walk_state_animation=%s" % String(rig.get_current_animation_name()))
		rig.update_locomotion_state(5.5, 5.5, true, 0.0, false)
		lines.append("jog_state_animation=%s" % String(rig.get_current_animation_name()))
		rig.update_locomotion_state(8.0, 8.0, true, 0.0, true)
		lines.append("sprint_state_animation=%s" % String(rig.get_current_animation_name()))
		rig.update_locomotion_state(0.0, 5.5, false, 1.0, false)
		lines.append("jump_state_animation=%s" % String(rig.get_current_animation_name()))
		rig.update_locomotion_state(0.0, 5.5, false, -1.0, false)
		lines.append("fall_state_animation=%s" % String(rig.get_current_animation_name()))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
