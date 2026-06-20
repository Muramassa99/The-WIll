extends SceneTree

const PlayerHumanoidRigScene: PackedScene = preload("res://scenes/player/player_humanoid_rig.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/verify_runtime_solved_replay_modifier_authority_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var rig = PlayerHumanoidRigScene.instantiate()
	root.add_child(rig)
	await process_frame

	var skeleton: Skeleton3D = rig.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D
	var modifier: SkeletonModifier3D = skeleton.get_node_or_null("RuntimeSolvedReplayModifier") as SkeletonModifier3D if skeleton != null else null
	var right_arm_ik_modifier: SkeletonModifier3D = skeleton.get_node_or_null("RightArmIK") as SkeletonModifier3D if skeleton != null else null
	var left_arm_ik_modifier: SkeletonModifier3D = skeleton.get_node_or_null("LeftArmIK") as SkeletonModifier3D if skeleton != null else null
	var body_restriction_modifier: SkeletonModifier3D = skeleton.get_node_or_null("RuntimeBodyRestrictionSyncModifier") as SkeletonModifier3D if skeleton != null else null
	var bone_debug_modifier: SkeletonModifier3D = skeleton.get_node_or_null("RuntimeBoneDebugModifier") as SkeletonModifier3D if skeleton != null else null
	var solved_after_arm_ik: bool = (
		_modifier_index(modifier) > _modifier_index(right_arm_ik_modifier)
		and _modifier_index(modifier) > _modifier_index(left_arm_ik_modifier)
	)
	var body_restriction_after_solved: bool = _modifier_index(body_restriction_modifier) > _modifier_index(modifier)
	var debug_after_body_restriction: bool = _modifier_index(bone_debug_modifier) > _modifier_index(body_restriction_modifier)
	var bone_names: Array[StringName] = [&"CC_Base_Hip", &"CC_Base_Spine02", &"CC_Base_R_Hand"]
	var bone_positions: Array[Vector3] = [
		Vector3(0.02, -0.01, 1.17),
		Vector3(0.0, 0.08, 0.0),
		Vector3(0.04, 0.02, -0.03),
	]
	var solved_hand_rotation := Quaternion(Vector3.FORWARD, 0.65).normalized()
	var bone_rotations: Array[Quaternion] = [
		Quaternion.IDENTITY,
		Quaternion(Vector3.RIGHT, 0.2).normalized(),
		solved_hand_rotation,
	]
	var bone_scales: Array[Vector3] = [Vector3.ONE, Vector3.ONE, Vector3.ONE]

	var first_apply: bool = bool(rig.call(
		"apply_runtime_solved_upper_body_pose_frame",
		bone_names,
		bone_positions,
		bone_rotations,
		bone_scales,
		1.0
	))
	var modifier_active_after_apply: bool = modifier != null and modifier.active

	var hand_index: int = skeleton.find_bone("CC_Base_R_Hand") if skeleton != null else -1
	if hand_index >= 0:
		skeleton.set_bone_pose_rotation(hand_index, Quaternion(Vector3.UP, 1.35).normalized())
		skeleton.force_update_all_bone_transforms()
	rig.call("process_runtime_solved_replay_modifier_frame", 1.0 / 60.0)
	var restored_error: float = _rotation_error(
		skeleton.get_bone_pose_rotation(hand_index).normalized() if hand_index >= 0 else Quaternion.IDENTITY,
		solved_hand_rotation
	)

	var weapon := Node3D.new()
	weapon.name = "SolvedReplayAuthorityWeapon"
	var primary_anchor := Node3D.new()
	primary_anchor.name = "PrimaryGripAnchor"
	weapon.add_child(primary_anchor)
	rig.add_child(weapon)
	var weapon_position_reference_local := Vector3(0.18, 0.42, -0.13)
	var weapon_rotation_reference_local := Quaternion(Vector3.UP, 0.45).normalized()
	var weapon_scale_reference_local := Vector3.ONE
	var anchor_position_weapon_local := Vector3(0.03, 0.04, -0.02)
	var weapon_registered: bool = bool(rig.call(
		"set_runtime_solved_replay_weapon_frame",
		weapon,
		&"RL_BoneRoot",
		weapon_position_reference_local,
		weapon_rotation_reference_local,
		weapon_scale_reference_local,
		[&"PrimaryGripAnchor"],
		[anchor_position_weapon_local],
		[Quaternion.IDENTITY],
		[Vector3.ONE]
	))
	weapon.global_transform = Transform3D(Basis(Quaternion(Vector3.RIGHT, 1.2)), Vector3(9.0, 9.0, 9.0))
	primary_anchor.position = Vector3(1.0, 1.0, 1.0)
	rig.call("process_runtime_solved_replay_modifier_frame", 1.0 / 60.0)
	var expected_weapon_transform: Transform3D = (
		_resolve_bone_world_transform(skeleton, &"RL_BoneRoot")
		* Transform3D(Basis(weapon_rotation_reference_local), weapon_position_reference_local)
	)
	var weapon_origin_error: float = weapon.global_position.distance_to(expected_weapon_transform.origin)
	var weapon_rotation_error: float = _rotation_error(
		weapon.global_basis.orthonormalized().get_rotation_quaternion(),
		expected_weapon_transform.basis.orthonormalized().get_rotation_quaternion()
	)
	var expected_anchor_position: Vector3 = weapon.global_transform * anchor_position_weapon_local
	var anchor_origin_error: float = primary_anchor.global_position.distance_to(expected_anchor_position)

	rig.call("clear_runtime_solved_replay_pose_frame")
	var modifier_inactive_after_clear: bool = modifier == null or not modifier.active
	root.remove_child(rig)
	rig.queue_free()

	var all_checks_passed: bool = (
		first_apply
		and modifier_active_after_apply
		and restored_error <= 0.0001
		and weapon_registered
		and weapon_origin_error <= 0.0001
		and weapon_rotation_error <= 0.0001
		and anchor_origin_error <= 0.0001
		and modifier_inactive_after_clear
		and solved_after_arm_ik
		and body_restriction_after_solved
		and debug_after_body_restriction
	)
	var lines: PackedStringArray = []
	lines.append("first_apply=%s" % str(first_apply))
	lines.append("modifier_exists=%s" % str(modifier != null))
	lines.append("solved_after_arm_ik=%s" % str(solved_after_arm_ik))
	lines.append("body_restriction_after_solved=%s" % str(body_restriction_after_solved))
	lines.append("debug_after_body_restriction=%s" % str(debug_after_body_restriction))
	lines.append("modifier_active_after_apply=%s" % str(modifier_active_after_apply))
	lines.append("restored_error=%0.6f" % restored_error)
	lines.append("weapon_registered=%s" % str(weapon_registered))
	lines.append("weapon_origin_error=%0.6f" % weapon_origin_error)
	lines.append("weapon_rotation_error=%0.6f" % weapon_rotation_error)
	lines.append("anchor_origin_error=%0.6f" % anchor_origin_error)
	lines.append("modifier_inactive_after_clear=%s" % str(modifier_inactive_after_clear))
	lines.append("all_checks_passed=%s" % str(all_checks_passed))
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(0 if all_checks_passed else 1)

func _rotation_error(a: Quaternion, b: Quaternion) -> float:
	return absf(1.0 - absf(a.normalized().dot(b.normalized())))

func _modifier_index(modifier: SkeletonModifier3D) -> int:
	if modifier == null or not is_instance_valid(modifier):
		return -1
	return modifier.get_index()

func _resolve_bone_world_transform(skeleton: Skeleton3D, bone_name: StringName) -> Transform3D:
	if skeleton == null:
		return Transform3D.IDENTITY
	var bone_index: int = skeleton.find_bone(String(bone_name))
	if bone_index < 0:
		return Transform3D.IDENTITY
	var world_pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)
	return Transform3D(world_pose.basis.orthonormalized(), world_pose.origin)
