extends RefCounted
class_name CombatAnimationSpeedStateSampler

const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")

const STATE_RESET: StringName = &"speed_reset"
const STATE_BUILDUP: StringName = &"speed_buildup"
const STATE_ARMED: StringName = &"speed_armed"

const DEFAULT_ACCELERATION_PERCENT := 35.0
const DEFAULT_DECELERATION_PERCENT := 35.0
const DEFAULT_ARMED_SPEED_THRESHOLD_MPS := 1.0
const DEFAULT_SAMPLES_PER_SEGMENT := 10
const DEFAULT_STARTUP_SEGMENT_COUNT := 1

const COLOR_RESET := Color(0.18, 0.85, 0.35, 1.0)
const COLOR_ARMED := Color(1.0, 0.25, 0.18, 1.0)

func sample_motion_chain(
	motion_node_chain: Array,
	tip_curve: Curve3D,
	pommel_curve: Curve3D,
	config: Dictionary = {}
) -> Dictionary:
	var samples: Array[Dictionary] = []
	if motion_node_chain.size() < 2:
		return _build_result(samples, config)
	var samples_per_segment: int = maxi(int(config.get("samples_per_segment", DEFAULT_SAMPLES_PER_SEGMENT)), 2)
	var acceleration_percent: float = _sanitize_percent(float(config.get("acceleration_percent", DEFAULT_ACCELERATION_PERCENT)))
	var deceleration_percent: float = _sanitize_percent(float(config.get("deceleration_percent", DEFAULT_DECELERATION_PERCENT)))
	var armed_threshold_mps: float = maxf(float(config.get("armed_speed_threshold_mps", DEFAULT_ARMED_SPEED_THRESHOLD_MPS)), 0.001)
	var startup_segment_count: int = maxi(int(config.get("startup_segment_count", DEFAULT_STARTUP_SEGMENT_COUNT)), 0)
	var total_duration: float = _resolve_total_duration(motion_node_chain)
	var segment_count: int = motion_node_chain.size() - 1
	var total_tip_length: float = _resolve_curve_length(tip_curve)
	var total_pommel_length: float = _resolve_curve_length(pommel_curve)
	var elapsed_time: float = 0.0
	var previous_tip: Vector3 = Vector3.ZERO
	var previous_pommel: Vector3 = Vector3.ZERO
	var previous_time: float = 0.0
	var has_previous: bool = false
	for segment_index: int in range(1, motion_node_chain.size()):
		var curr_node: CombatAnimationMotionNode = motion_node_chain[segment_index] as CombatAnimationMotionNode
		var prev_node: CombatAnimationMotionNode = motion_node_chain[segment_index - 1] as CombatAnimationMotionNode
		if curr_node == null or prev_node == null:
			continue
		var segment_duration: float = maxf(curr_node.transition_duration_seconds, 0.01)
		for sample_index: int in range(samples_per_segment + 1):
			if segment_index > 1 and sample_index == 0:
				continue
			var local_ratio: float = float(sample_index) / float(samples_per_segment)
			var chain_ratio: float = (float(segment_index - 1) + local_ratio) / float(segment_count)
			var sample_time: float = elapsed_time + segment_duration * local_ratio
			var tip_position: Vector3 = _sample_curve_or_lerp(
				tip_curve,
				total_tip_length,
				chain_ratio,
				prev_node.tip_position_local,
				curr_node.tip_position_local,
				local_ratio
			)
			var pommel_position: Vector3 = _sample_curve_or_lerp(
				pommel_curve,
				total_pommel_length,
				chain_ratio,
				prev_node.pommel_position_local,
				curr_node.pommel_position_local,
				local_ratio
			)
			var dt: float = sample_time - previous_time if has_previous else segment_duration / float(samples_per_segment)
			if dt <= 0.00001:
				dt = segment_duration / float(samples_per_segment)
			var tip_speed: float = previous_tip.distance_to(tip_position) / dt if has_previous else 0.0
			var pommel_speed: float = previous_pommel.distance_to(pommel_position) / dt if has_previous else 0.0
			var raw_speed: float = maxf(tip_speed, pommel_speed)
			var envelope: float = _resolve_speed_envelope(local_ratio, acceleration_percent, deceleration_percent)
			var effective_speed: float = raw_speed * envelope
			var state: StringName = _classify_speed_state(segment_index, local_ratio, effective_speed, armed_threshold_mps, deceleration_percent, startup_segment_count)
			var speed_alpha: float = clampf(effective_speed / armed_threshold_mps, 0.0, 1.0)
			var color: Color = COLOR_RESET.lerp(COLOR_ARMED, speed_alpha)
			if state == STATE_RESET:
				color = COLOR_RESET
			elif state == STATE_ARMED:
				color = COLOR_ARMED
			samples.append({
				"segment_index": segment_index,
				"local_ratio": local_ratio,
				"chain_ratio": chain_ratio,
				"time_seconds": sample_time,
				"normalized_time": sample_time / total_duration if total_duration > 0.00001 else 0.0,
				"tip_position": tip_position,
				"pommel_position": pommel_position,
				"tip_speed_mps": tip_speed,
				"pommel_speed_mps": pommel_speed,
				"raw_speed_mps": raw_speed,
				"effective_speed_mps": effective_speed,
				"speed_alpha": speed_alpha,
				"state": state,
				"color": color,
			})
			previous_tip = tip_position
			previous_pommel = pommel_position
			previous_time = sample_time
			has_previous = true
		elapsed_time += segment_duration
	var resolved_config: Dictionary = config.duplicate(true)
	resolved_config["acceleration_percent"] = acceleration_percent
	resolved_config["deceleration_percent"] = deceleration_percent
	resolved_config["armed_speed_threshold_mps"] = armed_threshold_mps
	resolved_config["samples_per_segment"] = samples_per_segment
	resolved_config["startup_segment_count"] = startup_segment_count
	return _build_result(samples, resolved_config)

func _build_result(samples: Array[Dictionary], config: Dictionary) -> Dictionary:
	var armed_count: int = 0
	var reset_count: int = 0
	var buildup_count: int = 0
	var min_speed: float = INF
	var max_speed: float = 0.0
	for sample: Dictionary in samples:
		var speed: float = float(sample.get("effective_speed_mps", 0.0))
		min_speed = minf(min_speed, speed)
		max_speed = maxf(max_speed, speed)
		match sample.get("state", STATE_RESET) as StringName:
			STATE_ARMED:
				armed_count += 1
			STATE_BUILDUP:
				buildup_count += 1
			_:
				reset_count += 1
	return {
		"samples": samples,
		"sample_count": samples.size(),
		"armed_sample_count": armed_count,
		"buildup_sample_count": buildup_count,
		"reset_sample_count": reset_count,
		"min_effective_speed_mps": min_speed if min_speed < INF else 0.0,
		"max_effective_speed_mps": max_speed,
		"acceleration_percent": float(config.get("acceleration_percent", DEFAULT_ACCELERATION_PERCENT)),
		"deceleration_percent": float(config.get("deceleration_percent", DEFAULT_DECELERATION_PERCENT)),
		"armed_speed_threshold_mps": float(config.get("armed_speed_threshold_mps", DEFAULT_ARMED_SPEED_THRESHOLD_MPS)),
		"samples_per_segment": int(config.get("samples_per_segment", DEFAULT_SAMPLES_PER_SEGMENT)),
		"startup_segment_count": int(config.get("startup_segment_count", DEFAULT_STARTUP_SEGMENT_COUNT)),
	}

func _resolve_speed_envelope(local_ratio: float, acceleration_percent: float, deceleration_percent: float) -> float:
	var envelope: float = 1.0
	var accel_ratio: float = acceleration_percent / 100.0
	var decel_ratio: float = deceleration_percent / 100.0
	if accel_ratio > 0.0001:
		envelope = minf(envelope, clampf(local_ratio / accel_ratio, 0.0, 1.0))
	if decel_ratio > 0.0001:
		envelope = minf(envelope, clampf((1.0 - local_ratio) / decel_ratio, 0.0, 1.0))
	return envelope

func _classify_speed_state(
	segment_index: int,
	local_ratio: float,
	effective_speed_mps: float,
	armed_threshold_mps: float,
	deceleration_percent: float,
	startup_segment_count: int
) -> StringName:
	if segment_index <= startup_segment_count:
		return STATE_RESET
	var decel_start: float = 1.0 - deceleration_percent / 100.0
	if local_ratio >= decel_start:
		return STATE_RESET
	if effective_speed_mps >= armed_threshold_mps:
		return STATE_ARMED
	if effective_speed_mps > armed_threshold_mps * 0.25:
		return STATE_BUILDUP
	return STATE_RESET

func _sample_curve_or_lerp(
	curve: Curve3D,
	total_length: float,
	chain_ratio: float,
	from_position: Vector3,
	to_position: Vector3,
	local_ratio: float
) -> Vector3:
	var fallback_position: Vector3 = from_position.lerp(to_position, clampf(local_ratio, 0.0, 1.0))
	if curve == null or total_length <= 0.00001:
		return fallback_position
	return _sample_baked_polyline_position(
		curve,
		clampf(chain_ratio, 0.0, 1.0) * total_length,
		fallback_position
	)

func _sample_baked_polyline_position(curve: Curve3D, offset: float, fallback_position: Vector3) -> Vector3:
	if curve == null:
		return fallback_position
	var baked_points: PackedVector3Array = curve.get_baked_points()
	if baked_points.is_empty():
		return fallback_position
	var previous_point: Vector3 = baked_points[0]
	if not _is_finite_vector3(previous_point):
		return fallback_position
	if baked_points.size() == 1 or offset <= 0.0:
		return previous_point
	var walked_length: float = 0.0
	var target_offset: float = maxf(offset, 0.0)
	for point_index: int in range(1, baked_points.size()):
		var current_point: Vector3 = baked_points[point_index]
		if not _is_finite_vector3(current_point):
			continue
		var interval_length: float = previous_point.distance_to(current_point)
		if interval_length <= 0.000001:
			previous_point = current_point
			continue
		var next_walked_length: float = walked_length + interval_length
		if next_walked_length >= target_offset:
			var interval_ratio: float = clampf((target_offset - walked_length) / interval_length, 0.0, 1.0)
			return previous_point.lerp(current_point, interval_ratio)
		walked_length = next_walked_length
		previous_point = current_point
	return previous_point

func _resolve_total_duration(motion_node_chain: Array) -> float:
	var total: float = 0.0
	for node_index: int in range(1, motion_node_chain.size()):
		var node: CombatAnimationMotionNode = motion_node_chain[node_index] as CombatAnimationMotionNode
		total += maxf(node.transition_duration_seconds if node != null else 0.01, 0.01)
	return total

func _sanitize_curve_length(value: float) -> float:
	return value if not is_nan(value) and not is_inf(value) and value > 0.0 else 0.0

func _resolve_curve_length(curve: Curve3D) -> float:
	if curve == null or curve.get_point_count() < 2:
		return 0.0
	var first_point: Vector3 = curve.get_point_position(0)
	var has_distinct_point: bool = false
	for point_index: int in range(1, curve.get_point_count()):
		if first_point.distance_squared_to(curve.get_point_position(point_index)) > 0.00000025:
			has_distinct_point = true
			break
	if not has_distinct_point:
		return 0.0
	return _sanitize_curve_length(_resolve_baked_polyline_length(curve))

func _resolve_baked_polyline_length(curve: Curve3D) -> float:
	if curve == null:
		return 0.0
	var baked_points: PackedVector3Array = curve.get_baked_points()
	if baked_points.size() < 2:
		return 0.0
	var total_length: float = 0.0
	var previous_point: Vector3 = baked_points[0]
	if not _is_finite_vector3(previous_point):
		return 0.0
	for point_index: int in range(1, baked_points.size()):
		var current_point: Vector3 = baked_points[point_index]
		if not _is_finite_vector3(current_point):
			continue
		var interval_length: float = previous_point.distance_to(current_point)
		if interval_length > 0.000001:
			total_length += interval_length
		previous_point = current_point
	return total_length

func _sanitize_percent(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return DEFAULT_ACCELERATION_PERCENT
	return clampf(value, 0.0, 100.0)

func _is_finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x)
		and not is_nan(value.y)
		and not is_nan(value.z)
		and not is_inf(value.x)
		and not is_inf(value.y)
		and not is_inf(value.z)
	)
