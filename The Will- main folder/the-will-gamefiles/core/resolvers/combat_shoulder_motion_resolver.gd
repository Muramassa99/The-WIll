extends RefCounted
class_name CombatShoulderMotionResolver

## Pure chest-relative measurement/composition. All poses share a caller-named
## reference (Skeleton3D or captured replay reference) whose chain reaches
## RL_BoneRoot. No world axes, scene writes, IK or changing neutral reference.
const REVISION := "chest_relative_shoulder_v1"
const EPSILON_SQUARED := 1.0e-12
const ANTIPODE_EPSILON := 1.0e-6

static func validate_profile(profile: Dictionary) -> Dictionary:
	if String(profile.get("revision", "")) != REVISION:
		return _fail("shoulder_profile_revision")
	var planes: Variant = profile.get("plane_samples_radians")
	var minimums: Variant = profile.get("minimum_samples_radians")
	var maximums: Variant = profile.get("maximum_samples_radians")
	if not planes is PackedFloat64Array or not minimums is PackedFloat64Array or not maximums is PackedFloat64Array:
		return _fail("shoulder_profile_sample_layout")
	if planes.size() < 2 or planes.size() != minimums.size() or planes.size() != maximums.size():
		return _fail("shoulder_profile_sample_count")
	for i: int in planes.size():
		if not is_finite(planes[i]) or not is_finite(minimums[i]) or not is_finite(maximums[i]) or minimums[i] >= maximums[i]:
			return _fail("shoulder_profile_sample_invalid")
		if i > 0 and planes[i] <= planes[i - 1]:
			return _fail("shoulder_profile_planes_unordered")
	for field: String in ["sampled_elevation_radians", "angle_epsilon_radians"]:
		if not is_finite(float(profile.get(field, NAN))):
			return _fail("shoulder_profile_missing_" + field)
	if float(profile.angle_epsilon_radians) < 0.0:
		return _fail("shoulder_profile_negative_epsilon")
	if String(profile.get("coverage_mode", "")) != "measured_band_only":
		return _fail("shoulder_profile_unknown_coverage")
	return {"valid": true, "reason": ""}

static func measure(chest: Transform3D, upperarm: Transform3D, forearm: Transform3D,
		calibration: Dictionary, profile: Dictionary, previous_state: Dictionary = {}) -> Dictionary:
	var validation := validate_profile(profile)
	if not validation.valid:
		return validation
	var context := _context(chest, upperarm, forearm, calibration)
	if not context.valid:
		return context
	var hinge: Vector3 = context.chest_frame.transposed() * upperarm.basis.orthonormalized() * (calibration.material_frame_in_upperarm as Basis).x
	var shaft: Vector3 = context.direction
	hinge -= shaft * hinge.dot(shaft)
	if hinge.length_squared() <= EPSILON_SQUARED:
		return _fail("shoulder_material_hinge_parallel_to_shaft")
	hinge = hinge.normalized()
	var zero: Vector3 = context.zero_hinge
	var h: float = float(calibration.internal_sign) * atan2(shaft.dot(zero.cross(hinge)), zero.dot(hinge))
	if previous_state.has("h"):
		var prior: float = float(previous_state.h)
		if not is_finite(prior):
			return _fail("shoulder_previous_angle_nonfinite")
		# Previous accepted h selects a branch, never a new anatomical zero.
		h += TAU * round((prior - h) / TAU)
	var bounds := sample_bounds(shaft, float(calibration.side_sign), profile)
	var violations := PackedFloat64Array()
	var legal := false
	if bounds.covered:
		violations.append(float(bounds.minimum_radians) - h)
		violations.append(h - float(bounds.maximum_radians))
		legal = maxf(violations[0], violations[1]) <= float(profile.angle_epsilon_radians)
	return {"valid": true, "legal": legal, "covered": bool(bounds.covered),
		"reason": "" if bounds.covered else "shoulder_direction_not_calibrated",
		"state": {"h": h}, "minimum_radians": bounds.minimum_radians,
		"maximum_radians": bounds.maximum_radians, "violations": violations,
		"direction_anatomical": shaft, "plane_radians": bounds.plane_radians,
		"elevation_radians": bounds.elevation_radians, "revision": REVISION,
		"origin_id": calibration.origin_id, "reference_chart": context.reference_chart,
		"reference_warning": context.reference_warning}

static func compose(chest: Transform3D, upperarm: Transform3D, forearm: Transform3D,
		calibration: Dictionary, requested_h: float) -> Dictionary:
	if not is_finite(requested_h):
		return _fail("shoulder_requested_angle_nonfinite")
	var context := _context(chest, upperarm, forearm, calibration)
	if not context.valid:
		return context
	var shaft: Vector3 = context.direction
	var hinge: Vector3 = Basis(shaft, requested_h * float(calibration.internal_sign)) * (context.zero_hinge as Vector3)
	var material: Basis = calibration.material_frame_in_upperarm
	var anatomical := Basis(hinge, shaft, hinge.cross(shaft))
	var result: Basis = context.chest_frame * anatomical * material.transposed()
	return {"valid": true, "reason": "", "upperarm_basis": result.orthonormalized().scaled_local(upperarm.basis.get_scale()),
		"state": {"h": requested_h}, "revision": REVISION,
		"reference_chart": context.reference_chart, "reference_warning": context.reference_warning}

static func sample_bounds(direction_anatomical: Vector3, side_sign: float, profile: Dictionary) -> Dictionary:
	var u := direction_anatomical.normalized()
	var plane: float = atan2(-u.z, u.x * side_sign)
	var elevation: float = acos(clampf(-u.y, -1.0, 1.0))
	var result := {"covered": false, "minimum_radians": 0.0, "maximum_radians": 0.0,
		"plane_radians": plane, "elevation_radians": elevation}
	var planes: PackedFloat64Array = profile.plane_samples_radians
	var epsilon: float = profile.angle_epsilon_radians
	if absf(elevation - float(profile.sampled_elevation_radians)) > epsilon or plane < planes[0] - epsilon or plane > planes[-1] + epsilon:
		return result
	plane = clampf(plane, planes[0], planes[-1])
	for i: int in range(planes.size() - 1):
		if plane > planes[i + 1]:
			continue
		var weight: float = (plane - planes[i]) / (planes[i + 1] - planes[i])
		result.minimum_radians = lerpf(profile.minimum_samples_radians[i], profile.minimum_samples_radians[i + 1], weight)
		result.maximum_radians = lerpf(profile.maximum_samples_radians[i], profile.maximum_samples_radians[i + 1], weight)
		result.covered = true
		return result
	return result

static func _context(chest: Transform3D, upperarm: Transform3D, forearm: Transform3D, calibration: Dictionary) -> Dictionary:
	if not calibration.get("valid", false) or String(calibration.get("revision", "")) != REVISION:
		return _fail("shoulder_calibration_invalid")
	for frame: Transform3D in [chest, upperarm, forearm]:
		if not frame.is_finite() or frame.basis.determinant() <= 0.0 or not frame.basis.is_conformal():
			return _fail("shoulder_pose_nonrigid")
	for field: String in ["chest_anatomical_in_bone", "material_frame_in_upperarm"]:
		var value: Variant = calibration.get(field)
		if not value is Basis or not value.is_finite() or not value.is_equal_approx(value.orthonormalized()) or value.determinant() <= 0.0:
			return _fail("shoulder_calibration_invalid_" + field)
	var side: float = float(calibration.get("side_sign", 0.0))
	var internal: float = float(calibration.get("internal_sign", 0.0))
	if absf(side) != 1.0 or absf(internal) != 1.0:
		return _fail("shoulder_calibration_invalid_sign")
	var chest_frame: Basis = chest.basis.orthonormalized() * (calibration.chest_anatomical_in_bone as Basis)
	var shaft := forearm.origin - upperarm.origin
	if shaft.length_squared() <= EPSILON_SQUARED:
		return _fail("shoulder_zero_length_upperarm")
	var u: Vector3 = (chest_frame.transposed() * shaft).normalized()
	# These constants are axes of the named anatomical chest origin, NOT world.
	# Fixed reference exercise: arm sideways, forearm forward at elbow 90.
	# Shortest swing maps it to the candidate direction; no incremental transport.
	# At forward shoulder-height zero forearm points across toward the midline;
	# at arm-down zero forearm points forward. This is an engineering convention.
	var outward := Vector3(side, 0.0, 0.0)
	var reference_chart := "sideways_reference"
	var reference_warning := ""
	var zero: Vector3
	if outward.dot(u) < -1.0 + ANTIPODE_EPSILON:
		# A sphere cannot have a globally continuous nonzero transverse frame.
		# At this uncovered direction use a SECOND FIXED reference chart: turn
		# the sideways reference 180 degrees about anatomical chest-up, then
		# shortest-swing to u. Its hinge stays side*up. The tiny chart seam is
		# explicit; this is recovery-readable geometry, not invented ROM data.
		zero = Basis(Quaternion(-outward, u)) * Vector3(0.0, side, 0.0)
		reference_chart = "opposite_side_reference"
		reference_warning = "uncovered_shoulder_reference_chart_seam"
	else:
		zero = Basis(Quaternion(outward, u)) * Vector3(0.0, side, 0.0)
	zero = (zero - u * zero.dot(u)).normalized()
	return {"valid": true, "chest_frame": chest_frame, "direction": u, "zero_hinge": zero,
		"reference_chart": reference_chart, "reference_warning": reference_warning}

static func _fail(reason: String) -> Dictionary:
	return {"valid": false, "legal": false, "covered": false, "reason": reason, "revision": REVISION}
