extends RefCounted
class_name ForgeV2PathRoll

const PathSampler = preload("res://runtime/forge_v2/forge_v2_spline_path_sampler.gd")
const ProfileLibrary = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")

# Authored angles are unwrapped totals. Positive is clockwise looking from
# the end of the path back toward its beginning.
const MIN_TWIST_PITCH_METERS := 0.005
const MAX_ROLL_DEGREES_PER_METER := 360.0 / MIN_TWIST_PITCH_METERS
const MAX_SAMPLE_ROLL_DEGREES := 5.0
const MAX_ROLL_CHORD_ERROR_METERS := 0.00005
const ARC_BAKE_INTERVAL_METERS := 0.0001
const BASE_BAKE_INTERVAL_METERS := 0.0005
const FRAME_METADATA := &"forge_v2_path_roll_frames"
const SWEEP_REVISION := 2
const EPSILON := 0.000000001


static func normalize_roll_degrees(values: PackedFloat64Array, point_count: int) -> PackedFloat64Array:
	# Only the absent legacy field supplies defaults. Never repair malformed
	# authored geometry silently; validation reports it before generation.
	if not values.is_empty():
		return values.duplicate()
	var result := PackedFloat64Array()
	result.resize(maxi(point_count, 0))
	return result


static func has_roll(body: Variant) -> bool:
	if body == null:
		return false
	var values: Variant = body.get("path_roll_degrees")
	if not (values is PackedFloat64Array):
		return false
	for value: float in values:
		if not is_zero_approx(value):
			return true
	return false


static func uses_shared_sweep(body: Variant) -> bool:
	return body != null and (has_roll(body)
		or StringName(body.get("body_kind")) == &"body_kind_handle_profile"
		or StringName(body.get("shape_kind")) in [
			&"shape_kind_spline_profile_path", &"shape_kind_spline_capsule_path"])


static func span_lengths_meters(points: PackedVector3Array, use_linear_path: bool) -> PackedFloat64Array:
	var lengths := PackedFloat64Array()
	var total := 0.0
	for index in range(maxi(points.size() - 1, 0)):
		lengths.append(points[index].distance_to(points[index + 1]) if use_linear_path else _span_curve(points, index, false).get_baked_length())
		total += lengths[lengths.size() - 1]
	# Validation, bounds and mesh sampling use the same baked distance scale.
	if total > EPSILON:
		var scale := _center_curve(points, use_linear_path).get_baked_length() / total
		for i in range(lengths.size()):
			lengths[i] *= scale
	return lengths


static func point_roll_bounds_degrees(
	points: PackedVector3Array,
	rolls: PackedFloat64Array,
	index: int,
	use_linear_path: bool
) -> Vector2:
	if index < 0 or index >= points.size():
		return Vector2.ZERO
	for point in points:
		if not point.is_finite():
			return Vector2(1, 0)
	if points.size() < 2:
		return Vector2(-INF, INF)
	var values := normalize_roll_degrees(rolls, points.size())
	if values.size() != points.size():
		return Vector2.ZERO
	for value in values:
		if not is_finite(value):
			return Vector2.ZERO
	var lengths := span_lengths_meters(points, use_linear_path)
	var lower := -INF
	var upper := INF
	if index > 0:
		var delta := lengths[index - 1] * MAX_ROLL_DEGREES_PER_METER
		lower = maxf(lower, values[index - 1] - delta)
		upper = minf(upper, values[index - 1] + delta)
	if index < points.size() - 1:
		var delta := lengths[index] * MAX_ROLL_DEGREES_PER_METER
		lower = maxf(lower, values[index + 1] - delta)
		upper = minf(upper, values[index + 1] + delta)
	# Smoothing can raise the interior rate above the endpoint secant. Tighten
	# each side against the complete curve, including neighbouring slopes.
	var anchor := clampf(values[index], lower, upper)
	var candidate := values.duplicate()
	candidate[index] = anchor
	if _invalid_rate_span(candidate, lengths) >= 0:
		return Vector2(1, 0)
	var bounds := Vector2.ZERO
	for side in range(2):
		var outside := lower if side == 0 else upper
		candidate[index] = outside
		if _invalid_rate_span(candidate, lengths) >= 0:
			var inside := anchor
			for iteration in range(40):
				var middle := (inside + outside) * 0.5
				candidate[index] = middle
				if _invalid_rate_span(candidate, lengths) >= 0:
					outside = middle
				else:
					inside = middle
			outside = inside
		bounds[side] = ceil(outside) if side == 0 else floor(outside)
	return bounds


static func validate_roll_profile(
	points: PackedVector3Array,
	rolls: PackedFloat64Array,
	use_linear_path: bool
) -> Dictionary:
	var result := {
		"valid": true, "reason": "", "span_index": -1,
		"min_pitch_meters": MIN_TWIST_PITCH_METERS,
		"max_degrees_per_meter": MAX_ROLL_DEGREES_PER_METER,
	}
	for point in points:
		if not point.is_finite():
			result.merge({"valid": false, "reason": "path_point_not_finite"}, true)
			return result
	for i in range(points.size() - 1):
		if points[i].distance_squared_to(points[i + 1]) <= EPSILON * EPSILON:
			result.merge({"valid": false, "reason": "zero_length_span", "span_index": i}, true)
			return result
	if not rolls.is_empty() and rolls.size() != points.size():
		result.merge({"valid": false, "reason": "roll_point_count_mismatch"}, true)
		return result
	for value in rolls:
		if not is_finite(value):
			result.merge({"valid": false, "reason": "roll_not_finite"}, true)
			return result
	var values := normalize_roll_degrees(rolls, points.size())
	var lengths := span_lengths_meters(points, use_linear_path)
	var invalid_span := _invalid_rate_span(values, lengths)
	if invalid_span >= 0:
		result.merge({"valid": false, "reason": "twist_pitch_below_minimum", "span_index": invalid_span}, true)
	return result


static func _roll_slopes(values: PackedFloat64Array, lengths: PackedFloat64Array) -> PackedFloat64Array:
	# Shape-preserving cubic Hermite slopes in degrees/metre (PCHIP).
	var slopes := PackedFloat64Array()
	slopes.resize(values.size())
	if lengths.is_empty():
		return slopes
	var secants := PackedFloat64Array()
	for i in range(lengths.size()):
		secants.append((values[i + 1] - values[i]) / maxf(lengths[i], EPSILON))
	if secants.size() == 1:
		slopes[0] = secants[0]
		slopes[1] = secants[0]
		return slopes
	for i in range(1, values.size() - 1):
		if secants[i - 1] * secants[i] <= 0.0:
			continue
		var w1 := 2.0 * lengths[i] + lengths[i - 1]
		var w2 := lengths[i] + 2.0 * lengths[i - 1]
		slopes[i] = (w1 + w2) / (w1 / secants[i - 1] + w2 / secants[i])
	slopes[0] = _end_slope(lengths[0], lengths[1], secants[0], secants[1])
	var last := lengths.size() - 1
	slopes[slopes.size() - 1] = _end_slope(lengths[last], lengths[last - 1], secants[last], secants[last - 1])
	return slopes


static func _end_slope(h0: float, h1: float, d0: float, d1: float) -> float:
	var slope := ((2.0 * h0 + h1) * d0 - h0 * d1) / maxf(h0 + h1, EPSILON)
	if slope * d0 <= 0.0:
		return 0.0
	return signf(slope) * minf(absf(slope), 3.0 * absf(d0)) if d0 * d1 <= 0.0 else slope


static func _roll_value(a: float, b: float, m0: float, m1: float, length: float, t: float) -> float:
	var delta := b - a
	return a + t * (length * m0 + t * (3.0 * delta - length * (2.0 * m0 + m1) + t * (-2.0 * delta + length * (m0 + m1))))


static func _peak_roll_rate(a: float, b: float, m0: float, m1: float, length: float) -> float:
	var d := (b - a) / maxf(length, EPSILON)
	var quadratic := 3.0 * (m0 + m1 - 2.0 * d)
	var linear := 6.0 * d - 4.0 * m0 - 2.0 * m1
	var peak := maxf(absf(m0), absf(m1))
	if absf(quadratic) > EPSILON:
		var t := -linear / (2.0 * quadratic)
		if t > 0.0 and t < 1.0:
			peak = maxf(peak, absf((quadratic * t + linear) * t + m0))
	return peak


static func _invalid_rate_span(values: PackedFloat64Array, lengths: PackedFloat64Array) -> int:
	for i in range(lengths.size()):
		if not is_finite(lengths[i]) or lengths[i] <= EPSILON or not is_finite((values[i + 1] - values[i]) / lengths[i]):
			return i
	var slopes := _roll_slopes(values, lengths)
	for i in range(lengths.size()):
		var peak := _peak_roll_rate(values[i], values[i + 1], slopes[i], slopes[i + 1], lengths[i])
		if not is_finite(slopes[i]) or not is_finite(slopes[i + 1]) or not is_finite(peak) or peak > MAX_ROLL_DEGREES_PER_METER + 0.00001:
			return i
	return -1


static func uses_linear_path(body: Variant) -> bool:
	return StringName(body.get("shape_kind")) not in [
		&"shape_kind_spline_profile_path", &"shape_kind_spline_capsule_path",
	]


static func _center_curve(points: PackedVector3Array, linear: bool) -> Curve3D:
	var curve: Curve3D
	if linear:
		curve = Curve3D.new()
		curve.bake_interval = BASE_BAKE_INTERVAL_METERS
		for point in points:
			curve.add_point(point)
	else:
		curve = PathSampler.build_auto_curve(points, BASE_BAKE_INTERVAL_METERS, false)
	return curve


static func build_base_curve(body: Variant, _sample_spacing_meters: float) -> Curve3D:
	var points: PackedVector3Array = body.get("path_points")
	var curve := _center_curve(points, uses_linear_path(body))
	# A placement plane guides the centreline; it must not introduce a new
	# roll constraint at every dot. Anchor facing once in the transported frame.
	if curve.point_count >= 2:
		var pose := curve.sample_baked_with_rotation(0.0, false, false)
		var tangent := (pose.basis * Vector3.FORWARD).normalized()
		var normals: PackedVector3Array = body.get("path_surface_normals")
		var normal := normals[0] if not normals.is_empty() else Vector3.FORWARD
		var initial := ProfileLibrary.resolve_profile_path_frame(tangent, normal,
			body.get("profile_contact_direction_2d") as Vector2, float(body.get("profile_rotation_bias_degrees")))
		var tilt := curve.sample_baked_up_vector(0.0, false).signed_angle_to(initial.axis_y, tangent)
		for i in range(curve.point_count):
			curve.set_point_tilt(i, tilt)
	return curve


static func apply_base_orientation(curve: Curve3D, source_points: PackedVector3Array,
	source_normals: PackedVector3Array, contact: Vector2, rotation_bias: float) -> void:
	if curve == null or curve.point_count < 2:
		return
	var previous_tilt := 0.0
	var aligned := curve.point_count == source_points.size() and source_normals.size() >= source_points.size()
	for index in range(curve.point_count):
		var position := curve.get_point_position(index)
		var tangent := Vector3.ZERO
		if index > 0:
			tangent += position - curve.get_point_position(index - 1)
		if index < curve.point_count - 1:
			tangent += curve.get_point_position(index + 1) - position
		tangent = tangent.normalized() if tangent.length_squared() > 0.000001 else Vector3.RIGHT
		var normal := ProfileLibrary.interpolate_path_surface_normal(source_normals, index, 0.0) if aligned and position.is_equal_approx(source_points[index]) else ProfileLibrary.resolve_path_surface_normal(position, source_points, source_normals)
		var frame := ProfileLibrary.resolve_profile_path_frame(tangent, normal, contact, rotation_bias)
		var tilt := float(frame.get("tilt_radians", 0.0))
		if index > 0:
			while tilt - previous_tilt > PI:
				tilt -= TAU
			while tilt - previous_tilt < -PI:
				tilt += TAU
		curve.set_point_tilt(index, tilt)
		previous_tilt = tilt


static func sample_base_frame(curve: Curve3D, offset: float, mirror_profile_x: bool = true) -> Dictionary:
	var safe_offset := clampf(offset, 0.0, curve.get_baked_length())
	var pose := curve.sample_baked_with_rotation(safe_offset, false, false)
	var tangent := (pose.basis * Vector3.FORWARD).normalized()
	var up := curve.sample_baked_up_vector(safe_offset, true).normalized()
	var facing := Transform3D.IDENTITY.looking_at(tangent, up)
	# Native path extrusion uses facing +X. Ordinary authored splines flip
	# profile X at the CSG boundary; Handles retain native handedness.
	return {"position": curve.sample_baked(safe_offset), "tangent": tangent,
		"axis_x": (facing.basis.x if mirror_profile_x else -facing.basis.x).normalized(),
		"axis_y": facing.basis.y.normalized()}


static func control_offsets(body: Variant, curve: Curve3D) -> PackedFloat64Array:
	# Span arc lengths preserve placement order even when a path crosses or
	# returns to an earlier dot. A global nearest-point query cannot do that.
	var lengths := span_lengths_meters(body.get("path_points") as PackedVector3Array, uses_linear_path(body))
	var total := 0.0
	for length in lengths:
		total += length
	var offsets := PackedFloat64Array([0.0])
	var traveled := 0.0
	for length in lengths:
		traveled += length
		offsets.append(curve.get_baked_length() * traveled / total if total > EPSILON else 0.0)
	return offsets


static func build_body_curve(body: Variant, sample_spacing_meters: float) -> Curve3D:
	if body == null:
		return null
	var points: PackedVector3Array = body.get("path_points")
	var rolls: PackedFloat64Array = body.get("path_roll_degrees")
	var linear := uses_linear_path(body)
	if points.size() < 2 or not bool(validate_roll_profile(points, rolls, linear).get("valid", false)):
		return null
	rolls = normalize_roll_degrees(rolls, points.size())
	var base_curve := build_base_curve(body, sample_spacing_meters)
	var base_offsets := control_offsets(body, base_curve)
	var lengths := PackedFloat64Array()
	for i in range(base_offsets.size() - 1):
		lengths.append(base_offsets[i + 1] - base_offsets[i])
	var slopes := _roll_slopes(rolls, lengths)
	# The established Handle CSG path maps profile +X opposite to the
	# authored sweep frame. Preserve that convention when a roll is added.
	var mirror_profile_x := StringName(body.get("body_kind")) == &"body_kind_handle_profile"
	var radius := maxf(float(body.get("radius_meters")), MAX_ROLL_CHORD_ERROR_METERS)
	var polygon: Variant = body.get("profile_polygon_2d_meters")
	if polygon is PackedVector2Array:
		for vertex: Vector2 in polygon:
			radius = maxf(radius, vertex.length())
	var angular_step := minf(MAX_SAMPLE_ROLL_DEGREES, rad_to_deg(2.0 * acos(clampf(1.0 - MAX_ROLL_CHORD_ERROR_METERS / radius, -1.0, 1.0))))
	var curve := Curve3D.new()
	curve.bake_interval = ARC_BAKE_INTERVAL_METERS
	var sampled_points := PackedVector3Array()
	var tangents := PackedVector3Array()
	var axes_x := PackedVector3Array()
	var axes_y := PackedVector3Array()
	var sampled_rolls := PackedFloat64Array()
	var distances := PackedFloat64Array()
	var source_offsets := PackedFloat64Array([0.0])
	var traveled := 0.0
	for span in range(points.size() - 1):
		var length := base_offsets[span + 1] - base_offsets[span]
		if length <= EPSILON:
			source_offsets.append(traveled)
			continue
		var count := maxi(1, int(ceil(length / maxf(sample_spacing_meters, ARC_BAKE_INTERVAL_METERS))))
		var peak_rate := _peak_roll_rate(rolls[span], rolls[span + 1], slopes[span], slopes[span + 1], length)
		count = maxi(count, int(ceil(peak_rate * length / angular_step)))
		for step in range(0 if sampled_points.is_empty() else 1, count + 1):
			var ratio := float(step) / float(count)
			var offset := lerpf(base_offsets[span], base_offsets[span + 1], ratio)
			var frame := sample_base_frame(base_curve, offset, mirror_profile_x)
			var position: Vector3 = frame.get("position")
			var tangent: Vector3 = frame.get("tangent")
			var roll := _roll_value(rolls[span], rolls[span + 1], slopes[span], slopes[span + 1], length, ratio)
			var rotation := Basis(tangent, -deg_to_rad(fposmod(roll, 360.0)))
			var axis_x: Vector3 = rotation * (frame.get("axis_x") as Vector3)
			var axis_y: Vector3 = rotation * (frame.get("axis_y") as Vector3)
			if not sampled_points.is_empty():
				traveled += position.distance_to(sampled_points[sampled_points.size() - 1])
			sampled_points.append(position)
			tangents.append(tangent)
			axes_x.append(axis_x)
			axes_y.append(axis_y)
			sampled_rolls.append(roll)
			distances.append(traveled)
			curve.add_point(position)
		source_offsets.append(traveled)
	curve.set_meta(FRAME_METADATA, {
		"points": sampled_points, "tangents": tangents,
		"axis_x": axes_x, "axis_y": axes_y,
		"roll_degrees": sampled_rolls, "distances": distances,
		"source_offsets": source_offsets,
		"mirror_profile_x": mirror_profile_x,
	})
	return curve


static func sample_frame(curve: Curve3D, offset: float) -> Dictionary:
	if curve == null or not curve.has_meta(FRAME_METADATA):
		return {}
	var data: Dictionary = curve.get_meta(FRAME_METADATA)
	var distances: PackedFloat64Array = data.get("distances")
	if distances.is_empty():
		return {}
	var low := 0
	var high := distances.size() - 1
	while low + 1 < high:
		var middle := int((low + high) / 2)
		if distances[middle] <= offset:
			low = middle
		else:
			high = middle
	var ratio := 0.0
	if high != low and distances[high] - distances[low] > EPSILON:
		ratio = clampf((offset - distances[low]) / (distances[high] - distances[low]), 0.0, 1.0)
	var points: PackedVector3Array = data.get("points")
	var axes_x: PackedVector3Array = data.get("axis_x")
	var axes_y: PackedVector3Array = data.get("axis_y")
	var rolls: PackedFloat64Array = data.get("roll_degrees")
	# Interpolate a proper rotation, then restore the profile reflection.
	# Independent normalized axis lerps need not stay perpendicular in 3D.
	var from := Basis(axes_x[low], axes_y[low], axes_x[low].cross(axes_y[low]).normalized()).get_rotation_quaternion()
	var to := Basis(axes_x[high], axes_y[high], axes_x[high].cross(axes_y[high]).normalized()).get_rotation_quaternion()
	var orientation := Basis(from.slerp(to, ratio))
	return {
		"position": points[low].lerp(points[high], ratio),
		"tangent": -orientation.z if bool(data.get("mirror_profile_x", false)) else orientation.z,
		"axis_x": orientation.x,
		"axis_y": orientation.y,
		"roll_degrees": lerpf(rolls[low], rolls[high], ratio),
	}


static func control_tangent(points: PackedVector3Array, index: int, linear: bool) -> Vector3:
	if points.size() < 2 or index < 0 or index >= points.size():
		return Vector3.RIGHT
	if not linear:
		var outgoing := PathSampler.resolve_auto_curve_handle(points, index, false)
		if outgoing.length_squared() > EPSILON:
			return outgoing.normalized()
		var incoming := PathSampler.resolve_auto_curve_handle(points, index, true)
		if incoming.length_squared() > EPSILON:
			return -incoming.normalized()
	return ProfileLibrary.resolve_linear_path_point_tangent(points, index)


static func _span_curve(points: PackedVector3Array, index: int, linear: bool) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = ARC_BAKE_INTERVAL_METERS
	var outgoing := Vector3.ZERO if linear else PathSampler.resolve_auto_curve_handle(points, index, false)
	var incoming := Vector3.ZERO if linear else PathSampler.resolve_auto_curve_handle(points, index + 1, true)
	curve.add_point(points[index], Vector3.ZERO, outgoing)
	curve.add_point(points[index + 1], incoming, Vector3.ZERO)
	return curve


static func _span_tangent(curve: Curve3D, offset: float) -> Vector3:
	var delta := ARC_BAKE_INTERVAL_METERS
	return (curve.sample_baked(minf(offset + delta, curve.get_baked_length())) - curve.sample_baked(maxf(offset - delta, 0.0))).normalized()
