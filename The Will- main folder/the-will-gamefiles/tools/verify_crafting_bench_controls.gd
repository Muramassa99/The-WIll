extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	get_root().add_child(forge_controller)

	var player: PlayerController3D = PlayerScene.instantiate() as PlayerController3D
	get_root().add_child(player)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_for(player, forge_controller, "Controls Verifier Bench")
	await process_frame
	await process_frame

	var preview: ForgeWorkspacePreview = crafting_ui.free_workspace_preview
	var offgrid_top_left_rejected: bool = preview.screen_to_grid(Vector2.ZERO) == null
	var offgrid_bottom_right_rejected: bool = preview.screen_to_grid(crafting_ui.free_view_container.size) == null

	var initial_pitch_degrees: float = rad_to_deg(preview.camera_pitch.rotation.x) if preview != null and preview.camera_pitch != null else 0.0
	if preview != null:
		preview.orbit_by(Vector2(0.0, -50000.0))
	await process_frame
	var raised_pitch_degrees: float = rad_to_deg(preview.camera_pitch.rotation.x) if preview != null and preview.camera_pitch != null else initial_pitch_degrees
	var can_look_underneath: bool = raised_pitch_degrees >= 70.0

	var start_layer: int = crafting_ui.active_layer
	crafting_ui.call("_step_layer", 1)
	crafting_ui.call("_begin_layer_hold", 1)
	Input.action_press(&"forge_layer_up")
	crafting_ui.call("_process_layer_hold_repeat", 0.49)
	var layer_after_delay_window: int = crafting_ui.active_layer
	crafting_ui.call("_process_layer_hold_repeat", 0.21)
	var layer_after_repeat_window: int = crafting_ui.active_layer
	Input.action_release(&"forge_layer_up")
	crafting_ui.call("_clear_layer_hold")

	var lines: PackedStringArray = []
	lines.append("offgrid_top_left_rejected=%s" % str(offgrid_top_left_rejected))
	lines.append("offgrid_bottom_right_rejected=%s" % str(offgrid_bottom_right_rejected))
	lines.append("initial_pitch_degrees=%s" % str(initial_pitch_degrees))
	lines.append("raised_pitch_degrees=%s" % str(raised_pitch_degrees))
	lines.append("can_look_underneath=%s" % str(can_look_underneath))
	lines.append("start_layer=%d" % start_layer)
	lines.append("layer_after_delay_window=%d" % layer_after_delay_window)
	lines.append("layer_after_repeat_window=%d" % layer_after_repeat_window)
	lines.append("layer_hold_delay_respected=%s" % str(layer_after_delay_window == start_layer + 1))
	lines.append("layer_hold_repeat_advanced=%s" % str(layer_after_repeat_window >= start_layer + 3))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/crafting_bench_controls_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
