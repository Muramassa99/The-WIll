extends SceneTree

## Focused body-only contract for the user's Hand-parent X/Z demonstration.
## Uses imported Josie geometry and fixed forearm calibration. No grip search,
## player save, F playback or performance/skin certification.
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const Calibration = preload("res://runtime/player/combat_wrist_rig_calibration.gd")
const Wrist = preload("res://core/resolvers/combat_wrist_motion_resolver.gd")
const Forearm = preload("res://core/resolvers/combat_forearm_rotation_resolver.gd")
const ForearmSkin = preload("res://core/resolvers/combat_forearm_hand_index_resolver.gd")
const Adapter = preload("res://runtime/player/combat_weapon_motion_rig_adapter.gd")
const Independent = preload("res://runtime/player/combat_independent_arm_motion_adapter.gd")
const Allocator = preload("res://core/resolvers/combat_weapon_motion_allocator.gd")
const Presenter = preload("res://runtime/combat/combat_animation_station_preview_presenter.gd")
const MotionNode = preload("res://core/models/combat_animation_motion_node.gd")
const ANGLE_EPSILON := 0.0001
var out_dir := "C:/WORKSPACE/godot_runs/wrist_local_bend_controls"
var checks: Array[Dictionary] = []
var rig: PlayerHumanoidRig
var skeleton: Skeleton3D
var baseline: Array[Transform3D] = []

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			out_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")

func _run() -> void:
	rig = RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.reset_authoring_preview_baseline_pose(&"Idle")
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in rig.find_children("*", "AnimationTree", true, false):
		(node as AnimationTree).active = false
	for node: Node in rig.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).stop(true)
	skeleton = rig.skeleton
	_check(skeleton != null, "real_skeleton_available")
	if skeleton == null:
		_finish()
		return
	for bone: int in skeleton.get_bone_count():
		baseline.append(skeleton.get_bone_pose(bone))
	var profile: Dictionary = rig.wrist_motion_profile.as_dictionary()
	var profile_bytes := var_to_bytes(profile)
	_check(profile.get("bend_frame", "") == "hand_parent_local_xz", "live_profile_uses_hand_parent_axes")
	_check(absf(rad_to_deg(float(profile.flexion_limit_radians)) - 65.0) < 0.00001
		and absf(rad_to_deg(float(profile.extension_limit_radians)) - 35.0) < 0.00001
		and absf(rad_to_deg(float(profile.ulnar_limit_radians)) - 55.0) < 0.00001
		and absf(rad_to_deg(float(profile.radial_limit_radians)) - 55.0) < 0.00001,
		"explicit_user_x_minus65_plus35_z_minus55_plus55")
	for side: String in ["R", "L"]:
		_restore()
		_test_local_axes(side, profile)
		_test_adapter_controls(side)
	_test_green_input_limits(profile)
	_restore()
	_check(profile_bytes == var_to_bytes(rig.wrist_motion_profile.as_dictionary()), "shared_profile_unchanged")
	_finish()

func _test_local_axes(side: String, profile: Dictionary) -> void:
	var slot := _slot(side)
	var calibration: Dictionary = Calibration.build(skeleton, slot)
	_check(calibration.get("valid", false), side + "_real_calibration_valid")
	if not calibration.get("valid", false):
		return
	var calibration_bytes := var_to_bytes(calibration)
	var forearm_index := skeleton.find_bone("CC_Base_" + side + "_Forearm")
	var hand_index := skeleton.find_bone("CC_Base_" + side + "_Hand")
	var forearm := skeleton.get_bone_global_pose(forearm_index)
	var hand := skeleton.get_bone_global_pose(hand_index)
	_check(skeleton.get_bone_parent(hand_index) == forearm_index, side + "_hand_parent_is_forearm")
	var idle := Wrist.measure_state(forearm, hand, calibration, profile, {}, rig.capture_elbow_bend_radians(slot), rig.authoring_elbow_full_flexion_radians())
	_check(idle.get("valid", false) and idle.get("within_limits", false), side + "_actual_idle_wrist_is_legal", _compact(idle))
	var expected_thumb_up := 4.6735436 if side == "R" else -4.672524
	_check(absf(rad_to_deg(float(calibration.forearm_thumb_up_rho_radians)) - expected_thumb_up) < 0.001
		and float(calibration.forearm_pronation_sign) == (-1.0 if side == "R" else 1.0), side + "_forearm_reference_unchanged")
	# The expected world transform is independently constructed from the actual
	# parent frame and the demonstrated single local X or Z rotation.
	for spec: Vector2 in [Vector2(-65, 0), Vector2(0, 0), Vector2(35, 0), Vector2(0, -55), Vector2(0, 55)]:
		var state := _state(0.0, deg_to_rad(spec.x), deg_to_rad(spec.y))
		var expected := _local_target(forearm, hand, spec)
		var label := "%s_x%s_z%s" % [side, spec.x, spec.y]
		var measured := Wrist.measure_state(forearm, expected, calibration, profile)
		_check(measured.get("valid", false) and measured.get("within_limits", false), label + "_measured_legal", _compact(measured))
		_check(_same_state(measured.get("state", {}), state), label + "_no_invented_forearm_roll", measured.get("state", {}))
		var composed := Wrist.compose(forearm, hand, calibration, profile, state)
		_check(composed.get("valid", false) and _basis_error(composed.get("accepted_hand_basis", Basis.IDENTITY), expected.basis) < ANGLE_EPSILON,
			label + "_compose_matches_actual_parent_axis", _compact(composed))
		var resolved := Wrist.resolve(forearm, expected, calibration, profile)
		_check(resolved.get("valid", false) and _same_state(resolved.get("accepted_state", {}), state), label + "_resolve_keeps_requested_axis", _compact(resolved))
		# A global rotation/translation/uniform scale must change no joint angles.
		var placement := Transform3D(Basis.from_euler(Vector3(0.37, -0.63, 0.28)).scaled(Vector3.ONE * 1.25), Vector3(3.0, -1.0, 4.0))
		var placed := Wrist.compose(placement * forearm, placement * hand, calibration, profile, state)
		var placed_target := placement * expected
		_check(placed.get("valid", false)
			and _basis_error(placed.get("accepted_hand_basis", Basis.IDENTITY), placed_target.basis) < ANGLE_EPSILON
			and (placed.get("accepted_hand_basis", Basis.IDENTITY) as Basis).get_scale().distance_to(placed_target.basis.get_scale()) < 0.00001,
			label + "_root_transform_covariant", _compact(placed))
	for spec: Vector2 in [Vector2(-66, 0), Vector2(36, 0), Vector2(0, -56), Vector2(0, 56), Vector2(35, 55)]:
		var state := _state(0.0, deg_to_rad(spec.x), deg_to_rad(spec.y))
		var target := _local_target(forearm, hand, spec)
		var measured := Wrist.measure_state(forearm, target, calibration, profile, state)
		_check(measured.get("valid", false) and not measured.get("within_limits", true), "%s_outside_%s_measured_not_accepted" % [side, spec], _compact(measured))
		var composed := Wrist.compose(forearm, hand, calibration, profile, state)
		_check(not composed.get("valid", true) and composed.get("reason", "") == "wrist_motion_range",
			"%s_outside_%s_compose_rejects" % [side, spec], _compact(composed))
	# Changing the bend frame must not alter the independent pronation/supination
	# calibration or its elbow-conditioned interval.
	var legacy_profile := profile.duplicate(true)
	legacy_profile["bend_frame"] = "rest_anatomical"
	for bend: float in [0.0, 45.0, 90.0, 160.0]:
		var interval := Wrist.forearm_interval(calibration, profile, deg_to_rad(bend))
		var unchanged := Forearm.interval(calibration, legacy_profile, deg_to_rad(bend))
		_check(interval.get("valid", false) and interval == unchanged, "%s_forearm_limits_unchanged_at_%s" % [side, bend])
	_check(calibration_bytes == var_to_bytes(calibration), side + "_fixed_calibration_not_rewritten")

func _test_adapter_controls(side: String) -> void:
	_restore()
	var slot := _slot(side)
	var hand_index := skeleton.find_bone("CC_Base_" + side + "_Hand")
	# Nonzero values prove each control holds the selected node's current angle,
	# rather than silently resetting its other wrist coordinate to zero.
	skeleton.set_bone_pose_rotation(hand_index, (Basis(Vector3.RIGHT, deg_to_rad(10.0)) * Basis(Vector3.BACK, deg_to_rad(12.0))).get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()
	for property: String in ["_wrist_motion_states", "_wrist_motion_failures", "_shoulder_motion_states"]:
		rig.get(property).clear()
	if not _synchronize_fixture_helpers(side):
		return
	var hand_world := skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = hand_world
	for mode: String in ["tip", "pommel", "roll", "pose", "position"]:
		var independent := mode in ["pose", "position"]
		var adapter: Adapter = Independent.new() if independent else Adapter.new()
		var request := {"mode": mode, "primary_slot": slot, "weapon": prop,
			"previous_weapon": hand_world, "target_weapon": hand_world,
			"contact_local": Vector3.ZERO, "hand_in_weapon_by_slot": {slot: Transform3D.IDENTITY}, "commit": false}
		if mode == "position":
			var elbow_index := skeleton.find_bone("CC_Base_" + side + "_Forearm")
			var elbow_world := Transform3D(Basis.IDENTITY, (skeleton.global_transform * skeleton.get_bone_global_pose(elbow_index)).origin)
			request.previous_weapon = elbow_world
			request.target_weapon = elbow_world
			request["fixed_hand_world"] = hand_world
		var initialized := adapter._initialize(rig, request)
		var label := side + "_" + mode
		_check(initialized.get("valid", false), label + "_adapter_initialized", initialized)
		if not initialized.get("valid", false):
			continue
		var arm: Dictionary = adapter.arms[0]
		var w: int = arm.wrist_q
		var beta := w + 1
		var gamma := w + 2
		_check(absf(adapter.q[beta] - deg_to_rad(10.0)) < ANGLE_EPSILON and absf(adapter.q[gamma] - deg_to_rad(12.0)) < ANGLE_EPSILON,
			label + "_captured_nonzero_local_angles", {"beta": adapter.q[beta], "gamma": adapter.q[gamma]})
		_check(_held(adapter, w) if mode == "roll" else adapter.lower[w] < adapter.upper[w], label + "_forearm_control_ownership")
		if mode in ["tip", "pommel"]:
			_check(_held(adapter, gamma) and adapter.lower[beta] < adapter.upper[beta], label + "_holds_z_allows_x")
		elif mode == "roll":
			_check(_held(adapter, beta) and adapter.lower[gamma] < adapter.upper[gamma], label + "_holds_x_allows_z")
			var upstream_held := true
			for index: int in gamma:
				upstream_held = upstream_held and _held(adapter, index)
			_check(upstream_held, label + "_all_upstream_coordinates_held")
		else:
			_check(adapter.lower[beta] < adapter.upper[beta] and adapter.lower[gamma] < adapter.upper[gamma], label + "_independent_keeps_both_bends")
		# One small production FK/allocator task per weapon mode. Other joint
		# bounds are held only in this fixture to isolate the intended wrist axis;
		# this does not certify the full redundant arm search or UI dragging.
		if mode in ["tip", "roll"]:
			_isolated_bend_step(adapter, gamma if mode == "roll" else beta, label)
	_test_shared_roll_bounds(side, prop)
	_test_committed_controls(side, prop)
	_test_green_endpoints(side, prop)
	prop.free()

func _synchronize_fixture_helpers(side: String) -> bool:
	# The fixture just changed Hand from the imported Idle pose to explicit X/Z
	# with rho=0. Idle's authored helper rotations no longer represent that state.
	# Use the unchanged production distribution before taking any movement BEFORE;
	# otherwise the first commit repairs our fixture rather than changing roll.
	var prefix := "CC_Base_" + side + "_"
	var indices: Array[int] = []
	for suffix: String in ["Forearm", "Hand", "ForearmTwist01", "ForearmTwist02"]:
		indices.append(skeleton.find_bone(prefix + suffix))
	var measured: Dictionary = rig.capture_wrist_motion_start_state(_slot(side))
	_check(measured.get("valid", false), side + "_fixture_helper_state_available", _compact(measured))
	if not measured.get("valid", false):
		return false
	var calibration: Dictionary = rig.capture_wrist_constraint_calibration(_slot(side))
	var profile: Dictionary = rig.wrist_motion_profile.as_dictionary()
	var distributed: Dictionary = ForearmSkin.distribute(skeleton.get_bone_global_pose(indices[0]), skeleton.get_bone_global_pose(indices[1]),
		skeleton.get_bone_rest(indices[2]).basis, skeleton.get_bone_rest(indices[3]).basis, skeleton.get_bone_rest(indices[1]).basis,
		Wrist.forearm_geometry_limit(calibration, profile), float(profile.angle_epsilon_radians), float(measured.state.rho))
	_check(distributed.get("valid", false), side + "_fixture_helper_distribution_available", distributed.get("reason", ""))
	if not distributed.get("valid", false):
		return false
	var corrections: Array[Dictionary] = []
	for pair: int in 2:
		var index: int = indices[pair + 2]
		var before := skeleton.get_bone_pose(index)
		var rotation: Quaternion = distributed.proximal_rotation if pair == 0 else distributed.distal_rotation
		skeleton.set_bone_pose_rotation(index, rotation)
		var after := skeleton.get_bone_pose(index)
		corrections.append({"bone": skeleton.get_bone_name(index), "rotation_degrees": rad_to_deg(_basis_error(before.basis, after.basis)),
			"position_error_m": before.origin.distance_to(after.origin), "scale_error": before.basis.get_scale().distance_to(after.basis.get_scale())})
	skeleton.force_update_all_bone_transforms()
	_check(true, side + "_fixture_helpers_match_explicit_semantic_rho_before_test", {"rho": measured.state.rho, "corrections": corrections})
	return true

func _test_shared_roll_bounds(side: String, prop: Node3D) -> void:
	var slot := _slot(side)
	var support := _slot("L" if side == "R" else "R")
	var support_name := "CC_Base_L_Hand" if side == "R" else "CC_Base_R_Hand"
	var support_hand := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(support_name))
	var adapter := Adapter.new()
	var initialized := adapter._initialize(rig, {"mode": "roll", "weapon": prop, "primary_slot": slot,
		"support_slot": support, "previous_weapon": prop.global_transform, "target_weapon": prop.global_transform,
		"contact_local": Vector3.ZERO, "hand_in_weapon_by_slot": {slot: Transform3D.IDENTITY,
			support: prop.global_transform.affine_inverse() * support_hand}, "commit": false})
	_check(initialized.get("valid", false), side + "_shared_roll_initialized", initialized)
	if not initialized.get("valid", false):
		return
	var primary: Dictionary = adapter.arms[0]
	var following: Dictionary = adapter.arms[1]
	var held := true
	for index: int in int(primary.wrist_q) + 2:
		held = held and _held(adapter, index)
	_check(held, side + "_shared_green_keeps_primary_upstream_fixed")
	_check(adapter.lower[following.wrist_q] < adapter.upper[following.wrist_q]
		and adapter.lower[following.wrist_q + 1] < adapter.upper[following.wrist_q + 1]
		and adapter.lower[following.wrist_q + 2] < adapter.upper[following.wrist_q + 2], side + "_shared_support_wrist_can_follow")

func _test_committed_controls(side: String, prop: Node3D) -> void:
	var slot := _slot(side)
	var hand_index := skeleton.find_bone("CC_Base_" + side + "_Hand")
	for mode: String in ["roll", "tip", "pommel"]:
		var hand_world := skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
		prop.global_transform = hand_world
		var request := {"mode": mode, "weapon": prop, "primary_slot": slot,
			"previous_weapon": hand_world, "target_weapon": hand_world, "contact_local": Vector3.ZERO,
			"hand_in_weapon_by_slot": {slot: Transform3D.IDENTITY}, "commit": true}
		var probe := Adapter.new()
		var initialized := probe._initialize(rig, request)
		_check(initialized.get("valid", false), side + "_commit_" + mode + "_initializes", initialized)
		if not initialized.get("valid", false):
			continue
		var arm: Dictionary = probe.arms[0]
		var w: int = arm.wrist_q
		var target := hand_world
		if mode == "pommel":
			target.origin += hand_world.basis.orthonormalized() * Vector3(0.001, 0.002, -0.001)
		else:
			var target_q: PackedFloat64Array = probe.q.duplicate()
			target_q[w + (2 if mode == "roll" else 1)] += deg_to_rad(2.0)
			var evaluated := probe._evaluate_kinematics(target_q)
			_check(evaluated.get("valid", false), side + "_commit_" + mode + "_target_valid")
			if not evaluated.get("valid", false):
				continue
			target = evaluated.weapon_frame
		request.target_weapon = target
		if mode == "roll":
			request["contact_anchor_world"] = hand_world.origin
		var initial_poses: Array[Transform3D] = []
		for bone: int in skeleton.get_bone_count():
			initial_poses.append(skeleton.get_bone_pose(bone))
		var result := Adapter.new().allocate(rig, request)
		var label := side + "_actual_commit_" + mode
		_check(result.get("valid", false) and result.get("status", "") == "ACCEPTED"
			and result.get("commit_readback_valid", false), label + "_accepted",
			{"status": result.get("status"), "reason": result.get("reason"), "task_scale": result.get("task_scale"),
			"commit_readback_valid": result.get("commit_readback_valid")})
		var measured: Dictionary = rig.capture_wrist_motion_start_state(slot)
		var state: Dictionary = measured.get("state", {})
		if mode == "roll":
			_check(absf(float(state.get("gamma", INF)) - probe.q[w + 2] - deg_to_rad(2.0)) <= deg_to_rad(0.025), label + "_z_moved_two_degrees", state)
			_check(absf(float(state.get("beta", INF)) - probe.q[w + 1]) < ANGLE_EPSILON
				and absf(float(state.get("rho", INF)) - probe.q[w]) < ANGLE_EPSILON, label + "_x_and_forearm_stayed_fixed", state)
			var upstream_fixed := true
			var upstream_errors: Array[Dictionary] = []
			for suffix: String in ["Clavicle", "Upperarm", "Forearm", "ForearmTwist01", "ForearmTwist02"]:
				var index := skeleton.find_bone("CC_Base_" + side + "_" + suffix)
				var actual := skeleton.get_bone_pose(index)
				var angle_error := _basis_error(initial_poses[index].basis, actual.basis)
				var position_error := initial_poses[index].origin.distance_to(actual.origin)
				upstream_fixed = upstream_fixed and angle_error < ANGLE_EPSILON and position_error < 0.000001
				upstream_errors.append({"bone": skeleton.get_bone_name(index), "rotation_degrees": rad_to_deg(angle_error),
					"position_error_m": position_error, "scale_error": initial_poses[index].basis.get_scale().distance_to(actual.basis.get_scale())})
			_check(upstream_fixed, label + "_arm_and_helpers_fixed", upstream_errors)
		else:
			_check(absf(float(state.get("gamma", INF)) - probe.q[w + 2]) < ANGLE_EPSILON, label + "_selected_z_retained", state)

func _test_green_endpoints(side: String, prop: Node3D) -> void:
	# Three bounded production commands: positive endpoint, centre, negative
	# endpoint. Each is below the allocator's unchanged 60-degree per-call budget.
	# No resets between commands; both endpoints retain the original fixed limits.
	_restore()
	var slot := _slot(side)
	var hand_index := skeleton.find_bone("CC_Base_" + side + "_Hand")
	skeleton.set_bone_pose_rotation(hand_index, (Basis(Vector3.RIGHT, deg_to_rad(10.0)) * Basis(Vector3.BACK, deg_to_rad(12.0))).get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()
	if not _synchronize_fixture_helpers(side):
		return
	var profile: Dictionary = rig.wrist_motion_profile.as_dictionary()
	var fixed_beta := deg_to_rad(10.0)
	var ellipse_scale := sqrt(1.0 - pow(fixed_beta / float(profile.extension_limit_radians), 2.0))
	var endpoints := [float(profile.radial_limit_radians) * ellipse_scale, 0.0, -float(profile.ulnar_limit_radians) * ellipse_scale]
	var stage_names := ["positive_endpoint", "reverse_to_centre", "negative_endpoint"]
	var initial_poses: Array[Transform3D] = []
	for bone: int in skeleton.get_bone_count():
		initial_poses.append(skeleton.get_bone_pose(bone))
	for step: int in endpoints.size():
		var hand_world := skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
		prop.global_transform = hand_world
		var before: Dictionary = rig.capture_wrist_motion_start_state(slot)
		var state_before: Dictionary = before.get("state", {})
		var delta := float(endpoints[step]) - float(state_before.get("gamma", 0.0))
		var target := Transform3D(hand_world.basis * Basis(Vector3.BACK, delta), hand_world.origin)
		var request := {"mode": "roll", "weapon": prop, "primary_slot": slot,
			"previous_weapon": hand_world, "target_weapon": target, "contact_local": Vector3.ZERO,
			"contact_anchor_world": hand_world.origin, "hand_in_weapon_by_slot": {slot: Transform3D.IDENTITY}, "commit": true}
		var result := Adapter.new().allocate(rig, request)
		var label := side + "_green_full_range_" + String(stage_names[step])
		_check(result.get("valid", false) and result.get("status", "") == "ACCEPTED"
			and result.get("commit_readback_valid", false), label + "_accepted",
			{"status": result.get("status"), "reason": result.get("reason"), "task_scale": result.get("task_scale"),
			"commit_readback_valid": result.get("commit_readback_valid")})
		var measured: Dictionary = rig.capture_wrist_motion_start_state(slot)
		var state: Dictionary = measured.get("state", {})
		_check(absf(float(state.get("gamma", INF)) - float(endpoints[step])) <= deg_to_rad(0.025), label + "_reached_original_target", state)
		_check(absf(float(state.get("beta", INF)) - fixed_beta) < ANGLE_EPSILON
			and absf(float(state.get("rho", INF))) < ANGLE_EPSILON, label + "_x_and_rho_fixed", state)
		var upstream_fixed := true
		var errors: Array[Dictionary] = []
		for suffix: String in ["Clavicle", "Upperarm", "Forearm", "ForearmTwist01", "ForearmTwist02"]:
			var index := skeleton.find_bone("CC_Base_" + side + "_" + suffix)
			var actual := skeleton.get_bone_pose(index)
			var angle_error := _basis_error(initial_poses[index].basis, actual.basis)
			var position_error := initial_poses[index].origin.distance_to(actual.origin)
			upstream_fixed = upstream_fixed and angle_error < ANGLE_EPSILON and position_error < 0.000001
			errors.append({"bone": skeleton.get_bone_name(index), "rotation_degrees": rad_to_deg(angle_error), "position_error_m": position_error})
		_check(upstream_fixed, label + "_upstream_fixed_across_reversal", errors)

func _test_green_input_limits(profile: Dictionary) -> void:
	var presenter := Presenter.new()
	var motion := MotionNode.new()
	for offset: float in [0.0, 275.0, -430.0]:
		for gamma: float in [-30.0, 0.0, 30.0, 50.0]:
			motion.weapon_roll_degrees = offset + gamma
			var limits: Dictionary = presenter._primary_wrist_bend_input_limits(motion,
				{"available": true, "profile": profile, "state": _state(0.0, 0.0, deg_to_rad(gamma))})
			_check(limits.get("available", false) and absf(float(limits.minimum_degrees) - (offset - 55.0)) < 0.00001
				and absf(float(limits.maximum_degrees) - (offset + 55.0)) < 0.00001,
				"green_scalar_offset_does_not_rebase_local_z_%s_%s" % [offset, gamma], limits)
	for gamma: float in [-70.0, 70.0]:
		motion.weapon_roll_degrees = gamma
		var limits: Dictionary = presenter._primary_wrist_bend_input_limits(motion,
			{"available": true, "profile": profile, "state": _state(0.0, 0.0, deg_to_rad(gamma))})
		_check(limits.get("available", false) and absf(float(limits.minimum_degrees) - minf(-55.0, gamma)) < 0.00001
			and absf(float(limits.maximum_degrees) - maxf(55.0, gamma)) < 0.00001,
			"green_invalid_z_allows_inward_only_%s" % gamma, limits)
	motion.weapon_roll_degrees = 0.0
	var half_x: Dictionary = presenter._primary_wrist_bend_input_limits(motion,
		{"available": true, "profile": profile, "state": _state(0.0, deg_to_rad(17.5), 0.0)})
	var expected := 55.0 * sqrt(0.75)
	_check(absf(float(half_x.minimum_degrees) + expected) < 0.00001 and absf(float(half_x.maximum_degrees) - expected) < 0.00001,
		"green_respects_ellipse_at_held_x", half_x)

func _isolated_bend_step(adapter: Adapter, active: int, label: String) -> void:
	var target_q: PackedFloat64Array = adapter.q.duplicate()
	target_q[active] += deg_to_rad(2.0)
	var target := adapter._evaluate_kinematics(target_q)
	_check(target.get("valid", false), label + "_small_target_fk_valid")
	if not target.get("valid", false):
		return
	var input := adapter._allocator_input().duplicate(true)
	input.lower = adapter.q.duplicate()
	input.upper = adapter.q.duplicate()
	input.lower[active] = adapter.lower[active]
	input.upper[active] = adapter.upper[active]
	input.target_weapon = target.weapon_frame
	var result := Allocator.solve(input, Callable(adapter, "_evaluate"), adapter.policy)
	_check(result.get("valid", false) and result.get("status", "") == "ACCEPTED", label + "_small_bend_accepted",
		{"status": result.get("status"), "reason": result.get("reason"), "task_scale": result.get("task_scale")})
	var reached: PackedFloat64Array = result.get("accepted_q", PackedFloat64Array())
	_check(reached.size() == adapter.q.size() and absf(reached[active] - target_q[active]) < deg_to_rad(0.025), label + "_small_bend_reached")

func _held(adapter: Adapter, index: int) -> bool:
	return absf(adapter.lower[index] - adapter.q[index]) < 0.000001 and absf(adapter.upper[index] - adapter.q[index]) < 0.000001

func _local_target(forearm: Transform3D, hand: Transform3D, degrees: Vector2) -> Transform3D:
	return Transform3D(forearm.basis * Basis(Vector3.RIGHT, deg_to_rad(degrees.x)) * Basis(Vector3.BACK, deg_to_rad(degrees.y)), hand.origin)

func _state(rho: float, beta: float, gamma: float) -> Dictionary:
	return {"rho": rho, "beta": beta, "gamma": gamma}

func _same_state(actual: Dictionary, expected: Dictionary) -> bool:
	for field: String in ["rho", "beta", "gamma"]:
		if absf(float(actual.get(field, INF)) - float(expected[field])) > ANGLE_EPSILON:
			return false
	return true

func _basis_error(a: Basis, b: Basis) -> float:
	var q := (a.orthonormalized().get_rotation_quaternion().inverse() * b.orthonormalized().get_rotation_quaternion()).normalized()
	return 2.0 * atan2(Vector3(q.x, q.y, q.z).length(), absf(q.w))

func _slot(side: String) -> StringName:
	return &"hand_right" if side == "R" else &"hand_left"

func _restore() -> void:
	for bone: int in baseline.size():
		var pose: Transform3D = baseline[bone]
		skeleton.set_bone_pose_position(bone, pose.origin)
		skeleton.set_bone_pose_rotation(bone, pose.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(bone, pose.basis.get_scale())
	skeleton.force_update_all_bone_transforms()
	for property: String in ["_wrist_motion_states", "_wrist_motion_failures", "_shoulder_motion_states"]:
		rig.get(property).clear()

func _compact(result: Dictionary) -> Dictionary:
	return {"valid": result.get("valid"), "status": result.get("status"), "reason": result.get("reason"),
		"state": result.get("state", result.get("accepted_state", {})), "within_limits": result.get("within_limits"),
		"orientation_error_radians": result.get("orientation_error_radians")}

func _check(passed: bool, name: String, details: Variant = null) -> void:
	checks.append({"passed": passed, "name": name, "details": details})
	if not passed:
		push_error("WRIST_LOCAL_BEND " + name + " " + str(details))

func _finish() -> void:
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks,
		"scope": "Imported Josie local wrist X/Z, fixed forearm interval, transform covariance and control-specific adapter bounds; body only. No grip, player save, F, skin or UI performance certification."}, "\t"))
	file.close()
	print("WRIST_LOCAL_BEND passed=%s checks=%d" % [passed, checks.size()])
	quit(0 if passed else 1)
