extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_runtime_skill_entry_recovery_results.txt"
const TEMP_LIBRARY_SAVE_PATH := "C:/WORKSPACE/test_artifacts/verify_player_runtime_skill_entry_recovery_library.tres"
const TEMP_SKILL_SLOT_SAVE_PATH := "C:/WORKSPACE/test_artifacts/verify_player_runtime_skill_entry_recovery_slots.tres"
const TEMP_EQUIPMENT_SAVE_PATH := "C:/WORKSPACE/test_artifacts/verify_player_runtime_skill_entry_recovery_equipment.tres"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library_state.save_file_path = TEMP_LIBRARY_SAVE_PATH
	library_state.saved_wips.clear()

	var authored_wip: CraftedItemWIP = _build_entry_recovery_test_wip()
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
	root.add_child(player)
	await process_frame
	await physics_frame
	await process_frame
	await physics_frame

	player.call("_sync_equipped_skill_slots")
	var idle_debug_before: Dictionary = player.get_runtime_idle_pose_debug_state()
	player.call("_activate_skill_slot", &"skill_slot_1")
	var activation_result: Dictionary = player.get_last_skill_activation_result()
	var entry_debug: Dictionary = player.get_runtime_skill_playback_debug_state()
	var entry_hidden_bridge: Dictionary = entry_debug.get("hidden_bridge_state", {}) as Dictionary
	await physics_frame
	await process_frame

	for frame_index: int in range(28):
		await physics_frame
		await process_frame

	var runtime_debug_after_finish: Dictionary = player.get_runtime_skill_playback_debug_state()
	var idle_debug_recovery: Dictionary = player.get_runtime_idle_pose_debug_state()
	var recovery_hidden_bridge: Dictionary = idle_debug_recovery.get("hidden_bridge_state", {}) as Dictionary

	var lines: PackedStringArray = []
	lines.append("idle_active_before_skill=%s" % str(bool(idle_debug_before.get("active", false))))
	lines.append("activation_success=%s" % str(bool(activation_result.get("success", false))))
	lines.append("runtime_started=%s" % str(bool(activation_result.get("runtime_playback_started", false))))
	lines.append("entry_bridge_active=%s" % str(bool(entry_debug.get("entry_bridge_active", false))))
	lines.append("entry_bridge_duration_seconds=%.2f" % float(entry_debug.get("entry_bridge_duration_seconds", 0.0)))
	lines.append("entry_duration_ok=%s" % str(absf(float(entry_debug.get("entry_bridge_duration_seconds", 0.0)) - 0.3) <= 0.001))
	lines.append("entry_grip_swap_active=%s" % str(bool(entry_debug.get("entry_grip_swap_active", false))))
	lines.append("entry_source_grip=%s" % String(entry_debug.get("entry_source_grip_style_mode", StringName())))
	lines.append("entry_target_grip=%s" % String(entry_debug.get("entry_target_grip_style_mode", StringName())))
	lines.append("entry_source_grip_ok=%s" % str(entry_debug.get("entry_source_grip_style_mode", StringName()) == CraftedItemWIPScript.GRIP_NORMAL))
	lines.append("entry_target_grip_ok=%s" % str(entry_debug.get("entry_target_grip_style_mode", StringName()) == CraftedItemWIPScript.GRIP_REVERSE))
	lines.append("entry_hidden_bridge_kind=%s" % String(entry_hidden_bridge.get("kind", StringName())))
	lines.append("entry_hidden_bridge_active=%s" % str(bool(entry_hidden_bridge.get("active", false))))
	lines.append("entry_hidden_recent_has_entry=%s" % str(_recent_kinds_has(entry_hidden_bridge, &"skill_entry")))
	lines.append("entry_trajectory_volume_enabled=%s" % str(bool(entry_debug.get("trajectory_volume_enabled", false))))
	lines.append("runtime_active_after_finish_window=%s" % str(bool(runtime_debug_after_finish.get("active", false))))
	lines.append("idle_active_during_recovery=%s" % str(bool(idle_debug_recovery.get("active", false))))
	lines.append("recovery_bridge_active=%s" % str(bool(idle_debug_recovery.get("recovery_bridge_active", false))))
	lines.append("recovery_bridge_duration_seconds=%.2f" % float(idle_debug_recovery.get("recovery_bridge_duration_seconds", 0.0)))
	lines.append("recovery_duration_ok=%s" % str(absf(float(idle_debug_recovery.get("recovery_bridge_duration_seconds", 0.0)) - 1.2) <= 0.001))
	lines.append("recovery_grip_swap_active=%s" % str(bool(idle_debug_recovery.get("recovery_grip_swap_active", false))))
	lines.append("recovery_source_grip=%s" % String(idle_debug_recovery.get("recovery_source_grip_style_mode", StringName())))
	lines.append("recovery_target_grip=%s" % String(idle_debug_recovery.get("recovery_target_grip_style_mode", StringName())))
	lines.append("recovery_source_grip_ok=%s" % str(idle_debug_recovery.get("recovery_source_grip_style_mode", StringName()) == CraftedItemWIPScript.GRIP_REVERSE))
	lines.append("recovery_target_grip_ok=%s" % str(idle_debug_recovery.get("recovery_target_grip_style_mode", StringName()) == CraftedItemWIPScript.GRIP_NORMAL))
	lines.append("recovery_hidden_bridge_kind=%s" % String(recovery_hidden_bridge.get("kind", StringName())))
	lines.append("recovery_hidden_bridge_active=%s" % str(bool(recovery_hidden_bridge.get("active", false))))
	lines.append("recovery_hidden_recent_has_recovery=%s" % str(_recent_kinds_has(recovery_hidden_bridge, &"skill_recovery")))
	lines.append("recovery_trajectory_volume_enabled=%s" % str(bool(idle_debug_recovery.get("trajectory_volume_enabled", false))))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _recent_kinds_has(bridge_state: Dictionary, bridge_kind: StringName) -> bool:
	var recent_kinds: Array = bridge_state.get("recent_kinds", []) as Array
	for kind_variant: Variant in recent_kinds:
		if StringName(kind_variant) == bridge_kind:
			return true
	return false

func _build_entry_recovery_test_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = &"entry_recovery_test_weapon"
	wip.forge_project_name = "Runtime Entry Recovery Test"
	wip.creator_id = &"verify"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.grip_style_mode = CraftedItemWIPScript.GRIP_NORMAL
	var layer_a: LayerAtom = LayerAtom.new()
	layer_a.layer_index = 20
	layer_a.cells = _build_handle_cells(20)
	var layer_b: LayerAtom = LayerAtom.new()
	layer_b.layer_index = 21
	layer_b.cells = _build_handle_cells(21)
	wip.layers = [layer_a, layer_b]

	var station_state: CombatAnimationStationState = wip.ensure_combat_animation_station_state() as CombatAnimationStationState
	if station_state == null:
		return wip
	var idle_draft: CombatAnimationDraft = station_state.get_or_create_idle_draft(
		CombatAnimationStationStateScript.IDLE_CONTEXT_COMBAT,
		"Combat Idle",
		wip.grip_style_mode
	) as CombatAnimationDraft
	if idle_draft != null:
		idle_draft.ensure_minimum_baseline_nodes()
		var idle_node: CombatAnimationMotionNode = idle_draft.motion_node_chain[0] as CombatAnimationMotionNode
		if idle_node != null:
			idle_node.tip_position_local = Vector3(0.35, 0.12, -0.42)
			idle_node.pommel_position_local = Vector3(-0.16, -0.04, 0.25)
			idle_node.weapon_orientation_degrees = Vector3(0.0, -18.0, 0.0)
			idle_node.weapon_orientation_authored = true
			idle_node.preferred_grip_style_mode = CraftedItemWIPScript.GRIP_NORMAL
			idle_node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
			idle_node.normalize()

	var skill_draft: CombatAnimationDraft = station_state.get_or_create_skill_draft(
		&"skill_slot_1",
		"Runtime Bridge Skill",
		wip.grip_style_mode,
		&"skill_slot_1"
	) as CombatAnimationDraft
	if skill_draft != null:
		skill_draft.skill_name = "Runtime Bridge Skill"
		skill_draft.ensure_minimum_baseline_nodes()
		var hidden_node: CombatAnimationMotionNode = skill_draft.motion_node_chain[0] as CombatAnimationMotionNode
		var first_node: CombatAnimationMotionNode = skill_draft.motion_node_chain[1] as CombatAnimationMotionNode
		if hidden_node != null:
			hidden_node.tip_position_local = Vector3(0.35, 0.12, -0.42)
			hidden_node.pommel_position_local = Vector3(-0.16, -0.04, 0.25)
			hidden_node.weapon_orientation_authored = true
			hidden_node.preferred_grip_style_mode = CraftedItemWIPScript.GRIP_NORMAL
			hidden_node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
			hidden_node.normalize()
		if first_node != null:
			first_node.tip_position_local = Vector3(-0.18, 0.22, 0.36)
			first_node.pommel_position_local = Vector3(0.42, -0.02, -0.26)
			first_node.weapon_orientation_degrees = Vector3(0.0, 28.0, 0.0)
			first_node.weapon_orientation_authored = true
			first_node.preferred_grip_style_mode = CraftedItemWIPScript.GRIP_REVERSE
			first_node.transition_duration_seconds = 0.05
			first_node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
			first_node.normalize()
		skill_draft.preview_loop_enabled = false
		skill_draft.normalize()
	return wip

func _build_handle_cells(layer_index: int) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	for x in range(20, 48):
		for y in range(10, 13):
			var cell: CellAtom = CellAtom.new()
			cell.grid_position = Vector3i(x, y, layer_index)
			cell.layer_index = layer_index
			cell.material_variant_id = &"mat_wood_gray"
			cells.append(cell)
	return cells
