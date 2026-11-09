extends SceneTree

## Focused real Unarmed editor idle/camera capture cadence. No Save/F/equipped run.
## Run --baseline before production changes to record the original _process cost.
const Library = preload("res://core/models/player_forge_wip_library_state.gd")
const Station = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const PreparedPose = preload("res://core/models/combat_prepared_pose.gd")

class FakePlayer:
	extends Node
	var forge_wip_library_state: PlayerForgeWipLibraryState
	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state
	func set_ui_mode_enabled(_enabled: bool) -> void:
		pass

var _out := "C:/WORKSPACE/godot_runs/sc_idle_capture_20261108"
var _baseline := false
var _manual_poll := false
var _ui: CombatAnimationStationUI
var _player: FakePlayer
var _finished := false
var _report := {"complete": false, "checks": [], "failures": [], "phases": {},
	"scope": "Fresh isolated Unarmed editor. Idle and camera-only polling; authored finger, selection/reset, acquisition-key notification and terminal capture error. No full grip acquisition, Save/F or equipped playback certification."}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6).replace("\\", "/").trim_suffix("/")
		elif arg == "--baseline":
			_baseline = true
	_report["baseline"] = _baseline
	if not _out.to_lower().begins_with("c:/workspace/") or DirAccess.make_dir_recursive_absolute(_out) != OK:
		push_error("A writable workspace output directory is required.")
		quit(1)
		return
	create_timer(120.0).timeout.connect(func() -> void:
		if not _finished:
			_check(false, "run_timeout")
			_finish())
	var library: PlayerForgeWipLibraryState = Library.new()
	library.save_file_path = _out.path_join("isolated_unarmed_fixture.tres")
	_player = FakePlayer.new()
	_player.forge_wip_library_state = library
	root.add_child(_player)
	_ui = Station.instantiate() as CombatAnimationStationUI
	root.add_child(_ui)
	_ui.set_meta("verification_skip_persistence", true)
	await _frames(2)
	_ui.open_for(_player, "Idle capture cadence verification")
	await _frames(2)
	if not _require(_ui.select_unarmed_authoring(true, {"dominant_slot_id": &"hand_right", "use_two_hand": false}), "unarmed_open"):
		return
	await _frames(2)
	if not _require(_ui.select_skill_slot(&"skill_slot_2", true), "skill_open"):
		return
	await _frames(2)
	if not _require(_ui.reset_active_draft_to_baseline(), "baseline_reset"):
		return
	_ui.select_motion_node(1)
	if not _require(await _wait_recorded(), "initial_pose_recorded"):
		return
	# Keep rig/tree processing real. Call the UI's actual _process once per frame
	# ourselves so its synchronous cost is measured independently of frame waits.
	_ui.set_process(false)
	_manual_poll = true
	_ui.set_meta("marker_lifecycle_profile_enabled", true)
	await _frames(3)
	await _measure("settled_idle", false)
	await _measure("camera_only", true)
	if _baseline:
		_finish()
		return
	if not _require(_ui.has_method("_request_background_prepared_pose_capture")
		and _ui.has_method("_observe_prepared_pose_acquisition_key"), "background_gate_hooks_available"):
		return
	for phase: String in ["settled_idle", "camera_only"]:
		var measured: Dictionary = _report.phases[phase]
		_check(int(measured.station_preparations) == 0, phase + ":no_station_preparation", measured)
		_check(int(measured.background_capture_attempts) == 0, phase + ":no_capture_attempts", measured)
	var node := _motion()
	var old_signature: String = node.prepared_pose_signature
	_clear_profile()
	_check(_ui.set_selected_motion_node_finger_curl(&"hand_left", &"index", 70.0), "finger_edit_accepted")
	_check(await _wait_recorded(), "finger_edit_recorded")
	_check(node.prepared_pose_signature != old_signature, "finger_edit_changed_recorded_signature")
	_check(_capture_attempts() > 0, "finger_edit_woke_background_capture")
	await _measure("after_finger_settled", false)
	_check(int(_report.phases.after_finger_settled.background_capture_attempts) == 0, "finger_edit_settles_again")
	_clear_profile()
	_check(_ui.insert_motion_node_after_selection(), "insert_node")
	_check(await _wait_recorded(), "new_node_recorded")
	_check(_ui.get_selected_motion_node_index() == 2, "new_node_selected")
	_check(_capture_attempts() > 0, "new_node_woke_background_capture")
	_clear_profile()
	_check(_ui.select_motion_node(1), "select_existing_node")
	_check(await _wait_recorded(), "selected_node_recorded")
	_check(_capture_attempts() > 0, "selection_woke_background_capture")
	_clear_profile()
	_ui.call("_observe_prepared_pose_acquisition_key", "test_completed_grip_notification")
	_check(bool(_ui.get("_background_prepared_pose_capture_pending")), "changed_acquisition_key_requests_capture")
	await _frames(5)
	_check(_capture_attempts() > 0, "acquisition_notification_woke_capture")
	# This tests only the notification dispatch; no synthetic grip is bound.
	_clear_profile()
	_check(_ui.reset_active_draft_to_baseline(), "reset_again")
	_check(await _wait_recorded(), "reset_recorded")
	_check(_capture_attempts() > 0, "reset_woke_background_capture")
	await _test_terminal_failure()
	_finish()

func _test_terminal_failure() -> void:
	var node := _motion()
	var preview_root := _ui.call("_get_preview_root") as Node3D
	var saved_signature: String = node.prepared_pose_signature
	var saved_replay: Variant = preview_root.get_meta("preview_runtime_solved_replay_fast_path_active", false)
	# Deliberately inconsistent test-only display state: preview says replay, node
	# has no matching signature. This causes a terminal authoring-capture result.
	node.prepared_pose_signature = ""
	_ui.set("_prepared_pose_completed_input_key", "")
	_ui.set("_prepared_pose_completed_key", "")
	preview_root.set_meta("preview_runtime_solved_replay_fast_path_active", true)
	_clear_profile()
	_ui.call("_request_background_prepared_pose_capture")
	await _frames(8)
	var first_attempts := _capture_attempts()
	_check(first_attempts == 1, "terminal_failure_one_attempt", {"attempts": first_attempts})
	_check(not bool(_ui.get("_background_prepared_pose_capture_pending")), "terminal_failure_sleeps")
	await _frames(12)
	_check(_capture_attempts() == first_attempts, "terminal_failure_does_not_retry_every_frame")
	preview_root.set_meta("preview_runtime_solved_replay_fast_path_active", saved_replay)
	node.prepared_pose_signature = saved_signature
	_ui.call("_request_background_prepared_pose_capture")
	_check(await _wait_recorded(), "explicit_request_recovers_after_terminal_fixture")

func _measure(label: String, orbit: bool) -> void:
	_clear_profile()
	var times: Array[float] = []
	var camera_times: Array[float] = []
	var first_usec := Time.get_ticks_usec()
	for index: int in 30:
		await process_frame
		var started := Time.get_ticks_usec()
		if orbit:
			_ui.orbit_preview_camera(Vector2(2.0, 0.4))
		camera_times.append(float(Time.get_ticks_usec() - started) / 1000.0)
		started = Time.get_ticks_usec()
		_ui.call("_process", 1.0 / 60.0)
		times.append(float(Time.get_ticks_usec() - started) / 1000.0)
	var prepare_count := 0
	for event: Dictionary in _profile():
		if String(event.get("name", "")).begins_with("station_prepare_"):
			prepare_count += 1
	_report.phases[label] = {"frames": times.size(), "ui_process_ms": times,
		"ui_process_mean_ms": _mean(times), "ui_process_max_ms": times.max(),
		"camera_call_mean_ms": _mean(camera_times), "station_preparations": prepare_count,
		"background_capture_attempts": _capture_attempts(),
		"phase_wall_ms": float(Time.get_ticks_usec() - first_usec) / 1000.0}

func _mean(values: Array[float]) -> float:
	var total := 0.0
	for value: float in values:
		total += value
	return total / maxf(float(values.size()), 1.0)

func _profile() -> Array:
	return _ui.get_meta("marker_lifecycle_profile_events", []) as Array

func _clear_profile() -> void:
	_ui.set_meta("marker_lifecycle_profile_events", [])

func _capture_attempts() -> int:
	var count := 0
	for event: Dictionary in _profile():
		if event.get("name", "") == "background_pose_capture":
			count += 1
	return count

func _motion() -> CombatAnimationMotionNode:
	return _ui.call("_get_active_motion_node") as CombatAnimationMotionNode

func _wait_recorded() -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 30000 and not _finished:
		await _frames(1)
		var node := _motion()
		if node != null and not _ui.is_motion_node_recording_pending() \
			and not _ui.preview_presenter.is_grip_acquisition_pending(_ui.preview_subviewport) \
			and node.prepared_pose_signature == PreparedPose.node_pose_signature(node) \
			and not node.prepared_pose.is_empty():
			if _baseline or not bool(_ui.get("_background_prepared_pose_capture_pending")):
				return true
	return false

func _frames(count: int) -> void:
	for index: int in count:
		await process_frame
		if _manual_poll and is_instance_valid(_ui):
			_ui.call("_process", 1.0 / 60.0)

func _require(passed: bool, label: String) -> bool:
	_check(passed, label)
	if not passed:
		_finish()
	return passed

func _check(passed: bool, label: String, details: Dictionary = {}) -> void:
	_report.checks.append({"passed": passed, "name": label, "details": details})
	if not passed:
		_report.failures.append(label)

func _finish() -> void:
	if _finished:
		return
	_finished = true
	_report.complete = true
	var file := FileAccess.open(_out.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))
	print("SKILL_CRAFTER_IDLE_CAPTURE baseline=%s checks=%d failures=%d report=%s" % [_baseline, _report.checks.size(), _report.failures.size(), _out])
	if is_instance_valid(_ui):
		_ui.queue_free()
	if is_instance_valid(_player):
		_player.queue_free()
	quit(0 if _report.failures.is_empty() else 1)
