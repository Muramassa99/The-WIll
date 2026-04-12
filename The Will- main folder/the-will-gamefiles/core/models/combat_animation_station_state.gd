extends Resource
class_name CombatAnimationStationState

const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")

const AUTHORING_MODE_IDLE: StringName = &"author_idle"
const AUTHORING_MODE_SKILL: StringName = &"author_skill"
const IDLE_CONTEXT_COMBAT: StringName = &"idle_combat"
const IDLE_CONTEXT_NONCOMBAT: StringName = &"idle_noncombat"
const DEFAULT_MELEE_SKILL_DRAFT_IDS: Array[StringName] = [&"melee_baseline_a", &"melee_baseline_b"]
const DEFAULT_GENERIC_SKILL_DRAFT_IDS: Array[StringName] = [&"weapon_baseline_a"]

@export var station_version: int = 1
@export var station_schema_id: StringName = &"combat_animation_creator_v1"
@export var selected_authoring_mode: StringName = AUTHORING_MODE_SKILL
@export var selected_skill_id: StringName = &""
@export var selected_idle_context_id: StringName = &"idle_combat"
@export var uses_stage1_geometry_truth: bool = true
@export var uses_stage2_geometry_truth: bool = true
@export var auto_save_draft_continuity: bool = true
@export var idle_drafts: Array[Resource] = []
@export var skill_drafts: Array[Resource] = []
@export var default_skill_package_initialized: bool = false
@export_multiline var station_notes: String = ""

static func get_authoring_mode_ids() -> Array[StringName]:
	return [
		AUTHORING_MODE_IDLE,
		AUTHORING_MODE_SKILL,
	]

func normalize() -> void:
	if station_version <= 0:
		station_version = 1
	if not get_authoring_mode_ids().has(selected_authoring_mode):
		selected_authoring_mode = AUTHORING_MODE_SKILL
	if not _get_idle_context_ids().has(selected_idle_context_id):
		selected_idle_context_id = IDLE_CONTEXT_COMBAT
	idle_drafts = _normalize_draft_array(idle_drafts, CombatAnimationDraftScript.DRAFT_KIND_IDLE)
	skill_drafts = _normalize_draft_array(skill_drafts, CombatAnimationDraftScript.DRAFT_KIND_SKILL)

func ensure_default_baseline_content(
	builder_path_id: StringName,
	equipment_context_id: StringName,
	grip_style_mode: StringName = &"grip_normal"
) -> void:
	normalize()
	get_or_create_idle_draft(IDLE_CONTEXT_COMBAT, "Combat Idle", grip_style_mode)
	get_or_create_idle_draft(IDLE_CONTEXT_NONCOMBAT, "Noncombat Idle", grip_style_mode)
	if default_skill_package_initialized:
		return
	var default_skill_ids: Array[StringName] = _resolve_default_skill_draft_ids(builder_path_id, equipment_context_id)
	for skill_id: StringName in default_skill_ids:
		var draft_display_name: String = _build_default_skill_display_name(skill_id)
		get_or_create_skill_draft(skill_id, draft_display_name, grip_style_mode)
	default_skill_package_initialized = not skill_drafts.is_empty()
	if selected_skill_id == StringName() and not skill_drafts.is_empty():
		selected_skill_id = skill_drafts[0].get("owning_skill_id")

func get_or_create_idle_draft(idle_context_id: StringName, display_name: String, grip_style_mode: StringName = &"grip_normal") -> Resource:
	for idle_draft: Resource in idle_drafts:
		if idle_draft == null:
			continue
		if idle_draft.get("context_id") == idle_context_id:
			idle_draft.set("display_name", display_name)
			idle_draft.set("preferred_grip_style_mode", grip_style_mode)
			idle_draft.call("ensure_minimum_baseline_nodes")
			return idle_draft
	var draft_id: StringName = StringName("%s_%s" % [String(idle_context_id), "draft"])
	var draft: Resource = _build_default_idle_draft(draft_id, display_name, idle_context_id)
	draft.set("preferred_grip_style_mode", grip_style_mode)
	idle_drafts.append(draft)
	return draft

func get_or_create_skill_draft(skill_id: StringName, display_name: String, grip_style_mode: StringName = &"grip_normal") -> Resource:
	for skill_draft: Resource in skill_drafts:
		if skill_draft == null:
			continue
		if skill_draft.get("owning_skill_id") == skill_id:
			skill_draft.set("display_name", display_name)
			skill_draft.set("preferred_grip_style_mode", grip_style_mode)
			skill_draft.call("ensure_minimum_baseline_nodes")
			return skill_draft
	var draft: Resource = _build_default_skill_draft(StringName("%s_draft" % String(skill_id)), display_name, skill_id)
	draft.set("preferred_grip_style_mode", grip_style_mode)
	skill_drafts.append(draft)
	return draft

func duplicate_station_state() -> CombatAnimationStationState:
	return duplicate(true) as CombatAnimationStationState

func _normalize_draft_array(drafts: Array[Resource], expected_kind: StringName) -> Array[Resource]:
	var normalized_drafts: Array[Resource] = []
	for draft: Resource in drafts:
		if draft == null:
			continue
		draft.set("draft_kind", expected_kind)
		draft.call("ensure_minimum_baseline_nodes")
		normalized_drafts.append(draft)
	return normalized_drafts

func _resolve_default_skill_draft_ids(builder_path_id: StringName, equipment_context_id: StringName) -> Array[StringName]:
	if builder_path_id == &"builder_path_melee" and equipment_context_id == &"ctx_weapon":
		return DEFAULT_MELEE_SKILL_DRAFT_IDS.duplicate()
	return DEFAULT_GENERIC_SKILL_DRAFT_IDS.duplicate()

func _build_default_skill_display_name(skill_id: StringName) -> String:
	var skill_id_text: String = String(skill_id).replace("_", " ").strip_edges()
	if skill_id_text.is_empty():
		return "Baseline Skill"
	return skill_id_text.capitalize()

func _get_idle_context_ids() -> Array[StringName]:
	return [
		IDLE_CONTEXT_COMBAT,
		IDLE_CONTEXT_NONCOMBAT,
	]

func _build_default_idle_draft(draft_id: StringName, display_name: String, idle_context_id: StringName) -> Resource:
	var draft_script: Script = load("res://core/models/combat_animation_draft.gd") as Script
	var draft: Resource = draft_script.new() if draft_script != null else null
	if draft == null:
		return null
	draft.set("draft_id", draft_id)
	draft.set("display_name", display_name)
	draft.set("draft_kind", CombatAnimationDraftScript.DRAFT_KIND_IDLE)
	draft.set("context_id", idle_context_id)
	draft.set("preview_loop_enabled", true)
	draft.call("ensure_minimum_baseline_nodes")
	return draft

func _build_default_skill_draft(draft_id: StringName, display_name: String, skill_id: StringName) -> Resource:
	var draft_script: Script = load("res://core/models/combat_animation_draft.gd") as Script
	var draft: Resource = draft_script.new() if draft_script != null else null
	if draft == null:
		return null
	draft.set("draft_id", draft_id)
	draft.set("display_name", display_name)
	draft.set("draft_kind", CombatAnimationDraftScript.DRAFT_KIND_SKILL)
	draft.set("owning_skill_id", skill_id)
	draft.call("ensure_minimum_baseline_nodes")
	return draft
