extends SceneTree

## Real station Save profiling. All library writes use an isolated workspace copy.
## Required env: THE_WILL_DIAGNOSTIC_USER_ROOT, THE_WILL_GRIP_LIVE_LIBRARY,
## THE_WILL_SAVE_PROFILE_OUTPUT_DIR. Optional THE_WILL_GRIP_LIVE_WEAPON_NAME.
## --cases=short,twenty_equal_duration,twenty_default_duration,warm_active_rebuild,cached_metadata
## Cases share one station: later cases deliberately retain warmed grip relationships.
## --collision-backend=reference selects the GDScript parity baseline (default: native).
## Save has no frame-count timeout; use an external watchdog allowing >=180s per case.
const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const SLOT := &"skill_slot_1"
const HAND := &"hand_right"
const CASES := ["short", "twenty_equal_duration", "twenty_default_duration", "warm_active_rebuild", "cached_metadata"]

class LibraryPlayer extends Node:
	var library: Resource
	func get_forge_wip_library_state() -> Resource: return library
	func set_ui_mode_enabled(_enabled: bool) -> void: pass

var _ui: CombatAnimationStationUI
var _player: LibraryPlayer
var _library: Resource
var _output := ""
var _output_ready := false
var _source := ""
var _source_hash := ""
var _weapon_id := StringName()
var _options: Dictionary = {}
var _report: Dictionary = {"complete": false, "cases": [], "scope": "isolated actual station Save timing; no visual or full-hand certification"}
var _measuring := false
var _last_frame_usec := 0
var _max_frame_interval_ms := 0.0
var _frame_intervals := 0
var _final_case := ""

func _initialize() -> void:
	process_frame.connect(_observe_process_frame)
	call_deferred("_run")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2: _options[pair[0]] = pair[1]
	_source = OS.get_environment("THE_WILL_GRIP_LIVE_LIBRARY").strip_edges()
	_output = OS.get_environment("THE_WILL_SAVE_PROFILE_OUTPUT_DIR").strip_edges()
	var expected := _normalized(OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT"))
	if not _workspace(expected) or expected != _normalized(OS.get_user_data_dir()):
		_fail("diagnostic_user_root_not_isolated"); return
	if not _workspace(_source) or not FileAccess.file_exists(_source) or not _workspace(_output):
		_fail("workspace_source_and_output_required"); return
	if _normalized(_source).begins_with(_normalized(_output) + "/"):
		_fail("source_must_be_outside_output_directory"); return
	if FileAccess.file_exists(_output.path_join("report.json")):
		_fail("fresh_output_directory_required"); return
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		_fail("output_directory_creation_failed"); return
	_output_ready = true
	_source_hash = FileAccess.get_sha256(_source)
	var input: Resource = ResourceLoader.load(_source, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if input == null: _fail("source_library_load_failed"); return
	var requested := OS.get_environment("THE_WILL_GRIP_LIVE_WEAPON_NAME").strip_edges()
	if requested.is_empty(): requested = "Broken_Balde_v1"
	var chosen: CraftedItemWIP
	for item: CraftedItemWIP in input.saved_wips:
		if item != null and (item.forge_project_name == requested or String(item.wip_id) == requested):
			chosen = item
			break
	if chosen == null or chosen.latest_baked_profile_snapshot == null:
		_fail("named_saved_weapon_with_baked_profile_required"); return
	_weapon_id = chosen.wip_id
	_library = input.duplicate(true)
	_library.save_file_path = _output.path_join("profile_library.tres")
	_library.get_saved_wip(_weapon_id).grip_style_mode = CraftedItemWIP.GRIP_NORMAL
	_library.set("trace_save_latency", true)
	_player = LibraryPlayer.new()
	_player.library = _library
	root.add_child(_player)
	_ui = UIScene.instantiate() as CombatAnimationStationUI
	_ui.set_meta("trace_save_latency", true)
	root.add_child(_ui)
	await process_frame
	_ui.preview_presenter.set_meta("trace_save_latency", true)
	var collision_backend := String(_options.get("collision-backend", "native"))
	if collision_backend not in ["native", "reference"]:
		_fail("unknown_collision_backend"); return
	_ui.preview_presenter.collision_legality_resolver.configure_native_kernel(collision_backend == "native")
	_report.merge({"source_library": _source, "source_sha256": _source_hash,
		"source_bytes": _file_size(_source), "library_wip_count": _library.saved_wips.size(),
		"weapon": chosen.forge_project_name, "weapon_id": String(_weapon_id),
		"slot": String(SLOT), "output_library": _library.save_file_path, "options": _options,
		"timing_note": "max_process_frame_interval_ms includes main-thread stalls and frame scheduling, not GPU render time"})
	_write_report()
	_ui.open_for(_player, "Isolated real skill Save latency")
	for _index: int in 4: await process_frame
	if not _ui.open_saved_wip_with_hand_setup(_weapon_id, HAND, false, true) or not _ui.select_skill_slot(SLOT, true):
		_fail("station_weapon_or_slot_open_failed"); return
	var draft: Resource = _ui.call("_get_active_draft")
	var visible_start: int = _ui.call("_get_user_visible_motion_node_start_index", draft)
	if visible_start != 1 or draft.motion_node_chain.size() <= visible_start:
		_fail("expected_hidden_entry_and_visible_skill_node"); return
	_ui.select_motion_node(visible_start)
	var readiness: Dictionary = await _wait_ready(10.0)
	_report["initial_readiness"] = readiness
	_write_report()
	if not readiness.get("ready", false): _fail("initial_grip_not_ready"); return
	var defaults := "short,twenty_default_duration,warm_active_rebuild,cached_metadata"
	var selected_cases: PackedStringArray = String(_options.get("cases", defaults)).split(",", false)
	for label: String in selected_cases:
		if label not in CASES: _fail("unknown_case_" + label); return
	for label: String in CASES:
		if label in selected_cases: _final_case = label
	# Warm/cache-only requests need a completed render first, even when selected alone.
	var primed := false
	for label: String in CASES:
		if label not in selected_cases: continue
		if label in ["warm_active_rebuild", "cached_metadata"] and not primed:
			if not await _run_case("warm_prime", 20, 20.0, "rebuild"): _finish(false); return
			primed = true
		var visible_count := 3 if label == "short" else 20
		var duration := 3.0 if label in ["short", "twenty_equal_duration"] else 20.0
		var mode := "cached" if label == "cached_metadata" else ("warm" if label == "warm_active_rebuild" else "rebuild")
		if not await _run_case(label, visible_count, duration, mode): _finish(false); return
		if label == "twenty_default_duration": primed = true
	_finish(true)

func _run_case(label: String, visible_count: int, duration: float, mode: String) -> bool:
	var row: Dictionary = {"case": label, "mode": mode, "complete": false}
	_report["active_case"] = label
	_write_report()
	if mode == "rebuild":
		row["fixture"] = await _build_chain(visible_count, duration)
		if not row.fixture.get("ok", false):
			row["reason"] = "fixture_preparation_failed"
			_record_case(row); return false
	elif mode == "warm":
		_ui.call("_mark_active_draft_runtime_clip_cache_dirty")
		_ui.editor_state_dirty = true
	else:
		var current: Resource = _ui.call("_get_active_draft")
		_ui.set_active_draft_skill_description(String(current.skill_description) + "\nSave profile " + label)
	var readiness: Dictionary = await _wait_ready(0.0)
	row["readiness"] = readiness
	if not readiness.get("ready", false):
		row["reason"] = "case_grip_not_ready"
		_record_case(row); return false
	var draft: Resource = _ui.call("_get_active_draft")
	var original_draft_id: StringName = draft.draft_id
	var before_clip: Resource = draft.baked_runtime_clip
	row.merge({"visible_nodes": _ui.call("_get_user_visible_motion_node_count", draft),
		"raw_nodes": draft.motion_node_chain.size(), "hidden_entry_nodes": _ui.call("_get_user_visible_motion_node_start_index", draft),
		"duration_seconds": draft.get_total_transition_duration_seconds(),
		"selected_node_index": draft.selected_motion_node_index,
		"cache_available_before": before_clip != null and before_clip.has_solved_replay_track(),
		"persistence_enabled": not bool(_ui.get_meta("verification_skip_persistence", false))})
	row["prepared_library"] = _write_prepared_library(label)
	if String(row.prepared_library).is_empty():
		row["reason"] = "prepared_library_write_failed"; _record_case(row); return false
	_write_json(_output.path_join(label + ".json"), row)
	if _ui.has_meta("last_save_latency_trace"): _ui.remove_meta("last_save_latency_trace")
	_library.set("last_save_latency_trace", {})
	_max_frame_interval_ms = 0.0
	_frame_intervals = 0
	_last_frame_usec = Time.get_ticks_usec()
	_measuring = true
	_ui.preview_presenter.collision_legality_resolver.reset_backend_stats()
	print("SAVE_PROFILE begin case=%s nodes=%d duration=%.3f" % [label, row.raw_nodes, row.duration_seconds])
	var started := Time.get_ticks_usec()
	await _ui._manual_save_active_editor_state()
	var elapsed := Time.get_ticks_usec() - started
	_observe_process_frame()
	_measuring = false
	row.merge({"save_wall_ms": float(elapsed) / 1000.0,
		"collision_backend": _ui.preview_presenter.collision_legality_resolver.get_backend_stats(),
		"max_process_frame_interval_ms": _max_frame_interval_ms, "observed_process_frame_intervals": _frame_intervals,
		"save_trace": _ui.get_meta("last_save_latency_trace", {}).duplicate(true),
		"library_trace": (_library.get("last_save_latency_trace") as Dictionary).duplicate(true),
		"save_message": _ui.footer_status_label.text, "manual_save_in_progress": _ui.manual_save_in_progress,
		"output_bytes": _file_size(_library.save_file_path)})
	draft = _ui.call("_get_active_draft")
	var clip: Resource = draft.baked_runtime_clip
	row["frame_count"] = clip.get_frame_count() if clip != null else 0
	row["solved_track"] = clip != null and clip.has_solved_replay_track()
	row["cache_resource_reused"] = clip != null and clip == before_clip
	row["reload"] = _reload_probe(original_draft_id, clip)
	var saved_case_path := _output.path_join(label + "_saved_library.tres")
	row["saved_library"] = saved_case_path if DirAccess.copy_absolute(_library.save_file_path, saved_case_path) == OK else ""
	# Playback replaces the authoring grip context. Exercise F after the final
	# Save so the warm rebuild cases retain the same authoring relationships.
	row["f_checked"] = label == _final_case
	if row.f_checked:
		_ui.call("_toggle_preview_playback")
		row["f_playback_started"] = _ui.chain_player.is_playing()
		await process_frame
		var preview_root: Node = _ui.call("_get_preview_root")
		row["f_solved_fast_path"] = bool(preview_root.get_meta("preview_runtime_solved_replay_fast_path_active", false)) if preview_root != null else false
		if _ui.chain_player.is_playing(): _ui.call("_toggle_preview_playback")
	row["source_unchanged"] = FileAccess.get_sha256(_source) == _source_hash
	row["complete"] = true
	var playback_ok := not bool(row.f_checked) or (bool(row.get("f_playback_started", false)) and bool(row.get("f_solved_fast_path", false)))
	row["ok"] = bool(row.solved_track) and bool(row.reload.get("ok", false)) and playback_ok and bool(row.source_unchanged) and String(row.save_message).contains("Preview ready")
	_record_case(row)
	print("SAVE_PROFILE complete case=%s save_ms=%.3f max_frame_ms=%.3f ok=%s" % [label, row.save_wall_ms, _max_frame_interval_ms, row.ok])
	return bool(row.ok)

func _build_chain(visible_count: int, duration: float) -> Dictionary:
	# Reuse the level thrust setup from diagnose_skill_crafter_body_motion.gd:
	# grip 0.30m ahead of shoulder and 0.12m down; use only its first 0.05m of travel.
	if not _ui.reset_active_draft_to_baseline(): return {"ok": false, "reason": "baseline_reset_failed"}
	var draft: Resource = _ui.call("_get_active_draft")
	var start: int = _ui.call("_get_user_visible_motion_node_start_index", draft)
	if start != 1 or draft.motion_node_chain.size() != 2:
		return {"ok": false, "reason": "baseline_must_keep_hidden_entry_and_one_visible"}
	_ui.select_motion_node(start)
	var hidden_id: StringName = draft.motion_node_chain[0].node_id
	var context: Dictionary = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
	if context.is_empty(): return {"ok": false, "reason": "missing_preview_context"}
	var actor: Node3D = context.actor
	var trajectory: Node3D = context.trajectory
	var skeleton: Skeleton3D = actor.get("skeleton")
	var shoulder_index := skeleton.find_bone("CC_Base_R_Upperarm")
	var anchor: Node3D = context.weapon.get_node_or_null("PrimaryGripAnchor")
	if shoulder_index < 0 or anchor == null: return {"ok": false, "reason": "missing_shoulder_or_primary_anchor"}
	var direction_world: Vector3 = actor.global_basis.z.normalized()
	var direction_local: Vector3 = (trajectory.global_basis.inverse() * direction_world).normalized()
	var motion: CombatAnimationMotionNode = _ui.call("_get_active_motion_node")
	if motion.preferred_grip_style_mode != CraftedItemWIP.GRIP_NORMAL:
		return {"ok": false, "reason": "normal_grip_baseline_required"}
	_ui.set_selected_motion_node_tip_position(motion.pommel_position_local + direction_local * motion.tip_position_local.distance_to(motion.pommel_position_local), false, false, false, true, false)
	var shoulder: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(shoulder_index)).origin
	var desired_grip: Vector3 = shoulder + direction_world * 0.30 - actor.global_basis.y.normalized() * 0.12
	var translation: Vector3 = trajectory.to_local(desired_grip) - trajectory.to_local(anchor.global_position)
	_ui.set_selected_motion_node_pommel_position(motion.pommel_position_local + translation, false)
	var setup: Dictionary = await _wait_ready(10.0)
	if not setup.get("ready", false): return {"ok": false, "reason": "thrust_setup_not_ready", "readiness": setup}
	motion = _ui.call("_get_active_motion_node")
	var display: CombatAnimationMotionNode = _ui.call("_build_authoring_motion_node_baseline", motion)
	if display == null: return {"ok": false, "reason": "missing_accepted_display_baseline"}
	var base: Vector3 = display.pommel_position_local
	direction_local = (display.tip_position_local - base).normalized()
	var positions: Array = []
	var insertion_defaults: Array = []
	var max_motion := 0.0
	var first_authored: Vector3 = motion.pommel_position_local
	for index: int in visible_count:
		if index > 0 and not _ui.insert_motion_node_after_selection():
			return {"ok": false, "reason": "R_insert_failed", "index": index}
		motion = _ui.call("_get_active_motion_node")
		insertion_defaults.append(motion.transition_duration_seconds)
		var t := float(index) / float(maxi(visible_count - 1, 1))
		var requested: Vector3 = base + direction_local * 0.05 * (1.0 - absf(t * 2.0 - 1.0))
		var changed := false
		if index > 0:
			changed = _ui.set_selected_motion_node_pommel_position(requested, false)
		if not is_equal_approx(duration / float(visible_count), 1.0):
			_ui.set_selected_motion_node_transition_duration(duration / float(visible_count), false)
		max_motion = maxf(max_motion, motion.pommel_position_local.distance_to(first_authored))
		positions.append({"node": motion.node_index, "requested_pommel": requested, "authored_pommel": motion.pommel_position_local,
			"authored_tip": motion.tip_position_local, "setter_changed": changed, "duration": motion.transition_duration_seconds})
		await process_frame
	draft.preview_loop_enabled = false
	_ui.select_motion_node(start)
	return {"ok": draft.motion_node_chain.size() == visible_count + 1 and draft.motion_node_chain[0].node_id == hidden_id and max_motion > 0.0001,
		"source_fixture": "diagnose_skill_crafter_body_motion level thrust; 0.05m outward/back subset",
		"R_insert_calls": visible_count - 1, "insertion_defaults_seconds": insertion_defaults,
		"hidden_entry_id": String(hidden_id), "max_authored_pommel_motion_m": max_motion, "positions": positions, "setup": setup}

func _wait_ready(minimum_seconds: float) -> Dictionary:
	var started := Time.get_ticks_msec()
	var stable_since := started
	var last_print := started - 5000
	var previous_key := ""
	var retried := false
	var state: Dictionary = {}
	var identity_stable_since := started
	var previous_identity := ""
	var setup_retries: Array = []
	while Time.get_ticks_msec() - started < 120000:
		var now := Time.get_ticks_msec()
		var context: Dictionary = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
		if context.is_empty():
			await process_frame
			continue
		var actor: Node = context.actor
		var owner: Node = actor.get_node_or_null("PreparedGripAcquisition")
		if owner == null:
			await process_frame
			continue
		var status: Dictionary = owner.status().get(HAND, {})
		var binding: Dictionary = actor.get_planar_grip_pose_state(HAND)
		var idle: bool = not owner._busy and owner._job == null and owner._queue.is_empty() and not _ui.preview_drag_refresh_pending
		var request: Dictionary = owner._requests.get(HAND, {})
		var current: bool = not request.is_empty() and owner._is_current(HAND, request)
		var live_key: String = owner.relationship_key(context.weapon, HAND, request.get("dominant", HAND),
			owner._data.anatomy.get("source_signature"), owner._geometry_epoch) if owner._data.get("valid", false) else ""
		if live_key != previous_identity:
			previous_identity = live_key
			identity_stable_since = now
		var ready: bool = owner._primary_ready_for_support() and binding.get("has_grip_pose", false) and idle
		var key := str([status.get("serial"), binding.get("relationship_key"), binding.get("source_pose_id"), binding.get("weapon_instance_id"), ready])
		if key != previous_key or not ready:
			stable_since = now
			previous_key = key
		state = {"ready": ready, "status": status.get("status", ""), "reason": status.get("reason", ""),
			"wait_ms": now - started, "stable_ms": now - stable_since, "idle": idle,
			"request_serial": status.get("serial"), "relationship_key_hash": String(binding.get("relationship_key", "")).sha256_text(),
			"retried_stale_setup": retried, "setup_retries": setup_retries,
			"request_current": current, "request_key_hash": String(request.get("key", "")).sha256_text(),
			"current_key_hash": live_key.sha256_text(), "owner_busy": owner._busy,
			"owner_job_present": owner._job != null, "owner_queue_size": owner._queue.size()}
		if ready and now - started >= minimum_seconds * 1000.0 and now - stable_since >= 1000: return state
		# A completed stale job can retain "solving" after its queue/job were cleared.
		# Re-request only the proven stale, idle relationship after setup has settled.
		if idle and status.get("status", "") == "solving" and not request.is_empty() and not current and now - started >= 10000 and now - identity_stable_since >= 1000:
			state["identity_difference"] = _identity_difference(String(request.get("key", "")), live_key)
			if retried:
				state["reason"] = "stale_idle_setup_request_after_one_retry"
				return state
			setup_retries.append(state.duplicate(true))
			_report["last_setup_retry"] = state.duplicate(true)
			_write_report()
			print("SAVE_PROFILE retry_stale_idle_setup " + JSON.stringify(state.identity_difference))
			retried = true
			_ui.preview_presenter.reacquire_grip(_ui.preview_subviewport)
		if status.get("status", "") in ["unresolved", "unavailable", "cancelled"]:
			if not retried and status.get("reason", "") == "source_pose_changed_during_acquisition":
				retried = true
				_ui.preview_presenter.reacquire_grip(_ui.preview_subviewport)
			else:
				state["ready"] = false
				return state
		if now - last_print >= 5000:
			print("SAVE_PROFILE waiting_grip status=%s elapsed_ms=%d" % [state.status, now - started])
			last_print = now
		await process_frame
	state["ready"] = false
	state["timeout"] = true
	return state

func _identity_difference(request_key: String, live_key: String) -> Array:
	var before: Array = bytes_to_var(request_key.hex_decode()) if not request_key.is_empty() else []
	var after: Array = bytes_to_var(live_key.hex_decode()) if not live_key.is_empty() else []
	var names := ["anatomy", "weapon_instance", "slot", "dominant", "geometry_epoch", "station", "origin", "style", "geometry", "primary_station"]
	var differences: Array = []
	for index: int in maxi(before.size(), after.size()):
		var left: Variant = before[index] if index < before.size() else null
		var right: Variant = after[index] if index < after.size() else null
		if left != right:
			differences.append({"field": names[index] if index < names.size() else str(index), "requested": str(left), "current": str(right)})
	return differences

func _write_prepared_library(label: String) -> String:
	var prepared: Resource = _library.duplicate(true)
	var found := false
	for index: int in prepared.saved_wips.size():
		if prepared.saved_wips[index].wip_id == _weapon_id:
			prepared.saved_wips[index] = _ui.active_wip.duplicate(true)
			found = true
			break
	if not found: return ""
	var path := _output.path_join(label + "_prepared_library.tres")
	prepared.save_file_path = path
	return path if ResourceSaver.save(prepared, path) == OK else ""

func _reload_probe(draft_id: StringName, clip: Resource) -> Dictionary:
	var persisted: Resource = ResourceLoader.load(_library.save_file_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if persisted == null: return {"ok": false, "reason": "saved_library_reload_failed"}
	var wip: Resource = persisted.get_saved_wip(_weapon_id)
	if wip == null: return {"ok": false, "reason": "saved_weapon_missing"}
	for draft: Resource in wip.combat_animation_station_state.skill_drafts:
		if draft.draft_id != draft_id: continue
		var saved_clip: Resource = draft.baked_runtime_clip
		return {"ok": saved_clip != null and saved_clip.has_solved_replay_track() and clip != null and saved_clip.get_frame_count() == clip.get_frame_count(),
			"frame_count": saved_clip.get_frame_count() if saved_clip != null else 0,
			"raw_nodes": draft.motion_node_chain.size(), "library_wip_count": persisted.saved_wips.size()}
	return {"ok": false, "reason": "saved_skill_missing"}

func _observe_process_frame() -> void:
	if not _measuring: return
	var now := Time.get_ticks_usec()
	_max_frame_interval_ms = maxf(_max_frame_interval_ms, float(now - _last_frame_usec) / 1000.0)
	_frame_intervals += 1
	_last_frame_usec = now

func _record_case(row: Dictionary) -> void:
	_report.cases.append(row)
	_write_json(_output.path_join(String(row.case) + ".json"), row)
	_write_report()

func _write_report() -> void:
	if _output_ready: _write_json(_output.path_join("report.json"), _report)

func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return -1
	var size := file.get_length()
	file.close()
	return size

func _normalized(path: String) -> String:
	return path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()

func _workspace(path: String) -> bool:
	return path.is_absolute_path() and _normalized(path).begins_with("c:/workspace/")

func _fail(reason: String) -> void:
	_report["failure"] = reason
	push_error("SAVE_PROFILE " + reason)
	_finish(false)

func _finish(success: bool) -> void:
	if not _source_hash.is_empty():
		_report["source_unchanged"] = FileAccess.get_sha256(_source) == _source_hash
		success = success and bool(_report.source_unchanged)
	_report["complete"] = success
	_write_report()
	if is_instance_valid(_ui): _ui.queue_free()
	if is_instance_valid(_player): _player.queue_free()
	await process_frame
	quit(0 if success else 1)
