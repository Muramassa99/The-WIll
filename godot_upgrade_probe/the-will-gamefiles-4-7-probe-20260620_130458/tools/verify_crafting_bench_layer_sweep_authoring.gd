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

	crafting_ui.open_for(player, forge_controller, "Layer Sweep Verifier Bench")
	await process_frame
	await process_frame

	crafting_ui.call("_create_new_blank_project")
	crafting_ui.call("_set_active_plane", &"xy")
	await process_frame
	await process_frame

	var plane_viewport: ForgePlaneViewport = crafting_ui.plane_viewport
	var initial_material_id: StringName = crafting_ui.armed_material_variant_id if crafting_ui.armed_material_variant_id != StringName() else crafting_ui.selected_material_variant_id
	crafting_ui.call("_set_active_tool", &"place")
	crafting_ui.armed_material_variant_id = initial_material_id
	await process_frame

	var draw_position: Vector2 = _build_plane_position(plane_viewport, 3, 2)
	var start_grid_variant: Variant = plane_viewport.call("_screen_to_grid", draw_position)
	var start_grid: Vector3i = start_grid_variant if start_grid_variant is Vector3i else Vector3i.ZERO
	var start_layer: int = crafting_ui.active_layer

	var plane_press: InputEventMouseButton = InputEventMouseButton.new()
	plane_press.button_index = MOUSE_BUTTON_LEFT
	plane_press.pressed = true
	plane_press.position = draw_position
	plane_viewport._gui_input(plane_press)
	await process_frame

	crafting_ui.call("_begin_layer_hold", 1)
	Input.action_press(&"forge_layer_up")
	crafting_ui.call("_step_layer", 1)
	crafting_ui.call("_process_layer_hold_repeat", 0.49)
	crafting_ui.call("_process_layer_hold_repeat", 0.21)
	Input.action_release(&"forge_layer_up")
	crafting_ui.call("_clear_layer_hold")
	await process_frame
	await process_frame
	var place_end_layer: int = crafting_ui.active_layer

	var place_release: InputEventMouseButton = InputEventMouseButton.new()
	place_release.button_index = MOUSE_BUTTON_LEFT
	place_release.pressed = false
	place_release.position = draw_position
	plane_viewport._gui_input(place_release)
	await process_frame
	await process_frame

	var placed_layers: PackedInt32Array = PackedInt32Array()
	for layer_offset in range(4):
		var query_position: Vector3i = Vector3i(start_grid.x, start_grid.y, start_grid.z + layer_offset)
		if forge_controller.get_material_id_at(query_position) == initial_material_id:
			placed_layers.append(start_grid.z + layer_offset)

	var total_cells_after_place: int = _count_cells(crafting_ui.call("_ensure_wip_for_editing"))

	crafting_ui.call("_set_active_tool", &"erase")
	await process_frame

	var erase_press: InputEventMouseButton = InputEventMouseButton.new()
	erase_press.button_index = MOUSE_BUTTON_LEFT
	erase_press.pressed = true
	erase_press.position = draw_position
	plane_viewport._gui_input(erase_press)
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
	erase_release.position = draw_position
	plane_viewport._gui_input(erase_release)
	await process_frame
	await process_frame

	var cleared_layers: PackedInt32Array = PackedInt32Array()
	for layer_offset in range(4):
		var query_position: Vector3i = Vector3i(start_grid.x, start_grid.y, start_grid.z + layer_offset)
		if forge_controller.get_material_id_at(query_position) == StringName():
			cleared_layers.append(start_grid.z + layer_offset)

	var total_cells_after_erase: int = _count_cells(crafting_ui.call("_ensure_wip_for_editing"))

	var lines: PackedStringArray = []
	lines.append("initial_material_variant_id=%s" % String(initial_material_id))
	lines.append("start_layer=%d" % start_layer)
	lines.append("place_end_layer=%d" % place_end_layer)
	lines.append("placed_layers=%s" % str(Array(placed_layers)))
	lines.append("placed_layer_count=%d" % placed_layers.size())
	lines.append("layer_sweep_place_success=%s" % str(placed_layers.size() == 4))
	lines.append("total_cells_after_place=%d" % total_cells_after_place)
	lines.append("place_one_per_new_layer=%s" % str(total_cells_after_place == 4))
	lines.append("cleared_layers=%s" % str(Array(cleared_layers)))
	lines.append("cleared_layer_count=%d" % cleared_layers.size())
	lines.append("layer_sweep_erase_success=%s" % str(cleared_layers.size() == 4))
	lines.append("total_cells_after_erase=%d" % total_cells_after_erase)
	lines.append("erase_returned_to_empty=%s" % str(total_cells_after_erase == 0))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/crafting_bench_layer_sweep_results.txt", FileAccess.WRITE)
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
