extends Resource
class_name TierRegistryDef

@export var registry_id: StringName = &""
@export var entries: Array[TierDef] = []

func is_empty() -> bool:
	return entries.is_empty()
