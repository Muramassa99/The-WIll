extends "res://tools/verify_combat_pose_recording_lifecycle.gd"

## Rendered real station and saved weapon; only the isolated in-memory Skill 3
## fixture is reset. No authored or prepared pose is injected. Same environment
## contract as verify_combat_weapon_facing_control.gd. No F or Save is invoked.
const CAMERA_RUN_LIMIT_MS := 150000
const CAMERA_PHASE_LIMIT_MS := 40000
const CAMERA_TEST_SLOT := &"skill_slot_3"

var _camera_checks: int = 0
var _camera_failures: Array[String] = []


func _run() -> void:
	_source = OS.get_environment("THE_WILL_GRIP_LIVE_LIBRARY").replace("\\", "/")
	_output = OS.get_environment("THE_WILL_SAVE_PROFILE_OUTPUT_DIR").replace("\\", "/")
	var expected: String = OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").to_lower()
	if not expected.begins_with("c:/workspace/") or OS.get_user_data_dir().replace("\\", "/").to_lower() != expected:
		push_error("Isolated diagnostic user root required."); quit(1); return
	if not _source.to_lower().begins_with("c:/workspace/") or not _output.to_lower().begins_with("c:/workspace/") or _source.to_lower().begins_with(_output.to_lower() + "/"):
		push_error("Separate workspace source/output required."); quit(1); return
	if not FileAccess.file_exists(_source) or FileAccess.file_exists(_output.path_join("camera_edit_stability.json")) or DirAccess.make_dir_recursive_absolute(_output) != OK:
		push_error("Existing source and fresh output required."); quit(1); return
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
		if candidate.forge_project_name == requested:
			if selected != null: _finish("ambiguous_weapon_name"); return
			selected = candidate
	if selected == null: _finish("weapon_missing"); return
	_weapon_id = selected.wip_id
	_lifecycle_slot = CAMERA_TEST_SLOT
	var station: Resource = selected.ensure_combat_animation_station_state()
	var remaining: Array[Resource] = []
	for draft: Resource in station.skill_drafts:
		if draft != null and draft.owning_skill_id != _lifecycle_slot: remaining.append(draft)
	station.skill_drafts.assign(remaining)
	station.get_or_create_skill_draft(_lifecycle_slot, "Skill 3", selected.grip_style_mode, _lifecycle_slot)
	_report.merge({"source_path": _source, "source_sha256": _source_hash, "weapon": requested,
		"slot": String(_lifecycle_slot), "run_limit_ms": CAMERA_RUN_LIMIT_MS,
		"automation": "Rendered real station; natural baseline acquisition; Space action and real preview mouse input. Fresh isolated Skill 3 only. No actual save mutation.",
		"limits": "Camera, layout, stationary pointer and two-pixel Tip/Pommel edits. Live pose constraints remain active; not an anatomy, grip-geometry or playback certification."})
	_write_report()
	if not await _open_lifecycle_station() or not await _wait_natural_recording("fresh_station_ready", true):
		_finish("initial_station_not_ready"); return
	for frame: int in 12: await process_frame
	_report["initial_camera"] = _camera_snapshot()
	if not _check(not _camera_snapshot().is_empty(), "initial preview camera exists"):
		_finish("camera_missing"); return
	await _screenshot("camera_initial.png")
	if not await _focus_control(&"tip"): _finish("tip_focus_unavailable"); return
	await _stationary_gesture(&"tip")
	await _micro_drag(&"tip", Vector2(2.0, 0.0))
	await _micro_drag(&"tip", Vector2(2.0, 0.0), Vector2(4.0, 0.0))
	# This is the user's sequence: edit Tip, cycle through available controls,
	# then grab a different control for a small adjustment.
	await _cycle_all_focus("after_tip_focus_cycle")
	if not await _focus_control(&"pommel"): _finish("pommel_focus_unavailable"); return
	await _stationary_gesture(&"pommel")
	await _micro_drag(&"pommel", Vector2(2.0, 0.0))
	await _micro_drag(&"pommel", Vector2(2.0, 0.0), Vector2(4.0, 0.0))
	await _explicit_camera_inputs()
	await _screenshot("camera_final.png")
	_finish("finished")


func _camera_snapshot() -> Dictionary:
	var camera: Camera3D = _ui.call("_get_preview_camera")
	if camera == null: return {}
	var state: Dictionary = _ui.preview_presenter.capture_camera_state(_ui.preview_subviewport)
	var rect: Rect2 = _ui.preview_view_container.get_global_rect()
	var viewport_size: Vector2i = _ui.preview_subviewport.size
	return {"transform": _plain(camera.global_transform), "focus_and_orbit": _plain(state),
		"viewport_size": [viewport_size.x, viewport_size.y],
		"container_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"projection_mode": camera.projection, "fov": camera.fov, "orthogonal_size": camera.size,
		"keep_aspect": camera.keep_aspect, "near": camera.near, "far": camera.far,
		"h_offset": camera.h_offset, "v_offset": camera.v_offset}


func _record_camera(label: String, baseline: Dictionary) -> void:
	var current: Dictionary = _camera_snapshot()
	var same: bool = current == baseline
	_check(same, label + " preserves camera, focus, projection and viewport layout")
	_report.phases.append({"phase": label, "focus": String(_ui.session_state.current_focus), "camera_unchanged": same,
		"camera": current, "status": _ui.footer_status_label.text})
	_write_report()


func _cycle_all_focus(label: String) -> void:
	var baseline: Dictionary = _camera_snapshot()
	var node: Resource = _ui.call("_get_active_motion_node")
	var signature: String = PreparedPoseContract.node_pose_signature(node)
	var ids: Array = _ui.call("_resolve_available_focus_ids")
	var start: StringName = _ui.session_state.current_focus
	var visited: Array[String] = []
	for index: int in ids.size():
		_action(CombatAnimationStationUI.ACTION_CYCLE_FOCUS)
		await process_frame
		visited.append(String(_ui.session_state.current_focus))
		_record_camera(label + "_" + str(index), baseline)
	_check(_ui.session_state.current_focus == start, label + " completes focus cycle")
	_check(visited.size() == ids.size() and ids.all(func(id: Variant) -> bool: return visited.has(String(id))), label + " visits all available controls")
	_check(PreparedPoseContract.node_pose_signature(node) == signature, label + " does not edit authored pose")
	_report.phases.append({"phase": label + "_summary", "visited": visited})


func _focus_control(focus: StringName) -> bool:
	var ids: Array = _ui.call("_resolve_available_focus_ids")
	if not ids.has(focus): return _check(false, "available focus " + String(focus))
	for index: int in ids.size() + 1:
		if _ui.session_state.current_focus == focus: return true
		_action(CombatAnimationStationUI.ACTION_CYCLE_FOCUS)
		await process_frame
	return _check(false, "Space reaches " + String(focus))


func _control_sample(focus: StringName) -> Dictionary:
	var node: Resource = _ui.call("_get_effective_preview_motion_node")
	var display: Resource = _ui.call("_build_display_motion_node_for_viewport_pick", node)
	var camera: Camera3D = _ui.call("_get_preview_camera")
	var trajectory: Node3D = _ui.call("_get_preview_trajectory_root")
	if node == null or display == null or camera == null or trajectory == null: return {}
	var local: Vector3 = display.tip_position_local if focus == &"tip" else display.pommel_position_local
	var world: Vector3 = trajectory.to_global(local)
	var screen: Vector2 = camera.unproject_position(world)
	return {"world": world, "screen": screen, "tip": node.tip_position_local, "pommel": node.pommel_position_local,
		"signature": PreparedPoseContract.node_pose_signature(node), "behind_camera": camera.is_position_behind(world)}


func _sample_json(sample: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in sample:
		var value: Variant = sample[key]
		result[key] = [value.x, value.y] if value is Vector2 else _plain(value)
	return result


func _mouse_button(pointer: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = pointer
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else (MOUSE_BUTTON_MASK_RIGHT if pressed and button == MOUSE_BUTTON_RIGHT else 0)
	_ui.call("_on_preview_gui_input", event)


func _mouse_motion(pointer: Vector2, relative: Vector2, mask: MouseButtonMask = MOUSE_BUTTON_MASK_LEFT) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pointer
	event.relative = relative
	event.button_mask = mask
	_ui.call("_on_preview_gui_input", event)


func _stationary_gesture(focus: StringName) -> void:
	var label: String = String(focus) + "_stationary"
	var sample: Dictionary = _control_sample(focus)
	if not _check(not sample.is_empty() and not bool(sample.get("behind_camera", true)), label + " visible target"): return
	var node: Resource = _ui.call("_get_active_motion_node")
	var signature: String = PreparedPoseContract.node_pose_signature(node)
	var baseline: Dictionary = _camera_snapshot()
	# Deliberately press four pixels off centre within the visible control. A
	# stationary pointer must not snap the control's centre to the cursor.
	var pointer: Vector2 = (sample.screen as Vector2) + Vector2(4.0, 0.0)
	_mouse_button(pointer, true)
	_check(_ui.motion_node_editor.is_dragging(), label + " input starts drag")
	_record_camera(label + "_press", baseline)
	_mouse_motion(pointer, Vector2.ZERO)
	for frame: int in 3:
		await process_frame
		_record_camera(label + "_held_" + str(frame), baseline)
	_mouse_button(pointer, false)
	for frame: int in 3: await process_frame
	_record_camera(label + "_release", baseline)
	_check(PreparedPoseContract.node_pose_signature(node) == signature, label + " press, zero-motion event and release do not author")
	_report.phases.append({"phase": label + "_target", "before": _sample_json(sample), "after": _sample_json(_control_sample(focus))})


func _micro_drag(focus: StringName, delta: Vector2, press_offset: Vector2 = Vector2.ZERO) -> void:
	var label: String = String(focus) + "_two_pixel_drag" + ("_off_centre" if not press_offset.is_zero_approx() else "")
	var before: Dictionary = _control_sample(focus)
	if not _check(not before.is_empty() and not bool(before.get("behind_camera", true)), label + " visible target"): return
	var baseline: Dictionary = _camera_snapshot()
	var pointer: Vector2 = (before.screen as Vector2) + press_offset
	_mouse_button(pointer, true)
	if not _check(_ui.motion_node_editor.is_dragging(), label + " input starts drag"):
		_mouse_button(pointer, false)
		return
	_record_camera(label + "_press", baseline)
	var requested_screen: Vector2 = _ui.motion_node_editor.resolve_point_drag_screen_position(pointer + delta)
	_check(requested_screen.distance_to((before.screen as Vector2) + delta) < 0.01, label + " excludes the original click offset from movement")
	_mouse_motion(pointer + delta, delta)
	for frame: int in 6:
		await process_frame
		_record_camera(label + "_held_" + str(frame), baseline)
	var held: Dictionary = _control_sample(focus)
	_mouse_button(pointer + delta, false)
	for frame: int in 8:
		await process_frame
		_record_camera(label + "_released_" + str(frame), baseline)
	var after: Dictionary = _control_sample(focus)
	var screen_held: float = (held.screen as Vector2).distance_to(before.screen)
	var screen_after: float = (after.screen as Vector2).distance_to(before.screen)
	var authored_delta: float = maxf((after.tip as Vector3).distance_to(before.tip), (after.pommel as Vector3).distance_to(before.pommel))
	# Report live constraints rather than changing the fixture to manufacture a
	# legal result. Four pixels is a diagnostic twice-input ceiling, not a new
	# movement tolerance in production code.
	_check(authored_delta > 0.0000001, label + " produces an accepted authored movement")
	_check(screen_held <= delta.length() * 2.0 + 0.01, label + " held target does not jump beyond twice the requested pixel movement")
	_report.phases.append({"phase": label + "_result", "requested_pixels": [delta.x, delta.y],
		"press_offset_pixels": [press_offset.x, press_offset.y],
		"held_screen_distance_pixels": screen_held, "released_screen_distance_pixels": screen_after,
		"authored_largest_endpoint_delta_meters": authored_delta, "before": _sample_json(before),
		"held": _sample_json(held), "after": _sample_json(after), "status": _ui.footer_status_label.text})
	_write_report()
	await _screenshot(label + ".png")


func _explicit_camera_inputs() -> void:
	# Allow the existing release-event orbit guard to expire first.
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 400: await process_frame
	var before: Dictionary = _camera_snapshot()
	var node: Resource = _ui.call("_get_active_motion_node")
	var signature: String = PreparedPoseContract.node_pose_signature(node)
	var pointer := Vector2(300.0, 250.0)
	_mouse_button(pointer, true, MOUSE_BUTTON_RIGHT)
	_mouse_motion(pointer + Vector2(25.0, 10.0), Vector2(25.0, 10.0), MOUSE_BUTTON_MASK_RIGHT)
	_mouse_button(pointer + Vector2(25.0, 10.0), false, MOUSE_BUTTON_RIGHT)
	await process_frame
	var orbit: Dictionary = _camera_snapshot()
	_check(orbit.transform != before.transform, "deliberate RMB orbit moves camera")
	_mouse_button(pointer, true, MOUSE_BUTTON_WHEEL_UP)
	await process_frame
	var zoom: Dictionary = _camera_snapshot()
	_check(zoom.transform != orbit.transform, "deliberate wheel zoom moves camera")
	_check(PreparedPoseContract.node_pose_signature(node) == signature, "explicit camera inputs leave authored pose unchanged")
	_report.phases.append({"phase": "explicit_camera_controls", "before": before, "orbit": orbit, "zoom": zoom})
	_ui.call("_refresh_preview_scene")
	await process_frame
	_record_camera("refresh_after_explicit_camera", zoom)


func _wait_natural_recording(label: String, require_baseline: bool = false) -> bool:
	var started: int = Time.get_ticks_msec()
	var stable: int = 0
	while Time.get_ticks_msec() - started < CAMERA_PHASE_LIMIT_MS and not _finished:
		var ready: bool = not require_baseline or bool(_ui.get_meta("last_baseline_preparation", {}).get("ready", false))
		ready = ready and not _recording_pending() and not _ui.preview_presenter.is_grip_acquisition_pending(_ui.preview_subviewport) and _node_current(_ui.call("_get_active_motion_node"))
		stable = stable + 1 if ready else 0
		if stable >= 6:
			_report.phases.append({"phase": label, "ready_wait_ms": Time.get_ticks_msec() - started})
			_write_report()
			return true
		await process_frame
	_report.phases.append({"phase": label, "ready": false, "status": _ui.footer_status_label.text,
		"capture": _ui.get_meta("last_prepared_pose_capture", {})})
	return false


func _check(value: bool, label: String) -> bool:
	_camera_checks += 1
	if not value: _camera_failures.append(label)
	return value


func _observe_frame() -> void:
	super._observe_frame()
	if not _finished and Time.get_ticks_msec() - _started > CAMERA_RUN_LIMIT_MS: _finish("camera_bounded_run_timeout")


func _write_report() -> void:
	_report["checks"] = _camera_checks
	_report["failures"] = _camera_failures.duplicate()
	if not _output.is_empty(): _write_json("camera_edit_stability.json", _report)


func _finish(reason: String) -> void:
	if reason == "finished" and not _camera_failures.is_empty(): reason = "focused_assertions_failed"
	super._finish(reason)
