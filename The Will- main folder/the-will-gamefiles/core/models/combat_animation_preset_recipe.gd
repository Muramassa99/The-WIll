extends Resource
class_name CombatAnimationPresetRecipe

const SCHEMA_ID: StringName = &"combat_animation_preset_recipe_v1"

@export var schema_id: StringName = SCHEMA_ID
@export var preset_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var retarget_nodes: Array[Resource] = []
@export_range(0.0, 100.0, 1.0) var speed_acceleration_percent: float = 35.0
@export_range(0.0, 100.0, 1.0) var speed_deceleration_percent: float = 35.0
@export var validation_required: bool = true

func normalize() -> void:
	schema_id = SCHEMA_ID
	if preset_id == StringName():
		preset_id = &"preset_custom"
	if display_name.strip_edges().is_empty():
		display_name = String(preset_id).capitalize()
	speed_acceleration_percent = clampf(speed_acceleration_percent, 0.0, 100.0)
	speed_deceleration_percent = clampf(speed_deceleration_percent, 0.0, 100.0)
	for node_index: int in range(retarget_nodes.size()):
		var retarget_node: Resource = retarget_nodes[node_index]
		if retarget_node == null:
			continue
		if retarget_node.has_method("normalize"):
			retarget_node.call("normalize")
		if retarget_node.has_method("set"):
			retarget_node.set("enabled", true)

func duplicate_recipe():
	return duplicate(true)
