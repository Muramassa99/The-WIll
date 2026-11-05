extends RefCounted
class_name CombatForearmHandIndexResolver

## Deform the visible forearm from an ALREADY ACCEPTED semantic forearm roll.
## All input frames share one reference. Helpers are a serial sibling branch of
## Hand: Forearm -> proximal -> distal, while Hand is a child of Forearm.
const REVISION := "forearm_roll_distribution_v2"
const AXIS_EPSILON_SQUARED := 1.0e-12

static func resolve(
	_forearm: Transform3D, _hand: Transform3D,
	_proximal_rest: Basis, _distal_rest: Basis, _hand_rest: Basis,
	_proximal_neutral: Quaternion, _distal_neutral: Quaternion,
	_total_limit_radians: float, _epsilon_radians: float
) -> Dictionary:
	# Old diagnostics can report the obsolete contract explicitly. Production
	# must never infer forearm pronation from a bent Hand's generic twist.
	return _fail("semantic_wrist_model_required")

static func distribute(
	forearm: Transform3D, hand: Transform3D,
	proximal_rest: Basis, distal_rest: Basis, hand_rest: Basis,
	total_limit_radians: float, epsilon_radians: float, accepted_roll_radians: float
) -> Dictionary:
	if not forearm.is_finite() or not hand.is_finite() or not _supported_basis(hand.basis):
		return _fail("forearm_hand_index_invalid_frame")
	if not is_finite(total_limit_radians) or not is_finite(epsilon_radians) or minf(total_limit_radians, epsilon_radians) < 0.0:
		return _fail("forearm_hand_index_invalid_limit")
	for basis: Basis in [forearm.basis, proximal_rest, distal_rest, hand_rest]:
		if not _supported_basis(basis):
			return _fail("forearm_hand_index_unsupported_basis")
	# Semantic rho is measured from imported rest, so the deformation branch
	# must use the same zero. A previously posed/Reset helper is not calibration.
	var proximal_neutral := proximal_rest.orthonormalized().get_rotation_quaternion()
	var distal_neutral := distal_rest.orthonormalized().get_rotation_quaternion()
	var axis := hand.origin - forearm.origin
	if axis.length_squared() <= AXIS_EPSILON_SQUARED:
		return _fail("forearm_hand_index_zero_axis")
	axis = axis.normalized()
	if not is_finite(accepted_roll_radians):
		return _fail("invalid_accepted_forearm_roll")
	var requested: float = accepted_roll_radians
	var half_angle := requested * 0.5
	var per_helper_limit := total_limit_radians * 0.5
	var diagnostics := {"revision": REVISION, "requested_radians": requested,
		"per_helper_requested_radians": half_angle, "per_helper_limit_radians": per_helper_limit,
		"axis_reference": axis, "main_bone_writes": 0, "hand_writes": 0}
	if absf(half_angle) > per_helper_limit + epsilon_radians:
		return _fail("forearm_hand_index_range").merged({"requested_radians": requested, "diagnostics": diagnostics})
	var forearm_basis := forearm.basis.orthonormalized()
	var proximal_base := forearm_basis * Basis(proximal_neutral.normalized())
	var distal_base := proximal_base * Basis(distal_neutral.normalized())
	# Desired cumulative helper rotations are half/full of the accepted axial
	# request. Convert each through its actual desired parent, not a world axis.
	var proximal_target := Basis(axis, half_angle) * proximal_base
	var distal_target := Basis(axis, requested) * distal_base
	var proximal_rotation := (forearm_basis.inverse() * proximal_target).orthonormalized().get_rotation_quaternion().normalized()
	var distal_rotation := (proximal_target.inverse() * distal_target).orthonormalized().get_rotation_quaternion().normalized()
	var proximal_delta := (proximal_neutral.normalized().inverse() * proximal_rotation).normalized()
	var distal_delta := (distal_neutral.normalized().inverse() * distal_rotation).normalized()
	diagnostics["proximal_local_angle_radians"] = _rotation_angle(proximal_delta)
	diagnostics["distal_local_angle_radians"] = _rotation_angle(distal_delta)
	if maxf(diagnostics.proximal_local_angle_radians, diagnostics.distal_local_angle_radians) > per_helper_limit + epsilon_radians:
		return _fail("forearm_hand_index_range").merged({"requested_radians": requested, "diagnostics": diagnostics})
	diagnostics["roll_source"] = "accepted_semantic_forearm_state"
	return {"valid": true, "reason": "", "proximal_rotation": proximal_rotation,
		"distal_rotation": distal_rotation, "requested_radians": requested, "diagnostics": diagnostics}

## Stable neutral for both indexing and input limits. Current helper rotations
## deliberately do not participate; moving them must not move the allowed window.
static func neutral_hand_basis(
	forearm: Basis, proximal_rest: Basis, distal_rest: Basis, hand_rest: Basis,
	proximal_neutral: Quaternion, distal_neutral: Quaternion
) -> Dictionary:
	for basis: Basis in [forearm, proximal_rest, distal_rest, hand_rest]:
		if not _supported_basis(basis):
			return _fail("forearm_hand_index_unsupported_basis")
	for rotation: Quaternion in [proximal_neutral, distal_neutral]:
		if not rotation.is_finite() or rotation.length_squared() <= AXIS_EPSILON_SQUARED:
			return _fail("forearm_hand_index_invalid_neutral")
	# This is the existing imported distal-helper -> neutral-Hand Skin mapping.
	var skin_calibration := (proximal_rest.orthonormalized() * distal_rest.orthonormalized()).inverse() * hand_rest.orthonormalized()
	var basis := forearm.orthonormalized() * Basis(proximal_neutral.normalized()) * Basis(distal_neutral.normalized()) * skin_calibration
	return {"valid": true, "reason": "", "basis": basis.orthonormalized(), "skin_calibration": skin_calibration}

static func _twist(rotation: Quaternion, axis: Vector3) -> Dictionary:
	var component := Vector3(rotation.x, rotation.y, rotation.z).dot(axis)
	if component * component + rotation.w * rotation.w <= AXIS_EPSILON_SQUARED:
		return {"valid": false}
	var angle := wrapf(2.0 * atan2(component, rotation.w), -PI, PI)
	return {"valid": true, "angle": angle, "rotation": Quaternion(axis, angle)}

static func _rotation_angle(rotation: Quaternion) -> float:
	return 2.0 * atan2(Vector3(rotation.x, rotation.y, rotation.z).length(), absf(rotation.w))

static func _supported_basis(basis: Basis) -> bool:
	if not basis.is_finite() or basis.determinant() <= 1.0e-9:
		return false
	var scale := basis.get_scale()
	if not is_equal_approx(scale.x, scale.y) or not is_equal_approx(scale.x, scale.z):
		return false
	var x := basis.x.normalized()
	var y := basis.y.normalized()
	var z := basis.z.normalized()
	return maxf(absf(x.dot(y)), maxf(absf(x.dot(z)), absf(y.dot(z)))) <= 0.00001

static func _fail(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
