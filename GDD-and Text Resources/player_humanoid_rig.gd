extends Node3D
class_name PlayerHumanoidRig

const RIGHT_HAND_BONE := &"CC_Base_R_Hand"
const LEFT_HAND_BONE := &"CC_Base_L_Hand"
const HIP_BONE := &"CC_Base_Hip"
const PELVIS_BONE := &"CC_Base_Pelvis"
const RIGHT_THIGH_BONE := &"CC_Base_R_Thigh"
const LEFT_THIGH_BONE := &"CC_Base_L_Thigh"
const RIGHT_CALF_BONE := &"CC_Base_R_Calf"
const LEFT_CALF_BONE := &"CC_Base_L_Calf"
const RIGHT_FOOT_BONE := &"CC_Base_R_Foot"
const LEFT_FOOT_BONE := &"CC_Base_L_Foot"
const WAIST_BONE := &"CC_Base_Waist"
const SPINE_01_BONE := &"CC_Base_Spine01"
const SPINE_02_BONE := &"CC_Base_Spine02"
const NECK_01_BONE := &"CC_Base_NeckTwist01"
const NECK_02_BONE := &"CC_Base_NeckTwist02"
const HEAD_BONE := &"CC_Base_Head"
const RIGHT_CLAVICLE_BONE := &"CC_Base_R_Clavicle"
const LEFT_CLAVICLE_BONE := &"CC_Base_L_Clavicle"
const RIGHT_UPPERARM_BONE := &"CC_Base_R_Upperarm"
const LEFT_UPPERARM_BONE := &"CC_Base_L_Upperarm"
const RIGHT_FOREARM_BONE := &"CC_Base_R_Forearm"
const LEFT_FOREARM_BONE := &"CC_Base_L_Forearm"
const RIGHT_FINGER_CHAINS := [
	[&"CC_Base_R_Index1", &"CC_Base_R_Index2", &"CC_Base_R_Index3"],
	[&"CC_Base_R_Mid1", &"CC_Base_R_Mid2", &"CC_Base_R_Mid3"],
	[&"CC_Base_R_Ring1", &"CC_Base_R_Ring2", &"CC_Base_R_Ring3"],
	[&"CC_Base_R_Pinky1", &"CC_Base_R_Pinky2", &"CC_Base_R_Pinky3"]
]
const LEFT_FINGER_CHAINS := [
	[&"CC_Base_L_Index1", &"CC_Base_L_Index2", &"CC_Base_L_Index3"],
	[&"CC_Base_L_Mid1", &"CC_Base_L_Mid2", &"CC_Base_L_Mid3"],
	[&"CC_Base_L_Ring1", &"CC_Base_L_Ring2", &"CC_Base_L_Ring3"],
	[&"CC_Base_L_Pinky1", &"CC_Base_L_Pinky2", &"CC_Base_L_Pinky3"]
]
const RIGHT_THUMB_CHAIN := [&"CC_Base_R_Thumb1", &"CC_Base_R_Thumb2", &"CC_Base_R_Thumb3"]
const LEFT_THUMB_CHAIN := [&"CC_Base_L_Thumb1", &"CC_Base_L_Thumb2", &"CC_Base_L_Thumb3"]
const FINGER_TRACK_TOKENS := [
	"CC_Base_R_Index",
	"CC_Base_R_Mid",
	"CC_Base_R_Ring",
	"CC_Base_R_Pinky",
	"CC_Base_R_Thumb",
	"CC_Base_L_Index",
	"CC_Base_L_Mid",
	"CC_Base_L_Ring",
	"CC_Base_L_Pinky",
	"CC_Base_L_Thumb"
]
const AIM_TRACK_TOKENS := [
	"CC_Base_Waist",
	"CC_Base_Spine01",
	"CC_Base_Spine02",
	"CC_Base_NeckTwist01",
	"CC_Base_NeckTwist02",
	"CC_Base_Head"
]
const AIM_BONE_CONFIGS := [
	{
		"bone": WAIST_BONE,
		"yaw_weight": 0.04,
		"pitch_weight": 0.02,
		"smoothing_speed": 4.0
	},
	{
		"bone": SPINE_01_BONE,
		"yaw_weight": 0.07,
		"pitch_weight": 0.04,
		"smoothing_speed": 5.5
	},
	{
		"bone": SPINE_02_BONE,
		"yaw_weight": 0.11,
		"pitch_weight": 0.07,
		"smoothing_speed": 7.0
	},
	{
		"bone": NECK_01_BONE,
		"yaw_weight": 0.14,
		"pitch_weight": 0.10,
		"smoothing_speed": 7.8
	},
	{
		"bone": NECK_02_BONE,
		"yaw_weight": 0.16,
		"pitch_weight": 0.12,
		"smoothing_speed": 8.2
	},
	{
		"bone": HEAD_BONE,
		"yaw_weight": 0.18,
		"pitch_weight": 0.14,
		"smoothing_speed": 8.8
	}
]
const RIGHT_ARM_AIM_BONE_CONFIGS := [
	{
		"bone": RIGHT_CLAVICLE_BONE,
		"yaw_weight": 0.08,
		"pitch_weight": 0.05,
		"smoothing_speed": 8.0
	},
	{
		"bone": RIGHT_UPPERARM_BONE,
		"yaw_weight": -0.18,
		"pitch_weight": -0.16,
		"smoothing_speed": 10.0
	},
	{
		"bone": RIGHT_FOREARM_BONE,
		"yaw_weight": -0.10,
		"pitch_weight": -0.24,
		"smoothing_speed": 12.0
	}
]
const LEFT_ARM_AIM_BONE_CONFIGS := [
	{
		"bone": LEFT_CLAVICLE_BONE,
		"yaw_weight": 0.08,
		"pitch_weight": 0.05,
		"smoothing_speed": 8.0
	},
	{
		"bone": LEFT_UPPERARM_BONE,
		"yaw_weight": -0.18,
		"pitch_weight": -0.16,
		"smoothing_speed": 10.0
	},
	{
		"bone": LEFT_FOREARM_BONE,
		"yaw_weight": -0.10,
		"pitch_weight": -0.24,
		"smoothing_speed": 12.0
	}
]

@export_range(1.6, 2.4, 0.01) var standing_height_meters: float = 2.0
@export var right_hand_anchor_position: Vector3 = Vector3.ZERO
@export var right_hand_anchor_rotation_degrees: Vector3 = Vector3(0.0, 90.0, 0.0)
@export var left_hand_anchor_position: Vector3 = Vector3.ZERO
@export var left_hand_anchor_rotation_degrees: Vector3 = Vector3(0.0, -90.0, 0.0)
@export_category("Stowed Weapon Anchors")
@export var left_shoulder_stow_position: Vector3 = Vector3(0.08, 0.12, -0.10)
@export var left_shoulder_stow_rotation_degrees: Vector3 = Vector3(-18.0, 24.0, 112.0)
@export var right_shoulder_stow_position: Vector3 = Vector3(-0.08, 0.12, -0.10)
@export var right_shoulder_stow_rotation_degrees: Vector3 = Vector3(-18.0, -24.0, -112.0)
@export var left_side_hip_stow_position: Vector3 = Vector3(0.10, 0.42, 0.08)
@export var left_side_hip_stow_rotation_degrees: Vector3 = Vector3(8.0, 16.0, 82.0)
@export var right_side_hip_stow_position: Vector3 = Vector3(-0.10, 0.42, 0.08)
@export var right_side_hip_stow_rotation_degrees: Vector3 = Vector3(8.0, -16.0, -82.0)
@export var left_lower_back_stow_position: Vector3 = Vector3(0.12, 0.48, -0.14)
@export var left_lower_back_stow_rotation_degrees: Vector3 = Vector3(6.0, 164.0, -22.0)
@export var right_lower_back_stow_position: Vector3 = Vector3(-0.12, 0.48, -0.14)
@export var right_lower_back_stow_rotation_degrees: Vector3 = Vector3(6.0, -164.0, 22.0)
@export var default_animation_name: StringName = &"Idle"
@export var walk_animation_name: StringName = &"Walk"
@export var jog_animation_name: StringName = &"SlowRun"
@export var sprint_animation_name: StringName = &"Run"
@export var jump_animation_name: StringName = &"Jump(Pose)"
@export var fall_animation_name: StringName = &"Fall(Pose)"
@export_range(0.01, 2.0, 0.01) var animation_blend_seconds: float = 0.18
@export_range(0.0, 1.0, 0.01) var idle_horizontal_speed_threshold: float = 0.08
@export_range(0.0, 1.0, 0.01) var walk_ratio_threshold: float = 0.45
@export_range(-10.0, 10.0, 0.01) var jump_vertical_velocity_threshold: float = 0.12
@export var apply_runtime_hand_grip_pose: bool = true
@export var apply_runtime_aim_follow_pose: bool = true
@export var apply_runtime_arm_aim_follow_pose: bool = true
@export_range(0.0, 1.0, 0.01) var unarmed_aim_follow_intensity: float = 0.72
@export_range(0.0, 1.0, 0.01) var armed_aim_follow_intensity: float = 1.0
@export_range(0.0, 1.5, 0.01) var armed_arm_aim_intensity: float = 1.0
@export_range(0.0, 90.0, 0.5) var max_local_aim_yaw_degrees: float = 70.0
@export_range(0.0, 90.0, 0.5) var max_local_aim_pitch_up_degrees: float = 38.0
@export_range(0.0, 90.0, 0.5) var max_local_aim_pitch_down_degrees: float = 28.0
@export var enable_arm_ik: bool = true
@export var enable_foot_ik: bool = true
@export_range(0.0, 1.0, 0.01) var arm_ik_influence: float = 1.0
@export_range(0.0, 1.0, 0.01) var foot_ik_idle_influence: float = 0.0
@export_range(0.0, 1.0, 0.01) var foot_ik_moving_influence: float = 0.24
@export_range(0.0, 1.0, 0.01) var foot_ik_airborne_influence: float = 0.0
@export_range(0.1, 1.5, 0.01) var hand_ik_reach_meters: float = 0.24
@export_range(0.0, 1.0, 0.01) var hand_ik_pose_bias: float = 0.55
@export_range(0.0, 0.5, 0.01) var hand_ik_side_offset_meters: float = 0.10
@export_range(-0.3, 0.3, 0.01) var hand_ik_vertical_offset_meters: float = -0.02
@export_range(1.0, 30.0, 0.1) var arm_ik_target_smoothing_speed: float = 12.0
@export_range(0.0, 0.6, 0.01) var arm_ik_pole_side_offset_meters: float = 0.24
@export_range(0.0, 0.6, 0.01) var arm_ik_pole_down_offset_meters: float = 0.18
@export_range(0.0, 0.4, 0.01) var arm_ik_pole_back_offset_meters: float = 0.08
@export_flags_3d_physics var foot_ik_collision_mask: int = 1
@export_range(0.05, 2.0, 0.01) var foot_ik_probe_height_meters: float = 0.45
@export_range(0.05, 2.0, 0.01) var foot_ik_probe_depth_meters: float = 1.6
@export_range(0.0, 0.2, 0.005) var foot_ik_target_lift_meters: float = 0.03
@export_range(1.0, 30.0, 0.1) var foot_ik_target_smoothing_speed: float = 14.0
@export_range(0.0, 0.4, 0.01) var foot_ik_knee_forward_offset_meters: float = 0.16
@export_range(0.0, 0.3, 0.01) var foot_ik_knee_side_offset_meters: float = 0.05
@export_range(-45.0, 45.0, 0.5) var support_hand_clavicle_pitch_degrees: float = -14.0
@export_range(0.0, 45.0, 0.5) var support_hand_clavicle_yaw_degrees: float = 32.0
@export_range(0.0, 60.0, 0.5) var support_body_max_yaw_degrees: float = 28.0
@export_range(0.0, 45.0, 0.5) var support_body_max_pitch_degrees: float = 18.0
@export_range(0.0, 1.0, 0.01) var support_pelvis_yaw_weight: float = 0.08
@export_range(0.0, 1.0, 0.01) var support_pelvis_pitch_weight: float = 0.04
@export_range(0.0, 1.0, 0.01) var support_waist_yaw_weight: float = 0.15
@export_range(0.0, 1.0, 0.01) var support_waist_pitch_weight: float = 0.09
@export_range(0.0, 1.0, 0.01) var support_spine01_yaw_weight: float = 0.20
@export_range(0.0, 1.0, 0.01) var support_spine01_pitch_weight: float = 0.14
@export_range(0.0, 1.0, 0.01) var support_spine02_yaw_weight: float = 0.24
@export_range(0.0, 1.0, 0.01) var support_spine02_pitch_weight: float = 0.18
@export_category("Posture Bias")
@export var apply_runtime_posture_bias: bool = true
@export_range(-20.0, 20.0, 0.5) var posture_pelvis_pitch_degrees: float = 0.5
@export_range(-20.0, 20.0, 0.5) var posture_waist_pitch_degrees: float = 1.0
@export_range(-20.0, 20.0, 0.5) var posture_spine01_pitch_degrees: float = 1.5
@export_range(-20.0, 20.0, 0.5) var posture_spine02_pitch_degrees: float = 2.0
@export_range(-20.0, 20.0, 0.5) var posture_neck01_pitch_degrees: float = 1.0
@export_range(-20.0, 20.0, 0.5) var posture_neck02_pitch_degrees: float = 0.5
@export_range(-20.0, 20.0, 0.5) var posture_head_pitch_degrees: float = 0.5
@export var right_hand_grip_rotation_degrees: Vector3 = Vector3(-10.0, 8.0, -12.0)
@export var left_hand_grip_rotation_degrees: Vector3 = Vector3(-10.0, -8.0, 12.0)
@export var finger_grip_proximal_rotation_degrees: Vector3 = Vector3(28.0, 0.0, 0.0)
@export var finger_grip_middle_rotation_degrees: Vector3 = Vector3(36.0, 0.0, 0.0)
@export var finger_grip_distal_rotation_degrees: Vector3 = Vector3(24.0, 0.0, 0.0)
@export_range(0.0, 1.0, 0.01) var hand_anchor_knuckle_to_middle_blend: float = 0.35
@export_range(0.0, 1.0, 0.01) var hand_anchor_thumb_bias: float = 0.18
@export_range(0.1, 1.5, 0.01) var hand_anchor_palm_pullback: float = 0.82
@export var right_thumb_grip_rotations_degrees: Array[Vector3] = [
	Vector3(8.0, -18.0, 24.0),
	Vector3(0.0, -4.0, 18.0),
	Vector3(0.0, 0.0, 12.0)
]
@export var left_thumb_grip_rotations_degrees: Array[Vector3] = [
	Vector3(8.0, 18.0, -24.0),
	Vector3(0.0, 4.0, -18.0),
	Vector3(0.0, 0.0, -12.0)
]

@onready var josie_model: Node3D = $JosieModel
@onready var skeleton: Skeleton3D = $JosieModel/Josie/Skeleton3D
@onready var mesh_instance: MeshInstance3D = $JosieModel/Josie/Skeleton3D/Mesh
@onready var animation_player: AnimationPlayer = $JosieModel/AnimationPlayer
@onready var ik_targets_root: Node3D = $IkTargets
@onready var right_hand_ik_target: Node3D = $IkTargets/RightHandIkTarget
@onready var left_hand_ik_target: Node3D = $IkTargets/LeftHandIkTarget
@onready var right_hand_pole_target: Node3D = $IkTargets/RightHandPoleTarget
@onready var left_hand_pole_target: Node3D = $IkTargets/LeftHandPoleTarget
@onready var right_foot_ik_target: Node3D = $IkTargets/RightFootIkTarget
@onready var left_foot_ik_target: Node3D = $IkTargets/LeftFootIkTarget
@onready var right_foot_pole_target: Node3D = $IkTargets/RightFootPoleTarget
@onready var left_foot_pole_target: Node3D = $IkTargets/LeftFootPoleTarget

var resolved_visual_height_meters: float = 0.0
var current_animation_name: StringName = StringName()
var right_hand_grip_active: bool = false
var left_hand_grip_active: bool = false
var bone_index_cache: Dictionary = {}
var aim_target_local_yaw_radians: float = 0.0
var aim_target_local_pitch_radians: float = 0.0
var aim_bone_state_by_name: Dictionary = {}
var arm_bone_state_by_name: Dictionary = {}
var arm_last_offsets_by_bone: Dictionary = {}
var posture_bias_last_offsets_by_bone: Dictionary = {}
var locomotion_grounded: bool = true
var locomotion_horizontal_speed: float = 0.0
var locomotion_vertical_velocity: float = 0.0
var right_arm_ik_modifier: TwoBoneIK3D = null
var left_arm_ik_modifier: TwoBoneIK3D = null
var right_leg_ik_modifier: TwoBoneIK3D = null
var left_leg_ik_modifier: TwoBoneIK3D = null
var right_hand_guidance_target: Node3D = null
var left_hand_guidance_target: Node3D = null
var right_hand_support_active: bool = false
var left_hand_support_active: bool = false
var support_pose_last_offsets_by_bone: Dictionary = {}

func _ready() -> void:
	_apply_target_height_scale()
	if skeleton != null:
		skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
	_ensure_hand_attachment("RightHandAttachment", RIGHT_HAND_BONE, "RightHandItemAnchor", _resolve_hand_anchor_position(&"hand_right"), right_hand_anchor_rotation_degrees)
	_ensure_hand_attachment("LeftHandAttachment", LEFT_HAND_BONE, "LeftHandItemAnchor", _resolve_hand_anchor_position(&"hand_left"), left_hand_anchor_rotation_degrees)
	_ensure_empty_attachment("RightFootAttachment", RIGHT_FOOT_BONE)
	_ensure_empty_attachment("LeftFootAttachment", LEFT_FOOT_BONE)
	_ensure_stow_attachment("LeftShoulderStowAttachment", LEFT_CLAVICLE_BONE, "LeftShoulderStowAnchor", left_shoulder_stow_position, left_shoulder_stow_rotation_degrees)
	_ensure_stow_attachment("RightShoulderStowAttachment", RIGHT_CLAVICLE_BONE, "RightShoulderStowAnchor", right_shoulder_stow_position, right_shoulder_stow_rotation_degrees)
	_ensure_stow_attachment("LeftHipStowAttachment", LEFT_THIGH_BONE, "LeftHipStowAnchor", left_side_hip_stow_position, left_side_hip_stow_rotation_degrees)
	_ensure_stow_attachment("RightHipStowAttachment", RIGHT_THIGH_BONE, "RightHipStowAnchor", right_side_hip_stow_position, right_side_hip_stow_rotation_degrees)
	_ensure_stow_attachment("LeftLowerBackStowAttachment", LEFT_THIGH_BONE, "LeftLowerBackStowAnchor", left_lower_back_stow_position, left_lower_back_stow_rotation_degrees)
	_ensure_stow_attachment("RightLowerBackStowAttachment", RIGHT_THIGH_BONE, "RightLowerBackStowAnchor", right_lower_back_stow_position, right_lower_back_stow_rotation_degrees)
	_ensure_ik_target_nodes()
	_ensure_runtime_ik_modifiers()
	_snap_runtime_ik_targets_to_current_pose()
	_refresh_runtime_ik_influences()
	_prepare_runtime_hand_pose_animations()
	process_priority = 10
	set_process(true)
	_play_default_animation()

func _process(delta: float) -> void:
	_update_runtime_arm_ik_targets(delta)
	_update_runtime_foot_ik_targets(delta)
	_refresh_runtime_ik_influences()
	_apply_runtime_aim_follow_pose(delta)
	_apply_runtime_arm_aim_follow_pose(delta)
	_apply_runtime_support_pose()
	_apply_runtime_posture_bias()

func get_standing_height_meters() -> float:
	return standing_height_meters

func get_visual_height_meters() -> float:
	return resolved_visual_height_meters

func get_right_hand_item_anchor() -> Node3D:
	return get_node_or_null("JosieModel/Josie/Skeleton3D/RightHandAttachment/RightHandItemAnchor") as Node3D

func get_left_hand_item_anchor() -> Node3D:
	return get_node_or_null("JosieModel/Josie/Skeleton3D/LeftHandAttachment/LeftHandItemAnchor") as Node3D

func get_weapon_stow_anchor(stow_mode: StringName, slot_id: StringName) -> Node3D:
	var normalized_mode: StringName = CraftedItemWIP.normalize_stow_position_mode(stow_mode)
	if normalized_mode == CraftedItemWIP.STOW_SIDE_HIP:
		if slot_id == &"hand_right":
			return get_node_or_null("JosieModel/Josie/Skeleton3D/LeftHipStowAttachment/LeftHipStowAnchor") as Node3D
		if slot_id == &"hand_left":
			return get_node_or_null("JosieModel/Josie/Skeleton3D/RightHipStowAttachment/RightHipStowAnchor") as Node3D
	elif normalized_mode == CraftedItemWIP.STOW_LOWER_BACK:
		if slot_id == &"hand_right":
			return get_node_or_null("JosieModel/Josie/Skeleton3D/RightLowerBackStowAttachment/RightLowerBackStowAnchor") as Node3D
		if slot_id == &"hand_left":
			return get_node_or_null("JosieModel/Josie/Skeleton3D/LeftLowerBackStowAttachment/LeftLowerBackStowAnchor") as Node3D
	else:
		if slot_id == &"hand_right":
			return get_node_or_null("JosieModel/Josie/Skeleton3D/LeftShoulderStowAttachment/LeftShoulderStowAnchor") as Node3D
		if slot_id == &"hand_left":
			return get_node_or_null("JosieModel/Josie/Skeleton3D/RightShoulderStowAttachment/RightShoulderStowAnchor") as Node3D
	return null

func get_current_animation_name() -> StringName:
	return current_animation_name

func get_required_cc_base_bone_names() -> Array[StringName]:
	var required_bones: Array[StringName] = [
		HIP_BONE,
		PELVIS_BONE,
		WAIST_BONE,
		SPINE_01_BONE,
		SPINE_02_BONE,
		NECK_01_BONE,
		NECK_02_BONE,
		HEAD_BONE,
		RIGHT_CLAVICLE_BONE,
		LEFT_CLAVICLE_BONE,
		RIGHT_UPPERARM_BONE,
		LEFT_UPPERARM_BONE,
		RIGHT_FOREARM_BONE,
		LEFT_FOREARM_BONE,
		RIGHT_HAND_BONE,
		LEFT_HAND_BONE,
		RIGHT_THIGH_BONE,
		LEFT_THIGH_BONE,
		RIGHT_CALF_BONE,
		LEFT_CALF_BONE,
		RIGHT_FOOT_BONE,
		LEFT_FOOT_BONE
	]
	for finger_chain_variant in RIGHT_FINGER_CHAINS:
		for finger_bone_variant in finger_chain_variant:
			required_bones.append(finger_bone_variant)
	for finger_chain_variant in LEFT_FINGER_CHAINS:
		for finger_bone_variant in finger_chain_variant:
			required_bones.append(finger_bone_variant)
	for thumb_bone in RIGHT_THUMB_CHAIN:
		required_bones.append(thumb_bone)
	for thumb_bone in LEFT_THUMB_CHAIN:
		required_bones.append(thumb_bone)
	return required_bones

func get_arm_guidance_target(slot_id: StringName) -> Node3D:
	if slot_id == &"hand_right":
		return right_hand_guidance_target
	if slot_id == &"hand_left":
		return left_hand_guidance_target
	return null

func is_support_hand_active(slot_id: StringName) -> bool:
	if slot_id == &"hand_right":
		return right_hand_support_active
	if slot_id == &"hand_left":
		return left_hand_support_active
	return false

func is_hand_grip_active(slot_id: StringName) -> bool:
	if slot_id == &"hand_right":
		return right_hand_grip_active
	if slot_id == &"hand_left":
		return left_hand_grip_active
	return false

func get_hand_bone_name(slot_id: StringName) -> StringName:
	if slot_id == &"hand_right":
		return RIGHT_HAND_BONE
	if slot_id == &"hand_left":
		return LEFT_HAND_BONE
	return StringName()

func get_hand_grip_rotation_degrees(slot_id: StringName) -> Vector3:
	if slot_id == &"hand_right":
		return right_hand_grip_rotation_degrees
	if slot_id == &"hand_left":
		return left_hand_grip_rotation_degrees
	return Vector3.ZERO

func get_finger_chains(slot_id: StringName) -> Array:
	if slot_id == &"hand_right":
		return RIGHT_FINGER_CHAINS
	if slot_id == &"hand_left":
		return LEFT_FINGER_CHAINS
	return []

func get_thumb_chain(slot_id: StringName) -> Array:
	if slot_id == &"hand_right":
		return RIGHT_THUMB_CHAIN
	if slot_id == &"hand_left":
		return LEFT_THUMB_CHAIN
	return []

func get_thumb_grip_rotations_degrees(slot_id: StringName) -> Array[Vector3]:
	if slot_id == &"hand_right":
		return right_thumb_grip_rotations_degrees
	if slot_id == &"hand_left":
		return left_thumb_grip_rotations_degrees
	return []

func has_animation_name(animation_name: StringName) -> bool:
	if animation_player == null or animation_name == StringName():
		return false
	return animation_player.has_animation(String(animation_name))

func update_locomotion_state(
		horizontal_speed: float,
		target_horizontal_speed: float,
		grounded: bool,
		vertical_velocity: float,
		sprinting: bool
	) -> void:
	locomotion_horizontal_speed = horizontal_speed
	locomotion_grounded = grounded
	locomotion_vertical_velocity = vertical_velocity
	var target_animation_name: StringName = _resolve_locomotion_animation_name(
		horizontal_speed,
		target_horizontal_speed,
		grounded,
		vertical_velocity,
		sprinting
	)
	_play_animation(target_animation_name)

func set_aim_follow_target(local_yaw_radians: float, local_pitch_radians: float) -> void:
	aim_target_local_yaw_radians = clampf(
		local_yaw_radians,
		-deg_to_rad(max_local_aim_yaw_degrees),
		deg_to_rad(max_local_aim_yaw_degrees)
	)
	aim_target_local_pitch_radians = clampf(
		local_pitch_radians,
		-deg_to_rad(max_local_aim_pitch_down_degrees),
		deg_to_rad(max_local_aim_pitch_up_degrees)
	)

func set_arm_guidance_target(slot_id: StringName, target_node: Node3D) -> void:
	if slot_id == &"hand_right":
		right_hand_guidance_target = target_node if is_instance_valid(target_node) else null
		_refresh_runtime_ik_influences()
		return
	if slot_id == &"hand_left":
		left_hand_guidance_target = target_node if is_instance_valid(target_node) else null
		_refresh_runtime_ik_influences()

func clear_arm_guidance_target(slot_id: StringName) -> void:
	set_arm_guidance_target(slot_id, null)

func set_hand_grip_active(slot_id: StringName, active: bool) -> void:
	if slot_id == &"hand_right":
		if right_hand_grip_active == active:
			return
		right_hand_grip_active = active
		_refresh_runtime_ik_influences()
		if active:
			_apply_hand_grip_pose_for_slot(slot_id)
		elif not right_hand_support_active:
			_reset_hand_grip_pose(slot_id)
		return
	if slot_id == &"hand_left":
		if left_hand_grip_active == active:
			return
		left_hand_grip_active = active
		_refresh_runtime_ik_influences()
		if active:
			_apply_hand_grip_pose_for_slot(slot_id)
		elif not left_hand_support_active:
			_reset_hand_grip_pose(slot_id)

func set_support_hand_active(slot_id: StringName, active: bool) -> void:
	if slot_id == &"hand_right":
		if right_hand_support_active == active:
			return
		right_hand_support_active = active
		_refresh_runtime_ik_influences()
		if active:
			_apply_hand_grip_pose_for_slot(slot_id)
		elif not right_hand_grip_active:
			_reset_hand_grip_pose(slot_id)
		return
	if slot_id == &"hand_left":
		if left_hand_support_active == active:
			return
		left_hand_support_active = active
		_refresh_runtime_ik_influences()
		if active:
			_apply_hand_grip_pose_for_slot(slot_id)
		elif not left_hand_grip_active:
			_reset_hand_grip_pose(slot_id)

func _ensure_ik_target_nodes() -> void:
	if ik_targets_root == null:
		return
	for target_name: String in [
		"RightHandIkTarget",
		"LeftHandIkTarget",
		"RightHandPoleTarget",
		"LeftHandPoleTarget",
		"RightFootIkTarget",
		"LeftFootIkTarget",
		"RightFootPoleTarget",
		"LeftFootPoleTarget"
	]:
		if ik_targets_root.get_node_or_null(target_name) != null:
			continue
		var target_node := Node3D.new()
		target_node.name = target_name
		ik_targets_root.add_child(target_node)

func _ensure_runtime_ik_modifiers() -> void:
	if skeleton == null:
		return
	right_arm_ik_modifier = _ensure_two_bone_ik(
		"RightArmIK",
		RIGHT_UPPERARM_BONE,
		RIGHT_FOREARM_BONE,
		RIGHT_HAND_BONE,
		right_hand_ik_target,
		right_hand_pole_target
	)
	left_arm_ik_modifier = _ensure_two_bone_ik(
		"LeftArmIK",
		LEFT_UPPERARM_BONE,
		LEFT_FOREARM_BONE,
		LEFT_HAND_BONE,
		left_hand_ik_target,
		left_hand_pole_target
	)
	right_leg_ik_modifier = _ensure_two_bone_ik(
		"RightLegIK",
		RIGHT_THIGH_BONE,
		RIGHT_CALF_BONE,
		RIGHT_FOOT_BONE,
		right_foot_ik_target,
		right_foot_pole_target
	)
	left_leg_ik_modifier = _ensure_two_bone_ik(
		"LeftLegIK",
		LEFT_THIGH_BONE,
		LEFT_CALF_BONE,
		LEFT_FOOT_BONE,
		left_foot_ik_target,
		left_foot_pole_target
	)

func _ensure_two_bone_ik(
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
	var root_bone_idx: int = _get_bone_index(root_bone_name)
	var middle_bone_idx: int = _get_bone_index(middle_bone_name)
	var end_bone_idx: int = _get_bone_index(end_bone_name)
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

func _snap_runtime_ik_targets_to_current_pose() -> void:
	if skeleton == null:
		return
	if right_hand_ik_target != null:
		right_hand_ik_target.global_position = _get_bone_world_position(RIGHT_HAND_BONE)
	if left_hand_ik_target != null:
		left_hand_ik_target.global_position = _get_bone_world_position(LEFT_HAND_BONE)
	if right_hand_pole_target != null:
		right_hand_pole_target.global_position = _get_bone_world_position(RIGHT_FOREARM_BONE)
	if left_hand_pole_target != null:
		left_hand_pole_target.global_position = _get_bone_world_position(LEFT_FOREARM_BONE)
	if right_foot_ik_target != null:
		right_foot_ik_target.global_position = _get_bone_world_position(RIGHT_FOOT_BONE)
	if left_foot_ik_target != null:
		left_foot_ik_target.global_position = _get_bone_world_position(LEFT_FOOT_BONE)
	if right_foot_pole_target != null:
		right_foot_pole_target.global_position = _get_bone_world_position(RIGHT_CALF_BONE)
	if left_foot_pole_target != null:
		left_foot_pole_target.global_position = _get_bone_world_position(LEFT_CALF_BONE)

func _update_runtime_arm_ik_targets(delta: float) -> void:
	if skeleton == null or not enable_arm_ik:
		return
	var aim_world_direction: Vector3 = _get_aim_world_direction()
	var body_right: Vector3 = global_basis.x.normalized()
	var body_up: Vector3 = global_basis.y.normalized()
	var right_hand_anchor: Node3D = get_right_hand_item_anchor()
	var left_hand_anchor: Node3D = get_left_hand_item_anchor()
	_update_arm_ik_target_for_side(
		right_hand_ik_target,
		right_hand_pole_target,
		RIGHT_UPPERARM_BONE,
		RIGHT_FOREARM_BONE,
		RIGHT_HAND_BONE,
		right_hand_guidance_target,
		right_hand_anchor,
		right_hand_grip_active,
		aim_world_direction,
		body_right,
		body_up,
		1.0,
		delta
	)
	_update_arm_ik_target_for_side(
		left_hand_ik_target,
		left_hand_pole_target,
		LEFT_UPPERARM_BONE,
		LEFT_FOREARM_BONE,
		LEFT_HAND_BONE,
		left_hand_guidance_target,
		left_hand_anchor,
		left_hand_grip_active,
		aim_world_direction,
		body_right,
		body_up,
		-1.0,
		delta
	)

func _update_arm_ik_target_for_side(
		target_node: Node3D,
		pole_node: Node3D,
		upperarm_bone_name: StringName,
		forearm_bone_name: StringName,
		hand_bone_name: StringName,
		guidance_target: Node3D,
		hand_anchor_node: Node3D,
		apply_hand_anchor_offset: bool,
		aim_world_direction: Vector3,
		body_right: Vector3,
		body_up: Vector3,
		side_sign: float,
		delta: float
	) -> void:
	if target_node == null or pole_node == null:
		return
	var shoulder_position: Vector3 = _get_bone_world_position(upperarm_bone_name)
	var current_hand_position: Vector3 = _get_bone_world_position(hand_bone_name)
	var desired_target: Vector3 = current_hand_position
	if guidance_target != null and is_instance_valid(guidance_target):
		desired_target = guidance_target.global_position
		if apply_hand_anchor_offset and hand_anchor_node != null and is_instance_valid(hand_anchor_node):
			desired_target -= hand_anchor_node.global_position - current_hand_position
	else:
		var aimed_target: Vector3 = shoulder_position \
			+ aim_world_direction * hand_ik_reach_meters \
			+ body_right * hand_ik_side_offset_meters * side_sign \
			+ body_up * hand_ik_vertical_offset_meters
		desired_target = current_hand_position.lerp(aimed_target, hand_ik_pose_bias)
	var forearm_position: Vector3 = _get_bone_world_position(forearm_bone_name)
	var desired_pole: Vector3 = forearm_position
	if desired_pole == Vector3.ZERO:
		desired_pole = shoulder_position
	desired_pole += body_right * arm_ik_pole_side_offset_meters * side_sign
	desired_pole -= body_up * arm_ik_pole_down_offset_meters
	desired_pole -= aim_world_direction * arm_ik_pole_back_offset_meters
	_move_ik_target_toward(target_node, desired_target, arm_ik_target_smoothing_speed, delta)
	_move_ik_target_toward(pole_node, desired_pole, arm_ik_target_smoothing_speed, delta)

func _update_runtime_foot_ik_targets(delta: float) -> void:
	if skeleton == null or not enable_foot_ik or get_world_3d() == null:
		return
	var body_up: Vector3 = global_basis.y.normalized()
	var body_forward: Vector3 = global_basis.z.normalized()
	var body_right: Vector3 = global_basis.x.normalized()
	_update_foot_ik_target_for_side(
		right_foot_ik_target,
		right_foot_pole_target,
		RIGHT_THIGH_BONE,
		RIGHT_FOOT_BONE,
		body_up,
		body_forward,
		body_right,
		1.0,
		delta
	)
	_update_foot_ik_target_for_side(
		left_foot_ik_target,
		left_foot_pole_target,
		LEFT_THIGH_BONE,
		LEFT_FOOT_BONE,
		body_up,
		body_forward,
		body_right,
		-1.0,
		delta
	)

func _update_foot_ik_target_for_side(
		target_node: Node3D,
		pole_node: Node3D,
		thigh_bone_name: StringName,
		foot_bone_name: StringName,
		body_up: Vector3,
		body_forward: Vector3,
		body_right: Vector3,
		side_sign: float,
		delta: float
	) -> void:
	if target_node == null or pole_node == null:
		return
	var foot_position: Vector3 = _get_bone_world_position(foot_bone_name)
	var desired_target: Vector3 = foot_position
	var space_state := get_world_3d().direct_space_state
	if space_state != null:
		var ray_query := PhysicsRayQueryParameters3D.create(
			foot_position + body_up * foot_ik_probe_height_meters,
			foot_position - body_up * foot_ik_probe_depth_meters
		)
		ray_query.collision_mask = foot_ik_collision_mask
		ray_query.exclude = _build_ik_ray_exclusions()
		var hit: Dictionary = space_state.intersect_ray(ray_query)
		if not hit.is_empty():
			desired_target = hit.position + body_up * foot_ik_target_lift_meters
	var thigh_position: Vector3 = _get_bone_world_position(thigh_bone_name)
	var desired_pole: Vector3 = thigh_position \
		+ body_forward * foot_ik_knee_forward_offset_meters \
		+ body_right * foot_ik_knee_side_offset_meters * side_sign
	_move_ik_target_toward(target_node, desired_target, foot_ik_target_smoothing_speed, delta)
	_move_ik_target_toward(pole_node, desired_pole, foot_ik_target_smoothing_speed, delta)

func _refresh_runtime_ik_influences() -> void:
	_set_modifier_runtime_state(right_arm_ik_modifier, _slot_requires_arm_ik(&"hand_right"), arm_ik_influence)
	_set_modifier_runtime_state(left_arm_ik_modifier, _slot_requires_arm_ik(&"hand_left"), arm_ik_influence)
	var foot_influence: float = _resolve_foot_ik_influence()
	var foot_active: bool = enable_foot_ik and foot_influence > 0.001
	_set_modifier_runtime_state(right_leg_ik_modifier, foot_active, foot_influence)
	_set_modifier_runtime_state(left_leg_ik_modifier, foot_active, foot_influence)

func _slot_requires_arm_ik(slot_id: StringName) -> bool:
	if not enable_arm_ik:
		return false
	if slot_id == &"hand_right":
		return right_hand_grip_active or right_hand_support_active or (right_hand_guidance_target != null and is_instance_valid(right_hand_guidance_target))
	if slot_id == &"hand_left":
		return left_hand_grip_active or left_hand_support_active or (left_hand_guidance_target != null and is_instance_valid(left_hand_guidance_target))
	return false

func _set_modifier_runtime_state(modifier: SkeletonModifier3D, enabled: bool, influence_value: float) -> void:
	if modifier == null:
		return
	modifier.active = enabled
	modifier.influence = influence_value if enabled else 0.0

func _resolve_foot_ik_influence() -> float:
	if not locomotion_grounded:
		return foot_ik_airborne_influence
	if locomotion_horizontal_speed <= idle_horizontal_speed_threshold:
		return foot_ik_idle_influence
	return foot_ik_moving_influence

func _get_aim_world_direction() -> Vector3:
	var local_aim_direction := Vector3(
		sin(aim_target_local_yaw_radians) * cos(aim_target_local_pitch_radians),
		sin(aim_target_local_pitch_radians),
		cos(aim_target_local_yaw_radians) * cos(aim_target_local_pitch_radians)
	)
	if local_aim_direction.is_zero_approx():
		local_aim_direction = Vector3(0.0, 0.0, 1.0)
	return (global_basis * local_aim_direction).normalized()

func _move_ik_target_toward(target_node: Node3D, desired_global_position: Vector3, smoothing_speed: float, delta: float) -> void:
	if target_node == null:
		return
	var blend_factor: float = clampf(smoothing_speed * delta, 0.0, 1.0)
	target_node.global_position = target_node.global_position.lerp(desired_global_position, blend_factor)

func _build_ik_ray_exclusions() -> Array:
	var exclusions: Array = []
	var current: Node = self
	while current != null:
		if current is CollisionObject3D:
			exclusions.append((current as CollisionObject3D).get_rid())
		current = current.get_parent()
	return exclusions

func _get_bone_world_position(bone_name: StringName) -> Vector3:
	var bone_idx: int = _get_bone_index(bone_name)
	if bone_idx < 0 or skeleton == null:
		return global_position
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_idx).origin)

func _has_active_arm_ik() -> bool:
	return enable_arm_ik and (
		(right_arm_ik_modifier != null and right_arm_ik_modifier.influence > 0.001) \
		or (left_arm_ik_modifier != null and left_arm_ik_modifier.influence > 0.001)
	)

func _apply_runtime_support_pose() -> void:
	if skeleton == null:
		_apply_additive_bone_rotation_offsets({}, support_pose_last_offsets_by_bone)
		return
	var desired_offsets: Dictionary = {}
	if right_hand_support_active and right_hand_guidance_target != null and is_instance_valid(right_hand_guidance_target):
		_append_support_pose_offsets_for_target(desired_offsets, right_hand_guidance_target, RIGHT_CLAVICLE_BONE)
	if left_hand_support_active and left_hand_guidance_target != null and is_instance_valid(left_hand_guidance_target):
		_append_support_pose_offsets_for_target(desired_offsets, left_hand_guidance_target, LEFT_CLAVICLE_BONE)
	_apply_additive_bone_rotation_offsets(desired_offsets, support_pose_last_offsets_by_bone)

func _apply_runtime_posture_bias() -> void:
	if skeleton == null or not apply_runtime_posture_bias:
		_apply_additive_bone_rotation_offsets({}, posture_bias_last_offsets_by_bone)
		return
	var desired_offsets: Dictionary = {}
	_append_support_rotation_offset(desired_offsets, PELVIS_BONE, deg_to_rad(posture_pelvis_pitch_degrees), 0.0)
	_append_support_rotation_offset(desired_offsets, WAIST_BONE, deg_to_rad(posture_waist_pitch_degrees), 0.0)
	_append_support_rotation_offset(desired_offsets, SPINE_01_BONE, deg_to_rad(posture_spine01_pitch_degrees), 0.0)
	_append_support_rotation_offset(desired_offsets, SPINE_02_BONE, deg_to_rad(posture_spine02_pitch_degrees), 0.0)
	_append_support_rotation_offset(desired_offsets, NECK_01_BONE, deg_to_rad(posture_neck01_pitch_degrees), 0.0)
	_append_support_rotation_offset(desired_offsets, NECK_02_BONE, deg_to_rad(posture_neck02_pitch_degrees), 0.0)
	_append_support_rotation_offset(desired_offsets, HEAD_BONE, deg_to_rad(posture_head_pitch_degrees), 0.0)
	_apply_additive_bone_rotation_offsets(desired_offsets, posture_bias_last_offsets_by_bone)

func _append_support_pose_offsets_for_target(desired_offsets: Dictionary, guidance_target: Node3D, clavicle_bone_name: StringName) -> void:
	if guidance_target == null or not is_instance_valid(guidance_target):
		return
	var torso_origin: Vector3 = _get_bone_world_position(SPINE_02_BONE)
	var torso_direction: Vector3 = guidance_target.global_position - torso_origin
	if torso_direction.is_zero_approx():
		return
	var rig_local_direction: Vector3 = global_basis.inverse() * torso_direction.normalized()
	var torso_yaw_limit: float = deg_to_rad(support_body_max_yaw_degrees)
	var torso_pitch_limit: float = deg_to_rad(support_body_max_pitch_degrees)
	var torso_yaw: float = clampf(atan2(rig_local_direction.x, rig_local_direction.z), -torso_yaw_limit, torso_yaw_limit)
	var torso_pitch: float = clampf(atan2(rig_local_direction.y, Vector2(rig_local_direction.x, rig_local_direction.z).length()), -torso_pitch_limit, torso_pitch_limit)
	_append_support_rotation_offset(desired_offsets, PELVIS_BONE, torso_pitch * support_pelvis_pitch_weight, torso_yaw * support_pelvis_yaw_weight)
	_append_support_rotation_offset(desired_offsets, WAIST_BONE, torso_pitch * support_waist_pitch_weight, torso_yaw * support_waist_yaw_weight)
	_append_support_rotation_offset(desired_offsets, SPINE_01_BONE, torso_pitch * support_spine01_pitch_weight, torso_yaw * support_spine01_yaw_weight)
	_append_support_rotation_offset(desired_offsets, SPINE_02_BONE, torso_pitch * support_spine02_pitch_weight, torso_yaw * support_spine02_yaw_weight)

	var clavicle_origin: Vector3 = _get_bone_world_position(clavicle_bone_name)
	var clavicle_direction: Vector3 = guidance_target.global_position - clavicle_origin
	if clavicle_direction.is_zero_approx():
		return
	var clavicle_local_direction: Vector3 = global_basis.inverse() * clavicle_direction.normalized()
	var clavicle_yaw_limit: float = deg_to_rad(maxf(support_hand_clavicle_yaw_degrees, 1.0))
	var clavicle_pitch_limit: float = deg_to_rad(maxf(absf(support_hand_clavicle_pitch_degrees), 1.0))
	var clavicle_yaw: float = clampf(atan2(clavicle_local_direction.x, clavicle_local_direction.z), -clavicle_yaw_limit, clavicle_yaw_limit)
	var clavicle_pitch: float = clampf(atan2(clavicle_local_direction.y, Vector2(clavicle_local_direction.x, clavicle_local_direction.z).length()), -clavicle_pitch_limit, clavicle_pitch_limit)
	_append_support_rotation_offset(desired_offsets, clavicle_bone_name, clavicle_pitch, clavicle_yaw)

func _append_support_rotation_offset(desired_offsets: Dictionary, bone_name: StringName, pitch_radians: float, yaw_radians: float, roll_radians: float = 0.0) -> void:
	var bone_idx: int = _get_bone_index(bone_name)
	if bone_idx < 0:
		return
	desired_offsets[bone_idx] = Quaternion.from_euler(Vector3(pitch_radians, yaw_radians, roll_radians))

func _apply_target_height_scale() -> void:
	if josie_model == null or mesh_instance == null:
		return
	var source_height_meters: float = mesh_instance.mesh.get_aabb().size.y if mesh_instance.mesh != null else 0.0
	if source_height_meters <= 0.001:
		return
	var scale_factor: float = standing_height_meters / source_height_meters
	josie_model.scale = Vector3.ONE * scale_factor
	resolved_visual_height_meters = source_height_meters * scale_factor

func _ensure_hand_attachment(
		attachment_name: String,
		bone_name: StringName,
		anchor_name: String,
		anchor_position: Vector3,
		anchor_rotation_degrees: Vector3
	) -> void:
	if skeleton == null:
		return
	var attachment: BoneAttachment3D = skeleton.get_node_or_null(attachment_name) as BoneAttachment3D
	if attachment == null:
		attachment = BoneAttachment3D.new()
		attachment.name = attachment_name
		skeleton.add_child(attachment)
	attachment.bone_name = bone_name

	var anchor: Node3D = attachment.get_node_or_null(anchor_name) as Node3D
	if anchor == null:
		anchor = Node3D.new()
		anchor.name = anchor_name
		attachment.add_child(anchor)
	anchor.position = anchor_position
	anchor.rotation_degrees = anchor_rotation_degrees

func _ensure_empty_attachment(attachment_name: String, bone_name: StringName) -> void:
	if skeleton == null:
		return
	var attachment: BoneAttachment3D = skeleton.get_node_or_null(attachment_name) as BoneAttachment3D
	if attachment == null:
		attachment = BoneAttachment3D.new()
		attachment.name = attachment_name
		skeleton.add_child(attachment)
	attachment.bone_name = bone_name

func _ensure_stow_attachment(
		attachment_name: String,
		bone_name: StringName,
		anchor_name: String,
		anchor_position: Vector3,
		anchor_rotation_degrees: Vector3
	) -> void:
	_ensure_hand_attachment(attachment_name, bone_name, anchor_name, anchor_position, anchor_rotation_degrees)

func _play_default_animation() -> void:
	_play_animation(default_animation_name, 0.0)

func _prepare_runtime_hand_pose_animations() -> void:
	if animation_player == null:
		return
	var animation_library: AnimationLibrary = animation_player.get_animation_library(&"")
	if animation_library == null:
		return
	for animation_name: StringName in _get_runtime_locomotion_animation_names():
		if animation_name == StringName():
			continue
		if not animation_library.has_animation(animation_name):
			continue
		var source_animation: Animation = animation_library.get_animation(animation_name)
		if source_animation == null:
			continue
		var runtime_animation: Animation = source_animation.duplicate() as Animation
		if runtime_animation == null:
			continue
		_strip_finger_tracks(runtime_animation)
		animation_library.remove_animation(animation_name)
		animation_library.add_animation(animation_name, runtime_animation)

func _get_runtime_locomotion_animation_names() -> Array[StringName]:
	return [
		default_animation_name,
		walk_animation_name,
		jog_animation_name,
		sprint_animation_name,
		jump_animation_name,
		fall_animation_name
	]

func _strip_finger_tracks(animation: Animation) -> void:
	for track_index: int in range(animation.get_track_count() - 1, -1, -1):
		var track_path: String = String(animation.track_get_path(track_index))
		if _is_finger_track_path(track_path) or _is_aim_track_path(track_path):
			animation.remove_track(track_index)

func _is_finger_track_path(track_path: String) -> bool:
	for finger_track_token: String in FINGER_TRACK_TOKENS:
		if track_path.contains(finger_track_token):
			return true
	return false

func _is_aim_track_path(track_path: String) -> bool:
	for aim_track_token: String in AIM_TRACK_TOKENS:
		if track_path.contains(aim_track_token):
			return true
	return false

func _resolve_locomotion_animation_name(
		horizontal_speed: float,
		target_horizontal_speed: float,
		grounded: bool,
		vertical_velocity: float,
		sprinting: bool
	) -> StringName:
	if not grounded:
		if vertical_velocity >= jump_vertical_velocity_threshold:
			return jump_animation_name
		return fall_animation_name

	if horizontal_speed <= idle_horizontal_speed_threshold:
		return default_animation_name

	var resolved_target_speed: float = maxf(target_horizontal_speed, 0.001)
	var speed_ratio: float = clampf(horizontal_speed / resolved_target_speed, 0.0, 1.5)
	if sprinting:
		return sprint_animation_name
	if speed_ratio < walk_ratio_threshold:
		return walk_animation_name
	return jog_animation_name

func _play_animation(animation_name: StringName, custom_blend_seconds: float = -1.0) -> void:
	if animation_player == null or animation_name == StringName():
		return
	if not animation_player.has_animation(String(animation_name)):
		return
	if current_animation_name == animation_name:
		return
	var blend_seconds: float = animation_blend_seconds if custom_blend_seconds < 0.0 else custom_blend_seconds
	animation_player.play(String(animation_name), blend_seconds)
	current_animation_name = animation_name

func _apply_runtime_aim_follow_pose(delta: float) -> void:
	if skeleton == null or not apply_runtime_aim_follow_pose:
		return
	var aim_intensity: float = armed_aim_follow_intensity if right_hand_grip_active or left_hand_grip_active else unarmed_aim_follow_intensity
	for aim_bone_config_variant in AIM_BONE_CONFIGS:
		var aim_bone_config: Dictionary = aim_bone_config_variant
		var bone_name: StringName = aim_bone_config["bone"]
		var yaw_weight: float = float(aim_bone_config["yaw_weight"]) * aim_intensity
		var pitch_weight: float = float(aim_bone_config["pitch_weight"]) * aim_intensity
		var smoothing_speed: float = float(aim_bone_config["smoothing_speed"])
		var target_state := Vector2(
			aim_target_local_yaw_radians * yaw_weight,
			aim_target_local_pitch_radians * pitch_weight
		)
		var current_state: Vector2 = aim_bone_state_by_name.get(bone_name, Vector2.ZERO)
		var blend_factor: float = clampf(smoothing_speed * delta, 0.0, 1.0)
		current_state = current_state.lerp(target_state, blend_factor)
		aim_bone_state_by_name[bone_name] = current_state
		_apply_bone_pose_rotation_radians(bone_name, current_state.y, current_state.x, 0.0)

func _apply_runtime_arm_aim_follow_pose(delta: float) -> void:
	if skeleton == null or not apply_runtime_arm_aim_follow_pose or _has_active_arm_ik():
		_apply_additive_bone_rotation_offsets({}, arm_last_offsets_by_bone)
		return
	var desired_offsets: Dictionary = {}
	if right_hand_grip_active:
		_append_arm_aim_offsets(desired_offsets, RIGHT_ARM_AIM_BONE_CONFIGS, delta)
	if left_hand_grip_active:
		_append_arm_aim_offsets(desired_offsets, LEFT_ARM_AIM_BONE_CONFIGS, delta)
	_apply_additive_bone_rotation_offsets(desired_offsets, arm_last_offsets_by_bone)

func _append_arm_aim_offsets(desired_offsets: Dictionary, arm_configs: Array, delta: float) -> void:
	for arm_config_variant in arm_configs:
		var arm_config: Dictionary = arm_config_variant
		var bone_name: StringName = arm_config["bone"]
		var yaw_weight: float = float(arm_config["yaw_weight"]) * armed_arm_aim_intensity
		var pitch_weight: float = float(arm_config["pitch_weight"]) * armed_arm_aim_intensity
		var smoothing_speed: float = float(arm_config["smoothing_speed"])
		var target_state := Vector2(
			aim_target_local_yaw_radians * yaw_weight,
			aim_target_local_pitch_radians * pitch_weight
		)
		var current_state: Vector2 = arm_bone_state_by_name.get(bone_name, Vector2.ZERO)
		var blend_factor: float = clampf(smoothing_speed * delta, 0.0, 1.0)
		current_state = current_state.lerp(target_state, blend_factor)
		arm_bone_state_by_name[bone_name] = current_state
		var bone_idx: int = _get_bone_index(bone_name)
		if bone_idx < 0:
			continue
		desired_offsets[bone_idx] = Quaternion.from_euler(Vector3(current_state.y, current_state.x, 0.0))

func _apply_runtime_grip_pose() -> void:
	if skeleton == null or not apply_runtime_hand_grip_pose:
		return
	if right_hand_grip_active:
		_apply_hand_grip_pose_for_slot(&"hand_right")
	if left_hand_grip_active:
		_apply_hand_grip_pose_for_slot(&"hand_left")

func _apply_hand_grip_pose_for_slot(slot_id: StringName) -> void:
	_apply_bone_pose_rotation(get_hand_bone_name(slot_id), get_hand_grip_rotation_degrees(slot_id))
	if slot_id == &"hand_right":
		_apply_finger_chain_pose([&"CC_Base_R_Index1", &"CC_Base_R_Index2", &"CC_Base_R_Index3"])
		_apply_finger_chain_pose([&"CC_Base_R_Mid1", &"CC_Base_R_Mid2", &"CC_Base_R_Mid3"])
		_apply_finger_chain_pose([&"CC_Base_R_Ring1", &"CC_Base_R_Ring2", &"CC_Base_R_Ring3"])
		_apply_finger_chain_pose([&"CC_Base_R_Pinky1", &"CC_Base_R_Pinky2", &"CC_Base_R_Pinky3"])
		_apply_thumb_pose([&"CC_Base_R_Thumb1", &"CC_Base_R_Thumb2", &"CC_Base_R_Thumb3"], right_thumb_grip_rotations_degrees)
		return
	if slot_id == &"hand_left":
		_apply_finger_chain_pose([&"CC_Base_L_Index1", &"CC_Base_L_Index2", &"CC_Base_L_Index3"])
		_apply_finger_chain_pose([&"CC_Base_L_Mid1", &"CC_Base_L_Mid2", &"CC_Base_L_Mid3"])
		_apply_finger_chain_pose([&"CC_Base_L_Ring1", &"CC_Base_L_Ring2", &"CC_Base_L_Ring3"])
		_apply_finger_chain_pose([&"CC_Base_L_Pinky1", &"CC_Base_L_Pinky2", &"CC_Base_L_Pinky3"])
		_apply_thumb_pose([&"CC_Base_L_Thumb1", &"CC_Base_L_Thumb2", &"CC_Base_L_Thumb3"], left_thumb_grip_rotations_degrees)

func _apply_finger_chain_pose(finger_chain: Array[StringName]) -> void:
	if finger_chain.size() >= 1:
		_apply_bone_pose_rotation(finger_chain[0], finger_grip_proximal_rotation_degrees)
	if finger_chain.size() >= 2:
		_apply_bone_pose_rotation(finger_chain[1], finger_grip_middle_rotation_degrees)
	if finger_chain.size() >= 3:
		_apply_bone_pose_rotation(finger_chain[2], finger_grip_distal_rotation_degrees)

func _apply_thumb_pose(thumb_chain: Array[StringName], thumb_rotations: Array[Vector3]) -> void:
	for thumb_index: int in range(mini(thumb_chain.size(), thumb_rotations.size())):
		_apply_bone_pose_rotation(thumb_chain[thumb_index], thumb_rotations[thumb_index])

func _build_hand_grip_offsets(slot_id: StringName, active: bool) -> Dictionary:
	var offsets: Dictionary = {}
	if not active:
		return offsets

	var wrist_bone: StringName = get_hand_bone_name(slot_id)
	var wrist_rotation_degrees: Vector3 = get_hand_grip_rotation_degrees(slot_id)
	_add_bone_rotation_offset(offsets, wrist_bone, wrist_rotation_degrees)

	var finger_chains: Array = get_finger_chains(slot_id)
	for finger_chain_variant in finger_chains:
		var finger_chain: Array = finger_chain_variant
		if finger_chain.size() >= 1:
			_add_bone_rotation_offset(offsets, finger_chain[0], finger_grip_proximal_rotation_degrees)
		if finger_chain.size() >= 2:
			_add_bone_rotation_offset(offsets, finger_chain[1], finger_grip_middle_rotation_degrees)
		if finger_chain.size() >= 3:
			_add_bone_rotation_offset(offsets, finger_chain[2], finger_grip_distal_rotation_degrees)

	var thumb_chain: Array = get_thumb_chain(slot_id)
	var thumb_rotations: Array[Vector3] = get_thumb_grip_rotations_degrees(slot_id)
	for thumb_index: int in range(mini(thumb_chain.size(), thumb_rotations.size())):
		_add_bone_rotation_offset(offsets, thumb_chain[thumb_index], thumb_rotations[thumb_index])

	return offsets

func _add_bone_rotation_offset(offsets: Dictionary, bone_name: StringName, local_rotation_degrees: Vector3) -> void:
	var bone_idx: int = _get_bone_index(bone_name)
	if bone_idx < 0:
		return
	offsets[bone_idx] = _degrees_to_quaternion(local_rotation_degrees)

func _apply_bone_pose_rotation(bone_name: StringName, local_rotation_degrees: Vector3) -> void:
	var bone_idx: int = _get_bone_index(bone_name)
	if bone_idx < 0:
		return
	var current_rotation: Quaternion = skeleton.get_bone_pose_rotation(bone_idx)
	skeleton.set_bone_pose_rotation(bone_idx, current_rotation * _degrees_to_quaternion(local_rotation_degrees))

func _apply_bone_pose_rotation_radians(bone_name: StringName, pitch_radians: float, yaw_radians: float, roll_radians: float) -> void:
	var bone_idx: int = _get_bone_index(bone_name)
	if bone_idx < 0:
		return
	skeleton.set_bone_pose_rotation(bone_idx, Quaternion.from_euler(Vector3(pitch_radians, yaw_radians, roll_radians)))

func _apply_additive_bone_rotation_offsets(desired_offsets: Dictionary, last_offsets: Dictionary) -> void:
	var affected_bone_indices: Array = desired_offsets.keys()
	for bone_idx_variant in last_offsets.keys():
		if not affected_bone_indices.has(bone_idx_variant):
			affected_bone_indices.append(bone_idx_variant)

	for bone_idx_variant in affected_bone_indices:
		var bone_idx: int = int(bone_idx_variant)
		var last_offset: Quaternion = last_offsets.get(bone_idx, Quaternion.IDENTITY) as Quaternion
		var desired_offset: Quaternion = desired_offsets.get(bone_idx, Quaternion.IDENTITY) as Quaternion
		var current_rotation: Quaternion = skeleton.get_bone_pose_rotation(bone_idx)
		var base_rotation: Quaternion = current_rotation * last_offset.inverse()
		skeleton.set_bone_pose_rotation(bone_idx, base_rotation * desired_offset)
		if desired_offset.is_equal_approx(Quaternion.IDENTITY):
			last_offsets.erase(bone_idx)
		else:
			last_offsets[bone_idx] = desired_offset

func _get_bone_index(bone_name: StringName) -> int:
	if bone_name == StringName():
		return -1
	if bone_index_cache.has(bone_name):
		return int(bone_index_cache[bone_name])
	var bone_idx: int = skeleton.find_bone(String(bone_name)) if skeleton != null else -1
	bone_index_cache[bone_name] = bone_idx
	return bone_idx

func _degrees_to_quaternion(local_rotation_degrees: Vector3) -> Quaternion:
	return Quaternion.from_euler(Vector3(
		deg_to_rad(local_rotation_degrees.x),
		deg_to_rad(local_rotation_degrees.y),
		deg_to_rad(local_rotation_degrees.z)
	))

func _resolve_hand_anchor_position(slot_id: StringName) -> Vector3:
	if slot_id == &"hand_right" and not right_hand_anchor_position.is_zero_approx():
		return right_hand_anchor_position
	if slot_id == &"hand_left" and not left_hand_anchor_position.is_zero_approx():
		return left_hand_anchor_position
	return _calculate_default_palm_anchor_position(slot_id)

func _calculate_default_palm_anchor_position(slot_id: StringName) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var hand_bone: StringName = RIGHT_HAND_BONE if slot_id == &"hand_right" else LEFT_HAND_BONE
	var hand_bone_idx: int = _get_bone_index(hand_bone)
	if hand_bone_idx < 0:
		return Vector3.ZERO
	var hand_rest: Transform3D = skeleton.get_bone_global_rest(hand_bone_idx)

	var finger_chains: Array = RIGHT_FINGER_CHAINS if slot_id == &"hand_right" else LEFT_FINGER_CHAINS
	var thumb_chain: Array = RIGHT_THUMB_CHAIN if slot_id == &"hand_right" else LEFT_THUMB_CHAIN

	var knuckle_center_local: Vector3 = _average_hand_local_bone_positions(hand_rest, _extract_chain_bones(finger_chains, 0))
	var middle_center_local: Vector3 = _average_hand_local_bone_positions(hand_rest, _extract_chain_bones(finger_chains, 1))
	var thumb_base_local: Vector3 = _average_hand_local_bone_positions(hand_rest, [thumb_chain[0]])
	if knuckle_center_local == Vector3.ZERO and middle_center_local == Vector3.ZERO:
		return Vector3.ZERO

	var finger_band_local: Vector3 = knuckle_center_local.lerp(middle_center_local, hand_anchor_knuckle_to_middle_blend)
	if thumb_base_local != Vector3.ZERO:
		finger_band_local = finger_band_local.lerp(thumb_base_local, hand_anchor_thumb_bias)
	return finger_band_local * hand_anchor_palm_pullback

func _extract_chain_bones(chains: Array, joint_index: int) -> Array[StringName]:
	var resolved_bones: Array[StringName] = []
	for chain_variant in chains:
		var chain: Array = chain_variant
		if joint_index < 0 or joint_index >= chain.size():
			continue
		resolved_bones.append(chain[joint_index])
	return resolved_bones

func _average_hand_local_bone_positions(hand_rest: Transform3D, bone_names: Array[StringName]) -> Vector3:
	var accumulated_local: Vector3 = Vector3.ZERO
	var valid_count: int = 0
	for bone_name: StringName in bone_names:
		var bone_idx: int = _get_bone_index(bone_name)
		if bone_idx < 0:
			continue
		var bone_rest: Transform3D = skeleton.get_bone_global_rest(bone_idx)
		accumulated_local += hand_rest.affine_inverse() * bone_rest.origin
		valid_count += 1
	if valid_count <= 0:
		return Vector3.ZERO
	return accumulated_local / float(valid_count)

func _reset_hand_grip_pose(slot_id: StringName) -> void:
	if skeleton == null:
		return
	var bone_names: Array[StringName] = []
	if slot_id == &"hand_right":
		bone_names.append(RIGHT_HAND_BONE)
		for finger_chain_variant in RIGHT_FINGER_CHAINS:
			var finger_chain: Array = finger_chain_variant
			for bone_name_variant in finger_chain:
				bone_names.append(bone_name_variant)
		for bone_name_variant in RIGHT_THUMB_CHAIN:
			bone_names.append(bone_name_variant)
	elif slot_id == &"hand_left":
		bone_names.append(LEFT_HAND_BONE)
		for finger_chain_variant in LEFT_FINGER_CHAINS:
			var finger_chain: Array = finger_chain_variant
			for bone_name_variant in finger_chain:
				bone_names.append(bone_name_variant)
		for bone_name_variant in LEFT_THUMB_CHAIN:
			bone_names.append(bone_name_variant)
	else:
		return

	for bone_name: StringName in bone_names:
		var bone_idx: int = _get_bone_index(bone_name)
		if bone_idx < 0:
			continue
		skeleton.reset_bone_pose(bone_idx)
