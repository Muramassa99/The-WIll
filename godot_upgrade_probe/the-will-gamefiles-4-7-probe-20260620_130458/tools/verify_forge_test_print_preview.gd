extends SceneTree

const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const WOOD_MATERIAL_ID := &"mat_wood_gray"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var root_node: Node3D = Node3D.new()
	get_root().add_child(root_node)

	var controller: ForgeGridController = ForgeGridControllerScript.new()
	controller.test_print_spawn_root_path = NodePath("PreviewHost")
	var preview_host: Node3D = Node3D.new()
	preview_host.name = "PreviewHost"
	controller.add_child(preview_host)
	root_node.add_child(controller)
	await process_frame

	var wip: CraftedItemWIP = controller.load_new_blank_wip("Preview Verification Draft")
	if wip != null:
		var layer: LayerAtom = LayerAtom.new()
		layer.layer_index = 0
		layer.cells = []
		var cell: CellAtom = CellAtom.new()
		cell.grid_position = Vector3i.ZERO
		cell.layer_index = 0
		cell.material_variant_id = WOOD_MATERIAL_ID
		layer.cells.append(cell)
		wip.layers = [layer]
		controller.set_active_wip(wip)
	var material_lookup: Dictionary = controller.build_default_material_lookup()
	var test_print: TestPrintInstance = controller.spawn_test_print_from_active_wip(material_lookup)
	await process_frame

	var preview_mesh: MeshInstance3D = preview_host.get_node_or_null("ActiveTestPrintMesh") as MeshInstance3D
	var preview_mesh_valid: bool = preview_mesh != null
	var preview_mesh_visible: bool = preview_mesh != null and preview_mesh.visible
	var preview_surface_count: int = preview_mesh.mesh.get_surface_count() if preview_mesh != null and preview_mesh.mesh != null else 0
	var preview_material_override_exists: bool = preview_mesh != null and preview_mesh.material_override != null

	var lines: PackedStringArray = []
	lines.append("test_print_exists=%s" % str(test_print != null))
	lines.append("spawn_root_resolved=%s" % str(controller.test_print_spawn_root != null))
	lines.append("spawn_root_child_count=%d" % preview_host.get_child_count())
	lines.append("test_print_mesh_instance_valid=%s" % str(is_instance_valid(controller.test_print_mesh_instance)))
	lines.append("preview_mesh_exists=%s" % str(preview_mesh_valid))
	lines.append("preview_mesh_visible=%s" % str(preview_mesh_visible))
	lines.append("preview_surface_count=%d" % preview_surface_count)
	lines.append("preview_material_override_exists=%s" % str(preview_material_override_exists))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/forge_test_print_preview_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
