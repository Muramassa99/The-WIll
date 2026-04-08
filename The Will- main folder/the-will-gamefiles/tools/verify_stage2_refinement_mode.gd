extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/stage2_refinement_mode_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	forge_controller.load_new_blank_wip_for_builder_path("Stage2 Mode Test", CraftedItemWIP.BUILDER_PATH_MELEE)
	_seed_cells(forge_controller)
	forge_controller.ensure_stage2_item_state_for_active_wip()
	forge_controller.spawn_test_print_from_active_wip(forge_controller.build_default_material_lookup())
	get_root().add_child(forge_controller)

	var player: PlayerController3D = PlayerScene.instantiate() as PlayerController3D
	get_root().add_child(player)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_for(player, forge_controller, "Stage2 Mode Bench")
	await process_frame
	await process_frame

	crafting_ui.call("_toggle_stage2_refinement_mode")
	await process_frame
	await process_frame

	var preview: ForgeWorkspacePreview = crafting_ui.free_workspace_preview
	var stage2_item_state = forge_controller.active_wip.stage2_item_state if forge_controller.active_wip != null else null
	var stage2_mode_active: bool = bool(crafting_ui.get("stage2_refinement_mode_active"))
	var shell_visible: bool = preview != null and preview.stage2_shell_instance != null and preview.stage2_shell_instance.visible
	var occupied_cells_hidden_in_stage2: bool = preview != null and preview.occupied_cells_instance != null and not preview.occupied_cells_instance.visible
	var draw_text_ok: bool = crafting_ui.draw_tool_button.text == "Apply"
	var erase_text_ok: bool = crafting_ui.erase_tool_button.text == "Revert"
	var brush_screen_position: Vector2 = _resolve_stage2_shell_screen_position(preview, stage2_item_state)
	var hit_data: Dictionary = preview.resolve_stage2_brush_hit(brush_screen_position, forge_controller.active_wip) if preview != null else {}
	var hover_hit_resolved: bool = not hit_data.is_empty()
	crafting_ui.call("_update_stage2_brush_hover", brush_screen_position)
	await process_frame
	var brush_preview_visible: bool = preview != null and preview.stage2_brush_preview_instance != null and preview.stage2_brush_preview_instance.visible
	var origins_before_carve: Array[Vector3] = _collect_patch_origins(forge_controller.active_wip.stage2_item_state)
	crafting_ui.call("_apply_stage2_brush_at_screen_position", brush_screen_position)
	await process_frame
	var carve_changed_shell: bool = _has_any_patch_origin_changed(
		origins_before_carve,
		_collect_patch_origins(forge_controller.active_wip.stage2_item_state)
	)
	var cleared_test_print_after_carve: bool = forge_controller.active_test_print == null

	crafting_ui.call("_toggle_stage2_refinement_mode")
	await process_frame
	var mode_exited: bool = not bool(crafting_ui.get("stage2_refinement_mode_active"))
	var draw_text_restored: bool = crafting_ui.draw_tool_button.text == "Draw"

	var lines: PackedStringArray = []
	lines.append("stage2_mode_active=%s" % str(stage2_mode_active))
	lines.append("stage2_shell_visible=%s" % str(shell_visible))
	lines.append("occupied_cells_hidden_in_stage2=%s" % str(occupied_cells_hidden_in_stage2))
	lines.append("draw_text_ok=%s" % str(draw_text_ok))
	lines.append("erase_text_ok=%s" % str(erase_text_ok))
	lines.append("hover_hit_resolved=%s" % str(hover_hit_resolved))
	lines.append("brush_preview_visible=%s" % str(brush_preview_visible))
	lines.append("carve_changed_shell=%s" % str(carve_changed_shell))
	lines.append("cleared_test_print_after_carve=%s" % str(cleared_test_print_after_carve))
	lines.append("mode_exited=%s" % str(mode_exited))
	lines.append("draw_text_restored=%s" % str(draw_text_restored))

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

func _collect_patch_origins(stage2_item_state) -> Array[Vector3]:
	var origins: Array[Vector3] = []
	if stage2_item_state == null:
		return origins
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null or patch_state.current_quad == null:
			continue
		origins.append(patch_state.current_quad.origin_local)
	return origins

func _has_any_patch_origin_changed(origins_before: Array[Vector3], origins_after: Array[Vector3]) -> bool:
	if origins_before.size() != origins_after.size():
		return true
	for index: int in range(origins_before.size()):
		if not origins_before[index].is_equal_approx(origins_after[index]):
			return true
	return false

func _resolve_stage2_shell_screen_position(preview: ForgeWorkspacePreview, stage2_item_state) -> Vector2:
	if preview == null or stage2_item_state == null or preview.camera == null:
		return Vector2.ZERO
	var stage2_shell_center_local: Vector3 = (
		stage2_item_state.current_local_aabb_position
		+ (stage2_item_state.current_local_aabb_size * 0.5)
	)
	var grid_origin_offset: Vector3 = -Vector3(
		(float(preview.grid_size.x - 1) * preview.cell_world_size) * 0.5,
		(float(preview.grid_size.y - 1) * preview.cell_world_size) * 0.5,
		(float(preview.grid_size.z - 1) * preview.cell_world_size) * 0.5
	)
	var preview_local_point: Vector3 = stage2_shell_center_local * preview.cell_world_size + grid_origin_offset
	return preview.camera.unproject_position(preview.to_global(preview_local_point))
