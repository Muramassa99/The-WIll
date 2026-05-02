extends Resource
class_name CombatAnimationStationState

const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")

const AUTHORING_MODE_IDLE: StringName = &"author_idle"
const AUTHORING_MODE_SKILL: StringName = &"author_skill"
const IDLE_CONTEXT_COMBAT: StringName = &"idle_combat"
const IDLE_CONTEXT_NONCOMBAT: StringName = &"idle_noncombat"
const SKILL_BASELINE_SCHEMA_VERSION := 3

@export var station_version: int = SKILL_BASELINE_SCHEMA_VERSION
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

static func get_authoring_idle_context_ids() -> Array[StringName]:
	return [
		IDLE_CONTEXT_COMBAT,
		IDLE_CONTEXT_NONCOMBAT,
	]

static func get_authoring_skill_slot_ids() -> Array[StringName]:
	var slot_ids: Array[StringName] = PlayerSkillSlotStateScript.SKILL_SLOT_IDS.duplicate()
	slot_ids.append(PlayerSkillSlotStateScript.BLOCK_SLOT_ID)
	return slot_ids

func normalize() -> void:
	var requires_skill_baseline_reset: bool = station_version < SKILL_BASELINE_SCHEMA_VERSION
	station_version = SKILL_BASELINE_SCHEMA_VERSION
	if requires_skill_baseline_reset:
		_clear_skill_drafts_for_baseline_migration()
	if not get_authoring_mode_ids().has(selected_authoring_mode):
		selected_authoring_mode = AUTHORING_MODE_SKILL
	if not is_authoring_idle_context_id(selected_idle_context_id):
		selected_idle_context_id = IDLE_CONTEXT_COMBAT
	idle_drafts = _normalize_draft_array(idle_drafts, CombatAnimationDraftScript.DRAFT_KIND_IDLE)
	skill_drafts = _normalize_skill_draft_array(skill_drafts)
	if _find_skill_draft_by_identifier(selected_skill_id) == null:
		selected_skill_id = StringName()
	if selected_skill_id == StringName() and not skill_drafts.is_empty():
		selected_skill_id = StringName(skill_drafts[0].get("owning_skill_id"))

func _clear_skill_drafts_for_baseline_migration() -> void:
	skill_drafts.clear()
	selected_skill_id = StringName()
	default_skill_package_initialized = false

func ensure_default_baseline_content(
	builder_path_id: StringName,
	equipment_context_id: StringName,
	grip_style_mode: StringName = &"grip_normal",
	stow_anchor_mode: StringName = CombatAnimationDraftScript.STOW_ANCHOR_SHOULDER_HANGING
) -> void:
	normalize()
	get_or_create_idle_draft(IDLE_CONTEXT_COMBAT, "Combat Idle", grip_style_mode)
	get_or_create_idle_draft(IDLE_CONTEXT_NONCOMBAT, "Noncombat Idle", grip_style_mode, stow_anchor_mode)
	if default_skill_package_initialized:
		return
	var default_skill_ids: Array[StringName] = _resolve_default_skill_draft_ids(builder_path_id, equipment_context_id)
	for skill_id: StringName in default_skill_ids:
		var draft_display_name: String = _build_default_skill_display_name(skill_id)
		var slot_id: StringName = skill_id if get_authoring_skill_slot_ids().has(skill_id) else StringName()
		get_or_create_skill_draft(skill_id, draft_display_name, grip_style_mode, slot_id)
	default_skill_package_initialized = not skill_drafts.is_empty()
	if selected_skill_id == StringName() and not skill_drafts.is_empty():
		selected_skill_id = skill_drafts[0].get("owning_skill_id")

func get_or_create_idle_draft(
	idle_context_id: StringName,
	display_name: String,
	grip_style_mode: StringName = &"grip_normal",
	stow_anchor_mode: StringName = CombatAnimationDraftScript.STOW_ANCHOR_SHOULDER_HANGING
) -> Resource:
	if not is_authoring_idle_context_id(idle_context_id):
		return null
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
	draft.set("stow_anchor_mode", CombatAnimationDraftScript.normalize_stow_anchor_mode(stow_anchor_mode))
	idle_drafts.append(draft)
	return draft

func get_or_create_skill_draft(
	skill_id: StringName,
	display_name: String,
	grip_style_mode: StringName = &"grip_normal",
	slot_id: StringName = StringName()
) -> Resource:
	var resolved_slot_id: StringName = slot_id if is_authoring_skill_slot_id(slot_id) else skill_id
	if not is_authoring_skill_slot_id(resolved_slot_id):
		return null
	for skill_draft: Resource in skill_drafts:
		if skill_draft == null:
			continue
		if StringName(skill_draft.get("owning_skill_id")) == resolved_slot_id:
			skill_draft.set("display_name", display_name)
			skill_draft.set("preferred_grip_style_mode", grip_style_mode)
			skill_draft.set("legal_slot_id", resolved_slot_id)
			skill_draft.set("owning_skill_id", resolved_slot_id)
			skill_draft.call("ensure_minimum_baseline_nodes")
			return skill_draft
	var draft: Resource = _build_default_skill_draft(
		StringName("%s_draft" % String(resolved_slot_id)),
		display_name,
		resolved_slot_id,
		resolved_slot_id
	)
	draft.set("preferred_grip_style_mode", grip_style_mode)
	skill_drafts.append(draft)
	return draft

func duplicate_station_state() -> CombatAnimationStationState:
	return duplicate(true) as CombatAnimationStationState

func _normalize_draft_array(drafts: Array[Resource], expected_kind: StringName) -> Array[Resource]:
	var normalized_drafts: Array[Resource] = []
	var idle_drafts_by_context: Dictionary = {}
	for draft: Resource in drafts:
		if draft == null:
			continue
		draft.set("draft_kind", expected_kind)
		if expected_kind == CombatAnimationDraftScript.DRAFT_KIND_IDLE:
			var idle_context_id: StringName = StringName(draft.get("context_id"))
			if not is_authoring_idle_context_id(idle_context_id):
				continue
			draft.call("ensure_minimum_baseline_nodes")
			var existing: Resource = idle_drafts_by_context.get(idle_context_id, null) as Resource
			if existing == null or _score_idle_draft(draft) >= _score_idle_draft(existing):
				idle_drafts_by_context[idle_context_id] = draft
			continue
		draft.call("ensure_minimum_baseline_nodes")
		normalized_drafts.append(draft)
	if expected_kind == CombatAnimationDraftScript.DRAFT_KIND_IDLE:
		for idle_context_id: StringName in get_authoring_idle_context_ids():
			var idle_draft: Resource = idle_drafts_by_context.get(idle_context_id, null) as Resource
			if idle_draft != null:
				normalized_drafts.append(idle_draft)
	return normalized_drafts

func _normalize_skill_draft_array(drafts: Array[Resource]) -> Array[Resource]:
	var normalized_drafts: Array[Resource] = []
	var drafts_by_slot_id: Dictionary = {}
	for draft: Resource in drafts:
		if draft == null:
			continue
		draft.set("draft_kind", CombatAnimationDraftScript.DRAFT_KIND_SKILL)
		draft.call("ensure_minimum_baseline_nodes")
		var slot_id: StringName = _resolve_skill_draft_slot_id(draft)
		if not is_authoring_skill_slot_id(slot_id):
			continue
		draft.set("legal_slot_id", slot_id)
		draft.set("owning_skill_id", slot_id)
		var existing: Resource = drafts_by_slot_id.get(slot_id, null) as Resource
		if existing == null or _score_skill_draft(draft) >= _score_skill_draft(existing):
			drafts_by_slot_id[slot_id] = draft
	for slot_id_variant: Variant in drafts_by_slot_id.keys():
		normalized_drafts.append(drafts_by_slot_id[slot_id_variant] as Resource)
	normalized_drafts.sort_custom(func(a: Resource, b: Resource) -> bool:
		return String(a.get("owning_skill_id")) < String(b.get("owning_skill_id"))
	)
	return normalized_drafts

func _resolve_default_skill_draft_ids(builder_path_id: StringName, equipment_context_id: StringName) -> Array[StringName]:
	if (
		builder_path_id == &"builder_path_melee"
		and (equipment_context_id == &"ctx_weapon" or equipment_context_id == &"ctx_unarmed")
	):
		return get_authoring_skill_slot_ids()
	return []

func _build_default_skill_display_name(skill_id: StringName) -> String:
	if skill_id == PlayerSkillSlotStateScript.BLOCK_SLOT_ID:
		return "Block"
	var skill_id_text: String = String(skill_id).replace("_", " ").strip_edges()
	if skill_id_text.is_empty():
		return "Baseline Skill"
	return skill_id_text.capitalize()

func _get_idle_context_ids() -> Array[StringName]:
	return get_authoring_idle_context_ids()

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

func _build_default_skill_draft(
	draft_id: StringName,
	display_name: String,
	skill_id: StringName,
	slot_id: StringName = StringName()
) -> Resource:
	var draft_script: Script = load("res://core/models/combat_animation_draft.gd") as Script
	var draft: Resource = draft_script.new() if draft_script != null else null
	if draft == null:
		return null
	draft.set("draft_id", draft_id)
	draft.set("display_name", display_name)
	draft.set("draft_kind", CombatAnimationDraftScript.DRAFT_KIND_SKILL)
	draft.set("owning_skill_id", skill_id)
	draft.set("legal_slot_id", slot_id)
	draft.call("ensure_minimum_baseline_nodes")
	return draft

func _resolve_skill_draft_slot_id(draft: Resource) -> StringName:
	if draft == null:
		return StringName()
	var legal_slot_id: StringName = StringName(draft.get("legal_slot_id"))
	if is_authoring_skill_slot_id(legal_slot_id):
		return legal_slot_id
	var owning_skill_id: StringName = StringName(draft.get("owning_skill_id"))
	if is_authoring_skill_slot_id(owning_skill_id):
		return owning_skill_id
	return StringName()

func _score_skill_draft(draft: Resource) -> int:
	if draft == null:
		return -1
	var score: int = 0
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	score += motion_node_chain.size() * 100
	if not String(draft.get("skill_name")).strip_edges().is_empty():
		score += 10
	if not String(draft.get("skill_description")).strip_edges().is_empty():
		score += 5
	if not String(draft.get("draft_notes")).strip_edges().is_empty():
		score += 3
	return score

func _score_idle_draft(draft: Resource) -> int:
	if draft == null:
		return -1
	var score: int = 0
	score += int((draft.get("motion_node_chain") as Array).size()) * 100
	if StringName(draft.get("stow_anchor_mode")) != CombatAnimationDraftScript.STOW_ANCHOR_SHOULDER_HANGING:
		score += 5
	if not String(draft.get("draft_notes")).strip_edges().is_empty():
		score += 3
	return score

func _find_skill_draft_by_identifier(skill_id: StringName) -> Resource:
	for draft: Resource in skill_drafts:
		if draft == null:
			continue
		if StringName(draft.get("owning_skill_id")) == skill_id:
			return draft
	return null

static func is_authoring_skill_slot_id(slot_id: StringName) -> bool:
	return get_authoring_skill_slot_ids().has(slot_id)

static func is_authoring_idle_context_id(idle_context_id: StringName) -> bool:
	return get_authoring_idle_context_ids().has(idle_context_id)
