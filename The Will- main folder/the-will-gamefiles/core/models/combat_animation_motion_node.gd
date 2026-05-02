extends Resource
class_name CombatAnimationMotionNode

const TWO_HAND_STATE_AUTO: StringName = &"two_hand_auto"
const TWO_HAND_STATE_ONE_HAND: StringName = &"two_hand_one_hand"
const TWO_HAND_STATE_TWO_HAND: StringName = &"two_hand_two_hand"
const PRIMARY_HAND_AUTO: StringName = &"primary_hand_auto"
const PRIMARY_HAND_RIGHT: StringName = &"hand_right"
const PRIMARY_HAND_LEFT: StringName = &"hand_left"
const TRANSITION_KIND_NONE: StringName = &""
const TRANSITION_KIND_GRIP_STYLE_SWAP: StringName = &"grip_style_swap"
const TRANSITION_KIND_PRIMARY_HAND_SWAP: StringName = &"primary_hand_swap"
const TRANSITION_KIND_TWO_HAND_STATE_SWAP: StringName = &"two_hand_state_swap"

@export var node_id: StringName = &""
@export var node_index: int = 0

## Weapon frame orientation. Tip and pommel define the main weapon axis.
@export var weapon_orientation_degrees: Vector3 = Vector3.ZERO
@export var weapon_orientation_authored: bool = false

## Tip Control - authored weapon tip position in the local authoring frame.
@export var tip_position_local: Vector3 = Vector3.ZERO
@export var tip_curve_in_handle: Vector3 = Vector3.ZERO
@export var tip_curve_out_handle: Vector3 = Vector3.ZERO

## Pommel Control - authored weapon pommel position in the local authoring frame.
@export var pommel_position_local: Vector3 = Vector3.ZERO
@export var pommel_curve_in_handle: Vector3 = Vector3.ZERO
@export var pommel_curve_out_handle: Vector3 = Vector3.ZERO

## Weapon Orientation - roll around grip axis (+/-120 degrees).
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
@export var primary_hand_slot: StringName = PRIMARY_HAND_AUTO

## Optional normalized motion intent used by retarget-aware resolvers.
@export var retarget_node: Resource = null

## Meta
@export var generated_transition_node: bool = false
@export var generated_transition_kind: StringName = TRANSITION_KIND_NONE
@export var locked_for_authoring: bool = false
@export_multiline var draft_notes: String = ""

static func get_two_hand_state_ids() -> Array[StringName]:
	return [
		TWO_HAND_STATE_AUTO,
		TWO_HAND_STATE_ONE_HAND,
		TWO_HAND_STATE_TWO_HAND,
	]

static func get_primary_hand_slot_ids() -> Array[StringName]:
	return [
		PRIMARY_HAND_AUTO,
		PRIMARY_HAND_RIGHT,
		PRIMARY_HAND_LEFT,
	]

static func normalize_primary_hand_slot(slot_id: StringName) -> StringName:
	if get_primary_hand_slot_ids().has(slot_id):
		return slot_id
	return PRIMARY_HAND_AUTO

static func get_generated_transition_kind_ids() -> Array[StringName]:
	return [
		TRANSITION_KIND_NONE,
		TRANSITION_KIND_GRIP_STYLE_SWAP,
		TRANSITION_KIND_PRIMARY_HAND_SWAP,
		TRANSITION_KIND_TWO_HAND_STATE_SWAP,
	]

func normalize() -> void:
	if node_id == StringName():
		node_id = StringName("motion_node_%02d" % maxi(node_index, 0))
	if not get_two_hand_state_ids().has(two_hand_state):
		two_hand_state = TWO_HAND_STATE_AUTO
	primary_hand_slot = normalize_primary_hand_slot(primary_hand_slot)
	weapon_roll_degrees = clampf(weapon_roll_degrees, -120.0, 120.0)
	if transition_duration_seconds < 0.0:
		transition_duration_seconds = 0.0
	if not get_generated_transition_kind_ids().has(generated_transition_kind):
		generated_transition_kind = TRANSITION_KIND_NONE
	if retarget_node != null and retarget_node.has_method("normalize"):
		retarget_node.call("normalize")
	if generated_transition_node:
		locked_for_authoring = true
	elif generated_transition_kind == TRANSITION_KIND_NONE:
		locked_for_authoring = false

func duplicate_node() -> CombatAnimationMotionNode:
	return duplicate(true) as CombatAnimationMotionNode
