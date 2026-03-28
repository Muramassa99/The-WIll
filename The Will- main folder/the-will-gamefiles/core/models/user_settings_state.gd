extends Resource
class_name UserSettingsState

const DEFAULT_SAVE_FILE_PATH := "user://settings/user_settings_state.tres"

const SCALE_SMALL := &"small"
const SCALE_NORMAL := &"normal"
const SCALE_LARGE := &"large"

const WINDOWED := &"windowed"
const BORDERLESS := &"borderless"
const FULLSCREEN := &"fullscreen"

const DEFAULT_RESOLUTION := Vector2i(1600, 900)

@export var save_file_path: String = DEFAULT_SAVE_FILE_PATH
@export var window_mode: StringName = WINDOWED
@export var display_index: int = 0
@export var resolution: Vector2i = DEFAULT_RESOLUTION
@export var vsync_enabled: bool = true
@export var max_fps: int = 120
@export var render_scale_preset: StringName = SCALE_NORMAL
@export var master_volume_linear: float = 1.0
@export var master_muted: bool = false
@export var ui_scale_preset: StringName = SCALE_NORMAL
@export var text_scale_preset: StringName = SCALE_NORMAL
@export var keybindings: Dictionary = {}

static func load_or_create(save_path: String = DEFAULT_SAVE_FILE_PATH) -> UserSettingsState:
	var loaded_state: UserSettingsState = null
	if FileAccess.file_exists(save_path):
		loaded_state = ResourceLoader.load(save_path) as UserSettingsState
	if loaded_state == null:
		loaded_state = UserSettingsState.new()
	loaded_state.save_file_path = save_path
	loaded_state._ensure_defaults()
	return loaded_state

func persist() -> bool:
	_ensure_save_directory()
	return ResourceSaver.save(self, save_file_path) == OK

func get_keybinding_data(action_name: StringName, fallback_data: Dictionary = {}) -> Dictionary:
	var key_name: String = String(action_name)
	if not keybindings.has(key_name):
		return fallback_data.duplicate(true)
	var stored_value: Variant = keybindings[key_name]
	if stored_value is Dictionary:
		return (stored_value as Dictionary).duplicate(true)
	if stored_value is int:
		return _build_keybinding_data(int(stored_value))
	return fallback_data.duplicate(true)

func set_keybinding_data(action_name: StringName, binding_data: Dictionary) -> void:
	keybindings[String(action_name)] = binding_data.duplicate(true)

func set_keybinding_event(action_name: StringName, key_event: InputEventKey) -> void:
	keybindings[String(action_name)] = _serialize_key_event(key_event)

func reset_display_to_defaults() -> void:
	window_mode = WINDOWED
	display_index = 0
	resolution = DEFAULT_RESOLUTION
	vsync_enabled = true
	max_fps = 120
	render_scale_preset = SCALE_NORMAL

func reset_audio_to_defaults() -> void:
	master_volume_linear = 1.0
	master_muted = false

func reset_interface_to_defaults() -> void:
	ui_scale_preset = SCALE_NORMAL
	text_scale_preset = SCALE_NORMAL

func reset_keybindings_for_actions(action_names: Array[StringName]) -> void:
	for action_name: StringName in action_names:
		keybindings.erase(String(action_name))

func reset_all_to_defaults(include_keybindings: bool = false) -> void:
	reset_display_to_defaults()
	reset_audio_to_defaults()
	reset_interface_to_defaults()
	if include_keybindings:
		keybindings.clear()

func get_ui_scale_factor() -> float:
	return _preset_to_scale(ui_scale_preset, 0.9, 1.0, 1.15)

func get_text_scale_factor() -> float:
	return _preset_to_scale(text_scale_preset, 0.9, 1.0, 1.15)

func get_render_scale_factor() -> float:
	return _preset_to_scale(render_scale_preset, 0.8, 1.0, 1.2)

func _ensure_defaults() -> void:
	if resolution == Vector2i.ZERO:
		resolution = DEFAULT_RESOLUTION
	if window_mode == StringName():
		window_mode = WINDOWED
	if display_index < 0:
		display_index = 0
	if max_fps < 0:
		max_fps = 0
	if render_scale_preset == StringName():
		render_scale_preset = SCALE_NORMAL
	if ui_scale_preset == StringName():
		ui_scale_preset = SCALE_NORMAL
	if text_scale_preset == StringName():
		text_scale_preset = SCALE_NORMAL
	if keybindings == null:
		keybindings = {}

func _ensure_save_directory() -> void:
	var save_directory_path: String = save_file_path.get_base_dir()
	if save_directory_path.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_directory_path))

func _preset_to_scale(preset: StringName, small_value: float, normal_value: float, large_value: float) -> float:
	match preset:
		SCALE_SMALL:
			return small_value
		SCALE_LARGE:
			return large_value
		_:
			return normal_value

func _serialize_key_event(key_event: InputEventKey) -> Dictionary:
	return {
		"physical_keycode": int(key_event.physical_keycode),
		"keycode": int(key_event.keycode),
		"ctrl": key_event.ctrl_pressed,
		"shift": key_event.shift_pressed,
		"alt": key_event.alt_pressed,
		"meta": key_event.meta_pressed
	}

func _build_keybinding_data(keycode: int) -> Dictionary:
	return {
		"physical_keycode": keycode,
		"keycode": keycode,
		"ctrl": false,
		"shift": false,
		"alt": false,
		"meta": false
	}
