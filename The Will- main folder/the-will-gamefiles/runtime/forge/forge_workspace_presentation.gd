extends RefCounted
class_name ForgeWorkspacePresentation

func refresh_workspace_visuals(
	forge_controller: ForgeGridController,
	current_wip: CraftedItemWIP,
	active_plane: StringName,
	active_layer: int,
	plane_viewport: ForgePlaneViewport,
	free_workspace_preview: ForgeWorkspacePreview,
	material_lookup: Dictionary,
	view_tuning: ForgeViewTuningDef,
	preserve_workspace_view: bool,
	force_full_sync: bool,
	show_grid_bounds: bool,
	show_active_slice: bool,
	main_workspace_mode: StringName,
	stage2_refinement_mode_active: bool = false
) -> String:
	if forge_controller == null:
		return ""
	if plane_viewport != null:
		if force_full_sync or plane_viewport.grid_size != forge_controller.grid_size:
			plane_viewport.set_grid_size(forge_controller.grid_size)
		plane_viewport.set_active_plane(active_plane)
		plane_viewport.set_active_layer(active_layer)
		plane_viewport.set_active_wip(current_wip)
		plane_viewport.set_material_lookup(material_lookup)
		if force_full_sync:
			plane_viewport.set_view_tuning(view_tuning)
	if force_full_sync:
		free_workspace_preview.set_view_tuning(view_tuning)
		free_workspace_preview.configure(forge_controller.grid_size, forge_controller.get_cell_world_size_meters(), preserve_workspace_view)
	free_workspace_preview.set_active_slice(active_plane, active_layer)
	free_workspace_preview.set_material_lookup(material_lookup)
	free_workspace_preview.sync_from_wip(
		current_wip,
		forge_controller.get_forge_service(),
		forge_controller.test_print_mesh_builder,
		stage2_refinement_mode_active
	)
	free_workspace_preview.grid_bounds_instance.visible = show_grid_bounds
	free_workspace_preview.active_plane_instance.visible = show_active_slice and not stage2_refinement_mode_active
	if stage2_refinement_mode_active:
		return "3D Refinement Workspace"
	return "%s\nPlane %s / Layer %d" % [
		"3D Workspace" if main_workspace_mode == &"free" else "3D Inset",
		String(active_plane).to_upper(),
		active_layer,
	]

func build_left_panel_state(
	forge_controller: ForgeGridController,
	current_wip: CraftedItemWIP,
	active_plane: StringName,
	active_layer: int,
	max_layer_for_plane: int,
	active_tool: StringName,
	armed_material_display_name: String,
	stage2_refinement_mode_active: bool = false,
	shape_rotation_degrees: int = 0
) -> Dictionary:
	if forge_controller == null:
		return {}
	var used_cells: int = count_cells(current_wip)
	var max_fill_cells: int = forge_controller.get_max_fill_cells()
	var fill_ratio: float = float(used_cells) / maxf(float(max_fill_cells), 1.0)
	var layer_status_text: String = "Active layer: %d / %d" % [active_layer, max_layer_for_plane]
	var plane_status_text: String = "Plane: %s" % String(active_plane).to_upper()
	if stage2_refinement_mode_active:
		layer_status_text = "Refinement Space: Full 3D"
		plane_status_text = "Layer rules: Structural placement only"
	return {
		"layer_status_text": layer_status_text,
		"plane_status_text": plane_status_text,
		"tool_status_text": _format_tool_status_text(active_tool, shape_rotation_degrees),
		"stage2_status_text": _build_stage2_status_text(current_wip, stage2_refinement_mode_active),
		"armed_material_text": "Material: %s" % armed_material_display_name,
		"capacity_text": "Capacity: %d / %d cells (%.1f%% of allowed fill)" % [used_cells, max_fill_cells, fill_ratio * 100.0],
		"capacity_ratio": fill_ratio,
		"place_active": _is_stage1_place_tool(active_tool),
		"erase_active": _is_stage1_erase_tool(active_tool),
		"pick_active": active_tool == &"pick",
		"xy_active": active_plane == &"xy",
		"zx_active": active_plane == &"zx",
		"zy_active": active_plane == &"zy",
	}

func build_status_text(
	forge_controller: ForgeGridController,
	current_wip: CraftedItemWIP,
	active_plane: StringName,
	active_layer: int,
	active_tool: StringName,
	active_project_display_name: String,
	selected_material_display_name: String,
	armed_material_display_name: String,
	material_lookup: Dictionary,
	stage2_refinement_mode_active: bool = false,
	shape_rotation_degrees: int = 0
) -> String:
	if forge_controller == null:
		return "Forge controller missing."
	var lines: PackedStringArray = []
	lines.append("[b]Forge Workstation State[/b]")
	if current_wip == null:
		lines.append("No active WIP loaded.")
		return "\n".join(lines)
	lines.append("WIP id: %s" % String(current_wip.wip_id))
	lines.append("Project: %s" % active_project_display_name)
	lines.append("Builder path: %s" % CraftedItemWIP.get_builder_path_label(current_wip.forge_builder_path_id))
	if CraftedItemWIP.has_multiple_builder_components(current_wip.forge_builder_path_id):
		lines.append("Builder component: %s" % CraftedItemWIP.get_builder_component_label(
			current_wip.forge_builder_path_id,
			current_wip.forge_builder_component_id
		))
	lines.append("Forge intent / equipment context: %s / %s" % [
		String(current_wip.forge_intent),
		String(current_wip.equipment_context)
	])
	if not current_wip.forge_project_notes.strip_edges().is_empty():
		lines.append("Forge notes: %s" % current_wip.forge_project_notes.strip_edges())
	lines.append("Final item name: not assigned here")
	lines.append("Grid: %d x %d x %d" % [forge_controller.grid_size.x, forge_controller.grid_size.y, forge_controller.grid_size.z])
	lines.append("Cell scale: %.3fm" % forge_controller.get_cell_world_size_meters())
	lines.append("Stage 2: %s" % _build_stage2_status_text(current_wip, stage2_refinement_mode_active))
	if stage2_refinement_mode_active:
		lines.append("Refinement space: Full 3D model interaction")
		lines.append("Layer rules: inactive during Stage 2")
	else:
		lines.append("Plane / layer: %s / %d" % [String(active_plane).to_upper(), active_layer])
	lines.append("Tool: %s" % _format_tool_status_text(active_tool, shape_rotation_degrees))
	if _is_stage1_shape_tool(active_tool):
		lines.append("Shape rotation: %d°" % shape_rotation_degrees)
	lines.append("Selected material: %s" % selected_material_display_name)
	lines.append("Material: %s" % armed_material_display_name)
	lines.append("")

	var profile: BakedProfile = forge_controller.get_active_baked_profile()
	var authored_cells: Array[CellAtom] = collect_wip_cells(current_wip)
	var cells: Array[CellAtom] = CraftedItemWIP.collect_bake_cells(current_wip)
	var segments: Array[SegmentAtom] = forge_controller.forge_service.build_segments(cells, material_lookup)
	segments = forge_controller.forge_service.classify_joint_segments(segments, material_lookup)
	var joint_data: Dictionary = forge_controller.forge_service.build_joint_data(segments, material_lookup)
	var bow_data: Dictionary = forge_controller.forge_service.build_bow_data(
		segments,
		material_lookup,
		current_wip.forge_intent,
		current_wip.equipment_context,
		authored_cells
	)
	lines.append("Segments: %d" % segments.size())
	lines.append("Joint valid: %s" % _format_bool(bool(joint_data.get("joint_chain_valid", false))))
	lines.append("Bow valid: %s" % _format_bool(bool(bow_data.get("bow_valid", false))))
	if StringName(bow_data.get("string_anchor_source", &"")) != StringName():
		lines.append("Bow string source: %s" % String(bow_data.get("string_anchor_source", &"")))
	if StringName(bow_data.get("string_anchor_pair_id", &"")) != StringName():
		lines.append("Bow string pair: %s" % String(bow_data.get("string_anchor_pair_id", &"")).to_upper())
	if float(bow_data.get("string_draw_distance_meters", 0.0)) > 0.0:
		lines.append("Bow draw distance: %.3fm" % float(bow_data.get("string_draw_distance_meters", 0.0)))
	if profile == null:
		lines.append("No baked profile yet. Use Workflow -> Bake WIP or press Enter.")
	else:
		lines.append("Validation: %s" % _format_validation(profile))
		lines.append("Primary grip valid: %s" % _format_bool(profile.primary_grip_valid))
		lines.append("Primary grip span: %d" % profile.primary_grip_span_length_voxels)
		lines.append("Primary grip contact: %s" % str(profile.primary_grip_contact_position))
		lines.append("Total mass: %.3f" % profile.total_mass)
		lines.append("Balance score: %.3f" % profile.balance_score)
		lines.append("Flex score: %.3f" % profile.flex_score)
		lines.append("Launch score: %.3f" % profile.launch_score)
	if forge_controller.active_test_print != null:
		lines.append("Test print id: %s" % String(forge_controller.active_test_print.test_id))
	return "\n".join(lines)

func count_cells(wip: CraftedItemWIP) -> int:
	if wip == null:
		return 0
	var total: int = 0
	for layer_atom: LayerAtom in wip.layers:
		if layer_atom == null:
			continue
		total += layer_atom.cells.size()
	return total

func collect_wip_cells(wip: CraftedItemWIP) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	if wip == null:
		return cells
	for layer_atom: LayerAtom in wip.layers:
		if layer_atom == null:
			continue
		for cell: CellAtom in layer_atom.cells:
			if cell != null:
				cells.append(cell)
	return cells

func _format_bool(value: bool) -> String:
	return "true" if value else "false"

func _format_validation(profile: BakedProfile) -> String:
	if profile == null:
		return "no_profile"
	return "ok" if profile.validation_error.is_empty() else profile.validation_error

func _build_stage2_status_text(current_wip: CraftedItemWIP, stage2_refinement_mode_active: bool = false) -> String:
	if current_wip == null or current_wip.stage2_item_state == null:
		return "not initialized"
	if not current_wip.stage2_item_state.has_current_shell():
		return "empty"
	var status_text: String = "initialized (%d shell quads / %d patches)" % [
		current_wip.stage2_item_state.get_unified_shell_quad_count(),
		current_wip.stage2_item_state.get_patch_count()
	]
	if stage2_refinement_mode_active:
		status_text += " [editing]"
	return status_text

func _format_tool_status_text(active_tool: StringName, shape_rotation_degrees: int = 0) -> String:
	match active_tool:
		&"stage2_carve":
			return "Carve"
		&"stage2_chamfer":
			return "Chamfer"
		&"stage2_fillet":
			return "Fillet"
		&"stage2_surface_face_chamfer":
			return "Face Chamfer"
		&"stage2_surface_face_fillet":
			return "Face Fillet"
		&"stage2_surface_face_restore":
			return "Face Revert"
		&"stage2_surface_edge_chamfer":
			return "Edge Chamfer"
		&"stage2_surface_edge_fillet":
			return "Edge Fillet"
		&"stage2_surface_edge_restore":
			return "Edge Revert"
		&"stage2_surface_feature_edge_chamfer":
			return "Feature Edge Chamfer"
		&"stage2_surface_feature_edge_fillet":
			return "Feature Edge Fillet"
		&"stage2_surface_feature_edge_restore":
			return "Feature Edge Revert"
		&"stage2_surface_feature_region_chamfer":
			return "Feature Region Chamfer"
		&"stage2_surface_feature_region_fillet":
			return "Feature Region Fillet"
		&"stage2_surface_feature_region_restore":
			return "Feature Region Revert"
		&"stage2_surface_feature_band_chamfer":
			return "Feature Band Chamfer"
		&"stage2_surface_feature_band_fillet":
			return "Feature Band Fillet"
		&"stage2_surface_feature_band_restore":
			return "Feature Band Revert"
		&"stage2_surface_feature_cluster_chamfer":
			return "Feature Cluster Chamfer"
		&"stage2_surface_feature_cluster_fillet":
			return "Feature Cluster Fillet"
		&"stage2_surface_feature_cluster_restore":
			return "Feature Cluster Revert"
		&"stage2_surface_feature_bridge_chamfer":
			return "Feature Bridge Chamfer"
		&"stage2_surface_feature_bridge_fillet":
			return "Feature Bridge Fillet"
		&"stage2_surface_feature_bridge_restore":
			return "Feature Bridge Revert"
		&"stage2_surface_feature_contour_chamfer":
			return "Feature Contour Chamfer"
		&"stage2_surface_feature_contour_fillet":
			return "Feature Contour Fillet"
		&"stage2_surface_feature_contour_restore":
			return "Feature Contour Revert"
		&"stage2_surface_feature_loop_chamfer":
			return "Feature Loop Chamfer"
		&"stage2_surface_feature_loop_fillet":
			return "Feature Loop Fillet"
		&"stage2_surface_feature_loop_restore":
			return "Feature Loop Revert"
		&"stage2_restore":
			return "Stage 2 Revert"
		&"place":
			return "Freehand"
		&"erase":
			return "Freehand"
		&"pick":
			return "Pick"
		&"rectangle_place":
			return "Rectangle Draw (%d°)" % shape_rotation_degrees
		&"rectangle_erase":
			return "Rectangle Erase (%d°)" % shape_rotation_degrees
		&"circle_place":
			return "Circle Draw (%d°)" % shape_rotation_degrees
		&"circle_erase":
			return "Circle Erase (%d°)" % shape_rotation_degrees
		&"oval_place":
			return "Oval Draw (%d°)" % shape_rotation_degrees
		&"oval_erase":
			return "Oval Erase (%d°)" % shape_rotation_degrees
		&"triangle_place":
			return "Triangle Draw (%d°)" % shape_rotation_degrees
		&"triangle_erase":
			return "Triangle Erase (%d°)" % shape_rotation_degrees
		_:
			return String(active_tool).capitalize()

func _is_stage1_place_tool(tool_id: StringName) -> bool:
	return (
		tool_id == &"place"
		or tool_id == &"rectangle_place"
		or tool_id == &"circle_place"
		or tool_id == &"oval_place"
		or tool_id == &"triangle_place"
	)

func _is_stage1_erase_tool(tool_id: StringName) -> bool:
	return (
		tool_id == &"erase"
		or tool_id == &"rectangle_erase"
		or tool_id == &"circle_erase"
		or tool_id == &"oval_erase"
		or tool_id == &"triangle_erase"
	)

func _is_stage1_shape_tool(tool_id: StringName) -> bool:
	return (
		tool_id == &"rectangle_place"
		or tool_id == &"rectangle_erase"
		or tool_id == &"circle_place"
		or tool_id == &"circle_erase"
		or tool_id == &"oval_place"
		or tool_id == &"oval_erase"
		or tool_id == &"triangle_place"
		or tool_id == &"triangle_erase"
	)
