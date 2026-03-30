extends Resource
class_name EquipmentSlotDef

@export var slot_id: StringName = &""
@export var display_name: String = ""
@export var category_id: StringName = &""
@export var section_id: StringName = &""
@export var supports_forge_test_loadout: bool = false
@export var display_order: int = 0

func get_resolved_display_name() -> String:
	var cleaned_name: String = display_name.strip_edges()
	if not cleaned_name.is_empty():
		return cleaned_name
	return String(slot_id).replace("_", " ").capitalize()

