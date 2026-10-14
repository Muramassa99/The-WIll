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

	var material_lookup: Dictionary = MaterialPipelineServiceScript.new().build_base_material_lookup()
	var forge_service: ForgeService = ForgeServiceScript.new(DEFAULT_FORGE_RULES_RESOURCE)
	var test_print: TestPrintInstance = forge_service.build_test_print_from_wip(target_wip, material_lookup, {}, {}, {}, true)
	var mesh_builder: TestPrintMeshBuilder = TestPrintMeshBuilderScript.new()
	var canonical_geometry = test_print.canonical_geometry if test_print != null else null
	var mesh: ArrayMesh = mesh_builder.build_mesh_from_test_print(test_print, material_lookup)
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
	lines.append("authoring_version=forge_v2")
	lines.append("material_volume_mix=%s" % str(test_print.baked_profile.material_volume_mix if test_print != null and test_print.baked_profile != null else {}))
	lines.append("visual_mesh_source=%s" % String(test_print.visual_mesh_source if test_print != null else StringName()))
	var saved_cell_size: float = float(target_wip.stage2_item_state.get("cell_world_size_meters")) if target_wip.stage2_item_state != null else 0.0
	lines.append("mesh_aabb_size_meters=%s" % str(mesh_aabb.size * saved_cell_size))
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

func _write_results(lines: PackedStringArray) -> void:
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(lines))
	file.close()
