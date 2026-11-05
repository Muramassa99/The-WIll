extends SceneTree

## Real imported skeleton with declared, bent fixtures and a rigid test prop.
## No saved weapon/library, acquisition, skin-quality or station lifecycle claim.
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const Hinge = preload("res://core/resolvers/combat_arm_hinge_frame_resolver.gd")
const Wrist = preload("res://core/resolvers/combat_wrist_motion_resolver.gd")
const Capture = preload("res://runtime/combat/combat_prepared_pose_capture.gd")
const POSITION_EPSILON := 0.00005
const ANGLE_EPSILON := deg_to_rad(0.025)
var output_dir := "C:/WORKSPACE/godot_runs/weapon_motion_allocator"
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var rig: PlayerHumanoidRig
var skeleton: Skeleton3D
var base_poses: Array[Transform3D] = []
var actor_parent: Node3D

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			output_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")

func _run() -> void:
	actor_parent = Node3D.new()
	root.add_child(actor_parent)
	rig = RigScene.instantiate() as PlayerHumanoidRig
	actor_parent.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.reset_authoring_preview_baseline_pose()
	rig.set_process(false)
	rig.set_physics_process(false)
	for tree: Node in rig.find_children("*", "AnimationTree", true, false):
		(tree as AnimationTree).active = false
	skeleton = rig.skeleton
	_check(skeleton != null and rig.has_method("allocate_authoring_weapon_motion"), "allocator_rig_api_available")
	if skeleton == null or not rig.has_method("allocate_authoring_weapon_motion"):
		_finish()
		return
	for side: String in ["R", "L"]:
		_seed_bent_neutral_wrist(side)
	base_poses = _poses()
	for side: String in ["R", "L"]:
		_exercise(side, false)
		_exercise(side, true)
		_exercise_wrist_boundary(side)
		_exercise_wrist_measurement(side)
		_exercise_independent_arm(side)
	_exercise_two_hands()
	_exercise_outside_shoulder_recovery()
	_exercise_stale_wrist_failure()
	_exercise_outside_wrist_recovery()
	_exercise_inverted_elbow_recovery()
	_finish()

func _seed_bent_neutral_wrist(side: String) -> void:
	var p := "CC_Base_" + side + "_"
	var u := skeleton.find_bone(p + "Upperarm")
	var f := skeleton.find_bone(p + "Forearm")
	var h := skeleton.find_bone(p + "Hand")
	var upper := skeleton.get_bone_global_pose(u)
	var forearm := skeleton.get_bone_global_pose(f)
	var hand := skeleton.get_bone_global_pose(h)
	var shaft := (forearm.origin - upper.origin).normalized()
	var distal := (hand.origin - forearm.origin).normalized()
	var axis := shaft.cross(distal)
	var current := atan2(axis.length(), shaft.dot(distal))
	if axis.length() < Hinge.BEND_SINE_EPSILON:
		var calibration: Dictionary = Hinge.calibration(skeleton.get_bone_rest(f), skeleton.get_bone_rest(h))
		if not calibration.get("valid", false):
			_check(false, side + "_fixture_hinge_calibration", calibration)
			return
		axis = upper.basis.orthonormalized() * calibration.frame_in_upperarm.x
	var desired := Basis(axis.normalized(), deg_to_rad(60.0) - current) * forearm.basis.orthonormalized()
	skeleton.set_bone_pose_rotation(f, (upper.basis.orthonormalized().inverse() * desired).get_rotation_quaternion().normalized())
	skeleton.force_update_all_bone_transforms()
	rig.call("_enforce_authoring_upperarm_swing_authority", _slot(side), StringName(p + "Clavicle"), StringName(p + "Upperarm"), StringName(p + "Forearm"), StringName(p + "Hand"))
	var calibration: Dictionary = rig.capture_wrist_constraint_calibration(_slot(side))
	var profile: Dictionary = rig.wrist_motion_profile.call("as_dictionary")
	var neutral: Dictionary = Wrist.compose(skeleton.get_bone_global_pose(f), skeleton.get_bone_global_pose(h), calibration, profile, {"rho": 0.0, "beta": 0.0, "gamma": 0.0})
	_check(neutral.get("valid", false), side + "_fixture_neutral_wrist_composes", neutral)
	if not neutral.get("valid", false): return
	var target := Transform3D(neutral.accepted_hand_basis, skeleton.get_bone_global_pose(h).origin)
	var accepted: Dictionary = rig.call("_resolve_authoring_forearm_hand_index", _slot(side), skeleton.global_transform * target)
	_check(accepted.get("valid", false), side + "_fixture_neutral_wrist_accepted", accepted)
	if accepted.get("valid", false):
		rig.call("_write_authoring_forearm_hand_index", _slot(side), accepted)

func _exercise(side: String, transformed: bool) -> void:
	_restore()
	actor_parent.transform = Transform3D(Basis.from_euler(Vector3(0.2, -0.6, 0.1)), Vector3(2.0, 1.0, -3.0)) if transformed else Transform3D.IDENTITY
	var label := side + ("_transformed" if transformed else "_identity")
	var prop := Node3D.new()
	root.add_child(prop)
	# The control anchor is 8 cm from the actual wrist centre in the Hand's
	# local longitudinal direction. This explicitly exercises compensation.
	prop.global_transform = _hand_world(side) * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	var hand_in_prop := prop.global_transform.affine_inverse() * _hand_world(side)
	prop.set_meta("fixture_hand_in_weapon", {_slot(side): hand_in_prop})
	var before: Transform3D = prop.global_transform
	var proximal_before := _proximal_spine_poses()
	var opposite_before := _arm_world_poses("L" if side == "R" else "R")
	var axis: Vector3 = _hand_world(side).basis.x.normalized()
	var target := _orbit(before, Vector3.ZERO, axis, deg_to_rad(3.0))
	var request := _request(side, prop, target, "tip")
	request.commit = false
	var bones_before := var_to_bytes(_poses())
	var trial: Dictionary = _allocate(request)
	_record(label + "_trial_tip", trial)
	_check(bones_before == var_to_bytes(_poses()) and prop.global_transform.is_equal_approx(before), label + "_trial_does_not_mutate_scene")
	request.commit = true
	var result: Dictionary = _allocate(request)
	_record(label + "_tip", result)
	_check(result.get("valid", false), label + "_small_tip_accepted", result)
	_check(_proximal_spine_unchanged(proximal_before), label + "_tip_stops_at_clavicle")
	_check(_world_poses_unchanged(opposite_before), label + "_tip_preserves_opposite_arm_world_pose")
	if not result.get("valid", false):
		prop.queue_free()
		return
	_check(prop.global_position.distance_to(before.origin) > POSITION_EPSILON, label + "_tip_contact_can_travel",
		{"grip_travel_m": prop.global_position.distance_to(before.origin)})
	_check(_basis_error(prop.global_basis, before.basis) > deg_to_rad(0.001) and _basis_error(prop.global_basis, target.basis) <= ANGLE_EPSILON,
		label + "_tip_reaches_actual_orientation")
	_check(_pose_error(prop.global_transform.affine_inverse() * _hand_world(side), hand_in_prop), label + "_tip_keeps_rigid_hand_relation")
	_check(rig.validate_authoring_forearm_hand_indexing().get("valid", false), label + "_tip_wrist_semantics_valid")
	var accepted_pose := _poses()
	var accepted_frame := prop.global_transform
	var hold: Dictionary = _allocate(_request(side, prop, accepted_frame, "tip"))
	_check(hold.get("valid", false) and _poses_close(accepted_pose, _poses()), label + "_zero_input_does_not_recentre")
	# Reverse from accepted state; never from an unrealized raw request.
	target = _orbit(prop.global_transform, Vector3.ZERO, axis, deg_to_rad(-1.0))
	result = _allocate(_request(side, prop, target, "tip"))
	_record(label + "_reverse", result)
	_check(result.get("valid", false), label + "_reverse_has_legal_motion", result)
	_check(_pose_error(prop.global_transform.affine_inverse() * _hand_world(side), hand_in_prop), label + "_reverse_keeps_contact")
	before = prop.global_transform
	target = before
	target.origin += actor_parent.global_basis * Vector3(0.002, 0.002, 0.0)
	result = _allocate(_request(side, prop, target, "pommel"))
	_record(label + "_pommel", result)
	_check(result.get("valid", false), label + "_small_translation_accepted", result)
	_check(_basis_error(prop.global_basis, before.basis) <= ANGLE_EPSILON, label + "_translation_preserves_orientation")
	_check(_pose_error(prop.global_transform.affine_inverse() * _hand_world(side), hand_in_prop), label + "_translation_keeps_contact")
	_check(_proximal_spine_unchanged(proximal_before), label + "_one_hand_pommel_stops_at_clavicle")
	_check(_world_poses_unchanged(opposite_before), label + "_pommel_preserves_opposite_arm_world_pose")
	before = prop.global_transform
	target = _orbit(before, Vector3.ZERO, before.basis.z.normalized(), deg_to_rad(2.0))
	result = _allocate(_request(side, prop, target, "roll"))
	_record(label + "_roll", result)
	_check(result.get("valid", false), label + "_small_roll_accepted", result)
	_check(prop.global_position.distance_to(before.origin) <= POSITION_EPSILON and _pose_error(prop.global_transform.affine_inverse() * _hand_world(side), hand_in_prop), label + "_roll_keeps_pivot_and_contact")
	_check(_proximal_spine_unchanged(proximal_before), label + "_one_hand_roll_stops_at_clavicle")
	_check(_world_poses_unchanged(opposite_before), label + "_roll_preserves_opposite_arm_world_pose")
	_exercise_saved_writer(side, prop, label)
	prop.queue_free()

func _exercise_independent_arm(side: String) -> void:
	_restore()
	actor_parent.transform = Transform3D(Basis.from_euler(Vector3(0.13, -0.37, 0.09)), Vector3(1.0, 0.4, -1.2))
	var slot := _slot(side)
	var other_side := "L" if side == "R" else "R"
	var other_slot := _slot(other_side)
	var target := Node3D.new()
	var other_target := Node3D.new()
	root.add_child(target)
	root.add_child(other_target)
	target.global_position = _hand_world(side).origin + actor_parent.global_basis * Vector3(0.015, 0.025, -0.01)
	other_target.global_position = _hand_world(other_side).origin + actor_parent.global_basis * Vector3(0.08, 0.06, 0.03)
	# Both guidance targets are active and disagree with the current pose. A
	# shared solve would move the other arm, so this is not an inactive-arm pass.
	rig.set_arm_guidance_target(slot, target)
	rig.set_arm_guidance_active(slot, true)
	rig.set_arm_guidance_target(other_slot, other_target)
	rig.set_arm_guidance_active(other_slot, true)
	rig.set_upper_body_authoring_state({"active": true, "blend": 1.0, "two_hand": false,
		"dominant_slot_id": other_slot, "primary_target_world": other_target.global_position,
		"tip_world": other_target.global_position + Vector3.UP, "pommel_world": other_target.global_position,
		"right_upperarm_roll_degrees": 25.0, "left_upperarm_roll_degrees": -25.0})
	var opposite_before := _arm_world_poses(other_side)
	var ancestors_before := _proximal_spine_poses()
	var active_before := _arm_world_poses(side)
	var locals_before := _poses()
	var result: Dictionary = rig.apply_authoring_independent_arm_frame_now(slot)
	_check(result.get("valid", false), side + "_independent_arm_edit_applies", result)
	_check(not _world_poses_unchanged(active_before), side + "_independent_arm_actually_moves")
	_check(_world_poses_unchanged(opposite_before), side + "_independent_arm_preserves_opposite_world_pose")
	_check(_proximal_spine_unchanged(ancestors_before), side + "_independent_arm_preserves_shared_ancestors")
	_check(_local_positions_unchanged(locals_before), side + "_independent_arm_does_not_stretch_bones")
	_check(rig.has_authoring_independent_arm_pose_authority(slot), side + "_independent_arm_retains_authority")
	var accepted := _poses()
	# Exercise actual ordinary refresh owners, not just immediate readback.
	rig.call("_process", 1.0 / 60.0)
	rig.apply_authoring_preview_frame_now()
	rig.apply_authoring_preview_drag_frame_now()
	rig.apply_runtime_contact_group_frame_now()
	rig.process_combat_authoring_modifier_frame()
	rig.call("_advance_skeleton_modifiers_now", 1.0 / 60.0)
	_check(_poses_close(accepted, _poses()) and _world_poses_unchanged(opposite_before), side + "_independent_arm_survives_idle_and_refresh")
	rig.clear_authoring_independent_arm_pose_authority()
	_check(not rig.has_authoring_independent_arm_pose_authority(), side + "_independent_arm_authority_can_release")
	rig.clear_arm_guidance_target(slot)
	rig.clear_arm_guidance_target(other_slot)
	rig.clear_upper_body_authoring_state()
	target.queue_free()
	other_target.queue_free()

func _exercise_two_hands() -> void:
	_restore()
	actor_parent.transform = Transform3D.IDENTITY
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = _hand_world("R") * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	var a := prop.global_transform.affine_inverse() * _hand_world("R")
	var b := prop.global_transform.affine_inverse() * _hand_world("L")
	prop.set_meta("fixture_hand_in_weapon", {&"hand_right": a, &"hand_left": b})
	var target := _orbit(prop.global_transform, Vector3.ZERO, prop.global_basis.y.normalized(), deg_to_rad(0.5))
	var request := _request("R", prop, target, "tip")
	request.support_slot = &"hand_left"
	var proximal_before := _proximal_spine_poses()
	var primary_before := _hand_world("R")
	var support_before := _hand_world("L")
	var result: Dictionary = _allocate(request)
	_record("two_hand_shared_rigid_prop", result)
	_check(result.get("valid", false), "two_hand_small_tip_accepted", result)
	_check(_proximal_spine_unchanged(proximal_before), "two_hand_tip_stops_at_clavicle")
	var primary_expected := prop.global_transform * a
	var support_expected := prop.global_transform * b
	_check(_pose_error(_hand_world("R"), primary_expected), "two_hand_primary_relation_retained", _transform_error(_hand_world("R"), primary_expected))
	_check(_pose_error(_hand_world("L"), support_expected), "two_hand_support_relation_retained", _transform_error(_hand_world("L"), support_expected))
	_check(not _pose_error(_hand_world("R"), primary_before) and not _pose_error(_hand_world("L"), support_before), "two_hand_shared_control_moves_both_arms")
	prop.queue_free()

func _exercise_wrist_boundary(side: String) -> void:
	_restore()
	actor_parent.transform = Transform3D.IDENTITY
	var forearm := skeleton.find_bone("CC_Base_" + side + "_Forearm")
	var hand := skeleton.find_bone("CC_Base_" + side + "_Hand")
	var calibration: Dictionary = rig.capture_wrist_constraint_calibration(_slot(side))
	var profile: Dictionary = rig.wrist_motion_profile.call("as_dictionary")
	var state := {"rho": 0.0, "beta": float(profile.extension_limit_radians) - deg_to_rad(0.1), "gamma": 0.0}
	var composed: Dictionary = Wrist.compose(skeleton.get_bone_global_pose(forearm), skeleton.get_bone_global_pose(hand), calibration, profile, state)
	if not composed.get("valid", false):
		_check(false, side + "_boundary_fixture_composes", composed)
		return
	var target_hand := Transform3D(composed.accepted_hand_basis, skeleton.get_bone_global_pose(hand).origin)
	var accepted: Dictionary = rig.call("_resolve_authoring_forearm_hand_index", _slot(side), skeleton.global_transform * target_hand)
	if not accepted.get("valid", false):
		_check(false, side + "_boundary_fixture_accepted", accepted)
		return
	rig.call("_write_authoring_forearm_hand_index", _slot(side), accepted)
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = _hand_world(side) * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	var relation := prop.global_transform.affine_inverse() * _hand_world(side)
	prop.set_meta("fixture_hand_in_weapon", {_slot(side): relation})
	var anatomical: Basis = _hand_world(side).basis.orthonormalized() * calibration.anatomical_in_hand_bone
	var weapon_before := prop.global_transform
	var elbow_before := _elbow_flexion_degrees(side)
	var proximal_before := _proximal_spine_poses()
	var target := _orbit(prop.global_transform, Vector3.ZERO, anatomical.x, deg_to_rad(3.0))
	var result := _allocate(_request(side, prop, target, "tip"))
	result["measured_grip_travel_m"] = prop.global_position.distance_to(weapon_before.origin)
	result["measured_elbow_delta_degrees"] = _elbow_flexion_degrees(side) - elbow_before
	result["measured_weapon_rotation_degrees"] = rad_to_deg(_basis_error(prop.global_basis, weapon_before.basis))
	_record(side + "_wrist_boundary_continue", result)
	_check(result.get("valid", false), side + "_wrist_boundary_recruits_legal_chain", result)
	_check(_proximal_spine_unchanged(proximal_before), side + "_wrist_boundary_stops_at_clavicle")
	_check(float(result.measured_grip_travel_m) > POSITION_EPSILON, side + "_boundary_grip_can_travel",
		{"grip_travel_m": result.measured_grip_travel_m})
	_check(absf(float(result.measured_elbow_delta_degrees)) > 0.001 and "elbow" in result.get("contributing_joint_groups", []),
		side + "_boundary_elbow_actually_bends", {"elbow_delta_degrees": result.measured_elbow_delta_degrees})
	_check(float(result.measured_weapon_rotation_degrees) > 0.001 and _basis_error(prop.global_basis, target.basis) <= ANGLE_EPSILON,
		side + "_boundary_reaches_requested_orientation")
	_check(_pose_error(_hand_world(side), prop.global_transform * relation), side + "_boundary_keeps_rigid_grip")
	var after: Dictionary = rig.capture_wrist_constraint_state(_slot(side))
	_check(not after.is_empty() and float(after.get("beta", INF)) <= float(profile.extension_limit_radians) + 0.000001, side + "_boundary_does_not_extend_wrist_limit", after)
	if result.get("valid", false):
		target = _orbit(prop.global_transform, Vector3.ZERO, anatomical.x, deg_to_rad(-1.0))
		result = _allocate(_request(side, prop, target, "tip"))
		_record(side + "_wrist_boundary_reverse", result)
		_check(result.get("valid", false), side + "_boundary_reverse_responds", result)
		_check(_pose_error(_hand_world(side), prop.global_transform * relation), side + "_boundary_reverse_keeps_grip")
	prop.queue_free()

func _exercise_saved_writer(side: String, prop: Node3D, label: String) -> void:
	var captured: Dictionary = Capture.capture(rig, prop, _slot(side), [], false, "allocator_fixture", false)
	_check(captured.get("valid", false), label + "_capture_available", {"reason": captured.get("reason", "")})
	if not captured.get("valid", false): return
	var hand_before := _hand_world(side)
	var raw: Dictionary = rig.capture_runtime_upper_body_pose_frame()
	rig.call("clear_authoring_weapon_motion_authority")
	var calibration := {"bone_names": captured.bone_names, "bone_rest_transforms": captured.bone_rest_transforms,
		"arm_constraints_by_slot": captured.arm_constraints_by_slot, "wrist_states_by_slot": captured.wrist_states_by_slot}
	var applied := rig.apply_runtime_solved_upper_body_pose_frame(raw.bone_names, raw.pose_positions, raw.pose_rotations, raw.pose_scales, 1.0, calibration)
	_check(applied, label + "_shared_saved_pose_writer_accepts", rig.get_meta("last_solved_body_replay_validation", {}))
	_check(_pose_error(_hand_world(side), hand_before), label + "_shared_saved_writer_preserves_hand_endpoint")
	rig.clear_runtime_solved_replay_pose_frame()

func _exercise_wrist_measurement(side: String) -> void:
	_restore()
	var forearm := skeleton.get_bone_global_pose(skeleton.find_bone("CC_Base_" + side + "_Forearm"))
	var hand := skeleton.get_bone_global_pose(skeleton.find_bone("CC_Base_" + side + "_Hand"))
	var calibration: Dictionary = rig.capture_wrist_constraint_calibration(_slot(side))
	var profile: Dictionary = rig.wrist_motion_profile.call("as_dictionary")
	# Equivalent frames in another reference must measure the same local state.
	var frame := Transform3D(Basis.from_euler(Vector3(0.23, -0.4, 0.17)), Vector3(1.2, -0.3, 2.1)) if side == "L" else Transform3D.IDENTITY
	forearm = frame * forearm
	hand = frame * hand
	var states: Array[Dictionary] = [
		{"rho": float(profile.forearm_roll_limit_radians) + 0.15, "beta": 0.2, "gamma": 0.1},
		{"rho": 0.1, "beta": float(profile.extension_limit_radians) * 0.9, "gamma": float(profile.radial_limit_radians) * 0.9},
		{"rho": PI + 0.02, "beta": 0.1, "gamma": 0.05},
	]
	for index: int in states.size():
		var state: Dictionary = states[index]
		var sampled: Dictionary = Wrist.sample_kinematics(forearm, hand, calibration, profile, state)
		_check(sampled.get("valid", false), "%s_measurement_%d_sample_valid" % [side, index])
		if not sampled.get("valid", false): continue
		var actual := Transform3D(sampled.hand_basis, hand.origin)
		var prior: Dictionary = state.duplicate()
		if index == 2: prior.rho = PI - 0.02
		var measured: Dictionary = Wrist.measure_state(forearm, actual, calibration, profile, prior)
		_record("%s_unbounded_wrist_measurement_%d" % [side, index], measured)
		_check(measured.get("valid", false) and _basis_error(measured.get("hand_basis", Basis.IDENTITY), actual.basis) <= ANGLE_EPSILON,
			"%s_measurement_%d_reconstructs_actual_pose" % [side, index])
		if not measured.get("valid", false): continue
		_check(not measured.get("within_limits", true), "%s_measurement_%d_does_not_certify_range" % [side, index])
		var captured: Dictionary = measured.state
		_check(absf(float(captured.rho) - float(state.rho)) < 0.001 and absf(float(captured.beta) - float(state.beta)) < 0.001 and absf(float(captured.gamma) - float(state.gamma)) < 0.001,
			"%s_measurement_%d_does_not_clamp_or_change_branch" % [side, index], {"expected": state, "measured": captured})
		var strict: Dictionary = Wrist.compose(forearm, actual, calibration, profile, captured)
		_check(not strict.get("valid", true), "%s_measurement_%d_strict_compose_still_rejects" % [side, index])

func _exercise_stale_wrist_failure() -> void:
	_restore()
	actor_parent.transform = Transform3D.IDENTITY
	var previous_failures: Dictionary = (rig.get("_wrist_motion_failures") as Dictionary).duplicate(true)
	var stale := previous_failures.duplicate(true)
	stale[&"hand_right"] = {"reason": "fixture_previous_wrist_failure"}
	rig.set("_wrist_motion_failures", stale)
	_check(rig.capture_wrist_constraint_state(&"hand_right").is_empty(), "stale_failure_fixture_blocks_old_capture")
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = _hand_world("R") * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	var before := prop.global_transform
	var binding := before.affine_inverse() * _hand_world("R")
	prop.set_meta("fixture_hand_in_weapon", {&"hand_right": binding})
	var spine := _proximal_spine_poses()
	var target := _orbit(before, Vector3.ZERO, _hand_world("R").basis.x.normalized(), deg_to_rad(0.5))
	var result := _allocate(_request("R", prop, target, "tip"))
	_record("stale_wrist_failure_current_pose_valid", result)
	_check(result.get("valid", false) and _basis_error(before.basis, prop.global_basis) > deg_to_rad(0.1), "stale_failure_does_not_block_actual_motion")
	_check(_pose_error(_hand_world("R"), prop.global_transform * binding), "stale_failure_recovery_keeps_attachment")
	_check(_proximal_spine_unchanged(spine), "stale_failure_recovery_keeps_spine")
	rig.set("_wrist_motion_failures", previous_failures)
	prop.queue_free()

func _exercise_outside_wrist_recovery() -> void:
	_restore()
	actor_parent.transform = Transform3D.IDENTITY
	var forearm := skeleton.find_bone("CC_Base_R_Forearm")
	var hand := skeleton.find_bone("CC_Base_R_Hand")
	var calibration: Dictionary = rig.capture_wrist_constraint_calibration(&"hand_right")
	var profile: Dictionary = rig.wrist_motion_profile.call("as_dictionary")
	var limit: float = profile.extension_limit_radians
	var start := {"rho": 0.0, "beta": limit + deg_to_rad(0.2), "gamma": 0.0}
	var sampled: Dictionary = Wrist.sample_kinematics(skeleton.get_bone_global_pose(forearm), skeleton.get_bone_global_pose(hand), calibration, profile, start)
	_check(sampled.get("valid", false), "outside_wrist_fixture_sample_valid")
	if not sampled.get("valid", false): return
	skeleton.set_bone_pose_rotation(hand, (skeleton.get_bone_global_pose(forearm).basis.inverse() * (sampled.hand_basis as Basis)).get_rotation_quaternion().normalized())
	skeleton.force_update_all_bone_transforms()
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = _hand_world("R") * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	var binding := prop.global_transform.affine_inverse() * _hand_world("R")
	prop.set_meta("fixture_hand_in_weapon", {&"hand_right": binding})
	var anatomical: Basis = _hand_world("R").basis.orthonormalized() * calibration.anatomical_in_hand_bone
	var spine := _proximal_spine_poses()
	for step: int in 2:
		var before := prop.global_transform
		var amount := -0.1 if step == 0 else -0.25
		var target := _orbit(before, Vector3.ZERO, anatomical.x, deg_to_rad(amount))
		var result := _allocate(_request("R", prop, target, "tip"))
		var measured: Dictionary = Wrist.measure_state(skeleton.get_bone_global_pose(forearm), skeleton.get_bone_global_pose(hand), calibration, profile, start)
		result["measured_wrist"] = measured
		_record("outside_wrist_correction_%d" % step, result)
		_check(result.get("valid", false), "outside_wrist_step_%d_commits" % step, result)
		_check(_basis_error(before.basis, prop.global_basis) > deg_to_rad(0.02), "outside_wrist_step_%d_has_actual_motion" % step)
		_check(not (result.get("initial_warning", {}) as Dictionary).is_empty(), "outside_wrist_step_%d_reports_warning" % step)
		_check(_pose_error(_hand_world("R"), prop.global_transform * binding), "outside_wrist_step_%d_keeps_attachment" % step)
		_check(_proximal_spine_unchanged(spine), "outside_wrist_step_%d_keeps_spine" % step)
		if not result.get("valid", false) or not measured.get("valid", false): break
		var beta: float = measured.state.beta
		if step == 0:
			_check(beta > limit and beta < float(start.beta) - deg_to_rad(0.02), "outside_wrist_partial_correction_survives_readback", {"beta_degrees": rad_to_deg(beta)})
		else:
			_check(beta < limit and (result.get("pose_warning", {}) as Dictionary).is_empty(), "outside_wrist_fresh_adapter_finishes_correction", {"beta_degrees": rad_to_deg(beta)})
	prop.queue_free()

func _exercise_outside_shoulder_recovery() -> void:
	_restore()
	actor_parent.transform = Transform3D.IDENTITY
	var side := "R"
	var clavicle := skeleton.find_bone("CC_Base_R_Clavicle")
	var upper := skeleton.find_bone("CC_Base_R_Upperarm")
	var forearm := skeleton.find_bone("CC_Base_R_Forearm")
	var c := skeleton.get_bone_global_pose(clavicle)
	var u := skeleton.get_bone_global_pose(upper)
	var f := skeleton.get_bone_global_pose(forearm)
	var inward := (c.origin - u.origin).normalized()
	var shaft := (f.origin - u.origin).normalized()
	var normal := inward.cross(shaft).normalized()
	if normal.length_squared() < 0.5:
		_check(false, "recovery_fixture_has_defined_shoulder_plane")
		return
	var limit := deg_to_rad(rig.authoring_shoulder_max_plane_angle_degrees)
	var seeded := limit + deg_to_rad(0.2)
	var rotated := Basis(normal, seeded - inward.angle_to(shaft)) * u.basis.orthonormalized()
	skeleton.set_bone_pose_rotation(upper, (c.basis.orthonormalized().inverse() * rotated).get_rotation_quaternion().normalized())
	skeleton.force_update_all_bone_transforms()
	var initial_angle := _shoulder_angle_degrees(side)
	_check(initial_angle > rig.authoring_shoulder_max_plane_angle_degrees + 0.15,
		"recovery_fixture_starts_outside_existing_shoulder_range", {"angle_degrees": initial_angle})
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = _hand_world(side) * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	var binding := prop.global_transform.affine_inverse() * _hand_world(side)
	prop.set_meta("fixture_hand_in_weapon", {_slot(side): binding})
	var proximal_before := _proximal_spine_poses()
	var axis := (skeleton.global_basis * normal).normalized()
	# This fixture isolates shoulder recovery using the existing policy seam.
	# Default production Tip priorities are verified by the other fixtures.
	var hold_order: Array = [PackedStringArray(["shoulder_girdle"]),
		PackedStringArray(["wrist", "forearm", "elbow", "shoulder_roll"]), PackedStringArray(["shoulder_swing"])]
	for step: int in 2:
		var before := prop.global_transform
		var amount := -0.1 if step == 0 else -0.25
		var target := _orbit(before, Vector3.ZERO, axis, deg_to_rad(amount))
		var request := _request(side, prop, target, "tip")
		request["policy"] = {"hold_order_by_mode": {"tip": hold_order}}
		var result := _allocate(request)
		var angle := _shoulder_angle_degrees(side)
		result["measured_shoulder_angle_degrees"] = angle
		result["measured_weapon_rotation_degrees"] = rad_to_deg(_basis_error(before.basis, prop.global_basis))
		_record("outside_shoulder_correction_%d" % step, result)
		_check(result.get("valid", false), "outside_shoulder_step_%d_commits" % step, result)
		_check(float(result.measured_weapon_rotation_degrees) > 0.01,
			"outside_shoulder_step_%d_has_actual_motion" % step)
		_check(not (result.get("initial_warning", {}) as Dictionary).is_empty(), "outside_shoulder_step_%d_warns_about_inherited_pose" % step)
		_check(_pose_error(_hand_world(side), prop.global_transform * binding), "outside_shoulder_step_%d_keeps_attachment" % step)
		_check(_proximal_spine_unchanged(proximal_before), "outside_shoulder_step_%d_keeps_spine" % step)
		if step == 0:
			_check(angle > rig.authoring_shoulder_max_plane_angle_degrees and angle < initial_angle - 0.02,
				"outside_shoulder_partial_correction_survives_commit", {"angle_degrees": angle})
			_check(not (result.get("pose_warning", {}) as Dictionary).is_empty(), "partial_shoulder_correction_keeps_warning")
		else:
			_check(angle < rig.authoring_shoulder_max_plane_angle_degrees,
				"outside_shoulder_fresh_adapter_can_finish_correction", {"angle_degrees": angle})
			_check((result.get("pose_warning", {}) as Dictionary).is_empty(), "full_shoulder_correction_clears_warning")
		if not result.get("valid", false): break
	prop.queue_free()

func _exercise_inverted_elbow_recovery() -> void:
	_restore()
	actor_parent.transform = Transform3D.IDENTITY
	var upper := skeleton.find_bone("CC_Base_R_Upperarm")
	var forearm := skeleton.find_bone("CC_Base_R_Forearm")
	var hand := skeleton.find_bone("CC_Base_R_Hand")
	var calibration: Dictionary = Hinge.calibration(skeleton.get_bone_rest(forearm), skeleton.get_bone_rest(hand))
	_check(calibration.get("valid", false), "inverted_elbow_fixture_has_calibrated_hinge")
	if not calibration.get("valid", false): return
	var u := skeleton.get_bone_global_pose(upper)
	var f := skeleton.get_bone_global_pose(forearm)
	var axis := (u.basis.orthonormalized() * (calibration.frame_in_upperarm as Basis).x).normalized()
	var initial := deg_to_rad(-0.2)
	var desired := Basis(axis, initial - _signed_elbow_flexion("R")) * f.basis.orthonormalized()
	skeleton.set_bone_pose_rotation(forearm, (u.basis.orthonormalized().inverse() * desired).get_rotation_quaternion().normalized())
	skeleton.force_update_all_bone_transforms()
	_check(_signed_elbow_flexion("R") < deg_to_rad(-0.15), "inverted_elbow_fixture_starts_negative")
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = _hand_world("R") * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	var binding := prop.global_transform.affine_inverse() * _hand_world("R")
	prop.set_meta("fixture_hand_in_weapon", {&"hand_right": binding})
	var spine := _proximal_spine_poses()
	var bones := _poses()
	var held: Dictionary = _allocate(_request("R", prop, prop.global_transform, "tip"))
	_check(held.get("valid", false) and _poses_close(bones, _poses()), "inverted_elbow_zero_input_does_not_recentre")
	var hold_order: Array = [PackedStringArray(["shoulder_girdle"]),
		PackedStringArray(["shoulder_swing", "shoulder_roll"]), PackedStringArray(["wrist", "forearm"]), PackedStringArray(["elbow"])]
	var minimum := PI - deg_to_rad(rig.authoring_elbow_max_plane_angle_degrees)
	var world_axis := (skeleton.global_basis * axis).normalized()
	for step: int in 2:
		var before := prop.global_transform
		var amount := deg_to_rad(0.1) if step == 0 else minimum + deg_to_rad(0.3)
		var target := _orbit(before, Vector3.ZERO, world_axis, amount)
		var request := _request("R", prop, target, "tip")
		request["policy"] = {"hold_order_by_mode": {"tip": hold_order}}
		var result := _allocate(request)
		var flexion := _signed_elbow_flexion("R")
		result["measured_signed_flexion_degrees"] = rad_to_deg(flexion)
		_record("inverted_elbow_correction_%d" % step, result)
		_check(result.get("valid", false), "inverted_elbow_step_%d_commits" % step, result)
		_check(_basis_error(before.basis, prop.global_basis) > deg_to_rad(0.02), "inverted_elbow_step_%d_actually_moves" % step)
		_check(_pose_error(_hand_world("R"), prop.global_transform * binding), "inverted_elbow_step_%d_keeps_attachment" % step)
		_check(_proximal_spine_unchanged(spine), "inverted_elbow_step_%d_keeps_spine" % step)
		if step == 0:
			_check(flexion < 0.0 and flexion > initial + deg_to_rad(0.02), "inverted_elbow_partial_correction_commits_while_still_negative")
		else:
			_check(flexion >= minimum and (result.get("pose_warning", {}) as Dictionary).is_empty(), "inverted_elbow_fresh_adapter_reaches_existing_legal_range")
		if not result.get("valid", false): break
	# Returning toward extension must respect the original 12-degree minimum;
	# the previous negative pose is not a lasting extension of anatomical ROM.
	if _signed_elbow_flexion("R") >= minimum:
		var request := _request("R", prop, _orbit(prop.global_transform, Vector3.ZERO, world_axis, deg_to_rad(-0.4)), "tip")
		request["policy"] = {"hold_order_by_mode": {"tip": hold_order}}
		var result := _allocate(request)
		_check(_signed_elbow_flexion("R") >= minimum - 0.000001, "inverted_elbow_recovery_does_not_expand_original_range", result)
	prop.queue_free()

func _signed_elbow_flexion(side: String) -> float:
	var prefix := "CC_Base_" + side + "_"
	var upper := skeleton.find_bone(prefix + "Upperarm")
	var forearm := skeleton.find_bone(prefix + "Forearm")
	var hand := skeleton.find_bone(prefix + "Hand")
	var calibration: Dictionary = Hinge.calibration(skeleton.get_bone_rest(forearm), skeleton.get_bone_rest(hand))
	var u := skeleton.get_bone_global_pose(upper)
	var f := skeleton.get_bone_global_pose(forearm)
	var h := skeleton.get_bone_global_pose(hand)
	var axis := u.basis.orthonormalized() * (calibration.frame_in_upperarm as Basis).x
	var shaft := (f.origin - u.origin).normalized()
	var distal := (h.origin - f.origin).normalized()
	return atan2(axis.dot(shaft.cross(distal)), shaft.dot(distal))

func _shoulder_angle_degrees(side: String) -> float:
	var prefix := "CC_Base_" + side + "_"
	var c := skeleton.get_bone_global_pose(skeleton.find_bone(prefix + "Clavicle")).origin
	var u := skeleton.get_bone_global_pose(skeleton.find_bone(prefix + "Upperarm")).origin
	var f := skeleton.get_bone_global_pose(skeleton.find_bone(prefix + "Forearm")).origin
	return rad_to_deg((c - u).angle_to(f - u))

func _request(side: String, prop: Node3D, target: Transform3D, mode: String) -> Dictionary:
	var result := {"mode": mode, "weapon": prop, "previous_weapon": prop.global_transform, "target_weapon": target,
		"contact_local": Vector3.ZERO, "primary_slot": _slot(side), "commit": true}
	if prop.has_meta("fixture_hand_in_weapon"):
		result["hand_in_weapon_by_slot"] = prop.get_meta("fixture_hand_in_weapon")
	return result

func _elbow_flexion_degrees(side: String) -> float:
	var prefix := "CC_Base_" + side + "_"
	var upper := skeleton.get_bone_global_pose(skeleton.find_bone(prefix + "Upperarm")).origin
	var elbow := skeleton.get_bone_global_pose(skeleton.find_bone(prefix + "Forearm")).origin
	var wrist := skeleton.get_bone_global_pose(skeleton.find_bone(prefix + "Hand")).origin
	return rad_to_deg((elbow - upper).angle_to(wrist - elbow))

func _proximal_spine_poses() -> Dictionary:
	# Follow real rig ancestry: every bone proximal to either clavicle must
	# remain held during Tip. The clavicles themselves remain available.
	var result := {}
	for side: String in ["R", "L"]:
		var index := skeleton.find_bone("CC_Base_" + side + "_Clavicle")
		if index >= 0: index = skeleton.get_bone_parent(index)
		while index >= 0:
			result[index] = skeleton.get_bone_pose(index)
			index = skeleton.get_bone_parent(index)
	return result

func _proximal_spine_unchanged(before: Dictionary) -> bool:
	if before.is_empty(): return false
	for index: int in before:
		var old_pose: Transform3D = before[index]
		var pose := skeleton.get_bone_pose(index)
		if pose.origin.distance_to(old_pose.origin) > 0.0000001 or _basis_error(pose.basis, old_pose.basis) > 0.000001:
			return false
	return true

func _arm_world_poses(side: String) -> Dictionary:
	var result := {}
	var upperarm := skeleton.find_bone("CC_Base_" + side + "_Upperarm")
	for index: int in skeleton.get_bone_count():
		var ancestor := index
		while ancestor >= 0 and ancestor != upperarm:
			ancestor = skeleton.get_bone_parent(ancestor)
		if ancestor == upperarm:
			result[index] = skeleton.global_transform * skeleton.get_bone_global_pose(index)
	return result

func _world_poses_unchanged(before: Dictionary) -> bool:
	if before.is_empty(): return false
	for index: int in before:
		var current := skeleton.global_transform * skeleton.get_bone_global_pose(index)
		var previous: Transform3D = before[index]
		if current.origin.distance_to(previous.origin) > 0.000001 or _basis_error(current.basis, previous.basis) > 0.000001:
			return false
	return true

func _local_positions_unchanged(before: Array[Transform3D]) -> bool:
	for index: int in before.size():
		if skeleton.get_bone_pose_position(index).distance_to(before[index].origin) > 0.0000001:
			return false
	return true

func _orbit(frame: Transform3D, contact: Vector3, axis: Vector3, angle: float) -> Transform3D:
	var basis := Basis(axis.normalized(), angle) * frame.basis
	return Transform3D(basis, frame * contact - basis * contact)

func _slot(side: String) -> StringName:
	return &"hand_left" if side == "L" else &"hand_right"

func _hand_world(side: String) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("CC_Base_" + side + "_Hand"))

func _poses() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for index: int in skeleton.get_bone_count(): result.append(skeleton.get_bone_pose(index))
	return result

func _restore() -> void:
	rig.clear_runtime_solved_replay_pose_frame()
	rig.call("clear_authoring_weapon_motion_authority")
	for index: int in base_poses.size():
		skeleton.set_bone_pose_position(index, base_poses[index].origin)
		skeleton.set_bone_pose_rotation(index, base_poses[index].basis.orthonormalized().get_rotation_quaternion())
		skeleton.set_bone_pose_scale(index, base_poses[index].basis.get_scale())
	skeleton.force_update_all_bone_transforms()

func _poses_close(a: Array[Transform3D], b: Array[Transform3D]) -> bool:
	if a.size() != b.size(): return false
	for index: int in a.size():
		if not _pose_error(a[index], b[index]): return false
	return true

func _pose_error(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) <= POSITION_EPSILON and _basis_error(a.basis, b.basis) <= ANGLE_EPSILON

func _transform_error(a: Transform3D, b: Transform3D) -> Dictionary:
	return {"position_error_m": a.origin.distance_to(b.origin), "orientation_error_degrees": rad_to_deg(_basis_error(a.basis, b.basis))}

func _basis_error(a: Basis, b: Basis) -> float:
	var delta := (a.orthonormalized().get_rotation_quaternion().inverse() * b.orthonormalized().get_rotation_quaternion()).normalized()
	return 2.0 * atan2(Vector3(delta.x, delta.y, delta.z).length(), absf(delta.w))

func _record(label: String, result: Dictionary) -> void:
	var compact := result.duplicate()
	compact.erase("accepted_pose")
	compact.erase("accepted_payload")
	samples.append({"case": label, "result": compact})

func _check(passed: bool, label: String, details: Dictionary = {}) -> void:
	checks.append({"passed": passed, "check": label, "details": details})
	if not passed: push_error("WEAPON_MOTION_RIG " + label + " " + JSON.stringify(details))

func _finish() -> void:
	var passed := true
	for check: Dictionary in checks: passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("rig_report.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "samples": samples,
		"scope": "Imported R/L rig, bent neutral-wrist fixtures, rigid test prop, world-frame transform, constraints, two-hand attachment and shared solved-pose writer. No source save, acquisition, visual or complete station lifecycle certification."}, "\t"))
	file.close()
	print("WEAPON_MOTION_RIG passed=%s checks=%d output=%s" % [passed, checks.size(), output_dir])
	quit(0 if passed else 1)

func _allocate(request: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result: Dictionary = rig.call("allocate_authoring_weapon_motion", request)
	result["elapsed_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	return result
