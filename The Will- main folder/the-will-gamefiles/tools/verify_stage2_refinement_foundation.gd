extends SceneTree

const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const Stage2EditableMeshBuilderScript = preload("res://core/resolvers/stage2_editable_mesh_builder.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/stage2_refinement_foundation_results.txt"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller: ForgeGridController = ForgeGridControllerScript.new()
	controller.load_new_blank_wip_for_builder_path("Stage2 Foundation Test", CraftedItemWIP.BUILDER_PATH_MELEE)
	_seed_cells(controller)

	var stage2_item_state = controller.ensure_stage2_item_state_for_active_wip()
	var editable_mesh_builder = Stage2EditableMeshBuilderScript.new()
	var material_lookup: Dictionary = controller.build_default_material_lookup()
	var test_print: TestPrintInstance = controller.spawn_test_print_from_active_wip(material_lookup)
	var unified_shell_quad_count: int = stage2_item_state.get_unified_shell_quad_count() if stage2_item_state != null else 0
	var patch_count: int = stage2_item_state.get_patch_count() if stage2_item_state != null else 0
	var editable_mesh_state: Resource = stage2_item_state.current_editable_mesh_state if stage2_item_state != null else null
	var editable_mesh_data_tool: MeshDataTool = editable_mesh_builder.build_mesh_data_tool_from_state(editable_mesh_state)

	var lines: PackedStringArray = []
	lines.append("stage2_initialized=%s" % str(stage2_item_state != null and stage2_item_state.refinement_initialized))
	lines.append("stage2_patch_count=%d" % patch_count)
	lines.append("stage2_unified_shell_quad_count=%d" % unified_shell_quad_count)
	lines.append("stage2_unified_shell_simpler_than_patch_grid=%s" % str(
		stage2_item_state != null
		and unified_shell_quad_count > 0
		and unified_shell_quad_count < patch_count
	))
	lines.append("stage2_source_cell_count=%d" % (stage2_item_state.source_stage1_cell_count if stage2_item_state != null else 0))
	lines.append("stage2_current_aabb_size=%s" % str(stage2_item_state.current_local_aabb_size if stage2_item_state != null else Vector3.ZERO))
	lines.append("stage2_editable_mesh_exists=%s" % str(stage2_item_state != null and stage2_item_state.has_current_editable_mesh()))
	lines.append("stage2_editable_mesh_vertex_count=%d" % (
		editable_mesh_state.get_vertex_count()
		if editable_mesh_state != null and editable_mesh_state.has_method("get_vertex_count")
		else 0
	))
	lines.append("stage2_editable_mesh_index_count=%d" % (
		editable_mesh_state.get_index_count()
		if editable_mesh_state != null and editable_mesh_state.has_method("get_index_count")
		else 0
	))
	lines.append("stage2_editable_mesh_meshdatatool_ready=%s" % str(editable_mesh_data_tool != null))
	lines.append("stage2_has_positive_patch_depth=%s" % str(_has_positive_patch_depth(stage2_item_state)))
	lines.append("stage2_has_positive_envelope=%s" % str(_has_positive_patch_envelope(stage2_item_state)))
	lines.append("test_print_exists=%s" % str(test_print != null))
	lines.append("test_print_stage2_exists=%s" % str(test_print != null and test_print.stage2_item_state != null))
	lines.append("test_print_uses_stage2_geometry=%s" % str(
		test_print != null
		and test_print.stage2_item_state != null
		and test_print.canonical_geometry != null
		and test_print.stage2_item_state.get_unified_shell_quad_count() == test_print.canonical_geometry.get_quad_count()
	))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	controller.free()
	quit()

func _seed_cells(controller: ForgeGridController) -> void:
	for z: int in range(2):
		for y: int in range(2):
			for x: int in range(4):
				controller.set_material_at(Vector3i(x, y, z), &"mat_iron_gray")

func _has_positive_patch_depth(stage2_item_state) -> bool:
	if stage2_item_state == null:
		return false
	for patch_state in stage2_item_state.patch_states:
		if patch_state != null and patch_state.min_surface_depth_voxels > 0:
			return true
	return false

func _has_positive_patch_envelope(stage2_item_state) -> bool:
	if stage2_item_state == null:
		return false
	for patch_state in stage2_item_state.patch_states:
		if patch_state != null and patch_state.max_inward_offset_meters > 0.0:
			return true
	return false
