extends SceneTree

const PlayerBodyInventoryStateScript = preload("res://core/models/player_body_inventory_state.gd")
const PlayerPersonalStorageStateScript = preload("res://core/models/player_personal_storage_state.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_weapon_grip_orientation_results.txt"
const TEMP_STATE_DIR := "C:/WORKSPACE/test_artifacts"
const TEST_GRIP_LAYER_START := 20
const TEST_GRIP_SLICE_COUNT := 20

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var player_scene: PackedScene = load("res://scenes/player/player_character.tscn") as PackedScene
	var player_root: PlayerController3D = player_scene.instantiate() as PlayerController3D
	var skill_slot_state := PlayerSkillSlotStateScript.new()
	skill_slot_state.save_file_path = "%s/verify_grip_orientation_skill_slot_state.tres" % TEMP_STATE_DIR
	player_root.player_skill_slot_state = skill_slot_state
	root.add_child(player_root)
	await process_frame
	await process_frame

	var player := player_root as PlayerController3D
	var body_state = PlayerBodyInventoryStateScript.new()
	body_state.save_file_path = "%s/verify_grip_orientation_body_inventory_state.tres" % TEMP_STATE_DIR
	var personal_state = PlayerPersonalStorageStateScript.new()
	personal_state.save_file_path = "%s/verify_grip_orientation_personal_storage_state.tres" % TEMP_STATE_DIR
	var equipment_state = PlayerEquipmentStateScript.new()
	equipment_state.save_file_path = "%s/verify_grip_orientation_player_equipment_state.tres" % TEMP_STATE_DIR
	var wip_library = PlayerForgeWipLibraryStateScript.new()
	wip_library.save_file_path = "%s/verify_grip_orientation_player_wip_library_state.tres" % TEMP_STATE_DIR

	player.body_inventory_state = body_state
	player.personal_storage_state = personal_state
	player.equipment_state = equipment_state
	player.forge_wip_library_state = wip_library
	player._sync_equipped_test_meshes()

	var right_normal_wip: CraftedItemWIP = wip_library.save_wip(_build_valid_test_wip(&"verify_right_normal", CraftedItemWIP.GRIP_NORMAL))
	var right_reverse_wip: CraftedItemWIP = wip_library.save_wip(_build_valid_test_wip(&"verify_right_reverse", CraftedItemWIP.GRIP_REVERSE))
	var left_normal_wip: CraftedItemWIP = wip_library.save_wip(_build_valid_test_wip(&"verify_left_normal", CraftedItemWIP.GRIP_NORMAL))
	var left_reverse_wip: CraftedItemWIP = wip_library.save_wip(_build_valid_test_wip(&"verify_left_reverse", CraftedItemWIP.GRIP_REVERSE))

	var right_normal_data: Dictionary = await _equip_and_measure(player, right_normal_wip.wip_id, &"hand_right", CraftedItemWIP.GRIP_NORMAL)
	var right_reverse_data: Dictionary = await _equip_and_measure(player, right_reverse_wip.wip_id, &"hand_right", CraftedItemWIP.GRIP_REVERSE)
	var left_normal_data: Dictionary = await _equip_and_measure(player, left_normal_wip.wip_id, &"hand_left", CraftedItemWIP.GRIP_NORMAL)
	var left_reverse_data: Dictionary = await _equip_and_measure(player, left_reverse_wip.wip_id, &"hand_left", CraftedItemWIP.GRIP_REVERSE)

	var lines: PackedStringArray = []
	lines.append("right_normal_exists=%s" % str(right_normal_data.get("exists", false)))
	lines.append("right_reverse_exists=%s" % str(right_reverse_data.get("exists", false)))
	lines.append("left_normal_exists=%s" % str(left_normal_data.get("exists", false)))
	lines.append("left_reverse_exists=%s" % str(left_reverse_data.get("exists", false)))
	lines.append("right_normal_tip_axis_score=%s" % str(snappedf(float(right_normal_data.get("tip_axis_score", -2.0)), 0.0001)))
	lines.append("right_reverse_tip_axis_score=%s" % str(snappedf(float(right_reverse_data.get("tip_axis_score", -2.0)), 0.0001)))
	lines.append("left_normal_tip_axis_score=%s" % str(snappedf(float(left_normal_data.get("tip_axis_score", -2.0)), 0.0001)))
	lines.append("left_reverse_tip_axis_score=%s" % str(snappedf(float(left_reverse_data.get("tip_axis_score", -2.0)), 0.0001)))
	lines.append("right_normal_grip_style=%s" % String(right_normal_data.get("grip_style_mode", StringName())))
	lines.append("right_reverse_grip_style=%s" % String(right_reverse_data.get("grip_style_mode", StringName())))
	lines.append("left_normal_grip_style=%s" % String(left_normal_data.get("grip_style_mode", StringName())))
	lines.append("left_reverse_grip_style=%s" % String(left_reverse_data.get("grip_style_mode", StringName())))
	lines.append("right_normal_tip_axis_matches_contact_axis=%s" % str(float(right_normal_data.get("tip_axis_score", -2.0)) > 0.95))
	lines.append("right_reverse_tip_axis_matches_reverse_contact_axis=%s" % str(float(right_reverse_data.get("tip_axis_score", 2.0)) > 0.95))
	lines.append("left_normal_tip_axis_matches_contact_axis=%s" % str(float(left_normal_data.get("tip_axis_score", -2.0)) > 0.95))
	lines.append("left_reverse_tip_axis_matches_reverse_contact_axis=%s" % str(float(left_reverse_data.get("tip_axis_score", 2.0)) > 0.95))
	lines.append("right_reverse_support_guide_absent=%s" % str(not bool(right_reverse_data.get("has_secondary_guide", true))))
	lines.append("left_reverse_support_guide_absent=%s" % str(not bool(left_reverse_data.get("has_secondary_guide", true))))

	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _equip_and_measure(
	player: PlayerController3D,
	saved_wip_id: StringName,
	slot_id: StringName,
	desired_grip_style_mode: StringName
) -> Dictionary:
	player.clear_equipment_slot(&"hand_right")
	player.clear_equipment_slot(&"hand_left")
	await process_frame
	await process_frame
	player.equip_saved_wip_to_hand(saved_wip_id, slot_id)
	await process_frame
	await process_frame

	var held_item: Node3D = player.held_item_nodes.get(slot_id) as Node3D
	if held_item == null:
		return {
			"exists": false,
			"tip_axis_score": -2.0,
			"has_secondary_guide": false
		}
	player.equipped_item_presenter.apply_held_item_grip_style_mode(
		held_item,
		player.humanoid_rig,
		slot_id,
		desired_grip_style_mode
	)
	player.equipped_item_presenter.apply_hand_mount_transform(held_item)
	await process_frame
	var local_tip: Vector3 = held_item.get_meta("weapon_tip_local", Vector3.ZERO) as Vector3
	var local_grip: Vector3 = held_item.get_meta("primary_grip_contact_local", Vector3.ZERO) as Vector3
	var local_tip_axis: Vector3 = local_tip - local_grip
	var tip_axis_score: float = -2.0
	if local_tip_axis.length_squared() > 0.000001:
		var expected_contact_axis: Vector3 = _resolve_contact_axis_local(player, slot_id)
		var grip_style_mode: StringName = held_item.get_meta("grip_style_mode", CraftedItemWIP.GRIP_NORMAL) as StringName
		if grip_style_mode == CraftedItemWIP.GRIP_REVERSE:
			expected_contact_axis = -expected_contact_axis
		var hand_anchor: Node3D = held_item.get_parent() as Node3D
		var expected_anchor_axis: Vector3 = expected_contact_axis
		if hand_anchor != null:
			expected_anchor_axis = (hand_anchor.transform.basis.inverse() * expected_contact_axis).normalized()
		var tip_axis_in_anchor: Vector3 = (held_item.transform.basis * local_tip_axis.normalized()).normalized()
		tip_axis_score = tip_axis_in_anchor.dot(expected_anchor_axis.normalized())
	return {
		"exists": true,
		"tip_axis_score": tip_axis_score,
		"grip_style_mode": held_item.get_meta("grip_style_mode", StringName()),
		"has_secondary_guide": held_item.get_node_or_null("SecondaryGripGuide") != null
	}

func _resolve_contact_axis_local(player: PlayerController3D, slot_id: StringName) -> Vector3:
	var humanoid_rig: Node3D = player.humanoid_rig if player != null else null
	if humanoid_rig != null and humanoid_rig.has_method("resolve_hand_index_pinky_axis_local"):
		var resolved_axis: Vector3 = humanoid_rig.call("resolve_hand_index_pinky_axis_local", slot_id) as Vector3
		if resolved_axis.length_squared() > 0.000001:
			return resolved_axis.normalized()
	return Vector3.RIGHT

func _build_valid_test_wip(wip_id: StringName, grip_style_mode: StringName) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = wip_id
	wip.forge_project_name = String(wip_id)
	wip.creator_id = &"verify"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.grip_style_mode = grip_style_mode
	var layers: Array[LayerAtom] = []
	for layer_index: int in range(TEST_GRIP_LAYER_START, TEST_GRIP_LAYER_START + TEST_GRIP_SLICE_COUNT):
		var layer := LayerAtom.new()
		layer.layer_index = layer_index
		layer.cells = _build_handle_cells(layer_index)
		layers.append(layer)
	wip.layers = layers
	return wip

func _build_handle_cells(layer_index: int) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	for x in range(20, 23):
		for y in range(10, 13):
			var cell: CellAtom = CellAtom.new()
			cell.grid_position = Vector3i(x, y, layer_index)
			cell.layer_index = layer_index
			cell.material_variant_id = &"mat_wood_gray"
			cells.append(cell)
	return cells
