extends SceneTree

const PlayerBodyInventoryStateScript = preload("res://core/models/player_body_inventory_state.gd")
const PlayerPersonalStorageStateScript = preload("res://core/models/player_personal_storage_state.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_weapon_guidance_results.txt"
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
	body_state.save_file_path = "%s/verify_guidance_body_inventory_state.tres" % TEMP_STATE_DIR
	var personal_state = PlayerPersonalStorageStateScript.new()
	personal_state.save_file_path = "%s/verify_guidance_personal_storage_state.tres" % TEMP_STATE_DIR
	var equipment_state = PlayerEquipmentStateScript.new()
	equipment_state.save_file_path = "%s/verify_guidance_player_equipment_state.tres" % TEMP_STATE_DIR
	var wip_library = PlayerForgeWipLibraryStateScript.new()
	wip_library.save_file_path = "%s/verify_guidance_player_wip_library_state.tres" % TEMP_STATE_DIR

	player.body_inventory_state = body_state
	player.personal_storage_state = personal_state
	player.equipment_state = equipment_state
	player.forge_wip_library_state = wip_library
	player._sync_equipped_test_meshes()

	var saved_wip: CraftedItemWIP = wip_library.save_wip(_build_two_hand_test_wip())
	var preview_status: Dictionary = player.preview_saved_wip_test_status(saved_wip.wip_id)
	var baked_profile: BakedProfile = preview_status.get("baked_profile") as BakedProfile
	var equip_result: Dictionary = player.equip_saved_wip_to_hand(saved_wip.wip_id, &"hand_right")

	for _i in range(30):
		await physics_frame
		await process_frame

	var rig: PlayerHumanoidRig = player.humanoid_rig as PlayerHumanoidRig if player != null else null
	var skeleton: Skeleton3D = rig.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if rig != null else null
	var required_bones: Array[StringName] = rig.get_required_cc_base_bone_names() if rig != null and rig.has_method("get_required_cc_base_bone_names") else []
	var missing_required_bones: PackedStringArray = []
	for required_bone: StringName in required_bones:
		if skeleton == null or skeleton.find_bone(String(required_bone)) < 0:
			missing_required_bones.append(String(required_bone))
	var left_arm_ik: TwoBoneIK3D = skeleton.get_node_or_null("LeftArmIK") as TwoBoneIK3D if skeleton != null else null
	var right_hand_anchor: Node3D = player._get_hand_anchor(&"hand_right")
	var left_hand_anchor: Node3D = player._get_hand_anchor(&"hand_left")
	var right_weapon: Node3D = _resolve_first_child_node3d(right_hand_anchor)
	var left_guidance_target: Node3D = rig.get_arm_guidance_target(&"hand_left") if rig != null else null
	var left_support_active: bool = rig.is_support_hand_active(&"hand_left") if rig != null else false
	var right_anchor_child_names: PackedStringArray = []
	if right_hand_anchor != null:
		for child_node: Node in right_hand_anchor.get_children():
			right_anchor_child_names.append(child_node.name)
	var secondary_guide: Node3D = right_weapon.get_node_or_null("SecondaryGripGuide") as Node3D if right_weapon != null else null
	if secondary_guide == null and left_guidance_target != null and left_guidance_target.name == "SecondaryGripGuide":
		secondary_guide = left_guidance_target

	var left_hand_index: int = skeleton.find_bone("CC_Base_L_Hand") if skeleton != null else -1
	var left_hand_world_position: Vector3 = Vector3.ZERO
	if left_arm_ik != null:
		await left_arm_ik.modification_processed
		left_hand_world_position = _get_bone_world_position(skeleton, left_hand_index)
	else:
		left_hand_world_position = _get_bone_world_position(skeleton, left_hand_index)
	var left_hand_distance_to_support: float = left_hand_world_position.distance_to(secondary_guide.global_position) if secondary_guide != null else -1.0
	var left_anchor_distance_to_support: float = left_hand_anchor.global_position.distance_to(secondary_guide.global_position) if left_hand_anchor != null and secondary_guide != null else -1.0

	var lines: PackedStringArray = []
	lines.append("player_loaded=%s" % str(player != null))
	lines.append("preview_valid=%s" % str(bool(preview_status.get("valid", false))))
	lines.append("equip_success=%s" % str(bool(equip_result.get("success", false))))
	lines.append("primary_grip_span_length_voxels=%d" % int(baked_profile.primary_grip_span_length_voxels if baked_profile != null else -1))
	lines.append("right_weapon_exists=%s" % str(right_weapon != null))
	lines.append("right_anchor_children=%s" % ", ".join(right_anchor_child_names))
	lines.append("required_cc_base_bones_present=%s" % str(missing_required_bones.is_empty()))
	lines.append("missing_cc_base_bone_count=%d" % missing_required_bones.size())
	lines.append("missing_cc_base_bones=%s" % ", ".join(missing_required_bones))
	lines.append("secondary_guide_exists=%s" % str(secondary_guide != null))
	lines.append("left_guidance_target_exists=%s" % str(left_guidance_target != null))
	lines.append("left_guidance_target_name=%s" % str(left_guidance_target.name if left_guidance_target != null else ""))
	lines.append("left_support_active=%s" % str(left_support_active))
	lines.append("left_arm_influence=%s" % str(snapped(left_arm_ik.influence if left_arm_ik != null else -1.0, 0.0001)))
	lines.append("left_support_target_matches_secondary=%s" % str(left_guidance_target == secondary_guide))
	lines.append("left_hand_distance_to_support=%s" % str(snapped(left_hand_distance_to_support, 0.0001)))
	lines.append("left_anchor_distance_to_support=%s" % str(snapped(left_anchor_distance_to_support, 0.0001)))
	lines.append("left_hand_near_support=%s" % str(left_anchor_distance_to_support >= 0.0 and left_anchor_distance_to_support < 0.12))

	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _build_two_hand_test_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = &"verify_two_hand_guidance_wip"
	wip.forge_project_name = "Verify Two Hand Guidance Sword"
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
	for x in range(20, 42):
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

func _resolve_first_child_node3d(parent_node: Node) -> Node3D:
	if parent_node == null:
		return null
	for child_node: Node in parent_node.get_children():
		if child_node is Node3D:
			return child_node as Node3D
	return null
