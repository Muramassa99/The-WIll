extends RefCounted
class_name TestPrintMeshBuilder

const DEFAULT_FORGE_VIEW_TUNING_RESOURCE: ForgeViewTuningDef = preload("res://core/defs/forge/forge_view_tuning_default.tres")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")
const Stage2EditableMeshBuilderScript = preload("res://core/resolvers/stage2_editable_mesh_builder.gd")

var forge_view_tuning: ForgeViewTuningDef = DEFAULT_FORGE_VIEW_TUNING_RESOURCE
var material_runtime_resolver = MaterialRuntimeResolverScript.new()
var editable_mesh_builder = Stage2EditableMeshBuilderScript.new()

func set_view_tuning(value: ForgeViewTuningDef) -> void:
	forge_view_tuning = value if value != null else DEFAULT_FORGE_VIEW_TUNING_RESOURCE

func build_mesh_from_canonical_geometry(canonical_geometry, material_lookup: Dictionary = {}) -> ArrayMesh:
	if canonical_geometry == null or canonical_geometry.is_empty():
		return ArrayMesh.new()
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var next_vertex_index: int = 0
	for surface_quad in canonical_geometry.surface_quads:
		if surface_quad == null:
			continue
		next_vertex_index = _append_surface_quad(
			surface_tool,
			surface_quad,
			material_lookup,
			next_vertex_index
		)
	for surface_triangle in canonical_geometry.surface_triangles:
		if surface_triangle == null:
			continue
		next_vertex_index = _append_surface_triangle(
			surface_tool,
			surface_triangle,
			material_lookup,
			next_vertex_index
		)

	if next_vertex_index == 0:
		return ArrayMesh.new()

	return surface_tool.commit()

func build_mesh_from_test_print(test_print: TestPrintInstance, _material_lookup: Dictionary = {}) -> ArrayMesh:
	if not _test_print_uses_editable_mesh_visual_source(test_print):
		return ArrayMesh.new()
	var editable_mesh_state: Resource = test_print.stage2_item_state.get("current_editable_mesh_state") as Resource
	var editable_mesh: ArrayMesh = editable_mesh_builder.build_array_mesh_from_state(editable_mesh_state)
	return editable_mesh if editable_mesh != null else ArrayMesh.new()

func _test_print_uses_editable_mesh_visual_source(test_print: TestPrintInstance) -> bool:
	if test_print == null or test_print.visual_mesh_source != &"editable_mesh":
		return false
	if test_print.stage2_item_state == null:
		return false
	return (
		test_print.stage2_item_state.has_method("has_current_editable_mesh")
		and bool(test_print.stage2_item_state.call("has_current_editable_mesh"))
	)

func build_bounds_data_from_canonical_geometry(
		canonical_geometry,
		grip_contact_position: Vector3,
		cell_world_size: float,
		padding_cells: int = 1
	) -> Dictionary:
	if canonical_geometry == null or canonical_geometry.is_empty():
		return {"center_local": Vector3.ZERO, "size_meters": Vector3.ONE * cell_world_size}
	var padded_aabb: AABB = canonical_geometry.get_padded_local_aabb(padding_cells)
	if padded_aabb.size == Vector3.ZERO:
		return {"center_local": Vector3.ZERO, "size_meters": Vector3.ONE * cell_world_size}
	var local_center_cells: Vector3 = padded_aabb.get_center() - grip_contact_position
	return {
		"center_local": local_center_cells * cell_world_size,
		"size_meters": padded_aabb.size * cell_world_size,
	}

func _append_surface_quad(
		surface_tool: SurfaceTool,
		surface_quad,
		material_lookup: Dictionary,
		start_vertex_index: int
	) -> int:
	var vertices: Array[Vector3] = surface_quad.get_vertices()
	var color: Color = _resolve_cell_color(surface_quad.material_variant_id, material_lookup)
	for vertex: Vector3 in vertices:
		surface_tool.set_color(color)
		surface_tool.set_normal(surface_quad.normal)
		surface_tool.add_vertex(vertex)
	surface_tool.add_index(start_vertex_index)
	surface_tool.add_index(start_vertex_index + 1)
	surface_tool.add_index(start_vertex_index + 2)
	surface_tool.add_index(start_vertex_index)
	surface_tool.add_index(start_vertex_index + 2)
	surface_tool.add_index(start_vertex_index + 3)
	return start_vertex_index + 4

func _append_surface_triangle(
		surface_tool: SurfaceTool,
		surface_triangle,
		material_lookup: Dictionary,
		start_vertex_index: int
	) -> int:
	var vertices: Array[Vector3] = surface_triangle.get_vertices()
	if vertices.size() < 3:
		return start_vertex_index
	var vertex_normals: Array[Vector3] = [
		surface_triangle.vertex_a_normal,
		surface_triangle.vertex_b_normal,
		surface_triangle.vertex_c_normal,
	]
	var use_vertex_normals: bool = surface_triangle.has_vertex_normals() if surface_triangle.has_method("has_vertex_normals") else false
	var color: Color = _resolve_cell_color(surface_triangle.material_variant_id, material_lookup)
	for vertex_index: int in range(vertices.size()):
		var vertex: Vector3 = vertices[vertex_index]
		surface_tool.set_color(color)
		surface_tool.set_normal(
			vertex_normals[vertex_index] if use_vertex_normals else surface_triangle.normal
		)
		surface_tool.add_vertex(vertex)
	surface_tool.add_index(start_vertex_index)
	surface_tool.add_index(start_vertex_index + 1)
	surface_tool.add_index(start_vertex_index + 2)
	return start_vertex_index + 3

func _resolve_cell_color(material_variant_id: StringName, material_lookup: Dictionary) -> Color:
	return material_runtime_resolver.resolve_material_color(
		material_variant_id,
		material_lookup,
		forge_view_tuning.test_print_fallback_color
	)
