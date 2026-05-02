extends RefCounted
class_name CombatAnimationWeaponFrameSolver

## Clean weapon-frame solve for the Skill Crafter rebuild.
## The authored segment owns weapon placement; no separate helper surface is
## part of this authority path.

func solve_transform_from_segment(
	local_tip: Vector3,
	local_pommel: Vector3,
	authored_tip_world: Vector3,
	authored_pommel_world: Vector3,
	local_up_reference: Vector3,
	authoring_root_basis: Basis,
	weapon_orientation_degrees: Vector3,
	weapon_roll_degrees: float
) -> Transform3D:
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
	weapon_roll_degrees: float
) -> Transform3D:
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
