extends RefCounted
class_name PlayerInventorySelectionPresenter

const SELECTION_EQUIPMENT := &"equipment"
const SELECTION_BODY := &"body"
const SELECTION_STORAGE := &"storage"
const SELECTION_WIP := &"wip"

var selection_values := {
	SELECTION_EQUIPMENT: StringName(),
	SELECTION_BODY: StringName(),
	SELECTION_STORAGE: StringName(),
	SELECTION_WIP: StringName(),
}

func get_selected_equipment_slot_id() -> StringName:
	return get_selection_value(SELECTION_EQUIPMENT)

func get_selected_body_item_id() -> StringName:
	return get_selection_value(SELECTION_BODY)

func get_selected_storage_item_id() -> StringName:
	return get_selection_value(SELECTION_STORAGE)

func get_selected_wip_id() -> StringName:
	return get_selection_value(SELECTION_WIP)

func get_selection_value(selection_key: StringName) -> StringName:
	return selection_values.get(selection_key, StringName())

func update_selection_from_list(
	interaction_presenter: PlayerInventoryInteractionPresenter,
	selection_key: StringName,
	item_list: ItemList,
	index: int
) -> bool:
	if interaction_presenter == null:
		return false
	var selection_result: Dictionary = interaction_presenter.resolve_list_selection(item_list, index)
	if not bool(selection_result.get("valid", false)):
		return false
	selection_values[selection_key] = selection_result.get("selection_value", get_selection_value(selection_key))
	return true

func apply_command_result(command_result: Dictionary, selection_field_name: StringName) -> void:
	if selection_field_name == StringName():
		return
	if command_result.has(selection_field_name):
		selection_values[_selection_key_from_field_name(selection_field_name)] = command_result.get(selection_field_name, StringName())

func set_selection_value(selection_field_name: StringName, selection_value: StringName) -> void:
	if selection_field_name == StringName():
		return
	selection_values[_selection_key_from_field_name(selection_field_name)] = selection_value

func _selection_key_from_field_name(selection_field_name: StringName) -> StringName:
	match selection_field_name:
		&"selected_equipment_slot_id":
			return SELECTION_EQUIPMENT
		&"selected_body_item_id":
			return SELECTION_BODY
		&"selected_storage_item_id":
			return SELECTION_STORAGE
		&"selected_wip_id":
			return SELECTION_WIP
		_:
			return selection_field_name
