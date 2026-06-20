extends RefCounted
class_name Stage2EditableMeshBuilder

const Stage2EditableMeshStateScript = preload("res://core/models/stage2_editable_mesh_state.gd")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")

var material_runtime_resolver = MaterialRuntimeResolverScript.new()

func build_state_from_canonical_geometry(canonical_geometry, material_lookup: Dictionary = {}, fallback_color: Color = Color(0.8, 0.8, 0.8, 1.0)) -> Resource:
	var editable_mesh_state = Stage2EditableMeshStateScript.new()
	if canonical_geometry == null or canonical_geometry.is_empty():
		if canonical_geometry != null:
			editable_mesh_state.local_aabb_position = canonical_geometry.local_aabb.position
			editable_mesh_state.local_aabb_size = canonical_geometry.local_aabb.size
		return editable_mesh_state
	var surface_tool := SurfaceTool.new()
	var triangle_patch_keys: PackedStringArray = PackedStringArray()
	var triangle_face_ids: PackedStringArray = PackedStringArray()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for surface_quad in canonical_geometry.surface_quads:
		if surface_quad == null:
			continue
		_append_surface_quad(
			surface_tool,
			surface_quad,
			material_lookup,
			fallback_color,
			triangle_patch_keys,
			triangle_face_ids
		)
	for surface_triangle in canonical_geometry.surface_triangles:
		if surface_triangle == null:
			continue
		_append_surface_triangle(
			surface_tool,
			surface_triangle,
			material_lookup,
			fallback_color,
			triangle_patch_keys,
			triangle_face_ids
		)
	surface_tool.index()
	surface_tool.generate_normals()
	var committed_arrays: Array = surface_tool.commit_to_arrays()
	if committed_arrays.is_empty() or committed_arrays.size() <= Mesh.ARRAY_VERTEX:
		editable_mesh_state.local_aabb_position = canonical_geometry.local_aabb.position
		editable_mesh_state.local_aabb_size = canonical_geometry.local_aabb.size
		return editable_mesh_state
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, committed_arrays)
	if mesh == null or mesh.get_surface_count() <= 0:
		editable_mesh_state.local_aabb_position = canonical_geometry.local_aabb.position
		editable_mesh_state.local_aabb_size = canonical_geometry.local_aabb.size
		return editable_mesh_state
	editable_mesh_state.copy_from_surface_arrays(
		mesh.surface_get_arrays(0),
		Mesh.PRIMITIVE_TRIANGLES,
		canonical_geometry.local_aabb,
		triangle_patch_keys,
		triangle_face_ids
	)
	return editable_mesh_state

func build_array_mesh_from_state(editable_mesh_state: Resource) -> ArrayMesh:
	if editable_mesh_state == null or not editable_mesh_state.has_method("build_array_mesh"):
		return ArrayMesh.new()
	return editable_mesh_state.build_array_mesh()

func build_mesh_data_tool_from_state(editable_mesh_state: Resource) -> MeshDataTool:
	if editable_mesh_state == null or not editable_mesh_state.has_method("has_surface_arrays"):
		return null
	if not editable_mesh_state.has_surface_arrays():
		return null
	var mesh: ArrayMesh = build_array_mesh_from_state(editable_mesh_state)
	if mesh == null or mesh.get_surface_count() <= 0:
		return null
	var mesh_data_tool := MeshDataTool.new()
	var create_error: Error = mesh_data_tool.create_from_surface(mesh, 0)
	if create_error != OK:
		return null
	return mesh_data_tool

func commit_mesh_data_tool_to_state(editable_mesh_state: Resource, mesh_data_tool: MeshDataTool) -> bool:
	if editable_mesh_state == null or mesh_data_tool == null:
		return false
	_rebuild_vertex_normals(mesh_data_tool)
	var mesh := ArrayMesh.new()
	var commit_error: Error = mesh_data_tool.commit_to_surface(mesh)
	if commit_error != OK or mesh.get_surface_count() <= 0:
		return false
	if not editable_mesh_state.has_method("copy_from_surface_arrays"):
		return false
	var committed_arrays: Array = mesh.surface_get_arrays(0)
	var triangle_patch_keys: PackedStringArray = PackedStringArray(editable_mesh_state.get("triangle_patch_keys"))
	var triangle_face_ids: PackedStringArray = PackedStringArray(editable_mesh_state.get("triangle_face_ids"))
	var committed_triangle_count: int = _resolve_triangle_count_from_surface_arrays(committed_arrays)
	if committed_triangle_count <= 0 or triangle_patch_keys.size() != committed_triangle_count:
		triangle_patch_keys = PackedStringArray()
	if committed_triangle_count <= 0 or triangle_face_ids.size() != committed_triangle_count:
		triangle_face_ids = PackedStringArray()
	editable_mesh_state.copy_from_surface_arrays(
		committed_arrays,
		Mesh.PRIMITIVE_TRIANGLES,
		mesh.get_aabb(),
		triangle_patch_keys,
		triangle_face_ids
	)
	return true

func _append_surface_quad(
	surface_tool: SurfaceTool,
	surface_quad,
	material_lookup: Dictionary,
	fallback_color: Color,
	triangle_patch_keys: PackedStringArray,
	triangle_face_ids: PackedStringArray
) -> void:
	var color: Color = _resolve_material_color(surface_quad.material_variant_id, material_lookup, fallback_color)
	var width_steps: int = maxi(int(surface_quad.width_voxels), 1)
	var height_steps: int = maxi(int(surface_quad.height_voxels), 1)
	var edge_u_step: Vector3 = surface_quad.edge_u_local / float(width_steps)
	var edge_v_step: Vector3 = surface_quad.edge_v_local / float(height_steps)
	var shell_face_id: StringName = _resolve_surface_stage2_face_id(surface_quad)
	for v_index: int in range(height_steps):
		for u_index: int in range(width_steps):
			var vertex_a: Vector3 = surface_quad.origin_local + (edge_u_step * float(u_index)) + (edge_v_step * float(v_index))
			var vertex_b: Vector3 = surface_quad.origin_local + (edge_u_step * float(u_index)) + (edge_v_step * float(v_index + 1))
			var vertex_c: Vector3 = surface_quad.origin_local + (edge_u_step * float(u_index + 1)) + (edge_v_step * float(v_index + 1))
			var vertex_d: Vector3 = surface_quad.origin_local + (edge_u_step * float(u_index + 1)) + (edge_v_step * float(v_index))
			for vertex: Vector3 in [vertex_a, vertex_b, vertex_c, vertex_a, vertex_c, vertex_d]:
				surface_tool.set_color(color)
				surface_tool.add_vertex(vertex)
			var patch_key: String = _build_triangle_patch_key(shell_face_id, u_index, v_index)
			for _triangle_index in range(2):
				triangle_patch_keys.append(patch_key)
				triangle_face_ids.append(String(shell_face_id))

func _append_surface_triangle(
	surface_tool: SurfaceTool,
	surface_triangle,
	material_lookup: Dictionary,
	fallback_color: Color,
	triangle_patch_keys: PackedStringArray,
	triangle_face_ids: PackedStringArray
) -> void:
	var vertices: Array[Vector3] = surface_triangle.get_vertices()
	if vertices.size() < 3:
		return
	var color: Color = _resolve_material_color(surface_triangle.material_variant_id, material_lookup, fallback_color)
	for vertex_index: int in range(3):
		surface_tool.set_color(color)
		surface_tool.add_vertex(vertices[vertex_index])
	var face_id: StringName = _resolve_surface_stage2_face_id(surface_triangle)
	var triangle_patch_key: String = ""
	if not surface_triangle.stage2_patch_ids.is_empty():
		triangle_patch_key = String(surface_triangle.stage2_patch_ids[0])
	triangle_patch_keys.append(triangle_patch_key)
	triangle_face_ids.append(String(face_id))

func _resolve_material_color(material_variant_id: StringName, material_lookup: Dictionary, fallback_color: Color) -> Color:
	return material_runtime_resolver.resolve_material_color(
		material_variant_id,
		material_lookup,
		fallback_color
	)

func _rebuild_vertex_normals(mesh_data_tool: MeshDataTool) -> void:
	if mesh_data_tool == null:
		return
	for vertex_index: int in range(mesh_data_tool.get_vertex_count()):
		var vertex_face_indices: PackedInt32Array = mesh_data_tool.get_vertex_faces(vertex_index)
		if vertex_face_indices.is_empty():
			continue
		var accumulated_normal: Vector3 = Vector3.ZERO
		for face_index: int in vertex_face_indices:
			accumulated_normal += mesh_data_tool.get_face_normal(face_index)
		var resolved_normal: Vector3 = accumulated_normal.normalized()
		if resolved_normal == Vector3.ZERO:
			continue
		mesh_data_tool.set_vertex_normal(vertex_index, resolved_normal)

func _resolve_surface_stage2_face_id(surface_primitive) -> StringName:
	if surface_primitive == null:
		return StringName()
	if surface_primitive.stage2_shell_quad_id != StringName():
		return surface_primitive.stage2_shell_quad_id
	return surface_primitive.stage2_face_id

func _build_triangle_patch_key(shell_face_id: StringName, u_index: int, v_index: int) -> String:
	if shell_face_id == StringName():
		return ""
	return "%s::%d::%d" % [String(shell_face_id), u_index, v_index]

func _resolve_triangle_count_from_surface_arrays(surface_arrays: Array) -> int:
	if surface_arrays.is_empty() or surface_arrays.size() <= Mesh.ARRAY_VERTEX:
		return 0
	if surface_arrays.size() > Mesh.ARRAY_INDEX and surface_arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		var indices: PackedInt32Array = surface_arrays[Mesh.ARRAY_INDEX]
		if not indices.is_empty():
			return int(float(indices.size()) / 3.0)
	if surface_arrays[Mesh.ARRAY_VERTEX] is not PackedVector3Array:
		return 0
	var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
	return int(float(vertices.size()) / 3.0)
