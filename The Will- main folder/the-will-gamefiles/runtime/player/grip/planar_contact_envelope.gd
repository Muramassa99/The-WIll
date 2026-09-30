extends RefCounted

## Isolated 2D disk-closing proof. Does not move skin, write poses, or certify grip.
## Coordinates and radius are meters in the caller's named orthonormal slice.
## A larger radius bridges more recesses: it is a MINIMUM inward bend radius.
const Validation = preload("res://runtime/player/grip/planar_skin_overlap_budget.gd")
const SegmentQuery = preload("res://runtime/player/grip/skin_plane_contact_query.gd")
const REVISION: StringName = &"planar_contact_envelope_proof_v1"
const DEFAULT_UNITS_PER_METER: float = 100000.0


func build(polygon_m: PackedVector2Array, plane_origin_id: StringName, source_id: StringName, inward_min_radius_m: float, complete: bool, units_per_meter: float = DEFAULT_UNITS_PER_METER) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	if not is_finite(inward_min_radius_m) or inward_min_radius_m <= 0.0:
		return _fail("invalid_inward_radius")
	if not is_finite(units_per_meter) or units_per_meter < 1000.0 or units_per_meter > 10000000.0:
		return _fail("invalid_numeric_unit_scale")
	var checked: Dictionary = Validation.new().prepare_target(polygon_m, plane_origin_id, source_id, complete)
	if not checked.get("valid", false):
		return _fail("invalid_source_polygon", checked)
	var source: PackedVector2Array = checked.polygon.duplicate()
	if Geometry2D.is_polygon_clockwise(source):
		source.reverse()
	# Arithmetic recentering only: returned points retain the caller's exact origin.
	var numeric_center_m: Vector2 = Vector2.ZERO
	for point: Vector2 in source:
		numeric_center_m += point / float(source.size())
	var scaled: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in source:
		var value: Vector2 = (point - numeric_center_m) * units_per_meter
		if not value.is_finite() or value.length() > 100000000.0:
			return _fail("numeric_extent_out_of_proof_range")
		scaled.append(value)
	var radius: float = inward_min_radius_m * units_per_meter
	if not is_finite(radius) or radius > 100000000.0:
		return _fail("numeric_radius_out_of_proof_range")
	var convex: bool = true
	for index: int in source.size():
		var a: Vector2 = source[index]
		var b: Vector2 = source[(index + 1) % source.size()]
		var c: Vector2 = source[(index + 2) % source.size()]
		if (b - a).cross(c - b) < 0.0:
			convex = false
			break
	var output: PackedVector2Array = source.duplicate()
	var scaled_output: PackedVector2Array = scaled.duplicate()
	var exact_duplicates_removed: int = 0
	var offset_started: int = Time.get_ticks_usec()
	if not convex:
		# Godot 4.7 fixes Clipper arc tolerance at 0.25 input units. Explicit
		# scale makes this 2.5 micrometers at the default, not 0.25 meters.
		var grown: Array[PackedVector2Array] = Geometry2D.offset_polygon(scaled, radius, Geometry2D.JOIN_ROUND)
		if grown.size() != 1:
			return _fail("dilation_is_not_one_loop", {"loop_count": grown.size()})
		var closed: Array[PackedVector2Array] = Geometry2D.offset_polygon(grown[0], -radius, Geometry2D.JOIN_ROUND)
		if closed.size() != 1:
			return _fail("closure_is_not_one_loop", {"loop_count": closed.size()})
		scaled_output = closed[0]
		output = PackedVector2Array()
		for point: Vector2 in scaled_output:
			var restored: Vector2 = point / units_per_meter + numeric_center_m
			# real_t conversion can collapse distinct offset coordinates to the
			# exact same output point. Remove only zero-length consecutive edges.
			if not output.is_empty() and restored == output[-1]:
				exact_duplicates_removed += 1
			else:
				output.append(restored)
		if output.size() > 1 and output[0] == output[-1]:
			output.resize(output.size() - 1)
			exact_duplicates_removed += 1
		scaled_output = PackedVector2Array()
		for point: Vector2 in output:
			scaled_output.append((point - numeric_center_m) * units_per_meter)
	var offset_ms: float = float(Time.get_ticks_usec() - offset_started) / 1000.0
	# Offsets produce real edges shorter than the unordered mesh-slice validator's
	# 1-micrometer endpoint-welding threshold. This already ORDERED polygon has
	# explicit adjacency: verify it without welding or deleting short segments.
	var output_check: Dictionary = _check_ordered_polygon(output)
	if not output_check.valid:
		return _fail("invalid_constructed_envelope", output_check)
	# Do not union away numerical undercut. Preserve it as evidence to be checked
	# by the independent verifier; successful construction is not acceptance.
	var outside: Array[PackedVector2Array] = Geometry2D.clip_polygons(scaled, scaled_output)
	var outside_area_m2: float = 0.0
	for loop: PackedVector2Array in outside:
		outside_area_m2 += _signed_area(loop) / (units_per_meter * units_per_meter)
	return {"valid": true, "revision": REVISION, "origin_id": plane_origin_id,
		"source_id": source_id, "metric_units": &"meters", "source_polygon_m": source,
		"envelope_polygon_m": output, "inward_min_radius_m": inward_min_radius_m,
		"maximum_inward_curvature_per_m": 1.0 / inward_min_radius_m,
		"numeric_units_per_meter": units_per_meter, "numeric_center_m": numeric_center_m,
		"nominal_offset_arc_tolerance_m": 0.25 / units_per_meter,
		"convex_identity": convex, "offset_ms": offset_ms,
		"output_validation": output_check,
		"exact_consecutive_duplicates_removed_after_metric_conversion": exact_duplicates_removed,
		"total_build_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"source_outside_area_m2": absf(outside_area_m2), "source_outside_loop_count": outside.size(),
		"construction": &"disk_dilation_then_disk_erosion_polygon_approximation",
		"envelope_verified": false, "continuous_curvature_certified": false,
		"actual_3d_grip_verified": false, "production_pose_written": false}


func _check_ordered_polygon(points: PackedVector2Array) -> Dictionary:
	if points.size() < 3 or _signed_area(points) == 0.0:
		return {"valid": false, "reason": "too_few_points_or_zero_area"}
	var query: RefCounted = SegmentQuery.new()
	for i: int in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		if not a.is_finite() or not b.is_finite() or a == b:
			return {"valid": false, "reason": "nonfinite_or_zero_length_edge", "edge": i}
		for j: int in range(i + 1, points.size()):
			var c: Vector2 = points[j]
			var d: Vector2 = points[(j + 1) % points.size()]
			if a.min(b).x > c.max(d).x or c.min(d).x > a.max(b).x or a.min(b).y > c.max(d).y or c.min(d).y > a.max(b).y:
				continue
			var hit: Dictionary = query._intersection(a, b, c, d)
			var adjacent: bool = j == i + 1 or (i == 0 and j == points.size() - 1)
			if not hit.is_empty() and (not adjacent or bool(hit.proper) or bool(hit.coincident)):
				return {"valid": false, "reason": "crossing_or_overlapping_edges", "edges": [i, j], "points": [a,b,c,d], "intersection": hit}
	return {"valid": true, "method": "ordered_adjacency_no_endpoint_welding", "vertices_removed": 0}


func _signed_area(points: PackedVector2Array) -> float:
	var twice: float = 0.0
	for index: int in points.size():
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index + 1) % points.size()]
		twice += float(a.x) * float(b.y) - float(a.y) * float(b.x)
	return twice * 0.5


func _fail(reason: String, detail: Dictionary = {}) -> Dictionary:
	return {"valid": false, "revision": REVISION, "reason": reason, "detail": detail,
		"envelope_verified": false, "production_pose_written": false}
