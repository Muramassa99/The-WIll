extends Resource
class_name AnchorAtom

const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")
const DEFAULT_ANCHOR_ORIGIN_ID := CombatOriginRecordScript.ORIGIN_WEAPON_ROOT

@export var anchor_id: StringName = &""
@export var anchor_type: String = ""
@export var local_position: Vector3 = Vector3.ZERO
@export var position_origin_id: StringName = DEFAULT_ANCHOR_ORIGIN_ID
@export var local_axis: Vector3 = Vector3.ZERO
@export var axis_origin_id: StringName = DEFAULT_ANCHOR_ORIGIN_ID
@export var span_length: int = 0
@export var span_start_local_position: Vector3 = Vector3.ZERO
@export var span_start_position_origin_id: StringName = DEFAULT_ANCHOR_ORIGIN_ID
@export var span_end_local_position: Vector3 = Vector3.ZERO
@export var span_end_position_origin_id: StringName = DEFAULT_ANCHOR_ORIGIN_ID
@export var span_start_index: int = -1
@export var span_end_index: int = -1
@export var span_slice_axis_ratios_from_start: PackedFloat32Array = PackedFloat32Array()
@export var span_slice_center_local_positions: PackedVector3Array = PackedVector3Array()
@export var span_anchor_material_ratio: float = 0.0

func normalize() -> void:
	if position_origin_id == StringName():
		position_origin_id = DEFAULT_ANCHOR_ORIGIN_ID
	if axis_origin_id == StringName():
		axis_origin_id = DEFAULT_ANCHOR_ORIGIN_ID
	if span_start_position_origin_id == StringName():
		span_start_position_origin_id = DEFAULT_ANCHOR_ORIGIN_ID
	if span_end_position_origin_id == StringName():
		span_end_position_origin_id = DEFAULT_ANCHOR_ORIGIN_ID
