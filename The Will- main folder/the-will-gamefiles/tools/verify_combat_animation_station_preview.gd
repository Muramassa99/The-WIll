extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const LayerAtomScript = preload("res://core/atoms/layer_atom.gd")
const CellAtomScript = preload("res://core/atoms/cell_atom.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_animation_station_preview_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/verify_combat_animation_station_preview_library.tres"
const WOOD_MATERIAL_ID := &"mat_wood_gray"

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library_state.save_file_path = TEMP_SAVE_FILE_PATH
	library_state.saved_wips.clear()
	library_state.selected_wip_id = StringName()

	var source_wip: CraftedItemWIP = _build_preview_test_wip()
	var saved_wip: CraftedItemWIP = library_state.save_wip(source_wip)

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	get_root().add_child(fake_player)

	var ui = CombatAnimationStationUIScene.instantiate()
	get_root().add_child(ui)
	await process_frame
	ui.open_for(fake_player, "PreviewVerifier")
	await process_frame
	ui.create_skill_draft(&"skill_preview_alpha", "Preview Alpha")
	await process_frame
	ui.set_selected_motion_node_tip_curve_out(Vector3(0.08, 0.02, -0.05))
	ui.insert_motion_node_after_selection()
	await process_frame
	ui.set_selected_motion_node_tip_curve_in(Vector3(-0.05, 0.04, 0.03))
	ui.set_selected_motion_node_two_hand_state(&"two_hand_two_hand")
	await process_frame
	await process_frame

	var debug_state: Dictionary = ui.get_preview_debug_state()
	var active_draft: Resource = ui.call("_get_active_draft") as Resource
	var ui_node_count: int = int((active_draft.get("motion_node_chain") as Array).size()) if active_draft != null else 0
	var lines: PackedStringArray = []
	lines.append("preview_actor_exists=%s" % str(bool(debug_state.get("has_preview_actor", false))))
	lines.append("preview_weapon_exists=%s" % str(bool(debug_state.get("has_preview_weapon", false))))
	lines.append("primary_grip_anchor_exists=%s" % str(bool(debug_state.get("has_primary_grip_anchor", false))))
	lines.append("ui_selected_motion_node_index=%d" % ui.get_selected_motion_node_index())
	lines.append("ui_motion_node_count=%d" % ui_node_count)
	lines.append("preview_draft_point_count=%d" % int(debug_state.get("draft_point_count", 0)))
	lines.append("curve_baked_point_count=%d" % int(debug_state.get("curve_baked_point_count", 0)))
	lines.append("point_marker_count=%d" % int(debug_state.get("point_marker_count", 0)))
	lines.append("control_handle_marker_count=%d" % int(debug_state.get("control_handle_marker_count", 0)))
	lines.append("selected_point_index=%d" % int(debug_state.get("selected_point_index", -1)))
	lines.append("marker_root_exists=%s" % str(bool(debug_state.get("marker_root_exists", false))))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _build_preview_test_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = &"combat_preview_test_wip"
	wip.forge_project_name = "Combat Preview Test WIP"
	CraftedItemWIPScript.apply_builder_path_defaults(
		wip,
		CraftedItemWIPScript.BUILDER_PATH_MELEE,
		CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	)
	var layer_map: Dictionary = {}
	for slice_index: int in range(26):
		for y in range(4, 6):
			for z in range(4, 7):
				_add_cell(layer_map, Vector3i(slice_index, y, z), WOOD_MATERIAL_ID)
	var ordered_layers: Array = layer_map.keys()
	ordered_layers.sort()
	for layer_index_value: Variant in ordered_layers:
		wip.layers.append(layer_map[layer_index_value])
	return wip

func _add_cell(layer_map: Dictionary, grid_position: Vector3i, material_variant_id: StringName) -> void:
	if not layer_map.has(grid_position.z):
		var layer: LayerAtom = LayerAtomScript.new()
		layer.layer_index = grid_position.z
		layer.cells = []
		layer_map[grid_position.z] = layer
	var cell: CellAtom = CellAtomScript.new()
	cell.grid_position = grid_position
	cell.layer_index = grid_position.z
	cell.material_variant_id = material_variant_id
	var target_layer: LayerAtom = layer_map[grid_position.z]
	target_layer.cells.append(cell)
