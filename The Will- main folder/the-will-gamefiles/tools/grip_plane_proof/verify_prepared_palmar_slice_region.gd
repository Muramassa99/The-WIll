extends "res://tools/grip_plane_proof/run_circle_hand_process_proof.gd"

const PalmRegion = preload("res://tools/grip_plane_proof/prepared_palmar_slice_region.gd")
const PALM_TRACES := {
	"C:/WORKSPACE/test_artifacts/grip_placement_trace_hand_right_2026-09-18T02-30-57.bin": "dab0fbd68489e84ec1196c5a0acfb383a76a8eed099779e00a0f424c65529f89",
	"C:/WORKSPACE/test_artifacts/grip_placement_trace_hand_left_2026-09-18T02-31-08.bin": "c9765e43b465f5a529a07337bc2c9865d440612788960f162e7f40e5172311aa"}
var _palm_checks := 0
var _palm_failures: Array[String] = []
var _palm_cases: Array = []
var _palm := PalmRegion.new()


func _run() -> void:
	_test_core_fixtures()
	_test_source_boundary_roundoff()
	var loaded: Dictionary = Store.new().load_matching(OldInputs.DEFINITION_PATH, OldInputs.SIGNATURE, "rest_middle_thumb_surface_measurements_v1")
	if _palm_check(loaded.get("valid", false), "prepared anatomy loads"):
		var before := var_to_bytes(loaded.resource.reference_skin)
		for path: String in PALM_TRACES: _test_character(loaded.resource, path)
		_palm_check(var_to_bytes(loaded.resource.reference_skin) == before, "prepared anatomy remains unchanged")
	var report := {"schema": "verify_prepared_palmar_slice_region_v1", "ok": _palm_failures.is_empty(),
		"checks": _palm_checks, "failures": _palm_failures, "cases": _palm_cases,
		"complete_palm_partition_verified": false, "production_pose_written": false}
	var path := "C:/WORKSPACE/test_artifacts/verify_prepared_palmar_slice_region_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: push_error("Cannot write palm verifier"); quit(1); return
	file.store_string(JSON.stringify(_json(report), "\t")); file.close()
	print("PALMAR_REGION_RESULT=" + path)
	print("PALMAR_REGION_SUMMARY=" + JSON.stringify({"ok": report.ok, "checks": _palm_checks, "failures": _palm_failures}))
	quit(0 if report.ok else 1)


func _test_character(definition: Resource, path: String) -> void:
	if not _palm_check(FileAccess.get_sha256(path) == PALM_TRACES[path], "frozen source hash"): return
	var file := FileAccess.open(path, FileAccess.READ)
	if not _palm_check(file != null, "frozen source readable"): return
	var trace: Dictionary = file.get_var(false); file.close()
	var chosen: Dictionary = {}
	for transaction: Dictionary in trace.transactions:
		if transaction.slot == trace.slot and transaction.get("result", {}).get("applied", false) and not transaction.get("finger_inputs", []).is_empty(): chosen = transaction
	if not _palm_check(not chosen.is_empty(), "accepted frozen seat exists"): return
	var stage: Dictionary = chosen.finger_inputs[-1]
	var context: Dictionary = _prepare(definition, stage)
	if not _palm_check(context.get("valid", false), "character context prepares"): return
	var prepared: Dictionary = _palm.prepare(context, definition)
	if not _palm_check(prepared.get("valid", false), "palmar source prepares: " + str(prepared.get("reason", ""))): return
	_palm_check(prepared.accepted_face_count > 0, "real character has attributable core faces")
	_palm_check(not prepared.complete_palm_partition_verified and not prepared.solid_enclosure_verified, "incomplete coverage stays explicit")
	var case := {"slot": context.slot, "accepted_face_count": prepared.accepted_face_count,
		"candidate_face_count": prepared.candidate_face_count, "preparation_ms": prepared.preparation_ms,
		"rejected_face_counts": prepared.rejected_face_counts,
		"paired_core_accepted_sample_count": prepared.paired_core_accepted_sample_count, "slices": []}
	var palm_count := 0
	for trial: Array in [[0.0, 0.0], [0.4, 0.0], [0.0, 0.004], [0.4, -0.003]]:
		var fraction: float = trial[0]
		var offset: float = trial[1]
		var parameters: Array = context.open_parameters.duplicate()
		for index: int in range(6):
			var digit: StringName = DIGITS[index / 3]
			parameters[index] = lerpf(parameters[index], context.adapter.digit_inputs[digit].snapshot.preferred_angles_rad[index % 3], fraction)
		var shift: Vector3 = context.translation_u_world * offset - context.translation_v_world * offset * 0.5
		var candidate: Dictionary = _rigid_candidate(context, parameters, shift)
		if not _palm_check(candidate.get("valid", false), "candidate prepares"): continue
		for digit: StringName in DIGITS:
			var state: Dictionary = candidate.digit_states[digit]
			var observation: Dictionary = context.observations[digit].duplicate()
			observation.machine_to_world = candidate.pose_packet.machine_to_world
			var slice: Dictionary = _observer.slice_candidate(observation, candidate, state.plane_to_world, state.plane_origin_id)
			if not _palm_check(slice.get("valid", false), "original-weight skin slices"): continue
			var before := var_to_bytes(slice)
			var annotated: Dictionary = _palm.annotate(prepared, candidate, slice, state.plane_to_world)
			if not _palm_check(annotated.get("valid", false), "palm slice annotation: " + str(annotated.get("reason", ""))): continue
			var circle: Dictionary = _circle_query.evaluate(annotated.segments, Vector2.ZERO, 0.05, state.plane_origin_id, &"PalmVerifierCircle")
			_palm_check(circle.get("valid", false), "actual circle consumer accepts every fragment: " + str(circle.get("reason", "")))
			var depth_helper := Depth.new()
			var target: Dictionary = depth_helper.prepare_target(PackedVector2Array([Vector2(-0.03, -0.03), Vector2(0.03, -0.03), Vector2(0.03, 0.03), Vector2(-0.03, 0.03)]), state.plane_origin_id, &"PalmVerifierSquare", true)
			var depth: Dictionary = depth_helper.evaluate_segments(annotated.segments, target, state.plane_origin_id)
			_palm_check(depth.get("valid", false), "actual material depth consumer accepts every fragment: " + str(depth.get("reason", "")))
			_palm_check(before == var_to_bytes(slice), "annotation does not change supplied slice")
			var lengths := {}
			for index: int in range(annotated.segments.size()):
				var edge: Dictionary = annotated.segments[index]
				var old: Dictionary = slice.segments[edge.original_segment_index]
				var lower := float(edge.get("source_segment_t0", 0.0))
				var upper := float(edge.get("source_segment_t1", 1.0))
				lengths[edge.original_segment_index] = float(lengths.get(edge.original_segment_index, 0.0)) + upper - lower
				_palm_check((edge.a as Vector2).distance_to((old.a as Vector2).lerp(old.b, lower)) < 0.0000001 and (edge.b as Vector2).distance_to((old.a as Vector2).lerp(old.b, upper)) < 0.0000001 and edge.section_owner == old.section_owner and edge.source_id == old.source_id, "fragment geometry and source identity preserved")
				if edge.section_owner >= 0:
					_palm_check(index in annotated.owned[edge.section_owner], "digit ownership indices refreshed")
				if edge.get("palm_owned", false):
					_palm_check(old.section_owner == -1 and edge.section_id == &"palm" and edge.max_inward_depth_m == 0.0025 and not edge.allowance_unassigned, "palm gets user policy only on unowned core")
					_palm_check(edge.palmar_source_vertex_contributors.size() == 3 and edge.palmar_reference_origin_id == prepared.reference_frame_origin_id, "exact contributor and named reference provenance retained")
				else:
					_palm_check(edge.max_inward_depth_m == old.max_inward_depth_m and edge.allowance_unassigned == old.allowance_unassigned, "outside core keeps exact previous policy")
			_palm_check(lengths.size() == slice.segments.size(), "all source edges retained")
			for coverage: float in lengths.values(): _palm_check(absf(coverage - 1.0) < 0.0000001, "fragments exactly cover original edge without loss or overlap")
			palm_count += annotated.palm_owned.size()
			case.slices.append({"digit": digit, "fraction": fraction, "offset": offset, "palm_edges": annotated.palm_owned.size(), "unassigned_edges": annotated.unassigned_segment_count})
			var broken := slice.duplicate(true)
			broken.pose_id = &"WrongPose"
			_palm_check(not _palm.annotate(prepared, candidate, broken, state.plane_to_world).get("valid", false), "wrong pose rejected")
			broken = slice.duplicate(true)
			broken.plane_origin_id = &"MissingPlane"
			_palm_check(not _palm.annotate(prepared, candidate, broken, state.plane_to_world).get("valid", false), "missing origin rejected")
			if not annotated.palm_owned.is_empty():
				broken = slice.duplicate(true)
				broken.segments[annotated.segments[annotated.palm_owned[0]].original_segment_index].a += Vector2(0.05, 0.07)
				_palm_check(not _palm.annotate(prepared, candidate, broken, state.plane_to_world).get("valid", false), "forged source geometry rejected")
	_palm_check(palm_count > 0, "current diagnostic planes have usable palm coverage")
	_palm_cases.append(case)


func _test_core_fixtures() -> void:
	var footprint := PackedVector2Array([Vector2(0, 0), Vector2(0.1, 0), Vector2(0, 0.1)])
	var front := PackedVector3Array([Vector3(0.01, 0.01, 0.01), Vector3(0.03, 0.01, 0.01), Vector3(0.01, 0.03, 0.01)])
	var fixture := _fixture_core(front, PackedFloat64Array([1, 1, 1]), footprint)
	_palm_check(fixture.valid and fixture.faces.has("0/0"), "front core face accepted")
	var back := front.duplicate()
	for index: int in range(back.size()): back[index].z = -0.01
	_palm_check(_fixture_core(back, PackedFloat64Array([1, 1, 1]), footprint).faces.is_empty(), "Hand-weighted dorsal face rejected geometrically")
	_palm_check(_fixture_core(front, PackedFloat64Array([0.4, 0.4, 0.4]), footprint).faces.has("0/0"), "mixed Hand 0.4 plus Thumb 0.6 palmar core accepted geometrically")
	_palm_check(_fixture_core(front, PackedFloat64Array([0.4, 0.4, 0.4]), footprint, 0.1).faces.is_empty(), "forearm contributors prevent palm policy")
	_palm_check(_fixture_core(front, PackedFloat64Array([0, 0, 0]), footprint).faces.is_empty(), "missing Hand contributor rejected")
	var outside := front.duplicate(); outside[0].x = -0.01
	var clipped := _fixture_core(outside, PackedFloat64Array([1, 1, 1]), footprint)
	_palm_check(clipped.faces.has("0/0") and not clipped.faces["0/0"].whole_source_face_verified, "boundary-crossing face clipped instead of granting whole face")
	if clipped.faces.has("0/0"):
		var plane := Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.01))
		var edge := {"a": Vector2(-0.01, 0.01), "b": Vector2(0.03, 0.01), "section_owner": -1, "source_id": "0/0"}
		var split := _palm._fragment_edge(edge, clipped.faces["0/0"], outside, plane)
		_palm_check(split.get("valid", false) and split.fragments.size() == 2 and not split.fragments[0].palm_owned and split.fragments[1].palm_owned, "edge divided at geometric footprint boundary")
	var occluded := front.duplicate()
	var near := front.duplicate()
	for index: int in range(near.size()): near[index].z = 0.005
	occluded.append_array(near)
	fixture = _fixture_core(occluded, PackedFloat64Array([1, 1, 1, 0, 0, 0]), footprint)
	_palm_check(fixture.faces.is_empty(), "nearer surface blocks hidden Hand-weighted face even without Hand weights")
	var partial := front.duplicate()
	partial.append_array(PackedVector3Array([Vector3(0.014, 0.014, 0.005), Vector3(0.018, 0.014, 0.005), Vector3(0.014, 0.018, 0.005)]))
	fixture = _fixture_core(partial, PackedFloat64Array([1, 1, 1, 0, 0, 0]), footprint)
	_palm_check(fixture.faces.has("0/0") and not fixture.faces["0/0"].occluders_m.is_empty(), "small interior occluder masks only hidden source region")


func _fixture_core(points: PackedVector3Array, weights: PackedFloat64Array, footprint: PackedVector2Array, foreign_weight: float = 0.0) -> Dictionary:
	var indices := PackedInt32Array()
	var surfaces := PackedInt32Array()
	var locals := PackedInt32Array()
	var totals := PackedFloat64Array()
	var foreign := PackedFloat64Array()
	var contributors: Array = []
	for index: int in range(points.size()):
		indices.append(index); totals.append(1.0)
		foreign.append(foreign_weight)
		contributors.append({&"FixtureHand": weights[index], &"FixtureThumb": 1.0 - weights[index] - foreign_weight, &"FixtureForearm": foreign_weight})
		if index % 3 == 0: surfaces.append(0); locals.append(index / 3)
	return _palm._compile(points, indices, surfaces, locals, weights, totals, footprint, foreign, contributors)


func _test_source_boundary_roundoff() -> void:
	# Synthetic palm-reference metres. The named fixture plane is translated
	# from the fixture root; it does not author or alter a character pose.
	var plane := Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.01))
	var polygon := PackedVector2Array([Vector2.ZERO, Vector2(0.1, 0), Vector2(0, 0.1)])
	var vertices := PackedVector3Array([plane * Vector3.ZERO, plane * Vector3(0.1, 0, 0), plane * Vector3(0, 0.1, 0)])
	var face := {"vertex_indices": [0, 1, 2], "reference_polygon_m": polygon,
		"domains_m": [polygon], "occluders_m": [], "source_vertex_contributors": [{&"FixtureHand": 0.4, &"FixtureThumb": 0.6}]}
	var edge := {"a": Vector2(-0.000000025, 0.02), "b": Vector2(0.045, 0.055000025),
		"section_owner": -1, "source_id": "0/0", "origin_id": &"PalmRoundoffFixturePlane",
		"allowance_unassigned": true, "max_inward_depth_m": 0.0005,
		"a_selected_weights": Vector3(0.1, 0.2, 0.3), "b_selected_weights": Vector3(0.2, 0.3, 0.4)}
	var before := var_to_bytes([edge, face, vertices])
	var split: Dictionary = _palm._fragment_edge(edge, face, vertices, plane)
	_palm_check(split.get("valid", false) and split.get("fragments", []).size() == 1 and split.fragments[0].palm_owned, "nanometre source-boundary roundoff does not manufacture unassigned slivers")
	if split.get("valid", false):
		_palm_check(split.fragments[0].a == edge.a and split.fragments[-1].b == edge.b, "source-boundary correction never moves supplied skin endpoints")
		_palm_check(split.fragments[0].a_selected_weights == edge.a_selected_weights and split.fragments[-1].b_selected_weights == edge.b_selected_weights, "source-boundary correction preserves original bone interpolation weights")
		_palm_check(split.fragments[0].source_segment_t0 == 0.0 and split.fragments[-1].source_segment_t1 == 1.0, "source-boundary correction covers the entire original edge")
	_palm_check(var_to_bytes([edge, face, vertices]) == before, "source-boundary correction leaves caller geometry and original bone contributors unchanged")
	for point: Vector2 in [edge.a, edge.b]:
		var world := plane * Vector3(point.x, point.y, 0)
		var bary: Vector3 = _palm._source_barycentric(world, face, vertices)
		_palm_check(bary.is_finite() and minf(bary.x, minf(bary.y, bary.z)) >= 0.0, "roundoff barycentrics remain inside original source simplex")
		_palm_check((vertices[0] * bary.x + vertices[1] * bary.y + vertices[2] * bary.z).distance_to(world) <= PalmRegion.EPSILON_M, "source reconstruction correction stays within existing numerical epsilon")
	var reversed_face := face.duplicate(true)
	var reversed := polygon.duplicate(); reversed.reverse()
	reversed_face.domains_m = [reversed]
	var reversed_split: Dictionary = _palm._fragment_edge(edge, reversed_face, vertices, plane)
	_palm_check(reversed_split.get("valid", false) and reversed_split.fragments.size() == 1 and reversed_split.fragments[0].palm_owned, "source-boundary correction is independent of domain winding")
	# Real footprint cuts and occlusion boundaries are not source-simplex
	# roundoff, even when a real outside interval is smaller than epsilon.
	var clipped_face := face.duplicate(true)
	clipped_face.domains_m = [PackedVector2Array([Vector2(0.02, 0), Vector2(0.1, 0), Vector2(0.02, 0.08)])]
	var clipped_edge := edge.duplicate(true)
	clipped_edge.a = Vector2(0.019999975, 0.01); clipped_edge.b = Vector2(0.04, 0.01)
	var clipped_split: Dictionary = _palm._fragment_edge(clipped_edge, clipped_face, vertices, plane)
	_palm_check(clipped_split.get("valid", false) and clipped_split.fragments.size() == 2 and not clipped_split.fragments[0].palm_owned and clipped_split.fragments[1].palm_owned, "genuine sub-epsilon footprint exclusion retains unassigned skin")
	var hidden_face := face.duplicate(true)
	hidden_face.occluders_m = [PackedVector2Array([Vector2(0.02, 0), Vector2(0.1, 0), Vector2(0.02, 0.08)])]
	var hidden_split: Dictionary = _palm._fragment_edge(clipped_edge, hidden_face, vertices, plane)
	_palm_check(hidden_split.get("valid", false) and hidden_split.fragments.size() == 2 and hidden_split.fragments[0].palm_owned and not hidden_split.fragments[1].palm_owned, "occluder exclusion stays strict at numerical-scale intervals")
	var outside := edge.duplicate(true)
	outside.a = Vector2(-0.000001, 0.02); outside.b = Vector2(0.04, 0.02)
	var outside_split: Dictionary = _palm._fragment_edge(outside, face, vertices, plane)
	_palm_check(outside_split.get("valid", false) and outside_split.fragments.size() == 2 and not outside_split.fragments[0].palm_owned, "outside-source displacement exceeding numerical epsilon remains unassigned")
	outside.a = Vector2(-0.001, 0.02)
	_palm_check(not _palm._fragment_edge(outside, face, vertices, plane).get("valid", false), "forged geometry beyond original source reconstruction tolerance still fails")
	_palm_cases.append({"case": "source_boundary_roundoff", "numeric_epsilon_m": PalmRegion.EPSILON_M,
		"skin_coordinates_changed": false, "bone_weights_normalized": false,
		"genuine_footprint_and_occluder_exclusions_preserved": true})


func _palm_check(value: bool, label: String) -> bool:
	_palm_checks += 1
	if not value: _palm_failures.append(label)
	return value
