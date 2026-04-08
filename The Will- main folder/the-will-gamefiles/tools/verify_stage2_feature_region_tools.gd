extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const ForgeStage2SelectionPresenterScript = preload("res://runtime/forge/forge_stage2_selection_presenter.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const Stage2PatchStateScript = preload("res://core/models/stage2_patch_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/stage2_feature_region_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	forge_controller.load_player_saved_wip(_build_front_heavy_sword_wip())
	var stage2_item_state = forge_controller.ensure_stage2_item_state_for_active_wip()
	get_root().add_child(forge_controller)

	var grip_safe_patch = _find_internal_patch(stage2_item_state, Stage2PatchStateScript.ZONE_PRIMARY_GRIP_SAFE)
	var general_patch = _find_internal_patch(stage2_item_state, Stage2PatchStateScript.ZONE_GENERAL)
	_build_offset_cluster(stage2_item_state, grip_safe_patch, 4, -0.25)
	_build_offset_cluster(stage2_item_state, general_patch, 5, -0.25)
	stage2_item_state.refresh_current_local_aabb_from_patches()

	var player: PlayerController3D = PlayerScene.instantiate() as PlayerController3D
	get_root().add_child(player)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_for(player, forge_controller, "Stage2 Feature Region Bench")
	await process_frame
	await process_frame

	crafting_ui.call("_toggle_stage2_refinement_mode")
	await process_frame
	await process_frame

	var menu_ids: Dictionary = crafting_ui.call("_get_action_menu_ids")
	var geometry_popup: PopupMenu = crafting_ui.geometry_menu_button.get_popup()
	var selection_presenter = ForgeStage2SelectionPresenterScript.new()
	var has_feature_region_fillet_tool: bool = _popup_has_item_text(geometry_popup, "Feature Region Fillet Tool")
	var has_feature_region_chamfer_tool: bool = _popup_has_item_text(geometry_popup, "Feature Region Chamfer Tool")

	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_tool_surface_feature_region_fillet", -1)))
	await process_frame
	await process_frame

	geometry_popup = crafting_ui.geometry_menu_button.get_popup()
	var feature_region_tool_apply_visible: bool = _popup_has_item_text(geometry_popup, "Apply Selected Targets")
	var feature_region_tool_clear_visible: bool = _popup_has_item_text(geometry_popup, "Clear Target Selection")

	var grip_safe_selection_data: Dictionary = selection_presenter.resolve_hover_selection_data(
		stage2_item_state,
		_build_patch_hit_data(grip_safe_patch),
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_REGION_FILLET
	)
	var grip_safe_patch_ids: PackedStringArray = PackedStringArray(grip_safe_selection_data.get("patch_ids", PackedStringArray()))
	var grip_safe_selected_count: int = grip_safe_patch_ids.size()
	var grip_safe_apply_patch_ids: PackedStringArray = selection_presenter.resolve_selection_apply_patch_ids(
		stage2_item_state,
		grip_safe_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_REGION_FILLET
	)
	var hover_preview_visible: bool = not grip_safe_patch_ids.is_empty()
	var selected_preview_visible: bool = not grip_safe_patch_ids.is_empty()
	var origins_before_safe_feature_region_fillet: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	var grip_safe_feature_region_fillet_changed_shell: bool = crafting_ui.stage2_brush_presenter.apply_selection_tool(
		stage2_item_state,
		grip_safe_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_REGION_FILLET,
		grip_safe_apply_patch_ids
	) and _has_any_patch_origin_changed(
		origins_before_safe_feature_region_fillet,
		_collect_patch_origins(stage2_item_state)
	)
	var grip_safe_feature_region_changed_patch_count: int = _count_changed_patch_origins(
		origins_before_safe_feature_region_fillet,
		_collect_patch_origins(stage2_item_state)
	)

	var selected_count_after_clear: int = 0

	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_tool_surface_feature_region_chamfer", -1)))
	await process_frame
	await process_frame
	var grip_safe_chamfer_patch_ids: PackedStringArray = PackedStringArray(selection_presenter.resolve_hover_selection_data(
		stage2_item_state,
		_build_patch_hit_data(grip_safe_patch),
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER
	).get("patch_ids", PackedStringArray()))
	var grip_safe_chamfer_apply_patch_ids: PackedStringArray = selection_presenter.resolve_selection_apply_patch_ids(
		stage2_item_state,
		grip_safe_chamfer_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER
	)
	var origins_before_safe_feature_region_chamfer: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	var grip_safe_feature_region_chamfer_changed_shell: bool = crafting_ui.stage2_brush_presenter.apply_selection_tool(
		stage2_item_state,
		grip_safe_chamfer_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER,
		grip_safe_chamfer_apply_patch_ids
	) and _has_any_patch_origin_changed(
		origins_before_safe_feature_region_chamfer,
		_collect_patch_origins(stage2_item_state)
	)

	var general_chamfer_patch_ids: PackedStringArray = PackedStringArray(selection_presenter.resolve_hover_selection_data(
		stage2_item_state,
		_build_patch_hit_data(general_patch),
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER
	).get("patch_ids", PackedStringArray()))
	var general_selected_count: int = general_chamfer_patch_ids.size()
	var general_chamfer_apply_patch_ids: PackedStringArray = selection_presenter.resolve_selection_apply_patch_ids(
		stage2_item_state,
		general_chamfer_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER
	)
	var origins_before_general_feature_region_chamfer: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	var general_feature_region_chamfer_changed_shell: bool = crafting_ui.stage2_brush_presenter.apply_selection_tool(
		stage2_item_state,
		general_chamfer_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_REGION_CHAMFER,
		general_chamfer_apply_patch_ids
	) and _has_any_patch_origin_changed(
		origins_before_general_feature_region_chamfer,
		_collect_patch_origins(stage2_item_state)
	)
	var general_feature_region_changed_patch_count: int = _count_changed_patch_origins(
		origins_before_general_feature_region_chamfer,
		_collect_patch_origins(stage2_item_state)
	)

	var lines: PackedStringArray = []
	lines.append("stage2_geometry_menu_has_feature_region_fillet=%s" % str(has_feature_region_fillet_tool))
	lines.append("stage2_geometry_menu_has_feature_region_chamfer=%s" % str(has_feature_region_chamfer_tool))
	lines.append("feature_region_tool_apply_visible=%s" % str(feature_region_tool_apply_visible))
	lines.append("feature_region_tool_clear_visible=%s" % str(feature_region_tool_clear_visible))
	lines.append("hover_preview_visible=%s" % str(hover_preview_visible))
	lines.append("selected_preview_visible=%s" % str(selected_preview_visible))
	lines.append("grip_safe_selected_count=%d" % grip_safe_selected_count)
	lines.append("grip_safe_apply_target_count=%d" % grip_safe_apply_patch_ids.size())
	lines.append("grip_safe_feature_region_fillet_changed_shell=%s" % str(grip_safe_feature_region_fillet_changed_shell))
	lines.append("grip_safe_feature_region_changed_patch_count=%d" % grip_safe_feature_region_changed_patch_count)
	lines.append("selected_count_after_clear=%d" % selected_count_after_clear)
	lines.append("grip_safe_feature_region_chamfer_changed_shell=%s" % str(grip_safe_feature_region_chamfer_changed_shell))
	lines.append("general_selected_count=%d" % general_selected_count)
	lines.append("general_apply_target_count=%d" % general_chamfer_apply_patch_ids.size())
	lines.append("general_feature_region_chamfer_changed_shell=%s" % str(general_feature_region_chamfer_changed_shell))
	lines.append("general_feature_region_changed_patch_count=%d" % general_feature_region_changed_patch_count)

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _build_front_heavy_sword_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = &"verify_stage2_feature_region_front_heavy_sword"
	wip.forge_project_name = "Verify Stage2 Feature Region Front Heavy Sword"
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

func _find_internal_patch(stage2_item_state, zone_mask_id: StringName):
	if stage2_item_state == null:
		return null
	var patch_lookup: Dictionary = {}
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null:
			continue
		patch_lookup[patch_state.patch_id] = patch_state
	var best_patch = null
	var best_neighbor_count: int = -1
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null or patch_state.current_quad == null:
			continue
		if patch_state.zone_mask_id != zone_mask_id:
			continue
		var internal_neighbor_count: int = 0
		for neighbor_patch_id_string: String in patch_state.neighbor_patch_ids:
			var neighbor_patch_state = patch_lookup.get(StringName(neighbor_patch_id_string), null)
			if neighbor_patch_state == null or neighbor_patch_state.current_quad == null:
				continue
			if neighbor_patch_state.zone_mask_id != zone_mask_id:
				continue
			if not patch_state.current_quad.normal.normalized().is_equal_approx(neighbor_patch_state.current_quad.normal.normalized()):
				continue
			internal_neighbor_count += 1
		if internal_neighbor_count > best_neighbor_count:
			best_neighbor_count = internal_neighbor_count
			best_patch = patch_state
	return best_patch

func _build_offset_cluster(stage2_item_state, anchor_patch, desired_count: int, offset_cells: float) -> PackedStringArray:
	var cluster_patch_ids: PackedStringArray = PackedStringArray()
	if stage2_item_state == null or anchor_patch == null or anchor_patch.current_quad == null:
		return cluster_patch_ids
	var patch_lookup: Dictionary = {}
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null:
			continue
		patch_lookup[patch_state.patch_id] = patch_state
	var anchor_normal: Vector3 = anchor_patch.current_quad.normal.normalized()
	var visited_lookup: Dictionary = {}
	var pending_patch_ids: Array[StringName] = [anchor_patch.patch_id]
	while not pending_patch_ids.is_empty() and cluster_patch_ids.size() < desired_count:
		var patch_id: StringName = pending_patch_ids.pop_back()
		if patch_id == StringName() or visited_lookup.has(patch_id):
			continue
		visited_lookup[patch_id] = true
		var patch_state = patch_lookup.get(patch_id, null)
		if patch_state == null or patch_state.current_quad == null:
			continue
		if patch_state.zone_mask_id != anchor_patch.zone_mask_id:
			continue
		if not patch_state.current_quad.normal.normalized().is_equal_approx(anchor_normal):
			continue
		cluster_patch_ids.append(String(patch_id))
		_set_patch_offset_cells(patch_state, offset_cells)
		for neighbor_patch_id_string: String in patch_state.neighbor_patch_ids:
			var neighbor_patch_id: StringName = StringName(neighbor_patch_id_string)
			if not visited_lookup.has(neighbor_patch_id):
				pending_patch_ids.append(neighbor_patch_id)
	return cluster_patch_ids

func _set_patch_offset_cells(patch_state, offset_cells: float) -> void:
	if patch_state == null or patch_state.baseline_quad == null or patch_state.current_quad == null:
		return
	var normal: Vector3 = patch_state.current_quad.normal.normalized()
	patch_state.current_quad.origin_local = patch_state.baseline_quad.origin_local - (normal * offset_cells)
	patch_state.dirty = true

func _build_patch_hit_data(patch_state) -> Dictionary:
	if patch_state == null or patch_state.current_quad == null:
		return {}
	return {
		"patch_id": patch_state.patch_id,
		"hit_point_canonical_local": _resolve_patch_center_local(patch_state),
	}

func _resolve_patch_center_local(patch_state) -> Vector3:
	return patch_state.current_quad.origin_local + (patch_state.current_quad.edge_u_local * 0.5) + (patch_state.current_quad.edge_v_local * 0.5)

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

func _count_changed_patch_origins(origins_before: Array[Vector3], origins_after: Array[Vector3]) -> int:
	if origins_before.size() != origins_after.size():
		return maxi(origins_before.size(), origins_after.size())
	var changed_count: int = 0
	for index: int in range(origins_before.size()):
		if not origins_before[index].is_equal_approx(origins_after[index]):
			changed_count += 1
	return changed_count

func _popup_has_item_text(popup: PopupMenu, item_text: String) -> bool:
	if popup == null:
		return false
	for item_index: int in range(popup.item_count):
		if popup.get_item_text(item_index) == item_text:
			return true
	return false
