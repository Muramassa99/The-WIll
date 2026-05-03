extends RefCounted
class_name CombatAnimationRetargetResolver

const CombatAnimationRetargetNodeScript = preload("res://core/models/combat_animation_retarget_node.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const DEFAULT_PIVOT_RATIO_FROM_POMMEL := 0.5
const DEFAULT_ORIGIN_SPACE: StringName = &"primary_shoulder"
const DEFAULT_LENGTH_EPSILON_METERS := 0.001

func build_retarget_node_from_legacy_motion_node(
	motion_node,
	volume_config: Dictionary = {}
):
	if motion_node == null:
		return null
	var retarget_node = CombatAnimationRetargetNodeScript.new()
	var pivot_ratio: float = clampf(
		float(volume_config.get("pivot_ratio_from_pommel", DEFAULT_PIVOT_RATIO_FROM_POMMEL)),
		0.0,
		1.0
	)
	var origin_local: Vector3 = volume_config.get("origin_local", Vector3.ZERO) as Vector3
	var min_radius: float = maxf(float(volume_config.get("min_radius_meters", 0.0)), 0.0)
	var max_radius: float = maxf(float(volume_config.get("max_radius_meters", 0.0)), min_radius)
	var pivot_position: Vector3 = motion_node.pommel_position_local.lerp(motion_node.tip_position_local, pivot_ratio)
	var origin_to_pivot: Vector3 = pivot_position - origin_local
	var distance: float = origin_to_pivot.length()
	var range_span: float = maxf(max_radius - min_radius, 0.000001)
	var curve_scale: float = _resolve_curve_handle_scale(range_span)
	var segment_axis: Vector3 = motion_node.tip_position_local - motion_node.pommel_position_local
	retarget_node.enabled = true
	retarget_node.origin_space = StringName(volume_config.get("origin_space", DEFAULT_ORIGIN_SPACE))
	retarget_node.pivot_direction_local = _resolve_safe_direction(origin_to_pivot, segment_axis)
	retarget_node.pivot_range_percent = clampf((distance - min_radius) / range_span, 0.0, 1.0)
	retarget_node.pivot_ratio_from_pommel = pivot_ratio
	retarget_node.weapon_axis_local = _resolve_safe_direction(segment_axis, retarget_node.pivot_direction_local)
	retarget_node.weapon_orientation_degrees = motion_node.weapon_orientation_degrees
	retarget_node.weapon_orientation_authored = motion_node.weapon_orientation_authored
	retarget_node.weapon_roll_degrees = motion_node.weapon_roll_degrees
	retarget_node.axial_reposition_offset = motion_node.axial_reposition_offset
	retarget_node.grip_seat_slide_offset = motion_node.grip_seat_slide_offset
	retarget_node.body_support_blend = motion_node.body_support_blend
	retarget_node.right_upperarm_roll_degrees = motion_node.right_upperarm_roll_degrees
	retarget_node.left_upperarm_roll_degrees = motion_node.left_upperarm_roll_degrees
	retarget_node.transition_duration_seconds = motion_node.transition_duration_seconds
	retarget_node.preferred_grip_style_mode = motion_node.preferred_grip_style_mode
	retarget_node.two_hand_state = motion_node.two_hand_state
	retarget_node.primary_hand_slot = motion_node.primary_hand_slot
	retarget_node.source_weapon_length_meters = motion_node.tip_position_local.distance_to(motion_node.pommel_position_local)
	retarget_node.source_min_radius_meters = min_radius
	retarget_node.source_max_radius_meters = max_radius
	retarget_node.tip_curve_in_normalized = _normalize_curve_handle(motion_node.tip_curve_in_handle, curve_scale)
	retarget_node.tip_curve_out_normalized = _normalize_curve_handle(motion_node.tip_curve_out_handle, curve_scale)
	retarget_node.pommel_curve_in_normalized = _normalize_curve_handle(motion_node.pommel_curve_in_handle, curve_scale)
	retarget_node.pommel_curve_out_normalized = _normalize_curve_handle(motion_node.pommel_curve_out_handle, curve_scale)
	retarget_node.normalize()
	return retarget_node

func resolve_motion_values_from_retarget_node(
	retarget_node,
	current_weapon_length_meters: float,
	volume_config: Dictionary = {}
) -> Dictionary:
	if retarget_node == null:
		return {}
	retarget_node.normalize()
	var origin_local: Vector3 = volume_config.get("origin_local", Vector3.ZERO) as Vector3
	var min_radius: float = maxf(float(volume_config.get("min_radius_meters", retarget_node.source_min_radius_meters)), 0.0)
	var max_radius: float = maxf(float(volume_config.get("max_radius_meters", retarget_node.source_max_radius_meters)), min_radius)
	var range_span: float = maxf(max_radius - min_radius, 0.0)
	var curve_scale: float = _resolve_curve_handle_scale(range_span)
	var radius: float = min_radius + range_span * clampf(retarget_node.pivot_range_percent, 0.0, 1.0)
	var pivot_position: Vector3 = origin_local + retarget_node.pivot_direction_local.normalized() * radius
	var weapon_length: float = current_weapon_length_meters
	if weapon_length <= 0.00001:
		weapon_length = retarget_node.source_weapon_length_meters
	var pivot_ratio: float = clampf(retarget_node.pivot_ratio_from_pommel, 0.0, 1.0)
	var axis: Vector3 = _resolve_safe_direction(retarget_node.weapon_axis_local, retarget_node.pivot_direction_local)
	var pommel_position: Vector3 = pivot_position - axis * weapon_length * pivot_ratio
	var tip_position: Vector3 = pivot_position + axis * weapon_length * (1.0 - pivot_ratio)
	return {
		"tip_position_local": tip_position,
		"pommel_position_local": pommel_position,
		"retarget_resolved": true,
		"origin_space": retarget_node.origin_space,
		"pivot_position_local": pivot_position,
		"pivot_range_percent": retarget_node.pivot_range_percent,
		"pivot_ratio_from_pommel": pivot_ratio,
		"weapon_orientation_degrees": retarget_node.weapon_orientation_degrees,
		"weapon_orientation_authored": retarget_node.weapon_orientation_authored,
		"weapon_roll_degrees": retarget_node.weapon_roll_degrees,
		"axial_reposition_offset": retarget_node.axial_reposition_offset,
		"grip_seat_slide_offset": retarget_node.grip_seat_slide_offset,
		"body_support_blend": retarget_node.body_support_blend,
		"right_upperarm_roll_degrees": retarget_node.right_upperarm_roll_degrees,
		"left_upperarm_roll_degrees": retarget_node.left_upperarm_roll_degrees,
		"transition_duration_seconds": retarget_node.transition_duration_seconds,
		"preferred_grip_style_mode": retarget_node.preferred_grip_style_mode,
		"two_hand_state": retarget_node.two_hand_state,
		"primary_hand_slot": retarget_node.primary_hand_slot,
		"tip_curve_in_handle": retarget_node.tip_curve_in_normalized * curve_scale,
		"tip_curve_out_handle": retarget_node.tip_curve_out_normalized * curve_scale,
		"pommel_curve_in_handle": retarget_node.pommel_curve_in_normalized * curve_scale,
		"pommel_curve_out_handle": retarget_node.pommel_curve_out_normalized * curve_scale,
	}

func apply_retarget_node_to_motion_node(
	motion_node,
	retarget_node,
	current_weapon_length_meters: float,
	volume_config: Dictionary = {}
) -> bool:
	if motion_node == null or retarget_node == null:
		return false
	var resolved_values: Dictionary = resolve_motion_values_from_retarget_node(
		retarget_node,
		current_weapon_length_meters,
		volume_config
	)
	if resolved_values.is_empty():
		return false
	motion_node.tip_position_local = resolved_values.get("tip_position_local", motion_node.tip_position_local) as Vector3
	motion_node.pommel_position_local = resolved_values.get("pommel_position_local", motion_node.pommel_position_local) as Vector3
	motion_node.weapon_orientation_degrees = resolved_values.get("weapon_orientation_degrees", motion_node.weapon_orientation_degrees) as Vector3
	motion_node.weapon_orientation_authored = bool(resolved_values.get("weapon_orientation_authored", motion_node.weapon_orientation_authored))
	motion_node.weapon_roll_degrees = float(resolved_values.get("weapon_roll_degrees", motion_node.weapon_roll_degrees))
	motion_node.axial_reposition_offset = float(resolved_values.get("axial_reposition_offset", motion_node.axial_reposition_offset))
	motion_node.grip_seat_slide_offset = float(resolved_values.get("grip_seat_slide_offset", motion_node.grip_seat_slide_offset))
	motion_node.body_support_blend = float(resolved_values.get("body_support_blend", motion_node.body_support_blend))
	motion_node.right_upperarm_roll_degrees = float(resolved_values.get("right_upperarm_roll_degrees", motion_node.right_upperarm_roll_degrees))
	motion_node.left_upperarm_roll_degrees = float(resolved_values.get("left_upperarm_roll_degrees", motion_node.left_upperarm_roll_degrees))
	motion_node.transition_duration_seconds = float(resolved_values.get("transition_duration_seconds", motion_node.transition_duration_seconds))
	motion_node.preferred_grip_style_mode = StringName(resolved_values.get("preferred_grip_style_mode", motion_node.preferred_grip_style_mode))
	motion_node.two_hand_state = StringName(resolved_values.get("two_hand_state", motion_node.two_hand_state))
	motion_node.primary_hand_slot = CombatAnimationMotionNodeScript.normalize_primary_hand_slot(StringName(resolved_values.get("primary_hand_slot", motion_node.primary_hand_slot)))
	motion_node.retarget_node = retarget_node
	motion_node.normalize()
	return true

func seed_missing_retarget_nodes_for_motion_chain(
	motion_node_chain: Array,
	volume_config: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		"changed": false,
		"seeded_count": 0,
		"node_count": motion_node_chain.size(),
	}
	for node_variant: Variant in motion_node_chain:
		var motion_node = node_variant
		if motion_node == null:
			continue
		if motion_node.retarget_node != null:
			continue
		var node_config: Dictionary = _build_node_safe_volume_config(motion_node, volume_config)
		var retarget_node = build_retarget_node_from_legacy_motion_node(motion_node, node_config)
		if retarget_node == null:
			continue
		motion_node.retarget_node = retarget_node
		if motion_node.has_method("normalize"):
			motion_node.call("normalize")
		result["changed"] = true
		result["seeded_count"] = int(result.get("seeded_count", 0)) + 1
	return result

func retarget_motion_chain_for_weapon_length(
	motion_node_chain: Array,
	current_weapon_length_meters: float,
	volume_config: Dictionary = {},
	length_epsilon_meters: float = DEFAULT_LENGTH_EPSILON_METERS,
	seed_missing: bool = true
) -> Dictionary:
	var result: Dictionary = {
		"changed": false,
		"seeded_count": 0,
		"retargeted_count": 0,
		"endpoint_changed_count": 0,
		"node_count": motion_node_chain.size(),
		"current_weapon_length_meters": maxf(current_weapon_length_meters, 0.0),
	}
	for node_variant: Variant in motion_node_chain:
		var motion_node = node_variant
		if motion_node == null:
			continue
		var retarget_node = motion_node.retarget_node
		var node_config: Dictionary = _build_node_safe_volume_config(motion_node, volume_config)
		if retarget_node == null and seed_missing:
			retarget_node = build_retarget_node_from_legacy_motion_node(motion_node, node_config)
			if retarget_node != null:
				motion_node.retarget_node = retarget_node
				result["changed"] = true
				result["seeded_count"] = int(result.get("seeded_count", 0)) + 1
		if retarget_node == null:
			continue
		var source_length: float = maxf(float(retarget_node.source_weapon_length_meters), 0.0)
		var target_length: float = maxf(current_weapon_length_meters, 0.0)
		if target_length <= length_epsilon_meters:
			target_length = source_length
		if target_length <= length_epsilon_meters:
			continue
		var current_segment_length: float = motion_node.tip_position_local.distance_to(motion_node.pommel_position_local)
		var length_changed: bool = absf(source_length - target_length) > length_epsilon_meters
		var endpoint_length_stale: bool = absf(current_segment_length - target_length) > length_epsilon_meters
		if not length_changed and not endpoint_length_stale:
			continue
		var tip_before: Vector3 = motion_node.tip_position_local
		var pommel_before: Vector3 = motion_node.pommel_position_local
		if apply_retarget_node_to_motion_node(motion_node, retarget_node, target_length, node_config):
			result["changed"] = true
			result["retargeted_count"] = int(result.get("retargeted_count", 0)) + 1
			if (
				not motion_node.tip_position_local.is_equal_approx(tip_before)
				or not motion_node.pommel_position_local.is_equal_approx(pommel_before)
			):
				result["endpoint_changed_count"] = int(result.get("endpoint_changed_count", 0)) + 1
	return result

func refresh_motion_chain_retarget_authoring_snapshot(
	motion_node_chain: Array,
	volume_config: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		"changed": false,
		"refreshed_count": 0,
		"node_count": motion_node_chain.size(),
	}
	for node_variant: Variant in motion_node_chain:
		var motion_node = node_variant
		if motion_node == null:
			continue
		var node_config: Dictionary = _build_node_safe_volume_config(motion_node, volume_config)
		var retarget_node = build_retarget_node_from_legacy_motion_node(motion_node, node_config)
		if retarget_node == null:
			continue
		motion_node.retarget_node = retarget_node
		if motion_node.has_method("normalize"):
			motion_node.call("normalize")
		result["changed"] = true
		result["refreshed_count"] = int(result.get("refreshed_count", 0)) + 1
	return result

func retarget_draft_for_weapon_length(
	draft,
	current_weapon_length_meters: float,
	volume_config: Dictionary = {},
	length_epsilon_meters: float = DEFAULT_LENGTH_EPSILON_METERS,
	seed_missing: bool = true
) -> Dictionary:
	if draft == null:
		return {}
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	var result: Dictionary = retarget_motion_chain_for_weapon_length(
		motion_node_chain,
		current_weapon_length_meters,
		volume_config,
		length_epsilon_meters,
		seed_missing
	)
	if bool(result.get("changed", false)) and draft.has_method("normalize"):
		draft.call("normalize")
	return result

func refresh_draft_retarget_authoring_snapshot(
	draft,
	volume_config: Dictionary = {}
) -> Dictionary:
	if draft == null:
		return {}
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	var result: Dictionary = refresh_motion_chain_retarget_authoring_snapshot(motion_node_chain, volume_config)
	if bool(result.get("changed", false)) and draft.has_method("normalize"):
		draft.call("normalize")
	return result

func _resolve_safe_direction(primary: Vector3, fallback: Vector3) -> Vector3:
	if primary.length_squared() > 0.000001:
		return primary.normalized()
	if fallback.length_squared() > 0.000001:
		return fallback.normalized()
	return Vector3.FORWARD

func _normalize_curve_handle(handle: Vector3, curve_scale: float) -> Vector3:
	return handle / maxf(curve_scale, 0.000001)

func _resolve_curve_handle_scale(range_span: float) -> float:
	return maxf(range_span, 1.0)

func _build_node_safe_volume_config(motion_node, volume_config: Dictionary) -> Dictionary:
	var config: Dictionary = volume_config.duplicate(true)
	if not config.has("origin_space"):
		config["origin_space"] = DEFAULT_ORIGIN_SPACE
	if not config.has("origin_local"):
		config["origin_local"] = Vector3.ZERO
	if not config.has("pivot_ratio_from_pommel"):
		config["pivot_ratio_from_pommel"] = DEFAULT_PIVOT_RATIO_FROM_POMMEL
	var pivot_ratio: float = clampf(
		float(config.get("pivot_ratio_from_pommel", DEFAULT_PIVOT_RATIO_FROM_POMMEL)),
		0.0,
		1.0
	)
	var origin_local: Vector3 = config.get("origin_local", Vector3.ZERO) as Vector3
	var pivot_position: Vector3 = motion_node.pommel_position_local.lerp(motion_node.tip_position_local, pivot_ratio)
	var distance_to_origin: float = pivot_position.distance_to(origin_local)
	var segment_length: float = motion_node.tip_position_local.distance_to(motion_node.pommel_position_local)
	if not config.has("min_radius_meters"):
		config["min_radius_meters"] = 0.0
	if not config.has("max_radius_meters") or float(config.get("max_radius_meters", 0.0)) <= 0.0:
		var fallback_max: float = maxf(1.0, distance_to_origin)
		fallback_max = maxf(fallback_max, distance_to_origin + segment_length)
		fallback_max = maxf(fallback_max, segment_length * 3.0)
		config["max_radius_meters"] = fallback_max
	return config
