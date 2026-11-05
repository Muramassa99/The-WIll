extends "res://tools/verify_skill_grip_reopen.gd"

## Real station pointer input, one latest sample by wall-clock time. Never saves
## source/isolated skills. The inherited harness guards the source-library hash.
## --phase=write --hands=R --weapon=Broken_Balde_v1 --slot=skill_slot_2 --out=<fresh-dir>
const SpeedCheckpoint = preload("res://runtime/combat/combat_animation_render_checkpoint.gd")

func _reopen_write(ui: CombatAnimationStationUI, side: String) -> void:
	allocation_report["scope"] = "Real Tip press/motion/release on isolated saved weapon; same acquired Reset baseline before each speed. No performance pass/fail threshold and no skill Save."
	_check_allocation(ui.reset_active_draft_to_baseline(), "isolated_reset")
	var ready := await _await_recorded_reset_baseline(ui)
	_check_allocation(ready.get("ready", false), "recorded_reset_baseline", ready)
	if not ready.get("ready", false): return
	ready = await _reopen_await_bound(ui, side)
	_check_allocation(ready.get("ready", false), "baseline_binding_ready", ready)
	if not ready.get("ready", false): return
	ui.session_state.current_focus = CombatAnimationSessionState.FOCUS_TIP
	ui.call("_refresh_preview_scene")
	await _wait_frames(3)
	await _reopen_capture(ui)
	var actor := _get_preview_actor(ui) as PlayerHumanoidRig
	var weapon := _get_preview_held_item(ui)
	var preview_root: Node3D = ui.call("_get_preview_root")
	var trajectory: Node3D = ui.call("_get_preview_trajectory_root")
	var camera: Camera3D = ui.call("_get_preview_camera")
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var baseline_node := node.duplicate(true) as CombatAnimationMotionNode
	var draft: CombatAnimationDraft = ui.call("_get_active_draft")
	var selected := ui.get_selected_motion_node_index()
	var camera_state := ui.preview_presenter.capture_camera_state(ui.preview_subviewport)
	var checkpoint := SpeedCheckpoint.capture(ui.preview_presenter, {"preview_root": preview_root,
		"actor_pivot": preview_root.get_node_or_null(ui.preview_presenter.PREVIEW_ACTOR_PIVOT_NAME),
		"trajectory_root": trajectory}, false)
	_check_allocation(not checkpoint.is_empty(), "full_baseline_checkpoint_available")
	_check_allocation(actor.is_authoring_arm_spine_isolation_enabled(), "isolation_enabled")
	if checkpoint.is_empty(): return
	var baseline_body := _boundary_bone_channels(actor)
	var baseline_weapon := weapon.global_transform
	allocation_report["input_accumulated"] = Input.use_accumulated_input
	allocation_report["trials"] = []
	var route := PackedVector2Array([Vector2.ZERO, Vector2(20, 0), Vector2(35, -15), Vector2(10, -30), Vector2(55, -10), Vector2(60, 20)])
	var pixels := clampf(float(options.get("pixels", "60")), 5.0, 120.0)
	for route_index in route.size(): route[route_index] *= pixels / 60.0
	var overall_start := Time.get_ticks_msec()
	for specification: Dictionary in [{"label": "slow", "duration_ms": 6000}, {"label": "normal", "duration_ms": 1500}, {"label": "fast", "duration_ms": 450}]:
		if Time.get_ticks_msec() - overall_start > 120000:
			_check_allocation(false, "trial_budget_exceeded")
			break
		ui.motion_node_editor.end_drag()
		ui.call("_clear_preview_drag_override")
		draft.motion_node_chain[selected] = baseline_node.duplicate(true) as CombatAnimationMotionNode
		ui.call("_invalidate_preview_drag_motion_chain_cache")
		var restored := SpeedCheckpoint.restore(ui.preview_presenter, checkpoint)
		ui.preview_presenter.restore_camera_state(ui.preview_subviewport, camera_state)
		var body_error := _speed_body_error(baseline_body, _boundary_bone_channels(actor))
		var exact_body: bool = body_error.valid
		var exact_weapon := weapon.global_transform.is_equal_approx(baseline_weapon)
		_check_allocation(restored and exact_body and exact_weapon, String(specification.label) + "_same_baseline", {"restored": restored, "body_error": body_error, "exact_weapon": exact_weapon})
		if not restored or not exact_body or not exact_weapon: break
		ui.call("_refresh_endpoint_motion_visuals")
		var display: CombatAnimationMotionNode = ui.call("_build_display_motion_node_for_viewport_pick", ui.call("_get_active_motion_node"))
		var pointer := camera.unproject_position(trajectory.to_global(display.tip_position_local))
		var bounds := Rect2(Vector2.ZERO, ui.preview_view_container.size)
		var inside := true
		for offset: Vector2 in route: inside = inside and bounds.has_point(pointer + offset)
		_check_allocation(inside, String(specification.label) + "_pointer_route_inside_view", {"pointer": pointer, "bounds": bounds})
		if not inside: break
		var trial := await _speed_trial(ui, weapon, camera, preview_root, pointer, route, specification)
		allocation_report.trials.append(trial)
		_check_allocation(trial.get("completed", false), String(specification.label) + "_gesture_completed", {"reason": trial.get("reason", ""), "delivered_samples": trial.get("delivered_samples", 0)})
		if not trial.get("completed", false): break
		await _wait_frames(3)
	allocation_report["actual_acquisition_starts"] = _reopen_solve_count()

func _speed_trial(ui: CombatAnimationStationUI, weapon: Node3D, camera: Camera3D,
		preview_root: Node3D, start: Vector2, route: PackedVector2Array, specification: Dictionary) -> Dictionary:
	var report := specification.duplicate(true)
	var route_length := 0.0
	for route_index in range(1, route.size()): route_length += route[route_index - 1].distance_to(route[route_index])
	var planned_samples := maxi(1, int(ceil(float(specification.duration_ms) * 0.12)))
	report.merge({"completed": false, "start_pointer": start, "route_offsets": Array(route),
		"requested_path_length_px": route_length, "requested_speed_px_sec": route_length * 1000.0 / float(specification.duration_ms),
		"planned_samples": planned_samples, "delivered_samples": 0, "inputs": [], "frames": [], "solves": []})
	_speed_button(ui, start, true)
	report["picked_target"] = String(ui.motion_node_editor.get_drag_target())
	if ui.motion_node_editor.get_drag_target() != &"tip":
		_speed_button(ui, start, false)
		return report.merged({"reason": "tip_not_picked"})
	var began := Time.get_ticks_usec()
	var last_frame := began
	var last_pointer := start
	var sent_index := 0
	var last_refresh: int = ui.preview_drag_last_refresh_msec
	var final_sent_at := -1
	var max_gap_ms := 0.0
	var tip_local: Vector3 = weapon.get_meta("weapon_tip_local", Vector3.ZERO)
	var previous_tip_screen := camera.unproject_position(weapon.to_global(tip_local))
	var last_tip_moved := began
	var max_stationary_ms := 0.0
	var max_tip_jump := 0.0
	var actual_path_length := 0.0
	var delivered_path_length := 0.0
	var accepted_updates := 0
	while Time.get_ticks_usec() - began < 20000000:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed_ms := float(now - began) / 1000.0
		var gap_ms := float(now - last_frame) / 1000.0
		last_frame = now
		max_gap_ms = maxf(max_gap_ms, gap_ms)
		var tip_world := weapon.to_global(tip_local)
		var tip_screen := camera.unproject_position(tip_world)
		var tip_step := previous_tip_screen.distance_to(tip_screen)
		actual_path_length += tip_step
		max_tip_jump = maxf(max_tip_jump, tip_step)
		if final_sent_at < 0:
			max_stationary_ms = maxf(max_stationary_ms, float(now - last_tip_moved) / 1000.0)
		if tip_step >= 0.05: last_tip_moved = now
		previous_tip_screen = tip_screen
		report.frames.append({"ms": elapsed_ms, "gap_ms": gap_ms, "tip_world": [tip_world.x, tip_world.y, tip_world.z],
			"tip_screen": [tip_screen.x, tip_screen.y], "tip_step_px": tip_step, "pointer": [last_pointer.x, last_pointer.y],
			"pending": ui.preview_drag_refresh_pending, "phase": "drive" if final_sent_at < 0 else "held_settle"})
		if ui.preview_drag_last_refresh_msec != last_refresh:
			last_refresh = ui.preview_drag_last_refresh_msec
			var allocation: Dictionary = preview_root.get_meta("weapon_motion_allocation_result", {})
			if float(allocation.get("task_scale", 0.0)) > 0.0: accepted_updates += 1
			report.solves.append({"ms": elapsed_ms, "refresh_cost_ms": ui.preview_drag_last_refresh_cost_msec,
				"status": allocation.get("status", ""), "reason": allocation.get("reason", ""),
				"task_scale": allocation.get("task_scale", -1.0), "iterations": allocation.get("iterations", -1),
				"timings": allocation.get("timings", {}), "groups": allocation.get("contributing_joint_groups", []),
				"active_limits": allocation.get("active_limits", []), "search_failures": allocation.get("search_failures", [])})
		if final_sent_at < 0:
			var desired_index := mini(planned_samples, int(floor(elapsed_ms / float(specification.duration_ms) * float(planned_samples))))
			if desired_index > sent_index:
				var pointer := start + _speed_route_offset(route, route_length * float(desired_index) / float(planned_samples))
				var motion := InputEventMouseMotion.new()
				motion.position = pointer
				motion.relative = pointer - last_pointer
				delivered_path_length += motion.relative.length()
				motion.button_mask = MOUSE_BUTTON_MASK_LEFT
				var input_started := Time.get_ticks_usec()
				ui.call("_on_preview_gui_input", motion)
				report.inputs.append({"ms": elapsed_ms, "sample_index": desired_index, "pointer": pointer,
					"relative": motion.relative, "handler_ms": float(Time.get_ticks_usec() - input_started) / 1000.0})
				report.delivered_samples += 1
				last_pointer = pointer
				sent_index = desired_index
				if sent_index == planned_samples: final_sent_at = Time.get_ticks_usec()
		elif now - final_sent_at >= 700000 and not ui.preview_drag_refresh_pending:
			break
	report["timed_out"] = Time.get_ticks_usec() - began >= 20000000
	report["pending_before_release"] = ui.preview_drag_refresh_pending
	report["max_process_frame_gap_ms"] = max_gap_ms
	report["max_drive_stationary_interval_ms"] = max_stationary_ms
	report["max_actual_tip_frame_step_px"] = max_tip_jump
	report["actual_tip_screen_path_px"] = actual_path_length
	report["delivered_pointer_path_px"] = delivered_path_length
	report["accepted_update_count"] = accepted_updates
	var release_started := Time.get_ticks_usec()
	_speed_button(ui, last_pointer, false)
	report["release_ms"] = float(Time.get_ticks_usec() - release_started) / 1000.0
	await _wait_frames(3)
	report["pending_after_release"] = ui.preview_drag_refresh_pending
	report["final_tip_screen"] = camera.unproject_position(weapon.to_global(tip_local))
	report["final_pointer"] = last_pointer
	report["final_status"] = ui.footer_status_label.text
	report["elapsed_ms"] = float(Time.get_ticks_usec() - began) / 1000.0
	report["completed"] = sent_index == planned_samples and not report.timed_out and not ui.motion_node_editor.is_dragging()
	return report

func _speed_route_offset(route: PackedVector2Array, distance: float) -> Vector2:
	for index in range(1, route.size()):
		var length := route[index - 1].distance_to(route[index])
		if distance <= length: return route[index - 1].lerp(route[index], distance / maxf(length, 0.0001))
		distance -= length
	return route[route.size() - 1]

func _speed_body_error(expected: Dictionary, actual: Dictionary) -> Dictionary:
	var result := {"valid": expected.size() == actual.size(), "max_position_m": 0.0, "max_rotation_deg": 0.0, "max_scale": 0.0}
	for name: String in expected:
		if not actual.has(name):
			result.valid = false
			continue
		var a: Transform3D = expected[name]
		var b: Transform3D = actual[name]
		var aq := a.basis.orthonormalized().get_rotation_quaternion().normalized()
		var bq := b.basis.orthonormalized().get_rotation_quaternion().normalized()
		if aq.dot(bq) < 0.0: bq = -bq
		# Chord distance is stable for near-identical float32 rotations; acos(dot)
		# exaggerates rounding around one and can reject a correctly restored pose.
		var chord := sqrt(pow(aq.x - bq.x, 2) + pow(aq.y - bq.y, 2) + pow(aq.z - bq.z, 2) + pow(aq.w - bq.w, 2))
		result.max_position_m = maxf(result.max_position_m, a.origin.distance_to(b.origin))
		result.max_rotation_deg = maxf(result.max_rotation_deg, rad_to_deg(4.0 * asin(clampf(chord * 0.5, 0.0, 1.0))))
		result.max_scale = maxf(result.max_scale, a.basis.get_scale().distance_to(b.basis.get_scale()))
	result.valid = result.valid and result.max_position_m <= 0.0000001 and result.max_rotation_deg <= 0.0001 and result.max_scale <= 0.0000001
	return result

func _speed_button(ui: CombatAnimationStationUI, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	ui.call("_on_preview_gui_input", event)

func _complete_allocation() -> Dictionary:
	allocation_report.complete = true
	for check: Dictionary in allocation_report.checks:
		if not check.passed: allocation_report.complete = false
	print("POINTER_SPEED complete=%s trials=%d" % [allocation_report.complete, allocation_report.get("trials", []).size()])
	return allocation_report
