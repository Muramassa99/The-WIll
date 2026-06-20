extends CanvasLayer
class_name PlayerInventoryOverlay

signal closed

const InventoryStorageServiceScript = preload("res://services/inventory_storage_service.gd")
const MaterialPipelineServiceScript = preload("res://services/material_pipeline_service.gd")
const PlayerInventoryActionPresenterScript = preload("res://runtime/ui/player_inventory_action_presenter.gd")
const PlayerInventoryInteractionPresenterScript = preload("res://runtime/ui/player_inventory_interaction_presenter.gd")
const PlayerInventoryLayoutPresenterScript = preload("res://runtime/ui/player_inventory_layout_presenter.gd")
const PlayerInventoryNavigationPresenterScript = preload("res://runtime/ui/player_inventory_navigation_presenter.gd")
const PlayerInventoryPagePresenterScript = preload("res://runtime/ui/player_inventory_page_presenter.gd")
const PlayerInventoryRefreshPresenterScript = preload("res://runtime/ui/player_inventory_refresh_presenter.gd")
const PlayerInventorySelectionPresenterScript = preload("res://runtime/ui/player_inventory_selection_presenter.gd")
const PlayerInventorySessionPresenterScript = preload("res://runtime/ui/player_inventory_session_presenter.gd")
const PlayerInventorySurfacePresenterScript = preload("res://runtime/ui/player_inventory_surface_presenter.gd")
const PlayerInventoryTextPresenterScript = preload("res://runtime/ui/player_inventory_text_presenter.gd")
const DEFAULT_EQUIPMENT_SLOT_REGISTRY_RESOURCE: Resource = preload("res://core/defs/equipment/equipment_slot_registry_default.tres")

const PAGE_EQUIPMENT := &"equipment"
const PAGE_BODY_INVENTORY := &"inventory"
const PAGE_STORAGE := &"storage"
const PAGE_FORGE_MATERIALS := &"forge_materials"
const PAGE_WIP_STORAGE := &"wip_storage"

@export_category("Responsive Layout")
@export var compact_width_breakpoint: int = 1320
@export var compact_height_breakpoint: int = 760
@export_range(0.0, 0.12, 0.005) var wide_outer_margin_ratio: float = 0.02
@export_range(0.0, 0.12, 0.005) var compact_outer_margin_ratio: float = 0.015
@export var minimum_outer_margin_px: int = 12
@export var maximum_outer_margin_px: int = 36
@export var compact_page_button_min_width: int = 120
@export var wide_page_button_min_width: int = 150
@export var compact_action_button_min_width: int = 132
@export var wide_action_button_min_width: int = 180
@export var compact_action_button_min_height: int = 32
@export var wide_action_button_min_height: int = 38
@export var compact_item_list_min_height: int = 220
@export var wide_item_list_min_height: int = 360
@export var minimum_item_list_min_height: int = 150
@export_range(0.1, 0.6, 0.01) var compact_item_list_height_ratio: float = 0.22
@export_range(0.1, 0.6, 0.01) var wide_item_list_height_ratio: float = 0.32

@export var equipment_slot_registry: Resource = DEFAULT_EQUIPMENT_SLOT_REGISTRY_RESOURCE

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/MarginContainer/RootVBox/HeaderBox/TitleLabel
@onready var subtitle_label: Label = $Panel/MarginContainer/RootVBox/HeaderBox/SubtitleLabel
@onready var equipment_page_button: Button = $Panel/MarginContainer/RootVBox/PageButtonFlow/EquipmentPageButton
@onready var inventory_page_button: Button = $Panel/MarginContainer/RootVBox/PageButtonFlow/InventoryPageButton
@onready var storage_page_button: Button = $Panel/MarginContainer/RootVBox/PageButtonFlow/StoragePageButton
@onready var forge_materials_page_button: Button = $Panel/MarginContainer/RootVBox/PageButtonFlow/ForgeMaterialsPageButton
@onready var wip_page_button: Button = $Panel/MarginContainer/RootVBox/PageButtonFlow/WipPageButton
@onready var page_scroll: ScrollContainer = $Panel/MarginContainer/RootVBox/PageScroll
@onready var stacked_pages: TabContainer = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages
@onready var equipment_list: ItemList = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/EquipmentPage/MarginContainer/EquipmentVBox/EquipmentList
@onready var equipment_detail_label: Label = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/EquipmentPage/MarginContainer/EquipmentVBox/EquipmentDetailLabel
@onready var clear_slot_button: Button = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/EquipmentPage/MarginContainer/EquipmentVBox/ActionRow/ClearSlotButton
@onready var body_inventory_list: ItemList = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/BodyInventoryPage/MarginContainer/BodyInventoryVBox/BodyInventoryList
@onready var body_inventory_detail_label: Label = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/BodyInventoryPage/MarginContainer/BodyInventoryVBox/BodyInventoryDetailLabel
@onready var move_to_storage_button: Button = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/BodyInventoryPage/MarginContainer/BodyInventoryVBox/ActionRow/MoveToStorageButton
@onready var refresh_body_inventory_button: Button = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/BodyInventoryPage/MarginContainer/BodyInventoryVBox/ActionRow/RefreshBodyInventoryButton
@onready var storage_list: ItemList = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/StoragePage/MarginContainer/StorageVBox/StorageList
@onready var storage_detail_label: Label = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/StoragePage/MarginContainer/StorageVBox/StorageDetailLabel
@onready var move_to_inventory_button: Button = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/StoragePage/MarginContainer/StorageVBox/ActionRow/MoveToInventoryButton
@onready var refresh_storage_button: Button = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/StoragePage/MarginContainer/StorageVBox/ActionRow/RefreshStorageButton
@onready var forge_materials_list: ItemList = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/ForgeMaterialsPage/MarginContainer/ForgeMaterialsVBox/ForgeMaterialsList
@onready var forge_materials_summary_label: Label = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/ForgeMaterialsPage/MarginContainer/ForgeMaterialsVBox/ForgeMaterialsSummaryLabel
@onready var wip_list: ItemList = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/WipStoragePage/MarginContainer/WipVBox/WipList
@onready var wip_detail_label: Label = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/WipStoragePage/MarginContainer/WipVBox/WipDetailLabel
@onready var mark_for_forge_button: Button = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/WipStoragePage/MarginContainer/WipVBox/ActionRow/MarkForForgeButton
@onready var equip_right_hand_button: Button = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/WipStoragePage/MarginContainer/WipVBox/ActionRow/EquipRightHandButton
@onready var equip_left_hand_button: Button = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/WipStoragePage/MarginContainer/WipVBox/ActionRow/EquipLeftHandButton
@onready var clear_hand_test_button: Button = $Panel/MarginContainer/RootVBox/PageScroll/StackedPages/WipStoragePage/MarginContainer/WipVBox/ActionRow/ClearHandTestButton
@onready var footer_status_label: Label = $Panel/MarginContainer/RootVBox/FooterRow/FooterStatusLabel
@onready var close_button: Button = $Panel/MarginContainer/RootVBox/FooterRow/CloseButton

var inventory_storage_service = InventoryStorageServiceScript.new()
var material_pipeline_service = MaterialPipelineServiceScript.new()
var active_player
var active_page_id: StringName = PAGE_BODY_INVENTORY
var active_source_label: String = "Player Inventory"
var material_lookup: Dictionary = {}
var layout_refresh_queued: bool = false
var action_presenter = PlayerInventoryActionPresenterScript.new()
var interaction_presenter = PlayerInventoryInteractionPresenterScript.new()
var layout_presenter = PlayerInventoryLayoutPresenterScript.new()
var navigation_presenter = PlayerInventoryNavigationPresenterScript.new()
var page_presenter = PlayerInventoryPagePresenterScript.new()
var refresh_presenter = PlayerInventoryRefreshPresenterScript.new()
var selection_presenter = PlayerInventorySelectionPresenterScript.new()
var session_presenter = PlayerInventorySessionPresenterScript.new()
var surface_presenter = PlayerInventorySurfacePresenterScript.new()
var text_presenter = PlayerInventoryTextPresenterScript.new()

func _ready() -> void:
	visible = false
	backdrop.visible = false
	panel.visible = false
	_refresh_material_lookup()
	equipment_page_button.pressed.connect(func() -> void: _set_active_page(PAGE_EQUIPMENT))
	inventory_page_button.pressed.connect(func() -> void: _set_active_page(PAGE_BODY_INVENTORY))
	storage_page_button.pressed.connect(func() -> void: _set_active_page(PAGE_STORAGE))
	forge_materials_page_button.pressed.connect(func() -> void: _set_active_page(PAGE_FORGE_MATERIALS))
	wip_page_button.pressed.connect(func() -> void: _set_active_page(PAGE_WIP_STORAGE))
	equipment_list.item_clicked.connect(_on_equipment_item_clicked)
	body_inventory_list.item_clicked.connect(_on_body_inventory_item_clicked)
	storage_list.item_clicked.connect(_on_storage_item_clicked)
	wip_list.item_clicked.connect(_on_wip_item_clicked)
	clear_slot_button.pressed.connect(_on_clear_slot_pressed)
	move_to_storage_button.pressed.connect(_on_move_to_storage_pressed)
	refresh_body_inventory_button.pressed.connect(func() -> void: _refresh_all("Body inventory refreshed."))
	move_to_inventory_button.pressed.connect(_on_move_to_inventory_pressed)
	refresh_storage_button.pressed.connect(func() -> void: _refresh_all("Personal storage refreshed."))
	mark_for_forge_button.pressed.connect(_on_mark_for_forge_pressed)
	equip_right_hand_button.pressed.connect(func() -> void: _equip_selected_wip_to_hand(&"hand_right"))
	equip_left_hand_button.pressed.connect(func() -> void: _equip_selected_wip_to_hand(&"hand_left"))
	clear_hand_test_button.pressed.connect(_on_clear_hand_test_pressed)
	close_button.pressed.connect(close_overlay)
	if not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	if not panel.resized.is_connected(_queue_layout_refresh):
		panel.resized.connect(_queue_layout_refresh)
	_queue_layout_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"ui_cancel"):
		close_overlay()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_inventory"):
		if active_page_id == PAGE_BODY_INVENTORY:
			close_overlay()
		else:
			_set_active_page(PAGE_BODY_INVENTORY)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_character"):
		if active_page_id == PAGE_EQUIPMENT:
			close_overlay()
		else:
			_set_active_page(PAGE_EQUIPMENT)
		get_viewport().set_input_as_handled()

func toggle_page_for(player, page_id: StringName, source_label: String = "") -> void:
	if session_presenter.should_close_existing_page(
		is_open(),
		active_player,
		active_page_id,
		player,
		page_id
	):
		close_overlay()
		return
	open_page_for(player, page_id, source_label)

func open_page_for(player, page_id: StringName, source_label: String = "") -> void:
	var session_state: Dictionary = session_presenter.open_overlay(
		player,
		page_id,
		source_label,
		panel,
		backdrop
	)
	active_player = session_state.get("active_player", null)
	active_source_label = String(session_state.get("active_source_label", "Player Inventory"))
	visible = true
	_set_active_page(page_id)
	layout_refresh_queued = false
	_apply_responsive_layout()
	_queue_layout_refresh()

func close_overlay() -> void:
	var session_state: Dictionary = session_presenter.close_overlay(active_player, panel, backdrop)
	if not bool(session_state.get("closed", false)):
		return
	visible = false
	active_player = session_state.get("active_player", null)
	active_source_label = String(session_state.get("active_source_label", "Player Inventory"))
	emit_signal("closed")

func is_open() -> bool:
	return panel.visible

func set_selected_equipment_slot_id(slot_id: StringName) -> void:
	selection_presenter.set_selection_value(&"selected_equipment_slot_id", slot_id)

func set_selected_body_item_id(item_id: StringName) -> void:
	selection_presenter.set_selection_value(&"selected_body_item_id", item_id)

func set_selected_storage_item_id(item_id: StringName) -> void:
	selection_presenter.set_selection_value(&"selected_storage_item_id", item_id)

func set_selected_wip_id(wip_id: StringName) -> void:
	selection_presenter.set_selection_value(&"selected_wip_id", wip_id)

func _set_active_page(page_id: StringName) -> void:
	var page_state: Dictionary = navigation_presenter.resolve_page_state(
		page_id,
		PAGE_BODY_INVENTORY,
		surface_presenter.get_page_order(
			PAGE_EQUIPMENT,
			PAGE_BODY_INVENTORY,
			PAGE_STORAGE,
			PAGE_FORGE_MATERIALS,
			PAGE_WIP_STORAGE
		)
	)
	active_page_id = page_state.get("active_page_id", PAGE_BODY_INVENTORY)
	stacked_pages.current_tab = int(page_state.get("page_index", 0))
	_refresh_all()

func _refresh_all(status_text: String = "") -> void:
	surface_presenter.configure_runtime_context(action_presenter, text_presenter, active_player, material_lookup)
	refresh_presenter.refresh_all(
		page_presenter,
		active_source_label,
		active_page_id,
		footer_status_label,
		status_text,
		Callable(self, "_queue_layout_refresh"),
		_build_surface_refresh_payloads()
	)

func _on_equipment_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if not selection_presenter.update_selection_from_list(
		interaction_presenter,
		PlayerInventorySelectionPresenterScript.SELECTION_EQUIPMENT,
		equipment_list,
		index
	):
		return
	_refresh_all()

func _on_body_inventory_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if not selection_presenter.update_selection_from_list(
		interaction_presenter,
		PlayerInventorySelectionPresenterScript.SELECTION_BODY,
		body_inventory_list,
		index
	):
		return
	_refresh_all()

func _on_storage_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if not selection_presenter.update_selection_from_list(
		interaction_presenter,
		PlayerInventorySelectionPresenterScript.SELECTION_STORAGE,
		storage_list,
		index
	):
		return
	_refresh_all()

func _on_wip_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if not selection_presenter.update_selection_from_list(
		interaction_presenter,
		PlayerInventorySelectionPresenterScript.SELECTION_WIP,
		wip_list,
		index
	):
		return
	_refresh_all()

func _on_clear_slot_pressed() -> void:
	var command_result: Dictionary = interaction_presenter.handle_clear_slot(
		action_presenter,
		active_player,
		selection_presenter.get_selected_equipment_slot_id()
	)
	if not bool(command_result.get("should_refresh", false)):
		return
	_refresh_all(String(command_result.get("status_text", "")))

func _on_move_to_storage_pressed() -> void:
	var command_result: Dictionary = interaction_presenter.handle_move_to_storage(
		action_presenter,
		inventory_storage_service,
		active_player,
		selection_presenter.get_selected_body_item_id()
	)
	if not bool(command_result.get("should_refresh", false)):
		return
	selection_presenter.apply_command_result(command_result, &"selected_body_item_id")
	_refresh_all(String(command_result.get("status_text", "")))

func _on_move_to_inventory_pressed() -> void:
	var command_result: Dictionary = interaction_presenter.handle_move_to_inventory(
		action_presenter,
		inventory_storage_service,
		active_player,
		selection_presenter.get_selected_storage_item_id()
	)
	if not bool(command_result.get("should_refresh", false)):
		return
	selection_presenter.apply_command_result(command_result, &"selected_storage_item_id")
	_refresh_all(String(command_result.get("status_text", "")))

func _on_mark_for_forge_pressed() -> void:
	var command_result: Dictionary = interaction_presenter.handle_mark_for_forge(
		action_presenter,
		active_player,
		selection_presenter.get_selected_wip_id()
	)
	if not bool(command_result.get("should_refresh", false)):
		return
	_refresh_all(String(command_result.get("status_text", "")))

func _equip_selected_wip_to_hand(slot_id: StringName) -> void:
	var command_result: Dictionary = interaction_presenter.handle_equip_selected_wip_to_hand(
		action_presenter,
		active_player,
		selection_presenter.get_selected_wip_id(),
		slot_id
	)
	if not bool(command_result.get("should_refresh", false)):
		return
	_refresh_all(String(command_result.get("status_text", "")))

func _on_clear_hand_test_pressed() -> void:
	var command_result: Dictionary = interaction_presenter.handle_clear_hand_test(action_presenter, active_player)
	if not bool(command_result.get("should_refresh", false)):
		return
	_refresh_all(String(command_result.get("status_text", "")))

func _refresh_material_lookup() -> void:
	material_lookup = material_pipeline_service.build_base_material_lookup()
func _build_surface_refresh_payloads() -> Dictionary:
	return surface_presenter.build_refresh_payloads(
		PAGE_EQUIPMENT,
		PAGE_BODY_INVENTORY,
		PAGE_STORAGE,
		PAGE_FORGE_MATERIALS,
		PAGE_WIP_STORAGE,
		title_label,
		subtitle_label,
		equipment_page_button,
		inventory_page_button,
		storage_page_button,
		forge_materials_page_button,
		wip_page_button,
		equipment_list,
		equipment_detail_label,
		clear_slot_button,
		equipment_slot_registry,
		selection_presenter.get_selected_equipment_slot_id(),
		body_inventory_list,
		body_inventory_detail_label,
		move_to_storage_button,
		selection_presenter.get_selected_body_item_id(),
		storage_list,
		storage_detail_label,
		move_to_inventory_button,
		selection_presenter.get_selected_storage_item_id(),
		forge_materials_list,
		forge_materials_summary_label,
		wip_list,
		wip_detail_label,
		mark_for_forge_button,
		equip_right_hand_button,
		equip_left_hand_button,
		clear_hand_test_button,
		selection_presenter.get_selected_wip_id()
	)

func _queue_layout_refresh() -> void:
	if layout_refresh_queued:
		return
	layout_refresh_queued = true
	call_deferred("_apply_responsive_layout")

func _apply_responsive_layout() -> void:
	layout_refresh_queued = false
	layout_presenter.apply_responsive_layout(
		get_viewport().get_visible_rect().size,
		_build_surface_layout_config(),
		backdrop,
		panel,
		page_scroll,
		surface_presenter.get_page_buttons(
			equipment_page_button,
			inventory_page_button,
			storage_page_button,
			forge_materials_page_button,
			wip_page_button
		),
		surface_presenter.get_action_buttons(
			clear_slot_button,
			move_to_storage_button,
			refresh_body_inventory_button,
			move_to_inventory_button,
			refresh_storage_button,
			mark_for_forge_button,
			equip_right_hand_button,
			equip_left_hand_button,
			clear_hand_test_button,
			close_button
		),
		surface_presenter.get_item_lists(
			equipment_list,
			body_inventory_list,
			storage_list,
			forge_materials_list,
			wip_list
		)
	)

func _build_surface_layout_config() -> Dictionary:
	return surface_presenter.build_layout_config(
		compact_width_breakpoint,
		compact_height_breakpoint,
		wide_outer_margin_ratio,
		compact_outer_margin_ratio,
		minimum_outer_margin_px,
		maximum_outer_margin_px,
		compact_page_button_min_width,
		wide_page_button_min_width,
		compact_action_button_min_width,
		wide_action_button_min_width,
		compact_action_button_min_height,
		wide_action_button_min_height,
		compact_item_list_min_height,
		wide_item_list_min_height,
		minimum_item_list_min_height,
		compact_item_list_height_ratio,
		wide_item_list_height_ratio
	)
