extends Resource
class_name ForgeV2EditorSettingsState

## User preferences, independent of a Forge draft and its Undo history.
const DEFAULT_SAVE_FILE_PATH := "user://settings/forge_v2_editor_settings.tres"
const FREEHAND_SMOOTHING_DEFAULT := 4
const FREEHAND_SMOOTHING_MIN := 0
const FREEHAND_SMOOTHING_MAX := 10
const PersistentResourceStateIOScript = preload("res://core/models/persistent_resource_state_io.gd")

@export var save_file_path: String = DEFAULT_SAVE_FILE_PATH
@export_range(0, 10, 1) var freehand_smoothing_steps: int = FREEHAND_SMOOTHING_DEFAULT

static func load_or_create(save_path: String = DEFAULT_SAVE_FILE_PATH) -> ForgeV2EditorSettingsState:
	var settings := PersistentResourceStateIOScript.load_or_create(
		save_path, "res://core/models/forge_v2_editor_settings_state.gd"
	) as ForgeV2EditorSettingsState
	if settings == null:
		settings = (load("res://core/models/forge_v2_editor_settings_state.gd") as Script).new()
	settings.save_file_path = save_path
	settings.normalize()
	return settings

func normalize() -> void:
	freehand_smoothing_steps = clampi(
		freehand_smoothing_steps, FREEHAND_SMOOTHING_MIN, FREEHAND_SMOOTHING_MAX
	)

func persist() -> bool:
	normalize()
	return PersistentResourceStateIOScript.persist_resource(self, save_file_path)
