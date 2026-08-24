extends MeshInstance3D

const MODE_OFF := 0
const MODE_ACTIVE := 1
const MODE_ACTIVE_WITH_HALO := 2
const MODE_FULL_WORKSPACE := 3

const COLOR_RESIDENT := Color(0.16, 0.42, 1.0, 0.18)
const COLOR_CONTEXT := Color(1.0, 0.82, 0.12, 0.25)
const COLOR_WRITE := Color(0.12, 1.0, 0.38, 0.55)
const COLOR_CONTACT := Color(1.0, 0.32, 0.08, 0.75)
const COLOR_REMESH := Color(1.0, 0.08, 0.16, 0.95)
const COLOR_FULL_WORKSPACE := Color(0.42, 0.52, 0.68, 0.08)

var guide_mode := MODE_OFF
var chunk_world_size_meters := 0.064
var workspace_bounds := AABB(
	Vector3(-0.5, -0.5, -0.5),
	Vector3.ONE
)
var last_snapshot: Dictionary = {}
var rendered_chunk_count := 0


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func configure(
	next_chunk_world_size_meters: float,
	next_workspace_bounds: AABB = AABB(
		Vector3(-0.5, -0.5, -0.5),
		Vector3.ONE
	)
) -> void:
	if is_finite(next_chunk_world_size_meters) and next_chunk_world_size_meters > 0.0:
		chunk_world_size_meters = next_chunk_world_size_meters
	if next_workspace_bounds.size.length_squared() > 0.0:
		workspace_bounds = next_workspace_bounds
	_rebuild()


func set_guide_mode(next_mode: int) -> void:
	guide_mode = clampi(next_mode, MODE_OFF, MODE_FULL_WORKSPACE)
	_rebuild()


func update_from_snapshot(snapshot: Dictionary) -> void:
	last_snapshot = snapshot.duplicate(true)
	var snapshot_chunk_size := float(snapshot.get(
		"chunk_world_size_meters",
		chunk_world_size_meters
	))
	if is_finite(snapshot_chunk_size) and snapshot_chunk_size > 0.0:
		chunk_world_size_meters = snapshot_chunk_size
	_rebuild()


func get_debug_summary() -> Dictionary:
	return {
		"guide_mode": guide_mode,
		"visible": visible,
		"rendered_chunk_count": rendered_chunk_count,
		"surface_count": mesh.get_surface_count() if mesh != null else 0,
		"has_collision_node": _contains_collision_object(self),
	}


func _rebuild() -> void:
	rendered_chunk_count = 0
	if guide_mode == MODE_OFF:
		mesh = null
		visible = false
		return
	var chunk_colors: Dictionary = {}
	if guide_mode == MODE_FULL_WORKSPACE:
		_append_full_workspace_chunks(chunk_colors)
	else:
		_append_snapshot_chunks(
			chunk_colors,
			last_snapshot.get("all_resident_chunk_coords", []),
			COLOR_RESIDENT
		)
		if guide_mode == MODE_ACTIVE_WITH_HALO:
			_append_snapshot_chunks(
				chunk_colors,
				last_snapshot.get("processing_context_chunk_coords", []),
				COLOR_CONTEXT
			)
		_append_snapshot_chunks(
			chunk_colors,
			last_snapshot.get("candidate_chunk_coords", []),
			COLOR_WRITE
		)
		_append_snapshot_chunks(
			chunk_colors,
			last_snapshot.get("contact_chunk_coords", []),
			COLOR_CONTACT
		)
		_append_snapshot_chunks(
			chunk_colors,
			last_snapshot.get("remeshed_chunk_coords", []),
			COLOR_REMESH
		)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for chunk_coord: Vector3i in _sorted_vector3i_keys(chunk_colors):
		_append_chunk_box(
			vertices,
			colors,
			chunk_coord,
			chunk_colors[chunk_coord] as Color
		)
	var array_mesh := ArrayMesh.new()
	if not vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
		array_mesh.surface_set_material(0, _build_line_material())
	mesh = array_mesh
	rendered_chunk_count = chunk_colors.size()
	visible = rendered_chunk_count > 0


func _append_full_workspace_chunks(chunk_colors: Dictionary) -> void:
	var minimum := _world_to_chunk(workspace_bounds.position)
	var end_inclusive := workspace_bounds.end - Vector3.ONE * 0.000001
	var maximum := _world_to_chunk(end_inclusive)
	for chunk_x in range(minimum.x, maximum.x + 1):
		for chunk_y in range(minimum.y, maximum.y + 1):
			for chunk_z in range(minimum.z, maximum.z + 1):
				chunk_colors[Vector3i(chunk_x, chunk_y, chunk_z)] = (
					COLOR_FULL_WORKSPACE
				)


func _append_snapshot_chunks(
	chunk_colors: Dictionary,
	coords_variant: Variant,
	color: Color
) -> void:
	if not coords_variant is Array:
		return
	for coord_variant: Variant in coords_variant as Array:
		if coord_variant is Vector3i:
			chunk_colors[coord_variant as Vector3i] = color


func _append_chunk_box(
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	chunk_coord: Vector3i,
	color: Color
) -> void:
	var minimum := Vector3(chunk_coord) * chunk_world_size_meters
	var maximum := minimum + Vector3.ONE * chunk_world_size_meters
	var corners := [
		Vector3(minimum.x, minimum.y, minimum.z),
		Vector3(maximum.x, minimum.y, minimum.z),
		Vector3(maximum.x, maximum.y, minimum.z),
		Vector3(minimum.x, maximum.y, minimum.z),
		Vector3(minimum.x, minimum.y, maximum.z),
		Vector3(maximum.x, minimum.y, maximum.z),
		Vector3(maximum.x, maximum.y, maximum.z),
		Vector3(minimum.x, maximum.y, maximum.z),
	]
	var edge_indices := [
		0, 1, 1, 2, 2, 3, 3, 0,
		4, 5, 5, 6, 6, 7, 7, 4,
		0, 4, 1, 5, 2, 6, 3, 7,
	]
	for corner_index: int in edge_indices:
		vertices.append(corners[corner_index])
		colors.append(color)


func _world_to_chunk(world_position: Vector3) -> Vector3i:
	return Vector3i(
		floori(world_position.x / chunk_world_size_meters),
		floori(world_position.y / chunk_world_size_meters),
		floori(world_position.z / chunk_world_size_meters)
	)


func _build_line_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	return material


func _sorted_vector3i_keys(dictionary: Dictionary) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for key: Variant in dictionary.keys():
		if key is Vector3i:
			result.append(key as Vector3i)
	result.sort_custom(_vector3i_less)
	return result


func _vector3i_less(first: Vector3i, second: Vector3i) -> bool:
	if first.x != second.x:
		return first.x < second.x
	if first.y != second.y:
		return first.y < second.y
	return first.z < second.z


func _contains_collision_object(node: Node) -> bool:
	if node is CollisionObject3D:
		return true
	for child: Node in node.get_children():
		if _contains_collision_object(child):
			return true
	return false
