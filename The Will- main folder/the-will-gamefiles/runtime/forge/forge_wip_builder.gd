extends RefCounted
class_name ForgeWipBuilder

func get_sample_preset_def(authoring_sandbox: Resource, sample_preset_id: StringName) -> Resource:
	if authoring_sandbox == null:
		return null
	for preset_def: Resource in authoring_sandbox.sample_presets:
		if preset_def == null:
			continue
		if preset_def.preset_id == sample_preset_id:
			return preset_def
	return null

func build_sample_preset_wip(
	authoring_sandbox: Resource,
	grid_size: Vector3i,
	default_active_layer: int,
	sample_preset_id: StringName
) -> CraftedItemWIP:
	if authoring_sandbox == null:
		return null
	var resolved_sample_preset_id: StringName = sample_preset_id if sample_preset_id != StringName() else authoring_sandbox.default_sample_preset_id
	var preset_def: Resource = get_sample_preset_def(authoring_sandbox, resolved_sample_preset_id)
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = StringName("sample_%s" % String(resolved_sample_preset_id))
	wip.forge_project_name = preset_def.display_name if preset_def != null else ""
	wip.creator_id = &"sample_preset"
	wip.created_timestamp = Time.get_unix_time_from_system()
	if preset_def != null:
		wip.forge_intent = preset_def.forge_intent
		wip.equipment_context = preset_def.equipment_context
		wip.layers = _build_layers_from_cells(
			_build_cells_from_sample_preset(preset_def, grid_size, default_active_layer)
		)
	else:
		wip.forge_intent = &"intent_melee"
		wip.equipment_context = &"ctx_weapon"
		wip.layers = []
	return wip

func build_blank_wip(project_name: String = "") -> CraftedItemWIP:
	return build_blank_wip_for_builder_path(project_name, CraftedItemWIP.BUILDER_PATH_MELEE)

func build_blank_wip_for_builder_path(
	project_name: String,
	builder_path_id: StringName,
	builder_component_id: StringName = StringName()
) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = StringName("draft_%s" % str(Time.get_unix_time_from_system()))
	wip.forge_project_name = project_name.strip_edges()
	wip.creator_id = &"sandbox"
	wip.created_timestamp = Time.get_unix_time_from_system()
	CraftedItemWIP.apply_builder_path_defaults(wip, builder_path_id, builder_component_id)
	wip.layers = []
	return wip

func _build_cells_from_sample_preset(
	preset_def: Resource,
	grid_size: Vector3i,
	default_active_layer: int
) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	if preset_def == null:
		return cells
	var sample_size: Vector3i = preset_def.footprint_size_voxels
	var origin: Vector3i = _get_sample_origin(grid_size, sample_size.x, sample_size.y, sample_size.z, default_active_layer)
	for brush_def: Resource in preset_def.brushes:
		if brush_def == null:
			continue
		var brush_size: Vector3i = brush_def.size_voxels
		var brush_origin: Vector3i = origin + brush_def.offset_voxels
		for z in range(brush_size.z):
			for y in range(brush_size.y):
				for x in range(brush_size.x):
					cells.append(_make_cell(brush_origin + Vector3i(x, y, z), brush_def.material_variant_id))
	return cells

func _get_sample_origin(
	grid_size: Vector3i,
	sample_width: int,
	sample_height: int,
	sample_depth: int,
	default_active_layer: int
) -> Vector3i:
	var start_x: int = (grid_size.x - sample_width) >> 1
	var start_y: int = (grid_size.y - sample_height) >> 1
	var start_z: int = clampi(default_active_layer, 0, maxi(grid_size.z - sample_depth, 0))
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

func _make_cell(grid_position: Vector3i, material_variant_id: StringName) -> CellAtom:
	var cell: CellAtom = CellAtom.new()
	cell.grid_position = grid_position
	cell.layer_index = grid_position.z
	cell.material_variant_id = material_variant_id
	return cell
