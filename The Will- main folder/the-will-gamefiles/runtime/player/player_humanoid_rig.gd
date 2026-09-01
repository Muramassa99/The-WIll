extends Node3D
class_name PlayerHumanoidRig

const PlayerRigModelPresenterScript = preload("res://runtime/player/player_rig_model_presenter.gd")
const PlayerRigGuidanceStatePresenterScript = preload("res://runtime/player/player_rig_guidance_state_presenter.gd")
const PlayerRigLocomotionPresenterScript = preload("res://runtime/player/player_rig_locomotion_presenter.gd")
const PlayerRigGripLayoutPresenterScript = preload("res://runtime/player/player_rig_grip_layout_presenter.gd")
const PlayerRigSupportArmIkPresenterScript = preload("res://runtime/player/player_rig_support_arm_ik_presenter.gd")
const PlayerRigFingerGripPresenterScript = preload("res://runtime/player/player_rig_finger_grip_presenter.gd")
const PlayerDigitHingeRulesScript = preload("res://runtime/player/player_digit_hinge_rules.gd")
const PlayerRigUpperBodyPosePresenterScript = preload("res://runtime/player/player_rig_upper_body_pose_presenter.gd")
const PlayerCombatAuthoringModifier3DScript = preload("res://runtime/player/player_combat_authoring_modifier_3d.gd")
const PlayerRuntimeSolvedReplayModifier3DScript = preload("res://runtime/player/player_runtime_solved_replay_modifier_3d.gd")
const PlayerRuntimeBodyRestrictionSyncModifier3DScript = preload("res://runtime/player/player_runtime_body_restriction_sync_modifier_3d.gd")
const PlayerRuntimeBoneDebugModifier3DScript = preload("res://runtime/player/player_runtime_bone_debug_modifier_3d.gd")
const HandTargetConstraintSolverScript = preload("res://runtime/player/hand_target_constraint_solver.gd")
const TwoHandPoseSolverScript = preload("res://runtime/player/two_hand_pose_solver.gd")
const GripDebugDrawScript = preload("res://runtime/player/grip_debug_draw.gd")
const RuntimeBoneDebugDrawScript = preload("res://runtime/player/runtime_bone_debug_draw.gd")
const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")
const RIGHT_HAND_BONE := &"CC_Base_R_Hand"
const LEFT_HAND_BONE := &"CC_Base_L_Hand"
const RIGHT_INDEX1_BONE := &"CC_Base_R_Index1"
const LEFT_INDEX1_BONE := &"CC_Base_L_Index1"
const RIGHT_PINKY1_BONE := &"CC_Base_R_Pinky1"
const LEFT_PINKY1_BONE := &"CC_Base_L_Pinky1"
const RIGHT_THIGH_BONE := &"CC_Base_R_Thigh"
const LEFT_THIGH_BONE := &"CC_Base_L_Thigh"
const HIP_BONE := &"CC_Base_Hip"
const WAIST_BONE := &"CC_Base_Waist"
const SPINE_01_BONE := &"CC_Base_Spine01"
const SPINE_02_BONE := &"CC_Base_Spine02"
const RIGHT_CLAVICLE_BONE := &"CC_Base_R_Clavicle"
const LEFT_CLAVICLE_BONE := &"CC_Base_L_Clavicle"
const RIGHT_UPPERARM_BONE := &"CC_Base_R_Upperarm"
const LEFT_UPPERARM_BONE := &"CC_Base_L_Upperarm"
const RIGHT_FOREARM_BONE := &"CC_Base_R_Forearm"
const LEFT_FOREARM_BONE := &"CC_Base_L_Forearm"
const RIGHT_UPPERARM_TWIST_BONES := [&"CC_Base_R_UpperarmTwist01", &"CC_Base_R_UpperarmTwist02"]
const LEFT_UPPERARM_TWIST_BONES := [&"CC_Base_L_UpperarmTwist01", &"CC_Base_L_UpperarmTwist02"]
const RIGHT_FOREARM_TWIST_BONES := [&"CC_Base_R_ForearmTwist01", &"CC_Base_R_ForearmTwist02"]
const LEFT_FOREARM_TWIST_BONES := [&"CC_Base_L_ForearmTwist01", &"CC_Base_L_ForearmTwist02"]
const RIGHT_FINGER_POSE_BONES := [
	&"CC_Base_R_Thumb1",
	&"CC_Base_R_Thumb2",
	&"CC_Base_R_Thumb3",
	&"CC_Base_R_Index1",
	&"CC_Base_R_Index2",
	&"CC_Base_R_Index3",
	&"CC_Base_R_Mid1",
	&"CC_Base_R_Mid2",
	&"CC_Base_R_Mid3",
	&"CC_Base_R_Ring1",
	&"CC_Base_R_Ring2",
	&"CC_Base_R_Ring3",
	&"CC_Base_R_Pinky1",
	&"CC_Base_R_Pinky2",
	&"CC_Base_R_Pinky3",
]
const LEFT_FINGER_POSE_BONES := [
	&"CC_Base_L_Thumb1",
	&"CC_Base_L_Thumb2",
	&"CC_Base_L_Thumb3",
	&"CC_Base_L_Index1",
	&"CC_Base_L_Index2",
	&"CC_Base_L_Index3",
	&"CC_Base_L_Mid1",
	&"CC_Base_L_Mid2",
	&"CC_Base_L_Mid3",
	&"CC_Base_L_Ring1",
	&"CC_Base_L_Ring2",
	&"CC_Base_L_Ring3",
	&"CC_Base_L_Pinky1",
	&"CC_Base_L_Pinky2",
	&"CC_Base_L_Pinky3",
]
const RUNTIME_UPPER_BODY_POSE_BONES: Array[StringName] = [
	HIP_BONE,
	WAIST_BONE,
	SPINE_01_BONE,
	SPINE_02_BONE,
	RIGHT_CLAVICLE_BONE,
	LEFT_CLAVICLE_BONE,
	RIGHT_UPPERARM_BONE,
	LEFT_UPPERARM_BONE,
	RIGHT_FOREARM_BONE,
	LEFT_FOREARM_BONE,
	RIGHT_HAND_BONE,
	LEFT_HAND_BONE,
	RIGHT_UPPERARM_TWIST_BONES[0],
	RIGHT_UPPERARM_TWIST_BONES[1],
	LEFT_UPPERARM_TWIST_BONES[0],
	LEFT_UPPERARM_TWIST_BONES[1],
	RIGHT_FOREARM_TWIST_BONES[0],
	RIGHT_FOREARM_TWIST_BONES[1],
	LEFT_FOREARM_TWIST_BONES[0],
	LEFT_FOREARM_TWIST_BONES[1],
	RIGHT_FINGER_POSE_BONES[0],
	RIGHT_FINGER_POSE_BONES[1],
	RIGHT_FINGER_POSE_BONES[2],
	RIGHT_FINGER_POSE_BONES[3],
	RIGHT_FINGER_POSE_BONES[4],
	RIGHT_FINGER_POSE_BONES[5],
	RIGHT_FINGER_POSE_BONES[6],
	RIGHT_FINGER_POSE_BONES[7],
	RIGHT_FINGER_POSE_BONES[8],
	RIGHT_FINGER_POSE_BONES[9],
	RIGHT_FINGER_POSE_BONES[10],
	RIGHT_FINGER_POSE_BONES[11],
	RIGHT_FINGER_POSE_BONES[12],
	RIGHT_FINGER_POSE_BONES[13],
	RIGHT_FINGER_POSE_BONES[14],
	LEFT_FINGER_POSE_BONES[0],
	LEFT_FINGER_POSE_BONES[1],
	LEFT_FINGER_POSE_BONES[2],
	LEFT_FINGER_POSE_BONES[3],
	LEFT_FINGER_POSE_BONES[4],
	LEFT_FINGER_POSE_BONES[5],
	LEFT_FINGER_POSE_BONES[6],
	LEFT_FINGER_POSE_BONES[7],
	LEFT_FINGER_POSE_BONES[8],
	LEFT_FINGER_POSE_BONES[9],
	LEFT_FINGER_POSE_BONES[10],
	LEFT_FINGER_POSE_BONES[11],
	LEFT_FINGER_POSE_BONES[12],
	LEFT_FINGER_POSE_BONES[13],
	LEFT_FINGER_POSE_BONES[14],
]
const AUTHORING_DIRECT_ARM_SOLVE_ITERATIONS: int = 12
const AUTHORING_DIRECT_ARM_SOLVE_EPSILON_METERS: float = 0.006
const AUTHORING_DIRECT_ARM_FOREARM_WEIGHT: float = 0.86
const AUTHORING_DIRECT_ARM_UPPERARM_WEIGHT: float = 0.74
const AUTHORING_DIRECT_ARM_CLAVICLE_WEIGHT: float = 0.22
const AUTHORING_ARM_SPLINE_CLAVICLE_WEIGHT: float = 0.14
const AUTHORING_ARM_SPLINE_UPPERARM_WEIGHT: float = 0.30
const AUTHORING_ARM_SPLINE_FOREARM_WEIGHT: float = 0.50
const AUTHORING_ARM_SPLINE_RESEAT_ITERATIONS: int = 2
const AUTHORING_DRAG_DIRECT_ARM_SOLVE_ITERATIONS: int = AUTHORING_DIRECT_ARM_SOLVE_ITERATIONS
const AUTHORING_DRAG_ARM_SPLINE_RESEAT_ITERATIONS: int = AUTHORING_ARM_SPLINE_RESEAT_ITERATIONS
const AUTHORING_DRAG_CONTACT_ALIGNMENT_PASSES: int = 1
# The upper-body authoring presenter deliberately blends toward its solved pose.
# Finish that inexpensive blend before an exact support-hand surface solve so
# cached digit angles are attached to the final macro hand frame.
const AUTHORING_GRIP_RELATIONSHIP_MACRO_SETTLE_PASSES: int = 5
const AUTHORING_GRIP_RELATIONSHIP_CONTACT_SETTLE_PASSES: int = 3
const AUTHORING_GRIP_RELATIONSHIP_PRECISE_SETTLE_PASSES: int = 6
const AUTHORING_GRIP_RELATIONSHIP_PRECISE_SOLVE_ITERATIONS: int = 24
const AUTHORING_GRIP_RELATIONSHIP_ALIGNMENT_EPSILON_METERS: float = 0.0005
const AUTHORING_GRIP_RELATIONSHIP_CONTACT_AXIS_EPSILON_DEGREES: float = 0.5
const AUTHORING_SHOULDER_ENDPOINT_RESEAT_EPSILON_METERS: float = 0.00005
const AUTHORING_ARM_SPLINE_CONTACT_AXIS_BIAS: float = 0.0
const AUTHORING_LIMB_TWIST_FOREARM_SHARE: float = 0.78
const AUTHORING_LIMB_TWIST_UPPERARM_SHARE: float = 0.22
const AUTHORING_LIMB_TWIST_LIMIT_RADIANS: float = PI * 0.5
const AUTHORING_LIMB_TWIST_LOCAL_AXIS: Vector3 = Vector3.UP
const AUTHORING_JOINT_RANGE_DEBUG_ROOT_NAME := "AuthoringJointRangeDebugRoot"
const AUTHORING_JOINT_RANGE_ARC_STEPS: int = 28
const AUTHORING_JOINT_RANGE_WARNING_MARGIN_DEGREES: float = 8.0
const AUTHORING_JOINT_RANGE_EPSILON_DEGREES: float = 0.05
const AUTHORING_DIGIT_HINGE_OFF_AXIS_TOLERANCE_DEGREES: float = 0.5
const AUTHORING_DIGIT_RANGE_MIN_RADIUS_METERS: float = 0.012
const AUTHORING_DIGIT_RANGE_MAX_RADIUS_METERS: float = 0.032
const RUNTIME_LOCOMOTION_ANIMATION_TREE_NAME := "RuntimeLocomotionAnimationTree"
const RUNTIME_LOCOMOTION_PLAYBACK_PATH := "parameters/playback"
const RUNTIME_SOLVED_REPLAY_MODIFIER_NAME := "RuntimeSolvedReplayModifier"
const RUNTIME_SOLVED_REPLAY_REFERENCE_BONE := &"RL_BoneRoot"
const RUNTIME_ENDPOINT_AUTHORITY_ROOT_NAME := "RuntimeCombatEndpointAuthorityRoot"
const RUNTIME_BODY_RESTRICTION_SYNC_MODIFIER_NAME := "RuntimeBodyRestrictionSyncModifier"
const RUNTIME_BONE_DEBUG_MODIFIER_NAME := "RuntimeBoneDebugModifier"
const COMBAT_AUTHORING_MODIFIER_NAME := "CombatAuthoringModifier"
const STOW_UPPER_BACK_OFFSET_METERS := 0.18
const STOW_HIP_SIDE_OFFSET_METERS := 0.23
const STOW_LOWER_BACK_OFFSET_METERS := 0.20
@export_range(1.6, 2.4, 0.01) var standing_height_meters: float = 2.0
@export_range(0.0, 0.5, 0.01) var pole_grip_arm_reach_margin_percent: float = 0.10
@export_range(0.50, 1.0, 0.01) var usable_arm_motion_range_ratio: float = 0.98
@export var right_hand_anchor_position: Vector3 = Vector3(-0.0025, 0.0969, 0.0190)
@export var right_hand_anchor_rotation_degrees: Vector3 = Vector3(0.0, 90.0, 0.0)
@export var left_hand_anchor_position: Vector3 = Vector3(0.0025, 0.0969, 0.0190)
@export var left_hand_anchor_rotation_degrees: Vector3 = Vector3(0.0, -90.0, 0.0)

@export_category("Support Arm IK")
@export var enable_support_arm_ik: bool = true
@export_range(0.0, 1.0, 0.01) var support_arm_ik_influence: float = 1.0
@export_range(1.0, 30.0, 0.1) var support_arm_ik_target_smoothing_speed: float = 12.0
@export_range(0.0, 0.6, 0.01) var support_arm_ik_pole_side_offset_meters: float = 0.24
@export_range(0.0, 0.6, 0.01) var support_arm_ik_pole_down_offset_meters: float = 0.18
@export_range(0.0, 0.4, 0.01) var support_arm_ik_pole_back_offset_meters: float = 0.08

@export_category("Two Hand Grip Constraint")
@export_range(0.0, 0.4, 0.01) var two_hand_front_bias_meters: float = 0.18
@export_range(0.0, 0.3, 0.01) var two_hand_safety_margin_meters: float = 0.08
@export_range(0.0, 0.4, 0.01) var two_hand_orbit_radius_meters: float = 0.14
@export_range(1.0, 3.0, 0.1) var two_hand_orbit_radius_scale: float = 1.5
@export_range(0.0, 0.2, 0.01) var two_hand_orbit_vertical_bias_meters: float = 0.04
@export_range(4, 24, 1) var two_hand_orbit_sample_count: int = 10
@export var show_two_hand_grip_debug_markers: bool = false

@export_category("Finger Grip IK")
@export var enable_finger_grip_ik: bool = true
@export_range(0.0, 1.0, 0.01) var finger_grip_ik_influence: float = 1.0
@export_range(1.0, 30.0, 0.1) var finger_grip_target_smoothing_speed: float = 16.0

@export_category("Upper Body Authoring")
@export var enable_upper_body_authoring_pose: bool = true
@export_range(0.0, 1.0, 0.01) var upper_body_authoring_pose_strength: float = 1.0
@export var enable_authoring_contact_wrist_basis: bool = true
@export var enable_authoring_limb_twist_distribution: bool = true
@export_range(0.0, 1.0, 0.01) var authoring_contact_wrist_basis_strength: float = 1.0
@export_range(0.0, 1.0, 0.01) var authoring_contact_wrist_straightness_bias: float = 0.0
@export_range(0.0, 180.0, 1.0) var authoring_contact_wrist_twist_limit_degrees: float = 0.0
@export var show_authoring_joint_range_debug: bool = true
@export var show_authoring_joint_range_labels: bool = false
@export_category("Runtime Bone Debug")
@export var show_runtime_bone_debug: bool = false
@export var runtime_bone_debug_draw_all_bones: bool = true
@export var runtime_bone_debug_show_labels: bool = true
@export_category("Upper Body Authoring")
@export_range(0.0, 90.0, 1.0) var authoring_shoulder_min_plane_angle_degrees: float = 8.0
@export_range(45.0, 180.0, 1.0) var authoring_shoulder_max_plane_angle_degrees: float = 155.0
@export_range(0.0, 90.0, 1.0) var authoring_elbow_min_plane_angle_degrees: float = 20.0
@export_range(90.0, 180.0, 1.0) var authoring_elbow_max_plane_angle_degrees: float = 168.0
@export_range(0.0, 0.05, 0.001) var body_clearance_proxy_offset_meters: float = 0.005

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

@export_category("Locomotion")
@export var default_animation_name: StringName = &"Idle"
@export var two_hand_idle_animation_name: StringName = &"2 Hand Idle"
@export var walk_animation_name: StringName = &"Walk"
@export var jog_animation_name: StringName = &"SlowRun"
@export var sprint_animation_name: StringName = &"Run"
@export var jump_animation_name: StringName = &"Jump(Pose)"
@export var fall_animation_name: StringName = &"Fall(Pose)"
@export_range(0.01, 2.0, 0.01) var animation_blend_seconds: float = 0.18
@export_range(0.0, 1.0, 0.01) var idle_horizontal_speed_threshold: float = 0.08
@export_range(0.0, 1.0, 0.01) var walk_ratio_threshold: float = 0.45
@export_range(-10.0, 10.0, 0.01) var jump_vertical_velocity_threshold: float = 0.12

@onready var josie_model: Node3D = $JosieModel
@onready var skeleton: Skeleton3D = $JosieModel/Josie/Skeleton3D
@onready var mesh_instance: MeshInstance3D = $JosieModel/Josie/Skeleton3D/Mesh
@onready var animation_player: AnimationPlayer = $JosieModel/AnimationPlayer
@onready var runtime_locomotion_animation_tree: AnimationTree = josie_model.get_node_or_null(RUNTIME_LOCOMOTION_ANIMATION_TREE_NAME) as AnimationTree
@onready var ik_targets_root: Node3D = $IkTargets
@onready var right_hand_ik_target: Node3D = $IkTargets/RightHandIkTarget
@onready var left_hand_ik_target: Node3D = $IkTargets/LeftHandIkTarget
@onready var right_hand_pole_target: Node3D = $IkTargets/RightHandPoleTarget
@onready var left_hand_pole_target: Node3D = $IkTargets/LeftHandPoleTarget

var resolved_visual_height_meters: float = 0.0
var max_model_arm_reach_meters: float = 0.0
var max_model_arm_reach_combat_meters: float = 0.0
var right_max_arm_chain_reach_meters: float = 0.0
var left_max_arm_chain_reach_meters: float = 0.0
var right_usable_arm_chain_reach_meters: float = 0.0
var left_usable_arm_chain_reach_meters: float = 0.0
var pole_grip_negative_limit_meters: float = 0.0
var pole_grip_positive_limit_meters: float = 0.0
var right_arm_ik_modifier: TwoBoneIK3D = null
var left_arm_ik_modifier: TwoBoneIK3D = null
var combat_authoring_modifier: SkeletonModifier3D = null
var runtime_solved_replay_modifier: SkeletonModifier3D = null
var runtime_body_restriction_sync_modifier: SkeletonModifier3D = null
var runtime_bone_debug_modifier: SkeletonModifier3D = null
var bone_index_cache: Dictionary = {}
var rig_model_presenter = PlayerRigModelPresenterScript.new()
var guidance_state_presenter = PlayerRigGuidanceStatePresenterScript.new()
var locomotion_presenter = PlayerRigLocomotionPresenterScript.new()
var grip_layout_presenter = PlayerRigGripLayoutPresenterScript.new()
var support_arm_ik_presenter = PlayerRigSupportArmIkPresenterScript.new()
var finger_grip_presenter = PlayerRigFingerGripPresenterScript.new()
var upper_body_pose_presenter = PlayerRigUpperBodyPosePresenterScript.new()
var hand_target_constraint_solver = HandTargetConstraintSolverScript.new()
var two_hand_pose_solver = TwoHandPoseSolverScript.new()
var grip_debug_draw = GripDebugDrawScript.new()
var runtime_bone_debug_draw = RuntimeBoneDebugDrawScript.new()
var finger_grip_source_lookup: Dictionary = {}
var finger_grip_target_lookup: Dictionary = {}
var finger_grip_modifier_lookup: Dictionary = {}
var body_restriction_root: Node3D = null
var grip_solve_root: Node3D = null
var runtime_bone_debug_root: Node3D = null
var authoring_joint_range_debug_root: Node3D = null
var authoring_joint_range_debug_state: Dictionary = {}
var authoring_joint_range_debug_pose_snapshot: Dictionary = {}
var authoring_joint_range_debug_config_signature: int = 0
var runtime_bone_debug_state: Dictionary = {}
var dominant_grip_slot_id: StringName = StringName()
var locomotion_grounded: bool = true
var locomotion_horizontal_speed: float = 0.0
var locomotion_vertical_velocity: float = 0.0
var runtime_locomotion_state_machine_playback: AnimationNodeStateMachinePlayback = null
var upper_body_authoring_state: Dictionary = {}
var authoring_contact_anchor_basis_lookup: Dictionary = {}
var authoring_limb_twist_neutral_rotation_lookup: Dictionary = {}
var authoring_digit_hinge_neutral_rotation_lookup: Dictionary = {}
var authoring_limb_twist_distribution_state: Dictionary = {}
var last_two_hand_solve_result: Dictionary = {}
var upper_body_authoring_auto_apply_enabled: bool = true
var authoring_preview_mode_enabled: bool = false
var authoring_preview_baseline_animation_name: StringName = StringName()
var combat_authoring_modifier_processing: bool = false
var runtime_solved_replay_modifier_processing: bool = false
var runtime_solved_replay_pose_state: Dictionary = {}
var runtime_solved_replay_weapon_state: Dictionary = {}
var runtime_debug_visuals_visible: bool = false

func _ready() -> void:
	_apply_target_height_scale()
	guidance_state_presenter.reset_state()
	if skeleton != null:
		skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
	_ensure_combat_authoring_modifier()
	_ensure_runtime_solved_replay_modifier()
	_ensure_hand_attachment("RightHandAttachment", RIGHT_HAND_BONE, "RightHandItemAnchor", right_hand_anchor_position, right_hand_anchor_rotation_degrees)
	_ensure_hand_attachment("LeftHandAttachment", LEFT_HAND_BONE, "LeftHandItemAnchor", left_hand_anchor_position, left_hand_anchor_rotation_degrees)
	var stow_anchor_origin_id: StringName = CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	var upper_back_stow_direction_local: Vector3 = Vector3(0.0, 0.0, -1.0)
	var upper_back_stow_direction_origin_id: StringName = stow_anchor_origin_id
	var hip_stow_right_direction_local: Vector3 = _resolve_hip_stow_right_direction_local()
	var hip_stow_right_direction_origin_id: StringName = stow_anchor_origin_id
	var hip_stow_left_direction_local: Vector3 = -hip_stow_right_direction_local
	var hip_stow_left_direction_origin_id: StringName = hip_stow_right_direction_origin_id
	_ensure_stow_attachment_from_direction("LeftShoulderStowAttachment", LEFT_CLAVICLE_BONE, "LeftShoulderStowAnchor", upper_back_stow_direction_local, upper_back_stow_direction_origin_id, STOW_UPPER_BACK_OFFSET_METERS)
	_ensure_stow_attachment_from_direction("RightShoulderStowAttachment", RIGHT_CLAVICLE_BONE, "RightShoulderStowAnchor", upper_back_stow_direction_local, upper_back_stow_direction_origin_id, STOW_UPPER_BACK_OFFSET_METERS)
	_ensure_stow_attachment_from_direction("LeftHipStowAttachment", HIP_BONE, "LeftHipStowAnchor", hip_stow_left_direction_local, hip_stow_left_direction_origin_id, STOW_HIP_SIDE_OFFSET_METERS)
	_ensure_stow_attachment_from_direction("RightHipStowAttachment", HIP_BONE, "RightHipStowAnchor", hip_stow_right_direction_local, hip_stow_right_direction_origin_id, STOW_HIP_SIDE_OFFSET_METERS)
	_ensure_stow_attachment_from_direction("LeftLowerBackStowAttachment", HIP_BONE, "LeftLowerBackStowAnchor", upper_back_stow_direction_local, upper_back_stow_direction_origin_id, STOW_LOWER_BACK_OFFSET_METERS)
	_ensure_stow_attachment_from_direction("RightLowerBackStowAttachment", HIP_BONE, "RightLowerBackStowAnchor", upper_back_stow_direction_local, upper_back_stow_direction_origin_id, STOW_LOWER_BACK_OFFSET_METERS)
	max_model_arm_reach_meters = _resolve_max_model_arm_reach_meters()
	_apply_pole_grip_arm_reach_limits()
	_resolve_arm_chain_reach_limits()
	_ensure_support_arm_ik_modifiers()
	_ensure_finger_grip_ik_targets_and_modifiers()
	body_restriction_root = hand_target_constraint_solver.call("ensure_body_restriction_root", self, skeleton, mesh_instance, body_clearance_proxy_offset_meters) as Node3D
	_ensure_runtime_body_restriction_sync_modifier()
	_ensure_runtime_bone_debug_modifier()
	_refresh_runtime_modifier_order()
	upper_body_pose_presenter.warm_cache()
	grip_solve_root = grip_debug_draw.call("ensure_debug_root", self) as Node3D
	runtime_bone_debug_root = runtime_bone_debug_draw.call("ensure_debug_root", self) as Node3D
	_snap_support_arm_ik_targets_to_current_pose()
	_refresh_support_arm_ik_influences()
	_refresh_finger_grip_ik_influences()
	_ensure_runtime_locomotion_animation_tree()
	_refresh_combat_authoring_modifier_state()
	_refresh_runtime_solved_replay_modifier_state()
	_refresh_runtime_body_restriction_sync_modifier_state()
	_refresh_runtime_bone_debug_modifier_state()
	process_priority = 10
	set_process(true)
	if not authoring_preview_mode_enabled:
		_play_default_animation()

func _process(delta: float) -> void:
	_refresh_combat_authoring_modifier_state()
	_refresh_runtime_solved_replay_modifier_state()
	_refresh_runtime_body_restriction_sync_modifier_state()
	_refresh_runtime_bone_debug_modifier_state()
	if _uses_direct_authoring_solver_mode() and not authoring_preview_mode_enabled:
		_sync_authoring_joint_range_debug_if_pose_changed()
		return
	if upper_body_authoring_auto_apply_enabled:
		_apply_upper_body_authoring_pose()
	_update_support_arm_ik_targets(delta)
	_refresh_support_arm_ik_influences()
	_apply_authoring_contact_alignment_pose()
	_update_finger_grip_targets(delta)
	_refresh_finger_grip_ik_influences()
	if authoring_preview_mode_enabled:
		_advance_skeleton_modifiers_now(delta)
	_sync_authoring_joint_range_debug_if_pose_changed()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_runtime_debug_visual_toggle_event(event):
		return
	if _has_runtime_debug_visual_controller():
		return
	set_runtime_debug_visuals_visible(not runtime_debug_visuals_visible)
	get_viewport().set_input_as_handled()

func set_runtime_debug_visuals_visible(debug_visible: bool) -> void:
	runtime_debug_visuals_visible = debug_visible
	set_runtime_bone_debug_visible(debug_visible)
	show_two_hand_grip_debug_markers = debug_visible
	_set_body_restriction_debug_meshes_visible(debug_visible)
	if grip_solve_root != null and is_instance_valid(grip_solve_root):
		grip_solve_root.visible = debug_visible

func set_runtime_bone_debug_visible(debug_visible: bool) -> void:
	show_runtime_bone_debug = debug_visible
	_refresh_runtime_bone_debug_modifier_state()
	if not show_runtime_bone_debug:
		process_runtime_bone_debug_modifier_frame(0.0)

func get_runtime_bone_debug_state() -> Dictionary:
	return runtime_bone_debug_state.duplicate(true)

func process_runtime_bone_debug_modifier_frame(_delta: float = 1.0 / 60.0) -> void:
	if runtime_bone_debug_root == null or not is_instance_valid(runtime_bone_debug_root):
		runtime_bone_debug_root = runtime_bone_debug_draw.call("ensure_debug_root", self) as Node3D
	runtime_bone_debug_state = runtime_bone_debug_draw.call(
		"update_debug_skeleton",
		runtime_bone_debug_root,
		skeleton,
		show_runtime_bone_debug,
		RUNTIME_UPPER_BODY_POSE_BONES,
		RUNTIME_SOLVED_REPLAY_REFERENCE_BONE,
		runtime_bone_debug_draw_all_bones,
		runtime_bone_debug_show_labels
	) as Dictionary

func get_standing_height_meters() -> float:
	return standing_height_meters

func get_visual_height_meters() -> float:
	return resolved_visual_height_meters

func get_max_model_arm_reach_meters() -> float:
	return max_model_arm_reach_meters

func get_max_model_arm_reach_combat_meters() -> float:
	return max_model_arm_reach_combat_meters

func get_usable_arm_motion_range_ratio() -> float:
	return clampf(usable_arm_motion_range_ratio, 0.0, 1.0)

func get_max_arm_chain_reach_meters(slot_id: StringName) -> float:
	return left_max_arm_chain_reach_meters if slot_id == &"hand_left" else right_max_arm_chain_reach_meters

func get_usable_arm_chain_reach_meters(slot_id: StringName) -> float:
	return maxf(get_max_arm_chain_reach_meters(slot_id) * get_usable_arm_motion_range_ratio(), 0.0)

func get_pole_grip_negative_limit_meters() -> float:
	return pole_grip_negative_limit_meters

func get_pole_grip_positive_limit_meters() -> float:
	return pole_grip_positive_limit_meters

func get_required_cc_base_bone_names() -> Array[StringName]:
	return [
		RIGHT_HAND_BONE,
		LEFT_HAND_BONE,
		RIGHT_CLAVICLE_BONE,
		LEFT_CLAVICLE_BONE,
		RIGHT_UPPERARM_BONE,
		LEFT_UPPERARM_BONE,
		RIGHT_FOREARM_BONE,
		LEFT_FOREARM_BONE,
		RIGHT_THIGH_BONE,
		LEFT_THIGH_BONE
	]

func get_arm_guidance_target(slot_id: StringName) -> Node3D:
	return guidance_state_presenter.get_arm_guidance_target(slot_id)

func is_arm_guidance_active(slot_id: StringName) -> bool:
	return guidance_state_presenter.is_arm_guidance_active(slot_id)

func is_support_hand_active(slot_id: StringName) -> bool:
	return guidance_state_presenter.is_support_hand_active(slot_id)

func resolve_grip_hold_layout(
		baked_profile: BakedProfile,
		dominant_slot_id: StringName,
		cell_world_size_meters: float
	) -> Dictionary:
	return grip_layout_presenter.resolve_grip_hold_layout(
		baked_profile,
		dominant_slot_id,
		cell_world_size_meters,
		max_model_arm_reach_combat_meters
	)

func get_current_animation_name() -> StringName:
	return locomotion_presenter.get_current_animation_name()

func has_animation_name(animation_name: StringName) -> bool:
	return locomotion_presenter.has_animation_name(animation_player, animation_name)

func get_right_hand_item_anchor() -> Node3D:
	return rig_model_presenter.get_right_hand_item_anchor(self)

func get_left_hand_item_anchor() -> Node3D:
	return rig_model_presenter.get_left_hand_item_anchor(self)

func resolve_hand_grip_alignment_offset_origin_id(_slot_id: StringName) -> StringName:
	return CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT

func resolve_hand_grip_alignment_offset_state(slot_id: StringName) -> Dictionary:
	return {
		"hand_alignment_offset_local": resolve_hand_grip_alignment_offset_local(slot_id),
		"hand_alignment_offset_origin_id": resolve_hand_grip_alignment_offset_origin_id(slot_id),
	}

func resolve_hand_grip_alignment_offset_local(slot_id: StringName) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var hand_anchor: Node3D = get_right_hand_item_anchor() if slot_id == &"hand_right" else get_left_hand_item_anchor()
	if hand_anchor == null:
		return Vector3.ZERO
	var contact_center_world: Vector3 = _resolve_hand_index_pinky_contact_center_world(slot_id)
	var grip_center_world: Vector3 = contact_center_world
	if grip_center_world.length_squared() <= 0.000001:
		grip_center_world = finger_grip_presenter.resolve_hand_grip_alignment_world_position(skeleton, slot_id)
	else:
		grip_center_world = _resolve_anatomically_seated_hand_grip_center_world(
			slot_id,
			contact_center_world
		)
	if grip_center_world.length_squared() <= 0.000001:
		return Vector3.ZERO
	return hand_anchor.to_local(grip_center_world)

func resolve_hand_grip_alignment_world_position(slot_id: StringName) -> Vector3:
	return _resolve_default_hand_grip_alignment_world_position(slot_id)

func _resolve_default_hand_grip_alignment_world_position(slot_id: StringName) -> Vector3:
	var hand_anchor: Node3D = get_right_hand_item_anchor() if slot_id == &"hand_right" else get_left_hand_item_anchor()
	if hand_anchor == null:
		return Vector3.ZERO
	var grip_alignment_offset_local: Vector3 = resolve_hand_grip_alignment_offset_local(slot_id)
	return hand_anchor.to_global(grip_alignment_offset_local)

func resolve_hand_surface_seat_anatomy_state(slot_id: StringName) -> Dictionary:
	var invalid := {
		"valid": false,
		"status": &"missing_hand_surface_seat_anatomy",
	}
	if skeleton == null:
		return invalid
	var index_bone: StringName = RIGHT_INDEX1_BONE
	var pinky_bone: StringName = RIGHT_PINKY1_BONE
	if slot_id == &"hand_left":
		index_bone = LEFT_INDEX1_BONE
		pinky_bone = LEFT_PINKY1_BONE
	var index_index: int = skeleton.find_bone(String(index_bone))
	var pinky_index: int = skeleton.find_bone(String(pinky_bone))
	if index_index < 0 or pinky_index < 0:
		invalid["status"] = &"hand_surface_seat_bones_missing"
		return invalid
	var index_world: Vector3 = skeleton.to_global(
		skeleton.get_bone_global_pose(index_index).origin
	)
	var pinky_world: Vector3 = skeleton.to_global(
		skeleton.get_bone_global_pose(pinky_index).origin
	)
	if (
		not index_world.is_finite()
		or not pinky_world.is_finite()
		or index_world.distance_squared_to(pinky_world) <= 0.000001
	):
		invalid["status"] = &"hand_surface_seat_anatomy_degenerate"
		return invalid
	var index_skin_radius_meters: float = (
		PlayerDigitHingeRulesScript.get_contact_capsule_radius_meters(
			slot_id,
			&"index",
			1
		)
	)
	var pinky_skin_radius_meters: float = (
		PlayerDigitHingeRulesScript.get_contact_capsule_radius_meters(
			slot_id,
			&"pinky",
			1
		)
	)
	if index_skin_radius_meters <= 0.0 or pinky_skin_radius_meters <= 0.0:
		invalid["status"] = &"hand_surface_seat_skin_calibration_missing"
		return invalid
	var ordinary_proximal_capsules: Array[Dictionary] = []
	var authorized_closing_directions: Dictionary = {}
	for digit_id: StringName in [&"index", &"middle", &"ring", &"pinky"]:
		var chain_rules: Array[Dictionary] = (
			PlayerDigitHingeRulesScript.get_chain_rules(slot_id, digit_id)
		)
		if chain_rules.size() != 3:
			invalid["status"] = &"hand_surface_seat_proximal_rules_missing"
			return invalid
		var proximal_rule: Dictionary = chain_rules[0]
		var start_bone: StringName = proximal_rule.get(
			"bone",
			StringName()
		) as StringName
		var end_bone: StringName = proximal_rule.get(
			"next_bone",
			StringName()
		) as StringName
		var start_index: int = skeleton.find_bone(String(start_bone))
		var end_index: int = skeleton.find_bone(String(end_bone))
		var radius_meters: float = (
			PlayerDigitHingeRulesScript.get_contact_capsule_radius_meters(
				slot_id,
				digit_id,
				1
			)
		)
		if start_index < 0 or end_index < 0 or radius_meters <= 0.0:
			invalid["status"] = &"hand_surface_seat_proximal_anatomy_missing"
			return invalid
		var start_world: Vector3 = skeleton.to_global(
			skeleton.get_bone_global_pose(start_index).origin
		)
		var end_world: Vector3 = skeleton.to_global(
			skeleton.get_bone_global_pose(end_index).origin
		)
		if (
			not start_world.is_finite()
			or not end_world.is_finite()
			or start_world.distance_squared_to(end_world) <= 0.000001
		):
			invalid["status"] = &"hand_surface_seat_proximal_anatomy_degenerate"
			return invalid
		if digit_id == &"index" or digit_id == &"pinky":
			var hinge_axis_local: Vector3 = proximal_rule.get(
				"hinge_axis_local",
				Vector3.ZERO
			) as Vector3
			var hinge_axis_origin_id: StringName = proximal_rule.get(
				"hinge_axis_origin_id",
				StringName()
			) as StringName
			var bone_root_origin_id: StringName = proximal_rule.get(
				"bone_root_origin_id",
				StringName()
			) as StringName
			var motion_direction_sign: float = float(proximal_rule.get(
				"motion_direction_sign",
				0.0
			))
			if (
				not hinge_axis_local.is_finite()
				or hinge_axis_local.length_squared() <= 0.000001
				or hinge_axis_origin_id != start_bone
				or bone_root_origin_id != CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
				or not PlayerDigitHingeRulesScript.rule_has_valid_origin_chain(
					proximal_rule,
					skeleton
				)
				or not is_finite(motion_direction_sign)
				or is_zero_approx(motion_direction_sign)
			):
				invalid["status"] = &"hand_surface_seat_closing_authority_missing"
				return invalid
			var start_world_basis: Basis = (
				skeleton.global_basis
				* skeleton.get_bone_global_pose(start_index).basis
			).orthonormalized()
			var signed_hinge_axis_world: Vector3 = (
				start_world_basis * hinge_axis_local.normalized()
			) * signf(motion_direction_sign)
			var authorized_closing_direction_world: Vector3 = (
				signed_hinge_axis_world.cross(end_world - start_world)
			)
			if (
				not authorized_closing_direction_world.is_finite()
				or authorized_closing_direction_world.length_squared() <= 0.000001
			):
				invalid["status"] = &"hand_surface_seat_closing_authority_degenerate"
				return invalid
			authorized_closing_directions[digit_id] = (
				authorized_closing_direction_world.normalized()
			)
		ordinary_proximal_capsules.append({
			"digit_id": digit_id,
			"section_index": 0,
			"segment_start_world": start_world,
			"segment_start_world_origin_id": CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
			"segment_start_source_origin_id": start_bone,
			"segment_end_world": end_world,
			"segment_end_world_origin_id": CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
			"segment_end_source_origin_id": end_bone,
			"radius_meters": radius_meters,
			"radius_source_id": PlayerDigitHingeRulesScript.get_revision(),
		})
	if (
		not authorized_closing_directions.has(&"index")
		or not authorized_closing_directions.has(&"pinky")
	):
		invalid["status"] = &"hand_surface_seat_closing_authority_missing"
		return invalid
	return {
		"valid": true,
		"status": &"hand_surface_seat_anatomy_ready",
		"slot_id": slot_id,
		"index_bone": index_bone,
		"pinky_bone": pinky_bone,
		"index_point_world": index_world,
		"index_point_world_origin_id": CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
		"index_point_source_origin_id": index_bone,
		"pinky_point_world": pinky_world,
		"pinky_point_world_origin_id": CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
		"pinky_point_source_origin_id": pinky_bone,
		"index_authorized_closing_direction_world": (
			authorized_closing_directions.get(&"index", Vector3.ZERO) as Vector3
		),
		"index_authorized_closing_direction_world_origin_id": (
			CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
		),
		"index_authorized_closing_direction_source_origin_id": index_bone,
		"index_authorized_closing_direction_segment_end_source_origin_id": (
			PlayerDigitHingeRulesScript.get_chain_rules(slot_id, &"index")[0].get(
				"next_bone",
				StringName()
			)
		),
		"index_authorized_closing_direction_rule_revision": (
			PlayerDigitHingeRulesScript.get_revision()
		),
		"pinky_authorized_closing_direction_world": (
			authorized_closing_directions.get(&"pinky", Vector3.ZERO) as Vector3
		),
		"pinky_authorized_closing_direction_world_origin_id": (
			CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
		),
		"pinky_authorized_closing_direction_source_origin_id": pinky_bone,
		"pinky_authorized_closing_direction_segment_end_source_origin_id": (
			PlayerDigitHingeRulesScript.get_chain_rules(slot_id, &"pinky")[0].get(
				"next_bone",
				StringName()
			)
		),
		"pinky_authorized_closing_direction_rule_revision": (
			PlayerDigitHingeRulesScript.get_revision()
		),
		"index_skin_to_bone_radius_meters": index_skin_radius_meters,
		"index_skin_to_bone_radius_source_id": PlayerDigitHingeRulesScript.get_revision(),
		"pinky_skin_to_bone_radius_meters": pinky_skin_radius_meters,
		"pinky_skin_to_bone_radius_source_id": PlayerDigitHingeRulesScript.get_revision(),
		"skin_radius_calibration_revision": PlayerDigitHingeRulesScript.get_revision(),
		"ordinary_proximal_capsules": ordinary_proximal_capsules,
		"ordinary_proximal_capsules_origin_id": CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
	}

func _resolve_hand_index_pinky_contact_center_world(slot_id: StringName) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var index_bone: StringName = RIGHT_INDEX1_BONE
	var pinky_bone: StringName = RIGHT_PINKY1_BONE
	if slot_id == &"hand_left":
		index_bone = LEFT_INDEX1_BONE
		pinky_bone = LEFT_PINKY1_BONE
	var index_index: int = skeleton.find_bone(String(index_bone))
	var pinky_index: int = skeleton.find_bone(String(pinky_bone))
	if index_index < 0 or pinky_index < 0:
		return Vector3.ZERO
	var index_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(index_index).origin)
	var pinky_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(pinky_index).origin)
	if index_world.distance_squared_to(pinky_world) <= 0.000001:
		return Vector3.ZERO
	return index_world.lerp(pinky_world, 0.5)

func _resolve_anatomically_seated_hand_grip_center_world(
	slot_id: StringName,
	contact_center_world: Vector3
) -> Vector3:
	var anatomical_center_world: Vector3 = finger_grip_presenter.resolve_hand_grip_alignment_world_position(skeleton, slot_id)
	if anatomical_center_world.length_squared() <= 0.000001:
		return contact_center_world
	var anatomical_offset_world: Vector3 = anatomical_center_world - contact_center_world
	var contact_axis_world: Vector3 = _resolve_hand_index_pinky_contact_axis_world(slot_id)
	if contact_axis_world.length_squared() > 0.000001:
		anatomical_offset_world -= contact_axis_world * anatomical_offset_world.dot(contact_axis_world)
	var max_offset_meters: float = _resolve_hand_index_pinky_contact_span_meters(slot_id) * 0.75
	var offset_length: float = anatomical_offset_world.length()
	if max_offset_meters > 0.0 and offset_length > max_offset_meters:
		anatomical_offset_world = anatomical_offset_world.normalized() * max_offset_meters
	if anatomical_offset_world.length_squared() <= 0.000001:
		return contact_center_world
	return contact_center_world + anatomical_offset_world

func _resolve_hand_index_pinky_contact_axis_world(slot_id: StringName) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var index_bone: StringName = RIGHT_INDEX1_BONE
	var pinky_bone: StringName = RIGHT_PINKY1_BONE
	if slot_id == &"hand_left":
		index_bone = LEFT_INDEX1_BONE
		pinky_bone = LEFT_PINKY1_BONE
	var index_index: int = skeleton.find_bone(String(index_bone))
	var pinky_index: int = skeleton.find_bone(String(pinky_bone))
	if index_index < 0 or pinky_index < 0:
		return Vector3.ZERO
	var index_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(index_index).origin)
	var pinky_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(pinky_index).origin)
	var index_to_pinky_world: Vector3 = index_world - pinky_world
	if index_to_pinky_world.length_squared() <= 0.000001:
		return Vector3.ZERO
	return index_to_pinky_world.normalized()

func _resolve_hand_index_pinky_contact_span_meters(slot_id: StringName) -> float:
	if skeleton == null:
		return 0.0
	var index_bone: StringName = RIGHT_INDEX1_BONE
	var pinky_bone: StringName = RIGHT_PINKY1_BONE
	if slot_id == &"hand_left":
		index_bone = LEFT_INDEX1_BONE
		pinky_bone = LEFT_PINKY1_BONE
	var index_index: int = skeleton.find_bone(String(index_bone))
	var pinky_index: int = skeleton.find_bone(String(pinky_bone))
	if index_index < 0 or pinky_index < 0:
		return 0.0
	var index_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(index_index).origin)
	var pinky_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(pinky_index).origin)
	return index_world.distance_to(pinky_world)

func get_weapon_stow_anchor(stow_mode: StringName, slot_id: StringName) -> Node3D:
	return rig_model_presenter.get_weapon_stow_anchor(self, stow_mode, slot_id)

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
	if authoring_preview_mode_enabled:
		return
	var target_animation_name: StringName = locomotion_presenter.resolve_locomotion_animation_name(
		horizontal_speed,
		target_horizontal_speed,
		grounded,
		vertical_velocity,
		sprinting,
		_get_locomotion_config(_should_use_two_hand_idle_animation())
	)
	_play_runtime_locomotion_animation(target_animation_name)

func set_support_hand_active(slot_id: StringName, active: bool) -> void:
	guidance_state_presenter.set_support_hand_active(slot_id, active)
	_refresh_support_arm_ik_influences()

func set_dominant_grip_slot(slot_id: StringName) -> void:
	if slot_id == &"hand_left":
		dominant_grip_slot_id = &"hand_left"
		return
	dominant_grip_slot_id = &"hand_right"

func clear_dominant_grip_slot() -> void:
	dominant_grip_slot_id = StringName()

func is_two_hand_idle_animation_active() -> bool:
	return _should_use_two_hand_idle_animation() and get_current_animation_name() == two_hand_idle_animation_name

func sync_runtime_body_restriction_root_now() -> bool:
	if skeleton == null:
		return false
	if body_restriction_root == null or not is_instance_valid(body_restriction_root):
		body_restriction_root = hand_target_constraint_solver.call(
			"ensure_body_restriction_root",
			self,
			skeleton,
			mesh_instance,
			body_clearance_proxy_offset_meters
		) as Node3D
	if body_restriction_root == null or not is_instance_valid(body_restriction_root):
		return false
	hand_target_constraint_solver.call("sync_body_restriction_root", body_restriction_root, skeleton)
	_set_body_restriction_debug_meshes_visible(runtime_debug_visuals_visible)
	return true

func process_runtime_body_restriction_sync_modifier_frame(_delta: float = 1.0 / 60.0) -> void:
	sync_runtime_body_restriction_root_now()

func get_body_restriction_root() -> Node3D:
	return body_restriction_root

func _is_runtime_debug_visual_toggle_event(event: InputEvent) -> bool:
	if InputMap.has_action(&"runtime_debug_visuals"):
		return event.is_action_pressed(&"runtime_debug_visuals")
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	return key_event.physical_keycode == KEY_F9 or key_event.keycode == KEY_F9

func _has_runtime_debug_visual_controller() -> bool:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("_apply_runtime_debug_visual_visibility"):
			return true
		current = current.get_parent()
	return false

func _set_body_restriction_debug_meshes_visible(debug_visible: bool) -> void:
	if body_restriction_root == null or not is_instance_valid(body_restriction_root):
		return
	for attachment_node: Node in body_restriction_root.get_children():
		var attachment: Node3D = attachment_node as Node3D
		if attachment == null:
			continue
		var debug_mesh: MeshInstance3D = attachment.get_node_or_null("RestrictionDebug") as MeshInstance3D
		if debug_mesh != null:
			debug_mesh.visible = debug_visible

func get_body_clearance_debug_state() -> Dictionary:
	var attachment_count: int = 0
	var regions: PackedStringArray = []
	if body_restriction_root != null and is_instance_valid(body_restriction_root):
		attachment_count = body_restriction_root.get_child_count()
		for attachment_node: Node in body_restriction_root.get_children():
			var attachment: Node3D = attachment_node as Node3D
			if attachment == null:
				continue
			var region_name: String = String(attachment.get_meta("proxy_region", ""))
			if not region_name.is_empty():
				regions.append(region_name)
	return {
		"body_clearance_root_exists": body_restriction_root != null and is_instance_valid(body_restriction_root),
		"body_clearance_proxy_source": body_restriction_root.get_meta("proxy_source", StringName()) if body_restriction_root != null else StringName(),
		"body_clearance_offset_meters": float(body_restriction_root.get_meta("clearance_offset_meters", 0.0)) if body_restriction_root != null else 0.0,
		"body_clearance_descriptor_count": int(body_restriction_root.get_meta("proxy_descriptor_count", 0)) if body_restriction_root != null else 0,
		"body_clearance_attachment_count": attachment_count,
		"body_clearance_regions": regions,
		"body_clearance_source_mesh_aabb_size": body_restriction_root.get_meta("source_mesh_aabb_size", Vector3.ZERO) if body_restriction_root != null else Vector3.ZERO,
	}

func get_body_self_collision_debug_state() -> Dictionary:
	if body_restriction_root == null or not is_instance_valid(body_restriction_root):
		return {
			"legal": true,
			"checked_pair_count": 0,
			"overlap_pair_count": 0,
			"allowed_overlap_pair_count": 0,
			"illegal_pair_count": 0,
		}
	sync_runtime_body_restriction_root_now()
	return hand_target_constraint_solver.call("evaluate_body_self_collision", body_restriction_root) as Dictionary

func get_grip_solve_root() -> Node3D:
	return grip_solve_root

func set_arm_guidance_target(slot_id: StringName, target_node: Node3D) -> void:
	guidance_state_presenter.set_arm_guidance_target(slot_id, target_node)
	_refresh_support_arm_ik_influences()

func clear_arm_guidance_target(slot_id: StringName) -> void:
	guidance_state_presenter.clear_arm_guidance_target(slot_id)
	guidance_state_presenter.clear_arm_guidance_active(slot_id)
	_refresh_support_arm_ik_influences()

func set_arm_guidance_active(slot_id: StringName, active: bool) -> void:
	guidance_state_presenter.set_arm_guidance_active(slot_id, active)
	_refresh_support_arm_ik_influences()

func clear_arm_guidance_active(slot_id: StringName) -> void:
	guidance_state_presenter.clear_arm_guidance_active(slot_id)
	_refresh_support_arm_ik_influences()

func set_finger_grip_target(slot_id: StringName, guide_node: Node3D) -> void:
	if slot_id != &"hand_right" and slot_id != &"hand_left":
		return
	finger_grip_source_lookup[slot_id] = guide_node
	if finger_grip_presenter.has_method("note_grip_source_assigned"):
		finger_grip_presenter.call("note_grip_source_assigned", slot_id, guide_node)
	_refresh_finger_grip_ik_influences()

func clear_finger_grip_target(slot_id: StringName) -> void:
	if slot_id != &"hand_right" and slot_id != &"hand_left":
		return
	finger_grip_source_lookup.erase(slot_id)
	if finger_grip_presenter.has_method("note_grip_source_cleared"):
		finger_grip_presenter.call("note_grip_source_cleared", slot_id)
	_refresh_finger_grip_ik_influences()

func set_authoring_contact_anchor_basis(slot_id: StringName, anchor_basis_world: Basis) -> void:
	if slot_id != &"hand_right" and slot_id != &"hand_left":
		return
	authoring_contact_anchor_basis_lookup[slot_id] = anchor_basis_world.orthonormalized()

func clear_authoring_contact_anchor_basis(slot_id: StringName) -> void:
	if slot_id != &"hand_right" and slot_id != &"hand_left":
		return
	authoring_contact_anchor_basis_lookup.erase(slot_id)

func clear_authoring_contact_anchor_bases() -> void:
	authoring_contact_anchor_basis_lookup.clear()

func set_upper_body_authoring_state(state: Dictionary) -> void:
	upper_body_authoring_state = state.duplicate(true)
	_refresh_combat_authoring_modifier_state()

func clear_upper_body_authoring_state() -> void:
	upper_body_authoring_state = {}
	_refresh_combat_authoring_modifier_state()

func get_upper_body_authoring_state() -> Dictionary:
	return upper_body_authoring_state.duplicate(true)

func get_runtime_upper_body_pose_bone_names() -> Array[StringName]:
	return RUNTIME_UPPER_BODY_POSE_BONES.duplicate()

func capture_runtime_upper_body_pose_frame(bone_names: Array = []) -> Dictionary:
	var result := {
		"bone_names": [],
		"pose_positions": PackedVector3Array(),
		"pose_rotations": PackedVector4Array(),
		"pose_scales": PackedVector3Array(),
	}
	if skeleton == null:
		return result
	var resolved_bone_names: Array = bone_names if not bone_names.is_empty() else RUNTIME_UPPER_BODY_POSE_BONES
	var captured_names: Array[StringName] = []
	var captured_positions := PackedVector3Array()
	var captured_rotations := PackedVector4Array()
	var captured_scales := PackedVector3Array()
	for bone_name_variant: Variant in resolved_bone_names:
		var bone_name: StringName = StringName(bone_name_variant)
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		var pose_position: Vector3 = skeleton.get_bone_pose_position(bone_index)
		var pose_rotation: Quaternion = skeleton.get_bone_pose_rotation(bone_index).normalized()
		var pose_scale: Vector3 = skeleton.get_bone_pose_scale(bone_index)
		captured_names.append(bone_name)
		captured_positions.append(pose_position)
		captured_rotations.append(Vector4(pose_rotation.x, pose_rotation.y, pose_rotation.z, pose_rotation.w))
		captured_scales.append(pose_scale)
	result["bone_names"] = captured_names
	result["pose_positions"] = captured_positions
	result["pose_rotations"] = captured_rotations
	result["pose_scales"] = captured_scales
	return result

func capture_runtime_solved_replay_weapon_frame(
	held_item: Node3D,
	reference_bone_name: StringName = RUNTIME_SOLVED_REPLAY_REFERENCE_BONE,
	anchor_node_paths: Array = []
) -> Dictionary:
	var result := {
		"valid": false,
		"reference_bone_name": reference_bone_name if reference_bone_name != StringName() else RUNTIME_SOLVED_REPLAY_REFERENCE_BONE,
		"reference_origin_id": CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE,
		"weapon_position_reference_local": Vector3.ZERO,
		"weapon_rotation_reference_local": Quaternion.IDENTITY,
		"weapon_scale_reference_local": Vector3.ONE,
		"weapon_reference_origin_id": CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE,
		"anchor_node_paths": [],
		"anchor_positions_weapon_local": PackedVector3Array(),
		"anchor_rotations_weapon_local": PackedVector4Array(),
		"anchor_scales_weapon_local": PackedVector3Array(),
		"anchor_origin_id": CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
	}
	if held_item == null or not is_instance_valid(held_item):
		return result
	var reference_transform: Transform3D = _resolve_runtime_solved_replay_reference_transform(
		result["reference_bone_name"] as StringName
	)
	var weapon_reference_transform: Transform3D = reference_transform.affine_inverse() * held_item.global_transform
	var weapon_rotation: Quaternion = weapon_reference_transform.basis.get_rotation_quaternion().normalized()
	var weapon_scale: Vector3 = weapon_reference_transform.basis.get_scale()
	if (
		not _is_finite_vector3(weapon_reference_transform.origin)
		or not _is_finite_quaternion(weapon_rotation)
		or not _is_finite_vector3(weapon_scale)
	):
		return result
	var resolved_anchor_paths: Array = anchor_node_paths.duplicate()
	var captured_anchor_paths: Array[StringName] = []
	var captured_anchor_positions := PackedVector3Array()
	var captured_anchor_rotations := PackedVector4Array()
	var captured_anchor_scales := PackedVector3Array()
	var weapon_inverse: Transform3D = held_item.global_transform.affine_inverse()
	for anchor_path_variant: Variant in resolved_anchor_paths:
		var anchor_path := NodePath(String(anchor_path_variant))
		var anchor_node: Node3D = held_item.get_node_or_null(anchor_path) as Node3D
		if anchor_node == null or not is_instance_valid(anchor_node):
			return result
		var anchor_weapon_transform: Transform3D = weapon_inverse * anchor_node.global_transform
		var anchor_rotation: Quaternion = anchor_weapon_transform.basis.get_rotation_quaternion().normalized()
		var anchor_scale: Vector3 = anchor_weapon_transform.basis.get_scale()
		if (
			not _is_finite_vector3(anchor_weapon_transform.origin)
			or not _is_finite_quaternion(anchor_rotation)
			or not _is_finite_vector3(anchor_scale)
		):
			return result
		captured_anchor_paths.append(StringName(String(anchor_path_variant)))
		captured_anchor_positions.append(anchor_weapon_transform.origin)
		captured_anchor_rotations.append(Vector4(anchor_rotation.x, anchor_rotation.y, anchor_rotation.z, anchor_rotation.w))
		captured_anchor_scales.append(anchor_scale)
	result["valid"] = true
	result["weapon_position_reference_local"] = weapon_reference_transform.origin
	result["weapon_rotation_reference_local"] = weapon_rotation
	result["weapon_scale_reference_local"] = weapon_scale
	result["anchor_node_paths"] = captured_anchor_paths
	result["anchor_positions_weapon_local"] = captured_anchor_positions
	result["anchor_rotations_weapon_local"] = captured_anchor_rotations
	result["anchor_scales_weapon_local"] = captured_anchor_scales
	return result

func apply_runtime_solved_upper_body_pose_frame(
	bone_names: Array,
	bone_pose_positions: Array,
	bone_pose_rotations: Array,
	bone_pose_scales: Array,
	strength: float = 1.0
) -> bool:
	if skeleton == null:
		return false
	if bone_names.is_empty() or bone_pose_positions.is_empty() or bone_pose_rotations.is_empty() or bone_pose_scales.is_empty():
		return false
	var clean_strength: float = clampf(strength, 0.0, 1.0)
	if clean_strength <= 0.00001:
		return false
	var count: int = mini(bone_names.size(), mini(bone_pose_positions.size(), mini(bone_pose_rotations.size(), bone_pose_scales.size())))
	if count <= 0:
		return false
	var stored_bone_names: Array[StringName] = []
	var stored_positions: Array = []
	var stored_rotations: Array = []
	var stored_scales: Array = []
	for pose_index: int in range(count):
		stored_bone_names.append(StringName(bone_names[pose_index]))
		stored_positions.append(bone_pose_positions[pose_index])
		stored_rotations.append(bone_pose_rotations[pose_index])
		stored_scales.append(bone_pose_scales[pose_index])
	runtime_solved_replay_pose_state = {
		"active": true,
		"bone_names": stored_bone_names,
		"pose_positions": stored_positions,
		"pose_rotations": stored_rotations,
		"pose_scales": stored_scales,
		"strength": clean_strength,
	}
	_refresh_runtime_solved_replay_modifier_state()
	return _apply_runtime_solved_upper_body_pose_state(runtime_solved_replay_pose_state)

func clear_runtime_solved_replay_pose_frame() -> void:
	runtime_solved_replay_pose_state = {}
	runtime_solved_replay_weapon_state = {}
	_refresh_runtime_solved_replay_modifier_state()

func process_runtime_solved_replay_modifier_frame(_delta: float = 1.0 / 60.0) -> void:
	if runtime_solved_replay_modifier_processing:
		return
	if skeleton == null or (runtime_solved_replay_pose_state.is_empty() and runtime_solved_replay_weapon_state.is_empty()):
		return
	runtime_solved_replay_modifier_processing = true
	_apply_runtime_solved_upper_body_pose_state(runtime_solved_replay_pose_state)
	_apply_runtime_solved_replay_weapon_state(runtime_solved_replay_weapon_state)
	runtime_solved_replay_modifier_processing = false

func sync_runtime_endpoint_authority_root_to_reference(reference_bone_name: StringName = RUNTIME_SOLVED_REPLAY_REFERENCE_BONE) -> bool:
	var authority_root: Node3D = _resolve_runtime_endpoint_authority_root()
	if authority_root == null:
		return false
	var resolved_reference_bone_name: StringName = reference_bone_name if reference_bone_name != StringName() else RUNTIME_SOLVED_REPLAY_REFERENCE_BONE
	var reference_transform: Transform3D = _resolve_runtime_solved_replay_reference_transform(resolved_reference_bone_name)
	authority_root.global_transform = reference_transform
	authority_root.set_meta("runtime_endpoint_authority_origin_id", CombatOriginRecordScript.ORIGIN_RUNTIME_ENDPOINT_AUTHORITY_ROOT)
	authority_root.set_meta("runtime_endpoint_authority_reference_bone_name", resolved_reference_bone_name)
	authority_root.set_meta("runtime_endpoint_authority_reference_origin_id", CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE)
	return true

func set_runtime_solved_replay_weapon_frame(
	held_item: Node3D,
	reference_bone_name: StringName,
	weapon_position_reference_local: Vector3,
	weapon_rotation_reference_local: Quaternion,
	weapon_scale_reference_local: Vector3,
	anchor_node_paths: Array,
	anchor_positions_weapon_local: Array,
	anchor_rotations_weapon_local: Array,
	anchor_scales_weapon_local: Array,
	bridge_anchor_lock_slot_id: StringName = StringName(),
	reference_origin_id: StringName = CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE,
	weapon_reference_origin_id: StringName = CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE,
	anchor_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
) -> bool:
	if held_item == null or not is_instance_valid(held_item):
		return false
	if not _is_finite_vector3(weapon_position_reference_local):
		return false
	if not _is_finite_quaternion(weapon_rotation_reference_local):
		return false
	if not _is_finite_vector3(weapon_scale_reference_local):
		return false
	runtime_solved_replay_weapon_state = {
		"active": true,
		"held_item": held_item,
		"reference_bone_name": reference_bone_name if reference_bone_name != StringName() else RUNTIME_SOLVED_REPLAY_REFERENCE_BONE,
		"reference_origin_id": reference_origin_id if reference_origin_id != StringName() else CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE,
		"weapon_position_reference_local": weapon_position_reference_local,
		"weapon_rotation_reference_local": weapon_rotation_reference_local.normalized(),
		"weapon_scale_reference_local": weapon_scale_reference_local,
		"weapon_reference_origin_id": weapon_reference_origin_id if weapon_reference_origin_id != StringName() else CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE,
		"anchor_node_paths": anchor_node_paths.duplicate(),
		"anchor_positions_weapon_local": anchor_positions_weapon_local.duplicate(),
		"anchor_rotations_weapon_local": anchor_rotations_weapon_local.duplicate(),
		"anchor_scales_weapon_local": anchor_scales_weapon_local.duplicate(),
		"anchor_origin_id": anchor_origin_id if anchor_origin_id != StringName() else CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
		"bridge_anchor_lock_slot_id": bridge_anchor_lock_slot_id,
	}
	_refresh_runtime_solved_replay_modifier_state()
	return _apply_runtime_solved_replay_weapon_state(runtime_solved_replay_weapon_state)

func _apply_runtime_solved_upper_body_pose_state(pose_state: Dictionary) -> bool:
	if pose_state.is_empty() or not bool(pose_state.get("active", false)):
		return false
	return _apply_runtime_solved_upper_body_pose_values(
		pose_state.get("bone_names", []) as Array,
		pose_state.get("pose_positions", []) as Array,
		pose_state.get("pose_rotations", []) as Array,
		pose_state.get("pose_scales", []) as Array,
		float(pose_state.get("strength", 1.0))
	)

func _apply_runtime_solved_replay_weapon_state(weapon_state: Dictionary) -> bool:
	if weapon_state.is_empty() or not bool(weapon_state.get("active", false)):
		return false
	var held_item: Node3D = weapon_state.get("held_item", null) as Node3D
	if held_item == null or not is_instance_valid(held_item):
		return false
	var reference_bone_name: StringName = weapon_state.get("reference_bone_name", RUNTIME_SOLVED_REPLAY_REFERENCE_BONE) as StringName
	if reference_bone_name == StringName():
		reference_bone_name = RUNTIME_SOLVED_REPLAY_REFERENCE_BONE
	var reference_transform: Transform3D = _resolve_runtime_solved_replay_reference_transform(reference_bone_name)
	var weapon_reference_transform: Transform3D = _build_runtime_solved_replay_transform(
		weapon_state.get("weapon_position_reference_local", Vector3.ZERO) as Vector3,
		weapon_state.get("weapon_rotation_reference_local", Quaternion.IDENTITY) as Quaternion,
		weapon_state.get("weapon_scale_reference_local", Vector3.ONE) as Vector3
	)
	var authority_root: Node3D = _resolve_runtime_endpoint_authority_root()
	if authority_root != null and held_item.get_parent() == authority_root:
		authority_root.global_transform = reference_transform
		held_item.transform = weapon_reference_transform
	else:
		held_item.global_transform = reference_transform * weapon_reference_transform
	_apply_runtime_solved_replay_bridge_anchor_lock(
		held_item,
		weapon_state.get("bridge_anchor_lock_slot_id", StringName()) as StringName,
		weapon_state.get("anchor_node_paths", []) as Array,
		weapon_state.get("anchor_positions_weapon_local", []) as Array
	)
	_apply_runtime_solved_replay_anchor_state(
		held_item,
		weapon_state.get("anchor_node_paths", []) as Array,
		weapon_state.get("anchor_positions_weapon_local", []) as Array,
		weapon_state.get("anchor_rotations_weapon_local", []) as Array,
		weapon_state.get("anchor_scales_weapon_local", []) as Array
	)
	return true

func _apply_runtime_solved_replay_bridge_anchor_lock(
	held_item: Node3D,
	slot_id: StringName,
	anchor_node_paths: Array,
	anchor_positions_weapon_local: Array
) -> void:
	if slot_id == StringName() or held_item == null or not is_instance_valid(held_item):
		return
	if not has_method("resolve_hand_grip_alignment_world_position"):
		return
	var target_variant: Variant = call("resolve_hand_grip_alignment_world_position", slot_id)
	if not (target_variant is Vector3):
		return
	var target_world: Vector3 = target_variant as Vector3
	if target_world.length_squared() <= 0.000001 or not _is_finite_vector3(target_world):
		return
	var primary_anchor_index: int = -1
	for anchor_index: int in range(anchor_node_paths.size()):
		if String(anchor_node_paths[anchor_index]) == "PrimaryGripAnchor":
			primary_anchor_index = anchor_index
			break
	if primary_anchor_index < 0 or primary_anchor_index >= anchor_positions_weapon_local.size():
		return
	var primary_anchor_weapon_local: Vector3 = _resolve_runtime_pose_vector3(
		anchor_positions_weapon_local[primary_anchor_index],
		Vector3.ZERO
	)
	var current_anchor_world: Vector3 = held_item.global_transform * primary_anchor_weapon_local
	var correction_delta: Vector3 = target_world - current_anchor_world
	if not _is_finite_vector3(correction_delta):
		return
	held_item.global_position += correction_delta

func _resolve_runtime_solved_replay_reference_transform(reference_bone_name: StringName) -> Transform3D:
	if skeleton != null and reference_bone_name != StringName():
		var bone_index: int = skeleton.find_bone(String(reference_bone_name))
		if bone_index >= 0:
			var bone_pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
			var world_pose: Transform3D = skeleton.global_transform * bone_pose
			return Transform3D(world_pose.basis.orthonormalized(), world_pose.origin)
	return Transform3D(global_basis.orthonormalized(), global_position)

func _resolve_runtime_endpoint_authority_root() -> Node3D:
	return get_node_or_null(RUNTIME_ENDPOINT_AUTHORITY_ROOT_NAME) as Node3D

func _build_runtime_solved_replay_transform(
	replay_position: Vector3,
	replay_rotation: Quaternion,
	replay_scale: Vector3
) -> Transform3D:
	var replay_basis := Basis(replay_rotation.normalized())
	replay_basis = replay_basis.scaled(replay_scale)
	return Transform3D(replay_basis, replay_position)

func _apply_runtime_solved_replay_anchor_state(
	held_item: Node3D,
	anchor_node_paths: Array,
	anchor_positions_weapon_local: Array,
	anchor_rotations_weapon_local: Array,
	anchor_scales_weapon_local: Array
) -> void:
	if held_item == null or not is_instance_valid(held_item):
		return
	var count: int = mini(anchor_node_paths.size(), mini(anchor_positions_weapon_local.size(), mini(anchor_rotations_weapon_local.size(), anchor_scales_weapon_local.size())))
	for anchor_index: int in range(count):
		var anchor_node: Node3D = held_item.get_node_or_null(NodePath(String(anchor_node_paths[anchor_index]))) as Node3D
		if anchor_node == null or not is_instance_valid(anchor_node):
			continue
		var anchor_weapon_transform: Transform3D = _build_runtime_solved_replay_transform(
			anchor_positions_weapon_local[anchor_index] as Vector3,
			_resolve_runtime_pose_rotation(anchor_rotations_weapon_local[anchor_index]),
			anchor_scales_weapon_local[anchor_index] as Vector3
		)
		anchor_node.global_transform = held_item.global_transform * anchor_weapon_transform

func _apply_runtime_solved_upper_body_pose_values(
	bone_names: Array,
	bone_pose_positions: Array,
	bone_pose_rotations: Array,
	bone_pose_scales: Array,
	strength: float = 1.0
) -> bool:
	if skeleton == null:
		return false
	if bone_names.is_empty() or bone_pose_positions.is_empty() or bone_pose_rotations.is_empty() or bone_pose_scales.is_empty():
		return false
	var clean_strength: float = clampf(strength, 0.0, 1.0)
	if clean_strength <= 0.00001:
		return false
	var applied: bool = false
	var count: int = mini(bone_names.size(), mini(bone_pose_positions.size(), mini(bone_pose_rotations.size(), bone_pose_scales.size())))
	for pose_index: int in range(count):
		var bone_name: StringName = StringName(bone_names[pose_index])
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		var target_position: Vector3 = _resolve_runtime_pose_vector3(bone_pose_positions[pose_index], skeleton.get_bone_pose_position(bone_index))
		var target_rotation: Quaternion = _resolve_runtime_pose_rotation(bone_pose_rotations[pose_index]).normalized()
		var target_scale: Vector3 = _resolve_runtime_pose_vector3(bone_pose_scales[pose_index], skeleton.get_bone_pose_scale(bone_index))
		if not _is_finite_vector3(target_position) or not _is_finite_quaternion(target_rotation) or not _is_finite_vector3(target_scale):
			continue
		if clean_strength < 0.99999:
			target_position = skeleton.get_bone_pose_position(bone_index).lerp(target_position, clean_strength)
			target_rotation = skeleton.get_bone_pose_rotation(bone_index).normalized().slerp(target_rotation, clean_strength).normalized()
			target_scale = skeleton.get_bone_pose_scale(bone_index).lerp(target_scale, clean_strength)
		skeleton.set_bone_pose_position(bone_index, target_position)
		skeleton.set_bone_pose_rotation(bone_index, target_rotation)
		skeleton.set_bone_pose_scale(bone_index, target_scale)
		applied = true
	if applied:
		skeleton.force_update_all_bone_transforms()
	return applied

func apply_runtime_upper_body_pose_frame(
	bone_names: Array,
	bone_pose_rotations: Array,
	strength: float = 1.0
) -> bool:
	if skeleton == null:
		return false
	if bone_names.is_empty() or bone_pose_rotations.is_empty():
		return false
	var clean_strength: float = clampf(strength, 0.0, 1.0)
	if clean_strength <= 0.00001:
		return false
	var applied: bool = false
	var count: int = mini(bone_names.size(), bone_pose_rotations.size())
	for pose_index: int in range(count):
		var bone_name: StringName = StringName(bone_names[pose_index])
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		var target_rotation: Quaternion = _resolve_runtime_pose_rotation(bone_pose_rotations[pose_index])
		if not _is_finite_quaternion(target_rotation):
			continue
		var current_rotation: Quaternion = skeleton.get_bone_pose_rotation(bone_index).normalized()
		var resolved_rotation: Quaternion = current_rotation.slerp(target_rotation.normalized(), clean_strength).normalized()
		skeleton.set_bone_pose_rotation(bone_index, resolved_rotation)
		applied = true
	if applied:
		skeleton.force_update_all_bone_transforms()
	return applied

func _resolve_runtime_pose_rotation(rotation_data: Variant) -> Quaternion:
	if rotation_data is Quaternion:
		return rotation_data as Quaternion
	if rotation_data is Vector4:
		var vector_rotation: Vector4 = rotation_data as Vector4
		return Quaternion(vector_rotation.x, vector_rotation.y, vector_rotation.z, vector_rotation.w)
	return Quaternion.IDENTITY

func _resolve_runtime_pose_vector3(vector_data: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if vector_data is Vector3:
		return vector_data as Vector3
	return fallback

func _is_finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x)
		and not is_nan(value.y)
		and not is_nan(value.z)
		and not is_inf(value.x)
		and not is_inf(value.y)
		and not is_inf(value.z)
	)

func _is_finite_quaternion(value: Quaternion) -> bool:
	return (
		not is_nan(value.x)
		and not is_nan(value.y)
		and not is_nan(value.z)
		and not is_nan(value.w)
		and not is_inf(value.x)
		and not is_inf(value.y)
		and not is_inf(value.z)
		and not is_inf(value.w)
		and (value.x * value.x + value.y * value.y + value.z * value.z + value.w * value.w) > 0.000001
	)

func get_grip_contact_debug_state() -> Dictionary:
	return {
		"right_arm_ik_active": right_arm_ik_modifier != null and right_arm_ik_modifier.active,
		"left_arm_ik_active": left_arm_ik_modifier != null and left_arm_ik_modifier.active,
		"right_arm_ik_influence": right_arm_ik_modifier.influence if right_arm_ik_modifier != null else 0.0,
		"left_arm_ik_influence": left_arm_ik_modifier.influence if left_arm_ik_modifier != null else 0.0,
		"right_arm_guidance_active": is_arm_guidance_active(&"hand_right"),
		"left_arm_guidance_active": is_arm_guidance_active(&"hand_left"),
		"right_authoring_contact_basis_active": authoring_contact_anchor_basis_lookup.has(&"hand_right"),
		"left_authoring_contact_basis_active": authoring_contact_anchor_basis_lookup.has(&"hand_left"),
		"upper_body_authoring_auto_apply_enabled": upper_body_authoring_auto_apply_enabled,
		"direct_authoring_solver_mode": _uses_direct_authoring_solver_mode(),
		"combat_authoring_modifier_active": combat_authoring_modifier != null and combat_authoring_modifier.active,
		"authoring_limb_twist_distribution_enabled": enable_authoring_limb_twist_distribution,
		"right_forearm_twist_bone_count": _count_existing_bones(RIGHT_FOREARM_TWIST_BONES),
		"left_forearm_twist_bone_count": _count_existing_bones(LEFT_FOREARM_TWIST_BONES),
		"right_upperarm_twist_bone_count": _count_existing_bones(RIGHT_UPPERARM_TWIST_BONES),
		"left_upperarm_twist_bone_count": _count_existing_bones(LEFT_UPPERARM_TWIST_BONES),
		"right_authoring_twist_distribution_active": bool((authoring_limb_twist_distribution_state.get(&"hand_right", {}) as Dictionary).get("active", false)),
		"left_authoring_twist_distribution_active": bool((authoring_limb_twist_distribution_state.get(&"hand_left", {}) as Dictionary).get("active", false)),
		"right_authoring_twist_requested_degrees": float((authoring_limb_twist_distribution_state.get(&"hand_right", {}) as Dictionary).get("requested_degrees", 0.0)),
		"left_authoring_twist_requested_degrees": float((authoring_limb_twist_distribution_state.get(&"hand_left", {}) as Dictionary).get("requested_degrees", 0.0)),
		"right_authoring_forearm_twist_applied_degrees": float((authoring_limb_twist_distribution_state.get(&"hand_right", {}) as Dictionary).get("forearm_applied_degrees", 0.0)),
		"left_authoring_forearm_twist_applied_degrees": float((authoring_limb_twist_distribution_state.get(&"hand_left", {}) as Dictionary).get("forearm_applied_degrees", 0.0)),
		"right_authoring_upperarm_twist_applied_degrees": float((authoring_limb_twist_distribution_state.get(&"hand_right", {}) as Dictionary).get("upperarm_applied_degrees", 0.0)),
		"left_authoring_upperarm_twist_applied_degrees": float((authoring_limb_twist_distribution_state.get(&"hand_left", {}) as Dictionary).get("upperarm_applied_degrees", 0.0)),
		"right_authoring_twist_bone_applied_count": int((authoring_limb_twist_distribution_state.get(&"hand_right", {}) as Dictionary).get("applied_bone_count", 0)),
		"left_authoring_twist_bone_applied_count": int((authoring_limb_twist_distribution_state.get(&"hand_left", {}) as Dictionary).get("applied_bone_count", 0)),
		"right_hand_world": _get_bone_world_position(RIGHT_HAND_BONE),
		"left_hand_world": _get_bone_world_position(LEFT_HAND_BONE),
		"usable_arm_motion_range_ratio": get_usable_arm_motion_range_ratio(),
		"right_max_arm_chain_reach_meters": right_max_arm_chain_reach_meters,
		"left_max_arm_chain_reach_meters": left_max_arm_chain_reach_meters,
		"right_usable_arm_chain_reach_meters": get_usable_arm_chain_reach_meters(&"hand_right"),
		"left_usable_arm_chain_reach_meters": get_usable_arm_chain_reach_meters(&"hand_left"),
		"right_hand_ik_clavicle_distance_meters": (
			_get_bone_world_position(RIGHT_CLAVICLE_BONE).distance_to(right_hand_ik_target.global_position)
			if right_hand_ik_target != null
			else -1.0
		),
		"left_hand_ik_clavicle_distance_meters": (
			_get_bone_world_position(LEFT_CLAVICLE_BONE).distance_to(left_hand_ik_target.global_position)
			if left_hand_ik_target != null
			else -1.0
		),
		"right_hand_ik_target_world": right_hand_ik_target.global_position if right_hand_ik_target != null else Vector3.ZERO,
		"left_hand_ik_target_world": left_hand_ik_target.global_position if left_hand_ik_target != null else Vector3.ZERO,
		"last_two_hand_solve_result": last_two_hand_solve_result.duplicate(true),
		"right_hand_ik_target_distance_meters": (
			_get_bone_world_position(RIGHT_HAND_BONE).distance_to(right_hand_ik_target.global_position)
			if right_hand_ik_target != null
			else -1.0
		),
		"left_hand_ik_target_distance_meters": (
			_get_bone_world_position(LEFT_HAND_BONE).distance_to(left_hand_ik_target.global_position)
			if left_hand_ik_target != null
			else -1.0
		),
	}

func get_authoring_joint_range_debug_state() -> Dictionary:
	return authoring_joint_range_debug_state.duplicate(true)

func set_authoring_joint_range_debug_visible(debug_visible: bool) -> void:
	show_authoring_joint_range_debug = debug_visible
	var debug_root: Node3D = _ensure_authoring_joint_range_debug_root()
	if debug_root != null:
		debug_root.visible = (
			authoring_preview_mode_enabled
			and show_authoring_joint_range_debug
			and skeleton != null
		)
	if not authoring_joint_range_debug_state.is_empty():
		authoring_joint_range_debug_state["visible"] = (
			debug_root != null and debug_root.visible
		)

func sync_authoring_joint_range_debug_now(debug_visible: bool = true) -> void:
	set_authoring_joint_range_debug_visible(debug_visible)
	_sync_authoring_joint_range_debug()

func resolve_hand_anatomical_y_axis_world(slot_id: StringName) -> Vector3:
	var hand_bone: StringName = RIGHT_HAND_BONE
	var forearm_bone: StringName = RIGHT_FOREARM_BONE
	if slot_id == &"hand_left":
		hand_bone = LEFT_HAND_BONE
		forearm_bone = LEFT_FOREARM_BONE
	var hand_world: Vector3 = _get_bone_world_position(hand_bone)
	var forearm_world: Vector3 = _get_bone_world_position(forearm_bone)
	var axis_world: Vector3 = hand_world - forearm_world
	if axis_world.length_squared() <= 0.000001:
		return Vector3.ZERO
	return axis_world.normalized()

func resolve_hand_index_pinky_axis_local(slot_id: StringName) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var hand_bone: StringName = RIGHT_HAND_BONE
	var index_bone: StringName = RIGHT_INDEX1_BONE
	var pinky_bone: StringName = RIGHT_PINKY1_BONE
	if slot_id == &"hand_left":
		hand_bone = LEFT_HAND_BONE
		index_bone = LEFT_INDEX1_BONE
		pinky_bone = LEFT_PINKY1_BONE
	var hand_index: int = skeleton.find_bone(String(hand_bone))
	var index_index: int = skeleton.find_bone(String(index_bone))
	var pinky_index: int = skeleton.find_bone(String(pinky_bone))
	if hand_index < 0 or index_index < 0 or pinky_index < 0:
		return Vector3.RIGHT
	var rest_axis_local: Vector3 = _resolve_rest_index_pinky_axis_local(hand_index, index_index, pinky_index)
	if rest_axis_local.length_squared() > 0.000001:
		return rest_axis_local
	var hand_basis_world: Basis = (skeleton.global_basis * skeleton.get_bone_global_pose(hand_index).basis).orthonormalized()
	var index_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(index_index).origin)
	var pinky_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(pinky_index).origin)
	var index_to_pinky_world: Vector3 = index_world - pinky_world
	if index_to_pinky_world.length_squared() <= 0.000001:
		return Vector3.RIGHT
	return (hand_basis_world.inverse() * index_to_pinky_world.normalized()).normalized()

func _resolve_rest_index_pinky_axis_local(hand_index: int, index_index: int, pinky_index: int) -> Vector3:
	var hand_rest: Transform3D = _get_bone_global_rest_transform(hand_index)
	var index_rest: Transform3D = _get_bone_global_rest_transform(index_index)
	var pinky_rest: Transform3D = _get_bone_global_rest_transform(pinky_index)
	var rest_axis_skeleton: Vector3 = index_rest.origin - pinky_rest.origin
	if rest_axis_skeleton.length_squared() <= 0.000001:
		return Vector3.ZERO
	return (hand_rest.basis.orthonormalized().inverse() * rest_axis_skeleton.normalized()).normalized()

func set_upper_body_authoring_auto_apply_enabled(enabled: bool) -> void:
	upper_body_authoring_auto_apply_enabled = enabled
	_refresh_combat_authoring_modifier_state()

func apply_upper_body_authoring_pose_now() -> void:
	_apply_upper_body_authoring_pose()

func apply_authoring_preview_frame_now(allow_exact_surface_solve: bool = false) -> void:
	_apply_upper_body_authoring_pose()
	_refresh_support_arm_ik_influences()
	var support_snap_delta: float = 1.0 / maxf(support_arm_ik_target_smoothing_speed, 0.001)
	var finger_snap_delta: float = 1.0 / maxf(finger_grip_target_smoothing_speed, 0.001)
	_update_support_arm_ik_targets(support_snap_delta)
	_apply_authoring_contact_alignment_pose()
	_update_finger_grip_targets(finger_snap_delta, allow_exact_surface_solve)
	_refresh_finger_grip_ik_influences()
	if skeleton != null:
		_advance_skeleton_modifiers_now(1.0 / 60.0)
		skeleton.force_update_all_bone_transforms()
	_sync_authoring_joint_range_debug_if_pose_changed()

func apply_authoring_preview_drag_frame_now(allow_exact_surface_solve: bool = false) -> void:
	_apply_upper_body_authoring_pose()
	_refresh_support_arm_ik_influences()
	var support_snap_delta: float = 1.0 / maxf(support_arm_ik_target_smoothing_speed, 0.001)
	var finger_snap_delta: float = 1.0 / maxf(finger_grip_target_smoothing_speed, 0.001)
	_update_support_arm_ik_targets(support_snap_delta)
	_apply_authoring_contact_alignment_pose(
		AUTHORING_DRAG_CONTACT_ALIGNMENT_PASSES,
		AUTHORING_DRAG_DIRECT_ARM_SOLVE_ITERATIONS,
		AUTHORING_DRAG_ARM_SPLINE_RESEAT_ITERATIONS
	)
	_update_finger_grip_targets(finger_snap_delta, allow_exact_surface_solve)
	_refresh_finger_grip_ik_influences()
	if skeleton != null:
		_advance_skeleton_modifiers_now(1.0 / 60.0)
		skeleton.force_update_all_bone_transforms()
	_sync_authoring_joint_range_debug_if_pose_changed()

func apply_runtime_combat_authoring_frame_now() -> void:
	process_combat_authoring_modifier_frame(1.0 / 60.0)

func apply_runtime_contact_group_frame_now(delta: float = 1.0 / 60.0) -> void:
	if skeleton == null:
		return
	_apply_authoring_contact_wrist_basis_pose()
	var finger_snap_delta: float = 1.0 / maxf(finger_grip_target_smoothing_speed, 0.001)
	_update_finger_grip_targets(maxf(delta, finger_snap_delta))
	_refresh_finger_grip_ik_influences()
	skeleton.force_update_all_bone_transforms()

func process_combat_authoring_modifier_frame(delta: float = 1.0 / 60.0) -> void:
	if combat_authoring_modifier_processing:
		return
	if not _uses_direct_authoring_solver_mode() or skeleton == null:
		return
	combat_authoring_modifier_processing = true
	_apply_combat_authoring_overlay_frame(maxf(delta, 0.0))
	combat_authoring_modifier_processing = false

func _apply_combat_authoring_overlay_frame(delta: float) -> void:
	_apply_upper_body_authoring_pose()
	_refresh_support_arm_ik_influences()
	var support_snap_delta: float = 1.0 / maxf(support_arm_ik_target_smoothing_speed, 0.001)
	var finger_snap_delta: float = 1.0 / maxf(finger_grip_target_smoothing_speed, 0.001)
	_update_support_arm_ik_targets(support_snap_delta)
	_apply_authoring_contact_alignment_pose(
		AUTHORING_DRAG_CONTACT_ALIGNMENT_PASSES,
		AUTHORING_DRAG_DIRECT_ARM_SOLVE_ITERATIONS,
		AUTHORING_DRAG_ARM_SPLINE_RESEAT_ITERATIONS
	)
	_apply_authoring_contact_wrist_basis_pose()
	_update_finger_grip_targets(maxf(delta, finger_snap_delta))
	_refresh_finger_grip_ik_influences()
	if skeleton != null:
		skeleton.force_update_all_bone_transforms()

func reset_authoring_preview_baseline_pose(baseline_animation_name: StringName = StringName()) -> void:
	clear_upper_body_authoring_state()
	clear_authoring_contact_anchor_bases()
	authoring_limb_twist_distribution_state.clear()
	clear_dominant_grip_slot()
	for slot_id: StringName in [&"hand_right", &"hand_left"]:
		guidance_state_presenter.clear_arm_guidance_target(slot_id)
		guidance_state_presenter.clear_arm_guidance_active(slot_id)
		guidance_state_presenter.set_support_hand_active(slot_id, false)
		clear_finger_grip_target(slot_id)
	_apply_authoring_preview_baseline_pose(baseline_animation_name)
	_snap_support_arm_ik_targets_to_current_pose()
	_refresh_support_arm_ik_influences()
	_refresh_finger_grip_ik_influences()
	_cache_authoring_limb_twist_neutral_pose()
	_cache_authoring_digit_hinge_neutral_pose()
	if skeleton != null:
		skeleton.force_update_all_bone_transforms()

func set_authoring_preview_mode_enabled(enabled: bool, baseline_animation_name: StringName = StringName()) -> void:
	authoring_preview_mode_enabled = enabled
	if not authoring_preview_mode_enabled:
		_clear_authoring_joint_range_debug_pose_snapshot()
	_set_skeleton_modifier_callback_mode_for_authoring(authoring_preview_mode_enabled)
	_refresh_combat_authoring_modifier_state()
	_refresh_runtime_solved_replay_modifier_state()
	_refresh_runtime_body_restriction_sync_modifier_state()
	_refresh_runtime_bone_debug_modifier_state()
	if authoring_preview_mode_enabled:
		if runtime_locomotion_animation_tree != null:
			runtime_locomotion_animation_tree.active = false
		locomotion_horizontal_speed = 0.0
		locomotion_grounded = true
		locomotion_vertical_velocity = 0.0
		if baseline_animation_name != authoring_preview_baseline_animation_name:
			_apply_authoring_preview_baseline_pose(baseline_animation_name)
			_cache_authoring_limb_twist_neutral_pose()
			_cache_authoring_digit_hinge_neutral_pose()
		elif authoring_digit_hinge_neutral_rotation_lookup.is_empty():
			_cache_authoring_digit_hinge_neutral_pose()
		authoring_preview_baseline_animation_name = baseline_animation_name
		return
	authoring_preview_baseline_animation_name = StringName()
	clear_authoring_contact_anchor_bases()
	authoring_limb_twist_distribution_state.clear()
	authoring_digit_hinge_neutral_rotation_lookup.clear()
	if runtime_locomotion_animation_tree != null:
		runtime_locomotion_animation_tree.active = true
	_refresh_combat_authoring_modifier_state()
	_refresh_runtime_solved_replay_modifier_state()
	_refresh_runtime_body_restriction_sync_modifier_state()
	_refresh_runtime_bone_debug_modifier_state()
	_play_default_animation()

func _set_skeleton_modifier_callback_mode_for_authoring(enabled: bool) -> void:
	if skeleton == null:
		return
	skeleton.modifier_callback_mode_process = (
		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
		if enabled
		else Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
	)

func _advance_skeleton_modifiers_now(delta: float) -> void:
	if skeleton == null:
		return
	if not skeleton.has_method("advance"):
		return
	skeleton.call("advance", maxf(delta, 0.0))

func _apply_authoring_contact_alignment_pose(
	pass_count: int = 3,
	direct_solve_iterations: int = AUTHORING_DIRECT_ARM_SOLVE_ITERATIONS,
	reseat_iterations: int = AUTHORING_ARM_SPLINE_RESEAT_ITERATIONS
) -> void:
	if not _can_apply_authoring_contact_alignment() or skeleton == null:
		return
	for _pass_index: int in range(maxi(pass_count, 1)):
		_apply_authoring_direct_arm_reach_pose(direct_solve_iterations, reseat_iterations)
		_apply_authoring_contact_wrist_basis_pose()

func _apply_authoring_direct_arm_reach_pose(
	solve_iterations: int = AUTHORING_DIRECT_ARM_SOLVE_ITERATIONS,
	reseat_iterations: int = AUTHORING_ARM_SPLINE_RESEAT_ITERATIONS
) -> void:
	if not _can_apply_authoring_contact_alignment() or skeleton == null:
		return
	if is_arm_guidance_active(&"hand_right") and right_hand_ik_target != null:
		var right_hand_target_world: Vector3 = right_hand_ik_target.global_position
		var right_target_world: Vector3 = _resolve_usable_arm_target_world(&"hand_right", right_hand_target_world).get("target_world", right_hand_target_world) as Vector3
		_apply_ccd_arm_reach_pose(
			RIGHT_UPPERARM_BONE,
			RIGHT_FOREARM_BONE,
			RIGHT_HAND_BONE,
			right_target_world,
			solve_iterations,
			AUTHORING_DIRECT_ARM_FOREARM_WEIGHT,
			AUTHORING_DIRECT_ARM_UPPERARM_WEIGHT,
			RIGHT_CLAVICLE_BONE,
			AUTHORING_DIRECT_ARM_CLAVICLE_WEIGHT
		)
		_apply_authoring_arm_spline_preference(
			&"hand_right",
			RIGHT_CLAVICLE_BONE,
			RIGHT_UPPERARM_BONE,
			RIGHT_FOREARM_BONE,
			RIGHT_HAND_BONE,
			get_right_hand_item_anchor()
		)
		_apply_ccd_arm_reach_pose(
			RIGHT_UPPERARM_BONE,
			RIGHT_FOREARM_BONE,
			RIGHT_HAND_BONE,
			right_target_world,
			reseat_iterations,
			AUTHORING_DIRECT_ARM_FOREARM_WEIGHT * 0.5,
			AUTHORING_DIRECT_ARM_UPPERARM_WEIGHT * 0.5,
			RIGHT_CLAVICLE_BONE,
			AUTHORING_DIRECT_ARM_CLAVICLE_WEIGHT * 0.5
		)
		_apply_authoring_manual_upperarm_roll_pose(
			&"hand_right",
			RIGHT_UPPERARM_BONE,
			RIGHT_FOREARM_BONE,
			RIGHT_HAND_BONE
		)
		_enforce_authoring_upperarm_swing_authority(
			&"hand_right",
			RIGHT_CLAVICLE_BONE,
			RIGHT_UPPERARM_BONE,
			RIGHT_FOREARM_BONE,
			RIGHT_HAND_BONE
		)
		_enforce_authoring_elbow_max_angle(RIGHT_UPPERARM_BONE, RIGHT_FOREARM_BONE, RIGHT_HAND_BONE)
	if is_arm_guidance_active(&"hand_left") and left_hand_ik_target != null:
		var left_hand_target_world: Vector3 = left_hand_ik_target.global_position
		var left_target_world: Vector3 = _resolve_usable_arm_target_world(&"hand_left", left_hand_target_world).get("target_world", left_hand_target_world) as Vector3
		_apply_ccd_arm_reach_pose(
			LEFT_UPPERARM_BONE,
			LEFT_FOREARM_BONE,
			LEFT_HAND_BONE,
			left_target_world,
			solve_iterations,
			AUTHORING_DIRECT_ARM_FOREARM_WEIGHT,
			AUTHORING_DIRECT_ARM_UPPERARM_WEIGHT,
			LEFT_CLAVICLE_BONE,
			AUTHORING_DIRECT_ARM_CLAVICLE_WEIGHT
		)
		_apply_authoring_arm_spline_preference(
			&"hand_left",
			LEFT_CLAVICLE_BONE,
			LEFT_UPPERARM_BONE,
			LEFT_FOREARM_BONE,
			LEFT_HAND_BONE,
			get_left_hand_item_anchor()
		)
		_apply_ccd_arm_reach_pose(
			LEFT_UPPERARM_BONE,
			LEFT_FOREARM_BONE,
			LEFT_HAND_BONE,
			left_target_world,
			reseat_iterations,
			AUTHORING_DIRECT_ARM_FOREARM_WEIGHT * 0.5,
			AUTHORING_DIRECT_ARM_UPPERARM_WEIGHT * 0.5,
			LEFT_CLAVICLE_BONE,
			AUTHORING_DIRECT_ARM_CLAVICLE_WEIGHT * 0.5
		)
		_apply_authoring_manual_upperarm_roll_pose(
			&"hand_left",
			LEFT_UPPERARM_BONE,
			LEFT_FOREARM_BONE,
			LEFT_HAND_BONE
		)
		_enforce_authoring_upperarm_swing_authority(
			&"hand_left",
			LEFT_CLAVICLE_BONE,
			LEFT_UPPERARM_BONE,
			LEFT_FOREARM_BONE,
			LEFT_HAND_BONE
		)
		_enforce_authoring_elbow_max_angle(LEFT_UPPERARM_BONE, LEFT_FOREARM_BONE, LEFT_HAND_BONE)
	skeleton.force_update_all_bone_transforms()

func _can_apply_authoring_contact_alignment() -> bool:
	if authoring_preview_mode_enabled:
		return true
	if upper_body_authoring_auto_apply_enabled:
		return false
	return not upper_body_authoring_state.is_empty() and bool(upper_body_authoring_state.get("active", false))

func _apply_authoring_contact_wrist_basis_pose() -> void:
	if skeleton == null:
		return
	if not enable_authoring_contact_wrist_basis:
		return
	var resolved_strength: float = clampf(authoring_contact_wrist_basis_strength, 0.0, 1.0)
	if resolved_strength <= 0.00001:
		return
	authoring_limb_twist_distribution_state.clear()
	_apply_authoring_contact_wrist_basis_for_slot(
		&"hand_right",
		RIGHT_HAND_BONE,
		RIGHT_FOREARM_BONE,
		get_right_hand_item_anchor(),
		resolved_strength
	)
	_apply_authoring_contact_wrist_basis_for_slot(
		&"hand_left",
		LEFT_HAND_BONE,
		LEFT_FOREARM_BONE,
		get_left_hand_item_anchor(),
		resolved_strength
	)
	skeleton.force_update_all_bone_transforms()

func _apply_authoring_contact_wrist_basis_for_slot(
	slot_id: StringName,
	hand_bone: StringName,
	forearm_bone: StringName,
	hand_anchor: Node3D,
	strength: float
) -> void:
	if not is_arm_guidance_active(slot_id):
		return
	if not finger_grip_source_lookup.has(slot_id):
		return
	if not authoring_contact_anchor_basis_lookup.has(slot_id):
		return
	if hand_anchor == null or not is_instance_valid(hand_anchor):
		return
	var desired_anchor_basis_world: Basis = authoring_contact_anchor_basis_lookup.get(slot_id, Basis.IDENTITY) as Basis
	var anchor_local_basis: Basis = hand_anchor.transform.basis.orthonormalized()
	var contact_hand_basis_world: Basis = (desired_anchor_basis_world * anchor_local_basis.inverse()).orthonormalized()
	var desired_hand_basis_world: Basis = _resolve_anatomical_contact_hand_basis_for_slot(
		slot_id,
		forearm_bone,
		hand_bone,
		contact_hand_basis_world
	)
	desired_hand_basis_world = _apply_authoring_contact_wrist_straight_preference(
		hand_bone,
		desired_hand_basis_world
	)
	_apply_authoring_limb_twist_distribution_for_slot(
		slot_id,
		forearm_bone,
		hand_bone,
		desired_hand_basis_world,
		strength
	)
	skeleton.force_update_all_bone_transforms()
	desired_hand_basis_world = _clamp_authoring_contact_wrist_twist(
		slot_id,
		hand_bone,
		forearm_bone,
		desired_hand_basis_world
	)
	_apply_bone_world_basis(hand_bone, desired_hand_basis_world, strength)

func _sync_authoring_joint_range_debug() -> void:
	authoring_joint_range_debug_state = {
		"visible": false,
		"visual_count": 0,
		"digit_visual_count": 0,
		"joints": {},
		"twist_bones": {},
		"digit_bones": {},
	}
	var debug_root: Node3D = _ensure_authoring_joint_range_debug_root()
	if debug_root == null:
		_clear_authoring_joint_range_debug_pose_snapshot()
		return
	var debug_active: bool = authoring_preview_mode_enabled and skeleton != null
	var debug_visible: bool = debug_active and show_authoring_joint_range_debug
	debug_root.visible = debug_visible
	if not debug_active:
		_clear_authoring_joint_range_debug_pose_snapshot()
		return
	debug_root.global_transform = Transform3D.IDENTITY
	var joints: Dictionary = {}
	var twist_bones: Dictionary = {}
	var digit_bones: Dictionary = {}
	var visual_count: int = 0
	var right_shoulder: Dictionary = _sync_authoring_joint_range_visual(
		debug_root,
		"RightShoulderRange",
		"R shoulder",
		RIGHT_CLAVICLE_BONE,
		RIGHT_UPPERARM_BONE,
		RIGHT_FOREARM_BONE,
		authoring_shoulder_min_plane_angle_degrees,
		authoring_shoulder_max_plane_angle_degrees,
		0.22,
		Color(0.20, 0.72, 1.0, 0.20)
	)
	if bool(right_shoulder.get("visible", false)):
		visual_count += 1
	joints["right_shoulder"] = right_shoulder
	var right_elbow: Dictionary = _sync_authoring_joint_range_visual(
		debug_root,
		"RightElbowRange",
		"R elbow",
		RIGHT_UPPERARM_BONE,
		RIGHT_FOREARM_BONE,
		RIGHT_HAND_BONE,
		authoring_elbow_min_plane_angle_degrees,
		authoring_elbow_max_plane_angle_degrees,
		0.18,
		Color(0.24, 0.95, 0.42, 0.20)
	)
	if bool(right_elbow.get("visible", false)):
		visual_count += 1
	joints["right_elbow"] = right_elbow
	var left_shoulder: Dictionary = _sync_authoring_joint_range_visual(
		debug_root,
		"LeftShoulderRange",
		"L shoulder",
		LEFT_CLAVICLE_BONE,
		LEFT_UPPERARM_BONE,
		LEFT_FOREARM_BONE,
		authoring_shoulder_min_plane_angle_degrees,
		authoring_shoulder_max_plane_angle_degrees,
		0.22,
		Color(0.18, 0.52, 1.0, 0.20)
	)
	if bool(left_shoulder.get("visible", false)):
		visual_count += 1
	joints["left_shoulder"] = left_shoulder
	var left_elbow: Dictionary = _sync_authoring_joint_range_visual(
		debug_root,
		"LeftElbowRange",
		"L elbow",
		LEFT_UPPERARM_BONE,
		LEFT_FOREARM_BONE,
		LEFT_HAND_BONE,
		authoring_elbow_min_plane_angle_degrees,
		authoring_elbow_max_plane_angle_degrees,
		0.18,
		Color(0.16, 0.86, 0.50, 0.20)
	)
	if bool(left_elbow.get("visible", false)):
		visual_count += 1
	joints["left_elbow"] = left_elbow
	visual_count += _sync_authoring_twist_range_chain(
		debug_root,
		twist_bones,
		"RightUpperarmTwist",
		"right_upperarm_twist",
		"R upper twist",
		RIGHT_UPPERARM_TWIST_BONES,
		0.14,
		Color(1.0, 0.48, 0.18, 0.24)
	)
	visual_count += _sync_authoring_twist_range_chain(
		debug_root,
		twist_bones,
		"RightForearmTwist",
		"right_forearm_twist",
		"R fore twist",
		RIGHT_FOREARM_TWIST_BONES,
		0.12,
		Color(1.0, 0.78, 0.18, 0.24)
	)
	visual_count += _sync_authoring_twist_range_chain(
		debug_root,
		twist_bones,
		"LeftUpperarmTwist",
		"left_upperarm_twist",
		"L upper twist",
		LEFT_UPPERARM_TWIST_BONES,
		0.14,
		Color(0.82, 0.44, 1.0, 0.24)
	)
	visual_count += _sync_authoring_twist_range_chain(
		debug_root,
		twist_bones,
		"LeftForearmTwist",
		"left_forearm_twist",
		"L fore twist",
		LEFT_FOREARM_TWIST_BONES,
		0.12,
		Color(0.96, 0.28, 0.82, 0.24)
	)
	var digit_visual_count: int = _sync_authoring_digit_hinge_range_chain(
		debug_root,
		digit_bones
	)
	visual_count += digit_visual_count
	authoring_joint_range_debug_state = {
		"visible": debug_visible,
		"visual_count": visual_count,
		"digit_visual_count": digit_visual_count,
		"joints": joints,
		"twist_bones": twist_bones,
		"digit_bones": digit_bones,
	}
	_capture_authoring_joint_range_debug_pose_snapshot()


func _sync_authoring_joint_range_debug_if_pose_changed() -> void:
	if _authoring_joint_range_debug_pose_matches_snapshot():
		return
	_sync_authoring_joint_range_debug()


func _authoring_joint_range_debug_pose_matches_snapshot() -> bool:
	if (
		skeleton == null
		or not authoring_preview_mode_enabled
		or authoring_joint_range_debug_pose_snapshot.is_empty()
		or authoring_joint_range_debug_config_signature
			!= _resolve_authoring_joint_range_debug_config_signature()
	):
		return false
	var existing_bone_count := 0
	for bone_name: StringName in RUNTIME_UPPER_BODY_POSE_BONES:
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		existing_bone_count += 1
		var cached_pose_variant: Variant = (
			authoring_joint_range_debug_pose_snapshot.get(bone_name, null)
		)
		if not cached_pose_variant is Transform3D:
			return false
		var current_pose_world: Transform3D = (
			skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)
		)
		if not current_pose_world.is_equal_approx(cached_pose_variant as Transform3D):
			return false
	return existing_bone_count == authoring_joint_range_debug_pose_snapshot.size()


func _capture_authoring_joint_range_debug_pose_snapshot() -> void:
	authoring_joint_range_debug_pose_snapshot.clear()
	if skeleton == null or not authoring_preview_mode_enabled:
		authoring_joint_range_debug_config_signature = 0
		return
	for bone_name: StringName in RUNTIME_UPPER_BODY_POSE_BONES:
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		authoring_joint_range_debug_pose_snapshot[bone_name] = (
			skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)
		)
	authoring_joint_range_debug_config_signature = (
		_resolve_authoring_joint_range_debug_config_signature()
	)


func _clear_authoring_joint_range_debug_pose_snapshot() -> void:
	authoring_joint_range_debug_pose_snapshot.clear()
	authoring_joint_range_debug_config_signature = 0


func _resolve_authoring_joint_range_debug_config_signature() -> int:
	var right_digit_zero_packet: Dictionary = (
		_resolve_committed_authoring_digit_zero_packet(&"hand_right")
	)
	var left_digit_zero_packet: Dictionary = (
		_resolve_committed_authoring_digit_zero_packet(&"hand_left")
	)
	return hash([
		show_authoring_joint_range_labels,
		authoring_shoulder_min_plane_angle_degrees,
		authoring_shoulder_max_plane_angle_degrees,
		authoring_elbow_min_plane_angle_degrees,
		authoring_elbow_max_plane_angle_degrees,
		PlayerDigitHingeRulesScript.get_revision(),
		hash(authoring_limb_twist_neutral_rotation_lookup),
		hash(authoring_digit_hinge_neutral_rotation_lookup),
		String(right_digit_zero_packet.get("context_key", "")),
		String(right_digit_zero_packet.get("packet_signature", "")),
		String(left_digit_zero_packet.get("context_key", "")),
		String(left_digit_zero_packet.get("packet_signature", "")),
	])


func _resolve_committed_authoring_digit_zero_packet(
	slot_id: StringName
) -> Dictionary:
	if not finger_grip_presenter.has_method(
		"get_committed_surface_grasp_zero_packet"
	):
		return {}
	var packet: Dictionary = finger_grip_presenter.call(
		"get_committed_surface_grasp_zero_packet",
		slot_id
	) as Dictionary
	if not bool(packet.get("valid", false)):
		return {}
	var expected_bones: Array[StringName] = (
		PlayerDigitHingeRulesScript.get_finger_bone_names(slot_id)
	)
	var zero_rotations: Dictionary = packet.get("zero_rotations", {}) as Dictionary
	if expected_bones.size() != 15 or zero_rotations.size() != expected_bones.size():
		return {}
	for bone_name: StringName in expected_bones:
		var zero_rotation_variant: Variant = zero_rotations.get(bone_name, null)
		if not zero_rotation_variant is Quaternion:
			return {}
		var zero_rotation: Quaternion = zero_rotation_variant as Quaternion
		if (
			not is_finite(zero_rotation.x)
			or not is_finite(zero_rotation.y)
			or not is_finite(zero_rotation.z)
			or not is_finite(zero_rotation.w)
		):
			return {}
	return packet

func _ensure_authoring_joint_range_debug_root() -> Node3D:
	if authoring_joint_range_debug_root != null and is_instance_valid(authoring_joint_range_debug_root):
		return authoring_joint_range_debug_root
	authoring_joint_range_debug_root = get_node_or_null(AUTHORING_JOINT_RANGE_DEBUG_ROOT_NAME) as Node3D
	if authoring_joint_range_debug_root == null:
		authoring_joint_range_debug_root = Node3D.new()
		authoring_joint_range_debug_root.name = AUTHORING_JOINT_RANGE_DEBUG_ROOT_NAME
		add_child(authoring_joint_range_debug_root)
	authoring_joint_range_debug_root.top_level = true
	authoring_joint_range_debug_root.global_transform = Transform3D.IDENTITY
	return authoring_joint_range_debug_root

func _sync_authoring_joint_range_visual(
	debug_root: Node3D,
	visual_name: String,
	label_text: String,
	parent_bone: StringName,
	joint_bone: StringName,
	child_bone: StringName,
	min_angle_degrees: float,
	max_angle_degrees: float,
	fallback_radius: float,
	base_color: Color
) -> Dictionary:
	var visual_root: Node3D = _ensure_named_node3d(debug_root, visual_name)
	var result := {
		"visible": false,
		"angle_degrees": -1.0,
		"min_angle_degrees": min_angle_degrees,
		"max_angle_degrees": max_angle_degrees,
		"state": "missing",
	}
	if skeleton == null:
		visual_root.visible = false
		return result
	var parent_world: Vector3 = _get_bone_world_position(parent_bone)
	var joint_world: Vector3 = _get_bone_world_position(joint_bone)
	var child_world: Vector3 = _get_bone_world_position(child_bone)
	var parent_vector: Vector3 = parent_world - joint_world
	var child_vector: Vector3 = child_world - joint_world
	if parent_vector.length_squared() <= 0.000001 or child_vector.length_squared() <= 0.000001:
		visual_root.visible = false
		return result
	var parent_dir: Vector3 = parent_vector.normalized()
	var child_dir: Vector3 = child_vector.normalized()
	var plane_normal: Vector3 = parent_dir.cross(child_dir)
	if plane_normal.length_squared() <= 0.000001:
		plane_normal = global_basis.z - parent_dir * global_basis.z.dot(parent_dir)
	if plane_normal.length_squared() <= 0.000001:
		plane_normal = global_basis.y - parent_dir * global_basis.y.dot(parent_dir)
	if plane_normal.length_squared() <= 0.000001:
		plane_normal = Vector3.UP - parent_dir * Vector3.UP.dot(parent_dir)
	if plane_normal.length_squared() <= 0.000001:
		visual_root.visible = false
		return result
	plane_normal = plane_normal.normalized()
	var resolved_min: float = clampf(min_angle_degrees, 0.0, 180.0)
	var resolved_max: float = clampf(max_angle_degrees, resolved_min, 180.0)
	var current_angle: float = rad_to_deg(parent_dir.angle_to(child_dir))
	var status_color: Color = _resolve_joint_range_status_color(current_angle, resolved_min, resolved_max)
	var state_text: String = _resolve_joint_range_state_text(current_angle, resolved_min, resolved_max)
	var radius: float = maxf(minf(maxf(parent_vector.length(), child_vector.length()) * 0.85, fallback_radius), 0.08)
	visual_root.visible = true
	_update_joint_range_plane_mesh(
		visual_root,
		joint_world,
		parent_dir,
		plane_normal,
		resolved_min,
		resolved_max,
		radius,
		base_color
	)
	_update_joint_range_line_mesh(
		visual_root,
		joint_world,
		parent_world,
		child_world,
		parent_dir,
		child_dir,
		plane_normal,
		resolved_min,
		resolved_max,
		radius,
		status_color
	)
	_update_joint_range_label(
		visual_root,
		label_text,
		joint_world,
		parent_dir,
		plane_normal,
		resolved_min,
		resolved_max,
		current_angle,
		radius,
		status_color
	)
	result["visible"] = true
	result["angle_degrees"] = current_angle
	result["state"] = state_text
	return result

func _sync_authoring_twist_range_chain(
	debug_root: Node3D,
	twist_bones: Dictionary,
	visual_prefix: String,
	state_prefix: String,
	label_prefix: String,
	twist_bone_names: Array,
	fallback_radius: float,
	base_color: Color
) -> int:
	var existing_count: int = _count_existing_bones(twist_bone_names)
	var visual_count: int = 0
	for bone_index: int in range(twist_bone_names.size()):
		var twist_bone: StringName = twist_bone_names[bone_index] as StringName
		var visual_state: Dictionary = _sync_authoring_twist_range_visual(
			debug_root,
			"%s%02dRange" % [visual_prefix, bone_index + 1],
			"%s %d" % [label_prefix, bone_index + 1],
			twist_bone,
			maxi(existing_count, 1),
			fallback_radius,
			base_color
		)
		if bool(visual_state.get("visible", false)):
			visual_count += 1
		twist_bones["%s_%d" % [state_prefix, bone_index + 1]] = visual_state
	return visual_count

func _sync_authoring_twist_range_visual(
	debug_root: Node3D,
	visual_name: String,
	label_text: String,
	twist_bone: StringName,
	chain_bone_count: int,
	fallback_radius: float,
	base_color: Color
) -> Dictionary:
	var visual_root: Node3D = _ensure_named_node3d(debug_root, visual_name)
	var per_bone_limit_degrees: float = rad_to_deg(AUTHORING_LIMB_TWIST_LIMIT_RADIANS) / maxf(float(chain_bone_count), 1.0)
	var min_angle_degrees: float = -per_bone_limit_degrees
	var max_angle_degrees: float = per_bone_limit_degrees
	var result := {
		"visible": false,
		"angle_degrees": -999.0,
		"min_angle_degrees": min_angle_degrees,
		"max_angle_degrees": max_angle_degrees,
		"state": "missing",
		"bone": String(twist_bone),
	}
	var twist_index: int = skeleton.find_bone(String(twist_bone)) if skeleton != null else -1
	if twist_index < 0:
		visual_root.visible = false
		return result
	if authoring_limb_twist_neutral_rotation_lookup.is_empty():
		_cache_authoring_limb_twist_neutral_pose()
	if not authoring_limb_twist_neutral_rotation_lookup.has(twist_bone):
		_cache_authoring_limb_twist_neutral_bone(twist_bone)
	var neutral_local_rotation: Quaternion = (
		authoring_limb_twist_neutral_rotation_lookup.get(twist_bone, skeleton.get_bone_pose_rotation(twist_index))
		as Quaternion
	).normalized()
	var current_local_rotation: Quaternion = skeleton.get_bone_pose_rotation(twist_index).normalized()
	var local_delta: Quaternion = (neutral_local_rotation.inverse() * current_local_rotation).normalized()
	var twist_local_axis: Vector3 = _resolve_authoring_limb_twist_local_axis(twist_bone)
	var current_twist: Quaternion = _extract_quaternion_twist(local_delta, twist_local_axis)
	var current_angle: float = rad_to_deg(_resolve_signed_twist_angle(current_twist, twist_local_axis))
	var parent_index: int = skeleton.get_bone_parent(twist_index)
	var parent_basis: Basis = Basis.IDENTITY
	if parent_index >= 0:
		parent_basis = skeleton.get_bone_global_pose(parent_index).basis.orthonormalized()
	var neutral_world_basis: Basis = (
		skeleton.global_basis * (parent_basis * Basis(neutral_local_rotation))
	).orthonormalized()
	var current_world_basis: Basis = (
		skeleton.global_basis * skeleton.get_bone_global_pose(twist_index).basis
	).orthonormalized()
	var twist_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(twist_index).origin)
	var axis_world: Vector3 = neutral_world_basis * twist_local_axis
	if axis_world.length_squared() <= 0.000001:
		axis_world = current_world_basis * twist_local_axis
	if axis_world.length_squared() <= 0.000001:
		visual_root.visible = false
		return result
	axis_world = axis_world.normalized()
	var neutral_reference_dir: Vector3 = neutral_world_basis.x - axis_world * neutral_world_basis.x.dot(axis_world)
	if neutral_reference_dir.length_squared() <= 0.000001:
		neutral_reference_dir = neutral_world_basis.z - axis_world * neutral_world_basis.z.dot(axis_world)
	if neutral_reference_dir.length_squared() <= 0.000001:
		neutral_reference_dir = Vector3.RIGHT - axis_world * Vector3.RIGHT.dot(axis_world)
	if neutral_reference_dir.length_squared() <= 0.000001:
		neutral_reference_dir = Vector3.FORWARD - axis_world * Vector3.FORWARD.dot(axis_world)
	if neutral_reference_dir.length_squared() <= 0.000001:
		visual_root.visible = false
		return result
	neutral_reference_dir = neutral_reference_dir.normalized()
	var current_reference_dir: Vector3 = current_world_basis.x - axis_world * current_world_basis.x.dot(axis_world)
	if current_reference_dir.length_squared() <= 0.000001:
		current_reference_dir = (Basis(axis_world, deg_to_rad(current_angle)) * neutral_reference_dir).normalized()
	else:
		current_reference_dir = current_reference_dir.normalized()
	var status_color: Color = _resolve_joint_range_status_color(current_angle, min_angle_degrees, max_angle_degrees)
	var state_text: String = _resolve_joint_range_state_text(current_angle, min_angle_degrees, max_angle_degrees)
	var radius: float = maxf(fallback_radius, 0.04)
	visual_root.visible = true
	_update_joint_range_plane_mesh(
		visual_root,
		twist_world,
		neutral_reference_dir,
		axis_world,
		min_angle_degrees,
		max_angle_degrees,
		radius,
		base_color
	)
	_update_twist_range_rotation_mesh(
		visual_root,
		twist_world,
		axis_world,
		neutral_reference_dir,
		current_reference_dir,
		min_angle_degrees,
		max_angle_degrees,
		current_angle,
		radius,
		status_color
	)
	_update_joint_range_label(
		visual_root,
		label_text,
		twist_world,
		neutral_reference_dir,
		axis_world,
		min_angle_degrees,
		max_angle_degrees,
		current_angle,
		radius,
		status_color
	)
	result["visible"] = true
	result["angle_degrees"] = current_angle
	result["state"] = state_text
	return result

func _sync_authoring_digit_hinge_range_chain(
	debug_root: Node3D,
	digit_bones: Dictionary
) -> int:
	if authoring_digit_hinge_neutral_rotation_lookup.is_empty():
		_cache_authoring_digit_hinge_neutral_pose()
	var exact_zero_packets: Dictionary = {
		&"hand_right": _resolve_committed_authoring_digit_zero_packet(&"hand_right"),
		&"hand_left": _resolve_committed_authoring_digit_zero_packet(&"hand_left"),
	}
	var visual_count: int = 0
	for rule: Dictionary in PlayerDigitHingeRulesScript.get_all_rules():
		var slot_id: StringName = rule.get("slot_id", StringName()) as StringName
		var bone_name: StringName = rule.get("bone", StringName()) as StringName
		var digit_id: StringName = rule.get("digit", StringName()) as StringName
		var section_index: int = int(rule.get("section", 0))
		var side_label: String = "R" if slot_id == &"hand_right" else "L"
		var side_name: String = "Right" if slot_id == &"hand_right" else "Left"
		var visual_state: Dictionary = _sync_authoring_digit_hinge_range_visual(
			debug_root,
			"%s%s%02dDigitRange" % [side_name, String(digit_id).capitalize(), section_index],
			"%s %s %d" % [side_label, String(digit_id), section_index],
			rule,
			_resolve_authoring_digit_range_color(slot_id, digit_id, section_index),
			exact_zero_packets.get(slot_id, {}) as Dictionary
		)
		if bool(visual_state.get("visible", false)):
			visual_count += 1
		digit_bones[String(bone_name)] = visual_state
	return visual_count

func _sync_authoring_digit_hinge_range_visual(
	debug_root: Node3D,
	visual_name: String,
	label_text: String,
	rule: Dictionary,
	base_color: Color,
	exact_zero_packet: Dictionary = {}
) -> Dictionary:
	var visual_root: Node3D = _ensure_named_node3d(debug_root, visual_name)
	var slot_id: StringName = rule.get("slot_id", StringName()) as StringName
	var bone_name: StringName = rule.get("bone", StringName()) as StringName
	var next_bone_name: StringName = rule.get("next_bone", StringName()) as StringName
	var digit_id: StringName = rule.get("digit", StringName()) as StringName
	var section_index: int = int(rule.get("section", 0))
	var open_angle_degrees: float = float(rule.get("open_degrees", 0.0))
	var closed_angle_degrees: float = float(rule.get("closed_degrees", 130.0))
	var min_angle_degrees: float = float(rule.get("min_degrees", 0.0))
	var max_angle_degrees: float = float(rule.get("max_degrees", 130.0))
	var hinge_axis_local: Vector3 = rule.get("hinge_axis_local", Vector3.FORWARD) as Vector3
	var hinge_axis_origin_id: StringName = rule.get("hinge_axis_origin_id", StringName()) as StringName
	var zero_direction_local: Vector3 = rule.get("zero_direction_local", Vector3.UP) as Vector3
	var zero_direction_origin_id: StringName = rule.get("zero_direction_origin_id", StringName()) as StringName
	var bone_root_origin_id: StringName = rule.get("bone_root_origin_id", StringName()) as StringName
	var exact_zero_rotations: Dictionary = exact_zero_packet.get(
		"zero_rotations",
		{}
	) as Dictionary
	var exact_zero_rotation_variant: Variant = exact_zero_rotations.get(
		bone_name,
		null
	)
	var uses_exact_solver_zero: bool = (
		bool(exact_zero_packet.get("valid", false))
		and exact_zero_rotation_variant is Quaternion
	)
	var reference_pose: String = (
		"committed_exact_surface_solver_zero"
		if uses_exact_solver_zero
		else "authoring_baseline"
	)
	var result := {
		"visible": false,
		"bone": String(bone_name),
		"slot_id": String(slot_id),
		"digit": String(digit_id),
		"section": section_index,
		"angle_degrees": -999.0,
		"open_angle_degrees": open_angle_degrees,
		"closed_angle_degrees": closed_angle_degrees,
		"min_angle_degrees": min_angle_degrees,
		"max_angle_degrees": max_angle_degrees,
		"allowed_sweep_degrees": absf(max_angle_degrees - min_angle_degrees),
		"hinge_axis_local": hinge_axis_local,
		"hinge_axis_origin_id": hinge_axis_origin_id,
		"zero_direction_local": zero_direction_local,
		"zero_direction_origin_id": zero_direction_origin_id,
		"bone_root_origin_id": bone_root_origin_id,
		"reference_pose": reference_pose,
		"reference_context_key": String(exact_zero_packet.get(
			"context_key",
			""
		)) if uses_exact_solver_zero else "",
		"reference_packet_signature": String(exact_zero_packet.get(
			"packet_signature",
			""
		)) if uses_exact_solver_zero else "",
		"reference_execution_path_id": StringName(exact_zero_packet.get(
			"grip_execution_path_id",
			StringName()
		)) if uses_exact_solver_zero else StringName(),
		"state": "missing",
	}
	var bone_index: int = skeleton.find_bone(String(bone_name)) if skeleton != null else -1
	if bone_index < 0:
		visual_root.visible = false
		return result
	var parent_index: int = skeleton.get_bone_parent(bone_index)
	if (
		parent_index < 0
		or not PlayerDigitHingeRulesScript.rule_has_valid_origin_chain(rule, skeleton)
		or hinge_axis_local.length_squared() <= 0.000001
		or zero_direction_local.length_squared() <= 0.000001
	):
		visual_root.visible = false
		return result
	hinge_axis_local = hinge_axis_local.normalized()
	zero_direction_local = zero_direction_local.normalized()
	var neutral_local_rotation: Quaternion = (
		(exact_zero_rotation_variant as Quaternion).normalized()
		if uses_exact_solver_zero
		else (
			authoring_digit_hinge_neutral_rotation_lookup.get(
				bone_name,
				skeleton.get_bone_pose_rotation(bone_index)
			) as Quaternion
		).normalized()
	)
	var parent_pose: Transform3D = skeleton.get_bone_global_pose(parent_index)
	var neutral_skeleton_basis: Basis = (
		parent_pose.basis * Basis(neutral_local_rotation)
	).orthonormalized()
	var neutral_world_basis: Basis = (skeleton.global_basis * neutral_skeleton_basis).orthonormalized()
	var current_skeleton_pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
	var current_world_basis: Basis = (skeleton.global_basis * current_skeleton_pose.basis).orthonormalized()
	var joint_world: Vector3 = skeleton.to_global(current_skeleton_pose.origin)
	var hinge_axis_world: Vector3 = neutral_world_basis * hinge_axis_local
	if hinge_axis_world.length_squared() <= 0.000001:
		visual_root.visible = false
		return result
	hinge_axis_world = hinge_axis_world.normalized()
	var zero_direction_world: Vector3 = neutral_world_basis * zero_direction_local
	zero_direction_world -= hinge_axis_world * zero_direction_world.dot(hinge_axis_world)
	if zero_direction_world.length_squared() <= 0.000001:
		visual_root.visible = false
		return result
	zero_direction_world = zero_direction_world.normalized()
	var actual_direction_world: Vector3 = current_world_basis * zero_direction_local
	actual_direction_world -= hinge_axis_world * actual_direction_world.dot(hinge_axis_world)
	if actual_direction_world.length_squared() <= 0.000001:
		actual_direction_world = zero_direction_world
	else:
		actual_direction_world = actual_direction_world.normalized()
	var current_local_rotation: Quaternion = skeleton.get_bone_pose_rotation(bone_index).normalized()
	var current_local_delta: Quaternion = (
		neutral_local_rotation.inverse() * current_local_rotation
	).normalized()
	var current_hinge_rotation: Quaternion = _extract_quaternion_twist(current_local_delta, hinge_axis_local)
	var current_angle_degrees: float = rad_to_deg(
		_resolve_signed_twist_angle(current_hinge_rotation, hinge_axis_local)
	)
	var current_hinge_direction_world: Vector3 = (
		Basis(hinge_axis_world, deg_to_rad(current_angle_degrees)) * zero_direction_world
	).normalized()
	var actual_hinge_axis_world: Vector3 = (current_world_basis * hinge_axis_local).normalized()
	var axis_alignment_dot: float = clampf(hinge_axis_world.dot(actual_hinge_axis_world), -1.0, 1.0)
	var off_axis_degrees: float = rad_to_deg(acos(axis_alignment_dot))
	var status_color: Color = _resolve_joint_range_status_color(
		current_angle_degrees,
		min_angle_degrees,
		max_angle_degrees
	)
	var state_text: String = _resolve_joint_range_state_text(
		current_angle_degrees,
		min_angle_degrees,
		max_angle_degrees
	)
	var is_off_axis: bool = off_axis_degrees > AUTHORING_DIGIT_HINGE_OFF_AXIS_TOLERANCE_DEGREES
	if is_off_axis:
		status_color = Color(1.0, 0.12, 0.68, 0.98)
		state_text = "off_axis"
	var radius: float = _resolve_authoring_digit_range_radius(
		bone_index,
		next_bone_name,
		joint_world
	)
	visual_root.visible = true
	_update_joint_range_plane_mesh(
		visual_root,
		joint_world,
		zero_direction_world,
		hinge_axis_world,
		min_angle_degrees,
		max_angle_degrees,
		radius,
		base_color,
		true
	)
	_update_digit_hinge_range_line_mesh(
		visual_root,
		joint_world,
		hinge_axis_world,
		actual_hinge_axis_world,
		zero_direction_world,
		current_hinge_direction_world,
		actual_direction_world,
		min_angle_degrees,
		max_angle_degrees,
		current_angle_degrees,
		radius,
		status_color
	)
	_update_joint_range_label(
		visual_root,
		"%s OFF-AXIS" % label_text if is_off_axis else label_text,
		joint_world,
		zero_direction_world,
		hinge_axis_world,
		min_angle_degrees,
		max_angle_degrees,
		current_angle_degrees,
		radius,
		status_color,
		true,
		open_angle_degrees,
		closed_angle_degrees
	)
	result["visible"] = true
	result["angle_degrees"] = current_angle_degrees
	result["angle_delta_degrees"] = current_angle_degrees
	result["reference_pose"] = reference_pose
	result["hinge_axis_local"] = hinge_axis_local
	result["hinge_axis_origin_id"] = hinge_axis_origin_id
	result["zero_direction_local"] = zero_direction_local
	result["zero_direction_origin_id"] = zero_direction_origin_id
	result["hinge_axis_world"] = hinge_axis_world
	result["actual_hinge_axis_world"] = actual_hinge_axis_world
	result["zero_direction_world"] = zero_direction_world
	result["current_hinge_direction_world"] = current_hinge_direction_world
	result["actual_direction_world"] = actual_direction_world
	result["joint_world"] = joint_world
	result["neutral_local_rotation"] = neutral_local_rotation
	result["neutral_rotation_origin_id"] = bone_name
	result["axis_alignment_dot"] = axis_alignment_dot
	result["off_axis_degrees"] = off_axis_degrees
	result["off_axis_tolerance_degrees"] = AUTHORING_DIGIT_HINGE_OFF_AXIS_TOLERANCE_DEGREES
	result["visual_node_path"] = String(visual_root.get_path())
	result["state"] = state_text
	return result

func _resolve_authoring_digit_range_radius(
	bone_index: int,
	next_bone_name: StringName,
	joint_world: Vector3
) -> float:
	var segment_length: float = 0.0
	var next_bone_index: int = skeleton.find_bone(String(next_bone_name)) if next_bone_name != StringName() else -1
	if next_bone_index >= 0:
		segment_length = joint_world.distance_to(
			skeleton.to_global(skeleton.get_bone_global_pose(next_bone_index).origin)
		)
	if segment_length <= 0.000001:
		segment_length = skeleton.get_bone_rest(bone_index).origin.length()
	return clampf(
		segment_length * 0.72,
		AUTHORING_DIGIT_RANGE_MIN_RADIUS_METERS,
		AUTHORING_DIGIT_RANGE_MAX_RADIUS_METERS
	)

func _resolve_authoring_digit_range_color(
	slot_id: StringName,
	digit_id: StringName,
	section_index: int
) -> Color:
	var digit_bias_lookup := {
		&"thumb": 0.00,
		&"index": 0.04,
		&"middle": 0.08,
		&"ring": 0.12,
		&"pinky": 0.16,
	}
	var digit_bias: float = float(digit_bias_lookup.get(digit_id, 0.0))
	var section_bias: float = clampf(float(section_index - 1) * 0.035, 0.0, 0.07)
	if slot_id == &"hand_left":
		return Color(0.34 + section_bias, 0.48 + digit_bias, 1.0, 0.18)
	return Color(1.0, 0.42 + digit_bias, 0.12 + section_bias, 0.18)

func _update_digit_hinge_range_line_mesh(
	visual_root: Node3D,
	joint_world: Vector3,
	hinge_axis_world: Vector3,
	actual_hinge_axis_world: Vector3,
	zero_direction_world: Vector3,
	current_hinge_direction_world: Vector3,
	actual_direction_world: Vector3,
	min_angle_degrees: float,
	max_angle_degrees: float,
	current_angle_degrees: float,
	radius: float,
	status_color: Color
) -> void:
	var line_instance: MeshInstance3D = _ensure_debug_mesh_instance(visual_root, "BoundaryLines")
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var axis_color := Color(0.08, 0.92, 1.0, 0.96)
	var actual_axis_color := Color(0.88, 0.24, 1.0, 0.82)
	var zero_color := Color(0.96, 0.96, 0.96, 0.94)
	var min_color := Color(1.0, 0.28, 0.20, 0.98)
	var max_color := Color(0.22, 1.0, 0.42, 0.98)
	var actual_direction_color := Color(0.94, 0.28, 1.0, 0.88)
	var min_direction: Vector3 = (
		Basis(hinge_axis_world, deg_to_rad(min_angle_degrees)) * zero_direction_world
	).normalized()
	var max_direction: Vector3 = (
		Basis(hinge_axis_world, deg_to_rad(max_angle_degrees)) * zero_direction_world
	).normalized()
	_append_debug_line(
		vertices,
		colors,
		joint_world - hinge_axis_world * (radius * 0.48),
		joint_world + hinge_axis_world * (radius * 0.48),
		axis_color
	)
	if hinge_axis_world.dot(actual_hinge_axis_world) < 0.9995:
		_append_debug_line(
			vertices,
			colors,
			joint_world - actual_hinge_axis_world * (radius * 0.40),
			joint_world + actual_hinge_axis_world * (radius * 0.40),
			actual_axis_color
		)
	_append_debug_line(vertices, colors, joint_world, joint_world + zero_direction_world * (radius * 1.02), zero_color)
	_append_debug_line(vertices, colors, joint_world, joint_world + min_direction * (radius * 1.12), min_color)
	_append_debug_line(vertices, colors, joint_world, joint_world + max_direction * (radius * 1.12), max_color)
	_append_debug_line(vertices, colors, joint_world, joint_world + current_hinge_direction_world * (radius * 1.30), status_color)
	if current_hinge_direction_world.dot(actual_direction_world) < 0.9995:
		_append_debug_line(vertices, colors, joint_world, joint_world + actual_direction_world * (radius * 1.18), actual_direction_color)
	_append_debug_ring(
		vertices,
		colors,
		joint_world,
		zero_direction_world,
		hinge_axis_world,
		min_angle_degrees,
		max_angle_degrees,
		radius,
		Color(1.0, 1.0, 1.0, 0.84)
	)
	_append_debug_ring(
		vertices,
		colors,
		joint_world,
		zero_direction_world,
		hinge_axis_world,
		current_angle_degrees - 2.5,
		current_angle_degrees + 2.5,
		radius * 1.08,
		status_color
	)
	line_instance.mesh = _build_debug_array_mesh(
		Mesh.PRIMITIVE_LINES,
		vertices,
		colors,
		line_instance.mesh as ArrayMesh
	)
	line_instance.material_override = _build_debug_vertex_material(
		true,
		line_instance.material_override as StandardMaterial3D
	)
	line_instance.visible = true
	_update_debug_sphere_marker(visual_root, "HingeMinMarker", joint_world + min_direction * (radius * 1.12), radius * 0.085, min_color, 0.0015, true)
	_update_debug_sphere_marker(visual_root, "HingeMaxMarker", joint_world + max_direction * (radius * 1.12), radius * 0.085, max_color, 0.0015, true)
	_update_debug_sphere_marker(visual_root, "HingeCurrentMarker", joint_world + current_hinge_direction_world * (radius * 1.30), radius * 0.105, status_color, 0.0015, true)
	_update_debug_sphere_marker(visual_root, "HingePivotMarker", joint_world, radius * 0.070, axis_color, 0.0015, true)

func _ensure_named_node3d(parent: Node3D, node_name: String) -> Node3D:
	var node: Node3D = parent.get_node_or_null(node_name) as Node3D if parent != null else null
	if node == null:
		node = Node3D.new()
		node.name = node_name
		parent.add_child(node)
	return node

func _update_joint_range_plane_mesh(
	visual_root: Node3D,
	joint_world: Vector3,
	parent_dir: Vector3,
	plane_normal: Vector3,
	min_angle_degrees: float,
	max_angle_degrees: float,
	radius: float,
	base_color: Color,
	no_depth_test: bool = false
) -> void:
	var plane_instance: MeshInstance3D = _ensure_debug_mesh_instance(visual_root, "AllowedPlane")
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var plane_color: Color = base_color
	plane_color.a = clampf(base_color.a, 0.08, 0.35)
	for step_index: int in range(AUTHORING_JOINT_RANGE_ARC_STEPS):
		var ratio_a: float = float(step_index) / float(AUTHORING_JOINT_RANGE_ARC_STEPS)
		var ratio_b: float = float(step_index + 1) / float(AUTHORING_JOINT_RANGE_ARC_STEPS)
		var angle_a: float = deg_to_rad(lerpf(min_angle_degrees, max_angle_degrees, ratio_a))
		var angle_b: float = deg_to_rad(lerpf(min_angle_degrees, max_angle_degrees, ratio_b))
		vertices.append(joint_world)
		vertices.append(joint_world + (Basis(plane_normal, angle_a) * parent_dir).normalized() * radius)
		vertices.append(joint_world + (Basis(plane_normal, angle_b) * parent_dir).normalized() * radius)
		colors.append(plane_color)
		colors.append(plane_color)
		colors.append(plane_color)
	plane_instance.mesh = _build_debug_array_mesh(
		Mesh.PRIMITIVE_TRIANGLES,
		vertices,
		colors,
		plane_instance.mesh as ArrayMesh
	)
	plane_instance.material_override = _build_debug_vertex_material(
		no_depth_test,
		plane_instance.material_override as StandardMaterial3D
	)
	plane_instance.visible = true

func _update_joint_range_line_mesh(
	visual_root: Node3D,
	joint_world: Vector3,
	parent_world: Vector3,
	child_world: Vector3,
	parent_dir: Vector3,
	child_dir: Vector3,
	plane_normal: Vector3,
	min_angle_degrees: float,
	max_angle_degrees: float,
	radius: float,
	status_color: Color
) -> void:
	var line_instance: MeshInstance3D = _ensure_debug_mesh_instance(visual_root, "BoundaryLines")
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var parent_color := Color(0.92, 0.92, 0.92, 0.95)
	var child_color: Color = status_color
	var min_dir: Vector3 = (Basis(plane_normal, deg_to_rad(min_angle_degrees)) * parent_dir).normalized()
	var max_dir: Vector3 = (Basis(plane_normal, deg_to_rad(max_angle_degrees)) * parent_dir).normalized()
	_append_debug_line(vertices, colors, joint_world, parent_world, parent_color)
	_append_debug_line(vertices, colors, joint_world, child_world, child_color)
	_append_debug_line(vertices, colors, joint_world, joint_world + min_dir * radius, Color(1.0, 0.34, 0.26, 0.95))
	_append_debug_line(vertices, colors, joint_world, joint_world + max_dir * radius, Color(0.20, 0.95, 0.42, 0.95))
	_append_debug_line(vertices, colors, joint_world, joint_world + child_dir * (radius * 1.08), status_color)
	var previous_arc: Vector3 = joint_world + min_dir * radius
	for step_index: int in range(1, AUTHORING_JOINT_RANGE_ARC_STEPS + 1):
		var ratio: float = float(step_index) / float(AUTHORING_JOINT_RANGE_ARC_STEPS)
		var angle: float = deg_to_rad(lerpf(min_angle_degrees, max_angle_degrees, ratio))
		var arc_point: Vector3 = joint_world + (Basis(plane_normal, angle) * parent_dir).normalized() * radius
		_append_debug_line(vertices, colors, previous_arc, arc_point, Color(0.96, 0.96, 0.96, 0.68))
		previous_arc = arc_point
	line_instance.mesh = _build_debug_array_mesh(
		Mesh.PRIMITIVE_LINES,
		vertices,
		colors,
		line_instance.mesh as ArrayMesh
	)
	line_instance.material_override = _build_debug_vertex_material(
		false,
		line_instance.material_override as StandardMaterial3D
	)
	line_instance.visible = true

func _update_twist_range_rotation_mesh(
	visual_root: Node3D,
	twist_world: Vector3,
	axis_world: Vector3,
	neutral_reference_dir: Vector3,
	current_reference_dir: Vector3,
	min_angle_degrees: float,
	max_angle_degrees: float,
	current_angle_degrees: float,
	radius: float,
	status_color: Color
) -> void:
	var line_instance: MeshInstance3D = _ensure_debug_mesh_instance(visual_root, "BoundaryLines")
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var resolved_axis: Vector3 = axis_world.normalized()
	var resolved_neutral: Vector3 = neutral_reference_dir.normalized()
	var resolved_current: Vector3 = current_reference_dir.normalized()
	var min_dir: Vector3 = (Basis(resolved_axis, deg_to_rad(min_angle_degrees)) * resolved_neutral).normalized()
	var max_dir: Vector3 = (Basis(resolved_axis, deg_to_rad(max_angle_degrees)) * resolved_neutral).normalized()
	var current_dir: Vector3 = (Basis(resolved_axis, deg_to_rad(current_angle_degrees)) * resolved_neutral).normalized()
	if resolved_current.length_squared() > 0.000001:
		current_dir = resolved_current
	var axis_color := Color(0.08, 0.92, 1.0, 0.95)
	var zero_color := Color(0.96, 0.96, 0.96, 0.92)
	var min_color := Color(1.0, 0.28, 0.20, 0.96)
	var max_color := Color(0.22, 1.0, 0.42, 0.96)
	var faint_color := Color(0.95, 0.95, 0.95, 0.28)
	_append_debug_line(vertices, colors, twist_world - resolved_axis * (radius * 0.70), twist_world + resolved_axis * (radius * 0.70), axis_color)
	_append_debug_line(vertices, colors, twist_world, twist_world + resolved_neutral * (radius * 1.16), zero_color)
	_append_debug_line(vertices, colors, twist_world, twist_world + min_dir * (radius * 1.24), min_color)
	_append_debug_line(vertices, colors, twist_world, twist_world + max_dir * (radius * 1.24), max_color)
	_append_debug_line(vertices, colors, twist_world, twist_world + current_dir * (radius * 1.45), status_color)
	_append_debug_ring(vertices, colors, twist_world, resolved_neutral, resolved_axis, 0.0, 360.0, radius * 0.96, faint_color)
	_append_debug_ring(vertices, colors, twist_world, resolved_neutral, resolved_axis, min_angle_degrees, max_angle_degrees, radius * 1.10, Color(1.0, 1.0, 1.0, 0.78))
	_append_debug_ring(vertices, colors, twist_world, resolved_neutral, resolved_axis, current_angle_degrees - 4.0, current_angle_degrees + 4.0, radius * 1.18, status_color)
	line_instance.mesh = _build_debug_array_mesh(
		Mesh.PRIMITIVE_LINES,
		vertices,
		colors,
		line_instance.mesh as ArrayMesh
	)
	line_instance.material_override = _build_debug_vertex_material(
		false,
		line_instance.material_override as StandardMaterial3D
	)
	line_instance.visible = true
	_update_debug_sphere_marker(visual_root, "TwistMinMarker", twist_world + min_dir * (radius * 1.24), radius * 0.105, min_color)
	_update_debug_sphere_marker(visual_root, "TwistMaxMarker", twist_world + max_dir * (radius * 1.24), radius * 0.105, max_color)
	_update_debug_sphere_marker(visual_root, "TwistCurrentMarker", twist_world + current_dir * (radius * 1.45), radius * 0.14, status_color)
	_update_debug_sphere_marker(visual_root, "TwistAxisMarker", twist_world, radius * 0.075, axis_color)

func _update_joint_range_label(
	visual_root: Node3D,
	label_text: String,
	joint_world: Vector3,
	parent_dir: Vector3,
	plane_normal: Vector3,
	min_angle_degrees: float,
	max_angle_degrees: float,
	current_angle_degrees: float,
	radius: float,
	status_color: Color,
	angle_is_delta: bool = false,
	display_start_degrees: float = NAN,
	display_end_degrees: float = NAN
) -> void:
	var label: Label3D = visual_root.get_node_or_null("AngleLabel") as Label3D
	if not show_authoring_joint_range_labels:
		if label != null:
			label.visible = false
		return
	if label == null:
		label = Label3D.new()
		label.name = "AngleLabel"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 24
		label.pixel_size = 0.0028
		visual_root.add_child(label)
	var mid_angle: float = deg_to_rad((min_angle_degrees + max_angle_degrees) * 0.5)
	var label_dir: Vector3 = (Basis(plane_normal, mid_angle) * parent_dir).normalized()
	label.position = joint_world + label_dir * (radius * 1.12) + plane_normal * 0.018
	var angle_prefix: String = "delta " if angle_is_delta else ""
	var range_start_degrees: float = display_start_degrees if is_finite(display_start_degrees) else min_angle_degrees
	var range_end_degrees: float = display_end_degrees if is_finite(display_end_degrees) else max_angle_degrees
	if angle_is_delta:
		label.text = "%s %s%.0f | ROM %.0f..%.0f | close %.0f->%.0f" % [
			label_text,
			angle_prefix,
			current_angle_degrees,
			min_angle_degrees,
			max_angle_degrees,
			range_start_degrees,
			range_end_degrees,
		]
	else:
		label.text = "%s %.0f / %.0f-%.0f" % [
			label_text,
			current_angle_degrees,
			min_angle_degrees,
			max_angle_degrees,
		]
	label.modulate = status_color
	label.visible = true

func _append_debug_ring(
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	center_world: Vector3,
	reference_dir: Vector3,
	axis_world: Vector3,
	min_angle_degrees: float,
	max_angle_degrees: float,
	radius: float,
	color: Color
) -> void:
	var previous_point: Vector3 = center_world + (Basis(axis_world, deg_to_rad(min_angle_degrees)) * reference_dir).normalized() * radius
	for step_index: int in range(1, AUTHORING_JOINT_RANGE_ARC_STEPS + 1):
		var ratio: float = float(step_index) / float(AUTHORING_JOINT_RANGE_ARC_STEPS)
		var angle: float = deg_to_rad(lerpf(min_angle_degrees, max_angle_degrees, ratio))
		var arc_point: Vector3 = center_world + (Basis(axis_world, angle) * reference_dir).normalized() * radius
		_append_debug_line(vertices, colors, previous_point, arc_point, color)
		previous_point = arc_point

func _append_debug_line(
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	from_world: Vector3,
	to_world: Vector3,
	color: Color
) -> void:
	vertices.append(from_world)
	vertices.append(to_world)
	colors.append(color)
	colors.append(color)

func _update_debug_sphere_marker(
	parent: Node3D,
	marker_name: String,
	world_position: Vector3,
	radius: float,
	color: Color,
	minimum_radius: float = 0.004,
	no_depth_test: bool = false
) -> void:
	var marker: MeshInstance3D = _ensure_debug_mesh_instance(parent, marker_name)
	var sphere: SphereMesh = marker.mesh as SphereMesh
	if sphere == null:
		sphere = SphereMesh.new()
		sphere.radial_segments = 12
		sphere.rings = 6
		marker.mesh = sphere
	sphere.radius = maxf(radius, minimum_radius)
	sphere.height = maxf(radius * 2.0, minimum_radius * 2.0)
	var material: StandardMaterial3D = marker.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = no_depth_test
	marker.material_override = material
	marker.global_position = world_position
	marker.visible = true

func _build_debug_array_mesh(
	primitive: Mesh.PrimitiveType,
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	existing_mesh: ArrayMesh = null
) -> ArrayMesh:
	var mesh: ArrayMesh = existing_mesh if existing_mesh != null else ArrayMesh.new()
	mesh.clear_surfaces()
	if vertices.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(primitive, arrays)
	return mesh

func _ensure_debug_mesh_instance(parent: Node3D, instance_name: String) -> MeshInstance3D:
	var instance: MeshInstance3D = parent.get_node_or_null(instance_name) as MeshInstance3D
	if instance == null:
		instance = MeshInstance3D.new()
		instance.name = instance_name
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
	return instance

func _build_debug_vertex_material(
	no_depth_test: bool = false,
	existing_material: StandardMaterial3D = null
) -> StandardMaterial3D:
	var material: StandardMaterial3D = (
		existing_material if existing_material != null else StandardMaterial3D.new()
	)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = no_depth_test
	return material

func _resolve_joint_range_status_color(current_angle: float, min_angle: float, max_angle: float) -> Color:
	if current_angle < min_angle - AUTHORING_JOINT_RANGE_EPSILON_DEGREES or current_angle > max_angle + AUTHORING_JOINT_RANGE_EPSILON_DEGREES:
		return Color(1.0, 0.16, 0.12, 0.95)
	if current_angle <= min_angle + AUTHORING_JOINT_RANGE_WARNING_MARGIN_DEGREES:
		return Color(1.0, 0.74, 0.18, 0.95)
	if current_angle >= max_angle - AUTHORING_JOINT_RANGE_WARNING_MARGIN_DEGREES:
		return Color(1.0, 0.74, 0.18, 0.95)
	return Color(0.18, 1.0, 0.38, 0.95)

func _resolve_joint_range_state_text(current_angle: float, min_angle: float, max_angle: float) -> String:
	if current_angle < min_angle - AUTHORING_JOINT_RANGE_EPSILON_DEGREES:
		return "below_min"
	if current_angle > max_angle + AUTHORING_JOINT_RANGE_EPSILON_DEGREES:
		return "above_max"
	if current_angle <= min_angle + AUTHORING_JOINT_RANGE_WARNING_MARGIN_DEGREES:
		return "near_min"
	if current_angle >= max_angle - AUTHORING_JOINT_RANGE_WARNING_MARGIN_DEGREES:
		return "near_max"
	return "inside"

func _resolve_anatomical_contact_hand_basis_for_slot(
	slot_id: StringName,
	forearm_bone: StringName,
	hand_bone: StringName,
	contact_hand_basis_world: Basis
) -> Basis:
	var resolved_contact_basis: Basis = contact_hand_basis_world.orthonormalized()
	var contact_axis_local: Vector3 = resolve_hand_index_pinky_axis_local(slot_id)
	var locked_contact_axis_world: Vector3 = resolved_contact_basis * contact_axis_local
	if locked_contact_axis_world.length_squared() <= 0.000001:
		return resolved_contact_basis
	locked_contact_axis_world = locked_contact_axis_world.normalized()
	var y_reference_world: Vector3 = _resolve_hand_anatomical_axis_world(forearm_bone, hand_bone)
	if y_reference_world.length_squared() <= 0.000001:
		y_reference_world = resolved_contact_basis.y
	y_reference_world = y_reference_world - locked_contact_axis_world * y_reference_world.dot(locked_contact_axis_world)
	if y_reference_world.length_squared() <= 0.000001:
		var hand_index: int = skeleton.find_bone(String(hand_bone)) if skeleton != null else -1
		if hand_index >= 0:
			y_reference_world = _resolve_neutral_hand_world_basis(hand_index).y
			y_reference_world -= locked_contact_axis_world * y_reference_world.dot(locked_contact_axis_world)
	if y_reference_world.length_squared() <= 0.000001:
		y_reference_world = Vector3.UP - locked_contact_axis_world * Vector3.UP.dot(locked_contact_axis_world)
	if y_reference_world.length_squared() <= 0.000001:
		y_reference_world = Vector3.FORWARD - locked_contact_axis_world * Vector3.FORWARD.dot(locked_contact_axis_world)
	if y_reference_world.length_squared() <= 0.000001:
		return resolved_contact_basis
	return _build_basis_aligning_local_axis(contact_axis_local, locked_contact_axis_world, y_reference_world)

func _resolve_hand_anatomical_axis_world(forearm_bone: StringName, hand_bone: StringName) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var forearm_world: Vector3 = _get_bone_world_position(forearm_bone)
	var hand_world: Vector3 = _get_bone_world_position(hand_bone)
	var axis_world: Vector3 = hand_world - forearm_world
	if axis_world.length_squared() <= 0.000001:
		return Vector3.ZERO
	return axis_world.normalized()

func _apply_authoring_contact_wrist_straight_preference(
	hand_bone: StringName,
	desired_world_basis: Basis
) -> Basis:
	if skeleton == null:
		return desired_world_basis
	var straightness_bias: float = clampf(authoring_contact_wrist_straightness_bias, 0.0, 1.0)
	if straightness_bias <= 0.00001:
		return desired_world_basis
	var hand_index: int = skeleton.find_bone(String(hand_bone))
	if hand_index < 0:
		return desired_world_basis
	var neutral_world_basis: Basis = _resolve_neutral_hand_world_basis(hand_index)
	return _blend_contact_basis_roll_toward_reference(
		desired_world_basis,
		neutral_world_basis,
		straightness_bias
	)

func _blend_contact_basis_roll_toward_reference(
	desired_world_basis: Basis,
	reference_world_basis: Basis,
	blend: float
) -> Basis:
	var resolved_desired_basis: Basis = desired_world_basis.orthonormalized()
	var resolved_blend: float = clampf(blend, 0.0, 1.0)
	if resolved_blend <= 0.00001:
		return resolved_desired_basis
	var locked_anatomical_y_axis_world: Vector3 = resolved_desired_basis.y.normalized()
	if locked_anatomical_y_axis_world.length_squared() <= 0.000001:
		return resolved_desired_basis
	var desired_roll_reference: Vector3 = resolved_desired_basis.x - locked_anatomical_y_axis_world * resolved_desired_basis.x.dot(locked_anatomical_y_axis_world)
	var neutral_roll_reference: Vector3 = reference_world_basis.orthonormalized().x
	neutral_roll_reference = neutral_roll_reference - locked_anatomical_y_axis_world * neutral_roll_reference.dot(locked_anatomical_y_axis_world)
	if desired_roll_reference.length_squared() <= 0.000001 or neutral_roll_reference.length_squared() <= 0.000001:
		return resolved_desired_basis
	desired_roll_reference = desired_roll_reference.normalized()
	neutral_roll_reference = neutral_roll_reference.normalized()
	var roll_to_reference_radians: float = atan2(
		locked_anatomical_y_axis_world.dot(desired_roll_reference.cross(neutral_roll_reference)),
		clampf(desired_roll_reference.dot(neutral_roll_reference), -1.0, 1.0)
	)
	return (Basis(locked_anatomical_y_axis_world, roll_to_reference_radians * resolved_blend) * resolved_desired_basis).orthonormalized()

func _clamp_authoring_contact_wrist_twist(
	slot_id: StringName,
	hand_bone: StringName,
	forearm_bone: StringName,
	desired_world_basis: Basis
) -> Basis:
	if skeleton == null:
		return desired_world_basis
	var resolved_desired_basis: Basis = desired_world_basis.orthonormalized()
	var contact_axis_local: Vector3 = resolve_hand_index_pinky_axis_local(slot_id)
	var locked_contact_axis_world: Vector3 = resolved_desired_basis * contact_axis_local
	if locked_contact_axis_world.length_squared() <= 0.000001:
		return desired_world_basis
	locked_contact_axis_world = locked_contact_axis_world.normalized()
	var twist_limit_radians: float = deg_to_rad(clampf(authoring_contact_wrist_twist_limit_degrees, 0.0, 180.0))
	if twist_limit_radians >= PI - 0.0001:
		return desired_world_basis
	var hand_index: int = skeleton.find_bone(String(hand_bone))
	var forearm_index: int = skeleton.find_bone(String(forearm_bone))
	if hand_index < 0 or forearm_index < 0:
		return desired_world_basis
	var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand_index)
	var forearm_pose: Transform3D = skeleton.get_bone_global_pose(forearm_index)
	var twist_axis_world: Vector3 = skeleton.global_basis * (hand_pose.origin - forearm_pose.origin)
	if twist_axis_world.length_squared() <= 0.000001:
		return desired_world_basis
	twist_axis_world = twist_axis_world.normalized()
	var neutral_world_basis: Basis = _resolve_neutral_hand_world_basis(hand_index)
	var neutral_rotation: Quaternion = neutral_world_basis.get_rotation_quaternion().normalized()
	var desired_rotation: Quaternion = desired_world_basis.orthonormalized().get_rotation_quaternion().normalized()
	var desired_delta: Quaternion = (desired_rotation * neutral_rotation.inverse()).normalized()
	var desired_twist: Quaternion = _extract_quaternion_twist(desired_delta, twist_axis_world)
	var desired_swing: Quaternion = (desired_delta * desired_twist.inverse()).normalized()
	var clamped_twist_angle: float = clampf(
		_resolve_signed_twist_angle(desired_twist, twist_axis_world),
		-twist_limit_radians,
		twist_limit_radians
	)
	var clamped_twist: Quaternion = Quaternion(twist_axis_world, clamped_twist_angle).normalized()
	var clamped_delta: Quaternion = (desired_swing * clamped_twist).normalized()
	var clamped_basis: Basis = Basis((clamped_delta * neutral_rotation).normalized()).orthonormalized()
	return _build_basis_aligning_local_axis(contact_axis_local, locked_contact_axis_world, clamped_basis.y)

func _apply_authoring_limb_twist_distribution_for_slot(
	slot_id: StringName,
	forearm_bone: StringName,
	hand_bone: StringName,
	desired_world_basis: Basis,
	strength: float
) -> void:
	if not enable_authoring_limb_twist_distribution or skeleton == null:
		_record_authoring_limb_twist_state(slot_id, false, 0.0, 0.0, 0.0, 0)
		return
	if authoring_limb_twist_neutral_rotation_lookup.is_empty():
		_cache_authoring_limb_twist_neutral_pose()
	var requested_twist_radians: float = _resolve_authoring_contact_wrist_twist_angle(
		hand_bone,
		forearm_bone,
		desired_world_basis
	)
	if absf(requested_twist_radians) <= 0.0001:
		_record_authoring_limb_twist_state(slot_id, false, requested_twist_radians, 0.0, 0.0, 0)
		return
	var forearm_twist_bones: Array = _get_slot_forearm_twist_bones(slot_id)
	var upperarm_twist_bones: Array = _get_slot_upperarm_twist_bones(slot_id)
	var forearm_twist_count: int = _count_existing_bones(forearm_twist_bones)
	var upperarm_twist_count: int = _count_existing_bones(upperarm_twist_bones)
	if forearm_twist_count <= 0 and upperarm_twist_count <= 0:
		_record_authoring_limb_twist_state(slot_id, false, requested_twist_radians, 0.0, 0.0, 0)
		return
	var forearm_share: float = AUTHORING_LIMB_TWIST_FOREARM_SHARE
	var upperarm_share: float = AUTHORING_LIMB_TWIST_UPPERARM_SHARE
	if forearm_twist_count <= 0:
		forearm_share = 0.0
		upperarm_share = 1.0
	elif upperarm_twist_count <= 0:
		forearm_share = 1.0
		upperarm_share = 0.0
	var forearm_twist_radians: float = clampf(
		requested_twist_radians * forearm_share,
		-AUTHORING_LIMB_TWIST_LIMIT_RADIANS,
		AUTHORING_LIMB_TWIST_LIMIT_RADIANS
	)
	var upperarm_twist_radians: float = clampf(
		requested_twist_radians * upperarm_share,
		-AUTHORING_LIMB_TWIST_LIMIT_RADIANS,
		AUTHORING_LIMB_TWIST_LIMIT_RADIANS
	)
	var applied_count: int = 0
	if absf(forearm_twist_radians) > 0.0001:
		applied_count += _apply_authoring_twist_bone_chain(
			forearm_twist_bones,
			forearm_twist_radians,
			strength
		)
	if absf(upperarm_twist_radians) > 0.0001:
		applied_count += _apply_authoring_twist_bone_chain(
			upperarm_twist_bones,
			upperarm_twist_radians,
			strength
		)
	_record_authoring_limb_twist_state(
		slot_id,
		applied_count > 0,
		requested_twist_radians,
		forearm_twist_radians if forearm_twist_count > 0 else 0.0,
		upperarm_twist_radians if upperarm_twist_count > 0 else 0.0,
		applied_count
	)

func _resolve_authoring_contact_wrist_twist_angle(
	hand_bone: StringName,
	forearm_bone: StringName,
	desired_world_basis: Basis
) -> float:
	if skeleton == null:
		return 0.0
	var hand_index: int = skeleton.find_bone(String(hand_bone))
	var forearm_index: int = skeleton.find_bone(String(forearm_bone))
	if hand_index < 0 or forearm_index < 0:
		return 0.0
	var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand_index)
	var forearm_pose: Transform3D = skeleton.get_bone_global_pose(forearm_index)
	var twist_axis_world: Vector3 = skeleton.global_basis * (hand_pose.origin - forearm_pose.origin)
	if twist_axis_world.length_squared() <= 0.000001:
		return 0.0
	twist_axis_world = twist_axis_world.normalized()
	var neutral_rotation: Quaternion = _resolve_neutral_hand_world_basis(hand_index).get_rotation_quaternion().normalized()
	var desired_rotation: Quaternion = desired_world_basis.orthonormalized().get_rotation_quaternion().normalized()
	var desired_delta: Quaternion = (desired_rotation * neutral_rotation.inverse()).normalized()
	var desired_twist: Quaternion = _extract_quaternion_twist(desired_delta, twist_axis_world)
	return _resolve_signed_twist_angle(desired_twist, twist_axis_world)

func _apply_authoring_twist_bone_chain(
	twist_bones: Array,
	total_twist_radians: float,
	strength: float
) -> int:
	if skeleton == null or twist_bones.is_empty():
		return 0
	var existing_bones: Array[StringName] = []
	for twist_bone in twist_bones:
		var twist_bone_name: StringName = twist_bone as StringName
		if skeleton.find_bone(String(twist_bone_name)) >= 0:
			existing_bones.append(twist_bone_name)
	if existing_bones.is_empty():
		return 0
	var per_bone_twist_radians: float = total_twist_radians / float(existing_bones.size())
	var applied_count: int = 0
	for twist_bone_name: StringName in existing_bones:
		if _apply_authoring_twist_bone_local_axis(
			twist_bone_name,
			per_bone_twist_radians,
			strength
		):
			applied_count += 1
	return applied_count

func _apply_authoring_twist_bone_local_axis(
	twist_bone: StringName,
	twist_radians: float,
	strength: float
) -> bool:
	var twist_index: int = skeleton.find_bone(String(twist_bone)) if skeleton != null else -1
	if twist_index < 0:
		return false
	if not authoring_limb_twist_neutral_rotation_lookup.has(twist_bone):
		_cache_authoring_limb_twist_neutral_bone(twist_bone)
	var neutral_local_rotation: Quaternion = (
		authoring_limb_twist_neutral_rotation_lookup.get(twist_bone, Quaternion.IDENTITY)
		as Quaternion
	).normalized()
	var local_twist_axis: Vector3 = _resolve_authoring_limb_twist_local_axis(twist_bone)
	var local_twist: Quaternion = Quaternion(local_twist_axis, twist_radians).normalized()
	var desired_local_rotation: Quaternion = (neutral_local_rotation * local_twist).normalized()
	var current_local_rotation: Quaternion = skeleton.get_bone_pose_rotation(twist_index).normalized()
	skeleton.set_bone_pose_rotation(
		twist_index,
		current_local_rotation.slerp(desired_local_rotation, clampf(strength, 0.0, 1.0)).normalized()
	)
	return true

func _resolve_authoring_limb_twist_local_axis(_twist_bone: StringName = StringName()) -> Vector3:
	return AUTHORING_LIMB_TWIST_LOCAL_AXIS

func _record_authoring_limb_twist_state(
	slot_id: StringName,
	active: bool,
	requested_twist_radians: float,
	forearm_twist_radians: float,
	upperarm_twist_radians: float,
	applied_count: int
) -> void:
	authoring_limb_twist_distribution_state[slot_id] = {
		"active": active,
		"requested_degrees": rad_to_deg(requested_twist_radians),
		"forearm_applied_degrees": rad_to_deg(forearm_twist_radians),
		"upperarm_applied_degrees": rad_to_deg(upperarm_twist_radians),
		"applied_bone_count": applied_count,
	}

func _cache_authoring_limb_twist_neutral_pose() -> void:
	_clear_authoring_joint_range_debug_pose_snapshot()
	authoring_limb_twist_neutral_rotation_lookup.clear()
	for twist_bone in RIGHT_FOREARM_TWIST_BONES:
		_cache_authoring_limb_twist_neutral_bone(twist_bone)
	for twist_bone in LEFT_FOREARM_TWIST_BONES:
		_cache_authoring_limb_twist_neutral_bone(twist_bone)
	for twist_bone in RIGHT_UPPERARM_TWIST_BONES:
		_cache_authoring_limb_twist_neutral_bone(twist_bone)
	for twist_bone in LEFT_UPPERARM_TWIST_BONES:
		_cache_authoring_limb_twist_neutral_bone(twist_bone)

func _cache_authoring_limb_twist_neutral_bone(twist_bone: StringName) -> void:
	var twist_index: int = skeleton.find_bone(String(twist_bone)) if skeleton != null else -1
	if twist_index < 0:
		return
	authoring_limb_twist_neutral_rotation_lookup[twist_bone] = skeleton.get_bone_pose_rotation(twist_index).normalized()

func _cache_authoring_digit_hinge_neutral_pose() -> void:
	_clear_authoring_joint_range_debug_pose_snapshot()
	authoring_digit_hinge_neutral_rotation_lookup.clear()
	if skeleton == null:
		return
	for rule: Dictionary in PlayerDigitHingeRulesScript.get_all_rules():
		var bone_name: StringName = rule.get("bone", StringName()) as StringName
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		authoring_digit_hinge_neutral_rotation_lookup[bone_name] = (
			skeleton.get_bone_pose_rotation(bone_index).normalized()
		)

func _get_slot_forearm_twist_bones(slot_id: StringName) -> Array:
	return LEFT_FOREARM_TWIST_BONES if slot_id == &"hand_left" else RIGHT_FOREARM_TWIST_BONES

func _get_slot_upperarm_twist_bones(slot_id: StringName) -> Array:
	return LEFT_UPPERARM_TWIST_BONES if slot_id == &"hand_left" else RIGHT_UPPERARM_TWIST_BONES

func _count_existing_bones(bone_names: Array) -> int:
	if skeleton == null:
		return 0
	var existing_count: int = 0
	for bone_name in bone_names:
		if skeleton.find_bone(String(bone_name)) >= 0:
			existing_count += 1
	return existing_count

func _rebuild_contact_basis_from_locked_axis(locked_grip_axis_world: Vector3, preferred_up_world: Vector3) -> Basis:
	var z_axis: Vector3 = locked_grip_axis_world.normalized()
	if z_axis.length_squared() <= 0.000001:
		return Basis.IDENTITY
	var y_axis: Vector3 = preferred_up_world - z_axis * preferred_up_world.dot(z_axis)
	if y_axis.length_squared() <= 0.000001:
		y_axis = Vector3.UP - z_axis * Vector3.UP.dot(z_axis)
	if y_axis.length_squared() <= 0.000001:
		y_axis = Vector3.RIGHT - z_axis * Vector3.RIGHT.dot(z_axis)
	y_axis = y_axis.normalized()
	var x_axis: Vector3 = y_axis.cross(z_axis).normalized()
	if x_axis.length_squared() <= 0.000001:
		x_axis = Vector3.RIGHT
	y_axis = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()

func _rebuild_contact_basis_from_locked_y_axis(locked_y_axis_world: Vector3, preferred_x_world: Vector3) -> Basis:
	var y_axis: Vector3 = locked_y_axis_world.normalized()
	if y_axis.length_squared() <= 0.000001:
		return Basis.IDENTITY
	var x_axis: Vector3 = preferred_x_world - y_axis * preferred_x_world.dot(y_axis)
	if x_axis.length_squared() <= 0.000001:
		x_axis = Vector3.RIGHT - y_axis * Vector3.RIGHT.dot(y_axis)
	if x_axis.length_squared() <= 0.000001:
		x_axis = Vector3.FORWARD - y_axis * Vector3.FORWARD.dot(y_axis)
	if x_axis.length_squared() <= 0.000001:
		return Basis.IDENTITY
	x_axis = x_axis.normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	if z_axis.length_squared() <= 0.000001:
		return Basis.IDENTITY
	x_axis = y_axis.cross(z_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()

func _rebuild_contact_basis_from_locked_x_axis(locked_x_axis_world: Vector3, preferred_y_world: Vector3) -> Basis:
	var x_axis: Vector3 = locked_x_axis_world.normalized()
	if x_axis.length_squared() <= 0.000001:
		return Basis.IDENTITY
	var y_axis: Vector3 = preferred_y_world - x_axis * preferred_y_world.dot(x_axis)
	if y_axis.length_squared() <= 0.000001:
		y_axis = Vector3.UP - x_axis * Vector3.UP.dot(x_axis)
	if y_axis.length_squared() <= 0.000001:
		y_axis = Vector3.FORWARD - x_axis * Vector3.FORWARD.dot(x_axis)
	if y_axis.length_squared() <= 0.000001:
		return Basis.IDENTITY
	y_axis = y_axis.normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	if z_axis.length_squared() <= 0.000001:
		return Basis.IDENTITY
	y_axis = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()

func _build_basis_aligning_local_axis(local_axis: Vector3, target_axis: Vector3, up_reference: Vector3) -> Basis:
	var source_axis: Vector3 = local_axis.normalized()
	var resolved_target_axis: Vector3 = target_axis.normalized()
	if source_axis.length_squared() <= 0.000001 or resolved_target_axis.length_squared() <= 0.000001:
		return Basis.IDENTITY
	var rotation_axis: Vector3 = source_axis.cross(resolved_target_axis)
	var rotation_angle: float = 0.0
	if rotation_axis.length_squared() <= 0.000001:
		if source_axis.dot(resolved_target_axis) < 0.0:
			rotation_axis = _resolve_perpendicular_axis(source_axis, up_reference)
			rotation_angle = PI
		else:
			return Basis.IDENTITY
	else:
		rotation_axis = rotation_axis.normalized()
		rotation_angle = source_axis.angle_to(resolved_target_axis)
	var aligned_basis: Basis = Basis(rotation_axis, rotation_angle).orthonormalized()
	var aligned_up: Vector3 = aligned_basis * Vector3.UP
	var roll_correction_axis: Vector3 = resolved_target_axis
	var projected_current_up: Vector3 = aligned_up - roll_correction_axis * aligned_up.dot(roll_correction_axis)
	var projected_target_up: Vector3 = up_reference - roll_correction_axis * up_reference.dot(roll_correction_axis)
	if projected_current_up.length_squared() > 0.000001 and projected_target_up.length_squared() > 0.000001:
		projected_current_up = projected_current_up.normalized()
		projected_target_up = projected_target_up.normalized()
		var roll_angle: float = atan2(
			roll_correction_axis.dot(projected_current_up.cross(projected_target_up)),
			clampf(projected_current_up.dot(projected_target_up), -1.0, 1.0)
		)
		aligned_basis = (Basis(roll_correction_axis, roll_angle) * aligned_basis).orthonormalized()
	return aligned_basis

func _resolve_perpendicular_axis(axis: Vector3, preferred_axis: Vector3) -> Vector3:
	var resolved_axis: Vector3 = axis.normalized()
	var resolved_preferred: Vector3 = preferred_axis - resolved_axis * preferred_axis.dot(resolved_axis)
	if resolved_preferred.length_squared() > 0.000001:
		return resolved_preferred.normalized()
	resolved_preferred = Vector3.UP - resolved_axis * Vector3.UP.dot(resolved_axis)
	if resolved_preferred.length_squared() > 0.000001:
		return resolved_preferred.normalized()
	resolved_preferred = Vector3.RIGHT - resolved_axis * Vector3.RIGHT.dot(resolved_axis)
	if resolved_preferred.length_squared() > 0.000001:
		return resolved_preferred.normalized()
	resolved_preferred = Vector3.FORWARD - resolved_axis * Vector3.FORWARD.dot(resolved_axis)
	return resolved_preferred.normalized() if resolved_preferred.length_squared() > 0.000001 else Vector3.UP

func _resolve_neutral_hand_world_basis(hand_index: int) -> Basis:
	var parent_index: int = skeleton.get_bone_parent(hand_index)
	var neutral_skeleton_basis: Basis = skeleton.get_bone_global_pose(hand_index).basis
	if parent_index >= 0:
		var parent_pose: Transform3D = skeleton.get_bone_global_pose(parent_index)
		var hand_rest: Transform3D = skeleton.get_bone_rest(hand_index)
		neutral_skeleton_basis = (parent_pose.basis * hand_rest.basis).orthonormalized()
	return (skeleton.global_basis * neutral_skeleton_basis).orthonormalized()

func _get_bone_global_rest_transform(bone_index: int) -> Transform3D:
	if skeleton == null or bone_index < 0:
		return Transform3D.IDENTITY
	var rest_transform: Transform3D = skeleton.get_bone_rest(bone_index)
	var parent_index: int = skeleton.get_bone_parent(bone_index)
	if parent_index < 0:
		return rest_transform
	return _get_bone_global_rest_transform(parent_index) * rest_transform

func _extract_quaternion_twist(source_rotation: Quaternion, twist_axis_world: Vector3) -> Quaternion:
	var resolved_rotation: Quaternion = source_rotation.normalized()
	if resolved_rotation.w < 0.0:
		resolved_rotation = Quaternion(
			-resolved_rotation.x,
			-resolved_rotation.y,
			-resolved_rotation.z,
			-resolved_rotation.w
		)
	var vector_part := Vector3(resolved_rotation.x, resolved_rotation.y, resolved_rotation.z)
	var projected_vector: Vector3 = twist_axis_world.normalized() * vector_part.dot(twist_axis_world.normalized())
	if projected_vector.length_squared() <= 0.00000001 and absf(resolved_rotation.w) <= 0.00000001:
		return Quaternion.IDENTITY
	return Quaternion(
		projected_vector.x,
		projected_vector.y,
		projected_vector.z,
		resolved_rotation.w
	).normalized()

func _resolve_signed_twist_angle(twist_rotation: Quaternion, twist_axis_world: Vector3) -> float:
	var resolved_twist: Quaternion = twist_rotation.normalized()
	if resolved_twist.w < 0.0:
		resolved_twist = Quaternion(
			-resolved_twist.x,
			-resolved_twist.y,
			-resolved_twist.z,
			-resolved_twist.w
		)
	var vector_part := Vector3(resolved_twist.x, resolved_twist.y, resolved_twist.z)
	var unsigned_angle: float = 2.0 * atan2(vector_part.length(), resolved_twist.w)
	var angle_sign: float = 1.0
	if vector_part.dot(twist_axis_world.normalized()) < 0.0:
		angle_sign = -1.0
	return unsigned_angle * angle_sign

func _apply_bone_world_basis(bone_name: StringName, desired_world_basis: Basis, strength: float) -> void:
	var bone_index: int = skeleton.find_bone(String(bone_name)) if skeleton != null else -1
	if bone_index < 0:
		return
	var parent_index: int = skeleton.get_bone_parent(bone_index)
	if parent_index < 0:
		return
	var parent_pose: Transform3D = skeleton.get_bone_global_pose(parent_index)
	var current_local_rotation: Quaternion = skeleton.get_bone_pose_rotation(bone_index).normalized()
	var desired_skeleton_basis: Basis = (skeleton.global_basis.inverse() * desired_world_basis).orthonormalized()
	var desired_local_basis: Basis = (parent_pose.basis.inverse() * desired_skeleton_basis).orthonormalized()
	var desired_local_rotation: Quaternion = desired_local_basis.get_rotation_quaternion().normalized()
	skeleton.set_bone_pose_rotation(
		bone_index,
		current_local_rotation.slerp(desired_local_rotation, clampf(strength, 0.0, 1.0)).normalized()
	)

func _apply_ccd_arm_reach_pose(
	upperarm_bone: StringName,
	forearm_bone: StringName,
	hand_bone: StringName,
	target_world: Vector3,
	solve_iterations: int = AUTHORING_DIRECT_ARM_SOLVE_ITERATIONS,
	forearm_weight: float = AUTHORING_DIRECT_ARM_FOREARM_WEIGHT,
	upperarm_weight: float = AUTHORING_DIRECT_ARM_UPPERARM_WEIGHT,
	clavicle_bone: StringName = StringName(),
	clavicle_weight: float = AUTHORING_DIRECT_ARM_CLAVICLE_WEIGHT,
	solve_epsilon_meters: float = AUTHORING_DIRECT_ARM_SOLVE_EPSILON_METERS
) -> void:
	if skeleton == null:
		return
	var target_local: Vector3 = skeleton.to_local(target_world)
	for _iteration_index: int in range(maxi(solve_iterations, 0)):
		if (
			_resolve_bone_local_position(hand_bone).distance_to(target_local)
			<= maxf(solve_epsilon_meters, 0.0)
		):
			return
		_rotate_bone_toward_end_target(
			forearm_bone,
			hand_bone,
			target_local,
			forearm_weight
		)
		_rotate_bone_toward_end_target(
			upperarm_bone,
			hand_bone,
			target_local,
			upperarm_weight
		)
		if clavicle_bone != StringName() and clavicle_weight > 0.00001:
			_rotate_bone_toward_end_target(
				clavicle_bone,
				hand_bone,
				target_local,
				clavicle_weight
			)

func _enforce_authoring_elbow_max_angle(
	upperarm_bone: StringName,
	forearm_bone: StringName,
	hand_bone: StringName
) -> void:
	if skeleton == null:
		return
	var max_angle_degrees: float = clampf(authoring_elbow_max_plane_angle_degrees, 1.0, 179.0)
	var upperarm_local: Vector3 = _resolve_bone_local_position(upperarm_bone)
	var forearm_local: Vector3 = _resolve_bone_local_position(forearm_bone)
	var hand_local: Vector3 = _resolve_bone_local_position(hand_bone)
	var elbow_to_upperarm: Vector3 = upperarm_local - forearm_local
	var elbow_to_hand: Vector3 = hand_local - forearm_local
	var hand_distance: float = elbow_to_hand.length()
	if elbow_to_upperarm.length_squared() <= 0.000001 or hand_distance <= 0.000001:
		return
	var upperarm_dir: Vector3 = elbow_to_upperarm.normalized()
	var hand_dir: Vector3 = elbow_to_hand.normalized()
	var current_angle_degrees: float = rad_to_deg(acos(clampf(upperarm_dir.dot(hand_dir), -1.0, 1.0)))
	if current_angle_degrees <= max_angle_degrees + AUTHORING_JOINT_RANGE_EPSILON_DEGREES:
		return
	var bend_axis: Vector3 = upperarm_dir.cross(hand_dir)
	if bend_axis.length_squared() <= 0.000001:
		bend_axis = upperarm_dir.cross(Vector3.FORWARD)
	if bend_axis.length_squared() <= 0.000001:
		bend_axis = upperarm_dir.cross(Vector3.UP)
	if bend_axis.length_squared() <= 0.000001:
		return
	bend_axis = bend_axis.normalized()
	var target_hand_dir: Vector3 = (Basis(bend_axis, deg_to_rad(max_angle_degrees)) * upperarm_dir).normalized()
	var target_hand_local: Vector3 = forearm_local + target_hand_dir * hand_distance
	_rotate_bone_toward_end_target(
		forearm_bone,
		hand_bone,
		target_hand_local,
		1.0
	)

func _apply_authoring_arm_spline_preference(
	slot_id: StringName,
	clavicle_bone: StringName,
	upperarm_bone: StringName,
	forearm_bone: StringName,
	hand_bone: StringName,
	hand_anchor: Node3D,
	contact_axis_bias: float = AUTHORING_ARM_SPLINE_CONTACT_AXIS_BIAS
) -> void:
	if skeleton == null:
		return
	var contact_axis_world: Vector3 = _resolve_authoring_contact_axis_world(
		slot_id,
		forearm_bone,
		hand_bone,
		hand_anchor
	)
	if contact_axis_world.length_squared() <= 0.000001:
		return
	var clavicle_world: Vector3 = _get_bone_world_position(clavicle_bone)
	var upperarm_world: Vector3 = _get_bone_world_position(upperarm_bone)
	var forearm_world: Vector3 = _get_bone_world_position(forearm_bone)
	var hand_world: Vector3 = _get_bone_world_position(hand_bone)
	var current_wrist_axis_world: Vector3 = hand_world - forearm_world
	if current_wrist_axis_world.length_squared() <= 0.000001:
		return
	var current_wrist_axis_normalized: Vector3 = current_wrist_axis_world.normalized()
	var preferred_wrist_axis_world: Vector3 = current_wrist_axis_normalized.lerp(
		contact_axis_world,
		clampf(contact_axis_bias, 0.0, 1.0)
	)
	if preferred_wrist_axis_world.length_squared() <= 0.000001:
		preferred_wrist_axis_world = current_wrist_axis_normalized
	else:
		preferred_wrist_axis_world = preferred_wrist_axis_world.normalized()
	var wrist_length: float = current_wrist_axis_world.length()
	var preferred_forearm_world: Vector3 = hand_world - preferred_wrist_axis_world * wrist_length
	var spline_forearm_world: Vector3 = _sample_cubic_bezier_3d(
		clavicle_world,
		upperarm_world,
		preferred_forearm_world,
		hand_world,
		0.72
	)
	preferred_forearm_world = preferred_forearm_world.lerp(spline_forearm_world, 0.25)
	var clavicle_to_preferred_forearm: Vector3 = preferred_forearm_world - clavicle_world
	var preferred_upperarm_world: Vector3 = upperarm_world
	if clavicle_to_preferred_forearm.length_squared() > 0.000001:
		preferred_upperarm_world = clavicle_world + clavicle_to_preferred_forearm.normalized() * maxf(clavicle_world.distance_to(upperarm_world), 0.000001)
	_rotate_bone_toward_end_target(
		clavicle_bone,
		upperarm_bone,
		skeleton.to_local(preferred_upperarm_world),
		AUTHORING_ARM_SPLINE_CLAVICLE_WEIGHT
	)
	_rotate_bone_toward_end_target(
		upperarm_bone,
		forearm_bone,
		skeleton.to_local(preferred_forearm_world),
		AUTHORING_ARM_SPLINE_UPPERARM_WEIGHT
	)
	forearm_world = _get_bone_world_position(forearm_bone)
	var forearm_axis_target_world: Vector3 = forearm_world + preferred_wrist_axis_world * wrist_length
	_rotate_bone_toward_end_target(
		forearm_bone,
		hand_bone,
		skeleton.to_local(forearm_axis_target_world),
		AUTHORING_ARM_SPLINE_FOREARM_WEIGHT
	)
	skeleton.force_update_all_bone_transforms()


func _resolve_authoring_contact_axis_world(
	slot_id: StringName,
	forearm_bone: StringName,
	hand_bone: StringName,
	hand_anchor: Node3D
) -> Vector3:
	if (
		skeleton == null
		or not authoring_contact_anchor_basis_lookup.has(slot_id)
		or hand_anchor == null
		or not is_instance_valid(hand_anchor)
	):
		return Vector3.ZERO
	var desired_anchor_basis_world: Basis = authoring_contact_anchor_basis_lookup.get(
		slot_id,
		Basis.IDENTITY
	) as Basis
	var anchor_local_basis: Basis = hand_anchor.transform.basis.orthonormalized()
	var desired_hand_basis_world: Basis = (
		desired_anchor_basis_world * anchor_local_basis.inverse()
	).orthonormalized()
	var contact_axis_world: Vector3 = desired_hand_basis_world.y.normalized()
	var current_wrist_axis_world: Vector3 = (
		_get_bone_world_position(hand_bone)
		- _get_bone_world_position(forearm_bone)
	)
	if (
		contact_axis_world.length_squared() <= 0.000001
		or current_wrist_axis_world.length_squared() <= 0.000001
	):
		return Vector3.ZERO
	current_wrist_axis_world = current_wrist_axis_world.normalized()
	if current_wrist_axis_world.dot(contact_axis_world) < 0.0:
		contact_axis_world = -contact_axis_world
	return contact_axis_world.normalized()


func _resolve_authoring_contact_axis_error_degrees(
	slot_id: StringName,
	forearm_bone: StringName,
	hand_bone: StringName,
	hand_anchor: Node3D
) -> float:
	var desired_axis_world: Vector3 = _resolve_authoring_contact_axis_world(
		slot_id,
		forearm_bone,
		hand_bone,
		hand_anchor
	)
	var current_axis_world: Vector3 = (
		_get_bone_world_position(hand_bone)
		- _get_bone_world_position(forearm_bone)
	)
	if (
		desired_axis_world.length_squared() <= 0.000001
		or current_axis_world.length_squared() <= 0.000001
	):
		return INF
	return rad_to_deg(acos(clampf(
		current_axis_world.normalized().dot(desired_axis_world),
		-1.0,
		1.0
	)))

func _apply_authoring_manual_upperarm_roll_pose(
	slot_id: StringName,
	upperarm_bone: StringName,
	forearm_bone: StringName,
	hand_bone: StringName
) -> void:
	if skeleton == null:
		return
	var roll_degrees: float = _resolve_authoring_manual_upperarm_roll_degrees(slot_id)
	if absf(roll_degrees) <= 0.0001:
		return
	var shoulder_world: Vector3 = _get_bone_world_position(upperarm_bone)
	var elbow_world: Vector3 = _get_bone_world_position(forearm_bone)
	var hand_world: Vector3 = _get_bone_world_position(hand_bone)
	var shoulder_to_hand: Vector3 = hand_world - shoulder_world
	if shoulder_to_hand.length_squared() <= 0.000001:
		return
	var roll_axis_world: Vector3 = shoulder_to_hand.normalized()
	var shoulder_to_elbow: Vector3 = elbow_world - shoulder_world
	var parallel_world: Vector3 = roll_axis_world * shoulder_to_elbow.dot(roll_axis_world)
	var radial_world: Vector3 = shoulder_to_elbow - parallel_world
	if radial_world.length_squared() <= 0.000001:
		radial_world = _resolve_authoring_upperarm_roll_reference_world(slot_id, roll_axis_world) * maxf(shoulder_to_elbow.length(), 0.05)
	if radial_world.length_squared() <= 0.000001:
		return
	var reference_world: Vector3 = _resolve_authoring_upperarm_roll_reference_world(slot_id, roll_axis_world)
	if reference_world.length_squared() <= 0.000001:
		return
	var current_angle: float = _resolve_signed_planar_angle(reference_world, radial_world.normalized(), roll_axis_world)
	var target_angle: float = deg_to_rad(clampf(roll_degrees, -180.0, 180.0))
	var correction_angle: float = _wrap_angle_radians(target_angle - current_angle)
	if absf(correction_angle) <= 0.0001:
		return
	var desired_radial_world: Vector3 = Basis(roll_axis_world, correction_angle) * radial_world
	var desired_elbow_world: Vector3 = shoulder_world + parallel_world + desired_radial_world
	_rotate_bone_toward_end_target(
		upperarm_bone,
		forearm_bone,
		skeleton.to_local(desired_elbow_world),
		1.0
	)
	_rotate_bone_toward_end_target(
		forearm_bone,
		hand_bone,
		skeleton.to_local(hand_world),
		1.0
	)
	skeleton.force_update_all_bone_transforms()


func _enforce_authoring_upperarm_swing_authority(
	slot_id: StringName,
	clavicle_bone: StringName,
	upperarm_bone: StringName,
	forearm_bone: StringName,
	hand_bone: StringName
) -> void:
	if skeleton == null:
		return
	var clavicle_index: int = skeleton.find_bone(String(clavicle_bone))
	var upperarm_index: int = skeleton.find_bone(String(upperarm_bone))
	var forearm_index: int = skeleton.find_bone(String(forearm_bone))
	var hand_index: int = skeleton.find_bone(String(hand_bone))
	if clavicle_index < 0 or upperarm_index < 0 or forearm_index < 0 or hand_index < 0:
		return
	if (
		skeleton.get_bone_parent(upperarm_index) != clavicle_index
		or skeleton.get_bone_parent(forearm_index) != upperarm_index
	):
		return

	# Shoulder authority is a two-axis swing in the actual side's Clavicle-local
	# frame. The main Upperarm carries no independent longitudinal roll; that job
	# belongs to the dedicated UpperarmTwist chain. Preserve the already-solved
	# shoulder-to-elbow direction, then rebuild a pure swing from this bone's own
	# rest frame instead of mirroring the opposite side.
	var upperarm_pose_before: Transform3D = skeleton.get_bone_global_pose(upperarm_index)
	var forearm_pose_before: Transform3D = skeleton.get_bone_global_pose(forearm_index)
	var hand_position_before: Vector3 = skeleton.get_bone_global_pose(hand_index).origin
	var shoulder_to_elbow_skeleton: Vector3 = (
		forearm_pose_before.origin - upperarm_pose_before.origin
	)
	if shoulder_to_elbow_skeleton.length_squared() <= 0.000001:
		return

	var clavicle_pose: Transform3D = skeleton.get_bone_global_pose(clavicle_index)
	var upperarm_rest_basis_parent: Basis = (
		skeleton.get_bone_rest(upperarm_index).basis.orthonormalized()
	)
	var solved_direction_parent: Vector3 = (
		clavicle_pose.basis.orthonormalized().inverse()
		* shoulder_to_elbow_skeleton.normalized()
	).normalized()
	var solved_direction_neutral: Vector3 = (
		upperarm_rest_basis_parent.inverse() * solved_direction_parent
	).normalized()
	if solved_direction_neutral.length_squared() <= 0.000001:
		return

	var polar_radians: float = acos(clampf(solved_direction_neutral.y, -1.0, 1.0))
	var swing_rotation: Quaternion = Quaternion.IDENTITY
	if polar_radians > 0.000001:
		var swing_axis_neutral: Vector3 = Vector3.UP.cross(solved_direction_neutral)
		if swing_axis_neutral.length_squared() <= 0.000001:
			# Exact rest-opposite is the only ambiguous swing. Keep the documented
			# right 0..+180 and left 0..-180 conventions explicit and deterministic.
			swing_axis_neutral = Vector3.BACK
		else:
			swing_axis_neutral = swing_axis_neutral.normalized()
		if slot_id == &"hand_left":
			swing_axis_neutral = -swing_axis_neutral
			polar_radians = -polar_radians
		swing_rotation = Quaternion(swing_axis_neutral, polar_radians).normalized()

	var desired_upperarm_basis_parent: Basis = (
		upperarm_rest_basis_parent * Basis(swing_rotation)
	).orthonormalized()
	var desired_upperarm_basis_skeleton: Basis = (
		clavicle_pose.basis.orthonormalized() * desired_upperarm_basis_parent
	).orthonormalized()
	var restored_forearm_basis_parent: Basis = (
		desired_upperarm_basis_skeleton.inverse()
		* forearm_pose_before.basis.orthonormalized()
	).orthonormalized()
	skeleton.set_bone_pose_rotation(
		upperarm_index,
		desired_upperarm_basis_parent.get_rotation_quaternion().normalized()
	)
	# Removing Upperarm roll changes every descendant basis. Restore the solved
	# Forearm world orientation under the corrected parent so the existing hand
	# target and grip shell do not orbit around the humerus. Both local rotations
	# are written before one skeleton refresh, keeping this an atomic pose update.
	skeleton.set_bone_pose_rotation(
		forearm_index,
		restored_forearm_basis_parent.get_rotation_quaternion().normalized()
	)
	skeleton.force_update_all_bone_transforms()

	# The imported arm segments are longitudinal +Y, so the basis transaction
	# normally preserves the endpoint exactly. A Forearm-only reseat handles any
	# sub-millimetre bind-axis deviation without granting Upperarm another writer.
	if (
		skeleton.get_bone_global_pose(hand_index).origin.distance_to(hand_position_before)
		> AUTHORING_SHOULDER_ENDPOINT_RESEAT_EPSILON_METERS
	):
		_rotate_bone_toward_end_target(
			forearm_bone,
			hand_bone,
			hand_position_before,
			1.0
		)


func _resolve_authoring_manual_upperarm_roll_degrees(slot_id: StringName) -> float:
	if upper_body_authoring_state.is_empty():
		return 0.0
	if slot_id == &"hand_left":
		return clampf(float(upper_body_authoring_state.get("left_upperarm_roll_degrees", 0.0)), -180.0, 180.0)
	return clampf(float(upper_body_authoring_state.get("right_upperarm_roll_degrees", 0.0)), -180.0, 180.0)

func _resolve_authoring_upperarm_roll_reference_world(slot_id: StringName, roll_axis_world: Vector3) -> Vector3:
	var side_reference_world: Vector3 = -global_basis.x if slot_id == &"hand_left" else global_basis.x
	var reference_world: Vector3 = side_reference_world - roll_axis_world * side_reference_world.dot(roll_axis_world)
	if reference_world.length_squared() <= 0.000001:
		reference_world = global_basis.y - roll_axis_world * global_basis.y.dot(roll_axis_world)
	if reference_world.length_squared() <= 0.000001:
		reference_world = global_basis.z - roll_axis_world * global_basis.z.dot(roll_axis_world)
	if reference_world.length_squared() <= 0.000001:
		return Vector3.ZERO
	return reference_world.normalized()

func _resolve_signed_planar_angle(from_direction: Vector3, to_direction: Vector3, axis: Vector3) -> float:
	if from_direction.length_squared() <= 0.000001 or to_direction.length_squared() <= 0.000001 or axis.length_squared() <= 0.000001:
		return 0.0
	var resolved_from: Vector3 = from_direction.normalized()
	var resolved_to: Vector3 = to_direction.normalized()
	var resolved_axis: Vector3 = axis.normalized()
	return atan2(
		resolved_axis.dot(resolved_from.cross(resolved_to)),
		clampf(resolved_from.dot(resolved_to), -1.0, 1.0)
	)

func _wrap_angle_radians(angle: float) -> float:
	return atan2(sin(angle), cos(angle))

func _sample_cubic_bezier_3d(start: Vector3, control_a: Vector3, control_b: Vector3, end: Vector3, ratio: float) -> Vector3:
	var t: float = clampf(ratio, 0.0, 1.0)
	var inv_t: float = 1.0 - t
	return start * inv_t * inv_t * inv_t \
		+ control_a * 3.0 * inv_t * inv_t * t \
		+ control_b * 3.0 * inv_t * t * t \
		+ end * t * t * t

func _rotate_bone_toward_end_target(
	joint_bone: StringName,
	end_bone: StringName,
	target_local: Vector3,
	rotation_weight: float
) -> void:
	var joint_index: int = skeleton.find_bone(String(joint_bone)) if skeleton != null else -1
	var end_index: int = skeleton.find_bone(String(end_bone)) if skeleton != null else -1
	if joint_index < 0 or end_index < 0:
		return
	var joint_pose: Transform3D = skeleton.get_bone_global_pose(joint_index)
	var end_pose: Transform3D = skeleton.get_bone_global_pose(end_index)
	var current_vector: Vector3 = end_pose.origin - joint_pose.origin
	var target_vector: Vector3 = target_local - joint_pose.origin
	if current_vector.length_squared() <= 0.000001 or target_vector.length_squared() <= 0.000001:
		return
	var swing_rotation: Quaternion = Quaternion(
		current_vector.normalized(),
		target_vector.normalized()
	).normalized()
	var weighted_rotation: Quaternion = Quaternion.IDENTITY.slerp(
		swing_rotation,
		clampf(rotation_weight, 0.0, 1.0)
	).normalized()
	var desired_global_basis: Basis = (Basis(weighted_rotation) * joint_pose.basis).orthonormalized()
	var parent_index: int = skeleton.get_bone_parent(joint_index)
	var desired_local_basis: Basis = desired_global_basis
	if parent_index >= 0:
		var parent_pose: Transform3D = skeleton.get_bone_global_pose(parent_index)
		desired_local_basis = (parent_pose.basis.inverse() * desired_global_basis).orthonormalized()
	skeleton.set_bone_pose_rotation(
		joint_index,
		desired_local_basis.get_rotation_quaternion().normalized()
	)
	skeleton.force_update_all_bone_transforms()

func _resolve_bone_local_position(bone_name: StringName) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var bone_index: int = skeleton.find_bone(String(bone_name))
	if bone_index < 0:
		return Vector3.ZERO
	return skeleton.get_bone_global_pose(bone_index).origin

func _apply_target_height_scale() -> void:
	resolved_visual_height_meters = rig_model_presenter.apply_target_height_scale(
		josie_model,
		mesh_instance,
		standing_height_meters
	)

func _ensure_hand_attachment(
		attachment_name: String,
		bone_name: StringName,
		anchor_name: String,
		anchor_position: Vector3,
		anchor_rotation_degrees: Vector3
	) -> void:
	rig_model_presenter.ensure_hand_attachment(
		skeleton,
		attachment_name,
		bone_name,
		anchor_name,
		anchor_position,
		anchor_rotation_degrees
	)

func _ensure_stow_attachment(
		attachment_name: String,
		bone_name: StringName,
		anchor_name: String,
		anchor_position: Vector3,
		anchor_rotation_degrees: Vector3,
		anchor_position_origin_id: StringName,
		anchor_rotation_degrees_origin_id: StringName
) -> void:
	rig_model_presenter.ensure_stow_attachment(
		skeleton,
		attachment_name,
		bone_name,
		anchor_name,
		anchor_position,
		anchor_rotation_degrees,
		anchor_position_origin_id,
		anchor_rotation_degrees_origin_id
	)

func _ensure_stow_attachment_from_direction(
		attachment_name: String,
		bone_name: StringName,
		anchor_name: String,
		anchor_direction_local: Vector3,
		anchor_direction_origin_id: StringName,
		world_offset_meters: float
) -> void:
	var anchor_position_origin_id: StringName = _resolve_stow_anchor_position_origin_id(anchor_direction_origin_id)
	var anchor_position_local: Vector3 = _resolve_stow_anchor_local_position(anchor_direction_local, world_offset_meters)
	var anchor_rotation_degrees_origin_id: StringName = CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	var anchor_rotation_degrees_local: Vector3 = _resolve_stow_anchor_rotation_degrees_local(anchor_rotation_degrees_origin_id)
	_ensure_stow_attachment(
		attachment_name,
		bone_name,
		anchor_name,
		anchor_position_local,
		anchor_rotation_degrees_local,
		anchor_position_origin_id,
		anchor_rotation_degrees_origin_id
	)

func _resolve_stow_anchor_position_origin_id(anchor_direction_origin_id: StringName) -> StringName:
	if anchor_direction_origin_id != StringName():
		return anchor_direction_origin_id
	return CombatOriginRecordScript.ORIGIN_STOW_ANCHOR

func _resolve_stow_anchor_rotation_degrees_local(_anchor_rotation_degrees_origin_id: StringName) -> Vector3:
	return Vector3.ZERO

func _resolve_hip_stow_right_direction_local() -> Vector3:
	if skeleton == null:
		return Vector3.RIGHT
	var hip_index: int = skeleton.find_bone(String(HIP_BONE))
	if hip_index < 0:
		return Vector3.RIGHT
	var hip_basis_world: Basis = (skeleton.global_basis * skeleton.get_bone_global_pose(hip_index).basis).orthonormalized()
	var local_plus_x_world: Vector3 = (hip_basis_world * Vector3.RIGHT).normalized()
	var actor_right_world: Vector3 = global_basis.x.normalized()
	if local_plus_x_world.length_squared() <= 0.000001 or actor_right_world.length_squared() <= 0.000001:
		return Vector3.RIGHT
	return Vector3.RIGHT if local_plus_x_world.dot(actor_right_world) >= 0.0 else Vector3.LEFT

func _resolve_stow_anchor_local_position(local_direction: Vector3, world_offset_meters: float) -> Vector3:
	if local_direction.length_squared() <= 0.000001:
		return Vector3.ZERO
	var normalized_direction: Vector3 = local_direction.normalized()
	var world_units_per_local_unit: float = 1.0
	if skeleton != null:
		world_units_per_local_unit = (skeleton.global_basis * normalized_direction).length()
	elif global_basis.determinant() != 0.0:
		world_units_per_local_unit = (global_basis * normalized_direction).length()
	if world_units_per_local_unit <= 0.000001:
		world_units_per_local_unit = 1.0
	return normalized_direction * (maxf(world_offset_meters, 0.0) / world_units_per_local_unit)

func _ensure_support_arm_ik_modifiers() -> void:
	var modifier_state: Dictionary = support_arm_ik_presenter.ensure_support_arm_ik_modifiers(
		skeleton,
		right_arm_ik_modifier,
		left_arm_ik_modifier,
		right_hand_ik_target,
		left_hand_ik_target,
		right_hand_pole_target,
		left_hand_pole_target,
		RIGHT_UPPERARM_BONE,
		RIGHT_FOREARM_BONE,
		RIGHT_HAND_BONE,
		LEFT_UPPERARM_BONE,
		LEFT_FOREARM_BONE,
		LEFT_HAND_BONE
	)
	right_arm_ik_modifier = modifier_state.get("right_arm_ik_modifier", right_arm_ik_modifier)
	left_arm_ik_modifier = modifier_state.get("left_arm_ik_modifier", left_arm_ik_modifier)

func _ensure_finger_grip_ik_targets_and_modifiers() -> void:
	finger_grip_target_lookup = finger_grip_presenter.ensure_finger_target_nodes(ik_targets_root)
	finger_grip_modifier_lookup = finger_grip_presenter.ensure_finger_ik_modifiers(
		skeleton,
		finger_grip_modifier_lookup,
		finger_grip_target_lookup
	)

func _snap_support_arm_ik_targets_to_current_pose() -> void:
	support_arm_ik_presenter.snap_support_arm_ik_targets_to_current_pose(
		skeleton,
		right_hand_ik_target,
		left_hand_ik_target,
		right_hand_pole_target,
		left_hand_pole_target,
		RIGHT_HAND_BONE,
		LEFT_HAND_BONE,
		RIGHT_FOREARM_BONE,
		LEFT_FOREARM_BONE,
		Callable(self, "_get_bone_world_position")
	)

func _update_support_arm_ik_targets(delta: float) -> void:
	if skeleton == null or not enable_support_arm_ik:
		return
	sync_runtime_body_restriction_root_now()
	if grip_solve_root == null or not is_instance_valid(grip_solve_root):
		grip_solve_root = grip_debug_draw.call("ensure_debug_root", self) as Node3D
	var solve_result: Dictionary = two_hand_pose_solver.call(
		"solve_arm_targets",
		skeleton,
		body_restriction_root,
		dominant_grip_slot_id,
		global_basis,
		get_arm_guidance_target(&"hand_right"),
		get_arm_guidance_target(&"hand_left"),
		get_right_hand_item_anchor(),
		get_left_hand_item_anchor(),
		RIGHT_UPPERARM_BONE,
		LEFT_UPPERARM_BONE,
		RIGHT_FOREARM_BONE,
		LEFT_FOREARM_BONE,
		RIGHT_HAND_BONE,
		LEFT_HAND_BONE,
		Callable(self, "_get_bone_world_position"),
		Callable(self, "resolve_hand_grip_alignment_world_position"),
		hand_target_constraint_solver,
		_get_two_hand_constraint_config()
	) as Dictionary
	solve_result["dominant_slot_id"] = dominant_grip_slot_id if dominant_grip_slot_id != StringName() else &"hand_right"
	solve_result = _apply_usable_arm_reach_clamp_to_solve_result(solve_result)
	_apply_authoring_manual_upperarm_roll_to_solve_result(
		solve_result,
		&"hand_right",
		RIGHT_UPPERARM_BONE
	)
	_apply_authoring_manual_upperarm_roll_to_solve_result(
		solve_result,
		&"hand_left",
		LEFT_UPPERARM_BONE
	)
	last_two_hand_solve_result = _build_two_hand_solve_debug_summary(solve_result)
	grip_debug_draw.call("update_debug_markers", grip_solve_root, solve_result, show_two_hand_grip_debug_markers)
	var right_solve: Dictionary = solve_result.get(&"hand_right", {})
	if bool(right_solve.get("active", false)) and is_arm_guidance_active(&"hand_right"):
		support_arm_ik_presenter.apply_solved_arm_targets(
			right_hand_ik_target,
			right_hand_pole_target,
			right_solve.get("corrected_target", right_hand_ik_target.global_position),
			right_solve.get("pole_target", right_hand_pole_target.global_position),
			support_arm_ik_target_smoothing_speed,
			delta
		)
	var left_solve: Dictionary = solve_result.get(&"hand_left", {})
	if bool(left_solve.get("active", false)) and is_arm_guidance_active(&"hand_left"):
		support_arm_ik_presenter.apply_solved_arm_targets(
			left_hand_ik_target,
			left_hand_pole_target,
			left_solve.get("corrected_target", left_hand_ik_target.global_position),
			left_solve.get("pole_target", left_hand_pole_target.global_position),
			support_arm_ik_target_smoothing_speed,
			delta
		)

func _build_two_hand_solve_debug_summary(solve_result: Dictionary) -> Dictionary:
	var summary := {
		"dominant_slot_id": solve_result.get("dominant_slot_id", StringName()),
		"hand_right": _build_slot_solve_debug_summary(solve_result.get(&"hand_right", {}) as Dictionary),
		"hand_left": _build_slot_solve_debug_summary(solve_result.get(&"hand_left", {}) as Dictionary),
	}
	return summary

func _build_slot_solve_debug_summary(slot_solve: Dictionary) -> Dictionary:
	if slot_solve.is_empty():
		return {"active": false}
	var projection: Dictionary = slot_solve.get("projection", {}) as Dictionary
	return {
		"active": bool(slot_solve.get("active", false)),
		"desired_target": slot_solve.get("desired_target", Vector3.ZERO) as Vector3,
		"corrected_target": slot_solve.get("corrected_target", Vector3.ZERO) as Vector3,
		"pole_target": slot_solve.get("pole_target", Vector3.ZERO) as Vector3,
		"path_illegal": bool(projection.get("path_illegal", false)),
		"point_illegal": bool(projection.get("point_illegal", false)),
		"front_bias_failed": bool(projection.get("front_bias_failed", false)),
		"used_orbit": bool(projection.get("used_orbit", false)),
		"alternate_target_correction_disabled": bool(projection.get("alternate_target_correction_disabled", false)),
		"weapon_body_illegal": bool(slot_solve.get("weapon_body_illegal", false)),
		"manual_upperarm_roll_active": bool(slot_solve.get("manual_upperarm_roll_active", false)),
		"manual_upperarm_roll_degrees": float(slot_solve.get("manual_upperarm_roll_degrees", 0.0)),
		"arm_reach_clamped": bool(slot_solve.get("arm_reach_clamped", false)),
		"arm_reach_limit_meters": float(slot_solve.get("arm_reach_limit_meters", 0.0)),
		"arm_reach_before_meters": float(slot_solve.get("arm_reach_before_meters", 0.0)),
		"arm_reach_after_meters": float(slot_solve.get("arm_reach_after_meters", 0.0)),
	}

func _apply_authoring_manual_upperarm_roll_to_solve_result(
	solve_result: Dictionary,
	slot_id: StringName,
	upperarm_bone: StringName
) -> void:
	if solve_result.is_empty():
		return
	var roll_degrees: float = _resolve_authoring_manual_upperarm_roll_degrees(slot_id)
	if absf(roll_degrees) <= 0.0001:
		return
	var slot_solve: Dictionary = solve_result.get(slot_id, {}) as Dictionary
	if slot_solve.is_empty() or not bool(slot_solve.get("active", false)):
		return
	var target_world: Vector3 = slot_solve.get("corrected_target", slot_solve.get("desired_target", Vector3.ZERO)) as Vector3
	var pole_world: Vector3 = slot_solve.get("pole_target", Vector3.ZERO) as Vector3
	var shoulder_world: Vector3 = _get_bone_world_position(upperarm_bone)
	var roll_axis_world: Vector3 = target_world - shoulder_world
	if roll_axis_world.length_squared() <= 0.000001:
		return
	roll_axis_world = roll_axis_world.normalized()
	var shoulder_to_pole: Vector3 = pole_world - shoulder_world
	var parallel_world: Vector3 = roll_axis_world * shoulder_to_pole.dot(roll_axis_world)
	var radial_world: Vector3 = shoulder_to_pole - parallel_world
	if radial_world.length_squared() <= 0.000001:
		radial_world = _resolve_authoring_upperarm_roll_reference_world(slot_id, roll_axis_world) * 0.18
	if radial_world.length_squared() <= 0.000001:
		return
	var reference_world: Vector3 = _resolve_authoring_upperarm_roll_reference_world(slot_id, roll_axis_world)
	if reference_world.length_squared() <= 0.000001:
		return
	var current_angle: float = _resolve_signed_planar_angle(reference_world, radial_world.normalized(), roll_axis_world)
	var target_angle: float = deg_to_rad(clampf(roll_degrees, -180.0, 180.0))
	var correction_angle: float = _wrap_angle_radians(target_angle - current_angle)
	var corrected_pole_world: Vector3 = shoulder_world + parallel_world + (Basis(roll_axis_world, correction_angle) * radial_world)
	slot_solve["pole_target"] = corrected_pole_world
	slot_solve["manual_upperarm_roll_degrees"] = roll_degrees
	slot_solve["manual_upperarm_roll_active"] = true
	solve_result[slot_id] = slot_solve

func _refresh_support_arm_ik_influences() -> void:
	support_arm_ik_presenter.refresh_support_arm_ik_influences(
		enable_support_arm_ik and not _uses_direct_authoring_solver_mode(),
		support_arm_ik_influence,
		right_arm_ik_modifier,
		left_arm_ik_modifier,
		is_arm_guidance_active(&"hand_right"),
		is_arm_guidance_active(&"hand_left"),
		get_arm_guidance_target(&"hand_right"),
		get_arm_guidance_target(&"hand_left")
	)

func _uses_direct_authoring_solver_mode() -> bool:
	if authoring_preview_mode_enabled:
		return true
	return (
		not upper_body_authoring_auto_apply_enabled
		and not upper_body_authoring_state.is_empty()
		and bool(upper_body_authoring_state.get("active", false))
	)

func resolve_exact_surface_weapon_seat(
	slot_id: StringName,
	allow_surface_solve: bool = true
) -> Dictionary:
	if skeleton == null:
		return {
			"valid": false,
			"status": &"weapon_surface_seat_unavailable",
		}
	var grip_guide: Node3D = finger_grip_source_lookup.get(slot_id) as Node3D
	if grip_guide == null or not is_instance_valid(grip_guide):
		return {
			"valid": false,
			"status": &"weapon_surface_seat_guide_missing",
		}
	var guide_role: StringName = StringName(grip_guide.name)
	if slot_id == &"hand_right":
		if guide_role == &"PrimaryGripGuide":
			return _resolve_right_primary_exact_surface_weapon_seat(
				grip_guide,
				allow_surface_solve
			)
		if guide_role == &"SecondaryGripGuide":
			return _resolve_right_support_exact_surface_weapon_seat(
				grip_guide,
				allow_surface_solve
			)
	elif slot_id == &"hand_left":
		if guide_role == &"PrimaryGripGuide":
			return _resolve_left_primary_exact_surface_weapon_seat(
				grip_guide,
				allow_surface_solve
			)
		if guide_role == &"SecondaryGripGuide":
			return _resolve_left_support_exact_surface_weapon_seat(
				grip_guide,
				allow_surface_solve
			)
	return {
		"valid": false,
		"status": &"weapon_surface_seat_execution_path_unavailable",
	}


func _resolve_right_primary_exact_surface_weapon_seat(
	grip_guide: Node3D,
	allow_surface_solve: bool
) -> Dictionary:
	if not finger_grip_presenter.has_method(
		"resolve_right_primary_exact_surface_weapon_seat"
	):
		return {
			"valid": false,
			"status": &"right_primary_surface_seat_unavailable",
		}
	var anatomy_state: Dictionary = resolve_hand_surface_seat_anatomy_state(
		&"hand_right"
	)
	if not bool(anatomy_state.get("valid", false)):
		return anatomy_state
	return finger_grip_presenter.call(
		"resolve_right_primary_exact_surface_weapon_seat",
		skeleton,
		grip_guide,
		anatomy_state,
		allow_surface_solve
	) as Dictionary


func _resolve_left_primary_exact_surface_weapon_seat(
	grip_guide: Node3D,
	allow_surface_solve: bool
) -> Dictionary:
	if not finger_grip_presenter.has_method(
		"resolve_left_primary_exact_surface_weapon_seat"
	):
		return {
			"valid": false,
			"status": &"left_primary_surface_seat_unavailable",
		}
	var anatomy_state: Dictionary = resolve_hand_surface_seat_anatomy_state(
		&"hand_left"
	)
	if not bool(anatomy_state.get("valid", false)):
		return anatomy_state
	return finger_grip_presenter.call(
		"resolve_left_primary_exact_surface_weapon_seat",
		skeleton,
		grip_guide,
		anatomy_state,
		allow_surface_solve
	) as Dictionary


func _resolve_right_support_exact_surface_weapon_seat(
	grip_guide: Node3D,
	allow_surface_solve: bool
) -> Dictionary:
	if not finger_grip_presenter.has_method(
		"resolve_right_support_exact_surface_weapon_seat"
	):
		return {
			"valid": false,
			"status": &"right_support_surface_seat_unavailable",
		}
	var anatomy_state: Dictionary = resolve_hand_surface_seat_anatomy_state(
		&"hand_right"
	)
	if not bool(anatomy_state.get("valid", false)):
		return anatomy_state
	return finger_grip_presenter.call(
		"resolve_right_support_exact_surface_weapon_seat",
		skeleton,
		grip_guide,
		anatomy_state,
		allow_surface_solve
	) as Dictionary


func _resolve_left_support_exact_surface_weapon_seat(
	grip_guide: Node3D,
	allow_surface_solve: bool
) -> Dictionary:
	if not finger_grip_presenter.has_method(
		"resolve_left_support_exact_surface_weapon_seat"
	):
		return {
			"valid": false,
			"status": &"left_support_surface_seat_unavailable",
		}
	var anatomy_state: Dictionary = resolve_hand_surface_seat_anatomy_state(
		&"hand_left"
	)
	if not bool(anatomy_state.get("valid", false)):
		return anatomy_state
	return finger_grip_presenter.call(
		"resolve_left_support_exact_surface_weapon_seat",
		skeleton,
		grip_guide,
		anatomy_state,
		allow_surface_solve
	) as Dictionary

func apply_authoring_digit_grip_now(
	allow_exact_surface_solve: bool = true
) -> void:
	if skeleton == null:
		return
	var finger_snap_delta: float = 1.0 / maxf(
		finger_grip_target_smoothing_speed,
		0.001
	)
	_update_finger_grip_targets(
		finger_snap_delta,
		allow_exact_surface_solve
	)
	_refresh_finger_grip_ik_influences()
	skeleton.force_update_all_bone_transforms()
	# Keep the hidden debug geometry synchronized with the committed digit pose.
	# The visibility toggle must remain display-only, so it cannot repair a stale
	# pre-solve snapshot when the user turns Debug View on later.
	_sync_authoring_joint_range_debug_if_pose_changed()


func prepare_authoring_surface_grip_open_pose_now(slot_id: StringName) -> bool:
	if (
		skeleton == null
		or not finger_grip_source_lookup.has(slot_id)
		or not finger_grip_presenter.has_method("apply_exact_surface_open_pose_now")
	):
		return false
	var applied: bool = bool(finger_grip_presenter.call(
		"apply_exact_surface_open_pose_now",
		skeleton,
		slot_id
	))
	if applied:
		skeleton.force_update_all_bone_transforms()
		# A seat rejection can end this lifecycle immediately after the canonical
		# open pose is applied. Keep the hidden gizmo snapshot current here as well;
		# visibility remains a display-only toggle and must not repair stale data.
		_sync_authoring_joint_range_debug_if_pose_changed()
	return applied


func restore_authoring_committed_surface_grip_now(slot_id: StringName) -> bool:
	if (
		skeleton == null
		or not finger_grip_presenter.has_method("reapply_committed_surface_grasp")
	):
		return false
	var restored: bool = bool(finger_grip_presenter.call(
		"reapply_committed_surface_grasp",
		skeleton,
		slot_id
	))
	if restored:
		skeleton.force_update_all_bone_transforms()
		_sync_authoring_joint_range_debug_if_pose_changed()
	return restored


func invalidate_authoring_surface_grasp(slot_id: StringName) -> void:
	if finger_grip_presenter.has_method("invalidate_cached_surface_grasp"):
		finger_grip_presenter.call(
			"invalidate_cached_surface_grasp",
			slot_id
		)


func invalidate_authoring_weapon_surface_seat(slot_id: StringName) -> void:
	if finger_grip_presenter.has_method("invalidate_cached_weapon_surface_seat"):
		finger_grip_presenter.call(
			"invalidate_cached_weapon_surface_seat",
			slot_id
		)


func settle_authoring_grip_relationship_macro_pose_now() -> void:
	if skeleton == null:
		return
	# One ordinary preview frame has already been applied by the caller. Five
	# more upper-body blend passes leave less than 0.04% of the two-hand blend
	# outstanding, without rerunning the expensive exact digit/surface query.
	for _pass_index: int in range(
		AUTHORING_GRIP_RELATIONSHIP_MACRO_SETTLE_PASSES
	):
		_apply_upper_body_authoring_pose()
	_refresh_support_arm_ik_influences()
	var support_snap_delta: float = 1.0 / maxf(
		support_arm_ik_target_smoothing_speed,
		0.001
	)
	# Spend the existing three contact-alignment passes as a converging sequence.
	# Recompute the hand-bone target after each wrist/arm solve so the anatomical
	# index-pinky alignment point actually arrives at the newly published grip
	# anchor. Repeating one stale target three times leaves the palm offset even
	# though the arm itself reached that obsolete target.
	for _pass_index: int in range(
		AUTHORING_GRIP_RELATIONSHIP_CONTACT_SETTLE_PASSES
	):
		_update_support_arm_ik_targets(support_snap_delta)
		_apply_authoring_contact_alignment_pose(1)
		skeleton.force_update_all_bone_transforms()
	settle_authoring_support_grip_macro_pose_now()


func settle_authoring_support_grip_macro_pose_now(
	alignment_epsilon_meters: float = (
		AUTHORING_GRIP_RELATIONSHIP_ALIGNMENT_EPSILON_METERS
	)
) -> void:
	if skeleton == null:
		return
	var resolved_alignment_epsilon_meters: float = alignment_epsilon_meters
	if (
		not is_finite(resolved_alignment_epsilon_meters)
		or resolved_alignment_epsilon_meters <= 0.0
	):
		resolved_alignment_epsilon_meters = (
			AUTHORING_GRIP_RELATIONSHIP_ALIGNMENT_EPSILON_METERS
		)
	var support_slot_id: StringName = (
		&"hand_right"
		if dominant_grip_slot_id == &"hand_left"
		else &"hand_left"
	)
	if is_support_hand_active(support_slot_id):
		var support_snap_delta: float = 1.0 / maxf(
			support_arm_ik_target_smoothing_speed,
			0.001
		)
		# The ordinary authoring pass intentionally accepts a coarse arm-arrival
		# tolerance for interactive editing. A relationship-changing support grip
		# needs millimetre-scale agreement before the transactional digit solver can
		# apply its 0.5 mm contact law. Reuse the existing arm and wrist operators in
		# a bounded, support-only final convergence pass; the weapon and dominant hand
		# remain untouched.
		for _pass_index: int in range(
			AUTHORING_GRIP_RELATIONSHIP_PRECISE_SETTLE_PASSES
		):
			_update_support_arm_ik_targets(support_snap_delta)
			_apply_authoring_precise_contact_alignment_for_slot(
				support_slot_id,
				resolved_alignment_epsilon_meters
			)
			skeleton.force_update_all_bone_transforms()
			var guidance_target: Node3D = get_arm_guidance_target(support_slot_id)
			if guidance_target == null or not is_instance_valid(guidance_target):
				break
			var alignment_world: Vector3 = (
				resolve_hand_grip_alignment_world_position(support_slot_id)
			)
			var forearm_bone: StringName = (
				LEFT_FOREARM_BONE
				if support_slot_id == &"hand_left"
				else RIGHT_FOREARM_BONE
			)
			var hand_bone: StringName = (
				LEFT_HAND_BONE
				if support_slot_id == &"hand_left"
				else RIGHT_HAND_BONE
			)
			var hand_anchor: Node3D = (
				get_left_hand_item_anchor()
				if support_slot_id == &"hand_left"
				else get_right_hand_item_anchor()
			)
			var contact_axis_error_degrees: float = (
				_resolve_authoring_contact_axis_error_degrees(
					support_slot_id,
					forearm_bone,
					hand_bone,
					hand_anchor
				)
			)
			if (
				alignment_world.distance_to(guidance_target.global_position)
					<= resolved_alignment_epsilon_meters
				and contact_axis_error_degrees
					<= AUTHORING_GRIP_RELATIONSHIP_CONTACT_AXIS_EPSILON_DEGREES
			):
				break
	_refresh_finger_grip_ik_influences()
	skeleton.force_update_all_bone_transforms()


func _apply_authoring_precise_contact_alignment_for_slot(
	slot_id: StringName,
	alignment_epsilon_meters: float = (
		AUTHORING_GRIP_RELATIONSHIP_ALIGNMENT_EPSILON_METERS
	)
) -> void:
	if skeleton == null or not is_arm_guidance_active(slot_id):
		return
	var hand_target: Node3D = (
		left_hand_ik_target
		if slot_id == &"hand_left"
		else right_hand_ik_target
	)
	if hand_target == null or not is_instance_valid(hand_target):
		return
	var upperarm_bone: StringName = (
		LEFT_UPPERARM_BONE
		if slot_id == &"hand_left"
		else RIGHT_UPPERARM_BONE
	)
	var forearm_bone: StringName = (
		LEFT_FOREARM_BONE
		if slot_id == &"hand_left"
		else RIGHT_FOREARM_BONE
	)
	var hand_bone: StringName = (
		LEFT_HAND_BONE
		if slot_id == &"hand_left"
		else RIGHT_HAND_BONE
	)
	var clavicle_bone: StringName = (
		LEFT_CLAVICLE_BONE
		if slot_id == &"hand_left"
		else RIGHT_CLAVICLE_BONE
	)
	var hand_anchor: Node3D = (
		get_left_hand_item_anchor()
		if slot_id == &"hand_left"
		else get_right_hand_item_anchor()
	)
	var requested_target_world: Vector3 = hand_target.global_position
	var target_world: Vector3 = _resolve_usable_arm_target_world(
		slot_id,
		requested_target_world
	).get("target_world", requested_target_world) as Vector3
	_apply_ccd_arm_reach_pose(
		upperarm_bone,
		forearm_bone,
		hand_bone,
		target_world,
		AUTHORING_GRIP_RELATIONSHIP_PRECISE_SOLVE_ITERATIONS,
		AUTHORING_DIRECT_ARM_FOREARM_WEIGHT,
		AUTHORING_DIRECT_ARM_UPPERARM_WEIGHT,
		clavicle_bone,
		AUTHORING_DIRECT_ARM_CLAVICLE_WEIGHT,
		alignment_epsilon_meters
	)
	# The support hand follows the fixed primary-hand/weapon unit. Align the
	# existing arm chain to the published Handle contact axis, then reseat the
	# hand point; do not grant the wrist an independent roll solve.
	_apply_authoring_arm_spline_preference(
		slot_id,
		clavicle_bone,
		upperarm_bone,
		forearm_bone,
		hand_bone,
		hand_anchor,
		1.0
	)
	_apply_ccd_arm_reach_pose(
		upperarm_bone,
		forearm_bone,
		hand_bone,
		target_world,
		AUTHORING_ARM_SPLINE_RESEAT_ITERATIONS,
		AUTHORING_DIRECT_ARM_FOREARM_WEIGHT * 0.5,
		AUTHORING_DIRECT_ARM_UPPERARM_WEIGHT * 0.5,
		clavicle_bone,
		AUTHORING_DIRECT_ARM_CLAVICLE_WEIGHT * 0.5,
		alignment_epsilon_meters
	)
	_enforce_authoring_upperarm_swing_authority(
		slot_id,
		clavicle_bone,
		upperarm_bone,
		forearm_bone,
		hand_bone
	)
	if enable_authoring_contact_wrist_basis:
		_apply_authoring_contact_wrist_basis_for_slot(
			slot_id,
			hand_bone,
			forearm_bone,
			hand_anchor,
			clampf(authoring_contact_wrist_basis_strength, 0.0, 1.0)
		)
	skeleton.force_update_all_bone_transforms()

func get_weapon_surface_seat_debug_state(slot_id: StringName) -> Dictionary:
	if finger_grip_presenter.has_method("get_hand_surface_seat_debug_state"):
		return finger_grip_presenter.call(
			"get_hand_surface_seat_debug_state",
			slot_id
		) as Dictionary
	return {}

func get_hand_surface_seat_debug_state(slot_id: StringName) -> Dictionary:
	return get_weapon_surface_seat_debug_state(slot_id)

func _update_finger_grip_targets(
	delta: float,
	allow_exact_surface_solve: bool = false
) -> void:
	finger_grip_presenter.update_finger_grip_targets(
		skeleton,
		finger_grip_source_lookup,
		finger_grip_target_lookup,
		Callable(self, "_get_bone_world_position"),
		finger_grip_target_smoothing_speed,
		delta,
		allow_exact_surface_solve
	)

func _refresh_finger_grip_ik_influences() -> void:
	finger_grip_presenter.refresh_finger_ik_influences(
		enable_finger_grip_ik,
		finger_grip_ik_influence,
		finger_grip_modifier_lookup,
		finger_grip_source_lookup
	)

func _apply_upper_body_authoring_pose() -> void:
	if skeleton == null or not enable_upper_body_authoring_pose:
		return
	if upper_body_authoring_state.is_empty() or not bool(upper_body_authoring_state.get("active", false)):
		return
	var effective_state: Dictionary = upper_body_authoring_state.duplicate(true)
	effective_state["strength_scale"] = upper_body_authoring_pose_strength
	upper_body_pose_presenter.apply_upper_body_authoring_pose(
		skeleton,
		global_basis,
		effective_state
	)

func _resolve_max_model_arm_reach_meters() -> float:
	return rig_model_presenter.resolve_max_model_arm_reach_meters(
		skeleton,
		RIGHT_HAND_BONE,
		LEFT_HAND_BONE,
		right_hand_anchor_position,
		left_hand_anchor_position,
		bone_index_cache
	)

func _apply_pole_grip_arm_reach_limits() -> void:
	var limits: Dictionary = grip_layout_presenter.apply_pole_grip_arm_reach_limits(
		max_model_arm_reach_meters,
		pole_grip_arm_reach_margin_percent
	)
	max_model_arm_reach_combat_meters = float(limits.get("max_model_arm_reach_combat_meters", 0.0))
	pole_grip_negative_limit_meters = float(limits.get("pole_grip_negative_limit_meters", 0.0))
	pole_grip_positive_limit_meters = float(limits.get("pole_grip_positive_limit_meters", 0.0))

func _resolve_arm_chain_reach_limits() -> void:
	right_max_arm_chain_reach_meters = rig_model_presenter.resolve_arm_chain_reach_meters(
		skeleton,
		RIGHT_CLAVICLE_BONE,
		RIGHT_UPPERARM_BONE,
		RIGHT_FOREARM_BONE,
		RIGHT_HAND_BONE,
		right_hand_anchor_position,
		bone_index_cache
	)
	left_max_arm_chain_reach_meters = rig_model_presenter.resolve_arm_chain_reach_meters(
		skeleton,
		LEFT_CLAVICLE_BONE,
		LEFT_UPPERARM_BONE,
		LEFT_FOREARM_BONE,
		LEFT_HAND_BONE,
		left_hand_anchor_position,
		bone_index_cache
	)
	var usable_ratio: float = get_usable_arm_motion_range_ratio()
	right_usable_arm_chain_reach_meters = maxf(right_max_arm_chain_reach_meters * usable_ratio, 0.0)
	left_usable_arm_chain_reach_meters = maxf(left_max_arm_chain_reach_meters * usable_ratio, 0.0)

func _apply_usable_arm_reach_clamp_to_solve_result(solve_result: Dictionary) -> Dictionary:
	var clamped_result: Dictionary = solve_result.duplicate(true)
	for slot_id: StringName in [&"hand_right", &"hand_left"]:
		var slot_solve: Dictionary = clamped_result.get(slot_id, {}) as Dictionary
		if not bool(slot_solve.get("active", false)):
			continue
		var corrected_target: Vector3 = slot_solve.get("corrected_target", Vector3.ZERO) as Vector3
		var reach_result: Dictionary = _resolve_usable_arm_target_world(slot_id, corrected_target)
		slot_solve["corrected_target"] = reach_result.get("target_world", corrected_target) as Vector3
		slot_solve["arm_reach_clamped"] = bool(reach_result.get("clamped", false))
		slot_solve["arm_reach_limit_meters"] = float(reach_result.get("limit_meters", 0.0))
		slot_solve["arm_reach_before_meters"] = float(reach_result.get("distance_before_meters", 0.0))
		slot_solve["arm_reach_after_meters"] = float(reach_result.get("distance_after_meters", 0.0))
		var projection: Dictionary = slot_solve.get("projection", {}) as Dictionary
		projection["arm_reach_clamped"] = bool(reach_result.get("clamped", false))
		projection["arm_reach_limit_meters"] = float(reach_result.get("limit_meters", 0.0))
		projection["arm_reach_before_meters"] = float(reach_result.get("distance_before_meters", 0.0))
		projection["arm_reach_after_meters"] = float(reach_result.get("distance_after_meters", 0.0))
		slot_solve["projection"] = projection
		clamped_result[slot_id] = slot_solve
	return clamped_result

func _resolve_usable_arm_target_world(slot_id: StringName, target_world: Vector3) -> Dictionary:
	var clavicle_bone: StringName = LEFT_CLAVICLE_BONE if slot_id == &"hand_left" else RIGHT_CLAVICLE_BONE
	var origin_world: Vector3 = _get_bone_world_position(clavicle_bone)
	var reach_limit_meters: float = get_usable_arm_chain_reach_meters(slot_id)
	var origin_to_target: Vector3 = target_world - origin_world
	var distance_before: float = origin_to_target.length()
	if reach_limit_meters <= 0.00001 or distance_before <= reach_limit_meters:
		return {
			"origin_world": origin_world,
			"target_world": target_world,
			"limit_meters": reach_limit_meters,
			"distance_before_meters": distance_before,
			"distance_after_meters": distance_before,
			"clamped": false,
		}
	var clamped_target: Vector3 = origin_world + origin_to_target.normalized() * reach_limit_meters
	return {
		"origin_world": origin_world,
		"target_world": clamped_target,
		"limit_meters": reach_limit_meters,
		"distance_before_meters": distance_before,
		"distance_after_meters": reach_limit_meters,
		"clamped": true,
	}

func _get_bone_world_position(bone_name: StringName) -> Vector3:
	return rig_model_presenter.get_bone_world_position(global_position, skeleton, bone_name, bone_index_cache)

func _ensure_combat_authoring_modifier() -> void:
	if skeleton == null:
		return
	combat_authoring_modifier = skeleton.get_node_or_null(COMBAT_AUTHORING_MODIFIER_NAME) as SkeletonModifier3D
	if combat_authoring_modifier == null:
		combat_authoring_modifier = PlayerCombatAuthoringModifier3DScript.new()
		combat_authoring_modifier.name = COMBAT_AUTHORING_MODIFIER_NAME
		skeleton.add_child(combat_authoring_modifier)
	combat_authoring_modifier.set("humanoid_rig", self)
	combat_authoring_modifier.influence = 1.0
	_refresh_combat_authoring_modifier_state()

func _refresh_combat_authoring_modifier_state() -> void:
	if combat_authoring_modifier == null:
		return
	combat_authoring_modifier.active = _uses_direct_authoring_solver_mode() and not authoring_preview_mode_enabled

func _ensure_runtime_solved_replay_modifier() -> void:
	if skeleton == null:
		return
	runtime_solved_replay_modifier = skeleton.get_node_or_null(RUNTIME_SOLVED_REPLAY_MODIFIER_NAME) as SkeletonModifier3D
	if runtime_solved_replay_modifier == null:
		runtime_solved_replay_modifier = PlayerRuntimeSolvedReplayModifier3DScript.new()
		runtime_solved_replay_modifier.name = RUNTIME_SOLVED_REPLAY_MODIFIER_NAME
		skeleton.add_child(runtime_solved_replay_modifier)
	runtime_solved_replay_modifier.set("humanoid_rig", self)
	runtime_solved_replay_modifier.influence = 1.0
	_refresh_runtime_solved_replay_modifier_state()
	_refresh_runtime_modifier_order()

func _refresh_runtime_solved_replay_modifier_state() -> void:
	if runtime_solved_replay_modifier == null:
		return
	runtime_solved_replay_modifier.active = (
		not authoring_preview_mode_enabled
		and (
			(not runtime_solved_replay_pose_state.is_empty() and bool(runtime_solved_replay_pose_state.get("active", false)))
			or (not runtime_solved_replay_weapon_state.is_empty() and bool(runtime_solved_replay_weapon_state.get("active", false)))
		)
	)

func _ensure_runtime_body_restriction_sync_modifier() -> void:
	if skeleton == null:
		return
	runtime_body_restriction_sync_modifier = skeleton.get_node_or_null(RUNTIME_BODY_RESTRICTION_SYNC_MODIFIER_NAME) as SkeletonModifier3D
	if runtime_body_restriction_sync_modifier == null:
		runtime_body_restriction_sync_modifier = PlayerRuntimeBodyRestrictionSyncModifier3DScript.new()
		runtime_body_restriction_sync_modifier.name = RUNTIME_BODY_RESTRICTION_SYNC_MODIFIER_NAME
		skeleton.add_child(runtime_body_restriction_sync_modifier)
	runtime_body_restriction_sync_modifier.set("humanoid_rig", self)
	runtime_body_restriction_sync_modifier.influence = 1.0
	_refresh_runtime_body_restriction_sync_modifier_state()
	_refresh_runtime_modifier_order()

func _refresh_runtime_body_restriction_sync_modifier_state() -> void:
	if runtime_body_restriction_sync_modifier == null:
		return
	runtime_body_restriction_sync_modifier.active = not authoring_preview_mode_enabled and body_restriction_root != null

func _ensure_runtime_bone_debug_modifier() -> void:
	if skeleton == null:
		return
	runtime_bone_debug_modifier = skeleton.get_node_or_null(RUNTIME_BONE_DEBUG_MODIFIER_NAME) as SkeletonModifier3D
	if runtime_bone_debug_modifier == null:
		runtime_bone_debug_modifier = PlayerRuntimeBoneDebugModifier3DScript.new()
		runtime_bone_debug_modifier.name = RUNTIME_BONE_DEBUG_MODIFIER_NAME
		skeleton.add_child(runtime_bone_debug_modifier)
	runtime_bone_debug_modifier.set("humanoid_rig", self)
	runtime_bone_debug_modifier.influence = 1.0
	_refresh_runtime_bone_debug_modifier_state()
	_refresh_runtime_modifier_order()

func _refresh_runtime_modifier_order() -> void:
	if skeleton == null:
		return
	_move_skeleton_modifier_to_tail(runtime_solved_replay_modifier)
	_move_skeleton_modifier_to_tail(runtime_body_restriction_sync_modifier)
	_move_skeleton_modifier_to_tail(runtime_bone_debug_modifier)

func _move_skeleton_modifier_to_tail(modifier: SkeletonModifier3D) -> void:
	if modifier == null or not is_instance_valid(modifier):
		return
	if modifier.get_parent() != skeleton:
		return
	var target_index: int = skeleton.get_child_count() - 1
	if modifier.get_index() == target_index:
		return
	skeleton.move_child(modifier, target_index)

func _refresh_runtime_bone_debug_modifier_state() -> void:
	if runtime_bone_debug_modifier == null:
		return
	runtime_bone_debug_modifier.active = show_runtime_bone_debug and not authoring_preview_mode_enabled

func _ensure_runtime_locomotion_animation_tree() -> void:
	if josie_model == null or animation_player == null:
		return
	if runtime_locomotion_animation_tree == null or not is_instance_valid(runtime_locomotion_animation_tree):
		runtime_locomotion_animation_tree = AnimationTree.new()
		runtime_locomotion_animation_tree.name = RUNTIME_LOCOMOTION_ANIMATION_TREE_NAME
		josie_model.add_child(runtime_locomotion_animation_tree)
	runtime_locomotion_animation_tree.anim_player = runtime_locomotion_animation_tree.get_path_to(animation_player)
	runtime_locomotion_animation_tree.root_node = NodePath("..")
	runtime_locomotion_animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	var state_names: Array[StringName] = _get_runtime_locomotion_animation_state_names()
	if state_names.is_empty():
		runtime_locomotion_animation_tree.active = false
		runtime_locomotion_state_machine_playback = null
		return
	var setup_key_parts := PackedStringArray()
	for animation_name: StringName in state_names:
		setup_key_parts.append(String(animation_name))
	var setup_key: String = "|".join(setup_key_parts)
	if runtime_locomotion_animation_tree.tree_root != null and String(runtime_locomotion_animation_tree.get_meta("runtime_locomotion_setup_key", "")) == setup_key:
		runtime_locomotion_animation_tree.active = not authoring_preview_mode_enabled
		runtime_locomotion_state_machine_playback = runtime_locomotion_animation_tree.get(RUNTIME_LOCOMOTION_PLAYBACK_PATH) as AnimationNodeStateMachinePlayback
		return
	var state_machine := AnimationNodeStateMachine.new()
	for state_index: int in range(state_names.size()):
		var animation_name: StringName = state_names[state_index]
		var animation_node := AnimationNodeAnimation.new()
		animation_node.animation = animation_name
		state_machine.add_node(animation_name, animation_node, Vector2(float(state_index) * 180.0, 0.0))
	for from_state: StringName in state_names:
		for to_state: StringName in state_names:
			if from_state == to_state:
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
			transition.xfade_time = animation_blend_seconds
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
			transition.reset = true
			state_machine.add_transition(from_state, to_state, transition)
	runtime_locomotion_animation_tree.tree_root = state_machine
	runtime_locomotion_animation_tree.set_meta("runtime_locomotion_setup_key", setup_key)
	runtime_locomotion_animation_tree.active = not authoring_preview_mode_enabled
	runtime_locomotion_state_machine_playback = runtime_locomotion_animation_tree.get(RUNTIME_LOCOMOTION_PLAYBACK_PATH) as AnimationNodeStateMachinePlayback

func _get_runtime_locomotion_animation_state_names() -> Array[StringName]:
	var requested_names: Array[StringName] = [
		default_animation_name,
		two_hand_idle_animation_name,
		walk_animation_name,
		jog_animation_name,
		sprint_animation_name,
		jump_animation_name,
		fall_animation_name,
	]
	var state_names: Array[StringName] = []
	for animation_name: StringName in requested_names:
		if animation_name == StringName():
			continue
		if state_names.has(animation_name):
			continue
		if not has_animation_name(animation_name):
			continue
		state_names.append(animation_name)
	return state_names

func _play_runtime_locomotion_animation(animation_name: StringName) -> void:
	if authoring_preview_mode_enabled or animation_name == StringName():
		return
	if locomotion_presenter.current_animation_name == animation_name and _is_runtime_locomotion_state_playing(animation_name):
		return
	if _travel_runtime_locomotion_animation_tree(animation_name):
		locomotion_presenter.current_animation_name = animation_name
		return
	locomotion_presenter.play_animation(animation_player, animation_name, animation_blend_seconds)

func _is_runtime_locomotion_state_playing(animation_name: StringName) -> bool:
	if runtime_locomotion_animation_tree == null or not runtime_locomotion_animation_tree.active:
		return false
	if runtime_locomotion_state_machine_playback == null:
		runtime_locomotion_state_machine_playback = runtime_locomotion_animation_tree.get(RUNTIME_LOCOMOTION_PLAYBACK_PATH) as AnimationNodeStateMachinePlayback
	if runtime_locomotion_state_machine_playback == null or not runtime_locomotion_state_machine_playback.is_playing():
		return false
	return runtime_locomotion_state_machine_playback.get_current_node() == animation_name

func _travel_runtime_locomotion_animation_tree(animation_name: StringName) -> bool:
	if animation_name == StringName() or not has_animation_name(animation_name):
		return false
	_ensure_runtime_locomotion_animation_tree()
	if runtime_locomotion_animation_tree == null or not runtime_locomotion_animation_tree.active:
		return false
	if runtime_locomotion_state_machine_playback == null:
		runtime_locomotion_state_machine_playback = runtime_locomotion_animation_tree.get(RUNTIME_LOCOMOTION_PLAYBACK_PATH) as AnimationNodeStateMachinePlayback
	if runtime_locomotion_state_machine_playback == null:
		return false
	if not runtime_locomotion_state_machine_playback.is_playing():
		runtime_locomotion_state_machine_playback.start(animation_name, true)
		return true
	runtime_locomotion_state_machine_playback.travel(animation_name, true)
	runtime_locomotion_state_machine_playback.next()
	if runtime_locomotion_state_machine_playback.get_current_node() != animation_name:
		runtime_locomotion_state_machine_playback.start(animation_name, true)
	return true

func _play_default_animation() -> void:
	if authoring_preview_mode_enabled:
		return
	_play_runtime_locomotion_animation(default_animation_name)

func _apply_authoring_preview_baseline_pose(baseline_animation_name: StringName = StringName()) -> void:
	if skeleton != null:
		skeleton.reset_bone_poses()
		skeleton.force_update_all_bone_transforms()
	if animation_player == null:
		return
	var resolved_animation_name: StringName = baseline_animation_name
	if resolved_animation_name == StringName() or not has_animation_name(resolved_animation_name):
		resolved_animation_name = default_animation_name if has_animation_name(default_animation_name) else StringName()
	if resolved_animation_name != StringName():
		animation_player.play(String(resolved_animation_name), 0.0)
		animation_player.seek(0.0, true)
		animation_player.stop(true)
		locomotion_presenter.current_animation_name = resolved_animation_name
		if skeleton != null:
			skeleton.force_update_all_bone_transforms()
		return
	animation_player.stop()
	locomotion_presenter.current_animation_name = StringName()
	if skeleton != null:
		skeleton.force_update_all_bone_transforms()

func _get_support_arm_ik_config() -> Dictionary:
	return {
		"support_arm_ik_target_smoothing_speed": support_arm_ik_target_smoothing_speed,
		"support_arm_ik_pole_side_offset_meters": support_arm_ik_pole_side_offset_meters,
		"support_arm_ik_pole_down_offset_meters": support_arm_ik_pole_down_offset_meters,
		"support_arm_ik_pole_back_offset_meters": support_arm_ik_pole_back_offset_meters,
	}

func _get_locomotion_config(two_hand_idle_requested: bool = false) -> Dictionary:
	return {
		"default_animation_name": default_animation_name,
		"two_hand_idle_animation_name": two_hand_idle_animation_name,
		"two_hand_idle_available": has_animation_name(two_hand_idle_animation_name),
		"two_hand_idle_requested": two_hand_idle_requested,
		"walk_animation_name": walk_animation_name,
		"jog_animation_name": jog_animation_name,
		"sprint_animation_name": sprint_animation_name,
		"jump_animation_name": jump_animation_name,
		"fall_animation_name": fall_animation_name,
		"animation_blend_seconds": animation_blend_seconds,
		"idle_horizontal_speed_threshold": idle_horizontal_speed_threshold,
		"walk_ratio_threshold": walk_ratio_threshold,
		"jump_vertical_velocity_threshold": jump_vertical_velocity_threshold,
	}

func _should_use_two_hand_idle_animation() -> bool:
	if dominant_grip_slot_id == StringName():
		return false
	return is_support_hand_active(&"hand_right") or is_support_hand_active(&"hand_left")

func _get_two_hand_constraint_config() -> Dictionary:
	return {
		"front_bias_amount": two_hand_front_bias_meters,
		"safety_margin_meters": two_hand_safety_margin_meters,
		"orbit_radius_meters": two_hand_orbit_radius_meters,
		"orbit_radius_scale": two_hand_orbit_radius_scale,
		"orbit_vertical_bias": two_hand_orbit_vertical_bias_meters,
		"orbit_sample_count": two_hand_orbit_sample_count,
		"allow_alternate_target_correction": not authoring_preview_mode_enabled,
		"elbow_pole_side_offset_meters": support_arm_ik_pole_side_offset_meters,
		"elbow_pole_down_offset_meters": support_arm_ik_pole_down_offset_meters,
		"elbow_pole_back_offset_meters": support_arm_ik_pole_back_offset_meters,
		"usable_arm_motion_range_ratio": get_usable_arm_motion_range_ratio(),
		"right_usable_arm_chain_reach_meters": get_usable_arm_chain_reach_meters(&"hand_right"),
		"left_usable_arm_chain_reach_meters": get_usable_arm_chain_reach_meters(&"hand_left"),
	}
