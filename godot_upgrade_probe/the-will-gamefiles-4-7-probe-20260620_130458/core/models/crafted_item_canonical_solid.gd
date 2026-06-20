extends RefCounted
class_name CraftedItemCanonicalSolid

var occupied_cells: Dictionary = {}
var min_position: Vector3i = Vector3i.ZERO
var max_position: Vector3i = Vector3i.ZERO
var dimensions_voxels: Vector3i = Vector3i.ZERO

func is_empty() -> bool:
	return occupied_cells.is_empty()

func get_cell_count() -> int:
	return occupied_cells.size()

func get_cell(grid_position: Vector3i) -> CellAtom:
	return occupied_cells.get(grid_position) as CellAtom

func get_cell_from_normalized_position(normalized_position: Vector3i) -> CellAtom:
	return get_cell(Vector3i(
		min_position.x + normalized_position.x,
		min_position.y + normalized_position.y,
		min_position.z + normalized_position.z
	))

func get_local_aabb() -> AABB:
	if is_empty():
		return AABB()
	return AABB(
		Vector3(min_position) - Vector3.ONE * 0.5,
		Vector3(dimensions_voxels)
	)

func get_padded_local_aabb(padding_cells: int = 1) -> AABB:
	if is_empty():
		return AABB()
	var resolved_padding: float = maxf(float(padding_cells), 0.0)
	var padding_vector: Vector3 = Vector3.ONE * resolved_padding
	var base_aabb: AABB = get_local_aabb()
	return AABB(
		base_aabb.position - padding_vector,
		base_aabb.size + padding_vector * 2.0
	)
