extends "res://runtime/player/player_finger_surface_grip_solver.gd"

## Diagnostic only: frozen Hand/weapon frames, exact existing capsule queries,
## and existing local hinges. Returned candidates are never applied to a rig.
## Vector3/Basis below also represent three residuals and a Jacobian; those are
## numeric tuples, not additional spatial origins. Spatial data stays in the
## supplied snapshot/surface's declared bone -> RL_BoneRoot presentation chain.
const PROBE_MAX_EVALUATIONS: int = 128
const PROBE_SEED_REFINEMENT_BUDGET: int = 36
const PROBE_DIFFERENCE_RADIANS: float = 0.00872664626 # 0.5 degrees
const PROBE_MAX_STEP_RADIANS: float = 0.1745329252 # 10 degrees
const PROBE_DAMPING: float = 0.0000001


func probe(
	snapshot: Dictionary,
	surface: Dictionary,
	preferred: float,
	cap: float,
	options: Dictionary,
	wider_root_open_degrees: float = 0.0
) -> Dictionary:
	var started_usec: int = Time.get_ticks_usec()
	var input_reason: StringName = _probe_input_reason(snapshot, surface, preferred, cap)
	if input_reason != &"ok":
		return _probe_unavailable(input_reason, started_usec)
	if bool(snapshot.get("is_thumb", false)):
		return _probe_unavailable(&"thumb_collinear_clearance_not_prototyped", started_usec)
	if not is_finite(wider_root_open_degrees) or wider_root_open_degrees < 0.0 or wider_root_open_degrees > 180.0:
		return _probe_unavailable(&"invalid_wider_root_open_degrees", started_usec)
	if not (options.has("fallback_ray_target_world") or options.has("grip_center_world") or (options.has("grip_span_start_world") and options.has("grip_span_end_world"))):
		return _probe_unavailable(&"missing_captured_grip_target", started_usec)
	var grip_center_world: Vector3 = _resolve_fallback_ray_target(options)
	if not grip_center_world.is_finite():
		return _probe_unavailable(&"nonfinite_captured_grip_target", started_usec)

	var working_snapshot: Dictionary = snapshot.duplicate(true)
	var minimums: Array = working_snapshot["min_angles_rad"]
	var maximums: Array = working_snapshot["max_angles_rad"]
	var original_minimums: Array = minimums.duplicate()
	var original_maximums: Array = maximums.duplicate()
	var seed_open: Array[float] = _resolve_open_angles(working_snapshot)
	if wider_root_open_degrees > 0.0:
		var root_bone_name: String = String((working_snapshot["bone_names"] as Array)[0])
		if root_bone_name.begins_with("CC_Base_R_"):
			minimums[0] = minf(float(minimums[0]), -deg_to_rad(wider_root_open_degrees))
			seed_open[0] = float(minimums[0])
		elif root_bone_name.begins_with("CC_Base_L_"):
			maximums[0] = maxf(float(maximums[0]), deg_to_rad(wider_root_open_degrees))
			seed_open[0] = float(maximums[0])
		else:
			return _probe_unavailable(&"unknown_hand_for_wider_range", started_usec)
	var closed: Array[float] = _resolve_closed_angles(working_snapshot, seed_open)
	var targets: Array[float] = []
	for target_variant: Variant in working_snapshot["section_target_overlaps_meters"]:
		targets.append(clampf(float(target_variant), 0.0, cap))
	var context: Dictionary = {
		"snapshot": working_snapshot, "surface": surface,
		"grip_center_world": grip_center_world,
		"maximum_ray_distance": float(options.get("max_fallback_ray_distance_meters", 0.2)),
		"targets": targets, "cap": cap, "stats": {}, "evaluations": 0,
		"best": {},
	}
	var baseline: Dictionary = _probe_evaluate(context, _resolve_open_angles(working_snapshot))
	var seeds: Array[Dictionary] = [baseline]
	# Equal closure and two opposing lead/lag schedules. These are search seeds,
	# not claims about tendon anatomy or an animation/presentation path.
	for profile_index: int in range(3):
		for sample_index: int in range(6):
			var t: float = float(sample_index) / 5.0
			var fractions: Array[float] = [t, t, t]
			if profile_index == 1:
				fractions = [t, t * t, t * t * t]
			elif profile_index == 2:
				fractions = [t * t * t, t * t, t]
			var angles: Array[float] = []
			for joint_index: int in range(3):
				angles.append(lerpf(seed_open[joint_index], closed[joint_index], fractions[joint_index]))
			var duplicate_seed: bool = false
			for seed: Dictionary in seeds:
				if not _serial_angles_differ(angles, seed["angles_rad"]):
					duplicate_seed = true
					break
			if not duplicate_seed:
				seeds.append(_probe_evaluate(context, angles))
	seeds.sort_custom(_probe_candidate_better)
	for seed_index: int in range(mini(3, seeds.size())):
		if bool((context["best"] as Dictionary).get("full_contact", false)):
			break
		_probe_refine(context, seeds[seed_index])
	var best: Dictionary = context["best"]
	var evaluation: Dictionary = best["evaluation"]
	var safe: bool = bool(best["exact_safe"])
	var full_contact: bool = bool(best["full_contact"])
	var overlaps: Array[float] = []
	var contact_count: int = 0
	for section: Dictionary in evaluation["section_states"]:
		overlaps.append(float(section.get("signed_overlap_meters", -INF)))
		if bool(section.get("in_contact", false)):
			contact_count += 1
	return {
		"available": true,
		"status": &"full_contact" if full_contact else (&"exact_safe_partial" if safe else &"no_exact_safe_candidate_found"),
		"digit_id": snapshot.get("digit_id"),
		"angles_rad": best["angles_rad"],
		"angles_degrees": _probe_degrees(best["angles_rad"]),
		"exact_safe": safe, "full_contact": full_contact,
		"contact_count": contact_count,
		"target_band_contact_count": evaluation.get("feasible_section_count", 0),
		"signed_overlaps_meters": overlaps,
		"sections": evaluation["section_states"],
		"max_penetration_meters": evaluation.get("max_penetration_meters", INF),
		"initial_open_evaluation": baseline["evaluation"],
		"initial_open_angles_rad": baseline["angles_rad"],
		"original_min_angles_rad": original_minimums,
		"original_max_angles_rad": original_maximums,
		"tested_min_angles_rad": minimums, "tested_max_angles_rad": maximums,
		"wider_root_open_degrees": wider_root_open_degrees,
		"section_targets_meters": targets, "max_overlap_meters": cap,
		"pose_evaluation_count": context["evaluations"],
		"pose_evaluation_budget": PROBE_MAX_EVALUATIONS,
		"query_count": (context["stats"] as Dictionary).get("surface_query_count", 0),
		"query_stats": context["stats"],
		"elapsed_milliseconds": float(Time.get_ticks_usec() - started_usec) / 1000.0,
		"search_method": &"coupled_seeds_signed_overlap_damped_least_squares",
		"path_safety_checked": false, "live_pose_written": false,
	}


func _probe_refine(context: Dictionary, seed: Dictionary) -> void:
	var current: Dictionary = seed
	var snapshot: Dictionary = context["snapshot"]
	var minimums: Array = snapshot["min_angles_rad"]
	var maximums: Array = snapshot["max_angles_rad"]
	var evaluation_limit: int = mini(int(context["evaluations"]) + PROBE_SEED_REFINEMENT_BUDGET, PROBE_MAX_EVALUATIONS)
	for _iteration: int in range(9):
		if int(context["evaluations"]) + 4 > evaluation_limit or not bool(current["query_valid"]) or bool(current["full_contact"]):
			break
		var angles: Array[float] = current["angles_rad"]
		var residual: Vector3 = current["residual"]
		var columns: Array[Vector3] = []
		for joint_index: int in range(3):
			var perturbed: Array[float] = angles.duplicate()
			var difference: float = PROBE_DIFFERENCE_RADIANS
			if angles[joint_index] + difference > float(maximums[joint_index]):
				difference = -difference
			perturbed[joint_index] = clampf(angles[joint_index] + difference, float(minimums[joint_index]), float(maximums[joint_index]))
			difference = perturbed[joint_index] - angles[joint_index]
			if absf(difference) <= ANGLE_EPSILON:
				columns.append(Vector3.ZERO)
				continue
			var sampled: Dictionary = _probe_evaluate(context, perturbed)
			if not bool(sampled.get("query_valid", false)):
				return
			columns.append(((sampled["residual"] as Vector3) - residual) / difference)
		var jacobian := Basis(columns[0], columns[1], columns[2])
		var normal: Basis = jacobian.transposed() * jacobian
		normal = Basis(normal.x + Vector3(PROBE_DAMPING, 0.0, 0.0), normal.y + Vector3(0.0, PROBE_DAMPING, 0.0), normal.z + Vector3(0.0, 0.0, PROBE_DAMPING))
		if not normal.is_finite() or not is_finite(normal.determinant()) or normal.determinant() == 0.0:
			break
		var step: Vector3 = -(normal.inverse() * (jacobian.transposed() * residual))
		if not step.is_finite() or step.length_squared() < ANGLE_EPSILON * ANGLE_EPSILON:
			break
		var largest_step: float = maxf(absf(step.x), maxf(absf(step.y), absf(step.z)))
		if largest_step > PROBE_MAX_STEP_RADIANS:
			step *= PROBE_MAX_STEP_RADIANS / largest_step
		var improved: bool = false
		for line_scale: float in [1.0, 0.5, 0.25, 0.125]:
			if int(context["evaluations"]) >= evaluation_limit:
				break
			var candidate_angles: Array[float] = []
			for joint_index: int in range(3):
				candidate_angles.append(clampf(angles[joint_index] + step[joint_index] * line_scale, float(minimums[joint_index]), float(maximums[joint_index])))
			if not _serial_angles_differ(candidate_angles, angles):
				continue
			var candidate: Dictionary = _probe_evaluate(context, candidate_angles)
			if _probe_candidate_better(candidate, current):
				current = candidate
				improved = true
				break
		if not improved:
			break


func _probe_evaluate(context: Dictionary, angles: Array[float]) -> Dictionary:
	if int(context["evaluations"]) >= PROBE_MAX_EVALUATIONS:
		return {}
	context["evaluations"] = int(context["evaluations"]) + 1
	var targets: Array[float] = context["targets"]
	var evaluation: Dictionary = _evaluate_serial_pose_safety(context["snapshot"], context["surface"], angles, context["grip_center_world"], context["maximum_ray_distance"], targets, context["cap"], DEFAULT_MAX_ACCEPTABLE_CONTACT_ERROR_METERS, context["stats"])
	var invalid_count: int = 0
	var maximum_excess: float = 0.0
	var total_excess_squared: float = 0.0
	var residual := Vector3.ZERO
	var sections: Array = evaluation["section_states"]
	for section_index: int in range(3):
		var section: Dictionary = sections[section_index]
		var signed_overlap: float = float(section.get("signed_overlap_meters", INF))
		if not bool(section.get("inside_classification_valid", false)) or not is_finite(signed_overlap):
			invalid_count += 1
			residual[section_index] = INF
			continue
		var section_cap: float = float(section["section_max_allowed_overlap_meters"])
		var excess: float = maxf(float(section["penetration_meters"]) - section_cap - OVERLAP_NUMERIC_EPSILON_METERS, 0.0)
		maximum_excess = maxf(maximum_excess, excess)
		total_excess_squared += excess * excess
		var solve_target: float = minf(targets[section_index], maxf(section_cap - HARD_CAP_TARGET_GUARD_METERS, 0.0))
		residual[section_index] = signed_overlap - solve_target
	var safe: bool = invalid_count == 0 and bool(evaluation["overlap_limit_respected"]) and int(evaluation["inside_solid_section_count"]) == 0
	var full_contact: bool = safe and int(evaluation["feasible_section_count"]) == 3
	var candidate: Dictionary = {
		"angles_rad": angles.duplicate(), "evaluation": evaluation,
		"query_valid": invalid_count == 0, "exact_safe": safe,
		"full_contact": full_contact,
		"residual": residual,
		# Hard safety precedes closeness to contact; unsafe numerical candidates
		# can guide search but are never labelled usable/full-contact output.
		"rank": [float(invalid_count), float(evaluation["inside_solid_section_count"]), maximum_excess, total_excess_squared, 0.0 if full_contact else 1.0, residual.length_squared()],
	}
	if (context["best"] as Dictionary).is_empty() or _probe_candidate_better(candidate, context["best"]):
		context["best"] = candidate
	return candidate


func _probe_candidate_better(first: Dictionary, second: Dictionary) -> bool:
	var first_rank: Array = first["rank"]
	var second_rank: Array = second["rank"]
	for index: int in range(first_rank.size()):
		if float(first_rank[index]) != float(second_rank[index]):
			return float(first_rank[index]) < float(second_rank[index])
	return false


func _probe_input_reason(snapshot: Dictionary, surface: Dictionary, preferred: float, cap: float) -> StringName:
	if not bool(snapshot.get("valid", false)) or not bool(surface.get("valid", false)):
		return &"invalid_snapshot_or_prepared_surface"
	if not is_finite(preferred) or not is_finite(cap) or preferred < 0.0 or cap <= 0.0 or cap > MAX_ALLOWED_OVERLAP_METERS or preferred > cap:
		return &"invalid_or_widened_overlap_cap"
	if snapshot.get("bone_root_origin_id") != &"RL_BoneRoot" or surface.get("resolved_world_origin_id") != &"RL_BoneRoot" or StringName(surface.get("surface_source_origin_id", &"")) == StringName():
		return &"invalid_origin_contract"
	for key: String in ["bone_names", "relative_transforms", "neutral_local_rotations", "hinge_axes_local", "min_angles_rad", "max_angles_rad", "preferred_angles_rad", "capsule_radii_m", "section_target_overlaps_meters"]:
		if not snapshot.get(key) is Array or (snapshot[key] as Array).size() != 3:
			return StringName("invalid_%s" % key)
	if not snapshot.get("root_parent_world") is Transform3D or not (snapshot["root_parent_world"] as Transform3D).is_finite():
		return &"invalid_root_parent_frame"
	for index: int in range(3):
		for key: String in ["min_angles_rad", "max_angles_rad", "preferred_angles_rad", "capsule_radii_m", "section_target_overlaps_meters"]:
			if not is_finite(float((snapshot[key] as Array)[index])):
				return StringName("nonfinite_%s" % key)
		if float(snapshot["min_angles_rad"][index]) > float(snapshot["max_angles_rad"][index]) or float(snapshot["capsule_radii_m"][index]) <= 0.0:
			return &"invalid_bounds_or_radius"
		if not snapshot["relative_transforms"][index] is Transform3D or not (snapshot["relative_transforms"][index] as Transform3D).is_finite():
			return &"invalid_relative_frame"
		if not snapshot["hinge_axes_local"][index] is Vector3 or not (snapshot["hinge_axes_local"][index] as Vector3).is_equal_approx(Vector3(0.0, 0.0, 1.0)):
			return &"unexpected_local_hinge_axis"
	return &"ok"


func _probe_degrees(angles: Array[float]) -> Array[float]:
	var degrees: Array[float] = []
	for angle: float in angles:
		degrees.append(rad_to_deg(angle))
	return degrees


func _probe_unavailable(reason: StringName, started_usec: int) -> Dictionary:
	return {"available": false, "status": reason, "angles_rad": [], "exact_safe": false, "full_contact": false, "pose_evaluation_count": 0, "query_count": 0, "elapsed_milliseconds": float(Time.get_ticks_usec() - started_usec) / 1000.0, "live_pose_written": false, "path_safety_checked": false}
