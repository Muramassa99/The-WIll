extends RefCounted
class_name CombatForearmRotationResolver

## Anatomical pronation p is distinct from stored geometric rho:
## rho = thumb_up_rho + pronation_sign * p. All calibration vectors are in
## Forearm bone space, derived through Upperarm from immutable imported rests.
const REVISION := "elbow_conditioned_forearm_v1"
const Hinge = preload("res://core/resolvers/combat_arm_hinge_frame_resolver.gd")
const EPSILON := 1.0e-10

static func calibrate(forearm_rest: Transform3D, hand_rest: Transform3D,
		anatomical_in_forearm: Basis, radial_sign: float) -> Dictionary:
	var material: Dictionary = Hinge.calibration(forearm_rest, hand_rest)
	if not material.get("valid", false): return material
	if not anatomical_in_forearm.is_finite() or not is_equal_approx(absf(radial_sign), 1.0):
		return {"valid": false, "reason": "forearm_thumb_up_calibration_invalid"}
	var shaft: Vector3 = hand_rest.origin.normalized()
	var hinge: Vector3 = forearm_rest.basis.orthonormalized().transposed() * (material.frame_in_upperarm as Basis).x
	var thumb_up: Vector3 = hinge.cross(shaft)
	var radial: Vector3 = -anatomical_in_forearm.x * radial_sign
	radial -= shaft * radial.dot(shaft)
	if minf(thumb_up.length_squared(), radial.length_squared()) <= EPSILON:
		return {"valid": false, "reason": "forearm_thumb_up_reference_degenerate"}
	thumb_up = thumb_up.normalized()
	radial = radial.normalized()
	var zero: float = atan2(shaft.dot(radial.cross(thumb_up)), radial.dot(thumb_up))
	var neutral_palmar: Vector3 = Basis(shaft, zero) * -anatomical_in_forearm.z
	# At a thumb-up pose pronation turns the palm toward the elbow-flexion
	# plane's down direction. Derive the sign independently from each hand.
	var pronation_alignment: float = shaft.cross(neutral_palmar).dot(-thumb_up)
	if absf(pronation_alignment) < 0.1:
		return {"valid": false, "reason": "forearm_pronation_direction_ambiguous"}
	return {"valid": true, "forearm_interval_revision": REVISION,
		"forearm_thumb_up_rho_radians": zero, "forearm_pronation_sign": signf(pronation_alignment),
		"forearm_shaft_local": shaft, "forearm_hinge_local": hinge,
		"forearm_thumb_up_local": thumb_up, "forearm_pronation_alignment": pronation_alignment}

## NAN bend requests the complete profile envelope for measurement/legacy
## consumers only. A candidate acceptance check must supply its actual bend.
static func interval(calibration: Dictionary, profile: Dictionary,
		elbow_bend_radians: float = NAN, full_flexion_radians: float = deg_to_rad(160.0)) -> Dictionary:
	if not profile.has("forearm_interval_revision"):
		var legacy: float = float(profile.get("forearm_roll_limit_radians", 0.0))
		return {"valid": is_finite(legacy) and legacy > 0.0, "rho_min": -legacy,
			"rho_max": legacy, "conditioned": false, "legacy": true}
	if String(profile.get("forearm_interval_revision", "")) != REVISION or String(calibration.get("forearm_interval_revision", "")) != REVISION:
		return {"valid": false, "reason": "forearm_interval_calibration_missing"}
	var zero: float = float(calibration.get("forearm_thumb_up_rho_radians", NAN))
	var direction: float = float(calibration.get("forearm_pronation_sign", NAN))
	if not is_finite(zero) or not is_finite(direction) or not is_equal_approx(absf(direction), 1.0):
		return {"valid": false, "reason": "forearm_interval_calibration_invalid"}
	var bends := PackedFloat64Array(profile.get("forearm_elbow_samples_radians", []))
	var pronation := PackedFloat64Array(profile.get("forearm_pronation_limits_radians", []))
	var supination := PackedFloat64Array(profile.get("forearm_supination_limits_radians", []))
	if bends.size() < 2 or bends.size() != pronation.size() or bends.size() != supination.size() or not is_finite(full_flexion_radians):
		return {"valid": false, "reason": "forearm_interval_samples_invalid"}
	# The document maps its final measured sample to this rig's full bend;
	# intermediate samples retain their measured elbow angles (45 and90 deg).
	bends[bends.size() - 1] = full_flexion_radians
	var p := 0.0
	var s := 0.0
	for index: int in bends.size():
		if not is_finite(bends[index]) or not is_finite(pronation[index]) or not is_finite(supination[index]) or minf(pronation[index], supination[index]) <= 0.0 or maxf(pronation[index], supination[index]) > PI or (index > 0 and bends[index] <= bends[index - 1]):
			return {"valid": false, "reason": "forearm_interval_samples_invalid"}
		p = maxf(p, pronation[index])
		s = maxf(s, supination[index])
	var conditioned: bool = is_finite(elbow_bend_radians)
	if conditioned:
		var bend := clampf(elbow_bend_radians, bends[0], bends[bends.size() - 1])
		for index: int in range(1, bends.size()):
			if bend <= bends[index]:
				var weight: float = (bend - bends[index - 1]) / (bends[index] - bends[index - 1])
				p = lerpf(pronation[index - 1], pronation[index], weight)
				s = lerpf(supination[index - 1], supination[index], weight)
				break
	var a: float = zero - direction * s
	var b: float = zero + direction * p
	return {"valid": true, "revision": REVISION, "rho_min": minf(a, b), "rho_max": maxf(a, b),
		"pronation_limit": p, "supination_limit": s, "conditioned": conditioned,
		"thumb_up_rho": zero, "pronation_sign": direction, "elbow_bend_radians": elbow_bend_radians,
		"full_flexion_radians": full_flexion_radians, "legacy": false}

static func geometry_limit(calibration: Dictionary, profile: Dictionary) -> float:
	var bounds := interval(calibration, profile)
	return maxf(absf(bounds.rho_min), absf(bounds.rho_max)) if bounds.get("valid", false) else NAN
