extends Resource
class_name PlayerEquipmentState

const DEFAULT_SAVE_FILE_PATH := "user://inventory/player_equipment_state.tres"
const EquippedSlotInstanceScript = preload("res://core/models/equipped_slot_instance.gd")

@export var equipped_slots: Array[Resource] = []
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
		loaded_state = load("res://core/models/player_equipment_state.gd").new()
	loaded_state.save_file_path = save_path
	return loaded_state

func get_equipped_slots() -> Array[Resource]:
	return equipped_slots

func get_equipped_slot(slot_id: StringName):
	for equipped_slot in equipped_slots:
		if equipped_slot == null:
			continue
		if equipped_slot.slot_id == slot_id:
			return equipped_slot
	return null

func set_equipped_slot(source_entry: Resource):
	if source_entry == null or source_entry.slot_id == StringName():
		return null
	var equipped_entry: Resource = source_entry.duplicate(true)
	var existing_index: int = _find_equipped_slot_index(equipped_entry.slot_id)
	if equipped_entry.entry_kind == StringName():
		if existing_index >= 0:
			equipped_slots.remove_at(existing_index)
			persist()
		return null
	if existing_index >= 0:
		equipped_slots[existing_index] = equipped_entry
	else:
		equipped_slots.append(equipped_entry)
	persist()
	return equipped_entry.duplicate(true)

func clear_slot(slot_id: StringName) -> bool:
	var existing_index: int = _find_equipped_slot_index(slot_id)
	if existing_index < 0:
		return false
	equipped_slots.remove_at(existing_index)
	persist()
	return true

func equip_forge_test_wip(slot_id: StringName, source_wip: CraftedItemWIP):
	if slot_id == StringName() or source_wip == null or source_wip.wip_id == StringName():
		return null
	var equipped_entry = EquippedSlotInstanceScript.new()
	equipped_entry.slot_id = slot_id
	equipped_entry.entry_kind = EquippedSlotInstanceScript.KIND_FORGE_TEST_WIP
	equipped_entry.source_wip_id = source_wip.wip_id
	equipped_entry.display_name = source_wip.forge_project_name.strip_edges()
	equipped_entry.is_forge_internal_only = true
	return set_equipped_slot(equipped_entry)

func equip_stored_item(slot_id: StringName, stored_item: Resource):
	if slot_id == StringName() or stored_item == null or stored_item.item_instance_id == StringName():
		return null
	var equipped_entry = EquippedSlotInstanceScript.new()
	equipped_entry.slot_id = slot_id
	equipped_entry.entry_kind = EquippedSlotInstanceScript.KIND_STORED_ITEM
	equipped_entry.source_item_instance_id = stored_item.item_instance_id
	equipped_entry.display_name = stored_item.get_resolved_display_name()
	equipped_entry.is_forge_internal_only = false
	return set_equipped_slot(equipped_entry)

func persist() -> bool:
	_ensure_save_directory()
	var save_error: Error = ResourceSaver.save(self, save_file_path)
	if save_error == OK:
		return true
	return ResourceSaver.save(self, ProjectSettings.globalize_path(save_file_path)) == OK

func _find_equipped_slot_index(slot_id: StringName) -> int:
	for index: int in range(equipped_slots.size()):
		var equipped_slot = equipped_slots[index]
		if equipped_slot == null:
			continue
		if equipped_slot.slot_id == slot_id:
			return index
	return -1

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
