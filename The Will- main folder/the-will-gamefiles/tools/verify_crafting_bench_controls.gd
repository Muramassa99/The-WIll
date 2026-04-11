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

	var menu_ids: Dictionary = crafting_ui.call("_get_action_menu_ids")
	var left_panel_hidden: bool = not crafting_ui.left_panel.visible
	var project_menu_exists: bool = crafting_ui.project_menu_button != null
	var status_menu_exists: bool = crafting_ui.status_menu_button != null
	var tool_menu_exists: bool = crafting_ui.tool_menu_button != null
	var draw_overlay_exists: bool = crafting_ui.draw_tool_button != null
	var erase_overlay_exists: bool = crafting_ui.erase_tool_button != null

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

	var view_popup: PopupMenu = crafting_ui.view_menu_button.get_popup()
	var geometry_popup: PopupMenu = crafting_ui.geometry_menu_button.get_popup()
	crafting_ui.call("_rebuild_geometry_menu")
	var geometry_menu_has_pick_material: bool = _popup_has_item_text(geometry_popup, "Pick Material")
	var geometry_menu_has_freehand_tool: bool = _popup_has_item_text(geometry_popup, "Freehand Tool")
	var geometry_menu_has_rectangle_tool: bool = _popup_has_item_text(geometry_popup, "Rectangle Tool")
	var geometry_menu_has_circle_tool: bool = _popup_has_item_text(geometry_popup, "Circle Tool")
	var geometry_menu_has_oval_tool: bool = _popup_has_item_text(geometry_popup, "Oval Tool")
	var geometry_menu_has_triangle_tool: bool = _popup_has_item_text(geometry_popup, "Triangle Tool")
	var geometry_menu_hides_rectangle_erase_entry: bool = not _popup_has_item_text(geometry_popup, "Rectangle Erase Tool")
	var geometry_menu_hides_circle_erase_entry: bool = not _popup_has_item_text(geometry_popup, "Circle Erase Tool")
	var geometry_menu_hides_oval_erase_entry: bool = not _popup_has_item_text(geometry_popup, "Oval Erase Tool")
	var geometry_menu_hides_triangle_erase_entry: bool = not _popup_has_item_text(geometry_popup, "Triangle Erase Tool")
	var bounds_before_toggle: bool = crafting_ui.show_grid_bounds
	var active_plane_before_menu: StringName = crafting_ui.active_plane
	if view_popup != null and view_popup.get_item_count() > 1:
		crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("view_toggle_bounds", -1)))
	await process_frame
	if geometry_popup != null and geometry_popup.get_item_count() > 0:
		crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_plane_zx", -1)))
	await process_frame
	var bounds_toggled_via_menu: bool = crafting_ui.show_grid_bounds != bounds_before_toggle
	var plane_changed_via_menu: bool = crafting_ui.active_plane != active_plane_before_menu

	if draw_overlay_exists:
		crafting_ui.draw_tool_button.emit_signal("pressed")
	await process_frame
	var draw_overlay_selected_place: bool = crafting_ui.active_tool == &"place"
	if erase_overlay_exists:
		crafting_ui.erase_tool_button.emit_signal("pressed")
	await process_frame
	var erase_overlay_selected_erase: bool = crafting_ui.active_tool == &"erase"

	var lines: PackedStringArray = []
	lines.append("left_panel_hidden=%s" % str(left_panel_hidden))
	lines.append("project_menu_exists=%s" % str(project_menu_exists))
	lines.append("status_menu_exists=%s" % str(status_menu_exists))
	lines.append("tool_menu_exists=%s" % str(tool_menu_exists))
	lines.append("draw_overlay_exists=%s" % str(draw_overlay_exists))
	lines.append("erase_overlay_exists=%s" % str(erase_overlay_exists))
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
	lines.append("geometry_menu_has_pick_material=%s" % str(geometry_menu_has_pick_material))
	lines.append("geometry_menu_has_freehand_tool=%s" % str(geometry_menu_has_freehand_tool))
	lines.append("geometry_menu_has_rectangle_tool=%s" % str(geometry_menu_has_rectangle_tool))
	lines.append("geometry_menu_has_circle_tool=%s" % str(geometry_menu_has_circle_tool))
	lines.append("geometry_menu_has_oval_tool=%s" % str(geometry_menu_has_oval_tool))
	lines.append("geometry_menu_has_triangle_tool=%s" % str(geometry_menu_has_triangle_tool))
	lines.append("geometry_menu_hides_rectangle_erase_entry=%s" % str(geometry_menu_hides_rectangle_erase_entry))
	lines.append("geometry_menu_hides_circle_erase_entry=%s" % str(geometry_menu_hides_circle_erase_entry))
	lines.append("geometry_menu_hides_oval_erase_entry=%s" % str(geometry_menu_hides_oval_erase_entry))
	lines.append("geometry_menu_hides_triangle_erase_entry=%s" % str(geometry_menu_hides_triangle_erase_entry))
	lines.append("bounds_toggled_via_menu=%s" % str(bounds_toggled_via_menu))
	lines.append("plane_changed_via_menu=%s" % str(plane_changed_via_menu))
	lines.append("draw_overlay_selected_place=%s" % str(draw_overlay_selected_place))
	lines.append("erase_overlay_selected_erase=%s" % str(erase_overlay_selected_erase))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/crafting_bench_controls_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _popup_has_item_text(popup: PopupMenu, item_text: String) -> bool:
	if popup == null:
		return false
	for item_index: int in range(popup.get_item_count()):
		if popup.get_item_text(item_index) == item_text:
			return true
	return false
