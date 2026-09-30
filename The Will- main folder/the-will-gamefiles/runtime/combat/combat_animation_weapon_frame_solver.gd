extends RefCounted
class_name CombatAnimationWeaponFrameSolver

const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")

## Clean weapon-frame solve for the Skill Crafter rebuild.
## The authored segment owns weapon placement; no separate helper surface is
## part of this authority path.

## Encode a realized weapon frame through the same segment representation used
## by authoring. This is an inverse conversion, not a pose or limit policy.
func encode_transform_for_authoring(
	target: Transform3D,
	local_tip: Vector3,
	local_pommel: Vector3,
	local_up_reference: Vector3,
	trajectory_world: Transform3D,
	roll_degrees: float,
	weapon_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
) -> Dictionary:
	if weapon_origin_id != CombatOriginRecordScript.ORIGIN_WEAPON_ROOT:
		return {"available": false, "reason": "invalid_weapon_frame_origin"}
	if not target.is_finite() or not trajectory_world.is_finite() or not local_tip.is_finite() or not local_pommel.is_finite() or not local_up_reference.is_finite() or not is_finite(roll_degrees):
		return {"available": false, "reason": "non_finite_authoring_frame"}
	if absf(target.basis.determinant()) < 0.00000001 or absf(trajectory_world.basis.determinant()) < 0.00000001:
		return {"available": false, "reason": "non_invertible_authoring_frame"}
	if local_tip.distance_squared_to(local_pommel) <= 0.00000001:
		return {"available": false, "reason": "degenerate_weapon_segment"}
	var local_axis: Vector3 = (local_tip - local_pommel).normalized()
	# Retain the existing segment solver's fallback for a collinear up reference.
	var intrinsic: Basis = _build_basis_from_axis_and_up(local_axis, local_up_reference)
	var output_basis: Basis = target.basis * intrinsic
	var unrolled_up_world: Vector3 = output_basis.y.rotated(output_basis.z.normalized(), -deg_to_rad(roll_degrees))
	var up_in_trajectory: Vector3 = trajectory_world.basis.inverse() * unrolled_up_world
	if not up_in_trajectory.is_finite() or up_in_trajectory.length_squared() <= 0.00000001:
		return {"available": false, "reason": "invalid_authoring_up_reference"}
	var world_to_trajectory: Transform3D = trajectory_world.affine_inverse()
	var encoded := {
		"available": true,
		"tip_position_local": world_to_trajectory * (target * local_tip),
		"pommel_position_local": world_to_trajectory * (target * local_pommel),
		"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"weapon_orientation_degrees": Quaternion(Vector3.UP, up_in_trajectory.normalized()).get_euler() * (180.0 / PI),
		"weapon_orientation_authored": true,
		"weapon_roll_degrees": roll_degrees,
	}
	var reconstructed: Transform3D = solve_transform_from_segment(
		local_tip, local_pommel,
		trajectory_world * (encoded.tip_position_local as Vector3),
		trajectory_world * (encoded.pommel_position_local as Vector3),
		local_up_reference, trajectory_world.basis,
		encoded.weapon_orientation_degrees, roll_degrees,
		weapon_origin_id, weapon_origin_id, weapon_origin_id
	)
	if not reconstructed.is_equal_approx(target) or (reconstructed * local_tip).distance_to(target * local_tip) > 0.00001 or (reconstructed * local_pommel).distance_to(target * local_pommel) > 0.00001:
		return {"available": false, "reason": "authored_frame_roundtrip_failed"}
	return encoded


func solve_transform_from_segment(
	local_tip: Vector3,
	local_pommel: Vector3,
	authored_tip_world: Vector3,
	authored_pommel_world: Vector3,
	local_up_reference: Vector3,
	authoring_root_basis: Basis,
	weapon_orientation_degrees: Vector3,
	weapon_roll_degrees: float,
	tip_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
	pommel_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
	up_reference_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
) -> Transform3D:
	_validate_weapon_frame_origin_ids(tip_origin_id, pommel_origin_id, up_reference_origin_id)
	var local_axis: Vector3 = _resolve_safe_axis(local_tip - local_pommel, Vector3.FORWARD)
	var world_axis: Vector3 = _resolve_safe_axis(authored_tip_world - authored_pommel_world, authoring_root_basis.z.normalized())
	var local_basis: Basis = _build_basis_from_axis_and_up(local_axis, local_up_reference)
	var orientation_rad: Vector3 = weapon_orientation_degrees * (PI / 180.0)
	var oriented_basis_world: Basis = authoring_root_basis * Basis.from_euler(orientation_rad)
	var world_up_reference: Vector3 = oriented_basis_world * Vector3.UP
	if absf(world_up_reference.normalized().dot(world_axis)) > 0.999:
		world_up_reference = authoring_root_basis * Vector3.UP
	world_up_reference = world_up_reference.rotated(world_axis, deg_to_rad(weapon_roll_degrees))
	var world_basis: Basis = _build_basis_from_axis_and_up(world_axis, world_up_reference)
	var solved_basis: Basis = (world_basis * local_basis.inverse()).orthonormalized()
	var solved_origin: Vector3 = authored_pommel_world - solved_basis * local_pommel
	return Transform3D(solved_basis, solved_origin)

func solve_transform_from_tip_and_grip(
	local_tip: Vector3,
	local_grip: Vector3,
	authored_tip_world: Vector3,
	authored_grip_world: Vector3,
	local_up_reference: Vector3,
	authoring_root_basis: Basis,
	weapon_orientation_degrees: Vector3,
	weapon_roll_degrees: float,
	tip_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
	grip_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
	up_reference_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
) -> Transform3D:
	_validate_weapon_frame_origin_ids(tip_origin_id, grip_origin_id, up_reference_origin_id)
	var local_axis: Vector3 = _resolve_safe_axis(local_tip - local_grip, Vector3.FORWARD)
	var world_axis: Vector3 = _resolve_safe_axis(authored_tip_world - authored_grip_world, authoring_root_basis.z.normalized())
	var local_basis: Basis = _build_basis_from_axis_and_up(local_axis, local_up_reference)
	var orientation_rad: Vector3 = weapon_orientation_degrees * (PI / 180.0)
	var oriented_basis_world: Basis = authoring_root_basis * Basis.from_euler(orientation_rad)
	var world_up_reference: Vector3 = oriented_basis_world * Vector3.UP
	if absf(world_up_reference.normalized().dot(world_axis)) > 0.999:
		world_up_reference = authoring_root_basis * Vector3.UP
	world_up_reference = world_up_reference.rotated(world_axis, deg_to_rad(weapon_roll_degrees))
	var world_basis: Basis = _build_basis_from_axis_and_up(world_axis, world_up_reference)
	var solved_basis: Basis = (world_basis * local_basis.inverse()).orthonormalized()
	var solved_origin: Vector3 = authored_grip_world - solved_basis * local_grip
	return Transform3D(solved_basis, solved_origin)

func _validate_weapon_frame_origin_ids(
	first_origin_id: StringName,
	second_origin_id: StringName,
	up_reference_origin_id: StringName
) -> void:
	_normalize_weapon_frame_origin_id(first_origin_id)
	_normalize_weapon_frame_origin_id(second_origin_id)
	_normalize_weapon_frame_origin_id(up_reference_origin_id)

func _normalize_weapon_frame_origin_id(origin_id: StringName) -> StringName:
	if origin_id != StringName():
		return origin_id
	return CombatOriginRecordScript.ORIGIN_WEAPON_ROOT

func _resolve_safe_axis(axis: Vector3, fallback: Vector3) -> Vector3:
	if axis.length_squared() > 0.000001:
		return axis.normalized()
	if fallback.length_squared() > 0.000001:
		return fallback.normalized()
	return Vector3.FORWARD

func _build_basis_from_axis_and_up(axis: Vector3, up_reference: Vector3) -> Basis:
	var forward: Vector3 = _resolve_safe_axis(axis, Vector3.FORWARD)
	var projected_up: Vector3 = up_reference - forward * up_reference.dot(forward)
	if projected_up.length_squared() <= 0.000001:
		projected_up = Vector3.UP - forward * Vector3.UP.dot(forward)
	if projected_up.length_squared() <= 0.000001:
		projected_up = Vector3.RIGHT - forward * Vector3.RIGHT.dot(forward)
	projected_up = projected_up.normalized()
	var right: Vector3 = projected_up.cross(forward).normalized()
	var up: Vector3 = forward.cross(right).normalized()
	return Basis(right, up, forward).orthonormalized()
