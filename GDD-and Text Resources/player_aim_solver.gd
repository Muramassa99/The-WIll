extends RefCounted
class_name PlayerAimSolver

const PlayerAimContextScript = preload("res://core/models/player_aim_context.gd")

func resolve_from_camera(
		camera: Camera3D,
		max_range_meters: float,
		collision_mask: int,
		exclude: Array = []
	):
	var aim_context = PlayerAimContextScript.new()
	aim_context.max_range_meters = maxf(max_range_meters, 0.01)
	if camera == null or camera.get_viewport() == null:
		return aim_context

	var viewport_center: Vector2 = camera.get_viewport().get_visible_rect().size * 0.5
	var ray_origin: Vector3 = camera.project_ray_origin(viewport_center)
	var ray_direction: Vector3 = camera.project_ray_normal(viewport_center).normalized()
	var max_target_point: Vector3 = ray_origin + ray_direction * aim_context.max_range_meters

	var query := PhysicsRayQueryParameters3D.create(ray_origin, max_target_point, collision_mask, exclude)
	var hit_result: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)

	aim_context.camera_origin = ray_origin
	aim_context.camera_direction = ray_direction
	aim_context.aim_point = max_target_point
	aim_context.aim_distance = aim_context.max_range_meters
	aim_context.surface_normal = Vector3.UP
	if not hit_result.is_empty():
		aim_context.hit = true
		aim_context.aim_point = hit_result.get("position", max_target_point)
		aim_context.aim_distance = ray_origin.distance_to(aim_context.aim_point)
		aim_context.surface_normal = hit_result.get("normal", Vector3.UP)

	var flat_direction: Vector3 = ray_direction
	flat_direction.y = 0.0
	if flat_direction.is_zero_approx():
		flat_direction = -camera.global_basis.z
		flat_direction.y = 0.0
	if not flat_direction.is_zero_approx():
		aim_context.flat_direction = flat_direction.normalized()
		aim_context.aim_yaw_radians = atan2(aim_context.flat_direction.x, aim_context.flat_direction.z)

	return aim_context
