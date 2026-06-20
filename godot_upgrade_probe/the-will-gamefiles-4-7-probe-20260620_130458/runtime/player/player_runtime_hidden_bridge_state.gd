extends RefCounted
class_name PlayerRuntimeHiddenBridgeState

const KIND_NONE: StringName = &""
const KIND_SKILL_ENTRY: StringName = &"skill_entry"
const KIND_SKILL_INTERRUPT_ENTRY: StringName = &"skill_interrupt_entry"
const KIND_SKILL_RECOVERY: StringName = &"skill_recovery"
const KIND_DRAW_TO_COMBAT_IDLE: StringName = &"draw_to_combat_idle"
const KIND_STOW_TO_NONCOMBAT_IDLE: StringName = &"stow_to_noncombat_idle"

var active: bool = false
var kind: StringName = KIND_NONE
var last_kind: StringName = KIND_NONE
var source_context_id: StringName = StringName()
var target_context_id: StringName = StringName()
var dominant_slot_id: StringName = StringName()
var duration_seconds: float = 0.0
var elapsed_seconds: float = 0.0
var source_grip_style_mode: StringName = StringName()
var target_grip_style_mode: StringName = StringName()
var grip_swap_active: bool = false
var completion_count: int = 0
var recent_kinds: Array[StringName] = []

func begin(
	bridge_kind: StringName,
	bridge_duration_seconds: float,
	slot_id: StringName = StringName(),
	source_context: StringName = StringName(),
	target_context: StringName = StringName(),
	source_grip: StringName = StringName(),
	target_grip: StringName = StringName(),
	bridge_grip_swap_active: bool = false,
	bridge_should_be_active: bool = true
) -> void:
	kind = _normalize_kind(bridge_kind)
	last_kind = kind
	if kind != KIND_NONE:
		recent_kinds.append(kind)
		while recent_kinds.size() > 8:
			recent_kinds.remove_at(0)
	duration_seconds = maxf(bridge_duration_seconds, 0.0)
	elapsed_seconds = 0.0
	dominant_slot_id = slot_id
	source_context_id = source_context
	target_context_id = target_context
	source_grip_style_mode = source_grip
	target_grip_style_mode = target_grip
	grip_swap_active = bridge_grip_swap_active
	active = bridge_should_be_active and kind != KIND_NONE and duration_seconds > 0.0

func advance(delta_seconds: float) -> void:
	if not active:
		return
	elapsed_seconds = minf(duration_seconds, elapsed_seconds + maxf(delta_seconds, 0.0))
	if elapsed_seconds >= duration_seconds:
		complete()

func complete() -> void:
	if active:
		completion_count += 1
	active = false
	elapsed_seconds = duration_seconds

func clear() -> void:
	active = false
	kind = KIND_NONE
	source_context_id = StringName()
	target_context_id = StringName()
	dominant_slot_id = StringName()
	duration_seconds = 0.0
	elapsed_seconds = 0.0
	source_grip_style_mode = StringName()
	target_grip_style_mode = StringName()
	grip_swap_active = false

func reset_history() -> void:
	clear()
	last_kind = KIND_NONE
	completion_count = 0
	recent_kinds.clear()

func get_remaining_seconds() -> float:
	if not active:
		return 0.0
	return maxf(duration_seconds - elapsed_seconds, 0.0)

func to_debug_state() -> Dictionary:
	return {
		"active": active,
		"kind": kind,
		"last_kind": last_kind,
		"source_context_id": source_context_id,
		"target_context_id": target_context_id,
		"dominant_slot_id": dominant_slot_id,
		"duration_seconds": duration_seconds,
		"elapsed_seconds": elapsed_seconds,
		"remaining_seconds": get_remaining_seconds(),
		"source_grip_style_mode": source_grip_style_mode,
		"target_grip_style_mode": target_grip_style_mode,
		"grip_swap_active": grip_swap_active,
		"completion_count": completion_count,
		"recent_kinds": recent_kinds.duplicate(),
	}

func _normalize_kind(bridge_kind: StringName) -> StringName:
	match bridge_kind:
		KIND_SKILL_ENTRY, KIND_SKILL_INTERRUPT_ENTRY, KIND_SKILL_RECOVERY, KIND_DRAW_TO_COMBAT_IDLE, KIND_STOW_TO_NONCOMBAT_IDLE:
			return bridge_kind
		_:
			return KIND_NONE
