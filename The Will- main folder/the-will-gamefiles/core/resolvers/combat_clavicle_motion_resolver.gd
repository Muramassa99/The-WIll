extends RefCounted
class_name CombatClavicleMotionResolver

## Two absolute socket-swing coordinates relative to a declared fixed reference.
## Production supplies the immutable Idle home; omitted reference uses rest.
## Inputs are Clavicle -> Spine02 and Upperarm -> Clavicle local transforms.
## The caller retains the named Spine02 ancestry to RL_BoneRoot. No world axis,
## current-pose zero, additional shoulder h allowance or mutable Resource state.
## Axial twist is measured from that reference and held for one request.
## This preserves an old pose's existing twist; it does not enable axial motion.
const REVISION := "fixed_reference_clavicle_swing_v2"
const EPSILON_SQUARED := 1.0e-12
const CHART_MARGIN := 0.00001

static func calibrate(
	clavicle_rest: Transform3D, upperarm_rest: Transform3D,
	clavicle_bone_name: StringName = &"Clavicle", reference_local_basis: Variant = null
) -> Dictionary:
	if not _supported(clavicle_rest) or not _supported(upperarm_rest):
		return _fail("clavicle_rest_nonrigid")
	if upperarm_rest.origin.length_squared() <= EPSILON_SQUARED:
		return _fail("clavicle_rest_socket_offset_missing")
	var reference: Basis = clavicle_rest.basis.orthonormalized()
	var source := "imported_rest"
	if reference_local_basis != null:
		if not reference_local_basis is Basis or not reference_local_basis.is_finite() or not reference_local_basis.is_orthonormal() or reference_local_basis.determinant() <= 0.0:
			return _fail("clavicle_fixed_reference_invalid")
		reference = reference_local_basis
		source = "fixed_idle_pose"
	var fixed_reference := Transform3D(reference * Basis.from_scale(clavicle_rest.basis.get_scale()), clavicle_rest.origin)
	var local_shaft: Vector3 = upperarm_rest.origin.normalized()
	var shaft: Vector3 = (reference * local_shaft).normalized()
	# Choose the most transverse imported material axis, never a guessed world
	# direction. Select in the bone's local frame so parent rotations cannot
	# change the choice through floating-point ties between material axes.
	var selected := 0
	for index: int in range(1, 3):
		if absf(local_shaft[index]) < absf(local_shaft[selected]):
			selected = index
	var transverse: Vector3 = reference[selected]
	transverse = (transverse - shaft * transverse.dot(shaft)).normalized()
	var second: Vector3 = shaft.cross(transverse).normalized()
	var origin_id := StringName(String(clavicle_bone_name).trim_suffix("Clavicle") + "IdlePoseClavicleOrigin") if source == "fixed_idle_pose" else StringName(String(clavicle_bone_name) + "RestSwingOrigin")
	return {"valid": true, "reason": "", "revision": REVISION,
		"rest_transform": clavicle_rest, "upperarm_rest_transform": upperarm_rest,
		"rest_basis": clavicle_rest.basis.orthonormalized(), "reference_basis": reference,
		"fixed_reference_transform": fixed_reference, "reference_source": source,
		"shaft_local": local_shaft, "shaft_parent": shaft,
		"swing_axis_x": transverse, "swing_axis_y": second,
		"transverse_material_axis_index": selected,
		"origin_id": origin_id, "parent_origin_id": &"CC_Base_Spine02",
		"origin_record": {"origin_id": origin_id, "parent_origin_id": &"CC_Base_Spine02",
			"transform_to_parent": fixed_reference, "space_type": &"bone_frame",
			"is_dynamic": false, "owner_system": &"clavicle_rig_calibration",
			"resolve_phase": &"bake_time"},
		"source_bone_name": clavicle_bone_name,
		"source_transform_space": &"parent_bone",
		"swing_coordinate_space": &"CC_Base_Spine02",
		"upperarm_rest_transform_space": clavicle_bone_name,
		"zero_convention": source + "_clavicle_shortest_swing"}

static func measure(
	current_clavicle_local: Transform3D, calibration: Dictionary,
	half_angle_degrees: float = 10.0, held_twist: float = NAN
) -> Dictionary:
	if not _calibration_valid(calibration) or not _supported(current_clavicle_local):
		return _fail("clavicle_measure_reference_invalid")
	if not is_finite(half_angle_degrees) or half_angle_degrees < 0.0 or half_angle_degrees >= 180.0:
		return _fail("clavicle_swing_limit_invalid")
	if not is_nan(held_twist) and not is_finite(held_twist):
		return _fail("clavicle_held_twist_invalid")
	var reference: Basis = calibration.reference_basis
	var current: Basis = current_clavicle_local.basis.orthonormalized()
	var shaft: Vector3 = calibration.shaft_parent
	var moved_shaft: Vector3 = (current * (calibration.shaft_local as Vector3)).normalized()
	var cross: Vector3 = shaft.cross(moved_shaft)
	var sine: float = cross.length()
	var cosine: float = clampf(shaft.dot(moved_shaft), -1.0, 1.0)
	var angle: float = atan2(sine, cosine)
	if angle >= PI - CHART_MARGIN:
		return _fail("clavicle_swing_antipodal_reference")
	var swing := Quaternion.IDENTITY
	var rotation_vector := Vector3.ZERO
	if sine * sine > EPSILON_SQUARED:
		var axis: Vector3 = cross / sine
		swing = Quaternion(axis, angle).normalized()
		rotation_vector = axis * angle
	var remaining: Basis = Basis(swing.inverse()) * current * reference.transposed()
	var axial: Quaternion = remaining.get_rotation_quaternion().normalized()
	var projection: float = Vector3(axial.x, axial.y, axial.z).dot(shaft)
	var twist: float = wrapf(2.0 * atan2(projection, axial.w), -PI, PI)
	var axial_constraint := 0.0
	if not is_nan(held_twist):
		# Only continuity of a fixed captured coordinate, not extra travel.
		twist += round((held_twist - twist) / TAU) * TAU
		axial_constraint = absf(twist - held_twist)
	return {"valid": true, "reason": "", "revision": REVISION,
		"swing_x": rotation_vector.dot(calibration.swing_axis_x),
		"swing_y": rotation_vector.dot(calibration.swing_axis_y),
		"twist": twist, "swing_angle": angle,
		"constraint": angle - deg_to_rad(half_angle_degrees),
		"axial_constraint": axial_constraint, "axial_is_held": not is_nan(held_twist),
		"origin_id": calibration.origin_id, "parent_origin_id": calibration.parent_origin_id}

static func compose(
	swing_x: float, swing_y: float, held_twist: float, calibration: Dictionary,
	source_transform: Transform3D
) -> Dictionary:
	if not _calibration_valid(calibration) or not _supported(source_transform):
		return _fail("clavicle_compose_reference_invalid")
	if not is_finite(swing_x) or not is_finite(swing_y) or not is_finite(held_twist):
		return _fail("clavicle_coordinates_nonfinite")
	var rotation_vector: Vector3 = calibration.swing_axis_x * swing_x + calibration.swing_axis_y * swing_y
	var angle: float = rotation_vector.length()
	if angle >= PI - CHART_MARGIN:
		return _fail("clavicle_swing_chart_exceeded")
	var swing := Quaternion.IDENTITY
	if angle * angle > EPSILON_SQUARED:
		swing = Quaternion(rotation_vector / angle, angle).normalized()
	var axial := Quaternion(calibration.shaft_parent, held_twist).normalized()
	var rotation: Basis = Basis((swing * axial).normalized()) * (calibration.reference_basis as Basis)
	var result := Transform3D(rotation * Basis.from_scale(source_transform.basis.get_scale()), source_transform.origin)
	return {"valid": true, "reason": "", "revision": REVISION,
		"local_transform": result, "origin_id": calibration.origin_id,
		"parent_origin_id": calibration.parent_origin_id}

static func _calibration_valid(calibration: Dictionary) -> bool:
	if not calibration.get("valid", false) or calibration.get("revision", "") != REVISION:
		return false
	for key: String in ["shaft_parent", "shaft_local", "swing_axis_x", "swing_axis_y"]:
		var value: Variant = calibration.get(key)
		if not value is Vector3 or not value.is_finite() or value.length_squared() <= EPSILON_SQUARED:
			return false
	var reference: Variant = calibration.get("reference_basis")
	return reference is Basis and reference.is_finite() and reference.determinant() > 0.0

static func _supported(frame: Transform3D) -> bool:
	return frame.is_finite() and frame.basis.determinant() > 0.0 and frame.basis.is_conformal()

static func _fail(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason, "revision": REVISION}
