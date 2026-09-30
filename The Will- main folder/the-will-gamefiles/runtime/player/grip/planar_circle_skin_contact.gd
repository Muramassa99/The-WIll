extends RefCounted

## Analytic minimum signed circle clearance over each entire supplied segment.
## Scalar-double projection avoids endpoint-only misses and polygon chord error.
## Coordinates remain meters in one caller-supplied orthonormal named plane.
## This observes boundaries; it does not certify a solid hand, motion, or 3D grip.
const REVISION: StringName = &"planar_circle_skin_contact_v1"


func evaluate(segments: Array, center_m: Vector2, radius_m: float, origin_id: StringName, source_id: StringName) -> Dictionary:
	if origin_id == StringName() or source_id == StringName():
		return _fail("missing_circle_origin_or_source")
	if not center_m.is_finite() or not is_finite(radius_m) or radius_m <= 0.0:
		return _fail("invalid_circle_center_or_radius")
	if segments.is_empty():
		return _fail("missing_skin_segments")
	var results: Array[Dictionary] = []
	var nearest: Dictionary = {}
	var minimum_clearance: float = INF
	for index: int in segments.size():
		if not segments[index] is Dictionary:
			return _fail("invalid_skin_segment", {"segment_index": index})
		var segment: Dictionary = segments[index]
		var skin_source: Variant = segment.get("source_id")
		if segment.get("origin_id") != origin_id or not (skin_source is String or skin_source is StringName) or String(skin_source).is_empty():
			return _fail("missing_or_mismatched_skin_origin_or_source", {"segment_index": index})
		if not segment.get("a") is Vector2 or not segment.get("b") is Vector2:
			return _fail("missing_skin_endpoints", {"segment_index": index})
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		if not a.is_finite() or not b.is_finite() or a == b:
			return _fail("nonfinite_or_zero_length_skin_segment", {"segment_index": index})
		var dx: float = float(b.x) - float(a.x)
		var dy: float = float(b.y) - float(a.y)
		var cx: float = float(center_m.x) - float(a.x)
		var cy: float = float(center_m.y) - float(a.y)
		var t: float = clampf((cx * dx + cy * dy) / (dx * dx + dy * dy), 0.0, 1.0)
		var x: float = float(a.x) + t * dx
		var y: float = float(a.y) + t * dy
		var radial_x: float = x - float(center_m.x)
		var radial_y: float = y - float(center_m.y)
		var distance: float = sqrt(radial_x * radial_x + radial_y * radial_y)
		var clearance: float = distance - radius_m
		var ambiguous: bool = distance == 0.0
		var normal: Variant = null
		var circle_point: Variant = null
		if not ambiguous:
			var normal_x: float = radial_x / distance
			var normal_y: float = radial_y / distance
			normal = Vector2(normal_x, normal_y)
			circle_point = Vector2(float(center_m.x) + radius_m * normal_x, float(center_m.y) + radius_m * normal_y)
			if not (circle_point as Vector2).is_finite():
				return _fail("circle_witness_outside_vector_numeric_range", {"segment_index": index})
		var record: Dictionary = {"source_id": skin_source, "segment_index": index, "origin_id": origin_id,
			"circle_source_id": source_id, "signed_clearance_m": clearance,
			"maximum_inward_depth_m": maxf(-clearance, 0.0), "skin_point_m": Vector2(x, y),
			"circle_point_m": circle_point, "circle_outward_normal": normal,
			"tangent_ambiguous": ambiguous, "skin_segment_t": t, "distance_to_center_m": distance}
		results.append(record)
		if clearance < minimum_clearance:
			minimum_clearance = clearance
			nearest = record
	return {"valid": true, "revision": REVISION, "origin_id": origin_id, "source_id": source_id,
		"center_m": center_m, "radius_m": radius_m, "metric_units": &"meters",
		"min_signed_clearance_m": minimum_clearance, "maximum_inward_depth_m": maxf(-minimum_clearance, 0.0),
		"nearest_skin_point_m": nearest.skin_point_m, "nearest_circle_point_m": nearest.circle_point_m,
		"nearest_source_id": nearest.source_id, "nearest_segment_index": nearest.segment_index,
		"circle_outward_normal": nearest.circle_outward_normal, "tangent_ambiguous": nearest.tangent_ambiguous,
		"segments": results, "segment_count": results.size(),
		"measurement": &"minimum_over_whole_segments_of_distance_to_circle_center_minus_radius",
		"numeric_policy": &"scalar_double_projection_no_acceptance_epsilon_applied",
		"witness_policy": &"first_segment_with_smallest_signed_clearance_center_closest_point",
		"inside_solid_skin_classification_verified": false, "actual_3d_grip_verified": false, "grip_accepted": false}


func _fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"valid": false, "revision": REVISION, "reason": reason, "details": details,
		"inside_solid_skin_classification_verified": false, "actual_3d_grip_verified": false, "grip_accepted": false}
