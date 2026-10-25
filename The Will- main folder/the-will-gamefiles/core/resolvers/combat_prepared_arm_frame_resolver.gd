extends RefCounted
class_name CombatPreparedArmFrameResolver

## Value-only extraction of PlayerHumanoidRig.realize_prepared_support_hand_frame.
## No acquisition, collision queries, CCD, scene mutation or new anatomy limits.
## Only the four named arm rotations may change. All coordinates share the
## captured replay reference; limits and initial helper rotations come from rig.
const FRAME_EPSILON := 0.00005
# Accepted hand-to-target positional residual, in metres. Angular and internal
# correction precision remain independent of this gameplay allowance.
const POSITION_TOLERANCE_METERS := 0.005
# Maximum absolute deviation from the target: +/-0.025 degrees (0.05 total).
const ANGULAR_TOLERANCE_RADIANS := deg_to_rad(0.025)

static func resolve(pose: Dictionary, requested_hand_reference: Transform3D, constraints: Dictionary) -> Dictionary:
	var validation: Dictionary = _validate(pose, constraints)
	if not validation.valid:
		return validation
	if not requested_hand_reference.is_finite() or not _supported_basis(requested_hand_reference.basis):
		return _fail("invalid_requested_hand_frame")
	var indices: Array[int] = validation.indices
	var c: int = indices[0]
	var u: int = indices[1]
	var f: int = indices[2]
	var h: int = indices[3]
	var rotations: PackedVector4Array = pose.pose_rotations.duplicate()
	var fk: Dictionary = forward_kinematics(pose, rotations)
	if not fk.valid:
		return fk
	var original: Array[Transform3D] = fk.transforms
	if not original[h].basis.get_scale().is_equal_approx(requested_hand_reference.basis.get_scale()):
		return _fail("requested_hand_scale_differs_from_rig")
	var helper_check: Dictionary = _check_helpers(pose, constraints)
	if not helper_check.valid:
		return helper_check
	var root: Vector3 = original[c].origin
	var shoulder: Vector3 = original[u].origin
	var elbow: Vector3 = original[f].origin
	var reach: float = float(constraints.usable_reach_m)
	if reach > 0.00001 and root.distance_to(requested_hand_reference.origin) > reach:
		return _fail("requested_hand_outside_usable_reach")
	var hand_local: Transform3D = _local(pose, rotations, h)
	var desired_forearm: Transform3D = requested_hand_reference * hand_local.affine_inverse()
	var hand_rest: Basis = pose.bone_rest_transforms[h].basis.orthonormalized()
	var wrist_reference: float = _wrist_twist(requested_hand_reference, desired_forearm, hand_rest)
	var initial_metrics: Dictionary = _metrics(original, indices, requested_hand_reference, hand_rest, wrist_reference, constraints)
	initial_metrics["upperarm_axial_twist_rad"] = _upperarm_twist(pose, rotations, u)
	# Existing exact destinations remain byte-for-byte identical, including a
	# legal authored elbow branch. This is also the idempotent follow case.
	if bool(initial_metrics.valid):
		return initial_metrics.merged({"pose_rotations": rotations, "changed": false, "wrist_swing_used": false, "helper_twists": helper_check.twists})
	var l1: float = root.distance_to(shoulder)
	var l2: float = shoulder.distance_to(elbow)
	var l3: float = desired_forearm.origin.distance_to(requested_hand_reference.origin)
	if minf(l1, minf(l2, l3)) <= 0.000001:
		return _fail("degenerate_arm_segment")
	var wrist_swing := false
	var root_to_hand: Vector3 = requested_hand_reference.origin - root
	var hand_distance: float = root_to_hand.length()
	var min_distance: float = sqrt(maxf(l1 * l1 + l2 * l2 - 2.0 * l1 * l2 * cos(deg_to_rad(constraints.shoulder_min_degrees)), 0.0))
	var max_distance: float = sqrt(maxf(l1 * l1 + l2 * l2 - 2.0 * l1 * l2 * cos(deg_to_rad(constraints.shoulder_max_degrees)), 0.0))
	min_distance = maxf(min_distance, absf(hand_distance - l3))
	max_distance = minf(max_distance, hand_distance + l3)
	if hand_distance <= 0.000001 or min_distance > max_distance:
		return _fail("requested_hand_has_no_arm_sphere_intersection")
	var current_distance: float = root.distance_to(elbow)
	var distance_interval := {"initial": current_distance, "minimum": min_distance, "maximum": max_distance}
	if hand_distance > 0.000001:
		var chosen: float = clampf(current_distance, min_distance, max_distance)
		var hand_axis: Vector3 = root_to_hand / hand_distance
		var along: float = (chosen * chosen - l3 * l3 + hand_distance * hand_distance) / (2.0 * hand_distance)
		var radius: float = sqrt(maxf(chosen * chosen - along * along, 0.0))
		# The existing wrist-swing freedom also keeps the authored elbow branch
		# during following. Transport its incoming plane with the root-to-hand
		# direction; projecting an untransported elbow onto the new axis can flip
		# its radial sign as the target crosses that elbow. No previous-frame
		# mutable state, new angle range or target clamping is introduced.
		var incoming_axis: Vector3 = original[h].origin - root
		if incoming_axis.length_squared() <= 0.000000000001:
			return _fail("degenerate_incoming_arm_axis")
		var transport: Quaternion = _direction_swing(incoming_axis.normalized(), hand_axis)
		var radial: Vector3 = transport * (elbow - root)
		radial -= hand_axis * radial.dot(hand_axis)
		if radial.length_squared() <= 0.00000001:
			radial = _perpendicular(hand_axis, constraints.reference_up)
		var adjusted: Vector3 = root + hand_axis * along + radial.normalized() * radius
		var old_axis: Vector3 = (requested_hand_reference.origin - desired_forearm.origin).normalized()
		var new_axis: Vector3 = (requested_hand_reference.origin - adjusted).normalized()
		var old_twist: float = _wrist_twist(requested_hand_reference, desired_forearm, hand_rest)
		desired_forearm.basis = Basis(Quaternion(old_axis, new_axis)) * desired_forearm.basis
		desired_forearm.origin = adjusted
		var new_twist: float = _wrist_twist(requested_hand_reference, desired_forearm, hand_rest)
		desired_forearm.basis = Basis(new_axis, _wrap(new_twist - old_twist)) * desired_forearm.basis
		hand_local.basis = (desired_forearm.basis.inverse() * requested_hand_reference.basis).orthonormalized().scaled(pose.pose_scales[h])
		wrist_swing = true
	var chord: Vector3 = desired_forearm.origin - root
	var distance: float = chord.length()
	if distance <= 0.000001 or distance > l1 + l2 or distance < absf(l1 - l2):
		return _fail("elbow_frame_outside_reach")
	var shoulder_angle: float = rad_to_deg(acos(clampf((l1 * l1 + l2 * l2 - distance * distance) / (2.0 * l1 * l2), -1.0, 1.0)))
	if not _in_range(shoulder_angle, constraints.shoulder_min_degrees, constraints.shoulder_max_degrees, constraints.joint_epsilon_degrees):
		return _fail("shoulder_range").merged({"shoulder_angle_degrees": shoulder_angle})
	var axis: Vector3 = chord / distance
	var along: float = (l1 * l1 - l2 * l2 + distance * distance) / (2.0 * distance)
	var radius: float = sqrt(maxf(l1 * l1 - along * along, 0.0))
	var radial: Vector3 = shoulder - root
	radial -= axis * radial.dot(axis)
	if radial.length_squared() <= 0.00000001:
		radial = _perpendicular(axis, constraints.reference_up)
	var desired_shoulder: Vector3 = root + axis * along + radial.normalized() * radius
	var elbow_angle: float = rad_to_deg((desired_shoulder - desired_forearm.origin).angle_to(requested_hand_reference.origin - desired_forearm.origin))
	if not _in_range(elbow_angle, constraints.elbow_min_degrees, constraints.elbow_max_degrees, constraints.joint_epsilon_degrees):
		var forearm_axis: Vector3 = (requested_hand_reference.origin - desired_forearm.origin).normalized()
		var projected: Vector3 = forearm_axis - axis * forearm_axis.dot(axis)
		var center: Vector3 = root + axis * along
		var denominator: float = radius * projected.length()
		if denominator <= 0.000000001:
			return _fail("elbow_circle_has_no_range_freedom").merged({"elbow_distance_interval": distance_interval})
		var target_angle: float = clampf(elbow_angle, constraints.elbow_min_degrees, constraints.elbow_max_degrees)
		var ratio: float = (l2 * cos(deg_to_rad(target_angle)) - (center - desired_forearm.origin).dot(forearm_axis)) / denominator
		if absf(ratio) > 1.000001:
			return _fail("elbow_range_has_no_circle_solution").merged({"elbow_distance_interval": distance_interval})
		ratio = clampf(ratio, -1.0, 1.0)
		var toward: Vector3 = projected.normalized()
		var sideways: Vector3 = axis.cross(toward).normalized()
		if radial.dot(sideways) < 0.0:
			sideways = -sideways
		desired_shoulder = center + (toward * ratio + sideways * sqrt(maxf(1.0 - ratio * ratio, 0.0))) * radius
	_rotate_toward(pose, rotations, c, u, desired_shoulder)
	_rotate_toward(pose, rotations, u, f, desired_forearm.origin)
	_set_reference_basis(pose, rotations, f, desired_forearm.basis)
	rotations[h] = _vector(hand_local.basis.orthonormalized().get_rotation_quaternion())
	_enforce_upperarm_swing(pose, rotations, indices, constraints.slot_id)
	var realized: Dictionary = forward_kinematics(pose, rotations)
	if not realized.valid:
		return realized
	var metrics: Dictionary = _metrics(realized.transforms, indices, requested_hand_reference, hand_rest, wrist_reference, constraints)
	metrics["changed"] = true
	metrics["upperarm_axial_twist_rad"] = _upperarm_twist(pose, rotations, u)
	metrics["wrist_swing_used"] = wrist_swing
	metrics["helper_twists"] = helper_check.twists
	metrics["shoulder_displacement_m"] = shoulder.distance_to(realized.transforms[u].origin)
	metrics["elbow_displacement_m"] = elbow.distance_to(realized.transforms[f].origin)
	if metrics.valid:
		metrics["pose_rotations"] = rotations
	return metrics

static func forward_kinematics(pose: Dictionary, rotations: PackedVector4Array = PackedVector4Array()) -> Dictionary:
	var resolved: PackedVector4Array = rotations if not rotations.is_empty() else pose.pose_rotations
	var transforms: Array[Transform3D] = []
	var visited := PackedByteArray()
	transforms.resize(resolved.size())
	visited.resize(resolved.size())
	for index: int in resolved.size():
		if not _resolve_bone(pose, resolved, index, transforms, visited):
			return _fail("invalid_pose_parent_hierarchy")
	return {"valid": true, "transforms": transforms}

static func _resolve_bone(pose: Dictionary, rotations: PackedVector4Array, index: int, transforms: Array[Transform3D], visited: PackedByteArray) -> bool:
	if visited[index] == 2:
		return true
	if visited[index] == 1:
		return false
	visited[index] = 1
	var parent: int = pose.parent_indices[index]
	if parent >= transforms.size() or parent < -1:
		return false
	if parent >= 0 and not _resolve_bone(pose, rotations, parent, transforms, visited):
		return false
	var parent_frame: Transform3D = transforms[parent] if parent >= 0 else pose.parent_reference_transforms[index]
	transforms[index] = parent_frame * _local(pose, rotations, index)
	visited[index] = 2
	return transforms[index].is_finite()

static func _local(pose: Dictionary, rotations: PackedVector4Array, index: int) -> Transform3D:
	return Transform3D(Basis(_quaternion(rotations[index])).scaled(pose.pose_scales[index]), pose.pose_positions[index])

static func _set_reference_basis(pose: Dictionary, rotations: PackedVector4Array, index: int, basis: Basis) -> void:
	var globals: Array[Transform3D] = forward_kinematics(pose, rotations).transforms
	var parent: int = pose.parent_indices[index]
	var parent_frame: Transform3D = globals[parent] if parent >= 0 else pose.parent_reference_transforms[index]
	rotations[index] = _vector((parent_frame.basis.inverse() * basis).orthonormalized().get_rotation_quaternion())

static func _rotate_toward(pose: Dictionary, rotations: PackedVector4Array, joint: int, end: int, target: Vector3) -> void:
	var globals: Array[Transform3D] = forward_kinematics(pose, rotations).transforms
	var from: Vector3 = globals[end].origin - globals[joint].origin
	var to: Vector3 = target - globals[joint].origin
	if from.length_squared() <= 0.000001 or to.length_squared() <= 0.000001:
		return
	from = from.normalized()
	to = to.normalized()
	var swing: Quaternion = _direction_swing(from, to)
	_set_reference_basis(pose, rotations, joint, Basis(swing) * globals[joint].basis)

static func _direction_swing(from: Vector3, to: Vector3) -> Quaternion:
	var axis: Vector3 = from.cross(to)
	return Quaternion(axis.normalized(), atan2(axis.length(), clampf(from.dot(to), -1.0, 1.0))).normalized() if axis.length_squared() > 1.0e-16 else Quaternion(from, to).normalized()

static func _enforce_upperarm_swing(pose: Dictionary, rotations: PackedVector4Array, indices: Array[int], slot: StringName) -> void:
	var globals: Array[Transform3D] = forward_kinematics(pose, rotations).transforms
	var c: int = indices[0]
	var u: int = indices[1]
	var f: int = indices[2]
	var h: int = indices[3]
	var direction: Vector3 = globals[f].origin - globals[u].origin
	if direction.length_squared() <= 0.000001:
		return
	var upper_rest: Basis = pose.bone_rest_transforms[u].basis.orthonormalized()
	var neutral_direction: Vector3 = (upper_rest.inverse() * globals[c].basis.orthonormalized().inverse() * direction.normalized()).normalized()
	var polar: float = acos(clampf(neutral_direction.y, -1.0, 1.0))
	var swing := Quaternion.IDENTITY
	if polar > 0.000001:
		var axis: Vector3 = Vector3.UP.cross(neutral_direction)
		axis = Vector3.BACK if axis.length_squared() <= 0.000001 else axis.normalized()
		if slot == &"hand_left":
			axis = -axis
			polar = -polar
		swing = Quaternion(axis, polar).normalized()
	var upper_parent: Basis = (upper_rest * Basis(swing)).orthonormalized()
	var upper_reference: Basis = (globals[c].basis.orthonormalized() * upper_parent).orthonormalized()
	rotations[u] = _vector(upper_parent.get_rotation_quaternion())
	rotations[f] = _vector((upper_reference.inverse() * globals[f].basis.orthonormalized()).orthonormalized().get_rotation_quaternion())
	var after: Array[Transform3D] = forward_kinematics(pose, rotations).transforms
	if after[h].origin.distance_to(globals[h].origin) > FRAME_EPSILON:
		_rotate_toward(pose, rotations, f, h, globals[h].origin)

static func _metrics(globals: Array[Transform3D], indices: Array[int], target: Transform3D, hand_rest: Basis, wrist_reference: float, constraints: Dictionary) -> Dictionary:
	var c: Transform3D = globals[indices[0]]
	var u: Transform3D = globals[indices[1]]
	var f: Transform3D = globals[indices[2]]
	var h: Transform3D = globals[indices[3]]
	var delta: Quaternion = (h.basis.orthonormalized().get_rotation_quaternion().inverse() * target.basis.orthonormalized().get_rotation_quaternion()).normalized()
	var position_error: float = h.origin.distance_to(target.origin)
	var angle_error: float = 2.0 * atan2(Vector3(delta.x, delta.y, delta.z).length(), absf(delta.w))
	var twist_error: float = absf(_wrap(_wrist_twist(h, f, hand_rest) - wrist_reference))
	var shoulder_angle: float = rad_to_deg((c.origin - u.origin).angle_to(f.origin - u.origin))
	var elbow_angle: float = rad_to_deg((u.origin - f.origin).angle_to(h.origin - f.origin))
	var valid: bool = position_error <= POSITION_TOLERANCE_METERS and angle_error <= ANGULAR_TOLERANCE_RADIANS and twist_error <= ANGULAR_TOLERANCE_RADIANS and _in_range(shoulder_angle, constraints.shoulder_min_degrees, constraints.shoulder_max_degrees, constraints.joint_epsilon_degrees) and _in_range(elbow_angle, constraints.elbow_min_degrees, constraints.elbow_max_degrees, constraints.joint_epsilon_degrees)
	var bend: Vector3 = (f.origin - u.origin).cross(h.origin - f.origin)
	return {"valid": valid, "reason": "" if valid else "complete_arm_frame_residual", "position_error_m": position_error, "orientation_error_rad": angle_error, "wrist_twist_change_rad": twist_error, "shoulder_angle_degrees": shoulder_angle, "elbow_angle_degrees": elbow_angle, "bend_normal_reference": bend.normalized(), "bend_normal_valid": bend.length_squared() > 0.00000001, "bone_lengths_preserved": true}

static func _check_helpers(pose: Dictionary, constraints: Dictionary) -> Dictionary:
	var twists: Dictionary = {}
	for chain: Array in constraints.twist_chains:
		var count := 0
		for name: StringName in chain:
			if pose.bone_names.has(name): count += 1
		for name: StringName in chain:
			var index: int = pose.bone_names.find(name)
			if index < 0:
				continue
			if not constraints.twist_neutral_rotations.has(name):
				return _fail("missing_helper_twist_neutral").merged({"bone": name})
			var neutral: Quaternion = constraints.twist_neutral_rotations[name]
			var delta: Quaternion = (neutral.inverse() * _quaternion(pose.pose_rotations[index])).normalized()
			var twist: float = _signed_twist(delta, constraints.limb_twist_axis)
			twists[name] = twist
			if absf(twist) > float(constraints.limb_twist_limit_radians) / maxf(count, 1) + deg_to_rad(constraints.joint_epsilon_degrees):
				return _fail("helper_twist_range").merged({"bone": name, "twist_radians": twist})
	return {"valid": true, "twists": twists}

static func _wrist_twist(hand: Transform3D, forearm: Transform3D, hand_rest: Basis) -> float:
	var axis: Vector3 = (hand.origin - forearm.origin).normalized()
	var neutral: Quaternion = (forearm.basis.orthonormalized() * hand_rest).get_rotation_quaternion()
	var delta: Quaternion = (hand.basis.orthonormalized().get_rotation_quaternion() * neutral.inverse()).normalized()
	return _signed_twist(delta, axis)

static func _signed_twist(rotation: Quaternion, axis: Vector3) -> float:
	var q: Quaternion = rotation.normalized()
	if q.w < 0.0:
		q = Quaternion(-q.x, -q.y, -q.z, -q.w)
	var projected: Vector3 = axis.normalized() * Vector3(q.x, q.y, q.z).dot(axis.normalized())
	if projected.length_squared() <= 0.00000001 and absf(q.w) <= 0.00000001:
		return 0.0
	var twist: Quaternion = Quaternion(projected.x, projected.y, projected.z, q.w).normalized()
	var value: float = 2.0 * atan2(Vector3(twist.x, twist.y, twist.z).length(), twist.w)
	return -value if projected.dot(axis) < 0.0 else value

static func _perpendicular(axis: Vector3, preferred: Vector3) -> Vector3:
	for candidate: Vector3 in [preferred, Vector3.UP, Vector3.RIGHT, Vector3.FORWARD]:
		var perpendicular: Vector3 = candidate - axis * candidate.dot(axis)
		if perpendicular.length_squared() > 0.000001:
			return perpendicular.normalized()
	return Vector3.UP

static func _validate(pose: Dictionary, constraints: Dictionary) -> Dictionary:
	for field: String in ["bone_names", "parent_indices", "parent_reference_transforms", "bone_rest_transforms", "pose_positions", "pose_rotations", "pose_scales"]:
		if not pose.has(field):
			return _fail("missing_pose_" + field)
	var count: int = pose.bone_names.size()
	for field: String in ["parent_indices", "parent_reference_transforms", "bone_rest_transforms", "pose_positions", "pose_rotations", "pose_scales"]:
		if pose[field].size() != count:
			return _fail("misaligned_pose_" + field)
	for index: int in count:
		var position: Vector3 = pose.pose_positions[index]
		var rotation: Vector4 = pose.pose_rotations[index]
		var scale: Vector3 = pose.pose_scales[index]
		if not position.is_finite() or not rotation.is_finite() or rotation.length_squared() <= 0.000000000001 or not scale.is_finite() or minf(scale.x, minf(scale.y, scale.z)) <= 0.000001:
			return _fail("invalid_pose_channel").merged({"bone_index": index})
		if not is_equal_approx(scale.x, scale.y) or not is_equal_approx(scale.x, scale.z):
			return _fail("unsupported_nonuniform_bone_scale").merged({"bone_index": index})
		for field: String in ["parent_reference_transforms", "bone_rest_transforms"]:
			var transform: Transform3D = pose[field][index]
			if not transform.is_finite() or not _supported_basis(transform.basis):
				return _fail("unsupported_" + field).merged({"bone_index": index})
	for field: String in ["slot_id", "clavicle_bone", "upperarm_bone", "forearm_bone", "hand_bone", "shoulder_min_degrees", "shoulder_max_degrees", "elbow_min_degrees", "elbow_max_degrees", "joint_epsilon_degrees", "limb_twist_axis", "limb_twist_limit_radians", "twist_chains", "twist_neutral_rotations", "reference_up", "usable_reach_m"]:
		if not constraints.has(field):
			return _fail("missing_constraint_" + field)
	for field: String in ["shoulder_min_degrees", "shoulder_max_degrees", "elbow_min_degrees", "elbow_max_degrees", "joint_epsilon_degrees", "limb_twist_limit_radians"]:
		if not (constraints[field] is float or constraints[field] is int) or not is_finite(float(constraints[field])) or float(constraints[field]) < 0.0:
			return _fail("invalid_constraint_" + field)
	if constraints.shoulder_min_degrees > constraints.shoulder_max_degrees or constraints.elbow_min_degrees > constraints.elbow_max_degrees or constraints.shoulder_max_degrees > 180.0 or constraints.elbow_max_degrees > 180.0:
		return _fail("invalid_joint_range")
	if not (constraints.usable_reach_m is float or constraints.usable_reach_m is int) or not is_finite(float(constraints.usable_reach_m)) or float(constraints.usable_reach_m) < 0.0:
		return _fail("invalid_usable_reach")
	for field: String in ["limb_twist_axis", "reference_up"]:
		if not constraints[field] is Vector3 or not constraints[field].is_finite() or constraints[field].length_squared() <= 0.000001:
			return _fail("invalid_constraint_" + field)
	for value: Variant in constraints.twist_neutral_rotations.values():
		if not value is Quaternion or not value.is_finite() or value.length_squared() <= 0.000000000001:
			return _fail("invalid_helper_neutral_rotation")
	var indices: Array[int] = []
	for field: String in ["clavicle_bone", "upperarm_bone", "forearm_bone", "hand_bone"]:
		var index: int = pose.bone_names.find(constraints[field])
		if index < 0:
			return _fail("missing_arm_bone_" + field)
		indices.append(index)
	for index: int in range(1, indices.size()):
		if pose.parent_indices[indices[index]] != indices[index - 1]:
			return _fail("unexpected_arm_hierarchy")
	return {"valid": true, "indices": indices}

static func _supported_basis(basis: Basis) -> bool:
	if not basis.is_finite() or basis.determinant() <= 0.000000001:
		return false
	var scale: Vector3 = basis.get_scale()
	if not is_equal_approx(scale.x, scale.y) or not is_equal_approx(scale.x, scale.z):
		return false
	var x: Vector3 = basis.x.normalized()
	var y: Vector3 = basis.y.normalized()
	var z: Vector3 = basis.z.normalized()
	return maxf(absf(x.dot(y)), maxf(absf(x.dot(z)), absf(y.dot(z)))) <= 0.00001

static func _upperarm_twist(pose: Dictionary, rotations: PackedVector4Array, upperarm_index: int) -> float:
	var rest: Quaternion = pose.bone_rest_transforms[upperarm_index].basis.orthonormalized().get_rotation_quaternion()
	return _signed_twist((rest.inverse() * _quaternion(rotations[upperarm_index])).normalized(), Vector3.UP)

static func _quaternion(value: Vector4) -> Quaternion:
	return Quaternion(value.x, value.y, value.z, value.w).normalized()

static func _vector(value: Quaternion) -> Vector4:
	var q: Quaternion = value.normalized()
	return Vector4(q.x, q.y, q.z, q.w)

static func _wrap(value: float) -> float:
	return atan2(sin(value), cos(value))

static func _in_range(value: float, low: float, high: float, epsilon: float) -> bool:
	return value >= low - epsilon and value <= high + epsilon

static func _fail(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
