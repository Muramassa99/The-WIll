extends RefCounted
class_name CombatAnimationTrajectoryVolumeResolver

const DEFAULT_PIVOT_RATIO_FROM_POMMEL := 0.5

func make_shell_config(
	origin_local: Vector3,
	min_radius_meters: float,
	max_radius_meters: float,
	pivot_ratio_from_pommel: float = DEFAULT_PIVOT_RATIO_FROM_POMMEL,
	enabled: bool = true
) -> Dictionary:
	return {
		"enabled": enabled,
		"origin_local": origin_local,
		"min_radius_meters": maxf(min_radius_meters, 0.0),
		"max_radius_meters": maxf(max_radius_meters, 0.0),
		"pivot_ratio_from_pommel": clampf(pivot_ratio_from_pommel, 0.0, 1.0),
	}

func project_segment_to_valid_volume(
	tip_position_local: Vector3,
	pommel_position_local: Vector3,
	config: Dictionary = {}
) -> Dictionary:
	var pivot_ratio: float = clampf(
		float(config.get("pivot_ratio_from_pommel", DEFAULT_PIVOT_RATIO_FROM_POMMEL)),
		0.0,
		1.0
	)
	var pivot_before: Vector3 = pommel_position_local.lerp(tip_position_local, pivot_ratio)
	var result := {
		"tip_position": tip_position_local,
		"pommel_position": pommel_position_local,
		"pivot_position_before": pivot_before,
		"pivot_position_after": pivot_before,
		"distance_before_meters": 0.0,
		"distance_after_meters": 0.0,
		"min_radius_meters": 0.0,
		"max_radius_meters": 0.0,
		"clamped": false,
		"min_clamped": false,
		"max_clamped": false,
	}
	if not bool(config.get("enabled", false)):
		return result
	var origin_local: Vector3 = config.get("origin_local", Vector3.ZERO) as Vector3
	var min_radius: float = maxf(float(config.get("min_radius_meters", 0.0)), 0.0)
	var max_radius: float = maxf(float(config.get("max_radius_meters", 0.0)), 0.0)
	if max_radius > 0.0 and min_radius > max_radius:
		min_radius = max_radius
	result["min_radius_meters"] = min_radius
	result["max_radius_meters"] = max_radius
	var origin_to_pivot: Vector3 = pivot_before - origin_local
	var distance_before: float = origin_to_pivot.length()
	result["distance_before_meters"] = distance_before
	var projected_pivot: Vector3 = pivot_before
	var direction: Vector3 = _resolve_projection_direction(origin_to_pivot, config)
	if max_radius > 0.0 and distance_before > max_radius:
		projected_pivot = origin_local + direction * max_radius
		result["clamped"] = true
		result["max_clamped"] = true
	elif min_radius > 0.0 and distance_before < min_radius:
		projected_pivot = origin_local + direction * min_radius
		result["clamped"] = true
		result["min_clamped"] = true
	var translation: Vector3 = projected_pivot - pivot_before
	result["tip_position"] = tip_position_local + translation
	result["pommel_position"] = pommel_position_local + translation
	result["pivot_position_after"] = projected_pivot
	result["distance_after_meters"] = projected_pivot.distance_to(origin_local)
	return result

func project_point_to_valid_volume(point_local: Vector3, config: Dictionary = {}) -> Dictionary:
	var result: Dictionary = project_segment_to_valid_volume(point_local, point_local, config)
	return {
		"point_position": result.get("pivot_position_after", point_local),
		"point_position_before": point_local,
		"distance_before_meters": result.get("distance_before_meters", 0.0),
		"distance_after_meters": result.get("distance_after_meters", 0.0),
		"min_radius_meters": result.get("min_radius_meters", 0.0),
		"max_radius_meters": result.get("max_radius_meters", 0.0),
		"clamped": result.get("clamped", false),
		"min_clamped": result.get("min_clamped", false),
		"max_clamped": result.get("max_clamped", false),
	}

func _resolve_projection_direction(origin_to_pivot: Vector3, config: Dictionary) -> Vector3:
	if origin_to_pivot.length_squared() > 0.000001:
		return origin_to_pivot.normalized()
	var fallback_direction: Vector3 = config.get("fallback_direction_local", Vector3.FORWARD) as Vector3
	if fallback_direction.length_squared() <= 0.000001:
		fallback_direction = Vector3.FORWARD
	return fallback_direction.normalized()
