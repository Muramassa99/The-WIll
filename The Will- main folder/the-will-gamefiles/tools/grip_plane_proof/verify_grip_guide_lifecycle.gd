extends SceneTree

## Exercise production guide transitions/reseat orchestration with controlled
## projection replies. This is not a geometry, IK-convergence or live-grip proof.
const Solver = preload("res://runtime/player/grip/contact_driven_grip_preparation.gd")
const Derivatives = preload("res://runtime/player/grip/skin_contact_hinge_jacobian.gd")
const DIGITS := [&"middle", &"thumb", &"index", &"ring", &"pinky"]
const RADIUS_M := 0.117


class FollowFixture extends Solver:
	var mode := "success"
	var calls: Array = []
	var commits: Array = []

	func _project(_context: Dictionary, _saved: Dictionary, seed: Dictionary, radius: float,
			_movable: bool, _palm: bool, _guide_kind: StringName = &"circle",
			_retain_material: Array = [], _settle: bool = false, _retained_slices: Dictionary = {}) -> Dictionary:
		var proposed: float = _working_guides[seed.digit].progress
		calls.append({"proposed":proposed, "seed_progress":seed.get("guide_progress", -1.0)})
		var sample: Dictionary = seed.duplicate(true)
		sample.merge({"persistent_guide":true, "attached":true, "guide_progress":proposed,
			"working_guide":{"initial_radius_m":radius, "progress":proposed}}, true)
		if calls.size() == 1:
			return {"converged":mode != "initial_unconverged", "sample":sample,
				"reason":"projection_budget_not_physical_limit" if mode == "initial_unconverged" else "fixture_attachment"}
		if mode in ["stale_failed", "stale_converged"]:
			return {"converged":mode == "stale_converged", "sample":seed.duplicate(true), "reason":"fixture_target_evaluation_failed"}
		if mode == "wrong_radius": sample.working_guide.initial_radius_m = radius + 0.01
		if mode == "detached": sample.attached = false
		if mode == "adaptive" and proposed - float(seed.guide_progress) > 0.35:
			return {"converged":false, "sample":seed.duplicate(true), "reason":"projection_budget_not_physical_limit"}
		if mode == "plateau" and proposed > 0.5:
			return {"converged":false, "sample":seed.duplicate(true), "reason":"projection_budget_not_physical_limit"}
		if mode in ["numerical_at_bound", "current_unconverged", "material_direction"]:
			return {"converged":false, "sample":sample,
				"reason":"material_constraints_reject_proposed_direction" if mode == "material_direction" else "projection_budget_not_physical_limit"}
		return {"converged":true, "sample":sample, "reason":"fixture_attached_response"}

	func _record(sample: Dictionary, label: String, committed: bool) -> void:
		commits.append({"label":label, "committed":committed,
			"progress":sample.get("guide_progress", -1.0), "attached":sample.get("attached", false),
			"radius_m":sample.get("working_guide", {}).get("initial_radius_m", -1.0)})


class DerivativeFixture extends Derivatives:
	func prepare(_adapter: Dictionary, _digit: StringName, _palm: Dictionary = {}, _observation: StringName = &"") -> Dictionary:
		return {"valid":true}


## Only run()'s reseat orchestration is under test in this fixture. Its geometry,
## validation, projection and guide-following replies are controlled separately.
class ReseatFixture extends Solver:
	var mode := "improving"
	var reseat_calls := 0
	var committed_reseats := 0

	func _init() -> void:
		_jacobian = DerivativeFixture.new()
		configure_evaluation(false, 0.00005)

	func _validate_context(_context: Dictionary, _saved: Dictionary) -> Dictionary:
		return {"valid":true}

	func _evaluate(_context: Dictionary, _saved: Dictionary, angles: Dictionary, placement: Vector2,
			digit: StringName, radius: float, palm: bool, _reuse: Dictionary = {},
			guide_kind: StringName = &"circle") -> Dictionary:
		return {"valid":true, "digit":digit, "angles":angles.duplicate(true), "placement":placement,
			"radius_m":radius, "enclosing_radius_m":0.03, "palm_required":palm, "guide_kind":guide_kind,
			"attached":true, "quality":10.0, "material_assessed":true, "material_safe":true,
			"material_contacts":["middle/S1", "middle/S2", "middle/S3"],
			"accepted_contact_constraints":true, "candidate":{"hand_to_world":Transform3D.IDENTITY},
			"persistent_guide":guide_kind == &"saved_wrapper"}

	func _project(_context: Dictionary, _saved: Dictionary, seed: Dictionary, _radius: float,
			_movable: bool, _palm: bool, _guide_kind: StringName = &"circle",
			_retain_material: Array = [], settle: bool = false, _retained_slices: Dictionary = {}) -> Dictionary:
		var sample: Dictionary = seed.duplicate(true)
		if settle:
			reseat_calls += 1
			if mode != "no_improvement": sample.quality -= 1.0
			if mode == "detached": sample.attached = false
		return {"converged":sample.attached, "sample":sample, "reason":"fixture_reseat_response"}

	func _follow_guide(_context: Dictionary, _saved: Dictionary, seed: Dictionary,
			_movable: bool, _palm: bool, _retained: Dictionary) -> Dictionary:
		var sample: Dictionary = seed.duplicate(true)
		sample.guide_kind = &"saved_wrapper"
		sample.persistent_guide = true
		_working_guides[seed.digit] = {"radius_m":seed.radius_m, "progress":1.0}
		_guidance_results[seed.digit] = {"attached":true, "progress":1.0,
			"initial_radius_m":seed.radius_m, "stop_reason":"saved_wrapper_reached"}
		return {"valid":true, "converged":true, "sample":sample, "reason":"saved_wrapper_reached"}

	func _attraction_selection(sample: Dictionary, _allow_preference: bool = true) -> Dictionary:
		return {"merit":sample.quality}

	func _public(sample: Dictionary) -> Dictionary:
		return sample.duplicate(true)

	func _record(_sample: Dictionary, label: String, committed: bool) -> void:
		if label == "middle_saved_wrapper_reseated" and committed: committed_reseats += 1


var _checks := 0
var _failures: Array[String] = []
var _cases: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_usec()
	for digit: StringName in DIGITS:
		for mode: String in ["stale_failed", "stale_converged", "wrong_radius", "detached",
				"numerical_at_bound", "current_unconverged", "material_direction", "initial_unconverged"]:
			_rejected_progression(digit, mode)
		_successful_progression(digit, "success")
		_successful_progression(digit, "adaptive")
	_partial_progression()
	_reseating()
	var report := {"schema":"grip_guide_lifecycle_v1", "ok":_failures.is_empty(),
		"checks":_checks, "failures":_failures, "cases":_cases,
		"production_follow_guide_exercised":true, "production_reseat_loop_exercised":true,
		"projection_geometry_and_derivatives_mocked":true, "production_pose_written":false,
		"physical_stop_certified":false, "live_grip_verified":false,
		"solver_sha256":FileAccess.get_sha256("res://runtime/player/grip/contact_driven_grip_preparation.gd"),
		"elapsed_ms":float(Time.get_ticks_usec() - started) / 1000.0}
	var path := "C:/WORKSPACE/test_artifacts/grip_guide_lifecycle_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write guide lifecycle verification report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("GRIP_GUIDE_LIFECYCLE=" + JSON.stringify({"ok":report.ok,"checks":_checks,
		"failures":_failures,"report":path,"elapsed_ms":report.elapsed_ms}))
	quit(0 if _failures.is_empty() else 1)


func _seed(digit: StringName) -> Dictionary:
	return {"valid":true, "digit":digit, "radius_m":RADIUS_M, "enclosing_radius_m":0.03,
		"attached":true, "persistent_guide":false, "guide_progress":0.0,
		"angles":{digit:[0.0, 0.0, 0.0]}, "material_contacts":[]}


func _context(digit: StringName) -> Dictionary:
	# An unrelated open hinge is exactly at its minimum. That alone must not
	# promote a numerical failure into a verified physical stopping condition.
	return {"adapter":{"digit_inputs":{digit:{"snapshot":{
		"min_angles_rad":[0.0, 0.0, 0.0], "max_angles_rad":[1.0, 1.0, 1.0]}}}}}


func _rejected_progression(digit: StringName, mode: String) -> void:
	var fixture := FollowFixture.new()
	fixture.mode = mode
	var seed := _seed(digit)
	var original := var_to_bytes(seed)
	var result := fixture._follow_guide(_context(digit), {}, seed, digit == &"middle", digit == &"middle", {})
	var label := str(digit) + "/" + mode
	_check(not result.get("valid", false) and not result.get("converged", false), label + " remains unresolved")
	_check(fixture._working_guides[digit].progress == 0.0, label + " failed target never becomes committed guide progress")
	_check(not fixture._guidance_results[digit].get("physical_limit_verified", false), label + " cannot certify a physical stop")
	_check(not fixture._guidance_results[digit].get("destination_reached", false), label + " cannot claim saved wrapper reached")
	_check(fixture.calls.size() < 100, label + " rejection terminates without unbounded retry")
	_check(var_to_bytes(seed) == original, label + " caller seed is unchanged")
	for commit: Dictionary in fixture.commits:
		_check(commit.progress == 0.0 and commit.attached and commit.radius_m == RADIUS_M, label + " only genuine initial attachment may be committed")
	if mode == "initial_unconverged":
		_check(fixture.commits.is_empty(), label + " unverified initial attachment produces no committed pose")
	_cases.append({"digit":str(digit), "mode":mode, "valid":result.get("valid", false),
		"reason":result.get("reason", ""), "calls":fixture.calls.size(), "commits":fixture.commits})


func _successful_progression(digit: StringName, mode: String) -> void:
	var fixture := FollowFixture.new()
	fixture.mode = mode
	var result := fixture._follow_guide(_context(digit), {}, _seed(digit), digit == &"middle", digit == &"middle", {})
	var label := str(digit) + "/" + mode
	_check(result.get("valid", false) and result.get("converged", false), label + " reaches the saved target")
	_check(fixture._working_guides[digit].progress == 1.0 and fixture._guidance_results[digit].destination_reached, label + " reported guide matches final endpoint")
	_check(not fixture._guidance_results[digit].physical_limit_verified, label + " endpoint success does not invent a physical stop certificate")
	var previous := -1.0
	for commit: Dictionary in fixture.commits:
		_check(commit.attached and commit.radius_m == RADIUS_M and commit.progress > previous, label + " every committed state is attached and advances matching guide")
		if mode == "adaptive" and previous >= 0.0:
			_check(commit.progress - previous <= 0.35, label + " rejected large jump is not committed")
		previous = commit.progress
	_check(previous == 1.0, label + " final committed surface is exact endpoint")
	_cases.append({"digit":str(digit), "mode":mode, "calls":fixture.calls.size(), "commits":fixture.commits})


func _partial_progression() -> void:
	var fixture := FollowFixture.new()
	fixture.mode = "plateau"
	var result := fixture._follow_guide(_context(&"middle"), {}, _seed(&"middle"), true, true, {})
	_check(not result.get("valid", false), "numerical failure after real partial progress remains unresolved")
	_check(fixture._working_guides[&"middle"].progress == 0.5, "partial failure retains last genuinely attached guide")
	_check(fixture._guidance_results[&"middle"].attached and not fixture._guidance_results[&"middle"].physical_limit_verified, "diagnostic attachment does not imply completed physical stop")
	for commit: Dictionary in fixture.commits:
		_check(commit.progress <= 0.5, "failed later proposals never enter committed partial history")
	_cases.append({"mode":"plateau", "reason":result.get("reason", ""), "commits":fixture.commits})


func _reseating() -> void:
	var context := {"adapter":{"slot":&"hand_right", "base_packet":{"pose_id":&"GuideLifecycleFixture"},
		"digit_inputs":{&"middle":{}}, "baseline_hand_to_world":Transform3D.IDENTITY},
		"digit_order":[&"middle"], "open_parameters":[0.0, 0.0, 0.0],
		"observations":{&"middle":{"reach_m":RADIUS_M}}, "outward_parameters":Vector2.RIGHT, "palm_region":{}}
	for mode: String in ["improving", "no_improvement", "detached"]:
		var fixture := ReseatFixture.new()
		fixture.mode = mode
		var result: Dictionary = fixture.run(context.duplicate(true), {}, null)
		_check(result.get("valid", false), mode + " controlled reseat orchestration finishes")
		var expected := 3 if mode == "improving" else 1
		_check(fixture.reseat_calls == expected and result.get("reseat_attempts", -1) == expected, mode + " production reseat loop obeys three-attempt failsafe and early stop")
		_check(fixture.committed_reseats == (3 if mode == "improving" else 0), mode + " only attached improvements become committed reseats")
		_cases.append({"mode":"reseat_" + mode, "reseat_calls":fixture.reseat_calls,
			"committed_reseats":fixture.committed_reseats})


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error(label)
