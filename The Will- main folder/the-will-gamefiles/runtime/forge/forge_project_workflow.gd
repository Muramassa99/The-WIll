extends RefCounted
class_name ForgeProjectWorkflow

static func build_default_project_name(wip_library: PlayerForgeWipLibraryState) -> String:
	var project_count: int = wip_library.get_saved_wips().size() if wip_library != null else 0
	return "Forge Project %03d" % (project_count + 1)

static func format_sample_preset_name(forge_controller: ForgeGridController, sample_preset_id: StringName) -> String:
	if forge_controller == null:
		return String(sample_preset_id)
	return forge_controller.get_sample_preset_display_name(sample_preset_id)

static func format_saved_project_name(saved_wip: CraftedItemWIP) -> String:
	if saved_wip == null:
		return "Unnamed Player WIP"
	if not saved_wip.forge_project_name.strip_edges().is_empty():
		return saved_wip.forge_project_name.strip_edges()
	if not saved_wip.wip_id.is_empty():
		return String(saved_wip.wip_id)
	return "Unnamed Player WIP"

static func is_saved_project(current_wip: CraftedItemWIP, wip_library: PlayerForgeWipLibraryState) -> bool:
	if current_wip == null or wip_library == null:
		return false
	return wip_library.get_saved_wip(current_wip.wip_id) != null

static func should_autosave_current_project(
	current_wip: CraftedItemWIP,
	wip_library: PlayerForgeWipLibraryState
) -> bool:
	if current_wip == null or wip_library == null:
		return false
	if is_saved_project(current_wip, wip_library):
		return true
	if _count_authored_cells(current_wip) > 0:
		return true
	if not CraftedItemWIP.collect_builder_marker_positions(current_wip).is_empty():
		return true
	return not current_wip.forge_project_notes.strip_edges().is_empty()

static func resolve_active_project_display_name(current_wip: CraftedItemWIP, forge_controller: ForgeGridController) -> String:
	if current_wip == null:
		return "none"
	if not current_wip.forge_project_name.strip_edges().is_empty():
		return current_wip.forge_project_name.strip_edges()
	if forge_controller != null and forge_controller.get_active_sample_preset_id() != StringName():
		return format_sample_preset_name(forge_controller, forge_controller.get_active_sample_preset_id())
	return format_saved_project_name(current_wip)

static func resolve_editor_project_name(current_wip: CraftedItemWIP, forge_controller: ForgeGridController, default_project_name: String) -> String:
	if current_wip == null:
		return ""
	if not current_wip.forge_project_name.strip_edges().is_empty():
		return current_wip.forge_project_name.strip_edges()
	if forge_controller != null and forge_controller.get_active_sample_preset_id() != StringName():
		return format_sample_preset_name(forge_controller, forge_controller.get_active_sample_preset_id())
	return default_project_name

static func resolve_project_source_text(current_wip: CraftedItemWIP, forge_controller: ForgeGridController, wip_library: PlayerForgeWipLibraryState) -> String:
	if current_wip == null:
		return "Current project source: none"
	var builder_scope_label: String = CraftedItemWIP.get_builder_scope_label(
		current_wip.forge_builder_path_id,
		current_wip.forge_builder_component_id
	).to_lower()
	if forge_controller != null and forge_controller.get_active_sample_preset_id() != StringName():
		return "Current project source: %s authoring preset. Temporary forge label only." % builder_scope_label
	if is_saved_project(current_wip, wip_library):
		return "Current project source: saved player %s forge project. Final item naming happens later." % builder_scope_label
	return "Current project source: unsaved %s forge draft. Final item naming happens later." % builder_scope_label

static func build_project_catalog(forge_controller: ForgeGridController, wip_library: PlayerForgeWipLibraryState) -> Array[Dictionary]:
	var project_catalog: Array[Dictionary] = []
	if forge_controller != null:
		for sample_preset_id: StringName in forge_controller.get_sample_preset_ids():
			project_catalog.append({
				"entry_type": &"authoring_preset",
				"sample_preset_id": sample_preset_id,
				"display_name": "[Preset] %s" % format_sample_preset_name(forge_controller, sample_preset_id),
			})
	var saved_wips: Array[CraftedItemWIP] = []
	if wip_library != null:
		saved_wips = wip_library.get_saved_wips()
	for saved_wip: CraftedItemWIP in saved_wips:
		var saved_description: String = saved_wip.forge_project_notes.strip_edges()
		var builder_scope_summary: String = "Path: %s" % CraftedItemWIP.get_builder_scope_label(
			saved_wip.forge_builder_path_id,
			saved_wip.forge_builder_component_id
		)
		var stow_summary: String = "Stowed: %s" % CraftedItemWIP.get_stow_position_label(saved_wip.stow_position_mode)
		var grip_summary: String = "Grip: %s" % CraftedItemWIP.get_grip_style_label(saved_wip.grip_style_mode)
		saved_description = "%s\n%s" % [saved_description, builder_scope_summary] if not saved_description.is_empty() else builder_scope_summary
		saved_description = "%s\n%s" % [saved_description, stow_summary] if not saved_description.is_empty() else stow_summary
		saved_description = "%s\n%s" % [saved_description, grip_summary] if not saved_description.is_empty() else grip_summary
		project_catalog.append({
			"entry_type": &"saved",
			"saved_wip_id": saved_wip.wip_id,
			"display_name": "[Saved] %s" % format_saved_project_name(saved_wip),
			"description": saved_description,
		})
	return project_catalog

static func apply_editor_metadata(
	forge_controller: ForgeGridController,
	current_wip: CraftedItemWIP,
	submitted_name: String,
	submitted_notes: String,
	stow_mode: StringName,
	grip_mode: StringName,
	default_project_name: String
) -> CraftedItemWIP:
	if forge_controller == null or current_wip == null:
		return null
	current_wip.forge_project_name = submitted_name.strip_edges() if not submitted_name.strip_edges().is_empty() else default_project_name
	current_wip.forge_project_notes = submitted_notes.strip_edges()
	current_wip.stow_position_mode = CraftedItemWIP.normalize_stow_position_mode(stow_mode)
	current_wip.grip_style_mode = CraftedItemWIP.resolve_supported_grip_style(
		grip_mode,
		current_wip.forge_intent,
		current_wip.equipment_context
	)
	forge_controller.set_active_wip(current_wip)
	return forge_controller.active_wip

static func ensure_editable_wip(forge_controller: ForgeGridController, default_project_name: String) -> CraftedItemWIP:
	if forge_controller == null:
		return null
	return forge_controller.ensure_editable_wip(default_project_name)

static func load_sample_preset(forge_controller: ForgeGridController, sample_preset_id: StringName) -> CraftedItemWIP:
	if forge_controller == null:
		return null
	return forge_controller.load_sample_preset_wip(sample_preset_id)

static func create_new_blank_project(forge_controller: ForgeGridController, default_project_name: String) -> CraftedItemWIP:
	return create_new_blank_project_for_builder_path(
		forge_controller,
		default_project_name,
		CraftedItemWIP.BUILDER_PATH_MELEE
	)

static func create_new_blank_project_for_builder_path(
	forge_controller: ForgeGridController,
	default_project_name: String,
	builder_path_id: StringName,
	builder_component_id: StringName = StringName()
) -> CraftedItemWIP:
	if forge_controller == null:
		return null
	return forge_controller.load_new_blank_wip_for_builder_path(
		default_project_name,
		builder_path_id,
		builder_component_id
	)

static func load_saved_project_by_id(
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState,
	saved_wip_id: StringName
) -> CraftedItemWIP:
	if forge_controller == null or wip_library == null or saved_wip_id == StringName():
		return null
	var saved_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(saved_wip_id)
	if saved_wip == null:
		return null
	wip_library.set_selected_wip_id(saved_wip_id)
	return forge_controller.load_player_saved_wip(saved_wip)

static func load_catalog_entry(
	entry: Dictionary,
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState
) -> CraftedItemWIP:
	var entry_type: StringName = entry.get("entry_type", &"")
	if entry_type == &"authoring_preset":
		return load_sample_preset(forge_controller, entry.get("sample_preset_id", &""))
	if entry_type == &"saved":
		return load_saved_project_by_id(forge_controller, wip_library, entry.get("saved_wip_id", &""))
	return null

static func restore_preferred_project(
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState,
	force_reload: bool = false
) -> CraftedItemWIP:
	if forge_controller == null:
		return null
	if not force_reload and forge_controller.active_wip != null:
		return forge_controller.active_wip
	if wip_library == null:
		return null
	if wip_library.selected_wip_id != StringName():
		var selected_saved_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(wip_library.selected_wip_id)
		if selected_saved_wip != null:
			return forge_controller.load_player_saved_wip(selected_saved_wip)
	for saved_wip: CraftedItemWIP in wip_library.get_saved_wips():
		if saved_wip == null:
			continue
		wip_library.set_selected_wip_id(saved_wip.wip_id)
		return forge_controller.load_player_saved_wip(saved_wip.duplicate(true) as CraftedItemWIP)
	return null

static func save_current_project(
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState,
	submitted_name: String,
	submitted_notes: String,
	stow_mode: StringName,
	grip_mode: StringName,
	default_project_name: String
) -> CraftedItemWIP:
	var current_wip: CraftedItemWIP = ensure_editable_wip(forge_controller, default_project_name)
	if current_wip == null or wip_library == null or forge_controller == null:
		return null
	apply_editor_metadata(
		forge_controller,
		current_wip,
		submitted_name,
		submitted_notes,
		stow_mode,
		grip_mode,
		default_project_name
	)
	var saved_wip: CraftedItemWIP = wip_library.save_wip(forge_controller.active_wip)
	if saved_wip == null:
		return null
	return forge_controller.load_player_saved_wip(saved_wip)

static func autosave_current_project_if_needed(
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState,
	submitted_name: String,
	submitted_notes: String,
	stow_mode: StringName,
	grip_mode: StringName,
	default_project_name: String
) -> CraftedItemWIP:
	var current_wip: CraftedItemWIP = forge_controller.active_wip if forge_controller != null else null
	if not should_autosave_current_project(current_wip, wip_library):
		return null
	return save_current_project(
		forge_controller,
		wip_library,
		submitted_name,
		submitted_notes,
		stow_mode,
		grip_mode,
		default_project_name
	)

static func reset_active_project(
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState,
	default_project_name: String
) -> CraftedItemWIP:
	if forge_controller == null:
		return null
	if forge_controller.get_active_sample_preset_id() == StringName() and wip_library != null and not wip_library.selected_wip_id.is_empty():
		var saved_wip_clone: CraftedItemWIP = wip_library.get_saved_wip_clone(wip_library.selected_wip_id)
		if saved_wip_clone != null:
			return forge_controller.load_player_saved_wip(saved_wip_clone)
	if forge_controller.get_active_sample_preset_id() != StringName():
		return forge_controller.reset_active_sample_preset_wip()
	var current_wip: CraftedItemWIP = forge_controller.active_wip
	var builder_path_id: StringName = (
		CraftedItemWIP.normalize_builder_path_id(current_wip.forge_builder_path_id)
		if current_wip != null
		else CraftedItemWIP.BUILDER_PATH_MELEE
	)
	var builder_component_id: StringName = CraftedItemWIP.normalize_builder_component_id(
		builder_path_id,
		current_wip.forge_builder_component_id if current_wip != null else StringName()
	)
	return forge_controller.load_new_blank_wip_for_builder_path(
		default_project_name,
		builder_path_id,
		builder_component_id
	)

static func duplicate_current_project(
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState,
	submitted_name: String,
	submitted_notes: String,
	stow_mode: StringName,
	grip_mode: StringName,
	default_project_name: String
) -> CraftedItemWIP:
	var current_wip: CraftedItemWIP = ensure_editable_wip(forge_controller, default_project_name)
	if current_wip == null or wip_library == null or forge_controller == null:
		return null
	current_wip = apply_editor_metadata(
		forge_controller,
		current_wip,
		submitted_name,
		submitted_notes,
		stow_mode,
		grip_mode,
		default_project_name
	)
	var duplicated_wip: CraftedItemWIP = null
	if is_saved_project(current_wip, wip_library):
		var refreshed_saved_wip: CraftedItemWIP = wip_library.save_wip(current_wip)
		if refreshed_saved_wip != null:
			duplicated_wip = wip_library.duplicate_saved_wip(refreshed_saved_wip.wip_id)
	else:
		var clone_wip: CraftedItemWIP = current_wip.duplicate(true) as CraftedItemWIP
		clone_wip.wip_id = StringName("draft_%s_copy" % str(Time.get_unix_time_from_system()))
		clone_wip.forge_project_name = "%s Copy" % resolve_editor_project_name(current_wip, forge_controller, default_project_name)
		duplicated_wip = wip_library.save_wip(clone_wip)
	if duplicated_wip == null:
		return null
	return forge_controller.load_player_saved_wip(duplicated_wip)

static func delete_current_project(
	forge_controller: ForgeGridController,
	wip_library: PlayerForgeWipLibraryState,
	default_project_name: String
) -> CraftedItemWIP:
	var current_wip: CraftedItemWIP = ensure_editable_wip(forge_controller, default_project_name)
	if current_wip == null or wip_library == null or forge_controller == null:
		return null
	if not is_saved_project(current_wip, wip_library):
		return current_wip
	if not wip_library.delete_saved_wip(current_wip.wip_id):
		return current_wip
	var fallback_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(wip_library.selected_wip_id)
	if fallback_wip != null:
		return forge_controller.load_player_saved_wip(fallback_wip)
	return forge_controller.load_new_blank_wip(default_project_name)

static func _count_authored_cells(current_wip: CraftedItemWIP) -> int:
	if current_wip == null:
		return 0
	var total: int = 0
	for layer_atom: LayerAtom in current_wip.layers:
		if layer_atom == null:
			continue
		total += layer_atom.cells.size()
	return total
