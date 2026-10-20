extends "res://tools/diagnose_skill_crafter_elbow_correction.gd"

# Actual saved-weapon Roll baseline. Inherits isolated saves, R-L-R ordering and
# post-setup readiness; replaces the thrust/elbow exercise with UI Roll requests.
# Example: --weapon=Broken_Balde_v1 --slot=skill_slot_2 --hands=R,L,R
# --reuse-station=true --warmup-first=true --settle-seconds=10 --elevations=0
# --roll-limit=120 --roll-step=30 --out=<fresh directory>
# Opt-in --raw-orbit=true observes the same Hand-only resolver over 360 degrees
# without the production UI gate. No motion data is authored by that branch.
# --use-live-limits=true instead exercises the production interval returned by
# the presenter, including original-pose preservation when fields refresh.
# --check-preview-bounds-sync=true adds an isolated stale-display recovery check.
const RollProbeResolver = preload("res://core/resolvers/combat_weapon_roll_resolver.gd")
var roll_case: Dictionary = {}
var roll_baseline: Dictionary = {}
var roll_bone_baseline: Dictionary = {}
var roll_wrist_capture: Dictionary = {}
var roll_baseline_degrees := 0.0
var roll_sample_index := 0
var roll_raw_sample_state: Dictionary = {}
var roll_raw_front_camera: Dictionary = {}
var roll_live_initial_limits: Dictionary = {}

func _run_thrust(ui: CombatAnimationStationUI, side: String, elevation: float) -> Dictionary:
	correction_case_index += 1
	roll_sample_index = 0
	roll_raw_sample_state.clear()
	roll_raw_front_camera.clear()
	roll_live_initial_limits.clear()
	roll_case = {"case": "%s_pass_%d_case_%d_roll_elevation_%.1f" % [side, hand_pass_index, correction_case_index, elevation], "complete": false, "samples": 0, "snapshots": [], "pointer_failures": [], "warmup_only": hand_pass_index == 1 and String(options.get("warmup-first", "false")) == "true", "scope": "requested/authored/rendered Roll comparison; complete means capture finished, not anatomical acceptance"}
	var limit: float = float(options.get("roll-limit", "120"))
	var step_size: float = float(options.get("roll-step", "30"))
	if not is_finite(limit) or not is_finite(step_size) or limit <= 0.0 or limit > 360.0 or step_size <= 0.0 or step_size > 90.0:
		roll_case["reason"] = "invalid_roll_limit_or_step"
		return roll_case
	if not options.has("settle-seconds"):
		options["settle-seconds"] = "10"
	if not ui.reset_active_draft_to_baseline():
		roll_case["reason"] = "reset_failed"
		return roll_case
	await _wait_frames(4)
	_select_first_visible_skill_node(ui)
	await _wait_frames(3)
	var actor: PlayerHumanoidRig = _get_preview_actor(ui) as PlayerHumanoidRig
	var sk: Skeleton3D = actor.skeleton
	var trajectory: Node3D = _get_trajectory_root(ui)
	var motion: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var direction_world: Vector3 = (actor.global_basis * Vector3(0.0, sin(deg_to_rad(elevation)), cos(deg_to_rad(elevation)))).normalized()
	var direction_local: Vector3 = (trajectory.global_basis.inverse() * direction_world).normalized()
	var length: float = motion.tip_position_local.distance_to(motion.pommel_position_local)
	ui.set_selected_motion_node_tip_position(motion.pommel_position_local + direction_local * length, false, false, false, true, false)
	await _wait_frames(3)
	var shoulder: Vector3 = _get_bone_world_position(sk, "CC_Base_%s_Upperarm" % side)
	var setup_grip: Vector3 = shoulder + direction_world * 0.30 - actor.global_basis.y.normalized() * 0.12
	_attempt_grip_translation_with_ui(ui, setup_grip)
	await _wait_frames(3)
	var started: int = Time.get_ticks_msec()
	ui.preview_presenter.reacquire_grip(ui.preview_subviewport)
	var ready: Dictionary = await _await_settled_setup(ui, side, started)
	roll_case.merge({"setup_applied_grip": ready, "requested_setup_axis_world": _vec(direction_world), "requested_setup_grip_world": _vec(setup_grip), "elevation_degrees": elevation, "requested_sweep_limit_degrees": limit, "requested_step_degrees": step_size, "ui_roll_min": ui.weapon_roll_spin_box.min_value, "ui_roll_max": ui.weapon_roll_spin_box.max_value})
	if not ready.get("ready", false):
		roll_case["reason"] = "setup_grip_not_ready"
		return roll_case
	if String(options.get("use-live-limits", "false")) == "true":
		if String(options.get("raw-orbit", "false")) == "true":
			roll_case["reason"] = "live_limits_and_raw_orbit_are_separate_modes"
			return roll_case
		roll_baseline = _roll_snapshot(ui, side)
		roll_baseline_degrees = (ui.call("_get_active_motion_node") as CombatAnimationMotionNode).weapon_roll_degrees
		roll_wrist_capture = actor.capture_authoring_wrist_origin(&"hand_left" if side == "L" else &"hand_right")
		roll_bone_baseline = _capture_bones(sk, side, {})
		return await _run_live_roll_limits(ui, side, step_size)
	ui.set_selected_motion_node_weapon_roll(0.0, false)
	await _wait_frames(2)
	roll_baseline = _roll_snapshot(ui, side)
	roll_baseline_degrees = (ui.call("_get_active_motion_node") as CombatAnimationMotionNode).weapon_roll_degrees
	roll_wrist_capture = actor.capture_authoring_wrist_origin(&"hand_left" if side == "L" else &"hand_right")
	roll_bone_baseline = _capture_bones(sk, side, {})
	if String(options.get("raw-orbit", "false")) == "true":
		return await _run_raw_orbit(ui, actor, side, step_size)
	await _record_roll(ui, side, "neutral", 0.0, false, true)
	var previous := 0.0
	# Traverse the whole interval in both directions, then finish at neutral.
	for destination: float in [limit, -limit, limit, 0.0]:
		var count: int = maxi(1, ceili(absf(destination - previous) / step_size))
		for index: int in range(1, count + 1):
			var requested: float = lerpf(previous, destination, float(index) / float(count))
			var changed: bool = ui.set_selected_motion_node_weapon_roll(requested, false)
			await _wait_frames(2)
			await _record_roll(ui, side, "numeric_sweep", requested, changed, is_equal_approx(absf(requested), limit) or is_zero_approx(requested))
		previous = destination
	for requested: float in [limit + 30.0, 0.0, -limit - 30.0, 0.0]:
		var changed: bool = ui.set_selected_motion_node_weapon_roll(requested, false)
		await _wait_frames(2)
		await _record_roll(ui, side, "numeric_boundary_probe", requested, changed, not is_zero_approx(requested))
	for sign_direction: float in [1.0, -1.0]:
		await _exercise_roll_pointer(ui, side, sign_direction)
	ui.call("_refresh_preview_scene")
	await _wait_frames(3)
	await _record_roll(ui, side, "idle_refresh", 0.0, false, true)
	roll_case["complete"] = true
	return roll_case

func _run_live_roll_limits(ui: CombatAnimationStationUI, side: String, step_size: float) -> Dictionary:
	var motion: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var original_motion: Dictionary = _roll_motion_values(motion)
	roll_live_initial_limits = _query_roll_limits(ui, motion)
	roll_case.merge({"scope": "production live interval, actual setters and pointer gestures; original settled pose captured before any Roll request", "live_limits_initial": roll_live_initial_limits.duplicate(true), "live_failures": [], "original_roll_degrees": roll_baseline_degrees})
	if not roll_live_initial_limits.get("available", false):
		roll_case["reason"] = "live_roll_limits_unavailable"
		return roll_case
	await _record_roll(ui, side, "live_original_before_roll", roll_baseline_degrees, false, true)
	ui.call("_refresh_editor_fields")
	await _wait_frames(2)
	var after_refresh: Dictionary = _roll_snapshot(ui, side)
	var changed_bones: Array[int] = []
	for index: int in range((roll_baseline["local_bones"] as Array).size()):
		if not (roll_baseline["local_bones"][index] as Transform3D).is_equal_approx(after_refresh["local_bones"][index]):
			changed_bones.append(index)
	var refresh_preserved: bool = changed_bones.is_empty() and (after_refresh["hand"] as Transform3D).is_equal_approx(roll_baseline["hand"]) and (after_refresh["weapon"] as Transform3D).is_equal_approx(roll_baseline["weapon"]) and _roll_motion_values(motion) == original_motion
	roll_case["original_fields_refresh"] = {"preserved": refresh_preserved, "changed_bone_indices": changed_bones, "motion_values_unchanged": _roll_motion_values(motion) == original_motion, "before_hand": _roll_transform(roll_baseline["hand"]), "after_hand": _roll_transform(after_refresh["hand"]), "before_weapon": _roll_transform(roll_baseline["weapon"]), "after_weapon": _roll_transform(after_refresh["weapon"])}
	if not refresh_preserved:
		roll_case["live_failures"].append({"phase": "live_fields_refresh", "check": "original_pose_and_motion_preserved"})
	await _record_roll(ui, side, "live_fields_refresh", roll_baseline_degrees, false, true)
	var minimum: float = roll_live_initial_limits["minimum_degrees"]
	var maximum: float = roll_live_initial_limits["maximum_degrees"]
	var center: float = roll_live_initial_limits["center_degrees"]
	var changed: bool = ui.set_selected_motion_node_weapon_roll(center, false)
	await _wait_frames(2)
	await _record_roll(ui, side, "live_center", center, changed, true)
	# Full preview refresh preserves the retained Roll transaction only after an
	# actual Roll apply. Before that it can legitimately rerun the ordinary IK.
	# The earlier fields-only check still protects the untouched original pose.
	if String(options.get("check-preview-bounds-sync", "false")) == "true":
		await _check_preview_roll_bounds_sync(ui, side, motion)
	var previous: float = center
	for destination: float in [maximum, minimum, maximum, center]:
		var count: int = maxi(1, ceili(absf(destination - previous) / step_size))
		for index: int in range(1, count + 1):
			var requested: float = lerpf(previous, destination, float(index) / float(count))
			changed = ui.set_selected_motion_node_weapon_roll(requested, false)
			await _wait_frames(2)
			await _record_roll(ui, side, "live_numeric_sweep", requested, changed, index == count)
		previous = destination
	for requested: float in [maximum + 30.0, center, minimum - 30.0, center]:
		changed = ui.set_selected_motion_node_weapon_roll(requested, false)
		await _wait_frames(2)
		await _record_roll(ui, side, "live_boundary_probe", requested, changed, true)
	for sign_direction: float in [1.0, -1.0]:
		await _exercise_roll_pointer(ui, side, sign_direction, center, "live_")
	var finish: float = roll_baseline_degrees if roll_baseline_degrees >= minimum and roll_baseline_degrees <= maximum else center
	changed = ui.set_selected_motion_node_weapon_roll(finish, false)
	await _wait_frames(2)
	ui.call("_refresh_editor_fields")
	ui.call("_refresh_preview_scene")
	await _wait_frames(3)
	await _record_roll(ui, side, "live_final_refresh", finish, changed, true)
	roll_case["final_requested_degrees"] = finish
	roll_case["live_checks_passed"] = (roll_case["live_failures"] as Array).is_empty() and (roll_case["pointer_failures"] as Array).is_empty()
	roll_case["complete"] = true
	return roll_case

func _check_preview_roll_bounds_sync(ui: CombatAnimationStationUI, side: String, motion: CombatAnimationMotionNode) -> void:
	var before: Dictionary = _roll_snapshot(ui, side)
	var motion_before: Dictionary = _roll_motion_values(motion)
	var status_before: String = ui.footer_status_label.text
	var expected: Dictionary = _query_roll_limits(ui, motion)
	var stale_minimum: float = float(expected["minimum_degrees"]) - 37.0
	var stale_maximum: float = float(expected["maximum_degrees"]) + 41.0
	var blocked: bool = ui.weapon_roll_spin_box.is_blocking_signals()
	ui.weapon_roll_spin_box.set_block_signals(true)
	ui.weapon_roll_spin_box.min_value = stale_minimum
	ui.weapon_roll_spin_box.max_value = stale_maximum
	ui.weapon_roll_spin_box.set_block_signals(blocked)
	# The deliberately stale field state is never recorded as a production row.
	# Only recovery through the normal preview refresh is evaluated below.
	ui.call("_refresh_preview_scene")
	await _wait_frames(3)
	var after: Dictionary = _roll_snapshot(ui, side)
	var current: Dictionary = _query_roll_limits(ui, motion)
	var changed_bones: Array[int] = []
	for index: int in range((before["local_bones"] as Array).size()):
		if not (before["local_bones"][index] as Transform3D).is_equal_approx(after["local_bones"][index]):
			changed_bones.append(index)
	var checks: Dictionary = {"limits_available": current["available"], "minimum_refreshed": absf(ui.weapon_roll_spin_box.min_value - float(current["minimum_degrees"])) < 0.01, "maximum_refreshed": absf(ui.weapon_roll_spin_box.max_value - float(current["maximum_degrees"])) < 0.01, "derived_limits_unchanged": absf(float(current["minimum_degrees"]) - float(expected["minimum_degrees"])) < 0.01 and absf(float(current["maximum_degrees"]) - float(expected["maximum_degrees"])) < 0.01, "bones_unchanged": changed_bones.is_empty(), "hand_unchanged": (after["hand"] as Transform3D).is_equal_approx(before["hand"]), "weapon_unchanged": (after["weapon"] as Transform3D).is_equal_approx(before["weapon"]), "motion_unchanged": _roll_motion_values(motion) == motion_before, "status_unchanged": ui.footer_status_label.text == status_before, "display_value_preserved": absf(ui.weapon_roll_spin_box.value - motion.weapon_roll_degrees) <= 0.50001}
	var passed := true
	for check: String in checks:
		if not bool(checks[check]):
			passed = false
			roll_case["live_failures"].append({"phase": "live_preview_bounds_sync", "check": check})
	roll_case["post_preview_display_sync_test"] = {"passed": passed, "scope": "only displayed min/max were widened with signals blocked; normal preview refresh must restore derived bounds without authoring", "deliberate_stale_fields": {"minimum": stale_minimum, "maximum": stale_maximum}, "expected_limits_before": expected, "current_limits_after": current, "actual_fields_after": {"minimum": ui.weapon_roll_spin_box.min_value, "maximum": ui.weapon_roll_spin_box.max_value, "value": ui.weapon_roll_spin_box.value}, "status_before": status_before, "status_after": ui.footer_status_label.text, "changed_bone_indices": changed_bones, "checks": checks}

func _query_roll_limits(ui: CombatAnimationStationUI, motion: CombatAnimationMotionNode) -> Dictionary:
	if not ui.preview_presenter.has_method("get_weapon_roll_limits"):
		return {"available": false, "reason": "presenter_limit_api_missing"}
	var limits: Dictionary = ui.preview_presenter.call("get_weapon_roll_limits", ui.preview_subviewport, motion)
	return {"available": limits.get("available", false), "reason": String(limits.get("reason", "")), "minimum_degrees": limits.get("minimum_degrees", 0.0), "maximum_degrees": limits.get("maximum_degrees", 0.0), "center_degrees": limits.get("center_degrees", 0.0)}

func _run_raw_orbit(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, side: String, step_size: float) -> Dictionary:
	var sk: Skeleton3D = actor.skeleton
	var slot: StringName = &"hand_left" if side == "L" else &"hand_right"
	var weapon: Node3D = _get_preview_held_item(ui)
	var motion: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var original_motion: Dictionary = _roll_motion_values(motion)
	var base_hand: Transform3D = roll_baseline["hand"]
	var base_weapon: Transform3D = roll_baseline["weapon"]
	var axis: Vector3 = ((roll_baseline["tip"] as Vector3) - base_hand.origin).normalized()
	var neutral: Basis = actor.call("_resolve_neutral_hand_world_basis", roll_baseline["hand_index"]) as Basis
	var neutral_delta: Quaternion = (neutral.get_rotation_quaternion() * base_hand.basis.orthonormalized().get_rotation_quaternion().inverse()).normalized()
	var closest_reference: float = wrapf(rad_to_deg(2.0 * atan2(Vector3(neutral_delta.x, neutral_delta.y, neutral_delta.z).dot(axis), neutral_delta.w)), -180.0, 180.0)
	var skin_reference: Dictionary = _raw_distal_helper_reference(sk, side, int(roll_baseline["hand_index"]), base_hand, axis)
	_prepare_raw_front_camera(actor, side, base_hand)
	roll_case.merge({"diagnostic_gate_bypass": true, "scope": "direct Hand-only resolver orbit; production UI limits and saved motion untouched; not an anatomical acceptance test", "raw_orbit_axis_world": _vec(axis), "raw_baseline_roll_degrees": roll_baseline_degrees, "raw_closest_reference_delta_degrees": closest_reference, "raw_reference_rule": "closest quaternion to current-parent-times-Hand-rest neutral on the existing fixed Wrist-to-Tip orbit; not a new neutral definition", "raw_front_camera": {"offset_world": _vec(roll_raw_front_camera["offset"]), "up_world": _vec(roll_raw_front_camera["up"]), "rule": "fixed acquired-baseline palm-plane face, signed toward actor front; same camera for every angle"}, "raw_writer_failures": []})
	roll_case["raw_parent_neutral_world_quaternion"] = _roll_quat(neutral.get_rotation_quaternion())
	roll_case["raw_distal_helper_reference"] = skin_reference
	# Settled acquisition has finished. Suspend only preview pose writers while
	# observing direct resolver output; rendering and explicit bone updates remain.
	var ui_processing: bool = ui.is_processing()
	var actor_processing: bool = actor.is_processing()
	var modifier_mode: int = sk.modifier_callback_mode_process
	var animation_states: Array[Dictionary] = []
	for mixer: AnimationMixer in [actor.animation_player, actor.runtime_locomotion_animation_tree]:
		if mixer != null:
			animation_states.append({"node": mixer, "active": mixer.active})
			mixer.active = false
	ui.set_process(false)
	actor.set_process(false)
	sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	var requests: Array[Dictionary] = []
	var count: int = maxi(1, ceili(360.0 / step_size))
	for index: int in range(count + 1):
		requests.append({"degrees": roll_baseline_degrees + 360.0 * float(index) / float(count), "phase": "raw_orbit_neutral" if index == 0 else "raw_orbit_sweep"})
	for offset: float in [0.0, -120.0, 120.0]:
		requests.append({"degrees": roll_baseline_degrees + closest_reference + offset, "phase": "raw_reference_center" if is_zero_approx(offset) else ("raw_reference_minus120" if offset < 0.0 else "raw_reference_plus120")})
	if skin_reference.get("available", false):
		for offset: float in [0.0, -120.0, 120.0]:
			requests.append({"degrees": roll_baseline_degrees + float(skin_reference["closest_delta_degrees"]) + offset, "phase": "raw_skin_reference_center" if is_zero_approx(offset) else ("raw_skin_reference_minus120" if offset < 0.0 else "raw_skin_reference_plus120")})
	requests.append({"degrees": roll_baseline_degrees, "phase": "raw_orbit_restore"})
	roll_case["expected_samples"] = requests.size()
	for request: Dictionary in requests:
		var requested: float = request["degrees"]
		var resolved: Dictionary = RollProbeResolver.resolve(roll_wrist_capture, base_weapon, weapon.get_meta("weapon_tip_local"), weapon.get_meta("weapon_tip_origin_id"), roll_baseline_degrees, requested)
		var accepted := false
		if bool(resolved.get("available", false)):
			accepted = actor.apply_authoring_wrist_roll_pose(slot, resolved["hand_transform_world"])
			if accepted:
				weapon.global_transform = resolved["weapon_transform_world"]
		roll_raw_sample_state = {"diagnostic_gate_bypass": true, "resolver_available": resolved.get("available", false), "resolver_reason": String(resolved.get("reason", "")), "writer_accepted": accepted, "requested_unwrapped_delta_degrees": requested - roll_baseline_degrees, "motion_values_unchanged": _roll_motion_values(motion) == original_motion}
		if accepted:
			roll_raw_sample_state["expected_hand"] = resolved["hand_transform_world"]
			roll_raw_sample_state["expected_weapon"] = resolved["weapon_transform_world"]
		else:
			roll_case["raw_writer_failures"].append({"degrees": requested, "phase": request["phase"], "reason": resolved.get("reason", "wrist_writer_rejected")})
		await _wait_frames(2)
		await _record_roll(ui, side, request["phase"], requested, null, true)
	# Restore the exact captured local Hand rotation and weapon before resuming
	# normal preview updates; no motion scalar/endpoints were changed by this path.
	sk.set_bone_pose_rotation(int(roll_baseline["hand_index"]), (roll_baseline["local_bones"][int(roll_baseline["hand_index"])] as Transform3D).basis.get_rotation_quaternion())
	sk.force_update_all_bone_transforms()
	weapon.global_transform = base_weapon
	roll_case["raw_motion_values_unchanged"] = _roll_motion_values(motion) == original_motion
	sk.modifier_callback_mode_process = modifier_mode
	for saved_mixer: Dictionary in animation_states:
		(saved_mixer["node"] as AnimationMixer).active = bool(saved_mixer["active"])
	actor.set_process(actor_processing)
	ui.set_process(ui_processing)
	roll_raw_sample_state.clear()
	ui.call("_refresh_preview_scene")
	await _wait_frames(3)
	var restored: Dictionary = _roll_snapshot(ui, side)
	roll_case["raw_after_restore_refresh"] = {"hand": _roll_transform(restored["hand"]), "weapon": _roll_transform(restored["weapon"]), "motion_values_unchanged": _roll_motion_values(motion) == original_motion}
	roll_case["complete"] = true
	return roll_case

func _raw_distal_helper_reference(sk: Skeleton3D, side: String, hand_index: int, base_hand: Transform3D, axis: Vector3) -> Dictionary:
	var forearm_index: int = sk.find_bone("CC_Base_%s_Forearm" % side)
	var twist1: int = sk.find_bone("CC_Base_%s_ForearmTwist01" % side)
	var twist2: int = sk.find_bone("CC_Base_%s_ForearmTwist02" % side)
	if forearm_index < 0 or twist1 < 0 or twist2 < 0:
		return {"available": false, "reason": "missing_distal_helper_bone"}
	if sk.get_bone_parent(twist1) != forearm_index or sk.get_bone_parent(twist2) != twist1 or sk.get_bone_parent(hand_index) != forearm_index:
		return {"available": false, "reason": "unexpected_distal_helper_or_hand_parent_chain"}
	var distal_world: Basis = sk.global_basis * sk.get_bone_global_pose(twist2).basis
	var helper_rest: Basis = sk.get_bone_rest(twist1).basis * sk.get_bone_rest(twist2).basis
	var skin_neutral: Basis = (distal_world * helper_rest.inverse() * sk.get_bone_rest(hand_index).basis).orthonormalized()
	var delta: Quaternion = (skin_neutral.get_rotation_quaternion() * base_hand.basis.orthonormalized().get_rotation_quaternion().inverse()).normalized()
	var closest: float = wrapf(rad_to_deg(2.0 * atan2(Vector3(delta.x, delta.y, delta.z).dot(axis), delta.w)), -180.0, 180.0)
	return {"available": true, "rule": "Twist02 world basis * inverse(Twist01 local rest basis * Twist02 local rest basis) * Hand local rest basis; candidate visible distal-skin reference, not anatomy certification", "twist01_name": sk.get_bone_name(twist1), "twist02_name": sk.get_bone_name(twist2), "twist02_world_quaternion": _roll_quat(distal_world.orthonormalized().get_rotation_quaternion()), "helper_rest_chain_quaternion": _roll_quat(helper_rest.orthonormalized().get_rotation_quaternion()), "neutral_world_quaternion": _roll_quat(skin_neutral.get_rotation_quaternion()), "closest_delta_degrees": closest}

func _roll_motion_values(motion: CombatAnimationMotionNode) -> Dictionary:
	var values: Dictionary = {}
	for property: Dictionary in motion.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_STORAGE and String(property["name"]) != "script":
			values[property["name"]] = motion.get(property["name"])
	return values

func _prepare_raw_front_camera(actor: PlayerHumanoidRig, side: String, hand: Transform3D) -> void:
	var sk: Skeleton3D = actor.skeleton
	var index: Vector3 = _get_bone_world_position(sk, "CC_Base_%s_Index1" % side)
	var pinky: Vector3 = _get_bone_world_position(sk, "CC_Base_%s_Pinky1" % side)
	var along: Vector3 = ((index + pinky) * 0.5 - hand.origin).normalized()
	var normal: Vector3 = (index - pinky).cross(along).normalized()
	if normal.is_zero_approx():
		normal = actor.global_basis.z.normalized()
	if normal.dot(actor.global_basis.z) < 0.0:
		normal = -normal
	var up: Vector3 = (along - normal * along.dot(normal)).normalized()
	if up.is_zero_approx():
		up = actor.global_basis.y.normalized()
	roll_raw_front_camera = {"offset": normal * 1.2, "up": up}

func _exercise_roll_pointer(ui: CombatAnimationStationUI, side: String, sign_direction: float, starting_degrees: float = 0.0, phase_prefix: String = "") -> void:
	ui.set_selected_motion_node_weapon_roll(starting_degrees, false)
	ui.session_state.current_focus = &"weapon"
	ui.call("_refresh_preview_scene")
	await _wait_frames(2)
	var motion: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var display: CombatAnimationMotionNode = ui.call("_build_display_motion_node_for_viewport_pick", motion) as CombatAnimationMotionNode
	var camera: Camera3D = ui.call("_get_preview_camera") as Camera3D
	var trajectory: Node3D = _get_trajectory_root(ui)
	var pointer: Vector2 = camera.unproject_position(trajectory.to_global(ui.motion_node_editor.get_weapon_rotation_handle_local(display)))
	_roll_mouse_button(ui, pointer, true)
	await _wait_frames(1)
	await _record_roll(ui, side, phase_prefix + "pointer_press", starting_degrees, false, false)
	if not ui.preview_weapon_roll_dragging:
		roll_case["pointer_failures"].append({"direction": sign_direction, "reason": "actual_handle_press_did_not_begin_roll"})
		_roll_mouse_button(ui, pointer, false)
		return
	var previous_pointer: Vector2 = pointer
	for delta_degrees: float in [30.0 * sign_direction, 0.0]:
		var requested: float = starting_degrees + delta_degrees
		var target_pointer: Vector2 = pointer + Vector2(delta_degrees * 2.0, 0.0)
		var event := InputEventMouseMotion.new()
		event.position = target_pointer
		event.relative = target_pointer - previous_pointer
		ui.call("_on_preview_gui_input", event)
		previous_pointer = target_pointer
		await _wait_frames(2)
		await _record_roll(ui, side, phase_prefix + "pointer_move", requested, null, false)
	_roll_mouse_button(ui, previous_pointer, false)
	await _wait_frames(2)
	await _record_roll(ui, side, phase_prefix + "pointer_release", starting_degrees, false, false)

func _roll_mouse_button(ui: CombatAnimationStationUI, pointer: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pointer
	event.pressed = pressed
	ui.call("_on_preview_gui_input", event)

func _roll_snapshot(ui: CombatAnimationStationUI, side: String) -> Dictionary:
	var actor: PlayerHumanoidRig = _get_preview_actor(ui) as PlayerHumanoidRig
	var sk: Skeleton3D = actor.skeleton
	var weapon: Node3D = _get_preview_held_item(ui)
	var hand_index: int = sk.find_bone("CC_Base_%s_Hand" % side)
	var local_bones: Array[Transform3D] = []
	for index: int in range(sk.get_bone_count()):
		local_bones.append(sk.get_bone_pose(index))
	return {"hand": sk.global_transform * sk.get_bone_global_pose(hand_index), "hand_index": hand_index, "weapon": weapon.global_transform, "tip": weapon.to_global(weapon.get_meta("weapon_tip_local")), "pommel": weapon.to_global(weapon.get_meta("weapon_pommel_local")), "local_bones": local_bones}

func _record_roll(ui: CombatAnimationStationUI, side: String, phase: String, requested: float, changed: Variant, capture_image: bool) -> void:
	var actor: PlayerHumanoidRig = _get_preview_actor(ui) as PlayerHumanoidRig
	var sk: Skeleton3D = actor.skeleton
	var slot: StringName = &"hand_left" if side == "L" else &"hand_right"
	var motion: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var snap: Dictionary = _roll_snapshot(ui, side)
	var hand: Transform3D = snap["hand"]
	var base_hand: Transform3D = roll_baseline["hand"]
	var weapon: Transform3D = snap["weapon"]
	var base_weapon: Transform3D = roll_baseline["weapon"]
	var relative_grip: Transform3D = hand.affine_inverse() * weapon
	var base_grip: Transform3D = base_hand.affine_inverse() * base_weapon
	var neutral_basis: Basis = actor.call("_resolve_neutral_hand_world_basis", snap["hand_index"]) as Basis
	var hand_q: Quaternion = hand.basis.orthonormalized().get_rotation_quaternion()
	var neutral_q: Quaternion = neutral_basis.get_rotation_quaternion()
	var rest_delta: Quaternion = (hand_q * neutral_q.inverse()).normalized()
	var forearm_axis: Vector3 = actor.resolve_hand_anatomical_y_axis_world(slot)
	var twist: Quaternion = actor.call("_extract_quaternion_twist", rest_delta, forearm_axis) as Quaternion
	var swing: Quaternion = (rest_delta * twist.inverse()).normalized()
	var index_pinky: Vector3 = hand.basis.orthonormalized() * actor.resolve_hand_index_pinky_axis_local(slot)
	var index_world: Vector3 = _get_bone_world_position(sk, "CC_Base_%s_Index1" % side)
	var pinky_world: Vector3 = _get_bone_world_position(sk, "CC_Base_%s_Pinky1" % side)
	var wrist_to_roots: Vector3 = ((index_world + pinky_world) * 0.5 - hand.origin).normalized()
	var palm_plane_normal: Vector3 = index_pinky.cross(wrist_to_roots).normalized()
	var non_hand_max := 0.0
	var non_hand_translation_max := 0.0
	for index: int in range(sk.get_bone_count()):
		if index == int(snap["hand_index"]):
			continue
		var current: Transform3D = snap["local_bones"][index]
		var baseline: Transform3D = roll_baseline["local_bones"][index]
		non_hand_max = maxf(non_hand_max, rad_to_deg(current.basis.orthonormalized().get_rotation_quaternion().angle_to(baseline.basis.orthonormalized().get_rotation_quaternion())))
		non_hand_translation_max = maxf(non_hand_translation_max, current.origin.distance_to(baseline.origin))
	var row: Dictionary = _capture_motion(ui, sk, side, roll_bone_baseline)
	var held_item: Node3D = _get_preview_held_item(ui)
	var raw_request: Dictionary = RollProbeResolver.resolve(roll_wrist_capture, base_weapon, held_item.get_meta("weapon_tip_local"), held_item.get_meta("weapon_tip_origin_id"), roll_baseline_degrees, requested)
	row["unclamped_resolver_request"] = {"available": raw_request.get("available", false), "reason": String(raw_request.get("reason", "")), "scope": "read-only geometry from captured baseline; bypasses UI gate for comparison only"}
	if raw_request.get("available", false):
		row["unclamped_resolver_request"]["hand_world"] = _roll_transform(raw_request["hand_transform_world"])
		row["unclamped_resolver_request"]["weapon_world"] = _roll_transform(raw_request["weapon_transform_world"])
	row["hand_neutral_reference_rule"] = "current immediate parent global pose multiplied by Hand rest basis, through existing rig method"
	if roll_case.has("raw_distal_helper_reference"):
		row["distal_helper_neutral_reference"] = roll_case["raw_distal_helper_reference"]
	row["hand_parent_bone"] = sk.get_bone_name(sk.get_bone_parent(int(snap["hand_index"])))
	var hand_index: int = snap["hand_index"]
	var forearm_index: int = sk.find_bone("CC_Base_%s_Forearm" % side)
	var upperarm_index: int = sk.find_bone("CC_Base_%s_Upperarm" % side)
	row["hand_rest_local_quaternion"] = _roll_quat(sk.get_bone_rest(hand_index).basis.orthonormalized().get_rotation_quaternion())
	row["forearm_rest_local_quaternion"] = _roll_quat(sk.get_bone_rest(forearm_index).basis.orthonormalized().get_rotation_quaternion())
	row["forearm_world_quaternion"] = _roll_quat((sk.global_basis * sk.get_bone_global_pose(forearm_index).basis).orthonormalized().get_rotation_quaternion())
	row["upperarm_world_quaternion"] = _roll_quat((sk.global_basis * sk.get_bone_global_pose(upperarm_index).basis).orthonormalized().get_rotation_quaternion())
	var index_root: int = sk.find_bone("CC_Base_%s_Index1" % side)
	var pinky_root: int = sk.find_bone("CC_Base_%s_Pinky1" % side)
	if index_root >= 0 and pinky_root >= 0:
		var rest_hand: Transform3D = actor.call("_get_bone_global_rest_transform", hand_index) as Transform3D
		var rest_index: Transform3D = actor.call("_get_bone_global_rest_transform", index_root) as Transform3D
		var rest_pinky: Transform3D = actor.call("_get_bone_global_rest_transform", pinky_root) as Transform3D
		var root_midpoint_in_hand: Vector3 = rest_hand.affine_inverse() * ((rest_index.origin + rest_pinky.origin) * 0.5)
		row["rest_mcp_midpoint_in_hand_local"] = _vec(root_midpoint_in_hand)
		row["neutral_wrist_to_mcp_midpoint_world"] = _vec((neutral_basis * root_midpoint_in_hand).normalized())
		row["neutral_mcp_reference_rule"] = "Index1/Pinky1 global rest midpoint expressed in Hand rest frame, rotated by current-parent-times-Hand-rest neutral basis"
	var roll_axis: Vector3 = ((roll_baseline["tip"] as Vector3) - base_hand.origin).normalized()
	var roll_delta: Quaternion = (hand_q * base_hand.basis.orthonormalized().get_rotation_quaternion().inverse()).normalized()
	var roll_twist: Quaternion = actor.call("_extract_quaternion_twist", roll_delta, roll_axis) as Quaternion
	row.merge({"case": roll_case["case"], "step": roll_sample_index, "sample_serial": sample_serial, "phase": phase, "requested_roll_degrees": requested, "authored_roll_degrees": motion.weapon_roll_degrees, "setter_reported_change": changed, "pointer_drag_active": ui.preview_weapon_roll_dragging, "rendered_roll_from_baseline_degrees": rad_to_deg(float(actor.call("_resolve_signed_twist_angle", roll_twist, roll_axis))), "wrist_position_error_m": hand.origin.distance_to(base_hand.origin), "tip_position_error_m": (snap["tip"] as Vector3).distance_to(roll_baseline["tip"]), "pommel_delta_m": (snap["pommel"] as Vector3).distance_to(roll_baseline["pommel"]), "rigid_grip_position_error_m": relative_grip.origin.distance_to(base_grip.origin), "rigid_grip_angle_error_degrees": rad_to_deg(relative_grip.basis.orthonormalized().get_rotation_quaternion().angle_to(base_grip.basis.orthonormalized().get_rotation_quaternion())), "non_hand_max_local_rotation_degrees": non_hand_max, "non_hand_max_local_translation_m": non_hand_translation_max, "hand_world": _roll_transform(hand), "weapon_world": _roll_transform(weapon), "tip_world": _vec(snap["tip"]), "pommel_world": _vec(snap["pommel"]), "hand_neutral_world_quaternion": _roll_quat(neutral_q), "hand_delta_from_current_forearm_rest_world_quaternion": _roll_quat(rest_delta), "forearm_longitudinal_world": _vec(forearm_axis), "hand_neutral_relative_forearm_twist_degrees": rad_to_deg(float(actor.call("_resolve_signed_twist_angle", twist, forearm_axis))), "hand_neutral_relative_swing_degrees": rad_to_deg(2.0 * acos(clampf(absf(swing.w), 0.0, 1.0))), "index_pinky_world": _vec(index_pinky), "wrist_to_finger_roots_world": _vec(wrist_to_roots), "palm_plane_normal_world": _vec(palm_plane_normal), "palm_normal_rule": "index_pinky cross wrist_to_root_midpoint; geometric normal, not certified outward skin normal", "hand_basis_x_world": _vec(hand.basis.x.normalized()), "hand_basis_y_world": _vec(hand.basis.y.normalized()), "hand_basis_z_world": _vec(hand.basis.z.normalized()), "helper_twist_state": actor.authoring_limb_twist_distribution_state.get(slot, {}), "contact_wrist_twist_limit_degrees": actor.authoring_contact_wrist_twist_limit_degrees, "retained_roll_matches": ui.preview_presenter.weapon_roll_manipulator.matches(actor, _get_preview_held_item(ui), _get_trajectory_root(ui), motion, slot), "lookup_scope_depth": ui.preview_authoring_lookup_scope_depth})
	if not roll_raw_sample_state.is_empty():
		var raw_state: Dictionary = roll_raw_sample_state.duplicate()
		if raw_state.has("expected_hand"):
			raw_state["expected_hand"] = _roll_transform(roll_raw_sample_state["expected_hand"])
			raw_state["expected_weapon"] = _roll_transform(roll_raw_sample_state["expected_weapon"])
			raw_state["before_images"] = _raw_roll_expected_errors(snap)
		row["raw_orbit"] = raw_state
	if capture_image:
		var name: String = "%s_%03d_%s.png" % [roll_case["case"], roll_sample_index, phase]
		if await _capture_frame(ui, actor, side, output_dir.path_join(name)):
			row["image"] = name
			roll_case["snapshots"].append(name)
		var wrist_name: String = name.trim_suffix(".png") + "_wrist.png"
		if await _capture_roll_wrist(ui, actor, side, hand.origin, output_dir.path_join(wrist_name)):
			row["wrist_image"] = wrist_name
			roll_case["snapshots"].append(wrist_name)
		if not roll_raw_sample_state.is_empty():
			var front_name: String = name.trim_suffix(".png") + "_wrist_front.png"
			if await _capture_roll_wrist(ui, actor, side, base_hand.origin, output_dir.path_join(front_name), true):
				row["wrist_front_image"] = front_name
				roll_case["snapshots"].append(front_name)
	if row.has("raw_orbit") and roll_raw_sample_state.has("expected_hand"):
		row["raw_orbit"]["after_images"] = _raw_roll_expected_errors(_roll_snapshot(ui, side))
	if not roll_live_initial_limits.is_empty():
		row["live_roll_checks"] = _check_live_roll(ui, side, phase, requested, motion, _roll_snapshot(ui, side))
	samples_file.store_line(JSON.stringify(row))
	samples_file.flush()
	roll_case["samples"] += 1
	roll_sample_index += 1
	sample_serial += 1
	print("WEAPON_ROLL %s step=%d %s requested=%.1f authored=%.1f ready=%s" % [side, roll_sample_index - 1, phase, requested, motion.weapon_roll_degrees, str(row["prepared_grip_readiness"]["ready"])])

func _check_live_roll(ui: CombatAnimationStationUI, side: String, phase: String, requested: float, motion: CombatAnimationMotionNode, snap: Dictionary) -> Dictionary:
	var current: Dictionary = _query_roll_limits(ui, motion)
	var minimum: float = roll_live_initial_limits["minimum_degrees"]
	var maximum: float = roll_live_initial_limits["maximum_degrees"]
	var original_pose_phase: bool = phase == "live_original_before_roll" or phase == "live_fields_refresh"
	var expected: float = roll_baseline_degrees if original_pose_phase else clampf(requested, minimum, maximum)
	var checks: Dictionary = {"limits_available": current["available"], "span_is_240_degrees": absf(float(current["maximum_degrees"]) - float(current["minimum_degrees"]) - 240.0) < 0.01, "center_is_interval_midpoint": absf(float(current["center_degrees"]) - (float(current["minimum_degrees"]) + float(current["maximum_degrees"])) * 0.5) < 0.01, "authored_matches_expected": absf(motion.weapon_roll_degrees - expected) < 0.01, "fields_do_not_clamp_scalar": absf(ui.weapon_roll_spin_box.value - motion.weapon_roll_degrees) <= 0.50001}
	for key: String in ["minimum_degrees", "maximum_degrees", "center_degrees"]:
		checks["stable_" + key] = absf(float(current[key]) - float(roll_live_initial_limits[key])) < 0.01
	if phase != "live_original_before_roll":
		checks["field_minimum_matches_live"] = absf(ui.weapon_roll_spin_box.min_value - float(current["minimum_degrees"])) < 0.01
		checks["field_maximum_matches_live"] = absf(ui.weapon_roll_spin_box.max_value - float(current["maximum_degrees"])) < 0.01
	var bone_unchanged := true
	for index: int in range((snap["local_bones"] as Array).size()):
		if index != int(roll_baseline["hand_index"]) and not (snap["local_bones"][index] as Transform3D).is_equal_approx(roll_baseline["local_bones"][index]):
			bone_unchanged = false
	checks["non_hand_bones_unchanged"] = bone_unchanged
	var weapon: Node3D = _get_preview_held_item(ui)
	var resolved: Dictionary = RollProbeResolver.resolve(roll_wrist_capture, roll_baseline["weapon"], weapon.get_meta("weapon_tip_local"), weapon.get_meta("weapon_tip_origin_id"), roll_baseline_degrees, expected)
	var result: Dictionary = {"current_limits": current, "fields": {"minimum": ui.weapon_roll_spin_box.min_value, "maximum": ui.weapon_roll_spin_box.max_value, "value": ui.weapon_roll_spin_box.value, "editable": ui.weapon_roll_spin_box.editable, "display_tolerance_degrees": 0.50001, "display_rule": "existing whole-degree SpinBox rounding; authored scalar remains continuous"}, "requested_unwrapped_degrees": requested, "expected_bounded_request_degrees": expected, "expected_unwrapped_delta_from_original_degrees": expected - roll_baseline_degrees, "original_pose_preservation_phase": original_pose_phase, "checks": checks}
	checks["expected_resolver_available"] = resolved.get("available", false)
	if resolved.get("available", false):
		var errors: Dictionary = _roll_pose_errors(snap, resolved["hand_transform_world"], resolved["weapon_transform_world"])
		result["expected_hand"] = _roll_transform(resolved["hand_transform_world"])
		result["expected_weapon"] = _roll_transform(resolved["weapon_transform_world"])
		result["after_images_pose_errors"] = errors
		checks["rendered_hand_matches_expected"] = float(errors["hand_angle_error_degrees"]) < 0.1 and float(errors["hand_position_error_m"]) < 0.00001
		checks["rendered_weapon_matches_expected"] = float(errors["weapon_angle_error_degrees"]) < 0.1 and float(errors["weapon_position_error_m"]) < 0.00001
	var passed := true
	for check: String in checks:
		if not bool(checks[check]):
			passed = false
			roll_case["live_failures"].append({"phase": phase, "step": roll_sample_index, "side": side, "request": requested, "check": check})
	result["passed"] = passed
	return result

func _raw_roll_expected_errors(snap: Dictionary) -> Dictionary:
	return _roll_pose_errors(snap, roll_raw_sample_state["expected_hand"], roll_raw_sample_state["expected_weapon"])

func _roll_pose_errors(snap: Dictionary, expected_hand: Transform3D, expected_weapon: Transform3D) -> Dictionary:
	var hand: Transform3D = snap["hand"]
	var weapon: Transform3D = snap["weapon"]
	var hand_dot: float = absf(hand.basis.orthonormalized().get_rotation_quaternion().normalized().dot(expected_hand.basis.orthonormalized().get_rotation_quaternion().normalized()))
	var weapon_dot: float = absf(weapon.basis.orthonormalized().get_rotation_quaternion().normalized().dot(expected_weapon.basis.orthonormalized().get_rotation_quaternion().normalized()))
	return {"hand_position_error_m": hand.origin.distance_to(expected_hand.origin), "weapon_position_error_m": weapon.origin.distance_to(expected_weapon.origin), "hand_angle_error_degrees": rad_to_deg(2.0 * acos(clampf(hand_dot, 0.0, 1.0))), "weapon_angle_error_degrees": rad_to_deg(2.0 * acos(clampf(weapon_dot, 0.0, 1.0)))}

func _capture_roll_wrist(ui: CombatAnimationStationUI, actor: Node3D, side: String, center: Vector3, path: String, front: bool = false) -> bool:
	if DisplayServer.get_name().to_lower() == "headless":
		return false
	var camera: Camera3D = ui.call("_get_preview_camera") as Camera3D
	var previous_transform: Transform3D = camera.global_transform
	var previous_size: float = camera.size
	var previous_projection: int = camera.projection
	# These are the presenter's visual-only children of TrajectoryRoot. Do not
	# hide the trajectory root, actor, held item, collision nodes or input owners.
	var hidden_visuals: Array[Dictionary] = []
	var trajectory: Node3D = _get_trajectory_root(ui)
	for visual_name: String in ["TrajectoryMarkerRoot", "ControlLineMesh", "TrajectoryMesh", "SphereVisualizationMesh", "OnionSkinRoot"]:
		var visual: Node3D = trajectory.get_node_or_null(NodePath(visual_name)) as Node3D
		if visual != null:
			hidden_visuals.append({"node": visual, "visible": visual.visible})
			visual.visible = false
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.52
	if front:
		camera.global_position = center + (roll_raw_front_camera["offset"] as Vector3)
		camera.look_at(center, roll_raw_front_camera["up"])
	else:
		camera.global_position = center + actor.global_basis * Vector3(0.7 if side == "R" else -0.7, 0.3, 0.8)
		camera.look_at(center, actor.global_basis.y.normalized())
	await RenderingServer.frame_post_draw
	var shot: Image = ui.preview_subviewport.get_texture().get_image()
	var saved: bool = shot != null and not shot.is_empty() and shot.save_png(path) == OK
	for saved_visual: Dictionary in hidden_visuals:
		var visual: Node3D = saved_visual["node"]
		if is_instance_valid(visual):
			visual.visible = bool(saved_visual["visible"])
	camera.global_transform = previous_transform
	camera.size = previous_size
	camera.projection = previous_projection
	return saved

func _roll_quat(value: Quaternion) -> Array:
	return [value.x, value.y, value.z, value.w]

func _roll_transform(value: Transform3D) -> Dictionary:
	return {"origin": _vec(value.origin), "quaternion": _roll_quat(value.basis.orthonormalized().get_rotation_quaternion()), "scale": _vec(value.basis.get_scale())}
