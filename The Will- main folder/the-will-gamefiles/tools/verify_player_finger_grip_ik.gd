extends SceneTree

const PlayerBodyInventoryStateScript = preload("res://core/models/player_body_inventory_state.gd")
const PlayerPersonalStorageStateScript = preload("res://core/models/player_personal_storage_state.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_finger_grip_ik_results.txt"
const TEMP_STATE_DIR := "C:/WORKSPACE/test_artifacts"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var player_scene: PackedScene = load("res://scenes/player/player_character.tscn") as PackedScene
	var player_root: Node = player_scene.instantiate()
	root.add_child(player_root)
	await process_frame
	await process_frame

	var player := player_root as PlayerController3D
	var body_state = PlayerBodyInventoryStateScript.new()
	body_state.save_file_path = "%s/verify_finger_grip_body_inventory_state.tres" % TEMP_STATE_DIR
	var personal_state = PlayerPersonalStorageStateScript.new()
	personal_state.save_file_path = "%s/verify_finger_grip_personal_storage_state.tres" % TEMP_STATE_DIR
	var equipment_state = PlayerEquipmentStateScript.new()
	equipment_state.save_file_path = "%s/verify_finger_grip_player_equipment_state.tres" % TEMP_STATE_DIR
	var wip_library = PlayerForgeWipLibraryStateScript.new()
	wip_library.save_file_path = "%s/verify_finger_grip_player_wip_library_state.tres" % TEMP_STATE_DIR

	player.body_inventory_state = body_state
	player.personal_storage_state = personal_state
	player.equipment_state = equipment_state
	player.forge_wip_library_state = wip_library
	player._sync_equipped_test_meshes()

	var rig: PlayerHumanoidRig = player.humanoid_rig as PlayerHumanoidRig if player != null else null
	var skeleton: Skeleton3D = rig.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if rig != null else null
	var right_index_1: int = skeleton.find_bone("CC_Base_R_Index1") if skeleton != null else -1
	var right_index_3: int = skeleton.find_bone("CC_Base_R_Index3") if skeleton != null else -1
	var right_middle_1: int = skeleton.find_bone("CC_Base_R_Mid1") if skeleton != null else -1
	var right_middle_3: int = skeleton.find_bone("CC_Base_R_Mid3") if skeleton != null else -1
	var right_ring_1: int = skeleton.find_bone("CC_Base_R_Ring1") if skeleton != null else -1
	var right_ring_3: int = skeleton.find_bone("CC_Base_R_Ring3") if skeleton != null else -1
	var right_thumb_1: int = skeleton.find_bone("CC_Base_R_Thumb1") if skeleton != null else -1
	var right_thumb_3: int = skeleton.find_bone("CC_Base_R_Thumb3") if skeleton != null else -1
	var right_pinky_1: int = skeleton.find_bone("CC_Base_R_Pinky1") if skeleton != null else -1
	var right_pinky_2: int = skeleton.find_bone("CC_Base_R_Pinky2") if skeleton != null else -1
	var right_pinky_3: int = skeleton.find_bone("CC_Base_R_Pinky3") if skeleton != null else -1
	var right_upperarm: int = skeleton.find_bone("CC_Base_R_Upperarm") if skeleton != null else -1
	var right_forearm: int = skeleton.find_bone("CC_Base_R_Forearm") if skeleton != null else -1
	var left_index_1: int = skeleton.find_bone("CC_Base_L_Index1") if skeleton != null else -1
	var left_index_3: int = skeleton.find_bone("CC_Base_L_Index3") if skeleton != null else -1
	var right_index_before: Quaternion = skeleton.get_bone_pose_rotation(right_index_1) if skeleton != null and right_index_1 >= 0 else Quaternion.IDENTITY
	var right_middle_before: Quaternion = skeleton.get_bone_pose_rotation(right_middle_1) if skeleton != null and right_middle_1 >= 0 else Quaternion.IDENTITY
	var right_ring_before: Quaternion = skeleton.get_bone_pose_rotation(right_ring_1) if skeleton != null and right_ring_1 >= 0 else Quaternion.IDENTITY
	var right_thumb_before: Quaternion = skeleton.get_bone_pose_rotation(right_thumb_1) if skeleton != null and right_thumb_1 >= 0 else Quaternion.IDENTITY
	var right_pinky_before: Quaternion = skeleton.get_bone_pose_rotation(right_pinky_1) if skeleton != null and right_pinky_1 >= 0 else Quaternion.IDENTITY
	var right_pinky_mid_before: Quaternion = skeleton.get_bone_pose_rotation(right_pinky_2) if skeleton != null and right_pinky_2 >= 0 else Quaternion.IDENTITY
	var right_upperarm_before: Basis = skeleton.get_bone_global_pose_no_override(right_upperarm).basis if skeleton != null and right_upperarm >= 0 else Basis.IDENTITY
	var right_forearm_before: Basis = skeleton.get_bone_global_pose_no_override(right_forearm).basis if skeleton != null and right_forearm >= 0 else Basis.IDENTITY
	var left_index_before: Quaternion = skeleton.get_bone_pose_rotation(left_index_1) if skeleton != null and left_index_1 >= 0 else Quaternion.IDENTITY
	var right_index_tip_before: Vector3 = _get_bone_world_position(skeleton, right_index_3)
	var right_middle_tip_before: Vector3 = _get_bone_world_position(skeleton, right_middle_3)
	var right_ring_tip_before: Vector3 = _get_bone_world_position(skeleton, right_ring_3)
	var right_thumb_tip_before: Vector3 = _get_bone_world_position(skeleton, right_thumb_3)
	var right_pinky_tip_before: Vector3 = _get_bone_world_position(skeleton, right_pinky_3)
	var left_index_tip_before: Vector3 = _get_bone_world_position(skeleton, left_index_3)

	var saved_wip: CraftedItemWIP = wip_library.save_wip(_build_two_hand_grip_test_wip())
	var preview_status: Dictionary = player.preview_saved_wip_test_status(saved_wip.wip_id)
	var equip_result: Dictionary = player.equip_saved_wip_to_hand(saved_wip.wip_id, &"hand_right")

	for _frame_index in range(40):
		await physics_frame
		await process_frame

	var held_item: Node3D = player.held_item_nodes.get(&"hand_right") as Node3D if player != null else null
	var primary_guide: Node3D = held_item.get_node_or_null("PrimaryGripGuide") as Node3D if held_item != null else null
	var primary_shell_center: Node3D = primary_guide.get_node_or_null("GripShellCenter") as Node3D if primary_guide != null else null
	var primary_contact_area: Area3D = primary_shell_center.get_node_or_null("GripContactArea") as Area3D if primary_shell_center != null else null
	var secondary_guide: Node3D = held_item.get_node_or_null("SecondaryGripGuide") as Node3D if held_item != null else null
	var secondary_shell_center: Node3D = secondary_guide.get_node_or_null("GripShellCenter") as Node3D if secondary_guide != null else null
	var right_index_target: Node3D = rig.get_node_or_null("IkTargets/RightFingerGripTargets/IndexGripTarget") as Node3D if rig != null else null
	var right_middle_target: Node3D = rig.get_node_or_null("IkTargets/RightFingerGripTargets/MiddleGripTarget") as Node3D if rig != null else null
	var right_ring_target: Node3D = rig.get_node_or_null("IkTargets/RightFingerGripTargets/RingGripTarget") as Node3D if rig != null else null
	var right_thumb_target: Node3D = rig.get_node_or_null("IkTargets/RightFingerGripTargets/ThumbGripTarget") as Node3D if rig != null else null
	var right_pinky_target: Node3D = rig.get_node_or_null("IkTargets/RightFingerGripTargets/PinkyGripTarget") as Node3D if rig != null else null
	var left_index_target: Node3D = rig.get_node_or_null("IkTargets/LeftFingerGripTargets/IndexGripTarget") as Node3D if rig != null else null
	var right_index_ik: SkeletonModifier3D = skeleton.get_node_or_null("RightIndexGripIK") as SkeletonModifier3D if skeleton != null else null
	var right_middle_ik: SkeletonModifier3D = skeleton.get_node_or_null("RightMiddleGripIK") as SkeletonModifier3D if skeleton != null else null
	var right_ring_ik: SkeletonModifier3D = skeleton.get_node_or_null("RightRingGripIK") as SkeletonModifier3D if skeleton != null else null
	var right_thumb_ik: SkeletonModifier3D = skeleton.get_node_or_null("RightThumbGripIK") as SkeletonModifier3D if skeleton != null else null
	var left_index_ik: SkeletonModifier3D = skeleton.get_node_or_null("LeftIndexGripIK") as SkeletonModifier3D if skeleton != null else null

	var right_index_after: Quaternion = skeleton.get_bone_pose_rotation(right_index_1) if skeleton != null and right_index_1 >= 0 else Quaternion.IDENTITY
	var right_middle_after: Quaternion = skeleton.get_bone_pose_rotation(right_middle_1) if skeleton != null and right_middle_1 >= 0 else Quaternion.IDENTITY
	var right_ring_after: Quaternion = skeleton.get_bone_pose_rotation(right_ring_1) if skeleton != null and right_ring_1 >= 0 else Quaternion.IDENTITY
	var right_thumb_after: Quaternion = skeleton.get_bone_pose_rotation(right_thumb_1) if skeleton != null and right_thumb_1 >= 0 else Quaternion.IDENTITY
	var right_pinky_after: Quaternion = skeleton.get_bone_pose_rotation(right_pinky_1) if skeleton != null and right_pinky_1 >= 0 else Quaternion.IDENTITY
	var right_pinky_mid_after: Quaternion = skeleton.get_bone_pose_rotation(right_pinky_2) if skeleton != null and right_pinky_2 >= 0 else Quaternion.IDENTITY
	var right_upperarm_after: Basis = skeleton.get_bone_global_pose_no_override(right_upperarm).basis if skeleton != null and right_upperarm >= 0 else Basis.IDENTITY
	var right_forearm_after: Basis = skeleton.get_bone_global_pose_no_override(right_forearm).basis if skeleton != null and right_forearm >= 0 else Basis.IDENTITY
	var left_index_after: Quaternion = skeleton.get_bone_pose_rotation(left_index_1) if skeleton != null and left_index_1 >= 0 else Quaternion.IDENTITY
	var right_index_tip_after: Vector3 = _get_bone_world_position(skeleton, right_index_3)
	var right_middle_tip_after: Vector3 = _get_bone_world_position(skeleton, right_middle_3)
	var right_ring_tip_after: Vector3 = _get_bone_world_position(skeleton, right_ring_3)
	var right_thumb_tip_after: Vector3 = _get_bone_world_position(skeleton, right_thumb_3)
	var right_pinky_tip_after: Vector3 = _get_bone_world_position(skeleton, right_pinky_3)
	var left_index_tip_after: Vector3 = _get_bone_world_position(skeleton, left_index_3)

	var lines: PackedStringArray = []
	lines.append("preview_valid=%s" % str(bool(preview_status.get("valid", false))))
	lines.append("equip_success=%s" % str(bool(equip_result.get("success", false))))
	lines.append("held_item_exists=%s" % str(held_item != null))
	lines.append("primary_guide_exists=%s" % str(primary_guide != null))
	lines.append("primary_shell_center_exists=%s" % str(primary_shell_center != null))
	lines.append("primary_contact_area_exists=%s" % str(primary_contact_area != null))
	lines.append("secondary_guide_exists=%s" % str(secondary_guide != null))
	lines.append("secondary_shell_center_exists=%s" % str(secondary_shell_center != null))
	lines.append("right_index_target_exists=%s" % str(right_index_target != null))
	lines.append("right_middle_target_exists=%s" % str(right_middle_target != null))
	lines.append("right_ring_target_exists=%s" % str(right_ring_target != null))
	lines.append("right_thumb_target_exists=%s" % str(right_thumb_target != null))
	lines.append("right_pinky_target_exists=%s" % str(right_pinky_target != null))
	lines.append("left_index_target_exists=%s" % str(left_index_target != null))
	lines.append("right_index_ik_active=%s" % str(right_index_ik != null and right_index_ik.active))
	lines.append("right_middle_ik_active=%s" % str(right_middle_ik != null and right_middle_ik.active))
	lines.append("right_ring_ik_active=%s" % str(right_ring_ik != null and right_ring_ik.active))
	lines.append("right_thumb_ik_active=%s" % str(right_thumb_ik != null and right_thumb_ik.active))
	lines.append("left_index_ik_active=%s" % str(left_index_ik != null and left_index_ik.active))
	lines.append("right_index_rotation_changed=%s" % str(not right_index_before.is_equal_approx(right_index_after)))
	lines.append("right_middle_rotation_changed=%s" % str(not right_middle_before.is_equal_approx(right_middle_after)))
	lines.append("right_ring_rotation_changed=%s" % str(not right_ring_before.is_equal_approx(right_ring_after)))
	lines.append("right_thumb_rotation_changed=%s" % str(not right_thumb_before.is_equal_approx(right_thumb_after)))
	lines.append("right_pinky_rotation_changed=%s" % str(not right_pinky_before.is_equal_approx(right_pinky_after)))
	lines.append("right_pinky_mid_rotation_changed=%s" % str(not right_pinky_mid_before.is_equal_approx(right_pinky_mid_after)))
	lines.append("right_upperarm_rotation_changed=%s" % str(not right_upperarm_before.is_equal_approx(right_upperarm_after)))
	lines.append("right_forearm_rotation_changed=%s" % str(not right_forearm_before.is_equal_approx(right_forearm_after)))
	lines.append("left_index_rotation_changed=%s" % str(not left_index_before.is_equal_approx(left_index_after)))
	lines.append("right_index_tip_moved=%s" % str(not right_index_tip_before.is_equal_approx(right_index_tip_after)))
	lines.append("right_middle_tip_moved=%s" % str(not right_middle_tip_before.is_equal_approx(right_middle_tip_after)))
	lines.append("right_ring_tip_moved=%s" % str(not right_ring_tip_before.is_equal_approx(right_ring_tip_after)))
	lines.append("right_thumb_tip_moved=%s" % str(not right_thumb_tip_before.is_equal_approx(right_thumb_tip_after)))
	lines.append("right_pinky_tip_moved=%s" % str(not right_pinky_tip_before.is_equal_approx(right_pinky_tip_after)))
	lines.append("left_index_tip_moved=%s" % str(not left_index_tip_before.is_equal_approx(left_index_tip_after)))
	lines.append("right_index_target_distance_to_primary_shell=%s" % str(
		snapped(right_index_target.global_position.distance_to(primary_shell_center.global_position), 0.0001)
		if right_index_target != null and primary_shell_center != null
		else -1.0
	))
	lines.append("right_index_tip_distance_to_target=%s" % str(
		snapped(right_index_tip_after.distance_to(right_index_target.global_position), 0.0001)
		if right_index_target != null
		else -1.0
	))
	lines.append("right_thumb_tip_distance_to_target=%s" % str(
		snapped(right_thumb_tip_after.distance_to(right_thumb_target.global_position), 0.0001)
		if right_thumb_target != null
		else -1.0
	))
	lines.append("right_middle_tip_distance_to_target=%s" % str(
		snapped(right_middle_tip_after.distance_to(right_middle_target.global_position), 0.0001)
		if right_middle_target != null
		else -1.0
	))
	lines.append("right_ring_tip_distance_to_target=%s" % str(
		snapped(right_ring_tip_after.distance_to(right_ring_target.global_position), 0.0001)
		if right_ring_target != null
		else -1.0
	))
	lines.append("right_pinky_tip_distance_to_target=%s" % str(
		snapped(right_pinky_tip_after.distance_to(right_pinky_target.global_position), 0.0001)
		if right_pinky_target != null
		else -1.0
	))

	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _build_two_hand_grip_test_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = &"verify_two_hand_finger_grip"
	wip.forge_project_name = "Verify Two Hand Finger Grip"
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

func _get_bone_world_position(skeleton: Skeleton3D, bone_idx: int) -> Vector3:
	if skeleton == null or bone_idx < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_idx).origin)
