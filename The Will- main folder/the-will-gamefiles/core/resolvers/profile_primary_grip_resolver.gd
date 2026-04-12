extends RefCounted
class_name ProfilePrimaryGripResolver

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")

var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE
var anchor_resolver: AnchorResolver

func _init(rules: ForgeRulesDef = null) -> void:
	forge_rules = rules if rules != null else DEFAULT_FORGE_RULES_RESOURCE
	anchor_resolver = AnchorResolver.new(forge_rules)

func apply_primary_grip_profile(
	profile: BakedProfile,
	cells: Array[CellAtom],
	anchors: Array[AnchorAtom],
	center_of_mass: Vector3,
	forge_intent: StringName,
	equipment_context: StringName
) -> void:
	if profile == null:
		return

	var primary_grip: AnchorAtom = _find_primary_grip_anchor(anchors, center_of_mass)
	profile.primary_grip_valid = primary_grip != null
	if primary_grip == null:
		if profile.validation_error.is_empty():
			profile.validation_error = "no_primary_grip_candidate"
		return

	var grip_contact_position: Vector3 = anchor_resolver.resolve_primary_grip_contact_position(primary_grip, center_of_mass)
	var forward_axis: Vector3 = _resolve_forward_axis(primary_grip)
	profile.primary_grip_contact_position = grip_contact_position
	profile.primary_grip_span_start = primary_grip.span_start_local_position
	profile.primary_grip_span_end = primary_grip.span_end_local_position
	profile.primary_grip_span_length_voxels = primary_grip.span_length
	profile.primary_grip_slide_axis = forward_axis
	_apply_primary_grip_occupancy_metadata(
		profile,
		primary_grip,
		center_of_mass,
		forge_intent,
		equipment_context
	)
	profile.primary_grip_offset = anchor_resolver.calculate_primary_grip_offset(
		center_of_mass,
		grip_contact_position
	)
	profile.reach = _calculate_reach(cells, grip_contact_position)
	profile.front_heavy_score = _calculate_front_heavy_score(
		profile.primary_grip_offset,
		forward_axis,
		profile.reach
	)
	profile.balance_score = _calculate_balance_score(profile.primary_grip_offset, profile.reach)
	_apply_weapon_total_length(profile, cells, forward_axis, primary_grip.span_start_local_position, grip_contact_position)

func _find_primary_grip_anchor(anchors: Array[AnchorAtom], center_of_mass: Vector3 = Vector3.ZERO) -> AnchorAtom:
	var best_anchor: AnchorAtom = null
	var best_distance_squared: float = INF
	var best_span_length: int = -1
	for anchor: AnchorAtom in anchors:
		if anchor == null:
			continue
		if anchor.anchor_type != "primary_grip":
			continue
		var candidate_position: Vector3 = anchor_resolver.resolve_primary_grip_contact_position(anchor, center_of_mass)
		var distance_squared: float = candidate_position.distance_squared_to(center_of_mass)
		var candidate_span_length: int = maxi(anchor.span_length, 0)
		if best_anchor == null or distance_squared < best_distance_squared - 0.00001:
			best_anchor = anchor
			best_distance_squared = distance_squared
			best_span_length = candidate_span_length
			continue
		if is_equal_approx(distance_squared, best_distance_squared) and candidate_span_length > best_span_length:
			best_anchor = anchor
			best_span_length = candidate_span_length
	return best_anchor

func _resolve_forward_axis(primary_grip: AnchorAtom) -> Vector3:
	if primary_grip == null:
		return Vector3.ZERO
	if primary_grip.local_axis == Vector3.ZERO:
		return Vector3.ZERO
	return primary_grip.local_axis.normalized()

func _calculate_reach(cells: Array[CellAtom], primary_grip_position: Vector3) -> float:
	var max_distance: float = 0.0
	for cell: CellAtom in cells:
		if cell == null:
			continue
		var distance: float = primary_grip_position.distance_to(cell.get_center_position())
		if distance > max_distance:
			max_distance = distance
	return max_distance

func _calculate_front_heavy_score(primary_grip_offset: Vector3, forward_axis: Vector3, reach: float) -> float:
	if forward_axis == Vector3.ZERO:
		return 0.0
	var epsilon: float = 0.00001
	var safe_reach: float = maxf(reach, epsilon)
	var projected_offset: float = primary_grip_offset.dot(forward_axis)
	return clampf(projected_offset / safe_reach, -1.0, 1.0)

func _calculate_balance_score(primary_grip_offset: Vector3, reach: float) -> float:
	var epsilon: float = 0.00001
	var safe_reach: float = maxf(reach, epsilon)
	return 1.0 - clampf(primary_grip_offset.length() / safe_reach, 0.0, 1.0)

func _apply_primary_grip_occupancy_metadata(
	profile: BakedProfile,
	primary_grip: AnchorAtom,
	center_of_mass: Vector3,
	forge_intent: StringName,
	equipment_context: StringName
) -> void:
	if profile == null or primary_grip == null:
		return

	var span_projection: Dictionary = _resolve_primary_grip_span_projection(primary_grip, center_of_mass)
	var clamped_ratio: float = float(span_projection.get("clamped_ratio", 0.0))
	var unclamped_ratio: float = float(span_projection.get("unclamped_ratio", 0.0))
	var span_start_is_com_side: bool = bool(span_projection.get("span_start_is_com_side", true))

	profile.primary_grip_axis_ratio_from_span_start = clamped_ratio
	profile.primary_grip_contact_percent = (1.0 - clamped_ratio) if span_start_is_com_side else clamped_ratio
	profile.primary_grip_com_side_position = primary_grip.span_start_local_position if span_start_is_com_side else primary_grip.span_end_local_position
	profile.primary_grip_far_side_position = primary_grip.span_end_local_position if span_start_is_com_side else primary_grip.span_start_local_position
	profile.primary_grip_center_balance_offset_percent = absf(unclamped_ratio - 0.5)

	var center_balance_valid: bool = _is_primary_grip_center_balance_valid(unclamped_ratio)
	profile.primary_grip_center_balance_valid = center_balance_valid
	if center_balance_valid:
		profile.primary_grip_center_balance_origin = span_projection.get("projected_position", profile.primary_grip_contact_position)

	var two_hand_eligible: bool = _is_primary_grip_two_hand_eligible(primary_grip, forge_intent, equipment_context)
	profile.primary_grip_two_hand_eligible = two_hand_eligible
	if two_hand_eligible and center_balance_valid:
		var signed_limit: float = clampf(forge_rules.primary_grip_two_hand_max_span_usage_percent, 0.0, 1.0)
		profile.primary_grip_two_hand_negative_limit = -signed_limit
		profile.primary_grip_two_hand_positive_limit = signed_limit

func _resolve_primary_grip_span_projection(primary_grip: AnchorAtom, desired_position: Vector3) -> Dictionary:
	if primary_grip == null:
		return {}
	var span_start: Vector3 = primary_grip.span_start_local_position
	var span_end: Vector3 = primary_grip.span_end_local_position
	var span_vector: Vector3 = span_end - span_start
	var span_length_squared: float = span_vector.length_squared()
	if span_length_squared <= 0.00001:
		return {
			"clamped_ratio": 0.0,
			"unclamped_ratio": 0.0,
			"projected_position": primary_grip.local_position,
			"span_start_is_com_side": true,
		}
	var unclamped_ratio: float = (desired_position - span_start).dot(span_vector) / span_length_squared
	var clamped_ratio: float = clampf(unclamped_ratio, 0.0, 1.0)
	return {
		"clamped_ratio": clamped_ratio,
		"unclamped_ratio": unclamped_ratio,
		"projected_position": span_start + span_vector * clamped_ratio,
		"span_start_is_com_side": desired_position.distance_squared_to(span_start) <= desired_position.distance_squared_to(span_end),
	}

func _is_primary_grip_center_balance_valid(unclamped_ratio: float) -> bool:
	if unclamped_ratio < 0.0 or unclamped_ratio > 1.0:
		return false
	return absf(unclamped_ratio - 0.5) <= forge_rules.primary_grip_center_balance_tolerance_percent

func _is_primary_grip_two_hand_eligible(
	primary_grip: AnchorAtom,
	forge_intent: StringName,
	equipment_context: StringName
) -> bool:
	if primary_grip == null:
		return false
	var branch_allows_two_hand: bool = (
		(forge_intent == &"intent_melee" and equipment_context == &"ctx_weapon")
		or (forge_intent == &"intent_magic" and equipment_context == &"ctx_focus")
	)
	if not branch_allows_two_hand:
		return false
	return primary_grip.span_length >= forge_rules.primary_grip_two_hand_min_length_voxels

func _apply_weapon_total_length(
	profile: BakedProfile,
	cells: Array[CellAtom],
	grip_axis_direction: Vector3,
	grip_axis_origin: Vector3,
	hand_contact_position: Vector3
) -> void:
	if profile == null or cells.is_empty() or grip_axis_direction.length_squared() <= 0.00001:
		return
	var axis_normalized: Vector3 = grip_axis_direction.normalized()
	var min_proj: float = INF
	var max_proj: float = -INF
	for cell: CellAtom in cells:
		if cell == null:
			continue
		var center: Vector3 = cell.get_center_position()
		var proj: float = axis_normalized.dot(center - grip_axis_origin)
		min_proj = minf(min_proj, proj)
		max_proj = maxf(max_proj, proj)
	if min_proj >= max_proj:
		return
	var total_length: float = max_proj - min_proj
	var extremity_1: Vector3 = grip_axis_origin + axis_normalized * min_proj
	var extremity_2: Vector3 = grip_axis_origin + axis_normalized * max_proj
	var hand_proj: float = axis_normalized.dot(hand_contact_position - grip_axis_origin)
	var dist_to_1: float = absf(hand_proj - min_proj)
	var dist_to_2: float = absf(hand_proj - max_proj)
	var tip_point: Vector3
	var pommel_point: Vector3
	var tip_dist: float
	var pommel_dist: float
	if dist_to_2 >= dist_to_1:
		tip_point = extremity_2
		pommel_point = extremity_1
		tip_dist = dist_to_2
		pommel_dist = dist_to_1
	else:
		tip_point = extremity_1
		pommel_point = extremity_2
		tip_dist = dist_to_1
		pommel_dist = dist_to_2
	profile.weapon_total_length_meters = total_length
	profile.weapon_tip_point = tip_point
	profile.weapon_pommel_point = pommel_point
	profile.weapon_tip_distance_meters = tip_dist
	profile.weapon_pommel_distance_meters = pommel_dist
