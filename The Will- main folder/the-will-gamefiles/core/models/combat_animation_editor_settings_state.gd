extends Resource
class_name CombatAnimationEditorSettingsState

## Authoring preferences, independent of weapon drafts and saved skill timing.
const DEFAULT_SAVE_FILE_PATH := "user://settings/combat_animation_editor_settings.tres"
const MotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const PersistentResourceStateIOScript = preload("res://core/models/persistent_resource_state_io.gd")

@export var save_file_path: String = DEFAULT_SAVE_FILE_PATH
@export_range(0.1, 2.0, 0.01) var default_transition_duration_seconds: float = MotionNodeScript.DEFAULT_TRANSITION_DURATION_SECONDS

static func load_or_create(save_path: String = DEFAULT_SAVE_FILE_PATH) -> CombatAnimationEditorSettingsState:
	var settings := PersistentResourceStateIOScript.load_or_create(
		save_path, "res://core/models/combat_animation_editor_settings_state.gd"
	) as CombatAnimationEditorSettingsState
	if settings == null:
		settings = (load("res://core/models/combat_animation_editor_settings_state.gd") as Script).new()
	settings.save_file_path = save_path
	settings.normalize()
	return settings

func normalize() -> void:
	if not is_finite(default_transition_duration_seconds):
		default_transition_duration_seconds = MotionNodeScript.DEFAULT_TRANSITION_DURATION_SECONDS
	default_transition_duration_seconds = clampf(
		snappedf(default_transition_duration_seconds, MotionNodeScript.TRANSITION_DURATION_STEP_SECONDS),
		MotionNodeScript.MIN_AUTHORED_TRANSITION_DURATION_SECONDS,
		MotionNodeScript.MAX_AUTHORED_TRANSITION_DURATION_SECONDS
	)

func persist() -> bool:
	normalize()
	return PersistentResourceStateIOScript.persist_resource(self, save_file_path)
