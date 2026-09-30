extends RefCounted

## W3: Middle owns one shared transverse weapon seat. Guide and actual skin are
## projected together; a changed guide alone is never committed as a pose.
const Candidate = preload("res://runtime/player/grip/prepared_hand_candidate_pose.gd")
const Observer = preload("res://runtime/player/grip/prepared_grip_slice_contact.gd")
const CircleQuery = preload("res://runtime/player/grip/planar_circle_skin_contact.gd")
const Jacobian = preload("res://runtime/player/grip/skin_contact_hinge_jacobian.gd")
const Sections = preload("res://runtime/player/grip/prepared_saved_grip_sections.gd")
const HandSkin = preload("res://runtime/player/grip/prepared_hand_skin_query.gd")
const Wrapper = preload("res://core/resolvers/prepared_grip_target_wrapper_resolver.gd")
const Palm = preload("res://runtime/player/grip/prepared_palmar_slice_region.gd")
const Native = preload("res://runtime/player/grip/native_digit_contact_ik.gd")
const SavedContact = preload("res://runtime/player/grip/saved_wrapper_skin_contact.gd")
const Chronology = preload("res://runtime/player/grip/grip_chronology.gd")
const ROOT := &"RL_BoneRoot"
const REVISION := &"middle_first_coupled_contact_v2"
const CLEARANCE_M := 0.00002
const CONTACT_BAND_M := 0.0001
const NUMERIC_GUARD_M := 0.000002
const PREPARATION_RADIUS_M := 0.05
const PROJECTION_ITERATIONS := 20
const MIN_RADIUS_STEP_M := 0.0001
const PLACEMENT_PROBE_M := 0.0001
const MAX_TRANSLATION_M := 0.35
const ANGLE_SCALE := 0.12
const TRANSLATION_SCALE := 0.005
var _candidate := Candidate.new()
var _observer := Observer.new()
var _circle := CircleQuery.new()
var _sections := Sections.new()
var _jacobian := Jacobian.new()
var _palm := Palm.new()
var _saved_contact := SavedContact.new()
var _cache := {}
var _derivatives := {}
var _metrics := {}
var _events: Array = []
var _trace: Array = []
var _recording := false
var _recording_slot := ""

func run(context: Dictionary, saved: Dictionary, host: Node) -> Dictionary:
	var start := Time.get_ticks_usec()
	_recording = Chronology.enabled()
	_recording_slot = ""
	_cache.clear(); _derivatives.clear(); _events.clear(); _trace.clear()
	_metrics = {"section_queries":0,"section_cache_hits":0,"section_slice_ms":0.0,
		"skin_evaluations":0,"skin_ms":0.0,"candidate_ms":0.0,"projection_iterations":0}
	var checked := _validate_context(context, saved)
	if not checked.get("valid", false): return checked
	_recording_slot = str(context.adapter.get("slot",""))
	if not context.adapter.digit_inputs.has(&"middle"): return _fail("middle_placement_owner_missing")
	if not _saved_contact.begin_acquisition(StringName(str(context.adapter.slot)+":"+str(context.adapter.base_packet.pose_id))):
		return _fail("saved_contact_cache_acquisition_unavailable")
	var angles := {}
	var initial_radius := 0.0
	for index: int in context.digit_order.size():
		var digit: StringName = context.digit_order[index]
		angles[digit] = context.open_parameters.slice(index * 3, index * 3 + 3)
		initial_radius = maxf(initial_radius, context.observations[digit].reach_m)
		_derivatives[digit] = _jacobian.prepare(context.adapter, digit, context.palm_region)
		if not _derivatives[digit].get("valid", false): return _derivatives[digit]
	var placement: Vector2 = -context.outward_parameters * initial_radius
	var current := _evaluate(context, saved, angles, placement, &"middle", initial_radius, false)
	if not current.get("valid", false): return current
	# Acquisition is explicitly unbound. Only after all three contacts fit does
	# contraction begin; unresolved attempts remain diagnostic, not fake binding.
	_record(current, "middle_initial_unbound", false)
	var fitted: Dictionary = _project(context, saved, current, initial_radius, true, false)
	_event({"event":"initial_middle_attachment","converged":fitted.converged,"reason":fitted.reason,"detail":fitted.get("detail",{})})
	current = fitted.sample
	_record(current, "middle_initial_attachment", fitted.converged)
	var middle_ready: bool = fitted.converged
	var termination := "initial_middle_attachment_unresolved"
	if middle_ready:
		termination = "middle_enclosing_target_reached"
		var checkpoints: Array[float] = []
		if current.enclosing_radius_m < PREPARATION_RADIUS_M: checkpoints.append(PREPARATION_RADIUS_M)
		# Zero selects the current enclosure, which changes with shared placement.
		checkpoints.append(0.0)
		for checkpoint: float in checkpoints:
			var continuation_steps := 0
			while current.radius_m - maxf(checkpoint, current.enclosing_radius_m) > MIN_RADIUS_STEP_M:
				if not is_instance_valid(host): return _fail("preparation_host_freed")
				if continuation_steps >= 256:
					termination = "continuation_budget_not_physical_limit"
					middle_ready = false
					break
				continuation_steps += 1
				# Request the agreed coarse waypoint directly. Halve only a failed
				# constrained advance; do not march through fixed 5 mm radii.
				var step: float = current.radius_m - maxf(checkpoint, current.enclosing_radius_m)
				var accepted := false
				while step >= MIN_RADIUS_STEP_M:
					var response := _project(context, saved, current, current.radius_m - step, true, false)
					_event({"event":"coupled_contraction_attempt","from_radius_m":current.radius_m,
						"requested_radius_m":current.radius_m-step,"converged":response.converged,
						"reason":response.reason,"max_contact_error_m":response.sample.max_contact_error_m,
						"detail":response.get("detail",{})})
					if response.converged and response.sample.radius_m < current.radius_m - 0.000001:
						current = response.sample
						_record(current, "middle_coupled_contraction", true)
						accepted = true
						break
					step *= 0.5
				if not accepted:
					termination = "middle_contact_continuation_unresolved_not_a_physical_limit"
					middle_ready = false
					break
				await host.get_tree().process_frame
			if not middle_ready: break
			_record(current, "middle_50mm_reached" if checkpoint == PREPARATION_RADIUS_M else "middle_enclosing_target_reached", true)
		if middle_ready:
			# Palm joins only after digit enclosure. This is still guide contact,
			# not the W4 inward material target or physical penetration acceptance.
			var seated := _project(context, saved, current, current.radius_m, true, true)
			if seated.converged:
				current = seated.sample
				_record(current, "middle_palm_guide_seated", true)
			else:
				_event({"event":"palm_guide_seating_unresolved","reason":seated.reason,"detail":seated.get("detail",{})})
				_record(seated.sample, "palm_seating_unbound_diagnostic", false)
	var circle_summary := _public(current)
	# The saved guide is the next target even if a prep constraint was unresolved.
	# No new envelope is built, and the existing inset is never applied twice.
	var wrapped := _project(context,saved,current,current.radius_m,true,true,&"saved_wrapper")
	_event({"event":"saved_wrapper_match","converged":wrapped.converged,"reason":wrapped.reason,"detail":wrapped.get("detail",{})})
	if wrapped.sample.get("guide_kind",&"circle")==&"saved_wrapper":
		current=wrapped.sample
		_record(current,"middle_saved_wrapper_response",current.accepted_contact_constraints)
	else:
		_record(wrapped.sample,"saved_wrapper_unresolved_diagnostic",false)
	var reseat_count := 0
	if current.get("material_assessed",false) and current.accepted_contact_constraints:
		for attempt: int in 3:
			var before: Dictionary=current
			var reseated := _project(context,saved,current,current.radius_m,true,true,&"saved_wrapper",current.material_contacts,true)
			reseat_count+=1
			var improved: bool = reseated.sample.get("accepted_contact_constraints",false) and reseated.sample.cost<before.cost-1e-12
			_event({"event":"saved_wrapper_reseat","attempt":attempt+1,"improved":improved,
				"reason":reseated.reason,"preserved_contacts":before.material_contacts})
			if not improved: break
			current=reseated.sample
			_record(current,"middle_saved_wrapper_reseated",true)
	var middle_final: Dictionary = current
	var followers: Array = []
	var retained := {&"middle":{"radius_m":middle_final.radius_m,"palm_required":middle_final.palm_required,
		"guide_kind":middle_final.guide_kind,"contacts":middle_final.get("material_contacts",[])}}
	var placement_ready: bool = current.get("accepted_contact_constraints",false) if current.guide_kind==&"saved_wrapper" else middle_ready
	if placement_ready:
		for digit: StringName in context.digit_order:
			if digit == &"middle": continue
			var kind: StringName=current.guide_kind
			var input := _evaluate(context,saved,current.angles,current.placement,digit,0.0,false,{},kind)
			if not input.get("valid",false):
				followers.append({"digit":digit,"valid":false,"reason":input.get("reason"),"detail":input.get("detail",{})})
				continue
			var response := _project(context,saved,input,input.radius_m,false,false,kind)
			var usable: bool=response.sample.get("accepted_contact_constraints",false) and not response.sample.get("material_contacts",[]).is_empty() if kind==&"saved_wrapper" else response.converged
			var retained_contacts := true
			if usable:
				for held_digit: StringName in retained:
					var held: Dictionary=retained[held_digit]
					var check := _evaluate(context,saved,response.sample.angles,current.placement,held_digit,held.radius_m,held.palm_required,{},held.guide_kind)
					var held_valid: bool=check.get("valid",false)
					if held_valid:
						if held.guide_kind==&"saved_wrapper":
							held_valid=check.accepted_contact_constraints
							for id: String in held.contacts: held_valid=held_valid and check.material_contacts.has(id)
						else: held_valid=check.attached
					if not held_valid:
						retained_contacts=false
						_event({"event":"follower_would_lose_retained_contact","digit":digit,
							"held_digit":held_digit,"reason":check.get("reason","shared_skin_contact_changed"),
							"max_contact_error_m":check.get("max_contact_error_m",INF)})
						break
			var accepted: bool=usable and retained_contacts
			followers.append({"digit":digit,"valid":true,"accepted_contact_response":accepted,
				"attached":response.sample.attached and accepted,"guide_kind":kind,
				"reason":response.reason if retained_contacts else "would_lose_previously_acquired_skin_contact",
				"material_contacts":response.sample.get("material_contacts",[]),
				"material_safe":response.sample.get("material_safe",false),
				"max_contact_error_m":response.sample.max_contact_error_m})
			if accepted:
				current=response.sample
				retained[digit]={"radius_m":current.radius_m,"palm_required":false,"guide_kind":kind,"contacts":current.get("material_contacts",[])}
				_record(current,"follower_response_fixed_weapon",true)
			else: _record(response.sample,"follower_unbound_diagnostic",false)
			await host.get_tree().process_frame
	var final_middle := _evaluate(context,saved,current.angles,current.placement,&"middle",middle_final.radius_m,middle_final.palm_required,{},middle_final.guide_kind)
	if not final_middle.get("valid",false): return final_middle
	_record(final_middle,"final_middle_recheck",final_middle.get("accepted_contact_constraints",false) if final_middle.guide_kind==&"saved_wrapper" else final_middle.attached)
	# Retained follower contacts were checked against each subsequent accepted
	# shared-skin pose. Count distinct sections, not nearby points on an edge.
	var hand_contacts: Array=final_middle.get("material_contacts",[]).duplicate()
	for held_digit: StringName in retained:
		if held_digit==&"middle": continue
		for id: String in retained[held_digit].contacts:
			if not hand_contacts.has(id): hand_contacts.append(id)
	_metrics["saved_contact_cache_statistics"] = _saved_contact.cache_statistics()
	return {"valid":true,"revision":REVISION,"stages":_trace,"events":_events,
		"selected":_public(final_middle),"circle_selected":circle_summary,"candidate":final_middle.candidate,"followers":followers,
		"initial_radius_m":initial_radius,"preparation_radius_m":PREPARATION_RADIUS_M,
		"total_ms":float(Time.get_ticks_usec()-start)/1000.0,"totals":_metrics,
		"native_process_count":0,"termination":wrapped.reason,"preparation_termination":termination,"preparation_completed":middle_ready,
		"middle_attachment_verified":final_middle.attached,"hand_transform_unchanged":_same_hand(context.adapter.baseline_hand_to_world,final_middle.candidate.hand_to_world),
		"palm_attachment_verified":final_middle.palm_required and final_middle.attached,
		"placement_owner":&"middle_contact_weapon_transverse_translation","grip_accepted":false,
		"wrapper_target_selected":final_middle.get("wrapper_target_selected",false),"reseat_attempts":reseat_count,
		"material_assessed":final_middle.get("material_assessed",false),"material_safe":final_middle.get("material_safe",false),
		"material_contacts":final_middle.get("material_contacts",[]),
		"material_contact_scope":&"selected_middle_slice","accepted_hand_material_contacts":hand_contacts,
		"minimum_hand_contact_count_met":final_middle.get("accepted_contact_constraints",false) and hand_contacts.size()>=3,
		"continuous_tangency_verified":false,"substep_tangency_measured":true,
		"actual_3d_grip_verified":false,"production_pose_written":false}

func _evaluate(context: Dictionary, saved: Dictionary, angles: Dictionary, placement: Vector2,
		digit: StringName, requested_radius: float, palm_required: bool, reuse: Dictionary = {}, guide_kind: StringName = &"circle") -> Dictionary:
	var candidate: Dictionary
	var skin: Dictionary
	if reuse.is_empty():
		var start := Time.get_ticks_usec()
		var phase := Chronology.begin("preparation.sample.candidate", _trace_context(digit)) if _recording else 0
		candidate = _candidate.evaluate(context.adapter, angles, Vector3.ZERO, ROOT)
		_end_observation(phase,candidate)
		_metrics.candidate_ms += float(Time.get_ticks_usec()-start)/1000.0
		if not candidate.get("valid", false): return candidate
		var state: Dictionary = candidate.digit_states[digit]
		start = Time.get_ticks_usec()
		phase = Chronology.begin("preparation.sample.skin_slice", _trace_context(digit)) if _recording else 0
		skin = _observer.slice_candidate(context.observations[digit],candidate,state.plane_to_world,state.plane_origin_id)
		_end_observation(phase,skin)
		if not skin.get("valid",false): return skin
		if palm_required or guide_kind == &"saved_wrapper":
			phase = Chronology.begin("preparation.sample.palm_annotation", _trace_context(digit)) if _recording else 0
			skin = _palm.annotate(context.palm_region,candidate,skin,state.plane_to_world)
			_end_observation(phase,skin)
			if not skin.get("valid",false): return skin
		_metrics.skin_ms += float(Time.get_ticks_usec()-start)/1000.0
		_metrics.skin_evaluations += 1
	else:
		candidate = reuse.candidate; skin = reuse.skin
	var world: Vector3 = context.translation_u_world*placement.x+context.translation_v_world*placement.y
	var key := str(digit)+":"+var_to_bytes(world).hex_encode()
	_metrics.section_queries += 1
	var sections: Dictionary
	if _cache.has(key):
		sections = _cache[key]
		_metrics.section_cache_hits += 1
		if _recording: Chronology.event("preparation.sample.section_cache_hit", _trace_context(digit))
	else:
		var start := Time.get_ticks_usec()
		var phase := Chronology.begin("preparation.sample.weapon_sections", _trace_context(digit)) if _recording else 0
		sections = _sections.slice(saved,world,ROOT,[digit])
		_end_observation(phase,sections)
		_metrics.section_slice_ms += float(Time.get_ticks_usec()-start)/1000.0
		_cache[key] = sections
	if not sections.get("valid",false): return sections
	var section: Dictionary = sections.digits[digit]
	var radius: float = maxf(requested_radius,section.required_enclosing_radius_m)
	if guide_kind == &"saved_wrapper":
		return _wrapper_sample({"valid":true,"angles":angles.duplicate(true),"placement":placement,
			"candidate":candidate,"skin":skin,"sections":sections,"section":section,"digit":digit,
			"radius_m":radius,"enclosing_radius_m":section.required_enclosing_radius_m,
			"palm_required":palm_required,"guide_kind":guide_kind})
	var circle_span := Chronology.begin("preparation.sample.circle_contact", _trace_context(digit)) if _recording else 0
	var measured := _circle.evaluate(skin.segments,section.center,radius,section.origin_id,&"GripPreparationGuide")
	_end_observation(circle_span,measured)
	if not measured.get("valid",false): return measured
	var rows: Array = []
	var max_error := 0.0
	var cost := 0.0
	for owner: int in ([1,2] if digit == &"thumb" else [0,1,2]):
		var best: Dictionary = {}
		for index: int in skin.segments.size():
			if skin.segments[index].section_owner != owner: continue
			var witness: Dictionary = measured.segments[index]
			if witness.tangent_ambiguous: continue
			if best.is_empty() or witness.signed_clearance_m < best.witness.signed_clearance_m:
				best = {"segment":skin.segments[index],"witness":witness,"section":owner+1,"required":true}
		if best.is_empty(): return _fail("required_skin_section_unavailable",{"digit":digit,"section":owner+1})
		best["residual"] = best.witness.signed_clearance_m-CLEARANCE_M
		max_error = maxf(max_error,absf(best.residual)); cost += best.residual*best.residual
		rows.append(best)
	var palm_found := not palm_required
	if palm_required:
		var best: Dictionary = {}
		for index: int in skin.segments.size():
			if not skin.segments[index].get("palm_owned",false): continue
			var witness: Dictionary = measured.segments[index]
			if witness.tangent_ambiguous: continue
			if best.is_empty() or witness.signed_clearance_m < best.witness.signed_clearance_m:
				best = {"segment":skin.segments[index],"witness":witness,"section":0,"required":true}
		if not best.is_empty():
			best["residual"] = best.witness.signed_clearance_m-CLEARANCE_M
			max_error=maxf(max_error,absf(best.residual));cost+=best.residual*best.residual
			rows.append(best);palm_found=true
	# Keep all measured skin outside the guide, including unclassified tissue.
	# An inequality joins the projection only when violated; it is not palm.
	var worst: Dictionary = measured.segments[measured.nearest_segment_index]
	if worst.signed_clearance_m < -NUMERIC_GUARD_M:
		rows.append({"segment":skin.segments[measured.nearest_segment_index],"witness":worst,
			"section":-1,"required":false,"residual":worst.signed_clearance_m-CLEARANCE_M})
		cost += 4.0*pow(worst.signed_clearance_m-CLEARANCE_M,2.0)
	return {"valid":true,"angles":angles.duplicate(true),"placement":placement,"candidate":candidate,"skin":skin,
		"guide_kind":&"circle","material_assessed":false,
		"sections":sections,"section":section,"digit":digit,"rows":rows,"radius_m":radius,
		"enclosing_radius_m":section.required_enclosing_radius_m,"cost":cost,"max_contact_error_m":max_error,
		"max_guide_depth_m":measured.maximum_inward_depth_m,"palm_required":palm_required,
		"attached":max_error <= CONTACT_BAND_M and measured.maximum_inward_depth_m <= NUMERIC_GUARD_M and palm_found}

func _wrapper_sample(sample: Dictionary) -> Dictionary:
	var start := Time.get_ticks_usec()
	var phase := Chronology.begin("preparation.sample.prepare_saved_contact", _trace_context(sample.digit)) if _recording else 0
	var prepared: Dictionary = _saved_contact.prepare(sample.section)
	_end_observation(phase,prepared)
	if not prepared.get("valid",false): return prepared
	phase = Chronology.begin("preparation.sample.saved_contact", _trace_context(sample.digit)) if _recording else 0
	var measured: Dictionary = _saved_contact.evaluate(prepared,sample.skin.segments,sample.section.origin_id)
	_end_observation(phase,measured)
	_metrics["wrapper_measurement_ms"] = float(_metrics.get("wrapper_measurement_ms",0.0)) + float(Time.get_ticks_usec()-start)/1000.0
	if not measured.get("valid",false): return measured
	for field: String in ["material_measurement_ms","guide_measurement_ms","witness_normalization_ms"]:
		_metrics[field]=float(_metrics.get(field,0.0))+float(measured[field])
	_metrics["target_preparation_ms"]=float(_metrics.get("target_preparation_ms",0.0))+float(prepared.preparation_ms)
	var rows: Array = []
	var regions := {}
	var required: Array = [2,3] if sample.digit == &"thumb" else [1,2,3]
	if sample.palm_required: required.append(0)
	for section: int in required:
		regions[section] = {"section":section,"best":{},"material_gap_m":INF,
			"material_depth_upper_m":0.0,"cap_m":INF,"material_safe":true}
	var material_safe := true
	var guide_safe := true
	var guide_depth := 0.0
	var cost := 0.0
	var blockers: Array = []
	for index: int in measured.segments.size():
		var record: Dictionary = measured.segments[index]
		var edge: Dictionary = record.segment
		var section: int = int(edge.section_owner)+1 if int(edge.section_owner)>=0 else (0 if edge.get("palm_owned",false) else -1)
		var cap: float = float(edge.max_inward_depth_m) if not edge.get("allowance_unassigned",true) else 0.0
		var excess: float = maxf(record.depth_upper_m-cap,0.0)
		var guide_excess: float = maxf(record.guide_depth_upper_m-cap,0.0)
		var material_ok: bool = record.material_constraint_safe
		var guide_ok: bool = record.guide_constraint_safe
		material_safe = material_safe and material_ok
		guide_safe = guide_safe and guide_ok
		if not material_ok or not guide_ok:
			blockers.append({"section":section,"source_id":edge.source_id,"cap_m":cap,
				"material_status":record.material_cap_status,"guide_status":record.guide_cap_status,
				"material_safe":material_ok,"guide_safe":guide_ok,
				"material_lower_m":record.depth_lower_m,"material_upper_m":record.depth_upper_m,
				"guide_lower_m":record.guide_depth_lower_m,"guide_upper_m":record.guide_depth_upper_m})
		guide_depth=maxf(guide_depth,record.guide_depth_upper_m)
		if regions.has(section):
			var region: Dictionary = regions[section]
			region.material_gap_m=minf(region.material_gap_m,record.material_gap_m)
			region.material_depth_upper_m=maxf(region.material_depth_upper_m,record.depth_upper_m)
			region.cap_m=minf(region.cap_m,cap)
			region.material_safe=region.material_safe and material_ok
			var witness: Dictionary = record.witness
			if not witness.get("gradient_ambiguous",true) and (region.best.is_empty() or witness.signed_clearance_m < region.best.witness.signed_clearance_m):
				region.best={"segment":edge,"witness":witness,"section":section,"required":true,
					"measurement_index":index,"metric":&"guide","residual":witness.signed_clearance_m-CLEARANCE_M}
		if not material_ok:
			var witness: Dictionary = record.material_witness
			# A loose upper bound is not a penetration witness. Never respond to
			# uncertainty by pulling a safely sampled point further inward.
			if record.depth_lower_m>cap and not witness.get("gradient_ambiguous",true):
				rows.append({"segment":edge,"witness":witness,"section":-1,"required":false,
					"measurement_index":index,"metric":&"material","residual":record.material_gap_m+cap})
			cost+=64.0*excess*excess
		if not guide_ok:
			if record.guide_depth_lower_m>cap and not record.witness.get("gradient_ambiguous",true):
				rows.append({"segment":edge,"witness":record.witness,"section":-1,"required":false,
					"measurement_index":index,"metric":&"guide","residual":record.guide_gap_m+cap})
			cost+=64.0*guide_excess*guide_excess
	var contacts: Array = []
	var max_error := 0.0
	for section: int in required:
		var region: Dictionary = regions[section]
		if region.best.is_empty(): return _fail("saved_wrapper_contact_witness_unavailable",{"digit":sample.digit,"section":section})
		rows.append(region.best)
		cost+=pow(float(region.best.residual),2.0)
		max_error=maxf(max_error,absf(region.best.residual))
		region["material_contact"]=region.material_safe and region.material_gap_m<=NUMERIC_GUARD_M
		if region.material_contact: contacts.append("palm" if section==0 else str(sample.digit)+"/S"+str(section))
	sample.merge({"rows":rows,"regions":regions,"records":measured.segments,"material_assessed":true,
		"material_safe":material_safe,"guide_safe":guide_safe,"material_contacts":contacts,"cost":cost,"max_contact_error_m":max_error,
		"max_guide_depth_m":guide_depth,"wrapper_target_selected":true,"constraint_blockers":blockers,
		"attached":material_safe and guide_safe and max_error<=CONTACT_BAND_M,
		"accepted_contact_constraints":material_safe and guide_safe,
		"material_condition_met":material_safe and guide_safe and contacts.size()>=mini(3,required.size())},true)
	return sample

func _complete(sample: Dictionary) -> bool:
	return sample.get("material_condition_met",false) if sample.get("guide_kind",&"circle")==&"saved_wrapper" else sample.attached

func _project(context: Dictionary,saved: Dictionary,seed: Dictionary,radius: float,movable: bool,palm: bool,
        guide_kind: StringName = &"circle", retain_material: Array = [], settle: bool = false) -> Dictionary:
	var span := Chronology.begin("preparation.response.cycle", {"job_id":str(get_instance_id()),"slot":_recording_slot,
		"digit":seed.digit,"radius_m":radius,"movable_weapon":movable,"palm_required":palm,
		"guide_kind":guide_kind,"reseat":settle,"iteration_limit":PROJECTION_ITERATIONS}) if _recording else 0
	var iteration_span := 0
	var current := _evaluate(context,saved,seed.angles,seed.placement,seed.digit,radius,palm,{},guide_kind)
	if not current.get("valid",false): return _response_observed(span,iteration_span,{"sample":seed,"converged":false,"reason":current.get("reason"),"detail":current})
	for iteration: int in PROJECTION_ITERATIONS:
		if _complete(current) and not settle: return _response_observed(span,iteration_span,{"sample":current,"converged":true,"reason":"material_contact_condition" if guide_kind==&"saved_wrapper" else "all_requested_sections_tangent"})
		iteration_span = Chronology.begin("preparation.response.iteration", {"job_id":str(get_instance_id()),
			"slot":_recording_slot,"digit":current.digit,"iteration":iteration,"guide_kind":guide_kind,"reseat":settle}) if _recording else 0
		_metrics.projection_iterations += 1
		var count := 5 if movable else 3
		var matrix: Array = []; var rhs: Array = []
		for column: int in count:
			var row: Array = [];row.resize(count);row.fill(0.0);row[column]=0.00000001
			matrix.append(row);rhs.append(0.0)
		var probes: Array = []
		if movable:
			for coordinate: int in 2:
				var probe: Dictionary = {}
				var probe_step := PLACEMENT_PROBE_M
				for direction: float in [1.0,-1.0]:
					probe_step = PLACEMENT_PROBE_M * direction
					var point: Vector2 = current.placement;point[coordinate]+=probe_step
					probe = _evaluate(context,saved,current.angles,point,current.digit,radius,palm,current,guide_kind)
					if probe.get("valid",false): break
					_event({"event":"invalid_derivative_neighbour","digit":current.digit,
						"placement":point,"coordinate":coordinate,"detail":probe})
				if not probe.get("valid",false): return _response_observed(span,iteration_span,{"sample":current,"converged":false,"reason":"invalid_translation_probe_both_sides","detail":probe})
				probes.append({"sample":probe,"step":probe_step})
		for contact: Dictionary in current.rows:
			var differentiated := _contact_gradient(contact,current,probes,guide_kind)
			if not differentiated.get("valid",false):
				_event({"event":"skin_derivative_unresolved","digit":current.digit,"detail":differentiated})
				return _response_observed(span,iteration_span,{"sample":current,"converged":false,"reason":"analytic_skin_derivative_unavailable"})
			var gradient: Array = differentiated.gradient
			var weight := 1.0 if contact.required else (64.0 if guide_kind==&"saved_wrapper" else 4.0)
			for first: int in count:
				rhs[first] -= weight*gradient[first]*contact.residual
				for second: int in count: matrix[first][second]+=weight*gradient[first]*gradient[second]
		var snapshot: Dictionary = context.adapter.digit_inputs[current.digit].snapshot
		var delta: Array
		if guide_kind==&"saved_wrapper" and current.accepted_contact_constraints:
			var phase := Chronology.begin("preparation.response.constraint_derivatives", _trace_context(current.digit)) if _recording else 0
			var bounded := _wrapper_constraints(current,probes,snapshot,count)
			_end_observation(phase,bounded)
			if not bounded.get("valid",false): return _response_observed(span,iteration_span,{"sample":current,"converged":_complete(current),"reason":"contact_constraint_derivative_unavailable","detail":bounded})
			phase = Chronology.begin("preparation.response.constrained_step", _trace_context(current.digit)) if _recording else 0
			var response := _constrained_linear(matrix,rhs,bounded.constraints)
			_end_observation(phase,response)
			if not response.get("valid",false): return _response_observed(span,iteration_span,{"sample":current,"converged":_complete(current),"reason":"constrained_contact_step_unresolved","detail":response})
			delta=response.delta
			_metrics["constrained_contact_steps"]=int(_metrics.get("constrained_contact_steps",0))+1
		else:
			var phase := Chronology.begin("preparation.response.bound_step", _trace_context(current.digit)) if _recording else 0
			delta=_active_bound_linear(matrix,rhs,current.angles[current.digit],snapshot)
			if phase != 0: Chronology.finish(phase,{"delta_available":not delta.is_empty()})
		if delta.is_empty(): return _response_observed(span,iteration_span,{"sample":current,"converged":false,"reason":"singular_contact_response"})
		var norm := 1.0
		for value: float in delta: norm=maxf(norm,absf(value))
		var accepted := false
		var material_blocked := false
		var rejected_constraints: Array = []
		var fractions: Array = [1.0,0.5,0.25,0.125,0.0625,0.03125,0.015625] if guide_kind==&"saved_wrapper" else [1.0,0.5,0.25,0.125]
		for fraction: float in fractions:
			var angles: Dictionary = current.angles.duplicate(true)
			for joint: int in 3: angles[current.digit][joint]=clampf(angles[current.digit][joint]+delta[joint]/norm*fraction*ANGLE_SCALE,snapshot.min_angles_rad[joint],snapshot.max_angles_rad[joint])
			var placement: Vector2 = current.placement
			if movable: placement += Vector2(delta[3],delta[4])/norm*fraction*TRANSLATION_SCALE
			if placement.length()>MAX_TRANSLATION_M:
				if _recording: Chronology.event("preparation.response.trial_skipped",{"reason":"placement_limit","fraction":fraction,"digit":current.digit})
				continue
			var trial_span := Chronology.begin("preparation.response.trial",{"slot":_recording_slot,"digit":current.digit,
				"iteration":iteration,"fraction":fraction,"guide_kind":guide_kind,"reseat":settle}) if _recording else 0
			var trial := _evaluate(context,saved,angles,placement,current.digit,radius,palm,{},guide_kind)
			if not trial.get("valid",false):
				_end_observation(trial_span,trial,{"accepted":false,"outcome":"invalid_sample"})
				continue
			if guide_kind==&"saved_wrapper":
				if current.accepted_contact_constraints and not trial.accepted_contact_constraints:
					material_blocked=true
					rejected_constraints=trial.constraint_blockers
					_end_observation(trial_span,trial,{"accepted":false,"outcome":"material_constraints"})
					continue
				var retained := true
				for id: String in retain_material: retained=retained and trial.material_contacts.has(id)
				if not retained:
					_end_observation(trial_span,trial,{"accepted":false,"outcome":"lost_retained_contact"})
					continue
			if trial.cost < current.cost - 1e-14:
				_end_observation(trial_span,trial,{"accepted":true,"outcome":"improving_response"})
				current=trial;accepted=true;break
			_end_observation(trial_span,trial,{"accepted":false,"outcome":"no_cost_improvement"})
		if not accepted:
			return _response_observed(span,iteration_span,{"sample":current,"converged":_complete(current),"reason":"material_constraints_reject_proposed_direction" if material_blocked else "no_improving_coupled_response",
				"detail":{"rejected_constraints":rejected_constraints}})
		_end_observation(iteration_span,current,{"accepted":true,"outcome":"improving_response"})
		iteration_span=0
	return _response_observed(span,iteration_span,{"sample":current,"converged":_complete(current),"reason":"projection_budget_not_physical_limit"})

func _contact_gradient(contact: Dictionary,current: Dictionary,probes: Array,kind: StringName) -> Dictionary:
	var derivative: Dictionary
	var normal: Vector2
	if kind==&"circle":
		derivative=_jacobian.evaluate(_derivatives[current.digit],current.candidate,contact.segment,contact.witness)
		normal=contact.witness.circle_outward_normal
	else:
		derivative=_jacobian.evaluate_point(_derivatives[current.digit],current.candidate,contact.segment,contact.witness.skin_segment_t)
		normal=contact.witness.target_outward_normal
	if not derivative.get("valid",false): return derivative
	var gradient: Array=[]
	for joint: int in 3: gradient.append(normal.dot(derivative.derivatives_m_per_rad[joint])*ANGLE_SCALE)
	for probe: Dictionary in probes:
		var slope: float
		if kind==&"circle":
			var center_change: Vector2=(probe.sample.section.center-current.section.center)/probe.step
			slope=-normal.dot(center_change)-(probe.sample.radius_m-current.radius_m)/probe.step
		else:
			var field: String="guide_gap_m" if contact.metric==&"guide" else "material_gap_m"
			slope=(probe.sample.records[contact.measurement_index][field]-current.records[contact.measurement_index][field])/probe.step
		gradient.append(slope*TRANSLATION_SCALE)
	return {"valid":true,"gradient":gradient}

func _wrapper_constraints(current: Dictionary,probes: Array,snapshot: Dictionary,count: int) -> Dictionary:
	var constraints: Array=[]
	# Constrain inward motion, leaving tangent directions and other hinges free.
	# A conservative response margin is subtracted; caps are never enlarged.
	for index: int in current.records.size():
		var record: Dictionary=current.records[index]
		var cap: float=record.max_inward_depth_m
		for metric: StringName in [&"material",&"guide"]:
			var witness: Dictionary=record.material_witness if metric==&"material" else record.witness
			if witness.gradient_ambiguous: continue # Full nonlinear checks still apply.
			var row := {"segment":record.segment,"witness":witness,"metric":metric,"measurement_index":index}
			var differentiated := _contact_gradient(row,current,probes,&"saved_wrapper")
			if not differentiated.get("valid",false):
				# Tiny/nonsmooth slice fragments cannot supply a local normal row.
				# They remain in every complete nonlinear cap check; this omits
				# only their linear prediction, never their physical constraint.
				if not _metrics.has("unlinearized_constraint_reasons"): _metrics["unlinearized_constraint_reasons"]={}
				var reason: String=str(differentiated.get("reason","unavailable"))
				var counts: Dictionary=_metrics.unlinearized_constraint_reasons
				counts[reason]=int(counts.get(reason,0))+1
				continue
			var gap: float=record.material_gap_m if metric==&"material" else record.guide_gap_m
			var upper: float=record.depth_upper_m if metric==&"material" else record.guide_depth_upper_m
			var margin: float=maxf((cap-upper if gap<0.0 else cap+gap)-NUMERIC_GUARD_M,0.0)
			constraints.append({"gradient":differentiated.gradient,"minimum":-margin,"id":str(metric)+":"+str(index)})
	for coordinate: int in count:
		var positive: Array=[];positive.resize(count);positive.fill(0.0);positive[coordinate]=1.0
		var negative: Array=positive.duplicate();negative[coordinate]=-1.0
		var lower := -1.0
		var upper := 1.0
		if coordinate<3:
			lower=maxf(lower,(snapshot.min_angles_rad[coordinate]-current.angles[current.digit][coordinate])/ANGLE_SCALE)
			upper=minf(upper,(snapshot.max_angles_rad[coordinate]-current.angles[current.digit][coordinate])/ANGLE_SCALE)
		constraints.append({"gradient":positive,"minimum":lower,"id":"lower:"+str(coordinate)})
		constraints.append({"gradient":negative,"minimum":-upper,"id":"upper:"+str(coordinate)})
	return {"valid":true,"constraints":constraints}

func _active_bound_linear(matrix: Array,rhs: Array,angles: Array,snapshot: Dictionary) -> Array:
	var fixed: Dictionary = {}
	for attempt: int in 4:
		# _linear performs elimination in place. Each retry starts from unchanged
		# contact equations, not the eliminated matrix from the previous attempt.
		var system: Array = matrix.duplicate(true)
		var target: Array = rhs.duplicate()
		for joint: int in fixed:
			for column: int in target.size():
				system[joint][column]=0.0
				system[column][joint]=0.0
			system[joint][joint]=1.0
			target[joint]=0.0
		var delta: Array = _linear(system,target)
		if delta.is_empty(): return []
		var added := false
		for joint: int in 3:
			if fixed.has(joint): continue
			var at_min: bool = float(angles[joint]) <= float(snapshot.min_angles_rad[joint]) + 1.0e-10
			var at_max: bool = float(angles[joint]) >= float(snapshot.max_angles_rad[joint]) - 1.0e-10
			if (at_min and float(delta[joint]) < 0.0) or (at_max and float(delta[joint]) > 0.0):
				fixed[joint]=true
				added=true
		if not added: return delta
		_metrics["active_bound_resolves"]=int(_metrics.get("active_bound_resolves",0))+1
	return []

func _constrained_linear(matrix: Array, rhs: Array, constraints: Array) -> Dictionary:
	# Convex local step: min 0.5*x'H*x-rhs'x, subject to a*x >= minimum.
	# Dual active set: entering a boundary may RELEASE a previous multiplier.
	# No physical allowance is changed here; the caller still validates geometry.
	var n: int = rhs.size()
	var rows: Array = []
	var active: Array = []
	var multipliers: Array = []
	var counters := {"iterations":0, "releases":0}
	var reject: Callable = func(reason: String) -> Dictionary:
		var indices: Array = []
		for index: int in active: indices.append(rows[index].input_index)
		return {"valid":false, "delta":[], "reason":reason, "active_indices":indices,
			"iterations":counters.iterations, "releases":counters.releases}
	if n < 1 or n > 5 or matrix.size() != n:
		return reject.call("invalid_contact_system_size")
	var matrix_scale: float = 0.0
	for row: int in n:
		if not matrix[row] is Array or matrix[row].size() != n:
			return reject.call("invalid_contact_matrix_row")
		if not (rhs[row] is float or rhs[row] is int) or not is_finite(float(rhs[row])):
			return reject.call("nonfinite_contact_rhs")
		for column: int in n:
			var entry: Variant = matrix[row][column]
			if not (entry is float or entry is int) or not is_finite(float(entry)):
				return reject.call("nonfinite_contact_matrix")
			matrix_scale = maxf(matrix_scale, absf(float(entry)))
	if matrix_scale == 0.0: return reject.call("contact_matrix_not_positive_definite")
	var hessian: Array = []
	var target: Array = []
	var cholesky: Array = []
	for row: int in n:
		var hessian_row: Array = []
		var lower_row: Array = []
		for column: int in n:
			var forward: float = float(matrix[row][column]) / matrix_scale
			var backward: float = float(matrix[column][row]) / matrix_scale
			if absf(forward-backward) > 1.0e-12:
				return reject.call("contact_matrix_not_symmetric")
			hessian_row.append(0.5 * (forward+backward))
			lower_row.append(0.0)
		hessian.append(hessian_row)
		cholesky.append(lower_row)
		target.append(float(rhs[row]) / matrix_scale)
		if not is_finite(target[-1]): return reject.call("contact_rhs_scale_unresolved")
	# Reject indefinite/poorly resolved equations rather than return a fake optimum.
	for row: int in n:
		for column: int in range(row+1):
			var pivot: float = hessian[row][column]
			for previous: int in column: pivot -= cholesky[row][previous] * cholesky[column][previous]
			if row == column:
				if pivot <= 1.0e-14: return reject.call("contact_matrix_not_positive_definite_or_resolved")
				cholesky[row][column] = sqrt(pivot)
			else:
				cholesky[row][column] = pivot / cholesky[column][column]
	var delta: Array = _linear(hessian.duplicate(true), target.duplicate())
	if delta.is_empty(): return reject.call("contact_system_singular")
	for value: float in delta:
		if not is_finite(value): return reject.call("nonfinite_unconstrained_contact_step")
	for index: int in constraints.size():
		if not constraints[index] is Dictionary: return reject.call("invalid_contact_constraint")
		var constraint: Dictionary = constraints[index]
		if not constraint.get("gradient") is Array or constraint.gradient.size() != n:
			return reject.call("invalid_contact_constraint_gradient")
		if not (constraint.get("minimum") is float or constraint.get("minimum") is int) or not is_finite(float(constraint.minimum)):
			return reject.call("nonfinite_contact_constraint_minimum")
		var largest: float = 0.0
		for value: Variant in constraint.gradient:
			if not (value is float or value is int) or not is_finite(float(value)):
				return reject.call("nonfinite_contact_constraint_gradient")
			largest = maxf(largest, absf(float(value)))
		if largest == 0.0:
			if float(constraint.minimum) > 0.0: return reject.call("infeasible_zero_contact_constraint")
			continue
		var squared: float = 0.0
		for value: float in constraint.gradient: squared += (value/largest) * (value/largest)
		var length_scaled: float = sqrt(squared)
		var gradient: Array = []
		for value: float in constraint.gradient: gradient.append((value/largest) / length_scaled)
		var minimum: float = (float(constraint.minimum)/largest) / length_scaled
		if not is_finite(minimum): return reject.call("contact_constraint_scale_unresolved")
		var inverse_normal: Array = _linear(hessian.duplicate(true), gradient.duplicate())
		if inverse_normal.is_empty(): return reject.call("contact_inverse_normal_unresolved")
		for value: float in inverse_normal:
			if not is_finite(value): return reject.call("nonfinite_contact_inverse_normal")
		rows.append({"gradient":gradient, "minimum":minimum, "inverse_normal":inverse_normal,
			"input_index":index, "tolerance":1.0e-10 * (1.0+absf(minimum))})
	var pending: int = -1
	var pending_multiplier: float = 0.0
	var budget: int = maxi(32, mini(256, 4 * (rows.size()+n)))
	for iteration: int in budget:
		counters.iterations = iteration+1
		if pending < 0:
			# Stable input order also permits reproducible multiplier-release tests.
			for index: int in rows.size():
				var achieved: float = 0.0
				for column: int in n: achieved += rows[index].gradient[column] * delta[column]
				if achieved < rows[index].minimum - rows[index].tolerance:
					if active.has(index): return reject.call("active_contact_equality_drift")
					pending = index
					pending_multiplier = 0.0
					break
			if pending < 0:
				# Certify primal feasibility, dual signs, active equalities and stationarity.
				# These are numerical tolerances in unit-normalized local-step variables.
				var indices: Array = []
				for position: int in active.size():
					var boundary: Dictionary = rows[active[position]]
					var achieved: float = 0.0
					for column: int in n: achieved += boundary.gradient[column] * delta[column]
					if multipliers[position] < 0.0 or absf(achieved-boundary.minimum) > 10.0 * boundary.tolerance:
						return reject.call("contact_kkt_boundary_unresolved")
					indices.append(boundary.input_index)
				for row: int in n:
					var residual: float = -target[row]
					var magnitude: float = absf(target[row])
					for column: int in n:
						var contribution: float = hessian[row][column] * delta[column]
						residual += contribution
						magnitude += absf(contribution)
					for position: int in active.size():
						var contribution: float = multipliers[position] * rows[active[position]].gradient[row]
						residual -= contribution
						magnitude += absf(contribution)
					if not is_finite(residual) or absf(residual) > 1.0e-9 * (1.0+magnitude):
						return reject.call("contact_kkt_stationarity_unresolved")
				return {"valid":true, "delta":delta, "reason":"constrained_contact_optimum",
					"active_indices":indices, "iterations":counters.iterations,
					"releases":counters.releases, "normalized_multipliers":multipliers.duplicate()}
		var entering: Dictionary = rows[pending]
		var gram: Array = []
		var projected_rhs: Array = []
		var gram_scale: float = 0.0
		for first: int in active.size():
			var gram_row: Array = []
			var inner: float = 0.0
			for column: int in n: inner += rows[active[first]].gradient[column] * entering.inverse_normal[column]
			projected_rhs.append(inner)
			for second: int in active.size():
				inner = 0.0
				for column: int in n: inner += rows[active[first]].gradient[column] * rows[active[second]].inverse_normal[column]
				gram_row.append(inner)
				gram_scale = maxf(gram_scale, absf(inner))
			gram.append(gram_row)
		var dual_direction: Array = []
		if not active.is_empty():
			if gram_scale == 0.0: return reject.call("active_contact_rank_unresolved")
			for row: int in active.size():
				projected_rhs[row] /= gram_scale
				for column: int in active.size(): gram[row][column] /= gram_scale
			dual_direction = _linear(gram, projected_rhs)
			if dual_direction.is_empty(): return reject.call("active_contact_rank_unresolved")
		var direction: Array = entering.inverse_normal.duplicate()
		for position: int in active.size():
			if not is_finite(dual_direction[position]): return reject.call("nonfinite_contact_dual_direction")
			for column: int in n: direction[column] -= rows[active[position]].inverse_normal[column] * dual_direction[position]
		var denominator: float = 0.0
		var unprojected: float = 0.0
		var gap: float = entering.minimum
		for column: int in n:
			denominator += entering.gradient[column] * direction[column]
			unprojected += entering.gradient[column] * entering.inverse_normal[column]
			gap -= entering.gradient[column] * delta[column]
		if not is_finite(denominator) or unprojected <= 0.0 or denominator < -1.0e-10 * unprojected:
			return reject.call("contact_projected_metric_unresolved")
		var primal_step: float = INF
		if active.size() < n and denominator > 1.0e-12 * unprojected:
			primal_step = maxf(0.0, gap) / denominator
		var dual_step: float = INF
		var leaving: int = -1
		for position: int in active.size():
			if dual_direction[position] > 1.0e-12:
				var candidate: float = multipliers[position] / dual_direction[position]
				if candidate < dual_step:
					dual_step = candidate
					leaving = position
		var step: float = minf(primal_step, dual_step)
		if not is_finite(step): return reject.call("infeasible_or_dependent_contact_constraints_unresolved")
		if step < 0.0: return reject.call("negative_contact_dual_step")
		for column: int in n:
			delta[column] += step * direction[column]
			if not is_finite(delta[column]): return reject.call("nonfinite_constrained_contact_step")
		for position: int in active.size():
			multipliers[position] = maxf(0.0, multipliers[position] - step * dual_direction[position])
		pending_multiplier += step
		if not is_finite(pending_multiplier): return reject.call("nonfinite_contact_multiplier")
		if primal_step <= dual_step:
			if active.size() >= n: return reject.call("contact_active_rank_exceeds_dof")
			active.append(pending)
			multipliers.append(pending_multiplier)
			pending = -1
		else:
			if leaving < 0: return reject.call("contact_dual_release_unresolved")
			active.remove_at(leaving)
			multipliers.remove_at(leaving)
			counters.releases += 1
	return reject.call("contact_active_set_budget_exhausted")

func _linear(a: Array,b: Array) -> Array:
	var n := b.size()
	for pivot: int in n:
		var best := pivot
		for row: int in range(pivot+1,n):
			if absf(a[row][pivot])>absf(a[best][pivot]):best=row
		if absf(a[best][pivot])<1e-16:return []
		var swap: Array=a[pivot];a[pivot]=a[best];a[best]=swap
		var value: float=b[pivot];b[pivot]=b[best];b[best]=value
		var divisor: float=a[pivot][pivot]
		for col: int in range(pivot,n):a[pivot][col]/=divisor
		b[pivot]/=divisor
		for row: int in n:
			if row==pivot:continue
			var factor: float=a[row][pivot]
			for col: int in range(pivot,n):a[row][col]-=factor*a[pivot][col]
			b[row]-=factor*b[pivot]
	return b

func _record(sample: Dictionary,label: String,committed: bool) -> void:
	var record:=_public(sample)
	record["label"]=label;record["committed_contact_state"]=committed;record["sweep"]=_trace.size()
	_trace.append(record)
	if _recording:
		var data := _trace_context(sample.digit)
		data.merge({"label":label,"stage_index":_trace.size()-1,"committed":committed,
			"guide_kind":sample.get("guide_kind",""),"radius_m":sample.get("radius_m",0.0),
			"cost":sample.get("cost",0.0),"material_contacts":sample.get("material_contacts",[])})
		Chronology.event("preparation.recorded_stage",data)

## Observer payloads remain scalar and never enter geometry packets or cache keys.
func _trace_context(digit: StringName = &"") -> Dictionary:
	return {"job_id":str(get_instance_id()),"slot":_recording_slot,"digit":digit}

func _end_observation(span: int, result: Dictionary, extra: Dictionary = {}) -> void:
	if span == 0: return
	var data := _trace_context()
	for key: String in ["valid","reason","converged","cache_hit","material_safe","material_contacts",
			"accepted_contact_constraints","cost","depth_evaluations","material_depth_evaluations","guide_depth_evaluations"]:
		if result.has(key): data[key]=result[key]
	data.merge(extra,true)
	Chronology.finish(span,data)

func _response_observed(span: int, iteration_span: int, result: Dictionary) -> Dictionary:
	if span != 0:
		var sample: Dictionary=result.get("sample",{})
		var data := {"digit":sample.get("digit",""),"cost":sample.get("cost",0.0),
			"material_contacts":sample.get("material_contacts",[]),"cycle_finished":true}
		_end_observation(iteration_span,result,data)
		_end_observation(span,result,data)
	return result

func _event(record: Dictionary) -> void:
	_events.append(record)
	if not _recording: return
	var data := _trace_context()
	for key: String in ["digit","held_digit","from_radius_m","requested_radius_m","converged",
			"reason","max_contact_error_m","attempt","improved","preserved_contacts","coordinate"]:
		if record.has(key): data[key]=record[key]
	Chronology.event("preparation."+str(record.event),data)

func _public(sample: Dictionary) -> Dictionary:
	var digit: StringName=sample.digit
	var state: Dictionary=sample.candidate.digit_states[digit]
	var regions: Array=[]
	for contact: Dictionary in sample.rows:
		if contact.section<0:continue
		var region := {"section":contact.section,"gap_m":contact.witness.signed_clearance_m,
			"nearest_unrestricted_gap_m":contact.witness.signed_clearance_m,"witness":contact.witness}
		if sample.get("material_assessed",false):
			for field: String in ["material_gap_m","material_depth_upper_m","cap_m","material_safe","material_contact"]:
				region[field]=sample.regions[contact.section][field]
		regions.append(region)
	var section: Dictionary=sample.section
	return {"radius_m":sample.radius_m,"placement":sample.placement,"max_contact_error_m":sample.max_contact_error_m,
		"guide_kind":sample.guide_kind,"material_assessed":sample.get("material_assessed",false),
		"wrapper_target_selected":sample.get("wrapper_target_selected",false),
		"material_safe":sample.get("material_safe",false),"material_contacts":sample.get("material_contacts",[]),
		"constraint_blockers":sample.get("constraint_blockers",[]),
		"accepted_contact_constraints":sample.get("accepted_contact_constraints",sample.attached),
		"guide_contacts":_contact_ids(sample),"all_required_tangent":sample.attached,
		"hand_to_world":sample.candidate.hand_to_world,"pose_origin_records":sample.candidate.pose_packet.origin_records,
		"weapon_origin_records":sample.sections.origin_records,"weapon_to_world":sample.sections.weapon_to_world,
		"hand_to_world_origin_id":ROOT,"weapon_to_world_origin_id":ROOT,
		"digits":[{"digit":digit,"angles_rad":state.angles_rad,"joints_world":state.joint_origins_world,
			"guide_kind":sample.guide_kind,"material_assessed":sample.get("material_assessed",false),
			"plane_to_world":state.plane_to_world,"origin_id":state.plane_origin_id,"skin_segments":sample.skin.segments,
			"center_m":section.center,"circle_center_m":section.center,"slice_center_m":section.center,
			"radius_m":sample.radius_m,"handle_polygon":section.handle.polygon,"wrapper_polygon":section.digit_target.polygon,
			"palm_polygon":section.palm_target.polygon,"regions":regions}],"grip_accepted":false}

func _contact_ids(sample: Dictionary) -> Array:
	var out: Array=[]
	for contact: Dictionary in sample.rows:
		if contact.required and absf(contact.residual)<=CONTACT_BAND_M:out.append(str(sample.digit)+"/S"+str(contact.section))
	return out

func _validate_context(context: Dictionary, saved: Dictionary) -> Dictionary:
	if saved.get("revision") != Sections.REVISION or not saved.get("source_geometry_frozen", false):
		return _fail("requires_current_frozen_saved_section_source")
	if not context.get("adapter") is Dictionary or not context.adapter.get("valid", false):
		return _fail("requires_validated_hand_adapter")
	if not context.get("observations") is Dictionary:
		return _fail("requires_prepared_digit_observations")
	if not context.get("palm_region") is Dictionary or not context.palm_region.get("valid",false):
		return _fail("requires_prepared_palmar_region")
	var adapter: Dictionary = context.adapter
	if context.get("vectors_origin_id") != ROOT or saved.get("vectors_origin_id") != ROOT:
		return _fail("missing_named_shared_placement_axes")
	for field: String in ["station_axis_world", "translation_u_world", "translation_v_world"]:
		if not context.get(field) is Vector3 or not context[field].is_finite() or absf(context[field].length_squared() - 1.0) > 0.00001:
			return _fail("invalid_shared_placement_axis", {"field": field})
	var axis: Vector3 = context.station_axis_world
	var u: Vector3 = context.translation_u_world
	var v: Vector3 = context.translation_v_world
	if absf(u.dot(axis)) > 0.00001 or absf(v.dot(axis)) > 0.00001 or absf(u.dot(v)) > 0.00001:
		return _fail("shared_placement_axes_not_transverse_orthogonal")
	if not saved.get("station_axis_world") is Vector3 or axis.distance_to(saved.station_axis_world) > 0.00001:
		return _fail("hand_context_saved_station_axis_mismatch")
	if not context.get("weapon_to_world") is Transform3D or not _same_hand(context.weapon_to_world, saved.weapon_to_world):
		return _fail("hand_context_saved_weapon_frame_mismatch")
	if not _same_hand(adapter.base_packet.machine_to_world, saved.machine_to_world) or adapter.base_packet.resolve_phase != saved.resolve_phase:
		return _fail("hand_context_saved_capture_frame_or_phase_mismatch")
	var signature: String = str(context.get("expected_source_body_signature", ""))
	if signature.is_empty() or signature != str(saved.get("source_body_signature", "")):
		return _fail("hand_context_saved_handle_source_mismatch")
	if not context.get("expected_contact_config") is Dictionary: return _fail("missing_independent_contact_configuration")
	var config: Dictionary = Wrapper.validate_config(context.expected_contact_config)
	if not config.get("valid", false) or config.config != saved.get("config", {}):
		return _fail("hand_context_saved_contact_configuration_mismatch")
	if adapter.anatomy_signature != config.config.get("anatomy_signature", ""):
		return _fail("hand_anatomy_saved_wrapper_configuration_mismatch")
	if not context.get("digit_order") is Array or context.digit_order.is_empty() or not saved.get("digits") is Dictionary:
		return _fail("missing_shared_digit_plane_layout")
	if context.digit_order.size() != saved.digits.size() or context.digit_order.size() != adapter.digit_inputs.size():
		return _fail("saved_and_hand_digit_layout_mismatch")
	if not context.get("open_parameters") is Array or context.open_parameters.size() != context.digit_order.size() * 3 + 2:
		return _fail("missing_open_digit_parameters")
	if not context.get("outward_parameters") is Vector2 or not context.outward_parameters.is_finite() or absf(context.outward_parameters.length_squared() - 1.0) > 0.00001:
		return _fail("missing_unit_outside_direction")
	var registry_result: Dictionary = HandSkin.new()._registry(saved.origin_records, saved.resolve_phase)
	if not registry_result.get("valid", false): return _fail("saved_origin_chain_invalid", registry_result)
	var registry: RefCounted = registry_result.registry
	var hand_origin := StringName(adapter.base_packet.bone_origin_ids.get(adapter.hand_bone_name, &""))
	if hand_origin == &"" or not registry.has_origin(hand_origin): return _fail("saved_chain_missing_selected_hand")
	var hand: Transform3D = saved.machine_to_world * registry.resolve_transform_to_machine(hand_origin)
	if not _same_hand(hand, adapter.baseline_hand_to_world): return _fail("saved_and_prepared_hand_frame_mismatch")
	var seen: Dictionary = {}
	for digit: Variant in context.digit_order:
		if not (digit is String or digit is StringName) or seen.has(digit) or not saved.digits.has(digit) or not adapter.digit_inputs.has(digit):
			return _fail("invalid_or_mixed_saved_digit_layout")
		seen[digit] = true
		var input: Dictionary = adapter.digit_inputs[digit]
		var fixed: Dictionary = saved.digits[digit]
		if input.plane_origin_id != fixed.origin_id or not _same_hand(input.plane_to_world, fixed.plane_to_world):
			return _fail("saved_and_prepared_digit_plane_mismatch", {"digit": digit})
		if not context.observations.has(digit) or context.observations[digit].anatomy_signature != adapter.anatomy_signature or context.observations[digit].source_pose_id != adapter.base_packet.pose_id:
			return _fail("mixed_skin_observation_epoch", {"digit": digit})
	return {"valid": true}



func _same_hand(before: Transform3D,after: Transform3D) -> bool:
	return before.origin.distance_to(after.origin)<=Native.FRAME_TOLERANCE and before.basis.is_equal_approx(after.basis)

func _fail(reason: String,detail: Dictionary={}) -> Dictionary:
	return {"valid":false,"revision":REVISION,"reason":reason,"detail":detail,"grip_accepted":false,"production_pose_written":false}
