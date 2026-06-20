extends RefCounted
class_name PlayerInventoryInteractionPresenter

func resolve_list_selection(item_list: ItemList, index: int) -> Dictionary:
	if item_list == null or index < 0 or index >= item_list.item_count:
		return {"valid": false, "selection_value": null}
	var selection_value = item_list.get_item_metadata(index)
	if selection_value == null:
		return {"valid": false, "selection_value": null}
	return {"valid": true, "selection_value": selection_value}

func handle_clear_slot(action_presenter: PlayerInventoryActionPresenter, active_player, selected_equipment_slot_id: StringName) -> Dictionary:
	return _build_command_result(action_presenter.clear_slot(active_player, selected_equipment_slot_id))

func handle_move_to_storage(
	action_presenter: PlayerInventoryActionPresenter,
	inventory_storage_service,
	active_player,
	selected_body_item_id: StringName
) -> Dictionary:
	var move_result: Dictionary = action_presenter.move_to_storage(
		inventory_storage_service,
		active_player,
		selected_body_item_id
	)
	return _build_command_result(
		String(move_result.get("status_text", "")),
		{"selected_body_item_id": move_result.get("selected_body_item_id", selected_body_item_id)}
	)

func handle_move_to_inventory(
	action_presenter: PlayerInventoryActionPresenter,
	inventory_storage_service,
	active_player,
	selected_storage_item_id: StringName
) -> Dictionary:
	var move_result: Dictionary = action_presenter.move_to_inventory(
		inventory_storage_service,
		active_player,
		selected_storage_item_id
	)
	return _build_command_result(
		String(move_result.get("status_text", "")),
		{"selected_storage_item_id": move_result.get("selected_storage_item_id", selected_storage_item_id)}
	)

func handle_mark_for_forge(action_presenter: PlayerInventoryActionPresenter, active_player, selected_wip_id: StringName) -> Dictionary:
	return _build_command_result(action_presenter.mark_for_forge(active_player, selected_wip_id))

func handle_equip_selected_wip_to_hand(
	action_presenter: PlayerInventoryActionPresenter,
	active_player,
	selected_wip_id: StringName,
	slot_id: StringName
) -> Dictionary:
	return _build_command_result(action_presenter.equip_selected_wip_to_hand(active_player, selected_wip_id, slot_id))

func handle_clear_hand_test(action_presenter: PlayerInventoryActionPresenter, active_player) -> Dictionary:
	return _build_command_result(action_presenter.clear_hand_test(active_player))

func _build_command_result(status_text: String, extra_fields: Dictionary = {}) -> Dictionary:
	var result := {"status_text": status_text, "should_refresh": not status_text.is_empty()}
	for key in extra_fields.keys():
		result[key] = extra_fields[key]
	return result
