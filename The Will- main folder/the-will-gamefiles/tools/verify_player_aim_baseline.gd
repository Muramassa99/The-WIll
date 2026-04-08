extends SceneTree

const PlayerScene = preload("res://scenes/player/player_character.tscn")
const PlayerAimContextScript = preload("res://core/models/player_aim_context.gd")
const RESULT_FILE_PATH := "C:/WORKSPACE/player_aim_baseline_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var player_root: Node = PlayerScene.instantiate()
	root.add_child(player_root)
	await process_frame
	await process_frame

	var player := player_root as PlayerController3D
	if player != null:
		player._refresh_aim_context()

	var aim_context = player.get_current_aim_context() if player != null else PlayerAimContextScript.new()
	var crosshair: Control = player.get_node_or_null("PlayerCrosshairOverlay/Crosshair") as Control if player != null else null
	var backpedal_speed: float = player._resolve_target_move_speed(Vector2(0.0, 1.0), false) if player != null else -1.0
	var forward_speed: float = player._resolve_target_move_speed(Vector2(0.0, -1.0), false) if player != null else -1.0

	var lines: PackedStringArray = []
	lines.append("player_loaded=%s" % str(player != null))
	lines.append("crosshair_loaded=%s" % str(crosshair != null))
	lines.append("crosshair_visible=%s" % str(crosshair != null and crosshair.visible))
	lines.append("aim_context_loaded=%s" % str(aim_context != null))
	lines.append("aim_distance=%s" % str(snapped(aim_context.aim_distance, 0.001) if aim_context != null else -1.0))
	lines.append("aim_range_target=%s" % str(player.aim_max_range_meters if player != null else -1.0))
	lines.append("aim_has_flat_direction=%s" % str(aim_context != null and aim_context.has_flat_direction()))
	lines.append("backpedal_speed=%s" % str(backpedal_speed))
	lines.append("forward_speed=%s" % str(forward_speed))
	lines.append("backpedal_is_penalized=%s" % str(backpedal_speed >= 0.0 and forward_speed > backpedal_speed))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
