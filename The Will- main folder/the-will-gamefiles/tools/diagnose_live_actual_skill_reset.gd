extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/live_actual_skill_reset_results.txt"
const TARGET_SLOT_ID: StringName = &"skill_slot_1"

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	var lines: PackedStringArray = []
	lines.append("diagnostic=live_actual_skill_reset")
	lines.append("target_slot_id=%s" % String(TARGET_SLOT_ID))
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create() as PlayerForgeWipLibraryState
	var skill_slot_state: PlayerSkillSlotState = PlayerSkillSlotStateScript.load_or_create() as PlayerSkillSlotState
	lines.append("library_loaded=%s" % str(library_state != null))
	lines.append("skill_slot_state_loaded=%s" % str(skill_slot_state != null))
	if library_state == null:
		_write_results(lines)
		quit(2)
		return
	var target_wip_id: StringName = _resolve_target_wip_id(library_state, skill_slot_state)
	var target_wip: CraftedItemWIP = library_state.get_saved_wip(target_wip_id)
	lines.append("target_wip_id=%s" % String(target_wip_id))
	lines.append("target_wip_found=%s" % str(target_wip != null))
	if target_wip != null:
		lines.append("target_project_name=%s" % target_wip.forge_project_name)
		lines.append("target_selected_wip_before=%s" % String(library_state.selected_wip_id))
	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Live Actual Skill Reset Diagnostic")
	await _wait_frames(8)
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(target_wip_id, &"hand_right", false, false)
	await _wait_frames(8)
	var select_ok: bool = ui.select_skill_slot(TARGET_SLOT_ID, true)
	await _wait_frames(8)
	lines.append("open_ok=%s" % str(open_ok))
	lines.append("select_skill_ok=%s" % str(select_ok))
	lines.append_array(_build_active_draft_lines(ui, "before_reset"))
	lines.append_array(_build_runtime_cache_lines(ui, "before_reset"))
	_write_results(lines)

	var reset_signal_fired: bool = false
	if ui.reset_draft_button != null:
		ui.reset_draft_button.emit_signal("pressed")
		reset_signal_fired = true
	else:
		lines.append("reset_button_missing=true")
		lines.append("direct_reset_call_attempted=true")
		lines.append("direct_reset_ok=%s" % str(ui.reset_active_draft_to_baseline()))
	await _wait_frames(16)
	lines.append("reset_signal_fired=%s" % str(reset_signal_fired))
	lines.append_array(_build_active_draft_lines(ui, "after_reset"))
	lines.append_array(_build_runtime_cache_lines(ui, "after_reset"))
	var saved_wip_after: CraftedItemWIP = library_state.get_saved_wip(target_wip_id)
	lines.append("saved_wip_after_found=%s" % str(saved_wip_after != null))
	if saved_wip_after != null:
		lines.append("saved_wip_after_project_name=%s" % saved_wip_after.forge_project_name)
	_write_results(lines)
	quit(0)

func _resolve_target_wip_id(library_state: PlayerForgeWipLibraryState, skill_slot_state: PlayerSkillSlotState) -> StringName:
	if skill_slot_state != null:
		var assignment: Resource = skill_slot_state.get_slot_assignment(TARGET_SLOT_ID)
		if assignment != null:
			var assigned_wip_id: StringName = StringName(assignment.get("source_weapon_wip_id"))
			if assigned_wip_id != StringName():
				return assigned_wip_id
	if library_state != null and library_state.selected_wip_id != StringName():
		return library_state.selected_wip_id
	return StringName()

func _build_active_draft_lines(ui: CombatAnimationStationUI, prefix: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	if ui == null:
		lines.append("%s_ui_exists=false" % prefix)
		return lines
	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	lines.append("%s_ui_exists=true" % prefix)
	lines.append("%s_active_saved_wip_id=%s" % [prefix, String(ui.active_saved_wip_id)])
	lines.append("%s_active_draft_identifier=%s" % [prefix, String(ui.get_active_draft_identifier())])
	lines.append("%s_draft_exists=%s" % [prefix, str(draft != null)])
	if draft == null:
		return lines
	lines.append("%s_draft_id=%s" % [prefix, String(draft.draft_id)])
	lines.append("%s_owning_skill_id=%s" % [prefix, String(draft.owning_skill_id)])
	lines.append("%s_legal_slot_id=%s" % [prefix, String(draft.legal_slot_id)])
	lines.append("%s_node_count=%d" % [prefix, draft.motion_node_chain.size()])
	lines.append("%s_selected_node_index=%d" % [prefix, draft.selected_motion_node_index])
	if not draft.motion_node_chain.is_empty():
		var first_node: CombatAnimationMotionNode = draft.motion_node_chain[0] as CombatAnimationMotionNode
		if first_node != null:
			lines.append("%s_first_tip=%s" % [prefix, str(first_node.tip_position_local)])
			lines.append("%s_first_pommel=%s" % [prefix, str(first_node.pommel_position_local)])
			lines.append("%s_first_orientation=%s" % [prefix, str(first_node.weapon_orientation_degrees)])
			lines.append("%s_first_two_hand_state=%s" % [prefix, String(first_node.two_hand_state)])
			lines.append("%s_first_primary_hand=%s" % [prefix, String(first_node.primary_hand_slot)])
	return lines

func _build_runtime_cache_lines(ui: CombatAnimationStationUI, prefix: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	if ui == null:
		return lines
	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	if draft == null:
		return lines
	var runtime_clip = draft.baked_runtime_clip
	lines.append("%s_runtime_clip_exists=%s" % [prefix, str(runtime_clip != null)])
	if runtime_clip != null and runtime_clip.has_method("get_frame_count"):
		lines.append("%s_runtime_clip_frame_count=%d" % [prefix, int(runtime_clip.call("get_frame_count"))])
		lines.append("%s_runtime_clip_solved_replay=%s" % [prefix, str(runtime_clip.has_method("has_solved_replay_track") and bool(runtime_clip.call("has_solved_replay_track")))])
	return lines

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame

func _write_results(lines: PackedStringArray) -> void:
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(lines))
	file.close()
