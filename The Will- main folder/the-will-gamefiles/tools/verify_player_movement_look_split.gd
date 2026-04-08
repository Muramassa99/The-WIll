extends SceneTree

const PlayerScene = preload("res://scenes/player/player_character.tscn")
const PlayerAimContextScript = preload("res://core/models/player_aim_context.gd")
const RESULT_FILE_PATH := "C:/WORKSPACE/player_movement_look_split_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var player_root: Node = PlayerScene.instantiate()
	root.add_child(player_root)
	await process_frame
	await process_frame

	var player := player_root as PlayerController3D
	var movement_facing_matches_move: bool = false
	var skill_facing_matches_crosshair: bool = false
	var crosshair_priority_active: bool = false
	var rear_camera_fallback_active: bool = false
	var backpedal_camera_override_active: bool = false
	var front_crosshair_direction := Vector3(0.0, 0.0, 1.0)
	var rear_crosshair_direction := Vector3(0.0, 0.0, -1.0)

	if player != null:
		player.visual_root.rotation = Vector3.ZERO
		player.camera.global_position = player.visual_root.global_position + Vector3(0.0, 1.6, -3.5)
		player.current_aim_context = PlayerAimContextScript.new()

		var move_direction := Vector3.RIGHT
		player.current_aim_context.flat_direction = front_crosshair_direction
		player.current_aim_context.camera_direction = front_crosshair_direction
		player.current_aim_context.aim_point = player.visual_root.global_position + front_crosshair_direction * 12.0
		var locomotion_facing: Vector3 = player._resolve_visual_facing_direction(move_direction)
		movement_facing_matches_move = locomotion_facing.dot(move_direction.normalized()) > 0.9

		player.request_skill_face_crosshair(0.5)
		var skill_facing: Vector3 = player._resolve_visual_facing_direction(move_direction)
		skill_facing_matches_crosshair = skill_facing.dot(front_crosshair_direction) > 0.9

		player.skill_face_crosshair_timer = 0.0
		player.last_move_input_vector = Vector2.ZERO
		player.current_aim_context.aim_point = player.visual_root.global_position + front_crosshair_direction * 12.0
		player.current_aim_context.camera_direction = front_crosshair_direction
		var crosshair_priority_direction: Vector3 = player._resolve_aim_follow_world_direction()
		crosshair_priority_active = crosshair_priority_direction.dot(front_crosshair_direction) > 0.9

		var camera_direction: Vector3 = player._get_direction_to_camera_world()
		player.current_aim_context.aim_point = player.visual_root.global_position + rear_crosshair_direction * 12.0
		player.current_aim_context.camera_direction = rear_crosshair_direction
		var rear_fallback_direction: Vector3 = player._resolve_aim_follow_world_direction()
		rear_camera_fallback_active = rear_fallback_direction.dot(camera_direction) > 0.9

		player.last_move_input_vector = Vector2(0.0, 1.0)
		player.current_aim_context.aim_point = player.visual_root.global_position + front_crosshair_direction * 12.0
		player.current_aim_context.camera_direction = front_crosshair_direction
		var backpedal_direction: Vector3 = player._resolve_aim_follow_world_direction()
		backpedal_camera_override_active = backpedal_direction.dot(camera_direction) > 0.9

	var lines: PackedStringArray = []
	lines.append("player_loaded=%s" % str(player != null))
	lines.append("movement_facing_matches_move=%s" % str(movement_facing_matches_move))
	lines.append("skill_facing_matches_crosshair=%s" % str(skill_facing_matches_crosshair))
	lines.append("crosshair_priority_active=%s" % str(crosshair_priority_active))
	lines.append("rear_camera_fallback_active=%s" % str(rear_camera_fallback_active))
	lines.append("backpedal_camera_override_active=%s" % str(backpedal_camera_override_active))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
