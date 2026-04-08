extends SceneTree

const PlayerBodyInventoryStateScript = preload("res://core/models/player_body_inventory_state.gd")
const PlayerPersonalStorageStateScript = preload("res://core/models/player_personal_storage_state.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_held_item_materials_results.txt"
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
	body_state.save_file_path = "%s/verify_materials_body_inventory_state.tres" % TEMP_STATE_DIR
	var personal_state = PlayerPersonalStorageStateScript.new()
	personal_state.save_file_path = "%s/verify_materials_personal_storage_state.tres" % TEMP_STATE_DIR
	var equipment_state = PlayerEquipmentStateScript.new()
	equipment_state.save_file_path = "%s/verify_materials_player_equipment_state.tres" % TEMP_STATE_DIR
	var wip_library = PlayerForgeWipLibraryStateScript.new()
	wip_library.save_file_path = "%s/verify_materials_player_wip_library_state.tres" % TEMP_STATE_DIR

	player.body_inventory_state = body_state
	player.personal_storage_state = personal_state
	player.equipment_state = equipment_state
	player.forge_wip_library_state = wip_library
	player._sync_equipped_test_meshes()

	var saved_wip: CraftedItemWIP = wip_library.save_wip(_build_mixed_material_wip())
	var equip_result: Dictionary = player.equip_saved_wip_to_hand(saved_wip.wip_id, &"hand_right")
	await process_frame
	await process_frame

	var held_item: Node3D = player.held_item_nodes.get(&"hand_right") as Node3D
	var mesh_instance: MeshInstance3D = _resolve_first_child_mesh_instance(held_item)
	var override_material: StandardMaterial3D = mesh_instance.material_override as StandardMaterial3D if mesh_instance != null else null
	var mesh: ArrayMesh = mesh_instance.mesh as ArrayMesh if mesh_instance != null else null
	var unique_colors: Dictionary = {}
	var vertex_color_count: int = 0
	if mesh != null and mesh.get_surface_count() > 0:
		var surface_arrays: Array = mesh.surface_get_arrays(0)
		var colors: PackedColorArray = surface_arrays[Mesh.ARRAY_COLOR]
		vertex_color_count = colors.size()
		for color: Color in colors:
			unique_colors[_color_key(color)] = true

	var lines: PackedStringArray = []
	lines.append("equip_success=%s" % str(bool(equip_result.get("success", false))))
	lines.append("held_item_exists=%s" % str(held_item != null))
	lines.append("mesh_instance_exists=%s" % str(mesh_instance != null))
	lines.append("material_override_exists=%s" % str(override_material != null))
	lines.append("material_override_uses_vertex_color=%s" % str(override_material != null and override_material.vertex_color_use_as_albedo))
	lines.append("material_override_cull_disabled=%s" % str(override_material != null and override_material.cull_mode == BaseMaterial3D.CULL_DISABLED))
	lines.append("vertex_color_count=%d" % vertex_color_count)
	lines.append("unique_vertex_color_count=%d" % unique_colors.size())
	lines.append("multiple_visible_material_colors=%s" % str(unique_colors.size() > 1))

	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _build_mixed_material_wip() -> CraftedItemWIP:
	var wip := CraftedItemWIP.new()
	wip.wip_id = &"verify_player_held_item_materials"
	wip.forge_project_name = "Verify Player Held Item Materials"
	wip.creator_id = &"verify"
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"

	var layer_map: Dictionary = {}
	for x: int in range(20, 44):
		for y: int in range(10, 13):
			for z: int in range(20, 22):
				_add_cell(layer_map, Vector3i(x, y, z), &"mat_wood_gray")

	for x: int in range(44, 52):
		for y: int in range(8, 15):
			for z: int in range(19, 23):
				_add_cell(layer_map, Vector3i(x, y, z), &"mat_iron_gray")

	var ordered_layers: Array = layer_map.keys()
	ordered_layers.sort()
	for layer_index_value in ordered_layers:
		wip.layers.append(layer_map[layer_index_value])
	return wip

func _add_cell(layer_map: Dictionary, grid_position: Vector3i, material_variant_id: StringName) -> void:
	if not layer_map.has(grid_position.z):
		var layer := LayerAtom.new()
		layer.layer_index = grid_position.z
		layer.cells = []
		layer_map[grid_position.z] = layer
	var cell := CellAtom.new()
	cell.grid_position = grid_position
	cell.layer_index = grid_position.z
	cell.material_variant_id = material_variant_id
	var target_layer: LayerAtom = layer_map[grid_position.z]
	target_layer.cells.append(cell)

func _resolve_first_child_mesh_instance(parent_node: Node) -> MeshInstance3D:
	if parent_node == null:
		return null
	for child_node: Node in parent_node.get_children():
		if child_node is MeshInstance3D:
			return child_node as MeshInstance3D
	return null

func _color_key(color: Color) -> String:
	return "%0.4f|%0.4f|%0.4f|%0.4f" % [color.r, color.g, color.b, color.a]
