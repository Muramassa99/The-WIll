extends "res://runtime/player/grip/character_hand_anatomy_store.gd"

## Tool-only persistence adapter. Runtime owns validation and never saves
## or prepares anatomy on acquisition. Existing saved definitions are immutable.

func save_new(definition: Resource, path: String) -> Dictionary:
	var target := _checked_path(path)
	if target.is_empty():
		return _failure("invalid_definition_path")
	if FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target)):
		return _failure("definition_already_exists", target)
	var validation := validate(definition)
	if not bool(validation.valid):
		return validation
	var directory := ProjectSettings.globalize_path(target).get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK:
		return {"valid": false, "status": "cannot_create_definition_directory", "path": target, "error": directory_error}
	if FileAccess.file_exists(target):
		return _failure("definition_already_exists", target)
	var save_error := ResourceSaver.save(definition, target)
	if save_error != OK:
		return {"valid": false, "status": "definition_save_failed", "path": target, "error": save_error}
	return {"valid": true, "status": "definition_saved", "path": target, "resource": definition}


func load_matching(path: String, expected_signature: String, expected_revision: String) -> Dictionary:
	var target := _checked_path(path)
	if target.is_empty() or expected_signature.is_empty() or expected_revision.is_empty():
		return _failure("invalid_load_expectation", path)
	if not FileAccess.file_exists(target):
		return _failure("definition_missing", target)
	# Godot 4.7: bypass cache for this Resource and its subresources. Its script
	# remains an ordinary external dependency; no mutable data Resource is cached.
	var definition := ResourceLoader.load(target, "Resource", ResourceLoader.CACHE_MODE_IGNORE)
	if definition == null:
		return _failure("definition_load_failed", target)
	var validation := validate(definition)
	if not bool(validation.valid):
		validation["path"] = target
		return validation
	if String(definition.get("source_signature")) != expected_signature:
		return _failure("source_signature_mismatch", target)
	if String(definition.get("preparation_revision")) != expected_revision:
		return _failure("preparation_revision_mismatch", target)
	return {"valid": true, "status": "matching_definition_loaded", "path": target, "resource": definition}


func _checked_path(path: String) -> String:
	var normalized := path.replace("\\", "/").strip_edges()
	if normalized.get_extension().to_lower() not in ["tres", "res"]:
		return ""
	if not normalized.begins_with("res://") and not normalized.begins_with("user://") and not normalized.is_absolute_path():
		return ""
	return normalized
