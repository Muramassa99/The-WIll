extends SceneTree

const TestPrintMeshBuilderScript = preload("res://runtime/forge/test_print_mesh_builder.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/crafted_item_mesh_foundation_results.txt"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var builder: TestPrintMeshBuilder = TestPrintMeshBuilderScript.new()
	var line_cells: Array[CellAtom] = _build_cells([
		Vector3i(0, 0, 0),
		Vector3i(1, 0, 0)
	])
	var box_cells: Array[CellAtom] = _build_box_cells(Vector3i(2, 2, 2))

	var line_solid = builder.build_canonical_solid(line_cells)
	var box_solid = builder.build_canonical_solid(box_cells)
	var line_geometry = builder.build_canonical_geometry(line_solid)
	var box_geometry = builder.build_canonical_geometry(box_solid)
	var line_mesh: ArrayMesh = builder.build_mesh_from_canonical_geometry(line_geometry)
	var box_mesh: ArrayMesh = builder.build_mesh_from_canonical_geometry(box_geometry)

	var line_stats: Dictionary = _resolve_mesh_stats(line_mesh)
	var box_stats: Dictionary = _resolve_mesh_stats(box_mesh)

	var lines: PackedStringArray = []
	lines.append("line_solid_cell_count=%d" % line_solid.get_cell_count())
	lines.append("line_solid_aabb_size=%s" % str(line_solid.get_local_aabb().size))
	lines.append("line_geometry_quad_count=%d" % line_geometry.get_quad_count())
	lines.append("line_surface_count=%d" % int(line_stats.get("surface_count", 0)))
	lines.append("line_vertex_count=%d" % int(line_stats.get("vertex_count", 0)))
	lines.append("line_triangle_count=%d" % int(line_stats.get("triangle_count", 0)))
	lines.append("line_aabb_size=%s" % str(line_mesh.get_aabb().size))
	lines.append("line_canonical_solid_valid=%s" % str(
		line_solid != null
		and line_solid.get_cell_count() == 2
		and line_solid.get_local_aabb().size.is_equal_approx(Vector3(2.0, 1.0, 1.0))
	))
	lines.append("line_canonical_geometry_valid=%s" % str(
		line_geometry != null
		and line_geometry.get_quad_count() == 6
		and line_geometry.local_aabb.size.is_equal_approx(Vector3(2.0, 1.0, 1.0))
	))
	lines.append("line_matches_box_hull=%s" % str(
		int(line_stats.get("vertex_count", 0)) == 24
		and int(line_stats.get("triangle_count", 0)) == 12
		and line_mesh.get_aabb().size.is_equal_approx(Vector3(2.0, 1.0, 1.0))
	))
	lines.append("box_solid_cell_count=%d" % box_solid.get_cell_count())
	lines.append("box_solid_aabb_size=%s" % str(box_solid.get_local_aabb().size))
	lines.append("box_geometry_quad_count=%d" % box_geometry.get_quad_count())
	lines.append("box_surface_count=%d" % int(box_stats.get("surface_count", 0)))
	lines.append("box_vertex_count=%d" % int(box_stats.get("vertex_count", 0)))
	lines.append("box_triangle_count=%d" % int(box_stats.get("triangle_count", 0)))
	lines.append("box_aabb_size=%s" % str(box_mesh.get_aabb().size))
	lines.append("box_canonical_solid_valid=%s" % str(
		box_solid != null
		and box_solid.get_cell_count() == 8
		and box_solid.get_local_aabb().size.is_equal_approx(Vector3(2.0, 2.0, 2.0))
	))
	lines.append("box_canonical_geometry_valid=%s" % str(
		box_geometry != null
		and box_geometry.get_quad_count() == 6
		and box_geometry.local_aabb.size.is_equal_approx(Vector3(2.0, 2.0, 2.0))
	))
	lines.append("box_matches_box_hull=%s" % str(
		int(box_stats.get("vertex_count", 0)) == 24
		and int(box_stats.get("triangle_count", 0)) == 12
		and box_mesh.get_aabb().size.is_equal_approx(Vector3(2.0, 2.0, 2.0))
	))

	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _build_cells(grid_positions: Array[Vector3i]) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	for grid_position: Vector3i in grid_positions:
		var cell := CellAtom.new()
		cell.grid_position = grid_position
		cell.layer_index = grid_position.z
		cell.material_variant_id = &"mat_iron_gray"
		cells.append(cell)
	return cells

func _build_box_cells(size: Vector3i) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	for z: int in range(size.z):
		for y: int in range(size.y):
			for x: int in range(size.x):
				var cell := CellAtom.new()
				cell.grid_position = Vector3i(x, y, z)
				cell.layer_index = z
				cell.material_variant_id = &"mat_iron_gray"
				cells.append(cell)
	return cells

func _resolve_mesh_stats(mesh: ArrayMesh) -> Dictionary:
	if mesh == null or mesh.get_surface_count() == 0:
		return {"surface_count": 0, "vertex_count": 0, "triangle_count": 0}
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var triangle_count: int = 0
	if not indices.is_empty():
		triangle_count = indices.size() / 3
	else:
		triangle_count = vertices.size() / 3
	return {
		"surface_count": mesh.get_surface_count(),
		"vertex_count": vertices.size(),
		"triangle_count": triangle_count
	}
