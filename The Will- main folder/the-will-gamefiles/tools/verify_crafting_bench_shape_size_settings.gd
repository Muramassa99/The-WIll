extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const ForgeWorkspaceShapeToolPresenterScript = preload("res://runtime/forge/forge_workspace_shape_tool_presenter.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/crafting_bench_shape_size_settings_results.txt"

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

	crafting_ui.open_for(player, forge_controller, "Shape Size Settings Bench")
	await process_frame
	await process_frame

	crafting_ui.call("_create_new_blank_project")
	crafting_ui.call("_set_active_plane", &"xy")
	await process_frame
	await process_frame

	var plane_viewport: ForgePlaneViewport = crafting_ui.plane_viewport
	var shape_presenter = ForgeWorkspaceShapeToolPresenterScript.new()
	var material_id: StringName = crafting_ui.armed_material_variant_id if crafting_ui.armed_material_variant_id != StringName() else crafting_ui.selected_material_variant_id

	crafting_ui.call("_set_active_tool", ForgeWorkspaceShapeToolPresenterScript.TOOL_RECTANGLE_PLACE)
	await process_frame
	var shape_tool_forces_plane_mode: bool = crafting_ui.main_workspace_mode == crafting_ui.WORKSPACE_VIEW_PLANE
	crafting_ui.call("_step_stage1_shape_primary_size", 2)
	crafting_ui.call("_step_stage1_shape_secondary_size", 1)
	await process_frame
	var rectangle_click_result: Dictionary = await _run_click_shape_case(
		crafting_ui,
		forge_controller,
		plane_viewport,
		shape_presenter,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_RECTANGLE_PLACE,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_RECTANGLE_ERASE,
		Vector2i(6, 6),
		material_id
	)

	crafting_ui.call("_set_active_tool", ForgeWorkspaceShapeToolPresenterScript.TOOL_CIRCLE_PLACE)
	await process_frame
	crafting_ui.call("_step_stage1_shape_primary_size", 2)
	await process_frame
	var circle_click_result: Dictionary = await _run_click_shape_case(
		crafting_ui,
		forge_controller,
		plane_viewport,
		shape_presenter,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_CIRCLE_PLACE,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_CIRCLE_ERASE,
		Vector2i(10, 6),
		material_id
	)

	crafting_ui.call("_set_active_tool", ForgeWorkspaceShapeToolPresenterScript.TOOL_TRIANGLE_PLACE)
	await process_frame
	crafting_ui.call("_step_stage1_shape_primary_size", 2)
	crafting_ui.call("_step_stage1_shape_secondary_size", 2)
	await process_frame
	var triangle_click_result: Dictionary = await _run_click_shape_case(
		crafting_ui,
		forge_controller,
		plane_viewport,
		shape_presenter,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_TRIANGLE_PLACE,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_TRIANGLE_ERASE,
		Vector2i(14, 7),
		material_id
	)

	var lines: PackedStringArray = []
	lines.append("shape_tool_forces_plane_mode=%s" % str(shape_tool_forces_plane_mode))
	lines.append("rectangle_fixed_hover_preview_present=%s" % str(bool(rectangle_click_result.get("hover_preview_present", false))))
	lines.append("rectangle_fixed_click_expected_cells_ok=%s" % str(bool(rectangle_click_result.get("expected_cells_ok", false))))
	lines.append("rectangle_fixed_click_preview_present=%s" % str(bool(rectangle_click_result.get("preview_present", false))))
	lines.append("rectangle_fixed_click_erase_success=%s" % str(bool(rectangle_click_result.get("erase_success", false))))
	lines.append("circle_fixed_hover_preview_present=%s" % str(bool(circle_click_result.get("hover_preview_present", false))))
	lines.append("circle_fixed_click_expected_cells_ok=%s" % str(bool(circle_click_result.get("expected_cells_ok", false))))
	lines.append("circle_fixed_click_preview_present=%s" % str(bool(circle_click_result.get("preview_present", false))))
	lines.append("circle_fixed_click_erase_success=%s" % str(bool(circle_click_result.get("erase_success", false))))
	lines.append("triangle_fixed_hover_preview_present=%s" % str(bool(triangle_click_result.get("hover_preview_present", false))))
	lines.append("triangle_fixed_click_expected_cells_ok=%s" % str(bool(triangle_click_result.get("expected_cells_ok", false))))
	lines.append("triangle_fixed_click_preview_present=%s" % str(bool(triangle_click_result.get("preview_present", false))))
	lines.append("triangle_fixed_click_erase_success=%s" % str(bool(triangle_click_result.get("erase_success", false))))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _run_click_shape_case(
	crafting_ui: CraftingBenchUI,
	forge_controller: ForgeGridController,
	plane_viewport: ForgePlaneViewport,
	shape_presenter,
	place_tool_id: StringName,
	erase_tool_id: StringName,
	plane_position_uv: Vector2i,
	material_id: StringName
) -> Dictionary:
	crafting_ui.armed_material_variant_id = material_id
	crafting_ui.call("_set_active_tool", place_tool_id)
	await process_frame

	var click_position: Vector2 = _build_plane_position(plane_viewport, plane_position_uv.x, plane_position_uv.y)
	var click_grid: Vector3i = plane_viewport.call("_screen_to_grid", click_position)
	var shape_settings: Dictionary = crafting_ui.call("_get_stage1_shape_settings")
	shape_settings["use_fixed_size"] = true
	var expected_cells: Array[Vector3i] = shape_presenter.build_shape_footprint(
		place_tool_id,
		click_grid,
		click_grid,
		&"xy",
		crafting_ui.active_layer,
		forge_controller.grid_size,
		int(crafting_ui.get("structural_shape_rotation_quadrant")),
		shape_settings
	)

	var hover_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	hover_motion.position = click_position
	plane_viewport._gui_input(hover_motion)
	await process_frame

	var hover_preview_present: bool = plane_viewport.structural_shape_preview_cells.size() == expected_cells.size() and not expected_cells.is_empty()

	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = click_position
	plane_viewport._gui_input(press)
	await process_frame

	var preview_present: bool = plane_viewport.structural_shape_preview_cells.size() == expected_cells.size() and not expected_cells.is_empty()

	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = click_position
	plane_viewport._gui_input(release)
	await process_frame
	await process_frame

	var expected_cells_ok: bool = _footprint_matches(forge_controller, expected_cells, material_id)

	crafting_ui.call("_set_active_tool", erase_tool_id)
	await process_frame
	var erase_press: InputEventMouseButton = InputEventMouseButton.new()
	erase_press.button_index = MOUSE_BUTTON_LEFT
	erase_press.pressed = true
	erase_press.position = click_position
	plane_viewport._gui_input(erase_press)
	await process_frame
	var erase_release: InputEventMouseButton = InputEventMouseButton.new()
	erase_release.button_index = MOUSE_BUTTON_LEFT
	erase_release.pressed = false
	erase_release.position = click_position
	plane_viewport._gui_input(erase_release)
	await process_frame
	await process_frame

	return {
		"hover_preview_present": hover_preview_present,
		"preview_present": preview_present,
		"expected_cells_ok": expected_cells_ok,
		"erase_success": _count_cells(crafting_ui.call("_ensure_wip_for_editing")) == 0,
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
