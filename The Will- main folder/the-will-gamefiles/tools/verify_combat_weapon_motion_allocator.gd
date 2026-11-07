extends SceneTree

## Policy tests on deliberately small kinematic fixtures. These are not a
## substitute for the separate imported-rig and live station checks.
const Allocator = preload("res://core/resolvers/combat_weapon_motion_allocator.gd")
const POSITION_EPSILON := 0.00005
const ANGLE_EPSILON := 0.001
var output_dir := "C:/WORKSPACE/godot_runs/weapon_motion_allocator"
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			output_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")

func _run() -> void:
	_test_redundant_tip_and_reversal()
	_test_tip_releases_spatial_pivot()
	_test_roll_priority()
	_test_pommel_translation()
	_test_pommel_reach_bound()
	_test_bounded_pommel_stagnation()
	_test_shoulder_coverage_boundary()
	_test_shoulder_hold_crossing_classification()
	_test_coupled_boundary()
	_test_existing_anatomy_can_be_corrected()
	_test_existing_coupled_limit_can_be_corrected()
	_test_retained_contact_anchor()
	_test_no_motion_scaling()
	_test_search_guidance_is_not_hard_legality()
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("policy_report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot create allocator policy report")
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "samples": samples,
		"scope": "Small independent kinematic policy fixtures; not imported-rig, grip-acquisition, skin or equipped-playback certification."}, "\t"))
	file.close()
	print("WEAPON_MOTION_ALLOCATOR_POLICY passed=%s checks=%d output=%s" % [passed, checks.size(), output_dir])
	quit(0 if passed else 1)

func _serial_frame(q: PackedFloat64Array, context: Dictionary) -> Dictionary:
	var angle := 0.0
	for value: float in q:
		angle += value
	var basis: Basis = context.reference.basis * Basis(Vector3.FORWARD, angle)
	var frame := Transform3D(basis, context.anchor - basis * context.contact)
	return {"valid": true, "weapon_frame": frame, "constraints": PackedFloat64Array(), "payload": {"angles": q.duplicate()}}

func _input(q: PackedFloat64Array, groups: PackedStringArray, frame: Transform3D, target: Transform3D, contact: Vector3, mode: String) -> Dictionary:
	var lower := PackedFloat64Array()
	var upper := PackedFloat64Array()
	var steps := PackedFloat64Array()
	for _index: int in q.size():
		lower.append(-1.0)
		upper.append(1.0)
		steps.append(0.2)
	return {"q": q.duplicate(), "lower": lower, "upper": upper, "joint_groups": groups,
		"step_sizes": steps, "previous_weapon": frame, "target_weapon": target,
		"contact_local": contact, "mode": mode, "origin_id": &"AllocatorPolicyFixtureOrigin"}

func _test_redundant_tip_and_reversal() -> void:
	var context := {"reference": Transform3D(Basis.from_euler(Vector3(0.3, -0.4, 0.1)), Vector3.ZERO),
		"anchor": Vector3(0.4, 1.2, -0.6), "contact": Vector3(0.035, 0.2, 0.01)}
	var evaluate: Callable = _serial_frame.bind(context)
	var q := PackedFloat64Array([0.0, 0.0])
	var previous: Transform3D = evaluate.call(q).weapon_frame
	var target: Transform3D = evaluate.call(PackedFloat64Array([0.2, 0.0])).weapon_frame
	var request := _input(q, PackedStringArray(["wrist", "elbow"]), previous, target, context.contact, "tip")
	var unchanged := var_to_bytes(request)
	var result: Dictionary = _solve(request, evaluate)
	_record("tip_small_distal_priority", result)
	_check(unchanged == var_to_bytes(request), "solve_does_not_mutate_input")
	_check(_orientation_reached(result, target), "small_tip_reaches_requested_orientation")
	if not result.get("valid", false): return
	q = result.accepted_q
	_check(absf(q[1]) < ANGLE_EPSILON, "small_tip_does_not_recruit_unneeded_elbow", {"q": q})
	_check(_rotation_error(previous.basis, result.accepted_weapon.basis) > deg_to_rad(1.0), "tip_produces_actual_rotation")
	previous = result.accepted_weapon
	target = evaluate.call(PackedFloat64Array([1.0, 0.5])).weapon_frame
	result = _solve(_input(q, request.joint_groups, previous, target, context.contact, "tip"), evaluate)
	_record("tip_continues_beyond_distal_boundary", result)
	_check(_orientation_reached(result, target), "tip_recruits_legal_proximal_motion")
	if not result.get("valid", false): return
	q = result.accepted_q
	_check(absf(q[0] - 1.0) < ANGLE_EPSILON and absf(q[1] - 0.5) < ANGLE_EPSILON, "tip_uses_distal_capacity_before_proximal", {"q": q})
	var retained_proximal: float = q[1]
	target = evaluate.call(PackedFloat64Array([0.75, 0.5])).weapon_frame
	result = _solve(_input(q, request.joint_groups, result.accepted_weapon, target, context.contact, "tip"), evaluate)
	_record("tip_reverse_from_boundary", result)
	_check(_orientation_reached(result, target), "reversal_immediately_moves_inward")
	if not result.get("valid", false): return
	q = result.accepted_q
	_check(absf(q[1] - retained_proximal) < ANGLE_EPSILON, "reversal_retains_previous_proximal_state", {"q": q})
	# Relative commands originate from accepted state, including after rejection.
	for attempt: int in 3:
		previous = result.accepted_weapon
		target = evaluate.call(PackedFloat64Array([1.2, 1.2])).weapon_frame
		result = _solve(_input(q, request.joint_groups, previous, target, context.contact, "tip"), evaluate)
		_record("blocked_input_%d" % attempt, result)
		if result.has("accepted_q"): q = result.accepted_q
	_check(q[0] <= 1.0 + ANGLE_EPSILON and q[1] <= 1.0 + ANGLE_EPSILON, "repeated_blocked_input_keeps_joint_bounds", {"q": q})
	previous = evaluate.call(q).weapon_frame
	var inward := q.duplicate()
	inward[0] -= 0.1
	target = evaluate.call(inward).weapon_frame
	result = _solve(_input(q, request.joint_groups, previous, target, context.contact, "tip"), evaluate)
	_record("inward_after_repeated_block", result)
	_check(_orientation_reached(result, target), "no_hidden_blocked_input_backlog")
	if result.get("valid", false):
		var hold: Dictionary = _solve(_input(result.accepted_q, request.joint_groups, result.accepted_weapon, result.accepted_weapon, context.contact, "tip"), evaluate)
		_check(hold.get("valid", false) and (hold.accepted_q as PackedFloat64Array) == (result.accepted_q as PackedFloat64Array), "zero_input_holds_accepted_joint_state")

func _elbow_lever_frame(q: PackedFloat64Array, context: Dictionary) -> Dictionary:
	var elbow_rotation := Basis(Vector3.BACK, q[1])
	var hand_local := Transform3D(Basis(Vector3.BACK, q[0] + q[1]), elbow_rotation * Vector3(0.35, 0.0, 0.0))
	var hand: Transform3D = context.base * hand_local
	return {"valid": true, "weapon_frame": hand * context.hand_to_weapon,
		"constraints": PackedFloat64Array(), "payload": {"hand_world": hand}}

func _test_tip_releases_spatial_pivot() -> void:
	var context := {"base": Transform3D(Basis.from_euler(Vector3(0.2, -0.3, 0.1)), Vector3(0.4, 1.1, -0.6)),
		"hand_to_weapon": Transform3D(Basis.IDENTITY, Vector3(0.08, 0.03, 0.0))}
	var evaluate: Callable = _elbow_lever_frame.bind(context)
	var q := PackedFloat64Array([0.2, 0.0])
	var previous: Transform3D = evaluate.call(q).weapon_frame
	var contact := Vector3(0.02, 0.05, 0.0)
	var target := previous
	target.basis = Basis((context.base as Transform3D).basis.z, 0.2) * previous.basis
	var request := _input(q, PackedStringArray(["wrist", "elbow"]), previous, target, contact, "tip")
	request.lower = PackedFloat64Array([-0.2, -0.8])
	request.upper = PackedFloat64Array([0.2, 0.8])
	# A stale old-mode anchor must not secretly constrain orientation-only Tip.
	request.contact_anchor = previous * contact
	var result: Dictionary = _solve(request, evaluate)
	_record("tip_wrist_limit_elbow_lever", result)
	_check(_orientation_reached(result, target), "tip_orientation_succeeds_where_pivot_must_travel")
	var shifted := request.duplicate(true)
	var shifted_target := target
	shifted_target.origin += Vector3(0.7, -0.4, 0.2)
	shifted.target_weapon = shifted_target
	var shifted_result: Dictionary = _solve(shifted, evaluate)
	_check(shifted_result.get("valid", false) and result.get("valid", false) and shifted_result.accepted_q == result.accepted_q,
		"tip_ignores_target_position_without_changing_orientation_solution")
	if result.get("valid", false):
		var accepted: Transform3D = result.accepted_weapon
		var grip_travel: float = (accepted * contact).distance_to(previous * contact)
		_check(grip_travel > 0.01, "tip_releases_world_grip_pivot", {"grip_travel_m": grip_travel})
		_check(result.accepted_q[1] > 0.15 and result.accepted_q[0] <= 0.2 + 0.000001,
			"elbow_bends_without_extending_wrist_limit", {"q": result.accepted_q})
		var hand: Transform3D = result.accepted_payload.hand_world
		var expected: Transform3D = accepted * (context.hand_to_weapon as Transform3D).affine_inverse()
		_check(hand.origin.distance_to(expected.origin) <= POSITION_EPSILON and _rotation_error(hand.basis, expected.basis) <= ANGLE_EPSILON,
			"tip_preserves_acquired_hand_weapon_attachment")
	var locked_target := target
	locked_target.origin = previous * contact - locked_target.basis * contact
	var locked := request.duplicate(true)
	locked.mode = "roll"
	locked.target_weapon = locked_target
	var held: Dictionary = _solve(locked, evaluate)
	_record("same_lever_with_fixed_roll_pivot", held)
	_check(not _orientation_reached(held, locked_target), "same_orientation_infeasible_when_grip_pivot_is_fixed")
	if held.get("valid", false):
		_check((held.accepted_weapon * contact).distance_to(previous * contact) <= POSITION_EPSILON,
			"scaled_roll_still_keeps_its_pivot")

func _test_roll_priority() -> void:
	var context := {"reference": Transform3D.IDENTITY, "anchor": Vector3(1.0, 0.5, -0.3), "contact": Vector3(0.04, 0.02, 0.3)}
	var evaluate: Callable = _serial_frame.bind(context)
	var q := PackedFloat64Array([0.0, 0.0])
	var target: Transform3D = evaluate.call(PackedFloat64Array([0.0, 0.3])).weapon_frame
	var result: Dictionary = _solve(_input(q, PackedStringArray(["shoulder", "forearm"]), evaluate.call(q).weapon_frame, target, context.contact, "roll"), evaluate)
	_record("forearm_first_roll", result)
	_check(_reached(result, target), "roll_reaches_rigid_target")
	if result.get("valid", false):
		_check(absf(result.accepted_q[0]) < ANGLE_EPSILON, "roll_prefers_forearm_over_humerus", {"q": result.accepted_q})
		_check((result.accepted_weapon * context.contact).distance_to(context.anchor) <= POSITION_EPSILON, "off_axis_roll_preserves_selected_contact")

func _translation_frame(q: PackedFloat64Array) -> Dictionary:
	return {"valid": true, "weapon_frame": Transform3D(Basis.from_euler(Vector3(0.2, 0.3, 0.4)), Vector3(q[0], q[1], q[2])), "constraints": PackedFloat64Array(), "payload": {}}

func _test_pommel_translation() -> void:
	var q := PackedFloat64Array([0.1, 0.2, 0.3])
	var previous: Transform3D = _translation_frame(q).weapon_frame
	var target: Transform3D = _translation_frame(PackedFloat64Array([0.12, 0.19, 0.31])).weapon_frame
	var contact := Vector3(0.04, 0.1, 0.01)
	var result: Dictionary = _solve(_input(q, PackedStringArray(["elbow", "shoulder", "shoulder"]), previous, target, contact, "pommel"), _translation_frame)
	_record("whole_weapon_translation", result)
	_check(_reached(result, target), "pommel_translates_with_orientation_held")
	if result.get("valid", false):
		_check((result.accepted_weapon * contact - previous * contact).distance_to(target.origin - previous.origin) <= POSITION_EPSILON, "pommel_moves_contact_with_weapon")

func _test_pommel_reach_bound() -> void:
	var q := PackedFloat64Array([0.1, 0.2, 0.3])
	var previous: Transform3D = _translation_frame(q).weapon_frame
	var target := previous
	target.origin.x += 0.08
	var request := _input(q, PackedStringArray(["elbow", "shoulder", "shoulder"]), previous, target, Vector3(0.04, 0.1, 0.01), "pommel")
	var unbounded: Dictionary = _solve(request, _translation_frame)
	var bounded := request.duplicate(true)
	bounded.translation_reach_bound = {"valid": true, "maximum_fraction": 0.375,
		"origin_id": request.origin_id, "reason": "arm_extension_reach_limit", "evidence": "analytical fixture"}
	var before := var_to_bytes(bounded)
	var result: Dictionary = _solve(bounded, _translation_frame)
	_record("pommel_analytical_reach_cap", result)
	_check(var_to_bytes(bounded) == before, "reach_bound_does_not_mutate_input")
	_check(result.get("valid", false) and result.status == "SCALED" and result.reason == "arm_extension_reach_limit",
		"reach_cap_reports_partial_original_request")
	var expected := previous
	expected.origin = previous.origin.lerp(target.origin, 0.375)
	_check(_reached(result, expected) and absf(float(result.task_scale) - 0.375) < 1.0e-10,
		"reach_cap_preserves_original_path_fraction", {"fraction": result.task_scale})
	_check(absf(float(result.remaining_task_error.position) - previous.origin.distance_to(target.origin) * 0.625) < POSITION_EPSILON,
		"reach_cap_keeps_error_to_original_target", {"error": result.remaining_task_error})
	_check(result.get("translation_reach_bound", {}).get("reached", false) and result.get("search_failures", []).is_empty(),
		"reach_cap_stops_before_impossible_fit")
	for unused_bound: Dictionary in [{}, {"valid": false, "maximum_fraction": 0.0}]:
		var ignored := request.duplicate(true)
		ignored.translation_reach_bound = unused_bound
		_check(var_to_bytes(_solve(ignored, _translation_frame)) == var_to_bytes(unbounded),
			"inactive_reach_bound_preserves_unbounded_result", {"bound": unused_bound})
	var full := request.duplicate(true)
	full.translation_reach_bound = {"valid": true, "maximum_fraction": 1.0, "origin_id": request.origin_id}
	var full_result: Dictionary = _solve(full, _translation_frame)
	full_result.erase("translation_reach_bound")
	_check(var_to_bytes(full_result) == var_to_bytes(unbounded), "full_reach_bound_preserves_solver_result")
	# The cap is a necessary envelope only: scalar/collision checks retain the
	# authority to stop earlier, and initial contact/context still validate.
	var limited := bounded.duplicate(true)
	limited.upper[0] = 0.105
	var limited_result: Dictionary = _solve(limited, _translation_frame)
	_check(float(limited_result.task_scale) < 0.375 and limited_result.reason != "arm_extension_reach_limit"
		and not bool(limited_result.translation_reach_bound.reached), "earlier_joint_limit_keeps_its_failure")
	var collision := bounded.duplicate(true)
	collision.validate_candidate = func(evaluation: Dictionary) -> Dictionary:
		return {"valid": (evaluation.weapon_frame as Transform3D).origin.x <= 0.105}
	var collision_result: Dictionary = _solve(collision, _translation_frame)
	_check(float(collision_result.task_scale) < 0.375 and collision_result.reason != "arm_extension_reach_limit",
		"reach_cap_does_not_bypass_candidate_validation")
	var budget: Dictionary = Allocator.solve(bounded, _translation_frame, {"max_substeps": 1})
	_check(float(budget.task_scale) < 0.375 and budget.reason == "allocator_substep_budget"
		and not bool(budget.translation_reach_bound.reached), "budget_before_reach_cap_retains_budget_reason")
	var zero := bounded.duplicate(true)
	zero.translation_reach_bound.maximum_fraction = 0.0
	var calls := [0]
	var counted: Callable = func(values: PackedFloat64Array) -> Dictionary:
		calls[0] += 1
		var evaluation := _translation_frame(values)
		evaluation.payload = {"proof": "initial FK retained"}
		return evaluation
	var zero_result: Dictionary = _solve(zero, counted)
	_check(not zero_result.valid and zero_result.status == "SEARCH_EXHAUSTED" and zero_result.reason == "arm_extension_reach_limit"
		and zero_result.task_scale == 0.0 and zero_result.accepted_q == q,
		"zero_reach_bound_reports_unchanged_reach_stop")
	_check(zero_result.iterations == 0 and calls[0] == 2 and zero_result.accepted_payload == {"proof": "initial FK retained"},
		"zero_reach_bound_validates_initial_and_skips_all_fit_search", {"evaluations": calls[0], "iterations": zero_result.iterations})
	zero.validate_candidate = func(_evaluation: Dictionary) -> Dictionary: return {"valid": false}
	var rejected_start: Dictionary = _solve(zero, _translation_frame)
	_check(rejected_start.reason == "allocator_initial_collision_or_context_invalid", "zero_reach_bound_cannot_bypass_initial_validation")
	for fraction: Variant in [-0.1, 1.1, NAN, "0.5", null]:
		var invalid := bounded.duplicate(true)
		invalid.translation_reach_bound.maximum_fraction = fraction
		var invalid_result: Dictionary = _solve(invalid, _translation_frame)
		_check(not invalid_result.valid and invalid_result.reason == "allocator_translation_reach_bound_invalid",
			"invalid_reach_fraction_is_rejected", {"reason": invalid_result.reason})
	var wrong_origin := bounded.duplicate(true)
	wrong_origin.translation_reach_bound.origin_id = "different origin"
	var wrong_result: Dictionary = _solve(wrong_origin, _translation_frame)
	_check(not wrong_result.valid and wrong_result.reason == "allocator_translation_reach_bound_invalid",
		"reach_bound_requires_same_declared_origin")
	# Tip ignores translation, including bounds supplied for a different task.
	var tip := request.duplicate(true)
	tip.mode = "tip"
	var tip_result: Dictionary = _solve(tip, _translation_frame)
	tip.translation_reach_bound = wrong_origin.translation_reach_bound
	_check(var_to_bytes(_solve(tip, _translation_frame)) == var_to_bytes(tip_result), "tip_does_not_consume_translation_bound")

func _coupled_frame(q: PackedFloat64Array) -> Dictionary:
	return {"valid": true, "weapon_frame": Transform3D(Basis(Vector3.RIGHT, q[0] + q[2]) * Basis(Vector3.BACK, q[1]), Vector3.ZERO),
		"constraints": PackedFloat64Array([q[0] * q[0] / 0.25 + q[1] * q[1] / 0.25 - 1.0]), "payload": {}}

func _test_bounded_pommel_stagnation() -> void:
	# Only Y can move. An unreachable X demand dominates the residual while
	# the tiny Y correction gives the QP a real, nonzero joint step. That step
	# improves task norm below the noise floor and cannot reach the target.
	var calls := [0]
	var evaluate: Callable = func(values: PackedFloat64Array) -> Dictionary:
		calls[0] += 1
		return {"valid": true, "weapon_frame": Transform3D(Basis.IDENTITY, Vector3(0.0, values[0], 0.0)),
			"constraints": PackedFloat64Array(), "payload": {}}
	var request := _input(PackedFloat64Array([0.0]), PackedStringArray(["shoulder"]), Transform3D.IDENTITY,
		Transform3D(Basis.IDENTITY, Vector3(0.1, 0.00001, 0.0)), Vector3.ZERO, "pommel")
	var policy := {"max_substeps": 1, "max_translation_step": 1.0, "scale_search_steps": 0}
	var unbounded: Dictionary = Allocator.solve(request, evaluate, policy)
	var unbounded_calls: int = calls[0]
	calls[0] = 0
	request.translation_reach_bound = {"valid": true, "maximum_fraction": 1.0, "origin_id": request.origin_id}
	var result: Dictionary = Allocator.solve(request, evaluate, policy)
	_record("bounded_pommel_unreachable_residual", result)
	var failures: Array = result.get("search_failures", [])
	var failure: Dictionary = failures[0] if not failures.is_empty() else {}
	var details: Dictionary = failure.get("stagnation_diagnostics", {})
	_check(not result.valid and result.accepted_q == request.q and failure.get("reason", "") == "allocator_numerical_stagnation",
		"bounded_pommel_stagnation_never_accepts_unsolved_pose")
	_check(float(details.get("delta_squared", 0.0)) > 1.0e-16 and float(details.get("predicted_residual_gain", INF)) <= float(details.get("progress_floor", 0.0)),
		"stagnation_detects_nonzero_joint_step_with_negligible_task_gain", details)
	_check(calls[0] < unbounded_calls and not unbounded.valid,
		"stagnation_prunes_wasted_trials_without_changing_feasibility", {"bounded_calls": calls[0], "unbounded_calls": unbounded_calls})

func _test_coupled_boundary() -> void:
	var q := PackedFloat64Array([0.5, 0.0, 0.0])
	var target: Transform3D = _coupled_frame(PackedFloat64Array([0.5, 0.0, 0.1])).weapon_frame
	var result: Dictionary = _solve(_input(q, PackedStringArray(["wrist", "wrist", "shoulder"]), _coupled_frame(q).weapon_frame, target, Vector3.ZERO, "tip"), _coupled_frame)
	_record("coupled_boundary_continuation", result)
	_check(_orientation_reached(result, target), "coupled_wrist_boundary_recruits_legal_shoulder")
	if result.get("valid", false):
		var accepted: Dictionary = _coupled_frame(result.accepted_q)
		_check(accepted.constraints[0] <= 0.000001, "final_nonlinear_wrist_envelope_is_legal", {"constraint": accepted.constraints[0]})

func _coverage_boundary_frame(q: PackedFloat64Array) -> Dictionary:
	# A deliberately small nonlinear task with a discontinuous missing-coverage
	# hold. Past 0.45, h must equal its original 0.1. Candidate evaluation never
	# changes that anchor. Repeated Newton trials otherwise cross and retract.
	var state: Dictionary = {"h": q[0]}
	var constraint := -1.0
	if q[0] > 0.45:
		state["held_h"] = 0.1
		constraint = absf(q[0] - 0.1)
	return {"valid": true, "weapon_frame": Transform3D(Basis.IDENTITY, Vector3(q[0] * q[0], 0.0, 0.0)),
		"constraints": PackedFloat64Array([constraint]),
		"constraint_reasons": PackedStringArray(["SHOULDER_HOLD:fixture:hand_right"]),
		"payload": {"shoulder_states_by_slot": {"hand_right": state}}}

func _test_shoulder_coverage_boundary() -> void:
	var q := PackedFloat64Array([0.1])
	var previous: Transform3D = _coverage_boundary_frame(q).weapon_frame
	var target := Transform3D(Basis.IDENTITY, Vector3(0.25, 0.0, 0.0))
	var request := _input(q, PackedStringArray(["shoulder_roll"]), previous, target, Vector3.ZERO, "pommel")
	request.step_sizes = PackedFloat64Array([1.0])
	var policy := {"max_substeps": 1, "max_translation_step": 1.0}
	var result: Dictionary = Allocator.solve(request, _coverage_boundary_frame, policy)
	_record("shoulder_coverage_boundary", result)
	var bounded_failure := false
	for failure: Dictionary in result.get("search_failures", []):
		bounded_failure = bounded_failure or failure.reason == "allocator_shoulder_coverage_boundary"
	_check(bounded_failure, "coverage_crossing_search_stops_repeated_restore_cycles")
	_check(result.get("status", "") == "SCALED" and result.accepted_q[0] > q[0] and result.accepted_q[0] <= 0.45,
		"coverage_boundary_retains_legal_progress_without_changing_hold", {"q": result.get("accepted_q", []), "scale": result.get("task_scale", 0.0)})
	var reverse := _input(result.accepted_q, PackedStringArray(["shoulder_roll"]), result.accepted_weapon, previous, Vector3.ZERO, "pommel")
	reverse.step_sizes = PackedFloat64Array([1.0])
	var backoff: Dictionary = Allocator.solve(reverse, _coverage_boundary_frame, policy)
	_check(backoff.get("status", "") == "ACCEPTED" and absf(backoff.accepted_q[0] - 0.1) < 0.001,
		"coverage_boundary_still_allows_inward_backoff")

func _test_shoulder_hold_crossing_classification() -> void:
	var before := {"payload": {"shoulder_states_by_slot": {"hand_right": {"h": 0.1}}}}
	var after := {"payload": {"shoulder_states_by_slot": {"hand_right": {"h": 0.1, "held_h": 0.1}}},
		"constraints": PackedFloat64Array([0.2, 0.0]),
		"constraint_reasons": PackedStringArray(["JOINT_RANGE:elbow:hand_right", "SHOULDER_HOLD:external:hand_right"])}
	_check(not Allocator._enters_shoulder_hold(before, after), "unrelated_elbow_illegality_does_not_consume_coverage_search_budget")
	after.constraints[1] = 0.2
	after.constraint_reasons[1] = "SHOULDER_HOLD:external:hand_left"
	_check(not Allocator._enters_shoulder_hold(before, after), "opposite_arm_hold_does_not_count_as_new_same_arm_coverage_failure")
	after.constraint_reasons[1] = "SHOULDER_HOLD:external:hand_right"
	_check(Allocator._enters_shoulder_hold(before, after), "only_active_same_arm_hold_counts_as_failed_coverage_crossing")
	after.constraints[1] = 0.0000005
	_check(not Allocator._enters_shoulder_hold(before, after), "hold_residual_inside_existing_epsilon_does_not_count_as_coverage_failure")

func _test_existing_anatomy_can_be_corrected() -> void:
	var context := {"reference": Transform3D.IDENTITY, "anchor": Vector3.ZERO, "contact": Vector3.ZERO}
	var evaluate: Callable = _serial_frame.bind(context)
	var q := PackedFloat64Array([1.1])
	var groups := PackedStringArray(["elbow"])
	var previous: Transform3D = evaluate.call(q).weapon_frame
	var hold: Dictionary = _solve(_input(q, groups, previous, previous, Vector3.ZERO, "tip"), evaluate)
	_check(hold.get("valid", false) and hold.accepted_q == q, "existing_limit_zero_input_does_not_recentre")
	var target: Transform3D = evaluate.call(PackedFloat64Array([1.05])).weapon_frame
	var result: Dictionary = _solve(_input(q, groups, previous, target, Vector3.ZERO, "tip"), evaluate)
	_record("scalar_limit_partial_correction", result)
	_check(_orientation_reached(result, target) and result.accepted_q[0] > 1.0 and result.accepted_q[0] < q[0] - 0.01,
		"existing_scalar_limit_allows_real_partial_correction")
	_check(not (result.get("initial_warning", {}) as Dictionary).is_empty() and not (result.get("pose_warning", {}) as Dictionary).is_empty(),
		"existing_scalar_limit_reports_warning")
	if not result.get("valid", false): return
	q = result.accepted_q
	previous = result.accepted_weapon
	var outward: Transform3D = evaluate.call(PackedFloat64Array([1.15])).weapon_frame
	var refused: Dictionary = _solve(_input(q, groups, previous, outward, Vector3.ZERO, "tip"), evaluate)
	_check(not refused.get("valid", false) or refused.accepted_q[0] <= q[0] + 0.000001,
		"existing_scalar_limit_cannot_worsen")
	target = evaluate.call(PackedFloat64Array([0.95])).weapon_frame
	result = _solve(_input(q, groups, previous, target, Vector3.ZERO, "tip"), evaluate)
	_record("scalar_limit_fresh_request_recovers", result)
	_check(_orientation_reached(result, target) and result.accepted_q[0] < 1.0,
		"fresh_request_can_complete_correction")
	_check((result.get("pose_warning", {}) as Dictionary).is_empty(), "recovered_pose_clears_limit_warning")
	if not result.get("valid", false): return
	q = result.accepted_q
	previous = result.accepted_weapon
	result = _solve(_input(q, groups, previous, outward, Vector3.ZERO, "tip"), evaluate)
	_check(result.accepted_q[0] <= 1.0 + 0.000001, "normal_scalar_limit_returns_after_recovery")
	var detached := previous
	detached.origin.x += 0.01
	result = _solve(_input(q, groups, detached, detached, Vector3.ZERO, "tip"), evaluate)
	_check(not result.get("valid", true) and result.get("reason", "") == "allocator_initial_grip_mismatch",
		"recovery_does_not_relax_initial_attachment")

func _recoverable_coupled_frame(q: PackedFloat64Array) -> Dictionary:
	return {"valid": true, "weapon_frame": Transform3D(Basis(Vector3.RIGHT, q[0]) * Basis(Vector3.BACK, q[1]), Vector3.ZERO),
		"constraints": PackedFloat64Array([q[0] * q[0] + q[1] * q[1] - 1.0]),
		"constraint_reasons": PackedStringArray(["COUPLED_LIMIT:fixture"]), "payload": {}}

func _test_existing_coupled_limit_can_be_corrected() -> void:
	var q := PackedFloat64Array([0.8, 0.8])
	var groups := PackedStringArray(["wrist", "wrist"])
	var previous: Transform3D = _recoverable_coupled_frame(q).weapon_frame
	var target: Transform3D = _recoverable_coupled_frame(PackedFloat64Array([0.75, 0.75])).weapon_frame
	var result: Dictionary = _solve(_input(q, groups, previous, target, Vector3.ZERO, "tip"), _recoverable_coupled_frame)
	_record("coupled_limit_partial_correction", result)
	_check(_orientation_reached(result, target), "existing_coupled_limit_allows_partial_correction")
	if not result.get("valid", false): return
	var excess: float = _recoverable_coupled_frame(result.accepted_q).constraints[0]
	_check(excess > 0.0 and excess < 0.28 - 0.01, "coupled_correction_reduces_but_need_not_instantly_eliminate_excess")
	q = result.accepted_q
	previous = result.accepted_weapon
	target = _recoverable_coupled_frame(PackedFloat64Array([0.85, 0.85])).weapon_frame
	result = _solve(_input(q, groups, previous, target, Vector3.ZERO, "tip"), _recoverable_coupled_frame)
	_check(not result.get("valid", false) or float(_recoverable_coupled_frame(result.accepted_q).constraints[0]) <= excess + 0.000001,
		"coupled_limit_cannot_worsen")
	# The inherited coupled allowance does not make an unrelated, previously
	# legal scalar bound optional.
	target = _recoverable_coupled_frame(PackedFloat64Array([0.6, 1.1])).weapon_frame
	result = _solve(_input(q, groups, previous, target, Vector3.ZERO, "tip"), _recoverable_coupled_frame)
	_check(result.accepted_q[1] <= 1.0 + 0.000001, "recovery_retains_previously_legal_scalar_bound")

func _anchor_drift_frame(q: PackedFloat64Array, context: Dictionary) -> Dictionary:
	var basis: Basis = Basis(Vector3.BACK, q[0])
	return {"valid": true, "weapon_frame": Transform3D(basis, context.anchor + Vector3(q[1], 0.0, 0.0) - basis * context.contact),
		"constraints": PackedFloat64Array(), "payload": {}}

func _test_retained_contact_anchor() -> void:
	var context := {"anchor": Vector3(0.4, 1.2, -0.6), "contact": Vector3(0.035, 0.2, 0.01)}
	var evaluate: Callable = _anchor_drift_frame.bind(context)
	var groups := PackedStringArray(["wrist", "shoulder"])
	var prior_allowed := true
	var result: Dictionary = {}
	# Model small same-direction numerical drift between successive inputs.
	# Each individual increment is <50um; total error must still use the original
	# anchor, rather than repeatedly treating the last drifted pose as zero.
	for step: int in 3:
		var q := PackedFloat64Array([0.0, float(step + 1) * 0.00002])
		var frame: Transform3D = evaluate.call(q).weapon_frame
		var request := _input(q, groups, frame, frame, context.contact, "roll")
		request.contact_anchor = context.anchor
		result = _solve(request, evaluate)
		_record("retained_contact_anchor_drift_%d" % step, result)
		if step < 2:
			prior_allowed = prior_allowed and bool(result.get("valid", false))
	_check(prior_allowed, "retained_anchor_allows_small_initial_numerical_error")
	_check(not result.get("valid", true) and result.get("status", "") == "RECOVERY_REQUIRED" and result.get("reason", "") == "allocator_initial_contact_drift", "retained_anchor_rejects_accumulated_drift")
	var start := PackedFloat64Array([0.0, 0.00004])
	var previous: Transform3D = evaluate.call(start).weapon_frame
	var target: Transform3D = evaluate.call(PackedFloat64Array([0.2, 0.0])).weapon_frame
	var correcting := _input(start, groups, previous, target, context.contact, "roll")
	correcting.contact_anchor = context.anchor
	result = _solve(correcting, evaluate)
	_record("retained_contact_anchor_correction", result)
	_check(_reached(result, target) and (result.accepted_weapon * context.contact).distance_to(context.anchor) <= POSITION_EPSILON, "retained_anchor_used_by_rotation_substeps")
	# A new target can be close to the drifted previous contact but too far from
	# the retained one. It cannot quietly become a new fixed pivot.
	var moved: Transform3D = evaluate.call(PackedFloat64Array([0.0, 0.00008])).weapon_frame
	var shifted_target := _input(start, groups, previous, moved, context.contact, "roll")
	shifted_target.contact_anchor = context.anchor
	result = _solve(shifted_target, evaluate)
	_check(not result.get("valid", true) and result.get("reason", "") == "allocator_rotation_changed_contact_anchor", "retained_anchor_rejects_target_reanchoring")

func _test_no_motion_scaling() -> void:
	var context := {"reference": Transform3D.IDENTITY, "anchor": Vector3.ZERO, "contact": Vector3.ZERO}
	var evaluate: Callable = _serial_frame.bind(context)
	var q := PackedFloat64Array([0.0])
	var frame: Transform3D = evaluate.call(q).weapon_frame
	var request := _input(q, PackedStringArray(["wrist"]), frame,
		evaluate.call(PackedFloat64Array([deg_to_rad(0.5)])).weapon_frame, Vector3.ZERO, "tip")
	request.lower = q.duplicate()
	request.upper = q.duplicate()
	var result: Dictionary = _solve(request, evaluate)
	_record("locked_small_command", result)
	_check(not result.get("valid", true) and result.get("reason", "") == "allocator_no_task_progress" and result.get("task_scale", 1.0) == 0.0,
		"scaling_into_tolerance_does_not_certify_unchanged_motion")
	request.target_weapon = evaluate.call(PackedFloat64Array([deg_to_rad(0.01)])).weapon_frame
	result = _solve(request, evaluate)
	_check(result.get("valid", false) and result.accepted_q == q, "within_tolerance_hold_remains_valid")

func _search_ball_frame(q: PackedFloat64Array) -> Dictionary:
	var residual := Vector3(q[0], q[1], 0.0)
	var guide := 1.0 / sqrt(3.0)
	return {"valid": true, "weapon_frame": Transform3D(Basis.IDENTITY, residual),
		"constraints": PackedFloat64Array([residual.length_squared() - 1.0]),
		"squared_norm_residuals": {0: residual},
		"search_constraints": PackedFloat64Array([q[0] - guide, -q[0] - guide, q[1] - guide, -q[1] - guide]), "payload": {}}

func _test_search_guidance_is_not_hard_legality() -> void:
	var q := PackedFloat64Array([0.8, 0.0])
	var target: Transform3D = _search_ball_frame(PackedFloat64Array([0.7, 0.0])).weapon_frame
	var result: Dictionary = _solve(_input(q, PackedStringArray(["elbow", "shoulder"]),
		_search_ball_frame(q).weapon_frame, target, Vector3.ZERO, "pommel"), _search_ball_frame)
	_record("physical_ball_outside_conservative_search_box", result)
	_check(_reached(result, target), "legal_contact_outside_search_box_can_move_inward")

func _reached(result: Dictionary, target: Transform3D) -> bool:
	if not result.get("valid", false) or not result.get("accepted_weapon") is Transform3D: return false
	var accepted: Transform3D = result.accepted_weapon
	var error := (accepted.basis.orthonormalized().get_rotation_quaternion().inverse() * target.basis.orthonormalized().get_rotation_quaternion()).normalized()
	return accepted.origin.distance_to(target.origin) <= POSITION_EPSILON and 2.0 * atan2(Vector3(error.x, error.y, error.z).length(), absf(error.w)) <= ANGLE_EPSILON

func _orientation_reached(result: Dictionary, target: Transform3D) -> bool:
	return result.get("valid", false) and result.get("accepted_weapon") is Transform3D and _rotation_error(result.accepted_weapon.basis, target.basis) <= ANGLE_EPSILON

func _rotation_error(a: Basis, b: Basis) -> float:
	var delta := (a.orthonormalized().get_rotation_quaternion().inverse() * b.orthonormalized().get_rotation_quaternion()).normalized()
	return 2.0 * atan2(Vector3(delta.x, delta.y, delta.z).length(), absf(delta.w))

func _record(label: String, result: Dictionary) -> void:
	samples.append({"case": label, "result": result})

func _check(passed: bool, label: String, details: Dictionary = {}) -> void:
	checks.append({"passed": passed, "check": label, "details": details})
	if not passed: push_error("WEAPON_MOTION_ALLOCATOR_POLICY " + label + " " + JSON.stringify(details))

func _solve(request: Dictionary, evaluate: Callable) -> Dictionary:
	# Large analytical fixtures span more than one real mouse frame.
	return Allocator.solve(request, evaluate, {"max_substeps": 32})
