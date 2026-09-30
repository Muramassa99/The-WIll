extends "res://tools/grip_plane_proof/run_tangent_hand_process_proof.gd"

## Prescribed guide -> sliding skin witness -> native constrained IK -> actual
## original-weight skin check. The solver never owns the circle radius.
const NativeContact = preload("res://tools/grip_plane_proof/native_digit_contact_ik.gd")
const CONTACT_PASSES: int = 24
var _native := NativeContact.new()
var _native_history: Array = []
var _native_calls: int = 0

func _report_stem() -> String:
	return "native_envelope_follow"

func _guide_radius_for_digit(_digit: StringName, _parameters: Array, radius: float) -> float:
	# Explicit authority boundary: no inherited fitted-radius offsets.
	return radius

func _report_extensions() -> Dictionary:
	return {"schema":"native_envelope_follow_proof_v1",
		"scope":"native_middle_thumb_prescribed_circle_response" if _selected_digits() == DIGITS else "native_selected_digits_prescribed_circle_response",
		"solver":"Godot_4_7_CCDIK3D_proposal_with_simultaneous_actual_skin_constraint_correction",
		"native_pass_alone_proved_sufficient":false,"actual_skin_correction_parameters":"six_hinge_angles_two_transverse_hand_offsets_no_radius" if _selected_digits() == DIGITS else "selected_digit_hinge_angles_two_transverse_hand_offsets_no_radius",
		"radius_is_prescribed":true,"radius_is_optimization_variable":false,
		"circle_center_policy":"current_weapon_slice_area_centroid_in_each_digit_plane",
		"required_contacts":_required_contact_keys(),
		"contact_band_m":CONTACT_BAND_M,"guide_clearance_m":CLEARANCE_M,"numeric_guard_m":NUMERIC_GUARD_M,
		"contact_slides_on_skin":true,"fixed_palm_anchor":false,"palm_attraction_before_wrapper":false,
		"temporary_upstream_locks":"only_when_all_earlier_required_sections_are_currently_in_contact_band",
		"guide_interior_policy":"all_observed_skin_outside_virtual_circle",
		"material_flesh_give_applied_to_virtual_guide":false,
		"proxy_targets_certify_blended_skin_contact":false,"actual_original_weight_skin_rechecked":true,
		"skin_and_circle_targets_refreshed_after_each_native_contact":true,
		"placement_policy":"rigid_captured_pose_world_translation_then_selected_digit_articulation",
		"continuous_sweep_certified":false,"noncircular_wrapper_phase_run":false,
		"maximum_contact_passes_per_radius":CONTACT_PASSES,
		"source_sha256":{
			"runner":FileAccess.get_sha256("res://tools/grip_plane_proof/run_native_envelope_follow_proof.gd"),
			"native_adapter":FileAccess.get_sha256("res://tools/grip_plane_proof/native_digit_contact_ik.gd"),
			"candidate_skin":FileAccess.get_sha256("res://tools/grip_plane_proof/prepared_hand_candidate_pose.gd"),
			"skin_constraint_numerics":FileAccess.get_sha256("res://tools/grip_plane_proof/run_tangent_hand_process_proof.gd"),
			"circle_query":FileAccess.get_sha256("res://tools/grip_plane_proof/planar_circle_skin_contact.gd"),
			"prepared_section":FileAccess.get_sha256("res://tools/grip_plane_proof/prepared_weapon_plane_section.gd")}}

func _clamped(context: Dictionary, parameters: Array) -> Array:
	return SharedGripAcquisition.op_native_clamped(self, context,parameters)

func _skin_constraint_correction(context: Dictionary, sample: Dictionary, radius: float, label: String) -> Dictionary:
	assert(sample.parameters.size()==_parameter_count() and sample.radius_m==radius)
	return _fit(context,sample,radius,label)

func _contact_requests(sample: Dictionary) -> Array:
	var requests: Array = []
	for digit: Dictionary in sample.digits:
		var plane: Transform3D = digit.plane_to_world
		for region: Dictionary in digit.regions:
			if not region.contact_required or region.witness.is_empty(): continue
			var earlier_contacts: bool = true
			for earlier: Dictionary in digit.regions:
				if not earlier.contact_required or int(earlier.section)>=int(region.section): continue
				var gap: float = earlier.nearest_gap_m
				earlier_contacts=earlier_contacts and is_finite(gap) and gap>=-NUMERIC_GUARD_M and absf(gap-CLEARANCE_M)<=CONTACT_BAND_M
			var fixed: int = int(region.section)-1 if earlier_contacts else 0
			if digit.digit==&"thumb" and int(region.section)==2: fixed=0
			var witness: Dictionary = region.witness
			var skin: Vector2 = witness.skin_point_m
			var target: Vector2 = witness.circle_point_m + witness.circle_outward_normal * CLEARANCE_M
			requests.append({"digit":digit.digit,"section":region.section,
				"fixed_upstream_count":fixed,
				"skin_point_world":plane*Vector3(skin.x,skin.y,0.0),
				"target_point_world":plane*Vector3(target.x,target.y,0.0),
				"skin_origin_id":ROOT,"target_origin_id":ROOT,
				"source_id":witness.source_id})
	return requests

func _translation_response(context: Dictionary, current: Dictionary, radius: float) -> Dictionary:
	# Only shared transverse hand placement is solved here; bones belong to IK.
	# Re-slicing each probe accounts for oblique-plane centroid motion.
	var residual: PackedFloat64Array = _residual(current)
	var columns: Array = []
	for index: int in [_translation_u_index(),_translation_v_index()]:
		var parameters: Array = current.parameters.duplicate()
		parameters[index] += 0.0001
		var probe: Dictionary = _circle_sample(context,parameters,radius)
		if not probe.get("valid",false): return current
		var measured: PackedFloat64Array = _residual(probe)
		var column: PackedFloat64Array = []
		for row: int in residual.size(): column.append((measured[row]-residual[row])/0.1)
		columns.append(column)
	var matrix: Array = [[0.1,0.0],[0.0,0.1]]
	var rhs: PackedFloat64Array = [0.0,0.0]
	for i: int in 2:
		for row: int in residual.size():
			rhs[i]-=columns[i][row]*residual[row]
			for j: int in 2: matrix[i][j]+=columns[i][row]*columns[j][row]
	var delta: PackedFloat64Array = _linear_solve(matrix,rhs)
	if delta.size()!=2: return current
	var step: Vector2 = Vector2(delta[0],delta[1]).limit_length(10.0)*0.001
	for fraction: float in [1.0,0.5,0.25,0.125]:
		var parameters: Array = current.parameters.duplicate()
		parameters[_translation_u_index()]+=step.x*fraction; parameters[_translation_v_index()]+=step.y*fraction
		if Vector2(parameters[_translation_u_index()],parameters[_translation_v_index()]).length()>0.35: continue
		var trial: Dictionary = _circle_sample(context,parameters,radius)
		if trial.get("valid",false) and _cost(_residual(trial))<_cost(residual)-0.00000001: return trial
	return current

func _native_contact_sweep(context: Dictionary, handle: Dictionary, sample: Dictionary, radius: float) -> Dictionary:
	# Each native step changes the blended skin. Reconstruct it before choosing
	# the next sliding witness; never reuse a pre-sweep target for a changed pose.
	var provisional: Dictionary = sample
	var calls: Array = []
	var off_axis: float = 0.0
	var result: Dictionary = {}
	for identity: Array in _required_digit_contacts():
		var request: Dictionary = {}
		for measured: Dictionary in _contact_requests(provisional):
			if measured.digit==identity[0] and measured.section==identity[1]: request=measured; break
		if request.is_empty():
			return {"valid":false,"reason":"contact_witness_lost_within_native_sweep","native_calls":calls,"native_process_count":calls.size()}
		var translation: Vector3 = context.translation_u_world*float(provisional.parameters[_translation_u_index()])+context.translation_v_world*float(provisional.parameters[_translation_v_index()])
		var candidate: Dictionary = _rigid_candidate(context,provisional.parameters,translation)
		result=await _native.solve(handle,candidate,[request])
		for call: Dictionary in result.get("native_calls",[]):
			call["source_pose_id"]=provisional.pose_id
			call["skin_point_world"]=request.skin_point_world
			call["skin_point_world_origin_id"]=ROOT
			for digit: Dictionary in provisional.digits:
				if digit.digit!=request.digit: continue
				var center: Vector2 = digit.circle_center_m
				call["circle_center_world"]=digit.plane_to_world*Vector3(center.x,center.y,0.0)
				call["circle_center_world_origin_id"]=ROOT
				call["prescribed_radius_m"]=radius
			calls.append(call)
		off_axis=maxf(off_axis,float(result.get("off_axis_error_rad",0.0)))
		if not result.get("valid",false):
			result["native_calls"]=calls; result["native_process_count"]=calls.size()
			return result
		var parameters: Array = provisional.parameters.duplicate()
		for digit_index: int in _selected_digits().size():
			for joint: int in 3: parameters[digit_index*3+joint]=result.angles[_selected_digits()[digit_index]][joint]
		provisional=_circle_sample(context,parameters,radius)
		if not provisional.get("valid",false):
			return {"valid":false,"reason":"native_proposal_skin_reconstruction_failed","native_calls":calls,"native_process_count":calls.size()}
	result["native_calls"]=calls; result["native_process_count"]=calls.size(); result["off_axis_error_rad"]=off_axis
	return result

func _follow_radius(context: Dictionary, handle: Dictionary, seed: Dictionary, radius: float, label: String) -> Dictionary:
	var current: Dictionary = seed
	var stalled: int = 0
	for pass_index: int in CONTACT_PASSES:
		if _contact_status(current).accepted: break
		var before_cost: float = _cost(_residual(current))
		current=_translation_response(context,current,radius)
		var requests: Array = _contact_requests(current)
		if requests.size()!=_required_digit_contacts().size():
			_native_history.append({"label":label,"pass":pass_index,"failure":"missing_reachable_skin_contact_witness","requests":requests.size(),"radius_m":radius})
			# Acquisition may still have room to move the hand into reach. This is
			# placement only, never an accepted contact or an unreachable IK target.
			if before_cost-_cost(_residual(current))>0.00000001: continue
			break
		var solved: Dictionary = await _native_contact_sweep(context,handle,current,radius)
		_native_calls+=int(solved.get("native_process_count",0))
		var entry: Dictionary = {"label":label,"pass":pass_index,"radius_m":radius,
			"native_valid":solved.get("valid",false),"native_reason":solved.get("reason",""),
			"native_process_count":solved.get("native_process_count",0),
			"off_axis_error_rad":solved.get("off_axis_error_rad"),
			"joint_limit_violations":solved.get("joint_limit_violations",[]),
			"solved_angles":solved.get("angles",{}),
			"native_origin_records":solved.get("origin_records",[]),
			"native_machine_to_world":solved.get("machine_to_world"),
			"native_calls":solved.get("native_calls",[])}
		if solved.get("valid",false):
			var angles: Dictionary = solved.angles
			for fraction: float in [1.0,0.5,0.25,0.125]:
				var parameters: Array = current.parameters.duplicate()
				for digit_index: int in _selected_digits().size():
					for joint: int in 3:
						var index: int = digit_index*3+joint
						parameters[index]=lerpf(current.parameters[index],angles[_selected_digits()[digit_index]][joint],fraction)
				var trial: Dictionary = _circle_sample(context,parameters,radius)
				if not trial.get("valid",false): continue
				trial=_translation_response(context,trial,radius)
				if _cost(_residual(trial))<_cost(_residual(current))-0.00000001:
					current=trial; entry["accepted_native_fraction"]=fraction; break
		entry["actual_skin_status"]=_contact_status(current)
		entry["actual_skin_min_clearance_m"]=current.min_signed_clearance_m
		entry["cost"]=_cost(_residual(current))
		_native_history.append(entry)
		if pass_index%4==0:
			print("NATIVE_FOLLOW="+JSON.stringify(_json({"slot":context.slot,"label":label,"pass":pass_index,"status":entry.actual_skin_status,"native_valid":entry.native_valid,"cost":entry.cost})))
		if before_cost-entry.cost < 0.00000001: stalled+=1
		else: stalled=0
		if stalled>=3 or not solved.get("valid",false): break
	return _skin_constraint_correction(context,current,radius,label+"_simultaneous_skin_constraints")

func _search(context: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	_circle_cache.clear(); _slice_cache.clear(); _process_frames.clear(); _native_history.clear(); _fit_history.clear(); _fit_runs.clear(); _circle_evaluations=0; _native_calls=0
	var open: Array = context.open_parameters.duplicate()
	var original: Dictionary = _circle_sample(context,open,0.05)
	if not original.get("valid",false): return original
	var radius: float = 0.0
	for digit: Dictionary in original.digits: radius=maxf(radius,digit.reach_m)
	context["start_radius_m"]=radius
	var seed: Dictionary = {}
	for angle: float in [0.0,-30.0,30.0,-60.0,60.0]:
		var direction: Vector2 = context.outward_parameters.rotated(deg_to_rad(angle))
		for factor: float in [0.5,0.75,1.0,1.25,1.5,1.75,2.0]:
			var parameters: Array = open.duplicate()
			parameters[_translation_u_index()]+=direction.x*radius*factor; parameters[_translation_v_index()]+=direction.y*radius*factor
			var trial: Dictionary = _circle_sample(context,parameters,radius)
			if not trial.get("valid",false): continue
			if seed.is_empty() or (_safe(trial) and not _safe(seed)) or (_safe(trial)==_safe(seed) and _cost(_residual(trial))<_cost(_residual(seed))): seed=trial
	if seed.is_empty(): return {"valid":false,"reason":"no_valid_section_for_initial_native_seed"}
	var handle: Dictionary = _native.prepare(root,context)
	if not handle.get("valid",false): return handle
	_record_fit(context,seed,"unfitted_prescribed_start")
	var current: Dictionary = await _follow_radius(context,handle,seed,radius,"initial_native_acquisition")
	_record_fit(context,current,"initial_native_result")
	var initial_passed: bool = _contact_status(current).accepted
	var continuous_contacts: bool = initial_passed
	var prescribed_trials: Array = [{"radius_m":radius,"status":_contact_status(current)}]
	# If initial contact fails, two explicitly diagnostic prescribed-radius trials
	# still measure IK response. They cannot count as maintained-contact motion.
	var reason: String = "accepted_endpoint_budget_reached_continuous_path_unverified" if initial_passed else "initial_contact_not_acquired_native_response_only"
	for radius_step: int in (8 if initial_passed else 2):
		var enclosure: float = current.required_enclosing_radius_m
		if radius-enclosure <= 0.0002:
			reason="circle_reached_weapon_extent" if continuous_contacts else reason; break
		var prescribed: float = (radius+enclosure)*0.5
		var next_seed: Dictionary = _circle_sample(context,current.parameters,prescribed)
		if not next_seed.get("valid",false): reason="section_query_failed_at_prescribed_radius"; break
		var trial: Dictionary = await _follow_radius(context,handle,next_seed,prescribed,"prescribed_radius_"+str(radius_step+1))
		var status: Dictionary = _contact_status(trial)
		_record_fit(context,trial,"contact_follow_result" if continuous_contacts and status.accepted else "diagnostic_radius_response_not_accepted_motion")
		prescribed_trials.append({"radius_m":prescribed,"status":status})
		if continuous_contacts and not status.accepted:
			continuous_contacts=false
			reason="native_follow_failed_at_prescribed_radius_not_proven_anatomical_stop"; break
		continuous_contacts=continuous_contacts and status.accepted
		current=trial; radius=prescribed
	var selected: Dictionary = _record_fit(context,current,"selected_measured_result")
	_native.dispose(handle)
	return {"valid":true,"slot":context.slot,"initial":_process_frames[0].pose,"selected":selected,"radius_m":radius,
		"termination":reason,"stages":_process_frames.duplicate(true),"prescribed_trials":prescribed_trials,
		"native_history":_native_history.duplicate(true),"native_process_count":_native_calls,
		"skin_constraint_history":_fit_history.duplicate(true),"skin_constraint_runs":_fit_runs.duplicate(true),
		"evaluation_count":_circle_evaluations,"total_search_ms":float(Time.get_ticks_usec()-started)/1000.0,
		"station_axis_world":context.station_axis_world,"outward_direction_world":context.outward_direction_world,"vectors_origin_id":ROOT,
		"weapon_to_world":context.weapon_to_world,"object_origin_records":context.object_origin_records,
		"machine_to_world":context.adapter.base_packet.machine_to_world,"open_parameters":open,
		"initial_contact_gate_passed":initial_passed,"all_prescribed_endpoints_accepted":continuous_contacts,
		"maintained_contact_sequence":false,
		"contact_band_m":CONTACT_BAND_M,"continuous_sweep_certified":false,
		"recorded_states_are_solver_snapshots_not_interpolated_motion":true,
		"arm_realization_verified":false,"palm_contact_verified":false,"grip_accepted":false}
