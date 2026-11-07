extends RefCounted
class_name CombatArmReachResolver

## Necessary reach bound, never a replacement for complete pose validation.
## Caller supplies actual posed segment vectors and hinge axis in ONE declared
## Euclidean reference frame (runtime ancestry must resolve to RL_BoneRoot).
## No assumed zero, bone length, elbow convention, profile or scene ownership.
## A downstream nonconformal transform needs a conservative operator-norm bound
## from the caller; runtime supplies that instead of assuming uniform scale.

static func maximum_radius(upper: Vector3, distal: Vector3, hinge_axis: Vector3,
		min_delta: float, max_delta: float) -> Dictionary:
	if not upper.is_finite() or not distal.is_finite() or not hinge_axis.is_finite() \
			or not is_finite(min_delta) or not is_finite(max_delta) or min_delta > max_delta:
		return {"valid": false, "reason": "arm_reach_invalid_input"}
	var axis_length := sqrt(_dot(hinge_axis, hinge_axis))
	if axis_length <= 1.0e-12:
		return {"valid": false, "reason": "arm_reach_missing_hinge_axis"}
	# Compute with scalar floats rather than Vector3.dot's engine precision.
	var ux: float = hinge_axis.x / axis_length
	var uy: float = hinge_axis.y / axis_length
	var uz: float = hinge_axis.z / axis_length
	var upper_axial: float = upper.x * ux + upper.y * uy + upper.z * uz
	var distal_axial: float = distal.x * ux + distal.y * uy + distal.z * uz
	var constant: float = _dot(upper, upper) + _dot(distal, distal) + 2.0 * upper_axial * distal_axial
	var cosine: float = 2.0 * (_dot(upper, distal) - upper_axial * distal_axial)
	var sine: float = 2.0 * (upper.x * (uy * distal.z - uz * distal.y)
		+ upper.y * (uz * distal.x - ux * distal.z) + upper.z * (ux * distal.y - uy * distal.x))
	# |upper + Rot(axis,delta)*distal|^2 = constant + cosine*cos + sine*sin.
	# The hinge need not be perfectly perpendicular to either posed segment.
	var maximum: float = constant + cosine * cos(min_delta) + sine * sin(min_delta)
	var extremum := min_delta
	var end_value: float = constant + cosine * cos(max_delta) + sine * sin(max_delta)
	if end_value > maximum:
		maximum = end_value
		extremum = max_delta
	var peak := atan2(sine, cosine)
	peak += TAU * ceil((min_delta - peak) / TAU)
	if peak <= max_delta or max_delta - min_delta >= TAU:
		maximum = maxf(maximum, constant + sqrt(cosine * cosine + sine * sine))
		extremum = peak
	if not is_finite(maximum):
		return {"valid": false, "reason": "arm_reach_nonfinite_bound"}
	return {"valid": true, "reason": "", "radius": sqrt(maxf(0.0, maximum)),
		"maximum_squared_radius": maxf(0.0, maximum), "extremum_delta": extremum}

## Largest prefix of the straight requested translation inside the sphere.
## An unsupported/outside start supplies NO cap (invalid, fraction 1), allowing
## the existing recovery/solver route to decide. It never asserts a valid pose.
static func translation_fraction(center: Vector3, start: Vector3, target: Vector3, radius: float) -> Dictionary:
	if not center.is_finite() or not start.is_finite() or not target.is_finite() or not is_finite(radius) or radius < 0.0:
		return {"valid": false, "reason": "arm_reach_invalid_sphere", "maximum_fraction": 1.0}
	var relative := start - center
	var delta := target - start
	var a := _dot(delta, delta)
	var b := _dot(relative, delta)
	var c := _dot(relative, relative) - radius * radius
	if not is_finite(a) or not is_finite(b) or not is_finite(c):
		return {"valid": false, "reason": "arm_reach_nonfinite_segment", "maximum_fraction": 1.0}
	if c > 0.0:
		return {"valid": false, "reason": "arm_reach_start_outside", "maximum_fraction": 1.0}
	if a == 0.0:
		return {"valid": true, "reason": "", "maximum_fraction": 1.0}
	var root_value := sqrt(maxf(0.0, b * b - a * c))
	# Avoid catastrophic cancellation for an outward step near the boundary.
	var exit_fraction: float = -c / (b + root_value) if b > 0.0 else (-b + root_value) / a
	if not is_finite(exit_fraction):
		return {"valid": false, "reason": "arm_reach_nonfinite_exit", "maximum_fraction": 1.0}
	return {"valid": true, "reason": "", "maximum_fraction": clampf(exit_fraction, 0.0, 1.0)}

static func _dot(a: Vector3, b: Vector3) -> float:
	return float(a.x) * float(b.x) + float(a.y) * float(b.y) + float(a.z) * float(b.z)
