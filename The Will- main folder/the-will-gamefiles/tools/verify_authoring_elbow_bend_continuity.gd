extends SceneTree

# Actual imported rig, isolated direct-writer checks. This verifies continuity
# of an incoming bend branch, not a fixed anatomical hinge or skin deformation.
const RigScene: PackedScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const ANGLE_EPSILON_DEGREES := 0.03
const POSITION_EPSILON_METERS := 0.000005

var checks: Array[Dictionary] = []
var output_path := "C:/WORKSPACE/godot_runs/verify_authoring_elbow_bend_continuity.json"

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output_path = argument.trim_prefix("--out=")
	call_deferred("_run")

func _run() -> void:
	var rig: PlayerHumanoidRig = RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.set_process(false)
	var sk: Skeleton3D = rig.get_node("JosieModel/Josie/Skeleton3D") as Skeleton3D
	for yaw: float in [0.0, 75.0]:
		rig.rotation = Vector3(0.0, deg_to_rad(yaw), 0.0)
		rig.position = Vector3(1.25, 0.2, -0.75) if yaw != 0.0 else Vector3.ZERO
		rig.set_upper_body_authoring_state({
			"active": true, "blend": 1.0, "two_hand": true, "dominant_slot_id": &"hand_right",
			"primary_target_world": rig.to_global(Vector3(0.32, 1.20, -0.68)),
			"secondary_target_world": rig.to_global(Vector3(-0.22, 1.18, -0.52)),
			"tip_world": rig.to_global(Vector3(0.58, 1.42, -1.08)),
			"pommel_world": rig.to_global(Vector3(0.18, 1.02, -0.44)),
		})
		rig.apply_authoring_preview_frame_now(false)
		var snapshot: Array[Quaternion] = _snapshot(sk)
		for side: String in ["R", "L"]:
			_exercise(rig, sk, snapshot, side, yaw)
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check["passed"])
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"passed": passed, "checks": checks,
			"scope": "Incoming elbow branch continuity, narrow direct-writer and reachable CCD regressions. No anatomical or full grip certificate."}, "\t"))
		file.close()
	else:
		passed = false
	print("ELBOW_BEND_CONTINUITY passed=%s checks=%d output=%s" % [str(passed), checks.size(), output_path])
	quit(0 if passed else 1)

func _exercise(rig: PlayerHumanoidRig, sk: Skeleton3D, snapshot: Array[Quaternion], side: String, yaw: float) -> void:
	var forearm := StringName("CC_Base_%s_Forearm" % side)
	var hand := StringName("CC_Base_%s_Hand" % side)
	var forearm_index: int = sk.find_bone(String(forearm))
	var label := "%s_yaw_%.0f" % [side, yaw]
	var limit: float = rig.authoring_elbow_max_plane_angle_degrees
	for branch_sign: float in [-1.0, 1.0]:
		for weight: float in [0.25, 0.86, 1.0]:
			_restore(sk, snapshot)
			var before: Dictionary = _seed(rig, sk, side, limit - 0.5, branch_sign)
			var target: Vector3 = before.elbow + Basis(before.normal, deg_to_rad(190.0)) * before.upper_direction * float(before.lower_length)
			var initial_rotation: Quaternion = sk.get_bone_pose_rotation(forearm_index)
			# The unguarded path must actually cross or exceed the cap; otherwise
			# this target would not distinguish the regression from an easy move.
			rig.call("_rotate_bone_toward_end_target", forearm, hand, target, weight, false)
			var raw: Dictionary = _geometry(sk, side)
			var raw_continuous: float = _continuous_angle(before, raw)
			_check(raw_continuous > limit, label + "_fixture_exceeds_limit_sign_%s_weight_%s" % [branch_sign, weight], {"raw_continuous_degrees": raw_continuous})
			sk.set_bone_pose_rotation(forearm_index, initial_rotation)
			sk.force_update_all_bone_transforms()
			rig.call("_rotate_bone_toward_end_target", forearm, hand, target, weight, true)
			var after: Dictionary = _geometry(sk, side)
			var actual: float = _continuous_angle(before, after)
			_check(absf(actual - limit) <= ANGLE_EPSILON_DEGREES and (before.normal as Vector3).dot(after.normal) > 0.999,
				label + "_weighted_crossing_keeps_incoming_branch_sign_%s_weight_%s" % [branch_sign, weight], {"continuous_degrees": actual, "limit_degrees": limit})
			_check(absf(float(after.lower_length) - float(before.lower_length)) <= POSITION_EPSILON_METERS,
				label + "_crossing_preserves_segment_length_sign_%s_weight_%s" % [branch_sign, weight])
		_restore(sk, snapshot)
		var inward_before: Dictionary = _seed(rig, sk, side, 145.0, branch_sign)
		var inward_target: Vector3 = inward_before.elbow + Basis(inward_before.normal, deg_to_rad(135.0)) * inward_before.upper_direction * float(inward_before.lower_length)
		var inward_rotation: Quaternion = sk.get_bone_pose_rotation(forearm_index)
		rig.call("_rotate_bone_toward_end_target", forearm, hand, inward_target, 0.86, false)
		var unguarded_hand: Vector3 = _geometry(sk, side).hand
		var unguarded_q: Quaternion = sk.get_bone_pose_rotation(forearm_index)
		sk.set_bone_pose_rotation(forearm_index, inward_rotation)
		sk.force_update_all_bone_transforms()
		rig.call("_rotate_bone_toward_end_target", forearm, hand, inward_target, 0.86, true)
		_check(unguarded_hand.distance_to(_geometry(sk, side).hand) <= POSITION_EPSILON_METERS
			and absf(unguarded_q.dot(sk.get_bone_pose_rotation(forearm_index))) >= 0.999999,
			label + "_inward_update_unchanged_sign_%s" % branch_sign)
	# A zero-weight call must not change even an already-over-cap pose.
	_restore(sk, snapshot)
	var zero_before: Dictionary = _seed(rig, sk, side, limit + 1.0, 1.0)
	var zero_q: Quaternion = sk.get_bone_pose_rotation(forearm_index)
	var zero_target: Vector3 = zero_before.elbow + Basis(zero_before.normal, deg_to_rad(190.0)) * zero_before.upper_direction * float(zero_before.lower_length)
	rig.call("_rotate_bone_toward_end_target", forearm, hand, zero_target, 0.0, true)
	_check((zero_before.hand as Vector3).distance_to(_geometry(sk, side).hand) <= POSITION_EPSILON_METERS
		and absf(zero_q.dot(sk.get_bone_pose_rotation(forearm_index))) >= 0.999999, label + "_zero_weight_is_noop")
	# Exact straightness has no incoming plane. Require finite geometry, not an
	# invented side; the broader solver owns its existing singularity policy.
	_restore(sk, snapshot)
	var straight: Dictionary = _seed(rig, sk, side, 180.0, 1.0)
	var straight_target: Vector3 = straight.hand + Vector3(0.01, -0.01, 0.02)
	rig.call("_rotate_bone_toward_end_target", forearm, hand, straight_target, 0.86, true)
	var straight_after: Dictionary = _geometry(sk, side)
	_check((straight_after.hand as Vector3).is_finite() and sk.get_bone_pose_rotation(forearm_index).is_finite()
		and absf(float(straight_after.lower_length) - float(straight.lower_length)) <= POSITION_EPSILON_METERS, label + "_exact_straight_remains_finite")
	# Keep the same imported segments but exercise a narrower near-straight cap.
	_restore(sk, snapshot)
	rig.authoring_elbow_max_plane_angle_degrees = 179.0
	var near: Dictionary = _seed(rig, sk, side, 178.9, -1.0)
	var near_target: Vector3 = near.elbow + Basis(near.normal, deg_to_rad(185.0)) * near.upper_direction * float(near.lower_length)
	rig.call("_rotate_bone_toward_end_target", forearm, hand, near_target, 0.86, true)
	var near_after: Dictionary = _geometry(sk, side)
	_check(absf(_continuous_angle(near, near_after) - 179.0) <= ANGLE_EPSILON_DEGREES
		and (near.normal as Vector3).dot(near_after.normal) > 0.999, label + "_near_straight_nonzero_branch_preserved")
	rig.authoring_elbow_max_plane_angle_degrees = limit
	for target_angle: float in [137.0, limit]:
		_restore(sk, snapshot)
		var seed_angle: float = 140.0 if target_angle < 150.0 else limit - 0.5
		var ccd_before: Dictionary = _seed(rig, sk, side, seed_angle, 1.0)
		var ccd_target_local: Vector3 = ccd_before.elbow + Basis(ccd_before.normal, deg_to_rad(target_angle)) * ccd_before.upper_direction * float(ccd_before.lower_length)
		var ccd_target_world: Vector3 = sk.to_global(ccd_target_local)
		rig.call("_apply_ccd_arm_reach_pose", StringName("CC_Base_%s_Upperarm" % side), forearm, hand, ccd_target_world,
			PlayerHumanoidRig.AUTHORING_GRIP_RELATIONSHIP_PRECISE_SOLVE_ITERATIONS,
			PlayerHumanoidRig.AUTHORING_DIRECT_ARM_FOREARM_WEIGHT, PlayerHumanoidRig.AUTHORING_DIRECT_ARM_UPPERARM_WEIGHT,
			StringName("CC_Base_%s_Clavicle" % side), PlayerHumanoidRig.AUTHORING_DIRECT_ARM_CLAVICLE_WEIGHT,
			PlayerHumanoidRig.AUTHORING_GRIP_RELATIONSHIP_ALIGNMENT_EPSILON_METERS)
		var error: float = sk.to_global(_geometry(sk, side).hand).distance_to(ccd_target_world)
		_check(error <= PlayerHumanoidRig.AUTHORING_GRIP_RELATIONSHIP_ALIGNMENT_EPSILON_METERS,
			label + "_reachable_ccd_endpoint_%.1f" % target_angle, {"endpoint_error_meters": error, "existing_epsilon_meters": PlayerHumanoidRig.AUTHORING_GRIP_RELATIONSHIP_ALIGNMENT_EPSILON_METERS})
	_restore(sk, snapshot)

func _seed(rig: PlayerHumanoidRig, sk: Skeleton3D, side: String, degrees: float, branch_sign: float) -> Dictionary:
	var state: Dictionary = _geometry(sk, side)
	var normal: Vector3 = state.normal
	if normal.length_squared() < 0.5:
		normal = (state.upper_direction as Vector3).cross(Vector3.FORWARD).normalized()
		if normal.length_squared() < 0.5:
			normal = (state.upper_direction as Vector3).cross(Vector3.UP).normalized()
	normal *= branch_sign
	var target: Vector3 = state.elbow + Basis(normal, deg_to_rad(degrees)) * state.upper_direction * float(state.lower_length)
	rig.call("_rotate_bone_toward_end_target", StringName("CC_Base_%s_Forearm" % side), StringName("CC_Base_%s_Hand" % side), target, 1.0, false)
	return _geometry(sk, side)

func _geometry(sk: Skeleton3D, side: String) -> Dictionary:
	var shoulder: Vector3 = sk.get_bone_global_pose(sk.find_bone("CC_Base_%s_Upperarm" % side)).origin
	var elbow: Vector3 = sk.get_bone_global_pose(sk.find_bone("CC_Base_%s_Forearm" % side)).origin
	var hand: Vector3 = sk.get_bone_global_pose(sk.find_bone("CC_Base_%s_Hand" % side)).origin
	var upper: Vector3 = shoulder - elbow
	var lower: Vector3 = hand - elbow
	return {"shoulder": shoulder, "elbow": elbow, "hand": hand, "upper_direction": upper.normalized(),
		"lower_direction": lower.normalized(), "lower_length": lower.length(), "normal": upper.cross(lower).normalized(),
		"angle_degrees": rad_to_deg(upper.angle_to(lower))}

func _continuous_angle(before: Dictionary, after: Dictionary) -> float:
	var signed: float = atan2((before.normal as Vector3).dot((before.upper_direction as Vector3).cross(after.lower_direction)),
		(before.upper_direction as Vector3).dot(after.lower_direction))
	var previous: float = deg_to_rad(float(before.angle_degrees))
	return rad_to_deg(previous + wrapf(signed - previous, -PI, PI))

func _snapshot(sk: Skeleton3D) -> Array[Quaternion]:
	var rotations: Array[Quaternion] = []
	for index: int in range(sk.get_bone_count()):
		rotations.append(sk.get_bone_pose_rotation(index))
	return rotations

func _restore(sk: Skeleton3D, rotations: Array[Quaternion]) -> void:
	for index: int in range(rotations.size()):
		sk.set_bone_pose_rotation(index, rotations[index])
	sk.force_update_all_bone_transforms()

func _check(passed: bool, label: String, details: Dictionary = {}) -> void:
	details["name"] = label
	details["passed"] = passed
	checks.append(details)
