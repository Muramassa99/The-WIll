extends SceneTree

## Independent small FK fixtures: locked channels must neither be sampled nor
## change movement/limits versus the equivalent reduced-coordinate mechanism.
## Fixture coordinates belong to AllocatorFixedCoordinatesFixtureOrigin;
## these are synthetic joints, not anatomical calibration or live-rig evidence.
const Allocator = preload("res://core/resolvers/combat_weapon_motion_allocator.gd")
const Policy = preload("res://core/defs/weapon_motion_policy_def.gd")
var output_dir := "C:/WORKSPACE/godot_runs/allocator_fixed_coordinates"
var checks: Array[Dictionary] = []
var calls: int = 0
var locked_perturbations: int = 0
var samples: Array[Dictionary] = []

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			output_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")

func _run() -> void:
	_test_derivative_work()
	_test_motion_equivalence()
	_test_all_fixed()
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var report := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if report == null:
		push_error("Cannot write fixed-coordinate verifier report")
		quit(1)
		return
	report.store_string(JSON.stringify({"passed": passed, "checks": checks, "samples": samples}, "\t"))
	report.close()
	print("ALLOCATOR_FIXED_COORDINATES passed=%s checks=%d output=%s" % [passed, checks.size(), output_dir])
	quit(0 if passed else 1)

func _mixed_frame(q: PackedFloat64Array) -> Dictionary:
	calls += 1
	if q[0] != 0.2 or q[2] != -0.3:
		locked_perturbations += 1
	# The fixed channels have a real mechanical effect. Their calibrated
	# contributions cancel in this fixture, yielding the reduced q[1] motion.
	return _frame(3.0 * q[0] + q[1] + 2.0 * q[2], q[1])

func _reduced_frame(q: PackedFloat64Array) -> Dictionary:
	return _frame(q[0], q[0])

func _frame(angle: float, moving_joint: float) -> Dictionary:
	return {"valid": true, "weapon_frame": Transform3D(Basis(Vector3.BACK, angle), Vector3.ZERO),
		"constraints": PackedFloat64Array([moving_joint - 0.35]),
		"constraint_reasons": PackedStringArray(["JOINT_RANGE:fixture_positive_stop"]),
		"payload": {"moving_joint": moving_joint}}

func _test_derivative_work() -> void:
	var q := PackedFloat64Array([0.2, 0.1, -0.3])
	var lower := PackedFloat64Array([0.2, -0.4, -0.3])
	var upper := PackedFloat64Array([0.2, 0.4, -0.3])
	var policy: Dictionary = Policy.new().as_dictionary()
	var baseline := _mixed_frame(q)
	calls = 0
	locked_perturbations = 0
	var differential: Dictionary = Allocator._differentiate(q, baseline, Vector3.ZERO, _mixed_frame, policy, lower, upper, "tip")
	_check(differential.get("valid", false), "mixed_derivative_valid")
	_check(calls == 1 and locked_perturbations == 0, "only_free_coordinate_is_evaluated", {"calls": calls, "locked_perturbations": locked_perturbations})
	if differential.get("valid", false):
		_check(differential.jacobian.size() == 3 and differential.constraints.size() == 1,
			"task_and_constraint_row_counts_retained")
		var zero_columns := true
		for matrix: Array in [differential.jacobian, differential.constraints]:
			for row: PackedFloat64Array in matrix:
				zero_columns = zero_columns and row.size() == 3 and row[0] == 0.0 and row[2] == 0.0
		_check(zero_columns, "fixed_columns_retained_as_exact_zero")
		_check(absf(differential.jacobian[2][1]) > 0.99 and absf(differential.constraints[0][1] - 1.0) < 0.000001,
			"free_task_and_limit_derivatives_retained")
	# Exact equality matters: a tiny permitted interval is still a free channel.
	upper[0] = lower[0] + 1.0e-10
	calls = 0
	Allocator._differentiate(q, baseline, Vector3.ZERO, _mixed_frame, policy, lower, upper, "tip")
	_check(calls == 2, "narrow_nonzero_interval_is_not_locked", {"calls": calls})
	# A previously invalid fixed channel may move back toward its fixed value.
	# Differentiation must consume the effective correction bounds, not nominal.
	q[0] = 0.25
	upper[0] = lower[0]
	var input := {"q": q, "lower": lower, "upper": upper}
	baseline = _mixed_frame(q)
	var allowance: Dictionary = Allocator.build_start_allowance(input, baseline)
	calls = 0
	Allocator._differentiate(q, baseline, Vector3.ZERO, _mixed_frame, policy, allowance.lower, allowance.upper, "tip")
	_check(calls == 2, "invalid_start_correction_channel_remains_available", {"calls": calls})

func _request(q: PackedFloat64Array, previous: Transform3D, target: Transform3D, mixed: bool) -> Dictionary:
	return {"mode": "tip", "q": q, "previous_weapon": previous, "target_weapon": target,
		"contact_local": Vector3.ZERO, "origin_id": &"AllocatorFixedCoordinatesFixtureOrigin",
		"lower": PackedFloat64Array([0.2, -0.4, -0.3]) if mixed else PackedFloat64Array([-0.4]),
		"upper": PackedFloat64Array([0.2, 0.4, -0.3]) if mixed else PackedFloat64Array([0.4]),
		"joint_groups": PackedStringArray(["shoulder_girdle", "forearm", "shoulder_girdle"]) if mixed else PackedStringArray(["forearm"])}

func _test_motion_equivalence() -> void:
	var mixed_q := PackedFloat64Array([0.2, 0.1, -0.3])
	var reduced_q := PackedFloat64Array([0.1])
	for label_and_angle: Array in [["forward", 0.2], ["limit", 0.6], ["reverse", -0.15]]:
		var label := String(label_and_angle[0])
		var target: Transform3D = _frame(float(label_and_angle[1]), 0.0).weapon_frame
		var mixed_previous: Transform3D = _mixed_frame(mixed_q).weapon_frame
		var reduced_previous: Transform3D = _reduced_frame(reduced_q).weapon_frame
		calls = 0
		locked_perturbations = 0
		var mixed: Dictionary = Allocator.solve(_request(mixed_q, mixed_previous, target, true), _mixed_frame)
		var used_calls := calls
		var fixed_probes := locked_perturbations
		var reduced: Dictionary = Allocator.solve(_request(reduced_q, reduced_previous, target, false), _reduced_frame)
		_check(mixed.get("status", "") == reduced.get("status", ""), label + "_same_status")
		_check(absf(float(mixed.task_scale) - float(reduced.task_scale)) < 0.000001, label + "_same_task_fraction")
		_check(absf(float(mixed.accepted_q[1]) - float(reduced.accepted_q[0])) < 0.000001,
			label + "_same_joint_motion", {"mixed": mixed.accepted_q, "reduced": reduced.accepted_q})
		_check((mixed.accepted_weapon as Transform3D).is_equal_approx(reduced.accepted_weapon), label + "_same_weapon_frame")
		_check(mixed.accepted_q[0] == 0.2 and mixed.accepted_q[2] == -0.3, label + "_fixed_joints_unchanged")
		# A direct initial/candidate evaluation is permitted; none may perturb a
		# fixed channel. This includes the solve's own numerical differentiation.
		_check(fixed_probes == 0, label + "_no_fixed_channel_perturbation", {"calls": used_calls, "fixed_probes": fixed_probes})
		if label == "limit":
			_check(float(mixed.accepted_q[1]) <= 0.350001 and float(mixed.task_scale) < 1.0,
				"shared_physical_limit_still_applies")
		else:
			_check(mixed.get("valid", false), label + "_movement_accepted")
		samples.append({"phase": label, "status": mixed.get("status", ""), "fraction": mixed.task_scale,
			"mixed_q": mixed.accepted_q, "reduced_q": reduced.accepted_q, "evaluations": used_calls})
		mixed_q = mixed.accepted_q
		reduced_q = reduced.accepted_q

func _test_all_fixed() -> void:
	var q := PackedFloat64Array([0.2, 0.1, -0.3])
	var baseline := _mixed_frame(q)
	calls = 0
	var differential: Dictionary = Allocator._differentiate(q, baseline, Vector3.ZERO, _mixed_frame,
		Policy.new().as_dictionary(), q, q, "tip")
	_check(differential.get("valid", false) and calls == 0, "all_fixed_requires_no_derivative_evaluations", {"calls": calls})
	var zero_rows := true
	for matrix: Array in [differential.get("jacobian", []), differential.get("constraints", [])]:
		for row: PackedFloat64Array in matrix:
			for value: float in row:
				zero_rows = zero_rows and value == 0.0
	_check(zero_rows, "all_fixed_derivatives_are_zero")
	var target: Transform3D = _frame(0.2, 0.0).weapon_frame
	var input := _request(q, baseline.weapon_frame, target, true)
	input.lower = q.duplicate()
	input.upper = q.duplicate()
	locked_perturbations = 0
	var result: Dictionary = Allocator.solve(input, _mixed_frame)
	_check(not result.get("valid", false) and result.accepted_q == q and float(result.task_scale) == 0.0,
		"all_fixed_does_not_claim_motion", {"status": result.get("status", ""), "reason": result.get("reason", "")})
	_check(locked_perturbations == 0, "all_fixed_solve_never_perturbs_locked_channels")

func _check(passed: bool, label: String, data: Dictionary = {}) -> void:
	checks.append({"passed": passed, "check": label, "data": data})
