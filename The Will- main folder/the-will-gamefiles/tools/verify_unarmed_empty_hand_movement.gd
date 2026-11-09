extends "res://tools/verify_unarmed_empty_hand_fingers.gd"

## Fresh Unarmed libraries, both primary-hand selections. Exercises the primary
## generic Tip/Pommel controls and opposite-hand proxy controls through real
## marker press, queued pointer samples and release. No player-library load,
## grip acquisition, Save, F, or endpoint-capture certification.
## Native window events are disabled for this deterministic synthetic UI probe;
## direct calls still exercise the production pick, queue and release handlers.
## --out=<fresh workspace output directory>
## --first-case-only=true selects just right-primary generic Pommel for diagnosis.

const MOVE_POSITION_EPSILON := 0.00005
const MOVE_ANGLE_EPSILON_DEGREES := 0.025
var _movement_samples: FileAccess
var _movement_finger_rotations: Dictionary = {}
var _movement_first_case_only := false

func _run() -> void:
	_out = "C:/WORKSPACE/godot_runs/unarmed_empty_hand_movement_%d" % int(Time.get_unix_time_from_system())
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.substr(6).replace("\\", "/").trim_suffix("/")
		elif argument == "--first-case-only=true":
			_movement_first_case_only = true
	if not _out.to_lower().begins_with("c:/workspace/") or FileAccess.file_exists(_out.path_join("report.json")) \
			or DirAccess.make_dir_recursive_absolute(_out) != OK:
		push_error("A fresh writable workspace output directory is required.")
		quit(1)
		return
	_report = {"complete": false, "checks": [], "failures": [], "readiness": [], "cases": [],
		"scope": "Fresh Unarmed UI; primary R and L; generic and offhand proxy Tip/Pommel pointer routes plus primary numeric aliases; attached physical endpoints; independent arm ownership; no acquisition. No player-library load, Save/F or full motion certificate."}
	_report["first_case_only"] = _movement_first_case_only
	_report["expected_case_count"] = 1 if _movement_first_case_only else 8
	if _movement_first_case_only:
		_report.scope = "Diagnostic subset: fresh right-primary Unarmed; generic Pommel pointer sequence and release only, both authored index curls and no acquisition. All selected-case assertions retained. No numeric alias, other motion cases, Save/F, or player-library load."
	root.gui_disable_input = true
	_report["input_route"] = "Synthetic marker GUI press/release and explicit preview-local pointer samples; native root GUI and station input/unhandled-input callbacks disabled to prevent additional physical-window captured demands."
	_movement_samples = FileAccess.open(_out.path_join("samples.jsonl"), FileAccess.WRITE)
	if _movement_samples == null:
		_check(false, "sample_output_unavailable")
		_finish()
		return
	create_timer(240.0).timeout.connect(func() -> void:
		if not _finished:
			_check(false, "run_timeout")
			_finish())
	for primary: StringName in SLOTS:
		if _movement_first_case_only and primary != &"hand_right":
			continue
		if not await _open_movement_station(primary):
			_finish()
			return
		var other := &"hand_left" if primary == &"hand_right" else &"hand_right"
		for slot: StringName in [primary, other]:
			if _movement_first_case_only and slot != primary:
				continue
			var primary_route := slot == primary
			_aim_movement_camera(slot)
			for mode: String in ["pommel", "tip"]:
				if _movement_first_case_only and mode != "pommel":
					continue
				var result := await _drag_unarmed_control(primary, slot, primary_route, mode)
				_report.cases.append(result)
				_write_movement_report()
		if not _movement_first_case_only:
			await _check_primary_numeric_aliases(primary)
		_check_movement_finger_focus(String(primary) + ":after_motion")
		_check_movement_finger_retention(String(primary) + ":after_motion")
		_ui.queue_free()
		_player.queue_free()
		await _frames(4)
		_ui = null
		_player = null
		_actor = null
		_skeleton = null
	_finish()

func _open_movement_station(primary: StringName) -> bool:
	var library: PlayerForgeWipLibraryState = Library.new()
	library.save_file_path = _out.path_join("fresh_unarmed_%s.tres" % primary)
	_player = FakePlayer.new()
	_player.forge_wip_library_state = library
	root.add_child(_player)
	_ui = Station.instantiate() as CombatAnimationStationUI
	_ui.set_meta("verification_skip_persistence", true)
	root.add_child(_ui)
	await _frames(2)
	_ui.set_process_input(false)
	_ui.set_process_unhandled_input(false)
	_ui.open_for(_player, "Unarmed movement verification: " + String(primary))
	await _frames(2)
	var opened := _ui.select_unarmed_authoring(true, {"dominant_slot_id": primary, "use_two_hand": false})
	_check(opened, String(primary) + ":unarmed_open")
	if not opened:
		return false
	await _frames(2)
	var selected := _ui.select_skill_slot(&"skill_slot_2", true)
	_check(selected, String(primary) + ":skill_open")
	if not selected:
		return false
	await _frames(2)
	var reset := _ui.reset_active_draft_to_baseline()
	_check(reset, String(primary) + ":baseline_reset")
	if not reset:
		return false
	_ui.select_motion_node(1)
	var ready := await _wait_ready(String(primary) + ":baseline")
	_check(ready, String(primary) + ":baseline_ready")
	if not ready:
		return false
	_actor = _preview().get_node_or_null("PreviewActorPivot/PreviewActor") as PlayerHumanoidRig
	_check(_actor != null and _actor.skeleton != null, String(primary) + ":rig_available")
	if _actor == null or _actor.skeleton == null:
		return false
	_skeleton = _actor.skeleton
	var proxy := _preview().get_meta("preview_held_item", null) as Node3D
	_check(proxy != null and bool(proxy.get_meta("unarmed_hand_proxy", false)), String(primary) + ":virtual_proxy")
	_check(_ui.call("_resolve_active_motion_node_primary_slot_id") == primary, String(primary) + ":primary_slot_selected")
	_check(root.gui_disable_input and not _ui.is_processing_input() and not _ui.is_processing_unhandled_input(),
		String(primary) + ":native_input_isolated")
	_check_no_grip(String(primary) + ":baseline")
	_check_movement_finger_focus(String(primary) + ":before_motion")
	_movement_finger_rotations.clear()
	for slot: StringName in SLOTS:
		var curl := 30.0 if slot == &"hand_right" else 60.0
		_check(_ui.set_selected_motion_node_finger_curl(slot, &"index", curl),
			String(primary) + ":seed_index_curl:" + String(slot))
	var fingers_ready := await _wait_ready(String(primary) + ":finger_seed")
	_check(fingers_ready, String(primary) + ":finger_seed_ready")
	if not fingers_ready:
		return false
	for slot: StringName in SLOTS:
		for rule: Dictionary in FingerHinges.get_chain_rules(slot, &"index"):
			var bone := StringName(rule.bone)
			_movement_finger_rotations[bone] = _skeleton.get_bone_pose_rotation(_skeleton.find_bone(String(bone)))
	return true

func _drag_unarmed_control(primary: StringName, slot: StringName, primary_route: bool, mode: String) -> Dictionary:
	var case_name := "%s:%s:%s:%s" % [primary, slot, "generic" if primary_route else "proxy", mode]
	var result := {"name": case_name, "primary": primary, "edited_slot": slot, "mode": mode,
		"route": "generic" if primary_route else "hand_proxy", "complete": false, "samples": []}
	var focus := StringName(mode) if primary_route else (&"left_hand_proxy" if slot == &"hand_left" else &"right_hand_proxy")
	var target := StringName(mode) if primary_route else StringName(("left" if slot == &"hand_left" else "right") + "_hand_proxy_" + mode)
	var focus_ids: Array = _ui.call("_resolve_available_focus_ids")
	_check(focus_ids.has(focus), case_name + ":focus_available")
	if not focus_ids.has(focus):
		return result
	for step: int in 32:
		if _ui.session_state.current_focus == focus:
			break
		_ui.call("_cycle_focus")
	_check(_ui.session_state.current_focus == focus, case_name + ":focus_selected")
	await _frames(2)
	var physical := _physical_unarmed_segment(slot)
	if not physical.get("available", false):
		_check(false, case_name + ":physical_segment_available")
		return result
	var camera := _ui.call("_get_preview_camera") as Camera3D
	var expected: Vector3 = _trajectory().to_global(physical[mode + "_position_local"])
	var screen: Variant = _attached_marker_screen(camera, focus, target, expected)
	var pick_diagnostic := _movement_marker_diagnostic(camera, focus, target, expected, physical, slot)
	result["initial_marker"] = pick_diagnostic
	_check(screen is Vector2, case_name + ":attached_marker_visible", pick_diagnostic)
	if not screen is Vector2:
		return result
	var frozen := _outside_arm_frames(slot)
	var start_hand := _movement_hand_world(slot)
	var start_wrist: Dictionary = _actor.capture_wrist_motion_start_state(slot)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	_ui.call("_on_preview_gui_input", press)
	var picked := _ui.motion_node_editor.get_drag_target() == target
	_check(picked, case_name + ":marker_picked", {"target": target, "actual": _ui.motion_node_editor.get_drag_target()})
	if not picked:
		press.pressed = false
		_ui.call("_on_preview_gui_input", press)
		return result
	var max_translation := 0.0
	var max_orientation := 0.0
	var pointer: Vector2 = screen
	for step: int in 4:
		physical = _physical_unarmed_segment(slot)
		var tip_screen := camera.unproject_position(_trajectory().to_global(physical.tip_position_local))
		var pommel_screen := camera.unproject_position(_trajectory().to_global(physical.pommel_position_local))
		var direction := 1.0 if step < 2 else -1.0
		pointer = pommel_screen + Vector2(10.0, -4.0) * direction if mode == "pommel" \
			else pommel_screen + (tip_screen - pommel_screen).rotated(deg_to_rad(8.0 * direction))
		_ui.call("_begin_preview_authoring_lookup_scope")
		_ui.call("_handle_preview_drag", pointer)
		_ui.call("_end_preview_authoring_lookup_scope")
		var deadline := Time.get_ticks_msec() + 10000
		while _ui.preview_drag_refresh_pending and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(not _ui.preview_drag_refresh_pending, case_name + ":queued_refresh:%d" % step)
		await _frames(2)
		var sample := _sample_unarmed_motion(case_name + ":step_%d" % step, slot, primary_route, mode, focus, frozen, start_wrist)
		var hand := _movement_hand_world(slot)
		max_translation = maxf(max_translation, start_hand.origin.distance_to(hand.origin))
		max_orientation = maxf(max_orientation, _movement_basis_angle(start_hand.basis, hand.basis))
		result.samples.append(sample)
	var held_hand := _movement_hand_world(slot)
	result["before_release"] = _movement_release_diagnostic(slot)
	press.pressed = false
	press.position = pointer
	_ui.call("_on_preview_gui_input", press)
	result["immediate_after_release"] = _movement_release_diagnostic(slot)
	var immediate_hand := _movement_hand_world(slot)
	result["synchronous_release_position_change_m"] = held_hand.origin.distance_to(immediate_hand.origin)
	result["synchronous_release_orientation_change_degrees"] = _movement_basis_angle(held_hand.basis, immediate_hand.basis)
	for delay: int in [1, 3, 8]:
		await _frames(delay)
		var phase := case_name + ":release_%d" % delay
		var sample := _sample_unarmed_motion(phase, slot, primary_route, mode, focus, frozen, start_wrist)
		sample["release_diagnostic"] = _movement_release_diagnostic(slot)
		var hand := _movement_hand_world(slot)
		var distance := held_hand.origin.distance_to(hand.origin)
		var angle := _movement_basis_angle(held_hand.basis, hand.basis)
		_check(distance <= MOVE_POSITION_EPSILON and angle <= MOVE_ANGLE_EPSILON_DEGREES,
			phase + ":accepted_hand_retained", {"position_m": distance, "angle_degrees": angle})
		result.samples.append(sample)
	_check(max_translation >= 0.0005 if mode == "pommel" else max_orientation >= 0.1,
		case_name + ":requested_kind_of_motion_observed", {"maximum_translation_m": max_translation, "maximum_orientation_degrees": max_orientation})
	result["maximum_translation_m"] = max_translation
	result["maximum_orientation_degrees"] = max_orientation
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var shot: Image = _ui.preview_subviewport.get_texture().get_image()
		if shot != null and not shot.is_empty():
			result["image"] = case_name.replace(":", "_") + ".png"
			shot.save_png(_out.path_join(result.image))
	result.complete = result.samples.size() == 7
	return result

func _movement_release_diagnostic(slot: StringName) -> Dictionary:
	var effective := _ui.call("_get_effective_preview_motion_node") as CombatAnimationMotionNode
	var active := _motion()
	var fields: Dictionary = {}
	var active_fields: Dictionary = {}
	for field: StringName in [&"tip_position_local", &"tip_position_origin_id", &"pommel_position_local", &"pommel_position_origin_id",
			&"weapon_orientation_degrees", &"weapon_orientation_authored", &"weapon_roll_degrees"]:
		fields[field] = effective.get(field)
		active_fields[field] = active.get(field)
	var captured: RefCounted = _ui.marker_drag_input
	var proxy := _preview().get_meta("preview_held_item", null) as Node3D
	return {"hand_world": _movement_hand_world(slot), "proxy_world": proxy.global_transform,
		"effective_signature": PreparedPose.node_pose_signature(effective), "active_signature": PreparedPose.node_pose_signature(active),
		"effective_fields": fields, "active_fields": active_fields,
		"preview_pending": _ui.preview_drag_refresh_pending, "preview_target": _ui.preview_drag_target,
		"preview_slot": _ui.preview_drag_independent_arm_slot,
		"endpoint_pointer_latest": _ui.get("_endpoint_pointer_latest"),
		"captured_active": captured.get("active"), "captured_target": captured.get("target"),
		"captured_pointer": captured.get("pointer_position"), "captured_pending_relative": captured.get("_pending_relative"),
		"captured_sample_usec": captured.get("_sample_usec"),
		"retained_identity": (_preview().get_meta("retained_independent_arm_edit", {}) as Dictionary).duplicate(true),
		"retention_validation": (_preview().get_meta("independent_arm_retention_validation", {}) as Dictionary).duplicate(true),
		"last_edit_result": _movement_allocation_summary(_preview().get_meta("independent_arm_edit_result", {}))}

func _check_primary_numeric_aliases(primary: StringName) -> void:
	for mode: String in ["pommel", "tip"]:
		var name := String(primary) + ":numeric:" + mode
		var physical := _physical_unarmed_segment(primary)
		var frozen := _outside_arm_frames(primary)
		var wrist: Dictionary = _actor.capture_wrist_motion_start_state(primary)
		var before := _movement_hand_world(primary)
		var changed: bool
		if mode == "pommel":
			changed = _ui.set_selected_motion_node_pommel_position(physical.pommel_position_local + Vector3(0.006, 0.004, 0.0), false)
		else:
			var axis: Vector3 = physical.tip_position_local - physical.pommel_position_local
			var wanted: Vector3 = physical.pommel_position_local + axis.rotated(Vector3.UP, deg_to_rad(5.0))
			changed = _ui.set_selected_motion_node_tip_position(wanted, false)
		_check(changed, name + ":setter_changed")
		await _frames(3)
		_ui.session_state.current_focus = StringName(mode)
		_ui.preview_presenter.refresh_focus_visuals(_ui.preview_view_container, _ui.preview_subviewport,
			_ui.call("_get_active_draft"), _ui.get_selected_motion_node_index(), StringName(mode), _ui.call("_get_active_baked_profile"))
		_sample_unarmed_motion(name, primary, true, mode, StringName(mode), frozen, wrist)
		var after := _movement_hand_world(primary)
		var distance := before.origin.distance_to(after.origin)
		var angle := _movement_basis_angle(before.basis, after.basis)
		_check(distance >= 0.0001 if mode == "pommel" else angle >= 0.05,
			name + ":actual_motion", {"position_m": distance, "angle_degrees": angle})

func _sample_unarmed_motion(name: String, slot: StringName, primary_route: bool,
		mode: String, focus: StringName, frozen: Dictionary, start_wrist: Dictionary) -> Dictionary:
	var physical := _physical_unarmed_segment(slot)
	var stored: Dictionary = _ui.call("_resolve_motion_node_hand_proxy_segment", _ui.call("_get_effective_preview_motion_node"), slot)
	var sample := {"name": name, "slot": slot, "expected_mode": mode, "endpoint_errors_m": {}, "marker_errors_m": {}}
	var allocation: Dictionary = _preview().get_meta("independent_arm_edit_result", {})
	sample["hand_control_mode"] = allocation.get("hand_control_mode", "")
	sample["allocation_status"] = allocation.get("status", "")
	sample["allocation_reason"] = allocation.get("reason", "")
	_check(String(sample.hand_control_mode) == mode, name + ":correct_motion_intent", _movement_allocation_summary(allocation))
	var frame_warning := String(allocation.get("authoring_frame_warning", ""))
	sample["authoring_frame_warning"] = frame_warning
	_check(frame_warning.is_empty(), name + ":authoring_frame_encoded", {"warning": frame_warning})
	if primary_route:
		sample["primary_frame"] = _check_primary_authoring_frame(name)
	for endpoint: String in ["tip", "pommel"]:
		var expected: Vector3 = _trajectory().to_global(physical[endpoint + "_position_local"])
		var stored_world: Vector3 = _trajectory().to_global(stored[endpoint + "_position_local"])
		var error := expected.distance_to(stored_world)
		sample.endpoint_errors_m[endpoint] = error
		_check(physical[endpoint + "_position_origin_id"] == stored[endpoint + "_position_origin_id"]
			and error <= MOVE_POSITION_EPSILON, name + ":stored_" + endpoint + "_attached", {"error_m": error})
		if not primary_route or endpoint == mode:
			var target := StringName(endpoint) if primary_route else StringName(("left" if slot == &"hand_left" else "right") + "_hand_proxy_" + endpoint)
			var marker_error := _nearest_marker_error(focus, target, expected)
			sample.marker_errors_m[endpoint] = marker_error
			_check(marker_error <= MOVE_POSITION_EPSILON, name + ":visible_" + endpoint + "_attached", {"error_m": marker_error})
	var max_position := 0.0
	var max_angle := 0.0
	for bone: int in frozen:
		var before: Transform3D = frozen[bone]
		var after := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)
		max_position = maxf(max_position, before.origin.distance_to(after.origin))
		max_angle = maxf(max_angle, _movement_basis_angle(before.basis, after.basis))
	_check(max_position <= MOVE_POSITION_EPSILON and max_angle <= MOVE_ANGLE_EPSILON_DEGREES,
		name + ":outside_selected_arm_frozen", {"position_m": max_position, "angle_degrees": max_angle})
	sample["frozen_position_m"] = max_position
	sample["frozen_angle_degrees"] = max_angle
	if mode == "pommel":
		var wrist: Dictionary = _actor.capture_wrist_motion_start_state(slot)
		var valid: bool = start_wrist.get("valid", false) and wrist.get("valid", false)
		var rho := rad_to_deg(absf(float(wrist.state.rho) - float(start_wrist.state.rho))) if valid else INF
		var gamma := rad_to_deg(absf(float(wrist.state.gamma) - float(start_wrist.state.gamma))) if valid else INF
		_check(valid and rho <= MOVE_ANGLE_EPSILON_DEGREES and gamma <= MOVE_ANGLE_EPSILON_DEGREES,
			name + ":pommel_wrist_channels_held", {"rho_error_degrees": rho, "gamma_error_degrees": gamma})
		sample["rho_error_degrees"] = rho
		sample["gamma_error_degrees"] = gamma
	sample["grip"] = _check_no_grip(name)
	_check_movement_finger_retention(name)
	sample["footer"] = _ui.footer_status_label.text
	_movement_samples.store_line(JSON.stringify(sample))
	_movement_samples.flush()
	print("UNARMED_MOVEMENT ", JSON.stringify(sample))
	return sample

func _movement_allocation_summary(allocation: Dictionary) -> Dictionary:
	var summary: Dictionary = {}
	for field: StringName in [&"valid", &"status", &"reason", &"hand_control_mode", &"retained_previous_pose",
			&"edited_slot", &"origin_id", &"authoring_frame_warning", &"accepted_hand_world", &"task_scale"]:
		if allocation.has(field):
			summary[field] = allocation[field]
	return summary

func _check_primary_authoring_frame(name: String) -> Dictionary:
	var proxy := _preview().get_meta("preview_held_item", null) as Node3D
	var motion := _ui.call("_get_effective_preview_motion_node") as CombatAnimationMotionNode
	var encoded: Dictionary = _ui.preview_presenter.call("_encode_prepared_grip_display_state", proxy,
		_trajectory(), motion.weapon_roll_degrees)
	var report := {"encode_available": encoded.get("available", false), "encode_reason": encoded.get("reason", ""), "sources": {}}
	_check(bool(encoded.get("available", false)), name + ":actual_proxy_frame_encodable", report)
	if not encoded.get("available", false):
		return report
	var node_fields: Dictionary = {}
	for field: StringName in [&"tip_position_local", &"tip_position_origin_id", &"pommel_position_local", &"pommel_position_origin_id",
			&"weapon_orientation_degrees", &"weapon_orientation_authored", &"weapon_roll_degrees"]:
		node_fields[field] = motion.get(field)
	var published: Dictionary = _preview().get_meta("resolved_playback_state", {})
	var sources := {"current_node": node_fields, "published_resolved": published}
	var local_tip: Vector3 = proxy.get_meta("weapon_tip_local", Vector3.ZERO)
	var local_pommel: Vector3 = proxy.get_meta("weapon_pommel_local", Vector3.ZERO)
	for source_name: String in sources:
		var fields: Dictionary = sources[source_name]
		var errors := {"tip_error_m": INF, "pommel_error_m": INF, "orientation_field_error_degrees": INF,
			"roll_error_degrees": INF, "decoded_position_error_m": INF, "decoded_orientation_error_degrees": INF}
		var complete := true
		for field: StringName in [&"tip_position_local", &"tip_position_origin_id", &"pommel_position_local", &"pommel_position_origin_id",
				&"weapon_orientation_degrees", &"weapon_roll_degrees"]:
			complete = complete and fields.has(field)
		_check(complete, name + ":" + source_name + ":frame_fields_present")
		if not complete:
			report.sources[source_name] = errors
			continue
		for endpoint: String in ["tip", "pommel"]:
			errors[endpoint + "_error_m"] = _trajectory().to_global(fields[endpoint + "_position_local"]).distance_to(
				_trajectory().to_global(encoded[endpoint + "_position_local"]))
			_check(fields[endpoint + "_position_origin_id"] == encoded[endpoint + "_position_origin_id"],
				name + ":" + source_name + ":" + endpoint + "_frame_origin")
		var source_orientation: Vector3 = fields.weapon_orientation_degrees
		var encoded_orientation: Vector3 = encoded.weapon_orientation_degrees
		errors.orientation_field_error_degrees = _movement_basis_angle(Basis.from_euler(source_orientation * (PI / 180.0)),
			Basis.from_euler(encoded_orientation * (PI / 180.0)))
		errors.roll_error_degrees = absf(wrapf(float(fields.weapon_roll_degrees) - float(encoded.weapon_roll_degrees), -180.0, 180.0))
		var decoder := CombatAnimationMotionNode.new()
		decoder.weapon_roll_degrees = float(fields.weapon_roll_degrees)
		var decoded: Transform3D = _ui.preview_presenter.call("_solve_weapon_segment_transform", proxy, _trajectory(), decoder,
			local_tip, local_pommel, _trajectory().to_global(fields.tip_position_local), _trajectory().to_global(fields.pommel_position_local),
			source_orientation)
		errors.decoded_position_error_m = decoded.origin.distance_to(proxy.global_position)
		errors.decoded_orientation_error_degrees = _movement_basis_angle(decoded.basis, proxy.global_basis)
		_check(errors.tip_error_m <= MOVE_POSITION_EPSILON and errors.pommel_error_m <= MOVE_POSITION_EPSILON \
			and errors.orientation_field_error_degrees <= MOVE_ANGLE_EPSILON_DEGREES and errors.roll_error_degrees <= MOVE_ANGLE_EPSILON_DEGREES \
			and errors.decoded_position_error_m <= MOVE_POSITION_EPSILON and errors.decoded_orientation_error_degrees <= MOVE_ANGLE_EPSILON_DEGREES,
			name + ":" + source_name + ":matches_actual_proxy_frame", errors)
		if source_name == "current_node":
			_check(bool(fields.weapon_orientation_authored), name + ":current_node:up_reference_authored")
		report.sources[source_name] = errors
	return report

func _check_no_grip(name: String) -> Dictionary:
	var owner: Node = _actor.get_node_or_null("PreparedGripAcquisition")
	var requests: Dictionary = owner.get("_requests") if owner != null else {}
	var queue: Array = owner.get("_queue") if owner != null else []
	var busy: bool = bool(owner.get("_busy")) if owner != null else false
	var has_job: bool = owner.get("_job") != null if owner != null else false
	var bindings := 0
	for slot: StringName in SLOTS:
		if bool(_actor.get_planar_grip_pose_state(slot).get("has_grip_pose", false)):
			bindings += 1
	var result := {"request_count": requests.size(), "queue_count": queue.size(), "busy": busy, "job": has_job, "binding_count": bindings}
	_check(requests.is_empty() and queue.is_empty() and not busy and not has_job and bindings == 0,
		name + ":no_grip_request_or_binding", result)
	return result

func _check_movement_finger_focus(name: String) -> void:
	var ids: Array = _ui.call("_resolve_available_focus_ids")
	for slot: StringName in SLOTS:
		for focus: StringName in FingerControls.focus_ids(slot):
			_check(ids.has(focus), name + ":finger_focus:" + String(focus))

func _check_movement_finger_retention(name: String) -> void:
	for slot: StringName in SLOTS:
		var expected := 30.0 if slot == &"hand_right" else 60.0
		var curls: Dictionary = FingerControls.get_curls(_motion(), slot)
		_check(absf(float(curls.get(&"index", -1.0)) - expected) <= 0.0001,
			name + ":index_curl_value_retained:" + String(slot))
	var worst := 0.0
	for bone: StringName in _movement_finger_rotations:
		worst = maxf(worst, _angle(_movement_finger_rotations[bone],
			_skeleton.get_bone_pose_rotation(_skeleton.find_bone(String(bone)))))
	_check(_movement_finger_rotations.size() >= 6 and worst <= MOVE_ANGLE_EPSILON_DEGREES,
		name + ":index_curl_pose_retained", {"max_local_rotation_error_degrees": worst})

func _movement_basis_angle(first: Basis, second: Basis) -> float:
	return _angle(first.orthonormalized().get_rotation_quaternion(), second.orthonormalized().get_rotation_quaternion())

func _physical_unarmed_segment(slot: StringName) -> Dictionary:
	return _ui.preview_presenter.call("_resolve_hand_proxy_default_trajectory_segment_state", _actor, _trajectory(), slot)

func _movement_hand_world(slot: StringName) -> Transform3D:
	var name := "CC_Base_L_Hand" if slot == &"hand_left" else "CC_Base_R_Hand"
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone(name))

func _outside_arm_frames(slot: StringName) -> Dictionary:
	var selected := _skeleton.find_bone("CC_Base_L_Clavicle" if slot == &"hand_left" else "CC_Base_R_Clavicle")
	var frames: Dictionary = {}
	for bone: int in _skeleton.get_bone_count():
		var ancestor := bone
		while ancestor >= 0 and ancestor != selected:
			ancestor = _skeleton.get_bone_parent(ancestor)
		if selected < 0 or ancestor != selected:
			frames[bone] = _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)
	return frames

func _attached_marker_screen(camera: Camera3D, focus: StringName, target: StringName, expected: Vector3) -> Variant:
	for candidate: Dictionary in _ui.preview_presenter.call("_authoring_marker_candidates", _ui.preview_subviewport, focus):
		var marker := candidate.marker as MeshInstance3D
		if candidate.target == target and marker.global_position.distance_to(expected) <= MOVE_POSITION_EPSILON \
				and not camera.is_position_behind(marker.global_position):
			return camera.unproject_position(marker.global_position)
	return null

func _nearest_marker_error(focus: StringName, target: StringName, expected: Vector3) -> float:
	var error := INF
	for candidate: Dictionary in _ui.preview_presenter.call("_authoring_marker_candidates", _ui.preview_subviewport, focus):
		if candidate.target == target:
			error = minf(error, (candidate.marker as MeshInstance3D).global_position.distance_to(expected))
	return error

func _movement_marker_diagnostic(camera: Camera3D, focus: StringName, target: StringName,
		expected: Vector3, physical: Dictionary, slot: StringName) -> Dictionary:
	var result := {"focus": focus, "target": target, "expected_world": expected,
		"expected_camera_behind": camera.is_position_behind(expected), "candidates": [], "matching_count": 0,
		"physical_segment": physical, "camera_world": camera.global_transform,
		"active_focus": _ui.session_state.current_focus, "selected_node_index": _ui.get_selected_motion_node_index(),
		"stored_segment": _ui.call("_resolve_motion_node_hand_proxy_segment", _ui.call("_get_effective_preview_motion_node"), slot)}
	for candidate: Dictionary in _ui.preview_presenter.call("_authoring_marker_candidates", _ui.preview_subviewport, focus):
		var marker := candidate.marker as MeshInstance3D
		var matches: bool = candidate.target == target
		if matches:
			result.matching_count += 1
		result.candidates.append({"target": candidate.target, "matches_requested": matches,
			"name": marker.name, "world": marker.global_position, "local": marker.position,
			"visible": marker.is_visible_in_tree(), "camera_behind": camera.is_position_behind(marker.global_position),
			"error_from_physical_endpoint_m": marker.global_position.distance_to(expected)})
	var proxy := _preview().get_meta("preview_held_item", null) as Node3D
	if proxy != null:
		result["virtual_proxy_world"] = proxy.global_transform
		result["virtual_proxy_tip_local"] = proxy.get_meta("weapon_tip_local", null)
		result["virtual_proxy_pommel_local"] = proxy.get_meta("weapon_pommel_local", null)
		result["virtual_proxy_contact_local"] = proxy.get_meta("primary_grip_contact_local", null)
	return result

func _aim_movement_camera(slot: StringName) -> void:
	var camera := _ui.call("_get_preview_camera") as Camera3D
	var center := _movement_hand_world(slot).origin
	var sign_side := -1.0 if slot == &"hand_left" else 1.0
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.0
	camera.global_position = center + _actor.global_basis.orthonormalized() * Vector3(sign_side * 1.3, 0.4, 2.0)
	camera.look_at(center, _actor.global_basis.y.normalized())
	_ui.preview_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _preview() -> Node3D:
	return _ui.call("_get_preview_root") as Node3D

func _trajectory() -> Node3D:
	return _ui.call("_get_preview_trajectory_root") as Node3D

func _write_movement_report() -> void:
	var file := FileAccess.open(_out.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))

func _finish() -> void:
	if _finished:
		return
	_finished = true
	_report.complete = _report.failures.is_empty() and _report.cases.size() == int(_report.get("expected_case_count", 8))
	_write_movement_report()
	if _movement_samples != null:
		_movement_samples.close()
	print("UNARMED_EMPTY_HAND_MOVEMENT checks=%d failures=%d report=%s" % [_report.checks.size(), _report.failures.size(), _out])
	if is_instance_valid(_ui):
		_ui.queue_free()
	if is_instance_valid(_player):
		_player.queue_free()
	quit(0 if _report.complete else 1)
