extends RefCounted
class_name CombatShoulderMotionResolver

## Pure chest-relative measurement/composition. All poses share a caller-named
## reference (Skeleton3D or captured replay reference) whose chain reaches
## RL_BoneRoot. No world axes, scene writes, IK or changing neutral reference.
const REVISION := "chest_relative_shoulder_v1"
const EPSILON_SQUARED := 1.0e-12
const ANTIPODE_EPSILON := 1.0e-6
const COVERAGE_SCHEMA := "fixed_shoulder_neighborhoods_v1"
const CONTINUOUS_COVERAGE_SCHEMA := "fixed_shoulder_regions_v1"
const ANATOMICAL_ORIGIN := "CC_Base_Spine02ShoulderAnatomicalOrigin"
const ZERO_CONVENTION := "sideways_upperarm_forearm_forward_shortest_swing"
# Keep the prepared reference default until full-output native sampling earns
# its place in the request benchmark; unsupported historic donor modes remain
# explicit reference fallbacks even when native is enabled for profiling.
static var _native_prepared_enabled := false
static var _native_prepared_kernel: RefCounted
static var _native_prepared_missing_warned := false
static var _prepared_backend_stats := {"native_calls": 0, "reference_calls": 0, "unsupported_coverage_fallbacks": 0}

static func configure_native_prepared(enabled: bool) -> void:
	_native_prepared_enabled = enabled

static func get_prepared_backend_stats() -> Dictionary:
	return _prepared_backend_stats.duplicate()

static func reset_prepared_backend_stats() -> void:
	_prepared_backend_stats = {"native_calls": 0, "reference_calls": 0, "unsupported_coverage_fallbacks": 0}

static func _prepared_native_kernel() -> RefCounted:
	if not _native_prepared_enabled:
		return null
	if _native_prepared_kernel == null and ClassDB.class_exists(&"CombatMotionAnatomyKernel"):
		_native_prepared_kernel = ClassDB.instantiate(&"CombatMotionAnatomyKernel") as RefCounted
	if _native_prepared_kernel == null and not _native_prepared_missing_warned:
		_native_prepared_missing_warned = true
		push_warning("Native prepared shoulder math unavailable; using the GDScript reference.")
	return _native_prepared_kernel

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
	var coverage := String(profile.get("coverage_mode", ""))
	if coverage not in ["measured_band_only", "measured_plus_provisional", "continuous_provisional"]:
		return _fail("shoulder_profile_unknown_coverage")
	if coverage == "continuous_provisional":
		return _validate_continuous_regions(profile)
	if coverage == "measured_plus_provisional":
		if String(profile.get("coverage_schema", "")) != COVERAGE_SCHEMA:
			return _fail("shoulder_profile_coverage_schema")
		var radius: float = float(profile.get("maximum_borrow_angle_radians", NAN))
		if not is_finite(radius) or radius < 0.0 or radius > deg_to_rad(15.0):
			return _fail("shoulder_profile_borrow_radius")
		var samples: Variant = profile.get("provisional_samples")
		if not samples is Array:
			return _fail("shoulder_profile_provisional_layout")
		var ids: Dictionary = {}
		for sample: Variant in samples:
			if not sample is Dictionary:
				return _fail("shoulder_profile_provisional_sample")
			var direction: Variant = sample.get("direction_side_neutral")
			if not direction is Vector3 or not direction.is_finite() or direction.length_squared() <= EPSILON_SQUARED:
				return _fail("shoulder_profile_provisional_direction")
			var minimum: float = float(sample.get("minimum_radians", NAN))
			var maximum: float = float(sample.get("maximum_radians", NAN))
			if not is_finite(minimum) or not is_finite(maximum) or minimum >= maximum:
				return _fail("shoulder_profile_provisional_interval")
			if String(sample.get("side", "")) not in ["both", "hand_right", "hand_left"]:
				return _fail("shoulder_profile_provisional_side")
			var kind := String(sample.get("provenance_kind", ""))
			if kind not in ["original_reference", "checked_rig", "provisional"] or (bool(sample.get("can_donate", false)) and kind == "provisional"):
				return _fail("shoulder_profile_provisional_donor")
			for field: String in ["sample_id", "region_id", "source"]:
				if String(sample.get(field, "")).strip_edges().is_empty():
					return _fail("shoulder_profile_provisional_missing_" + field)
			if String(sample.get("origin_id", "")) != ANATOMICAL_ORIGIN or String(sample.get("parent_origin_id", "")) != "CC_Base_Spine02" or String(sample.get("machine_origin_id", "")) != "RL_BoneRoot" or String(sample.get("zero_convention", "")) != ZERO_CONVENTION:
				return _fail("shoulder_profile_provisional_reference")
			var id := String(sample.sample_id) + ":" + String(sample.side)
			if ids.has(id):
				return _fail("shoulder_profile_provisional_duplicate")
			ids[id] = true
	return {"valid": true, "reason": ""}

static func measure(chest: Transform3D, upperarm: Transform3D, forearm: Transform3D,
		calibration: Dictionary, profile: Dictionary, previous_state: Dictionary = {}) -> Dictionary:
	var validation := validate_profile(profile)
	if not validation.valid:
		return validation
	var context := _context(chest, upperarm, forearm, calibration)
	if not context.valid:
		return context
	if String(profile.get("coverage_mode", "")) != "measured_band_only" and String(calibration.get("origin_id", "")) != ANATOMICAL_ORIGIN:
		return _fail("shoulder_profile_calibration_origin_mismatch")
	return _measure_with_context(upperarm, calibration, profile, previous_state, context)

## One request owns this copied profile/calibration. Only invariant validation
## is prepared; poses, direction-dependent bounds and angular branches are not.
static func prepare_measurement(calibration: Dictionary, profile: Dictionary) -> Dictionary:
	var validation := validate_profile(profile)
	if not validation.valid:
		return validation
	if not calibration.get("valid", false) or String(calibration.get("revision", "")) != REVISION:
		return _fail("shoulder_calibration_invalid")
	validation = _validate_calibration_values(calibration)
	if not validation.valid:
		return validation
	if String(profile.get("coverage_mode", "")) != "measured_band_only" and String(calibration.get("origin_id", "")) != ANATOMICAL_ORIGIN:
		return _fail("shoulder_profile_calibration_origin_mismatch")
	var prepared := {"owner": "shoulder_measurement_v1", "calibration": calibration.duplicate(true), "profile": profile.duplicate(true)}
	_lock_prepared_containers(prepared)
	return {"valid": true, "prepared": prepared}

static func measure_prepared(chest: Transform3D, upperarm: Transform3D, forearm: Transform3D,
		prepared: Dictionary, previous_state: Dictionary = {}) -> Dictionary:
	if prepared.get("owner", "") != "shoulder_measurement_v1":
		return _fail("shoulder_prepared_context_invalid")
	var mode := String(prepared.profile.get("coverage_mode", ""))
	if mode in ["continuous_provisional", "measured_band_only"]:
		var kernel := _prepared_native_kernel()
		if kernel != null:
			_prepared_backend_stats.native_calls += 1
			# A native numerical rejection remains a rejection, never a retry.
			return kernel.call(&"measure_shoulder", chest, upperarm, forearm, prepared, previous_state)
	elif _native_prepared_enabled:
		# Historical donor-neighborhood profiles deliberately retain their
		# complete reference calculation; no partial native approximation.
		_prepared_backend_stats.unsupported_coverage_fallbacks += 1
	_prepared_backend_stats.reference_calls += 1
	return measure_prepared_reference(chest, upperarm, forearm, prepared, previous_state)

static func measure_prepared_reference(chest: Transform3D, upperarm: Transform3D, forearm: Transform3D,
		prepared: Dictionary, previous_state: Dictionary = {}) -> Dictionary:
	if prepared.get("owner", "") != "shoulder_measurement_v1":
		return _fail("shoulder_prepared_context_invalid")
	# Dynamic transform checks remain identical to the ordinary entry point.
	for frame: Transform3D in [chest, upperarm, forearm]:
		if not frame.is_finite() or frame.basis.determinant() <= 0.0 or not frame.basis.is_conformal():
			return _fail("shoulder_pose_nonrigid")
	var context := _context_geometry(chest, upperarm, forearm, prepared.calibration)
	if not context.valid:
		return context
	return _measure_with_context(upperarm, prepared.calibration, prepared.profile, previous_state, context)

static func _measure_with_context(upperarm: Transform3D, calibration: Dictionary, profile: Dictionary,
		previous_state: Dictionary, context: Dictionary) -> Dictionary:
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
	var bounds := sample_bounds(shaft, float(calibration.side_sign), profile, float(calibration.internal_sign))
	var violations := PackedFloat64Array()
	var legal := false
	if bounds.covered:
		violations.append(float(bounds.minimum_radians) - h)
		violations.append(h - float(bounds.maximum_radians))
		legal = maxf(violations[0], violations[1]) <= float(profile.angle_epsilon_radians)
	return {"valid": true, "legal": legal, "covered": bool(bounds.covered),
		"reason": "" if bounds.covered else bounds.get("reason", "shoulder_direction_not_calibrated"),
		"state": {"h": h}, "minimum_radians": bounds.minimum_radians,
		"maximum_radians": bounds.maximum_radians, "violations": violations,
		"direction_anatomical": shaft, "plane_radians": bounds.plane_radians,
		"elevation_radians": bounds.elevation_radians, "revision": REVISION,
		"origin_id": calibration.origin_id, "reference_chart": context.reference_chart,
		"reference_warning": context.reference_warning,
		"coverage_kind": bounds.coverage_kind, "provisional": bounds.provisional,
		"coverage_sources": bounds.coverage_sources, "coverage_schema": profile.get("coverage_schema", "measured_band_only")}

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

static func sample_bounds(direction_anatomical: Vector3, side_sign: float, profile: Dictionary, internal_sign: float = 0.0) -> Dictionary:
	var result := {"covered": false, "minimum_radians": 0.0, "maximum_radians": 0.0,
		"plane_radians": 0.0, "elevation_radians": 0.0,
		"coverage_kind": "uncovered", "provisional": false, "coverage_sources": [],
		"reason": "shoulder_direction_not_calibrated"}
	if not direction_anatomical.is_finite() or direction_anatomical.length_squared() <= EPSILON_SQUARED or absf(side_sign) != 1.0:
		return result
	var u := direction_anatomical.normalized()
	var plane: float = atan2(-u.z, u.x * side_sign)
	var elevation: float = acos(clampf(-u.y, -1.0, 1.0))
	result.plane_radians = plane
	result.elevation_radians = elevation
	if internal_sign == 0.0:
		# The named Josie reference exercise defines this relation. Runtime
		# passes its calibrated sign explicitly; pure profile callers may omit it.
		internal_sign = -side_sign
	if absf(internal_sign) != 1.0:
		return result
	var planes: PackedFloat64Array = profile.plane_samples_radians
	var epsilon: float = profile.angle_epsilon_radians
	if absf(elevation - float(profile.sampled_elevation_radians)) <= epsilon and plane >= planes[0] - epsilon and plane <= planes[-1] + epsilon:
		var measured := _measured_interval(clampf(plane, planes[0], planes[-1]), profile)
		result.merge(measured, true)
		result.covered = true
		result.coverage_kind = "measured"
		result.reason = ""
		result.coverage_sources = [{"sample_id": "mccully_2005_measured_band", "provenance_kind": "original_reference",
			"source": profile.get("source", ""), "plane_radians": plane, "provisional": false}]
		# A checked nearby fallback must not silently narrow an authoritative
		# measured direction. Local borrowing applies only to missing coverage.
		return result
	if String(profile.get("coverage_mode", "")) == "continuous_provisional":
		return _continuous_bounds(result, profile)
	if String(profile.get("coverage_mode", "measured_band_only")) != "measured_plus_provisional":
		return result
	var radius: float = profile.maximum_borrow_angle_radians
	var aligned: Array[Dictionary] = []
	var nearest := _nearest_measured_direction(u, side_sign, profile)
	if float(nearest.distance) <= radius + epsilon:
		var interval := _measured_interval(float(nearest.plane), profile)
		var source := {"sample_id": "mccully_2005_measured_band", "region_id": "shoulder_height",
			"provenance_kind": "original_reference", "source": profile.get("source", ""), "provisional": true}
		aligned.append(_transport_interval(nearest.direction, u, side_sign, internal_sign,
			interval.minimum_radians, interval.maximum_radians, source))
	var side_name := "hand_right" if side_sign > 0.0 else "hand_left"
	for sample: Dictionary in profile.provisional_samples:
		if String(sample.side) not in ["both", side_name]:
			continue
		var neutral: Vector3 = sample.direction_side_neutral
		var donor := Vector3(neutral.x * side_sign, neutral.y, neutral.z).normalized()
		var distance: float = _direction_distance(donor, u)
		var exact := distance <= epsilon
		# Only original or inspected rows can donate. A borrowed evaluation
		# never enters the immutable sample list and cannot extend the radius.
		if not exact and (not bool(sample.can_donate) or String(sample.provenance_kind) == "provisional" or distance > radius + epsilon):
			continue
		var source := {"sample_id": sample.sample_id, "side": sample.side, "region_id": sample.region_id,
			"provenance_kind": sample.provenance_kind, "source": sample.source,
			"provisional": bool(sample.get("provisional", true)) or not exact,
			"origin_id": sample.origin_id, "machine_origin_id": sample.machine_origin_id}
		aligned.append(_transport_interval(donor, u, side_sign, internal_sign,
			sample.minimum_radians, sample.maximum_radians, source))
	if aligned.is_empty():
		return result
	var minimum := -INF
	var maximum := INF
	for interval: Dictionary in aligned:
		if not interval.get("valid", false):
			return result
		minimum = maxf(minimum, float(interval.minimum_radians))
		maximum = minf(maximum, float(interval.maximum_radians))
		result.coverage_sources.append(interval.source)
		result.provisional = result.provisional or bool(interval.source.provisional)
	if minimum >= maximum:
		result.reason = "shoulder_provisional_intervals_disjoint"
		result.coverage_kind = "conflicting_samples"
		return result
	result.minimum_radians = minimum
	result.maximum_radians = maximum
	result.covered = true
	result.reason = ""
	result.coverage_kind = "provisional" if result.provisional else "checked"
	return result

## A finite engineering envelope in the SAME fixed h convention used by
## measure/compose. Direction selects bounds, never a new zero or drag budget.
## The old +/-10 inspected poses remain evidence; their donor disks no longer
## cut holes or intersect the broad lowered reference during ordinary reach.
static func _validate_continuous_regions(profile: Dictionary) -> Dictionary:
	if String(profile.get("coverage_schema", "")) != CONTINUOUS_COVERAGE_SCHEMA:
		return _fail("shoulder_profile_coverage_schema")
	var regions: Variant = profile.get("continuous_regions")
	if not regions is Dictionary:
		return _fail("shoulder_profile_continuous_regions")
	for field: String in ["lower_elevation_radians", "upper_elevation_radians", "posterior_transition_plane_radians"]:
		if not is_finite(float(regions.get(field, NAN))):
			return _fail("shoulder_profile_missing_" + field)
	var height: float = profile.sampled_elevation_radians
	if regions.lower_elevation_radians < 0.0 or regions.lower_elevation_radians >= height or regions.upper_elevation_radians <= height or regions.upper_elevation_radians > PI:
		return _fail("shoulder_profile_region_elevations")
	var planes: PackedFloat64Array = profile.plane_samples_radians
	if planes[0] != 0.0 or planes[-1] >= PI or regions.posterior_transition_plane_radians <= -PI or regions.posterior_transition_plane_radians >= planes[0]:
		return _fail("shoulder_profile_region_planes")
	for region: String in ["lower", "upper", "posterior"]:
		var minimum: float = float(regions.get(region + "_minimum_radians", NAN))
		var maximum: float = float(regions.get(region + "_maximum_radians", NAN))
		if not is_finite(minimum) or not is_finite(maximum) or minimum >= maximum or maximum - minimum >= TAU:
			return _fail("shoulder_profile_region_interval")
		if String(regions.get(region + "_source", "")).strip_edges().is_empty():
			return _fail("shoulder_profile_region_source")
	if String(regions.get("zero_convention", "")) != ZERO_CONVENTION or String(regions.get("origin_id", "")) != ANATOMICAL_ORIGIN or String(regions.get("machine_origin_id", "")) != "RL_BoneRoot":
		return _fail("shoulder_profile_region_reference")
	return {"valid": true, "reason": ""}

static func _continuous_bounds(result: Dictionary, profile: Dictionary) -> Dictionary:
	var regions: Dictionary = profile.continuous_regions
	var planes: PackedFloat64Array = profile.plane_samples_radians
	var plane: float = result.plane_radians
	var elevation: float = result.elevation_radians
	var posterior := Vector2(regions.posterior_minimum_radians, regions.posterior_maximum_radians)
	var horizontal: Vector2
	if plane < planes[0]:
		var side := _measured_interval(planes[0], profile)
		horizontal = posterior.lerp(Vector2(side.minimum_radians, side.maximum_radians),
			_region_blend(regions.posterior_transition_plane_radians, planes[0], plane))
	elif plane > planes[-1]:
		var front := _measured_interval(planes[-1], profile)
		horizontal = Vector2(front.minimum_radians, front.maximum_radians).lerp(posterior,
			_region_blend(planes[-1], PI, plane))
	else:
		var measured := _measured_interval(plane, profile)
		horizontal = Vector2(measured.minimum_radians, measured.maximum_radians)
	var bounds: Vector2
	var region: String
	if elevation <= float(profile.sampled_elevation_radians):
		bounds = Vector2(regions.lower_minimum_radians, regions.lower_maximum_radians).lerp(horizontal,
			_region_blend(regions.lower_elevation_radians, profile.sampled_elevation_radians, elevation))
		region = "lower_to_shoulder_height"
	else:
		bounds = horizontal.lerp(Vector2(regions.upper_minimum_radians, regions.upper_maximum_radians),
			_region_blend(profile.sampled_elevation_radians, regions.upper_elevation_radians, elevation))
		region = "shoulder_height_to_upper"
	# Both poles have one fixed interval; atan2's arbitrary azimuth there must
	# not change the limits. All regions are immutable profile data, not donors
	# recursively derived from prior poses. This is provisional, not clinical ROM.
	result.merge({"covered": true, "reason": "", "coverage_kind": "provisional_continuous",
		"provisional": true, "minimum_radians": float(bounds.x), "maximum_radians": float(bounds.y),
		"coverage_sources": [{"sample_id": region, "provenance_kind": "provisional",
			"origin_id": ANATOMICAL_ORIGIN, "machine_origin_id": "RL_BoneRoot",
			"zero_convention": ZERO_CONVENTION, "source": regions.lower_source + "; " + String(profile.get("source", "")) + "; " + regions.upper_source + "; " + regions.posterior_source,
			"provisional": true}]}, true)
	return result

static func _region_blend(start: float, end: float, value: float) -> float:
	var t := clampf((value - start) / (end - start), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func _measured_interval(plane: float, profile: Dictionary) -> Dictionary:
	var planes: PackedFloat64Array = profile.plane_samples_radians
	for i: int in range(planes.size() - 1):
		if plane > planes[i + 1]:
			continue
		var weight: float = (plane - planes[i]) / (planes[i + 1] - planes[i])
		return {"minimum_radians": lerpf(profile.minimum_samples_radians[i], profile.minimum_samples_radians[i + 1], weight),
			"maximum_radians": lerpf(profile.maximum_samples_radians[i], profile.maximum_samples_radians[i + 1], weight)}
	return {"minimum_radians": profile.minimum_samples_radians[-1], "maximum_radians": profile.maximum_samples_radians[-1]}

static func _nearest_measured_direction(u: Vector3, side: float, profile: Dictionary) -> Dictionary:
	var planes: PackedFloat64Array = profile.plane_samples_radians
	var plane := clampf(atan2(-u.z, u.x * side), planes[0], planes[-1])
	var elevation: float = profile.sampled_elevation_radians
	var best := {"distance": INF, "plane": plane, "direction": Vector3.ZERO}
	# Endpoints also matter when atan2 crosses its branch on the far side.
	for candidate: float in [plane, planes[0], planes[-1]]:
		var direction := Vector3(side * sin(elevation) * cos(candidate), -cos(elevation), -sin(elevation) * sin(candidate))
		var distance: float = _direction_distance(u, direction)
		if distance < float(best.distance):
			best = {"distance": distance, "plane": candidate, "direction": direction.normalized()}
	return best

static func _transport_interval(donor: Vector3, target: Vector3, side: float, internal: float,
		minimum: float, maximum: float, source: Dictionary) -> Dictionary:
	var donor_reference := fixed_reference(donor, side)
	var target_reference := fixed_reference(target, side)
	if not donor_reference.valid or not target_reference.valid:
		return {"valid": false}
	var transported: Vector3 = Basis(Quaternion(donor, target)) * (donor_reference.zero_hinge as Vector3)
	transported = (transported - target * target.dot(transported)).normalized()
	var zero: Vector3 = target_reference.zero_hinge
	var offset: float = internal * atan2(target.dot(zero.cross(transported)), zero.dot(transported))
	var evidence := source.duplicate(true)
	evidence["distance_radians"] = _direction_distance(donor, target)
	evidence["zero_offset_radians"] = offset
	evidence["minimum_radians"] = minimum + offset
	evidence["maximum_radians"] = maximum + offset
	return {"valid": true, "minimum_radians": minimum + offset, "maximum_radians": maximum + offset, "source": evidence}

static func _direction_distance(a: Vector3, b: Vector3) -> float:
	# Stable near matching float32 unit vectors; acos(dot) can turn identical
	# samples into a false nonzero separation after normalization rounding.
	return atan2(a.cross(b).length(), a.dot(b))

static func _context(chest: Transform3D, upperarm: Transform3D, forearm: Transform3D, calibration: Dictionary) -> Dictionary:
	if not calibration.get("valid", false) or String(calibration.get("revision", "")) != REVISION:
		return _fail("shoulder_calibration_invalid")
	for frame: Transform3D in [chest, upperarm, forearm]:
		if not frame.is_finite() or frame.basis.determinant() <= 0.0 or not frame.basis.is_conformal():
			return _fail("shoulder_pose_nonrigid")
	var validation := _validate_calibration_values(calibration)
	if not validation.valid:
		return validation
	return _context_geometry(chest, upperarm, forearm, calibration)

static func _validate_calibration_values(calibration: Dictionary) -> Dictionary:
	for field: String in ["chest_anatomical_in_bone", "material_frame_in_upperarm"]:
		var value: Variant = calibration.get(field)
		if not value is Basis or not value.is_finite() or not value.is_equal_approx(value.orthonormalized()) or value.determinant() <= 0.0:
			return _fail("shoulder_calibration_invalid_" + field)
	var side: float = float(calibration.get("side_sign", 0.0))
	var internal: float = float(calibration.get("internal_sign", 0.0))
	if absf(side) != 1.0 or absf(internal) != 1.0:
		return _fail("shoulder_calibration_invalid_sign")
	return {"valid": true}

static func _context_geometry(chest: Transform3D, upperarm: Transform3D, forearm: Transform3D, calibration: Dictionary) -> Dictionary:
	var chest_frame: Basis = chest.basis.orthonormalized() * (calibration.chest_anatomical_in_bone as Basis)
	var shaft := forearm.origin - upperarm.origin
	if shaft.length_squared() <= EPSILON_SQUARED:
		return _fail("shoulder_zero_length_upperarm")
	var u: Vector3 = (chest_frame.transposed() * shaft).normalized()
	var reference := fixed_reference(u, float(calibration.side_sign))
	if not reference.valid:
		return reference
	return {"valid": true, "chest_frame": chest_frame, "direction": u, "zero_hinge": reference.zero_hinge,
		"reference_chart": reference.reference_chart, "reference_warning": reference.reference_warning}

static func _lock_prepared_containers(value: Variant) -> void:
	if value is Dictionary:
		for key: Variant in value:
			_lock_prepared_containers(value[key])
		value.make_read_only()
	elif value is Array:
		for item: Variant in value:
			_lock_prepared_containers(item)
		value.make_read_only()

## Shared by measuring, composing and donor alignment. Input axes belong to
## CC_Base_Spine02ShoulderAnatomicalOrigin, whose parent chain reaches root.
## No accepted pose or prior gesture can redefine this zero.
static func fixed_reference(direction_anatomical: Vector3, side: float) -> Dictionary:
	if not direction_anatomical.is_finite() or direction_anatomical.length_squared() <= EPSILON_SQUARED or absf(side) != 1.0:
		return _fail("shoulder_fixed_reference_invalid")
	var u := direction_anatomical.normalized()
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
	return {"valid": true, "direction": u, "zero_hinge": zero,
		"reference_chart": reference_chart, "reference_warning": reference_warning}

static func _fail(reason: String) -> Dictionary:
	return {"valid": false, "legal": false, "covered": false, "reason": reason, "revision": REVISION}
