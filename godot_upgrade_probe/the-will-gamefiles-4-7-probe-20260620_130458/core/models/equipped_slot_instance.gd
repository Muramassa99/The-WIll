extends Resource
class_name EquippedSlotInstance

const KIND_STORED_ITEM := &"stored_item"
const KIND_FORGE_TEST_WIP := &"forge_test_wip"

@export var slot_id: StringName = &""
@export var entry_kind: StringName = &""
@export var source_item_instance_id: StringName = &""
@export var source_wip_id: StringName = &""
@export var display_name: String = ""
@export var is_forge_internal_only: bool = false

func is_empty() -> bool:
	return slot_id == StringName() or entry_kind == StringName()

func is_stored_item() -> bool:
	return entry_kind == KIND_STORED_ITEM and source_item_instance_id != StringName()

func is_forge_test_wip() -> bool:
	return entry_kind == KIND_FORGE_TEST_WIP and source_wip_id != StringName()

func get_resolved_display_name() -> String:
	var cleaned_name: String = display_name.strip_edges()
	if not cleaned_name.is_empty():
		return cleaned_name
	if is_forge_test_wip():
		return "Forge Test WIP"
	if is_stored_item():
		return "Equipped Item"
	return "Empty"

