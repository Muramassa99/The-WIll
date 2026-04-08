extends Resource
class_name PlayerForgeWipLibraryState

const DEFAULT_SAVE_FILE_PATH := "user://forge/player_wip_library_state.tres"
const PersistentResourceStateIOScript = preload("res://core/models/persistent_resource_state_io.gd")

@export var saved_wips: Array[CraftedItemWIP] = []
@export var selected_wip_id: StringName = &""
@export var save_file_path: String = DEFAULT_SAVE_FILE_PATH

static func load_or_create(save_path: String = DEFAULT_SAVE_FILE_PATH):
	return PersistentResourceStateIOScript.load_or_create(save_path, "res://core/models/player_forge_wip_library_state.gd")

func has_saved_wips() -> bool:
	return not saved_wips.is_empty()

func get_saved_wips() -> Array[CraftedItemWIP]:
	return saved_wips

func get_saved_wip(saved_wip_id: StringName) -> CraftedItemWIP:
	for saved_wip: CraftedItemWIP in saved_wips:
		if saved_wip == null:
			continue
		if saved_wip.wip_id == saved_wip_id:
			return saved_wip
	return null

func get_saved_wip_clone(saved_wip_id: StringName) -> CraftedItemWIP:
	var saved_wip: CraftedItemWIP = get_saved_wip(saved_wip_id)
	if saved_wip == null:
		return null
	return saved_wip.duplicate(true) as CraftedItemWIP

func save_wip(source_wip: CraftedItemWIP) -> CraftedItemWIP:
	if source_wip == null:
		return null
	var saved_clone: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	var resolved_wip_id: StringName = _resolve_saved_wip_id(saved_clone)
	saved_clone.wip_id = resolved_wip_id
	saved_clone.forge_project_name = _resolve_forge_project_name(saved_clone)
	saved_clone.forge_project_notes = _resolve_forge_project_notes(saved_clone)
	saved_clone.stow_position_mode = CraftedItemWIP.normalize_stow_position_mode(saved_clone.stow_position_mode)
	saved_clone.grip_style_mode = CraftedItemWIP.resolve_supported_grip_style(
		saved_clone.grip_style_mode,
		saved_clone.forge_intent,
		saved_clone.equipment_context
	)
	var existing_index: int = _find_saved_wip_index(resolved_wip_id)
	if existing_index >= 0:
		saved_wips[existing_index] = saved_clone
	else:
		saved_wips.append(saved_clone)
	selected_wip_id = resolved_wip_id
	persist()
	return saved_clone.duplicate(true) as CraftedItemWIP

func duplicate_saved_wip(saved_wip_id: StringName) -> CraftedItemWIP:
	var source_wip: CraftedItemWIP = get_saved_wip(saved_wip_id)
	if source_wip == null:
		return null
	var duplicate_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	duplicate_wip.wip_id = _build_generated_wip_id()
	duplicate_wip.forge_project_name = _build_duplicate_project_name(duplicate_wip.forge_project_name)
	duplicate_wip.forge_project_notes = _resolve_forge_project_notes(duplicate_wip)
	duplicate_wip.stow_position_mode = CraftedItemWIP.normalize_stow_position_mode(duplicate_wip.stow_position_mode)
	duplicate_wip.grip_style_mode = CraftedItemWIP.resolve_supported_grip_style(
		duplicate_wip.grip_style_mode,
		duplicate_wip.forge_intent,
		duplicate_wip.equipment_context
	)
	saved_wips.append(duplicate_wip)
	selected_wip_id = duplicate_wip.wip_id
	persist()
	return duplicate_wip.duplicate(true) as CraftedItemWIP

func delete_saved_wip(saved_wip_id: StringName) -> bool:
	var saved_index: int = _find_saved_wip_index(saved_wip_id)
	if saved_index < 0:
		return false
	saved_wips.remove_at(saved_index)
	if selected_wip_id == saved_wip_id:
		selected_wip_id = saved_wips[0].wip_id if not saved_wips.is_empty() and saved_wips[0] != null else StringName()
	persist()
	return true

func set_selected_wip_id(saved_wip_id: StringName) -> void:
	selected_wip_id = saved_wip_id
	persist()

func persist() -> bool:
	return PersistentResourceStateIOScript.persist_resource(self, save_file_path)

func _find_saved_wip_index(saved_wip_id: StringName) -> int:
	for index: int in range(saved_wips.size()):
		var saved_wip: CraftedItemWIP = saved_wips[index]
		if saved_wip == null:
			continue
		if saved_wip.wip_id == saved_wip_id:
			return index
	return -1

func _resolve_saved_wip_id(saved_wip: CraftedItemWIP) -> StringName:
	if saved_wip == null:
		return StringName()
	var current_wip_id_text: String = String(saved_wip.wip_id)
	if current_wip_id_text.is_empty() or current_wip_id_text.begins_with("debug_") or current_wip_id_text.begins_with("draft_"):
		return _build_generated_wip_id()
	return saved_wip.wip_id

func _resolve_forge_project_name(saved_wip: CraftedItemWIP) -> String:
	if saved_wip == null:
		return _build_generated_project_name()
	var cleaned_name: String = saved_wip.forge_project_name.strip_edges()
	if cleaned_name.is_empty():
		return _build_generated_project_name()
	return cleaned_name

func _resolve_forge_project_notes(saved_wip: CraftedItemWIP) -> String:
	if saved_wip == null:
		return ""
	return saved_wip.forge_project_notes.strip_edges()

func _build_generated_wip_id() -> StringName:
	return StringName("player_wip_%s_%d" % [str(Time.get_unix_time_from_system()), saved_wips.size() + 1])

func _build_generated_project_name() -> String:
	return "Forge Project %03d" % (saved_wips.size() + 1)

func _build_duplicate_project_name(project_name: String) -> String:
	var cleaned_name: String = project_name.strip_edges()
	if cleaned_name.is_empty():
		cleaned_name = _build_generated_project_name()
	return "%s Copy" % cleaned_name

