extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const ForgeStage2SelectionPresenterScript = preload("res://runtime/forge/forge_stage2_selection_presenter.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const Stage2PatchStateScript = preload("res://core/models/stage2_patch_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/stage2_selection_restore_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	forge_controller.load_player_saved_wip(_build_front_heavy_sword_wip())
	var stage2_item_state = forge_controller.ensure_stage2_item_state_for_active_wip()
	get_root().add_child(forge_controller)

	var player: PlayerController3D = PlayerScene.instantiate() as PlayerController3D
	get_root().add_child(player)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_for(player, forge_controller, "Stage2 Selection Restore Bench")
	await process_frame
	await process_frame

	crafting_ui.call("_toggle_stage2_refinement_mode")
	await process_frame
	await process_frame

	var preview: ForgeWorkspacePreview = crafting_ui.free_workspace_preview
	var menu_ids: Dictionary = crafting_ui.call("_get_action_menu_ids")
	var geometry_popup: PopupMenu = crafting_ui.geometry_menu_button.get_popup()
	var selection_presenter = ForgeStage2SelectionPresenterScript.new()
	var face_restore_hidden: bool = not _popup_has_item_text(geometry_popup, "Face Restore Tool")
	var edge_restore_hidden: bool = not _popup_has_item_text(geometry_popup, "Edge Restore Tool")
	var feature_edge_restore_hidden: bool = not _popup_has_item_text(geometry_popup, "Feature Edge Restore Tool")

	var face_target: Dictionary = _resolve_visible_face_target(
		preview,
		forge_controller.active_wip,
		stage2_item_state,
		Stage2PatchStateScript.ZONE_PRIMARY_GRIP_SAFE,
		selection_presenter,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FACE_RESTORE
	)
	var edge_target: Dictionary = _resolve_visible_edge_target(
		preview,
		forge_controller.active_wip,
		stage2_item_state,
		Stage2PatchStateScript.ZONE_GENERAL,
		selection_presenter,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_EDGE_RESTORE
	)
	var feature_edge_target: Dictionary = _resolve_visible_internal_feature_edge_target(
		preview,
		forge_controller.active_wip,
		stage2_item_state,
		Stage2PatchStateScript.ZONE_GENERAL,
		selection_presenter,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_EDGE_RESTORE
	)

	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_tool_surface_face_fillet", -1)))
	await process_frame
	await process_frame
	crafting_ui.erase_tool_button.emit_signal("pressed")
	await process_frame
	await process_frame
	geometry_popup = crafting_ui.geometry_menu_button.get_popup()
	var restore_tool_revert_visible: bool = _popup_has_item_text(geometry_popup, "Revert Selected Targets")
	var restore_tool_clear_visible: bool = _popup_has_item_text(geometry_popup, "Clear Target Selection")

	var face_selected_patch_ids: PackedStringArray = PackedStringArray(face_target.get("patch_ids", PackedStringArray()))
	var face_apply_patch_ids: PackedStringArray = selection_presenter.resolve_selection_apply_patch_ids(
		stage2_item_state,
		face_selected_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FACE_RESTORE
	)
	_offset_patch_ids(stage2_item_state, face_apply_patch_ids, -0.25)
	var origins_before_face_restore: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	var face_restore_changed_shell: bool = crafting_ui.stage2_brush_presenter.apply_selection_tool(
		stage2_item_state,
		face_selected_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FACE_RESTORE,
		face_apply_patch_ids
	) and _has_any_patch_origin_changed(origins_before_face_restore, _collect_patch_origins(stage2_item_state))

	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_tool_surface_edge_fillet", -1)))
	await process_frame
	await process_frame
	crafting_ui.erase_tool_button.emit_signal("pressed")
	await process_frame
	await process_frame
	var edge_selected_patch_ids: PackedStringArray = PackedStringArray(edge_target.get("patch_ids", PackedStringArray()))
	var edge_apply_patch_ids: PackedStringArray = selection_presenter.resolve_selection_apply_patch_ids(
		stage2_item_state,
		edge_selected_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_EDGE_RESTORE
	)
	_offset_patch_ids(stage2_item_state, edge_apply_patch_ids, -0.25)
	var origins_before_edge_restore: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	var edge_restore_changed_shell: bool = crafting_ui.stage2_brush_presenter.apply_selection_tool(
		stage2_item_state,
		edge_selected_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_EDGE_RESTORE,
		edge_apply_patch_ids
	) and _has_any_patch_origin_changed(origins_before_edge_restore, _collect_patch_origins(stage2_item_state))

	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_tool_surface_feature_edge_fillet", -1)))
	await process_frame
	await process_frame
	crafting_ui.erase_tool_button.emit_signal("pressed")
	await process_frame
	await process_frame
	var feature_edge_selected_patch_ids: PackedStringArray = PackedStringArray(feature_edge_target.get("patch_ids", PackedStringArray()))
	var feature_edge_apply_patch_ids: PackedStringArray = selection_presenter.resolve_selection_apply_patch_ids(
		stage2_item_state,
		feature_edge_selected_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_EDGE_RESTORE
	)
	_offset_patch_ids(stage2_item_state, feature_edge_apply_patch_ids, -0.25)
	var origins_before_feature_edge_restore: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	var feature_edge_restore_changed_shell: bool = crafting_ui.stage2_brush_presenter.apply_selection_tool(
		stage2_item_state,
		feature_edge_selected_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_EDGE_RESTORE,
		feature_edge_apply_patch_ids
	) and _has_any_patch_origin_changed(origins_before_feature_edge_restore, _collect_patch_origins(stage2_item_state))

	var lines: PackedStringArray = []
	lines.append("stage2_geometry_menu_face_restore_hidden=%s" % str(face_restore_hidden))
	lines.append("stage2_geometry_menu_edge_restore_hidden=%s" % str(edge_restore_hidden))
	lines.append("stage2_geometry_menu_feature_edge_restore_hidden=%s" % str(feature_edge_restore_hidden))
	lines.append("restore_tool_revert_visible=%s" % str(restore_tool_revert_visible))
	lines.append("restore_tool_clear_visible=%s" % str(restore_tool_clear_visible))
	lines.append("face_selected_count=%d" % face_selected_patch_ids.size())
	lines.append("face_apply_target_count=%d" % face_apply_patch_ids.size())
	lines.append("face_restore_changed_shell=%s" % str(face_restore_changed_shell))
	lines.append("edge_selected_count=%d" % edge_selected_patch_ids.size())
	lines.append("edge_apply_target_count=%d" % edge_apply_patch_ids.size())
	lines.append("edge_restore_changed_shell=%s" % str(edge_restore_changed_shell))
	lines.append("feature_edge_selected_count=%d" % feature_edge_selected_patch_ids.size())
	lines.append("feature_edge_apply_target_count=%d" % feature_edge_apply_patch_ids.size())
	lines.append("feature_edge_restore_changed_shell=%s" % str(feature_edge_restore_changed_shell))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _build_front_heavy_sword_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = &"verify_stage2_selection_restore_front_heavy_sword"
	wip.forge_project_name = "Verify Stage2 Selection Restore Front Heavy Sword"
	wip.creator_id = &"verify"
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.forge_builder_path_id = CraftedItemWIP.BUILDER_PATH_MELEE

	var layer_map: Dictionary = {}
	for x: int in range(40, 52):
		for y: int in range(24, 27):
			for z: int in range(18, 20):
				_add_cell(layer_map, Vector3i(x, y, z), &"mat_wood_gray")
	for x: int in range(52, 65):
		for y: int in range(22, 29):
			for z: int in range(17, 22):
				_add_cell(layer_map, Vector3i(x, y, z), &"mat_iron_gray")

	var ordered_layers: Array = layer_map.keys()
	ordered_layers.sort()
	for layer_index_value in ordered_layers:
		wip.layers.append(layer_map[layer_index_value])
	return wip

func _add_cell(layer_map: Dictionary, grid_position: Vector3i, material_variant_id: StringName) -> void:
	if not layer_map.has(grid_position.z):
		var layer: LayerAtom = LayerAtom.new()
		layer.layer_index = grid_position.z
		layer.cells = []
		layer_map[grid_position.z] = layer
	var cell: CellAtom = CellAtom.new()
	cell.grid_position = grid_position
	cell.layer_index = grid_position.z
	cell.material_variant_id = material_variant_id
	var target_layer: LayerAtom = layer_map[grid_position.z]
	target_layer.cells.append(cell)

func _resolve_visible_face_target(preview: ForgeWorkspacePreview, active_wip: CraftedItemWIP, stage2_item_state, zone_mask_id: StringName, selection_presenter, tool_id: StringName) -> Dictionary:
	if preview == null or active_wip == null or stage2_item_state == null:
		return {}
	var best_target: Dictionary = {}
	var best_selected_count: int = -1
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null or patch_state.current_quad == null:
			continue
		if patch_state.zone_mask_id != zone_mask_id:
			continue
		var screen_position: Vector2 = _resolve_patch_screen_position(preview, patch_state)
		var hit_data: Dictionary = preview.resolve_stage2_brush_hit(screen_position, active_wip)
		if hit_data.is_empty():
			continue
		if StringName(hit_data.get("patch_id", StringName())) != patch_state.patch_id:
			continue
		var hover_selection_data: Dictionary = selection_presenter.resolve_hover_selection_data(stage2_item_state, hit_data, tool_id)
		var patch_ids: PackedStringArray = PackedStringArray(hover_selection_data.get("patch_ids", PackedStringArray()))
		if patch_ids.size() <= best_selected_count:
			continue
		best_selected_count = patch_ids.size()
		best_target = {"patch_ids": patch_ids}
	return best_target

func _resolve_visible_edge_target(preview: ForgeWorkspacePreview, active_wip: CraftedItemWIP, stage2_item_state, zone_mask_id: StringName, selection_presenter, tool_id: StringName) -> Dictionary:
	if preview == null or active_wip == null or stage2_item_state == null:
		return {}
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null or patch_state.current_quad == null:
			continue
		if patch_state.zone_mask_id != zone_mask_id:
			continue
		var screen_position: Vector2 = _resolve_patch_screen_position(preview, patch_state)
		var hit_data: Dictionary = preview.resolve_stage2_brush_hit(screen_position, active_wip)
		if hit_data.is_empty():
			continue
		if StringName(hit_data.get("patch_id", StringName())) != patch_state.patch_id:
			continue
		var hover_selection_data: Dictionary = selection_presenter.resolve_hover_selection_data(stage2_item_state, hit_data, tool_id)
		var patch_ids: PackedStringArray = PackedStringArray(hover_selection_data.get("patch_ids", PackedStringArray()))
		if patch_ids.size() <= 1:
			continue
		return {"patch_ids": patch_ids}
	return {}

func _resolve_visible_internal_feature_edge_target(preview: ForgeWorkspacePreview, active_wip: CraftedItemWIP, stage2_item_state, zone_mask_id: StringName, selection_presenter, tool_id: StringName) -> Dictionary:
	if preview == null or active_wip == null or stage2_item_state == null:
		return {}
	var best_target: Dictionary = {}
	var best_selected_count: int = -1
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null or patch_state.current_quad == null:
			continue
		if patch_state.zone_mask_id != zone_mask_id:
			continue
		var screen_position: Vector2 = _resolve_patch_screen_position(preview, patch_state)
		var hit_data: Dictionary = preview.resolve_stage2_brush_hit(screen_position, active_wip)
		if hit_data.is_empty():
			continue
		if StringName(hit_data.get("patch_id", StringName())) != patch_state.patch_id:
			continue
		var hover_selection_data: Dictionary = selection_presenter.resolve_hover_selection_data(stage2_item_state, hit_data, tool_id)
		var patch_ids: PackedStringArray = PackedStringArray(hover_selection_data.get("patch_ids", PackedStringArray()))
		if patch_ids.size() <= 1:
			continue
		if patch_ids.size() <= best_selected_count:
			continue
		best_selected_count = patch_ids.size()
		best_target = {"patch_ids": patch_ids}
	return best_target

func _offset_patch_ids(stage2_item_state, patch_ids: PackedStringArray, offset_cells: float) -> void:
	if stage2_item_state == null or patch_ids.is_empty():
		return
	var selected_lookup: Dictionary = {}
	for patch_id: String in patch_ids:
		selected_lookup[StringName(patch_id)] = true
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null or patch_state.current_quad == null or patch_state.baseline_quad == null:
			continue
		if not selected_lookup.has(patch_state.patch_id):
			continue
		var normal: Vector3 = patch_state.current_quad.normal.normalized()
		patch_state.current_quad.origin_local = patch_state.baseline_quad.origin_local - (normal * offset_cells)
		patch_state.dirty = true
	stage2_item_state.refresh_current_local_aabb_from_patches()

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

func _resolve_patch_screen_position(preview: ForgeWorkspacePreview, patch_state) -> Vector2:
	if preview == null or patch_state == null or patch_state.current_quad == null or preview.camera == null:
		return Vector2.ZERO
	var patch_center_local: Vector3 = _resolve_patch_center_local(patch_state)
	var grid_origin_offset: Vector3 = -Vector3(
		(float(preview.grid_size.x - 1) * preview.cell_world_size) * 0.5,
		(float(preview.grid_size.y - 1) * preview.cell_world_size) * 0.5,
		(float(preview.grid_size.z - 1) * preview.cell_world_size) * 0.5
	)
	var preview_local_point: Vector3 = patch_center_local * preview.cell_world_size + grid_origin_offset
	return preview.camera.unproject_position(preview.to_global(preview_local_point))

func _resolve_patch_center_local(patch_state) -> Vector3:
	if patch_state == null or patch_state.current_quad == null:
		return Vector3.ZERO
	return patch_state.current_quad.origin_local + (patch_state.current_quad.edge_u_local * 0.5) + (patch_state.current_quad.edge_v_local * 0.5)

func _popup_has_item_text(popup: PopupMenu, item_text: String) -> bool:
	if popup == null:
		return false
	for item_index: int in range(popup.item_count):
		if popup.get_item_text(item_index) == item_text:
			return true
	return false
