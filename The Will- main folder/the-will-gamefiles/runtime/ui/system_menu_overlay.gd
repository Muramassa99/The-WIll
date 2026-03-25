extends CanvasLayer
class_name SystemMenuOverlay

const UserSettingsStateScript = preload("res://core/models/user_settings_state.gd")
const UserSettingsRuntimeScript = preload("res://runtime/system/user_settings_runtime.gd")

const PAGE_SETTINGS := &"settings"
const PAGE_CONTROLS := &"controls"
const PAGE_INTERFACE := &"interface"
const PAGE_SOCIAL := &"social"
const PAGE_HELP := &"help"
const FOOTER_STATUS_DEFAULT := "World simulation continues while this overlay is open. Return to Title is not wired in this workspace yet."

const RESOLUTION_OPTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

const MAX_FPS_OPTIONS := [0, 30, 60, 120, 144, 240]

@export_category("Responsive Layout")
@export var compact_width_breakpoint: int = 1280
@export var compact_height_breakpoint: int = 760
@export_range(0.0, 0.25, 0.005) var wide_outer_margin_ratio: float = 0.055
@export_range(0.0, 0.25, 0.005) var compact_outer_margin_ratio: float = 0.035
@export var minimum_outer_margin_px: int = 16
@export var maximum_outer_margin_px: int = 72
@export var wide_navigation_panel_min_width: int = 280
@export var compact_navigation_panel_min_width: int = 220
@export var wide_navigation_button_min_height: int = 42
@export var compact_navigation_button_min_height: int = 34
@export var wide_form_label_min_width: int = 180
@export var compact_form_label_min_width: int = 124
@export var wide_footer_button_min_width: int = 220
@export var compact_footer_button_min_width: int = 160
@export var wide_close_button_min_width: int = 180
@export var compact_close_button_min_width: int = 140
@export var wide_footer_button_min_height: int = 42
@export var compact_footer_button_min_height: int = 36
@export var page_scroll_width_padding: int = 6

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Panel
@onready var main_hbox: HBoxContainer = $Panel/MarginContainer/RootVBox/MainHBox
@onready var nav_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainHBox/NavPanel
@onready var page_title_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageHeader/PageTitleLabel
@onready var page_subtitle_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageHeader/PageSubtitleLabel
@onready var page_scroll: ScrollContainer = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll
@onready var page_stack: VBoxContainer = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack
@onready var settings_page: Control = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SettingsPage
@onready var controls_page: Control = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/ControlsPage
@onready var interface_page: Control = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/InterfacePage
@onready var social_page: Control = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SocialPage
@onready var help_page: Control = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/HelpPage
@onready var resume_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/NavPanel/MarginContainer/NavVBox/ResumeButton
@onready var settings_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/NavPanel/MarginContainer/NavVBox/SettingsButton
@onready var controls_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/NavPanel/MarginContainer/NavVBox/ControlsButton
@onready var interface_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/NavPanel/MarginContainer/NavVBox/InterfaceButton
@onready var social_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/NavPanel/MarginContainer/NavVBox/SocialButton
@onready var help_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/NavPanel/MarginContainer/NavVBox/HelpButton
@onready var return_to_title_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/NavPanel/MarginContainer/NavVBox/ReturnToTitleButton
@onready var quit_game_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/NavPanel/MarginContainer/NavVBox/QuitGameButton
@onready var window_mode_option: OptionButton = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SettingsPage/MarginContainer/SettingsVBox/DisplayPanel/DisplayMargin/DisplayVBox/WindowModeRow/WindowModeOption
@onready var monitor_option: OptionButton = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SettingsPage/MarginContainer/SettingsVBox/DisplayPanel/DisplayMargin/DisplayVBox/MonitorRow/MonitorOption
@onready var resolution_option: OptionButton = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SettingsPage/MarginContainer/SettingsVBox/DisplayPanel/DisplayMargin/DisplayVBox/ResolutionRow/ResolutionOption
@onready var vsync_check_box: CheckBox = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SettingsPage/MarginContainer/SettingsVBox/DisplayPanel/DisplayMargin/DisplayVBox/VSyncCheckBox
@onready var render_scale_option: OptionButton = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SettingsPage/MarginContainer/SettingsVBox/DisplayPanel/DisplayMargin/DisplayVBox/RenderScaleRow/RenderScaleOption
@onready var max_fps_option: OptionButton = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SettingsPage/MarginContainer/SettingsVBox/DisplayPanel/DisplayMargin/DisplayVBox/MaxFpsRow/MaxFpsOption
@onready var master_volume_slider: HSlider = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SettingsPage/MarginContainer/SettingsVBox/AudioPanel/AudioMargin/AudioVBox/MasterVolumeRow/MasterVolumeSlider
@onready var master_volume_value_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SettingsPage/MarginContainer/SettingsVBox/AudioPanel/AudioMargin/AudioVBox/MasterVolumeRow/MasterVolumeValueLabel
@onready var master_mute_check_box: CheckBox = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SettingsPage/MarginContainer/SettingsVBox/AudioPanel/AudioMargin/AudioVBox/MasterMuteCheckBox
@onready var ui_scale_option: OptionButton = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/InterfacePage/MarginContainer/InterfaceVBox/UIScaleRow/UIScaleOption
@onready var text_scale_option: OptionButton = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/InterfacePage/MarginContainer/InterfaceVBox/TextScaleRow/TextScaleOption
@onready var controls_category_option: OptionButton = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/ControlsPage/MarginContainer/ControlsVBox/CategoryRow/CategoryOption
@onready var bindings_status_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/ControlsPage/MarginContainer/ControlsVBox/BindingsStatusLabel
@onready var bindings_container: VBoxContainer = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/ControlsPage/MarginContainer/ControlsVBox/BindingsScroll/BindingsVBox
@onready var restore_defaults_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/ControlsPage/MarginContainer/ControlsVBox/ControlsFooterRow/RestoreDefaultsButton
@onready var footer_status_label: Label = $Panel/MarginContainer/RootVBox/FooterRow/FooterStatusLabel
@onready var reset_page_button: Button = $Panel/MarginContainer/RootVBox/FooterRow/ResetPageButton
@onready var close_button: Button = $Panel/MarginContainer/RootVBox/FooterRow/CloseButton
@onready var window_mode_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SettingsPage/MarginContainer/SettingsVBox/DisplayPanel/DisplayMargin/DisplayVBox/WindowModeRow/WindowModeLabel
@onready var monitor_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SettingsPage/MarginContainer/SettingsVBox/DisplayPanel/DisplayMargin/DisplayVBox/MonitorRow/MonitorLabel
@onready var resolution_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SettingsPage/MarginContainer/SettingsVBox/DisplayPanel/DisplayMargin/DisplayVBox/ResolutionRow/ResolutionLabel
@onready var render_scale_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SettingsPage/MarginContainer/SettingsVBox/DisplayPanel/DisplayMargin/DisplayVBox/RenderScaleRow/RenderScaleLabel
@onready var max_fps_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SettingsPage/MarginContainer/SettingsVBox/DisplayPanel/DisplayMargin/DisplayVBox/MaxFpsRow/MaxFpsLabel
@onready var master_volume_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/SettingsPage/MarginContainer/SettingsVBox/AudioPanel/AudioMargin/AudioVBox/MasterVolumeRow/MasterVolumeLabel
@onready var category_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/ControlsPage/MarginContainer/ControlsVBox/CategoryRow/CategoryLabel
@onready var ui_scale_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/InterfacePage/MarginContainer/InterfaceVBox/UIScaleRow/UIScaleLabel
@onready var text_scale_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll/PageStack/InterfacePage/MarginContainer/InterfaceVBox/TextScaleRow/TextScaleLabel

var active_player: PlayerController3D
var settings_state: UserSettingsState = null
var selected_controls_category: String = ""
var pending_rebind_action: StringName = StringName()
var current_page: StringName = PAGE_SETTINGS
var is_refreshing_ui: bool = false
var layout_refresh_queued: bool = false

func _ready() -> void:
	visible = false
	backdrop.visible = false
	panel.visible = false
	_configure_static_options()
	_connect_signals()
	_select_page(PAGE_SETTINGS)
	if not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	if not panel.resized.is_connected(_queue_layout_refresh):
		panel.resized.connect(_queue_layout_refresh)
	if not page_scroll.resized.is_connected(_queue_layout_refresh):
		page_scroll.resized.connect(_queue_layout_refresh)
	_queue_layout_refresh()

func configure(player, state) -> void:
	active_player = player
	settings_state = state as UserSettingsState if state != null else UserSettingsStateScript.load_or_create()
	return_to_title_button.disabled = true
	footer_status_label.text = FOOTER_STATUS_DEFAULT
	_refresh_from_state()

func is_open() -> bool:
	return panel.visible

func toggle_menu() -> void:
	if panel.visible:
		close_menu()
		return
	open_menu()

func open_page(page_id: StringName) -> void:
	current_page = page_id
	if panel.visible:
		_select_page(page_id)
		return
	open_menu()

func reset_active_page_to_defaults() -> void:
	if settings_state == null:
		return
	match current_page:
		PAGE_SETTINGS:
			settings_state.reset_display_to_defaults()
			settings_state.reset_audio_to_defaults()
			_apply_and_persist_settings("Display and audio settings restored to defaults.")
			_refresh_from_state()
		PAGE_INTERFACE:
			settings_state.reset_interface_to_defaults()
			_apply_and_persist_settings("Interface scale restored to defaults.")
			_refresh_from_state()
		PAGE_CONTROLS:
			_restore_selected_category_defaults()
		_:
			footer_status_label.text = "This page does not have resettable live settings yet."

func get_current_page_id() -> StringName:
	return current_page

func open_menu() -> void:
	if settings_state == null:
		settings_state = UserSettingsStateScript.load_or_create()
	_refresh_from_state()
	_select_page(current_page)
	_queue_layout_refresh()
	visible = true
	backdrop.visible = true
	panel.visible = true
	if active_player != null:
		active_player.set_ui_mode_enabled(true)

func close_menu() -> void:
	pending_rebind_action = StringName()
	visible = false
	backdrop.visible = false
	panel.visible = false
	if active_player != null:
		active_player.set_ui_mode_enabled(false)

func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if pending_rebind_action != StringName() and event is InputEventKey:
		var pending_key_event: InputEventKey = event
		if pending_key_event.pressed and not pending_key_event.echo:
			if pending_key_event.keycode == KEY_ESCAPE:
				pending_rebind_action = StringName()
				bindings_status_label.text = "Rebind cancelled."
			else:
				_commit_key_rebind(pending_rebind_action, pending_key_event)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"ui_settings"):
		open_page(PAGE_SETTINGS)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_social"):
		open_page(PAGE_SOCIAL)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"menu_toggle"):
		close_menu()
		get_viewport().set_input_as_handled()

func _configure_static_options() -> void:
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
	for fps_value in MAX_FPS_OPTIONS:
		max_fps_option.add_item("Unlimited" if fps_value == 0 else "%d FPS" % fps_value)

	resolution_option.clear()
	for resolution: Vector2i in RESOLUTION_OPTIONS:
		resolution_option.add_item("%d x %d" % [resolution.x, resolution.y])

	ui_scale_option.clear()
	text_scale_option.clear()
	for label_text: String in ["Small", "Normal", "Large"]:
		ui_scale_option.add_item(label_text)
		text_scale_option.add_item(label_text)

	controls_category_option.clear()
	for category_name: String in UserSettingsRuntimeScript.get_categories():
		controls_category_option.add_item(UserSettingsRuntimeScript.get_category_display_name(category_name))

func _connect_signals() -> void:
	resume_button.pressed.connect(close_menu)
	settings_button.pressed.connect(_select_page.bind(PAGE_SETTINGS))
	controls_button.pressed.connect(_select_page.bind(PAGE_CONTROLS))
	interface_button.pressed.connect(_select_page.bind(PAGE_INTERFACE))
	social_button.pressed.connect(_select_page.bind(PAGE_SOCIAL))
	help_button.pressed.connect(_select_page.bind(PAGE_HELP))
	return_to_title_button.pressed.connect(_on_return_to_title_pressed)
	quit_game_button.pressed.connect(_on_quit_game_pressed)
	window_mode_option.item_selected.connect(_on_window_mode_selected)
	monitor_option.item_selected.connect(_on_monitor_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	vsync_check_box.toggled.connect(_on_vsync_toggled)
	render_scale_option.item_selected.connect(_on_render_scale_selected)
	max_fps_option.item_selected.connect(_on_max_fps_selected)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	master_mute_check_box.toggled.connect(_on_master_mute_toggled)
	ui_scale_option.item_selected.connect(_on_ui_scale_selected)
	text_scale_option.item_selected.connect(_on_text_scale_selected)
	controls_category_option.item_selected.connect(_on_controls_category_selected)
	restore_defaults_button.pressed.connect(_restore_selected_category_defaults)
	reset_page_button.pressed.connect(reset_active_page_to_defaults)
	close_button.pressed.connect(close_menu)

func _refresh_from_state() -> void:
	if settings_state == null:
		return
	is_refreshing_ui = true
	window_mode_option.select(_find_window_mode_index(settings_state.window_mode))
	if monitor_option.item_count > 0:
		monitor_option.select(clampi(settings_state.display_index, 0, maxi(monitor_option.item_count - 1, 0)))
	resolution_option.select(_find_resolution_index(settings_state.resolution))
	vsync_check_box.button_pressed = settings_state.vsync_enabled
	render_scale_option.select(_scale_preset_to_index(settings_state.render_scale_preset))
	max_fps_option.select(_find_max_fps_index(settings_state.max_fps))
	master_volume_slider.value = settings_state.master_volume_linear
	master_mute_check_box.button_pressed = settings_state.master_muted
	master_volume_value_label.text = "%d%%" % int(round(settings_state.master_volume_linear * 100.0))
	ui_scale_option.select(_scale_preset_to_index(settings_state.ui_scale_preset))
	text_scale_option.select(_scale_preset_to_index(settings_state.text_scale_preset))
	if controls_category_option.item_count > 0:
		if selected_controls_category.is_empty():
			selected_controls_category = UserSettingsRuntimeScript.get_categories()[0]
		controls_category_option.select(_find_category_index(selected_controls_category))
	is_refreshing_ui = false
	_refresh_bindings_list()
	_queue_layout_refresh()

func _queue_layout_refresh() -> void:
	if layout_refresh_queued:
		return
	layout_refresh_queued = true
	call_deferred("_apply_responsive_layout")

func _apply_responsive_layout() -> void:
	layout_refresh_queued = false
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var compact_mode: bool = viewport_size.x < float(compact_width_breakpoint) or viewport_size.y < float(compact_height_breakpoint)
	var margin_ratio: float = compact_outer_margin_ratio if compact_mode else wide_outer_margin_ratio
	var smaller_axis: int = mini(int(round(viewport_size.x)), int(round(viewport_size.y)))
	var resolved_margin: float = float(clampi(int(round(float(smaller_axis) * margin_ratio)), minimum_outer_margin_px, maximum_outer_margin_px))
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

	nav_panel.custom_minimum_size.x = compact_navigation_panel_min_width if compact_mode else wide_navigation_panel_min_width
	var resolved_navigation_button_height: int = compact_navigation_button_min_height if compact_mode else wide_navigation_button_min_height
	for button: Button in _get_navigation_buttons():
		button.custom_minimum_size.y = resolved_navigation_button_height
	var resolved_label_width: int = compact_form_label_min_width if compact_mode else wide_form_label_min_width
	for label: Label in _get_form_labels():
		label.custom_minimum_size.x = resolved_label_width

	var resolved_footer_button_height: int = compact_footer_button_min_height if compact_mode else wide_footer_button_min_height
	var resolved_footer_button_width: int = compact_footer_button_min_width if compact_mode else wide_footer_button_min_width
	reset_page_button.custom_minimum_size = Vector2(resolved_footer_button_width, resolved_footer_button_height)
	restore_defaults_button.custom_minimum_size = Vector2(resolved_footer_button_width, resolved_footer_button_height)
	close_button.custom_minimum_size = Vector2(compact_close_button_min_width if compact_mode else wide_close_button_min_width, resolved_footer_button_height)

	page_stack.custom_minimum_size.x = maxf(page_scroll.size.x - float(page_scroll_width_padding), 0.0)

func _get_navigation_buttons() -> Array[Button]:
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

func _get_form_labels() -> Array[Label]:
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

func _refresh_bindings_list() -> void:
	for child: Node in bindings_container.get_children():
		child.queue_free()
	if selected_controls_category.is_empty():
		bindings_status_label.text = "No input category selected."
		return
	bindings_status_label.text = "Pick a binding and press a new key. Escape cancels the rebind prompt."
	for action_name: StringName in UserSettingsRuntimeScript.get_actions_for_category(selected_controls_category):
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var action_label: Label = Label.new()
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_label.text = UserSettingsRuntimeScript.get_action_display_name(action_name)
		row.add_child(action_label)

		var binding_button: Button = Button.new()
		binding_button.custom_minimum_size = Vector2(180.0, 0.0)
		binding_button.text = UserSettingsRuntimeScript.get_keybinding_label(settings_state.get_keybinding_data(action_name, UserSettingsRuntimeScript.get_default_binding_data(action_name)))
		binding_button.pressed.connect(_begin_rebind.bind(action_name))
		row.add_child(binding_button)

		bindings_container.add_child(row)

func _begin_rebind(action_name: StringName) -> void:
	pending_rebind_action = action_name
	bindings_status_label.text = "Press a new key for %s." % UserSettingsRuntimeScript.get_action_display_name(action_name)
	footer_status_label.text = "Listening for a new key on %s. Escape cancels." % UserSettingsRuntimeScript.get_action_display_name(action_name)

func _commit_key_rebind(action_name: StringName, key_event: InputEventKey) -> void:
	settings_state.set_keybinding_event(action_name, key_event)
	_apply_and_persist_settings("Saved controls for %s." % UserSettingsRuntimeScript.get_action_display_name(action_name))
	pending_rebind_action = StringName()
	bindings_status_label.text = "%s is now bound to %s." % [UserSettingsRuntimeScript.get_action_display_name(action_name), UserSettingsRuntimeScript.get_keybinding_label(settings_state.get_keybinding_data(action_name))]
	_refresh_bindings_list()

func _apply_and_persist_settings(status_message: String = "") -> void:
	if settings_state == null:
		return
	UserSettingsRuntimeScript.ensure_input_actions(settings_state)
	UserSettingsRuntimeScript.apply_settings(settings_state, get_tree().root)
	_queue_layout_refresh()
	var persisted_ok: bool = settings_state.persist()
	if not status_message.is_empty():
		footer_status_label.text = status_message if persisted_ok else "%s Saving failed." % status_message
		return
	if not persisted_ok:
		footer_status_label.text = "Settings could not be saved."

func _find_resolution_index(target_resolution: Vector2i) -> int:
	for index in range(RESOLUTION_OPTIONS.size()):
		if RESOLUTION_OPTIONS[index] == target_resolution:
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

func _find_max_fps_index(target_fps: int) -> int:
	for index in range(MAX_FPS_OPTIONS.size()):
		if MAX_FPS_OPTIONS[index] == target_fps:
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

func _on_window_mode_selected(index: int) -> void:
	if is_refreshing_ui:
		return
	match index:
		1:
			settings_state.window_mode = UserSettingsStateScript.BORDERLESS
		2:
			settings_state.window_mode = UserSettingsStateScript.FULLSCREEN
		_:
			settings_state.window_mode = UserSettingsStateScript.WINDOWED
	_apply_and_persist_settings("Window mode updated.")

func _on_monitor_selected(index: int) -> void:
	if is_refreshing_ui:
		return
	settings_state.display_index = index
	_apply_and_persist_settings("Monitor target updated.")

func _on_resolution_selected(index: int) -> void:
	if is_refreshing_ui:
		return
	settings_state.resolution = RESOLUTION_OPTIONS[index]
	_apply_and_persist_settings("Resolution updated.")

func _on_vsync_toggled(enabled: bool) -> void:
	if is_refreshing_ui:
		return
	settings_state.vsync_enabled = enabled
	_apply_and_persist_settings("V-Sync preference updated.")

func _on_render_scale_selected(index: int) -> void:
	if is_refreshing_ui:
		return
	settings_state.render_scale_preset = _index_to_scale_preset(index)
	_apply_and_persist_settings("3D render scale updated.")

func _on_max_fps_selected(index: int) -> void:
	if is_refreshing_ui:
		return
	settings_state.max_fps = MAX_FPS_OPTIONS[index]
	_apply_and_persist_settings("Max FPS updated.")

func _on_master_volume_changed(value: float) -> void:
	if is_refreshing_ui:
		return
	settings_state.master_volume_linear = value
	master_volume_value_label.text = "%d%%" % int(round(value * 100.0))
	_apply_and_persist_settings("Master volume updated.")

func _on_master_mute_toggled(enabled: bool) -> void:
	if is_refreshing_ui:
		return
	settings_state.master_muted = enabled
	_apply_and_persist_settings("Master mute updated.")

func _on_ui_scale_selected(index: int) -> void:
	if is_refreshing_ui:
		return
	settings_state.ui_scale_preset = _index_to_scale_preset(index)
	_apply_and_persist_settings("UI scale updated.")

func _on_text_scale_selected(index: int) -> void:
	if is_refreshing_ui:
		return
	settings_state.text_scale_preset = _index_to_scale_preset(index)
	_apply_and_persist_settings("Text scale updated.")

func _on_controls_category_selected(index: int) -> void:
	if is_refreshing_ui:
		return
	selected_controls_category = UserSettingsRuntimeScript.get_categories()[index]
	_refresh_bindings_list()
	_refresh_page_actions()

func _restore_selected_category_defaults() -> void:
	if selected_controls_category.is_empty():
		return
	settings_state.reset_keybindings_for_actions(UserSettingsRuntimeScript.get_actions_for_category(selected_controls_category))
	_apply_and_persist_settings("%s bindings restored to defaults." % UserSettingsRuntimeScript.get_category_display_name(selected_controls_category))
	bindings_status_label.text = "%s bindings restored to defaults." % UserSettingsRuntimeScript.get_category_display_name(selected_controls_category)
	_refresh_bindings_list()

func _select_page(page_id: StringName) -> void:
	current_page = page_id
	settings_page.visible = page_id == PAGE_SETTINGS
	controls_page.visible = page_id == PAGE_CONTROLS
	interface_page.visible = page_id == PAGE_INTERFACE
	social_page.visible = page_id == PAGE_SOCIAL
	help_page.visible = page_id == PAGE_HELP
	match page_id:
		PAGE_CONTROLS:
			page_title_label.text = "Controls"
			page_subtitle_label.text = "Per-user keybindings grouped by movement, combat, camera, UI/menu, and forge contexts."
		PAGE_INTERFACE:
			page_title_label.text = "Interface"
			page_subtitle_label.text = "Adjust global UI and text scaling while preserving relative size hierarchy."
		PAGE_SOCIAL:
			page_title_label.text = "Social"
			page_subtitle_label.text = "Privacy, request filtering, and social-clutter controls will expand here next."
		PAGE_HELP:
			page_title_label.text = "Help"
			page_subtitle_label.text = "Use this overlay as a control room for active expeditions. World simulation continues while it is open."
		_:
			page_title_label.text = "Settings"
			page_subtitle_label.text = "Display and audio settings apply immediately and persist per user across boots."
	_refresh_page_actions()
	if footer_status_label.text.is_empty() or footer_status_label.text == FOOTER_STATUS_DEFAULT:
		footer_status_label.text = FOOTER_STATUS_DEFAULT

func _refresh_page_actions() -> void:
	match current_page:
		PAGE_SETTINGS:
			reset_page_button.disabled = false
			reset_page_button.text = "Reset Display / Audio"
		PAGE_CONTROLS:
			reset_page_button.disabled = selected_controls_category.is_empty()
			reset_page_button.text = "Reset Controls"
		PAGE_INTERFACE:
			reset_page_button.disabled = false
			reset_page_button.text = "Reset Interface"
		_:
			reset_page_button.disabled = true
			reset_page_button.text = "No Reset Available"

func _on_return_to_title_pressed() -> void:
	footer_status_label.text = "Return to Title is not available yet because this workspace has no title scene."

func _on_quit_game_pressed() -> void:
	get_tree().quit()
