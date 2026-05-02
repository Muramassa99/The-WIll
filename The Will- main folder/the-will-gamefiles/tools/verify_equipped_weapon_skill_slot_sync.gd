extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")
const PlayerEquippedSkillSlotPresenterScript = preload("res://runtime/player/player_equipped_skill_slot_presenter.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const HudScene = preload("res://scenes/ui/player_gameplay_hud_overlay.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/equipped_weapon_skill_slot_sync_results.txt"
const TEMP_LIBRARY_SAVE_PATH := "C:/WORKSPACE/test_artifacts/verify_equipped_weapon_skill_slot_sync_library.tres"
const TEMP_SKILL_SLOT_SAVE_PATH := "C:/WORKSPACE/test_artifacts/verify_equipped_weapon_skill_slot_state.tres"
const TEMP_EQUIPMENT_SAVE_PATH := "C:/WORKSPACE/test_artifacts/verify_equipped_weapon_skill_slot_equipment_state.tres"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library_state.save_file_path = TEMP_LIBRARY_SAVE_PATH
	library_state.saved_wips.clear()

	var right_wip: CraftedItemWIP = _build_skill_test_wip("Right Authored", {
		&"skill_slot_1": "Right Slash",
	})
	var left_wip: CraftedItemWIP = _build_skill_test_wip("Left Authored", {
		&"skill_slot_1": "Left Slash",
		&"skill_slot_6": "Left Guard",
	})
	var saved_right_wip: CraftedItemWIP = library_state.save_wip(right_wip)
	var saved_left_wip: CraftedItemWIP = library_state.save_wip(left_wip)
	var right_slot_6_draft: CombatAnimationDraft = _get_skill_draft_for_slot(saved_right_wip, &"skill_slot_6")
	var right_slot_6_motion_nodes: Array = right_slot_6_draft.motion_node_chain if right_slot_6_draft != null else []

	var equipment_state: PlayerEquipmentState = PlayerEquipmentStateScript.new()
	equipment_state.save_file_path = TEMP_EQUIPMENT_SAVE_PATH
	equipment_state.equip_forge_test_wip(&"hand_left", saved_left_wip)
	equipment_state.equip_forge_test_wip(&"hand_right", saved_right_wip)

	var skill_slot_state: PlayerSkillSlotState = PlayerSkillSlotStateScript.new()
	skill_slot_state.save_file_path = TEMP_SKILL_SLOT_SAVE_PATH
	skill_slot_state.slot_assignments.clear()

	var presenter = PlayerEquippedSkillSlotPresenterScript.new()
	presenter.sync_from_equipment(equipment_state, library_state, skill_slot_state)

	var slot_1_assignment: Resource = skill_slot_state.get_slot_assignment(&"skill_slot_1")
	var slot_6_assignment: Resource = skill_slot_state.get_slot_assignment(&"skill_slot_6")
	var slot_2_assignment: Resource = skill_slot_state.get_slot_assignment(&"skill_slot_2")

	equipment_state.clear_slot(&"hand_right")
	presenter.sync_from_equipment(equipment_state, library_state, skill_slot_state)
	var slot_1_after_clear: Resource = skill_slot_state.get_slot_assignment(&"skill_slot_1")

	var reloaded_skill_slot_state: PlayerSkillSlotState = PlayerSkillSlotStateScript.load_or_create(
		TEMP_SKILL_SLOT_SAVE_PATH
	) as PlayerSkillSlotState
	var reloaded_slot_6_assignment: Resource = reloaded_skill_slot_state.get_slot_assignment(&"skill_slot_6") if reloaded_skill_slot_state != null else null
	var player_instance: Node = PlayerScene.instantiate() if PlayerScene != null else null
	var hud_instance: Node = HudScene.instantiate() if HudScene != null else null
	if player_instance != null:
		player_instance.queue_free()
	if hud_instance != null:
		hud_instance.queue_free()

	var lines: PackedStringArray = []
	lines.append("player_scene_instanced=%s" % str(player_instance != null))
	lines.append("hud_scene_instanced=%s" % str(hud_instance != null))
	lines.append("right_slot_6_publishable=%s" % str(right_slot_6_draft.is_publishable_skill_draft() if right_slot_6_draft != null else false))
	lines.append("right_slot_6_matches_legacy=%s" % str(right_slot_6_draft.call("_matches_legacy_skill_baseline") if right_slot_6_draft != null else false))
	lines.append("right_slot_6_display_name=%s" % String(right_slot_6_draft.display_name if right_slot_6_draft != null else ""))
	lines.append("right_slot_6_skill_name=%s" % String(right_slot_6_draft.skill_name if right_slot_6_draft != null else ""))
	lines.append("right_slot_6_motion_node_count=%d" % right_slot_6_motion_nodes.size())
	lines.append("slot_1_assigned=%s" % str(slot_1_assignment != null))
	lines.append("slot_1_display_name=%s" % String(slot_1_assignment.get("display_name") if slot_1_assignment != null else ""))
	lines.append("slot_1_source_weapon=%s" % String(slot_1_assignment.get("source_weapon_wip_id") if slot_1_assignment != null else StringName()))
	lines.append("slot_6_assigned=%s" % str(slot_6_assignment != null))
	lines.append("slot_6_display_name=%s" % String(slot_6_assignment.get("display_name") if slot_6_assignment != null else ""))
	lines.append("slot_6_source_weapon=%s" % String(slot_6_assignment.get("source_weapon_wip_id") if slot_6_assignment != null else StringName()))
	lines.append("untouched_slot_2_assigned=%s" % str(slot_2_assignment != null))
	lines.append("slot_1_after_clear_display_name=%s" % String(slot_1_after_clear.get("display_name") if slot_1_after_clear != null else ""))
	lines.append("slot_1_after_clear_source_weapon=%s" % String(slot_1_after_clear.get("source_weapon_wip_id") if slot_1_after_clear != null else StringName()))
	lines.append("reloaded_slot_6_display_name=%s" % String(reloaded_slot_6_assignment.get("display_name") if reloaded_slot_6_assignment != null else ""))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _build_skill_test_wip(project_name: String, authored_slot_names: Dictionary) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.forge_project_name = project_name
	CraftedItemWIPScript.apply_builder_path_defaults(
		wip,
		CraftedItemWIPScript.BUILDER_PATH_MELEE,
		CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	)
	var station_state: CombatAnimationStationState = wip.ensure_combat_animation_station_state() as CombatAnimationStationState
	if station_state == null:
		return wip
	for slot_id_variant: Variant in authored_slot_names.keys():
		var slot_id: StringName = slot_id_variant as StringName
		var draft: CombatAnimationDraft = station_state.get_or_create_skill_draft(
			slot_id,
			String(slot_id).replace("_", " ").capitalize(),
			wip.grip_style_mode,
			slot_id
		) as CombatAnimationDraft
		if draft == null:
			continue
		draft.skill_name = String(authored_slot_names[slot_id_variant])
	return wip

func _get_skill_draft_for_slot(saved_wip: CraftedItemWIP, slot_id: StringName) -> CombatAnimationDraft:
	if saved_wip == null:
		return null
	var station_state: CombatAnimationStationState = saved_wip.ensure_combat_animation_station_state() as CombatAnimationStationState
	if station_state == null:
		return null
	for draft_variant: Variant in station_state.skill_drafts:
		var draft: CombatAnimationDraft = draft_variant as CombatAnimationDraft
		if draft == null:
			continue
		if draft.legal_slot_id == slot_id or draft.owning_skill_id == slot_id:
			return draft
	return null
