extends SceneTree

## Request-local prepared/ordinary numerical parity. Imported Idle provides
## real references; no allocation, grip search, library writes or playback.
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const Shoulder = preload("res://core/resolvers/combat_shoulder_motion_resolver.gd")
const Wrist = preload("res://core/resolvers/combat_wrist_motion_resolver.gd")
var output_dir := "C:/WORKSPACE/godot_runs/prepared_anatomy_context"
var checks: Array[Dictionary] = []
var timings: Dictionary = {}
var rig: PlayerHumanoidRig
var last_difference: Dictionary = {}

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			output_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")

func _run() -> void:
	_check(ClassDB.class_exists(&"CombatMotionAnatomyKernel"), "native_anatomy_class_available")
	Shoulder.configure_native_prepared(true)
	Wrist.configure_native_prepared(true)
	Shoulder.reset_prepared_backend_stats()
	Wrist.reset_prepared_backend_stats()
	rig = RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.reset_authoring_preview_baseline_pose(&"Idle")
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in rig.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).stop(true)
	_check(rig.skeleton != null, "imported_idle_available")
	if rig.skeleton != null:
		for slot: StringName in [&"hand_right", &"hand_left"]:
			_test_shoulder(slot)
			_test_wrist(slot)
	var shoulder_backend := Shoulder.get_prepared_backend_stats()
	var wrist_backend := Wrist.get_prepared_backend_stats()
	_check(shoulder_backend.native_calls > 0, "supported_shoulder_native_dispatch_used", shoulder_backend)
	_check(shoulder_backend.unsupported_coverage_fallbacks > 0, "historical_donor_mode_explicit_reference_fallback", shoulder_backend)
	_check(wrist_backend.native_calls > 0, "wrist_native_dispatch_used", wrist_backend)
	_check(wrist_backend.reference_calls == 0, "supported_wrist_results_do_not_retry_reference", wrist_backend)
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write prepared anatomy context report")
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "timings": timings,
		"backends": {"shoulder": shoulder_backend, "wrist": wrist_backend},
		"scope": "Per-request prepared versus fully checked shoulder/wrist numerical parity; not movement, collision or grip certification."}, "\t"))
	file.close()
	print("PREPARED_ANATOMY_CONTEXT passed=%s checks=%d output=%s" % [passed, checks.size(), output_dir])
	quit(0 if passed else 1)

func _check(passed: bool, name: String, details: Dictionary = {}) -> void:
	if not passed and not last_difference.is_empty():
		details = details.duplicate()
		details.first_difference = last_difference
	checks.append({"passed": passed, "name": name, "details": details})
	last_difference = {}

func _test_shoulder(slot: StringName) -> void:
	var calibration: Dictionary = rig.capture_shoulder_constraint_calibration(slot).duplicate(true)
	var profile: Dictionary = rig.shoulder_motion_profile.as_dictionary()
	var original := var_to_bytes([calibration, profile])
	var chest := rig.skeleton.get_bone_global_pose(rig.skeleton.find_bone(String(calibration.chest_bone_name)))
	var upper := rig.skeleton.get_bone_global_pose(rig.skeleton.find_bone(String(calibration.upperarm_bone_name)))
	var forearm := rig.skeleton.get_bone_global_pose(rig.skeleton.find_bone(String(calibration.forearm_bone_name)))
	var setup := Shoulder.prepare_measurement(calibration, profile)
	_check(setup.get("valid", false), String(slot) + "_shoulder_prepared")
	if not setup.get("valid", false):
		return
	var prepared: Dictionary = setup.prepared
	_check(prepared.is_read_only() and prepared.profile.is_read_only() and prepared.calibration.is_read_only(), String(slot) + "_shoulder_snapshot_containers_readonly")
	_check(var_to_bytes([calibration, profile]) == original and not profile.is_read_only(), String(slot) + "_shoulder_factory_does_not_mutate_inputs")
	var baseline := Shoulder.measure_prepared(chest, upper, forearm, prepared)
	for i: int in 9:
		var rotation := Basis.from_euler(Vector3(0.17 * i, -0.23 * i, 0.31 * i))
		var moved_upper := Transform3D(rotation * upper.basis, upper.origin)
		var moved_forearm := Transform3D(rotation * forearm.basis, upper.origin + rotation * (forearm.origin - upper.origin))
		var prior := {"h": float(i - 4) * PI}
		var checked := Shoulder.measure(chest, moved_upper, moved_forearm, calibration, profile, prior)
		var sampled := Shoulder.measure_prepared(chest, moved_upper, moved_forearm, prepared, prior)
		_check(_same(checked, sampled), "%s_shoulder_direction_branch_%d" % [slot, i])
	var placement := Transform3D(Basis.from_euler(Vector3(0.2, -0.4, 0.1)).scaled(Vector3.ONE * 1.3), Vector3(4.0, -3.0, 2.0))
	_check(_same(Shoulder.measure(placement * chest, placement * upper, placement * forearm, calibration, profile),
		Shoulder.measure_prepared(placement * chest, placement * upper, placement * forearm, prepared)), String(slot) + "_shoulder_root_placement_parity")
	var bad_chest := chest
	bad_chest.basis = bad_chest.basis.scaled(Vector3(1.0, 2.0, 1.0))
	_check(_same(Shoulder.measure(bad_chest, upper, forearm, calibration, profile),
		Shoulder.measure_prepared(bad_chest, upper, forearm, prepared)), String(slot) + "_shoulder_dynamic_nonrigid_still_rejected")
	var degenerate := forearm
	degenerate.origin = upper.origin
	_check(_same(Shoulder.measure(chest, upper, degenerate, calibration, profile),
		Shoulder.measure_prepared(chest, upper, degenerate, prepared)), String(slot) + "_shoulder_dynamic_degeneracy_still_rejected")
	_check(_same(Shoulder.measure(chest, upper, forearm, calibration, profile, {"h": NAN}),
		Shoulder.measure_prepared(chest, upper, forearm, prepared, {"h": NAN})), String(slot) + "_shoulder_nonfinite_branch_still_rejected")
	var invalid := profile.duplicate(true)
	invalid.plane_samples_radians = PackedFloat64Array()
	_check(_same(Shoulder.prepare_measurement(calibration, invalid), Shoulder.measure(chest, upper, forearm, calibration, invalid)), String(slot) + "_shoulder_invalid_profile_rejected_at_preparation")
	var bad_calibration := calibration.duplicate(true)
	bad_calibration.side_sign = 0.0
	_check(_same(Shoulder.prepare_measurement(bad_calibration, profile), Shoulder.measure(chest, upper, forearm, bad_calibration, profile)), String(slot) + "_shoulder_invalid_calibration_rejected_at_preparation")
	_test_shoulder_modes(slot, chest, upper, forearm, calibration, profile)
	if slot == &"hand_right":
		var start := Time.get_ticks_usec()
		for _i: int in 1000:
			Shoulder.measure(chest, upper, forearm, calibration, profile)
		timings.shoulder_checked_us_1000 = Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		for _i: int in 1000:
			Shoulder.measure_prepared(chest, upper, forearm, prepared)
		timings.shoulder_prepared_us_1000 = Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		for _i: int in 1000:
			Shoulder.measure_prepared_reference(chest, upper, forearm, prepared)
		timings.shoulder_prepared_reference_us_1000 = Time.get_ticks_usec() - start
	# A caller's later configuration edit belongs to its next request only.
	profile.minimum_samples_radians[0] -= 0.25
	profile.continuous_regions.lower_minimum_radians -= 0.1
	calibration.side_sign *= -1.0
	_check(_same(baseline, Shoulder.measure_prepared(chest, upper, forearm, prepared)), String(slot) + "_shoulder_snapshot_isolated_from_source_mutation")

func _test_shoulder_modes(slot: StringName, chest: Transform3D, upper: Transform3D, forearm: Transform3D,
		calibration: Dictionary, source_profile: Dictionary) -> void:
	var chest_frame: Basis = chest.basis.orthonormalized() * calibration.chest_anatomical_in_bone
	var side: float = calibration.side_sign
	var length: float = upper.origin.distance_to(forearm.origin)
	# Fixed anatomical directions exercise measured boundaries, uncalibrated
	# historical directions, both poles and the explicit antipode chart seam.
	var directions: Array[Vector3] = [Vector3(side, 0, 0), Vector3(0, 0, -1),
		Vector3(side, 0, -1).normalized(), Vector3(0, -1, 0), Vector3(0, 1, 0),
		Vector3(-side, 0, 0), Vector3(-side, 0.002, 0).normalized(),
		Vector3(side, 0, 0.00001).normalized(), Vector3(0.00001 * side, 0, -1).normalized()]
	for mode: String in ["continuous_provisional", "measured_band_only", "measured_plus_provisional"]:
		var profile := source_profile.duplicate(true)
		profile.coverage_mode = mode
		profile.coverage_schema = "fixed_shoulder_regions_v1" if mode == "continuous_provisional" else "fixed_shoulder_neighborhoods_v1"
		var setup := Shoulder.prepare_measurement(calibration, profile)
		_check(setup.get("valid", false), "%s_%s_prepared_for_backend_parity" % [slot, mode])
		if not setup.get("valid", false):
			continue
		for index: int in directions.size():
			var moved := forearm
			moved.origin = upper.origin + chest_frame * directions[index] * length
			var composed := Shoulder.compose(chest, upper, moved, calibration, 0.2)
			var rotated := upper
			rotated.basis = composed.upperarm_basis
			var oracle := Shoulder.measure(chest, rotated, moved, calibration, profile)
			_check(_same(oracle, Shoulder.measure_prepared_reference(chest, rotated, moved, setup.prepared)),
				"%s_%s_direction_%d_prepared_reference" % [slot, mode, index])
			_check(_same(oracle, Shoulder.measure_prepared(chest, rotated, moved, setup.prepared)),
				"%s_%s_direction_%d_backend" % [slot, mode, index])

func _test_wrist(slot: StringName) -> void:
	var calibration: Dictionary = rig.capture_wrist_constraint_calibration(slot).duplicate(true)
	var profile: Dictionary = rig.wrist_motion_profile.as_dictionary()
	var forearm := rig.skeleton.get_bone_global_pose(rig.skeleton.find_bone(String(calibration.forearm_bone_name)))
	var hand := rig.skeleton.get_bone_global_pose(rig.skeleton.find_bone(String(calibration.hand_bone_name)))
	var full: float = rig.authoring_elbow_full_flexion_radians()
	for frame: String in ["rest_anatomical", "hand_parent_local_xz"]:
		var input_profile := profile.duplicate(true)
		input_profile.bend_frame = frame
		var original := var_to_bytes([calibration, input_profile])
		var setup := Wrist.prepare_kinematics(calibration, input_profile)
		_check(setup.get("valid", false), "%s_%s_wrist_prepared" % [slot, frame])
		if not setup.get("valid", false):
			continue
		var prepared: Dictionary = setup.prepared
		_check(prepared.is_read_only() and prepared.profile.is_read_only() and prepared.calibration.is_read_only(), "%s_%s_wrist_snapshot_readonly" % [slot, frame])
		_check(var_to_bytes([calibration, input_profile]) == original and not input_profile.is_read_only(), "%s_%s_wrist_factory_inputs_unchanged" % [slot, frame])
		for bend: float in [NAN, 0.0, deg_to_rad(45.0), deg_to_rad(90.0), full]:
			for state: Dictionary in [{"rho": 0.0, "beta": 0.0, "gamma": 0.0},
				{"rho": 0.3, "beta": -0.5, "gamma": 0.4}, {"rho": -1.5, "beta": 1.0, "gamma": -1.0}]:
				var checked := Wrist.sample_kinematics(forearm, hand, calibration, input_profile, state, bend, full)
				var sampled := Wrist.sample_kinematics_prepared(forearm, hand, prepared, state, bend, full)
				_check(_same(checked, sampled), "%s_%s_wrist_bend_%s_state_%s" % [slot, frame, bend, state])
				_check(_same(checked, Wrist.sample_kinematics_prepared_reference(forearm, hand, prepared, state, bend, full)),
					"%s_%s_wrist_prepared_reference_%s_%s" % [slot, frame, bend, state])
		var state := {"rho": 0.2, "beta": -0.3, "gamma": 0.1}
		var baseline := Wrist.sample_kinematics_prepared(forearm, hand, prepared, state, 0.7, full)
		var placement := Transform3D(Basis.from_euler(Vector3(-0.3, 0.7, 0.2)).scaled(Vector3.ONE * 0.75), Vector3(-2.0, 4.0, 6.0))
		_check(_same(Wrist.sample_kinematics(placement * forearm, placement * hand, calibration, input_profile, state, 0.7, full),
			Wrist.sample_kinematics_prepared(placement * forearm, placement * hand, prepared, state, 0.7, full)), "%s_%s_wrist_root_placement_parity" % [slot, frame])
		var degenerate := hand
		degenerate.origin = forearm.origin
		_check(_same(Wrist.sample_kinematics(forearm, degenerate, calibration, input_profile, state, 0.7, full),
			Wrist.sample_kinematics_prepared(forearm, degenerate, prepared, state, 0.7, full)), "%s_%s_wrist_dynamic_axis_rejected" % [slot, frame])
		var nonrigid := forearm
		nonrigid.basis = nonrigid.basis.scaled(Vector3(1.0, 2.0, 1.0))
		_check(_same(Wrist.sample_kinematics(nonrigid, hand, calibration, input_profile, state, 0.7, full),
			Wrist.sample_kinematics_prepared(nonrigid, hand, prepared, state, 0.7, full)), "%s_%s_wrist_nonrigid_rejected" % [slot, frame])
		_check(_same(Wrist.sample_kinematics(forearm, hand, calibration, input_profile, {"rho": NAN}, 0.7, full),
			Wrist.sample_kinematics_prepared(forearm, hand, prepared, {"rho": NAN}, 0.7, full)), "%s_%s_wrist_invalid_state_rejected" % [slot, frame])
		_check(_same(Wrist.sample_kinematics(forearm, hand, calibration, input_profile, state, 0.7, 0.0),
			Wrist.sample_kinematics_prepared(forearm, hand, prepared, state, 0.7, 0.0)), "%s_%s_wrist_dynamic_interval_rejected" % [slot, frame])
		var invalid := input_profile.duplicate(true)
		invalid.flexion_limit_radians = -1.0
		_check(_same(Wrist.prepare_kinematics(calibration, invalid), Wrist.sample_kinematics(forearm, hand, calibration, invalid, state)), "%s_%s_invalid_profile_rejected_at_preparation" % [slot, frame])
		var bad_calibration := calibration.duplicate(true)
		bad_calibration.radial_sign = 0.0
		_check(_same(Wrist.prepare_kinematics(bad_calibration, input_profile), Wrist.sample_kinematics(forearm, hand, bad_calibration, input_profile, state)), "%s_%s_invalid_calibration_rejected_at_preparation" % [slot, frame])
		if slot == &"hand_right" and frame == "hand_parent_local_xz":
			var start := Time.get_ticks_usec()
			for _i: int in 1000:
				Wrist.sample_kinematics(forearm, hand, calibration, input_profile, state, 0.7, full)
			timings.wrist_checked_us_1000 = Time.get_ticks_usec() - start
			start = Time.get_ticks_usec()
			for _i: int in 1000:
				Wrist.sample_kinematics_prepared(forearm, hand, prepared, state, 0.7, full)
			timings.wrist_prepared_us_1000 = Time.get_ticks_usec() - start
			start = Time.get_ticks_usec()
			for _i: int in 1000:
				Wrist.sample_kinematics_prepared_reference(forearm, hand, prepared, state, 0.7, full)
			timings.wrist_prepared_reference_us_1000 = Time.get_ticks_usec() - start
		for failure: String in ["legacy_interval", "missing_interval_calibration", "invalid_interval_sign", "invalid_interval_samples"]:
			var test_profile := input_profile.duplicate(true)
			var test_calibration := calibration.duplicate(true)
			match failure:
				"legacy_interval": test_profile.erase("forearm_interval_revision")
				"missing_interval_calibration": test_calibration.erase("forearm_interval_revision")
				"invalid_interval_sign": test_calibration.forearm_pronation_sign = 0.0
				"invalid_interval_samples": test_profile.forearm_elbow_samples_radians = PackedFloat64Array([0.0])
			var test_setup := Wrist.prepare_kinematics(test_calibration, test_profile)
			_check(_same(Wrist.sample_kinematics(forearm, hand, test_calibration, test_profile, state, 0.7, full),
				Wrist.sample_kinematics_prepared(forearm, hand, test_setup.prepared, state, 0.7, full)),
				"%s_%s_%s_native_parity" % [slot, frame, failure])
		input_profile.forearm_pronation_limits_radians[0] -= 0.1
		input_profile.flexion_limit_radians *= 0.5
		_check(_same(baseline, Wrist.sample_kinematics_prepared(forearm, hand, prepared, state, 0.7, full)), "%s_%s_snapshot_isolated_from_source_mutation" % [slot, frame])

func _same(a: Variant, b: Variant) -> bool:
	last_difference = _difference(a, b, "result")
	return last_difference.is_empty()

func _difference(a: Variant, b: Variant, path: String) -> Dictionary:
	if typeof(a) != typeof(b):
		return {"path": path, "expected_type": type_string(typeof(a)), "actual_type": type_string(typeof(b))}
	if a is float:
		return {} if (is_nan(a) and is_nan(b)) or a == b else {"path": path, "expected": a, "actual": b, "difference": b - a}
	if a is Dictionary:
		if a.size() != b.size():
			return {"path": path, "expected_keys": a.keys(), "actual_keys": b.keys()}
		for key: Variant in a:
			if not b.has(key):
				return {"path": path, "missing_key": key}
			var difference := _difference(a[key], b[key], path + "." + String(key))
			if not difference.is_empty(): return difference
		return {}
	if a is Array or a is PackedFloat64Array:
		if a.size() != b.size():
			return {"path": path, "expected_size": a.size(), "actual_size": b.size()}
		for index: int in a.size():
			var difference := _difference(a[index], b[index], path + "[%d]" % index)
			if not difference.is_empty(): return difference
		return {}
	if a is Basis:
		return _difference([a.x, a.y, a.z], [b.x, b.y, b.z], path)
	if a is Vector3:
		return _difference([a.x, a.y, a.z], [b.x, b.y, b.z], path)
	return {} if a == b else {"path": path, "expected": str(a), "actual": str(b)}
