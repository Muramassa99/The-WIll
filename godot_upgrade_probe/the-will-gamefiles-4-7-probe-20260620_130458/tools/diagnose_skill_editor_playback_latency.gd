extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/skill_editor_playback_latency_2026-05-10.log"
const TARGET_SLOT_ID: StringName = &"skill_slot_1"
const PREVIEW_ROOT_NAME := "CombatAnimationPreviewRoot3D"
const PLAYBACK_FRAME_SAMPLE_COUNT := 90
const PLAYBACK_FRAME_DELTA := 1.0 / 60.0

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
	lines.append("diagnostic=skill_editor_playback_latency")
	lines.append("target_slot_id=%s" % String(TARGET_SLOT_ID))
	DirAccess.make_dir_recursive_absolute(RESULT_FILE_PATH.get_base_dir())

	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create() as PlayerForgeWipLibraryState
	var skill_slot_state: PlayerSkillSlotState = PlayerSkillSlotStateScript.load_or_create() as PlayerSkillSlotState
	lines.append("library_loaded=%s" % str(library_state != null))
	lines.append("skill_slot_state_loaded=%s" % str(skill_slot_state != null))
	if library_state == null:
		_write_results()
		quit(2)
		return

	var target_wip_id: StringName = _resolve_target_wip_id(library_state, skill_slot_state)
	var target_wip: CraftedItemWIP = library_state.get_saved_wip(target_wip_id)
	lines.append("target_wip_id=%s" % String(target_wip_id))
	lines.append("target_wip_found=%s" % str(target_wip != null))
	if target_wip == null:
		_write_results()
		quit(3)
		return

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	ui.set_meta("verification_skip_persistence", true)
	root.add_child(ui)
	await process_frame

	var start_usec: int = Time.get_ticks_usec()
	ui.open_for(fake_player, "Skill Editor Playback Latency Diagnostic")
	_append_elapsed("open_for_call", start_usec)
	await _wait_frames(4)

	start_usec = Time.get_ticks_usec()
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(target_wip_id, &"hand_right", false, false)
	_append_elapsed("open_saved_wip_with_hand_setup_call", start_usec)
	lines.append("after_open_retarget_result=%s" % str(ui.last_station_retarget_result))
	await _wait_frames(4)

	start_usec = Time.get_ticks_usec()
	var select_ok: bool = ui.select_skill_slot(TARGET_SLOT_ID, true)
	_append_elapsed("select_skill_slot_call", start_usec)
	await _wait_frames(4)

	lines.append("open_ok=%s" % str(open_ok))
	lines.append("select_skill_ok=%s" % str(select_ok))
	lines.append_array(_build_active_draft_lines(ui, "before_F"))
	lines.append_array(_build_cache_probe_lines(ui, library_state, "before_F"))
	_write_results()

	start_usec = Time.get_ticks_usec()
	ui.call("_toggle_preview_playback")
	_append_elapsed("key_F_before_save_call", start_usec)
	lines.append("playback_started_before_save=%s" % str(ui.chain_player.is_playing()))
	lines.append_array(_build_active_draft_lines(ui, "after_F_before_save"))
	if ui.chain_player.is_playing():
		ui.chain_player.stop()
		ui.session_state.playback_active = false

	start_usec = Time.get_ticks_usec()
	ui.call("_manual_save_active_editor_state")
	await _wait_for_manual_save(ui)
	_append_elapsed("manual_save_total", start_usec)
	lines.append("manual_save_in_progress_after_wait=%s" % str(ui.manual_save_in_progress))
	lines.append_array(_build_active_draft_lines(ui, "after_manual_save"))
	_write_results()

	start_usec = Time.get_ticks_usec()
	ui.call("_toggle_preview_playback")
	_append_elapsed("key_F_after_save_call", start_usec)
	lines.append("playback_started_after_save=%s" % str(ui.chain_player.is_playing()))
	lines.append_array(_build_active_draft_lines(ui, "after_F_after_save"))

	var frame_total_ms: float = 0.0
	var frame_max_ms: float = 0.0
	var frame_count: int = 0
	var fast_frame_count: int = 0
	for frame_index: int in range(PLAYBACK_FRAME_SAMPLE_COUNT):
		if not ui.chain_player.is_playing():
			break
		start_usec = Time.get_ticks_usec()
		ui.call("_process", PLAYBACK_FRAME_DELTA)
		var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
		frame_total_ms += elapsed_ms
		frame_max_ms = maxf(frame_max_ms, elapsed_ms)
		frame_count += 1
		if _preview_used_solved_replay_fast_path(ui):
			fast_frame_count += 1
		if frame_index < 12:
			lines.append("playback_frame_%02d_ms=%.3f" % [frame_index, elapsed_ms])

	var frame_avg_ms: float = frame_total_ms / float(frame_count) if frame_count > 0 else 0.0
	lines.append("playback_measured_frame_count=%d" % frame_count)
	lines.append("playback_fast_frame_count=%d" % fast_frame_count)
	lines.append("playback_frame_avg_ms=%.3f" % frame_avg_ms)
	lines.append("playback_frame_max_ms=%.3f" % frame_max_ms)
	lines.append("playback_still_playing_after_sample=%s" % str(ui.chain_player.is_playing()))
	if ui.chain_player.is_playing():
		ui.chain_player.stop()
		ui.session_state.playback_active = false
	start_usec = Time.get_ticks_usec()
	ui.call("_toggle_preview_playback")
	_append_elapsed("key_F_cached_restart_call", start_usec)
	lines.append_array(_measure_playback_frames(ui, "cached_restart", 12))
	if ui.chain_player.is_playing():
		ui.chain_player.stop()
		ui.session_state.playback_active = false
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

func _build_cache_probe_lines(
	ui: CombatAnimationStationUI,
	library_state: PlayerForgeWipLibraryState,
	prefix: String
) -> PackedStringArray:
	var result: PackedStringArray = []
	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft if ui != null else null
	if ui == null or draft == null or library_state == null:
		result.append("%s_cache_probe_available=false" % prefix)
		return result
	var cache_signature: String = String(ui.call("_build_runtime_clip_cache_signature", draft))
	result.append("%s_cache_probe_available=true" % prefix)
	result.append("%s_cache_signature_length=%d" % [prefix, cache_signature.length()])
	result.append("%s_cache_signature_hash=%d" % [prefix, cache_signature.hash()])
	var saved_wip_id: StringName = ui.active_saved_wip_id if ui.active_saved_wip_id != StringName() else ui.active_wip.wip_id
	var draft_identifier: StringName = draft.context_id if StringName(draft.draft_kind) == &"draft_idle" else draft.owning_skill_id
	var cache_data: Dictionary = library_state.get_saved_draft_runtime_clip_cache(saved_wip_id, draft_identifier, StringName(draft.draft_kind) == &"draft_idle")
	var saved_signature: String = String(cache_data.get("runtime_cache_signature", ""))
	result.append("%s_saved_cache_found=%s" % [prefix, str(bool(cache_data.get("found", false)))])
	result.append("%s_saved_cache_frame_count=%d" % [prefix, int(cache_data.get("frame_count", -1))])
	result.append("%s_saved_signature_length=%d" % [prefix, saved_signature.length()])
	result.append("%s_saved_signature_hash=%d" % [prefix, saved_signature.hash()])
	result.append("%s_saved_signature_matches=%s" % [prefix, str(saved_signature == cache_signature)])
	result.append_array(_build_signature_diff_lines(cache_signature, saved_signature, prefix))
	return result

func _build_signature_diff_lines(current_signature: String, saved_signature: String, prefix: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var compare_length: int = mini(current_signature.length(), saved_signature.length())
	var first_diff_index: int = -1
	for char_index: int in range(compare_length):
		if current_signature[char_index] != saved_signature[char_index]:
			first_diff_index = char_index
			break
	if first_diff_index < 0 and current_signature.length() != saved_signature.length():
		first_diff_index = compare_length
	result.append("%s_signature_first_diff_index=%d" % [prefix, first_diff_index])
	if first_diff_index >= 0:
		var window_start: int = maxi(first_diff_index - 80, 0)
		var window_end_current: int = mini(first_diff_index + 160, current_signature.length())
		var window_end_saved: int = mini(first_diff_index + 160, saved_signature.length())
		result.append("%s_current_signature_diff_window=%s" % [prefix, current_signature.substr(window_start, window_end_current - window_start)])
		result.append("%s_saved_signature_diff_window=%s" % [prefix, saved_signature.substr(window_start, window_end_saved - window_start)])
	return result

func _preview_used_solved_replay_fast_path(ui: CombatAnimationStationUI) -> bool:
	if ui == null or ui.preview_subviewport == null:
		return false
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null(PREVIEW_ROOT_NAME) as Node3D
	if preview_root == null:
		return false
	var resolved_state: Dictionary = preview_root.get_meta("resolved_playback_state", {}) as Dictionary
	return bool(resolved_state.get("solved_replay_applied", false))

func _measure_playback_frames(ui: CombatAnimationStationUI, prefix: String, sample_count: int) -> PackedStringArray:
	var result: PackedStringArray = []
	var frame_total_ms: float = 0.0
	var frame_max_ms: float = 0.0
	var frame_count: int = 0
	var fast_frame_count: int = 0
	var max_frame_index: int = -1
	for frame_index: int in range(maxi(sample_count, 0)):
		if not ui.chain_player.is_playing():
			break
		var start_usec: int = Time.get_ticks_usec()
		ui.call("_process", PLAYBACK_FRAME_DELTA)
		var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
		frame_total_ms += elapsed_ms
		if elapsed_ms > frame_max_ms:
			frame_max_ms = elapsed_ms
			max_frame_index = frame_index
		frame_count += 1
		if _preview_used_solved_replay_fast_path(ui):
			fast_frame_count += 1
	var frame_avg_ms: float = frame_total_ms / float(frame_count) if frame_count > 0 else 0.0
	result.append("%s_measured_frame_count=%d" % [prefix, frame_count])
	result.append("%s_fast_frame_count=%d" % [prefix, fast_frame_count])
	result.append("%s_frame_avg_ms=%.3f" % [prefix, frame_avg_ms])
	result.append("%s_frame_max_ms=%.3f" % [prefix, frame_max_ms])
	result.append("%s_frame_max_index=%d" % [prefix, max_frame_index])
	return result

func _append_elapsed(label: String, start_usec: int) -> void:
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	lines.append("%s_ms=%.3f" % [label, elapsed_ms])

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame

func _wait_for_manual_save(ui: CombatAnimationStationUI, max_frames: int = 1200) -> void:
	for _frame_index: int in range(maxi(max_frames, 0)):
		await process_frame
		if ui == null or not ui.manual_save_in_progress:
			return

func _write_results() -> void:
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(lines))
	file.close()
