extends SceneTree

const PlayerBodyInventoryStateScript = preload("res://core/models/player_body_inventory_state.gd")
const PlayerPersonalStorageStateScript = preload("res://core/models/player_personal_storage_state.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const StoredItemInstanceScript = preload("res://core/models/stored_item_instance.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_inventory_slice_results.txt"
const TEMP_STATE_DIR := "C:/WORKSPACE/test_artifacts"

func _initialize() -> void:
	var results: PackedStringArray = []
	var player_scene: PackedScene = load("res://scenes/player/player_character.tscn") as PackedScene
	var world_scene: PackedScene = load("res://node_3d.tscn") as PackedScene
	var player_root: Node = player_scene.instantiate()
	root.add_child(player_root)
	await process_frame

	var player = player_root as PlayerController3D
	var overlay = player_root.get_node("PlayerInventoryOverlay")
	var body_state = PlayerBodyInventoryStateScript.new()
	body_state.save_file_path = "%s/verify_body_inventory_state.tres" % TEMP_STATE_DIR
	var personal_state = PlayerPersonalStorageStateScript.new()
	personal_state.save_file_path = "%s/verify_personal_storage_state.tres" % TEMP_STATE_DIR
	var equipment_state = PlayerEquipmentStateScript.new()
	equipment_state.save_file_path = "%s/verify_player_equipment_state.tres" % TEMP_STATE_DIR
	var wip_library = PlayerForgeWipLibraryStateScript.new()
	wip_library.save_file_path = "%s/verify_player_wip_library_state.tres" % TEMP_STATE_DIR
	var forge_inventory = PlayerForgeInventoryState.new()

	player.body_inventory_state = body_state
	player.personal_storage_state = personal_state
	player.equipment_state = equipment_state
	player.forge_wip_library_state = wip_library
	player.forge_inventory_state = forge_inventory

	var stored_item = StoredItemInstanceScript.new()
	stored_item.item_instance_id = &"verify_body_item"
	stored_item.item_kind = &"raw_drop"
	stored_item.raw_drop_id = &"drop_wood_raw_gray"
	stored_item.display_name = "Wood Raw (Gray)"
	stored_item.stack_count = 4
	stored_item.is_disassemblable = true
	body_state.add_item(stored_item)

	forge_inventory.set_quantity(&"mat_wood_gray", 120)
	forge_inventory.set_quantity(&"mat_iron_gray", 90)

	var saved_wip: CraftedItemWIP = wip_library.save_wip(_build_valid_test_wip())
	player._sync_equipped_test_meshes()

	overlay.open_page_for(player, &"inventory", "Verify Inventory")
	overlay.set_selected_body_item_id(stored_item.item_instance_id)
	overlay._on_move_to_storage_pressed()

	var moved_to_storage: bool = personal_state.get_stored_items().size() == 1 and body_state.get_owned_items().is_empty()

	overlay.open_page_for(player, &"storage", "Verify Storage")
	var stored_transfer_id: StringName = personal_state.get_stored_items()[0].item_instance_id if not personal_state.get_stored_items().is_empty() else StringName()
	overlay.set_selected_storage_item_id(stored_transfer_id)
	overlay._on_move_to_inventory_pressed()

	var moved_back_to_inventory: bool = body_state.get_owned_items().size() == 1 and personal_state.get_stored_items().is_empty()

	var preview_status: Dictionary = player.preview_saved_wip_test_status(saved_wip.wip_id)
	var equip_result: Dictionary = player.equip_saved_wip_to_hand(saved_wip.wip_id, &"hand_right")
	var right_anchor: Node3D = player.humanoid_rig.call("get_right_hand_item_anchor") as Node3D if player.humanoid_rig != null else null
	var right_hand_child_count: int = right_anchor.get_child_count() if right_anchor != null else 0
	var hand_entry = equipment_state.get_equipped_slot(&"hand_right")

	var world_root: Node = world_scene.instantiate()
	root.add_child(world_root)
	await process_frame
	var storage_box_exists: bool = world_root.get_node_or_null("StorageBox") != null

	results.append("player_loaded=%s" % str(player != null))
	results.append("inventory_overlay_loaded=%s" % str(overlay != null))
	results.append("humanoid_height_meters=%.2f" % player.get_humanoid_standing_height_meters())
	results.append("humanoid_height_is_two_meters=%s" % str(is_equal_approx(player.get_humanoid_standing_height_meters(), 2.0)))
	results.append("moved_to_storage=%s" % str(moved_to_storage))
	results.append("moved_back_to_inventory=%s" % str(moved_back_to_inventory))
	results.append("saved_wip_id=%s" % String(saved_wip.wip_id))
	results.append("preview_valid=%s" % str(bool(preview_status.get("valid", false))))
	results.append("preview_message=%s" % String(preview_status.get("message", "")))
	results.append("equip_success=%s" % str(bool(equip_result.get("success", false))))
	results.append("equip_message=%s" % String(equip_result.get("message", "")))
	results.append("right_hand_entry_is_forge_test=%s" % str(hand_entry != null and hand_entry.is_forge_test_wip()))
	results.append("right_hand_visual_child_count=%d" % right_hand_child_count)
	results.append("storage_box_exists_in_world=%s" % str(storage_box_exists))

	var result_directory: String = RESULT_FILE_PATH.get_base_dir()
	DirAccess.make_dir_recursive_absolute(result_directory)
	var result_file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	result_file.store_string("\n".join(results))
	result_file.close()
	quit()

func _build_valid_test_wip() -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = &"verify_test_wip"
	wip.forge_project_name = "Verify Sword"
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
	for x in range(20, 32):
		for y in range(10, 13):
			var cell: CellAtom = CellAtom.new()
			cell.grid_position = Vector3i(x, y, layer_index)
			cell.layer_index = layer_index
			cell.material_variant_id = &"mat_wood_gray"
			cells.append(cell)
	return cells
