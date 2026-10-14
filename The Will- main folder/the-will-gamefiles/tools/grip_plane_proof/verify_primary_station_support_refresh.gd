extends "res://tools/grip_plane_proof/verify_surface_grip_support.gd"

## Actual UI dependency regression. No replacement solver, Save, or pose writes.
## Default: right main, reverse style, primary 63% -> 58%, support 20% -> 22%.
## Input is a read-only workspace library copy; all incidental writes isolated.
const Wip = preload("res://core/models/crafted_item_wip.gd")
const Trace = preload("res://runtime/player/grip/grip_chronology.gd")
const MountedSeedProbe = preload("res://tools/grip_plane_proof/diagnose_grip_mounted_seed.gd")
const LIMIT_SECONDS := 60.0
var _trace_path := ""

func _run() -> void:
	_prefix = "C:/WORKSPACE/test_artifacts/primary_station_support_refresh_" + Time.get_datetime_string_from_system().replace(":", "-")
	_report = {"scope": "actual_ui_primary_station_invalidates_support_after_primary_seat", "visual_grip_certified": false}
	_source = OS.get_environment("THE_WILL_GRIP_LIVE_LIBRARY").strip_edges()
	_trace_path = OS.get_environment("THE_WILL_GRIP_TRACE_PATH").strip_edges()
	var isolation := OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").simplify_path().to_lower()
	if not _check(_workspace(isolation) and isolation == OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower(), "incidental writes isolated inside workspace"):
		_finish(); return
	if not _check(_workspace(_source) and FileAccess.file_exists(_source), "input library is an existing workspace copy"):
		_finish(); return
	if not _check(_workspace(_trace_path) and _trace_path.get_extension() == "jsonl" and not FileAccess.file_exists(_trace_path), "chronology has a fresh workspace JSONL path"):
		_finish(); return
	_source_hash = FileAccess.get_sha256(_source)
	var input: Resource = ResourceLoader.load(_source, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _check(input != null, "actual saved library loads"):
		_finish(); return
	var weapon_name := OS.get_environment("THE_WILL_GRIP_LIVE_WEAPON_NAME").strip_edges()
	if weapon_name.is_empty(): weapon_name = "Stage 1 V2 Draft Copy"
	var chosen: Resource
	for wip: Resource in input.saved_wips:
		if wip.forge_project_name == weapon_name: chosen = wip
	if not _check(chosen != null, "named actual saved weapon exists"):
		_finish(); return
	var requested_style := OS.get_environment("THE_WILL_GRIP_REFRESH_STYLE").strip_edges()
	if requested_style.is_empty(): requested_style = "reverse"
	if not _check(requested_style in ["normal", "reverse"], "requested style is explicit and valid"):
		_finish(); return
	var before_station := _station_env("THE_WILL_GRIP_PRIMARY_STATION_BEFORE", 0.63)
	var after_station := _station_env("THE_WILL_GRIP_PRIMARY_STATION_AFTER", 0.58)
	var support_before := _station_env("THE_WILL_GRIP_SUPPORT_STATION", 0.20)
	var support_after := _station_env("THE_WILL_GRIP_SUPPORT_STATION_AFTER", 0.22)
	if not _check(before_station >= 0.0 and after_station >= 0.0 and support_before >= 0.0 and support_after >= 0.0
		and not is_equal_approx(before_station, after_station) and not is_equal_approx(support_before, support_after), "station changes are finite normalized distinct coordinates"):
		_finish(); return
	_report.merge({"source_library": _source, "source_library_sha256": _source_hash, "weapon_name": weapon_name,
		"trace_path": _trace_path, "style": requested_style, "primary_hand": HAND,
		"primary_before": before_station, "primary_after": after_station,
		"support_before": support_before, "support_after": support_after})
	_library_player = LibraryPlayer.new()
	_library_player.library = input.duplicate(true)
	_library_player.library.save_file_path = _prefix + "_library.tres"
	root.add_child(_library_player)
	_ui = UIScene.instantiate()
	root.add_child(_ui)
	await process_frame
	_ui.open_for(_library_player, "Primary station / support dependency regression")
	if not _check(_ui.open_saved_wip_with_hand_setup(chosen.wip_id, HAND, false), "actual UI opens right-main setup"):
		_finish(); return
	_ui.select_skill_slot(SKILL)
	_ui.set_selected_motion_node_two_hand_state(Motion.TWO_HAND_STATE_ONE_HAND, false)
	if not await _wait_ready(HAND, "initial_primary"): _finish(); return
	var mounted_seed: Dictionary = MountedSeedProbe.capture(_ui, {}, "before_station_edits")
	_report["mounted_seed_before_edits"] = mounted_seed
	_report["mounted_seed_assertions_enabled"] = OS.get_environment("THE_WILL_GRIP_VERIFY_MOUNTED_SEED") == "1"
	if _report.mounted_seed_assertions_enabled:
		_check(mounted_seed.get("available", false), "actual saved weapon exposes its mounted Reset seed")
		var mount_error: Dictionary = mounted_seed.get("production_error_vs_intended", {})
		_check(float(mount_error.get("basis_angle_degrees", INF)) < 0.01, "Reset seed reconstructs the intended mount orientation within 0.01 degree")
		_check(float(mount_error.get("selected_station_mm", INF)) < 0.05
			and float(mount_error.get("tip_mm", INF)) < 0.05 and float(mount_error.get("pommel_mm", INF)) < 0.05,
			"Reset seed preserves selected station and both endpoints within 0.05 mm")
		var mount_production: Dictionary = mounted_seed.get("production_seed", {})
		var mount_fallback: Dictionary = mounted_seed.get("fallback", {})
		_check(mount_production.has("weapon_roll_degrees") and mount_fallback.has("weapon_roll_degrees")
			and is_equal_approx(float(mount_production.get("weapon_roll_degrees", INF)), float(mount_fallback.get("weapon_roll_degrees", -INF))),
			"Reset mount conversion retains the intended scalar weapon roll")
		_check(mounted_seed.get("trajectory_restored", false) and mounted_seed.get("weapon_unchanged", false),
			"mounted-seed observation restores trajectory and leaves the live weapon unchanged")
	_ui.set_selected_motion_node_grip_seat_slide(before_station, false)
	if not await _wait_ready(HAND, "initial_station"): _finish(); return
	var style: StringName = Wip.GRIP_REVERSE if requested_style == "reverse" else Wip.GRIP_NORMAL
	if _ui._get_active_motion_node().preferred_grip_style_mode != style:
		if not _check(_ui.set_selected_motion_node_preferred_grip_style(style, false), "UI inserts requested grip style and editable follow-on"):
			_finish(); return
		if not await _wait_ready(HAND, "requested_style"): _finish(); return
	var context: Dictionary = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
	if not _check(not context.is_empty() and not _ui._get_active_motion_node().locked_for_authoring, "live chosen-style follow-on is editable"):
		_finish(); return
	var owner: Node = context.actor.get_node("PreparedGripAcquisition")
	_ui.set_selected_motion_node_secondary_grip_seat_slide(support_before, false)
	if not _check(_ui.set_selected_motion_node_two_hand_state(Motion.TWO_HAND_STATE_TWO_HAND, false), "UI activates support"):
		_finish(); return
	var initial_main := _request_snapshot(owner, HAND)
	var joined := await _observe_refresh(context, owner, "support_add", initial_main, _request_snapshot(owner, SUPPORT))
	_report["support_add"] = joined
	if not _check(joined.primary_ready and joined.support_ready, "both hands finish initial two-hand acquisition"):
		_finish(); return
	var old_main := _request_snapshot(owner, HAND)
	var old_support := _request_snapshot(owner, SUPPORT)
	if not _check(_ui.set_selected_motion_node_grip_seat_slide(after_station, false), "UI changes the primary handle percentage"):
		_finish(); return
	var new_main := _request_snapshot(owner, HAND)
	var new_support := _request_snapshot(owner, SUPPORT)
	_report["main_station_requests"] = {"before_main": old_main, "before_support": old_support, "after_main": new_main, "after_support": new_support}
	_check(new_main.key != old_main.key and new_main.serial > old_main.serial, "primary station change creates a new primary request")
	_check(new_support.key != old_support.key and new_support.serial > old_support.serial, "primary station change also creates a new support request")
	var changed := await _observe_refresh(context, owner, "primary_station_changed", new_main, new_support)
	_report["primary_station_changed"] = changed
	_check(changed.primary_ready and changed.support_ready, "both hands finish after primary percentage change")
	_check(changed.saw_support_capture and changed.primary_ready_at_support_capture, "support input is captured only after the new primary is committed")
	_check(changed.get("capture_serial", -1) == new_support.serial and changed.get("primary_binding_key_at_capture", "") == new_main.key,
		"new support capture belongs to the current primary binding and support request")
	_check(changed.capture_weapon_error <= 0.00005, "support captures the currently seated primary weapon frame")
	_check(changed.primary_relative_error <= 0.00005 and changed.primary_finger_error <= 0.00005, "support refit preserves the newly seated primary relationship and finger pose")
	_check(changed.weapon_motion_during_support <= 0.00005, "support refit does not move the established weapon")
	_check(changed.get("support_binding_key_after", "") == new_support.key, "completed support pose binds to its refreshed request")
	if not changed.primary_ready or not changed.support_ready:
		_verify_trace_order(new_main.serial, new_support.serial); _finish(); return
	var settled_main := _request_snapshot(owner, HAND)
	var settled_relative := _primary_relative(context)
	var settled_fingers := _finger_rotations(context.actor, HAND)
	var previous_support := _request_snapshot(owner, SUPPORT)
	_check(_ui.set_selected_motion_node_secondary_grip_seat_slide(support_after, false), "UI changes only the support handle percentage")
	var support_only := _request_snapshot(owner, SUPPORT)
	_check(_request_snapshot(owner, HAND) == settled_main, "support-only percentage change does not reacquire primary")
	_check(support_only.key != previous_support.key and support_only.serial > previous_support.serial, "support-only percentage change creates a support request")
	var support_changed := await _observe_refresh(context, owner, "support_station_changed", settled_main, support_only)
	_report["support_station_changed"] = support_changed
	_check(support_changed.primary_ready and support_changed.support_ready, "support-only refit finishes")
	_check(_request_snapshot(owner, HAND) == settled_main and _frame_error(settled_relative, _primary_relative(context)) <= 0.00005
		and _finger_error(settled_fingers, _finger_rotations(context.actor, HAND)) <= 0.00005, "support-only refit preserves primary ownership and binding")
	_check(_ui.set_selected_motion_node_two_hand_state(Motion.TWO_HAND_STATE_ONE_HAND, false), "UI removes support")
	for _i: int in 3: await process_frame
	_check(not owner.owns(SUPPORT) and owner._support_motion_snapshot.is_empty(), "support removal releases ownership and retained motion snapshot")
	_check(_request_snapshot(owner, HAND) == settled_main and _frame_error(settled_relative, _primary_relative(context)) <= 0.00005,
		"support removal preserves current primary grip")
	_report["legacy_solve_count"] = _legacy_solve_count(context.actor)
	_check(_report.legacy_solve_count == 0, "station changes and support lifecycle perform no legacy serial/seat solve")
	_verify_trace_order(new_main.serial, new_support.serial)
	_finish()

func _station_env(name: String, fallback: float) -> float:
	var value := OS.get_environment(name).strip_edges()
	if value.is_empty(): return fallback
	if not value.is_valid_float(): return -1.0
	var parsed := float(value)
	return parsed if is_finite(parsed) and parsed >= 0.0 and parsed <= 1.0 else -1.0

func _request_snapshot(owner: Node, slot: StringName) -> Dictionary:
	var request: Dictionary = owner._requests.get(slot, {})
	return {"key": String(request.get("key", "")).sha256_text(), "serial": int(request.get("serial", -1))}

func _wait_ready(slot: StringName, label: String) -> bool:
	print("Grip dependency diagnostic: ", label)
	var started := Time.get_ticks_usec()
	var status: Dictionary = {}
	while float(Time.get_ticks_usec() - started) / 1000000.0 < LIMIT_SECONDS:
		await process_frame
		status = _ui.preview_presenter.get_grip_acquisition_status(_ui.preview_subviewport).get(slot, {})
		if status.get("status", "") in ["preview_applied", "unresolved", "unavailable", "cancelled"]: break
	_report[label] = {"status": status.get("status", ""), "reason": status.get("reason", ""), "serial": status.get("serial", -1),
		"elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0}
	return _check(status.get("status", "") == "preview_applied", label + " is applied within bounded wait")

func _observe_refresh(context: Dictionary, owner: Node, label: String, main_request: Dictionary, support_request: Dictionary) -> Dictionary:
	print("Grip dependency diagnostic: ", label)
	var started := Time.get_ticks_usec()
	var result := {"primary_ready": false, "support_ready": false, "saw_support_capture": false,
		"primary_ready_at_support_capture": false, "capture_weapon_error": INF,
		"primary_relative_error": 0.0, "primary_finger_error": 0.0, "weapon_motion_during_support": 0.0, "events": []}
	var main_frame := Transform3D.IDENTITY
	var main_fingers: Array[Quaternion] = []
	var support_weapon := Transform3D.IDENTITY
	var have_primary := false
	var previous_state := ""
	while float(Time.get_ticks_usec() - started) / 1000000.0 < LIMIT_SECONDS:
		await process_frame
		var primary: Dictionary = owner._status.get(HAND, {})
		var support: Dictionary = owner._status.get(SUPPORT, {})
		result.primary_ready = primary.get("status", "") == "preview_applied" and primary.get("serial", -1) == main_request.serial and _request_snapshot(owner, HAND) == main_request
		result.support_ready = support.get("status", "") == "preview_applied" and support.get("serial", -1) == support_request.serial and _request_snapshot(owner, SUPPORT) == support_request
		var state := "%s/%s/%s" % [primary.get("status", ""), support.get("status", ""), owner._running_slot]
		if state != previous_state:
			result.events.append({"elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0,
				"state": state, "primary_serial": primary.get("serial", -1), "support_serial": support.get("serial", -1)})
			previous_state = state
		if result.primary_ready and not have_primary:
			main_frame = _primary_relative(context)
			main_fingers = _finger_rotations(context.actor, HAND)
			have_primary = true
		if owner._running_slot == SUPPORT and owner._job != null and not result.saw_support_capture:
			var capture: Dictionary = owner._job._capture
			var captured_weapon: Transform3D = capture.object.weapon_to_world
			result.saw_support_capture = true
			result.primary_ready_at_support_capture = result.primary_ready
			result.capture_weapon_error = _frame_error(captured_weapon, context.weapon.global_transform)
			result.capture_serial = capture.transaction_serial
			result.capture_frame = capture.engine_process_frame
			result.primary_binding_key_at_capture = String(context.actor.planar_grip_pose_binding.relationship(HAND, context.weapon).get("relationship_key", "")).sha256_text()
			support_weapon = context.weapon.global_transform
		if have_primary:
			result.primary_relative_error = maxf(result.primary_relative_error, _frame_error(main_frame, _primary_relative(context)))
			result.primary_finger_error = maxf(result.primary_finger_error, _finger_error(main_fingers, _finger_rotations(context.actor, HAND)))
		if result.saw_support_capture:
			result.weapon_motion_during_support = maxf(result.weapon_motion_during_support, _frame_error(support_weapon, context.weapon.global_transform))
		if (result.primary_ready and result.support_ready) or primary.get("status", "") in ["unresolved", "unavailable", "cancelled"] or support.get("status", "") in ["unresolved", "unavailable", "cancelled"]:
			result.primary_status = primary.get("status", "")
			result.support_status = support.get("status", "")
			result.reason = support.get("reason", primary.get("reason", ""))
			break
	result.elapsed_ms = float(Time.get_ticks_usec() - started) / 1000.0
	result.support_binding_key_after = String(context.actor.planar_grip_pose_binding.relationship(SUPPORT, context.weapon).get("relationship_key", "")).sha256_text()
	return result

func _verify_trace_order(primary_serial: int, support_serial: int) -> void:
	Trace.close()
	var primary_done: Dictionary = {}
	var support_capture: Dictionary = {}
	var file := FileAccess.open(_trace_path, FileAccess.READ)
	if file != null:
		while not file.eof_reached():
			var line := file.get_line().strip_edges()
			if line.is_empty(): continue
			var entry: Variant = JSON.parse_string(line)
			if not entry is Dictionary: continue
			var data: Dictionary = entry.get("data", {})
			if entry.get("name", "") == "owner.preview_applied" and data.get("slot", "") == String(HAND) and data.get("request_serial", -1) == primary_serial:
				primary_done = entry
			if entry.get("name", "") == "owner.capture_input" and entry.get("kind", "") == "begin" and data.get("slot", "") == String(SUPPORT) and data.get("request_serial", -1) == support_serial:
				support_capture = entry
	_report["chronology_order"] = {"primary_applied": primary_done, "support_capture": support_capture}
	_check(not primary_done.is_empty() and not support_capture.is_empty() and primary_done.sequence < support_capture.sequence,
		"actual timestamped primary completion precedes support input capture for changed station")
