extends Resource
class_name PlayerToolProfileLibraryState

const DEFAULT_SAVE_FILE_PATH := "user://forge/tool_presets/player_tool_profile_library_state.tres"
const PersistentResourceStateIOScript = preload("res://core/models/persistent_resource_state_io.gd")

const PROFILE_NAME_MAX_LENGTH := 36
const PROFILE_FAMILY_HANDLE := &"profile_family_handle"
const PROFILE_FAMILY_BASIC := &"profile_family_basic"

@export var saved_profiles: Array[Dictionary] = []
@export var selected_profile_id: StringName = StringName()
@export var save_file_path: String = DEFAULT_SAVE_FILE_PATH

static func load_or_create(save_path: String = DEFAULT_SAVE_FILE_PATH):
	return PersistentResourceStateIOScript.load_or_create(save_path, "res://core/models/player_tool_profile_library_state.gd")

func get_saved_profiles(profile_family: StringName = StringName()) -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	for profile: Dictionary in saved_profiles:
		if profile.is_empty():
			continue
		if profile_family != StringName() and StringName(profile.get("family", StringName())) != profile_family:
			continue
		profiles.append(profile.duplicate(true))
	return profiles

func get_saved_profile(profile_id: StringName) -> Dictionary:
	for profile: Dictionary in saved_profiles:
		if StringName(profile.get("profile_id", StringName())) == profile_id:
			return profile.duplicate(true)
	return {}

func save_profile(profile_data: Dictionary, requested_name: String = "") -> Dictionary:
	if profile_data.is_empty():
		return {}
	var profile_family: StringName = StringName(profile_data.get("family", PROFILE_FAMILY_HANDLE))
	var saved_profile := profile_data.duplicate(true)
	var profile_id: StringName = StringName(saved_profile.get("profile_id", StringName()))
	if profile_id == StringName():
		profile_id = _build_generated_profile_id(profile_family)
	saved_profile["profile_id"] = profile_id
	saved_profile["id"] = profile_id
	saved_profile["family"] = profile_family
	saved_profile["label"] = _resolve_available_profile_name(requested_name, profile_family, profile_id)
	saved_profile["updated_timestamp"] = Time.get_unix_time_from_system()
	if not saved_profile.has("created_timestamp") or float(saved_profile.get("created_timestamp", 0.0)) <= 0.0:
		saved_profile["created_timestamp"] = saved_profile["updated_timestamp"]
	var existing_index := _find_saved_profile_index(profile_id)
	if existing_index >= 0:
		saved_profiles[existing_index] = saved_profile
	else:
		saved_profiles.append(saved_profile)
	selected_profile_id = profile_id
	persist()
	return saved_profile.duplicate(true)

func remove_profile(profile_id: StringName) -> bool:
	var profile_index := _find_saved_profile_index(profile_id)
	if profile_index < 0:
		return false
	saved_profiles.remove_at(profile_index)
	if selected_profile_id == profile_id:
		selected_profile_id = StringName()
	persist()
	return true

func rename_profile(profile_id: StringName, requested_name: String) -> Dictionary:
	var profile_index := _find_saved_profile_index(profile_id)
	if profile_index < 0:
		return {}
	var profile := saved_profiles[profile_index].duplicate(true)
	var profile_family: StringName = StringName(profile.get("family", PROFILE_FAMILY_HANDLE))
	profile["label"] = _resolve_available_profile_name(requested_name, profile_family, profile_id)
	profile["updated_timestamp"] = Time.get_unix_time_from_system()
	saved_profiles[profile_index] = profile
	selected_profile_id = profile_id
	persist()
	return profile.duplicate(true)

func build_default_profile_name(profile_family: StringName) -> String:
	var base_name := "tool profile"
	if profile_family == PROFILE_FAMILY_HANDLE:
		base_name = "handle profile"
	return _resolve_available_profile_name("", profile_family, StringName(), base_name)

func persist() -> bool:
	return PersistentResourceStateIOScript.persist_resource(self, save_file_path)

func _find_saved_profile_index(profile_id: StringName) -> int:
	for index in range(saved_profiles.size()):
		var profile: Dictionary = saved_profiles[index]
		if StringName(profile.get("profile_id", StringName())) == profile_id:
			return index
	return -1

func _resolve_available_profile_name(
	requested_name: String,
	profile_family: StringName,
	current_profile_id: StringName = StringName(),
	default_base_name: String = ""
) -> String:
	var requested_name_was_empty := requested_name.strip_edges().is_empty()
	var cleaned_name := _sanitize_profile_name(requested_name)
	if cleaned_name.is_empty():
		cleaned_name = default_base_name.strip_edges()
	if cleaned_name.is_empty():
		cleaned_name = "handle profile" if profile_family == PROFILE_FAMILY_HANDLE else "tool profile"
	var base_name := _strip_trailing_profile_number(cleaned_name)
	if base_name.is_empty():
		base_name = cleaned_name
	var candidate := _build_numbered_profile_name(base_name, 1) if requested_name_was_empty else _clamp_profile_name(cleaned_name)
	if not _profile_name_exists(candidate, profile_family, current_profile_id):
		return candidate
	var profile_index := 1
	while profile_index < 10000:
		candidate = _build_numbered_profile_name(base_name, profile_index)
		if not _profile_name_exists(candidate, profile_family, current_profile_id):
			return candidate
		profile_index += 1
	return _clamp_profile_name("%s %s" % [base_name, str(Time.get_unix_time_from_system())])

func _profile_name_exists(profile_name: String, profile_family: StringName, ignored_profile_id: StringName) -> bool:
	var normalized_name := profile_name.strip_edges().to_lower()
	for profile: Dictionary in saved_profiles:
		if StringName(profile.get("profile_id", StringName())) == ignored_profile_id:
			continue
		if StringName(profile.get("family", StringName())) != profile_family:
			continue
		if String(profile.get("label", "")).strip_edges().to_lower() == normalized_name:
			return true
	return false

func _sanitize_profile_name(raw_name: String) -> String:
	var cleaned_name := raw_name.strip_edges()
	cleaned_name = cleaned_name.replace("\n", " ")
	cleaned_name = cleaned_name.replace("\r", " ")
	while cleaned_name.find("  ") >= 0:
		cleaned_name = cleaned_name.replace("  ", " ")
	return _clamp_profile_name(cleaned_name)

func _clamp_profile_name(profile_name: String) -> String:
	var cleaned_name := profile_name.strip_edges()
	if cleaned_name.length() <= PROFILE_NAME_MAX_LENGTH:
		return cleaned_name
	return cleaned_name.substr(0, PROFILE_NAME_MAX_LENGTH).strip_edges()

func _strip_trailing_profile_number(profile_name: String) -> String:
	var cleaned_name := profile_name.strip_edges()
	var last_space_index := cleaned_name.rfind(" ")
	if last_space_index < 0:
		return cleaned_name
	var suffix := cleaned_name.substr(last_space_index + 1)
	if not suffix.is_valid_int():
		return cleaned_name
	return cleaned_name.substr(0, last_space_index).strip_edges()

func _build_numbered_profile_name(base_name: String, profile_index: int) -> String:
	var suffix := " %d" % profile_index
	var resolved_base := base_name.strip_edges()
	var max_base_length := PROFILE_NAME_MAX_LENGTH - suffix.length()
	if resolved_base.length() > max_base_length:
		resolved_base = resolved_base.substr(0, max_base_length).strip_edges()
	return "%s%s" % [resolved_base, suffix]

func _build_generated_profile_id(profile_family: StringName) -> StringName:
	var prefix := "handle_profile" if profile_family == PROFILE_FAMILY_HANDLE else "tool_profile"
	return StringName("%s_%s_%d" % [prefix, str(Time.get_unix_time_from_system()), saved_profiles.size() + 1])
