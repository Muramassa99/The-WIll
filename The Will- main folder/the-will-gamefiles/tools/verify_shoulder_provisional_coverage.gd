extends SceneTree

## Pure fixed-reference and coverage policy tests. Fixture endpoints are test
## data, not anatomical recommendations or certification of imported skin.
const Resolver = preload("res://core/resolvers/combat_shoulder_motion_resolver.gd")
const Profile = preload("res://core/defs/shoulder_motion_profile_def.gd")
const Sample = preload("res://core/defs/shoulder_motion_sample_def.gd")
const LiveProfile = preload("res://core/defs/characters/josie/shoulder_motion_profile.tres")
var checks: Array[Dictionary] = []
var out_dir := "C:/WORKSPACE/godot_runs/shoulder_provisional_coverage"

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			out_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")

func _run() -> void:
	var legacy: Dictionary = Profile.new().as_dictionary()
	_check(Resolver.validate_profile(legacy).valid, "default_profile_remains_valid")
	for key: String in ["coverage_schema", "provisional_samples", "maximum_borrow_angle_radians"]:
		legacy.erase(key)
	_check(Resolver.validate_profile(legacy).valid, "old_measured_dictionary_still_valid")
	_check(Resolver.validate_profile(LiveProfile.as_dictionary()).valid, "live_profile_schema_valid")
	var enabled := _profile([])
	_check(Resolver.validate_profile(enabled).valid, "enabled_empty_profile_is_valid")
	for direction: Vector3 in [Vector3.DOWN, Vector3.UP, Vector3.BACK]:
		_check(not Resolver.sample_bounds(direction, 1.0, enabled).covered, "distant_missing_direction_stays_uncovered", direction)
	_check(Resolver.sample_bounds(_direction(80.0, 45.0), 1.0, enabled).covered, "local_gap_borrows_original_measured_arc")
	_check(not Resolver.sample_bounds(_direction(74.0, 45.0), 1.0, enabled).covered, "measured_arc_does_not_extend_beyond_15_degrees")
	_test_lowered()
	_test_transport_and_total_angles()
	_test_intersection_and_no_chaining()
	_test_validation()
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write provisional shoulder policy report")
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks,
		"scope": "Pure fixed anatomical reference, donor bounds and schema. Not imported-rig pose, collision, UI or playback certification."}, "\t"))
	file.close()
	print("SHOULDER_PROVISIONAL_COVERAGE passed=%s checks=%d" % [passed, checks.size()])
	quit(0 if passed else 1)

func _direction(elevation: float, plane: float, side: float = 1.0) -> Vector3:
	var e := deg_to_rad(elevation)
	var p := deg_to_rad(plane)
	return Vector3(side * sin(e) * cos(p), -cos(e), -sin(e) * sin(p)).normalized()

func _row(id: StringName, direction: Vector3, minimum: float, maximum: float) -> Sample:
	var row := Sample.new()
	row.sample_id = id
	row.direction_side_neutral = direction
	row.minimum_degrees = minimum
	row.maximum_degrees = maximum
	row.region_id = &"fixture_local_neighborhood"
	row.provenance_kind = "checked_rig"
	row.can_donate = true
	row.source = "Pure test fixture only; not a live anatomical or inspected Josie row."
	return row

func _profile(rows: Array) -> Dictionary:
	var definition := Profile.new()
	definition.coverage_mode = "measured_plus_provisional"
	for row: Sample in rows:
		definition.provisional_samples.append(row)
	return definition.as_dictionary()

func _calibration(side: float) -> Dictionary:
	return {"valid": true, "revision": Resolver.REVISION, "chest_anatomical_in_bone": Basis.IDENTITY,
		"material_frame_in_upperarm": Basis.IDENTITY, "side_sign": side, "internal_sign": -side,
		"origin_id": &"CC_Base_Spine02ShoulderAnatomicalOrigin"}

func _test_lowered() -> void:
	var row := _row(&"sahara_2020_lowered_mapped", _direction(2.0, 0.0), -65.1, 66.9)
	row.provenance_kind = "original_reference"
	row.source = "Sahara 2020 paired 2-degree abduction reference; engineering mapping to fixed arm-down/forearm-forward zero."
	var profile := _profile([row])
	_check(Resolver.validate_profile(profile).valid, "mapped_paired_lowered_profile_valid")
	for side: float in [1.0, -1.0]:
		var bounds := Resolver.sample_bounds(_direction(2.0, 0.0, side), side, profile)
		_check(bounds.covered and bounds.provisional and absf(rad_to_deg(bounds.minimum_radians) + 65.1) < 0.001
			and absf(rad_to_deg(bounds.maximum_radians) - 66.9) < 0.001,
			"paired_lowered_endpoints_mirror_without_new_zero", {"side": side, "bounds": bounds})
		_check(Resolver.sample_bounds(Vector3.DOWN, side, profile).covered, "stored_lowered_reference_handles_pole", side)
		_check(not Resolver.sample_bounds(_direction(18.0, 0.0, side), side, profile).covered,
			"lowered_row_cannot_donate_outside_15_degrees", side)

func _test_transport_and_total_angles() -> void:
	var donor_neutral := _direction(60.0, 20.0)
	var row := _row(&"transport_fixture", donor_neutral, -20.0, 30.0)
	var profile := _profile([row])
	var snapshot := var_to_bytes(profile)
	for side: float in [1.0, -1.0]:
		var donor := _direction(60.0, 20.0, side)
		var target := _direction(64.0, 30.0, side)
		var calibration := _calibration(side)
		var source_forearm := Transform3D(Basis.IDENTITY, donor)
		var target_forearm := Transform3D(Basis.IDENTITY, target)
		var source_zero := Resolver.compose(Transform3D.IDENTITY, Transform3D.IDENTITY, source_forearm, calibration, 0.0)
		# Transport the actual composed material frame, then measure it in the
		# target frame. This independently observes the offset applied to bounds.
		var transported := Transform3D(Basis(Quaternion(donor, target)) * (source_zero.upperarm_basis as Basis), Vector3.ZERO)
		var reading := Resolver.measure(Transform3D.IDENTITY, transported, target_forearm, calibration, Profile.new().as_dictionary())
		var offset: float = reading.state.h
		var bounds := Resolver.sample_bounds(target, side, profile, -side)
		_check(bounds.covered and absf(bounds.minimum_radians - deg_to_rad(-20.0) - offset) < 0.00001
			and absf(bounds.maximum_radians - deg_to_rad(30.0) - offset) < 0.00001,
			"borrowed_interval_transports_both_endpoints_in_fixed_frame", {"side": side, "offset": offset, "bounds": bounds})
		for turn: float in [0.0, 29.0, 31.0, 180.0, 359.0, 500.0]:
			var requested := deg_to_rad(turn) + offset
			var composed := Resolver.compose(Transform3D.IDENTITY, Transform3D.IDENTITY, target_forearm, calibration, requested)
			var measured := Resolver.measure(Transform3D.IDENTITY, Transform3D(composed.upperarm_basis, Vector3.ZERO), target_forearm,
				calibration, profile, {"h": requested})
			_check(measured.valid and absf(float(measured.state.h) - requested) < 0.00001
				and measured.legal == (turn <= 30.0) and absf(measured.minimum_radians - bounds.minimum_radians) < 0.00001,
				"repeated_angles_do_not_rebase_or_expand_interval", {"side": side, "turn": turn})
		var roundtrip: Dictionary = bytes_to_var(var_to_bytes(profile))
		_check(Resolver.sample_bounds(target, side, roundtrip) == bounds, "serialized_profile_keeps_identical_interval", side)
	_check(var_to_bytes(profile) == snapshot, "sampling_does_not_mutate_or_extend_donors")

func _test_intersection_and_no_chaining() -> void:
	var first := _row(&"first", _direction(60.0, 20.0), -20.0, 20.0)
	var second := _row(&"second", _direction(65.0, 20.0), -10.0, 10.0)
	var target := _direction(62.0, 20.0)
	var a := Resolver.sample_bounds(target, 1.0, _profile([first]))
	var b := Resolver.sample_bounds(target, 1.0, _profile([second]))
	var both := Resolver.sample_bounds(target, 1.0, _profile([first, second]))
	_check(both.covered and both.coverage_sources.size() == 2
		and absf(both.minimum_radians - maxf(a.minimum_radians, b.minimum_radians)) < 0.00001
		and absf(both.maximum_radians - minf(a.maximum_radians, b.maximum_radians)) < 0.00001,
		"overlapping_neighborhoods_keep_tighter_aligned_interval")
	second.direction_side_neutral = first.direction_side_neutral
	first.minimum_degrees = -30.0
	first.maximum_degrees = -20.0
	second.minimum_degrees = 20.0
	second.maximum_degrees = 30.0
	var conflict := Resolver.sample_bounds(first.direction_side_neutral, 1.0, _profile([first, second]))
	_check(not conflict.covered and conflict.reason == "shoulder_provisional_intervals_disjoint",
		"empty_intersection_is_not_invented_motion", conflict)
	first.provenance_kind = "provisional"
	first.can_donate = false
	var non_donor := _profile([first])
	_check(Resolver.sample_bounds(first.direction_side_neutral, 1.0, non_donor).covered
		and not Resolver.sample_bounds(target, 1.0, non_donor).covered, "provisional_result_cannot_become_a_donor")
	first.provenance_kind = "checked_rig"
	first.can_donate = true
	first.side = "hand_right"
	_check(not Resolver.sample_bounds(_direction(60.0, 20.0, -1.0), -1.0, _profile([first])).covered,
		"side_specific_inspection_does_not_certify_other_arm")
	var near_measured := _row(&"narrow_near_measured", _direction(80.0, 45.0), -1.0, 1.0)
	var measured := Resolver.sample_bounds(_direction(90.0, 45.0), 1.0, _profile([near_measured]))
	var original := Resolver.sample_bounds(_direction(90.0, 45.0), 1.0, Profile.new().as_dictionary())
	_check(measured.coverage_kind == "measured" and not measured.provisional
		and measured.minimum_radians == original.minimum_radians and measured.maximum_radians == original.maximum_radians,
		"measured_band_is_not_narrowed_by_a_provisional_neighbor")

func _test_validation() -> void:
	var row := _row(&"invalid_fixture", _direction(60.0, 20.0), -10.0, 10.0)
	var profile := _profile([row])
	profile.maximum_borrow_angle_radians = deg_to_rad(15.1)
	_check(not Resolver.validate_profile(profile).valid, "borrow_radius_cannot_exceed_15_degrees")
	row.provenance_kind = "provisional"
	_check(not Resolver.validate_profile(_profile([row])).valid, "unchecked_provisional_row_cannot_donate")
	row.provenance_kind = "checked_rig"
	row.origin_id = &"arbitrary_world_zero"
	_check(not Resolver.validate_profile(_profile([row])).valid, "sample_requires_named_chest_to_root_reference")

func _check(passed: bool, label: String, detail: Variant = null) -> void:
	checks.append({"passed": passed, "label": label, "detail": detail})
	if not passed:
		push_error(label + ": " + str(detail))
