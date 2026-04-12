extends Resource
class_name PlayerHudLayoutState

const PersistentResourceStateIOScript = preload("res://core/models/persistent_resource_state_io.gd")
const DEFAULT_SAVE_FILE_PATH := "user://ui/player_hud_layout_state.tres"

@export var element_positions: Dictionary = {}
@export var element_scales: Dictionary = {}
@export var save_file_path: String = DEFAULT_SAVE_FILE_PATH

static func load_or_create(save_path: String = DEFAULT_SAVE_FILE_PATH) -> Resource:
	return PersistentResourceStateIOScript.load_or_create(save_path, "res://core/models/player_hud_layout_state.gd")

func get_element_position(element_id: StringName) -> Vector2:
	if element_positions.has(String(element_id)):
		return element_positions[String(element_id)] as Vector2
	return Vector2(-1.0, -1.0)

func set_element_position(element_id: StringName, position: Vector2) -> void:
	element_positions[String(element_id)] = position
	persist()

func has_custom_position(element_id: StringName) -> bool:
	return element_positions.has(String(element_id))

func get_element_scale(element_id: StringName) -> float:
	if element_scales.has(String(element_id)):
		return float(element_scales[String(element_id)])
	return 1.0

func set_element_scale(element_id: StringName, scale_factor: float) -> void:
	element_scales[String(element_id)] = scale_factor
	persist()

func clear_element_position(element_id: StringName) -> void:
	element_positions.erase(String(element_id))
	persist()

func reset_all_positions() -> void:
	element_positions.clear()
	element_scales.clear()
	persist()

func persist() -> bool:
	return PersistentResourceStateIOScript.persist_resource(self, save_file_path)
