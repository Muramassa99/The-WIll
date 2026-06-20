extends CanvasLayer
class_name CraftingBenchUIV2

signal closed

const ForgeV2WorkspacePreviewScript = preload("res://runtime/forge_v2/forge_v2_workspace_preview.gd")
const ForgeV2KeybindingStateScript = preload("res://runtime/forge_v2/forge_v2_keybinding_state.gd")

@onready var panel: PanelContainer = $Panel
@onready var root_margin: MarginContainer = $Panel/MarginContainer
@onready var root_vbox: VBoxContainer = $Panel/MarginContainer/RootVBox
@onready var header_vbox: VBoxContainer = $Panel/MarginContainer/RootVBox/HeaderVBox
@onready var title_label: Label = $Panel/MarginContainer/RootVBox/HeaderVBox/TitleLabel
@onready var subtitle_label: Label = $Panel/MarginContainer/RootVBox/HeaderVBox/SubtitleLabel
@onready var body_panel: PanelContainer = $Panel/MarginContainer/RootVBox/BodyPanel
@onready var body_margin: MarginContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin
@onready var body_scroll: ScrollContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll
@onready var body_vbox: VBoxContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox
@onready var status_label: Label = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/StatusLabel
@onready var new_draft_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/DraftButtonRow/NewDraftButton
@onready var clear_strokes_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/DraftButtonRow/ClearStrokesButton
@onready var builder_path_option: OptionButton = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/BuilderPathRow/BuilderPathOption
@onready var builder_component_row: HBoxContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/BuilderComponentRow
@onready var builder_component_option: OptionButton = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/BuilderComponentRow/BuilderComponentOption
@onready var operation_option: OptionButton = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/OperationRow/OperationOption
@onready var placement_policy_option: OptionButton = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/PlacementPolicyRow/PlacementPolicyOption
@onready var active_material_label: Label = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/MaterialPaletteRow/MaterialPaletteVBox/ActiveMaterialLabel
@onready var material_palette_grid: GridContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/MaterialPaletteRow/MaterialPaletteVBox/MaterialPaletteScroll/MaterialPaletteGrid
@onready var primitive_option: OptionButton = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/PrimitiveRow/PrimitiveOption
@onready var radius_value_label: Label = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/RadiusRow/RadiusValueLabel
@onready var radius_decrease_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/RadiusRow/RadiusDecreaseButton
@onready var radius_increase_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/RadiusRow/RadiusIncreaseButton
@onready var add_empty_stroke_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/StrokeButtonRow/AddEmptyStrokeButton
@onready var commit_pending_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/StrokeButtonRow/CommitPendingButton
@onready var undo_layer_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/StrokeButtonRow/UndoLayerButton
@onready var redo_layer_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/StrokeButtonRow/RedoLayerButton
@onready var body_stack_option: OptionButton = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/BodyStackRow/BodyStackOption
@onready var delete_selected_body_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/BodyStackRow/DeleteSelectedBodyButton
@onready var platform_contract_label: Label = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/PlatformContractLabel
@onready var summary_label: Label = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/SummaryLabel
@onready var workspace_panel: PanelContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/WorkspacePanel
@onready var workspace_margin: MarginContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/WorkspacePanel/WorkspaceMargin
@onready var workspace_vbox: VBoxContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/WorkspacePanel/WorkspaceMargin/WorkspaceVBox
@onready var workspace_title_label: Label = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/WorkspacePanel/WorkspaceMargin/WorkspaceVBox/WorkspaceTitle
@onready var workspace_view_container: SubViewportContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/WorkspacePanel/WorkspaceMargin/WorkspaceVBox/WorkspaceViewportContainer
@onready var workspace_subviewport: SubViewport = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/WorkspacePanel/WorkspaceMargin/WorkspaceVBox/WorkspaceViewportContainer/WorkspaceSubViewport
@onready var workspace_status_label: Label = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/WorkspacePanel/WorkspaceMargin/WorkspaceVBox/WorkspaceStatusLabel
@onready var footer_row: HBoxContainer = $Panel/MarginContainer/RootVBox/FooterRow
@onready var close_button: Button = $Panel/MarginContainer/RootVBox/FooterRow/CloseButton

const MATERIAL_PLACEHOLDER_ICON_PATH := "res://assets/ui_v2/material_placeholder_icon.png"
const MATERIAL_ICON_BUTTON_SIZE := Vector2(56, 56)
const COMPACT_LAYOUT_WIDTH := 1180.0
const COMPACT_LAYOUT_HEIGHT := 700.0
const ULTRA_COMPACT_LAYOUT_WIDTH := 860.0
const ULTRA_COMPACT_LAYOUT_HEIGHT := 560.0
const UI_FIT_SCALE_MIN := 0.58
const UI_FIT_PADDING_PX := 2.0
const WORKSPACE_VIEWPORT_ASPECT := 16.0 / 9.0
const MENU_ID_BASE := 1000
const WORKSPACE_ZOOM_STEP := 0.1
const SPLINE_POINT_SCREEN_PICK_RADIUS_PIXELS := 26.0

var active_player = null
var active_stage_controller: Node = null
var active_placement_space: Node3D = null
var current_bench_name: String = ""
var is_refreshing_ui: bool = false
var material_icon_texture: Texture2D = null
var workspace_preview: Node3D = null
var body_layout_hbox: HBoxContainer = null
var action_host_row: HBoxContainer = null
var draft_menu_button: MenuButton = null
var build_menu_button: MenuButton = null
var material_menu_button: MenuButton = null
var shape_menu_button: MenuButton = null
var layers_menu_button: MenuButton = null
var view_menu_button: MenuButton = null
var status_menu_button: MenuButton = null
var settings_button: Button = null
var action_status_label: Label = null
var keybinding_state: Resource = null
var settings_popup: PopupPanel = null
var freehand_smoothing_slider: HSlider = null
var freehand_smoothing_value_label: Label = null
var keybindings_popup: PopupPanel = null
var keybindings_list_vbox: VBoxContainer = null
var keybinding_buttons_by_action: Dictionary = {}
var keybinding_capture_action: StringName = StringName()
var keybinding_capture_button: Button = null
var keybinding_capture_keyboard_data: Dictionary = {}
var is_refreshing_settings_ui: bool = false
var menu_action_lookup: Dictionary = {}
var menu_next_id: int = MENU_ID_BASE
var last_ui_fit_scale := 1.0
var workspace_frame_host: Control = null
var workspace_drag_active := false
var workspace_drag_pan_mode := false
var workspace_brush_stroke_active := false
var workspace_spline_point_drag_active := false
var workspace_spline_drag_point_index := -1
var workspace_spline_drag_plane_origin_local: Vector3 = Vector3.ZERO
var workspace_spline_drag_plane_normal_local: Vector3 = Vector3.FORWARD

func _ready() -> void:
	visible = false
	panel.visible = false
	material_icon_texture = _load_material_icon_texture()
	_ensure_keybinding_state()
	_ensure_top_action_bar()
	_ensure_workspace_frame_host()
	_ensure_fullscreen_workspace_layout()
	new_draft_button.pressed.connect(_on_new_draft_pressed)
	clear_strokes_button.pressed.connect(_on_clear_strokes_pressed)
	builder_path_option.item_selected.connect(_on_builder_path_selected)
	builder_component_option.item_selected.connect(_on_builder_component_selected)
	operation_option.item_selected.connect(_on_operation_selected)
	placement_policy_option.item_selected.connect(_on_placement_policy_selected)
	primitive_option.item_selected.connect(_on_primitive_selected)
	radius_decrease_button.pressed.connect(_on_radius_decrease_pressed)
	radius_increase_button.pressed.connect(_on_radius_increase_pressed)
	add_empty_stroke_button.pressed.connect(_on_add_empty_stroke_pressed)
	commit_pending_button.pressed.connect(_on_commit_pending_pressed)
	undo_layer_button.pressed.connect(_on_undo_layer_pressed)
	redo_layer_button.pressed.connect(_on_redo_layer_pressed)
	body_stack_option.item_selected.connect(_on_body_stack_selected)
	delete_selected_body_button.pressed.connect(_on_delete_selected_body_pressed)
	workspace_view_container.gui_input.connect(_on_workspace_view_gui_input)
	workspace_view_container.mouse_exited.connect(_on_workspace_view_mouse_exited)
	workspace_view_container.resized.connect(_sync_workspace_subviewport_size)
	close_button.pressed.connect(close_ui)
	_ensure_workspace_preview()
	get_viewport().size_changed.connect(_apply_fullscreen_workspace_layout)
	call_deferred("_sync_workspace_subviewport_size")

func toggle_start_menu_for(player, stage_controller: Node, bench_name: String, placement_space: Node3D = null) -> void:
	if is_open():
		close_ui()
		return
	open_for(player, stage_controller, bench_name, placement_space)

func toggle_for(player, stage_controller: Node, bench_name: String, placement_space: Node3D = null) -> void:
	toggle_start_menu_for(player, stage_controller, bench_name, placement_space)

func open_for(player, stage_controller: Node, bench_name: String, placement_space: Node3D = null) -> void:
	active_player = player
	active_stage_controller = stage_controller
	active_placement_space = placement_space
	current_bench_name = bench_name
	title_label.text = "%s Forge Station V2" % current_bench_name
	subtitle_label.text = "Stage 1 V2 authoring surface"
	_connect_stage_controller()
	if active_stage_controller != null:
		active_stage_controller.ensure_authoring_state("%s V2 Draft" % current_bench_name)
	_ensure_workspace_preview()
	if workspace_preview != null and workspace_preview.has_method("bind_stage_controller"):
		workspace_preview.call("bind_stage_controller", active_stage_controller)
	call_deferred("_sync_workspace_subviewport_size")
	_configure_options_from_controller()
	_refresh_from_controller()
	visible = true
	panel.visible = true
	if active_player != null and active_player.has_method("set_ui_mode_enabled"):
		active_player.call("set_ui_mode_enabled", true)

func close_ui() -> void:
	if not is_open():
		return
	if workspace_brush_stroke_active:
		_finish_workspace_brush_stroke(Vector2.ZERO, false)
	_finish_workspace_spline_point_drag()
	_close_keybindings_popup()
	_close_settings_popup()
	panel.visible = false
	visible = false
	if active_player != null and active_player.has_method("set_ui_mode_enabled"):
		active_player.call("set_ui_mode_enabled", false)
	_disconnect_stage_controller()
	if workspace_preview != null and workspace_preview.has_method("clear_stage_controller"):
		workspace_preview.call("clear_stage_controller")
	workspace_drag_active = false
	workspace_brush_stroke_active = false
	workspace_spline_point_drag_active = false
	workspace_spline_drag_point_index = -1
	active_player = null
	active_stage_controller = null
	active_placement_space = null
	current_bench_name = ""
	closed.emit()

func is_open() -> bool:
	return panel.visible

func _ensure_top_action_bar() -> void:
	if root_vbox == null:
		return
	action_host_row = root_vbox.get_node_or_null("V2ActionHostRow") as HBoxContainer
	if action_host_row == null:
		action_host_row = HBoxContainer.new()
		action_host_row.name = "V2ActionHostRow"
		action_host_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_host_row.add_theme_constant_override("separation", 6)
		root_vbox.add_child(action_host_row)
	var target_index: int = header_vbox.get_index() + 1 if header_vbox != null else 0
	root_vbox.move_child(action_host_row, target_index)
	draft_menu_button = _ensure_action_menu_button("DraftMenuButton", "Draft")
	build_menu_button = _ensure_action_menu_button("BuildMenuButton", "Build")
	material_menu_button = _ensure_action_menu_button("MaterialMenuButton", "Material")
	shape_menu_button = _ensure_action_menu_button("ShapeMenuButton", "Shape")
	layers_menu_button = _ensure_action_menu_button("LayersMenuButton", "Layers")
	view_menu_button = _ensure_action_menu_button("ViewMenuButton", "View")
	status_menu_button = _ensure_action_menu_button("StatusMenuButton", "Status")
	settings_button = _ensure_action_button("SettingsButton", "Settings")
	_configure_v2_increment_popup(shape_menu_button.get_popup())
	action_status_label = action_host_row.get_node_or_null("ActionStatusLabel") as Label
	if action_status_label == null:
		action_status_label = Label.new()
		action_status_label.name = "ActionStatusLabel"
		action_host_row.add_child(action_status_label)
	action_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	action_status_label.clip_text = true
	if close_button != null:
		if close_button.get_parent() != action_host_row:
			close_button.reparent(action_host_row)
		close_button.text = "Close"
		close_button.custom_minimum_size = Vector2(92.0, 30.0)
	if footer_row != null:
		footer_row.visible = false
	_rebuild_v2_action_menus()

func _ensure_action_button(button_name: String, button_text: String) -> Button:
	var button := action_host_row.get_node_or_null(button_name) as Button
	if button == null:
		button = Button.new()
		button.name = button_name
		action_host_row.add_child(button)
	button.text = button_text
	button.custom_minimum_size = Vector2(82.0, 30.0)
	button.focus_mode = Control.FOCUS_NONE
	if not button.pressed.is_connected(_open_settings_popup):
		button.pressed.connect(_open_settings_popup)
	return button

func _ensure_action_menu_button(button_name: String, button_text: String) -> MenuButton:
	var button := action_host_row.get_node_or_null(button_name) as MenuButton
	if button == null:
		button = MenuButton.new()
		button.name = button_name
		action_host_row.add_child(button)
	button.text = button_text
	button.custom_minimum_size = Vector2(82.0, 30.0)
	button.switch_on_hover = true
	button.focus_mode = Control.FOCUS_NONE
	_connect_v2_popup(button.get_popup())
	return button

func _apply_margin(container: MarginContainer, margin_px: int) -> void:
	if container == null:
		return
	container.add_theme_constant_override("margin_left", margin_px)
	container.add_theme_constant_override("margin_top", margin_px)
	container.add_theme_constant_override("margin_right", margin_px)
	container.add_theme_constant_override("margin_bottom", margin_px)

func _apply_v2_popup_theme(control) -> void:
	if control == null:
		return
	control.add_theme_stylebox_override("panel", _build_v2_popup_panel_style())

func _build_v2_popup_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.052, 0.058, 1.0)
	style.border_color = Color(0.19, 0.24, 0.26, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style

func _apply_v2_header_layout(compact_layout: bool, ultra_compact_layout: bool) -> void:
	if header_vbox == null:
		return
	header_vbox.visible = not compact_layout
	header_vbox.add_theme_constant_override("separation", 2 if compact_layout else 6)
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", 16 if compact_layout else 20)
		title_label.clip_text = true
	if subtitle_label != null:
		subtitle_label.visible = not compact_layout

func _apply_v2_action_bar_layout(compact_layout: bool, ultra_compact_layout: bool) -> void:
	if action_host_row == null:
		return
	var menu_width: float = 50.0 if ultra_compact_layout else 68.0 if compact_layout else 82.0
	var menu_height: float = 26.0 if ultra_compact_layout else 28.0 if compact_layout else 30.0
	var button_entries: Array[Dictionary] = [
		{"button": draft_menu_button, "wide": "Draft", "compact": "Draft", "ultra": "Dft"},
		{"button": build_menu_button, "wide": "Build", "compact": "Build", "ultra": "Bld"},
		{"button": material_menu_button, "wide": "Material", "compact": "Mat", "ultra": "Mat"},
		{"button": shape_menu_button, "wide": "Shape", "compact": "Shape", "ultra": "Shp"},
		{"button": layers_menu_button, "wide": "Layers", "compact": "Layers", "ultra": "Lyr"},
		{"button": view_menu_button, "wide": "View", "compact": "View", "ultra": "View"},
		{"button": status_menu_button, "wide": "Status", "compact": "Info", "ultra": "Info"},
		{"button": settings_button, "wide": "Settings", "compact": "Set", "ultra": "Set"},
	]
	for entry: Dictionary in button_entries:
		var button := entry.get("button", null) as Button
		if button == null:
			continue
		button.text = String(entry.get("ultra" if ultra_compact_layout else "compact" if compact_layout else "wide", "Menu"))
		button.custom_minimum_size = Vector2(menu_width, menu_height)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	action_host_row.add_theme_constant_override("separation", 2 if ultra_compact_layout else 4 if compact_layout else 6)
	action_host_row.custom_minimum_size = Vector2.ZERO
	if action_status_label != null:
		action_status_label.visible = not compact_layout
		action_status_label.custom_minimum_size = Vector2.ZERO
		action_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if close_button != null:
		close_button.text = "X" if compact_layout else "Close"
		close_button.custom_minimum_size = Vector2(36.0 if ultra_compact_layout else 54.0 if compact_layout else 92.0, menu_height)

func _apply_v2_workspace_chrome_layout(compact_layout: bool) -> void:
	if workspace_title_label != null:
		workspace_title_label.visible = false
	if workspace_status_label != null:
		workspace_status_label.visible = not compact_layout
	if workspace_vbox != null:
		workspace_vbox.add_theme_constant_override("separation", 0 if compact_layout else 4)

func _ensure_workspace_frame_host() -> void:
	if workspace_vbox == null or workspace_view_container == null:
		return
	workspace_frame_host = workspace_vbox.get_node_or_null("WorkspaceFrameHost") as Control
	if workspace_frame_host == null:
		workspace_frame_host = Control.new()
		workspace_frame_host.name = "WorkspaceFrameHost"
		workspace_frame_host.clip_contents = true
		workspace_vbox.add_child(workspace_frame_host)
	workspace_frame_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_frame_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_frame_host.custom_minimum_size = Vector2.ZERO
	if workspace_view_container.get_parent() != workspace_frame_host:
		workspace_view_container.reparent(workspace_frame_host)
	workspace_view_container.custom_minimum_size = Vector2.ZERO
	workspace_view_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	workspace_view_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	workspace_view_container.mouse_filter = Control.MOUSE_FILTER_STOP
	var target_index := 1 if workspace_title_label != null else 0
	workspace_vbox.move_child(workspace_frame_host, mini(target_index, workspace_vbox.get_child_count() - 1))
	if workspace_status_label != null:
		workspace_vbox.move_child(workspace_status_label, workspace_vbox.get_child_count() - 1)
	if not workspace_frame_host.resized.is_connected(_sync_workspace_frame_layout):
		workspace_frame_host.resized.connect(_sync_workspace_frame_layout)
	call_deferred("_sync_workspace_frame_layout")

func _sync_workspace_frame_layout() -> void:
	if workspace_frame_host == null or workspace_view_container == null:
		return
	var available_size: Vector2 = workspace_frame_host.size
	if available_size.x <= 1.0 or available_size.y <= 1.0:
		return
	var target_size := Vector2(available_size.x, available_size.x / WORKSPACE_VIEWPORT_ASPECT)
	if target_size.y > available_size.y:
		target_size.y = available_size.y
		target_size.x = target_size.y * WORKSPACE_VIEWPORT_ASPECT
	target_size.x = maxf(floor(target_size.x), 1.0)
	target_size.y = maxf(floor(target_size.y), 1.0)
	var target_subviewport_size := Vector2i(int(target_size.x), int(target_size.y))
	if workspace_subviewport != null and workspace_subviewport.size != target_subviewport_size:
		workspace_subviewport.size = target_subviewport_size
	workspace_view_container.position = ((available_size - target_size) * 0.5).floor()
	workspace_view_container.size = target_size
	_sync_workspace_subviewport_size()

func _apply_v2_fit_scale(viewport_size: Vector2) -> void:
	if panel == null or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var minimum_size: Vector2 = panel.get_combined_minimum_size()
	minimum_size.x = maxf(minimum_size.x, 1.0)
	minimum_size.y = maxf(minimum_size.y, 1.0)
	var available_size := Vector2(
		maxf(viewport_size.x - UI_FIT_PADDING_PX, 1.0),
		maxf(viewport_size.y - UI_FIT_PADDING_PX, 1.0)
	)
	var fit_scale: float = minf(1.0, minf(
		available_size.x / minimum_size.x,
		available_size.y / minimum_size.y
	))
	fit_scale = clampf(fit_scale, UI_FIT_SCALE_MIN, 1.0)
	last_ui_fit_scale = fit_scale
	panel.scale = Vector2(fit_scale, fit_scale)
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = (viewport_size.x / fit_scale) - viewport_size.x
	panel.offset_bottom = (viewport_size.y / fit_scale) - viewport_size.y

func _connect_v2_popup(popup: PopupMenu) -> void:
	if popup == null:
		return
	_apply_v2_popup_theme(popup)
	if not popup.id_pressed.is_connected(_on_v2_menu_id_pressed):
		popup.id_pressed.connect(_on_v2_menu_id_pressed)

func _configure_v2_increment_popup(popup: PopupMenu) -> void:
	if popup == null:
		return
	popup.hide_on_item_selection = false
	popup.hide_on_checkable_item_selection = false

func _ensure_keybinding_state() -> Resource:
	if keybinding_state == null:
		keybinding_state = ForgeV2KeybindingStateScript.load_or_create()
	return keybinding_state

func _ensure_settings_popup() -> void:
	if is_instance_valid(settings_popup):
		return
	settings_popup = PopupPanel.new()
	settings_popup.name = "V2SettingsPopup"
	settings_popup.visible = false
	settings_popup.unresizable = true
	_apply_v2_popup_theme(settings_popup)
	add_child(settings_popup)

	var popup_margin := MarginContainer.new()
	popup_margin.name = "SettingsMargin"
	_apply_margin(popup_margin, 12)
	settings_popup.add_child(popup_margin)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.name = "SettingsVBox"
	popup_vbox.add_theme_constant_override("separation", 12)
	popup_margin.add_child(popup_vbox)

	var header_row := HBoxContainer.new()
	header_row.name = "SettingsHeaderRow"
	header_row.add_theme_constant_override("separation", 8)
	popup_vbox.add_child(header_row)

	var title := Label.new()
	title.name = "SettingsTitle"
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	var settings_close_button := Button.new()
	settings_close_button.name = "SettingsCloseButton"
	settings_close_button.text = "X"
	settings_close_button.custom_minimum_size = Vector2(34.0, 28.0)
	settings_close_button.focus_mode = Control.FOCUS_NONE
	settings_close_button.pressed.connect(_close_settings_popup)
	header_row.add_child(settings_close_button)

	var smoothing_row := HBoxContainer.new()
	smoothing_row.name = "FreehandSmoothingRow"
	smoothing_row.add_theme_constant_override("separation", 10)
	popup_vbox.add_child(smoothing_row)

	var smoothing_label := Label.new()
	smoothing_label.name = "FreehandSmoothingLabel"
	smoothing_label.text = "Freehand Smoothing"
	smoothing_label.custom_minimum_size = Vector2(168.0, 0.0)
	smoothing_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	smoothing_row.add_child(smoothing_label)

	freehand_smoothing_slider = HSlider.new()
	freehand_smoothing_slider.name = "FreehandSmoothingSlider"
	freehand_smoothing_slider.min_value = 0.0
	freehand_smoothing_slider.max_value = 10.0
	freehand_smoothing_slider.step = 1.0
	freehand_smoothing_slider.rounded = true
	freehand_smoothing_slider.tick_count = 11
	freehand_smoothing_slider.ticks_on_borders = true
	freehand_smoothing_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	freehand_smoothing_slider.custom_minimum_size = Vector2(210.0, 0.0)
	freehand_smoothing_slider.value_changed.connect(_on_freehand_smoothing_value_changed)
	smoothing_row.add_child(freehand_smoothing_slider)

	freehand_smoothing_value_label = Label.new()
	freehand_smoothing_value_label.name = "FreehandSmoothingValueLabel"
	freehand_smoothing_value_label.custom_minimum_size = Vector2(36.0, 0.0)
	freehand_smoothing_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	freehand_smoothing_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	freehand_smoothing_value_label.text = "0"
	smoothing_row.add_child(freehand_smoothing_value_label)

	var keybindings_button := Button.new()
	keybindings_button.name = "OpenKeybindingsButton"
	keybindings_button.text = "Keybindings"
	keybindings_button.custom_minimum_size = Vector2(160.0, 32.0)
	keybindings_button.focus_mode = Control.FOCUS_NONE
	keybindings_button.pressed.connect(_open_keybindings_popup)
	popup_vbox.add_child(keybindings_button)

func _ensure_keybindings_popup() -> void:
	if is_instance_valid(keybindings_popup):
		return
	keybindings_popup = PopupPanel.new()
	keybindings_popup.name = "V2KeybindingsPopup"
	keybindings_popup.visible = false
	keybindings_popup.unresizable = true
	_apply_v2_popup_theme(keybindings_popup)
	add_child(keybindings_popup)

	var popup_margin := MarginContainer.new()
	popup_margin.name = "KeybindingsMargin"
	_apply_margin(popup_margin, 12)
	keybindings_popup.add_child(popup_margin)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.name = "KeybindingsVBox"
	popup_vbox.add_theme_constant_override("separation", 10)
	popup_margin.add_child(popup_vbox)

	var header_row := HBoxContainer.new()
	header_row.name = "KeybindingsHeaderRow"
	header_row.add_theme_constant_override("separation", 8)
	popup_vbox.add_child(header_row)

	var title := Label.new()
	title.name = "KeybindingsTitle"
	title.text = "Forge V2 Keybindings"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	var reset_button := Button.new()
	reset_button.name = "ResetKeybindingsButton"
	reset_button.text = "Reset"
	reset_button.custom_minimum_size = Vector2(78.0, 28.0)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(_on_reset_keybindings_pressed)
	header_row.add_child(reset_button)

	var close_button_local := Button.new()
	close_button_local.name = "KeybindingsCloseButton"
	close_button_local.text = "X"
	close_button_local.custom_minimum_size = Vector2(34.0, 28.0)
	close_button_local.focus_mode = Control.FOCUS_NONE
	close_button_local.pressed.connect(_close_keybindings_popup)
	header_row.add_child(close_button_local)

	var scroll := ScrollContainer.new()
	scroll.name = "KeybindingsScroll"
	scroll.custom_minimum_size = Vector2(580.0, 360.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_vbox.add_child(scroll)

	keybindings_list_vbox = VBoxContainer.new()
	keybindings_list_vbox.name = "KeybindingsList"
	keybindings_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keybindings_list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(keybindings_list_vbox)
	_rebuild_keybindings_list()

func _open_settings_popup() -> void:
	_ensure_settings_popup()
	_refresh_settings_popup()
	settings_popup.popup_centered(Vector2i(520, 200))

func _close_settings_popup() -> void:
	if is_instance_valid(settings_popup):
		settings_popup.hide()

func _open_keybindings_popup() -> void:
	_ensure_keybindings_popup()
	_rebuild_keybindings_list()
	keybindings_popup.popup_centered(Vector2i(660, 470))

func _close_keybindings_popup() -> void:
	_cancel_keybinding_capture()
	if is_instance_valid(keybindings_popup):
		keybindings_popup.hide()
	_persist_keybinding_state()

func _refresh_settings_popup() -> void:
	_ensure_settings_popup()
	if freehand_smoothing_slider == null or freehand_smoothing_value_label == null:
		return
	var smoothing_steps := 0
	if active_stage_controller != null and active_stage_controller.has_method("get_freehand_smoothing_steps"):
		smoothing_steps = int(active_stage_controller.call("get_freehand_smoothing_steps"))
	smoothing_steps = clampi(smoothing_steps, 0, 10)
	is_refreshing_settings_ui = true
	freehand_smoothing_slider.editable = active_stage_controller != null
	freehand_smoothing_slider.set_value_no_signal(float(smoothing_steps))
	freehand_smoothing_value_label.text = str(smoothing_steps)
	is_refreshing_settings_ui = false

func _on_freehand_smoothing_value_changed(value: float) -> void:
	if is_refreshing_settings_ui:
		return
	var smoothing_steps := clampi(roundi(value), 0, 10)
	is_refreshing_settings_ui = true
	if freehand_smoothing_slider != null:
		freehand_smoothing_slider.set_value_no_signal(float(smoothing_steps))
	if freehand_smoothing_value_label != null:
		freehand_smoothing_value_label.text = str(smoothing_steps)
	is_refreshing_settings_ui = false
	if active_stage_controller != null and active_stage_controller.has_method("set_freehand_smoothing_steps"):
		active_stage_controller.call("set_freehand_smoothing_steps", smoothing_steps)

func _rebuild_keybindings_list() -> void:
	_ensure_keybinding_state()
	if keybindings_list_vbox == null:
		return
	for child: Node in keybindings_list_vbox.get_children():
		child.queue_free()
	keybinding_buttons_by_action.clear()
	var entries: Array = keybinding_state.call("get_action_entries") as Array
	for entry_variant in entries:
		var entry: Dictionary = entry_variant as Dictionary
		var action_name := StringName(entry.get("action", StringName()))
		var row := HBoxContainer.new()
		row.name = "KeybindingRow_%s" % String(action_name)
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keybindings_list_vbox.add_child(row)

		var action_label := Label.new()
		action_label.name = "ActionLabel"
		action_label.text = String(entry.get("display_name", String(action_name)))
		action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_label.clip_text = true
		row.add_child(action_label)

		var binding_button := Button.new()
		binding_button.name = "BindingButton"
		binding_button.text = String(entry.get("binding_label", "Unbound"))
		binding_button.custom_minimum_size = Vector2(190.0, 30.0)
		binding_button.focus_mode = Control.FOCUS_NONE
		binding_button.pressed.connect(_begin_keybinding_capture.bind(action_name, binding_button))
		row.add_child(binding_button)
		keybinding_buttons_by_action[action_name] = binding_button

func _begin_keybinding_capture(action_name: StringName, binding_button: Button) -> void:
	_cancel_keybinding_capture()
	keybinding_capture_action = action_name
	keybinding_capture_button = binding_button
	keybinding_capture_keyboard_data = {}
	if keybinding_capture_button != null:
		keybinding_capture_button.text = "Press keys to bind"
		keybinding_capture_button.modulate = Color(1.0, 1.0, 1.0, 0.5)

func _cancel_keybinding_capture() -> void:
	if keybinding_capture_button != null and keybinding_capture_action != StringName():
		keybinding_capture_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		keybinding_capture_button.text = _get_v2_binding_label(keybinding_capture_action)
	keybinding_capture_action = StringName()
	keybinding_capture_button = null
	keybinding_capture_keyboard_data = {}

func _commit_keybinding_capture(binding_data: Dictionary) -> void:
	if keybinding_capture_action == StringName():
		return
	_ensure_keybinding_state()
	var committed_action := keybinding_capture_action
	keybinding_state.call("set_binding_data", keybinding_capture_action, binding_data)
	_persist_keybinding_state()
	if keybinding_capture_button != null:
		keybinding_capture_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		keybinding_capture_button.text = _get_v2_binding_label(committed_action)
	keybinding_capture_action = StringName()
	keybinding_capture_button = null
	keybinding_capture_keyboard_data = {}
	_rebuild_keybindings_list()

func _is_keybinding_capture_active() -> bool:
	return keybinding_capture_action != StringName()

func _handle_keybinding_capture_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.echo:
			return
		if key_event.pressed:
			if key_event.physical_keycode == KEY_ESCAPE:
				_cancel_keybinding_capture()
				get_viewport().set_input_as_handled()
				return
			if keybinding_capture_keyboard_data.is_empty():
				keybinding_capture_keyboard_data = ForgeV2KeybindingStateScript.build_binding_data_from_key_event(key_event)
			else:
				keybinding_capture_keyboard_data = ForgeV2KeybindingStateScript.append_secondary_key_event(
					keybinding_capture_keyboard_data,
					key_event
				)
			get_viewport().set_input_as_handled()
			return
		if not keybinding_capture_keyboard_data.is_empty():
			_commit_keybinding_capture(keybinding_capture_keyboard_data)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		var binding_data := ForgeV2KeybindingStateScript.build_binding_data_from_mouse_event(
			mouse_event,
			keybinding_capture_keyboard_data
		)
		_commit_keybinding_capture(binding_data)
		get_viewport().set_input_as_handled()

func _on_reset_keybindings_pressed() -> void:
	_ensure_keybinding_state()
	keybinding_state.call("reset_all_to_defaults")
	_persist_keybinding_state()
	_cancel_keybinding_capture()
	_rebuild_keybindings_list()

func _persist_keybinding_state() -> void:
	if keybinding_state != null and keybinding_state.has_method("persist"):
		keybinding_state.call("persist")

func _get_v2_binding_label(action_name: StringName) -> String:
	_ensure_keybinding_state()
	return String(keybinding_state.call("get_binding_label", action_name))

func _v2_event_matches_binding(action_name: StringName, event: InputEvent) -> bool:
	_ensure_keybinding_state()
	return bool(keybinding_state.call("event_matches_action", action_name, event))

func _get_v2_binding_mouse_button(action_name: StringName) -> int:
	_ensure_keybinding_state()
	var binding_data: Dictionary = keybinding_state.call("get_binding_data", action_name) as Dictionary
	return int(binding_data.get("mouse_button", MOUSE_BUTTON_NONE))

func _prepare_v2_submenu(parent_popup: PopupMenu, submenu_name: String) -> PopupMenu:
	var submenu := parent_popup.get_node_or_null(submenu_name) as PopupMenu
	if submenu == null:
		submenu = PopupMenu.new()
		submenu.name = submenu_name
		parent_popup.add_child(submenu)
	submenu.clear()
	_connect_v2_popup(submenu)
	return submenu

func _register_v2_menu_action(action_id: StringName, action_value: Variant = null) -> int:
	var menu_id := menu_next_id
	menu_next_id += 1
	menu_action_lookup[menu_id] = {
		"action": action_id,
		"value": action_value,
	}
	return menu_id

func _add_v2_menu_action(
	popup: PopupMenu,
	label: String,
	action_id: StringName,
	action_value: Variant = null,
	disabled: bool = false
) -> void:
	popup.add_item(label, _register_v2_menu_action(action_id, action_value))
	if disabled:
		popup.set_item_disabled(popup.get_item_count() - 1, true)

func _add_v2_disabled_line(popup: PopupMenu, label: String) -> void:
	popup.add_item(label)
	popup.set_item_disabled(popup.get_item_count() - 1, true)

func _add_v2_option_items(
	popup: PopupMenu,
	options: Array,
	action_id: StringName,
	active_value: Variant
) -> void:
	if options.is_empty():
		_add_v2_disabled_line(popup, "No options")
		return
	for option in options:
		var option_dict: Dictionary = option as Dictionary
		var option_value: Variant = option_dict.get("id", StringName())
		var label := String(option_dict.get("label", String(option_value)))
		popup.add_radio_check_item(label, _register_v2_menu_action(action_id, option_value))
		popup.set_item_checked(popup.get_item_count() - 1, option_value == active_value)

func _get_v2_controller_options(method_name: StringName) -> Array:
	if active_stage_controller == null or not active_stage_controller.has_method(method_name):
		return []
	return active_stage_controller.call(method_name) as Array

func _get_player_forge_wip_library_state() -> PlayerForgeWipLibraryState:
	if active_player == null or not active_player.has_method("get_forge_wip_library_state"):
		return null
	return active_player.call("get_forge_wip_library_state") as PlayerForgeWipLibraryState

func _collect_saved_v2_wips() -> Array[CraftedItemWIP]:
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	if wip_library == null:
		return []
	var saved_v2_wips: Array[CraftedItemWIP] = []
	for saved_wip: CraftedItemWIP in wip_library.get_saved_wips():
		if saved_wip == null or saved_wip.forge_v2_authoring_state == null:
			continue
		saved_v2_wips.append(saved_wip)
	return saved_v2_wips

func _format_saved_v2_wip_label(saved_wip: CraftedItemWIP) -> String:
	if saved_wip == null:
		return "Unnamed V2 Draft"
	var project_name := saved_wip.forge_project_name.strip_edges()
	return project_name if not project_name.is_empty() else String(saved_wip.wip_id)

func _rebuild_v2_action_menus() -> void:
	if draft_menu_button == null or build_menu_button == null or material_menu_button == null:
		return
	menu_action_lookup.clear()
	menu_next_id = MENU_ID_BASE
	var summary: Dictionary = active_stage_controller.get_status_summary() if active_stage_controller != null else {}
	_rebuild_v2_draft_menu(summary)
	_rebuild_v2_build_menu(summary)
	_rebuild_v2_material_menu(summary)
	_rebuild_v2_shape_menu(summary)
	_rebuild_v2_layers_menu(summary)
	_rebuild_v2_view_menu()
	_rebuild_v2_status_menu(summary)
	_sync_v2_action_status(summary)

func _rebuild_v2_draft_menu(summary: Dictionary) -> void:
	var popup: PopupMenu = draft_menu_button.get_popup()
	popup.clear()
	var has_draft := active_stage_controller != null
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	var saved_v2_wips: Array[CraftedItemWIP] = _collect_saved_v2_wips()
	var source_wip_id := StringName(summary.get("source_wip_id", StringName()))
	var saved_label := "Saved WIP: %s" % String(source_wip_id) if source_wip_id != StringName() else "Unsaved V2 draft"
	_add_v2_disabled_line(popup, saved_label)
	_add_v2_menu_action(popup, "Save Draft (Ctrl+S)", &"draft_save", null, not has_draft or wip_library == null)
	popup.add_separator()
	_add_v2_menu_action(popup, "New V2 Draft", &"draft_new", null, not has_draft)
	_add_v2_menu_action(
		popup,
		"Clear Pending Work",
		&"draft_clear",
		null,
		not has_draft or int(summary.get("pending_material_body_count", 0)) <= 0
	)
	popup.add_separator()
	var saved_submenu: PopupMenu = _prepare_v2_submenu(popup, "SavedV2DraftSubmenu")
	if saved_v2_wips.is_empty():
		_add_v2_disabled_line(saved_submenu, "No saved V2 drafts")
	else:
		for saved_wip: CraftedItemWIP in saved_v2_wips:
			_add_v2_menu_action(
				saved_submenu,
				_format_saved_v2_wip_label(saved_wip),
				&"draft_load_saved",
				saved_wip.wip_id
			)
	popup.add_submenu_item("Saved V2 Drafts", String(saved_submenu.name))
	popup.set_item_disabled(popup.get_item_count() - 1, saved_v2_wips.is_empty())
	popup.add_separator()
	_add_v2_menu_action(popup, "Close Forge", &"close")

func _rebuild_v2_build_menu(summary: Dictionary) -> void:
	var popup: PopupMenu = build_menu_button.get_popup()
	popup.clear()
	_add_v2_disabled_line(popup, "Path: %s" % String(summary.get("builder_scope", "No draft")))
	var path_submenu: PopupMenu = _prepare_v2_submenu(popup, "BuilderPathSubmenu")
	_add_v2_option_items(
		path_submenu,
		_get_v2_controller_options(&"get_builder_path_options"),
		&"builder_path",
		summary.get("builder_path", StringName())
	)
	popup.add_submenu_item("Builder Path", String(path_submenu.name))
	var component_submenu: PopupMenu = _prepare_v2_submenu(popup, "BuilderComponentSubmenu")
	_add_v2_option_items(
		component_submenu,
		_get_v2_controller_options(&"get_builder_component_options"),
		&"builder_component",
		summary.get("builder_component", StringName())
	)
	popup.add_submenu_item("Component", String(component_submenu.name))
	popup.add_separator()
	var operation_submenu: PopupMenu = _prepare_v2_submenu(popup, "OperationSubmenu")
	_add_v2_option_items(
		operation_submenu,
		_get_v2_controller_options(&"get_operation_options"),
		&"operation",
		summary.get("operation", StringName())
	)
	popup.add_submenu_item("Operation", String(operation_submenu.name))
	var placement_submenu: PopupMenu = _prepare_v2_submenu(popup, "PlacementPolicySubmenu")
	_add_v2_option_items(
		placement_submenu,
		_get_v2_controller_options(&"get_placement_policy_options"),
		&"placement_policy",
		summary.get("placement_policy", StringName())
	)
	popup.add_submenu_item("Placement Policy", String(placement_submenu.name))

func _rebuild_v2_material_menu(summary: Dictionary) -> void:
	var popup: PopupMenu = material_menu_button.get_popup()
	popup.clear()
	_add_v2_disabled_line(popup, "Active: %s" % String(summary.get("active_material_label", "No material")))
	var material_submenu: PopupMenu = _prepare_v2_submenu(popup, "MaterialVariantSubmenu")
	_add_v2_option_items(
		material_submenu,
		_get_v2_controller_options(&"get_material_palette_options"),
		&"material",
		summary.get("active_material", StringName())
	)
	popup.add_submenu_item("Material Variant", String(material_submenu.name))
	var tier_policy: Dictionary = summary.get("material_tier_policy", {}) as Dictionary
	if not tier_policy.is_empty():
		popup.add_separator()
		_add_v2_disabled_line(popup, String(tier_policy.get("summary", "Tier policy active")))

func _rebuild_v2_shape_menu(summary: Dictionary) -> void:
	var popup: PopupMenu = shape_menu_button.get_popup()
	popup.clear()
	_add_v2_disabled_line(popup, "Tool: %s" % String(summary.get("active_tool_label", "None")))
	var tool_submenu: PopupMenu = _prepare_v2_submenu(popup, "ToolSubmenu")
	_add_v2_option_items(
		tool_submenu,
		_get_v2_controller_options(&"get_tool_options"),
		&"tool",
		summary.get("active_tool", StringName())
	)
	popup.add_submenu_item("Tool", String(tool_submenu.name))
	popup.add_separator()
	_add_v2_disabled_line(popup, String(summary.get("spline_line_status_label", "Spline: no points")))
	var spline_point_count := int(summary.get("spline_line_point_count", 0))
	var spline_finished := bool(summary.get("spline_line_finished", false))
	_add_v2_menu_action(
		popup,
		"Finish Spline Line",
		&"spline_finish",
		null,
		active_stage_controller == null or spline_point_count < 2 or spline_finished
	)
	_add_v2_menu_action(
		popup,
		"Cancel Spline Line",
		&"spline_cancel",
		null,
		active_stage_controller == null or spline_point_count <= 0
	)
	var csg_noodle_enabled := bool(summary.get("spline_line_csg_noodle_enabled", false))
	_add_v2_disabled_line(popup, String(summary.get("spline_line_csg_noodle_status_label", "CSG noodle: needs 2 points")))
	_add_v2_menu_action(
		popup,
		"Generate CSG Noodle",
		&"spline_generate_csg_noodle",
		null,
		active_stage_controller == null or not bool(summary.get("can_generate_spline_line_csg_noodle", false))
	)
	_add_v2_menu_action(
		popup,
		"Clear CSG Noodle",
		&"spline_clear_csg_noodle",
		null,
		active_stage_controller == null or not csg_noodle_enabled
	)
	popup.add_separator()
	_add_v2_disabled_line(popup, "Primitive: %s" % String(summary.get("active_primitive_label", "None")))
	var primitive_submenu: PopupMenu = _prepare_v2_submenu(popup, "PrimitiveSubmenu")
	_add_v2_option_items(
		primitive_submenu,
		_get_v2_controller_options(&"get_primitive_options"),
		&"primitive",
		summary.get("active_primitive", StringName())
	)
	popup.add_submenu_item("Primitive", String(primitive_submenu.name))
	popup.add_separator()
	_add_v2_disabled_line(popup, String(summary.get("brush_radius_label", "Radius n/a")))
	_add_v2_menu_action(popup, "Radius -", &"radius_down", null, active_stage_controller == null)
	_add_v2_menu_action(popup, "Radius +", &"radius_up", null, active_stage_controller == null)

func _rebuild_v2_layers_menu(summary: Dictionary) -> void:
	var popup: PopupMenu = layers_menu_button.get_popup()
	popup.clear()
	var has_draft := active_stage_controller != null
	_add_v2_menu_action(popup, "Add Primitive Deposit", &"add_primitive", null, not has_draft)
	_add_v2_menu_action(
		popup,
		"Commit Pending Layer",
		&"commit_layer",
		null,
		not has_draft or int(summary.get("pending_material_body_count", 0)) <= 0
	)
	_add_v2_menu_action(
		popup,
		"Undo Layer",
		&"undo_layer",
		null,
		not has_draft or int(summary.get("committed_layer_count", 0)) <= 0
	)
	_add_v2_menu_action(
		popup,
		"Redo Layer",
		&"redo_layer",
		null,
		not has_draft or int(summary.get("undone_layer_count", 0)) <= 0
	)
	popup.add_separator()
	var body_submenu: PopupMenu = _prepare_v2_submenu(popup, "BodyStackSubmenu")
	_add_v2_option_items(
		body_submenu,
		_get_v2_controller_options(&"get_material_body_stack_options"),
		&"select_body",
		summary.get("selected_material_body_id", StringName())
	)
	popup.add_submenu_item("Body Stack", String(body_submenu.name))
	var selected_body_summary: Dictionary = summary.get("selected_material_body", {}) as Dictionary
	var delete_disabled := (
		not has_draft
		or selected_body_summary.is_empty()
		or bool(selected_body_summary.get("is_seed", false))
		or bool(selected_body_summary.get("is_committed", false))
	)
	_add_v2_menu_action(popup, "Delete Selected Body", &"delete_body", null, delete_disabled)

func _rebuild_v2_view_menu() -> void:
	var popup: PopupMenu = view_menu_button.get_popup()
	popup.clear()
	_add_v2_menu_action(popup, "Fit View", &"view_fit", null, workspace_preview == null)
	_add_v2_menu_action(popup, "Reset View", &"view_reset", null, workspace_preview == null)
	popup.add_separator()
	_add_v2_menu_action(popup, "Zoom In", &"view_zoom_in", null, workspace_preview == null)
	_add_v2_menu_action(popup, "Zoom Out", &"view_zoom_out", null, workspace_preview == null)

func _rebuild_v2_status_menu(summary: Dictionary) -> void:
	var popup: PopupMenu = status_menu_button.get_popup()
	popup.clear()
	_add_v2_disabled_line(popup, "Forge Status")
	_add_v2_disabled_line(popup, "Draft: %s" % String(summary.get("project_name", "No draft")))
	_add_v2_disabled_line(popup, "Build: %s" % String(summary.get("builder_scope", "n/a")))
	_add_v2_disabled_line(popup, "Operation: %s" % String(summary.get("operation_label", "n/a")))
	_add_v2_disabled_line(popup, "Placement: %s" % String(summary.get("placement_policy_label", "n/a")))
	_add_v2_disabled_line(popup, "Material: %s" % String(summary.get("active_material_label", "n/a")))
	_add_v2_disabled_line(popup, "Primitive: %s" % String(summary.get("active_primitive_label", "n/a")))
	_add_v2_disabled_line(popup, String(summary.get("brush_radius_label", "Radius n/a")))
	_add_v2_disabled_line(popup, "Bodies: %s user + %s seed, %s pending" % [
		str(int(summary.get("user_material_body_count", 0))),
		str(int(summary.get("seed_material_body_count", 0))),
		str(int(summary.get("pending_material_body_count", 0))),
	])
	_add_v2_disabled_line(popup, "Layers: %s committed, %s redo" % [
		str(int(summary.get("committed_layer_count", 0))),
		str(int(summary.get("undone_layer_count", 0))),
	])
	_add_v2_disabled_line(popup, String(summary.get("material_ledger_label", "Ledger n/a")))

func _sync_v2_action_status(summary: Dictionary) -> void:
	if action_status_label == null:
		return
	action_status_label.text = "%s | %s | %s | %s" % [
		String(summary.get("builder_scope", "No draft")),
		String(summary.get("active_tool_label", "No tool")),
		String(summary.get("active_material_label", "No material")),
		String(summary.get("brush_radius_label", "Radius n/a")),
	]

func _on_v2_menu_id_pressed(menu_id: int) -> void:
	var menu_entry: Dictionary = menu_action_lookup.get(menu_id, {}) as Dictionary
	if menu_entry.is_empty():
		return
	var action_id := StringName(menu_entry.get("action", StringName()))
	var action_value: Variant = menu_entry.get("value", null)
	var keep_shape_popup_open := _is_v2_shape_repeat_action(action_id)
	match action_id:
		&"draft_save":
			_save_current_v2_draft()
		&"draft_new":
			_on_new_draft_pressed()
		&"draft_clear":
			_on_clear_strokes_pressed()
		&"draft_load_saved":
			_load_saved_v2_draft(StringName(action_value))
		&"builder_path":
			if active_stage_controller != null:
				active_stage_controller.set_builder_path_id(StringName(action_value))
		&"builder_component":
			if active_stage_controller != null:
				active_stage_controller.set_builder_component_id(StringName(action_value))
		&"operation":
			if active_stage_controller != null:
				active_stage_controller.set_active_operation_mode(StringName(action_value))
		&"placement_policy":
			if active_stage_controller != null:
				active_stage_controller.set_placement_policy(StringName(action_value))
		&"material":
			if active_stage_controller != null:
				active_stage_controller.set_active_material_variant_id(StringName(action_value))
		&"primitive":
			if active_stage_controller != null:
				active_stage_controller.set_active_primitive_id(StringName(action_value))
		&"tool":
			if active_stage_controller != null:
				active_stage_controller.set_active_tool_id(StringName(action_value))
		&"spline_finish":
			_finish_active_spline_line()
		&"spline_cancel":
			_cancel_active_spline_line()
		&"spline_generate_csg_noodle":
			_generate_active_spline_csg_noodle()
		&"spline_clear_csg_noodle":
			_clear_active_spline_csg_noodle()
		&"radius_down":
			_on_radius_decrease_pressed()
		&"radius_up":
			_on_radius_increase_pressed()
		&"add_primitive":
			_on_add_empty_stroke_pressed()
		&"commit_layer":
			_on_commit_pending_pressed()
		&"undo_layer":
			_on_undo_layer_pressed()
		&"redo_layer":
			_on_redo_layer_pressed()
		&"select_body":
			if active_stage_controller != null:
				active_stage_controller.select_material_body_id(StringName(action_value))
		&"delete_body":
			_on_delete_selected_body_pressed()
		&"view_fit":
			_call_workspace_preview_action(&"fit_view")
		&"view_reset":
			_call_workspace_preview_action(&"reset_view")
		&"view_zoom_in":
			_call_workspace_preview_action(&"zoom_by", -WORKSPACE_ZOOM_STEP)
		&"view_zoom_out":
			_call_workspace_preview_action(&"zoom_by", WORKSPACE_ZOOM_STEP)
		&"close":
			close_ui()
	if keep_shape_popup_open:
		_refresh_v2_shape_menu_popup_contents()
	else:
		_rebuild_v2_action_menus()

func _is_v2_shape_repeat_action(action_id: StringName) -> bool:
	return (
		action_id == &"radius_down"
		or action_id == &"radius_up"
	)

func _refresh_v2_shape_menu_popup_contents() -> void:
	if not is_instance_valid(shape_menu_button):
		return
	call_deferred("_refresh_v2_shape_menu_popup_contents_if_available")

func _refresh_v2_shape_menu_popup_contents_if_available() -> void:
	if not is_instance_valid(shape_menu_button):
		return
	var popup: PopupMenu = shape_menu_button.get_popup()
	var popup_visible: bool = popup.visible
	var summary: Dictionary = active_stage_controller.get_status_summary() if active_stage_controller != null else {}
	_rebuild_v2_shape_menu(summary)
	_sync_v2_action_status(summary)
	if popup_visible and not popup.visible:
		shape_menu_button.show_popup()

func _call_workspace_preview_action(method_name: StringName, argument: Variant = null) -> void:
	_ensure_workspace_preview()
	if workspace_preview == null or not workspace_preview.has_method(method_name):
		return
	if argument == null:
		workspace_preview.call(method_name)
	else:
		workspace_preview.call(method_name, argument)

func _set_active_v2_tool(tool_id: StringName) -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("set_active_tool_id"):
		return
	if workspace_brush_stroke_active:
		_finish_workspace_brush_stroke(Vector2.ZERO, false)
	_finish_workspace_spline_point_drag()
	active_stage_controller.call("set_active_tool_id", tool_id)

func _finish_active_spline_line() -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("finish_spline_line"):
		return
	_finish_workspace_spline_point_drag()
	active_stage_controller.call("finish_spline_line")

func _cancel_active_spline_line() -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("cancel_spline_line"):
		return
	_finish_workspace_spline_point_drag()
	active_stage_controller.call("cancel_spline_line")

func _generate_active_spline_csg_noodle() -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("generate_spline_line_csg_noodle"):
		return
	_finish_workspace_spline_point_drag()
	active_stage_controller.call("generate_spline_line_csg_noodle")

func _clear_active_spline_csg_noodle() -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("clear_spline_line_csg_noodle"):
		return
	active_stage_controller.call("clear_spline_line_csg_noodle")

func _save_current_v2_draft() -> bool:
	if active_stage_controller == null or not active_stage_controller.has_method("save_current_wip"):
		_set_v2_action_status_text("Save failed: no V2 draft")
		return false
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	if wip_library == null:
		_set_v2_action_status_text("Save failed: no WIP library")
		return false
	if workspace_brush_stroke_active:
		_finish_workspace_brush_stroke(Vector2.ZERO, false)
	_finish_workspace_spline_point_drag()
	var saved_wip: CraftedItemWIP = active_stage_controller.call("save_current_wip", wip_library) as CraftedItemWIP
	if saved_wip == null:
		_set_v2_action_status_text("Save failed")
		return false
	_configure_options_from_controller()
	_refresh_from_controller()
	_set_v2_action_status_text("Saved: %s" % _format_saved_v2_wip_label(saved_wip))
	return true

func _load_saved_v2_draft(saved_wip_id: StringName) -> bool:
	if active_stage_controller == null or not active_stage_controller.has_method("load_saved_wip"):
		_set_v2_action_status_text("Load failed: no V2 controller")
		return false
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	if wip_library == null or saved_wip_id == StringName():
		_set_v2_action_status_text("Load failed: no saved draft")
		return false
	var saved_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(saved_wip_id, false)
	if saved_wip == null or saved_wip.forge_v2_authoring_state == null:
		_set_v2_action_status_text("Load failed: V2 data missing")
		return false
	if workspace_brush_stroke_active:
		_finish_workspace_brush_stroke(Vector2.ZERO, false)
	_finish_workspace_spline_point_drag()
	var loaded := bool(active_stage_controller.call("load_saved_wip", saved_wip))
	if not loaded:
		_set_v2_action_status_text("Load failed")
		return false
	wip_library.set_selected_wip_id(saved_wip_id)
	_configure_options_from_controller()
	_refresh_from_controller()
	_set_v2_action_status_text("Loaded: %s" % _format_saved_v2_wip_label(saved_wip))
	return true

func _set_v2_action_status_text(status_text: String) -> void:
	if action_status_label != null:
		action_status_label.text = status_text

func _is_v2_spline_line_tool_active() -> bool:
	if active_stage_controller == null or not active_stage_controller.has_method("get_status_summary"):
		return false
	var summary: Dictionary = active_stage_controller.call("get_status_summary") as Dictionary
	return StringName(summary.get("active_tool", StringName())) == &"tool_spline_line"

func _ensure_fullscreen_workspace_layout() -> void:
	if body_margin == null or body_scroll == null or body_vbox == null or workspace_panel == null:
		return
	body_layout_hbox = body_margin.get_node_or_null("BodyHBox") as HBoxContainer
	if body_layout_hbox == null:
		body_layout_hbox = HBoxContainer.new()
		body_layout_hbox.name = "BodyHBox"
		body_layout_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_layout_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_layout_hbox.add_theme_constant_override("separation", 12)
		body_margin.add_child(body_layout_hbox)
	if body_scroll.get_parent() != body_layout_hbox:
		body_scroll.reparent(body_layout_hbox)
	if workspace_panel.get_parent() != body_layout_hbox:
		workspace_panel.reparent(body_layout_hbox)
	body_layout_hbox.move_child(body_scroll, 0)
	body_layout_hbox.move_child(workspace_panel, 1)
	_apply_fullscreen_workspace_layout()

func _apply_fullscreen_workspace_layout() -> void:
	if panel == null or body_panel == null or body_scroll == null or body_vbox == null or workspace_panel == null:
		return
	_ensure_workspace_frame_host()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var compact_layout: bool = viewport_size.x <= COMPACT_LAYOUT_WIDTH or viewport_size.y <= COMPACT_LAYOUT_HEIGHT
	var ultra_compact_layout: bool = viewport_size.x <= ULTRA_COMPACT_LAYOUT_WIDTH or viewport_size.y <= ULTRA_COMPACT_LAYOUT_HEIGHT
	var root_margin_px := 2 if ultra_compact_layout else 6 if compact_layout else 10
	var body_margin_px := 2 if ultra_compact_layout else 4 if compact_layout else 8
	var workspace_margin_px := 2 if ultra_compact_layout else 4 if compact_layout else 8
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	_apply_margin(root_margin, root_margin_px)
	_apply_margin(body_margin, body_margin_px)
	_apply_margin(workspace_margin, workspace_margin_px)
	if root_vbox != null:
		root_vbox.add_theme_constant_override("separation", 3 if ultra_compact_layout else 6 if compact_layout else 10)
	_apply_v2_header_layout(compact_layout, ultra_compact_layout)
	_apply_v2_action_bar_layout(compact_layout, ultra_compact_layout)
	_apply_v2_workspace_chrome_layout(compact_layout)
	body_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if body_layout_hbox != null:
		body_layout_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_layout_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_layout_hbox.add_theme_constant_override("separation", 0)
	body_scroll.visible = false
	body_scroll.custom_minimum_size = Vector2.ZERO
	body_scroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_vbox.custom_minimum_size = Vector2.ZERO
	workspace_panel.custom_minimum_size = Vector2.ZERO
	workspace_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if workspace_frame_host != null:
		workspace_frame_host.custom_minimum_size = Vector2.ZERO
		workspace_frame_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		workspace_frame_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_view_container.custom_minimum_size = Vector2.ZERO
	workspace_view_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	workspace_view_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if action_host_row != null:
		action_host_row.add_theme_constant_override("separation", 2 if ultra_compact_layout else 4 if compact_layout else 6)
	_apply_v2_fit_scale(viewport_size)
	call_deferred("_sync_workspace_frame_layout")

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if _is_keybinding_capture_active():
		_handle_keybinding_capture_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"ui_cancel"):
		if _is_keybinding_capture_active():
			_cancel_keybinding_capture()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(keybindings_popup) and keybindings_popup.visible:
			_close_keybindings_popup()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(settings_popup) and settings_popup.visible:
			settings_popup.hide()
			get_viewport().set_input_as_handled()
			return
		close_ui()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(keybindings_popup) and keybindings_popup.visible:
		return
	if is_instance_valid(settings_popup) and settings_popup.visible:
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_SAVE_DRAFT, event):
		_save_current_v2_draft()
		get_viewport().set_input_as_handled()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_VIEW_FIT, event):
		_call_workspace_preview_action(&"fit_view")
		get_viewport().set_input_as_handled()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_VIEW_RESET, event):
		_call_workspace_preview_action(&"reset_view")
		get_viewport().set_input_as_handled()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_SPLINE_FINISH, event):
		_finish_active_spline_line()
		get_viewport().set_input_as_handled()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_SPLINE_CANCEL, event):
		_cancel_active_spline_line()
		get_viewport().set_input_as_handled()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_SPLINE_GENERATE_CSG_NOODLE, event):
		_generate_active_spline_csg_noodle()
		get_viewport().set_input_as_handled()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_TOOL_VOLUME_STROKE, event):
		_set_active_v2_tool(&"tool_volume_stroke")
		get_viewport().set_input_as_handled()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_TOOL_SPLINE_LINE, event):
		_set_active_v2_tool(&"tool_spline_line")
		get_viewport().set_input_as_handled()

func _connect_stage_controller() -> void:
	if active_stage_controller == null:
		return
	if not active_stage_controller.authoring_state_changed.is_connected(_on_authoring_state_changed):
		active_stage_controller.authoring_state_changed.connect(_on_authoring_state_changed)

func _disconnect_stage_controller() -> void:
	if active_stage_controller == null:
		return
	if active_stage_controller.authoring_state_changed.is_connected(_on_authoring_state_changed):
		active_stage_controller.authoring_state_changed.disconnect(_on_authoring_state_changed)

func _configure_options_from_controller() -> void:
	if active_stage_controller == null:
		return
	_configure_option_button(builder_path_option, active_stage_controller.get_builder_path_options())
	_configure_option_button(builder_component_option, active_stage_controller.get_builder_component_options())
	_configure_option_button(operation_option, active_stage_controller.get_operation_options())
	_configure_option_button(placement_policy_option, active_stage_controller.get_placement_policy_options())
	_configure_option_button(primitive_option, active_stage_controller.get_primitive_options())

func _configure_option_button(option_button: OptionButton, options: Array[Dictionary]) -> void:
	option_button.clear()
	for option: Dictionary in options:
		var item_index: int = option_button.get_item_count()
		option_button.add_item(String(option.get("label", "")))
		option_button.set_item_metadata(item_index, option.get("id", StringName()))

func _refresh_from_controller() -> void:
	if active_stage_controller == null:
		status_label.text = "No V2 stage controller is attached."
		summary_label.text = ""
		_rebuild_v2_action_menus()
		if is_instance_valid(settings_popup) and settings_popup.visible:
			_refresh_settings_popup()
		return
	is_refreshing_ui = true
	var summary: Dictionary = active_stage_controller.get_status_summary()
	_configure_option_button(builder_component_option, active_stage_controller.get_builder_component_options())
	_rebuild_material_palette(
		active_stage_controller.get_material_palette_options(),
		StringName(summary.get("active_material", StringName()))
	)
	_configure_body_stack_options(active_stage_controller.get_material_body_stack_options())
	_select_option_by_metadata(builder_path_option, _resolve_builder_path_from_state())
	_select_option_by_metadata(builder_component_option, summary.get("builder_component", StringName()))
	_select_option_by_metadata(operation_option, summary.get("operation", StringName()))
	_select_option_by_metadata(placement_policy_option, summary.get("placement_policy", StringName()))
	_select_option_by_metadata(primitive_option, summary.get("active_primitive", StringName()))
	_select_option_by_metadata(body_stack_option, summary.get("selected_material_body_id", StringName()))
	builder_component_row.visible = builder_component_option.get_item_count() > 1
	var selected_body_summary: Dictionary = summary.get("selected_material_body", {}) as Dictionary
	delete_selected_body_button.disabled = (
		selected_body_summary.is_empty()
		or bool(selected_body_summary.get("is_seed", false))
		or bool(selected_body_summary.get("is_committed", false))
	)
	commit_pending_button.disabled = int(summary.get("pending_material_body_count", 0)) <= 0
	undo_layer_button.disabled = int(summary.get("committed_layer_count", 0)) <= 0
	redo_layer_button.disabled = int(summary.get("undone_layer_count", 0)) <= 0
	status_label.text = "%s | %s | %s" % [
		String(summary.get("builder_scope", "")),
		String(summary.get("operation_label", "")),
		String(summary.get("placement_policy_label", "")),
	]
	var workspace_status_parts: Array[String] = [String(summary.get("active_tool_label", ""))]
	if StringName(summary.get("active_tool", StringName())) == &"tool_spline_line":
		workspace_status_parts.append(String(summary.get("spline_line_status_label", "Spline: no points")))
		workspace_status_parts.append(String(summary.get("spline_line_csg_noodle_status_label", "CSG noodle: needs 2 points")))
		workspace_status_parts.append(String(summary.get("brush_radius_label", "")))
	else:
		workspace_status_parts.append(String(summary.get("brush_radius_label", "")))
	workspace_status_label.text = " | ".join(workspace_status_parts)
	platform_contract_label.text = String(summary.get("platform_contract_summary", ""))
	active_material_label.text = "Active: %s" % String(summary.get("active_material_label", summary.get("active_material", "")))
	radius_value_label.text = String(summary.get("brush_radius_label", "Radius 0.0000 m"))
	var platform_contract: Dictionary = summary.get("platform_contract", {}) as Dictionary
	summary_label.text = "Draft: %s\nTool: %s\nPrimitive: %s\nActive material: %s\nCSG bodies: %s user + %s seed, %s pending\n%s\n%s\nLayers: %s committed, %s redo\nSelected: %s\n%s\n%s\n%s\n%s" % [
		String(summary.get("project_name", "")),
		String(summary.get("active_tool_label", "")),
		String(summary.get("active_primitive_label", "")),
		String(summary.get("active_material_label", summary.get("active_material", ""))),
		str(int(summary.get("user_material_body_count", 0))),
		str(int(summary.get("seed_material_body_count", 0))),
		str(int(summary.get("pending_material_body_count", 0))),
		String(summary.get("spline_line_status_label", "Spline: no points")),
		String(summary.get("spline_line_csg_noodle_status_label", "CSG noodle: needs 2 points")),
		str(int(summary.get("committed_layer_count", 0))),
		str(int(summary.get("undone_layer_count", 0))),
		String(selected_body_summary.get("label", "none")),
		String(summary.get("brush_radius_label", "")),
		String(summary.get("material_ledger_label", "")),
		String(summary.get("material_usage_label", "")),
		String(platform_contract.get("validation_note", "")),
	]
	is_refreshing_ui = false
	_rebuild_v2_action_menus()
	if is_instance_valid(settings_popup) and settings_popup.visible:
		_refresh_settings_popup()

func _configure_body_stack_options(options: Array[Dictionary]) -> void:
	body_stack_option.clear()
	if options.is_empty():
		body_stack_option.add_item("No material bodies")
		body_stack_option.set_item_metadata(0, StringName())
		body_stack_option.disabled = true
		return
	body_stack_option.disabled = false
	for option: Dictionary in options:
		var item_index: int = body_stack_option.get_item_count()
		body_stack_option.add_item(String(option.get("label", "")))
		body_stack_option.set_item_metadata(item_index, option.get("id", StringName()))

func _rebuild_material_palette(options: Array[Dictionary], active_material_id: StringName) -> void:
	for child: Node in material_palette_grid.get_children():
		child.queue_free()
	for option: Dictionary in options:
		var material_id: StringName = StringName(option.get("id", StringName()))
		if material_id == StringName():
			continue
		var material_button := Button.new()
		var is_active: bool = material_id == active_material_id
		var material_color: Color = option.get("albedo_color", Color(0.8, 0.82, 0.84, 1.0))
		material_button.custom_minimum_size = MATERIAL_ICON_BUTTON_SIZE
		material_button.tooltip_text = "%s\n%s" % [
			String(option.get("label", String(material_id))),
			String(material_id),
		]
		material_button.toggle_mode = true
		material_button.focus_mode = Control.FOCUS_NONE
		material_button.icon = material_icon_texture
		material_button.expand_icon = true
		material_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		material_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		material_button.set_pressed_no_signal(is_active)
		_apply_material_button_theme(material_button, material_color, is_active)
		material_button.pressed.connect(_on_material_palette_pressed.bind(material_id))
		material_palette_grid.add_child(material_button)

func _apply_material_button_theme(button: Button, material_color: Color, is_active: bool) -> void:
	var icon_color: Color = material_color.lightened(0.22 if is_active else 0.04)
	icon_color.a = 1.0 if is_active else 0.82
	button.add_theme_color_override("icon_normal_color", icon_color)
	button.add_theme_color_override("icon_hover_color", material_color.lightened(0.28))
	button.add_theme_color_override("icon_pressed_color", material_color.lightened(0.36))
	button.add_theme_color_override("icon_disabled_color", Color(0.35, 0.37, 0.38, 0.55))
	button.add_theme_stylebox_override("normal", _build_material_button_style(material_color, is_active, false))
	button.add_theme_stylebox_override("hover", _build_material_button_style(material_color, true, false))
	button.add_theme_stylebox_override("pressed", _build_material_button_style(material_color, true, true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _build_material_button_style(material_color: Color, highlighted: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.066, 0.076, 0.96) if not pressed else Color(0.075, 0.092, 0.102, 0.98)
	style.border_width_left = 2 if highlighted else 1
	style.border_width_top = 2 if highlighted else 1
	style.border_width_right = 2 if highlighted else 1
	style.border_width_bottom = 2 if highlighted else 1
	style.border_color = material_color.lightened(0.24) if highlighted else Color(0.26, 0.31, 0.34, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	return style

func _load_material_icon_texture() -> Texture2D:
	return load(MATERIAL_PLACEHOLDER_ICON_PATH) as Texture2D

func _resolve_builder_path_from_state() -> StringName:
	if active_stage_controller == null:
		return StringName()
	var state: Resource = active_stage_controller.get_active_authoring_state()
	return StringName(state.get("builder_path_id")) if state != null else StringName()

func _select_option_by_metadata(option_button: OptionButton, target_metadata: Variant) -> void:
	for item_index in range(option_button.get_item_count()):
		if option_button.get_item_metadata(item_index) == target_metadata:
			option_button.select(item_index)
			return

func _on_authoring_state_changed(_state) -> void:
	_refresh_from_controller()

func _on_new_draft_pressed() -> void:
	if active_stage_controller == null:
		return
	active_stage_controller.start_new_draft("%s V2 Draft" % current_bench_name)

func _on_clear_strokes_pressed() -> void:
	if active_stage_controller == null:
		return
	if active_stage_controller.has_method("clear_pending_material_bodies"):
		active_stage_controller.call("clear_pending_material_bodies")
	else:
		active_stage_controller.call("clear_volume_strokes")

func _on_builder_path_selected(index: int) -> void:
	if is_refreshing_ui or active_stage_controller == null:
		return
	active_stage_controller.set_builder_path_id(StringName(builder_path_option.get_item_metadata(index)))

func _on_builder_component_selected(index: int) -> void:
	if is_refreshing_ui or active_stage_controller == null:
		return
	active_stage_controller.set_builder_component_id(StringName(builder_component_option.get_item_metadata(index)))

func _on_operation_selected(index: int) -> void:
	if is_refreshing_ui or active_stage_controller == null:
		return
	active_stage_controller.set_active_operation_mode(StringName(operation_option.get_item_metadata(index)))

func _on_placement_policy_selected(index: int) -> void:
	if is_refreshing_ui or active_stage_controller == null:
		return
	active_stage_controller.set_placement_policy(StringName(placement_policy_option.get_item_metadata(index)))

func _on_material_palette_pressed(material_id: StringName) -> void:
	if is_refreshing_ui or active_stage_controller == null:
		return
	active_stage_controller.set_active_material_variant_id(material_id)

func _on_primitive_selected(index: int) -> void:
	if is_refreshing_ui or active_stage_controller == null:
		return
	active_stage_controller.set_active_primitive_id(StringName(primitive_option.get_item_metadata(index)))

func _on_radius_decrease_pressed() -> void:
	if active_stage_controller == null:
		return
	active_stage_controller.adjust_brush_radius_steps(-1)

func _on_radius_increase_pressed() -> void:
	if active_stage_controller == null:
		return
	active_stage_controller.adjust_brush_radius_steps(1)

func _on_add_empty_stroke_pressed() -> void:
	if active_stage_controller == null:
		return
	active_stage_controller.append_active_primitive_deposit()

func _on_commit_pending_pressed() -> void:
	if active_stage_controller == null:
		return
	active_stage_controller.commit_pending_material_bodies_as_layer()

func _on_undo_layer_pressed() -> void:
	if active_stage_controller == null:
		return
	active_stage_controller.undo_latest_layer()

func _on_redo_layer_pressed() -> void:
	if active_stage_controller == null:
		return
	active_stage_controller.redo_latest_layer()

func _on_body_stack_selected(index: int) -> void:
	if is_refreshing_ui or active_stage_controller == null:
		return
	active_stage_controller.select_material_body_id(StringName(body_stack_option.get_item_metadata(index)))

func _on_delete_selected_body_pressed() -> void:
	if active_stage_controller == null:
		return
	active_stage_controller.remove_selected_material_body()

func _ensure_workspace_preview() -> void:
	if workspace_preview != null and is_instance_valid(workspace_preview):
		return
	if workspace_subviewport == null:
		return
	workspace_subviewport.own_world_3d = true
	workspace_preview = ForgeV2WorkspacePreviewScript.new()
	workspace_preview.name = "ForgeV2WorkspacePreview"
	workspace_subviewport.add_child(workspace_preview)
	if active_stage_controller != null and workspace_preview.has_method("bind_stage_controller"):
		workspace_preview.call("bind_stage_controller", active_stage_controller)

func _sync_workspace_subviewport_size() -> void:
	if workspace_view_container == null or workspace_subviewport == null:
		return
	var target_size := Vector2i(
		maxi(int(round(workspace_view_container.size.x)), 1),
		maxi(int(round(workspace_view_container.size.y)), 1)
	)
	if workspace_subviewport.size != target_size:
		workspace_subviewport.size = target_size

func _on_workspace_view_gui_input(event: InputEvent) -> void:
	if active_stage_controller == null:
		return
	_ensure_workspace_preview()
	if workspace_preview == null:
		return
	if event is InputEventMouseButton:
		_handle_workspace_mouse_button(event as InputEventMouseButton)
		return
	if event is InputEventMouseMotion:
		_handle_workspace_mouse_motion(event as InputEventMouseMotion)

func _handle_workspace_mouse_button(mouse_button_event: InputEventMouseButton) -> void:
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_VIEW_ZOOM_IN, mouse_button_event):
		workspace_preview.call("zoom_by", -WORKSPACE_ZOOM_STEP)
		workspace_view_container.accept_event()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_VIEW_ZOOM_OUT, mouse_button_event):
		workspace_preview.call("zoom_by", WORKSPACE_ZOOM_STEP)
		workspace_view_container.accept_event()
		return
	var orbit_mouse_button := _get_v2_binding_mouse_button(ForgeV2KeybindingStateScript.ACTION_VIEW_ORBIT)
	var pan_mouse_button := _get_v2_binding_mouse_button(ForgeV2KeybindingStateScript.ACTION_VIEW_PAN)
	var pan_secondary_mouse_button := _get_v2_binding_mouse_button(ForgeV2KeybindingStateScript.ACTION_VIEW_PAN_SECONDARY)
	var paint_mouse_button := _get_v2_binding_mouse_button(ForgeV2KeybindingStateScript.ACTION_PAINT_MATERIAL)
	if (
		mouse_button_event.button_index == orbit_mouse_button
		or mouse_button_event.button_index == pan_mouse_button
		or mouse_button_event.button_index == pan_secondary_mouse_button
	):
		workspace_drag_active = mouse_button_event.pressed
		workspace_drag_pan_mode = (
			_v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_VIEW_PAN, mouse_button_event)
			or _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_VIEW_PAN_SECONDARY, mouse_button_event)
		)
		workspace_view_container.accept_event()
		return
	if mouse_button_event.button_index != paint_mouse_button:
		return
	if mouse_button_event.pressed:
		if _is_v2_spline_line_tool_active():
			_begin_workspace_spline_input(mouse_button_event.position)
		else:
			_begin_workspace_brush_stroke(mouse_button_event.position)
	else:
		if workspace_spline_point_drag_active:
			_finish_workspace_spline_point_drag()
		else:
			_finish_workspace_brush_stroke(mouse_button_event.position)
	workspace_view_container.accept_event()

func _handle_workspace_mouse_motion(motion_event: InputEventMouseMotion) -> void:
	if workspace_spline_point_drag_active:
		_update_workspace_spline_point_drag(motion_event.position)
		workspace_view_container.accept_event()
		return
	if workspace_brush_stroke_active:
		_extend_workspace_brush_stroke(motion_event.position)
		workspace_view_container.accept_event()
		return
	if workspace_drag_active:
		if workspace_drag_pan_mode:
			workspace_preview.call("pan_by", motion_event.relative)
		else:
			workspace_preview.call("orbit_by", motion_event.relative)
		workspace_view_container.accept_event()
		return
	_update_placement_cursor_from_workspace_position(motion_event.position)

func _on_workspace_view_mouse_exited() -> void:
	workspace_drag_active = false
	_finish_workspace_spline_point_drag()
	if workspace_brush_stroke_active:
		_finish_workspace_brush_stroke(Vector2.ZERO, false)
	if active_stage_controller != null and active_stage_controller.has_method("clear_placement_cursor"):
		active_stage_controller.call("clear_placement_cursor")

func _begin_workspace_spline_input(screen_position: Vector2) -> void:
	var nearest_point_index := _find_nearest_spline_point_at_screen(screen_position)
	if nearest_point_index >= 0:
		_begin_workspace_spline_point_drag(nearest_point_index, Vector3.ZERO)
		_update_workspace_spline_point_drag(screen_position)
		return
	var placement_result: Dictionary = _resolve_workspace_local_position(screen_position)
	if not bool(placement_result.get("valid", false)):
		return
	var local_position: Vector3 = placement_result.get("local_position", Vector3.ZERO) as Vector3
	if active_stage_controller != null and active_stage_controller.has_method("append_spline_line_point"):
		active_stage_controller.call("append_spline_line_point", local_position)

func _begin_workspace_spline_point_drag(point_index: int, fallback_local_position: Vector3) -> void:
	if workspace_preview == null or not workspace_preview.has_method("build_camera_facing_drag_plane"):
		return
	var point_origin: Vector3 = _get_spline_point_local_position(point_index, fallback_local_position)
	var drag_plane: Dictionary = workspace_preview.call("build_camera_facing_drag_plane", point_origin) as Dictionary
	if not bool(drag_plane.get("valid", false)):
		return
	workspace_spline_point_drag_active = true
	workspace_spline_drag_point_index = point_index
	workspace_spline_drag_plane_origin_local = drag_plane.get("origin_local", point_origin) as Vector3
	workspace_spline_drag_plane_normal_local = drag_plane.get("normal_local", Vector3.FORWARD) as Vector3
	if active_stage_controller != null and active_stage_controller.has_method("select_spline_line_point"):
		active_stage_controller.call("select_spline_line_point", point_index)

func _update_workspace_spline_point_drag(screen_position: Vector2) -> void:
	if not workspace_spline_point_drag_active:
		return
	if workspace_preview == null or not workspace_preview.has_method("screen_to_workspace_local_on_drag_plane"):
		return
	var drag_result: Dictionary = workspace_preview.call(
		"screen_to_workspace_local_on_drag_plane",
		screen_position,
		workspace_spline_drag_plane_origin_local,
		workspace_spline_drag_plane_normal_local
	) as Dictionary
	if not bool(drag_result.get("valid", false)):
		return
	var local_position: Vector3 = drag_result.get("local_position", Vector3.ZERO) as Vector3
	if active_stage_controller != null and active_stage_controller.has_method("set_spline_line_point"):
		active_stage_controller.call("set_spline_line_point", workspace_spline_drag_point_index, local_position)

func _finish_workspace_spline_point_drag() -> void:
	workspace_spline_point_drag_active = false
	workspace_spline_drag_point_index = -1
	workspace_spline_drag_plane_origin_local = Vector3.ZERO
	workspace_spline_drag_plane_normal_local = Vector3.FORWARD

func _find_nearest_spline_point_at_screen(screen_position: Vector2) -> int:
	if workspace_preview == null or not workspace_preview.has_method("find_nearest_local_point_by_screen"):
		return -1
	var spline_points: PackedVector3Array = _get_spline_points()
	return int(workspace_preview.call(
		"find_nearest_local_point_by_screen",
		spline_points,
		screen_position,
		SPLINE_POINT_SCREEN_PICK_RADIUS_PIXELS
	))

func _get_spline_point_local_position(point_index: int, fallback_local_position: Vector3) -> Vector3:
	var spline_points: PackedVector3Array = _get_spline_points()
	if point_index < 0 or point_index >= spline_points.size():
		return fallback_local_position
	return spline_points[point_index]

func _get_spline_points() -> PackedVector3Array:
	if active_stage_controller == null or not active_stage_controller.has_method("get_status_summary"):
		return PackedVector3Array()
	var summary: Dictionary = active_stage_controller.call("get_status_summary") as Dictionary
	var spline_summary: Dictionary = summary.get("spline_line", {}) as Dictionary
	return spline_summary.get("points", PackedVector3Array())

func _begin_workspace_brush_stroke(screen_position: Vector2) -> void:
	var placement_result: Dictionary = _resolve_workspace_local_position(screen_position)
	if not bool(placement_result.get("valid", false)):
		return
	var local_position: Vector3 = placement_result.get("local_position", Vector3.ZERO) as Vector3
	workspace_brush_stroke_active = true
	if active_stage_controller.has_method("begin_material_body_path"):
		active_stage_controller.call("begin_material_body_path", local_position)
	elif active_stage_controller.has_method("begin_placement_stroke"):
		active_stage_controller.call("begin_placement_stroke", local_position)
	else:
		active_stage_controller.call("append_point_material_body", local_position)

func _extend_workspace_brush_stroke(screen_position: Vector2, force_endpoint: bool = false) -> void:
	if not workspace_brush_stroke_active:
		return
	var placement_result: Dictionary = _resolve_workspace_local_position(screen_position)
	if not bool(placement_result.get("valid", false)):
		if active_stage_controller.has_method("clear_placement_cursor"):
			active_stage_controller.call("clear_placement_cursor")
		return
	var local_position: Vector3 = placement_result.get("local_position", Vector3.ZERO) as Vector3
	if active_stage_controller.has_method("extend_material_body_path"):
		active_stage_controller.call("extend_material_body_path", local_position, force_endpoint)
	elif active_stage_controller.has_method("extend_placement_stroke"):
		active_stage_controller.call("extend_placement_stroke", local_position, force_endpoint)
	elif force_endpoint:
		active_stage_controller.call("append_point_material_body", local_position)

func _finish_workspace_brush_stroke(screen_position: Vector2, use_screen_position: bool = true) -> void:
	if not workspace_brush_stroke_active:
		return
	var placement_result: Dictionary = _resolve_workspace_local_position(screen_position) if use_screen_position else {"valid": false}
	if active_stage_controller.has_method("finish_material_body_path"):
		active_stage_controller.call(
			"finish_material_body_path",
			placement_result.get("local_position", Vector3.ZERO) as Vector3,
			bool(placement_result.get("valid", false))
		)
	elif active_stage_controller.has_method("finish_placement_stroke"):
		active_stage_controller.call(
			"finish_placement_stroke",
			placement_result.get("local_position", Vector3.ZERO) as Vector3,
			bool(placement_result.get("valid", false))
		)
	workspace_brush_stroke_active = false

func _update_placement_cursor_from_workspace_position(screen_position: Vector2) -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("set_placement_cursor_local_position"):
		return
	var placement_result: Dictionary = _resolve_workspace_local_position(screen_position)
	if not bool(placement_result.get("valid", false)):
		active_stage_controller.call("clear_placement_cursor")
		return
	active_stage_controller.call(
		"set_placement_cursor_local_position",
		placement_result.get("local_position", Vector3.ZERO) as Vector3,
		true
	)

func _resolve_workspace_local_position(screen_position: Vector2) -> Dictionary:
	_ensure_workspace_preview()
	if workspace_preview == null or not workspace_preview.has_method("screen_to_workspace_local"):
		return {"valid": false}
	return workspace_preview.call("screen_to_workspace_local", screen_position) as Dictionary
