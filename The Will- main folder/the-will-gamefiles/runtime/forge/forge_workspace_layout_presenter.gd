extends RefCounted
class_name ForgeWorkspaceLayoutPresenter

func apply_root_layout(
	viewport_size: Vector2,
	config: Dictionary,
	panel: Control,
	main_hbox: HBoxContainer,
	left_panel: Control,
	right_panel: Control,
	workspace_stage: Control
) -> bool:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	var compact_mode: bool = viewport_size.x <= float(config.get("compact_width_breakpoint", 0)) or viewport_size.y <= float(config.get("compact_height_breakpoint", 0))
	var smaller_axis: int = mini(int(round(viewport_size.x)), int(round(viewport_size.y)))
	var margin_ratio: float = float(config.get("compact_outer_margin_ratio", 0.0)) if compact_mode else float(config.get("wide_outer_margin_ratio", 0.0))
	var resolved_margin: float = float(clampi(
		int(round(float(smaller_axis) * margin_ratio)),
		int(config.get("minimum_outer_margin_px", 0)),
		int(config.get("maximum_outer_margin_px", 0))
	))
	panel.offset_left = resolved_margin
	panel.offset_top = resolved_margin
	panel.offset_right = -resolved_margin
	panel.offset_bottom = -resolved_margin

	main_hbox.add_theme_constant_override(
		"separation",
		int(config.get("compact_panel_separation", 0)) if compact_mode else int(config.get("wide_panel_separation", 0))
	)
	left_panel.custom_minimum_size.x = int(config.get("compact_left_panel_min_width", 0)) if compact_mode else int(config.get("wide_left_panel_min_width", 0))
	right_panel.custom_minimum_size.x = int(config.get("compact_right_panel_min_width", 0)) if compact_mode else int(config.get("wide_right_panel_min_width", 0))
	workspace_stage.custom_minimum_size.y = int(config.get("compact_workspace_stage_min_height", 0)) if compact_mode else int(config.get("wide_workspace_stage_min_height", 0))
	return compact_mode

func apply_detail_panel_layout(
	compact_mode: bool,
	config: Dictionary,
	project_panel: Control,
	project_notes_edit: Control,
	project_list: Control,
	inventory_list: Control,
	description_panel: Control,
	stats_panel: Control
) -> void:
	project_panel.custom_minimum_size.y = int(config.get("compact_project_panel_min_height", 0)) if compact_mode else int(config.get("wide_project_panel_min_height", 0))
	project_notes_edit.custom_minimum_size.y = int(config.get("compact_project_notes_min_height", 0)) if compact_mode else int(config.get("wide_project_notes_min_height", 0))
	project_list.custom_minimum_size.y = int(config.get("compact_project_list_min_height", 0)) if compact_mode else int(config.get("wide_project_list_min_height", 0))
	inventory_list.custom_minimum_size.y = int(config.get("compact_inventory_list_min_height", 0)) if compact_mode else int(config.get("wide_inventory_list_min_height", 0))
	description_panel.custom_minimum_size.y = int(config.get("compact_description_panel_min_height", 0)) if compact_mode else int(config.get("wide_description_panel_min_height", 0))
	stats_panel.custom_minimum_size.y = int(config.get("compact_stats_panel_min_height", 0)) if compact_mode else int(config.get("wide_stats_panel_min_height", 0))

func apply_action_button_layout(
	compact_mode: bool,
	config: Dictionary,
	action_buttons: Array[BaseButton],
	debug_vbox: Control
) -> void:
	var resolved_action_button_width: int = int(config.get("compact_action_button_min_width", 0)) if compact_mode else int(config.get("wide_action_button_min_width", 0))
	var resolved_action_button_height: int = int(config.get("compact_action_button_min_height", 0)) if compact_mode else int(config.get("wide_action_button_min_height", 0))
	for button: BaseButton in action_buttons:
		button.custom_minimum_size = Vector2(resolved_action_button_width, resolved_action_button_height)
	debug_vbox.custom_minimum_size = Vector2(
		config.get("compact_debug_popup_min_size", Vector2.ZERO) if compact_mode else config.get("wide_debug_popup_min_size", Vector2.ZERO)
	)

func sync_workspace_hosts(
	main_workspace_mode: StringName,
	workspace_view_free: StringName,
	workspace_view_plane: StringName,
	main_viewport_host: Control,
	inset_viewport_host: Control,
	free_view_panel: Control,
	plane_view_panel: Control,
	free_title_label: Label,
	plane_title_label: Label,
	flip_view_button: Button
) -> void:
	var primary_panel: Control = free_view_panel if main_workspace_mode == workspace_view_free else plane_view_panel
	var inset_panel: Control = plane_view_panel if main_workspace_mode == workspace_view_free else free_view_panel
	if primary_panel.get_parent() != main_viewport_host:
		primary_panel.reparent(main_viewport_host)
	if inset_panel.get_parent() != inset_viewport_host:
		inset_panel.reparent(inset_viewport_host)
	prepare_workspace_panel(primary_panel)
	prepare_workspace_panel(inset_panel)
	free_title_label.text = "Free 3D Workspace" if main_workspace_mode == workspace_view_free else "3D Inset View"
	plane_title_label.text = "2D Layer Map" if main_workspace_mode == workspace_view_plane else "2D Layer Minimap"
	flip_view_button.text = "2D Main" if main_workspace_mode == workspace_view_free else "3D Main"

func prepare_workspace_panel(panel_node: Control) -> void:
	panel_node.anchor_left = 0.0
	panel_node.anchor_top = 0.0
	panel_node.anchor_right = 1.0
	panel_node.anchor_bottom = 1.0
	panel_node.offset_left = 0.0
	panel_node.offset_top = 0.0
	panel_node.offset_right = 0.0
	panel_node.offset_bottom = 0.0
	panel_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_node.size_flags_vertical = Control.SIZE_EXPAND_FILL

func apply_workspace_layout(
	compact_mode: bool,
	config: Dictionary,
	workspace_stage: Control,
	inset_viewport_host: Control,
	main_viewport_host: Control,
	plane_viewport: Control,
	free_view_container: Control,
	free_view_panel: Control,
	plane_view_panel: Control,
	main_workspace_mode: StringName,
	workspace_view_free: StringName,
	workspace_view_plane: StringName
) -> void:
	var inset_size: Vector2 = Vector2(config.get("compact_workspace_inset_size", Vector2.ZERO) if compact_mode else config.get("wide_workspace_inset_size", Vector2.ZERO))
	var inset_margin: float = float(config.get("compact_workspace_inset_margin_px", 0)) if compact_mode else float(config.get("wide_workspace_inset_margin_px", 0))
	var stage_size: Vector2 = workspace_stage.size
	if stage_size.x <= 0.0 or stage_size.y <= 0.0:
		stage_size = workspace_stage.get_combined_minimum_size()
	var max_inset_size: Vector2 = Vector2(maxf(stage_size.x * 0.46, 160.0), maxf(stage_size.y * 0.46, 120.0))
	inset_size.x = minf(inset_size.x, max_inset_size.x)
	inset_size.y = minf(inset_size.y, max_inset_size.y)
	inset_viewport_host.position = Vector2(inset_margin, inset_margin)
	inset_viewport_host.size = inset_size
	main_viewport_host.position = Vector2.ZERO
	main_viewport_host.size = stage_size

	var plane_main_size: Vector2 = Vector2(config.get("compact_plane_main_viewport_min_size", Vector2.ZERO) if compact_mode else config.get("wide_plane_main_viewport_min_size", Vector2.ZERO))
	var plane_inset_size: Vector2 = Vector2(config.get("compact_plane_inset_viewport_min_size", Vector2.ZERO) if compact_mode else config.get("wide_plane_inset_viewport_min_size", Vector2.ZERO))
	var free_main_size: Vector2 = Vector2(config.get("compact_free_main_viewport_min_size", Vector2.ZERO) if compact_mode else config.get("wide_free_main_viewport_min_size", Vector2.ZERO))
	var free_inset_size: Vector2 = Vector2(config.get("compact_free_inset_viewport_min_size", Vector2.ZERO) if compact_mode else config.get("wide_free_inset_viewport_min_size", Vector2.ZERO))
	plane_viewport.custom_minimum_size = plane_main_size if main_workspace_mode == workspace_view_plane else plane_inset_size
	free_view_container.custom_minimum_size = free_main_size if main_workspace_mode == workspace_view_free else free_inset_size
	free_view_panel.custom_minimum_size = Vector2.ZERO
	plane_view_panel.custom_minimum_size = Vector2.ZERO

func sync_free_subviewport_size(free_view_container: Control, free_subviewport: SubViewport) -> void:
	var target_size: Vector2i = Vector2i(
		maxi(int(round(free_view_container.size.x)), 1),
		maxi(int(round(free_view_container.size.y)), 1)
	)
	if free_subviewport.size != target_size:
		free_subviewport.size = target_size
