extends Resource
class_name Stage2EditableMeshState

@export var primitive_type: Mesh.PrimitiveType = Mesh.PRIMITIVE_TRIANGLES
@export var surface_arrays: Array = []
@export var triangle_patch_keys: PackedStringArray = PackedStringArray()
@export var triangle_face_ids: PackedStringArray = PackedStringArray()
@export var local_aabb_position: Vector3 = Vector3.ZERO
@export var local_aabb_size: Vector3 = Vector3.ZERO
@export var dirty: bool = false

func has_surface_arrays() -> bool:
	if surface_arrays.is_empty():
		return false
	if surface_arrays.size() <= Mesh.ARRAY_VERTEX:
		return false
	return surface_arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array and not surface_arrays[Mesh.ARRAY_VERTEX].is_empty()

func get_vertex_count() -> int:
	if not has_surface_arrays():
		return 0
	var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
	return vertices.size()

func get_index_count() -> int:
	if not has_surface_arrays() or surface_arrays.size() <= Mesh.ARRAY_INDEX:
		return 0
	if surface_arrays[Mesh.ARRAY_INDEX] is not PackedInt32Array:
		return 0
	var indices: PackedInt32Array = surface_arrays[Mesh.ARRAY_INDEX]
	return indices.size()

func get_triangle_count() -> int:
	if not has_surface_arrays():
		return 0
	if surface_arrays.size() > Mesh.ARRAY_INDEX and surface_arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		var indices: PackedInt32Array = surface_arrays[Mesh.ARRAY_INDEX]
		if not indices.is_empty():
			return int(float(indices.size()) / 3.0)
	var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
	return int(float(vertices.size()) / 3.0)

func get_local_aabb() -> AABB:
	return AABB(local_aabb_position, local_aabb_size)

func copy_from_surface_arrays(
	arrays: Array,
	next_primitive_type: Mesh.PrimitiveType = Mesh.PRIMITIVE_TRIANGLES,
	local_aabb: AABB = AABB(),
	next_triangle_patch_keys: PackedStringArray = PackedStringArray(),
	next_triangle_face_ids: PackedStringArray = PackedStringArray()
) -> void:
	primitive_type = next_primitive_type
	surface_arrays = arrays.duplicate(true) if not arrays.is_empty() else []
	triangle_patch_keys = PackedStringArray(next_triangle_patch_keys)
	triangle_face_ids = PackedStringArray(next_triangle_face_ids)
	local_aabb_position = local_aabb.position
	local_aabb_size = local_aabb.size
	dirty = false

func build_array_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if not has_surface_arrays():
		return mesh
	mesh.add_surface_from_arrays(primitive_type, surface_arrays)
	return mesh
