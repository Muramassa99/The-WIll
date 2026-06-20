extends Resource
class_name CellAtom

@export var grid_position: Vector3i = Vector3i.ZERO
@export var layer_index: int = 0
@export var material_variant_id: StringName = &""

func get_center_position() -> Vector3:
	return Vector3(grid_position)
