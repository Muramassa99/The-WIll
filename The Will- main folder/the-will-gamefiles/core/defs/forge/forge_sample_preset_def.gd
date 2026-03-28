extends Resource
class_name ForgeSamplePresetDef

const ForgeSampleBrushDefScript = preload("res://core/defs/forge/forge_sample_brush_def.gd")

@export var preset_id: StringName = &""
@export var display_name: String = ""
@export var forge_intent: StringName = &""
@export var equipment_context: StringName = &""
@export var footprint_size_voxels: Vector3i = Vector3i.ONE
@export var brushes: Array[ForgeSampleBrushDef] = []