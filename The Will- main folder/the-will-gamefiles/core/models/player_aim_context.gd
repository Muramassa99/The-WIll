extends RefCounted
class_name PlayerAimContext

var max_range_meters: float = 0.0
var camera_origin: Vector3 = Vector3.ZERO
var camera_direction: Vector3 = Vector3.FORWARD
var flat_direction: Vector3 = Vector3.FORWARD
var aim_point: Vector3 = Vector3.ZERO
var aim_distance: float = 0.0
var hit: bool = false
var surface_normal: Vector3 = Vector3.UP
var aim_yaw_radians: float = 0.0

func has_flat_direction() -> bool:
	return not flat_direction.is_zero_approx()
