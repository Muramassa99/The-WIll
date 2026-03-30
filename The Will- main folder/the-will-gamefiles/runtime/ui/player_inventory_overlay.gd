extends CanvasLayer
class_name PlayerInventoryOverlay

signal closed

const InventoryStorageServiceScript = preload("res://services/inventory_storage_service.gd")
const MaterialPipelineServiceScript = preload("res://services/material_pipeline_service.gd")
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
var selected_equipment_slot_id: StringName = StringName()
var selected_body_item_id: StringName = StringName()
var selected_storage_item_id: StringName = StringName()
var selected_wip_id: StringName = StringName()
var material_lookup: Dictionary = {}
var layout_refresh_queued: bool = false

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
	if is_open() and active_player == player and active_page_id == page_id:
		close_overlay()
		return
	open_page_for(player, page_id, source_label)

func open_page_for(player, page_id: StringName, source_label: String = "") -> void:
	active_player = player
	active_source_label = source_label.strip_edges() if not source_label.strip_edges().is_empty() else "Player Inventory"
	if active_player != null and active_player.has_method("set_ui_mode_enabled"):
		active_player.call("set_ui_mode_enabled", true)
	visible = true
	backdrop.visible = true
	panel.visible = true
	_set_active_page(page_id)
	layout_refresh_queued = false
	_apply_responsive_layout()
	_queue_layout_refresh()

func close_overlay() -> void:
	if not is_open():
		return
	panel.visible = false
	backdrop.visible = false
	visible = false
	if active_player != null and active_player.has_method("set_ui_mode_enabled"):
		active_player.call("set_ui_mode_enabled", false)
	active_player = null
	active_source_label = "Player Inventory"
	emit_signal("closed")

func is_open() -> bool:
	return panel.visible

func _set_active_page(page_id: StringName) -> void:
	active_page_id = page_id if page_id != StringName() else PAGE_BODY_INVENTORY
	stacked_pages.current_tab = _resolve_page_index(active_page_id)
	_refresh_all()

func _resolve_page_index(page_id: StringName) -> int:
	match page_id:
		PAGE_EQUIPMENT:
			return 0
		PAGE_BODY_INVENTORY:
			return 1
		PAGE_STORAGE:
			return 2
		PAGE_FORGE_MATERIALS:
			return 3
		PAGE_WIP_STORAGE:
			return 4
		_:
			return 1

func _refresh_all(status_text: String = "") -> void:
	_refresh_header_text()
	_refresh_nav_button_state()
	_refresh_equipment_page()
	_refresh_body_inventory_page()
	_refresh_storage_page()
	_refresh_forge_materials_page()
	_refresh_wip_page()
	if not status_text.is_empty():
		footer_status_label.text = status_text
	elif footer_status_label.text.strip_edges().is_empty():
		footer_status_label.text = "Inventory ready."
	_queue_layout_refresh()

func _refresh_header_text() -> void:
	title_label.text = active_source_label
	subtitle_label.text = "Use this shared player surface for equipment, on-body inventory, personal storage, forge material counts, and saved WIP projects."

func _refresh_nav_button_state() -> void:
	var page_buttons: Dictionary = {
		PAGE_EQUIPMENT: equipment_page_button,
		PAGE_BODY_INVENTORY: inventory_page_button,
		PAGE_STORAGE: storage_page_button,
		PAGE_FORGE_MATERIALS: forge_materials_page_button,
		PAGE_WIP_STORAGE: wip_page_button,
	}
	for page_id_value in page_buttons.keys():
		var page_id: StringName = page_id_value
		var button: Button = page_buttons[page_id]
		button.disabled = page_id == active_page_id

func _refresh_equipment_page() -> void:
	equipment_list.clear()
	var equipment_state = _get_equipment_state()
	for slot_def in _get_ordered_equipment_slots():
		if slot_def == null:
			continue
		var equipped_entry = equipment_state.call("get_equipped_slot", slot_def.slot_id) if equipment_state != null else null
		var item_index: int = equipment_list.add_item("%s: %s" % [slot_def.get_resolved_display_name(), _format_equipped_entry_label(equipped_entry)])
		equipment_list.set_item_metadata(item_index, slot_def.slot_id)
	if equipment_list.item_count == 0:
		equipment_list.add_item("No equipment slots are configured.")
		equipment_list.set_item_disabled(0, true)
	var selected_slot_def = equipment_slot_registry.get_slot(selected_equipment_slot_id) if equipment_slot_registry != null else null
	var selected_entry = equipment_state.call("get_equipped_slot", selected_equipment_slot_id) if equipment_state != null and selected_equipment_slot_id != StringName() else null
	if selected_slot_def == null:
		equipment_detail_label.text = "Select an equipment slot to inspect it. Hand slots currently support forge-internal WIP test equips, while the rest of the slot shell is ready for finalized items later."
		clear_slot_button.disabled = true
		return
	var detail_lines: PackedStringArray = []
	detail_lines.append("Slot: %s" % selected_slot_def.get_resolved_display_name())
	detail_lines.append("Category: %s" % String(selected_slot_def.category_id).capitalize())
	detail_lines.append("Section: %s" % String(selected_slot_def.section_id).capitalize())
	detail_lines.append("Supports forge test loadout: %s" % str(selected_slot_def.supports_forge_test_loadout))
	detail_lines.append("Current entry: %s" % _format_equipped_entry_label(selected_entry))
	if selected_entry != null and selected_entry.is_forge_test_wip():
		detail_lines.append("Source WIP id: %s" % String(selected_entry.source_wip_id))
		detail_lines.append("Forge-only entry: true")
	elif selected_entry != null and selected_entry.is_stored_item():
		detail_lines.append("Stored item id: %s" % String(selected_entry.source_item_instance_id))
	equipment_detail_label.text = "\n".join(detail_lines)
	clear_slot_button.disabled = selected_entry == null

func _refresh_body_inventory_page() -> void:
	body_inventory_list.clear()
	var body_inventory_state = _get_body_inventory_state()
	var body_items: Array[Resource] = body_inventory_state.get_owned_items() if body_inventory_state != null else []
	for stored_item: Resource in body_items:
		if stored_item == null:
			continue
		var item_index: int = body_inventory_list.add_item(_format_stored_item_label(stored_item))
		body_inventory_list.set_item_metadata(item_index, stored_item.item_instance_id)
	if body_inventory_list.item_count == 0:
		body_inventory_list.add_item("Body inventory is empty.")
		body_inventory_list.set_item_disabled(0, true)
	var selected_item = body_inventory_state.get_item(selected_body_item_id) if body_inventory_state != null and selected_body_item_id != StringName() else null
	if selected_item == null:
		body_inventory_detail_label.text = "Select an on-body item to inspect it or move it into personal storage."
		move_to_storage_button.disabled = true
		return
	body_inventory_detail_label.text = "Item: %s\nKind: %s\nStack count: %d\nDisassemblable: %s\nEquip flow: finalized-item equipment support comes later, while storage transfer works now." % [
		selected_item.get_resolved_display_name(),
		String(selected_item.item_kind),
		selected_item.stack_count,
		str(selected_item.is_disassemblable),
	]
	move_to_storage_button.disabled = false

func _refresh_storage_page() -> void:
	storage_list.clear()
	var storage_state = _get_personal_storage_state()
	var stored_items: Array[Resource] = storage_state.get_stored_items() if storage_state != null else []
	for stored_item: Resource in stored_items:
		if stored_item == null:
			continue
		var item_index: int = storage_list.add_item(_format_stored_item_label(stored_item))
		storage_list.set_item_metadata(item_index, stored_item.item_instance_id)
	if storage_list.item_count == 0:
		storage_list.add_item("Personal storage is empty.")
		storage_list.set_item_disabled(0, true)
	var selected_item = storage_state.get_item(selected_storage_item_id) if storage_state != null and selected_storage_item_id != StringName() else null
	if selected_item == null:
		storage_detail_label.text = "Select a stored item to inspect it or move it back into body inventory."
		move_to_inventory_button.disabled = true
		return
	storage_detail_label.text = "Stored item: %s\nKind: %s\nStack count: %d\nThis is a personal storage surface that can later be opened from other storage locations as long as they point at this same player-owned data." % [
		selected_item.get_resolved_display_name(),
		String(selected_item.item_kind),
		selected_item.stack_count,
	]
	move_to_inventory_button.disabled = false

func _refresh_forge_materials_page() -> void:
	forge_materials_list.clear()
	var forge_inventory_state = _get_forge_inventory_state()
	var material_stacks: Array[ForgeMaterialStack] = forge_inventory_state.material_stacks if forge_inventory_state != null else []
	var total_quantity: int = 0
	var non_empty_stack_count: int = 0
	for material_stack: ForgeMaterialStack in material_stacks:
		if material_stack == null or material_stack.quantity <= 0:
			continue
		non_empty_stack_count += 1
		total_quantity += material_stack.quantity
		forge_materials_list.add_item(_format_material_stack_label(material_stack))
	if forge_materials_list.item_count == 0:
		forge_materials_list.add_item("No forge materials are currently stored.")
		forge_materials_list.set_item_disabled(0, true)
	forge_materials_summary_label.text = "Visible forge stack count: %d\nTotal forge material quantity: %d\nThis page is here for logistics and quick checks while away from the forge." % [
		non_empty_stack_count,
		total_quantity,
	]

func _refresh_wip_page() -> void:
	wip_list.clear()
	var wip_library = _get_forge_wip_library_state()
	var saved_wips: Array[CraftedItemWIP] = wip_library.get_saved_wips() if wip_library != null else []
	for saved_wip: CraftedItemWIP in saved_wips:
		if saved_wip == null:
			continue
		var label: String = _format_wip_label(saved_wip, wip_library.selected_wip_id == saved_wip.wip_id if wip_library != null else false)
		var item_index: int = wip_list.add_item(label)
		wip_list.set_item_metadata(item_index, saved_wip.wip_id)
	if wip_list.item_count == 0:
		wip_list.add_item("No saved WIP projects exist yet.")
		wip_list.set_item_disabled(0, true)
	var selected_wip: CraftedItemWIP = wip_library.get_saved_wip(selected_wip_id) if wip_library != null and selected_wip_id != StringName() else null
	if selected_wip == null:
		wip_detail_label.text = "Select a saved WIP to inspect it, mark it for the forge, or test-equip it into the right or left hand slot if it passes the current forge test gate."
		mark_for_forge_button.disabled = true
		equip_right_hand_button.disabled = true
		equip_left_hand_button.disabled = true
		clear_hand_test_button.disabled = _hands_are_empty()
		return
	var status_preview: Dictionary = _preview_wip_test_status(selected_wip.wip_id)
	var detail_lines: PackedStringArray = []
	detail_lines.append("Project: %s" % _get_wip_display_name(selected_wip))
	detail_lines.append("WIP id: %s" % String(selected_wip.wip_id))
	detail_lines.append("Intent: %s" % String(selected_wip.forge_intent))
	detail_lines.append("Equipment context: %s" % String(selected_wip.equipment_context))
	detail_lines.append("Cell count: %d" % _count_wip_cells(selected_wip))
	detail_lines.append("Forge test valid now: %s" % str(bool(status_preview.get("valid", false))))
	detail_lines.append("Gate detail: %s" % String(status_preview.get("message", "No preview available.")))
	wip_detail_label.text = "\n".join(detail_lines)
	mark_for_forge_button.disabled = false
	var can_equip_now: bool = bool(status_preview.get("valid", false))
	equip_right_hand_button.disabled = not can_equip_now
	equip_left_hand_button.disabled = not can_equip_now
	clear_hand_test_button.disabled = _hands_are_empty()

func _on_equipment_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if index < 0 or index >= equipment_list.item_count:
		return
	var slot_id_variant = equipment_list.get_item_metadata(index)
	if slot_id_variant == null:
		return
	selected_equipment_slot_id = slot_id_variant
	_refresh_equipment_page()

func _on_body_inventory_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if index < 0 or index >= body_inventory_list.item_count:
		return
	var item_id_variant = body_inventory_list.get_item_metadata(index)
	if item_id_variant == null:
		return
	selected_body_item_id = item_id_variant
	_refresh_body_inventory_page()

func _on_storage_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if index < 0 or index >= storage_list.item_count:
		return
	var item_id_variant = storage_list.get_item_metadata(index)
	if item_id_variant == null:
		return
	selected_storage_item_id = item_id_variant
	_refresh_storage_page()

func _on_wip_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if index < 0 or index >= wip_list.item_count:
		return
	var wip_id_variant = wip_list.get_item_metadata(index)
	if wip_id_variant == null:
		return
	selected_wip_id = wip_id_variant
	_refresh_wip_page()

func _on_clear_slot_pressed() -> void:
	if selected_equipment_slot_id == StringName():
		return
	if active_player != null and active_player.has_method("clear_equipment_slot"):
		active_player.call("clear_equipment_slot", selected_equipment_slot_id)
	_refresh_all("Cleared equipment slot %s." % String(selected_equipment_slot_id))

func _on_move_to_storage_pressed() -> void:
	if selected_body_item_id == StringName():
		return
	var moved_item = inventory_storage_service.transfer_item(
		_get_body_inventory_state(),
		_get_personal_storage_state(),
		selected_body_item_id
	)
	if moved_item == null:
		_refresh_all("Could not move the selected body item into personal storage.")
		return
	selected_body_item_id = StringName()
	_refresh_all("Moved the selected body item into personal storage.")

func _on_move_to_inventory_pressed() -> void:
	if selected_storage_item_id == StringName():
		return
	var moved_item = inventory_storage_service.transfer_item(
		_get_personal_storage_state(),
		_get_body_inventory_state(),
		selected_storage_item_id
	)
	if moved_item == null:
		_refresh_all("Could not move the selected stored item back into body inventory.")
		return
	selected_storage_item_id = StringName()
	_refresh_all("Moved the selected stored item back into body inventory.")

func _on_mark_for_forge_pressed() -> void:
	if selected_wip_id == StringName() or active_player == null or not active_player.has_method("set_selected_forge_wip_id"):
		return
	active_player.call("set_selected_forge_wip_id", selected_wip_id)
	_refresh_all("Marked the selected WIP as the preferred forge project.")

func _equip_selected_wip_to_hand(slot_id: StringName) -> void:
	if selected_wip_id == StringName() or active_player == null or not active_player.has_method("equip_saved_wip_to_hand"):
		return
	var equip_result: Dictionary = active_player.call("equip_saved_wip_to_hand", selected_wip_id, slot_id)
	_refresh_all(String(equip_result.get("message", "Updated hand test loadout.")))

func _on_clear_hand_test_pressed() -> void:
	if active_player == null or not active_player.has_method("clear_equipment_slot"):
		return
	active_player.call("clear_equipment_slot", &"hand_right")
	active_player.call("clear_equipment_slot", &"hand_left")
	_refresh_all("Cleared both hand test-loadout slots.")

func _hands_are_empty() -> bool:
	var equipment_state = _get_equipment_state()
	if equipment_state == null:
		return true
	return equipment_state.get_equipped_slot(&"hand_right") == null and equipment_state.get_equipped_slot(&"hand_left") == null

func _get_equipment_state():
	if active_player == null or not active_player.has_method("get_equipment_state"):
		return null
	return active_player.call("get_equipment_state")

func _get_body_inventory_state():
	if active_player == null or not active_player.has_method("get_body_inventory_state"):
		return null
	return active_player.call("get_body_inventory_state")

func _get_personal_storage_state():
	if active_player == null or not active_player.has_method("get_personal_storage_state"):
		return null
	return active_player.call("get_personal_storage_state")

func _get_forge_inventory_state():
	if active_player == null or not active_player.has_method("get_forge_inventory_state"):
		return null
	return active_player.call("get_forge_inventory_state")

func _get_forge_wip_library_state():
	if active_player == null or not active_player.has_method("get_forge_wip_library_state"):
		return null
	return active_player.call("get_forge_wip_library_state")

func _get_ordered_equipment_slots() -> Array:
	if equipment_slot_registry == null:
		return []
	return equipment_slot_registry.get_slots_ordered()

func _preview_wip_test_status(wip_id: StringName) -> Dictionary:
	if active_player == null or not active_player.has_method("preview_saved_wip_test_status"):
		return {}
	return active_player.call("preview_saved_wip_test_status", wip_id) as Dictionary

func _refresh_material_lookup() -> void:
	material_lookup = material_pipeline_service.build_base_material_lookup()

func _format_equipped_entry_label(equipped_entry) -> String:
	if equipped_entry == null:
		return "Empty"
	var suffix: String = ""
	if equipped_entry.is_forge_test_wip():
		suffix = " [Forge Test]"
	elif equipped_entry.is_stored_item():
		suffix = " [Item]"
	return "%s%s" % [equipped_entry.get_resolved_display_name(), suffix]

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

func _format_wip_label(saved_wip: CraftedItemWIP, is_selected_for_forge: bool) -> String:
	var prefix: String = "* " if is_selected_for_forge else ""
	return "%s%s" % [prefix, _get_wip_display_name(saved_wip)]

func _get_wip_display_name(saved_wip: CraftedItemWIP) -> String:
	if saved_wip == null:
		return "Unnamed WIP"
	var cleaned_name: String = saved_wip.forge_project_name.strip_edges()
	if not cleaned_name.is_empty():
		return cleaned_name
	return String(saved_wip.wip_id)

func _count_wip_cells(saved_wip: CraftedItemWIP) -> int:
	if saved_wip == null:
		return 0
	var total_cells: int = 0
	for layer_atom: LayerAtom in saved_wip.layers:
		if layer_atom == null:
			continue
		total_cells += layer_atom.cells.size()
	return total_cells

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
	page_scroll.custom_minimum_size = Vector2.ZERO

	var page_button_min_width: int = compact_page_button_min_width if compact_mode else wide_page_button_min_width
	var action_button_min_width: int = compact_action_button_min_width if compact_mode else wide_action_button_min_width
	var action_button_min_height: int = compact_action_button_min_height if compact_mode else wide_action_button_min_height
	for page_button: Button in [
		equipment_page_button,
		inventory_page_button,
		storage_page_button,
		forge_materials_page_button,
		wip_page_button,
	]:
		page_button.custom_minimum_size = Vector2(page_button_min_width, action_button_min_height)

	for action_button: Button in [
		clear_slot_button,
		move_to_storage_button,
		refresh_body_inventory_button,
		move_to_inventory_button,
		refresh_storage_button,
		mark_for_forge_button,
		equip_right_hand_button,
		equip_left_hand_button,
		clear_hand_test_button,
		close_button,
	]:
		action_button.custom_minimum_size = Vector2(action_button_min_width, action_button_min_height)

	var resolved_item_list_min_height: int = compact_item_list_min_height if compact_mode else wide_item_list_min_height
	var item_list_height_ratio: float = compact_item_list_height_ratio if compact_mode else wide_item_list_height_ratio
	resolved_item_list_min_height = clampi(
		int(round(viewport_size.y * item_list_height_ratio)),
		minimum_item_list_min_height,
		resolved_item_list_min_height
	)
	for item_list: ItemList in [
		equipment_list,
		body_inventory_list,
		storage_list,
		forge_materials_list,
		wip_list,
	]:
		item_list.custom_minimum_size.y = resolved_item_list_min_height
