extends Resource
class_name ForgeInventorySeedDef

@export var seed_id: StringName = &""
@export var entries: Array[Resource] = []

func is_empty() -> bool:
	return entries.is_empty()
