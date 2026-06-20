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
	capability_scores[&"cap_pierce"] = _resolve_pierce_capability(profile, material_bias_lines, context_bias_lines)
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
	# Current first-pass contract:
	# - optional pierce reach bonus is intentionally disabled until a later weighting rule is locked
	# - context bias lines are accepted when passed, even though no forge context/page layer emits them yet
	# - threshold/display-tier mapping stays outside this resolver for now
	return capability_scores

func _resolve_pierce_capability(
		profile: BakedProfile,
		material_bias_lines: Array[StatLine],
		context_bias_lines: Array[StatLine]
	) -> float:
	var pierce_total: float = profile.pierce_score + _get_bias_total(&"cap_pierce", material_bias_lines, context_bias_lines)
	return _clamp_capability(pierce_total + _resolve_optional_pierce_reach_bonus(profile))

func _resolve_optional_pierce_reach_bonus(_profile: BakedProfile) -> float:
	return 0.0

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
	# Current first-pass rule: use the existing max-distance reach output directly and clamp it
	# into the debug-friendly 0.0-1.0 capability range until a richer normalization baseline exists.
	return clampf(reach, 0.0, 1.0)
