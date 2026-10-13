extends SceneTree

## Observe the natural Skill Crafter acquisition from real UI signal handlers.
## No solved fixture, geometry replacement, forced pose, or solver suppression.
## Reads the isolated library or an explicit workspace copy; neither is saved.
const Chronology = preload("res://runtime/player/grip/grip_chronology.gd")
const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const StationState = preload("res://core/models/combat_animation_station_state.gd")
const GripData = preload("res://runtime/player/grip/character_grip_data.gd")
const Capture = preload("res://runtime/player/grip/capture_grip_placement_stage.gd")
const USER_LIBRARY := "user://forge/player_wip_library_state.tres"
const OWNER_NAME := "PreparedGripAcquisition"
const HEARTBEAT_USEC := 1000000
const QUIESCENT_CONFIRM_USEC := 2000000
const CANCEL_GRACE_USEC := 10000000

class TracePlayer extends Node:
	var library: Resource
	func get_forge_wip_library_state() -> Resource: return library
	func set_ui_mode_enabled(_enabled: bool) -> void: pass

var _ui
var _player: TracePlayer
var _owner: Node
var _started_usec := 0
var _last_frame_usec := 0
var _last_heartbeat_usec := 0
var _frame_count := 0
var _maximum_frame_interval_usec := 0
var _interval_maximum_usec := 0
var _timeout_seconds := 1800.0
var _after_seconds := 5.0
var _library_sha256 := ""
var _library_path := USER_LIBRARY
var _classification := "setup_incomplete"
var _terminal_first: Dictionary = {}
var _context: Dictionary = {}
var _actual_capture: Dictionary = {}
var _weapon_name := ""
var _source_body_signature := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_started_usec = Time.get_ticks_usec()
	_last_frame_usec = _started_usec
	var expected := OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").simplify_path().to_lower()
	var actual := OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower()
	if not expected.begins_with("c:/workspace/") or expected != actual:
		push_error("Grip chronology requires THE_WILL_DIAGNOSTIC_USER_ROOT to match an isolated C:/WORKSPACE user directory.")
		quit(1)
		return
	if not Chronology.enabled():
		push_error("Grip chronology recorder is not enabled; acquisition was not started.")
		quit(1)
		return
	_timeout_seconds = _positive_env("THE_WILL_GRIP_TRACE_TIMEOUT_SECONDS", 1800.0)
	_after_seconds = _positive_env("THE_WILL_GRIP_TRACE_AFTER_SECONDS", 5.0)
	var library_override := OS.get_environment("THE_WILL_GRIP_TRACE_LIBRARY").strip_edges()
	if not library_override.is_empty():
		library_override = library_override.replace("\\", "/").simplify_path()
		if not library_override.is_absolute_path() or not library_override.to_lower().begins_with("c:/workspace/"):
			push_error("THE_WILL_GRIP_TRACE_LIBRARY must be an absolute path inside C:/WORKSPACE.")
			await _finish("setup_failed_library_outside_workspace", 1)
			return
		_library_path = library_override
	var weapon_name := OS.get_environment("THE_WILL_GRIP_TRACE_WEAPON_NAME").strip_edges()
	if weapon_name.is_empty(): weapon_name = "Star_Handle_Testing"
	_weapon_name = weapon_name
	Chronology.event("runner.start", {
		"scope": "real_ui_signal_handlers_not_synthetic_mouse_or_full_game_boot",
		"weapon_action": "ItemList.item_activated (double-click handler)",
		"skill_action": "Button.pressed (no separate skill double-click handler exists)",
		"timeout_seconds": _timeout_seconds, "after_seconds": _after_seconds,
		"configured_weapon_name": weapon_name,
		"library_path": _library_path,
		"user_root": actual, "persistence_disabled": true,
		"fixture_pose_used": false, "solver_modified_by_runner": false,
		"engine_version": Engine.get_version_info(), "engine_max_fps": Engine.max_fps,
		"timeout_scope": "observed between main-thread frames; cancellation joins an active worker safely",
	})
	if not FileAccess.file_exists(_library_path):
		await _finish("setup_failed_missing_isolated_library", 1)
		return
	_library_sha256 = FileAccess.get_sha256(_library_path)
	var span: int = Chronology.begin("runner.load_isolated_library", {"sha256": _library_sha256,
		"modified_time_unix_seconds": FileAccess.get_modified_time(_library_path), "configured_weapon_name": weapon_name,
		"library_path": _library_path})
	var library: Resource = load(_library_path)
	Chronology.finish(span, {"loaded": library != null})
	if library == null:
		await _finish("setup_failed_library_load", 1)
		return
	# open_for's schema migration can persist without consulting the diagnostic
	# flag. Reject that input instead of changing library or migration behavior.
	for saved: Resource in library.get("saved_wips"):
		if saved == null: continue
		var station: Resource = saved.get("combat_animation_station_state")
		if station == null or int(station.get("station_version")) < StationState.SKILL_BASELINE_SCHEMA_VERSION:
			Chronology.event("runner.setup_rejected", {"reason": "input_library_requires_persisting_schema_migration", "wip_id": saved.get("wip_id")})
			await _finish("setup_failed_library_requires_migration", 1)
			return
	var chosen: Resource
	for saved: Resource in library.get("saved_wips"):
		if saved != null and str(saved.get("forge_project_name")) == weapon_name:
			if chosen != null:
				await _finish("setup_failed_ambiguous_weapon_name", 1)
				return
			chosen = saved
	if chosen == null:
		Chronology.event("runner.setup_rejected", {"reason": "weapon_not_found", "weapon_name": weapon_name})
		await _finish("setup_failed_weapon_not_found", 1)
		return
	var saved_stage: Resource = chosen.get("stage2_item_state")
	_source_body_signature = str(saved_stage.get("primary_grip_handle_body_signature")) if saved_stage != null else ""
	span = Chronology.begin("runner.instantiate_ui", {"weapon_name": weapon_name, "wip_id": chosen.get("wip_id")})
	_player = TracePlayer.new()
	_player.library = library.duplicate(true)
	root.add_child(_player)
	_ui = UIScene.instantiate()
	_ui.set_meta("verification_skip_persistence", true)
	_ui.set_meta("trace_open_latency", true)
	_ui.set_meta("trace_editor_surface_latency", true)
	_ui.preview_presenter.set_meta("trace_preview_latency", true)
	root.add_child(_ui)
	Chronology.finish(span, {"ui_inside_tree": _ui.is_inside_tree()})
	await process_frame
	span = Chronology.begin("ui.open_skill_crafter", {"method": "open_for"})
	_ui.open_for(_player, "Grip chronology")
	Chronology.finish(span, _ui_summary())
	var project_list: ItemList = _ui.project_list
	var selected_index := -1
	for index: int in project_list.item_count:
		if project_list.get_item_metadata(index) == chosen.get("wip_id"):
			selected_index = index
			break
	if selected_index < 0:
		await _finish("setup_failed_weapon_missing_from_ui", 1)
		return
	span = Chronology.begin("ui.weapon_item_activated", {"index": selected_index, "wip_id": chosen.get("wip_id"), "weapon_name": weapon_name})
	project_list.select(selected_index)
	project_list.item_activated.emit(selected_index)
	Chronology.finish(span, _ui_summary())
	_record_existing_latency_snapshot("weapon_item_activated")
	if _ui.active_saved_wip_id != chosen.get("wip_id") or _ui.workflow_step != &"workflow_skill_select":
		await _finish("setup_failed_weapon_activation_did_not_advance", 1)
		return
	# Search the actual button's bound selector callback, not an assumed index.
	var skill_button := _find_skill_button(&"skill_slot_1")
	if skill_button == null or skill_button.disabled:
		await _finish("setup_failed_skill_1_button_missing_or_disabled", 1)
		return
	span = Chronology.begin("ui.skill_1_pressed", {"slot": "skill_slot_1", "method": "Button.pressed -> _on_skill_slot_selector_pressed", "activation_count": 1})
	skill_button.pressed.emit()
	Chronology.finish(span, _ui_summary())
	_record_existing_latency_snapshot("skill_1_pressed")
	if _ui.workflow_step != &"workflow_editor" or _ui._get_active_skill_slot_id() != &"skill_slot_1":
		await _finish("setup_failed_skill_activation_did_not_advance", 1)
		return
	var context: Dictionary = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
	if context.is_empty() or not is_instance_valid(context.get("actor")):
		await _finish("setup_failed_preview_context_missing", 1)
		return
	_context = context
	_owner = context.actor.get_node_or_null(OWNER_NAME)
	if _owner == null:
		await _finish("setup_failed_acquisition_owner_missing", 1)
		return
	Chronology.event("runner.natural_acquisition_observation_started", _snapshot())
	_last_frame_usec = Time.get_ticks_usec()
	_last_heartbeat_usec = _last_frame_usec
	await _observe()
	await _finish(_classification, 2 if _classification == "timeout" else 0)


func _record_existing_latency_snapshot(action: String) -> void:
	Chronology.event("ui.existing_latency_snapshot", {
		"captured_after_action": action,
		"scope": "Last-operation snapshots, not an exhaustive trace of internal calls. Each series retains its last writer and may predate this action.",
		"last_open_latency_trace": _ui.get_meta("last_open_latency_trace", []),
		"last_editor_surface_latency_trace": _ui.get_meta("last_editor_surface_latency_trace", []),
		"last_sync_preview_pose_latency_trace": _ui.preview_presenter.get_meta("last_sync_preview_pose_latency_trace", []),
	})


func _find_skill_button(slot_id: StringName) -> Button:
	var grid: GridContainer = _ui.skill_slot_grid
	if grid == null: return null
	for child: Node in grid.get_children():
		if not child is Button: continue
		for connection: Dictionary in child.pressed.get_connections():
			var callback: Callable = connection.get("callable", Callable())
			if callback.get_method() == &"_on_skill_slot_selector_pressed" and slot_id in callback.get_bound_arguments():
				return child as Button
	return null


func _observe() -> void:
	var terminal_usec := 0
	var candidate_since := 0
	var candidate := ""
	var candidate_serial := -1
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		_note_frame(now)
		if now - _last_heartbeat_usec >= HEARTBEAT_USEC:
			_heartbeat(now)
		var observed := _terminal_candidate()
		var observed_serial := int(_owner.get("_serial")) if is_instance_valid(_owner) else -1
		if observed != candidate or observed_serial != candidate_serial:
			if terminal_usec > 0:
				Chronology.event("runner.terminal_window_reset", {"previous_candidate": candidate,
					"previous_serial": candidate_serial, "next_candidate": observed,
					"next_serial": observed_serial, "observed_after_seconds": float(now - terminal_usec) / 1000000.0})
			terminal_usec = 0
			_classification = "observing"
			candidate = observed
			candidate_serial = observed_serial
			candidate_since = now
			Chronology.event("runner.observed_state_change", {"candidate": candidate, "state": _snapshot()})
		if terminal_usec == 0 and not candidate.is_empty() and now - candidate_since >= QUIESCENT_CONFIRM_USEC:
			terminal_usec = now
			var terminal_state := _snapshot()
			if _terminal_first.is_empty(): _terminal_first = terminal_state
			Chronology.event("runner.terminal_observed", {"classification": candidate, "state": terminal_state, "grip_success_asserted": false})
		if terminal_usec > 0 and float(now - terminal_usec) / 1000000.0 >= _after_seconds:
			_classification = candidate
			return
		if float(now - _started_usec) / 1000000.0 >= _timeout_seconds:
			_classification = "timeout"
			Chronology.event("runner.timeout", _snapshot())
			return


func _terminal_candidate() -> String:
	if not is_instance_valid(_owner): return "owner_disappeared"
	var busy: bool = _owner.get("_busy")
	var job = _owner.get("_job")
	var queued: Array = _owner.get("_queue")
	if not queued.is_empty(): return ""
	if job != null: return ""
	var statuses: Dictionary = _owner.get("_status")
	if busy:
		# assess() briefly has no job during frame-awaited capture; it is not a
		# terminal state. A stuck busy-without-job remains visible until timeout.
		return ""
	if statuses.is_empty(): return "quiescent_without_status"
	var result := ""
	for slot: Variant in statuses:
		var state: Dictionary = statuses[slot]
		match str(state.get("status", "")):
			"solving", "assessing", "queued": return "quiescent_stale_status"
			"unavailable", "unresolved": return "failed"
			"cancelled": result = "cancelled"
			"preview_applied":
				if result.is_empty(): result = "preview_applied"
			_: return "quiescent_unknown_status"
	return result


func _snapshot() -> Dictionary:
	var result := _ui_summary()
	result["elapsed_seconds"] = float(Time.get_ticks_usec() - _started_usec) / 1000000.0
	result["owner_present"] = is_instance_valid(_owner)
	if not is_instance_valid(_owner): return result
	result["owner_busy"] = _owner.get("_busy")
	result["owner_process_enabled"] = _owner.is_processing()
	result["settle_ready"] = _owner.get("_settle_ready")
	result["request_serial"] = _owner.get("_serial")
	result["running_slot"] = _owner.get("_running_slot")
	result["queued_slots"] = (_owner.get("_queue") as Array).duplicate()
	var requests: Dictionary = _owner.get("_requests")
	var request_summary: Dictionary = {}
	for slot: Variant in requests:
		var request: Dictionary = requests[slot]
		request_summary[str(slot)] = {"serial": request.get("serial"), "dominant": request.get("dominant"), "key_sha256": str(request.get("key", "")).sha256_text()}
	result["requests"] = request_summary
	var status_summary: Dictionary = {}
	var statuses: Dictionary = _owner.get("_status")
	for slot: Variant in statuses:
		var state: Dictionary = statuses[slot]
		var small: Dictionary = {}
		for key: String in ["status", "reason", "serial", "elapsed_seconds", "actual_assessment_current", "actual_material_query_valid", "actual_material_safe", "actual_articulation_valid", "actual_assessment_reason", "contact_condition_met"]:
			if state.has(key): small[key] = state[key]
		status_summary[str(slot)] = small
	result["statuses"] = status_summary
	var job = _owner.get("_job")
	result["job_present"] = job != null
	if job != null:
		result["job_instance_id"] = str(job.get_instance_id())
		result["job_progress"] = job.progress()
		var worker: Thread = job.get("_worker")
		result["worker_started"] = worker != null and worker.is_started()
		result["worker_alive"] = worker != null and worker.is_alive()
	return result


func _ui_summary() -> Dictionary:
	if not is_instance_valid(_ui): return {"ui_present": false}
	var grip_label: Label = _ui.grip_acquisition_label
	var footer: Label = _ui.footer_status_label
	return {"ui_present": true, "workflow_step": _ui.workflow_step,
		"selected_wip_id": _ui.active_saved_wip_id,
		"grip_status_text": grip_label.text if grip_label != null else "",
		"footer_text": footer.text if footer != null else ""}


func _note_frame(now: int) -> void:
	var interval := now - _last_frame_usec
	_last_frame_usec = now
	_frame_count += 1
	_interval_maximum_usec = maxi(_interval_maximum_usec, interval)
	_maximum_frame_interval_usec = maxi(_maximum_frame_interval_usec, interval)


func _heartbeat(now: int) -> void:
	var state := _snapshot()
	state["frames_observed"] = _frame_count
	state["heartbeat_interval_ms"] = float(now - _last_heartbeat_usec) / 1000.0
	state["maximum_frame_interval_ms_since_heartbeat"] = float(_interval_maximum_usec) / 1000.0
	state["maximum_frame_interval_ms_overall"] = float(_maximum_frame_interval_usec) / 1000.0
	Chronology.event("runner.heartbeat", state)
	_last_heartbeat_usec = now
	_interval_maximum_usec = 0


func _cancel_and_join() -> void:
	if not is_instance_valid(_owner): return
	var job = _owner.get("_job")
	var queued: Array = _owner.get("_queue")
	if job == null and queued.is_empty() and not _owner.get("_busy"): return
	var span: int = Chronology.begin("runner.cancel_and_join", _snapshot())
	# The observation has ended. Clear cancels the owned job and removes queued
	# requests. Give the natural coroutine a bounded grace period to join.
	_owner.clear()
	var deadline := Time.get_ticks_usec() + CANCEL_GRACE_USEC
	while job != null and bool(job.get("_running")) and Time.get_ticks_usec() < deadline:
		await process_frame
		var now := Time.get_ticks_usec()
		_note_frame(now)
		if now - _last_heartbeat_usec >= HEARTBEAT_USEC: _heartbeat(now)
	if job != null and bool(job.get("_running")):
		# Never abandon an active worker or free its host underneath it. The
		# fallback join can exceed the graceful wait; report its blocking time.
		var join_span: int = Chronology.begin("runner.cancel_grace_exceeded_synchronous_join", {"grace_seconds": float(CANCEL_GRACE_USEC) / 1000000.0})
		job.shutdown()
		Chronology.finish(join_span, {"worker_joined": job.get("_worker") == null})
		await process_frame
	Chronology.finish(span, {"owner_busy": _owner.get("_busy"), "job_present": _owner.get("_job") != null})


func _finish(classification: String, exit_code: int) -> void:
	_classification = classification
	Chronology.event("runner.observation_finished", {"classification": classification, "state": _snapshot(), "grip_success_asserted": false})
	if OS.get_environment("THE_WILL_GRIP_TRACE_CAPTURE_POSE") == "1" and classification == "preview_applied":
		await _capture_actual_pose()
	var status_exported := _export_full_status(classification)
	await _cancel_and_join()
	var span: int = Chronology.begin("runner.cleanup", {})
	if is_instance_valid(_ui):
		_ui.close_ui()
		_ui.queue_free()
	if is_instance_valid(_player): _player.queue_free()
	await process_frame
	var library_unchanged := _library_sha256.is_empty() or FileAccess.get_sha256(_library_path) == _library_sha256
	Chronology.finish(span, {"library_unchanged": library_unchanged})
	var final_exit_code := exit_code if library_unchanged and status_exported else 1
	Chronology.event("runner.complete", {"classification": classification, "exit_code": final_exit_code,
		"elapsed_seconds": float(Time.get_ticks_usec() - _started_usec) / 1000000.0,
		"library_unchanged": library_unchanged, "first_terminal": _terminal_first, "full_status_exported":status_exported,
		"grip_success_asserted": false})
	Chronology.close()
	print("Grip chronology observation: %s; library unchanged: %s" % [classification, library_unchanged])
	quit(final_exit_code)


func _export_full_status(classification: String) -> bool:
	var trace_path := OS.get_environment("THE_WILL_GRIP_TRACE_PATH").replace("\\", "/").simplify_path()
	var path := trace_path.get_basename() + "_status.json"
	if not trace_path.is_absolute_path() or not path.to_lower().begins_with("c:/workspace/") or trace_path.get_extension().to_lower() != "jsonl":
		push_error("Full grip status requires an absolute workspace .jsonl trace path.")
		return false
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		push_error("Grip chronology refuses to overwrite an existing status export: " + path)
		return false
	var status: Dictionary = _owner.status() if is_instance_valid(_owner) else {}
	var report := {"schema":"the_will_grip_full_owner_status", "version":1,
		"captured_utc":Time.get_datetime_string_from_system(true) + "Z",
		"captured_unix_seconds":Time.get_unix_time_from_system(), "engine_version":Engine.get_version_info(),
		"library_path":ProjectSettings.globalize_path(_library_path), "library_sha256":_library_sha256,
		"library_sha256_at_export":FileAccess.get_sha256(_library_path) if FileAccess.file_exists(_library_path) else "",
		"classification":classification, "scope":"real_ui_signal_handlers_owner_status_before_cancel_and_cleanup",
		"chronology_depth_or_item_truncation_applied":false, "grip_success_asserted":false,
		"state":_snapshot(), "owner_status":status}
	report.merge(_actual_capture)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write full grip status: " + error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(report, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_error("Full grip status write failed: " + error_string(write_error))
		return false
	Chronology.event("runner.full_status_exported", {"path":path, "classification":classification, "slot_count":status.size()})
	return true


## Optional observer used by a subsequent HTML export. This runs after the
## timed natural acquisition, never writes a pose, and does not rerun a solver.
## https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html#signals
func _capture_actual_pose() -> void:
	var span := Chronology.begin("runner.capture_actual_pose", {"solver_ran":false, "pose_writes":false})
	_actual_capture = {"actual_capture_valid":false, "weapon_name":_weapon_name,
		"source_library":ProjectSettings.globalize_path(_library_path), "source_library_sha256":_library_sha256,
		"input_body_signature":_source_body_signature}
	if not is_instance_valid(_owner) or not is_instance_valid(_context.get("actor")) or not is_instance_valid(_context.get("weapon")):
		_actual_capture["actual_capture_error"] = "missing_live_context"
		Chronology.finish(span, _actual_capture)
		return
	var requests: Dictionary = _owner.get("_requests")
	var slot: StringName = &""
	for candidate: StringName in requests:
		if requests[candidate].get("dominant") == candidate:
			slot = candidate
			break
	if slot == &"":
		_actual_capture["actual_capture_error"] = "missing_primary_request"
		Chronology.finish(span, _actual_capture)
		return
	var request: Dictionary = requests[slot].duplicate(true)
	var data := GripData.load_for_actor(_context.actor)
	if not data.get("valid", false):
		_actual_capture["actual_capture_error"] = data
		Chronology.finish(span, _actual_capture)
		return
	var pivot := {"point_local":_context.weapon.get_meta("preview_primary_grip_seat_local"),
		"origin_id":_context.weapon.get_meta("preview_primary_grip_seat_origin_id"), "source":"preview_primary_grip_seat"}
	var skeleton: Skeleton3D = _context.actor.get("skeleton")
	var capture := {}
	var receive := func() -> void:
		if capture.is_empty() and _owner._is_current(slot, request):
			capture.merge(Capture.new().capture(_context.actor, _context.weapon, data.anatomy, slot,
				&"trace_natural_skeleton_observation", request.serial, 0, {}, pivot))
			capture["verification_capture_policy"] = "natural_skeleton_updated_signal"
	skeleton.skeleton_updated.connect(receive)
	var stamp: PackedByteArray = _owner._realization_stamp()
	var stable_frames := 0
	for frame: int in 4:
		await process_frame
		if not capture.is_empty(): break
		var next: PackedByteArray = _owner._realization_stamp()
		stable_frames = stable_frames + 1 if stamp == next else 0
		stamp = next
	if skeleton.skeleton_updated.is_connected(receive): skeleton.skeleton_updated.disconnect(receive)
	if not _owner._is_current(slot, request):
		capture = {"valid":false, "reason":"request_replaced_during_capture"}
	elif capture.is_empty():
		var active_modifiers: Array = []
		for child: Node in skeleton.find_children("*", "SkeletonModifier3D", true, false):
			if child is SkeletonModifier3D and child.active and child.influence > 0.0:
				if child is PhysicalBoneSimulator3D and not child.is_simulating_physics(): continue
				active_modifiers.append(str(child.get_path()))
		if not active_modifiers.is_empty() or stable_frames < 2 or stamp.is_empty():
			capture = {"valid":false, "reason":"no_stable_naturally_completed_pose", "active_modifiers":active_modifiers}
		else:
			capture = Capture.new().capture(_context.actor, _context.weapon, data.anatomy, slot,
				&"trace_stable_completed_frames", request.serial, 0, {}, pivot)
			capture["verification_capture_policy"] = "stable_completed_frames_without_active_pose_modifiers"
			if stamp != _owner._realization_stamp(): capture = {"valid":false, "reason":"pose_changed_during_capture"}
	var dimensions: Dictionary = request.get("digit_dimension_reference", {})
	if capture.get("valid", false) and dimensions.is_empty():
		capture = {"valid":false, "reason":"missing_current_request_digit_dimensions"}
	if not capture.get("valid", false):
		_actual_capture["actual_capture_error"] = capture
	else:
		capture.posed_character["digit_dimension_reference"] = dimensions.duplicate(true)
		var path := OS.get_environment("THE_WILL_GRIP_TRACE_PATH").replace("\\", "/").simplify_path().get_basename() + "_actual.bin"
		if not path.to_lower().begins_with("c:/workspace/") or FileAccess.file_exists(path):
			_actual_capture["actual_capture_error"] = "capture_path_outside_workspace_or_already_exists"
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				_actual_capture["actual_capture_error"] = "capture_file_cannot_open"
			else:
				file.store_var(capture, false)
				file.flush()
				var error := file.get_error()
				file.close()
				_actual_capture.merge({"actual_capture_valid":error == OK, "actual_capture_path":path,
					"actual_capture_sha256":FileAccess.get_sha256(path), "slot":slot,
					"actual_capture_policy":capture.get("verification_capture_policy", ""),
					"actual_capture_write_error":error,
					"actual_capture_is_observation_not_grip_certification":true}, true)
	Chronology.finish(span, _actual_capture)


func _positive_env(name: String, fallback: float) -> float:
	var raw := OS.get_environment(name).strip_edges()
	if raw.is_empty(): return fallback
	if not raw.is_valid_float() or not is_finite(float(raw)) or float(raw) <= 0.0:
		Chronology.event("runner.invalid_environment_value", {"name": name, "value": raw, "fallback": fallback})
		return fallback
	return float(raw)
