extends CanvasLayer
class_name DisassemblyBenchUI

signal closed

const SalvageServiceScript = preload("res://services/salvage_service.gd")
const MaterialPipelineServiceScript = preload("res://services/material_pipeline_service.gd")
const DisassemblyBenchLayoutPresenterScript = preload("res://runtime/disassembly/disassembly_bench_layout_presenter.gd")
const DisassemblyBenchTextPresenterScript = preload("res://runtime/disassembly/disassembly_bench_text_presenter.gd")
const DisassemblyBenchWorkflowPresenterScript = preload("res://runtime/disassembly/disassembly_bench_workflow_presenter.gd")
const DEFAULT_BODY_INVENTORY_SEED_RESOURCE: Resource = preload("res://core/defs/inventory/body_inventory_seed_default.tres")

@export_category("Responsive Layout")
@export var compact_width_breakpoint: int = 1320
@export var compact_height_breakpoint: int = 760
@export_range(0.0, 0.12, 0.005) var wide_outer_margin_ratio: float = 0.02
@export_range(0.0, 0.12, 0.005) var compact_outer_margin_ratio: float = 0.015
@export var minimum_outer_margin_px: int = 12
@export var maximum_outer_margin_px: int = 36
@export var wide_panel_separation: int = 12
@export var compact_panel_separation: int = 8
@export var wide_side_panel_min_width: int = 280
@export var compact_side_panel_min_width: int = 220
@export var wide_center_panel_min_width: int = 360
@export var compact_center_panel_min_width: int = 260
@export var wide_item_list_min_height: int = 320
@export var compact_item_list_min_height: int = 180
@export var wide_warning_panel_min_height: int = 150
@export var compact_warning_panel_min_height: int = 110
@export var wide_action_button_min_width: int = 180
@export var compact_action_button_min_width: int = 132
@export var wide_action_button_min_height: int = 38
@export var compact_action_button_min_height: int = 32
@export var wide_footer_button_min_width: int = 150
@export var compact_footer_button_min_width: int = 120

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Panel
@onready var main_hbox: HBoxContainer = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox
@onready var inventory_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/InventoryPanel
@onready var output_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/OutputPanel
@onready var selected_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/SelectedPanel
@onready var title_label: Label = $Panel/MarginContainer/RootVBox/HeaderBox/TitleLabel
@onready var subtitle_label: Label = $Panel/MarginContainer/RootVBox/HeaderBox/SubtitleLabel
@onready var inventory_list: ItemList = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/InventoryPanel/MarginContainer/InventoryVBox/InventoryList
@onready var output_preview_list: ItemList = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/OutputPanel/MarginContainer/OutputVBox/OutputPreviewList
@onready var warning_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/OutputPanel/MarginContainer/OutputVBox/WarningPanel
@onready var warning_text_label: Label = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/OutputPanel/MarginContainer/OutputVBox/WarningPanel/MarginContainer/WarningVBox/WarningTextLabel
@onready var irreversible_check_box: CheckBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/OutputPanel/MarginContainer/OutputVBox/WarningPanel/MarginContainer/WarningVBox/IrreversibleCheckBox
@onready var disassemble_button: Button = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/OutputPanel/MarginContainer/OutputVBox/ActionRow/DisassembleButton
@onready var clear_selection_button: Button = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/OutputPanel/MarginContainer/OutputVBox/ActionRow/ClearSelectionButton
@onready var output_status_label: Label = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/OutputPanel/MarginContainer/OutputVBox/OutputStatusLabel
@onready var selected_list: ItemList = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/SelectedPanel/MarginContainer/SelectedVBox/SelectedList
@onready var summary_label: Label = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/SelectedPanel/MarginContainer/SelectedVBox/SummaryPanel/MarginContainer/SummaryVBox/SummaryLabel
@onready var optional_panel: PanelContainer = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/SelectedPanel/MarginContainer/SelectedVBox/OptionalPanel
@onready var optional_status_label: Label = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/SelectedPanel/MarginContainer/SelectedVBox/OptionalPanel/MarginContainer/OptionalVBox/OptionalStatusLabel
@onready var extract_blueprint_button: Button = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/SelectedPanel/MarginContainer/SelectedVBox/OptionalPanel/MarginContainer/OptionalVBox/OptionalActionRow/ExtractBlueprintButton
@onready var select_skill_button: Button = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/SelectedPanel/MarginContainer/SelectedVBox/OptionalPanel/MarginContainer/OptionalVBox/OptionalActionRow/SelectSkillButton
@onready var footer_status_label: Label = $Panel/MarginContainer/RootVBox/FooterRow/FooterStatusLabel
@onready var close_button: Button = $Panel/MarginContainer/RootVBox/FooterRow/CloseButton

var active_player
var salvage_service = SalvageServiceScript.new()
var material_pipeline_service = MaterialPipelineServiceScript.new()
var layout_refresh_queued: bool = false
var layout_presenter = DisassemblyBenchLayoutPresenterScript.new()
var text_presenter = DisassemblyBenchTextPresenterScript.new()
var workflow_presenter = DisassemblyBenchWorkflowPresenterScript.new()

func _ready() -> void:
	visible = false
	backdrop.visible = false
	panel.visible = false
	inventory_list.item_clicked.connect(_on_inventory_item_clicked)
	selected_list.item_clicked.connect(_on_selected_item_clicked)
	irreversible_check_box.toggled.connect(_on_irreversible_toggled)
	disassemble_button.pressed.connect(_on_disassemble_pressed)
	clear_selection_button.pressed.connect(_on_clear_selection_pressed)
	close_button.pressed.connect(close_ui)
	if not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	if not panel.resized.is_connected(_queue_layout_refresh):
		panel.resized.connect(_queue_layout_refresh)
	_refresh_material_lookup()
	_queue_layout_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close_ui()
		get_viewport().set_input_as_handled()

func toggle_for(player, bench_name: String) -> void:
	if panel.visible:
		close_ui()
		return
	open_for(player, bench_name)

func open_for(player, bench_name: String) -> void:
	active_player = player
	if active_player != null and active_player.has_method("ensure_body_inventory_seeded"):
		active_player.call("ensure_body_inventory_seeded", DEFAULT_BODY_INVENTORY_SEED_RESOURCE)
	if active_player != null and active_player.has_method("set_ui_mode_enabled"):
		active_player.call("set_ui_mode_enabled", true)
	title_label.text = "%s Disassembly Bench" % bench_name
	subtitle_label.text = "Move suitable body-inventory items into the disassembly list, review projected forge-material output, confirm the irreversible change, and route results directly into forge storage."
	workflow_presenter.reset_runtime_state()
	irreversible_check_box.button_pressed = false
	visible = true
	backdrop.visible = true
	panel.visible = true
	_refresh_all("Select suitable inventory items to prepare them for disassembly.")
	layout_refresh_queued = false
	_apply_responsive_layout()
	_queue_layout_refresh()

func close_ui() -> void:
	if not panel.visible:
		return
	panel.visible = false
	backdrop.visible = false
	visible = false
	irreversible_check_box.button_pressed = false
	workflow_presenter.reset_runtime_state()
	if active_player != null and active_player.has_method("set_ui_mode_enabled"):
		active_player.call("set_ui_mode_enabled", false)
	active_player = null
	emit_signal("closed")

func is_open() -> bool:
	return panel.visible

func _refresh_all(footer_message: String = "") -> void:
	workflow_presenter.refresh_all(
		_get_body_inventory_state(),
		salvage_service,
		text_presenter,
		_get_workflow_nodes(),
		footer_message
	)
	_queue_layout_refresh()

func _on_inventory_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	workflow_presenter.handle_inventory_item_clicked(
		index,
		_get_body_inventory_state(),
		salvage_service,
		text_presenter,
		_get_workflow_nodes()
	)
	_queue_layout_refresh()

func _on_selected_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	workflow_presenter.handle_selected_item_clicked(
		index,
		_get_body_inventory_state(),
		salvage_service,
		text_presenter,
		_get_workflow_nodes()
	)
	_queue_layout_refresh()

func _on_irreversible_toggled(_enabled: bool) -> void:
	workflow_presenter.handle_irreversible_toggled(_get_workflow_nodes())
	_queue_layout_refresh()

func _on_clear_selection_pressed() -> void:
	workflow_presenter.handle_clear_selection_pressed(
		_get_body_inventory_state(),
		salvage_service,
		text_presenter,
		_get_workflow_nodes()
	)
	_queue_layout_refresh()

func _on_disassemble_pressed() -> void:
	workflow_presenter.handle_disassemble_pressed(
		_get_body_inventory_state(),
		_get_forge_inventory_state(),
		salvage_service,
		text_presenter,
		_get_workflow_nodes()
	)
	_queue_layout_refresh()

func _get_body_inventory_state():
	if active_player == null or not active_player.has_method("get_body_inventory_state"):
		return null
	return active_player.call("get_body_inventory_state")

func _get_forge_inventory_state():
	if active_player == null or not active_player.has_method("get_forge_inventory_state"):
		return null
	return active_player.call("get_forge_inventory_state")

func _refresh_material_lookup() -> void:
	workflow_presenter.refresh_material_lookup(text_presenter, material_pipeline_service)

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
		_get_layout_config(),
		backdrop,
		panel,
		main_hbox,
		inventory_panel,
		output_panel,
		selected_panel,
		inventory_list,
		selected_list,
		output_preview_list,
		warning_panel,
		disassemble_button,
		clear_selection_button,
		extract_blueprint_button,
		select_skill_button,
		close_button
	)

func _get_layout_config() -> Dictionary:
	return {
		"compact_width_breakpoint": compact_width_breakpoint,
		"compact_height_breakpoint": compact_height_breakpoint,
		"wide_outer_margin_ratio": wide_outer_margin_ratio,
		"compact_outer_margin_ratio": compact_outer_margin_ratio,
		"minimum_outer_margin_px": minimum_outer_margin_px,
		"maximum_outer_margin_px": maximum_outer_margin_px,
		"wide_panel_separation": wide_panel_separation,
		"compact_panel_separation": compact_panel_separation,
		"wide_side_panel_min_width": wide_side_panel_min_width,
		"compact_side_panel_min_width": compact_side_panel_min_width,
		"wide_center_panel_min_width": wide_center_panel_min_width,
		"compact_center_panel_min_width": compact_center_panel_min_width,
		"wide_item_list_min_height": wide_item_list_min_height,
		"compact_item_list_min_height": compact_item_list_min_height,
		"wide_warning_panel_min_height": wide_warning_panel_min_height,
		"compact_warning_panel_min_height": compact_warning_panel_min_height,
		"wide_action_button_min_width": wide_action_button_min_width,
		"compact_action_button_min_width": compact_action_button_min_width,
		"wide_action_button_min_height": wide_action_button_min_height,
		"compact_action_button_min_height": compact_action_button_min_height,
		"wide_footer_button_min_width": wide_footer_button_min_width,
		"compact_footer_button_min_width": compact_footer_button_min_width,
	}

func _get_workflow_nodes() -> Dictionary:
	return {
		"inventory_list": inventory_list,
		"output_preview_list": output_preview_list,
		"warning_text_label": warning_text_label,
		"irreversible_check_box": irreversible_check_box,
		"disassemble_button": disassemble_button,
		"clear_selection_button": clear_selection_button,
		"output_status_label": output_status_label,
		"selected_list": selected_list,
		"summary_label": summary_label,
		"optional_status_label": optional_status_label,
		"extract_blueprint_button": extract_blueprint_button,
		"select_skill_button": select_skill_button,
		"footer_status_label": footer_status_label,
	}
