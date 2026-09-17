extends SceneTree

const Solver = preload("res://tools/grip_plane_proof/planar_digit_contact_solver.gd")
var failures := 0

func _init() -> void:
	var solver := Solver.new()
	var hand := {"lengths_m": [0.08, 0.06, 0.08], "radii_m": [0.01, 0.01, 0.01], "zero_angles_rad": [0.0, 0.0, 0.0], "min_angles_rad": [0.0, 0.0, 0.0], "max_angles_rad": [PI, PI, PI], "closure_signs": [1.0, 1.0, 1.0]}
	var rectangle := _slice(PackedVector2Array([Vector2(0.015, 0.01), Vector2(0.07, 0.01), Vector2(0.07, 0.05), Vector2(0.015, 0.05), Vector2(0.015, 0.01)]))
	var before := var_to_bytes([hand, rectangle])
	var config := {"allowed_penetration_m": [0.0, 0.0, 0.0], "contact_tolerance_m": 0.00008, "max_pose_evaluations": 1700}
	var result := solver.solve(hand, rectangle, config)
	print("rectangle timing_ms=%.3f evaluations=%d segments=%d section_query_cache=%s" % [float(result.timing_ms), int(result.evaluations), rectangle.segments.size(), str(result.section_query_cache)])
	_check(result.get("status") == &"three_section_contact" and bool(result.get("safe", false)), "rectangle reaches three safe contacts")
	_check(var_to_bytes([hand, rectangle]) == before, "solver leaves input measurements and slice unchanged")
	_check(int(result.get("evaluations", 9999)) <= 1700, "pose evaluation budget is bounded")
	var circle := PackedVector2Array()
	for i in range(65):
		circle.append(Vector2(0.05, 0.03) + Vector2(cos(TAU * float(i) / 64.0), sin(TAU * float(i) / 64.0)) * 0.02)
	var circle_slice := _slice(circle)
	result = solver.solve(hand, circle_slice, config)
	print("circle cached timing_ms=%.3f evaluations=%d segments=%d section_query_cache=%s" % [float(result.timing_ms), int(result.evaluations), circle_slice.segments.size(), str(result.section_query_cache)])
	_check(result.get("status") == &"three_section_contact" and bool(result.get("safe", false)), "round profile reaches three safe contacts")
	var baseline_config: Dictionary = config.duplicate(true)
	baseline_config["disable_section_query_cache"] = true
	var baseline := solver.solve(hand, circle_slice, baseline_config)
	print("circle uncached timing_ms=%.3f evaluations=%d segments=%d section_query_cache=%s" % [float(baseline.timing_ms), int(baseline.evaluations), circle_slice.segments.size(), str(baseline.section_query_cache)])
	var selected_cached: Dictionary = result.duplicate(true)
	var selected_baseline: Dictionary = baseline.duplicate(true)
	for diagnostic_key: String in ["timing_ms", "section_query_cache"]:
		selected_cached.erase(diagnostic_key)
		selected_baseline.erase(diagnostic_key)
	_check(var_to_bytes(selected_cached) == var_to_bytes(selected_baseline), "cache preserves the entire selected result, including exact pose, measurements, score, status and evaluation count")
	_check(int(result.section_query_cache.hits) > 0 and int(result.section_query_cache.hits) + int(result.section_query_cache.misses) == int(result.evaluations) * 3, "cached query counts account for every section of every candidate visit")
	_check(int(baseline.section_query_cache.hits) == 0 and int(baseline.section_query_cache.misses) == int(baseline.evaluations) * 3, "disabled cache measures every section without hits")
	var distant := _slice(PackedVector2Array([Vector2(1, 1), Vector2(2, 1), Vector2(2, 2), Vector2(1, 2), Vector2(1, 1)]))
	result = solver.solve(hand, distant, config)
	_check(result.get("status") == &"unreachable", "out-of-reach profile is reported unreachable")
	_check(result.has("timing_ms") and float(result.timing_ms) >= 0.0, "early reach rejection includes timing")
	var concave := _slice(PackedVector2Array([Vector2(0.04, 0.01), Vector2(0.08, 0.01), Vector2(0.08, 0.09), Vector2(0.06, 0.09), Vector2(0.06, 0.03), Vector2(0.04, 0.03), Vector2(0.04, 0.01)]))
	var section := solver.measure_section(Vector2(0.035, 0.015), Vector2(0.035, 0.025), 0.006, concave, 0.0, 0.00008)
	_check(not bool(section.safe) and absf(float(section.penetration_m) - 0.001) < 0.000001, "concave profile edge interior, not only vertices, determines collision")
	var open := {"origin_id": &"SyntheticDigitPlane", "classification_incomplete": true, "segments": [[Vector2(-1, -1), Vector2(1, -1)], [Vector2(1, -1), Vector2(1, 1)]], "contours": [PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1)])]}
	section = solver.measure_section(Vector2(0.2, 0), Vector2(0.3, 0), 0.01, open, 0.0, 0.00008)
	_check(bool(section["2d_boundary_clearance"]) and not bool(section.inside) and not bool(section.safe), "cropped open chain gives only provisional clearance without an artificial cap")
	var local_open := {"origin_id": &"SyntheticDigitPlane", "classification_incomplete": true, "segments": [[Vector2(-0.3, 0.02), Vector2(0.3, 0.02)]], "contours": []}
	var one_pose_config: Dictionary = config.duplicate(true)
	one_pose_config["max_pose_evaluations"] = 1
	result = solver.solve(hand, local_open, one_pose_config)
	_check(bool(result["2d_boundary_clearance"]) and not bool(result.safe), "incomplete clear slice cannot publish certified safe")
	_check(result.status == &"provisional_boundary_candidate" and result.classification_incomplete and result.requires_3d_validation, "provisional classification is forwarded")
	_check(result.angles_rad == [0.0, 0.0, 0.0] and int(result.evaluations) == 1, "provisional candidate retains angles and unchanged search budget")
	_check(not bool(result.sections[0].safe) and bool(result.sections[0]["2d_boundary_clearance"]), "nested section also withholds certified safety")
	var blocked_open := {"origin_id": &"SyntheticDigitPlane", "classification_incomplete": true, "segments": [[Vector2(-0.3, 0.001), Vector2(0.3, 0.001)]], "contours": []}
	result = solver.solve(hand, blocked_open, config)
	_check(result.status == &"blocked_fixed_origin" and int(result.evaluations) == 0 and result.has("timing_ms"), "incomplete boundary rejection preserves its reason and zero evaluations")
	var incomplete_distant: Dictionary = distant.duplicate(true)
	incomplete_distant["classification_incomplete"] = true
	result = solver.solve(hand, incomplete_distant, config)
	_check(result.status == &"unreachable" and int(result.evaluations) == 0, "incomplete unreachable slice does not claim a spent search budget")
	var retained_hole := _slice(PackedVector2Array([Vector2(-0.04, -0.04), Vector2(0.04, -0.04), Vector2(0.04, 0.04), Vector2(-0.04, 0.04), Vector2(-0.04, -0.04)]))
	result = solver.solve(hand, retained_hole, one_pose_config)
	_check(result.status == &"blocked_fixed_origin" and int(result.evaluations) == 0, "explicit complete contour still classifies the fixed origin")
	retained_hole["classification_incomplete"] = true
	result = solver.solve(hand, retained_hole, one_pose_config)
	_check(result.status != &"blocked_fixed_origin" and int(result.evaluations) == 1 and result.angles_rad.size() == 3, "retained hole without its outer contour cannot falsely reject the fixed origin")
	section = solver.measure_section(Vector2(-0.001, 0), Vector2(0.001, 0), 0.005, retained_hole, 0.0, 0.00008)
	_check(not bool(section.inside) and bool(section["2d_boundary_clearance"]) and not bool(section.safe), "incomplete retained loop supplies real boundary distance without inside parity or certified safety")
	result = solver.solve({}, local_open, config)
	_check(not result.valid and result.status == &"invalid_hand_array" and int(result.evaluations) == 0 and result.has("timing_ms"), "incomplete invalid-input return preserves its reason and timing")
	print("planar_digit_contact_solver failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func _slice(contour: PackedVector2Array) -> Dictionary:
	var segments: Array = []
	for i in range(contour.size() - 1):
		segments.append([contour[i], contour[i + 1]])
	return {"origin_id": &"SyntheticDigitPlane", "classification_incomplete": false, "segments": segments, "contours": [contour]}

func _check(passed: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if passed else "FAIL", label])
	if not passed:
		failures += 1
