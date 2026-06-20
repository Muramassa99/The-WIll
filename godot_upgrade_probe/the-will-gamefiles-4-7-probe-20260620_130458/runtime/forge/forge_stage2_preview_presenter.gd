extends RefCounted
class_name ForgeStage2PreviewPresenter

const Stage2EditableMeshBuilderScript = preload("res://core/resolvers/stage2_editable_mesh_builder.gd")

var editable_mesh_builder = Stage2EditableMeshBuilderScript.new()

func sync_stage2_shell_preview(
	stage2_shell_instance: MeshInstance3D,
	stage2_item_state: Resource,
	test_print_mesh_builder: TestPrintMeshBuilder,
	material_lookup: Dictionary,
	grid_size: Vector3i,
	cell_world_size: float,
	view_tuning: ForgeViewTuningDef,
	stage2_visible: bool
) -> StringName:
	if stage2_shell_instance == null:
		return StringName()
	if not stage2_visible or stage2_item_state == null or not stage2_item_state.has_current_shell() or test_print_mesh_builder == null:
		stage2_shell_instance.visible = false
		stage2_shell_instance.mesh = null
		return StringName()
	var preview_source: StringName = StringName()
	var stage2_mesh: ArrayMesh = ArrayMesh.new()
	if _can_use_editable_mesh_preview(stage2_item_state):
		var editable_mesh_state: Resource = stage2_item_state.get("current_editable_mesh_state") as Resource
		stage2_mesh = editable_mesh_builder.build_array_mesh_from_state(editable_mesh_state)
		if stage2_mesh != null and stage2_mesh.get_surface_count() > 0:
			preview_source = &"editable_mesh"
	if preview_source == StringName():
		var canonical_geometry = stage2_item_state.build_current_canonical_geometry()
		if canonical_geometry == null or canonical_geometry.is_empty():
			stage2_shell_instance.visible = false
			stage2_shell_instance.mesh = null
			return StringName()
		stage2_mesh = test_print_mesh_builder.build_mesh_from_canonical_geometry(canonical_geometry, material_lookup)
		if stage2_mesh == null or stage2_mesh.get_surface_count() <= 0:
			stage2_shell_instance.visible = false
			stage2_shell_instance.mesh = null
			return StringName()
		preview_source = &"canonical_geometry"
	if stage2_mesh == null or stage2_mesh.get_surface_count() <= 0:
		stage2_shell_instance.visible = false
		stage2_shell_instance.mesh = null
		return StringName()
	stage2_shell_instance.mesh = stage2_mesh
	stage2_shell_instance.material_override = _build_stage2_shell_material(view_tuning)
	stage2_shell_instance.scale = Vector3.ONE * cell_world_size
	stage2_shell_instance.position = _resolve_grid_origin_offset(grid_size, cell_world_size)
	stage2_shell_instance.visible = true
	return preview_source

func sync_stage2_brush_preview(
	stage2_brush_instance: MeshInstance3D,
	stage2_visible: bool,
	hit_point_local: Variant,
	brush_radius_meters: float,
	blocked: bool,
	grid_size: Vector3i,
	cell_world_size: float,
	view_tuning: ForgeViewTuningDef
) -> void:
	if stage2_brush_instance == null:
		return
	if not stage2_visible or hit_point_local is not Vector3:
		stage2_brush_instance.visible = false
		return
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = brush_radius_meters
	sphere_mesh.height = brush_radius_meters * 2.0
	sphere_mesh.radial_segments = 18
	sphere_mesh.rings = 10
	stage2_brush_instance.mesh = sphere_mesh
	stage2_brush_instance.material_override = _build_stage2_brush_material(view_tuning, blocked)
	stage2_brush_instance.scale = Vector3.ONE
	stage2_brush_instance.position = _canonical_local_to_preview_local(hit_point_local, grid_size, cell_world_size)
	stage2_brush_instance.visible = true

func sync_stage2_selection_preview(
	stage2_hover_face_instance: MeshInstance3D,
	stage2_selected_faces_instance: MeshInstance3D,
	stage2_item_state: Resource,
	hovered_face_ids: PackedStringArray,
	selected_face_ids: PackedStringArray,
	hovered_patch_ids: PackedStringArray,
	selected_patch_ids: PackedStringArray,
	test_print_mesh_builder: TestPrintMeshBuilder,
	grid_size: Vector3i,
	cell_world_size: float,
	view_tuning: ForgeViewTuningDef,
	stage2_visible: bool,
	selection_target_kind: StringName = StringName()
) -> void:
	_sync_stage2_selection_mesh_instance(
		stage2_hover_face_instance,
		stage2_item_state,
		hovered_face_ids,
		hovered_patch_ids,
		test_print_mesh_builder,
		grid_size,
		cell_world_size,
		view_tuning.workspace_stage2_hover_face_color,
		stage2_visible,
		selection_target_kind
	)
	_sync_stage2_selection_mesh_instance(
		stage2_selected_faces_instance,
		stage2_item_state,
		selected_face_ids,
		selected_patch_ids,
		test_print_mesh_builder,
		grid_size,
		cell_world_size,
		view_tuning.workspace_stage2_selected_face_color,
		stage2_visible,
		selection_target_kind
	)

func resolve_stage2_brush_hit(
	camera: Camera3D,
	screen_position: Vector2,
	stage2_item_state: Resource,
	grid_size: Vector3i,
	cell_world_size: float,
	preview_owner: Node3D
) -> Dictionary:
	if camera == null or stage2_item_state == null or not stage2_item_state.has_current_shell() or preview_owner == null:
		return {}
	var ray_origin_world: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction_world: Vector3 = camera.project_ray_normal(screen_position).normalized()
	var ray_origin_local: Vector3 = preview_owner.to_local(ray_origin_world)
	var ray_direction_local: Vector3 = (preview_owner.global_transform.basis.inverse() * ray_direction_world).normalized()
	if _can_use_editable_mesh_preview(stage2_item_state):
		var editable_mesh_hit: Dictionary = _resolve_stage2_brush_hit_from_editable_mesh(
			ray_origin_local,
			ray_direction_local,
			stage2_item_state,
			grid_size,
			cell_world_size
		)
		if not editable_mesh_hit.is_empty():
			return editable_mesh_hit
	var canonical_geometry = stage2_item_state.build_current_canonical_geometry()
	if canonical_geometry == null or canonical_geometry.is_empty():
		return {}
	var best_hit_distance: float = INF
	var best_hit_point_preview_local: Vector3 = Vector3.ZERO
	var best_hit_point_canonical_local: Vector3 = Vector3.ZERO
	var best_hit_primitive_type: StringName = StringName()
	for surface_quad in canonical_geometry.surface_quads:
		if surface_quad == null:
			continue
		var hit_data: Dictionary = _intersect_surface_quad(
			ray_origin_local,
			ray_direction_local,
			surface_quad,
			grid_size,
			cell_world_size
		)
		if hit_data.is_empty():
			continue
		var hit_distance: float = float(hit_data.get("hit_distance", INF))
		if hit_distance >= best_hit_distance:
			continue
		best_hit_distance = hit_distance
		best_hit_point_preview_local = hit_data.get("hit_point_preview_local", Vector3.ZERO)
		best_hit_point_canonical_local = hit_data.get("hit_point_canonical_local", Vector3.ZERO)
		best_hit_primitive_type = &"quad"
	for surface_triangle in canonical_geometry.surface_triangles:
		if surface_triangle == null:
			continue
		var hit_data: Dictionary = _intersect_surface_triangle(
			ray_origin_local,
			ray_direction_local,
			surface_triangle,
			grid_size,
			cell_world_size
		)
		if hit_data.is_empty():
			continue
		var hit_distance: float = float(hit_data.get("hit_distance", INF))
		if hit_distance >= best_hit_distance:
			continue
		best_hit_distance = hit_distance
		best_hit_point_preview_local = hit_data.get("hit_point_preview_local", Vector3.ZERO)
		best_hit_point_canonical_local = hit_data.get("hit_point_canonical_local", Vector3.ZERO)
		best_hit_primitive_type = &"triangle"
	if best_hit_distance == INF:
		return {}
	var nearest_patch_state: Resource = _resolve_nearest_patch_state(stage2_item_state, best_hit_point_canonical_local)
	var resolved_face_id: StringName = nearest_patch_state.shell_quad_id if nearest_patch_state != null else StringName()
	return {
		"hit_point_preview_local": best_hit_point_preview_local,
		"hit_point_canonical_local": best_hit_point_canonical_local,
		"ray_direction_canonical_local": ray_direction_local,
		"hit_distance": best_hit_distance,
		"patch_id": nearest_patch_state.patch_id if nearest_patch_state != null else StringName(),
		"zone_mask_id": nearest_patch_state.zone_mask_id if nearest_patch_state != null else StringName(),
		"face_id": resolved_face_id,
		"target_kind": &"surface_face" if resolved_face_id != StringName() else StringName(),
		"primitive_type": best_hit_primitive_type,
		"mesh_source": &"canonical_geometry",
	}

func _can_use_editable_mesh_preview(stage2_item_state: Resource) -> bool:
	return (
		stage2_item_state != null
		and stage2_item_state.has_method("has_current_editable_mesh")
		and bool(stage2_item_state.call("has_current_editable_mesh"))
		and bool(stage2_item_state.get("editable_mesh_visual_authority"))
	)

func _resolve_stage2_brush_hit_from_editable_mesh(
	ray_origin_local: Vector3,
	ray_direction_local: Vector3,
	stage2_item_state: Resource,
	grid_size: Vector3i,
	cell_world_size: float
) -> Dictionary:
	if stage2_item_state == null:
		return {}
	var editable_mesh_state: Resource = stage2_item_state.get("current_editable_mesh_state") as Resource
	if editable_mesh_state == null or not editable_mesh_state.has_method("has_surface_arrays"):
		return {}
	if not editable_mesh_state.has_surface_arrays():
		return {}
	var surface_arrays: Array = editable_mesh_state.get("surface_arrays") as Array
	if surface_arrays.size() <= Mesh.ARRAY_VERTEX or surface_arrays[Mesh.ARRAY_VERTEX] is not PackedVector3Array:
		return {}
	var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return {}
	var indices: PackedInt32Array = PackedInt32Array()
	if surface_arrays.size() > Mesh.ARRAY_INDEX and surface_arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		indices = surface_arrays[Mesh.ARRAY_INDEX]
	var best_hit_distance: float = INF
	var best_hit_point_preview_local: Vector3 = Vector3.ZERO
	var best_hit_point_canonical_local: Vector3 = Vector3.ZERO
	var best_hit_triangle_index: int = -1
	if indices.is_empty():
		var editable_triangle_index: int = 0
		for vertex_index: int in range(0, vertices.size() - 2, 3):
			var hit_data: Dictionary = _intersect_surface_triangle_vertices(
				ray_origin_local,
				ray_direction_local,
				vertices[vertex_index],
				vertices[vertex_index + 1],
				vertices[vertex_index + 2],
				grid_size,
				cell_world_size
			)
			if hit_data.is_empty():
				editable_triangle_index += 1
				continue
			var hit_distance: float = float(hit_data.get("hit_distance", INF))
			if hit_distance >= best_hit_distance:
				editable_triangle_index += 1
				continue
			best_hit_distance = hit_distance
			best_hit_point_preview_local = hit_data.get("hit_point_preview_local", Vector3.ZERO)
			best_hit_point_canonical_local = hit_data.get("hit_point_canonical_local", Vector3.ZERO)
			best_hit_triangle_index = editable_triangle_index
			editable_triangle_index += 1
	else:
		var editable_triangle_index: int = 0
		for index_offset: int in range(0, indices.size() - 2, 3):
			var triangle_index_a: int = indices[index_offset]
			var triangle_index_b: int = indices[index_offset + 1]
			var triangle_index_c: int = indices[index_offset + 2]
			if (
				triangle_index_a < 0 or triangle_index_a >= vertices.size()
				or triangle_index_b < 0 or triangle_index_b >= vertices.size()
				or triangle_index_c < 0 or triangle_index_c >= vertices.size()
			):
				editable_triangle_index += 1
				continue
			var hit_data: Dictionary = _intersect_surface_triangle_vertices(
				ray_origin_local,
				ray_direction_local,
				vertices[triangle_index_a],
				vertices[triangle_index_b],
				vertices[triangle_index_c],
				grid_size,
				cell_world_size
			)
			if hit_data.is_empty():
				editable_triangle_index += 1
				continue
			var hit_distance: float = float(hit_data.get("hit_distance", INF))
			if hit_distance >= best_hit_distance:
				editable_triangle_index += 1
				continue
			best_hit_distance = hit_distance
			best_hit_point_preview_local = hit_data.get("hit_point_preview_local", Vector3.ZERO)
			best_hit_point_canonical_local = hit_data.get("hit_point_canonical_local", Vector3.ZERO)
			best_hit_triangle_index = editable_triangle_index
			editable_triangle_index += 1
	if best_hit_distance == INF:
		return {}
	var resolved_hit_target: Dictionary = {}
	if stage2_item_state.has_method("resolve_editable_mesh_hit_target"):
		resolved_hit_target = stage2_item_state.call(
			"resolve_editable_mesh_hit_target",
			best_hit_triangle_index,
			best_hit_point_canonical_local
		)
	var nearest_patch_state: Resource = resolved_hit_target.get("patch_state", null)
	if nearest_patch_state == null:
		nearest_patch_state = _resolve_nearest_patch_state(stage2_item_state, best_hit_point_canonical_local)
	var resolved_face_id: StringName = StringName(resolved_hit_target.get("face_id", StringName()))
	if resolved_face_id == StringName() and nearest_patch_state != null:
		resolved_face_id = nearest_patch_state.shell_quad_id
	return {
		"hit_point_preview_local": best_hit_point_preview_local,
		"hit_point_canonical_local": best_hit_point_canonical_local,
		"ray_direction_canonical_local": ray_direction_local,
		"hit_distance": best_hit_distance,
		"patch_id": resolved_hit_target.get("patch_id", nearest_patch_state.patch_id if nearest_patch_state != null else StringName()),
		"zone_mask_id": resolved_hit_target.get("zone_mask_id", nearest_patch_state.zone_mask_id if nearest_patch_state != null else StringName()),
		"face_id": resolved_face_id,
		"target_kind": &"surface_face" if resolved_face_id != StringName() else StringName(),
		"primitive_type": &"editable_triangle",
		"mesh_source": &"editable_mesh",
	}

func _intersect_surface_quad(
	ray_origin_local: Vector3,
	ray_direction_local: Vector3,
	surface_quad,
	grid_size: Vector3i,
	cell_world_size: float
) -> Dictionary:
	var vertices: Array[Vector3] = surface_quad.get_vertices()
	if vertices.size() < 4:
		return {}
	var hit_data_a: Dictionary = _intersect_surface_triangle_vertices(
		ray_origin_local,
		ray_direction_local,
		vertices[0],
		vertices[1],
		vertices[2],
		grid_size,
		cell_world_size
	)
	var hit_data_b: Dictionary = _intersect_surface_triangle_vertices(
		ray_origin_local,
		ray_direction_local,
		vertices[0],
		vertices[2],
		vertices[3],
		grid_size,
		cell_world_size
	)
	if hit_data_a.is_empty():
		return hit_data_b
	if hit_data_b.is_empty():
		return hit_data_a
	return hit_data_a if float(hit_data_a.get("hit_distance", INF)) <= float(hit_data_b.get("hit_distance", INF)) else hit_data_b

func _intersect_surface_triangle(
	ray_origin_local: Vector3,
	ray_direction_local: Vector3,
	surface_triangle,
	grid_size: Vector3i,
	cell_world_size: float
) -> Dictionary:
	var vertices: Array[Vector3] = surface_triangle.get_vertices()
	if vertices.size() < 3:
		return {}
	return _intersect_surface_triangle_vertices(
		ray_origin_local,
		ray_direction_local,
		vertices[0],
		vertices[1],
		vertices[2],
		grid_size,
		cell_world_size
	)

func _intersect_surface_triangle_vertices(
	ray_origin_local: Vector3,
	ray_direction_local: Vector3,
	vertex_a_canonical_local: Vector3,
	vertex_b_canonical_local: Vector3,
	vertex_c_canonical_local: Vector3,
	grid_size: Vector3i,
	cell_world_size: float
) -> Dictionary:
	var vertex_a_preview_local: Vector3 = _canonical_local_to_preview_local(vertex_a_canonical_local, grid_size, cell_world_size)
	var vertex_b_preview_local: Vector3 = _canonical_local_to_preview_local(vertex_b_canonical_local, grid_size, cell_world_size)
	var vertex_c_preview_local: Vector3 = _canonical_local_to_preview_local(vertex_c_canonical_local, grid_size, cell_world_size)
	var edge_ab: Vector3 = vertex_b_preview_local - vertex_a_preview_local
	var edge_ac: Vector3 = vertex_c_preview_local - vertex_a_preview_local
	var triangle_normal_preview_local: Vector3 = edge_ab.cross(edge_ac).normalized()
	if triangle_normal_preview_local == Vector3.ZERO:
		return {}
	var denominator: float = ray_direction_local.dot(triangle_normal_preview_local)
	if absf(denominator) <= 0.00001:
		return {}
	var hit_distance: float = (vertex_a_preview_local - ray_origin_local).dot(triangle_normal_preview_local) / denominator
	if hit_distance < 0.0:
		return {}
	var hit_point_preview_local: Vector3 = ray_origin_local + (ray_direction_local * hit_distance)
	var barycentric_coords: Vector3 = Geometry3D.get_triangle_barycentric_coords(
		hit_point_preview_local,
		vertex_a_preview_local,
		vertex_b_preview_local,
		vertex_c_preview_local
	)
	if barycentric_coords == Vector3.INF:
		return {}
	if barycentric_coords.x < -0.0001 or barycentric_coords.y < -0.0001 or barycentric_coords.z < -0.0001:
		return {}
	return {
		"hit_distance": hit_distance,
		"hit_point_preview_local": hit_point_preview_local,
		"hit_point_canonical_local": (
			(vertex_a_canonical_local * barycentric_coords.x)
			+ (vertex_b_canonical_local * barycentric_coords.y)
			+ (vertex_c_canonical_local * barycentric_coords.z)
		),
	}

func _resolve_nearest_patch_state(stage2_item_state: Resource, hit_point_canonical_local: Vector3) -> Resource:
	if stage2_item_state == null:
		return null
	var best_patch_state: Resource = null
	var best_patch_distance: float = INF
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null or not patch_state.has_current_quad():
			continue
		var patch_center: Vector3 = _get_surface_quad_center(patch_state.current_quad.build_canonical_surface_quad())
		var patch_distance: float = patch_center.distance_to(hit_point_canonical_local)
		if patch_distance >= best_patch_distance:
			continue
		best_patch_distance = patch_distance
		best_patch_state = patch_state
	return best_patch_state

func _get_surface_quad_center(surface_quad) -> Vector3:
	if surface_quad == null:
		return Vector3.ZERO
	var vertices: Array[Vector3] = surface_quad.get_vertices()
	if vertices.is_empty():
		return Vector3.ZERO
	var center_point: Vector3 = Vector3.ZERO
	for vertex: Vector3 in vertices:
		center_point += vertex
	return center_point / float(vertices.size())

func _build_stage2_shell_material(view_tuning: ForgeViewTuningDef) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = view_tuning.test_print_material_roughness
	material.metallic = view_tuning.test_print_material_metallic
	return material

func _build_stage2_brush_material(view_tuning: ForgeViewTuningDef, blocked: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = (
		view_tuning.workspace_stage2_blocked_brush_color
		if blocked
		else view_tuning.workspace_stage2_brush_color
	)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _sync_stage2_selection_mesh_instance(
	target_instance: MeshInstance3D,
	stage2_item_state: Resource,
	face_ids: PackedStringArray,
	patch_ids: PackedStringArray,
	test_print_mesh_builder: TestPrintMeshBuilder,
	grid_size: Vector3i,
	cell_world_size: float,
	preview_color: Color,
	stage2_visible: bool,
	selection_target_kind: StringName = StringName()
) -> void:
	if target_instance == null:
		return
	var use_face_geometry: bool = selection_target_kind == &"surface_face" and not face_ids.is_empty()
	if (
		not stage2_visible
		or stage2_item_state == null
		or test_print_mesh_builder == null
		or (use_face_geometry and face_ids.is_empty())
		or (not use_face_geometry and patch_ids.is_empty())
	):
		target_instance.visible = false
		target_instance.mesh = null
		return
	var selected_geometry = (
		stage2_item_state.build_current_canonical_geometry_for_face_ids(face_ids)
		if use_face_geometry and stage2_item_state.has_method("build_current_canonical_geometry_for_face_ids")
		else stage2_item_state.build_current_canonical_geometry_for_patch_ids(patch_ids)
	)
	if selected_geometry == null or selected_geometry.is_empty():
		target_instance.visible = false
		target_instance.mesh = null
		return
	target_instance.mesh = test_print_mesh_builder.build_mesh_from_canonical_geometry(selected_geometry)
	target_instance.material_override = _build_stage2_selection_material(preview_color)
	target_instance.scale = Vector3.ONE * cell_world_size
	target_instance.position = _resolve_grid_origin_offset(grid_size, cell_world_size)
	target_instance.visible = true

func _build_stage2_selection_material(preview_color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = preview_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _canonical_local_to_preview_local(canonical_local: Vector3, grid_size: Vector3i, cell_world_size: float) -> Vector3:
	return canonical_local * cell_world_size + _resolve_grid_origin_offset(grid_size, cell_world_size)

func _resolve_grid_origin_offset(grid_size: Vector3i, cell_world_size: float) -> Vector3:
	return -Vector3(
		(float(grid_size.x - 1) * cell_world_size) * 0.5,
		(float(grid_size.y - 1) * cell_world_size) * 0.5,
		(float(grid_size.z - 1) * cell_world_size) * 0.5
	)
