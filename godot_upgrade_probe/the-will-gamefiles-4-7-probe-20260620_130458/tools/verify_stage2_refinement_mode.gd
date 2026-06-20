extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/stage2_refinement_mode_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	forge_controller.load_new_blank_wip_for_builder_path("Stage2 Mode Test", CraftedItemWIP.BUILDER_PATH_MELEE)
	_seed_cells(forge_controller)
	forge_controller.ensure_stage2_item_state_for_active_wip()
	forge_controller.spawn_test_print_from_active_wip(forge_controller.build_default_material_lookup())
	get_root().add_child(forge_controller)

	var player: PlayerController3D = PlayerScene.instantiate() as PlayerController3D
	get_root().add_child(player)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_for(player, forge_controller, "Stage2 Mode Bench")
	await process_frame
	await process_frame

	crafting_ui.call("_toggle_stage2_refinement_mode")
	await process_frame
	await process_frame

	var preview: ForgeWorkspacePreview = crafting_ui.free_workspace_preview
	var stage2_item_state = forge_controller.active_wip.stage2_item_state if forge_controller.active_wip != null else null
	var stage2_mode_active: bool = bool(crafting_ui.get("stage2_refinement_mode_active"))
	var shell_visible: bool = preview != null and preview.stage2_shell_instance != null and preview.stage2_shell_instance.visible
	var shell_preview_source: String = str(preview.stage2_shell_preview_source if preview != null else StringName())
	var shell_surface_count: int = (
		preview.stage2_shell_instance.mesh.get_surface_count()
		if preview != null and preview.stage2_shell_instance != null and preview.stage2_shell_instance.mesh != null
		else 0
	)
	var shell_has_mesh_surfaces: bool = shell_surface_count > 0
	var shell_material: StandardMaterial3D = (
		preview.stage2_shell_instance.material_override as StandardMaterial3D
		if preview != null and preview.stage2_shell_instance != null
		else null
	)
	var shell_material_uses_vertex_color: bool = shell_material != null and shell_material.vertex_color_use_as_albedo
	var shell_material_opaque: bool = shell_material != null and shell_material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	var occupied_cells_visible: bool = preview != null and preview.occupied_cells_instance != null and preview.occupied_cells_instance.visible
	var occupied_cells_hidden_in_stage2: bool = preview != null and preview.occupied_cells_instance != null and not preview.occupied_cells_instance.visible
	var refinement_model_visible: bool = shell_has_mesh_surfaces or occupied_cells_visible
	var free_workspace_locked: bool = StringName(crafting_ui.get("main_workspace_mode")) == &"free"
	var inset_hidden: bool = crafting_ui.inset_viewport_host != null and not crafting_ui.inset_viewport_host.visible
	var active_slice_hidden: bool = preview != null and preview.active_plane_instance != null and not preview.active_plane_instance.visible
	var draw_text_ok: bool = crafting_ui.draw_tool_button.text == "Apply"
	var erase_text_ok: bool = crafting_ui.erase_tool_button.text == "Revert"
	var active_plane_before_stage2_change: StringName = StringName(crafting_ui.get("active_plane"))
	var active_layer_before_stage2_change: int = int(crafting_ui.get("active_layer"))
	crafting_ui.call("_set_active_plane", &"zx")
	crafting_ui.call("_step_layer", 1)
	await process_frame
	var plane_unchanged_in_stage2: bool = StringName(crafting_ui.get("active_plane")) == active_plane_before_stage2_change
	var layer_unchanged_in_stage2: bool = int(crafting_ui.get("active_layer")) == active_layer_before_stage2_change
	var brush_screen_position: Vector2 = _resolve_stage2_shell_screen_position(preview, stage2_item_state)
	var hit_data: Dictionary = preview.resolve_stage2_brush_hit(brush_screen_position, forge_controller.active_wip) if preview != null else {}
	var hover_hit_resolved: bool = not hit_data.is_empty()
	var hover_hit_source: String = str(hit_data.get("mesh_source", ""))
	var min_brush_radius_meters: float = float(crafting_ui.call("_get_stage2_pointer_tool_min_radius_meters"))
	var brush_candidate_face_ids: PackedStringArray = (
		stage2_item_state.resolve_shell_face_ids_for_brush_sphere(
			hit_data.get("hit_point_canonical_local", Vector3.ZERO),
			min_brush_radius_meters,
			StringName(hit_data.get("face_id", StringName()))
		)
		if stage2_item_state != null and not hit_data.is_empty() and stage2_item_state.has_method("resolve_shell_face_ids_for_brush_sphere")
		else PackedStringArray()
	)
	var brush_candidate_patch_count: int = (
		stage2_item_state.resolve_patch_ids_for_brush_sphere(
			hit_data.get("hit_point_canonical_local", Vector3.ZERO),
			min_brush_radius_meters,
			StringName(hit_data.get("face_id", StringName()))
		).size()
		if stage2_item_state != null and not hit_data.is_empty() and stage2_item_state.has_method("resolve_patch_ids_for_brush_sphere")
		else 0
	)
	crafting_ui.call("_update_stage2_brush_hover", brush_screen_position)
	await process_frame
	var brush_preview_visible: bool = preview != null and preview.stage2_brush_preview_instance != null and preview.stage2_brush_preview_instance.visible
	crafting_ui.set("stage2_brush_radius_meters", min_brush_radius_meters)
	var surface_signature_before_carve: Array[Vector3] = _collect_stage2_surface_signature(forge_controller.active_wip.stage2_item_state)
	crafting_ui.call("_apply_stage2_brush_at_screen_position", brush_screen_position)
	await process_frame
	var carve_changed_shell: bool = _has_any_patch_origin_changed(
		surface_signature_before_carve,
		_collect_stage2_surface_signature(forge_controller.active_wip.stage2_item_state)
	)
	var post_carve_canonical_geometry = (
		forge_controller.active_wip.stage2_item_state.build_current_canonical_geometry()
		if forge_controller.active_wip != null and forge_controller.active_wip.stage2_item_state != null
		else null
	)
	var post_carve_hit_data: Dictionary = preview.resolve_stage2_brush_hit(
		brush_screen_position,
		forge_controller.active_wip
	) if preview != null else {}
	var post_carve_hit_primitive_type: String = str(post_carve_hit_data.get("primitive_type", ""))
	var post_carve_hit_source: String = str(post_carve_hit_data.get("mesh_source", ""))
	var post_carve_quad_count: int = (
		post_carve_canonical_geometry.get_quad_count()
		if post_carve_canonical_geometry != null
		else 0
	)
	var post_carve_triangle_count: int = (
		post_carve_canonical_geometry.get_triangle_count()
		if post_carve_canonical_geometry != null
		else 0
	)
	var post_carve_surface_primitive_count: int = (
		post_carve_canonical_geometry.get_surface_primitive_count()
		if post_carve_canonical_geometry != null
		else 0
	)
	var post_carve_triangles_have_vertex_normals: bool = _triangles_have_vertex_normals(post_carve_canonical_geometry)
	var post_carve_smoothed_vertex_normals_present: bool = _triangles_have_smoothed_vertex_normals(post_carve_canonical_geometry)
	var post_carve_localized_geometry_retained: bool = (
		forge_controller.active_wip != null
		and forge_controller.active_wip.stage2_item_state != null
		and post_carve_surface_primitive_count > forge_controller.active_wip.stage2_item_state.get_unified_shell_quad_count()
		and post_carve_surface_primitive_count < (forge_controller.active_wip.stage2_item_state.get_patch_count() * 4)
	)
	var changed_shell_quad_ids: PackedStringArray = _resolve_changed_shell_quad_ids(
		forge_controller.active_wip.stage2_item_state,
		surface_signature_before_carve
	)
	if changed_shell_quad_ids.is_empty():
		changed_shell_quad_ids = brush_candidate_face_ids
	var localized_surface_only_primitive_count: int = _resolve_localized_surface_only_primitive_count(
		forge_controller.active_wip.stage2_item_state,
		changed_shell_quad_ids
	)
	var post_carve_secondary_diagonal_cell_count: int = (
		forge_controller.active_wip.stage2_item_state.count_secondary_diagonal_cells_for_shell_quad_ids(changed_shell_quad_ids)
		if forge_controller.active_wip != null
			and forge_controller.active_wip.stage2_item_state != null
			and forge_controller.active_wip.stage2_item_state.has_method("count_secondary_diagonal_cells_for_shell_quad_ids")
		else 0
	)
	var post_carve_center_subdivided_cell_count: int = (
		forge_controller.active_wip.stage2_item_state.count_center_subdivided_cells_for_shell_quad_ids(changed_shell_quad_ids)
		if forge_controller.active_wip != null
			and forge_controller.active_wip.stage2_item_state != null
			and forge_controller.active_wip.stage2_item_state.has_method("count_center_subdivided_cells_for_shell_quad_ids")
		else 0
	)
	var post_carve_edge_midpoint_subdivided_cell_count: int = (
		forge_controller.active_wip.stage2_item_state.count_edge_midpoint_subdivided_cells_for_shell_quad_ids(changed_shell_quad_ids)
		if forge_controller.active_wip != null
			and forge_controller.active_wip.stage2_item_state != null
			and forge_controller.active_wip.stage2_item_state.has_method("count_edge_midpoint_subdivided_cells_for_shell_quad_ids")
		else 0
	)
	var post_carve_transition_geometry_present: bool = (
		post_carve_surface_primitive_count > localized_surface_only_primitive_count
	)
	var cleared_test_print_after_carve: bool = forge_controller.active_test_print == null

	crafting_ui.call("_toggle_stage2_refinement_mode")
	await process_frame
	var mode_exited: bool = not bool(crafting_ui.get("stage2_refinement_mode_active"))
	var draw_text_restored: bool = crafting_ui.draw_tool_button.text == "Draw"

	var lines: PackedStringArray = []
	lines.append("stage2_mode_active=%s" % str(stage2_mode_active))
	lines.append("stage2_shell_visible=%s" % str(shell_visible))
	lines.append("stage2_shell_preview_source=%s" % shell_preview_source)
	lines.append("stage2_shell_surface_count=%s" % str(shell_surface_count))
	lines.append("stage2_shell_has_mesh_surfaces=%s" % str(shell_has_mesh_surfaces))
	lines.append("stage2_shell_material_uses_vertex_color=%s" % str(shell_material_uses_vertex_color))
	lines.append("stage2_shell_material_opaque=%s" % str(shell_material_opaque))
	lines.append("occupied_cells_visible=%s" % str(occupied_cells_visible))
	lines.append("occupied_cells_hidden_in_stage2=%s" % str(occupied_cells_hidden_in_stage2))
	lines.append("refinement_model_visible=%s" % str(refinement_model_visible))
	lines.append("free_workspace_locked=%s" % str(free_workspace_locked))
	lines.append("inset_hidden=%s" % str(inset_hidden))
	lines.append("active_slice_hidden=%s" % str(active_slice_hidden))
	lines.append("draw_text_ok=%s" % str(draw_text_ok))
	lines.append("erase_text_ok=%s" % str(erase_text_ok))
	lines.append("plane_unchanged_in_stage2=%s" % str(plane_unchanged_in_stage2))
	lines.append("layer_unchanged_in_stage2=%s" % str(layer_unchanged_in_stage2))
	lines.append("hover_hit_resolved=%s" % str(hover_hit_resolved))
	lines.append("hover_hit_source=%s" % hover_hit_source)
	lines.append("brush_candidate_face_count=%d" % brush_candidate_face_ids.size())
	lines.append("brush_candidate_patch_count=%d" % brush_candidate_patch_count)
	lines.append("brush_preview_visible=%s" % str(brush_preview_visible))
	lines.append("carve_changed_shell=%s" % str(carve_changed_shell))
	lines.append("post_carve_quad_count=%d" % post_carve_quad_count)
	lines.append("post_carve_triangle_count=%d" % post_carve_triangle_count)
	lines.append("post_carve_surface_primitive_count=%d" % post_carve_surface_primitive_count)
	lines.append("post_carve_hit_primitive_type=%s" % post_carve_hit_primitive_type)
	lines.append("post_carve_hit_source=%s" % post_carve_hit_source)
	lines.append("post_carve_triangles_have_vertex_normals=%s" % str(post_carve_triangles_have_vertex_normals))
	lines.append("post_carve_smoothed_vertex_normals_present=%s" % str(post_carve_smoothed_vertex_normals_present))
	lines.append("post_carve_localized_geometry_retained=%s" % str(post_carve_localized_geometry_retained))
	lines.append("localized_surface_only_primitive_count=%d" % localized_surface_only_primitive_count)
	lines.append("post_carve_secondary_diagonal_cell_count=%d" % post_carve_secondary_diagonal_cell_count)
	lines.append("post_carve_center_subdivided_cell_count=%d" % post_carve_center_subdivided_cell_count)
	lines.append("post_carve_edge_midpoint_subdivided_cell_count=%d" % post_carve_edge_midpoint_subdivided_cell_count)
	lines.append("post_carve_transition_geometry_present=%s" % str(post_carve_transition_geometry_present))
	lines.append("cleared_test_print_after_carve=%s" % str(cleared_test_print_after_carve))
	lines.append("mode_exited=%s" % str(mode_exited))
	lines.append("draw_text_restored=%s" % str(draw_text_restored))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _seed_cells(forge_controller: ForgeGridController) -> void:
	for z: int in range(2):
		for y: int in range(2):
			for x: int in range(4):
				forge_controller.set_material_at(Vector3i(x, y, z), &"mat_iron_gray")

func _collect_patch_origins(stage2_item_state) -> Array[Vector3]:
	var origins: Array[Vector3] = []
	if stage2_item_state == null:
		return origins
	for patch_state in stage2_item_state.patch_states:
		if patch_state == null or patch_state.current_quad == null:
			continue
		origins.append(patch_state.current_quad.origin_local)
	return origins

func _collect_stage2_surface_signature(stage2_item_state) -> Array[Vector3]:
	if (
		stage2_item_state != null
		and bool(stage2_item_state.get("editable_mesh_visual_authority"))
		and stage2_item_state.has_method("has_current_editable_mesh")
		and bool(stage2_item_state.call("has_current_editable_mesh"))
	):
		var editable_mesh_state: Resource = stage2_item_state.get("current_editable_mesh_state") as Resource
		if editable_mesh_state != null:
			var surface_arrays: Array = editable_mesh_state.get("surface_arrays") as Array
			if surface_arrays.size() > Mesh.ARRAY_VERTEX and surface_arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
				var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
				var signature: Array[Vector3] = []
				for vertex_local: Vector3 in vertices:
					signature.append(vertex_local)
				return signature
	return _collect_patch_origins(stage2_item_state)

func _resolve_changed_shell_quad_ids(stage2_item_state, origins_before: Array[Vector3]) -> PackedStringArray:
	var changed_shell_quad_lookup: Dictionary = {}
	if stage2_item_state == null:
		return PackedStringArray()
	for patch_index: int in range(stage2_item_state.patch_states.size()):
		var patch_state = stage2_item_state.patch_states[patch_index]
		if patch_state == null or patch_state.current_quad == null:
			continue
		if patch_index >= origins_before.size():
			if patch_state.shell_quad_id != StringName():
				changed_shell_quad_lookup[patch_state.shell_quad_id] = true
			continue
		if not origins_before[patch_index].is_equal_approx(patch_state.current_quad.origin_local) and patch_state.shell_quad_id != StringName():
			changed_shell_quad_lookup[patch_state.shell_quad_id] = true
	return PackedStringArray(changed_shell_quad_lookup.keys())

func _resolve_localized_surface_only_primitive_count(stage2_item_state, changed_shell_quad_ids: PackedStringArray) -> int:
	if stage2_item_state == null:
		return 0
	if changed_shell_quad_ids.is_empty() or not stage2_item_state.has_method("build_current_canonical_geometry_without_transition_walls_for_shell_quad_ids"):
		return stage2_item_state.get_unified_shell_quad_count()
	var surface_only_geometry = stage2_item_state.build_current_canonical_geometry_without_transition_walls_for_shell_quad_ids(
		changed_shell_quad_ids
	)
	if surface_only_geometry == null or not surface_only_geometry.has_method("get_surface_primitive_count"):
		return stage2_item_state.get_unified_shell_quad_count()
	return int(surface_only_geometry.get_surface_primitive_count())

func _triangles_have_vertex_normals(canonical_geometry) -> bool:
	if canonical_geometry == null:
		return false
	for surface_triangle in canonical_geometry.surface_triangles:
		if surface_triangle == null:
			continue
		if surface_triangle.has_method("has_vertex_normals") and surface_triangle.has_vertex_normals():
			return true
	return false

func _triangles_have_smoothed_vertex_normals(canonical_geometry) -> bool:
	if canonical_geometry == null:
		return false
	for surface_triangle in canonical_geometry.surface_triangles:
		if surface_triangle == null:
			continue
		if not (surface_triangle.has_method("has_vertex_normals") and surface_triangle.has_vertex_normals()):
			continue
		if (
			not surface_triangle.vertex_a_normal.is_equal_approx(surface_triangle.normal)
			or not surface_triangle.vertex_b_normal.is_equal_approx(surface_triangle.normal)
			or not surface_triangle.vertex_c_normal.is_equal_approx(surface_triangle.normal)
		):
			return true
	return false

func _has_any_patch_origin_changed(origins_before: Array[Vector3], origins_after: Array[Vector3]) -> bool:
	if origins_before.size() != origins_after.size():
		return true
	for index: int in range(origins_before.size()):
		if not origins_before[index].is_equal_approx(origins_after[index]):
			return true
	return false

func _resolve_stage2_shell_screen_position(preview: ForgeWorkspacePreview, stage2_item_state) -> Vector2:
	if preview == null or stage2_item_state == null or preview.camera == null:
		return Vector2.ZERO
	var stage2_shell_center_local: Vector3 = (
		stage2_item_state.current_local_aabb_position
		+ (stage2_item_state.current_local_aabb_size * 0.5)
	)
	var grid_origin_offset: Vector3 = -Vector3(
		(float(preview.grid_size.x - 1) * preview.cell_world_size) * 0.5,
		(float(preview.grid_size.y - 1) * preview.cell_world_size) * 0.5,
		(float(preview.grid_size.z - 1) * preview.cell_world_size) * 0.5
	)
	var preview_local_point: Vector3 = stage2_shell_center_local * preview.cell_world_size + grid_origin_offset
	return preview.camera.unproject_position(preview.to_global(preview_local_point))
