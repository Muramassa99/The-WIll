extends RefCounted
class_name ForgeProjectPanelPresenter

const ForgeProjectWorkflowScript = preload("res://runtime/forge/forge_project_workflow.gd")

func populate_stow_position_options(option_button: OptionButton) -> void:
	option_button.clear()
	var stow_popup: PopupMenu = option_button.get_popup()
	for _popup_item_index: int in range(stow_popup.get_item_count()):
		stow_popup.remove_item(0)
	for stow_index: int in range(CraftedItemWIP.get_stow_position_modes().size()):
		var stow_mode: StringName = CraftedItemWIP.get_stow_position_modes()[stow_index]
		option_button.add_item(CraftedItemWIP.get_stow_position_label(stow_mode), stow_index)
		option_button.set_item_metadata(stow_index, stow_mode)
		stow_popup.set_item_tooltip(stow_index, CraftedItemWIP.get_stow_position_note(stow_mode))
	select_project_stow_position(option_button, CraftedItemWIP.STOW_SHOULDER_HANGING)

func populate_grip_style_options(option_button: OptionButton) -> void:
	option_button.clear()
	var grip_popup: PopupMenu = option_button.get_popup()
	for _popup_item_index: int in range(grip_popup.get_item_count()):
		grip_popup.remove_item(0)
	for grip_index: int in range(CraftedItemWIP.get_grip_style_modes().size()):
		var grip_mode: StringName = CraftedItemWIP.get_grip_style_modes()[grip_index]
		option_button.add_item(CraftedItemWIP.get_grip_style_label(grip_mode), grip_index)
		option_button.set_item_metadata(grip_index, grip_mode)
		grip_popup.set_item_tooltip(grip_index, CraftedItemWIP.get_grip_style_note(grip_mode))
	select_project_grip_style(option_button, CraftedItemWIP.GRIP_NORMAL)

func select_project_stow_position(option_button: OptionButton, stow_mode: StringName) -> void:
	var normalized_mode: StringName = CraftedItemWIP.normalize_stow_position_mode(stow_mode)
	for stow_index: int in range(option_button.get_item_count()):
		if option_button.get_item_metadata(stow_index) == normalized_mode:
			option_button.select(stow_index)
			return
	if option_button.get_item_count() > 0:
		option_button.select(0)

func get_selected_project_stow_position(option_button: OptionButton) -> StringName:
	var selected_index: int = option_button.selected
	if selected_index < 0 or selected_index >= option_button.get_item_count():
		return CraftedItemWIP.STOW_SHOULDER_HANGING
	return CraftedItemWIP.normalize_stow_position_mode(option_button.get_item_metadata(selected_index))

func select_project_grip_style(option_button: OptionButton, grip_mode: StringName, current_wip: CraftedItemWIP = null) -> void:
	var normalized_mode: StringName = CraftedItemWIP.normalize_grip_style_mode(grip_mode)
	if current_wip != null:
		normalized_mode = CraftedItemWIP.resolve_supported_grip_style(
			normalized_mode,
			current_wip.forge_intent,
			current_wip.equipment_context
		)
	for grip_index: int in range(option_button.get_item_count()):
		if option_button.get_item_metadata(grip_index) == normalized_mode:
			option_button.select(grip_index)
			return
	if option_button.get_item_count() > 0:
		option_button.select(0)

func get_selected_project_grip_style(option_button: OptionButton) -> StringName:
	var selected_index: int = option_button.selected
	if selected_index < 0 or selected_index >= option_button.get_item_count():
		return CraftedItemWIP.GRIP_NORMAL
	return CraftedItemWIP.normalize_grip_style_mode(option_button.get_item_metadata(selected_index))

func refresh_grip_style_option_availability(option_button: OptionButton, current_wip: CraftedItemWIP) -> void:
	var grip_popup: PopupMenu = option_button.get_popup()
	var reverse_supported: bool = current_wip != null and CraftedItemWIP.supports_reverse_grip_for_context(current_wip.forge_intent, current_wip.equipment_context)
	for grip_index: int in range(option_button.get_item_count()):
		var grip_mode: StringName = option_button.get_item_metadata(grip_index)
		var is_disabled: bool = grip_mode == CraftedItemWIP.GRIP_REVERSE and not reverse_supported
		grip_popup.set_item_disabled(grip_index, is_disabled)

func show_stow_position_hint(
	popup: PopupPanel,
	label: Label,
	stow_mode: StringName,
	viewport_size: Vector2,
	mouse_position: Vector2
) -> void:
	var tooltip_text: String = CraftedItemWIP.get_stow_position_note(stow_mode)
	if tooltip_text.is_empty():
		hide_hint(popup)
		return
	label.text = tooltip_text
	_show_hint_popup(popup, viewport_size, mouse_position, Vector2(260.0, 80.0))

func show_grip_style_hint(
	popup: PopupPanel,
	label: Label,
	grip_mode: StringName,
	viewport_size: Vector2,
	mouse_position: Vector2
) -> void:
	var tooltip_text: String = CraftedItemWIP.get_grip_style_note(grip_mode)
	if tooltip_text.is_empty():
		hide_hint(popup)
		return
	label.text = tooltip_text
	_show_hint_popup(popup, viewport_size, mouse_position, Vector2(300.0, 96.0))

func hide_hint(popup: PopupPanel) -> void:
	if popup.visible:
		popup.hide()

func sync_project_list_selection(
	project_list: ItemList,
	project_catalog: Array[Dictionary],
	current_wip: CraftedItemWIP,
	active_sample_preset_id: StringName
) -> void:
	project_list.deselect_all()
	if current_wip == null:
		return
	for project_index: int in range(project_catalog.size()):
		var entry: Dictionary = project_catalog[project_index]
		var entry_type: StringName = entry.get("entry_type", &"")
		if entry_type == &"authoring_preset":
			if entry.get("sample_preset_id", &"") == active_sample_preset_id:
				project_list.select(project_index)
				return
		elif entry_type == &"saved":
			if current_wip.wip_id == entry.get("saved_wip_id", &""):
				project_list.select(project_index)
				return

func refresh_builder_component_tabs(
	current_wip: CraftedItemWIP,
	builder_component_tabs: Control,
	builder_component_bow_button: BaseButton,
	builder_component_quiver_button: BaseButton,
	view_tuning: ForgeViewTuningDef
) -> void:
	var builder_path_id: StringName = (
		CraftedItemWIP.normalize_builder_path_id(current_wip.forge_builder_path_id)
		if current_wip != null
		else CraftedItemWIP.BUILDER_PATH_MELEE
	)
	var show_component_tabs: bool = current_wip != null and CraftedItemWIP.has_multiple_builder_components(builder_path_id)
	builder_component_tabs.visible = show_component_tabs
	if not show_component_tabs:
		builder_component_bow_button.button_pressed = false
		builder_component_quiver_button.button_pressed = false
		return
	var current_component_id: StringName = CraftedItemWIP.normalize_builder_component_id(
		builder_path_id,
		current_wip.forge_builder_component_id
	)
	_apply_builder_component_button_state(
		builder_component_bow_button,
		current_component_id == CraftedItemWIP.BUILDER_COMPONENT_BOW,
		view_tuning
	)
	_apply_builder_component_button_state(
		builder_component_quiver_button,
		current_component_id == CraftedItemWIP.BUILDER_COMPONENT_QUIVER,
		view_tuning
	)

func commit_project_metadata_if_visible(
	panel_visible: bool,
	apply_project_metadata: Callable,
	refresh_project_panel_callback: Callable,
	refresh_status_text: Callable
) -> void:
	if not panel_visible:
		return
	apply_project_metadata.call()
	refresh_project_panel_callback.call()
	refresh_status_text.call()

func handle_stow_position_popup_focus(
	focused_id: int,
	option_button: OptionButton,
	show_hint: Callable,
	hide_hint_callback: Callable
) -> void:
	if focused_id < 0 or focused_id >= option_button.get_item_count():
		hide_hint_callback.call()
		return
	var stow_mode: StringName = option_button.get_item_metadata(focused_id)
	show_hint.call(stow_mode)

func handle_grip_style_popup_focus(
	focused_id: int,
	option_button: OptionButton,
	show_hint: Callable,
	hide_hint_callback: Callable
) -> void:
	if focused_id < 0 or focused_id >= option_button.get_item_count():
		hide_hint_callback.call()
		return
	var grip_mode: StringName = option_button.get_item_metadata(focused_id)
	show_hint.call(grip_mode)

func handle_project_list_item_clicked(
	index: int,
	project_catalog: Array[Dictionary],
	project_list: ItemList,
	load_selected_project: Callable
) -> void:
	if index < 0 or index >= project_catalog.size():
		return
	project_list.select(index)
	load_selected_project.call()

func refresh_project_panel(
	forge_controller: ForgeGridController,
	current_wip: CraftedItemWIP,
	wip_library: PlayerForgeWipLibraryState,
	project_name_edit: LineEdit,
	project_notes_edit: TextEdit,
	project_stow_position_option_button: OptionButton,
	project_grip_style_option_button: OptionButton,
	project_source_label: Label,
	new_project_button: Button,
	project_list: ItemList
) -> Array[Dictionary]:
	project_list.clear()
	if current_wip != null:
		current_wip.grip_style_mode = CraftedItemWIP.resolve_supported_grip_style(
			current_wip.grip_style_mode,
			current_wip.forge_intent,
			current_wip.equipment_context
		)
	project_name_edit.editable = current_wip != null
	project_notes_edit.editable = current_wip != null
	project_stow_position_option_button.disabled = current_wip == null
	project_grip_style_option_button.disabled = current_wip == null
	project_name_edit.text = ForgeProjectWorkflowScript.resolve_editor_project_name(
		current_wip,
		forge_controller,
		ForgeProjectWorkflowScript.build_default_project_name(wip_library)
	)
	project_notes_edit.text = current_wip.forge_project_notes if current_wip != null else ""
	select_project_stow_position(
		project_stow_position_option_button,
		current_wip.stow_position_mode if current_wip != null else CraftedItemWIP.STOW_SHOULDER_HANGING
	)
	refresh_grip_style_option_availability(project_grip_style_option_button, current_wip)
	select_project_grip_style(
		project_grip_style_option_button,
		current_wip.grip_style_mode if current_wip != null else CraftedItemWIP.GRIP_NORMAL,
		current_wip
	)
	project_source_label.text = ForgeProjectWorkflowScript.resolve_project_source_text(current_wip, forge_controller, wip_library)
	new_project_button.disabled = forge_controller == null
	var project_catalog: Array[Dictionary] = ForgeProjectWorkflowScript.build_project_catalog(forge_controller, wip_library)
	for entry: Dictionary in project_catalog:
		var item_index: int = project_list.add_item(String(entry.get("display_name", "Project")))
		project_list.set_item_metadata(item_index, entry)
		var description: String = String(entry.get("description", "")).strip_edges()
		if not description.is_empty():
			project_list.set_item_tooltip(item_index, description)
	sync_project_list_selection(
		project_list,
		project_catalog,
		current_wip,
		forge_controller.get_active_sample_preset_id() if forge_controller != null else StringName()
	)
	return project_catalog

func _show_hint_popup(
	popup: PopupPanel,
	viewport_size: Vector2,
	mouse_position: Vector2,
	popup_size: Vector2
) -> void:
	var popup_position: Vector2 = mouse_position + Vector2(24.0, -8.0)
	if popup_position.x + popup_size.x > viewport_size.x - 8.0:
		popup_position.x = mouse_position.x - popup_size.x - 24.0
	if popup_position.y + popup_size.y > viewport_size.y - 8.0:
		popup_position.y = viewport_size.y - popup_size.y - 8.0
	popup_position.x = clampf(popup_position.x, 8.0, maxf(8.0, viewport_size.x - popup_size.x - 8.0))
	popup_position.y = clampf(popup_position.y, 8.0, maxf(8.0, viewport_size.y - popup_size.y - 8.0))
	popup.position = popup_position
	popup.size = popup_size
	popup.popup()

func _apply_builder_component_button_state(button: BaseButton, is_active: bool, view_tuning: ForgeViewTuningDef) -> void:
	button.button_pressed = is_active
	button.modulate = view_tuning.ui_tab_active_color if is_active else view_tuning.ui_tab_inactive_color
