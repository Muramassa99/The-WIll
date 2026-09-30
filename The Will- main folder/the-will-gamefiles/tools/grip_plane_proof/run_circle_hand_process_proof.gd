extends "res://tools/grip_plane_proof/run_shared_hand_closure_proof.gd"

## Isolated first, circular phase: outside placement, sliding contact and gradual
## radius reduction. A circle stops at the actual object's outer extent; the
## later noncircular membrane phase is deliberately not substituted for a circle.
const CircleQuery = preload("res://tools/grip_plane_proof/planar_circle_skin_contact.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const START_RADIUS_M: float = 0.05
const CLEARANCE_M: float = 0.00002
const NUMERIC_GUARD_M: float = 0.000002
const MAX_OFFSET_M: float = 0.25
var _circle_query := CircleQuery.new()
var _circle_cache: Dictionary = {}
var _circle_evaluations: int = 0
var _process_frames: Array = []
var _rejected_path_count: int = 0
var _last_settle_path: Array = []
var _accepted_path: Array = []

func _report_extensions() -> Dictionary:
	return {"schema": "circle_hand_process_proof_v1", "start_radius_m": START_RADIUS_M,
		"scope": "two_independent_digit_plane_circles_one_shared_hand_circular_phase" if _selected_digits() == DIGITS else "selected_digit_plane_circles_one_shared_hand_circular_phase",
		"contact_slides_on_skin": true, "fixed_palm_anchor": false, "cylinder_used": false,
		"circle_center_policy": "current_weapon_slice_area_centroid_in_each_digit_plane",
		"initial_pose_policy": "authored_open_angles_checked_against_prepared_limits",
		"placement_policy": "rigid_captured_pose_world_translation_then_selected_digit_articulation",
		"guide_interior_policy": "all_observed_skin_stays_outside_virtual_circle",
		"guide_clearance_m": CLEARANCE_M, "numeric_guard_m": NUMERIC_GUARD_M,
		"weapon_containment_checked_each_candidate": true,
		"final_wrapper_minimum_inward_radius_m": 0.0508284749483291,
		"guide_policy_does_not_replace_material_flesh_give": true,
		"continuous_sweep_certified": false, "noncircular_wrapper_phase_run": false}

func _report_stem() -> String:
	return "circle_hand_process"

func _prepare(definition: Resource, stage: Dictionary) -> Dictionary:
	var context: Dictionary = super._prepare(definition,stage)
	return SharedGripAcquisition.op_circle_prepare(self,definition,stage,context)

func _angles(parameters: Array) -> Dictionary:
	return SharedGripAcquisition.op_circle_angles(self, parameters)

func _offset(context: Dictionary, parameters: Array, distance: float) -> Array:
	var out: Array = parameters.duplicate()
	out[_translation_u_index()] += float(context.outward_parameters.x) * distance
	out[_translation_v_index()] += float(context.outward_parameters.y) * distance
	return out

func _rigid_candidate(context: Dictionary, parameters: Array, translation: Vector3) -> Dictionary:
	return SharedGripAcquisition.op_circle_rigid_candidate(self, context,parameters,translation)

func _circle_sample(context: Dictionary, parameters: Array, radius: float, geometry: bool = false) -> Dictionary:
	var key: String = var_to_bytes([parameters,radius]).hex_encode()
	if not geometry and _circle_cache.has(key): return _circle_cache[key]
	_circle_evaluations += 1
	var translation: Vector3 = context.translation_u_world * float(parameters[_translation_u_index()]) + context.translation_v_world * float(parameters[_translation_v_index()])
	var candidate: Dictionary = _rigid_candidate(context,parameters,translation)
	if not candidate.get("valid", false): return candidate
	# Each guide shares the current actual section's centroid. A translated
	# oblique plane must not retain a stale center from an earlier section.
	var targets: Dictionary = _circle_targets(context,candidate,[parameters[_translation_u_index()],parameters[_translation_v_index()]])
	if not targets.get("valid",false): return targets
	var out: Dictionary = {"valid": true, "parameters": parameters.duplicate(), "pose_id": candidate.pose_packet.pose_id,
		"translation_world": translation, "translation_world_origin_id": ROOT, "hand_to_world": candidate.hand_to_world,
		"hand_to_world_origin_id": ROOT, "axial_translation_m": translation.dot(context.station_axis_world),
		"radius_m": radius, "digits": [], "min_signed_clearance_m": INF, "contact_error_m": 0.0,
		"machine_to_world": candidate.pose_packet.machine_to_world,
		"grip_accepted": false, "production_pose_written": false, "actual_3d_grip_verified": false}
	for digit: StringName in _selected_digits():
		var state: Dictionary = candidate.digit_states[digit]
		var plane: Transform3D = state.plane_to_world
		var digit_radius: float = _guide_radius_for_digit(digit,parameters,radius)
		var center: Vector2 = targets.digits[digit].center
		var center_world: Vector3 = plane * Vector3(center.x,center.y,0.0)
		var reference: Dictionary = {"center_reference_weapon_local":context.weapon_to_world.affine_inverse()*center_world,
			"origin_id":context.object_origin_records[1].origin_id}
		var observation_input: Dictionary = context.observations[digit].duplicate()
		observation_input.machine_to_world = candidate.pose_packet.machine_to_world
		var sliced: Dictionary = _observer.slice_candidate(observation_input,candidate,plane,state.plane_origin_id)
		if not sliced.get("valid", false): return sliced
		var measured: Dictionary = _circle_query.evaluate(sliced.segments,center,digit_radius,state.plane_origin_id,&"WeaponOwnedPlanarCircle")
		if not measured.get("valid", false): return measured
		var regions: Array = []
		var group_clearance: Array = [INF,INF,INF,INF]
		for edge_index: int in sliced.segments.size():
			var owner: int = int(sliced.segments[edge_index].section_owner)
			var group: int = owner if owner >= 0 else 3
			group_clearance[group] = minf(group_clearance[group],float(measured.segments[edge_index].signed_clearance_m))
		for joint: int in 3:
			var nearest: float = INF
			var nearest_unrestricted: float = INF
			var witness: Dictionary = {}
			for edge_index: int in sliced.owned[joint]:
				var edge: Dictionary = measured.segments[edge_index]
				nearest_unrestricted = minf(nearest_unrestricted,float(edge.signed_clearance_m))
				if edge.get("circle_point_m") is Vector2 and (edge.circle_point_m as Vector2).distance_to(sliced.reach_center_m) <= sliced.reach_m and float(edge.signed_clearance_m) < nearest:
					nearest = edge.signed_clearance_m
					witness = edge
			var required: bool = not (digit == &"thumb" and joint == 0)
			if required: out.contact_error_m += maxf(nearest,0.0) if is_finite(nearest) else radius * 4.0
			regions.append({"section": joint+1, "nearest_gap_m": nearest, "contact_required": required,
				"nearest_unrestricted_gap_m":nearest_unrestricted,
				"owned_segments": sliced.owned[joint].size(), "witness": witness})
		out.min_signed_clearance_m = minf(out.min_signed_clearance_m, measured.min_signed_clearance_m)
		var observation: Dictionary = {"valid": true, "digit": digit, "slot": context.slot, "pose_id": out.pose_id,
			"angles_rad": state.angles_rad, "plane_to_world": plane, "plane_origin_id": state.plane_origin_id,
			"circle_center_m": center, "circle_center_origin_id": state.plane_origin_id, "radius_m": digit_radius,
			"circle_reference": reference, "slice_center_m": center, "slice_center_origin_id": state.plane_origin_id,
			"circle_observation": measured if geometry else {"min_signed_clearance_m":measured.min_signed_clearance_m},
			"regions": regions, "reach_center_m": sliced.reach_center_m, "reach_m": sliced.reach_m}
		observation["group_clearance_m"] = group_clearance
		observation["nearest_skin_source_id"] = measured.get("nearest_source_id")
		if geometry: observation["skin_segments"] = sliced.segments
		out.digits.append(observation)
	# Sliding the hand moves its oblique planes through the fixed weapon. Check
	# containment on every candidate, including every accepted transition sample.
	out["weapon_slices_valid"] = targets.get("valid",false)
	out["weapon_slice_failure"] = targets.get("reason","")
	out["required_enclosing_radius_m"] = 0.0
	for observation: Dictionary in out.digits:
		observation["required_enclosing_radius_m"] = 0.0
		if geometry: observation["target_polygon_m"] = PackedVector2Array()
		if targets.get("valid",false):
			var polygon: PackedVector2Array = targets.digits[observation.digit].polygon
			if geometry: observation.target_polygon_m = polygon
			for point: Vector2 in polygon:
				out.required_enclosing_radius_m = maxf(out.required_enclosing_radius_m, point.distance_to(observation.circle_center_m))
				observation.required_enclosing_radius_m = maxf(observation.required_enclosing_radius_m,point.distance_to(observation.circle_center_m))
	if geometry: out["pose_origin_records"] = candidate.pose_packet.origin_records
	else: _circle_cache[key] = out
	return out

func _guide_radius_for_digit(_digit: StringName, _parameters: Array, radius: float) -> float:
	return radius

func _circle_targets(context: Dictionary, candidate: Dictionary, translation: Array) -> Dictionary:
	return super._targets(context,candidate,translation)

func _safe(sample: Dictionary) -> bool:
	return sample.get("valid",false) and sample.get("weapon_slices_valid",false) and float(sample.min_signed_clearance_m) >= -NUMERIC_GUARD_M and float(sample.required_enclosing_radius_m) <= float(sample.radius_m)+NUMERIC_GUARD_M

func _record_stage(context: Dictionary, parameters: Array, radius: float, label: String) -> Dictionary:
	var pose: Dictionary = _circle_sample(context,parameters,radius,true)
	if not pose.get("valid",false): return pose
	_process_frames.append({"stage":label,"radius_m":radius,"pose":pose})
	return pose

func _retain_path(context: Dictionary, parameters: Array, radius: float, label: String) -> void:
	var sample: Dictionary = _circle_sample(context,parameters,radius)
	_accepted_path.append({"stage":label,"parameters":parameters.duplicate(),"radius_m":radius,
		"pose_id":sample.pose_id,"min_signed_clearance_m":sample.min_signed_clearance_m,
		"weapon_slices_valid":sample.weapon_slices_valid,"required_enclosing_radius_m":sample.required_enclosing_radius_m})

func _project_outside(context: Dictionary, parameters: Array, radius: float) -> Dictionary:
	var result: Dictionary = _circle_sample(context,parameters,radius)
	var values: Array = parameters.duplicate()
	for attempt: int in 12:
		if not result.get("valid",false): return result
		if result.min_signed_clearance_m >= CLEARANCE_M: return result
		values = _offset(context,values,maxf(0.0002,-float(result.min_signed_clearance_m) + CLEARANCE_M))
		if Vector2(values[_translation_u_index()],values[_translation_v_index()]).length() > MAX_OFFSET_M: return {"valid":false,"reason":"outside_projection_bound"}
		result = _circle_sample(context,values,radius)
	return {"valid":false,"reason":"outside_projection_did_not_converge"}

func _seat_on_circle(context: Dictionary, parameters: Array, radius: float) -> Dictionary:
	var current: Dictionary = _project_outside(context,parameters,radius)
	if not current.get("valid",false): return current
	# The closest skin carrier is recomputed each time; no palm point is pinned.
	for step: int in 12:
		if current.min_signed_clearance_m <= CLEARANCE_M+0.000005: return current
		var distance: float = minf(0.01,maxf(0.00001,float(current.min_signed_clearance_m)-CLEARANCE_M)*1.1)
		var next_parameters: Array = _offset(context,current.parameters,-distance)
		var next: Dictionary = _circle_sample(context,next_parameters,radius)
		if not next.get("valid",false): return next
		if next.min_signed_clearance_m < CLEARANCE_M:
			var low: float = 0.0
			var high: float = distance
			var safe: Dictionary = current
			for refinement: int in 12:
				var middle: float = (low+high)*0.5
				var trial: Dictionary = _circle_sample(context,_offset(context,current.parameters,-middle),radius)
				if not trial.get("valid",false): return trial
				if trial.min_signed_clearance_m >= CLEARANCE_M: low=middle; safe=trial
				else: high=middle
			return safe
		if next.min_signed_clearance_m >= current.min_signed_clearance_m: return current
		current = next
	return current

func _path(context: Dictionary, before: Array, after: Array, radius: float) -> Dictionary:
	var count: int = maxi(1,ceili(Vector2(float(after[_translation_u_index()])-float(before[_translation_u_index()]),float(after[_translation_v_index()])-float(before[_translation_v_index()])).length()/0.0005))
	for i: int in _angle_count(): count = maxi(count,ceili(absf(float(after[i])-float(before[i]))/deg_to_rad(0.5)))
	if count > 128: return {"valid":false,"reason":"candidate_step_too_large"}
	var samples: Array = []
	for step: int in range(1,count+1):
		var values: Array = []
		for i: int in _parameter_count(): values.append(lerpf(before[i],after[i],float(step)/float(count)))
		var sample: Dictionary = _circle_sample(context,values,radius)
		if not _safe(sample):
			_rejected_path_count += 1
			return {"valid":false,"reason":"sampled_transition_violates_skin_or_weapon_containment"}
		samples.append(values)
	return {"valid":true,"samples":samples}

func _settle(context: Dictionary, initial: Dictionary, radius: float, passes: int, record_frames: bool = true) -> Dictionary:
	var current: Dictionary = initial
	_last_settle_path = []
	for iteration: int in passes:
		var best: Dictionary = current
		var directions: Array = []
		for i: int in _parameter_count():
			for sign_value: float in [-1.0,1.0]:
				var direction: Array = _zero_parameters()
				direction[i] = sign_value
				directions.append(direction)
		for digit_index: int in _selected_digits().size():
			var direction: Array = _zero_parameters()
			for joint: int in 3:
				var index: int = digit_index*3+joint
				direction[index] = signf(float(context.adapter.digit_inputs[_selected_digits()[digit_index]].snapshot.preferred_angles_rad[joint])-float(context.open_parameters[index]))
			directions.append(direction)
		for direction: Array in directions:
			var values: Array = current.parameters.duplicate()
			for i: int in _angle_count():
				var snapshot: Dictionary = context.adapter.digit_inputs[_selected_digits()[i/3]].snapshot
				values[i] = clampf(float(values[i])+float(direction[i])*deg_to_rad(3.0),snapshot.min_angles_rad[i%3],snapshot.max_angles_rad[i%3])
			for i: int in [_translation_u_index(),_translation_v_index()]: values[i] += float(direction[i])*0.001
			if values == current.parameters: continue
			var trial: Dictionary = _seat_on_circle(context,values,radius)
			if not _safe(trial) or trial.contact_error_m >= best.contact_error_m-0.000001: continue
			var transition: Dictionary = _path(context,current.parameters,trial.parameters,radius)
			if transition.get("valid",false): best = trial
		if best.parameters == current.parameters: break
		var transition: Dictionary = _path(context,current.parameters,best.parameters,radius)
		# Record actual checked intermediate candidates, never interpolated artwork.
		for i: int in transition.samples.size():
			var values: Array = transition.samples[i]
			_last_settle_path.append(values)
			if record_frames: _retain_path(context,values,radius,"sliding_contact_follow")
			if record_frames and (i % 4 == 0 or i == transition.samples.size()-1):
				_record_stage(context,values,radius,"sliding_contact_follow")
		current = best
	return current

func _contact_count(sample: Dictionary) -> int:
	var count: int = 0
	for digit: Dictionary in sample.digits:
		for region: Dictionary in digit.regions:
			count += int(region.contact_required and is_finite(region.nearest_gap_m) and region.nearest_gap_m <= 0.0001)
	return count

func _contact_keys(sample: Dictionary) -> Array:
	var keys: Array = []
	for digit: Dictionary in sample.digits:
		for region: Dictionary in digit.regions:
			if region.contact_required and is_finite(region.nearest_gap_m) and region.nearest_gap_m <= 0.0001:
				keys.append(str(digit.digit)+"/S"+str(region.section))
	return keys

func _reseat_better(a: Dictionary, b: Dictionary) -> bool:
	if _contact_count(a) != _contact_count(b): return _contact_count(a) > _contact_count(b)
	return a.contact_error_m < b.contact_error_m-0.000001

func _reseat(context: Dictionary, original: Dictionary, radius: float) -> Dictionary:
	var best: Dictionary = original
	var best_path: Array = []
	var attempts: Array = []
	_record_stage(context,original.parameters,radius,"before_reseat")
	# One correction cycle with eight small opening/translation alternatives.
	# Intermediate candidates may lose contact; they may never enter the guide.
	for digit_index: int in _selected_digits().size():
		for offset: Vector2 in [Vector2(0.002,0),Vector2(-0.002,0),Vector2(0,0.002),Vector2(0,-0.002)]:
			var values: Array = original.parameters.duplicate()
			for joint: int in 3:
				var index: int = digit_index*3+joint
				values[index] = move_toward(float(values[index]),float(context.open_parameters[index]),deg_to_rad(6.0))
			values[_translation_u_index()] += offset.x; values[_translation_v_index()] += offset.y
			var seed: Dictionary = _seat_on_circle(context,values,radius)
			if not _safe(seed): attempts.append({"valid":false,"reason":seed.get("reason","unsafe_seed")}); continue
			var approach: Dictionary = _path(context,original.parameters,seed.parameters,radius)
			if not approach.get("valid",false): attempts.append(approach); continue
			var corrected: Dictionary = _settle(context,seed,radius,3,false)
			attempts.append({"valid":true,"opened_digit":_selected_digits()[digit_index],"contacts":_contact_count(corrected),
				"error_m":corrected.contact_error_m,"parameters":corrected.parameters})
			if _reseat_better(corrected,best):
				best = corrected
				best_path = approach.samples.duplicate(true)
				best_path.append_array(_last_settle_path.duplicate(true))
	if best.parameters != original.parameters:
		for i: int in best_path.size():
			_retain_path(context,best_path[i],radius,"reseat_correction")
			if i % 4 == 0 or i == best_path.size()-1: _record_stage(context,best_path[i],radius,"reseat_correction")
	_record_stage(context,best.parameters,radius,"reseat_improved" if best.parameters != original.parameters else "reseat_retained_original")
	return {"selected":best,"attempts":attempts,"before_contacts":_contact_count(original),"after_contacts":_contact_count(best),
		"before_error_m":original.contact_error_m,"after_error_m":best.contact_error_m,
		"changed":best.parameters!=original.parameters,"contact_band_m":0.0001,
		"before_contact_regions":_contact_keys(original),"after_contact_regions":_contact_keys(best),
		"scope":"one_bounded_open_shift_reclose_cycle_not_global_optimality_proof"}

func _search(context: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	_circle_cache.clear(); _process_frames.clear(); _accepted_path.clear(); _circle_evaluations = 0; _rejected_path_count = 0
	var open: Array = context.open_parameters
	var low: float = 0.0
	var high: float = 0.02
	var outside: Dictionary = _circle_sample(context,_offset(context,open,high),START_RADIUS_M)
	while (not outside.get("valid",false) or outside.min_signed_clearance_m < CLEARANCE_M) and high < MAX_OFFSET_M-0.005:
		high = minf(high+0.02,MAX_OFFSET_M-0.005)
		outside = _circle_sample(context,_offset(context,open,high),START_RADIUS_M)
	if not outside.get("valid",false) or outside.min_signed_clearance_m < CLEARANCE_M: return {"valid":false,"reason":"no_clear_start_within_disclosed_offset_bound","slot":context.slot}
	for step: int in 18:
		var middle: float = (low+high)*0.5
		var sample: Dictionary = _circle_sample(context,_offset(context,open,middle),START_RADIUS_M)
		if sample.get("valid",false) and sample.min_signed_clearance_m >= CLEARANCE_M: high=middle
		else: low=middle
	var start: Array = _offset(context,open,high+0.005)
	var current: Dictionary = _record_stage(context,start,START_RADIUS_M,"clear_open_start")
	if not _safe(current): return {"valid":false,"reason":"clear_start_reevaluation_failed","slot":context.slot}
	_retain_path(context,start,START_RADIUS_M,"clear_open_start")
	var arrival: Array = _offset(context,open,high)
	var approach: Dictionary = _path(context,start,arrival,START_RADIUS_M)
	if not approach.get("valid",false): return {"valid":false,"reason":"outside_approach_not_clear","slot":context.slot}
	for values: Array in approach.samples:
		_retain_path(context,values,START_RADIUS_M,"outside_approach")
		_record_stage(context,values,START_RADIUS_M,"outside_approach")
	current = _circle_sample(context,arrival,START_RADIUS_M)
	_record_stage(context,arrival,START_RADIUS_M,"first_tangent")
	current = _settle(context,current,START_RADIUS_M,8)
	var radius: float = START_RADIUS_M
	var reason: String = "circular_phase_step_budget"
	for step: int in 18:
		var inspected: Dictionary = _circle_sample(context,current.parameters,radius,true)
		if not inspected.weapon_slices_valid:
			reason = "current_plane_does_not_supply_one_complete_weapon_loop"; break
		if inspected.required_enclosing_radius_m > radius+NUMERIC_GUARD_M:
			reason = "circle_no_longer_encloses_current_weapon_section"; break
		var next_radius: float = maxf(radius-0.002,float(inspected.required_enclosing_radius_m)+CLEARANCE_M)
		if next_radius >= radius-0.0001:
			reason = "circle_reached_weapon_outer_extent_non_circular_phase_needed"; break
		radius = next_radius
		current = _circle_sample(context,current.parameters,radius)
		_record_stage(context,current.parameters,radius,"circle_contracts")
		_retain_path(context,current.parameters,radius,"circle_contracts")
		var seated: Dictionary = _seat_on_circle(context,current.parameters,radius)
		if _safe(seated):
			var reapproach: Dictionary = _path(context,current.parameters,seated.parameters,radius)
			if reapproach.get("valid",false):
				for values: Array in reapproach.samples:
					_retain_path(context,values,radius,"contact_reapproach")
					_record_stage(context,values,radius,"contact_reapproach")
				current=seated
		current = _settle(context,current,radius,5)
		var final_pose: Dictionary = _record_stage(context,current.parameters,radius,"radius_stage_settled")
		print("CIRCLE_PROGRESS="+JSON.stringify({"slot":context.slot,"radius_mm":radius*1000.0,"clearance_mm":current.min_signed_clearance_m*1000.0,"error_mm":current.contact_error_m*1000.0,"evaluations":_circle_evaluations}))
		if not _safe(final_pose): reason="final_candidate_recheck_failed"; break
		if current.min_signed_clearance_m > 0.001:
			reason="bounded_follower_did_not_reestablish_contact"; break
	var reseat: Dictionary = _reseat(context,current,radius)
	current = reseat.selected
	var selected: Dictionary = _record_stage(context,current.parameters,radius,"stopped")
	if reason == "bounded_follower_did_not_reestablish_contact" and selected.min_signed_clearance_m <= 0.001:
		reason = "reseat_restored_contact_continuation_not_run_in_this_pass"
	reseat.erase("selected")
	return {"valid":_safe(selected),"slot":context.slot,"initial":_process_frames[0].pose,"selected":selected,
		"stages":_process_frames.duplicate(true),"termination":reason,"radius_m":radius,
		"accepted_sampled_path":_accepted_path.duplicate(true),
		"evaluation_count":_circle_evaluations,"total_search_ms":float(Time.get_ticks_usec()-started)/1000.0,
		"outward_direction_world":context.outward_direction_world,"vectors_origin_id":ROOT,
		"initial_outward_offset_m":high+0.005,"first_contact_outward_offset_m":high,
		"station_axis_world":context.station_axis_world,"weapon_to_world":context.weapon_to_world,
		"object_origin_records":context.object_origin_records,"machine_to_world":context.adapter.base_packet.machine_to_world,
		"open_parameters":open,
		"sampled_transition_max_translation_m":0.0005,"sampled_transition_max_joint_step_rad":deg_to_rad(0.5),
		"rejected_sampled_transitions":_rejected_path_count,"continuous_sweep_certified":false,"reseat":reseat,
		"arm_realization_verified":false,"palm_contact_verified":false,"grip_accepted":false}

func _brief(value: Dictionary) -> Dictionary:
	return {"valid":value.get("valid",false),"radius_m":value.get("radius_m"),
		"min_signed_clearance_m":value.get("min_signed_clearance_m"),"contact_error_m":value.get("contact_error_m"),
		"parameters":value.get("parameters"),"grip_accepted":false}
