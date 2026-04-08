extends RefCounted
class_name SystemMenuSurfacePresenter

func get_page_id_map() -> Dictionary:
	return {
		"settings": &"settings",
		"controls": &"controls",
		"interface": &"interface",
		"social": &"social",
		"help": &"help",
	}

func build_layout_config(
	compact_width_breakpoint: int,
	compact_height_breakpoint: int,
	wide_outer_margin_ratio: float,
	compact_outer_margin_ratio: float,
	minimum_outer_margin_px: int,
	maximum_outer_margin_px: int,
	wide_navigation_panel_min_width: int,
	compact_navigation_panel_min_width: int,
	wide_navigation_button_min_height: int,
	compact_navigation_button_min_height: int,
	wide_form_label_min_width: int,
	compact_form_label_min_width: int,
	wide_footer_button_min_width: int,
	compact_footer_button_min_width: int,
	wide_close_button_min_width: int,
	compact_close_button_min_width: int,
	wide_footer_button_min_height: int,
	compact_footer_button_min_height: int,
	page_scroll_width_padding: int
) -> Dictionary:
	return {
		"compact_width_breakpoint": compact_width_breakpoint,
		"compact_height_breakpoint": compact_height_breakpoint,
		"wide_outer_margin_ratio": wide_outer_margin_ratio,
		"compact_outer_margin_ratio": compact_outer_margin_ratio,
		"minimum_outer_margin_px": minimum_outer_margin_px,
		"maximum_outer_margin_px": maximum_outer_margin_px,
		"wide_navigation_panel_min_width": wide_navigation_panel_min_width,
		"compact_navigation_panel_min_width": compact_navigation_panel_min_width,
		"wide_navigation_button_min_height": wide_navigation_button_min_height,
		"compact_navigation_button_min_height": compact_navigation_button_min_height,
		"wide_form_label_min_width": wide_form_label_min_width,
		"compact_form_label_min_width": compact_form_label_min_width,
		"wide_footer_button_min_width": wide_footer_button_min_width,
		"compact_footer_button_min_width": compact_footer_button_min_width,
		"wide_close_button_min_width": wide_close_button_min_width,
		"compact_close_button_min_width": compact_close_button_min_width,
		"wide_footer_button_min_height": wide_footer_button_min_height,
		"compact_footer_button_min_height": compact_footer_button_min_height,
		"page_scroll_width_padding": page_scroll_width_padding,
	}

func get_navigation_buttons(
	resume_button: Button,
	settings_button: Button,
	controls_button: Button,
	interface_button: Button,
	social_button: Button,
	help_button: Button,
	return_to_title_button: Button,
	quit_game_button: Button
) -> Array[Button]:
	return [
		resume_button,
		settings_button,
		controls_button,
		interface_button,
		social_button,
		help_button,
		return_to_title_button,
		quit_game_button,
	]

func get_form_labels(
	window_mode_label: Label,
	monitor_label: Label,
	resolution_label: Label,
	render_scale_label: Label,
	max_fps_label: Label,
	master_volume_label: Label,
	category_label: Label,
	ui_scale_label: Label,
	text_scale_label: Label
) -> Array[Label]:
	return [
		window_mode_label,
		monitor_label,
		resolution_label,
		render_scale_label,
		max_fps_label,
		master_volume_label,
		category_label,
		ui_scale_label,
		text_scale_label,
	]

func build_option_payload(
	window_mode_option: OptionButton,
	monitor_option: OptionButton,
	resolution_option: OptionButton,
	vsync_check_box: CheckBox,
	render_scale_option: OptionButton,
	max_fps_option: OptionButton,
	master_volume_slider: HSlider,
	master_volume_value_label: Label,
	master_mute_check_box: CheckBox,
	ui_scale_option: OptionButton,
	text_scale_option: OptionButton,
	controls_category_option: OptionButton
) -> Dictionary:
	return {
		"window_mode_option": window_mode_option,
		"monitor_option": monitor_option,
		"resolution_option": resolution_option,
		"vsync_check_box": vsync_check_box,
		"render_scale_option": render_scale_option,
		"max_fps_option": max_fps_option,
		"master_volume_slider": master_volume_slider,
		"master_volume_value_label": master_volume_value_label,
		"master_mute_check_box": master_mute_check_box,
		"ui_scale_option": ui_scale_option,
		"text_scale_option": text_scale_option,
		"controls_category_option": controls_category_option,
	}

func build_controls_payload(
	bindings_container: VBoxContainer,
	bindings_status_label: Label,
	begin_rebind_callable: Callable,
	selected_controls_category: String
) -> Dictionary:
	return {
		"bindings_container": bindings_container,
		"bindings_status_label": bindings_status_label,
		"begin_rebind_callable": begin_rebind_callable,
		"selected_controls_category": selected_controls_category,
	}
