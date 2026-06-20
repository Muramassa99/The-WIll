extends RefCounted
class_name ForgeBenchPanelPresenter

func refresh_inventory(
	material_catalog_presenter: RefCounted,
	material_catalog: Array[Dictionary],
	current_inventory_page: StringName,
	search_text: String,
	selected_material_variant_id: StringName,
	view_tuning: ForgeViewTuningDef,
	inventory_list: ItemList,
	owned_tab_button: BaseButton,
	all_tab_button: BaseButton,
	weapon_tab_button: BaseButton,
	page_owned: StringName,
	page_all: StringName,
	page_weapon: StringName
) -> Array[Dictionary]:
	var visible_inventory_entries: Array[Dictionary] = material_catalog_presenter.build_visible_inventory_entries(
		material_catalog,
		current_inventory_page,
		search_text
	)
	inventory_list.clear()
	for entry: Dictionary in visible_inventory_entries:
		var quantity: int = int(entry.get("quantity", 0))
		var display_name: String = String(entry.get("display_name", ""))
		var material_id: StringName = entry.get("material_id", &"")
		var is_builder_marker: bool = bool(entry.get("is_builder_marker", false))
		var status_suffix: String = ""
		if not is_builder_marker:
			status_suffix = " x%d" % quantity if quantity > 0 else " (0)"
		var item_index: int = inventory_list.add_item(display_name + status_suffix)
		var item_color: Color = view_tuning.ui_inventory_owned_color if quantity > 0 else view_tuning.ui_inventory_empty_color
		if is_builder_marker:
			item_color = entry.get("builder_marker_color", view_tuning.ui_inventory_owned_color)
		inventory_list.set_item_custom_fg_color(item_index, item_color)
		inventory_list.set_item_metadata(item_index, material_id)
		if material_id == selected_material_variant_id:
			inventory_list.select(item_index)
	_apply_tab_button_state(owned_tab_button, current_inventory_page == page_owned, view_tuning)
	_apply_tab_button_state(all_tab_button, current_inventory_page == page_all, view_tuning)
	_apply_tab_button_state(weapon_tab_button, current_inventory_page == page_weapon, view_tuning)
	return visible_inventory_entries

func refresh_material_panels(
	material_catalog_presenter: RefCounted,
	material_catalog: Array[Dictionary],
	selected_material_variant_id: StringName,
	material_description_text: RichTextLabel,
	material_stats_text: RichTextLabel
) -> void:
	var entry: Dictionary = material_catalog_presenter.get_material_entry(material_catalog, selected_material_variant_id)
	material_description_text.text = material_catalog_presenter.build_material_description_text(entry)
	material_stats_text.text = material_catalog_presenter.build_material_stats_text(entry)

func refresh_left_panel(
	workspace_presentation: ForgeWorkspacePresentation,
	forge_controller: ForgeGridController,
	current_wip: CraftedItemWIP,
	active_plane: StringName,
	active_layer: int,
	max_layer_for_plane: int,
	active_tool: StringName,
	armed_material_display_name: String,
	stage2_refinement_mode_active: bool,
	shape_rotation_degrees: int,
	view_tuning: ForgeViewTuningDef,
	layer_status_label: Label,
	plane_status_label: Label,
	armed_material_label: Label,
	capacity_label: Label,
	capacity_bar: ProgressBar,
	place_category_button: BaseButton,
	erase_category_button: BaseButton,
	single_tool_button: BaseButton,
	pick_tool_button: BaseButton,
	xy_plane_button: BaseButton,
	zx_plane_button: BaseButton,
	zy_plane_button: BaseButton
) -> void:
	if forge_controller == null:
		return
	var panel_state: Dictionary = workspace_presentation.build_left_panel_state(
		forge_controller,
		current_wip,
		active_plane,
		active_layer,
		max_layer_for_plane,
		active_tool,
		armed_material_display_name,
		stage2_refinement_mode_active,
		shape_rotation_degrees
	)
	layer_status_label.text = String(panel_state.get("layer_status_text", ""))
	plane_status_label.text = String(panel_state.get("plane_status_text", ""))
	armed_material_label.text = String(panel_state.get("armed_material_text", ""))
	capacity_label.text = String(panel_state.get("capacity_text", ""))
	capacity_bar.max_value = 1.0
	capacity_bar.value = float(panel_state.get("capacity_ratio", 0.0))
	_apply_button_state(place_category_button, bool(panel_state.get("place_active", false)), view_tuning)
	_apply_button_state(erase_category_button, bool(panel_state.get("erase_active", false)), view_tuning)
	_apply_button_state(single_tool_button, bool(panel_state.get("place_active", false)), view_tuning)
	_apply_button_state(pick_tool_button, bool(panel_state.get("pick_active", false)), view_tuning)
	_apply_button_state(xy_plane_button, bool(panel_state.get("xy_active", false)), view_tuning)
	_apply_button_state(zx_plane_button, bool(panel_state.get("zx_active", false)), view_tuning)
	_apply_button_state(zy_plane_button, bool(panel_state.get("zy_active", false)), view_tuning)

func refresh_status_text(
	workspace_presentation: ForgeWorkspacePresentation,
	forge_controller: ForgeGridController,
	current_wip: CraftedItemWIP,
	active_plane: StringName,
	active_layer: int,
	active_tool: StringName,
	active_project_display_name: String,
	selected_material_display_name: String,
	armed_material_display_name: String,
	material_lookup: Dictionary,
	stage2_refinement_mode_active: bool,
	shape_rotation_degrees: int,
	status_text: RichTextLabel
) -> String:
	var debug_text: String = workspace_presentation.build_status_text(
		forge_controller,
		current_wip,
		active_plane,
		active_layer,
		active_tool,
		active_project_display_name,
		selected_material_display_name,
		armed_material_display_name,
		material_lookup,
		stage2_refinement_mode_active,
		shape_rotation_degrees
	)
	status_text.text = debug_text
	return debug_text

func _apply_button_state(button: BaseButton, is_active: bool, view_tuning: ForgeViewTuningDef) -> void:
	button.modulate = view_tuning.ui_button_active_color if is_active else view_tuning.ui_button_inactive_color

func _apply_tab_button_state(button: BaseButton, is_active: bool, view_tuning: ForgeViewTuningDef) -> void:
	button.modulate = view_tuning.ui_tab_active_color if is_active else view_tuning.ui_tab_inactive_color
