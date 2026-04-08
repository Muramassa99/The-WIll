extends CanvasLayer
class_name CraftingBenchUI

signal closed

const PAGE_OWNED: StringName = &"owned"
const PAGE_ALL: StringName = &"all"
const PAGE_WEAPON: StringName = &"weapon"

const TOOL_PLACE: StringName = &"place"
const TOOL_ERASE: StringName = &"erase"
const TOOL_PICK: StringName = &"pick"

const PLANE_XY: StringName = &"xy"
const PLANE_ZX: StringName = &"zx"
const PLANE_ZY: StringName = &"zy"
const WORKSPACE_VIEW_FREE: StringName = &"free"
const WORKSPACE_VIEW_PLANE: StringName = &"plane"

const FREE_VIEW_DRAG_NONE := 0
const FREE_VIEW_DRAG_PAN := 1
const FREE_VIEW_DRAG_ORBIT := 2

const MENU_VIEW_FIT := 100
const MENU_VIEW_TOGGLE_BOUNDS := 101
const MENU_VIEW_TOGGLE_SLICE := 102
const MENU_GEOMETRY_TOOL_PLACE := 200
const MENU_GEOMETRY_TOOL_ERASE := 201
const MENU_GEOMETRY_PLANE_XY := 202
const MENU_GEOMETRY_PLANE_ZX := 203
const MENU_GEOMETRY_PLANE_ZY := 204
const MENU_WORKFLOW_BAKE := 300
const MENU_WORKFLOW_RESET := 301
const MENU_WORKFLOW_CLOSE := 302

const DEFAULT_FORGE_VIEW_TUNING_RESOURCE: ForgeViewTuningDef = preload("res://core/defs/forge/forge_view_tuning_default.tres")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")

@export_category("Responsive Layout")
@export var compact_width_breakpoint: int = 1360
@export var compact_height_breakpoint: int = 720
@export_range(0.0, 0.12, 0.005) var wide_outer_margin_ratio: float = 0.02
@export_range(0.0, 0.12, 0.005) var compact_outer_margin_ratio: float = 0.015
@export var minimum_outer_margin_px: int = 12
@export var maximum_outer_margin_px: int = 36
@export var wide_left_panel_min_width: int = 250
@export var compact_left_panel_min_width: int = 170
@export var wide_right_panel_min_width: int = 360
@export var compact_right_panel_min_width: int = 220
@export var wide_action_button_min_width: int = 140
@export var compact_action_button_min_width: int = 84
@export var wide_action_button_min_height: int = 34
@export var compact_action_button_min_height: int = 30
@export var wide_project_panel_min_height: int = 220
@export var compact_project_panel_min_height: int = 160
@export var wide_project_notes_min_height: int = 84
@export var compact_project_notes_min_height: int = 60
@export var wide_project_list_min_height: int = 120
@export var compact_project_list_min_height: int = 88
@export var wide_inventory_list_min_height: int = 240
@export var compact_inventory_list_min_height: int = 140
@export var wide_description_panel_min_height: int = 190
@export var compact_description_panel_min_height: int = 116
@export var wide_stats_panel_min_height: int = 260
@export var compact_stats_panel_min_height: int = 144
@export var wide_workspace_stage_min_height: int = 620
@export var compact_workspace_stage_min_height: int = 240
@export var wide_workspace_inset_size: Vector2i = Vector2i(360, 240)
@export var compact_workspace_inset_size: Vector2i = Vector2i(240, 160)
@export var wide_workspace_inset_margin_px: int = 14
@export var compact_workspace_inset_margin_px: int = 10
@export var wide_plane_main_viewport_min_size: Vector2i = Vector2i(780, 620)
@export var compact_plane_main_viewport_min_size: Vector2i = Vector2i(260, 180)
@export var wide_plane_inset_viewport_min_size: Vector2i = Vector2i(220, 140)
@export var compact_plane_inset_viewport_min_size: Vector2i = Vector2i(180, 118)
@export var wide_free_main_viewport_min_size: Vector2i = Vector2i(900, 620)
@export var compact_free_main_viewport_min_size: Vector2i = Vector2i(260, 180)
@export var wide_free_inset_viewport_min_size: Vector2i = Vector2i(220, 140)
@export var compact_free_inset_viewport_min_size: Vector2i = Vector2i(180, 118)
@export var wide_debug_popup_min_size: Vector2i = Vector2i(540, 420)
@export var compact_debug_popup_min_size: Vector2i = Vector2i(420, 300)
@export var layer_hold_repeat_delay_seconds: float = 0.5
@export var layer_hold_repeat_rate_hz: float = 10.0
@export var edit_panel_refresh_interval_seconds: float = 0.08
@export var wide_panel_separation: int = 12
@export var compact_panel_separation: int = 8

@onready var panel: PanelContainer = $Panel
@onready var main_hbox: HBoxContainer = $Panel/MarginContainer/RootVBox/MainHBox
@onready var left_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel
@onready var center_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel
@onready var right_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainHBox/RightPanel
@onready var project_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel
@onready var workspace_stage: Control = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage
@onready var main_viewport_host: Control = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/MainViewportHost
@onready var inset_viewport_host: Control = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/InsetViewportHost
@onready var plane_view_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/InsetViewportHost/PlaneViewPanel
@onready var free_view_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/MainViewportHost/FreeViewPanel
@onready var title_label: Label = $Panel/MarginContainer/RootVBox/HeaderBox/TitleLabel
@onready var subtitle_label: Label = $Panel/MarginContainer/RootVBox/HeaderBox/SubtitleLabel
@onready var layer_status_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/LayerStatusLabel
@onready var plane_status_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/PlaneStatusLabel
@onready var armed_material_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ArmedMaterialLabel
@onready var capacity_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/CapacityLabel
@onready var capacity_bar: ProgressBar = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/CapacityBar
@onready var project_source_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel/ProjectMargin/ProjectVBox/ProjectSourceLabel
@onready var project_name_edit: LineEdit = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel/ProjectMargin/ProjectVBox/ProjectNameEdit
@onready var project_stow_position_option_button: OptionButton = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel/ProjectMargin/ProjectVBox/ProjectStowPositionOptionButton
@onready var project_grip_style_option_button: OptionButton = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel/ProjectMargin/ProjectVBox/ProjectGripStyleOptionButton
@onready var new_project_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel/ProjectMargin/ProjectVBox/ProjectButtonRow/NewProjectButton
@onready var save_project_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel/ProjectMargin/ProjectVBox/ProjectButtonRow/SaveProjectButton
@onready var duplicate_project_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel/ProjectMargin/ProjectVBox/ProjectButtonRowSecondary/DuplicateProjectButton
@onready var delete_project_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel/ProjectMargin/ProjectVBox/ProjectButtonRowSecondary/DeleteProjectButton
@onready var load_project_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel/ProjectMargin/ProjectVBox/ProjectButtonRowTertiary/LoadProjectButton
@onready var resume_last_project_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel/ProjectMargin/ProjectVBox/ProjectButtonRowTertiary/ResumeLastProjectButton
@onready var project_notes_edit: TextEdit = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel/ProjectMargin/ProjectVBox/ProjectNotesEdit
@onready var project_list: ItemList = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel/ProjectMargin/ProjectVBox/ProjectList
@onready var place_category_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ToolCategoryStrip/PlaceCategoryButton
@onready var erase_category_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ToolCategoryStrip/EraseCategoryButton
@onready var single_tool_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ToolPalette/SingleToolButton
@onready var pick_tool_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ToolPalette/PickToolButton
@onready var xy_plane_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/PlaneSelectorRow/XYPlaneButton
@onready var zx_plane_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/PlaneSelectorRow/ZXPlaneButton
@onready var zy_plane_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/PlaneSelectorRow/ZYPlaneButton
@onready var layer_down_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/LayerStepRow/LayerDownButton
@onready var layer_up_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/LayerStepRow/LayerUpButton
@onready var view_menu_button: MenuButton = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/ActionHostRow/ViewMenuButton
@onready var geometry_menu_button: MenuButton = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/ActionHostRow/GeometryMenuButton
@onready var workflow_menu_button: MenuButton = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/ActionHostRow/WorkflowMenuButton
@onready var flip_view_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/ActionHostRow/FlipViewButton
@onready var debug_info_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/ActionHostRow/DebugInfoButton
@onready var plane_title_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/InsetViewportHost/PlaneViewPanel/PlaneVBox/PlaneTitle
@onready var free_title_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/MainViewportHost/FreeViewPanel/FreeVBox/FreeTitle
@onready var plane_viewport: ForgePlaneViewport = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/InsetViewportHost/PlaneViewPanel/PlaneVBox/PlaneViewport
@onready var free_view_container: SubViewportContainer = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/MainViewportHost/FreeViewPanel/FreeVBox/FreeViewContainer
@onready var free_subviewport: SubViewport = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/MainViewportHost/FreeViewPanel/FreeVBox/FreeViewContainer/FreeSubViewport
@onready var orientation_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/MainViewportHost/FreeViewPanel/FreeVBox/OrientationLabel
@onready var stow_hint_popup: PopupPanel = $StowHintPopup
@onready var stow_hint_label: Label = $StowHintPopup/StowHintMargin/StowHintLabel
@onready var grip_hint_popup: PopupPanel = $GripHintPopup
@onready var grip_hint_label: Label = $GripHintPopup/GripHintMargin/GripHintLabel
@onready var debug_popup: PopupPanel = $DebugPopup
@onready var debug_close_button: Button = $DebugPopup/DebugMargin/DebugVBox/DebugHeaderRow/DebugCloseButton
@onready var status_text: RichTextLabel = $DebugPopup/DebugMargin/DebugVBox/DebugScroll/DebugText
@onready var owned_tab_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/RightPanel/MarginContainer/RightScroll/RightVBox/InventoryPageTabs/OwnedTabButton
@onready var all_tab_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/RightPanel/MarginContainer/RightScroll/RightVBox/InventoryPageTabs/AllTabButton
@onready var weapon_tab_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/RightPanel/MarginContainer/RightScroll/RightVBox/InventoryPageTabs/WeaponTabButton
@onready var search_box: LineEdit = $Panel/MarginContainer/RootVBox/MainHBox/RightPanel/MarginContainer/RightScroll/RightVBox/SearchBox
@onready var inventory_list: ItemList = $Panel/MarginContainer/RootVBox/MainHBox/RightPanel/MarginContainer/RightScroll/RightVBox/InventoryList
@onready var description_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainHBox/RightPanel/MarginContainer/RightScroll/RightVBox/DescriptionPanel
@onready var material_description_text: RichTextLabel = $Panel/MarginContainer/RootVBox/MainHBox/RightPanel/MarginContainer/RightScroll/RightVBox/DescriptionPanel/DescriptionMargin/DescriptionText
@onready var stats_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainHBox/RightPanel/MarginContainer/RightScroll/RightVBox/StatsPanel
@onready var material_stats_text: RichTextLabel = $Panel/MarginContainer/RootVBox/MainHBox/RightPanel/MarginContainer/RightScroll/RightVBox/StatsPanel/StatsMargin/StatsText

@export var forge_view_tuning: ForgeViewTuningDef = DEFAULT_FORGE_VIEW_TUNING_RESOURCE

var active_player: PlayerController3D
var forge_controller: ForgeGridController
var active_plane: StringName = PLANE_XY
var active_layer: int = 20
var active_tool: StringName = TOOL_PLACE
var current_inventory_page: StringName = PAGE_OWNED
var selected_material_variant_id: StringName = &""
var armed_material_variant_id: StringName = &""
var material_catalog: Array[Dictionary] = []
var visible_inventory_entries: Array[Dictionary] = []
var project_catalog: Array[Dictionary] = []
var free_workspace_preview: ForgeWorkspacePreview
var material_runtime_resolver = MaterialRuntimeResolverScript.new()
var free_view_drag_active: bool = false
var free_view_drag_mode: int = FREE_VIEW_DRAG_NONE
var free_view_restore_mouse_position: Vector2 = Vector2.ZERO
var free_view_previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var free_view_paint_active: bool = false
var free_view_paint_has_last_grid: bool = false
var free_view_paint_last_grid_position: Vector3i = Vector3i.ZERO
var show_grid_bounds: bool = true
var show_active_slice: bool = true
var main_workspace_mode: StringName = WORKSPACE_VIEW_FREE
var suppress_active_wip_refresh: bool = false
var cached_material_lookup: Dictionary = {}
var debug_status_dirty: bool = true
var held_layer_direction: int = 0
var held_layer_delay_remaining: float = 0.0
var held_layer_repeat_accumulator: float = 0.0
var layout_refresh_queued: bool = false
var last_layout_compact_mode: bool = false
var last_layout_viewport_size: Vector2 = Vector2.ZERO
var last_debug_text: String = ""
var pending_edit_visual_refresh: bool = false
var pending_edit_panel_refresh: bool = false
var pending_edit_preserve_workspace_view: bool = true
var pending_edit_panel_refresh_elapsed: float = 0.0

func _ready() -> void:
	panel.visible = false
	stow_hint_popup.hide()
	grip_hint_popup.hide()
	free_subviewport.own_world_3d = true
	_configure_action_menus()
	_connect_ui_signals()
	_populate_stow_position_options()
	_populate_grip_style_options()
	_ensure_free_workspace_preview()
	plane_viewport.set_view_tuning(_get_view_tuning())
	_sync_workspace_hosts()
	if not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	if not panel.resized.is_connected(_queue_layout_refresh):
		panel.resized.connect(_queue_layout_refresh)
	_queue_layout_refresh()

func _process(delta: float) -> void:
	if not panel.visible:
		return
	_process_layer_hold_repeat(delta)
	_process_pending_edit_refresh(delta)

func _unhandled_input(event: InputEvent) -> void:
	if free_view_drag_active:
		if event is InputEventMouseMotion:
			_handle_free_view_drag_motion((event as InputEventMouseMotion).relative)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton:
			var drag_button_event: InputEventMouseButton = event
			if drag_button_event.button_index == _get_workspace_orbit_mouse_button() and not drag_button_event.pressed:
				_end_free_view_drag()
				get_viewport().set_input_as_handled()
				return
	if free_view_paint_active and event is InputEventMouseButton:
		var paint_button_event: InputEventMouseButton = event
		if paint_button_event.button_index == MOUSE_BUTTON_LEFT and not paint_button_event.pressed:
			_end_free_view_paint()
	if not panel.visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close_ui()
		get_viewport().set_input_as_handled()
		return
	if _is_action_pressed_if_available(event, &"forge_bake"):
		_bake_active_wip()
		get_viewport().set_input_as_handled()
		return
	if _is_action_pressed_if_available(event, &"forge_reset"):
		_reset_active_wip()
		get_viewport().set_input_as_handled()
		return
	if _is_initial_action_press(event, &"forge_layer_down"):
		_begin_layer_hold(-1)
		_step_layer(-1)
		get_viewport().set_input_as_handled()
		return
	if _is_initial_action_press(event, &"forge_layer_up"):
		_begin_layer_hold(1)
		_step_layer(1)
		get_viewport().set_input_as_handled()
		return
	if _is_action_released_if_available(event, &"forge_layer_down") and held_layer_direction < 0:
		_clear_layer_hold()
		return
	if _is_action_released_if_available(event, &"forge_layer_up") and held_layer_direction > 0:
		_clear_layer_hold()
		return
	if _is_action_pressed_if_available(event, &"forge_plane_xy"):
		_set_active_plane(PLANE_XY)
		get_viewport().set_input_as_handled()
		return
	if _is_action_pressed_if_available(event, &"forge_plane_zx"):
		_set_active_plane(PLANE_ZX)
		get_viewport().set_input_as_handled()
		return
	if _is_action_pressed_if_available(event, &"forge_plane_zy"):
		_set_active_plane(PLANE_ZY)
		get_viewport().set_input_as_handled()

func toggle_for(player: PlayerController3D, controller: ForgeGridController, bench_name: String) -> void:
	if panel.visible:
		close_ui()
		return
	open_for(player, controller, bench_name)

func open_for(player: PlayerController3D, controller: ForgeGridController, bench_name: String) -> void:
	active_player = player
	forge_controller = controller
	_reset_material_lookup_cache()
	debug_status_dirty = true
	_clear_layer_hold()
	title_label.text = "%s Forge Station" % bench_name
	subtitle_label.text = "Author matter on the full forge work area. The right side manages processed material stacks, the center edits one shared WIP, and the left side controls layer, plane, tool, and capacity state."
	panel.visible = true
	_hide_stow_position_hint()
	debug_popup.hide()
	_queue_layout_refresh()
	if active_player != null:
		active_player.set_ui_mode_enabled(true)
	if forge_controller != null:
		if not forge_controller.active_wip_changed.is_connected(_on_active_wip_changed):
			forge_controller.active_wip_changed.connect(_on_active_wip_changed)
		if not forge_controller.active_test_print_changed.is_connected(_on_active_test_print_changed):
			forge_controller.active_test_print_changed.connect(_on_active_test_print_changed)
	var current_wip: CraftedItemWIP = forge_controller.active_wip if forge_controller != null else null
	if current_wip == null:
		current_wip = _restore_preferred_player_project_if_available()
	if current_wip == null:
		current_wip = _ensure_wip_for_editing()
	active_plane = PLANE_XY
	active_layer = _get_default_layer_for_plane(active_plane)
	if current_wip != null and forge_controller != null:
		active_layer = clampi(forge_controller.get_active_layer_index(), 0, _get_max_layer_for_plane(active_plane))
	if active_player != null and forge_controller != null:
		active_player.ensure_forge_inventory_seeded(
			forge_controller.build_default_material_lookup(),
			forge_controller.get_inventory_seed_def(),
			forge_controller.get_debug_inventory_seed_quantity(),
			forge_controller.get_debug_inventory_bonus_quantity()
		)
	_rebuild_workflow_menu()
	_build_material_catalog()
	_refresh_all(false)

func close_ui() -> void:
	if not panel.visible:
		return
	_end_free_view_drag(false)
	_end_free_view_paint()
	_clear_layer_hold()
	_reset_pending_edit_refresh()
	_reset_material_lookup_cache()
	_hide_stow_position_hint()
	debug_popup.hide()
	panel.visible = false
	if active_player != null:
		active_player.set_ui_mode_enabled(false)
	active_player = null
	emit_signal("closed")

func is_open() -> bool:
	return panel.visible

func _connect_ui_signals() -> void:
	place_category_button.pressed.connect(func() -> void: _set_active_tool(TOOL_PLACE))
	erase_category_button.pressed.connect(func() -> void: _set_active_tool(TOOL_ERASE))
	single_tool_button.pressed.connect(func() -> void: _set_active_tool(TOOL_PLACE))
	pick_tool_button.pressed.connect(func() -> void: _set_active_tool(TOOL_PICK))
	xy_plane_button.pressed.connect(func() -> void: _set_active_plane(PLANE_XY))
	zx_plane_button.pressed.connect(func() -> void: _set_active_plane(PLANE_ZX))
	zy_plane_button.pressed.connect(func() -> void: _set_active_plane(PLANE_ZY))
	layer_down_button.pressed.connect(func() -> void: _step_layer(-1))
	layer_up_button.pressed.connect(func() -> void: _step_layer(1))
	owned_tab_button.pressed.connect(func() -> void: _set_inventory_page(PAGE_OWNED))
	all_tab_button.pressed.connect(func() -> void: _set_inventory_page(PAGE_ALL))
	weapon_tab_button.pressed.connect(func() -> void: _set_inventory_page(PAGE_WEAPON))
	new_project_button.pressed.connect(_on_new_project_pressed)
	save_project_button.pressed.connect(_on_save_project_pressed)
	duplicate_project_button.pressed.connect(_on_duplicate_project_pressed)
	delete_project_button.pressed.connect(_on_delete_project_pressed)
	load_project_button.pressed.connect(_on_load_project_pressed)
	resume_last_project_button.pressed.connect(_on_resume_last_project_pressed)
	project_name_edit.text_submitted.connect(_on_project_name_submitted)
	project_name_edit.focus_exited.connect(_on_project_name_focus_exited)
	project_stow_position_option_button.item_selected.connect(_on_project_stow_position_selected)
	var stow_popup: PopupMenu = project_stow_position_option_button.get_popup()
	stow_popup.id_focused.connect(_on_stow_position_popup_id_focused)
	stow_popup.popup_hide.connect(_hide_stow_position_hint)
	project_grip_style_option_button.item_selected.connect(_on_project_grip_style_selected)
	var grip_popup: PopupMenu = project_grip_style_option_button.get_popup()
	grip_popup.id_focused.connect(_on_grip_style_popup_id_focused)
	grip_popup.popup_hide.connect(_hide_grip_style_hint)
	project_notes_edit.focus_exited.connect(_on_project_notes_focus_exited)
	project_list.item_clicked.connect(_on_project_list_item_clicked)
	project_list.item_selected.connect(_on_project_list_item_selected)
	search_box.text_changed.connect(func(_new_text: String) -> void: _refresh_inventory())
	inventory_list.item_clicked.connect(_on_inventory_item_clicked)
	flip_view_button.pressed.connect(_on_flip_view_pressed)
	debug_info_button.pressed.connect(_open_debug_popup)
	debug_close_button.pressed.connect(func() -> void: debug_popup.hide())
	plane_viewport.cell_place_requested.connect(_on_plane_cell_place_requested)
	plane_viewport.cell_remove_requested.connect(_on_plane_cell_remove_requested)
	plane_viewport.cell_pick_requested.connect(_on_plane_cell_pick_requested)
	plane_viewport.stroke_finished.connect(_on_plane_stroke_finished)
	free_view_panel.gui_input.connect(_on_free_view_panel_gui_input)
	free_view_container.gui_input.connect(_on_free_view_gui_input)

func _configure_action_menus() -> void:
	var view_popup: PopupMenu = view_menu_button.get_popup()
	view_popup.add_item("Fit View", MENU_VIEW_FIT)
	view_popup.add_item("Toggle Grid Bounds", MENU_VIEW_TOGGLE_BOUNDS)
	view_popup.add_item("Toggle Active Slice", MENU_VIEW_TOGGLE_SLICE)
	view_popup.id_pressed.connect(_on_action_menu_id_pressed)

	var geometry_popup: PopupMenu = geometry_menu_button.get_popup()
	geometry_popup.add_item("Place Tool", MENU_GEOMETRY_TOOL_PLACE)
	geometry_popup.add_item("Erase Tool", MENU_GEOMETRY_TOOL_ERASE)
	geometry_popup.add_separator()
	geometry_popup.add_item("Plane XY", MENU_GEOMETRY_PLANE_XY)
	geometry_popup.add_item("Plane ZX", MENU_GEOMETRY_PLANE_ZX)
	geometry_popup.add_item("Plane ZY", MENU_GEOMETRY_PLANE_ZY)
	geometry_popup.id_pressed.connect(_on_action_menu_id_pressed)

	var workflow_popup: PopupMenu = workflow_menu_button.get_popup()
	workflow_popup.id_pressed.connect(_on_action_menu_id_pressed)

func _populate_stow_position_options() -> void:
	project_stow_position_option_button.clear()
	var stow_popup: PopupMenu = project_stow_position_option_button.get_popup()
	for popup_item_index: int in range(stow_popup.get_item_count()):
		stow_popup.remove_item(0)
	for stow_index: int in range(CraftedItemWIP.get_stow_position_modes().size()):
		var stow_mode: StringName = CraftedItemWIP.get_stow_position_modes()[stow_index]
		project_stow_position_option_button.add_item(CraftedItemWIP.get_stow_position_label(stow_mode), stow_index)
		project_stow_position_option_button.set_item_metadata(stow_index, stow_mode)
		stow_popup.set_item_tooltip(stow_index, CraftedItemWIP.get_stow_position_note(stow_mode))
	_select_project_stow_position(CraftedItemWIP.STOW_SHOULDER_HANGING)

func _populate_grip_style_options() -> void:
	project_grip_style_option_button.clear()
	var grip_popup: PopupMenu = project_grip_style_option_button.get_popup()
	for popup_item_index: int in range(grip_popup.get_item_count()):
		grip_popup.remove_item(0)
	for grip_index: int in range(CraftedItemWIP.get_grip_style_modes().size()):
		var grip_mode: StringName = CraftedItemWIP.get_grip_style_modes()[grip_index]
		project_grip_style_option_button.add_item(CraftedItemWIP.get_grip_style_label(grip_mode), grip_index)
		project_grip_style_option_button.set_item_metadata(grip_index, grip_mode)
		grip_popup.set_item_tooltip(grip_index, CraftedItemWIP.get_grip_style_note(grip_mode))
	_select_project_grip_style(CraftedItemWIP.GRIP_NORMAL)

func _select_project_stow_position(stow_mode: StringName) -> void:
	var normalized_mode: StringName = CraftedItemWIP.normalize_stow_position_mode(stow_mode)
	for stow_index: int in range(project_stow_position_option_button.get_item_count()):
		if project_stow_position_option_button.get_item_metadata(stow_index) == normalized_mode:
			project_stow_position_option_button.select(stow_index)
			return
	if project_stow_position_option_button.get_item_count() > 0:
		project_stow_position_option_button.select(0)

func _get_selected_project_stow_position() -> StringName:
	var selected_index: int = project_stow_position_option_button.selected
	if selected_index < 0 or selected_index >= project_stow_position_option_button.get_item_count():
		return CraftedItemWIP.STOW_SHOULDER_HANGING
	return CraftedItemWIP.normalize_stow_position_mode(project_stow_position_option_button.get_item_metadata(selected_index))

func _select_project_grip_style(grip_mode: StringName, current_wip: CraftedItemWIP = null) -> void:
	var normalized_mode: StringName = CraftedItemWIP.normalize_grip_style_mode(grip_mode)
	if current_wip != null:
		normalized_mode = CraftedItemWIP.resolve_supported_grip_style(
			normalized_mode,
			current_wip.forge_intent,
			current_wip.equipment_context
		)
	for grip_index: int in range(project_grip_style_option_button.get_item_count()):
		if project_grip_style_option_button.get_item_metadata(grip_index) == normalized_mode:
			project_grip_style_option_button.select(grip_index)
			return
	if project_grip_style_option_button.get_item_count() > 0:
		project_grip_style_option_button.select(0)

func _get_selected_project_grip_style() -> StringName:
	var selected_index: int = project_grip_style_option_button.selected
	if selected_index < 0 or selected_index >= project_grip_style_option_button.get_item_count():
		return CraftedItemWIP.GRIP_NORMAL
	return CraftedItemWIP.normalize_grip_style_mode(project_grip_style_option_button.get_item_metadata(selected_index))

func _refresh_grip_style_option_availability(current_wip: CraftedItemWIP) -> void:
	var grip_popup: PopupMenu = project_grip_style_option_button.get_popup()
	var reverse_supported: bool = current_wip != null and CraftedItemWIP.supports_reverse_grip_for_context(current_wip.forge_intent, current_wip.equipment_context)
	for grip_index: int in range(project_grip_style_option_button.get_item_count()):
		var grip_mode: StringName = project_grip_style_option_button.get_item_metadata(grip_index)
		var is_disabled: bool = grip_mode == CraftedItemWIP.GRIP_REVERSE and not reverse_supported
		grip_popup.set_item_disabled(grip_index, is_disabled)

func _show_stow_position_hint(stow_mode: StringName) -> void:
	var tooltip_text: String = CraftedItemWIP.get_stow_position_note(stow_mode)
	if tooltip_text.is_empty():
		_hide_stow_position_hint()
		return
	stow_hint_label.text = tooltip_text
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var popup_size: Vector2 = Vector2(260.0, 80.0)
	var popup_position: Vector2 = mouse_position + Vector2(24.0, -8.0)
	if popup_position.x + popup_size.x > viewport_size.x - 8.0:
		popup_position.x = mouse_position.x - popup_size.x - 24.0
	if popup_position.y + popup_size.y > viewport_size.y - 8.0:
		popup_position.y = viewport_size.y - popup_size.y - 8.0
	popup_position.x = clampf(popup_position.x, 8.0, maxf(8.0, viewport_size.x - popup_size.x - 8.0))
	popup_position.y = clampf(popup_position.y, 8.0, maxf(8.0, viewport_size.y - popup_size.y - 8.0))
	stow_hint_popup.position = popup_position
	stow_hint_popup.size = popup_size
	stow_hint_popup.popup()

func _hide_stow_position_hint() -> void:
	if stow_hint_popup.visible:
		stow_hint_popup.hide()

func _show_grip_style_hint(grip_mode: StringName) -> void:
	var tooltip_text: String = CraftedItemWIP.get_grip_style_note(grip_mode)
	if tooltip_text.is_empty():
		_hide_grip_style_hint()
		return
	grip_hint_label.text = tooltip_text
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var popup_size: Vector2 = Vector2(300.0, 96.0)
	var popup_position: Vector2 = mouse_position + Vector2(24.0, -8.0)
	if popup_position.x + popup_size.x > viewport_size.x - 8.0:
		popup_position.x = mouse_position.x - popup_size.x - 24.0
	if popup_position.y + popup_size.y > viewport_size.y - 8.0:
		popup_position.y = viewport_size.y - popup_size.y - 8.0
	popup_position.x = clampf(popup_position.x, 8.0, maxf(8.0, viewport_size.x - popup_size.x - 8.0))
	popup_position.y = clampf(popup_position.y, 8.0, maxf(8.0, viewport_size.y - popup_size.y - 8.0))
	grip_hint_popup.position = popup_position
	grip_hint_popup.size = popup_size
	grip_hint_popup.popup()

func _hide_grip_style_hint() -> void:
	if grip_hint_popup.visible:
		grip_hint_popup.hide()

func _ensure_free_workspace_preview() -> void:
	if is_instance_valid(free_workspace_preview):
		return
	free_workspace_preview = ForgeWorkspacePreview.new()
	free_workspace_preview.name = "ForgeWorkspacePreview"
	free_workspace_preview.set_view_tuning(_get_view_tuning())
	free_subviewport.add_child(free_workspace_preview)

func _build_material_catalog() -> void:
	material_catalog.clear()
	if forge_controller == null:
		return
	var material_lookup: Dictionary = _get_material_lookup()
	var inventory_state: PlayerForgeInventoryState = _get_player_forge_inventory_state()
	var material_ids: Array[StringName] = _collect_material_catalog_ids(inventory_state)
	for material_id: StringName in material_ids:
		var material_entry: Variant = _resolve_material_entry(material_id, material_lookup)
		var base_material: BaseMaterialDef = material_runtime_resolver.resolve_base_material_for_material_id(material_id, material_lookup)
		if base_material == null:
			continue
		var quantity: int = inventory_state.get_quantity(material_id) if inventory_state != null else 0
		material_catalog.append({
			"material_id": material_id,
			"material_entry": material_entry,
			"base_material": base_material,
			"quantity": quantity,
			"display_name": _resolve_material_display_name(base_material, material_entry),
		})
	_reconcile_material_selection_state()

func _refresh_all(preserve_workspace_view: bool = true) -> void:
	_reset_pending_edit_refresh()
	_rebuild_workflow_menu()
	_refresh_project_panel()
	_build_material_catalog()
	_refresh_inventory()
	_refresh_material_panels()
	_refresh_plane_and_preview(preserve_workspace_view)
	_refresh_left_panel()
	_refresh_status_text()
	_queue_layout_refresh()

func _refresh_after_edit(preserve_workspace_view: bool = true) -> void:
	_queue_edit_refresh(preserve_workspace_view)

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
	var compact_mode: bool = viewport_size.x <= float(compact_width_breakpoint) or viewport_size.y <= float(compact_height_breakpoint)
	last_layout_compact_mode = compact_mode
	last_layout_viewport_size = viewport_size
	var smaller_axis: int = mini(int(round(viewport_size.x)), int(round(viewport_size.y)))
	var margin_ratio: float = compact_outer_margin_ratio if compact_mode else wide_outer_margin_ratio
	var resolved_margin: float = float(clampi(int(round(float(smaller_axis) * margin_ratio)), minimum_outer_margin_px, maximum_outer_margin_px))
	panel.offset_left = resolved_margin
	panel.offset_top = resolved_margin
	panel.offset_right = -resolved_margin
	panel.offset_bottom = -resolved_margin

	main_hbox.add_theme_constant_override("separation", compact_panel_separation if compact_mode else wide_panel_separation)

	left_panel.custom_minimum_size.x = compact_left_panel_min_width if compact_mode else wide_left_panel_min_width
	right_panel.custom_minimum_size.x = compact_right_panel_min_width if compact_mode else wide_right_panel_min_width
	workspace_stage.custom_minimum_size.y = compact_workspace_stage_min_height if compact_mode else wide_workspace_stage_min_height
	_sync_workspace_hosts()
	_apply_workspace_layout(compact_mode)

	project_panel.custom_minimum_size.y = compact_project_panel_min_height if compact_mode else wide_project_panel_min_height
	project_notes_edit.custom_minimum_size.y = compact_project_notes_min_height if compact_mode else wide_project_notes_min_height
	project_list.custom_minimum_size.y = compact_project_list_min_height if compact_mode else wide_project_list_min_height
	inventory_list.custom_minimum_size.y = compact_inventory_list_min_height if compact_mode else wide_inventory_list_min_height
	description_panel.custom_minimum_size.y = compact_description_panel_min_height if compact_mode else wide_description_panel_min_height
	stats_panel.custom_minimum_size.y = compact_stats_panel_min_height if compact_mode else wide_stats_panel_min_height

	var resolved_action_button_width: int = compact_action_button_min_width if compact_mode else wide_action_button_min_width
	var resolved_action_button_height: int = compact_action_button_min_height if compact_mode else wide_action_button_min_height
	for button: BaseButton in _get_action_buttons():
		button.custom_minimum_size = Vector2(resolved_action_button_width, resolved_action_button_height)
	(debug_popup.get_node("DebugMargin/DebugVBox") as Control).custom_minimum_size = Vector2(compact_debug_popup_min_size if compact_mode else wide_debug_popup_min_size)

func _get_action_buttons() -> Array[BaseButton]:
	return [
		view_menu_button,
		geometry_menu_button,
		workflow_menu_button,
		flip_view_button,
		debug_info_button,
	]

func _sync_workspace_hosts() -> void:
	var primary_panel: Control = free_view_panel if main_workspace_mode == WORKSPACE_VIEW_FREE else plane_view_panel
	var inset_panel: Control = plane_view_panel if main_workspace_mode == WORKSPACE_VIEW_FREE else free_view_panel
	if primary_panel.get_parent() != main_viewport_host:
		primary_panel.reparent(main_viewport_host)
	if inset_panel.get_parent() != inset_viewport_host:
		inset_panel.reparent(inset_viewport_host)
	_prepare_workspace_panel(primary_panel)
	_prepare_workspace_panel(inset_panel)
	free_title_label.text = "Free 3D Workspace" if main_workspace_mode == WORKSPACE_VIEW_FREE else "3D Inset View"
	plane_title_label.text = "2D Layer Map" if main_workspace_mode == WORKSPACE_VIEW_PLANE else "2D Layer Minimap"
	flip_view_button.text = "2D Main" if main_workspace_mode == WORKSPACE_VIEW_FREE else "3D Main"

func _prepare_workspace_panel(panel_node: Control) -> void:
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

func _apply_workspace_layout(compact_mode: bool) -> void:
	var inset_size: Vector2 = Vector2(compact_workspace_inset_size if compact_mode else wide_workspace_inset_size)
	var inset_margin: float = float(compact_workspace_inset_margin_px if compact_mode else wide_workspace_inset_margin_px)
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

	var plane_main_size: Vector2 = Vector2(compact_plane_main_viewport_min_size if compact_mode else wide_plane_main_viewport_min_size)
	var plane_inset_size: Vector2 = Vector2(compact_plane_inset_viewport_min_size if compact_mode else wide_plane_inset_viewport_min_size)
	var free_main_size: Vector2 = Vector2(compact_free_main_viewport_min_size if compact_mode else wide_free_main_viewport_min_size)
	var free_inset_size: Vector2 = Vector2(compact_free_inset_viewport_min_size if compact_mode else wide_free_inset_viewport_min_size)
	plane_viewport.custom_minimum_size = plane_main_size if main_workspace_mode == WORKSPACE_VIEW_PLANE else plane_inset_size
	free_view_container.custom_minimum_size = free_main_size if main_workspace_mode == WORKSPACE_VIEW_FREE else free_inset_size
	free_view_panel.custom_minimum_size = Vector2.ZERO
	plane_view_panel.custom_minimum_size = Vector2.ZERO
	call_deferred("_sync_free_subviewport_size")

func _sync_free_subviewport_size() -> void:
	var target_size: Vector2i = Vector2i(
		maxi(int(round(free_view_container.size.x)), 1),
		maxi(int(round(free_view_container.size.y)), 1)
	)
	if free_subviewport.size != target_size:
		free_subviewport.size = target_size

func _reset_material_lookup_cache() -> void:
	cached_material_lookup.clear()

func _get_material_lookup() -> Dictionary:
	if forge_controller == null:
		return {}
	if cached_material_lookup.is_empty():
		cached_material_lookup = forge_controller.build_default_material_lookup()
	return cached_material_lookup

func _refresh_inventory() -> void:
	visible_inventory_entries.clear()
	inventory_list.clear()
	var search_text: String = search_box.text.strip_edges().to_lower()
	for entry: Dictionary in material_catalog:
		var quantity: int = int(entry.get("quantity", 0))
		var display_name: String = String(entry.get("display_name", ""))
		var base_material: BaseMaterialDef = entry.get("base_material") as BaseMaterialDef
		if current_inventory_page == PAGE_OWNED and quantity <= 0:
			continue
		if current_inventory_page == PAGE_WEAPON and not _supports_weapon_context(base_material):
			continue
		if not search_text.is_empty():
			var haystack: String = "%s %s" % [display_name.to_lower(), String(entry.get("material_id", &"")).to_lower()]
			if not haystack.contains(search_text):
				continue
		visible_inventory_entries.append(entry)

	for entry: Dictionary in visible_inventory_entries:
		var quantity: int = int(entry.get("quantity", 0))
		var display_name: String = String(entry.get("display_name", ""))
		var material_id: StringName = entry.get("material_id", &"")
		var status_suffix: String = " x%d" % quantity if quantity > 0 else " (0)"
		var item_index: int = inventory_list.add_item(display_name + status_suffix)
		inventory_list.set_item_custom_fg_color(item_index, _get_view_tuning().ui_inventory_owned_color if quantity > 0 else _get_view_tuning().ui_inventory_empty_color)
		inventory_list.set_item_metadata(item_index, material_id)
		if material_id == selected_material_variant_id:
			inventory_list.select(item_index)

	_apply_tab_button_state(owned_tab_button, current_inventory_page == PAGE_OWNED)
	_apply_tab_button_state(all_tab_button, current_inventory_page == PAGE_ALL)
	_apply_tab_button_state(weapon_tab_button, current_inventory_page == PAGE_WEAPON)

func _collect_material_catalog_ids(inventory_state: PlayerForgeInventoryState) -> Array[StringName]:
	var ordered_material_ids: Array[StringName] = []
	if forge_controller != null:
		ordered_material_ids = forge_controller.get_material_catalog_ids()
	var extra_material_ids: Array[StringName] = []
	if inventory_state == null:
		return ordered_material_ids
	for stack: ForgeMaterialStack in inventory_state.material_stacks:
		if stack == null or stack.material_variant_id == StringName() or stack.quantity <= 0:
			continue
		if ordered_material_ids.has(stack.material_variant_id) or extra_material_ids.has(stack.material_variant_id):
			continue
		extra_material_ids.append(stack.material_variant_id)
	extra_material_ids.sort()
	ordered_material_ids.append_array(extra_material_ids)
	return ordered_material_ids

func _resolve_material_entry(material_id: StringName, material_lookup: Dictionary) -> Variant:
	var material_entry: Variant = material_lookup.get(material_id)
	if material_entry != null:
		return material_entry
	return material_runtime_resolver.resolve_material_variant_for_material_id(material_id, material_lookup)

func _refresh_material_panels() -> void:
	var entry: Dictionary = _get_material_entry(selected_material_variant_id)
	if entry.is_empty():
		material_description_text.text = "Select a material entry to inspect it."
		material_stats_text.text = ""
		return
	var base_material: BaseMaterialDef = entry.get("base_material") as BaseMaterialDef
	var material_variant: MaterialVariantDef = entry.get("material_entry") as MaterialVariantDef
	var quantity: int = int(entry.get("quantity", 0))
	var lines: PackedStringArray = []
	lines.append("[b]%s[/b]" % String(entry.get("display_name", "Unknown Material")))
	lines.append("Material id: %s" % String(entry.get("material_id", &"")))
	lines.append("Owned quantity: %d" % quantity)
	lines.append("Family: %s" % String(base_material.material_family if base_material != null else &"unknown"))
	if material_variant != null:
		lines.append("Quality: %s" % _format_tier_display_name(material_variant.tier_id))
	lines.append("")
	lines.append("Processed forge material for the weapon station.")
	lines.append("Readable even when quantity is zero; placeable only when owned.")
	if base_material != null:
		lines.append("Good at: %s" % _describe_material_strengths(base_material))
		lines.append("Tradeoffs: %s" % _describe_material_tradeoffs(base_material))
		lines.append("Source note: processed from world drops through Forge material conversion.")
	material_description_text.text = "\n".join(lines)

	var stat_lines: PackedStringArray = []
	if base_material != null:
		if material_variant != null:
			stat_lines.append("[b]Resolved Variant Stats[/b]")
			stat_lines.append("tier = %s" % _format_tier_display_name(material_variant.tier_id))
			stat_lines.append("resolved_density_per_cell = %.3f" % material_variant.resolved_density_per_cell)
			stat_lines.append("resolved_value_multiplier = %.3f" % material_variant.resolved_value_score)
			stat_lines.append("resolved_processing_output_count = %d" % material_variant.resolved_processing_output_count)
			stat_lines.append("")
			if not material_variant.variant_stats.is_empty():
				stat_lines.append("[b]Resolved Material Stat Lines[/b]")
				for stat_line: StatLine in material_variant.variant_stats:
					if stat_line == null:
						continue
					stat_lines.append(_format_stat_line(stat_line))
				stat_lines.append("")
			if not material_variant.resolved_capability_bias_lines.is_empty():
				stat_lines.append("[b]Resolved Capability Bias Lines[/b]")
				for stat_line: StatLine in material_variant.resolved_capability_bias_lines:
					if stat_line == null:
						continue
					stat_lines.append(_format_stat_line(stat_line))
				stat_lines.append("")
			if not material_variant.resolved_skill_family_bias_lines.is_empty():
				stat_lines.append("[b]Resolved Skill Family Bias Lines[/b]")
				for stat_line: StatLine in material_variant.resolved_skill_family_bias_lines:
					if stat_line == null:
						continue
					stat_lines.append(_format_stat_line(stat_line))
				stat_lines.append("")
			if not material_variant.resolved_elemental_affinity_lines.is_empty():
				stat_lines.append("[b]Resolved Elemental Affinity Lines[/b]")
				for stat_line: StatLine in material_variant.resolved_elemental_affinity_lines:
					if stat_line == null:
						continue
					stat_lines.append(_format_stat_line(stat_line))
				stat_lines.append("")
			if not material_variant.resolved_equipment_context_bias_lines.is_empty():
				stat_lines.append("[b]Resolved Equipment Context Bias Lines[/b]")
				for stat_line: StatLine in material_variant.resolved_equipment_context_bias_lines:
					if stat_line == null:
						continue
					stat_lines.append(_format_stat_line(stat_line))
				stat_lines.append("")
		stat_lines.append("[b]Base Physical Truth[/b]")
		stat_lines.append("density_per_cell = %.3f" % base_material.density_per_cell)
		stat_lines.append("hardness = %.3f" % base_material.hardness)
		stat_lines.append("toughness = %.3f" % base_material.toughness)
		stat_lines.append("elasticity = %.3f" % base_material.elasticity)
		stat_lines.append("")
		stat_lines.append("[b]Base Support Flags[/b]")
		stat_lines.append("anchor=%s edge=%s blunt=%s guard=%s plate=%s" % [
			_format_bool(base_material.can_be_anchor_material),
			_format_bool(base_material.can_be_beveled_edge),
			_format_bool(base_material.can_be_blunt_surface),
			_format_bool(base_material.can_be_guard_surface),
			_format_bool(base_material.can_be_plate_surface)
		])
		stat_lines.append("joint=%s bow_limb=%s bow_string=%s projectile=%s" % [
			_format_bool(base_material.can_be_joint_support or base_material.can_be_joint_membrane),
			_format_bool(base_material.can_be_bow_limb),
			_format_bool(base_material.can_be_bow_string),
			_format_bool(base_material.can_be_projectile_support)
		])
	material_stats_text.text = "\n".join(stat_lines)

func _refresh_plane_and_preview(preserve_workspace_view: bool = true) -> void:
	_refresh_workspace_visuals(preserve_workspace_view, true)

func _refresh_workspace_visuals(preserve_workspace_view: bool = true, force_full_sync: bool = false) -> void:
	var current_wip: CraftedItemWIP = _ensure_wip_for_editing()
	if forge_controller == null:
		return
	var material_lookup: Dictionary = _get_material_lookup()
	if force_full_sync or plane_viewport.grid_size != forge_controller.grid_size:
		plane_viewport.set_grid_size(forge_controller.grid_size)
	plane_viewport.set_active_plane(active_plane)
	plane_viewport.set_active_layer(active_layer)
	plane_viewport.set_active_wip(current_wip)
	plane_viewport.set_material_lookup(material_lookup)
	if force_full_sync:
		plane_viewport.set_view_tuning(_get_view_tuning())
	_ensure_free_workspace_preview()
	if force_full_sync:
		free_workspace_preview.set_view_tuning(_get_view_tuning())
		free_workspace_preview.configure(forge_controller.grid_size, forge_controller.get_cell_world_size_meters(), preserve_workspace_view)
	free_workspace_preview.set_active_slice(active_plane, active_layer)
	free_workspace_preview.set_material_lookup(material_lookup)
	free_workspace_preview.sync_from_wip(current_wip)
	free_workspace_preview.grid_bounds_instance.visible = show_grid_bounds
	free_workspace_preview.active_plane_instance.visible = show_active_slice
	orientation_label.text = "%s\nPlane %s / Layer %d" % [
		"3D Workspace" if main_workspace_mode == WORKSPACE_VIEW_FREE else "3D Inset",
		String(active_plane).to_upper(),
		active_layer,
	]

func _queue_edit_refresh(preserve_workspace_view: bool = true) -> void:
	if pending_edit_visual_refresh:
		pending_edit_preserve_workspace_view = pending_edit_preserve_workspace_view and preserve_workspace_view
	else:
		pending_edit_preserve_workspace_view = preserve_workspace_view
	pending_edit_visual_refresh = true
	pending_edit_panel_refresh = true
	debug_status_dirty = true

func _process_pending_edit_refresh(delta: float) -> void:
	if pending_edit_visual_refresh:
		_refresh_workspace_visuals(pending_edit_preserve_workspace_view, false)
		pending_edit_visual_refresh = false
		pending_edit_preserve_workspace_view = true
	if not pending_edit_panel_refresh:
		return
	pending_edit_panel_refresh_elapsed += maxf(delta, 0.0)
	if pending_edit_panel_refresh_elapsed < maxf(edit_panel_refresh_interval_seconds, 0.0):
		return
	_flush_pending_edit_panels()

func _flush_pending_edit_refresh(force: bool = false) -> void:
	if pending_edit_visual_refresh:
		_refresh_workspace_visuals(pending_edit_preserve_workspace_view, false)
		pending_edit_visual_refresh = false
		pending_edit_preserve_workspace_view = true
	if force:
		_flush_pending_edit_panels()

func _flush_pending_edit_panels() -> void:
	if not pending_edit_panel_refresh:
		return
	_build_material_catalog()
	_refresh_inventory()
	_refresh_material_panels()
	_refresh_left_panel()
	pending_edit_panel_refresh = false
	pending_edit_panel_refresh_elapsed = 0.0

func _reset_pending_edit_refresh() -> void:
	pending_edit_visual_refresh = false
	pending_edit_panel_refresh = false
	pending_edit_preserve_workspace_view = true
	pending_edit_panel_refresh_elapsed = 0.0

func _refresh_left_panel() -> void:
	if forge_controller == null:
		return
	layer_status_label.text = "Active layer: %d / %d" % [active_layer, _get_max_layer_for_plane(active_plane)]
	plane_status_label.text = "Plane: %s" % String(active_plane).to_upper()
	armed_material_label.text = "Armed material: %s" % _get_armed_material_display_name()
	var current_wip: CraftedItemWIP = _ensure_wip_for_editing()
	var used_cells: int = _count_cells(current_wip)
	var max_fill_cells: int = forge_controller.get_max_fill_cells()
	var fill_ratio: float = float(used_cells) / maxf(float(max_fill_cells), 1.0)
	capacity_label.text = "Capacity: %d / %d cells (%.1f%% of allowed fill)" % [used_cells, max_fill_cells, fill_ratio * 100.0]
	capacity_bar.max_value = 1.0
	capacity_bar.value = fill_ratio
	_apply_button_state(place_category_button, active_tool == TOOL_PLACE)
	_apply_button_state(erase_category_button, active_tool == TOOL_ERASE)
	_apply_button_state(single_tool_button, active_tool == TOOL_PLACE)
	_apply_button_state(pick_tool_button, active_tool == TOOL_PICK)
	_apply_button_state(xy_plane_button, active_plane == PLANE_XY)
	_apply_button_state(zx_plane_button, active_plane == PLANE_ZX)
	_apply_button_state(zy_plane_button, active_plane == PLANE_ZY)

func _refresh_status_text() -> void:
	if forge_controller == null:
		last_debug_text = "Forge controller missing."
		status_text.text = last_debug_text
		debug_status_dirty = false
		return
	var current_wip: CraftedItemWIP = _ensure_wip_for_editing()
	var lines: PackedStringArray = []
	lines.append("[b]Forge Workstation State[/b]")
	if current_wip == null:
		lines.append("No active WIP loaded.")
		last_debug_text = "\n".join(lines)
		status_text.text = last_debug_text
		debug_status_dirty = false
		return
	lines.append("WIP id: %s" % String(current_wip.wip_id))
	lines.append("Project: %s" % _get_active_project_display_name(current_wip))
	if not current_wip.forge_project_notes.strip_edges().is_empty():
		lines.append("Forge notes: %s" % current_wip.forge_project_notes.strip_edges())
	lines.append("Final item name: not assigned here")
	lines.append("Grid: %d x %d x %d" % [forge_controller.grid_size.x, forge_controller.grid_size.y, forge_controller.grid_size.z])
	lines.append("Cell scale: %.3fm" % forge_controller.get_cell_world_size_meters())
	lines.append("Plane / layer: %s / %d" % [String(active_plane).to_upper(), active_layer])
	lines.append("Tool: %s" % String(active_tool))
	lines.append("Selected material: %s" % _get_selected_material_display_name())
	lines.append("Armed material: %s" % _get_armed_material_display_name())
	lines.append("")

	var profile: BakedProfile = forge_controller.get_active_baked_profile()
	var material_lookup: Dictionary = _get_material_lookup()
	var cells: Array[CellAtom] = _collect_wip_cells(current_wip)
	var segments: Array[SegmentAtom] = forge_controller.forge_service.build_segments(cells, material_lookup)
	segments = forge_controller.forge_service.classify_joint_segments(segments, material_lookup)
	var joint_data: Dictionary = forge_controller.forge_service.build_joint_data(segments, material_lookup)
	var bow_data: Dictionary = forge_controller.forge_service.build_bow_data(segments, material_lookup, current_wip.forge_intent, current_wip.equipment_context)
	lines.append("Segments: %d" % segments.size())
	lines.append("Joint valid: %s" % _format_bool(bool(joint_data.get("joint_chain_valid", false))))
	lines.append("Bow valid: %s" % _format_bool(bool(bow_data.get("bow_valid", false))))
	if profile == null:
		lines.append("No baked profile yet. Use Workflow -> Bake WIP or press Enter.")
	else:
		lines.append("Validation: %s" % _format_validation(profile))
		lines.append("Primary grip valid: %s" % _format_bool(profile.primary_grip_valid))
		lines.append("Primary grip span: %d" % profile.primary_grip_span_length_voxels)
		lines.append("Primary grip contact: %s" % str(profile.primary_grip_contact_position))
		lines.append("Total mass: %.3f" % profile.total_mass)
		lines.append("Balance score: %.3f" % profile.balance_score)
		lines.append("Flex score: %.3f" % profile.flex_score)
		lines.append("Launch score: %.3f" % profile.launch_score)
	if forge_controller.active_test_print != null:
		lines.append("Test print id: %s" % String(forge_controller.active_test_print.test_id))
	last_debug_text = "\n".join(lines)
	status_text.text = last_debug_text
	debug_status_dirty = false

func _set_inventory_page(page_id: StringName) -> void:
	current_inventory_page = page_id
	_refresh_inventory()

func _set_active_tool(tool_id: StringName) -> void:
	active_tool = tool_id
	_refresh_left_panel()

func _set_active_plane(plane_id: StringName) -> void:
	active_plane = plane_id
	active_layer = clampi(active_layer, 0, _get_max_layer_for_plane(active_plane))
	if forge_controller != null:
		active_layer = _get_default_layer_for_plane(active_plane)
	_refresh_plane_and_preview()
	_refresh_left_panel()
	_refresh_status_text()

func _step_layer(delta: int) -> void:
	active_layer = clampi(active_layer + delta, 0, _get_max_layer_for_plane(active_plane))
	if forge_controller != null and active_plane == PLANE_XY:
		forge_controller.set_active_layer_index(active_layer)
	_refresh_plane_and_preview()
	_refresh_left_panel()
	_refresh_status_text()

func _on_inventory_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if index < 0 or index >= visible_inventory_entries.size():
		return
	var entry: Dictionary = visible_inventory_entries[index]
	var material_id: StringName = entry.get("material_id", &"")
	var quantity: int = int(entry.get("quantity", 0))
	if material_id == selected_material_variant_id:
		if quantity > 0:
			armed_material_variant_id = StringName() if armed_material_variant_id == material_id else material_id
	else:
		selected_material_variant_id = material_id
		armed_material_variant_id = material_id if quantity > 0 else StringName()
	_refresh_inventory()
	_refresh_material_panels()
	_refresh_left_panel()
	_refresh_status_text()

func _on_flip_view_pressed() -> void:
	main_workspace_mode = WORKSPACE_VIEW_PLANE if main_workspace_mode == WORKSPACE_VIEW_FREE else WORKSPACE_VIEW_FREE
	_sync_workspace_hosts()
	_refresh_plane_and_preview()
	_queue_layout_refresh()

func _open_debug_popup() -> void:
	if not panel.visible:
		return
	_flush_pending_edit_refresh(true)
	if debug_status_dirty or status_text.text.strip_edges().is_empty():
		_refresh_status_text()
	var popup_size: Vector2i = compact_debug_popup_min_size if last_layout_compact_mode else wide_debug_popup_min_size
	debug_popup.popup_centered(popup_size)

func _on_plane_cell_place_requested(grid_position: Vector3i) -> void:
	if active_tool == TOOL_PICK:
		_pick_material_from_grid(grid_position)
		return
	if active_tool == TOOL_ERASE:
		_remove_cell(grid_position)
		return
	_place_material_cell(grid_position)

func _on_plane_cell_remove_requested(grid_position: Vector3i) -> void:
	_remove_cell(grid_position)

func _on_plane_cell_pick_requested(grid_position: Vector3i) -> void:
	_pick_material_from_grid(grid_position)

func _on_plane_stroke_finished() -> void:
	_flush_pending_edit_refresh(true)

func _on_free_view_panel_gui_input(event: InputEvent) -> void:
	if forge_controller == null or not is_instance_valid(free_workspace_preview):
		return
	if event is not InputEventMouseButton:
		return
	var mouse_button: InputEventMouseButton = event
	if not mouse_button.pressed:
		return
	if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
		free_workspace_preview.zoom_by(-_get_view_tuning().workspace_zoom_step)
		return
	if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		free_workspace_preview.zoom_by(_get_view_tuning().workspace_zoom_step)
		return

func _on_free_view_gui_input(event: InputEvent) -> void:
	if forge_controller == null or not is_instance_valid(free_workspace_preview):
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			free_workspace_preview.zoom_by(-_get_view_tuning().workspace_zoom_step)
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			free_workspace_preview.zoom_by(_get_view_tuning().workspace_zoom_step)
			return
		if mouse_button.button_index == _get_workspace_orbit_mouse_button():
			if mouse_button.pressed:
				_begin_free_view_drag()
			else:
				_end_free_view_drag()
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			_end_free_view_paint()
			return
		if not mouse_button.pressed:
			return
		if mouse_button.ctrl_pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
			var pick_grid_position: Variant = free_workspace_preview.screen_to_grid(mouse_button.position)
			if pick_grid_position != null:
				_pick_material_from_grid(pick_grid_position)
			_end_free_view_paint()
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if active_tool == TOOL_PICK:
				var pick_tool_grid_position: Variant = free_workspace_preview.screen_to_grid(mouse_button.position)
				if pick_tool_grid_position != null:
					_pick_material_from_grid(pick_tool_grid_position)
				_end_free_view_paint()
			else:
				_begin_free_view_paint()
				_paint_free_view_at_screen_position(mouse_button.position)
			return
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		if free_view_drag_active:
			_handle_free_view_drag_motion(motion_event.relative)
			return
		if free_view_paint_active:
			_paint_free_view_at_screen_position(motion_event.position)

func _on_action_menu_id_pressed(action_id: int) -> void:
	match action_id:
		MENU_VIEW_FIT:
			if is_instance_valid(free_workspace_preview):
				free_workspace_preview.fit_view()
		MENU_VIEW_TOGGLE_BOUNDS:
			show_grid_bounds = not show_grid_bounds
			_refresh_plane_and_preview()
		MENU_VIEW_TOGGLE_SLICE:
			show_active_slice = not show_active_slice
			_refresh_plane_and_preview()
		MENU_GEOMETRY_TOOL_PLACE:
			_set_active_tool(TOOL_PLACE)
		MENU_GEOMETRY_TOOL_ERASE:
			_set_active_tool(TOOL_ERASE)
		MENU_GEOMETRY_PLANE_XY:
			_set_active_plane(PLANE_XY)
		MENU_GEOMETRY_PLANE_ZX:
			_set_active_plane(PLANE_ZX)
		MENU_GEOMETRY_PLANE_ZY:
			_set_active_plane(PLANE_ZY)
		MENU_WORKFLOW_BAKE:
			_bake_active_wip()
		MENU_WORKFLOW_RESET:
			_reset_active_wip()
		MENU_WORKFLOW_CLOSE:
			close_ui()

func _load_sample_preset(sample_preset_id: StringName) -> void:
	if forge_controller == null:
		return
	forge_controller.load_debug_sample_preset(sample_preset_id)
	var current_wip: CraftedItemWIP = forge_controller.active_wip
	if current_wip != null and current_wip.forge_project_name.strip_edges().is_empty():
		current_wip.forge_project_name = _format_sample_preset(sample_preset_id)
	active_layer = _get_default_layer_for_plane(active_plane)
	_refresh_all(false)

func _create_new_blank_project() -> void:
	if forge_controller == null:
		return
	forge_controller.load_new_blank_wip(_build_default_forge_project_name())
	active_layer = _get_default_layer_for_plane(active_plane)
	_refresh_all(false)

func _save_current_wip_to_player_library() -> void:
	var current_wip: CraftedItemWIP = _ensure_wip_for_editing()
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	if current_wip == null or wip_library == null or forge_controller == null:
		return
	_apply_project_metadata_from_editor()
	current_wip = forge_controller.active_wip
	var saved_wip: CraftedItemWIP = wip_library.save_wip(current_wip)
	if saved_wip == null:
		return
	forge_controller.load_player_saved_wip(saved_wip)
	active_layer = _get_default_layer_for_plane(active_plane)
	_refresh_all(false)

func _load_selected_project_from_list() -> void:
	if project_list.get_selected_items().is_empty():
		return
	var selected_index: int = project_list.get_selected_items()[0]
	if selected_index < 0 or selected_index >= project_catalog.size():
		return
	var entry: Dictionary = project_catalog[selected_index]
	var entry_type: StringName = entry.get("entry_type", &"")
	if entry_type == &"sample":
		_load_sample_preset(entry.get("sample_preset_id", &""))
		return
	if entry_type == &"saved":
		_load_saved_wip_by_id(entry.get("saved_wip_id", &""))

func _resume_last_saved_project() -> void:
	var resumed_wip: CraftedItemWIP = _restore_preferred_player_project_if_available(true)
	if resumed_wip != null:
		_refresh_all(false)

func _restore_preferred_player_project_if_available(force_reload: bool = false) -> CraftedItemWIP:
	if forge_controller == null:
		return null
	if not force_reload and forge_controller.active_wip != null:
		return forge_controller.active_wip
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	if wip_library == null:
		return null
	if wip_library.selected_wip_id != StringName():
		var selected_saved_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(wip_library.selected_wip_id)
		if selected_saved_wip != null:
			forge_controller.load_player_saved_wip(selected_saved_wip)
			active_layer = _get_default_layer_for_plane(active_plane)
			return forge_controller.active_wip
	for saved_wip: CraftedItemWIP in wip_library.get_saved_wips():
		if saved_wip == null:
			continue
		wip_library.set_selected_wip_id(saved_wip.wip_id)
		forge_controller.load_player_saved_wip(saved_wip.duplicate(true) as CraftedItemWIP)
		active_layer = _get_default_layer_for_plane(active_plane)
		return forge_controller.active_wip
	return null

func _load_saved_wip_by_id(saved_wip_id: StringName) -> bool:
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	if wip_library == null or forge_controller == null or saved_wip_id == StringName():
		return false
	var saved_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(saved_wip_id)
	if saved_wip == null:
		return false
	wip_library.set_selected_wip_id(saved_wip_id)
	forge_controller.load_player_saved_wip(saved_wip)
	active_layer = _get_default_layer_for_plane(active_plane)
	_refresh_all(false)
	return true

func _refresh_project_action_buttons(current_wip: CraftedItemWIP) -> void:
	load_project_button.disabled = project_list.get_selected_items().is_empty()
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	var has_saved_projects: bool = wip_library != null and wip_library.has_saved_wips()
	var has_selected_saved_project: bool = wip_library != null and wip_library.selected_wip_id != StringName() and wip_library.get_saved_wip(wip_library.selected_wip_id) != null
	resume_last_project_button.disabled = not has_saved_projects and not has_selected_saved_project
	save_project_button.disabled = current_wip == null
	duplicate_project_button.disabled = current_wip == null
	delete_project_button.disabled = not _is_saved_player_project(current_wip)

func _bake_active_wip() -> void:
	if forge_controller == null:
		return
	forge_controller.bake_active_wip_with_defaults()
	_refresh_all()

func _reset_active_wip() -> void:
	if forge_controller == null:
		return
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	if forge_controller.get_active_sample_preset_id() == StringName() and wip_library != null and not wip_library.selected_wip_id.is_empty():
		var saved_wip_clone: CraftedItemWIP = wip_library.get_saved_wip_clone(wip_library.selected_wip_id)
		if saved_wip_clone != null:
			forge_controller.load_player_saved_wip(saved_wip_clone)
			active_layer = _get_default_layer_for_plane(active_plane)
			_refresh_all(false)
			return
	forge_controller.reset_debug_sample_wip()
	active_layer = _get_default_layer_for_plane(active_plane)
	_refresh_all(false)

func _place_material_cell(grid_position: Vector3i) -> void:
	if forge_controller == null or armed_material_variant_id == StringName():
		debug_status_dirty = true
		return
	var current_wip: CraftedItemWIP = _ensure_wip_for_editing()
	if current_wip == null:
		return
	var existing_material_id: StringName = forge_controller.get_material_id_at(grid_position)
	if existing_material_id == armed_material_variant_id:
		return
	if not _try_apply_inventory_swap(existing_material_id, armed_material_variant_id):
		_refresh_after_edit()
		return
	suppress_active_wip_refresh = true
	forge_controller.set_material_at(grid_position, armed_material_variant_id)
	suppress_active_wip_refresh = false
	_refresh_after_edit()

func _remove_cell(grid_position: Vector3i) -> void:
	if forge_controller == null:
		return
	suppress_active_wip_refresh = true
	var removed_material_id: StringName = forge_controller.remove_material_at(grid_position)
	suppress_active_wip_refresh = false
	if removed_material_id == StringName():
		return
	_refund_inventory_material(removed_material_id, 1)
	_refresh_after_edit()

func _begin_free_view_paint() -> void:
	free_view_paint_active = true
	free_view_paint_has_last_grid = false

func _end_free_view_paint() -> void:
	free_view_paint_active = false
	free_view_paint_has_last_grid = false
	_flush_pending_edit_refresh(true)

func _paint_free_view_at_screen_position(screen_position: Vector2) -> void:
	if not free_view_paint_active or forge_controller == null or not is_instance_valid(free_workspace_preview):
		return
	var grid_position_variant: Variant = free_workspace_preview.screen_to_grid(screen_position)
	if grid_position_variant == null:
		return
	var grid_position: Vector3i = grid_position_variant
	if free_view_paint_has_last_grid and grid_position == free_view_paint_last_grid_position:
		return
	free_view_paint_has_last_grid = true
	free_view_paint_last_grid_position = grid_position
	if active_tool == TOOL_ERASE:
		_remove_cell(grid_position)
	else:
		_place_material_cell(grid_position)

func _pick_material_from_grid(grid_position: Vector3i) -> void:
	if forge_controller == null:
		return
	var material_id: StringName = forge_controller.get_material_id_at(grid_position)
	if material_id == StringName():
		return
	selected_material_variant_id = material_id
	var entry: Dictionary = _get_material_entry(selected_material_variant_id)
	armed_material_variant_id = selected_material_variant_id if int(entry.get("quantity", 0)) > 0 else StringName()
	_refresh_inventory()
	_refresh_material_panels()
	_refresh_left_panel()
	_refresh_status_text()

func _ensure_wip_for_editing() -> CraftedItemWIP:
	if forge_controller == null:
		return null
	return forge_controller.ensure_debug_sample_wip()

func _count_cells(wip: CraftedItemWIP) -> int:
	if wip == null:
		return 0
	var total: int = 0
	for layer_atom: LayerAtom in wip.layers:
		if layer_atom == null:
			continue
		total += layer_atom.cells.size()
	return total

func _collect_wip_cells(wip: CraftedItemWIP) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	if wip == null:
		return cells
	for layer_atom: LayerAtom in wip.layers:
		if layer_atom == null:
			continue
		for cell: CellAtom in layer_atom.cells:
			if cell != null:
				cells.append(cell)
	return cells

func _get_material_entry(material_id: StringName) -> Dictionary:
	for entry: Dictionary in material_catalog:
		if entry.get("material_id", &"") == material_id:
			return entry
	return {}

func _get_default_layer_for_plane(plane_id: StringName) -> int:
	if forge_controller == null:
		return 0
	match plane_id:
		PLANE_ZX:
			return forge_controller.grid_size.y >> 1
		PLANE_ZY:
			return forge_controller.grid_size.x >> 1
		_:
			return forge_controller.get_default_active_layer()

func _get_max_layer_for_plane(plane_id: StringName) -> int:
	if forge_controller == null:
		return 0
	match plane_id:
		PLANE_ZX:
			return forge_controller.grid_size.y - 1
		PLANE_ZY:
			return forge_controller.grid_size.x - 1
		_:
			return forge_controller.grid_size.z - 1

func _supports_weapon_context(base_material: BaseMaterialDef) -> bool:
	if base_material == null:
		return false
	for stat_line: StatLine in base_material.equipment_context_bias_lines:
		if stat_line == null:
			continue
		if stat_line.stat_id == &"ctx_weapon":
			return true
	return false

func _resolve_material_display_name(base_material: BaseMaterialDef, material_entry: Variant = null) -> String:
	if base_material == null:
		return "Unknown Material"
	var base_name: String = base_material.display_name
	if base_name.is_empty():
		var raw_text: String = String(base_material.base_material_id).replace("mat_", "").replace("_base", "").replace("_", " ")
		base_name = raw_text.capitalize()
	if material_entry is MaterialVariantDef:
		var material_variant: MaterialVariantDef = material_entry as MaterialVariantDef
		var tier_display_name: String = _format_tier_display_name(material_variant.tier_id)
		if not tier_display_name.is_empty():
			return "%s (%s)" % [base_name, tier_display_name]
	return base_name

func _format_tier_display_name(tier_id: StringName) -> String:
	var tier_id_text: String = String(tier_id)
	if tier_id_text.begins_with("tier_"):
		tier_id_text = tier_id_text.trim_prefix("tier_")
	return tier_id_text.capitalize()

func _resolve_base_material_from_entry(material_entry: Variant, material_lookup: Dictionary) -> BaseMaterialDef:
	if material_entry is BaseMaterialDef:
		return material_entry as BaseMaterialDef
	if material_entry is MaterialVariantDef:
		var material_variant: MaterialVariantDef = material_entry as MaterialVariantDef
		return material_lookup.get(material_variant.base_material_id) as BaseMaterialDef
	return null

func _describe_material_strengths(base_material: BaseMaterialDef) -> String:
	var strengths: PackedStringArray = []
	if base_material.can_be_anchor_material:
		strengths.append("anchor stability")
	if base_material.can_be_bow_limb:
		strengths.append("limb flex")
	if base_material.can_be_bow_string:
		strengths.append("string support")
	if base_material.can_be_beveled_edge:
		strengths.append("edge shaping")
	if base_material.can_be_blunt_surface:
		strengths.append("blunt impact")
	if strengths.is_empty():
		return "general structural use"
	return ", ".join(strengths)

func _describe_material_tradeoffs(base_material: BaseMaterialDef) -> String:
	if base_material == null:
		return "unknown"
	if base_material.elasticity < 0.3:
		return "low flex compared to lighter materials"
	if base_material.hardness < 0.5:
		return "lower hardness than heavy structural metals"
	return "balanced first-slice baseline tradeoffs"

func _format_stat_line(stat_line: StatLine) -> String:
	if stat_line == null:
		return ""
	var suffix: String = ""
	if stat_line.value_kind == StatLine.ValueKind.PCT_ADD:
		suffix = " (pct)"
	return "%s = %.3f%s" % [String(stat_line.stat_id), stat_line.value, suffix]

func _format_bool(value: bool) -> String:
	return "true" if value else "false"

func _format_validation(profile: BakedProfile) -> String:
	if profile == null:
		return "no_profile"
	return "ok" if profile.validation_error.is_empty() else profile.validation_error

func _format_sample_preset(sample_preset_id: StringName) -> String:
	if forge_controller == null:
		return String(sample_preset_id)
	return forge_controller.get_sample_preset_display_name(sample_preset_id)

func _apply_button_state(button: BaseButton, is_active: bool) -> void:
	button.modulate = _get_view_tuning().ui_button_active_color if is_active else _get_view_tuning().ui_button_inactive_color

func _apply_tab_button_state(button: BaseButton, is_active: bool) -> void:
	button.modulate = _get_view_tuning().ui_tab_active_color if is_active else _get_view_tuning().ui_tab_inactive_color

func _get_selected_material_display_name() -> String:
	var entry: Dictionary = _get_material_entry(selected_material_variant_id)
	if entry.is_empty():
		return "none"
	return String(entry.get("display_name", "none"))

func _get_armed_material_display_name() -> String:
	var entry: Dictionary = _get_material_entry(armed_material_variant_id)
	if entry.is_empty():
		return "none"
	return String(entry.get("display_name", "none"))

func _get_active_project_display_name(current_wip: CraftedItemWIP) -> String:
	if current_wip == null:
		return "none"
	if not current_wip.forge_project_name.strip_edges().is_empty():
		return current_wip.forge_project_name.strip_edges()
	if forge_controller != null and forge_controller.get_active_sample_preset_id() != StringName():
		return _format_sample_preset(forge_controller.get_active_sample_preset_id())
	return _format_saved_wip_name(current_wip)

func _get_forge_project_name(current_wip: CraftedItemWIP) -> String:
	if current_wip == null:
		return ""
	if not current_wip.forge_project_name.strip_edges().is_empty():
		return current_wip.forge_project_name.strip_edges()
	if forge_controller != null and forge_controller.get_active_sample_preset_id() != StringName():
		return _format_sample_preset(forge_controller.get_active_sample_preset_id())
	return _build_default_forge_project_name()

func _format_saved_wip_name(saved_wip: CraftedItemWIP) -> String:
	if saved_wip == null:
		return "Unnamed Player WIP"
	if not saved_wip.forge_project_name.strip_edges().is_empty():
		return saved_wip.forge_project_name.strip_edges()
	if not saved_wip.wip_id.is_empty():
		return String(saved_wip.wip_id)
	return "Unnamed Player WIP"

func _get_project_source_text(current_wip: CraftedItemWIP) -> String:
	if current_wip == null:
		return "Current project source: none"
	if forge_controller != null and forge_controller.get_active_sample_preset_id() != StringName():
		return "Current project source: sample preset. Temporary forge label only."
	if _is_saved_player_project(current_wip):
		return "Current project source: saved player forge project. Final item naming happens later."
	return "Current project source: unsaved forge draft. Final item naming happens later."

func _build_default_forge_project_name() -> String:
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	var project_count: int = wip_library.get_saved_wips().size() if wip_library != null else 0
	return "Forge Project %03d" % (project_count + 1)

func _apply_project_metadata_from_editor() -> void:
	var current_wip: CraftedItemWIP = _ensure_wip_for_editing()
	if current_wip == null or forge_controller == null:
		return
	var submitted_name: String = project_name_edit.text.strip_edges()
	current_wip.forge_project_name = submitted_name if not submitted_name.is_empty() else _build_default_forge_project_name()
	current_wip.forge_project_notes = project_notes_edit.text.strip_edges()
	current_wip.stow_position_mode = _get_selected_project_stow_position()
	current_wip.grip_style_mode = CraftedItemWIP.resolve_supported_grip_style(
		_get_selected_project_grip_style(),
		current_wip.forge_intent,
		current_wip.equipment_context
	)
	forge_controller.set_active_wip(current_wip)

func _is_saved_player_project(current_wip: CraftedItemWIP) -> bool:
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	if current_wip == null or wip_library == null:
		return false
	return wip_library.get_saved_wip(current_wip.wip_id) != null

func _duplicate_current_project() -> void:
	var current_wip: CraftedItemWIP = _ensure_wip_for_editing()
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	if current_wip == null or wip_library == null or forge_controller == null:
		return
	_apply_project_metadata_from_editor()
	current_wip = forge_controller.active_wip
	var duplicated_wip: CraftedItemWIP = null
	if _is_saved_player_project(current_wip):
		var refreshed_saved_wip: CraftedItemWIP = wip_library.save_wip(current_wip)
		if refreshed_saved_wip != null:
			duplicated_wip = wip_library.duplicate_saved_wip(refreshed_saved_wip.wip_id)
	else:
		var clone_wip: CraftedItemWIP = current_wip.duplicate(true) as CraftedItemWIP
		clone_wip.wip_id = StringName("draft_%s_copy" % str(Time.get_unix_time_from_system()))
		clone_wip.forge_project_name = "%s Copy" % _get_forge_project_name(current_wip)
		duplicated_wip = wip_library.save_wip(clone_wip)
	if duplicated_wip == null:
		return
	forge_controller.load_player_saved_wip(duplicated_wip)
	active_layer = _get_default_layer_for_plane(active_plane)
	_refresh_all(false)

func _delete_current_project() -> void:
	var current_wip: CraftedItemWIP = _ensure_wip_for_editing()
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	if current_wip == null or wip_library == null or forge_controller == null:
		return
	if not _is_saved_player_project(current_wip):
		return
	var deleted_wip_id: StringName = current_wip.wip_id
	if not wip_library.delete_saved_wip(deleted_wip_id):
		return
	var fallback_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(wip_library.selected_wip_id)
	if fallback_wip != null:
		forge_controller.load_player_saved_wip(fallback_wip)
	else:
		forge_controller.load_new_blank_wip(_build_default_forge_project_name())
	active_layer = _get_default_layer_for_plane(active_plane)
	_refresh_all(false)

func _sync_project_list_selection(current_wip: CraftedItemWIP) -> void:
	project_list.deselect_all()
	if current_wip == null:
		return
	for project_index: int in range(project_catalog.size()):
		var entry: Dictionary = project_catalog[project_index]
		var entry_type: StringName = entry.get("entry_type", &"")
		if entry_type == &"sample":
			if forge_controller != null and entry.get("sample_preset_id", &"") == forge_controller.get_active_sample_preset_id():
				project_list.select(project_index)
				return
		elif entry_type == &"saved":
			if current_wip.wip_id == entry.get("saved_wip_id", &""):
				project_list.select(project_index)
				return

func _on_new_project_pressed() -> void:
	_create_new_blank_project()

func _on_save_project_pressed() -> void:
	_save_current_wip_to_player_library()

func _on_load_project_pressed() -> void:
	_load_selected_project_from_list()

func _on_resume_last_project_pressed() -> void:
	_resume_last_saved_project()

func _on_duplicate_project_pressed() -> void:
	_duplicate_current_project()

func _on_delete_project_pressed() -> void:
	_delete_current_project()

func _on_project_name_submitted(_new_text: String) -> void:
	_apply_project_metadata_from_editor()
	_refresh_project_panel()
	_refresh_status_text()

func _on_project_name_focus_exited() -> void:
	if not panel.visible:
		return
	_apply_project_metadata_from_editor()
	_refresh_project_panel()
	_refresh_status_text()

func _on_project_stow_position_selected(_index: int) -> void:
	if not panel.visible:
		return
	_apply_project_metadata_from_editor()
	_refresh_project_panel()
	_refresh_status_text()

func _on_project_grip_style_selected(_index: int) -> void:
	if not panel.visible:
		return
	_apply_project_metadata_from_editor()
	_refresh_project_panel()
	_refresh_status_text()

func _on_stow_position_popup_id_focused(focused_id: int) -> void:
	if focused_id < 0 or focused_id >= project_stow_position_option_button.get_item_count():
		_hide_stow_position_hint()
		return
	var stow_mode: StringName = project_stow_position_option_button.get_item_metadata(focused_id)
	_show_stow_position_hint(stow_mode)

func _on_grip_style_popup_id_focused(focused_id: int) -> void:
	if focused_id < 0 or focused_id >= project_grip_style_option_button.get_item_count():
		_hide_grip_style_hint()
		return
	var grip_mode: StringName = project_grip_style_option_button.get_item_metadata(focused_id)
	_show_grip_style_hint(grip_mode)

func _on_project_notes_focus_exited() -> void:
	if not panel.visible:
		return
	_apply_project_metadata_from_editor()
	_refresh_project_panel()
	_refresh_status_text()

func _on_project_list_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if index < 0 or index >= project_catalog.size():
		return
	var entry: Dictionary = project_catalog[index]
	var entry_type: StringName = entry.get("entry_type", &"")
	if entry_type == &"sample":
		_load_sample_preset(entry.get("sample_preset_id", &""))
		return
	if entry_type == &"saved":
		_load_saved_wip_by_id(entry.get("saved_wip_id", &""))

func _on_project_list_item_selected(_index: int) -> void:
	_refresh_project_action_buttons(_ensure_wip_for_editing())

func _on_active_wip_changed(_wip: CraftedItemWIP) -> void:
	if not panel.visible or suppress_active_wip_refresh:
		return
	_refresh_all()

func _on_active_test_print_changed(_test_print: TestPrintInstance) -> void:
	if not panel.visible:
		return
	debug_status_dirty = true
	if debug_popup.visible:
		_refresh_status_text()

func _get_player_forge_inventory_state() -> PlayerForgeInventoryState:
	if active_player == null:
		return null
	return active_player.get_forge_inventory_state()

func _get_player_forge_wip_library_state() -> PlayerForgeWipLibraryState:
	if active_player == null:
		return null
	return active_player.get_forge_wip_library_state()

func _rebuild_workflow_menu() -> void:
	var workflow_popup: PopupMenu = workflow_menu_button.get_popup()
	workflow_popup.clear()
	workflow_popup.add_item("Bake WIP", MENU_WORKFLOW_BAKE)
	workflow_popup.add_item("Reset Current WIP", MENU_WORKFLOW_RESET)
	workflow_popup.add_separator()
	workflow_popup.add_item("Close Forge", MENU_WORKFLOW_CLOSE)

func _refresh_project_panel() -> void:
	project_catalog.clear()
	project_list.clear()
	var current_wip: CraftedItemWIP = _ensure_wip_for_editing()
	if current_wip != null:
		current_wip.grip_style_mode = CraftedItemWIP.resolve_supported_grip_style(
			current_wip.grip_style_mode,
			current_wip.forge_intent,
			current_wip.equipment_context
		)
	project_name_edit.editable = current_wip != null
	project_notes_edit.editable = current_wip != null
	project_stow_position_option_button.disabled = current_wip == null
	project_grip_style_option_button.disabled = current_wip == null
	project_name_edit.text = _get_forge_project_name(current_wip)
	project_notes_edit.text = current_wip.forge_project_notes if current_wip != null else ""
	_select_project_stow_position(current_wip.stow_position_mode if current_wip != null else CraftedItemWIP.STOW_SHOULDER_HANGING)
	_refresh_grip_style_option_availability(current_wip)
	_select_project_grip_style(current_wip.grip_style_mode if current_wip != null else CraftedItemWIP.GRIP_NORMAL, current_wip)
	_hide_stow_position_hint()
	_hide_grip_style_hint()
	project_source_label.text = _get_project_source_text(current_wip)
	new_project_button.disabled = forge_controller == null
	if forge_controller != null:
		for sample_preset_id: StringName in forge_controller.get_sample_preset_ids():
			project_catalog.append({
				"entry_type": &"sample",
				"sample_preset_id": sample_preset_id,
				"display_name": "[Sample] %s" % _format_sample_preset(sample_preset_id),
			})
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	var saved_wips: Array[CraftedItemWIP] = []
	if wip_library != null:
		saved_wips = wip_library.get_saved_wips()
	for saved_wip: CraftedItemWIP in saved_wips:
		var saved_description: String = saved_wip.forge_project_notes.strip_edges()
		var stow_summary: String = "Stowed: %s" % CraftedItemWIP.get_stow_position_label(saved_wip.stow_position_mode)
		var grip_summary: String = "Grip: %s" % CraftedItemWIP.get_grip_style_label(saved_wip.grip_style_mode)
		saved_description = "%s\n%s" % [saved_description, stow_summary] if not saved_description.is_empty() else stow_summary
		saved_description = "%s\n%s" % [saved_description, grip_summary] if not saved_description.is_empty() else grip_summary
		project_catalog.append({
			"entry_type": &"saved",
			"saved_wip_id": saved_wip.wip_id,
			"display_name": "[Saved] %s" % _format_saved_wip_name(saved_wip),
			"description": saved_description,
		})
	for entry: Dictionary in project_catalog:
		var item_index: int = project_list.add_item(String(entry.get("display_name", "Project")))
		project_list.set_item_metadata(item_index, entry)
		var description: String = String(entry.get("description", "")).strip_edges()
		if not description.is_empty():
			project_list.set_item_tooltip(item_index, description)
	_sync_project_list_selection(current_wip)
	_refresh_project_action_buttons(current_wip)

func _try_apply_inventory_swap(refund_material_id: StringName, consume_material_id: StringName) -> bool:
	if consume_material_id == StringName():
		return true
	var inventory_state: PlayerForgeInventoryState = _get_player_forge_inventory_state()
	if inventory_state == null:
		return false
	if refund_material_id != StringName() and refund_material_id != consume_material_id:
		inventory_state.add_quantity(refund_material_id, 1)
	if inventory_state.try_consume(consume_material_id, 1):
		return true
	if refund_material_id != StringName() and refund_material_id != consume_material_id:
		inventory_state.try_consume(refund_material_id, 1)
	return false

func _refund_inventory_material(material_id: StringName, amount: int) -> void:
	if material_id == StringName() or amount <= 0:
		return
	var inventory_state: PlayerForgeInventoryState = _get_player_forge_inventory_state()
	if inventory_state == null:
		return
	inventory_state.add_quantity(material_id, amount)

func _reconcile_material_selection_state() -> void:
	if material_catalog.is_empty():
		selected_material_variant_id = StringName()
		armed_material_variant_id = StringName()
		return
	var selected_entry: Dictionary = _get_material_entry(selected_material_variant_id)
	if selected_entry.is_empty():
		selected_material_variant_id = material_catalog[0].get("material_id", &"")
		selected_entry = _get_material_entry(selected_material_variant_id)
	if int(selected_entry.get("quantity", 0)) <= 0 and armed_material_variant_id == selected_material_variant_id:
		armed_material_variant_id = StringName()
	if armed_material_variant_id != StringName() and int(_get_material_entry(armed_material_variant_id).get("quantity", 0)) <= 0:
		armed_material_variant_id = StringName()
	if armed_material_variant_id == StringName() and int(selected_entry.get("quantity", 0)) > 0:
		armed_material_variant_id = selected_material_variant_id

func _begin_free_view_drag() -> void:
	_end_free_view_paint()
	free_view_drag_active = true
	free_view_drag_mode = _resolve_free_view_drag_mode()
	free_view_restore_mouse_position = get_viewport().get_mouse_position()
	free_view_previous_mouse_mode = Input.get_mouse_mode()
	if _get_view_tuning().workspace_capture_mouse_during_drag:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _end_free_view_drag(restore_mouse_position: bool = true) -> void:
	if not free_view_drag_active and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	free_view_drag_active = false
	free_view_drag_mode = FREE_VIEW_DRAG_NONE
	var previous_mouse_mode: Input.MouseMode = free_view_previous_mouse_mode
	if _get_view_tuning().workspace_capture_mouse_during_drag and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(previous_mouse_mode)
		if restore_mouse_position:
			get_viewport().warp_mouse(free_view_restore_mouse_position)
	else:
		Input.set_mouse_mode(previous_mouse_mode)

func _handle_free_view_drag_motion(relative: Vector2) -> void:
	if not free_view_drag_active or not is_instance_valid(free_workspace_preview):
		return
	free_view_drag_mode = _resolve_free_view_drag_mode()
	if free_view_drag_mode == FREE_VIEW_DRAG_PAN:
		free_workspace_preview.pan_by(relative)
	else:
		free_workspace_preview.orbit_by(relative)

func _resolve_free_view_drag_mode() -> int:
	return FREE_VIEW_DRAG_PAN if Input.is_key_pressed(_get_view_tuning().workspace_pan_modifier_keycode) else FREE_VIEW_DRAG_ORBIT

func _get_workspace_orbit_mouse_button() -> MouseButton:
	return _get_view_tuning().workspace_orbit_mouse_button

func _is_action_pressed_if_available(event: InputEvent, action_name: StringName) -> bool:
	return InputMap.has_action(action_name) and event.is_action_pressed(action_name)

func _is_initial_action_press(event: InputEvent, action_name: StringName) -> bool:
	if not _is_action_pressed_if_available(event, action_name):
		return false
	if event is InputEventKey and (event as InputEventKey).echo:
		return false
	return true

func _is_action_released_if_available(event: InputEvent, action_name: StringName) -> bool:
	return InputMap.has_action(action_name) and event.is_action_released(action_name)

func _begin_layer_hold(direction: int) -> void:
	held_layer_direction = 1 if direction > 0 else -1 if direction < 0 else 0
	held_layer_delay_remaining = maxf(layer_hold_repeat_delay_seconds, 0.0)
	held_layer_repeat_accumulator = 0.0

func _clear_layer_hold() -> void:
	held_layer_direction = 0
	held_layer_delay_remaining = 0.0
	held_layer_repeat_accumulator = 0.0

func _process_layer_hold_repeat(delta: float) -> void:
	if held_layer_direction == 0:
		return
	var action_name: StringName = &"forge_layer_up" if held_layer_direction > 0 else &"forge_layer_down"
	if not InputMap.has_action(action_name) or not Input.is_action_pressed(action_name):
		_clear_layer_hold()
		return
	if held_layer_delay_remaining > 0.0:
		held_layer_delay_remaining -= delta
		if held_layer_delay_remaining > 0.0:
			return
		delta = -held_layer_delay_remaining
		held_layer_delay_remaining = 0.0
	var repeat_interval: float = 1.0 / maxf(layer_hold_repeat_rate_hz, 0.001)
	held_layer_repeat_accumulator += delta
	var repeat_step_count: int = int(floor((held_layer_repeat_accumulator + 0.0001) / repeat_interval))
	if repeat_step_count <= 0:
		return
	held_layer_repeat_accumulator -= repeat_interval * float(repeat_step_count)
	for _repeat_index in range(repeat_step_count):
		_step_layer(held_layer_direction)

func _get_view_tuning() -> ForgeViewTuningDef:
	return forge_view_tuning if forge_view_tuning != null else DEFAULT_FORGE_VIEW_TUNING_RESOURCE
