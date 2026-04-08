extends RefCounted
class_name CraftedItemCanonicalGeometry

var source_solid = null
var surface_quads: Array = []
var local_aabb: AABB = AABB()

func is_empty() -> bool:
	return source_solid == null or source_solid.is_empty() or surface_quads.is_empty()

func get_quad_count() -> int:
	return surface_quads.size()

func get_local_center() -> Vector3:
	return local_aabb.get_center()

func get_padded_local_aabb(padding_cells: int = 1) -> AABB:
	if source_solid == null:
		return AABB()
	return source_solid.get_padded_local_aabb(padding_cells)
