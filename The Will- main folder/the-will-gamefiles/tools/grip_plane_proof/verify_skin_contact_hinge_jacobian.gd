extends "res://tools/grip_plane_proof/run_contact_driven_preparation.gd"

## Independent perturbation oracle: regenerate complete blended skin, reslice
## its original triangle, then remeasure its sliding nearest point. Production
## Jacobian uses no finite differences. This verifier changes no saved inputs.
const Jacobian = preload("res://runtime/player/grip/skin_contact_hinge_jacobian.gd")
const Observer = preload("res://runtime/player/grip/prepared_grip_slice_contact.gd")
const Circle = preload("res://runtime/player/grip/planar_circle_skin_contact.gd")
const PalmarRegion = preload("res://runtime/player/grip/prepared_palmar_slice_region.gd")
const STEP_RAD: float = 0.001
const ABSOLUTE_TOLERANCE_M_PER_RAD: float = 0.001
const RELATIVE_TOLERANCE: float = 0.025
const TEST_DIGITS: Array[StringName] = [&"middle", &"thumb"]
var _jacobian := Jacobian.new()
var _observer := Observer.new()
var _circle := Circle.new()
var _comparisons: int = 0
var _skipped: Array = []
var _covered: Dictionary = {}
var _palmar_comparisons: int = 0
var _moving_palmar_derivatives: int = 0
var _point_comparisons: int = 0


func _run() -> void:
	_started = Time.get_ticks_usec()
	_prefix = "C:/WORKSPACE/test_artifacts/skin_contact_hinge_jacobian_" + Time.get_datetime_string_from_system().replace(":", "-")
	for path: String in TRACES:
		await _case(path, null, {})
	for side: String in ["hand_right", "hand_left"]:
		for section: int in [1, 2, 3]:
			_check(_covered.has(side + "/middle/S" + str(section)), side + " Middle S" + str(section) + " has verified derivatives")
		for section: int in [2, 3]:
			_check(_covered.has(side + "/thumb/S" + str(section)), side + " Thumb S" + str(section) + " has verified derivatives")
	_check(_comparisons > 0, "independent perturbation comparisons executed")
	_check(_palmar_comparisons > 0, "clipped palmar fragment perturbations executed")
	_check(_moving_palmar_derivatives > 0, "clipped shared skin has nonzero independently checked hinge motion")
	_check(_point_comparisons > 0, "noncircle fixed skin-segment parameter comparisons executed")
	_finish()


func _case(path: String, _unused_wip: Resource, _unused_packet: Dictionary) -> void:
	if not _check(FileAccess.get_sha256(path) == TRACES[path], "frozen hand source hash"):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var raw: Variant = file.get_var(false)
	file.close()
	if not _check(raw is Dictionary and raw.get("valid", false) and raw.get("validation", {}).get("valid", false), "validated frozen capture"):
		return
	var source: Dictionary = {}
	for transaction: Dictionary in raw.transactions:
		if transaction.slot == raw.slot and transaction.get("result", {}).get("applied", false) and not transaction.get("finger_inputs", []).is_empty():
			source = transaction.finger_inputs[-1]
	if not _check(not source.is_empty(), "captured pose source exists"): return
	var immutable_source: PackedByteArray = var_to_bytes(source.posed_character)
	var adapter: Dictionary = Candidate.new().prepare(Config.anatomy, source.posed_character, source.slot, TEST_DIGITS)
	if not _check(adapter.get("valid", false), "prepared actual anatomy: " + str(adapter.get("reason", ""))): return
	var prepared: Dictionary = {}
	var observations: Dictionary = {}
	var palm_region: Dictionary = PalmarRegion.new().prepare({"adapter":adapter,"slot":source.slot},Config.anatomy)
	if not _check(palm_region.get("valid",false),"prepared source palmar region"): return
	for digit: StringName in TEST_DIGITS:
		prepared[digit] = _jacobian.prepare(adapter, digit, palm_region)
		observations[digit] = _observer.prepare(adapter, digit)
		if not _check(prepared[digit].get("valid", false) and observations[digit].get("valid", false), "prepared Jacobian and observer " + str(digit)):
			return
	for pose_fraction: float in [0.0, 0.2, 0.5]:
		var angles: Dictionary = {}
		for digit: StringName in TEST_DIGITS:
			var values: Array = []
			var snapshot: Dictionary = adapter.digit_inputs[digit].snapshot
			for hinge: int in 3:
				var open: float = clampf(0.0, snapshot.min_angles_rad[hinge], snapshot.max_angles_rad[hinge])
				var inner: float = lerpf(snapshot.min_angles_rad[hinge], snapshot.max_angles_rad[hinge], pose_fraction)
				values.append(open if pose_fraction == 0.0 else inner)
			angles[digit] = values
		var candidate: Dictionary = Candidate.new().evaluate(adapter, angles, Vector3.ZERO, ROOT)
		if not _check(candidate.get("valid", false), "legal coherent test pose"): continue
		var immutable_candidate: PackedByteArray = var_to_bytes(candidate)
		for digit: StringName in TEST_DIGITS:
			var state: Dictionary = candidate.digit_states[digit]
			var slice: Dictionary = _observer.slice_candidate(observations[digit], candidate, state.plane_to_world, state.plane_origin_id)
			if not _check(slice.get("valid", false), "actual skin slice " + str(digit)): continue
			for section: int in 3:
				var measured: Dictionary = _choose_stable_edge(prepared[digit], candidate, slice, section)
				if measured.is_empty():
					_skipped.append({"slot":source.slot, "digit":digit, "section":section + 1, "pose_fraction":pose_fraction,
						"reason":"no_owned_smooth_triangle_cut_for_independent_comparison", "owned_edges":slice.owned[section].size()})
					continue
				var analytic: Dictionary = measured.analytic
				var record := {"slot":source.slot, "digit":digit, "section":section + 1, "pose_fraction":pose_fraction,
					"source_id":measured.edge.source_id, "origin_id":state.plane_origin_id,
					"skin_edge_length_m":(measured.edge.a as Vector2).distance_to(measured.edge.b),
					"smooth_triangle_cut_branch":analytic.smooth_triangle_cut_branch, "hinges":[]}
				var covered := false
				for hinge: int in 3:
					var comparison: Dictionary = _compare_hinge(adapter, observations[digit], candidate, angles, digit, hinge, measured)
					record.hinges.append(comparison)
					if not comparison.get("valid", false):
						_skipped.append({"slot":source.slot,"digit":digit,"section":section + 1,"hinge":hinge,
							"pose_fraction":pose_fraction,"reason":comparison.get("reason", "unknown_comparison_failure")})
						continue
					_comparisons += 1
					covered = true
					_check(comparison.point_error_m_per_rad <= comparison.tolerance_m_per_rad,
						"point derivative " + str(source.slot) + "/" + str(digit) + "/S" + str(section + 1) + "/J" + str(hinge + 1) + " pose=" + str(pose_fraction))
					_check(comparison.clearance_error_m_per_rad <= comparison.tolerance_m_per_rad,
						"clearance derivative " + str(source.slot) + "/" + str(digit) + "/S" + str(section + 1) + "/J" + str(hinge + 1) + " pose=" + str(pose_fraction))
				if covered: _covered[str(source.slot) + "/" + str(digit) + "/S" + str(section + 1)] = true
				_cases.append(record)
				_verify_fixed_point(adapter,observations[digit],prepared[digit],candidate,angles,digit,measured,0.37,
					{"slot":source.slot,"digit":digit,"section":section+1,"pose_fraction":pose_fraction})
				var bad_origin: Dictionary = measured.edge.duplicate(true)
				bad_origin.erase("origin_id")
				_check(not _jacobian.evaluate(prepared[digit], candidate, bad_origin, measured.witness).get("valid", true), "missing contact origin rejected")
				var bad_source: Dictionary = measured.witness.duplicate(true)
				bad_source.source_id = "invalid/source"
				_check(not _jacobian.evaluate(prepared[digit], candidate, measured.edge, bad_source).get("valid", true), "mismatched contact source rejected")
		_verify_palmar(source.slot,adapter,prepared,observations,candidate,angles,palm_region,pose_fraction)
		_check(var_to_bytes(candidate) == immutable_candidate, "original candidate remains immutable")
		await process_frame
	_check(var_to_bytes(source.posed_character) == immutable_source, "original captured pose remains immutable")
	_check(FileAccess.get_sha256(path) == TRACES[path], "frozen hand file unchanged")


func _choose_stable_edge(prepared: Dictionary, candidate: Dictionary, slice: Dictionary, section: int) -> Dictionary:
	var edges: Array = []
	for index: int in slice.owned[section]: edges.append(slice.segments[index])
	edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.b as Vector2).distance_squared_to(a.a) > (b.b as Vector2).distance_squared_to(b.a))
	for edge: Dictionary in edges:
		var direction: Vector2 = (edge.b as Vector2) - (edge.a as Vector2)
		if direction.length() < 0.0001: continue
		var normal := Vector2(-direction.y, direction.x).normalized()
		var center: Vector2 = ((edge.a as Vector2) + (edge.b as Vector2)) * 0.5 + normal * 0.05
		var measured: Dictionary = _circle.evaluate([edge], center, 0.04, edge.origin_id, &"JacobianVerificationCircle")
		if not measured.get("valid", false): continue
		var witness: Dictionary = measured.segments[0]
		var analytic: Dictionary = _jacobian.evaluate(prepared, candidate, edge, witness)
		if not analytic.get("valid", false) or not analytic.smooth_triangle_cut_branch: continue
		return {"edge":edge, "center_m":center, "radius_m":0.04, "witness":witness, "analytic":analytic}
	return {}


func _compare_hinge(adapter: Dictionary, observation: Dictionary, candidate: Dictionary, angles: Dictionary, digit: StringName, hinge: int, measured: Dictionary) -> Dictionary:
	var snapshot: Dictionary = adapter.digit_inputs[digit].snapshot
	var angle: float = angles[digit][hinge]
	var minus_step: float = minf(STEP_RAD, angle - float(snapshot.min_angles_rad[hinge]))
	var plus_step: float = minf(STEP_RAD, float(snapshot.max_angles_rad[hinge]) - angle)
	if minus_step < STEP_RAD * 0.5: minus_step = 0.0
	if plus_step < STEP_RAD * 0.5: plus_step = 0.0
	if minus_step == 0.0 and plus_step == 0.0: return {"valid":false,"reason":"hinge_range_too_small_for_independent_perturbation"}
	var samples: Array = []
	for step: float in [-minus_step, plus_step]:
		if step == 0.0:
			samples.append(measured.witness)
			continue
		var trial_angles: Dictionary = angles.duplicate(true)
		trial_angles[digit][hinge] = angle + step
		var trial: Dictionary = Candidate.new().evaluate(adapter, trial_angles, Vector3.ZERO, ROOT)
		if not trial.get("valid", false): return {"valid":false,"reason":"perturbed_candidate_invalid"}
		var state: Dictionary = trial.digit_states[digit]
		var slice: Dictionary = _observer.slice_candidate(observation, trial, state.plane_to_world, state.plane_origin_id)
		if not slice.get("valid", false): return {"valid":false,"reason":"perturbed_slice_invalid"}
		if measured.get("palmar_fragment",false):
			slice = PalmarRegion.new().annotate(measured.palm_region,trial,slice,state.plane_to_world)
			if not slice.get("valid",false): return {"valid":false,"reason":"perturbed_palmar_annotation_invalid"}
		var source_edges: Array = []
		for edge: Dictionary in slice.segments:
			if edge.source_id == measured.edge.source_id and (not measured.get("palmar_fragment",false) or edge.get("palm_owned",false) == measured.edge.get("palm_owned",false)):
				source_edges.append(edge)
		if measured.get("palmar_fragment",false) and source_edges.size()>1:
			var midpoint: Vector2 = (measured.edge.a+measured.edge.b)*0.5
			source_edges.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return ((a.a+a.b)*0.5 as Vector2).distance_squared_to(midpoint)<((b.a+b.b)*0.5 as Vector2).distance_squared_to(midpoint))
			source_edges=[source_edges[0]]
		if source_edges.size() != 1: return {"valid":false,"reason":"source_triangle_cut_topology_changed"}
		var witness: Dictionary
		if measured.get("point_mode",false):
			var point_edge: Dictionary = source_edges[0]
			witness={"skin_point_m":(point_edge.a as Vector2).lerp(point_edge.b,measured.witness.skin_segment_t),"signed_clearance_m":0.0}
		else:
			var sample: Dictionary = _circle.evaluate(source_edges, measured.center_m, measured.radius_m, state.plane_origin_id, &"JacobianVerificationCircle")
			if not sample.get("valid", false): return {"valid":false,"reason":"perturbed_circle_measurement_invalid"}
			witness = sample.segments[0]
			var original_t: float = measured.witness.skin_segment_t
			if (original_t>0.0 and original_t<1.0 and (witness.skin_segment_t<=0.0 or witness.skin_segment_t>=1.0)) or (original_t==0.0 and witness.skin_segment_t!=0.0) or (original_t==1.0 and witness.skin_segment_t!=1.0):
				return {"valid":false,"reason":"nearest_point_branch_changed"}
		samples.append(witness)
	var interval: float = minus_step + plus_step
	var point_derivative: Vector2 = ((samples[1].skin_point_m as Vector2) - (samples[0].skin_point_m as Vector2)) / interval
	var clearance_derivative: float = (float(samples[1].signed_clearance_m) - float(samples[0].signed_clearance_m)) / interval
	var analytic_point: Vector2 = measured.analytic.derivatives_m_per_rad[hinge]
	var analytic_clearance: float = 0.0 if measured.get("point_mode",false) else measured.analytic.clearance_derivatives_m_per_rad[hinge]
	var tolerance: float = maxf(ABSOLUTE_TOLERANCE_M_PER_RAD, analytic_point.length() * RELATIVE_TOLERANCE)
	return {"valid":true,"hinge":hinge + 1,"hinge_origin_id":snapshot.bone_names[hinge],
		"plane_origin_id":candidate.digit_states[digit].plane_origin_id,
		"method":"central" if minus_step > 0.0 and plus_step > 0.0 else "one_sided_at_range_endpoint",
		"minus_step_rad":minus_step,"plus_step_rad":plus_step,
		"analytic_point_m_per_rad":analytic_point,"observed_point_m_per_rad":point_derivative,
		"analytic_clearance_m_per_rad":analytic_clearance,"observed_clearance_m_per_rad":clearance_derivative,
		"point_error_m_per_rad":analytic_point.distance_to(point_derivative),
		"clearance_error_m_per_rad":absf(analytic_clearance - clearance_derivative),"tolerance_m_per_rad":tolerance}


func _verify_palmar(slot: StringName,adapter: Dictionary,prepared: Dictionary,observations: Dictionary,candidate: Dictionary,
		angles: Dictionary,palm_region: Dictionary,pose_fraction: float) -> void:
	for digit: StringName in TEST_DIGITS:
		var state: Dictionary = candidate.digit_states[digit]
		var raw: Dictionary = _observer.slice_candidate(observations[digit],candidate,state.plane_to_world,state.plane_origin_id)
		if not raw.get("valid",false): continue
		var annotated: Dictionary = PalmarRegion.new().annotate(palm_region,candidate,raw,state.plane_to_world)
		if not _check(annotated.get("valid",false),"actual palmar fragment annotation"): continue
		var selected: Dictionary = {}
		var best_motion: float = -1.0
		var rejected: Dictionary = {}
		for edge: Dictionary in annotated.segments:
			if not edge.get("palm_owned",false): continue
			var endpoint: String = ""
			if float(edge.get("source_segment_t0",0.0))>0.0 and float(edge.get("source_segment_t0",0.0))<1.0: endpoint="a"
			elif float(edge.get("source_segment_t1",1.0))>0.0 and float(edge.get("source_segment_t1",1.0))<1.0: endpoint="b"
			if endpoint.is_empty(): continue
			var direction: Vector2 = (edge.b as Vector2)-(edge.a as Vector2)
			if direction.length()<0.00001: continue
			direction=direction.normalized()
			var normal:=Vector2(-direction.y,direction.x)
			# Put the closest point ON the clipped endpoint. Interior tangency
			# alone could cancel the clipping-ratio derivative and miss this bug.
			var center: Vector2 = edge[endpoint]+direction*(0.015 if endpoint=="b" else -0.015)+normal*0.02
			var measured: Dictionary = _circle.evaluate([edge],center,0.015,state.plane_origin_id,&"JacobianVerificationCircle")
			if not measured.get("valid",false): continue
			var witness: Dictionary = measured.segments[0]
			var analytic: Dictionary = _jacobian.evaluate(prepared[digit],candidate,edge,witness)
			if not analytic.get("valid",false):
				var reason: String = str(analytic.get("reason","unknown"))
				rejected[reason]=int(rejected.get(reason,0))+1
				continue
			var motion:=0.0
			for derivative: Vector2 in analytic.derivatives_m_per_rad: motion+=derivative.length()
			if motion>best_motion:
				best_motion=motion
				selected={"edge":edge,"center_m":center,"radius_m":0.015,"witness":witness,"analytic":analytic,
					"palmar_fragment":true,"palm_region":palm_region,"clipped_endpoint":endpoint}
		if selected.is_empty():
			_skipped.append({"slot":slot,"digit":digit,"pose_fraction":pose_fraction,
				"reason":"no_differentiable_actual_clipped_palm_fragment","rejected":rejected})
			continue
		var record: Dictionary = {"slot":slot,"digit":digit,"section":"palm_fragment","pose_fraction":pose_fraction,
			"source_id":selected.edge.source_id,"origin_id":state.plane_origin_id,"endpoint":selected.clipped_endpoint,
			"source_segment_t0":selected.edge.source_segment_t0,"source_segment_t1":selected.edge.source_segment_t1,
			"analytic_motion_sum_m_per_rad":best_motion,"hinges":[],"rejected_alternatives":rejected}
		for hinge: int in 3:
			var comparison: Dictionary = _compare_hinge(adapter,observations[digit],candidate,angles,digit,hinge,selected)
			record.hinges.append(comparison)
			if not comparison.get("valid",false): continue
			_palmar_comparisons+=1
			_moving_palmar_derivatives+=int((comparison.analytic_point_m_per_rad as Vector2).length()>0.0001)
			_check(comparison.point_error_m_per_rad<=comparison.tolerance_m_per_rad,"clipped palm point derivative "+str(slot)+"/"+str(digit)+"/J"+str(hinge+1))
			_check(comparison.clearance_error_m_per_rad<=comparison.tolerance_m_per_rad,"clipped palm clearance derivative "+str(slot)+"/"+str(digit)+"/J"+str(hinge+1))
		_cases.append(record)
		_verify_fixed_point(adapter,observations[digit],prepared[digit],candidate,angles,digit,selected,
			selected.witness.skin_segment_t,{"slot":slot,"digit":digit,"section":"clipped_palm","pose_fraction":pose_fraction})


func _verify_fixed_point(adapter: Dictionary,observation: Dictionary,prepared: Dictionary,candidate: Dictionary,
		angles: Dictionary,digit: StringName,source_measurement: Dictionary,t: float,description: Dictionary) -> void:
	var edge: Dictionary = source_measurement.edge
	var analytic: Dictionary = _jacobian.evaluate_point(prepared,candidate,edge,t)
	if not _check(analytic.get("valid",false),"generic point Jacobian prepared without circle fields"): return
	_check(not analytic.nearest_point_sliding_derivative_included,"generic point derivative excludes nearest-point traversal")
	var measured: Dictionary = source_measurement.duplicate(false)
	measured["point_mode"]=true
	measured["analytic"]=analytic
	measured["witness"]={"skin_segment_t":t,"skin_point_m":(edge.a as Vector2).lerp(edge.b,t),"signed_clearance_m":0.0}
	var record: Dictionary = description.duplicate(true)
	record["case_kind"]="noncircle_point_at_fixed_slice_segment_parameter"
	record["source_id"]=edge.source_id
	record["origin_id"]=edge.origin_id
	record["skin_segment_t"]=t
	record["hinges"]=[]
	for hinge: int in 3:
		var comparison: Dictionary = _compare_hinge(adapter,observation,candidate,angles,digit,hinge,measured)
		record.hinges.append(comparison)
		if not comparison.get("valid",false): continue
		_point_comparisons+=1
		_check(comparison.point_error_m_per_rad<=comparison.tolerance_m_per_rad,
			"generic fixed-parameter point derivative "+str(description.slot)+"/"+str(digit)+"/"+str(description.section)+"/J"+str(hinge+1))
	var unnamed: Dictionary = edge.duplicate(true)
	unnamed.erase("origin_id")
	_check(not _jacobian.evaluate_point(prepared,candidate,unnamed,t).get("valid",true),"generic point rejects missing plane origin")
	_check(not _jacobian.evaluate_point(prepared,candidate,edge,-0.1).get("valid",true),"generic point rejects invalid segment parameter")
	_cases.append(record)


func _finish() -> void:
	var report := {"schema":"skin_contact_hinge_jacobian_verification_v1","checks":_checks,"failures":_failures,
		"comparisons":_comparisons,"covered_sections":_covered.keys(),"cases":_cases,"skipped":_skipped,
		"palmar_comparisons":_palmar_comparisons,"moving_palmar_derivatives":_moving_palmar_derivatives,
		"noncircle_point_comparisons":_point_comparisons,
		"finite_difference_step_rad":STEP_RAD,"absolute_tolerance_m_per_rad":ABSOLUTE_TOLERANCE_M_PER_RAD,
		"relative_tolerance":RELATIVE_TOLERANCE,"total_ms":float(Time.get_ticks_usec() - _started) / 1000.0,
		"scope":"local analytic derivative against independent complete skin/FK/reslice measurements; not grip or continuous-contact acceptance",
		"production_pose_written":false}
	var file := FileAccess.open(_prefix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(_json(report), "\t"))
	file.close()
	print("SKIN_JACOBIAN_REPORT=", _prefix + ".json")
	print("SKIN_JACOBIAN: ", "PASS" if _failures.is_empty() else "FAIL", " checks=", _checks, " comparisons=", _comparisons)
	quit(0 if _failures.is_empty() else 1)
