extends SceneTree

const Solver = preload("res://tools/grip_plane_proof/prepared_skin_contact_solver.gd")
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var solver := Solver.new()
	var snapshot := _snapshot([0.0, 0.0, 0.0], [1.0, 1.0, 1.0], [1.0, 1.0, 1.0])
	var before := var_to_bytes(snapshot)
	var first_trace: Array = []
	var second_trace: Array = []
	var first := solver.solve(snapshot, &"SyntheticDigitPlaneOrigin", _analytic.bind(first_trace), {"max_pose_evaluations": 180})
	var second := solver.solve(snapshot, &"SyntheticDigitPlaneOrigin", _analytic.bind(second_trace), {"max_pose_evaluations": 180})
	_check(bool(first.get("valid", false)), "coupled analytic objective provides usable candidate")
	_check(first.get("status") == "provisional_clear_contact_candidate", "known synthetic optimum classified provisional contact")
	_check(_angle_error(first.get("angles_rad", []), [0.5, 1.0, 0.0]) <= 1.0e-12 and absf(float(first.get("score", INF))) <= 1.0e-12, "coupled three-angle objective reaches known unique grid configuration")
	_check(int(first.get("ranking_region_contact_count", 0)) == 3, "known synthetic optimum meets all three gap targets")
	_check(first_trace == second_trace, "repeat callback order is deterministic")
	_check(_stable_result(first) == _stable_result(second), "repeat result and accounting are deterministic excluding timings")
	_check(int(first.get("evaluations", -1)) == first_trace.size() and first_trace.size() <= 180, "evaluation accounting respects unique-callback budget")
	_check(_unique_count(first_trace) == first_trace.size(), "exact angle cache suppresses duplicate callback invocations")
	_check(int(first.get("cache_hits", 0)) > 0, "repeated seed and neighborhood tuples use cache")
	_check(var_to_bytes(snapshot) == before, "solver leaves input joint definition unchanged")
	_check(not bool(first.get("actual_3d_grip_verified", true)) and not bool(first.get("production_pose_written", true)) and not bool(first.get("search_exhaustive", true)), "synthetic result does not claim real grip, writes or exhaustive search")

	for budget: int in [1, 3, 11, 37]:
		var trace: Array = []
		var result := solver.solve(snapshot, &"SyntheticDigitPlaneOrigin", _analytic.bind(trace), {"max_pose_evaluations": budget})
		_check(trace.size() == budget and int(result.evaluations) == trace.size(), "strict callback cap " + str(budget))

	var locked := _snapshot([0.2, -0.3, 0.4], [0.2, -0.3, 0.4], [0.2, -0.3, 0.4])
	var locked_trace: Array = []
	var locked_result := solver.solve(locked, &"SyntheticDigitPlaneOrigin", _analytic.bind(locked_trace), {"max_pose_evaluations": 50})
	_check(locked_trace.size() == 1 and int(locked_result.evaluations) == 1 and int(locked_result.cache_hits) > 1, "locked joint tuple evaluated once across seed and neighborhood repeats")
	_check(_angle_error(locked_result.get("angles_rad", []), [0.2, -0.3, 0.4]) <= 1.0e-12, "locked joint configuration preserved")

	var offset_limits := _snapshot([0.2, -0.8, 0.1], [0.7, -0.2, 0.9], [0.6, -0.5, 0.8])
	var bounded_trace: Array = []
	solver.solve(offset_limits, &"SyntheticDigitPlaneOrigin", _analytic.bind(bounded_trace), {"max_pose_evaluations": 100})
	_check(_all_in_limits(bounded_trace, offset_limits), "all seeds and refinements stay within positive-only and negative-only ranges")

	var bad_preferred := snapshot.duplicate(true)
	bad_preferred.preferred_angles_rad[1] = NAN
	var invalid_trace: Array = []
	var nan_result := solver.solve(bad_preferred, &"SyntheticDigitPlaneOrigin", _analytic.bind(invalid_trace))
	_check(not bool(nan_result.get("valid", true)) and invalid_trace.is_empty(), "nonfinite preferred angle rejected before evaluator")
	bad_preferred.preferred_angles_rad[1] = 1.1
	_check(not bool(solver.solve(bad_preferred, &"SyntheticDigitPlaneOrigin", _analytic.bind(invalid_trace)).get("valid", true)) and invalid_trace.is_empty(), "out-of-range preferred angle rejected before evaluator")
	var bad_limits := snapshot.duplicate(true)
	bad_limits.min_angles_rad[0] = 2.0
	_check(not bool(solver.solve(bad_limits, &"SyntheticDigitPlaneOrigin", _analytic.bind(invalid_trace)).get("valid", true)), "inverted range rejected")
	_check(not bool(solver.solve(snapshot, &"", _analytic.bind(invalid_trace)).get("valid", true)), "missing named plane rejected")
	_check(not bool(solver.solve(snapshot, &"SyntheticDigitPlaneOrigin", Callable()).get("valid", true)), "missing evaluator rejected")

	var rejected_trace: Array = []
	var rejected := solver.solve(snapshot, &"SyntheticDigitPlaneOrigin", _reject_all.bind(rejected_trace), {"max_pose_evaluations": 17})
	_check(not bool(rejected.get("valid", true)) and rejected.get("status") == "no_usable_pose_evaluation", "all rejected evaluations produce no usable candidate")
	_check(not rejected.has("angles_rad") and not bool(rejected.get("boundary_candidate_clear", false)), "all-invalid result has no selected angles or clear state")
	_check(int(rejected.get("invalid_evaluations", -1)) == rejected_trace.size() and rejected_trace.size() == 17, "all-invalid accounting remains bounded")
	_check(int(rejected.get("invalid_reasons", {}).get("synthetic_rejection", 0)) == 17, "invalid callback reasons retained")

	var mixed_trace: Array = []
	var mixed := solver.solve(snapshot, &"SyntheticDigitPlaneOrigin", _reject_false_clear.bind(mixed_trace), {"max_pose_evaluations": 40})
	_check(bool(mixed.get("valid", false)) and int(mixed.get("invalid_evaluations", 0)) > 0, "mixed valid and rejected callbacks retain valid diagnostics")
	_check(not bool(mixed.get("boundary_candidate_clear", true)) and mixed.get("status") == "no_clear_candidate_within_budget", "rejected false-clear callback cannot defeat valid intersecting candidates")
	_check(_angle_error(mixed.get("angles_rad", []), [0.0, 0.0, 0.0]) > 0.0, "rejected zero-angle tuple is not selected")

	var only_zero := _snapshot([0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0])
	for scenario: String in ["static_crossing", "inside", "coincident", "contact_invalid", "reported_planar_overlap", "reverse_containment"]:
		var result := solver.solve(only_zero, &"SyntheticDigitPlaneOrigin", _scenario.bind(scenario))
		_check(not bool(result.get("boundary_candidate_clear", false)), scenario + " never reported clear")
		if scenario == "contact_invalid":
			_check(not bool(result.get("valid", true)), "invalid contact packet is unusable even when outer callback is valid")
		if scenario in ["reported_planar_overlap", "reverse_containment"]:
			_check(int(result.get("ranking_region_contact_count", -1)) == 0 and result.get("status") == "no_clear_candidate_within_budget", scenario + " cannot produce ranked contact through zero gaps")
	print("PREPARED_SKIN_CONTACT_SOLVER_VERIFICATION=" + JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"known_configuration": first.get("angles_rad", []), "known_score": first.get("score"), "evaluations": first.get("evaluations"), "cache_hits": first.get("cache_hits"),
		"synthetic_callbacks_only": true, "actual_character_or_weapon_contact_verified": false, "files_written": false}))
	quit(0 if failures.is_empty() else 1)

func _snapshot(minimum: Array, maximum: Array, preferred: Array) -> Dictionary:
	return {"min_angles_rad": minimum, "max_angles_rad": maximum, "preferred_angles_rad": preferred}

func _analytic(angles: Array[float], trace: Array) -> Dictionary:
	trace.append(angles.duplicate())
	var delta := Vector3(angles[0] - 0.5, angles[1] - 1.0, angles[2])
	# Invertible coupled linear system: all three gaps vanish only at (.5,1,0).
	# These gaps are a synthetic optimizer test, not physical contact geometry.
	return _packet([absf(delta.x + delta.y), absf(delta.y + delta.z), absf(delta.x + delta.z)])

func _packet(gaps: Array) -> Dictionary:
	var regions: Array[Dictionary] = []
	for index: int in range(3):
		regions.append({"region_index": index, "gap_m": gaps[index]})
	return {"valid": true, "contact": {"valid": true, "dynamic": {"proper_crossings": 0, "sampled_inside_depth_m": 0.0, "inside_interval_samples": 0},
		"fixed_static": {"proper_crossings": 0, "sampled_inside_depth_m": 0.0, "inside_interval_samples": 0}, "ranking_regions": regions, "coincident_boundaries_unclassified": false}}

func _reject_all(angles: Array[float], trace: Array) -> Dictionary:
	trace.append(angles.duplicate())
	return {"valid": false, "reason": "synthetic_rejection"}

func _reject_false_clear(angles: Array[float], trace: Array) -> Dictionary:
	trace.append(angles.duplicate())
	var packet := _packet([0.0, 0.0, 0.0])
	if _angle_error(angles, [0.0, 0.0, 0.0]) == 0.0:
		packet.valid = false
		packet.reason = "false_clear_rejected"
	else:
		packet.contact.dynamic.proper_crossings = 1
	return packet

func _scenario(_angles: Array[float], scenario: String) -> Dictionary:
	var packet := _packet([0.0, 0.0, 0.0])
	match scenario:
		"static_crossing":
			packet.contact.fixed_static.proper_crossings = 1
		"inside":
			packet.contact.dynamic.inside_interval_samples = 1
			packet.contact.dynamic.sampled_inside_depth_m = 0.0001
		"coincident":
			packet.contact.coincident_boundaries_unclassified = true
		"contact_invalid":
			packet.contact.valid = false
		"reported_planar_overlap":
			packet.contact.planar_overlap_detected = true
		"reverse_containment":
			packet.contact.target_inside_skin_interval_samples = 1
	return packet

func _angle_error(first: Array, second: Array) -> float:
	if first.size() != 3 or second.size() != 3:
		return INF
	var error := 0.0
	for index: int in range(3):
		error = maxf(error, absf(float(first[index]) - float(second[index])))
	return error

func _unique_count(trace: Array) -> int:
	var keys: Dictionary = {}
	for angles: Array in trace:
		keys[var_to_bytes(angles).hex_encode()] = true
	return keys.size()

func _all_in_limits(trace: Array, snapshot: Dictionary) -> bool:
	for angles: Array in trace:
		for index: int in range(3):
			if not is_finite(float(angles[index])) or float(angles[index]) < float(snapshot.min_angles_rad[index]) or float(angles[index]) > float(snapshot.max_angles_rad[index]):
				return false
	return not trace.is_empty()

func _stable_result(result: Dictionary) -> Dictionary:
	var stable := result.duplicate(true)
	stable.erase("candidate_evaluation_ms")
	stable.erase("elapsed_ms")
	return stable

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)
