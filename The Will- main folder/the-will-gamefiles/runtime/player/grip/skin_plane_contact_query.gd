extends RefCounted

## Exact line-segment queries in one named orthonormal plane, in meters.
## A complete planar classification is conditional on the supplied full slices
## being the complete boundaries of solids. It never certifies a 3D grip.
const EPS_M := 0.000001
const EPS_SQUARED := EPS_M * EPS_M


func prepare_target(segments: Array, origin_id: StringName) -> Dictionary:
	if origin_id == &"":
		return {"valid": false, "reason": "missing_plane_origin"}
	var packet := _prepare(segments)
	packet["origin_id"] = origin_id
	return packet


func evaluate(skin_segments: Array, target: Dictionary, origin_id: StringName, config: Dictionary = {}) -> Dictionary:
	var answer := {"valid": false, "origin_id": origin_id, "scope": "planar_full_boundary_query_not_3d_grip_validation"}
	if origin_id == &"" or target.get("origin_id", &"") != origin_id or not bool(target.get("valid", false)):
		answer["reason"] = "invalid_target_or_mismatched_plane_origin"
		return answer
	var reach: float = float(config.get("reach_m", INF))
	if is_nan(reach) or reach <= 0.0:
		answer["reason"] = "invalid_reach"
		return answer
	var skip_skin_solid: bool = bool(config.get("skip_skin_solid_classification", false))
	var skin := _prepare(skin_segments, skip_skin_solid)
	if not bool(skin.get("valid", false)):
		answer["reason"] = skin.get("reason", "invalid_skin")
		return answer
	var target_complete: bool = bool(target["topology_complete"]) and not bool(target.get("classification_incomplete", false))
	var skin_complete: bool = bool(skin["topology_complete"]) and not bool(config.get("skin_classification_incomplete", false))
	var complete: bool = target_complete and skin_complete
	var target_edges := _bounded_edges(target["segments"], reach)
	var skin_edges := _bounded_edges(skin["segments"], reach)
	var moving := _empty_measure()
	var fixed := _empty_measure()
	var by_bone: Dictionary = {}
	var regions: Array[Dictionary] = [_empty_measure(), _empty_measure(), _empty_measure()]
	for index: int in regions.size():
		regions[index]["region_index"] = index
		regions[index]["bone_id"] = &""
	var target_inside_count := 0
	var target_inside_depth := 0.0
	var query_center_inside_both := false
	var coincident := false
	var skin_cuts: Array = []
	var target_cuts: Array = []
	for _edge: Dictionary in skin_edges:
		skin_cuts.append([0.0, 1.0])
	for _edge: Dictionary in target_edges:
		target_cuts.append([0.0, 1.0])
	for i: int in skin_edges.size():
		var edge: Dictionary = skin_edges[i]
		var measure: Dictionary = moving if bool(edge["dynamic"]) else fixed
		measure["edges_in_reach"] += 1
		var bones := _affected_bones(edge) if bool(edge["dynamic"]) else []
		var regional: Array[Dictionary] = []
		for bone: StringName in bones:
			if not by_bone.has(bone):
				by_bone[bone] = _empty_measure()
			regional.append(by_bone[bone])
		var region: int = _ranking_region(edge) if bool(edge["dynamic"]) else -1
		if region >= 0:
			regions[region]["bone_id"] = StringName(edge["bone_ids"][region])
			regional.append(regions[region])
		for section: Dictionary in regional:
			section["edges_in_reach"] += 1
		for j: int in target_edges.size():
			var other: Dictionary = target_edges[j]
			var lower_bound: float = _bounds_distance_squared(edge, other)
			# A bone may need a farther nearest edge than the whole digit does.
			var threshold: float = float(measure["gap_squared_m"])
			for section: Dictionary in regional:
				threshold = maxf(threshold, float(section["gap_squared_m"]))
			if lower_bound > threshold and lower_bound > EPS_SQUARED:
				continue
			var hit := _intersection(edge["a"], edge["b"], other["a"], other["b"])
			var nearest := _nearest(edge["a"], edge["b"], other["a"], other["b"], hit)
			_record_nearest(measure, nearest)
			for section: Dictionary in regional:
				_record_nearest(section, nearest)
			if not hit.is_empty():
				measure["boundary_intersections"] += 1
				measure["proper_crossings"] += int(bool(hit["proper"]))
				for section: Dictionary in regional:
					section["boundary_intersections"] += 1
					section["proper_crossings"] += int(bool(hit["proper"]))
				coincident = coincident or bool(hit["coincident"])
				(skin_cuts[i] as Array).append(float(hit["t"]))
				(target_cuts[j] as Array).append(float(hit["u"]))
		if target_complete:
			var buried := _buried_intervals(edge, skin_cuts[i], target["segments"])
			measure["inside_interval_samples"] += int(buried["count"])
			measure["sampled_inside_depth_m"] = maxf(float(measure["sampled_inside_depth_m"]), float(buried["depth"]))
			for section: Dictionary in regional:
				section["inside_interval_samples"] += int(buried["count"])
				section["sampled_inside_depth_m"] = maxf(float(section["sampled_inside_depth_m"]), float(buried["depth"]))
	if skin_complete:
		for i: int in target_edges.size():
			var buried := _buried_intervals(target_edges[i], target_cuts[i], skin["segments"])
			target_inside_count += int(buried["count"])
			target_inside_depth = maxf(target_inside_depth, float(buried["depth"]))
		# Full boundaries may both surround the complete disk without contributing
		# one local edge. Their full-soup parity must still detect that overlap.
		query_center_inside_both = target_complete and bool(_point_relation(Vector2.ZERO, skin["segments"])["inside"]) and bool(_point_relation(Vector2.ZERO, target["segments"])["inside"])
	# Coincident boundaries require solid-side reasoning. Do not turn them into
	# certified clearance, or pretend a sampled depth is an exact penetration.
	complete = complete and not coincident
	for measure: Dictionary in [moving, fixed]:
		measure["gap_m"] = sqrt(float(measure["gap_squared_m"]))
	for measure: Dictionary in by_bone.values():
		measure["gap_m"] = sqrt(float(measure["gap_squared_m"]))
	for measure: Dictionary in regions:
		measure["gap_m"] = sqrt(float(measure["gap_squared_m"]))
	var overlaps: bool = query_center_inside_both or int(moving["proper_crossings"]) + int(fixed["proper_crossings"]) + int(moving["inside_interval_samples"]) + int(fixed["inside_interval_samples"]) + target_inside_count > 0
	answer.merge({"valid": true, "planar_classification_complete": complete,
		"planar_overlap_detected": overlaps, "planar_clearance_verified": complete and not overlaps,
		"dynamic": moving, "fixed_static": fixed, "by_bone": by_bone,
		"ranking_regions": regions, "ranking_region_definition": "greatest_average_selected_bone_weight_not_anatomy_partition_or_verified_grip_contacts",
		"skin_inside_target_classification_complete": target_complete,
		"target_inside_skin_classification_complete": skin_complete,
		"skin_solid_classification_skipped": skip_skin_solid,
		"target_inside_skin_interval_samples": target_inside_count,
		"target_inside_skin_sampled_depth_m": target_inside_depth,
		"query_center_inside_both": query_center_inside_both,
		"coincident_boundaries_unclassified": coincident,
		"skin_topology": skin["topology"], "target_topology": target["topology"],
		"depth_metric": "maximum_sampled_inside_boundary_distance_lower_bound_not_penetration_solution",
		"reach_m": reach}, true)
	return answer


func _prepare(raw: Array, skip_topology: bool = false) -> Dictionary:
	if raw.is_empty():
		return {"valid": false, "reason": "empty_boundary"}
	var edges: Array[Dictionary] = []
	var points: Array[Vector2] = []
	var representative_by_endpoint: Dictionary = {}
	var degree: Array[int] = []
	var topology := {"open_or_branched_vertices": 0, "duplicate_edges": 0, "self_intersections": 0, "coplanar_edges": 0, "sub_epsilon_edges": 0, "noncoincident_endpoint_welds": 0, "self_intersection_pairs": [], "skipped": skip_topology}
	var keys: Dictionary = {}
	for item: Variant in raw:
		var edge: Dictionary = item.duplicate() if item is Dictionary else {}
		if (item is Array or item is PackedVector2Array) and item.size() == 2:
			edge = {"a": item[0], "b": item[1]}
		if not edge.get("a") is Vector2 or not edge.get("b") is Vector2 or not (edge["a"] as Vector2).is_finite() or not (edge["b"] as Vector2).is_finite():
			return {"valid": false, "reason": "invalid_or_nonfinite_edge"}
		var length_squared: float = (edge["a"] as Vector2).distance_squared_to(edge["b"])
		if length_squared == 0.0:
			return {"valid": false, "reason": "zero_length_edge", "edge_index": edges.size(), "length_m": 0.0}
		topology["sub_epsilon_edges"] += int(length_squared <= EPS_SQUARED)
		edge["dynamic"] = bool(edge.get("dynamic", true))
		edge["minimum"] = (edge["a"] as Vector2).min(edge["b"])
		edge["maximum"] = (edge["a"] as Vector2).max(edge["b"])
		if skip_topology:
			edges.append(edge)
			continue
		var ids: Array[int] = []
		for point: Vector2 in [edge["a"], edge["b"]]:
			# Memoize only identical finite input points after their original full
			# scan. Representatives only append, so no later ID can precede this
			# first matching ID. No bucket quantization or tolerance change.
			var id: int = int(representative_by_endpoint.get(point, -1))
			if id < 0:
				for candidate: int in points.size():
					if points[candidate].distance_squared_to(point) <= EPS_SQUARED:
						id = candidate
						break
			if id < 0:
				id = points.size()
				points.append(point)
				degree.append(0)
			representative_by_endpoint[point] = id
			# Every occurrence still contributes to the same diagnostic, including
			# repeated noncoincident inputs already present in the memo.
			topology["noncoincident_endpoint_welds"] += int(points[id] != point)
			degree[id] += 1
			ids.append(id)
		edge["vertex_ids"] = ids
		var key := Vector2i(mini(ids[0], ids[1]), maxi(ids[0], ids[1]))
		topology["duplicate_edges"] += int(keys.has(key))
		keys[key] = true
		topology["coplanar_edges"] += int(bool(edge.get("coplanar", false)))
		edges.append(edge)
	if skip_topology:
		return {"valid": true, "segments": edges, "topology_complete": false, "topology": topology}
	for count: int in degree:
		topology["open_or_branched_vertices"] += int(count != 2)
	var topology_index := _topology_index(edges)
	for i: int in edges.size():
		for j: int in _topology_candidates(edges, topology_index, i):
			if _bounds_distance_squared(edges[i], edges[j]) > EPS_SQUARED:
				continue
			var hit := _intersection(edges[i]["a"], edges[i]["b"], edges[j]["a"], edges[j]["b"])
			if hit.is_empty():
				continue
			var adjacent: bool = (edges[i]["vertex_ids"] as Array).has(edges[j]["vertex_ids"][0]) or (edges[i]["vertex_ids"] as Array).has(edges[j]["vertex_ids"][1])
			if not adjacent or bool(hit["proper"]) or bool(hit["coincident"]):
				topology["self_intersections"] += 1
				if (topology["self_intersection_pairs"] as Array).size() < 12:
					topology["self_intersection_pairs"].append({"edges": [i, j], "a": edges[i]["a"], "b": edges[i]["b"], "c": edges[j]["a"], "d": edges[j]["b"], "adjacent": adjacent, "intersection": hit})
	var complete := true
	for key: String in ["open_or_branched_vertices", "duplicate_edges", "self_intersections", "coplanar_edges", "sub_epsilon_edges", "noncoincident_endpoint_welds"]:
		complete = complete and int(topology[key]) == 0
	complete = complete and not skip_topology
	return {"valid": true, "segments": edges, "topology_complete": complete, "topology": topology}


func _topology_index(edges: Array[Dictionary]) -> Dictionary:
	# Broad phase only: retain the original edge order, welding, narrow-phase
	# predicate and epsilon. Small boundaries avoid the index setup overhead.
	return _topology_range(edges, 0, edges.size()) if edges.size() >= 64 else {}


func _topology_range(edges: Array[Dictionary], first: int, last: int) -> Dictionary:
	var node := {"first": first, "last": last}
	if last - first <= 8:
		var minimum: Vector2 = edges[first]["minimum"]
		var maximum: Vector2 = edges[first]["maximum"]
		for index: int in range(first + 1, last):
			minimum = minimum.min(edges[index]["minimum"])
			maximum = maximum.max(edges[index]["maximum"])
		node["minimum"] = minimum
		node["maximum"] = maximum
	else:
		var middle: int = (first + last) >> 1
		var left := _topology_range(edges, first, middle)
		var right := _topology_range(edges, middle, last)
		node["left"] = left
		node["right"] = right
		node["minimum"] = (left["minimum"] as Vector2).min(right["minimum"])
		node["maximum"] = (left["maximum"] as Vector2).max(right["maximum"])
	return node


func _topology_candidates(edges: Array[Dictionary], index: Dictionary, first_edge: int) -> Array[int]:
	var candidates: Array[int] = []
	if index.is_empty():
		for second: int in range(first_edge + 1, edges.size()): candidates.append(second)
	else:
		_append_topology_candidates(edges[first_edge], index, first_edge, candidates)
	return candidates


func _append_topology_candidates(edge: Dictionary, node: Dictionary, first_edge: int,
		candidates: Array[int]) -> void:
	if int(node["last"]) <= first_edge + 1 or _bounds_distance_squared(edge, node) > EPS_SQUARED:
		return
	if node.has("left"):
		# Contiguous ranges, left first: same lexicographic [i,j] order as the old
		# all-pairs loop, including its first twelve diagnostic intersections.
		_append_topology_candidates(edge, node["left"], first_edge, candidates)
		_append_topology_candidates(edge, node["right"], first_edge, candidates)
	else:
		for second: int in range(maxi(first_edge + 1, int(node["first"])), int(node["last"])):
			candidates.append(second)


func _bounded_edges(edges: Array, reach: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for original: Dictionary in edges:
		var edge: Dictionary = original.duplicate()
		if is_finite(reach):
			var a: Vector2 = edge["a"]
			var delta: Vector2 = edge["b"] - a
			var squared := delta.length_squared()
			var projection := a.dot(delta)
			var discriminant := projection * projection - squared * (a.length_squared() - reach * reach)
			if discriminant < 0.0:
				continue
			var lo := maxf(0.0, (-projection - sqrt(discriminant)) / squared)
			var hi := minf(1.0, (-projection + sqrt(discriminant)) / squared)
			if hi <= lo:
				continue
			if edge.has("a_selected_weights") and edge.has("b_selected_weights"):
				var first_weights: Vector3 = edge["a_selected_weights"]
				var last_weights: Vector3 = edge["b_selected_weights"]
				edge["a_selected_weights"] = first_weights.lerp(last_weights, lo)
				edge["b_selected_weights"] = first_weights.lerp(last_weights, hi)
			edge["a"] = a + delta * lo
			edge["b"] = a + delta * hi
			edge["minimum"] = (edge["a"] as Vector2).min(edge["b"])
			edge["maximum"] = (edge["a"] as Vector2).max(edge["b"])
		result.append(edge)
	return result


func _bounds_distance_squared(a: Dictionary, b: Dictionary) -> float:
	var gap: Vector2 = (a["minimum"] as Vector2) - (b["maximum"] as Vector2)
	gap = gap.max((b["minimum"] as Vector2) - (a["maximum"] as Vector2)).max(Vector2.ZERO)
	return gap.length_squared()


func _intersection(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Dictionary:
	var r := b - a
	var s := d - c
	# Vector2 arithmetic uses project real_t precision. Scalar float arithmetic
	# keeps cancellation near a shared triangle endpoint from inventing a cross.
	var rx: float = float(b.x) - float(a.x)
	var ry: float = float(b.y) - float(a.y)
	var sx: float = float(d.x) - float(c.x)
	var sy: float = float(d.y) - float(c.y)
	var qx: float = float(c.x) - float(a.x)
	var qy: float = float(c.y) - float(a.y)
	var cross: float = rx * sy - ry * sx
	if cross != 0.0:
		# Same ordered endpoint tests; avoid five temporary arrays per query.
		if a == c:
			return {"t": 0.0, "u": 0.0, "point": a, "proper": false, "coincident": false}
		if a == d:
			return {"t": 0.0, "u": 1.0, "point": a, "proper": false, "coincident": false}
		if b == c:
			return {"t": 1.0, "u": 0.0, "point": b, "proper": false, "coincident": false}
		if b == d:
			return {"t": 1.0, "u": 1.0, "point": b, "proper": false, "coincident": false}
		var t := (qx * sy - qy * sx) / cross
		var u := (qx * ry - qy * rx) / cross
		if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0:
			return {"t": t, "u": u, "point": a + r * t, "proper": t > 0.0 and t < 1.0 and u > 0.0 and u < 1.0, "coincident": false}
	elif qx * ry - qy * rx == 0.0:
		var first := (qx * rx + qy * ry) / (rx * rx + ry * ry)
		var last := ((float(d.x) - float(a.x)) * rx + (float(d.y) - float(a.y)) * ry) / (rx * rx + ry * ry)
		var lo := maxf(0.0, minf(first, last))
		var hi := minf(1.0, maxf(first, last))
		if hi >= lo:
			var point := a + r * lo
			return {"t": lo, "u": (point - c).dot(s) / s.length_squared(), "point": point, "proper": false, "coincident": hi > lo}
	return {}


func _nearest(a: Vector2, b: Vector2, c: Vector2, d: Vector2, hit: Dictionary) -> Dictionary:
	if not hit.is_empty():
		return {"distance_squared": 0.0, "skin_point_m": hit["point"], "target_point_m": hit["point"]}
	# Keep the exact projections, distance arithmetic and strict first-win order.
	# Only the selected pair needs a Dictionary; the four candidates need no arrays.
	var nearest := INF
	var skin_point := Vector2.ZERO
	var target_point := Vector2.ZERO
	var projected := _project(a, c, d)
	var squared: float = a.distance_squared_to(projected)
	if squared < nearest:
		nearest = squared; skin_point = a; target_point = projected
	projected = _project(b, c, d)
	squared = b.distance_squared_to(projected)
	if squared < nearest:
		nearest = squared; skin_point = b; target_point = projected
	projected = _project(c, a, b)
	squared = projected.distance_squared_to(c)
	if squared < nearest:
		nearest = squared; skin_point = projected; target_point = c
	projected = _project(d, a, b)
	squared = projected.distance_squared_to(d)
	if squared < nearest:
		nearest = squared; skin_point = projected; target_point = d
	# Preserve the original no-finite-candidate packet for malformed direct calls.
	if nearest == INF: return {"distance_squared": INF}
	return {"distance_squared": nearest, "skin_point_m": skin_point, "target_point_m": target_point}


func _project(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	# Attraction may query a single skin point through the same nearest-feature
	# owner. Validated physical segment queries still reject zero-length edges.
	if a == b: return a
	var delta := b - a
	return a + delta * clampf((point - a).dot(delta) / delta.length_squared(), 0.0, 1.0)


func _buried_intervals(edge: Dictionary, cuts: Array, boundary: Array) -> Dictionary:
	cuts.sort()
	var result := {"count": 0, "depth": 0.0}
	for index: int in range(cuts.size() - 1):
		if float(cuts[index + 1]) <= float(cuts[index]):
			continue
		var point: Vector2 = (edge["a"] as Vector2).lerp(edge["b"], (float(cuts[index]) + float(cuts[index + 1])) * 0.5)
		var relation := _point_relation(point, boundary)
		if bool(relation["inside"]):
			result["count"] += 1
			result["depth"] = maxf(float(result["depth"]), sqrt(float(relation["distance_squared"])))
	return result


func _point_relation(point: Vector2, boundary: Array) -> Dictionary:
	var inside := false
	var nearest := INF
	for segment: Dictionary in boundary:
		var a: Vector2 = segment["a"]
		var b: Vector2 = segment["b"]
		nearest = minf(nearest, point.distance_squared_to(_project(point, a, b)))
		if (a.y > point.y) != (b.y > point.y) and point.x < a.x + (b.x - a.x) * (point.y - a.y) / (b.y - a.y):
			inside = not inside
	return {"inside": inside and nearest > 0.0, "distance_squared": nearest}


func _empty_measure() -> Dictionary:
	return {"gap_m": INF, "gap_squared_m": INF, "skin_point_m": null, "target_point_m": null, "boundary_intersections": 0, "proper_crossings": 0, "inside_interval_samples": 0, "sampled_inside_depth_m": 0.0, "edges_in_reach": 0}


func _record_nearest(measure: Dictionary, nearest: Dictionary) -> void:
	if float(nearest["distance_squared"]) < float(measure["gap_squared_m"]):
		measure["gap_squared_m"] = nearest["distance_squared"]
		measure["skin_point_m"] = nearest["skin_point_m"]
		measure["target_point_m"] = nearest["target_point_m"]


func _affected_bones(edge: Dictionary) -> Array:
	var result: Array = []
	var bones: Array = edge.get("bone_ids", [])
	if bones.is_empty() and edge.has("bone_id"):
		bones = [edge["bone_id"]]
	for index: int in bones.size():
		if index < 3 and edge.has("a_selected_weights") and edge.has("b_selected_weights"):
			if maxf(float(edge["a_selected_weights"][index]), float(edge["b_selected_weights"][index])) <= 0.0:
				continue
		result.append(StringName(bones[index]))
	return result


func _ranking_region(edge: Dictionary) -> int:
	if not edge.has("a_selected_weights") or not edge.has("b_selected_weights") or (edge.get("bone_ids", []) as Array).size() != 3:
		return -1
	var weights: Vector3 = (edge["a_selected_weights"] as Vector3) + (edge["b_selected_weights"] as Vector3)
	var index := weights.max_axis_index()
	return index if weights[index] > 0.0 else -1
