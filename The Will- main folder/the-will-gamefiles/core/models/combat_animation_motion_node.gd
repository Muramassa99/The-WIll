extends Resource
class_name CombatAnimationMotionNode

const TWO_HAND_STATE_AUTO: StringName = &"two_hand_auto"
const TWO_HAND_STATE_ONE_HAND: StringName = &"two_hand_one_hand"
const TWO_HAND_STATE_TWO_HAND: StringName = &"two_hand_two_hand"

@export var node_id: StringName = &""
@export var node_index: int = 0

## Trajectory Plane — orientation and vertical displacement
@export var trajectory_plane_orientation_degrees: Vector3 = Vector3.ZERO
@export var trajectory_plane_vertical_offset: float = 0.0

## Tip Control — position on trajectory plane surface
@export var tip_position_local: Vector3 = Vector3.ZERO
@export var tip_curve_in_handle: Vector3 = Vector3.ZERO
@export var tip_curve_out_handle: Vector3 = Vector3.ZERO

## Pommel Control — position on sphere around tip (radius = weapon_total_length_calculated)
@export var pommel_position_local: Vector3 = Vector3.ZERO
@export var pommel_curve_in_handle: Vector3 = Vector3.ZERO
@export var pommel_curve_out_handle: Vector3 = Vector3.ZERO

## Weapon Orientation — roll around grip axis (±120°)
@export_range(-120.0, 120.0, 1.0) var weapon_roll_degrees: float = 0.0

## Grip Adjustments
@export var axial_reposition_offset: float = 0.0
@export var grip_seat_slide_offset: float = 0.0

## Timing
@export_range(0.0, 2.0, 0.01) var transition_duration_seconds: float = 0.18

## Body
@export_range(0.0, 1.0, 0.01) var body_support_blend: float = 0.0
@export var preferred_grip_style_mode: StringName = &"grip_normal"
@export var two_hand_state: StringName = TWO_HAND_STATE_AUTO

## Meta
@export_multiline var draft_notes: String = ""

static func get_two_hand_state_ids() -> Array[StringName]:
	return [
		TWO_HAND_STATE_AUTO,
		TWO_HAND_STATE_ONE_HAND,
		TWO_HAND_STATE_TWO_HAND,
	]

func normalize() -> void:
	if node_id == StringName():
		node_id = StringName("motion_node_%02d" % maxi(node_index, 0))
	if not get_two_hand_state_ids().has(two_hand_state):
		two_hand_state = TWO_HAND_STATE_AUTO
	weapon_roll_degrees = clampf(weapon_roll_degrees, -120.0, 120.0)
	if transition_duration_seconds < 0.0:
		transition_duration_seconds = 0.0

func duplicate_node() -> CombatAnimationMotionNode:
	return duplicate(true) as CombatAnimationMotionNode
