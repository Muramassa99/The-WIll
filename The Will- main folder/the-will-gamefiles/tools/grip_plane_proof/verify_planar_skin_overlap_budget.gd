extends SceneTree

const Kernel = preload("res://tools/grip_plane_proof/planar_skin_overlap_budget.gd")
const PLANE := &"OverlapBudgetTestPlane"
const SOURCE := &"SyntheticObjectContour"

var assertions := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var kernel := Kernel.new()
	var polygon := PackedVector2Array([Vector2(0, 0), Vector2(0.01, 0), Vector2(0.01, 0.01), Vector2(0, 0.01)])
	var target: Dictionary = kernel.prepare_target(polygon, PLANE, SOURCE, true)
	_check(bool(target.get("valid", false)), "complete square target accepted")
	if not bool(target.get("valid", false)):
		_finish()
		return
	var crossing := _segment(Vector2(-0.001, 0.005), Vector2(0.011, 0.005), 0.0005)
	var crossed: Dictionary = kernel.evaluate_segments([crossing], target, PLANE)
	var deep: Dictionary = crossed.segments[0]
	_check(crossed.cap_status == &"exceeds", "middle of long segment exceeds cap although both endpoints outside")
	_check(float(deep.max_inward_depth_lower_m) > 0.0049, "deep interior witness exceeds endpoint-only result")
	_check(float(deep.max_inward_depth_lower_m) <= 0.00500001 and float(deep.max_inward_depth_upper_m) >= 0.00499999, "maximum depth is enclosed by returned bounds")
	_check(not deep.depth_lower_bound_witness.is_empty() and absf(float(deep.depth_lower_bound_witness.skin_segment_t) - 0.5) < 0.00001, "depth witness identifies the interior of the skin segment")
	_check(deep.depth_lower_bound_witness.origin_id == PLANE and int(deep.depth_lower_bound_witness.target_edge_index) >= 0, "depth witness retains origin and target edge")
	var shallow := _segment(Vector2(-0.001, 0.0003), Vector2(0.011, 0.0003), 0.0005)
	var clear: Dictionary = kernel.evaluate_segments([shallow], target, PLANE)
	_check(clear.cap_status == &"within", "0.30 mm inward depth fits supplied 0.50 mm cap")
	_check(float(clear.segments[0].max_inward_depth_upper_m) <= 0.0005, "pass is certified by upper bound, not just sampled depth")
	_check(float(clear.segments[0].max_inward_depth_lower_m) <= 0.00030001 and float(clear.segments[0].max_inward_depth_upper_m) >= 0.00029999, "shallow true maximum enclosed")
	var excessive := _segment(Vector2(-0.001, 0.0007), Vector2(0.011, 0.0007), 0.0005)
	_check(kernel.evaluate_segments([excessive], target, PLANE).cap_status == &"exceeds", "0.70 mm inward depth fails same supplied cap")
	var early: Dictionary = kernel.evaluate_segments([excessive], target, PLANE)
	var refined: Dictionary = kernel.evaluate_segments([excessive], target, PLANE, {"refine_depth_after_cap": true})
	_check(not early.refine_depth_after_cap and not early.segments[0].refine_depth_after_cap and refined.refine_depth_after_cap and refined.segments[0].refine_depth_after_cap, "optional depth refinement is reported and defaults off")
	_check(refined.cap_status == early.cap_status and float(refined.segments[0].geometric_bound_width_m) < float(early.segments[0].geometric_bound_width_m), "post-cap refinement narrows depth bounds without changing cap semantics")
	_check(float(refined.segments[0].max_inward_depth_lower_m) >= float(early.segments[0].max_inward_depth_lower_m) and float(refined.segments[0].max_inward_depth_upper_m) <= float(early.segments[0].max_inward_depth_upper_m), "refinement tightens rather than replaces existing depth enclosure")
	_check(int(refined.depth_evaluations) > int(early.depth_evaluations) and int(refined.depth_evaluations) <= 256, "optional refinement uses extra evaluations within the original budget")
	var refine_limited: Dictionary = kernel.evaluate_segments([_segment(Vector2(0.001,0.0007), Vector2(0.009,0.0007), 0.0005)], target, PLANE, {"refine_depth_after_cap": true, "max_evaluations_per_segment": 3})
	_check(refine_limited.cap_status == &"exceeds" and refine_limited.segments[0].budget_exhausted and int(refine_limited.depth_evaluations) <= 3, "exhausted optional refinement preserves a previously certified exceeded cap")
	var different_cap := excessive.duplicate(true)
	different_cap.max_inward_depth_m = 0.001
	_check(kernel.evaluate_segments([different_cap], target, PLANE).cap_status == &"within", "caller owns per-segment cap; geometry kernel has no anatomical constant")
	var mixed: Dictionary = kernel.evaluate_segments([shallow, excessive], target, PLANE)
	_check(mixed.cap_status == &"exceeds" and mixed.segments[0].cap_status == &"within" and mixed.segments[1].cap_status == &"exceeds", "mixed caps remain attributable to individual source segments")
	var reversed_polygon := polygon.duplicate()
	reversed_polygon.reverse()
	var reversed: Dictionary = kernel.prepare_target(reversed_polygon, PLANE, SOURCE, true)
	var reverse_result: Dictionary = kernel.evaluate_segments([shallow], reversed, PLANE)
	_check(reverse_result.cap_status == clear.cap_status and absf(float(reverse_result.segments[0].max_inward_depth_upper_m) - float(clear.segments[0].max_inward_depth_upper_m)) < 1.0e-12, "polygon winding does not change depth or cap decision")
	var explicit_closed := polygon.duplicate()
	explicit_closed.append(polygon[0])
	_check(kernel.prepare_target(explicit_closed, PLANE, SOURCE, true).valid, "explicit repeated closing point accepted without zero-length edge")
	var concave_polygon := PackedVector2Array([Vector2(0,0), Vector2(0.02,0), Vector2(0.02,0.01), Vector2(0.01,0.01), Vector2(0.01,0.02), Vector2(0,0.02)])
	var concave: Dictionary = kernel.prepare_target(concave_polygon, PLANE, SOURCE, true)
	_check(concave.valid, "simple concave polygon retained")
	var notch := _segment(Vector2(0.012,0.015), Vector2(0.018,0.015), 0.0005)
	var notch_result: Dictionary = kernel.evaluate_segments([notch], concave, PLANE)
	_check(notch_result.cap_status == &"within" and float(notch_result.segments[0].max_sampled_inward_depth_m) == 0.0, "empty concavity is not replaced by a convex hull")
	var across_notch := _segment(Vector2(0.005,0.015), Vector2(0.015,0.005), 0.0005)
	_check(kernel.evaluate_segments([across_notch], concave, PLANE).cap_status == &"exceeds", "reentrant boundary crossing remains a contact obstacle")
	var near_edge := _segment(Vector2(0.002,0.012), Vector2(0.008,0.012), 0.0005)
	var nearest: Dictionary = kernel.evaluate_segments([near_edge], target, PLANE).segments[0].contact
	_check(absf(float(nearest.distance_m) - 0.002) < 0.0000001, "nearest gap reports separation from actual target")
	_check(not nearest.tangent_ambiguous and (nearest.target_edge_tangent as Vector2).length() > 0.999, "edge interior exposes a target tangent")
	var zero_cap_exterior := near_edge.duplicate(true)
	zero_cap_exterior.max_inward_depth_m = 0.0
	var zero_cap_report: Dictionary = kernel.evaluate_segments([zero_cap_exterior], target, PLANE, {"refine_depth_after_cap": true})
	_check(zero_cap_report.cap_status == &"unresolved" and float(zero_cap_report.segments[0].max_sampled_inward_depth_m) == 0.0 and float(zero_cap_report.segments[0].max_inward_depth_upper_m) > 0.0, "zero-cap exterior remains unresolved under a positive numeric guard")
	var near_corner := _segment(Vector2(0.012,0.012), Vector2(0.014,0.014), 0.0005)
	var corner: Dictionary = kernel.evaluate_segments([near_corner], target, PLANE).segments[0].contact
	_check(corner.corner_ambiguous and corner.tangent_ambiguous and corner.tied_target_edge_indices.size() == 2, "corner does not claim a unique tangent")
	var boundary := _segment(Vector2(0.002,0.01), Vector2(0.008,0.01), 0.000001)
	_check(kernel.evaluate_segments([boundary], target, PLANE).cap_status == &"within", "coincident boundary segment does not invent positive geometric depth")
	var limited := _segment(Vector2(0.001,0.002), Vector2(0.009,0.002), 0.0021)
	var unresolved: Dictionary = kernel.evaluate_segments([limited], target, PLANE, {"max_evaluations_per_segment": 3})
	_check(unresolved.cap_status == &"unresolved" and unresolved.segments[0].budget_exhausted, "small work budget leaves undecided cap unresolved")
	_check(float(unresolved.segments[0].max_inward_depth_lower_m) < 0.0021 and float(unresolved.segments[0].max_inward_depth_upper_m) > 0.0021, "unresolved bounds straddle cap")
	_check(int(unresolved.depth_evaluations) <= 3, "evaluation budget is enforced")
	var near_cap := _segment(Vector2(0.003,0.0005), Vector2(0.007,0.0005), 0.0005)
	var uncertain_numeric: Dictionary = kernel.evaluate_segments([near_cap], target, PLANE, {"numeric_epsilon_m": 0.000001, "max_evaluations_per_segment": 256})
	_check(uncertain_numeric.cap_status == &"unresolved", "numeric guard prevents certifying a depth exactly at cap")
	_check(float(uncertain_numeric.segments[0].numeric_epsilon_m) == 0.000001 and float(uncertain_numeric.segments[0].depth_bound_width_m) >= float(uncertain_numeric.segments[0].geometric_bound_width_m), "numeric guard and geometric uncertainty reported separately")
	var no_origin := shallow.duplicate(true)
	no_origin.erase("origin_id")
	_check(not kernel.evaluate_segments([no_origin], target, PLANE).valid, "missing skin origin rejected")
	var no_source := shallow.duplicate(true)
	no_source.erase("source_id")
	_check(not kernel.evaluate_segments([no_source], target, PLANE).valid, "missing skin source rejected")
	_check(not kernel.evaluate_segments([shallow], target, &"OtherPlane").valid, "mismatched metric plane rejected")
	_check(not kernel.prepare_target(polygon, StringName(), SOURCE, true).valid, "missing target origin rejected")
	_check(not kernel.prepare_target(polygon, PLANE, StringName(), true).valid, "missing target source rejected")
	_check(not kernel.prepare_target(polygon, PLANE, SOURCE, false).valid, "incomplete target never silently closed")
	var bowtie := PackedVector2Array([Vector2(0,0),Vector2(0.01,0.01),Vector2(0,0.01),Vector2(0.01,0)])
	_check(not kernel.prepare_target(bowtie, PLANE, SOURCE, true).valid, "self-intersecting polygon rejected")
	var broken := _segment(Vector2.ZERO, Vector2.ZERO, 0.0005)
	_check(not kernel.evaluate_segments([broken], target, PLANE).valid, "zero-length skin segment rejected explicitly")
	var saved_inputs := var_to_bytes([polygon, target, shallow])
	var first: Dictionary = kernel.evaluate_segments([shallow], target, PLANE)
	var second: Dictionary = kernel.evaluate_segments([shallow], target, PLANE)
	_check(var_to_bytes(first) == var_to_bytes(second), "identical input produces identical decisions bounds witnesses and counts")
	_check(saved_inputs == var_to_bytes([polygon, target, shallow]), "kernel leaves source arrays and dictionaries immutable")
	_check(not first.actual_3d_grip_verified and not first.whole_skin_clearance_verified, "planar segment report makes no whole-skin or 3D acceptance claim")
	_check_pruning_parity(kernel)
	_finish()


func _check_pruning_parity(kernel: Kernel) -> void:
	# Two reentrant corners, separated lobes and nonbinary decimal coordinates.
	# Preserve all eight edges; this tests query pruning, not contour reduction.
	var polygon := PackedVector2Array([Vector2(0,0), Vector2(0.03,0), Vector2(0.03,0.03),
		Vector2(0.02,0.03), Vector2(0.02,0.012), Vector2(0.01,0.012),
		Vector2(0.01,0.03), Vector2(0,0.03)])
	var offset := Vector2(0.02731, -0.01977)
	for index: int in polygon.size():
		polygon[index] += offset
	var target: Dictionary = kernel.prepare_target(polygon, PLANE, &"ConcavePruningOracle", true)
	_check(target.get("valid", false), "concave pruning reference polygon is complete")
	if not target.get("valid", false):
		return
	var cases: Array = [
		[&"exterior", Vector2(-0.01,-0.004), Vector2(0.035,-0.004)],
		[&"crossing_both_lobes", Vector2(-0.005,0.02), Vector2(0.035,0.02)],
		[&"crossing_base", Vector2(-0.005,0.006), Vector2(0.035,0.006)],
		[&"empty_concavity", Vector2(0.014,0.025), Vector2(0.016,0.029)],
		[&"near_reentrant_corner", Vector2(0.011,0.013), Vector2(0.014,0.016)],
		[&"near_outer_corner", Vector2(0.031,0.031), Vector2(0.034,0.034)],
		[&"near_numeric_boundary", Vector2(0.030000003,0.025), Vector2(0.030000003,0.026)]
	]
	var total_prunes := 0
	for item: Array in cases:
		var segment := _segment(item[1] + offset, item[2] + offset, 0.0005)
		segment.source_id = item[0]
		var saved := var_to_bytes([target, segment])
		var config := {"refine_depth_after_cap": true, "max_evaluations_per_segment": 32}
		var pruned: Dictionary = kernel.evaluate_segments([segment], target, PLANE, config)
		config["use_boundary_pruning"] = false
		var exhaustive: Dictionary = kernel.evaluate_segments([segment], target, PLANE, config)
		var label := String(item[0])
		_check(pruned.get("valid", false) and exhaustive.get("valid", false), label + ": both query modes valid")
		if not pruned.get("valid", false) or not exhaustive.get("valid", false):
			continue
		_check(_geometry_bytes(pruned) == _geometry_bytes(exhaustive), label + ": exhaustive parity includes depth bounds, caps, witnesses and corner ties")
		_check(int(pruned.work_counts.intersection_tests) == polygon.size() and int(pruned.work_counts.contact_intersection_reuses) == int(pruned.work_counts.contact_nearest_tests), label + ": all depth intersections computed once and reused for contact")
		_check(int(pruned.work_counts.contact_nearest_tests) + int(pruned.work_counts.contact_aabb_prunes) == polygon.size() and int(exhaustive.work_counts.contact_nearest_tests) == polygon.size() and int(exhaustive.work_counts.contact_aabb_prunes) == 0, label + ": work counters account for every target edge in both modes")
		_check(saved == var_to_bytes([target, segment]), label + ": both modes preserve prepared target and skin input")
		total_prunes += int(pruned.work_counts.contact_aabb_prunes)
	_check(total_prunes > 0, "pruning actually avoids nearest-edge calculations in nontrivial cases")


func _geometry_bytes(report: Dictionary) -> PackedByteArray:
	var geometry := report.duplicate(true)
	geometry.erase("work_counts")
	geometry.erase("use_boundary_pruning")
	for segment: Dictionary in geometry.segments:
		segment.erase("work_counts")
		segment.erase("use_boundary_pruning")
	return var_to_bytes(geometry)


func _segment(a: Vector2, b: Vector2, cap: float) -> Dictionary:
	return {"a": a, "b": b, "origin_id": PLANE, "source_id": &"SyntheticSkinSegment", "max_inward_depth_m": cap}


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
		push_error(label)


func _finish() -> void:
	print("PLANAR_SKIN_OVERLAP_BUDGET_RESULT=" + JSON.stringify({"valid": failures.is_empty(),
		"assertions": assertions, "failures": failures, "actual_3d_grip_verified": false}))
	quit(0 if failures.is_empty() else 1)
