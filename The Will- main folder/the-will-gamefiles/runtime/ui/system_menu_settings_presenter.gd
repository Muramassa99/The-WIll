extends RefCounted
class_name SystemMenuSettingsPresenter

const UserSettingsStateScript = preload("res://core/models/user_settings_state.gd")
const UserSettingsRuntimeScript = preload("res://runtime/system/user_settings_runtime.gd")

func configure_static_options(
	window_mode_option: OptionButton,
	monitor_option: OptionButton,
	render_scale_option: OptionButton,
	max_fps_option: OptionButton,
	resolution_option: OptionButton,
	ui_scale_option: OptionButton,
	text_scale_option: OptionButton,
	controls_category_option: OptionButton,
	resolution_options: Array,
	max_fps_options: Array
) -> void:
	window_mode_option.clear()
	window_mode_option.add_item("Windowed")
	window_mode_option.add_item("Borderless")
	window_mode_option.add_item("Fullscreen")

	monitor_option.clear()
	var screen_count: int = maxi(DisplayServer.get_screen_count(), 1)
	for display_index in range(screen_count):
		monitor_option.add_item("Monitor %d" % (display_index + 1))

	render_scale_option.clear()
	render_scale_option.add_item("Performance")
	render_scale_option.add_item("Balanced")
	render_scale_option.add_item("Quality")

	max_fps_option.clear()
	for fps_value in max_fps_options:
		max_fps_option.add_item("Unlimited" if int(fps_value) == 0 else "%d FPS" % int(fps_value))

	resolution_option.clear()
	for resolution_variant in resolution_options:
		var resolution: Vector2i = resolution_variant
		resolution_option.add_item("%d x %d" % [resolution.x, resolution.y])

	ui_scale_option.clear()
	text_scale_option.clear()
	for label_text: String in ["Small", "Normal", "Large"]:
		ui_scale_option.add_item(label_text)
		text_scale_option.add_item(label_text)

	controls_category_option.clear()
	for category_name: String in UserSettingsRuntimeScript.get_categories():
		controls_category_option.add_item(UserSettingsRuntimeScript.get_category_display_name(category_name))

func refresh_from_state(
	settings_state: UserSettingsState,
	selected_controls_category: String,
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
	controls_category_option: OptionButton,
	resolution_options: Array,
	max_fps_options: Array
) -> String:
	window_mode_option.select(_find_window_mode_index(settings_state.window_mode))
	if monitor_option.item_count > 0:
		monitor_option.select(clampi(settings_state.display_index, 0, maxi(monitor_option.item_count - 1, 0)))
	resolution_option.select(_find_resolution_index(settings_state.resolution, resolution_options))
	vsync_check_box.button_pressed = settings_state.vsync_enabled
	render_scale_option.select(_scale_preset_to_index(settings_state.render_scale_preset))
	max_fps_option.select(_find_max_fps_index(settings_state.max_fps, max_fps_options))
	master_volume_slider.value = settings_state.master_volume_linear
	master_mute_check_box.button_pressed = settings_state.master_muted
	master_volume_value_label.text = "%d%%" % int(round(settings_state.master_volume_linear * 100.0))
	ui_scale_option.select(_scale_preset_to_index(settings_state.ui_scale_preset))
	text_scale_option.select(_scale_preset_to_index(settings_state.text_scale_preset))

	var resolved_controls_category: String = selected_controls_category
	if controls_category_option.item_count > 0:
		if resolved_controls_category.is_empty():
			resolved_controls_category = UserSettingsRuntimeScript.get_categories()[0]
		controls_category_option.select(_find_category_index(resolved_controls_category))
	return resolved_controls_category

func apply_window_mode_selection(settings_state: UserSettingsState, index: int) -> String:
	match index:
		1:
			settings_state.window_mode = UserSettingsStateScript.BORDERLESS
		2:
			settings_state.window_mode = UserSettingsStateScript.FULLSCREEN
		_:
			settings_state.window_mode = UserSettingsStateScript.WINDOWED
	return "Window mode updated."

func apply_monitor_selection(settings_state: UserSettingsState, index: int) -> String:
	settings_state.display_index = index
	return "Monitor target updated."

func apply_resolution_selection(settings_state: UserSettingsState, index: int, resolution_options: Array) -> String:
	settings_state.resolution = resolution_options[index]
	return "Resolution updated."

func apply_vsync_toggle(settings_state: UserSettingsState, enabled: bool) -> String:
	settings_state.vsync_enabled = enabled
	return "V-Sync preference updated."

func apply_render_scale_selection(settings_state: UserSettingsState, index: int) -> String:
	settings_state.render_scale_preset = _index_to_scale_preset(index)
	return "3D render scale updated."

func apply_max_fps_selection(settings_state: UserSettingsState, index: int, max_fps_options: Array) -> String:
	settings_state.max_fps = int(max_fps_options[index])
	return "Max FPS updated."

func apply_master_volume_change(settings_state: UserSettingsState, value: float, master_volume_value_label: Label) -> String:
	settings_state.master_volume_linear = value
	master_volume_value_label.text = "%d%%" % int(round(value * 100.0))
	return "Master volume updated."

func apply_master_mute_toggle(settings_state: UserSettingsState, enabled: bool) -> String:
	settings_state.master_muted = enabled
	return "Master mute updated."

func apply_ui_scale_selection(settings_state: UserSettingsState, index: int) -> String:
	settings_state.ui_scale_preset = _index_to_scale_preset(index)
	return "UI scale updated."

func apply_text_scale_selection(settings_state: UserSettingsState, index: int) -> String:
	settings_state.text_scale_preset = _index_to_scale_preset(index)
	return "Text scale updated."

func _find_resolution_index(target_resolution: Vector2i, resolution_options: Array) -> int:
	for index in range(resolution_options.size()):
		if resolution_options[index] == target_resolution:
			return index
	return 1

func _find_window_mode_index(window_mode: StringName) -> int:
	match window_mode:
		UserSettingsStateScript.BORDERLESS:
			return 1
		UserSettingsStateScript.FULLSCREEN:
			return 2
		_:
			return 0

func _find_max_fps_index(target_fps: int, max_fps_options: Array) -> int:
	for index in range(max_fps_options.size()):
		if int(max_fps_options[index]) == target_fps:
			return index
	return 3

func _find_category_index(category_name: String) -> int:
	var categories: Array[String] = UserSettingsRuntimeScript.get_categories()
	for index in range(categories.size()):
		if categories[index] == category_name:
			return index
	return 0

func _scale_preset_to_index(scale_preset: StringName) -> int:
	match scale_preset:
		UserSettingsStateScript.SCALE_SMALL:
			return 0
		UserSettingsStateScript.SCALE_LARGE:
			return 2
		_:
			return 1

func _index_to_scale_preset(index: int) -> StringName:
	match index:
		0:
			return UserSettingsStateScript.SCALE_SMALL
		2:
			return UserSettingsStateScript.SCALE_LARGE
		_:
			return UserSettingsStateScript.SCALE_NORMAL
