extends Resource
class_name CraftedItemWIP

const STOW_SHOULDER_HANGING := &"stow_shoulder_hanging"
const STOW_SIDE_HIP := &"stow_side_hip"
const STOW_LOWER_BACK := &"stow_lower_back"
const GRIP_NORMAL := &"grip_normal"
const GRIP_REVERSE := &"grip_reverse"

@export var wip_id: StringName = &""
@export var forge_project_name: String = ""
@export_multiline var forge_project_notes: String = ""
@export var creator_id: StringName = &""
@export var created_timestamp: float = 0.0
@export var forge_intent: StringName = &""
@export var equipment_context: StringName = &""
@export var stow_position_mode: StringName = STOW_SHOULDER_HANGING
@export var grip_style_mode: StringName = GRIP_NORMAL
@export var layers: Array[LayerAtom] = []
@export var latest_baked_profile_snapshot: BakedProfile

static func get_stow_position_modes() -> Array[StringName]:
	return [
		STOW_SHOULDER_HANGING,
		STOW_SIDE_HIP,
		STOW_LOWER_BACK
	]

static func normalize_stow_position_mode(stow_mode: StringName) -> StringName:
	if get_stow_position_modes().has(stow_mode):
		return stow_mode
	return STOW_SHOULDER_HANGING

static func get_stow_position_label(stow_mode: StringName) -> String:
	match normalize_stow_position_mode(stow_mode):
		STOW_SIDE_HIP:
			return "Side Hip"
		STOW_LOWER_BACK:
			return "Lower Back"
		_:
			return "Shoulder Hanging"

static func get_stow_position_note(stow_mode: StringName) -> String:
	match normalize_stow_position_mode(stow_mode):
		STOW_SIDE_HIP:
			return "Recommended for short and medium weapon builds."
		STOW_LOWER_BACK:
			return "Recommended for short weapon builds."
		_:
			return "Recommended for medium and long weapon builds."

static func get_grip_style_modes() -> Array[StringName]:
	return [
		GRIP_NORMAL,
		GRIP_REVERSE
	]

static func normalize_grip_style_mode(grip_mode: StringName) -> StringName:
	if get_grip_style_modes().has(grip_mode):
		return grip_mode
	return GRIP_NORMAL

static func supports_reverse_grip_for_context(resolved_forge_intent: StringName, resolved_equipment_context: StringName) -> bool:
	return resolved_forge_intent == &"intent_melee" and resolved_equipment_context == &"ctx_weapon"

static func resolve_supported_grip_style(grip_mode: StringName, resolved_forge_intent: StringName, resolved_equipment_context: StringName) -> StringName:
	var normalized_mode: StringName = normalize_grip_style_mode(grip_mode)
	if normalized_mode == GRIP_REVERSE and not supports_reverse_grip_for_context(resolved_forge_intent, resolved_equipment_context):
		return GRIP_NORMAL
	return normalized_mode

static func get_grip_style_label(grip_mode: StringName) -> String:
	match normalize_grip_style_mode(grip_mode):
		GRIP_REVERSE:
			return "Reverse Grip"
		_:
			return "Normal Grip"

static func get_grip_style_note(grip_mode: StringName) -> String:
	match normalize_grip_style_mode(grip_mode):
		GRIP_REVERSE:
			return "Reverse grip shortens the weapon's effective reach significantly and disables two-handed weapon techniques, but grants +25% attack speed."
		_:
			return "Standard forward-facing hold. Supports normal one-handed and two-handed weapon use when available."
