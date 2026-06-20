extends Resource
class_name ForgeMaterialCatalogDef

@export var catalog_id: StringName = &""
@export var entries: Array[Resource] = []

func is_empty() -> bool:
	return entries.is_empty()

