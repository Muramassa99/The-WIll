extends CanvasLayer
class_name CraftingBenchUI

signal closed

const PAGE_OWNED: StringName = &"owned"
const PAGE_ALL: StringName = &"all"
const PAGE_WEAPON: StringName = &"weapon"

const TOOL_PLACE: StringName = &"place"
const TOOL_ERASE: StringName = &"erase"
const TOOL_PICK: StringName = &"pick"
const DEFAULT_STAGE2_POINTER_TOOL_MIN_RADIUS_METERS: float = 0.0125
const DEFAULT_STAGE2_POINTER_TOOL_MAX_RADIUS_METERS: float = 0.375
const DEFAULT_STAGE2_POINTER_TOOL_RADIUS_STEP_METERS: float = 0.0125

const PLANE_XY: StringName = &"xy"
const PLANE_ZX: StringName = &"zx"
const PLANE_ZY: StringName = &"zy"
const WORKSPACE_VIEW_FREE: StringName = &"free"
const WORKSPACE_VIEW_PLANE: StringName = &"plane"

const MENU_VIEW_FIT := 100
const MENU_VIEW_TOGGLE_BOUNDS := 101
const MENU_VIEW_TOGGLE_SLICE := 102
const MENU_GEOMETRY_TOOL_PLACE := 200
const MENU_GEOMETRY_TOOL_ERASE := 201
const MENU_GEOMETRY_TOOL_PICK := 202
const MENU_GEOMETRY_TOOL_FILLET := 208
const MENU_GEOMETRY_TOOL_CHAMFER := 209
const MENU_GEOMETRY_TOOL_SURFACE_FACE_FILLET := 210
const MENU_GEOMETRY_TOOL_SURFACE_FACE_CHAMFER := 211
const MENU_GEOMETRY_TOOL_SURFACE_EDGE_FILLET := 212
const MENU_GEOMETRY_TOOL_SURFACE_EDGE_CHAMFER := 213
const MENU_GEOMETRY_SELECTION_APPLY := 214
const MENU_GEOMETRY_SELECTION_CLEAR := 215
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_EDGE_FILLET := 216
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_EDGE_CHAMFER := 217
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_REGION_FILLET := 218
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_REGION_CHAMFER := 219
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_LOOP_FILLET := 220
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_LOOP_CHAMFER := 221
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_REGION_RESTORE := 222
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_LOOP_RESTORE := 223
const MENU_GEOMETRY_TOOL_SURFACE_FACE_RESTORE := 224
const MENU_GEOMETRY_TOOL_SURFACE_EDGE_RESTORE := 225
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_EDGE_RESTORE := 226
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_BAND_FILLET := 227
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_BAND_CHAMFER := 228
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_BAND_RESTORE := 229
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_CLUSTER_FILLET := 230
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_CLUSTER_CHAMFER := 231
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_CLUSTER_RESTORE := 232
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_BRIDGE_FILLET := 233
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_BRIDGE_CHAMFER := 234
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_BRIDGE_RESTORE := 235
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_CONTOUR_FILLET := 236
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_CONTOUR_CHAMFER := 237
const MENU_GEOMETRY_TOOL_SURFACE_FEATURE_CONTOUR_RESTORE := 238
const MENU_GEOMETRY_TOOL_RECTANGLE_PLACE := 239
const MENU_GEOMETRY_TOOL_RECTANGLE_ERASE := 240
const MENU_GEOMETRY_TOOL_CIRCLE_PLACE := 241
const MENU_GEOMETRY_TOOL_CIRCLE_ERASE := 242
const MENU_GEOMETRY_TOOL_OVAL_PLACE := 243
const MENU_GEOMETRY_TOOL_OVAL_ERASE := 244
const MENU_GEOMETRY_TOOL_TRIANGLE_PLACE := 245
const MENU_GEOMETRY_TOOL_TRIANGLE_ERASE := 246
const MENU_GEOMETRY_SHAPE_ROTATE_LEFT := 247
const MENU_GEOMETRY_SHAPE_ROTATE_RIGHT := 248
const MENU_GEOMETRY_PLANE_XY := 203
const MENU_GEOMETRY_PLANE_ZX := 204
const MENU_GEOMETRY_PLANE_ZY := 205
const MENU_GEOMETRY_LAYER_DOWN := 206
const MENU_GEOMETRY_LAYER_UP := 207
const MENU_WORKFLOW_BAKE := 300
const MENU_WORKFLOW_RESET := 301
const MENU_WORKFLOW_CLOSE := 302
const MENU_WORKFLOW_STAGE2_INITIALIZE := 303
const MENU_WORKFLOW_STAGE2_TOGGLE_MODE := 304
const MENU_PROJECT_MANAGER := 400
const MENU_PROJECT_SAVE := 401
const MENU_PROJECT_NEW := 402
const MENU_PROJECT_LOAD_SELECTED := 403
const MENU_PROJECT_RESUME_LAST := 404
const MENU_PROJECT_DUPLICATE := 405
const MENU_PROJECT_DELETE := 406
const MENU_PROJECT_SHOW_PATHS := 407

const DEFAULT_FORGE_VIEW_TUNING_RESOURCE: ForgeViewTuningDef = preload("res://core/defs/forge/forge_view_tuning_default.tres")
const ForgeMaterialCatalogPresenterScript = preload("res://runtime/forge/forge_material_catalog_presenter.gd")
const ForgeWorkspaceEditFlowScript = preload("res://runtime/forge/forge_workspace_edit_flow.gd")
const ForgeWorkspaceEditActionPresenterScript = preload("res://runtime/forge/forge_workspace_edit_action_presenter.gd")
const ForgeWorkspaceInteractionPresenterScript = preload("res://runtime/forge/forge_workspace_interaction_presenter.gd")
const ForgeWorkspaceLayoutPresenterScript = preload("res://runtime/forge/forge_workspace_layout_presenter.gd")
const ForgeWorkspacePlanePresenterScript = preload("res://runtime/forge/forge_workspace_plane_presenter.gd")
const ForgeProjectActionPresenterScript = preload("res://runtime/forge/forge_project_action_presenter.gd")
const ForgeProjectPanelPresenterScript = preload("res://runtime/forge/forge_project_panel_presenter.gd")
const ForgeWorkspacePresentationScript = preload("res://runtime/forge/forge_workspace_presentation.gd")
const ForgeBenchPanelPresenterScript = preload("res://runtime/forge/forge_bench_panel_presenter.gd")
const ForgeBenchRefreshPresenterScript = preload("res://runtime/forge/forge_bench_refresh_presenter.gd")
const ForgeBenchDebugPresenterScript = preload("res://runtime/forge/forge_bench_debug_presenter.gd")
const ForgeBenchSessionPresenterScript = preload("res://runtime/forge/forge_bench_session_presenter.gd")
const ForgeBenchMaterialStatePresenterScript = preload("res://runtime/forge/forge_bench_material_state_presenter.gd")
const ForgeBenchMenuPresenterScript = preload("res://runtime/forge/forge_bench_menu_presenter.gd")
const ForgeBenchStartMenuPresenterScript = preload("res://runtime/forge/forge_bench_start_menu_presenter.gd")
const ForgeStage2BrushPresenterScript = preload("res://runtime/forge/forge_stage2_brush_presenter.gd")
const ForgeStage2SelectionPresenterScript = preload("res://runtime/forge/forge_stage2_selection_presenter.gd")
const ForgeWorkspaceShapeToolPresenterScript = preload("res://runtime/forge/forge_workspace_shape_tool_presenter.gd")

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
@onready var tool_overlay_host: Control = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/ToolOverlayHost
@onready var main_viewport_host: Control = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/MainViewportHost
@onready var inset_viewport_host: Control = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/InsetViewportHost
@onready var plane_view_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/InsetViewportHost/PlaneViewPanel
@onready var free_view_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/MainViewportHost/FreeViewPanel
@onready var title_label: Label = $Panel/MarginContainer/RootVBox/HeaderBox/TitleLabel
@onready var subtitle_label: Label = $Panel/MarginContainer/RootVBox/HeaderBox/SubtitleLabel
@onready var start_menu_panel: PanelContainer = $Panel/MarginContainer/RootVBox/StartMenuPanel
@onready var start_menu_continue_last_button: Button = $Panel/MarginContainer/RootVBox/StartMenuPanel/StartMenuMargin/StartMenuVBox/StartMenuButtonVBox/ContinueLastButton
@onready var start_menu_project_list_button: Button = $Panel/MarginContainer/RootVBox/StartMenuPanel/StartMenuMargin/StartMenuVBox/StartMenuButtonVBox/ProjectListButton
@onready var start_menu_new_melee_button: Button = $Panel/MarginContainer/RootVBox/StartMenuPanel/StartMenuMargin/StartMenuVBox/StartMenuButtonVBox/NewMeleeWeaponButton
@onready var start_menu_new_ranged_physical_button: Button = $Panel/MarginContainer/RootVBox/StartMenuPanel/StartMenuMargin/StartMenuVBox/StartMenuButtonVBox/NewRangedPhysicalWeaponButton
@onready var start_menu_new_shield_button: Button = $Panel/MarginContainer/RootVBox/StartMenuPanel/StartMenuMargin/StartMenuVBox/StartMenuButtonVBox/NewShieldButton
@onready var start_menu_new_magic_button: Button = $Panel/MarginContainer/RootVBox/StartMenuPanel/StartMenuMargin/StartMenuVBox/StartMenuButtonVBox/NewMagicWeaponButton
@onready var layer_status_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/LayerStatusLabel
@onready var plane_status_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/PlaneStatusLabel
@onready var armed_material_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ArmedMaterialLabel
@onready var capacity_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/CapacityLabel
@onready var capacity_bar: ProgressBar = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/CapacityBar
@onready var project_source_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel/ProjectMargin/ProjectVBox/ProjectSourceLabel
@onready var builder_component_tabs: HBoxContainer = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel/ProjectMargin/ProjectVBox/BuilderComponentTabs
@onready var builder_component_bow_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel/ProjectMargin/ProjectVBox/BuilderComponentTabs/BuilderComponentBowButton
@onready var builder_component_quiver_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/LeftPanel/MarginContainer/LeftScroll/LeftVBox/ProjectPanel/ProjectMargin/ProjectVBox/BuilderComponentTabs/BuilderComponentQuiverButton
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
@onready var project_menu_button: MenuButton = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/ActionHostRow/ProjectMenuButton
@onready var status_menu_button: MenuButton = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/ActionHostRow/StatusMenuButton
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
@onready var axis_indicator_control = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/MainViewportHost/AxisIndicatorPanel/AxisIndicatorMargin/AxisIndicatorVBox/AxisIndicatorCenter/AxisIndicatorControl
@onready var tool_overlay_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/ToolOverlayHost/ToolOverlayPanel
@onready var draw_tool_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/ToolOverlayHost/ToolOverlayPanel/ToolOverlayMargin/ToolOverlayVBox/DrawToolButton
@onready var erase_tool_button: Button = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/ToolOverlayHost/ToolOverlayPanel/ToolOverlayMargin/ToolOverlayVBox/EraseToolButton
@onready var tool_state_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/ToolOverlayHost/ToolOverlayPanel/ToolOverlayMargin/ToolOverlayVBox/ToolStateLabel
@onready var active_tool_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/ToolOverlayHost/ToolOverlayPanel/ToolOverlayMargin/ToolOverlayVBox/ActiveToolLabel
@onready var shape_size_status_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/ToolOverlayHost/ToolOverlayPanel/ToolOverlayMargin/ToolOverlayVBox/ShapeSizeStatusLabel
@onready var rotation_status_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/ToolOverlayHost/ToolOverlayPanel/ToolOverlayMargin/ToolOverlayVBox/RotationStatusLabel
@onready var material_status_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/ToolOverlayHost/ToolOverlayPanel/ToolOverlayMargin/ToolOverlayVBox/MaterialStatusLabel
@onready var radius_status_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/ToolOverlayHost/ToolOverlayPanel/ToolOverlayMargin/ToolOverlayVBox/RadiusStatusLabel
@onready var orientation_label: Label = $Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/MainViewportHost/FreeViewPanel/FreeVBox/OrientationLabel
@onready var stow_hint_popup: PopupPanel = $StowHintPopup
@onready var stow_hint_label: Label = $StowHintPopup/StowHintMargin/StowHintLabel
@onready var grip_hint_popup: PopupPanel = $GripHintPopup
@onready var grip_hint_label: Label = $GripHintPopup/GripHintMargin/GripHintLabel
@onready var debug_popup: PopupPanel = $DebugPopup
@onready var project_manager_popup: PopupPanel = $ProjectManagerPopup
@onready var project_manager_host: VBoxContainer = $ProjectManagerPopup/ProjectManagerMargin/ProjectManagerHost
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
var material_catalog_presenter = ForgeMaterialCatalogPresenterScript.new()
var workspace_layout_presenter = ForgeWorkspaceLayoutPresenterScript.new()
var workspace_plane_presenter = ForgeWorkspacePlanePresenterScript.new()
var project_panel_presenter = ForgeProjectPanelPresenterScript.new()
var workspace_presentation = ForgeWorkspacePresentationScript.new()
var bench_panel_presenter = ForgeBenchPanelPresenterScript.new()
var bench_refresh_presenter = ForgeBenchRefreshPresenterScript.new()
var bench_debug_presenter = ForgeBenchDebugPresenterScript.new()
var bench_session_presenter = ForgeBenchSessionPresenterScript.new()
var bench_material_state_presenter = ForgeBenchMaterialStatePresenterScript.new()
var bench_menu_presenter = ForgeBenchMenuPresenterScript.new()
var bench_start_menu_presenter = ForgeBenchStartMenuPresenterScript.new()
var show_grid_bounds: bool = true
var show_active_slice: bool = true
var main_workspace_mode: StringName = WORKSPACE_VIEW_FREE
var suppress_active_wip_refresh: bool = false
var cached_material_lookup: Dictionary = {}
var debug_status_dirty: bool = true
var layout_refresh_queued: bool = false
var last_layout_compact_mode: bool = false
var last_layout_viewport_size: Vector2 = Vector2.ZERO
var last_debug_text: String = ""
var last_left_panel_state: Dictionary = {}
var start_menu_visible: bool = false
var current_bench_name: String = ""
var workspace_edit_flow = ForgeWorkspaceEditFlowScript.new()
var workspace_edit_action_presenter = ForgeWorkspaceEditActionPresenterScript.new()
var workspace_interaction_presenter = ForgeWorkspaceInteractionPresenterScript.new()
var project_action_presenter = ForgeProjectActionPresenterScript.new()
var stage2_brush_presenter = ForgeStage2BrushPresenterScript.new()
var stage2_selection_presenter = ForgeStage2SelectionPresenterScript.new()
var workspace_shape_tool_presenter = ForgeWorkspaceShapeToolPresenterScript.new()
var stage2_refinement_mode_active: bool = false
var stage1_active_tool_before_stage2_refinement: StringName = TOOL_PLACE
var structural_shape_drag_active: bool = false
var structural_shape_drag_anchor_grid_position: Vector3i = Vector3i.ZERO
var structural_shape_drag_current_grid_position: Vector3i = Vector3i.ZERO
var structural_shape_preview_grid_positions: Array[Vector3i] = []
var structural_shape_preview_dirty: bool = false
var structural_shape_last_committed_layer: int = -1
var structural_shape_last_committed_plane: StringName = StringName()
var structural_shape_rotation_quadrant: int = 0
var stage2_brush_radius_meters: float = 0.0
var stage2_hover_patch_ids: PackedStringArray = PackedStringArray()
var stage2_selected_patch_ids: PackedStringArray = PackedStringArray()
var tool_state_modifier: StringName = ForgeWorkspaceShapeToolPresenterScript.MODIFIER_ADD
var stage1_tool_family: StringName = ForgeWorkspaceShapeToolPresenterScript.FAMILY_FREEHAND
var stage2_tool_family: StringName = ForgeStage2BrushPresenterScript.FAMILY_STAGE2_CARVE

func _ready() -> void:
	panel.visible = false
	stow_hint_popup.hide()
	grip_hint_popup.hide()
	project_manager_popup.hide()
	free_subviewport.own_world_3d = true
	_configure_project_manager_popup()
	_configure_action_menus()
	_connect_ui_signals()
	_populate_stow_position_options()
	_populate_grip_style_options()
	_ensure_free_workspace_preview()
	stage2_brush_radius_meters = _get_view_tuning().workspace_stage2_default_brush_radius_meters
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
	if start_menu_visible:
		return
	_process_layer_hold_repeat(delta)
	_process_pending_edit_refresh(delta)
	_refresh_axis_indicator()

func _unhandled_input(event: InputEvent) -> void:
	if workspace_edit_flow.is_free_view_drag_active():
		if event is InputEventMouseMotion:
			workspace_interaction_presenter.handle_free_view_drag_motion_state(
				workspace_edit_flow,
				(event as InputEventMouseMotion).relative,
				free_workspace_preview,
				_get_view_tuning().workspace_pan_modifier_keycode
			)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton:
			var drag_button_event: InputEventMouseButton = event
			if drag_button_event.button_index == workspace_interaction_presenter.get_workspace_orbit_mouse_button(_get_view_tuning().workspace_orbit_mouse_button) and not drag_button_event.pressed:
				workspace_interaction_presenter.end_free_view_drag(
					workspace_edit_flow,
					get_viewport(),
					_get_view_tuning().workspace_capture_mouse_during_drag
				)
				get_viewport().set_input_as_handled()
				return
	if workspace_edit_flow.is_free_view_paint_active() and event is InputEventMouseButton:
		var paint_button_event: InputEventMouseButton = event
		if paint_button_event.button_index == MOUSE_BUTTON_LEFT and not paint_button_event.pressed:
			workspace_interaction_presenter.end_free_view_paint(
				workspace_edit_flow,
				Callable(self, "_flush_pending_edit_refresh")
			)
	if not panel.visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close_ui()
		get_viewport().set_input_as_handled()
		return
	if start_menu_visible:
		return
	if workspace_interaction_presenter.is_action_pressed_if_available(event, &"forge_bake"):
		_bake_active_wip()
		get_viewport().set_input_as_handled()
		return
	if workspace_interaction_presenter.is_action_pressed_if_available(event, &"forge_reset"):
		_reset_active_wip()
		get_viewport().set_input_as_handled()
		return
	if workspace_interaction_presenter.is_initial_action_press(event, &"forge_layer_down"):
		_begin_layer_hold(-1)
		_step_layer(-1)
		get_viewport().set_input_as_handled()
		return
	if workspace_interaction_presenter.is_initial_action_press(event, &"forge_layer_up"):
		_begin_layer_hold(1)
		_step_layer(1)
		get_viewport().set_input_as_handled()
		return
	if workspace_interaction_presenter.is_action_released_if_available(event, &"forge_layer_down") and workspace_interaction_presenter.held_layer_direction < 0:
		_clear_layer_hold()
		return
	if workspace_interaction_presenter.is_action_released_if_available(event, &"forge_layer_up") and workspace_interaction_presenter.held_layer_direction > 0:
		_clear_layer_hold()
		return
	if workspace_interaction_presenter.is_action_pressed_if_available(event, &"forge_plane_xy"):
		_set_active_plane(PLANE_XY)
		get_viewport().set_input_as_handled()
		return
	if workspace_interaction_presenter.is_action_pressed_if_available(event, &"forge_plane_zx"):
		_set_active_plane(PLANE_ZX)
		get_viewport().set_input_as_handled()
		return
	if workspace_interaction_presenter.is_action_pressed_if_available(event, &"forge_plane_zy"):
		_set_active_plane(PLANE_ZY)
		get_viewport().set_input_as_handled()

func toggle_for(player: PlayerController3D, controller: ForgeGridController, bench_name: String) -> void:
	if panel.visible:
		close_ui()
		return
	open_for(player, controller, bench_name)

func toggle_start_menu_for(player: PlayerController3D, controller: ForgeGridController, bench_name: String) -> void:
	if panel.visible:
		close_ui()
		return
	open_start_menu_for(player, controller, bench_name)

func open_for(player: PlayerController3D, controller: ForgeGridController, bench_name: String) -> void:
	_set_stage2_refinement_mode(false, false)
	active_player = player
	forge_controller = controller
	current_bench_name = bench_name
	var session_state: Dictionary = bench_session_presenter.open_session(
		active_player,
		forge_controller,
		bench_name,
		title_label,
		subtitle_label,
		panel,
		debug_popup,
		Callable(self, "_hide_stow_position_hint"),
		Callable(self, "_hide_grip_style_hint"),
		Callable(self, "_queue_layout_refresh"),
		Callable(self, "_reset_material_lookup_cache"),
		Callable(self, "_clear_layer_hold"),
		Callable(self, "_restore_preferred_player_project_if_available"),
		Callable(self, "_ensure_wip_for_editing"),
		Callable(self, "_get_default_layer_for_plane"),
		Callable(self, "_get_max_layer_for_plane"),
		Callable(self, "_rebuild_workflow_menu"),
		Callable(self, "_build_material_catalog"),
		Callable(self, "_refresh_all"),
		Callable(self, "_on_active_wip_changed"),
		Callable(self, "_on_active_test_print_changed")
	)
	debug_status_dirty = bool(session_state.get("debug_status_dirty", true))
	active_plane = session_state.get("active_plane", PLANE_XY)
	active_layer = int(session_state.get("active_layer", _get_default_layer_for_plane(active_plane)))
	_show_editor_surface_for_current_wip()

func open_start_menu_for(player: PlayerController3D, controller: ForgeGridController, bench_name: String) -> void:
	open_for(player, controller, bench_name)
	_show_start_menu()

func close_ui() -> void:
	_set_stage2_refinement_mode(false, false)
	_autosave_current_wip_if_needed()
	project_manager_popup.hide()
	var close_state: Dictionary = bench_session_presenter.close_session(
		active_player,
		panel,
		debug_popup,
		Callable(self, "_end_free_view_drag"),
		Callable(self, "_end_free_view_paint"),
		Callable(self, "_clear_layer_hold"),
		Callable(self, "_reset_pending_edit_refresh"),
		Callable(self, "_reset_material_lookup_cache"),
		Callable(self, "_hide_stow_position_hint"),
		Callable(self, "_hide_grip_style_hint")
	)
	if not bool(close_state.get("closed", false)):
		return
	active_player = close_state.get("active_player", null)
	start_menu_visible = false
	current_bench_name = ""
	emit_signal("closed")

func is_open() -> bool:
	return panel.visible

func _show_start_menu() -> void:
	start_menu_visible = true
	project_manager_popup.hide()
	bench_start_menu_presenter.apply_menu_surface(
		current_bench_name,
		title_label,
		subtitle_label
	)
	bench_start_menu_presenter.apply_menu_visibility(
		true,
		start_menu_panel,
		main_hbox
	)
	bench_start_menu_presenter.apply_continue_last_button_state(
		_get_player_forge_wip_library_state(),
		start_menu_continue_last_button
	)
	debug_popup.hide()
	_hide_stow_position_hint()
	_hide_grip_style_hint()
	_end_free_view_drag(false)
	_end_free_view_paint()
	_clear_layer_hold()
	_queue_layout_refresh()

func _show_editor_surface_for_current_wip() -> void:
	start_menu_visible = false
	project_manager_popup.hide()
	bench_start_menu_presenter.apply_menu_visibility(
		false,
		start_menu_panel,
		main_hbox
	)
	bench_start_menu_presenter.apply_editor_surface(
		current_bench_name,
		_get_current_builder_path_id(),
		title_label,
		subtitle_label
	)
	_queue_layout_refresh()

func _show_start_menu_from_editor() -> void:
	_autosave_current_wip_if_needed()
	_set_stage2_refinement_mode(false, false)
	_show_start_menu()

func _get_current_builder_path_id() -> StringName:
	var current_wip: CraftedItemWIP = forge_controller.active_wip if forge_controller != null else null
	if current_wip == null:
		return CraftedItemWIP.BUILDER_PATH_MELEE
	return CraftedItemWIP.normalize_builder_path_id(current_wip.forge_builder_path_id)

func _get_current_builder_component_id() -> StringName:
	var current_wip: CraftedItemWIP = forge_controller.active_wip if forge_controller != null else null
	var builder_path_id: StringName = _get_current_builder_path_id()
	if current_wip == null:
		return CraftedItemWIP.get_default_builder_component_id(builder_path_id)
	return CraftedItemWIP.normalize_builder_component_id(
		builder_path_id,
		current_wip.forge_builder_component_id
	)

func _configure_project_manager_popup() -> void:
	left_panel.visible = false
	left_panel.custom_minimum_size = Vector2.ZERO
	var project_button_rows: Array[NodePath] = [
		NodePath("ProjectMargin/ProjectVBox/ProjectButtonRow"),
		NodePath("ProjectMargin/ProjectVBox/ProjectButtonRowSecondary"),
		NodePath("ProjectMargin/ProjectVBox/ProjectButtonRowTertiary"),
	]
	for row_path: NodePath in project_button_rows:
		var row_node: Control = project_panel.get_node_or_null(row_path) as Control
		if row_node != null:
			row_node.visible = false
	if project_panel.get_parent() != project_manager_host:
		project_panel.reparent(project_manager_host)

func _connect_ui_signals() -> void:
	start_menu_continue_last_button.pressed.connect(_on_start_menu_continue_last_pressed)
	start_menu_project_list_button.pressed.connect(_on_start_menu_project_list_pressed)
	start_menu_new_melee_button.pressed.connect(_on_start_menu_new_melee_pressed)
	start_menu_new_ranged_physical_button.pressed.connect(_on_start_menu_new_ranged_physical_pressed)
	start_menu_new_shield_button.pressed.connect(_on_start_menu_new_shield_pressed)
	start_menu_new_magic_button.pressed.connect(_on_start_menu_new_magic_pressed)
	draw_tool_button.pressed.connect(_on_primary_overlay_tool_pressed)
	erase_tool_button.pressed.connect(_on_secondary_overlay_tool_pressed)
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
	builder_component_bow_button.pressed.connect(_on_builder_component_bow_pressed)
	builder_component_quiver_button.pressed.connect(_on_builder_component_quiver_pressed)
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
	project_menu_button.get_popup().about_to_popup.connect(_rebuild_project_menu)
	status_menu_button.get_popup().about_to_popup.connect(_rebuild_status_menu)
	geometry_menu_button.get_popup().about_to_popup.connect(_rebuild_geometry_menu)
	flip_view_button.pressed.connect(_on_flip_view_pressed)
	debug_info_button.pressed.connect(_open_debug_popup)
	debug_close_button.pressed.connect(func() -> void: debug_popup.hide())
	plane_viewport.cell_place_requested.connect(_on_plane_cell_place_requested)
	plane_viewport.cell_remove_requested.connect(_on_plane_cell_remove_requested)
	plane_viewport.cell_pick_requested.connect(_on_plane_cell_pick_requested)
	plane_viewport.drag_started.connect(_on_plane_drag_started)
	plane_viewport.drag_updated.connect(_on_plane_drag_updated)
	plane_viewport.stroke_finished.connect(_on_plane_stroke_finished)
	free_view_panel.gui_input.connect(_on_free_view_panel_gui_input)
	free_view_container.gui_input.connect(_on_free_view_gui_input)

func _configure_action_menus() -> void:
	bench_menu_presenter.configure_action_menus(
		project_menu_button,
		status_menu_button,
		view_menu_button,
		geometry_menu_button,
		workflow_menu_button,
		Callable(self, "_on_action_menu_id_pressed"),
		_get_action_menu_ids()
	)
	_rebuild_project_menu()
	_rebuild_status_menu()
	_rebuild_geometry_menu()

func _populate_stow_position_options() -> void:
	project_panel_presenter.populate_stow_position_options(project_stow_position_option_button)

func _populate_grip_style_options() -> void:
	project_panel_presenter.populate_grip_style_options(project_grip_style_option_button)

func _select_project_stow_position(stow_mode: StringName) -> void:
	project_panel_presenter.select_project_stow_position(project_stow_position_option_button, stow_mode)

func _get_selected_project_stow_position() -> StringName:
	return project_panel_presenter.get_selected_project_stow_position(project_stow_position_option_button)

func _select_project_grip_style(grip_mode: StringName, current_wip: CraftedItemWIP = null) -> void:
	project_panel_presenter.select_project_grip_style(project_grip_style_option_button, grip_mode, current_wip)

func _get_selected_project_grip_style() -> StringName:
	return project_panel_presenter.get_selected_project_grip_style(project_grip_style_option_button)

func _refresh_grip_style_option_availability(current_wip: CraftedItemWIP) -> void:
	project_panel_presenter.refresh_grip_style_option_availability(project_grip_style_option_button, current_wip)

func _show_stow_position_hint(stow_mode: StringName) -> void:
	project_panel_presenter.show_stow_position_hint(
		stow_hint_popup,
		stow_hint_label,
		stow_mode,
		get_viewport().get_visible_rect().size,
		get_viewport().get_mouse_position()
	)

func _hide_stow_position_hint() -> void:
	project_panel_presenter.hide_hint(stow_hint_popup)

func _show_grip_style_hint(grip_mode: StringName) -> void:
	project_panel_presenter.show_grip_style_hint(
		grip_hint_popup,
		grip_hint_label,
		grip_mode,
		get_viewport().get_visible_rect().size,
		get_viewport().get_mouse_position()
	)

func _hide_grip_style_hint() -> void:
	project_panel_presenter.hide_hint(grip_hint_popup)

func _ensure_free_workspace_preview() -> void:
	if is_instance_valid(free_workspace_preview):
		return
	free_workspace_preview = ForgeWorkspacePreview.new()
	free_workspace_preview.name = "ForgeWorkspacePreview"
	free_workspace_preview.set_view_tuning(_get_view_tuning())
	free_subviewport.add_child(free_workspace_preview)
	_refresh_axis_indicator()

func _build_material_catalog() -> void:
	var material_state: Dictionary = bench_material_state_presenter.build_material_catalog(
		material_catalog_presenter,
		forge_controller,
		_get_player_forge_inventory_state(),
		selected_material_variant_id,
		armed_material_variant_id,
		_get_material_lookup()
	)
	material_catalog = material_state.get("material_catalog", [])
	selected_material_variant_id = material_state.get("selected_material_variant_id", StringName())
	armed_material_variant_id = material_state.get("armed_material_variant_id", StringName())

func _refresh_all(preserve_workspace_view: bool = true) -> void:
	bench_refresh_presenter.refresh_all(
		Callable(self, "_reset_pending_edit_refresh"),
		Callable(self, "_rebuild_workflow_menu"),
		Callable(self, "_refresh_project_panel"),
		Callable(self, "_build_material_catalog"),
		Callable(self, "_refresh_inventory"),
		Callable(self, "_refresh_material_panels"),
		Callable(self, "_refresh_plane_and_preview"),
		Callable(self, "_refresh_left_panel"),
		Callable(self, "_refresh_status_text"),
		Callable(self, "_queue_layout_refresh"),
		preserve_workspace_view
	)

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
	var layout_config: Dictionary = _get_layout_config()
	var compact_mode: bool = workspace_layout_presenter.apply_root_layout(
		viewport_size,
		layout_config,
		panel,
		main_hbox,
		left_panel,
		right_panel,
		workspace_stage
	)
	last_layout_compact_mode = compact_mode
	last_layout_viewport_size = viewport_size
	_sync_workspace_hosts()
	_apply_workspace_layout(compact_mode)
	workspace_layout_presenter.apply_detail_panel_layout(
		compact_mode,
		layout_config,
		project_panel,
		project_notes_edit,
		project_list,
		inventory_list,
		description_panel,
		stats_panel
	)
	workspace_layout_presenter.apply_action_button_layout(
		compact_mode,
		layout_config,
		_get_action_buttons(),
		debug_popup.get_node("DebugMargin/DebugVBox") as Control
	)

func _get_action_buttons() -> Array[BaseButton]:
	return [
		project_menu_button,
		status_menu_button,
		view_menu_button,
		geometry_menu_button,
		workflow_menu_button,
		flip_view_button,
		debug_info_button,
	]

func _get_layout_config() -> Dictionary:
	return {
		"compact_width_breakpoint": compact_width_breakpoint,
		"compact_height_breakpoint": compact_height_breakpoint,
		"wide_outer_margin_ratio": wide_outer_margin_ratio,
		"compact_outer_margin_ratio": compact_outer_margin_ratio,
		"minimum_outer_margin_px": minimum_outer_margin_px,
		"maximum_outer_margin_px": maximum_outer_margin_px,
		"wide_left_panel_min_width": wide_left_panel_min_width,
		"compact_left_panel_min_width": compact_left_panel_min_width,
		"wide_right_panel_min_width": wide_right_panel_min_width,
		"compact_right_panel_min_width": compact_right_panel_min_width,
		"wide_workspace_stage_min_height": wide_workspace_stage_min_height,
		"compact_workspace_stage_min_height": compact_workspace_stage_min_height,
		"wide_project_panel_min_height": wide_project_panel_min_height,
		"compact_project_panel_min_height": compact_project_panel_min_height,
		"wide_project_notes_min_height": wide_project_notes_min_height,
		"compact_project_notes_min_height": compact_project_notes_min_height,
		"wide_project_list_min_height": wide_project_list_min_height,
		"compact_project_list_min_height": compact_project_list_min_height,
		"wide_inventory_list_min_height": wide_inventory_list_min_height,
		"compact_inventory_list_min_height": compact_inventory_list_min_height,
		"wide_description_panel_min_height": wide_description_panel_min_height,
		"compact_description_panel_min_height": compact_description_panel_min_height,
		"wide_stats_panel_min_height": wide_stats_panel_min_height,
		"compact_stats_panel_min_height": compact_stats_panel_min_height,
		"wide_action_button_min_width": wide_action_button_min_width,
		"compact_action_button_min_width": compact_action_button_min_width,
		"wide_action_button_min_height": wide_action_button_min_height,
		"compact_action_button_min_height": compact_action_button_min_height,
		"wide_workspace_inset_size": wide_workspace_inset_size,
		"compact_workspace_inset_size": compact_workspace_inset_size,
		"wide_workspace_inset_margin_px": wide_workspace_inset_margin_px,
		"compact_workspace_inset_margin_px": compact_workspace_inset_margin_px,
		"wide_plane_main_viewport_min_size": wide_plane_main_viewport_min_size,
		"compact_plane_main_viewport_min_size": compact_plane_main_viewport_min_size,
		"wide_plane_inset_viewport_min_size": wide_plane_inset_viewport_min_size,
		"compact_plane_inset_viewport_min_size": compact_plane_inset_viewport_min_size,
		"wide_free_main_viewport_min_size": wide_free_main_viewport_min_size,
		"compact_free_main_viewport_min_size": compact_free_main_viewport_min_size,
		"wide_free_inset_viewport_min_size": wide_free_inset_viewport_min_size,
		"compact_free_inset_viewport_min_size": compact_free_inset_viewport_min_size,
		"wide_debug_popup_min_size": wide_debug_popup_min_size,
		"compact_debug_popup_min_size": compact_debug_popup_min_size,
		"wide_panel_separation": wide_panel_separation,
		"compact_panel_separation": compact_panel_separation,
	}

func _sync_workspace_hosts() -> void:
	workspace_layout_presenter.sync_workspace_hosts(
		main_workspace_mode,
		WORKSPACE_VIEW_FREE,
		WORKSPACE_VIEW_PLANE,
		main_viewport_host,
		inset_viewport_host,
		free_view_panel,
		plane_view_panel,
		free_title_label,
		plane_title_label,
		flip_view_button
	)
	if is_instance_valid(tool_overlay_host):
		tool_overlay_host.move_to_front()

func _prepare_workspace_panel(panel_node: Control) -> void:
	workspace_layout_presenter.prepare_workspace_panel(panel_node)

func _apply_workspace_layout(compact_mode: bool) -> void:
	workspace_layout_presenter.apply_workspace_layout(
		compact_mode,
		_get_layout_config(),
		workspace_stage,
		inset_viewport_host,
		main_viewport_host,
		plane_viewport,
		free_view_container,
		free_view_panel,
		plane_view_panel,
		main_workspace_mode,
		WORKSPACE_VIEW_FREE,
		WORKSPACE_VIEW_PLANE
	)
	call_deferred("_sync_free_subviewport_size")
	if is_instance_valid(tool_overlay_host):
		tool_overlay_host.move_to_front()

func _sync_free_subviewport_size() -> void:
	workspace_layout_presenter.sync_free_subviewport_size(free_view_container, free_subviewport)

func _reset_material_lookup_cache() -> void:
	bench_material_state_presenter.reset_material_lookup_cache(cached_material_lookup)

func _get_material_lookup() -> Dictionary:
	return bench_material_state_presenter.get_material_lookup(forge_controller, cached_material_lookup)

func _refresh_inventory() -> void:
	visible_inventory_entries = bench_panel_presenter.refresh_inventory(
		material_catalog_presenter,
		material_catalog,
		current_inventory_page,
		search_box.text,
		selected_material_variant_id,
		_get_view_tuning(),
		inventory_list,
		owned_tab_button,
		all_tab_button,
		weapon_tab_button,
		PAGE_OWNED,
		PAGE_ALL,
		PAGE_WEAPON
	)

func _refresh_material_panels() -> void:
	bench_panel_presenter.refresh_material_panels(
		material_catalog_presenter,
		material_catalog,
		selected_material_variant_id,
		material_description_text,
		material_stats_text
	)

func _refresh_plane_and_preview(preserve_workspace_view: bool = true) -> void:
	_refresh_workspace_visuals(preserve_workspace_view, true)

func _refresh_workspace_visuals(preserve_workspace_view: bool = true, force_full_sync: bool = false) -> void:
	var current_wip: CraftedItemWIP = _ensure_wip_for_editing()
	_ensure_free_workspace_preview()
	orientation_label.text = workspace_presentation.refresh_workspace_visuals(
		forge_controller,
		current_wip,
		active_plane,
		active_layer,
		plane_viewport,
		free_workspace_preview,
		_get_material_lookup(),
		_get_view_tuning(),
		preserve_workspace_view,
		force_full_sync,
		show_grid_bounds,
		show_active_slice,
		main_workspace_mode,
		stage2_refinement_mode_active
	)
	_sync_structural_shape_preview()
	_refresh_stage2_selection_preview()
	_refresh_axis_indicator()

func _refresh_stage2_selection_preview() -> void:
	if not is_instance_valid(free_workspace_preview) or forge_controller == null:
		return
	var current_wip: CraftedItemWIP = forge_controller.active_wip
	if (
		not stage2_refinement_mode_active
		or not _is_stage2_selection_tool(active_tool)
		or current_wip == null
		or current_wip.stage2_item_state == null
	):
		free_workspace_preview.clear_stage2_selection_preview()
		return
	free_workspace_preview.set_stage2_selection_preview_state(
		current_wip.stage2_item_state,
		stage2_hover_patch_ids,
		stage2_selected_patch_ids,
		forge_controller.test_print_mesh_builder
	)

func _refresh_axis_indicator() -> void:
	if axis_indicator_control == null:
		return
	if not is_instance_valid(free_workspace_preview):
		axis_indicator_control.clear_state()
		return
	axis_indicator_control.sync_from_preview(free_workspace_preview)

func _sync_structural_shape_preview() -> void:
	if plane_viewport == null:
		return
	if structural_shape_preview_grid_positions.is_empty():
		plane_viewport.clear_structural_shape_preview_state()
		if is_instance_valid(free_workspace_preview):
			free_workspace_preview.clear_structural_shape_preview()
		return
	var remove_mode: bool = tool_state_modifier == ForgeWorkspaceShapeToolPresenterScript.MODIFIER_REMOVE
	plane_viewport.set_structural_shape_preview_state(
		structural_shape_preview_grid_positions,
		armed_material_variant_id,
		remove_mode
	)
	if is_instance_valid(free_workspace_preview):
		free_workspace_preview.set_structural_shape_preview_state(
			structural_shape_preview_grid_positions,
			armed_material_variant_id,
			remove_mode
		)

func _clear_structural_shape_preview() -> void:
	structural_shape_drag_active = false
	structural_shape_drag_anchor_grid_position = Vector3i.ZERO
	structural_shape_drag_current_grid_position = Vector3i.ZERO
	structural_shape_preview_grid_positions.clear()
	structural_shape_preview_dirty = false
	structural_shape_last_committed_layer = -1
	structural_shape_last_committed_plane = StringName()
	_sync_structural_shape_preview()

func _update_structural_shape_preview() -> void:
	if not structural_shape_drag_active:
		_clear_structural_shape_preview()
		return
	if workspace_shape_tool_presenter.is_shape_tool(active_tool) and forge_controller != null:
		structural_shape_preview_grid_positions = workspace_shape_tool_presenter.build_shape_footprint(
			active_tool,
			structural_shape_drag_anchor_grid_position,
			structural_shape_drag_current_grid_position,
			active_plane,
			active_layer,
			forge_controller.grid_size,
			structural_shape_rotation_quadrant
		)
	else:
		structural_shape_preview_grid_positions.clear()
	_mark_structural_shape_preview_dirty()
	_sync_structural_shape_preview()

func _commit_structural_shape_preview(clear_after_commit: bool = true) -> void:
	if structural_shape_preview_grid_positions.is_empty():
		if clear_after_commit:
			_clear_structural_shape_preview()
			_flush_pending_edit_refresh(true)
		else:
			_mark_current_structural_shape_layer_committed()
		return
	var result: Dictionary = {}
	suppress_active_wip_refresh = true
	if workspace_shape_tool_presenter.is_subtractive_shape_tool(active_tool):
		result = workspace_edit_action_presenter.remove_cells(
			forge_controller,
			_get_player_forge_inventory_state(),
			structural_shape_preview_grid_positions
		)
	else:
		result = workspace_edit_action_presenter.apply_material_cells(
			forge_controller,
			_get_player_forge_inventory_state(),
			armed_material_variant_id,
			structural_shape_preview_grid_positions,
			Callable(self, "_ensure_wip_for_editing")
		)
	suppress_active_wip_refresh = false
	var should_refresh_after_edit: bool = bool(result.get("queue_edit_refresh", false))
	if bool(result.get("debug_status_dirty", false)):
		debug_status_dirty = true
	_mark_current_structural_shape_layer_committed()
	if clear_after_commit:
		_clear_structural_shape_preview()
		if should_refresh_after_edit:
			_refresh_after_edit()
		else:
			_flush_pending_edit_refresh(true)
	elif should_refresh_after_edit:
		_refresh_after_edit()

func _mark_structural_shape_preview_dirty() -> void:
	structural_shape_preview_dirty = true

func _mark_current_structural_shape_layer_committed() -> void:
	structural_shape_preview_dirty = false
	structural_shape_last_committed_layer = active_layer
	structural_shape_last_committed_plane = active_plane

func _has_pending_structural_shape_commit_for_current_layer() -> bool:
	return (
		structural_shape_preview_dirty
		or structural_shape_last_committed_layer != active_layer
		or structural_shape_last_committed_plane != active_plane
	)

func _queue_edit_refresh(preserve_workspace_view: bool = true) -> void:
	workspace_edit_flow.queue_edit_refresh(preserve_workspace_view)
	debug_status_dirty = true

func _process_pending_edit_refresh(delta: float) -> void:
	workspace_edit_flow.process_pending_edit_refresh(
		delta,
		edit_panel_refresh_interval_seconds,
		Callable(self, "_refresh_workspace_visuals_for_pending_edit"),
		Callable(self, "_flush_pending_edit_panels")
	)

func _flush_pending_edit_refresh(force: bool = false) -> void:
	workspace_edit_flow.flush_pending_edit_refresh(
		force,
		Callable(self, "_refresh_workspace_visuals_for_pending_edit"),
		Callable(self, "_flush_pending_edit_panels")
	)

func _flush_pending_edit_panels() -> void:
	bench_refresh_presenter.refresh_pending_edit_panels(
		Callable(self, "_build_material_catalog"),
		Callable(self, "_refresh_inventory"),
		Callable(self, "_refresh_material_panels"),
		Callable(self, "_refresh_left_panel"),
		Callable(workspace_edit_flow, "clear_pending_panel_refresh")
	)

func _reset_pending_edit_refresh() -> void:
	workspace_edit_flow.reset_pending_edit_refresh()

func _refresh_workspace_visuals_for_pending_edit(preserve_workspace_view: bool) -> void:
	_refresh_workspace_visuals(preserve_workspace_view, false)

func _refresh_left_panel() -> void:
	last_left_panel_state = {}
	if forge_controller == null:
		_refresh_tool_overlay()
		_rebuild_status_menu()
		return
	bench_panel_presenter.refresh_left_panel(
		workspace_presentation,
		forge_controller,
		_ensure_wip_for_editing(),
		active_plane,
		active_layer,
		_get_max_layer_for_plane(active_plane),
		active_tool,
		_get_armed_material_display_name(),
		stage2_refinement_mode_active,
		workspace_shape_tool_presenter.get_rotation_degrees(structural_shape_rotation_quadrant),
		_get_view_tuning(),
		layer_status_label,
		plane_status_label,
		armed_material_label,
		capacity_label,
		capacity_bar,
		place_category_button,
		erase_category_button,
		single_tool_button,
		pick_tool_button,
		xy_plane_button,
		zx_plane_button,
		zy_plane_button
	)
	_refresh_tool_overlay()
	last_left_panel_state = workspace_presentation.build_left_panel_state(
		forge_controller,
		_ensure_wip_for_editing(),
		active_plane,
		active_layer,
		_get_max_layer_for_plane(active_plane),
		active_tool,
		_get_armed_material_display_name(),
		stage2_refinement_mode_active,
		workspace_shape_tool_presenter.get_rotation_degrees(structural_shape_rotation_quadrant)
	)
	_rebuild_status_menu()

func _refresh_tool_overlay() -> void:
	var view_tuning: ForgeViewTuningDef = _get_view_tuning()
	var draw_active: bool = tool_state_modifier == ForgeWorkspaceShapeToolPresenterScript.MODIFIER_ADD
	var erase_active: bool = tool_state_modifier == ForgeWorkspaceShapeToolPresenterScript.MODIFIER_REMOVE
	draw_tool_button.text = "Apply" if stage2_refinement_mode_active else "Draw"
	erase_tool_button.text = "Revert" if stage2_refinement_mode_active else "Erase"
	draw_tool_button.set_pressed_no_signal(draw_active)
	erase_tool_button.set_pressed_no_signal(erase_active)
	draw_tool_button.modulate = view_tuning.ui_button_active_color if draw_active else view_tuning.ui_button_inactive_color
	erase_tool_button.modulate = view_tuning.ui_button_active_color if erase_active else view_tuning.ui_button_inactive_color
	tool_state_label.text = "Tool State: %s" % _get_overlay_tool_state_text()
	active_tool_label.text = "Active Tool: %s" % _get_overlay_active_tool_text()
	var show_shape_status: bool = (
		not stage2_refinement_mode_active
		and workspace_shape_tool_presenter.is_shape_family(stage1_tool_family)
	)
	shape_size_status_label.visible = show_shape_status
	rotation_status_label.visible = show_shape_status
	if show_shape_status:
		shape_size_status_label.text = "Size: Drag Footprint"
		rotation_status_label.text = "Rotation: %d°" % workspace_shape_tool_presenter.get_rotation_degrees(structural_shape_rotation_quadrant)
	var show_material_status: bool = _should_show_overlay_material_status()
	material_status_label.visible = show_material_status
	if show_material_status:
		material_status_label.text = _get_overlay_material_status_text()
	var show_radius_status: bool = _should_show_overlay_radius_status()
	radius_status_label.visible = show_radius_status
	if show_radius_status:
		radius_status_label.text = "Radius: %s m" % _format_overlay_radius_text(stage2_brush_radius_meters)

func _on_primary_overlay_tool_pressed() -> void:
	_set_tool_state_modifier(ForgeWorkspaceShapeToolPresenterScript.MODIFIER_ADD)

func _on_secondary_overlay_tool_pressed() -> void:
	_set_tool_state_modifier(ForgeWorkspaceShapeToolPresenterScript.MODIFIER_REMOVE)

func _get_overlay_tool_state_text() -> String:
	match tool_state_modifier:
		ForgeWorkspaceShapeToolPresenterScript.MODIFIER_PICK:
			return "Pick"
		ForgeWorkspaceShapeToolPresenterScript.MODIFIER_REMOVE:
			return "Remove"
		_:
			return "Add"

func _get_overlay_active_tool_text() -> String:
	if tool_state_modifier == ForgeWorkspaceShapeToolPresenterScript.MODIFIER_PICK:
		return "Pick Material"
	if stage2_refinement_mode_active:
		if stage2_selection_presenter.is_selection_family(stage2_tool_family):
			return stage2_selection_presenter.get_selection_tool_display_name(stage2_tool_family)
		return stage2_brush_presenter.get_pointer_tool_display_name(stage2_tool_family)
	return workspace_shape_tool_presenter.get_stage1_tool_display_name(stage1_tool_family)

func _should_show_overlay_material_status() -> bool:
	return (
		not stage2_refinement_mode_active
		and tool_state_modifier != ForgeWorkspaceShapeToolPresenterScript.MODIFIER_PICK
	)

func _get_overlay_material_status_text() -> String:
	var material_entry: Dictionary = _get_overlay_material_entry()
	if material_entry.is_empty():
		return "Select Material"
	var display_name: String = String(material_entry.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		return "Select Material"
	if bool(material_entry.get("is_placeable_without_inventory", false)):
		return display_name
	return "%s - %d" % [display_name, int(material_entry.get("quantity", 0))]

func _get_overlay_material_entry() -> Dictionary:
	var material_id: StringName = (
		armed_material_variant_id
		if armed_material_variant_id != StringName()
		else selected_material_variant_id
	)
	return material_catalog_presenter.get_material_entry(material_catalog, material_id)

func _should_show_overlay_radius_status() -> bool:
	return (
		stage2_refinement_mode_active
		and stage2_brush_presenter.is_pointer_radius_family(stage2_tool_family)
	)

func _format_overlay_radius_text(radius_meters: float) -> String:
	return ("%.4f" % snappedf(radius_meters, 0.0001)).rstrip("0").rstrip(".")

func _refresh_status_text() -> void:
	last_debug_text = bench_panel_presenter.refresh_status_text(
		workspace_presentation,
		forge_controller,
		_ensure_wip_for_editing(),
		active_plane,
		active_layer,
		active_tool,
		_get_active_project_display_name(_ensure_wip_for_editing()),
		_get_selected_material_display_name(),
		_get_armed_material_display_name(),
		_get_material_lookup(),
		stage2_refinement_mode_active,
		workspace_shape_tool_presenter.get_rotation_degrees(structural_shape_rotation_quadrant),
		status_text
	)
	debug_status_dirty = false

func _set_inventory_page(page_id: StringName) -> void:
	current_inventory_page = workspace_interaction_presenter.resolve_inventory_page(page_id)
	_refresh_inventory()

func _set_tool_state_modifier(modifier_id: StringName, refresh_ui: bool = true) -> void:
	if stage2_refinement_mode_active and modifier_id == ForgeWorkspaceShapeToolPresenterScript.MODIFIER_PICK:
		modifier_id = ForgeWorkspaceShapeToolPresenterScript.MODIFIER_ADD
	if not stage2_refinement_mode_active and modifier_id == ForgeWorkspaceShapeToolPresenterScript.MODIFIER_PICK:
		stage1_tool_family = ForgeWorkspaceShapeToolPresenterScript.FAMILY_FREEHAND
	tool_state_modifier = modifier_id
	_apply_active_tool_change(refresh_ui)

func _sync_stage1_tool_state_from_effective_tool(tool_id: StringName) -> void:
	stage1_tool_family = workspace_shape_tool_presenter.resolve_stage1_tool_family(tool_id)
	tool_state_modifier = workspace_shape_tool_presenter.resolve_stage1_modifier(tool_id)

func _sync_stage2_tool_state_from_effective_tool(tool_id: StringName) -> void:
	if stage2_selection_presenter.is_selection_tool(tool_id):
		stage2_tool_family = stage2_selection_presenter.resolve_selection_family(tool_id, stage2_tool_family)
		tool_state_modifier = (
			ForgeWorkspaceShapeToolPresenterScript.MODIFIER_REMOVE
			if String(tool_id).ends_with("_restore")
			else ForgeWorkspaceShapeToolPresenterScript.MODIFIER_ADD
		)
		return
	stage2_tool_family = stage2_brush_presenter.resolve_pointer_tool_family(tool_id, stage2_tool_family)
	tool_state_modifier = (
		ForgeWorkspaceShapeToolPresenterScript.MODIFIER_REMOVE
		if tool_id == ForgeStage2BrushPresenterScript.TOOL_STAGE2_RESTORE
		else ForgeWorkspaceShapeToolPresenterScript.MODIFIER_ADD
	)

func _compose_effective_active_tool_from_state() -> StringName:
	if stage2_refinement_mode_active:
		var stage2_modifier: StringName = (
			ForgeStage2BrushPresenterScript.MODIFIER_REMOVE
			if tool_state_modifier == ForgeWorkspaceShapeToolPresenterScript.MODIFIER_REMOVE
			else ForgeStage2BrushPresenterScript.MODIFIER_ADD
		)
		if stage2_selection_presenter.is_selection_family(stage2_tool_family):
			return stage2_selection_presenter.compose_selection_tool_id(stage2_tool_family, stage2_modifier)
		return stage2_brush_presenter.compose_pointer_tool_id(stage2_tool_family, stage2_modifier)
	return workspace_shape_tool_presenter.compose_stage1_tool_id(stage1_tool_family, tool_state_modifier)

func _apply_active_tool_change(refresh_ui: bool = true) -> void:
	active_tool = workspace_interaction_presenter.resolve_active_tool(_compose_effective_active_tool_from_state())
	if not workspace_shape_tool_presenter.is_shape_tool(active_tool):
		_clear_structural_shape_preview()
	stage2_hover_patch_ids = PackedStringArray()
	_rebuild_geometry_menu()
	if is_instance_valid(free_workspace_preview):
		if _is_stage2_selection_tool(active_tool):
			free_workspace_preview.clear_stage2_brush_preview()
			_refresh_stage2_selection_preview()
		else:
			free_workspace_preview.clear_stage2_selection_preview()
	if refresh_ui:
		_refresh_left_panel()
		_refresh_status_text()

func _set_active_tool(tool_id: StringName, refresh_ui: bool = true) -> void:
	if stage2_refinement_mode_active:
		if tool_id == TOOL_PLACE:
			tool_state_modifier = ForgeWorkspaceShapeToolPresenterScript.MODIFIER_ADD
		elif tool_id == TOOL_ERASE:
			tool_state_modifier = ForgeWorkspaceShapeToolPresenterScript.MODIFIER_REMOVE
		elif tool_id == TOOL_PICK:
			tool_state_modifier = ForgeWorkspaceShapeToolPresenterScript.MODIFIER_ADD
		elif stage2_selection_presenter.is_selection_family(tool_id):
			stage2_tool_family = tool_id
			if tool_state_modifier == ForgeWorkspaceShapeToolPresenterScript.MODIFIER_PICK:
				tool_state_modifier = ForgeWorkspaceShapeToolPresenterScript.MODIFIER_ADD
		elif stage2_selection_presenter.is_selection_tool(tool_id):
			_sync_stage2_tool_state_from_effective_tool(tool_id)
		elif stage2_brush_presenter.is_pointer_radius_family(tool_id):
			stage2_tool_family = tool_id
			if tool_state_modifier == ForgeWorkspaceShapeToolPresenterScript.MODIFIER_PICK:
				tool_state_modifier = ForgeWorkspaceShapeToolPresenterScript.MODIFIER_ADD
		elif stage2_brush_presenter.is_pointer_radius_tool(tool_id):
			_sync_stage2_tool_state_from_effective_tool(tool_id)
	else:
		if tool_id == TOOL_PICK:
			stage1_tool_family = ForgeWorkspaceShapeToolPresenterScript.FAMILY_FREEHAND
			tool_state_modifier = ForgeWorkspaceShapeToolPresenterScript.MODIFIER_PICK
		elif tool_id == ForgeWorkspaceShapeToolPresenterScript.FAMILY_FREEHAND:
			stage1_tool_family = ForgeWorkspaceShapeToolPresenterScript.FAMILY_FREEHAND
			if tool_state_modifier == ForgeWorkspaceShapeToolPresenterScript.MODIFIER_PICK:
				tool_state_modifier = ForgeWorkspaceShapeToolPresenterScript.MODIFIER_ADD
		elif workspace_shape_tool_presenter.is_stage1_tool_family(tool_id):
			stage1_tool_family = tool_id
			if tool_state_modifier == ForgeWorkspaceShapeToolPresenterScript.MODIFIER_PICK:
				tool_state_modifier = ForgeWorkspaceShapeToolPresenterScript.MODIFIER_ADD
		elif tool_id == TOOL_PLACE or tool_id == TOOL_ERASE or workspace_shape_tool_presenter.is_shape_tool(tool_id):
			_sync_stage1_tool_state_from_effective_tool(tool_id)
		elif _is_stage2_refinement_tool(tool_id):
			_sync_stage1_tool_state_from_effective_tool(stage1_active_tool_before_stage2_refinement)
		else:
			_sync_stage1_tool_state_from_effective_tool(tool_id)
	_apply_active_tool_change(refresh_ui)

func _step_structural_shape_rotation(delta_quadrants: int) -> void:
	structural_shape_rotation_quadrant = posmod(structural_shape_rotation_quadrant + delta_quadrants, 4)
	if structural_shape_drag_active and workspace_shape_tool_presenter.is_shape_tool(active_tool):
		_update_structural_shape_preview()
	_rebuild_geometry_menu()
	_refresh_left_panel()
	_refresh_status_text()

func _is_stage2_refinement_tool(tool_id: StringName) -> bool:
	return (
		tool_id == ForgeStage2BrushPresenterScript.TOOL_STAGE2_CARVE
		or tool_id == ForgeStage2BrushPresenterScript.TOOL_STAGE2_CHAMFER
		or tool_id == ForgeStage2BrushPresenterScript.TOOL_STAGE2_FILLET
		or tool_id == ForgeStage2BrushPresenterScript.TOOL_STAGE2_RESTORE
		or _is_stage2_selection_tool(tool_id)
	)

func _is_stage2_selection_tool(tool_id: StringName) -> bool:
	return stage2_selection_presenter.is_selection_tool(tool_id)

func _get_stage2_item_state():
	var current_wip: CraftedItemWIP = forge_controller.active_wip if forge_controller != null else null
	return current_wip.stage2_item_state if current_wip != null else null

func _can_enter_stage2_refinement_mode() -> bool:
	var stage2_item_state = _get_stage2_item_state()
	return stage2_item_state != null and stage2_item_state.has_current_shell()

func _get_stage2_pointer_tool_min_radius_meters() -> float:
	var rules: ForgeRulesDef = forge_controller.forge_rules if forge_controller != null else null
	return (
		float(rules.stage2_pointer_tool_min_radius_meters)
		if rules != null
		else DEFAULT_STAGE2_POINTER_TOOL_MIN_RADIUS_METERS
	)

func _get_stage2_pointer_tool_max_radius_meters() -> float:
	var rules: ForgeRulesDef = forge_controller.forge_rules if forge_controller != null else null
	return (
		float(rules.stage2_pointer_tool_max_radius_meters)
		if rules != null
		else DEFAULT_STAGE2_POINTER_TOOL_MAX_RADIUS_METERS
	)

func _get_stage2_pointer_tool_radius_step_meters() -> float:
	var rules: ForgeRulesDef = forge_controller.forge_rules if forge_controller != null else null
	return (
		float(rules.stage2_pointer_tool_radius_step_meters)
		if rules != null
		else DEFAULT_STAGE2_POINTER_TOOL_RADIUS_STEP_METERS
	)

func _clamp_stage2_pointer_tool_radius_meters(radius_meters: float) -> float:
	var min_radius_meters: float = _get_stage2_pointer_tool_min_radius_meters()
	var max_radius_meters: float = maxf(
		_get_stage2_pointer_tool_max_radius_meters(),
		min_radius_meters
	)
	return clampf(radius_meters, min_radius_meters, max_radius_meters)

func _step_stage2_pointer_tool_radius(step_direction: int, hover_screen_position: Vector2 = Vector2.ZERO) -> void:
	if not stage2_brush_presenter.is_pointer_radius_tool(active_tool):
		return
	var next_radius_meters: float = _clamp_stage2_pointer_tool_radius_meters(
		stage2_brush_radius_meters + (float(step_direction) * _get_stage2_pointer_tool_radius_step_meters())
	)
	if is_equal_approx(next_radius_meters, stage2_brush_radius_meters):
		return
	stage2_brush_radius_meters = next_radius_meters
	_refresh_tool_overlay()
	_refresh_status_text()
	if hover_screen_position != Vector2.ZERO:
		_update_stage2_brush_hover(hover_screen_position)

func _get_stage2_brush_step_meters() -> float:
	var cell_world_size_meters: float = (
		forge_controller.get_cell_world_size_meters()
		if forge_controller != null
		else 0.025
	)
	return maxf(
		cell_world_size_meters * _get_view_tuning().workspace_stage2_brush_step_ratio,
		0.0005
	)

func _toggle_stage2_refinement_mode() -> void:
	_set_stage2_refinement_mode(not stage2_refinement_mode_active)

func _set_stage2_refinement_mode(next_active: bool, refresh_ui: bool = true) -> void:
	if structural_shape_drag_active:
		_clear_structural_shape_preview()
	if next_active and not _can_enter_stage2_refinement_mode():
		next_active = false
	if stage2_refinement_mode_active == next_active:
		if not next_active and is_instance_valid(free_workspace_preview):
			free_workspace_preview.clear_stage2_brush_preview()
			free_workspace_preview.clear_stage2_selection_preview()
		return
	stage2_refinement_mode_active = next_active
	stage2_hover_patch_ids = PackedStringArray()
	stage2_selected_patch_ids = PackedStringArray()
	if stage2_refinement_mode_active:
		if not _is_stage2_refinement_tool(active_tool):
			stage1_active_tool_before_stage2_refinement = active_tool
		if tool_state_modifier == ForgeWorkspaceShapeToolPresenterScript.MODIFIER_PICK:
			tool_state_modifier = ForgeWorkspaceShapeToolPresenterScript.MODIFIER_ADD
		if not (
			stage2_brush_presenter.is_pointer_radius_family(stage2_tool_family)
			or stage2_selection_presenter.is_selection_family(stage2_tool_family)
		):
			stage2_tool_family = ForgeStage2BrushPresenterScript.FAMILY_STAGE2_CARVE
		stage2_brush_radius_meters = _clamp_stage2_pointer_tool_radius_meters(
			maxf(
				stage2_brush_radius_meters,
				_get_view_tuning().workspace_stage2_default_brush_radius_meters
			)
		)
		if is_instance_valid(free_workspace_preview):
			free_workspace_preview.clear_stage2_brush_preview()
			free_workspace_preview.clear_stage2_selection_preview()
	else:
		_sync_stage1_tool_state_from_effective_tool(stage1_active_tool_before_stage2_refinement)
		if is_instance_valid(free_workspace_preview):
			free_workspace_preview.clear_stage2_brush_preview()
			free_workspace_preview.clear_stage2_selection_preview()
	_apply_active_tool_change(false)
	if refresh_ui:
		_rebuild_geometry_menu()
		_refresh_left_panel()
		_refresh_status_text()
		_rebuild_workflow_menu()
		_refresh_workspace_visuals()

func _set_active_plane(plane_id: StringName) -> void:
	if structural_shape_drag_active:
		_clear_structural_shape_preview()
	var plane_state: Dictionary = workspace_interaction_presenter.resolve_active_plane_state(
		active_layer,
		plane_id,
		forge_controller,
		Callable(self, "_get_default_layer_for_plane"),
		Callable(self, "_get_max_layer_for_plane")
	)
	active_plane = plane_state.get("active_plane", plane_id)
	active_layer = int(plane_state.get("active_layer", active_layer))
	_refresh_plane_and_preview()
	_refresh_left_panel()
	_refresh_status_text()

func _step_layer(delta: int) -> void:
	var previous_active_layer: int = active_layer
	var next_active_layer: int = workspace_interaction_presenter.resolve_stepped_layer(
		active_layer,
		active_plane,
		delta,
		forge_controller,
		PLANE_XY,
		Callable(self, "_get_max_layer_for_plane")
	)
	if (
		next_active_layer != active_layer
		and structural_shape_drag_active
		and workspace_shape_tool_presenter.is_shape_tool(active_tool)
		and _has_pending_structural_shape_commit_for_current_layer()
	):
		_commit_structural_shape_preview(false)
	active_layer = next_active_layer
	_refresh_plane_and_preview()
	if active_layer != previous_active_layer:
		if structural_shape_drag_active and workspace_shape_tool_presenter.is_shape_tool(active_tool):
			_update_structural_shape_preview()
		_apply_plane_layer_sweep_after_step()
	_refresh_left_panel()
	_refresh_status_text()

func _apply_plane_layer_sweep_after_step() -> void:
	if stage2_refinement_mode_active:
		return
	if active_tool == TOOL_PICK:
		return
	if workspace_shape_tool_presenter.is_shape_tool(active_tool):
		if structural_shape_drag_active and _has_pending_structural_shape_commit_for_current_layer():
			_commit_structural_shape_preview(false)
		return
	if plane_viewport == null or not plane_viewport.has_active_drag_action():
		return
	plane_viewport.emit_active_drag_action_for_current_layer()

func _on_inventory_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	var selection_state: Dictionary = workspace_interaction_presenter.resolve_inventory_selection(
		index,
		visible_inventory_entries,
		selected_material_variant_id,
		armed_material_variant_id
	)
	var material_selection_state: Dictionary = bench_refresh_presenter.apply_material_selection_state(
		selection_state,
		selected_material_variant_id,
		armed_material_variant_id,
		Callable(self, "_refresh_inventory"),
		Callable(self, "_refresh_material_panels"),
		Callable(self, "_refresh_left_panel"),
		Callable(self, "_refresh_status_text")
	)
	if not bool(material_selection_state.get("applied", false)):
		return
	selected_material_variant_id = material_selection_state.get("selected_material_variant_id", StringName())
	armed_material_variant_id = material_selection_state.get("armed_material_variant_id", StringName())

func _on_flip_view_pressed() -> void:
	main_workspace_mode = workspace_interaction_presenter.toggle_workspace_mode(
		main_workspace_mode,
		WORKSPACE_VIEW_FREE,
		WORKSPACE_VIEW_PLANE
	)
	_sync_workspace_hosts()
	_refresh_plane_and_preview()
	_queue_layout_refresh()

func _open_debug_popup() -> void:
	bench_debug_presenter.open_debug_popup(
		panel.visible,
		Callable(self, "_flush_pending_edit_refresh"),
		debug_status_dirty,
		status_text.text,
		Callable(self, "_refresh_status_text"),
		last_layout_compact_mode,
		compact_debug_popup_min_size,
		wide_debug_popup_min_size,
		debug_popup
	)

func _on_plane_cell_place_requested(grid_position: Vector3i) -> void:
	if stage2_refinement_mode_active:
		return
	if workspace_shape_tool_presenter.is_shape_tool(active_tool):
		return
	workspace_interaction_presenter.handle_plane_cell_place_requested(
		active_tool,
		TOOL_PICK,
		TOOL_ERASE,
		grid_position,
		Callable(self, "_pick_material_from_grid"),
		Callable(self, "_remove_cell"),
		Callable(self, "_place_material_cell")
	)

func _on_plane_cell_remove_requested(grid_position: Vector3i) -> void:
	if stage2_refinement_mode_active:
		return
	if workspace_shape_tool_presenter.is_shape_tool(active_tool):
		return
	_remove_cell(grid_position)

func _on_plane_cell_pick_requested(grid_position: Vector3i) -> void:
	if stage2_refinement_mode_active:
		return
	_pick_material_from_grid(grid_position)

func _on_plane_drag_started(grid_position: Vector3i, button_index: MouseButton) -> void:
	if stage2_refinement_mode_active:
		return
	if not workspace_shape_tool_presenter.is_shape_tool(active_tool):
		return
	if button_index != MOUSE_BUTTON_LEFT:
		return
	structural_shape_drag_active = true
	structural_shape_drag_anchor_grid_position = grid_position
	structural_shape_drag_current_grid_position = grid_position
	_update_structural_shape_preview()

func _on_plane_drag_updated(grid_position: Vector3i, button_index: MouseButton) -> void:
	if stage2_refinement_mode_active:
		return
	if not structural_shape_drag_active:
		return
	if not workspace_shape_tool_presenter.is_shape_tool(active_tool):
		return
	if button_index != MOUSE_BUTTON_LEFT:
		return
	structural_shape_drag_current_grid_position = grid_position
	_update_structural_shape_preview()

func _on_plane_stroke_finished() -> void:
	if structural_shape_drag_active and workspace_shape_tool_presenter.is_shape_tool(active_tool):
		if _has_pending_structural_shape_commit_for_current_layer():
			_commit_structural_shape_preview()
		else:
			_clear_structural_shape_preview()
			_flush_pending_edit_refresh(true)
		return
	_flush_pending_edit_refresh(true)

func _on_free_view_panel_gui_input(event: InputEvent) -> void:
	workspace_interaction_presenter.handle_free_view_panel_gui_input(
		event,
		forge_controller,
		free_workspace_preview,
		_get_view_tuning().workspace_zoom_step
	)

func _on_free_view_gui_input(event: InputEvent) -> void:
	if stage2_refinement_mode_active:
		_handle_stage2_free_view_gui_input(event)
		return
	workspace_interaction_presenter.handle_free_view_gui_input(
		event,
		forge_controller,
		free_workspace_preview,
		active_tool,
		TOOL_PICK,
		workspace_edit_flow,
		_get_workspace_orbit_mouse_button(),
		_get_view_tuning().workspace_zoom_step,
		Callable(self, "_pick_material_from_screen_position"),
		Callable(self, "_begin_free_view_drag"),
		Callable(self, "_end_free_view_drag"),
		Callable(self, "_begin_free_view_paint"),
		Callable(self, "_end_free_view_paint"),
		Callable(self, "_paint_free_view_at_screen_position"),
		Callable(self, "_handle_free_view_drag_motion")
	)

func _handle_stage2_free_view_gui_input(event: InputEvent) -> void:
	if forge_controller == null or not is_instance_valid(free_workspace_preview):
		return
	if _is_stage2_selection_tool(active_tool):
		_handle_stage2_selection_free_view_gui_input(event)
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.ctrl_pressed and mouse_button.pressed:
			if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
				_step_stage2_pointer_tool_radius(1, mouse_button.position)
				return
			if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_step_stage2_pointer_tool_radius(-1, mouse_button.position)
				return
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
			_update_stage2_brush_hover(mouse_button.position)
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_begin_free_view_paint()
			_apply_stage2_brush_at_screen_position(mouse_button.position)
			return
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		if workspace_edit_flow.is_free_view_drag_active():
			_handle_free_view_drag_motion(motion_event.relative)
			return
		_update_stage2_brush_hover(motion_event.position)
		if workspace_edit_flow.is_free_view_paint_active():
			_apply_stage2_brush_at_screen_position(motion_event.position)

func _handle_stage2_selection_free_view_gui_input(event: InputEvent) -> void:
	if forge_controller == null or not is_instance_valid(free_workspace_preview):
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.ctrl_pressed and mouse_button.pressed and (
			mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP
			or mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN
		):
			return
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
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_toggle_stage2_patch_selection_at_screen_position(mouse_button.position)
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			_update_stage2_selection_hover(mouse_button.position)
			return
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		if workspace_edit_flow.is_free_view_drag_active():
			_handle_free_view_drag_motion(motion_event.relative)
			return
		_update_stage2_selection_hover(motion_event.position)

func _update_stage2_brush_hover(screen_position: Vector2) -> void:
	if not stage2_refinement_mode_active or not is_instance_valid(free_workspace_preview):
		return
	var current_wip: CraftedItemWIP = forge_controller.active_wip if forge_controller != null else null
	var hit_data: Dictionary = free_workspace_preview.resolve_stage2_brush_hit(screen_position, current_wip)
	if hit_data.is_empty():
		free_workspace_preview.clear_stage2_brush_preview()
		return
	var brush_blocked: bool = stage2_brush_presenter.is_zone_mask_blocked(
		StringName(hit_data.get("zone_mask_id", StringName())),
		active_tool
	)
	free_workspace_preview.set_stage2_brush_preview_hit(
		hit_data.get("hit_point_canonical_local", null),
		stage2_brush_radius_meters,
		brush_blocked
	)

func _apply_stage2_brush_at_screen_position(screen_position: Vector2) -> void:
	if not stage2_refinement_mode_active or forge_controller == null or not is_instance_valid(free_workspace_preview):
		return
	var current_wip: CraftedItemWIP = forge_controller.active_wip
	if current_wip == null or current_wip.stage2_item_state == null:
		return
	var hit_data: Dictionary = free_workspace_preview.resolve_stage2_brush_hit(screen_position, current_wip)
	if hit_data.is_empty():
		free_workspace_preview.clear_stage2_brush_preview()
		return
	var hit_point_canonical_local: Variant = hit_data.get("hit_point_canonical_local", null)
	var brush_blocked: bool = stage2_brush_presenter.is_zone_mask_blocked(
		StringName(hit_data.get("zone_mask_id", StringName())),
		active_tool
	)
	free_workspace_preview.set_stage2_brush_preview_hit(
		hit_point_canonical_local,
		stage2_brush_radius_meters,
		brush_blocked
	)
	if stage2_brush_presenter.apply_brush(
		current_wip.stage2_item_state,
		active_tool,
		hit_point_canonical_local,
		stage2_brush_radius_meters,
		_get_stage2_brush_step_meters()
	):
		forge_controller.clear_active_baked_profile()
		forge_controller.clear_active_test_print()
		_refresh_workspace_visuals(true, false)
		_refresh_status_text()

func _update_stage2_selection_hover(screen_position: Vector2) -> void:
	if not stage2_refinement_mode_active or not is_instance_valid(free_workspace_preview):
		return
	var current_wip: CraftedItemWIP = forge_controller.active_wip if forge_controller != null else null
	var hit_data: Dictionary = free_workspace_preview.resolve_stage2_brush_hit(screen_position, current_wip)
	var hover_selection_data: Dictionary = stage2_selection_presenter.resolve_hover_selection_data(
		current_wip.stage2_item_state if current_wip != null else null,
		hit_data,
		active_tool
	)
	stage2_hover_patch_ids = PackedStringArray(hover_selection_data.get("patch_ids", PackedStringArray()))
	_refresh_stage2_selection_preview()

func _toggle_stage2_patch_selection_at_screen_position(screen_position: Vector2) -> void:
	if not stage2_refinement_mode_active or not is_instance_valid(free_workspace_preview):
		return
	var current_wip: CraftedItemWIP = forge_controller.active_wip if forge_controller != null else null
	var hit_data: Dictionary = free_workspace_preview.resolve_stage2_brush_hit(screen_position, current_wip)
	var hover_selection_data: Dictionary = stage2_selection_presenter.resolve_hover_selection_data(
		current_wip.stage2_item_state if current_wip != null else null,
		hit_data,
		active_tool
	)
	var hovered_patch_ids: PackedStringArray = PackedStringArray(hover_selection_data.get("patch_ids", PackedStringArray()))
	stage2_hover_patch_ids = hovered_patch_ids
	stage2_selected_patch_ids = stage2_selection_presenter.toggle_patch_selection(stage2_selected_patch_ids, hovered_patch_ids)
	_rebuild_geometry_menu()
	_refresh_stage2_selection_preview()

func _apply_stage2_selection_tool() -> void:
	if (
		not stage2_refinement_mode_active
		or forge_controller == null
		or forge_controller.active_wip == null
		or forge_controller.active_wip.stage2_item_state == null
		or not _is_stage2_selection_tool(active_tool)
		or stage2_selected_patch_ids.is_empty()
	):
		return
	var selection_apply_patch_ids: PackedStringArray = stage2_selection_presenter.resolve_selection_apply_patch_ids(
		forge_controller.active_wip.stage2_item_state,
		stage2_selected_patch_ids,
		active_tool
	)
	if selection_apply_patch_ids.is_empty():
		return
	if stage2_brush_presenter.apply_selection_tool(
		forge_controller.active_wip.stage2_item_state,
		stage2_selected_patch_ids,
		active_tool,
		selection_apply_patch_ids
	):
		forge_controller.clear_active_baked_profile()
		forge_controller.clear_active_test_print()
		_refresh_workspace_visuals(true, false)
		_refresh_status_text()

func _clear_stage2_selection() -> void:
	stage2_hover_patch_ids = PackedStringArray()
	stage2_selected_patch_ids = stage2_selection_presenter.clear_selection()
	_rebuild_geometry_menu()
	_refresh_stage2_selection_preview()

func _on_action_menu_id_pressed(action_id: int) -> void:
	var menu_ids: Dictionary = _get_action_menu_ids()
	if action_id == int(menu_ids.get("geometry_selection_apply", -1)):
		_apply_stage2_selection_tool()
		return
	if action_id == int(menu_ids.get("geometry_selection_clear", -1)):
		_clear_stage2_selection()
		return
	var menu_state: Dictionary = bench_menu_presenter.handle_action_menu_id_pressed(
		action_id,
		menu_ids,
		show_grid_bounds,
		show_active_slice,
		Callable(self, "_fit_free_workspace_preview"),
		Callable(self, "_refresh_plane_and_preview"),
		Callable(self, "_set_active_tool"),
		Callable(self, "_step_structural_shape_rotation"),
		Callable(self, "_set_active_plane"),
		Callable(self, "_step_layer"),
		Callable(self, "_open_project_manager_popup"),
		Callable(self, "_save_current_wip_to_player_library"),
		Callable(self, "_create_new_blank_project"),
		Callable(self, "_load_selected_project_from_list"),
		Callable(self, "_resume_last_saved_project"),
		Callable(self, "_duplicate_current_project"),
		Callable(self, "_delete_current_project"),
		Callable(self, "_show_start_menu_from_editor"),
		Callable(self, "_bake_active_wip"),
		Callable(self, "_initialize_stage2_for_active_wip"),
		Callable(self, "_toggle_stage2_refinement_mode"),
		Callable(self, "_reset_active_wip"),
		Callable(self, "close_ui")
	)
	show_grid_bounds = bool(menu_state.get("show_grid_bounds", show_grid_bounds))
	show_active_slice = bool(menu_state.get("show_active_slice", show_active_slice))

func _fit_free_workspace_preview() -> void:
	if is_instance_valid(free_workspace_preview):
		free_workspace_preview.fit_view()

func _open_project_manager_popup() -> void:
	_refresh_project_panel()
	project_manager_popup.popup_centered(Vector2i(620, 760))

func _get_selected_project_catalog_entry() -> Dictionary:
	if project_list.get_selected_items().is_empty():
		return {}
	var selected_index: int = project_list.get_selected_items()[0]
	if selected_index < 0 or selected_index >= project_catalog.size():
		return {}
	return project_catalog[selected_index]

func _autosave_current_wip_if_needed() -> bool:
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	var result: Dictionary = project_action_presenter.autosave_current_project_if_needed(
		forge_controller,
		wip_library,
		project_name_edit.text,
		project_notes_edit.text,
		_get_selected_project_stow_position(),
		_get_selected_project_grip_style(),
		_build_default_forge_project_name(),
		Callable(self, "_get_default_layer_for_plane"),
		active_plane
	)
	return project_action_presenter.apply_project_action_result_to_layer(
		result,
		active_layer,
		Callable(self, "_refresh_all"),
		Callable(self, "_set_active_layer_value"),
		false
	)

func _load_project_catalog_entry(entry: Dictionary, autosave_first: bool = true) -> bool:
	if entry.is_empty():
		return false
	if autosave_first:
		_autosave_current_wip_if_needed()
	var entry_type: StringName = entry.get("entry_type", &"")
	if entry_type == &"authoring_preset":
		_load_sample_preset(entry.get("sample_preset_id", &""), false)
		return true
	if entry_type == &"saved":
		return _load_saved_wip_by_id(entry.get("saved_wip_id", &""), false)
	return false

func _load_sample_preset(sample_preset_id: StringName, autosave_first: bool = true) -> void:
	if autosave_first:
		_autosave_current_wip_if_needed()
	var result: Dictionary = project_action_presenter.load_sample_preset(
		forge_controller,
		sample_preset_id,
		Callable(self, "_get_default_layer_for_plane"),
		active_plane
	)
	project_action_presenter.apply_project_action_result_to_layer(
		result,
		active_layer,
		Callable(self, "_refresh_all"),
		Callable(self, "_set_active_layer_value"),
		false
	)

func _create_new_blank_project() -> void:
	_create_new_blank_project_for_builder_path(
		_get_current_builder_path_id(),
		_get_current_builder_component_id()
	)

func _create_new_blank_project_for_builder_path(
	builder_path_id: StringName,
	builder_component_id: StringName = StringName()
) -> void:
	_autosave_current_wip_if_needed()
	project_manager_popup.hide()
	var result: Dictionary = project_action_presenter.create_new_blank_project_for_builder_path(
		forge_controller,
		_build_default_forge_project_name(),
		builder_path_id,
		Callable(self, "_get_default_layer_for_plane"),
		active_plane,
		builder_component_id
	)
	project_action_presenter.apply_project_action_result_to_layer(
		result,
		active_layer,
		Callable(self, "_refresh_all"),
		Callable(self, "_set_active_layer_value"),
		false
	)
	if not result.is_empty():
		_show_editor_surface_for_current_wip()

func _save_current_wip_to_player_library() -> void:
	project_manager_popup.hide()
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	var result: Dictionary = project_action_presenter.save_current_project(
		forge_controller,
		wip_library,
		project_name_edit.text,
		project_notes_edit.text,
		_get_selected_project_stow_position(),
		_get_selected_project_grip_style(),
		_build_default_forge_project_name(),
		Callable(self, "_get_default_layer_for_plane"),
		active_plane
	)
	project_action_presenter.apply_project_action_result_to_layer(
		result,
		active_layer,
		Callable(self, "_refresh_all"),
		Callable(self, "_set_active_layer_value"),
		false
	)

func _load_selected_project_from_list() -> void:
	var entry: Dictionary = _get_selected_project_catalog_entry()
	if entry.is_empty():
		return
	project_manager_popup.hide()
	_load_project_catalog_entry(entry)

func _resume_last_saved_project() -> void:
	project_manager_popup.hide()
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	var target_saved_wip_id: StringName = StringName()
	if wip_library != null:
		target_saved_wip_id = wip_library.selected_wip_id
		if target_saved_wip_id == StringName():
			for saved_wip: CraftedItemWIP in wip_library.get_saved_wips():
				if saved_wip != null:
					target_saved_wip_id = saved_wip.wip_id
					break
	if target_saved_wip_id != StringName():
		_load_saved_wip_by_id(target_saved_wip_id)
		return
	var result: Dictionary = _restore_preferred_player_project_if_available(true)
	project_action_presenter.apply_project_action_result_to_layer(
		result,
		active_layer,
		Callable(self, "_refresh_all"),
		Callable(self, "_set_active_layer_value"),
		false
	)

func _restore_preferred_player_project_if_available(force_reload: bool = false) -> Dictionary:
	var result: Dictionary = project_action_presenter.restore_preferred_project(
		forge_controller,
		_get_player_forge_wip_library_state(),
		Callable(self, "_get_default_layer_for_plane"),
		active_plane,
		force_reload
	)
	if result.is_empty():
		return {}
	active_layer = int(result.get("active_layer", active_layer))
	return result

func _load_saved_wip_by_id(saved_wip_id: StringName, autosave_first: bool = true) -> bool:
	if autosave_first:
		_autosave_current_wip_if_needed()
	var result: Dictionary = project_action_presenter.load_saved_project_by_id(
		saved_wip_id,
		forge_controller,
		_get_player_forge_wip_library_state(),
		Callable(self, "_get_default_layer_for_plane"),
		active_plane
	)
	return project_action_presenter.apply_project_action_result_to_layer(
		result,
		active_layer,
		Callable(self, "_refresh_all"),
		Callable(self, "_set_active_layer_value"),
		false
	)

func _bake_active_wip() -> void:
	if not project_action_presenter.bake_active_wip(forge_controller):
		return
	_refresh_all()

func _initialize_stage2_for_active_wip() -> void:
	if not project_action_presenter.initialize_stage2_refinement(forge_controller):
		return
	stage2_brush_radius_meters = _clamp_stage2_pointer_tool_radius_meters(
		_get_view_tuning().workspace_stage2_default_brush_radius_meters
	)
	_refresh_all()

func _reset_active_wip() -> void:
	var result: Dictionary = project_action_presenter.reset_active_project(
		forge_controller,
		_get_player_forge_wip_library_state(),
		_build_default_forge_project_name(),
		Callable(self, "_get_default_layer_for_plane"),
		active_plane
	)
	project_action_presenter.apply_project_action_result_to_layer(
		result,
		active_layer,
		Callable(self, "_refresh_all"),
		Callable(self, "_set_active_layer_value"),
		false
	)

func _place_material_cell(grid_position: Vector3i) -> void:
	suppress_active_wip_refresh = true
	var result: Dictionary = workspace_edit_action_presenter.place_material_cell(
		forge_controller,
		_get_player_forge_inventory_state(),
		armed_material_variant_id,
		grid_position,
		Callable(self, "_ensure_wip_for_editing")
	)
	suppress_active_wip_refresh = false
	if bool(result.get("debug_status_dirty", false)):
		debug_status_dirty = true
	if bool(result.get("queue_edit_refresh", false)):
		_refresh_after_edit()

func _remove_cell(grid_position: Vector3i) -> void:
	suppress_active_wip_refresh = true
	var result: Dictionary = workspace_edit_action_presenter.remove_cell(
		forge_controller,
		_get_player_forge_inventory_state(),
		grid_position
	)
	suppress_active_wip_refresh = false
	if bool(result.get("queue_edit_refresh", false)):
		_refresh_after_edit()

func _begin_free_view_paint() -> void:
	workspace_interaction_presenter.begin_free_view_paint(workspace_edit_flow)

func _end_free_view_paint() -> void:
	workspace_interaction_presenter.end_free_view_paint(
		workspace_edit_flow,
		Callable(self, "_flush_pending_edit_refresh")
	)

func _paint_free_view_at_screen_position(screen_position: Vector2) -> void:
	workspace_interaction_presenter.paint_free_view_at_screen_position_state(
		workspace_edit_flow,
		screen_position,
		forge_controller,
		free_workspace_preview,
		active_tool,
		TOOL_ERASE,
		Callable(self, "_place_material_cell"),
		Callable(self, "_remove_cell")
	)

func _pick_material_from_grid(grid_position: Vector3i) -> void:
	var result: Dictionary = workspace_edit_action_presenter.pick_material_from_grid(
		forge_controller,
		material_catalog,
		grid_position
	)
	var pick_state: Dictionary = bench_refresh_presenter.apply_material_selection_state(
		result,
		selected_material_variant_id,
		armed_material_variant_id,
		Callable(self, "_refresh_inventory"),
		Callable(self, "_refresh_material_panels"),
		Callable(self, "_refresh_left_panel"),
		Callable(self, "_refresh_status_text")
	)
	if not bool(pick_state.get("applied", false)):
		return
	selected_material_variant_id = pick_state.get("selected_material_variant_id", StringName())
	armed_material_variant_id = pick_state.get("armed_material_variant_id", StringName())

func _pick_material_from_screen_position(screen_position: Vector2) -> void:
	var result: Dictionary = workspace_edit_action_presenter.pick_material_from_screen_position(
		free_workspace_preview,
		forge_controller,
		material_catalog,
		screen_position
	)
	var pick_state: Dictionary = bench_refresh_presenter.apply_material_selection_state(
		result,
		selected_material_variant_id,
		armed_material_variant_id,
		Callable(self, "_refresh_inventory"),
		Callable(self, "_refresh_material_panels"),
		Callable(self, "_refresh_left_panel"),
		Callable(self, "_refresh_status_text")
	)
	if not bool(pick_state.get("applied", false)):
		return
	selected_material_variant_id = pick_state.get("selected_material_variant_id", StringName())
	armed_material_variant_id = pick_state.get("armed_material_variant_id", StringName())

func _ensure_wip_for_editing() -> CraftedItemWIP:
	return project_action_presenter.ensure_wip_for_editing(
		forge_controller,
		_get_player_forge_wip_library_state()
	)

func _collect_wip_cells(wip: CraftedItemWIP) -> Array[CellAtom]:
	return workspace_presentation.collect_wip_cells(wip)

func _get_material_entry(material_id: StringName) -> Dictionary:
	return material_catalog_presenter.get_material_entry(material_catalog, material_id)

func _get_default_layer_for_plane(plane_id: StringName) -> int:
	return workspace_plane_presenter.get_default_layer_for_plane(
		forge_controller,
		plane_id,
		PLANE_ZX,
		PLANE_ZY
	)

func _get_max_layer_for_plane(plane_id: StringName) -> int:
	return workspace_plane_presenter.get_max_layer_for_plane(
		forge_controller,
		plane_id,
		PLANE_ZX,
		PLANE_ZY
	)

func _format_sample_preset(sample_preset_id: StringName) -> String:
	return project_action_presenter.format_sample_preset_name(forge_controller, sample_preset_id)

func _get_selected_material_display_name() -> String:
	return material_catalog_presenter.get_selected_display_name(material_catalog, selected_material_variant_id)

func _get_armed_material_display_name() -> String:
	return material_catalog_presenter.get_armed_display_name(material_catalog, armed_material_variant_id)

func _get_active_project_display_name(current_wip: CraftedItemWIP) -> String:
	return project_action_presenter.resolve_active_project_display_name(current_wip, forge_controller)

func _get_forge_project_name(current_wip: CraftedItemWIP) -> String:
	return project_action_presenter.resolve_editor_project_name(
		current_wip,
		forge_controller,
		_get_player_forge_wip_library_state()
	)

func _format_saved_wip_name(saved_wip: CraftedItemWIP) -> String:
	return project_action_presenter.format_saved_project_name(saved_wip)

func _get_project_source_text(current_wip: CraftedItemWIP) -> String:
	return project_action_presenter.resolve_project_source_text(
		current_wip,
		forge_controller,
		_get_player_forge_wip_library_state()
	)

func _build_default_forge_project_name() -> String:
	return project_action_presenter.build_default_project_name(_get_player_forge_wip_library_state())

func _apply_project_metadata_from_editor() -> void:
	project_action_presenter.apply_current_project_metadata_from_editor(
		forge_controller,
		_get_player_forge_wip_library_state(),
		project_name_edit.text,
		project_notes_edit.text,
		_get_selected_project_stow_position(),
		_get_selected_project_grip_style()
	)

func _duplicate_current_project() -> void:
	project_manager_popup.hide()
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	var result: Dictionary = project_action_presenter.duplicate_current_project(
		forge_controller,
		wip_library,
		project_name_edit.text,
		project_notes_edit.text,
		_get_selected_project_stow_position(),
		_get_selected_project_grip_style(),
		_build_default_forge_project_name(),
		Callable(self, "_get_default_layer_for_plane"),
		active_plane
	)
	project_action_presenter.apply_project_action_result_to_layer(
		result,
		active_layer,
		Callable(self, "_refresh_all"),
		Callable(self, "_set_active_layer_value"),
		false
	)

func _delete_current_project() -> void:
	project_manager_popup.hide()
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	var result: Dictionary = project_action_presenter.delete_current_project(
		forge_controller,
		wip_library,
		_build_default_forge_project_name(),
		Callable(self, "_get_default_layer_for_plane"),
		active_plane
	)
	project_action_presenter.apply_project_action_result_to_layer(
		result,
		active_layer,
		Callable(self, "_refresh_all"),
		Callable(self, "_set_active_layer_value"),
		false
	)

func _on_start_menu_continue_last_pressed() -> void:
	var result: Dictionary = _restore_preferred_player_project_if_available(true)
	if project_action_presenter.apply_project_action_result_to_layer(
		result,
		active_layer,
		Callable(self, "_refresh_all"),
		Callable(self, "_set_active_layer_value"),
		false
	):
		_show_editor_surface_for_current_wip()

func _on_start_menu_project_list_pressed() -> void:
	_show_editor_surface_for_current_wip()
	_refresh_project_panel()
	_refresh_status_text()
	_open_project_manager_popup()

func _on_start_menu_new_melee_pressed() -> void:
	_create_new_blank_project_for_builder_path(CraftedItemWIP.BUILDER_PATH_MELEE)

func _on_start_menu_new_ranged_physical_pressed() -> void:
	_create_new_blank_project_for_builder_path(
		CraftedItemWIP.BUILDER_PATH_RANGED_PHYSICAL,
		CraftedItemWIP.BUILDER_COMPONENT_BOW
	)

func _on_start_menu_new_shield_pressed() -> void:
	_create_new_blank_project_for_builder_path(CraftedItemWIP.BUILDER_PATH_SHIELD)

func _on_start_menu_new_magic_pressed() -> void:
	_create_new_blank_project_for_builder_path(CraftedItemWIP.BUILDER_PATH_MAGIC)

func _on_new_project_pressed() -> void:
	_create_new_blank_project()

func _on_builder_component_bow_pressed() -> void:
	_open_ranged_builder_component(CraftedItemWIP.BUILDER_COMPONENT_BOW)

func _on_builder_component_quiver_pressed() -> void:
	_open_ranged_builder_component(CraftedItemWIP.BUILDER_COMPONENT_QUIVER)

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

func _commit_project_metadata_if_visible() -> void:
	project_panel_presenter.commit_project_metadata_if_visible(
		panel.visible,
		Callable(self, "_apply_project_metadata_from_editor"),
		Callable(self, "_refresh_project_panel"),
		Callable(self, "_refresh_status_text")
	)

func _on_project_name_submitted(_new_text: String) -> void:
	_commit_project_metadata_if_visible()

func _on_project_name_focus_exited() -> void:
	_commit_project_metadata_if_visible()

func _on_project_stow_position_selected(_index: int) -> void:
	_commit_project_metadata_if_visible()

func _on_project_grip_style_selected(_index: int) -> void:
	_commit_project_metadata_if_visible()

func _on_stow_position_popup_id_focused(focused_id: int) -> void:
	project_panel_presenter.handle_stow_position_popup_focus(
		focused_id,
		project_stow_position_option_button,
		Callable(self, "_show_stow_position_hint"),
		Callable(self, "_hide_stow_position_hint")
	)

func _on_grip_style_popup_id_focused(focused_id: int) -> void:
	project_panel_presenter.handle_grip_style_popup_focus(
		focused_id,
		project_grip_style_option_button,
		Callable(self, "_show_grip_style_hint"),
		Callable(self, "_hide_grip_style_hint")
	)

func _on_project_notes_focus_exited() -> void:
	_commit_project_metadata_if_visible()

func _on_project_list_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	project_panel_presenter.handle_project_list_item_clicked(
		index,
		project_catalog,
		project_list,
		Callable(self, "_load_selected_project_from_list")
	)

func _on_project_list_item_selected(_index: int) -> void:
	project_action_presenter.apply_project_action_button_state(
		project_list,
		_ensure_wip_for_editing(),
		_get_player_forge_wip_library_state(),
		load_project_button,
		resume_last_project_button,
		save_project_button,
		duplicate_project_button,
		delete_project_button
	)
	_rebuild_project_menu()

func _on_active_wip_changed(_wip: CraftedItemWIP) -> void:
	if stage2_refinement_mode_active and not _can_enter_stage2_refinement_mode():
		_set_stage2_refinement_mode(false, false)
	if not start_menu_visible:
		_show_editor_surface_for_current_wip()
	bench_debug_presenter.handle_active_wip_changed(
		panel.visible,
		suppress_active_wip_refresh,
		Callable(self, "_refresh_all")
	)

func _on_active_test_print_changed(_test_print: TestPrintInstance) -> void:
	if not bench_debug_presenter.handle_active_test_print_changed(
		panel.visible,
		debug_popup.visible,
		Callable(self, "_refresh_status_text")
	):
		return
	debug_status_dirty = true

func _get_player_forge_inventory_state() -> PlayerForgeInventoryState:
	if active_player == null:
		return null
	return active_player.get_forge_inventory_state()

func _get_player_forge_wip_library_state() -> PlayerForgeWipLibraryState:
	if active_player == null:
		return null
	return active_player.get_forge_wip_library_state()

func _set_active_layer_value(next_active_layer: int) -> void:
	active_layer = next_active_layer

func _rebuild_workflow_menu() -> void:
	bench_menu_presenter.rebuild_workflow_menu(
		workflow_menu_button,
		_get_action_menu_ids(),
		_can_enter_stage2_refinement_mode(),
		stage2_refinement_mode_active
	)

func _get_action_menu_ids() -> Dictionary:
	return {
		"project_manager": MENU_PROJECT_MANAGER,
		"project_save": MENU_PROJECT_SAVE,
		"project_new": MENU_PROJECT_NEW,
		"project_load_selected": MENU_PROJECT_LOAD_SELECTED,
		"project_resume_last": MENU_PROJECT_RESUME_LAST,
		"project_duplicate": MENU_PROJECT_DUPLICATE,
		"project_delete": MENU_PROJECT_DELETE,
		"project_show_paths": MENU_PROJECT_SHOW_PATHS,
		"view_fit": MENU_VIEW_FIT,
		"view_toggle_bounds": MENU_VIEW_TOGGLE_BOUNDS,
		"view_toggle_slice": MENU_VIEW_TOGGLE_SLICE,
		"geometry_tool_place": MENU_GEOMETRY_TOOL_PLACE,
		"geometry_tool_erase": MENU_GEOMETRY_TOOL_ERASE,
		"geometry_tool_pick": MENU_GEOMETRY_TOOL_PICK,
		"geometry_tool_fillet": MENU_GEOMETRY_TOOL_FILLET,
		"geometry_tool_chamfer": MENU_GEOMETRY_TOOL_CHAMFER,
		"geometry_tool_surface_face_fillet": MENU_GEOMETRY_TOOL_SURFACE_FACE_FILLET,
		"geometry_tool_surface_face_chamfer": MENU_GEOMETRY_TOOL_SURFACE_FACE_CHAMFER,
		"geometry_tool_surface_face_restore": MENU_GEOMETRY_TOOL_SURFACE_FACE_RESTORE,
		"geometry_tool_surface_edge_fillet": MENU_GEOMETRY_TOOL_SURFACE_EDGE_FILLET,
		"geometry_tool_surface_edge_chamfer": MENU_GEOMETRY_TOOL_SURFACE_EDGE_CHAMFER,
		"geometry_tool_surface_edge_restore": MENU_GEOMETRY_TOOL_SURFACE_EDGE_RESTORE,
		"geometry_tool_surface_feature_edge_fillet": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_EDGE_FILLET,
		"geometry_tool_surface_feature_edge_chamfer": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_EDGE_CHAMFER,
		"geometry_tool_surface_feature_edge_restore": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_EDGE_RESTORE,
		"geometry_tool_surface_feature_region_fillet": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_REGION_FILLET,
		"geometry_tool_surface_feature_region_chamfer": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_REGION_CHAMFER,
		"geometry_tool_surface_feature_loop_fillet": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_LOOP_FILLET,
		"geometry_tool_surface_feature_loop_chamfer": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_LOOP_CHAMFER,
		"geometry_tool_surface_feature_region_restore": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_REGION_RESTORE,
		"geometry_tool_surface_feature_loop_restore": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_LOOP_RESTORE,
		"geometry_tool_surface_feature_band_fillet": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_BAND_FILLET,
		"geometry_tool_surface_feature_band_chamfer": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_BAND_CHAMFER,
		"geometry_tool_surface_feature_band_restore": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_BAND_RESTORE,
		"geometry_tool_surface_feature_cluster_fillet": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_CLUSTER_FILLET,
		"geometry_tool_surface_feature_cluster_chamfer": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_CLUSTER_CHAMFER,
		"geometry_tool_surface_feature_cluster_restore": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_CLUSTER_RESTORE,
		"geometry_tool_surface_feature_bridge_fillet": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_BRIDGE_FILLET,
		"geometry_tool_surface_feature_bridge_chamfer": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_BRIDGE_CHAMFER,
		"geometry_tool_surface_feature_bridge_restore": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_BRIDGE_RESTORE,
		"geometry_tool_surface_feature_contour_fillet": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_CONTOUR_FILLET,
		"geometry_tool_surface_feature_contour_chamfer": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_CONTOUR_CHAMFER,
		"geometry_tool_surface_feature_contour_restore": MENU_GEOMETRY_TOOL_SURFACE_FEATURE_CONTOUR_RESTORE,
		"geometry_tool_rectangle_place": MENU_GEOMETRY_TOOL_RECTANGLE_PLACE,
		"geometry_tool_rectangle_erase": MENU_GEOMETRY_TOOL_RECTANGLE_ERASE,
		"geometry_tool_circle_place": MENU_GEOMETRY_TOOL_CIRCLE_PLACE,
		"geometry_tool_circle_erase": MENU_GEOMETRY_TOOL_CIRCLE_ERASE,
		"geometry_tool_oval_place": MENU_GEOMETRY_TOOL_OVAL_PLACE,
		"geometry_tool_oval_erase": MENU_GEOMETRY_TOOL_OVAL_ERASE,
		"geometry_tool_triangle_place": MENU_GEOMETRY_TOOL_TRIANGLE_PLACE,
		"geometry_tool_triangle_erase": MENU_GEOMETRY_TOOL_TRIANGLE_ERASE,
		"geometry_shape_rotate_left": MENU_GEOMETRY_SHAPE_ROTATE_LEFT,
		"geometry_shape_rotate_right": MENU_GEOMETRY_SHAPE_ROTATE_RIGHT,
		"geometry_selection_apply": MENU_GEOMETRY_SELECTION_APPLY,
		"geometry_selection_clear": MENU_GEOMETRY_SELECTION_CLEAR,
		"geometry_plane_xy": MENU_GEOMETRY_PLANE_XY,
		"geometry_plane_zx": MENU_GEOMETRY_PLANE_ZX,
		"geometry_plane_zy": MENU_GEOMETRY_PLANE_ZY,
		"geometry_layer_down": MENU_GEOMETRY_LAYER_DOWN,
		"geometry_layer_up": MENU_GEOMETRY_LAYER_UP,
		"workflow_bake": MENU_WORKFLOW_BAKE,
		"workflow_stage2_initialize": MENU_WORKFLOW_STAGE2_INITIALIZE,
		"workflow_stage2_toggle_mode": MENU_WORKFLOW_STAGE2_TOGGLE_MODE,
		"workflow_reset": MENU_WORKFLOW_RESET,
		"workflow_close": MENU_WORKFLOW_CLOSE,
	}

func _rebuild_project_menu() -> void:
	var button_state: Dictionary = project_action_presenter.build_project_action_button_state(
		project_list,
		forge_controller.active_wip if forge_controller != null else null,
		_get_player_forge_wip_library_state()
	)
	bench_menu_presenter.rebuild_project_menu(
		project_menu_button,
		_get_action_menu_ids(),
		button_state
	)

func _rebuild_status_menu() -> void:
	bench_menu_presenter.rebuild_status_menu(status_menu_button, last_left_panel_state)

func _rebuild_geometry_menu() -> void:
	bench_menu_presenter.rebuild_geometry_menu(
		geometry_menu_button,
		_get_action_menu_ids(),
		stage2_refinement_mode_active,
		active_tool,
		workspace_shape_tool_presenter.get_rotation_degrees(structural_shape_rotation_quadrant),
		not stage2_selected_patch_ids.is_empty(),
		not stage2_selected_patch_ids.is_empty()
	)

func _refresh_project_panel() -> void:
	var current_wip: CraftedItemWIP = _ensure_wip_for_editing()
	project_catalog = bench_refresh_presenter.refresh_project_panel(
		project_panel_presenter,
		project_action_presenter,
		forge_controller,
		current_wip,
		_get_player_forge_wip_library_state(),
		_get_view_tuning(),
		project_name_edit,
		project_notes_edit,
		project_stow_position_option_button,
		project_grip_style_option_button,
		project_source_label,
		new_project_button,
		builder_component_tabs,
		builder_component_bow_button,
		builder_component_quiver_button,
		project_list,
		load_project_button,
		resume_last_project_button,
		save_project_button,
		duplicate_project_button,
		delete_project_button,
		Callable(self, "_hide_stow_position_hint"),
		Callable(self, "_hide_grip_style_hint")
	)
	_rebuild_project_menu()

func _open_ranged_builder_component(builder_component_id: StringName) -> void:
	var current_wip: CraftedItemWIP = forge_controller.active_wip if forge_controller != null else null
	var current_is_same_ranged_component: bool = (
		current_wip != null
		and CraftedItemWIP.normalize_builder_path_id(current_wip.forge_builder_path_id) == CraftedItemWIP.BUILDER_PATH_RANGED_PHYSICAL
		and CraftedItemWIP.normalize_builder_component_id(current_wip.forge_builder_path_id, current_wip.forge_builder_component_id) == builder_component_id
	)
	if current_is_same_ranged_component:
		return
	_create_new_blank_project_for_builder_path(
		CraftedItemWIP.BUILDER_PATH_RANGED_PHYSICAL,
		builder_component_id
	)

func _begin_free_view_drag() -> void:
	workspace_interaction_presenter.begin_free_view_drag(
		workspace_edit_flow,
		get_viewport(),
		_get_view_tuning().workspace_capture_mouse_during_drag,
		_get_view_tuning().workspace_pan_modifier_keycode,
		Callable(self, "_end_free_view_paint")
	)

func _end_free_view_drag(restore_mouse_position: bool = true) -> void:
	workspace_interaction_presenter.end_free_view_drag(
		workspace_edit_flow,
		get_viewport(),
		_get_view_tuning().workspace_capture_mouse_during_drag,
		restore_mouse_position
	)

func _handle_free_view_drag_motion(relative: Vector2) -> void:
	workspace_interaction_presenter.handle_free_view_drag_motion_state(
		workspace_edit_flow,
		relative,
		free_workspace_preview,
		_get_view_tuning().workspace_pan_modifier_keycode
	)

func _get_workspace_orbit_mouse_button() -> MouseButton:
	return workspace_interaction_presenter.get_workspace_orbit_mouse_button(_get_view_tuning().workspace_orbit_mouse_button)

func _is_action_pressed_if_available(event: InputEvent, action_name: StringName) -> bool:
	return workspace_interaction_presenter.is_action_pressed_if_available(event, action_name)

func _is_initial_action_press(event: InputEvent, action_name: StringName) -> bool:
	return workspace_interaction_presenter.is_initial_action_press(event, action_name)

func _is_action_released_if_available(event: InputEvent, action_name: StringName) -> bool:
	return workspace_interaction_presenter.is_action_released_if_available(event, action_name)

func _begin_layer_hold(direction: int) -> void:
	workspace_interaction_presenter.begin_layer_hold(direction, layer_hold_repeat_delay_seconds)

func _clear_layer_hold() -> void:
	workspace_interaction_presenter.clear_layer_hold()

func _process_layer_hold_repeat(delta: float) -> void:
	workspace_interaction_presenter.process_layer_hold_repeat(
		delta,
		layer_hold_repeat_rate_hz,
		Callable(self, "_step_layer")
	)

func _get_view_tuning() -> ForgeViewTuningDef:
	return forge_view_tuning if forge_view_tuning != null else DEFAULT_FORGE_VIEW_TUNING_RESOURCE
