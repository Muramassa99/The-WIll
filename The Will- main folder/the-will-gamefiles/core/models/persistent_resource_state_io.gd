extends RefCounted
class_name PersistentResourceStateIO

static func load_or_create(save_path: String, script_path: String) -> Resource:
	var loaded_state: Resource = null
	if FileAccess.file_exists(save_path):
		loaded_state = ResourceLoader.load(save_path)
	if loaded_state == null:
		var absolute_save_path: String = ProjectSettings.globalize_path(save_path)
		if FileAccess.file_exists(absolute_save_path):
			loaded_state = ResourceLoader.load(absolute_save_path)
	if loaded_state == null:
		var state_script: Script = load(script_path) as Script
		if state_script != null:
			loaded_state = state_script.new()
	if loaded_state != null:
		loaded_state.set("save_file_path", save_path)
	return loaded_state

static func persist_resource(state_resource: Resource, save_path: String) -> bool:
	if state_resource == null:
		return false
	ensure_save_directory(save_path)
	var save_error: Error = ResourceSaver.save(state_resource, save_path)
	if save_error == OK:
		return true
	return ResourceSaver.save(state_resource, ProjectSettings.globalize_path(save_path)) == OK

static func ensure_save_directory(save_path: String) -> void:
	var normalized_save_path: String = save_path.replace("\\", "/")
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
