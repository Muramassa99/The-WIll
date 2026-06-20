extends Resource
class_name MaterialAnimationEffectStub

const TRIGGER_MOTION_THRESHOLD: StringName = &"motion_threshold"
const TRIGGER_HIT: StringName = &"hit"
const TRIGGER_IDLE_LOOP: StringName = &"idle_loop"
const EFFECT_KIND_PARTICLE: StringName = &"particle"
const EFFECT_KIND_SOUND: StringName = &"sound"

@export var effect_stub_id: StringName = &""
@export var trigger_kind: StringName = TRIGGER_MOTION_THRESHOLD
@export var effect_kind: StringName = EFFECT_KIND_PARTICLE
@export_range(0.0, 1.0, 0.01) var animation_speed_threshold_ratio: float = 0.0
@export var particle_scene_path: String = ""
@export var sound_event_id: StringName = &""
@export_multiline var notes: String = ""

static func get_trigger_kind_ids() -> Array[StringName]:
	return [
		TRIGGER_MOTION_THRESHOLD,
		TRIGGER_HIT,
		TRIGGER_IDLE_LOOP,
	]

static func get_effect_kind_ids() -> Array[StringName]:
	return [
		EFFECT_KIND_PARTICLE,
		EFFECT_KIND_SOUND,
	]

func normalize() -> void:
	if not get_trigger_kind_ids().has(trigger_kind):
		trigger_kind = TRIGGER_MOTION_THRESHOLD
	if not get_effect_kind_ids().has(effect_kind):
		effect_kind = EFFECT_KIND_PARTICLE
	animation_speed_threshold_ratio = clampf(animation_speed_threshold_ratio, 0.0, 1.0)
