extends Resource
class_name CombatAnimationRetargetNode

const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")

const SCHEMA_ID: StringName = &"combat_animation_retarget_node_v1"
const ORIGIN_SPACE_PRIMARY_SHOULDER: StringName = &"primary_shoulder"
const ORIGIN_SPACE_TORSO_FRAME: StringName = &"torso_frame"
const DEFAULT_GRIP_SEAT_SLIDE_OFFSET: float = 0.2
const DEFAULT_SECONDARY_GRIP_SEAT_SLIDE_OFFSET: float = 0.0

@export var schema_id: StringName = SCHEMA_ID
@export var enabled: bool = false
@export var origin_space: StringName = ORIGIN_SPACE_PRIMARY_SHOULDER
@export var origin_id: StringName = CombatOriginRecordScript.ORIGIN_PRIMARY_SHOULDER
@export var parent_origin_id: StringName = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
@export var pivot_direction_local: Vector3 = Vector3.FORWARD
@export var pivot_direction_origin_id: StringName = CombatOriginRecordScript.ORIGIN_PRIMARY_SHOULDER
@export_range(0.0, 1.0, 0.001) var pivot_range_percent: float = 0.0
@export_range(0.0, 1.0, 0.001) var pivot_ratio_from_pommel: float = 0.5
@export var weapon_axis_local: Vector3 = Vector3.FORWARD
@export var weapon_axis_origin_id: StringName = CombatOriginRecordScript.ORIGIN_PRIMARY_SHOULDER
@export var weapon_orientation_degrees: Vector3 = Vector3.ZERO
@export var weapon_orientation_authored: bool = false
@export var weapon_roll_degrees: float = 0.0
@export var axial_reposition_offset: float = 0.0
@export var grip_seat_slide_offset: float = DEFAULT_GRIP_SEAT_SLIDE_OFFSET
@export var secondary_grip_seat_slide_offset: float = DEFAULT_SECONDARY_GRIP_SEAT_SLIDE_OFFSET
@export var body_support_blend: float = 0.0
@export var right_upperarm_roll_degrees: float = 0.0
@export var left_upperarm_roll_degrees: float = 0.0
@export_range(0.0, 2.0, 0.01) var transition_duration_seconds: float = 0.18
@export var preferred_grip_style_mode: StringName = &"grip_normal"
@export var two_hand_state: StringName = &"two_hand_auto"
@export var primary_hand_slot: StringName = &"primary_hand_auto"
@export var source_weapon_length_meters: float = 0.0
@export var source_min_radius_meters: float = 0.0
@export var source_max_radius_meters: float = 0.0
@export var tip_curve_in_normalized: Vector3 = Vector3.ZERO
@export var tip_curve_out_normalized: Vector3 = Vector3.ZERO
@export var pommel_curve_in_normalized: Vector3 = Vector3.ZERO
@export var pommel_curve_out_normalized: Vector3 = Vector3.ZERO

func normalize() -> void:
	schema_id = SCHEMA_ID
	if origin_id == StringName():
		origin_id = _resolve_origin_id_for_space(origin_space)
	if parent_origin_id == StringName():
		parent_origin_id = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	if pivot_direction_origin_id == StringName():
		pivot_direction_origin_id = origin_id
	if weapon_axis_origin_id == StringName():
		weapon_axis_origin_id = origin_id
	if pivot_direction_local.length_squared() <= 0.000001:
		pivot_direction_local = Vector3.FORWARD
	else:
		pivot_direction_local = pivot_direction_local.normalized()
	if weapon_axis_local.length_squared() <= 0.000001:
		weapon_axis_local = Vector3.FORWARD
	else:
		weapon_axis_local = weapon_axis_local.normalized()
	pivot_range_percent = clampf(pivot_range_percent, 0.0, 1.0)
	pivot_ratio_from_pommel = clampf(pivot_ratio_from_pommel, 0.0, 1.0)
	weapon_roll_degrees = clampf(weapon_roll_degrees, -120.0, 120.0)
	axial_reposition_offset = clampf(axial_reposition_offset, -1.0, 1.0)
	grip_seat_slide_offset = clampf(grip_seat_slide_offset, 0.0, 1.0)
	secondary_grip_seat_slide_offset = clampf(secondary_grip_seat_slide_offset, 0.0, 1.0)
	body_support_blend = clampf(body_support_blend, 0.0, 1.0)
	right_upperarm_roll_degrees = clampf(right_upperarm_roll_degrees, -180.0, 180.0)
	left_upperarm_roll_degrees = clampf(left_upperarm_roll_degrees, -180.0, 180.0)
	transition_duration_seconds = maxf(transition_duration_seconds, 0.0)
	source_weapon_length_meters = maxf(source_weapon_length_meters, 0.0)
	source_min_radius_meters = maxf(source_min_radius_meters, 0.0)
	source_max_radius_meters = maxf(source_max_radius_meters, 0.0)

func duplicate_retarget_node() -> CombatAnimationRetargetNode:
	return duplicate(true) as CombatAnimationRetargetNode

static func _resolve_origin_id_for_space(space_id: StringName) -> StringName:
	match space_id:
		ORIGIN_SPACE_PRIMARY_SHOULDER:
			return CombatOriginRecordScript.ORIGIN_PRIMARY_SHOULDER
		ORIGIN_SPACE_TORSO_FRAME:
			return CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE
		_:
			return CombatOriginRecordScript.ORIGIN_PRIMARY_SHOULDER
