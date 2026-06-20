extends Resource
class_name PlayerPersonalStorageState

const DEFAULT_SAVE_FILE_PATH := "user://storage/player_personal_storage_state.tres"
const ItemInstanceContainerSupportScript = preload("res://core/models/item_instance_container_support.gd")
const PersistentResourceStateIOScript = preload("res://core/models/persistent_resource_state_io.gd")

@export var stored_items: Array[Resource] = []
@export var save_file_path: String = DEFAULT_SAVE_FILE_PATH

static func load_or_create(save_path: String = DEFAULT_SAVE_FILE_PATH):
	return PersistentResourceStateIOScript.load_or_create(save_path, "res://core/models/player_personal_storage_state.gd")

func get_stored_items() -> Array[Resource]:
	return stored_items

func get_item(item_instance_id: StringName):
	return ItemInstanceContainerSupportScript.get_item(stored_items, item_instance_id)

func add_item(source_item: Resource):
	return ItemInstanceContainerSupportScript.add_item(
		stored_items,
		source_item,
		"storage_item",
		Callable(self, "persist")
	)

func take_item(item_instance_id: StringName, amount: int = 0):
	return ItemInstanceContainerSupportScript.take_item(
		stored_items,
		item_instance_id,
		amount,
		Callable(self, "persist")
	)

func persist() -> bool:
	return PersistentResourceStateIOScript.persist_resource(self, save_file_path)
