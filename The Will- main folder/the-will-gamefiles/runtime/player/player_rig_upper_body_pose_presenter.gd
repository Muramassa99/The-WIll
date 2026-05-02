extends RefCounted
class_name PlayerRigUpperBodyPosePresenter

const JosieRigScene = preload("res://Josie/josie.tscn")
const CharacterFrameResolverScript = preload("res://runtime/player/character_frame_resolver.gd")

const SLOT_RIGHT: StringName = &"hand_right"
const SLOT_LEFT: StringName = &"hand_left"

const IDLE_BASELINE_ANIMATION_NAME: StringName = &"Idle"
const TWO_HAND_BASELINE_ANIMATION_NAME: StringName = &"2 Hand Idle"
const BASELINE_SAMPLE_RATIO: float = 0.5

const POSE_IDLE: StringName = &"idle"
const POSE_TWO_HAND: StringName = &"two_hand"

const WAIST_BONE: StringName = &"CC_Base_Waist"
const SPINE_01_BONE: StringName = &"CC_Base_Spine01"
const SPINE_02_BONE: StringName = &"CC_Base_Spine02"
const LEFT_CLAVICLE_BONE: StringName = &"CC_Base_L_Clavicle"
const RIGHT_CLAVICLE_BONE: StringName = &"CC_Base_R_Clavicle"
const LEFT_UPPERARM_BONE: StringName = &"CC_Base_L_Upperarm"
const RIGHT_UPPERARM_BONE: StringName = &"CC_Base_R_Upperarm"
const LEFT_FOREARM_BONE: StringName = &"CC_Base_L_Forearm"
const RIGHT_FOREARM_BONE: StringName = &"CC_Base_R_Forearm"

const TORSO_BONES: Array[StringName] = [
	WAIST_BONE,
	SPINE_01_BONE,
	SPINE_02_BONE,
]

const SHOULDER_BONES: Array[StringName] = [
	LEFT_CLAVICLE_BONE,
	RIGHT_CLAVICLE_BONE,
]

const BASELINE_BONES: Array[StringName] = [
	WAIST_BONE,
	SPINE_01_BONE,
	SPINE_02_BONE,
	LEFT_CLAVICLE_BONE,
	RIGHT_CLAVICLE_BONE,
	LEFT_UPPERARM_BONE,
	RIGHT_UPPERARM_BONE,
	LEFT_FOREARM_BONE,
	RIGHT_FOREARM_BONE,
]

const DIRECTION_WEIGHTS := {
	WAIST_BONE: Vector2(0.26, 0.12),
	SPINE_01_BONE: Vector2(0.44, 0.20),
	SPINE_02_BONE: Vector2(0.62, 0.30),
	LEFT_CLAVICLE_BONE: Vector2(0.46, 0.26),
	RIGHT_CLAVICLE_BONE: Vector2(0.46, 0.26),
	LEFT_UPPERARM_BONE: Vector2(0.82, 0.48),
	RIGHT_UPPERARM_BONE: Vector2(0.82, 0.48),
	LEFT_FOREARM_BONE: Vector2(0.72, 0.42),
	RIGHT_FOREARM_BONE: Vector2(0.72, 0.42),
}

const APPLICATION_WEIGHTS := {
	WAIST_BONE: 0.68,
	SPINE_01_BONE: 0.82,
	SPINE_02_BONE: 0.94,
	LEFT_CLAVICLE_BONE: 1.00,
	RIGHT_CLAVICLE_BONE: 1.00,
	LEFT_UPPERARM_BONE: 1.00,
	RIGHT_UPPERARM_BONE: 1.00,
	LEFT_FOREARM_BONE: 0.94,
	RIGHT_FOREARM_BONE: 0.94,
}

const ONE_HAND_BASE_SUPPORT_BLEND: float = 0.52
const TWO_HAND_BASE_SUPPORT_BLEND: float = 0.74
const TORSO_MAX_ONE_HAND_YAW_DEGREES: float = 34.0
const TORSO_MAX_TWO_HAND_YAW_DEGREES: float = 52.0
const TORSO_MAX_ONE_HAND_PITCH_DEGREES: float = 22.0
const TORSO_MAX_TWO_HAND_PITCH_DEGREES: float = 34.0
const SHOULDER_MAX_ONE_HAND_YAW_DEGREES: float = 62.0
const SHOULDER_MAX_TWO_HAND_YAW_DEGREES: float = 78.0
const SHOULDER_MAX_ONE_HAND_PITCH_DEGREES: float = 38.0
const SHOULDER_MAX_TWO_HAND_PITCH_DEGREES: float = 52.0

var upper_body_pose_cache: Dictionary = {}
var upper_body_pose_cache_initialized: bool = false
var character_frame_resolver = CharacterFrameResolverScript.new()

func warm_cache() -> void:
	_ensure_upper_body_pose_cache()

func apply_upper_body_authoring_pose(
	skeleton: Skeleton3D,
	actor_global_basis: Basis,
	state: Dictionary
) -> void:
	if skeleton == null:
		return
	if not bool(state.get("active", false)):
		return
	_ensure_upper_body_pose_cache()
	var strength_scale: float = clampf(float(state.get("strength_scale", 1.0)), 0.0, 1.0)
	if strength_scale <= 0.00001:
		return
	var two_hand: bool = bool(state.get("two_hand", false))
	var authored_blend: float = clampf(float(state.get("blend", 0.0)), 0.0, 1.0)
	var resolved_blend: float = _resolve_effective_support_blend(two_hand, authored_blend) * strength_scale
	if resolved_blend <= 0.00001:
		return
	var pose_blend: float = resolved_blend if two_hand else 0.0
	var torso_origin_world: Vector3 = _get_bone_world_position(skeleton, SPINE_02_BONE)
	if torso_origin_world.length_squared() <= 0.000001:
		torso_origin_world = skeleton.global_position
	var body_frame: Dictionary = character_frame_resolver.resolve_basis_frame(actor_global_basis)
	var body_forward_world: Vector3 = body_frame.get(
		"forward_world",
		character_frame_resolver.get_default_forward_world()
	) as Vector3
	var body_up_world: Vector3 = body_frame.get("up_world", actor_global_basis.y.normalized()) as Vector3
	var body_right_world: Vector3 = body_frame.get("right_world", actor_global_basis.x.normalized()) as Vector3
	var pose_context: Dictionary = _resolve_pose_context(
		state,
		torso_origin_world,
		body_forward_world
	)
	var torso_forward_world: Vector3 = pose_context.get("torso_forward_world", body_forward_world) as Vector3
	var shoulder_forward_world: Vector3 = pose_context.get("shoulder_forward_world", torso_forward_world) as Vector3
	var reach_ratio: float = float(pose_context.get("reach_ratio", 0.0))
	var torso_local_direction: Vector3 = actor_global_basis.inverse() * torso_forward_world
	var shoulder_local_direction: Vector3 = actor_global_basis.inverse() * shoulder_forward_world
	var torso_yaw_degrees: float = _resolve_local_direction_yaw_degrees(
		torso_local_direction,
		TORSO_MAX_TWO_HAND_YAW_DEGREES if two_hand else TORSO_MAX_ONE_HAND_YAW_DEGREES,
		reach_ratio
	)
	var torso_pitch_degrees: float = _resolve_local_direction_pitch_degrees(
		torso_local_direction,
		TORSO_MAX_TWO_HAND_PITCH_DEGREES if two_hand else TORSO_MAX_ONE_HAND_PITCH_DEGREES,
		reach_ratio
	)
	var shoulder_yaw_degrees: float = _resolve_local_direction_yaw_degrees(
		shoulder_local_direction,
		SHOULDER_MAX_TWO_HAND_YAW_DEGREES if two_hand else SHOULDER_MAX_ONE_HAND_YAW_DEGREES,
		reach_ratio
	)
	var shoulder_pitch_degrees: float = _resolve_local_direction_pitch_degrees(
		shoulder_local_direction,
		SHOULDER_MAX_TWO_HAND_PITCH_DEGREES if two_hand else SHOULDER_MAX_ONE_HAND_PITCH_DEGREES,
		reach_ratio
	)
	_apply_bone_group(
		skeleton,
		TORSO_BONES,
		pose_blend,
		resolved_blend,
		torso_yaw_degrees,
		torso_pitch_degrees,
		body_up_world,
		body_right_world,
		state.get("dominant_slot_id", SLOT_RIGHT) as StringName,
		two_hand
	)
	skeleton.force_update_all_bone_transforms()
	_apply_bone_group(
		skeleton,
		SHOULDER_BONES,
		pose_blend,
		resolved_blend,
		shoulder_yaw_degrees,
		shoulder_pitch_degrees,
		body_up_world,
		body_right_world,
		state.get("dominant_slot_id", SLOT_RIGHT) as StringName,
		two_hand
	)
	skeleton.force_update_all_bone_transforms()

func _ensure_upper_body_pose_cache() -> void:
	if upper_body_pose_cache_initialized:
		return
	upper_body_pose_cache_initialized = true
	upper_body_pose_cache[POSE_IDLE] = _sample_animation_upper_body_pose(
		IDLE_BASELINE_ANIMATION_NAME,
		BASELINE_SAMPLE_RATIO
	)
	upper_body_pose_cache[POSE_TWO_HAND] = _sample_animation_upper_body_pose(
		TWO_HAND_BASELINE_ANIMATION_NAME,
		BASELINE_SAMPLE_RATIO
	)

func _sample_animation_upper_body_pose(animation_name: StringName, sample_ratio: float) -> Dictionary:
	var josie_root: Node3D = JosieRigScene.instantiate() as Node3D
	if josie_root == null:
		return {}
	var animation_player: AnimationPlayer = josie_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var skeleton: Skeleton3D = josie_root.get_node_or_null("Josie/Skeleton3D") as Skeleton3D
	if animation_player == null or skeleton == null or not animation_player.has_animation(String(animation_name)):
		josie_root.free()
		return {}
	var animation: Animation = animation_player.get_animation(String(animation_name))
	if animation == null:
		josie_root.free()
		return {}
	animation_player.play(String(animation_name))
	animation_player.advance(animation.length * clampf(sample_ratio, 0.0, 1.0))
	skeleton.force_update_all_bone_transforms()
	var rotation_lookup: Dictionary = {}
	for bone_name: StringName in BASELINE_BONES:
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		rotation_lookup[bone_name] = skeleton.get_bone_pose_rotation(bone_index).normalized()
	josie_root.free()
	return rotation_lookup

func _resolve_effective_support_blend(two_hand: bool, authored_blend: float) -> float:
	var base_support: float = TWO_HAND_BASE_SUPPORT_BLEND if two_hand else ONE_HAND_BASE_SUPPORT_BLEND
	return clampf(base_support + authored_blend * (1.0 - base_support), 0.0, 1.0)

func _resolve_pose_context(
	state: Dictionary,
	torso_origin_world: Vector3,
	fallback_forward_world: Vector3
) -> Dictionary:
	var primary_target_world: Vector3 = state.get("primary_target_world", Vector3.ZERO) as Vector3
	var secondary_target_world: Vector3 = state.get("secondary_target_world", Vector3.ZERO) as Vector3
	var tip_world: Vector3 = state.get("tip_world", Vector3.ZERO) as Vector3
	var pommel_world: Vector3 = state.get("pommel_world", Vector3.ZERO) as Vector3
	var weapon_center_world: Vector3 = tip_world.lerp(pommel_world, 0.5)
	var weapon_axis_world: Vector3 = tip_world - pommel_world
	var has_weapon_segment: bool = weapon_axis_world.length_squared() > 0.000001
	var weapon_drive_target_world: Vector3 = weapon_center_world
	if has_weapon_segment and primary_target_world.length_squared() > 0.000001:
		weapon_drive_target_world = primary_target_world.lerp(weapon_center_world, 0.72)
	var torso_target_world: Vector3 = primary_target_world
	if has_weapon_segment and weapon_drive_target_world.length_squared() > 0.000001:
		torso_target_world = weapon_drive_target_world
	if torso_target_world.length_squared() <= 0.000001:
		torso_target_world = weapon_center_world
	if secondary_target_world.length_squared() > 0.000001:
		if torso_target_world.length_squared() > 0.000001:
			torso_target_world = torso_target_world.lerp(secondary_target_world, 0.35)
		else:
			torso_target_world = secondary_target_world
	var shoulder_target_world: Vector3 = primary_target_world
	if has_weapon_segment:
		var forward_weighted_weapon_target: Vector3 = weapon_center_world.lerp(tip_world, 0.30)
		shoulder_target_world = (
			primary_target_world.lerp(forward_weighted_weapon_target, 0.82)
			if primary_target_world.length_squared() > 0.000001
			else forward_weighted_weapon_target
		)
	if secondary_target_world.length_squared() > 0.000001:
		if shoulder_target_world.length_squared() > 0.000001:
			shoulder_target_world = shoulder_target_world.lerp(secondary_target_world, 0.5)
		else:
			shoulder_target_world = secondary_target_world
	if shoulder_target_world.length_squared() <= 0.000001:
		shoulder_target_world = torso_target_world
	var torso_forward_world: Vector3 = _resolve_weighted_forward_world(
		torso_origin_world,
		torso_target_world,
		weapon_center_world,
		weapon_axis_world,
		fallback_forward_world,
		0.42
	)
	var shoulder_forward_world: Vector3 = _resolve_weighted_forward_world(
		torso_origin_world,
		shoulder_target_world,
		weapon_center_world,
		weapon_axis_world,
		torso_forward_world,
		0.34
	)
	var reach_direction: Vector3 = shoulder_target_world - torso_origin_world
	var reach_ratio: float = clampf(reach_direction.length() / 1.35, 0.0, 1.0)
	return {
		"torso_forward_world": torso_forward_world,
		"shoulder_forward_world": shoulder_forward_world,
		"reach_ratio": reach_ratio,
	}

func _resolve_weighted_forward_world(
	torso_origin_world: Vector3,
	primary_target_world: Vector3,
	weapon_center_world: Vector3,
	weapon_axis_world: Vector3,
	fallback_forward_world: Vector3,
	axis_weight: float
) -> Vector3:
	var desired_forward_world: Vector3 = fallback_forward_world
	var reach_direction: Vector3 = primary_target_world - torso_origin_world
	if reach_direction.length_squared() <= 0.000001 and weapon_center_world.length_squared() > 0.000001:
		reach_direction = weapon_center_world - torso_origin_world
	if reach_direction.length_squared() > 0.000001:
		desired_forward_world = reach_direction.normalized()
	if weapon_axis_world.length_squared() > 0.000001:
		var normalized_axis: Vector3 = weapon_axis_world.normalized()
		if desired_forward_world.length_squared() > 0.000001:
			desired_forward_world = (desired_forward_world * (1.0 - axis_weight)) + (normalized_axis * axis_weight)
		else:
			desired_forward_world = normalized_axis
	if desired_forward_world.length_squared() <= 0.000001:
		return fallback_forward_world
	return desired_forward_world.normalized()

func _resolve_local_direction_yaw_degrees(local_direction: Vector3, max_yaw_degrees: float, reach_ratio: float) -> float:
	var local_forward: Vector3 = local_direction.normalized()
	if local_forward.length_squared() <= 0.000001:
		return 0.0
	var raw_yaw: float = rad_to_deg(atan2(local_forward.x, -local_forward.z))
	var max_yaw: float = lerpf(max_yaw_degrees * 0.72, max_yaw_degrees, reach_ratio)
	return clampf(raw_yaw, -max_yaw, max_yaw)

func _resolve_local_direction_pitch_degrees(local_direction: Vector3, max_pitch_degrees: float, reach_ratio: float) -> float:
	var local_forward: Vector3 = local_direction.normalized()
	if local_forward.length_squared() <= 0.000001:
		return 0.0
	var horizontal_distance: float = sqrt((local_forward.x * local_forward.x) + (local_forward.z * local_forward.z))
	var raw_pitch: float = rad_to_deg(atan2(local_forward.y, maxf(horizontal_distance, 0.000001)))
	var max_pitch: float = lerpf(max_pitch_degrees * 0.72, max_pitch_degrees, reach_ratio)
	return clampf(raw_pitch, -max_pitch, max_pitch)

func _apply_bone_group(
	skeleton: Skeleton3D,
	bone_names: Array[StringName],
	pose_blend: float,
	resolved_blend: float,
	yaw_degrees: float,
	pitch_degrees: float,
	body_up_world: Vector3,
	body_right_world: Vector3,
	dominant_slot_id: StringName,
	two_hand: bool
) -> void:
	var body_up_skeleton: Vector3 = _world_axis_to_skeleton_axis(skeleton, body_up_world, Vector3.UP)
	var body_right_skeleton: Vector3 = _world_axis_to_skeleton_axis(skeleton, body_right_world, Vector3.RIGHT)
	for bone_name: StringName in bone_names:
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		var parent_index: int = skeleton.get_bone_parent(bone_index)
		if parent_index < 0:
			continue
		var current_local_rotation: Quaternion = skeleton.get_bone_pose_rotation(bone_index).normalized()
		var reference_local_rotation: Quaternion = _resolve_reference_pose_rotation(
			bone_name,
			pose_blend,
			current_local_rotation
		)
		var parent_global_basis: Basis = skeleton.get_bone_global_pose(parent_index).basis
		var base_global_basis: Basis = parent_global_basis * Basis(reference_local_rotation)
		var direction_weight: Vector2 = DIRECTION_WEIGHTS.get(bone_name, Vector2.ZERO) as Vector2
		var side_weight: float = _resolve_side_weight_multiplier(bone_name, dominant_slot_id, two_hand)
		var yaw_quaternion := Quaternion(
			body_up_skeleton,
			deg_to_rad(yaw_degrees * direction_weight.x * side_weight)
		)
		var pitch_quaternion := Quaternion(
			body_right_skeleton,
			deg_to_rad(-pitch_degrees * direction_weight.y * side_weight)
		)
		var desired_global_basis: Basis = Basis(yaw_quaternion) * Basis(pitch_quaternion) * base_global_basis
		var desired_local_basis: Basis = parent_global_basis.inverse() * desired_global_basis
		var desired_local_rotation: Quaternion = desired_local_basis.get_rotation_quaternion().normalized()
		var application_weight: float = _resolve_application_weight(bone_name, dominant_slot_id, two_hand)
		var final_blend: float = clampf(resolved_blend * application_weight, 0.0, 1.0)
		if final_blend <= 0.00001:
			continue
		skeleton.set_bone_pose_rotation(
			bone_index,
			current_local_rotation.slerp(desired_local_rotation, final_blend).normalized()
		)

func _resolve_reference_pose_rotation(
	bone_name: StringName,
	pose_blend: float,
	current_local_rotation: Quaternion
) -> Quaternion:
	var idle_lookup: Dictionary = upper_body_pose_cache.get(POSE_IDLE, {})
	var two_hand_lookup: Dictionary = upper_body_pose_cache.get(POSE_TWO_HAND, {})
	var idle_rotation: Quaternion = idle_lookup.get(bone_name, current_local_rotation) as Quaternion
	var two_hand_rotation: Quaternion = two_hand_lookup.get(bone_name, idle_rotation) as Quaternion
	return idle_rotation.slerp(two_hand_rotation, clampf(pose_blend, 0.0, 1.0)).normalized()

func _resolve_application_weight(bone_name: StringName, dominant_slot_id: StringName, two_hand: bool) -> float:
	return float(APPLICATION_WEIGHTS.get(bone_name, 1.0)) * _resolve_side_weight_multiplier(
		bone_name,
		dominant_slot_id,
		two_hand
	)

func _resolve_side_weight_multiplier(bone_name: StringName, dominant_slot_id: StringName, two_hand: bool) -> float:
	if two_hand:
		return 1.0
	if (
		bone_name == RIGHT_CLAVICLE_BONE
		or bone_name == RIGHT_UPPERARM_BONE
		or bone_name == RIGHT_FOREARM_BONE
	):
		return 1.0 if dominant_slot_id != SLOT_LEFT else 0.45
	if (
		bone_name == LEFT_CLAVICLE_BONE
		or bone_name == LEFT_UPPERARM_BONE
		or bone_name == LEFT_FOREARM_BONE
	):
		return 1.0 if dominant_slot_id == SLOT_LEFT else 0.45
	return 1.0

func _get_bone_world_position(skeleton: Skeleton3D, bone_name: StringName) -> Vector3:
	var bone_index: int = skeleton.find_bone(String(bone_name))
	if bone_index < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)

func _world_axis_to_skeleton_axis(skeleton: Skeleton3D, world_axis: Vector3, fallback_axis: Vector3) -> Vector3:
	if skeleton == null or world_axis.length_squared() <= 0.000001:
		return fallback_axis
	var skeleton_axis: Vector3 = skeleton.global_basis.inverse() * world_axis
	if skeleton_axis.length_squared() <= 0.000001:
		return fallback_axis
	return skeleton_axis.normalized()
