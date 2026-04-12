extends Resource
class_name CombatAnimationPoint

const TWO_HAND_STATE_AUTO: StringName = &"two_hand_auto"
const TWO_HAND_STATE_ONE_HAND: StringName = &"two_hand_one_hand"
const TWO_HAND_STATE_TWO_HAND: StringName = &"two_hand_two_hand"

@export var point_id: StringName = &""
@export var point_index: int = 0
@export var local_target_position: Vector3 = Vector3.ZERO
@export var local_target_rotation_degrees: Vector3 = Vector3.ZERO
@export var curve_in_handle_local: Vector3 = Vector3.ZERO
@export var curve_out_handle_local: Vector3 = Vector3.ZERO
@export var active_plane_origin_local: Vector3 = Vector3.ZERO
@export var active_plane_normal_local: Vector3 = Vector3.FORWARD
@export var active_plane_axis_u_local: Vector3 = Vector3.RIGHT
@export var active_plane_axis_v_local: Vector3 = Vector3.UP
@export_range(0.0, 2.0, 0.01) var transition_duration_seconds: float = 0.18
@export_range(0.0, 1.0, 0.01) var body_support_blend: float = 0.0
@export var preferred_grip_style_mode: StringName = &"grip_normal"
@export var two_hand_state: StringName = TWO_HAND_STATE_AUTO
@export var committed: bool = true

static func get_two_hand_state_ids() -> Array[StringName]:
	return [
		TWO_HAND_STATE_AUTO,
		TWO_HAND_STATE_ONE_HAND,
		TWO_HAND_STATE_TWO_HAND,
	]

func normalize() -> void:
	if point_id == StringName():
		point_id = StringName("point_%02d" % max(point_index, 0))
	if not get_two_hand_state_ids().has(two_hand_state):
		two_hand_state = TWO_HAND_STATE_AUTO
	if active_plane_normal_local.length_squared() <= 0.000001:
		active_plane_normal_local = Vector3.FORWARD
	if active_plane_axis_u_local.length_squared() <= 0.000001:
		active_plane_axis_u_local = Vector3.RIGHT
	if active_plane_axis_v_local.length_squared() <= 0.000001:
		active_plane_axis_v_local = Vector3.UP
	if transition_duration_seconds < 0.0:
		transition_duration_seconds = 0.0

func duplicate_point() -> CombatAnimationPoint:
	return duplicate(true) as CombatAnimationPoint
