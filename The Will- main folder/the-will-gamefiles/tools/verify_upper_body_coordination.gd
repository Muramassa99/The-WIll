extends "res://tools/verify_combat_weapon_motion_rig.gd"

## Seven imported-rig fixtures. Reuses setup/math helpers, never the parent's
## saved-writer or full lifecycle tests. No library, grip or animation changes.
const IndependentAdapter = preload("res://runtime/player/combat_independent_arm_motion_adapter.gd")
const ClavicleMotion = preload("res://core/resolvers/combat_clavicle_motion_resolver.gd")
var baseline_wrist_states: Dictionary = {}
var baseline_shoulder_states: Dictionary = {}
var baseline_wrist_failures: Dictionary = {}
var legacy_clavicle_pose := Transform3D.IDENTITY

func _initialize() -> void:
	output_dir = "C:/WORKSPACE/godot_runs/upper_body_coordination"
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
	_check(skeleton != null, "coordination_imported_skeleton_available")
	if skeleton == null:
		_finish()
		return
	legacy_clavicle_pose = skeleton.get_bone_rest(skeleton.find_bone("CC_Base_R_Clavicle"))
	# The user-confirmed Idle quaternion, not imported rest, is the fixed home.
	# Verify actual Reset already matches it before preparing the bent fixture.
	var profile: Dictionary = rig.shoulder_motion_profile.as_dictionary()
	for side: String in ["R", "L"]:
		var index: int = skeleton.find_bone("CC_Base_" + side + "_Clavicle")
		var rest: Transform3D = skeleton.get_bone_rest(index)
		var rotation: Quaternion = profile.clavicle_reference_rotations_by_slot[_slot(side)]
		_check(_basis_error(skeleton.get_bone_pose(index).basis, Basis(rotation)) < deg_to_rad(0.001), side + "_actual_reset_idle_matches_fixed_home")
		skeleton.set_bone_pose_rotation(index, rotation)
		skeleton.set_bone_pose_scale(index, rest.basis.get_scale())
	skeleton.force_update_all_bone_transforms()
	(rig.get("_wrist_motion_states") as Dictionary).clear()
	(rig.get("_shoulder_motion_states") as Dictionary).clear()
	for side: String in ["R", "L"]:
		_seed_bent_neutral_wrist(side)
	base_poses = _poses()
	baseline_wrist_states = (rig.get("_wrist_motion_states") as Dictionary).duplicate(true)
	baseline_shoulder_states = (rig.get("_shoulder_motion_states") as Dictionary).duplicate(true)
	baseline_wrist_failures = (rig.get("_wrist_motion_failures") as Dictionary).duplicate(true)
	for side: String in ["R", "L"]:
		var initial: Dictionary = _clavicle_measures()[side]
		_check(initial.get("valid", false) and float(initial.constraint) <= 0.0, side + "_fresh_fixture_starts_inside_clavicle_cone")
	for side: String in ["R", "L"]:
		var identity: Dictionary = _independent_fixture(side, false)
		var transformed: Dictionary = _independent_fixture(side, true)
		if identity.has("after_hand") and transformed.has("after_hand"):
			_check(_root_relative_agreement(identity.after_hand, transformed.after_hand), side + "_free_hand_root_transform_equivalence", _transform_error(identity.after_hand, transformed.after_hand))
		if identity.has("after_elbow") and transformed.has("after_elbow"):
			# Elbow task controls its position, not Forearm orientation. The
			# second task is the held Hand frame. Its input already carries the
			# preceding free-hand solve's measured cross-root discrepancy.
			var error := _transform_error(identity.after_elbow, transformed.after_elbow)
			var inherited_angle: float = _basis_error(identity.after_hand.basis, transformed.after_hand.basis)
			error.allowed_orientation_degrees = rad_to_deg(ANGLE_EPSILON * 2.0 + inherited_angle)
			error.unconstrained_forearm_orientation_error_degrees = rad_to_deg(_basis_error(identity.forearm_frame.basis, transformed.forearm_frame.basis))
			_check(float(error.position_error_m) <= POSITION_EPSILON * 2.0 and float(error.orientation_error_degrees) <= float(error.allowed_orientation_degrees), side + "_elbow_position_and_held_hand_root_equivalence", error)
	_handoff_fixture()
	_shared_fixture()
	_legacy_fixture()
	_finish()

func _restore() -> void:
	# Parent restore only restores bones. Semantic branch/hold state must belong
	# to those same bones, rather than leaking from the preceding fixture.
	for slot: StringName in [&"hand_right", &"hand_left"]:
		rig.clear_arm_guidance_target(slot)
		rig.clear_arm_guidance_active(slot)
	rig.clear_upper_body_authoring_state()
	super._restore()
	rig.set("_wrist_motion_states", baseline_wrist_states.duplicate(true))
	rig.set("_shoulder_motion_states", baseline_shoulder_states.duplicate(true))
	rig.set("_wrist_motion_failures", baseline_wrist_failures.duplicate(true))

func _independent_fixture(side: String, transformed: bool) -> Dictionary:
	_restore()
	actor_parent.transform = Transform3D(Basis.from_euler(Vector3(0.2, -0.6, 0.1)) * Basis.from_scale(Vector3.ONE * 1.7), Vector3(2.0, 1.0, -3.0)) if transformed else Transform3D.IDENTITY
	var label := side + ("_transformed_scaled" if transformed else "_identity")
	var other := "L" if side == "R" else "R"
	var opposite := _arm_world_poses(other)
	var ancestors := _proximal_spine_poses()
	var locals := _poses()
	var clavicle_before := _clavicle_measures()
	var before: Transform3D = _hand_world(side)
	# An independently constructed reachable hand frame: a tiny hinge bend
	# around the actual imported material axis, with no arbitrary scene pole.
	var elbow: Vector3 = _joint_world(side, "Forearm").origin
	var upper: Transform3D = _joint_world(side, "Upperarm")
	var prefix := "CC_Base_" + side + "_"
	var f := skeleton.find_bone(prefix + "Forearm")
	var h := skeleton.find_bone(prefix + "Hand")
	var hinge: Dictionary = Hinge.calibration(skeleton.get_bone_rest(f), skeleton.get_bone_rest(h))
	var axis: Vector3 = (upper.basis.orthonormalized() * (hinge.frame_in_upperarm as Basis).x).normalized()
	var turn := Basis(axis, deg_to_rad(1.5))
	var target := Transform3D(turn * before.basis, elbow + turn * (before.origin - elbow))
	var result: Dictionary = IndependentAdapter.new().move_hand(rig, _slot(side), target)
	_record(label + "_free_hand", result)
	var actual: Transform3D = _hand_world(side)
	_check(result.get("valid", false) and _pose_error(actual, target), label + "_free_hand_reaches_real_target", _transform_error(actual, target))
	_check(actual.origin.distance_to(before.origin) > 0.0005, label + "_free_hand_positive_travel", {"travel_m": actual.origin.distance_to(before.origin)})
	_check(_world_poses_unchanged(opposite) and _proximal_spine_unchanged(ancestors), label + "_free_hand_keeps_opposite_and_root_chain")
	_check(_local_positions_unchanged(locals), label + "_free_hand_preserves_bone_lengths")
	_check_clavicles(clavicle_before, label + "_free_hand")
	var record := {"after_hand": _machine_frame().affine_inverse() * actual}
	if not result.get("valid", false):
		return record
	# Swivel the elbow about the real shoulder-to-hand axis, preserving the
	# already accepted Hand world frame in both translation and orientation.
	var held: Transform3D = actual
	var shoulder: Vector3 = _joint_world(side, "Upperarm").origin
	var old_elbow: Vector3 = _joint_world(side, "Forearm").origin
	var swivel_axis := (held.origin - shoulder).normalized()
	var amount: float = deg_to_rad(1.5 if side == "R" else -1.5)
	var target_elbow: Vector3 = shoulder + Basis(swivel_axis, amount) * (old_elbow - shoulder)
	clavicle_before = _clavicle_measures()
	result = IndependentAdapter.new().move_elbow(rig, _slot(side), target_elbow)
	_record(label + "_elbow", result)
	var accepted_elbow: Vector3 = _joint_world(side, "Forearm").origin
	_check(result.get("valid", false) and accepted_elbow.distance_to(target_elbow) <= POSITION_EPSILON, label + "_elbow_reaches_real_target", {"target_error_m": accepted_elbow.distance_to(target_elbow)})
	_check(accepted_elbow.distance_to(old_elbow) > 0.0002, label + "_elbow_positive_travel", {"travel_m": accepted_elbow.distance_to(old_elbow)})
	_check(_pose_error(_hand_world(side), held), label + "_elbow_holds_hand_50um_0025deg", _transform_error(_hand_world(side), held))
	_check(_world_poses_unchanged(opposite) and _proximal_spine_unchanged(ancestors), label + "_elbow_keeps_opposite_and_root_chain")
	_check(_local_positions_unchanged(locals), label + "_elbow_preserves_bone_lengths")
	_check_clavicles(clavicle_before, label + "_elbow")
	var root_inverse := _machine_frame().affine_inverse()
	record.forearm_frame = root_inverse * _joint_world(side, "Forearm")
	var final_hand: Transform3D = root_inverse * _hand_world(side)
	record.after_elbow = Transform3D(final_hand.basis, root_inverse * accepted_elbow)
	_large_elbow_sweeps(side, label)
	return record

func _large_elbow_sweeps(side: String, label: String) -> void:
	# Actual rig entry retains one Hand pin across repeated elbow requests.
	# Large inputs expose path/limit issues tiny1.5-degree inputs can conceal.
	# Partial legal progress is reported rather than called a full20-degree move.
	var original_hand := _hand_world(side)
	var opposite := _arm_world_poses("L" if side == "R" else "R")
	var ancestors := _proximal_spine_poses()
	var locals := _poses()
	var original_clavicles := _clavicle_measures()
	var profile_before: PackedByteArray = var_to_bytes(rig.shoulder_motion_profile.as_dictionary())
	var sign_value := 1.0 if side == "R" else -1.0
	var slot := _slot(side)
	var guidance := Node3D.new()
	root.add_child(guidance)
	guidance.global_position = _guidance_center_world(side)
	rig.set_arm_guidance_target(slot, guidance)
	rig.set_arm_guidance_active(slot, true)
	for step: int in 3:
		var before_hand := _hand_world(side)
		var shoulder: Vector3 = _joint_world(side, "Upperarm").origin
		var before_elbow: Vector3 = _joint_world(side, "Forearm").origin
		var axis := (before_hand.origin - shoulder).normalized()
		var angle: float = deg_to_rad(20.0 * sign_value * (-1.0 if step == 1 else 1.0))
		var target: Vector3 = shoulder + Basis(axis, angle) * (before_elbow - shoulder)
		var control: Dictionary = rig.get_authoring_upperarm_roll_control_state(slot)
		_check(not control.is_empty(), label + "_large_elbow_" + str(step) + "_control_reference_exists")
		if control.is_empty():
			break
		var state: Dictionary = rig.get_upper_body_authoring_state()
		var roll_key := "left_upperarm_roll_degrees" if side == "L" else "right_upperarm_roll_degrees"
		state[roll_key] = wrapf(float(control.initial_roll_degrees) + rad_to_deg(angle), -180.0, 180.0)
		rig.set_upper_body_authoring_state(state)
		var result: Dictionary = rig.apply_authoring_independent_arm_frame_now(slot, true, false)
		var after_elbow: Vector3 = _joint_world(side, "Forearm").origin
		var start_radius: Vector3 = before_elbow - shoulder
		var end_radius: Vector3 = after_elbow - shoulder
		start_radius -= axis * start_radius.dot(axis)
		end_radius -= axis * end_radius.dot(axis)
		var accepted_angle: float = atan2(axis.dot(start_radius.cross(end_radius)), start_radius.dot(end_radius))
		result["requested_swivel_degrees"] = rad_to_deg(angle)
		result["measured_swivel_degrees"] = rad_to_deg(accepted_angle)
		result["elbow_travel_m"] = after_elbow.distance_to(before_elbow)
		result["final_target_error_m"] = after_elbow.distance_to(target)
		result["hand_drift_from_first_sweep"] = _transform_error(_hand_world(side), original_hand)
		result["hand_delta_from_previous_sweep"] = _transform_error(_hand_world(side), before_hand)
		_record(label + "_large_elbow_" + str(step), result)
		_check(result.get("valid", false) and after_elbow.distance_to(before_elbow) > 0.0002 and accepted_angle * angle > 0.0, label + "_large_elbow_" + str(step) + "_positive_requested_direction", {"accepted_degrees": rad_to_deg(accepted_angle), "requested_degrees": rad_to_deg(angle), "task_scale": result.get("task_scale", 0.0), "reason": result.get("reason", "")})
		_check(_pose_error(_hand_world(side), original_hand), label + "_large_elbow_" + str(step) + "_retained_original_hand_pin", _transform_error(_hand_world(side), original_hand))
		var retained_pin: Dictionary = rig.get("_independent_arm_hand_pin")
		_check(retained_pin.has("frame_world") and (retained_pin.frame_world as Transform3D).is_equal_approx(original_hand), label + "_large_elbow_" + str(step) + "_pin_reference_does_not_ratchet")
		_check(_world_poses_unchanged(opposite) and _proximal_spine_unchanged(ancestors) and _local_positions_unchanged(locals), label + "_large_elbow_" + str(step) + "_opposite_root_and_lengths_held")
		_check_clavicles(original_clavicles, label + "_large_elbow_" + str(step))
	_check(profile_before == var_to_bytes(rig.shoulder_motion_profile.as_dictionary()), label + "_large_elbow_regrab_does_not_change_profile_limits")
	samples.append({"case": label + "_large_elbow_cumulative_hand_drift", "measurement": _transform_error(_hand_world(side), original_hand), "contract": "Three actual rig elbow-entry requests retain the first Hand world frame; cumulative50um/.025deg pin is asserted."})
	rig.clear_arm_guidance_target(slot)
	rig.clear_arm_guidance_active(slot)
	guidance.free()

func _handoff_fixture() -> void:
	_restore()
	actor_parent.transform = Transform3D.IDENTITY
	var opposite := _arm_world_poses("L")
	var ancestors := _proximal_spine_poses()
	var locals := _poses()
	var clavicle_before := _clavicle_measures()
	var guidance := Node3D.new()
	root.add_child(guidance)
	var hand_before: Transform3D = _hand_world("R")
	var desired_delta: Vector3 = _machine_frame().basis * Vector3(0.002, 0.003, -0.002)
	guidance.global_position = _guidance_center_world("R") + desired_delta
	rig.set_arm_guidance_target(&"hand_right", guidance)
	rig.set_arm_guidance_active(&"hand_right", true)
	var independent: Dictionary = rig.apply_authoring_independent_arm_frame_now(&"hand_right")
	_record("handoff_first_independent_entry", independent)
	_check_requested_hand_delta(independent, hand_before, desired_delta, "handoff_first")
	_check(independent.get("valid", false) and _hand_world("R").origin.distance_to(hand_before.origin) > 0.0002, "handoff_independent_entry_moves_hand")
	_check(rig.has_authoring_independent_arm_pose_authority(&"hand_right"), "handoff_independent_entry_retains_authority")
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = _hand_world("R") * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	var binding: Transform3D = prop.global_transform.affine_inverse() * _hand_world("R")
	prop.set_meta("fixture_hand_in_weapon", {&"hand_right": binding})
	var before: Transform3D = prop.global_transform
	var target := _orbit(before, Vector3.ZERO, _hand_world("R").basis.x.normalized(), deg_to_rad(1.0))
	var result: Dictionary = _allocate(_request("R", prop, target, "tip"))
	_record("handoff_weapon_tip", result)
	_check(result.get("valid", false) and _basis_error(prop.global_basis, before.basis) > deg_to_rad(0.1), "handoff_tip_has_actual_motion")
	_check(_pose_error(prop.global_transform * binding, _hand_world("R")), "handoff_tip_keeps_existing_binding")
	_check(rig.has_authoring_weapon_motion_authority() and not rig.has_authoring_independent_arm_pose_authority(), "handoff_weapon_authority_replaces_independent")
	before = prop.global_transform
	target = before
	target.origin += _machine_frame().basis * Vector3(0.002, 0.002, 0.0)
	result = _allocate(_request("R", prop, target, "pommel"))
	_record("handoff_weapon_pommel", result)
	_check(result.get("valid", false) and prop.global_position.distance_to(before.origin) > 0.0002, "handoff_pommel_has_actual_motion")
	_check(_pose_error(prop.global_transform * binding, _hand_world("R")), "handoff_pommel_keeps_existing_binding")
	# Free hand owns no prop attachment. This is a control-family handoff test,
	# not a claim that an independently moved hand can retain an equipped prop.
	hand_before = _hand_world("R")
	desired_delta = _machine_frame().basis * Vector3(-0.002, 0.002, 0.002)
	guidance.global_position = _guidance_center_world("R") + desired_delta
	independent = rig.apply_authoring_independent_arm_frame_now(&"hand_right")
	_record("handoff_last_independent_entry", independent)
	_check_requested_hand_delta(independent, hand_before, desired_delta, "handoff_last")
	_check(independent.get("valid", false) and _hand_world("R").origin.distance_to(hand_before.origin) > 0.0002, "handoff_return_to_independent_moves_hand")
	_check(not rig.has_authoring_weapon_motion_authority() and rig.has_authoring_independent_arm_pose_authority(&"hand_right"), "handoff_independent_replaces_weapon_authority")
	_check(_world_poses_unchanged(opposite) and _proximal_spine_unchanged(ancestors), "handoff_keeps_opposite_and_root_chain")
	_check(_local_positions_unchanged(locals), "handoff_preserves_bone_lengths")
	_check_clavicles(clavicle_before, "handoff")
	rig.clear_arm_guidance_target(&"hand_right")
	guidance.free()
	prop.free()

func _shared_fixture() -> void:
	_restore()
	actor_parent.transform = Transform3D.IDENTITY
	var locals := _poses()
	var clavicle_before := _clavicle_measures()
	var primary := _hand_world("R")
	var support := _hand_world("L")
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = primary * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	var right_binding := prop.global_transform.affine_inverse() * primary
	var left_binding := prop.global_transform.affine_inverse() * support
	prop.set_meta("fixture_hand_in_weapon", {&"hand_right": right_binding, &"hand_left": left_binding})
	var target := prop.global_transform
	target.origin += _machine_frame().basis * Vector3(0.0, 0.002, -0.001)
	var request := _request("R", prop, target, "pommel")
	request.support_slot = &"hand_left"
	var result: Dictionary = _allocate(request)
	_record("shared_two_hand_pommel", result)
	_check(result.get("valid", false), "shared_two_hand_accepts_small_move")
	_check(_hand_world("R").origin.distance_to(primary.origin) > 0.0002 and _hand_world("L").origin.distance_to(support.origin) > 0.0002, "shared_two_hand_actually_moves_both_hands")
	_check(_pose_error(_hand_world("R"), prop.global_transform * right_binding), "shared_two_hand_primary_contact", _transform_error(_hand_world("R"), prop.global_transform * right_binding))
	_check(_pose_error(_hand_world("L"), prop.global_transform * left_binding), "shared_two_hand_support_contact", _transform_error(_hand_world("L"), prop.global_transform * left_binding))
	_check(_local_positions_unchanged(locals), "shared_two_hand_preserves_bone_lengths")
	_check_clavicles(clavicle_before, "shared_two_hand")
	prop.free()

func _legacy_fixture() -> void:
	_restore()
	actor_parent.transform = Transform3D.IDENTITY
	var clavicle: int = skeleton.find_bone("CC_Base_R_Clavicle")
	skeleton.set_bone_pose_rotation(clavicle, legacy_clavicle_pose.basis.orthonormalized().get_rotation_quaternion())
	skeleton.set_bone_pose_scale(clavicle, legacy_clavicle_pose.basis.get_scale())
	skeleton.force_update_all_bone_transforms()
	# Imported rest was the previous implementation's home. Keep that real
	# reference as the inherited-error fixture; it is distinct from current Idle.
	var before_clavicles := _clavicle_measures()
	_check(float(before_clavicles.R.constraint) > 0.0, "legacy_imported_rest_has_existing_idle_cone_excess", before_clavicles.R)
	(rig.get("_wrist_motion_states") as Dictionary).erase(&"hand_right")
	(rig.get("_shoulder_motion_states") as Dictionary).erase(&"hand_right")
	var hand := _hand_world("R")
	var elbow := _joint_world("R", "Forearm")
	var upper := _joint_world("R", "Upperarm")
	var f := skeleton.find_bone("CC_Base_R_Forearm")
	var h := skeleton.find_bone("CC_Base_R_Hand")
	var hinge: Dictionary = Hinge.calibration(skeleton.get_bone_rest(f), skeleton.get_bone_rest(h))
	var axis: Vector3 = (upper.basis.orthonormalized() * (hinge.frame_in_upperarm as Basis).x).normalized()
	var turn := Basis(axis, deg_to_rad(1.0))
	var target := Transform3D(turn * hand.basis, elbow.origin + turn * (hand.origin - elbow.origin))
	var opposite := _arm_world_poses("L")
	var locals := _poses()
	var result: Dictionary = IndependentAdapter.new().move_hand(rig, &"hand_right", target)
	_record("legacy_imported_rest_nonworsening_independent_move", result)
	_check(result.get("valid", false) and _hand_world("R").origin.distance_to(hand.origin) > 0.0002, "legacy_imported_rest_has_actual_corrective_editability")
	_check_clavicles(before_clavicles, "legacy_imported_rest")
	_check(_world_poses_unchanged(opposite) and _local_positions_unchanged(locals), "legacy_imported_rest_keeps_opposite_and_bone_lengths")

func _clavicle_measures() -> Dictionary:
	var result := {}
	var profile: Dictionary = rig.shoulder_motion_profile.as_dictionary()
	for side: String in ["R", "L"]:
		var name := StringName("CC_Base_" + side + "_Clavicle")
		var index: int = skeleton.find_bone(String(name))
		var child: int = skeleton.find_bone("CC_Base_" + side + "_Upperarm")
		var rotation: Quaternion = profile.clavicle_reference_rotations_by_slot[_slot(side)]
		var calibration := ClavicleMotion.calibrate(skeleton.get_bone_rest(index), skeleton.get_bone_rest(child), name, Basis(rotation))
		result[side] = ClavicleMotion.measure(skeleton.get_bone_pose(index), calibration, float(profile.clavicle_swing_half_angle_degrees))
	return result

func _check_clavicles(before: Dictionary, label: String) -> void:
	var after := _clavicle_measures()
	for side: String in ["R", "L"]:
		var prior: Dictionary = before[side]
		var current: Dictionary = after[side]
		_check(prior.get("valid", false) and current.get("valid", false), label + "_" + side + "_clavicle_readable")
		if not prior.get("valid", false) or not current.get("valid", false):
			continue
		_check(float(current.constraint) <= maxf(0.0, float(prior.constraint)) + 0.00001, label + "_" + side + "_cone_or_original_nonworsening_allowance", {"before_excess_radians": prior.constraint, "after_excess_radians": current.constraint})
		_check(absf(wrapf(float(current.twist) - float(prior.twist), -PI, PI)) <= ANGLE_EPSILON, label + "_" + side + "_clavicle_adds_no_axial_roll")

func _joint_world(side: String, bone: String) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("CC_Base_" + side + "_" + bone))

func _guidance_center_world(side: String) -> Vector3:
	# Match TwoHandPoseSolver's grip-centre -> Hand-origin conversion. Feeding
	# a Hand origin as a palm target accidentally requests an extra~8cm move.
	var slot := _slot(side)
	var aligned: Vector3 = rig.resolve_hand_grip_alignment_world_position(slot)
	if aligned.is_finite() and aligned.length_squared() > 0.000001:
		return aligned
	var dominant := StringName(rig.get("dominant_grip_slot_id"))
	if dominant == StringName():
		dominant = &"hand_right"
	var anchor: Node3D = rig.get_left_hand_item_anchor() if side == "L" else rig.get_right_hand_item_anchor()
	if slot == dominant and is_instance_valid(anchor):
		return anchor.global_position
	return _hand_world(side).origin

func _check_requested_hand_delta(result: Dictionary, before: Transform3D, desired_delta: Vector3, label: String) -> void:
	_check(result.get("requested_hand_world") is Transform3D, label + "_requested_hand_frame_reported")
	if not result.get("requested_hand_world") is Transform3D:
		return
	var requested: Transform3D = result.requested_hand_world
	var actual_delta: Vector3 = requested.origin - before.origin
	_check(actual_delta.length() > 0.0001 and actual_delta.length() < 0.01 and actual_delta.distance_to(desired_delta) <= POSITION_EPSILON, label + "_guidance_requests_intended_few_mm", {"requested_delta_world": actual_delta, "intended_delta_world": desired_delta, "mapping_error_m": actual_delta.distance_to(desired_delta)})

func _machine_frame() -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("RL_BoneRoot"))

func _root_relative_agreement(a: Transform3D, b: Transform3D) -> bool:
	# Position tolerances are world metres, so a scaled rig can stop at a
	# different sub-tolerance local point. Compare within two output tolerances.
	return a.origin.distance_to(b.origin) <= POSITION_EPSILON * 2.0 and _basis_error(a.basis, b.basis) <= ANGLE_EPSILON * 2.0

func _record(label: String, result: Dictionary) -> void:
	var compact: Dictionary = result.duplicate()
	for key: String in ["accepted_pose", "accepted_payload", "motion_adapter"]:
		compact.erase(key)
	samples.append({"case": label, "result": compact})

func _finish() -> void:
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var report := FileAccess.open(output_dir.path_join("coordination_report.json"), FileAccess.WRITE)
	if report == null:
		quit(1)
		return
	report.store_string(JSON.stringify({"passed": passed, "checks": checks, "samples": samples,
		"scope": "Seven actual imported-rig body fixtures: fixed-Idle-cone independent hand/elbow,20-degree reverse/regrab sweeps, root transforms, control-family handoff, shared two-hand contacts, and previous imported-rest reference outside the Idle cone. Elbow task constrains elbow position and held Hand, not full Forearm orientation. No Save/F, library, grip acquisition, UI smoothness or collision certification."}, "\t"))
	report.close()
	print("UPPER_BODY_COORDINATION passed=%s checks=%d output=%s" % [passed, checks.size(), output_dir])
	quit(0 if passed else 1)
