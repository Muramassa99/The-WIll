extends SceneTree

const PlayerBodyInventoryStateScript = preload("res://core/models/player_body_inventory_state.gd")
const PlayerPersonalStorageStateScript = preload("res://core/models/player_personal_storage_state.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const Fixture = preload("res://tools/forge_v2_small_handle_fixture.gd")
const MaterialResolver = preload("res://core/resolvers/material_runtime_resolver.gd")
const RESULT_FILE_PATH := "C:/WORKSPACE/player_held_item_materials_results.txt"
const TEMP_STATE_DIR := "user://verification/held_item_materials"
var _failures := PackedStringArray()
var _lines := PackedStringArray()


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var player_scene := load("res://scenes/player/player_character.tscn") as PackedScene
	var player_root := player_scene.instantiate()
	root.add_child(player_root)
	await process_frame
	await process_frame
	var player := player_root as PlayerController3D
	var body_state := PlayerBodyInventoryStateScript.new()
	body_state.save_file_path = TEMP_STATE_DIR.path_join("body.tres")
	var personal_state := PlayerPersonalStorageStateScript.new()
	personal_state.save_file_path = TEMP_STATE_DIR.path_join("personal.tres")
	var equipment_state := PlayerEquipmentStateScript.new()
	equipment_state.save_file_path = TEMP_STATE_DIR.path_join("equipment.tres")
	var library := PlayerForgeWipLibraryStateScript.new()
	library.save_file_path = TEMP_STATE_DIR.path_join("library.tres")
	player.body_inventory_state = body_state
	player.personal_storage_state = personal_state
	player.equipment_state = equipment_state
	player.forge_wip_library_state = library
	player._sync_equipped_test_meshes()
	var source := _build_prepared_color_wip()
	if not _expect(source != null, "V2 fixture exports"):
		_finish()
		return
	var saved: CraftedItemWIP = library.save_wip(source)
	if not _expect(saved != null, "V2 colored mesh saves"):
		_finish()
		return
	var runtime_wip := saved.duplicate(true) as CraftedItemWIP
	var prepared_before: Resource = runtime_wip.stage2_item_state
	var test_print: TestPrintInstance = player.forge_service.build_test_print_from_wip(
		runtime_wip, Fixture.material_lookup(), {}, {}, {}, true
	)
	_expect(runtime_wip.stage2_item_state == prepared_before, "runtime uses existing prepared state without rebuilding it")
	_expect(test_print != null and test_print.visual_mesh_source == &"editable_mesh",
		"runtime mesh authority is prepared editable mesh")
	var mesh: ArrayMesh = player.held_item_mesh_builder.build_mesh_from_test_print(test_print)
	_expect(_unique_colors(mesh).size() == 2, "prepared wood and iron colors survive TestPrint creation")
	var cached_node: Node3D = player.equipped_item_presenter.build_equipped_item_node(
		saved.duplicate(true) as CraftedItemWIP, &"hand_right", player.forge_service,
		Fixture.material_lookup(), player.held_item_mesh_builder, player.humanoid_rig,
		PlayerController3D.DEFAULT_FORGE_RULES_RESOURCE,
		PlayerController3D.DEFAULT_FORGE_VIEW_TUNING_RESOURCE, true
	)
	var cached_visual := _resolve_first_child_mesh_instance(cached_node)
	_expect(cached_visual != null and _unique_colors(cached_visual.mesh as ArrayMesh) == _unique_colors(mesh),
		"cached equipped-node construction preserves prepared colors")
	if cached_node != null:
		cached_node.free()
	var equip: Dictionary = player.equip_saved_wip_to_hand(saved.wip_id, &"hand_right")
	await process_frame
	await process_frame
	var held := player.held_item_nodes.get(&"hand_right") as Node3D
	var visual := _resolve_first_child_mesh_instance(held)
	var material := visual.material_override as StandardMaterial3D if visual != null else null
	var held_mesh := visual.mesh as ArrayMesh if visual != null else null
	_expect(bool(equip.get("success", false)), "V2 saved weapon equips")
	_expect(visual != null, "equipped visual exists")
	_expect(material != null and material.vertex_color_use_as_albedo, "equipped material uses saved vertex colors")
	_expect(material != null and material.cull_mode == BaseMaterial3D.CULL_DISABLED, "equipped material remains double sided")
	# The Forge test-equip action deliberately rebakes a private clone. The current
	# V2 adapter initializes its output colors; it does not transport edited paint.
	# Check that branch against its refreshed export, without treating it as cache reuse.
	var refreshed: TestPrintInstance = player.forge_service.build_test_print_from_wip(
		saved.duplicate(true) as CraftedItemWIP, Fixture.material_lookup()
	)
	var refreshed_mesh: ArrayMesh = player.held_item_mesh_builder.build_mesh_from_test_print(refreshed)
	_expect(held_mesh != null and _unique_colors(held_mesh) == _unique_colors(refreshed_mesh),
		"Forge test equip matches its deliberate V2 export refresh")
	var unchanged: TestPrintInstance = player.forge_service.build_test_print_from_wip(
		library.get_saved_wip_clone(saved.wip_id), Fixture.material_lookup(), {}, {}, {}, true
	)
	_expect(_unique_colors(player.held_item_mesh_builder.build_mesh_from_test_print(unchanged)) == _unique_colors(mesh),
		"Forge test equip leaves saved prepared colors unchanged")
	var missing := saved.duplicate(true) as CraftedItemWIP
	missing.stage2_item_state = null
	var missing_print: TestPrintInstance = player.forge_service.build_test_print_from_wip(missing)
	_expect(missing.stage2_item_state == null, "missing prepared mesh is never regenerated from retired cell data")
	_expect(player.held_item_mesh_builder.build_mesh_from_test_print(missing_print).get_surface_count() == 0,
		"missing prepared mesh has no fallback visual")
	player_root.queue_free()
	await process_frame
	_finish()


func _build_prepared_color_wip() -> CraftedItemWIP:
	# This verifies saved editable-color transport, not retired voxel color reconstruction.
	# Material stat/occupancy ownership has its own V2 export verifier.
	var lookup := Fixture.material_lookup()
	var wip := Fixture.build(&"mat_wood_gray", lookup)
	if wip == null:
		return null
	wip.wip_id = &"verify_player_held_item_materials"
	wip.forge_project_name = "Verify V2 Prepared Material Colors"
	var editable := wip.stage2_item_state.get("current_editable_mesh_state") as Resource
	var arrays: Array = editable.get("surface_arrays") as Array
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var resolver := MaterialResolver.new()
	var wood := resolver.resolve_material_color(&"mat_wood_gray", lookup, Color.WHITE)
	var iron := resolver.resolve_material_color(&"mat_iron_gray", lookup, Color.WHITE)
	var colors := PackedColorArray()
	for vertex: Vector3 in vertices:
		colors.append(wood if vertex.x < 8.0 else iron)
	arrays[Mesh.ARRAY_COLOR] = colors
	editable.set("surface_arrays", arrays)
	return wip


func _unique_colors(mesh: ArrayMesh) -> Dictionary:
	var colors: Dictionary = {}
	if mesh == null:
		return colors
	for surface_index: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var values: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for color: Color in values:
			colors["%.4f|%.4f|%.4f|%.4f" % [color.r, color.g, color.b, color.a]] = true
	return colors


func _resolve_first_child_mesh_instance(parent: Node) -> MeshInstance3D:
	if parent != null:
		for child: Node in parent.get_children():
			if child is MeshInstance3D:
				return child as MeshInstance3D
	return null


func _expect(condition: bool, label: String) -> bool:
	_lines.append("%s=%s" % [label, condition])
	if not condition:
		_failures.append(label)
	return condition


func _finish() -> void:
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines))
	for failure: String in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
