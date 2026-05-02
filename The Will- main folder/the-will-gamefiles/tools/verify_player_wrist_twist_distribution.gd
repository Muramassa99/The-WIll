extends SceneTree

const RigScene: PackedScene = preload("res://scenes/player/player_humanoid_rig.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_wrist_twist_distribution_results.txt"
const RIGHT_HAND_BONE := "CC_Base_R_Hand"
const LEFT_HAND_BONE := "CC_Base_L_Hand"
const RIGHT_FOREARM_BONE := "CC_Base_R_Forearm"
const LEFT_FOREARM_BONE := "CC_Base_L_Forearm"
const RIGHT_FOREARM_TWIST_BONES := ["CC_Base_R_ForearmTwist01", "CC_Base_R_ForearmTwist02"]
const LEFT_FOREARM_TWIST_BONES := ["CC_Base_L_ForearmTwist01", "CC_Base_L_ForearmTwist02"]
const RIGHT_UPPERARM_TWIST_BONES := ["CC_Base_R_UpperarmTwist01", "CC_Base_R_UpperarmTwist02"]
const LEFT_UPPERARM_TWIST_BONES := ["CC_Base_L_UpperarmTwist01", "CC_Base_L_UpperarmTwist02"]

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var rig_root: PlayerHumanoidRig = RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig_root)
	await process_frame
	await process_frame
	rig_root.set_authoring_preview_mode_enabled(true)
	rig_root.authoring_contact_wrist_straightness_bias = 0.0
	rig_root.authoring_contact_wrist_twist_limit_degrees = 90.0
	await process_frame

	var skeleton: Skeleton3D = rig_root.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D
	var initial_debug: Dictionary = rig_root.get_grip_contact_debug_state()
	var right_result: Dictionary = await _exercise_slot(
		rig_root,
		skeleton,
		&"hand_right",
		RIGHT_HAND_BONE,
		RIGHT_FOREARM_BONE,
		RIGHT_FOREARM_TWIST_BONES,
		RIGHT_UPPERARM_TWIST_BONES,
		deg_to_rad(54.0)
	)
	var left_result: Dictionary = await _exercise_slot(
		rig_root,
		skeleton,
		&"hand_left",
		LEFT_HAND_BONE,
		LEFT_FOREARM_BONE,
		LEFT_FOREARM_TWIST_BONES,
		LEFT_UPPERARM_TWIST_BONES,
		deg_to_rad(-54.0)
	)

	var right_ok: bool = bool(right_result.get("active", false)) \
		and int(right_result.get("applied_bone_count", 0)) >= 4 \
		and float(right_result.get("forearm_delta_radians", 0.0)) > 0.01 \
		and float(right_result.get("upperarm_delta_radians", 0.0)) > 0.001 \
		and float(right_result.get("hand_x_alignment", 0.0)) > 0.75
	var left_ok: bool = bool(left_result.get("active", false)) \
		and int(left_result.get("applied_bone_count", 0)) >= 4 \
		and float(left_result.get("forearm_delta_radians", 0.0)) > 0.01 \
		and float(left_result.get("upperarm_delta_radians", 0.0)) > 0.001 \
		and float(left_result.get("hand_x_alignment", 0.0)) > 0.75
	var all_checks_passed: bool = skeleton != null \
		and int(initial_debug.get("right_forearm_twist_bone_count", 0)) == 2 \
		and int(initial_debug.get("left_forearm_twist_bone_count", 0)) == 2 \
		and int(initial_debug.get("right_upperarm_twist_bone_count", 0)) == 2 \
		and int(initial_debug.get("left_upperarm_twist_bone_count", 0)) == 2 \
		and right_ok \
		and left_ok

	var lines: PackedStringArray = []
	lines.append("rig_loaded=%s" % str(rig_root != null))
	lines.append("skeleton_loaded=%s" % str(skeleton != null))
	lines.append("right_forearm_twist_bone_count=%d" % int(initial_debug.get("right_forearm_twist_bone_count", 0)))
	lines.append("left_forearm_twist_bone_count=%d" % int(initial_debug.get("left_forearm_twist_bone_count", 0)))
	lines.append("right_upperarm_twist_bone_count=%d" % int(initial_debug.get("right_upperarm_twist_bone_count", 0)))
	lines.append("left_upperarm_twist_bone_count=%d" % int(initial_debug.get("left_upperarm_twist_bone_count", 0)))
	lines.append_array(_result_lines("right", right_result))
	lines.append_array(_result_lines("left", left_result))
	lines.append("right_twist_distribution_ok=%s" % str(right_ok))
	lines.append("left_twist_distribution_ok=%s" % str(left_ok))
	lines.append("all_checks_passed=%s" % str(all_checks_passed))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _exercise_slot(
	rig_root: PlayerHumanoidRig,
	skeleton: Skeleton3D,
	slot_id: StringName,
	hand_bone: String,
	forearm_bone: String,
	forearm_twist_bones: Array,
	upperarm_twist_bones: Array,
	requested_twist_radians: float
) -> Dictionary:
	if rig_root == null or skeleton == null:
		return {}
	rig_root.reset_authoring_preview_baseline_pose()
	rig_root.set_authoring_preview_mode_enabled(true)
	await process_frame

	var hand_world: Vector3 = _get_bone_world_position(skeleton, hand_bone)
	var forearm_world: Vector3 = _get_bone_world_position(skeleton, forearm_bone)
	var twist_axis_world: Vector3 = hand_world - forearm_world
	if twist_axis_world.length_squared() <= 0.000001:
		return {}
	twist_axis_world = twist_axis_world.normalized()
	var target_node := Node3D.new()
	target_node.name = "%sTwistTarget" % String(slot_id)
	root.add_child(target_node)
	target_node.global_position = hand_world
	var finger_guide := Node3D.new()
	finger_guide.name = "%sTwistFingerGuide" % String(slot_id)
	root.add_child(finger_guide)
	finger_guide.global_position = hand_world

	var before_forearm: Dictionary = _capture_pose_rotations(skeleton, forearm_twist_bones)
	var before_upperarm: Dictionary = _capture_pose_rotations(skeleton, upperarm_twist_bones)
	var hand_basis_before: Basis = _get_bone_world_basis(skeleton, hand_bone)
	var desired_hand_basis: Basis = (Basis(twist_axis_world, requested_twist_radians) * hand_basis_before).orthonormalized()
	var hand_anchor: Node3D = rig_root.get_left_hand_item_anchor() if slot_id == &"hand_left" else rig_root.get_right_hand_item_anchor()
	var desired_anchor_basis: Basis = desired_hand_basis
	if hand_anchor != null:
		desired_anchor_basis = (desired_hand_basis * hand_anchor.transform.basis.orthonormalized()).orthonormalized()

	rig_root.set_arm_guidance_target(slot_id, target_node)
	rig_root.set_arm_guidance_active(slot_id, true)
	rig_root.set_finger_grip_target(slot_id, finger_guide)
	rig_root.set_authoring_contact_anchor_basis(slot_id, desired_anchor_basis)
	rig_root.apply_authoring_preview_frame_now()
	await process_frame
	rig_root.apply_authoring_preview_frame_now()
	await process_frame

	var debug_state: Dictionary = rig_root.get_grip_contact_debug_state()
	var prefix: String = "left" if slot_id == &"hand_left" else "right"
	var hand_basis_after: Basis = _get_bone_world_basis(skeleton, hand_bone)
	var expected_x_axis: Vector3 = desired_hand_basis.x - twist_axis_world * desired_hand_basis.x.dot(twist_axis_world)
	expected_x_axis = expected_x_axis.normalized() if expected_x_axis.length_squared() > 0.000001 else desired_hand_basis.x.normalized()
	return {
		"active": bool(debug_state.get("%s_authoring_twist_distribution_active" % prefix, false)),
		"requested_degrees": float(debug_state.get("%s_authoring_twist_requested_degrees" % prefix, 0.0)),
		"forearm_applied_degrees": float(debug_state.get("%s_authoring_forearm_twist_applied_degrees" % prefix, 0.0)),
		"upperarm_applied_degrees": float(debug_state.get("%s_authoring_upperarm_twist_applied_degrees" % prefix, 0.0)),
		"applied_bone_count": int(debug_state.get("%s_authoring_twist_bone_applied_count" % prefix, 0)),
		"forearm_delta_radians": _sum_pose_rotation_delta(skeleton, forearm_twist_bones, before_forearm),
		"upperarm_delta_radians": _sum_pose_rotation_delta(skeleton, upperarm_twist_bones, before_upperarm),
		"hand_y_alignment": hand_basis_after.y.normalized().dot(twist_axis_world),
		"hand_x_alignment": hand_basis_after.x.normalized().dot(expected_x_axis),
	}

func _capture_pose_rotations(skeleton: Skeleton3D, bone_names: Array) -> Dictionary:
	var rotations: Dictionary = {}
	if skeleton == null:
		return rotations
	for bone_name in bone_names:
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index >= 0:
			rotations[String(bone_name)] = skeleton.get_bone_pose_rotation(bone_index).normalized()
	return rotations

func _sum_pose_rotation_delta(skeleton: Skeleton3D, bone_names: Array, before_rotations: Dictionary) -> float:
	if skeleton == null:
		return 0.0
	var total_delta: float = 0.0
	for bone_name in bone_names:
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		var before_rotation: Quaternion = before_rotations.get(String(bone_name), Quaternion.IDENTITY) as Quaternion
		var after_rotation: Quaternion = skeleton.get_bone_pose_rotation(bone_index).normalized()
		total_delta += before_rotation.normalized().angle_to(after_rotation)
	return total_delta

func _result_lines(prefix: String, result: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append("%s_twist_active=%s" % [prefix, str(bool(result.get("active", false)))])
	lines.append("%s_twist_requested_degrees=%.4f" % [prefix, float(result.get("requested_degrees", 0.0))])
	lines.append("%s_forearm_twist_applied_degrees=%.4f" % [prefix, float(result.get("forearm_applied_degrees", 0.0))])
	lines.append("%s_upperarm_twist_applied_degrees=%.4f" % [prefix, float(result.get("upperarm_applied_degrees", 0.0))])
	lines.append("%s_twist_applied_bone_count=%d" % [prefix, int(result.get("applied_bone_count", 0))])
	lines.append("%s_forearm_twist_delta_radians=%.6f" % [prefix, float(result.get("forearm_delta_radians", 0.0))])
	lines.append("%s_upperarm_twist_delta_radians=%.6f" % [prefix, float(result.get("upperarm_delta_radians", 0.0))])
	lines.append("%s_hand_y_alignment=%.6f" % [prefix, float(result.get("hand_y_alignment", 0.0))])
	lines.append("%s_hand_x_alignment=%.6f" % [prefix, float(result.get("hand_x_alignment", 0.0))])
	return lines

func _get_bone_world_position(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var bone_index: int = skeleton.find_bone(bone_name)
	if bone_index < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)

func _get_bone_world_basis(skeleton: Skeleton3D, bone_name: String) -> Basis:
	if skeleton == null:
		return Basis.IDENTITY
	var bone_index: int = skeleton.find_bone(bone_name)
	if bone_index < 0:
		return Basis.IDENTITY
	return (skeleton.global_basis * skeleton.get_bone_global_pose(bone_index).basis).orthonormalized()
