extends Resource
class_name CombatAnimationDraft

const DRAFT_KIND_SKILL: StringName = &"draft_skill"
const DRAFT_KIND_IDLE: StringName = &"draft_idle"
const IDLE_CONTEXT_COMBAT: StringName = &"idle_combat"
const IDLE_CONTEXT_NONCOMBAT: StringName = &"idle_noncombat"

@export var draft_id: StringName = &""
@export var display_name: String = ""
@export var draft_kind: StringName = DRAFT_KIND_SKILL
@export var context_id: StringName = StringName()
@export var owning_skill_id: StringName = &""
@export var legal_slot_id: StringName = &""
@export var preferred_grip_style_mode: StringName = &"grip_normal"
@export var authored_for_two_hand_only: bool = false
@export var motion_node_chain: Array[Resource] = []
@export var selected_motion_node_index: int = 0
@export var continuity_motion_node_index: int = 0
@export_range(0.0, 3.0, 0.01) var preview_playback_speed_scale: float = 1.0
@export var preview_loop_enabled: bool = false
@export var skill_name: String = ""
@export var skill_description: String = ""
@export_multiline var draft_notes: String = ""

static func get_draft_kind_ids() -> Array[StringName]:
	return [
		DRAFT_KIND_SKILL,
		DRAFT_KIND_IDLE,
	]

static func get_idle_context_ids() -> Array[StringName]:
	return [
		IDLE_CONTEXT_COMBAT,
		IDLE_CONTEXT_NONCOMBAT,
	]

static func create_default_skill_baseline(
	draft_id_value: StringName,
	display_name_value: String,
	skill_id: StringName,
	slot_id: StringName = StringName()
):
	var self_script: Script = load("res://core/models/combat_animation_draft.gd") as Script
	var draft = self_script.new() if self_script != null else null
	if draft == null:
		return null
	draft.draft_id = draft_id_value
	draft.display_name = display_name_value
	draft.draft_kind = DRAFT_KIND_SKILL
	draft.owning_skill_id = skill_id
	draft.legal_slot_id = slot_id
	draft.motion_node_chain = [
		_build_default_motion_node(0, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0.0, 0.0, -0.04)),
		_build_default_motion_node(1, Vector3(0.0, 0.0, -0.12), Vector3(0.0, 0.0, -0.12), Vector3(0.0, 0.0, 0.04), Vector3.ZERO),
	]
	draft.normalize()
	return draft

static func create_default_idle_baseline(
	draft_id_value: StringName,
	display_name_value: String,
	idle_context_id: StringName
):
	var self_script: Script = load("res://core/models/combat_animation_draft.gd") as Script
	var draft = self_script.new() if self_script != null else null
	if draft == null:
		return null
	draft.draft_id = draft_id_value
	draft.display_name = display_name_value
	draft.draft_kind = DRAFT_KIND_IDLE
	draft.context_id = idle_context_id
	draft.preview_loop_enabled = true
	draft.motion_node_chain = [
		_build_default_motion_node(0, Vector3.ZERO, Vector3.ZERO),
	]
	draft.normalize()
	return draft

static func _build_default_motion_node(
	index: int,
	tip_position: Vector3,
	pommel_position: Vector3,
	tip_curve_in: Vector3 = Vector3.ZERO,
	tip_curve_out: Vector3 = Vector3.ZERO
):
	var node_script: Script = load("res://core/models/combat_animation_motion_node.gd") as Script
	var motion_node = node_script.new() if node_script != null else null
	if motion_node == null:
		return null
	motion_node.node_index = index
	motion_node.node_id = StringName("motion_node_%02d" % index)
	motion_node.tip_position_local = tip_position
	motion_node.pommel_position_local = pommel_position
	motion_node.tip_curve_in_handle = tip_curve_in
	motion_node.tip_curve_out_handle = tip_curve_out
	motion_node.normalize()
	return motion_node

func normalize() -> void:
	if not get_draft_kind_ids().has(draft_kind):
		draft_kind = DRAFT_KIND_SKILL
	if draft_kind == DRAFT_KIND_IDLE and not get_idle_context_ids().has(context_id):
		context_id = IDLE_CONTEXT_COMBAT
	if preview_playback_speed_scale <= 0.0:
		preview_playback_speed_scale = 1.0
	for node_index: int in range(motion_node_chain.size()):
		var motion_node: Resource = motion_node_chain[node_index]
		if motion_node == null:
			var node_script: Script = load("res://core/models/combat_animation_motion_node.gd") as Script
			motion_node = node_script.new() if node_script != null else null
			if motion_node == null:
				continue
			motion_node_chain[node_index] = motion_node
		motion_node.set("node_index", node_index)
		if motion_node.has_method("normalize"):
			motion_node.call("normalize")
	selected_motion_node_index = clampi(selected_motion_node_index, 0, maxi(motion_node_chain.size() - 1, 0))
	continuity_motion_node_index = clampi(continuity_motion_node_index, 0, maxi(motion_node_chain.size() - 1, 0))

func ensure_minimum_baseline_nodes() -> void:
	if not motion_node_chain.is_empty():
		normalize()
		return
	if draft_kind == DRAFT_KIND_IDLE:
		motion_node_chain = [_build_default_motion_node(0, Vector3.ZERO, Vector3.ZERO)]
	else:
		motion_node_chain = [
			_build_default_motion_node(0, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0.0, 0.0, -0.04)),
			_build_default_motion_node(1, Vector3(0.0, 0.0, -0.12), Vector3(0.0, 0.0, -0.12), Vector3(0.0, 0.0, 0.04), Vector3.ZERO),
		]
	normalize()

func get_motion_node_count() -> int:
	return motion_node_chain.size()

func duplicate_draft():
	return duplicate(true)
