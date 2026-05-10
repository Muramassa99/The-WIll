extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/skill_editor_action_latency_2026-05-10.log"
const TARGET_SLOT_ID: StringName = &"skill_slot_1"

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

var lines: PackedStringArray = []

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	lines.append("diagnostic=skill_editor_action_latency")
	lines.append("target_slot_id=%s" % String(TARGET_SLOT_ID))
	lines.append("user_dir=%s" % ProjectSettings.globalize_path("user://"))
	DirAccess.make_dir_recursive_absolute(RESULT_FILE_PATH.get_base_dir())

	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create() as PlayerForgeWipLibraryState
	var skill_slot_state: PlayerSkillSlotState = PlayerSkillSlotStateScript.load_or_create() as PlayerSkillSlotState
	lines.append("library_loaded=%s" % str(library_state != null))
	lines.append("skill_slot_state_loaded=%s" % str(skill_slot_state != null))
	if library_state == null:
		_write_results()
		quit(2)
		return
	lines.append("library_save_file_path=%s" % String(library_state.save_file_path))
	lines.append("library_file_bytes_before=%d" % _get_file_length(ProjectSettings.globalize_path(library_state.save_file_path)))
	lines.append("saved_wip_count=%d" % library_state.get_saved_wips().size())

	var target_wip_id: StringName = _resolve_target_wip_id(library_state, skill_slot_state)
	var target_wip: CraftedItemWIP = library_state.get_saved_wip(target_wip_id)
	lines.append("target_wip_id=%s" % String(target_wip_id))
	lines.append("target_wip_found=%s" % str(target_wip != null))
	if target_wip == null:
		_write_results()
		quit(3)
		return
	lines.append("target_project_name=%s" % target_wip.forge_project_name)

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	ui.set_meta("trace_open_latency", true)
	ui.preview_presenter.set_meta("trace_preview_latency", true)
	root.add_child(ui)
	await process_frame

	var start_usec: int = Time.get_ticks_usec()
	ui.open_for(fake_player, "Skill Editor Latency Diagnostic")
	_append_elapsed("open_for_call", start_usec)
	await _wait_frames(4)

	start_usec = Time.get_ticks_usec()
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(target_wip_id, &"hand_right", false, false)
	_append_elapsed("open_saved_wip_with_hand_setup_call", start_usec)
	lines.append_array(_build_meta_trace_lines(ui, "open_trace", "last_open_latency_trace"))
	await _wait_frames(4)

	start_usec = Time.get_ticks_usec()
	var select_ok: bool = ui.select_skill_slot(TARGET_SLOT_ID, true)
	_append_elapsed("select_skill_slot_call", start_usec)
	await _wait_frames(4)

	lines.append("open_ok=%s" % str(open_ok))
	lines.append("select_skill_ok=%s" % str(select_ok))
	lines.append_array(_build_active_draft_lines(ui, "active"))
	lines.append_array(_build_runtime_cache_draft_lines(ui))
	_write_results()

	start_usec = Time.get_ticks_usec()
	ui.call("_refresh_motion_node_list")
	_append_elapsed("refresh_motion_node_list_only_call", start_usec)

	start_usec = Time.get_ticks_usec()
	ui.call("_refresh_editor_fields")
	_append_elapsed("refresh_editor_fields_only_call", start_usec)

	start_usec = Time.get_ticks_usec()
	ui.call("_sync_preview_pose_only")
	_append_elapsed("sync_preview_pose_only_call", start_usec)
	lines.append_array(_build_meta_trace_lines(ui.preview_presenter, "sync_preview_trace", "last_sync_preview_pose_latency_trace"))

	start_usec = Time.get_ticks_usec()
	ui.call("_refresh_preview_scene")
	_append_elapsed("refresh_preview_scene_only_call", start_usec)
	_write_results()

	start_usec = Time.get_ticks_usec()
	ui.call("_navigate_motion_node", -1)
	_append_elapsed("key_Q_prev_motion_node_call", start_usec)
	lines.append_array(_build_active_draft_lines(ui, "after_Q_prev"))
	await _wait_frames(2)

	start_usec = Time.get_ticks_usec()
	ui.call("_navigate_motion_node", 1)
	_append_elapsed("key_E_next_motion_node_call", start_usec)
	lines.append_array(_build_active_draft_lines(ui, "after_E_next"))
	_write_results()

	start_usec = Time.get_ticks_usec()
	ui.call("_refresh_all", "Latency probe refresh.")
	_append_elapsed("refresh_all_call", start_usec)
	await _wait_frames(2)
	_write_results()

	start_usec = Time.get_ticks_usec()
	var insert_ok: bool = ui.insert_motion_node_after_selection()
	_append_elapsed("key_R_insert_motion_node_call", start_usec)
	lines.append("key_R_insert_ok=%s" % str(insert_ok))
	lines.append("key_R_editor_dirty=%s" % str(bool(ui.get("editor_state_dirty"))))
	lines.append_array(_build_active_draft_lines(ui, "after_R_insert"))
	_write_results()
	await _wait_frames(2)

	start_usec = Time.get_ticks_usec()
	var delete_ok: bool = ui.remove_selected_motion_node()
	_append_elapsed("key_T_delete_motion_node_call", start_usec)
	lines.append("key_T_delete_ok=%s" % str(delete_ok))
	lines.append("key_T_editor_dirty=%s" % str(bool(ui.get("editor_state_dirty"))))
	lines.append_array(_build_active_draft_lines(ui, "after_T_delete"))
	_write_results()
	await _wait_frames(2)

	start_usec = Time.get_ticks_usec()
	var reset_ok: bool = ui.reset_active_draft_to_baseline()
	_append_elapsed("reset_active_draft_to_baseline_call", start_usec)
	lines.append("reset_ok=%s" % str(reset_ok))
	lines.append("reset_editor_dirty=%s" % str(bool(ui.get("editor_state_dirty"))))
	lines.append_array(_build_active_draft_lines(ui, "after_reset"))
	lines.append("library_file_bytes_after_all=%d" % _get_file_length(ProjectSettings.globalize_path(library_state.save_file_path)))
	_write_results()
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
	var result: PackedStringArray = []
	if ui == null:
		result.append("%s_ui_exists=false" % prefix)
		return result
	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	result.append("%s_ui_exists=true" % prefix)
	result.append("%s_active_saved_wip_id=%s" % [prefix, String(ui.active_saved_wip_id)])
	result.append("%s_active_draft_identifier=%s" % [prefix, String(ui.get_active_draft_identifier())])
	result.append("%s_draft_exists=%s" % [prefix, str(draft != null)])
	if draft == null:
		return result
	result.append("%s_node_count=%d" % [prefix, draft.motion_node_chain.size()])
	result.append("%s_selected_node_index=%d" % [prefix, draft.selected_motion_node_index])
	var runtime_clip = draft.baked_runtime_clip
	result.append("%s_runtime_clip_exists=%s" % [prefix, str(runtime_clip != null)])
	if runtime_clip != null and runtime_clip.has_method("get_frame_count"):
		result.append("%s_runtime_clip_frame_count=%d" % [prefix, int(runtime_clip.call("get_frame_count"))])
		result.append("%s_runtime_clip_solved_replay=%s" % [
			prefix,
			str(runtime_clip.has_method("has_solved_replay_track") and bool(runtime_clip.call("has_solved_replay_track"))),
		])
	return result

func _build_runtime_cache_draft_lines(ui: CombatAnimationStationUI) -> PackedStringArray:
	var result: PackedStringArray = []
	if ui == null:
		return result
	var drafts: Array = ui.call("_collect_runtime_clip_cache_drafts") as Array
	result.append("runtime_cache_draft_count=%d" % drafts.size())
	for draft_index: int in range(drafts.size()):
		var draft: Resource = drafts[draft_index] as Resource
		if draft == null:
			continue
		var motion_node_chain: Array = draft.get("motion_node_chain") as Array
		var runtime_clip = draft.get("baked_runtime_clip")
		var frame_count: int = -1
		if runtime_clip != null and runtime_clip.has_method("get_frame_count"):
			frame_count = int(runtime_clip.call("get_frame_count"))
		result.append("runtime_cache_draft_%d=%s nodes=%d frames=%d" % [
			draft_index,
			String(draft.get("draft_id")),
			motion_node_chain.size(),
			frame_count,
		])
	return result

func _build_meta_trace_lines(ui: Object, prefix: String, meta_name: String) -> PackedStringArray:
	var result: PackedStringArray = []
	if ui == null or not ui.has_meta(meta_name):
		result.append("%s_available=false" % prefix)
		return result
	result.append("%s_available=true" % prefix)
	var trace: Array = ui.get_meta(meta_name, []) as Array
	for trace_index: int in range(trace.size()):
		result.append("%s_%d=%s" % [prefix, trace_index, String(trace[trace_index])])
	return result

func _append_elapsed(label: String, start_usec: int) -> void:
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	lines.append("%s_ms=%.3f" % [label, elapsed_ms])

func _get_file_length(absolute_path: String) -> int:
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return -1
	var length: int = int(file.get_length())
	file.close()
	return length

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame

func _write_results() -> void:
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(lines))
	file.close()
