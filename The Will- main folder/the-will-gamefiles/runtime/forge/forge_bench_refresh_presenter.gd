extends RefCounted
class_name ForgeBenchRefreshPresenter

func refresh_all(
	reset_pending_edit_refresh: Callable,
	rebuild_workflow_menu: Callable,
	refresh_project_panel_callback: Callable,
	build_material_catalog: Callable,
	refresh_inventory: Callable,
	refresh_material_panels: Callable,
	refresh_plane_and_preview: Callable,
	refresh_left_panel: Callable,
	refresh_status_text: Callable,
	queue_layout_refresh: Callable,
	preserve_workspace_view: bool = true
) -> void:
	reset_pending_edit_refresh.call()
	rebuild_workflow_menu.call()
	refresh_project_panel_callback.call()
	build_material_catalog.call()
	refresh_inventory.call()
	refresh_material_panels.call()
	refresh_plane_and_preview.call(preserve_workspace_view)
	refresh_left_panel.call()
	refresh_status_text.call()
	queue_layout_refresh.call()

func refresh_pending_edit_panels(
	build_material_catalog: Callable,
	refresh_inventory: Callable,
	refresh_material_panels: Callable,
	refresh_left_panel: Callable,
	clear_pending_panel_refresh: Callable
) -> void:
	build_material_catalog.call()
	refresh_inventory.call()
	refresh_material_panels.call()
	refresh_left_panel.call()
	clear_pending_panel_refresh.call()

func apply_material_selection_state(
	selection_state: Dictionary,
	current_selected_material_variant_id: StringName,
	current_armed_material_variant_id: StringName,
	refresh_inventory: Callable,
	refresh_material_panels: Callable,
	refresh_left_panel: Callable,
	refresh_status_text: Callable
) -> Dictionary:
	if selection_state.is_empty():
		return {
			"applied": false,
			"selected_material_variant_id": current_selected_material_variant_id,
			"armed_material_variant_id": current_armed_material_variant_id,
		}
	var selected_material_variant_id: StringName = selection_state.get(
		"selected_material_variant_id",
		current_selected_material_variant_id
	)
	var armed_material_variant_id: StringName = selection_state.get(
		"armed_material_variant_id",
		current_armed_material_variant_id
	)
	refresh_inventory.call()
	refresh_material_panels.call()
	refresh_left_panel.call()
	refresh_status_text.call()
	return {
		"applied": true,
		"selected_material_variant_id": selected_material_variant_id,
		"armed_material_variant_id": armed_material_variant_id,
	}

func refresh_project_panel(
	project_panel_presenter: RefCounted,
	project_action_presenter: RefCounted,
	forge_controller: ForgeGridController,
	current_wip: CraftedItemWIP,
	wip_library: PlayerForgeWipLibraryState,
	view_tuning: ForgeViewTuningDef,
	project_name_edit: LineEdit,
	project_notes_edit: TextEdit,
	project_stow_position_option_button: OptionButton,
	project_grip_style_option_button: OptionButton,
	project_source_label: Label,
	new_project_button: Button,
	builder_component_tabs: Control,
	builder_component_bow_button: BaseButton,
	builder_component_quiver_button: BaseButton,
	project_list: ItemList,
	load_project_button: Button,
	resume_last_project_button: Button,
	save_project_button: Button,
	duplicate_project_button: Button,
	delete_project_button: Button,
	hide_stow_hint: Callable,
	hide_grip_hint: Callable
) -> Array[Dictionary]:
	var project_catalog: Array[Dictionary] = project_panel_presenter.refresh_project_panel(
		forge_controller,
		current_wip,
		wip_library,
		project_name_edit,
		project_notes_edit,
		project_stow_position_option_button,
		project_grip_style_option_button,
		project_source_label,
		new_project_button,
		project_list
	)
	project_panel_presenter.refresh_builder_component_tabs(
		current_wip,
		builder_component_tabs,
		builder_component_bow_button,
		builder_component_quiver_button,
		view_tuning
	)
	hide_stow_hint.call()
	hide_grip_hint.call()
	project_action_presenter.apply_project_action_button_state(
		project_list,
		current_wip,
		wip_library,
		load_project_button,
		resume_last_project_button,
		save_project_button,
		duplicate_project_button,
		delete_project_button
	)
	return project_catalog
