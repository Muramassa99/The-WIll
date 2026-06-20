extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const ForgeServiceScript = preload("res://services/forge_service.gd")
const MaterialPipelineServiceScript = preload("res://services/material_pipeline_service.gd")
const TestPrintMeshBuilderScript = preload("res://runtime/forge/test_print_mesh_builder.gd")
const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")

const RESULT_FILE_PATH := "C:/WORKSPACE/extensive_testing_1_geometry_results.txt"
const TARGET_PROJECT_NAME := "Extensive testing 1."

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var target_wip: CraftedItemWIP = _find_target_wip(library)
	var lines: PackedStringArray = []
	if target_wip == null:
		lines.append("found=false")
		_write_results(lines)
		quit()
		return

	var cells: Array[CellAtom] = []
	var occupied: Dictionary = {}
	var layer_counts: Dictionary = {}
	var xz_columns: Dictionary = {}
	var yz_columns: Dictionary = {}
	var xy_columns: Dictionary = {}
	var min_pos: Vector3i = Vector3i(2147483647, 2147483647, 2147483647)
	var max_pos: Vector3i = Vector3i(-2147483648, -2147483648, -2147483648)
	var material_mix: Dictionary = {}

	for layer_atom: LayerAtom in target_wip.layers:
		if layer_atom == null:
			continue
		layer_counts[layer_atom.layer_index] = layer_atom.cells.size()
		for cell: CellAtom in layer_atom.cells:
			if cell == null:
				continue
			cells.append(cell)
			occupied[cell.grid_position] = true
			min_pos.x = mini(min_pos.x, cell.grid_position.x)
			min_pos.y = mini(min_pos.y, cell.grid_position.y)
			min_pos.z = mini(min_pos.z, cell.grid_position.z)
			max_pos.x = maxi(max_pos.x, cell.grid_position.x)
			max_pos.y = maxi(max_pos.y, cell.grid_position.y)
			max_pos.z = maxi(max_pos.z, cell.grid_position.z)
			material_mix[cell.material_variant_id] = int(material_mix.get(cell.material_variant_id, 0)) + 1
			_increment_column_count(xz_columns, "%d|%d" % [cell.grid_position.x, cell.grid_position.z])
			_increment_column_count(yz_columns, "%d|%d" % [cell.grid_position.y, cell.grid_position.z])
			_increment_column_count(xy_columns, "%d|%d" % [cell.grid_position.x, cell.grid_position.y])

	var single_y_columns: int = _count_columns_with_value(xz_columns, 1)
	var single_x_columns: int = _count_columns_with_value(yz_columns, 1)
	var single_z_columns: int = _count_columns_with_value(xy_columns, 1)
	var exposed_faces: int = _count_exposed_faces(occupied)
	var total_possible_faces: int = cells.size() * 6

	var material_lookup: Dictionary = MaterialPipelineServiceScript.new().build_base_material_lookup()
	var forge_service: ForgeService = ForgeServiceScript.new(DEFAULT_FORGE_RULES_RESOURCE)
	var test_print: TestPrintInstance = forge_service.build_test_print_from_wip(target_wip, material_lookup)
	var mesh_builder: TestPrintMeshBuilder = TestPrintMeshBuilderScript.new()
	var canonical_solid = test_print.canonical_solid if test_print != null else null
	var canonical_geometry = test_print.canonical_geometry if test_print != null else null
	var mesh: ArrayMesh = mesh_builder.build_mesh_from_canonical_geometry(canonical_geometry, material_lookup)
	var mesh_aabb: AABB = mesh.get_aabb() if mesh != null else AABB()
	var mesh_vertex_count: int = 0
	var mesh_triangle_count: int = 0
	if mesh != null and mesh.get_surface_count() > 0:
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		mesh_vertex_count = vertices.size()
		mesh_triangle_count = indices.size() / 3 if not indices.is_empty() else vertices.size() / 3

	lines.append("found=true")
	lines.append("wip_id=%s" % String(target_wip.wip_id))
	lines.append("project_name=%s" % target_wip.forge_project_name)
	lines.append("cell_count=%d" % cells.size())
	lines.append("layer_count=%d" % target_wip.layers.size())
	lines.append("layer_indices=%s" % str(layer_counts.keys()))
	lines.append("layer_cell_counts=%s" % str(layer_counts))
	lines.append("min_grid=%s" % str(min_pos))
	lines.append("max_grid=%s" % str(max_pos))
	lines.append("grid_span=%s" % str(max_pos - min_pos + Vector3i.ONE))
	lines.append("material_mix=%s" % str(material_mix))
	lines.append("single_cell_y_columns=%d" % single_y_columns)
	lines.append("single_cell_x_columns=%d" % single_x_columns)
	lines.append("single_cell_z_columns=%d" % single_z_columns)
	lines.append("xz_column_count=%d" % xz_columns.size())
	lines.append("yz_column_count=%d" % yz_columns.size())
	lines.append("xy_column_count=%d" % xy_columns.size())
	lines.append("exposed_faces=%d" % exposed_faces)
	lines.append("total_possible_faces=%d" % total_possible_faces)
	lines.append("exposed_face_ratio=%0.4f" % (float(exposed_faces) / float(maxi(total_possible_faces, 1))))
	lines.append("canonical_solid_cell_count=%d" % (canonical_solid.get_cell_count() if canonical_solid != null else 0))
	lines.append("canonical_geometry_quad_count=%d" % (canonical_geometry.get_quad_count() if canonical_geometry != null else 0))
	lines.append("mesh_surface_count=%d" % (mesh.get_surface_count() if mesh != null else 0))
	lines.append("mesh_vertex_count=%d" % mesh_vertex_count)
	lines.append("mesh_triangle_count=%d" % mesh_triangle_count)
	lines.append("mesh_aabb_size=%s" % str(mesh_aabb.size))

	_write_results(lines)
	quit()

func _find_target_wip(library: PlayerForgeWipLibraryState) -> CraftedItemWIP:
	if library == null:
		return null
	for saved_wip: CraftedItemWIP in library.get_saved_wips():
		if saved_wip == null:
			continue
		if saved_wip.forge_project_name == TARGET_PROJECT_NAME:
			return saved_wip
	return null

func _increment_column_count(lookup: Dictionary, key: String) -> void:
	lookup[key] = int(lookup.get(key, 0)) + 1

func _count_columns_with_value(lookup: Dictionary, expected: int) -> int:
	var count: int = 0
	for key in lookup.keys():
		if int(lookup[key]) == expected:
			count += 1
	return count

func _count_exposed_faces(occupied: Dictionary) -> int:
	var count: int = 0
	var directions: Array[Vector3i] = [
		Vector3i.RIGHT,
		Vector3i.LEFT,
		Vector3i.UP,
		Vector3i.DOWN,
		Vector3i.FORWARD,
		Vector3i.BACK
	]
	for grid_position_variant in occupied.keys():
		var grid_position: Vector3i = grid_position_variant
		for direction: Vector3i in directions:
			if not occupied.has(grid_position + direction):
				count += 1
	return count

func _write_results(lines: PackedStringArray) -> void:
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(lines))
	file.close()
