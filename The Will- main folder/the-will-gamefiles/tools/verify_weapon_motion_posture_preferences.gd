extends SceneTree

## Small analytic mechanisms for allocation policy, not a human-arm model.
## Actual rig/body checks remain separate; this tool never loads player saves.
const Allocator = preload("res://core/resolvers/combat_weapon_motion_allocator.gd")
const Policy = preload("res://core/defs/weapon_motion_policy_def.gd")
const POSITION_EPSILON := 0.00005
const ANGLE_EPSILON := 0.000436333
var output_dir := "C:/WORKSPACE/godot_runs/weapon_motion_posture_preferences"
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			output_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")

func _run() -> void:
	_test_coordinated_recruitment()
	_test_modes_and_constraints()
	_test_orbit_task_path()
	_test_policy_contract()
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot create posture preference report")
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "samples": samples,
		"scope": "Finite posture preference and generic task contracts on analytic mechanisms; not live body, grip or playback certification."}, "\t"))
	file.close()
	print("WEAPON_MOTION_POSTURE_PREFERENCES passed=%s checks=%d output=%s" % [passed, checks.size(), output_dir])
	quit(0 if passed else 1)

func _check(passed: bool, name: String, details: Dictionary = {}) -> void:
	checks.append({"passed": passed, "name": name, "details": details})

func _request(values: PackedFloat64Array, groups: PackedStringArray, previous: Transform3D,
		target: Transform3D, mode: String) -> Dictionary:
	var lower := PackedFloat64Array()
	var upper := PackedFloat64Array()
	var steps := PackedFloat64Array()
	var spans := PackedFloat64Array()
	for _index: int in values.size():
		lower.append(-1.0)
		upper.append(1.0)
		steps.append(0.25)
		spans.append(2.0)
	return {"q": values.duplicate(), "lower": lower, "upper": upper,
		"step_sizes": steps, "posture_spans": spans, "joint_groups": groups,
		"previous_weapon": previous, "target_weapon": target, "contact_local": Vector3.ZERO,
		"mode": mode, "origin_id": &"PosturePreferenceFixtureOrigin"}

func _serial(values: PackedFloat64Array, reference: Transform3D) -> Dictionary:
	return {"valid": true,
		"weapon_frame": Transform3D(reference.basis * Basis(Vector3.FORWARD, values[0] + values[1]), reference.origin),
		"constraints": PackedFloat64Array(), "payload": {"q": values.duplicate()}}

func _test_coordinated_recruitment() -> void:
	var reference := Transform3D(Basis.from_euler(Vector3(0.2, -0.3, 0.1)), Vector3(0.7, 1.3, -0.4))
	var evaluate: Callable = _serial.bind(reference)
	var groups := PackedStringArray(["forearm", "shoulder_roll"])
	var q := PackedFloat64Array([0.0, 0.0])
	var target: Transform3D = evaluate.call(PackedFloat64Array([0.2, 0.0])).weapon_frame
	var request := _request(q, groups, reference, target, "tip")
	request.lower[0] = -0.25
	request.upper[0] = 0.25
	var unchanged := var_to_bytes(request)
	var weighted: Dictionary = Allocator.solve(request, evaluate)
	var exact: Dictionary = Allocator.solve(request, evaluate, {"posture_preference_mode": "lexicographic"})
	samples.append({"label": "weighted_and_exact", "weighted": weighted, "exact": exact})
	_check(var_to_bytes(request) == unchanged, "allocation_does_not_mutate_request_or_bounds")
	_check(_reached(weighted, target, "tip") and _reached(exact, target, "tip"), "both_policies_preserve_primary_task")
	if not weighted.get("valid", false) or not exact.get("valid", false):
		return
	var w: PackedFloat64Array = weighted.accepted_q
	var x: PackedFloat64Array = exact.accepted_q
	_check(w[0] > w[1] and w[1] > 0.005 and w[0] < 0.25, "proximal_contribution_begins_before_distal_limit", {"q": w})
	_check(absf(w[0] - 0.2 * 12.0 / 13.0) < 0.0005, "finite_cost_solution_matches_analytic_redundancy", {"q": w})
	_check(absf(x[1]) < 0.0001, "counterfactual_retains_exact_historical_hold", {"q": x})
	var explicit: Dictionary = Allocator.solve(request, evaluate, {"hold_order_by_mode": {"tip": [PackedStringArray(["shoulder_roll"]), PackedStringArray(["forearm"])]}})
	_check(_reached(explicit, target, "tip") and absf(explicit.accepted_q[1]) < 0.0001, "explicit_hold_override_takes_precedence")
	var reverse_costs := {"posture_group_costs_by_mode": {"tip": {"forearm": 12.0, "shoulder_roll": 1.0}}}
	var other: Dictionary = Allocator.solve(request, evaluate, reverse_costs)
	_check(_reached(other, target, "tip") and other.accepted_q[1] > other.accepted_q[0], "costs_change_posture_without_changing_task")
	var normalized := request.duplicate(true)
	normalized.posture_spans = PackedFloat64Array([0.5, 2.0])
	var narrow: Dictionary = Allocator.solve(normalized, evaluate)
	_check(_reached(narrow, target, "tip") and narrow.accepted_q[0] < w[0], "explicit_spans_change_preference_not_bounds")

	# Small successive commands cross the distal stop. Recruitment is already
	# present before contact with that stop; no coordinate teleports at handoff.
	q = PackedFloat64Array([0.0, 0.0])
	var sequence_ok := true
	var bounds_ok := true
	var maximum_joint_step := 0.0
	for step: int in range(1, 9):
		target = evaluate.call(PackedFloat64Array([float(step) * 0.05, 0.0])).weapon_frame
		request = _request(q, groups, evaluate.call(q).weapon_frame, target, "tip")
		request.lower[0] = -0.25
		request.upper[0] = 0.25
		var result: Dictionary = Allocator.solve(request, evaluate)
		sequence_ok = sequence_ok and _reached(result, target, "tip")
		if not result.get("valid", false): break
		var next: PackedFloat64Array = result.accepted_q
		maximum_joint_step = maxf(maximum_joint_step, maxf(absf(next[0] - q[0]), absf(next[1] - q[1])))
		bounds_ok = bounds_ok and next[0] <= 0.25 + 0.000001 and next[1] <= 1.0 + 0.000001
		q = next
	_check(sequence_ok and maximum_joint_step <= 0.0501, "joint_recruitment_stays_continuous_through_distal_stop", {"maximum_joint_step": maximum_joint_step, "q": q})
	_check(bounds_ok and absf(q[0] - 0.25) < 0.0001, "distal_limit_stays_firm")
	var before_reverse := q.duplicate()
	target = evaluate.call(PackedFloat64Array([q[0] + q[1] - 0.1, 0.0])).weapon_frame
	request = _request(q, groups, evaluate.call(q).weapon_frame, target, "tip")
	request.lower[0] = -0.25
	request.upper[0] = 0.25
	var reverse: Dictionary = Allocator.solve(request, evaluate)
	_check(_reached(reverse, target, "tip") and reverse.accepted_q[0] < before_reverse[0] - 0.01, "reversal_leaves_limit_immediately")

func _cartesian(values: PackedFloat64Array, reference: Transform3D) -> Dictionary:
	return {"valid": true,
		"weapon_frame": Transform3D(reference.basis * Basis(Vector3.FORWARD, values[2] + values[3]),
			reference * Vector3(values[0], values[1], 0.0)),
		"constraints": PackedFloat64Array(),
		# A fixed linkage relation, expressed as an equality independently of
		# the requested task and secondary posture preference.
		"equalities": PackedFloat64Array([values[2] - values[3]]),
		"equality_tolerances": PackedFloat64Array([0.00000001])}

func _test_modes_and_constraints() -> void:
	var reference := Transform3D(Basis.from_euler(Vector3(-0.2, 0.15, 0.3)), Vector3(-0.6, 1.1, 0.9))
	var evaluate: Callable = _cartesian.bind(reference)
	var values := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	var groups := PackedStringArray(["shoulder_swing", "elbow", "forearm", "wrist"])
	var target: Transform3D = evaluate.call(PackedFloat64Array([0.08, -0.04, 0.1, 0.1])).weapon_frame
	var request := _request(values, groups, reference, target, "pose")
	var result: Dictionary = Allocator.solve(request, evaluate)
	samples.append({"label": "generic_pose", "result": result})
	_check(_reached(result, target, "pose"), "pose_mode_reaches_origin_and_orientation_together")
	if result.get("valid", false):
		_check(absf(result.accepted_q[2] - result.accepted_q[3]) <= 0.0000011, "posture_preference_preserves_linkage_equality")
	request.mode = "position"
	var position: Dictionary = Allocator.solve(request, evaluate)
	samples.append({"label": "generic_position", "result": position})
	_check(_reached(position, target, "position"), "position_mode_reaches_frame_origin")
	_check(position.get("valid", false) and not position.get("orientation_constrained", true)
		and Allocator._rotation_vector(position.accepted_weapon.basis, reference.basis).length() < ANGLE_EPSILON,
		"position_mode_does_not_demand_target_orientation")
	# Endpoint origin, not an off-origin contact point, defines these generic tasks.
	request.contact_local = Vector3(0.2, -0.1, 0.3)
	var offset: Dictionary = Allocator.solve(request, evaluate)
	_check(_reached(offset, target, "position"), "position_target_is_frame_origin_even_with_contact_metadata")
	request = _request(values, groups, reference,
		evaluate.call(PackedFloat64Array([0.0, 0.0, 0.2, 0.2])).weapon_frame, "pose")
	request.upper[2] = 0.08
	var limited: Dictionary = Allocator.solve(request, evaluate)
	samples.append({"label": "generic_pose_limited", "result": limited})
	_check(limited.get("valid", false) and float(limited.task_scale) < 1.0, "unreachable_pose_is_scaled_not_certified_complete")
	_check(float(limited.accepted_q[2]) <= 0.080001 and absf(limited.accepted_q[2] - limited.accepted_q[3]) <= 0.0000011,
		"scaled_pose_preserves_joint_bound_and_linkage")

func _test_policy_contract() -> void:
	var policy := Policy.new()
	var snapshot := policy.as_dictionary()
	snapshot.posture_group_costs_by_mode.tip.forearm = 100.0
	_check(float(policy.posture_group_costs_by_mode.tip.forearm) == 1.0, "policy_snapshot_does_not_mutate_shared_resource")
	var evaluate: Callable = _serial.bind(Transform3D.IDENTITY)
	var q := PackedFloat64Array([0.0, 0.0])
	var request := _request(q, PackedStringArray(["forearm", "shoulder_roll"]), Transform3D.IDENTITY,
		evaluate.call(PackedFloat64Array([0.1, 0.0])).weapon_frame, "tip")
	var invalid_cost: Dictionary = Allocator.solve(request, evaluate,
		{"posture_group_costs_by_mode": {"tip": {"forearm": 0.0}}})
	_check(not invalid_cost.valid and invalid_cost.reason == "allocator_posture_costs_invalid", "nonpositive_cost_is_rejected")
	request.posture_spans = PackedFloat64Array([0.0, 2.0])
	var invalid_span: Dictionary = Allocator.solve(request, evaluate)
	_check(not invalid_span.valid and invalid_span.reason == "allocator_posture_spans_invalid", "invalid_normalization_span_is_rejected")

func _orbit_frame(values: PackedFloat64Array, center: Vector3, axis: Vector3, offset: Vector3) -> Dictionary:
	return {"valid": true, "weapon_frame": Transform3D(Basis.IDENTITY, center + Basis(axis, values[0]) * offset),
		"constraints": PackedFloat64Array()}

func _test_orbit_task_path() -> void:
	var center := Vector3(0.6, 1.2, -0.3)
	var axis := Vector3(0.3, 0.7, -0.2).normalized()
	var radial := axis.cross(Vector3.RIGHT).normalized() * 0.25
	# A nonzero component along the axis must survive orbiting too.
	var offset := radial + axis * 0.12
	var evaluate: Callable = _orbit_frame.bind(center, axis, offset)
	var q := PackedFloat64Array([0.0])
	var previous: Transform3D = evaluate.call(q).weapon_frame
	var target: Transform3D = evaluate.call(PackedFloat64Array([0.3])).weapon_frame
	var request := _request(q, PackedStringArray(["elbow"]), previous, target, "position")
	request.task_path = {"kind": "orbit", "center": center, "axis": axis * 2.0, "angle_radians": 0.3}
	var unchanged := var_to_bytes(request)
	var validation := Allocator._validate_task_path(request, "position", previous, target, Policy.new().as_dictionary())
	_check(validation.valid and absf(float(validation.arc_length) - 0.075) < 0.000001, "orbit_counts_perpendicular_arc_length_not_chord")
	if not validation.valid:
		return
	var path_samples_ok := true
	for weight: float in [0.0, 0.125, 0.25, 0.5, 0.75, 1.0]:
		var sample: Transform3D = Allocator._target_at(previous, target, Vector3.ZERO, "position", weight, Vector3.ZERO, validation.path)
		var relative := sample.origin - center
		path_samples_ok = path_samples_ok and absf(relative.length() - offset.length()) < 0.000001 \
			and absf(relative.dot(axis) - 0.12) < 0.000001 and sample.basis.is_equal_approx(previous.basis)
	_check(path_samples_ok, "orbit_targets_preserve_link_length_axial_offset_and_basis")
	var result: Dictionary = Allocator.solve(request, evaluate)
	samples.append({"label": "position_orbit", "result": result})
	_check(_reached(result, target, "position"), "orbit_position_task_reaches_rigid_link_endpoint")
	_check(var_to_bytes(request) == unchanged, "orbit_axis_normalization_does_not_mutate_input")
	var reverse := request.duplicate(true)
	reverse.target_weapon = evaluate.call(PackedFloat64Array([-0.3])).weapon_frame
	reverse.task_path.angle_radians = -0.3
	var reversed: Dictionary = Allocator.solve(reverse, evaluate)
	_check(_reached(reversed, reverse.target_weapon, "position"), "negative_orbit_angle_reaches_opposite_direction")
	var malformed := request.duplicate(true)
	malformed.task_path.axis = Vector3.ZERO
	var zero_axis: Dictionary = Allocator.solve(malformed, evaluate)
	_check(not zero_axis.valid and zero_axis.reason == "allocator_task_path_geometry_invalid", "zero_orbit_axis_rejected")
	malformed = request.duplicate(true)
	malformed.task_path.angle_radians = 0.5
	var wrong_end: Dictionary = Allocator.solve(malformed, evaluate)
	_check(not wrong_end.valid and wrong_end.reason == "allocator_task_path_endpoint_mismatch", "orbit_endpoint_must_match_requested_target")
	malformed = request.duplicate(true)
	malformed.mode = "pommel"
	var wrong_mode: Dictionary = Allocator.solve(malformed, evaluate)
	_check(not wrong_mode.valid and wrong_mode.reason == "allocator_task_path_mode_invalid", "orbit_does_not_change_existing_weapon_mode_contracts")

func _reached(result: Dictionary, target: Transform3D, mode: String) -> bool:
	if not result.get("valid", false) or float(result.get("task_scale", 0.0)) < 1.0 - 0.000001:
		return false
	var actual: Transform3D = result.accepted_weapon
	return (mode == "tip" or actual.origin.distance_to(target.origin) <= POSITION_EPSILON) \
		and (mode == "position" or Allocator._rotation_vector(actual.basis, target.basis).length() <= ANGLE_EPSILON)
