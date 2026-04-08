extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const ForgeWorkspaceShapeToolPresenterScript = preload("res://runtime/forge/forge_workspace_shape_tool_presenter.gd")

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

	crafting_ui.open_for(player, forge_controller, "Rectangle Tool Verifier Bench")
	await process_frame
	await process_frame

	crafting_ui.call("_create_new_blank_project")
	crafting_ui.call("_set_active_plane", &"xy")
	await process_frame
	await process_frame

	crafting_ui.call("_rebuild_geometry_menu")
	var geometry_popup: PopupMenu = crafting_ui.geometry_menu_button.get_popup()
	var geometry_menu_has_rectangle_tool: bool = _popup_has_item_text(geometry_popup, "Rectangle Tool")
	var geometry_menu_hides_rectangle_erase_entry: bool = not _popup_has_item_text(geometry_popup, "Rectangle Erase Tool")

	var plane_viewport: ForgePlaneViewport = crafting_ui.plane_viewport
	var initial_material_id: StringName = crafting_ui.armed_material_variant_id if crafting_ui.armed_material_variant_id != StringName() else crafting_ui.selected_material_variant_id

	crafting_ui.call("_set_active_tool", ForgeWorkspaceShapeToolPresenterScript.FAMILY_RECTANGLE)
	crafting_ui.armed_material_variant_id = initial_material_id
	await process_frame

	var start_position: Vector2 = _build_plane_position(plane_viewport, 3, 2)
	var end_position: Vector2 = _build_plane_position(plane_viewport, 4, 3)
	var start_grid: Vector3i = plane_viewport.call("_screen_to_grid", start_position)
	var end_grid: Vector3i = plane_viewport.call("_screen_to_grid", end_position)

	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start_position
	plane_viewport._gui_input(press)
	await process_frame

	var preview_count_during_drag: int = plane_viewport.structural_shape_preview_cells.size()
	var preview_visible_during_drag: bool = preview_count_during_drag == 1

	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = end_position
	plane_viewport._gui_input(motion)
	await process_frame

	var expanded_preview_count: int = plane_viewport.structural_shape_preview_cells.size()

	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = end_position
	plane_viewport._gui_input(release)
	await process_frame
	await process_frame

	var placed_count: int = _count_cells(crafting_ui.call("_ensure_wip_for_editing"))
	var placed_expected_cells_ok: bool = _rectangle_cells_match(forge_controller, start_grid, end_grid, initial_material_id)

	crafting_ui.erase_tool_button.emit_signal("pressed")
	await process_frame

	var erase_press: InputEventMouseButton = InputEventMouseButton.new()
	erase_press.button_index = MOUSE_BUTTON_LEFT
	erase_press.pressed = true
	erase_press.position = start_position
	plane_viewport._gui_input(erase_press)
	await process_frame

	var erase_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	erase_motion.position = end_position
	plane_viewport._gui_input(erase_motion)
	await process_frame

	var erase_release: InputEventMouseButton = InputEventMouseButton.new()
	erase_release.button_index = MOUSE_BUTTON_LEFT
	erase_release.pressed = false
	erase_release.position = end_position
	plane_viewport._gui_input(erase_release)
	await process_frame
	await process_frame

	var remaining_count: int = _count_cells(crafting_ui.call("_ensure_wip_for_editing"))

	var lines: PackedStringArray = []
	lines.append("geometry_menu_has_rectangle_tool=%s" % str(geometry_menu_has_rectangle_tool))
	lines.append("geometry_menu_hides_rectangle_erase_entry=%s" % str(geometry_menu_hides_rectangle_erase_entry))
	lines.append("preview_visible_during_drag=%s" % str(preview_visible_during_drag))
	lines.append("preview_count_during_drag=%d" % preview_count_during_drag)
	lines.append("expanded_preview_count=%d" % expanded_preview_count)
	lines.append("rectangle_place_count=%d" % placed_count)
	lines.append("rectangle_place_success=%s" % str(placed_count == 4))
	lines.append("rectangle_place_expected_cells_ok=%s" % str(placed_expected_cells_ok))
	lines.append("rectangle_erase_remaining_count=%d" % remaining_count)
	lines.append("rectangle_erase_success=%s" % str(remaining_count == 0))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/crafting_bench_rectangle_tool_results.txt", FileAccess.WRITE)
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

func _count_cells(wip: CraftedItemWIP) -> int:
	if wip == null:
		return 0
	var count: int = 0
	for layer_atom: LayerAtom in wip.layers:
		if layer_atom == null:
			continue
		count += layer_atom.cells.size()
	return count

func _rectangle_cells_match(
	forge_controller: ForgeGridController,
	start_grid: Vector3i,
	end_grid: Vector3i,
	expected_material_id: StringName
) -> bool:
	var min_x: int = mini(start_grid.x, end_grid.x)
	var max_x: int = maxi(start_grid.x, end_grid.x)
	var min_y: int = mini(start_grid.y, end_grid.y)
	var max_y: int = maxi(start_grid.y, end_grid.y)
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			if forge_controller.get_material_id_at(Vector3i(x, y, start_grid.z)) != expected_material_id:
				return false
	return true

func _popup_has_item_text(popup: PopupMenu, item_text: String) -> bool:
	if popup == null:
		return false
	for item_index: int in range(popup.get_item_count()):
		if popup.get_item_text(item_index) == item_text:
			return true
	return false
