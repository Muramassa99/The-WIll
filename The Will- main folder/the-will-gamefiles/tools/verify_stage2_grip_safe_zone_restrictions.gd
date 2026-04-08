extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const ForgeStage2BrushPresenterScript = preload("res://runtime/forge/forge_stage2_brush_presenter.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const Stage2PatchStateScript = preload("res://core/models/stage2_patch_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/stage2_grip_safe_zone_results.txt"

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

	crafting_ui.open_for(player, forge_controller, "Stage2 Grip Safe Zone Bench")
	await process_frame
	await process_frame

	crafting_ui.call("_toggle_stage2_refinement_mode")
	await process_frame
	await process_frame
	crafting_ui.set("stage2_brush_radius_meters", forge_controller.get_cell_world_size_meters() * 0.35)

	var preview: ForgeWorkspacePreview = crafting_ui.free_workspace_preview
	var menu_ids: Dictionary = crafting_ui.call("_get_action_menu_ids")
	var geometry_popup: PopupMenu = crafting_ui.geometry_menu_button.get_popup()
	var baked_profile: BakedProfile = forge_controller.active_wip.latest_baked_profile_snapshot if forge_controller.active_wip != null else null
	var stage2_geometry_menu_has_fillet: bool = _popup_has_item_text(geometry_popup, "Fillet Tool")
	var stage2_geometry_menu_has_chamfer: bool = _popup_has_item_text(geometry_popup, "Chamfer Tool")
	var stage2_geometry_menu_has_pick: bool = _popup_has_item_text(geometry_popup, "Pick Material")
	var grip_safe_hit: Dictionary = _resolve_visible_patch_hit(
		preview,
		forge_controller.active_wip,
		stage2_item_state,
		Stage2PatchStateScript.ZONE_PRIMARY_GRIP_SAFE
	)
	var general_hit: Dictionary = _resolve_visible_patch_hit(
		preview,
		forge_controller.active_wip,
		stage2_item_state,
		Stage2PatchStateScript.ZONE_GENERAL
	)

	var grip_safe_screen_position: Vector2 = grip_safe_hit.get("screen_position", Vector2.ZERO)
	crafting_ui.call("_update_stage2_brush_hover", grip_safe_screen_position)
	await process_frame
	var grip_hover_blocked: bool = preview != null and bool(preview.stage2_brush_preview_blocked)
	var origins_before_safe_carve: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	crafting_ui.call("_apply_stage2_brush_at_screen_position", grip_safe_screen_position)
	await process_frame
	var grip_safe_carve_changed_shell: bool = _has_any_patch_origin_changed(
		origins_before_safe_carve,
		_collect_patch_origins(stage2_item_state)
	)

	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_tool_fillet", -1)))
	await process_frame
	crafting_ui.call("_update_stage2_brush_hover", grip_safe_screen_position)
	await process_frame
	var grip_hover_blocked_for_fillet: bool = preview != null and bool(preview.stage2_brush_preview_blocked)
	var origins_before_safe_fillet: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	crafting_ui.call("_apply_stage2_brush_at_screen_position", grip_safe_screen_position)
	await process_frame
	var grip_safe_fillet_changed_shell: bool = _has_any_patch_origin_changed(
		origins_before_safe_fillet,
		_collect_patch_origins(stage2_item_state)
	)

	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_tool_chamfer", -1)))
	await process_frame
	crafting_ui.call("_update_stage2_brush_hover", grip_safe_screen_position)
	await process_frame
	var grip_hover_blocked_for_chamfer: bool = preview != null and bool(preview.stage2_brush_preview_blocked)
	var origins_before_safe_chamfer: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	crafting_ui.call("_apply_stage2_brush_at_screen_position", grip_safe_screen_position)
	await process_frame
	var grip_safe_chamfer_changed_shell: bool = _has_any_patch_origin_changed(
		origins_before_safe_chamfer,
		_collect_patch_origins(stage2_item_state)
	)

	var general_screen_position: Vector2 = general_hit.get("screen_position", Vector2.ZERO)
	crafting_ui.call("_update_stage2_brush_hover", general_screen_position)
	await process_frame
	var general_hover_blocked: bool = preview != null and bool(preview.stage2_brush_preview_blocked)
	var origins_before_general_carve: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	var general_patch = general_hit.get("patch_state", null)
	var brush_presenter = ForgeStage2BrushPresenterScript.new()
	var general_patch_center: Vector3 = _resolve_patch_center_local(general_patch)
	brush_presenter.apply_brush(
		stage2_item_state,
		ForgeStage2BrushPresenterScript.TOOL_STAGE2_CARVE,
		general_patch_center,
		float(crafting_ui.get("stage2_brush_radius_meters")),
		float(crafting_ui.get("stage2_brush_radius_meters")) * 0.25
	)
	var general_carve_changed_shell: bool = _has_any_patch_origin_changed(
		origins_before_general_carve,
		_collect_patch_origins(stage2_item_state)
	)
	var origins_before_general_chamfer: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	brush_presenter.apply_brush(
		stage2_item_state,
		ForgeStage2BrushPresenterScript.TOOL_STAGE2_CHAMFER,
		general_patch_center,
		float(crafting_ui.get("stage2_brush_radius_meters")),
		float(crafting_ui.get("stage2_brush_radius_meters")) * 0.25
	)
	var general_chamfer_changed_shell: bool = _has_any_patch_origin_changed(
		origins_before_general_chamfer,
		_collect_patch_origins(stage2_item_state)
	)

	var lines: PackedStringArray = []
	lines.append("profile_primary_grip_valid=%s" % str(baked_profile != null and baked_profile.primary_grip_valid))
	lines.append("stage2_geometry_menu_has_fillet=%s" % str(stage2_geometry_menu_has_fillet))
	lines.append("stage2_geometry_menu_has_chamfer=%s" % str(stage2_geometry_menu_has_chamfer))
	lines.append("stage2_geometry_menu_has_pick=%s" % str(stage2_geometry_menu_has_pick))
	lines.append("grip_safe_patch_count=%d" % _count_zone_patches(stage2_item_state, Stage2PatchStateScript.ZONE_PRIMARY_GRIP_SAFE))
	lines.append("grip_safe_patch_count_positive=%s" % str(_count_zone_patches(stage2_item_state, Stage2PatchStateScript.ZONE_PRIMARY_GRIP_SAFE) > 0))
	lines.append("grip_hover_blocked=%s" % str(grip_hover_blocked))
	lines.append("grip_safe_carve_changed_shell=%s" % str(grip_safe_carve_changed_shell))
	lines.append("grip_hover_blocked_for_fillet=%s" % str(grip_hover_blocked_for_fillet))
	lines.append("grip_safe_fillet_changed_shell=%s" % str(grip_safe_fillet_changed_shell))
	lines.append("grip_hover_blocked_for_chamfer=%s" % str(grip_hover_blocked_for_chamfer))
	lines.append("grip_safe_chamfer_changed_shell=%s" % str(grip_safe_chamfer_changed_shell))
	lines.append("general_hover_blocked=%s" % str(general_hover_blocked))
	lines.append("general_carve_changed_shell=%s" % str(general_carve_changed_shell))
	lines.append("general_chamfer_changed_shell=%s" % str(general_chamfer_changed_shell))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _build_front_heavy_sword_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = &"verify_stage2_grip_safe_zone_front_heavy_sword"
	wip.forge_project_name = "Verify Stage2 Grip Safe Zone Front Heavy Sword"
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

func _count_zone_patches(stage2_item_state, zone_mask_id: StringName) -> int:
	if stage2_item_state == null:
		return 0
	var count: int = 0
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null:
			continue
		if patch_state.zone_mask_id == zone_mask_id:
			count += 1
	return count

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

func _resolve_visible_patch_hit(
	preview: ForgeWorkspacePreview,
	active_wip: CraftedItemWIP,
	stage2_item_state,
	zone_mask_id: StringName
) -> Dictionary:
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
		return {
			"patch_state": patch_state,
			"screen_position": screen_position,
		}
	return {}

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
