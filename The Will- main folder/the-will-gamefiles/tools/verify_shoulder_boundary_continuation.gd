extends SceneTree

## Deterministic continuation-contract fixture, not a second human arm model.
## Three orthogonal/serial prismatic coordinates supply exact affine FK. A
## coupled proximal lower bound changes while the carrier is in coverage.
## The distal coordinate's finite capacity makes a stale proximal hold insufficient,
## while retaining a completed covered checkpoint makes the target reachable.
## The separate imported-rig diagnostic establishes actual Josie behaviour.
const Allocator = preload("res://core/resolvers/combat_weapon_motion_allocator.gd")
const SLOT := &"hand_right"
const POSITION_EPSILON := 0.00005
const ANGLE_EPSILON := 0.000436333
var output_dir := "C:/WORKSPACE/godot_runs/shoulder_boundary_continuation"
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []

class Mechanism extends RefCounted:
	var profile := {"coverage_end": 0.25, "minimum_h": -0.45, "maximum_h": 0.45,
		"minimum_wrist": -0.04, "maximum_wrist": 0.04, "zero": 0.0}
	var state := {"h": 0.05}
	var callbacks: Array[Dictionary] = []
	var verified: Dictionary = {}
	var reject_motion := false
	var initial_s := 0.1
	var evaluation_count := 0

	func frame(values: PackedFloat64Array) -> Transform3D:
		return Transform3D(Basis.IDENTITY, Vector3(values[0], values[1] + values[2], 0.0))

	func target(s: float) -> Transform3D:
		return Transform3D(Basis.IDENTITY, Vector3(s, 0.5 * s, 0.0))

	func evaluate(values: PackedFloat64Array) -> Dictionary:
		evaluation_count += 1
		var covered: bool = values[0] <= float(profile.coverage_end)
		var held: float = state.get("held_h", state.h)
		var minimum: float = maxf(float(profile.minimum_h), 0.5 * values[0]) if covered else held
		var maximum: float = profile.maximum_h if covered else held
		var next := {"h": values[1]}
		if not covered:
			next["held_h"] = held
		var prefix := "JOINT_RANGE:" if covered else "SHOULDER_HOLD:"
		return {"valid": true, "weapon_frame": frame(values),
			"constraints": PackedFloat64Array([minimum - values[1], values[1] - maximum]),
			"constraint_reasons": PackedStringArray([prefix + "external:hand_right", prefix + "internal:hand_right"]),
			"payload": {"q": values.duplicate(), "shoulder_states_by_slot": {SLOT: next}}}

	func validate(evaluation: Dictionary) -> Dictionary:
		var values: PackedFloat64Array = evaluation.payload.q
		var valid := not reject_motion or absf(values[0] - initial_s) < 1.0e-10
		if valid:
			verified[var_to_str(values)] = true
		return {"valid": valid}

	func advance(evaluation: Dictionary) -> bool:
		var next: Dictionary = evaluation.payload.shoulder_states_by_slot[SLOT]
		var values: PackedFloat64Array = evaluation.payload.q
		var before := state.duplicate(true)
		var changed := false
		if not (next.has("held_h") and state.has("held_h")):
			changed = state.has("held_h") != next.has("held_h") or absf(float(state.h) - float(next.h)) > 1.0e-8
			state = next.duplicate(true)
		var constraints: PackedFloat64Array = evaluation.constraints
		callbacks.append({"q": values, "before": before, "after": state.duplicate(true),
			"previously_validated": verified.has(var_to_str(values)), "changed": changed,
			"maximum_constraint": maxf(constraints[0], constraints[1]),
			"orientation_error": Allocator._rotation_vector(target(values[0]).basis, frame(values).basis).length()})
		return changed

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			output_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")

func _run() -> void:
	_test_boundary_continuation()
	_test_no_checkpoint_on_rejected_or_stationary_input()
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var report := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if report == null:
		push_error("Cannot create shoulder continuation report")
		quit(1)
		return
	report.store_string(JSON.stringify({"passed": passed, "checks": checks, "samples": samples,
		"scope": "Small serial-mechanism continuation contract; no imported-rig, grip acquisition, skin or playback certification."}, "\t"))
	report.close()
	print("SHOULDER_BOUNDARY_CONTINUATION passed=%s checks=%d output=%s" % [passed, checks.size(), output_dir])
	quit(0 if passed else 1)

func _request(fixture: Mechanism, q: PackedFloat64Array, target_s: float, continuation: bool = true) -> Dictionary:
	var request := {"q": q.duplicate(), "lower": PackedFloat64Array([-0.5, fixture.profile.minimum_h, fixture.profile.minimum_wrist]),
		"upper": PackedFloat64Array([0.5, fixture.profile.maximum_h, fixture.profile.maximum_wrist]),
		"joint_groups": PackedStringArray(["elbow", "shoulder_roll", "wrist"]),
		"step_sizes": PackedFloat64Array([0.25, 0.25, 0.25]), "previous_weapon": fixture.frame(q),
		"target_weapon": fixture.target(target_s), "contact_local": Vector3.ZERO, "mode": "pommel",
		"origin_id": &"ShoulderContinuationFixtureOrigin", "validate_candidate": Callable(fixture, "validate")}
	if continuation:
		request["advance_accepted_checkpoint"] = Callable(fixture, "advance")
	return request

func _solve(fixture: Mechanism, q: PackedFloat64Array, target_s: float, label: String, continuation: bool = true) -> Dictionary:
	var request := _request(fixture, q, target_s, continuation)
	var immutable := request.duplicate(true)
	immutable.erase("validate_candidate")
	immutable.erase("advance_accepted_checkpoint")
	var before := var_to_bytes(immutable)
	var profile_before := var_to_bytes(fixture.profile)
	var result: Dictionary = Allocator.solve(request, Callable(fixture, "evaluate"), {
		"max_substeps": 1, "max_translation_step": 1.0})
	immutable = request.duplicate(true)
	immutable.erase("validate_candidate")
	immutable.erase("advance_accepted_checkpoint")
	_check(before == var_to_bytes(immutable), label + ":request_not_mutated")
	_check(profile_before == var_to_bytes(fixture.profile), label + ":profile_and_zero_not_mutated")
	_check(result.get("coverage_handoffs", []).size() <= 2, label + ":handoffs_bounded")
	samples.append({"label": label, "status": result.get("status"), "reason": result.get("reason"),
		"task_scale": result.get("task_scale"), "accepted_q": result.get("accepted_q"),
		"handoffs": result.get("coverage_handoffs", []), "iterations": result.get("iterations"),
		"state": fixture.state.duplicate(true)})
	return result

func _test_boundary_continuation() -> void:
	var q := PackedFloat64Array([0.1, 0.05, 0.0])
	var old := Mechanism.new()
	var blocked := _solve(old, q, 0.3, "without_continuation", false)
	_check(not _reached(blocked, old.target(0.3)), "stale_request_start_hold_cannot_reach_target")
	var fixture := Mechanism.new()
	var result := _solve(fixture, q, 0.3, "cross_coverage")
	_check(_reached(result, fixture.target(0.3)), "covered_checkpoint_allows_full_requested_translation")
	_check(not result.get("coverage_handoffs", []).is_empty(), "crossing_uses_certified_partial_checkpoint")
	if not result.get("valid", false):
		return
	q = result.accepted_q
	_check(q[1] > 0.10 and q[2] > 0.01, "proximal_motion_then_distal_compensation", {"q": q})
	_check(fixture.state.has("held_h"), "uncovered_result_retains_hold")
	var held: float = fixture.state.get("held_h", NAN)
	for trial: int in 3:
		# New request models release/regrab. Persist only accepted semantic state;
		# the original fixed h reference and profile are never reconstructed.
		result = _solve(fixture, q, 0.45, "outside_regrab_%d" % trial)
		q = result.accepted_q
		_check(absf(float(fixture.state.get("held_h", INF)) - held) < 1.0e-12,
			"outside_regrab_%d:hold_never_ratchets" % trial)
		_check(absf(q[1] - held) <= 0.000002 and q[2] >= fixture.profile.minimum_wrist - 0.000002 and q[2] <= fixture.profile.maximum_wrist + 0.000002,
			"outside_regrab_%d:joint_limits_remain_firm" % trial, {"q": q})
	result = _solve(fixture, q, 0.1, "reverse_into_coverage")
	_check(_reached(result, fixture.target(0.1)), "reverse_reenters_coverage_without_reset")
	_check(not fixture.state.has("held_h"), "measured_reentry_releases_only_transient_hold")
	if result.get("valid", false):
		q = result.accepted_q
		result = _solve(fixture, q, 0.3, "cross_again_after_reverse")
		_check(_reached(result, fixture.target(0.3)), "repeated_crossing_still_reaches_target")
	for index: int in fixture.callbacks.size():
		var callback: Dictionary = fixture.callbacks[index]
		_check(callback.previously_validated and callback.maximum_constraint <= 0.000001,
			"checkpoint_%d:certified_before_notification" % index)
		_check(callback.orientation_error <= ANGLE_EPSILON * 1.1,
			"checkpoint_%d:on_original_fixed_orientation_path" % index)
	samples.append({"label": "checkpoint_history", "callbacks": fixture.callbacks})

func _test_no_checkpoint_on_rejected_or_stationary_input() -> void:
	var q := PackedFloat64Array([0.1, 0.05, 0.0])
	var fixture := Mechanism.new()
	var stationary := _solve(fixture, q, 0.1, "stationary")
	_check(stationary.accepted_q == q and fixture.callbacks.is_empty(), "stationary_input_has_no_checkpoint")
	fixture.reject_motion = true
	var result := _solve(fixture, q, 0.3, "validator_rejects_motion")
	_check(not result.get("valid", true) and fixture.callbacks.is_empty(), "rejected_motion_has_no_checkpoint")
	fixture.reject_motion = false
	var request := _request(fixture, q, 0.3)
	request.lower = PackedFloat64Array()
	result = Allocator.solve(request, Callable(fixture, "evaluate"))
	_check(not result.valid and fixture.callbacks.is_empty(), "invalid_input_has_no_checkpoint")

func _reached(result: Dictionary, target: Transform3D) -> bool:
	if not result.get("valid", false) or not result.get("accepted_weapon") is Transform3D:
		return false
	var actual: Transform3D = result.accepted_weapon
	return actual.origin.distance_to(target.origin) <= POSITION_EPSILON and Allocator._rotation_vector(target.basis, actual.basis).length() <= ANGLE_EPSILON * 1.1

func _check(passed: bool, label: String, details: Dictionary = {}) -> void:
	checks.append({"passed": passed, "check": label, "details": details})
