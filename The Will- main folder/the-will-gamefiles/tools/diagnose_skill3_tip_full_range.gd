extends "res://tools/diagnose_skill3_tip_direction_stall.gd"

## Large actual Tip sweeps on the isolated copy of the saved Skill3. Inherited
## right -> left -> right sequencing keeps one continuous captured drag. No
## Reset/reacquisition between stages, no Save, no production limit overrides.
## --phase=write --hands=R --weapon=Broken_Balde_v1 --slot=skill_slot_3
## --out=<fresh-directory> --cap=900 --step-px=10 --max-events=120
## --stall-events=6 --stall-px=0.03 --warmup-events=6
## --overpush-events=12 adds bounded extra inputs after a sustained stop.
## --separate-holds=true also runs the inherited restored/fresh-drag comparison.
## Existing camera arguments are forwarded unchanged to the parent harness.
const FinalWrist = preload("res://core/resolvers/combat_wrist_motion_resolver.gd")
const FinalShoulder = preload("res://core/resolvers/combat_shoulder_motion_resolver.gd")
const FinalHinge = preload("res://core/resolvers/combat_arm_hinge_frame_resolver.gd")
const TEST_MOUSE_DEVICE := 734091

## Last root child receives _input before earlier scene children. Suppress only
## untagged mouse event delivery inside this test window; never block the OS.
class TestMouseIsolation extends Node:
	var accepted_device: int = 0
	var ignored_motion: int = 0
	var ignored_buttons: int = 0
	var delivered_motion: int = 0
	var delivered_buttons: int = 0

	func _input(event: InputEvent) -> void:
		if not event is InputEventMouseMotion and not event is InputEventMouseButton: return
		if event.device == accepted_device:
			if event is InputEventMouseMotion: delivered_motion += 1
			else: delivered_buttons += 1
			return
		if event is InputEventMouseMotion: ignored_motion += 1
		else: ignored_buttons += 1
		get_viewport().set_input_as_handled()

	func statistics() -> Dictionary:
		return {"enabled": true, "test_device": accepted_device,
			"ignored_physical_motion_events": ignored_motion, "ignored_physical_button_events": ignored_buttons,
			"delivered_tagged_motion_events": delivered_motion, "delivered_tagged_button_events": delivered_buttons,
			"scope": "Engine mouse-event propagation only; keyboard and operating system remain usable."}

var test_mouse_isolation: TestMouseIsolation
var final_skin: Dictionary = {}
var final_skin_sequence := 0
var final_skin_skeleton: Skeleton3D
var final_skin_records: Array[Dictionary] = []
var final_skin_bindings: Dictionary = {}

func _reopen_write(ui: CombatAnimationStationUI, side: String) -> void:
	_install_mouse_isolation()
	if not options.has("cap"): options["cap"] = "900"
	if not options.has("step-px"): options["step-px"] = "10"
	if not options.has("separate-holds"): options["separate-holds"] = "false"
	await super._reopen_write(ui, side)
	allocation_report["scope"] = "Read-only source Skill3, isolated saved node3, large right-left-right Tip sweeps with one continuous captured drag. No Reset, Save, F or reacquisition between sweeps. Captures final Skeleton3D.skeleton_updated poses separately from input poses."
	allocation_report["final_skin_signal_count"] = final_skin_sequence
	allocation_report["input_isolation"] = _mouse_isolation_statistics()
	allocation_report["range_limits"] = {"max_events_per_stage": _maximum_events(),
		"step_px": float(options.get("step-px", "10")),
		"stall_events": _stall_events(), "stall_px": _stall_pixels(),
		"warmup_events": _warmup_events(), "overpush_events": _overpush_events(),
		"speed_cap_px_s": circle_ui.marker_drag_input.speed_pixels_per_second}
	_check_allocation(final_skin_sequence > 0, "final_skeleton_signal_observed", {"signals": final_skin_sequence})
	if is_instance_valid(final_skin_skeleton) and final_skin_skeleton.skeleton_updated.is_connected(_capture_final_skin):
		final_skin_skeleton.skeleton_updated.disconnect(_capture_final_skin)

func _snapshot(label: String) -> void:
	if is_instance_valid(test_mouse_isolation): root.move_child(test_mouse_isolation, root.get_child_count() - 1)
	if label == "node3_ready" and final_skin_skeleton == null:
		_install_final_skin_capture()
	super._snapshot(label)

func _install_mouse_isolation() -> void:
	if is_instance_valid(test_mouse_isolation): return
	test_mouse_isolation = TestMouseIsolation.new()
	test_mouse_isolation.name = "DiagnosticMouseIsolation"
	test_mouse_isolation.accepted_device = TEST_MOUSE_DEVICE
	test_mouse_isolation.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(test_mouse_isolation)
	test_mouse_isolation.set_process_input(true)

func _mouse_isolation_statistics() -> Dictionary:
	return test_mouse_isolation.statistics() if is_instance_valid(test_mouse_isolation) else {"enabled": false}

func _engine_button(local_position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.device = TEST_MOUSE_DEVICE
	event.position = circle_ui.preview_view_container.get_global_transform_with_canvas() * local_position
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _linear_input(label: String, distance_px: float, _seconds: float) -> Dictionary:
	# Never enter the parent's untagged time-based injector.
	return await _fixed_step_input(label, signf(distance_px))

func _install_final_skin_capture() -> void:
	if circle_actor == null or circle_actor.skeleton == null: return
	final_skin_skeleton = circle_actor.skeleton
	for side: String in ["R", "L"]:
		var slot := &"hand_right" if side == "R" else &"hand_left"
		var prefix := "CC_Base_" + side + "_"
		var indices := {}
		for part: String in ["Clavicle", "Upperarm", "Forearm", "Hand"]:
			indices[part] = final_skin_skeleton.find_bone(prefix + part)
		var shoulder_calibration: Dictionary = circle_actor.capture_shoulder_constraint_calibration(slot)
		var wrist_calibration: Dictionary = circle_actor.capture_wrist_constraint_calibration(slot)
		var hinge: Dictionary = FinalHinge.calibration(final_skin_skeleton.get_bone_rest(indices.Forearm), final_skin_skeleton.get_bone_rest(indices.Hand))
		final_skin_records.append({"side": side, "slot": slot, "indices": indices,
			"chest": final_skin_skeleton.find_bone(String(shoulder_calibration.get("chest_bone_name", "CC_Base_Spine02"))),
			"shoulder_calibration": shoulder_calibration, "wrist_calibration": wrist_calibration,
			"hinge": hinge, "wrist_profile": circle_actor.wrist_motion_profile.as_dictionary(),
			"shoulder_profile": circle_actor.shoulder_motion_profile.as_dictionary(),
			"full_flexion": circle_actor.authoring_elbow_full_flexion_radians()})
	final_skin_skeleton.skeleton_updated.connect(_capture_final_skin)

## Called only by the final-pose signal. Never force an update, install a pose,
## invoke the live solver or acquire grip from this observer.
func _capture_final_skin() -> void:
	if not is_instance_valid(final_skin_skeleton) or not is_instance_valid(circle_weapon): return
	final_skin_sequence += 1
	var skeleton_world: Transform3D = final_skin_skeleton.global_transform
	var weapon_world: Transform3D = circle_weapon.global_transform
	var packet := {"signal": "Skeleton3D.skeleton_updated", "sequence": final_skin_sequence,
		"process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames(),
		"monotonic_usec": Time.get_ticks_usec(), "skeleton_world": _transform(skeleton_world),
		"weapon_world": _transform(weapon_world), "arms": {}}
	var wrist_cache: Dictionary = circle_actor.get("_wrist_motion_states")
	var shoulder_cache: Dictionary = circle_actor.get("_shoulder_motion_states")
	for record: Dictionary in final_skin_records:
		var poses := {}
		var encoded := {}
		for part: String in record.indices:
			var index: int = record.indices[part]
			var pose: Transform3D = final_skin_skeleton.get_bone_global_pose(index)
			poses[part] = pose
			encoded[part] = {"world": _transform(skeleton_world * pose),
				"skeleton": _transform(pose), "local": _transform(final_skin_skeleton.get_bone_pose(index))}
		var upper: Transform3D = poses.Upperarm
		var forearm: Transform3D = poses.Forearm
		var hand: Transform3D = poses.Hand
		var shaft: Vector3 = (forearm.origin - upper.origin).normalized()
		var distal: Vector3 = (hand.origin - forearm.origin).normalized()
		var flexion := NAN
		if bool(record.hinge.get("valid", false)):
			var axis: Vector3 = upper.basis.orthonormalized() * (record.hinge.frame_in_upperarm as Basis).x
			flexion = atan2(axis.dot(shaft.cross(distal)), shaft.dot(distal))
		var wrist: Dictionary = FinalWrist.measure_state(forearm, hand, record.wrist_calibration,
			record.wrist_profile, wrist_cache.get(record.slot, {}), flexion, float(record.full_flexion))
		var shoulder: Dictionary = FinalShoulder.measure(final_skin_skeleton.get_bone_global_pose(record.chest),
			upper, forearm, record.shoulder_calibration, record.shoulder_profile, shoulder_cache.get(record.slot, {}))
		var hand_in_weapon: Transform3D = weapon_world.affine_inverse() * skeleton_world * hand
		if not final_skin_bindings.has(record.slot): final_skin_bindings[record.slot] = hand_in_weapon
		var initial_binding: Transform3D = final_skin_bindings[record.slot]
		packet.arms[record.side] = {"bones": encoded, "elbow_flexion_degrees": rad_to_deg(flexion),
			"wrist": _json(wrist), "shoulder": _json(shoulder),
			"cached_wrist_state": _json(wrist_cache.get(record.slot, {})),
			"cached_shoulder_state": _json(shoulder_cache.get(record.slot, {})),
			"hand_in_weapon": _transform(hand_in_weapon),
			"attachment_change_from_first_final_signal": {
				"position_m": hand_in_weapon.origin.distance_to(initial_binding.origin),
				"angle_degrees": rad_to_deg(_final_basis_angle(initial_binding.basis, hand_in_weapon.basis))}}
	final_skin = packet

func _final_basis_angle(a: Basis, b: Basis) -> float:
	var delta: Quaternion = (a.orthonormalized().get_rotation_quaternion().inverse() * b.orthonormalized().get_rotation_quaternion()).normalized()
	return 2.0 * atan2(Vector3(delta.x, delta.y, delta.z).length(), absf(delta.w))

func _sample(label: String, extra: Dictionary = {}) -> Dictionary:
	var extended := extra.duplicate()
	extended["final_skin"] = final_skin.duplicate(true)
	extended["input_isolation"] = _mouse_isolation_statistics()
	extended["final_skin_age_usec"] = Time.get_ticks_usec() - int(final_skin.get("monotonic_usec", Time.get_ticks_usec()))
	if circle_actor != null:
		extended["accepted_shoulder_cache"] = _json(circle_actor.get("_shoulder_motion_states"))
	return super._sample(label, extended)

func _maximum_events() -> int:
	return clampi(int(options.get("max-events", "120")), 1, 200)

func _overpush_events() -> int:
	return clampi(int(options.get("overpush-events", "12")), 12, 24)

func _stall_events() -> int:
	return clampi(int(options.get("stall-events", "6")), 2, 20)

func _warmup_events() -> int:
	return clampi(int(options.get("warmup-events", "6")), 0, 20)

func _stall_pixels() -> float:
	return clampf(float(options.get("stall-px", "0.03")), 0.001, 1.0)

func _tip_screen_now() -> Variant:
	var position: Vector3 = circle_weapon.to_global(circle_weapon.get_meta("weapon_tip_local", Vector3.ZERO))
	return null if circle_camera.is_position_behind(position) else circle_camera.unproject_position(position)

func _fixed_step_input(label: String, direction: float) -> Dictionary:
	var step_px := clampf(float(options.get("step-px", "10")), 0.1, 50.0)
	var maximum := _maximum_events()
	var started := Time.get_ticks_usec()
	var delivered := 0
	var stalls := 0
	var warmup_stalls := 0
	var total_travel := 0.0
	var largest_gap_ms := 0.0
	var reason := "event_cap"
	var first_stall_step := -1
	var overpush_delivered := 0
	var overpush_regained_progress := false
	var steps: Array[Dictionary] = []
	print("TIP_RANGE_STAGE_BEGIN ", label, " direction=", direction, " step_px=", step_px, " max_events=", maximum)
	_sample(label + "_start")
	for step_index: int in maximum + _overpush_events():
		if first_stall_step < 0 and step_index >= maximum: break
		await process_frame
		await RenderingServer.frame_post_draw
		var before_tip: Variant = _tip_screen_now()
		var before_sequence := final_skin_sequence
		var step_started := Time.get_ticks_usec()
		var details := {"step_index": step_index + 1, "maximum_events": maximum,
			"warmup": step_index < _warmup_events(),
			"requested_relative_px": [step_px * direction, 0.0],
			"requested_total_px": (step_index + 1) * step_px * direction}
		_sample(label + "_before_input", details)
		var event := InputEventMouseMotion.new()
		event.device = TEST_MOUSE_DEVICE
		event.screen_relative = Vector2(step_px * direction, 0.0)
		event.relative = event.screen_relative
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		delivered += 1
		_sample(label + "_after_input", details)
		var drain: Dictionary = await _await_direction_input_drained(label + "_step_%03d" % (step_index + 1))
		# The drain samples input poses. This later point sees the displayed
		# weapon and the latest actual post-modifier skeleton signal together.
		await RenderingServer.frame_post_draw
		var after_tip: Variant = _tip_screen_now()
		var travel := INF
		if before_tip is Vector2 and after_tip is Vector2:
			travel = (before_tip as Vector2).distance_to(after_tip)
			total_travel += travel
		var elapsed_ms := float(Time.get_ticks_usec() - step_started) / 1000.0
		largest_gap_ms = maxf(largest_gap_ms, elapsed_ms)
		var small := is_finite(travel) and travel < _stall_pixels()
		if first_stall_step >= 0:
			overpush_delivered += 1
			overpush_regained_progress = overpush_regained_progress or not small
		if step_index < _warmup_events():
			warmup_stalls += 1 if small else 0
			stalls = 0
		else:
			stalls = stalls + 1 if small else 0
		var step := {"step_index": step_index + 1, "drain": drain,
			"tip_before": _vec(before_tip) if before_tip is Vector2 else null,
			"tip_after": _vec(after_tip) if after_tip is Vector2 else null,
			"actual_tip_travel_px": travel if is_finite(travel) else null,
			"consecutive_stalls": stalls, "warmup": step_index < _warmup_events(),
			"overpush": first_stall_step >= 0, "overpush_delivered": overpush_delivered,
			"elapsed_ms": elapsed_ms, "final_signal_before": before_sequence,
			"final_signal_after": final_skin_sequence,
			"post_draw_weapon_world": _transform(circle_weapon.global_transform)}
		steps.append(step)
		_sample(label + "_visible_after_input", step)
		if delivered % 20 == 0:
			print("TIP_RANGE_PROGRESS ", label, " events=", delivered, " travel_px=", total_travel,
				" stalls=", stalls, " overpush=", overpush_delivered)
		if not bool(drain.drained):
			reason = "input_drain_timeout"
			break
		if not after_tip is Vector2:
			reason = "tip_behind_camera"
			break
		if first_stall_step < 0 and stalls >= _stall_events():
			first_stall_step = step_index + 1
			print("TIP_RANGE_SUSTAINED_STOP ", label, " event=", first_stall_step, " continuing_overpush=", _overpush_events())
		if first_stall_step >= 0 and overpush_delivered >= _overpush_events():
			reason = "bounded_overpush_after_sustained_stop"
			break
	print("TIP_RANGE_STAGE_END ", label, " events=", delivered, " stop=", reason,
		" travel_px=", total_travel, " overpush_regained_progress=", overpush_regained_progress)
	_check_allocation(delivered > 0, label + "_range_inputs_delivered", {"delivered": delivered, "stop_reason": reason})
	return {"label": label, "mode": "bounded_range_sweep", "step_px": step_px * direction,
		"maximum_events": maximum, "delivered_samples": delivered,
		"requested_distance_px": delivered * step_px * direction,
		"actual_tip_travel_px": total_travel, "warmup_stall_events": warmup_stalls,
		"first_sustained_stop_event": first_stall_step, "overpush_delivered": overpush_delivered,
		"overpush_regained_progress": overpush_regained_progress,
		"final_consecutive_stalls": stalls, "stop_reason": reason,
		"largest_step_ms": largest_gap_ms, "steps": steps,
		"elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0}
