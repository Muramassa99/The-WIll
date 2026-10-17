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
const FRAME_METADATA := &"forge_v2_path_roll_frames"
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


static func span_lengths_meters(points: PackedVector3Array, use_linear_path: bool) -> PackedFloat64Array:
	var lengths := PackedFloat64Array()
	for index in range(maxi(points.size() - 1, 0)):
		lengths.append(points[index].distance_to(points[index + 1]) if use_linear_path else _span_curve(points, index, false).get_baked_length())
	return lengths


static func point_roll_bounds_degrees(
	points: PackedVector3Array,
	rolls: PackedFloat64Array,
	index: int,
	use_linear_path: bool
) -> Vector2:
	if index < 0 or index >= points.size():
		return Vector2.ZERO
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
	return Vector2(ceil(lower - 0.00001), floor(upper + 0.00001))


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
	if not rolls.is_empty() and rolls.size() != points.size():
		result.merge({"valid": false, "reason": "roll_point_count_mismatch"}, true)
		return result
	for value in rolls:
		if not is_finite(value):
			result.merge({"valid": false, "reason": "roll_not_finite"}, true)
			return result
	var values := normalize_roll_degrees(rolls, points.size())
	var lengths := span_lengths_meters(points, use_linear_path)
	for index in range(lengths.size()):
		if absf(values[index + 1] - values[index]) > lengths[index] * MAX_ROLL_DEGREES_PER_METER + 0.00001:
			result.merge({"valid": false, "reason": "twist_pitch_below_minimum", "span_index": index}, true)
			return result
	return result


static func uses_linear_path(body: Variant) -> bool:
	return StringName(body.get("shape_kind")) not in [
		&"shape_kind_spline_profile_path", &"shape_kind_spline_capsule_path",
	]


static func build_base_curve(body: Variant, sample_spacing_meters: float) -> Curve3D:
	var points: PackedVector3Array = body.get("path_points")
	var curve: Curve3D
	if uses_linear_path(body):
		curve = Curve3D.new()
		curve.bake_interval = maxf(sample_spacing_meters, ARC_BAKE_INTERVAL_METERS)
		for point in points:
			curve.add_point(point)
	else:
		curve = PathSampler.build_auto_curve(points, sample_spacing_meters)
	apply_base_orientation(curve, points, body.get("path_surface_normals") as PackedVector3Array,
		body.get("profile_contact_direction_2d") as Vector2, float(body.get("profile_rotation_bias_degrees")))
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
	# The established Handle CSG path maps profile +X opposite to the
	# authored sweep frame. Preserve that convention when a roll is added.
	var mirror_profile_x := StringName(body.get("body_kind")) == &"body_kind_handle_profile"
	var radius := maxf(float(body.get("radius_meters")), MAX_ROLL_CHORD_ERROR_METERS)
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
		count = maxi(count, int(ceil(absf(rolls[span + 1] - rolls[span]) / angular_step)))
		for step in range(0 if sampled_points.is_empty() else 1, count + 1):
			var ratio := float(step) / float(count)
			var offset := lerpf(base_offsets[span], base_offsets[span + 1], ratio)
			var frame := sample_base_frame(base_curve, offset, mirror_profile_x)
			var position: Vector3 = frame.get("position")
			var tangent: Vector3 = frame.get("tangent")
			var roll := lerpf(rolls[span], rolls[span + 1], ratio)
			var rotation := Basis(tangent, -deg_to_rad(roll))
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
	var tangents: PackedVector3Array = data.get("tangents")
	var axes_x: PackedVector3Array = data.get("axis_x")
	var axes_y: PackedVector3Array = data.get("axis_y")
	var rolls: PackedFloat64Array = data.get("roll_degrees")
	return {
		"position": points[low].lerp(points[high], ratio),
		"tangent": tangents[low].lerp(tangents[high], ratio).normalized(),
		"axis_x": axes_x[low].lerp(axes_x[high], ratio).normalized(),
		"axis_y": axes_y[low].lerp(axes_y[high], ratio).normalized(),
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
