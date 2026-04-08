extends Node3D
class_name PlayerHumanoidRig

const RIGHT_HAND_BONE := &"CC_Base_R_Hand"
const LEFT_HAND_BONE := &"CC_Base_L_Hand"
const RIGHT_THIGH_BONE := &"CC_Base_R_Thigh"
const LEFT_THIGH_BONE := &"CC_Base_L_Thigh"
const RIGHT_CLAVICLE_BONE := &"CC_Base_R_Clavicle"
const LEFT_CLAVICLE_BONE := &"CC_Base_L_Clavicle"

@export_range(1.6, 2.4, 0.01) var standing_height_meters: float = 2.0
@export var right_hand_anchor_position: Vector3 = Vector3(-0.0025, 0.0969, 0.0190)
@export var right_hand_anchor_rotation_degrees: Vector3 = Vector3(0.0, 90.0, 0.0)
@export var left_hand_anchor_position: Vector3 = Vector3(0.0025, 0.0969, 0.0190)
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

@export_category("Locomotion")
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

@onready var josie_model: Node3D = $JosieModel
@onready var skeleton: Skeleton3D = $JosieModel/Josie/Skeleton3D
@onready var mesh_instance: MeshInstance3D = $JosieModel/Josie/Skeleton3D/Mesh
@onready var animation_player: AnimationPlayer = $JosieModel/AnimationPlayer

var resolved_visual_height_meters: float = 0.0
var current_animation_name: StringName = StringName()

func _ready() -> void:
	_apply_target_height_scale()
	_ensure_hand_attachment("RightHandAttachment", RIGHT_HAND_BONE, "RightHandItemAnchor", right_hand_anchor_position, right_hand_anchor_rotation_degrees)
	_ensure_hand_attachment("LeftHandAttachment", LEFT_HAND_BONE, "LeftHandItemAnchor", left_hand_anchor_position, left_hand_anchor_rotation_degrees)
	_ensure_stow_attachment("LeftShoulderStowAttachment", LEFT_CLAVICLE_BONE, "LeftShoulderStowAnchor", left_shoulder_stow_position, left_shoulder_stow_rotation_degrees)
	_ensure_stow_attachment("RightShoulderStowAttachment", RIGHT_CLAVICLE_BONE, "RightShoulderStowAnchor", right_shoulder_stow_position, right_shoulder_stow_rotation_degrees)
	_ensure_stow_attachment("LeftHipStowAttachment", LEFT_THIGH_BONE, "LeftHipStowAnchor", left_side_hip_stow_position, left_side_hip_stow_rotation_degrees)
	_ensure_stow_attachment("RightHipStowAttachment", RIGHT_THIGH_BONE, "RightHipStowAnchor", right_side_hip_stow_position, right_side_hip_stow_rotation_degrees)
	_ensure_stow_attachment("LeftLowerBackStowAttachment", LEFT_THIGH_BONE, "LeftLowerBackStowAnchor", left_lower_back_stow_position, left_lower_back_stow_rotation_degrees)
	_ensure_stow_attachment("RightLowerBackStowAttachment", RIGHT_THIGH_BONE, "RightLowerBackStowAnchor", right_lower_back_stow_position, right_lower_back_stow_rotation_degrees)
	_play_default_animation()

func get_standing_height_meters() -> float:
	return standing_height_meters

func get_visual_height_meters() -> float:
	return resolved_visual_height_meters

func get_current_animation_name() -> StringName:
	return current_animation_name

func has_animation_name(animation_name: StringName) -> bool:
	if animation_player == null or animation_name == StringName():
		return false
	return animation_player.has_animation(String(animation_name))

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

func update_locomotion_state(
		horizontal_speed: float,
		target_horizontal_speed: float,
		grounded: bool,
		vertical_velocity: float,
		sprinting: bool
	) -> void:
	var target_animation_name: StringName = _resolve_locomotion_animation_name(
		horizontal_speed,
		target_horizontal_speed,
		grounded,
		vertical_velocity,
		sprinting
	)
	_play_animation(target_animation_name)

func set_hand_grip_active(_slot_id: StringName, _active: bool) -> void:
	pass

func set_support_hand_active(_slot_id: StringName, _active: bool) -> void:
	pass

func set_arm_guidance_target(_slot_id: StringName, _target_node: Node3D) -> void:
	pass

func clear_arm_guidance_target(_slot_id: StringName) -> void:
	pass

func set_aim_follow_target(_local_yaw_radians: float, _local_pitch_radians: float) -> void:
	pass

func _apply_target_height_scale() -> void:
	if josie_model == null or mesh_instance == null or mesh_instance.mesh == null:
		return
	var source_height_meters: float = mesh_instance.mesh.get_aabb().size.y
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
