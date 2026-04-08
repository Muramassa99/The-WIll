extends RefCounted
class_name PlayerRigGripLayoutPresenter

func resolve_grip_hold_layout(
	baked_profile: BakedProfile,
	dominant_slot_id: StringName,
	cell_world_size_meters: float,
	max_model_arm_reach_combat_meters: float
) -> Dictionary:
	var resolved_dominant_slot_id: StringName = normalize_hand_slot_id(dominant_slot_id)
	var support_slot_id: StringName = resolve_support_slot_id(resolved_dominant_slot_id)
	var layout := {
		"valid": false,
		"dominant_slot_id": resolved_dominant_slot_id,
		"support_slot_id": support_slot_id,
		"dominant_hand_local_position": Vector3.ZERO,
		"support_hand_local_position": Vector3.ZERO,
		"dominant_hand_axis_ratio_from_span_start": 0.0,
		"support_hand_axis_ratio_from_span_start": 0.0,
		"dominant_hand_contact_percent": 0.0,
		"support_hand_contact_percent": 0.0,
		"dominant_hand_signed_ratio": 0.0,
		"support_hand_signed_ratio": 0.0,
		"two_hand_weapon_eligible": false,
		"two_hand_character_eligible": false,
		"center_balance_valid": false,
		"character_two_hand_span_meters": max_model_arm_reach_combat_meters,
		"weapon_two_hand_span_meters": 0.0,
		"effective_two_hand_span_meters": 0.0,
	}
	if baked_profile == null or not baked_profile.primary_grip_valid:
		return layout

	var safe_cell_world_size_meters: float = maxf(cell_world_size_meters, 0.00001)
	var slide_axis: Vector3 = resolve_profile_slide_axis(baked_profile)
	if slide_axis == Vector3.ZERO:
		return layout

	var dominant_position: Vector3 = baked_profile.primary_grip_contact_position
	layout.valid = true
	layout.dominant_hand_local_position = dominant_position
	layout.dominant_hand_axis_ratio_from_span_start = project_axis_ratio_on_profile_span(dominant_position, baked_profile)
	layout.dominant_hand_contact_percent = resolve_profile_contact_percent(float(layout.dominant_hand_axis_ratio_from_span_start), baked_profile)
	layout.two_hand_weapon_eligible = baked_profile.primary_grip_two_hand_eligible
	layout.center_balance_valid = baked_profile.primary_grip_center_balance_valid

	if max_model_arm_reach_combat_meters <= 0.0 or not baked_profile.primary_grip_two_hand_eligible:
		return layout

	if baked_profile.primary_grip_center_balance_valid:
		var weapon_negative_half_span_meters: float = resolve_profile_half_span_limit_meters(
			baked_profile.primary_grip_two_hand_negative_limit,
			baked_profile,
			safe_cell_world_size_meters
		)
		var weapon_positive_half_span_meters: float = resolve_profile_half_span_limit_meters(
			baked_profile.primary_grip_two_hand_positive_limit,
			baked_profile,
			safe_cell_world_size_meters
		)
		var character_half_span_meters: float = max_model_arm_reach_combat_meters * 0.5
		var effective_half_span_meters: float = minf(character_half_span_meters, minf(weapon_negative_half_span_meters, weapon_positive_half_span_meters))
		layout.weapon_two_hand_span_meters = minf(weapon_negative_half_span_meters, weapon_positive_half_span_meters) * 2.0
		if effective_half_span_meters <= 0.0:
			return layout
		var dominant_offset_units: float = effective_half_span_meters / safe_cell_world_size_meters
		var support_offset_units: float = -dominant_offset_units
		dominant_position = baked_profile.primary_grip_center_balance_origin + slide_axis * dominant_offset_units
		var balanced_support_position: Vector3 = baked_profile.primary_grip_center_balance_origin + slide_axis * support_offset_units
		layout.dominant_hand_local_position = dominant_position
		layout.support_hand_local_position = balanced_support_position
		layout.dominant_hand_axis_ratio_from_span_start = project_axis_ratio_on_profile_span(dominant_position, baked_profile)
		layout.support_hand_axis_ratio_from_span_start = project_axis_ratio_on_profile_span(balanced_support_position, baked_profile)
		layout.dominant_hand_contact_percent = resolve_profile_contact_percent(float(layout.dominant_hand_axis_ratio_from_span_start), baked_profile)
		layout.support_hand_contact_percent = resolve_profile_contact_percent(float(layout.support_hand_axis_ratio_from_span_start), baked_profile)
		layout.effective_two_hand_span_meters = effective_half_span_meters * 2.0
		layout.two_hand_character_eligible = true
		layout.dominant_hand_signed_ratio = safe_ratio(effective_half_span_meters, character_half_span_meters)
		layout.support_hand_signed_ratio = -float(layout.dominant_hand_signed_ratio)
		return layout

	var far_side_position: Vector3 = baked_profile.primary_grip_far_side_position
	var support_direction: Vector3 = far_side_position - dominant_position
	if support_direction.length_squared() <= 0.00001:
		return layout
	var available_support_distance_meters: float = dominant_position.distance_to(far_side_position) * safe_cell_world_size_meters
	var effective_support_distance_meters: float = minf(max_model_arm_reach_combat_meters, available_support_distance_meters)
	layout.weapon_two_hand_span_meters = available_support_distance_meters
	if effective_support_distance_meters <= 0.0:
		return layout
	var far_side_support_position: Vector3 = dominant_position + support_direction.normalized() * (effective_support_distance_meters / safe_cell_world_size_meters)
	layout.support_hand_local_position = far_side_support_position
	layout.support_hand_axis_ratio_from_span_start = project_axis_ratio_on_profile_span(far_side_support_position, baked_profile)
	layout.support_hand_contact_percent = resolve_profile_contact_percent(float(layout.support_hand_axis_ratio_from_span_start), baked_profile)
	layout.effective_two_hand_span_meters = effective_support_distance_meters
	layout.two_hand_character_eligible = true
	layout.dominant_hand_signed_ratio = 0.0
	layout.support_hand_signed_ratio = -safe_ratio(effective_support_distance_meters, max_model_arm_reach_combat_meters)
	return layout

func apply_pole_grip_arm_reach_limits(max_model_arm_reach_meters: float, pole_grip_arm_reach_margin_percent: float) -> Dictionary:
	var clamped_margin_percent: float = clampf(pole_grip_arm_reach_margin_percent, 0.0, 0.5)
	var max_model_arm_reach_combat_meters: float = maxf(max_model_arm_reach_meters * (1.0 - clamped_margin_percent), 0.0)
	var half_span: float = max_model_arm_reach_combat_meters * 0.5
	return {
		"max_model_arm_reach_combat_meters": max_model_arm_reach_combat_meters,
		"pole_grip_negative_limit_meters": -half_span,
		"pole_grip_positive_limit_meters": half_span,
	}

func resolve_profile_slide_axis(baked_profile: BakedProfile) -> Vector3:
	if baked_profile == null:
		return Vector3.ZERO
	if baked_profile.primary_grip_slide_axis != Vector3.ZERO:
		return baked_profile.primary_grip_slide_axis.normalized()
	var span_vector: Vector3 = baked_profile.primary_grip_span_end - baked_profile.primary_grip_span_start
	if span_vector == Vector3.ZERO:
		return Vector3.ZERO
	return span_vector.normalized()

func resolve_profile_half_span_limit_meters(limit_ratio: float, baked_profile: BakedProfile, cell_world_size_meters: float) -> float:
	if baked_profile == null:
		return 0.0
	var total_span_meters: float = baked_profile.primary_grip_span_start.distance_to(baked_profile.primary_grip_span_end) * cell_world_size_meters
	return total_span_meters * 0.5 * absf(limit_ratio)

func project_axis_ratio_on_profile_span(local_position: Vector3, baked_profile: BakedProfile) -> float:
	if baked_profile == null:
		return 0.0
	var span_start: Vector3 = baked_profile.primary_grip_span_start
	var span_end: Vector3 = baked_profile.primary_grip_span_end
	var span_vector: Vector3 = span_end - span_start
	var span_length_squared: float = span_vector.length_squared()
	if span_length_squared <= 0.00001:
		return 0.0
	return clampf((local_position - span_start).dot(span_vector) / span_length_squared, 0.0, 1.0)

func resolve_profile_contact_percent(axis_ratio_from_span_start: float, baked_profile: BakedProfile) -> float:
	if baked_profile == null:
		return 0.0
	var com_side_is_span_start: bool = baked_profile.primary_grip_com_side_position.distance_squared_to(baked_profile.primary_grip_span_start) <= baked_profile.primary_grip_com_side_position.distance_squared_to(baked_profile.primary_grip_span_end)
	return (1.0 - axis_ratio_from_span_start) if com_side_is_span_start else axis_ratio_from_span_start

func normalize_hand_slot_id(slot_id: StringName) -> StringName:
	if slot_id == &"hand_left":
		return &"hand_left"
	return &"hand_right"

func resolve_support_slot_id(dominant_slot_id: StringName) -> StringName:
	if dominant_slot_id == &"hand_left":
		return &"hand_right"
	return &"hand_left"

func safe_ratio(value: float, divisor: float) -> float:
	if absf(divisor) <= 0.00001:
		return 0.0
	return clampf(value / divisor, 0.0, 1.0)
