extends SceneTree

## Pure coverage/reference contract. Passing does not certify actual rig poses,
## skin, collision, grip, or movement performance.
const Resolver = preload("res://core/resolvers/combat_shoulder_motion_resolver.gd")
const Profile = preload("res://core/defs/shoulder_motion_profile_def.gd")
const LiveProfile = preload("res://core/defs/characters/josie/shoulder_motion_profile.tres")
const PROBE_OFFSET_DEGREES := 0.001
const MAXIMUM_BOUND_JUMP_DEGREES := 0.02
var checks: Array[Dictionary] = []
var out_dir := "C:/WORKSPACE/godot_runs/shoulder_continuous_coverage_20261107"

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			out_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")

func _run() -> void:
	var profile: Dictionary = LiveProfile.as_dictionary()
	var initial_bytes := var_to_bytes(profile)
	_check(profile.get("coverage_mode", "") == "continuous_provisional", "active_profile_uses_continuous_mode")
	_check(profile.get("coverage_schema", "") == "fixed_shoulder_regions_v1", "active_profile_names_fixed_regions")
	var validation := Resolver.validate_profile(profile)
	_check(bool(validation.get("valid", false)), "active_profile_valid", validation)
	if bool(validation.get("valid", false)) and profile.get("coverage_mode", "") == "continuous_provisional":
		_test_grid(profile)
		_test_measured_band(profile)
		_test_poles_and_invalid(profile)
		_test_holes_and_boundaries(profile)
		_test_fixed_reference(profile)
	_test_legacy()
	_check(initial_bytes == var_to_bytes(profile), "sampling_never_mutates_profile_or_adds_donors")
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write continuous shoulder coverage verifier report")
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks,
		"scope": "Pure profile coverage and fixed reference only; provisional endpoints are not anatomical certification.",
		"continuity_probe_offset_degrees": PROBE_OFFSET_DEGREES,
		"maximum_two_sided_bound_jump_degrees": MAXIMUM_BOUND_JUMP_DEGREES}, "\t"))
	file.close()
	print("SHOULDER_CONTINUOUS_COVERAGE passed=%s checks=%d" % [passed, checks.size()])
	quit(0 if passed else 1)

func _test_grid(profile: Dictionary) -> void:
	var coverage_failures: Array = []
	var mirror_failures: Array = []
	var count := 0
	for elevation: int in range(0, 181, 5):
		for plane: int in range(-180, 181, 5):
			var right := _bounds(elevation, plane, 1.0, profile)
			var left := _bounds(elevation, plane, -1.0, profile)
			count += 2
			if not _finite_ordered(right) or not _finite_ordered(left):
				if coverage_failures.size() < 8:
					coverage_failures.append({"elevation": elevation, "plane": plane, "right": right, "left": left})
			if not _same_limits(right, left, 0.000001):
				if mirror_failures.size() < 8:
					mirror_failures.append({"elevation": elevation, "plane": plane, "right": right, "left": left})
	_check(coverage_failures.is_empty(), "bilateral_full_direction_grid_finite_ordered", {"samples": count, "first_failures": coverage_failures})
	_check(mirror_failures.is_empty(), "bilateral_side_neutral_intervals_match", {"samples": count, "first_failures": mirror_failures})

func _test_measured_band(profile: Dictionary) -> void:
	# Independent piecewise-linear interpolation of the published values.
	for side: float in [1.0, -1.0]:
		for plane: float in [0.0, 10.0, 32.5, 45.0, 75.0, 90.0]:
			var t := plane / 32.5 if plane <= 32.5 else (plane - 32.5) / 57.5
			var lower := lerpf(-107.0, -103.0, t) if plane <= 32.5 else lerpf(-103.0, -113.0, t)
			var upper := lerpf(73.0, 65.0, t) if plane <= 32.5 else lerpf(65.0, 41.0, t)
			var result := _bounds(90.0, plane, side, profile)
			_check(_finite_ordered(result) and result.coverage_kind == "measured"
				and absf(rad_to_deg(float(result.minimum_radians)) - lower) < 0.0001
				and absf(rad_to_deg(float(result.maximum_radians)) - upper) < 0.0001,
				"measured_band_preserves_published_interval", {"side": side, "plane": plane, "bounds": result})

func _test_poles_and_invalid(profile: Dictionary) -> void:
	for side: float in [1.0, -1.0]:
		for elevation: float in [0.0, 180.0]:
			var baseline := _bounds(elevation, 0.0, side, profile)
			var equivalent := true
			for plane: int in range(-180, 181, 5):
				equivalent = equivalent and _same_limits(baseline, _bounds(elevation, plane, side, profile), 0.000001)
			_check(equivalent and _finite_ordered(baseline), "pole_interval_independent_of_azimuth", {"side": side, "elevation": elevation})
	for direction: Vector3 in [Vector3.ZERO, Vector3(NAN, 0.0, 0.0), Vector3(INF, 0.0, 0.0)]:
		var result := Resolver.sample_bounds(direction, 1.0, profile)
		_check(not bool(result.get("covered", false)), "invalid_direction_not_given_permissive_coverage", str(direction))

func _test_holes_and_boundaries(profile: Dictionary) -> void:
	for side: float in [1.0, -1.0]:
		for pair: Vector2 in [Vector2(17.0, 23.62), Vector2(60.0, 22.5), Vector2(45.0, 22.5)]:
			_check(_finite_ordered(_bounds(pair.x, pair.y, side, profile)), "previous_neighborhood_hole_is_covered", {"side": side, "elevation": pair.x, "plane": pair.y})
		for elevation: float in [2.0, 30.0, 60.0, 75.0, 90.0, 105.0, 120.0, 150.0]:
			for plane: float in [-180.0, -90.0, -30.0, 0.0, 22.5, 32.5, 45.0, 90.0, 120.0, 180.0]:
				_assert_continuity(_bounds(elevation - PROBE_OFFSET_DEGREES, plane, side, profile),
					_bounds(elevation, plane, side, profile),
					_bounds(elevation + PROBE_OFFSET_DEGREES, plane, side, profile),
					{"axis": "elevation", "side": side, "elevation": elevation, "plane": plane})
		for plane: float in [-180.0, -30.0, 0.0, 32.5, 90.0, 180.0]:
			for elevation: float in [0.0, 2.0, 17.0, 30.0, 60.0, 75.0, 90.0, 105.0, 120.0, 150.0, 180.0]:
				_assert_continuity(_bounds(elevation, plane - PROBE_OFFSET_DEGREES, side, profile),
					_bounds(elevation, plane, side, profile),
					_bounds(elevation, plane + PROBE_OFFSET_DEGREES, side, profile),
					{"axis": "plane", "side": side, "elevation": elevation, "plane": plane})

func _assert_continuity(before: Dictionary, center: Dictionary, after: Dictionary, detail: Dictionary) -> void:
	var maximum_jump := INF
	if _finite_ordered(before) and _finite_ordered(center) and _finite_ordered(after):
		maximum_jump = 0.0
		for field: String in ["minimum_radians", "maximum_radians"]:
			maximum_jump = maxf(maximum_jump, rad_to_deg(absf(float(after[field]) - float(before[field]))))
			maximum_jump = maxf(maximum_jump, rad_to_deg(absf(float(center[field]) - float(before[field]))))
			maximum_jump = maxf(maximum_jump, rad_to_deg(absf(float(after[field]) - float(center[field]))))
	var okay := maximum_jump <= MAXIMUM_BOUND_JUMP_DEGREES
	detail["maximum_jump_degrees"] = maximum_jump
	if not okay:
		detail.merge({"before": before, "center": center, "after": after})
	_check(okay, "bounds_continuous_at_region_or_old_donor_boundary", detail)

func _test_fixed_reference(profile: Dictionary) -> void:
	for side: float in [1.0, -1.0]:
		var calibration := {"valid": true, "revision": Resolver.REVISION, "chest_anatomical_in_bone": Basis.IDENTITY,
			"material_frame_in_upperarm": Basis.IDENTITY, "side_sign": side, "internal_sign": -side,
			"origin_id": &"CC_Base_Spine02ShoulderAnatomicalOrigin"}
		for pair: Vector2 in [Vector2(60.0, 22.5), Vector2(90.0, 45.0), Vector2(150.0, 45.0)]:
			var direction := _direction(pair.x, pair.y, side)
			var baseline := Resolver.sample_bounds(direction, side, profile, -side)
			var identical := true
			for repeat: int in 20:
				identical = identical and Resolver.sample_bounds(direction, side, profile, -side) == baseline
			_check(identical, "repeated_query_does_not_recenter_or_expand_limits", {"side": side, "direction": str(direction)})
			for degrees: float in [-500.0, 500.0]:
				var h := deg_to_rad(degrees)
				var forearm := Transform3D(Basis.IDENTITY, direction)
				var composed := Resolver.compose(Transform3D.IDENTITY, Transform3D.IDENTITY, forearm, calibration, h)
				if not bool(composed.get("valid", false)):
					_check(false, "fixed_reference_can_be_composed_for_large_angle_audit", composed)
					continue
				var measured := Resolver.measure(Transform3D.IDENTITY, Transform3D(composed.upperarm_basis, Vector3.ZERO), forearm, calibration, profile, {"h": h})
				_check(bool(measured.get("valid", false)) and not bool(measured.get("legal", true))
					and absf(float(measured.state.h) - h) < 0.00001
					and _same_limits(baseline, measured, 0.000001),
					"five_hundred_degree_turn_remains_illegal_without_modulo_ratchet", {"side": side, "degrees": degrees, "elevation": pair.x, "plane": pair.y})

func _test_legacy() -> void:
	var legacy: Dictionary = Profile.new().as_dictionary()
	legacy["coverage_mode"] = "measured_band_only"
	legacy["coverage_schema"] = "fixed_shoulder_neighborhoods_v1"
	_check(bool(Resolver.validate_profile(legacy).get("valid", false)), "measured_only_profile_still_valid")
	for side: float in [1.0, -1.0]:
		_check(_finite_ordered(_bounds(90.0, 45.0, side, legacy)), "measured_only_still_covers_original_band", side)
		for pair: Vector2 in [Vector2(17.0, 23.62), Vector2(60.0, 22.5), Vector2(90.0, -30.0), Vector2(150.0, 45.0)]:
			_check(not bool(_bounds(pair.x, pair.y, side, legacy).get("covered", false)), "measured_only_does_not_gain_provisional_coverage", {"side": side, "elevation": pair.x, "plane": pair.y})

func _direction(elevation: float, plane: float, side: float) -> Vector3:
	var e := deg_to_rad(elevation)
	var p := deg_to_rad(plane)
	return Vector3(side * sin(e) * cos(p), -cos(e), -sin(e) * sin(p)).normalized()

func _bounds(elevation: float, plane: float, side: float, profile: Dictionary) -> Dictionary:
	return Resolver.sample_bounds(_direction(elevation, plane, side), side, profile, -side)

func _finite_ordered(result: Dictionary) -> bool:
	return bool(result.get("covered", false)) and is_finite(float(result.get("minimum_radians", NAN))) \
		and is_finite(float(result.get("maximum_radians", NAN))) and float(result.minimum_radians) < float(result.maximum_radians)

func _same_limits(a: Dictionary, b: Dictionary, tolerance: float) -> bool:
	return _finite_ordered(a) and _finite_ordered(b) and absf(float(a.minimum_radians) - float(b.minimum_radians)) <= tolerance \
		and absf(float(a.maximum_radians) - float(b.maximum_radians)) <= tolerance

func _check(passed: bool, label: String, detail: Variant = null) -> void:
	checks.append({"passed": passed, "label": label, "detail": detail})
