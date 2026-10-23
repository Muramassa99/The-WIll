extends "res://tools/verify_profiled_skill_equipped_playback.gd"

## Reads a fresh isolated saved library from the prepared endpoint UI diagnostic.
## Production player activation and final skeleton signals; no original save writes.
## --source=C:/WORKSPACE/.../profile_library.tres --slot=skill_slot_1 --out=C:/WORKSPACE/.../equipped.json
const Channels = preload("res://core/resolvers/combat_runtime_clip_incremental_resolver.gd")
const Chronology = preload("res://runtime/player/grip/grip_chronology.gd")
var _activation_solve_start_count: int = -1

func _run() -> void:
	var selected_slot: StringName = &"skill_slot_1"
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() != 2:
			continue
		if pair[0] == "source": _source = pair[1]
		if pair[0] == "out": _output = pair[1]
		if pair[0] == "slot": selected_slot = StringName(pair[1])
	if not _source.is_absolute_path() or not _output.is_absolute_path():
		_finish(false, "absolute_source_and_out_required"); return
	if _source.replace("\\", "/").to_lower() == _output.replace("\\", "/").to_lower():
		_output = ""
		_finish(false, "report_cannot_overwrite_source"); return
	if FileAccess.file_exists(_output):
		_output = ""
		_finish(false, "fresh_report_path_required"); return
	if not FileAccess.file_exists(_source):
		_finish(false, "source_library_missing"); return
	if not Chronology.enabled():
		_finish(false, "fresh_THE_WILL_GRIP_TRACE_PATH_required"); return
	_source_hash = FileAccess.get_sha256(_source)
	var loaded := ResourceLoader.load(_source, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState
	if loaded == null:
		_finish(false, "source_library_load_failed"); return
	var saved_weapon: CraftedItemWIP
	for candidate: CraftedItemWIP in loaded.saved_wips:
		if candidate != null and candidate.forge_project_name == WEAPON_NAME:
			if saved_weapon != null:
				_finish(false, "ambiguous_weapon_name"); return
			saved_weapon = candidate
	if saved_weapon == null:
		_finish(false, "saved_weapon_missing"); return
	_weapon_id = saved_weapon.wip_id
	var station := saved_weapon.combat_animation_station_state as CombatAnimationStationState
	var saved_draft: CombatAnimationDraft
	if station != null:
		for candidate: CombatAnimationDraft in station.skill_drafts:
			if candidate != null and candidate.legal_slot_id == selected_slot:
				if saved_draft != null:
					_finish(false, "ambiguous_saved_slot"); return
				saved_draft = candidate
	if saved_draft == null:
		_finish(false, "saved_slot_missing"); return
	var saved_clip := saved_draft.baked_runtime_clip as CombatRuntimeClip
	var saved_tracks := _complete_saved_tracks(saved_clip)
	_report.merge({
		"source": _source, "source_sha256": _source_hash, "weapon": WEAPON_NAME,
		"weapon_id": String(_weapon_id), "slot": String(selected_slot), "draft_id": String(saved_draft.draft_id),
		"raw_node_count": saved_draft.motion_node_chain.size(),
		"visible_node_count": saved_draft.get_action_motion_node_chain().size(),
		"cache_signature": saved_draft.runtime_cache_signature,
		"saved_tracks": saved_tracks,
		"probe_version": "prepared_endpoint_equipped_v2",
		"limits": "Selected real-rig samples and saved-track equality; no visual, full-hand contact, continuous playback, or recovery certification.",
	})
	if saved_draft.draft_kind != CombatAnimationDraft.DRAFT_KIND_SKILL or saved_draft.get_action_motion_node_chain().is_empty():
		_finish(false, "expected_at_least_one_visible_action_destination"); return
	if not saved_draft.runtime_cache_signature.begins_with(CombatRuntimeClip.RUNTIME_CACHE_VERSION + "|"):
		_finish(false, "prepared_clip_requires_current_cache_version"); return
	if saved_draft.preview_loop_enabled or not bool(saved_tracks.get("ok", false)):
		_finish(false, "nonlooping_complete_saved_replay_required"); return

	# These are the freshly loaded saved resources. Production readers clone them;
	# no Save, normalization, fixture rebuild or publication happens in this tool.
	_library.saved_wips = loaded.saved_wips
	_library.selected_wip_id = _weapon_id
	if _equipment.equip_forge_test_wip(HAND, saved_weapon) == null:
		_finish(false, "equip_failed"); return
	_player = PlayerScene.instantiate() as PlayerController3D
	if _player == null:
		_finish(false, "player_scene_instantiation_failed"); return
	_player.equipment_state = _equipment
	_player.forge_wip_library_state = _library
	_player.player_skill_slot_state = _slots
	_player.weapons_drawn = true
	root.add_child(_player)
	# Keep the real rig/modifier processing. The normal controller idle update is
	# stepped below before activation; automatic locomotion/playback stay frozen
	# so neither free fall nor automatic advances affect the exact samples.
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)
	for _index: int in 3:
		await physics_frame
		await process_frame
	_weapon = _player.held_item_nodes.get(HAND) as Node3D
	if _weapon == null or StringName(_weapon.get_meta("source_wip_id", StringName())) != _weapon_id:
		_finish(false, "actual_equipped_weapon_missing"); return
	_observed_skeleton = _player.humanoid_rig.get("skeleton") as Skeleton3D
	if _observed_skeleton == null:
		_finish(false, "actual_equipped_skeleton_missing"); return
	# A direct signal callback observes the final skin pose while modifier output
	# is still applied. Reading after process_frame can see restored input poses.
	_observed_skeleton.skeleton_updated.connect(_capture_final_skeleton_pose)
	_report["pre_idle_weapon"] = _weapon_transform_diagnostic()
	var idle_ready: bool = await _prepare_combat_idle()
	if not idle_ready:
		_finish(false, "production_combat_idle_not_ready"); return
	_report["pre_activation_weapon"] = _weapon_transform_diagnostic()
	Chronology.event("audit.equipped_before_activation", {"terminal": true})
	_activation_solve_start_count = _count_acquisition_starts()
	if _activation_solve_start_count < 0:
		_finish(false, "grip_acquisition_trace_unreadable"); return
	_player.call("_sync_equipped_skill_slots")
	_player.call("_activate_skill_slot", selected_slot)
	var activation: Dictionary = _player.get_last_skill_activation_result()
	_report["activation"] = {
		"success": activation.get("success", false),
		"runtime_playback_started": activation.get("runtime_playback_started", false),
		"grip_replay_ready": activation.get("grip_replay_ready", false),
		"message": activation.get("message", ""),
		"runtime_message": activation.get("runtime_playback_message", ""),
		"source_weapon_wip_id": String(activation.get("source_weapon_wip_id", "")),
		"source_skill_draft_id": String(activation.get("source_skill_draft_id", "")),
		"source_equipment_slot_id": String(activation.get("source_equipment_slot_id", "")),
	}
	if (
		not bool(activation.get("success", false))
		or not bool(activation.get("runtime_playback_started", false))
		or not bool(activation.get("grip_replay_ready", false))
		or StringName(activation.get("source_weapon_wip_id", StringName())) != _weapon_id
		or StringName(activation.get("source_skill_draft_id", StringName())) != saved_draft.draft_id
		or StringName(activation.get("source_equipment_slot_id", StringName())) != HAND
	):
		_finish(false, "saved_slot_activation_failed"); return
	var presenter: PlayerRuntimeSkillPlaybackPresenter = _player.runtime_skill_playback_presenter
	var runtime_clip: CombatRuntimeClip = presenter.active_runtime_clip
	if runtime_clip == null or not runtime_clip.has_solved_replay_track():
		_finish(false, "equipped_solved_track_missing"); return
	var offset: float = presenter.last_entry_bridge_duration_seconds
	_report["runtime"] = {
		"duration_seconds": runtime_clip.total_duration_seconds,
		"frame_count": runtime_clip.get_frame_count(),
		"saved_duration_seconds": saved_clip.total_duration_seconds,
		"entry_bridge_seconds": offset,
		"saved_sample_rate_hz": saved_clip.sample_rate_hz,
		"runtime_sample_rate_hz": runtime_clip.sample_rate_hz,
		"cached_track_copied": presenter.active_runtime_skill_result.get("cached_runtime_clip_upper_body_pose_track", false),
		"compile_diagnostics": presenter.active_runtime_skill_result.get("runtime_compile_diagnostics", []),
	}
	if not bool(_report.runtime.cached_track_copied):
		_finish(false, "saved_track_not_consumed"); return
	await _settle_rig(presenter.chain_player)
	var entry := _sample("activation_start", 0.0, presenter.last_runtime_pose_state, false)
	entry["comparison"] = "Current-pose entry bridge; not equality with the first saved pose." if offset > 0.0001 else "Initial saved pose."
	_report.samples.append(entry)
	var all_ok := bool(entry.ok)
	var rate_and_entry_ok: bool = (
		is_equal_approx(saved_clip.sample_rate_hz, 60.0)
		and is_equal_approx(runtime_clip.sample_rate_hz, 60.0)
		and absf(offset - 0.160) < 0.000001
	)
	_report["sixty_hertz_body_and_160ms_entry"] = rate_and_entry_ok
	all_ok = all_ok and rate_and_entry_ok
	var prefix_count: int = runtime_clip.get_frame_count() - saved_clip.get_frame_count()
	var body_channels_unchanged: bool = prefix_count >= 0
	var body_timestamps_shifted_only: bool = prefix_count >= 0
	if prefix_count >= 0:
		for field: StringName in Channels.INPUT_FRAME_FIELDS + Channels.SOLVED_FRAME_FIELDS:
			if field == &"baked_frame_times":
				continue
			body_channels_unchanged = body_channels_unchanged and runtime_clip.get(field).slice(prefix_count) == saved_clip.get(field)
		for index: int in saved_clip.get_frame_count():
			body_timestamps_shifted_only = body_timestamps_shifted_only and absf(float(runtime_clip.baked_frame_times[index + prefix_count]) - float(saved_clip.baked_frame_times[index]) - offset) < 0.000001
	_report["prepared_body_channels_unchanged_after_equipped_entry"] = body_channels_unchanged
	_report["prepared_body_timestamps_only_shifted_by_entry"] = body_timestamps_shifted_only
	all_ok = all_ok and body_channels_unchanged and body_timestamps_shifted_only
	var first_authored_time := -1.0
	var bridge_flags: Array = runtime_clip.get_meta("baked_solved_replay_bridge_frame", [])
	for index: int in runtime_clip.get_frame_count():
		if runtime_clip.baked_frame_times[index] + 0.000001 >= offset and (bridge_flags.is_empty() or not bool(bridge_flags[index])):
			first_authored_time = runtime_clip.baked_frame_times[index]
			break
	if first_authored_time < 0.0:
		_finish(false, "authored_runtime_frame_missing"); return
	var times: Array[float] = [
		first_authored_time,
		maxf(first_authored_time, offset + saved_clip.total_duration_seconds * 0.5),
		runtime_clip.total_duration_seconds,
	]
	var labels := ["authored_start", "authored_middle", "terminal"]
	var elapsed := 0.0
	var terminal_state: Dictionary = {}
	for index: int in times.size():
		var target_time: float = times[index]
		var entry_wall_delta: float = maxf(minf(target_time, offset) - minf(elapsed, offset), 0.0)
		var body_wall_delta: float = maxf(target_time - maxf(elapsed, offset), 0.0) / presenter.chain_player.speed_scale
		var delta: float = entry_wall_delta + body_wall_delta
		# Cross the declared duration explicitly, exercising the actual terminal
		# sample and completion signal instead of a near-end interpolated pose.
		if index == times.size() - 1: delta += 0.00001
		var state := presenter.advance_playback(delta, _player.humanoid_rig, _player.held_item_nodes)
		elapsed = target_time
		await _settle_rig(presenter.chain_player)
		var sample := _sample(labels[index], target_time, state, true)
		_report.samples.append(sample)
		all_ok = all_ok and bool(sample.ok)
		if index == times.size() - 1: terminal_state = state
	var source_player = ChainPlayerScript.new()
	source_player.prepare_runtime_clip(saved_clip, 1.0, false)
	source_player.start()
	source_player.advance(saved_clip.total_duration_seconds + 0.00001)
	var saved_terminal := _compare_terminal_source(presenter.chain_player, source_player)
	_report["terminal_matches_saved"] = saved_terminal
	_report["terminal_finished"] = bool(terminal_state.get("finished", false)) and not presenter.chain_player.is_playing()
	all_ok = all_ok and bool(saved_terminal.ok) and bool(_report.terminal_finished)
	_finish(all_ok, "" if all_ok else "equipped_sample_or_terminal_check_failed")

func _count_acquisition_starts() -> int:
	var path: String = OS.get_environment("THE_WILL_GRIP_TRACE_PATH")
	var trace := FileAccess.open(path, FileAccess.READ)
	if trace == null:
		return -1
	var count := 0
	while not trace.eof_reached():
		var line: String = trace.get_line()
		if line.is_empty():
			continue
		var value: Variant = JSON.parse_string(line)
		if not value is Dictionary:
			return -1
		if String(value.get("name", "")) == "owner.solve_started":
			count += 1
	return count

func _finish(success: bool, reason: String) -> void:
	if _activation_solve_start_count >= 0:
		Chronology.event("audit.equipped_samples_complete", {"terminal": true})
		var final_count: int = _count_acquisition_starts()
		var no_new_acquisition: bool = final_count == _activation_solve_start_count
		_report["grip_acquisitions_during_activation_and_playback"] = {
			"before_activation": _activation_solve_start_count,
			"after_samples": final_count,
			"new_acquisitions": final_count - _activation_solve_start_count if final_count >= 0 else -1,
			"ok": no_new_acquisition,
			"scope": "Actual owner.solve_started trace events after prepared combat idle through equipped activation and sampled playback.",
		}
		if not no_new_acquisition:
			success = false
			if reason.is_empty():
				reason = "equipped_playback_started_new_grip_acquisition"
	Chronology.close()
	super._finish(success, reason)
