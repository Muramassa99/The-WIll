extends RefCounted
class_name CombatAnimationSessionState

const FOCUS_TIP: StringName = &"tip"
const FOCUS_POMMEL: StringName = &"pommel"
const FOCUS_WEAPON: StringName = &"weapon"
const FOCUS_ARM_ROLL: StringName = &"arm_roll"
const FOCUS_RIGHT_ARM_ROLL: StringName = &"right_arm_roll"
const FOCUS_LEFT_ARM_ROLL: StringName = &"left_arm_roll"
const FOCUS_RIGHT_HAND_PROXY: StringName = &"right_hand_proxy"
const FOCUS_LEFT_HAND_PROXY: StringName = &"left_hand_proxy"

var current_weapon_wip_id: StringName = StringName()
var current_draft_ref: Resource = null
var current_motion_node_index: int = 0
var current_focus: StringName = FOCUS_TIP
var playback_active: bool = false
var onion_skin_enabled: bool = true

func cycle_focus(available_focus_ids: Array = []) -> void:
	var focus_ids: Array = available_focus_ids.duplicate()
	if focus_ids.is_empty():
		focus_ids = [
			FOCUS_TIP,
			FOCUS_POMMEL,
			FOCUS_WEAPON,
			FOCUS_ARM_ROLL,
		]
	var current_index: int = focus_ids.find(current_focus)
	if current_index < 0:
		current_focus = focus_ids[0] as StringName
		return
	current_focus = focus_ids[(current_index + 1) % focus_ids.size()] as StringName

func is_tip_focused() -> bool:
	return current_focus == FOCUS_TIP

func is_pommel_focused() -> bool:
	return current_focus == FOCUS_POMMEL

func is_weapon_focused() -> bool:
	return current_focus == FOCUS_WEAPON

func is_arm_roll_focused() -> bool:
	return current_focus == FOCUS_ARM_ROLL or current_focus == FOCUS_RIGHT_ARM_ROLL or current_focus == FOCUS_LEFT_ARM_ROLL

func is_right_arm_roll_focused() -> bool:
	return current_focus == FOCUS_ARM_ROLL or current_focus == FOCUS_RIGHT_ARM_ROLL

func is_left_arm_roll_focused() -> bool:
	return current_focus == FOCUS_LEFT_ARM_ROLL

func is_hand_proxy_focused() -> bool:
	return current_focus == FOCUS_RIGHT_HAND_PROXY or current_focus == FOCUS_LEFT_HAND_PROXY

func reset() -> void:
	current_weapon_wip_id = StringName()
	current_draft_ref = null
	current_motion_node_index = 0
	current_focus = FOCUS_TIP
	playback_active = false
	onion_skin_enabled = true
