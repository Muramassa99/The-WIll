extends "res://tools/diagnose_skill_crafter_body_motion.gd"

# One extension, one pull toward the shoulder, hold position, elbow gizmo only.
# --elevations=0 preserves the original forward pose; positive angles tilt up.
# Optional --lateral-factor=0.15 adds outward actor-X travel equal to 15% of the
# shoulderward pull length (right +X, left -X). Zero preserves the exact baseline.
# --elbow-steps accepts signed 15..60 degree pointer increments while held.
# Alternatively --elbow-seed selects 12 reproducible signed 15/25/35/45/55 steps.
var correction_case: Dictionary = {}
var correction_baseline: Dictionary = {}
var correction_step := 0
var correction_case_index := 0
var correction_angle_steps: Array[float] = []

func _run_thrust(ui: CombatAnimationStationUI, side: String, elevation: float) -> Dictionary:
	correction_case_index += 1
	var lateral_factor: float = float(options.get("lateral-factor", "0"))
	var case_id: String = "%s_pass_%d_push_pull_elbow" % [side, hand_pass_index]
	if elevation != 0.0 or lateral_factor != 0.0 or options.has("elbow-steps") or options.has("elbow-seed") or String(options.get("elevations", "0,25")).split(",").size() > 1:
		case_id += "_case_%d_elevation_%.3f_lateral_%.3f" % [correction_case_index, elevation, lateral_factor]
	correction_case = {"case": case_id, "complete": false, "samples": 0, "snapshots": [], "sequence": "extend; pull toward shoulder; hold; actual elbow control drag; no reextension", "warmup_only": hand_pass_index == 1 and String(options.get("warmup-first", "false")) == "true", "movement_variant": {"elevation_degrees": elevation, "lateral_factor": lateral_factor, "case_index": correction_case_index, "lateral_rule": "outward actor X (R positive, L negative), fraction of shoulderward pull length; negative factor moves inward", "steps_each_way": 8, "extension_distance_m": 1.0, "shoulderward_pull_fraction": 0.45}}
	correction_step = 0
	correction_angle_steps.clear()
	if options.has("elbow-seed") and options.has("elbow-steps"):
		correction_case["reason"] = "elbow_seed_and_elbow_steps_are_mutually_exclusive"
		return correction_case
	if options.has("elbow-steps"):
		for increment_text: String in String(options["elbow-steps"]).split(",", true):
			increment_text = increment_text.strip_edges()
			if not increment_text.is_valid_float() or absf(increment_text.to_float()) < 15.0 or absf(increment_text.to_float()) > 60.0:
				correction_case["reason"] = "elbow_steps_require_signed_increments_15_to_60_degrees"
				return correction_case
			correction_angle_steps.append(increment_text.to_float())
	elif options.has("elbow-seed"):
		var seed_text: String = String(options["elbow-seed"]).strip_edges()
		if not seed_text.is_valid_int():
			correction_case["reason"] = "elbow_seed_requires_integer"
			return correction_case
		var generator := RandomNumberGenerator.new()
		generator.seed = seed_text.to_int()
		for _step: int in range(12):
			var magnitude: float = float(15 + 10 * generator.randi_range(0, 4))
			correction_angle_steps.append(magnitude * (-1.0 if generator.randi_range(0, 1) == 0 else 1.0))
		correction_case["movement_variant"].merge({"elbow_seed": seed_text.to_int(), "elbow_random_magnitudes_degrees": [15, 25, 35, 45, 55], "elbow_seed_rule": "restart same seed per case for comparable R-L-R inputs; recorded list is replay authority across engine versions"})
	correction_case["expected_samples"] = 21 + (correction_angle_steps.size() if not correction_angle_steps.is_empty() else 12)
	correction_case["movement_variant"]["elbow_step_increments_degrees"] = correction_angle_steps.duplicate()
	correction_case["movement_variant"]["elbow_control_mode"] = "explicit_signed_pointer_steps" if not correction_angle_steps.is_empty() else "restore_initial_radial_in_12_steps"
	if options.has("elbow-seed"):
		correction_case["movement_variant"]["elbow_control_mode"] = "seeded_random_signed_pointer_steps"
	if not ui.reset_active_draft_to_baseline():
		return {"complete": false, "reason": "reset_failed"}
	await _wait_frames(4)
	_select_first_visible_skill_node(ui)
	await _wait_frames(3)
	var actor: Node3D = _get_preview_actor(ui)
	var sk: Skeleton3D = actor.get_node("JosieModel/Josie/Skeleton3D") as Skeleton3D
	var trajectory: Node3D = _get_trajectory_root(ui)
	# Elevation changes the setup; extension follows the accepted shoulder-hand
	# direction. No setup/reset occurs after extension begins.
	var setup_motion: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var forward_world: Vector3 = actor.global_basis.z.normalized()
	if elevation != 0.0:
		forward_world = (actor.global_basis * Vector3(0.0, sin(deg_to_rad(elevation)), cos(deg_to_rad(elevation)))).normalized()
	var forward_local: Vector3 = (trajectory.global_basis.inverse() * forward_world).normalized()
	var weapon_length: float = setup_motion.tip_position_local.distance_to(setup_motion.pommel_position_local)
	ui.set_selected_motion_node_tip_position(setup_motion.pommel_position_local + forward_local * weapon_length, false, false, false, true, false)
	await _wait_frames(3)
	var setup_shoulder: Vector3 = _get_bone_world_position(sk, "CC_Base_%s_Upperarm" % side)
	var setup_grip_world: Vector3 = setup_shoulder + forward_world * 0.30 - actor.global_basis.y.normalized() * 0.12
	correction_case["movement_variant"].merge({"requested_setup_axis_world": _vec(forward_world), "requested_setup_axis_local": _vec(forward_local), "setup_shoulder_world": _vec(setup_shoulder), "requested_setup_grip_world": _vec(setup_grip_world)})
	_attempt_grip_translation_with_ui(ui, setup_grip_world)
	await _wait_frames(3)
	# Selection/reset/setup can obsolete the original asynchronous neutral-pose
	# job. Start acquisition only once the final starting pose is established.
	var setup_started_msec: int = Time.get_ticks_msec()
	ui.preview_presenter.reacquire_grip(ui.preview_subviewport)
	var setup_ready: Dictionary = await _await_settled_setup(ui, side, setup_started_msec)
	correction_case["initial_applied_grip"] = setup_ready
	correction_case["setup_applied_grip"] = setup_ready
	if not setup_ready.get("ready", false):
		correction_case["reason"] = "forward_setup_grip_not_ready"
		return correction_case
	correction_baseline = _capture_bones(sk, side, {})
	var initial_radial_local: Vector3 = actor.global_basis.inverse() * _elbow_radial(sk, side)
	correction_case["initial_elbow_radial_actor_local"] = _vec(initial_radial_local)
	await _record_stage(ui, sk, side, "initial")
	var active: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var display: CombatAnimationMotionNode = ui.call("_build_authoring_motion_node_baseline", active) as CombatAnimationMotionNode
	ui.call("_begin_preview_drag_override", display)
	ui.motion_node_editor.begin_drag(&"pommel", Vector2.ZERO, display)
	var shoulder: Vector3 = _get_bone_world_position(sk, "CC_Base_%s_Upperarm" % side)
	var hand: Vector3 = _get_bone_world_position(sk, "CC_Base_%s_Hand" % side)
	var extension_axis: Vector3 = (hand - shoulder).normalized()
	var extension_delta: Vector3 = trajectory.global_basis.inverse() * extension_axis * 1.0
	correction_case["movement_variant"].merge({"accepted_setup_weapon_axis_world": _vec((trajectory.global_basis * (display.tip_position_local - display.pommel_position_local)).normalized()), "extension_axis_world": _vec(extension_axis), "extension_delta_local": _vec(extension_delta), "extension_delta_world": _vec(trajectory.global_basis * extension_delta), "extension_start_pommel_local": _vec(display.pommel_position_local)})
	await _move_pommel(ui, sk, side, display.pommel_position_local, extension_delta, "extend")
	await _record_stage(ui, sk, side, "maximum_extension")
	# Begin the pull at accepted position, never at the distant rejected request.
	var accepted: CombatAnimationMotionNode = ui.call("_get_effective_preview_motion_node") as CombatAnimationMotionNode
	shoulder = _get_bone_world_position(sk, "CC_Base_%s_Upperarm" % side)
	hand = _get_bone_world_position(sk, "CC_Base_%s_Hand" % side)
	var pull_delta: Vector3 = trajectory.global_basis.inverse() * (shoulder - hand) * 0.45
	var lateral_world: Vector3 = Vector3.ZERO
	if lateral_factor != 0.0:
		var outward_world: Vector3 = actor.global_basis.x.normalized() * (-1.0 if side == "L" else 1.0)
		lateral_world = outward_world * shoulder.distance_to(hand) * 0.45 * lateral_factor
		pull_delta += trajectory.global_basis.inverse() * lateral_world
	correction_case["movement_variant"].merge({"pull_shoulder_world": _vec(shoulder), "pull_hand_world": _vec(hand), "shoulderward_pull_delta_world": _vec((shoulder - hand) * 0.45), "lateral_pull_delta_world": _vec(lateral_world), "pull_delta_local": _vec(pull_delta), "pull_delta_world": _vec(trajectory.global_basis * pull_delta), "pull_start_pommel_local": _vec(accepted.pommel_position_local), "requested_pull_end_pommel_local": _vec(accepted.pommel_position_local + pull_delta)})
	await _move_pommel(ui, sk, side, accepted.pommel_position_local, pull_delta, "pull")
	await _record_stage(ui, sk, side, "retracted_before_release")
	ui.motion_node_editor.end_drag()
	ui.call("_finalize_preview_drag")
	await _wait_frames(2)
	await _record_stage(ui, sk, side, "retracted_held")
	await _correct_elbow(ui, sk, side, initial_radial_local)
	correction_case["complete"] = correction_step == int(correction_case["expected_samples"]) and not correction_case.has("correction_failure")
	return correction_case

func _await_settled_setup(ui: CombatAnimationStationUI, side: String, started: int) -> Dictionary:
	var state: Dictionary = await _await_applied_grip(ui, side)
	var first_ready_msec: int = Time.get_ticks_msec() - started
	var minimum_msec: int = int(float(options.get("settle-seconds", "0")) * 1000.0)
	if not state.get("ready", false) or minimum_msec <= 0:
		return state
	var stable_since: int = 0
	var last_signature := ""
	var trace: Array[Dictionary] = []
	var owner: Node = _get_preview_actor(ui).get_node("PreparedGripAcquisition")
	while Time.get_ticks_msec() - started < 90000:
		state = _grip_readiness(ui, side)
		var binding: Dictionary = state.get("binding", {})
		var details: Dictionary = state.get("status_details", {})
		var idle: bool = not bool(owner.get("_busy")) and owner.get("_job") == null and (owner.get("_queue") as Array).is_empty() and not ui.preview_drag_refresh_pending
		var signature: String = JSON.stringify([state.get("ready"), state.get("status"), details.get("serial"), binding.get("relationship_key"), binding.get("source_pose_id"), binding.get("weapon_instance_id"), idle])
		var now: int = Time.get_ticks_msec()
		if signature != last_signature:
			trace.append({"elapsed_ms": now - started, "ready": state.get("ready", false), "status": state.get("status"), "reason": state.get("reason"), "serial": details.get("serial"), "idle": idle})
			last_signature = signature
			stable_since = now
		if not state.get("ready", false) or not idle:
			stable_since = now
		if now - started >= minimum_msec and now - stable_since >= 1000 and state.get("ready", false) and idle:
			state["first_reported_ready_ms"] = first_ready_msec
			state["setup_observed_ms"] = now - started
			state["open_to_settled_ms"] = now - hand_open_started_msec
			state["continuous_stable_ms"] = now - stable_since
			state["settle_trace"] = trace
			print("ELBOW_SEQUENCE settled %s pass=%d first_ready_ms=%d observed_ms=%d" % [side, hand_pass_index, first_ready_msec, now - started])
			return state
		if String(state.get("status", "")) in ["unresolved", "unavailable", "cancelled"]:
			state["settle_failure"] = true
			state["settle_trace"] = trace
			return state
		await _wait_frames(3)
	state["ready"] = false
	state["settle_timeout"] = true
	state["settle_trace"] = trace
	return state

func _move_pommel(ui: CombatAnimationStationUI, sk: Skeleton3D, side: String, start: Vector3, delta: Vector3, phase: String) -> void:
	var motion: CombatAnimationMotionNode = ui.call("_get_effective_preview_motion_node") as CombatAnimationMotionNode
	var origin: StringName = motion.pommel_position_origin_id
	for step: int in range(1, 9):
		var target: Vector3 = start + delta * float(step) / 8.0
		var before: Dictionary = _capture_bones(sk, side, correction_baseline)
		ui.call("_queue_pommel_drag_authority_target", target, origin)
		var authority: Dictionary = ui.call("_resolve_pending_pommel_drag_authority", true)
		var after: Dictionary = _capture_bones(sk, side, correction_baseline)
		ui.preview_drag_refresh_pending = false
		ui.preview_drag_first_pending_msec = 0
		ui.call("_refresh_preview_scene")
		await _wait_frames(2)
		await _record_stage(ui, sk, side, phase, {"requested_pommel_local": _vec(target), "authority": authority, "bones_before_authority": before, "bones_after_authority": after})

func _correct_elbow(ui: CombatAnimationStationUI, sk: Skeleton3D, side: String, initial_radial_local: Vector3) -> void:
	var actor: Node3D = _get_preview_actor(ui)
	var slot: StringName = &"hand_right" if side == "R" else &"hand_left"
	var wanted_focus: StringName = &"right_arm_roll" if side == "R" else &"left_arm_roll"
	# Use the actual Space-selection path. Selection-only refresh does not build
	# the elbow gizmo and can leave another hand's stale state after a hand swap.
	for focus_step: int in range(8):
		ui.call("_cycle_focus")
		if ui.session_state.current_focus == wanted_focus:
			break
	var preview_root: Node3D = ui.call("_get_preview_root") as Node3D
	var states: Dictionary = preview_root.get_meta("upperarm_roll_gizmo_state", {})
	var state: Dictionary = states.get(slot, {})
	if state.is_empty():
		correction_case["correction_failure"] = "elbow_gizmo_missing"
		return
	var center: Vector3 = state["center_global"]
	var axis: Vector3 = (state["axis_global"] as Vector3).normalized()
	var initial_normal: Vector3 = state["initial_normal_global"]
	var desired: Vector3 = actor.global_basis * initial_radial_local
	desired = (desired - axis * desired.dot(axis)).normalized()
	var angle: float = atan2(axis.dot(initial_normal.cross(desired)), initial_normal.dot(desired))
	var requested_total_degrees: float = rad_to_deg(angle)
	if not correction_angle_steps.is_empty():
		requested_total_degrees = 0.0
		for increment: float in correction_angle_steps:
			requested_total_degrees += increment
		desired = Basis(axis, deg_to_rad(requested_total_degrees)) * initial_normal
	var reference: Vector3 = actor.call("_resolve_authoring_upperarm_roll_reference_world", slot, axis) as Vector3
	correction_case["correction_start"] = {"gizmo": state, "desired_radial_world": _vec(desired), "pointer_arc_degrees": requested_total_degrees, "requested_step_increments_degrees": correction_angle_steps.duplicate(), "actual_radial_angle_from_rig_reference_degrees": rad_to_deg(atan2(axis.dot(reference.cross(initial_normal)), reference.dot(initial_normal))), "target_rule": "explicit signed pointer increments while held; not an anatomical certificate" if not correction_angle_steps.is_empty() else "restore initial applied-grip elbow side; not a universal anatomical certificate"}
	var active: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var display: CombatAnimationMotionNode = ui.call("_build_authoring_motion_node_baseline", active) as CombatAnimationMotionNode
	ui.call("_begin_preview_drag_override", display)
	var camera: Camera3D = ui.call("_get_preview_camera") as Camera3D
	# Calibrate the real press ray in the same view used for pointer movement.
	# Frame captures below restore a frontal view, so each step restores this one.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.55
	camera.global_position = center + axis * 2.0
	var press_up: Vector3 = actor.global_basis.y.normalized()
	if absf(press_up.dot(axis)) > 0.95:
		press_up = actor.global_basis.x.normalized()
	camera.look_at(center, press_up)
	var press: Vector2 = camera.unproject_position(center + initial_normal * float(state["radius_meters"]) * 0.999)
	ui.motion_node_editor.begin_upperarm_roll_drag(state["drag_target"], state, camera, press)
	var fixed_pommel: Vector3 = display.pommel_position_local
	var fixed_tip: Vector3 = display.tip_position_local
	var step_count: int = correction_angle_steps.size() if not correction_angle_steps.is_empty() else 12
	var cumulative_degrees := 0.0
	for step: int in range(1, step_count + 1):
		# Look down the control axis so the full gizmo ring is accessible to the
		# production pointer ray/sphere resolver, including the opposite side.
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 1.55
		camera.global_position = center + axis * 2.0
		var up: Vector3 = actor.global_basis.y.normalized()
		if absf(up.dot(axis)) > 0.95:
			up = actor.global_basis.x.normalized()
		camera.look_at(center, up)
		var normal: Vector3 = Basis(axis, angle * float(step) / 12.0) * initial_normal
		var step_degrees: float = rad_to_deg(angle) / 12.0
		if not correction_angle_steps.is_empty():
			step_degrees = correction_angle_steps[step - 1]
			cumulative_degrees += step_degrees
			normal = Basis(axis, deg_to_rad(cumulative_degrees)) * initial_normal
		else:
			cumulative_degrees = rad_to_deg(angle) * float(step) / 12.0
		var point: Vector3 = center + normal * float(state["radius_meters"]) * 0.999
		var pointer: Vector2 = camera.unproject_position(point)
		var resolved: Variant = ui.motion_node_editor.resolve_upperarm_roll_drag(camera, pointer)
		ui.call("_handle_preview_drag", pointer)
		ui.call("_flush_pending_preview_drag_refresh")
		# The live UI throttles drag refreshes by elapsed time, so two frames
		# alone can still measure the previous input. Wait for its normal update;
		# do not bypass the throttle or force an alternate solve for the fixture.
		var refresh_started_msec := Time.get_ticks_msec()
		while ui.preview_drag_refresh_pending and Time.get_ticks_msec() - refresh_started_msec < 2000:
			await process_frame
		if ui.preview_drag_refresh_pending:
			correction_case["correction_failure"] = "elbow_preview_refresh_timeout"
			ui.motion_node_editor.end_drag()
			ui.call("_finalize_preview_drag")
			return
		await _wait_frames(2)
		if DisplayServer.get_name().to_lower() != "headless":
			await RenderingServer.frame_post_draw
		var effective: CombatAnimationMotionNode = ui.call("_get_effective_preview_motion_node") as CombatAnimationMotionNode
		await _record_stage(ui, sk, side, "elbow_correction", {"correction_fraction": float(step) / float(step_count), "requested_step_degrees": step_degrees, "requested_cumulative_arc_degrees": cumulative_degrees, "desired_final_normal_world": _vec(desired), "pointer_resolved_roll_degrees": resolved, "requested_control_normal_world": _vec(normal), "elbow_radial_world": _vec(_elbow_radial(sk, side)), "authored_pommel_drift_m": effective.pommel_position_local.distance_to(fixed_pommel), "authored_tip_drift_m": effective.tip_position_local.distance_to(fixed_tip)})
	ui.motion_node_editor.end_drag()
	ui.call("_finalize_preview_drag")
	await _wait_frames(2)
	var achieved_normal: Vector3 = _elbow_radial(sk, side)
	correction_case["correction_end"] = {"desired_final_normal_world": _vec(desired), "achieved_radial_world": _vec(achieved_normal), "requested_total_arc_degrees": requested_total_degrees, "normal_error_degrees": rad_to_deg(achieved_normal.angle_to(desired))}
	await _record_stage(ui, sk, side, "elbow_corrected_released", correction_case["correction_end"])

func _record_stage(ui: CombatAnimationStationUI, sk: Skeleton3D, side: String, phase: String, extra: Dictionary = {}) -> void:
	var actor: Node3D = _get_preview_actor(ui)
	var row: Dictionary = _capture_motion(ui, sk, side, correction_baseline)
	var motion: CombatAnimationMotionNode = ui.call("_get_effective_preview_motion_node") as CombatAnimationMotionNode
	row.merge({"case": correction_case["case"], "step": correction_step, "phase": phase, "sample_serial": sample_serial, "elbow_radial_world": _vec(_elbow_radial(sk, side)), "authored_upperarm_roll_degrees": motion.right_upperarm_roll_degrees if side == "R" else motion.left_upperarm_roll_degrees})
	row.merge(extra)
	var name: String = "%s_%03d_%s.png" % [correction_case["case"], correction_step, phase]
	if await _capture_frame(ui, actor, side, output_dir.path_join(name)):
		row["image"] = name
		correction_case["snapshots"].append(name)
	samples_file.store_line(JSON.stringify(row))
	samples_file.flush()
	correction_step += 1
	sample_serial += 1
	correction_case["samples"] += 1
	print("ELBOW_SEQUENCE %s step=%d %s angle=%.2f ready=%s" % [side, correction_step - 1, phase, row["elbow_inner_angle_degrees"], str(row["prepared_grip_readiness"]["ready"])])

func _elbow_radial(sk: Skeleton3D, side: String) -> Vector3:
	var shoulder: Vector3 = _get_bone_world_position(sk, "CC_Base_%s_Upperarm" % side)
	var elbow: Vector3 = _get_bone_world_position(sk, "CC_Base_%s_Forearm" % side)
	var hand: Vector3 = _get_bone_world_position(sk, "CC_Base_%s_Hand" % side)
	var axis: Vector3 = (hand - shoulder).normalized()
	var radial: Vector3 = elbow - shoulder
	return (radial - axis * radial.dot(axis)).normalized()
