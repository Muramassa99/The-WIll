extends RefCounted
class_name PlayerInventorySurfacePresenter

var action_presenter: PlayerInventoryActionPresenter = null
var text_presenter: PlayerInventoryTextPresenter = null
var active_player = null
var material_lookup: Dictionary = {}

func configure_runtime_context(
	resolved_action_presenter: PlayerInventoryActionPresenter,
	resolved_text_presenter: PlayerInventoryTextPresenter,
	resolved_active_player,
	resolved_material_lookup: Dictionary
) -> void:
	action_presenter = resolved_action_presenter
	text_presenter = resolved_text_presenter
	active_player = resolved_active_player
	material_lookup = resolved_material_lookup.duplicate(true)

func build_refresh_payloads(
	page_equipment: StringName,
	page_body_inventory: StringName,
	page_storage: StringName,
	page_forge_materials: StringName,
	page_wip_storage: StringName,
	title_label: Label,
	subtitle_label: Label,
	equipment_page_button: Button,
	inventory_page_button: Button,
	storage_page_button: Button,
	forge_materials_page_button: Button,
	wip_page_button: Button,
	equipment_list: ItemList,
	equipment_detail_label: Label,
	clear_slot_button: Button,
	equipment_slot_registry: Resource,
	selected_equipment_slot_id: StringName,
	body_inventory_list: ItemList,
	body_inventory_detail_label: Label,
	move_to_storage_button: Button,
	selected_body_item_id: StringName,
	storage_list: ItemList,
	storage_detail_label: Label,
	move_to_inventory_button: Button,
	selected_storage_item_id: StringName,
	forge_materials_list: ItemList,
	forge_materials_summary_label: Label,
	wip_list: ItemList,
	wip_detail_label: Label,
	mark_for_forge_button: Button,
	equip_right_hand_button: Button,
	equip_left_hand_button: Button,
	clear_hand_test_button: Button,
	selected_wip_id: StringName
) -> Dictionary:
	return {
		"header": {
			"title_label": title_label,
			"subtitle_label": subtitle_label,
		},
		"page_buttons": build_page_buttons(
			page_equipment,
			page_body_inventory,
			page_storage,
			page_forge_materials,
			page_wip_storage,
			equipment_page_button,
			inventory_page_button,
			storage_page_button,
			forge_materials_page_button,
			wip_page_button
		),
		"equipment": {
			"equipment_list": equipment_list,
			"equipment_detail_label": equipment_detail_label,
			"clear_slot_button": clear_slot_button,
			"equipment_slot_registry": equipment_slot_registry,
			"selected_equipment_slot_id": selected_equipment_slot_id,
			"equipment_state": _get_equipment_state(),
			"ordered_equipment_slots": _get_ordered_equipment_slots(equipment_slot_registry),
			"format_equipped_entry_label_callable": Callable(self, "_format_equipped_entry_label"),
		},
		"body_inventory": {
			"body_inventory_list": body_inventory_list,
			"body_inventory_detail_label": body_inventory_detail_label,
			"move_to_storage_button": move_to_storage_button,
			"body_inventory_state": _get_body_inventory_state(),
			"selected_body_item_id": selected_body_item_id,
			"format_stored_item_label_callable": Callable(self, "_format_stored_item_label"),
		},
		"storage": {
			"storage_list": storage_list,
			"storage_detail_label": storage_detail_label,
			"move_to_inventory_button": move_to_inventory_button,
			"storage_state": _get_personal_storage_state(),
			"selected_storage_item_id": selected_storage_item_id,
			"format_stored_item_label_callable": Callable(self, "_format_stored_item_label"),
		},
		"forge_materials": {
			"forge_materials_list": forge_materials_list,
			"forge_materials_summary_label": forge_materials_summary_label,
			"forge_inventory_state": _get_forge_inventory_state(),
			"format_material_stack_label_callable": Callable(self, "_format_material_stack_label"),
		},
		"wip_storage": {
			"wip_list": wip_list,
			"wip_detail_label": wip_detail_label,
			"mark_for_forge_button": mark_for_forge_button,
			"equip_right_hand_button": equip_right_hand_button,
			"equip_left_hand_button": equip_left_hand_button,
			"clear_hand_test_button": clear_hand_test_button,
			"wip_library": _get_forge_wip_library_state(),
			"selected_wip_id": selected_wip_id,
			"format_wip_label_callable": Callable(self, "_format_wip_label"),
			"get_wip_display_name_callable": Callable(self, "_get_wip_display_name"),
			"count_wip_cells_callable": Callable(self, "_count_wip_cells"),
			"preview_wip_test_status_callable": Callable(self, "_preview_wip_test_status"),
			"hands_are_empty_callable": Callable(self, "_hands_are_empty"),
		},
	}

func build_layout_config(
	compact_width_breakpoint: int,
	compact_height_breakpoint: int,
	wide_outer_margin_ratio: float,
	compact_outer_margin_ratio: float,
	minimum_outer_margin_px: int,
	maximum_outer_margin_px: int,
	compact_page_button_min_width: int,
	wide_page_button_min_width: int,
	compact_action_button_min_width: int,
	wide_action_button_min_width: int,
	compact_action_button_min_height: int,
	wide_action_button_min_height: int,
	compact_item_list_min_height: int,
	wide_item_list_min_height: int,
	minimum_item_list_min_height: int,
	compact_item_list_height_ratio: float,
	wide_item_list_height_ratio: float
) -> Dictionary:
	return {
		"compact_width_breakpoint": compact_width_breakpoint,
		"compact_height_breakpoint": compact_height_breakpoint,
		"wide_outer_margin_ratio": wide_outer_margin_ratio,
		"compact_outer_margin_ratio": compact_outer_margin_ratio,
		"minimum_outer_margin_px": minimum_outer_margin_px,
		"maximum_outer_margin_px": maximum_outer_margin_px,
		"compact_page_button_min_width": compact_page_button_min_width,
		"wide_page_button_min_width": wide_page_button_min_width,
		"compact_action_button_min_width": compact_action_button_min_width,
		"wide_action_button_min_width": wide_action_button_min_width,
		"compact_action_button_min_height": compact_action_button_min_height,
		"wide_action_button_min_height": wide_action_button_min_height,
		"compact_item_list_min_height": compact_item_list_min_height,
		"wide_item_list_min_height": wide_item_list_min_height,
		"minimum_item_list_min_height": minimum_item_list_min_height,
		"compact_item_list_height_ratio": compact_item_list_height_ratio,
		"wide_item_list_height_ratio": wide_item_list_height_ratio,
	}

func build_page_buttons(
	page_equipment: StringName,
	page_body_inventory: StringName,
	page_storage: StringName,
	page_forge_materials: StringName,
	page_wip_storage: StringName,
	equipment_page_button: Button,
	inventory_page_button: Button,
	storage_page_button: Button,
	forge_materials_page_button: Button,
	wip_page_button: Button
) -> Dictionary:
	return {
		page_equipment: equipment_page_button,
		page_body_inventory: inventory_page_button,
		page_storage: storage_page_button,
		page_forge_materials: forge_materials_page_button,
		page_wip_storage: wip_page_button,
	}

func get_page_order(
	page_equipment: StringName,
	page_body_inventory: StringName,
	page_storage: StringName,
	page_forge_materials: StringName,
	page_wip_storage: StringName
) -> Array[StringName]:
	return [
		page_equipment,
		page_body_inventory,
		page_storage,
		page_forge_materials,
		page_wip_storage,
	]

func get_page_buttons(
	equipment_page_button: Button,
	inventory_page_button: Button,
	storage_page_button: Button,
	forge_materials_page_button: Button,
	wip_page_button: Button
) -> Array[Button]:
	return [
		equipment_page_button,
		inventory_page_button,
		storage_page_button,
		forge_materials_page_button,
		wip_page_button,
	]

func get_action_buttons(
	clear_slot_button: Button,
	move_to_storage_button: Button,
	refresh_body_inventory_button: Button,
	move_to_inventory_button: Button,
	refresh_storage_button: Button,
	mark_for_forge_button: Button,
	equip_right_hand_button: Button,
	equip_left_hand_button: Button,
	clear_hand_test_button: Button,
	close_button: Button
) -> Array[Button]:
	return [
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
	]

func get_item_lists(
	equipment_list: ItemList,
	body_inventory_list: ItemList,
	storage_list: ItemList,
	forge_materials_list: ItemList,
	wip_list: ItemList
) -> Array[ItemList]:
	return [
		equipment_list,
		body_inventory_list,
		storage_list,
		forge_materials_list,
		wip_list,
	]

func _get_equipment_state():
	return action_presenter.get_equipment_state(active_player) if action_presenter != null else null

func _get_body_inventory_state():
	return action_presenter.get_body_inventory_state(active_player) if action_presenter != null else null

func _get_personal_storage_state():
	return action_presenter.get_personal_storage_state(active_player) if action_presenter != null else null

func _get_forge_inventory_state():
	return action_presenter.get_forge_inventory_state(active_player) if action_presenter != null else null

func _get_forge_wip_library_state():
	return action_presenter.get_forge_wip_library_state(active_player) if action_presenter != null else null

func _get_ordered_equipment_slots(equipment_slot_registry: Resource) -> Array:
	return action_presenter.get_ordered_equipment_slots(equipment_slot_registry) if action_presenter != null else []

func _preview_wip_test_status(wip_id: StringName) -> Dictionary:
	return action_presenter.preview_wip_test_status(active_player, wip_id) if action_presenter != null else {}

func _hands_are_empty() -> bool:
	return action_presenter.hands_are_empty(active_player) if action_presenter != null else true

func _format_equipped_entry_label(equipped_entry) -> String:
	return text_presenter.format_equipped_entry_label(equipped_entry) if text_presenter != null else "Empty"

func _format_stored_item_label(stored_item: Resource) -> String:
	return text_presenter.format_stored_item_label(stored_item) if text_presenter != null else "Unknown Item"

func _format_material_stack_label(material_stack: ForgeMaterialStack) -> String:
	return text_presenter.format_material_stack_label(material_stack, material_lookup) if text_presenter != null else "Unknown Material"

func _format_wip_label(saved_wip: CraftedItemWIP, is_selected_for_forge: bool) -> String:
	return text_presenter.format_wip_label(saved_wip, is_selected_for_forge) if text_presenter != null else "Unnamed WIP"

func _get_wip_display_name(saved_wip: CraftedItemWIP) -> String:
	return text_presenter.get_wip_display_name(saved_wip) if text_presenter != null else "Unnamed WIP"

func _count_wip_cells(saved_wip: CraftedItemWIP) -> int:
	return text_presenter.count_wip_cells(saved_wip) if text_presenter != null else 0
