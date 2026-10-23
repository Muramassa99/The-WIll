extends "res://tools/diagnose_skill_save_latency.gd"

## Inherits the real station and all workspace/source/output isolation guards.
## Use the parent's required environment and --cases=short. --long=false omits
## the 20-node cases. --skip-short=true starts directly with the 20-node fixture.
## No library write is requested until the final Save step.
## --lifecycle=true adds post-Save Reacquire and two final-wait Save edit races.
## Sampling-stage cancellation runs with the long fixture; --sampling-cancel
## explicitly enables/disables that check independently of --long.
## Full comparisons deliberately use the same retained initial solver seed.
const Incremental = preload("res://core/resolvers/combat_runtime_clip_incremental_resolver.gd")
const RenderCheckpoint = preload("res://runtime/combat/combat_animation_render_checkpoint.gd")
const PREPARE_TIMEOUT_MS := 240000

var _replay_row: Dictionary = {}
var _initial_output_hash := ""
var _previous_clip: CombatRuntimeClip
var _save_race_target_phase := ""
var _save_race_observation: Dictionary = {}

func _run_case(label: String, _visible_count: int, _duration: float, _mode: String) -> bool:
	if label != "short" or String(_options.get("cases", "")) != "short":
		_report["failure"] = "incremental_harness_requires_cases_short"
		return false
	_report["scope"] = "isolated actual station unsaved F, incremental/full equality, cancellation, Save/reload; no visual or full-hand certification"
	_replay_row = {"case": "incremental_replay", "complete": false, "ok": false, "steps": []}
	_initial_output_hash = _hash_or_missing(String(_library.save_file_path))
	_replay_row["initial_output_sha256"] = _initial_output_hash
	var fixture: Dictionary = {}
	var ready: Dictionary = {}
	if String(_options.get("skip-short", "false")) != "true":
		fixture = await _build_chain(3, 3.0)
		_replay_row["short_fixture"] = fixture
		if not bool(fixture.get("ok", false)): return _end_replay_case("short_fixture_failed")
		ready = await _wait_ready(0.0)
		_replay_row["short_readiness"] = ready
		if not bool(ready.get("ready", false)): return _end_replay_case("short_grip_not_ready")
		if not await _prepare_and_check("short_unsaved_first", false, true): return _end_replay_case("short_unsaved_first_failed")
		if not await _check_cached_f(): return _end_replay_case("cached_F_failed")
		if not _append_last(): return _end_replay_case("short_R_append_failed")
		if not await _prepare_and_check("short_append", true, true): return _end_replay_case("short_append_failed")
		if not _edit_last_pommel(-0.004): return _end_replay_case("short_latest_edit_failed")
		if not await _prepare_and_check("short_latest_edit", true, true): return _end_replay_case("short_latest_prepare_failed")
	elif String(_options.get("long", "true")) == "false":
		return _end_replay_case("skip_short_requires_long_fixture")
	if String(_options.get("long", "true")) != "false":
		fixture = await _build_chain(20, 20.0)
		_replay_row["long_fixture"] = fixture
		if not bool(fixture.get("ok", false)): return _end_replay_case("long_fixture_failed")
		ready = await _wait_ready(0.0)
		_replay_row["long_readiness"] = ready
		if not bool(ready.get("ready", false)): return _end_replay_case("long_grip_not_ready")
		if not await _prepare_and_check("twenty_prime", false, false): return _end_replay_case("twenty_prime_failed")
		if not _append_last(): return _end_replay_case("twenty_R_append_failed")
		if not await _prepare_and_check("twenty_append", true, true): return _end_replay_case("twenty_append_failed")
		if not _edit_last_pommel(-0.004): return _end_replay_case("twenty_latest_edit_failed")
		if not await _prepare_and_check("twenty_latest_edit", true, true): return _end_replay_case("twenty_latest_prepare_failed")
	var draft: Resource = _ui.call("_get_active_draft")
	_ui.select_motion_node(draft.motion_node_chain.size() - 1)
	if not _ui.remove_selected_motion_node(): return _end_replay_case("delete_last_failed")
	if not await _prepare_and_check("delete_last", true, true): return _end_replay_case("delete_prepare_failed")
	if String(_options.get("sampling-cancel", _options.get("long", "true"))) == "true":
		if not await _check_cancel_and_camera("sampling"): return _end_replay_case("sampling_cancel_camera_failed")
	draft = _ui.call("_get_active_draft")
	_ui.select_motion_node(draft.motion_node_chain.size() - 1)
	if not _ui.set_selected_motion_node_transition_duration(0.837, false): return _end_replay_case("duration_edit_failed")
	if not await _prepare_and_check("off_grid_duration_edit", true, true): return _end_replay_case("duration_prepare_failed")
	if not await _check_cancel_and_camera(): return _end_replay_case("cancel_camera_failed")
	if not await _prepare_and_check("after_cancel", true, true): return _end_replay_case("after_cancel_failed")
	if String(_options.get("long", "true")) != "false":
		if not await _check_middle_edit_delete_reinsert(): return _end_replay_case("middle_edit_delete_reinsert_failed")
	if not await _check_save_reload(): return _end_replay_case("save_reload_failed")
	return _end_replay_case("")

func _append_last() -> bool:
	var draft: Resource = _ui.call("_get_active_draft")
	var before_count: int = draft.motion_node_chain.size()
	var before_last: Resource = draft.motion_node_chain.back()
	var row: Dictionary = {"step": "R_append", "raw_nodes_before": before_count,
		"selected_before": draft.selected_motion_node_index, "previous_last_id": String(before_last.node_id)}
	row["selection_accepted"] = _ui.select_motion_node(before_count - 1)
	row["insertion_accepted"] = bool(row.selection_accepted) and _ui.insert_motion_node_after_selection()
	row["raw_nodes_after"] = draft.motion_node_chain.size()
	row["selected_after"] = draft.selected_motion_node_index
	var appended: Resource = draft.motion_node_chain.back()
	row["appended_id"] = String(appended.node_id)
	row["appended_duration"] = appended.transition_duration_seconds
	row["appended_pommel"] = appended.pommel_position_local
	row["appended_tip"] = appended.tip_position_local
	row["persistence"] = _unsaved_persistence_check()
	# R itself supplies a valid duplicate pose. Moving that duplicate is a
	# separate authoring test; a reach rejection cannot invalidate insertion.
	row["ok"] = bool(row.insertion_accepted) and int(row.raw_nodes_after) == before_count + 1 \
		and int(row.selected_after) == before_count and appended.node_id != before_last.node_id and bool(row.persistence.ok)
	_record_replay_step(row)
	return bool(row.ok)

func _check_middle_edit_delete_reinsert() -> bool:
	var draft: Resource = _ui.call("_get_active_draft")
	var raw_count: int = draft.motion_node_chain.size()
	var visible_count: int = int(_ui.call("_get_user_visible_motion_node_count", draft))
	var middle_index: int = clampi(int(raw_count / 2.0), 1, raw_count - 2)
	var middle: CombatAnimationMotionNode = draft.motion_node_chain[middle_index] as CombatAnimationMotionNode
	var terminal: Resource = draft.motion_node_chain.back()
	var original_duration: float = middle.transition_duration_seconds
	var requested_duration: float = original_duration + 0.137
	var row: Dictionary = {"step": "middle_duration_edit", "middle_index": middle_index,
		"node_id": String(middle.node_id), "raw_nodes_before": raw_count, "visible_nodes_before": visible_count,
		"duration_before": original_duration, "requested_duration": requested_duration}
	row["selection_accepted"] = _ui.select_motion_node(middle_index)
	row["edit_accepted"] = bool(row.selection_accepted) and _ui.set_selected_motion_node_transition_duration(requested_duration, false)
	row["duration_after"] = middle.transition_duration_seconds
	row["persistence"] = _unsaved_persistence_check()
	row["ok"] = visible_count == 20 and middle_index > 1 and middle_index < raw_count - 1 \
		and bool(row.edit_accepted) and middle.transition_duration_seconds == requested_duration \
		and draft.motion_node_chain.size() == raw_count and bool(row.persistence.ok)
	_record_replay_step(row)
	if not bool(row.ok): return false
	if not await _prepare_and_check("twenty_middle_duration_edit", true, true): return false

	row = {"step": "middle_delete", "middle_index": middle_index, "removed_node_id": String(middle.node_id),
		"raw_nodes_before": draft.motion_node_chain.size()}
	row["selection_accepted"] = _ui.select_motion_node(middle_index)
	row["delete_accepted"] = bool(row.selection_accepted) and _ui.remove_selected_motion_node()
	row["removed_resource_absent"] = not draft.motion_node_chain.has(middle)
	row["raw_nodes_after"] = draft.motion_node_chain.size()
	row["visible_nodes_after"] = _ui.call("_get_user_visible_motion_node_count", draft)
	row["terminal_retained"] = draft.motion_node_chain.back() == terminal
	row["persistence"] = _unsaved_persistence_check()
	row["ok"] = bool(row.delete_accepted) and bool(row.removed_resource_absent) \
		and int(row.raw_nodes_after) == raw_count - 1 and int(row.visible_nodes_after) == visible_count - 1 \
		and bool(row.terminal_retained) and bool(row.persistence.ok)
	_record_replay_step(row)
	if not bool(row.ok): return false
	if not await _prepare_and_check("nineteen_middle_delete", true, true): return false

	# Restore only the visible-node count through ordinary R insertion. The UI
	# supplies its duplicate pose and default duration; no deleted pose is forced.
	row = {"step": "middle_R_reinsert", "insert_after_index": middle_index - 1,
		"raw_nodes_before": draft.motion_node_chain.size()}
	row["selection_accepted"] = _ui.select_motion_node(middle_index - 1)
	row["insertion_accepted"] = bool(row.selection_accepted) and _ui.insert_motion_node_after_selection()
	row["raw_nodes_after"] = draft.motion_node_chain.size()
	row["visible_nodes_after"] = _ui.call("_get_user_visible_motion_node_count", draft)
	row["selected_after"] = draft.selected_motion_node_index
	row["terminal_retained"] = draft.motion_node_chain.back() == terminal
	row["persistence"] = _unsaved_persistence_check()
	row["ok"] = bool(row.insertion_accepted) and int(row.raw_nodes_after) == raw_count \
		and int(row.visible_nodes_after) == 20 and int(row.selected_after) == middle_index \
		and bool(row.terminal_retained) and bool(row.persistence.ok)
	_record_replay_step(row)
	if not bool(row.ok): return false
	return await _prepare_and_check("twenty_middle_R_reinsert", true, true)

func _edit_last_pommel(distance: float) -> bool:
	var draft: Resource = _ui.call("_get_active_draft")
	var row: Dictionary = {"step": "edit_last_pommel", "attempts": [], "ok": false}
	row["selection_accepted"] = _ui.select_motion_node(draft.motion_node_chain.size() - 1)
	var motion: CombatAnimationMotionNode = _ui.call("_get_active_motion_node")
	if not bool(row.selection_accepted) or motion == null:
		row["reason"] = "terminal_selection_failed"
		_record_replay_step(row)
		return false
	var initial_pommel: Vector3 = motion.pommel_position_local
	var initial_tip: Vector3 = motion.tip_position_local
	var direction: Vector3 = (motion.tip_position_local - motion.pommel_position_local).normalized()
	var targets: Array[Dictionary] = [
		{"source": "requested_small_axis_edit", "position": initial_pommel + direction * distance},
		{"source": "opposite_small_axis_edit", "position": initial_pommel - direction * distance},
	]
	# The thrust fixture ends at an extension boundary. Earlier authored
	# positions are useful fallback requests, still resolved by the public UI.
	for index: int in range(draft.motion_node_chain.size() - 2, 0, -1):
		var previous: CombatAnimationMotionNode = draft.motion_node_chain[index] as CombatAnimationMotionNode
		if previous != null and previous.primary_hand_slot == motion.primary_hand_slot \
			and previous.preferred_grip_style_mode == motion.preferred_grip_style_mode \
			and previous.pommel_position_local.distance_to(initial_pommel) > 0.000001:
			targets.append({"source": "previous_authored_node_%d" % index, "position": previous.pommel_position_local})
	for target: Dictionary in targets:
		var accepted: bool = _ui.set_selected_motion_node_pommel_position(target.position, false)
		var pommel_delta: float = initial_pommel.distance_to(motion.pommel_position_local)
		var tip_delta: float = initial_tip.distance_to(motion.tip_position_local)
		(row.attempts as Array).append({"source": target.source, "requested_pommel": target.position,
			"setter_accepted": accepted, "authored_pommel": motion.pommel_position_local,
			"authored_tip": motion.tip_position_local, "pommel_delta_m": pommel_delta,
			"tip_delta_m": tip_delta, "message": _ui.footer_status_label.text})
		if accepted and maxf(pommel_delta, tip_delta) > 0.000001:
			row["ok"] = true
			row["accepted_request_source"] = target.source
			break
	row["reason"] = "" if bool(row.ok) else "all_public_pommel_requests_rejected_or_unchanged"
	row["persistence"] = _unsaved_persistence_check()
	row["ok"] = bool(row.ok) and bool(row.persistence.ok)
	_record_replay_step(row)
	return bool(row.ok)

func _prepare_and_check(label: String, require_reuse: bool, compare_full: bool) -> bool:
	var draft: Resource = _ui.call("_get_active_draft")
	var row: Dictionary = {"step": label, "visible_nodes": _ui.call("_get_user_visible_motion_node_count", draft),
		"selected_node_index": draft.selected_motion_node_index, "dirty_before": _ui.editor_state_dirty,
		"context_before": _ui.call("_build_runtime_pose_bake_context_key", draft),
		"previous_context": _render_cache(_previous_clip).get("context_key", "")}
	if _ui.has_meta("last_preview_prepare_result"): _ui.remove_meta("last_preview_prepare_result")
	if _ui.has_meta("last_preview_prepare_progress"): _ui.remove_meta("last_preview_prepare_progress")
	_begin_replay_measurement()
	var started := Time.get_ticks_usec()
	_ui.call("_toggle_preview_playback")
	row["busy_after_F"] = _ui.preview_prepare_in_progress
	row["repeated_busy_F_ignored"] = true
	if _ui.preview_prepare_in_progress:
		var generation: int = _ui.preview_prepare_generation
		_ui.call("_toggle_preview_playback")
		row["repeated_busy_F_ignored"] = _ui.preview_prepare_in_progress and generation == _ui.preview_prepare_generation
	while _ui.preview_prepare_in_progress and Time.get_ticks_usec() - started < PREPARE_TIMEOUT_MS * 1000:
		await process_frame
	_end_replay_measurement(row, started)
	row["prepare_result"] = (_ui.get_meta("last_preview_prepare_result", {}) as Dictionary).duplicate(true)
	row["progress"] = (_ui.get_meta("last_preview_prepare_progress", {}) as Dictionary).duplicate(true)
	row["playing"] = _ui.chain_player.is_playing()
	row["dirty_after"] = _ui.editor_state_dirty
	var clip: CombatRuntimeClip = draft.get("baked_runtime_clip") as CombatRuntimeClip
	row["frame_count"] = clip.get_frame_count() if clip != null else 0
	row["solved_track"] = clip != null and clip.has_solved_replay_track()
	row["matching_input_prefix"] = Incremental.matching_prefix_count(_previous_clip, clip)
	row["terminal"] = _terminal_check(draft, clip)
	row["context_after"] = _ui.call("_build_runtime_pose_bake_context_key", draft)
	row["cached_context"] = _render_cache(clip).get("context_key", "")
	await process_frame
	var preview_root: Node = _ui.call("_get_preview_root")
	row["solved_fast_path"] = preview_root != null and bool(preview_root.get_meta("preview_runtime_solved_replay_fast_path_active", false))
	_stop_replay()
	row["persistence"] = _unsaved_persistence_check()
	var result: Dictionary = row.prepare_result
	var reused: int = int(result.get("reused_frames", 0))
	row["ok"] = not _ui.preview_prepare_in_progress and bool(row.playing) and bool(row.solved_track) \
		and bool(row.solved_fast_path) and bool(row.dirty_before) and bool(row.dirty_after) \
		and bool(row.persistence.ok) and bool(row.terminal.ok) and bool(result.get("cached", false)) \
		and bool(row.repeated_busy_F_ignored) and (not require_reuse or reused > 0) and reused <= int(row.matching_input_prefix)
	if bool(row.ok) and compare_full:
		row["full_comparison"] = await _compare_forced_full(clip)
		row["ok"] = bool(row.full_comparison.ok)
	_previous_clip = draft.get("baked_runtime_clip") as CombatRuntimeClip
	_record_replay_step(row)
	return bool(row.ok)

func _check_cached_f() -> bool:
	var draft: Resource = _ui.call("_get_active_draft")
	var before: Resource = draft.get("baked_runtime_clip")
	var generation: int = _ui.preview_prepare_generation
	var started := Time.get_ticks_usec()
	_ui.call("_toggle_preview_playback")
	var row: Dictionary = {"step": "repeat_cached_F", "request_ms": (Time.get_ticks_usec() - started) / 1000.0,
		"playing_immediately": _ui.chain_player.is_playing(), "preparing": _ui.preview_prepare_in_progress,
		"same_clip": before == draft.get("baked_runtime_clip"), "same_generation": generation == _ui.preview_prepare_generation}
	await process_frame
	_stop_replay()
	row["persistence"] = _unsaved_persistence_check()
	row["ok"] = bool(row.playing_immediately) and not bool(row.preparing) and bool(row.same_clip) \
		and bool(row.same_generation) and bool(row.persistence.ok)
	_record_replay_step(row)
	return bool(row.ok)

func _compare_forced_full(incremental_clip: CombatRuntimeClip) -> Dictionary:
	var before: CombatRuntimeClip = incremental_clip.duplicate_clip()
	var cache_before: Dictionary = _render_cache(incremental_clip)
	var seed_before: Dictionary = cache_before.get("seed", {})
	var context_before: String = String(cache_before.get("context_key", ""))
	# F-stop intentionally leaves the last replay pose visible. Return through
	# the ordinary selection path before invoking this synchronous diagnostic
	# rebuild, so leaving playback cannot enqueue grip work inside seed capture.
	var draft: Resource = _ui.call("_get_active_draft")
	var selection_refreshed: bool = _ui.select_motion_node(int(draft.selected_motion_node_index))
	var readiness: Dictionary = await _wait_ready(0.0)
	var seed_restorable: bool = RenderCheckpoint.can_restore(seed_before)
	var editor_before: Dictionary = _comparison_editor_state()
	var camera_before: Dictionary = _ui.preview_presenter.capture_camera_state(_ui.preview_subviewport)
	var preview_state: Dictionary = _ui.preview_presenter.call("_ensure_preview_nodes", _ui.preview_view_container, _ui.preview_subviewport)
	_ui.preview_presenter.restore_camera_state(_ui.preview_subviewport, camera_before)
	var editor_checkpoint: Dictionary = RenderCheckpoint.capture(_ui.preview_presenter, preview_state)
	if not selection_refreshed or not bool(readiness.get("ready", false)) or not seed_restorable or editor_before.is_empty() or editor_checkpoint.is_empty():
		return {"ok": false, "reason": "full_comparison_editor_not_ready", "readiness": readiness,
			"selection_refreshed": selection_refreshed, "seed_restorable": seed_restorable,
			"editor_checkpoint_available": not editor_checkpoint.is_empty(), "persistence": _unsaved_persistence_check()}
	_ui.preview_presenter.set_meta("force_full_pose_render", true)
	_ui.call("_mark_active_draft_runtime_clip_cache_dirty")
	var started := Time.get_ticks_usec()
	var result: Dictionary = _ui.call("_refresh_active_draft_runtime_clip_cache")
	_ui.preview_presenter.remove_meta("force_full_pose_render")
	# The synchronous Save worker retains its terminal solver state for the
	# subsequent idle render. Its outer caller owns restoring the editor.
	var outer_restore_ok: bool = RenderCheckpoint.restore(_ui.preview_presenter, editor_checkpoint)
	var camera_restore_ok: bool = _ui.preview_presenter.restore_camera_state(_ui.preview_subviewport, camera_before)
	draft = _ui.call("_get_active_draft")
	var full: CombatRuntimeClip = draft.get("baked_runtime_clip") as CombatRuntimeClip
	var cache_after: Dictionary = _render_cache(full)
	var comparison: Dictionary = _compare_clips(before, full)
	var editor_after: Dictionary = _comparison_editor_state()
	var camera_comparison: Dictionary = _compare_camera_states(editor_before.get("camera", {}), editor_after.get("camera", {}))
	var changed_editor_parts: Array[String] = []
	for part: String in editor_before:
		if part == "camera":
			if not bool(camera_comparison.ok): changed_editor_parts.append(part)
			continue
		if not editor_after.has(part) or editor_before[part] != editor_after[part]: changed_editor_parts.append(part)
	comparison.merge({"wall_ms": (Time.get_ticks_usec() - started) / 1000.0, "result": result,
		"same_context": not context_before.is_empty() and context_before == String(cache_after.get("context_key", "")),
		"same_seed": not seed_before.is_empty() and seed_before == cache_after.get("seed", {}),
		"readiness": readiness, "seed_restorable_before": seed_restorable,
		"outer_restore_ok": outer_restore_ok,
		"camera_restore_ok": camera_restore_ok,
		"camera_comparison": camera_comparison,
		"editor_restored": outer_restore_ok and camera_restore_ok and not editor_after.is_empty() and changed_editor_parts.is_empty(),
		"changed_editor_parts": changed_editor_parts,
		"persistence": _unsaved_persistence_check()})
	comparison["ok"] = bool(comparison.ok) and bool(comparison.same_context) and bool(comparison.same_seed) \
		and bool(result.get("cached", false)) and int(result.get("reused_frames", -1)) == 0 \
		and full != null and int(result.get("processed_frames", -1)) == full.get_frame_count() \
		and bool(comparison.persistence.ok) and bool(comparison.editor_restored)
	return comparison

func _comparison_editor_state() -> Dictionary:
	var context: Dictionary = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
	if context.is_empty(): return {}
	var actor: Node = context.actor
	var owner: Node = actor.get_node_or_null("PreparedGripAcquisition")
	if owner == null: return {}
	var rig: Dictionary = actor.call("capture_render_checkpoint")
	var grip: Dictionary = owner.call("capture_render_checkpoint")
	if rig.is_empty() or grip.is_empty(): return {}
	return {"rig": rig, "grip": grip, "camera": _ui.preview_presenter.capture_camera_state(_ui.preview_subviewport),
		"authored_chain": _authored_chain_values(_ui.call("_get_active_draft"))}

func _check_cancel_and_camera(stage: String = "pose") -> bool:
	var draft: Resource = _ui.call("_get_active_draft")
	var before_count: int = draft.motion_node_chain.size()
	_ui.select_motion_node(draft.motion_node_chain.size() - 1)
	var motion: CombatAnimationMotionNode = _ui.call("_get_active_motion_node")
	var original_duration: float = motion.transition_duration_seconds
	var requested_duration: float = original_duration + 0.127 if stage == "sampling" else 1.139
	var cancel_duration: float = original_duration if stage == "sampling" else 0.913
	if not _ui.set_selected_motion_node_transition_duration(requested_duration, false): return false
	if _ui.has_meta("last_preview_prepare_progress"): _ui.remove_meta("last_preview_prepare_progress")
	_ui.call("_toggle_preview_playback")
	var started := Time.get_ticks_msec()
	while _ui.preview_prepare_in_progress and Time.get_ticks_msec() - started < PREPARE_TIMEOUT_MS:
		var progress: Dictionary = _ui.get_meta("last_preview_prepare_progress", {})
		var completed: int = int(progress.get("sampled_frames", 0)) if stage == "sampling" else int(progress.get("processed_frames", 0))
		if String(progress.get("stage", "")) == stage and completed > 0 and not bool(progress.get("done", false)): break
		await process_frame
	var row: Dictionary = {"step": "cancel_sampling_camera" if stage == "sampling" else "cancel_busy_camera",
		"requested_stage": stage, "busy_before": _ui.preview_prepare_in_progress,
		"progress_before": (_ui.get_meta("last_preview_prepare_progress", {}) as Dictionary).duplicate(true)}
	var observed_frames: int = int(row.progress_before.get("sampled_frames", 0)) if stage == "sampling" else int(row.progress_before.get("processed_frames", 0))
	row["requested_stage_observed"] = String(row.progress_before.get("stage", "")) == stage \
		and observed_frames > 0 and not bool(row.progress_before.get("done", false))
	var before: Dictionary = _ui.preview_presenter.capture_camera_state(_ui.preview_subviewport)
	row["orbit_accepted"] = _ui.orbit_preview_camera(Vector2(27.0, -9.0))
	var requested: Dictionary = _ui.preview_presenter.capture_camera_state(_ui.preview_subviewport)
	row["orbit_changed"] = before != requested
	await process_frame
	row["camera_during_step"] = _compare_camera_states(requested, _ui.preview_presenter.capture_camera_state(_ui.preview_subviewport))
	row["camera_preserved_during_step"] = bool(row.camera_during_step.ok)
	row["busy_at_cancel"] = _ui.preview_prepare_in_progress
	row["progress_at_cancel"] = (_ui.get_meta("last_preview_prepare_progress", {}) as Dictionary).duplicate(true)
	row["cancelled_during_requested_stage"] = String(row.progress_at_cancel.get("stage", "")) == stage and not bool(row.progress_at_cancel.get("done", false))
	row["no_partial_cache_during_step"] = draft.get("baked_runtime_clip") == null
	var generation: int = _ui.preview_prepare_generation
	row["edit_accepted"] = _ui.set_selected_motion_node_transition_duration(cancel_duration, false)
	for _index: int in 3: await process_frame
	row["result"] = (_ui.get_meta("last_preview_prepare_result", {}) as Dictionary).duplicate(true)
	row["cancelled"] = not _ui.preview_prepare_in_progress and _ui.preview_prepare_job == null \
		and _ui.preview_prepare_generation > generation and bool(row.result.get("cancelled", false))
	row["no_late_playback"] = not _ui.chain_player.is_playing()
	row["no_partial_cache"] = draft.get("baked_runtime_clip") == null
	row["node_count_preserved"] = draft.motion_node_chain.size() == before_count
	row["duration_after_cancel"] = motion.transition_duration_seconds
	row["expected_duration_after_cancel"] = cancel_duration
	row["camera_after_cancel"] = _compare_camera_states(requested, _ui.preview_presenter.capture_camera_state(_ui.preview_subviewport))
	row["camera_preserved_after_cancel"] = bool(row.camera_after_cancel.ok)
	row["persistence"] = _unsaved_persistence_check()
	row["ok"] = bool(row.busy_before) and bool(row.busy_at_cancel) and bool(row.orbit_accepted) \
		and bool(row.requested_stage_observed) and bool(row.cancelled_during_requested_stage) and bool(row.node_count_preserved) \
		and bool(row.orbit_changed) and bool(row.camera_preserved_during_step) and bool(row.edit_accepted) \
		and bool(row.cancelled) and bool(row.no_late_playback) and bool(row.no_partial_cache_during_step) and bool(row.no_partial_cache) \
		and float(row.duration_after_cancel) == cancel_duration and bool(row.camera_preserved_after_cancel) and bool(row.persistence.ok)
	_stop_replay()
	_record_replay_step(row)
	return bool(row.ok)

func _check_save_reload() -> bool:
	var draft: Resource = _ui.call("_get_active_draft")
	var draft_id: StringName = draft.draft_id
	var clip_before: CombatRuntimeClip = draft.get("baked_runtime_clip") as CombatRuntimeClip
	var expected_clip: CombatRuntimeClip = clip_before.duplicate_clip() if clip_before != null else null
	var chain_before: Array = _authored_chain_values(draft)
	var row: Dictionary = {"step": "explicit_Save_and_reload", "before": _unsaved_persistence_check()}
	var combat_idle: Resource = _ui.call("_get_existing_combat_idle_draft")
	if combat_idle == null or expected_clip == null:
		row.merge({"ok": false, "reason": "missing_active_clip_or_existing_combat_idle"})
		_record_replay_step(row)
		return false
	var idle_chain_before: Array = _authored_chain_values(combat_idle)
	var generation_before: int = _ui.preview_prepare_generation
	_ui.call("_toggle_preview_playback")
	row["cached_F_started"] = _ui.chain_player.is_playing() and not _ui.preview_prepare_in_progress \
		and generation_before == _ui.preview_prepare_generation and clip_before == draft.get("baked_runtime_clip")
	await process_frame
	var preview_root: Node = _ui.call("_get_preview_root")
	row["F_solved_fast_path"] = preview_root != null and bool(preview_root.get_meta("preview_runtime_solved_replay_fast_path_active", false))
	_stop_replay()
	# Reproduce the actual first-Save lifecycle: the F consumer has cleared
	# authoring ownership, active replay is cached, and combat idle needs work.
	# No reselect, readiness wait, or diagnostic checkpoint restore may mask it.
	_ui.call("_mark_draft_runtime_clip_cache_dirty", combat_idle)
	row["active_cache_retained_before_Save"] = clip_before == draft.get("baked_runtime_clip")
	row["combat_idle_uncached_before_Save"] = combat_idle.get("baked_runtime_clip") == null
	row["authored_unchanged_before_Save"] = chain_before == _authored_chain_values(draft) and idle_chain_before == _authored_chain_values(combat_idle)
	row["stopped_before_Save"] = not _ui.chain_player.is_playing() and not _ui.preview_prepare_in_progress
	row["before_Save_persistence"] = _unsaved_persistence_check()
	var save_fixture_ok: bool = bool(row.cached_F_started) and bool(row.F_solved_fast_path) \
		and bool(row.active_cache_retained_before_Save) and bool(row.combat_idle_uncached_before_Save) \
		and bool(row.authored_unchanged_before_Save) and bool(row.stopped_before_Save) and bool(row.before_Save_persistence.ok)
	if not save_fixture_ok:
		row.merge({"ok": false, "reason": "cached_F_stop_Save_fixture_failed"})
		_record_replay_step(row)
		return false
	_begin_replay_measurement()
	var started := Time.get_ticks_usec()
	await _ui._manual_save_active_editor_state()
	_end_replay_measurement(row, started)
	row["save_message"] = _ui.footer_status_label.text
	row["output_sha256"] = _hash_or_missing(String(_library.save_file_path))
	row["source_unchanged"] = FileAccess.get_sha256(_source) == _source_hash
	row["dirty_cleared"] = not _ui.editor_state_dirty
	row["no_auto_playback"] = not _ui.chain_player.is_playing()
	draft = _ui.call("_get_active_draft")
	combat_idle = _ui.call("_get_existing_combat_idle_draft")
	var active_after: CombatRuntimeClip = draft.get("baked_runtime_clip") as CombatRuntimeClip
	var idle_after: CombatRuntimeClip = combat_idle.get("baked_runtime_clip") as CombatRuntimeClip if combat_idle != null else null
	row["active_clip_same_resource"] = active_after == clip_before
	row["active_clip_preservation"] = _compare_clips(expected_clip, active_after)
	row["idle_prepared"] = idle_after != null and idle_after.has_solved_replay_track()
	row["save_trace"] = (_ui.get_meta("last_save_latency_trace", {}) as Dictionary).duplicate(true)
	var active_chain_after: Array = _authored_chain_values(draft)
	var idle_chain_after: Array = _authored_chain_values(combat_idle) if combat_idle != null else []
	var persisted_active_chain: Array = []
	var persisted_idle_chain: Array = []
	var persisted_wip: Resource = _library.get_saved_wip(_weapon_id)
	if persisted_wip != null:
		for candidate: Resource in persisted_wip.combat_animation_station_state.skill_drafts:
			if candidate.draft_id == draft_id:
				persisted_active_chain = _authored_chain_values(candidate)
				break
		for candidate: Resource in persisted_wip.combat_animation_station_state.idle_drafts:
			if candidate.context_id == CombatAnimationDraft.IDLE_CONTEXT_COMBAT:
				persisted_idle_chain = _authored_chain_values(candidate)
				break
	var saved: Resource
	row["output_file_exists"] = FileAccess.file_exists(String(_library.save_file_path))
	if bool(row.output_file_exists):
		saved = ResourceLoader.load(_library.save_file_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	else:
		row["reload_failure"] = "output_library_missing_after_Save"
	var saved_draft: Resource
	var saved_idle: Resource
	if saved != null:
		var wip: Resource = saved.get_saved_wip(_weapon_id)
		if wip != null:
			for candidate: Resource in wip.combat_animation_station_state.skill_drafts:
				if candidate.draft_id == draft_id:
					saved_draft = candidate
					break
			for candidate: Resource in wip.combat_animation_station_state.idle_drafts:
				if candidate.context_id == CombatAnimationDraft.IDLE_CONTEXT_COMBAT:
					saved_idle = candidate
					break
	row["reload_comparison"] = _compare_clips(expected_clip, saved_draft.get("baked_runtime_clip") as CombatRuntimeClip if saved_draft != null else null)
	row["idle_reload_comparison"] = _compare_clips(idle_after, saved_idle.get("baked_runtime_clip") as CombatRuntimeClip if saved_idle != null else null)
	row["authored_chain_equal"] = saved_draft != null and chain_before == _authored_chain_values(saved_draft)
	row["idle_authored_chain_equal"] = combat_idle != null and saved_idle != null \
		and idle_chain_before == _authored_chain_values(combat_idle) and idle_chain_before == _authored_chain_values(saved_idle)
	var active_chain_reloaded: Array = _authored_chain_values(saved_draft) if saved_draft != null else []
	var idle_chain_reloaded: Array = _authored_chain_values(saved_idle) if saved_idle != null else []
	row["authored_chain_differences"] = {
		"before_to_live": _compare_authored_values(chain_before, active_chain_after),
		"before_to_reloaded": _compare_authored_values(chain_before, active_chain_reloaded),
		"live_to_reloaded": _compare_authored_values(active_chain_after, active_chain_reloaded),
		"live_to_persisted_clone": _compare_authored_values(active_chain_after, persisted_active_chain),
		"persisted_clone_to_reloaded": _compare_authored_values(persisted_active_chain, active_chain_reloaded),
	}
	row["idle_authored_chain_differences"] = {
		"before_to_live": _compare_authored_values(idle_chain_before, idle_chain_after),
		"before_to_reloaded": _compare_authored_values(idle_chain_before, idle_chain_reloaded),
		"live_to_reloaded": _compare_authored_values(idle_chain_after, idle_chain_reloaded),
		"live_to_persisted_clone": _compare_authored_values(idle_chain_after, persisted_idle_chain),
		"persisted_clone_to_reloaded": _compare_authored_values(persisted_idle_chain, idle_chain_reloaded),
	}
	row["authored_text_roundtrip_equivalent"] = saved_draft != null \
		and bool(row.authored_chain_differences.before_to_live.exact_equal) \
		and bool(row.authored_chain_differences.live_to_persisted_clone.exact_equal) \
		and bool(row.authored_chain_differences.persisted_clone_to_reloaded.text_roundtrip_equivalent)
	row["idle_authored_text_roundtrip_equivalent"] = combat_idle != null and saved_idle != null \
		and bool(row.idle_authored_chain_differences.before_to_live.exact_equal) \
		and bool(row.idle_authored_chain_differences.live_to_persisted_clone.exact_equal) \
		and bool(row.idle_authored_chain_differences.persisted_clone_to_reloaded.text_roundtrip_equivalent)
	row["ok"] = save_fixture_ok and bool(row.before.ok) and bool(row.source_unchanged) and bool(row.dirty_cleared) \
		and bool(row.no_auto_playback) and String(row.output_sha256) != "missing" \
		and String(row.output_sha256) != _initial_output_hash and bool(row.reload_comparison.ok) and bool(row.authored_text_roundtrip_equivalent) \
		and bool(row.active_clip_preservation.ok) and bool(row.idle_prepared) and bool(row.idle_reload_comparison.ok) \
		and bool(row.idle_authored_text_roundtrip_equivalent) and String(row.save_message).contains("Preview ready")
	_record_replay_step(row)
	if bool(row.ok) and String(_options.get("lifecycle", "false")) == "true":
		return await _check_lifecycle_after_save()
	return bool(row.ok)

func _check_lifecycle_after_save() -> bool:
	# The normal pre-Save checks are complete. Subsequent no-write assertions
	# use the just-saved isolated file as their baseline.
	_initial_output_hash = _hash_or_missing(String(_library.save_file_path))
	_replay_row["lifecycle_limitations"] = "Same-draft duration edits at the two final Save frame waits; weapon switches and UI-close races are not exercised."
	var draft: Resource = _ui.call("_get_active_draft")
	var old_clip: CombatRuntimeClip = draft.get("baked_runtime_clip") as CombatRuntimeClip
	var chain_before: Array = _authored_chain_values(draft)
	var row: Dictionary = {"step": "lifecycle_explicit_Reacquire", "saved_output_sha256": _initial_output_hash,
		"had_completed_clip": old_clip != null and old_clip.has_solved_replay_track(),
		"had_continuation_cache": not _render_cache(old_clip).is_empty()}
	if _ui.grip_reacquire_button == null or not _ui.has_method("_request_preview_grip_reacquisition"):
		row.merge({"ok": false, "reason": "reacquire_button_callback_unavailable"})
		_record_replay_step(row)
		return false
	_ui.grip_reacquire_button.pressed.emit()
	row["completed_clip_invalidated"] = draft.get("baked_runtime_clip") == null
	row["continuation_invalidated"] = _render_cache(old_clip).is_empty()
	row["saved_cache_blocked"] = bool(_ui.get("saved_runtime_cache_reuse_blocked_by_grip"))
	row["saved_clip_not_reusable"] = not bool(_ui.call("_active_draft_has_valid_preview_cache", draft))
	row["dirty_after_request"] = _ui.editor_state_dirty
	row["authored_unchanged"] = chain_before == _authored_chain_values(draft)
	row["readiness"] = await _wait_ready(0.0)
	row["persistence"] = _unsaved_persistence_check()
	row["ok"] = bool(row.had_completed_clip) and bool(row.had_continuation_cache) \
		and bool(row.completed_clip_invalidated) and bool(row.continuation_invalidated) \
		and bool(row.saved_cache_blocked) and bool(row.saved_clip_not_reusable) and bool(row.dirty_after_request) \
		and bool(row.authored_unchanged) and bool(row.readiness.get("ready", false)) and bool(row.persistence.ok)
	_record_replay_step(row)
	if not bool(row.ok): return false
	if not await _prepare_and_check("lifecycle_F_after_Reacquire", false, false): return false
	var preparation_step: Dictionary = (_replay_row.steps as Array).back()
	var result: Dictionary = preparation_step.get("prepare_result", {})
	var fresh_clip: CombatRuntimeClip = draft.get("baked_runtime_clip") as CombatRuntimeClip
	row = {"step": "lifecycle_Reacquire_freshness", "new_clip_resource": fresh_clip != null and fresh_clip != old_clip,
		"F_prepared_instead_of_restoring_save": bool(preparation_step.get("busy_after_F", false)),
		"processed_frames": int(result.get("processed_frames", -1)), "reused_frames": int(result.get("reused_frames", -1)),
		"frame_count": fresh_clip.get_frame_count() if fresh_clip != null else 0,
		"saved_cache_still_blocked": bool(_ui.get("saved_runtime_cache_reuse_blocked_by_grip")),
		"dirty": _ui.editor_state_dirty, "persistence": _unsaved_persistence_check()}
	row["ok"] = bool(row.new_clip_resource) and bool(row.F_prepared_instead_of_restoring_save) \
		and int(row.processed_frames) == int(row.frame_count) and int(row.reused_frames) == 0 \
		and bool(row.saved_cache_still_blocked) and bool(row.dirty) and bool(row.persistence.ok)
	_record_replay_step(row)
	if not bool(row.ok): return false
	if not await _check_save_persistence_failure(): return false
	if not await _check_save_edit_race("restore_editor_grip", false): return false
	if not await _prepare_and_check("lifecycle_F_after_aborted_Save_edit", false, false): return false
	return await _check_save_edit_race("file_saving", true)

func _check_save_persistence_failure() -> bool:
	var draft: Resource = _ui.call("_get_active_draft")
	var clip_before: CombatRuntimeClip = draft.get("baked_runtime_clip") as CombatRuntimeClip
	var expected_clip: CombatRuntimeClip = clip_before.duplicate_clip() if clip_before != null else null
	var original_path: String = _library.save_file_path
	var blocker_path: String = _output.path_join("persistence_failure_parent")
	var failed_path: String = blocker_path.path_join("profile_library.tres")
	var row: Dictionary = {"step": "lifecycle_Save_persistence_failure", "original_path": original_path,
		"failed_path": failed_path, "dirty_before": _ui.editor_state_dirty,
		"saved_cache_blocked_before": bool(_ui.get("saved_runtime_cache_reuse_blocked_by_grip")),
		"output_sha256_before": _hash_or_missing(original_path)}
	# The inherited bootstrap already requires a fresh workspace output folder.
	# A regular file cannot serve as the parent of the requested save file.
	if FileAccess.file_exists(blocker_path) or DirAccess.dir_exists_absolute(blocker_path) or expected_clip == null:
		row.merge({"ok": false, "reason": "invalid_persistence_failure_fixture"})
		_record_replay_step(row)
		return false
	var blocker: FileAccess = FileAccess.open(blocker_path, FileAccess.WRITE)
	if blocker == null:
		row.merge({"ok": false, "reason": "cannot_create_persistence_failure_fixture"})
		_record_replay_step(row)
		return false
	blocker.store_string("Isolated persistence failure fixture: this parent is a regular file.\n")
	blocker.close()
	var blocker_hash: String = FileAccess.get_sha256(blocker_path)
	_library.save_file_path = failed_path
	await _ui._manual_save_active_editor_state()
	_library.save_file_path = original_path
	var trace: Dictionary = (_ui.get_meta("last_save_latency_trace", {}) as Dictionary).duplicate(true)
	draft = _ui.call("_get_active_draft")
	var clip_after: CombatRuntimeClip = draft.get("baked_runtime_clip") as CombatRuntimeClip
	row["trace"] = trace
	row["message"] = _ui.footer_status_label.text
	row["path_restored"] = String(_library.save_file_path) == original_path
	row["save_finished"] = not _ui.manual_save_in_progress
	row["dirty_retained"] = _ui.editor_state_dirty
	row["saved_cache_block_retained"] = bool(_ui.get("saved_runtime_cache_reuse_blocked_by_grip"))
	row["source_unchanged"] = FileAccess.get_sha256(_source) == _source_hash
	row["output_unchanged"] = _hash_or_missing(original_path) == String(row.output_sha256_before)
	row["blocker_unchanged"] = FileAccess.get_sha256(blocker_path) == blocker_hash
	row["failed_target_absent"] = not FileAccess.file_exists(failed_path)
	row["local_cache_available"] = clip_after != null and bool(_ui.call("_active_draft_has_valid_preview_cache", draft))
	row["local_cache_exact"] = _compare_clips(expected_clip, clip_after)
	row["no_playback"] = not _ui.chain_player.is_playing()
	row["failure_reported"] = trace.has("persisted") and not bool(trace.persisted) \
		and String(trace.get("failure_reason", "")) == "library_persistence_failed" \
		and String(row.message) == "Save failed. Changes remain unsaved."
	row["ok"] = bool(row.dirty_before) and bool(row.saved_cache_blocked_before) \
		and bool(row.path_restored) and bool(row.save_finished) and bool(row.dirty_retained) and bool(row.saved_cache_block_retained) \
		and bool(row.source_unchanged) and bool(row.output_unchanged) and bool(row.blocker_unchanged) and bool(row.failed_target_absent) \
		and bool(row.local_cache_available) and bool(row.local_cache_exact.ok) and bool(row.no_playback) and bool(row.failure_reported)
	_record_replay_step(row)
	return bool(row.ok)

func _check_save_edit_race(target_phase: String, expected_already_written: bool) -> bool:
	var draft: Resource = _ui.call("_get_active_draft")
	var draft_id: StringName = draft.draft_id
	var expected_saved_chain: Array = _authored_chain_values(draft)
	var before_hash: String = _hash_or_missing(String(_library.save_file_path))
	_save_race_target_phase = target_phase
	_save_race_observation = {"triggered": false}
	# Connected before the Save coroutine's process_frame awaits. The callback
	# additionally checks the existing trace phase and records the file hash at
	# injection, so a missed timing window cannot become a passing assertion.
	process_frame.connect(_on_save_race_process_frame)
	var started := Time.get_ticks_msec()
	_ui.call("_manual_save_active_editor_state")
	while _ui.manual_save_in_progress and Time.get_ticks_msec() - started < PREPARE_TIMEOUT_MS:
		await process_frame
	if process_frame.is_connected(_on_save_race_process_frame): process_frame.disconnect(_on_save_race_process_frame)
	_save_race_target_phase = ""
	var trace: Dictionary = (_ui.get_meta("last_save_latency_trace", {}) as Dictionary).duplicate(true)
	var row: Dictionary = {"step": "lifecycle_Save_edit_" + target_phase, "injection": _save_race_observation.duplicate(true),
		"save_finished": not _ui.manual_save_in_progress, "trace": trace, "message": _ui.footer_status_label.text,
		"dirty_edit_retained": _ui.editor_state_dirty, "source_unchanged": FileAccess.get_sha256(_source) == _source_hash,
		"output_before": before_hash, "output_after": _hash_or_missing(String(_library.save_file_path))}
	var motion: CombatAnimationMotionNode = _ui.call("_get_active_motion_node")
	row["live_duration_matches_injected_edit"] = motion != null and motion.transition_duration_seconds == float(_save_race_observation.get("requested_duration", -1.0))
	var saved_draft: Resource = _load_saved_draft(draft_id)
	row["saved_expected_source_found"] = saved_draft != null
	if expected_already_written:
		var saved_chain: Array = _authored_chain_values(saved_draft) if saved_draft != null else []
		row["saved_chain_is_pre_injection_snapshot_exact"] = saved_draft != null and expected_saved_chain == saved_chain
		row["saved_chain_text_roundtrip_comparison"] = _compare_authored_values(expected_saved_chain, saved_chain)
		var persisted_chain: Array = []
		var persisted_wip: Resource = _library.get_saved_wip(_weapon_id)
		if persisted_wip != null:
			for candidate: Resource in persisted_wip.combat_animation_station_state.skill_drafts:
				if candidate.draft_id == draft_id:
					persisted_chain = _authored_chain_values(candidate)
					break
		row["persisted_clone_is_pre_injection_snapshot_exact"] = expected_saved_chain == persisted_chain
		row["saved_chain_is_pre_injection_snapshot"] = saved_draft != null \
			and bool(row.persisted_clone_is_pre_injection_snapshot_exact) \
			and bool(row.saved_chain_text_roundtrip_comparison.text_roundtrip_equivalent)
		row["save_guard_reported"] = bool(trace.get("source_changed_after_write", false))
		row["race_contract_ok"] = bool(row.saved_chain_is_pre_injection_snapshot) and bool(row.save_guard_reported)
	else:
		row["no_output_write"] = String(row.output_before) == String(row.output_after)
		row["save_guard_reported"] = bool(trace.get("aborted", false))
		row["race_contract_ok"] = bool(row.no_output_write) and bool(row.save_guard_reported)
	row["ok"] = bool(row.injection.get("triggered", false)) and bool(row.injection.get("edit_accepted", false)) \
		and bool(row.save_finished) and bool(row.dirty_edit_retained) and bool(row.source_unchanged) \
		and bool(row.live_duration_matches_injected_edit) and bool(row.saved_expected_source_found) and bool(row.race_contract_ok)
	_record_replay_step(row)
	return bool(row.ok)

func _on_save_race_process_frame() -> void:
	if _save_race_target_phase.is_empty() or not _ui.manual_save_in_progress or bool(_save_race_observation.get("triggered", false)): return
	var trace: Dictionary = _ui.get_meta("last_save_latency_trace", {})
	var phases: Array = trace.get("phases", [])
	if phases.is_empty() or String((phases.back() as Dictionary).get("label", "")) != _save_race_target_phase: return
	var draft: Resource = _ui.call("_get_active_draft")
	var motion: CombatAnimationMotionNode = _ui.call("_get_active_motion_node")
	if draft == null or motion == null: return
	var requested: float = motion.transition_duration_seconds + 0.137
	_save_race_observation = {"triggered": true, "phase": _save_race_target_phase,
		"draft_id": String(draft.draft_id), "node_id": String(motion.node_id),
		"duration_before": motion.transition_duration_seconds, "requested_duration": requested,
		"output_sha256_at_injection": _hash_or_missing(String(_library.save_file_path)),
		"progress_percent": _ui.save_progress_bar.value if _ui.save_progress_bar != null else -1.0}
	_save_race_observation["edit_accepted"] = _ui.set_selected_motion_node_transition_duration(requested, false)
	_save_race_observation["dirty_immediately_after_edit"] = _ui.editor_state_dirty

func _load_saved_draft(draft_id: StringName) -> Resource:
	if not FileAccess.file_exists(String(_library.save_file_path)): return null
	var saved: Resource = ResourceLoader.load(_library.save_file_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if saved == null: return null
	var wip: Resource = saved.get_saved_wip(_weapon_id)
	if wip == null: return null
	for draft: Resource in wip.combat_animation_station_state.skill_drafts:
		if draft.draft_id == draft_id: return draft
	return null

func _compare_clips(left: CombatRuntimeClip, right: CombatRuntimeClip) -> Dictionary:
	if left == null or right == null: return {"ok": false, "reason": "missing_clip"}
	var fields: Array[StringName] = Incremental.INPUT_METADATA_FIELDS.duplicate()
	fields.append_array(Incremental.INPUT_FRAME_FIELDS)
	fields.append_array(Incremental.SOLVED_METADATA_FIELDS)
	fields.append_array(Incremental.SOLVED_FRAME_FIELDS)
	fields.append_array([&"total_duration_seconds", &"baked_upper_body_bone_pose_rotations"])
	var differences: Array = []
	for field: StringName in fields:
		var a: Variant = left.get(field)
		var b: Variant = right.get(field)
		if typeof(a) == typeof(b) and a == b: continue
		var detail: Dictionary = {"field": String(field), "left_type": typeof(a), "right_type": typeof(b)}
		if _is_sequence(a) and _is_sequence(b):
			detail["left_size"] = a.size()
			detail["right_size"] = b.size()
			for index: int in mini(a.size(), b.size()):
				if a[index] != b[index]:
					detail["first_index"] = index
					detail["left"] = str(a[index])
					detail["right"] = str(b[index])
					break
		else:
			detail["left"] = str(a)
			detail["right"] = str(b)
		differences.append(detail)
	return {"ok": differences.is_empty() and left.has_solved_replay_track() and right.has_solved_replay_track(),
		"fields_checked": fields.size(), "frames": left.get_frame_count(), "differences": differences}

func _compare_camera_states(before: Dictionary, after: Dictionary) -> Dictionary:
	# Production camera application converts pitch degrees to radians, clamps
	# against the floor and converts back. Camera-only roundoff is measured;
	# authored inputs, solved tracks and rig/grip checkpoints stay exact.
	var row: Dictionary = {"ok": false, "before": before.duplicate(true), "after": after.duplicate(true), "exact_equal": before == after,
		"position_tolerance_m": 0.000001, "angle_tolerance_degrees": 0.00001}
	if not bool(before.get("valid", false)) or not bool(after.get("valid", false)):
		row["reason"] = "invalid_camera_state"
		return row
	if not before.get("focus_point") is Vector3 or not after.get("focus_point") is Vector3:
		row["reason"] = "missing_camera_focus"
		return row
	var focus_before: Vector3 = before.focus_point
	var focus_after: Vector3 = after.focus_point
	row.before["focus_point"] = [focus_before.x, focus_before.y, focus_before.z]
	row.after["focus_point"] = [focus_after.x, focus_after.y, focus_after.z]
	if not focus_before.is_finite() or not focus_after.is_finite():
		row["reason"] = "nonfinite_camera_focus"
		return row
	var focus_error: float = focus_before.distance_to(focus_after)
	row["focus_error_m"] = focus_error
	var valid: bool = focus_error <= 0.000001
	for field: String in ["distance", "orbit_yaw_degrees", "orbit_pitch_degrees"]:
		if not before.has(field) or not after.has(field) or typeof(before[field]) != TYPE_FLOAT or typeof(after[field]) != TYPE_FLOAT:
			row["reason"] = "missing_or_invalid_camera_" + field
			return row
		var left: float = before[field]
		var right: float = after[field]
		if not is_finite(left) or not is_finite(right):
			row["reason"] = "nonfinite_camera_" + field
			return row
		var error: float = absf(left - right)
		row[field + "_absolute_error"] = error
		valid = valid and error <= (0.000001 if field == "distance" else 0.00001)
	row["ok"] = valid
	return row

func _is_sequence(value: Variant) -> bool:
	return typeof(value) in [TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_VECTOR4_ARRAY]

func _authored_chain_values(draft: Resource) -> Array:
	var values: Array = []
	for motion: Resource in draft.get("motion_node_chain"):
		values.append(_authored_resource_values(motion))
	return values

func _authored_resource_values(resource: Resource) -> Dictionary:
	# Retarget metadata is an exported child Resource. Compare its stored values
	# across fresh reloads rather than requiring the same in-memory object.
	var fields: Dictionary = {}
	for info: Dictionary in resource.get_property_list():
		var field := StringName(info.name)
		if int(info.usage) & PROPERTY_USAGE_STORAGE and not String(field).begins_with("resource_") and field != &"script":
			var value: Variant = resource.get(field)
			fields[field] = _authored_resource_values(value) if value is Resource else (value.duplicate(true) if value is Dictionary or value is Array else value)
	return fields

func _compare_authored_values(left: Variant, right: Variant) -> Dictionary:
	# Exact values remain visible. Text equivalence accepts only the observed
	# retarget source-length float32 conversion and pivot-range text roundtrip.
	var differences: Array[Dictionary] = []
	_collect_authored_differences(left, right, "chain", differences, 33)
	var truncated: bool = differences.size() > 32
	if truncated: differences.resize(32)
	return {"exact_equal": typeof(left) == typeof(right) and left == right,
		"text_roundtrip_equivalent": _authored_text_roundtrip_equivalent(left, right, "chain"),
		"reported_differences": differences.size(), "limit": 32, "truncated": truncated,
		"differences": differences}

func _authored_text_roundtrip_equivalent(left: Variant, right: Variant, path: String) -> bool:
	if typeof(left) != typeof(right): return false
	if left == right: return true
	if left is Dictionary:
		if left.size() != right.size(): return false
		for key: Variant in left:
			if not right.has(key) or not _authored_text_roundtrip_equivalent(left[key], right[key], path + "." + str(key)): return false
		return true
	if _is_sequence(left):
		if left.size() != right.size(): return false
		for index: int in left.size():
			if not _authored_text_roundtrip_equivalent(left[index], right[index], "%s[%d]" % [path, index]): return false
		return true
	if left is float and path.ends_with(".retarget_node.source_weapon_length_meters") and is_finite(left) and is_finite(right):
		var original_float32: float = PackedFloat32Array([left])[0]
		var reloaded_float32: float = PackedFloat32Array([right])[0]
		return float(left) == original_float32 and original_float32 == reloaded_float32
	if left is float and path.ends_with(".retarget_node.pivot_range_percent") and is_finite(left) and is_finite(right):
		var text_roundtrip: Variant = str_to_var(var_to_str(left))
		return typeof(text_roundtrip) == TYPE_FLOAT and text_roundtrip == right
	return false

func _collect_authored_differences(left: Variant, right: Variant, path: String,
		differences: Array[Dictionary], limit: int) -> void:
	if differences.size() >= limit or (typeof(left) == typeof(right) and left == right): return
	if typeof(left) == typeof(right):
		if left is Dictionary:
			var keys: Array = left.keys()
			for key: Variant in right.keys():
				if not left.has(key): keys.append(key)
			for key: Variant in keys:
				if differences.size() >= limit: return
				var field_path: String = path + "." + str(key)
				if not left.has(key) or not right.has(key):
					differences.append({"path": field_path, "left_present": left.has(key), "right_present": right.has(key),
						"left": _authored_difference_value(left.get(key)), "right": _authored_difference_value(right.get(key))})
				else:
					_collect_authored_differences(left[key], right[key], field_path, differences, limit)
			return
		if _is_sequence(left):
			if left.size() != right.size():
				differences.append({"path": path + ".size", "left": left.size(), "right": right.size()})
			for index: int in mini(left.size(), right.size()):
				if differences.size() >= limit: return
				_collect_authored_differences(left[index], right[index], "%s[%d]" % [path, index], differences, limit)
			return
		if left is Vector3:
			for axis: int in 3:
				_collect_authored_differences(left[axis], right[axis], path + "." + ["x", "y", "z"][axis], differences, limit)
			return
	var detail: Dictionary = {"path": path, "left": _authored_difference_value(left), "right": _authored_difference_value(right)}
	if (left is float or left is int) and (right is float or right is int):
		detail["absolute_error"] = absf(float(left) - float(right))
	differences.append(detail)

func _authored_difference_value(value: Variant) -> Dictionary:
	var result: Dictionary = {"type": type_string(typeof(value)), "value": value}
	if value is float:
		# The ordinary JSON writer need not retain every float64 decimal. Keep
		# a readable precision string and exact Variant bytes alongside it.
		result["decimal_17"] = "%.17f" % value
		result["variant_bytes_hex"] = var_to_bytes(value).hex_encode()
	elif value is Dictionary or _is_sequence(value):
		result["value"] = {"size": value.size()}
	elif value is Object:
		result["value"] = str(value)
	return result

func _terminal_check(draft: Resource, clip: CombatRuntimeClip) -> Dictionary:
	if clip == null or clip.motion_node_chain.is_empty() or clip.get_frame_count() <= 0: return {"ok": false}
	var authored: Resource = draft.motion_node_chain.back()
	var compiled: Resource = clip.motion_node_chain.back()
	var index: int = clip.get_frame_count() - 1
	var sampled_tip: Vector3 = clip.baked_tip_positions_local[index]
	var sampled_pommel: Vector3 = clip.baked_pommel_positions_local[index]
	var compiled_tip: Vector3 = compiled.tip_position_local
	var compiled_pommel: Vector3 = compiled.pommel_position_local
	return {"ok": authored.node_id == compiled.node_id and sampled_tip == compiled_tip and sampled_pommel == compiled_pommel,
		"authored_id": String(authored.node_id), "compiled_id": String(compiled.node_id),
		"sample_index": index, "compiled_last_index": clip.motion_node_chain.size() - 1,
		"sample_time": clip.baked_frame_times[index], "duration": clip.total_duration_seconds,
		"previous_sample_time": clip.baked_frame_times[index - 1] if index > 0 else -1.0,
		"sampled_tip": [sampled_tip.x, sampled_tip.y, sampled_tip.z],
		"compiled_tip": [compiled_tip.x, compiled_tip.y, compiled_tip.z],
		"sampled_pommel": [sampled_pommel.x, sampled_pommel.y, sampled_pommel.z],
		"compiled_pommel": [compiled_pommel.x, compiled_pommel.y, compiled_pommel.z],
		"tip_distance_error_m": sampled_tip.distance_to(compiled_tip),
		"pommel_distance_error_m": sampled_pommel.distance_to(compiled_pommel)}

func _render_cache(clip: CombatRuntimeClip) -> Dictionary:
	if clip == null: return {}
	var key: String = _ui.preview_presenter.call("_pose_render_cache_key", clip)
	var caches: Dictionary = _ui.preview_presenter.get("_pose_render_caches")
	return caches.get(key, {})

func _unsaved_persistence_check() -> Dictionary:
	var source_same: bool = FileAccess.get_sha256(_source) == _source_hash
	var output_hash: String = _hash_or_missing(String(_library.save_file_path))
	return {"ok": source_same and output_hash == _initial_output_hash, "source_unchanged": source_same,
		"output_unchanged": output_hash == _initial_output_hash, "output_sha256": output_hash}

func _hash_or_missing(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _stop_replay() -> void:
	if _ui.chain_player.is_playing(): _ui.call("_toggle_preview_playback")

func _begin_replay_measurement() -> void:
	_max_frame_interval_ms = 0.0
	_frame_intervals = 0
	_last_frame_usec = Time.get_ticks_usec()
	_measuring = true

func _end_replay_measurement(row: Dictionary, started: int) -> void:
	_observe_process_frame()
	_measuring = false
	row["wall_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	row["max_process_frame_interval_ms"] = _max_frame_interval_ms
	row["observed_process_frame_intervals"] = _frame_intervals

func _record_replay_step(row: Dictionary) -> void:
	(_replay_row.steps as Array).append(row)
	_write_json(_output.path_join("incremental_replay.json"), _replay_row)
	print("INCREMENTAL_REPLAY step=%s ok=%s wall_ms=%.3f" % [row.step, row.get("ok", false), float(row.get("wall_ms", 0.0))])

func _end_replay_case(reason: String) -> bool:
	_stop_replay()
	if _ui.preview_prepare_in_progress: _ui.call("_cancel_preview_preparation")
	_replay_row["reason"] = reason
	_replay_row["complete"] = reason.is_empty()
	_replay_row["ok"] = reason.is_empty()
	_record_case(_replay_row)
	return reason.is_empty()
