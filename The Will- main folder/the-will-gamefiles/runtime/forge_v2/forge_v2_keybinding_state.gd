extends Resource
class_name ForgeV2KeybindingState

const DEFAULT_SAVE_FILE_PATH := "user://settings/forge_v2_keybindings.json"

const ACTION_PAINT_MATERIAL := &"forge_v2_paint_material"
const ACTION_VIEW_ORBIT := &"forge_v2_view_orbit"
const ACTION_VIEW_PAN := &"forge_v2_view_pan"
const ACTION_VIEW_PAN_SECONDARY := &"forge_v2_view_pan_secondary"
const ACTION_VIEW_ZOOM_IN := &"forge_v2_view_zoom_in"
const ACTION_VIEW_ZOOM_OUT := &"forge_v2_view_zoom_out"
const ACTION_VIEW_FIT := &"forge_v2_view_fit"
const ACTION_VIEW_RESET := &"forge_v2_view_reset"
const ACTION_TOOL_VOLUME_STROKE := &"forge_v2_tool_volume_stroke"
const ACTION_TOOL_SPLINE_LINE := &"forge_v2_tool_spline_line"
const ACTION_SPLINE_FINISH := &"forge_v2_spline_finish"

const ACTION_DEFINITIONS: Array[Dictionary] = [
	{
		"action": ACTION_PAINT_MATERIAL,
		"display_name": "Place / Paint Material",
		"binding": {"mouse_button": MOUSE_BUTTON_LEFT},
	},
	{
		"action": ACTION_VIEW_ORBIT,
		"display_name": "Orbit View",
		"binding": {"mouse_button": MOUSE_BUTTON_RIGHT},
	},
	{
		"action": ACTION_VIEW_PAN,
		"display_name": "Pan View",
		"binding": {"mouse_button": MOUSE_BUTTON_MIDDLE},
	},
	{
		"action": ACTION_VIEW_PAN_SECONDARY,
		"display_name": "Pan View Alternate",
		"binding": {"physical_keycode": KEY_C, "keycode": KEY_C, "mouse_button": MOUSE_BUTTON_RIGHT},
	},
	{
		"action": ACTION_VIEW_ZOOM_IN,
		"display_name": "Zoom In",
		"binding": {"mouse_button": MOUSE_BUTTON_WHEEL_UP},
	},
	{
		"action": ACTION_VIEW_ZOOM_OUT,
		"display_name": "Zoom Out",
		"binding": {"mouse_button": MOUSE_BUTTON_WHEEL_DOWN},
	},
	{
		"action": ACTION_VIEW_FIT,
		"display_name": "Fit View",
		"binding": {"physical_keycode": KEY_F, "keycode": KEY_F},
	},
	{
		"action": ACTION_VIEW_RESET,
		"display_name": "Reset View",
		"binding": {"physical_keycode": KEY_HOME, "keycode": KEY_HOME},
	},
	{
		"action": ACTION_TOOL_VOLUME_STROKE,
		"display_name": "Select Volume Stroke Tool",
		"binding": {"physical_keycode": KEY_B, "keycode": KEY_B},
	},
	{
		"action": ACTION_TOOL_SPLINE_LINE,
		"display_name": "Select Spline Line Tool",
		"binding": {"physical_keycode": KEY_L, "keycode": KEY_L},
	},
	{
		"action": ACTION_SPLINE_FINISH,
		"display_name": "Finish Spline Line",
		"binding": {},
	},
]

@export var save_file_path: String = DEFAULT_SAVE_FILE_PATH
@export var bindings: Dictionary = {}

static func load_or_create(save_path: String = DEFAULT_SAVE_FILE_PATH) -> Resource:
	var state_script: Script = load("res://runtime/forge_v2/forge_v2_keybinding_state.gd") as Script
	var loaded_state: Resource = state_script.new() if state_script != null else null
	if loaded_state == null:
		return null
	loaded_state.set("save_file_path", save_path)
	if FileAccess.file_exists(save_path):
		var file := FileAccess.open(save_path, FileAccess.READ)
		if file != null:
			var parsed_data: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed_data is Dictionary:
				var parsed_dictionary: Dictionary = parsed_data as Dictionary
				loaded_state.set("bindings", parsed_dictionary.get("bindings", {}) as Dictionary)
	if loaded_state.has_method("normalize"):
		loaded_state.call("normalize")
	return loaded_state

func persist() -> bool:
	normalize()
	_ensure_save_directory(save_file_path)
	var file := FileAccess.open(save_file_path, FileAccess.WRITE)
	if file == null:
		file = FileAccess.open(ProjectSettings.globalize_path(save_file_path), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"bindings": bindings}, "\t"))
	file.close()
	return true

func normalize() -> void:
	if bindings == null:
		bindings = {}
	var retained_bindings: Dictionary = {}
	for action_name_text: String in bindings.keys():
		var action_name := StringName(action_name_text)
		if _get_action_definition(action_name).is_empty():
			continue
		var normalized_binding := normalize_binding_data(bindings[action_name_text] as Dictionary)
		retained_bindings[action_name_text] = normalized_binding
	bindings = retained_bindings

func get_action_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action_name: StringName = StringName(definition.get("action", StringName()))
		entries.append({
			"action": action_name,
			"display_name": String(definition.get("display_name", String(action_name))),
			"binding": get_binding_data(action_name),
			"binding_label": get_binding_label(action_name),
		})
	return entries

func get_binding_data(action_name: StringName, fallback_data: Dictionary = {}) -> Dictionary:
	var key_name := String(action_name)
	if bindings.has(key_name):
		return normalize_binding_data(bindings[key_name] as Dictionary)
	if not fallback_data.is_empty():
		return normalize_binding_data(fallback_data)
	return get_default_binding_data(action_name)

func set_binding_data(action_name: StringName, binding_data: Dictionary) -> void:
	if _get_action_definition(action_name).is_empty():
		return
	var normalized_binding := normalize_binding_data(binding_data)
	if not normalized_binding.is_empty():
		_unbind_conflicting_actions(action_name, normalized_binding)
	bindings[String(action_name)] = normalized_binding

func reset_all_to_defaults() -> void:
	bindings.clear()

func get_binding_label(action_name: StringName) -> String:
	return format_binding_label(get_binding_data(action_name))

func event_matches_action(action_name: StringName, event: InputEvent) -> bool:
	return event_matches_binding(get_binding_data(action_name), event)

static func get_default_binding_data(action_name: StringName) -> Dictionary:
	var definition := _get_action_definition_static(action_name)
	if definition.is_empty():
		return {}
	return normalize_binding_data(definition.get("binding", {}) as Dictionary)

static func get_action_display_name(action_name: StringName) -> String:
	var definition := _get_action_definition_static(action_name)
	if definition.is_empty():
		return String(action_name)
	return String(definition.get("display_name", String(action_name)))

static func normalize_binding_data(binding_data: Dictionary) -> Dictionary:
	if binding_data.is_empty():
		return {}
	var normalized_binding := {
		"physical_keycode": int(binding_data.get("physical_keycode", KEY_NONE)),
		"keycode": int(binding_data.get("keycode", binding_data.get("physical_keycode", KEY_NONE))),
		"secondary_physical_keycode": int(binding_data.get("secondary_physical_keycode", KEY_NONE)),
		"secondary_keycode": int(binding_data.get("secondary_keycode", binding_data.get("secondary_physical_keycode", KEY_NONE))),
		"mouse_button": int(binding_data.get("mouse_button", MOUSE_BUTTON_NONE)),
		"ctrl": bool(binding_data.get("ctrl", false)),
		"shift": bool(binding_data.get("shift", false)),
		"alt": bool(binding_data.get("alt", false)),
		"meta": bool(binding_data.get("meta", false)),
	}
	if not is_keycode_allowed_for_capture(int(normalized_binding.get("physical_keycode", KEY_NONE))):
		normalized_binding["physical_keycode"] = KEY_NONE
		normalized_binding["keycode"] = KEY_NONE
	if not is_keycode_allowed_for_capture(int(normalized_binding.get("secondary_physical_keycode", KEY_NONE))):
		normalized_binding["secondary_physical_keycode"] = KEY_NONE
		normalized_binding["secondary_keycode"] = KEY_NONE
	if (
		int(normalized_binding.get("physical_keycode", KEY_NONE)) == KEY_NONE
		and int(normalized_binding.get("secondary_physical_keycode", KEY_NONE)) != KEY_NONE
	):
		normalized_binding["physical_keycode"] = int(normalized_binding.get("secondary_physical_keycode", KEY_NONE))
		normalized_binding["keycode"] = int(normalized_binding.get("secondary_keycode", KEY_NONE))
		normalized_binding["secondary_physical_keycode"] = KEY_NONE
		normalized_binding["secondary_keycode"] = KEY_NONE
	if _key_data_same(
		int(normalized_binding.get("physical_keycode", KEY_NONE)),
		int(normalized_binding.get("keycode", KEY_NONE)),
		int(normalized_binding.get("secondary_physical_keycode", KEY_NONE)),
		int(normalized_binding.get("secondary_keycode", KEY_NONE))
	):
		normalized_binding["secondary_physical_keycode"] = KEY_NONE
		normalized_binding["secondary_keycode"] = KEY_NONE
	if (
		int(normalized_binding.get("physical_keycode", KEY_NONE)) == KEY_NONE
		and int(normalized_binding.get("secondary_physical_keycode", KEY_NONE)) == KEY_NONE
		and int(normalized_binding.get("mouse_button", MOUSE_BUTTON_NONE)) == MOUSE_BUTTON_NONE
	):
		return {}
	return normalized_binding

static func build_binding_data_from_key_event(key_event: InputEventKey) -> Dictionary:
	if key_event == null:
		return {}
	if not is_key_event_allowed_for_capture(key_event):
		return {}
	return normalize_binding_data({
		"physical_keycode": int(key_event.physical_keycode),
		"keycode": int(key_event.keycode),
		"secondary_physical_keycode": KEY_NONE,
		"secondary_keycode": KEY_NONE,
		"mouse_button": MOUSE_BUTTON_NONE,
		"ctrl": key_event.ctrl_pressed,
		"shift": key_event.shift_pressed,
		"alt": key_event.alt_pressed,
		"meta": key_event.meta_pressed,
	})

static func append_secondary_key_event(binding_data: Dictionary, key_event: InputEventKey) -> Dictionary:
	if key_event == null:
		return normalize_binding_data(binding_data)
	if not is_key_event_allowed_for_capture(key_event):
		return normalize_binding_data(binding_data)
	var normalized_binding := normalize_binding_data(binding_data)
	var next_physical_keycode := int(key_event.physical_keycode)
	var next_keycode := int(key_event.keycode)
	if _binding_has_key(normalized_binding, next_physical_keycode, next_keycode):
		return normalized_binding
	normalized_binding["secondary_physical_keycode"] = next_physical_keycode
	normalized_binding["secondary_keycode"] = next_keycode
	normalized_binding["ctrl"] = normalized_binding.get("ctrl", false) or key_event.ctrl_pressed
	normalized_binding["shift"] = normalized_binding.get("shift", false) or key_event.shift_pressed
	normalized_binding["alt"] = normalized_binding.get("alt", false) or key_event.alt_pressed
	normalized_binding["meta"] = normalized_binding.get("meta", false) or key_event.meta_pressed
	return normalize_binding_data(normalized_binding)

static func build_binding_data_from_mouse_event(mouse_event: InputEventMouseButton, keyboard_data: Dictionary = {}) -> Dictionary:
	if mouse_event == null:
		return {}
	var binding_data := normalize_binding_data(keyboard_data)
	binding_data["mouse_button"] = int(mouse_event.button_index)
	if binding_data.is_empty():
		binding_data = normalize_binding_data({
			"mouse_button": int(mouse_event.button_index),
			"ctrl": mouse_event.ctrl_pressed,
			"shift": mouse_event.shift_pressed,
			"alt": mouse_event.alt_pressed,
			"meta": mouse_event.meta_pressed,
		})
	return binding_data

static func event_matches_binding(binding_data: Dictionary, event: InputEvent) -> bool:
	var normalized_binding := normalize_binding_data(binding_data)
	if normalized_binding.is_empty() or event == null:
		return false
	if event is InputEventMouseButton:
		return _mouse_event_matches_binding(normalized_binding, event as InputEventMouseButton)
	if event is InputEventKey:
		return _key_event_matches_binding(normalized_binding, event as InputEventKey)
	return false

static func bindings_are_equivalent(first_binding_data: Dictionary, second_binding_data: Dictionary) -> bool:
	var first_binding := normalize_binding_data(first_binding_data)
	var second_binding := normalize_binding_data(second_binding_data)
	if first_binding.is_empty() or second_binding.is_empty():
		return first_binding.is_empty() and second_binding.is_empty()
	if int(first_binding.get("mouse_button", MOUSE_BUTTON_NONE)) != int(second_binding.get("mouse_button", MOUSE_BUTTON_NONE)):
		return false
	if bool(first_binding.get("ctrl", false)) != bool(second_binding.get("ctrl", false)):
		return false
	if bool(first_binding.get("shift", false)) != bool(second_binding.get("shift", false)):
		return false
	if bool(first_binding.get("alt", false)) != bool(second_binding.get("alt", false)):
		return false
	if bool(first_binding.get("meta", false)) != bool(second_binding.get("meta", false)):
		return false
	return _binding_key_pairs_equivalent(first_binding, second_binding)

static func format_binding_label(binding_data: Dictionary) -> String:
	var normalized_binding := normalize_binding_data(binding_data)
	if normalized_binding.is_empty():
		return "Unbound"
	var parts: Array[String] = []
	if bool(normalized_binding.get("ctrl", false)) and not _binding_contains_key_label(normalized_binding, "Ctrl"):
		parts.append("Ctrl")
	if bool(normalized_binding.get("shift", false)) and not _binding_contains_key_label(normalized_binding, "Shift"):
		parts.append("Shift")
	if bool(normalized_binding.get("alt", false)) and not _binding_contains_key_label(normalized_binding, "Alt"):
		parts.append("Alt")
	if bool(normalized_binding.get("meta", false)) and not _binding_contains_key_label(normalized_binding, "Meta"):
		parts.append("Meta")
	var physical_keycode := int(normalized_binding.get("physical_keycode", KEY_NONE))
	var keycode := int(normalized_binding.get("keycode", KEY_NONE))
	var resolved_keycode := physical_keycode if physical_keycode != KEY_NONE else keycode
	if resolved_keycode != KEY_NONE:
		parts.append(OS.get_keycode_string(resolved_keycode))
	var secondary_physical_keycode := int(normalized_binding.get("secondary_physical_keycode", KEY_NONE))
	var secondary_keycode := int(normalized_binding.get("secondary_keycode", KEY_NONE))
	var resolved_secondary_keycode := secondary_physical_keycode if secondary_physical_keycode != KEY_NONE else secondary_keycode
	if resolved_secondary_keycode != KEY_NONE:
		parts.append(OS.get_keycode_string(resolved_secondary_keycode))
	var mouse_button := int(normalized_binding.get("mouse_button", MOUSE_BUTTON_NONE))
	if mouse_button != MOUSE_BUTTON_NONE:
		parts.append(get_mouse_button_label(mouse_button))
	return " + ".join(parts) if not parts.is_empty() else "Unbound"

static func is_key_event_allowed_for_capture(key_event: InputEventKey) -> bool:
	if key_event == null:
		return false
	var physical_keycode := int(key_event.physical_keycode)
	var keycode := int(key_event.keycode)
	return is_keycode_allowed_for_capture(physical_keycode) or is_keycode_allowed_for_capture(keycode)

static func is_keycode_allowed_for_capture(keycode: int) -> bool:
	if keycode == KEY_NONE:
		return false
	var key_label := OS.get_keycode_string(keycode as Key).strip_edges()
	if key_label.is_empty():
		return false
	var compact_label := key_label.replace(" ", "").to_lower()
	if compact_label == "enter" or compact_label.ends_with("enter"):
		return false
	if compact_label == "backspace":
		return false
	if compact_label == "numlock" or compact_label == "numberlock":
		return false
	if keycode >= KEY_F1 and keycode <= KEY_F12:
		return false
	return true

static func get_mouse_button_label(mouse_button: int) -> String:
	match mouse_button:
		MOUSE_BUTTON_LEFT:
			return "LMB"
		MOUSE_BUTTON_RIGHT:
			return "RMB"
		MOUSE_BUTTON_MIDDLE:
			return "MMB"
		MOUSE_BUTTON_WHEEL_UP:
			return "Wheel Up"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "Wheel Down"
		MOUSE_BUTTON_WHEEL_LEFT:
			return "Wheel Left"
		MOUSE_BUTTON_WHEEL_RIGHT:
			return "Wheel Right"
		MOUSE_BUTTON_XBUTTON1:
			return "Mouse 4"
		MOUSE_BUTTON_XBUTTON2:
			return "Mouse 5"
	return "Mouse %d" % mouse_button

func _get_action_definition(action_name: StringName) -> Dictionary:
	return _get_action_definition_static(action_name)

func _unbind_conflicting_actions(owner_action_name: StringName, owner_binding_data: Dictionary) -> void:
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action_name := StringName(definition.get("action", StringName()))
		if action_name == owner_action_name:
			continue
		if bindings_are_equivalent(get_binding_data(action_name), owner_binding_data):
			bindings[String(action_name)] = {}

func _ensure_save_directory(next_save_file_path: String) -> void:
	var normalized_save_path: String = next_save_file_path.replace("\\", "/")
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

static func _get_action_definition_static(action_name: StringName) -> Dictionary:
	for definition: Dictionary in ACTION_DEFINITIONS:
		if StringName(definition.get("action", StringName())) == action_name:
			return definition
	return {}

static func _mouse_event_matches_binding(binding_data: Dictionary, mouse_event: InputEventMouseButton) -> bool:
	if not mouse_event.pressed:
		return false
	if int(binding_data.get("mouse_button", MOUSE_BUTTON_NONE)) != int(mouse_event.button_index):
		return false
	if not _modifiers_match_binding(binding_data, mouse_event):
		return false
	var physical_keycode := int(binding_data.get("physical_keycode", KEY_NONE))
	var secondary_physical_keycode := int(binding_data.get("secondary_physical_keycode", KEY_NONE))
	if physical_keycode == KEY_NONE and secondary_physical_keycode == KEY_NONE:
		return true
	if physical_keycode != KEY_NONE and not Input.is_physical_key_pressed(physical_keycode as Key):
		return false
	return secondary_physical_keycode == KEY_NONE or Input.is_physical_key_pressed(secondary_physical_keycode as Key)

static func _key_event_matches_binding(binding_data: Dictionary, key_event: InputEventKey) -> bool:
	if not key_event.pressed or key_event.echo:
		return false
	if int(binding_data.get("mouse_button", MOUSE_BUTTON_NONE)) != MOUSE_BUTTON_NONE:
		return false
	if not _modifiers_match_binding(binding_data, key_event):
		return false
	var physical_keycode := int(binding_data.get("physical_keycode", KEY_NONE))
	var keycode := int(binding_data.get("keycode", KEY_NONE))
	var secondary_physical_keycode := int(binding_data.get("secondary_physical_keycode", KEY_NONE))
	var secondary_keycode := int(binding_data.get("secondary_keycode", KEY_NONE))
	if secondary_physical_keycode == KEY_NONE and secondary_keycode == KEY_NONE:
		return _key_event_matches_key_data(key_event, physical_keycode, keycode)
	if not _key_event_matches_key_data(key_event, physical_keycode, keycode) and not _key_event_matches_key_data(key_event, secondary_physical_keycode, secondary_keycode):
		return false
	if physical_keycode != KEY_NONE and not Input.is_physical_key_pressed(physical_keycode as Key):
		return false
	return secondary_physical_keycode != KEY_NONE and Input.is_physical_key_pressed(secondary_physical_keycode as Key)

static func _key_event_matches_key_data(key_event: InputEventKey, physical_keycode: int, keycode: int) -> bool:
	if physical_keycode != KEY_NONE and int(key_event.physical_keycode) == physical_keycode:
		return true
	return keycode != KEY_NONE and int(key_event.keycode) == keycode

static func _binding_has_key(binding_data: Dictionary, physical_keycode: int, keycode: int) -> bool:
	if physical_keycode == KEY_NONE and keycode == KEY_NONE:
		return false
	return (
		(physical_keycode != KEY_NONE and int(binding_data.get("physical_keycode", KEY_NONE)) == physical_keycode)
		or (keycode != KEY_NONE and int(binding_data.get("keycode", KEY_NONE)) == keycode)
		or (physical_keycode != KEY_NONE and int(binding_data.get("secondary_physical_keycode", KEY_NONE)) == physical_keycode)
		or (keycode != KEY_NONE and int(binding_data.get("secondary_keycode", KEY_NONE)) == keycode)
	)

static func _binding_key_pairs_equivalent(first_binding: Dictionary, second_binding: Dictionary) -> bool:
	var first_pairs := _binding_key_pairs(first_binding)
	var second_pairs := _binding_key_pairs(second_binding)
	if first_pairs.size() != second_pairs.size():
		return false
	for first_pair: Dictionary in first_pairs:
		var matched := false
		for second_pair: Dictionary in second_pairs:
			if _key_pair_same(first_pair, second_pair):
				matched = true
				break
		if not matched:
			return false
	return true

static func _binding_key_pairs(binding_data: Dictionary) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	_append_binding_key_pair(
		pairs,
		int(binding_data.get("physical_keycode", KEY_NONE)),
		int(binding_data.get("keycode", KEY_NONE))
	)
	_append_binding_key_pair(
		pairs,
		int(binding_data.get("secondary_physical_keycode", KEY_NONE)),
		int(binding_data.get("secondary_keycode", KEY_NONE))
	)
	return pairs

static func _append_binding_key_pair(pairs: Array[Dictionary], physical_keycode: int, keycode: int) -> void:
	if physical_keycode == KEY_NONE and keycode == KEY_NONE:
		return
	var next_pair := {
		"physical_keycode": physical_keycode,
		"keycode": keycode,
	}
	for existing_pair: Dictionary in pairs:
		if _key_pair_same(existing_pair, next_pair):
			return
	pairs.append(next_pair)

static func _key_pair_same(first_pair: Dictionary, second_pair: Dictionary) -> bool:
	var first_physical := int(first_pair.get("physical_keycode", KEY_NONE))
	var first_keycode := int(first_pair.get("keycode", KEY_NONE))
	var second_physical := int(second_pair.get("physical_keycode", KEY_NONE))
	var second_keycode := int(second_pair.get("keycode", KEY_NONE))
	return (
		(first_physical != KEY_NONE and first_physical == second_physical)
		or (first_keycode != KEY_NONE and first_keycode == second_keycode)
	)

static func _key_data_same(
	primary_physical_keycode: int,
	primary_keycode: int,
	secondary_physical_keycode: int,
	secondary_keycode: int
) -> bool:
	if primary_physical_keycode == KEY_NONE and primary_keycode == KEY_NONE:
		return false
	if secondary_physical_keycode == KEY_NONE and secondary_keycode == KEY_NONE:
		return false
	return (
		(primary_physical_keycode != KEY_NONE and primary_physical_keycode == secondary_physical_keycode)
		or (primary_keycode != KEY_NONE and primary_keycode == secondary_keycode)
	)

static func _binding_contains_key_label(binding_data: Dictionary, target_label: String) -> bool:
	var primary_label := _format_keycode_label(int(binding_data.get("physical_keycode", KEY_NONE)), int(binding_data.get("keycode", KEY_NONE)))
	var secondary_label := _format_keycode_label(
		int(binding_data.get("secondary_physical_keycode", KEY_NONE)),
		int(binding_data.get("secondary_keycode", KEY_NONE))
	)
	return primary_label == target_label or secondary_label == target_label

static func _format_keycode_label(physical_keycode: int, keycode: int) -> String:
	var resolved_keycode := physical_keycode if physical_keycode != KEY_NONE else keycode
	return OS.get_keycode_string(resolved_keycode as Key).strip_edges() if resolved_keycode != KEY_NONE else ""

static func _modifiers_match_binding(binding_data: Dictionary, event: InputEventWithModifiers) -> bool:
	return (
		bool(binding_data.get("ctrl", false)) == event.ctrl_pressed
		and bool(binding_data.get("shift", false)) == event.shift_pressed
		and bool(binding_data.get("alt", false)) == event.alt_pressed
		and bool(binding_data.get("meta", false)) == event.meta_pressed
	)
