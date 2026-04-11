extends RefCounted
class_name ForgeBenchMenuPresenter

func configure_action_menus(
	project_menu_button: MenuButton,
	status_menu_button: MenuButton,
	view_menu_button: MenuButton,
	geometry_menu_button: MenuButton,
	tool_menu_button: MenuButton,
	workflow_menu_button: MenuButton,
	id_pressed_target: Callable,
	menu_ids: Dictionary
) -> void:
	var project_popup: PopupMenu = project_menu_button.get_popup()
	project_popup.clear()
	_connect_popup(project_popup, id_pressed_target)

	var status_popup: PopupMenu = status_menu_button.get_popup()
	status_popup.clear()

	var view_popup: PopupMenu = view_menu_button.get_popup()
	view_popup.clear()
	view_popup.add_item("Fit View", int(menu_ids.get("view_fit", 0)))
	view_popup.add_item("Toggle Grid Bounds", int(menu_ids.get("view_toggle_bounds", 0)))
	view_popup.add_item("Toggle Active Slice", int(menu_ids.get("view_toggle_slice", 0)))
	_connect_popup(view_popup, id_pressed_target)

	var geometry_popup: PopupMenu = geometry_menu_button.get_popup()
	geometry_popup.clear()
	_connect_popup(geometry_popup, id_pressed_target)

	var tool_popup: PopupMenu = tool_menu_button.get_popup()
	tool_popup.clear()
	_connect_popup(tool_popup, id_pressed_target)

	var workflow_popup: PopupMenu = workflow_menu_button.get_popup()
	workflow_popup.clear()
	_connect_popup(workflow_popup, id_pressed_target)

func rebuild_project_menu(
	project_menu_button: MenuButton,
	menu_ids: Dictionary,
	button_state: Dictionary
) -> void:
	var project_popup: PopupMenu = project_menu_button.get_popup()
	project_popup.clear()
	project_popup.add_item("Project Manager", int(menu_ids.get("project_manager", 0)))
	project_popup.add_separator()
	project_popup.add_item("Save Current", int(menu_ids.get("project_save", 0)))
	project_popup.set_item_disabled(
		project_popup.get_item_count() - 1,
		bool(button_state.get("save_disabled", true))
	)
	project_popup.add_item("New Current Path", int(menu_ids.get("project_new", 0)))
	project_popup.add_item("Load Selected", int(menu_ids.get("project_load_selected", 0)))
	project_popup.set_item_disabled(
		project_popup.get_item_count() - 1,
		bool(button_state.get("load_disabled", true))
	)
	project_popup.add_item("Resume Last", int(menu_ids.get("project_resume_last", 0)))
	project_popup.set_item_disabled(
		project_popup.get_item_count() - 1,
		bool(button_state.get("resume_disabled", true))
	)
	project_popup.add_item("Duplicate Current", int(menu_ids.get("project_duplicate", 0)))
	project_popup.set_item_disabled(
		project_popup.get_item_count() - 1,
		bool(button_state.get("duplicate_disabled", true))
	)
	project_popup.add_item("Delete Current", int(menu_ids.get("project_delete", 0)))
	project_popup.set_item_disabled(
		project_popup.get_item_count() - 1,
		bool(button_state.get("delete_disabled", true))
	)
	project_popup.add_separator()
	project_popup.add_item("Crafting Paths", int(menu_ids.get("project_show_paths", 0)))

func rebuild_status_menu(
	status_menu_button: MenuButton,
	status_state: Dictionary
) -> void:
	var status_popup: PopupMenu = status_menu_button.get_popup()
	status_popup.clear()
	status_popup.add_item("Forge Status")
	status_popup.set_item_disabled(status_popup.get_item_count() - 1, true)
	for line_text: String in _build_status_lines(status_state):
		status_popup.add_item(line_text)
		status_popup.set_item_disabled(status_popup.get_item_count() - 1, true)

func rebuild_geometry_menu(
	geometry_menu_button: MenuButton,
	menu_ids: Dictionary,
	stage2_refinement_mode_active: bool = false,
	active_tool: StringName = StringName(),
	shape_rotation_degrees: int = 0,
	stage2_selection_apply_enabled: bool = false,
	stage2_selection_clear_enabled: bool = false,
	handle_presets_available: bool = false
) -> void:
	var geometry_popup: PopupMenu = geometry_menu_button.get_popup()
	geometry_popup.clear()
	if stage2_refinement_mode_active:
		geometry_popup.add_item("Carve Tool", int(menu_ids.get("geometry_tool_place", 0)))
		geometry_popup.add_item("Fillet Tool", int(menu_ids.get("geometry_tool_fillet", 0)))
		geometry_popup.add_item("Chamfer Tool", int(menu_ids.get("geometry_tool_chamfer", 0)))
		geometry_popup.add_separator()
		geometry_popup.add_item("Face Fillet Tool", int(menu_ids.get("geometry_tool_surface_face_fillet", 0)))
		geometry_popup.add_item("Face Chamfer Tool", int(menu_ids.get("geometry_tool_surface_face_chamfer", 0)))
		geometry_popup.add_item("Edge Fillet Tool", int(menu_ids.get("geometry_tool_surface_edge_fillet", 0)))
		geometry_popup.add_item("Edge Chamfer Tool", int(menu_ids.get("geometry_tool_surface_edge_chamfer", 0)))
		geometry_popup.add_item("Feature Edge Fillet Tool", int(menu_ids.get("geometry_tool_surface_feature_edge_fillet", 0)))
		geometry_popup.add_item("Feature Edge Chamfer Tool", int(menu_ids.get("geometry_tool_surface_feature_edge_chamfer", 0)))
		geometry_popup.add_item("Feature Region Fillet Tool", int(menu_ids.get("geometry_tool_surface_feature_region_fillet", 0)))
		geometry_popup.add_item("Feature Region Chamfer Tool", int(menu_ids.get("geometry_tool_surface_feature_region_chamfer", 0)))
		geometry_popup.add_item("Feature Band Fillet Tool", int(menu_ids.get("geometry_tool_surface_feature_band_fillet", 0)))
		geometry_popup.add_item("Feature Band Chamfer Tool", int(menu_ids.get("geometry_tool_surface_feature_band_chamfer", 0)))
		geometry_popup.add_item("Feature Cluster Fillet Tool", int(menu_ids.get("geometry_tool_surface_feature_cluster_fillet", 0)))
		geometry_popup.add_item("Feature Cluster Chamfer Tool", int(menu_ids.get("geometry_tool_surface_feature_cluster_chamfer", 0)))
		geometry_popup.add_item("Feature Bridge Fillet Tool", int(menu_ids.get("geometry_tool_surface_feature_bridge_fillet", 0)))
		geometry_popup.add_item("Feature Bridge Chamfer Tool", int(menu_ids.get("geometry_tool_surface_feature_bridge_chamfer", 0)))
		geometry_popup.add_item("Feature Contour Fillet Tool", int(menu_ids.get("geometry_tool_surface_feature_contour_fillet", 0)))
		geometry_popup.add_item("Feature Contour Chamfer Tool", int(menu_ids.get("geometry_tool_surface_feature_contour_chamfer", 0)))
		geometry_popup.add_item("Feature Loop Fillet Tool", int(menu_ids.get("geometry_tool_surface_feature_loop_fillet", 0)))
		geometry_popup.add_item("Feature Loop Chamfer Tool", int(menu_ids.get("geometry_tool_surface_feature_loop_chamfer", 0)))
		if _is_stage2_selection_tool(active_tool):
			geometry_popup.add_separator()
			var selection_action_text: String = (
				"Revert Selected Targets"
				if String(active_tool).ends_with("_restore")
				else "Apply Selected Targets"
			)
			geometry_popup.add_item(selection_action_text, int(menu_ids.get("geometry_selection_apply", 0)))
			geometry_popup.set_item_disabled(geometry_popup.get_item_count() - 1, not stage2_selection_apply_enabled)
			geometry_popup.add_item("Clear Target Selection", int(menu_ids.get("geometry_selection_clear", 0)))
			geometry_popup.set_item_disabled(geometry_popup.get_item_count() - 1, not stage2_selection_clear_enabled)
		geometry_popup.add_separator()
		geometry_popup.add_item("Refinement Space: Full 3D Model")
		geometry_popup.set_item_disabled(geometry_popup.get_item_count() - 1, true)
		geometry_popup.add_item("Layer Rules: Inactive")
		geometry_popup.set_item_disabled(geometry_popup.get_item_count() - 1, true)
	else:
		geometry_popup.add_item("Freehand Tool", int(menu_ids.get("geometry_tool_place", 0)))
		geometry_popup.add_item("Pick Material", int(menu_ids.get("geometry_tool_pick", 0)))
		geometry_popup.add_separator()
		if handle_presets_available:
			geometry_popup.add_item("Handles", int(menu_ids.get("geometry_handles_panel", 0)))
		geometry_popup.add_item("Rectangle Tool", int(menu_ids.get("geometry_tool_rectangle_place", 0)))
		geometry_popup.add_item("Circle Tool", int(menu_ids.get("geometry_tool_circle_place", 0)))
		geometry_popup.add_item("Oval Tool", int(menu_ids.get("geometry_tool_oval_place", 0)))
		geometry_popup.add_item("Triangle Tool", int(menu_ids.get("geometry_tool_triangle_place", 0)))
		if _is_stage1_shape_tool(active_tool):
			geometry_popup.add_separator()
			geometry_popup.add_item("Shape Rotation: %d°" % shape_rotation_degrees)
			geometry_popup.set_item_disabled(geometry_popup.get_item_count() - 1, true)
			geometry_popup.add_item("Rotate Shape -90°", int(menu_ids.get("geometry_shape_rotate_left", 0)))
			geometry_popup.add_item("Rotate Shape +90°", int(menu_ids.get("geometry_shape_rotate_right", 0)))
	if not stage2_refinement_mode_active:
		geometry_popup.add_separator()
		geometry_popup.add_item("Plane XY", int(menu_ids.get("geometry_plane_xy", 0)))
		geometry_popup.add_item("Plane ZX", int(menu_ids.get("geometry_plane_zx", 0)))
		geometry_popup.add_item("Plane ZY", int(menu_ids.get("geometry_plane_zy", 0)))
		geometry_popup.add_separator()
		geometry_popup.add_item("Layer -", int(menu_ids.get("geometry_layer_down", 0)))
		geometry_popup.add_item("Layer +", int(menu_ids.get("geometry_layer_up", 0)))

func rebuild_tool_menu(
	tool_menu_button: MenuButton,
	menu_ids: Dictionary,
	tool_state: Dictionary
) -> void:
	var tool_popup: PopupMenu = tool_menu_button.get_popup()
	tool_popup.clear()
	tool_popup.add_item("Tool Settings")
	tool_popup.set_item_disabled(tool_popup.get_item_count() - 1, true)
	var has_runtime_adjustments: bool = false
	if bool(tool_state.get("shape_adjustments_visible", false)):
		tool_popup.add_separator()
		tool_popup.add_item(String(tool_state.get("shape_tool_text", "Shape Tool")))
		tool_popup.set_item_disabled(tool_popup.get_item_count() - 1, true)
		tool_popup.add_item(String(tool_state.get("shape_size_text", "Sizing")))
		tool_popup.set_item_disabled(tool_popup.get_item_count() - 1, true)
		if bool(tool_state.get("shape_size_controls_visible", true)):
			tool_popup.add_item(String(tool_state.get("shape_primary_text", "Size A: 1")))
			tool_popup.set_item_disabled(tool_popup.get_item_count() - 1, true)
			tool_popup.add_item(String(tool_state.get("shape_primary_down_text", "Size A -")), int(menu_ids.get("tool_shape_primary_down", 0)))
			tool_popup.set_item_disabled(
				tool_popup.get_item_count() - 1,
				not bool(tool_state.get("shape_primary_decrease_enabled", true))
			)
			tool_popup.add_item(String(tool_state.get("shape_primary_up_text", "Size A +")), int(menu_ids.get("tool_shape_primary_up", 0)))
			tool_popup.set_item_disabled(
				tool_popup.get_item_count() - 1,
				not bool(tool_state.get("shape_primary_increase_enabled", true))
			)
			if bool(tool_state.get("shape_secondary_visible", false)):
				tool_popup.add_item(String(tool_state.get("shape_secondary_text", "Size B: 1")))
				tool_popup.set_item_disabled(tool_popup.get_item_count() - 1, true)
				tool_popup.add_item(String(tool_state.get("shape_secondary_down_text", "Size B -")), int(menu_ids.get("tool_shape_secondary_down", 0)))
				tool_popup.set_item_disabled(
					tool_popup.get_item_count() - 1,
					not bool(tool_state.get("shape_secondary_decrease_enabled", true))
				)
				tool_popup.add_item(String(tool_state.get("shape_secondary_up_text", "Size B +")), int(menu_ids.get("tool_shape_secondary_up", 0)))
				tool_popup.set_item_disabled(
					tool_popup.get_item_count() - 1,
					not bool(tool_state.get("shape_secondary_increase_enabled", true))
				)
		tool_popup.add_item(String(tool_state.get("shape_mode_text", "Mode: Draw")))
		tool_popup.set_item_disabled(tool_popup.get_item_count() - 1, true)
		tool_popup.add_item("Set Shape to Draw", int(menu_ids.get("tool_shape_mode_draw", 0)))
		tool_popup.set_item_disabled(
			tool_popup.get_item_count() - 1,
			not bool(tool_state.get("shape_draw_enabled", true))
		)
		tool_popup.add_item("Set Shape to Erase", int(menu_ids.get("tool_shape_mode_erase", 0)))
		tool_popup.set_item_disabled(
			tool_popup.get_item_count() - 1,
			not bool(tool_state.get("shape_erase_enabled", true))
		)
		tool_popup.add_item(String(tool_state.get("shape_rotation_text", "Rotation: 0 deg")))
		tool_popup.set_item_disabled(tool_popup.get_item_count() - 1, true)
		tool_popup.add_item("Rotate Shape -90 deg", int(menu_ids.get("tool_shape_rotate_left", 0)))
		tool_popup.add_item("Rotate Shape +90 deg", int(menu_ids.get("tool_shape_rotate_right", 0)))
		has_runtime_adjustments = true
	if bool(tool_state.get("stage2_radius_visible", false)):
		tool_popup.add_separator()
		tool_popup.add_item(String(tool_state.get("stage2_radius_text", "Radius: 0.0125 m")))
		tool_popup.set_item_disabled(tool_popup.get_item_count() - 1, true)
		tool_popup.add_item("Radius -", int(menu_ids.get("tool_radius_down", 0)))
		tool_popup.set_item_disabled(
			tool_popup.get_item_count() - 1,
			not bool(tool_state.get("stage2_radius_decrease_enabled", true))
		)
		tool_popup.add_item("Radius +", int(menu_ids.get("tool_radius_up", 0)))
		tool_popup.set_item_disabled(
			tool_popup.get_item_count() - 1,
			not bool(tool_state.get("stage2_radius_increase_enabled", true))
		)
		has_runtime_adjustments = true
	if bool(tool_state.get("stage2_amount_visible", false)):
		tool_popup.add_separator()
		tool_popup.add_item(String(tool_state.get("stage2_amount_text", "Amount: 100%")))
		tool_popup.set_item_disabled(tool_popup.get_item_count() - 1, true)
		tool_popup.add_item("Amount -", int(menu_ids.get("tool_amount_down", 0)))
		tool_popup.set_item_disabled(
			tool_popup.get_item_count() - 1,
			not bool(tool_state.get("stage2_amount_decrease_enabled", true))
		)
		tool_popup.add_item("Amount +", int(menu_ids.get("tool_amount_up", 0)))
		tool_popup.set_item_disabled(
			tool_popup.get_item_count() - 1,
			not bool(tool_state.get("stage2_amount_increase_enabled", true))
		)
		has_runtime_adjustments = true
	if not has_runtime_adjustments:
		tool_popup.add_separator()
		tool_popup.add_item("No runtime adjustments")
		tool_popup.set_item_disabled(tool_popup.get_item_count() - 1, true)

func rebuild_workflow_menu(
	workflow_menu_button: MenuButton,
	menu_ids: Dictionary,
	stage2_toggle_enabled: bool = false,
	stage2_refinement_mode_active: bool = false
) -> void:
	var workflow_popup: PopupMenu = workflow_menu_button.get_popup()
	workflow_popup.clear()
	workflow_popup.add_item("Bake WIP", int(menu_ids.get("workflow_bake", 0)))
	workflow_popup.add_item("Initialize / Refresh Stage 2", int(menu_ids.get("workflow_stage2_initialize", 0)))
	workflow_popup.add_item(
		"Exit Stage 2 Refinement" if stage2_refinement_mode_active else "Enter Stage 2 Refinement",
		int(menu_ids.get("workflow_stage2_toggle_mode", 0))
	)
	workflow_popup.set_item_disabled(workflow_popup.get_item_count() - 1, not stage2_toggle_enabled)
	workflow_popup.add_item("Reset Current WIP", int(menu_ids.get("workflow_reset", 0)))
	workflow_popup.add_separator()
	workflow_popup.add_item("Close Forge", int(menu_ids.get("workflow_close", 0)))

func handle_action_menu_id_pressed(
	action_id: int,
	menu_ids: Dictionary,
	show_grid_bounds: bool,
	show_active_slice: bool,
	fit_view: Callable,
	refresh_plane_and_preview: Callable,
	set_active_tool: Callable,
	step_shape_rotation: Callable,
	set_active_plane: Callable,
	step_layer: Callable,
	open_project_manager: Callable,
	save_current_project: Callable,
	create_new_project: Callable,
	load_selected_project: Callable,
	resume_last_project: Callable,
	duplicate_current_project: Callable,
	delete_current_project: Callable,
	show_start_menu: Callable,
	bake_active_wip: Callable,
	initialize_stage2: Callable,
	toggle_stage2_refinement_mode: Callable,
	reset_active_wip: Callable,
	close_ui: Callable
) -> Dictionary:
	if action_id == int(menu_ids.get("project_manager", -1)):
		open_project_manager.call()
		return {
			"show_grid_bounds": show_grid_bounds,
			"show_active_slice": show_active_slice,
		}
	if action_id == int(menu_ids.get("project_save", -1)):
		save_current_project.call()
		return {
			"show_grid_bounds": show_grid_bounds,
			"show_active_slice": show_active_slice,
		}
	if action_id == int(menu_ids.get("project_new", -1)):
		create_new_project.call()
		return {
			"show_grid_bounds": show_grid_bounds,
			"show_active_slice": show_active_slice,
		}
	if action_id == int(menu_ids.get("project_load_selected", -1)):
		load_selected_project.call()
		return {
			"show_grid_bounds": show_grid_bounds,
			"show_active_slice": show_active_slice,
		}
	if action_id == int(menu_ids.get("project_resume_last", -1)):
		resume_last_project.call()
		return {
			"show_grid_bounds": show_grid_bounds,
			"show_active_slice": show_active_slice,
		}
	if action_id == int(menu_ids.get("project_duplicate", -1)):
		duplicate_current_project.call()
		return {
			"show_grid_bounds": show_grid_bounds,
			"show_active_slice": show_active_slice,
		}
	if action_id == int(menu_ids.get("project_delete", -1)):
		delete_current_project.call()
		return {
			"show_grid_bounds": show_grid_bounds,
			"show_active_slice": show_active_slice,
		}
	if action_id == int(menu_ids.get("project_show_paths", -1)):
		show_start_menu.call()
		return {
			"show_grid_bounds": show_grid_bounds,
			"show_active_slice": show_active_slice,
		}
	if action_id == int(menu_ids.get("view_fit", -1)):
		fit_view.call()
		return {
			"show_grid_bounds": show_grid_bounds,
			"show_active_slice": show_active_slice,
		}
	if action_id == int(menu_ids.get("view_toggle_bounds", -1)):
		show_grid_bounds = not show_grid_bounds
		refresh_plane_and_preview.call()
		return {
			"show_grid_bounds": show_grid_bounds,
			"show_active_slice": show_active_slice,
		}
	if action_id == int(menu_ids.get("view_toggle_slice", -1)):
		show_active_slice = not show_active_slice
		refresh_plane_and_preview.call()
		return {
			"show_grid_bounds": show_grid_bounds,
			"show_active_slice": show_active_slice,
	}
	if action_id == int(menu_ids.get("geometry_tool_place", -1)):
		set_active_tool.call(&"freehand")
	elif action_id == int(menu_ids.get("geometry_tool_erase", -1)):
		set_active_tool.call(&"erase")
	elif action_id == int(menu_ids.get("geometry_tool_rectangle_place", -1)):
		set_active_tool.call(&"rectangle")
	elif action_id == int(menu_ids.get("geometry_tool_rectangle_erase", -1)):
		set_active_tool.call(&"rectangle_erase")
	elif action_id == int(menu_ids.get("geometry_tool_circle_place", -1)):
		set_active_tool.call(&"circle")
	elif action_id == int(menu_ids.get("geometry_tool_circle_erase", -1)):
		set_active_tool.call(&"circle_erase")
	elif action_id == int(menu_ids.get("geometry_tool_oval_place", -1)):
		set_active_tool.call(&"oval")
	elif action_id == int(menu_ids.get("geometry_tool_oval_erase", -1)):
		set_active_tool.call(&"oval_erase")
	elif action_id == int(menu_ids.get("geometry_tool_triangle_place", -1)):
		set_active_tool.call(&"triangle")
	elif action_id == int(menu_ids.get("geometry_tool_triangle_erase", -1)):
		set_active_tool.call(&"triangle_erase")
	elif action_id == int(menu_ids.get("geometry_shape_rotate_left", -1)):
		step_shape_rotation.call(-1)
	elif action_id == int(menu_ids.get("geometry_shape_rotate_right", -1)):
		step_shape_rotation.call(1)
	elif action_id == int(menu_ids.get("geometry_tool_fillet", -1)):
		set_active_tool.call(&"stage2_fillet")
	elif action_id == int(menu_ids.get("geometry_tool_chamfer", -1)):
		set_active_tool.call(&"stage2_chamfer")
	elif action_id == int(menu_ids.get("geometry_tool_surface_face_fillet", -1)):
		set_active_tool.call(&"stage2_surface_face_fillet")
	elif action_id == int(menu_ids.get("geometry_tool_surface_face_chamfer", -1)):
		set_active_tool.call(&"stage2_surface_face_chamfer")
	elif action_id == int(menu_ids.get("geometry_tool_surface_edge_fillet", -1)):
		set_active_tool.call(&"stage2_surface_edge_fillet")
	elif action_id == int(menu_ids.get("geometry_tool_surface_edge_chamfer", -1)):
		set_active_tool.call(&"stage2_surface_edge_chamfer")
	elif action_id == int(menu_ids.get("geometry_tool_surface_feature_edge_fillet", -1)):
		set_active_tool.call(&"stage2_surface_feature_edge_fillet")
	elif action_id == int(menu_ids.get("geometry_tool_surface_feature_edge_chamfer", -1)):
		set_active_tool.call(&"stage2_surface_feature_edge_chamfer")
	elif action_id == int(menu_ids.get("geometry_tool_surface_feature_region_fillet", -1)):
		set_active_tool.call(&"stage2_surface_feature_region_fillet")
	elif action_id == int(menu_ids.get("geometry_tool_surface_feature_region_chamfer", -1)):
		set_active_tool.call(&"stage2_surface_feature_region_chamfer")
	elif action_id == int(menu_ids.get("geometry_tool_surface_feature_band_fillet", -1)):
		set_active_tool.call(&"stage2_surface_feature_band_fillet")
	elif action_id == int(menu_ids.get("geometry_tool_surface_feature_band_chamfer", -1)):
		set_active_tool.call(&"stage2_surface_feature_band_chamfer")
	elif action_id == int(menu_ids.get("geometry_tool_surface_feature_cluster_fillet", -1)):
		set_active_tool.call(&"stage2_surface_feature_cluster_fillet")
	elif action_id == int(menu_ids.get("geometry_tool_surface_feature_cluster_chamfer", -1)):
		set_active_tool.call(&"stage2_surface_feature_cluster_chamfer")
	elif action_id == int(menu_ids.get("geometry_tool_surface_feature_bridge_fillet", -1)):
		set_active_tool.call(&"stage2_surface_feature_bridge_fillet")
	elif action_id == int(menu_ids.get("geometry_tool_surface_feature_bridge_chamfer", -1)):
		set_active_tool.call(&"stage2_surface_feature_bridge_chamfer")
	elif action_id == int(menu_ids.get("geometry_tool_surface_feature_contour_fillet", -1)):
		set_active_tool.call(&"stage2_surface_feature_contour_fillet")
	elif action_id == int(menu_ids.get("geometry_tool_surface_feature_contour_chamfer", -1)):
		set_active_tool.call(&"stage2_surface_feature_contour_chamfer")
	elif action_id == int(menu_ids.get("geometry_tool_surface_feature_loop_fillet", -1)):
		set_active_tool.call(&"stage2_surface_feature_loop_fillet")
	elif action_id == int(menu_ids.get("geometry_tool_surface_feature_loop_chamfer", -1)):
		set_active_tool.call(&"stage2_surface_feature_loop_chamfer")
	elif action_id == int(menu_ids.get("geometry_tool_pick", -1)):
		set_active_tool.call(&"pick")
	elif action_id == int(menu_ids.get("geometry_plane_xy", -1)):
		set_active_plane.call(&"xy")
	elif action_id == int(menu_ids.get("geometry_plane_zx", -1)):
		set_active_plane.call(&"zx")
	elif action_id == int(menu_ids.get("geometry_plane_zy", -1)):
		set_active_plane.call(&"zy")
	elif action_id == int(menu_ids.get("geometry_layer_down", -1)):
		step_layer.call(-1)
	elif action_id == int(menu_ids.get("geometry_layer_up", -1)):
		step_layer.call(1)
	elif action_id == int(menu_ids.get("workflow_bake", -1)):
		bake_active_wip.call()
	elif action_id == int(menu_ids.get("workflow_stage2_initialize", -1)):
		initialize_stage2.call()
	elif action_id == int(menu_ids.get("workflow_stage2_toggle_mode", -1)):
		toggle_stage2_refinement_mode.call()
	elif action_id == int(menu_ids.get("workflow_reset", -1)):
		reset_active_wip.call()
	elif action_id == int(menu_ids.get("workflow_close", -1)):
		close_ui.call()
	return {
		"show_grid_bounds": show_grid_bounds,
		"show_active_slice": show_active_slice,
	}

func _connect_popup(popup: PopupMenu, id_pressed_target: Callable) -> void:
	if not popup.id_pressed.is_connected(id_pressed_target):
		popup.id_pressed.connect(id_pressed_target)

func _build_status_lines(status_state: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append(String(status_state.get("layer_status_text", "Layer: n/a")))
	lines.append(String(status_state.get("plane_status_text", "Plane: n/a")))
	lines.append("Tool: %s" % String(status_state.get("tool_status_text", "n/a")))
	lines.append("Stage 2: %s" % String(status_state.get("stage2_status_text", "n/a")))
	lines.append(String(status_state.get("armed_material_text", "Material: none")))
	lines.append(String(status_state.get("capacity_text", "Capacity: n/a")))
	return lines

func _is_stage2_selection_tool(tool_id: StringName) -> bool:
	return (
		tool_id == &"stage2_surface_face_fillet"
		or tool_id == &"stage2_surface_face_chamfer"
		or tool_id == &"stage2_surface_face_restore"
		or tool_id == &"stage2_surface_edge_fillet"
		or tool_id == &"stage2_surface_edge_chamfer"
		or tool_id == &"stage2_surface_edge_restore"
		or tool_id == &"stage2_surface_feature_edge_fillet"
		or tool_id == &"stage2_surface_feature_edge_chamfer"
		or tool_id == &"stage2_surface_feature_edge_restore"
		or tool_id == &"stage2_surface_feature_region_fillet"
		or tool_id == &"stage2_surface_feature_region_chamfer"
		or tool_id == &"stage2_surface_feature_region_restore"
		or tool_id == &"stage2_surface_feature_band_fillet"
		or tool_id == &"stage2_surface_feature_band_chamfer"
		or tool_id == &"stage2_surface_feature_band_restore"
		or tool_id == &"stage2_surface_feature_cluster_fillet"
		or tool_id == &"stage2_surface_feature_cluster_chamfer"
		or tool_id == &"stage2_surface_feature_cluster_restore"
		or tool_id == &"stage2_surface_feature_bridge_fillet"
		or tool_id == &"stage2_surface_feature_bridge_chamfer"
		or tool_id == &"stage2_surface_feature_bridge_restore"
		or tool_id == &"stage2_surface_feature_contour_fillet"
		or tool_id == &"stage2_surface_feature_contour_chamfer"
		or tool_id == &"stage2_surface_feature_contour_restore"
		or tool_id == &"stage2_surface_feature_loop_fillet"
		or tool_id == &"stage2_surface_feature_loop_chamfer"
		or tool_id == &"stage2_surface_feature_loop_restore"
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
		or tool_id == &"handle_place"
		or tool_id == &"handle_erase"
	)
