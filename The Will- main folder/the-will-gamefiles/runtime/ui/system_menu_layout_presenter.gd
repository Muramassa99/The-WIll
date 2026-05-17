extends RefCounted
class_name SystemMenuLayoutPresenter

func apply_responsive_layout(
	viewport_size: Vector2,
	config: Dictionary,
	backdrop: ColorRect,
	panel: PanelContainer,
	nav_panel: PanelContainer,
	reset_page_button: Button,
	restore_defaults_button: Button,
	close_button: Button,
	page_scroll: ScrollContainer,
	page_stack: VBoxContainer,
	navigation_buttons: Array[Button],
	form_labels: Array[Label]
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
	panel.position = Vector2(resolved_margin, resolved_margin)
	panel.size = Vector2(
		maxf(viewport_size.x - (resolved_margin * 2.0), 1.0),
		maxf(viewport_size.y - (resolved_margin * 2.0), 1.0)
	)

	nav_panel.custom_minimum_size.x = int(config.get("compact_navigation_panel_min_width", 0)) if compact_mode else int(config.get("wide_navigation_panel_min_width", 0))
	var resolved_navigation_button_height: int = int(config.get("compact_navigation_button_min_height", 0)) if compact_mode else int(config.get("wide_navigation_button_min_height", 0))
	for button: Button in navigation_buttons:
		button.custom_minimum_size.y = resolved_navigation_button_height

	var resolved_label_width: int = int(config.get("compact_form_label_min_width", 0)) if compact_mode else int(config.get("wide_form_label_min_width", 0))
	for label: Label in form_labels:
		label.custom_minimum_size.x = resolved_label_width

	var resolved_footer_button_height: int = int(config.get("compact_footer_button_min_height", 0)) if compact_mode else int(config.get("wide_footer_button_min_height", 0))
	var resolved_footer_button_width: int = int(config.get("compact_footer_button_min_width", 0)) if compact_mode else int(config.get("wide_footer_button_min_width", 0))
	reset_page_button.custom_minimum_size = Vector2(resolved_footer_button_width, resolved_footer_button_height)
	restore_defaults_button.custom_minimum_size = Vector2(resolved_footer_button_width, resolved_footer_button_height)
	close_button.custom_minimum_size = Vector2(
		int(config.get("compact_close_button_min_width", 0)) if compact_mode else int(config.get("wide_close_button_min_width", 0)),
		resolved_footer_button_height
	)

	page_stack.custom_minimum_size.x = maxf(page_scroll.size.x - float(config.get("page_scroll_width_padding", 0)), 0.0)
	_sync_page_stack_scroll_size(page_scroll, page_stack, config)
	return compact_mode

func _sync_page_stack_scroll_size(page_scroll: ScrollContainer, page_stack: VBoxContainer, config: Dictionary) -> void:
	if page_scroll == null or page_stack == null:
		return
	var resolved_width: float = maxf(page_scroll.size.x - float(config.get("page_scroll_width_padding", 0)), 0.0)
	page_stack.custom_minimum_size.x = resolved_width
	var visible_page_height: float = 0.0
	for child: Node in page_stack.get_children():
		var page_control: Control = child as Control
		if page_control == null:
			continue
		page_control.custom_minimum_size.x = resolved_width
		page_control.size.x = resolved_width
		_sync_page_child_width(page_control, resolved_width)
		var content_height: float = _resolve_page_content_minimum_height(page_control)
		page_control.custom_minimum_size.y = content_height if page_control.visible else 0.0
		page_control.size.y = maxf(page_scroll.size.y, content_height) if page_control.visible else 0.0
		if page_control.visible:
			visible_page_height = maxf(visible_page_height, content_height)
	page_stack.custom_minimum_size.y = visible_page_height

func _sync_page_child_width(page_control: Control, resolved_width: float) -> void:
	if page_control == null:
		return
	for child: Node in page_control.get_children():
		var child_control: Control = child as Control
		if child_control == null:
			continue
		child_control.position.x = 0.0
		child_control.custom_minimum_size.x = resolved_width
		child_control.size.x = resolved_width

func _resolve_page_content_minimum_height(page_control: Control) -> float:
	if page_control == null:
		return 0.0
	var resolved_height: float = 0.0
	for child: Node in page_control.get_children():
		var child_control: Control = child as Control
		if child_control == null:
			continue
		resolved_height = maxf(resolved_height, child_control.get_combined_minimum_size().y)
	return resolved_height
