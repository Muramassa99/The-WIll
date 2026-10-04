extends RefCounted

## Canonical acquisition operations. Tools delegate here; one numerical body.
const Candidate = preload("res://runtime/player/grip/prepared_hand_candidate_pose.gd")
const Observe = preload("res://runtime/player/grip/prepared_grip_slice_contact.gd")
const HandSkin = preload("res://runtime/player/grip/prepared_hand_skin_query.gd")
const Slicer = preload("res://runtime/player/grip/slice_reachable_surface.gd")
const Depth = preload("res://runtime/player/grip/planar_skin_overlap_budget.gd")
const Centroid = preload("res://core/resolvers/primary_grip_seat_resolver.gd")
const Profile = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const ROOT := &"RL_BoneRoot"
const CircleQuery = preload("res://runtime/player/grip/planar_circle_skin_contact.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const CLEARANCE_M: float = 0.00002
const NUMERIC_GUARD_M: float = 0.000002
const PreparedSection = preload("res://runtime/player/grip/prepared_weapon_plane_section.gd")
const CONTACT_BAND_M: float = 0.0001
const NativeContact = preload("res://runtime/player/grip/native_digit_contact_ik.gd")
const Progression = preload("res://runtime/player/grip/planar_grip_guide_progression.gd")
const PalmRegion = preload("res://runtime/player/grip/prepared_palmar_slice_region.gd")
const MAX_RESEATS: int = 3
const MIN_MATERIAL_SECTIONS: int = 3
const PREP_ITERATIONS: int = 12
const CONTACT_ITERATIONS: int = 24
const ExactDepthCache = preload("res://runtime/player/grip/exact_cached_planar_skin_overlap_budget.gd")
const Chronology = preload("res://runtime/player/grip/grip_chronology.gd")
var _builder := Candidate.new()
var _observer := Observe.new()
var _slice_cache: Dictionary = {}
var _circle_query := CircleQuery.new()
var _circle_cache: Dictionary = {}
var _circle_evaluations: int = 0
var _section_query := PreparedSection.new()
var _native := NativeContact.new()
var _native_calls: int = 0
var _config: Dictionary = {}
var _progression := Progression.new()
var _palm := PalmRegion.new()
var _depth := ExactDepthCache.new()
var _guide_phase: String = "circle"
var _guide_amount: float = 0.0
var _fixed_guides: Dictionary = {}
var _frozen_parameters: Array = []
var _guide_preparation_cache: Dictionary = {}
var _response_runs: Array = []
var _reseat_attempts: Array = []
var _preserve_guide: Array = []
var _preserve_material: Array = []
var _path_checks: int = 0

## A job owns one immutable capture and one serial numerical worker. Scene nodes
## are touched only by the native proposal on the main thread.
var _digits: Array[StringName] = [&"middle", &"thumb", &"index", &"ring", &"pinky"]
var _definition: Resource
var _capture_input: Dictionary = {}
var _prepared_context: Dictionary = {}
var _scene_host: Node
var _scene_tree: SceneTree
var _worker: Thread
var _state_mutex := Mutex.new()
var _cancel_requested: bool = false
var _running: bool = false
var _configured: bool = false
var _progress_state: Dictionary = {}
var _trace_callback: Callable
var _trace_enabled: bool = false
var _native_handle: Dictionary = {}

func configure(anatomy: Resource, capture: Dictionary, config: Dictionary, host: Node) -> Dictionary:
	if _running: return {"valid":false,"reason":"acquisition_already_running"}
	_configured=false
	if anatomy==null or not capture.get("posed_character") is Dictionary or not capture.get("object") is Dictionary:
		return {"valid":false,"reason":"missing_acquisition_input"}
	if capture.get("slot") not in [&"hand_right",&"hand_left"]:
		return {"valid":false,"reason":"invalid_acquisition_slot"}
	var checked: Dictionary = _configure_common(config,host)
	if not checked.valid: return checked
	_definition=anatomy
	_capture_input=capture
	_prepared_context={}
	_configured=true
	return {"valid":true}

## Tool-only seam: already validated preparation, same canonical process.
func configure_prepared(context: Dictionary, config: Dictionary, host: Node, digits: Array[StringName], trace: Callable = Callable()) -> Dictionary:
	if _running: return {"valid":false,"reason":"acquisition_already_running"}
	_configured=false
	if not context.get("valid",false): return {"valid":false,"reason":"invalid_prepared_context"}
	var supplied: Dictionary = config.duplicate()
	supplied["selected_digits"]=digits
	var checked: Dictionary = _configure_common(supplied,host)
	if not checked.valid: return checked
	if context.get("digit_order")!=_digits: return {"valid":false,"reason":"prepared_digit_order_mismatch"}
	_definition=null
	_capture_input={}
	_prepared_context=context
	_trace_callback=trace
	_trace_enabled=trace.is_valid()
	_configured=true
	return {"valid":true}

func _configure_common(config: Dictionary, host: Node) -> Dictionary:
	if not is_instance_valid(host) or not host.is_inside_tree(): return {"valid":false,"reason":"missing_acquisition_scene_host"}
	for field: String in ["measured_radius_m","envelope_radius_multiplier","envelope_radius_m"]:
		if not (config.get(field) is float or config.get(field) is int) or not is_finite(float(config[field])) or float(config[field])<=0.0:
			return {"valid":false,"reason":"invalid_envelope_configuration","field":field}
	if absf(float(config.measured_radius_m)*float(config.envelope_radius_multiplier)-float(config.envelope_radius_m))>1e-12:
		return {"valid":false,"reason":"envelope_multiplier_mismatch"}
	var inward_target: Variant = config.get("guide_inward_target_offset_m", 0.0)
	if not (inward_target is float or inward_target is int) or not is_finite(float(inward_target)) or float(inward_target)<0.0:
		return {"valid":false,"reason":"invalid_guide_inward_target_offset"}
	var palm_target: Variant = config.get("palm_guide_target_depth_m", 0.0)
	if not (palm_target is float or palm_target is int) or not is_finite(float(palm_target)) or float(palm_target)<0.0:
		return {"valid":false,"reason":"invalid_palm_guide_target_depth"}
	var requested: Array = config.get("selected_digits",[&"middle",&"thumb",&"index",&"ring",&"pinky"])
	var selected: Array[StringName] = []
	for digit: Variant in requested:
		var id := StringName(str(digit))
		if id not in [&"middle",&"thumb",&"index",&"ring",&"pinky"] or selected.has(id): return {"valid":false,"reason":"invalid_selected_digits"}
		selected.append(id)
	if not selected.has(&"middle"): return {"valid":false,"reason":"middle_placement_reference_required"}
	_digits=selected
	_config=config.duplicate(true)
	_scene_host=host
	_scene_tree=host.get_tree()
	_trace_callback=Callable()
	_trace_enabled=false
	_state_mutex.lock()
	_cancel_requested=false
	_progress_state={"stage":"configured","running":false}
	_state_mutex.unlock()
	return {"valid":true}

func _selected_digits() -> Array[StringName]:
	return _digits

func cancel() -> void:
	Chronology.event("acquisition.cancel_requested", {"job_id":str(get_instance_id())})
	_state_mutex.lock()
	_cancel_requested=true
	_state_mutex.unlock()

## Scene-exit fallback only: cancel and join the bounded current numerical
## operation before its owner can disappear. Ordinary cancellation is async.
func shutdown() -> void:
	cancel()
	if _worker!=null and _worker.is_started():
		_worker.wait_to_finish()
	_worker=null
	if not _native_handle.is_empty():
		_native.dispose(_native_handle)
		_native_handle={}

func _is_cancelled() -> bool:
	_state_mutex.lock()
	var requested: bool = _cancel_requested
	_state_mutex.unlock()
	return requested

func _progress_update(values: Dictionary) -> void:
	_state_mutex.lock()
	_progress_state.merge(values,true)
	_state_mutex.unlock()
	if Chronology.enabled():
		var recorded := values.duplicate()
		recorded["job_id"] = str(get_instance_id())
		Chronology.event("acquisition.progress", recorded)

func progress() -> Dictionary:
	_state_mutex.lock()
	var value: Dictionary = _progress_state.duplicate(true)
	_state_mutex.unlock()
	return value

func _cancel_result() -> Dictionary:
	return {"valid":false,"cancelled":true,"reason":"acquisition_cancelled"}

func _host_available() -> bool:
	return is_instance_valid(_scene_host) and _scene_host.is_inside_tree() and is_instance_valid(_scene_tree)

func _runtime_work(method: StringName, arguments: Array) -> Dictionary:
	if _is_cancelled(): return _cancel_result()
	if not _host_available():
		cancel()
		return _cancel_result()
	assert(_worker==null)
	var dispatch := Chronology.begin("worker.dispatch", {"job_id":str(get_instance_id()), "method":method})
	_worker=Thread.new()
	var active: Thread = _worker
	var work: Callable = Callable(self,method).bindv(arguments)
	if Chronology.enabled(): work = Callable(self,"_recorded_worker_call").bind(method,arguments)
	var error: Error = _worker.start(work)
	if error!=OK:
		_worker=null
		Chronology.finish(dispatch, {"valid":false,"reason":"worker_start_failed","error":error})
		return {"valid":false,"reason":"acquisition_worker_start_failed","error":error}
	while active.is_alive():
		# Keep the job alive until its worker exits, even if its scene host vanished.
		if not _host_available(): cancel()
		await _scene_tree.process_frame
	# shutdown() may already have joined this worker during scene exit.
	var value: Variant = active.wait_to_finish() if active.is_started() else null
	_worker=null
	Chronology.finish(dispatch, {"valid":value is Dictionary and value.get("valid",false), "reason":value.get("reason","") if value is Dictionary else "non_dictionary_result", "cancelled":_is_cancelled()})
	if _is_cancelled(): return _cancel_result()
	if not value is Dictionary: return {"valid":false,"reason":"invalid_acquisition_worker_result"}
	return value

func _recorded_worker_call(method: StringName, arguments: Array) -> Variant:
	var span := Chronology.begin("worker.execute", {"job_id":str(get_instance_id()),"method":method})
	var result: Variant = Callable(self,method).callv(arguments)
	Chronology.finish(span, {"valid":result is Dictionary and result.get("valid",false),"reason":result.get("reason","") if result is Dictionary else "non_dictionary_result"})
	return result

func solve() -> Dictionary:
	if _running or not _configured: return {"valid":false,"reason":"acquisition_not_configured_or_running"}
	var span := Chronology.begin("acquisition.solve", {"job_id":str(get_instance_id()),"digits":_digits})
	_running=true
	_progress_update({"stage":"preparing","running":true})
	_reset_acquisition()
	var context: Dictionary = _prepared_context
	if context.is_empty(): context=await _runtime_work("_prepare",[_definition,_capture_input])
	var result: Dictionary = context
	if context.get("valid",false): result=await _search_job(context)
	# Native calls have completed before this cleanup. No worker is abandoned.
	assert(_worker==null)
	if not _native_handle.is_empty():
		_native.dispose(_native_handle)
		_native_handle={}
	if _is_cancelled(): result=_cancel_result()
	_running=false
	_configured=false
	_progress_update({"stage":"cancelled" if _is_cancelled() else "complete","running":false,"valid":result.get("valid",false)})
	Chronology.finish(span, {"valid":result.get("valid",false),"reason":result.get("reason",result.get("termination","")),"evaluations":_circle_evaluations,"native_processes":_native_calls,"path_checks":_path_checks})
	return result

func _reset_acquisition() -> void:
	_circle_cache.clear(); _slice_cache.clear(); _response_runs.clear(); _reseat_attempts.clear()
	_guide_preparation_cache.clear(); _fixed_guides.clear(); _frozen_parameters.clear(); _preserve_guide.clear(); _preserve_material.clear()
	_circle_evaluations=0; _native_calls=0; _path_checks=0
	_depth.begin_acquisition(&"HandleGripAcquisition")
	_set_phase("circle",0.0)

func _trace_state(context: Dictionary, sample: Dictionary, label: String, force_geometry: bool = false) -> Dictionary:
	_progress_update({"stage":label,"phase":_guide_phase,"amount":_guide_amount,"contacts":sample.get("material_contacts",[]).duplicate(),"evaluations":_circle_evaluations})
	if not _trace_enabled and not force_geometry: return sample
	var pose: Dictionary = await _runtime_work("_circle_sample",[context,sample.parameters,sample.radius_m,true])
	if not pose.get("valid",false): return pose
	if _trace_enabled and _trace_callback.is_valid():
		_trace_callback.call({"stage":label,"phase":_guide_phase,"amount":_guide_amount,"pose":pose})
	return pose

## Freezing is a solver operation, independent of optional report geometry.
func _freeze_guides(context: Dictionary, sample: Dictionary) -> Dictionary:
	var candidate: Dictionary = _rigid_candidate(context,sample.parameters,sample.translation_world)
	if not candidate.get("valid",false): return candidate
	var targets: Dictionary = _circle_targets(context,candidate,[sample.parameters[_translation_u_index()],sample.parameters[_translation_v_index()]])
	if not targets.get("valid",false): return targets
	for digit: StringName in _selected_digits():
		if _is_cancelled(): return _cancel_result()
		var guide: Dictionary = _guide(context,targets.digits[digit],digit,sample.radius_m)
		if not guide.get("valid",false): return guide
		_fixed_guides[digit]=guide.duplicate(true)
	_frozen_parameters=sample.parameters.duplicate()
	_circle_cache.clear()
	_preserve_guide=sample.guide_contacts.duplicate()
	_preserve_material=sample.material_contacts.duplicate()
	return {"valid":true}

func _search_job(context: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var open: Array = context.open_parameters.duplicate()
	var original: Dictionary = await _runtime_work("_circle_sample",[context,open,0.05])
	if not original.get("valid",false): return original
	var radius: float = 0.0
	for digit: Dictionary in original.digits: radius=maxf(radius,digit.reach_m)
	context["start_radius_m"]=radius
	var current: Dictionary = {}
	for angle: float in [0.0,-30.0,30.0,-60.0,60.0]:
		var direction: Vector2 = context.outward_parameters.rotated(deg_to_rad(angle))
		for factor: float in [0.5,0.75,1.0,1.25,1.5,1.75,2.0]:
			var p: Array = open.duplicate(); p[_translation_u_index()]+=direction.x*radius*factor; p[_translation_v_index()]+=direction.y*radius*factor
			var trial: Dictionary = await _runtime_work("_circle_sample",[context,p,radius])
			if _is_cancelled(): return _cancel_result()
			if not trial.get("valid",false): continue
			if current.is_empty() or (_safe(trial) and not _safe(current)) or (_safe(trial)==_safe(current) and _cost(_residual(trial))<_cost(_residual(current))): current=trial
	if current.is_empty(): return {"valid":false,"reason":"no_valid_start_section"}
	if not _host_available(): cancel(); return _cancel_result()
	_native_handle=_native.prepare(_scene_host,context)
	if not _native_handle.get("valid",false): return _native_handle
	var recorded: Dictionary = await _trace_state(context,current,"outside_start")
	if not recorded.get("valid",false): return recorded
	for step: int in 9:
		if step>0:
			radius=0.0 if step==8 else (radius+current.required_enclosing_radius_m)*0.5
			current=await _runtime_work("_circle_sample",[context,current.parameters,radius])
			if not current.get("valid",false): return current
		current=await _native_proposal(context,_native_handle,current,radius)
		if not current.get("valid",false): return current
		current=await _runtime_work("_respond",[context,current,radius,"circle_"+str(step),PREP_ITERATIONS])
		if not current.get("valid",false): return current
		recorded=await _trace_state(context,current,"circle_at_handle" if radius==0.0 else "shrinking_preparation")
		if not recorded.get("valid",false): return recorded
	var reason: String = "sufficient_material_contact"
	if not current.diagnostic_grip_accepted:
		for phase: String in ["hull_transition","wrapper_transition"]:
			for amount: float in [0.25,0.5,0.75,1.0]:
				_set_phase(phase,amount)
				var seed: Dictionary = await _runtime_work("_circle_sample",[context,current.parameters,0.0])
				if not seed.get("valid",false): return seed
				current=await _native_proposal(context,_native_handle,seed,0.0)
				if not current.get("valid",false): return current
				current=await _runtime_work("_respond",[context,current,0.0,phase+"_"+str(amount),CONTACT_ITERATIONS])
				if not current.get("valid",false): return current
				recorded=await _trace_state(context,current,phase)
				if not recorded.get("valid",false): return recorded
				if current.diagnostic_grip_accepted: break
			if current.diagnostic_grip_accepted: break
		if not current.diagnostic_grip_accepted: reason="guide_reached_established_inward_curvature_limit"
	_native.dispose(_native_handle)
	_native_handle={}
	recorded=await _trace_state(context,current,"shrinking_stopped")
	if not recorded.get("valid",false): return recorded
	var frozen: Dictionary = await _runtime_work("_freeze_guides",[context,current])
	if not frozen.get("valid",false): return frozen
	for attempt: int in MAX_RESEATS:
		var before: Dictionary = current
		var before_cost: float = _cost(_residual(before))
		Chronology.event("reseat.attempt", {"job_id":str(get_instance_id()),"attempt":attempt+1,"cost":before_cost,"material_contacts":before.material_contacts})
		var response: Dictionary = await _runtime_work("_respond",[context,before,0.0,"reseat_"+str(attempt+1),CONTACT_ITERATIONS,true])
		if not response.get("valid",false): return response
		var improved: bool = _cost(_residual(response))<before_cost-1e-8 and _preserves(response)
		if Chronology.enabled():
			Chronology.event("reseat.outcome", {"job_id":str(get_instance_id()),"attempt":attempt+1,"improved":improved,"material_contacts":response.material_contacts,"cost":_cost(_residual(response))})
		if _trace_enabled:
			_reseat_attempts.append({"attempt":attempt+1,"improved":improved,"guide_id_before":before.guide_id,"guide_id_after":response.guide_id,
				"preserved_guide_sections":_preserve_guide.duplicate(),"preserved_material_sections":_preserve_material.duplicate(),
				"before_contacts":before.material_contacts.duplicate(),"after_contacts":response.material_contacts.duplicate(),"before_cost":before_cost,"after_cost":_cost(_residual(response))})
		if improved:
			current=response
			for id: String in current.guide_contacts:
				if not _preserve_guide.has(id): _preserve_guide.append(id)
			for id: String in current.material_contacts:
				if not _preserve_material.has(id): _preserve_material.append(id)
		recorded=await _trace_state(context,current,"reseat_"+str(attempt+1)+("_accepted" if improved else "_no_legal_improvement"))
		if not recorded.get("valid",false): return recorded
		if not improved: break
	var selected: Dictionary = await _trace_state(context,current,"selected_measured_result",true)
	if not selected.get("valid",false): return selected
	var candidate: Dictionary = await _runtime_work("_rigid_candidate",[context,selected.parameters,selected.translation_world])
	if not candidate.get("valid",false): return candidate
	return {"valid":true,"slot":context.slot,"selected":selected,"candidate":candidate,
		"termination":reason,"reseat_attempts":_reseat_attempts.duplicate(true),"response_runs":_response_runs.duplicate(true),
		"guide_reached_handle":selected.guide_reached_handle,"diagnostic_grip_accepted":selected.diagnostic_grip_accepted,
		"grip_accepted":false,"continuous_sweep_certified":false,"arm_realization_verified":false,"palm_contact_verified":false,
		"sampled_reseat_path_checks":_path_checks,"native_process_count":_native_calls,"evaluation_count":_circle_evaluations,
		"total_search_ms":float(Time.get_ticks_usec()-started)/1000.0,"station_axis_world":context.station_axis_world,
		"outward_direction_world":context.outward_direction_world,"vectors_origin_id":ROOT,"weapon_to_world":context.weapon_to_world,
		"object_origin_records":context.object_origin_records,"machine_to_world":context.adapter.base_packet.machine_to_world,"open_parameters":open,
		"palm_region_summary":{"accepted_reference_faces":context.palm_region.accepted_face_count,"coverage":context.palm_region.coverage,"complete_palm_partition_verified":false},
		"palmar_reference_origin_records":context.palm_region.reference_origin_records,"palmar_reference_frame_origin_id":context.palm_region.reference_frame_origin_id,
		"depth_cache_statistics":_depth.cache_statistics()}

func _retain_history() -> bool:
	return _trace_enabled

func _prepare(definition: Resource, stage: Dictionary) -> Dictionary:
	var context: Dictionary = op_shared_prepare(self,definition,stage)
	context=op_circle_prepare(self,definition,stage,context)
	context=op_tangent_prepare(self,definition,stage,context)
	return op_handle_prepare(self,definition,stage,context)

func _angle_count() -> int:
	return op_shared_angle_count(self)

func _translation_u_index() -> int:
	return op_shared_translation_u_index(self)

func _translation_v_index() -> int:
	return op_shared_translation_v_index(self)

func _parameter_count() -> int:
	return op_shared_parameter_count(self)

func _zero_parameters() -> Array:
	return op_shared_zero_parameters(self)

func _angles_by_digit(parameters: Array) -> Dictionary:
	return op_shared_angles_by_digit(self, parameters)

func _required_digit_contacts() -> Array:
	return op_shared_required_digit_contacts(self)

func _required_contact_keys() -> Array:
	return op_shared_required_contact_keys(self)

func _targets(context: Dictionary, candidate: Dictionary, translation: Array) -> Dictionary:
	return op_shared_targets(self, context,candidate,translation)

func _same_frame(a: Transform3D,b: Transform3D) -> bool:
	return op_shared_same_frame(self, a,b)

func _validate_object_source(object: Dictionary) -> Dictionary:
	return op_shared_validate_object_source(self, object)

func _angles(parameters: Array) -> Dictionary:
	return op_circle_angles(self, parameters)

func _rigid_candidate(context: Dictionary, parameters: Array, translation: Vector3) -> Dictionary:
	if not Chronology.enabled(): return op_circle_rigid_candidate(self, context,parameters,translation)
	var span := Chronology.begin("sample.candidate", {"job_id":str(get_instance_id())})
	var result: Dictionary = op_circle_rigid_candidate(self, context,parameters,translation)
	Chronology.finish(span, {"valid":result.get("valid",false),"reason":result.get("reason","")})
	return result

func _circle_targets(context: Dictionary, candidate: Dictionary, translation: Array) -> Dictionary:
	if not Chronology.enabled(): return op_tangent_circle_targets(self, context,candidate,translation)
	var span := Chronology.begin("sample.weapon_sections", {"job_id":str(get_instance_id())})
	var result: Dictionary = op_tangent_circle_targets(self, context,candidate,translation)
	Chronology.finish(span, {"valid":result.get("valid",false),"reason":result.get("reason","")})
	return result

func _solve_scale(index: int) -> float:
	return op_tangent_solve_scale(self, index)

func _cost(residual: PackedFloat64Array) -> float:
	return op_tangent_cost(self, residual)

func _linear_solve(matrix: Array, rhs: PackedFloat64Array) -> PackedFloat64Array:
	return op_tangent_linear_solve(self, matrix,rhs)

func _bounded_step(context: Dictionary, parameters: Array, matrix: Array, rhs: PackedFloat64Array) -> PackedFloat64Array:
	return op_tangent_bounded_step(self, context,parameters,matrix,rhs)

func _clamped(context: Dictionary, parameters: Array) -> Array:
	return op_handle_clamped(self, context,parameters)

func _set_phase(phase: String, amount: float) -> void:
	Chronology.event("acquisition.guide_phase", {"job_id":str(get_instance_id()),"phase":phase,"amount":amount})
	op_handle_set_phase(self, phase,amount)

func _guide(context: Dictionary, section: Dictionary, digit: StringName, radius: float) -> Dictionary:
	if not Chronology.enabled(): return op_handle_guide(self, context,section,digit,radius)
	var span := Chronology.begin("sample.guide", {"job_id":str(get_instance_id()),"digit":digit,"radius_m":radius,"phase":_guide_phase,"amount":_guide_amount})
	var result: Dictionary = op_handle_guide(self, context,section,digit,radius)
	Chronology.finish(span, {"valid":result.get("valid",false),"reason":result.get("reason","")})
	return result

func _measure(segments: Array, target: Dictionary, plane_id: StringName) -> Dictionary:
	if not Chronology.enabled(): return op_handle_measure(self, segments,target,plane_id)
	var span := Chronology.begin("sample.contact_measure", {"job_id":str(get_instance_id()),"plane_id":plane_id,"source_id":target.get("source_id",""),"skin_segment_count":segments.size()})
	var result: Dictionary = op_handle_measure(self, segments,target,plane_id)
	Chronology.finish(span, {"valid":result.get("valid",false),"reason":result.get("reason",""),"work_counts":result.get("work_counts",{}),"depth_evaluations":result.get("depth_evaluations",0)})
	return result

func _normal_record(record: Dictionary, circle: bool) -> Dictionary:
	return op_handle_normal_record(self, record,circle)

func _circle_sample(context: Dictionary, parameters: Array, radius: float, geometry: bool = false) -> Dictionary:
	if not Chronology.enabled(): return op_handle_circle_sample(self, context,parameters,radius,geometry)
	var span := Chronology.begin("sample.evaluate", {"job_id":str(get_instance_id()),"phase":_guide_phase,"amount":_guide_amount,"radius_m":radius,"geometry":geometry,"evaluation_before":_circle_evaluations})
	var before: int = _circle_evaluations
	var result: Dictionary = op_handle_circle_sample(self, context,parameters,radius,geometry)
	Chronology.finish(span, {"valid":result.get("valid",false),"reason":result.get("reason",""),"cache_hit":before==_circle_evaluations,"evaluation_after":_circle_evaluations,"material_contacts":result.get("material_contacts",[]),"guide_contacts":result.get("guide_contacts",[]),"material_safe":result.get("material_safe",false),"guide_safe":result.get("guide_safe",false),"diagnostic_grip_accepted":result.get("diagnostic_grip_accepted",false)})
	return result

func _residual(sample: Dictionary) -> PackedFloat64Array:
	return op_handle_residual(self, sample)

func _safe(sample: Dictionary) -> bool:
	return op_handle_safe(self, sample)

func _contact_status(sample: Dictionary) -> Dictionary:
	return op_handle_contact_status(self, sample)

func _contact_requests(sample: Dictionary) -> Array:
	return op_handle_contact_requests(self, sample)

func _native_proposal(context: Dictionary, handle: Dictionary, sample: Dictionary, radius: float) -> Dictionary:
	return await op_handle_native_proposal(self, context,handle,sample,radius)

func _retains_observed_sections(before: Dictionary, after: Dictionary) -> bool:
	return op_handle_retains_observed_sections(self, before,after)

func _preserves(sample: Dictionary) -> bool:
	return op_handle_preserves(self, sample)

func _reseat_path(context: Dictionary, before: Dictionary, after: Dictionary, radius: float) -> bool:
	return op_handle_reseat_path(self, context,before,after,radius)

func _respond(context: Dictionary, seed: Dictionary, radius: float, label: String, iterations: int, reseat: bool = false) -> Dictionary:
	if not Chronology.enabled(): return op_handle_respond(self, context,seed,radius,label,iterations,reseat)
	var span := Chronology.begin("response.cycle", {"job_id":str(get_instance_id()),"label":label,"iteration_limit":iterations,"reseat":reseat})
	var result: Dictionary = op_handle_respond(self, context,seed,radius,label,iterations,reseat)
	Chronology.finish(span, {"valid":result.get("valid",false),"reason":result.get("reason",""),"material_contacts":result.get("material_contacts",[]),"guide_contacts":result.get("guide_contacts",[])})
	return result

static func op_shared_angle_count(owner: Object) -> int:
	return owner._selected_digits().size() * 3


static func op_shared_translation_u_index(owner: Object) -> int:
	return owner._angle_count()


static func op_shared_translation_v_index(owner: Object) -> int:
	return owner._angle_count() + 1


static func op_shared_parameter_count(owner: Object) -> int:
	return owner._angle_count() + 2


static func op_shared_zero_parameters(owner: Object) -> Array:
	var result: Array = []
	result.resize(owner._parameter_count())
	result.fill(0.0)
	return result


static func op_shared_angles_by_digit(owner: Object, parameters: Array) -> Dictionary:
	var result: Dictionary = {}
	var digits: Array[StringName] = owner._selected_digits()
	for index: int in digits.size():
		result[digits[index]] = parameters.slice(index * 3,index * 3 + 3)
	return result


static func op_shared_required_digit_contacts(owner: Object) -> Array:
	var result: Array = []
	for digit: StringName in owner._selected_digits():
		for section: int in [1,2,3]:
			if digit == &"thumb" and section == 1: continue
			result.append([digit,section])
	return result


static func op_shared_required_contact_keys(owner: Object) -> Array:
	var result: Array = []
	for identity: Array in owner._required_digit_contacts():
		result.append(str(identity[0])+"/S"+str(identity[1]))
	return result


static func op_shared_prepare(owner: Object, definition: Resource, stage: Dictionary) -> Dictionary:
	var started: Variant = Time.get_ticks_usec()
	if not stage.get("object") is Dictionary:
		return {"valid": false, "reason": "missing_captured_weapon_surface"}
	var object: Dictionary = stage.object
	var source_check: Dictionary = owner._validate_object_source(object)
	if not source_check.get("valid", false): return source_check
	var adapter: Dictionary = owner._builder.prepare(definition, stage.posed_character, stage.slot, owner._selected_digits())
	if not adapter.get("valid", false): return adapter
	var records: Array = stage.posed_character.origin_records.duplicate(true)
	records.append(object.origin_record); records.append(object.weapon_origin_record)
	var registered: Dictionary = owner.HandSkin.new()._registry(records, stage.posed_character.resolve_phase)
	if not registered.get("valid", false): return registered
	var machine: Transform3D = stage.posed_character.machine_to_world
	for pair: Array in [[object.origin_record.origin_id, object.mesh_to_world], [object.weapon_origin_record.origin_id, object.weapon_to_world]]:
		var resolved: Transform3D = machine * registered.registry.resolve_transform_to_machine(pair[0])
		if not owner._same_frame(resolved, pair[1]): return {"valid": false, "reason": "object_frame_origin_mismatch"}
	for end: String in ["start", "end"]:
		if not object.get("primary_grip_span_" + end + "_local") is Vector3 or object.get("primary_grip_span_" + end + "_origin_id") != object.weapon_origin_record.origin_id:
			return {"valid": false, "reason": "missing_current_weapon_span"}
	var axis: Vector3 = (object.weapon_to_world as Transform3D).basis * ((object.primary_grip_span_end_local as Vector3) - (object.primary_grip_span_start_local as Vector3))
	if not axis.is_finite() or axis.length_squared() < 1.0e-12: return {"valid": false, "reason": "invalid_station_axis"}
	axis = axis.normalized()
	var first_plane: Transform3D = adapter.digit_inputs[&"middle"].plane_to_world
	var u: Vector3 = first_plane.basis.z.cross(axis)
	if u.length_squared() < 1.0e-8: u = first_plane.basis.x - axis * first_plane.basis.x.dot(axis)
	if u.length_squared() < 1.0e-8: return {"valid": false, "reason": "degenerate_shared_translation_basis"}
	u = u.normalized()
	var v: Variant = axis.cross(u).normalized()
	var surface: Variant = {"valid": true, "triangles_world": (object.mesh_to_world as Transform3D) * (object.local_faces as PackedVector3Array),
		"surface_source_origin_id": object.local_faces_origin_id, "resolved_world_origin_id": owner.ROOT}
	if surface.triangles_world.is_empty(): return {"valid": false, "reason": "empty_weapon_surface"}
	var observations: Variant = {}
	var radius: Variant = 0.0
	for point: Vector2 in owner.Profile.get_handle_builder_limit_polygon(): radius = maxf(radius, point.length() * 1.3)
	for digit: StringName in owner._selected_digits():
		var prepared: Dictionary = owner._observer.prepare(adapter, digit)
		if not prepared.get("valid", false): return prepared
		observations[digit] = prepared
	var context: Variant = {"valid": true, "slot": stage.slot, "adapter": adapter, "observations": observations,"digit_order":owner._selected_digits().duplicate(),
		"surface": surface, "weapon_to_world": object.weapon_to_world, "object_origin_records": [object.origin_record, object.weapon_origin_record],
		"station_axis_world": axis, "translation_u_world": u, "translation_v_world": v,
		"vectors_origin_id": owner.ROOT, "guide_initial_radius_m": radius, "preparation_ms": float(Time.get_ticks_usec() - started) / 1000.0}
	owner._slice_cache.clear()
	var zero: Dictionary = owner._builder.evaluate(adapter, owner._angles_by_digit(owner._zero_parameters()), Vector3.ZERO, owner.ROOT)
	if not zero.get("valid",false): return zero
	var initial_slices: Variant = owner._targets(context,zero,[0.0,0.0])
	if not initial_slices.get("valid",false): return initial_slices
	for digit: StringName in owner._selected_digits():
		var slice: Dictionary = initial_slices.digits[digit]
		for point: Vector2 in slice.polygon: radius = maxf(radius,point.distance_to(slice.center)+0.00001)
	context.guide_initial_radius_m = radius
	context.preparation_ms = float(Time.get_ticks_usec() - started) / 1000.0
	return context


static func op_shared_targets(owner: Object, context: Dictionary, candidate: Dictionary, translation: Array) -> Dictionary:
	var key: Variant = var_to_bytes(translation).hex_encode()
	if owner._slice_cache.has(key): return owner._slice_cache[key]
	var result: Variant = {"valid": true, "digits": {}, "slice_preparation_ms": 0.0}
	var started: Variant = Time.get_ticks_usec()
	for digit: StringName in owner._selected_digits():
		var state: Dictionary = candidate.digit_states[digit]
		var plane: Transform3D = state.plane_to_world
		var reach: Variant = 0.0
		for vertex: Vector3 in context.surface.triangles_world: reach = maxf(reach, vertex.distance_to(plane.origin))
		var sliced: Dictionary = owner.Slicer.new().slice(context.surface, plane, state.plane_origin_id, reach + 0.0001, 0.0)
		if not sliced.get("valid", false) or sliced.contours.size() != 1 or sliced.counts.segments_clipped != 0 or sliced.counts.open_or_branched_vertices != 0 or sliced.counts.coplanar_triangles != 0:
			return {"valid": false, "reason": "shared_trial_requires_complete_object_loop", "digit": digit, "slice": sliced.get("counts")}
		var polygon: PackedVector2Array = sliced.contours[0].duplicate()
		if polygon[0] == polygon[-1]: polygon.remove_at(polygon.size() - 1)
		var center: Dictionary = owner.Centroid._calculate_polygon_centroid_state(polygon)
		if not center.get("valid", false): return {"valid": false, "reason": "invalid_trial_centroid"}
		var target: Dictionary = owner.Depth.new().prepare_target(polygon, state.plane_origin_id, context.surface.surface_source_origin_id, true)
		if not target.get("valid", false): return target
		result.digits[digit] = {"target": target, "polygon": polygon, "center": center.centroid, "plane": plane, "origin_id": state.plane_origin_id}
	result.slice_preparation_ms = float(Time.get_ticks_usec() - started) / 1000.0
	owner._slice_cache[key] = result
	return result


static func op_shared_same_frame(owner: Object, a: Transform3D,b: Transform3D) -> bool:
	if not a.is_finite() or not b.is_finite(): return false
	if a.origin.distance_to(b.origin)>0.000005: return false
	for axis: int in range(3):
		if (a.basis[axis]-b.basis[axis]).length()>0.000005: return false
	return true


static func op_shared_validate_object_source(owner: Object, object: Dictionary) -> Dictionary:
	if not object.get("origin_record") is Dictionary or not object.get("weapon_origin_record") is Dictionary:
		return {"valid": false, "reason": "missing_object_origin_records"}
	var source_id: Variant = object.get("local_faces_origin_id")
	if not (source_id is String or source_id is StringName) or String(source_id).is_empty() or source_id != object.origin_record.get("origin_id"):
		return {"valid": false, "reason": "local_faces_origin_does_not_match_object_frame"}
	if not object.get("local_faces") is PackedVector3Array or object.local_faces.is_empty() or object.local_faces.size() % 3 != 0:
		return {"valid": false, "reason": "missing_or_nontriangle_weapon_surface"}
	for vertex: Vector3 in object.local_faces:
		if not vertex.is_finite(): return {"valid": false, "reason": "nonfinite_weapon_source_vertex"}
	for field: String in ["mesh_to_world", "weapon_to_world"]:
		if not object.get(field) is Transform3D or not (object[field] as Transform3D).is_finite():
			return {"valid": false, "reason": "missing_or_nonfinite_object_frame", "field": field}
	return {"valid": true}


static func op_circle_prepare(owner: Object, definition: Resource, stage: Dictionary, context: Dictionary) -> Dictionary:
	if not context.get("valid", false): return context
	var open_parameters: Array = owner._zero_parameters()
	for digit_index: int in owner._selected_digits().size():
		var digit: StringName = owner._selected_digits()[digit_index]
		var chain: Array = owner.Rules.get_chain_rules(stage.slot, digit)
		var snapshot: Dictionary = context.adapter.digit_inputs[digit].snapshot
		if chain.size() != 3: return {"valid": false, "reason": "missing_open_rules"}
		for joint: int in 3:
			var angle: float = deg_to_rad(float(chain[joint].open_degrees))
			if chain[joint].bone != snapshot.bone_names[joint] or angle < snapshot.min_angles_rad[joint] or angle > snapshot.max_angles_rad[joint]:
				return {"valid": false, "reason": "open_rules_do_not_match_prepared_anatomy"}
			open_parameters[digit_index * 3 + joint] = angle
	var open_pose: Dictionary = owner._builder.evaluate(context.adapter, owner._angles(open_parameters), Vector3.ZERO, owner.ROOT)
	if not open_pose.get("valid", false): return open_pose
	context["open_parameters"] = open_parameters
	var machine: Transform3D = context.adapter.base_packet.machine_to_world
	var wrist: Vector3 = context.adapter.baseline_hand_to_world.origin
	var index_name: StringName = owner.Rules.get_chain_rules(stage.slot, &"index")[0].bone
	var pinky_name: StringName = owner.Rules.get_chain_rules(stage.slot, &"pinky")[0].bone
	var index: Vector3 = (machine * (context.adapter.base_frames[index_name] as Transform3D)).origin
	var pinky: Vector3 = (machine * (context.adapter.base_frames[pinky_name] as Transform3D)).origin
	var normal: Vector3 = (index - wrist).cross(pinky - wrist)
	if normal.length_squared() < 1.0e-16: return {"valid": false, "reason": "degenerate_palm_footprint"}
	normal = normal.normalized()
	var middle: Dictionary = open_pose.digit_states[&"middle"]
	var first: Transform3D = middle.joint_transforms_world[0]
	var axis: Vector3 = first.basis * (middle.snapshot.hinge_axes_local[0] as Vector3)
	var closing: Vector3 = axis.cross((middle.joint_origins_world[1] as Vector3) - first.origin)
	closing *= signf(float(middle.snapshot.preferred_angles_rad[0]) - float(open_parameters[owner._selected_digits().find(&"middle") * 3]))
	if closing.length_squared() < 1.0e-16 or absf(normal.dot(closing.normalized())) < 0.1:
		return {"valid": false, "reason": "ambiguous_prepared_palm_facing"}
	normal *= signf(normal.dot(closing))
	var outward: Vector3 = -normal + context.station_axis_world * normal.dot(context.station_axis_world)
	if outward.length_squared() < 1.0e-12: return {"valid": false, "reason": "outward_axis_not_transverse"}
	outward = outward.normalized()
	context["outward_direction_world"] = outward
	context["outward_direction_origin_id"] = owner.ROOT
	context["outward_parameters"] = Vector2(outward.dot(context.translation_u_world), outward.dot(context.translation_v_world))
	return context


static func op_circle_angles(owner: Object, parameters: Array) -> Dictionary:
	return owner._angles_by_digit(parameters)


static func op_circle_rigid_candidate(owner: Object, context: Dictionary, parameters: Array, translation: Vector3) -> Dictionary:
	# Diagnostic free placement preserves the contributing forearm/Hand relationship.
	# Only world presentation is translated; all named bone-to-machine frames and
	# original skin weights are retained. No scene/body/arm pose is written.
	var candidate: Dictionary = owner._builder.evaluate(context.adapter,owner._angles(parameters),Vector3.ZERO,owner.ROOT)
	if not candidate.get("valid",false): return candidate
	var shift: Transform3D = Transform3D(Basis.IDENTITY,translation)
	var packet: Dictionary = candidate.pose_packet
	packet.machine_to_world = shift * (packet.machine_to_world as Transform3D)
	packet.pose_id = StringName(str(packet.pose_id)+"RigidPlacement"+str(hash(translation)))
	packet.translation_world = translation
	packet["placement_policy"] = &"rigid_captured_pose_world_translation"
	candidate.posed.vertices_world = shift * (candidate.posed.vertices_world as PackedVector3Array)
	candidate.posed.machine_to_world = packet.machine_to_world
	candidate.posed.pose_id = packet.pose_id
	for digit: StringName in owner._selected_digits():
		var state: Dictionary = candidate.digit_states[digit]
		state.hand_to_world = shift * (state.hand_to_world as Transform3D)
		state.plane_to_world = shift * (state.plane_to_world as Transform3D)
		state.snapshot.root_parent_world = shift * (state.snapshot.root_parent_world as Transform3D)
		for index: int in 3:
			state.joint_transforms_world[index] = shift * (state.joint_transforms_world[index] as Transform3D)
			state.joint_origins_world[index] = (state.joint_origins_world[index] as Vector3)+translation
		state.tip_world = (state.tip_world as Vector3)+translation
	candidate.hand_to_world = shift * (candidate.hand_to_world as Transform3D)
	candidate.translation_world = translation
	return candidate


static func op_tangent_prepare(owner: Object, definition: Resource, stage: Dictionary, context: Dictionary) -> Dictionary:
	if not context.get("valid",false): return context
	context["prepared_sections"] = {}
	for digit: StringName in owner._selected_digits():
		var input: Dictionary = context.adapter.digit_inputs[digit]
		var prepared: Dictionary = owner._section_query.prepare(context.surface,input.plane_to_world,input.plane_origin_id)
		if not prepared.get("valid",false): return prepared
		context.prepared_sections[digit] = prepared
	return context


static func op_tangent_circle_targets(owner: Object, context: Dictionary, candidate: Dictionary, translation: Array) -> Dictionary:
	var key: String = var_to_bytes(translation).hex_encode()
	if owner._slice_cache.has(key) and owner._slice_cache[key].get("prepared_index",false): return owner._slice_cache[key]
	var out: Dictionary = {"valid":true,"digits":{},"prepared_index":true}
	for digit: StringName in owner._selected_digits():
		var sliced: Dictionary = owner._section_query.slice(context.prepared_sections[digit],candidate.digit_states[digit].plane_to_world)
		if not sliced.get("valid",false): return sliced
		out.digits[digit] = sliced
	owner._slice_cache[key] = out
	return out


static func op_tangent_solve_scale(owner: Object, index: int) -> float:
	return 0.1 if index < owner._angle_count() else 0.005


static func op_tangent_cost(owner: Object, residual: PackedFloat64Array) -> float:
	var result: float = 0.0
	for value: float in residual: result += value*value
	return result


static func op_tangent_linear_solve(owner: Object, matrix: Array, rhs: PackedFloat64Array) -> PackedFloat64Array:
	var n: int = rhs.size()
	var a: Array = matrix.duplicate(true)
	var b: PackedFloat64Array = rhs.duplicate()
	for pivot: int in n:
		var best: int = pivot
		for row: int in range(pivot+1,n):
			if absf(a[row][pivot]) > absf(a[best][pivot]): best=row
		if absf(a[best][pivot]) < 1.0e-12: return []
		var swap: Variant = a[pivot]; a[pivot]=a[best]; a[best]=swap
		var value: float = b[pivot]; b[pivot]=b[best]; b[best]=value
		for row: int in range(pivot+1,n):
			var ratio: float = a[row][pivot]/a[pivot][pivot]
			for column: int in range(pivot,n): a[row][column]-=ratio*a[pivot][column]
			b[row]-=ratio*b[pivot]
	var x: PackedFloat64Array = []; x.resize(n)
	for row: int in range(n-1,-1,-1):
		var value: float = b[row]
		for column: int in range(row+1,n): value-=a[row][column]*x[column]
		x[row]=value/a[row][row]
	return x


static func op_tangent_bounded_step(owner: Object, context: Dictionary, parameters: Array, matrix: Array, rhs: PackedFloat64Array) -> PackedFloat64Array:
	# Re-solve with outward-pointing bound variables fixed. Simply clamping the
	# final unconstrained step throws away the compensation from other joints.
	var constrained: Array = matrix.duplicate(true)
	var target: PackedFloat64Array = rhs.duplicate()
	var fixed: Dictionary = {}
	for pass_index: int in parameters.size()+1:
		var step: PackedFloat64Array = owner._linear_solve(constrained,target)
		if step.is_empty(): return step
		var added: bool = false
		for index: int in parameters.size():
			if index in [owner._translation_u_index(),owner._translation_v_index()] or fixed.has(index): continue
			var low: float = -context.start_radius_m*0.5
			var high: float = context.start_radius_m
			if index<owner._angle_count():
				var snapshot: Dictionary = context.adapter.digit_inputs[owner._selected_digits()[index/3]].snapshot
				low=snapshot.min_angles_rad[index%3]; high=snapshot.max_angles_rad[index%3]
			if not ((parameters[index]<=low+1.0e-8 and step[index]<0.0) or (parameters[index]>=high-1.0e-8 and step[index]>0.0)): continue
			fixed[index]=true; added=true
			for j: int in parameters.size(): constrained[index][j]=0.0; constrained[j][index]=0.0
			constrained[index][index]=1.0; target[index]=0.0
		if not added: return step
	return []


static func op_native_clamped(owner: Object, context: Dictionary, parameters: Array) -> Array:
	# The numerical correction reuses the mature bounded least-squares machinery,
	# but its only unknowns are the hand pose. Radius is not an unknown.
	assert(parameters.size()==owner._parameter_count())
	var result: Array = parameters.duplicate()
	for index: int in owner._angle_count():
		var snapshot: Dictionary = context.adapter.digit_inputs[owner._selected_digits()[index/3]].snapshot
		result[index]=clampf(result[index],snapshot.min_angles_rad[index%3],snapshot.max_angles_rad[index%3])
	var offset: Vector2 = Vector2(result[owner._translation_u_index()],result[owner._translation_v_index()]).limit_length(0.35)
	result[owner._translation_u_index()]=offset.x; result[owner._translation_v_index()]=offset.y
	return result


static func op_handle_prepare(owner: Object, definition: Resource, stage: Dictionary, context: Dictionary) -> Dictionary:
	if not context.get("valid",false): return context
	context["palm_region"]=owner._palm.prepare(context,definition)
	if not context.palm_region.get("valid",false): return context.palm_region
	return context


static func op_handle_clamped(owner: Object, context: Dictionary, parameters: Array) -> Array:
	var out: Array = op_native_clamped(owner,context,parameters)
	if not owner._frozen_parameters.is_empty():
		out[owner._translation_u_index()]=owner._frozen_parameters[owner._translation_u_index()]; out[owner._translation_v_index()]=owner._frozen_parameters[owner._translation_v_index()]
	return out


static func op_handle_set_phase(owner: Object, phase: String, amount: float) -> void:
	owner._guide_phase=phase; owner._guide_amount=amount; owner._circle_cache.clear()


static func op_handle_guide(owner: Object, context: Dictionary, section: Dictionary, digit: StringName, radius: float) -> Dictionary:
	if owner._fixed_guides.has(digit): return owner._fixed_guides[digit]
	var enclosure: float = 0.0
	for point: Vector2 in section.polygon: enclosure=maxf(enclosure,point.distance_to(section.center))
	# Offset only the guide once it reaches the material-contact phase. Finger
	# settings and physical material checks remain independent and unchanged.
	var inward_target: float = float(owner._config.get("guide_inward_target_offset_m", 0.0)) if owner._guide_phase!="circle" or radius==0.0 else 0.0
	if owner._guide_phase=="circle":
		var circle: Dictionary = {"valid":true,"center":section.center,"radius_m":maxf(radius,enclosure),"polygon":PackedVector2Array(),
			"geometry_fingerprint":str(hash([section.polygon,section.center,maxf(radius,enclosure)])),"enclosing_radius_m":enclosure,
			"origin_id":section.origin_id,"source_id":context.surface.surface_source_origin_id}
		return owner._progression.inset_contact_target(circle,inward_target) if inward_target>0.0 else circle
	var key: String = var_to_bytes([section.polygon,section.center,section.origin_id]).hex_encode()
	if not owner._guide_preparation_cache.has(key):
		owner._guide_preparation_cache[key]=owner._progression.prepare(section.polygon,section.center,section.origin_id,
			context.surface.surface_source_origin_id,owner._config.envelope_radius_m)
	var prepared: Dictionary = owner._guide_preparation_cache[key]
	if not prepared.get("valid",false): return prepared
	var result: Dictionary = owner._progression.sample(prepared,owner._guide_phase,owner._guide_amount,enclosure,inward_target)
	if result.get("valid",false): result["radius_m"]=enclosure
	return result


static func op_handle_measure(owner: Object, segments: Array, target: Dictionary, plane_id: StringName) -> Dictionary:
	return owner._depth.evaluate_segments(segments,target,plane_id,{"max_evaluations_per_segment":64,
		"depth_bound_tolerance_m":0.00001,"refine_depth_after_cap":true})


static func op_handle_normal_record(owner: Object, record: Dictionary, circle: bool) -> Dictionary:
	if circle:
		return {"gap":record.signed_clearance_m,"depth_upper":maxf(-float(record.signed_clearance_m),0.0),
			"witness":{"skin_point_m":record.skin_point_m,"target_point_m":record.circle_point_m,
			"target_outward_normal":record.circle_outward_normal,"source_id":record.source_id}}
	var gap: float = -float(record.max_inward_depth_lower_m) if record.max_inward_depth_lower_m>0.0 else float(record.contact.distance_m)
	var witness: Dictionary = record.contact.duplicate()
	# For an intersecting edge use the deepest measured point, not its zero-gap
	# crossing, so the response actually addresses penetration.
	if record.max_inward_depth_lower_m>0.0 and not record.depth_lower_bound_witness.is_empty():
		var inside: Dictionary = record.depth_lower_bound_witness
		witness.skin_point_m=inside.skin_point_m
		witness.target_point_m=inside.nearest_target_point_m
		var separation: Vector2 = witness.target_point_m-witness.skin_point_m
		if separation.length_squared()>1e-16: witness.target_outward_normal=separation.normalized()
	return {"gap":gap,"depth_upper":record.max_inward_depth_upper_m,"witness":witness}


static func op_handle_circle_sample(owner: Object, context: Dictionary, parameters: Array, radius: float, geometry: bool = false) -> Dictionary:
	if owner._is_cancelled(): return {"valid":false,"cancelled":true,"reason":"acquisition_cancelled"}
	var key: String = var_to_bytes([parameters,radius,owner._guide_phase,owner._guide_amount]).hex_encode()
	if not geometry and owner._circle_cache.has(key): return owner._circle_cache[key]
	owner._circle_evaluations+=1
	var translation: Vector3 = context.translation_u_world*float(parameters[owner._translation_u_index()])+context.translation_v_world*float(parameters[owner._translation_v_index()])
	var candidate: Dictionary = owner._rigid_candidate(context,parameters,translation)
	if not candidate.get("valid",false): return candidate
	var targets: Dictionary = owner._circle_targets(context,candidate,[parameters[owner._translation_u_index()],parameters[owner._translation_v_index()]])
	if not targets.get("valid",false): return targets
	var out: Dictionary = {"valid":true,"parameters":parameters.duplicate(),"pose_id":candidate.pose_packet.pose_id,
		"translation_world":translation,"translation_world_origin_id":owner.ROOT,"hand_to_world":candidate.hand_to_world,
		"hand_to_world_origin_id":owner.ROOT,"machine_to_world":candidate.pose_packet.machine_to_world,"axial_translation_m":translation.dot(context.station_axis_world),
		"radius_m":radius,"phase":owner._guide_phase,"amount":owner._guide_amount,"digits":[],"material_contacts":[],"guide_contacts":[],
		"material_safe":true,"guide_safe":true,"material_assessed":owner._guide_phase!="circle" or radius==0.0,
		"guide_reached_handle":owner._guide_phase!="circle" or radius==0.0,"guide_id":"","min_signed_clearance_m":INF,
		"required_enclosing_radius_m":0.0,"weapon_slices_valid":true,
		"diagnostic_grip_accepted":false,"grip_accepted":false,"production_pose_written":false,"actual_3d_grip_verified":false}
	for digit: StringName in owner._selected_digits():
		if owner._is_cancelled(): return {"valid":false,"cancelled":true,"reason":"acquisition_cancelled"}
		var state: Dictionary = candidate.digit_states[digit]
		var section: Dictionary = targets.digits[digit]
		if out.material_assessed and not section.has("target"):
			section["target"]=owner._depth.prepare_ordered_target(section.polygon,state.plane_origin_id,context.surface.surface_source_origin_id,true)
			if not section.target.get("valid",false): return section.target
		var guide: Dictionary = owner._guide(context,section,digit,radius)
		if not guide.get("valid",false): return guide
		var prepared: Dictionary = context.observations[digit].duplicate()
		prepared.machine_to_world=candidate.pose_packet.machine_to_world
		var recording: bool = Chronology.enabled()
		var slice_span: int = Chronology.begin("sample.skin_slice", {"job_id":str(owner.get_instance_id()),"digit":digit}) if recording else 0
		var sliced: Dictionary = owner._observer.slice_candidate(prepared,candidate,state.plane_to_world,state.plane_origin_id)
		if recording:
			Chronology.finish(slice_span, {"valid":sliced.get("valid",false),"reason":sliced.get("reason",""),"segments":sliced.get("segments",[]).size(),"origin_validation_ms":sliced.get("plane_origin_validation_ms",0.0),"triangle_slice_ms":sliced.get("skin_slice_ms",0.0)})
		if not sliced.get("valid",false): return sliced
		var palm_span: int = Chronology.begin("sample.palm_annotation", {"job_id":str(owner.get_instance_id()),"digit":digit}) if recording else 0
		sliced=owner._palm.annotate(context.palm_region,candidate,sliced,state.plane_to_world)
		if recording: Chronology.finish(palm_span, {"valid":sliced.get("valid",false),"reason":sliced.get("reason",""),"segments":sliced.get("segments",[]).size()})
		if not sliced.get("valid",false): return sliced
		var segments: Array = sliced.segments
		var circular: bool = guide.polygon.is_empty()
		var circle_span: int = Chronology.begin("sample.circle_contact", {"job_id":str(owner.get_instance_id()),"digit":digit,"segments":segments.size()}) if recording and circular else 0
		var guide_measured: Dictionary = owner._circle_query.evaluate(segments,section.center,guide.radius_m,state.plane_origin_id,&"GripGuide") if circular else owner._measure(segments,guide.target,state.plane_origin_id)
		if circle_span!=0: Chronology.finish(circle_span, {"valid":guide_measured.get("valid",false),"reason":guide_measured.get("reason","")})
		if not guide_measured.get("valid",false): return guide_measured
		var material: Dictionary = owner._measure(segments,section.target,state.plane_origin_id) if out.material_assessed else {}
		if out.material_assessed and not material.get("valid",false): return material
		var observation: Dictionary = {"digit":digit,"slot":context.slot,"pose_id":out.pose_id,"angles_rad":state.angles_rad,
			"plane_to_world":state.plane_to_world,"plane_origin_id":state.plane_origin_id,"circle_center_m":section.center,
			"slice_center_m":section.center,"radius_m":guide.radius_m,"required_enclosing_radius_m":guide.enclosing_radius_m,
			"reach_center_m":sliced.reach_center_m,"reach_m":sliced.reach_m,"regions":[],
			"group_guide_excess_m":[0.0,0.0,0.0,0.0,0.0],"group_material_excess_m":[0.0,0.0,0.0,0.0,0.0],
			"guide_id":guide.geometry_fingerprint,"guide_geometry":guide if geometry else {},
			"circle_reference":{"center_reference_weapon_local":context.weapon_to_world.affine_inverse()*(state.plane_to_world*Vector3(section.center.x,section.center.y,0.0)),"origin_id":context.object_origin_records[1].origin_id}}
		var regions: Array = []
		for region_owner: int in 4:
			var cap: float = prepared.caps_m[region_owner] if region_owner<3 else 0.0025
			regions.append({"section":region_owner+1,"section_id":str(digit)+"/S"+str(region_owner+1) if region_owner<3 else "palm",
				"contact_required":not(digit==&"thumb" and region_owner==0) and (region_owner<3 or out.material_assessed),
				"cap_m":cap,"target_overlap_m":prepared.targets_m[region_owner] if region_owner<3 else float(owner._config.get("palm_guide_target_depth_m",0.0)),
				"nearest_gap_m":INF,"nearest_unrestricted_gap_m":INF,"material_gap_m":INF,"depth_upper_m":0.0,"guide_depth_upper_m":0.0,
				"owned_segments":0,"guide_witness":{},"material_witness":{},"guide_cap_verified":true,"material_cap_verified":true})
		for i: int in segments.size():
			var edge: Dictionary = segments[i]
			var region_owner: int = int(edge.section_owner)
			if region_owner<0 and edge.get("palm_owned",false): region_owner=3
			var group: int = region_owner if region_owner>=0 else 4
			var cap: float = float(edge.max_inward_depth_m) if not edge.allowance_unassigned else 0.0
			var guide_cap: float = cap if out.material_assessed else 0.0
			var g: Dictionary = owner._normal_record(guide_measured.segments[i],circular)
			var m: Dictionary = owner._normal_record(material.segments[i],false) if out.material_assessed else {"gap":INF,"depth_upper":0.0,"witness":{}}
			var guide_excess: float = maxf(float(g.depth_upper)-guide_cap-owner.NUMERIC_GUARD_M,0.0)
			var material_excess: float = maxf(float(m.depth_upper)-cap-owner.NUMERIC_GUARD_M,0.0)
			observation.group_guide_excess_m[group]=maxf(observation.group_guide_excess_m[group],guide_excess)
			observation.group_material_excess_m[group]=maxf(observation.group_material_excess_m[group],material_excess)
			out.guide_safe=out.guide_safe and guide_excess<=0.0
			out.material_safe=out.material_safe and material_excess<=0.0
			out.min_signed_clearance_m=minf(out.min_signed_clearance_m,g.gap)
			if region_owner<0: continue
			var region: Dictionary = regions[region_owner]
			region.owned_segments+=1
			region.guide_cap_verified=region.guide_cap_verified and guide_excess<=0.0
			region.material_cap_verified=region.material_cap_verified and material_excess<=0.0
			region.depth_upper_m=maxf(region.depth_upper_m,m.depth_upper)
			region.guide_depth_upper_m=maxf(region.guide_depth_upper_m,g.depth_upper)
			# Collision safety above still sees the entire skin. Only the prepared
			# gripping side (or positively identified palm) can count as contact.
			if not edge.get("grip_attraction_eligible", true): continue
			region.nearest_unrestricted_gap_m=minf(region.nearest_unrestricted_gap_m,g.gap)
			if g.gap<region.nearest_gap_m and (region_owner==3 or (g.witness.target_point_m as Vector2).distance_to(sliced.reach_center_m)<=sliced.reach_m):
				region.nearest_gap_m=g.gap; region.guide_witness=g.witness; region.guide_witness["source_id"]=edge.source_id
			if m.gap<region.material_gap_m and (region_owner==3 or (m.witness.target_point_m as Vector2).distance_to(sliced.reach_center_m)<=sliced.reach_m):
				region.material_gap_m=m.gap; region.material_witness=m.witness; region.material_witness["source_id"]=edge.source_id
		for region: Dictionary in regions:
			region["response_target_clearance_m"]=op_handle_desired_guide_clearance(owner,out,region)
			if geometry and region.contact_required and not region.guide_witness.is_empty():
				var witness: Dictionary = region.guide_witness
				region["response_target_point_m"]=witness.target_point_m+witness.target_outward_normal*region.response_target_clearance_m
				region["response_target_origin_id"]=state.plane_origin_id
			region["guide_contact"]=region.owned_segments>0 and region.guide_cap_verified and region.nearest_gap_m<=owner.CONTACT_BAND_M
			region["material_contact"]=out.material_assessed and region.owned_segments>0 and region.material_cap_verified and region.material_gap_m<=owner.NUMERIC_GUARD_M
			if region.guide_contact and not out.guide_contacts.has(region.section_id): out.guide_contacts.append(region.section_id)
			if region.material_contact and not out.material_contacts.has(region.section_id): out.material_contacts.append(region.section_id)
		observation.regions=regions
		if geometry:
			observation["skin_segments"]=segments; observation["target_polygon_m"]=section.polygon
			observation["guide_polygon_m"]=guide.polygon; observation["guide_measurements"]=guide_measured
			observation["material_measurements"]=material
		out.guide_id+=str(guide.geometry_fingerprint)+"/"
		out.required_enclosing_radius_m=maxf(out.required_enclosing_radius_m,guide.enclosing_radius_m)
		out.digits.append(observation)
	out.diagnostic_grip_accepted=out.material_assessed and out.material_contacts.size()>=owner.MIN_MATERIAL_SECTIONS and out.material_safe and out.guide_safe
	if geometry: out["pose_origin_records"]=candidate.pose_packet.origin_records
	else: owner._circle_cache[key]=out
	return out


static func op_handle_desired_guide_clearance(owner: Object, sample: Dictionary, region: Dictionary) -> float:
	if not sample.material_assessed: return owner.CLEARANCE_M
	# The identified palm may aim beyond its allowed penetration. Its existing
	# independent guide/material checks remain the stopper; never enlarge a cap.
	# Digit target behavior stays exactly as it was.
	if region.section_id=="palm": return -float(region.target_overlap_m)
	return -minf(region.target_overlap_m,region.cap_m)


static func op_handle_residual(owner: Object, sample: Dictionary) -> PackedFloat64Array:
	var result: PackedFloat64Array = []
	for digit: Dictionary in sample.digits:
		for region: Dictionary in digit.regions:
			# The measured unrestricted distance supplies a placement gradient while
			# a witness is still out of reach. It never counts as a contact or an
			# executable native target until the separate reach test passes.
			var gap: float = region.nearest_unrestricted_gap_m
			var desired: float = op_handle_desired_guide_clearance(owner,sample,region)
			var guide_error: float = 0.0
			if region.contact_required:
				if is_finite(gap): guide_error=(gap-desired)*1000.0
				elif region.section<=3: guide_error=digit.reach_m*1000.0
			result.append(guide_error)
			var material_gap: float = region.material_gap_m
			result.append(maxf(material_gap,0.0)*250.0 if region.contact_required and sample.material_assessed and is_finite(material_gap) else 0.0)
		for excess: float in digit.group_guide_excess_m: result.append(excess*20000.0)
		for excess: float in digit.group_material_excess_m: result.append(excess*40000.0)
	return result


static func op_handle_safe(owner: Object, sample: Dictionary) -> bool:
	return sample.get("valid",false) and sample.guide_safe and sample.material_safe


static func op_handle_contact_status(owner: Object, sample: Dictionary) -> Dictionary:
	return {"contacts":sample.material_contacts.size(),"required":owner.MIN_MATERIAL_SECTIONS,"accepted":sample.diagnostic_grip_accepted}


static func op_handle_contact_requests(owner: Object, sample: Dictionary) -> Array:
	var requests: Array = []
	for digit: Dictionary in sample.digits:
		for region: Dictionary in digit.regions:
			if not region.contact_required or region.section>3 or region.guide_witness.is_empty(): continue
			var witness: Dictionary = region.guide_witness
			var desired: float = op_handle_desired_guide_clearance(owner,sample,region)
			var target: Vector2 = witness.target_point_m+witness.target_outward_normal*desired
			var skin: Vector2 = witness.skin_point_m
			requests.append({"digit":digit.digit,"section":region.section,"fixed_upstream_count":0,
				"skin_point_world":digit.plane_to_world*Vector3(skin.x,skin.y,0.0),
				"target_point_world":digit.plane_to_world*Vector3(target.x,target.y,0.0),
				"skin_origin_id":owner.ROOT,"target_origin_id":owner.ROOT,"source_id":witness.source_id})
	return requests


static func op_handle_native_proposal(owner: Object, context: Dictionary, handle: Dictionary, sample: Dictionary, radius: float) -> Dictionary:
	var current: Dictionary = sample
	for identity: Array in owner._required_digit_contacts():
		if owner._is_cancelled(): return {"valid":false,"cancelled":true,"reason":"acquisition_cancelled"}
		if current.diagnostic_grip_accepted: return current
		var chosen: Dictionary = {}
		for request: Dictionary in owner._contact_requests(current):
			if request.digit==identity[0] and request.section==identity[1]: chosen=request; break
		if chosen.is_empty(): continue
		var candidate: Dictionary = await owner._runtime_work("_rigid_candidate",[context,current.parameters,current.translation_world])
		if not candidate.get("valid",false): return candidate
		var native_span := Chronology.begin("native.proposal", {"job_id":str(owner.get_instance_id()),"digit":identity[0],"section":identity[1]})
		var solved: Dictionary = await owner._native.solve(handle,candidate,[chosen])
		Chronology.finish(native_span, {"valid":solved.get("valid",false),"reason":solved.get("reason",""),"native_process_count":solved.get("native_process_count",0)})
		owner._native_calls+=int(solved.get("native_process_count",0))
		if not solved.get("valid",false): continue
		var parameters: Array = current.parameters.duplicate()
		for d: int in owner._selected_digits().size():
			for j: int in 3: parameters[d*3+j]=solved.angles[owner._selected_digits()[d]][j]
		var proposed: Dictionary = await owner._runtime_work("_circle_sample",[context,owner._clamped(context,parameters),radius])
		if not proposed.get("valid",false): continue
		if not owner._retains_observed_sections(current,proposed): continue
		if current.material_assessed and owner._safe(current) and not owner._safe(proposed): continue
		if owner._cost(owner._residual(proposed))<owner._cost(owner._residual(current)): current=proposed
	return current


static func op_handle_retains_observed_sections(owner: Object, before: Dictionary, after: Dictionary) -> bool:
	for d: int in before.digits.size():
		for r: int in 3:
			var old: Dictionary = before.digits[d].regions[r]
			var next: Dictionary = after.digits[d].regions[r]
			if old.contact_required and is_finite(old.nearest_gap_m) and not is_finite(next.nearest_gap_m): return false
	return true


static func op_handle_preserves(owner: Object, sample: Dictionary) -> bool:
	if not owner._safe(sample): return false
	for section: String in owner._preserve_guide:
		if not sample.guide_contacts.has(section): return false
	for section: String in owner._preserve_material:
		if not sample.material_contacts.has(section): return false
	return true


static func op_handle_reseat_path(owner: Object, context: Dictionary, before: Dictionary, after: Dictionary, radius: float) -> bool:
	if owner._is_cancelled(): return false
	var samples: int = 1
	for i: int in owner._angle_count(): samples=maxi(samples,ceili(absf(after.parameters[i]-before.parameters[i])/deg_to_rad(0.25)))
	if samples>32: return false
	for step: int in range(1,samples+1):
		if owner._is_cancelled(): return false
		var p: Array = before.parameters.duplicate()
		for i: int in owner._angle_count(): p[i]=lerpf(before.parameters[i],after.parameters[i],float(step)/float(samples))
		var checked: Dictionary = owner._circle_sample(context,p,radius)
		owner._path_checks+=1
		if not checked.get("valid",false) or checked.guide_id!=before.guide_id or not owner._preserves(checked): return false
	return true


static func op_handle_respond(owner: Object, context: Dictionary, seed: Dictionary, radius: float, label: String, iterations: int, reseat: bool = false) -> Dictionary:
	if owner._is_cancelled(): return {"valid":false,"cancelled":true,"reason":"acquisition_cancelled"}
	var current: Dictionary = seed
	var damping: float = 0.1
	var termination: String = "response_iteration_budget_not_physical_limit"
	var used: int = 0
	for iteration: int in iterations:
		if owner._is_cancelled(): return {"valid":false,"cancelled":true,"reason":"acquisition_cancelled"}
		owner._progress_update({"stage":label,"iteration":iteration,"iteration_limit":iterations,"evaluations":owner._circle_evaluations})
		if not reseat and current.diagnostic_grip_accepted:
			termination="sufficient_material_contact"; break
		var iteration_span := Chronology.begin("response.iteration", {"job_id":str(owner.get_instance_id()),"label":label,"iteration":iteration,"reseat":reseat,"damping":damping})
		used=iteration+1
		var residual: PackedFloat64Array = owner._residual(current)
		var jacobian: Array = []
		for index: int in owner._parameter_count():
			var column: PackedFloat64Array = []; column.resize(residual.size())
			if not(reseat and index>=owner._angle_count()):
				for direction: float in [1.0,-1.0]:
					var p: Array = current.parameters.duplicate()
					p[index]+=owner._solve_scale(index)*0.01*direction
					p=owner._clamped(context,p)
					var actual: float = (p[index]-current.parameters[index])/owner._solve_scale(index)
					if absf(actual)<1e-8: continue
					Chronology.event("response.finite_difference", {"job_id":str(owner.get_instance_id()),"label":label,"iteration":iteration,"coordinate":index,"direction":direction})
					var probe: Dictionary = owner._circle_sample(context,p,radius)
					if not probe.get("valid",false): continue
					var other: PackedFloat64Array = owner._residual(probe)
					for row: int in residual.size(): column[row]=(other[row]-residual[row])/actual
					break
			jacobian.append(column)
		var matrix: Array = []; var rhs: PackedFloat64Array = []; rhs.resize(owner._parameter_count())
		for i: int in owner._parameter_count():
			var row_values: PackedFloat64Array = []; row_values.resize(owner._parameter_count())
			for j: int in owner._parameter_count():
				for row: int in residual.size(): row_values[j]+=jacobian[i][row]*jacobian[j][row]
			row_values[i]+=damping; matrix.append(row_values)
			for row: int in residual.size(): rhs[i]-=jacobian[i][row]*residual[row]
		var delta: PackedFloat64Array = owner._bounded_step(context,current.parameters,matrix,rhs)
		if delta.is_empty():
			termination="singular_response_not_physical_limit"
			Chronology.finish(iteration_span, {"termination":termination,"improved":false})
			break
		var divisor: float = 1.0
		for i: int in owner._parameter_count(): divisor=maxf(divisor,absf(delta[i])*(3.0 if reseat else 1.0))
		var improved: bool = false
		for fraction: float in [1.0,0.5,0.25,0.125,0.0625]:
			Chronology.event("response.line_search_trial", {"job_id":str(owner.get_instance_id()),"label":label,"iteration":iteration,"fraction":fraction})
			var p: Array = current.parameters.duplicate()
			for i: int in owner._parameter_count(): p[i]+=delta[i]/divisor*owner._solve_scale(i)*fraction
			var trial: Dictionary = owner._circle_sample(context,owner._clamped(context,p),radius)
			if not trial.get("valid",false) or owner._cost(owner._residual(trial))>=owner._cost(residual)-1e-8:
				Chronology.event("response.line_search_rejected", {"reason":"invalid_or_no_cost_improvement","fraction":fraction})
				continue
			if not owner._retains_observed_sections(current,trial):
				Chronology.event("response.line_search_rejected", {"reason":"lost_observed_section","fraction":fraction})
				continue
			if not reseat and current.material_assessed and owner._safe(current) and not owner._safe(trial):
				Chronology.event("response.line_search_rejected", {"reason":"material_safety","fraction":fraction})
				continue
			if reseat and (not owner._preserves(trial) or not owner._reseat_path(context,current,trial,radius)):
				Chronology.event("response.line_search_rejected", {"reason":"reseat_contact_preservation_or_path","fraction":fraction})
				continue
			current=trial; improved=true; damping=maxf(0.0001,damping*0.5)
			Chronology.event("response.line_search_accepted", {"fraction":fraction,"material_contacts":current.material_contacts})
			if reseat:
				for id: String in current.guide_contacts:
					if not owner._preserve_guide.has(id): owner._preserve_guide.append(id)
				for id: String in current.material_contacts:
					if not owner._preserve_material.has(id): owner._preserve_material.append(id)
			break
		if iteration_span!=0:
			Chronology.finish(iteration_span, {"improved":improved,"cost":owner._cost(owner._residual(current)),"evaluations":owner._circle_evaluations,"material_contacts":current.material_contacts})
		if not improved:
			damping*=10.0
			if damping>10000.0: termination="no_legal_local_improvement" if reseat else "response_stalled_not_physical_limit"; break
	if owner._retain_history():
		owner._response_runs.append({"label":label,"iterations":used,"termination":termination,"cost":owner._cost(owner._residual(current)),"material_contacts":current.material_contacts.duplicate()})
	Chronology.event("response.termination", {"job_id":str(owner.get_instance_id()),"label":label,"iterations":used,"termination":termination,"material_contacts":current.material_contacts})
	return current
