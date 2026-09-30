extends RefCounted

const Contact = preload("res://runtime/player/grip/skin_plane_contact_query.gd")
const REVISION := &"planar_skin_overlap_budget_v1"

## One simple, complete polygon only; no holes, repaired contours or implicit
## completeness. Coordinates are physical meters in the named metric plane.
func prepare_target(polygon: PackedVector2Array, plane_origin_id: StringName, target_source_id: StringName, complete: bool) -> Dictionary:
	if plane_origin_id == StringName() or target_source_id == StringName():
		return _fail("missing_target_origin_or_source")
	if not complete:
		return _fail("incomplete_target_boundary")
	var points := polygon.duplicate()
	if points.size() > 1 and points[0] == points[-1]:
		points.resize(points.size() - 1)
	if points.size() < 3:
		return _fail("target_has_too_few_vertices")
	var edges: Array = []
	var edge_bounds: Array[PackedFloat64Array] = []
	var scale_m := 0.0
	var twice_area := 0.0
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for index: int in points.size():
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		if not a.is_finite() or not b.is_finite():
			return _fail("nonfinite_target_vertex")
		edges.append([a, b])
		edge_bounds.append(_scalar_bounds(a, b))
		scale_m = maxf(scale_m, maxf(absf(a.x), absf(a.y)))
		minimum = minimum.min(a)
		maximum = maximum.max(a)
		twice_area += float(a.x) * float(b.y) - float(b.x) * float(a.y)
	var checked: Dictionary = Contact.new().prepare_target(edges, plane_origin_id)
	if not bool(checked.get("valid", false)) or not bool(checked.get("topology_complete", false)) or twice_area == 0.0:
		return _fail("target_is_not_a_complete_simple_polygon", checked)
	return {"valid": true, "revision": REVISION, "polygon": points,
		"origin_id": plane_origin_id, "source_id": target_source_id, "metric_units": &"meters",
		"complete": true, "edges": edges, "edge_bounds": edge_bounds, "winding_sign": signf(twice_area),
		"coordinate_scale_m": scale_m, "diameter_upper_m": _distance(minimum, maximum),
		"actual_3d_grip_verified": false}


## An already ordered polygon has explicit index adjacency. Preserve all real
## edges, including edges shorter than the mesh-soup endpoint weld tolerance.
## This is not a relaxed prepare_target: validate every edge and nonadjacent
## intersection, and reject backtracking/overlaps without welding or repair.
func prepare_ordered_target(polygon: PackedVector2Array, plane_origin_id: StringName, target_source_id: StringName, complete: bool) -> Dictionary:
	if plane_origin_id == StringName() or target_source_id == StringName():
		return _fail("missing_target_origin_or_source")
	if not complete:
		return _fail("incomplete_target_boundary")
	var points := polygon.duplicate()
	if points.size() > 1 and points[0] == points[-1]:
		points.resize(points.size() - 1)
	if points.size() < 3:
		return _fail("target_has_too_few_vertices")
	var edges: Array = []
	var edge_bounds: Array[PackedFloat64Array] = []
	var scale_m := 0.0
	var twice_area := 0.0
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for index: int in points.size():
		var a := points[index]
		var b := points[(index + 1) % points.size()]
		if not a.is_finite() or not b.is_finite():
			return _fail("nonfinite_target_vertex", {"edge": index})
		if a == b:
			return _fail("zero_length_ordered_target_edge", {"edge": index})
		edges.append([a, b])
		edge_bounds.append(_scalar_bounds(a, b))
		scale_m = maxf(scale_m, maxf(absf(a.x), absf(a.y)))
		minimum = minimum.min(a)
		maximum = maximum.max(a)
		twice_area += float(a.x) * float(b.y) - float(b.x) * float(a.y)
	if not is_finite(twice_area) or twice_area == 0.0:
		return _fail("ordered_target_has_zero_or_nonfinite_area")
	var contact := Contact.new()
	for first: int in edges.size():
		for second: int in range(first + 1, edges.size()):
			if _bounds_distance_squared(edge_bounds[first], edge_bounds[second]) > 0.0:
				continue
			var hit: Dictionary = contact._intersection(edges[first][0], edges[first][1], edges[second][0], edges[second][1])
			var adjacent := second == first + 1 or (first == 0 and second == edges.size() - 1)
			if not hit.is_empty() and (not adjacent or bool(hit.proper) or bool(hit.coincident)):
				return _fail("ordered_target_crossing_or_overlapping_edges", {"edges": [first, second], "intersection": hit})
	# Deliberately the same prepared packet as prepare_target; depth/contact
	# evaluation has no alternate geometry, epsilon or acceptance behavior.
	return {"valid": true, "revision": REVISION, "polygon": points,
		"origin_id": plane_origin_id, "source_id": target_source_id, "metric_units": &"meters",
		"complete": true, "edges": edges, "edge_bounds": edge_bounds, "winding_sign": signf(twice_area),
		"coordinate_scale_m": scale_m, "diameter_upper_m": _distance(minimum, maximum),
		"actual_3d_grip_verified": false}


## Each skin segment supplies a/b, origin_id, source_id and max_inward_depth_m.
## Sources are caller-owned stable handles, independent of coordinate origins.
## Bounds use signed distance's 1-Lipschitz property along every inside interval.
## A sampled depth is only a lower bound, never an exact penetration claim.
## refine_depth_after_cap keeps narrowing geometric bounds after a cap decision,
## subject to the same deterministic evaluation budget and geometric tolerance.
## use_boundary_pruning=false keeps an exhaustive nearest-edge reference path.
## Both modes retain every intersection and the same depth classification/work.
func evaluate_segments(segments: Array, target: Dictionary, plane_origin_id: StringName, config: Dictionary = {}) -> Dictionary:
	if not bool(target.get("valid", false)) or target.get("revision") != REVISION or not bool(target.get("complete", false)):
		return _fail("invalid_prepared_target")
	if plane_origin_id == StringName() or target.get("origin_id") != plane_origin_id:
		return _fail("missing_or_mismatched_plane_origin")
	if segments.is_empty():
		return _fail("missing_skin_segments")
	var tolerance := float(config.get("depth_bound_tolerance_m", 0.000001))
	var requested_epsilon := float(config.get("numeric_epsilon_m", 0.000000001))
	var budget := int(config.get("max_evaluations_per_segment", 256))
	var refine_after_cap := bool(config.get("refine_depth_after_cap", false))
	var use_boundary_pruning := bool(config.get("use_boundary_pruning", true))
	if not is_finite(tolerance) or tolerance <= 0.0 or not is_finite(requested_epsilon) or requested_epsilon < 0.0 or budget < 3 or budget > 65536:
		return _fail("invalid_depth_bound_configuration")
	var results: Array = []
	var all_within := true
	var any_exceeds := false
	var evaluations := 0
	var work_counts := {"intersection_tests": 0, "contact_intersection_reuses": 0,
		"contact_nearest_tests": 0, "contact_aabb_tests": 0, "contact_aabb_prunes": 0}
	for index: int in segments.size():
		if not segments[index] is Dictionary:
			return _fail("invalid_skin_segment", {"segment_index": index})
		var segment: Dictionary = segments[index]
		if segment.get("origin_id") != plane_origin_id or StringName(segment.get("source_id", StringName())) == StringName():
			return _fail("missing_or_mismatched_skin_origin_or_source", {"segment_index": index})
		if not segment.get("a") is Vector2 or not segment.get("b") is Vector2:
			return _fail("missing_skin_endpoints", {"segment_index": index})
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		var cap := float(segment.get("max_inward_depth_m", -1.0))
		if not a.is_finite() or not b.is_finite() or a == b or not is_finite(cap) or cap < 0.0:
			return _fail("invalid_skin_segment_or_cap", {"segment_index": index})
		var scale_m: float = maxf(float(target.coordinate_scale_m), maxf(maxf(absf(a.x), absf(a.y)), maxf(absf(b.x), absf(b.y))))
		# Scalar-double depth arithmetic uses an explicit roundoff guard distinct
		# from the geometric interval width. The caller may enlarge this guard.
		var epsilon := maxf(requested_epsilon, maxf(1.0e-12, scale_m * 1.0e-12))
		var measured := _segment(segment, target, tolerance, epsilon, budget, refine_after_cap, use_boundary_pruning)
		measured["segment_index"] = index
		results.append(measured)
		all_within = all_within and measured.cap_status == &"within"
		any_exceeds = any_exceeds or measured.cap_status == &"exceeds"
		evaluations += int(measured.depth_evaluations)
		for key: String in work_counts:
			work_counts[key] += int(measured.work_counts[key])
	return {"valid": true, "revision": REVISION, "origin_id": plane_origin_id,
		"target_source_id": target.source_id, "segments": results,
		"cap_status": &"exceeds" if any_exceeds else (&"within" if all_within else &"unresolved"),
		"all_segments_within_cap": all_within, "any_segment_exceeds_cap": any_exceeds,
		"depth_evaluations": evaluations, "metric_units": &"meters",
		"refine_depth_after_cap": refine_after_cap,
		"use_boundary_pruning": use_boundary_pruning, "work_counts": work_counts,
		"acceptance_scope": &"supplied_2d_segments_against_one_polygon_only",
		"whole_skin_clearance_verified": false, "actual_3d_grip_verified": false}


func _segment(segment: Dictionary, target: Dictionary, tolerance: float, epsilon: float, budget: int, refine_after_cap: bool, use_boundary_pruning: bool) -> Dictionary:
	var a: Vector2 = segment.a
	var b: Vector2 = segment.b
	var cap: float = segment.max_inward_depth_m
	var contact = Contact.new()
	var cuts: Array[float] = [0.0, 1.0]
	var intersections: Array[Dictionary] = []
	for edge: Array in target.edges:
		var hit: Dictionary = contact._intersection(a, b, edge[0], edge[1])
		intersections.append(hit)
		if hit.is_empty():
			continue
		cuts.append(clampf(float(hit.t), 0.0, 1.0))
		if bool(hit.get("coincident", false)):
			cuts.append(clampf(_parameter(edge[0], a, b), 0.0, 1.0))
			cuts.append(clampf(_parameter(edge[1], a, b), 0.0, 1.0))
	cuts.sort()
	var unique: Array[float] = []
	for cut: float in cuts:
		if unique.is_empty() or cut != unique[-1]:
			unique.append(cut)
	var state := {"cache": {}, "evaluations": 0, "budget": budget,
		"maximum_sampled_depth_m": 0.0, "inside_interval_count": 0, "depth_witness": {}}
	var nodes: Array = []
	var pending_intervals := 0
	for index: int in range(unique.size() - 1):
		var lo := unique[index]
		var hi := unique[index + 1]
		var middle := _sample(a, b, (lo + hi) * 0.5, target, state)
		if middle.is_empty():
			pending_intervals += 1
			continue
		if not bool(middle.inside):
			continue
		state.inside_interval_count += 1
		var first := _sample(a, b, lo, target, state)
		var last := _sample(a, b, hi, target, state)
		if first.is_empty() or last.is_empty():
			pending_intervals += 1
			continue
		nodes.append(_node(lo, hi, first.depth_m, middle.depth_m, last.depth_m, _distance(a, b)))
	var bounds := _bounds(nodes, state, pending_intervals, target)
	var status := _cap_status(bounds, cap, epsilon)
	while (status == &"unresolved" or refine_after_cap) and float(bounds.upper_m) - float(bounds.lower_m) > tolerance and int(state.evaluations) + 2 <= budget and pending_intervals == 0:
		var best := -1
		var highest := -INF
		for index: int in nodes.size():
			if float(nodes[index].upper_m) > highest:
				highest = float(nodes[index].upper_m)
				best = index
		if best < 0:
			break
		var parent: Dictionary = nodes[best]
		var middle_t := (float(parent.lo) + float(parent.hi)) * 0.5
		var left := _sample(a, b, (float(parent.lo) + middle_t) * 0.5, target, state)
		var right := _sample(a, b, (middle_t + float(parent.hi)) * 0.5, target, state)
		if left.is_empty() or right.is_empty() or middle_t == float(parent.lo) or middle_t == float(parent.hi):
			break
		nodes[best] = _node(parent.lo, middle_t, parent.first_m, left.depth_m, parent.middle_m, _distance(a, b))
		nodes.append(_node(middle_t, parent.hi, parent.middle_m, right.depth_m, parent.last_m, _distance(a, b)))
		bounds = _bounds(nodes, state, pending_intervals, target)
		status = _cap_status(bounds, cap, epsilon)
	var lower := maxf(float(bounds.lower_m) - epsilon, 0.0)
	var upper := float(bounds.upper_m) + epsilon
	var witness: Dictionary = state.depth_witness.duplicate(true)
	if not witness.is_empty():
		witness["skin_source_id"] = segment.source_id
	var nearest := _nearest_contact(a, b, target, epsilon, intersections, use_boundary_pruning)
	var work_counts: Dictionary = nearest.work_counts
	nearest.erase("work_counts")
	work_counts["intersection_tests"] = target.edges.size()
	return {"valid": true, "source_id": segment.source_id, "origin_id": segment.origin_id,
		"max_inward_depth_m": cap, "cap_status": status,
		"max_inward_depth_lower_m": lower, "max_inward_depth_upper_m": upper,
		"max_sampled_inward_depth_m": state.maximum_sampled_depth_m,
		"geometric_bound_width_m": float(bounds.upper_m) - float(bounds.lower_m),
		"depth_bound_width_m": upper - lower, "numeric_epsilon_m": epsilon,
		"depth_bound_tolerance_m": tolerance, "depth_tolerance_met": upper - lower <= tolerance,
		"refine_depth_after_cap": refine_after_cap,
		"use_boundary_pruning": use_boundary_pruning, "work_counts": work_counts,
		"depth_evaluations": state.evaluations, "evaluation_budget": budget,
		"budget_exhausted": (status == &"unresolved" or (refine_after_cap and float(bounds.upper_m) - float(bounds.lower_m) > tolerance)) and int(state.evaluations) + 2 > budget,
		"unmeasured_interval_count": pending_intervals, "inside_interval_count": state.inside_interval_count,
		"depth_lower_bound_witness": witness,
		"contact": nearest,
		"depth_metric": &"maximum_inward_signed_distance_over_entire_segment_bounded",
		"actual_3d_grip_verified": false}


func _node(lo: float, hi: float, first: float, middle: float, last: float, length_m: float) -> Dictionary:
	var half_length := length_m * (hi - lo) * 0.5
	# Each half is below both unit-slope distance cones from its endpoints.
	var upper_left := maxf(maxf(first, middle), (first + middle + half_length) * 0.5)
	var upper_right := maxf(maxf(middle, last), (middle + last + half_length) * 0.5)
	return {"lo": lo, "hi": hi, "first_m": first, "middle_m": middle, "last_m": last,
		"upper_m": maxf(upper_left, upper_right)}


func _bounds(nodes: Array, state: Dictionary, pending: int, target: Dictionary) -> Dictionary:
	var lower: float = state.maximum_sampled_depth_m
	var upper := lower
	for node: Dictionary in nodes:
		upper = maxf(upper, node.upper_m)
	if pending > 0:
		upper = maxf(upper, target.diameter_upper_m)
	return {"lower_m": lower, "upper_m": upper}


func _cap_status(bounds: Dictionary, cap: float, epsilon: float) -> StringName:
	if float(bounds.lower_m) - epsilon > cap:
		return &"exceeds"
	if float(bounds.upper_m) + epsilon <= cap:
		return &"within"
	return &"unresolved"


func _sample(a: Vector2, b: Vector2, t: float, target: Dictionary, state: Dictionary) -> Dictionary:
	if state.cache.has(t):
		return state.cache[t]
	if int(state.evaluations) >= int(state.budget):
		return {}
	var x := float(a.x) + (float(b.x) - float(a.x)) * t
	var y := float(a.y) + (float(b.y) - float(a.y)) * t
	var nearest_squared := INF
	var inside := false
	var nearest_point := Vector2.ZERO
	var nearest_edge := -1
	for edge_index: int in target.edges.size():
		var edge: Array = target.edges[edge_index]
		var c: Vector2 = edge[0]
		var d: Vector2 = edge[1]
		var dx := float(d.x) - float(c.x)
		var dy := float(d.y) - float(c.y)
		var ratio := clampf(((x - float(c.x)) * dx + (y - float(c.y)) * dy) / (dx * dx + dy * dy), 0.0, 1.0)
		var gap_x := x - (float(c.x) + ratio * dx)
		var gap_y := y - (float(c.y) + ratio * dy)
		var squared := gap_x * gap_x + gap_y * gap_y
		if squared < nearest_squared:
			nearest_squared = squared
			nearest_point = Vector2(float(c.x) + ratio * dx, float(c.y) + ratio * dy)
			nearest_edge = edge_index
		if (float(c.y) > y) != (float(d.y) > y) and x < float(c.x) + dx * (y - float(c.y)) / dy:
			inside = not inside
	var depth := sqrt(nearest_squared) if inside else 0.0
	var result := {"inside": inside and nearest_squared > 0.0, "depth_m": depth}
	state.evaluations += 1
	if depth > float(state.maximum_sampled_depth_m):
		state.depth_witness = {"skin_point_m": Vector2(x, y), "skin_segment_t": t,
			"nearest_target_point_m": nearest_point, "target_edge_index": nearest_edge,
			"sampled_depth_m": depth, "origin_id": target.origin_id,
			"target_source_id": target.source_id, "witness_is_numeric_sample_not_exact_global_maximum": true}
	state.maximum_sampled_depth_m = maxf(state.maximum_sampled_depth_m, depth)
	state.cache[t] = result
	return result


func _nearest_contact(a: Vector2, b: Vector2, target: Dictionary, epsilon: float, intersections: Array[Dictionary], use_boundary_pruning: bool) -> Dictionary:
	var contact = Contact.new()
	var nearest := INF
	var result: Dictionary = {}
	var tied_edges: Array[int] = []
	var coordinate_scale := maxf(float(target.coordinate_scale_m), maxf(maxf(absf(a.x), absf(a.y)), maxf(absf(b.x), absf(b.y))))
	var contact_epsilon := maxf(epsilon, coordinate_scale * 0.0000002)
	var skin_bounds := _scalar_bounds(a, b)
	var work_counts := {"contact_intersection_reuses": 0, "contact_nearest_tests": 0,
		"contact_aabb_tests": 0, "contact_aabb_prunes": 0}
	for index: int in target.edges.size():
		var edge: Array = target.edges[index]
		if use_boundary_pruning and is_finite(nearest):
			work_counts.contact_aabb_tests += 1
			var lower_squared := _bounds_distance_squared(skin_bounds, target.edge_bounds[index])
			# Scalar-double box separation is a lower bound on true segment gap.
			# Expand by the float-Vector2 query's numeric guard AND tie epsilon:
			# edges capable of changing the closest point or its ties stay queried.
			var guarded_nearest := nearest + contact_epsilon + epsilon
			if lower_squared > guarded_nearest * guarded_nearest:
				work_counts.contact_aabb_prunes += 1
				continue
		var hit: Dictionary = intersections[index]
		work_counts.contact_intersection_reuses += 1
		work_counts.contact_nearest_tests += 1
		var pair: Dictionary = contact._nearest(a, b, edge[0], edge[1], hit)
		var distance := sqrt(float(pair.distance_squared))
		if distance < nearest - epsilon:
			nearest = distance
			tied_edges.clear()
			var tangent := ((edge[1] as Vector2) - (edge[0] as Vector2)).normalized()
			var point: Vector2 = pair.target_point_m
			result = {"distance_m": distance, "skin_point_m": pair.skin_point_m,
				"target_point_m": point, "target_edge_index": index,
				"target_edge_tangent": tangent, "skin_segment_tangent": (b - a).normalized(),
				"target_outward_normal": Vector2(tangent.y, -tangent.x) * float(target.winding_sign),
				"corner_ambiguous": point.distance_to(edge[0]) <= maxf(epsilon, Contact.EPS_M) or point.distance_to(edge[1]) <= maxf(epsilon, Contact.EPS_M)}
		if absf(distance - nearest) <= epsilon:
			tied_edges.append(index)
	result["tied_target_edge_indices"] = tied_edges
	result["tangent_ambiguous"] = bool(result.get("corner_ambiguous", false)) or tied_edges.size() != 1
	result["origin_id"] = target.origin_id
	result["target_source_id"] = target.source_id
	result["numeric_epsilon_m"] = contact_epsilon
	result["distance_is_numeric_estimate"] = true
	result["work_counts"] = work_counts
	return result


func _scalar_bounds(a: Vector2, b: Vector2) -> PackedFloat64Array:
	return PackedFloat64Array([minf(float(a.x), float(b.x)), minf(float(a.y), float(b.y)),
		maxf(float(a.x), float(b.x)), maxf(float(a.y), float(b.y))])


func _bounds_distance_squared(first: PackedFloat64Array, second: PackedFloat64Array) -> float:
	var gap_x := maxf(0.0, maxf(first[0] - second[2], second[0] - first[2]))
	var gap_y := maxf(0.0, maxf(first[1] - second[3], second[1] - first[3]))
	return gap_x * gap_x + gap_y * gap_y


func _distance(a: Vector2, b: Vector2) -> float:
	var dx := float(b.x) - float(a.x)
	var dy := float(b.y) - float(a.y)
	return sqrt(dx * dx + dy * dy)


func _parameter(point: Vector2, a: Vector2, b: Vector2) -> float:
	var dx := float(b.x) - float(a.x)
	var dy := float(b.y) - float(a.y)
	return ((float(point.x) - float(a.x)) * dx + (float(point.y) - float(a.y)) * dy) / (dx * dx + dy * dy)


func _fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"valid": false, "cap_status": &"unknown", "reason": reason, "details": details,
		"whole_skin_clearance_verified": false, "actual_3d_grip_verified": false}
