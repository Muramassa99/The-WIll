extends Node
class_name ForgeGridController

signal active_wip_changed(wip)
signal active_test_print_changed(test_print)

const ForgeRulesDefScript = preload("res://core/defs/forge_rules_def.gd")
const ForgeViewTuningDefScript = preload("res://core/defs/forge_view_tuning_def.gd")
const ForgeSamplePresetDefScript = preload("res://core/defs/forge/forge_sample_preset_def.gd")
const ForgeSampleBrushDefScript = preload("res://core/defs/forge/forge_sample_brush_def.gd")
const ForgeServiceScript = preload("res://services/forge_service.gd")
const TestPrintMeshBuilderScript = preload("res://runtime/forge/test_print_mesh_builder.gd")

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const DEFAULT_FORGE_VIEW_TUNING_RESOURCE: ForgeViewTuningDef = preload("res://core/defs/forge/forge_view_tuning_default.tres")

@export var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE
@export var forge_view_tuning: ForgeViewTuningDef = DEFAULT_FORGE_VIEW_TUNING_RESOURCE
@export var auto_run_debug_bake_loop: bool = false
@export var test_print_spawn_root_path: NodePath
@export_dir var material_defs_root_dir: String = "res://core/defs/materials"

var grid_size: Vector3i = DEFAULT_FORGE_RULES_RESOURCE.grid_size
var active_wip: CraftedItemWIP
var active_test_print: TestPrintInstance
var active_baked_profile: BakedProfile
var active_layer_index: int = DEFAULT_FORGE_RULES_RESOURCE.grid_size.z >> 1
var forge_service: ForgeService = ForgeServiceScript.new(DEFAULT_FORGE_RULES_RESOURCE)
var test_print_mesh_builder: TestPrintMeshBuilder = TestPrintMeshBuilderScript.new()
var test_print_spawn_root: Node3D
var test_print_mesh_instance: MeshInstance3D
var active_cell_lookup: Dictionary = {}

var active_sample_preset_id: StringName = DEFAULT_FORGE_RULES_RESOURCE.default_sample_preset_id

func _ready() -> void:
	_apply_forge_rules()
	test_print_mesh_builder.set_view_tuning(_get_forge_view_tuning())
	test_print_spawn_root = get_node_or_null(test_print_spawn_root_path) as Node3D
	_ensure_test_print_mesh_instance()
	_sync_spawned_test_print_mesh()
	if not auto_run_debug_bake_loop:
		return
	run_debug_bake_loop()

func configure_grid(new_grid_size: Vector3i) -> void:
	grid_size = new_grid_size

func get_cell_world_size_meters() -> float:
	return _get_forge_rules().cell_world_size_meters

func get_default_sample_preset_id() -> StringName:
	return _get_forge_rules().default_sample_preset_id

func get_sample_grip_preset_id() -> StringName:
	return _get_forge_rules().sample_grip_preset_id

func get_sample_flex_preset_id() -> StringName:
	return _get_forge_rules().sample_flex_preset_id

func get_sample_bow_preset_id() -> StringName:
	return _get_forge_rules().sample_bow_preset_id

func get_sample_preset_ids() -> Array[StringName]:
	var preset_ids: Array[StringName] = []
	for preset_def: ForgeSamplePresetDef in _get_forge_rules().sample_presets:
		if preset_def == null:
			continue
		preset_ids.append(preset_def.preset_id)
	return preset_ids

func get_sample_preset_defs() -> Array[ForgeSamplePresetDef]:
	return _get_forge_rules().sample_presets

func get_sample_preset_display_name(sample_preset_id: StringName) -> String:
	var preset_def: ForgeSamplePresetDef = _get_sample_preset_def(sample_preset_id)
	if preset_def == null or preset_def.display_name.is_empty():
		return String(sample_preset_id)
	return preset_def.display_name

func get_debug_inventory_seed_quantity() -> int:
	return _get_forge_rules().debug_inventory_seed_quantity

func get_debug_inventory_bonus_quantity() -> int:
	return _get_forge_rules().debug_inventory_bonus_quantity

func get_inventory_seed_def() -> Resource:
	return _get_forge_rules().inventory_seed_def

func get_material_catalog_def() -> Resource:
	return _get_forge_rules().material_catalog_def

func get_default_material_tier_def() -> Resource:
	return _get_forge_rules().default_material_tier_def

func get_material_catalog_ids() -> Array[StringName]:
	return _build_ordered_material_ids(build_default_material_lookup())

func set_active_wip(wip: CraftedItemWIP) -> void:
	active_wip = wip
	_rebuild_active_cell_lookup()
	active_baked_profile = null
	emit_signal("active_wip_changed", active_wip)

func set_active_test_print(test_print: TestPrintInstance) -> void:
	active_test_print = test_print
	_sync_spawned_test_print_mesh()
	emit_signal("active_test_print_changed", active_test_print)

func clear_active_test_print() -> void:
	if active_test_print == null:
		return
	active_test_print = null
	_sync_spawned_test_print_mesh()
	emit_signal("active_test_print_changed", active_test_print)

func get_active_baked_profile() -> BakedProfile:
	return active_baked_profile

func get_forge_service() -> ForgeService:
	return forge_service

func clear_active_baked_profile() -> void:
	active_baked_profile = null

func get_active_layer_index() -> int:
	return clampi(active_layer_index, 0, grid_size.z - 1)

func set_active_layer_index(layer_index: int) -> void:
	active_layer_index = clampi(layer_index, 0, grid_size.z - 1)

func ensure_debug_sample_wip() -> CraftedItemWIP:
	if active_wip == null:
		set_active_wip(_build_debug_sample_wip(active_sample_preset_id))
	return active_wip

func reset_debug_sample_wip() -> CraftedItemWIP:
	set_active_layer_index(get_default_active_layer())
	set_active_wip(_build_debug_sample_wip(active_sample_preset_id))
	clear_active_test_print()
	return active_wip

func load_debug_sample_preset(preset_id: StringName) -> CraftedItemWIP:
	active_sample_preset_id = preset_id
	set_active_layer_index(get_default_active_layer())
	set_active_wip(_build_debug_sample_wip(active_sample_preset_id))
	clear_active_test_print()
	return active_wip

func load_player_saved_wip(saved_wip: CraftedItemWIP) -> CraftedItemWIP:
	if saved_wip == null:
		return null
	active_sample_preset_id = StringName()
	set_active_layer_index(get_default_active_layer())
	set_active_wip(saved_wip.duplicate(true) as CraftedItemWIP)
	clear_active_test_print()
	return active_wip

func load_new_blank_wip(project_name: String = "") -> CraftedItemWIP:
	active_sample_preset_id = StringName()
	set_active_layer_index(get_default_active_layer())
	set_active_wip(_build_blank_wip(project_name))
	clear_active_test_print()
	return active_wip

func get_active_sample_preset_id() -> StringName:
	return active_sample_preset_id

func get_default_active_layer() -> int:
	return grid_size.z >> 1

func get_max_fill_cells() -> int:
	return int(floor(float(grid_size.x * grid_size.y * grid_size.z) * _get_forge_rules().max_fill_ratio))

func get_material_id_at(grid_position: Vector3i) -> StringName:
	var target_cell: CellAtom = _get_cell_at_position(grid_position)
	return target_cell.material_variant_id if target_cell != null else StringName()

func set_material_at(grid_position: Vector3i, material_variant_id: StringName) -> bool:
	if material_variant_id == StringName():
		return false
	var wip: CraftedItemWIP = ensure_debug_sample_wip()
	if wip == null:
		return false
	var layer_atom: LayerAtom = _get_or_create_layer(wip, grid_position.z)
	var existing_cell: CellAtom = _get_cell_at_position(grid_position)
	if existing_cell == null:
		var new_cell: CellAtom = CellAtom.new()
		new_cell.grid_position = grid_position
		new_cell.layer_index = grid_position.z
		new_cell.material_variant_id = material_variant_id
		layer_atom.cells.append(new_cell)
		active_cell_lookup[_build_cell_lookup_key(grid_position)] = new_cell
	else:
		existing_cell.material_variant_id = material_variant_id
	_sort_layer_cells(layer_atom)
	_mark_wip_dirty(wip)
	return true

func remove_material_at(grid_position: Vector3i) -> StringName:
	if active_wip == null:
		return StringName()
	var target_cell: CellAtom = _get_cell_at_position(grid_position)
	if target_cell == null:
		return StringName()
	var target_layer: LayerAtom = _find_layer_by_index(target_cell.layer_index)
	if target_layer != null:
		target_layer.cells.erase(target_cell)
	active_cell_lookup.erase(_build_cell_lookup_key(grid_position))
	var removed_material_id: StringName = target_cell.material_variant_id
	_mark_wip_dirty(active_wip)
	return removed_material_id

func build_default_material_lookup() -> Dictionary:
	return _build_debug_material_lookup()

func bake_active_wip(
		material_lookup: Dictionary = {},
		shape_data: Dictionary = {},
		joint_data: Dictionary = {},
		bow_data: Dictionary = {}
	) -> BakedProfile:
	if active_wip == null:
		return null
	active_baked_profile = forge_service.bake_wip(active_wip, material_lookup, shape_data, joint_data, bow_data)
	return active_baked_profile

func spawn_test_print_from_active_wip(
		material_lookup: Dictionary = {},
		shape_data: Dictionary = {},
		joint_data: Dictionary = {},
		bow_data: Dictionary = {}
	) -> TestPrintInstance:
	if active_wip == null:
		return null
	set_active_test_print(forge_service.build_test_print_from_wip(
		active_wip,
		material_lookup,
		shape_data,
		joint_data,
		bow_data
	))
	active_baked_profile = active_test_print.baked_profile if active_test_print != null else null
	return active_test_print

func bake_active_wip_with_defaults() -> TestPrintInstance:
	ensure_debug_sample_wip()
	var material_lookup: Dictionary = build_default_material_lookup()
	var test_print: TestPrintInstance = spawn_test_print_from_active_wip(material_lookup)
	if test_print == null:
		print("ForgeGridController: default bake did not produce a test print")
		return null

	var baked_profile: BakedProfile = active_baked_profile
	if baked_profile != null:
		print("ForgeGridController debug bake result")
		print("  validation_error=", baked_profile.validation_error)
		print("  primary_grip_valid=", baked_profile.primary_grip_valid)
	print("  test_print_id=", test_print.test_id)
	return test_print

func run_debug_bake_loop() -> TestPrintInstance:
	return bake_active_wip_with_defaults()

func _build_debug_sample_wip(sample_preset_id: StringName = StringName()) -> CraftedItemWIP:
	var resolved_sample_preset_id: StringName = sample_preset_id if sample_preset_id != StringName() else get_default_sample_preset_id()
	var preset_def: ForgeSamplePresetDef = _get_sample_preset_def(resolved_sample_preset_id)
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = StringName("debug_%s" % String(resolved_sample_preset_id))
	wip.forge_project_name = preset_def.display_name if preset_def != null else ""
	wip.creator_id = &"sandbox"
	wip.created_timestamp = Time.get_unix_time_from_system()
	if preset_def != null:
		wip.forge_intent = preset_def.forge_intent
		wip.equipment_context = preset_def.equipment_context
		wip.layers = _build_layers_from_cells(_build_cells_from_sample_preset(preset_def))
	else:
		wip.forge_intent = &"intent_melee"
		wip.equipment_context = &"ctx_weapon"
		wip.layers = []
	return wip

func _build_blank_wip(project_name: String = "") -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = StringName("draft_%s" % str(Time.get_unix_time_from_system()))
	wip.forge_project_name = project_name.strip_edges()
	wip.creator_id = &"sandbox"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.layers = []
	return wip

func _apply_forge_rules() -> void:
	var rules: ForgeRulesDef = _get_forge_rules()
	grid_size = rules.grid_size
	forge_service.set_forge_rules(rules)
	test_print_mesh_builder.set_view_tuning(_get_forge_view_tuning())
	if active_sample_preset_id == StringName():
		active_sample_preset_id = rules.default_sample_preset_id
	active_layer_index = clampi(active_layer_index, 0, grid_size.z - 1)

func _get_forge_rules() -> ForgeRulesDef:
	return forge_rules if forge_rules != null else DEFAULT_FORGE_RULES_RESOURCE

func _get_sample_preset_def(sample_preset_id: StringName) -> ForgeSamplePresetDef:
	for preset_def: ForgeSamplePresetDef in _get_forge_rules().sample_presets:
		if preset_def == null:
			continue
		if preset_def.preset_id == sample_preset_id:
			return preset_def
	return null

func _build_cells_from_sample_preset(preset_def: ForgeSamplePresetDef) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	if preset_def == null:
		return cells
	var sample_size: Vector3i = preset_def.footprint_size_voxels
	var origin: Vector3i = _get_sample_origin(sample_size.x, sample_size.y, sample_size.z)
	for brush_def: ForgeSampleBrushDef in preset_def.brushes:
		if brush_def == null:
			continue
		var brush_size: Vector3i = brush_def.size_voxels
		var brush_origin: Vector3i = origin + brush_def.offset_voxels
		for z in range(brush_size.z):
			for y in range(brush_size.y):
				for x in range(brush_size.x):
					cells.append(_make_cell(brush_origin + Vector3i(x, y, z), brush_def.material_variant_id))
	return cells

func _get_sample_origin(sample_width: int, sample_height: int, sample_depth: int) -> Vector3i:
	var start_x: int = (grid_size.x - sample_width) >> 1
	var start_y: int = (grid_size.y - sample_height) >> 1
	var start_z: int = clampi(get_default_active_layer(), 0, maxi(grid_size.z - sample_depth, 0))
	return Vector3i(start_x, start_y, start_z)

func _build_layers_from_cells(cells: Array[CellAtom]) -> Array[LayerAtom]:
	var layer_map: Dictionary = {}
	for cell: CellAtom in cells:
		if cell == null:
			continue
		if not layer_map.has(cell.layer_index):
			var layer: LayerAtom = LayerAtom.new()
			layer.layer_index = cell.layer_index
			layer.cells = []
			layer_map[cell.layer_index] = layer
		var target_layer: LayerAtom = layer_map[cell.layer_index]
		target_layer.cells.append(cell)

	var ordered_indices: Array = layer_map.keys()
	ordered_indices.sort()
	var layers: Array[LayerAtom] = []
	for layer_index in ordered_indices:
		layers.append(layer_map[layer_index])
	return layers

func _get_or_create_layer(wip: CraftedItemWIP, layer_index: int) -> LayerAtom:
	for existing_layer: LayerAtom in wip.layers:
		if existing_layer != null and existing_layer.layer_index == layer_index:
			return existing_layer
	var new_layer: LayerAtom = LayerAtom.new()
	new_layer.layer_index = layer_index
	wip.layers.append(new_layer)
	wip.layers.sort_custom(func(a: LayerAtom, b: LayerAtom) -> bool:
		if a == null:
			return false
		if b == null:
			return true
		return a.layer_index < b.layer_index
	)
	return new_layer

func _find_cell_at_position(layer_atom: LayerAtom, grid_position: Vector3i) -> CellAtom:
	for cell: CellAtom in layer_atom.cells:
		if cell == null:
			continue
		if cell.grid_position == grid_position:
			return cell
	return null

func _get_cell_at_position(grid_position: Vector3i) -> CellAtom:
	return active_cell_lookup.get(_build_cell_lookup_key(grid_position)) as CellAtom

func _find_layer_by_index(layer_index: int) -> LayerAtom:
	if active_wip == null:
		return null
	for layer_atom: LayerAtom in active_wip.layers:
		if layer_atom == null:
			continue
		if layer_atom.layer_index == layer_index:
			return layer_atom
	return null

func _mark_wip_dirty(wip: CraftedItemWIP) -> void:
	if wip != null:
		wip.latest_baked_profile_snapshot = null
	active_baked_profile = null
	active_wip = wip
	emit_signal("active_wip_changed", active_wip)
	clear_active_test_print()

func _sort_layer_cells(layer_atom: LayerAtom) -> void:
	layer_atom.cells.sort_custom(func(a: CellAtom, b: CellAtom) -> bool:
		if a == null:
			return false
		if b == null:
			return true
		if a.grid_position.x != b.grid_position.x:
			return a.grid_position.x < b.grid_position.x
		if a.grid_position.y != b.grid_position.y:
			return a.grid_position.y < b.grid_position.y
		return a.grid_position.z < b.grid_position.z
	)

func _make_cell(grid_position: Vector3i, material_variant_id: StringName) -> CellAtom:
	var cell: CellAtom = CellAtom.new()
	cell.grid_position = grid_position
	cell.layer_index = grid_position.z
	cell.material_variant_id = material_variant_id
	return cell

func _rebuild_active_cell_lookup() -> void:
	active_cell_lookup.clear()
	if active_wip == null:
		return
	for layer_atom: LayerAtom in active_wip.layers:
		if layer_atom == null:
			continue
		for cell: CellAtom in layer_atom.cells:
			if cell == null:
				continue
			active_cell_lookup[_build_cell_lookup_key(cell.grid_position)] = cell

func _build_cell_lookup_key(grid_position: Vector3i) -> StringName:
	return StringName("%d,%d,%d" % [grid_position.x, grid_position.y, grid_position.z])

func _build_debug_material_lookup() -> Dictionary:
	var material_lookup: Dictionary = {}
	_collect_catalog_material_defs(material_lookup)
	_collect_material_defs_in_dir(material_defs_root_dir, material_lookup)
	return material_lookup

func _collect_catalog_material_defs(material_lookup: Dictionary) -> void:
	var catalog_def: Resource = get_material_catalog_def()
	if catalog_def == null or catalog_def.is_empty():
		return
	for catalog_entry: Resource in catalog_def.entries:
		var base_material: BaseMaterialDef = _resolve_catalog_entry_material_def(catalog_entry)
		var material_id: StringName = _resolve_catalog_entry_material_id(catalog_entry, base_material)
		var material_variant: MaterialVariantDef = _build_catalog_material_variant(base_material)
		if base_material == null:
			continue
		material_lookup[base_material.base_material_id] = base_material
		if material_variant != null:
			material_lookup[material_variant.variant_id] = material_variant
		if material_id != StringName() and material_lookup.has(material_id):
			continue
		if material_id != StringName():
			if material_variant != null:
				material_lookup[material_id] = material_variant
			else:
				material_lookup[material_id] = base_material

func _build_ordered_material_ids(material_lookup: Dictionary) -> Array[StringName]:
	var ordered_ids: Array[StringName] = []
	var catalog_def: Resource = get_material_catalog_def()
	var has_authored_catalog: bool = false
	if catalog_def != null and not catalog_def.is_empty():
		has_authored_catalog = true
		for catalog_entry: Resource in catalog_def.entries:
			var base_material: BaseMaterialDef = _resolve_catalog_entry_material_def(catalog_entry)
			var material_id: StringName = _resolve_catalog_entry_material_id(catalog_entry, base_material)
			if material_id == StringName() or ordered_ids.has(material_id):
				continue
			if base_material != null and not material_lookup.has(material_id):
				material_lookup[material_id] = base_material
			if material_lookup.has(material_id):
				ordered_ids.append(material_id)
	if has_authored_catalog and not ordered_ids.is_empty():
		return ordered_ids

	var discovered_material_ids: Array = material_lookup.keys()
	discovered_material_ids.sort()
	for material_id_value in discovered_material_ids:
		var material_id: StringName = material_id_value
		if ordered_ids.has(material_id):
			continue
		ordered_ids.append(material_id)
	return ordered_ids

func _resolve_catalog_entry_material_def(catalog_entry: Resource) -> BaseMaterialDef:
	if catalog_entry == null:
		return null
	return catalog_entry.material_def as BaseMaterialDef

func _resolve_catalog_entry_material_id(catalog_entry: Resource, base_material: BaseMaterialDef = null) -> StringName:
	var material_variant: MaterialVariantDef = _build_catalog_material_variant(base_material)
	if catalog_entry != null and catalog_entry.material_id != StringName():
		if base_material != null and material_variant != null and catalog_entry.material_id == base_material.base_material_id:
			return material_variant.variant_id
		return catalog_entry.material_id
	if material_variant != null:
		return material_variant.variant_id
	if base_material != null:
		return base_material.base_material_id
	return StringName()

func _build_catalog_material_variant(base_material: BaseMaterialDef) -> MaterialVariantDef:
	var default_tier: TierDef = get_default_material_tier_def() as TierDef
	if base_material == null or default_tier == null:
		return null
	return forge_service.build_material_variant(base_material, default_tier)

func _collect_material_defs_in_dir(directory_path: String, material_lookup: Dictionary) -> void:
	if directory_path.is_empty():
		return
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	while true:
		var entry_name: String = directory.get_next()
		if entry_name.is_empty():
			break
		if entry_name.begins_with("."):
			continue
		var entry_path: String = "%s/%s" % [directory_path, entry_name]
		if directory.current_is_dir():
			_collect_material_defs_in_dir(entry_path, material_lookup)
			continue
		if not entry_name.ends_with(".tres"):
			continue
		var base_material: BaseMaterialDef = load(entry_path) as BaseMaterialDef
		if base_material == null:
			continue
		if base_material.base_material_id == StringName():
			continue
		material_lookup[base_material.base_material_id] = base_material
	directory.list_dir_end()

func _ensure_test_print_mesh_instance() -> void:
	if test_print_spawn_root == null:
		return
	if is_instance_valid(test_print_mesh_instance):
		return

	test_print_mesh_instance = MeshInstance3D.new()
	test_print_mesh_instance.name = "ActiveTestPrintMesh"
	test_print_mesh_instance.material_override = _build_test_print_material()
	test_print_mesh_instance.visible = false
	test_print_spawn_root.add_child(test_print_mesh_instance)

func _sync_spawned_test_print_mesh() -> void:
	if test_print_spawn_root == null:
		return
	_ensure_test_print_mesh_instance()
	if not is_instance_valid(test_print_mesh_instance):
		return

	if active_test_print == null:
		test_print_mesh_instance.mesh = null
		test_print_mesh_instance.position = Vector3.ZERO
		test_print_mesh_instance.visible = false
		return

	var material_lookup: Dictionary = build_default_material_lookup()
	var mesh: ArrayMesh = test_print_mesh_builder.build_mesh(active_test_print.display_cells, material_lookup)
	if mesh == null or mesh.get_surface_count() == 0:
		test_print_mesh_instance.mesh = null
		test_print_mesh_instance.position = Vector3.ZERO
		test_print_mesh_instance.visible = false
		return

	test_print_mesh_instance.mesh = mesh
	test_print_mesh_instance.position = -mesh.get_aabb().get_center()
	test_print_mesh_instance.visible = true

func _build_test_print_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = _get_forge_view_tuning().test_print_material_roughness
	material.metallic = _get_forge_view_tuning().test_print_material_metallic
	return material

func _get_forge_view_tuning() -> ForgeViewTuningDef:
	return forge_view_tuning if forge_view_tuning != null else DEFAULT_FORGE_VIEW_TUNING_RESOURCE
