extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_runtime_skill_activation_results.txt"
const TEMP_LIBRARY_SAVE_PATH := "C:/WORKSPACE/test_artifacts/verify_player_runtime_skill_activation_library.tres"
const TEMP_SKILL_SLOT_SAVE_PATH := "C:/WORKSPACE/test_artifacts/verify_player_runtime_skill_activation_slots.tres"
const TEMP_EQUIPMENT_SAVE_PATH := "C:/WORKSPACE/test_artifacts/verify_player_runtime_skill_activation_equipment.tres"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library_state.save_file_path = TEMP_LIBRARY_SAVE_PATH
	library_state.saved_wips.clear()

	var authored_wip: CraftedItemWIP = _build_authored_skill_test_wip("Runtime Skill Test", &"skill_slot_3", "Forward Arc")
	var saved_wip: CraftedItemWIP = library_state.save_wip(authored_wip)

	var equipment_state: PlayerEquipmentState = PlayerEquipmentStateScript.new()
	equipment_state.save_file_path = TEMP_EQUIPMENT_SAVE_PATH
	equipment_state.equip_forge_test_wip(&"hand_right", saved_wip)

	var skill_slot_state: PlayerSkillSlotState = PlayerSkillSlotStateScript.new()
	skill_slot_state.save_file_path = TEMP_SKILL_SLOT_SAVE_PATH
	skill_slot_state.slot_assignments.clear()

	var player: PlayerController3D = PlayerScene.instantiate() as PlayerController3D
	player.equipment_state = equipment_state
	player.forge_wip_library_state = library_state
	player.player_skill_slot_state = skill_slot_state
	player.call("_sync_equipped_skill_slots")

	var assigned_result: Dictionary = player.preview_runtime_skill_slot_activation(&"skill_slot_3")
	var unassigned_result: Dictionary = player.preview_runtime_skill_slot_activation(&"skill_slot_4")
	player.call("_activate_skill_slot", &"skill_slot_3")
	var last_result: Dictionary = player.get_last_skill_activation_result()

	var lines: PackedStringArray = []
	lines.append("assigned_success=%s" % str(bool(assigned_result.get("success", false))))
	lines.append("assigned_display_name=%s" % String(assigned_result.get("display_name", "")))
	lines.append("assigned_weapon_name=%s" % String(assigned_result.get("source_weapon_name", "")))
	lines.append("assigned_motion_node_count=%d" % int(assigned_result.get("motion_node_count", 0)))
	lines.append("assigned_slot_id=%s" % String(assigned_result.get("slot_id", StringName())))
	lines.append("assigned_legal_slot_id=%s" % String(assigned_result.get("legal_slot_id", StringName())))
	lines.append("assigned_skill_name=%s" % String(assigned_result.get("skill_name", "")))
	lines.append("assigned_preferred_grip_style=%s" % String(assigned_result.get("preferred_grip_style_mode", StringName())))
	lines.append("unassigned_success=%s" % str(bool(unassigned_result.get("success", false))))
	lines.append("unassigned_message=%s" % String(unassigned_result.get("message", "")))
	lines.append("last_result_matches_assigned=%s" % str(
		bool(last_result.get("success", false))
		and StringName(last_result.get("slot_id", StringName())) == &"skill_slot_3"
		and String(last_result.get("skill_name", "")) == "Forward Arc"
	))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _build_authored_skill_test_wip(project_name: String, slot_id: StringName, skill_name: String) -> CraftedItemWIP:
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
	var draft: CombatAnimationDraft = station_state.get_or_create_skill_draft(
		slot_id,
		String(slot_id).replace("_", " ").capitalize(),
		wip.grip_style_mode,
		slot_id
	) as CombatAnimationDraft
	if draft != null:
		draft.skill_name = skill_name
	return wip
