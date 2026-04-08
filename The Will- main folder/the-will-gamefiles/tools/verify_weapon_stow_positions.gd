extends SceneTree

const PlayerBodyInventoryStateScript = preload("res://core/models/player_body_inventory_state.gd")
const PlayerPersonalStorageStateScript = preload("res://core/models/player_personal_storage_state.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_weapon_stow_results.txt"
const TEMP_STATE_DIR := "C:/WORKSPACE/test_artifacts"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var player_scene: PackedScene = load("res://scenes/player/player_character.tscn") as PackedScene
	var player_root: Node = player_scene.instantiate()
	root.add_child(player_root)
	await process_frame
	await physics_frame
	await process_frame

	var player := player_root as PlayerController3D
	var body_state = PlayerBodyInventoryStateScript.new()
	body_state.save_file_path = "%s/verify_stow_body_inventory_state.tres" % TEMP_STATE_DIR
	var personal_state = PlayerPersonalStorageStateScript.new()
	personal_state.save_file_path = "%s/verify_stow_personal_storage_state.tres" % TEMP_STATE_DIR
	var equipment_state = PlayerEquipmentStateScript.new()
	equipment_state.save_file_path = "%s/verify_stow_player_equipment_state.tres" % TEMP_STATE_DIR
	var wip_library = PlayerForgeWipLibraryStateScript.new()
	wip_library.save_file_path = "%s/verify_stow_player_wip_library_state.tres" % TEMP_STATE_DIR

	player.body_inventory_state = body_state
	player.personal_storage_state = personal_state
	player.equipment_state = equipment_state
	player.forge_wip_library_state = wip_library
	player._sync_equipped_test_meshes()
	var rig: PlayerHumanoidRig = player.humanoid_rig as PlayerHumanoidRig if player != null else null

	var shoulder_wip: CraftedItemWIP = wip_library.save_wip(_build_stow_test_wip(&"verify_shoulder_wip", CraftedItemWIP.STOW_SHOULDER_HANGING))
	var side_hip_wip: CraftedItemWIP = wip_library.save_wip(_build_stow_test_wip(&"verify_side_hip_wip", CraftedItemWIP.STOW_SIDE_HIP))
	var lower_back_wip: CraftedItemWIP = wip_library.save_wip(_build_stow_test_wip(&"verify_lower_back_wip", CraftedItemWIP.STOW_LOWER_BACK))

	var shoulder_right_valid: bool = await _equip_and_stow(player, shoulder_wip.wip_id, &"hand_right")
	var shoulder_right_anchor: Node3D = rig.get_weapon_stow_anchor(CraftedItemWIP.STOW_SHOULDER_HANGING, &"hand_right") if rig != null else null
	var shoulder_right_node: Node3D = player.held_item_nodes.get(&"hand_right") as Node3D
	var shoulder_right_parent_matches: bool = shoulder_right_node != null and shoulder_right_node.get_parent() == shoulder_right_anchor

	var side_left_valid: bool = await _equip_and_stow(player, side_hip_wip.wip_id, &"hand_left")
	var side_left_anchor: Node3D = rig.get_weapon_stow_anchor(CraftedItemWIP.STOW_SIDE_HIP, &"hand_left") if rig != null else null
	var side_left_node: Node3D = player.held_item_nodes.get(&"hand_left") as Node3D
	var side_left_parent_matches: bool = side_left_node != null and side_left_node.get_parent() == side_left_anchor

	var lower_right_valid: bool = await _equip_and_stow(player, lower_back_wip.wip_id, &"hand_right")
	var lower_right_anchor: Node3D = rig.get_weapon_stow_anchor(CraftedItemWIP.STOW_LOWER_BACK, &"hand_right") if rig != null else null
	var lower_right_node: Node3D = player.held_item_nodes.get(&"hand_right") as Node3D
	var lower_right_parent_matches: bool = lower_right_node != null and lower_right_node.get_parent() == lower_right_anchor
	var bounds_area: Area3D = lower_right_node.get_node_or_null("WeaponBoundsArea") as Area3D if lower_right_node != null else null
	var bounds_shape: CollisionShape3D = bounds_area.get_node_or_null("WeaponBoundsShape") as CollisionShape3D if bounds_area != null else null
	var bounds_size: Vector3 = (bounds_shape.shape as BoxShape3D).size if bounds_shape != null and bounds_shape.shape is BoxShape3D else Vector3.ZERO

	var lines: PackedStringArray = []
	lines.append("shoulder_right_preview_valid=%s" % str(shoulder_right_valid))
	lines.append("shoulder_right_parent_matches=%s" % str(shoulder_right_parent_matches))
	lines.append("side_left_preview_valid=%s" % str(side_left_valid))
	lines.append("side_left_parent_matches=%s" % str(side_left_parent_matches))
	lines.append("lower_right_preview_valid=%s" % str(lower_right_valid))
	lines.append("lower_right_parent_matches=%s" % str(lower_right_parent_matches))
	lines.append("weapon_bounds_area_exists=%s" % str(bounds_area != null))
	lines.append("weapon_bounds_shape_exists=%s" % str(bounds_shape != null))
	lines.append("weapon_bounds_size=%s" % str(bounds_size))
	lines.append("weapon_bounds_has_padding=%s" % str(bounds_size.x > 0.0 and bounds_size.y > 0.0 and bounds_size.z > 0.0))
	lines.append("weapons_drawn_after_stow=%s" % str(player.weapons_drawn))

	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _equip_and_stow(player: PlayerController3D, saved_wip_id: StringName, slot_id: StringName) -> bool:
	player.clear_equipment_slot(&"hand_right")
	player.clear_equipment_slot(&"hand_left")
	player.set_weapons_drawn(true)
	var equip_result: Dictionary = player.equip_saved_wip_to_hand(saved_wip_id, slot_id)
	player.set_weapons_drawn(false)
	for _i in range(6):
		await physics_frame
		await process_frame
	return bool(equip_result.get("success", false))

func _build_stow_test_wip(wip_id: StringName, stow_mode: StringName) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = wip_id
	wip.forge_project_name = "%s Test" % String(wip_id)
	wip.creator_id = &"verify"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.stow_position_mode = stow_mode
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
	for x in range(20, 36):
		for y in range(10, 13):
			var cell: CellAtom = CellAtom.new()
			cell.grid_position = Vector3i(x, y, layer_index)
			cell.layer_index = layer_index
			cell.material_variant_id = &"mat_wood_gray"
			cells.append(cell)
	return cells
