extends "res://tools/verify_live_pommel_position_authority.gd"

## Rendered station verifier: --hands=R,L --elevations=0 --out=<fresh directory>.
## Side names identify the gripping main hand; this edits the opposite free arm.
## Real marker press/release and normal queued refresh, deterministic local
## pointer samples. No OS latency claim, grip changes, R/F or Save workflow.
func _run_thrust(ui: CombatAnimationStationUI, side: String, _elevation: float) -> Dictionary:
	var report := {"complete": false, "main_side": side, "requests": [], "failures": []}
	if not ui.reset_active_draft_to_baseline():
		return report.merged({"reason": "reset_failed"})
	var ready: Dictionary = await _await_recorded_reset_baseline(ui)
	report["readiness"] = ready
	if not bool(ready.get("ready", false)):
		return report.merged({"reason": "baseline_not_ready"})
	var actor := _get_preview_actor(ui) as PlayerHumanoidRig
	var prop := _get_preview_held_item(ui)
	var free_side := "L" if side == "R" else "R"
	var slot := &"hand_left" if free_side == "L" else &"hand_right"
	var focus := &"left_hand_proxy" if free_side == "L" else &"right_hand_proxy"
	var prefix := "left" if free_side == "L" else "right"
	var skeleton := actor.skeleton
	var main_frames := _capture_arm_frames(skeleton, side)
	var weapon_frame := prop.global_transform
	var initial_hand := _proxy_bone_world(skeleton, free_side, "Hand")
	ui.session_state.current_focus = focus
	ui.call("_refresh_endpoint_motion_visuals")
	await _wait_frames(2)
	if DisplayServer.get_name() != "headless":
		await _capture_frame(ui, actor, side, output_dir.path_join(side + "_free_hand_start.png"))
	var camera := ui.call("_get_preview_camera") as Camera3D
	for endpoint: String in ["pommel", "tip"]:
		var target := StringName(prefix + "_hand_proxy_" + endpoint)
		var screen: Variant = ui.preview_presenter.get_authoring_marker_screen_position(ui.preview_subviewport, camera, target)
		if not screen is Vector2:
			return report.merged({"reason": "visible_free_hand_marker_missing:" + endpoint})
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = screen
		ui.call("_on_preview_gui_input", press)
		if ui.motion_node_editor.get_drag_target() != target:
			press.pressed = false
			ui.call("_on_preview_gui_input", press)
			return report.merged({"reason": "free_hand_pick_failed:" + endpoint, "picked": String(ui.motion_node_editor.get_drag_target())})
		for step: int in 4:
			var physical := _physical_segment(ui, actor, slot)
			var trajectory := _get_trajectory_root(ui)
			var tip_screen := camera.unproject_position(trajectory.to_global(physical.tip_position_local))
			var pommel_screen := camera.unproject_position(trajectory.to_global(physical.pommel_position_local))
			var pointer: Vector2
			if endpoint == "pommel":
				var travel := [20.0, 360.0, -20.0, -120.0]
				pointer = pommel_screen + Vector2(travel[step], -float(travel[step]) * 0.25)
			else:
				var angles := [30.0, 75.0, -30.0, -75.0]
				pointer = pommel_screen + (tip_screen - pommel_screen).rotated(deg_to_rad(angles[step]))
			var started := Time.get_ticks_usec()
			ui.call("_begin_preview_authoring_lookup_scope")
			ui.call("_handle_preview_drag", pointer)
			ui.call("_end_preview_authoring_lookup_scope")
			var wait_start := Time.get_ticks_msec()
			while ui.preview_drag_refresh_pending and Time.get_ticks_msec() - wait_start < 10000:
				await process_frame
			await _wait_frames(2)
			var sample := _attachment_sample(ui, actor, prop, free_side, slot, focus, main_frames, weapon_frame)
			sample.merge({"phase": endpoint, "step": step, "elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0,
				"pointer_local_px": [pointer.x, pointer.y], "pending_timeout": ui.preview_drag_refresh_pending})
			if ui.preview_drag_refresh_pending:
				sample.failures.append("queued_refresh_timeout")
			_append_proxy_sample(report, sample)
		press.pressed = false
		ui.call("_on_preview_gui_input", press)
		await _wait_frames(3)
		var released := _attachment_sample(ui, actor, prop, free_side, slot, focus, main_frames, weapon_frame)
		released["phase"] = endpoint + "_release"
		_append_proxy_sample(report, released)
	# Reproduce old persisted/requested coordinates displaced from the hand,
	# then use the ordinary elbow UI setter. This must repair accepted proxy data
	# without dragging the stationary weapon or silently changing the other arm.
	var motion := ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var actual_segment := _physical_segment(ui, actor, slot)
	var detached_offset := Vector3(1.25, 0.4, -0.3)
	ui.call("_apply_hand_proxy_segment_to_motion_node", motion, slot,
		actual_segment.tip_position_local + detached_offset, actual_segment.pommel_position_local + detached_offset)
	var elbow: Dictionary = actor.get_authoring_upperarm_roll_control_state(slot)
	if elbow.is_empty():
		report.failures.append("elbow_control_missing")
	else:
		var changed := ui.set_selected_motion_node_upperarm_roll(slot, float(elbow.initial_roll_degrees) + 15.0, false, false, false, true, false)
		await _wait_frames(3)
		var after_elbow := _attachment_sample(ui, actor, prop, free_side, slot, focus, main_frames, weapon_frame)
		after_elbow.merge({"phase": "detached_authored_proxy_then_elbow", "setter_changed": changed,
			"seeded_detachment_m": detached_offset.length()})
		_append_proxy_sample(report, after_elbow)
	var hand_travel := initial_hand.origin.distance_to(_proxy_bone_world(skeleton, free_side, "Hand").origin)
	report["final_free_hand_travel_m"] = hand_travel
	var maximum_travel := 0.0
	for sample: Dictionary in report.requests:
		maximum_travel = maxf(maximum_travel, initial_hand.origin.distance_to(sample.hand_world))
	report["maximum_free_hand_travel_m"] = maximum_travel
	if maximum_travel < 0.0005:
		report.failures.append("fixture_did_not_produce_real_hand_movement")
	if DisplayServer.get_name() != "headless":
		await _capture_frame(ui, actor, side, output_dir.path_join(side + "_free_hand_end.png"))
	report.complete = report.failures.is_empty() and report.requests.size() == 11
	return report

func _physical_segment(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, slot: StringName) -> Dictionary:
	return ui.preview_presenter.call("_resolve_hand_proxy_default_trajectory_segment_state", actor, _get_trajectory_root(ui), slot)

func _attachment_sample(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, prop: Node3D,
		free_side: String, slot: StringName, focus: StringName, main_frames: Dictionary, weapon_frame: Transform3D) -> Dictionary:
	var failures: Array[String] = []
	var trajectory := _get_trajectory_root(ui)
	var physical := _physical_segment(ui, actor, slot)
	var expected_tip: Vector3 = trajectory.to_global(physical.tip_position_local)
	var expected_pommel: Vector3 = trajectory.to_global(physical.pommel_position_local)
	var motion := ui.call("_get_effective_preview_motion_node") as CombatAnimationMotionNode
	var stored: Dictionary = ui.call("_resolve_motion_node_hand_proxy_segment", motion, slot)
	var stored_tip := trajectory.to_global(stored.tip_position_local as Vector3)
	var stored_pommel := trajectory.to_global(stored.pommel_position_local as Vector3)
	var hand := _proxy_bone_world(actor.skeleton, free_side, "Hand")
	var index := _proxy_bone_world(actor.skeleton, free_side, "Index1").origin
	var pinky := _proxy_bone_world(actor.skeleton, free_side, "Pinky1").origin
	var line := pinky - index
	var bone_center := index + line * (hand.origin - index).dot(line) / line.length_squared()
	var helper_center_error := ((expected_tip + expected_pommel) * 0.5).distance_to(bone_center)
	var marker_errors: Dictionary = {}
	var found := 0
	var wanted_prefix := "left" if free_side == "L" else "right"
	for candidate: Dictionary in ui.preview_presenter.call("_authoring_marker_candidates", ui.preview_subviewport, focus):
		var target := String(candidate.target)
		var marker := candidate.marker as MeshInstance3D
		if target == wanted_prefix + "_hand_proxy_tip":
			marker_errors["tip"] = marker.global_position.distance_to(expected_tip)
			found += 1
		elif target == wanted_prefix + "_hand_proxy_pommel":
			marker_errors["pommel"] = marker.global_position.distance_to(expected_pommel)
			found += 1
	var stored_error := maxf(stored_tip.distance_to(expected_tip), stored_pommel.distance_to(expected_pommel))
	if stored_error > 0.00005:
		failures.append("stored_proxy_detached_from_physical_hand")
	if helper_center_error > 0.00005:
		failures.append("physical_helper_disagrees_with_hand_index_pinky_bones")
	if found != 2 or float(marker_errors.get("tip", INF)) > 0.00005 or float(marker_errors.get("pommel", INF)) > 0.00005:
		failures.append("visible_proxy_detached_from_physical_hand")
	var maximum_main_position := 0.0
	var maximum_main_angle := 0.0
	for bone: int in main_frames:
		var before: Transform3D = main_frames[bone]
		var actual := actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(bone)
		maximum_main_position = maxf(maximum_main_position, before.origin.distance_to(actual.origin))
		maximum_main_angle = maxf(maximum_main_angle, rad_to_deg(_frame_angle(before.basis, actual.basis)))
	if maximum_main_position > 0.00005 or maximum_main_angle > 0.025:
		failures.append("other_arm_moved")
	var weapon_position := weapon_frame.origin.distance_to(prop.global_position)
	var weapon_angle := rad_to_deg(_frame_angle(weapon_frame.basis, prop.global_basis))
	if weapon_position > 0.00005 or weapon_angle > 0.025:
		failures.append("weapon_moved")
	var result: Dictionary = _get_preview_root(ui).get_meta("independent_arm_edit_result", {})
	return {"failures": failures, "hand_world": hand.origin, "stored_error_m": stored_error,
		"marker_errors_m": marker_errors, "bone_center_error_m": helper_center_error,
		"other_arm_position_m": maximum_main_position, "other_arm_angle_degrees": maximum_main_angle,
		"weapon_position_m": weapon_position, "weapon_angle_degrees": weapon_angle,
		"allocation_status": result.get("status"), "allocation_reason": result.get("reason"),
		"retained_previous_pose": result.get("retained_previous_pose", false), "footer": ui.footer_status_label.text}

func _capture_arm_frames(skeleton: Skeleton3D, side: String) -> Dictionary:
	var result: Dictionary = {}
	var upper := skeleton.find_bone("CC_Base_" + side + "_Upperarm")
	for bone: int in skeleton.get_bone_count():
		var ancestor := bone
		while ancestor >= 0 and ancestor != upper:
			ancestor = skeleton.get_bone_parent(ancestor)
		if ancestor == upper:
			result[bone] = skeleton.global_transform * skeleton.get_bone_global_pose(bone)
	return result

func _proxy_bone_world(skeleton: Skeleton3D, side: String, suffix: String) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("CC_Base_" + side + "_" + suffix))

func _append_proxy_sample(report: Dictionary, sample: Dictionary) -> void:
	report.requests.append(sample)
	for failure: String in sample.failures:
		report.failures.append(String(sample.phase) + ":" + failure)
	print("LIVE_HAND_PROXY ", JSON.stringify(sample))
