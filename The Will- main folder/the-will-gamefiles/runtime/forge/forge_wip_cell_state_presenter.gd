extends RefCounted
class_name ForgeWipCellStatePresenter

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")

func get_material_id_at(active_cell_lookup: Dictionary, grid_position: Vector3i) -> StringName:
	var target_cell: CellAtom = _get_cell_at_position(active_cell_lookup, grid_position)
	return target_cell.material_variant_id if target_cell != null else StringName()

func set_material_at(
	active_cell_lookup: Dictionary,
	grid_position: Vector3i,
	material_variant_id: StringName,
	ensure_editable_wip: Callable,
	mark_wip_dirty: Callable
) -> bool:
	if material_variant_id == StringName():
		return false
	var wip: CraftedItemWIP = ensure_editable_wip.call()
	if wip == null:
		return false
	var layer_atom: LayerAtom = _get_or_create_layer(wip, grid_position.z)
	var existing_cell: CellAtom = _get_cell_at_position(active_cell_lookup, grid_position)
	if existing_cell == null:
		var new_cell: CellAtom = CellAtom.new()
		new_cell.grid_position = grid_position
		new_cell.layer_index = grid_position.z
		new_cell.material_variant_id = material_variant_id
		layer_atom.cells.append(new_cell)
		active_cell_lookup[grid_position] = new_cell
	else:
		existing_cell.material_variant_id = material_variant_id
	_sort_layer_cells(layer_atom)
	mark_wip_dirty.call(wip)
	return true

func set_materials_at(
	active_cell_lookup: Dictionary,
	grid_positions: Array[Vector3i],
	material_variant_id: StringName,
	ensure_editable_wip: Callable,
	mark_wip_dirty: Callable
) -> int:
	if material_variant_id == StringName() or grid_positions.is_empty():
		return 0
	var wip: CraftedItemWIP = ensure_editable_wip.call()
	if wip == null:
		return 0
	var visited: Dictionary = {}
	var cached_layers: Dictionary = {}
	var layers_needing_sort: Dictionary = {}
	var changed_count: int = 0
	for grid_position: Vector3i in grid_positions:
		if visited.has(grid_position):
			continue
		visited[grid_position] = true
		var existing_cell: CellAtom = _get_cell_at_position(active_cell_lookup, grid_position)
		if existing_cell == null:
			var layer_atom: LayerAtom = cached_layers.get(grid_position.z) as LayerAtom
			if layer_atom == null:
				layer_atom = _get_or_create_layer(wip, grid_position.z)
				cached_layers[grid_position.z] = layer_atom
			var new_cell: CellAtom = CellAtom.new()
			new_cell.grid_position = grid_position
			new_cell.layer_index = grid_position.z
			new_cell.material_variant_id = material_variant_id
			layer_atom.cells.append(new_cell)
			active_cell_lookup[grid_position] = new_cell
			layers_needing_sort[layer_atom.layer_index] = layer_atom
			changed_count += 1
			continue
		if existing_cell.material_variant_id == material_variant_id:
			continue
		existing_cell.material_variant_id = material_variant_id
		changed_count += 1
	if changed_count <= 0:
		return 0
	for layer_variant: Variant in layers_needing_sort.values():
		var layer_atom: LayerAtom = layer_variant as LayerAtom
		if layer_atom == null:
			continue
		_sort_layer_cells(layer_atom)
	mark_wip_dirty.call(wip)
	return changed_count

func remove_material_at(
	active_wip: CraftedItemWIP,
	active_cell_lookup: Dictionary,
	grid_position: Vector3i,
	mark_wip_dirty: Callable
) -> StringName:
	if active_wip == null:
		return StringName()
	var target_cell: CellAtom = _get_cell_at_position(active_cell_lookup, grid_position)
	if target_cell == null:
		return StringName()
	var target_layer: LayerAtom = _find_layer_by_index(active_wip, target_cell.layer_index)
	if target_layer != null:
		target_layer.cells.erase(target_cell)
	active_cell_lookup.erase(grid_position)
	var removed_material_id: StringName = target_cell.material_variant_id
	mark_wip_dirty.call(active_wip)
	return removed_material_id

func remove_materials_at(
	active_wip: CraftedItemWIP,
	active_cell_lookup: Dictionary,
	grid_positions: Array[Vector3i],
	mark_wip_dirty: Callable
) -> Dictionary:
	if active_wip == null or grid_positions.is_empty():
		return {
			"removed_count": 0,
			"removed_counts": {},
		}
	var visited: Dictionary = {}
	var removed_positions: Dictionary = {}
	var changed_layer_indexes: Dictionary = {}
	var removed_counts: Dictionary = {}
	var removed_count: int = 0
	for grid_position: Vector3i in grid_positions:
		if visited.has(grid_position):
			continue
		visited[grid_position] = true
		var target_cell: CellAtom = _get_cell_at_position(active_cell_lookup, grid_position)
		if target_cell == null:
			continue
		removed_positions[grid_position] = true
		changed_layer_indexes[target_cell.layer_index] = true
		active_cell_lookup.erase(grid_position)
		removed_counts[target_cell.material_variant_id] = int(removed_counts.get(target_cell.material_variant_id, 0)) + 1
		removed_count += 1
	if removed_count <= 0:
		return {
			"removed_count": 0,
			"removed_counts": {},
		}
	for layer_index_variant: Variant in changed_layer_indexes.keys():
		var layer_index: int = int(layer_index_variant)
		var target_layer: LayerAtom = _find_layer_by_index(active_wip, layer_index)
		if target_layer == null:
			continue
		var filtered_cells: Array[CellAtom] = []
		for cell: CellAtom in target_layer.cells:
			if cell == null:
				continue
			if removed_positions.has(cell.grid_position):
				continue
			filtered_cells.append(cell)
		target_layer.cells = filtered_cells
	mark_wip_dirty.call(active_wip)
	return {
		"removed_count": removed_count,
		"removed_counts": removed_counts,
	}

func rebuild_active_cell_lookup(active_wip: CraftedItemWIP) -> Dictionary:
	var active_cell_lookup: Dictionary = {}
	if active_wip == null:
		return active_cell_lookup
	for layer_atom: LayerAtom in active_wip.layers:
		if layer_atom == null:
			continue
		for cell: CellAtom in layer_atom.cells:
			if cell == null:
				continue
			if CraftedItemWIPScript.is_builder_marker_material_id(cell.material_variant_id):
				continue
			active_cell_lookup[cell.grid_position] = cell
	return active_cell_lookup

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

func _get_cell_at_position(active_cell_lookup: Dictionary, grid_position: Vector3i) -> CellAtom:
	return active_cell_lookup.get(grid_position) as CellAtom

func _find_layer_by_index(active_wip: CraftedItemWIP, layer_index: int) -> LayerAtom:
	if active_wip == null:
		return null
	for layer_atom: LayerAtom in active_wip.layers:
		if layer_atom == null:
			continue
		if layer_atom.layer_index == layer_index:
			return layer_atom
	return null

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
