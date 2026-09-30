extends SceneTree

## Observe the natural Skill Crafter acquisition from real UI signal handlers.
## No solved fixture, geometry replacement, forced pose, or solver suppression.
## Only the already isolated workspace user library is read; it is never saved.
const Chronology = preload("res://runtime/player/grip/grip_chronology.gd")
const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const StationState = preload("res://core/models/combat_animation_station_state.gd")
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
var _classification := "setup_incomplete"
var _terminal_first: Dictionary = {}


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
	var weapon_name := OS.get_environment("THE_WILL_GRIP_TRACE_WEAPON_NAME").strip_edges()
	if weapon_name.is_empty(): weapon_name = "Star_Handle_Testing"
	Chronology.event("runner.start", {
		"scope": "real_ui_signal_handlers_not_synthetic_mouse_or_full_game_boot",
		"weapon_action": "ItemList.item_activated (double-click handler)",
		"skill_action": "Button.pressed (no separate skill double-click handler exists)",
		"timeout_seconds": _timeout_seconds, "after_seconds": _after_seconds,
		"configured_weapon_name": weapon_name,
		"user_root": actual, "persistence_disabled": true,
		"fixture_pose_used": false, "solver_modified_by_runner": false,
		"engine_version": Engine.get_version_info(), "engine_max_fps": Engine.max_fps,
		"timeout_scope": "observed between main-thread frames; cancellation joins an active worker safely",
	})
	if not FileAccess.file_exists(USER_LIBRARY):
		await _finish("setup_failed_missing_isolated_library", 1)
		return
	_library_sha256 = FileAccess.get_sha256(USER_LIBRARY)
	var span: int = Chronology.begin("runner.load_isolated_library", {"sha256": _library_sha256,
		"modified_time_unix_seconds": FileAccess.get_modified_time(USER_LIBRARY), "configured_weapon_name": weapon_name})
	var library: Resource = load(USER_LIBRARY)
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
	await _cancel_and_join()
	var span: int = Chronology.begin("runner.cleanup", {})
	if is_instance_valid(_ui):
		_ui.close_ui()
		_ui.queue_free()
	if is_instance_valid(_player): _player.queue_free()
	await process_frame
	var library_unchanged := _library_sha256.is_empty() or FileAccess.get_sha256(USER_LIBRARY) == _library_sha256
	Chronology.finish(span, {"library_unchanged": library_unchanged})
	Chronology.event("runner.complete", {"classification": classification, "exit_code": exit_code if library_unchanged else 1,
		"elapsed_seconds": float(Time.get_ticks_usec() - _started_usec) / 1000000.0,
		"library_unchanged": library_unchanged, "first_terminal": _terminal_first,
		"grip_success_asserted": false})
	Chronology.close()
	print("Grip chronology observation: %s; library unchanged: %s" % [classification, library_unchanged])
	quit(exit_code if library_unchanged else 1)


func _positive_env(name: String, fallback: float) -> float:
	var raw := OS.get_environment(name).strip_edges()
	if raw.is_empty(): return fallback
	if not raw.is_valid_float() or not is_finite(float(raw)) or float(raw) <= 0.0:
		Chronology.event("runner.invalid_environment_value", {"name": name, "value": raw, "fallback": fallback})
		return fallback
	return float(raw)
