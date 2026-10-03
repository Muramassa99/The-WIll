extends SceneTree

## Numeric-kernel replacement proof. This does not solve/apply a hand pose.
## The GDScript implementation stays the reference; both implementations see
## identical validated target packets, source-order skin edges and settings.
const Reference = preload("res://runtime/player/grip/planar_skin_overlap_budget.gd")
const CAPTURE_PATH := "C:/WORKSPACE/test_artifacts/contact_driven_preparation_2026-10-01T00-31-21.json"
const CAPTURE_HASH := "7e7f5731c1a6dad5eec4961c1d7530afdc6af50b1754de885f8ee68eb710a34f"
const PLANE := &"NativeOverlapVerificationPlaneOrigin"
const USER_ACCURACY_M := 0.00005
const STRICT_SCALAR_ERROR := 0.000000000001
const STRICT_VECTOR_ERROR := 0.00000001
const BASE_CONFIG := {"max_evaluations_per_segment":64,"numeric_epsilon_m":0.000000001,
	"depth_bound_tolerance_m":0.00001,"refine_depth_after_cap":false,"use_boundary_pruning":true}
var _reference := Reference.new()
var _native: Object
var _checks: Array = []
var _fixtures: Array = []
var _benchmark_inputs: Array = []
var _benchmarks: Array = []
var _adapter_observations: Array = []
var _failures := 0
var _captured_targets := 0
var _compared_segments := 0
var _reference_usec := 0
var _native_usec := 0
var _maximum_position_depth_error_m := 0.0
var _started := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_started = Time.get_ticks_usec()
	if not _check(ClassDB.class_exists(&"GripContactKernel"),"compiled GripContactKernel is registered"):
		_finish(); return
	_native = ClassDB.instantiate(&"GripContactKernel")
	if not _check(_native != null,"compiled kernel instance is available"):
		_finish(); return
	if not _check(FileAccess.get_sha256(CAPTURE_PATH)==CAPTURE_HASH,"current accepted capture matches frozen SHA256"):
		_finish(); return
	_synthetic_cases()
	_invalid_outer_cases()
	_captured_cases()
	_check(_captured_targets==12,"both hands: selected Middle and one follower, each against all three saved targets")
	_cache_adapter_checks()
	_benchmark_captured_inputs()
	_check(FileAccess.get_sha256(CAPTURE_PATH)==CAPTURE_HASH,"captured input file remains unchanged")
	_native.call("clear_targets")
	if not _benchmark_inputs.is_empty():
		var previous: Dictionary = _benchmark_inputs[0]
		var stale: Dictionary = _native.call("evaluate_segment",previous.segments[0],previous.target_id,0.00001,0.000000001,64,false,true)
		_check(not stale.get("valid",false),"clearing native targets invalidates earlier handles")
	_finish()


func _config(changes: Dictionary) -> Dictionary:
	var result := BASE_CONFIG.duplicate(true)
	result.merge(changes,true)
	return result


func _standard_configurations() -> Array:
	return [{"name":"saved_0.01mm","config":BASE_CONFIG.duplicate(true)},
		{"name":"requested_0.05mm","config":_config({"depth_bound_tolerance_m":USER_ACCURACY_M})}]


func _synthetic_cases() -> void:
	var square := PackedVector2Array([Vector2(-0.01,-0.01),Vector2(0.01,-0.01),Vector2(0.01,0.01),Vector2(-0.01,0.01)])
	var concave := PackedVector2Array([Vector2(-0.012,-0.012),Vector2(-0.002,-0.012),Vector2(-0.002,-0.004),
		Vector2(0.012,-0.004),Vector2(0.012,0.004),Vector2(-0.002,0.004),Vector2(-0.002,0.012),Vector2(-0.012,0.012)])
	var tiny_edges := PackedVector2Array([Vector2(-0.01,-0.01),Vector2(0,-0.01),Vector2(0.0000001,-0.01),
		Vector2(0.01,-0.01),Vector2(0.01,0.01),Vector2(-0.01,0.01)])
	var reversed := square.duplicate()
	reversed.reverse()
	var closed := square.duplicate()
	closed.append(closed[0])
	var thin := PackedVector2Array([Vector2(-0.01,-0.00001),Vector2(0.01,-0.00001),Vector2(0.01,0.00001),Vector2(-0.01,0.00001)])
	var many_edges := PackedVector2Array()
	for index: int in 128:
		var angle: float = TAU*float(index)/128.0
		var radius: float = 0.012 if index%2==0 else 0.009
		many_edges.append(Vector2(cos(angle),sin(angle))*radius)
	var contours: Array = [{"name":"square","polygon":square}, {"name":"concave_recess","polygon":concave},
		{"name":"sub_weld_edges","polygon":tiny_edges},{"name":"clockwise","polygon":reversed},
		{"name":"explicit_closed_endpoint","polygon":closed},{"name":"20micron_thin_shape","polygon":thin},
		{"name":"128_edge_concave_tree","polygon":many_edges}]
	for contour: Dictionary in contours:
		var configurations := _standard_configurations()
		configurations.append({"name":"exhaustive","config":_config({"use_boundary_pruning":false})})
		configurations.append({"name":"minimal_budget","config":_config({"max_evaluations_per_segment":3})})
		configurations.append({"name":"refine_after_cap","config":_config({"refine_depth_after_cap":true,"max_evaluations_per_segment":32})})
		_compare_fixture("synthetic/"+contour.name,contour.polygon,_synthetic_segments(Vector2.ZERO),PLANE,configurations)
	var shift := Vector2(-0.137,-0.213)
	var translated := PackedVector2Array()
	for point: Vector2 in concave: translated.append(point+shift)
	_compare_fixture("synthetic/translated_concave",translated,_synthetic_segments(shift),PLANE,_standard_configurations())
	_analytic_expectations(square)


func _synthetic_segments(shift: Vector2) -> Array:
	var samples: Array = [
		[Vector2(-0.03,0.03),Vector2(0.03,0.03),0.0005,"separated"],
		[Vector2(-0.03,0.03),Vector2(0.03,0.03),0.0,"separated_zero_cap"],
		[Vector2(-0.02,0),Vector2(0.02,0),0.0005,"crossing"],
		[Vector2(-0.005,-0.003),Vector2(0.006,0.004),0.002,"inside"],
		[Vector2(-0.005,-0.003),Vector2(0.006,0.004),0.0,"inside_zero_cap"],
		[Vector2(-0.02,-0.01),Vector2(0.02,-0.01),0.0,"coincident_boundary"],
		[Vector2(-0.02,-0.02),Vector2(-0.01,-0.01),0.0,"corner_contact"],
		[Vector2(-0.015,0.01),Vector2(0.015,0.01),0.0005,"flat_tangent"],
		[Vector2(-0.02,0.02),Vector2(0.02,-0.02),0.0005,"corner_crossing"],
		[Vector2(-0.0000001,0),Vector2(0.0000001,0),0.01,"tiny_skin_equidistant_edges"],
		[Vector2(-0.002,0),Vector2(0.002,0),0.01,"nearest_edge_ties"],
		[Vector2(-0.001,0.0097),Vector2(0.001,0.0097),0.0005,"shallow_within_cap"],
		[Vector2(-0.001,0.0093),Vector2(0.001,0.0093),0.0005,"shallow_exceeds_cap"],
		[Vector2(-0.001,0.0095002),Vector2(0.001,0.0095002),0.0005,"near_cap_below"],
		[Vector2(-0.001,0.0095),Vector2(0.001,0.0095),0.0005,"at_cap"],
		[Vector2(-0.001,0.0094998),Vector2(0.001,0.0094998),0.0005,"near_cap_above"],
		[Vector2(-0.2,-0.3),Vector2(-0.19,-0.28),0.0,"far_negative"]]
	var segments: Array = []
	for sample: Array in samples:
		segments.append({"a":sample[0]+shift,"b":sample[1]+shift,"max_inward_depth_m":sample[2],
			"origin_id":PLANE,"source_id":StringName(sample[3])})
	return segments


func _analytic_expectations(square: PackedVector2Array) -> void:
	var target := _reference.prepare_ordered_target(square,PLANE,&"AnalyticSquare",true)
	var segments := _synthetic_segments(Vector2.ZERO)
	for configuration: Dictionary in _standard_configurations():
		var result := _reference.evaluate_segments(segments,target,PLANE,configuration.config)
		if not _check(result.get("valid",false),configuration.name+": analytic reference is valid"): continue
		var by_source: Dictionary = {}
		for item: Dictionary in result.segments: by_source[String(item.source_id)] = item
		_check(by_source.shallow_within_cap.cap_status==&"within",configuration.name+": 0.30 mm penetration fits 0.50 mm cap")
		_check(by_source.shallow_exceeds_cap.cap_status==&"exceeds",configuration.name+": 0.70 mm penetration exceeds 0.50 mm cap")
		_check(by_source.crossing.cap_status==&"exceeds" and by_source.crossing.max_inward_depth_lower_m>0.0099,
			configuration.name+": crossing is tested along its interior, not endpoints alone")
		_check(by_source.inside_zero_cap.cap_status==&"exceeds",configuration.name+": inside material with zero allowance exceeds cap")
		_check(by_source.separated_zero_cap.cap_status==&"unresolved" and by_source.separated_zero_cap.inside_interval_count==0
			and by_source.separated_zero_cap.contact.distance_m>0.0199,
			configuration.name+": zero-cap exterior retains mature unresolved status and exterior evidence")
		for pair: Array in [["shallow_within_cap",0.0003],["shallow_exceeds_cap",0.0007],["crossing",0.01]]:
			var item: Dictionary = by_source[pair[0]]
			_check(item.max_inward_depth_lower_m<=pair[1]+0.00000001 and item.max_inward_depth_upper_m>=pair[1]-0.00000001,
				configuration.name+": known depth enclosed by bounds for "+pair[0])


func _invalid_outer_cases() -> void:
	var square := PackedVector2Array([Vector2(0,0),Vector2(0.01,0),Vector2(0.01,0.01),Vector2(0,0.01)])
	var target := _reference.prepare_ordered_target(square,PLANE,&"ValidationSquare",true)
	var segment: Dictionary = _synthetic_segments(Vector2.ZERO)[0]
	var zero_segment := segment.duplicate(true)
	zero_segment.b=zero_segment.a
	var mismatched := segment.duplicate(true)
	mismatched.origin_id=&"DifferentPlaneOrigin"
	var negative_cap := segment.duplicate(true)
	negative_cap.max_inward_depth_m=-1.0
	var missing_source := segment.duplicate(true)
	missing_source.erase("source_id")
	var native_target_id: int = int(_native.call("prepare_target",target))
	_check(native_target_id>0,"native invalid-input tests have a valid target handle")
	for invalid: Dictionary in [{"name":"zero_length","segment":zero_segment},{"name":"mismatched_origin","segment":mismatched},
		{"name":"negative_cap","segment":negative_cap},{"name":"missing_source","segment":missing_source}]:
		_check(not _reference.evaluate_segments([invalid.segment],target,PLANE,BASE_CONFIG).get("valid",false),
			"unchanged GDScript boundary rejects "+invalid.name+" before native dispatch")
		var rejected: Dictionary = _native.call("evaluate_segment",invalid.segment,native_target_id,0.00001,0.000000001,64,false,true)
		_check(not rejected.get("valid",false),"native boundary independently rejects "+invalid.name)
	_check(not _reference.evaluate_segments([segment],target,&"DifferentPlaneOrigin",BASE_CONFIG).get("valid",false),"query plane mismatch rejected before native dispatch")
	_check(not _reference.evaluate_segments([],target,PLANE,BASE_CONFIG).get("valid",false),"empty segment list rejected before native dispatch")
	_check(not _reference.evaluate_segments([segment],target,PLANE,_config({"depth_bound_tolerance_m":0.0})).get("valid",false),"invalid tolerance rejected before native dispatch")
	var bad_tolerance: Dictionary = _native.call("evaluate_segment",segment,native_target_id,0.0,0.000000001,64,false,true)
	_check(not bad_tolerance.get("valid",false),"native boundary independently rejects zero tolerance")
	var crossing := PackedVector2Array([Vector2(0,0),Vector2(0.01,0.01),Vector2(0,0.01),Vector2(0.01,0)])
	var invalid_target := _reference.prepare_ordered_target(crossing,PLANE,&"InvalidTarget",true)
	_check(not invalid_target.get("valid",false),"self-crossing target rejected by unchanged topology preparation")
	_check(int(_native.call("prepare_target",invalid_target))==0,"native layer does not accept an invalid prepared target")
	var malformed: Dictionary = target.duplicate(true)
	malformed.edges=[Vector2.ZERO]
	_check(int(_native.call("prepare_target",malformed))==0,"native layer rejects malformed prepared edge storage")
	var invalid_handle: Dictionary = _native.call("evaluate_segment",segment,0,0.00001,0.000000001,64,false,true)
	_check(not invalid_handle.get("valid",false),"invalid native target handle fails explicitly")


func _captured_cases() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAPTURE_PATH))
	if not _check(raw is Dictionary and raw.get("cases") is Array,"parse frozen hand geometry capture"): return
	for hand: Dictionary in raw.cases:
		var follower: Dictionary = {}
		for stage: Dictionary in hand.stages:
			if stage.label=="follower_response_fixed_weapon":
				follower=stage
				break
		if not _check(not follower.is_empty(),str(hand.slot)+": captured fixed-weapon follower exists"): continue
		for stage: Dictionary in [hand.selected,follower]:
			if not _check(stage.get("digits") is Array and stage.digits.size()==1,str(hand.slot)+": one named digit plane"): continue
			var digit: Dictionary = stage.digits[0]
			var origin := StringName(digit.origin_id)
			var segments: Array = []
			for stored: Dictionary in digit.skin_segments:
				var segment := stored.duplicate(true)
				segment.a=_point(stored.a); segment.b=_point(stored.b)
				segment.origin_id=StringName(stored.origin_id); segment.source_id=StringName(stored.source_id)
				# Preserve live unassigned-skin policy: inherited numeric values do
				# not grant a blended/unclassified surface a positive allowance.
				if stored.get("allowance_unassigned",true): segment.max_inward_depth_m=0.0
				segments.append(segment)
			for field: String in ["handle_polygon","wrapper_polygon","palm_polygon"]:
				var polygon := PackedVector2Array()
				for point: Array in digit[field]: polygon.append(_point(point))
				var label: String = "captured/"+str(hand.slot)+"/"+str(digit.digit)+"/"+field
				_compare_fixture(label,polygon,segments,origin,_standard_configurations(),hand.slot=="hand_right" and digit.digit=="middle")
				_captured_targets+=1


func _point(pair: Array) -> Vector2:
	return Vector2(float(pair[0]),float(pair[1]))


func _compare_fixture(label: String,polygon: PackedVector2Array,segments: Array,origin: StringName,configurations: Array,benchmark: bool=false) -> void:
	var source := StringName(label)
	var input_before := var_to_bytes([polygon,segments])
	var started := Time.get_ticks_usec()
	var target := _reference.prepare_ordered_target(polygon,origin,source,true)
	var script_prepare_usec := Time.get_ticks_usec()-started
	if not _check(target.get("valid",false),label+": reference prepares complete target"): return
	var target_before := var_to_bytes(target)
	started=Time.get_ticks_usec()
	var target_id: int = int(_native.call("prepare_target",target))
	var native_prepare_usec := Time.get_ticks_usec()-started
	if not _check(target_id>0,label+": native receives immutable prepared target"): return
	for configuration: Dictionary in configurations:
		var config: Dictionary = configuration.config
		var config_before := var_to_bytes(config)
		var measured := _measure_pair(segments,target,origin,target_id,config,_fixtures.size()%2==0)
		var reference: Dictionary = measured.reference
		var native_segments: Array = measured.native_segments
		var differences: Array[String] = []
		var max_error_m := 0.0
		if _check(reference.get("valid",false),label+"/"+configuration.name+": reference evaluation is valid"):
			for index: int in reference.segments.size():
				var old: Dictionary = reference.segments[index].duplicate(true)
				old.erase("segment_index")
				var current: Dictionary = native_segments[index]
				var difference := _difference(old,current,"segment["+str(index)+"]")
				if not difference.is_empty() and differences.size()<8: differences.append(difference)
				max_error_m=maxf(max_error_m,_position_depth_error(old,current))
				_compared_segments+=1
		var name: String = label+"/"+configuration.name
		_check(differences.is_empty(),name+": identical discrete decisions, witnesses, ties and work counts; tight numeric parity "+"; ".join(differences))
		_check(max_error_m<=USER_ACCURACY_M,name+": all compared positions and depths within 0.05 mm")
		_check(var_to_bytes(config)==config_before,name+": caller configuration immutable")
		_reference_usec+=measured.reference_usec
		_native_usec+=measured.native_usec
		_maximum_position_depth_error_m=maxf(_maximum_position_depth_error_m,max_error_m)
		_fixtures.append({"name":name,"config":config,"strict_parity":differences.is_empty(),"differences":differences,
			"maximum_position_depth_error_m":max_error_m,"reference_usec":measured.reference_usec,"native_usec":measured.native_usec,
			"script_prepare_usec":script_prepare_usec,"native_prepare_usec":native_prepare_usec,
			"edge_count":target.edges.size(),"skin_segment_count":segments.size(),"reference_cap_status":reference.get("cap_status",""),
			"reference_work_counts":reference.get("work_counts",{}),"native_work_counts":_sum_work(native_segments)})
		if benchmark:
			_benchmark_inputs.append({"name":name,"segments":segments,"target":target,"origin":origin,"target_id":target_id,"config":config})
	_check(var_to_bytes(target)==target_before,label+": prepared target unchanged by all evaluations")
	_check(var_to_bytes([polygon,segments])==input_before,label+": source geometry unchanged")
	print("NATIVE_OVERLAP_FIXTURE ",label," complete")


func _measure_pair(segments: Array,target: Dictionary,origin: StringName,target_id: int,config: Dictionary,native_first: bool) -> Dictionary:
	var reference: Dictionary
	var native_segments: Array
	var reference_usec: int
	var native_usec: int
	var started: int
	if native_first:
		started=Time.get_ticks_usec()
		native_segments=_native_segments(segments,target,target_id,config)
		native_usec=Time.get_ticks_usec()-started
		started=Time.get_ticks_usec()
		reference=_reference.evaluate_segments(segments,target,origin,config)
		reference_usec=Time.get_ticks_usec()-started
	else:
		started=Time.get_ticks_usec()
		reference=_reference.evaluate_segments(segments,target,origin,config)
		reference_usec=Time.get_ticks_usec()-started
		started=Time.get_ticks_usec()
		native_segments=_native_segments(segments,target,target_id,config)
		native_usec=Time.get_ticks_usec()-started
	return {"reference":reference,"native_segments":native_segments,"reference_usec":reference_usec,"native_usec":native_usec}


func _native_segments(segments: Array,target: Dictionary,target_id: int,config: Dictionary) -> Array:
	var result: Array = []
	for segment: Dictionary in segments:
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		var scale_m: float = maxf(float(target.coordinate_scale_m),maxf(maxf(absf(a.x),absf(a.y)),maxf(absf(b.x),absf(b.y))))
		var epsilon: float = maxf(float(config.numeric_epsilon_m),maxf(1.0e-12,scale_m*1.0e-12))
		var item: Dictionary = _native.call("evaluate_segment",segment,target_id,float(config.depth_bound_tolerance_m),epsilon,
			int(config.max_evaluations_per_segment),bool(config.refine_depth_after_cap),bool(config.use_boundary_pruning))
		result.append(item)
	return result


func _benchmark_captured_inputs() -> void:
	_check(_benchmark_inputs.size()==6,"benchmark uses three right-Middle targets at both tolerances")
	# Already warmed by parity comparisons. Three repeats, alternating call order,
	# exclude preparation, comparison, file I/O and JSON serialization from timing.
	for item: Dictionary in _benchmark_inputs:
		var reference_times: Array[int] = []
		var native_times: Array[int] = []
		for iteration: int in 3:
			var measured := _measure_pair(item.segments,item.target,item.origin,item.target_id,item.config,iteration%2==0)
			reference_times.append(measured.reference_usec)
			native_times.append(measured.native_usec)
			var old: Dictionary = measured.reference
			var difference := ""
			for index: int in old.segments.size():
				var baseline: Dictionary = old.segments[index].duplicate(true)
				baseline.erase("segment_index")
				difference=_difference(baseline,measured.native_segments[index],"repeat.segment["+str(index)+"]")
				if not difference.is_empty(): break
			_check(difference.is_empty(),item.name+": repeated benchmark retains parity "+difference)
		var old_sorted := reference_times.duplicate()
		var new_sorted := native_times.duplicate()
		old_sorted.sort(); new_sorted.sort()
		_benchmarks.append({"name":item.name,"config":item.config,"reference_usec":reference_times,"native_usec":native_times,
			"reference_median_usec":old_sorted[1],"native_median_usec":new_sorted[1],
			"median_speedup":float(old_sorted[1])/float(maxi(1,new_sorted[1]))})


func _sum_work(segments: Array) -> Dictionary:
	var total: Dictionary = {}
	for segment: Dictionary in segments:
		for key: String in segment.get("work_counts",{}): total[key]=int(total.get(key,0))+int(segment.work_counts[key])
	return total


func _cache_adapter_checks() -> void:
	# Load dynamically: the root activates the adapter only after the user's
	# running baseline closes. Missing activation is a failed proof, not a skip.
	var adapter_path := "res://runtime/player/grip/native_cached_planar_skin_overlap_budget.gd"
	if not _check(ResourceLoader.exists(adapter_path),"native cache adapter is activated for verification"): return
	var adapter_script: Variant = ResourceLoader.load(adapter_path,"GDScript",ResourceLoader.CACHE_MODE_IGNORE)
	if not _check(adapter_script is GDScript and adapter_script.can_instantiate(),"native cache adapter script loads"): return
	var adapter: Variant = adapter_script.new()
	if not _check(adapter.configure_native_kernel(true),"adapter enables compiled kernel"): return
	if not _check(adapter.begin_acquisition(&"NativeAdapterVerificationAcquisition"),"adapter starts explicit acquisition"): return
	var square := PackedVector2Array([Vector2(-0.01,-0.01),Vector2(0.01,-0.01),Vector2(0.01,0.01),Vector2(-0.01,0.01)])
	var target := _reference.prepare_ordered_target(square,PLANE,&"AdapterSharedTargetSource",true)
	var all_segments := _synthetic_segments(Vector2.ZERO)
	var segments: Array = [all_segments[0],all_segments[2],all_segments[11]]
	var reference := _reference.evaluate_segments(segments,target,PLANE,BASE_CONFIG)
	var before_inputs := var_to_bytes([target,segments])
	var cold: Dictionary = adapter.evaluate_segments(segments,target,PLANE,BASE_CONFIG)
	_check(_difference(reference,cold,"adapter.cold").is_empty(),"adapter cold result matches complete reference packet")
	var cold_stats: Dictionary = adapter.cache_statistics()
	_adapter_observations.append({"stage":"cold","statistics":cold_stats})
	_check(cold_stats.contact_backend=="cpp" and cold_stats.native_kernel.segment_calls==3
		and cold_stats.native_kernel.fallback_calls==0 and cold_stats.native_kernel.target_preparations==1
		and cold_stats.entry_count==3 and cold_stats.target_count==1,
		"adapter cold batch computes three native segments, prepares target once, caches exact records, and never falls back")
	_check(int(adapter.get("_native_target_handle"))==0 and int(adapter.get("_native_query_depth"))==0,
		"adapter retires batch handle and query depth before returning")
	var native_object: RefCounted = adapter.get("_kernel")
	var retired: Dictionary = native_object.call("evaluate_segment",segments[0],1,0.00001,0.000000001,64,false,true)
	_check(not retired.get("valid",false),"first native target handle is unusable immediately after its batch")
	var warm: Dictionary = adapter.evaluate_segments(segments,target,PLANE,BASE_CONFIG)
	var warm_stats: Dictionary = adapter.cache_statistics()
	_check(_difference(reference,warm,"adapter.warm").is_empty(),"adapter warm result matches complete reference packet")
	_check(warm_stats.native_kernel.segment_calls==3 and warm_stats.native_kernel.target_preparations==1
		and warm_stats.cache_hits==3,"exact repeat hits all three cached records with no native preparation or segment work")
	# A caller owns this returned packet; mutating it must never poison memoized
	# contacts, depth bounds, decisions, or a subsequent caller's detached copy.
	warm.segments[0].contact.target_point_m=Vector2(99,99)
	warm.segments[0].cap_status=&"caller_mutation"
	warm.segments[0].max_inward_depth_upper_m=123.0
	var detached: Dictionary = adapter.evaluate_segments(segments,target,PLANE,BASE_CONFIG)
	var detached_stats: Dictionary = adapter.cache_statistics()
	_check(_difference(reference,detached,"adapter.detached").is_empty() and detached_stats.native_kernel.segment_calls==3
		and detached_stats.cache_hits==6,"mutating returned nested records does not alter cached geometry or decisions")
	var changed_polygon := PackedVector2Array()
	for point: Vector2 in square: changed_polygon.append(point+Vector2(0,0.002))
	# Same source and origin, different exact coordinates: identity must include
	# actual geometry, not merely a caller label or target's previous native ID.
	var changed_target := _reference.prepare_ordered_target(changed_polygon,PLANE,&"AdapterSharedTargetSource",true)
	var changed_reference := _reference.evaluate_segments(segments,changed_target,PLANE,BASE_CONFIG)
	var changed: Dictionary = adapter.evaluate_segments(segments,changed_target,PLANE,BASE_CONFIG)
	var changed_stats: Dictionary = adapter.cache_statistics()
	_check(_difference(changed_reference,changed,"adapter.changed").is_empty()
		and not _difference(reference,changed_reference,"different_geometry").is_empty(),
		"changed target geometry produces its own correct result despite identical source labels")
	_check(changed_stats.native_kernel.segment_calls==6 and changed_stats.native_kernel.target_preparations==2
		and changed_stats.target_count==2 and changed_stats.entry_count==6,"distinct target records never reuse the previous native geometry")
	_adapter_observations.append({"stage":"warm_and_distinct_target","statistics":changed_stats})
	var third_polygon := PackedVector2Array()
	for point: Vector2 in square: third_polygon.append(point+Vector2(0,0.004))
	var third_target := _reference.prepare_ordered_target(third_polygon,PLANE,&"AdapterSharedTargetSource",true)
	var new_segment: Dictionary = segments[0].duplicate(true)
	new_segment.source_id=&"InvalidOuterFirstValidSegment"
	var invalid_segment: Dictionary = segments[1].duplicate(true)
	invalid_segment.b=invalid_segment.a
	var invalid: Dictionary = adapter.evaluate_segments([new_segment,invalid_segment],third_target,PLANE,BASE_CONFIG)
	var invalid_stats: Dictionary = adapter.cache_statistics()
	_check(not invalid.get("valid",false) and invalid_stats.invalid_outer_calls==1
		and invalid_stats.discarded_pending_entries==1 and invalid_stats.pending_entry_count==0
		and not invalid_stats.pending_new_target and invalid_stats.entry_count==6 and invalid_stats.target_count==2,
		"invalid partial batch discards its pending segment and target without disturbing retained records")
	_check(invalid_stats.native_kernel.segment_calls==7 and invalid_stats.native_kernel.target_preparations==3
		and invalid_stats.native_kernel.fallback_calls==0 and int(adapter.get("_native_target_handle"))==0,
		"partial invalid batch performs only its first valid native segment and still retires its target")
	var retry: Dictionary = adapter.evaluate_segments([new_segment],third_target,PLANE,BASE_CONFIG)
	var retry_reference := _reference.evaluate_segments([new_segment],third_target,PLANE,BASE_CONFIG)
	var retry_stats: Dictionary = adapter.cache_statistics()
	_check(_difference(retry_reference,retry,"adapter.retry").is_empty() and retry_stats.native_kernel.segment_calls==8
		and retry_stats.native_kernel.target_preparations==4 and retry_stats.target_count==3 and retry_stats.entry_count==7,
		"valid retry recomputes discarded work and commits the correct new target")
	_adapter_observations.append({"stage":"invalid_batch_then_valid_retry","statistics":retry_stats})
	_check(adapter.configure_native_kernel(false),"adapter switches to GDScript backend between batches")
	var switched: Dictionary = adapter.cache_statistics()
	_check(switched.contact_backend=="gdscript" and switched.entry_count==0 and switched.target_count==0
		and switched.native_kernel.segment_calls==0,"backend switch clears prior cache and native statistics")
	var old_retired: Dictionary = native_object.call("evaluate_segment",segments[0],4,0.00001,0.000000001,64,false,true)
	_check(not old_retired.get("valid",false),"released native backend retains no usable final batch target")
	_check(adapter.begin_acquisition(&"ReferenceAdapterVerificationAcquisition"),"reference backend starts fresh acquisition")
	var reference_adapter: Dictionary = adapter.evaluate_segments(segments,target,PLANE,BASE_CONFIG)
	_check(_difference(reference,reference_adapter,"adapter.gdscript").is_empty()
		and adapter.cache_statistics().native_kernel.segment_calls==0,"GDScript backend retains complete result parity without native calls")
	_check(adapter.configure_native_kernel(true),"adapter can return to compiled backend")
	_check(adapter.cache_statistics().entry_count==0 and adapter.cache_statistics().target_count==0,
		"returning to compiled backend also clears reference cache")
	_check(adapter.begin_acquisition(&"SecondNativeAdapterVerificationAcquisition"),"second native acquisition starts cleanly")
	var second_native: Dictionary = adapter.evaluate_segments(segments,target,PLANE,BASE_CONFIG)
	_check(_difference(reference,second_native,"adapter.second_native").is_empty()
		and adapter.cache_statistics().native_kernel.segment_calls==3
		and adapter.cache_statistics().native_kernel.fallback_calls==0,"reenabled native backend computes the same three segments without fallback")
	var current_native: RefCounted = adapter.get("_kernel")
	_check(adapter.clear_cache(),"clearing acquisition succeeds between batches")
	var cleared: Dictionary = adapter.cache_statistics()
	_check(cleared.entry_count==0 and cleared.target_count==0 and cleared.pending_entry_count==0
		and cleared.acquisition_id==&"" and cleared.native_kernel.segment_calls==0
		and int(adapter.get("_native_target_handle"))==0 and int(adapter.get("_native_query_depth"))==0,
		"acquisition clear releases cache, pending work, identity and active native handle")
	var clear_retired: Dictionary = current_native.call("evaluate_segment",segments[0],1,0.00001,0.000000001,64,false,true)
	_check(not clear_retired.get("valid",false),"cleared acquisition cannot reuse its previous native target")
	_check(var_to_bytes([target,segments])==before_inputs,"adapter scenarios leave original source geometry immutable")
	_adapter_observations.append({"stage":"cleared","statistics":cleared})
	print("NATIVE_OVERLAP_CACHE_ADAPTER complete")


func _difference(before: Variant,after: Variant,path: String) -> String:
	# StringName/String and typed/untyped arrays carry the same public values.
	# Counts, decisions, source IDs, edge ordering, flags and key sets are exact.
	if (before is String or before is StringName) and (after is String or after is StringName):
		return "" if String(before)==String(after) else path+": identifier differs"
	if (before is float or before is int) and (after is float or after is int):
		if before is int: return "" if before==after else path+": integer differs ("+str(before)+" vs "+str(after)+")"
		if not is_finite(float(before)) or not is_finite(float(after)):
			return "" if before==after else path+": nonfinite values differ"
		return "" if absf(float(before)-float(after))<=STRICT_SCALAR_ERROR else path+": numeric error "+str(absf(float(before)-float(after)))
	if before is Vector2 and after is Vector2:
		return "" if before.distance_to(after)<=STRICT_VECTOR_ERROR else path+": vector error "+str(before.distance_to(after))
	if typeof(before)!=typeof(after): return path+": value types differ"
	if before is Dictionary:
		if before.size()!=after.size(): return path+": dictionary key count differs"
		for key: Variant in before:
			if not after.has(key): return path+": missing key "+str(key)
			var found := _difference(before[key],after[key],path+"."+str(key))
			if not found.is_empty(): return found
		return ""
	if before is Array:
		if before.size()!=after.size(): return path+": array size differs"
		for index: int in before.size():
			var found := _difference(before[index],after[index],path+"["+str(index)+"]")
			if not found.is_empty(): return found
		return ""
	return "" if before==after else path+": value differs"


func _position_depth_error(before: Variant,after: Variant,field: String="") -> float:
	if before is Dictionary and after is Dictionary:
		var maximum := 0.0
		for key: Variant in before:
			if after.has(key): maximum=maxf(maximum,_position_depth_error(before[key],after[key],String(key)))
		return maximum
	if before is Vector2 and after is Vector2 and field.ends_with("_m"):
		return before.distance_to(after)
	if (before is float or before is int) and (after is float or after is int) and field.ends_with("_m"):
		return absf(float(before)-float(after))
	return 0.0


func _check(condition: bool,label: String) -> bool:
	_checks.append({"passed":condition,"label":label})
	if not condition:
		_failures+=1
		push_error(label)
	return condition


func _finish() -> void:
	var path := "C:/WORKSPACE/test_artifacts/native_overlap_kernel_"+Time.get_datetime_string_from_system().replace(":","-")+".json"
	var report := {"schema":"native_overlap_kernel_verification_v1","passed":_failures==0,"checks":_checks,"fixtures":_fixtures,"benchmarks":_benchmarks,
		"adapter_observations":_adapter_observations,
		"reference_script_sha256":FileAccess.get_sha256("res://runtime/player/grip/planar_skin_overlap_budget.gd"),
		"capture_path":CAPTURE_PATH,"capture_sha256":CAPTURE_HASH,"compared_segments":_compared_segments,
		"reference_evaluation_usec":_reference_usec,"native_evaluation_usec":_native_usec,
		"evaluation_speedup":float(_reference_usec)/float(maxi(1,_native_usec)),"total_ms":float(Time.get_ticks_usec()-_started)/1000.0,
		"strict_scalar_error":STRICT_SCALAR_ERROR,"strict_vector_error":STRICT_VECTOR_ERROR,
		"user_geometry_accuracy_m":USER_ACCURACY_M,"maximum_position_depth_error_m":_maximum_position_depth_error_m,
		"accuracy_scope":"Native/reference position and depth differences at identical settings; not a claim that every budget-limited bound converges to tolerance.",
		"timing_scope":"GDScript evaluate_segments versus native per-segment calls including marshaling; excludes shared target preparation. Three-repeat captured benchmarks are local kernels, not full-grip duration.",
		"validation_scope":"Outer GDScript validation retained; complete _segment outputs compared including cap status, witnesses, depth bounds, ordered ties and work counts.",
		"captured_scope":"Current selected Middle and one fixed-weapon follower for each hand; all captured skin edges against physical, digit and palm targets, broader grouping than live.",
		"production_pose_written":false,"actual_3d_grip_verified":false}
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		_check(false,"write native kernel verification report")
	else:
		file.store_string(JSON.stringify(report,"\t")); file.close()
	print("NATIVE_OVERLAP_KERNEL ","PASS" if _failures==0 else "FAIL"," checks=",_checks.size()," failures=",_failures,
		" compared_segments=",_compared_segments," reference_ms=",float(_reference_usec)/1000.0," native_ms=",float(_native_usec)/1000.0," report=",path)
	quit(0 if _failures==0 else 1)
