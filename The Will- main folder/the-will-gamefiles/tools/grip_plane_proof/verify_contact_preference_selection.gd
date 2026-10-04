extends SceneTree

## Real solver selection helpers with synthetic measured packets. This does not
## run acquisition, prove convergence, or choose the live preference strength.
const Solver = preload("res://runtime/player/grip/contact_driven_grip_preparation.gd")
const Circle = preload("res://runtime/player/grip/planar_circle_skin_contact.gd")
const Visibility = preload("res://runtime/player/grip/grip_target_visibility.gd")
const TEST_STRENGTH := 0.1
const LENGTH_M := 0.02
const PEAKS := [0.2, 0.5, 0.8]


## Exercise the production response loop and preference helpers. Candidate
## sampling and response directions are controlled, not a geometry/IK proof.
class ProjectionFixture extends Solver:
	var initial_sample: Dictionary
	var trial_sample: Dictionary
	var mode := ""
	var evaluations := 0
	var forced_failures := 0
	var linear_calls := 0
	var differentiated_sources: Array[String] = []

	func _evaluate(_context: Dictionary, _saved: Dictionary, angles: Dictionary, placement: Vector2,
			digit: StringName, _requested_radius: float, _palm_required: bool, _reuse: Dictionary = {},
			_guide_kind: StringName = &"circle") -> Dictionary:
		evaluations += 1
		var sample: Dictionary = (initial_sample if evaluations == 1 else trial_sample).duplicate(true)
		sample.angles = angles.duplicate(true)
		sample.placement = placement
		if mode == "derivative_budget":
			# A controlled decreasing scalar cost lets the real loop exhaust its
			# existing budget after fallback, without claiming physical convergence.
			sample.cost = initial_sample.cost / (1.0 + absf(float(angles[digit][0])))
			sample.attached = false
		return sample

	func _contact_gradient(contact: Dictionary, _current: Dictionary, _probes: Array, _kind: StringName) -> Dictionary:
		differentiated_sources.append(str(contact.segment.source_id))
		if mode.begins_with("derivative") and contact.segment.source_id == "preferred" and forced_failures == 0:
			forced_failures += 1
			return {"valid": false, "reason": "fixture_preferred_derivative_unavailable"}
		return {"valid": true, "gradient": [1.0, 0.0, 0.0]}

	func _active_bound_linear(_matrix: Array, _rhs: Array, _angles: Array, _snapshot: Dictionary) -> Array:
		linear_calls += 1
		if mode == "singular" and forced_failures == 0:
			forced_failures += 1
			return []
		return [1.0, 0.0, 0.0]


var _solver := Solver.new()
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_neutral()
	_check(_solver.configure_contact_preference(TEST_STRENGTH), "test-only strength configured")
	_peaks_and_distance()
	_source_identity()
	_invalid_fixed_sources()
	_consistent_merit()
	_same_edge_circle_points()
	_production_wrapper_points()
	_projection_control_flow()
	_gripping_side_only()
	print("CONTACT_PREFERENCE_SELECTION=" + JSON.stringify({"passed": _failures.is_empty(),
		"checks": _checks, "failures": _failures, "test_strength_fraction": TEST_STRENGTH,
		"scope": "synthetic packets against real solver selection and fixed-source cost helpers",
		"live_strength_changed_by_verifier": false,
		"live_default_strength_fraction": Solver.new().get("_preference_strength_fraction"),
		"acquisition_run": false, "files_written": false,
		"projection_loop_exercised": true, "projection_control_geometry_and_derivatives_mocked": true}))
	quit(0 if _failures.is_empty() else 1)


func _neutral() -> void:
	for kind: StringName in [&"circle", &"saved_wrapper"]:
		var sample := _sample(1, kind)
		_set_gap(sample, 0, -0.001)
		_set_gap(sample, 1, 0.00003)
		_refresh_physical_rows(sample)
		_check(sample.rows[0].segment.source_id == "closer", "fixture retains smallest signed inside clearance")
		_check(pow(sample.rows[0].residual, 2.0) > pow(0.00003 - Solver.CLEARANCE_M, 2.0), "fixture distinguishes legacy signed order from squared distance")
		_check(_solver.configure_contact_preference(0.0), "zero strength accepted")
		_assert_neutral(sample, true, "zero strength " + str(kind))
		_check(_solver.configure_contact_preference(TEST_STRENGTH), "test strength restored")
		_assert_neutral(sample, false, "explicit nearest fallback " + str(kind))
		for edge: Dictionary in sample.skin.segments: edge.erase("location_bias")
		_assert_neutral(sample, true, "missing mapping keeps signed order " + str(kind))
		for slot: StringName in [&"hand_right", &"hand_left"]:
			var thumb := _sample(2, kind, &"thumb", slot)
			_assert_neutral(thumb, true, "Thumb unchanged " + str(kind) + "/" + str(slot))


func _assert_neutral(sample: Dictionary, allow: bool, label: String) -> void:
	var before := var_to_bytes(sample)
	var selection: Dictionary = _solver._attraction_selection(sample, allow)
	_check(var_to_bytes(selection.rows) == var_to_bytes(sample.rows), label + " rows byte-identical")
	_check(selection.sources.is_empty() and selection.changed == 0 and selection.merit == sample.cost, label + " no source lock or merit change")
	var fixed: Dictionary = _solver._fixed_attraction_cost(sample, selection)
	_check(fixed.valid and fixed.cost == sample.cost, label + " exact physical cost")
	_check(var_to_bytes(sample) == before, label + " all physical data unchanged")


func _peaks_and_distance() -> void:
	for kind: StringName in [&"circle", &"saved_wrapper"]:
		for slot: StringName in [&"hand_right", &"hand_left"]:
			for digit: StringName in [&"index", &"middle", &"ring", &"pinky"]:
				for section: int in range(1, 4):
					var label := "%s/%s/%s/S%d" % [kind, slot, digit, section]
					var sample := _sample(section, kind, digit, slot)
					var before := var_to_bytes(sample)
					var selection: Dictionary = _solver._attraction_selection(sample)
					_check(selection.rows[0].segment.source_id == "preferred" and selection.changed == 1, label + " preferred peak defeats modestly closer endpoint")
					_near(selection.rows[0].preference.percent, PEAKS[section - 1] * 100.0, 0.000001, label + " correct section peak")
					_check(selection.sources.size() == 1 and selection.sources.has(section), label + " only ordinary digit attraction selected")
					_check(var_to_bytes(selection.rows.slice(1)) == var_to_bytes(sample.rows.slice(1)), label + " palm and safety rows unchanged")
					var fixed: Dictionary = _solver._fixed_attraction_cost(sample, selection)
					_check(fixed.valid, label + " selected source resolves uniquely")
					_check(var_to_bytes(sample) == before, label + " physical rows records geometry caps and completion unchanged")
					_set_gap(sample, 1, 0.01002)
					_refresh_physical_rows(sample)
					var distant: Dictionary = _solver._attraction_selection(sample)
					_check(distant.rows[0].segment.source_id == "closer" and distant.changed == 0, label + " distant peak loses to available nearer contact")


func _source_identity() -> void:
	for kind: StringName in [&"circle", &"saved_wrapper"]:
		var sample := _sample(1, kind)
		var selection: Dictionary = _solver._attraction_selection(sample)
		var baseline: Dictionary = _solver._fixed_attraction_cost(sample, selection)
		var reordered: Dictionary = sample.duplicate(true)
		reordered.records.reverse()
		reordered.skin.segments.reverse()
		reordered.circle_records.reverse()
		_refresh_physical_rows(reordered)
		var result: Dictionary = _solver._fixed_attraction_cost(reordered, selection)
		_check(result.valid, str(kind) + " source reordering preserves selection identity")
		if result.valid: _near(result.cost, baseline.cost, 0.00000000000001, str(kind) + " reordered cost identical")
		var reranked: Dictionary = _solver._attraction_selection(reordered)
		_near(reranked.merit, selection.merit, 0.00000000000001, str(kind) + " global merit independent of record order")
		if kind == &"saved_wrapper":
			_check(reranked.rows[0].measurement_index == 2, "reranked derivative index follows current full record order")
		var slid: Dictionary = sample.duplicate(true)
		var edge: Dictionary = slid.records[1].segment
		edge.a_source.t = 0.35
		edge.b_source.t = 0.65
		edge.a.y += 0.0001
		edge.b.y += 0.0001
		slid.skin.segments[1] = edge
		slid.records[1].witness.skin_segment_t = 0.7
		slid.circle_records[1].skin_segment_t = 0.7
		_set_gap(slid, 1, 0.00082)
		_refresh_physical_rows(slid)
		result = _solver._fixed_attraction_cost(slid, selection)
		_check(result.valid, str(kind) + " changing source-edge interpolation and contact parameter permits sliding")
		if result.valid: _near(result.cost, _other_cost(slid) + pow(0.0008, 2.0), 0.00000000000001, str(kind) + " sliding uses current ordinary distance")
		var reversed: Dictionary = sample.duplicate(true)
		edge = reversed.records[1].segment
		var temporary: Dictionary = edge.a_source
		edge.a_source = edge.b_source
		edge.b_source = temporary
		reversed.skin.segments[1] = edge
		_check(_solver._fixed_attraction_cost(reversed, selection).valid, str(kind) + " endpoint winding does not change identity")


func _invalid_fixed_sources() -> void:
	for kind: StringName in [&"circle", &"saved_wrapper"]:
		var sample := _sample(1, kind)
		var selection: Dictionary = _solver._attraction_selection(sample)
		for mutation: String in ["duplicate", "disappeared", "owner", "origin", "source_edge", "ambiguous_witness", "ambiguous_topology"]:
			var trial: Dictionary = sample.duplicate(true)
			match mutation:
				"duplicate":
					trial.records.append(trial.records[1].duplicate(true))
					trial.skin.segments.append(trial.skin.segments[1].duplicate(true))
					trial.circle_records.append(trial.circle_records[1].duplicate(true))
				"disappeared":
					trial.records.remove_at(1)
					trial.skin.segments.remove_at(1)
					trial.circle_records.remove_at(1)
				"owner":
					trial.records[1].segment.section_owner = 1
					trial.skin.segments[1].section_owner = 1
				"origin":
					trial.records[1].segment.origin_id = &"UnrelatedPlane"
					trial.skin.segments[1].origin_id = &"UnrelatedPlane"
				"source_edge":
					trial.records[1].segment.a_source.topology_key = "e:900:901"
					trial.skin.segments[1].a_source.topology_key = "e:900:901"
				"ambiguous_witness":
					trial.records[1].witness.gradient_ambiguous = true
					trial.circle_records[1].tangent_ambiguous = true
				"ambiguous_topology":
					trial.records[1].segment.a_source.topology_ambiguous = true
					trial.skin.segments[1].a_source.topology_ambiguous = true
			var before := var_to_bytes(trial)
			_check(not _solver._fixed_attraction_cost(trial, selection).valid, str(kind) + " invalid frozen source: " + mutation)
			_check(var_to_bytes(trial) == before, str(kind) + " rejected preference preserves physical packet: " + mutation)
			_check(_solver._attraction_selection(trial, false).sources.is_empty(), str(kind) + " neutral fallback remains available: " + mutation)


func _consistent_merit() -> void:
	var sample := _sample(1, &"saved_wrapper")
	var selection: Dictionary = _solver._attraction_selection(sample)
	var credit: float = pow(TEST_STRENGTH * LENGTH_M, 2.0)
	_near(selection.merit, _other_cost(sample) + pow(0.001, 2.0) - credit, 0.00000000000001, "global merit replaces exactly one physical residual with ranked score")
	var fixed: Dictionary = _solver._fixed_attraction_cost(sample, selection)
	_near(fixed.cost, _other_cost(sample) + pow(0.001, 2.0), 0.00000000000001, "fixed-source line cost is ordinary distance without preference credit")
	var trial: Dictionary = sample.duplicate(true)
	_set_gap(trial, 0, 0.00202)
	_set_gap(trial, 1, 0.00082)
	_refresh_physical_rows(trial)
	_check(trial.rows[0].segment.source_id == "preferred", "trial physical nearest source changed")
	var result: Dictionary = _solver._fixed_attraction_cost(trial, selection)
	_check(result.valid, "fixed identity survives physical nearest-source change")
	if result.valid:
		_near(result.cost, _other_cost(trial) + pow(0.0008, 2.0), 0.00000000000001, "fixed cost does not double-count replacement after nearest changes")
		_check(result.cost < fixed.cost, "same-source ordinary residual improvement remains comparable")
	trial.material_condition_met = true
	trial.attached = true
	var before := var_to_bytes(trial)
	_solver._attraction_selection(trial)
	_solver._fixed_attraction_cost(trial, selection)
	_check(_solver._complete(trial) and var_to_bytes(trial) == before, "physical completion remains independent of preference scoring")


func _same_edge_circle_points() -> void:
	for section: int in range(1, 4):
		var label := "real circle same edge S%d" % section
		var sample := _real_circle_sample(section)
		if sample.is_empty(): continue
		var physical_before := var_to_bytes(sample)
		var selection: Dictionary = _solver._attraction_selection(sample)
		var chosen: Dictionary = selection.rows[0]
		_check(chosen.segment.source_id == sample.rows[0].segment.source_id, label + " selects a point on the original nearest edge")
		_check(absf(float(chosen.witness.skin_segment_t) - float(sample.rows[0].witness.skin_segment_t)) > 0.1, label + " preferred point differs from full-edge nearest witness")
		_near(chosen.witness.skin_segment_t, PEAKS[section - 1], 0.00000001, label + " exact peak parameter selected")
		_check(chosen.witness.get("attraction_only", false), label + " point witness is explicitly attraction-only")
		_check(selection.point_parameters.has(section), label + " selected point parameter recorded for this step")
		if not selection.point_parameters.has(section): continue
		_near(selection.point_parameters[section], PEAKS[section - 1], 0.00000001, label + " frozen parameter matches selected witness")
		_check(sample.circle_records[1].maximum_inward_depth_m > Solver.NUMERIC_GUARD_M and sample.rows[1].residual < 0.0,
			label + " fixture includes unsafe unpreferred full-edge penetration")
		_check(var_to_bytes(selection.rows[1]) == var_to_bytes(sample.rows[1]), label + " unsafe physical response row retained byte-for-byte")
		_check(not _solver._complete(sample), label + " preferred safe point does not complete unsafe physical sample")
		var fixed: Dictionary = _solver._fixed_attraction_cost(sample, selection)
		_check(fixed.valid, label + " frozen point evaluates on its original edge")
		if fixed.valid:
			_near(fixed.cost, _real_circle_expected_cost(sample, PEAKS[section - 1]), 0.000000000001, label + " fixed cost follows actual radial point distance plus full safety penalty")
		_check(var_to_bytes(sample) == physical_before, label + " all measured physical data remains unchanged")
		var reversed := _real_circle_sample(section)
		if not reversed.is_empty():
			var edge: Dictionary = reversed.skin.segments[0]
			for suffix: String in ["", "_source"]:
				var temporary: Variant = edge["a" + suffix]
				edge["a" + suffix] = edge["b" + suffix]
				edge["b" + suffix] = temporary
			edge.location_bias.a_percent = 100.0
			edge.location_bias.b_percent = 0.0
			var measurement: Dictionary = Circle.new().evaluate(reversed.skin.segments, reversed.section.center,
				reversed.radius_m, reversed.section.origin_id, &"GripPreparationGuide")
			_check(measurement.get("valid", false), label + " reversed edge remeasures complete physical geometry")
			if measurement.get("valid", false):
				reversed.circle_records = measurement.segments
				for index: int in reversed.rows.size():
					reversed.rows[index].segment = reversed.skin.segments[index]
					reversed.rows[index].witness = measurement.segments[index]
					reversed.rows[index].residual = float(measurement.segments[index].signed_clearance_m) - Solver.CLEARANCE_M
				reversed.cost = pow(float(reversed.rows[0].residual), 2.0) + 4.0 * pow(float(reversed.rows[1].residual), 2.0)
				var reversed_fixed: Dictionary = _solver._fixed_attraction_cost(reversed, selection)
				_check(reversed_fixed.valid, label + " reversed source winding retains frozen physical point")
				if reversed_fixed.valid:
					_near(reversed_fixed.cost, _real_circle_expected_cost(reversed, 1.0 - PEAKS[section - 1]), 0.000000000001,
						label + " frozen point parameter reverses to one minus t")
		# A new candidate has a moved target and a changed contour interval. The
		# old step must retain t; a fresh selection must use the new peak location.
		var trial := _real_circle_sample(section, 0.0005 if section < 3 else -0.0005)
		if trial.is_empty(): continue
		trial.skin.segments[0].location_bias.b_percent = 80.0
		trial.skin.segments[0].location_bias.section_length_m = 0.0125
		var trial_before := var_to_bytes(trial)
		var selected_before := var_to_bytes(selection)
		var trial_fixed: Dictionary = _solver._fixed_attraction_cost(trial, selection)
		_check(trial_fixed.valid, label + " changed mapping and target preserve frozen source point")
		if trial_fixed.valid:
			_near(trial_fixed.cost, _real_circle_expected_cost(trial, PEAKS[section - 1]), 0.000000000001, label + " trial uses old parameter instead of its newly preferred parameter")
		var fresh: Dictionary = _solver._attraction_selection(trial)
		var fresh_t: float = PEAKS[section - 1] / 0.8
		_near(fresh.rows[0].witness.skin_segment_t, fresh_t, 0.00000001, label + " next selection slides to the new mapped peak")
		_check(absf(float(fresh.rows[0].witness.skin_segment_t) - float(selection.point_parameters[section])) > 0.01, label + " frozen point is not a permanent attachment")
		_check(var_to_bytes(selection) == selected_before and var_to_bytes(trial) == trial_before, label + " re-evaluation changes neither frozen selection nor physical trial")


func _real_circle_sample(section: int, center_shift: float = 0.0) -> Dictionary:
	var origin := &"RealCirclePreferencePlane"
	var center := Vector2((0.01 if section == 3 else 0.0) + center_shift, 0.0)
	var edge := _edge("one_real_skin_edge", section - 1, origin, 50)
	edge.a = Vector2(0.0, 0.0202)
	edge.b = Vector2(0.01, 0.0202)
	edge.location_bias.section_length_m = 0.01
	var unsafe := _edge("unsafe_other_skin", -1, origin, 60)
	unsafe.a = Vector2(center.x - 0.002, 0.0199)
	unsafe.b = Vector2(center.x + 0.002, 0.0199)
	unsafe.allowance_unassigned = true
	unsafe.max_inward_depth_m = 0.0
	var edges: Array = [edge, unsafe]
	var measured: Dictionary = Circle.new().evaluate(edges, center, 0.02, origin, &"GripPreparationGuide")
	_check(measured.get("valid", false), "real circle fixture measures all source edges")
	if not measured.get("valid", false): return {}
	var ordinary := {"segment": edge, "witness": measured.segments[0], "section": section, "required": true,
		"residual": float(measured.segments[0].signed_clearance_m) - Solver.CLEARANCE_M}
	var safety := {"segment": unsafe, "witness": measured.segments[1], "section": -1, "required": false,
		"residual": float(measured.segments[1].signed_clearance_m) - Solver.CLEARANCE_M}
	return _with_visibility({"digit": &"middle", "guide_kind": &"circle", "section": {"center": center, "origin_id": origin},
		"radius_m": 0.02, "skin": {"segments": edges}, "circle_records": measured.segments,
		"rows": [ordinary, safety], "cost": pow(float(ordinary.residual), 2.0) + 4.0 * pow(float(safety.residual), 2.0),
		"max_guide_depth_m": measured.maximum_inward_depth_m, "attached": false})


func _real_circle_expected_cost(sample: Dictionary, t: float) -> float:
	# Independent scalar radial formula; do not use the solver's point query as
	# its own expected-value oracle. Preserve the entire unsafe-edge penalty.
	var edge: Dictionary = sample.skin.segments[0]
	var x: float = float(edge.a.x) + t * (float(edge.b.x) - float(edge.a.x)) - float(sample.section.center.x)
	var y: float = float(edge.a.y) + t * (float(edge.b.y) - float(edge.a.y)) - float(sample.section.center.y)
	var residual: float = sqrt(x * x + y * y) - float(sample.radius_m) - Solver.CLEARANCE_M
	return residual * residual + 4.0 * pow(float(sample.rows[1].residual), 2.0)


func _production_wrapper_points() -> void:
	var solver := Solver.new()
	solver.configure_contact_preference(TEST_STRENGTH)
	var sample := _raw_wrapper_sample(solver, "ordinary")
	if not sample.get("valid", false): return
	_check(not sample.section.digit_target.has("revision") and not sample.section.digit_target.has("edges"), "wrapper fixture starts with raw saved section rather than preprepared target")
	_check(sample.get("prepared_contact_targets", {}).get("digit_target", {}).has("edges"), "production wrapper sample retains prepared point-query target")
	if not sample.get("prepared_contact_targets", {}).get("digit_target", {}).has("edges"): return
	_check(sample.prepared_contact_targets.digit_target.polygon == sample.section.digit_target.polygon, "preparation preserves exact saved target vertices")
	var before := var_to_bytes(sample)
	var selection: Dictionary = solver._attraction_selection(sample)
	var chosen := _required_selection_row(selection.rows, 1)
	_check(not chosen.is_empty() and chosen.has("point_parameter"), "raw saved-section production path selects an interior peak point")
	if chosen.is_empty() or not chosen.has("point_parameter"): return
	_check(chosen.segment.source_id == sample.regions[1].best.segment.source_id, "wrapper point stays on original section-owned edge")
	_near(chosen.point_parameter, 0.2, 0.00000001, "wrapper production point uses S1 twenty-percent peak")
	_check(absf(float(chosen.point_parameter) - float(sample.regions[1].best.witness.skin_segment_t)) > 0.01, "wrapper peak differs from unrestricted whole-edge witness")
	_check(chosen.witness.get("attraction_only", false) and not chosen.witness.get("whole_skin_clearance_verified", true), "wrapper point cannot claim full-edge safety")
	var fixed: Dictionary = solver._fixed_attraction_cost(sample, selection)
	_check(fixed.valid, "production prepared target supports fixed-point line cost")
	_check(not sample.accepted_contact_constraints and not sample.constraint_blockers.is_empty() and not solver._complete(sample), "unsafe unpreferred source still blocks production physical completion")
	_check(var_to_bytes(sample) == before, "wrapper selection and fixed cost preserve all physical rows records caps and targets")
	# Keep the same source edge, but move its nearest witness from an ordinary
	# exterior point to an exact square corner. The selected t=.2 remains outside
	# with a unique point-distance gradient, although full-edge nearest is now
	# ambiguous. Another S1 edge supplies the unrestricted physical row.
	var clean := _raw_wrapper_sample(solver, "clean_point")
	var corner := _raw_wrapper_sample(solver, "corner_point")
	if not clean.get("valid", false) or not corner.get("valid", false): return
	var clean_selection: Dictionary = solver._attraction_selection(clean)
	var clean_chosen := _required_selection_row(clean_selection.rows, 1)
	_check(not clean_chosen.is_empty() and clean_chosen.segment.source_id == "moving_peak_skin" and clean_selection.point_parameters.has(1), "clean wrapper candidate selects point before nearest becomes ambiguous")
	if clean_chosen.is_empty() or not clean_selection.point_parameters.has(1): return
	var ambiguous: Dictionary = corner.records[corner.records.size() - 1]
	_check(ambiguous.segment.source_id == "moving_peak_skin" and ambiguous.witness.gradient_ambiguous, "actual full-edge square-corner witness is gradient ambiguous")
	var corner_before := var_to_bytes(corner)
	var corner_selection: Dictionary = solver._attraction_selection(corner)
	var corner_chosen := _required_selection_row(corner_selection.rows, 1)
	_check(not corner_chosen.is_empty() and corner_chosen.segment.source_id == "moving_peak_skin" and corner_chosen.has("point_parameter"), "ambiguous nearest witness does not suppress usable exact peak candidate")
	if not corner_chosen.is_empty():
		_check(not corner_chosen.witness.gradient_ambiguous, "selected point has independently resolved unique gradient")
	var corner_fixed: Dictionary = solver._fixed_attraction_cost(corner, clean_selection)
	_check(corner_fixed.valid, "frozen point remains valid when its source's nearest witness becomes ambiguous")
	if corner_fixed.valid:
		var point_y: float = float(ambiguous.segment.a.y) + 0.2 * (float(ambiguous.segment.b.y) - float(ambiguous.segment.a.y))
		var residual: float = point_y - float(corner.section.digit_target.polygon[2].y) - Solver.CLEARANCE_M
		var expected: float = corner.cost - pow(float(corner.regions[1].best.residual), 2.0) + residual * residual
		_near(corner_fixed.cost, expected, 0.00000000001, "ambiguous-nearest trial cost uses actual frozen exterior-point clearance")
	_check(not corner.accepted_contact_constraints and not solver._complete(corner), "usable point cannot remove an unrelated full-skin cap blocker")
	_check(var_to_bytes(corner) == corner_before, "ambiguous-nearest selection preserves every full physical measurement")


func _raw_wrapper_sample(solver: RefCounted, mode: String) -> Dictionary:
	var origin := &"RawWrapperPreferencePlane"
	var section := {"origin_id": origin, "center": Vector2.ZERO}
	for kind: StringName in [&"handle", &"digit_target", &"palm_target"]:
		section[kind] = {"valid": true, "complete": true, "origin_id": origin,
			"source_id": StringName("RawPreference/" + str(kind)),
			"polygon": PackedVector2Array([Vector2(-0.01, -0.01), Vector2(0.01, -0.01), Vector2(0.01, 0.01), Vector2(-0.01, 0.01)])}
	var edges: Array = []
	for owner: int in range(3):
		var edge := _edge("wrapper_S%d" % (owner + 1), owner, origin, 100 + owner * 10)
		edge.a = Vector2(-0.006, 0.0102 + owner * 0.0001)
		edge.b = Vector2(0.006, 0.0102 + owner * 0.0001)
		# Three physically exposed faces of a synthetic curled digit. Stacking
		# all sections above the same face would occlude S2/S3 behind S1.
		if owner == 1:
			edge.a = Vector2(0.0103, -0.006); edge.b = Vector2(0.0103, 0.006)
		elif owner == 2:
			edge.a = Vector2(-0.006, -0.0104); edge.b = Vector2(0.006, -0.0104)
		edge.location_bias.section_length_m = 0.012
		if owner != 0 or mode != "ordinary": edge.erase("location_bias")
		edges.append(edge)
	var unsafe := _edge("wrapper_unsafe_unassigned", -1, origin, 150)
	unsafe.a = Vector2(-0.002, 0.0099)
	unsafe.b = Vector2(0.002, 0.0099)
	unsafe.allowance_unassigned = true
	unsafe.max_inward_depth_m = 0.0
	edges.append(unsafe)
	if mode != "ordinary":
		var moving := _edge("moving_peak_skin", 0, origin, 160)
		moving.a = Vector2(0.009, 0.0102) if mode == "clean_point" else Vector2(0.01, 0.01)
		# The corner's nearest witness is ambiguous, but its interior peak has
		# a clear downward connector. A vertical source at x=.01 would put that
		# connector along its own skin rather than provide an accessible target.
		moving.b = Vector2(0.01, 0.0102) if mode == "clean_point" else Vector2(0.009, 0.011)
		moving.location_bias.section_length_m = 0.001
		edges.append(moving)
	var source_before := var_to_bytes([section, edges])
	var input := _with_visibility({"valid": true, "guide_kind": &"saved_wrapper",
		"digit": &"middle", "palm_required": false, "section": section, "skin": {"segments": edges}},
		[Vector3(-0.02, 0.03, 0), Vector3(0.03, 0.03, 0), Vector3(0.03, -0.03, 0), Vector3(-0.02, -0.03, 0)])
	var sample: Dictionary = solver._wrapper_sample(input)
	_check(sample.get("valid", false), "raw wrapper production sample evaluates: " + mode)
	_check(sample.get("missing_target_sections", [1, 2, 3]).is_empty(), "raw wrapper fixture exposes all three section targets without crossing other skin: " + mode)
	_check(var_to_bytes([section, edges]) == source_before, "wrapper production leaves source polygons and skin unchanged: " + mode)
	return sample


func _required_selection_row(rows: Array, section: int) -> Dictionary:
	for row: Dictionary in rows:
		if row.required and row.section == section: return row
	return {}


func _projection_control_flow() -> void:
	var context := {"adapter": {"digit_inputs": {&"middle": {"snapshot": {
		"min_angles_rad": [-10.0, -10.0, -10.0], "max_angles_rad": [10.0, 10.0, 10.0]}}}}}
	for mode: String in ["derivative", "singular", "derivative_budget", "complete_away_from_peak"]:
		var solver := ProjectionFixture.new()
		solver.mode = mode
		solver.configure_contact_preference(TEST_STRENGTH)
		solver._metrics = {"projection_iterations": 0}
		solver.initial_sample = _sample(1, &"circle")
		solver.initial_sample.merge({"valid": true, "angles": {&"middle": [0.0, 0.0, 0.0]},
			"placement": Vector2.ZERO, "radius_m": 0.02})
		solver.trial_sample = solver.initial_sample.duplicate(true)
		_set_gap(solver.trial_sample, 0, Solver.CLEARANCE_M)
		_set_gap(solver.trial_sample, 1, 0.01002)
		_set_gap(solver.trial_sample, 2, Solver.CLEARANCE_M)
		_set_gap(solver.trial_sample, 3, Solver.CLEARANCE_M)
		_refresh_physical_rows(solver.trial_sample)
		solver.trial_sample.attached = true
		if mode == "complete_away_from_peak":
			var selection: Dictionary = solver._attraction_selection(solver.initial_sample)
			var before: Dictionary = solver._fixed_attraction_cost(solver.initial_sample, selection)
			var after: Dictionary = solver._fixed_attraction_cost(solver.trial_sample, selection)
			_check(before.valid and after.valid and after.cost > before.cost, "completion fixture worsens frozen preferred-point cost")
			_check(solver.trial_sample.rows[0].witness.skin_segment_t == 1.0, "completion fixture contacts away from S1 twenty-percent peak")
		var result: Dictionary = solver._project(context, {}, solver.initial_sample, 0.02, false, false)
		if mode == "derivative_budget":
			_check(not result.converged and result.reason == "projection_budget_not_physical_limit", "fallback does not invent convergence at budget exhaustion")
			_check(solver._metrics.projection_iterations == Solver.PROJECTION_ITERATIONS and solver.evaluations == Solver.PROJECTION_ITERATIONS,
				"forced failure consumes one of the existing forty iterations without another budget")
		else:
			_check(result.converged and result.sample.attached, mode + " accepts physically complete trial")
			_check(solver._metrics.projection_iterations == (1 if mode == "complete_away_from_peak" else 2), mode + " uses exactly the expected shared-budget iterations")
		if mode != "complete_away_from_peak":
			_check(solver.forced_failures == 1 and solver.differentiated_sources[0] == "preferred", mode + " starts with one failed preferred response")
			_check(solver.differentiated_sources.has("closer"), mode + " subsequently differentiates unrestricted nearest row")
			_check(solver.differentiated_sources.count("preferred") == 1, mode + " fallback latch prevents preferred-source cycling")


func _gripping_side_only() -> void:
	for kind: StringName in [&"circle", &"saved_wrapper"]:
		var sample := _sample(2, kind)
		# A perfect percentage with a nearer gap on the back must not compete.
		sample.skin.segments[1]["grip_attraction_eligible"] = false
		_set_gap(sample, 1, 0.00002)
		var selected: Dictionary = _solver._attraction_selection(sample)
		_check(selected.rows[0].segment.source_id == "closer", str(kind) + " dorsal peak cannot replace gripping-side attraction")
		var available: Array = _solver._section_attraction_candidates(sample, 2, true)
		_check(available.size() == 1 and available[0].segment.source_id == "closer", str(kind) + " dorsal edge excluded from all preference candidates")
		var fallback: Dictionary = _solver._attraction_selection(sample, false)
		_check(fallback.rows[0].segment.source_id == "closer", str(kind) + " original gripping-side row retained by fallback")
		_check(sample.skin.segments.size() == 4 and sample.records.size() == 4, str(kind) + " complete skin and collision records retained")


func _sample(section: int, kind: StringName, digit: StringName = &"middle", slot: StringName = &"hand_right") -> Dictionary:
	var origin := StringName(str(slot) + "/" + str(digit) + "/Plane")
	var edges: Array = [_edge("closer", section - 1, origin, 10), _edge("preferred", section - 1, origin, 20),
		_edge("palm", -1, origin, 30), _edge("blocker", -1, origin, 40)]
	# Separate synthetic source patches so contact ranking does not accidentally
	# ask a target connector to pass through a coincident different skin surface.
	for index: int in edges.size():
		edges[index].a.x += float(index) * 0.04
		edges[index].b.x += float(index) * 0.04
	edges[2]["palm_owned"] = true
	edges[2]["grip_attraction_eligible"] = true
	edges[2].max_inward_depth_m = 0.0025
	edges[3].allowance_unassigned = true
	edges[3].max_inward_depth_m = 0.0
	var gaps := [0.00052, 0.00102, 0.00032, 0.00042]
	var parameters := [1.0 if section == 1 else 0.0, PEAKS[section - 1], 0.5, 0.5]
	var records: Array = []
	var circle_records: Array = []
	for index: int in edges.size():
		var witness := {"signed_clearance_m": gaps[index], "skin_segment_t": parameters[index],
			"source_id": edges[index].source_id, "origin_id": origin,
			"tangent_ambiguous": false, "gradient_ambiguous": false}
		circle_records.append(witness)
		records.append({"segment": edges[index], "witness": witness, "guide_gap_m": gaps[index],
			"material_gap_m": gaps[index], "max_inward_depth_m": edges[index].max_inward_depth_m,
			"material_constraint_safe": true, "guide_constraint_safe": true})
	var sample := {"digit": digit, "slot": slot, "guide_kind": kind, "focus_section": section,
		"skin": {"segments": edges}, "records": records, "circle_records": circle_records,
		"material_safe": true, "guide_safe": true, "accepted_contact_constraints": true,
		"material_contacts": [], "material_condition_met": false, "attached": false,
		"regions": {section: {"material_contact": false}}, "constraint_blockers": [], "rows": [], "cost": 0.0}
	_refresh_physical_rows(sample)
	return sample


func _edge(id: String, owner: int, origin: StringName, first: int) -> Dictionary:
	var edge := {"source_id": id, "section_owner": owner, "origin_id": origin,
		"a": Vector2(0.0, 0.01), "b": Vector2(0.02, 0.01), "coplanar": false,
		"a_source": {"kind": "edge", "topology_key": "e:%d:%d" % [first, first + 1],
			"vertex_ids": PackedInt32Array([first, first + 1]), "t": 0.2, "topology_ambiguous": false},
		"b_source": {"kind": "edge", "topology_key": "e:%d:%d" % [first + 2, first + 3],
			"vertex_ids": PackedInt32Array([first + 2, first + 3]), "t": 0.8, "topology_ambiguous": false},
		"max_inward_depth_m": 0.0005, "allowance_unassigned": false,
		"grip_attraction_eligible": owner >= 0}
	if owner >= 0:
		edge["location_bias"] = {"a_percent": 0.0, "b_percent": 100.0,
			"section_length_m": LENGTH_M, "origin_id": origin}
	return edge


func _refresh_physical_rows(sample: Dictionary) -> void:
	for index: int in sample.records.size(): _sync_mock_witness(sample, index)
	_with_visibility(sample)
	var best := -1
	var palm := -1
	var blocker := -1
	for index: int in sample.records.size():
		var record: Dictionary = sample.records[index]
		if record.segment.section_owner == sample.focus_section - 1:
			if best < 0 or record.witness.signed_clearance_m < sample.records[best].witness.signed_clearance_m: best = index
		if record.segment.source_id == "palm": palm = index
		if record.segment.source_id == "blocker": blocker = index
	sample.rows = [_row(sample, best, sample.focus_section, true), _row(sample, palm, 0, true), _row(sample, blocker, -1, false)]
	sample.cost = pow(float(sample.rows[0].residual), 2.0) + _other_cost(sample)


func _row(sample: Dictionary, index: int, section: int, required: bool) -> Dictionary:
	var record: Dictionary = sample.records[index]
	var row := {"segment": record.segment, "witness": record.witness, "section": section,
		"required": required, "residual": float(record.witness.signed_clearance_m) - Solver.CLEARANCE_M}
	if sample.guide_kind == &"saved_wrapper": row.merge({"measurement_index": index, "metric": &"guide"})
	return row


func _set_gap(sample: Dictionary, index: int, gap: float) -> void:
	sample.records[index].witness.signed_clearance_m = gap
	sample.records[index].guide_gap_m = gap
	sample.circle_records[index].signed_clearance_m = gap
	_sync_mock_witness(sample, index)


## Scalar costs in _sample intentionally remain controlled response fixtures.
## Their geometric evidence is nevertheless real: each stated skin parameter
## lies on its current edge and its connector points toward the exposed side.
func _sync_mock_witness(sample: Dictionary, index: int) -> void:
	var edge: Dictionary = sample.records[index].segment
	for witness: Dictionary in [sample.records[index].witness, sample.circle_records[index]]:
		var point: Vector2 = (edge.a as Vector2).lerp(edge.b, float(witness.skin_segment_t))
		witness["skin_point_m"] = point
		witness["target_point_m"] = point + Vector2(0, -float(witness.signed_clearance_m))


func _with_visibility(sample: Dictionary, supplied_chain: Array = []) -> Dictionary:
	var origin: StringName = sample.skin.segments[0].origin_id
	sample.skin["valid"] = true
	sample.skin["plane_origin_id"] = origin
	var chain: Array = supplied_chain if not supplied_chain.is_empty() else [
		Vector3(0, 0.04, 0), Vector3(0.05, 0.04, 0), Vector3(0.10, 0.04, 0), Vector3(0.15, 0.04, 0)]
	var state := {"plane_origin_id":origin, "plane_to_world":Transform3D.IDENTITY,
		"joint_origins_world":[chain[0], chain[1], chain[2]], "tip_world":chain[3],
		"hand_origin_id":&"PreferenceVerifierHand", "hand_to_world":Transform3D(Basis.IDENTITY, Vector3(-0.05, 0.04, 0))}
	sample["visibility"] = Visibility.new().prepare(sample.skin, state)
	_check(sample.visibility.get("valid", false), "synthetic fixture supplies current named-plane skin and finite skeleton visibility evidence")
	return sample


func _other_cost(sample: Dictionary) -> float:
	return pow(float(sample.rows[1].residual), 2.0) + (64.0 if sample.guide_kind == &"saved_wrapper" else 4.0) * pow(float(sample.rows[2].residual), 2.0)


func _near(actual: float, expected: float, tolerance: float, label: String) -> void:
	_check(is_finite(actual) and absf(actual - expected) <= tolerance, label + ": " + str(actual))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error(label)
