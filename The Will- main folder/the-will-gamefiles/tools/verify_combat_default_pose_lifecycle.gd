extends "res://tools/verify_combat_pose_recording_lifecycle.gd"

## SC-01: real station entry -> untouched Save -> disk/fresh-scene reopen -> Reset.
## Uses the parent's observation/comparison helpers, not its edit/F/prewarm flow.
## Required environment is the same isolated contract as the parent verifier.
## Replaces only Skill 3 and both idle contexts in the in-memory isolated fixture.
## Source files are never saved. Each awaited phase is bounded to 180 seconds.
## THE_WILL_SC01_EDIT_REOPENED=1 adds the cold-reopen edit test and runs only Skill 3.
## THE_WILL_SC01_CONTEXT=skill_slot_3 can also select only that context without editing.
const DEFAULT_TEST_SLOT: StringName = &"skill_slot_3"
const DEFAULT_CONTEXTS: Array[StringName] = [DEFAULT_TEST_SLOT, &"idle_combat", &"idle_noncombat"]
const DEFAULT_STAGE_TIMEOUT_MS: int = 180000
const DEFAULT_SETTLE_FRAMES: int = 8

var _default_context: StringName = DEFAULT_TEST_SLOT
var _default_open_trace: Dictionary = {}
var _edit_reopened_requested: bool = false


func _run() -> void:
	_edit_reopened_requested = OS.get_environment("THE_WILL_SC01_EDIT_REOPENED") == "1"
	var context_filter: String = OS.get_environment("THE_WILL_SC01_CONTEXT")
	if not context_filter.is_empty() and context_filter != String(DEFAULT_TEST_SLOT):
		push_error("SC-01 optional context filter supports only skill_slot_3."); quit(1); return
	_source = OS.get_environment("THE_WILL_GRIP_LIVE_LIBRARY").replace("\\", "/")
	_output = OS.get_environment("THE_WILL_SAVE_PROFILE_OUTPUT_DIR").replace("\\", "/")
	var expected_root: String = OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").to_lower()
	if not expected_root.begins_with("c:/workspace/") or OS.get_user_data_dir().replace("\\", "/").to_lower() != expected_root:
		push_error("Isolated diagnostic user root required."); quit(1); return
	if not _source.to_lower().begins_with("c:/workspace/") or not _output.to_lower().begins_with("c:/workspace/"):
		push_error("Workspace source/output required."); quit(1); return
	if FileAccess.file_exists(_output.path_join("default_pose_lifecycle.json")) or FileAccess.file_exists(_output.path_join("profile_library.tres")) or _source.to_lower().begins_with(_output.to_lower() + "/"):
		push_error("Fresh output separate from source required."); quit(1); return
	if not FileAccess.file_exists(_source) or DirAccess.make_dir_recursive_absolute(_output) != OK:
		push_error("Source missing or output unavailable."); quit(1); return
	_source_hash = FileAccess.get_sha256(_source)
	if not Chronology.enabled(): _finish("fresh_grip_trace_required"); return
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
	_report.merge({"source_path": _source, "source_sha256": _source_hash, "weapon": requested,
		"fixture_replaced_contexts": DEFAULT_CONTEXTS, "phase_timeout_ms": DEFAULT_STAGE_TIMEOUT_MS,
		"automation": "Real main scene and station commands. First Save has no edit, R, F, explicit capture, solver bypass, or injected prepared packet. Fixture replacement occurs only in the isolated library before entry.",
		"limits": "Proves default authoring/persistence/reuse and observed acquisition counts. Packet schema/signature validity is not anatomical or contact certification. Equipped combat playback and all-hand coverage are separate tests.",
		"contexts_completed": [], "edit_reopened_enabled": _edit_reopened_requested,
		"context_filter": String(DEFAULT_TEST_SLOT) if _edit_reopened_requested else context_filter})
	if not _make_default_fixture(selected): _finish("fresh_fixture_creation_failed"); return
	if not _library.persist(): _finish("isolated_fixture_save_failed"); return
	for context_id: StringName in DEFAULT_CONTEXTS:
		if (_edit_reopened_requested or not context_filter.is_empty()) and context_id != DEFAULT_TEST_SLOT: continue
		_default_context = context_id
		if not await _run_default_context(): return
		_report.contexts_completed.append(String(context_id))
		_write_report()
	_finish("finished")


func _make_default_fixture(weapon: Resource) -> bool:
	var station: Resource = weapon.ensure_combat_animation_station_state()
	if station == null: return false
	var skills: Array[Resource] = []
	for draft: Resource in station.skill_drafts:
		if draft != null and draft.owning_skill_id != DEFAULT_TEST_SLOT: skills.append(draft)
	station.skill_drafts.assign(skills)
	var idles: Array[Resource] = []
	for draft: Resource in station.idle_drafts:
		if draft != null and draft.context_id not in [&"idle_combat", &"idle_noncombat"]: idles.append(draft)
	station.idle_drafts.assign(idles)
	station.get_or_create_skill_draft(DEFAULT_TEST_SLOT, "Skill 3", weapon.grip_style_mode, DEFAULT_TEST_SLOT)
	station.get_or_create_idle_draft(&"idle_combat", "Combat Idle", weapon.grip_style_mode)
	station.get_or_create_idle_draft(&"idle_noncombat", "Noncombat Idle", weapon.grip_style_mode)
	for context_id: StringName in DEFAULT_CONTEXTS:
		var draft: Resource = _default_draft(weapon, context_id)
		if draft == null or bool(draft.get("authoring_pose_initialized")): return false
		for node: Resource in draft.get_action_motion_node_chain():
			if not node.prepared_pose.is_empty() or not node.prepared_pose_signature.is_empty(): return false
	return true


func _run_default_context() -> bool:
	if not await _open_default_context(): _finish("fresh_open_failed"); return false
	if not await _wait_default_ready("fresh_open"):
		_finish("fresh_default_not_ready"); return false
	if not _record_default_phase("fresh_open", _default_open_trace, _default_context != &"idle_noncombat"):
		_finish("fresh_default_contract_failed"); return false
	await _screenshot(String(_default_context) + "_fresh.png")
	if not await _save_default_without_edit(): return false
	if not await _reopen_saved_default(): return false
	if _edit_reopened_requested and not await _edit_after_cold_reopen(): return false
	if not await _reset_default_context(): return false
	await _close_default_scene()
	return true


func _open_default_context() -> bool:
	var weapon: Resource = _library.get_saved_wip(_weapon_id)
	var station_state: Resource = weapon.combat_animation_station_state if weapon != null else null
	if station_state == null: return false
	# Navigation metadata only: avoid entering an unrelated armed editor before
	# measuring Noncombat. No authored node/capture data changes here.
	station_state.selected_authoring_mode = &"author_skill" if _default_context == DEFAULT_TEST_SLOT else &"author_idle"
	if _default_context == DEFAULT_TEST_SLOT: station_state.selected_skill_id = DEFAULT_TEST_SLOT
	else: station_state.selected_idle_context_id = _default_context
	_lifecycle_world = WORLD.instantiate()
	root.add_child(_lifecycle_world)
	current_scene = _lifecycle_world
	await process_frame
	if _finished: return false
	var player: PlayerController3D = _lifecycle_world.get_node("PlayerCharacter")
	player.forge_wip_library_state = _library
	var station: CombatAnimationStation = _lifecycle_world.get_node("CombatAnimationStation")
	_ui = station.station_ui as CombatAnimationStationUI
	_ui.set_meta("trace_save_latency", true)
	_ui.preview_presenter.set_meta("trace_save_latency", true)
	station.interact(player)
	await process_frame
	_default_open_trace = _begin_default_trace("open")
	if not _ui.open_saved_wip_with_hand_setup(_weapon_id, HAND, false, false): return false
	if _default_context == DEFAULT_TEST_SLOT:
		return _ui.select_skill_slot(DEFAULT_TEST_SLOT, true)
	return _ui.select_authoring_mode(&"author_idle") and _ui.select_draft(_default_context, true)


func _wait_default_ready(label: String) -> bool:
	var started: int = Time.get_ticks_msec()
	var stable_frames: int = 0
	while not _finished and Time.get_ticks_msec() - started < DEFAULT_STAGE_TIMEOUT_MS:
		var node: CombatAnimationMotionNode = _ui.call("_get_active_motion_node") as CombatAnimationMotionNode
		var pending: bool = _ui.manual_save_in_progress or _ui.preview_prepare_in_progress or _recording_pending() or not (_ui.get("_baseline_preparation") as Dictionary).is_empty() or _ui.preview_presenter.is_grip_acquisition_pending(_ui.preview_subviewport)
		var ready: bool = not pending and node != null
		if _default_context == &"idle_noncombat":
			ready = ready and _noncombat_is_stowed(_ui.get_preview_debug_state())
		else:
			ready = ready and _node_current(node) and _ui.preview_presenter.can_restore_prepared_authoring_pose(node)
		stable_frames = stable_frames + 1 if ready else 0
		if stable_frames >= DEFAULT_SETTLE_FRAMES:
			_report.phases.append({"context": String(_default_context), "phase": label + "_wait", "wait_ms": Time.get_ticks_msec() - started, "ready": true})
			_write_report(); return true
		await process_frame
	_report.phases.append({"context": String(_default_context), "phase": label + "_wait", "wait_ms": Time.get_ticks_msec() - started, "ready": false, "state": _default_state()})
	_write_report()
	return false


func _begin_default_trace(label: String) -> Dictionary:
	# Also creates a trace file for a zero-acquisition Noncombat-only phase.
	Chronology.event("default_pose_lifecycle.phase_begin", {"context": String(_default_context), "phase": label, "terminal": true})
	return _solve_start_count()


func _record_default_phase(label: String, before: Dictionary, requires_acquisition: bool) -> bool:
	var after: Dictionary = _solve_start_count()
	var state: Dictionary = _default_state()
	var delta: int = int(after.get("count", 0)) - int(before.get("count", 0))
	var trace_valid: bool = bool(before.get("available", false)) and bool(after.get("available", false))
	var acquisition_valid: bool = delta > 0 if requires_acquisition else delta == 0
	var valid: bool = trace_valid and acquisition_valid and bool(state.one_visible_node) and bool(state.default_body_controls)
	if _default_context == &"idle_noncombat": valid = valid and bool(state.stowed)
	else: valid = valid and bool(state.pose_current) and bool(state.initialized)
	state.merge({"context": String(_default_context), "phase": label, "acquisitions": delta,
		"trace_available": trace_valid, "requires_new_acquisition": requires_acquisition, "valid": valid})
	_report.phases.append(state)
	_write_report()
	return valid


func _default_state() -> Dictionary:
	if _ui == null or not is_instance_valid(_ui): return {"ui_available": false}
	var draft: Resource = _ui.call("_get_active_draft")
	var node: Resource = _ui.call("_get_active_motion_node")
	var action: Array = draft.get_action_motion_node_chain() if draft != null else []
	var debug: Dictionary = _ui.get_preview_debug_state()
	var expected_index: int = 1 if _default_context == DEFAULT_TEST_SLOT else 0
	var preview_root: Node = _ui.preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D")
	var restore: Dictionary = preview_root.get_meta("prepared_authoring_pose_restore", {}) if preview_root != null else {}
	var body_controls: Dictionary = _compare_default_body_controls(node)
	return {"raw_node_count": draft.motion_node_chain.size() if draft != null else 0,
		"visible_node_count": action.size(), "selected_raw_index": _ui.get_selected_motion_node_index(),
		"one_visible_node": action.size() == 1 and _ui.get_selected_motion_node_index() == expected_index and action[0] == node,
		"initialized": draft != null and bool(draft.get("authoring_pose_initialized")),
		"pose_current": _node_current(node), "pose_signature": node.prepared_pose_signature if node != null else "",
		"default_body_controls": bool(body_controls.valid), "body_controls": body_controls,
		"stowed": _noncombat_is_stowed(debug), "stow_mode": String(debug.get("selected_stow_anchor_mode", "")),
		"stow_orientation_side": String(debug.get("selected_stow_anchor_orientation_side", "")),
		"stow_marker": String(debug.get("selected_stow_anchor_marker_id", "")),
		"prepared_pose_restore": restore, "baseline_preparation": _ui.get_meta("last_baseline_preparation", {}),
		"status": _ui.footer_status_label.text}


func _compare_default_body_controls(node: Resource) -> Dictionary:
	# A constructed weapon's default is its declared geometry seed, not the
	# raw MotionNode initializer. The weapon resolver currently supplies 0.4
	# body support; apply_weapon_geometry_seed clamps that and both arm rolls.
	# Read the pure geometry seed, avoiding a mount solve or reseed in the test.
	var seed: Dictionary = _ui.call("_resolve_active_weapon_geometry_seed_base")
	var expected: Dictionary = {
		"body_support_blend": clampf(float(seed.get("body_support_blend", 0.0)), 0.0, 1.0),
		"right_upperarm_roll_degrees": clampf(float(seed.get("right_upperarm_roll_degrees", 0.0)), -180.0, 180.0),
		"left_upperarm_roll_degrees": clampf(float(seed.get("left_upperarm_roll_degrees", 0.0)), -180.0, 180.0)}
	var observed: Dictionary = {}
	if node != null:
		for field: String in expected: observed[field] = node.get(field)
	var comparison: Dictionary = _prepared_numeric_comparison(expected, observed)
	return {"valid": not seed.is_empty() and node != null and bool(comparison.valid),
		"expected": expected, "observed": observed, "comparison": comparison,
		"seed_available": not seed.is_empty(),
		"authority": "CombatAnimationWeaponGeometryResolver.resolve_motion_seed_data -> CombatAnimationDraft.apply_weapon_geometry_seed"}


func _noncombat_is_stowed(debug: Dictionary) -> bool:
	var draft: Resource = _ui.call("_get_active_draft") if _ui != null else null
	var coupling: Dictionary = debug.get("contact_coupling_metrics", {})
	return draft != null and StringName(debug.get("preview_pose_mode", "")) == &"noncombat_stow" and not bool(debug.get("upper_body_authoring_active", true)) and not bool(coupling.get("hands_interact_with_weapon", true)) and String(coupling.get("stopped_reason", "")) == "noncombat_stow_decoupled" and StringName(debug.get("selected_stow_anchor_mode", "")) == draft.stow_anchor_mode and not String(debug.get("selected_stow_anchor_marker_id", "")).is_empty() and not String(debug.get("selected_stow_anchor_orientation_side", "")).is_empty()


func _save_default_without_edit(label: String = "untouched_Save") -> bool:
	var draft: Resource = _ui.call("_get_active_draft")
	var controls: Dictionary = _manual_controls(draft)
	var poses: Array = _prepared_snapshots(draft)
	var baseline: Resource = ResourceLoader.load(_library.save_file_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if baseline == null: _finish("isolated_Save_baseline_unavailable"); return false
	var others: Dictionary = _default_other_sections(baseline.get_saved_wip(_weapon_id), draft.draft_id)
	var before: Dictionary = _begin_default_trace(label)
	var started: int = Time.get_ticks_msec()
	if _ui.save_button.disabled: _finish(label + "_disabled"); return false
	_ui.save_button.pressed.emit()
	# Yield once even when a rejected button handler returns synchronously.
	await process_frame
	while not _finished and (_ui.manual_save_in_progress or _recording_pending()) and Time.get_ticks_msec() - started < DEFAULT_STAGE_TIMEOUT_MS:
		await process_frame
	var after: Dictionary = _solve_start_count()
	var loaded: Resource = ResourceLoader.load(_library.save_file_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var weapon: Resource = loaded.get_saved_wip(_weapon_id) if loaded != null else null
	var stored: Resource = _default_draft(weapon, _default_context)
	var active: Resource = _ui.call("_get_active_draft")
	var trace: Dictionary = _ui.get_meta("last_save_latency_trace", {})
	var row: Dictionary = {"context": String(_default_context), "phase": label, "wall_ms": Time.get_ticks_msec() - started,
		"save_finished": not _ui.manual_save_in_progress and not _recording_pending(), "save_trace": trace,
		"acquisitions": int(after.get("count", 0)) - int(before.get("count", 0)),
		"trace_available": bool(before.get("available", false)) and bool(after.get("available", false)),
		"stored_initialized": stored != null and bool(stored.get("authoring_pose_initialized")),
		"selected_requires_save": bool(_ui.call("_active_draft_requires_manual_save", active)),
		"status": _ui.footer_status_label.text}
	if stored != null:
		# Save is allowed to set its initialized marker; controls themselves stay.
		var stored_controls: Dictionary = _manual_controls(stored)
		controls.erase("authoring_pose_initialized")
		stored_controls.erase("authoring_pose_initialized")
		row["control_round_trip"] = _prepared_numeric_comparison(controls, stored_controls)
		row["prepared_round_trip"] = _prepared_numeric_comparison(poses, _prepared_snapshots(stored))
		row["nonactive_round_trip"] = _prepared_numeric_comparison(others, _default_other_sections(weapon, draft.draft_id))
		row["saved_visible_count"] = stored.get_action_motion_node_chain().size()
		row["saved_clip_present"] = stored.baked_runtime_clip != null and stored.baked_runtime_clip.has_solved_replay_track()
		row["saved_pose_current"] = _node_current(stored.get_action_motion_node_chain()[0]) if stored.get_action_motion_node_chain().size() == 1 else false
	var valid: bool = stored != null and bool(row.save_finished) and bool(row.stored_initialized) and not bool(row.selected_requires_save) and bool(trace.get("persisted", false)) and bool(row.trace_available) and int(row.acquisitions) == 0
	if stored != null:
		valid = valid and bool(row.control_round_trip.valid) and bool(row.nonactive_round_trip.valid) and int(row.saved_visible_count) == 1
		if _default_context != &"idle_noncombat": valid = valid and bool(row.prepared_round_trip.valid) and bool(row.saved_clip_present) and bool(row.saved_pose_current)
	row["valid"] = valid
	_report.phases.append(row)
	_write_report()
	if not valid: _finish(label + "_contract_failed"); return false
	await _close_default_scene()
	_library = loaded
	_library.save_file_path = _output.path_join("profile_library.tres")
	return true


func _reopen_saved_default(label: String = "saved_reopen") -> bool:
	var stored: Resource = _default_draft(_library.get_saved_wip(_weapon_id), _default_context)
	var controls: Dictionary = _manual_controls(stored)
	var poses: Array = _prepared_snapshots(stored)
	if not await _open_default_context(): _finish("saved_default_reopen_failed"); return false
	if not await _wait_default_ready(label): _finish(label + "_not_ready"); return false
	if not _record_default_phase(label, _default_open_trace, false): _finish(label + "_reacquired_or_changed"); return false
	var active: Resource = _ui.call("_get_active_draft")
	var state: Dictionary = _default_state()
	var control_comparison: Dictionary = _prepared_numeric_comparison(controls, _manual_controls(active))
	var pose_comparison: Dictionary = _prepared_numeric_comparison(poses, _prepared_snapshots(active))
	var valid: bool = bool(control_comparison.valid) and bool(state.initialized)
	if _default_context != &"idle_noncombat": valid = valid and bool(pose_comparison.valid) and bool((state.prepared_pose_restore as Dictionary).get("applied", false))
	_report.phases.append({"context": String(_default_context), "phase": label + "_preserves_saved_N01", "controls": control_comparison,
		"prepared": pose_comparison, "restore": state.prepared_pose_restore, "valid": valid})
	_write_report()
	if not valid: _finish(label + "_not_reused"); return false
	await _screenshot(String(_default_context) + "_" + label + ".png")
	return true


func _edit_after_cold_reopen() -> bool:
	var node: Resource = _ui.call("_get_active_motion_node")
	var prior_signature: String = node.prepared_pose_signature
	var prior_roll: float = node.weapon_roll_degrees
	var requested_roll: float = prior_roll + 5.0
	var before: Dictionary = _begin_default_trace("edit_reopened_roll")
	var accepted: bool = _ui.set_selected_motion_node_weapon_roll(requested_roll, false)
	var current_immediately: bool = _node_current(node)
	var ready: bool = false
	if accepted: ready = await _wait_default_ready("edit_reopened_roll")
	node = _ui.call("_get_active_motion_node")
	var after: Dictionary = _solve_start_count()
	var valid: bool = ready and _node_current(node) and node.prepared_pose_signature != prior_signature and is_equal_approx(node.weapon_roll_degrees, requested_roll)
	_report.phases.append({"context": String(_default_context), "phase": "edit_reopened_roll", "accepted": accepted,
		"prior_roll_degrees": prior_roll, "requested_roll_degrees": requested_roll, "observed_roll_degrees": node.weapon_roll_degrees,
		"prior_signature": prior_signature, "new_signature": node.prepared_pose_signature, "pose_current": _node_current(node),
		"pose_current_immediately_after_edit": current_immediately, "acquisitions": int(after.get("count", 0)) - int(before.get("count", 0)),
		"acquisition_policy": "An edit may legitimately reacquire; restored read-only pose reuse is no longer required.", "valid": valid})
	_write_report()
	if not valid: _finish("edit_after_cold_reopen_failed"); return false
	if not await _save_default_without_edit("edited_pose_Save"): return false
	if not await _reopen_saved_default("edited_pose_reopen"): return false
	node = _ui.call("_get_active_motion_node")
	var retained: bool = is_equal_approx(node.weapon_roll_degrees, requested_roll)
	_report.phases.append({"context": String(_default_context), "phase": "edited_roll_retained_after_cold_reopen",
		"expected_roll_degrees": requested_roll, "observed_roll_degrees": node.weapon_roll_degrees, "valid": retained})
	_write_report()
	if not retained: _finish("edited_roll_lost_after_cold_reopen"); return false
	return true


func _reset_default_context() -> bool:
	var draft: Resource = _ui.call("_get_active_draft")
	var others: Dictionary = _default_other_sections(_ui.active_wip, draft.draft_id)
	if _default_context == DEFAULT_TEST_SLOT:
		_action(CombatAnimationStationUI.ACTION_NEW_NODE)
		if not await _wait_default_ready("before_Reset_R"): _finish("Reset_extra_node_not_ready"); return false
		if draft.get_action_motion_node_chain().size() < 2: _finish("Reset_fixture_did_not_add_node"); return false
	var count_before: int = draft.get_action_motion_node_chain().size()
	var before: Dictionary = _begin_default_trace("Reset")
	if _ui.reset_draft_button.disabled: _finish("Reset_disabled"); return false
	_ui.reset_draft_button.pressed.emit()
	if not await _wait_default_ready("Reset"): _finish("Reset_default_not_ready"); return false
	if not _record_default_phase("Reset", before, _default_context != &"idle_noncombat"):
		_finish("Reset_default_contract_failed"); return false
	draft = _ui.call("_get_active_draft")
	var preserved: Dictionary = _prepared_numeric_comparison(others, _default_other_sections(_ui.active_wip, draft.draft_id))
	var count_after: int = draft.get_action_motion_node_chain().size()
	var valid: bool = bool(preserved.valid) and count_after == 1
	var reset_seed: Dictionary = _ui.call("_resolve_active_weapon_geometry_seed_base")
	var reset_roll: float = draft.get_action_motion_node_chain()[0].weapon_roll_degrees if count_after > 0 else INF
	if _edit_reopened_requested: valid = valid and is_equal_approx(reset_roll, float(reset_seed.get("weapon_roll_degrees", 0.0)))
	_report.phases.append({"context": String(_default_context), "phase": "Reset_scope", "visible_before": count_before,
		"visible_after": count_after, "nonactive_preserved": preserved, "observed_roll_degrees": reset_roll,
		"default_roll_degrees": float(reset_seed.get("weapon_roll_degrees", 0.0)), "valid": valid})
	_write_report()
	if not valid: _finish("Reset_changed_other_sections_or_kept_nodes"); return false
	return true


func _default_draft(weapon: Resource, context_id: StringName) -> Resource:
	if weapon == null or weapon.combat_animation_station_state == null: return null
	if context_id == DEFAULT_TEST_SLOT: return _find_draft(weapon, DEFAULT_TEST_SLOT)
	for draft: Resource in weapon.combat_animation_station_state.idle_drafts:
		if draft != null and draft.context_id == context_id: return draft
	return null


func _default_other_sections(weapon: Resource, active_id: StringName) -> Dictionary:
	var result: Dictionary = {}
	if weapon == null or weapon.combat_animation_station_state == null: return result
	var station: Resource = weapon.combat_animation_station_state
	for draft: Resource in (station.skill_drafts as Array) + (station.idle_drafts as Array):
		if draft == null or draft.draft_id == active_id: continue
		result[String(draft.draft_id)] = {"controls": _manual_controls(draft), "prepared": _prepared_snapshots(draft),
			"cache_signature": draft.runtime_cache_signature, "cache": _plain(draft.baked_runtime_clip)}
	return result


func _close_default_scene() -> void:
	if _ui != null and is_instance_valid(_ui): _ui.close_ui()
	_ui = null
	if _lifecycle_world != null and is_instance_valid(_lifecycle_world): _lifecycle_world.queue_free()
	await process_frame
	await process_frame
	_lifecycle_world = null


func _write_report() -> void:
	if not _output.is_empty(): _write_json("default_pose_lifecycle.json", _report)


func _finish(reason: String) -> void:
	if _finished: return
	_finished = true
	var unchanged: bool = not _source.is_empty() and FileAccess.get_sha256(_source) == _source_hash
	_report.merge({"complete": true, "reason": reason, "context": String(_default_context),
		"wall_ms": Time.get_ticks_msec() - _started, "source_file_unchanged": unchanged,
		"ok": reason == "finished" and unchanged}, true)
	if _ui != null and is_instance_valid(_ui): _report["last_state"] = _default_state()
	_write_report()
	print("DEFAULT_POSE_LIFECYCLE finished ", reason)
	quit(0 if bool(_report.ok) else 1)
