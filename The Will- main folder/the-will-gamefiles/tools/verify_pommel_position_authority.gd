extends SceneTree

const Allocator = preload("res://core/resolvers/combat_weapon_motion_allocator.gd")
const TASK_POINT := Vector3(0.4, 0.1, -0.05)
const GRIP_POINT := Vector3(0.0, -0.2, 0.0)
var checks: Array[Dictionary] = []
var records: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Transform3D(Basis.IDENTITY, Vector3(2.0, 3.0, 1.0))
	var evaluator := _hinge_evaluator(world)
	var previous: Transform3D = evaluator.call(PackedFloat64Array([0.0])).weapon_frame
	var destination: Transform3D = evaluator.call(PackedFloat64Array([0.4])).weapon_frame
	# The pointer gives a desired landmark position. Its old orientation is
	# descriptive input only; the existing hinge must be free to turn the prop.
	var target := previous
	target.origin = destination * TASK_POINT - previous.basis * TASK_POINT
	var request := _input("pommel", previous, target)
	# One endpoint request: a single hinge follows an arc, so intermediate
	# points on the pointer's straight chord are not themselves reachable.
	var result := Allocator.solve(request, evaluator, {"max_translation_step": 1.0})
	records["position_only"] = _summary(result)
	_check(bool(result.get("valid", false)), "position_only_reaches_using_existing_hinge", result)
	var actual: Transform3D = result.get("accepted_weapon", previous)
	_check((actual * TASK_POINT).distance_to(destination * TASK_POINT) <= 0.00005, "actual_nonzero_pommel_point_reaches_pointer")
	_check(actual.origin.distance_to(previous.origin) <= 0.000001, "weapon_root_is_not_mistaken_for_pommel")
	_check(absf(float(result.accepted_q[0]) - 0.4) <= 0.0002, "existing_hinge_supplies_required_rotation")
	_check(not bool(result.get("orientation_constrained", true)), "pommel_reports_position_authority_only")
	var fixed_request := request.duplicate(true)
	fixed_request.mode = "pose"
	var old_equivalent := Allocator.solve(fixed_request, evaluator, {"max_translation_step": 1.0})
	records["fixed_pose_counterfactual"] = _summary(old_equivalent)
	_check(not bool(old_equivalent.get("valid", false)), "old_fixed_orientation_pose_cannot_reach_same_pointer")
	# Free task orientation never relaxes the initial acquired-frame contract.
	var mismatched := request.duplicate(true)
	mismatched.previous_weapon = Transform3D(Basis(Vector3.BACK, 0.15), previous.origin)
	var rejected := Allocator.solve(mismatched, evaluator)
	_check(not bool(rejected.get("valid", false)) and String(rejected.get("reason", "")).contains("grip_mismatch"), "initial_actual_orientation_mismatch_still_rejected", _summary(rejected))
	# Named/root-independent inputs: same hinge, arbitrary rigid origin and
	# uniform scale. A world-space point must not become a global-axis guess.
	var moved_origin := Transform3D(Basis.from_euler(Vector3(0.3, -0.7, 0.2)) * Basis.from_scale(Vector3.ONE * 1.7), Vector3(-4.0, 1.0, 7.0))
	var moved_evaluator := _hinge_evaluator(moved_origin * world)
	var moved_previous: Transform3D = moved_evaluator.call(PackedFloat64Array([0.0])).weapon_frame
	var moved_destination: Transform3D = moved_evaluator.call(PackedFloat64Array([0.4])).weapon_frame
	var moved_target := moved_previous
	moved_target.origin = moved_destination * TASK_POINT - moved_previous.basis * TASK_POINT
	var moved := Allocator.solve(_input("pommel", moved_previous, moved_target), moved_evaluator, {"max_translation_step": 1.0})
	_check(bool(moved.get("valid", false)) and absf(float(moved.accepted_q[0]) - float(result.accepted_q[0])) < 0.0003, "root_transform_preserves_hinge_solution", _summary(moved))
	_check(((moved.get("accepted_weapon", moved_previous) as Transform3D) * TASK_POINT).distance_to(moved_destination * TASK_POINT) <= 0.00005, "scaled_root_pommel_reaches_same_local_target")
	var tip_request := _input("tip", previous, destination)
	var tip := Allocator.solve(tip_request, evaluator)
	_check(bool(tip.get("valid", false)) and bool(tip.get("orientation_constrained", false)) and absf(float(tip.accepted_q[0]) - 0.4) < 0.001, "tip_keeps_existing_orientation_task", _summary(tip))
	var anchor := Vector3(1.0, -2.0, 3.0)
	var roll_evaluator := func(q: PackedFloat64Array) -> Dictionary:
		var basis := Basis(Vector3.BACK, q[0])
		return {"valid": true, "weapon_frame": Transform3D(basis, anchor - basis * GRIP_POINT), "payload": {}}
	var roll_previous: Transform3D = roll_evaluator.call(PackedFloat64Array([0.0])).weapon_frame
	var roll_destination: Transform3D = roll_evaluator.call(PackedFloat64Array([0.3])).weapon_frame
	var roll_request := _input("roll", roll_previous, roll_destination)
	roll_request["contact_anchor"] = anchor
	var roll := Allocator.solve(roll_request, roll_evaluator)
	_check(bool(roll.get("valid", false)) and bool(roll.get("orientation_constrained", false)), "roll_keeps_existing_orientation_task", _summary(roll))
	_check(((roll.get("accepted_weapon", roll_previous) as Transform3D) * GRIP_POINT).distance_to(anchor) <= 0.00005, "roll_still_pins_grip_station_not_pommel")
	_trailing_preference_checks()
	_roll_ownership_checks()
	var failed := false
	for check: Dictionary in checks:
		failed = failed or not check.passed
	print(JSON.stringify({"checks": checks, "records": records, "passed": not failed}))
	quit(1 if failed else 0)

func _hinge_evaluator(origin: Transform3D) -> Callable:
	return func(q: PackedFloat64Array) -> Dictionary:
		return {"valid": true, "weapon_frame": origin * Transform3D(Basis(Vector3.BACK, q[0]), Vector3.ZERO), "payload": {}}

func _trailing_preference_checks() -> void:
	var pommel := Vector3(0.0, -0.25, 0.0)
	var tip := Vector3(0.0, 0.75, 0.0)
	var origin := Vector3(2.0, -1.0, 3.0)
	var evaluator := func(q: PackedFloat64Array) -> Dictionary:
		return {"valid": true, "weapon_frame": Transform3D(Basis(Vector3.BACK, q[2]), origin + Vector3(q[0], q[1], 0.0)), "payload": {}}
	var previous: Transform3D = evaluator.call(PackedFloat64Array([0.0, 0.0, 0.0])).weapon_frame
	var target := previous
	target.origin += Vector3(0.1, 0.0, 0.0)
	var request := {"q": PackedFloat64Array([0.0, 0.0, 0.0]), "lower": PackedFloat64Array([-1.0, -1.0, -0.8]),
		"upper": PackedFloat64Array([1.0, 1.0, 0.8]), "joint_groups": PackedStringArray(["elbow", "elbow", "shoulder_roll"]),
		"origin_id": &"test_machine_root", "mode": "pommel", "previous_weapon": previous, "target_weapon": target,
		"contact_local": GRIP_POINT, "task_point_local": pommel, "trailing_tip_local": tip}
	var settings := {"max_translation_step": 1.0, "posture_group_costs_by_mode": {"pommel": {"elbow": 1.0, "shoulder_roll": 1.0}}}
	var disabled_settings := settings.duplicate(true)
	disabled_settings["pommel_tip_trailing_weight"] = 0.0
	var disabled := Allocator.solve(request, evaluator, disabled_settings)
	var enabled := Allocator.solve(request, evaluator, settings)
	var disabled_frame: Transform3D = disabled.get("accepted_weapon", previous)
	var enabled_frame: Transform3D = enabled.get("accepted_weapon", previous)
	var disabled_tip_travel := (disabled_frame * tip).distance_to(previous * tip)
	var enabled_tip_travel := (enabled_frame * tip).distance_to(previous * tip)
	_check(bool(enabled.get("valid", false)) and (enabled_frame * pommel).distance_to(target * pommel) <= 0.00005, "trailing_keeps_pommel_primary_target")
	_check(bool(disabled.get("valid", false)) and enabled_tip_travel + 0.001 < disabled_tip_travel, "trailing_reduces_tip_displacement_on_identical_fixture", {"enabled_tip_m": enabled_tip_travel, "disabled_tip_m": disabled_tip_travel})
	_check(absf((enabled_frame * tip).distance_to(enabled_frame * pommel) - tip.distance_to(pommel)) < 0.000001, "trailing_preserves_fixed_weapon_length")
	var omitted := request.duplicate(true)
	omitted.erase("trailing_tip_local")
	var without_field := Allocator.solve(omitted, evaluator, settings)
	_check((without_field.get("accepted_weapon", previous) as Transform3D).is_equal_approx(disabled_frame), "zero_weight_matches_absent_trailing_preference")
	# Rotation is mechanically unavailable in this fixture. The old Tip cannot
	# stay still; the preference must yield and permit the full Pommel movement.
	var impossible_tip := request.duplicate(true)
	impossible_tip.lower[2] = 0.0
	impossible_tip.upper[2] = 0.0
	var yielded := Allocator.solve(impossible_tip, evaluator, settings)
	var yielded_frame: Transform3D = yielded.get("accepted_weapon", previous)
	_check(bool(yielded.get("valid", false)) and (yielded_frame * pommel).distance_to(target * pommel) <= 0.00005, "unreachable_tip_preference_does_not_freeze_pommel")
	_check((yielded_frame * tip).distance_to(previous * tip) > 0.09, "unreachable_trailing_is_reported_as_real_tip_motion")
	records["trailing"] = {"enabled": _summary(enabled), "disabled": _summary(disabled), "yielded": _summary(yielded),
		"enabled_tip_travel_m": enabled_tip_travel, "disabled_tip_travel_m": disabled_tip_travel}

func _roll_ownership_checks() -> void:
	# Two distinct existing roll coordinates; holding the forearm coordinate
	# must not lock the upper-arm one. Tip retains forearm authority separately.
	var evaluator := func(q: PackedFloat64Array) -> Dictionary:
		return {"valid": true, "weapon_frame": Transform3D(Basis(Vector3.BACK, q[0] + q[1]), Vector3(2.0, 1.0, 0.0)), "payload": {}}
	var previous: Transform3D = evaluator.call(PackedFloat64Array([0.0, 0.0])).weapon_frame
	var destination: Transform3D = evaluator.call(PackedFloat64Array([0.3, 0.0])).weapon_frame
	var target := previous
	target.origin = destination * TASK_POINT - previous.basis * TASK_POINT
	var request := {"q": PackedFloat64Array([0.0, 0.0]), "lower": PackedFloat64Array([-1.0, 0.0]),
		"upper": PackedFloat64Array([1.0, 0.0]), "joint_groups": PackedStringArray(["shoulder_roll", "forearm"]),
		"origin_id": &"test_machine_root", "mode": "pommel", "previous_weapon": previous, "target_weapon": target,
		"contact_local": GRIP_POINT, "task_point_local": TASK_POINT, "trailing_tip_local": Vector3(0.4, 0.8, -0.05)}
	var upper_roll := Allocator.solve(request, evaluator, {"max_translation_step": 1.0})
	_check(bool(upper_roll.get("valid", false)) and float(upper_roll.accepted_q[0]) > 0.29 and float(upper_roll.accepted_q[1]) == 0.0, "held_forearm_still_allows_significant_upperarm_roll", _summary(upper_roll))
	request.mode = "tip"
	request.lower = PackedFloat64Array([0.0, -1.0])
	request.upper = PackedFloat64Array([0.0, 1.0])
	request.target_weapon = destination
	var tip_roll := Allocator.solve(request, evaluator)
	_check(bool(tip_roll.get("valid", false)) and float(tip_roll.accepted_q[1]) > 0.29 and float(tip_roll.accepted_q[0]) == 0.0, "tip_still_uses_significant_forearm_roll", _summary(tip_roll))

func _input(mode: String, previous: Transform3D, target: Transform3D) -> Dictionary:
	return {"q": PackedFloat64Array([0.0]), "lower": PackedFloat64Array([-1.0]), "upper": PackedFloat64Array([1.0]),
		"joint_groups": PackedStringArray(["elbow"]), "origin_id": &"test_machine_root", "mode": mode,
		"previous_weapon": previous, "target_weapon": target, "contact_local": GRIP_POINT, "task_point_local": TASK_POINT}

func _summary(result: Dictionary) -> Dictionary:
	return {"status": result.get("status"), "reason": result.get("reason"), "q": Array(result.get("accepted_q", [])),
		"task_scale": result.get("task_scale"), "orientation_constrained": result.get("orientation_constrained"),
		"remaining_task_error": result.get("remaining_task_error", {})}

func _check(passed: bool, label: String, detail: Variant = null) -> void:
	checks.append({"passed": passed, "label": label, "detail": detail if detail is Dictionary else {}})
