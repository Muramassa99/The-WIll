extends RefCounted
class_name PlayerInventoryPagePresenter

func refresh_header_text(title_label: Label, subtitle_label: Label, active_source_label: String) -> void:
	title_label.text = active_source_label
	subtitle_label.text = "Use this shared player surface for equipment, on-body inventory, personal storage, forge material counts, and saved WIP projects."

func refresh_nav_button_state(active_page_id: StringName, page_buttons: Dictionary) -> void:
	for page_id_value in page_buttons.keys():
		var page_id: StringName = page_id_value
		var button: Button = page_buttons[page_id]
		button.disabled = page_id == active_page_id

func refresh_equipment_page(
	equipment_list: ItemList,
	equipment_detail_label: Label,
	clear_slot_button: Button,
	equipment_slot_registry: Resource,
	selected_equipment_slot_id: StringName,
	equipment_state,
	ordered_equipment_slots: Array,
	format_equipped_entry_label_callable: Callable
) -> void:
	equipment_list.clear()
	for slot_def in ordered_equipment_slots:
		if slot_def == null:
			continue
		var equipped_entry = equipment_state.call("get_equipped_slot", slot_def.slot_id) if equipment_state != null else null
		var item_index: int = equipment_list.add_item("%s: %s" % [slot_def.get_resolved_display_name(), format_equipped_entry_label_callable.call(equipped_entry)])
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
	detail_lines.append("Current entry: %s" % format_equipped_entry_label_callable.call(selected_entry))
	if selected_entry != null and selected_entry.is_forge_test_wip():
		detail_lines.append("Source WIP id: %s" % String(selected_entry.source_wip_id))
		detail_lines.append("Forge-only entry: true")
	elif selected_entry != null and selected_entry.is_stored_item():
		detail_lines.append("Stored item id: %s" % String(selected_entry.source_item_instance_id))
	equipment_detail_label.text = "\n".join(detail_lines)
	clear_slot_button.disabled = selected_entry == null

func refresh_body_inventory_page(
	body_inventory_list: ItemList,
	body_inventory_detail_label: Label,
	move_to_storage_button: Button,
	body_inventory_state,
	selected_body_item_id: StringName,
	format_stored_item_label_callable: Callable
) -> void:
	body_inventory_list.clear()
	var body_items: Array[Resource] = body_inventory_state.get_owned_items() if body_inventory_state != null else []
	for stored_item: Resource in body_items:
		if stored_item == null:
			continue
		var item_index: int = body_inventory_list.add_item(format_stored_item_label_callable.call(stored_item))
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

func refresh_storage_page(
	storage_list: ItemList,
	storage_detail_label: Label,
	move_to_inventory_button: Button,
	storage_state,
	selected_storage_item_id: StringName,
	format_stored_item_label_callable: Callable
) -> void:
	storage_list.clear()
	var stored_items: Array[Resource] = storage_state.get_stored_items() if storage_state != null else []
	for stored_item: Resource in stored_items:
		if stored_item == null:
			continue
		var item_index: int = storage_list.add_item(format_stored_item_label_callable.call(stored_item))
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

func refresh_forge_materials_page(
	forge_materials_list: ItemList,
	forge_materials_summary_label: Label,
	forge_inventory_state,
	format_material_stack_label_callable: Callable
) -> void:
	forge_materials_list.clear()
	var material_stacks: Array[ForgeMaterialStack] = forge_inventory_state.material_stacks if forge_inventory_state != null else []
	var total_quantity: int = 0
	var non_empty_stack_count: int = 0
	for material_stack: ForgeMaterialStack in material_stacks:
		if material_stack == null or material_stack.quantity <= 0:
			continue
		non_empty_stack_count += 1
		total_quantity += material_stack.quantity
		forge_materials_list.add_item(format_material_stack_label_callable.call(material_stack))
	if forge_materials_list.item_count == 0:
		forge_materials_list.add_item("No forge materials are currently stored.")
		forge_materials_list.set_item_disabled(0, true)
	forge_materials_summary_label.text = "Visible forge stack count: %d\nTotal forge material quantity: %d\nThis page is here for logistics and quick checks while away from the forge." % [
		non_empty_stack_count,
		total_quantity,
	]

func refresh_wip_page(
	wip_list: ItemList,
	wip_detail_label: Label,
	mark_for_forge_button: Button,
	equip_right_hand_button: Button,
	equip_left_hand_button: Button,
	clear_hand_test_button: Button,
	wip_library,
	selected_wip_id: StringName,
	format_wip_label_callable: Callable,
	get_wip_display_name_callable: Callable,
	count_wip_cells_callable: Callable,
	preview_wip_test_status_callable: Callable,
	hands_are_empty_callable: Callable
) -> void:
	wip_list.clear()
	var saved_wips: Array[CraftedItemWIP] = wip_library.get_saved_wips() if wip_library != null else []
	for saved_wip: CraftedItemWIP in saved_wips:
		if saved_wip == null:
			continue
		var label: String = format_wip_label_callable.call(saved_wip, wip_library.selected_wip_id == saved_wip.wip_id if wip_library != null else false)
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
		clear_hand_test_button.disabled = hands_are_empty_callable.call()
		return
	var status_preview: Dictionary = preview_wip_test_status_callable.call(selected_wip.wip_id)
	var detail_lines: PackedStringArray = []
	detail_lines.append("Project: %s" % get_wip_display_name_callable.call(selected_wip))
	detail_lines.append("WIP id: %s" % String(selected_wip.wip_id))
	detail_lines.append("Intent: %s" % String(selected_wip.forge_intent))
	detail_lines.append("Equipment context: %s" % String(selected_wip.equipment_context))
	detail_lines.append("Cell count: %d" % count_wip_cells_callable.call(selected_wip))
	detail_lines.append("Forge test valid now: %s" % str(bool(status_preview.get("valid", false))))
	detail_lines.append("Gate detail: %s" % String(status_preview.get("message", "No preview available.")))
	wip_detail_label.text = "\n".join(detail_lines)
	mark_for_forge_button.disabled = false
	var can_equip_now: bool = bool(status_preview.get("valid", false))
	equip_right_hand_button.disabled = not can_equip_now
	equip_left_hand_button.disabled = not can_equip_now
	clear_hand_test_button.disabled = hands_are_empty_callable.call()
