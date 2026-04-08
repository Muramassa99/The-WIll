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

	crafting_ui.open_for(player, forge_controller, "Paint Verifier Bench")
	await process_frame
	await process_frame

	crafting_ui.call("_create_new_blank_project")
	await process_frame
	await process_frame

	var plane_viewport: ForgePlaneViewport = crafting_ui.plane_viewport
	var initial_material_id: StringName = crafting_ui.armed_material_variant_id if crafting_ui.armed_material_variant_id != StringName() else crafting_ui.selected_material_variant_id
	var plane_positions: Array[Vector2] = _build_plane_drag_positions(plane_viewport, 3, 2, 3)

	var plane_press: InputEventMouseButton = InputEventMouseButton.new()
	plane_press.button_index = MOUSE_BUTTON_LEFT
	plane_press.pressed = true
	plane_press.position = plane_positions[0]
	plane_viewport._gui_input(plane_press)
	await process_frame

	for drag_index in range(1, plane_positions.size()):
		var plane_motion: InputEventMouseMotion = InputEventMouseMotion.new()
		plane_motion.position = plane_positions[drag_index]
		plane_viewport._gui_input(plane_motion)
		await process_frame

	var plane_release: InputEventMouseButton = InputEventMouseButton.new()
	plane_release.button_index = MOUSE_BUTTON_LEFT
	plane_release.pressed = false
	plane_release.position = plane_positions[plane_positions.size() - 1]
	plane_viewport._gui_input(plane_release)
	await process_frame
	await process_frame

	var plane_draw_count: int = crafting_ui.call("_count_cells", crafting_ui.call("_ensure_wip_for_editing"))

	crafting_ui.call("_set_active_tool", &"erase")
	await process_frame

	var plane_erase_press: InputEventMouseButton = InputEventMouseButton.new()
	plane_erase_press.button_index = MOUSE_BUTTON_LEFT
	plane_erase_press.pressed = true
	plane_erase_press.position = plane_positions[0]
	plane_viewport._gui_input(plane_erase_press)
	await process_frame

	for erase_index in range(1, plane_positions.size() - 1):
		var plane_erase_motion: InputEventMouseMotion = InputEventMouseMotion.new()
		plane_erase_motion.position = plane_positions[erase_index]
		plane_viewport._gui_input(plane_erase_motion)
		await process_frame

	var plane_erase_release: InputEventMouseButton = InputEventMouseButton.new()
	plane_erase_release.button_index = MOUSE_BUTTON_LEFT
	plane_erase_release.pressed = false
	plane_erase_release.position = plane_positions[plane_positions.size() - 2]
	plane_viewport._gui_input(plane_erase_release)
	await process_frame
	await process_frame

	var plane_remaining_count: int = crafting_ui.call("_count_cells", crafting_ui.call("_ensure_wip_for_editing"))

	crafting_ui.call("_create_new_blank_project")
	await process_frame
	await process_frame
	crafting_ui.call("_set_active_tool", &"place")
	crafting_ui.armed_material_variant_id = initial_material_id
	await process_frame

	var free_positions: Array[Vector2] = _build_free_view_drag_positions(crafting_ui.free_workspace_preview, crafting_ui.free_view_container.size)
	crafting_ui.call("_begin_free_view_paint")
	for screen_position in free_positions:
		crafting_ui.call("_paint_free_view_at_screen_position", screen_position)
		await process_frame
	crafting_ui.call("_end_free_view_paint")
	await process_frame
	await process_frame

	var free_draw_count: int = crafting_ui.call("_count_cells", crafting_ui.call("_ensure_wip_for_editing"))

	crafting_ui.call("_set_active_tool", &"erase")
	crafting_ui.call("_begin_free_view_paint")
	for erase_index in range(mini(2, free_positions.size())):
		crafting_ui.call("_paint_free_view_at_screen_position", free_positions[erase_index])
		await process_frame
	crafting_ui.call("_end_free_view_paint")
	await process_frame
	await process_frame

	var free_remaining_count: int = crafting_ui.call("_count_cells", crafting_ui.call("_ensure_wip_for_editing"))

	var lines: PackedStringArray = []
	lines.append("armed_material_variant_id=%s" % String(initial_material_id))
	lines.append("plane_position_count=%d" % plane_positions.size())
	lines.append("plane_draw_count=%d" % plane_draw_count)
	lines.append("plane_drag_place_success=%s" % str(plane_draw_count == 3))
	lines.append("plane_remaining_count=%d" % plane_remaining_count)
	lines.append("plane_drag_erase_success=%s" % str(plane_remaining_count == 1))
	lines.append("free_position_count=%d" % free_positions.size())
	lines.append("free_draw_count=%d" % free_draw_count)
	lines.append("free_drag_place_success=%s" % str(free_draw_count == 3))
	lines.append("free_remaining_count=%d" % free_remaining_count)
	lines.append("free_drag_erase_success=%s" % str(free_remaining_count == 1))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/crafting_bench_paint_drag_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _build_plane_drag_positions(plane_viewport: ForgePlaneViewport, start_u: int, start_v: int, count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var plane_rect: Rect2 = plane_viewport.call("_get_plane_draw_rect")
	var plane_dimensions: Vector2i = plane_viewport.call("_get_plane_dimensions")
	var cell_size: Vector2 = Vector2(
		plane_rect.size.x / float(plane_dimensions.x),
		plane_rect.size.y / float(plane_dimensions.y)
	)
	for offset_index in range(count):
		var u: int = start_u + offset_index
		var v: int = start_v
		positions.append(plane_rect.position + Vector2((float(u) + 0.5) * cell_size.x, (float(v) + 0.5) * cell_size.y))
	return positions

func _build_free_view_drag_positions(preview: ForgeWorkspacePreview, container_size: Vector2) -> Array[Vector2]:
	var candidate_offsets: Array[float] = [-180.0, -120.0, -60.0, 0.0, 60.0, 120.0, 180.0]
	var positions: Array[Vector2] = []
	var used_grids: Array[Vector3i] = []
	for offset_value in candidate_offsets:
		var candidate_position: Vector2 = Vector2(container_size.x * 0.5 + offset_value, container_size.y * 0.5)
		var grid_position_variant: Variant = preview.screen_to_grid(candidate_position)
		if grid_position_variant == null:
			continue
		var grid_position: Vector3i = grid_position_variant
		if used_grids.has(grid_position):
			continue
		used_grids.append(grid_position)
		positions.append(candidate_position)
		if positions.size() == 3:
			break
	return positions
