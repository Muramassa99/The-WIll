extends SceneTree

## Focused real-rig and value checks. No station, acquisition, player Save, or
## anatomical/skin-quality claim. Optional --source reads a library directly.
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const Indexer = preload("res://core/resolvers/combat_forearm_hand_index_resolver.gd")
const PreparedArm = preload("res://core/resolvers/combat_prepared_arm_frame_resolver.gd")
const HingeFrame = preload("res://core/resolvers/combat_arm_hinge_frame_resolver.gd")
const ANGLE_EPSILON := deg_to_rad(0.03)
const POSITION_EPSILON := 0.00001
var out_dir := "C:/WORKSPACE/godot_runs/forearm_hand_indexing"
var source_path := ""
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var rig: PlayerHumanoidRig
var sk: Skeleton3D
var baseline: Array[Transform3D] = []

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			out_dir = argument.trim_prefix("--out-dir=")
		elif argument.begins_with("--source="):
			source_path = argument.trim_prefix("--source=")
	call_deferred("_run")

func _run() -> void:
	rig = RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	# Preview enable alone can reuse the empty animation-name sentinel without
	# establishing the baseline caches. Use the same reset as the real editor.
	rig.reset_authoring_preview_baseline_pose()
	rig.set_process(false)
	rig.set_physics_process(false)
	for tree: Node in rig.find_children("*", "AnimationTree", true, false):
		(tree as AnimationTree).active = false
	sk = rig.get_node("JosieModel/Josie/Skeleton3D") as Skeleton3D
	var ready := sk != null
	var missing: Array[String] = []
	for side: String in ["R", "L"]:
		for suffix: String in ["Clavicle", "Upperarm", "Forearm", "Hand", "ForearmTwist01", "ForearmTwist02"]:
			var name := StringName("CC_Base_" + side + "_" + suffix)
			if sk == null or sk.find_bone(name) < 0:
				missing.append(String(name))
				ready = false
			if suffix.begins_with("ForearmTwist") and not rig.authoring_limb_twist_neutral_rotation_lookup.has(name):
				missing.append(String(name) + " neutral")
				ready = false
	_check(ready, "real_baseline_bones_and_neutral_caches_ready", {"missing": missing})
	if not ready:
		_finish()
		return
	for side: String in ["R", "L"]:
		var p := "CC_Base_" + side + "_"
		rig.call("_enforce_authoring_upperarm_swing_authority", _slot(side), StringName(p + "Clavicle"), StringName(p + "Upperarm"), StringName(p + "Forearm"), StringName(p + "Hand"))
	baseline = _poses()
	for side: String in ["R", "L"]:
		_observe_existing_hinge_normalization(side)
	_restore()
	# The imported idle arm is nearly straight. Its existing hinge calculation
	# is a separate numerical sensitivity, so wrist invariants use an explicit
	# bent fixture on the actual bones rather than weakening their tolerances.
	for side: String in ["R", "L"]:
		_set_fixture_bend(side, 60.0)
	baseline = _poses()
	for side: String in ["R", "L"]:
		_exercise_values(side)
		_exercise_prepared(side)
		_exercise_live_writer(side)
	_exercise_cold_replay()
	_exercise_invalid()
	if not source_path.is_empty():
		_exercise_saved_source()
	_finish()

func _finish() -> void:
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot create forearm indexing report")
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "samples": samples,
		"scope": "Real imported L/R indexing, existing caps, retained tilt/main poses, prepared/live adapters and optional immutable saved-pose observations. No full grip or gameplay lifecycle certification."}, "\t"))
	file.close()
	print("FOREARM_HAND_INDEXING passed=%s checks=%d output=%s" % [passed, checks.size(), out_dir])
	quit(0 if passed else 1)

func _fixture(side: String) -> Dictionary:
	var p := "CC_Base_" + side + "_"
	var f: int = sk.find_bone(p + "Forearm")
	var h: int = sk.find_bone(p + "Hand")
	var a: int = sk.find_bone(p + "ForearmTwist01")
	var b: int = sk.find_bone(p + "ForearmTwist02")
	var neutrals: Dictionary = rig.authoring_limb_twist_neutral_rotation_lookup
	return {"f": f, "h": h, "a": a, "b": b,
		"forearm": sk.get_bone_global_pose(f), "hand": sk.get_bone_global_pose(h),
		"proximal_rest": sk.get_bone_rest(a).basis, "distal_rest": sk.get_bone_rest(b).basis,
		"hand_rest": sk.get_bone_rest(h).basis,
		"proximal_neutral": neutrals[StringName(p + "ForearmTwist01")], "distal_neutral": neutrals[StringName(p + "ForearmTwist02")],
		"cap": rig.AUTHORING_LIMB_TWIST_LIMIT_RADIANS, "epsilon": deg_to_rad(rig.AUTHORING_JOINT_RANGE_EPSILON_DEGREES)}

func _solve(f: Dictionary, forearm: Transform3D, hand: Transform3D) -> Dictionary:
	return Indexer.resolve(forearm, hand, f.proximal_rest, f.distal_rest, f.hand_rest,
		f.proximal_neutral, f.distal_neutral, f.cap, f.epsilon)

func _desired(f: Dictionary, degrees: float, tilt_degrees: float = 25.0) -> Transform3D:
	var neutral: Dictionary = Indexer.neutral_hand_basis(f.forearm.basis, f.proximal_rest, f.distal_rest, f.hand_rest, f.proximal_neutral, f.distal_neutral)
	var axis: Vector3 = (f.hand.origin - f.forearm.origin).normalized()
	var tilt_axis: Vector3 = f.forearm.basis.x - axis * f.forearm.basis.x.dot(axis)
	var basis: Basis = Basis(tilt_axis.normalized(), deg_to_rad(tilt_degrees)) * Basis(axis, deg_to_rad(degrees)) * neutral.basis
	return Transform3D(basis.scaled(f.hand.basis.get_scale()), f.hand.origin)

func _observe_existing_hinge_normalization(side: String) -> void:
	_restore()
	var f := _fixture(side)
	_set_hand(side, _desired(f, 35.0))
	var pose := _snapshot(side)
	var hinge_only: Dictionary = pose.duplicate(true)
	var constraint: Dictionary = hinge_only.arm_constraints_by_slot[_slot(side)]
	constraint.erase("forearm_hand_index_revision")
	constraint.erase("twist_chains")
	var previous := PreparedArm.normalize_material_frames(hinge_only)
	var indexed := PreparedArm.normalize_material_frames(pose)
	var maximum_difference := 0.0
	var maximum_existing_change := 0.0
	if previous.get("valid", false) and indexed.get("valid", false):
		for i: int in pose.pose_rotations.size():
			if i == f.a or i == f.b:
				continue
			maximum_difference = maxf(maximum_difference, _qerror(_q(previous.pose_rotations[i]), _q(indexed.pose_rotations[i])))
			maximum_existing_change = maxf(maximum_existing_change, _qerror(_q(previous.pose_rotations[i]), _q(pose.pose_rotations[i])))
	_check(previous.get("valid", false) and indexed.get("valid", false) and maximum_difference < ANGLE_EPSILON, side + "_idle_indexing_matches_hinge_only_nonhelper_output", {
		"existing_hinge_maximum_change_degrees": rad_to_deg(maximum_existing_change),
		"indexing_added_nonhelper_change_degrees": rad_to_deg(maximum_difference),
		"previous_reason": previous.get("reason", ""), "indexed_reason": indexed.get("reason", "")})

func _set_fixture_bend(side: String, target_degrees: float) -> void:
	var p := "CC_Base_" + side + "_"
	var u := sk.find_bone(p + "Upperarm")
	var f := sk.find_bone(p + "Forearm")
	var h := sk.find_bone(p + "Hand")
	var upper := sk.get_bone_global_pose(u)
	var forearm := sk.get_bone_global_pose(f)
	var hand := sk.get_bone_global_pose(h)
	var shaft := (forearm.origin - upper.origin).normalized()
	var distal := (hand.origin - forearm.origin).normalized()
	var axis := shaft.cross(distal)
	var current := atan2(axis.length(), shaft.dot(distal))
	if axis.length() < HingeFrame.BEND_SINE_EPSILON:
		var calibration: Dictionary = HingeFrame.calibration(sk.get_bone_rest(f), sk.get_bone_rest(h))
		axis = upper.basis.orthonormalized() * calibration.frame_in_upperarm.x
	var desired := Basis(axis.normalized(), deg_to_rad(target_degrees) - current) * forearm.basis.orthonormalized()
	sk.set_bone_pose_rotation(f, (upper.basis.orthonormalized().inverse() * desired).get_rotation_quaternion().normalized())
	sk.force_update_all_bone_transforms()
	rig.call("_enforce_authoring_upperarm_swing_authority", _slot(side), StringName(p + "Clavicle"), StringName(p + "Upperarm"), StringName(p + "Forearm"), StringName(p + "Hand"))
	var realized := (sk.get_bone_global_pose(f).origin - sk.get_bone_global_pose(u).origin).angle_to(sk.get_bone_global_pose(h).origin - sk.get_bone_global_pose(f).origin)
	_check(absf(realized - deg_to_rad(target_degrees)) < ANGLE_EPSILON, side + "_imported_bent_wrist_fixture", {"target_flexion_degrees": target_degrees, "actual_flexion_degrees": rad_to_deg(realized)})

func _exercise_values(side: String) -> void:
	_restore()
	var f := _fixture(side)
	for degrees: float in [-90.5, -90.0, -89.5, 0.0, 30.0, 89.5, 90.0, 90.5]:
		var desired := _desired(f, degrees)
		var untransformed := _solve(f, f.forearm, desired)
		var accepted: bool = absf(degrees) <= 90.0
		for scale: float in [0.73, 1.0, 1.4]:
			var reference := Transform3D(Basis.from_euler(Vector3(0.31, -0.57, 0.22)).scaled(Vector3.ONE * scale), Vector3(2.0, 1.0, -3.0))
			var forearm: Transform3D = reference * f.forearm
			var hand: Transform3D = reference * desired
			var before: PackedByteArray = var_to_bytes([forearm, hand, f])
			var result := _solve(f, forearm, hand)
			var label := "%s_axial%.1f_scale%.2f" % [side, degrees, scale]
			_check(bool(result.get("valid", false)) == accepted, label + "_existing_cap", result)
			_check(before == var_to_bytes([forearm, hand, f]), label + "_value_inputs_immutable")
			if not accepted:
				_check(result.get("reason", "") == "forearm_hand_index_range", label + "_explicit_rejection")
				continue
			if not result.get("valid", false) or not untransformed.get("valid", false):
				continue
			_check(_qerror(result.proximal_rotation, untransformed.proximal_rotation) < ANGLE_EPSILON and _qerror(result.distal_rotation, untransformed.distal_rotation) < ANGLE_EPSILON, label + "_reference_invariance")
			var second := _solve(f, forearm, hand)
			_check(_qerror(result.proximal_rotation, second.proximal_rotation) < ANGLE_EPSILON and _qerror(result.distal_rotation, second.distal_rotation) < ANGLE_EPSILON, label + "_idempotent")
			var k: Basis = (f.proximal_rest * f.distal_rest).inverse() * f.hand_rest
			var indexed: Basis = forearm.basis.orthonormalized() * Basis(result.proximal_rotation) * Basis(result.distal_rotation) * k
			var residual: Quaternion = (hand.basis.orthonormalized().get_rotation_quaternion() * indexed.orthonormalized().get_rotation_quaternion().inverse()).normalized()
			var axis := (hand.origin - forearm.origin).normalized()
			_check(absf(_signed_twist(residual, axis)) < ANGLE_EPSILON, label + "_no_relative_material_roll")
			_check(absf(_qerror(Quaternion.IDENTITY, residual) - deg_to_rad(25.0)) < ANGLE_EPSILON, label + "_tilt_retained")
			_check(absf(_qerror(f.proximal_neutral, result.proximal_rotation)) <= f.cap * 0.5 + f.epsilon and absf(_qerror(f.distal_neutral, result.distal_rotation)) <= f.cap * 0.5 + f.epsilon, label + "_helper_caps")

func _exercise_prepared(side: String) -> void:
	_restore()
	var f := _fixture(side)
	_set_hand(side, _desired(f, 35.0))
	var pose := _snapshot(side)
	var original := var_to_bytes(pose)
	var expected := _solve(f, sk.get_bone_global_pose(f.f), sk.get_bone_global_pose(f.h))
	var normalized := PreparedArm.normalize_material_frames(pose)
	_check(normalized.get("valid", false), side + "_prepared_accept", normalized)
	_check(original == var_to_bytes(pose), side + "_prepared_input_immutable")
	if normalized.get("valid", false) and expected.get("valid", false):
		var rotations: PackedVector4Array = normalized.pose_rotations
		_check(_qerror(_q(rotations[f.a]), expected.proximal_rotation) < ANGLE_EPSILON and _qerror(_q(rotations[f.b]), expected.distal_rotation) < ANGLE_EPSILON, side + "_prepared_matches_pure")
		var max_other := 0.0
		for index: int in rotations.size():
			if index != f.a and index != f.b:
				max_other = maxf(max_other, _qerror(_q(rotations[index]), _q(pose.pose_rotations[index])))
		_check(max_other < ANGLE_EPSILON, side + "_prepared_main_hand_and_torso_preserved", {"maximum_rotation_delta_degrees": rad_to_deg(max_other)})
		var second_pose: Dictionary = pose.duplicate(true)
		second_pose.pose_rotations = rotations
		var second := PreparedArm.normalize_material_frames(second_pose)
		_check(second.get("valid", false) and _rotation_arrays_close(rotations, second.get("pose_rotations", PackedVector4Array())), side + "_prepared_idempotent")
	_set_hand(side, _desired(f, 110.0))
	var rejected_pose := _snapshot(side)
	var rejected_before := var_to_bytes(rejected_pose)
	var rejected := PreparedArm.normalize_material_frames(rejected_pose)
	_check(not rejected.get("valid", true) and rejected.get("reason", "") == "forearm_hand_index_range", side + "_prepared_over_cap_rejected", rejected)
	_check(rejected_before == var_to_bytes(rejected_pose), side + "_prepared_rejection_immutable")

func _exercise_live_writer(side: String) -> void:
	_restore()
	var f := _fixture(side)
	var desired := _desired(f, 30.0)
	var before := _poses()
	var accepted: bool = rig.apply_authoring_wrist_roll_pose(_slot(side), sk.global_transform * desired)
	_check(accepted, side + "_explicit_writer_accepts_inside_cap")
	if not accepted:
		return
	_check(sk.get_bone_global_pose(f.h).origin.distance_to(desired.origin) < POSITION_EPSILON and _qerror(sk.get_bone_global_pose(f.h).basis.orthonormalized().get_rotation_quaternion(), desired.basis.orthonormalized().get_rotation_quaternion()) < ANGLE_EPSILON, side + "_requested_hand_realized")
	var maximum_other := 0.0
	var local_positions_preserved := true
	for index: int in before.size():
		var now := sk.get_bone_pose(index)
		local_positions_preserved = local_positions_preserved and now.origin == before[index].origin and now.basis.get_scale().is_equal_approx(before[index].basis.get_scale())
		if index not in [f.a, f.b, f.h]:
			maximum_other = maxf(maximum_other, _qerror(now.basis.orthonormalized().get_rotation_quaternion(), before[index].basis.orthonormalized().get_rotation_quaternion()))
	_check(local_positions_preserved and maximum_other < ANGLE_EPSILON, side + "_writer_preserves_nonparticipants_and_local_positions")
	var resolved: Dictionary = rig.call("_resolve_authoring_forearm_hand_index", _slot(side))
	_check(resolved.get("valid", false), side + "_live_acceptance_matches_value", resolved)
	var before_reject := _poses()
	var rejected: bool = rig.apply_authoring_wrist_roll_pose(_slot(side), sk.global_transform * _desired(f, 110.0))
	_check(not rejected, side + "_explicit_writer_stops_outside_cap")
	_check(_pose_arrays_close(before_reject, _poses()), side + "_explicit_rejection_preserves_entire_pose")
	_set_hand(side, desired)
	sk.set_bone_pose_rotation(f.a, f.proximal_neutral)
	sk.set_bone_pose_rotation(f.b, f.distal_neutral)
	var partial_before := _poses()
	var partial: Array[StringName] = [StringName(sk.get_bone_name(f.f)), StringName(sk.get_bone_name(f.h))]
	rig.call("_normalize_solved_arm_material_frames", partial)
	_check(_pose_arrays_close(partial_before, _poses()), side + "_partial_payload_cannot_write_helpers")
	var complete: Array[StringName] = []
	for name: StringName in _snapshot(side).bone_names:
		complete.append(name)
	rig.call("_normalize_solved_arm_material_frames", complete)
	var applied: Dictionary = rig.call("_resolve_authoring_forearm_hand_index", _slot(side))
	_check(applied.get("valid", false) and _qerror(sk.get_bone_pose_rotation(f.a), applied.get("proximal_rotation", Quaternion.IDENTITY)) < ANGLE_EPSILON and _qerror(sk.get_bone_pose_rotation(f.b), applied.get("distal_rotation", Quaternion.IDENTITY)) < ANGLE_EPSILON, side + "_complete_replay_payload_indexes_helpers")

func _exercise_invalid() -> void:
	_restore()
	var f := _fixture("R")
	var hand: Transform3D = f.hand
	hand.origin = f.forearm.origin
	_check(not _solve(f, f.forearm, hand).get("valid", true), "zero_forearm_axis_rejected")
	hand = _desired(f, 0.0)
	hand.basis = hand.basis.scaled(Vector3(1.0, 2.0, 1.0))
	_check(not _solve(f, f.forearm, hand).get("valid", true), "nonuniform_frame_rejected")

func _exercise_cold_replay() -> void:
	_restore()
	var cached_neutrals: Dictionary = rig.authoring_limb_twist_neutral_rotation_lookup.duplicate(true)
	var previous_runtime: Dictionary = rig.runtime_solved_replay_pose_state.duplicate(true)
	var fixtures: Dictionary = {}
	var expected: Dictionary = {}
	var desired_hands: Dictionary = {}
	var authored_hands: Dictionary = {}
	for side: String in ["R", "L"]:
		fixtures[side] = _fixture(side)
		desired_hands[side] = _desired(fixtures[side], 30.0 if side == "R" else -40.0)
		_set_hand(side, desired_hands[side])
		authored_hands[side] = sk.get_bone_global_pose(fixtures[side].h)
		expected[side] = _solve(fixtures[side], fixtures[side].forearm, desired_hands[side])
	var pose := _snapshot("R")
	pose.arm_constraints_by_slot[&"hand_left"] = _snapshot("L").arm_constraints_by_slot[&"hand_left"]
	var calibration := {"bone_names": pose.bone_names.duplicate(), "bone_rest_transforms": pose.bone_rest_transforms.duplicate(), "arm_constraints_by_slot": pose.arm_constraints_by_slot.duplicate(true)}
	var rejected_poses: Dictionary = {}
	for side: String in ["R", "L"]:
		_set_hand(side, _desired(fixtures[side], 110.0))
		rejected_poses[side] = _snapshot(side)
		_set_hand(side, desired_hands[side])
	_restore()
	rig.authoring_limb_twist_neutral_rotation_lookup.clear()
	var calibration_bytes := var_to_bytes(calibration)
	# Reproduce the pre-existing finalizer independently, with exactly the same
	# packet channels, to distinguish it from the new two-helper operation.
	var raw_packet_hands: Dictionary = {}
	var hinge_only_hands: Dictionary = {}
	for index: int in sk.get_bone_count():
		sk.set_bone_pose_position(index, pose.pose_positions[index])
		sk.set_bone_pose_rotation(index, _q(pose.pose_rotations[index]))
		sk.set_bone_pose_scale(index, pose.pose_scales[index])
	sk.force_update_all_bone_transforms()
	for side: String in ["R", "L"]:
		raw_packet_hands[side] = sk.get_bone_global_pose(fixtures[side].h)
		var prefix := "CC_Base_" + side + "_"
		rig.call("_enforce_authoring_upperarm_swing_authority", _slot(side), StringName(prefix + "Clavicle"), StringName(prefix + "Upperarm"), StringName(prefix + "Forearm"), StringName(prefix + "Hand"))
		hinge_only_hands[side] = sk.get_bone_global_pose(fixtures[side].h)
	_restore()
	var accepted := _apply_replay(pose, calibration)
	_check(accepted, "cold_replay_accepts_genuine_both_arm_calibration")
	if accepted:
		for side: String in ["R", "L"]:
			var f: Dictionary = fixtures[side]
			var desired: Transform3D = desired_hands[side]
			var result: Dictionary = expected[side]
			_check(result.get("valid", false) and _qerror(sk.get_bone_pose_rotation(f.a), result.get("proximal_rotation", Quaternion.IDENTITY)) < ANGLE_EPSILON and _qerror(sk.get_bone_pose_rotation(f.b), result.get("distal_rotation", Quaternion.IDENTITY)) < ANGLE_EPSILON, side + "_cold_replay_helpers_match_value")
			var hand := sk.get_bone_global_pose(f.h)
			var authored: Transform3D = authored_hands[side]
			var raw_packet: Transform3D = raw_packet_hands[side]
			var hinge_only: Transform3D = hinge_only_hands[side]
			var position_error := sk.to_global(hand.origin).distance_to(sk.to_global(desired.origin))
			var rotation_error := _qerror(hand.basis.orthonormalized().get_rotation_quaternion(), desired.basis.orthonormalized().get_rotation_quaternion())
			var indexing_position_delta := sk.to_global(hand.origin).distance_to(sk.to_global(hinge_only.origin))
			var indexing_rotation_delta := _qerror(hand.basis.orthonormalized().get_rotation_quaternion(), hinge_only.basis.orthonormalized().get_rotation_quaternion())
			# This addition must preserve the existing finalizer's Hand frame. Its
			# independent hinge reconstruction residual remains explicit evidence,
			# not a new indexing error or permission to change the elbow in this task.
			_check(indexing_position_delta < POSITION_EPSILON and indexing_rotation_delta < ANGLE_EPSILON and rotation_error < ANGLE_EPSILON, side + "_cold_replay_preserves_existing_hinge_hand_frame", {
				"position_error_world_m": position_error, "position_error_skeleton_units": hand.origin.distance_to(desired.origin), "rotation_error_degrees": rad_to_deg(rotation_error),
				"skeleton_world_scale": sk.global_basis.get_scale(),
				"fixture_initial_position_error_world_m": sk.to_global(authored.origin).distance_to(sk.to_global(desired.origin)),
				"fixture_initial_rotation_error_degrees": rad_to_deg(_qerror(authored.basis.orthonormalized().get_rotation_quaternion(), desired.basis.orthonormalized().get_rotation_quaternion())),
				"replay_vs_authored_position_error_world_m": sk.to_global(hand.origin).distance_to(sk.to_global(authored.origin)),
				"replay_vs_authored_rotation_error_degrees": rad_to_deg(_qerror(hand.basis.orthonormalized().get_rotation_quaternion(), authored.basis.orthonormalized().get_rotation_quaternion())),
				"hand_local_position_delta_units": sk.get_bone_pose_position(f.h).distance_to(pose.pose_positions[f.h]),
				"raw_packet_vs_requested_position_world_m": sk.to_global(raw_packet.origin).distance_to(sk.to_global(desired.origin)),
				"hinge_only_vs_requested_position_world_m": sk.to_global(hinge_only.origin).distance_to(sk.to_global(desired.origin)),
				"indexed_vs_hinge_only_position_world_m": indexing_position_delta,
				"indexed_vs_hinge_only_rotation_degrees": rad_to_deg(indexing_rotation_delta)})
		var maximum_other := 0.0
		for index: int in sk.get_bone_count():
			if index in [fixtures.R.a, fixtures.R.b, fixtures.L.a, fixtures.L.b]:
				continue
			maximum_other = maxf(maximum_other, _qerror(sk.get_bone_pose_rotation(index), _q(pose.pose_rotations[index])))
		_check(maximum_other < ANGLE_EPSILON, "cold_replay_nonhelper_authored_rotations_preserved", {"maximum_delta_degrees": rad_to_deg(maximum_other)})
		for side: String in ["R", "L"]:
			_check_cold_rejection(rejected_poses[side], calibration, side + "_cold_replay_over_cap")
		var wrong_rest: Dictionary = calibration.duplicate(true)
		var rest: Transform3D = wrong_rest.bone_rest_transforms[fixtures.R.a]
		rest.basis = Basis(Vector3.RIGHT, 0.2) * rest.basis
		wrong_rest.bone_rest_transforms[fixtures.R.a] = rest
		_check_cold_rejection(pose, wrong_rest, "cold_replay_wrong_model_rest")
		var missing_neutral: Dictionary = calibration.duplicate(true)
		missing_neutral.arm_constraints_by_slot[&"hand_right"].twist_neutral_rotations.erase(&"CC_Base_R_ForearmTwist01")
		_check_cold_rejection(pose, missing_neutral, "cold_replay_missing_captured_neutral")
		_check_cold_rejection(pose, {}, "cold_replay_missing_calibration")
	_check(rig.authoring_limb_twist_neutral_rotation_lookup.is_empty(), "cold_replay_does_not_populate_authoring_cache")
	_check(calibration_bytes == var_to_bytes(calibration), "cold_replay_calibration_input_immutable")
	rig.authoring_limb_twist_neutral_rotation_lookup = cached_neutrals
	rig.runtime_solved_replay_pose_state = previous_runtime
	_restore()

func _apply_replay(pose: Dictionary, calibration: Dictionary) -> bool:
	return bool(rig.call("apply_runtime_solved_upper_body_pose_frame", pose.bone_names, Array(pose.pose_positions), Array(pose.pose_rotations), Array(pose.pose_scales), 1.0, calibration))

func _check_cold_rejection(pose: Dictionary, calibration: Dictionary, label: String) -> void:
	var before := _poses()
	var state := var_to_bytes([rig.runtime_solved_replay_pose_state, rig.runtime_solved_replay_weapon_state])
	_check(not _apply_replay(pose, calibration), label + "_rejected")
	_check(_pose_arrays_close(before, _poses()) and state == var_to_bytes([rig.runtime_solved_replay_pose_state, rig.runtime_solved_replay_weapon_state]), label + "_entire_pose_and_runtime_state_preserved")

func _exercise_saved_source() -> void:
	var hash_before := FileAccess.get_sha256(source_path)
	var library: Resource = ResourceLoader.load(source_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(library != null, "optional_saved_library_loads_readonly")
	if library == null:
		return
	for wip: Resource in library.get("saved_wips"):
		if wip == null or String(wip.get("forge_project_name")) != "Broken_Balde_v1":
			continue
		var station: Resource = wip.get("combat_animation_station_state")
		for draft: Resource in station.get("skill_drafts"):
			if draft == null or String(draft.get("legal_slot_id")) != "skill_slot_1":
				continue
			for node: Resource in draft.get("motion_node_chain"):
				var pose: Dictionary = node.get("prepared_pose")
				if pose.is_empty():
					continue
				var before := var_to_bytes(pose)
				var result := PreparedArm.normalize_material_frames(pose)
				samples.append({"source": source_path, "node": String(node.get("node_id")), "valid": result.get("valid", false), "reason": result.get("reason", ""), "hand_slot": result.get("hand_slot", ""), "diagnostics": result.get("diagnostics", {})})
				_check(before == var_to_bytes(pose), "saved_node_" + String(node.get("node_id")) + "_immutable")
				_check(result.get("valid", false) or result.get("reason", "") == "forearm_hand_index_range", "saved_node_" + String(node.get("node_id")) + "_valid_or_existing_cap_rejection", result if not result.get("valid", false) else {})
			_exercise_saved_frames(draft)
	_check(FileAccess.get_sha256(source_path) == hash_before, "source_library_hash_unchanged")

func _exercise_saved_frames(draft: Resource) -> void:
	var clip: Resource = draft.get("baked_runtime_clip")
	_check(clip != null, "saved_skill1_has_baked_frames")
	if clip == null:
		return
	var template: Dictionary = clip.get("prepared_entry_destination")
	var names: Array = clip.get("baked_solved_upper_body_bone_names")
	var frame_times: PackedFloat32Array = clip.get("baked_frame_times")
	var positions: Array = clip.get("baked_solved_upper_body_pose_positions")
	var rotations: Array = clip.get("baked_solved_upper_body_pose_rotations")
	var scales: Array = clip.get("baked_solved_upper_body_pose_scales")
	var available: Array = clip.get("baked_solved_replay_frame_available")
	var layout_ok: bool = template.get("bone_names", []) == names and frame_times.size() > 0 and positions.size() == frame_times.size() and rotations.size() == frame_times.size() and scales.size() == frame_times.size() and available.size() == frame_times.size()
	_check(layout_ok, "saved_skill1_frame_layout_matches_capture", {"frames": frame_times.size(), "bones": names.size()})
	if not layout_ok:
		return
	var passed_count := 0
	var rejected_count := 0
	var skipped_count := 0
	var immutable := true
	var failures: Array[Dictionary] = []
	for frame: int in frame_times.size():
		if not available[frame]:
			skipped_count += 1
			continue
		var pose: Dictionary = template.duplicate(true)
		pose.pose_positions = PackedVector3Array(positions[frame])
		pose.pose_rotations = PackedVector4Array(rotations[frame])
		pose.pose_scales = PackedVector3Array(scales[frame])
		var before := var_to_bytes(pose)
		var result := PreparedArm.normalize_material_frames(pose)
		immutable = immutable and before == var_to_bytes(pose)
		if result.get("valid", false):
			passed_count += 1
		else:
			rejected_count += 1
			failures.append({"frame": frame, "time": frame_times[frame], "reason": result.get("reason", ""), "hand_slot": result.get("hand_slot", "")})
	var summary := {"source": source_path, "kind": "saved_skill1_all_baked_frames", "total": frame_times.size(), "valid": passed_count, "rejected": rejected_count, "unavailable": skipped_count, "failures": failures}
	samples.append(summary)
	_check(immutable, "saved_skill1_all_frame_inputs_immutable")
	_check(passed_count == frame_times.size() and rejected_count == 0 and skipped_count == 0, "saved_skill1_all_available_frames_normalize", summary)

func _snapshot(side: String) -> Dictionary:
	var p := "CC_Base_" + side + "_"
	var packet := {"bone_names": [], "pose_positions": PackedVector3Array(), "pose_rotations": PackedVector4Array(), "pose_scales": PackedVector3Array(), "parent_indices": PackedInt32Array(), "parent_reference_transforms": [], "bone_rest_transforms": [], "arm_constraints_by_slot": {}}
	for index: int in sk.get_bone_count():
		var q := sk.get_bone_pose_rotation(index).normalized()
		packet.bone_names.append(StringName(sk.get_bone_name(index)))
		packet.pose_positions.append(sk.get_bone_pose_position(index))
		packet.pose_rotations.append(Vector4(q.x, q.y, q.z, q.w))
		packet.pose_scales.append(sk.get_bone_pose_scale(index))
		packet.parent_indices.append(sk.get_bone_parent(index))
		packet.parent_reference_transforms.append(Transform3D.IDENTITY)
		packet.bone_rest_transforms.append(sk.get_bone_rest(index))
	var constraint := {"forearm_hand_index_revision": Indexer.REVISION,
		"twist_chains": [[StringName(p + "ForearmTwist01"), StringName(p + "ForearmTwist02")]],
		"twist_neutral_rotations": rig.authoring_limb_twist_neutral_rotation_lookup.duplicate(),
		"limb_twist_limit_radians": rig.AUTHORING_LIMB_TWIST_LIMIT_RADIANS,
		"joint_epsilon_degrees": rig.AUTHORING_JOINT_RANGE_EPSILON_DEGREES}
	for role: String in ["Clavicle", "Upperarm", "Forearm", "Hand"]:
		constraint[role.to_lower() + "_bone"] = StringName(p + role)
	packet.arm_constraints_by_slot[_slot(side)] = constraint
	return packet

func _set_hand(side: String, desired: Transform3D) -> void:
	var h := sk.find_bone("CC_Base_" + side + "_Hand")
	var parent := sk.get_bone_global_pose(sk.get_bone_parent(h)).basis.orthonormalized()
	sk.set_bone_pose_rotation(h, (parent.inverse() * desired.basis.orthonormalized()).get_rotation_quaternion().normalized())
	sk.force_update_all_bone_transforms()

func _poses() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for index: int in sk.get_bone_count():
		result.append(sk.get_bone_pose(index))
	return result

func _restore() -> void:
	for index: int in baseline.size():
		sk.set_bone_pose(index, baseline[index])
	sk.force_update_all_bone_transforms()

func _pose_arrays_close(a: Array[Transform3D], b: Array[Transform3D]) -> bool:
	if a.size() != b.size(): return false
	for i: int in a.size():
		if a[i].origin.distance_to(b[i].origin) > POSITION_EPSILON or not a[i].basis.get_scale().is_equal_approx(b[i].basis.get_scale()) or _qerror(a[i].basis.orthonormalized().get_rotation_quaternion(), b[i].basis.orthonormalized().get_rotation_quaternion()) > ANGLE_EPSILON: return false
	return true

func _rotation_arrays_close(a: PackedVector4Array, b: PackedVector4Array) -> bool:
	if a.size() != b.size(): return false
	for i: int in a.size():
		if _qerror(_q(a[i]), _q(b[i])) > ANGLE_EPSILON: return false
	return true

func _qerror(a: Quaternion, b: Quaternion) -> float:
	var delta := (a.normalized().inverse() * b.normalized()).normalized()
	return 2.0 * atan2(Vector3(delta.x, delta.y, delta.z).length(), absf(delta.w))

func _signed_twist(q: Quaternion, axis: Vector3) -> float:
	return wrapf(2.0 * atan2(Vector3(q.x, q.y, q.z).dot(axis.normalized()), q.w), -PI, PI)

func _q(v: Vector4) -> Quaternion:
	return Quaternion(v.x, v.y, v.z, v.w).normalized()

func _slot(side: String) -> StringName:
	return &"hand_left" if side == "L" else &"hand_right"

func _check(passed: bool, label: String, detail: Dictionary = {}) -> void:
	checks.append({"passed": passed, "check": label, "detail": detail})
