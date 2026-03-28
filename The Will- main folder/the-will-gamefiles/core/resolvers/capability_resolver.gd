extends RefCounted
class_name CapabilityResolver

func derive_capability_scores(
		profile: BakedProfile,
		material_bias_lines: Array[StatLine] = [],
		context_bias_lines: Array[StatLine] = []
	) -> Dictionary[StringName, float]:
	var capability_scores: Dictionary[StringName, float] = {}
	if profile == null:
		return capability_scores

	capability_scores[&"cap_edge"] = _clamp_capability(
		profile.edge_score + _get_bias_total(&"cap_edge", material_bias_lines, context_bias_lines)
	)
	capability_scores[&"cap_blunt"] = _clamp_capability(
		profile.blunt_score + _get_bias_total(&"cap_blunt", material_bias_lines, context_bias_lines)
	)
	capability_scores[&"cap_pierce"] = _clamp_capability(
		profile.pierce_score + _get_bias_total(&"cap_pierce", material_bias_lines, context_bias_lines)
	)
	capability_scores[&"cap_guard"] = _clamp_capability(
		profile.guard_score + _get_bias_total(&"cap_guard", material_bias_lines, context_bias_lines)
	)
	capability_scores[&"cap_flex"] = _clamp_capability(
		profile.flex_score + _get_bias_total(&"cap_flex", material_bias_lines, context_bias_lines)
	)
	capability_scores[&"cap_launch"] = _clamp_capability(
		profile.launch_score + _get_bias_total(&"cap_launch", material_bias_lines, context_bias_lines)
	)
	capability_scores[&"cap_stability"] = _clamp_capability(
		profile.balance_score + _get_bias_total(&"cap_stability", material_bias_lines, context_bias_lines)
	)
	capability_scores[&"cap_reach"] = _normalize_reach_value(profile.reach)
	# TODO: NEEDS_DECISION - lock optional reach bonus behavior for cap_pierce.
	# TODO: context bias plumbing is now supported, but no forge context/page layer is passing lines yet.
	# TODO: NEEDS_DECISION - lock capability thresholds mapping to 0/1/2/3/4.
	return capability_scores

func _get_bias_total(
		capability_id: StringName,
		material_bias_lines: Array[StatLine],
		context_bias_lines: Array[StatLine]
	) -> float:
	return _sum_matching_bias_lines(capability_id, material_bias_lines) + _sum_matching_bias_lines(capability_id, context_bias_lines)

func _sum_matching_bias_lines(capability_id: StringName, bias_lines: Array[StatLine]) -> float:
	var total: float = 0.0
	for bias_line: StatLine in bias_lines:
		if bias_line == null:
			continue
		if bias_line.stat_id != capability_id:
			continue
		if not bias_line.is_numeric():
			continue
		total += bias_line.value
	return total

func _clamp_capability(value: float) -> float:
	return clampf(value, 0.0, 1.0)

func _normalize_reach_value(reach: float) -> float:
	# TODO: NEEDS_DECISION - exact reach normalization baseline beyond first-pass max-distance is not locked yet.
	return clampf(reach, 0.0, 1.0)