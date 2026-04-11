extends SceneTree

const PlayerBodyInventoryStateScript = preload("res://core/models/player_body_inventory_state.gd")
const PlayerPersonalStorageStateScript = preload("res://core/models/player_personal_storage_state.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_hand_mount_orientation_results.txt"
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
	body_state.save_file_path = "%s/verify_mount_body_inventory_state.tres" % TEMP_STATE_DIR
	var personal_state = PlayerPersonalStorageStateScript.new()
	personal_state.save_file_path = "%s/verify_mount_personal_storage_state.tres" % TEMP_STATE_DIR
	var equipment_state = PlayerEquipmentStateScript.new()
	equipment_state.save_file_path = "%s/verify_mount_player_equipment_state.tres" % TEMP_STATE_DIR
	var wip_library = PlayerForgeWipLibraryStateScript.new()
	wip_library.save_file_path = "%s/verify_mount_player_wip_library_state.tres" % TEMP_STATE_DIR

	player.body_inventory_state = body_state
	player.personal_storage_state = personal_state
	player.equipment_state = equipment_state
	player.forge_wip_library_state = wip_library
	player._sync_equipped_test_meshes()

	var right_normal_wip: CraftedItemWIP = wip_library.save_wip(_build_valid_test_wip(&"verify_mount_right_normal", CraftedItemWIP.GRIP_NORMAL))
	var right_reverse_wip: CraftedItemWIP = wip_library.save_wip(_build_valid_test_wip(&"verify_mount_right_reverse", CraftedItemWIP.GRIP_REVERSE))
	var left_normal_wip: CraftedItemWIP = wip_library.save_wip(_build_valid_test_wip(&"verify_mount_left_normal", CraftedItemWIP.GRIP_NORMAL))
	var left_reverse_wip: CraftedItemWIP = wip_library.save_wip(_build_valid_test_wip(&"verify_mount_left_reverse", CraftedItemWIP.GRIP_REVERSE))

	var right_normal: Dictionary = await _equip_and_capture(player, right_normal_wip.wip_id, &"hand_right")
	var right_reverse: Dictionary = await _equip_and_capture(player, right_reverse_wip.wip_id, &"hand_right")
	var left_normal: Dictionary = await _equip_and_capture(player, left_normal_wip.wip_id, &"hand_left")
	var left_reverse: Dictionary = await _equip_and_capture(player, left_reverse_wip.wip_id, &"hand_left")

	var lines: PackedStringArray = []
	lines.append("right_normal_exists=%s" % str(right_normal.get("exists", false)))
	lines.append("right_reverse_exists=%s" % str(right_reverse.get("exists", false)))
	lines.append("left_normal_exists=%s" % str(left_normal.get("exists", false)))
	lines.append("left_reverse_exists=%s" % str(left_reverse.get("exists", false)))
	lines.append("right_normal_local_basis_x=%s" % str(right_normal.get("local_x", Vector3.ZERO)))
	lines.append("right_reverse_local_basis_x=%s" % str(right_reverse.get("local_x", Vector3.ZERO)))
	lines.append("left_normal_local_basis_x=%s" % str(left_normal.get("local_x", Vector3.ZERO)))
	lines.append("left_reverse_local_basis_x=%s" % str(left_reverse.get("local_x", Vector3.ZERO)))
	lines.append("right_normal_local_basis_y=%s" % str(right_normal.get("local_y", Vector3.ZERO)))
	lines.append("left_normal_local_basis_y=%s" % str(left_normal.get("local_y", Vector3.ZERO)))
	lines.append("right_reverse_changes_local_forward=%s" % str(_vector_dot(right_normal, right_reverse, "local_x") < -0.8))
	lines.append("left_reverse_changes_local_forward=%s" % str(_vector_dot(left_normal, left_reverse, "local_x") < -0.8))
	lines.append("left_normal_matches_right_base_roll=%s" % str(_vector_dot(right_normal, left_normal, "local_y") > 0.8))
	lines.append("left_normal_has_left_hand_y_flip=%s" % str(_vector_dot(right_normal, left_normal, "local_x") < -0.8))
	lines.append("right_reverse_has_secondary_guide=%s" % str(bool(right_reverse.get("has_secondary_guide", false))))
	lines.append("left_reverse_has_secondary_guide=%s" % str(bool(left_reverse.get("has_secondary_guide", false))))

	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _equip_and_capture(player: PlayerController3D, saved_wip_id: StringName, slot_id: StringName) -> Dictionary:
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
			"local_x": Vector3.ZERO,
			"has_secondary_guide": false
		}
	return {
		"exists": true,
		"local_x": held_item.transform.basis.x.normalized(),
		"local_y": held_item.transform.basis.y.normalized(),
		"has_secondary_guide": held_item.get_node_or_null("SecondaryGripGuide") != null
	}

func _vector_dot(a: Dictionary, b: Dictionary, key: String) -> float:
	if not bool(a.get("exists", false)) or not bool(b.get("exists", false)):
		return -2.0
	return (a.get(key, Vector3.ZERO) as Vector3).dot(b.get(key, Vector3.ZERO) as Vector3)

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
	for x in range(20, 48):
		for y in range(10, 13):
			var cell: CellAtom = CellAtom.new()
			cell.grid_position = Vector3i(x, y, layer_index)
			cell.layer_index = layer_index
			cell.material_variant_id = &"mat_wood_gray"
			cells.append(cell)
	return cells
