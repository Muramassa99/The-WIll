extends SceneTree

const Kernel = preload("res://tools/grip_plane_proof/planar_skin_overlap_budget.gd")
const PLANE := &"OrderedEnvelopeVerificationPlane"
const SOURCE := &"OrderedEnvelopeVerificationContour"

var assertions := 0
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var kernel := Kernel.new()
	var square := PackedVector2Array([Vector2(0,0), Vector2(0.01,0), Vector2(0.01,0.01), Vector2(0,0.01)])
	var tiny := PackedVector2Array([Vector2(0,0), Vector2(0.0000001,0), Vector2(0.01,0), Vector2(0.01,0.01), Vector2(0,0.01)])
	var saved_tiny := var_to_bytes(tiny)
	var tiny_target: Dictionary = kernel.prepare_ordered_target(tiny, PLANE, SOURCE, true)
	_check(tiny_target.get("valid", false), "valid ordered 0.1 micrometer edge accepted")
	_check(not kernel.prepare_target(tiny, PLANE, SOURCE, true).get("valid", false), "unordered mesh-soup validator keeps its existing strict topology behavior")
	if tiny_target.get("valid", false):
		_check(tiny_target.polygon == tiny and tiny_target.edges.size() == tiny.size(), "short edge and source order preserved without simplification")
		var skin := _segment(Vector2(-0.001,0.0003), Vector2(0.011,0.0003), 0.0005)
		var measured: Dictionary = kernel.evaluate_segments([skin], tiny_target, PLANE, {"refine_depth_after_cap": true})
		_check(measured.get("valid", false) and measured.cap_status == &"within", "preserved tiny edge supports the ordinary bounded depth query")
	_check(saved_tiny == var_to_bytes(tiny), "ordered preparation leaves input polygon unchanged")
	_check(not kernel.prepare_ordered_target(square, StringName(), SOURCE, true).valid, "missing plane origin rejected")
	_check(not kernel.prepare_ordered_target(square, PLANE, StringName(), true).valid, "missing source rejected")
	_check(not kernel.prepare_ordered_target(square, PLANE, SOURCE, false).valid, "incomplete input is never implicitly closed")
	var zero := square.duplicate()
	zero.insert(1, zero[0])
	_check(not kernel.prepare_ordered_target(zero, PLANE, SOURCE, true).valid, "zero-length interior edge rejected")
	var closed := square.duplicate()
	closed.append(closed[0])
	_check(kernel.prepare_ordered_target(closed, PLANE, SOURCE, true).get("polygon") == square, "one explicit closing endpoint is accepted consistently with existing preparation")
	var nonfinite := square.duplicate()
	nonfinite[1] = Vector2(INF,0)
	_check(not kernel.prepare_ordered_target(nonfinite, PLANE, SOURCE, true).valid, "nonfinite vertex rejected")
	var crossing := PackedVector2Array([Vector2(0,0),Vector2(0.03,0.03),Vector2(0,0.03),Vector2(0.02,0)])
	var crossed: Dictionary = kernel.prepare_ordered_target(crossing, PLANE, SOURCE, true)
	_check(not crossed.valid and crossed.reason == "ordered_target_crossing_or_overlapping_edges", "nonzero-area crossing rejected by intersection test")
	var backtrack := PackedVector2Array([Vector2(0,0),Vector2(0.02,0),Vector2(0.01,0),Vector2(0.01,0.01),Vector2(0,0.01)])
	var overlapping: Dictionary = kernel.prepare_ordered_target(backtrack, PLANE, SOURCE, true)
	_check(not overlapping.valid and overlapping.reason == "ordered_target_crossing_or_overlapping_edges", "adjacent collinear backtrack rejected")
	var touching := PackedVector2Array([Vector2(0,0),Vector2(0.02,0),Vector2(0.01,0.01),Vector2(0.02,0.02),Vector2(0,0.02),Vector2(0.01,0.01)])
	_check(not kernel.prepare_ordered_target(touching, PLANE, SOURCE, true).valid, "nonadjacent point touch rejected")
	var flat := PackedVector2Array([Vector2(0,0),Vector2(0.01,0),Vector2(0.02,0)])
	_check(not kernel.prepare_ordered_target(flat, PLANE, SOURCE, true).valid, "zero-area polygon rejected")
	_check(not kernel.prepare_ordered_target(PackedVector2Array([Vector2(0,0),Vector2(0.01,0)]), PLANE, SOURCE, true).valid, "too few vertices rejected")
	var concave := PackedVector2Array([Vector2(0,0),Vector2(0.02,0),Vector2(0.02,0.01),Vector2(0.01,0.01),Vector2(0.01,0.02),Vector2(0,0.02)])
	for polygon: PackedVector2Array in [square, concave]:
		for reverse: bool in [false, true]:
			var points := polygon.duplicate()
			if reverse:
				points.reverse()
			_compare_paths(kernel, points)
	_finish()


func _compare_paths(kernel: Kernel, polygon: PackedVector2Array) -> void:
	var old: Dictionary = kernel.prepare_target(polygon, PLANE, SOURCE, true)
	var ordered: Dictionary = kernel.prepare_ordered_target(polygon, PLANE, SOURCE, true)
	_check(old.get("valid", false) and ordered.get("valid", false), "regular reference polygon passes both validation paths")
	if not old.get("valid", false) or not ordered.get("valid", false):
		return
	_check(var_to_bytes(old) == var_to_bytes(ordered), "regular polygon produces identical prepared target packets")
	var examples: Array = [
		_segment(Vector2(-0.001,0.005),Vector2(0.021,0.005),0.0005),
		_segment(Vector2(-0.001,0.0003),Vector2(0.021,0.0003),0.0005),
		_segment(Vector2(0.012,0.015),Vector2(0.018,0.015),0.0005),
		_segment(Vector2(0.002,-0.002),Vector2(0.008,-0.002),0.0005),
		_segment(Vector2(-0.003,-0.003),Vector2(-0.001,-0.001),0.0005)]
	var config := {"refine_depth_after_cap": true, "max_evaluations_per_segment": 96, "depth_bound_tolerance_m": 0.00001}
	var previous: Dictionary = kernel.evaluate_segments(examples, old, PLANE, config)
	var current: Dictionary = kernel.evaluate_segments(examples, ordered, PLANE, config)
	_check(previous.get("valid", false) and current.get("valid", false), "regular polygon queries valid through both preparation paths")
	_check(var_to_bytes(previous) == var_to_bytes(current), "contact points, tangents, signed depth bounds, cap decisions and work counts match exactly")


func _segment(a: Vector2, b: Vector2, cap: float) -> Dictionary:
	return {"a": a, "b": b, "origin_id": PLANE, "source_id": &"OrderedEnvelopeVerificationSkin", "max_inward_depth_m": cap}


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
		push_error(label)


func _finish() -> void:
	print("ORDERED_ENVELOPE_TARGET_RESULT=" + JSON.stringify({"valid": failures.is_empty(), "assertions": assertions,
		"failures": failures, "actual_3d_grip_verified": false}))
	quit(0 if failures.is_empty() else 1)
