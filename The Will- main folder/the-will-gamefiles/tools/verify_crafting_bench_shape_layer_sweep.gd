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

	crafting_ui.open_for(player, forge_controller, "Shape Layer Sweep Verifier Bench")
	await process_frame
	await process_frame

	crafting_ui.call("_create_new_blank_project")
	crafting_ui.call("_set_active_plane", &"xy")
	await process_frame
	await process_frame

	var plane_viewport: ForgePlaneViewport = crafting_ui.plane_viewport
	var shape_presenter = ForgeWorkspaceShapeToolPresenterScript.new()
	var material_id: StringName = crafting_ui.armed_material_variant_id if crafting_ui.armed_material_variant_id != StringName() else crafting_ui.selected_material_variant_id

	var rectangle_result: Dictionary = await _run_shape_layer_sweep_case(
		crafting_ui,
		forge_controller,
		plane_viewport,
		shape_presenter,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_RECTANGLE_PLACE,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_RECTANGLE_ERASE,
		Vector2i(2, 2),
		Vector2i(5, 3),
		material_id,
		0
	)
	var oval_result: Dictionary = await _run_shape_layer_sweep_case(
		crafting_ui,
		forge_controller,
		plane_viewport,
		shape_presenter,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_OVAL_PLACE,
		ForgeWorkspaceShapeToolPresenterScript.TOOL_OVAL_ERASE,
		Vector2i(2, 2),
		Vector2i(7, 4),
		material_id,
		1
	)

	var lines: PackedStringArray = []
	lines.append("rectangle_place_layer_count=%d" % int(rectangle_result.get("placed_layer_count", 0)))
	lines.append("rectangle_place_expected_total_ok=%s" % str(bool(rectangle_result.get("place_expected_total_ok", false))))
	lines.append("rectangle_place_expected_cells_ok=%s" % str(bool(rectangle_result.get("place_expected_cells_ok", false))))
	lines.append("rectangle_place_one_per_layer_ok=%s" % str(bool(rectangle_result.get("place_one_per_layer_ok", false))))
	lines.append("rectangle_erase_layer_count=%d" % int(rectangle_result.get("cleared_layer_count", 0)))
	lines.append("rectangle_erase_success=%s" % str(bool(rectangle_result.get("erase_success", false))))
	lines.append("oval_place_layer_count=%d" % int(oval_result.get("placed_layer_count", 0)))
	lines.append("oval_place_expected_total_ok=%s" % str(bool(oval_result.get("place_expected_total_ok", false))))
	lines.append("oval_place_expected_cells_ok=%s" % str(bool(oval_result.get("place_expected_cells_ok", false))))
	lines.append("oval_place_one_per_layer_ok=%s" % str(bool(oval_result.get("place_one_per_layer_ok", false))))
	lines.append("oval_erase_layer_count=%d" % int(oval_result.get("cleared_layer_count", 0)))
	lines.append("oval_erase_success=%s" % str(bool(oval_result.get("erase_success", false))))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/crafting_bench_shape_layer_sweep_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _run_shape_layer_sweep_case(
	crafting_ui: CraftingBenchUI,
	forge_controller: ForgeGridController,
	plane_viewport: ForgePlaneViewport,
	shape_presenter,
	place_tool_id: StringName,
	erase_tool_id: StringName,
	start_plane_position: Vector2i,
	end_plane_position: Vector2i,
	material_id: StringName,
	rotation_quadrant: int
) -> Dictionary:
	crafting_ui.call("_create_new_blank_project")
	crafting_ui.call("_set_active_plane", &"xy")
	await process_frame
	await process_frame

	var current_rotation_quadrant: int = int(crafting_ui.structural_shape_rotation_quadrant)
	var rotation_delta: int = posmod(rotation_quadrant - current_rotation_quadrant, 4)
	if rotation_delta != 0:
		crafting_ui.call("_step_structural_shape_rotation", rotation_delta)
		await process_frame

	crafting_ui.armed_material_variant_id = material_id
	crafting_ui.call("_set_active_tool", place_tool_id)
	await process_frame

	var start_position: Vector2 = _build_plane_position(plane_viewport, start_plane_position.x, start_plane_position.y)
	var end_position: Vector2 = _build_plane_position(plane_viewport, end_plane_position.x, end_plane_position.y)
	var start_grid: Vector3i = plane_viewport.call("_screen_to_grid", start_position)
	var end_grid: Vector3i = plane_viewport.call("_screen_to_grid", end_position)
	var expected_footprint: Array[Vector3i] = shape_presenter.build_shape_footprint(
		place_tool_id,
		start_grid,
		end_grid,
		&"xy",
		crafting_ui.active_layer,
		forge_controller.grid_size,
		rotation_quadrant
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

	var start_layer: int = crafting_ui.active_layer
	crafting_ui.call("_begin_layer_hold", 1)
	Input.action_press(&"forge_layer_up")
	crafting_ui.call("_step_layer", 1)
	crafting_ui.call("_process_layer_hold_repeat", 0.49)
	crafting_ui.call("_process_layer_hold_repeat", 0.21)
	Input.action_release(&"forge_layer_up")
	crafting_ui.call("_clear_layer_hold")
	await process_frame
	await process_frame

	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = end_position
	plane_viewport._gui_input(release)
	await process_frame
	await process_frame

	var placed_layers: PackedInt32Array = _collect_matching_layers(
		forge_controller,
		expected_footprint,
		material_id,
		start_layer,
		4
	)
	var total_cells_after_place: int = _count_cells(crafting_ui.call("_ensure_wip_for_editing"))

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

	crafting_ui.call("_begin_layer_hold", -1)
	Input.action_press(&"forge_layer_down")
	crafting_ui.call("_step_layer", -1)
	crafting_ui.call("_process_layer_hold_repeat", 0.49)
	crafting_ui.call("_process_layer_hold_repeat", 0.21)
	Input.action_release(&"forge_layer_down")
	crafting_ui.call("_clear_layer_hold")
	await process_frame
	await process_frame

	var erase_release: InputEventMouseButton = InputEventMouseButton.new()
	erase_release.button_index = MOUSE_BUTTON_LEFT
	erase_release.pressed = false
	erase_release.position = end_position
	plane_viewport._gui_input(erase_release)
	await process_frame
	await process_frame

	var cleared_layers: PackedInt32Array = _collect_empty_layers(
		forge_controller,
		expected_footprint,
		start_layer,
		4
	)
	var total_cells_after_erase: int = _count_cells(crafting_ui.call("_ensure_wip_for_editing"))
	return {
		"placed_layer_count": placed_layers.size(),
		"place_expected_total_ok": total_cells_after_place == expected_footprint.size() * 4,
		"place_expected_cells_ok": placed_layers.size() == 4,
		"place_one_per_layer_ok": total_cells_after_place == expected_footprint.size() * 4,
		"cleared_layer_count": cleared_layers.size(),
		"erase_success": cleared_layers.size() == 4 and total_cells_after_erase == 0,
	}

func _collect_matching_layers(
	forge_controller: ForgeGridController,
	base_footprint: Array[Vector3i],
	material_id: StringName,
	start_layer: int,
	layer_count: int
) -> PackedInt32Array:
	var matched_layers: PackedInt32Array = PackedInt32Array()
	for layer_offset: int in range(layer_count):
		var layer_index: int = start_layer + layer_offset
		var layer_matches: bool = true
		for grid_position: Vector3i in base_footprint:
			var query_position: Vector3i = Vector3i(grid_position.x, grid_position.y, layer_index)
			if forge_controller.get_material_id_at(query_position) != material_id:
				layer_matches = false
				break
		if layer_matches:
			matched_layers.append(layer_index)
	return matched_layers

func _collect_empty_layers(
	forge_controller: ForgeGridController,
	base_footprint: Array[Vector3i],
	start_layer: int,
	layer_count: int
) -> PackedInt32Array:
	var empty_layers: PackedInt32Array = PackedInt32Array()
	for layer_offset: int in range(layer_count):
		var layer_index: int = start_layer + layer_offset
		var layer_empty: bool = true
		for grid_position: Vector3i in base_footprint:
			var query_position: Vector3i = Vector3i(grid_position.x, grid_position.y, layer_index)
			if forge_controller.get_material_id_at(query_position) != StringName():
				layer_empty = false
				break
		if layer_empty:
			empty_layers.append(layer_index)
	return empty_layers

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
