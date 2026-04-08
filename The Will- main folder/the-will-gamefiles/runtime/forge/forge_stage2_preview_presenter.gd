extends RefCounted
class_name ForgeStage2PreviewPresenter

func sync_stage2_shell_preview(
	stage2_shell_instance: MeshInstance3D,
	stage2_item_state: Resource,
	test_print_mesh_builder: TestPrintMeshBuilder,
	grid_size: Vector3i,
	cell_world_size: float,
	view_tuning: ForgeViewTuningDef,
	stage2_visible: bool
) -> void:
	if stage2_shell_instance == null:
		return
	if not stage2_visible or stage2_item_state == null or not stage2_item_state.has_current_shell() or test_print_mesh_builder == null:
		stage2_shell_instance.visible = false
		stage2_shell_instance.mesh = null
		return
	var canonical_geometry = stage2_item_state.build_current_canonical_geometry()
	if canonical_geometry == null or canonical_geometry.surface_quads.is_empty():
		stage2_shell_instance.visible = false
		stage2_shell_instance.mesh = null
		return
	stage2_shell_instance.mesh = test_print_mesh_builder.build_mesh_from_canonical_geometry(canonical_geometry)
	stage2_shell_instance.material_override = _build_stage2_shell_material(view_tuning)
	stage2_shell_instance.scale = Vector3.ONE * cell_world_size
	stage2_shell_instance.position = _resolve_grid_origin_offset(grid_size, cell_world_size)
	stage2_shell_instance.visible = true

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
	hovered_patch_ids: PackedStringArray,
	selected_patch_ids: PackedStringArray,
	test_print_mesh_builder: TestPrintMeshBuilder,
	grid_size: Vector3i,
	cell_world_size: float,
	view_tuning: ForgeViewTuningDef,
	stage2_visible: bool
) -> void:
	_sync_stage2_selection_mesh_instance(
		stage2_hover_face_instance,
		stage2_item_state,
		hovered_patch_ids,
		test_print_mesh_builder,
		grid_size,
		cell_world_size,
		view_tuning.workspace_stage2_hover_face_color,
		stage2_visible
	)
	_sync_stage2_selection_mesh_instance(
		stage2_selected_faces_instance,
		stage2_item_state,
		selected_patch_ids,
		test_print_mesh_builder,
		grid_size,
		cell_world_size,
		view_tuning.workspace_stage2_selected_face_color,
		stage2_visible
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
	var best_hit_distance: float = INF
	var best_hit_point_preview_local: Vector3 = Vector3.ZERO
	var best_hit_point_canonical_local: Vector3 = Vector3.ZERO
	var best_hit_patch_id: StringName = StringName()
	var best_hit_zone_mask_id: StringName = StringName()
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null or not patch_state.has_current_quad():
			continue
		var hit_data: Dictionary = _intersect_patch_quad(
			ray_origin_local,
			ray_direction_local,
			patch_state.current_quad,
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
		best_hit_patch_id = patch_state.patch_id
		best_hit_zone_mask_id = patch_state.zone_mask_id
	if best_hit_distance == INF:
		return {}
	return {
		"hit_point_preview_local": best_hit_point_preview_local,
		"hit_point_canonical_local": best_hit_point_canonical_local,
		"hit_distance": best_hit_distance,
		"patch_id": best_hit_patch_id,
		"zone_mask_id": best_hit_zone_mask_id,
	}

func _intersect_patch_quad(
	ray_origin_local: Vector3,
	ray_direction_local: Vector3,
	quad_state: Resource,
	grid_size: Vector3i,
	cell_world_size: float
) -> Dictionary:
	var surface_quad = quad_state.build_canonical_surface_quad()
	var vertices: Array[Vector3] = surface_quad.get_vertices()
	if vertices.size() < 4:
		return {}
	var quad_origin_preview_local: Vector3 = _canonical_local_to_preview_local(vertices[0], grid_size, cell_world_size)
	var quad_u_preview_local: Vector3 = surface_quad.edge_u_local * cell_world_size
	var quad_v_preview_local: Vector3 = surface_quad.edge_v_local * cell_world_size
	var quad_normal_preview_local: Vector3 = surface_quad.normal.normalized()
	var denominator: float = ray_direction_local.dot(quad_normal_preview_local)
	if absf(denominator) <= 0.00001:
		return {}
	var hit_distance: float = (quad_origin_preview_local - ray_origin_local).dot(quad_normal_preview_local) / denominator
	if hit_distance < 0.0:
		return {}
	var hit_point_preview_local: Vector3 = ray_origin_local + (ray_direction_local * hit_distance)
	var relative_hit: Vector3 = hit_point_preview_local - quad_origin_preview_local
	var quad_u_length_squared: float = quad_u_preview_local.length_squared()
	var quad_v_length_squared: float = quad_v_preview_local.length_squared()
	if quad_u_length_squared <= 0.0000001 or quad_v_length_squared <= 0.0000001:
		return {}
	var u_ratio: float = relative_hit.dot(quad_u_preview_local) / quad_u_length_squared
	var v_ratio: float = relative_hit.dot(quad_v_preview_local) / quad_v_length_squared
	if u_ratio < 0.0 or u_ratio > 1.0 or v_ratio < 0.0 or v_ratio > 1.0:
		return {}
	return {
		"hit_distance": hit_distance,
		"hit_point_preview_local": hit_point_preview_local,
		"hit_point_canonical_local": vertices[0] + (surface_quad.edge_u_local * u_ratio) + (surface_quad.edge_v_local * v_ratio),
	}

func _build_stage2_shell_material(view_tuning: ForgeViewTuningDef) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = view_tuning.workspace_stage2_shell_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	patch_ids: PackedStringArray,
	test_print_mesh_builder: TestPrintMeshBuilder,
	grid_size: Vector3i,
	cell_world_size: float,
	preview_color: Color,
	stage2_visible: bool
) -> void:
	if target_instance == null:
		return
	if not stage2_visible or stage2_item_state == null or patch_ids.is_empty() or test_print_mesh_builder == null:
		target_instance.visible = false
		target_instance.mesh = null
		return
	var selected_geometry = stage2_item_state.build_current_canonical_geometry_for_patch_ids(patch_ids)
	if selected_geometry == null or selected_geometry.surface_quads.is_empty():
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
