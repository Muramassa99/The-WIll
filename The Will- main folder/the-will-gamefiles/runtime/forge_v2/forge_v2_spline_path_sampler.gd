extends RefCounted
class_name ForgeV2SplinePathSampler

const AUTO_CURVE_HANDLE_MIN_LENGTH_METERS := 0.025
const AUTO_CURVE_ENDPOINT_STRENGTH := 0.3333333
const AUTO_CURVE_MIDDLE_STRENGTH := 0.1666667
const MIN_SAMPLE_SPACING_METERS := 0.0001
const MIN_FLATNESS_TOLERANCE_METERS := 0.00001
const DEFAULT_MAX_SUBDIVISION_DEPTH := 10
const DEFAULT_MAX_SAMPLES_PER_SPAN := 1025
const GEOMETRY_EPSILON_SQUARED := 0.000000000001

const REASON_NONE := &"none"
const REASON_ZERO_LENGTH_SPAN := &"zero_length_span"
const REASON_SUBDIVISION_LIMIT := &"subdivision_limit"
const REASON_SAMPLE_LIMIT := &"sample_limit"


static func build_auto_curve(
	control_points: PackedVector3Array,
	bake_interval_meters: float,
	deduplicate_consecutive_points: bool = true
) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = maxf(
		bake_interval_meters,
		MIN_SAMPLE_SPACING_METERS
	)
	var resolved_points := (
		deduplicate_points(control_points)
		if deduplicate_consecutive_points
		else control_points
	)
	for point_index in range(resolved_points.size()):
		curve.add_point(
			resolved_points[point_index],
			resolve_auto_curve_handle(
				resolved_points,
				point_index,
				true
			),
			resolve_auto_curve_handle(
				resolved_points,
				point_index,
				false
			)
		)
	return curve


static func sample_auto_curve(
	control_points: PackedVector3Array,
	max_spacing_meters: float,
	flatness_tolerance_meters: float,
	max_subdivision_depth: int = DEFAULT_MAX_SUBDIVISION_DEPTH,
	max_samples_per_span: int = DEFAULT_MAX_SAMPLES_PER_SPAN
) -> Dictionary:
	var sampled_points := PackedVector3Array()
	var span_offsets := PackedInt32Array()
	var span_validity: Array[bool] = []
	var span_reasons: Array[StringName] = []
	if control_points.is_empty():
		return {
			"valid": false,
			"points": sampled_points,
			"span_offsets": span_offsets,
			"span_validity": span_validity,
			"span_reasons": span_reasons,
		}
	sampled_points.append(control_points[0])
	span_offsets.append(0)
	if control_points.size() == 1:
		return {
			"valid": true,
			"points": sampled_points,
			"span_offsets": span_offsets,
			"span_validity": span_validity,
			"span_reasons": span_reasons,
		}
	var spacing := maxf(max_spacing_meters, MIN_SAMPLE_SPACING_METERS)
	var flatness := maxf(
		flatness_tolerance_meters,
		MIN_FLATNESS_TOLERANCE_METERS
	)
	var depth_limit := maxi(max_subdivision_depth, 0)
	var sample_limit := maxi(max_samples_per_span, 2)
	var curve := build_auto_curve(control_points, spacing, false)
	var all_spans_valid := true
	for span_index in range(control_points.size() - 1):
		var span_start: Vector3 = control_points[span_index]
		var span_end: Vector3 = control_points[span_index + 1]
		var span_result := {
			"valid": true,
			"reason": REASON_NONE,
			"sample_count": 1,
		}
		if span_start.distance_squared_to(span_end) <= GEOMETRY_EPSILON_SQUARED:
			span_result["valid"] = false
			span_result["reason"] = REASON_ZERO_LENGTH_SPAN
			_append_unique_point(sampled_points, span_end)
		else:
			_sample_curve_interval(
				curve,
				span_index,
				0.0,
				1.0,
				span_start,
				span_end,
				spacing,
				flatness,
				0,
				depth_limit,
				sample_limit,
				sampled_points,
				span_result
			)
			# The exact authored dot is always the final point of its span.
			if sampled_points[sampled_points.size() - 1] != span_end:
				_append_unique_point(sampled_points, span_end)
		span_offsets.append(sampled_points.size() - 1)
		var span_is_valid := bool(span_result.get("valid", false))
		span_validity.append(span_is_valid)
		span_reasons.append(StringName(span_result.get("reason", REASON_NONE)))
		all_spans_valid = all_spans_valid and span_is_valid
	return {
		"valid": all_spans_valid,
		"points": sampled_points,
		"span_offsets": span_offsets,
		"span_validity": span_validity,
		"span_reasons": span_reasons,
	}


static func resolve_auto_curve_handle(
	points: PackedVector3Array,
	point_index: int,
	use_in_handle: bool
) -> Vector3:
	if point_index < 0 or point_index >= points.size():
		return Vector3.ZERO
	var current_position: Vector3 = points[point_index]
	var previous_position: Variant = null
	var next_position: Variant = null
	if point_index > 0:
		previous_position = points[point_index - 1]
	if point_index < points.size() - 1:
		next_position = points[point_index + 1]
	var auto_handle := Vector3.ZERO
	if previous_position is Vector3 and next_position is Vector3:
		var smooth_tangent := (
			(next_position as Vector3)
			- (previous_position as Vector3)
		) * AUTO_CURVE_MIDDLE_STRENGTH
		auto_handle = -smooth_tangent if use_in_handle else smooth_tangent
	elif use_in_handle and previous_position is Vector3:
		auto_handle = (
			(previous_position as Vector3)
			- current_position
		) * AUTO_CURVE_ENDPOINT_STRENGTH
	elif not use_in_handle and next_position is Vector3:
		auto_handle = (
			(next_position as Vector3)
			- current_position
		) * AUTO_CURVE_ENDPOINT_STRENGTH
	if auto_handle.length() < AUTO_CURVE_HANDLE_MIN_LENGTH_METERS:
		return Vector3.ZERO
	return auto_handle


static func deduplicate_points(
	points: PackedVector3Array
) -> PackedVector3Array:
	var deduplicated := PackedVector3Array()
	for point: Vector3 in points:
		if (
			not deduplicated.is_empty()
			and deduplicated[deduplicated.size() - 1].distance_squared_to(
				point
			) <= 0.000001
		):
			continue
		deduplicated.append(point)
	return deduplicated


static func _sample_curve_interval(
	curve: Curve3D,
	span_index: int,
	from_ratio: float,
	to_ratio: float,
	from_point: Vector3,
	to_point: Vector3,
	max_spacing_meters: float,
	flatness_tolerance_meters: float,
	depth: int,
	max_subdivision_depth: int,
	max_samples_per_span: int,
	output_points: PackedVector3Array,
	span_result: Dictionary
) -> void:
	if not bool(span_result.get("valid", true)):
		return
	var quarter_ratio := lerpf(from_ratio, to_ratio, 0.25)
	var middle_ratio := lerpf(from_ratio, to_ratio, 0.5)
	var three_quarter_ratio := lerpf(from_ratio, to_ratio, 0.75)
	var quarter_point := curve.sample(span_index, quarter_ratio)
	var middle_point := curve.sample(span_index, middle_ratio)
	var three_quarter_point := curve.sample(span_index, three_quarter_ratio)
	var interval_is_resolved := (
		from_point.distance_to(to_point) <= max_spacing_meters
		and _distance_to_segment(quarter_point, from_point, to_point)
		<= flatness_tolerance_meters
		and _distance_to_segment(middle_point, from_point, to_point)
		<= flatness_tolerance_meters
		and _distance_to_segment(
			three_quarter_point,
			from_point,
			to_point
		) <= flatness_tolerance_meters
	)
	if interval_is_resolved:
		_append_unique_point(output_points, to_point)
		span_result["sample_count"] = int(
			span_result.get("sample_count", 1)
		) + 1
		return
	if depth >= max_subdivision_depth:
		span_result["valid"] = false
		span_result["reason"] = REASON_SUBDIVISION_LIMIT
		_append_unique_point(output_points, to_point)
		return
	if int(span_result.get("sample_count", 1)) + 2 > max_samples_per_span:
		span_result["valid"] = false
		span_result["reason"] = REASON_SAMPLE_LIMIT
		_append_unique_point(output_points, to_point)
		return
	_sample_curve_interval(
		curve,
		span_index,
		from_ratio,
		middle_ratio,
		from_point,
		middle_point,
		max_spacing_meters,
		flatness_tolerance_meters,
		depth + 1,
		max_subdivision_depth,
		max_samples_per_span,
		output_points,
		span_result
	)
	_sample_curve_interval(
		curve,
		span_index,
		middle_ratio,
		to_ratio,
		middle_point,
		to_point,
		max_spacing_meters,
		flatness_tolerance_meters,
		depth + 1,
		max_subdivision_depth,
		max_samples_per_span,
		output_points,
		span_result
	)


static func _append_unique_point(
	points: PackedVector3Array,
	point: Vector3
) -> void:
	if not points.is_empty() and points[points.size() - 1] == point:
		return
	points.append(point)


static func _distance_to_segment(
	point: Vector3,
	segment_start: Vector3,
	segment_end: Vector3
) -> float:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= GEOMETRY_EPSILON_SQUARED:
		return point.distance_to(segment_start)
	var ratio := clampf(
		(point - segment_start).dot(segment) / segment_length_squared,
		0.0,
		1.0
	)
	return point.distance_to(segment_start + segment * ratio)
