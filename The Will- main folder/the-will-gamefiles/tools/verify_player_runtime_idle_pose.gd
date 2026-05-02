extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_runtime_idle_pose_results.txt"
const TEMP_LIBRARY_SAVE_PATH := "C:/WORKSPACE/test_artifacts/verify_player_runtime_idle_pose_library.tres"
const TEMP_SKILL_SLOT_SAVE_PATH := "C:/WORKSPACE/test_artifacts/verify_player_runtime_idle_pose_slots.tres"
const TEMP_EQUIPMENT_SAVE_PATH := "C:/WORKSPACE/test_artifacts/verify_player_runtime_idle_pose_equipment.tres"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library_state.save_file_path = TEMP_LIBRARY_SAVE_PATH
	library_state.saved_wips.clear()

	var authored_wip: CraftedItemWIP = _build_authored_idle_test_wip("Runtime Idle Pose Test")
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

	var idle_result: Dictionary = player.get_last_runtime_idle_pose_result()
	var idle_debug: Dictionary = player.get_runtime_idle_pose_debug_state()
	var rig_state: Dictionary = (
		player.humanoid_rig.get_upper_body_authoring_state()
		if player.humanoid_rig != null and player.humanoid_rig.has_method("get_upper_body_authoring_state")
		else {}
	)
	var pose_state: Dictionary = idle_debug.get("last_runtime_idle_pose_state", {}) as Dictionary

	player.set_weapons_drawn(false)
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame

	var stowed_idle_result: Dictionary = player.get_last_runtime_idle_pose_result()
	var stowed_idle_debug: Dictionary = player.get_runtime_idle_pose_debug_state()
	var stowed_rig_state: Dictionary = (
		player.humanoid_rig.get_upper_body_authoring_state()
		if player.humanoid_rig != null and player.humanoid_rig.has_method("get_upper_body_authoring_state")
		else {}
	)
	var rig: PlayerHumanoidRig = player.humanoid_rig as PlayerHumanoidRig if player != null else null
	var expected_station_stow_mode: StringName = CombatAnimationDraft.STOW_ANCHOR_LOWER_BACK
	var stow_anchor: Node3D = (
		rig.get_weapon_stow_anchor(expected_station_stow_mode, &"hand_right")
		if rig != null
		else null
	)
	var stowed_weapon_node: Node3D = player.held_item_nodes.get(&"hand_right") as Node3D
	var contact_debug: Dictionary = (
		rig.get_grip_contact_debug_state()
		if rig != null and rig.has_method("get_grip_contact_debug_state")
		else {}
	)
	var stowed_weapon_parent_matches: bool = stowed_weapon_node != null and stowed_weapon_node.get_parent() == stow_anchor

	player.set_weapons_drawn(true)
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame
	player.combat_idle_expiry_seconds = 0.05
	player.runtime_skill_playback_presenter.set_combat_idle_expiry_seconds(0.05)
	player.runtime_skill_playback_presenter.mark_combat_action_used()
	for frame_index: int in range(8):
		await physics_frame
		await process_frame

	var expiry_idle_result: Dictionary = player.get_last_runtime_idle_pose_result()
	var expiry_idle_debug: Dictionary = player.get_runtime_idle_pose_debug_state()
	var expiry_hidden_bridge: Dictionary = expiry_idle_debug.get("hidden_bridge_state", {}) as Dictionary

	var lines: PackedStringArray = []
	lines.append("idle_resolved=%s" % str(bool(idle_result.get("success", false))))
	lines.append("idle_applied=%s" % str(bool(idle_result.get("runtime_idle_applied", false))))
	lines.append("idle_message=%s" % String(idle_result.get("runtime_idle_message", "")))
	lines.append("idle_debug_active=%s" % str(bool(idle_debug.get("active", false))))
	lines.append("idle_source_slot=%s" % String(idle_debug.get("dominant_slot_id", StringName())))
	lines.append("idle_motion_node_count=%d" % int(idle_debug.get("motion_node_count", 0)))
	lines.append("idle_runtime_clip_active=%s" % str(bool(idle_debug.get("runtime_clip_active", false))))
	var idle_clip_debug: Dictionary = idle_debug.get("runtime_clip_debug_state", {}) as Dictionary
	lines.append("idle_runtime_clip_frame_count=%d" % int(idle_clip_debug.get("frame_count", 0)))
	lines.append("idle_pose_has_tip=%s" % str(pose_state.has("tip_position_local")))
	lines.append("upper_body_authoring_active=%s" % str(bool(rig_state.get("active", false))))
	lines.append("runtime_skill_active=%s" % str(player.is_runtime_skill_playback_active()))
	lines.append("stowed_idle_resolved=%s" % str(bool(stowed_idle_result.get("success", false))))
	lines.append("stowed_idle_context=%s" % String(stowed_idle_result.get("idle_context_id", StringName())))
	lines.append("stowed_idle_applied=%s" % str(bool(stowed_idle_result.get("runtime_idle_applied", false))))
	lines.append("stowed_idle_message=%s" % String(stowed_idle_result.get("runtime_idle_message", "")))
	lines.append("stowed_idle_debug_active=%s" % str(bool(stowed_idle_debug.get("active", false))))
	lines.append("stowed_presentation=%s" % str(bool(stowed_idle_result.get("stowed_presentation", false))))
	lines.append("stowed_hands_interact=%s" % str(bool(stowed_idle_result.get("hands_interact_with_weapon", true))))
	lines.append("stowed_station_stow_mode=%s" % String(stowed_idle_result.get("stow_position_mode", StringName())))
	lines.append("stowed_station_motion_node_count=%d" % int(stowed_idle_result.get("motion_node_count", 0)))
	lines.append("stowed_upper_body_authoring_active=%s" % str(bool(stowed_rig_state.get("active", false))))
	lines.append("stowed_weapon_parent_matches=%s" % str(stowed_weapon_parent_matches))
	lines.append("stowed_right_arm_guidance_active=%s" % str(bool(contact_debug.get("right_arm_guidance_active", false))))
	lines.append("stowed_left_arm_guidance_active=%s" % str(bool(contact_debug.get("left_arm_guidance_active", false))))
	lines.append("expiry_weapons_stowed=%s" % str(not player.weapons_drawn))
	lines.append("expiry_idle_context=%s" % String(expiry_idle_result.get("idle_context_id", StringName())))
	lines.append("expiry_stowed_presentation=%s" % str(bool(expiry_idle_result.get("stowed_presentation", false))))
	lines.append("expiry_hidden_bridge_kind=%s" % String(expiry_hidden_bridge.get("kind", StringName())))
	lines.append("expiry_hidden_recent_has_stow=%s" % str(_recent_kinds_has(expiry_hidden_bridge, &"stow_to_noncombat_idle")))
	lines.append("expiry_stow_duration_seconds=%.2f" % float(expiry_hidden_bridge.get("duration_seconds", 0.0)))

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

func _build_authored_idle_test_wip(project_name: String) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = StringName(project_name.to_snake_case())
	wip.forge_project_name = project_name
	wip.creator_id = &"verify"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.stow_position_mode = CraftedItemWIP.STOW_SHOULDER_HANGING
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
	if idle_draft == null:
		return wip
	idle_draft.ensure_minimum_baseline_nodes()
	var idle_node: CombatAnimationMotionNode = idle_draft.motion_node_chain[0] as CombatAnimationMotionNode
	if idle_node != null:
		idle_node.tip_position_local = Vector3(0.35, 0.1, -0.45)
		idle_node.pommel_position_local = Vector3(-0.15, -0.05, 0.24)
		idle_node.weapon_orientation_degrees = Vector3(0.0, -18.0, 0.0)
		idle_node.weapon_orientation_authored = true
		idle_node.body_support_blend = 0.45
		idle_node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
		idle_node.preferred_grip_style_mode = wip.grip_style_mode
		idle_node.normalize()
	var noncombat_idle_draft: CombatAnimationDraft = station_state.get_or_create_idle_draft(
		CombatAnimationStationStateScript.IDLE_CONTEXT_NONCOMBAT,
		"Noncombat Idle",
		wip.grip_style_mode,
		CombatAnimationDraft.STOW_ANCHOR_LOWER_BACK
	) as CombatAnimationDraft
	if noncombat_idle_draft != null:
		noncombat_idle_draft.ensure_minimum_baseline_nodes()
		noncombat_idle_draft.stow_anchor_mode = CombatAnimationDraft.STOW_ANCHOR_LOWER_BACK
		var stow_node: CombatAnimationMotionNode = noncombat_idle_draft.motion_node_chain[0] as CombatAnimationMotionNode
		if stow_node != null:
			stow_node.tip_position_local = Vector3(0.02, 0.04, -0.08)
			stow_node.pommel_position_local = Vector3(-0.02, -0.02, 0.08)
			stow_node.weapon_orientation_degrees = Vector3(4.0, -164.0, 22.0)
			stow_node.weapon_orientation_authored = true
			stow_node.preferred_grip_style_mode = wip.grip_style_mode
			stow_node.normalize()
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
