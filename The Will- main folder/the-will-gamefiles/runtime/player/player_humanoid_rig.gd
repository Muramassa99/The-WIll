extends Node3D
class_name PlayerHumanoidRig

const PlayerRigModelPresenterScript = preload("res://runtime/player/player_rig_model_presenter.gd")
const PlayerRigGuidanceStatePresenterScript = preload("res://runtime/player/player_rig_guidance_state_presenter.gd")
const PlayerRigLocomotionPresenterScript = preload("res://runtime/player/player_rig_locomotion_presenter.gd")
const PlayerRigGripLayoutPresenterScript = preload("res://runtime/player/player_rig_grip_layout_presenter.gd")
const PlayerRigSupportArmIkPresenterScript = preload("res://runtime/player/player_rig_support_arm_ik_presenter.gd")
const PlayerRigFingerGripPresenterScript = preload("res://runtime/player/player_rig_finger_grip_presenter.gd")
const HandTargetConstraintSolverScript = preload("res://runtime/player/hand_target_constraint_solver.gd")
const TwoHandPoseSolverScript = preload("res://runtime/player/two_hand_pose_solver.gd")
const GripDebugDrawScript = preload("res://runtime/player/grip_debug_draw.gd")
const RIGHT_HAND_BONE := &"CC_Base_R_Hand"
const LEFT_HAND_BONE := &"CC_Base_L_Hand"
const RIGHT_THIGH_BONE := &"CC_Base_R_Thigh"
const LEFT_THIGH_BONE := &"CC_Base_L_Thigh"
const RIGHT_CLAVICLE_BONE := &"CC_Base_R_Clavicle"
const LEFT_CLAVICLE_BONE := &"CC_Base_L_Clavicle"
const RIGHT_UPPERARM_BONE := &"CC_Base_R_Upperarm"
const LEFT_UPPERARM_BONE := &"CC_Base_L_Upperarm"
const RIGHT_FOREARM_BONE := &"CC_Base_R_Forearm"
const LEFT_FOREARM_BONE := &"CC_Base_L_Forearm"
@export_range(1.6, 2.4, 0.01) var standing_height_meters: float = 2.0
@export_range(0.0, 0.5, 0.01) var pole_grip_arm_reach_margin_percent: float = 0.10
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
@onready var ik_targets_root: Node3D = $IkTargets
@onready var right_hand_ik_target: Node3D = $IkTargets/RightHandIkTarget
@onready var left_hand_ik_target: Node3D = $IkTargets/LeftHandIkTarget
@onready var right_hand_pole_target: Node3D = $IkTargets/RightHandPoleTarget
@onready var left_hand_pole_target: Node3D = $IkTargets/LeftHandPoleTarget

var resolved_visual_height_meters: float = 0.0
var max_model_arm_reach_meters: float = 0.0
var max_model_arm_reach_combat_meters: float = 0.0
var pole_grip_negative_limit_meters: float = 0.0
var pole_grip_positive_limit_meters: float = 0.0
var right_arm_ik_modifier: TwoBoneIK3D = null
var left_arm_ik_modifier: TwoBoneIK3D = null
var bone_index_cache: Dictionary = {}
var rig_model_presenter = PlayerRigModelPresenterScript.new()
var guidance_state_presenter = PlayerRigGuidanceStatePresenterScript.new()
var locomotion_presenter = PlayerRigLocomotionPresenterScript.new()
var grip_layout_presenter = PlayerRigGripLayoutPresenterScript.new()
var support_arm_ik_presenter = PlayerRigSupportArmIkPresenterScript.new()
var finger_grip_presenter = PlayerRigFingerGripPresenterScript.new()
var hand_target_constraint_solver = HandTargetConstraintSolverScript.new()
var two_hand_pose_solver = TwoHandPoseSolverScript.new()
var grip_debug_draw = GripDebugDrawScript.new()
var finger_grip_source_lookup: Dictionary = {}
var finger_grip_target_lookup: Dictionary = {}
var finger_grip_modifier_lookup: Dictionary = {}
var body_restriction_root: Node3D = null
var grip_solve_root: Node3D = null
var dominant_grip_slot_id: StringName = StringName()
var locomotion_grounded: bool = true
var locomotion_horizontal_speed: float = 0.0
var locomotion_vertical_velocity: float = 0.0

func _ready() -> void:
	_apply_target_height_scale()
	guidance_state_presenter.reset_state()
	if skeleton != null:
		skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
	_ensure_hand_attachment("RightHandAttachment", RIGHT_HAND_BONE, "RightHandItemAnchor", right_hand_anchor_position, right_hand_anchor_rotation_degrees)
	_ensure_hand_attachment("LeftHandAttachment", LEFT_HAND_BONE, "LeftHandItemAnchor", left_hand_anchor_position, left_hand_anchor_rotation_degrees)
	_ensure_stow_attachment("LeftShoulderStowAttachment", LEFT_CLAVICLE_BONE, "LeftShoulderStowAnchor", left_shoulder_stow_position, left_shoulder_stow_rotation_degrees)
	_ensure_stow_attachment("RightShoulderStowAttachment", RIGHT_CLAVICLE_BONE, "RightShoulderStowAnchor", right_shoulder_stow_position, right_shoulder_stow_rotation_degrees)
	_ensure_stow_attachment("LeftHipStowAttachment", LEFT_THIGH_BONE, "LeftHipStowAnchor", left_side_hip_stow_position, left_side_hip_stow_rotation_degrees)
	_ensure_stow_attachment("RightHipStowAttachment", RIGHT_THIGH_BONE, "RightHipStowAnchor", right_side_hip_stow_position, right_side_hip_stow_rotation_degrees)
	_ensure_stow_attachment("LeftLowerBackStowAttachment", LEFT_THIGH_BONE, "LeftLowerBackStowAnchor", left_lower_back_stow_position, left_lower_back_stow_rotation_degrees)
	_ensure_stow_attachment("RightLowerBackStowAttachment", RIGHT_THIGH_BONE, "RightLowerBackStowAnchor", right_lower_back_stow_position, right_lower_back_stow_rotation_degrees)
	max_model_arm_reach_meters = _resolve_max_model_arm_reach_meters()
	_apply_pole_grip_arm_reach_limits()
	_ensure_support_arm_ik_modifiers()
	_ensure_finger_grip_ik_targets_and_modifiers()
	body_restriction_root = hand_target_constraint_solver.call("ensure_body_restriction_root", self, skeleton) as Node3D
	grip_solve_root = grip_debug_draw.call("ensure_debug_root", self) as Node3D
	_snap_support_arm_ik_targets_to_current_pose()
	_refresh_support_arm_ik_influences()
	_refresh_finger_grip_ik_influences()
	process_priority = 10
	set_process(true)
	_play_default_animation()

func _process(delta: float) -> void:
	_update_support_arm_ik_targets(delta)
	_refresh_support_arm_ik_influences()
	_update_finger_grip_targets(delta)
	_refresh_finger_grip_ik_influences()

func get_standing_height_meters() -> float:
	return standing_height_meters

func get_visual_height_meters() -> float:
	return resolved_visual_height_meters

func get_max_model_arm_reach_meters() -> float:
	return max_model_arm_reach_meters

func get_max_model_arm_reach_combat_meters() -> float:
	return max_model_arm_reach_combat_meters

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

func resolve_hand_grip_alignment_offset_local(slot_id: StringName) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var hand_anchor: Node3D = get_right_hand_item_anchor() if slot_id == &"hand_right" else get_left_hand_item_anchor()
	if hand_anchor == null:
		return Vector3.ZERO
	var grip_center_world: Vector3 = finger_grip_presenter.resolve_hand_grip_alignment_world_position(skeleton, slot_id)
	if grip_center_world.length_squared() <= 0.000001:
		return Vector3.ZERO
	return hand_anchor.to_local(grip_center_world)

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
	locomotion_presenter.update_locomotion_state(
		animation_player,
		horizontal_speed,
		target_horizontal_speed,
		grounded,
		vertical_velocity,
		sprinting,
		_get_locomotion_config(_should_use_two_hand_idle_animation())
	)

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

func get_body_restriction_root() -> Node3D:
	return body_restriction_root

func get_grip_solve_root() -> Node3D:
	return grip_solve_root

func set_arm_guidance_target(slot_id: StringName, target_node: Node3D) -> void:
	guidance_state_presenter.set_arm_guidance_target(slot_id, target_node)
	_refresh_support_arm_ik_influences()

func clear_arm_guidance_target(slot_id: StringName) -> void:
	guidance_state_presenter.clear_arm_guidance_target(slot_id)
	_refresh_support_arm_ik_influences()

func set_finger_grip_target(slot_id: StringName, guide_node: Node3D) -> void:
	if slot_id != &"hand_right" and slot_id != &"hand_left":
		return
	finger_grip_source_lookup[slot_id] = guide_node
	_refresh_finger_grip_ik_influences()

func clear_finger_grip_target(slot_id: StringName) -> void:
	if slot_id != &"hand_right" and slot_id != &"hand_left":
		return
	finger_grip_source_lookup.erase(slot_id)
	_refresh_finger_grip_ik_influences()

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
		anchor_rotation_degrees: Vector3
) -> void:
	rig_model_presenter.ensure_stow_attachment(
		skeleton,
		attachment_name,
		bone_name,
		anchor_name,
		anchor_position,
		anchor_rotation_degrees
	)

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
	if body_restriction_root == null or not is_instance_valid(body_restriction_root):
		body_restriction_root = hand_target_constraint_solver.call("ensure_body_restriction_root", self, skeleton) as Node3D
	hand_target_constraint_solver.call("sync_body_restriction_root", body_restriction_root, skeleton)
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
		hand_target_constraint_solver,
		_get_two_hand_constraint_config()
	) as Dictionary
	solve_result["dominant_slot_id"] = dominant_grip_slot_id if dominant_grip_slot_id != StringName() else &"hand_right"
	grip_debug_draw.call("update_debug_markers", grip_solve_root, solve_result, show_two_hand_grip_debug_markers)
	var right_solve: Dictionary = solve_result.get(&"hand_right", {})
	if bool(right_solve.get("active", false)) and is_support_hand_active(&"hand_right"):
		support_arm_ik_presenter.apply_solved_arm_targets(
			right_hand_ik_target,
			right_hand_pole_target,
			right_solve.get("corrected_target", right_hand_ik_target.global_position),
			right_solve.get("pole_target", right_hand_pole_target.global_position),
			support_arm_ik_target_smoothing_speed,
			delta
		)
	var left_solve: Dictionary = solve_result.get(&"hand_left", {})
	if bool(left_solve.get("active", false)) and is_support_hand_active(&"hand_left"):
		support_arm_ik_presenter.apply_solved_arm_targets(
			left_hand_ik_target,
			left_hand_pole_target,
			left_solve.get("corrected_target", left_hand_ik_target.global_position),
			left_solve.get("pole_target", left_hand_pole_target.global_position),
			support_arm_ik_target_smoothing_speed,
			delta
		)

func _refresh_support_arm_ik_influences() -> void:
	support_arm_ik_presenter.refresh_support_arm_ik_influences(
		enable_support_arm_ik,
		support_arm_ik_influence,
		right_arm_ik_modifier,
		left_arm_ik_modifier,
		is_support_hand_active(&"hand_right"),
		is_support_hand_active(&"hand_left"),
		get_arm_guidance_target(&"hand_right"),
		get_arm_guidance_target(&"hand_left")
	)

func _update_finger_grip_targets(delta: float) -> void:
	finger_grip_presenter.update_finger_grip_targets(
		skeleton,
		finger_grip_source_lookup,
		finger_grip_target_lookup,
		Callable(self, "_get_bone_world_position"),
		finger_grip_target_smoothing_speed,
		delta
	)

func _refresh_finger_grip_ik_influences() -> void:
	finger_grip_presenter.refresh_finger_ik_influences(
		enable_finger_grip_ik,
		finger_grip_ik_influence,
		finger_grip_modifier_lookup,
		finger_grip_source_lookup
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

func _get_bone_world_position(bone_name: StringName) -> Vector3:
	return rig_model_presenter.get_bone_world_position(global_position, skeleton, bone_name, bone_index_cache)

func _play_default_animation() -> void:
	locomotion_presenter.play_default_animation(animation_player, default_animation_name)

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
		"elbow_pole_side_offset_meters": support_arm_ik_pole_side_offset_meters,
		"elbow_pole_down_offset_meters": support_arm_ik_pole_down_offset_meters,
		"elbow_pole_back_offset_meters": support_arm_ik_pole_back_offset_meters,
	}
