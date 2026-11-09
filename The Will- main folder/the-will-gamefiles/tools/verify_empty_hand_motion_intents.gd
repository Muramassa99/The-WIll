extends "res://tools/verify_live_hand_proxy_attachment.gd"

## Focused rendered regression for the empty hand's two existing endpoint controls.
## Example: --weapon=Broken_Glave_v1 --slot=skill_slot_2 --hands=R,L
## --elevations=0 --reuse-station=false --out=<fresh directory>.
## The inherited runner clones the saved weapon into isolated libraries. This
## probe uses marker press, queued pointer samples and release; no R/F/Save.

const INTENT_POSITION_TOLERANCE := 0.00005
const INTENT_ANGLE_TOLERANCE := 0.025

func _run_thrust(ui: CombatAnimationStationUI, main_side: String, _elevation: float) -> Dictionary:
	var report := {"complete": false, "main_side": main_side, "requests": [], "failures": [],
		"scope": "Isolated saved weapon; empty-hand translation and orientation pointer intents; physical marker attachment; frozen other arm/body/weapon; occupied-slot UI guards. No R/F/Save or grip certificate."}
	manifest["scope"] = report.scope
	if ui.active_wip_library == null or not ui.active_wip_library.save_file_path.begins_with(output_dir + "/isolated_"):
		return report.merged({"reason": "isolated_library_required"})
	var source_path: String = ProjectSettings.globalize_path(PlayerForgeWipLibraryStateScript.DEFAULT_SAVE_FILE_PATH)
	var source_hash := FileAccess.get_sha256(source_path)
	if source_hash.is_empty():
		return report.merged({"reason": "source_hash_unavailable"})
	if not ui.reset_active_draft_to_baseline():
		return report.merged({"reason": "reset_failed"})
	var ready: Dictionary = await _await_recorded_reset_baseline(ui)
	report["readiness"] = ready
	if not ready.get("ready", false):
		return report.merged({"reason": "baseline_not_ready"})
	var actor := _get_preview_actor(ui) as PlayerHumanoidRig
	var prop := _get_preview_held_item(ui)
	var free_side := "L" if main_side == "R" else "R"
	var slot := &"hand_left" if free_side == "L" else &"hand_right"
	var focus := &"left_hand_proxy" if free_side == "L" else &"right_hand_proxy"
	var initial_frozen := _intent_frozen_frames(actor.skeleton, free_side)
	var main_frames := _capture_arm_frames(actor.skeleton, main_side)
	var weapon_frame := prop.global_transform
	ui.session_state.current_focus = focus
	ui.call("_refresh_endpoint_motion_visuals")
	await _wait_frames(2)
	if DisplayServer.get_name() != "headless":
		report["start_image"] = await _capture_frame(ui, actor, free_side, output_dir.path_join(main_side + "_empty_hand_start.png"))
	for endpoint: String in ["pommel", "tip"]:
		var phase: Dictionary = await _intent_drag(ui, actor, prop, free_side, slot, focus,
			endpoint, initial_frozen, main_frames, weapon_frame)
		report.requests.append(phase)
		for failure: String in phase.failures:
			report.failures.append(endpoint + ":" + failure)
	var occupancy := _intent_occupancy_guards(ui, actor, prop, main_side, free_side)
	report["occupancy"] = occupancy
	for failure: String in occupancy.failures:
		report.failures.append("occupancy:" + failure)
	if DisplayServer.get_name() != "headless":
		report["end_image"] = await _capture_frame(ui, actor, free_side, output_dir.path_join(main_side + "_empty_hand_end.png"))
	report["source_sha256_before"] = source_hash
	report["source_sha256_after"] = FileAccess.get_sha256(source_path)
	if source_hash != report.source_sha256_after:
		report.failures.append("source_library_changed")
	report.complete = report.failures.is_empty() and report.requests.size() == 2
	return report

func _intent_drag(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, prop: Node3D,
		free_side: String, slot: StringName, focus: StringName, endpoint: String,
		frozen: Dictionary, main_frames: Dictionary, weapon_frame: Transform3D) -> Dictionary:
	var result := {"complete": false, "endpoint": endpoint, "samples": [], "failures": []}
	var camera := ui.call("_get_preview_camera") as Camera3D
	var prefix := "left" if free_side == "L" else "right"
	var target := StringName(prefix + "_hand_proxy_" + endpoint)
	var screen: Variant = ui.preview_presenter.get_authoring_marker_screen_position(ui.preview_subviewport, camera, target)
	if not screen is Vector2:
		result.failures.append("visible_marker_missing")
		return result
	var start_hand := _proxy_bone_world(actor.skeleton, free_side, "Hand")
	var start_wrist: Dictionary = actor.capture_wrist_motion_start_state(slot)
	result["initial_wrist_measurement"] = start_wrist
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	ui.call("_on_preview_gui_input", press)
	result["picked_target"] = String(ui.motion_node_editor.get_drag_target())
	if ui.motion_node_editor.get_drag_target() != target:
		press.pressed = false
		ui.call("_on_preview_gui_input", press)
		result.failures.append("visible_marker_pick_failed")
		return result
	var max_translation := 0.0
	var max_orientation := 0.0
	var pointer: Vector2 = screen
	# Separate modest forward/reverse commands, based on the currently displayed
	# hand. A rejected request is never reused as the next frame's physical origin.
	for step: int in 4:
		var physical := _physical_segment(ui, actor, slot)
		var trajectory := _get_trajectory_root(ui)
		var tip_screen := camera.unproject_position(trajectory.to_global(physical.tip_position_local))
		var pommel_screen := camera.unproject_position(trajectory.to_global(physical.pommel_position_local))
		if endpoint == "pommel":
			var direction := 1.0 if step < 2 else -1.0
			pointer = pommel_screen + Vector2(12.0 * direction, -5.0 * direction)
		else:
			var angle := 8.0 if step < 2 else -8.0
			pointer = pommel_screen + (tip_screen - pommel_screen).rotated(deg_to_rad(angle))
		var started := Time.get_ticks_usec()
		ui.call("_begin_preview_authoring_lookup_scope")
		ui.call("_handle_preview_drag", pointer)
		ui.call("_end_preview_authoring_lookup_scope")
		var deadline := Time.get_ticks_msec() + 10000
		while ui.preview_drag_refresh_pending and Time.get_ticks_msec() < deadline:
			await process_frame
		await _wait_frames(2)
		var sample := _intent_sample(ui, actor, prop, free_side, slot, focus, frozen, main_frames, weapon_frame)
		_intent_check_mode_and_wrist(sample, ui, actor, slot, endpoint, start_wrist)
		var actual := _proxy_bone_world(actor.skeleton, free_side, "Hand")
		var translation := start_hand.origin.distance_to(actual.origin)
		var orientation := rad_to_deg(_frame_angle(start_hand.basis, actual.basis))
		max_translation = maxf(max_translation, translation)
		max_orientation = maxf(max_orientation, orientation)
		sample.merge({"step": step, "hand_travel_m": translation, "hand_rotation_degrees": orientation,
			"pointer_local_px": [pointer.x, pointer.y], "elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0})
		if ui.preview_drag_refresh_pending:
			sample.failures.append("queued_refresh_timeout")
		_intent_append_sample(result, sample)
		if ui.preview_drag_refresh_pending:
			break
	var held_hand := _proxy_bone_world(actor.skeleton, free_side, "Hand")
	press.pressed = false
	press.position = pointer
	ui.call("_on_preview_gui_input", press)
	# Check both immediate retention and delayed modifier callbacks. No snapshot
	# restore occurs between the requests or after release.
	for delay: int in [1, 3, 8]:
		await _wait_frames(delay)
		var sample := _intent_sample(ui, actor, prop, free_side, slot, focus, frozen, main_frames, weapon_frame)
		_intent_check_mode_and_wrist(sample, ui, actor, slot, endpoint, start_wrist)
		var actual := _proxy_bone_world(actor.skeleton, free_side, "Hand")
		sample["release_wait_frames"] = delay
		sample["release_position_drift_m"] = held_hand.origin.distance_to(actual.origin)
		sample["release_orientation_drift_degrees"] = rad_to_deg(_frame_angle(held_hand.basis, actual.basis))
		if sample.release_position_drift_m > INTENT_POSITION_TOLERANCE or sample.release_orientation_drift_degrees > INTENT_ANGLE_TOLERANCE:
			sample.failures.append("release_changed_accepted_hand")
		_intent_append_sample(result, sample)
	result["maximum_hand_translation_m"] = max_translation
	result["maximum_hand_orientation_degrees"] = max_orientation
	if endpoint == "pommel" and max_translation < 0.0005:
		result.failures.append("translation_intent_did_not_move_hand")
	if endpoint == "tip" and max_orientation < 0.1:
		result.failures.append("orientation_intent_did_not_turn_hand")
	result.complete = result.failures.is_empty() and result.samples.size() == 7
	return result

func _intent_sample(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, prop: Node3D,
		free_side: String, slot: StringName, focus: StringName, frozen: Dictionary,
		main_frames: Dictionary, weapon_frame: Transform3D) -> Dictionary:
	var sample := _attachment_sample(ui, actor, prop, free_side, slot, focus, main_frames, weapon_frame)
	var max_position := 0.0
	var max_angle := 0.0
	for bone: int in frozen:
		var before: Transform3D = frozen[bone]
		var after: Transform3D = actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(bone)
		max_position = maxf(max_position, before.origin.distance_to(after.origin))
		max_angle = maxf(max_angle, rad_to_deg(_frame_angle(before.basis, after.basis)))
	sample["outside_selected_clavicle_position_m"] = max_position
	sample["outside_selected_clavicle_angle_degrees"] = max_angle
	if max_position > INTENT_POSITION_TOLERANCE or max_angle > INTENT_ANGLE_TOLERANCE:
		sample.failures.append("bones_outside_selected_arm_changed")
	return sample

func _intent_frozen_frames(skeleton: Skeleton3D, free_side: String) -> Dictionary:
	var selected := skeleton.find_bone("CC_Base_" + free_side + "_Clavicle")
	var frames: Dictionary = {}
	for bone: int in skeleton.get_bone_count():
		var ancestor := bone
		while ancestor >= 0 and ancestor != selected:
			ancestor = skeleton.get_bone_parent(ancestor)
		if selected < 0 or ancestor != selected:
			frames[bone] = skeleton.global_transform * skeleton.get_bone_global_pose(bone)
	return frames

func _intent_occupancy_guards(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig,
		prop: Node3D, main_side: String, free_side: String) -> Dictionary:
	var report := {"failures": [], "scope": "UI availability/setter rejection, not support acquisition."}
	var motion: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var primary := &"hand_right" if main_side == "R" else &"hand_left"
	var free_slot := &"hand_right" if free_side == "R" else &"hand_left"
	var frames := _intent_frozen_frames(actor.skeleton, "missing")
	var before_weapon := prop.global_transform
	var before_signature: String = ElbowPreparedPoseContract.node_pose_signature(motion)
	var rejected_primary := not ui.set_selected_motion_node_hand_proxy_segment(primary, Vector3.ONE, Vector3.ZERO, false)
	report["occupied_primary_rejected"] = rejected_primary
	if not rejected_primary or before_signature != ElbowPreparedPoseContract.node_pose_signature(motion):
		report.failures.append("occupied_primary_edit_accepted_or_changed_node")
	var previous_mode := motion.two_hand_state
	motion.two_hand_state = CombatAnimationMotionNode.TWO_HAND_STATE_TWO_HAND
	var occupied_signature: String = ElbowPreparedPoseContract.node_pose_signature(motion)
	var available: Array = ui.call("_resolve_available_hand_proxy_slots", motion)
	var rejected_support := not ui.set_selected_motion_node_hand_proxy_segment(free_slot, Vector3.ONE, Vector3.ZERO, false)
	report["occupied_support_rejected"] = rejected_support
	report["two_hand_available_slots"] = available
	if not rejected_support or not available.is_empty() or occupied_signature != ElbowPreparedPoseContract.node_pose_signature(motion):
		report.failures.append("occupied_support_edit_accepted_or_changed_node")
	# Restore the temporary occupancy declaration synchronously; never refresh,
	# acquire or record this test-only mode change into the isolated draft.
	motion.two_hand_state = previous_mode
	if before_signature != ElbowPreparedPoseContract.node_pose_signature(motion):
		report.failures.append("occupancy_probe_changed_authored_node")
	for bone: int in frames:
		var current: Transform3D = actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(bone)
		if not (frames[bone] as Transform3D).is_equal_approx(current):
			report.failures.append("occupancy_rejection_changed_bone")
			break
	if not before_weapon.is_equal_approx(prop.global_transform):
		report.failures.append("occupancy_rejection_changed_weapon")
	return report

func _intent_check_mode_and_wrist(sample: Dictionary, ui: CombatAnimationStationUI,
		actor: PlayerHumanoidRig, slot: StringName, endpoint: String, start_wrist: Dictionary) -> void:
	var allocation: Dictionary = _get_preview_root(ui).get_meta("independent_arm_edit_result", {})
	var actual_mode := String(allocation.get("hand_control_mode", ""))
	sample["expected_hand_control_mode"] = endpoint
	sample["hand_control_mode"] = actual_mode
	sample["legacy_mode_unreported"] = actual_mode.is_empty()
	# The same harness can collect the pre-change baseline: absence of the new
	# field is evidence of the old route, not a reason to skip later gestures.
	if not actual_mode.is_empty() and actual_mode != endpoint:
		sample.failures.append("wrong_hand_control_mode")
	if endpoint != "pommel":
		return
	var measured: Dictionary = actor.capture_wrist_motion_start_state(slot)
	if not start_wrist.get("valid", false) or not measured.get("valid", false):
		sample["wrist_hold_measurement_available"] = false
		if actual_mode == endpoint:
			sample.failures.append("wrist_hold_measurement_missing")
		return
	sample["wrist_hold_measurement_available"] = true
	var rho_error := rad_to_deg(absf(float(measured.state.rho) - float(start_wrist.state.rho)))
	var gamma_error := rad_to_deg(absf(float(measured.state.gamma) - float(start_wrist.state.gamma)))
	sample["held_forearm_rho_error_degrees"] = rho_error
	sample["held_wrist_gamma_error_degrees"] = gamma_error
	if actual_mode == endpoint and (rho_error > INTENT_ANGLE_TOLERANCE or gamma_error > INTENT_ANGLE_TOLERANCE):
		sample.failures.append("translation_changed_held_wrist_channels")

func _intent_append_sample(report: Dictionary, sample: Dictionary) -> void:
	report.samples.append(sample)
	for failure: String in sample.failures:
		report.failures.append(failure)
	samples_file.store_line(JSON.stringify(sample))
	samples_file.flush()
	sample_serial += 1
	print("EMPTY_HAND_INTENT ", JSON.stringify(sample))
