extends RefCounted
class_name PlayerInventoryActionPresenter

func get_equipment_state(active_player):
	if active_player == null or not active_player.has_method("get_equipment_state"):
		return null
	return active_player.call("get_equipment_state")

func get_body_inventory_state(active_player):
	if active_player == null or not active_player.has_method("get_body_inventory_state"):
		return null
	return active_player.call("get_body_inventory_state")

func get_personal_storage_state(active_player):
	if active_player == null or not active_player.has_method("get_personal_storage_state"):
		return null
	return active_player.call("get_personal_storage_state")

func get_forge_inventory_state(active_player):
	if active_player == null or not active_player.has_method("get_forge_inventory_state"):
		return null
	return active_player.call("get_forge_inventory_state")

func get_forge_wip_library_state(active_player):
	if active_player == null or not active_player.has_method("get_forge_wip_library_state"):
		return null
	return active_player.call("get_forge_wip_library_state")

func get_ordered_equipment_slots(equipment_slot_registry: Resource) -> Array:
	if equipment_slot_registry == null:
		return []
	return equipment_slot_registry.get_slots_ordered()

func preview_wip_test_status(active_player, wip_id: StringName) -> Dictionary:
	if active_player == null or not active_player.has_method("preview_saved_wip_test_status"):
		return {}
	return active_player.call("preview_saved_wip_test_status", wip_id) as Dictionary

func hands_are_empty(active_player) -> bool:
	var equipment_state = get_equipment_state(active_player)
	if equipment_state == null:
		return true
	return equipment_state.get_equipped_slot(&"hand_right") == null and equipment_state.get_equipped_slot(&"hand_left") == null

func clear_slot(active_player, slot_id: StringName) -> String:
	if slot_id == StringName():
		return ""
	if active_player != null and active_player.has_method("clear_equipment_slot"):
		active_player.call("clear_equipment_slot", slot_id)
	return "Cleared equipment slot %s." % String(slot_id)

func move_to_storage(
	inventory_storage_service,
	active_player,
	selected_body_item_id: StringName
) -> Dictionary:
	if selected_body_item_id == StringName():
		return {"success": false, "status_text": "", "selected_body_item_id": selected_body_item_id}
	var moved_item = inventory_storage_service.transfer_item(
		get_body_inventory_state(active_player),
		get_personal_storage_state(active_player),
		selected_body_item_id
	)
	if moved_item == null:
		return {
			"success": false,
			"status_text": "Could not move the selected body item into personal storage.",
			"selected_body_item_id": selected_body_item_id,
		}
	return {
		"success": true,
		"status_text": "Moved the selected body item into personal storage.",
		"selected_body_item_id": StringName(),
	}

func move_to_inventory(
	inventory_storage_service,
	active_player,
	selected_storage_item_id: StringName
) -> Dictionary:
	if selected_storage_item_id == StringName():
		return {"success": false, "status_text": "", "selected_storage_item_id": selected_storage_item_id}
	var moved_item = inventory_storage_service.transfer_item(
		get_personal_storage_state(active_player),
		get_body_inventory_state(active_player),
		selected_storage_item_id
	)
	if moved_item == null:
		return {
			"success": false,
			"status_text": "Could not move the selected stored item back into body inventory.",
			"selected_storage_item_id": selected_storage_item_id,
		}
	return {
		"success": true,
		"status_text": "Moved the selected stored item back into body inventory.",
		"selected_storage_item_id": StringName(),
	}

func mark_for_forge(active_player, selected_wip_id: StringName) -> String:
	if selected_wip_id == StringName() or active_player == null or not active_player.has_method("set_selected_forge_wip_id"):
		return ""
	active_player.call("set_selected_forge_wip_id", selected_wip_id)
	return "Marked the selected WIP as the preferred forge project."

func equip_selected_wip_to_hand(active_player, selected_wip_id: StringName, slot_id: StringName) -> String:
	if selected_wip_id == StringName() or active_player == null or not active_player.has_method("equip_saved_wip_to_hand"):
		return ""
	var equip_result: Dictionary = active_player.call("equip_saved_wip_to_hand", selected_wip_id, slot_id)
	return String(equip_result.get("message", "Updated hand test loadout."))

func clear_hand_test(active_player) -> String:
	if active_player == null or not active_player.has_method("clear_equipment_slot"):
		return ""
	active_player.call("clear_equipment_slot", &"hand_right")
	active_player.call("clear_equipment_slot", &"hand_left")
	return "Cleared both hand test-loadout slots."
