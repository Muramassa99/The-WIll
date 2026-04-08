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

	crafting_ui.open_for(player, forge_controller, "Shape Tool Verifier Bench")
	await process_frame
	await process_frame

	crafting_ui.call("_create_new_blank_project")
	crafting_ui.call("_set_active_plane", &"xy")
	await process_frame
	await process_frame

	crafting_ui.call("_rebuild_geometry_menu")
	var geometry_popup: PopupMenu = crafting_ui.geometry_menu_button.get_popup()
	var geometry_menu_has_circle_tool: bool = _popup_has_item_text(geometry_popup, "Circle Tool")
	var geometry_menu_has_oval_tool: bool = _popup_has_item_text(geometry_popup, "Oval Tool")
	var geometry_menu_has_triangle_tool: bool = _popup_has_item_text(geometry_popup, "Triangle Tool")
	var geometry_menu_has_circle_erase_entry: bool = _popup_has_item_text(geometry_popup, "Circle Erase Tool")
	var geometry_menu_has_oval_erase_entry: bool = _popup_has_item_text(geometry_popup, "Oval Erase Tool")
	var geometry_menu_has_triangle_erase_entry: bool = _popup_has_item_text(geometry_popup, "Triangle Erase Tool")

	var plane_viewport: ForgePlaneViewport = crafting_ui.plane_viewport
	var shape_presenter = ForgeWorkspaceShapeToolPresenterScript.new()
	var initial_material_id: StringName = crafting_ui.armed_material_variant_id if crafting_ui.armed_material_variant_id != StringName() else crafting_ui.selected_material_variant_id

	var circle_result: Dictionary = await _run_shape_case(
		crafting_ui,
		forge_controller,
		plane_viewport,
		shape_presenter,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_CIRCLE_PLACE,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_CIRCLE_ERASE,
		Vector2i(2, 1),
		Vector2i(6, 5),
		initial_material_id,
		21
	)
	var oval_result: Dictionary = await _run_shape_case(
		crafting_ui,
		forge_controller,
		plane_viewport,
		shape_presenter,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_OVAL_PLACE,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_OVAL_ERASE,
		Vector2i(2, 2),
		Vector2i(7, 4),
		initial_material_id,
		14
	)
	var triangle_result: Dictionary = await _run_shape_case(
		crafting_ui,
		forge_controller,
		plane_viewport,
		shape_presenter,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_TRIANGLE_PLACE,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_TRIANGLE_ERASE,
		Vector2i(2, 1),
		Vector2i(6, 5),
		initial_material_id,
		13
	)

	crafting_ui.call("_set_active_tool", ForgeWorkspaceShapeToolPresenterScript.TOOL_OVAL_PLACE)
	await process_frame
	crafting_ui.erase_tool_button.emit_signal("pressed")
	await process_frame
	var overlay_switched_to_oval_erase: bool = crafting_ui.active_tool == ForgeWorkspaceShapeToolPresenterScript.TOOL_OVAL_ERASE
	crafting_ui.draw_tool_button.emit_signal("pressed")
	await process_frame
	var overlay_switched_back_to_oval_draw: bool = crafting_ui.active_tool == ForgeWorkspaceShapeToolPresenterScript.TOOL_OVAL_PLACE

	var lines: PackedStringArray = []
	lines.append("geometry_menu_has_circle_tool=%s" % str(geometry_menu_has_circle_tool))
	lines.append("geometry_menu_has_oval_tool=%s" % str(geometry_menu_has_oval_tool))
	lines.append("geometry_menu_has_triangle_tool=%s" % str(geometry_menu_has_triangle_tool))
	lines.append("geometry_menu_has_circle_erase_entry=%s" % str(geometry_menu_has_circle_erase_entry))
	lines.append("geometry_menu_has_oval_erase_entry=%s" % str(geometry_menu_has_oval_erase_entry))
	lines.append("geometry_menu_has_triangle_erase_entry=%s" % str(geometry_menu_has_triangle_erase_entry))
	lines.append("circle_preview_count=%d" % int(circle_result.get("preview_count", 0)))
	lines.append("circle_preview_3d_visible=%s" % str(bool(circle_result.get("preview_3d_visible", false))))
	lines.append("circle_place_count=%d" % int(circle_result.get("placed_count", 0)))
	lines.append("circle_place_expected_count_ok=%s" % str(bool(circle_result.get("expected_count_ok", false))))
	lines.append("circle_place_expected_cells_ok=%s" % str(bool(circle_result.get("expected_cells_ok", false))))
	lines.append("circle_erase_success=%s" % str(bool(circle_result.get("erase_success", false))))
	lines.append("oval_preview_count=%d" % int(oval_result.get("preview_count", 0)))
	lines.append("oval_preview_3d_visible=%s" % str(bool(oval_result.get("preview_3d_visible", false))))
	lines.append("oval_place_count=%d" % int(oval_result.get("placed_count", 0)))
	lines.append("oval_place_expected_count_ok=%s" % str(bool(oval_result.get("expected_count_ok", false))))
	lines.append("oval_place_expected_cells_ok=%s" % str(bool(oval_result.get("expected_cells_ok", false))))
	lines.append("oval_erase_success=%s" % str(bool(oval_result.get("erase_success", false))))
	lines.append("triangle_preview_count=%d" % int(triangle_result.get("preview_count", 0)))
	lines.append("triangle_preview_3d_visible=%s" % str(bool(triangle_result.get("preview_3d_visible", false))))
	lines.append("triangle_place_count=%d" % int(triangle_result.get("placed_count", 0)))
	lines.append("triangle_place_expected_count_ok=%s" % str(bool(triangle_result.get("expected_count_ok", false))))
	lines.append("triangle_place_expected_cells_ok=%s" % str(bool(triangle_result.get("expected_cells_ok", false))))
	lines.append("triangle_erase_success=%s" % str(bool(triangle_result.get("erase_success", false))))
	lines.append("overlay_switched_to_oval_erase=%s" % str(overlay_switched_to_oval_erase))
	lines.append("overlay_switched_back_to_oval_draw=%s" % str(overlay_switched_back_to_oval_draw))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/crafting_bench_shape_tools_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _run_shape_case(
	crafting_ui: CraftingBenchUI,
	forge_controller: ForgeGridController,
	plane_viewport: ForgePlaneViewport,
	shape_presenter,
	place_tool_id: StringName,
	erase_tool_id: StringName,
	start_plane_position: Vector2i,
	end_plane_position: Vector2i,
	material_id: StringName,
	expected_count: int
) -> Dictionary:
	crafting_ui.call("_set_active_plane", &"xy")
	await process_frame
	await process_frame
	crafting_ui.armed_material_variant_id = material_id
	crafting_ui.call("_set_active_tool", place_tool_id)
	await process_frame

	var start_position: Vector2 = _build_plane_position(plane_viewport, start_plane_position.x, start_plane_position.y)
	var end_position: Vector2 = _build_plane_position(plane_viewport, end_plane_position.x, end_plane_position.y)
	var start_grid: Vector3i = plane_viewport.call("_screen_to_grid", start_position)
	var end_grid: Vector3i = plane_viewport.call("_screen_to_grid", end_position)
	var expected_cells: Array[Vector3i] = shape_presenter.build_shape_footprint(
		place_tool_id,
		start_grid,
		end_grid,
		&"xy",
		crafting_ui.active_layer,
		forge_controller.grid_size
	)

	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start_position
	plane_viewport._gui_input(press)
	await process_frame

	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = end_position
	plane_viewport._gui_input(motion)
	await process_frame

	var preview_count: int = plane_viewport.structural_shape_preview_cells.size()
	var preview_3d_visible: bool = (
		crafting_ui.free_workspace_preview != null
		and crafting_ui.free_workspace_preview.structural_shape_preview_instance != null
		and crafting_ui.free_workspace_preview.structural_shape_preview_instance.visible
	)

	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = end_position
	plane_viewport._gui_input(release)
	await process_frame
	await process_frame

	var placed_count: int = _count_cells(crafting_ui.call("_ensure_wip_for_editing"))
	var expected_cells_ok: bool = _footprint_matches(forge_controller, expected_cells, material_id) and placed_count == expected_cells.size()

	crafting_ui.call("_set_active_tool", erase_tool_id)
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
	return {
		"preview_count": preview_count,
		"preview_3d_visible": preview_3d_visible,
		"placed_count": placed_count,
		"expected_count_ok": placed_count == expected_count and expected_cells.size() == expected_count,
		"expected_cells_ok": expected_cells_ok,
		"erase_success": remaining_count == 0,
	}

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

func _popup_has_item_text(popup: PopupMenu, item_text: String) -> bool:
	if popup == null:
		return false
	for item_index: int in range(popup.get_item_count()):
		if popup.get_item_text(item_index) == item_text:
			return true
	return false
