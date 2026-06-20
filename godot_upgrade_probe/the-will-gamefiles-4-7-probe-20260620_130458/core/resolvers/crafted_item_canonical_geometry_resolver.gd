extends RefCounted
class_name CraftedItemCanonicalGeometryResolver

const CraftedItemCanonicalGeometryScript = preload("res://core/models/crafted_item_canonical_geometry.gd")
const CraftedItemCanonicalSurfaceQuadScript = preload("res://core/models/crafted_item_canonical_surface_quad.gd")

func resolve_from_solid(canonical_solid):
	var geometry = CraftedItemCanonicalGeometryScript.new()
	geometry.source_solid = canonical_solid
	if canonical_solid == null or canonical_solid.is_empty():
		return geometry
	geometry.local_aabb = canonical_solid.get_local_aabb()
	var dimensions := [
		canonical_solid.dimensions_voxels.x,
		canonical_solid.dimensions_voxels.y,
		canonical_solid.dimensions_voxels.z
	]
	for axis_index: int in range(3):
		_append_axis_quads(geometry, canonical_solid, dimensions, axis_index)
	return geometry

func _append_axis_quads(
		geometry,
		canonical_solid,
		dimensions: Array,
		axis_index: int
	) -> void:
	var axis_u: int = (axis_index + 1) % 3
	var axis_v: int = (axis_index + 2) % 3
	var axis_dimensions := [
		int(dimensions[0]),
		int(dimensions[1]),
		int(dimensions[2])
	]
	var sweep_position := [0, 0, 0]
	for slice_index: int in range(-1, axis_dimensions[axis_index]):
		sweep_position[axis_index] = slice_index
		var mask_size: int = axis_dimensions[axis_u] * axis_dimensions[axis_v]
		var mask: Array = []
		mask.resize(mask_size)
		var mask_index: int = 0
		for axis_v_index: int in range(axis_dimensions[axis_v]):
			sweep_position[axis_v] = axis_v_index
			for axis_u_index: int in range(axis_dimensions[axis_u]):
				sweep_position[axis_u] = axis_u_index
				var cell_a: CellAtom = _get_normalized_cell(canonical_solid, sweep_position)
				var forward_position := [
					int(sweep_position[0]),
					int(sweep_position[1]),
					int(sweep_position[2])
				]
				forward_position[axis_index] += 1
				var cell_b: CellAtom = _get_normalized_cell(canonical_solid, forward_position)
				mask[mask_index] = _build_face_info(cell_a, cell_b)
				mask_index += 1
		sweep_position[axis_index] = slice_index + 1
		for axis_v_index: int in range(axis_dimensions[axis_v]):
			var axis_u_index: int = 0
			while axis_u_index < axis_dimensions[axis_u]:
				var face_index: int = axis_u_index + axis_v_index * axis_dimensions[axis_u]
				var face_info: Dictionary = mask[face_index] as Dictionary
				if face_info.is_empty():
					axis_u_index += 1
					continue
				var width: int = 1
				while axis_u_index + width < axis_dimensions[axis_u]:
					var neighbor_face: Dictionary = mask[face_index + width] as Dictionary
					if not _is_same_face_info(face_info, neighbor_face):
						break
					width += 1
				var height: int = 1
				var can_grow: bool = true
				while axis_v_index + height < axis_dimensions[axis_v] and can_grow:
					for width_index: int in range(width):
						var candidate_face: Dictionary = mask[face_index + width_index + height * axis_dimensions[axis_u]] as Dictionary
						if not _is_same_face_info(face_info, candidate_face):
							can_grow = false
							break
					if can_grow:
						height += 1
				var quad_origin := [0, 0, 0]
				quad_origin[axis_index] = sweep_position[axis_index]
				quad_origin[axis_u] = axis_u_index
				quad_origin[axis_v] = axis_v_index
				geometry.surface_quads.append(_build_surface_quad(
					canonical_solid.min_position,
					quad_origin,
					axis_index,
					axis_u,
					axis_v,
					width,
					height,
					face_info
				))
				for clear_v_index: int in range(height):
					for clear_u_index: int in range(width):
						mask[face_index + clear_u_index + clear_v_index * axis_dimensions[axis_u]] = {}
				axis_u_index += width

func _build_surface_quad(
		min_position: Vector3i,
		origin: Array,
		axis_index: int,
		axis_u: int,
		axis_v: int,
		width: int,
		height: int,
		face_info: Dictionary
	):
	var edge_u := [0, 0, 0]
	var edge_v := [0, 0, 0]
	edge_u[axis_u] = width
	edge_v[axis_v] = height
	var normal_sign: int = int(face_info.get("normal_sign", 1))
	var quad = CraftedItemCanonicalSurfaceQuadScript.new()
	quad.origin_local = _normalized_corner_to_world(origin, min_position)
	quad.edge_u_local = _array_to_vector3(edge_u)
	quad.edge_v_local = _array_to_vector3(edge_v)
	quad.material_variant_id = face_info.get("material_variant_id", StringName())
	quad.width_voxels = width
	quad.height_voxels = height
	match axis_index:
		0:
			quad.normal = Vector3.RIGHT * normal_sign
		1:
			quad.normal = Vector3.UP * normal_sign
		_:
			quad.normal = Vector3.BACK * normal_sign
	return quad

func _get_normalized_cell(canonical_solid, normalized_position: Array) -> CellAtom:
	if canonical_solid == null:
		return null
	return canonical_solid.get_cell_from_normalized_position(Vector3i(
		int(normalized_position[0]),
		int(normalized_position[1]),
		int(normalized_position[2])
	))

func _build_face_info(cell_a: CellAtom, cell_b: CellAtom) -> Dictionary:
	if cell_a == null and cell_b == null:
		return {}
	if cell_a != null and cell_b != null:
		return {}
	var source_cell: CellAtom = cell_a if cell_a != null else cell_b
	return {
		"material_variant_id": source_cell.material_variant_id,
		"normal_sign": 1 if cell_a != null else -1
	}

func _is_same_face_info(left: Dictionary, right: Dictionary) -> bool:
	if left.is_empty() or right.is_empty():
		return false
	if left.get("normal_sign", 0) != right.get("normal_sign", 0):
		return false
	return left.get("material_variant_id", StringName()) == right.get("material_variant_id", StringName())

func _normalized_corner_to_world(normalized_corner: Array, min_position: Vector3i) -> Vector3:
	return Vector3(
		min_position.x + float(normalized_corner[0]) - 0.5,
		min_position.y + float(normalized_corner[1]) - 0.5,
		min_position.z + float(normalized_corner[2]) - 0.5
	)

func _array_to_vector3(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
