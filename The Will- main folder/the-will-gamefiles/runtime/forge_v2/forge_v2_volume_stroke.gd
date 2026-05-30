extends Resource
class_name ForgeV2VolumeStroke

const OPERATION_ADD_MATERIAL := &"operation_add_material"
const OPERATION_REMOVE_MATERIAL := &"operation_remove_material"
const PLACEMENT_REPLACE_EXISTING := &"placement_replace_existing"
const PLACEMENT_EMPTY_ONLY := &"placement_empty_only"

@export var stroke_id: StringName = StringName()
@export var operation_mode: StringName = OPERATION_ADD_MATERIAL
@export var material_variant_id: StringName = &"iron_gray"
@export var placement_policy: StringName = PLACEMENT_REPLACE_EXISTING
@export var radius_meters: float = 0.06
@export var amount_ratio: float = 1.0
@export var path_points: PackedVector3Array = PackedVector3Array()
@export var created_timestamp: float = 0.0

func normalize() -> void:
	if stroke_id == StringName():
		stroke_id = _build_stroke_id()
	if created_timestamp <= 0.0:
		created_timestamp = Time.get_unix_time_from_system()
	if operation_mode != OPERATION_REMOVE_MATERIAL:
		operation_mode = OPERATION_ADD_MATERIAL
	if placement_policy != PLACEMENT_EMPTY_ONLY:
		placement_policy = PLACEMENT_REPLACE_EXISTING
	if material_variant_id == StringName():
		material_variant_id = &"iron_gray"
	radius_meters = maxf(radius_meters, 0.001)
	amount_ratio = clampf(amount_ratio, 0.01, 1.0)

func get_point_count() -> int:
	return path_points.size()

func has_volume_path() -> bool:
	return path_points.size() >= 2 and radius_meters > 0.0

func _build_stroke_id() -> StringName:
	return StringName("v2_stroke_%s" % str(Time.get_ticks_usec()))
