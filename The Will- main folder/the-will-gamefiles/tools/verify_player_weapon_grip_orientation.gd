extends SceneTree

const PlayerBodyInventoryStateScript = preload("res://core/models/player_body_inventory_state.gd")
const PlayerPersonalStorageStateScript = preload("res://core/models/player_personal_storage_state.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_weapon_grip_orientation_results.txt"
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

	var right_normal_data: Dictionary = await _equip_and_measure(player, right_normal_wip.wip_id, &"hand_right")
	var right_reverse_data: Dictionary = await _equip_and_measure(player, right_reverse_wip.wip_id, &"hand_right")
	var left_normal_data: Dictionary = await _equip_and_measure(player, left_normal_wip.wip_id, &"hand_left")
	var left_reverse_data: Dictionary = await _equip_and_measure(player, left_reverse_wip.wip_id, &"hand_left")

	var lines: PackedStringArray = []
	lines.append("right_normal_exists=%s" % str(right_normal_data.get("exists", false)))
	lines.append("right_reverse_exists=%s" % str(right_reverse_data.get("exists", false)))
	lines.append("left_normal_exists=%s" % str(left_normal_data.get("exists", false)))
	lines.append("left_reverse_exists=%s" % str(left_reverse_data.get("exists", false)))
	lines.append("right_normal_forward_score=%s" % str(snappedf(float(right_normal_data.get("forward_score", -2.0)), 0.0001)))
	lines.append("right_reverse_forward_score=%s" % str(snappedf(float(right_reverse_data.get("forward_score", -2.0)), 0.0001)))
	lines.append("left_normal_forward_score=%s" % str(snappedf(float(left_normal_data.get("forward_score", -2.0)), 0.0001)))
	lines.append("left_reverse_forward_score=%s" % str(snappedf(float(left_reverse_data.get("forward_score", -2.0)), 0.0001)))
	lines.append("right_normal_up_score=%s" % str(snappedf(float(right_normal_data.get("up_score", -2.0)), 0.0001)))
	lines.append("right_reverse_up_score=%s" % str(snappedf(float(right_reverse_data.get("up_score", -2.0)), 0.0001)))
	lines.append("left_normal_up_score=%s" % str(snappedf(float(left_normal_data.get("up_score", -2.0)), 0.0001)))
	lines.append("left_reverse_up_score=%s" % str(snappedf(float(left_reverse_data.get("up_score", -2.0)), 0.0001)))
	lines.append("right_reverse_flips_forward=%s" % str(_vectors_dot(right_normal_data, right_reverse_data) < -0.8))
	lines.append("left_reverse_flips_forward=%s" % str(_vectors_dot(left_normal_data, left_reverse_data) < -0.8))
	lines.append("left_normal_matches_right_normal=%s" % str(_vectors_dot(right_normal_data, left_normal_data) > 0.8))
	lines.append("left_reverse_matches_right_reverse=%s" % str(_vectors_dot(right_reverse_data, left_reverse_data) > 0.8))
	lines.append("right_reverse_support_guide_absent=%s" % str(not bool(right_reverse_data.get("has_secondary_guide", true))))
	lines.append("left_reverse_support_guide_absent=%s" % str(not bool(left_reverse_data.get("has_secondary_guide", true))))

	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _equip_and_measure(player: PlayerController3D, saved_wip_id: StringName, slot_id: StringName) -> Dictionary:
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
			"forward_score": -2.0,
			"up_score": -2.0,
			"forward": Vector3.ZERO,
			"has_secondary_guide": false
		}
	var player_forward: Vector3 = -player.visual_root.global_basis.z.normalized()
	var forward_vector: Vector3 = held_item.global_basis.x.normalized()
	var up_vector: Vector3 = held_item.global_basis.y.normalized()
	return {
		"exists": true,
		"forward_score": forward_vector.dot(player_forward),
		"up_score": up_vector.dot(Vector3.UP),
		"forward": forward_vector,
		"has_secondary_guide": held_item.get_node_or_null("SecondaryGripGuide") != null
	}

func _vectors_dot(a: Dictionary, b: Dictionary) -> float:
	if not bool(a.get("exists", false)) or not bool(b.get("exists", false)):
		return -2.0
	return (a.get("forward", Vector3.ZERO) as Vector3).dot(b.get("forward", Vector3.ZERO) as Vector3)

func _build_valid_test_wip(wip_id: StringName, grip_style_mode: StringName) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = wip_id
	wip.forge_project_name = String(wip_id)
	wip.creator_id = &"verify"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.grip_style_mode = grip_style_mode
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
	for x in range(20, 32):
		for y in range(10, 13):
			var cell: CellAtom = CellAtom.new()
			cell.grid_position = Vector3i(x, y, layer_index)
			cell.layer_index = layer_index
			cell.material_variant_id = &"mat_wood_gray"
			cells.append(cell)
	return cells
