extends SceneTree

const QueryScript = preload("res://tools/grip_plane_proof/skin_plane_contact_query.gd")
const PLANE := &"SyntheticDigitPlane"
var _checks: Array[Dictionary] = []


func _initialize() -> void:
	var query = QueryScript.new()
	var target: Dictionary = query.prepare_target(_box(Vector2(-0.5, -0.5), Vector2(0.5, 0.5)), PLANE)
	_check("closed square topology", target.valid and target.topology_complete)
	var separated: Dictionary = query.evaluate(_box(Vector2(-2.0, -0.5), Vector2(-1.0, 0.5)), target, PLANE)
	_check("exact separated gap", separated.valid and absf(float(separated.dynamic.gap_m) - 0.5) < 0.000001)
	_check("nearest point distance agrees", absf((separated.dynamic.skin_point_m as Vector2).distance_to(separated.dynamic.target_point_m) - 0.5) < 0.000001)
	_check("closed separated boundaries certify planar clearance", separated.planar_classification_complete and separated.planar_clearance_verified and not separated.planar_overlap_detected)
	var crossed: Dictionary = query.evaluate(_box(Vector2(0.25, -0.25), Vector2(0.75, 0.25)), target, PLANE)
	_check("proper crossing detects overlap", crossed.dynamic.proper_crossings > 0 and crossed.planar_overlap_detected and not crossed.planar_clearance_verified)
	_check("inside intervals measure nonzero sampled depth", crossed.dynamic.inside_interval_samples > 0 and crossed.dynamic.sampled_inside_depth_m > 0.0)
	var contained: Dictionary = query.evaluate(_box(Vector2(-0.1, -0.1), Vector2(0.1, 0.1)), target, PLANE)
	_check("skin wholly inside target detected without crossings", contained.dynamic.proper_crossings == 0 and contained.dynamic.inside_interval_samples > 0 and contained.planar_overlap_detected)
	var containing: Dictionary = query.evaluate(_box(Vector2(-1.0, -1.0), Vector2(1.0, 1.0)), target, PLANE)
	_check("target wholly inside skin detected", containing.target_inside_skin_interval_samples > 0 and containing.planar_overlap_detected)
	var hollow_edges: Array = _box(Vector2(-2.0, -2.0), Vector2(2.0, 2.0))
	hollow_edges.append_array(_box(Vector2(-1.0, -1.0), Vector2(1.0, 1.0)))
	var hollow: Dictionary = query.prepare_target(hollow_edges, PLANE)
	var in_hole: Dictionary = query.evaluate(_box(Vector2(-0.2, -0.2), Vector2(0.2, 0.2)), hollow, PLANE)
	_check("nested contour parity preserves hole", hollow.topology_complete and in_hole.planar_clearance_verified and not in_hole.planar_overlap_detected)
	var open_edges: Array = _box(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
	open_edges.pop_back()
	var open_target: Dictionary = query.prepare_target(open_edges, PLANE)
	var open_result: Dictionary = query.evaluate(_box(Vector2(-2.0, -0.5), Vector2(-1.0, 0.5)), open_target, PLANE)
	_check("open boundaries never certify clearance", open_target.valid and not open_target.topology_complete and not open_result.planar_classification_complete and not open_result.planar_clearance_verified)
	_check("open boundary still reports exact boundary gap", absf(float(open_result.dynamic.gap_m) - 0.5) < 0.000001)
	var branch_edges: Array = _box(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
	branch_edges.append([Vector2(-0.5, -0.5), Vector2(-0.7, -0.7)])
	_check("branch blocks topology certification", not query.prepare_target(branch_edges, PLANE).topology_complete)
	var bow_tie: Array = _polygon([Vector2(-1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(1.0, -1.0)])
	var crossed_boundary: Dictionary = query.prepare_target(bow_tie, PLANE)
	_check("self crossing closed graph remains invalid for parity", not crossed_boundary.topology_complete and crossed_boundary.topology.self_intersections > 0)
	var duplicate: Array = _box(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
	duplicate.append(duplicate[0])
	_check("duplicate boundary edges block parity", query.prepare_target(duplicate, PLANE).topology.duplicate_edges > 0)
	var coplanar: Array = _box(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
	coplanar[0]["coplanar"] = true
	_check("coplanar triangle edges do not certify a solid slice", not query.prepare_target(coplanar, PLANE).topology_complete)
	var huge_target: Dictionary = query.prepare_target(_box(Vector2(-10.0, -10.0), Vector2(10.0, 10.0)), PLANE)
	var surrounded: Dictionary = query.evaluate(_box(Vector2(-0.2, -0.2), Vector2(0.2, 0.2)), huge_target, PLANE, {"reach_m": 1.0})
	_check("target enclosing disk retains full parity despite no local edge", surrounded.planar_overlap_detected and surrounded.dynamic.inside_interval_samples > 0 and is_inf(float(surrounded.dynamic.gap_m)))
	var both_surround: Dictionary = query.evaluate(_box(Vector2(-5.0, -5.0), Vector2(5.0, 5.0)), huge_target, PLANE, {"reach_m": 1.0})
	_check("both complete solids enclosing disk are not called clear", both_surround.query_center_inside_both and both_surround.planar_overlap_detected and not both_surround.planar_clearance_verified)
	var outside: Dictionary = query.evaluate(_box(Vector2(4.0, 4.0), Vector2(5.0, 5.0)), target, PLANE, {"reach_m": 1.0})
	_check("out of reach skin supplies no scoring edges", outside.dynamic.edges_in_reach == 0 and is_inf(float(outside.dynamic.gap_m)) and outside.planar_clearance_verified)
	var clipped: Dictionary = query.evaluate(_box(Vector2(0.75, -2.0), Vector2(1.25, 2.0)), target, PLANE, {"reach_m": 1.0})
	_check("disk clipping retains originals for classification and does not add caps", clipped.dynamic.edges_in_reach == 1 and clipped.planar_classification_complete and absf(float(clipped.dynamic.gap_m) - 0.25) < 0.000001)
	var fixed_edges: Array = _box(Vector2(0.25, -0.25), Vector2(0.75, 0.25), false)
	var fixed_result: Dictionary = query.evaluate(fixed_edges, target, PLANE)
	_check("fixed overlap is separate from dynamic scoring", fixed_result.fixed_static.proper_crossings > 0 and fixed_result.dynamic.edges_in_reach == 0 and is_inf(float(fixed_result.dynamic.gap_m)))
	var weighted: Array = _box(Vector2(-2.0, -0.5), Vector2(-1.0, 0.5))
	for index: int in weighted.size():
		weighted[index]["bone_ids"] = [&"Bone0", &"Bone1", &"Bone2"]
		weighted[index]["a_selected_weights"] = Vector3(0.1, 0.7, 0.2) if index != 0 else Vector3(0.8, 0.1, 0.1)
		weighted[index]["b_selected_weights"] = weighted[index]["a_selected_weights"]
	var regions: Dictionary = query.evaluate(weighted, target, PLANE)
	_check("all positively influencing bones retain boundary queries", regions.by_bone.size() == 3)
	_check("ranking region uses greatest averaged weight only for scoring", regions.ranking_regions[0].edges_in_reach == 1 and regions.ranking_regions[1].edges_in_reach == 3 and regions.ranking_regions[2].edges_in_reach == 0)
	_check("regional nearest gap remains independent", regions.ranking_regions[0].gap_m >= regions.ranking_regions[1].gap_m and regions.ranking_regions[1].bone_id == &"Bone1")
	var coincident: Dictionary = query.evaluate(_box(Vector2(-0.5, -0.5), Vector2(0.5, 0.5)), target, PLANE)
	_check("coincident boundaries never manufacture clearance", coincident.coincident_boundaries_unclassified and not coincident.planar_classification_complete and not coincident.planar_clearance_verified)
	_check("missing origin rejected", not query.prepare_target(_box(Vector2.ZERO, Vector2.ONE), &"").valid)
	_check("different origins rejected", not query.evaluate(weighted, target, &"OtherPlane").valid)
	_check("nonfinite coordinates rejected", not query.prepare_target([[Vector2(NAN, 0.0), Vector2.ONE]], PLANE).valid)
	_check("zero length boundary rejected", not query.prepare_target([[Vector2.ONE, Vector2.ONE]], PLANE).valid)
	_check("invalid reach rejected", not query.evaluate(weighted, target, PLANE, {"reach_m": -1.0}).valid)
	var partial: Dictionary = query.evaluate(weighted, target, PLANE, {"skin_classification_incomplete": true})
	_check("upstream incomplete classification is preserved", partial.valid and not partial.planar_classification_complete and not partial.planar_clearance_verified)
	var skipped: Dictionary = query.evaluate(_box(Vector2(0.25, -0.25), Vector2(0.75, 0.25)), target, PLANE, {"skip_skin_solid_classification": true})
	_check("fast mode retains target-inside tests without claiming skin solid certification", skipped.valid and skipped.skin_solid_classification_skipped and skipped.skin_inside_target_classification_complete and skipped.dynamic.inside_interval_samples > 0 and not skipped.planar_classification_complete)
	var tiny: Dictionary = query.prepare_target([[Vector2.ZERO, Vector2(0.0000001, 0.0)]], PLANE)
	_check("positive submicrometer edge is retained and diagnosed", tiny.valid and tiny.segments.size() == 1 and tiny.topology.sub_epsilon_edges == 1 and not tiny.topology_complete)
	var nearly_closed: Array = _box(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
	nearly_closed[3]["b"] = Vector2(-0.4999998, -0.5)
	var near_packet: Dictionary = query.prepare_target(nearly_closed, PLANE)
	_check("numerically near but unequal endpoints do not silently close a gap", near_packet.valid and near_packet.topology.noncoincident_endpoint_welds > 0 and not near_packet.topology_complete)
	var failed := 0
	for check: Dictionary in _checks:
		failed += int(not bool(check.passed))
	print(JSON.stringify({"tool": "skin_plane_contact_query_verification", "passed": failed == 0, "checks": _checks, "count": _checks.size(), "failures": failed}, "\t"))
	quit(0 if failed == 0 else 1)


func _box(minimum: Vector2, maximum: Vector2, dynamic: bool = true) -> Array:
	return _polygon([minimum, Vector2(maximum.x, minimum.y), maximum, Vector2(minimum.x, maximum.y)], dynamic)


func _polygon(points: Array, dynamic: bool = true) -> Array:
	var edges: Array = []
	for index: int in points.size():
		edges.append({"a": points[index], "b": points[(index + 1) % points.size()], "dynamic": dynamic})
	return edges


func _check(label: String, passed: bool) -> void:
	_checks.append({"name": label, "passed": passed})
