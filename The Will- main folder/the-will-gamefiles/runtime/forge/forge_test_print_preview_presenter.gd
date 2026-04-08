extends RefCounted
class_name ForgeTestPrintPreviewPresenter

func ensure_test_print_mesh_instance(
	test_print_spawn_root: Node3D,
	test_print_mesh_instance: MeshInstance3D,
	material_override: Material
) -> MeshInstance3D:
	if test_print_spawn_root == null:
		return test_print_mesh_instance
	if is_instance_valid(test_print_mesh_instance):
		if material_override != null:
			test_print_mesh_instance.material_override = material_override
		return test_print_mesh_instance

	var new_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	new_mesh_instance.name = "ActiveTestPrintMesh"
	new_mesh_instance.material_override = material_override
	new_mesh_instance.visible = false
	test_print_spawn_root.add_child(new_mesh_instance)
	return new_mesh_instance

func sync_spawned_test_print_mesh(
	test_print_spawn_root: Node3D,
	test_print_mesh_instance: MeshInstance3D,
	active_test_print: TestPrintInstance,
	test_print_mesh_builder: TestPrintMeshBuilder,
	material_lookup: Dictionary
) -> MeshInstance3D:
	if test_print_spawn_root == null or not is_instance_valid(test_print_mesh_instance):
		return test_print_mesh_instance

	if active_test_print == null:
		test_print_mesh_instance.mesh = null
		test_print_mesh_instance.position = Vector3.ZERO
		test_print_mesh_instance.visible = false
		return test_print_mesh_instance

	var canonical_solid = active_test_print.canonical_solid if active_test_print.canonical_solid != null else test_print_mesh_builder.build_canonical_solid(active_test_print.display_cells)
	var canonical_geometry = active_test_print.canonical_geometry if active_test_print.canonical_geometry != null else test_print_mesh_builder.build_canonical_geometry(canonical_solid)
	var mesh: ArrayMesh = test_print_mesh_builder.build_mesh_from_canonical_geometry(canonical_geometry, material_lookup)
	if mesh == null or mesh.get_surface_count() == 0:
		test_print_mesh_instance.mesh = null
		test_print_mesh_instance.position = Vector3.ZERO
		test_print_mesh_instance.visible = false
		return test_print_mesh_instance

	test_print_mesh_instance.mesh = mesh
	test_print_mesh_instance.position = -canonical_geometry.get_local_center() if canonical_geometry != null else -mesh.get_aabb().get_center()
	test_print_mesh_instance.visible = true
	return test_print_mesh_instance

func build_test_print_material(forge_view_tuning: ForgeViewTuningDef) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = forge_view_tuning.test_print_material_roughness
	material.metallic = forge_view_tuning.test_print_material_metallic
	return material
