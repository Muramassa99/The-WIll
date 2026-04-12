extends RefCounted
class_name TwoHandPoseSolver

const SLOT_RIGHT: StringName = &"hand_right"
const SLOT_LEFT: StringName = &"hand_left"
const TORSO_WAIST_BONE: StringName = &"CC_Base_Waist"
const TORSO_CHEST_BONE: StringName = &"CC_Base_Spine02"

func solve_arm_targets(
	skeleton: Skeleton3D,
	body_restriction_root: Node3D,
	dominant_slot_id: StringName,
	global_basis: Basis,
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
	constraint_solver,
	settings: Dictionary = {}
) -> Dictionary:
	var result := {
		SLOT_RIGHT: {"active": false},
		SLOT_LEFT: {"active": false},
		"torso_frame": {},
	}
	if skeleton == null or constraint_solver == null:
		return result
	var torso_frame: Dictionary = _resolve_torso_frame(skeleton, global_basis, get_bone_world_position_callable)
	result["torso_frame"] = torso_frame
	var ordered_slots: Array[StringName] = []
	if dominant_slot_id == SLOT_RIGHT or dominant_slot_id == SLOT_LEFT:
		ordered_slots.append(dominant_slot_id)
	var secondary_slot: StringName = SLOT_LEFT if dominant_slot_id == SLOT_RIGHT else SLOT_RIGHT
	if not ordered_slots.has(secondary_slot):
		ordered_slots.append(secondary_slot)
	for slot_id: StringName in [SLOT_RIGHT, SLOT_LEFT]:
		if not ordered_slots.has(slot_id):
			ordered_slots.append(slot_id)
	for slot_id: StringName in ordered_slots:
		var guidance_target: Node3D = right_hand_guidance_target if slot_id == SLOT_RIGHT else left_hand_guidance_target
		if guidance_target == null or not is_instance_valid(guidance_target):
			continue
		var hand_anchor_node: Node3D = right_hand_anchor_node if slot_id == SLOT_RIGHT else left_hand_anchor_node
		var upperarm_bone_name: StringName = right_upperarm_bone if slot_id == SLOT_RIGHT else left_upperarm_bone
		var forearm_bone_name: StringName = right_forearm_bone if slot_id == SLOT_RIGHT else left_forearm_bone
		var hand_bone_name: StringName = right_hand_bone if slot_id == SLOT_RIGHT else left_hand_bone
		var side_sign: float = 1.0 if slot_id == SLOT_RIGHT else -1.0
		var current_hand_world: Vector3 = get_bone_world_position_callable.call(hand_bone_name)
		var desired_target: Vector3 = guidance_target.global_position
		var slot_is_dominant: bool = slot_id == dominant_slot_id
		if slot_is_dominant and hand_anchor_node != null and is_instance_valid(hand_anchor_node):
			desired_target -= hand_anchor_node.global_position - current_hand_world
		var source_world: Vector3 = get_bone_world_position_callable.call(upperarm_bone_name)
		var weapon_body_proxy_samples: Array[Vector3] = _collect_weapon_body_proxy_sample_positions(guidance_target)
		var projection: Dictionary = constraint_solver.project_target_to_legal_grip_space(
			body_restriction_root,
			source_world,
			desired_target,
			torso_frame.get("origin_world", Vector3.ZERO),
			torso_frame.get("forward_world", -global_basis.z),
			torso_frame.get("right_world", global_basis.x),
			torso_frame.get("up_world", global_basis.y),
			settings
		)
		var corrected_target: Vector3 = projection.get("corrected_target", desired_target) as Vector3
		if not slot_is_dominant and _weapon_body_proxy_intersects_body(body_restriction_root, guidance_target):
			var forward_push: float = maxf(
				float(settings.get("front_bias_amount", 0.18)) * 0.35,
				float(settings.get("safety_margin_meters", 0.08))
			)
			corrected_target += (torso_frame.get("forward_world", -global_basis.z) as Vector3).normalized() * forward_push
			projection["weapon_body_illegal"] = true
		else:
			projection["weapon_body_illegal"] = false
		var forearm_world: Vector3 = get_bone_world_position_callable.call(forearm_bone_name)
		var pole_target: Vector3 = _resolve_pole_target(
			forearm_world,
			source_world,
			corrected_target,
			torso_frame.get("right_world", global_basis.x),
			torso_frame.get("up_world", global_basis.y),
			side_sign,
			settings
		)
		result[slot_id] = {
			"active": true,
			"desired_target": desired_target,
			"corrected_target": corrected_target,
			"pole_target": pole_target,
			"projection": projection,
			"weapon_body_proxy_samples": weapon_body_proxy_samples,
			"weapon_body_illegal": bool(projection.get("weapon_body_illegal", false)),
		}
	return result

func _resolve_torso_frame(
	_skeleton: Skeleton3D,
	global_basis: Basis,
	get_bone_world_position_callable: Callable
) -> Dictionary:
	var waist_world: Vector3 = get_bone_world_position_callable.call(TORSO_WAIST_BONE)
	var chest_world: Vector3 = get_bone_world_position_callable.call(TORSO_CHEST_BONE)
	var origin_world: Vector3 = chest_world if chest_world.length_squared() > 0.000001 else waist_world
	if origin_world.length_squared() <= 0.000001:
		origin_world = Vector3.ZERO
	var forward_world: Vector3 = (-global_basis.z).normalized()
	var right_world: Vector3 = global_basis.x.normalized()
	var up_world: Vector3 = global_basis.y.normalized()
	return {
		"origin_world": origin_world,
		"waist_world": waist_world,
		"chest_world": chest_world,
		"forward_world": forward_world,
		"right_world": right_world,
		"up_world": up_world,
	}

func _resolve_pole_target(
	forearm_world: Vector3,
	shoulder_world: Vector3,
	corrected_target: Vector3,
	body_right_world: Vector3,
	body_up_world: Vector3,
	side_sign: float,
	settings: Dictionary
) -> Vector3:
	var shoulder_to_target: Vector3 = corrected_target - shoulder_world
	var forward_reference: Vector3 = shoulder_to_target.normalized()
	if forward_reference.length_squared() <= 0.000001:
		forward_reference = -body_up_world.cross(body_right_world).normalized()
	var pole_side_offset: float = float(settings.get("elbow_pole_side_offset_meters", 0.24))
	var pole_down_offset: float = float(settings.get("elbow_pole_down_offset_meters", 0.18))
	var pole_back_offset: float = float(settings.get("elbow_pole_back_offset_meters", 0.08))
	return forearm_world \
		+ body_right_world * pole_side_offset * side_sign \
		- body_up_world * pole_down_offset \
		- forward_reference * pole_back_offset

func _weapon_body_proxy_intersects_body(body_restriction_root: Node3D, guidance_target: Node3D) -> bool:
	if body_restriction_root == null or guidance_target == null:
		return false
	for sample_world: Vector3 in _collect_weapon_body_proxy_sample_positions(guidance_target):
		if _point_inside_body_restriction(body_restriction_root, sample_world):
			return true
	return false

func _collect_weapon_body_proxy_sample_positions(guidance_target: Node3D) -> Array[Vector3]:
	var sample_positions: Array[Vector3] = []
	if guidance_target == null:
		return sample_positions
	var held_root: Node = guidance_target.get_parent()
	if held_root == null:
		return sample_positions
	var proxy_root: Node3D = held_root.get_node_or_null("WeaponBodyRestrictionProxy") as Node3D
	if proxy_root == null:
		return sample_positions
	for sample_node: Node in proxy_root.get_children():
		var sample: Node3D = sample_node as Node3D
		if sample == null:
			continue
		sample_positions.append(sample.global_position)
	return sample_positions

func _point_inside_body_restriction(body_restriction_root: Node3D, point_world: Vector3) -> bool:
	if body_restriction_root == null:
		return false
	for attachment_node: Node in body_restriction_root.get_children():
		var attachment: Node3D = attachment_node as Node3D
		if attachment == null:
			continue
		var area: Area3D = attachment.get_node_or_null("RestrictionArea") as Area3D
		if area == null:
			continue
		var collision_shape: CollisionShape3D = area.get_node_or_null("RestrictionShape") as CollisionShape3D
		if collision_shape == null:
			continue
		var box_shape: BoxShape3D = collision_shape.shape as BoxShape3D
		if box_shape == null:
			continue
		var local_point: Vector3 = collision_shape.global_transform.affine_inverse() * point_world
		var half_size: Vector3 = box_shape.size * 0.5
		if absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y and absf(local_point.z) <= half_size.z:
			return true
	return false
