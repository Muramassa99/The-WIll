extends Resource
class_name CombatRuntimeClip

const SCHEMA_VERSION := 1

const CLIP_KIND_SKILL_BODY: StringName = &"skill_body"
const CLIP_KIND_SKILL_PLAYBACK: StringName = &"skill_playback"
const CLIP_KIND_IDLE: StringName = &"idle"
const CLIP_KIND_BRIDGE: StringName = &"bridge"

@export var schema_version: int = SCHEMA_VERSION
@export var clip_id: StringName = &""
@export var clip_kind: StringName = CLIP_KIND_SKILL_PLAYBACK
@export var source_draft_id: StringName = &""
@export var source_skill_slot_id: StringName = &""
@export var source_idle_context_id: StringName = &""
@export var source_equipment_slot_id: StringName = &""
@export var source_weapon_wip_id: StringName = &""
@export var source_weapon_length_meters: float = 0.0
@export_range(0.01, 8.0, 0.01) var playback_speed_scale: float = 1.0
@export var loop_enabled: bool = false
@export var total_duration_seconds: float = 0.0
@export var sample_rate_hz: float = 30.0
@export var motion_node_chain: Array[Resource] = []
@export var baked_frame_times: PackedFloat32Array = PackedFloat32Array()
@export var baked_tip_positions_local: PackedVector3Array = PackedVector3Array()
@export var baked_pommel_positions_local: PackedVector3Array = PackedVector3Array()
@export var baked_weapon_orientation_degrees: PackedVector3Array = PackedVector3Array()
@export var baked_weapon_roll_degrees: PackedFloat32Array = PackedFloat32Array()
@export var baked_axial_reposition_offsets: PackedFloat32Array = PackedFloat32Array()
@export var baked_grip_seat_slide_offsets: PackedFloat32Array = PackedFloat32Array()
@export var baked_body_support_blends: PackedFloat32Array = PackedFloat32Array()
@export var baked_right_upperarm_roll_degrees: PackedFloat32Array = PackedFloat32Array()
@export var baked_left_upperarm_roll_degrees: PackedFloat32Array = PackedFloat32Array()
@export var baked_contact_grip_axes_local: PackedVector3Array = PackedVector3Array()
@export var baked_contact_axis_override_active: Array = []
@export var baked_two_hand_states: Array = []
@export var baked_primary_hand_slots: Array = []
@export var baked_grip_style_modes: Array = []
@export var compile_diagnostics: Array = []
@export var retargeted_count: int = 0
@export var degraded_node_count: int = 0
@export var hand_swap_bridge_count: int = 0

func normalize() -> void:
	schema_version = SCHEMA_VERSION
	if clip_id == StringName():
		clip_id = StringName("%s_runtime_clip" % String(clip_kind))
	if not _get_clip_kind_ids().has(clip_kind):
		clip_kind = CLIP_KIND_SKILL_PLAYBACK
	playback_speed_scale = maxf(playback_speed_scale, 0.01)
	source_weapon_length_meters = maxf(source_weapon_length_meters, 0.0)
	total_duration_seconds = maxf(total_duration_seconds, 0.0)
	sample_rate_hz = maxf(sample_rate_hz, 1.0)
	for node_index: int in range(motion_node_chain.size()):
		var motion_node: Resource = motion_node_chain[node_index]
		if motion_node == null:
			continue
		motion_node.set("node_index", node_index)
		if motion_node.has_method("normalize"):
			motion_node.call("normalize")

func is_playable() -> bool:
	return not motion_node_chain.is_empty()

func get_frame_count() -> int:
	return baked_frame_times.size()

func to_debug_state() -> Dictionary:
	return {
		"clip_id": clip_id,
		"clip_kind": clip_kind,
		"source_draft_id": source_draft_id,
		"source_skill_slot_id": source_skill_slot_id,
		"source_idle_context_id": source_idle_context_id,
		"source_equipment_slot_id": source_equipment_slot_id,
		"source_weapon_wip_id": source_weapon_wip_id,
		"source_weapon_length_meters": source_weapon_length_meters,
		"motion_node_count": motion_node_chain.size(),
		"frame_count": get_frame_count(),
		"total_duration_seconds": total_duration_seconds,
		"sample_rate_hz": sample_rate_hz,
		"playback_speed_scale": playback_speed_scale,
		"loop_enabled": loop_enabled,
		"retargeted_count": retargeted_count,
		"degraded_node_count": degraded_node_count,
		"hand_swap_bridge_count": hand_swap_bridge_count,
	}

func duplicate_clip():
	var duplicate_script: Script = get_script() as Script
	var duplicate_resource = duplicate_script.new() if duplicate_script != null else null
	if duplicate_resource == null:
		return null
	duplicate_resource.schema_version = schema_version
	duplicate_resource.clip_id = clip_id
	duplicate_resource.clip_kind = clip_kind
	duplicate_resource.source_draft_id = source_draft_id
	duplicate_resource.source_skill_slot_id = source_skill_slot_id
	duplicate_resource.source_idle_context_id = source_idle_context_id
	duplicate_resource.source_equipment_slot_id = source_equipment_slot_id
	duplicate_resource.source_weapon_wip_id = source_weapon_wip_id
	duplicate_resource.source_weapon_length_meters = source_weapon_length_meters
	duplicate_resource.playback_speed_scale = playback_speed_scale
	duplicate_resource.loop_enabled = loop_enabled
	duplicate_resource.total_duration_seconds = total_duration_seconds
	duplicate_resource.sample_rate_hz = sample_rate_hz
	duplicate_resource.motion_node_chain = _duplicate_motion_node_chain()
	duplicate_resource.baked_frame_times = baked_frame_times.duplicate()
	duplicate_resource.baked_tip_positions_local = baked_tip_positions_local.duplicate()
	duplicate_resource.baked_pommel_positions_local = baked_pommel_positions_local.duplicate()
	duplicate_resource.baked_weapon_orientation_degrees = baked_weapon_orientation_degrees.duplicate()
	duplicate_resource.baked_weapon_roll_degrees = baked_weapon_roll_degrees.duplicate()
	duplicate_resource.baked_axial_reposition_offsets = baked_axial_reposition_offsets.duplicate()
	duplicate_resource.baked_grip_seat_slide_offsets = baked_grip_seat_slide_offsets.duplicate()
	duplicate_resource.baked_body_support_blends = baked_body_support_blends.duplicate()
	duplicate_resource.baked_right_upperarm_roll_degrees = baked_right_upperarm_roll_degrees.duplicate()
	duplicate_resource.baked_left_upperarm_roll_degrees = baked_left_upperarm_roll_degrees.duplicate()
	duplicate_resource.baked_contact_grip_axes_local = baked_contact_grip_axes_local.duplicate()
	duplicate_resource.baked_contact_axis_override_active = baked_contact_axis_override_active.duplicate(true)
	duplicate_resource.baked_two_hand_states = baked_two_hand_states.duplicate(true)
	duplicate_resource.baked_primary_hand_slots = baked_primary_hand_slots.duplicate(true)
	duplicate_resource.baked_grip_style_modes = baked_grip_style_modes.duplicate(true)
	duplicate_resource.compile_diagnostics = compile_diagnostics.duplicate(true)
	duplicate_resource.retargeted_count = retargeted_count
	duplicate_resource.degraded_node_count = degraded_node_count
	duplicate_resource.hand_swap_bridge_count = hand_swap_bridge_count
	duplicate_resource.normalize()
	return duplicate_resource

func _duplicate_motion_node_chain() -> Array[Resource]:
	var duplicated_chain: Array[Resource] = []
	for node_variant: Variant in motion_node_chain:
		var source_node: Resource = node_variant as Resource
		if source_node == null:
			continue
		var duplicate_node: Resource = source_node.duplicate(true)
		if source_node.has_method("duplicate_node"):
			duplicate_node = source_node.call("duplicate_node") as Resource
		if duplicate_node == null:
			continue
		duplicate_node.set("node_index", duplicated_chain.size())
		if duplicate_node.has_method("normalize"):
			duplicate_node.call("normalize")
		duplicated_chain.append(duplicate_node)
	return duplicated_chain

static func _get_clip_kind_ids() -> Array[StringName]:
	return [
		CLIP_KIND_SKILL_BODY,
		CLIP_KIND_SKILL_PLAYBACK,
		CLIP_KIND_IDLE,
		CLIP_KIND_BRIDGE,
	]
