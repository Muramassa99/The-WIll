extends SceneTree

const Preference = preload("res://runtime/player/grip/skin_section_contact_preference.gd")
const PLANE := &"SectionPreferenceVerifierPlane"
var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var query := Preference.new()
	var fixture := _fixture()
	var pristine: Array = fixture.edges.duplicate(true)
	var result: Dictionary = query.annotate(fixture.edges, fixture.hand, Vector2(0.02, 0), Vector2(0.03, 0), PLANE)
	_check(result.valid and result.reason == "mapped" and result.mapped_segments == 8, "continuous two-sided contour maps eight strictly owned edges")
	_check(result.eligible_segments == 8 and result.neutral_segments == 0, "mapping does not invent owned sections")
	if result.reason != "mapped": _finish(); return
	_near(result.section_lengths_m[0], 0.01, 0.00000001, "S1 length reaches influence crossings rather than owned-edge endpoints")
	_near(result.section_lengths_m[1], 0.01, 0.00000001, "S2 full interval bridges unowned transition gaps")
	_near(result.section_lengths_m[2], 0.007 + sqrt(0.000018), 0.00000001, "S3 measures curved contour length not axial projection")
	_near(fixture.edges[0].location_bias.a_percent, 100.0, 0.0001, "distal skin tip is S3 one hundred percent")
	_near(fixture.edges[4].location_bias.a_percent, 90.0, 0.0001, "S2 first owned endpoint is ninety percent, not a renormalized hundred")
	_near(fixture.edges[4].location_bias.b_percent, 10.0, 0.0001, "S2 final owned endpoint is ten percent, not a renormalized zero")
	for edge: Dictionary in fixture.edges:
		if edge.has("location_bias"):
			_check(edge.location_bias.origin_id == PLANE and edge.location_bias.percent_units == &"percentage_points_0_to_100", "metadata preserves named plane and explicit percentage units")
			edge.erase("location_bias")
	_check(var_to_bytes(fixture.edges) == var_to_bytes(pristine), "annotation leaves geometry ownership and overlap caps byte-identical")
	query.annotate(fixture.edges, fixture.hand, Vector2(0.02, 0), Vector2(0.03, 0), PLANE)
	var reversed := _fixture()
	for edge: Dictionary in reversed.edges:
		for field: String in ["", "_source", "_selected_weights"]:
			var swap: Variant = edge["a" + field]
			edge["a" + field] = edge["b" + field]; edge["b" + field] = swap
	reversed.edges.reverse()
	var reversed_result: Dictionary = query.annotate(reversed.edges, reversed.hand, Vector2(0.02, 0), Vector2(0.03, 0), PLANE)
	_check(reversed_result.mapped_segments == result.mapped_segments, "edge winding and array order do not change mapping coverage")
	for index: int in fixture.edges.size():
		var original: Dictionary = fixture.edges[index]
		var other: Dictionary = reversed.edges[fixture.edges.size() - 1 - index]
		if original.has("location_bias"):
			_near(original.location_bias.a_percent, other.location_bias.b_percent, 0.0001, "reversed edge keeps same physical endpoint percentage")
	var mirrored := _fixture()
	for edge: Dictionary in mirrored.edges:
		edge.a.x = -edge.a.x; edge.b.x = -edge.b.x
	var reflected: Dictionary = query.annotate(mirrored.edges, mirrored.hand, Vector2(-0.02, 0), Vector2(-0.03, 0), PLANE)
	_check(reflected.mapped_segments == 8, "reflected hand contour has the same mapping coverage")
	for index: int in 3:
		_near(reflected.section_lengths_m[index], result.section_lengths_m[index], 0.00000001, "reflection preserves contour length")
	var scaled := _fixture()
	for edge: Dictionary in scaled.edges:
		edge.a *= 2.0; edge.b *= 2.0
	var scale_result: Dictionary = query.annotate(scaled.edges, scaled.hand, Vector2(0.04, 0), Vector2(0.06, 0), PLANE)
	_check(scale_result.mapped_segments == 8, "larger anatomy remains mapped")
	_near(scaled.edges[4].location_bias.a_percent, fixture.edges[4].location_bias.a_percent, 0.0001, "anatomical scale does not change percentage")
	_near(scale_result.section_lengths_m[2], 2.0 * result.section_lengths_m[2], 0.00000001, "ranking scale follows measured anatomy")
	var unequal := _fixture()
	unequal.edges[0].a = Vector2(0.03, 0)
	for index: int in range(11, 20):
		unequal.edges[index].a.y *= 2.0; unequal.edges[index].b.y *= 2.0
	# The Hand closure edge also owns the lower-side starting endpoint.
	unequal.edges[10].b.y *= 2.0
	var unequal_result: Dictionary = query.annotate(unequal.edges, unequal.hand, Vector2(0.02, 0), Vector2(0.03, 0), PLANE)
	_check(unequal_result.mapped_segments == 8, "unequal dorsal and palmar branch lengths remain eligible")
	if unequal_result.mapped_segments == 8:
		_near(unequal.edges[0].location_bias.section_length_m, unequal.edges[18].location_bias.section_length_m, 0.000000001, "both sides share one ranking length without a side preference")
	_check_neutral(query, "coplanar contour", "coplanar")
	_check_neutral(query, "ambiguous source topology", "ambiguous")
	_check_neutral(query, "coincident disconnected source seam", "seam")
	_check_neutral(query, "branched source topology", "branch")
	_check_neutral(query, "inconsistent shared source position", "position")
	_check_neutral(query, "zero-weight false section boundary", "weights")
	_check_neutral(query, "wrong coordinate origin", "origin")
	_aliases(query)
	_ranking(query)
	var source := {"kind": "edge", "topology_key": "e:0:1", "vertex_ids": PackedInt32Array([0, 1]), "t": 0.25}
	_near(query._hand_weight(source, PackedFloat64Array([0.2, 0.8])), 0.35, 0.000000001, "Hand influence follows original low-to-high source-edge interpolation")
	_finish()


func _aliases(query: RefCounted) -> void:
	var fixture := _fixture()
	var vertices := PackedVector3Array()
	var ids := PackedInt32Array()
	var weights := PackedFloat32Array()
	for index: int in fixture.edges.size():
		var edge: Dictionary = fixture.edges[index]
		vertices.append(Vector3(edge.a.x, edge.a.y, 0.0))
		ids.append_array(PackedInt32Array([0, 1, 2, 3]))
		weights.append_array(PackedFloat32Array([edge.a_selected_weights.x, edge.a_selected_weights.y,
			edge.a_selected_weights.z, fixture.hand[index]]))
	var duplicate: int = vertices.size()
	vertices.append(vertices[4]); ids.append_array(ids.slice(16, 20)); weights.append_array(weights.slice(16, 20))
	fixture.hand.append(fixture.hand[4])
	fixture.edges[4].a_source = _source(duplicate)
	var original: Array = fixture.edges.duplicate(true)
	var aliases: PackedInt32Array = Preference.build_vertex_aliases(vertices, ids, weights, 4)
	_check(aliases.size() == vertices.size() and aliases[duplicate] == 4, "exact complete reference skin tuple aliases split render vertex to first ID")
	var result: Dictionary = query.annotate(fixture.edges, fixture.hand, Vector2(0.02, 0), Vector2(0.03, 0), PLANE, aliases)
	_check(result.mapped_segments == 8, "proven reference alias reconnects split render seam for preference only")
	for edge: Dictionary in fixture.edges: edge.erase("location_bias")
	_check(var_to_bytes(fixture.edges) == var_to_bytes(original), "reference aliases preserve original source IDs and physical geometry")
	var distinct_weights := weights.duplicate()
	distinct_weights[duplicate * 4] += 0.01
	var distinct: PackedInt32Array = Preference.build_vertex_aliases(vertices, ids, distinct_weights, 4)
	_check(distinct[duplicate] == duplicate, "coincident reference vertices with different weights do not alias")
	var unmatched: Dictionary = query.annotate(fixture.edges, fixture.hand, Vector2(0.02, 0), Vector2(0.03, 0), PLANE, distinct)
	_check(unmatched.mapped_segments == 0 and unmatched.valid, "unproven seam remains neutral rather than welded")
	var distinct_binds := ids.duplicate(); distinct_binds[duplicate * 4 + 1] = 9
	_check(Preference.build_vertex_aliases(vertices, distinct_binds, weights, 4)[duplicate] == duplicate, "complete bind identity is required for alias")
	var nearby := vertices.duplicate(); nearby[duplicate].x += 0.00000001
	_check(Preference.build_vertex_aliases(nearby, ids, weights, 4)[duplicate] == duplicate, "nearby reference positions inside slicer epsilon are never welded")
	_check(Preference.build_vertex_aliases(vertices, ids, weights, 3).is_empty(), "mismatched reference skin layout supplies no alias map")
	var paired_vertices := PackedVector3Array([Vector3.ZERO, Vector3.ONE, Vector3.ONE, Vector3.ZERO])
	var paired_ids := PackedInt32Array([0, 1, 1, 0])
	var paired_weights := PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
	var paired_aliases: PackedInt32Array = Preference.build_vertex_aliases(paired_vertices, paired_ids, paired_weights, 1)
	var forward := {"kind": "edge", "topology_key": "e:0:1", "vertex_ids": PackedInt32Array([0, 1]), "t": 0.25}
	var reverse := {"kind": "edge", "topology_key": "e:2:3", "vertex_ids": PackedInt32Array([2, 3]), "t": 0.75}
	_check(query._topology_key(forward, paired_aliases) == query._topology_key(reverse, paired_aliases), "reversed aliased source edge has one connectivity identity")
	var hand := PackedFloat64Array([0.1, 0.9, 0.9, 0.1])
	_near(query._hand_weight(forward, hand), query._hand_weight(reverse, hand), 0.000000001, "reversed aliased edge retains original Hand interpolation direction")


func _check_neutral(query: RefCounted, label: String, mutation: String) -> void:
	var fixture := _fixture()
	match mutation:
		"coplanar": fixture.edges[4].coplanar = true
		"ambiguous": fixture.edges[4].a_source.topology_ambiguous = true
		"seam":
			fixture.hand.append(fixture.hand[4])
			fixture.edges[4].a_source = _source(fixture.hand.size() - 1)
		"branch": fixture.edges.append(fixture.edges[4].duplicate(true))
		"position": fixture.edges[4].a.y += 0.00001
		"weights":
			fixture.edges[2].b_selected_weights = Vector3.ZERO
			fixture.edges[3].a_selected_weights = Vector3.ZERO
		"origin": fixture.edges[4].origin_id = &"UnrelatedPlane"
	var physical: Array = fixture.edges.duplicate(true)
	var result: Dictionary = query.annotate(fixture.edges, fixture.hand, Vector2(0.02, 0), Vector2(0.03, 0), PLANE)
	_check(result.valid and result.mapped_segments == 0 and result.neutral_segments == result.eligible_segments, label + " stays neutral, never rejects physical contact")
	_check(var_to_bytes(physical) == var_to_bytes(fixture.edges), label + " leaves input geometry and caps unchanged")


func _ranking(query: RefCounted) -> void:
	for section: int in range(1, 4):
		var edge := {"section_owner": section - 1, "origin_id": PLANE,
			"location_bias": {"a_percent": 0.0, "b_percent": 100.0, "section_length_m": 0.02, "origin_id": PLANE}}
		var peak: float = Preference.PEAKS[section - 1] / 100.0
		var witness := {"signed_clearance_m": 0.00102, "skin_segment_t": peak}
		var preferred: Dictionary = query.rank(edge, witness, section, 0.00002, 0.1)
		_near(preferred.bell, 1.0, 0.000000001, "section peak has full Gaussian preference")
		_near(preferred.percent, 100.0 * peak, 0.000001, "reported rank coordinate uses percentage points")
		_near(preferred.credit_m2, 0.000004, 0.000000000001, "explicit strength bounds preference credit by squared anatomical length fraction")
		witness.skin_segment_t = peak + (0.25 if peak < 0.75 else -0.25)
		var spread: Dictionary = query.rank(edge, witness, section, 0.00002, 0.1)
		_near(spread.bell, exp(-0.5), 0.000000001, "twenty-five percentage points is one Gaussian standard deviation")
		_check(preferred.score_m2 < spread.score_m2, "equal-distance preferred skin ranks ahead")
		for t: float in [0.0, 1.0]:
			witness.skin_segment_t = t
			_check(is_finite(query.rank(edge, witness, section, 0.00002, 0.1).score_m2), "both section endpoints remain eligible")
		var zero: Dictionary = query.rank(edge, witness, section, 0.00002, 0.0)
		_near(zero.score_m2, 0.000001, 0.000000000001, "zero strength is ordinary distance ranking")
		var missing: Dictionary = query.rank({"section_owner": section - 1}, witness, section, 0.00002, 0.1)
		_check(not missing.biased and missing.score_m2 == zero.score_m2, "missing metadata keeps neutral candidate eligible")
		witness.skin_segment_t = peak; witness.signed_clearance_m = 0.01002
		_check(query.rank(edge, witness, section, 0.00002, 0.1).score_m2 > zero.score_m2, "distant preferred point loses to nearer nonpreferred contact")
		edge.section_owner = -1
		_check(not query.rank(edge, witness, section, 0.00002, 0.1).biased, "unassigned or palm skin receives no digit bias")


func _fixture() -> Dictionary:
	var points := [Vector2(0.03, 0), Vector2(0.027, 0.003), Vector2(0.021, 0.003),
		Vector2(0.02, 0.003), Vector2(0.019, 0.003), Vector2(0.011, 0.003),
		Vector2(0.01, 0.003), Vector2(0.009, 0.003), Vector2(0.001, 0.003),
		Vector2(0, 0.003), Vector2(-0.005, 0), Vector2(0, -0.003),
		Vector2(0.001, -0.003), Vector2(0.009, -0.003), Vector2(0.01, -0.003),
		Vector2(0.011, -0.003), Vector2(0.019, -0.003), Vector2(0.02, -0.003),
		Vector2(0.021, -0.003), Vector2(0.027, -0.003)]
	var one := Vector3(1, 0, 0); var two := Vector3(0, 1, 0); var three := Vector3(0, 0, 1)
	var selected := [three, three, three, (two + three) * 0.5, two, two,
		(one + two) * 0.5, one, one, one * 0.5, Vector3.ZERO, one * 0.5,
		one, one, (one + two) * 0.5, two, two, (two + three) * 0.5, three, three]
	var hand := PackedFloat64Array(); hand.resize(points.size()); hand.fill(0.0)
	hand[9] = 0.5; hand[10] = 1.0; hand[11] = 0.5
	var edges: Array = []
	for i: int in points.size():
		var j: int = (i + 1) % points.size()
		var owner := -1
		for section: int in 3:
			if selected[i][section] > 0.5 and selected[j][section] > 0.5: owner = section
		edges.append({"a": points[i], "b": points[j], "a_selected_weights": selected[i],
			"b_selected_weights": selected[j], "a_source": _source(i), "b_source": _source(j),
			"section_owner": owner, "origin_id": PLANE, "source_id": "synthetic/%d" % i,
			"max_inward_depth_m": 0.00038, "allowance_unassigned": owner < 0, "coplanar": false})
	return {"edges": edges, "hand": hand}


func _source(vertex: int) -> Dictionary:
	return {"kind": "vertex", "topology_key": "v:%d" % vertex,
		"vertex_ids": PackedInt32Array([vertex]), "t": 0.0, "coplanar": false, "topology_ambiguous": false}


func _near(actual: float, expected: float, tolerance: float, label: String) -> void:
	_check(is_finite(actual) and absf(actual - expected) <= tolerance, label + ": " + str(actual))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition: _failures.append(label)


func _finish() -> void:
	var result := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures,
		"scope": "synthetic contour mapping and discrete ranking; not live grip or motion proof"}
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "C:/WORKSPACE/test_artifacts/skin_section_contact_preference_%s.json" % stamp
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result, "\t")); file.close()
	print(JSON.stringify(result)); print(path)
	quit(0 if _failures.is_empty() else 1)
