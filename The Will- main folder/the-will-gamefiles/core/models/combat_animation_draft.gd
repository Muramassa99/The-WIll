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
@export var point_chain: Array[Resource] = []
@export var selected_point_index: int = 0
@export var continuity_point_index: int = 0
@export_range(0.0, 3.0, 0.01) var preview_playback_speed_scale: float = 1.0
@export var preview_loop_enabled: bool = false
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
	draft.point_chain = [
		_build_default_point(0, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0.0, 0.0, -0.04)),
		_build_default_point(1, Vector3(0.0, 0.0, -0.12), Vector3(-8.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.04), Vector3.ZERO),
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
	draft.point_chain = [
		_build_default_point(0, Vector3.ZERO, Vector3.ZERO),
	]
	draft.normalize()
	return draft

static func _build_default_point(
	index: int,
	local_position: Vector3,
	local_rotation_degrees: Vector3,
	curve_in_handle_local: Vector3 = Vector3.ZERO,
	curve_out_handle_local: Vector3 = Vector3.ZERO
):
	var point_script: Script = load("res://core/models/combat_animation_point.gd") as Script
	var point = point_script.new() if point_script != null else null
	if point == null:
		return null
	point.point_index = index
	point.point_id = StringName("point_%02d" % index)
	point.local_target_position = local_position
	point.local_target_rotation_degrees = local_rotation_degrees
	point.curve_in_handle_local = curve_in_handle_local
	point.curve_out_handle_local = curve_out_handle_local
	point.active_plane_origin_local = local_position
	point.normalize()
	return point

func normalize() -> void:
	if not get_draft_kind_ids().has(draft_kind):
		draft_kind = DRAFT_KIND_SKILL
	if draft_kind == DRAFT_KIND_IDLE and not get_idle_context_ids().has(context_id):
		context_id = IDLE_CONTEXT_COMBAT
	if preview_playback_speed_scale <= 0.0:
		preview_playback_speed_scale = 1.0
	for point_index: int in range(point_chain.size()):
		var point: Resource = point_chain[point_index]
		if point == null:
			var point_script: Script = load("res://core/models/combat_animation_point.gd") as Script
			point = point_script.new() if point_script != null else null
			if point == null:
				continue
			point_chain[point_index] = point
		point.set("point_index", point_index)
		if point.has_method("normalize"):
			point.call("normalize")
	selected_point_index = clampi(selected_point_index, 0, maxi(point_chain.size() - 1, 0))
	continuity_point_index = clampi(continuity_point_index, 0, maxi(point_chain.size() - 1, 0))

func ensure_minimum_baseline_points() -> void:
	if not point_chain.is_empty():
		normalize()
		return
	if draft_kind == DRAFT_KIND_IDLE:
		point_chain = [_build_default_point(0, Vector3.ZERO, Vector3.ZERO)]
	else:
		point_chain = [
			_build_default_point(0, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0.0, 0.0, -0.04)),
			_build_default_point(1, Vector3(0.0, 0.0, -0.12), Vector3(-8.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.04), Vector3.ZERO),
		]
	normalize()

func get_point_count() -> int:
	return point_chain.size()

func duplicate_draft():
	return duplicate(true)
