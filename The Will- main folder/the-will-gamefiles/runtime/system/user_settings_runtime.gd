extends RefCounted
class_name UserSettingsRuntime

const UserSettingsStateScript = preload("res://core/models/user_settings_state.gd")

const FONT_SIZE_PROPERTIES := [&"font_size", &"normal_font_size"]

const ACTION_DEFINITIONS: Array[Dictionary] = [
	{"action": "move_forward", "display_name": "Move Forward", "category": "movement", "binding": {"physical_keycode": KEY_W, "keycode": KEY_W, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "move_back", "display_name": "Move Back", "category": "movement", "binding": {"physical_keycode": KEY_S, "keycode": KEY_S, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "move_left", "display_name": "Move Left", "category": "movement", "binding": {"physical_keycode": KEY_A, "keycode": KEY_A, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "move_right", "display_name": "Move Right", "category": "movement", "binding": {"physical_keycode": KEY_D, "keycode": KEY_D, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "jump", "display_name": "Jump", "category": "movement", "binding": {"physical_keycode": KEY_SPACE, "keycode": KEY_SPACE, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "sprint", "display_name": "Sprint", "category": "movement", "binding": {"physical_keycode": KEY_SHIFT, "keycode": KEY_SHIFT, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "dodge", "display_name": "Dodge", "category": "movement", "binding": {"physical_keycode": KEY_CTRL, "keycode": KEY_CTRL, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "interact", "display_name": "Interact", "category": "movement", "binding": {"physical_keycode": KEY_F, "keycode": KEY_F, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "auto_run", "display_name": "Auto-Run", "category": "movement", "binding": {"physical_keycode": KEY_EQUAL, "keycode": KEY_EQUAL, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "attack_primary", "display_name": "Primary Attack", "category": "combat", "binding": {"physical_keycode": KEY_NONE, "keycode": KEY_NONE, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "attack_secondary", "display_name": "Secondary Attack", "category": "combat", "binding": {"physical_keycode": KEY_NONE, "keycode": KEY_NONE, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "skill_mobility", "display_name": "Mobility Skill", "category": "combat", "binding": {"physical_keycode": KEY_Q, "keycode": KEY_Q, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "skill_defense", "display_name": "Defense Skill", "category": "combat", "binding": {"physical_keycode": KEY_E, "keycode": KEY_E, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "target_cycle", "display_name": "Cycle Target", "category": "combat", "binding": {"physical_keycode": KEY_TAB, "keycode": KEY_TAB, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "quick_use_item", "display_name": "Quick Use Item", "category": "combat", "binding": {"physical_keycode": KEY_X, "keycode": KEY_X, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "camera_zoom_in", "display_name": "Camera Zoom In", "category": "camera", "binding": {"physical_keycode": KEY_PAGEUP, "keycode": KEY_PAGEUP, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "camera_zoom_out", "display_name": "Camera Zoom Out", "category": "camera", "binding": {"physical_keycode": KEY_PAGEDOWN, "keycode": KEY_PAGEDOWN, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "camera_reset", "display_name": "Camera Reset", "category": "camera", "binding": {"physical_keycode": KEY_HOME, "keycode": KEY_HOME, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "camera_free_look_toggle", "display_name": "Free Look Toggle", "category": "camera", "binding": {"physical_keycode": KEY_NONE, "keycode": KEY_NONE, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "menu_toggle", "display_name": "System Menu", "category": "ui_menu", "binding": {"physical_keycode": KEY_ESCAPE, "keycode": KEY_ESCAPE, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "ui_cancel", "display_name": "Close Current Menu", "category": "ui_menu", "binding": {"physical_keycode": KEY_ESCAPE, "keycode": KEY_ESCAPE, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "ui_inventory", "display_name": "Open Inventory", "category": "ui_menu", "binding": {"physical_keycode": KEY_I, "keycode": KEY_I, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "ui_map", "display_name": "Open Map", "category": "ui_menu", "binding": {"physical_keycode": KEY_M, "keycode": KEY_M, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "ui_character", "display_name": "Open Character", "category": "ui_menu", "binding": {"physical_keycode": KEY_C, "keycode": KEY_C, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "ui_social", "display_name": "Open Social", "category": "ui_menu", "binding": {"physical_keycode": KEY_O, "keycode": KEY_O, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "ui_settings", "display_name": "Open Settings", "category": "ui_menu", "binding": {"physical_keycode": KEY_F10, "keycode": KEY_F10, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "toggle_hud", "display_name": "Toggle HUD", "category": "ui_menu", "binding": {"physical_keycode": KEY_F11, "keycode": KEY_F11, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "screenshot", "display_name": "Screenshot", "category": "ui_menu", "binding": {"physical_keycode": KEY_F12, "keycode": KEY_F12, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "forge_bake", "display_name": "Bake Active WIP", "category": "forge", "binding": {"physical_keycode": KEY_ENTER, "keycode": KEY_ENTER, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "forge_reset", "display_name": "Reset Active WIP", "category": "forge", "binding": {"physical_keycode": KEY_R, "keycode": KEY_R, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "forge_save_wip", "display_name": "Save WIP", "category": "forge", "binding": {"physical_keycode": KEY_S, "keycode": KEY_S, "ctrl": true, "shift": false, "alt": false, "meta": false}},
	{"action": "forge_toggle_grid", "display_name": "Toggle Grid", "category": "forge", "binding": {"physical_keycode": KEY_F, "keycode": KEY_F, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "forge_toggle_ghost", "display_name": "Toggle Ghost Layer", "category": "forge", "binding": {"physical_keycode": KEY_G, "keycode": KEY_G, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "forge_cycle_tool_category", "display_name": "Cycle Tool Category", "category": "forge", "binding": {"physical_keycode": KEY_T, "keycode": KEY_T, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "forge_focus_cycle", "display_name": "Cycle Forge Focus Region", "category": "forge", "binding": {"physical_keycode": KEY_TAB, "keycode": KEY_TAB, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "forge_layer_down", "display_name": "Layer Down", "category": "forge", "binding": {"physical_keycode": KEY_Q, "keycode": KEY_Q, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "forge_layer_up", "display_name": "Layer Up", "category": "forge", "binding": {"physical_keycode": KEY_E, "keycode": KEY_E, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "forge_plane_xy", "display_name": "Select XY Plane", "category": "forge", "binding": {"physical_keycode": KEY_1, "keycode": KEY_1, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "forge_plane_zx", "display_name": "Select ZX Plane", "category": "forge", "binding": {"physical_keycode": KEY_2, "keycode": KEY_2, "ctrl": false, "shift": false, "alt": false, "meta": false}},
	{"action": "forge_plane_zy", "display_name": "Select ZY Plane", "category": "forge", "binding": {"physical_keycode": KEY_3, "keycode": KEY_3, "ctrl": false, "shift": false, "alt": false, "meta": false}}
]

const CATEGORY_DISPLAY_NAMES := {
	"movement": "Movement",
	"combat": "Combat",
	"camera": "Camera",
	"ui_menu": "UI / Menu",
	"forge": "Forge"
}

static func ensure_input_actions(settings_state: UserSettingsState) -> void:
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action_name: StringName = StringName(String(definition.get("action", "")))
		if action_name == StringName():
			continue
		var default_binding: Dictionary = get_default_binding_data(action_name)
		var resolved_binding: Dictionary = settings_state.get_keybinding_data(action_name, default_binding) if settings_state != null else default_binding
		_ensure_key_action(action_name, _build_key_event_from_data(resolved_binding))

static func apply_settings(settings_state: UserSettingsState, root_window: Window) -> void:
	if settings_state == null:
		return
	_apply_display_settings(settings_state)
	_apply_audio_settings(settings_state)
	if root_window != null:
		root_window.content_scale_factor = settings_state.get_ui_scale_factor()
		root_window.scaling_3d_scale = settings_state.get_render_scale_factor()
		_apply_text_scale_recursive(root_window, settings_state.get_text_scale_factor())

static func get_categories() -> Array[String]:
	var categories: Array[String] = []
	for definition: Dictionary in ACTION_DEFINITIONS:
		var category_name: String = String(definition.get("category", ""))
		if category_name.is_empty() or categories.has(category_name):
			continue
		categories.append(category_name)
	return categories

static func get_category_display_name(category_name: String) -> String:
	return String(CATEGORY_DISPLAY_NAMES.get(category_name, category_name.capitalize()))

static func get_actions_for_category(category_name: String) -> Array[StringName]:
	var actions: Array[StringName] = []
	for definition: Dictionary in ACTION_DEFINITIONS:
		if String(definition.get("category", "")) != category_name:
			continue
		actions.append(StringName(String(definition.get("action", ""))))
	return actions

static func get_action_display_name(action_name: StringName) -> String:
	for definition: Dictionary in ACTION_DEFINITIONS:
		if String(definition.get("action", "")) == String(action_name):
			return String(definition.get("display_name", String(action_name)))
	return String(action_name)

static func get_default_keycode(action_name: StringName) -> Key:
	var binding_data: Dictionary = get_default_binding_data(action_name)
	return int(binding_data.get("physical_keycode", KEY_NONE)) as Key

static func get_default_binding_data(action_name: StringName) -> Dictionary:
	for definition: Dictionary in ACTION_DEFINITIONS:
		if String(definition.get("action", "")) == String(action_name):
			return (definition.get("binding", {}) as Dictionary).duplicate(true)
	return {}

static func get_keybinding_label(binding_data: Dictionary) -> String:
	var event: InputEventKey = _build_key_event_from_data(binding_data)
	if event == null or (event.physical_keycode == KEY_NONE and event.keycode == KEY_NONE):
		return "Unbound"
	var parts: Array[String] = []
	if event.ctrl_pressed:
		parts.append("Ctrl")
	if event.shift_pressed:
		parts.append("Shift")
	if event.alt_pressed:
		parts.append("Alt")
	if event.meta_pressed:
		parts.append("Meta")
	var resolved_keycode: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	parts.append(OS.get_keycode_string(resolved_keycode))
	return "+".join(parts)

static func _ensure_key_action(action_name: StringName, key_event: InputEventKey) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	_clear_key_events(action_name)
	if key_event == null or (key_event.physical_keycode == KEY_NONE and key_event.keycode == KEY_NONE):
		return
	InputMap.action_add_event(action_name, key_event)

static func _clear_key_events(action_name: StringName) -> void:
	var events: Array[InputEvent] = InputMap.action_get_events(action_name)
	for event: InputEvent in events:
		if event is InputEventKey:
			InputMap.action_erase_event(action_name, event)

static func _apply_display_settings(settings_state: UserSettingsState) -> void:
	if OS.has_feature("headless"):
		return
	var screen_count: int = DisplayServer.get_screen_count()
	var resolved_display_index: int = clampi(settings_state.display_index, 0, maxi(screen_count - 1, 0))
	DisplayServer.window_set_current_screen(resolved_display_index)
	var window_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
	var borderless_enabled: bool = false
	if settings_state.window_mode == UserSettingsStateScript.BORDERLESS:
		borderless_enabled = true
	if settings_state.window_mode == UserSettingsStateScript.FULLSCREEN:
		window_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, borderless_enabled)
	DisplayServer.window_set_mode(window_mode)
	if window_mode == DisplayServer.WINDOW_MODE_WINDOWED and settings_state.resolution != Vector2i.ZERO:
		DisplayServer.window_set_size(settings_state.resolution)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings_state.vsync_enabled else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = settings_state.max_fps

static func _apply_audio_settings(settings_state: UserSettingsState) -> void:
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	if master_bus_index < 0:
		return
	AudioServer.set_bus_mute(master_bus_index, settings_state.master_muted)
	if settings_state.master_muted:
		AudioServer.set_bus_volume_db(master_bus_index, -80.0)
		return
	var resolved_volume: float = clampf(settings_state.master_volume_linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(maxf(resolved_volume, 0.0001)))

static func _apply_text_scale_recursive(node: Node, text_scale_factor: float) -> void:
	if node is Control:
		_apply_control_text_scale(node as Control, text_scale_factor)
	for child: Node in node.get_children():
		_apply_text_scale_recursive(child, text_scale_factor)

static func _apply_control_text_scale(control: Control, text_scale_factor: float) -> void:
	var baseline_sizes: Dictionary = {}
	if control.has_meta("baseline_font_sizes"):
		baseline_sizes = control.get_meta("baseline_font_sizes") as Dictionary
	else:
		for property_name_value in FONT_SIZE_PROPERTIES:
			var property_name: StringName = property_name_value
			baseline_sizes[String(property_name)] = control.get_theme_font_size(property_name)
		control.set_meta("baseline_font_sizes", baseline_sizes)
	for property_name_text in baseline_sizes.keys():
		var baseline_size: int = int(baseline_sizes[property_name_text])
		if baseline_size <= 0:
			continue
		control.add_theme_font_size_override(StringName(property_name_text), maxi(int(round(float(baseline_size) * text_scale_factor)), 1))

static func _build_key_event_from_data(binding_data: Dictionary) -> InputEventKey:
	if binding_data.is_empty():
		return null
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = int(binding_data.get("physical_keycode", KEY_NONE)) as Key
	key_event.keycode = int(binding_data.get("keycode", key_event.physical_keycode)) as Key
	key_event.ctrl_pressed = bool(binding_data.get("ctrl", false))
	key_event.shift_pressed = bool(binding_data.get("shift", false))
	key_event.alt_pressed = bool(binding_data.get("alt", false))
	key_event.meta_pressed = bool(binding_data.get("meta", false))
	return key_event
