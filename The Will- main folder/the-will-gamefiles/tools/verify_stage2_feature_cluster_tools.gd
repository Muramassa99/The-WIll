extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const ForgeStage2SelectionPresenterScript = preload("res://runtime/forge/forge_stage2_selection_presenter.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const Stage2ItemStateScript = preload("res://core/models/stage2_item_state.gd")
const Stage2PatchStateScript = preload("res://core/models/stage2_patch_state.gd")
const Stage2ShellQuadStateScript = preload("res://core/models/stage2_shell_quad_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/stage2_feature_cluster_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	forge_controller.load_player_saved_wip(_build_wide_plate_wip())
	var stage2_item_state = forge_controller.ensure_stage2_item_state_for_active_wip()
	get_root().add_child(forge_controller)

	var face_reference_patch = _find_largest_general_face_reference_patch(stage2_item_state)
	var face_patch_ids: PackedStringArray = _collect_face_patch_ids(stage2_item_state, face_reference_patch)
	var face_stripes: Array[PackedStringArray] = _build_face_stripes(stage2_item_state, face_patch_ids)
	if face_stripes.size() >= 1:
		_set_patch_group_offset(stage2_item_state, face_stripes[0], -0.25)
	if face_stripes.size() >= 2:
		_set_patch_group_offset(stage2_item_state, face_stripes[1], -0.5)
	if face_stripes.size() >= 3:
		_set_patch_group_offset(stage2_item_state, face_stripes[2], -0.75)
	stage2_item_state.refresh_current_local_aabb_from_patches()

	var selection_anchor_patch = _find_patch_by_id(
		stage2_item_state,
		StringName(face_stripes[0][0]) if not face_stripes.is_empty() and not face_stripes[0].is_empty() else StringName()
	)

	var player: PlayerController3D = PlayerScene.instantiate() as PlayerController3D
	get_root().add_child(player)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_for(player, forge_controller, "Stage2 Feature Cluster Bench")
	await process_frame
	await process_frame

	crafting_ui.call("_toggle_stage2_refinement_mode")
	await process_frame
	await process_frame

	var menu_ids: Dictionary = crafting_ui.call("_get_action_menu_ids")
	var geometry_popup: PopupMenu = crafting_ui.geometry_menu_button.get_popup()
	var selection_presenter = ForgeStage2SelectionPresenterScript.new()
	var has_feature_cluster_fillet_tool: bool = _popup_has_item_text(geometry_popup, "Feature Cluster Fillet Tool")
	var has_feature_cluster_chamfer_tool: bool = _popup_has_item_text(geometry_popup, "Feature Cluster Chamfer Tool")
	var feature_cluster_restore_hidden: bool = not _popup_has_item_text(geometry_popup, "Feature Cluster Restore Tool")

	var synthetic_stage2_item_state = _build_synthetic_feature_cluster_state()
	var synthetic_band_selection: Dictionary = selection_presenter.resolve_hover_selection_data(
		synthetic_stage2_item_state,
		_build_synthetic_patch_hit_data(&"patch_0"),
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_BAND_FILLET
	)
	var synthetic_cluster_selection: Dictionary = selection_presenter.resolve_hover_selection_data(
		synthetic_stage2_item_state,
		_build_synthetic_patch_hit_data(&"patch_0"),
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_FILLET
	)
	var synthetic_band_patch_ids: PackedStringArray = PackedStringArray(synthetic_band_selection.get("patch_ids", PackedStringArray()))
	var synthetic_cluster_patch_ids: PackedStringArray = PackedStringArray(synthetic_cluster_selection.get("patch_ids", PackedStringArray()))

	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_tool_surface_feature_cluster_fillet", -1)))
	await process_frame
	await process_frame
	geometry_popup = crafting_ui.geometry_menu_button.get_popup()
	var feature_cluster_tool_apply_visible: bool = _popup_has_item_text(geometry_popup, "Apply Selected Targets")
	var feature_cluster_tool_clear_visible: bool = _popup_has_item_text(geometry_popup, "Clear Target Selection")

	var band_selection: Dictionary = selection_presenter.resolve_hover_selection_data(
		stage2_item_state,
		_build_patch_hit_data(selection_anchor_patch),
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_BAND_FILLET
	)
	var cluster_selection: Dictionary = selection_presenter.resolve_hover_selection_data(
		stage2_item_state,
		_build_patch_hit_data(selection_anchor_patch),
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_FILLET
	)
	var band_patch_ids: PackedStringArray = PackedStringArray(band_selection.get("patch_ids", PackedStringArray()))
	var cluster_patch_ids: PackedStringArray = PackedStringArray(cluster_selection.get("patch_ids", PackedStringArray()))

	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_tool_surface_feature_cluster_chamfer", -1)))
	await process_frame
	await process_frame
	var cluster_chamfer_apply_patch_ids: PackedStringArray = selection_presenter.resolve_selection_apply_patch_ids(
		stage2_item_state,
		cluster_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_CHAMFER
	)
	var origins_before_cluster_chamfer: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	var feature_cluster_chamfer_changed_shell: bool = crafting_ui.stage2_brush_presenter.apply_selection_tool(
		stage2_item_state,
		cluster_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_CHAMFER,
		cluster_chamfer_apply_patch_ids
	) and _has_any_patch_origin_changed(origins_before_cluster_chamfer, _collect_patch_origins(stage2_item_state))

	crafting_ui.call("_on_action_menu_id_pressed", int(menu_ids.get("geometry_tool_surface_feature_cluster_restore", -1)))
	await process_frame
	await process_frame
	var cluster_restore_patch_ids: PackedStringArray = PackedStringArray(selection_presenter.resolve_hover_selection_data(
		stage2_item_state,
		_build_patch_hit_data(selection_anchor_patch),
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_RESTORE
	).get("patch_ids", PackedStringArray()))
	var cluster_restore_apply_patch_ids: PackedStringArray = selection_presenter.resolve_selection_apply_patch_ids(
		stage2_item_state,
		cluster_restore_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_RESTORE
	)
	var origins_before_cluster_restore: Array[Vector3] = _collect_patch_origins(stage2_item_state)
	var feature_cluster_restore_changed_shell: bool = crafting_ui.stage2_brush_presenter.apply_selection_tool(
		stage2_item_state,
		cluster_restore_patch_ids,
		ForgeStage2SelectionPresenterScript.TOOL_STAGE2_SURFACE_FEATURE_CLUSTER_RESTORE,
		cluster_restore_apply_patch_ids
	) and _has_any_patch_origin_changed(origins_before_cluster_restore, _collect_patch_origins(stage2_item_state))

	var lines: PackedStringArray = []
	lines.append("stage2_geometry_menu_has_feature_cluster_fillet=%s" % str(has_feature_cluster_fillet_tool))
	lines.append("stage2_geometry_menu_has_feature_cluster_chamfer=%s" % str(has_feature_cluster_chamfer_tool))
	lines.append("stage2_geometry_menu_feature_cluster_restore_hidden=%s" % str(feature_cluster_restore_hidden))
	lines.append("feature_cluster_tool_apply_visible=%s" % str(feature_cluster_tool_apply_visible))
	lines.append("feature_cluster_tool_clear_visible=%s" % str(feature_cluster_tool_clear_visible))
	lines.append("synthetic_band_selected_count=%d" % synthetic_band_patch_ids.size())
	lines.append("synthetic_cluster_selected_count=%d" % synthetic_cluster_patch_ids.size())
	lines.append("synthetic_cluster_larger_than_band=%s" % str(synthetic_cluster_patch_ids.size() > synthetic_band_patch_ids.size()))
	lines.append("band_selected_count=%d" % band_patch_ids.size())
	lines.append("cluster_selected_count=%d" % cluster_patch_ids.size())
	lines.append("feature_cluster_chamfer_changed_shell=%s" % str(feature_cluster_chamfer_changed_shell))
	lines.append("feature_cluster_restore_changed_shell=%s" % str(feature_cluster_restore_changed_shell))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _build_wide_plate_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = &"verify_stage2_feature_cluster_wide_plate"
	wip.forge_project_name = "Verify Stage2 Feature Cluster Wide Plate"
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

func _find_largest_general_face_reference_patch(stage2_item_state):
	if stage2_item_state == null:
		return null
	var best_patch = null
	var best_face_count: int = -1
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null or patch_state.current_quad == null:
			continue
		if patch_state.zone_mask_id != Stage2PatchStateScript.ZONE_GENERAL:
			continue
		var face_count: int = _collect_face_patch_ids(stage2_item_state, patch_state).size()
		if face_count > best_face_count:
			best_face_count = face_count
			best_patch = patch_state
	return best_patch

func _collect_face_patch_ids(stage2_item_state, anchor_patch) -> PackedStringArray:
	var patch_ids: PackedStringArray = PackedStringArray()
	if stage2_item_state == null or anchor_patch == null or anchor_patch.current_quad == null:
		return patch_ids
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null or patch_state.current_quad == null:
			continue
		if patch_state.zone_mask_id != anchor_patch.zone_mask_id:
			continue
		if _shares_plane_and_normal(anchor_patch.current_quad, patch_state.current_quad):
			patch_ids.append(String(patch_state.patch_id))
	return patch_ids

func _build_face_stripes(stage2_item_state, face_patch_ids: PackedStringArray) -> Array[PackedStringArray]:
	var stripes: Array[PackedStringArray] = []
	if stage2_item_state == null or face_patch_ids.size() < 3:
		return stripes
	var patch_lookup: Dictionary = _build_patch_lookup(stage2_item_state)
	var records: Array[Dictionary] = []
	var first_patch = patch_lookup.get(StringName(face_patch_ids[0]), null)
	if first_patch == null or first_patch.current_quad == null:
		return stripes
	var sort_direction: Vector3 = first_patch.current_quad.edge_u_local.normalized()
	if sort_direction == Vector3.ZERO:
		sort_direction = Vector3.RIGHT
	for patch_id: String in face_patch_ids:
		var patch_state = patch_lookup.get(StringName(patch_id), null)
		if patch_state == null or patch_state.current_quad == null:
			continue
		var center: Vector3 = _resolve_patch_center_local(patch_state)
		records.append({
			"patch_id": patch_id,
			"sort_value": center.dot(sort_direction),
		})
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("sort_value", 0.0)) < float(b.get("sort_value", 0.0))
	)
	var stripe_count: int = 3
	var start_index: int = 0
	for stripe_index: int in range(stripe_count):
		var remaining_records: int = records.size() - start_index
		var remaining_stripes: int = stripe_count - stripe_index
		var stripe_size: int = maxi(1, int(floor(float(remaining_records) / float(remaining_stripes))))
		var stripe_patch_ids: PackedStringArray = PackedStringArray()
		for record_index: int in range(start_index, mini(start_index + stripe_size, records.size())):
			stripe_patch_ids.append(String(records[record_index].get("patch_id", "")))
		if not stripe_patch_ids.is_empty():
			stripes.append(stripe_patch_ids)
		start_index += stripe_size
	return stripes

func _set_patch_group_offset(stage2_item_state, patch_ids: PackedStringArray, offset_cells: float) -> void:
	var patch_lookup: Dictionary = _build_patch_lookup(stage2_item_state)
	for patch_id: String in patch_ids:
		var patch_state = patch_lookup.get(StringName(patch_id), null)
		if patch_state == null or patch_state.baseline_quad == null or patch_state.current_quad == null:
			continue
		var normal: Vector3 = patch_state.current_quad.normal.normalized()
		patch_state.current_quad.origin_local = patch_state.baseline_quad.origin_local - (normal * offset_cells)
		patch_state.dirty = true

func _build_patch_lookup(stage2_item_state) -> Dictionary:
	var patch_lookup: Dictionary = {}
	if stage2_item_state == null:
		return patch_lookup
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null:
			continue
		patch_lookup[patch_state.patch_id] = patch_state
	return patch_lookup

func _find_patch_by_id(stage2_item_state, patch_id: StringName):
	if stage2_item_state == null or patch_id == StringName():
		return null
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null:
			continue
		if patch_state.patch_id == patch_id:
			return patch_state
	return null

func _shares_plane_and_normal(quad_a, quad_b) -> bool:
	if quad_a == null or quad_b == null:
		return false
	var normal_a: Vector3 = quad_a.normal.normalized()
	var normal_b: Vector3 = quad_b.normal.normalized()
	if not normal_a.is_equal_approx(normal_b):
		return false
	return is_equal_approx(normal_a.dot(quad_a.origin_local), normal_b.dot(quad_b.origin_local))

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

func _popup_has_item_text(popup: PopupMenu, item_text: String) -> bool:
	if popup == null:
		return false
	for item_index: int in range(popup.item_count):
		if popup.get_item_text(item_index) == item_text:
			return true
	return false

func _build_synthetic_feature_cluster_state():
	var stage2_item_state = Stage2ItemStateScript.new()
	stage2_item_state.cell_world_size_meters = 0.05
	stage2_item_state.refinement_initialized = true
	for patch_index: int in range(6):
		var patch_state = Stage2PatchStateScript.new()
		patch_state.patch_id = StringName("patch_%d" % patch_index)
		patch_state.zone_mask_id = Stage2PatchStateScript.ZONE_GENERAL
		patch_state.neighbor_patch_ids = PackedStringArray()
		if patch_index > 0:
			patch_state.neighbor_patch_ids.append("patch_%d" % (patch_index - 1))
		if patch_index < 5:
			patch_state.neighbor_patch_ids.append("patch_%d" % (patch_index + 1))
		patch_state.baseline_quad = _build_synthetic_quad(float(patch_index), 0.0)
		var offset_cells: float = 0.25
		if patch_index >= 2 and patch_index <= 3:
			offset_cells = 0.5
		elif patch_index >= 4:
			offset_cells = 0.75
		patch_state.current_quad = _build_synthetic_quad(float(patch_index), offset_cells)
		stage2_item_state.patch_states.append(patch_state)
	return stage2_item_state

func _build_synthetic_quad(x_offset: float, offset_cells: float):
	var quad = Stage2ShellQuadStateScript.new()
	quad.origin_local = Vector3(x_offset, 0.0, -offset_cells)
	quad.edge_u_local = Vector3(1.0, 0.0, 0.0)
	quad.edge_v_local = Vector3(0.0, 1.0, 0.0)
	quad.normal = Vector3.FORWARD
	quad.width_voxels = 1
	quad.height_voxels = 1
	return quad

func _build_synthetic_patch_hit_data(patch_id: StringName) -> Dictionary:
	return {
		"patch_id": patch_id,
		"hit_point_canonical_local": Vector3(float(String(patch_id).trim_prefix("patch_").to_int()) + 0.5, 0.5, 0.0),
	}
