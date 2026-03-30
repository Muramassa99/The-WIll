extends Resource
class_name AnchorAtom

@export var anchor_id: StringName = &""
@export var anchor_type: String = ""
@export var local_position: Vector3 = Vector3.ZERO
@export var local_axis: Vector3 = Vector3.ZERO
@export var span_length: int = 0
@export var span_start_local_position: Vector3 = Vector3.ZERO
@export var span_end_local_position: Vector3 = Vector3.ZERO
@export var span_start_index: int = -1
@export var span_end_index: int = -1
@export var span_anchor_material_ratio: float = 0.0
