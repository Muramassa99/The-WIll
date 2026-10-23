extends SceneTree

## Real saved weapon -> real station UI -> live primary worker. The diagnostic
## moves the preview's shared world frame while normal rig processing continues;
## it never substitutes a candidate, suspends IK, or writes a closed finger pose.
## Required environment (all paths inside C:/WORKSPACE):
## THE_WILL_DIAGNOSTIC_USER_ROOT, THE_WILL_GRIP_LIVE_LIBRARY,
## THE_WILL_SAVE_PROFILE_OUTPUT_DIR, THE_WILL_GRIP_TRACE_PATH.
## Optional THE_WILL_GRIP_LIVE_WEAPON_NAME (default Broken_Balde_v1).
const WORLD = preload("res://node_3d.tscn")
const Chronology = preload("res://runtime/player/grip/grip_chronology.gd")
const MAX_PHASE_MS := 150000
const MAX_RUN_MS := 360000
const MOVE_DURATION_MS := 1600.0
const MOVE_INTERVAL_MS := 50

var _ui: CombatAnimationStationUI
var _library: Resource
var _source := ""
var _source_sha := ""
var _output := ""
var _trace := ""
var _weapon_id := StringName()
var _started := 0
var _finished := false
var _report := {"complete": false, "ok": false, "cases": [], "checks": []}


func _initialize() -> void:
	_started = Time.get_ticks_msec()
	process_frame.connect(_watchdog)
	call_deferred("_run")


func _run() -> void:
	_source = OS.get_environment("THE_WILL_GRIP_LIVE_LIBRARY").replace("\\", "/").simplify_path()
	_output = OS.get_environment("THE_WILL_SAVE_PROFILE_OUTPUT_DIR").replace("\\", "/").simplify_path()
	_trace = OS.get_environment("THE_WILL_GRIP_TRACE_PATH").replace("\\", "/").simplify_path()
	var expected := OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").simplify_path().to_lower()
	if not expected.begins_with("c:/workspace/") or OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower() != expected:
		push_error("Isolated diagnostic user root required."); quit(1); return
	if not _source.to_lower().begins_with("c:/workspace/") or not _output.to_lower().begins_with("c:/workspace/") or not _trace.to_lower().begins_with(_output.to_lower() + "/"):
		push_error("Workspace source/output and trace within output required."); quit(1); return
	if _source.to_lower().begins_with(_output.to_lower() + "/") or FileAccess.file_exists(_output.path_join("live_grip_motion.json")) or FileAccess.file_exists(_trace):
		push_error("Fresh isolated output required."); quit(1); return
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		quit(1); return
	_source_sha = FileAccess.get_sha256(_source)
	_library = ResourceLoader.load(_source, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if _library == null:
		_finish("source_library_unavailable"); return
	_library.save_file_path = _output.path_join("isolated_library.tres")
	var requested := OS.get_environment("THE_WILL_GRIP_LIVE_WEAPON_NAME")
	if requested.is_empty(): requested = "Broken_Balde_v1"
	for candidate: Resource in _library.saved_wips:
		if candidate.forge_project_name == requested:
			_weapon_id = candidate.wip_id
			break
	if _weapon_id == StringName():
		_finish("saved_weapon_unavailable"); return
	_report.merge({"source_path": _source, "source_sha256": _source_sha, "weapon": requested,
		"method": "Full main scene and real Skill Crafter. Actual saved weapon opened through UI. Live detached numerical worker continues while shared preview frame moves rigidly; no solver bypass, local pose writes, authored-node copy or source save.",
		"scope": "Rigid primary acquisition transport, not arbitrary wrist deformation or support acquisition."})
	_write_report()
	var world := WORLD.instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var player: PlayerController3D = world.get_node("PlayerCharacter")
	player.forge_wip_library_state = _library
	var station: CombatAnimationStation = world.get_node("CombatAnimationStation")
	_ui = station.station_ui as CombatAnimationStationUI
	station.interact(player)
	await process_frame
	for slot: StringName in [&"hand_right", &"hand_left"]:
		if not await _run_case(slot):
			_finish("live_motion_case_failed"); return
	_finish("finished")


func _run_case(slot: StringName) -> bool:
	var row: Dictionary = {"slot": slot, "steps": [], "observed_worker_ids": [], "complete": false, "ok": false}
	_report.cases.append(row)
	var opened := _ui.open_saved_wip_with_hand_setup(_weapon_id, slot, false, true)
	if not _check(opened, String(slot) + " opened actual saved weapon"):
		return false
	if not _check(_ui.select_skill_slot(&"skill_slot_2", true), String(slot) + " selected isolated Skill 2"):
		return false
	var context: Dictionary = {}
	var owner: Node
	var state: Dictionary = {}
	var wait_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - wait_started < MAX_PHASE_MS and not _finished:
		context = _ui.preview_presenter._weapon_roll_context(_ui.preview_subviewport)
		if not context.is_empty():
			owner = context.actor.get_node_or_null("PreparedGripAcquisition")
			if owner != null:
				state = owner.status().get(slot, {})
				if state.get("status", "") == "solving" and owner.get("_running_slot") == slot and owner.get("_job") != null:
					break
				if state.get("status", "") in ["unresolved", "unavailable", "cancelled"]:
					row["terminal_before_motion"] = state.duplicate(true)
					return _check(false, String(slot) + " initial worker unavailable")
		await process_frame
	if not _check(owner != null and state.get("status", "") == "solving" and owner.get("_job") != null, String(slot) + " observed actual worker before completion"):
		row["status"] = state.duplicate(true)
		return false
	var job: RefCounted = owner.get("_job")
	var job_id := str(job.get_instance_id())
	var request: Dictionary = owner.get("_requests")[slot].duplicate(true)
	row.merge({"owner_id": str(owner.get_instance_id()), "request_serial": request.serial,
		"request_key_sha256": String(request.key).sha256_text(), "job_id": job_id,
		"wait_until_solving_ms": Time.get_ticks_msec() - wait_started,
		"initial_status": state.duplicate(true)})
	row.observed_worker_ids.append(job_id)
	var preview_root: Node3D = context.root
	var actor: Node3D = context.actor
	var weapon: Node3D = context.weapon
	if not _check(preview_root.is_ancestor_of(actor) and preview_root.is_ancestor_of(weapon), String(slot) + " shared rigid ancestor contains actual actor and weapon"):
		return false
	var root_start := preview_root.global_transform
	var actor_start := actor.global_transform
	var weapon_start := weapon.global_transform
	var pivot := actor.global_position
	var source_local := _local_bones(actor.get("skeleton"))
	var movement_started := Time.get_ticks_msec()
	var next_move := movement_started
	var last_log := movement_started
	var side := 1.0 if slot == &"hand_right" else -1.0
	var observed_serial_changed := false
	var observed_cancelled := false
	var maximum_local_change := 0.0
	while Time.get_ticks_msec() - movement_started < MAX_PHASE_MS and not _finished:
		state = owner.status().get(slot, {})
		var current_request: Dictionary = owner.get("_requests").get(slot, {})
		if current_request.get("serial", -1) != request.serial or current_request.get("key", "") != request.key:
			observed_serial_changed = true
			break
		var current_job: RefCounted = owner.get("_job")
		if current_job != null:
			var current_id := str(current_job.get_instance_id())
			if current_id not in row.observed_worker_ids:
				row.observed_worker_ids.append(current_id)
			observed_cancelled = observed_cancelled or bool(current_job.call("_is_cancelled"))
		if state.get("status", "") != "solving":
			break
		var now := Time.get_ticks_msec()
		if now >= next_move and now - movement_started <= MOVE_DURATION_MS + MOVE_INTERVAL_MS:
			var progress := clampf(float(now - movement_started + MOVE_INTERVAL_MS) / MOVE_DURATION_MS, 0.0, 1.0)
			var rotation := Basis(Vector3(0.2, 0.6, 1.0).normalized(), deg_to_rad(14.0 * side * progress))
			var translation := Vector3(0.12 * side, 0.035, -0.08) * progress
			var delta := Transform3D(rotation, pivot - rotation * pivot + translation)
			preview_root.global_transform = delta * root_start
			# Explicit world assignments also cover a top-level attachment node.
			# In the normal inherited case these repeat the same rigid transform.
			actor.global_transform = delta * actor_start
			weapon.global_transform = delta * weapon_start
			# This is the production seam that previously cancelled pending work.
			# It records motion and retains the pair; it does not solve or pose it.
			owner.retain_roll()
			row.steps.append({"elapsed_ms": now - movement_started, "progress": progress,
				"owner_busy": owner.get("_busy"), "job_id": str(current_job.get_instance_id()) if current_job != null else "",
				"actor_world": actor.global_transform, "weapon_world": weapon.global_transform,
				"actor_rigid_error_m": actor.global_position.distance_to((delta * actor_start).origin),
				"weapon_rigid_error_m": weapon.global_position.distance_to((delta * weapon_start).origin)})
			next_move = now + MOVE_INTERVAL_MS
		maximum_local_change = maxf(maximum_local_change, _maximum_local_change(source_local, actor.get("skeleton")))
		if now - last_log > 3000:
			last_log = now
			print("LIVE_GRIP_MOTION hand=%s elapsed=%dms steps=%d stage=%s" % [slot, now - movement_started, row.steps.size(), str(state.get("stage", "solving"))])
			_write_report()
		await process_frame
	row.merge({"complete": true, "elapsed_motion_to_result_ms": Time.get_ticks_msec() - movement_started,
		"final_status": state.duplicate(true), "request_changed": observed_serial_changed,
		"cancel_observed": observed_cancelled or bool(job.call("_is_cancelled")),
		"max_local_bone_transform_change_during_movement": maximum_local_change,
		"movement_steps": row.steps.size()}, true)
	var realization: Dictionary = state.get("realization", {})
	var rebase: Dictionary = realization.get("motion_rebase", {})
	row["motion_rebase"] = rebase.duplicate(true)
	var okay := true
	okay = _check(not observed_serial_changed, String(slot) + " request identity and serial preserved") and okay
	okay = _check(row.observed_worker_ids.size() == 1, String(slot) + " one observed live worker") and okay
	okay = _check(not row.cancel_observed, String(slot) + " no cancellation despite retain_roll during motion") and okay
	okay = _check(row.steps.size() >= 2, String(slot) + " gradual motion occurred before completion") and okay
	okay = _check(state.get("status", "") == "preview_applied" and realization.get("valid", false), String(slot) + " actual live primary result applied: " + str(state.get("reason", ""))) and okay
	okay = _check(rebase.get("valid", false) and rebase.get("motion_rebased", false), String(slot) + " real result used proven motion rebase") and okay
	okay = _check(actor.get_planar_grip_pose_state(slot).get("has_grip_pose", false), String(slot) + " real hand owns solved finger pose") and okay
	row["ok"] = okay
	_write_report()
	if okay:
		# Hidden/headless runs may never emit frame_post_draw. Images are optional
		# evidence; do not let them block the next hand or final chronology checks.
		for _frame: int in 3:
			await process_frame
		row["screenshot"] = "skipped_no_rendered_image"
		if DisplayServer.get_name() != "headless" and is_instance_valid(_ui.preview_subviewport):
			var texture := _ui.preview_subviewport.get_texture()
			if texture != null and texture.get_width() > 0 and texture.get_height() > 0:
				var picture := texture.get_image()
				if picture != null and not picture.is_empty():
					var image_path := _output.path_join(String(slot) + "_after_motion.png")
					if picture.save_png(image_path) == OK:
						row["screenshot"] = image_path
		_write_report()
	# Restore only the diagnostic world presentation between independent cases.
	# Do not alter local arm/finger poses or invalidate an unfinished worker.
	if not owner.get("_busy"):
		preview_root.global_transform = root_start
	return okay


func _local_bones(skeleton: Skeleton3D) -> Array[Transform3D]:
	var values: Array[Transform3D] = []
	for index: int in skeleton.get_bone_count():
		values.append(skeleton.get_bone_pose(index))
	return values


func _maximum_local_change(source: Array[Transform3D], skeleton: Skeleton3D) -> float:
	var maximum := 0.0
	for index: int in mini(source.size(), skeleton.get_bone_count()):
		var actual := skeleton.get_bone_pose(index)
		maximum = maxf(maximum, actual.origin.distance_to(source[index].origin))
		for axis: int in 3:
			maximum = maxf(maximum, actual.basis[axis].distance_to(source[index].basis[axis]))
	return maximum


func _check(condition: bool, label: String) -> bool:
	_report.checks.append({"ok": condition, "label": label})
	if not condition:
		push_error(label)
	return condition


func _watchdog() -> void:
	if not _finished and Time.get_ticks_msec() - _started > MAX_RUN_MS:
		_finish("diagnostic_timeout")


func _trace_evidence() -> void:
	var file := FileAccess.open(_trace, FileAccess.READ)
	if file == null:
		_check(false, "chronology available for independent worker count")
		return
	var rows: Array = []
	while not file.eof_reached():
		var value: Variant = JSON.parse_string(file.get_line())
		if value is Dictionary:
			rows.append(value)
	file.close()
	for entry: Dictionary in _report.cases:
		if not entry.has("owner_id"):
			continue
		var started := 0
		var discarded := 0
		var applied := 0
		for row: Dictionary in rows:
			var data: Dictionary = row.get("data", {})
			if str(data.get("owner_id", "")) != entry.owner_id or int(data.get("request_serial", -1)) != entry.request_serial:
				continue
			match row.get("name", ""):
				"owner.solve_started": started += 1
				"owner.solve_discarded_stale": discarded += 1
				"owner.preview_applied": applied += 1
		entry["chronology"] = {"solve_started": started, "stale_discarded": discarded, "preview_applied": applied}
		_check(started == 1 and discarded == 0 and applied == 1, String(entry.slot) + " chronology confirms one worker and one application with no stale discard")


func _finish(reason: String) -> void:
	if _finished:
		return
	_finished = true
	Chronology.close()
	_trace_evidence()
	var source_unchanged := not _source.is_empty() and FileAccess.get_sha256(_source) == _source_sha
	_check(source_unchanged, "source library bytes unchanged")
	var okay := reason == "finished"
	for check: Dictionary in _report.checks:
		okay = okay and check.ok
	_report.merge({"complete": true, "ok": okay, "reason": reason,
		"wall_ms": Time.get_ticks_msec() - _started, "source_file_unchanged": source_unchanged}, true)
	_write_report()
	print("LIVE_GRIP_MOTION " + JSON.stringify({"ok": okay, "reason": reason, "checks": _report.checks.size()}))
	quit(0 if okay else 1)


func _write_report() -> void:
	if _output.is_empty():
		return
	var file := FileAccess.open(_output.path_join("live_grip_motion.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_plain(_report), "\t"))


func _plain(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[str(key)] = _plain(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_plain(item))
		return result
	if value is Transform3D or value is Basis or value is Vector3 or value is Quaternion:
		return var_to_str(value)
	return value
