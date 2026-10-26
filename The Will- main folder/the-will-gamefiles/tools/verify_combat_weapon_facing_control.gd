extends "res://tools/verify_combat_pose_recording_lifecycle.gd"

## Real rendered station, real saved weapon, isolated library only. Required
## environment is the same as verify_combat_pose_recording_lifecycle.gd.
## Replaces Skill 3 only in the isolated in-memory fixture. No authored pose or
## prepared-pose injection: the UI initializes, acquires, records and saves it.
## Run with THE_WILL_FACING_TWO_HAND=1 to include the support-hand acquisition
## sequence after the single-hand R/F/Save/cold-reopen check (default enabled).
## THE_WILL_FACING_MODE=two_hand_only or race_only skips the already-covered
## single-hand recording round trip. Neither mode relaxes grip acceptance.
const FACING_RUN_LIMIT_MS := 180000
const FACING_PHASE_LIMIT_MS := 40000
const FACING_MATRIX_EPS := 0.00001
const FACING_TEST_SLOT := &"skill_slot_3"

var _facing_failures: Array[String] = []
var _facing_checks: int = 0


func _run() -> void:
	_source = OS.get_environment("THE_WILL_GRIP_LIVE_LIBRARY").replace("\\", "/")
	_output = OS.get_environment("THE_WILL_SAVE_PROFILE_OUTPUT_DIR").replace("\\", "/")
	var expected: String = OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").to_lower()
	if not expected.begins_with("c:/workspace/") or OS.get_user_data_dir().replace("\\", "/").to_lower() != expected:
		push_error("Isolated diagnostic user root required."); quit(1); return
	if not _source.to_lower().begins_with("c:/workspace/") or not _output.to_lower().begins_with("c:/workspace/") or _source.to_lower().begins_with(_output.to_lower() + "/"):
		push_error("Separate workspace source/output required."); quit(1); return
	if not FileAccess.file_exists(_source) or FileAccess.file_exists(_output.path_join("weapon_facing_control.json")) or DirAccess.make_dir_recursive_absolute(_output) != OK:
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
	_lifecycle_slot = FACING_TEST_SLOT
	var station: Resource = selected.ensure_combat_animation_station_state()
	var remaining: Array[Resource] = []
	for draft: Resource in station.skill_drafts:
		if draft != null and draft.owning_skill_id != _lifecycle_slot: remaining.append(draft)
	station.skill_drafts.assign(remaining)
	station.get_or_create_skill_draft(_lifecycle_slot, "Skill 3", selected.grip_style_mode, _lifecycle_slot)
	_report.merge({"source_path": _source, "source_sha256": _source_hash, "weapon": requested,
		"slot": String(_lifecycle_slot), "run_limit_ms": FACING_RUN_LIMIT_MS,
		"automation": "Real world/station. UI input events, public authoring commands and manual grip button. Fresh isolated Skill 3; source file untouched.",
		"limits": "Rigid weapon-facing control, manual-acquisition ownership and R/F/Save/cold-reopen. Does not certify all grip geometries, anatomy, or equipped consumption."})
	_write_report()
	if not await _open_lifecycle_station() or not await _wait_natural_recording("fresh_station_ready", true):
		_finish("initial_station_not_ready"); return
	if not _ui.has_method("apply_selected_motion_node_weapon_facing_delta"):
		_finish("weapon_facing_API_missing"); return
	if not _check_facing_focus_order(): _finish("focus_order_failed"); return
	var focused_mode: String = OS.get_environment("THE_WILL_FACING_MODE")
	_report["focused_mode"] = focused_mode
	if focused_mode == "race_only":
		var race_ok: bool = await _exercise_inflight_facing()
		_finish("finished" if race_ok else "inflight_facing_failed")
		return
	if focused_mode == "two_hand_only":
		var two_hand_ok: bool = await _exercise_two_hand_facing()
		_finish("finished" if two_hand_ok else "two_hand_facing_failed")
		return
	if not focused_mode.is_empty(): _finish("unknown_facing_mode"); return
	if not await _exercise_facing_gesture("single_hand", true): _finish("single_hand_gesture_failed"); return
	if not await _check_pending_actions(): _finish("pending_action_guard_failed"); return
	if not await _manual_facing_reacquisition("single_hand", false): _finish("single_hand_reacquisition_failed"); return
	var before_r: Resource = _ui.call("_get_active_motion_node")
	var prior_orientation: Vector3 = before_r.weapon_orientation_degrees
	var old_index: int = _ui.get_selected_motion_node_index()
	_action(CombatAnimationStationUI.ACTION_NEW_NODE)
	if not await _wait_selection(old_index + 1, "facing_R", before_r) or not await _wait_natural_recording("facing_R_new_node_ready"):
		_finish("R_recording_failed"); return
	if not _facing_check(before_r.weapon_orientation_degrees == prior_orientation and _node_current(before_r), "R retains outgoing authored facing and current prepared pose"):
		_finish("R_outgoing_facing_changed"); return
	# A small second endpoint exercises the recorded orientation changing in F.
	if not bool(_ui.call("apply_selected_motion_node_weapon_facing_delta", -1.0, true)):
		_finish("second_node_facing_rejected"); return
	if not await _manual_facing_reacquisition("second_node", false): _finish("second_node_reacquisition_failed"); return
	var before_f: int = int(_solve_start_count().count)
	if not await _play_lifecycle_preview("facing_F"):
		_finish("facing_F_failed"); return
	if not _facing_check(int(_solve_start_count().count) == before_f, "F preparation and playback reuse acquired grips"):
		_finish("F_reacquired_grip"); return
	if not await _save_and_reopen(): return
	if not await _play_lifecycle_preview("facing_cold_reopen_F"):
		_finish("cold_reopen_F_failed"); return
	if OS.get_environment("THE_WILL_FACING_TWO_HAND") != "0":
		if not await _exercise_two_hand_facing(): _finish("two_hand_facing_failed"); return
	_report["equipped_verifier_input"] = {"source": _library.save_file_path, "slot": String(_lifecycle_slot),
		"tool": "res://tools/verify_prepared_skill_equipped_playback.gd", "run_in_this_verifier": false}
	_finish("finished")


func _check_facing_focus_order() -> bool:
	var ids: Array = _ui.call("_resolve_available_focus_ids")
	var pommel: int = ids.find(&"pommel")
	var okay: bool = _facing_check(pommel >= 0 and ids.slice(pommel, pommel + 3) == [&"pommel", &"weapon", &"weapon_facing"], "focus order Pommel / wrist roll / weapon facing")
	_ui.session_state.current_focus = &"pommel"
	_ui.call("_cycle_focus", 1)
	okay = _facing_check(_ui.session_state.current_focus == &"weapon", "forward focus reaches existing wrist roll") and okay
	_ui.call("_cycle_focus", 1)
	okay = _facing_check(_ui.session_state.current_focus == &"weapon_facing", "forward focus reaches new weapon facing") and okay
	_ui.call("_cycle_focus", -1)
	okay = _facing_check(_ui.session_state.current_focus == &"weapon", "reverse focus reaches existing wrist roll") and okay
	_ui.session_state.current_focus = &"weapon_facing"
	_ui.call("_refresh_preview_scene")
	return okay


func _exercise_facing_gesture(label: String, include_full_turns: bool) -> bool:
	_ui.session_state.current_focus = &"weapon_facing"
	_ui.call("_refresh_preview_scene")
	await process_frame
	var context: Dictionary = _ui.preview_presenter.call("_weapon_roll_context", _ui.preview_subviewport)
	if context.is_empty(): return _facing_check(false, label + " preview context available")
	var motion: Resource = _ui.call("_get_active_motion_node")
	var display: Resource = _ui.call("_build_display_motion_node_for_viewport_pick", motion)
	var camera: Camera3D = _ui.call("_get_preview_camera")
	var handle: Vector3 = _ui.motion_node_editor.call("get_weapon_facing_handle_local", display)
	var wrist_handle: Vector3 = _ui.motion_node_editor.get_weapon_rotation_handle_local(display)
	var centre: Vector3 = (display.tip_position_local + display.pommel_position_local) * 0.5
	# Record the actual geometry; radial opposition is checked around the axis
	# rather than assuming the two knobs share one fixed longitudinal centre.
	var axis: Vector3 = (display.tip_position_local - display.pommel_position_local).normalized()
	var a: Vector3 = (handle - centre).slide(axis)
	var b: Vector3 = (wrist_handle - centre).slide(axis)
	var opposite: float = a.normalized().dot(b.normalized())
	var okay: bool = _facing_check(opposite < -0.999, label + " facing knob is radially opposite wrist knob")
	var pointer: Vector2 = camera.unproject_position(context.trajectory.to_global(handle))
	var baseline: Dictionary = _facing_snapshot()
	_write_json(label + "_before_matrices.json", baseline)
	var trace_before: int = int(_solve_start_count().count)
	_facing_mouse_button(pointer, true)
	okay = _facing_check(bool(_ui.get("preview_weapon_facing_dragging")), label + " cube input starts facing drag") and okay
	okay = _compare_facing_snapshot(baseline, _facing_snapshot(), label + " mouse press", false) and okay
	var prior: Vector2 = pointer
	var suspended: Dictionary = {}
	for offset: Vector2 in [Vector2(20, 0), Vector2(60, 0), Vector2(4, 0)]:
		var event := InputEventMouseMotion.new()
		event.position = pointer + offset
		event.relative = event.position - prior
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		_ui.call("_on_preview_gui_input", event)
		prior = event.position
		await process_frame
		var sample: Dictionary = _facing_snapshot()
		okay = _compare_facing_snapshot(baseline, sample, label + " drag " + str(offset.x), true) and okay
		if suspended.is_empty(): suspended = sample.owner
		else: okay = _facing_check(sample.owner == suspended, label + " drag keeps suspended owner identity") and okay
	_facing_mouse_button(prior, false)
	for _frame: int in 8: await process_frame
	okay = _facing_check(not bool(_ui.get("preview_weapon_facing_dragging")), label + " release ends facing drag") and okay
	okay = _compare_facing_snapshot(baseline, _facing_snapshot(), label + " release", true) and okay
	if include_full_turns:
		var turn_start: Dictionary = _facing_snapshot()
		var world_axis: Vector3 = (turn_start.tip - turn_start.pommel).normalized()
		for degrees: float in [450.0, -450.0, 0.0]:
			var accepted: bool = _ui.call("apply_selected_motion_node_weapon_facing_delta", degrees, degrees == 450.0)
			await process_frame
			var sample: Dictionary = _facing_snapshot()
			okay = _facing_check(accepted, "unrestricted cumulative facing delta " + str(degrees)) and okay
			okay = _compare_facing_snapshot(baseline, sample, "full-turn " + str(degrees), not is_zero_approx(degrees)) and okay
			var expected_basis: Basis = Basis(world_axis, deg_to_rad(degrees)) * (turn_start.weapon as Transform3D).basis
			# Direction may follow the established negative input convention. The
			# absolute 90-degree physical turn still proves no wrist-limit clamp.
			var actual_turn: float = rad_to_deg((turn_start.weapon as Transform3D).basis.orthonormalized().get_rotation_quaternion().angle_to((sample.weapon as Transform3D).basis.orthonormalized().get_rotation_quaternion()))
			okay = _facing_check(absf(actual_turn - (90.0 if degrees != 0.0 else 0.0)) < 0.025, "full-turn physical orientation " + str(degrees)) and okay
			_report.phases.append({"phase": "full_turn", "requested_degrees": degrees, "actual_shortest_angle_degrees": actual_turn,
				"positive_axis_basis_error": _basis_error(expected_basis, (sample.weapon as Transform3D).basis)})
	_ui.call("_refresh_preview_scene")
	for _frame: int in 8: await process_frame
	var final: Dictionary = _facing_snapshot()
	okay = _compare_facing_snapshot(baseline, final, label + " unrelated refresh", true) and okay
	okay = _facing_check(final.owner == suspended, label + " release and refresh keep suspended request identity") and okay
	okay = _facing_check(int(_solve_start_count().count) == trace_before, label + " no acquisition starts during drag/release/refresh") and okay
	okay = _facing_check(_facing_pending(), label + " explicitly requires manual reacquisition") and okay
	_write_json(label + "_after_matrices.json", final)
	await _screenshot(label + "_pending_manual_acquisition.png")
	return okay


func _check_pending_actions() -> bool:
	var draft: Resource = _ui.call("_get_active_draft")
	var count: int = draft.motion_node_chain.size()
	var selected: int = _ui.get_selected_motion_node_index()
	var authored: Dictionary = _manual_controls(draft)
	var trace_before: int = int(_solve_start_count().count)
	var path: String = _library.save_file_path
	var saved_hash: String = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	var okay: bool = true
	for action: String in ["R", "F", "Save"]:
		if action == "R": _action(CombatAnimationStationUI.ACTION_NEW_NODE)
		elif action == "F": _action(CombatAnimationStationUI.ACTION_PREVIEW_PLAYBACK)
		else: _ui.save_button.pressed.emit()
		for _frame: int in 6: await process_frame
		var status: String = _ui.footer_status_label.text
		var unchanged: bool = draft.motion_node_chain.size() == count and _ui.get_selected_motion_node_index() == selected and _manual_controls(draft) == authored
		var idle: bool = not _recording_pending() and not _ui.preview_prepare_in_progress and not _ui.manual_save_in_progress and not _ui.chain_player.is_playing()
		okay = _facing_check(unchanged and idle and _facing_pending(), "pending facing blocks " + action + " without modifying nodes or starting preparation") and okay
		_report.phases.append({"phase": "pending_" + action, "status": status, "unchanged": unchanged, "idle": idle})
	var final_hash: String = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	okay = _facing_check(final_hash == saved_hash, "pending Save leaves isolated library file unchanged") and okay
	okay = _facing_check(int(_solve_start_count().count) == trace_before, "pending R/F/Save never starts acquisition") and okay
	return okay


func _manual_facing_reacquisition(label: String, expect_support: bool) -> bool:
	var starts_before: Array = _facing_solve_events()
	var before: Dictionary = _facing_snapshot()
	var primary: String = String(_ui.call("_resolve_active_motion_node_primary_slot_id"))
	var hand_name: String = "CC_Base_R_Hand" if primary == "hand_right" else "CC_Base_L_Hand"
	var hand_index: int = before.bone_names.find(hand_name)
	_ui.grip_reacquire_button.pressed.emit()
	if not await _wait_natural_recording(label + "_manual_acquisition"):
		return _facing_check(false, label + " manual acquisition produces a current accepted node")
	var events: Array = _facing_solve_events().slice(starts_before.size())
	var slots: Array = []
	for event: Dictionary in events: slots.append(String(event.get("data", {}).get("slot", "")))
	var support: String = "hand_left" if primary == "hand_right" else "hand_right"
	var okay: bool = _facing_check(not _facing_pending() and not slots.is_empty() and slots[0] == primary, label + " explicit button starts primary acquisition")
	if expect_support:
		okay = _facing_check(slots.find(support) > slots.find(primary), "support acquisition follows primary") and okay
	var after: Dictionary = _facing_snapshot()
	var facing_error: float = _rotation_error_degrees((before.weapon as Transform3D).basis, (after.weapon as Transform3D).basis)
	var wrist_position_error: float = INF
	var wrist_angle_error: float = INF
	if hand_index >= 0:
		wrist_position_error = (before.world_bones[hand_index] as Transform3D).origin.distance_to((after.world_bones[hand_index] as Transform3D).origin)
		wrist_angle_error = _rotation_error_degrees((before.world_bones[hand_index] as Transform3D).basis, (after.world_bones[hand_index] as Transform3D).basis)
	okay = _facing_check(facing_error <= 0.025, label + " manual acquisition retains chosen weapon facing") and okay
	okay = _facing_check(wrist_position_error <= 0.00005 and wrist_angle_error <= 0.025, label + " manual acquisition keeps primary wrist stationary") and okay
	_report.phases.append({"phase": label + "_manual_result", "solve_order": slots,
		"prepared_pose_current": _node_current(_ui.call("_get_active_motion_node")), "status": _ui.footer_status_label.text,
		"weapon_facing_error_degrees": facing_error, "primary_wrist_position_error_m": wrist_position_error,
		"primary_wrist_angle_error_degrees": wrist_angle_error,
		"weapon_before": before.weapon, "weapon_after": after.weapon,
		"wrist_before": before.world_bones[hand_index] if hand_index >= 0 else null,
		"wrist_after": after.world_bones[hand_index] if hand_index >= 0 else null})
	return okay


func _exercise_two_hand_facing() -> bool:
	if not await _wait_natural_recording("before_two_hand_enable"): return false
	if not await _prepare_two_hand_pose(): return false
	if not _ui.set_selected_motion_node_two_hand_state(&"two_hand_two_hand", false):
		return _facing_check(false, "real weapon accepts two-hand mode")
	if not await _wait_natural_recording("two_hand_ready"):
		# Still observe weapon-only movement with both hands configured. This
		# cannot turn the unavailable support baseline into a successful grip.
		var movement_ok: bool = await _exercise_facing_gesture("two_hand_unresolved_baseline", false)
		_report["two_hand_baseline_blocked"] = {"independent_motion_passed": movement_ok,
			"full_grip_and_manual_reacquisition_verified": false}
		return _facing_check(false, "real two-hand baseline ready (separate from facing control)")
	if not await _exercise_facing_gesture("two_hand", false): return false
	return await _manual_facing_reacquisition("two_hand", true)


func _prepare_two_hand_pose() -> bool:
	# The low single-hand Reset pose is not a certified support-hand fixture.
	# Author a forward-facing weapon and place the right wrist in the common
	# workspace of both arms using ordinary UI commands, never bone writes.
	var context: Dictionary = _ui.preview_presenter.call("_weapon_roll_context", _ui.preview_subviewport)
	if context.is_empty(): return false
	var actor: Node3D = context.actor
	var trajectory: Node3D = context.trajectory
	var skeleton: Skeleton3D = actor.get("skeleton")
	var r: int = skeleton.find_bone("CC_Base_R_Upperarm")
	var l: int = skeleton.find_bone("CC_Base_L_Upperarm")
	var hand: int = skeleton.find_bone("CC_Base_R_Hand")
	if r < 0 or l < 0 or hand < 0: return _facing_check(false, "two-hand fixture anatomical reference bones present")
	var shoulder_r: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(r)).origin
	var shoulder_l: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(l)).origin
	var shoulder_center: Vector3 = (shoulder_r + shoulder_l) * 0.5
	var span: float = shoulder_r.distance_to(shoulder_l)
	var forward: Vector3 = actor.global_basis.z.normalized()
	var up: Vector3 = actor.global_basis.y.normalized()
	var target_wrist: Vector3 = shoulder_center + forward * span * 0.90 - up * span * 0.55
	var motion: Resource = _ui.call("_get_active_motion_node")
	var length: float = motion.tip_position_local.distance_to(motion.pommel_position_local)
	var forward_local: Vector3 = (trajectory.global_basis.inverse() * forward).normalized()
	var target_tip: Vector3 = motion.pommel_position_local + forward_local * length
	var tip_ok: bool = _ui.set_selected_motion_node_tip_position(target_tip, false)
	if not tip_ok or not await _wait_natural_recording("two_hand_fixture_forward_axis"):
		return _facing_check(false, "two-hand fixture forward Tip edit naturally accepted")
	context = _ui.preview_presenter.call("_weapon_roll_context", _ui.preview_subviewport)
	trajectory = context.trajectory
	var current_wrist: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(hand)).origin
	motion = _ui.call("_get_active_motion_node")
	var target_pommel: Vector3 = motion.pommel_position_local + trajectory.global_basis.inverse() * (target_wrist - current_wrist)
	var pommel_ok: bool = _ui.set_selected_motion_node_pommel_position(target_pommel, false)
	if not pommel_ok or not await _wait_natural_recording("two_hand_fixture_centered_wrist"):
		return _facing_check(false, "two-hand fixture forward/chest Pommel edit naturally accepted")
	_ui.set_selected_motion_node_grip_seat_slide(0.63, false)
	if not await _wait_natural_recording("two_hand_fixture_primary_station"): return false
	_ui.set_selected_motion_node_secondary_grip_seat_slide(0.20, false)
	_report.phases.append({"phase": "two_hand_fixture", "source": "body-derived UI Tip/Pommel edits; primary63percent/support20percent from earlier support regression",
		"shoulder_span_m": span, "requested_wrist_world": target_wrist,
		"requested_tip_local": target_tip, "requested_pommel_local": target_pommel,
		"accepted_node": _manual_controls(_ui.call("_get_active_draft"))})
	return true


func _exercise_inflight_facing() -> bool:
	_ui.session_state.current_focus = &"weapon_facing"
	_ui.call("_refresh_preview_scene")
	# A restored prepared checkpoint can legitimately have no live owner slots.
	# Enter the actual facing -> manual acquisition workflow first so this race
	# probes an executing solver, rather than an unrelated cold-button no-op.
	if not bool(_ui.call("apply_selected_motion_node_weapon_facing_delta", 1.0, true)) or not _facing_pending():
		return _facing_check(false, "race fixture enters pending manual facing through UI")
	_ui.grip_reacquire_button.pressed.emit()
	var context: Dictionary = _ui.preview_presenter.call("_weapon_roll_context", _ui.preview_subviewport)
	var owner: Node = context.actor.get_node_or_null("PreparedGripAcquisition")
	if owner == null: return _facing_check(false, "race fixture has real acquisition owner")
	var started: int = Time.get_ticks_msec()
	while not bool(owner.get("_busy")) and Time.get_ticks_msec() - started < 5000 and not _finished:
		await process_frame
	if not bool(owner.get("_busy")): return _facing_check(false, "race fixture catches actual in-flight acquisition")
	var before: Dictionary = _facing_snapshot()
	var starts: int = int(_solve_start_count().count)
	var motion: Resource = _ui.call("_get_active_motion_node")
	var display: Resource = _ui.call("_build_display_motion_node_for_viewport_pick", motion)
	var camera: Camera3D = _ui.call("_get_preview_camera")
	var pointer: Vector2 = camera.unproject_position(context.trajectory.to_global(_ui.motion_node_editor.call("get_weapon_facing_handle_local", display)))
	_facing_mouse_button(pointer, true)
	var okay: bool = _facing_check(bool(_ui.get("preview_weapon_facing_dragging")) and _facing_pending(), "mouse-down suspends active acquisition before movement")
	var suspended: Dictionary = _facing_snapshot().owner
	# Holding still spans the cancelled worker's completion, not just one frame.
	started = Time.get_ticks_msec()
	var hold_bone_error: float = 0.0
	while Time.get_ticks_msec() - started < 1800 and not _finished:
		await process_frame
		var held: Dictionary = _facing_snapshot()
		for index: int in before.local_bones.size():
			hold_bone_error = maxf(hold_bone_error, maxf(_transform_error(before.local_bones[index], held.local_bones[index]), _transform_error(before.world_bones[index], held.world_bones[index])))
	okay = _facing_check(hold_bone_error <= FACING_MATRIX_EPS, "every held frame preserves all bone matrices") and okay
	okay = _compare_facing_snapshot(before, _facing_snapshot(), "in-flight mouse-down hold", false) and okay
	var move := InputEventMouseMotion.new()
	move.position = pointer + Vector2(4, 0)
	move.relative = Vector2(4, 0)
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	_ui.call("_on_preview_gui_input", move)
	await process_frame
	_facing_mouse_button(move.position, false)
	for _frame: int in 10: await process_frame
	var after: Dictionary = _facing_snapshot()
	okay = _compare_facing_snapshot(before, after, "in-flight drag/release", true) and okay
	okay = _facing_check(after.owner == suspended and int(_solve_start_count().count) == starts, "cancelled worker cannot replace held pose or restart acquisition") and okay
	_report.phases.append({"phase": "inflight_hold", "worker_busy_after": owner.get("_busy"),
		"max_hold_bone_matrix_error": hold_bone_error,
		"manual_required": _facing_pending(), "owner_status": _compact_facing_status()})
	if not okay: return false
	return await _manual_facing_reacquisition("after_inflight_cancel", false)


func _facing_pending() -> bool:
	return bool(_ui.preview_presenter.call("is_weapon_facing_reacquisition_required", _ui.preview_subviewport))


func _facing_snapshot() -> Dictionary:
	var context: Dictionary = _ui.preview_presenter.call("_weapon_roll_context", _ui.preview_subviewport)
	if context.is_empty(): return {}
	var actor: Node3D = context.actor
	var skeleton: Skeleton3D = actor.get("skeleton")
	var weapon: Node3D = context.weapon
	var local: Array[Transform3D] = []
	var world: Array[Transform3D] = []
	var names: Array[String] = []
	for index: int in skeleton.get_bone_count():
		local.append(skeleton.get_bone_pose(index))
		world.append(skeleton.global_transform * skeleton.get_bone_global_pose(index))
		names.append(skeleton.get_bone_name(index))
	var owner: Node = actor.get_node_or_null("PreparedGripAcquisition")
	var identity: Dictionary = {}
	if owner != null:
		identity = {"id": str(owner.get_instance_id()), "serial": owner.get("_serial"),
			"requests": owner.get("_requests").duplicate(true), "queue": owner.get("_queue").duplicate()}
	var node: Resource = _ui.call("_get_active_motion_node")
	return {"actor": actor.global_transform, "skeleton": skeleton.global_transform,
		"bone_names": names, "local_bones": local, "world_bones": world,
		"weapon": weapon.global_transform, "tip": weapon.to_global(weapon.get_meta("weapon_tip_local")),
		"pommel": weapon.to_global(weapon.get_meta("weapon_pommel_local")),
		"wrist_roll": node.weapon_roll_degrees, "orientation": node.weapon_orientation_degrees, "owner": identity}


func _compare_facing_snapshot(before: Dictionary, after: Dictionary, label: String, expect_rotation: bool) -> bool:
	if before.is_empty() or after.is_empty(): return _facing_check(false, label + " snapshot available")
	var largest: float = 0.0
	var changed_bones: Array[String] = []
	for index: int in before.local_bones.size():
		var error: float = maxf(_transform_error(before.local_bones[index], after.local_bones[index]), _transform_error(before.world_bones[index], after.world_bones[index]))
		largest = maxf(largest, error)
		if error > FACING_MATRIX_EPS: changed_bones.append(before.bone_names[index])
	var endpoint_error: float = maxf(before.tip.distance_to(after.tip), before.pommel.distance_to(after.pommel))
	var root_error: float = maxf(_transform_error(before.actor, after.actor), _transform_error(before.skeleton, after.skeleton))
	var scale_error: float = (before.weapon as Transform3D).basis.get_scale().distance_to((after.weapon as Transform3D).basis.get_scale())
	var rotation_error: float = _basis_error((before.weapon as Transform3D).basis, (after.weapon as Transform3D).basis)
	var okay: bool = _facing_check(changed_bones.is_empty() and root_error <= FACING_MATRIX_EPS and endpoint_error <= FACING_MATRIX_EPS and scale_error <= FACING_MATRIX_EPS and before.wrist_roll == after.wrist_roll, label + " fixes every bone, both hands, roots, endpoints, scale and wrist roll")
	if expect_rotation: okay = _facing_check(rotation_error > 0.0001, label + " changes weapon orientation") and okay
	_report.phases.append({"phase": label, "max_bone_matrix_error": largest, "changed_bones": changed_bones,
		"root_error": root_error, "endpoint_error_m": endpoint_error, "scale_error": scale_error,
		"weapon_basis_change": rotation_error})
	return okay


func _basis_error(a: Basis, b: Basis) -> float:
	return maxf(a.x.distance_to(b.x), maxf(a.y.distance_to(b.y), a.z.distance_to(b.z)))


func _transform_error(a: Transform3D, b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin), _basis_error(a.basis, b.basis))


func _rotation_error_degrees(a: Basis, b: Basis) -> float:
	var relative: Basis = a.orthonormalized().transposed() * b.orthonormalized()
	var sine: float = Vector3(relative.y.z - relative.z.y, relative.z.x - relative.x.z, relative.x.y - relative.y.x).length() * 0.5
	var cosine: float = (relative.x.x + relative.y.y + relative.z.z - 1.0) * 0.5
	return rad_to_deg(atan2(sine, cosine))


func _facing_mouse_button(pointer: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pointer
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	_ui.call("_on_preview_gui_input", event)


func _facing_solve_events() -> Array:
	var result: Array = []
	var file: FileAccess = FileAccess.open(OS.get_environment("THE_WILL_GRIP_TRACE_PATH"), FileAccess.READ)
	if file == null: return result
	while not file.eof_reached():
		var line: String = file.get_line()
		if not line.contains("owner.solve_started"): continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary and parsed.get("name", "") == "owner.solve_started": result.append(parsed)
	return result


func _wait_natural_recording(label: String, require_baseline: bool = false) -> bool:
	var started: int = Time.get_ticks_msec()
	var stable: int = 0
	while Time.get_ticks_msec() - started < FACING_PHASE_LIMIT_MS and not _finished:
		var ready: bool = not require_baseline or bool(_ui.get_meta("last_baseline_preparation", {}).get("ready", false))
		ready = ready and not _recording_pending() and not _facing_pending() and not _ui.preview_presenter.is_grip_acquisition_pending(_ui.preview_subviewport) and _node_current(_ui.call("_get_active_motion_node"))
		stable = stable + 1 if ready else 0
		if stable >= 6:
			_report.phases.append({"phase": label, "ready_wait_ms": Time.get_ticks_msec() - started})
			_write_report()
			return true
		await process_frame
	_report.phases.append({"phase": label, "ready": false, "status": _ui.footer_status_label.text,
		"owner_status": _compact_facing_status(), "capture": _ui.get_meta("last_prepared_pose_capture", {})})
	return false


func _compact_facing_status() -> Dictionary:
	var result: Dictionary = {}
	var states: Dictionary = _ui.preview_presenter.get_grip_acquisition_status(_ui.preview_subviewport)
	for slot: Variant in states:
		var state: Dictionary = states[slot]
		var row: Dictionary = {}
		for key: String in ["status", "reason", "serial", "actual_3d_grip_verified", "actual_assessment_current", "contact_condition_met"]:
			if state.has(key): row[key] = state[key]
		var realization: Dictionary = state.get("realization", {})
		row["realization_valid"] = realization.get("valid", false)
		row["realization_reason"] = realization.get("reason", "")
		result[String(slot)] = row
	return result


func _facing_check(value: bool, label: String) -> bool:
	_facing_checks += 1
	if not value: _facing_failures.append(label)
	return value


func _observe_frame() -> void:
	super._observe_frame()
	if not _finished and Time.get_ticks_msec() - _started > FACING_RUN_LIMIT_MS: _finish("facing_bounded_run_timeout")


func _write_report() -> void:
	_report["checks"] = _facing_checks
	_report["failures"] = _facing_failures.duplicate()
	if not _output.is_empty(): _write_json("weapon_facing_control.json", _report)


func _finish(reason: String) -> void:
	if reason == "finished" and not _facing_failures.is_empty(): reason = "focused_assertions_failed"
	super._finish(reason)
