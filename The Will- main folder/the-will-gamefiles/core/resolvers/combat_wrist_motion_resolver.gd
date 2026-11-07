extends RefCounted
class_name CombatWristMotionResolver

## Three semantic controls, one owner per motion: forearm rho, wrist beta/gamma.
## All input frames share a reference and the upstream wrist position is final.
## No IK, scene writes, mutable calibration, or inferred twist from a bent Hand.
const REVISION := "semantic_forearm_wrist_v1"
const Profile = preload("res://core/defs/wrist_motion_profile_def.gd")
const ForearmRotation = preload("res://core/resolvers/combat_forearm_rotation_resolver.gd")
const AXIS_EPSILON_SQUARED := 1.0e-12
const ROOT_EPSILON := 1.0e-8
# Vector3 stores float32 components; exact endpoint constants round on assignment.
# These only cover arithmetic precision, not extra authored wrist range.
const SCALAR_EPSILON := 1.0e-6
const ENVELOPE_EPSILON := 1.0e-6
const ERROR_TIE_RADIANS := 1.0e-7
const REFINEMENT_STEPS := 16

static func resolve(forearm_reference: Transform3D, requested_hand: Transform3D, calibration: Dictionary, profile: Dictionary, previous_state: Dictionary = {}, elbow_bend_radians: float = NAN, full_flexion_radians: float = deg_to_rad(160.0)) -> Dictionary:
	var context := _context(forearm_reference, requested_hand, calibration, profile, elbow_bend_radians, full_flexion_radians)
	if not context.valid:
		return context
	profile = context.limits_profile
	var prior := _project(_state_vector(previous_state), profile)
	var candidates: Array[Vector3] = [prior, Vector3.ZERO]
	var axis: Vector3 = context.axis
	var neutral: Basis = context.neutral
	var target: Basis = context.target_anatomical
	var n: Vector3 = neutral.x
	var v: Vector3 = target.z
	# Rx(beta)Rz(theta) has row-X/column-Z == 0. Removing rho gives
	# A*cos(rho)+B*sin(rho)+C == 0, including a shaft not parallel to palm Y.
	var c: float = n.dot(axis) * axis.dot(v)
	var a: float = n.dot(v) - c
	var b: float = -n.dot(axis.cross(v))
	var magnitude: float = sqrt(a * a + b * b)
	var rho_seeds: Array[float] = [prior.x, clampf(0.0, profile.forearm_min_radians, profile.forearm_max_radians), float(profile.forearm_min_radians), float(profile.forearm_max_radians)]
	var analytic_roots := 0
	if magnitude > ROOT_EPSILON and absf(c) <= magnitude + ROOT_EPSILON:
		var phase := atan2(b, a)
		var separation := acos(clampf(-c / magnitude, -1.0, 1.0))
		for root: float in [phase - separation, phase + separation]:
			rho_seeds.append(wrapf(root, -PI, PI))
			analytic_roots += 1
	for step: int in 7:
		rho_seeds.append(lerpf(profile.forearm_min_radians, profile.forearm_max_radians, float(step) / 6.0))
	for rho: float in rho_seeds:
		var local: Basis = (Basis(axis, rho) * neutral).transposed() * target
		var beta := atan2(-local.z.y, local.z.z)
		var gamma: float = float(context.radial_sign) * atan2(-local.y.x, local.x.x)
		candidates.append(_project(Vector3(rho, beta, gamma), profile))
	var best := _best(candidates, context, profile, prior)
	# Exact analytic solutions normally finish here. Invalid targets receive a
	# bounded closest-candidate search, not an unconstrained body compensation.
	if float(best.error) > float(profile.orientation_tolerance_radians):
		var boundary: Array[Vector3] = []
		for rho: float in [prior.x, clampf(0.0, profile.forearm_min_radians, profile.forearm_max_radians), float(profile.forearm_min_radians), float(profile.forearm_max_radians)]:
			for step: int in 16:
				var angle := TAU * float(step) / 16.0
				var beta: float = cos(angle) * (float(profile.extension_limit_radians) if cos(angle) >= 0.0 else float(profile.flexion_limit_radians))
				var gamma: float = sin(angle) * (float(profile.radial_limit_radians) if sin(angle) >= 0.0 else float(profile.ulnar_limit_radians))
				boundary.append(Vector3(rho, beta, gamma))
		boundary.append(best.state)
		best = _best(boundary, context, profile, prior)
		var steps := Vector3(deg_to_rad(15.0), deg_to_rad(10.0), deg_to_rad(5.0))
		for iteration: int in REFINEMENT_STEPS:
			var local_candidates: Array[Vector3] = [best.state]
			for coordinate: int in 3:
				for direction: float in [-1.0, 1.0]:
					var candidate: Vector3 = best.state
					candidate[coordinate] += steps[coordinate] * direction
					local_candidates.append(_project(candidate, profile))
			var refined := _best(local_candidates, context, profile, prior)
			if float(refined.error) >= float(best.error) - ERROR_TIE_RADIANS:
				steps *= 0.5
			best = refined
	return _result(best.state, context, profile, {"analytic_root_count": analytic_roots, "rho_equation_underdetermined": magnitude <= ROOT_EPSILON and absf(c) <= ROOT_EPSILON, "search_bounded": true})

## Read the actual pose, including an authored pose outside ROM. This does not
## accept a motion or modify a limit: the caller must validate new candidates.
## Equivalent 2*PI branches stay nearest the previous measured state. A prior
## state already matching the actual Hand is retained, even if outside ROM.
static func measure_state(forearm_reference: Transform3D, actual_hand: Transform3D, calibration: Dictionary, profile: Dictionary, previous_state: Dictionary = {}, elbow_bend_radians: float = NAN, full_flexion_radians: float = deg_to_rad(160.0)) -> Dictionary:
	var context := _context(forearm_reference, actual_hand, calibration, profile, elbow_bend_radians, full_flexion_radians)
	if not context.valid:
		return context
	profile = context.limits_profile
	var prior := _state_vector(previous_state)
	var has_prior := _state_valid(previous_state) and prior.is_finite()
	if not has_prior:
		prior = Vector3.ZERO
	var candidates: Array[Vector3] = []
	if has_prior:
		candidates.append(prior)
	var axis: Vector3 = context.axis
	var neutral: Basis = context.neutral
	var target: Basis = context.target_anatomical
	var n: Vector3 = neutral.x
	var v: Vector3 = target.z
	var c: float = n.dot(axis) * axis.dot(v)
	var a: float = n.dot(v) - c
	var b: float = -n.dot(axis.cross(v))
	var magnitude: float = sqrt(a * a + b * b)
	var rho_seeds: Array[float] = [prior.x, 0.0]
	var analytic_roots := 0
	if magnitude > ROOT_EPSILON and absf(c) <= magnitude + ROOT_EPSILON:
		var phase := atan2(b, a)
		var separation := acos(clampf(-c / magnitude, -1.0, 1.0))
		for root: float in [phase - separation, phase + separation]:
			rho_seeds.append(root)
			analytic_roots += 1
	for rho: float in rho_seeds:
		var local: Basis = (Basis(axis, rho) * neutral).transposed() * target
		var beta := atan2(-local.z.y, local.z.z)
		var gamma: float = float(context.radial_sign) * atan2(-local.y.x, local.x.x)
		var state := Vector3(rho, beta, gamma)
		for coordinate: int in 3:
			state[coordinate] = prior[coordinate] + wrapf(state[coordinate] - prior[coordinate], -PI, PI)
		candidates.append(state)
	var best := {"found": false, "state": prior, "error": INF, "distance": INF}
	var minimum_error := INF
	for state: Vector3 in candidates:
		if not state.is_finite():
			continue
		var candidate_hand: Basis = (_forward(state, context) * (context.anatomical_in_bone as Basis).transposed()).orthonormalized()
		var error := _orientation_error(candidate_hand, context.target_bone)
		minimum_error = minf(minimum_error, error)
		if not is_finite(error) or error > float(profile.orientation_tolerance_radians):
			continue
		var distance := state.distance_squared_to(prior)
		if not best.found or distance < float(best.distance):
			best = {"found": true, "state": state, "error": error, "distance": distance}
	var diagnostics := {"revision": REVISION, "analytic_root_count": analytic_roots,
		"rho_equation_underdetermined": magnitude <= ROOT_EPSILON and absf(c) <= ROOT_EPSILON,
		"independent_wrist_roll": false, "measurement_only": true, "bend_frame": context.bend_frame}
	if not best.found:
		return {"valid": false, "status": "UNREPRESENTABLE", "reason": "wrist_pose_not_representable",
			"orientation_error_radians": minimum_error, "diagnostics": diagnostics}
	var measured: Vector3 = best.state
	var bone: Basis = (_forward(measured, context) * (context.anatomical_in_bone as Basis).transposed()).orthonormalized()
	diagnostics["envelope_value"] = _envelope_value(measured, profile)
	diagnostics["forearm_interval"] = context.forearm_interval
	return {"valid": true, "status": "MEASURED", "reason": "", "state": _state_dictionary(measured),
		"hand_basis": bone.scaled(context.target_scale), "orientation_error_radians": best.error,
		"within_limits": _legal(measured, profile), "diagnostics": diagnostics}

## Replay accepted scalar motion through the same forward model. An invalid
## state is rejected; it is never silently clamped into an accepted pose.
static func compose(forearm_reference: Transform3D, hand_reference: Transform3D, calibration: Dictionary, profile: Dictionary, accepted_state: Dictionary, elbow_bend_radians: float = NAN, full_flexion_radians: float = deg_to_rad(160.0)) -> Dictionary:
	var context := _context(forearm_reference, hand_reference, calibration, profile, elbow_bend_radians, full_flexion_radians)
	if not context.valid:
		return context
	profile = context.limits_profile
	if not _state_valid(accepted_state):
		return _fail("wrist_state_invalid")
	var state := _state_vector(accepted_state)
	if not _legal(state, profile):
		return _fail("wrist_motion_range")
	var result := _result(state, context, profile, {"composed_accepted_state": true})
	# Here hand_reference supplies the pivot/reference scale. Its old rotation
	# is not a request to refit this explicitly authored state.
	result.valid = true
	result.status = "ACCEPTED"
	result.reason = ""
	return result

static func interpolate_states(from_state: Dictionary, to_state: Dictionary, weight: float) -> Dictionary:
	if not _state_valid(from_state) or not _state_valid(to_state) or not is_finite(weight):
		return {}
	# Bounded rho is an interval, not a periodic Euler channel. The fixed
	# asymmetric ellipse is convex; its legal endpoint scalar lerp stays legal.
	return _state_dictionary(_state_vector(from_state).lerp(_state_vector(to_state), clampf(weight, 0.0, 1.0)))

## Kinematic evaluation for constrained numerical allocation. This deliberately
## does not certify ROM: derivatives need samples immediately beyond a boundary.
## Only the allocator's complete nonlinear constraint gate may accept a sample.
static func sample_kinematics(forearm_reference: Transform3D, hand_reference: Transform3D, calibration: Dictionary, profile: Dictionary, state: Dictionary, elbow_bend_radians: float = NAN, full_flexion_radians: float = deg_to_rad(160.0)) -> Dictionary:
	var context := _context(forearm_reference, hand_reference, calibration, profile, elbow_bend_radians, full_flexion_radians)
	if not context.valid or not _state_valid(state):
		return context if not context.valid else _fail("wrist_state_invalid")
	var angles := _state_vector(state)
	var anatomical := _forward(angles, context)
	return {"valid": true, "hand_basis": (anatomical * (context.anatomical_in_bone as Basis).transposed()).orthonormalized().scaled(context.target_scale),
		"envelope_value": _envelope_value(angles, profile), "state": state.duplicate(), "forearm_interval": context.forearm_interval}

static func forearm_interval(calibration: Dictionary, profile: Dictionary, elbow_bend_radians: float = NAN, full_flexion_radians: float = deg_to_rad(160.0)) -> Dictionary:
	return ForearmRotation.interval(calibration, profile, elbow_bend_radians, full_flexion_radians)

static func forearm_geometry_limit(calibration: Dictionary, profile: Dictionary) -> float:
	return ForearmRotation.geometry_limit(calibration, profile)

static func _context(forearm: Transform3D, hand: Transform3D, calibration: Dictionary, profile: Dictionary, elbow_bend_radians: float, full_flexion_radians: float) -> Dictionary:
	if profile.get("revision", "") != REVISION:
		return _fail("wrist_profile_revision_mismatch", "INVALID_PROFILE")
	if not calibration.get("valid", false) or calibration.get("revision", "") != REVISION:
		return _fail("wrist_calibration_missing_or_obsolete")
	for key: String in ["forearm_roll_limit_radians", "flexion_limit_radians", "extension_limit_radians", "ulnar_limit_radians", "radial_limit_radians", "orientation_tolerance_radians", "angle_epsilon_radians"]:
		if not (profile.get(key) is float or profile.get(key) is int) or not is_finite(float(profile[key])) or float(profile[key]) <= 0.0:
			return _fail("wrist_profile_invalid_" + key, "INVALID_PROFILE")
	if float(profile.forearm_roll_limit_radians) > PI or maxf(float(profile.flexion_limit_radians), float(profile.extension_limit_radians)) >= PI * 0.5 or maxf(float(profile.ulnar_limit_radians), float(profile.radial_limit_radians)) >= PI * 0.5:
		return _fail("wrist_profile_unsupported_range", "INVALID_PROFILE")
	if not calibration.get("neutral_anatomical_in_forearm") is Basis or not calibration.get("anatomical_in_hand_bone") is Basis:
		return _fail("wrist_calibration_missing")
	var neutral_local: Basis = calibration.neutral_anatomical_in_forearm
	var anatomical_local: Basis = calibration.anatomical_in_hand_bone
	var radial_sign: float = float(calibration.get("radial_sign", 0.0))
	if not is_finite(radial_sign) or absf(absf(radial_sign) - 1.0) > ROOT_EPSILON or not _rotation_basis(neutral_local) or not _rotation_basis(anatomical_local):
		return _fail("wrist_calibration_invalid")
	var bend_frame: String = String(profile.get("bend_frame", Profile.BEND_FRAME_REST_ANATOMICAL))
	if bend_frame == Profile.BEND_FRAME_HAND_PARENT_LOCAL_XZ:
		# Literal Hand-parent local X/Z, as in the editor recordings. The
		# Forearm bone is the named reference in the existing calibration chain
		# through RL_BoneRoot. Identity is its axes, not a world-space zero and
		# not a neutral recaptured from the latest accepted pose.
		neutral_local = Basis.IDENTITY
		anatomical_local = Basis.IDENTITY
		radial_sign = 1.0
	elif bend_frame != Profile.BEND_FRAME_REST_ANATOMICAL:
		return _fail("wrist_bend_frame_unknown", "INVALID_PROFILE")
	if not forearm.is_finite() or not hand.is_finite() or not _uniform_basis(forearm.basis) or not _uniform_basis(hand.basis):
		return _fail("wrist_reference_invalid")
	var axis := hand.origin - forearm.origin
	if axis.length_squared() <= AXIS_EPSILON_SQUARED:
		return _fail("wrist_forearm_axis_degenerate")
	var interval := forearm_interval(calibration, profile, elbow_bend_radians, full_flexion_radians)
	if not interval.get("valid", false): return _fail(interval.get("reason", "forearm_interval_invalid"), "INVALID_PROFILE")
	var limits_profile := profile.duplicate()
	limits_profile["forearm_min_radians"] = interval.rho_min
	limits_profile["forearm_max_radians"] = interval.rho_max
	return {"valid": true, "axis": axis.normalized(), "neutral": (forearm.basis.orthonormalized() * neutral_local).orthonormalized(), "anatomical_in_bone": anatomical_local.orthonormalized(), "target_anatomical": (hand.basis.orthonormalized() * anatomical_local).orthonormalized(), "target_bone": hand.basis.orthonormalized(), "target_scale": hand.basis.get_scale(), "radial_sign": radial_sign, "forearm_interval": interval, "limits_profile": limits_profile, "bend_frame": bend_frame}

static func _forward(state: Vector3, context: Dictionary) -> Basis:
	return (Basis(context.axis, state.x) * context.neutral * Basis(Vector3.RIGHT, state.y) * Basis(Vector3.BACK, float(context.radial_sign) * state.z)).orthonormalized()

static func _result(state: Vector3, context: Dictionary, profile: Dictionary, diagnostics: Dictionary) -> Dictionary:
	var anatomical := _forward(state, context)
	var bone: Basis = (anatomical * context.anatomical_in_bone.transposed()).orthonormalized()
	var error := _orientation_error(anatomical, context.target_anatomical)
	var accepted: bool = _legal(state, profile) and error <= float(profile.orientation_tolerance_radians)
	diagnostics["revision"] = REVISION
	diagnostics["envelope_value"] = _envelope_value(state, profile)
	diagnostics["forearm_interval"] = context.forearm_interval
	diagnostics["forearm_axis_reference"] = context.axis
	diagnostics["independent_wrist_roll"] = false
	diagnostics["bend_frame"] = context.bend_frame
	return {"valid": accepted, "status": "ACCEPTED" if accepted else "APPROXIMATE", "reason": "" if accepted else "wrist_motion_range", "accepted_state": _state_dictionary(state), "accepted_hand_basis": bone.scaled(context.target_scale), "orientation_error_radians": error, "residual_basis": context.target_bone * bone.transposed(), "diagnostics": diagnostics}

static func _best(candidates: Array[Vector3], context: Dictionary, profile: Dictionary, prior: Vector3) -> Dictionary:
	var best := {"state": prior, "error": INF, "distance": INF}
	for state: Vector3 in candidates:
		if not _legal(state, profile):
			continue
		var error := _orientation_error(_forward(state, context), context.target_anatomical)
		var distance := state.distance_squared_to(prior)
		if error < float(best.error) - ERROR_TIE_RADIANS or (absf(error - float(best.error)) <= ERROR_TIE_RADIANS and distance < float(best.distance)):
			best = {"state": state, "error": error, "distance": distance}
	return best

static func _orientation_error(a: Basis, b: Basis) -> float:
	var delta := (a.get_rotation_quaternion().inverse() * b.get_rotation_quaternion()).normalized()
	return 2.0 * atan2(Vector3(delta.x, delta.y, delta.z).length(), absf(delta.w))

static func _project(state: Vector3, profile: Dictionary) -> Vector3:
	state.x = clampf(state.x, float(profile.get("forearm_min_radians", -float(profile.forearm_roll_limit_radians))), float(profile.get("forearm_max_radians", float(profile.forearm_roll_limit_radians))))
	var radius := sqrt(_envelope_value(state, profile))
	if radius > 1.0:
		state.y /= radius
		state.z /= radius
	return state

static func _envelope_value(state: Vector3, profile: Dictionary) -> float:
	var beta_limit: float = profile.extension_limit_radians if state.y >= 0.0 else profile.flexion_limit_radians
	var gamma_limit: float = profile.radial_limit_radians if state.z >= 0.0 else profile.ulnar_limit_radians
	return pow(state.y / beta_limit, 2.0) + pow(state.z / gamma_limit, 2.0)

static func _legal(state: Vector3, profile: Dictionary) -> bool:
	return state.is_finite() and state.x >= float(profile.get("forearm_min_radians", -float(profile.forearm_roll_limit_radians))) - SCALAR_EPSILON and state.x <= float(profile.get("forearm_max_radians", float(profile.forearm_roll_limit_radians))) + SCALAR_EPSILON and _envelope_value(state, profile) <= 1.0 + ENVELOPE_EPSILON

static func _state_valid(state: Dictionary) -> bool:
	for key: String in ["rho", "beta", "gamma"]:
		if not (state.get(key) is float or state.get(key) is int) or not is_finite(float(state[key])):
			return false
	return true

static func _state_vector(state: Dictionary) -> Vector3:
	return Vector3(float(state.rho), float(state.beta), float(state.gamma)) if _state_valid(state) else Vector3.ZERO

static func _state_dictionary(state: Vector3) -> Dictionary:
	return {"rho": state.x, "beta": state.y, "gamma": state.z}

static func _rotation_basis(basis: Basis) -> bool:
	return _uniform_basis(basis) and basis.get_scale().is_equal_approx(Vector3.ONE)

static func _uniform_basis(basis: Basis) -> bool:
	if not basis.is_finite() or basis.determinant() <= 0.0:
		return false
	var lengths := basis.get_scale()
	if minf(lengths.x, minf(lengths.y, lengths.z)) <= 0.000001 or not is_equal_approx(lengths.x, lengths.y) or not is_equal_approx(lengths.x, lengths.z):
		return false
	var normalized := Basis(basis.x / lengths.x, basis.y / lengths.y, basis.z / lengths.z)
	return absf(normalized.x.dot(normalized.y)) < 0.00001 and absf(normalized.x.dot(normalized.z)) < 0.00001 and absf(normalized.y.dot(normalized.z)) < 0.00001

static func _fail(reason: String, status: String = "BLOCKED") -> Dictionary:
	return {"valid": false, "status": status, "reason": reason, "diagnostics": {"revision": REVISION}}
