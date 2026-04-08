extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const ForgeStage2SelectionPresenterScript = preload("res://runtime/forge/forge_stage2_selection_presenter.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const Stage2ItemStateScript = preload("res://core/models/stage2_item_state.gd")
const Stage2PatchStateScript = preload("res://core/models/stage2_patch_state.gd")
const Stage2ShellQuadStateScript = preload("res://core/models/stage2_shell_quad_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/stage2_feature_contour_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	forge_controller.load_player_saved_wip(_build_wide_plate_wip())
	forge_controller.ensure_stage2_item_state_for_active_wip()
	get_root().add_child(forge_controller)

	var player: PlayerController3D = PlayerScene.instantiate() as PlayerController3D
	get_root().add_child(player)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_for(player, forge_controller, "Stage2 Feature Contour Bench")
	await process_frame
	await process_frame

	crafting_ui.call("_toggle_stage2_refinement_mode")
	await process_frame
	await process_frame

	var menu_ids: Dictionary = crafting_ui.call("_get_action_menu_ids")
	var geometry_popup: PopupMenu = crafting_ui.geometry_menu_button.get_popup()
	var selection_presenter = ForgeStage2SelectionPresenterScript.new()
	var has_feature_contour_fillet_tool: bool = _popup_has_item_text(geometry_popup, "Feature Contour Fillet Tool")
	var has_feature_contour_chamfer_tool: bool = _popup_has_item_text(geometry_popup, "Feature Contour Chamfer Tool")
	var feature_contour_restore_hidden: bool = not _popup_has_item_text(geometry_popup, "Feature Contour Restore Tool")

	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_tool_surface_feature_contour_fillet", -1)))
	await process_frame
	await process_frame
	geometry_popup = crafting_ui.geometry_menu_button.get_popup()
	var feature_contour_tool_apply_visible: bool = _popup_has_item_text(geometry_popup, "Apply Selected Targets")
	var feature_contour_tool_clear_visible: bool = _popup_has_item_text(geometry_popup, "Clear Target Selection")

	var general_contour_state = _build_synthetic_bridge_state(Stage2PatchStateScript.ZONE_GENERAL)
	var general_bridge_selection: Dictionary = selection_presenter.resolve_hover_selection_data(
		general_contour_state,
		_build_synthetic_patch_hit_data(&"h_patch_0"),
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_BRIDGE_FILLET
	)
	var general_contour_selection: Dictionary = selection_presenter.resolve_hover_selection_data(
		general_contour_state,
		_build_synthetic_patch_hit_data(&"h_patch_0"),
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_FILLET
	)
	var general_bridge_patch_ids: PackedStringArray = PackedStringArray(general_bridge_selection.get("patch_ids", PackedStringArray()))
	var general_contour_patch_ids: PackedStringArray = PackedStringArray(general_contour_selection.get("patch_ids", PackedStringArray()))

	var contour_chamfer_apply_patch_ids: PackedStringArray = selection_presenter.resolve_selection_apply_patch_ids(
		general_contour_state,
		general_contour_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_CHAMFER
	)
	var origins_before_contour_chamfer: Array[Vector3] = _collect_patch_origins(general_contour_state)
	var feature_contour_chamfer_changed_shell: bool = crafting_ui.stage2_brush_presenter.apply_selection_tool(
		general_contour_state,
		general_contour_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_CHAMFER,
		contour_chamfer_apply_patch_ids
	) and _has_any_patch_origin_changed(origins_before_contour_chamfer, _collect_patch_origins(general_contour_state))

	var contour_restore_apply_patch_ids: PackedStringArray = selection_presenter.resolve_selection_apply_patch_ids(
		general_contour_state,
		general_contour_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_RESTORE
	)
	var origins_before_contour_restore: Array[Vector3] = _collect_patch_origins(general_contour_state)
	var feature_contour_restore_changed_shell: bool = crafting_ui.stage2_brush_presenter.apply_selection_tool(
		general_contour_state,
		general_contour_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_RESTORE,
		contour_restore_apply_patch_ids
	) and _has_any_patch_origin_changed(origins_before_contour_restore, _collect_patch_origins(general_contour_state))

	var grip_safe_contour_state = _build_synthetic_bridge_state(Stage2PatchStateScript.ZONE_PRIMARY_GRIP_SAFE)
	var grip_safe_contour_selection: Dictionary = selection_presenter.resolve_hover_selection_data(
		grip_safe_contour_state,
		_build_synthetic_patch_hit_data(&"h_patch_0"),
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_FILLET
	)
	var grip_safe_contour_patch_ids: PackedStringArray = PackedStringArray(grip_safe_contour_selection.get("patch_ids", PackedStringArray()))
	var grip_safe_contour_fillet_apply_patch_ids: PackedStringArray = selection_presenter.resolve_selection_apply_patch_ids(
		grip_safe_contour_state,
		grip_safe_contour_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_FILLET
	)
	var origins_before_grip_safe_contour_fillet: Array[Vector3] = _collect_patch_origins(grip_safe_contour_state)
	var grip_safe_feature_contour_fillet_changed_shell: bool = crafting_ui.stage2_brush_presenter.apply_selection_tool(
		grip_safe_contour_state,
		grip_safe_contour_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_FILLET,
		grip_safe_contour_fillet_apply_patch_ids
	) and _has_any_patch_origin_changed(origins_before_grip_safe_contour_fillet, _collect_patch_origins(grip_safe_contour_state))

	var grip_safe_contour_chamfer_apply_patch_ids: PackedStringArray = selection_presenter.resolve_selection_apply_patch_ids(
		grip_safe_contour_state,
		grip_safe_contour_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_CHAMFER
	)
	var origins_before_grip_safe_contour_chamfer: Array[Vector3] = _collect_patch_origins(grip_safe_contour_state)
	var grip_safe_feature_contour_chamfer_changed_shell: bool = crafting_ui.stage2_brush_presenter.apply_selection_tool(
		grip_safe_contour_state,
		grip_safe_contour_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CONTOUR_CHAMFER,
		grip_safe_contour_chamfer_apply_patch_ids
	) and _has_any_patch_origin_changed(origins_before_grip_safe_contour_chamfer, _collect_patch_origins(grip_safe_contour_state))

	var lines: PackedStringArray = []
	lines.append("stage2_geometry_menu_has_feature_contour_fillet=%s" % str(has_feature_contour_fillet_tool))
	lines.append("stage2_geometry_menu_has_feature_contour_chamfer=%s" % str(has_feature_contour_chamfer_tool))
	lines.append("stage2_geometry_menu_feature_contour_restore_hidden=%s" % str(feature_contour_restore_hidden))
	lines.append("feature_contour_tool_apply_visible=%s" % str(feature_contour_tool_apply_visible))
	lines.append("feature_contour_tool_clear_visible=%s" % str(feature_contour_tool_clear_visible))
	lines.append("synthetic_bridge_selected_count=%d" % general_bridge_patch_ids.size())
	lines.append("synthetic_contour_selected_count=%d" % general_contour_patch_ids.size())
	lines.append("synthetic_contour_non_empty=%s" % str(not general_contour_patch_ids.is_empty()))
	lines.append("synthetic_contour_smaller_than_bridge=%s" % str(general_contour_patch_ids.size() < general_bridge_patch_ids.size()))
	lines.append("feature_contour_chamfer_changed_shell=%s" % str(feature_contour_chamfer_changed_shell))
	lines.append("feature_contour_restore_changed_shell=%s" % str(feature_contour_restore_changed_shell))
	lines.append("grip_safe_feature_contour_fillet_changed_shell=%s" % str(grip_safe_feature_contour_fillet_changed_shell))
	lines.append("grip_safe_feature_contour_chamfer_changed_shell=%s" % str(grip_safe_feature_contour_chamfer_changed_shell))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _build_wide_plate_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = &"verify_stage2_feature_contour_wide_plate"
	wip.forge_project_name = "Verify Stage2 Feature Contour Wide Plate"
	wip.creator_id = &"verify"
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.forge_builder_path_id = CraftedItemWIP.BUILDER_PATH_MELEE

	var layer_map: Dictionary = {}
	for x: int in range(30, 66):
		for y: int in range(20, 28):
			for z: int in range(18, 21):
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

func _build_synthetic_bridge_state(zone_mask_id: StringName):
	var stage2_item_state = Stage2ItemStateScript.new()
	stage2_item_state.cell_world_size_meters = 0.05
	stage2_item_state.refinement_initialized = true
	for patch_index: int in range(6):
		stage2_item_state.patch_states.append(_build_horizontal_bridge_patch_state(patch_index, zone_mask_id))
	for patch_index: int in range(6):
		stage2_item_state.patch_states.append(_build_vertical_bridge_patch_state(patch_index, zone_mask_id))
	return stage2_item_state

func _build_horizontal_bridge_patch_state(patch_index: int, zone_mask_id: StringName):
	var patch_state = Stage2PatchStateScript.new()
	patch_state.patch_id = StringName("h_patch_%d" % patch_index)
	patch_state.zone_mask_id = zone_mask_id
	patch_state.neighbor_patch_ids = PackedStringArray()
	if patch_index > 0:
		patch_state.neighbor_patch_ids.append("h_patch_%d" % (patch_index - 1))
	if patch_index < 5:
		patch_state.neighbor_patch_ids.append("h_patch_%d" % (patch_index + 1))
	patch_state.baseline_quad = _build_bridge_quad(float(patch_index), Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.FORWARD)
	patch_state.current_quad = _build_bridge_quad(
		float(patch_index),
		Vector3(0.0, 0.0, -_resolve_bridge_offset_cells(patch_index)),
		Vector3.RIGHT,
		Vector3.UP,
		Vector3.FORWARD
	)
	patch_state.max_fillet_offset_meters = 0.05
	patch_state.max_chamfer_offset_meters = 0.05
	return patch_state

func _build_vertical_bridge_patch_state(patch_index: int, zone_mask_id: StringName):
	var patch_state = Stage2PatchStateScript.new()
	patch_state.patch_id = StringName("v_patch_%d" % patch_index)
	patch_state.zone_mask_id = zone_mask_id
	patch_state.neighbor_patch_ids = PackedStringArray()
	if patch_index > 0:
		patch_state.neighbor_patch_ids.append("v_patch_%d" % (patch_index - 1))
	if patch_index < 5:
		patch_state.neighbor_patch_ids.append("v_patch_%d" % (patch_index + 1))
	patch_state.baseline_quad = _build_bridge_quad(float(patch_index), Vector3(0.0, 1.0, 0.0), Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	patch_state.current_quad = _build_bridge_quad(
		float(patch_index),
		Vector3(0.0, 1.0 - _resolve_bridge_offset_cells(patch_index), 0.0),
		Vector3.RIGHT,
		Vector3.FORWARD,
		Vector3.UP
	)
	patch_state.max_fillet_offset_meters = 0.05
	patch_state.max_chamfer_offset_meters = 0.05
	return patch_state

func _build_bridge_quad(x_offset: float, origin_offset: Vector3, edge_u_local: Vector3, edge_v_local: Vector3, normal: Vector3):
	var quad = Stage2ShellQuadStateScript.new()
	quad.origin_local = Vector3(x_offset, 0.0, 0.0) + origin_offset
	quad.edge_u_local = edge_u_local
	quad.edge_v_local = edge_v_local
	quad.normal = normal
	quad.width_voxels = 1
	quad.height_voxels = 1
	return quad

func _resolve_bridge_offset_cells(patch_index: int) -> float:
	if patch_index <= 1:
		return 0.25
	if patch_index <= 3:
		return 0.5
	return 0.75

func _build_synthetic_patch_hit_data(patch_id: StringName) -> Dictionary:
	var patch_name: String = String(patch_id)
	var patch_index: int = patch_name.split("_")[-1].to_int()
	var is_vertical: bool = patch_name.begins_with("v_")
	var hit_point_local: Vector3 = Vector3(float(patch_index) + 0.5, 0.5, 0.0)
	if is_vertical:
		hit_point_local = Vector3(float(patch_index) + 0.5, 1.0, 0.5)
	return {
		"patch_id": patch_id,
		"hit_point_canonical_local": hit_point_local,
	}

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

func _popup_has_item_text(popup: PopupMenu, item_text: String) -> bool:
	if popup == null:
		return false
	for item_index: int in range(popup.item_count):
		if popup.get_item_text(item_index) == item_text:
			return true
	return false
