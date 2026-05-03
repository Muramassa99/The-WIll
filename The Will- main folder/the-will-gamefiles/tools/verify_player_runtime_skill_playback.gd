extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_runtime_skill_playback_results.txt"
const TEMP_LIBRARY_SAVE_PATH := "C:/WORKSPACE/test_artifacts/verify_player_runtime_skill_playback_library.tres"
const TEMP_SKILL_SLOT_SAVE_PATH := "C:/WORKSPACE/test_artifacts/verify_player_runtime_skill_playback_slots.tres"
const TEMP_EQUIPMENT_SAVE_PATH := "C:/WORKSPACE/test_artifacts/verify_player_runtime_skill_playback_equipment.tres"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library_state.save_file_path = TEMP_LIBRARY_SAVE_PATH
	library_state.saved_wips.clear()

	var authored_wip: CraftedItemWIP = _build_authored_skill_test_wip("Runtime Skill Playback Test", &"skill_slot_3", "Forward Arc")
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

	var skeleton: Skeleton3D = player.humanoid_rig.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if player.humanoid_rig != null else null
	var spine_index: int = skeleton.find_bone("CC_Base_Spine02") if skeleton != null else -1
	var right_clavicle_index: int = skeleton.find_bone("CC_Base_R_Clavicle") if skeleton != null else -1
	var right_upperarm_index: int = skeleton.find_bone("CC_Base_R_Upperarm") if skeleton != null else -1
	var right_forearm_index: int = skeleton.find_bone("CC_Base_R_Forearm") if skeleton != null else -1
	var spine_before: Quaternion = skeleton.get_bone_pose_rotation(spine_index) if spine_index >= 0 else Quaternion.IDENTITY
	var right_clavicle_before: Quaternion = skeleton.get_bone_pose_rotation(right_clavicle_index) if right_clavicle_index >= 0 else Quaternion.IDENTITY
	var right_upperarm_before: Quaternion = skeleton.get_bone_pose_rotation(right_upperarm_index) if right_upperarm_index >= 0 else Quaternion.IDENTITY
	var right_forearm_before: Quaternion = skeleton.get_bone_pose_rotation(right_forearm_index) if right_forearm_index >= 0 else Quaternion.IDENTITY

	player.call("_sync_equipped_skill_slots")
	player.call("_activate_skill_slot", &"skill_slot_3")
	var activation_result: Dictionary = player.get_last_skill_activation_result()
	var runtime_debug_initial: Dictionary = player.get_runtime_skill_playback_debug_state()
	await physics_frame
	await process_frame
	await process_frame
	var runtime_debug_after_tick: Dictionary = player.get_runtime_skill_playback_debug_state()
	var rig_state: Dictionary = (
		player.humanoid_rig.get_upper_body_authoring_state()
		if player.humanoid_rig != null and player.humanoid_rig.has_method("get_upper_body_authoring_state")
		else {}
	)
	var grip_debug_state: Dictionary = (
		player.humanoid_rig.get_grip_contact_debug_state()
		if player.humanoid_rig != null and player.humanoid_rig.has_method("get_grip_contact_debug_state")
		else {}
	)
	var spine_after: Quaternion = skeleton.get_bone_pose_rotation(spine_index) if spine_index >= 0 else Quaternion.IDENTITY
	var right_clavicle_after: Quaternion = skeleton.get_bone_pose_rotation(right_clavicle_index) if right_clavicle_index >= 0 else Quaternion.IDENTITY
	var right_upperarm_after: Quaternion = skeleton.get_bone_pose_rotation(right_upperarm_index) if right_upperarm_index >= 0 else Quaternion.IDENTITY
	var right_forearm_after: Quaternion = skeleton.get_bone_pose_rotation(right_forearm_index) if right_forearm_index >= 0 else Quaternion.IDENTITY
	var runtime_spine_changed: bool = spine_before.angle_to(spine_after) > 0.0001
	var runtime_right_clavicle_changed: bool = right_clavicle_before.angle_to(right_clavicle_after) > 0.0001
	var runtime_right_upperarm_changed: bool = right_upperarm_before.angle_to(right_upperarm_after) > 0.0001
	var runtime_right_forearm_changed: bool = right_forearm_before.angle_to(right_forearm_after) > 0.0001
	var dominant_guidance_active: bool = bool(grip_debug_state.get("right_arm_guidance_active", false))
	var dominant_ik_active: bool = bool(grip_debug_state.get("right_arm_ik_active", false))
	var dominant_contact_basis_active: bool = bool(grip_debug_state.get("right_authoring_contact_basis_active", false))
	var direct_authoring_solver_mode: bool = bool(grip_debug_state.get("direct_authoring_solver_mode", false))
	var runtime_clip_debug: Dictionary = runtime_debug_initial.get("runtime_clip_debug_state", {}) as Dictionary
	var pose_state_after_tick: Dictionary = runtime_debug_after_tick.get("last_runtime_pose_state", {}) as Dictionary
	var all_checks_passed: bool = (
		bool(activation_result.get("success", false))
		and bool(activation_result.get("runtime_playback_started", false))
		and bool(runtime_debug_initial.get("active", false))
		and bool(runtime_debug_initial.get("runtime_clip_active", false))
		and int(runtime_clip_debug.get("frame_count", 0)) > 0
		and bool(runtime_debug_after_tick.get("active", false))
		and bool(pose_state_after_tick.has("tip_position_local"))
		and bool(rig_state.get("active", false))
		and runtime_spine_changed
		and runtime_right_clavicle_changed
		and runtime_right_upperarm_changed
		and runtime_right_forearm_changed
		and dominant_guidance_active
		and direct_authoring_solver_mode
		and not dominant_ik_active
		and dominant_contact_basis_active
		and bool(pose_state_after_tick.get("runtime_endpoint_authority_active", false))
	)

	var lines: PackedStringArray = []
	lines.append("activation_success=%s" % str(bool(activation_result.get("success", false))))
	lines.append("runtime_started=%s" % str(bool(activation_result.get("runtime_playback_started", false))))
	lines.append("runtime_message=%s" % String(activation_result.get("runtime_playback_message", "")))
	lines.append("runtime_source_slot=%s" % String(activation_result.get("source_equipment_slot_id", StringName())))
	lines.append("runtime_active_initial=%s" % str(bool(runtime_debug_initial.get("active", false))))
	lines.append("runtime_motion_node_count=%d" % int(runtime_debug_initial.get("motion_node_count", 0)))
	lines.append("runtime_clip_active=%s" % str(bool(runtime_debug_initial.get("runtime_clip_active", false))))
	lines.append("runtime_clip_frame_count=%d" % int(runtime_clip_debug.get("frame_count", 0)))
	lines.append("runtime_clip_duration_seconds=%.2f" % float(runtime_clip_debug.get("total_duration_seconds", 0.0)))
	lines.append("runtime_compile_diagnostic_count=%d" % int((runtime_debug_initial.get("runtime_compile_diagnostics", []) as Array).size()))
	lines.append("runtime_compile_degraded_node_count=%d" % int(runtime_debug_initial.get("runtime_compile_degraded_node_count", -1)))
	lines.append("runtime_compile_hand_swap_bridge_count=%d" % int(runtime_debug_initial.get("runtime_compile_hand_swap_bridge_count", -1)))
	lines.append("runtime_compile_retargeted_count=%d" % int(runtime_debug_initial.get("runtime_compile_retargeted_count", -1)))
	lines.append("runtime_active_after_tick=%s" % str(bool(runtime_debug_after_tick.get("active", false))))
	lines.append("runtime_pose_has_tip=%s" % str(
		bool((runtime_debug_after_tick.get("last_runtime_pose_state", {}) as Dictionary).has("tip_position_local"))
	))
	lines.append("upper_body_authoring_active=%s" % str(bool(rig_state.get("active", false))))
	lines.append("runtime_spine_changed=%s" % str(runtime_spine_changed))
	lines.append("runtime_right_clavicle_changed=%s" % str(runtime_right_clavicle_changed))
	lines.append("runtime_right_upperarm_changed=%s" % str(runtime_right_upperarm_changed))
	lines.append("runtime_right_forearm_changed=%s" % str(runtime_right_forearm_changed))
	lines.append("runtime_spine_angle_delta=%s" % str(snapped(spine_before.angle_to(spine_after), 0.0001)))
	lines.append("runtime_right_clavicle_angle_delta=%s" % str(snapped(right_clavicle_before.angle_to(right_clavicle_after), 0.0001)))
	lines.append("runtime_right_upperarm_angle_delta=%s" % str(snapped(right_upperarm_before.angle_to(right_upperarm_after), 0.0001)))
	lines.append("runtime_right_forearm_angle_delta=%s" % str(snapped(right_forearm_before.angle_to(right_forearm_after), 0.0001)))
	lines.append("dominant_arm_guidance_active=%s" % str(dominant_guidance_active))
	lines.append("dominant_arm_ik_active=%s" % str(dominant_ik_active))
	lines.append("direct_authoring_solver_mode=%s" % str(direct_authoring_solver_mode))
	lines.append("dominant_contact_basis_active=%s" % str(dominant_contact_basis_active))
	lines.append("runtime_endpoint_authority_active=%s" % str(bool(pose_state_after_tick.get("runtime_endpoint_authority_active", false))))
	lines.append("runtime_held_item_parent_path=%s" % String(pose_state_after_tick.get("held_item_parent_path", "")))
	lines.append("dominant_hand_ik_target_distance_meters=%.4f" % float(grip_debug_state.get("right_hand_ik_target_distance_meters", -1.0)))
	lines.append("all_checks_passed=%s" % str(all_checks_passed))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(0 if all_checks_passed else 1)

func _build_authored_skill_test_wip(project_name: String, slot_id: StringName, skill_name: String) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = StringName(project_name.to_snake_case())
	wip.forge_project_name = project_name
	wip.creator_id = &"verify"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
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
	var draft: CombatAnimationDraft = station_state.get_or_create_skill_draft(
		slot_id,
		String(slot_id).replace("_", " ").capitalize(),
		wip.grip_style_mode,
		slot_id
	) as CombatAnimationDraft
	if draft != null:
		draft.skill_name = skill_name
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
