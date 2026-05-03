extends RefCounted
class_name CombatAnimationSessionState

const FOCUS_TIP: StringName = &"tip"
const FOCUS_POMMEL: StringName = &"pommel"
const FOCUS_WEAPON: StringName = &"weapon"
const FOCUS_ARM_ROLL: StringName = &"arm_roll"

var current_weapon_wip_id: StringName = StringName()
var current_draft_ref: Resource = null
var current_motion_node_index: int = 0
var current_focus: StringName = FOCUS_TIP
var playback_active: bool = false
var onion_skin_enabled: bool = true

func cycle_focus() -> void:
	if current_focus == FOCUS_TIP:
		current_focus = FOCUS_POMMEL
	elif current_focus == FOCUS_POMMEL:
		current_focus = FOCUS_WEAPON
	elif current_focus == FOCUS_WEAPON:
		current_focus = FOCUS_ARM_ROLL
	else:
		current_focus = FOCUS_TIP

func is_tip_focused() -> bool:
	return current_focus == FOCUS_TIP

func is_pommel_focused() -> bool:
	return current_focus == FOCUS_POMMEL

func is_weapon_focused() -> bool:
	return current_focus == FOCUS_WEAPON

func is_arm_roll_focused() -> bool:
	return current_focus == FOCUS_ARM_ROLL

func reset() -> void:
	current_weapon_wip_id = StringName()
	current_draft_ref = null
	current_motion_node_index = 0
	current_focus = FOCUS_TIP
	playback_active = false
	onion_skin_enabled = true
