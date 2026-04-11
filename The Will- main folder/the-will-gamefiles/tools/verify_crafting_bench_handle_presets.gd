extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const ForgeWorkspaceShapeToolPresenterScript = preload("res://runtime/forge/forge_workspace_shape_tool_presenter.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/crafting_bench_handle_presets_results.txt"

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

	crafting_ui.open_for(player, forge_controller, "Handle Preset Test Bench")
	await process_frame
	await process_frame

	crafting_ui.call("_create_new_blank_project")
	crafting_ui.call("_set_active_plane", &"xy")
	await process_frame
	await process_frame

	crafting_ui.call("_rebuild_geometry_menu")
	var geometry_popup: PopupMenu = crafting_ui.geometry_menu_button.get_popup()
	var geometry_menu_has_handles_entry: bool = _popup_has_item_text(geometry_popup, "Handles")
	var menu_ids: Dictionary = crafting_ui.call("_get_action_menu_ids")
	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_handles_panel", -1)))
	await process_frame
	await process_frame
	var handle_popup: PopupPanel = crafting_ui.get("geometry_handles_popup")
	var handle_grid: GridContainer = crafting_ui.get("geometry_handles_grid")
	var handle_popup_visible: bool = handle_popup != null and handle_popup.visible
	var handle_popup_has_four_columns: bool = handle_grid != null and handle_grid.columns == 4
	var handle_popup_button_count: int = handle_grid.get_child_count() if handle_grid != null else 0
	var handle_popup_has_icons: bool = _grid_buttons_have_icons(handle_grid)

	var diamond_button: BaseButton = _find_button_by_tooltip(handle_grid, "Diamond 13")
	if diamond_button != null:
		diamond_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var handle_tool_selected: bool = crafting_ui.active_tool == ForgeWorkspaceShapeToolPresenterScript.TOOL_HANDLE_PLACE
	var selected_handle_preset_id: StringName = crafting_ui.get("selected_handle_preset_id")
	var selected_handle_is_diamond_13: bool = selected_handle_preset_id == ForgeWorkspaceShapeToolPresenterScript.HANDLE_PRESET_DIAMOND_13

	crafting_ui.call("_rebuild_tool_menu")
	var tool_popup: PopupMenu = crafting_ui.tool_menu_button.get_popup()
	var tool_menu_has_handle_label: bool = _popup_has_item_text(tool_popup, "Shape Tool: Handle: Diamond 13")
	var tool_menu_has_handle_preset_line: bool = _popup_has_item_text(tool_popup, "Preset: Diamond 13")
	var tool_menu_hides_size_controls_for_handle: bool = (
		not _popup_contains_prefix(tool_popup, "Size A: ")
		and not _popup_contains_prefix(tool_popup, "Size B: ")
		and not _popup_has_item_text(tool_popup, "Size A -")
		and not _popup_has_item_text(tool_popup, "Size A +")
	)

	var plane_viewport: ForgePlaneViewport = crafting_ui.plane_viewport
	var shape_presenter = ForgeWorkspaceShapeToolPresenterScript.new()
	var material_id: StringName = crafting_ui.armed_material_variant_id if crafting_ui.armed_material_variant_id != StringName() else crafting_ui.selected_material_variant_id
	var click_position: Vector2 = _build_plane_position(plane_viewport, 10, 10)
	var click_grid: Vector3i = plane_viewport.call("_screen_to_grid", click_position)
	var expected_cells: Array[Vector3i] = shape_presenter.build_shape_footprint(
		ForgeWorkspaceShapeToolPresenterScript.TOOL_HANDLE_PLACE,
		click_grid,
		click_grid,
		&"xy",
		crafting_ui.active_layer,
		forge_controller.grid_size,
		int(crafting_ui.get("structural_shape_rotation_quadrant")),
		{
			"use_fixed_size": true,
			"handle_preset_id": selected_handle_preset_id,
		}
	)

	var hover_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	hover_motion.position = click_position
	plane_viewport._gui_input(hover_motion)
	await process_frame
	var hover_preview_count_matches: bool = plane_viewport.structural_shape_preview_cells.size() == expected_cells.size()

	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = click_position
	plane_viewport._gui_input(press)
	await process_frame

	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = click_position
	plane_viewport._gui_input(release)
	await process_frame
	await process_frame

	var handle_stamp_expected_cells_ok: bool = _footprint_matches(forge_controller, expected_cells, material_id)

	crafting_ui.call("_set_tool_state_modifier", ForgeWorkspaceShapeToolPresenterScript.MODIFIER_REMOVE)
	await process_frame
	plane_viewport._gui_input(press)
	await process_frame
	plane_viewport._gui_input(release)
	await process_frame
	await process_frame

	var handle_erase_success: bool = _count_cells(crafting_ui.call("_ensure_wip_for_editing")) == 0

	var lines: PackedStringArray = []
	lines.append("geometry_menu_has_handles_entry=%s" % str(geometry_menu_has_handles_entry))
	lines.append("handle_popup_visible=%s" % str(handle_popup_visible))
	lines.append("handle_popup_has_four_columns=%s" % str(handle_popup_has_four_columns))
	lines.append("handle_popup_button_count=%d" % handle_popup_button_count)
	lines.append("handle_popup_has_icons=%s" % str(handle_popup_has_icons))
	lines.append("handle_tool_selected=%s" % str(handle_tool_selected))
	lines.append("selected_handle_is_diamond_13=%s" % str(selected_handle_is_diamond_13))
	lines.append("tool_menu_has_handle_label=%s" % str(tool_menu_has_handle_label))
	lines.append("tool_menu_has_handle_preset_line=%s" % str(tool_menu_has_handle_preset_line))
	lines.append("tool_menu_hides_size_controls_for_handle=%s" % str(tool_menu_hides_size_controls_for_handle))
	lines.append("hover_preview_count_matches=%s" % str(hover_preview_count_matches))
	lines.append("handle_stamp_expected_cells_ok=%s" % str(handle_stamp_expected_cells_ok))
	lines.append("handle_erase_success=%s" % str(handle_erase_success))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _build_plane_position(plane_viewport: ForgePlaneViewport, u: int, v: int) -> Vector2:
	var plane_rect: Rect2 = plane_viewport.call("_get_plane_draw_rect")
	var plane_dimensions: Vector2i = plane_viewport.call("_get_plane_dimensions")
	var cell_size: Vector2 = Vector2(
		plane_rect.size.x / float(plane_dimensions.x),
		plane_rect.size.y / float(plane_dimensions.y)
	)
	return plane_rect.position + Vector2((float(u) + 0.5) * cell_size.x, (float(v) + 0.5) * cell_size.y)

func _popup_has_item_text(popup: PopupMenu, item_text: String) -> bool:
	if popup == null:
		return false
	for item_index: int in range(popup.get_item_count()):
		if popup.get_item_text(item_index) == item_text:
			return true
	return false

func _popup_contains_prefix(popup: PopupMenu, prefix_text: String) -> bool:
	if popup == null:
		return false
	for item_index: int in range(popup.get_item_count()):
		if popup.get_item_text(item_index).begins_with(prefix_text):
			return true
	return false

func _grid_buttons_have_icons(grid: GridContainer) -> bool:
	if grid == null:
		return false
	if grid.get_child_count() <= 0:
		return false
	for child: Node in grid.get_children():
		var button: BaseButton = child as BaseButton
		if button == null or button.icon == null:
			return false
	return true

func _find_button_by_tooltip(grid: GridContainer, tooltip_text: String) -> BaseButton:
	if grid == null:
		return null
	for child: Node in grid.get_children():
		var button: BaseButton = child as BaseButton
		if button == null:
			continue
		if button.tooltip_text == tooltip_text:
			return button
	return null

func _count_cells(wip: CraftedItemWIP) -> int:
	if wip == null:
		return 0
	var count: int = 0
	for layer_atom: LayerAtom in wip.layers:
		if layer_atom == null:
			continue
		count += layer_atom.cells.size()
	return count

func _footprint_matches(
	forge_controller: ForgeGridController,
	expected_cells: Array[Vector3i],
	expected_material_id: StringName
) -> bool:
	var visited: Dictionary = {}
	for grid_position: Vector3i in expected_cells:
		visited[grid_position] = true
		if forge_controller.get_material_id_at(grid_position) != expected_material_id:
			return false
	var active_wip: CraftedItemWIP = forge_controller.active_wip
	if active_wip == null:
		return expected_cells.is_empty()
	for layer_atom: LayerAtom in active_wip.layers:
		if layer_atom == null:
			continue
		for cell: CellAtom in layer_atom.cells:
			if cell == null:
				continue
			if not visited.has(cell.grid_position):
				return false
	return true
