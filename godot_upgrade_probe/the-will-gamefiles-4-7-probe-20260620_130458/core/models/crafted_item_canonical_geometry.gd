extends RefCounted
class_name CraftedItemCanonicalGeometry

var source_solid = null
var surface_quads: Array = []
var surface_triangles: Array = []
var local_aabb: AABB = AABB()

func is_empty() -> bool:
	return surface_quads.is_empty() and surface_triangles.is_empty()

func get_quad_count() -> int:
	return surface_quads.size()

func get_triangle_count() -> int:
	return surface_triangles.size()

func get_surface_primitive_count() -> int:
	return surface_quads.size() + surface_triangles.size()

func get_local_center() -> Vector3:
	return local_aabb.get_center()

func get_padded_local_aabb(padding_cells: int = 1) -> AABB:
	if source_solid != null and not source_solid.is_empty():
		return source_solid.get_padded_local_aabb(padding_cells)
	if local_aabb.size == Vector3.ZERO:
		return AABB()
	return local_aabb.grow(float(padding_cells))
