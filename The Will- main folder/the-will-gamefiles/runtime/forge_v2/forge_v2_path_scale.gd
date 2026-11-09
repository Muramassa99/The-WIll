extends RefCounted
class_name ForgeV2PathScale

# Profile-builder local X/Y multipliers; never rebase on the last edit.
# Authored interior-point minimum is enforced by the authoring owner. Resolved
# samples near a collapsed endpoint may legitimately be below that minimum.
const MIN_INTERIOR_SCALE := 0.05
const MAX_SCALE := 2.0
const LEAD_ARC_INTERVALS := 8


static func normalize_scale(value: Vector2) -> Vector2:
	if not value.is_finite():
		return Vector2.ONE
	var accepted := Vector2(clampf(value.x, 0.0, MAX_SCALE), clampf(value.y, 0.0, MAX_SCALE))
	# Full collapse is a point, never a flattened line cross-section. Positive
	# width/thickness values remain independent.
	return Vector2.ZERO if accepted.x == 0.0 or accepted.y == 0.0 else accepted


static func normalize(values: PackedVector2Array, count: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	result.resize(maxi(count, 0))
	for i in range(result.size()):
		var value := values[i] if i < values.size() else Vector2.ONE
		result[i] = normalize_scale(value)
	return result


static func body_scales(body: Variant, offsets: PackedFloat64Array = PackedFloat64Array()) -> PackedVector2Array:
	var points: PackedVector3Array = body.get("path_points")
	var values: Variant = body.get("path_profile_scales")
	if StringName(body.get("body_kind")) == &"body_kind_handle_profile":
		return normalize(PackedVector2Array(), points.size())
	var scales := normalize(values if values is PackedVector2Array else PackedVector2Array(), points.size())
	var ranges := body_ranges(body)
	if ranges.is_empty():
		return scales
	if offsets.size() != points.size():
		offsets = polyline_offsets(points)
	return resolve_controls(scales, offsets, ranges, profile_extents(body))


static func polyline_offsets(points: PackedVector3Array) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	var traveled := 0.0
	for i in range(points.size()):
		if i > 0:
			traveled += points[i - 1].distance_to(points[i])
		result.append(traveled)
	return result


static func resolve_controls(values: PackedVector2Array, offsets: PackedFloat64Array, ranges: Array, extents: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var result := normalize(values, offsets.size())
	if ranges.is_empty() or result.size() < 2:
		return result
	# A convenience view for point labels. Geometry uses sample_span because
	# an interior point can have distinct incoming and outgoing profiles.
	for i in range(result.size()):
		result[i] = sample_span(values, offsets, ranges, maxi(i - 1, 0), 0.0 if i == 0 else 1.0, extents)
	return result


static func normalize_ranges(ranges: Array, count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Variant in ranges:
		if not (entry is Dictionary):
			continue
		var a := int(entry.get("fixed_a", -1))
		var target := int(entry.get("scaled", -1))
		var b := int(entry.get("fixed_b", -1))
		if a < 0 or target < 0 or a >= count or target >= count or a == target or b < -1 or b >= count:
			continue
		if b >= 0 and not (mini(a, b) < target and target < maxi(a, b)):
			continue
		var valid := true
		var copy: Dictionary = entry.duplicate(true)
		for key: String in ["fixed_a_scale", "fixed_b_scale", "scale"]:
			var value: Variant = copy.get(key, Vector2.ONE)
			if not (value is Vector2) or not value.is_finite():
				valid = false
				break
			copy[key] = normalize_scale(value)
		if valid:
			result.append(copy)
	return result


static func body_ranges(body: Variant) -> Array:
	if StringName(body.get("body_kind")) == &"body_kind_handle_profile":
		return []
	var value: Variant = body.get("path_profile_transform_ranges")
	return value if value is Array else []


static func sample_span(values: PackedVector2Array, offsets: PackedFloat64Array, ranges: Array, span: int, ratio: float, extents: Vector2 = Vector2.ZERO) -> Vector2:
	if span < 0 or span + 1 >= offsets.size():
		return Vector2.ONE
	var position := lerpf(offsets[span], offsets[span + 1], ratio)
	for index in range(ranges.size() - 1, -1, -1):
		var entry: Dictionary = ranges[index]
		var target := int(entry.scaled)
		for boundary_key: String in ["fixed_a", "fixed_b"]:
			var boundary := int(entry.get(boundary_key, -1))
			if boundary < 0 or span < mini(boundary, target) or span >= maxi(boundary, target):
				continue
			var length := offsets[target] - offsets[boundary]
			var weight := (position - offsets[boundary]) / length if absf(length) > 0.000000001 else 0.0
			var start: Vector2 = entry[boundary_key + "_scale"]
			var target_scale: Vector2 = entry.scale
			var result := start
			for axis in range(2):
				var height := absf(target_scale[axis] - start[axis]) * extents[axis]
				result[axis] = lerpf(start[axis], target_scale[axis], _lead_weight(weight, absf(length), height))
			return result
	return sample_controls(values, span, ratio)


static func profile_extents(body: Variant) -> Vector2:
	# Distances from the existing profile origin/anchor to its outermost
	# contours. Uniform scaling preserves flutes and off-centre profiles;
	# lesser offsets follow proportionally rather than being independently cut.
	var polygon: Variant = body.get("profile_polygon_2d_meters")
	var result := Vector2.ZERO
	if polygon is PackedVector2Array and not polygon.is_empty():
		for point: Vector2 in polygon:
			result.x = maxf(result.x, absf(point.x))
			result.y = maxf(result.y, absf(point.y))
		return result
	return Vector2.ONE * maxf(float(body.get("radius_meters")), 0.001)


static func taper_radius_meters(length_meters: float) -> float:
	# 5% of the selected leg's path distance, rounded half-up to 0.01 mm.
	# Tiny epsilon handles binary representation of exact decimal half steps.
	return floorf(maxf(length_meters, 0.0) * 5000.0 + 0.5 + 1.0e-9) * 0.00001


static func _lead_angle(length: float, height: float, radius: float) -> float:
	# Circle centre is (0,r). Choose its tangent passing through (length,height).
	# This keeps the boundary tangent flat AND reaches the authored end size.
	return atan2(height - radius, length) + asin(clampf(radius / sqrt(length * length + (height - radius) * (height - radius)), 0.0, 1.0))


static func _lead_weight(weight: float, length: float, height: float) -> float:
	var t := clampf(weight, 0.0, 1.0)
	var radius := taper_radius_meters(length)
	if t == 0.0 or t == 1.0 or height <= 1.0e-12 or radius <= 0.0 or length <= radius:
		return t
	var angle := _lead_angle(length, height, radius)
	var arc_end := radius * sin(angle)
	var distance := length * t
	var displacement: float
	if distance < arc_end:
		# Stable equivalent of r - sqrt(r*r-x*x), including shallow bends.
		displacement = distance * distance / (radius + sqrt(maxf(radius * radius - distance * distance, 0.0)))
	else:
		displacement = radius * 2.0 * pow(sin(angle * 0.5), 2.0) + (distance - arc_end) * tan(angle)
	return clampf(displacement / height, 0.0, 1.0)


static func max_body_scale(body: Variant) -> float:
	var maximum := 1.0
	for value: Vector2 in body_scales(body):
		maximum = maxf(maximum, maxf(value.x, value.y))
	for entry: Dictionary in body_ranges(body):
		for key: String in ["fixed_a_scale", "fixed_b_scale", "scale"]:
			var value: Vector2 = entry.get(key, Vector2.ONE)
			maximum = maxf(maximum, maxf(value.x, value.y))
	return maximum


static func span_sample_ratios(offsets: PackedFloat64Array, ranges: Array, span: int, extents: Vector2, count: int = 1) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	for step in range(count + 1):
		result.append(float(step) / float(count))
	var span_length := offsets[span + 1] - offsets[span]
	if span_length <= 1.0e-9:
		return result
	for entry: Dictionary in ranges:
		var target := int(entry.scaled)
		for boundary_key: String in ["fixed_a", "fixed_b"]:
			var boundary := int(entry.get(boundary_key, -1))
			if boundary < 0 or span < mini(boundary, target) or span >= maxi(boundary, target):
				continue
			var length := absf(offsets[target] - offsets[boundary])
			var radius := taper_radius_meters(length)
			if radius <= 0.0 or length <= radius:
				continue
			var direction := signf(offsets[target] - offsets[boundary])
			for axis in range(2):
				var height := absf((entry.scale as Vector2)[axis] - (entry[boundary_key + "_scale"] as Vector2)[axis]) * extents[axis]
				if height <= 1.0e-12:
					continue
				var angle := _lead_angle(length, height, radius)
				for step in range(1, LEAD_ARC_INTERVALS + 1):
					var position := offsets[boundary] + direction * radius * sin(angle * float(step) / LEAD_ARC_INTERVALS)
					var ratio := (position - offsets[span]) / span_length
					if ratio > 1.0e-8 and ratio < 1.0 - 1.0e-8:
						result.append(ratio)
	result.sort()
	var unique := PackedFloat64Array()
	for ratio: float in result:
		if unique.is_empty() or ratio - unique[-1] > 1.0e-8:
			unique.append(ratio)
	return unique


static func has_scale(body: Variant) -> bool:
	if body == null or StringName(body.get("body_kind")) == &"body_kind_handle_profile":
		return false
	if not body_ranges(body).is_empty():
		return true
	var values: Variant = body.get("path_profile_scales")
	if values is PackedVector2Array:
		for value: Vector2 in values:
			if value != Vector2.ONE:
				return true
	return false


static func sample_controls(scales: PackedVector2Array, span: int, ratio: float) -> Vector2:
	if scales.is_empty():
		return Vector2.ONE
	return scales[clampi(span, 0, scales.size() - 1)].lerp(scales[clampi(span + 1, 0, scales.size() - 1)], clampf(ratio, 0.0, 1.0))


static func resolve_detail_scales(control_scales: PackedVector2Array, points: PackedVector3Array, span_offsets: PackedInt32Array) -> PackedVector2Array:
	var result := normalize(PackedVector2Array(), points.size())
	var controls := normalize(control_scales, span_offsets.size())
	for span in range(span_offsets.size() - 1):
		var start := int(span_offsets[span])
		var end := int(span_offsets[span + 1])
		if start < 0 or end >= points.size() or end < start:
			continue
		var length := 0.0
		for i in range(start, end):
			length += points[i].distance_to(points[i + 1])
		var traveled := 0.0
		for i in range(start, end + 1):
			if i > start:
				traveled += points[i - 1].distance_to(points[i])
			result[i] = sample_controls(controls, span, traveled / length if length > 0.000000001 else 0.0)
	return result


static func weighted_path_length(points: PackedVector3Array, values: PackedVector2Array) -> float:
	return weighted_transformed_path_length(points, values, [])


static func weighted_body_path_length(body: Variant) -> float:
	return weighted_transformed_path_length(body.get("path_points"), body.get("path_profile_scales"), body_ranges(body), PackedFloat64Array(), profile_extents(body))


static func weighted_transformed_path_length(points: PackedVector3Array, values: PackedVector2Array, ranges: Array, offsets: PackedFloat64Array = PackedFloat64Array(), extents: Vector2 = Vector2.ZERO) -> float:
	var scales := normalize(values, points.size())
	if offsets.size() != points.size():
		offsets = polyline_offsets(points)
	var result := 0.0
	for i in range(points.size() - 1):
		# Integrate on arc/straight subintervals shared with the sweep. Four
		# Gauss samples resolve the short curved lead; the straight portion's
		# product of linear dimensions is exact. Never average only endpoints.
		var average_area := 0.0
		var samples := span_sample_ratios(offsets, ranges, i, extents)
		for segment in range(samples.size() - 1):
			var start := samples[segment]
			var end := samples[segment + 1]
			for pair: Vector2 in [Vector2(0.0694318442029737, 0.173927422568727),
				Vector2(0.330009478207572, 0.326072577431273),
				Vector2(0.669990521792428, 0.326072577431273),
				Vector2(0.930568155797026, 0.173927422568727)]:
				var value := sample_span(scales, offsets, ranges, i, lerpf(start, end, pair.x), extents)
				average_area += (end - start) * pair.y * value.x * value.y
		result += points[i].distance_to(points[i + 1]) * average_area
	return result
