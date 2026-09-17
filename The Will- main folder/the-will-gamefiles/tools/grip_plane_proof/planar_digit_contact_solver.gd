extends RefCounted

## Diagnostic candidate search only. All Vector2 positions are meters in the
## supplied slice.origin_id; no actor, animation, or persistent state is written.
## Joint offsets add to relative zero_angles_rad. Initial chain direction is +X.
## Only complete slices with explicitly closed contours supply inside/outside tests;
## incomplete slice classification never publishes a certified safe result.
const NUMERICAL_DISTANCE_EPSILON_M := 0.0000001 # Float32 Vector2 distance noise, not a contact allowance.

func solve(hand: Dictionary, slice: Dictionary, config: Dictionary = {}) -> Dictionary:
	var started := Time.get_ticks_usec()
	# This cache lives only for this solve: geometry, anatomy and tolerances are
	# constant. Float keys retain the unquantized angle prefixes for sections 1/2.
	var query_cache := {"enabled": not bool(config.get("disable_section_query_cache", false)), "sections": [{}, {}], "hits": [0, 0, 0], "misses": [0, 0, 0]}
	var reason := _input_error(hand, slice)
	if reason != &"ok":
		return _finish_result({"valid": false, "status": reason, "evaluations": 0}, slice, started, query_cache)
	var reach := float(hand.lengths_m[0]) + float(hand.lengths_m[1]) + float(hand.lengths_m[2])
	var radius := maxf(float(hand.radii_m[0]), maxf(float(hand.radii_m[1]), float(hand.radii_m[2])))
	var nearest := INF
	for edge: Variant in slice.segments:
		nearest = minf(nearest, _point_segment_distance_squared(Vector2.ZERO, edge[0], edge[1]))
	if nearest > pow(reach + radius, 2.0):
		return _finish_result({"valid": true, "safe": false, "status": &"unreachable", "evaluations": 0, "origin_id": slice.origin_id}, slice, started, query_cache)
	var allowed: Array = config.get("allowed_penetration_m", [0.0005, 0.0004, 0.0003])
	if _inside_complete_contours(Vector2.ZERO, slice) or sqrt(nearest) < float(hand.radii_m[0]) - float(allowed[0]) - NUMERICAL_DISTANCE_EPSILON_M:
		return _finish_result({"valid": true, "safe": false, "status": &"blocked_fixed_origin", "evaluations": 0, "origin_id": slice.origin_id}, slice, started, query_cache)
	var search := {"evaluations": 0, "budget": clampi(int(config.get("max_pose_evaluations", 1700)), 1, 2000), "seeds": [], "best": {}, "any": {}, "query_cache": query_cache}
	# Seven samples per joint include both limits and their midpoint. Each pose
	# changes all joint offsets together; refinement uses the full 26-neighborhood.
	for a in range(7):
		for b in range(7):
			for c in range(7):
				var angles: Array = []
				for i in range(3):
					angles.append(lerpf(float(hand.min_angles_rad[i]), float(hand.max_angles_rad[i]), float([a, b, c][i]) / 6.0))
				_consider(hand, slice, angles, config, search, true)
	var seeds: Array = search.seeds.duplicate(true)
	for seed: Dictionary in seeds:
		var current: Dictionary = seed
		for level in range(6):
			var next: Dictionary = current
			for a in range(-1, 2):
				for b in range(-1, 2):
					for c in range(-1, 2):
						if a == 0 and b == 0 and c == 0:
							continue
						var angles: Array = []
						for i in range(3):
							var step := (float(hand.max_angles_rad[i]) - float(hand.min_angles_rad[i])) / (12.0 * pow(2.0, level))
							angles.append(clampf(float(current.angles_rad[i]) + step * float([a, b, c][i]), float(hand.min_angles_rad[i]), float(hand.max_angles_rad[i])))
						var candidate := _consider(hand, slice, angles, config, search, false)
						if not candidate.is_empty() and float(candidate.score) < float(next.score):
							next = candidate
			current = next
	var result: Dictionary = search.best if not search.best.is_empty() else search.any
	result = result.duplicate(true)
	result["valid"] = true
	result["origin_id"] = slice.origin_id
	result["evaluations"] = search.evaluations
	result["search_exhaustive"] = false
	result["status"] = &"no_safe_candidate_within_budget"
	if bool(result.get("safe", false)):
		result["status"] = &"partial_contact"
		if int(result.contact_count) == 0:
			result["status"] = &"safe_without_contact"
		elif int(result.contact_count) == 3:
			result["status"] = &"three_section_contact"
		elif int(result.contact_count) >= 2 and bool(result.sections[2].contact):
			result["status"] = &"tip_and_support_contact"
	return _finish_result(result, slice, started, query_cache)


func evaluate_pose(hand: Dictionary, slice: Dictionary, angles: Array, config: Dictionary = {}) -> Dictionary:
	return _describe_boundary_result(_evaluate_boundary_pose(hand, slice, angles, config), slice)


func _evaluate_boundary_pose(hand: Dictionary, slice: Dictionary, angles: Array, config: Dictionary = {}, query_cache: Dictionary = {}) -> Dictionary:
	var points: Array[Vector2] = [Vector2.ZERO]
	var direction := 0.0
	for i in range(3):
		direction += float(hand.zero_angles_rad[i]) + float(angles[i])
		points.append(points[-1] + Vector2(cos(direction), sin(direction)) * float(hand.lengths_m[i]))
	var allowed: Array = config.get("allowed_penetration_m", [0.0005, 0.0004, 0.0003])
	var tolerance := float(config.get("contact_tolerance_m", 0.00008))
	var sections: Array = []
	var safe := true
	var count := 0
	var score := 0.0
	for i in range(3):
		var section: Dictionary
		var prefix_cache: Dictionary = {}
		var cacheable := not query_cache.is_empty() and bool(query_cache.enabled) and i < 2
		if cacheable:
			prefix_cache = query_cache.sections[i]
			if i == 1:
				if not prefix_cache.has(float(angles[0])):
					prefix_cache[float(angles[0])] = {}
				prefix_cache = prefix_cache[float(angles[0])]
		if cacheable and prefix_cache.has(float(angles[i])):
			section = prefix_cache[float(angles[i])]
			query_cache.hits[i] += 1
		else:
			section = _measure_boundary_section(points[i], points[i + 1], float(hand.radii_m[i]), slice, float(allowed[i]), tolerance)
			if not query_cache.is_empty():
				query_cache.misses[i] += 1
			if cacheable:
				prefix_cache[float(angles[i])] = section
		sections.append(section)
		safe = safe and bool(section.safe)
		count += int(bool(section.contact))
		var desired_gap_error := absf(float(section.gap_m) + float(allowed[i]))
		score += desired_gap_error * (2.0 if i == 2 else 1.0) + float(section.excess_penetration_m) * 1000.0
		# Closure direction is only a deterministic tie preference, never a limit override.
		score -= float(angles[i]) * float(hand.closure_signs[i]) * 0.000000001
	return {"angles_rad": angles.duplicate(), "points_m": points, "sections": sections, "safe": safe, "contact_count": count, "score": score}


func _consider(hand: Dictionary, slice: Dictionary, angles: Array, config: Dictionary, search: Dictionary, keep_seed: bool) -> Dictionary:
	if int(search.evaluations) >= int(search.budget):
		return {}
	var candidate := _evaluate_boundary_pose(hand, slice, angles, config, search.query_cache)
	search.evaluations += 1
	if search.any.is_empty() or float(candidate.score) < float(search.any.score):
		search.any = candidate
	if bool(candidate.safe):
		var best: Dictionary = search.best
		if best.is_empty() or int(candidate.contact_count) > int(best.contact_count) or (int(candidate.contact_count) == int(best.contact_count) and float(candidate.score) < float(best.score)):
			search.best = candidate
	if keep_seed:
		search.seeds.append(candidate)
		search.seeds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) < float(b.score))
		if search.seeds.size() > 8:
			search.seeds.pop_back()
	return candidate


func measure_section(a: Vector2, b: Vector2, radius: float, slice: Dictionary, allowed: float, tolerance: float) -> Dictionary:
	return _describe_boundary_result(_measure_boundary_section(a, b, radius, slice, allowed, tolerance), slice)


func _measure_boundary_section(a: Vector2, b: Vector2, radius: float, slice: Dictionary, allowed: float, tolerance: float) -> Dictionary:
	var nearest := INF
	for edge: Variant in slice.segments:
		nearest = minf(nearest, _segment_distance_squared(a, b, edge[0], edge[1]))
	var distance := sqrt(nearest)
	var inside := _inside_complete_contours(a, slice) or _inside_complete_contours(b, slice) or _inside_complete_contours((a + b) * 0.5, slice)
	var gap := -distance - radius if inside else distance - radius
	var excess := maxf(-gap - allowed, 0.0)
	var safe := not inside and excess <= NUMERICAL_DISTANCE_EPSILON_M
	return {"gap_m": gap, "penetration_m": maxf(-gap, 0.0), "excess_penetration_m": excess, "inside": inside, "safe": safe, "contact": safe and gap <= tolerance}


func _finish_result(result: Dictionary, slice: Dictionary, started: int, query_cache: Dictionary) -> Dictionary:
	result = _describe_boundary_result(result, slice)
	result["search_exhaustive"] = false
	result["section_query_cache"] = {
		"enabled": query_cache.enabled,
		"hits": int(query_cache.hits[0]) + int(query_cache.hits[1]) + int(query_cache.hits[2]),
		"misses": int(query_cache.misses[0]) + int(query_cache.misses[1]) + int(query_cache.misses[2]),
		"hits_by_section": query_cache.hits.duplicate(),
		"misses_by_section": query_cache.misses.duplicate(),
	}
	result["timing_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	return result


func _describe_boundary_result(result: Dictionary, slice: Dictionary) -> Dictionary:
	# Internal ranking still uses the identical boundary measurements. Public
	# results distinguish them from an established complete contact classification.
	var incomplete: bool = bool(slice.get("classification_incomplete", true))
	result["classification_incomplete"] = incomplete
	result["2d_boundary_clearance"] = bool(result.get("safe", false))
	result["requires_3d_validation"] = true
	result["contact_count_is_provisional"] = incomplete
	for section: Dictionary in result.get("sections", []):
		section["classification_incomplete"] = incomplete
		section["2d_boundary_clearance"] = bool(section.get("safe", false))
		section["requires_3d_validation"] = true
		if incomplete:
			section["safe"] = false
	if incomplete:
		result["safe"] = false
		# Preserve rejection reasons when no candidate/search result exists.
		if bool(result.get("valid", true)) and result.has("angles_rad"):
			result["boundary_status"] = result.get("status", &"boundary_measurement")
			result["status"] = &"provisional_boundary_candidate" if bool(result["2d_boundary_clearance"]) else &"no_boundary_clear_candidate_within_budget"
	return result


func _inside_complete_contours(point: Vector2, slice: Dictionary) -> bool:
	# A retained loop may be a hole whose enclosing outer loop was cropped away.
	# Its parity is unknown; only distance to the real retained boundary is usable.
	if bool(slice.get("classification_incomplete", true)):
		return false
	var inside := false
	for contour: Variant in slice.get("contours", []):
		# Never close an open cropped intersection with an invented straight cap.
		if contour.size() < 4 or not (contour[0] as Vector2).is_equal_approx(contour[-1]):
			continue
		for i in range(contour.size() - 1):
			var a: Vector2 = contour[i]
			var b: Vector2 = contour[i + 1]
			if (a.y > point.y) != (b.y > point.y):
				if point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x:
					inside = not inside
	return inside


func _point_segment_distance_squared(p: Vector2, a: Vector2, b: Vector2) -> float:
	var delta := b - a
	var weight := clampf((p - a).dot(delta) / maxf(delta.length_squared(), 0.000000000000000001), 0.0, 1.0)
	return p.distance_squared_to(a + delta * weight)


func _segment_distance_squared(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	var ab := b - a
	var cd := d - c
	var determinant := ab.cross(cd)
	if absf(determinant) > 0.000000000000001:
		var t := (c - a).cross(cd) / determinant
		var u := (c - a).cross(ab) / determinant
		if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0:
			return 0.0
	return minf(minf(_point_segment_distance_squared(a, c, d), _point_segment_distance_squared(b, c, d)), minf(_point_segment_distance_squared(c, a, b), _point_segment_distance_squared(d, a, b)))


func _input_error(hand: Dictionary, slice: Dictionary) -> StringName:
	for key: String in ["lengths_m", "radii_m", "zero_angles_rad", "min_angles_rad", "max_angles_rad", "closure_signs"]:
		if not hand.get(key, []) is Array or hand.get(key, []).size() != 3:
			return &"invalid_hand_array"
		for value: Variant in hand[key]:
			if not (value is int or value is float) or not is_finite(float(value)):
				return &"nonfinite_hand_measurement"
	for i in range(3):
		if float(hand.lengths_m[i]) <= 0.0 or float(hand.radii_m[i]) <= 0.0 or float(hand.min_angles_rad[i]) > float(hand.max_angles_rad[i]):
			return &"invalid_hand_limits"
	if StringName(slice.get("origin_id", StringName())) == StringName() or slice.get("segments", []).is_empty():
		return &"missing_slice_origin_or_segments"
	for edge: Variant in slice.segments:
		if edge.size() != 2 or not edge[0] is Vector2 or not edge[1] is Vector2 or not edge[0].is_finite() or not edge[1].is_finite():
			return &"invalid_slice_segment"
	return &"ok"
