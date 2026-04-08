extends CanvasLayer
class_name SystemMenuOverlay

const UserSettingsStateScript = preload("res://core/models/user_settings_state.gd")
const SystemMenuControlsPresenterScript = preload("res://runtime/ui/system_menu_controls_presenter.gd")
const SystemMenuInputPresenterScript = preload("res://runtime/ui/system_menu_input_presenter.gd")
const SystemMenuLayoutPresenterScript = preload("res://runtime/ui/system_menu_layout_presenter.gd")
const SystemMenuPagePresenterScript = preload("res://runtime/ui/system_menu_page_presenter.gd")
const SystemMenuSessionPresenterScript = preload("res://runtime/ui/system_menu_session_presenter.gd")
const SystemMenuStateFlowPresenterScript = preload("res://runtime/ui/system_menu_state_flow_presenter.gd")
const SystemMenuSurfacePresenterScript = preload("res://runtime/ui/system_menu_surface_presenter.gd")
const SystemMenuSettingsPresenterScript = preload("res://runtime/ui/system_menu_settings_presenter.gd")

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

var active_player = null
var settings_state: UserSettingsState = null
var selected_controls_category: String = ""
var pending_rebind_action: StringName = StringName()
var current_page: StringName = PAGE_SETTINGS
var is_refreshing_ui: bool = false
var layout_refresh_queued: bool = false
var controls_presenter = SystemMenuControlsPresenterScript.new()
var input_presenter = SystemMenuInputPresenterScript.new()
var layout_presenter = SystemMenuLayoutPresenterScript.new()
var page_presenter = SystemMenuPagePresenterScript.new()
var session_presenter = SystemMenuSessionPresenterScript.new()
var state_flow_presenter = SystemMenuStateFlowPresenterScript.new()
var surface_presenter = SystemMenuSurfacePresenterScript.new()
var settings_presenter = SystemMenuSettingsPresenterScript.new()

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
	var session_state: Dictionary = session_presenter.configure(player, state, footer_status_label, FOOTER_STATUS_DEFAULT)
	active_player = session_state.get("active_player", null)
	settings_state = session_state.get("settings_state", null)
	return_to_title_button.disabled = true
	_refresh_from_state()

func is_open() -> bool:
	return session_presenter.is_open(panel)

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
	var reset_result: Dictionary = state_flow_presenter.reset_active_page_to_defaults(
		current_page,
		settings_state,
		selected_controls_category,
		controls_presenter,
		_build_surface_controls_payload()
	)
	if not bool(reset_result.get("handled", false)):
		return
	var status_message: String = String(reset_result.get("status_message", ""))
	if bool(reset_result.get("apply_and_refresh", false)):
		_apply_and_persist_settings(status_message)
		_refresh_from_state()
		return
	if not status_message.is_empty():
		footer_status_label.text = status_message

func get_current_page_id() -> StringName:
	return current_page

func open_menu() -> void:
	if settings_state == null:
		settings_state = UserSettingsStateScript.load_or_create()
	_refresh_from_state()
	_select_page(current_page)
	_queue_layout_refresh()
	visible = true
	session_presenter.open_menu(active_player, backdrop, panel)

func close_menu() -> void:
	pending_rebind_action = StringName()
	visible = false
	session_presenter.close_menu(active_player, backdrop, panel)

func _unhandled_input(event: InputEvent) -> void:
	var input_result: Dictionary = input_presenter.handle_unhandled_input(
		panel.visible,
		pending_rebind_action,
		event,
		PAGE_SETTINGS,
		PAGE_SOCIAL
	)
	if not bool(input_result.get("handled", false)):
		return
	if bool(input_result.get("cancel_rebind", false)):
		pending_rebind_action = StringName()
		bindings_status_label.text = String(input_result.get("bindings_status_text", "Rebind cancelled."))
	elif bool(input_result.get("commit_rebind", false)):
		_commit_key_rebind(
			input_result.get("action_name", pending_rebind_action),
			input_result.get("key_event", null)
		)
	elif bool(input_result.get("close_menu", false)):
		close_menu()
	else:
		var page_id: StringName = input_result.get("open_page", StringName())
		if page_id != StringName():
			open_page(page_id)
	get_viewport().set_input_as_handled()

func _configure_static_options() -> void:
	settings_presenter.configure_static_options(
		window_mode_option,
		monitor_option,
		render_scale_option,
		max_fps_option,
		resolution_option,
		ui_scale_option,
		text_scale_option,
		controls_category_option,
		RESOLUTION_OPTIONS,
		MAX_FPS_OPTIONS
	)

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
	is_refreshing_ui = true
	var refresh_result: Dictionary = state_flow_presenter.refresh_from_state(
		settings_state,
		selected_controls_category,
		settings_presenter,
		controls_presenter,
		_build_surface_option_payload(),
		_build_surface_controls_payload(),
		RESOLUTION_OPTIONS,
		MAX_FPS_OPTIONS
	)
	selected_controls_category = String(refresh_result.get("selected_controls_category", selected_controls_category))
	is_refreshing_ui = false
	if bool(refresh_result.get("refreshed", false)):
		_queue_layout_refresh()

func _queue_layout_refresh() -> void:
	if layout_refresh_queued:
		return
	layout_refresh_queued = true
	call_deferred("_apply_responsive_layout")

func _apply_responsive_layout() -> void:
	layout_refresh_queued = false
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	layout_presenter.apply_responsive_layout(
		viewport_size,
		_build_surface_layout_config(),
		backdrop,
		panel,
		nav_panel,
		reset_page_button,
		restore_defaults_button,
		close_button,
		page_scroll,
		page_stack,
		_build_surface_navigation_buttons(),
		_build_surface_form_labels()
	)

func _begin_rebind(action_name: StringName) -> void:
	pending_rebind_action = state_flow_presenter.begin_rebind(
		action_name,
		controls_presenter,
		bindings_status_label,
		footer_status_label
	)

func _commit_key_rebind(action_name: StringName, key_event: InputEventKey) -> void:
	if key_event == null:
		return
	var commit_result: Dictionary = state_flow_presenter.commit_key_rebind(
		settings_state,
		action_name,
		key_event,
		controls_presenter,
		_build_surface_controls_payload()
	)
	_apply_and_persist_settings(String(commit_result.get("status_message", "")))
	pending_rebind_action = StringName()

func _apply_and_persist_settings(status_message: String = "") -> void:
	state_flow_presenter.apply_and_persist_settings(
		settings_state,
		get_tree().root,
		footer_status_label,
		status_message
	)
	_queue_layout_refresh()

func _on_window_mode_selected(index: int) -> void:
	_apply_live_settings_change(settings_presenter.apply_window_mode_selection(settings_state, index))

func _on_monitor_selected(index: int) -> void:
	_apply_live_settings_change(settings_presenter.apply_monitor_selection(settings_state, index))

func _on_resolution_selected(index: int) -> void:
	_apply_live_settings_change(settings_presenter.apply_resolution_selection(settings_state, index, RESOLUTION_OPTIONS))

func _on_vsync_toggled(enabled: bool) -> void:
	_apply_live_settings_change(settings_presenter.apply_vsync_toggle(settings_state, enabled))

func _on_render_scale_selected(index: int) -> void:
	_apply_live_settings_change(settings_presenter.apply_render_scale_selection(settings_state, index))

func _on_max_fps_selected(index: int) -> void:
	_apply_live_settings_change(settings_presenter.apply_max_fps_selection(settings_state, index, MAX_FPS_OPTIONS))

func _on_master_volume_changed(value: float) -> void:
	_apply_live_settings_change(settings_presenter.apply_master_volume_change(settings_state, value, master_volume_value_label))

func _on_master_mute_toggled(enabled: bool) -> void:
	_apply_live_settings_change(settings_presenter.apply_master_mute_toggle(settings_state, enabled))

func _on_ui_scale_selected(index: int) -> void:
	_apply_live_settings_change(settings_presenter.apply_ui_scale_selection(settings_state, index))

func _on_text_scale_selected(index: int) -> void:
	_apply_live_settings_change(settings_presenter.apply_text_scale_selection(settings_state, index))

func _on_controls_category_selected(index: int) -> void:
	var category_result: Dictionary = state_flow_presenter.handle_controls_category_selected(
		is_refreshing_ui,
		index,
		controls_presenter,
		settings_state,
		_build_surface_controls_payload()
	)
	if not bool(category_result.get("changed", false)):
		return
	selected_controls_category = String(category_result.get("selected_controls_category", selected_controls_category))
	_refresh_page_actions()

func _restore_selected_category_defaults() -> void:
	var restore_result: Dictionary = state_flow_presenter.restore_selected_category_defaults(
		settings_state,
		selected_controls_category,
		controls_presenter,
		_build_surface_controls_payload()
	)
	if not bool(restore_result.get("restored", false)):
		return
	var status_message: String = String(restore_result.get("status_message", ""))
	_apply_and_persist_settings(status_message)

func _select_page(page_id: StringName) -> void:
	current_page = page_id
	page_presenter.apply_page_selection(
		page_id,
		surface_presenter.get_page_id_map(),
		settings_page,
		controls_page,
		interface_page,
		social_page,
		help_page,
		page_title_label,
		page_subtitle_label,
		reset_page_button,
		selected_controls_category,
		footer_status_label,
		FOOTER_STATUS_DEFAULT
	)

func _refresh_page_actions() -> void:
	page_presenter.refresh_page_actions(current_page, surface_presenter.get_page_id_map(), selected_controls_category, reset_page_button)

func _apply_live_settings_change(status_message: String) -> void:
	if is_refreshing_ui:
		return
	_apply_and_persist_settings(status_message)

func _on_return_to_title_pressed() -> void:
	footer_status_label.text = "Return to Title is not available yet because this workspace has no title scene."

func _on_quit_game_pressed() -> void:
	get_tree().quit()

func _build_surface_layout_config() -> Dictionary:
	return surface_presenter.build_layout_config(
		compact_width_breakpoint,
		compact_height_breakpoint,
		wide_outer_margin_ratio,
		compact_outer_margin_ratio,
		minimum_outer_margin_px,
		maximum_outer_margin_px,
		wide_navigation_panel_min_width,
		compact_navigation_panel_min_width,
		wide_navigation_button_min_height,
		compact_navigation_button_min_height,
		wide_form_label_min_width,
		compact_form_label_min_width,
		wide_footer_button_min_width,
		compact_footer_button_min_width,
		wide_close_button_min_width,
		compact_close_button_min_width,
		wide_footer_button_min_height,
		compact_footer_button_min_height,
		page_scroll_width_padding
	)

func _build_surface_navigation_buttons() -> Array[Button]:
	return surface_presenter.get_navigation_buttons(
		resume_button,
		settings_button,
		controls_button,
		interface_button,
		social_button,
		help_button,
		return_to_title_button,
		quit_game_button
	)

func _build_surface_form_labels() -> Array[Label]:
	return surface_presenter.get_form_labels(
		window_mode_label,
		monitor_label,
		resolution_label,
		render_scale_label,
		max_fps_label,
		master_volume_label,
		category_label,
		ui_scale_label,
		text_scale_label
	)

func _build_surface_option_payload() -> Dictionary:
	return surface_presenter.build_option_payload(
		window_mode_option,
		monitor_option,
		resolution_option,
		vsync_check_box,
		render_scale_option,
		max_fps_option,
		master_volume_slider,
		master_volume_value_label,
		master_mute_check_box,
		ui_scale_option,
		text_scale_option,
		controls_category_option
	)

func _build_surface_controls_payload() -> Dictionary:
	return surface_presenter.build_controls_payload(
		bindings_container,
		bindings_status_label,
		Callable(self, "_begin_rebind"),
		selected_controls_category
	)
