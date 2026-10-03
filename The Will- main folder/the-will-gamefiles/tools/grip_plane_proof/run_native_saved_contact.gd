extends SceneTree

## Complete saved-contact replacement proof. Frozen supplied skin/target slices;
## no new pose search, live application, or relaxation of material acceptance.
const Query = preload("res://runtime/player/grip/saved_wrapper_skin_contact.gd")
const CAPTURE := "C:/WORKSPACE/test_artifacts/contact_driven_preparation_2026-10-01T02-15-26.json"
const CAPTURE_HASH := "a76ad9ab49e676db966b2ef66e84107a12b10fa6e6bae9b5169017acb228193e"
const PLANE := &"NativeSavedContactVerificationPlaneOrigin"
const CONFIG := {"max_evaluations_per_segment":64,"depth_bound_tolerance_m":0.00001,"refine_depth_after_cap":false}
const SCALAR_ERROR := 0.000000000001
const VECTOR_ERROR := 0.00000001
const OBSERVER_FIELDS := [&"cache_hit",&"preparation_ms",&"material_measurement_ms",&"guide_measurement_ms",
	&"witness_normalization_ms",&"evaluation_ms"]
var _reference := Query.new()
var _native: Object
var _checks: Array = []
var _cases: Array = []
var _benchmarks: Array = []
var _benchmark_inputs: Array = []
var _failures := 0
var _started := 0
var _captured_count := 0
var _compared_segments := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_started=Time.get_ticks_usec()
	if not _check(ClassDB.class_exists(&"GripSavedContactKernel"),"compiled whole saved-contact kernel is registered"):
		_finish(); return
	_native=ClassDB.instantiate(&"GripSavedContactKernel")
	if not _check(_native!=null and _reference.configure_evaluation(false,CONFIG.depth_bound_tolerance_m),"explicit GDScript reference and native instance are available"):
		_finish(); return
	if not _check(FileAccess.get_sha256(CAPTURE)==CAPTURE_HASH,"frozen real geometry capture SHA256"):
		_finish(); return
	_synthetic()
	_invalid()
	_detachment_and_epochs()
	_bounded_cache_retention()
	_captured()
	_check(_captured_count==6,"both hands: initial Middle, final Middle and final Thumb complete skin batches")
	_benchmark()
	_integrated_adapter()
	_check(FileAccess.get_sha256(CAPTURE)==CAPTURE_HASH,"capture remains unchanged")
	_finish()


func _epoch(label: String) -> void:
	_check(_reference.reset(),label+": reference reset")
	_check(bool(_native.call("reset")),label+": native reset")
	_check(_reference.begin_acquisition(StringName(label)),label+": reference acquisition")
	_check(bool(_native.call("begin_acquisition",StringName(label))),label+": native acquisition")


func _section(polygon: PackedVector2Array, origin: StringName=PLANE) -> Dictionary:
	var result := {"origin_id":origin,"center":Vector2.ZERO}
	for kind: StringName in [&"handle",&"digit_target",&"palm_target"]:
		var scale_factor := 1.0 if kind==&"handle" else (0.85 if kind==&"digit_target" else 0.7)
		var points:=PackedVector2Array()
		for point: Vector2 in polygon: points.append(point*scale_factor)
		result[kind]={"valid":true,"complete":true,"origin_id":origin,"source_id":StringName("SavedFixture/"+String(kind)),"polygon":points}
	return result


func _square() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-0.01,-0.01),Vector2(0.01,-0.01),Vector2(0.01,0.01),Vector2(-0.01,0.01)])


func _skin(a: Vector2,b: Vector2,cap: float,label: String,assigned: bool=true,palm: bool=false) -> Dictionary:
	return {"a":a,"b":b,"origin_id":PLANE,"source_id":StringName(label),"max_inward_depth_m":cap,
		"allowance_unassigned":not assigned,"palm_owned":palm,"section_owner":-1 if palm else 0,
		"metadata":{"nested":[1,2,3],"preserved":true}}


func _segments() -> Array:
	return [_skin(Vector2(-0.02,0.02),Vector2(0.02,0.02),0.0005,"separated"),
		_skin(Vector2(-0.02,0.02),Vector2(0.02,0.02),0.005,"unassigned_exterior",false),
		_skin(Vector2(-0.02,0),Vector2(0.02,0),0.0005,"crossing"),
		_skin(Vector2(-0.002,0.0097),Vector2(0.002,0.0097),0.0005,"within_0.30mm"),
		_skin(Vector2(-0.002,0.0093),Vector2(0.002,0.0093),0.0005,"exceeds_0.70mm"),
		_skin(Vector2(-0.002,0.0094998),Vector2(0.002,0.0094998),0.0005,"near_cap_above"),
		_skin(Vector2(-0.002,0.0095002),Vector2(0.002,0.0095002),0.0005,"near_cap_below"),
		_skin(Vector2(-0.002,0.0097),Vector2(0.002,0.0097),0.005,"unassigned_inside",false),
		_skin(Vector2(-0.002,0.0097),Vector2(0.002,0.0097),0.0,"assigned_zero_inside"),
		_skin(Vector2(-0.02,-0.01),Vector2(0.02,-0.01),0.005,"unassigned_touching",false),
		_skin(Vector2(-0.02,-0.02),Vector2(-0.01,-0.01),0.0005,"corner_touching"),
		_skin(Vector2(-0.0000001,0),Vector2(0.0000001,0),0.02,"center_ties"),
		_skin(Vector2(-0.002,0.0075),Vector2(0.002,0.0075),0.0025,"palm_2.5mm",true,true)]


func _synthetic() -> void:
	var square:=_square()
	var result:=_compare("synthetic/square_caps_and_mixed_ownership",_section(square),_segments(),PLANE)
	if result.get("valid",false):
		var by_name: Dictionary={}
		for record: Dictionary in result.segments: by_name[String(record.segment.source_id)]=record
		_check(by_name["within_0.30mm"].material_cap_status==&"within","analytic shallow penetration stays within cap")
		_check(by_name["exceeds_0.70mm"].material_cap_status==&"exceeds","analytic excessive penetration is rejected")
		_check(by_name.crossing.depth_lower_m>0.0099 and not by_name.crossing.material_constraint_safe,"crossing interior cannot be falsely accepted from exterior endpoints")
		_check(by_name.unassigned_exterior.material_strictly_exterior and by_name.unassigned_exterior.material_constraint_safe
			and by_name.unassigned_exterior.max_inward_depth_m==0.0,"unassigned exterior uses strict exterior proof and zero allowance")
		_check(not by_name.unassigned_inside.material_constraint_safe and not by_name.unassigned_touching.material_constraint_safe,
			"unassigned supplied numeric allowance does not permit material entry or touching")
		_check(by_name["palm_2.5mm"].guide_kind==&"palm_target" and by_name.separated.guide_kind==&"digit_target","palm and digit attraction targets remain separate")
		_check(not result.material_constraint_safe and not result.grip_accepted and not result.actual_3d_grip_verified,"known failed contact batch never claims an accepted grip")
	var reversed:=square.duplicate(); reversed.reverse()
	_compare("synthetic/clockwise",_section(reversed),_segments(),PLANE)
	var closed:=square.duplicate(); closed.append(closed[0])
	_compare("synthetic/explicit_closed",_section(closed),_segments(),PLANE)
	var short_edges:=PackedVector2Array([Vector2(-0.01,-0.01),Vector2(0,-0.01),Vector2(0.0000001,-0.01),Vector2(0.01,-0.01),Vector2(0.01,0.01),Vector2(-0.01,0.01)])
	_compare("synthetic/ordered_sub_weld_edge",_section(short_edges),_segments(),PLANE)
	var concave:=PackedVector2Array([Vector2(-0.012,-0.012),Vector2(-0.002,-0.012),Vector2(-0.002,-0.004),Vector2(0.012,-0.004),
		Vector2(0.012,0.004),Vector2(-0.002,0.004),Vector2(-0.002,0.012),Vector2(-0.012,0.012)])
	_compare("synthetic/concave_recess",_section(concave),_segments(),PLANE)
	var many:=PackedVector2Array()
	for index: int in 128: many.append(Vector2.from_angle(TAU*float(index)/128.0)*(0.012 if index%2==0 else 0.009))
	_compare("synthetic/128_edge_ordered_tree",_section(many),_segments(),PLANE)
	_compare("synthetic/20_micron_thin",_section(PackedVector2Array([Vector2(-0.01,-0.00001),Vector2(0.01,-0.00001),Vector2(0.01,0.00001),Vector2(-0.01,0.00001)])),_segments(),PLANE)
	var translated:=_section(square)
	var shifted_skin:=_segments()
	var shift:=Vector2(-0.137,-0.213)
	translated.center=shift
	for kind: StringName in Query.KINDS:
		for index: int in translated[kind].polygon.size(): translated[kind].polygon[index]+=shift
	for edge: Dictionary in shifted_skin: edge.a+=shift; edge.b+=shift
	_compare("synthetic/translated",translated,shifted_skin,PLANE)
	_signed_zero_bounds()


func _signed_zero_bounds() -> void:
	# A parsed -0.0 literal may lose its sign during constant folding. Decode
	# the IEEE-754 bit pattern at runtime so this is an actual signed-zero case.
	var negative_zero: float=PackedByteArray([0,0,0,128]).decode_float(0)
	_check(var_to_bytes(Vector2(0.0,0.0))!=var_to_bytes(Vector2(negative_zero,0.0)),"signed-zero fixture retains distinct coordinate bits")
	# Alternating signs on the zero coordinate of collinear boundary vertices
	# exercise MIN/MAX's equal-value tie rule, both without and with an edge tree.
	for subdivisions: int in [1,16]:
		for direction: float in [1.0,-1.0]:
			var points:=PackedVector2Array()
			var extent:=0.02*direction
			for side: int in 4:
				for index: int in subdivisions:
					var along:=extent*float(index)/float(subdivisions)
					var signed_zero: float=negative_zero if index%2==0 else 0.0
					match side:
						0: points.append(Vector2(along,signed_zero))
						1: points.append(Vector2(extent,along))
						2: points.append(Vector2(extent-along,extent))
						3: points.append(Vector2(signed_zero,extent-along))
			var label: String="synthetic/signed_zero_"+str(points.size())+"_edges_"+("minimum" if direction>0 else "maximum")
			var section:=_section(points)
			var result:=_compare(label,section,_segments(),PLANE)
			_check(result.get("valid",false),label+": valid mixed-zero geometry remains measurable")
			var expected: Dictionary=_reference.prepare(section)
			var actual: Dictionary=_native.call("prepare",section)
			if expected.get("valid",false) and actual.get("valid",false):
				for kind: StringName in Query.KINDS:
					_check(var_to_bytes(expected[kind].edge_bounds)==var_to_bytes(actual[kind].edge_bounds),label+": "+String(kind)+" scalar bounds preserve zero tie bits")
					_check(not expected[kind].edge_tree.is_empty() if points.size()>=64 else expected[kind].edge_tree.is_empty(),label+": expected tree branch "+String(kind))


func _compare(label: String,section: Dictionary,segments: Array,origin: StringName,benchmark: bool=false) -> Dictionary:
	_epoch(label)
	var input_bytes:=var_to_bytes([section,segments])
	var expected: Dictionary=_reference.prepare(section)
	var actual: Dictionary=_native.call("prepare",section)
	var preparation_difference:=_difference(expected,actual,"prepared")
	_check(preparation_difference.is_empty(),label+": complete prepared packet parity "+preparation_difference)
	var result: Dictionary={}
	var evaluation_difference: String="not_evaluated_invalid_preparation"
	if expected.get("valid",false) and actual.get("valid",false):
		result=_reference.evaluate(expected,segments,origin)
		var native_result: Dictionary=_native.call("evaluate",actual,segments,origin,CONFIG)
		evaluation_difference=_difference(result,native_result,"evaluated")
		_check(evaluation_difference.is_empty(),label+": complete evaluated packet parity "+evaluation_difference)
		_compared_segments+=segments.size()
		if result.get("valid",false):
			_check(not native_result.grip_accepted and not native_result.actual_3d_grip_verified and not native_result.production_pose_written,
				label+": contact observation never claims grip acceptance or writes a pose")
		if benchmark and result.get("valid",false): _benchmark_inputs.append({"name":label,"section":section.duplicate(true),"segments":segments.duplicate(true),"origin":origin})
	_check(var_to_bytes([section,segments])==input_bytes,label+": supplied geometry and metadata unchanged")
	_cases.append({"name":label,"prepared_valid":expected.get("valid",false),"result_valid":result.get("valid",false),
		"preparation_difference":preparation_difference,"evaluation_difference":evaluation_difference,"skin_segments":segments.size(),
		"material_constraint_safe":result.get("material_constraint_safe",false),"guide_constraint_safe":result.get("guide_constraint_safe",false),
		"material_depth_evaluations":result.get("material_depth_evaluations",0),"guide_depth_evaluations":result.get("guide_depth_evaluations",0)})
	return result


func _invalid() -> void:
	var section:=_section(_square())
	var segments:=_segments()
	for field: String in ["origin_id","center"]:
		var missing:=section.duplicate(true); missing.erase(field)
		_compare("invalid/missing_"+field,missing,segments,PLANE)
	for origin: StringName in [&"",&"RL_BoneRoot"]:
		_compare("invalid/section_origin_"+String(origin),_section(_square(),origin),segments,origin)
	for kind: StringName in Query.KINDS:
		for field: String in ["valid","complete","origin_id","source_id","polygon"]:
			var missing:=section.duplicate(true); missing[kind].erase(field)
			_compare("invalid/"+String(kind)+"_missing_"+field,missing,segments,PLANE)
	var nonfinite:=section.duplicate(true); nonfinite.center=Vector2(NAN,0)
	_compare("invalid/nonfinite_center",nonfinite,segments,PLANE)
	for points: PackedVector2Array in [PackedVector2Array(),PackedVector2Array([Vector2.ZERO,Vector2.ONE]),
		PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2(1,0),Vector2(0,1)]),
		PackedVector2Array([Vector2.ZERO,Vector2(1,1),Vector2(0,1),Vector2(1,0)])]:
		_compare("invalid/ordered_polygon_"+str(points.size())+"_"+str(_cases.size()),_section(points),segments,PLANE)
	_compare("invalid/empty_skin",section,[],PLANE)
	_compare("invalid/non_dictionary_skin",section,[23],PLANE)
	_compare("invalid/outer_origin",section,segments,&"AnotherPlaneOrigin")
	for field: String in ["source_id","origin_id","a","b","max_inward_depth_m"]:
		var missing: Dictionary=segments[0].duplicate(true); missing.erase(field)
		_compare("invalid/skin_missing_"+field,section,[segments[0],missing],PLANE)
	for cap: float in [-0.001,INF,NAN]:
		var edge: Dictionary=segments[0].duplicate(true); edge.max_inward_depth_m=cap
		_compare("invalid/skin_cap_"+str(cap),section,[edge],PLANE)
	var zero: Dictionary=segments[0].duplicate(true); zero.b=zero.a
	_compare("invalid/zero_length_skin",section,[zero],PLANE)


func _detachment_and_epochs() -> void:
	_epoch("detachment")
	var section:=_section(_square())
	var edges:=_segments()
	var original: Dictionary=_reference.prepare(section)
	var detached: Dictionary=_native.call("prepare",section)
	detached.handle.edges[0][0]=Vector2(55,66)
	detached.digit_target.polygon[0]=Vector2(55,66)
	var fresh: Dictionary=_native.call("prepare",section)
	_check(_difference(original,fresh,"detached_prepare").is_empty(),"mutation of returned prepared geometry cannot poison the preparation cache")
	var prepared_statistics: Dictionary=_native.call("statistics")
	_check(fresh.get("cache_hit",false) and prepared_statistics.get("prepared_section_cache_hits",0)>0,
		"identical prepare is an actual prepared-section cache hit")
	var expected: Dictionary=_reference.evaluate(original,edges,PLANE)
	var output: Dictionary=_native.call("evaluate",fresh,edges,PLANE,CONFIG)
	var first_statistics: Dictionary=_native.call("statistics")
	if output.get("valid",false):
		output.segments[0].segment.metadata.nested[0]=500
		output.segments[0].witness.skin_point_m=Vector2(55,66)
	var repeated: Dictionary=_native.call("evaluate",fresh,edges,PLANE,CONFIG)
	_check(_difference(expected,repeated,"detached_evaluation").is_empty(),"mutating returned nested records cannot poison input or later measurements")
	var repeated_statistics: Dictionary=_native.call("statistics")
	_check(repeated_statistics.native_section_cache_hits>first_statistics.native_section_cache_hits
		and repeated_statistics.native_kernel.target_preparations==first_statistics.native_kernel.target_preparations,
		"identical evaluate reuses native targets with no new target preparation")
	# A prepared packet is a value, not an identity token. Replace one target
	# with another valid prepared geometry while preserving the outer packet.
	var other:=_section(_square())
	for kind: StringName in Query.KINDS:
		for index: int in other[kind].polygon.size(): other[kind].polygon[index]+=Vector2(0.1,0)
	var replacement: Dictionary=_reference.prepare(other)
	var changed:=fresh.duplicate(true); changed.handle=replacement.handle.duplicate(true)
	_check(_difference(_reference.evaluate(changed,edges,PLANE),_native.call("evaluate",changed,edges,PLANE,CONFIG),"changed_prepared_target").is_empty(),
		"changed prepared target geometry cannot reuse a stale native target")
	var changed_statistics: Dictionary=_native.call("statistics")
	_check(changed_statistics.native_section_cache_misses>repeated_statistics.native_section_cache_misses,
		"changed prepared geometry creates a native-section miss")
	var noncanonical:=fresh.duplicate(true)
	noncanonical.handle.edges[0][0]+=Vector2(0.001,0)
	var rejected_target: Dictionary=_native.call("evaluate",noncanonical,edges,PLANE,CONFIG)
	_check(not rejected_target.get("valid",false),"inconsistent mutated target edges/bounds are rejected instead of reusing an old native handle")
	var bad: Dictionary=edges[0].duplicate(true); bad.origin_id=&"OtherPlane"
	var rejected: Dictionary=_native.call("evaluate",fresh,[edges[0],bad],PLANE,CONFIG)
	_check(not rejected.get("valid",false),"partially evaluated invalid batch remains rejected")
	_check(_difference(expected,_native.call("evaluate",fresh,edges,PLANE,CONFIG),"after_invalid").is_empty(),"invalid partial batch cannot contaminate a subsequent valid measurement")
	_check(bool(_native.call("reset")),"explicit native reset succeeds")
	var reset_statistics: Dictionary=_native.call("statistics")
	_check(reset_statistics.prepared_section_count==0 and reset_statistics.native_section_count==0 and reset_statistics.native_target_count==0,
		"reset releases both section stores and all retained native targets")
	_check(not bool(_native.call("begin_acquisition",&"")),"empty native acquisition identity is rejected")
	_check(bool(_native.call("begin_acquisition",&"AfterReset")),"new native acquisition starts after reset")
	_check(_difference(expected,_native.call("evaluate",original,edges,PLANE,CONFIG),"after_reset").is_empty(),"valid supplied prepared value evaluates after reset without stale handles")


func _captured() -> void:
	var document: Variant=JSON.parse_string(FileAccess.get_file_as_string(CAPTURE))
	if not _check(document is Dictionary and document.get("cases",[]).size()==2,"two frozen capture hands decoded"): return
	for hand: Dictionary in document.cases:
		_check(not hand.minimum_hand_contact_count_met and not hand.grip_accepted,"frozen "+String(hand.slot)+": incomplete three-contact result is not relabeled a successful grip")
		var selected: Array=[{"label":"selected_middle","digit":hand.selected.digits[0]}]
		for stage: Dictionary in hand.stages:
			if stage.label=="middle_initial_unbound" or stage.label=="follower_response_fixed_weapon":
				selected.append({"label":stage.label,"digit":stage.digits[0]})
		for item: Dictionary in selected:
			var digit: Dictionary=item.digit
			var origin:=StringName(digit.origin_id)
			var section: Dictionary={"origin_id":origin,"center":_vector2(digit.slice_center_m)}
			for entry: Array in [[&"handle","handle_polygon"],[&"digit_target","wrapper_polygon"],[&"palm_target","palm_polygon"]]:
				section[entry[0]]={"valid":true,"complete":true,"origin_id":origin,"source_id":StringName("FrozenReport/"+String(hand.slot)+"/"+String(digit.digit)+"/"+String(entry[0])),
					"polygon":_polygon(digit[entry[1]])}
			var segments: Array=[]
			for raw: Dictionary in digit.skin_segments:
				var edge:=raw.duplicate(true)
				edge.a=_vector2(raw.a); edge.b=_vector2(raw.b)
				edge.origin_id=StringName(raw.origin_id); edge.source_id=StringName(raw.source_id)
				for field: String in ["a_selected_weights","b_selected_weights"]:
					if edge.has(field): edge[field]=Vector3(float(raw[field][0]),float(raw[field][1]),float(raw[field][2]))
				segments.append(edge)
			var result:=_compare("captured/"+String(hand.slot)+"/"+String(item.label),section,segments,origin,item.label!="middle_initial_unbound")
			_check(result.get("valid",false),"captured "+String(hand.slot)+"/"+String(item.label)+": full skin batch remains measurable")
			_captured_count+=1


func _bounded_cache_retention() -> void:
	_epoch("bounded_cache_retention")
	var initial: Dictionary=_native.call("statistics")
	var maximum: int=int(initial.maximum_native_sections)
	var all_valid:=true
	var all_bounded:=true
	var section:=_section(_square())
	var first: Dictionary={}
	var edges: Array=[_segments()[0]]
	# Mutate the same caller-owned packet between requests. One beyond the
	# published limit exercises eviction without building a new test search.
	for index: int in maximum+1:
		if index>0:
			section.center+=Vector2(0.001,0)
			for kind: StringName in Query.KINDS:
				for vertex: int in section[kind].polygon.size(): section[kind].polygon[vertex]+=Vector2(0.001,0)
		var prepared: Dictionary=_native.call("prepare",section)
		if index==0: first=prepared.duplicate(true)
		var result: Dictionary=_native.call("evaluate",prepared,edges,PLANE,CONFIG)
		var statistics: Dictionary=_native.call("statistics")
		all_valid=all_valid and result.get("valid",false) and not prepared.get("cache_hit",true)
		all_bounded=all_bounded and statistics.prepared_section_count<=statistics.maximum_prepared_sections \
			and statistics.native_section_count<=statistics.maximum_native_sections and statistics.native_target_count<=statistics.maximum_native_targets
	var filled: Dictionary=_native.call("statistics")
	_check(all_valid,"mutating supplied polygon data causes a miss on every distinct valid geometry")
	_check(all_bounded and filled.native_section_evictions>0,"section and target counts remain bounded through eviction")
	_check(_difference(_reference.evaluate(first,edges,PLANE),_native.call("evaluate",first,edges,PLANE,CONFIG),"evicted_packet").is_empty(),
		"evicted prepared value can be evaluated again without stale native handles")
	_check(bool(_native.call("reset")),"bounded cache test reset succeeds")
	var cleared: Dictionary=_native.call("statistics")
	_check(cleared.prepared_section_count==0 and cleared.native_section_count==0 and cleared.native_target_count==0,"reset releases stores after actual eviction")


func _benchmark() -> void:
	for fixture: Dictionary in _benchmark_inputs:
		var timings: Array=[]
		for repeat_index: int in 3:
			for backend: String in (["gdscript","cpp"] if repeat_index%2==0 else ["cpp","gdscript"]):
				var evaluator: Object=_reference if backend=="gdscript" else _native
				evaluator.call("reset")
				evaluator.call("begin_acquisition",StringName("Benchmark/"+str(repeat_index)))
				var started:=Time.get_ticks_usec()
				var target: Dictionary=evaluator.call("prepare",fixture.section)
				var prepare_us:=Time.get_ticks_usec()-started
				started=Time.get_ticks_usec()
				var result: Dictionary=_reference.evaluate(target,fixture.segments,fixture.origin) if backend=="gdscript" else _native.call("evaluate",target,fixture.segments,fixture.origin,CONFIG)
				var evaluate_us:=Time.get_ticks_usec()-started
				_check(result.get("valid",false),fixture.name+": benchmark cold "+backend+" "+str(repeat_index))
				var cold_statistics: Dictionary=_native.call("statistics") if backend=="cpp" else {}
				started=Time.get_ticks_usec()
				var repeat_target: Dictionary=evaluator.call("prepare",fixture.section)
				var repeat_result: Dictionary=_reference.evaluate(repeat_target,fixture.segments,fixture.origin) if backend=="gdscript" else _native.call("evaluate",repeat_target,fixture.segments,fixture.origin,CONFIG)
				var repeat_us:=Time.get_ticks_usec()-started
				_check(_difference(result,repeat_result,"benchmark_repeat").is_empty(),fixture.name+": exact repeated output "+backend+" "+str(repeat_index))
				if backend=="cpp":
					var warm_statistics: Dictionary=_native.call("statistics")
					_check(repeat_target.get("cache_hit",false) and warm_statistics.prepared_section_cache_hits>cold_statistics.prepared_section_cache_hits
						and warm_statistics.native_section_cache_hits>cold_statistics.native_section_cache_hits
						and warm_statistics.native_kernel.target_preparations==cold_statistics.native_kernel.target_preparations,
						fixture.name+": real exact repeat hits both native caches without rebuilding targets "+str(repeat_index))
				timings.append({"backend":backend,"repeat":repeat_index,"cold_prepare_us":prepare_us,"cold_evaluate_us":evaluate_us,
					"cold_total_us":prepare_us+evaluate_us,"prepared_and_evaluated_repeat_us":repeat_us,
					"statistics":_reference.cache_statistics() if backend=="gdscript" else _native.call("statistics")})
		_benchmarks.append({"name":fixture.name,"skin_segments":fixture.segments.size(),"timings":timings})
	_check(_benchmark_inputs.size()==4,"four real final Middle/Thumb batches benchmarked on both backends three times")


func _integrated_adapter() -> void:
	var adapter:=Query.new()
	if not _check(adapter.configure_evaluation(true,CONFIG.depth_bound_tolerance_m),"integrated adapter selects native contact"): return
	if not _check(adapter.has_method("configure_native_batch"),"integrated adapter exposes complete-kernel selection"): return
	if not _check(bool(adapter.call("configure_native_batch",true)),"integrated adapter enables complete native kernel"): return
	_check(adapter.begin_acquisition(&"CompleteNativeAdapter"),"integrated native acquisition starts")
	_check(not adapter.configure_evaluation(false,CONFIG.depth_bound_tolerance_m) and not adapter.configure_native_batch(false),
		"integrated acquisition cannot change backend while active")
	var statistics: Dictionary=adapter.cache_statistics()
	_check(statistics.get("native_batch_enabled",false) and statistics.get("contact_backend","")=="cpp"
		and statistics.get("backend_selection_fallbacks",-1)==0,"integrated adapter uses the complete native backend without fallback")
	var section:=_section(_square())
	var edges:=_segments()
	var prepared: Dictionary=adapter.prepare(section)
	var expected_prepared: Dictionary=_reference.prepare(section)
	_check(_difference(expected_prepared,prepared,"integrated_prepare").is_empty(),"integrated prepare retains reference packet")
	var expected: Dictionary=_reference.evaluate(expected_prepared,edges,PLANE)
	var actual: Dictionary=adapter.evaluate(prepared,edges,PLANE)
	_check(_difference(expected,actual,"integrated_evaluate").is_empty(),"integrated evaluate retains complete reference packet")
	_check(adapter.reset(),"integrated native acquisition resets")
	_check(adapter.configure_evaluation(false,CONFIG.depth_bound_tolerance_m),"explicit GDScript selection disables complete native path")
	_check(adapter.begin_acquisition(&"ReferenceAgain"),"reference acquisition starts after backend switch")
	_check(_difference(expected,adapter.evaluate(adapter.prepare(section),edges,PLANE),"integrated_reference").is_empty(),"reference output survives integrated backend switch")


func _difference(before: Variant,after: Variant,path: String) -> String:
	if (before is String or before is StringName) and (after is String or after is StringName):
		return "" if String(before)==String(after) else path+": text differs"
	if (before is float or before is int) and (after is float or after is int):
		if before is int: return "" if before==after else path+": integer differs"
		if is_nan(float(before)) and is_nan(float(after)): return ""
		if not is_finite(float(before)) or not is_finite(float(after)): return "" if before==after else path+": nonfinite differs"
		return "" if absf(float(before)-float(after))<=SCALAR_ERROR else path+": scalar difference "+str(absf(float(before)-float(after)))
	if before is Vector2 and after is Vector2: return "" if before.distance_to(after)<=VECTOR_ERROR else path+": Vector2 differs"
	if before is Vector3 and after is Vector3: return "" if before.distance_to(after)<=VECTOR_ERROR else path+": Vector3 differs"
	if typeof(before)!=typeof(after): return path+": value type differs"
	if before is Dictionary:
		for key: Variant in before:
			if StringName(key) in OBSERVER_FIELDS: continue
			if not after.has(key): return path+": missing key "+str(key)
			var difference:=_difference(before[key],after[key],path+"."+str(key))
			if not difference.is_empty(): return difference
		for key: Variant in after:
			if not StringName(key) in OBSERVER_FIELDS and not before.has(key): return path+": extra key "+str(key)
		return ""
	if before is Array or before is PackedVector2Array or before is PackedVector3Array or before is PackedInt32Array or before is PackedFloat64Array:
		if before.size()!=after.size(): return path+": array size differs"
		for index: int in before.size():
			var difference:=_difference(before[index],after[index],path+"["+str(index)+"]")
			if not difference.is_empty(): return difference
		return ""
	return "" if before==after else path+": value differs"


func _vector2(values: Array) -> Vector2:
	return Vector2(float(values[0]),float(values[1]))


func _polygon(values: Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for point: Array in values: result.append(_vector2(point))
	return result


func _check(condition: bool,label: String) -> bool:
	_checks.append({"passed":condition,"label":label})
	if not condition: _failures+=1; push_error(label)
	return condition


func _finish() -> void:
	var path: String="C:/WORKSPACE/test_artifacts/native_saved_contact_"+Time.get_datetime_string_from_system().replace(":","-")+".json"
	var report: Dictionary={"schema":"native_saved_contact_verification_v1","passed":_failures==0,"checks":_checks,"failures":_failures,
		"cases":_cases,"benchmarks":_benchmarks,"duration_ms":float(Time.get_ticks_usec()-_started)/1000.0,
		"capture":CAPTURE,"capture_sha256":CAPTURE_HASH,"reference_sha256":FileAccess.get_sha256("res://runtime/player/grip/saved_wrapper_skin_contact.gd"),
		"config":CONFIG,"scalar_error_limit":SCALAR_ERROR,"vector_error_limit_m":VECTOR_ERROR,"captured_batches":_captured_count,
		"compared_skin_segments":_compared_segments,"excluded_packet_fields":OBSERVER_FIELDS,
		"comparison_scope":"Every non-observer preparation/evaluation field, source-order skin/target geometry, caps, safety, witnesses, normals, ties, provenance, failures, logical evaluation counts and preserved metadata.",
		"capture_scope":"Recorded planar geometry is reconstructed without pose solving. Generated fixture source IDs identify these restored report surfaces; original skin source IDs and metadata remain supplied. Initial-circle records still test their recorded saved polygons, not a substituted circle.",
		"timing_scope":"Three alternating backend repeats for four real complete batches. Cold acquisition preparation and evaluation reported separately; exact repeat timing is explicitly separate. Native call/Variant conversion included. Not a live-grip duration or acceptance test.",
		"production_pose_written":false,"actual_3d_grip_verified":false,"grip_accepted":false}
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: _check(false,"write saved-contact verification report")
	else: file.store_string(JSON.stringify(report,"\t")); file.close()
	print("NATIVE_SAVED_CONTACT ","PASS" if _failures==0 else "FAIL"," checks=",_checks.size()," failures=",_failures," report=",path)
	quit(0 if _failures==0 else 1)
