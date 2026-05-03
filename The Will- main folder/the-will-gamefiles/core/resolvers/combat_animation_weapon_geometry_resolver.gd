extends RefCounted
class_name CombatAnimationWeaponGeometryResolver

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")

var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE

func _init(rules: ForgeRulesDef = null) -> void:
	forge_rules = rules if rules != null else DEFAULT_FORGE_RULES_RESOURCE

func resolve_motion_seed_data(baked_profile: BakedProfile) -> Dictionary:
	if baked_profile == null or not baked_profile.primary_grip_valid:
		return {}
	var grip_origin_local: Vector3 = baked_profile.primary_grip_contact_position
	var tip_point_local: Vector3 = baked_profile.weapon_tip_point
	var pommel_point_local: Vector3 = baked_profile.weapon_pommel_point
	if tip_point_local.is_equal_approx(pommel_point_local):
		return {}
	var cell_world_size_meters: float = maxf(forge_rules.cell_world_size_meters, 0.0001)
	var tip_position_local: Vector3 = (tip_point_local - grip_origin_local) * cell_world_size_meters
	var pommel_position_local: Vector3 = (pommel_point_local - grip_origin_local) * cell_world_size_meters
	var weapon_total_length_meters: float = baked_profile.weapon_total_length_meters
	if weapon_total_length_meters <= 0.0001:
		weapon_total_length_meters = tip_position_local.distance_to(pommel_position_local)
	var weapon_orientation_degrees: Vector3 = _resolve_default_weapon_orientation_degrees(
		baked_profile.primary_grip_slide_axis
	)
	return {
		"tip_position_local": tip_position_local,
		"pommel_position_local": pommel_position_local,
		"weapon_total_length_meters": weapon_total_length_meters,
		"weapon_orientation_degrees": weapon_orientation_degrees,
		"weapon_orientation_authored": false,
		"weapon_roll_degrees": 0.0,
		"axial_reposition_offset": 0.0,
		"grip_seat_slide_offset": CombatAnimationMotionNode.DEFAULT_GRIP_SEAT_SLIDE_OFFSET,
		"body_support_blend": 0.4,
		"grip_axis_local": baked_profile.primary_grip_slide_axis.normalized(),
	}

func _resolve_default_weapon_orientation_degrees(grip_axis: Vector3) -> Vector3:
	if grip_axis.length_squared() < 0.000001:
		return Vector3.ZERO
	var normalized_grip_axis: Vector3 = grip_axis.normalized()
	var up_axis: Vector3 = Vector3.UP
	if absf(normalized_grip_axis.dot(up_axis)) > 0.99:
		up_axis = Vector3.FORWARD
	var plane_normal: Vector3 = normalized_grip_axis.cross(up_axis).normalized()
	if plane_normal.length_squared() < 0.000001:
		return Vector3.ZERO
	var basis_from_normal: Basis = Basis.looking_at(plane_normal, up_axis)
	var euler_degrees: Vector3 = basis_from_normal.get_euler() * (180.0 / PI)
	return Vector3(
		snapped(euler_degrees.x, 0.1),
		snapped(euler_degrees.y, 0.1),
		snapped(euler_degrees.z, 0.1)
	)
