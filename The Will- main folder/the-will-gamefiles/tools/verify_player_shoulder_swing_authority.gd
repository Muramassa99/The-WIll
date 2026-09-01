extends SceneTree

const RigScene: PackedScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const RESULT_FILE_PATH := "C:/WORKSPACE/player_shoulder_swing_authority_results.txt"
const SEED_TWIST_DEGREES: Array[float] = [-70.0, 0.0, 70.0]
const ENDPOINT_EPSILON_METERS: float = 0.0005
const DIRECTION_EPSILON_DEGREES: float = 0.05
const DETERMINISM_EPSILON_DEGREES: float = 0.10


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var rig_root: PlayerHumanoidRig = RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig_root)
	await process_frame
	await process_frame
	rig_root.set_authoring_preview_mode_enabled(true)
	rig_root.set_upper_body_authoring_state({
		"active": true,
		"blend": 1.0,
		"two_hand": true,
		"dominant_slot_id": &"hand_right",
		"primary_target_world": rig_root.global_position + Vector3(0.32, 1.20, -0.68),
		"secondary_target_world": rig_root.global_position + Vector3(-0.22, 1.18, -0.52),
		"tip_world": rig_root.global_position + Vector3(0.58, 1.42, -1.08),
		"pommel_world": rig_root.global_position + Vector3(0.18, 1.02, -0.44),
	})
	rig_root.apply_authoring_preview_frame_now(false)
	rig_root.set_process(false)

	var skeleton: Skeleton3D = (
		rig_root.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D
	)
	var right_result: Dictionary = _exercise_slot(
		rig_root,
		skeleton,
		&"hand_right",
		&"CC_Base_R_Clavicle",
		&"CC_Base_R_Upperarm",
		&"CC_Base_R_Forearm",
		&"CC_Base_R_Hand"
	)
	var left_result: Dictionary = _exercise_slot(
		rig_root,
		skeleton,
		&"hand_left",
		&"CC_Base_L_Clavicle",
		&"CC_Base_L_Upperarm",
		&"CC_Base_L_Forearm",
		&"CC_Base_L_Hand"
	)
	var all_checks_passed: bool = (
		skeleton != null
		and bool(right_result.get("passed", false))
		and bool(left_result.get("passed", false))
	)

	var lines: PackedStringArray = []
	lines.append("rig_loaded=%s" % str(rig_root != null))
	lines.append("skeleton_loaded=%s" % str(skeleton != null))
	lines.append_array(_result_lines("right", right_result))
	lines.append_array(_result_lines("left", left_result))
	lines.append("all_checks_passed=%s" % str(all_checks_passed))
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(0 if all_checks_passed else 1)


func _exercise_slot(
	rig_root: PlayerHumanoidRig,
	skeleton: Skeleton3D,
	slot_id: StringName,
	clavicle_bone: StringName,
	upperarm_bone: StringName,
	forearm_bone: StringName,
	hand_bone: StringName
) -> Dictionary:
	if skeleton == null:
		return {"passed": false, "status": "skeleton_missing"}
	var upperarm_index: int = skeleton.find_bone(String(upperarm_bone))
	var forearm_index: int = skeleton.find_bone(String(forearm_bone))
	if upperarm_index < 0 or forearm_index < 0:
		return {"passed": false, "status": "arm_bones_missing"}
	var baseline_upperarm: Quaternion = skeleton.get_bone_pose_rotation(upperarm_index).normalized()
	var baseline_forearm: Quaternion = skeleton.get_bone_pose_rotation(forearm_index).normalized()
	var final_rotations: Array[Quaternion] = []
	var max_elbow_drift_meters: float = 0.0
	var max_hand_drift_meters: float = 0.0
	var max_direction_error_degrees: float = 0.0

	for seed_degrees: float in SEED_TWIST_DEGREES:
		skeleton.set_bone_pose_rotation(upperarm_index, baseline_upperarm)
		skeleton.set_bone_pose_rotation(forearm_index, baseline_forearm)
		skeleton.force_update_all_bone_transforms()
		var seed_twist: Quaternion = Quaternion(Vector3.UP, deg_to_rad(seed_degrees))
		var seeded_basis: Basis = (
			Basis(baseline_upperarm) * Basis(seed_twist)
		).orthonormalized()
		skeleton.set_bone_pose_rotation(
			upperarm_index,
			seeded_basis.get_rotation_quaternion().normalized()
		)
		skeleton.force_update_all_bone_transforms()
		var elbow_before: Vector3 = _get_bone_world_position(skeleton, forearm_bone)
		var hand_before: Vector3 = _get_bone_world_position(skeleton, hand_bone)

		rig_root.call(
			"_enforce_authoring_upperarm_swing_authority",
			slot_id,
			clavicle_bone,
			upperarm_bone,
			forearm_bone,
			hand_bone
		)
		skeleton.force_update_all_bone_transforms()
		var shoulder_after: Vector3 = _get_bone_world_position(skeleton, upperarm_bone)
		var elbow_after: Vector3 = _get_bone_world_position(skeleton, forearm_bone)
		var hand_after: Vector3 = _get_bone_world_position(skeleton, hand_bone)
		var upperarm_basis_world: Basis = _get_bone_world_basis(skeleton, upperarm_bone)
		var solved_direction_world: Vector3 = (elbow_after - shoulder_after).normalized()
		max_elbow_drift_meters = maxf(
			max_elbow_drift_meters,
			elbow_before.distance_to(elbow_after)
		)
		max_hand_drift_meters = maxf(
			max_hand_drift_meters,
			hand_before.distance_to(hand_after)
		)
		max_direction_error_degrees = maxf(
			max_direction_error_degrees,
			rad_to_deg(acos(clampf(
				upperarm_basis_world.y.normalized().dot(solved_direction_world),
				-1.0,
				1.0
			)))
		)
		final_rotations.append(
			skeleton.get_bone_pose_rotation(upperarm_index).normalized()
		)

	var max_seed_result_delta_degrees: float = 0.0
	for rotation_index: int in range(1, final_rotations.size()):
		max_seed_result_delta_degrees = maxf(
			max_seed_result_delta_degrees,
			rad_to_deg(final_rotations[0].angle_to(final_rotations[rotation_index]))
		)
	var passed: bool = (
		max_elbow_drift_meters <= ENDPOINT_EPSILON_METERS
		and max_hand_drift_meters <= ENDPOINT_EPSILON_METERS
		and max_direction_error_degrees <= DIRECTION_EPSILON_DEGREES
		and max_seed_result_delta_degrees <= DETERMINISM_EPSILON_DEGREES
	)
	return {
		"passed": passed,
		"status": "ok" if passed else "shoulder_swing_authority_failed",
		"max_elbow_drift_meters": max_elbow_drift_meters,
		"max_hand_drift_meters": max_hand_drift_meters,
		"max_direction_error_degrees": max_direction_error_degrees,
		"max_seed_result_delta_degrees": max_seed_result_delta_degrees,
	}


func _result_lines(prefix: String, result: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append("%s_status=%s" % [prefix, String(result.get("status", "missing"))])
	lines.append("%s_max_elbow_drift_meters=%.8f" % [prefix, float(result.get("max_elbow_drift_meters", INF))])
	lines.append("%s_max_hand_drift_meters=%.8f" % [prefix, float(result.get("max_hand_drift_meters", INF))])
	lines.append("%s_max_direction_error_degrees=%.6f" % [prefix, float(result.get("max_direction_error_degrees", INF))])
	lines.append("%s_max_seed_result_delta_degrees=%.6f" % [prefix, float(result.get("max_seed_result_delta_degrees", INF))])
	lines.append("%s_passed=%s" % [prefix, str(bool(result.get("passed", false)))])
	return lines


func _get_bone_world_position(skeleton: Skeleton3D, bone_name: StringName) -> Vector3:
	var bone_index: int = skeleton.find_bone(String(bone_name)) if skeleton != null else -1
	if bone_index < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)


func _get_bone_world_basis(skeleton: Skeleton3D, bone_name: StringName) -> Basis:
	var bone_index: int = skeleton.find_bone(String(bone_name)) if skeleton != null else -1
	if bone_index < 0:
		return Basis.IDENTITY
	return (
		skeleton.global_basis * skeleton.get_bone_global_pose(bone_index).basis
	).orthonormalized()
