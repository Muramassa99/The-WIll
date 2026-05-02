extends RefCounted
class_name PlayerEquippedSkillSlotPresenter

const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")

const EQUIPMENT_SLOT_PRIORITY: Array[StringName] = [
	&"hand_right",
	&"hand_left",
]

func sync_from_equipment(
	equipment_state,
	wip_library: PlayerForgeWipLibraryState,
	skill_slot_state: PlayerSkillSlotState = null
) -> PlayerSkillSlotState:
	var resolved_skill_slot_state: PlayerSkillSlotState = skill_slot_state
	if resolved_skill_slot_state == null:
		resolved_skill_slot_state = PlayerSkillSlotStateScript.load_or_create() as PlayerSkillSlotState
	if resolved_skill_slot_state == null:
		return null
	resolved_skill_slot_state.clear_slots(CombatAnimationStationStateScript.get_authoring_skill_slot_ids(), false)
	if equipment_state != null and wip_library != null:
		for equipment_slot_id: StringName in EQUIPMENT_SLOT_PRIORITY:
			_apply_equipped_weapon_skill_slots(
				equipment_slot_id,
				equipment_state,
				wip_library,
				resolved_skill_slot_state
			)
	resolved_skill_slot_state.persist()
	return resolved_skill_slot_state

func resolve_runtime_skill_slot(
	slot_id: StringName,
	equipment_state,
	wip_library: PlayerForgeWipLibraryState,
	skill_slot_state: PlayerSkillSlotState = null
) -> Dictionary:
	var result := {
		"success": false,
		"slot_id": slot_id,
		"display_name": "",
		"message": "",
	}
	if slot_id == StringName():
		result["message"] = "No skill slot id was provided."
		return result
	var resolved_skill_slot_state: PlayerSkillSlotState = skill_slot_state
	if resolved_skill_slot_state == null:
		resolved_skill_slot_state = PlayerSkillSlotStateScript.load_or_create() as PlayerSkillSlotState
	if resolved_skill_slot_state == null:
		result["message"] = "Skill slot state is unavailable."
		return result
	var assignment: Resource = resolved_skill_slot_state.get_slot_assignment(slot_id)
	if assignment == null:
		result["message"] = "No authored skill is assigned to this slot."
		return result
	var source_weapon_wip_id: StringName = assignment.get("source_weapon_wip_id") as StringName
	var source_skill_draft_id: StringName = assignment.get("source_skill_draft_id") as StringName
	var display_name: String = String(assignment.get("display_name")).strip_edges()
	result["display_name"] = display_name
	result["source_weapon_wip_id"] = source_weapon_wip_id
	result["source_skill_draft_id"] = source_skill_draft_id
	if wip_library == null:
		result["message"] = "Weapon library is unavailable."
		return result
	var saved_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(source_weapon_wip_id)
	if saved_wip == null:
		result["message"] = "The source weapon for this skill could not be found."
		return result
	var station_state: CombatAnimationStationState = saved_wip.ensure_combat_animation_station_state() as CombatAnimationStationState
	if station_state == null:
		result["message"] = "The source weapon has no combat animation station state."
		return result
	station_state.normalize()
	var draft: CombatAnimationDraft = _resolve_runtime_skill_draft(
		station_state,
		source_skill_draft_id,
		slot_id
	)
	if draft == null:
		result["message"] = "The authored skill draft for this slot could not be found."
		return result
	if not draft.is_publishable_skill_draft():
		result["message"] = "The authored skill draft is not publishable yet."
		result["draft_publishable"] = false
		result["source_station_state"] = station_state
		result["source_weapon_wip"] = saved_wip
		result["source_skill_draft"] = draft
		return result
	result["success"] = true
	result["message"] = "Authored skill resolved."
	result["draft_publishable"] = true
	result["source_station_state"] = station_state
	result["source_weapon_wip"] = saved_wip
	result["source_skill_draft"] = draft
	result["source_weapon_name"] = saved_wip.forge_project_name
	result["draft_id"] = draft.draft_id
	result["owning_skill_id"] = draft.owning_skill_id
	result["legal_slot_id"] = draft.legal_slot_id
	result["source_equipment_slot_id"] = _resolve_source_equipment_slot_id(equipment_state, source_weapon_wip_id)
	result["skill_name"] = draft.skill_name
	result["skill_description"] = draft.skill_description
	result["preferred_grip_style_mode"] = draft.preferred_grip_style_mode
	result["motion_node_count"] = draft.motion_node_chain.size()
	result["motion_node_chain"] = draft.motion_node_chain
	result["preview_playback_speed_scale"] = draft.preview_playback_speed_scale
	result["speed_acceleration_percent"] = draft.speed_acceleration_percent
	result["speed_deceleration_percent"] = draft.speed_deceleration_percent
	result["preview_loop_enabled"] = draft.preview_loop_enabled
	result["authored_for_two_hand_only"] = draft.authored_for_two_hand_only
	result["equipment_state"] = equipment_state
	return result

func resolve_runtime_idle_pose(
	equipment_state,
	wip_library: PlayerForgeWipLibraryState,
	weapons_drawn: bool,
	preferred_equipment_slot_id: StringName = StringName()
) -> Dictionary:
	var idle_context_id: StringName = (
		CombatAnimationStationStateScript.IDLE_CONTEXT_COMBAT
		if weapons_drawn
		else CombatAnimationStationStateScript.IDLE_CONTEXT_NONCOMBAT
	)
	var result := {
		"success": false,
		"idle_context_id": idle_context_id,
		"display_name": "",
		"message": "",
		"stowed_presentation": not weapons_drawn,
		"hands_interact_with_weapon": weapons_drawn,
	}
	if equipment_state == null:
		result["message"] = "Equipment state is unavailable."
		return result
	if wip_library == null:
		result["message"] = "Weapon library is unavailable."
		return result
	var source_equipment_slot_id: StringName = _resolve_idle_source_equipment_slot_id(
		equipment_state,
		preferred_equipment_slot_id
	)
	if source_equipment_slot_id == StringName():
		result["message"] = "No equipped weapon is available for authored idle."
		return result
	var equipped_entry = equipment_state.get_equipped_slot(source_equipment_slot_id)
	if equipped_entry == null or not equipped_entry.has_method("is_forge_test_wip") or not equipped_entry.is_forge_test_wip():
		result["message"] = "The selected equipment slot has no forge weapon idle source."
		return result
	var source_weapon_wip_id: StringName = equipped_entry.source_wip_id
	var saved_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(source_weapon_wip_id)
	if saved_wip == null:
		result["message"] = "The equipped weapon for authored idle could not be found."
		return result
	var station_state: CombatAnimationStationState = saved_wip.ensure_combat_animation_station_state() as CombatAnimationStationState
	if station_state == null:
		result["message"] = "The equipped weapon has no combat animation station state."
		return result
	station_state.normalize()
	var draft: CombatAnimationDraft = _resolve_runtime_idle_draft(station_state, idle_context_id)
	if not weapons_drawn:
		if draft != null:
			draft.ensure_minimum_baseline_nodes()
		result["success"] = true
		result["message"] = "Noncombat idle uses authored stow presentation; hands do not interact with the weapon."
		result["display_name"] = draft.display_name if draft != null else "Noncombat Idle"
		result["source_station_state"] = station_state
		result["source_weapon_wip"] = saved_wip
		result["source_idle_draft"] = draft
		result["source_weapon_wip_id"] = source_weapon_wip_id
		result["source_weapon_name"] = saved_wip.forge_project_name
		result["source_equipment_slot_id"] = source_equipment_slot_id
		result["draft_id"] = draft.draft_id if draft != null else StringName()
		result["preferred_grip_style_mode"] = draft.preferred_grip_style_mode if draft != null else saved_wip.grip_style_mode
		result["stow_position_mode"] = (
			CombatAnimationDraft.normalize_stow_anchor_mode(draft.stow_anchor_mode)
			if draft != null
			else CombatAnimationDraft.normalize_stow_anchor_mode(saved_wip.stow_position_mode)
		)
		result["motion_node_count"] = draft.motion_node_chain.size() if draft != null else 0
		result["motion_node_chain"] = draft.motion_node_chain if draft != null else []
		result["speed_acceleration_percent"] = draft.speed_acceleration_percent if draft != null else CombatAnimationDraft.DEFAULT_SPEED_ACCELERATION_PERCENT
		result["speed_deceleration_percent"] = draft.speed_deceleration_percent if draft != null else CombatAnimationDraft.DEFAULT_SPEED_DECELERATION_PERCENT
		result["preview_loop_enabled"] = bool(draft.preview_loop_enabled) if draft != null else false
		result["equipment_state"] = equipment_state
		return result
	if draft == null:
		result["message"] = "The equipped weapon has no authored idle draft for this context."
		return result
	draft.ensure_minimum_baseline_nodes()
	if draft.motion_node_chain.is_empty():
		result["message"] = "The authored idle draft has no motion nodes."
		return result
	result["success"] = true
	result["message"] = "Authored idle resolved."
	result["display_name"] = draft.display_name
	result["source_station_state"] = station_state
	result["source_weapon_wip"] = saved_wip
	result["source_idle_draft"] = draft
	result["source_weapon_wip_id"] = source_weapon_wip_id
	result["source_weapon_name"] = saved_wip.forge_project_name
	result["source_equipment_slot_id"] = source_equipment_slot_id
	result["draft_id"] = draft.draft_id
	result["preferred_grip_style_mode"] = draft.preferred_grip_style_mode
	result["motion_node_count"] = draft.motion_node_chain.size()
	result["motion_node_chain"] = draft.motion_node_chain
	result["preview_playback_speed_scale"] = draft.preview_playback_speed_scale
	result["speed_acceleration_percent"] = draft.speed_acceleration_percent
	result["speed_deceleration_percent"] = draft.speed_deceleration_percent
	result["preview_loop_enabled"] = true
	result["equipment_state"] = equipment_state
	return result

func _apply_equipped_weapon_skill_slots(
	equipment_slot_id: StringName,
	equipment_state,
	wip_library: PlayerForgeWipLibraryState,
	skill_slot_state: PlayerSkillSlotState
) -> void:
	if equipment_state == null or wip_library == null or skill_slot_state == null:
		return
	var equipped_entry = equipment_state.get_equipped_slot(equipment_slot_id)
	if equipped_entry == null or not equipped_entry.has_method("is_forge_test_wip") or not equipped_entry.is_forge_test_wip():
		return
	var source_wip_id: StringName = equipped_entry.source_wip_id
	if source_wip_id == StringName():
		return
	var saved_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(source_wip_id)
	if saved_wip == null:
		return
	_apply_weapon_skill_slots(saved_wip, skill_slot_state)

func _apply_weapon_skill_slots(saved_wip: CraftedItemWIP, skill_slot_state: PlayerSkillSlotState) -> void:
	if saved_wip == null or skill_slot_state == null:
		return
	var station_state: CombatAnimationStationState = saved_wip.ensure_combat_animation_station_state() as CombatAnimationStationState
	if station_state == null:
		return
	station_state.normalize()
	for draft_variant: Variant in station_state.skill_drafts:
		var draft: CombatAnimationDraft = draft_variant as CombatAnimationDraft
		if draft == null or not draft.is_publishable_skill_draft():
			continue
		var slot_id: StringName = _resolve_draft_slot_id(draft)
		if slot_id == StringName() or skill_slot_state.is_slot_assigned(slot_id):
			continue
		skill_slot_state.set_slot_assignment(
			slot_id,
			saved_wip.wip_id,
			_resolve_draft_source_id(draft),
			_resolve_draft_display_name(draft),
			false
		)

func _resolve_draft_slot_id(draft: CombatAnimationDraft) -> StringName:
	if draft == null:
		return StringName()
	if CombatAnimationStationStateScript.is_authoring_skill_slot_id(draft.legal_slot_id):
		return draft.legal_slot_id
	if CombatAnimationStationStateScript.is_authoring_skill_slot_id(draft.owning_skill_id):
		return draft.owning_skill_id
	return StringName()

func _resolve_draft_source_id(draft: CombatAnimationDraft) -> StringName:
	if draft == null:
		return StringName()
	if draft.draft_id != StringName():
		return draft.draft_id
	return draft.owning_skill_id

func _resolve_draft_display_name(draft: CombatAnimationDraft) -> String:
	if draft == null:
		return ""
	var preferred_name: String = draft.skill_name.strip_edges()
	if not preferred_name.is_empty():
		return preferred_name
	var fallback_name: String = draft.display_name.strip_edges()
	if not fallback_name.is_empty():
		return fallback_name
	return String(_resolve_draft_slot_id(draft)).replace("_", " ").capitalize()

func _resolve_runtime_skill_draft(
	station_state: CombatAnimationStationState,
	source_skill_draft_id: StringName,
	slot_id: StringName
) -> CombatAnimationDraft:
	if station_state == null:
		return null
	for draft_variant: Variant in station_state.skill_drafts:
		var draft: CombatAnimationDraft = draft_variant as CombatAnimationDraft
		if draft == null:
			continue
		if source_skill_draft_id != StringName() and draft.draft_id == source_skill_draft_id:
			return draft
	for draft_variant: Variant in station_state.skill_drafts:
		var draft: CombatAnimationDraft = draft_variant as CombatAnimationDraft
		if draft == null:
			continue
		if draft.legal_slot_id == slot_id or draft.owning_skill_id == slot_id:
			return draft
	return null

func _resolve_runtime_idle_draft(
	station_state: CombatAnimationStationState,
	idle_context_id: StringName
) -> CombatAnimationDraft:
	if station_state == null:
		return null
	for draft_variant: Variant in station_state.idle_drafts:
		var draft: CombatAnimationDraft = draft_variant as CombatAnimationDraft
		if draft == null:
			continue
		if draft.context_id == idle_context_id:
			return draft
	return null

func _resolve_idle_source_equipment_slot_id(equipment_state, preferred_equipment_slot_id: StringName) -> StringName:
	if equipment_state == null:
		return StringName()
	if preferred_equipment_slot_id != StringName():
		var preferred_entry = equipment_state.get_equipped_slot(preferred_equipment_slot_id)
		if preferred_entry != null and preferred_entry.has_method("is_forge_test_wip") and preferred_entry.is_forge_test_wip():
			return preferred_equipment_slot_id
	for equipment_slot_id: StringName in EQUIPMENT_SLOT_PRIORITY:
		var equipped_entry = equipment_state.get_equipped_slot(equipment_slot_id)
		if equipped_entry == null or not equipped_entry.has_method("is_forge_test_wip"):
			continue
		if equipped_entry.is_forge_test_wip():
			return equipment_slot_id
	return StringName()

func _resolve_source_equipment_slot_id(equipment_state, source_weapon_wip_id: StringName) -> StringName:
	if equipment_state == null or source_weapon_wip_id == StringName():
		return StringName()
	for equipped_slot_variant: Variant in equipment_state.get_equipped_slots():
		var equipped_slot: Resource = equipped_slot_variant as Resource
		if equipped_slot == null:
			continue
		if StringName(equipped_slot.get("source_wip_id")) == source_weapon_wip_id:
			return equipped_slot.get("slot_id") as StringName
	return StringName()
