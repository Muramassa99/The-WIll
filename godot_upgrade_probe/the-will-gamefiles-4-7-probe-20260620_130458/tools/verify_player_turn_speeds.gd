extends SceneTree

const PlayerScene = preload("res://scenes/player/player_character.tscn")
const RESULT_FILE_PATH := "C:/WORKSPACE/player_turn_speeds_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var player_root: Node = PlayerScene.instantiate()
	root.add_child(player_root)
	await process_frame
	await process_frame

	var player := player_root as PlayerController3D
	var lines: PackedStringArray = []
	lines.append("player_loaded=%s" % str(player != null))

	if player != null:
		lines.append("idle_turn_speed=%s" % str(snapped(player._resolve_visual_turn_speed(Vector2.ZERO, false, true), 0.0001)))
		lines.append("move_turn_speed=%s" % str(snapped(player._resolve_visual_turn_speed(Vector2(0.0, -1.0), false, true), 0.0001)))
		lines.append("sprint_turn_speed=%s" % str(snapped(player._resolve_visual_turn_speed(Vector2(0.0, -1.0), true, true), 0.0001)))
		lines.append("backpedal_turn_speed=%s" % str(snapped(player._resolve_visual_turn_speed(Vector2(0.0, 1.0), false, true), 0.0001)))
		lines.append("air_turn_speed=%s" % str(snapped(player._resolve_visual_turn_speed(Vector2(0.0, -1.0), true, false), 0.0001)))
		lines.append("idle_turns_faster_than_sprint=%s" % str(player._resolve_visual_turn_speed(Vector2.ZERO, false, true) > player._resolve_visual_turn_speed(Vector2(0.0, -1.0), true, true)))
		lines.append("move_turns_faster_than_sprint=%s" % str(player._resolve_visual_turn_speed(Vector2(0.0, -1.0), false, true) > player._resolve_visual_turn_speed(Vector2(0.0, -1.0), true, true)))
		lines.append("backpedal_faster_than_sprint=%s" % str(player._resolve_visual_turn_speed(Vector2(0.0, 1.0), false, true) > player._resolve_visual_turn_speed(Vector2(0.0, -1.0), true, true)))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
