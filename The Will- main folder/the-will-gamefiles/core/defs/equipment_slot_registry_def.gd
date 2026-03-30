extends Resource
class_name EquipmentSlotRegistryDef

@export var entries: Array[Resource] = []

func is_empty() -> bool:
	return entries.is_empty()

func get_slot(slot_id: StringName):
	for slot_def in entries:
		if slot_def == null:
			continue
		if slot_def.slot_id == slot_id:
			return slot_def
	return null

func get_slots_ordered() -> Array:
	var ordered_slots: Array = []
	for slot_def in entries:
		if slot_def == null:
			continue
		ordered_slots.append(slot_def)
	ordered_slots.sort_custom(func(a, b) -> bool:
		if a.display_order != b.display_order:
			return a.display_order < b.display_order
		return String(a.slot_id) < String(b.slot_id)
	)
	return ordered_slots

func get_slots_for_section(section_id: StringName) -> Array:
	var section_slots: Array = []
	for slot_def in get_slots_ordered():
		if slot_def == null or slot_def.section_id != section_id:
			continue
		section_slots.append(slot_def)
	return section_slots
