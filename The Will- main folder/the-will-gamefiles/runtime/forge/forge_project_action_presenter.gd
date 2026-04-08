extends RefCounted
class_name ForgeProjectActionPresenter

const ForgeProjectWorkflowScript = preload("res://runtime/forge/forge_project_workflow.gd")

func build_default_project_name(wip_library: PlayerForgeWipLibraryState) -> String:
	return ForgeProjectWorkflowScript.build_default_project_name(wip_library)

func format_sample_preset_name(forge_controller: ForgeGridController, sample_preset_id: StringName) -> String:
	return ForgeProjectWorkflowScript.format_sample_preset_name(forge_controller, sample_preset_id)

func format_saved_project_name(saved_wip: CraftedItemWIP) -> String:
	return ForgeProjectWorkflowScript.format_saved_project_name(saved_wip)

func resolve_active_project_display_name(
	current_wip: CraftedItemWIP,
	forge_controller: ForgeGridController
) -> String:
	return ForgeProjectWorkflowScript.resolve_active_project_display_name(current_wip, forge_controller)

func resolve_editor_project_name(
	current_wip: CraftedItemWIP,
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState
) -> String:
	return ForgeProjectWorkflowScript.resolve_editor_project_name(
		current_wip,
		forge_controller,
		build_default_project_name(wip_library)
	)

func resolve_project_source_text(
	current_wip: CraftedItemWIP,
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState
) -> String:
	return ForgeProjectWorkflowScript.resolve_project_source_text(
		current_wip,
		forge_controller,
		wip_library
	)

func ensure_wip_for_editing(
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState
) -> CraftedItemWIP:
	return ForgeProjectWorkflowScript.ensure_editable_wip(
		forge_controller,
		build_default_project_name(wip_library)
	)

func should_autosave_current_project(
	current_wip: CraftedItemWIP,
	wip_library: PlayerForgeWipLibraryState
) -> bool:
	return ForgeProjectWorkflowScript.should_autosave_current_project(current_wip, wip_library)

func load_sample_preset(
	forge_controller: ForgeGridController,
	sample_preset_id: StringName,
	get_default_layer_for_plane: Callable,
	active_plane: StringName
) -> Dictionary:
	if ForgeProjectWorkflowScript.load_sample_preset(forge_controller, sample_preset_id) == null:
		return {}
	var current_wip: CraftedItemWIP = forge_controller.active_wip
	if current_wip != null and current_wip.forge_project_name.strip_edges().is_empty():
		current_wip.forge_project_name = ForgeProjectWorkflowScript.format_sample_preset_name(forge_controller, sample_preset_id)
	return {
		"active_layer": int(get_default_layer_for_plane.call(active_plane)),
	}

func create_new_blank_project(
	forge_controller: ForgeGridController,
	default_project_name: String,
	get_default_layer_for_plane: Callable,
	active_plane: StringName
) -> Dictionary:
	return create_new_blank_project_for_builder_path(
		forge_controller,
		default_project_name,
		CraftedItemWIP.BUILDER_PATH_MELEE,
		get_default_layer_for_plane,
		active_plane,
		CraftedItemWIP.BUILDER_COMPONENT_PRIMARY
	)

func create_new_blank_project_for_builder_path(
	forge_controller: ForgeGridController,
	default_project_name: String,
	builder_path_id: StringName,
	get_default_layer_for_plane: Callable,
	active_plane: StringName,
	builder_component_id: StringName = StringName()
) -> Dictionary:
	if ForgeProjectWorkflowScript.create_new_blank_project_for_builder_path(
		forge_controller,
		default_project_name,
		builder_path_id,
		builder_component_id
	) == null:
		return {}
	return {
		"active_layer": int(get_default_layer_for_plane.call(active_plane)),
	}

func save_current_project(
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState,
	project_name: String,
	project_notes: String,
	stow_mode: StringName,
	grip_mode: StringName,
	default_project_name: String,
	get_default_layer_for_plane: Callable,
	active_plane: StringName
) -> Dictionary:
	var saved_wip: CraftedItemWIP = ForgeProjectWorkflowScript.save_current_project(
		forge_controller,
		wip_library,
		project_name,
		project_notes,
		stow_mode,
		grip_mode,
		default_project_name
	)
	if saved_wip == null:
		return {}
	return {
		"active_layer": int(get_default_layer_for_plane.call(active_plane)),
	}

func autosave_current_project_if_needed(
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState,
	project_name: String,
	project_notes: String,
	stow_mode: StringName,
	grip_mode: StringName,
	default_project_name: String,
	get_default_layer_for_plane: Callable,
	active_plane: StringName
) -> Dictionary:
	var saved_wip: CraftedItemWIP = ForgeProjectWorkflowScript.autosave_current_project_if_needed(
		forge_controller,
		wip_library,
		project_name,
		project_notes,
		stow_mode,
		grip_mode,
		default_project_name
	)
	if saved_wip == null:
		return {}
	return {
		"active_layer": int(get_default_layer_for_plane.call(active_plane)),
	}

func load_selected_project(
	project_list: ItemList,
	project_catalog: Array[Dictionary],
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState,
	get_default_layer_for_plane: Callable,
	active_plane: StringName
) -> Dictionary:
	if project_list.get_selected_items().is_empty():
		return {}
	var selected_index: int = project_list.get_selected_items()[0]
	if selected_index < 0 or selected_index >= project_catalog.size():
		return {}
	var entry: Dictionary = project_catalog[selected_index]
	if ForgeProjectWorkflowScript.load_catalog_entry(entry, forge_controller, wip_library) == null:
		return {}
	return {
		"active_layer": int(get_default_layer_for_plane.call(active_plane)),
	}

func restore_preferred_project(
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState,
	get_default_layer_for_plane: Callable,
	active_plane: StringName,
	force_reload: bool = false
) -> Dictionary:
	var restored_wip: CraftedItemWIP = ForgeProjectWorkflowScript.restore_preferred_project(
		forge_controller,
		wip_library,
		force_reload
	)
	if restored_wip == null:
		return {}
	return {
		"active_layer": int(get_default_layer_for_plane.call(active_plane)),
		"wip": restored_wip,
	}

func load_saved_project_by_id(
	saved_wip_id: StringName,
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState,
	get_default_layer_for_plane: Callable,
	active_plane: StringName
) -> Dictionary:
	if ForgeProjectWorkflowScript.load_saved_project_by_id(
		forge_controller,
		wip_library,
		saved_wip_id
	) == null:
		return {}
	return {
		"active_layer": int(get_default_layer_for_plane.call(active_plane)),
	}

func build_project_action_button_state(
	project_list: ItemList,
	current_wip: CraftedItemWIP,
	wip_library: PlayerForgeWipLibraryState
) -> Dictionary:
	var has_saved_projects: bool = wip_library != null and wip_library.has_saved_wips()
	var has_selected_saved_project: bool = (
		wip_library != null
		and wip_library.selected_wip_id != StringName()
		and wip_library.get_saved_wip(wip_library.selected_wip_id) != null
	)
	return {
		"load_disabled": project_list.get_selected_items().is_empty(),
		"resume_disabled": not has_saved_projects and not has_selected_saved_project,
		"save_disabled": current_wip == null,
		"duplicate_disabled": current_wip == null,
		"delete_disabled": not ForgeProjectWorkflowScript.is_saved_project(current_wip, wip_library),
	}

func apply_project_action_button_state(
	project_list: ItemList,
	current_wip: CraftedItemWIP,
	wip_library: PlayerForgeWipLibraryState,
	load_project_button: Button,
	resume_last_project_button: Button,
	save_project_button: Button,
	duplicate_project_button: Button,
	delete_project_button: Button
) -> void:
	var button_state: Dictionary = build_project_action_button_state(
		project_list,
		current_wip,
		wip_library
	)
	load_project_button.disabled = bool(button_state.get("load_disabled", true))
	resume_last_project_button.disabled = bool(button_state.get("resume_disabled", true))
	save_project_button.disabled = bool(button_state.get("save_disabled", true))
	duplicate_project_button.disabled = bool(button_state.get("duplicate_disabled", true))
	delete_project_button.disabled = bool(button_state.get("delete_disabled", true))

func apply_project_action_result(
	result: Dictionary,
	current_active_layer: int,
	refresh_all: Callable,
	preserve_workspace_view: bool = false
) -> Dictionary:
	if result.is_empty():
		return {
			"applied": false,
			"active_layer": current_active_layer,
		}
	refresh_all.call(preserve_workspace_view)
	return {
		"applied": true,
		"active_layer": int(result.get("active_layer", current_active_layer)),
	}

func apply_project_action_result_to_layer(
	result: Dictionary,
	current_active_layer: int,
	refresh_all: Callable,
	set_active_layer: Callable,
	preserve_workspace_view: bool = false
) -> bool:
	var action_state: Dictionary = apply_project_action_result(
		result,
		current_active_layer,
		refresh_all,
		preserve_workspace_view
	)
	if not bool(action_state.get("applied", false)):
		return false
	set_active_layer.call(int(action_state.get("active_layer", current_active_layer)))
	return true

func bake_active_wip(forge_controller: ForgeGridController) -> bool:
	if forge_controller == null:
		return false
	forge_controller.bake_active_wip_with_defaults()
	return true

func initialize_stage2_refinement(forge_controller: ForgeGridController) -> bool:
	if forge_controller == null:
		return false
	return forge_controller.ensure_stage2_item_state_for_active_wip() != null

func reset_active_project(
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState,
	default_project_name: String,
	get_default_layer_for_plane: Callable,
	active_plane: StringName
) -> Dictionary:
	if ForgeProjectWorkflowScript.reset_active_project(
		forge_controller,
		wip_library,
		default_project_name
	) == null:
		return {}
	return {
		"active_layer": int(get_default_layer_for_plane.call(active_plane)),
	}

func apply_project_metadata_from_editor(
	forge_controller: ForgeGridController,
	current_wip: CraftedItemWIP,
	project_name: String,
	project_notes: String,
	stow_mode: StringName,
	grip_mode: StringName,
	default_project_name: String
) -> CraftedItemWIP:
	return ForgeProjectWorkflowScript.apply_editor_metadata(
		forge_controller,
		current_wip,
		project_name,
		project_notes,
		stow_mode,
		grip_mode,
		default_project_name
	)

func apply_current_project_metadata_from_editor(
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState,
	project_name: String,
	project_notes: String,
	stow_mode: StringName,
	grip_mode: StringName
) -> CraftedItemWIP:
	var current_wip: CraftedItemWIP = ensure_wip_for_editing(forge_controller, wip_library)
	if current_wip == null:
		return null
	return apply_project_metadata_from_editor(
		forge_controller,
		current_wip,
		project_name,
		project_notes,
		stow_mode,
		grip_mode,
		build_default_project_name(wip_library)
	)

func duplicate_current_project(
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState,
	project_name: String,
	project_notes: String,
	stow_mode: StringName,
	grip_mode: StringName,
	default_project_name: String,
	get_default_layer_for_plane: Callable,
	active_plane: StringName
) -> Dictionary:
	var duplicated_wip: CraftedItemWIP = ForgeProjectWorkflowScript.duplicate_current_project(
		forge_controller,
		wip_library,
		project_name,
		project_notes,
		stow_mode,
		grip_mode,
		default_project_name
	)
	if duplicated_wip == null:
		return {}
	return {
		"active_layer": int(get_default_layer_for_plane.call(active_plane)),
	}

func delete_current_project(
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState,
	default_project_name: String,
	get_default_layer_for_plane: Callable,
	active_plane: StringName
) -> Dictionary:
	if ForgeProjectWorkflowScript.delete_current_project(
		forge_controller,
		wip_library,
		default_project_name
	) == null:
		return {}
	return {
		"active_layer": int(get_default_layer_for_plane.call(active_plane)),
	}
