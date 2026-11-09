extends "res://tools/verify_live_hand_proxy_attachment.gd"

const FingerControls = preload("res://runtime/combat/combat_empty_hand_finger_control.gd")
const FingerHinges = preload("res://runtime/player/player_digit_hinge_rules.gd")
const FingerPreparedPose = preload("res://core/models/combat_prepared_pose.gd")

## Rendered real station verifier. --hands=R,L --elevations=0 --out=<fresh dir>.
## Uses the public numeric UI setter, not synthetic OS input. The inherited
## harness isolates the existing saved weapon. No full F/Save workflow is run.
## Both empty-hand sides are covered under opposite main-hand acquisition;
## this does not claim coverage of the separate unarmed ownership lifecycle.
func _run_thrust(ui: CombatAnimationStationUI, side: String, _elevation: float) -> Dictionary:
	var report := {"complete": false, "main_side": side, "requests": [], "checks": [], "failures": [],
		"input_route": "public UI curl setter; GUI marker pick/release; direct preview-local arc samples through _handle_preview_drag (does not test captured-pointer speed filtering); prepared-node capture",
		"unarmed_lifecycle_tested": false}
	if not ui.reset_active_draft_to_baseline():
		return report.merged({"reason": "reset_failed"})
	var ready: Dictionary = await _await_recorded_reset_baseline(ui)
	report["readiness"] = ready
	if not bool(ready.get("ready", false)):
		return report.merged({"reason": "baseline_not_ready"})
	var actor := _get_preview_actor(ui) as PlayerHumanoidRig
	var prop := _get_preview_held_item(ui)
	var slot := &"hand_left" if side == "R" else &"hand_right"
	var occupied_slot := &"hand_right" if side == "R" else &"hand_left"
	var free_side := "L" if side == "R" else "R"
	var skeleton := actor.skeleton
	var motion := ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var weapon_frame := prop.global_transform
	var idle: Dictionary = actor.finger_grip_presenter.capture_default_open_finger_rotations(skeleton, slot)
	if not bool(idle.get("valid", false)):
		return report.merged({"reason": "fixed_idle_reference_missing", "idle": idle})
	var focus_ids: Array = ui.call("_resolve_available_focus_ids")
	var expected: Array[StringName] = FingerControls.focus_ids(slot)
	var proxy := &"left_hand_proxy" if slot == &"hand_left" else &"right_hand_proxy"
	var proxy_index: int = focus_ids.find(proxy)
	var order_ok: bool = proxy_index >= 4
	for index: int in 4:
		order_ok = order_ok and proxy_index >= 4 and focus_ids[proxy_index - 4 + index] == expected[index]
	_finger_check(report, order_ok, "four_finger_controls_immediately_precede_free_hand_proxy", {"focus_ids": focus_ids})
	var occupied_before := _all_local_bone_poses(skeleton)
	var occupied_node_signature := FingerPreparedPose.node_pose_signature(motion)
	var rejected := not ui.set_selected_motion_node_finger_curl(occupied_slot, &"index", 90.0)
	await _wait_frames(2)
	var occupied_difference := _unrelated_pose_difference(skeleton, occupied_before, {})
	_finger_check(report, rejected and FingerPreparedPose.node_pose_signature(motion) == occupied_node_signature
		and float(occupied_difference.maximum_rotation_degrees) < 0.025, "occupied_hand_rejected_without_pose_or_authored_change", occupied_difference)
	for focus: StringName in FingerControls.focus_ids(occupied_slot):
		var description: Dictionary = ui.preview_presenter.describe_empty_hand_finger_control(ui.preview_subviewport, motion, focus)
		_finger_check(report, not focus_ids.has(focus) and not bool(description.get("available", false)), "occupied_focus_unavailable:" + String(focus))
	for digit: StringName in FingerControls.DIGITS:
		var focus := StringName(("left_finger_" if slot == &"hand_left" else "right_finger_") + String(digit))
		ui.session_state.current_focus = focus
		ui.call("_refresh_endpoint_motion_visuals")
		await _wait_frames(2)
		var before_control: Dictionary = ui.preview_presenter.describe_empty_hand_finger_control(ui.preview_subviewport, motion, focus)
		_finger_check(report, bool(before_control.get("available", false)), "free_finger_control_available:" + String(digit))
		var camera := ui.call("_get_preview_camera") as Camera3D
		var marker: Variant = ui.preview_presenter.get_authoring_marker_screen_position(ui.preview_subviewport, camera, focus)
		_finger_check(report, marker is Vector2, "visible_finger_marker:" + String(digit))
		var open_rotations: Dictionary = {}
		var maximum_joint_change := 0.0
		for angle: float in [0.0, 90.0, 180.0, 90.0, 0.0]:
			var before := _all_local_bone_poses(skeleton)
			var started := Time.get_ticks_usec()
			var changed := ui.set_selected_motion_node_finger_curl(slot, digit, angle)
			var setter_finished := Time.get_ticks_usec()
			await _wait_frames(3)
			var frames_finished := Time.get_ticks_usec()
			var sample := _finger_sample(ui, actor, prop, slot, digit, angle, idle, before, weapon_frame)
			sample["setter_changed"] = changed
			sample["setter_call_ms"] = float(setter_finished - started) / 1000.0
			sample["three_frame_wait_ms"] = float(frames_finished - setter_finished) / 1000.0
			sample["wall_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
			if not changed:
				sample.failures.append("requested_new_angle_was_not_applied")
			for bone: StringName in sample.rotations:
				if open_rotations.has(bone):
					maximum_joint_change = maxf(maximum_joint_change, _rotation_error_degrees(open_rotations[bone], sample.rotations[bone]))
			if angle == 0.0 and open_rotations.is_empty():
				open_rotations = sample.rotations.duplicate()
			elif angle == 0.0:
				for bone: StringName in open_rotations:
					if _rotation_error_degrees(open_rotations[bone], sample.rotations[bone]) > 0.025:
						sample.failures.append("return_to_open_accumulated_roll:" + String(bone))
			report.requests.append(sample)
			for failure: String in sample.failures:
				report.failures.append(String(digit) + ":" + str(angle) + ":" + failure)
			print("LIVE_EMPTY_HAND_FINGER ", JSON.stringify(sample))
			if angle == 180.0 and DisplayServer.get_name() != "headless":
				await _capture_finger_closeup(ui, actor, free_side, output_dir.path_join(side + "_" + String(digit) + "_180.png"))
		_finger_check(report, maximum_joint_change > 30.0, "meaningful_finger_motion:" + String(digit), {"maximum_joint_change_degrees": maximum_joint_change})
	await _exercise_finger_arc(ui, actor, prop, slot, idle, weapon_frame, report)
	# Unequal values make a persistence mix-up detectable, including the digit
	# mapping for Mid versus the user-facing name middle.
	for index: int in FingerControls.DIGITS.size():
		ui.set_selected_motion_node_finger_curl(slot, FingerControls.DIGITS[index], float(index + 1) * 45.0)
	await _wait_frames(4)
	var capture: Dictionary = {}
	for attempt: int in 60:
		capture = ui.capture_selected_prepared_pose(false, true)
		if bool(capture.get("valid", false)):
			break
		if String(capture.get("reason", "")) != "prepared_pose_settling":
			break
		await _wait_frames(2)
	report["capture"] = capture
	_finger_check(report, bool(capture.get("valid", false)), "current_finger_endpoint_can_be_recorded", capture)
	if bool(capture.get("valid", false)):
		_check_recorded_fingers(report, motion, skeleton, slot)
		var duplicate := motion.duplicate_node()
		_finger_check(report, FingerPreparedPose.node_pose_signature(duplicate) == FingerPreparedPose.node_pose_signature(motion)
			and duplicate.prepared_pose == motion.prepared_pose, "node_duplication_carries_curls_and_actual_recorded_pose")
		var path := output_dir.path_join(side + "_finger_node.tres")
		var save_error: Error = ResourceSaver.save(motion, path)
		_finger_check(report, save_error == OK, "recorded_node_resource_save", {"error": save_error})
		if save_error == OK:
			var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CombatAnimationMotionNode
			_finger_check(report, loaded != null, "recorded_node_resource_reload")
			if loaded != null:
				_finger_check(report, loaded.prepared_pose_signature == FingerPreparedPose.node_pose_signature(loaded)
					and FingerControls.get_curls(loaded, slot) == FingerControls.get_curls(motion, slot), "reloaded_curls_and_prepared_signature_agree")
				_check_recorded_fingers(report, loaded, skeleton, slot)
	if DisplayServer.get_name() != "headless":
		await _capture_finger_closeup(ui, actor, free_side, output_dir.path_join(side + "_mixed_fingers.png"))
	report.complete = report.failures.is_empty() and report.requests.size() == 20
	return report

func _exercise_finger_arc(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, prop: Node3D,
		slot: StringName, idle: Dictionary, weapon_frame: Transform3D, report: Dictionary) -> void:
	var focus := StringName(("left_finger_" if slot == &"hand_left" else "right_finger_") + "index")
	ui.session_state.current_focus = focus
	ui.call("_refresh_endpoint_motion_visuals")
	await _wait_frames(2)
	var motion := ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var frame: Dictionary = ui.preview_presenter.describe_empty_hand_finger_control(ui.preview_subviewport, motion, focus)
	if not bool(frame.get("available", false)):
		_finger_check(report, false, "arc_drag_control_available")
		return
	var camera := ui.call("_get_preview_camera") as Camera3D
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(float(frame.radius) * 3.0, 0.25)
	camera.global_position = (frame.origin as Vector3) + (frame.axis as Vector3) * 0.5
	camera.look_at(frame.origin, frame.radial)
	await _wait_frames(2)
	var pointer: Variant = ui.preview_presenter.get_authoring_marker_screen_position(ui.preview_subviewport, camera, focus)
	if not pointer is Vector2:
		_finger_check(report, false, "arc_drag_marker_available")
		return
	# Deterministic injected positions must not mix with physical cursor motion
	# or warp-generated GUI events during the await gaps. The direct calls below
	# still exercise the same pick/drag/release methods while delivery is muted.
	var previous_process_input: bool = ui.is_processing_input()
	var previous_mouse_filter: int = ui.preview_view_container.mouse_filter
	ui.set_process_input(false)
	ui.preview_view_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pointer
	ui.call("_on_preview_gui_input", press)
	report["arc_press_state"] = _finger_drag_diagnostic(ui, camera)
	var picked: bool = ui.motion_node_editor.get_drag_target() == focus and not ui.preview_finger_drag_state.is_empty()
	_finger_check(report, picked, "production_finger_marker_pick", {"picked": ui.motion_node_editor.get_drag_target()})
	if not picked:
		press.pressed = false
		ui.call("_on_preview_gui_input", press)
		ui.set_process_input(previous_process_input)
		ui.preview_view_container.mouse_filter = previous_mouse_filter
		return
	# Go past the upper endpoint, then immediately reverse. No invisible
	# accumulated demand should need undoing before the control can move back.
	var pointer_angles: Array[float] = [60.0, 120.0, 180.0, 210.0, 180.0, 120.0, 60.0, 30.0]
	var expected_angles: Array[float] = [60.0, 120.0, 180.0, 180.0, 150.0, 90.0, 30.0, 0.0]
	var samples: Array[Dictionary] = []
	for index: int in pointer_angles.size():
		var position := (frame.origin as Vector3) + (frame.radial as Vector3).rotated(frame.axis, deg_to_rad(pointer_angles[index])) * float(frame.radius)
		var next_pointer := camera.unproject_position(position)
		var before := _all_local_bone_poses(actor.skeleton)
		var input_before := _finger_drag_diagnostic(ui, camera)
		# The gesture is picked/released via the GUI, but these are deterministic
		# already-delivered preview positions. Sending absolute samples as raw
		# captured events would test the speed throttle instead of the arc math.
		var started := Time.get_ticks_usec()
		ui.call("_begin_preview_authoring_lookup_scope")
		ui.call("_handle_preview_drag", next_pointer)
		ui.call("_end_preview_authoring_lookup_scope")
		var drag_finished := Time.get_ticks_usec()
		var input_after_call := _finger_drag_diagnostic(ui, camera)
		await _wait_frames(2)
		var frames_finished := Time.get_ticks_usec()
		var input_after_frames := _finger_drag_diagnostic(ui, camera)
		var sample := _finger_sample(ui, actor, prop, slot, &"index", expected_angles[index], idle, before, weapon_frame)
		sample["pointer_angle_degrees"] = pointer_angles[index]
		sample["drag_call_ms"] = float(drag_finished - started) / 1000.0
		sample["two_frame_wait_ms"] = float(frames_finished - drag_finished) / 1000.0
		sample["pointer_local_px"] = [next_pointer.x, next_pointer.y]
		sample["input_before"] = input_before
		sample["input_after_call"] = input_after_call
		sample["input_after_frames"] = input_after_frames
		samples.append(sample)
		for failure: String in sample.failures:
			report.failures.append("gui_arc:" + str(index) + ":" + failure)
		pointer = next_pointer
	var before_release := _all_local_bone_poses(actor.skeleton)
	press.position = pointer
	press.pressed = false
	ui.call("_on_preview_gui_input", press)
	await _wait_frames(3)
	var release_difference := _unrelated_pose_difference(actor.skeleton, before_release, {})
	_finger_check(report, not ui.motion_node_editor.is_dragging() and ui.preview_finger_drag_state.is_empty()
		and float(release_difference.maximum_rotation_degrees) <= 0.025, "arc_release_keeps_accepted_finger_pose", release_difference)
	report["arc_release_state"] = _finger_drag_diagnostic(ui, camera)
	ui.set_process_input(previous_process_input)
	ui.preview_view_container.mouse_filter = previous_mouse_filter
	report["gui_arc_samples"] = samples

func _finger_drag_diagnostic(ui: CombatAnimationStationUI, camera: Camera3D) -> Dictionary:
	var drag: Dictionary = ui.preview_finger_drag_state.duplicate(true)
	return {"camera": {"transform": camera.global_transform, "projection": camera.projection,
		"size": camera.size, "viewport_size": ui.preview_subviewport.size},
		"finger_drag_state": drag, "drag_target": ui.motion_node_editor.get_drag_target(),
		"process_input": ui.is_processing_input(), "container_mouse_filter": ui.preview_view_container.mouse_filter}

func _finger_sample(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, prop: Node3D,
		slot: StringName, digit: StringName, angle: float, idle: Dictionary, before: Dictionary, weapon_frame: Transform3D) -> Dictionary:
	var failures: Array[String] = []
	var selected: Dictionary = {}
	var rotations: Dictionary = {}
	var joint_errors: Dictionary = {}
	var skeleton := actor.skeleton
	for rule: Dictionary in FingerHinges.get_chain_rules(slot, digit):
		var bone: StringName = rule.bone
		selected[bone] = true
		var bone_id := skeleton.find_bone(String(bone))
		var actual := skeleton.get_bone_pose_rotation(bone_id)
		var reference: Quaternion = idle.rotations[bone]
		var joint_degrees := lerpf(float(rule.open_degrees), float(rule.closed_degrees), angle / 180.0)
		var expected := (reference * Quaternion((rule.hinge_axis_local as Vector3).normalized(), deg_to_rad(joint_degrees))).normalized()
		var error := _rotation_error_degrees(expected, actual)
		rotations[bone] = actual
		joint_errors[bone] = error
		if error > 0.025:
			failures.append("actual_finger_does_not_match_requested_control:" + String(bone))
	var unchanged := _unrelated_pose_difference(skeleton, before, selected)
	if float(unchanged.maximum_rotation_degrees) > 0.025 or float(unchanged.maximum_position_m) > 0.00005 or float(unchanged.maximum_scale_change) > 0.000001:
		failures.append("unselected_bones_or_bone_dimensions_changed")
	var weapon_position := prop.global_position.distance_to(weapon_frame.origin)
	var weapon_angle := rad_to_deg(_frame_angle(prop.global_basis, weapon_frame.basis))
	if weapon_position > 0.00005 or weapon_angle > 0.025:
		failures.append("finger_edit_moved_weapon")
	var motion := ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var curls: Dictionary = FingerControls.get_curls(motion, slot)
	if not curls.has(digit) or absf(float(curls.get(digit, -1.0)) - angle) > 0.0001:
		failures.append("authored_curl_does_not_match_request")
	var focus := StringName(("left_finger_" if slot == &"hand_left" else "right_finger_") + String(digit))
	var description: Dictionary = ui.preview_presenter.describe_empty_hand_finger_control(ui.preview_subviewport, motion, focus)
	if not bool(description.get("available", false)) or absf(float(description.get("angle_degrees", -1.0)) - angle) > 0.001:
		failures.append("displayed_control_does_not_match_request")
	return {"digit": digit, "angle_degrees": angle, "rotations": rotations, "joint_error_degrees": joint_errors,
		"unchanged_bones": unchanged, "weapon_position_error_m": weapon_position, "weapon_angle_error_degrees": weapon_angle,
		"display": description, "failures": failures}

func _all_local_bone_poses(skeleton: Skeleton3D) -> Dictionary:
	var result: Dictionary = {}
	for index: int in skeleton.get_bone_count():
		result[StringName(skeleton.get_bone_name(index))] = {"rotation": skeleton.get_bone_pose_rotation(index),
			"position": skeleton.get_bone_pose_position(index), "scale": skeleton.get_bone_pose_scale(index)}
	return result

func _unrelated_pose_difference(skeleton: Skeleton3D, before: Dictionary, allowed_rotations: Dictionary) -> Dictionary:
	var max_rotation := 0.0
	var max_position := 0.0
	var max_scale := 0.0
	var changed_bone := ""
	for index: int in skeleton.get_bone_count():
		var bone := StringName(skeleton.get_bone_name(index))
		var prior: Dictionary = before[bone]
		if not allowed_rotations.has(bone):
			var angle := _rotation_error_degrees(prior.rotation, skeleton.get_bone_pose_rotation(index))
			if angle > max_rotation:
				max_rotation = angle
				changed_bone = String(bone)
		max_position = maxf(max_position, (prior.position as Vector3).distance_to(skeleton.get_bone_pose_position(index)))
		max_scale = maxf(max_scale, (prior.scale as Vector3).distance_to(skeleton.get_bone_pose_scale(index)))
	return {"maximum_rotation_degrees": max_rotation, "maximum_position_m": max_position,
		"maximum_scale_change": max_scale, "largest_rotating_bone": changed_bone}

func _rotation_error_degrees(a: Quaternion, b: Quaternion) -> float:
	var delta := (a.normalized().inverse() * b.normalized()).normalized()
	return rad_to_deg(2.0 * atan2(Vector3(delta.x, delta.y, delta.z).length(), absf(delta.w)))

func _check_recorded_fingers(report: Dictionary, motion: CombatAnimationMotionNode, skeleton: Skeleton3D, slot: StringName) -> void:
	var names: Array = motion.prepared_pose.get("bone_names", [])
	var rotations: Array = motion.prepared_pose.get("pose_rotations", [])
	for digit: StringName in FingerControls.DIGITS:
		for rule: Dictionary in FingerHinges.get_chain_rules(slot, digit):
			var bone: StringName = rule.bone
			var record_index: int = names.find(bone)
			var error := INF
			if record_index >= 0 and record_index < rotations.size():
				var stored: Variant = rotations[record_index]
				if stored is Vector4:
					stored = Quaternion(stored.x, stored.y, stored.z, stored.w)
				if stored is Quaternion:
					error = _rotation_error_degrees(stored, skeleton.get_bone_pose_rotation(skeleton.find_bone(String(bone))))
			_finger_check(report, error <= 0.025, "recorded_finger_matches_visible:" + String(bone), {"error_degrees": error})

func _capture_finger_closeup(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, side: String, path: String) -> void:
	var camera := ui.call("_get_preview_camera") as Camera3D
	var hand := _proxy_bone_world(actor.skeleton, side, "Hand")
	var index := _proxy_bone_world(actor.skeleton, side, "Index1").origin
	var pinky := _proxy_bone_world(actor.skeleton, side, "Pinky1").origin
	var across := (index - pinky).normalized()
	var forward := ((index + pinky) * 0.5 - hand.origin).normalized()
	var normal := across.cross(forward).normalized()
	var center := (index + pinky) * 0.5 + forward * 0.025
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.27
	camera.global_position = center + normal * 0.35 + across * 0.15
	camera.look_at(center, forward)
	ui.preview_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await RenderingServer.frame_post_draw
	var shot := ui.preview_subviewport.get_texture().get_image()
	if shot != null and not shot.is_empty():
		shot.save_png(path)

func _finger_check(report: Dictionary, passed: bool, name: String, details: Dictionary = {}) -> void:
	report.checks.append({"passed": passed, "name": name, "details": details})
	if not passed:
		report.failures.append(name)
