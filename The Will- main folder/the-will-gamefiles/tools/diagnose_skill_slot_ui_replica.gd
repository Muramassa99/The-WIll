extends SceneTree

## Recreate the actual saved Slot 1 through the real station's authoring commands.
## No authored Resource or property is assigned to Slot 2 by this diagnostic.
## Exact vector arguments use the same UI-owner commands as numeric/drag input,
## avoiding the numeric widgets' coarser display increments. Rules remain active.
## Required: THE_WILL_DIAGNOSTIC_USER_ROOT, THE_WILL_GRIP_LIVE_LIBRARY,
## THE_WILL_SAVE_PROFILE_OUTPUT_DIR. All output is isolated under C:/WORKSPACE.
const WORLD = preload("res://node_3d.tscn")
const Chronology = preload("res://runtime/player/grip/grip_chronology.gd")
const SOURCE_SLOT := &"skill_slot_1"
const TARGET_SLOT := &"skill_slot_2"
const HAND := &"hand_right"
const MAX_RUN_MS := 600000
const MAX_PHASE_MS := 200000
const POSITION_EPS := 0.0001
const SCALAR_EPS := 0.00001
const ANGLE_EPS := 0.001

var _ui: CombatAnimationStationUI
var _library: Resource
var _source_draft: Resource
var _source_fingerprint := ""
var _source_snapshot: Dictionary = {}
var _source_hash := ""
var _source := ""
var _output := ""
var _weapon_id := StringName()
var _started := 0
var _finished := false
var _report: Dictionary = {"complete": false, "ok": false, "actions": [], "phases": []}
var _bone_file: FileAccess
var _last_frame_usec := 0
var _max_frame_ms := 0.0
var _measure := false
var _allow_inexact_audit := false
var _exact_source := false
var _save_first := false

func _initialize() -> void:
	_started = Time.get_ticks_msec()
	process_frame.connect(_observe_frame)
	call_deferred("_run")

func _run() -> void:
	_source = OS.get_environment("THE_WILL_GRIP_LIVE_LIBRARY").replace("\\", "/")
	_output = OS.get_environment("THE_WILL_SAVE_PROFILE_OUTPUT_DIR").replace("\\", "/")
	var expected := OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").to_lower()
	if not expected.begins_with("c:/workspace/") or OS.get_user_data_dir().replace("\\", "/").to_lower() != expected:
		push_error("Isolated diagnostic user root required."); quit(1); return
	if not _source.to_lower().begins_with("c:/workspace/") or not _output.to_lower().begins_with("c:/workspace/"):
		push_error("Workspace source/output required."); quit(1); return
	if FileAccess.file_exists(_output.path_join("ui_replica.json")) or _source.to_lower().begins_with(_output.to_lower() + "/"):
		push_error("Fresh output separate from source required."); quit(1); return
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		quit(1); return
	_source_hash = FileAccess.get_sha256(_source)
	_allow_inexact_audit = OS.get_environment("THE_WILL_AUDIT_ALLOW_INEXACT_UI_TIMING") == "1"
	_exact_source = OS.get_environment("THE_WILL_AUDIT_EXACT_SOURCE") == "1"
	_save_first = OS.get_environment("THE_WILL_AUDIT_SAVE_FIRST") == "1"
	_library = ResourceLoader.load(_source, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if _library == null: _finish("source_load_failed"); return
	_library.save_file_path = _output.path_join("profile_library.tres")
	_library.set("trace_save_latency", true)
	var requested := OS.get_environment("THE_WILL_GRIP_LIVE_WEAPON_NAME")
	if requested.is_empty(): requested = "Broken_Balde_v1"
	var selected: Resource
	for candidate: Resource in _library.saved_wips:
		if candidate.forge_project_name == requested:
			selected = candidate; break
	if selected == null: _finish("weapon_missing"); return
	_weapon_id = selected.wip_id
	var source_in_library: Resource = _find_draft(selected, SOURCE_SLOT)
	if source_in_library == null: _finish("source_slot_missing"); return
	# Immutable read-only instructions. Opening the real station can refresh
	# other drafts' derived metadata; never read a moving instruction source.
	_source_draft = source_in_library.duplicate(true)
	_source_fingerprint = _fingerprint(_source_draft)
	_source_snapshot = _plain(_source_draft)
	_report.merge({"source_path": _source, "source_sha256": _source_hash,
		"source_skill_fingerprint": _source_fingerprint, "weapon": requested,
		"source_raw_node_count": _source_draft.motion_node_chain.size(),
		"source_duration": _source_draft.get_total_transition_duration_seconds(),
		"automation": "Full main scene and real PlayerCharacter. UI commands receive read-only scalar/vector instructions; R/F use station input handler. No node-resource copy, direct authored-property assignment, or solver bypass."})
	_write_report()
	var world := WORLD.instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var player: PlayerController3D = world.get_node("PlayerCharacter")
	player.forge_wip_library_state = _library
	var station: CombatAnimationStation = world.get_node("CombatAnimationStation")
	_ui = station.station_ui as CombatAnimationStationUI
	_ui.set_meta("trace_save_latency", true)
	_ui.preview_presenter.set_meta("trace_save_latency", true)
	_bone_file = FileAccess.open(_output.path_join("bones.jsonl"), FileAccess.WRITE)
	station.interact(player)
	await process_frame
	if not _ui.open_saved_wip_with_hand_setup(_weapon_id, HAND, false, true):
		_finish("weapon_open_failed"); return
	if not _ui.select_skill_slot(SOURCE_SLOT if _exact_source else TARGET_SLOT, true): _finish("target_slot_open_failed"); return
	if not await _wait_grip("initial_target_open"): _finish("initial_grip_unavailable"); return
	if OS.get_environment("THE_WILL_AUDIT_RESET_PROBE") == "1":
		await _run_reset_probe()
		return
	if _exact_source:
		_report["timing_fixture"] = "User-authorized isolated original Slot 1, opened normally without authoring changes"
		_report["source_authored_preserved_before_F_or_Save"] = _source_authored_unchanged()
		_capture_bones("exact_source_opened")
		await _screenshot("exact_source_opened.png")
		if not _source_authored_unchanged(): _finish("source_authoring_changed_before_test"); return
	else:
		if not await _recreate_slot_two(): return
	if not await _prepare_editor_snapshots(): return
	if not _save_first:
		if not await _run_f("cold_F"): _finish("F_prepare_failed"); return
		if not await _run_f("cached_F"): _finish("cached_F_failed"); return
	if not await _run_save("cold_Save" if _save_first else "Save_after_F"): return
	if _save_first:
		if not await _run_f("cached_F_after_Save"): _finish("cached_F_after_Save_failed"); return
	if OS.get_environment("THE_WILL_AUDIT_ROLLING_WORKFLOW") == "1":
		if not _exact_source:
			_finish("rolling_workflow_requires_isolated_exact_fixture"); return
		if not await _run_rolling_workflow(): return
	_finish("finished")


func _prepare_editor_snapshots() -> bool:
	var started: int = Time.get_ticks_usec()
	var selected_index: int = _ui.get_selected_motion_node_index()
	var slot: StringName = SOURCE_SLOT if _exact_source else TARGET_SLOT
	var before: Dictionary = _manual_controls(_ui.call("_get_active_draft"))
	# Save also publishes the combat idle. Visit it visibly through its normal
	# menu-owner methods; F/Save must not discover it by solving off screen.
	if not _ui.select_authoring_mode(CombatAnimationStationState.AUTHORING_MODE_IDLE) or not _ui.select_draft(CombatAnimationDraft.IDLE_CONTEXT_COMBAT, true):
		_finish("combat_idle_UI_visit_failed"); return false
	if not await _wait_grip("capture_combat_idle_grip") or not await _wait_prepared_pose("capture_combat_idle"):
		_finish("combat_idle_snapshot_unavailable"); return false
	_report["combat_idle_prepared_pose_status"] = _ui.get_prepared_action_pose_status()
	_capture_bones("combat_idle_prepared")
	if not _ui.select_skill_slot(slot, true):
		_finish("snapshot_skill_return_failed"); return false
	var draft: Resource = _ui.call("_get_active_draft")
	var start_index: int = _ui.call("_get_user_visible_motion_node_start_index", draft)
	for index: int in range(start_index, draft.motion_node_chain.size()):
		var visit_started: int = Time.get_ticks_usec()
		if not _ui.select_motion_node(index):
			_finish("snapshot_node_selection_failed_%d" % index); return false
		if not await _wait_grip("capture_node_%d_grip" % index) or not await _wait_prepared_pose("capture_node_%d" % index):
			_finish("snapshot_node_unavailable_%d" % index); return false
		_capture_bones("prepared_node_%d" % index)
		_report.phases.append({"phase": "editor_endpoint_capture", "node_index": index,
			"wall_ms": (Time.get_ticks_usec() - visit_started) / 1000.0,
			"timing_scope": "normal UI selection, existing acquisition if needed, and two idle capture frames"})
		_write_report()
	if _ui.get_selected_motion_node_index() != selected_index:
		if not _ui.select_motion_node(selected_index) or not await _wait_grip("capture_restore_selection_grip") or not await _wait_prepared_pose("capture_restore_selection"):
			_finish("snapshot_restore_selection_failed"); return false
	var status: Dictionary = _ui.get_prepared_action_pose_status()
	_report["prepared_action_pose_status"] = status
	_report["snapshot_visit_manual_control_differences"] = _snapshot_diff(before, _manual_controls(draft), "active_skill")
	_report.phases.append({"phase": "editor_snapshot_preparation_total", "wall_ms": (Time.get_ticks_usec() - started) / 1000.0,
		"separate_from_F_and_Save": true, "source_file_unchanged": FileAccess.get_sha256(_source) == _source_hash})
	_write_report()
	if not bool(status.get("valid", false)):
		_finish("prepared_action_snapshots_incomplete"); return false
	if not _report.snapshot_visit_manual_control_differences.is_empty() or FileAccess.get_sha256(_source) != _source_hash:
		_finish("snapshot_visit_changed_authored_controls"); return false
	await _screenshot("prepared_editor_before_F.png")
	return true


func _wait_prepared_pose(label: String) -> bool:
	var started: int = Time.get_ticks_msec()
	var result: Dictionary = {}
	while Time.get_ticks_msec() - started < MAX_PHASE_MS and not _finished:
		result = _ui.capture_selected_prepared_pose()
		if bool(result.get("valid", false)):
			_report.phases.append({"phase": label, "capture_wait_ms": Time.get_ticks_msec() - started, "result": result})
			_write_report()
			return true
		await process_frame
	_report.phases.append({"phase": label, "capture_wait_ms": Time.get_ticks_msec() - started, "result": result, "ready": false})
	_write_report()
	return false

func _run_reset_probe() -> void:
	# All mutations remain in the isolated Slot 2, through the normal UI.
	var baseline: Resource = _ui.call("_get_active_draft").duplicate(true)
	_report["reset_probe"] = [{"label": "initial", "draft": _plain(baseline)}]
	_capture_bones("reset_probe_initial")
	await _observe_reset_settling("reset_probe_initial")
	if not await _author_node(_source_draft.motion_node_chain.back(), 1):
		_finish("reset_probe_authoring_failed"); return
	_report.reset_probe.append({"label": "edited", "draft": _plain(_ui.call("_get_active_draft"))})
	for repetition: int in range(2):
		_ui.reset_draft_button.pressed.emit()
		if not await _wait_grip("reset_probe_%d" % repetition):
			_finish("reset_probe_unavailable"); return
		var current: Resource = _ui.call("_get_active_draft")
		var differences: Array = []
		for index: int in mini(baseline.motion_node_chain.size(), current.motion_node_chain.size()):
			for difference: Dictionary in _node_diff(baseline.motion_node_chain[index], current.motion_node_chain[index], index == 0):
				difference["index"] = index
				differences.append(difference)
		_report.reset_probe.append({"label": "reset_%d" % repetition, "draft": _plain(current),
			"node_control_differences_from_initial": differences,
			"restored_hand_reference": _plain(_ui.get_meta("last_reset_baseline_frame", {})),
			"node_count": current.motion_node_chain.size()})
		_capture_bones("reset_probe_%d" % repetition)
		await _observe_reset_settling("reset_probe_%d" % repetition)
	await _screenshot("after_reset.png")
	_finish("finished")

func _observe_reset_settling(label: String) -> void:
	# Observe normal frames only; do not force a pose refresh or change inputs.
	var elapsed_seconds := 0
	for seconds: int in [1, 2, 3]:
		await create_timer(float(seconds)).timeout
		elapsed_seconds += seconds
		_capture_bones("%s_settled_%ds" % [label, elapsed_seconds])
	await _screenshot(label + "_settled.png")

func _recreate_slot_two() -> bool:
	var before_reset: Resource = _ui.call("_get_active_draft")
	_report["hidden_entry_before_Reset"] = _node_diff(_source_draft.motion_node_chain[0], before_reset.motion_node_chain[0], true)
	_capture_bones("before_Reset")
	_ui.reset_draft_button.pressed.emit()
	if not await _wait_grip("reset_target_baseline"): _finish("reset_grip_unavailable"); return false
	var draft: Resource = _ui.call("_get_active_draft")
	_report["natural_hidden_entry_comparison"] = _node_diff(_source_draft.motion_node_chain[0], draft.motion_node_chain[0], true)
	_capture_bones("target_baseline")
	var targets: Array = _source_draft.motion_node_chain
	for index: int in range(1, targets.size()):
		if index > 1: _action(CombatAnimationStationUI.ACTION_NEW_NODE)
		if int(_ui.get_selected_motion_node_index()) != index:
			_finish("R_did_not_select_expected_node_%d" % index); return false
		if not await _author_node(targets[index], index):
			_finish("node_%d_authoring_failed" % index); return false
	_ui.set_active_draft_preview_speed(float(_source_draft.preview_playback_speed_scale))
	_ui.set_active_draft_speed_acceleration_percent(float(_source_draft.speed_acceleration_percent))
	_ui.set_active_draft_speed_deceleration_percent(float(_source_draft.speed_deceleration_percent))
	_ui.set_active_draft_preview_loop(bool(_source_draft.preview_loop_enabled))
	_report["replica_comparison"] = _compare_chain()
	_report["timing_fixture"] = "UI-created non-equivalent Slot 2; differences are retained in replica_comparison" if not bool(_report.replica_comparison.equivalent) else "equivalent UI-created Slot 2"
	_report["source_preserved_before_F"] = _source_unchanged()
	_report["source_authored_preserved_before_F"] = _source_authored_unchanged()
	await _screenshot("authoring_final.png")
	_write_report()
	if not bool(_report.replica_comparison.equivalent) and not _allow_inexact_audit:
		_finish("UI_constraints_prevented_equivalent_replica_no_timing_or_Save"); return false
	if not _source_authored_unchanged(): _finish("source_authoring_changed_in_memory"); return false
	return true

func _run_save(label: String, expected_skill: Resource = null) -> bool:
	var expected: Resource = expected_skill if expected_skill != null else _source_draft
	var active_before: Resource = _ui.call("_get_active_draft")
	var before_prepared: Array = _prepared_snapshots(active_before)
	var active_slot: StringName = active_before.owning_skill_id
	var save_started := Time.get_ticks_usec()
	_start_measure()
	_ui.save_button.pressed.emit()
	while _ui.manual_save_in_progress and Time.get_ticks_usec() - save_started < MAX_PHASE_MS * 1000:
		await process_frame
	_measure = false
	var save_row := {"phase": label, "wall_ms": (Time.get_ticks_usec() - save_started) / 1000.0,
		"max_process_frame_ms": _max_frame_ms, "dirty": _ui.editor_state_dirty,
		"status": _ui.footer_status_label.text, "trace": _ui.get_meta("last_save_latency_trace", {}),
		"saved_file_exists": FileAccess.file_exists(String(_library.save_file_path))}
	_report.phases.append(save_row)
	_capture_bake_grip_metrics(label)
	var saved_clip: Resource = _ui.call("_get_active_draft").baked_runtime_clip
	if saved_clip != null: _write_json(label + "_solved_clip.json", _plain(saved_clip))
	_capture_bones("after_Save")
	if not bool(save_row.saved_file_exists) or bool(save_row.dirty): _finish("Save_failed"); return false
	_report["source_preserved_after_Save"] = _source_unchanged()
	_report["source_authored_preserved_after_Save"] = _source_authored_unchanged()
	var reloaded: Resource = ResourceLoader.load(_library.save_file_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var saved_weapon: Resource = reloaded.get_saved_wip(_weapon_id) if reloaded != null else null
	_report["saved_slot1_fingerprint"] = _fingerprint(_find_draft(saved_weapon, SOURCE_SLOT))
	_report["saved_slot1_preserved"] = _report.saved_slot1_fingerprint == _source_fingerprint
	_report["saved_slot1_authoring_preserved"] = _authored_snapshot(_find_draft(saved_weapon, SOURCE_SLOT)) == _authored_snapshot(_source_draft)
	_report["saved_slot1_manual_controls_differences"] = _snapshot_diff(_manual_controls(expected), _manual_controls(_find_draft(saved_weapon, SOURCE_SLOT)), "skill1")
	var reloaded_active: Resource = _find_draft(saved_weapon, active_slot)
	var prepared_round_trip: Dictionary = _prepared_numeric_comparison(before_prepared, _prepared_snapshots(reloaded_active))
	save_row["prepared_snapshot_round_trip"] = prepared_round_trip
	save_row["prepared_snapshot_count"] = before_prepared.size()
	save_row["intentional_isolated_skill_edits"] = expected_skill != null
	if not _report.saved_slot1_manual_controls_differences.is_empty() or FileAccess.get_sha256(_source) != _source_hash:
		_finish("source_slot_manual_controls_preservation_guard_failed"); return false
	if not bool(prepared_round_trip.valid):
		_finish("prepared_snapshots_changed_on_Save_reload"); return false
	return true


func _run_rolling_workflow() -> bool:
	# This opt-in phase runs only AFTER baseline timings/Save and deliberately
	# edits the isolated exact fixture through the normal UI. The real source
	# library is never written, and its disk hash remains a mandatory guard.
	_report["rolling_workflow"] = {"scope": "Intentional UI edits to isolated Skill 1 after baseline Save; real Skill 1 file remains untouched."}
	var draft: Resource = _ui.call("_get_active_draft")
	var first: int = _ui.call("_get_user_visible_motion_node_start_index", draft)
	var count: int = draft.motion_node_chain.size()
	if count - first < 3:
		_finish("rolling_fixture_needs_three_visible_nodes"); return false
	var middle: int = first + (count - first) / 2
	if not _ui.select_motion_node(middle) or not await _wait_grip("rolling_middle_grip") or not await _wait_prepared_pose("rolling_middle_pose"):
		_finish("rolling_middle_selection_failed"); return false
	var node: Resource = _ui.call("_get_active_motion_node")
	var snapshot_before: Dictionary = node.prepared_pose.duplicate(true)
	var signature_before: String = node.prepared_pose_signature
	var duration_before: float = node.transition_duration_seconds
	if not _ui.set_selected_motion_node_transition_duration(duration_before + 0.25, false):
		_finish("rolling_duration_edit_rejected"); return false
	_report.rolling_workflow["duration_edit_preserved_pose"] = node.prepared_pose == snapshot_before and node.prepared_pose_signature == signature_before
	_report.rolling_workflow["duration_edit_node"] = middle
	if not bool(_report.rolling_workflow.duration_edit_preserved_pose):
		_finish("duration_edit_invalidated_stored_pose"); return false
	if not await _run_f("duration_edit_F"):
		_finish("duration_edit_F_failed"); return false
	if not _ui.select_motion_node(count - 1) or not await _wait_grip("rolling_last_grip") or not await _wait_prepared_pose("rolling_last_pose"):
		_finish("rolling_last_selection_failed"); return false
	_action(CombatAnimationStationUI.ACTION_NEW_NODE)
	if draft.motion_node_chain.size() != count + 1 or _ui.get_selected_motion_node_index() != count:
		_finish("rolling_R_did_not_append_and_select_node"); return false
	var appended: Resource = _ui.call("_get_active_motion_node")
	var old_tip: Vector3 = appended.tip_position_local
	var old_pommel: Vector3 = appended.pommel_position_local
	var offset := Vector3(0.0, 0.015, 0.0)
	_ui.set_selected_motion_node_pommel_position(old_pommel + offset, false)
	_ui.set_selected_motion_node_tip_position(old_tip + offset, false)
	if not await _wait_grip("rolling_appended_grip") or not await _wait_prepared_pose("rolling_appended_pose"):
		_finish("rolling_appended_pose_unavailable"); return false
	_report.rolling_workflow["appended_selected_index"] = _ui.get_selected_motion_node_index()
	_report.rolling_workflow["appended_pose_ready_before_F"] = not appended.prepared_pose.is_empty()
	if not await _run_f("appended_node_F"):
		_finish("appended_node_F_failed"); return false
	var clip: Resource = draft.baked_runtime_clip
	if clip == null or clip.get_frame_count() < 1:
		_finish("appended_node_F_has_no_prepared_clip"); return false
	var endpoint: Dictionary = _prepared_endpoint_comparison(appended.prepared_pose, clip, clip.get_frame_count() - 1)
	_report.rolling_workflow["final_replay_endpoint"] = endpoint
	_report.rolling_workflow["rendered_action_node_count"] = clip.motion_node_chain.size()
	_report.rolling_workflow["expected_action_node_count"] = draft.get_action_motion_node_chain().size()
	if not bool(endpoint.valid) or clip.motion_node_chain.size() != draft.get_action_motion_node_chain().size():
		_finish("appended_node_missing_from_F_endpoint"); return false
	var expected_after_edits: Resource = draft.duplicate(true)
	if not await _run_save("rolling_Save", expected_after_edits): return false
	_report.rolling_workflow["real_source_file_unchanged"] = FileAccess.get_sha256(_source) == _source_hash
	_write_report()
	return true


func _prepared_snapshots(draft: Resource) -> Array:
	var result: Array = []
	if draft == null: return result
	for node: Resource in draft.get_action_motion_node_chain():
		result.append({"signature": node.prepared_pose_signature, "pose": _plain(node.prepared_pose)})
	return result


func _prepared_endpoint_comparison(snapshot: Dictionary, clip: Resource, index: int) -> Dictionary:
	if clip == null or index < 0: return {"valid": false, "reason": "missing_clip_endpoint"}
	var actual := {
		"bone_names": clip.baked_solved_upper_body_bone_names,
		"pose_positions": clip.baked_solved_upper_body_pose_positions[index],
		"pose_rotations": clip.baked_solved_upper_body_pose_rotations[index],
		"pose_scales": clip.baked_solved_upper_body_pose_scales[index],
		"weapon_position_reference_local": clip.baked_solved_weapon_positions_reference_local[index],
		"weapon_rotation_reference_local": clip.baked_solved_weapon_rotations_reference_local[index],
		"weapon_scale_reference_local": clip.baked_solved_weapon_scales_reference_local[index],
		"anchor_positions_weapon_local": clip.baked_solved_anchor_positions_weapon_local[index],
		"anchor_rotations_weapon_local": clip.baked_solved_anchor_rotations_weapon_local[index],
		"anchor_scales_weapon_local": clip.baked_solved_anchor_scales_weapon_local[index],
	}
	var expected: Dictionary = {}
	for field: String in actual: expected[field] = snapshot.get(field)
	return _prepared_numeric_comparison(_plain(expected), _plain(actual))


func _prepared_numeric_comparison(expected: Variant, actual: Variant) -> Dictionary:
	var result := {"valid": true, "max_numeric_error": 0.0, "numeric_tolerance": 0.000001, "differences": []}
	_append_prepared_difference(expected, actual, "prepared", result)
	result.valid = result.differences.is_empty()
	return result


func _append_prepared_difference(expected: Variant, actual: Variant, path: String, result: Dictionary) -> void:
	if result.differences.size() >= 30: return
	if expected is Dictionary and actual is Dictionary:
		if expected.size() != actual.size(): result.differences.append({"path": path, "reason": "dictionary_size"})
		for key: Variant in expected:
			if not actual.has(key): result.differences.append({"path": path + "." + str(key), "reason": "missing"})
			else: _append_prepared_difference(expected[key], actual[key], path + "." + str(key), result)
	elif expected is Array and actual is Array:
		if expected.size() != actual.size(): result.differences.append({"path": path, "reason": "array_size"})
		for index: int in mini(expected.size(), actual.size()):
			_append_prepared_difference(expected[index], actual[index], path + "[%d]" % index, result)
	elif (expected is float or expected is int) and (actual is float or actual is int):
		var error: float = absf(float(expected) - float(actual))
		result.max_numeric_error = maxf(float(result.max_numeric_error), error)
		if not is_finite(error) or error > float(result.numeric_tolerance): result.differences.append({"path": path, "error": error})
	elif expected != actual:
		result.differences.append({"path": path, "expected": str(expected).left(80), "actual": str(actual).left(80)})

func _author_node(target: CombatAnimationMotionNode, index: int) -> bool:
	if target.generated_transition_node or target.preferred_grip_style_mode != &"grip_normal" or target.primary_hand_slot != HAND:
		_report["unsupported_source_node"] = index
		return false
	var started := Time.get_ticks_usec()
	_ui.set_selected_motion_node_two_hand_state(target.two_hand_state, false)
	_ui.set_selected_motion_node_body_support_blend(target.body_support_blend, false)
	await _record_edit("node_%d_body_support" % index)
	_ui.set_selected_motion_node_upperarm_roll(HAND, target.right_upperarm_roll_degrees, false)
	await _record_edit("node_%d_right_elbow_orbit" % index)
	_ui.set_selected_motion_node_upperarm_roll(&"hand_left", target.left_upperarm_roll_degrees, false)
	await _record_edit("node_%d_left_elbow_orbit" % index)
	_ui.set_selected_motion_node_grip_seat_slide(target.grip_seat_slide_offset, false)
	if not await _wait_grip("node_%d_seat" % index): return false
	_capture_bones("node_%d_before_endpoints" % index)
	_ui.set_selected_motion_node_pommel_position(target.pommel_position_local, false)
	await _record_edit("node_%d_pommel" % index)
	_ui.set_selected_motion_node_tip_position(target.tip_position_local, false)
	await _record_edit("node_%d_tip" % index)
	_ui.set_selected_motion_node_weapon_orientation(target.weapon_orientation_degrees, false)
	await _record_edit("node_%d_orientation" % index)
	if not await _wait_grip("node_%d_before_roll" % index): return false
	_ui.set_selected_motion_node_weapon_roll(target.weapon_roll_degrees, false)
	if not await _wait_grip("node_%d_after_roll" % index): return false
	await _record_edit("node_%d_weapon_roll" % index)
	_ui.set_selected_motion_node_tip_curve_in(target.tip_curve_in_handle, false)
	_ui.set_selected_motion_node_tip_curve_out(target.tip_curve_out_handle, false)
	_ui.set_selected_motion_node_pommel_curve_in(target.pommel_curve_in_handle, false)
	_ui.set_selected_motion_node_pommel_curve_out(target.pommel_curve_out_handle, false)
	_ui.set_selected_motion_node_transition_duration(target.transition_duration_seconds, false)
	if target.left_hand_proxy_authored:
		_ui.set_selected_motion_node_hand_proxy_segment(&"hand_left", target.left_hand_proxy_tip_position_local, target.left_hand_proxy_pommel_position_local, false)
	else:
		_ui.clear_selected_motion_node_hand_proxy_segment(&"hand_left", false)
	if target.right_hand_proxy_authored:
		_ui.set_selected_motion_node_hand_proxy_segment(HAND, target.right_hand_proxy_tip_position_local, target.right_hand_proxy_pommel_position_local, false)
	else:
		_ui.clear_selected_motion_node_hand_proxy_segment(HAND, false)
	if not await _wait_grip("node_%d_final_pose" % index) or not await _wait_prepared_pose("node_%d_capture" % index):
		return false
	_capture_bones("node_%d_completed" % index)
	var actual: CombatAnimationMotionNode = _ui.call("_get_active_motion_node")
	var row := {"node_index": index, "wall_ms": (Time.get_ticks_usec() - started) / 1000.0,
		"differences": _node_diff(target, actual, false), "status": _ui.footer_status_label.text}
	_report.actions.append(row)
	_write_report()
	print("UI_REPLICA node=%d differences=%d" % [index, row.differences.size()])
	# Continue collecting the creation audit across every node. Final fidelity
	# still gates F and Save; a mismatch is never silently accepted as a replica.
	return true

func _record_edit(label: String) -> void:
	await process_frame
	_capture_bones(label)
	if not _report.has("editor_steps"): _report["editor_steps"] = []
	_report.editor_steps.append({"label": label, "wall_ms": Time.get_ticks_msec() - _started,
		"node": _plain(_ui.call("_get_active_motion_node")), "status": _ui.footer_status_label.text})
	_write_report()

func _wait_grip(label: String) -> bool:
	var started := Time.get_ticks_msec()
	var stable_since := 0
	var last_log := 0
	var state: Dictionary = {}
	while Time.get_ticks_msec() - started < MAX_PHASE_MS and not _finished:
		var context: Dictionary = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
		if not context.is_empty():
			var owner: Node = context.actor.get_node_or_null("PreparedGripAcquisition")
			if owner != null:
				var binding: Dictionary = context.actor.get_planar_grip_pose_state(HAND)
				var statuses: Dictionary = owner.status()
				state = statuses.get(HAND, {})
				var ready: bool = owner._primary_ready_for_support() and bool(binding.get("has_grip_pose", false)) and not _ui.preview_presenter.is_grip_acquisition_pending(_ui.preview_subviewport) and not _ui.preview_drag_refresh_pending
				if ready:
					if stable_since == 0: stable_since = Time.get_ticks_msec()
					if Time.get_ticks_msec() - stable_since >= 500:
						_report.phases.append({"phase": label, "wait_ms": Time.get_ticks_msec() - started, "status": state})
						_write_report(); return true
				else: stable_since = 0
				if String(state.get("status", "")) in ["unresolved", "unavailable", "cancelled"]:
					break
		if Time.get_ticks_msec() - last_log > 5000:
			last_log = Time.get_ticks_msec()
			print("UI_REPLICA wait=%s elapsed=%d status=%s" % [label, last_log - started, str(state.get("status", ""))])
		await process_frame
	_report.phases.append({"phase": label, "wait_ms": Time.get_ticks_msec() - started, "ready": false, "status": state})
	_write_report()
	return false

func _run_f(label: String) -> bool:
	Chronology.event("audit.F_measurement_begin", {"label": label, "terminal": true})
	var trace_before: Dictionary = _solve_start_count()
	var started := Time.get_ticks_usec()
	var progress_rows: Array = []
	var previous_progress_key := ""
	_start_measure()
	_action(CombatAnimationStationUI.ACTION_PREVIEW_PLAYBACK)
	while _ui.preview_prepare_in_progress and Time.get_ticks_usec() - started < MAX_PHASE_MS * 1000 and not _finished:
		var progress: Dictionary = _ui.get_meta("last_preview_prepare_progress", {})
		var key := "%s:%d:%d" % [str(progress.get("stage", "waiting")), int(progress.get("sampled_frames", -1)), int(progress.get("completed_frames", -1))]
		if key != previous_progress_key:
			previous_progress_key = key
			progress_rows.append({"elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0, "progress": progress.duplicate(true)})
			_write_json(label + "_progress.json", progress_rows)
			print("UI_REPLICA F=%s elapsed=%.3fs progress=%s" % [label, (Time.get_ticks_usec() - started) / 1000000.0, key])
		await process_frame
	_measure = false
	var prepare_wall_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	Chronology.event("audit.F_preparation_finished", {"label": label, "terminal": true})
	var trace_prepared: Dictionary = _solve_start_count()
	var row := {"phase": label, "wall_ms": (Time.get_ticks_usec() - started) / 1000.0,
		"max_process_frame_ms": _max_frame_ms, "result": _ui.get_meta("last_preview_prepare_result", {}),
		"progress": _ui.get_meta("last_preview_prepare_progress", {}), "playing": _ui.chain_player.is_playing()}
	row["wall_ms"] = prepare_wall_ms
	row["grip_trace_available"] = bool(trace_before.available) and bool(trace_prepared.available)
	row["prepare_solve_started_delta"] = int(trace_prepared.count) - int(trace_before.count) if row.grip_trace_available else -1
	_report.phases.append(row)
	_capture_bake_grip_metrics(label)
	_write_json(label + "_progress.json", progress_rows)
	_write_report()
	if not bool(row.playing): return false
	var draft: Resource = _ui.call("_get_active_draft")
	var clip: Resource = draft.baked_runtime_clip
	if label == "cold_F" and clip != null:
		_write_json("replica_solved_clip.json", _plain(clip))
	var played := Time.get_ticks_msec()
	var captured_screenshot := false
	while _ui.chain_player.is_playing() and Time.get_ticks_msec() - played < 30000 and not _finished:
		_capture_bones(label + "_playback")
		if not captured_screenshot and Time.get_ticks_msec() - played > 300:
			await _screenshot(label + "_playback.png")
			captured_screenshot = true
		await process_frame
	if _ui.chain_player.is_playing(): _action(CombatAnimationStationUI.ACTION_PREVIEW_PLAYBACK)
	Chronology.event("audit.F_measurement_end", {"label": label, "terminal": true})
	var trace_after: Dictionary = _solve_start_count()
	row["whole_F_solve_started_delta"] = int(trace_after.count) - int(trace_before.count) if row.grip_trace_available and trace_after.available else -1
	row["zero_acquisition_calls_observed"] = row.whole_F_solve_started_delta == 0
	_write_report()
	return int(row.whole_F_solve_started_delta) <= 0


func _solve_start_count() -> Dictionary:
	var path: String = OS.get_environment("THE_WILL_GRIP_TRACE_PATH")
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"available": false, "count": 0}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"available": false, "count": 0}
	var count: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		if not line.contains("owner.solve_started"):
			continue
		var record: Variant = JSON.parse_string(line)
		if record is Dictionary and String(record.get("name", "")) == "owner.solve_started":
			count += 1
	file.close()
	return {"available": true, "count": count}

func _action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_ui._unhandled_input(event)

func _compare_chain() -> Dictionary:
	var target: Resource = _ui.call("_get_active_draft")
	var differences: Array = []
	if target.motion_node_chain.size() != _source_draft.motion_node_chain.size():
		differences.append({"field": "node_count", "actual": target.motion_node_chain.size()})
	for index: int in mini(target.motion_node_chain.size(), _source_draft.motion_node_chain.size()):
		for difference: Dictionary in _node_diff(_source_draft.motion_node_chain[index], target.motion_node_chain[index], index == 0):
			difference["index"] = index
			differences.append(difference)
	return {"equivalent": differences.is_empty(), "differences": differences,
		"position_tolerance_m": POSITION_EPS, "angle_tolerance_degrees": ANGLE_EPS,
		"scalar_tolerance": SCALAR_EPS, "exclusions": "node IDs, retarget-derived Resource, draft slot identity; hidden0 orientation-authored flag remains normal factory owned"}

func _node_diff(expected: Resource, actual: Resource, hidden: bool) -> Array:
	var differences: Array = []
	var fields := ["tip_position_local", "pommel_position_local", "tip_curve_in_handle", "tip_curve_out_handle", "pommel_curve_in_handle", "pommel_curve_out_handle", "weapon_orientation_degrees", "weapon_roll_degrees", "right_upperarm_roll_degrees", "left_upperarm_roll_degrees", "transition_duration_seconds", "body_support_blend", "axial_reposition_offset", "grip_seat_slide_offset", "secondary_grip_seat_slide_offset", "primary_hand_slot", "two_hand_state", "preferred_grip_style_mode", "left_hand_proxy_authored", "right_hand_proxy_authored"]
	if not hidden: fields.append("weapon_orientation_authored")
	for hand: String in ["left", "right"]:
		if bool(expected.get(hand + "_hand_proxy_authored")):
			fields.append(hand + "_hand_proxy_tip_position_local")
			fields.append(hand + "_hand_proxy_pommel_position_local")
	for field: String in fields:
		var a: Variant = expected.get(field)
		var b: Variant = actual.get(field)
		var delta := 0.0
		var tolerance := ANGLE_EPS if field.contains("degrees") else SCALAR_EPS
		var matches: bool = a == b
		if a is Vector3 and b is Vector3:
			delta = (a as Vector3).distance_to(b as Vector3)
			if not field.contains("degrees"): tolerance = POSITION_EPS
			matches = delta <= tolerance
		elif a is float and b is float:
			delta = absf(float(a) - float(b)); matches = delta <= tolerance
		if not matches: differences.append({"field": field, "expected": str(a), "actual": str(b), "delta": delta, "tolerance": tolerance})
	return differences

func _capture_bones(label: String) -> void:
	if _bone_file == null or _ui == null: return
	var preview: Node = _ui.call("_get_preview_root")
	if preview == null: return
	var skeletons: Array = []
	for candidate: Node in preview.find_children("*", "Skeleton3D", true, false):
		var skeleton := candidate as Skeleton3D
		var bones: Array = []
		for index: int in skeleton.get_bone_count():
			bones.append({"index": index, "name": skeleton.get_bone_name(index), "parent": skeleton.get_bone_parent(index),
				"local_pose": _transform(skeleton.get_bone_pose(index)),
				"skeleton_pose": _transform(skeleton.get_bone_global_pose(index)),
				"world_pose": _transform(skeleton.global_transform * skeleton.get_bone_global_pose(index)),
				"rest": _transform(skeleton.get_bone_rest(index))})
		skeletons.append({"path": str(preview.get_path_to(skeleton)), "bones": bones})
	_bone_file.store_line(JSON.stringify({"label": label, "wall_ms": Time.get_ticks_msec() - _started,
		"selected_node": _ui.get_selected_motion_node_index(), "clip_time": _ui.chain_player._clip_elapsed,
		"clip_frame": _ui.chain_player._clip_frame_index, "skeletons": skeletons}))
	_bone_file.flush()

func _transform(value: Transform3D) -> Array:
	return [value.basis.x.x, value.basis.x.y, value.basis.x.z, value.basis.y.x, value.basis.y.y, value.basis.y.z,
		value.basis.z.x, value.basis.z.y, value.basis.z.z, value.origin.x, value.origin.y, value.origin.z]

func _plain(value: Variant) -> Variant:
	if value is Resource:
		var result: Dictionary = {"class": value.get_class()}
		for property: Dictionary in value.get_property_list():
			var key := String(property.name)
			if (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0 or key in ["resource_path", "resource_scene_unique_id"]: continue
			if key == "script":
				var script: Script = value.get_script()
				result[key] = script.resource_path if script != null else ""
			else:
				result[key] = _plain(value.get(key))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[String(key)] = _plain(value[key])
		return result
	if value is Array or typeof(value) in [TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_VECTOR4_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY]:
		var result: Array = []
		for child: Variant in value: result.append(_plain(child))
		return result
	if value is Vector3: return [value.x, value.y, value.z]
	if value is Vector4 or value is Quaternion: return [value.x, value.y, value.z, value.w]
	if value is Transform3D: return _transform(value)
	if value is StringName: return String(value)
	return value

func _fingerprint(value: Resource) -> String:
	return var_to_bytes(_plain(value)).hex_encode().sha256_text()

func _find_draft(weapon: Resource, slot: StringName) -> Resource:
	if weapon == null or weapon.combat_animation_station_state == null: return null
	for draft: Resource in weapon.combat_animation_station_state.skill_drafts:
		if draft.owning_skill_id == slot: return draft
	return null

func _source_unchanged() -> bool:
	var persisted: Resource = _find_draft(_library.get_saved_wip(_weapon_id), SOURCE_SLOT)
	var active: Resource = _find_draft(_ui.active_wip, SOURCE_SLOT)
	return _fingerprint(persisted) == _source_fingerprint and _fingerprint(active) == _source_fingerprint and FileAccess.get_sha256(_source) == _source_hash

func _authored_snapshot(draft: Resource) -> Dictionary:
	var snapshot: Dictionary = _without_prepared_snapshots(_plain(draft)) if draft != null else {}
	snapshot.erase("baked_runtime_clip")
	snapshot.erase("runtime_cache_signature")
	return snapshot

func _manual_controls(draft: Resource) -> Dictionary:
	var snapshot := _authored_snapshot(draft)
	# The new saved action intentionally omits Reset, while reconstructing an
	# editor placeholder on load. Compare every visible node, not that fallback.
	if draft != null and draft.has_method("get_action_motion_node_chain"):
		snapshot["motion_node_chain"] = _without_prepared_snapshots(_plain(draft.get_action_motion_node_chain()))
	snapshot.erase("action_motion_node_chain")
	snapshot.erase("action_baseline_signature")
	snapshot.erase("selected_motion_node_index")
	for node: Dictionary in snapshot.get("motion_node_chain", []):
		node.erase("retarget_node")
	return snapshot


func _without_prepared_snapshots(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			if String(key) not in ["prepared_pose", "prepared_pose_signature"]:
				result[key] = _without_prepared_snapshots(value[key])
		return result
	if value is Array:
		var result: Array = []
		for child: Variant in value:
			result.append(_without_prepared_snapshots(child))
		return result
	return value

func _source_authored_unchanged() -> bool:
	return _authored_snapshot(_find_draft(_library.get_saved_wip(_weapon_id), SOURCE_SLOT)) == _authored_snapshot(_source_draft) and _authored_snapshot(_find_draft(_ui.active_wip, SOURCE_SLOT)) == _authored_snapshot(_source_draft) and FileAccess.get_sha256(_source) == _source_hash

func _start_measure() -> void:
	_max_frame_ms = 0.0; _last_frame_usec = Time.get_ticks_usec(); _measure = true

func _observe_frame() -> void:
	var now := Time.get_ticks_usec()
	if _measure and _last_frame_usec > 0: _max_frame_ms = maxf(_max_frame_ms, (now - _last_frame_usec) / 1000.0)
	_last_frame_usec = now
	if not _finished and Time.get_ticks_msec() - _started > MAX_RUN_MS: _finish("bounded_run_timeout")

func _screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	# Rendering may be suspended while the window is minimized/occluded. Never
	# leave the audit waiting forever for a presentation-only screenshot.
	var drawn: Dictionary = {"ready": false}
	var completed: Callable = func() -> void: drawn.ready = true
	RenderingServer.frame_post_draw.connect(completed, CONNECT_ONE_SHOT)
	var started: int = Time.get_ticks_msec()
	while not bool(drawn.ready) and Time.get_ticks_msec() - started < 3000 and not _finished:
		await process_frame
	if RenderingServer.frame_post_draw.is_connected(completed):
		RenderingServer.frame_post_draw.disconnect(completed)
	if not _report.has("screenshots"): _report["screenshots"] = []
	if not bool(drawn.ready) or _finished:
		_report.screenshots.append({"file": name, "saved": false, "reason": "render_frame_timeout"})
		_write_report()
		return
	var image: Image = root.get_texture().get_image()
	var error: int = image.save_png(_output.path_join(name)) if image != null and not image.is_empty() else ERR_UNAVAILABLE
	_report.screenshots.append({"file": name, "saved": error == OK, "error": error})
	_write_report()

func _write_json(name: String, data: Variant) -> void:
	var file := FileAccess.open(_output.path_join(name), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(data, "\t"))

func _write_report() -> void:
	if not _output.is_empty(): _write_json("ui_replica.json", _report)

func _capture_bake_grip_metrics(label: String) -> void:
	# Inspect completed private bake checkpoints after the timed operation.
	# The live editor owner has already been restored and is not the bake state.
	var rows: Array = []
	var caches: Dictionary = _ui.preview_presenter.get("_pose_render_caches")
	for cache_key: Variant in caches:
		var checkpoints: Dictionary = caches[cache_key].get("checkpoints", {})
		var indices: Array = checkpoints.keys()
		if indices.is_empty(): continue
		indices.sort()
		var checkpoint: Dictionary = checkpoints[indices.back()]
		var entries: Dictionary = checkpoint.get("grip", {}).get("state", {}).get("_replay_pose_cache", {})
		for relationship: Variant in entries:
			var status: Dictionary = entries[relationship].get("status", {})
			rows.append({"clip_key": str(cache_key), "checkpoint": indices.back(), "relationship": str(relationship),
				"solver_total_ms": status.get("solver_total_ms", -1), "solver_totals": _plain(status.get("solver_totals", {})),
				"status": status.get("status", ""), "actual_3d_grip_verified": status.get("actual_3d_grip_verified", false),
				"contact_condition_met": status.get("contact_condition_met", false)})
	_write_json(label + "_grip_metrics.json", rows)

func _finish(reason: String) -> void:
	if _finished: return
	_finished = true
	_report.merge({"complete": true, "reason": reason, "wall_ms": Time.get_ticks_msec() - _started,
		"ok": reason == "finished", "source_file_unchanged": not _source.is_empty() and FileAccess.get_sha256(_source) == _source_hash}, true)
	if _ui != null and is_instance_valid(_ui):
		_report["last_status"] = _ui.footer_status_label.text
		_report["source_slot_preserved"] = _source_unchanged()
		var current_source: Resource = _find_draft(_ui.active_wip, SOURCE_SLOT)
		_report["source_in_memory_differences"] = _snapshot_diff(_source_snapshot, _plain(current_source), "skill1")
		if _ui.preview_prepare_in_progress: _ui.call("_cancel_preview_preparation")
		if _ui.chain_player.is_playing(): _action(CombatAnimationStationUI.ACTION_PREVIEW_PLAYBACK)
	if _bone_file != null: _bone_file.close()
	_write_report()
	print("UI_REPLICA finished " + reason)
	quit(0 if bool(_report.ok) else 1)

func _snapshot_diff(a: Variant, b: Variant, path: String) -> Array:
	var result: Array = []
	_append_snapshot_diff(a, b, path, result)
	return result

func _append_snapshot_diff(a: Variant, b: Variant, path: String, result: Array) -> Array:
	if result.size() >= 60: return result
	if a is Dictionary and b is Dictionary:
		for key: Variant in a:
			if not b.has(key): result.append({"path": path + "." + str(key), "reason": "missing"})
			else: _append_snapshot_diff(a[key], b[key], path + "." + str(key), result)
	elif a is Array and b is Array:
		if a.size() != b.size(): result.append({"path": path, "before_size": a.size(), "after_size": b.size()})
		for index: int in mini(a.size(), b.size()): _append_snapshot_diff(a[index], b[index], path + "[%d]" % index, result)
	elif a != b:
		result.append({"path": path, "before": str(a).left(160), "after": str(b).left(160)})
	return result
