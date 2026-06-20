extends Resource
class_name BodyInventorySeedDef

@export var seed_id: StringName = &"body_inventory_seed_default"
@export var entries: Array[Resource] = []

func is_empty() -> bool:
	return entries.is_empty()
