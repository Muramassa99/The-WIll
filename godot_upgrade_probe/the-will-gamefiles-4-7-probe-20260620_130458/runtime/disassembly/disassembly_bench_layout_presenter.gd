extends RefCounted
class_name DisassemblyBenchLayoutPresenter

func apply_responsive_layout(
	viewport_size: Vector2,
	config: Dictionary,
	backdrop: ColorRect,
	panel: PanelContainer,
	main_hbox: HBoxContainer,
	inventory_panel: PanelContainer,
	output_panel: PanelContainer,
	selected_panel: PanelContainer,
	inventory_list: ItemList,
	selected_list: ItemList,
	output_preview_list: ItemList,
	warning_panel: PanelContainer,
	disassemble_button: Button,
	clear_selection_button: Button,
	extract_blueprint_button: Button,
	select_skill_button: Button,
	close_button: Button
) -> bool:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	var compact_mode: bool = viewport_size.x < float(config.get("compact_width_breakpoint", 0)) or viewport_size.y < float(config.get("compact_height_breakpoint", 0))
	var margin_ratio: float = float(config.get("compact_outer_margin_ratio", 0.0)) if compact_mode else float(config.get("wide_outer_margin_ratio", 0.0))
	var smaller_axis: int = mini(int(round(viewport_size.x)), int(round(viewport_size.y)))
	var resolved_margin: float = float(clampi(
		int(round(float(smaller_axis) * margin_ratio)),
		int(config.get("minimum_outer_margin_px", 0)),
		int(config.get("maximum_outer_margin_px", 0))
	))
	backdrop.position = Vector2.ZERO
	backdrop.size = viewport_size
	panel.offset_left = resolved_margin
	panel.offset_top = resolved_margin
	panel.offset_right = -resolved_margin
	panel.offset_bottom = -resolved_margin

	main_hbox.add_theme_constant_override(
		"separation",
		int(config.get("compact_panel_separation", 0)) if compact_mode else int(config.get("wide_panel_separation", 0))
	)
	inventory_panel.custom_minimum_size.x = int(config.get("compact_side_panel_min_width", 0)) if compact_mode else int(config.get("wide_side_panel_min_width", 0))
	selected_panel.custom_minimum_size.x = int(config.get("compact_side_panel_min_width", 0)) if compact_mode else int(config.get("wide_side_panel_min_width", 0))
	output_panel.custom_minimum_size.x = int(config.get("compact_center_panel_min_width", 0)) if compact_mode else int(config.get("wide_center_panel_min_width", 0))

	var resolved_item_list_min_height: int = int(config.get("compact_item_list_min_height", 0)) if compact_mode else int(config.get("wide_item_list_min_height", 0))
	inventory_list.custom_minimum_size.y = resolved_item_list_min_height
	selected_list.custom_minimum_size.y = resolved_item_list_min_height
	output_preview_list.custom_minimum_size.y = resolved_item_list_min_height
	warning_panel.custom_minimum_size.y = int(config.get("compact_warning_panel_min_height", 0)) if compact_mode else int(config.get("wide_warning_panel_min_height", 0))

	var resolved_button_width: int = int(config.get("compact_action_button_min_width", 0)) if compact_mode else int(config.get("wide_action_button_min_width", 0))
	var resolved_button_height: int = int(config.get("compact_action_button_min_height", 0)) if compact_mode else int(config.get("wide_action_button_min_height", 0))
	disassemble_button.custom_minimum_size = Vector2(resolved_button_width, resolved_button_height)
	clear_selection_button.custom_minimum_size = Vector2(resolved_button_width, resolved_button_height)
	extract_blueprint_button.custom_minimum_size = Vector2(resolved_button_width, resolved_button_height)
	select_skill_button.custom_minimum_size = Vector2(resolved_button_width, resolved_button_height)
	close_button.custom_minimum_size = Vector2(
		int(config.get("compact_footer_button_min_width", 0)) if compact_mode else int(config.get("wide_footer_button_min_width", 0)),
		resolved_button_height
	)
	return compact_mode
