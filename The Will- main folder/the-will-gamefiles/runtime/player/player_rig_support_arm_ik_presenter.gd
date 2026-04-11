extends RefCounted
class_name PlayerRigSupportArmIkPresenter

func ensure_support_arm_ik_modifiers(
	skeleton: Skeleton3D,
	right_arm_ik_modifier: TwoBoneIK3D,
	left_arm_ik_modifier: TwoBoneIK3D,
	right_hand_ik_target: Node3D,
	left_hand_ik_target: Node3D,
	right_hand_pole_target: Node3D,
	left_hand_pole_target: Node3D,
	right_upperarm_bone: StringName,
	right_forearm_bone: StringName,
	right_hand_bone: StringName,
	left_upperarm_bone: StringName,
	left_forearm_bone: StringName,
	left_hand_bone: StringName
) -> Dictionary:
	if skeleton == null:
		return {
			"right_arm_ik_modifier": right_arm_ik_modifier,
			"left_arm_ik_modifier": left_arm_ik_modifier,
		}
	right_arm_ik_modifier = ensure_two_bone_ik(
		skeleton,
		"RightArmIK",
		right_upperarm_bone,
		right_forearm_bone,
		right_hand_bone,
		right_hand_ik_target,
		right_hand_pole_target
	)
	left_arm_ik_modifier = ensure_two_bone_ik(
		skeleton,
		"LeftArmIK",
		left_upperarm_bone,
		left_forearm_bone,
		left_hand_bone,
		left_hand_ik_target,
		left_hand_pole_target
	)
	return {
		"right_arm_ik_modifier": right_arm_ik_modifier,
		"left_arm_ik_modifier": left_arm_ik_modifier,
	}

func ensure_two_bone_ik(
	skeleton: Skeleton3D,
	modifier_name: String,
	root_bone_name: StringName,
	middle_bone_name: StringName,
	end_bone_name: StringName,
	target_node: Node3D,
	pole_node: Node3D
) -> TwoBoneIK3D:
	var modifier: TwoBoneIK3D = skeleton.get_node_or_null(modifier_name) as TwoBoneIK3D
	if modifier == null:
		modifier = TwoBoneIK3D.new()
		modifier.name = modifier_name
		skeleton.add_child(modifier)
	modifier.setting_count = 1
	var root_bone_idx: int = skeleton.find_bone(String(root_bone_name))
	var middle_bone_idx: int = skeleton.find_bone(String(middle_bone_name))
	var end_bone_idx: int = skeleton.find_bone(String(end_bone_name))
	if root_bone_idx >= 0:
		modifier.set_root_bone(0, root_bone_idx)
	modifier.set_root_bone_name(0, String(root_bone_name))
	if middle_bone_idx >= 0:
		modifier.set_middle_bone(0, middle_bone_idx)
	modifier.set_middle_bone_name(0, String(middle_bone_name))
	if end_bone_idx >= 0:
		modifier.set_end_bone(0, end_bone_idx)
	modifier.set_end_bone_name(0, String(end_bone_name))
	if target_node != null:
		modifier.set_target_node(0, target_node.get_path())
	if pole_node != null:
		modifier.set_pole_node(0, pole_node.get_path())
	modifier.active = true
	modifier.influence = 0.0
	return modifier

func snap_support_arm_ik_targets_to_current_pose(
	skeleton: Skeleton3D,
	right_hand_ik_target: Node3D,
	left_hand_ik_target: Node3D,
	right_hand_pole_target: Node3D,
	left_hand_pole_target: Node3D,
	right_hand_bone: StringName,
	left_hand_bone: StringName,
	right_forearm_bone: StringName,
	left_forearm_bone: StringName,
	get_bone_world_position_callable: Callable
) -> void:
	if skeleton == null:
		return
	if right_hand_ik_target != null:
		right_hand_ik_target.global_position = get_bone_world_position_callable.call(right_hand_bone)
	if left_hand_ik_target != null:
		left_hand_ik_target.global_position = get_bone_world_position_callable.call(left_hand_bone)
	if right_hand_pole_target != null:
		right_hand_pole_target.global_position = get_bone_world_position_callable.call(right_forearm_bone)
	if left_hand_pole_target != null:
		left_hand_pole_target.global_position = get_bone_world_position_callable.call(left_forearm_bone)

func update_support_arm_ik_targets(
	skeleton: Skeleton3D,
	enable_support_arm_ik: bool,
	config: Dictionary,
	global_basis: Basis,
	right_hand_ik_target: Node3D,
	left_hand_ik_target: Node3D,
	right_hand_pole_target: Node3D,
	left_hand_pole_target: Node3D,
	right_hand_guidance_target: Node3D,
	left_hand_guidance_target: Node3D,
	right_hand_anchor_node: Node3D,
	left_hand_anchor_node: Node3D,
	right_upperarm_bone: StringName,
	left_upperarm_bone: StringName,
	right_forearm_bone: StringName,
	left_forearm_bone: StringName,
	right_hand_bone: StringName,
	left_hand_bone: StringName,
	get_bone_world_position_callable: Callable,
	delta: float
) -> void:
	if skeleton == null or not enable_support_arm_ik:
		return
	update_support_arm_ik_target_for_side(
		right_hand_ik_target,
		right_hand_pole_target,
		right_upperarm_bone,
		right_forearm_bone,
		right_hand_bone,
		right_hand_guidance_target,
		right_hand_anchor_node,
		1.0,
		config,
		global_basis,
		get_bone_world_position_callable,
		delta
	)
	update_support_arm_ik_target_for_side(
		left_hand_ik_target,
		left_hand_pole_target,
		left_upperarm_bone,
		left_forearm_bone,
		left_hand_bone,
		left_hand_guidance_target,
		left_hand_anchor_node,
		-1.0,
		config,
		global_basis,
		get_bone_world_position_callable,
		delta
	)

func refresh_support_arm_ik_influences(
	enable_support_arm_ik: bool,
	support_arm_ik_influence: float,
	right_arm_ik_modifier: SkeletonModifier3D,
	left_arm_ik_modifier: SkeletonModifier3D,
	right_hand_support_active: bool,
	left_hand_support_active: bool,
	right_hand_guidance_target: Node3D,
	left_hand_guidance_target: Node3D
) -> void:
	set_modifier_runtime_state(
		right_arm_ik_modifier,
		slot_requires_support_arm_ik(enable_support_arm_ik, right_hand_support_active, right_hand_guidance_target),
		support_arm_ik_influence
	)
	set_modifier_runtime_state(
		left_arm_ik_modifier,
		slot_requires_support_arm_ik(enable_support_arm_ik, left_hand_support_active, left_hand_guidance_target),
		support_arm_ik_influence
	)

func update_support_arm_ik_target_for_side(
	target_node: Node3D,
	pole_node: Node3D,
	upperarm_bone_name: StringName,
	forearm_bone_name: StringName,
	hand_bone_name: StringName,
	guidance_target: Node3D,
	hand_anchor_node: Node3D,
	side_sign: float,
	config: Dictionary,
	global_basis: Basis,
	get_bone_world_position_callable: Callable,
	delta: float
) -> void:
	if target_node == null or pole_node == null or guidance_target == null or not is_instance_valid(guidance_target):
		return
	var current_hand_position: Vector3 = get_bone_world_position_callable.call(hand_bone_name)
	var desired_target: Vector3 = guidance_target.global_position
	if hand_anchor_node != null and is_instance_valid(hand_anchor_node):
		desired_target -= hand_anchor_node.global_position - current_hand_position
	var shoulder_position: Vector3 = get_bone_world_position_callable.call(upperarm_bone_name)
	var forearm_position: Vector3 = get_bone_world_position_callable.call(forearm_bone_name)
	var body_right: Vector3 = global_basis.x.normalized()
	var body_up: Vector3 = global_basis.y.normalized()
	var shoulder_to_target: Vector3 = desired_target - shoulder_position
	var forward_reference: Vector3 = shoulder_to_target.normalized() if not shoulder_to_target.is_zero_approx() else global_basis.z.normalized()
	var desired_pole: Vector3 = forearm_position \
		+ body_right * float(config.get("support_arm_ik_pole_side_offset_meters", 0.24)) * side_sign \
		- body_up * float(config.get("support_arm_ik_pole_down_offset_meters", 0.18)) \
		- forward_reference * float(config.get("support_arm_ik_pole_back_offset_meters", 0.08))
	move_ik_target_toward(target_node, desired_target, float(config.get("support_arm_ik_target_smoothing_speed", 12.0)), delta)
	move_ik_target_toward(pole_node, desired_pole, float(config.get("support_arm_ik_target_smoothing_speed", 12.0)), delta)

func slot_requires_support_arm_ik(enable_support_arm_ik: bool, support_hand_active: bool, guidance_target: Node3D) -> bool:
	if not enable_support_arm_ik:
		return false
	return support_hand_active and guidance_target != null and is_instance_valid(guidance_target)

func set_modifier_runtime_state(modifier: SkeletonModifier3D, enabled: bool, influence_value: float) -> void:
	if modifier == null:
		return
	modifier.active = enabled
	modifier.influence = influence_value if enabled else 0.0

func move_ik_target_toward(target_node: Node3D, desired_global_position: Vector3, smoothing_speed: float, delta: float) -> void:
	if target_node == null:
		return
	var blend_factor: float = clampf(smoothing_speed * delta, 0.0, 1.0)
	target_node.global_position = target_node.global_position.lerp(desired_global_position, blend_factor)

func apply_solved_arm_targets(
	target_node: Node3D,
	pole_node: Node3D,
	corrected_target_world: Vector3,
	pole_target_world: Vector3,
	smoothing_speed: float,
	delta: float
) -> void:
	move_ik_target_toward(target_node, corrected_target_world, smoothing_speed, delta)
	move_ik_target_toward(pole_node, pole_target_world, smoothing_speed, delta)
