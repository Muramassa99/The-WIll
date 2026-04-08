extends SceneTree

const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const ForgeServiceScript = preload("res://services/forge_service.gd")
const TestPrintMeshBuilderScript = preload("res://runtime/forge/test_print_mesh_builder.gd")
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const LayerAtomScript = preload("res://core/atoms/layer_atom.gd")
const CellAtomScript = preload("res://core/atoms/cell_atom.gd")

func _init() -> void:
	var controller: ForgeGridController = ForgeGridControllerScript.new()
	controller.configure_grid(Vector3i(32, 16, 8))
	var forge_service: ForgeService = controller.get_forge_service()
	var test_print_mesh_builder: TestPrintMeshBuilder = TestPrintMeshBuilderScript.new()
	var lines: PackedStringArray = []

	var wood_material: BaseMaterialDef = load("res://core/defs/materials/base/wood.tres") as BaseMaterialDef
	var iron_material: BaseMaterialDef = load("res://core/defs/materials/base/iron.tres") as BaseMaterialDef
	var gray_tier: TierDef = load("res://core/defs/materials/tiers/tier_gray.tres") as TierDef
	var wood_raw_drop: RawDropDef = load("res://core/defs/materials/raw_drops/wood_raw_drop.tres") as RawDropDef
	var iron_raw_drop: RawDropDef = load("res://core/defs/materials/raw_drops/iron_raw_drop.tres") as RawDropDef
	var wood_process_rule: ProcessRuleDef = load("res://core/defs/materials/process_rules/wood_gray_process_rule.tres") as ProcessRuleDef
	var iron_process_rule: ProcessRuleDef = load("res://core/defs/materials/process_rules/iron_gray_process_rule.tres") as ProcessRuleDef

	var material_lookup: Dictionary = controller.build_default_material_lookup()
	lines.append("grid_configurable=%s" % str(controller.grid_size == Vector3i(32, 16, 8)))
	lines.append("material_lookup_has_wood_base=%s" % str(material_lookup.has(&"mat_wood_base")))
	lines.append("material_lookup_has_iron_base=%s" % str(material_lookup.has(&"mat_iron_base")))
	lines.append("material_lookup_has_wood_gray=%s" % str(material_lookup.has(&"mat_wood_gray")))
	lines.append("material_lookup_has_iron_gray=%s" % str(material_lookup.has(&"mat_iron_gray")))
	lines.append("tier_gray_loaded=%s" % str(gray_tier != null and gray_tier.tier_id == &"gray"))
	lines.append("raw_drop_paths_loaded=%s" % str(
		wood_raw_drop != null
		and iron_raw_drop != null
		and wood_raw_drop.drop_id == &"drop_wood_raw_gray"
		and iron_raw_drop.drop_id == &"drop_iron_raw_gray"
		and wood_raw_drop.base_material_id == &"mat_wood_base"
		and iron_raw_drop.base_material_id == &"mat_iron_base"
		and wood_raw_drop.default_tier_id == &"gray"
		and iron_raw_drop.default_tier_id == &"gray"
	))

	var wood_variant: MaterialVariantDef = forge_service.build_material_variant(wood_material, gray_tier)
	var iron_variant: MaterialVariantDef = forge_service.build_material_variant(iron_material, gray_tier)
	var wood_stack: ForgeMaterialStack = forge_service.build_material_stack(wood_process_rule, wood_variant)
	var iron_stack: ForgeMaterialStack = forge_service.build_material_stack(iron_process_rule, iron_variant)
	lines.append("wood_variant_id=%s" % String(wood_variant.variant_id))
	lines.append("iron_variant_id=%s" % String(iron_variant.variant_id))
	lines.append("wood_stack_quantity=%d" % wood_stack.quantity)
	lines.append("iron_stack_quantity=%d" % iron_stack.quantity)
	lines.append("wood_stack_output_matches_rule=%s" % str(wood_process_rule.output_material_variant_id == wood_variant.variant_id))
	lines.append("iron_stack_output_matches_rule=%s" % str(iron_process_rule.output_material_variant_id == iron_variant.variant_id))

	var iron_rectangle_wip: CraftedItemWIP = _build_box_wip(&"mochi_iron_rect", &"mat_iron_gray", Vector3i(4, 5, 1))
	var iron_rectangle_profile: BakedProfile = forge_service.bake_wip(iron_rectangle_wip, material_lookup)
	lines.append("iron_4x5x1_total_mass=%s" % String.num(iron_rectangle_profile.total_mass))
	lines.append("iron_4x5x1_validation=%s" % iron_rectangle_profile.validation_error)
	lines.append("iron_4x5x1_primary_grip_valid=%s" % str(iron_rectangle_profile.primary_grip_valid))
	lines.append("iron_4x5x1_snapshot_saved=%s" % str(
		iron_rectangle_wip.latest_baked_profile_snapshot != null
		and iron_rectangle_wip.latest_baked_profile_snapshot.profile_id == iron_rectangle_profile.profile_id
	))

	var disconnected_wip: CraftedItemWIP = _build_custom_wip(
		&"mochi_disconnected",
		[
			Vector3i(0, 0, 0),
			Vector3i(2, 0, 0),
		],
		&"mat_iron_gray"
	)
	var disconnected_profile: BakedProfile = forge_service.bake_wip(disconnected_wip, material_lookup)
	lines.append("disconnected_validation=%s" % disconnected_profile.validation_error)

	var wood_capability_wip: CraftedItemWIP = _build_box_wip(&"mochi_wood_caps", &"mat_wood_gray", Vector3i(12, 3, 2))
	var iron_capability_wip: CraftedItemWIP = _build_box_wip(&"mochi_iron_caps", &"mat_iron_gray", Vector3i(12, 3, 2))
	var wood_profile: BakedProfile = forge_service.bake_wip(wood_capability_wip, material_lookup)
	var iron_profile: BakedProfile = forge_service.bake_wip(iron_capability_wip, material_lookup)
	lines.append("wood_cap_flex_gt_iron=%s" % str(
		float(wood_profile.capability_scores.get(&"cap_flex", 0.0))
		> float(iron_profile.capability_scores.get(&"cap_flex", 0.0))
	))
	lines.append("iron_cap_edge_gt_wood=%s" % str(
		float(iron_profile.capability_scores.get(&"cap_edge", 0.0))
		> float(wood_profile.capability_scores.get(&"cap_edge", 0.0))
	))

	var two_cell_mesh: ArrayMesh = test_print_mesh_builder.build_mesh(
		_build_cells_from_positions([Vector3i(0, 0, 0), Vector3i(1, 0, 0)], &"mat_iron_gray"),
		material_lookup
	)
	lines.append("test_print_mesh_surface_count=%d" % two_cell_mesh.get_surface_count())
	lines.append("test_print_mesh_aabb_size=%s" % str(two_cell_mesh.get_aabb().size))

	var save_path: String = "res://tools/test_mochi_wip_library_state.tres"
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create(save_path)
	library_state.saved_wips.clear()
	library_state.selected_wip_id = StringName()
	var save_source_wip: CraftedItemWIP = _build_custom_wip(
		&"draft_mochi_save",
		[Vector3i(0, 0, 0)],
		&"mat_wood_gray"
	)
	save_source_wip.forge_project_name = "Mochi Save Test"
	var saved_wip: CraftedItemWIP = library_state.save_wip(save_source_wip)
	var reloaded_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create(save_path)
	var reloaded_wip: CraftedItemWIP = reloaded_state.get_saved_wip_clone(reloaded_state.selected_wip_id)
	controller.load_player_saved_wip(reloaded_wip)
	controller.set_material_at(Vector3i(1, 0, 0), &"mat_wood_gray")
	lines.append("save_reload_continue_edit=%s" % str(_count_cells(controller.active_wip) == 2))
	lines.append("snapshot_cleared_after_edit=%s" % str(
		controller.active_wip != null and controller.active_wip.latest_baked_profile_snapshot == null
	))

	var output_path: String = "c:/WORKSPACE/mochi_verify_results.txt"
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	controller.free()
	quit()

func _build_box_wip(wip_id: StringName, material_variant_id: StringName, footprint_size: Vector3i) -> CraftedItemWIP:
	var positions: Array[Vector3i] = []
	for z in range(footprint_size.z):
		for y in range(footprint_size.y):
			for x in range(footprint_size.x):
				positions.append(Vector3i(x, y, z))
	return _build_custom_wip(wip_id, positions, material_variant_id)

func _build_custom_wip(
		wip_id: StringName,
		positions: Array[Vector3i],
		material_variant_id: StringName
	) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = wip_id
	wip.creator_id = &"mochi_verify"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.layers = _build_layers_from_cells(_build_cells_from_positions(positions, material_variant_id))
	return wip

func _build_layers_from_cells(cells: Array[CellAtom]) -> Array[LayerAtom]:
	var layer_map: Dictionary = {}
	for cell: CellAtom in cells:
		if cell == null:
			continue
		if not layer_map.has(cell.layer_index):
			var layer: LayerAtom = LayerAtomScript.new()
			layer.layer_index = cell.layer_index
			layer.cells = []
			layer_map[cell.layer_index] = layer
		var target_layer: LayerAtom = layer_map[cell.layer_index]
		target_layer.cells.append(cell)

	var sorted_indices: Array = layer_map.keys()
	sorted_indices.sort()
	var layers: Array[LayerAtom] = []
	for layer_index in sorted_indices:
		layers.append(layer_map[layer_index])
	return layers

func _build_cells_from_positions(positions: Array[Vector3i], material_variant_id: StringName) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	for position: Vector3i in positions:
		var cell: CellAtom = CellAtomScript.new()
		cell.grid_position = position
		cell.layer_index = position.z
		cell.material_variant_id = material_variant_id
		cells.append(cell)
	return cells

func _count_cells(wip: CraftedItemWIP) -> int:
	if wip == null:
		return 0
	var cell_count: int = 0
	for layer: LayerAtom in wip.layers:
		if layer == null:
			continue
		cell_count += layer.cells.size()
	return cell_count
