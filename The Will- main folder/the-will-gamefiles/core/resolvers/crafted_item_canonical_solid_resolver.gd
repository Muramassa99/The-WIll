extends RefCounted
class_name CraftedItemCanonicalSolidResolver

const CraftedItemCanonicalSolidScript = preload("res://core/models/crafted_item_canonical_solid.gd")

func resolve_from_cells(cells: Array[CellAtom]):
	var canonical_solid = CraftedItemCanonicalSolidScript.new()
	var has_bounds: bool = false
	for cell: CellAtom in cells:
		if cell == null:
			continue
		canonical_solid.occupied_cells[cell.grid_position] = cell
		if not has_bounds:
			canonical_solid.min_position = cell.grid_position
			canonical_solid.max_position = cell.grid_position
			has_bounds = true
			continue
		canonical_solid.min_position.x = mini(canonical_solid.min_position.x, cell.grid_position.x)
		canonical_solid.min_position.y = mini(canonical_solid.min_position.y, cell.grid_position.y)
		canonical_solid.min_position.z = mini(canonical_solid.min_position.z, cell.grid_position.z)
		canonical_solid.max_position.x = maxi(canonical_solid.max_position.x, cell.grid_position.x)
		canonical_solid.max_position.y = maxi(canonical_solid.max_position.y, cell.grid_position.y)
		canonical_solid.max_position.z = maxi(canonical_solid.max_position.z, cell.grid_position.z)
	if canonical_solid.is_empty():
		return canonical_solid
	canonical_solid.dimensions_voxels = Vector3i(
		canonical_solid.max_position.x - canonical_solid.min_position.x + 1,
		canonical_solid.max_position.y - canonical_solid.min_position.y + 1,
		canonical_solid.max_position.z - canonical_solid.min_position.z + 1
	)
	return canonical_solid
