extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_speed_state_feedback_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/verify_combat_speed_state_feedback_library.tres"

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

	var source_wip: CraftedItemWIP = _build_speed_state_test_wip()
	var saved_wip: CraftedItemWIP = library_state.save_wip(source_wip)

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	get_root().add_child(fake_player)

	var ui = CombatAnimationStationUIScene.instantiate()
	get_root().add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Speed State Verifier")
	await process_frame

	var open_ok: bool = ui.open_saved_wip_with_hand_setup(saved_wip.wip_id if saved_wip != null else StringName(), &"hand_right", false, false)
	await process_frame
	var select_slot_ok: bool = ui.select_skill_slot(&"skill_slot_1", true)
	await process_frame
	var append_visible_node_ok: bool = _append_fast_visible_node(ui)
	await process_frame
	var acceleration_set_ok: bool = ui.set_active_draft_speed_acceleration_percent(15.0)
	await process_frame
	var deceleration_set_ok: bool = ui.set_active_draft_speed_deceleration_percent(25.0)
	await process_frame

	var debug_state: Dictionary = ui.get_preview_debug_state()
	var active_draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	var saved_library_wip: CraftedItemWIP = library_state.get_saved_wip(saved_wip.wip_id if saved_wip != null else StringName())
	var saved_draft: CombatAnimationDraft = null
	if saved_library_wip != null and saved_library_wip.combat_animation_station_state != null:
		saved_draft = _find_skill_draft(saved_library_wip.combat_animation_station_state.skill_drafts, &"skill_slot_1")

	var lines: PackedStringArray = []
	lines.append("open_ok=%s" % str(open_ok))
	lines.append("select_slot_ok=%s" % str(select_slot_ok))
	lines.append("append_visible_node_ok=%s" % str(append_visible_node_ok))
	lines.append("acceleration_set_ok=%s" % str(acceleration_set_ok))
	lines.append("deceleration_set_ok=%s" % str(deceleration_set_ok))
	lines.append("active_draft_acceleration_percent=%.1f" % float(active_draft.speed_acceleration_percent if active_draft != null else -1.0))
	lines.append("active_draft_deceleration_percent=%.1f" % float(active_draft.speed_deceleration_percent if active_draft != null else -1.0))
	lines.append("saved_draft_acceleration_percent=%.1f" % float(saved_draft.speed_acceleration_percent if saved_draft != null else -1.0))
	lines.append("saved_draft_deceleration_percent=%.1f" % float(saved_draft.speed_deceleration_percent if saved_draft != null else -1.0))
	lines.append("speed_state_sample_count=%d" % int(debug_state.get("speed_state_sample_count", 0)))
	lines.append("speed_state_armed_sample_count=%d" % int(debug_state.get("speed_state_armed_sample_count", 0)))
	lines.append("speed_state_reset_sample_count=%d" % int(debug_state.get("speed_state_reset_sample_count", 0)))
	lines.append("speed_state_has_armed=%s" % str(int(debug_state.get("speed_state_armed_sample_count", 0)) > 0))
	lines.append("speed_state_has_reset=%s" % str(int(debug_state.get("speed_state_reset_sample_count", 0)) > 0))
	lines.append("speed_state_debug_acceleration_percent=%.1f" % float(debug_state.get("speed_state_acceleration_percent", 0.0)))
	lines.append("speed_state_debug_deceleration_percent=%.1f" % float(debug_state.get("speed_state_deceleration_percent", 0.0)))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _append_fast_visible_node(ui) -> bool:
	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	if draft == null or draft.motion_node_chain.size() < 2:
		return false
	var source_node: CombatAnimationMotionNode = draft.motion_node_chain[draft.motion_node_chain.size() - 1] as CombatAnimationMotionNode
	if source_node == null:
		return false
	var node: CombatAnimationMotionNode = source_node.duplicate_node()
	node.node_index = draft.motion_node_chain.size()
	node.node_id = StringName("motion_node_%02d" % node.node_index)
	node.tip_position_local = source_node.tip_position_local + Vector3(0.82, 0.18, -0.34)
	node.pommel_position_local = source_node.pommel_position_local + Vector3(0.78, 0.08, -0.28)
	node.transition_duration_seconds = 0.06
	node.tip_curve_in_handle = Vector3(-0.18, 0.08, 0.04)
	node.pommel_curve_in_handle = Vector3(-0.12, 0.03, 0.03)
	node.normalize()
	draft.motion_node_chain.append(node)
	draft.selected_motion_node_index = node.node_index
	draft.normalize()
	ui.call("_persist_active_wip", "Speed state verifier appended node.")
	ui.call("_refresh_all", "Speed state verifier appended node.")
	return true

func _build_speed_state_test_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.forge_project_name = "Speed State Feedback Test"
	CraftedItemWIPScript.apply_builder_path_defaults(
		wip,
		CraftedItemWIPScript.BUILDER_PATH_MELEE,
		CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	)
	wip.layers = [_build_layer(20), _build_layer(21)]
	var station_state: CombatAnimationStationState = wip.ensure_combat_animation_station_state() as CombatAnimationStationState
	if station_state == null:
		return wip
	var draft: CombatAnimationDraft = station_state.get_or_create_skill_draft(
		&"skill_slot_1",
		"Speed State Skill",
		wip.grip_style_mode,
		&"skill_slot_1"
	) as CombatAnimationDraft
	if draft == null:
		return wip
	draft.skill_name = "Speed State Skill"
	draft.ensure_minimum_baseline_nodes()
	var node_0: CombatAnimationMotionNode = draft.motion_node_chain[0] as CombatAnimationMotionNode
	var node_1: CombatAnimationMotionNode = draft.motion_node_chain[1] as CombatAnimationMotionNode
	var node_2: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new() as CombatAnimationMotionNode
	if node_0 != null:
		_apply_motion_node(node_0, Vector3(0.0, 0.08, -0.35), Vector3(0.0, -0.05, 0.18), 0.01)
	if node_1 != null:
		_apply_motion_node(node_1, Vector3(0.14, 0.12, -0.42), Vector3(0.02, -0.03, 0.10), 0.28)
		node_1.tip_curve_in_handle = Vector3(0.0, 0.08, 0.06)
		node_1.tip_curve_out_handle = Vector3(0.18, 0.02, -0.12)
	node_2.node_index = 2
	node_2.node_id = &"motion_node_02"
	_apply_motion_node(node_2, Vector3(1.05, 0.2, -0.7), Vector3(0.82, -0.02, -0.18), 0.06)
	node_2.tip_curve_in_handle = Vector3(-0.16, 0.1, 0.08)
	node_2.pommel_curve_in_handle = Vector3(-0.12, 0.04, 0.04)
	draft.motion_node_chain.append(node_2)
	draft.normalize()
	return wip

func _apply_motion_node(node: CombatAnimationMotionNode, tip: Vector3, pommel: Vector3, duration: float) -> void:
	node.tip_position_local = tip
	node.pommel_position_local = pommel
	node.transition_duration_seconds = duration
	node.weapon_orientation_authored = true
	node.preferred_grip_style_mode = &"grip_normal"
	node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
	node.normalize()

func _build_layer(layer_index: int) -> LayerAtom:
	var layer: LayerAtom = LayerAtom.new()
	layer.layer_index = layer_index
	layer.cells = []
	for x in range(20, 48):
		for y in range(10, 13):
			var cell: CellAtom = CellAtom.new()
			cell.grid_position = Vector3i(x, y, layer_index)
			cell.layer_index = layer_index
			cell.material_variant_id = &"mat_wood_gray"
			layer.cells.append(cell)
	return layer

func _find_skill_draft(skill_drafts: Array, skill_id: StringName) -> CombatAnimationDraft:
	for draft_variant: Variant in skill_drafts:
		var draft: CombatAnimationDraft = draft_variant as CombatAnimationDraft
		if draft != null and StringName(draft.owning_skill_id) == skill_id:
			return draft
	return null
