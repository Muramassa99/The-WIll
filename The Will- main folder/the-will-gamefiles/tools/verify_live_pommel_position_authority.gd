extends "res://tools/verify_live_forearm_native_motion.gd"

## Real visible-marker pick, then deterministic preview-local drag samples
## through the production queued Pommel path. This is not an OS event latency
## test. Inherited harness isolates the saved weapon; no R/F/Save lifecycle.
func _run_thrust(ui: CombatAnimationStationUI, side: String, _elevation: float) -> Dictionary:
	var report := {"complete": false, "side": side, "input_route": "GUI marker press; _handle_preview_drag; normal queued refresh; GUI release", "requests": [], "failures": []}
	if not ui.reset_active_draft_to_baseline():
		return report.merged({"reason": "reset_failed"})
	var ready: Dictionary = await _await_recorded_reset_baseline(ui)
	report["readiness"] = ready
	if not ready.get("ready", false):
		return report.merged({"reason": "baseline_not_ready"})
	var actor := _get_preview_actor(ui) as PlayerHumanoidRig
	var prop := _get_preview_held_item(ui)
	var skeleton := actor.skeleton
	var slot := &"hand_right" if side == "R" else &"hand_left"
	var relationship: Dictionary = actor.planar_grip_pose_binding.relationship(slot, prop)
	if not relationship.get("hand_in_weapon") is Transform3D:
		return report.merged({"reason": "certified_relationship_missing"})
	var binding: Transform3D = relationship.hand_in_weapon
	var wrist_reference: Dictionary = actor.capture_wrist_motion_start_state(slot)
	if not bool(wrist_reference.get("valid", false)):
		return report.merged({"reason": "wrist_reference_missing"})
	var tip_local: Vector3 = ui.preview_presenter.call("_get_weapon_tip_meta", prop)
	var pommel_local: Vector3 = ui.preview_presenter.call("_get_weapon_pommel_meta", prop)
	var weapon_length := (prop.global_transform * tip_local).distance_to(prop.global_transform * pommel_local)
	report["wrist_reference"] = wrist_reference.state
	report["trailing_contract"] = "soft previous accepted Tip preference; strict Pommel position; forearm rho and wrist gamma held; no travel ratio"
	report["pommel_weapon_local"] = _vec(pommel_local)
	report["grip_station_weapon_local"] = _vec(binding.origin)
	report["distinct_task_and_grip_station_m"] = pommel_local.distance_to(binding.origin)
	if pommel_local.distance_to(binding.origin) < 0.001:
		report.failures.append("fixture_pommel_and_grip_station_not_distinct")
	ui.session_state.current_focus = &"pommel"
	ui.preview_presenter.refresh_focus_visuals(ui.preview_view_container, ui.preview_subviewport,
		ui.call("_get_active_draft"), ui.get_selected_motion_node_index(), &"pommel", ui.call("_get_active_baked_profile"))
	await _wait_frames(2)
	if DisplayServer.get_name() != "headless":
		await _capture_frame(ui, actor, side, output_dir.path_join(side + "_pommel_start.png"))
	var camera := ui.call("_get_preview_camera") as Camera3D
	var press_point: Variant = ui.preview_presenter.get_authoring_marker_screen_position(ui.preview_subviewport, camera, &"pommel")
	if not press_point is Vector2:
		return report.merged({"reason": "visible_pommel_marker_missing"})
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = press_point
	ui.call("_on_preview_gui_input", press)
	report["picked_target"] = String(ui.motion_node_editor.get_drag_target())
	if ui.motion_node_editor.get_drag_target() != &"pommel":
		return report.merged({"reason": "visible_pommel_pick_failed"})
	var first_frame := prop.global_transform
	var first_marker := first_frame * pommel_local
	var halfway_marker := first_marker
	var maximum_angle := 0.0
	for step: int in 40:
		var actual_before := prop.global_transform * pommel_local
		var tip_before := prop.global_transform * tip_local
		var direction := Vector2(4.0, -1.0) if step < 20 else Vector2(-4.0, 1.0)
		var pointer := camera.unproject_position(actual_before) + direction
		var started := Time.get_ticks_usec()
		ui.call("_begin_preview_authoring_lookup_scope")
		ui.call("_handle_preview_drag", pointer)
		ui.call("_end_preview_authoring_lookup_scope")
		var input_ms := float(Time.get_ticks_usec() - started) / 1000.0
		var requested: Vector3 = ui.preview_drag_pommel_requested_local
		var waiting := Time.get_ticks_msec()
		while ui.preview_drag_refresh_pending and Time.get_ticks_msec() - waiting < 5000:
			await process_frame
		if ui.preview_drag_refresh_pending:
			report.failures.append("pending_refresh_timeout:" + str(step))
			break
		await _wait_frames(2)
		var sample := _pommel_sample(ui, actor, prop, slot, binding, tip_local, pommel_local, wrist_reference.state, weapon_length)
		sample.merge({"step": step, "input_ms": input_ms, "step_wall_ms": float(Time.get_ticks_usec() - started) / 1000.0,
			"requested_authoring_local": _vec(requested), "pointer_local_px": [pointer.x, pointer.y],
			"request_start_tip_world": _vec(tip_before), "tip_travel_m": tip_before.distance_to(prop.global_transform * tip_local)})
		var allocation: Dictionary = _get_preview_root(ui).get_meta("weapon_motion_allocation_result", {})
		# The allocator anchor belongs to its latest accepted spatial substep,
		# not necessarily the start of this entire queued UI request.
		for key: String in ["timings", "reason", "status", "task_scale", "orientation_constrained", "task_point_local", "task_point_world", "task_point_world_origin_id", "trailing_tip_anchor_world", "trailing_tip_world", "trailing_tip_world_origin_id"]:
			if allocation.has(key):
				sample["allocation_" + key] = allocation[key]
		if bool(allocation.get("orientation_constrained", true)):
			report.failures.append("pommel_still_orientation_constrained:" + str(step))
		for failure: String in sample.failures:
			report.failures.append(str(step) + ":" + failure)
		maximum_angle = maxf(maximum_angle, rad_to_deg(_frame_angle(first_frame.basis, prop.global_basis)))
		report.requests.append(sample)
		if step == 19:
			halfway_marker = prop.global_transform * pommel_local
		print("LIVE_POMMEL ", JSON.stringify({"step": step, "wall_ms": sample.step_wall_ms, "contact_m": sample.contact_error_m, "endpoint_m": sample.pommel_encode_error_m, "angle_change_degrees": maximum_angle, "failures": sample.failures}))
	var before_release := prop.global_transform
	press.pressed = false
	ui.call("_on_preview_gui_input", press)
	await _wait_frames(4)
	var released := _pommel_sample(ui, actor, prop, slot, binding, tip_local, pommel_local, wrist_reference.state, weapon_length)
	report["after_release"] = released
	for failure: String in released.failures:
		report.failures.append("release:" + failure)
	var release_angle := rad_to_deg(_frame_angle(before_release.basis, prop.global_basis))
	var release_distance := (before_release * pommel_local).distance_to(prop.global_transform * pommel_local)
	report["release_angle_drift_degrees"] = release_angle
	report["release_pommel_drift_m"] = release_distance
	report["maximum_weapon_orientation_change_degrees"] = maximum_angle
	report["forward_marker_travel_m"] = first_marker.distance_to(halfway_marker)
	report["reverse_marker_travel_m"] = halfway_marker.distance_to(prop.global_transform * pommel_local)
	if release_angle > 0.025 or release_distance > 0.00005:
		report.failures.append("release_changed_accepted_pose")
	if first_marker.distance_to(halfway_marker) < 0.001 or halfway_marker.distance_to(prop.global_transform * pommel_local) < 0.001:
		report.failures.append("both_directions_require_real_movement")
	if maximum_angle < 0.1:
		report.failures.append("fixture_did_not_demonstrate_freed_orientation")
	if DisplayServer.get_name() != "headless":
		await _capture_frame(ui, actor, side, output_dir.path_join(side + "_pommel_end.png"))
	report.complete = report.failures.is_empty() and report.requests.size() == 40
	return report

func _pommel_sample(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, prop: Node3D, slot: StringName, binding: Transform3D, tip_local: Vector3, pommel_local: Vector3, wrist_reference: Dictionary, expected_length: float) -> Dictionary:
	var failures: Array[String] = []
	var skeleton := actor.skeleton
	var hand_id := skeleton.find_bone("CC_Base_R_Hand" if slot == &"hand_right" else "CC_Base_L_Hand")
	var actual := skeleton.global_transform * skeleton.get_bone_global_pose(hand_id)
	var expected := prop.global_transform * binding
	var contact_error := actual.origin.distance_to(expected.origin)
	var contact_angle := rad_to_deg(_frame_angle(actual.basis, expected.basis))
	if contact_error > 0.00005 or contact_angle > 0.025:
		failures.append("acquired_contact_changed")
	var node := ui.call("_get_effective_preview_motion_node") as CombatAnimationMotionNode
	var trajectory := _get_trajectory_root(ui)
	var actual_tip := prop.global_transform * tip_local
	var actual_pommel := prop.global_transform * pommel_local
	var length_error := absf(actual_tip.distance_to(actual_pommel) - expected_length)
	if length_error > 0.00005:
		failures.append("weapon_length_changed")
	var wrist: Dictionary = actor.capture_wrist_motion_start_state(slot)
	var rho_error := INF
	var gamma_error := INF
	if bool(wrist.get("valid", false)):
		rho_error = rad_to_deg(absf(float(wrist.state.rho) - float(wrist_reference.rho)))
		gamma_error = rad_to_deg(absf(float(wrist.state.gamma) - float(wrist_reference.gamma)))
	if rho_error > 0.025:
		failures.append("pommel_changed_held_forearm_roll")
	if gamma_error > 0.025:
		failures.append("pommel_changed_held_wrist_z")
	var tip_error := actual_tip.distance_to(trajectory.to_global(node.tip_position_local))
	var pommel_error := actual_pommel.distance_to(trajectory.to_global(node.pommel_position_local))
	if tip_error > 0.00005 or pommel_error > 0.00005:
		failures.append("authored_endpoints_do_not_match_actual_weapon")
	var orientation: Vector3 = ui.preview_presenter.call("_resolve_motion_node_weapon_orientation_degrees", node)
	var decoded: Transform3D = ui.preview_presenter.call("_solve_weapon_segment_transform", prop, trajectory, node,
		tip_local, pommel_local, trajectory.to_global(node.tip_position_local), trajectory.to_global(node.pommel_position_local), orientation)
	var encoded_angle := rad_to_deg(_frame_angle(decoded.basis, prop.global_basis))
	if encoded_angle > 0.025:
		failures.append("encoded_orientation_does_not_match_actual_weapon")
	return {"contact_error_m": contact_error, "contact_error_degrees": contact_angle,
		"tip_encode_error_m": tip_error, "pommel_encode_error_m": pommel_error,
		"forearm_rho_error_degrees": rho_error, "wrist_gamma_error_degrees": gamma_error,
		"weapon_length_error_m": length_error, "actual_tip_world": _vec(actual_tip),
		"orientation_encode_error_degrees": encoded_angle, "actual_pommel_world": _vec(actual_pommel),
		"tip_origin_id": String(node.tip_position_origin_id), "pommel_origin_id": String(node.pommel_position_origin_id),
		"status": ui.footer_status_label.text, "failures": failures}

func _frame_angle(first: Basis, second: Basis) -> float:
	var relative := (first.orthonormalized().get_rotation_quaternion().inverse() * second.orthonormalized().get_rotation_quaternion()).normalized()
	return 2.0 * atan2(Vector3(relative.x, relative.y, relative.z).length(), absf(relative.w))
