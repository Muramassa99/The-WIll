extends Resource
class_name PlayerBodyInventoryState

const DEFAULT_SAVE_FILE_PATH := "user://inventory/player_body_inventory_state.tres"
const ItemInstanceContainerSupportScript = preload("res://core/models/item_instance_container_support.gd")
const PersistentResourceStateIOScript = preload("res://core/models/persistent_resource_state_io.gd")

@export var owned_items: Array[Resource] = []
@export var save_file_path: String = DEFAULT_SAVE_FILE_PATH

static func load_or_create(save_path: String = DEFAULT_SAVE_FILE_PATH):
	return PersistentResourceStateIOScript.load_or_create(save_path, "res://core/models/player_body_inventory_state.gd")

func get_owned_items() -> Array[Resource]:
	return owned_items

func get_disassemblable_items() -> Array[Resource]:
	var disassemblable_items: Array[Resource] = []
	for owned_item: Resource in owned_items:
		if owned_item == null or not owned_item.is_disassemblable:
			continue
		disassemblable_items.append(owned_item)
	return disassemblable_items

func get_item(item_instance_id: StringName):
	return ItemInstanceContainerSupportScript.get_item(owned_items, item_instance_id)

func add_item(source_item: Resource):
	return ItemInstanceContainerSupportScript.add_item(
		owned_items,
		source_item,
		"body_item",
		Callable(self, "persist")
	)

func take_item(item_instance_id: StringName, amount: int = 0):
	return ItemInstanceContainerSupportScript.take_item(
		owned_items,
		item_instance_id,
		amount,
		Callable(self, "persist")
	)

func persist() -> bool:
	return PersistentResourceStateIOScript.persist_resource(self, save_file_path)
