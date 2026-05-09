extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/skill_editor_runtime_cache_latency_2026-05-09.log"
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
	DirAccess.make_dir_recursive_absolute(RESULT_FILE_PATH.get_base_dir())
	lines.append("diagnostic=skill_editor_runtime_cache_latency")
	lines.append("user_dir=%s" % ProjectSettings.globalize_path("user://"))
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create() as PlayerForgeWipLibraryState
	var skill_slot_state: PlayerSkillSlotState = PlayerSkillSlotStateScript.load_or_create() as PlayerSkillSlotState
	lines.append("library_loaded=%s" % str(library_state != null))
	lines.append("skill_slot_state_loaded=%s" % str(skill_slot_state != null))
	if library_state == null:
		_write_results()
		quit(2)
		return
	lines.append("library_file_bytes=%d" % _get_file_length(ProjectSettings.globalize_path(library_state.save_file_path)))
	lines.append("saved_wip_count=%d" % library_state.get_saved_wips().size())
	var target_wip_id: StringName = _resolve_target_wip_id(library_state, skill_slot_state)
	lines.append("target_wip_id=%s" % String(target_wip_id))

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await process_frame

	var start_usec: int = Time.get_ticks_usec()
	ui.open_for(fake_player, "Runtime Cache Latency Diagnostic")
	_append_elapsed("open_for_call", start_usec)
	await _wait_frames(4)

	start_usec = Time.get_ticks_usec()
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(target_wip_id, &"hand_right", false, false)
	_append_elapsed("open_saved_wip_with_hand_setup_call", start_usec)
	await _wait_frames(4)

	start_usec = Time.get_ticks_usec()
	var select_ok: bool = ui.select_skill_slot(TARGET_SLOT_ID, true)
	_append_elapsed("select_skill_slot_call", start_usec)
	await _wait_frames(4)

	lines.append("open_ok=%s" % str(open_ok))
	lines.append("select_skill_ok=%s" % str(select_ok))
	_write_results()

	var drafts: Array = ui.call("_collect_runtime_clip_cache_drafts") as Array
	lines.append("runtime_cache_draft_count=%d" % drafts.size())
	_write_results()
	for draft_index: int in range(drafts.size()):
		var draft: Resource = drafts[draft_index] as Resource
		if draft == null:
			continue
		var before_node_count: int = int((draft.get("motion_node_chain") as Array).size())
		start_usec = Time.get_ticks_usec()
		var cache_result: Dictionary = ui.call("_refresh_runtime_clip_cache_for_draft", draft) as Dictionary
		_append_elapsed("draft_%d_cache_call" % draft_index, start_usec)
		var runtime_clip = draft.get("baked_runtime_clip")
		var frame_count: int = -1
		if runtime_clip != null and runtime_clip.has_method("get_frame_count"):
			frame_count = int(runtime_clip.call("get_frame_count"))
		lines.append("draft_%d_id=%s" % [draft_index, String(draft.get("draft_id"))])
		lines.append("draft_%d_nodes=%d" % [draft_index, before_node_count])
		lines.append("draft_%d_cached=%s" % [draft_index, str(bool(cache_result.get("cached", false)))])
		lines.append("draft_%d_reason=%s" % [draft_index, String(cache_result.get("reason", ""))])
		lines.append("draft_%d_frames=%d" % [draft_index, frame_count])
		lines.append("draft_%d_solved_replay_track=%s" % [draft_index, str(bool(cache_result.get("solved_replay_track", false)))])
		_write_results()
		await process_frame
	quit(0)

func _resolve_target_wip_id(library_state: PlayerForgeWipLibraryState, skill_slot_state: PlayerSkillSlotState) -> StringName:
	if skill_slot_state != null:
		var assignment: Resource = skill_slot_state.get_slot_assignment(TARGET_SLOT_ID)
		if assignment != null:
			var assigned_wip_id: StringName = StringName(assignment.get("source_weapon_wip_id"))
			if assigned_wip_id != StringName():
				return assigned_wip_id
	if library_state != null:
		return library_state.selected_wip_id
	return StringName()

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
