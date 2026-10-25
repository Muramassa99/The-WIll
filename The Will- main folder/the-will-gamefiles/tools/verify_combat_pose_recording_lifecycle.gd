extends "res://tools/diagnose_skill_slot_ui_replica.gd"

## Real station lifecycle regression. This deliberately does NOT call
## _prepare_editor_snapshots(), explicitly capture a pose, or visit every node.
## Same isolated environment contract as diagnose_skill_slot_ui_replica.gd.
## Optional THE_WILL_LIFECYCLE_SLOT defaults to skill_slot_2.
## THE_WILL_LIFECYCLE_FRESH=1 instead defaults to empty Skill3 and creates
## the second visible node through R before running the lifecycle cases.
## THE_WILL_LIFECYCLE_CHECK_FAILED_SAVE=1 then tries the existing invalid Skill2
## and checks that a rejected Save preserves the playable saved library.
## THE_WILL_LIFECYCLE_CHECK_RESET=1 checks explicit Reset after a small edit to
## the fresh initial node, before creating the remainder of the test chain.
## The saved profile_library.tres is also input to
## verify_prepared_skill_equipped_playback.gd --slot=<the selected slot>.
const PreparedPoseContract = preload("res://core/models/combat_prepared_pose.gd")
const ClipChannels = preload("res://core/resolvers/combat_runtime_clip_incremental_resolver.gd")
const ArmFrameContract = preload("res://core/resolvers/combat_prepared_arm_frame_resolver.gd")
const OriginContract = preload("res://core/models/combat_origin_record.gd")

var _lifecycle_slot: StringName = TARGET_SLOT
var _lifecycle_world: Node
var _visited_indices: Array[int] = []
var _fresh_lifecycle_fixture: bool = false
var _unrelated_metadata_probe: Dictionary = {}


func _run() -> void:
	_source = OS.get_environment("THE_WILL_GRIP_LIVE_LIBRARY").replace("\\", "/")
	_output = OS.get_environment("THE_WILL_SAVE_PROFILE_OUTPUT_DIR").replace("\\", "/")
	var expected: String = OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").to_lower()
	if not expected.begins_with("c:/workspace/") or OS.get_user_data_dir().replace("\\", "/").to_lower() != expected:
		push_error("Isolated diagnostic user root required."); quit(1); return
	if not _source.to_lower().begins_with("c:/workspace/") or not _output.to_lower().begins_with("c:/workspace/"):
		push_error("Workspace source/output required."); quit(1); return
	if FileAccess.file_exists(_output.path_join("pose_recording_lifecycle.json")) or _source.to_lower().begins_with(_output.to_lower() + "/"):
		push_error("Fresh output separate from source required."); quit(1); return
	if not FileAccess.file_exists(_source) or DirAccess.make_dir_recursive_absolute(_output) != OK:
		quit(1); return
	_source_hash = FileAccess.get_sha256(_source)
	if not Chronology.enabled():
		_finish("fresh_grip_trace_required"); return
	_fresh_lifecycle_fixture = OS.get_environment("THE_WILL_LIFECYCLE_FRESH") == "1"
	if _fresh_lifecycle_fixture: _lifecycle_slot = &"skill_slot_3"
	var slot_setting: String = OS.get_environment("THE_WILL_LIFECYCLE_SLOT")
	if not slot_setting.is_empty(): _lifecycle_slot = StringName(slot_setting)
	_library = ResourceLoader.load(_source, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if _library == null: _finish("source_load_failed"); return
	_library.save_file_path = _output.path_join("profile_library.tres")
	_library.set("trace_save_latency", true)
	var requested: String = OS.get_environment("THE_WILL_GRIP_LIVE_WEAPON_NAME")
	if requested.is_empty(): requested = "Broken_Balde_v1"
	var selected: Resource
	for candidate: Resource in _library.saved_wips:
		if candidate.forge_project_name != requested: continue
		if selected != null: _finish("ambiguous_weapon_name"); return
		selected = candidate
	if selected == null: _finish("weapon_missing"); return
	_weapon_id = selected.wip_id
	_source_draft = _find_draft(selected, _lifecycle_slot)
	if _fresh_lifecycle_fixture and _source_draft != null and _source_draft.get_action_motion_node_chain().size() > 1:
		_finish("fresh_fixture_slot_already_has_multiple_nodes"); return
	if not _fresh_lifecycle_fixture and (_source_draft == null or _source_draft.get_action_motion_node_chain().size() < 2):
		_finish("fixture_needs_two_visible_nodes"); return
	_report.merge({"source_path": _source, "source_sha256": _source_hash, "weapon": requested,
		"slot": String(_lifecycle_slot), "source_recording_status": _node_statuses(_source_draft),
		"fresh_fixture": _fresh_lifecycle_fixture,
		"automation": "Real station controls and R/F input. No visit-all prewarming, explicit pose capture, direct authored-field assignment, or stored-pose injection. Only the isolated library is saved.",
		"limits": "Recording lifecycle, endpoint/entry data and actual preview start/completion. Does not certify anatomical correctness or contact quality. Equipped consumption is a separate verifier."})
	_write_report()
	if not await _open_lifecycle_station(): _finish("initial_station_open_failed"); return
	if not _ui.has_method("is_motion_node_recording_pending"):
		_finish("recording_lifecycle_API_missing"); return
	if _fresh_lifecycle_fixture and not _check_pending_baseline_edit_rejected("fresh_pending_baseline_edit"):
		_finish("fresh_pending_baseline_edit_not_guarded"); return
	var draft: Resource = _ui.call("_get_active_draft")
	var first: int = _ui.call("_get_user_visible_motion_node_start_index", draft)
	var last: int = draft.motion_node_chain.size() - 1
	_visited_indices.append(_ui.get_selected_motion_node_index())
	# Initial weapon opening is asynchronous. Observe only the naturally selected
	# pose becoming ready before starting the rapid-edit cases.
	if not await _wait_natural_recording("initial_open_recording", _fresh_lifecycle_fixture):
		_finish("initial_open_pose_unavailable"); return
	if _fresh_lifecycle_fixture:
		if not _check_baseline_consistency("fresh_initial_baseline"):
			_finish("fresh_initial_baseline_inconsistent"); return
		if OS.get_environment("THE_WILL_LIFECYCLE_CHECK_RESET") == "1":
			if not _small_roll_edit() or not await _wait_natural_recording("before_explicit_Reset"):
				_finish("explicit_Reset_setup_edit_failed"); return
			_ui.reset_draft_button.pressed.emit()
			if not _check_pending_baseline_edit_rejected("Reset_pending_baseline_edit"):
				_finish("Reset_pending_baseline_edit_not_guarded"); return
			if not await _wait_natural_recording("explicit_Reset_recording", true) or not _check_baseline_consistency("explicit_Reset_baseline"):
				_finish("explicit_Reset_baseline_inconsistent"); return
			draft = _ui.call("_get_active_draft")
			first = _ui.call("_get_user_visible_motion_node_start_index", draft)
		if not await _check_authored_single_node_reselect(): return
		draft = _ui.call("_get_active_draft")
		first = _ui.call("_get_user_visible_motion_node_start_index", draft)
		if draft.get_action_motion_node_chain().size() != 1 or _ui.get_selected_motion_node_index() != first:
			_finish("fresh_fixture_expected_one_initial_visible_node"); return
		var initial: Resource = draft.motion_node_chain[first]
		var initial_count: int = draft.motion_node_chain.size()
		_action(CombatAnimationStationUI.ACTION_NEW_NODE)
		if not await _wait_selection(first + 1, "fresh_fixture_R", initial) or draft.motion_node_chain.size() != initial_count + 1:
			_finish("fresh_fixture_R_failed"); return
		if not await _wait_natural_recording("fresh_fixture_second_recording"):
			_finish("fresh_fixture_second_pose_unavailable"); return
		last = draft.motion_node_chain.size() - 1
		_report["fresh_fixture_after_R"] = _node_statuses(draft)
	if not _ui.select_motion_node(last) or not await _wait_selection(last, "initial_last_selection"):
		_finish("initial_last_selection_failed"); return
	if not await _wait_natural_recording("initial_last_recording"):
		_finish("initial_last_pose_unavailable"); return
	if not await _edit_then_append(false): return
	if not await _edit_then_append(true): return
	if not await _grip_then_navigate(first): return
	if not _edit_unrelated_description(): return
	draft = _ui.call("_get_active_draft")
	last = draft.motion_node_chain.size() - 1
	if not _ui.select_motion_node(last) or not await _wait_selection(last, "final_selection"):
		_finish("final_selection_failed"); return
	if not await _wait_natural_recording("before_final_edit"):
		_finish("final_pose_unavailable"); return
	var final_node: Resource = draft.motion_node_chain[last]
	var prior_signature: String = final_node.prepared_pose_signature
	if not _small_roll_edit(): _finish("final_roll_edit_rejected"); return
	# No frame/yield here: F must own the final outstanding edit and legacy repair.
	_report["final_edit_before_F"] = {"old_signature": prior_signature,
		"current_signature": PreparedPoseContract.node_pose_signature(final_node),
		"recording_current": _node_current(final_node), "visited_indices": _visited_indices.duplicate(),
		"nodes_before_F": _node_statuses(draft)}
	if not await _play_lifecycle_preview("edited_final_F"):
		_write_working_draft_artifact("F_failure_working_draft.tres")
		if OS.get_environment("THE_WILL_LIFECYCLE_CHECK_FAILED_SAVE") == "1":
			await _probe_save_after_failed_preview()
		_finish("edited_final_F_failed"); return
	if not _node_current(final_node): _finish("final_edit_not_recorded_by_F"); return
	if not await _save_and_reopen(): return
	# Fresh scene/resources; no waiting for grip/capture and no node visits.
	if not await _play_lifecycle_preview("fresh_reopen_F"):
		_write_working_draft_artifact("F_failure_working_draft.tres")
		if OS.get_environment("THE_WILL_LIFECYCLE_CHECK_FAILED_SAVE") == "1":
			await _probe_save_after_failed_preview()
		_finish("fresh_reopen_F_failed"); return
	_report["equipped_verifier_input"] = {"source": _library.save_file_path, "slot": String(_lifecycle_slot),
		"tool": "res://tools/verify_prepared_skill_equipped_playback.gd", "run_in_this_verifier": false}
	if OS.get_environment("THE_WILL_LIFECYCLE_CHECK_FAILED_SAVE") == "1":
		if not await _check_failed_save_preserves_library(): return
	_finish("finished")


func _open_lifecycle_station() -> bool:
	_lifecycle_world = WORLD.instantiate()
	root.add_child(_lifecycle_world)
	current_scene = _lifecycle_world
	await process_frame
	var player: PlayerController3D = _lifecycle_world.get_node("PlayerCharacter")
	player.forge_wip_library_state = _library
	var station: CombatAnimationStation = _lifecycle_world.get_node("CombatAnimationStation")
	_ui = station.station_ui as CombatAnimationStationUI
	_ui.set_meta("trace_save_latency", true)
	_ui.preview_presenter.set_meta("trace_save_latency", true)
	station.interact(player)
	await process_frame
	return _ui.open_saved_wip_with_hand_setup(_weapon_id, HAND, false, true) and _ui.select_skill_slot(_lifecycle_slot, true)


func _small_roll_edit() -> bool:
	var node: Resource = _ui.call("_get_active_motion_node")
	var before: String = PreparedPoseContract.node_pose_signature(node)
	var current: float = node.weapon_roll_degrees
	# Try the opposite direction only if the first is an endpoint no-op.
	var accepted: bool = _ui.set_selected_motion_node_weapon_roll(current + 1.0, false)
	if not accepted: accepted = _ui.set_selected_motion_node_weapon_roll(current - 1.0, false)
	return accepted and PreparedPoseContract.node_pose_signature(node) != before


func _check_pending_baseline_edit_rejected(label: String) -> bool:
	var node: Resource = _ui.call("_get_active_motion_node")
	var preparation: Dictionary = _ui.get_meta("last_baseline_preparation", {})
	var before: String = PreparedPoseContract.node_pose_signature(node)
	var accepted: bool = _ui.set_selected_motion_node_weapon_roll(float(node.weapon_roll_degrees) + 1.0, false)
	var unchanged: bool = PreparedPoseContract.node_pose_signature(node) == before
	var pending: bool = not preparation.is_empty() and not bool(preparation.get("ready", true))
	_report.phases.append({"phase": label, "baseline_preparation": preparation.duplicate(true),
		"baseline_pending": pending, "edit_accepted": accepted, "authored_signature_unchanged": unchanged,
		"status": _ui.footer_status_label.text})
	_write_report()
	return pending and not accepted and unchanged


func _check_authored_single_node_reselect() -> bool:
	if not _small_roll_edit() or not await _wait_natural_recording("single_node_authored_edit"):
		_finish("single_node_reselect_setup_failed"); return false
	var draft: Resource = _ui.call("_get_active_draft")
	var before: Dictionary = _manual_controls(draft)
	if not _ui.select_skill_slot(_lifecycle_slot, true) or not await _wait_natural_recording("authored_single_node_reselect"):
		_finish("authored_single_node_reselect_failed"); return false
	var after: Resource = _ui.call("_get_active_draft")
	var differences: Array = _snapshot_diff(before, _manual_controls(after), "authored_single_node")
	_report.phases.append({"phase": "authored_single_node_controls_preserved", "differences": differences,
		"visible_node_count": after.get_action_motion_node_chain().size(),
		"baseline_preparation": _ui.get_meta("last_baseline_preparation", {})})
	_write_report()
	if not differences.is_empty() or after.get_action_motion_node_chain().size() != 1:
		_finish("authored_single_node_was_reset_on_reselect"); return false
	return true


func _check_baseline_consistency(label: String) -> bool:
	var node: Resource = _ui.call("_get_active_motion_node")
	var snapshot: Dictionary = node.prepared_pose if node != null else {}
	var preparation: Dictionary = _ui.get_meta("last_baseline_preparation", {})
	var expected_source: String = "reset" if label == "explicit_Reset_baseline" else "new_slot"
	var baseline_ready: bool = bool(preparation.get("ready", false)) and int(preparation.get("node_index", -1)) == 1 and String(preparation.get("source", "")) == expected_source
	var row := {"phase": label, "snapshot_current": _node_current(node),
		"baseline_preparation": preparation.duplicate(true), "baseline_preparation_ready": baseline_ready,
		"tolerance_m": ArmFrameContract.FRAME_EPSILON, "endpoint_fields_present": false}
	_report.phases.append(row)
	if not bool(row.snapshot_current) or not snapshot.get("trajectory_to_reference") is Transform3D or not snapshot.get("weapon_tip_local") is Vector3 or not snapshot.get("weapon_pommel_local") is Vector3:
		_write_report(); return false
	row.endpoint_fields_present = true
	var trajectory: Transform3D = snapshot.trajectory_to_reference
	var weapon := Transform3D(Basis(snapshot.weapon_rotation_reference_local).scaled(snapshot.weapon_scale_reference_local), snapshot.weapon_position_reference_local)
	var authored_tip: Vector3 = trajectory * node.tip_position_local
	var authored_pommel: Vector3 = trajectory * node.pommel_position_local
	var captured_tip: Vector3 = weapon * snapshot.weapon_tip_local
	var captured_pommel: Vector3 = weapon * snapshot.weapon_pommel_local
	var tip_error: float = authored_tip.distance_to(captured_tip)
	var pommel_error: float = authored_pommel.distance_to(captured_pommel)
	var origins_valid: bool = node.tip_position_origin_id == OriginContract.ORIGIN_TRAJECTORY_AUTHORING and node.pommel_position_origin_id == OriginContract.ORIGIN_TRAJECTORY_AUTHORING
	var draft: Resource = _ui.call("_get_active_draft")
	var raw: Array = draft.motion_node_chain
	var action: Array = draft.get_action_motion_node_chain()
	var hidden_excluded: bool = raw.size() >= 2 and action.size() == raw.size() - 1 and action[0] == raw[1] and not action.has(raw[0])
	var baseline_differences: Array = _node_diff(raw[0], raw[1], true) if raw.size() >= 2 else [{"reason": "missing_baseline_or_node1"}]
	var baseline_origins_match: bool = raw.size() >= 2 and raw[0].tip_position_origin_id == raw[1].tip_position_origin_id and raw[0].pommel_position_origin_id == raw[1].pommel_position_origin_id
	row.merge({"authored_tip_reference": _plain(authored_tip), "captured_tip_reference": _plain(captured_tip),
		"authored_pommel_reference": _plain(authored_pommel), "captured_pommel_reference": _plain(captured_pommel),
		"tip_error_m": tip_error, "pommel_error_m": pommel_error, "trajectory_origins_valid": origins_valid,
		"hidden_baseline_excluded_from_action": hidden_excluded, "baseline_control_differences": baseline_differences,
		"baseline_origins_match": baseline_origins_match,
		"valid": baseline_ready and hidden_excluded and baseline_differences.is_empty() and baseline_origins_match and origins_valid and is_finite(tip_error) and is_finite(pommel_error) and tip_error <= ArmFrameContract.FRAME_EPSILON and pommel_error <= ArmFrameContract.FRAME_EPSILON})
	_write_report()
	return bool(row.valid)


func _edit_then_append(duplicate: bool) -> bool:
	var draft: Resource = _ui.call("_get_active_draft")
	var count: int = draft.motion_node_chain.size()
	var old_index: int = _ui.get_selected_motion_node_index()
	var outgoing: Resource = draft.motion_node_chain[old_index]
	var label: String = "same_tick_edit_duplicate" if duplicate else "same_tick_edit_R"
	if not _small_roll_edit(): _finish(label + "_edit_rejected"); return false
	var current_before_request: bool = _node_current(outgoing)
	var accepted: bool = true
	# Intentionally no await between edit and departure request.
	if duplicate: accepted = _ui.duplicate_selected_motion_node()
	else: _action(CombatAnimationStationUI.ACTION_NEW_NODE)
	var row := {"phase": label, "accepted": accepted, "outgoing_index": old_index,
		"outgoing_current_before_request": current_before_request,
		"immediate_selected_index": _ui.get_selected_motion_node_index(),
		"immediate_recording_pending": _recording_pending()}
	_report.phases.append(row)
	if not accepted or (_ui.get_selected_motion_node_index() != old_index and not _node_current(outgoing)):
		_finish(label + "_left_unrecorded_pose"); return false
	if not await _wait_selection(old_index + 1, label, outgoing) or draft.motion_node_chain.size() != count + 1:
		_finish(label + "_did_not_append"); return false
	row["outgoing_current_after_departure"] = _node_current(outgoing)
	row["node_count"] = draft.motion_node_chain.size()
	if not await _wait_natural_recording(label + "_new_pose"):
		_finish(label + "_new_pose_unavailable"); return false
	_write_report()
	return true


func _grip_then_navigate(target: int) -> bool:
	var outgoing: Resource = _ui.call("_get_active_motion_node")
	var index: int = _ui.get_selected_motion_node_index()
	var before: float = outgoing.grip_seat_slide_offset
	var limits: Dictionary = _ui.call("_get_handle_edit_limits", outgoing)
	if not bool(limits.get("valid", false)):
		_finish("grip_navigation_limits_unavailable"); return false
	# Both this setter and its limits use normalized coordinates, not the
	# balanced weapon's signed display values. Old authored values can lie below
	# today's end bound while the live grip is already clamped to that bound.
	# Move from the effective legal station so this is a new grip relationship,
	# rather than merely accepting the clamp already used by the current solve.
	var minimum: float = limits.minimum
	var maximum: float = limits.maximum
	var effective_before: float = clampf(before, minimum, maximum)
	var toward: float = maximum if effective_before < (minimum + maximum) * 0.5 else minimum
	var destination: float = move_toward(effective_before, toward, minf(0.05, absf(toward - effective_before) * 0.5))
	var edit_started: int = Time.get_ticks_msec()
	if not _ui.set_selected_motion_node_grip_seat_slide(destination, false):
		_finish("grip_navigation_edit_rejected"); return false
	# No yield or polling: leave while the new acquisition is actually pending.
	var grip_pending: bool = _ui.preview_presenter.is_grip_acquisition_pending(_ui.preview_subviewport)
	var accepted: bool = _ui.select_motion_node(target)
	var row := {"phase": "pending_grip_navigation", "outgoing_index": index, "target_index": target,
		"from_percent": before, "effective_from_percent": effective_before,
		"requested_percent": destination, "to_percent": outgoing.grip_seat_slide_offset,
		"normalized_limits": limits, "edit_ms": Time.get_ticks_msec() - edit_started,
		"grip_pending_at_request": grip_pending, "accepted": accepted,
		"immediate_selected_index": _ui.get_selected_motion_node_index(), "immediate_recording_pending": _recording_pending()}
	_report.phases.append(row)
	# A cache hit that never starts acquisition does not exercise this regression.
	if not grip_pending: _finish("pending_grip_case_not_exercised"); return false
	if not accepted or (_ui.get_selected_motion_node_index() != index and not _node_current(outgoing)):
		_finish("pending_grip_navigation_left_unrecorded_pose"); return false
	if not await _wait_selection(target, "pending_grip_navigation", outgoing):
		_finish("pending_grip_navigation_did_not_finish"); return false
	row["outgoing_current_after_departure"] = _node_current(outgoing)
	_write_report()
	return true


func _wait_selection(index: int, label: String, outgoing: Resource = null) -> bool:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < MAX_PHASE_MS and not _finished:
		if _ui.get_selected_motion_node_index() == index and not _recording_pending():
			var valid: bool = outgoing == null or _node_current(outgoing)
			_report.phases.append({"phase": label + "_selection", "wait_ms": Time.get_ticks_msec() - started,
				"selected_index": index, "outgoing_current": valid})
			if not _visited_indices.has(index): _visited_indices.append(index)
			_write_report()
			return valid
		await process_frame
	return false


func _wait_natural_recording(label: String, require_baseline: bool = false) -> bool:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < MAX_PHASE_MS and not _finished:
		var baseline_ready: bool = not require_baseline or bool(_ui.get_meta("last_baseline_preparation", {}).get("ready", false))
		if baseline_ready and not _recording_pending() and not _ui.preview_presenter.is_grip_acquisition_pending(_ui.preview_subviewport) and _node_current(_ui.call("_get_active_motion_node")):
			_report.phases.append({"phase": label, "natural_recording_wait_ms": Time.get_ticks_msec() - started})
			_write_report()
			return true
		await process_frame
	return false


func _play_lifecycle_preview(label: String) -> bool:
	var before: Dictionary = _solve_start_count()
	var started: int = Time.get_ticks_msec()
	var last_log: int = started
	var idle_frames: int = 0
	_start_measure()
	_action(CombatAnimationStationUI.ACTION_PREVIEW_PLAYBACK)
	while not _ui.chain_player.is_playing() and Time.get_ticks_msec() - started < MAX_PHASE_MS and not _finished:
		if not _ui.preview_prepare_in_progress and not _recording_pending():
			idle_frames += 1
			if idle_frames >= 4: break
		else:
			idle_frames = 0
		if Time.get_ticks_msec() - last_log >= 5000:
			last_log = Time.get_ticks_msec()
			print("POSE_LIFECYCLE ", label, " wait_ms=", last_log - started, " status=", _ui.footer_status_label.text)
		await process_frame
	_measure = false
	var after_prepare: Dictionary = _solve_start_count()
	var draft: Resource = _ui.call("_get_active_draft")
	var body: Resource = draft.baked_runtime_clip
	var replay: Resource = _ui.chain_player.runtime_clip
	var row := {"phase": label, "prepare_wall_ms": Time.get_ticks_msec() - started,
		"max_process_frame_ms": _max_frame_ms, "playing": _ui.chain_player.is_playing(),
		"status": _ui.footer_status_label.text, "prepare_result": _ui.get_meta("last_preview_prepare_result", {}),
		"node_statuses": _node_statuses(draft),
		"prepare_acquisitions": int(after_prepare.count) - int(before.count)}
	_report.phases.append(row)
	_write_report()
	if not bool(row.playing) or body == null or replay == null: return false
	var action_nodes: Array = draft.get_action_motion_node_chain()
	var final_node: Resource = action_nodes.back()
	row["final_endpoint"] = _prepared_endpoint_comparison(final_node.prepared_pose, body, body.get_frame_count() - 1)
	row["body_node_count"] = body.motion_node_chain.size()
	row["expected_action_node_count"] = action_nodes.size()
	row["entry_seconds"] = _ui.chain_player._clip_entry_duration
	row["body_sample_rate_hz"] = body.sample_rate_hz
	row["replay_sample_rate_hz"] = replay.sample_rate_hz
	row["entry_keeps_saved_body"] = _entry_body_unchanged(body, replay)
	var valid: bool = bool(row.final_endpoint.valid) and row.body_node_count == action_nodes.size() and absf(float(row.entry_seconds) - 0.160) < 0.000001 and is_equal_approx(body.sample_rate_hz, 60.0) and is_equal_approx(replay.sample_rate_hz, 60.0) and bool(row.entry_keeps_saved_body)
	for node: Resource in action_nodes: valid = valid and _node_current(node)
	var play_started: int = Time.get_ticks_msec()
	var progressed: bool = false
	var elapsed_before: float = _ui.chain_player._clip_elapsed
	while _ui.chain_player.is_playing() and Time.get_ticks_msec() - play_started < MAX_PHASE_MS and not _finished:
		await process_frame
		progressed = progressed or _ui.chain_player._clip_elapsed > elapsed_before + 0.0001
		if draft.preview_loop_enabled and progressed and _ui.chain_player._clip_elapsed >= _ui.chain_player._clip_total_duration - 0.05:
			_action(CombatAnimationStationUI.ACTION_PREVIEW_PLAYBACK)
	var after: Dictionary = _solve_start_count()
	row["playback_progressed"] = progressed
	row["playback_completed"] = not _ui.chain_player.is_playing()
	row["playback_acquisitions"] = int(after.count) - int(after_prepare.count)
	row["trace_available"] = bool(before.available) and bool(after_prepare.available) and bool(after.available)
	_write_report()
	return valid and progressed and bool(row.playback_completed) and bool(row.trace_available) and int(row.playback_acquisitions) == 0


func _entry_body_unchanged(body: Resource, replay: Resource) -> bool:
	var offset: int = replay.get_frame_count() - body.get_frame_count()
	if offset < 0: return false
	for field: StringName in ClipChannels.INPUT_FRAME_FIELDS + ClipChannels.SOLVED_FRAME_FIELDS:
		var a: Variant = body.get(field)
		var b: Variant = replay.get(field)
		if a.size() == 0: continue
		if b.size() != a.size() + offset: return false
		for index: int in a.size():
			if field == &"baked_frame_times":
				if absf(float(b[index + offset]) - float(a[index]) - 0.160) > 0.00001: return false
			elif a[index] != b[index + offset]: return false
	return true


func _edit_unrelated_description() -> bool:
	var active: Resource = _ui.call("_get_active_draft")
	var other: Resource
	for candidate: Resource in _ui.active_wip.combat_animation_station_state.skill_drafts:
		if candidate != null and candidate != active and candidate.get_action_motion_node_chain().size() > 1:
			other = candidate
			break
	if other == null:
		_report.phases.append({"phase": "unrelated_description_edit", "exercised": false,
			"reason": "No other already-authored multi-node skill; unused drafts are deliberately not initialized."})
		return true
	var before: Dictionary = _nonactive_draft_states(_ui.active_wip, active.draft_id)
	var description: String = other.skill_description + "\nIsolated selected-Save lifecycle check."
	# Use real draft-list selection and the real metadata setter. Do not yield on
	# the unrelated skill, navigate its nodes, or initialize an unused draft.
	var selected: bool = _ui.select_draft(other.owning_skill_id, false)
	var edited: bool = selected and _ui.set_active_draft_skill_description(description)
	var restored: bool = _ui.select_draft(active.owning_skill_id, false)
	var after: Dictionary = _nonactive_draft_states(_ui.active_wip, active.draft_id)
	var key: String = String(other.draft_id)
	before[key].controls.erase("skill_description")
	after[key].controls.erase("skill_description")
	var differences: Array = _nonactive_state_differences(before, after)
	_unrelated_metadata_probe = {"draft_id": key, "slot": String(other.owning_skill_id), "description": description}
	_report.phases.append({"phase": "unrelated_description_edit", "exercised": true,
		"draft_id": key, "selection_accepted": selected, "edit_accepted": edited,
		"active_draft_restored": restored and _ui.call("_get_active_draft") == active,
		"unexpected_differences": differences,
		"unrelated_content_dirty": _ui.call("_draft_has_unsaved_content", other)})
	_write_report()
	if not edited or not restored or _ui.call("_get_active_draft") != active or not differences.is_empty():
		_finish("unrelated_metadata_edit_changed_pose_or_selection"); return false
	return true


func _save_and_reopen() -> bool:
	var draft: Resource = _ui.call("_get_active_draft")
	var expected_controls: Dictionary = _manual_controls(draft)
	var expected_poses: Array = _prepared_snapshots(draft)
	var active_id: StringName = draft.draft_id
	var expected_cache_signature: String = draft.runtime_cache_signature
	var expected_clip: String = _fingerprint(draft.baked_runtime_clip)
	var expected_clip_data: Dictionary = _plain(draft.baked_runtime_clip)
	var nonactive_before: Dictionary = _nonactive_draft_states(_ui.active_wip, active_id)
	var persisted_path: String = _library.save_file_path if FileAccess.file_exists(_library.save_file_path) else _source
	var persisted_before: Resource = ResourceLoader.load(persisted_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if persisted_before == null: _finish("Save_baseline_library_unavailable"); return false
	var nonactive_persisted_before: Dictionary = _nonactive_draft_states(persisted_before.get_saved_wip(_weapon_id), active_id)
	var acquisitions_before: Dictionary = _solve_start_count()
	var started: int = Time.get_ticks_msec()
	_ui.save_button.pressed.emit()
	while _ui.manual_save_in_progress and Time.get_ticks_msec() - started < MAX_PHASE_MS and not _finished:
		await process_frame
	var saved_path: String = _library.save_file_path
	var acquisitions_after: Dictionary = _solve_start_count()
	var active_after: Resource = _ui.call("_get_active_draft")
	var save_trace: Dictionary = _ui.get_meta("last_save_latency_trace", {})
	var row := {"phase": "Save_reload", "wall_ms": Time.get_ticks_msec() - started,
		"dirty": _ui.editor_state_dirty,
		"selected_requires_manual_save": _ui.call("_active_draft_requires_manual_save", active_after),
		"status": _ui.footer_status_label.text,
		"saved_path": saved_path, "save_finished": not _ui.manual_save_in_progress,
		"save_trace": save_trace, "nonactive_before": nonactive_before,
		"nonactive_changes_before_Save": _nonactive_state_differences(nonactive_persisted_before, nonactive_before),
		"nonactive_live_differences_during_Save": _nonactive_state_differences(nonactive_before, _nonactive_draft_states(_ui.active_wip, active_id)),
		"save_acquisition_trace_available": bool(acquisitions_before.available) and bool(acquisitions_after.available),
		"save_acquisitions": int(acquisitions_after.count) - int(acquisitions_before.count),
		"active_cache_retained": active_after.runtime_cache_signature == expected_cache_signature and _fingerprint(active_after.baked_runtime_clip) == expected_clip}
	var render_calls: Array = save_trace.get("render_calls", [])
	row["active_cache_reused"] = render_calls.size() == 1 and StringName(render_calls[0].get("draft_id", "")) == active_id and bool(render_calls[0].get("cached", false)) and bool(render_calls[0].get("skipped", false))
	_report.phases.append(row)
	if _ui.manual_save_in_progress or bool(row.selected_requires_manual_save) or not FileAccess.file_exists(saved_path):
		_finish("Save_failed"); return false
	var reloaded: Resource = ResourceLoader.load(saved_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var weapon: Resource = reloaded.get_saved_wip(_weapon_id) if reloaded != null else null
	var saved_draft: Resource = _find_draft(weapon, _lifecycle_slot)
	if saved_draft == null: _finish("saved_skill_missing"); return false
	row["manual_control_differences"] = _snapshot_diff(expected_controls, _manual_controls(saved_draft), "skill")
	row["prepared_round_trip"] = _prepared_numeric_comparison(expected_poses, _prepared_snapshots(saved_draft))
	row["saved_nodes"] = _node_statuses(saved_draft)
	row["saved_clip_present"] = saved_draft.baked_runtime_clip != null and saved_draft.baked_runtime_clip.has_solved_replay_track()
	var saved_clip_data: Variant = _plain(saved_draft.baked_runtime_clip)
	row["saved_active_cache_signature_matches"] = saved_draft.runtime_cache_signature == expected_cache_signature
	row["saved_active_cache_fingerprint_matches"] = _fingerprint(saved_draft.baked_runtime_clip) == expected_clip
	row["saved_active_cache_values_exact"] = expected_clip_data == saved_clip_data
	# Binary Dictionary hashes include insertion order, which text resources may
	# change. Compare every key and ordered motion sample after loading, using
	# the existing 1e-6 numeric round-trip bound rather than a gameplay tolerance.
	row["saved_active_cache_round_trip"] = _prepared_numeric_comparison(expected_clip_data, saved_clip_data)
	row["saved_active_cache_matches"] = bool(row.saved_active_cache_signature_matches) and bool(row.saved_active_cache_round_trip.valid)
	row["nonactive_persisted_differences"] = _nonactive_state_differences(nonactive_persisted_before, _nonactive_draft_states(weapon, active_id))
	if not _unrelated_metadata_probe.is_empty():
		var unrelated: Resource = _find_draft(_ui.active_wip, StringName(_unrelated_metadata_probe.slot))
		var stored_unrelated: Resource = _find_draft(weapon, StringName(_unrelated_metadata_probe.slot))
		row["unrelated_metadata_retained_in_memory"] = unrelated != null and unrelated.skill_description == _unrelated_metadata_probe.description
		row["unrelated_metadata_not_published"] = stored_unrelated != null and stored_unrelated.skill_description != _unrelated_metadata_probe.description
		row["unrelated_content_still_dirty"] = unrelated != null and bool(_ui.call("_draft_has_unsaved_content", unrelated))
		if not bool(row.unrelated_metadata_retained_in_memory) or not bool(row.unrelated_metadata_not_published) or not bool(row.unrelated_content_still_dirty) or not _ui.editor_state_dirty:
			_finish("Save_lost_or_published_unrelated_metadata_edit"); return false
	_write_report()
	if not row.manual_control_differences.is_empty() or not bool(row.prepared_round_trip.valid) or not bool(row.saved_clip_present):
		_finish("Save_round_trip_failed"); return false
	if not row.nonactive_live_differences_during_Save.is_empty() or not row.nonactive_persisted_differences.is_empty():
		_finish("Save_changed_nonactive_drafts"); return false
	if not bool(row.save_acquisition_trace_available) or int(row.save_acquisitions) != 0 or not bool(row.active_cache_retained) or not bool(row.saved_active_cache_matches) or not bool(row.active_cache_reused):
		_finish("Save_did_not_reuse_only_active_prepared_cache"); return false
	for node: Resource in saved_draft.get_action_motion_node_chain():
		if not _node_current(node): _finish("saved_pose_signature_stale"); return false
	_write_report()
	_ui = null
	_lifecycle_world.queue_free()
	await process_frame
	await process_frame
	_library = reloaded
	_library.save_file_path = saved_path
	if not await _open_lifecycle_station(): _finish("fresh_station_reopen_failed"); return false
	_report["reopened_before_F"] = _node_statuses(_ui.call("_get_active_draft"))
	_write_report()
	return true


func _nonactive_draft_states(weapon: Resource, active_id: StringName) -> Dictionary:
	var result: Dictionary = {}
	if weapon == null or weapon.combat_animation_station_state == null: return result
	var station: Resource = weapon.combat_animation_station_state
	for draft: Resource in (station.skill_drafts as Array) + (station.idle_drafts as Array):
		if draft == null or draft.draft_id == active_id: continue
		result[String(draft.draft_id)] = {"kind": String(draft.draft_kind), "context": String(draft.context_id),
			"controls": _manual_controls(draft), "prepared": _prepared_snapshots(draft),
			"cache_signature": draft.runtime_cache_signature, "cache_fingerprint": _fingerprint(draft.baked_runtime_clip),
			"recording_status": _node_statuses(draft)}
	return result


func _nonactive_state_differences(before: Dictionary, after: Dictionary) -> Array:
	var differences: Array = _snapshot_diff(before, after, "nonactive")
	for key: String in after:
		if not before.has(key): differences.append({"path": "nonactive." + key, "reason": "draft_added"})
	return differences


func _recording_pending() -> bool:
	return bool(_ui.call("is_motion_node_recording_pending"))


func _probe_save_after_failed_preview() -> void:
	var saved_path: String = _library.save_file_path
	var existed_before: bool = FileAccess.file_exists(saved_path)
	var hash_before: String = FileAccess.get_sha256(saved_path) if existed_before else ""
	var started: int = Time.get_ticks_msec()
	var enabled: bool = not _ui.save_button.disabled
	var save_started: bool = false
	if enabled:
		_ui.save_button.pressed.emit()
		save_started = _ui.manual_save_in_progress or _recording_pending()
		while (_ui.manual_save_in_progress or _recording_pending()) and Time.get_ticks_msec() - started < MAX_PHASE_MS and not _finished:
			await process_frame
	var exists_after: bool = FileAccess.file_exists(saved_path)
	var hash_after: String = FileAccess.get_sha256(saved_path) if exists_after else ""
	var unchanged: bool = existed_before == exists_after and hash_before == hash_after
	var trace: Dictionary = _ui.get_meta("last_save_latency_trace", {})
	var rejected: bool = bool(trace.get("aborted", false)) or (not bool(trace.get("persisted", true)) and not String(trace.get("failure_reason", "")).is_empty())
	_report.phases.append({"phase": "Save_after_failed_F", "wall_ms": Time.get_ticks_msec() - started,
		"save_control_enabled": enabled, "save_started": save_started, "save_rejection_observed": enabled and rejected,
		"saved_path": saved_path, "file_existed_before": existed_before, "file_exists_after": exists_after,
		"file_sha256_before": hash_before, "file_sha256_after": hash_after, "file_unchanged": unchanged,
		"dirty_retained": _ui.editor_state_dirty, "save_finished": not _ui.manual_save_in_progress and not _recording_pending(),
		"preservation_guard_passed": enabled and save_started and rejected and unchanged and _ui.editor_state_dirty and not _ui.manual_save_in_progress and not _recording_pending(),
		"status": _ui.footer_status_label.text, "save_trace": trace})
	_write_report()


func _check_failed_save_preserves_library() -> bool:
	if _lifecycle_slot == TARGET_SLOT:
		_finish("failed_Save_case_needs_separate_playable_slot"); return false
	var saved_path: String = _library.save_file_path
	var baseline: Resource = ResourceLoader.load(saved_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var baseline_weapon: Resource = baseline.get_saved_wip(_weapon_id) if baseline != null else null
	var playable: Resource = _find_draft(baseline_weapon, _lifecycle_slot)
	var rejected: Resource = _find_draft(baseline_weapon, TARGET_SLOT)
	if playable == null or playable.baked_runtime_clip == null or not playable.baked_runtime_clip.has_solved_replay_track() or rejected == null:
		_finish("failed_Save_baseline_unavailable"); return false
	var saved_clip_fingerprint: String = _fingerprint(playable.baked_runtime_clip)
	if not _ui.select_skill_slot(TARGET_SLOT, true):
		_finish("failed_Save_target_selection_failed"); return false
	if not await _wait_natural_recording("failed_Save_selected_pose"):
		_finish("failed_Save_selected_pose_unavailable"); return false
	# This fixture retains the previously observed failing authored Skill2.
	# Do not manufacture a failure by corrupting resource fields or snapshots.
	var hash_before: String = FileAccess.get_sha256(saved_path)
	var before_status: Dictionary = _ui.get_prepared_action_pose_status()
	var started: int = Time.get_ticks_msec()
	var button_enabled: bool = not _ui.save_button.disabled
	if not button_enabled: _finish("failed_Save_control_unavailable"); return false
	_ui.save_button.pressed.emit()
	var save_started: bool = _ui.manual_save_in_progress or _recording_pending()
	while (_ui.manual_save_in_progress or _recording_pending()) and Time.get_ticks_msec() - started < MAX_PHASE_MS and not _finished:
		await process_frame
	var hash_after: String = FileAccess.get_sha256(saved_path)
	var reloaded: Resource = ResourceLoader.load(saved_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var saved_weapon: Resource = reloaded.get_saved_wip(_weapon_id) if reloaded != null else null
	var preserved: Resource = _find_draft(saved_weapon, _lifecycle_slot)
	var clip_present: bool = preserved != null and preserved.baked_runtime_clip != null and preserved.baked_runtime_clip.has_solved_replay_track()
	var clip_unchanged: bool = clip_present and _fingerprint(preserved.baked_runtime_clip) == saved_clip_fingerprint
	var save_trace: Dictionary = _ui.get_meta("last_save_latency_trace", {})
	var rejected_save_observed: bool = bool(save_trace.get("aborted", false)) or (not bool(save_trace.get("persisted", true)) and not String(save_trace.get("failure_reason", "")).is_empty())
	var row := {"phase": "failed_Save_preserves_playable_library", "attempted_slot": String(TARGET_SLOT),
		"preserved_playable_slot": String(_lifecycle_slot), "wall_ms": Time.get_ticks_msec() - started,
		"save_started": save_started, "rejected_save_observed": rejected_save_observed,
		"before_pose_status": before_status, "after_pose_status": _ui.get_prepared_action_pose_status(),
		"file_sha256_before": hash_before, "file_sha256_after": hash_after, "file_unchanged": hash_before == hash_after,
		"dirty_retained": _ui.editor_state_dirty, "save_finished": not _ui.manual_save_in_progress and not _recording_pending(),
		"previous_playable_clip_present": clip_present, "previous_playable_clip_unchanged": clip_unchanged,
		"status": _ui.footer_status_label.text, "save_trace": save_trace}
	_report.phases.append(row)
	_write_report()
	if not save_started or not rejected_save_observed or not bool(row.save_finished) or not bool(row.file_unchanged) or not bool(row.dirty_retained) or not clip_unchanged:
		_finish("failed_Save_preservation_check_failed"); return false
	return true


func _node_current(node: Resource) -> bool:
	return node != null and node.prepared_pose_signature == PreparedPoseContract.node_pose_signature(node) and bool(PreparedPoseContract.validate(node.prepared_pose).get("valid", false))


func _node_statuses(draft: Resource) -> Array:
	var result: Array = []
	if draft == null: return result
	var index: int = 1
	for node: Resource in draft.get_action_motion_node_chain():
		result.append({"visible_node": index, "current": _node_current(node),
			"stored_signature": node.prepared_pose_signature, "current_signature": PreparedPoseContract.node_pose_signature(node),
			"schema_validation": PreparedPoseContract.validate(node.prepared_pose)})
		index += 1
	return result


func _write_report() -> void:
	if not _output.is_empty(): _write_json("pose_recording_lifecycle.json", _report)


func _write_working_draft_artifact(name: String) -> void:
	if _output.is_empty() or _ui == null or not is_instance_valid(_ui): return
	var draft: Resource = _ui.call("_get_active_draft")
	if draft == null: return
	var path: String = _output.path_join(name)
	# Observational diagnostic resource only. This does not publish the library,
	# prepare a pose, or alter the editor's authored/captured fields.
	var error: int = ResourceSaver.save(draft, path)
	if not _report.has("working_draft_artifacts"): _report["working_draft_artifacts"] = []
	_report.working_draft_artifacts.append({"path": path, "saved": error == OK, "error": error,
		"slot": String(draft.owning_skill_id), "selected_node": _ui.get_selected_motion_node_index()})


func _finish(reason: String) -> void:
	if _finished: return
	_finished = true
	var source_unchanged: bool = not _source.is_empty() and FileAccess.get_sha256(_source) == _source_hash
	_report.merge({"complete": true, "reason": reason, "wall_ms": Time.get_ticks_msec() - _started,
		"ok": reason == "finished" and source_unchanged, "source_file_unchanged": source_unchanged}, true)
	if _ui != null and is_instance_valid(_ui):
		_report["last_status"] = _ui.footer_status_label.text
		_report["last_selected_node"] = _ui.get_selected_motion_node_index()
		_report["last_capture"] = _ui.get_meta("last_prepared_pose_capture", {})
		_report["last_baseline_preparation"] = _ui.get_meta("last_baseline_preparation", {})
		_report["last_node_statuses"] = _node_statuses(_ui.call("_get_active_draft"))
		_write_working_draft_artifact("working_draft.tres")
		if _ui.preview_prepare_in_progress: _ui.call("_cancel_preview_preparation")
		if _ui.chain_player.is_playing(): _action(CombatAnimationStationUI.ACTION_PREVIEW_PLAYBACK)
	_write_report()
	print("POSE_LIFECYCLE finished ", reason)
	quit(0 if bool(_report.ok) else 1)
