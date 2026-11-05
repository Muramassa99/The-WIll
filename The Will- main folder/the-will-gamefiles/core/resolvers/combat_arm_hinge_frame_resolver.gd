extends RefCounted
class_name CombatArmHingeFrameResolver

## Shared material frame, not a reach solver or a shoulder ROM envelope.
## Input poses share one declared caller reference (Skeleton3D in the live rig,
## captured replay reference in preparation). Rest transforms are parent-bone
## relative: Forearm -> Upperarm and Hand -> Forearm. No world-axis pole is used.
## Calibration therefore follows Upperarm -> Clavicle -> ... -> RL_BoneRoot;
## model/world translation, rotation and uniform scale cannot change the rule.
const REVISION := "rest_material_hinge_v1"
const DIRECTION_EPSILON_SQUARED := 1.0e-12
# Dimensionless sine threshold, not a length measured from an arbitrary origin.
const BEND_SINE_EPSILON := 0.0001

static func calibration(forearm_rest: Transform3D, hand_rest: Transform3D) -> Dictionary:
	if not forearm_rest.is_finite() or not hand_rest.is_finite():
		return {"valid": false, "reason": "nonfinite_arm_rest"}
	var shaft: Vector3 = forearm_rest.origin
	var distal: Vector3 = forearm_rest.basis * hand_rest.origin
	if minf(shaft.length_squared(), distal.length_squared()) <= DIRECTION_EPSILON_SQUARED:
		return {"valid": false, "reason": "degenerate_arm_rest_segment"}
	shaft = shaft.normalized()
	distal = distal.normalized()
	var hinge: Vector3 = shaft.cross(distal)
	if hinge.length() < BEND_SINE_EPSILON:
		# A straight imported arm needs explicit model calibration. Do not infer
		# its anatomical front from whichever pose happened to be loaded first.
		return {"valid": false, "reason": "arm_rest_needs_bent_calibration"}
	hinge = hinge.normalized()
	return {"valid": true, "frame_in_upperarm": Basis(hinge, shaft, hinge.cross(shaft)), "revision": REVISION}

static func resolve(
	upper: Transform3D, forearm: Transform3D, hand: Transform3D,
	forearm_rest: Transform3D, hand_rest: Transform3D
) -> Dictionary:
	var calibrated: Dictionary = calibration(forearm_rest, hand_rest)
	if not calibrated.valid:
		return calibrated
	for frame: Transform3D in [upper, forearm, hand]:
		if not frame.is_finite() or frame.basis.determinant() <= 0.0:
			return {"valid": false, "reason": "invalid_arm_reference_frame"}
	var shaft: Vector3 = forearm.origin - upper.origin
	var distal: Vector3 = hand.origin - forearm.origin
	if minf(shaft.length_squared(), distal.length_squared()) <= DIRECTION_EPSILON_SQUARED:
		return {"valid": false, "reason": "degenerate_arm_segment"}
	shaft = shaft.normalized()
	distal = distal.normalized()
	var material: Basis = calibrated.frame_in_upperarm
	var hinge: Vector3 = shaft.cross(distal)
	var underdetermined: bool = hinge.length() < BEND_SINE_EPSILON
	if underdetermined:
		# Retain the posed, calibrated material hinge when geometric bend is
		# unobservable. This state is already captured in the bone rotations.
		hinge = upper.basis.orthonormalized() * material.x
		hinge -= shaft * hinge.dot(shaft)
		if hinge.length_squared() <= DIRECTION_EPSILON_SQUARED:
			return {"valid": false, "reason": "degenerate_material_hinge"}
	hinge = hinge.normalized()
	var desired: Basis = (Basis(hinge, shaft, hinge.cross(shaft)) * material.transposed()).orthonormalized()
	return {
		"valid": true, "upperarm_basis": desired,
		"hinge_reference": hinge, "underdetermined_bend": underdetermined,
		"flexion_degrees": rad_to_deg(atan2(hinge.dot(shaft.cross(distal)), shaft.dot(distal))),
		"revision": REVISION,
	}
