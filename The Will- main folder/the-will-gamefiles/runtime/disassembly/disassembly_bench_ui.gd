extends CanvasLayer
class_name DisassemblyBenchUI

signal closed

const SalvageServiceScript = preload("res://services/salvage_service.gd")
const MaterialPipelineServiceScript = preload("res://services/material_pipeline_service.gd")
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
var selected_item_ids: Array[StringName] = []
var current_preview_result
var material_lookup: Dictionary = {}
var layout_refresh_queued: bool = false

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
	selected_item_ids.clear()
	current_preview_result = null
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
	selected_item_ids.clear()
	current_preview_result = null
	if active_player != null and active_player.has_method("set_ui_mode_enabled"):
		active_player.call("set_ui_mode_enabled", false)
	active_player = null
	emit_signal("closed")

func is_open() -> bool:
	return panel.visible

func _refresh_all(footer_message: String = "") -> void:
	_prune_stale_selection()
	_refresh_inventory_list()
	_refresh_selected_list()
	_refresh_preview_state()
	_refresh_action_state()
	if not footer_message.is_empty():
		footer_status_label.text = footer_message
	_queue_layout_refresh()

func _refresh_inventory_list() -> void:
	inventory_list.clear()
	var body_inventory_state = _get_body_inventory_state()
	var available_items: Array[Resource] = salvage_service.call("get_available_disassembly_items", body_inventory_state)
	for stored_item: Resource in available_items:
		if stored_item == null:
			continue
		if selected_item_ids.has(stored_item.item_instance_id):
			continue
		var item_index: int = inventory_list.add_item(_format_stored_item_label(stored_item))
		inventory_list.set_item_metadata(item_index, stored_item.item_instance_id)
	if inventory_list.item_count == 0:
		inventory_list.add_item("No supported disassembly items in body inventory.")
		inventory_list.set_item_disabled(0, true)

func _refresh_selected_list() -> void:
	selected_list.clear()
	var body_inventory_state = _get_body_inventory_state()
	for item_instance_id: StringName in selected_item_ids:
		var stored_item = body_inventory_state.call("get_item", item_instance_id) if body_inventory_state != null else null
		if stored_item == null:
			continue
		var item_index: int = selected_list.add_item(_format_stored_item_label(stored_item))
		selected_list.set_item_metadata(item_index, item_instance_id)
	if selected_list.item_count == 0:
		selected_list.add_item("Nothing is currently queued for disassembly.")
		selected_list.set_item_disabled(0, true)

func _refresh_preview_state() -> void:
	output_preview_list.clear()
	var body_inventory_state = _get_body_inventory_state()
	current_preview_result = salvage_service.call("build_salvage_preview_from_inventory", body_inventory_state, selected_item_ids)
	var selected_stack_total: int = _get_selected_stack_total()
	var preview_total: int = 0

	if current_preview_result != null and current_preview_result.preview_valid:
		for material_stack: ForgeMaterialStack in current_preview_result.preview_material_stacks:
			if material_stack == null:
				continue
			preview_total += material_stack.quantity
			output_preview_list.add_item(_format_material_stack_label(material_stack))
		output_status_label.text = "Preview only. These processed materials do not exist yet and will only route into forge storage after confirmation."
	else:
		output_preview_list.add_item("No processed output preview yet.")
		output_preview_list.set_item_disabled(0, true)
		if current_preview_result != null and not current_preview_result.blocking_lines.is_empty():
			output_status_label.text = "\n".join(current_preview_result.blocking_lines)
		else:
			output_status_label.text = "Select items from the left list to preview the processed material output."

	var warning_lines: PackedStringArray = []
	warning_lines.append("Disassembly converts selected items into forge building materials.")
	warning_lines.append("The resulting materials are routed directly into forge storage and become non-tradable in this first slice.")
	warning_lines.append("This change is permanent and cannot be reverted.")
	warning_text_label.text = "\n".join(warning_lines)

	summary_label.text = "Selected item rows: %d\nSelected item quantity: %d\nProjected forge materials: %d" % [
		selected_item_ids.size(),
		selected_stack_total,
		preview_total,
	]

	var can_extract_blueprint: bool = current_preview_result != null and bool(current_preview_result.can_extract_blueprint)
	var can_select_skill: bool = current_preview_result != null and bool(current_preview_result.can_select_skill)
	extract_blueprint_button.visible = can_extract_blueprint
	select_skill_button.visible = can_select_skill
	extract_blueprint_button.disabled = not can_extract_blueprint
	select_skill_button.disabled = not can_select_skill
	optional_status_label.visible = not can_extract_blueprint and not can_select_skill
	optional_status_label.text = "No blueprint or chase-skill extraction options are available for the current selection."

func _refresh_action_state() -> void:
	var preview_valid: bool = current_preview_result != null and bool(current_preview_result.preview_valid)
	disassemble_button.disabled = not preview_valid or not irreversible_check_box.button_pressed
	clear_selection_button.disabled = selected_item_ids.is_empty()

func _prune_stale_selection() -> void:
	var body_inventory_state = _get_body_inventory_state()
	var valid_ids: Array[StringName] = []
	for item_instance_id: StringName in selected_item_ids:
		var stored_item = body_inventory_state.call("get_item", item_instance_id) if body_inventory_state != null else null
		if stored_item == null:
			continue
		valid_ids.append(item_instance_id)
	selected_item_ids = valid_ids

func _on_inventory_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if index < 0 or index >= inventory_list.item_count:
		return
	var item_instance_id = inventory_list.get_item_metadata(index)
	if item_instance_id == null:
		return
	var resolved_item_id: StringName = item_instance_id
	if resolved_item_id == StringName() or selected_item_ids.has(resolved_item_id):
		return
	selected_item_ids.append(resolved_item_id)
	irreversible_check_box.button_pressed = false
	_refresh_all("Item moved into the disassembly queue.")

func _on_selected_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if index < 0 or index >= selected_list.item_count:
		return
	var item_instance_id = selected_list.get_item_metadata(index)
	if item_instance_id == null:
		return
	var resolved_item_id: StringName = item_instance_id
	selected_item_ids.erase(resolved_item_id)
	irreversible_check_box.button_pressed = false
	_refresh_all("Item returned to body inventory and removed from the disassembly queue.")

func _on_irreversible_toggled(_enabled: bool) -> void:
	_refresh_action_state()
	if irreversible_check_box.button_pressed:
		footer_status_label.text = "Irreversible confirmation granted for the current preview."
	else:
		footer_status_label.text = "Disassembly remains blocked until the irreversible confirmation is checked."

func _on_clear_selection_pressed() -> void:
	selected_item_ids.clear()
	irreversible_check_box.button_pressed = false
	_refresh_all("Disassembly selection cleared.")

func _on_disassemble_pressed() -> void:
	var body_inventory_state = _get_body_inventory_state()
	var forge_inventory_state = _get_forge_inventory_state()
	var commit_result = salvage_service.call(
		"commit_salvage_preview",
		body_inventory_state,
		forge_inventory_state,
		current_preview_result,
		irreversible_check_box.button_pressed
	)
	if commit_result != null and bool(commit_result.commit_applied):
		var routed_quantity: int = int(commit_result.call("get_total_preview_quantity"))
		selected_item_ids.clear()
		irreversible_check_box.button_pressed = false
		_refresh_all("Disassembly committed. %d processed forge materials were routed into forge storage." % routed_quantity)
		return
	var failure_lines: PackedStringArray = []
	if commit_result != null and not commit_result.blocking_lines.is_empty():
		failure_lines = commit_result.blocking_lines
	var failure_text: String = "\n".join(failure_lines) if not failure_lines.is_empty() else "Disassembly could not be completed."
	_refresh_all(failure_text)

func _get_body_inventory_state():
	if active_player == null or not active_player.has_method("get_body_inventory_state"):
		return null
	return active_player.call("get_body_inventory_state")

func _get_forge_inventory_state():
	if active_player == null or not active_player.has_method("get_forge_inventory_state"):
		return null
	return active_player.call("get_forge_inventory_state")

func _refresh_material_lookup() -> void:
	material_lookup = material_pipeline_service.call("build_base_material_lookup")

func _format_stored_item_label(stored_item: Resource) -> String:
	if stored_item == null:
		return "Unknown Item"
	return "%s x%d" % [stored_item.get_resolved_display_name(), maxi(stored_item.stack_count, 1)]

func _format_material_stack_label(material_stack: ForgeMaterialStack) -> String:
	if material_stack == null:
		return "Unknown Material"
	return "%s x%d" % [_resolve_material_variant_display_name(material_stack.material_variant_id), material_stack.quantity]

func _resolve_material_variant_display_name(material_variant_id: StringName) -> String:
	var material_id_text: String = String(material_variant_id)
	if material_id_text.is_empty():
		return "Unknown Material"
	var tier_separator_index: int = material_id_text.rfind("_")
	var tier_display_name: String = ""
	if tier_separator_index > 0:
		tier_display_name = material_id_text.substr(tier_separator_index + 1).capitalize()
	var base_material_id: StringName = StringName("%s_base" % material_id_text.substr(0, tier_separator_index))
	var base_material: BaseMaterialDef = material_lookup.get(base_material_id) as BaseMaterialDef
	if base_material == null:
		return material_id_text
	if tier_display_name.is_empty():
		return base_material.display_name
	return "%s (%s)" % [base_material.display_name, tier_display_name]

func _get_selected_stack_total() -> int:
	var total: int = 0
	var body_inventory_state = _get_body_inventory_state()
	for item_instance_id: StringName in selected_item_ids:
		var stored_item = body_inventory_state.call("get_item", item_instance_id) if body_inventory_state != null else null
		if stored_item == null:
			continue
		total += maxi(stored_item.stack_count, 0)
	return total

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

	main_hbox.add_theme_constant_override("separation", compact_panel_separation if compact_mode else wide_panel_separation)
	inventory_panel.custom_minimum_size.x = compact_side_panel_min_width if compact_mode else wide_side_panel_min_width
	selected_panel.custom_minimum_size.x = compact_side_panel_min_width if compact_mode else wide_side_panel_min_width
	output_panel.custom_minimum_size.x = compact_center_panel_min_width if compact_mode else wide_center_panel_min_width

	var resolved_item_list_min_height: int = compact_item_list_min_height if compact_mode else wide_item_list_min_height
	inventory_list.custom_minimum_size.y = resolved_item_list_min_height
	selected_list.custom_minimum_size.y = resolved_item_list_min_height
	output_preview_list.custom_minimum_size.y = resolved_item_list_min_height
	warning_panel.custom_minimum_size.y = compact_warning_panel_min_height if compact_mode else wide_warning_panel_min_height

	var resolved_button_width: int = compact_action_button_min_width if compact_mode else wide_action_button_min_width
	var resolved_button_height: int = compact_action_button_min_height if compact_mode else wide_action_button_min_height
	disassemble_button.custom_minimum_size = Vector2(resolved_button_width, resolved_button_height)
	clear_selection_button.custom_minimum_size = Vector2(resolved_button_width, resolved_button_height)
	extract_blueprint_button.custom_minimum_size = Vector2(resolved_button_width, resolved_button_height)
	select_skill_button.custom_minimum_size = Vector2(resolved_button_width, resolved_button_height)
	close_button.custom_minimum_size = Vector2(compact_footer_button_min_width if compact_mode else wide_footer_button_min_width, resolved_button_height)
