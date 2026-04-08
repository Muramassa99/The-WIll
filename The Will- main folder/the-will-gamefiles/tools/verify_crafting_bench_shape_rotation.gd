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

	crafting_ui.open_for(player, forge_controller, "Shape Rotation Verifier Bench")
	await process_frame
	await process_frame

	crafting_ui.call("_create_new_blank_project")
	crafting_ui.call("_set_active_plane", &"xy")
	await process_frame
	await process_frame

	var menu_ids: Dictionary = crafting_ui.call("_get_action_menu_ids")
	var shape_presenter = ForgeWorkspaceShapeToolPresenterScript.new()
	var plane_viewport: ForgePlaneViewport = crafting_ui.plane_viewport
	var material_id: StringName = crafting_ui.armed_material_variant_id if crafting_ui.armed_material_variant_id != StringName() else crafting_ui.selected_material_variant_id

	crafting_ui.call("_set_active_tool", ForgeWorkspaceShapeToolPresenterScript.TOOL_RECTANGLE_PLACE)
	await process_frame
	crafting_ui.call("_rebuild_geometry_menu")
	var geometry_popup: PopupMenu = crafting_ui.geometry_menu_button.get_popup()
	var geometry_menu_has_rotation_label: bool = _popup_has_item_text(geometry_popup, "Shape Rotation: 0°")
	var geometry_menu_has_rotate_left: bool = _popup_has_item_text(geometry_popup, "Rotate Shape -90°")
	var geometry_menu_has_rotate_right: bool = _popup_has_item_text(geometry_popup, "Rotate Shape +90°")
	var rectangle_status_zero_ok: bool = crafting_ui.status_text.text.contains("Rectangle Draw (0°)")

	var rectangle_zero_cells: Array[Vector3i] = shape_presenter.build_shape_footprint(
		ForgeWorkspaceShapeToolPresenterScript.TOOL_RECTANGLE_PLACE,
		Vector3i(2, 5, crafting_ui.active_layer),
		Vector3i(5, 4, crafting_ui.active_layer),
		&"xy",
		crafting_ui.active_layer,
		forge_controller.grid_size,
		0
	)
	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_shape_rotate_right", -1)))
	await process_frame
	crafting_ui.call("_rebuild_geometry_menu")
	var rectangle_rotation_ninety_ok: bool = _popup_has_item_text(crafting_ui.geometry_menu_button.get_popup(), "Shape Rotation: 90°")
	var rectangle_status_ninety_ok: bool = crafting_ui.status_text.text.contains("Rectangle Draw (90°)")
	var rectangle_ninety_cells: Array[Vector3i] = shape_presenter.build_shape_footprint(
		ForgeWorkspaceShapeToolPresenterScript.TOOL_RECTANGLE_PLACE,
		Vector3i(2, 5, crafting_ui.active_layer),
		Vector3i(5, 4, crafting_ui.active_layer),
		&"xy",
		crafting_ui.active_layer,
		forge_controller.grid_size,
		1
	)
	var rectangle_rotation_changed_footprint: bool = not _same_cell_set(rectangle_zero_cells, rectangle_ninety_cells)
	var rectangle_zero_bounds: Vector2i = _plane_footprint_size(rectangle_zero_cells, plane_viewport)
	var rectangle_ninety_bounds: Vector2i = _plane_footprint_size(rectangle_ninety_cells, plane_viewport)
	var rectangle_rotation_swapped_bounds: bool = rectangle_zero_bounds == Vector2i(rectangle_ninety_bounds.y, rectangle_ninety_bounds.x)
	var rectangle_commit_start_grid: Vector3i = plane_viewport.call("_screen_to_grid", _build_plane_position(plane_viewport, 2, 2))
	var rectangle_commit_end_grid: Vector3i = plane_viewport.call("_screen_to_grid", _build_plane_position(plane_viewport, 5, 3))
	var rectangle_commit_expected_cells: Array[Vector3i] = shape_presenter.build_shape_footprint(
		ForgeWorkspaceShapeToolPresenterScript.TOOL_RECTANGLE_PLACE,
		rectangle_commit_start_grid,
		rectangle_commit_end_grid,
		&"xy",
		crafting_ui.active_layer,
		forge_controller.grid_size,
		1
	)
	var rectangle_commit_ok: bool = await _commit_and_match_shape(
		crafting_ui,
		forge_controller,
		plane_viewport,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_RECTANGLE_PLACE,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_RECTANGLE_ERASE,
		Vector2i(2, 2),
		Vector2i(5, 3),
		material_id,
		rectangle_commit_expected_cells
	)

	crafting_ui.call("_set_active_tool", ForgeWorkspaceShapeToolPresenterScript.TOOL_OVAL_PLACE)
	crafting_ui.call("_step_structural_shape_rotation", -1)
	await process_frame
	var oval_status_zero_ok: bool = crafting_ui.status_text.text.contains("Oval Draw (0°)")
	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_shape_rotate_right", -1)))
	await process_frame
	var oval_status_ninety_ok: bool = crafting_ui.status_text.text.contains("Oval Draw (90°)")
	var oval_zero_cells: Array[Vector3i] = shape_presenter.build_shape_footprint(
		ForgeWorkspaceShapeToolPresenterScript.TOOL_OVAL_PLACE,
		Vector3i(2, 5, crafting_ui.active_layer),
		Vector3i(7, 3, crafting_ui.active_layer),
		&"xy",
		crafting_ui.active_layer,
		forge_controller.grid_size,
		0
	)
	var oval_ninety_cells: Array[Vector3i] = shape_presenter.build_shape_footprint(
		ForgeWorkspaceShapeToolPresenterScript.TOOL_OVAL_PLACE,
		Vector3i(2, 5, crafting_ui.active_layer),
		Vector3i(7, 3, crafting_ui.active_layer),
		&"xy",
		crafting_ui.active_layer,
		forge_controller.grid_size,
		1
	)
	var oval_rotation_changed_footprint: bool = not _same_cell_set(oval_zero_cells, oval_ninety_cells)

	crafting_ui.call("_set_active_tool", ForgeWorkspaceShapeToolPresenterScript.TOOL_TRIANGLE_PLACE)
	await process_frame
	var triangle_status_ninety_ok: bool = crafting_ui.status_text.text.contains("Triangle Draw (90°)")
	var triangle_zero_cells: Array[Vector3i] = shape_presenter.build_shape_footprint(
		ForgeWorkspaceShapeToolPresenterScript.TOOL_TRIANGLE_PLACE,
		Vector3i(2, 5, crafting_ui.active_layer),
		Vector3i(6, 1, crafting_ui.active_layer),
		&"xy",
		crafting_ui.active_layer,
		forge_controller.grid_size,
		0
	)
	var triangle_ninety_cells: Array[Vector3i] = shape_presenter.build_shape_footprint(
		ForgeWorkspaceShapeToolPresenterScript.TOOL_TRIANGLE_PLACE,
		Vector3i(2, 5, crafting_ui.active_layer),
		Vector3i(6, 1, crafting_ui.active_layer),
		&"xy",
		crafting_ui.active_layer,
		forge_controller.grid_size,
		1
	)
	var triangle_rotation_changed_footprint: bool = not _same_cell_set(triangle_zero_cells, triangle_ninety_cells)

	crafting_ui.call("_set_active_tool", ForgeWorkspaceShapeToolPresenterScript.TOOL_CIRCLE_PLACE)
	await process_frame
	var circle_zero_cells: Array[Vector3i] = shape_presenter.build_shape_footprint(
		ForgeWorkspaceShapeToolPresenterScript.TOOL_CIRCLE_PLACE,
		Vector3i(2, 5, crafting_ui.active_layer),
		Vector3i(6, 1, crafting_ui.active_layer),
		&"xy",
		crafting_ui.active_layer,
		forge_controller.grid_size,
		0
	)
	var circle_ninety_cells: Array[Vector3i] = shape_presenter.build_shape_footprint(
		ForgeWorkspaceShapeToolPresenterScript.TOOL_CIRCLE_PLACE,
		Vector3i(2, 5, crafting_ui.active_layer),
		Vector3i(6, 1, crafting_ui.active_layer),
		&"xy",
		crafting_ui.active_layer,
		forge_controller.grid_size,
		1
	)
	var circle_rotation_preserved_footprint: bool = _same_cell_set(circle_zero_cells, circle_ninety_cells)

	var lines: PackedStringArray = []
	lines.append("geometry_menu_has_rotation_label=%s" % str(geometry_menu_has_rotation_label))
	lines.append("geometry_menu_has_rotate_left=%s" % str(geometry_menu_has_rotate_left))
	lines.append("geometry_menu_has_rotate_right=%s" % str(geometry_menu_has_rotate_right))
	lines.append("rectangle_status_zero_ok=%s" % str(rectangle_status_zero_ok))
	lines.append("rectangle_rotation_ninety_ok=%s" % str(rectangle_rotation_ninety_ok))
	lines.append("rectangle_status_ninety_ok=%s" % str(rectangle_status_ninety_ok))
	lines.append("rectangle_rotation_changed_footprint=%s" % str(rectangle_rotation_changed_footprint))
	lines.append("rectangle_rotation_swapped_bounds=%s" % str(rectangle_rotation_swapped_bounds))
	lines.append("rectangle_commit_ok=%s" % str(rectangle_commit_ok))
	lines.append("oval_status_zero_ok=%s" % str(oval_status_zero_ok))
	lines.append("oval_status_ninety_ok=%s" % str(oval_status_ninety_ok))
	lines.append("oval_rotation_changed_footprint=%s" % str(oval_rotation_changed_footprint))
	lines.append("triangle_status_ninety_ok=%s" % str(triangle_status_ninety_ok))
	lines.append("triangle_rotation_changed_footprint=%s" % str(triangle_rotation_changed_footprint))
	lines.append("circle_rotation_preserved_footprint=%s" % str(circle_rotation_preserved_footprint))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/crafting_bench_shape_rotation_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _commit_and_match_shape(
	crafting_ui: CraftingBenchUI,
	forge_controller: ForgeGridController,
	plane_viewport: ForgePlaneViewport,
	place_tool_id: StringName,
	erase_tool_id: StringName,
	start_plane_position: Vector2i,
	end_plane_position: Vector2i,
	material_id: StringName,
	expected_cells: Array[Vector3i]
) -> bool:
	crafting_ui.armed_material_variant_id = material_id
	crafting_ui.call("_set_active_tool", place_tool_id)
	await process_frame
	var start_position: Vector2 = _build_plane_position(plane_viewport, start_plane_position.x, start_plane_position.y)
	var end_position: Vector2 = _build_plane_position(plane_viewport, end_plane_position.x, end_plane_position.y)
	_drag_plane(plane_viewport, start_position, end_position)
	await process_frame
	await process_frame
	var matched: bool = _footprint_matches(forge_controller, expected_cells, material_id)
	crafting_ui.call("_set_active_tool", erase_tool_id)
	await process_frame
	_drag_plane(plane_viewport, start_position, end_position)
	await process_frame
	await process_frame
	return matched and _count_cells(crafting_ui.call("_ensure_wip_for_editing")) == 0

func _drag_plane(plane_viewport: ForgePlaneViewport, start_position: Vector2, end_position: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start_position
	plane_viewport._gui_input(press)

	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = end_position
	plane_viewport._gui_input(motion)

	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = end_position
	plane_viewport._gui_input(release)

func _build_plane_position(plane_viewport: ForgePlaneViewport, u: int, v: int) -> Vector2:
	var plane_rect: Rect2 = plane_viewport.call("_get_plane_draw_rect")
	var plane_dimensions: Vector2i = plane_viewport.call("_get_plane_dimensions")
	var cell_size: Vector2 = Vector2(
		plane_rect.size.x / float(plane_dimensions.x),
		plane_rect.size.y / float(plane_dimensions.y)
	)
	return plane_rect.position + Vector2((float(u) + 0.5) * cell_size.x, (float(v) + 0.5) * cell_size.y)

func _same_cell_set(left_cells: Array[Vector3i], right_cells: Array[Vector3i]) -> bool:
	if left_cells.size() != right_cells.size():
		return false
	var lookup: Dictionary = {}
	for grid_position: Vector3i in left_cells:
		lookup[grid_position] = true
	for grid_position: Vector3i in right_cells:
		if not lookup.has(grid_position):
			return false
	return true

func _plane_footprint_size(cells: Array[Vector3i], plane_viewport: ForgePlaneViewport) -> Vector2i:
	if cells.is_empty():
		return Vector2i.ZERO
	var min_x: int = 2147483647
	var max_x: int = -2147483648
	var min_y: int = 2147483647
	var max_y: int = -2147483648
	for grid_position: Vector3i in cells:
		var plane_position_variant: Variant = plane_viewport.call("_grid_to_plane", grid_position)
		if plane_position_variant == null:
			continue
		var plane_position: Vector2i = plane_position_variant
		min_x = mini(min_x, plane_position.x)
		max_x = maxi(max_x, plane_position.x)
		min_y = mini(min_y, plane_position.y)
		max_y = maxi(max_y, plane_position.y)
	return Vector2i((max_x - min_x) + 1, (max_y - min_y) + 1)

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
