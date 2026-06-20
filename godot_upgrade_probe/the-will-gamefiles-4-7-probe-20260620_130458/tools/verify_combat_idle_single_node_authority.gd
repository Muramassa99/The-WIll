extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_idle_single_node_authority_results.txt"
const TEMP_LIBRARY_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/verify_combat_idle_single_node_authority_library.tres"
const TEMP_EQUIPMENT_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/verify_combat_idle_single_node_authority_equipment.tres"

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null
	var equipment_state: PlayerEquipmentState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func get_equipment_state() -> PlayerEquipmentState:
		return equipment_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library_state.save_file_path = TEMP_LIBRARY_SAVE_FILE_PATH
	library_state.saved_wips.clear()
	library_state.selected_wip_id = StringName()

	var source_wip: CraftedItemWIP = CraftedItemWIPScript.new()
	source_wip.forge_project_name = "Combat Idle Authority Verifier"
	CraftedItemWIPScript.apply_builder_path_defaults(
		source_wip,
		CraftedItemWIPScript.BUILDER_PATH_MELEE,
		CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	)
	var saved_wip: CraftedItemWIP = library_state.save_wip(source_wip)
	var saved_wip_id: StringName = saved_wip.wip_id if saved_wip != null else StringName()
	var persisted_wip: CraftedItemWIP = library_state.get_saved_wip(saved_wip_id)
	var persisted_station_state: CombatAnimationStationState = null
	if persisted_wip != null:
		persisted_station_state = persisted_wip.ensure_combat_animation_station_state() as CombatAnimationStationState
	if persisted_station_state != null:
		persisted_station_state.selected_authoring_mode = CombatAnimationStationStateScript.AUTHORING_MODE_IDLE
		persisted_station_state.selected_idle_context_id = CombatAnimationStationStateScript.IDLE_CONTEXT_COMBAT
		var idle_draft: CombatAnimationDraft = persisted_station_state.get_or_create_idle_draft(
			CombatAnimationStationStateScript.IDLE_CONTEXT_COMBAT,
			"Combat Idle",
			persisted_wip.grip_style_mode if persisted_wip != null else CraftedItemWIPScript.GRIP_NORMAL
		) as CombatAnimationDraft
		if idle_draft != null:
			idle_draft.ensure_minimum_baseline_nodes()
			var first_node: CombatAnimationMotionNode = _get_motion_node(idle_draft, 0)
			if first_node != null:
				first_node.primary_hand_slot = CombatAnimationMotionNodeScript.PRIMARY_HAND_AUTO
			var extra_node: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
			extra_node.node_index = 1
			extra_node.primary_hand_slot = CombatAnimationMotionNodeScript.PRIMARY_HAND_RIGHT
			idle_draft.motion_node_chain.append(extra_node)
			idle_draft.selected_motion_node_index = 1
			idle_draft.continuity_motion_node_index = 1
		var noncombat_draft: CombatAnimationDraft = persisted_station_state.get_or_create_idle_draft(
			CombatAnimationStationStateScript.IDLE_CONTEXT_NONCOMBAT,
			"Noncombat Idle",
			persisted_wip.grip_style_mode if persisted_wip != null else CraftedItemWIPScript.GRIP_NORMAL,
			CombatAnimationDraft.STOW_ANCHOR_LOWER_BACK
		) as CombatAnimationDraft
		if noncombat_draft != null:
			noncombat_draft.ensure_minimum_baseline_nodes()
			noncombat_draft.stow_anchor_mode = CombatAnimationDraft.STOW_ANCHOR_LOWER_BACK
			var noncombat_extra_node: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
			noncombat_extra_node.node_index = 1
			noncombat_extra_node.primary_hand_slot = CombatAnimationMotionNodeScript.PRIMARY_HAND_RIGHT
			noncombat_draft.motion_node_chain.append(noncombat_extra_node)
			noncombat_draft.selected_motion_node_index = 1
			noncombat_draft.continuity_motion_node_index = 1
	library_state.persist()

	var equipment_state: PlayerEquipmentState = PlayerEquipmentStateScript.new()
	equipment_state.save_file_path = TEMP_EQUIPMENT_SAVE_FILE_PATH
	equipment_state.equipped_slots.clear()
	equipment_state.equip_forge_test_wip(&"hand_left", persisted_wip)

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	fake_player.equipment_state = equipment_state
	get_root().add_child(fake_player)

	var ui = CombatAnimationStationUIScene.instantiate()
	get_root().add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Verifier")
	await process_frame
	ui.open_saved_wip_with_hand_setup(saved_wip_id, &"hand_right", false, false)
	await process_frame
	ui.select_authoring_mode(CombatAnimationStationStateScript.AUTHORING_MODE_IDLE)
	await process_frame
	ui.select_draft(CombatAnimationStationStateScript.IDLE_CONTEXT_COMBAT, true)
	await process_frame

	var active_draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	var after_select_primary: StringName = _get_primary_hand(active_draft)
	var after_select_count: int = active_draft.motion_node_chain.size() if active_draft != null else -1
	var after_select_selected_index: int = active_draft.selected_motion_node_index if active_draft != null else -1
	var primary_button_disabled: bool = ui.primary_hand_option_button.disabled
	var add_button_disabled: bool = ui.add_point_button.disabled
	var duplicate_button_disabled: bool = ui.duplicate_point_button.disabled
	var remove_button_disabled: bool = ui.remove_point_button.disabled
	var combat_stow_selector_hidden: bool = not ui.stow_anchor_field_container.visible

	var primary_change_ok: bool = ui.set_selected_motion_node_primary_hand_slot(&"hand_right", false)
	await process_frame
	var after_primary_change_primary: StringName = _get_primary_hand(active_draft)

	var insert_ok: bool = ui.insert_motion_node_after_selection()
	await process_frame
	var after_insert_count: int = active_draft.motion_node_chain.size() if active_draft != null else -1
	var after_insert_primary: StringName = _get_primary_hand(active_draft)

	var remove_ok: bool = ui.remove_selected_motion_node()
	await process_frame
	var after_remove_count: int = active_draft.motion_node_chain.size() if active_draft != null else -1

	var duplicate_ok: bool = ui.duplicate_selected_motion_node()
	await process_frame
	var after_duplicate_count: int = active_draft.motion_node_chain.size() if active_draft != null else -1
	var after_duplicate_primary: StringName = _get_primary_hand(active_draft)

	ui.select_draft(CombatAnimationStationStateScript.IDLE_CONTEXT_NONCOMBAT, true)
	await process_frame
	var active_noncombat_draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	var noncombat_after_select_count: int = active_noncombat_draft.motion_node_chain.size() if active_noncombat_draft != null else -1
	var noncombat_after_select_selected_index: int = active_noncombat_draft.selected_motion_node_index if active_noncombat_draft != null else -1
	var noncombat_after_select_primary: StringName = _get_primary_hand(active_noncombat_draft)
	var noncombat_stow_anchor_mode: StringName = active_noncombat_draft.stow_anchor_mode if active_noncombat_draft != null else StringName()
	var noncombat_stow_selector_visible: bool = ui.stow_anchor_field_container.visible
	var noncombat_stow_selector_enabled: bool = not ui.stow_anchor_option_button.disabled
	var noncombat_stow_update_ok: bool = ui.set_active_draft_stow_anchor_mode(CombatAnimationDraft.STOW_ANCHOR_SIDE_HIP)
	await process_frame
	var noncombat_stow_anchor_after_update: StringName = active_noncombat_draft.stow_anchor_mode if active_noncombat_draft != null else StringName()
	var noncombat_primary_change_ok: bool = ui.set_selected_motion_node_primary_hand_slot(&"hand_right", false)
	await process_frame
	var noncombat_insert_ok: bool = ui.insert_motion_node_after_selection()
	await process_frame
	var noncombat_after_insert_count: int = active_noncombat_draft.motion_node_chain.size() if active_noncombat_draft != null else -1
	var noncombat_remove_ok: bool = ui.remove_selected_motion_node()
	await process_frame
	var noncombat_after_remove_count: int = active_noncombat_draft.motion_node_chain.size() if active_noncombat_draft != null else -1

	var all_checks_passed: bool = (
		after_select_count == 1
		and after_select_selected_index == 0
		and after_select_primary == &"hand_left"
		and primary_button_disabled
		and combat_stow_selector_hidden
		and add_button_disabled
		and duplicate_button_disabled
		and remove_button_disabled
		and not primary_change_ok
		and after_primary_change_primary == &"hand_left"
		and insert_ok
		and after_insert_count == 1
		and after_insert_primary == &"hand_left"
		and not remove_ok
		and after_remove_count == 1
		and duplicate_ok
		and after_duplicate_count == 1
		and after_duplicate_primary == &"hand_left"
		and noncombat_after_select_count == 1
		and noncombat_after_select_selected_index == 0
		and noncombat_after_select_primary == &"hand_left"
		and noncombat_stow_anchor_mode == CombatAnimationDraft.STOW_ANCHOR_LOWER_BACK
		and noncombat_stow_selector_visible
		and noncombat_stow_selector_enabled
		and noncombat_stow_update_ok
		and noncombat_stow_anchor_after_update == CombatAnimationDraft.STOW_ANCHOR_SIDE_HIP
		and not noncombat_primary_change_ok
		and noncombat_insert_ok
		and noncombat_after_insert_count == 1
		and not noncombat_remove_ok
		and noncombat_after_remove_count == 1
	)

	var lines: PackedStringArray = []
	lines.append("saved_wip_id=%s" % String(saved_wip_id))
	lines.append("after_select_count=%d" % after_select_count)
	lines.append("after_select_selected_index=%d" % after_select_selected_index)
	lines.append("after_select_primary=%s" % String(after_select_primary))
	lines.append("primary_button_disabled=%s" % str(primary_button_disabled))
	lines.append("combat_stow_selector_hidden=%s" % str(combat_stow_selector_hidden))
	lines.append("add_button_disabled=%s" % str(add_button_disabled))
	lines.append("duplicate_button_disabled=%s" % str(duplicate_button_disabled))
	lines.append("remove_button_disabled=%s" % str(remove_button_disabled))
	lines.append("primary_change_ok=%s" % str(primary_change_ok))
	lines.append("after_primary_change_primary=%s" % String(after_primary_change_primary))
	lines.append("insert_ok=%s" % str(insert_ok))
	lines.append("after_insert_count=%d" % after_insert_count)
	lines.append("after_insert_primary=%s" % String(after_insert_primary))
	lines.append("remove_ok=%s" % str(remove_ok))
	lines.append("after_remove_count=%d" % after_remove_count)
	lines.append("duplicate_ok=%s" % str(duplicate_ok))
	lines.append("after_duplicate_count=%d" % after_duplicate_count)
	lines.append("after_duplicate_primary=%s" % String(after_duplicate_primary))
	lines.append("noncombat_after_select_count=%d" % noncombat_after_select_count)
	lines.append("noncombat_after_select_selected_index=%d" % noncombat_after_select_selected_index)
	lines.append("noncombat_after_select_primary=%s" % String(noncombat_after_select_primary))
	lines.append("noncombat_stow_anchor_mode=%s" % String(noncombat_stow_anchor_mode))
	lines.append("noncombat_stow_selector_visible=%s" % str(noncombat_stow_selector_visible))
	lines.append("noncombat_stow_selector_enabled=%s" % str(noncombat_stow_selector_enabled))
	lines.append("noncombat_stow_update_ok=%s" % str(noncombat_stow_update_ok))
	lines.append("noncombat_stow_anchor_after_update=%s" % String(noncombat_stow_anchor_after_update))
	lines.append("noncombat_primary_change_ok=%s" % str(noncombat_primary_change_ok))
	lines.append("noncombat_insert_ok=%s" % str(noncombat_insert_ok))
	lines.append("noncombat_after_insert_count=%d" % noncombat_after_insert_count)
	lines.append("noncombat_remove_ok=%s" % str(noncombat_remove_ok))
	lines.append("noncombat_after_remove_count=%d" % noncombat_after_remove_count)
	lines.append("all_checks_passed=%s" % str(all_checks_passed))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(0 if all_checks_passed else 1)

func _get_motion_node(draft: CombatAnimationDraft, node_index: int) -> CombatAnimationMotionNode:
	if draft == null or node_index < 0 or node_index >= draft.motion_node_chain.size():
		return null
	return draft.motion_node_chain[node_index] as CombatAnimationMotionNode

func _get_primary_hand(draft: CombatAnimationDraft) -> StringName:
	var motion_node: CombatAnimationMotionNode = _get_motion_node(draft, 0)
	return motion_node.primary_hand_slot if motion_node != null else StringName()
