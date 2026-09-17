extends RefCounted

## Bounded diagnostic search over the three authored angles. The callback poses
## actual prepared skin and measures it against the fixed object slice. No pose
## is written. Ranking regions are weight-based heuristics, not anatomy proofs.
func solve(snapshot: Dictionary, origin_id: StringName, evaluate_pose: Callable, config: Dictionary = {}) -> Dictionary:
	if origin_id == &"" or not evaluate_pose.is_valid():
		return {"valid": false, "status": "missing_origin_or_evaluator"}
	for field: String in ["min_angles_rad", "max_angles_rad", "preferred_angles_rad"]:
		if not snapshot.get(field) is Array or snapshot[field].size() != 3:
			return {"valid": false, "status": "missing_three_joint_limits"}
	for index: int in range(3):
		if not is_finite(float(snapshot.min_angles_rad[index])) or not is_finite(float(snapshot.max_angles_rad[index])) or float(snapshot.min_angles_rad[index]) > float(snapshot.max_angles_rad[index]):
			return {"valid": false, "status": "invalid_joint_limits"}
		if not is_finite(float(snapshot.preferred_angles_rad[index])) or float(snapshot.preferred_angles_rad[index]) < float(snapshot.min_angles_rad[index]) or float(snapshot.preferred_angles_rad[index]) > float(snapshot.max_angles_rad[index]):
			return {"valid": false, "status": "invalid_preferred_joint_angles"}
	var started := Time.get_ticks_usec()
	var state := {"cache": {}, "evaluations": 0, "invalid_evaluations": 0, "budget": clampi(int(config.get("max_pose_evaluations", 240)), 1, 1000),
		"cache_hits": 0, "best": {}, "seeds": [], "failures": {}, "candidate_ms": 0.0,
		"contact_tolerance_m": float(config.get("contact_tolerance_m", 0.00008))}
	# Tendon-like seeds actuate all three joints together, followed by a small
	# full-range grid so a prescribed ratio cannot exclude a useful combination.
	for step: int in range(9):
		var angles: Array[float] = []
		for index: int in range(3):
			var start := clampf(0.0, float(snapshot.min_angles_rad[index]), float(snapshot.max_angles_rad[index]))
			angles.append(clampf(lerpf(start, float(snapshot.preferred_angles_rad[index]), float(step) / 8.0), float(snapshot.min_angles_rad[index]), float(snapshot.max_angles_rad[index])))
		_consider(angles, evaluate_pose, state, true)
	for a: int in range(3):
		for b: int in range(3):
			for c: int in range(3):
				var angles: Array[float] = []
				for index: int in range(3):
					# Even endpoint interpolation can round just beyond an authored
					# bound. Keep evaluator inputs inside the exact declared limits.
					angles.append(clampf(lerpf(float(snapshot.min_angles_rad[index]), float(snapshot.max_angles_rad[index]), float([a,b,c][index]) / 2.0), float(snapshot.min_angles_rad[index]), float(snapshot.max_angles_rad[index])))
				_consider(angles, evaluate_pose, state, true)
	var seeds: Array = state.seeds.duplicate()
	for seed: Dictionary in seeds:
		var current := seed
		for level: int in range(7):
			if state.evaluations >= state.budget:
				break
			var next := current
			# Test each signed coordinate and both coordinated closure directions;
			# choose only after evaluating the neighborhood, with fixed ordering.
			for direction: Vector3 in [Vector3(1,1,1),Vector3(-1,-1,-1),Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,1,0),Vector3(0,-1,0),Vector3(0,0,1),Vector3(0,0,-1)]:
				var angles: Array[float] = []
				for index: int in range(3):
					var amount := (float(snapshot.max_angles_rad[index]) - float(snapshot.min_angles_rad[index])) / (8.0 * pow(2.0, level))
					angles.append(clampf(float(current.angles_rad[index]) + direction[index] * amount, float(snapshot.min_angles_rad[index]), float(snapshot.max_angles_rad[index])))
				var candidate := _consider(angles, evaluate_pose, state, false)
				if not candidate.is_empty() and _better(candidate, next):
					next = candidate
			current = next
	var result: Dictionary = state.best.duplicate(true)
	var has_result := not result.is_empty()
	result["valid"] = has_result
	result["status"] = "no_usable_pose_evaluation" if not has_result else "no_clear_candidate_within_budget"
	if bool(result.get("boundary_candidate_clear", false)):
		result["status"] = "provisional_clear_contact_candidate" if int(result.get("ranking_region_contact_count", 0)) > 0 else "provisional_clear_pose_without_contact"
	result.merge({"origin_id": origin_id, "evaluations": state.evaluations, "invalid_evaluations": state.invalid_evaluations,
		"invalid_reasons": state.failures, "cache_hits": state.cache_hits, "budget": state.budget,
		"search_exhaustive": false, "actual_3d_grip_verified": false, "production_pose_written": false,
		"contact_tolerance_m": state.contact_tolerance_m, "candidate_evaluation_ms": state.candidate_ms,
		"elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0}, true)
	return result

func _consider(angles: Array[float], callback: Callable, state: Dictionary, keep_seed: bool) -> Dictionary:
	# Exact floating-point tuple: no angle quantization changes the search result.
	var key := var_to_bytes(angles).hex_encode()
	if state.cache.has(key):
		state.cache_hits += 1
		return state.cache[key]
	if state.evaluations >= state.budget:
		return {}
	var started := Time.get_ticks_usec()
	var value: Dictionary = callback.call(angles)
	state.candidate_ms += float(Time.get_ticks_usec() - started) / 1000.0
	state.evaluations += 1
	var contact: Dictionary = value.get("contact", {})
	if not bool(value.get("valid", false)) or not bool(contact.get("valid", false)):
		state.invalid_evaluations += 1
		var reason := String(contact.get("reason", value.get("reason", "invalid_evaluation")))
		state.failures[reason] = int(state.failures.get(reason, 0)) + 1
		state.cache[key] = {}
		return {}
	var moving: Dictionary = contact.get("dynamic", {})
	var fixed: Dictionary = contact.get("fixed_static", {})
	var crossings := int(moving.get("proper_crossings", 0)) + int(fixed.get("proper_crossings", 0))
	var depth := maxf(float(moving.get("sampled_inside_depth_m", 0.0)), float(fixed.get("sampled_inside_depth_m", 0.0)))
	var has_inside := int(moving.get("inside_interval_samples", 0)) + int(fixed.get("inside_interval_samples", 0)) > 0
	var has_reported_overlap := bool(contact.get("planar_overlap_detected", false)) or int(contact.get("target_inside_skin_interval_samples", 0)) > 0
	var boundary_clear := crossings == 0 and not has_inside and not has_reported_overlap and not bool(contact.get("coincident_boundaries_unclassified", false))
	var score := 100.0 * depth + float(crossings) * 0.01
	var count := 0
	for region: Dictionary in contact.get("ranking_regions", []):
		var gap := float(region.get("gap_m", INF))
		score += (gap if is_finite(gap) else 1.0) * (2.0 if int(region.get("region_index", -1)) == 2 else 1.0)
		count += int(is_finite(gap) and gap <= float(state.contact_tolerance_m) and boundary_clear)
	var candidate := {"angles_rad": angles.duplicate(), "contact": contact, "score": score,
		"boundary_candidate_clear": boundary_clear,
		"ranking_region_contact_count": count, "ranking_regions_are_not_verified_grip_contacts": true}
	state.cache[key] = candidate
	if state.best.is_empty() or _better(candidate, state.best):
		state.best = candidate
	if keep_seed:
		state.seeds.append(candidate)
		state.seeds.sort_custom(_better)
		if state.seeds.size() > 4:
			state.seeds.pop_back()
	return candidate

func _better(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.boundary_candidate_clear) != bool(b.boundary_candidate_clear):
		return bool(a.boundary_candidate_clear)
	return float(a.score) < float(b.score)
