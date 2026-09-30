extends "res://tools/grip_plane_proof/run_full_hand_grip_proof.gd"

const ExactDepthCache = preload("res://tools/grip_plane_proof/exact_cached_planar_skin_overlap_budget.gd")

## Bounded profiling of existing sample mathematics, never an acquisition search.
## Every timed wrapper delegates to its original implementation unchanged.
class SampleClock extends RefCounted:
	var enabled: bool = false
	var buckets: Dictionary = {}
	func add(label: String, elapsed_us: int, cache_hit: bool = false, extra: Dictionary = {}) -> void:
		if not enabled: return
		if not buckets.has(label):
			buckets[label] = {"calls":0,"cache_hits":0,"executed":0,"total_us":0,"minimum_us":elapsed_us,"maximum_us":0}
		var item: Dictionary = buckets[label]
		item.calls+=1; item.cache_hits+=int(cache_hit); item.executed+=int(not cache_hit)
		item.total_us+=elapsed_us; item.minimum_us=mini(item.minimum_us,elapsed_us); item.maximum_us=maxi(item.maximum_us,elapsed_us)
		for key: String in extra: item[key]=item.get(key,0)+extra[key]

class TimedObserver extends "res://tools/grip_plane_proof/prepared_grip_slice_contact.gd":
	var clock: SampleClock
	func slice_candidate(prepared: Dictionary, candidate: Dictionary, plane: Transform3D, origin: StringName) -> Dictionary:
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = super.slice_candidate(prepared,candidate,plane,origin)
		clock.add("skin_slice_with_validation",Time.get_ticks_usec()-started,false,{
			"reported_plane_validation_us":roundi(float(result.get("plane_origin_validation_ms",0.0))*1000.0),
			"reported_triangle_slice_us":roundi(float(result.get("skin_slice_ms",0.0))*1000.0),
			"returned_segments":result.get("segments",[]).size()})
		return result

class TimedPalm extends "res://tools/grip_plane_proof/prepared_palmar_slice_region.gd":
	var clock: SampleClock
	func annotate(prepared: Dictionary, candidate: Dictionary, slice: Dictionary, plane: Transform3D) -> Dictionary:
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = super.annotate(prepared,candidate,slice,plane)
		clock.add("palm_annotation_with_validation",Time.get_ticks_usec()-started,false,{"returned_segments":result.get("segments",[]).size()})
		return result

class TimedCircle extends "res://tools/grip_plane_proof/planar_circle_skin_contact.gd":
	var clock: SampleClock
	func evaluate(segments: Array, center: Vector2, radius: float, origin: StringName, source: StringName) -> Dictionary:
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = super.evaluate(segments,center,radius,origin,source)
		clock.add("guide_analytic_circle",Time.get_ticks_usec()-started,false,{"queried_segments":segments.size()})
		return result

var _sample_clock := SampleClock.new()
var _profile_source: Dictionary = {}
var _profile_source_path: String = ""
var _profile_source_hash: String = ""
var _use_exact_depth_cache: bool = false
var _query_fingerprints: Array = []

func _run() -> void:
	_profile_source_path=OS.get_environment("THE_WILL_GRIP_PROFILE_REPORT").replace("\\","/").simplify_path()
	if not _profile_source_path.begins_with("C:/WORKSPACE/test_artifacts/") or _profile_source_path.get_extension()!="json":
		push_error("Explicit workspace THE_WILL_GRIP_PROFILE_REPORT required"); quit(1); return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_profile_source_path))
	if not parsed is Dictionary or parsed.get("schema")!="handle_grip_process_proof_v1" or not parsed.get("ok",false):
		push_error("Profiler requires a completed valid handle process report"); quit(1); return
	_profile_source=parsed; _profile_source_hash=FileAccess.get_sha256(_profile_source_path)
	if parsed.get("selected_digits")!=["middle","thumb","index","ring","pinky"] or parsed.get("anatomy_signature")!=OS.get_environment("THE_WILL_ANATOMY_RESOURCE_PATH").get_file().get_basename():
		push_error("Profile source must match all-five anatomy and digit order"); quit(1); return
	var paths: Dictionary = {"runner":"run_handle_grip_process_proof.gd","depth":"planar_skin_overlap_budget.gd","palm":"prepared_palmar_slice_region.gd","progression":"planar_grip_guide_progression.gd","skin":"prepared_hand_candidate_pose.gd"}
	for key: String in paths:
		if parsed.get("source_sha256",{}).get(key)!=FileAccess.get_sha256("res://tools/grip_plane_proof/"+paths[key]):
			push_error("Profile source implementation mismatch: "+key); quit(1); return
	if parsed.get("envelope_configuration_sha256")!=FileAccess.get_sha256(CONFIG_PATH):
		push_error("Profile source envelope configuration mismatch"); quit(1); return
	var original_sources: Dictionary = {}
	for evidence: Dictionary in parsed.get("anatomy_extension_evidence",[]):
		original_sources[evidence.original_trace]=evidence.original_trace_sha256
	for requested: String in OS.get_environment("THE_WILL_GRIP_PLACEMENT_PATHS").split(";",false):
		var path: String = requested.replace("\\","/").simplify_path()
		if not original_sources.has(path) or FileAccess.get_sha256(path)!=original_sources[path]:
			push_error("Profiler original trace does not match source report"); quit(1); return
	var profile_id: String = str(parsed.get("template_fixture",{}).get("profile_id",""))
	if profile_id!=OS.get_environment("THE_WILL_GRIP_TEMPLATE_ID"):
		push_error("Profiler fixture must match source report"); quit(1); return
	var observer := TimedObserver.new(); observer.clock=_sample_clock; _observer=observer
	var palm := TimedPalm.new(); palm.clock=_sample_clock; _palm=palm
	var circle := TimedCircle.new(); circle.clock=_sample_clock; _circle_query=circle
	_use_exact_depth_cache=OS.get_environment("THE_WILL_GRIP_EXACT_DEPTH_CACHE")=="1"
	if _use_exact_depth_cache: _depth=ExactDepthCache.new()
	await super._run()

func _report_stem() -> String:
	return "profile_full_hand_grip_sample_cached" if _use_exact_depth_cache else "profile_full_hand_grip_sample"

func _report_extensions() -> Dictionary:
	var out: Dictionary = super._report_extensions()
	out["schema"]="full_hand_grip_sample_profile_v1"
	out["scope"]="one_saved_material_pose_and_seventeen_bound_aware_finite_difference_coordinates_per_hand"
	out["profile_source_report"]=_profile_source_path; out["profile_source_sha256"]=_profile_source_hash
	out["profiler_sha256"]=FileAccess.get_sha256(get_script().resource_path)
	out["full_hand_runner_sha256"]=FileAccess.get_sha256("res://tools/grip_plane_proof/run_full_hand_grip_proof.gd")
	out["search_performed"]=false; out["native_processing_performed"]=false; out["cache_implementation_changed"]=_use_exact_depth_cache
	out["exact_depth_cache_enabled"]=_use_exact_depth_cache
	out["exact_depth_cache_sha256"]=FileAccess.get_sha256("res://tools/grip_plane_proof/exact_cached_planar_skin_overlap_budget.gd") if _use_exact_depth_cache else ""
	out["probe_policy"]="same_direction_step_clamping_and_first_valid_probe_as_response_controller; shared_translation_unfrozen"
	out["timing_policy"]="microseconds; component buckets disjoint; sample_total includes components; observer internal timing fields are subsets"
	out["limitations"]=["No native solve or search cost measured","Preparation and capture extension excluded from sample buckets","Palm validation remains included in palm annotation","Instrumentation overhead included","One local Jacobian neighborhood cannot establish whole-acquisition latency"]
	return out

func _rigid_candidate(context: Dictionary, parameters: Array, translation: Vector3) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._rigid_candidate(context,parameters,translation)
	_sample_clock.add("candidate_build_and_rigid_presentation",Time.get_ticks_usec()-started,false,{
		"reported_builder_us":roundi(float(result.get("evaluation_ms",0.0))*1000.0),
		"affected_vertex_count_sum":result.get("affected_vertex_count",0),"full_vertex_count_sum":result.get("full_vertex_count",0)})
	return result

func _circle_targets(context: Dictionary, candidate: Dictionary, translation: Array) -> Dictionary:
	var key: String = var_to_bytes(translation).hex_encode()
	var hit: bool = _slice_cache.has(key) and _slice_cache[key].get("prepared_index",false)
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._circle_targets(context,candidate,translation)
	_sample_clock.add("weapon_sections",Time.get_ticks_usec()-started,hit)
	return result

func _guide(context: Dictionary, section: Dictionary, digit: StringName, radius: float) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var cached: bool = _fixed_guides.has(digit)
	var extra: Dictionary = {"fixed_guide_hits":int(cached),"preparation_cache_hits":0,"preparation_cache_misses":0,"sample_cache_hits":0}
	if not cached and _guide_phase!="circle":
		var key: String = var_to_bytes([section.polygon,section.center,section.origin_id]).hex_encode()
		var prepared_hit: bool = _guide_preparation_cache.has(key)
		extra.preparation_cache_hits=int(prepared_hit); extra.preparation_cache_misses=int(not prepared_hit)
		if prepared_hit:
			var enclosure: float = 0.0
			for point: Vector2 in section.polygon: enclosure=maxf(enclosure,point.distance_to(section.center))
			var sample_key: String = var_to_bytes([_guide_phase,_guide_amount,enclosure]).hex_encode()
			cached=_guide_preparation_cache[key].get("sample_cache",{}).has(sample_key)
			extra.sample_cache_hits=int(cached)
	var result: Dictionary = super._guide(context,section,digit,radius)
	_sample_clock.add("guide_construction_or_lookup",Time.get_ticks_usec()-started,cached,extra)
	return result

func _measure(segments: Array, target: Dictionary, plane: StringName) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._measure(segments,target,plane)
	var extra: Dictionary = {"queried_segments":segments.size(),"depth_evaluations":result.get("depth_evaluations",0)}
	for key: String in result.get("work_counts",{}): extra[key]=result.work_counts[key]
	_sample_clock.add("guide_polygon_depth" if str(target.get("source_id","")).ends_with(":grip_guide") else "material_polygon_depth",Time.get_ticks_usec()-started,false,extra)
	if _sample_clock.enabled:
		var stamp_started: int = Time.get_ticks_usec()
		var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(var_to_bytes(result))
		_query_fingerprints.append({"plane":plane,"source":target.get("source_id",&""),"sha256":digest.finish().hex_encode()})
		_sample_clock.add("measurement_fingerprint",Time.get_ticks_usec()-stamp_started)
	return result

func _circle_sample(context: Dictionary, parameters: Array, radius: float, geometry: bool = false) -> Dictionary:
	var before: int = _circle_evaluations
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._circle_sample(context,parameters,radius,geometry)
	_sample_clock.add("sample_total",Time.get_ticks_usec()-started,_circle_evaluations==before)
	return result

func _search(context: Dictionary) -> Dictionary:
	_sample_clock.enabled=false
	var source_case: Dictionary = {}
	for item: Dictionary in _profile_source.cases:
		if item.get("slot")==str(context.slot): source_case=item; break
	if source_case.is_empty(): return {"valid":false,"reason":"profile_source_missing_selected_hand","slot":context.slot}
	var source: Dictionary = source_case.get("selected",{})
	if not source.get("valid",false) or not source.get("material_assessed",false) or source.get("parameters",[]).size()!=_parameter_count():
		return {"valid":false,"reason":"profile_source_requires_valid_material_pose_with_seventeen_parameters","slot":context.slot}
	if int(source_case.get("source_transaction",-1))!=int(context.adapter.base_packet.get("transaction_serial",-2)):
		return {"valid":false,"reason":"profile_source_capture_transaction_mismatch","slot":context.slot}
	var parameters: Array = source.parameters.duplicate()
	for value: Variant in parameters:
		if not (value is float or value is int) or not is_finite(float(value)): return {"valid":false,"reason":"nonfinite_profile_parameter"}
	var radius: float = float(source.radius_m)
	_circle_cache.clear(); _slice_cache.clear(); _guide_preparation_cache.clear(); _fixed_guides.clear(); _frozen_parameters.clear()
	_circle_evaluations=0; _set_phase(str(source.phase),float(source.amount))
	# JSON prints decimal representations of the original Float32 offsets. Put
	# those back through the same clamp/Float32 boundary before probing. A larger
	# difference is a real input mismatch, not a profiling tolerance to grip.
	var restored: Array = _clamped(context,parameters)
	var round_trip_delta: float = 0.0
	for index: int in parameters.size():
		round_trip_delta=maxf(round_trip_delta,absf(float(restored[index])-float(parameters[index])))
	if round_trip_delta>1e-12: return {"valid":false,"reason":"saved_profile_parameters_outside_current_limits","maximum_round_trip_delta":round_trip_delta}
	parameters=restored
	_query_fingerprints.clear()
	if _use_exact_depth_cache and not _depth.begin_acquisition(StringName(str(context.slot)+":"+str(context.adapter.base_packet.pose_id))):
		return {"valid":false,"reason":"cannot_begin_exact_depth_cache_acquisition"}
	_sample_clock.buckets.clear(); _sample_clock.enabled=true
	var started: int = Time.get_ticks_usec()
	var baseline: Dictionary = _circle_sample(context,parameters,radius)
	if not baseline.get("valid",false): _sample_clock.enabled=false; return baseline
	var samples: Array = [{"coordinate":-1,"label":"source_material_pose","valid":true,"parameters":parameters.duplicate(),"components":_sample_clock.buckets.duplicate(true)}]
	var failures: Array = []
	var comparison: Dictionary = _compare_source(baseline,source)
	if not comparison.matches: failures.append("reconstructed_source_metrics_mismatch")
	var residual: PackedFloat64Array = _residual(baseline)
	for index: int in _parameter_count():
		var row: Dictionary = {"coordinate":index,"attempts":[],"valid_probe_found":false,"zero_step_at_both_bounds":true}
		for direction: float in [1.0,-1.0]:
			var p: Array = parameters.duplicate()
			p[index]+=_solve_scale(index)*0.01*direction; p=_clamped(context,p)
			var actual: float = (p[index]-parameters[index])/_solve_scale(index)
			if absf(actual)<1e-8: continue
			row.zero_step_at_both_bounds=false
			var old_buckets: Dictionary = _sample_clock.buckets.duplicate(true)
			var probe: Dictionary = _circle_sample(context,p,radius)
			var attempt: Dictionary = {"direction":direction,"actual_scaled_step":actual,"valid":probe.get("valid",false),"reason":probe.get("reason",""),"components":_bucket_delta(old_buckets,_sample_clock.buckets)}
			row.attempts.append(attempt)
			if not probe.get("valid",false): continue
			var values: PackedFloat64Array = _residual(probe)
			var column: PackedFloat64Array = []
			for r: int in residual.size(): column.append((values[r]-residual[r])/actual)
			row["jacobian_column"]=column; row["parameters"]=p; row.valid_probe_found=true
			break
		samples.append(row)
	_sample_clock.enabled=false
	var elapsed: float = float(Time.get_ticks_usec()-started)/1000.0
	var totals: Dictionary = _sample_clock.buckets.duplicate(true)
	var components_us: int = 0
	for name: String in totals:
		if name!="sample_total": components_us+=int(totals[name].total_us)
	return {"valid":failures.is_empty(),"reason":"" if failures.is_empty() else str(failures),"slot":context.slot,
		"selected":baseline,"source_phase":source.phase,"source_amount":source.amount,"source_radius_m":radius,
		"source_comparison":comparison,"parameter_json_round_trip_maximum":round_trip_delta,"profile_samples":samples,"component_totals":totals,
		"measurement_fingerprints":_query_fingerprints.duplicate(true),
		"exact_depth_cache_statistics":_depth.cache_statistics() if _use_exact_depth_cache else {},
		"sample_unattributed_us":int(totals.sample_total.total_us)-components_us,
		"finite_difference_coordinates":_parameter_count(),"sample_request_bound":1+2*_parameter_count(),
		"evaluation_count":_circle_evaluations,"total_search_ms":elapsed,"profile_wall_ms":elapsed,
		"shared_translation_frozen":false,"native_process_count":0,"search_performed":false,"production_pose_written":false,"grip_accepted":false}

func _bucket_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for name: String in after:
		var item: Dictionary = {}
		for field: String in after[name]:
			if field in ["minimum_us","maximum_us"]: continue
			item[field]=after[name][field]-before.get(name,{}).get(field,0)
		if item.calls>0: out[name]=item
	return out

func _compare_source(actual: Dictionary, saved: Dictionary) -> Dictionary:
	var maximum: float = 0.0
	var matches: bool = actual.material_contacts==saved.material_contacts and actual.guide_contacts==saved.guide_contacts and actual.material_safe==saved.material_safe and actual.guide_safe==saved.guide_safe
	if actual.digits.size()!=saved.digits.size(): return {"matches":false,"reason":"digit_count"}
	for index: int in actual.digits.size():
		var a: Dictionary = actual.digits[index]; var b: Dictionary = saved.digits[index]
		matches=matches and str(a.digit)==str(b.digit) and a.regions.size()==b.regions.size()
		for section: int in mini(a.regions.size(),b.regions.size()):
			for field: String in ["nearest_gap_m","material_gap_m","depth_upper_m","guide_depth_upper_m"]:
				var value: float = float(a.regions[section][field]); var reference: Variant = b.regions[section][field]
				if reference==null: matches=matches and not is_finite(value)
				else: maximum=maxf(maximum,absf(value-float(reference)))
	return {"matches":matches and maximum<=NUMERIC_GUARD_M,"maximum_metric_difference_m":maximum,"comparison_tolerance_m":NUMERIC_GUARD_M,"comparison_scope":"JSON_round_trip_saved_metrics; not an acceptance_rule_change"}
