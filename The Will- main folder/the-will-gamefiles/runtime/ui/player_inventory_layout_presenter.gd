extends RefCounted
class_name PlayerInventoryLayoutPresenter

func apply_responsive_layout(
	viewport_size: Vector2,
	config: Dictionary,
	backdrop: ColorRect,
	panel: PanelContainer,
	page_scroll: ScrollContainer,
	page_buttons: Array[Button],
	action_buttons: Array[Button],
	item_lists: Array[ItemList]
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
	page_scroll.custom_minimum_size = Vector2.ZERO

	var page_button_min_width: int = int(config.get("compact_page_button_min_width", 0)) if compact_mode else int(config.get("wide_page_button_min_width", 0))
	var action_button_min_width: int = int(config.get("compact_action_button_min_width", 0)) if compact_mode else int(config.get("wide_action_button_min_width", 0))
	var action_button_min_height: int = int(config.get("compact_action_button_min_height", 0)) if compact_mode else int(config.get("wide_action_button_min_height", 0))
	for page_button: Button in page_buttons:
		page_button.custom_minimum_size = Vector2(page_button_min_width, action_button_min_height)
	for action_button: Button in action_buttons:
		action_button.custom_minimum_size = Vector2(action_button_min_width, action_button_min_height)

	var resolved_item_list_min_height: int = int(config.get("compact_item_list_min_height", 0)) if compact_mode else int(config.get("wide_item_list_min_height", 0))
	var item_list_height_ratio: float = float(config.get("compact_item_list_height_ratio", 0.0)) if compact_mode else float(config.get("wide_item_list_height_ratio", 0.0))
	resolved_item_list_min_height = clampi(
		int(round(viewport_size.y * item_list_height_ratio)),
		int(config.get("minimum_item_list_min_height", 0)),
		resolved_item_list_min_height
	)
	for item_list: ItemList in item_lists:
		item_list.custom_minimum_size.y = resolved_item_list_min_height
	return compact_mode
