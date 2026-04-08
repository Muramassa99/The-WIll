extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const ForgeStage2SelectionPresenterScript = preload("res://runtime/forge/forge_stage2_selection_presenter.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const Stage2PatchStateScript = preload("res://core/models/stage2_patch_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/stage2_selection_feature_results.txt"

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

	crafting_ui.open_for(player, forge_controller, "Stage2 Selection Feature Bench")
	await process_frame
	await process_frame

	crafting_ui.call("_toggle_stage2_refinement_mode")
	await process_frame
	await process_frame

	var preview: ForgeWorkspacePreview = crafting_ui.free_workspace_preview
	var menu_ids: Dictionary = crafting_ui.call("_get_action_menu_ids")
	var geometry_popup: PopupMenu = crafting_ui.geometry_menu_button.get_popup()
	var has_face_fillet_tool: bool = _popup_has_item_text(geometry_popup, "Face Fillet Tool")
	var has_face_chamfer_tool: bool = _popup_has_item_text(geometry_popup, "Face Chamfer Tool")
	var stage2_selection_presenter = ForgeStage2SelectionPresenterScript.new()

	var grip_safe_hit: Dictionary = _resolve_visible_face_selection_hit(
		preview,
		forge_controller.active_wip,
		stage2_item_state,
		Stage2PatchStateScript.ZONE_PRIMARY_GRIP_SAFE,
		stage2_selection_presenter,
		StringName("stage2_surface_face_fillet")
	)
	var general_hit: Dictionary = _resolve_visible_face_selection_hit(
		preview,
		forge_controller.active_wip,
		stage2_item_state,
		Stage2PatchStateScript.ZONE_GENERAL,
		stage2_selection_presenter,
		StringName("stage2_surface_face_chamfer")
	)

	var grip_safe_screen_position: Vector2 = grip_safe_hit.get("screen_position", Vector2.ZERO)
	var grip_safe_selected_count: int = int(grip_safe_hit.get("selected_patch_count", 0))
	var grip_safe_apply_target_count: int = int(grip_safe_hit.get("apply_patch_count", 0))
	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_tool_surface_face_fillet", -1)))
	await process_frame
	await process_frame
	geometry_popup = crafting_ui.geometry_menu_button.get_popup()
	var face_tool_apply_visible: bool = _popup_has_item_text(geometry_popup, "Apply Selected Targets")
	var face_tool_clear_visible: bool = _popup_has_item_text(geometry_popup, "Clear Target Selection")
	crafting_ui.call("_update_stage2_selection_hover", grip_safe_screen_position)
	await process_frame
	var hover_preview_visible: bool = preview != null and preview.stage2_hover_face_instance != null and preview.stage2_hover_face_instance.visible
	crafting_ui.call("_toggle_stage2_patch_selection_at_screen_position", grip_safe_screen_position)
	await process_frame
	var selected_preview_visible: bool = preview != null and preview.stage2_selected_faces_instance != null and preview.stage2_selected_faces_instance.visible
	var selected_count_after_pick: int = PackedStringArray(crafting_ui.get("stage2_selected_patch_ids")).size()
	var origins_before_safe_face_fillet: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_selection_apply", -1)))
	await process_frame
	var origins_after_safe_face_fillet: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	var grip_safe_face_fillet_changed_shell: bool = _has_any_patch_origin_changed(
		origins_before_safe_face_fillet,
		origins_after_safe_face_fillet
	)
	var grip_safe_face_fillet_changed_patch_count: int = _count_changed_patch_origins(
		origins_before_safe_face_fillet,
		origins_after_safe_face_fillet
	)

	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_selection_clear", -1)))
	await process_frame
	var selected_count_after_clear: int = PackedStringArray(crafting_ui.get("stage2_selected_patch_ids")).size()

	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_tool_surface_face_chamfer", -1)))
	await process_frame
	await process_frame
	crafting_ui.call("_toggle_stage2_patch_selection_at_screen_position", grip_safe_screen_position)
	await process_frame
	var origins_before_safe_face_chamfer: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_selection_apply", -1)))
	await process_frame
	var origins_after_safe_face_chamfer: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	var grip_safe_face_chamfer_changed_shell: bool = _has_any_patch_origin_changed(
		origins_before_safe_face_chamfer,
		origins_after_safe_face_chamfer
	)

	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_selection_clear", -1)))
	await process_frame
	var general_screen_position: Vector2 = general_hit.get("screen_position", Vector2.ZERO)
	var general_selected_count: int = int(general_hit.get("selected_patch_count", 0))
	var general_apply_target_count: int = int(general_hit.get("apply_patch_count", 0))
	crafting_ui.call("_toggle_stage2_patch_selection_at_screen_position", general_screen_position)
	await process_frame
	var origins_before_general_face_chamfer: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_selection_apply", -1)))
	await process_frame
	var origins_after_general_face_chamfer: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	var general_face_chamfer_changed_shell: bool = _has_any_patch_origin_changed(
		origins_before_general_face_chamfer,
		origins_after_general_face_chamfer
	)
	var general_face_chamfer_changed_patch_count: int = _count_changed_patch_origins(
		origins_before_general_face_chamfer,
		origins_after_general_face_chamfer
	)

	var lines: PackedStringArray = []
	lines.append("stage2_geometry_menu_has_face_fillet=%s" % str(has_face_fillet_tool))
	lines.append("stage2_geometry_menu_has_face_chamfer=%s" % str(has_face_chamfer_tool))
	lines.append("face_tool_apply_visible=%s" % str(face_tool_apply_visible))
	lines.append("face_tool_clear_visible=%s" % str(face_tool_clear_visible))
	lines.append("hover_preview_visible=%s" % str(hover_preview_visible))
	lines.append("selected_preview_visible=%s" % str(selected_preview_visible))
	lines.append("selected_count_after_pick=%d" % selected_count_after_pick)
	lines.append("grip_safe_selected_count=%d" % grip_safe_selected_count)
	lines.append("grip_safe_apply_target_count=%d" % grip_safe_apply_target_count)
	lines.append("grip_safe_face_fillet_changed_shell=%s" % str(grip_safe_face_fillet_changed_shell))
	lines.append("grip_safe_face_fillet_changed_patch_count=%d" % grip_safe_face_fillet_changed_patch_count)
	lines.append("grip_safe_face_boundary_smaller_than_selection=%s" % str(grip_safe_apply_target_count < grip_safe_selected_count))
	lines.append("selected_count_after_clear=%d" % selected_count_after_clear)
	lines.append("grip_safe_face_chamfer_changed_shell=%s" % str(grip_safe_face_chamfer_changed_shell))
	lines.append("general_selected_count=%d" % general_selected_count)
	lines.append("general_apply_target_count=%d" % general_apply_target_count)
	lines.append("general_face_chamfer_changed_shell=%s" % str(general_face_chamfer_changed_shell))
	lines.append("general_face_chamfer_changed_patch_count=%d" % general_face_chamfer_changed_patch_count)
	lines.append("general_face_boundary_smaller_than_selection=%s" % str(general_apply_target_count < general_selected_count))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _build_front_heavy_sword_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = &"verify_stage2_selection_feature_front_heavy_sword"
	wip.forge_project_name = "Verify Stage2 Selection Feature Front Heavy Sword"
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

func _resolve_visible_face_selection_hit(
	preview: ForgeWorkspacePreview,
	active_wip: CraftedItemWIP,
	stage2_item_state,
	zone_mask_id: StringName,
	stage2_selection_presenter,
	tool_id: StringName
) -> Dictionary:
	if preview == null or active_wip == null or stage2_item_state == null:
		return {}
	var best_hit: Dictionary = {}
	var best_boundary_reduction: int = -1
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
		var selection_data: Dictionary = stage2_selection_presenter.resolve_hover_selection_data(stage2_item_state, hit_data, tool_id)
		var selected_patch_ids: PackedStringArray = PackedStringArray(selection_data.get("patch_ids", PackedStringArray()))
		if selected_patch_ids.is_empty():
			continue
		var apply_patch_ids: PackedStringArray = stage2_selection_presenter.resolve_selection_apply_patch_ids(
			stage2_item_state,
			selected_patch_ids,
			tool_id
		)
		if apply_patch_ids.is_empty():
			continue
		var boundary_reduction: int = selected_patch_ids.size() - apply_patch_ids.size()
		if boundary_reduction < best_boundary_reduction:
			continue
		if boundary_reduction == best_boundary_reduction and selected_patch_ids.size() <= best_selected_count:
			continue
		best_boundary_reduction = boundary_reduction
		best_selected_count = selected_patch_ids.size()
		best_hit = {
			"patch_state": patch_state,
			"screen_position": screen_position,
			"selected_patch_count": selected_patch_ids.size(),
			"apply_patch_count": apply_patch_ids.size(),
		}
	return best_hit

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
	return (
		patch_state.current_quad.origin_local
		+ (patch_state.current_quad.edge_u_local * 0.5)
		+ (patch_state.current_quad.edge_v_local * 0.5)
	)

func _popup_has_item_text(popup: PopupMenu, item_text: String) -> bool:
	if popup == null:
		return false
	for item_index: int in range(popup.get_item_count()):
		if popup.get_item_text(item_index) == item_text:
			return true
	return false
