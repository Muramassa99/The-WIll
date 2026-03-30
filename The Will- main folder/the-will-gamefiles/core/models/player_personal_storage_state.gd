extends Resource
class_name PlayerPersonalStorageState

const DEFAULT_SAVE_FILE_PATH := "user://storage/player_personal_storage_state.tres"

@export var stored_items: Array[Resource] = []
@export var save_file_path: String = DEFAULT_SAVE_FILE_PATH

static func load_or_create(save_path: String = DEFAULT_SAVE_FILE_PATH):
	var loaded_state: Resource = null
	if FileAccess.file_exists(save_path):
		loaded_state = ResourceLoader.load(save_path)
	if loaded_state == null:
		var absolute_save_path: String = ProjectSettings.globalize_path(save_path)
		if FileAccess.file_exists(absolute_save_path):
			loaded_state = ResourceLoader.load(absolute_save_path)
	if loaded_state == null:
		loaded_state = load("res://core/models/player_personal_storage_state.gd").new()
	loaded_state.save_file_path = save_path
	return loaded_state

func get_stored_items() -> Array[Resource]:
	return stored_items

func get_item(item_instance_id: StringName):
	for stored_item: Resource in stored_items:
		if stored_item == null:
			continue
		if stored_item.item_instance_id == item_instance_id:
			return stored_item
	return null

func add_item(source_item: Resource):
	if source_item == null:
		return null
	var stored_item: Resource = source_item.duplicate(true)
	stored_item.item_instance_id = _resolve_item_instance_id(stored_item)
	var stack_target: Resource = _find_stack_target(stored_item)
	if stack_target != null:
		stack_target.stack_count += maxi(stored_item.stack_count, 1)
		persist()
		return stack_target.duplicate(true)
	stored_items.append(stored_item)
	persist()
	return stored_item.duplicate(true)

func take_item(item_instance_id: StringName, amount: int = 0):
	var stored_item_index: int = _find_item_index(item_instance_id)
	if stored_item_index < 0:
		return null
	var stored_item: Resource = stored_items[stored_item_index]
	if stored_item == null:
		return null
	var resolved_amount: int = stored_item.stack_count if amount <= 0 else mini(amount, stored_item.stack_count)
	var taken_item: Resource = stored_item.duplicate(true)
	taken_item.stack_count = resolved_amount
	if resolved_amount >= stored_item.stack_count:
		stored_items.remove_at(stored_item_index)
	else:
		stored_item.stack_count -= resolved_amount
	persist()
	return taken_item

func persist() -> bool:
	_ensure_save_directory()
	var save_error: Error = ResourceSaver.save(self, save_file_path)
	if save_error == OK:
		return true
	return ResourceSaver.save(self, ProjectSettings.globalize_path(save_file_path)) == OK

func _find_item_index(item_instance_id: StringName) -> int:
	for index: int in range(stored_items.size()):
		var stored_item = stored_items[index]
		if stored_item == null:
			continue
		if stored_item.item_instance_id == item_instance_id:
			return index
	return -1

func _find_stack_target(source_item: Resource):
	for stored_item: Resource in stored_items:
		if stored_item == null:
			continue
		if stored_item.is_stack_equivalent_to(source_item):
			return stored_item
	return null

func _resolve_item_instance_id(source_item: Resource) -> StringName:
	if source_item == null:
		return StringName()
	if source_item.item_instance_id == StringName():
		return _build_generated_item_instance_id()
	if _find_item_index(source_item.item_instance_id) >= 0:
		return _build_generated_item_instance_id()
	return source_item.item_instance_id

func _build_generated_item_instance_id() -> StringName:
	return StringName("storage_item_%s_%d" % [str(Time.get_unix_time_from_system()), stored_items.size() + 1])

func _ensure_save_directory() -> void:
	var normalized_save_path: String = save_file_path.replace("\\", "/")
	if normalized_save_path.begins_with("user://"):
		var relative_save_path: String = normalized_save_path.trim_prefix("user://")
		var last_separator_index: int = relative_save_path.rfind("/")
		if last_separator_index < 0:
			return
		var relative_directory_path: String = relative_save_path.substr(0, last_separator_index)
		if relative_directory_path.is_empty():
			return
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://%s" % relative_directory_path))
		return
	var save_directory_path: String = normalized_save_path.get_base_dir()
	if save_directory_path.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_directory_path))
