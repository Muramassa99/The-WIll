extends Resource
class_name ProcessRuleRegistryDef

@export var registry_id: StringName = &""
@export var entries: Array[Resource] = []

func is_empty() -> bool:
	return entries.is_empty()
