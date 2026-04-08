extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const ForgeWorkspaceShapeToolPresenterScript = preload("res://runtime/forge/forge_workspace_shape_tool_presenter.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/crafting_bench_overlay_hud_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	forge_controller.load_new_blank_wip_for_builder_path("Overlay HUD Test", CraftedItemWIP.BUILDER_PATH_MELEE)
	_seed_cells(forge_controller)
	get_root().add_child(forge_controller)

	var player: PlayerController3D = PlayerScene.instantiate() as PlayerController3D
	get_root().add_child(player)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_for(player, forge_controller, "Overlay HUD Test Bench")
	await process_frame
	await process_frame

	var overlay_parent_is_tool_host: bool = crafting_ui.tool_overlay_panel.get_parent() == crafting_ui.tool_overlay_host
	var overlay_host_is_workspace_stage_child: bool = crafting_ui.tool_overlay_host.get_parent() == crafting_ui.workspace_stage
	var overlay_host_frontmost_initial: bool = crafting_ui.workspace_stage.get_child(crafting_ui.workspace_stage.get_child_count() - 1) == crafting_ui.tool_overlay_host

	crafting_ui.call("_on_flip_view_pressed")
	await process_frame
	await process_frame
	var overlay_parent_after_first_flip_ok: bool = crafting_ui.tool_overlay_panel.get_parent() == crafting_ui.tool_overlay_host
	var overlay_host_frontmost_after_first_flip: bool = crafting_ui.workspace_stage.get_child(crafting_ui.workspace_stage.get_child_count() - 1) == crafting_ui.tool_overlay_host
	crafting_ui.erase_tool_button.emit_signal("pressed")
	await process_frame
	var erase_after_first_flip_ok: bool = crafting_ui.active_tool == &"erase"

	crafting_ui.call("_on_flip_view_pressed")
	await process_frame
	await process_frame
	var overlay_parent_after_second_flip_ok: bool = crafting_ui.tool_overlay_panel.get_parent() == crafting_ui.tool_overlay_host
	var overlay_host_frontmost_after_second_flip: bool = crafting_ui.workspace_stage.get_child(crafting_ui.workspace_stage.get_child_count() - 1) == crafting_ui.tool_overlay_host
	crafting_ui.call("_set_active_tool", ForgeWorkspaceShapeToolPresenterScript.TOOL_RECTANGLE_PLACE)
	await process_frame
	crafting_ui.erase_tool_button.emit_signal("pressed")
	await process_frame
	var rectangle_overlay_erase_after_second_flip_ok: bool = crafting_ui.active_tool == ForgeWorkspaceShapeToolPresenterScript.TOOL_RECTANGLE_ERASE
	crafting_ui.draw_tool_button.emit_signal("pressed")
	await process_frame
	var rectangle_overlay_draw_after_second_flip_ok: bool = crafting_ui.active_tool == ForgeWorkspaceShapeToolPresenterScript.TOOL_RECTANGLE_PLACE

	crafting_ui.selected_material_variant_id = StringName()
	crafting_ui.armed_material_variant_id = StringName()
	crafting_ui.call("_refresh_left_panel")
	await process_frame
	var select_material_prompt_ok: bool = crafting_ui.material_status_label.visible and crafting_ui.material_status_label.text == "Select Material"
	var overlay_tool_state_add_ok: bool = crafting_ui.tool_state_label.text == "Tool State: Add"
	var overlay_active_tool_rectangle_ok: bool = crafting_ui.active_tool_label.text == "Active Tool: Rectangle"

	crafting_ui.call("_initialize_stage2_for_active_wip")
	await process_frame
	await process_frame
	crafting_ui.call("_toggle_stage2_refinement_mode")
	await process_frame
	await process_frame
	var material_hidden_in_stage2: bool = not crafting_ui.material_status_label.visible
	var radius_visible_in_stage2: bool = crafting_ui.radius_status_label.visible
	var stage2_tool_state_add_ok: bool = crafting_ui.tool_state_label.text == "Tool State: Add"
	var stage2_active_tool_carve_ok: bool = crafting_ui.active_tool_label.text == "Active Tool: Carve"
	var radius_label_prefix_ok: bool = crafting_ui.radius_status_label.text.begins_with("Radius: ")

	var radius_before_up: float = float(crafting_ui.get("stage2_brush_radius_meters"))
	var camera_distance_before_up: float = crafting_ui.free_workspace_preview.camera.position.z
	var wheel_up_event: InputEventMouseButton = InputEventMouseButton.new()
	wheel_up_event.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up_event.pressed = true
	wheel_up_event.ctrl_pressed = true
	wheel_up_event.position = crafting_ui.free_view_container.size * 0.5
	crafting_ui.call("_on_free_view_panel_gui_input", wheel_up_event)
	crafting_ui.call("_on_free_view_gui_input", wheel_up_event)
	await process_frame
	var radius_after_up: float = float(crafting_ui.get("stage2_brush_radius_meters"))
	var radius_increased_with_ctrl_scroll: bool = radius_after_up > radius_before_up
	var camera_zoom_suppressed_with_ctrl_scroll: bool = is_equal_approx(crafting_ui.free_workspace_preview.camera.position.z, camera_distance_before_up)

	var wheel_down_event: InputEventMouseButton = InputEventMouseButton.new()
	wheel_down_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down_event.pressed = true
	wheel_down_event.ctrl_pressed = true
	wheel_down_event.position = crafting_ui.free_view_container.size * 0.5
	for _down_index in range(80):
		crafting_ui.call("_on_free_view_panel_gui_input", wheel_down_event)
		crafting_ui.call("_on_free_view_gui_input", wheel_down_event)
	var min_radius_meters: float = float(crafting_ui.call("_get_stage2_pointer_tool_min_radius_meters"))
	var radius_clamped_to_min: bool = is_equal_approx(float(crafting_ui.get("stage2_brush_radius_meters")), min_radius_meters)

	for _up_index in range(80):
		crafting_ui.call("_on_free_view_panel_gui_input", wheel_up_event)
		crafting_ui.call("_on_free_view_gui_input", wheel_up_event)
	var max_radius_meters: float = float(crafting_ui.call("_get_stage2_pointer_tool_max_radius_meters"))
	var radius_clamped_to_max: bool = is_equal_approx(float(crafting_ui.get("stage2_brush_radius_meters")), max_radius_meters)

	var lines: PackedStringArray = []
	lines.append("overlay_parent_is_tool_host=%s" % str(overlay_parent_is_tool_host))
	lines.append("overlay_host_is_workspace_stage_child=%s" % str(overlay_host_is_workspace_stage_child))
	lines.append("overlay_host_frontmost_initial=%s" % str(overlay_host_frontmost_initial))
	lines.append("overlay_parent_after_first_flip_ok=%s" % str(overlay_parent_after_first_flip_ok))
	lines.append("overlay_host_frontmost_after_first_flip=%s" % str(overlay_host_frontmost_after_first_flip))
	lines.append("erase_after_first_flip_ok=%s" % str(erase_after_first_flip_ok))
	lines.append("overlay_parent_after_second_flip_ok=%s" % str(overlay_parent_after_second_flip_ok))
	lines.append("overlay_host_frontmost_after_second_flip=%s" % str(overlay_host_frontmost_after_second_flip))
	lines.append("rectangle_overlay_erase_after_second_flip_ok=%s" % str(rectangle_overlay_erase_after_second_flip_ok))
	lines.append("rectangle_overlay_draw_after_second_flip_ok=%s" % str(rectangle_overlay_draw_after_second_flip_ok))
	lines.append("select_material_prompt_ok=%s" % str(select_material_prompt_ok))
	lines.append("overlay_tool_state_add_ok=%s" % str(overlay_tool_state_add_ok))
	lines.append("overlay_active_tool_rectangle_ok=%s" % str(overlay_active_tool_rectangle_ok))
	lines.append("material_hidden_in_stage2=%s" % str(material_hidden_in_stage2))
	lines.append("radius_visible_in_stage2=%s" % str(radius_visible_in_stage2))
	lines.append("stage2_tool_state_add_ok=%s" % str(stage2_tool_state_add_ok))
	lines.append("stage2_active_tool_carve_ok=%s" % str(stage2_active_tool_carve_ok))
	lines.append("radius_label_prefix_ok=%s" % str(radius_label_prefix_ok))
	lines.append("radius_increased_with_ctrl_scroll=%s" % str(radius_increased_with_ctrl_scroll))
	lines.append("camera_zoom_suppressed_with_ctrl_scroll=%s" % str(camera_zoom_suppressed_with_ctrl_scroll))
	lines.append("radius_clamped_to_min=%s" % str(radius_clamped_to_min))
	lines.append("radius_clamped_to_max=%s" % str(radius_clamped_to_max))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _seed_cells(forge_controller: ForgeGridController) -> void:
	for z: int in range(2):
		for y: int in range(2):
			for x: int in range(4):
				forge_controller.set_material_at(Vector3i(x, y, z), &"mat_iron_gray")
