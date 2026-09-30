extends "res://tools/grip_plane_proof/run_circle_hand_process_proof.gd"

## Isolated simultaneous contact fitting. A failed initial fit cannot authorize
## contraction. Numerical iterates are diagnostics, not a realized hand motion.
const PreparedSection = preload("res://tools/grip_plane_proof/prepared_weapon_plane_section.gd")
const CONTACT_BAND_M: float = 0.0001
const FIT_ITERATIONS: int = 80
var _section_query := PreparedSection.new()
var _fit_history: Array = []
var _fit_runs: Array = []

func _solve_scale(index: int) -> float:
	return SharedGripAcquisition.op_tangent_solve_scale(self, index)

func _report_stem() -> String:
	return "tangent_hand_process"

func _report_extensions() -> Dictionary:
	var out: Dictionary = super._report_extensions()
	out.merge({"schema":"tangent_hand_process_proof_v1",
		"scope":"simultaneous_middle_thumb_initial_contact_feasibility" if _selected_digits() == DIGITS else "simultaneous_selected_digit_initial_contact_feasibility",
		"start_radius_policy":"largest_prepared_digit_reach",
		"initial_pose_policy":"bounded_simultaneous_five_contact_fit" if _selected_digits() == DIGITS else "bounded_simultaneous_required_contact_fit",
		"contact_band_m":CONTACT_BAND_M,"required_contacts":_required_contact_keys(),
		"palm_attraction_before_wrapper":false,"initial_fit_must_pass_before_contraction":true,
		"fitting_iterates_are_physical_motion":false,
		"initial_radii_fit_independently":true,"initial_radius_fit_bounds":"half_to_twice_largest_digit_reach",
		"guide_interior_policy":"all_observed_skin_outside_virtual_circle_before_material_contact",
		"material_flesh_give_applied_to_virtual_guide":false,
		"missing_thumb_s1_owned_skin_does_not_authorize_unassigned_overlap":true,
		"maximum_fit_iterations_per_seed":FIT_ITERATIONS,"maximum_fit_seeds":3,
		"initial_placement_search":"five_transverse_directions_seven_distances_prefer_clear_measured_seed",
		"source_sha256":{
			"runner":FileAccess.get_sha256("res://tools/grip_plane_proof/run_tangent_hand_process_proof.gd"),
			"circle_query":FileAccess.get_sha256("res://tools/grip_plane_proof/planar_circle_skin_contact.gd"),
			"circle_observation":FileAccess.get_sha256("res://tools/grip_plane_proof/run_circle_hand_process_proof.gd"),
			"prepared_section":FileAccess.get_sha256("res://tools/grip_plane_proof/prepared_weapon_plane_section.gd")},
		"solver":"scaled_damped_least_squares_with_active_no_entry_residuals"},true)
	out.erase("start_radius_m")
	return out

func _guide_radius_for_digit(digit: StringName, parameters: Array, radius: float) -> float:
	return radius+float(parameters[_parameter_count()+_selected_digits().find(digit)]) if parameters.size()==_parameter_count()+_selected_digits().size() else radius

func _safe(sample: Dictionary) -> bool:
	if not sample.get("valid",false) or not sample.get("weapon_slices_valid",false) or sample.min_signed_clearance_m < -NUMERIC_GUARD_M: return false
	for digit: Dictionary in sample.digits:
		if digit.required_enclosing_radius_m > digit.radius_m+NUMERIC_GUARD_M: return false
	return true

func _prepare(definition: Resource, stage: Dictionary) -> Dictionary:
	var context: Dictionary = super._prepare(definition,stage)
	return SharedGripAcquisition.op_tangent_prepare(self,definition,stage,context)

func _circle_targets(context: Dictionary, candidate: Dictionary, translation: Array) -> Dictionary:
	return SharedGripAcquisition.op_tangent_circle_targets(self, context,candidate,translation)

func _residual(sample: Dictionary) -> PackedFloat64Array:
	var result: PackedFloat64Array = []
	for digit: Dictionary in sample.digits:
		for region: Dictionary in digit.regions:
			if region.contact_required:
				var gap: float = region.nearest_unrestricted_gap_m
				# Millimetres avoid damping a badly scaled metre-sized residual.
				result.append((gap-CLEARANCE_M)*1000.0 if is_finite(gap) else 1000.0)
		for gap: float in digit.group_clearance_m:
			result.append(minf(gap-CLEARANCE_M,0.0)*10000.0 if is_finite(gap) else 0.0)
	for digit: Dictionary in sample.digits:
		result.append(maxf(float(digit.required_enclosing_radius_m)-float(digit.radius_m),0.0)*10000.0)
	return result

func _cost(residual: PackedFloat64Array) -> float:
	return SharedGripAcquisition.op_tangent_cost(self, residual)

func _contact_status(sample: Dictionary) -> Dictionary:
	var count: int = 0
	var maximum: float = 0.0
	var missing: Array = []
	for digit: Dictionary in sample.digits:
		for region: Dictionary in digit.regions:
			if not region.contact_required: continue
			var gap: float = region.nearest_gap_m
			maximum = maxf(maximum,absf(gap-CLEARANCE_M))
			if is_finite(gap) and gap >= -NUMERIC_GUARD_M and absf(gap-CLEARANCE_M) <= CONTACT_BAND_M:
				count += 1
			else: missing.append(str(digit.digit)+"/S"+str(region.section))
	var required: int = _required_digit_contacts().size()
	return {"contacts":count,"required":required,"maximum_error_m":maximum,"missing":missing,
		"accepted":count==required and _safe(sample)}

func _clamped(context: Dictionary, parameters: Array) -> Array:
	var result: Array = parameters.duplicate()
	for index: int in _angle_count():
		var snapshot: Dictionary = context.adapter.digit_inputs[_selected_digits()[index/3]].snapshot
		result[index] = clampf(result[index],snapshot.min_angles_rad[index%3],snapshot.max_angles_rad[index%3])
	for index: int in range(_parameter_count(),parameters.size()):
		result[index]=clampf(result[index],-context.start_radius_m*0.5,context.start_radius_m)
	var displacement: Vector2 = Vector2(result[_translation_u_index()],result[_translation_v_index()])
	if displacement.length()>context.start_radius_m*3.0:
		displacement=displacement.limit_length(context.start_radius_m*3.0)
		result[_translation_u_index()]=displacement.x; result[_translation_v_index()]=displacement.y
	return result

func _linear_solve(matrix: Array, rhs: PackedFloat64Array) -> PackedFloat64Array:
	return SharedGripAcquisition.op_tangent_linear_solve(self, matrix,rhs)

func _bounded_step(context: Dictionary, parameters: Array, matrix: Array, rhs: PackedFloat64Array) -> PackedFloat64Array:
	return SharedGripAcquisition.op_tangent_bounded_step(self, context,parameters,matrix,rhs)

func _fit(context: Dictionary, seed: Dictionary, radius: float, label: String) -> Dictionary:
	var current: Dictionary = seed
	var residual: PackedFloat64Array = _residual(current)
	var damping: float = 0.1
	var reason: String = "bounded_iteration_budget"
	var iterations: int = 0
	for iteration: int in FIT_ITERATIONS:
		iterations = iteration+1
		var status: Dictionary = _contact_status(current)
		if status.accepted: reason="all_required_contacts_within_band"; break
		var jacobian: Array = []
		for index: int in current.parameters.size():
			var column: PackedFloat64Array = []; column.resize(residual.size())
			var probe: Dictionary = {}
			var increment: float = _solve_scale(index)*0.02
			for direction: float in [1.0,-1.0]:
				var values: Array = current.parameters.duplicate()
				values[index] += increment*direction
				values = _clamped(context,values)
				var actual: float = (values[index]-current.parameters[index])/_solve_scale(index)
				if absf(actual)<1.0e-8: continue
				probe = _circle_sample(context,values,radius)
				if not probe.get("valid",false): continue
				var measured: PackedFloat64Array = _residual(probe)
				for row: int in residual.size(): column[row]=(measured[row]-residual[row])/actual
				break
			jacobian.append(column)
		var matrix: Array = []
		var size: int = current.parameters.size()
		var rhs: PackedFloat64Array = []; rhs.resize(size)
		for i: int in size:
			var row_values: PackedFloat64Array = []; row_values.resize(size)
			for j: int in size:
				for row: int in residual.size(): row_values[j]+=jacobian[i][row]*jacobian[j][row]
			row_values[i]+=damping
			matrix.append(row_values)
			for row: int in residual.size(): rhs[i]-=jacobian[i][row]*residual[row]
		var delta: PackedFloat64Array = _bounded_step(context,current.parameters,matrix,rhs)
		if delta.is_empty(): reason="singular_fit_step"; break
		var maximum: float = 1.0
		for value: float in delta: maximum=maxf(maximum,absf(value))
		var improved: bool = false
		for fraction: float in [1.0,0.5,0.25,0.125,0.0625]:
			var values: Array = current.parameters.duplicate()
			for i: int in size: values[i]+=delta[i]/maximum*_solve_scale(i)*fraction
			values=_clamped(context,values)
			var candidate: Dictionary = _circle_sample(context,values,radius)
			if not candidate.get("valid",false): continue
			var next_residual: PackedFloat64Array = _residual(candidate)
			if _cost(next_residual)<_cost(residual)-0.00000001:
				current=candidate; residual=next_residual; improved=true; damping=maxf(0.0001,damping*0.5)
				break
		if not improved:
			damping*=10.0
			if damping>100000.0: reason="bounded_local_fit_stalled"; break
		if iteration%8==0:
			print("TANGENT_FIT="+JSON.stringify({"slot":context.slot,"label":label,"iteration":iteration,
				"radius_mm":radius*1000,"cost":_cost(residual),"status":_json(_contact_status(current)),
				"min_clearance_mm":current.min_signed_clearance_m*1000,"evaluations":_circle_evaluations}))
			_fit_history.append({"label":label,"iteration":iteration,"parameters":current.parameters.duplicate(),"radius_m":radius,
				"status":_contact_status(current),"cost":_cost(residual),"min_signed_clearance_m":current.min_signed_clearance_m})
	_fit_runs.append({"label":label,"iterations":iterations,"termination":reason,"status":_contact_status(current),"cost":_cost(residual)})
	return current

func _record_fit(context: Dictionary, sample: Dictionary, label: String) -> Dictionary:
	var pose: Dictionary = _record_stage(context,sample.parameters,sample.radius_m,label)
	pose["contact_status"] = _contact_status(pose)
	pose["active_joint_limits"] = []
	for i: int in _angle_count():
		var snapshot: Dictionary = context.adapter.digit_inputs[_selected_digits()[i/3]].snapshot
		var angle: float = pose.parameters[i]
		var limit: String = ""
		if angle-snapshot.min_angles_rad[i%3] <= deg_to_rad(0.02): limit="minimum"
		if snapshot.max_angles_rad[i%3]-angle <= deg_to_rad(0.02): limit="maximum"
		if not limit.is_empty(): pose.active_joint_limits.append({"bone":snapshot.bone_names[i%3],"limit":limit,"angle_rad":angle})
	pose["virtual_guide_safe"] = _safe(pose)
	for digit: Dictionary in pose.digits:
		for region: Dictionary in digit.regions:
			if region.witness.is_empty(): continue
			var t: float = region.witness.skin_segment_t
			region["nearest_feature_type"]="edge_interior_radial_normal" if t>0.000001 and t<0.999999 else "mesh_vertex_support"
	return pose

func _search(context: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	_circle_cache.clear(); _process_frames.clear(); _accepted_path.clear(); _fit_history.clear(); _fit_runs.clear(); _circle_evaluations=0
	var open: Array = context.open_parameters.duplicate()
	var initial: Dictionary = _circle_sample(context,open,0.05)
	if not initial.get("valid",false): return initial
	var radius: float = 0.0
	for digit: Dictionary in initial.digits: radius=maxf(radius,float(digit.reach_m))
	context["start_radius_m"]=radius
	for _digit: StringName in _selected_digits(): open.append(0.0)
	var seed: Dictionary = {}
	# Find a collision-free open placement before fitting; if unavailable retain
	# the least violating measured candidate, explicitly labelled as unfitted.
	for angle: float in [0.0,-30.0,30.0,-60.0,60.0]:
		var direction: Vector2 = context.outward_parameters.rotated(deg_to_rad(angle))
		for factor: float in [0.5,0.75,1.0,1.25,1.5,1.75,2.0]:
			var values: Array = open.duplicate()
			values[_translation_u_index()]+=direction.x*radius*factor; values[_translation_v_index()]+=direction.y*radius*factor
			var attempt: Dictionary = _circle_sample(context,values,radius)
			if not attempt.get("valid",false): continue
			if seed.is_empty() or (_safe(attempt) and not _safe(seed)) or (_safe(attempt)==_safe(seed) and _cost(_residual(attempt))<_cost(_residual(seed))): seed=attempt
	if seed.is_empty(): return {"valid":false,"reason":"no_valid_current_weapon_sections_for_oversized_start"}
	_record_fit(context,seed,"unfitted_oversized_start")
	var current: Dictionary = _fit(context,seed,radius,"initial_contact_fit")
	_record_fit(context,current,"initial_fit_result")
	if not _contact_status(current).accepted:
		# One bounded reseating cycle, with two alternatives. Opening a distal
		# joint while closing its neighbour can escape a tip-first local minimum.
		for amount: float in [0.2,0.5]:
			var values: Array = seed.parameters.duplicate()
			for i: int in _angle_count():
				var snapshot: Dictionary = context.adapter.digit_inputs[_selected_digits()[i/3]].snapshot
				values[i]=lerpf(context.open_parameters[i],snapshot.preferred_angles_rad[i%3],amount)
			var alternate: Dictionary = _circle_sample(context,values,radius)
			if not alternate.get("valid",false): continue
			alternate=_fit(context,alternate,radius,"reseat_seed_"+str(amount))
			_record_fit(context,alternate,"reseat_candidate_"+str(amount))
			if _contact_status(alternate).accepted or _cost(_residual(alternate))<_cost(_residual(current)): current=alternate
			if _contact_status(current).accepted: break
	var initial_gate_passed: bool = _contact_status(current).accepted
	var reason: String = "initial_five_contact_gate_not_met_no_contraction" if _selected_digits() == DIGITS else "initial_required_contact_gate_not_met_no_contraction"
	if initial_gate_passed: reason="initial_independent_circle_tangencies_found_continuation_pending"
	var selected: Dictionary = _record_fit(context,current,"stopped")
	return {"valid":true,"slot":context.slot,"initial":_process_frames[0].pose,"selected":selected,"radius_m":radius,
		"termination":reason,"stages":_process_frames.duplicate(true),"accepted_sampled_path":[],
		"fit_history":_fit_history.duplicate(true),"fit_runs":_fit_runs.duplicate(true),
		"evaluation_count":_circle_evaluations,"total_search_ms":float(Time.get_ticks_usec()-started)/1000.0,
		"station_axis_world":context.station_axis_world,"outward_direction_world":context.outward_direction_world,"vectors_origin_id":ROOT,
		"weapon_to_world":context.weapon_to_world,"object_origin_records":context.object_origin_records,
		"machine_to_world":context.adapter.base_packet.machine_to_world,"open_parameters":open,
		"initial_contact_gate_passed":initial_gate_passed,
		"contact_band_m":CONTACT_BAND_M,"continuous_sweep_certified":false,
		"recorded_states_are_solver_snapshots_not_interpolated_motion":true,
		"arm_realization_verified":false,"palm_contact_verified":false,"grip_accepted":false}
