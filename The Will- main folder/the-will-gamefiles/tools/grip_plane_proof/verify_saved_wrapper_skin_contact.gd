extends SceneTree

const Query = preload("res://runtime/player/grip/saved_wrapper_skin_contact.gd")
const ORIGIN := &"SavedWrapperContactFixturePlaneOrigin"
const SOURCE := &"WeaponRootOrigin"
var _query := Query.new()
var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_usec()
	_check(_query.begin_acquisition(&"saved-wrapper-contact-verifier"),"explicit hand acquisition begins")
	var section := _section(false)
	var original := var_to_bytes(section)
	var prepared := _query.prepare(section)
	if _check(prepared.get("valid",false),"exact named saved targets prepare"):
		_check(not prepared.cache_hit,"first preparation is not cache hit")
		for kind: StringName in Query.KINDS:
			_check(prepared[kind].polygon == section[kind].polygon,str(kind)+": exact vertices preserved")
		var again := _query.prepare(section)
		_check(again.get("valid",false) and again.cache_hit,"exact repeated input reuses prepared target")
		var before := var_to_bytes(prepared)
		_measure(prepared,"outside",0.012,0.0005,false,0.0035,0.002,&"within")
		_measure(prepared,"actual material contact",0.010,0.0005,false,0.0015,0.0,&"within")
		_measure(prepared,"allowed digit flesh give",0.0097,0.0005,false,0.0012,-0.0003,&"within")
		_measure(prepared,"digit target cannot override physical cap",0.0085,0.0005,false,0.0,-0.0015,&"exceeds")
		_measure(prepared,"palm target cannot override physical cap",0.007,0.0025,true,0.0,-0.003,&"exceeds")
		_measure(prepared,"legal palm stops before target",0.0077,0.0025,true,0.0007,-0.0023,&"within")
		_measure(prepared,"same nonpalm skin uses digit target",0.0077,0.0025,false,-0.0008,-0.0023,&"within")
		var mixed: Array = [_segment(0.012,0.0005,false),_segment(0.0077,0.0025,true),_segment(0.0085,0.0005,false)]
		for index: int in mixed.size(): mixed[index].source_id="skin/"+str(index)
		var combined := _query.evaluate(prepared,mixed,ORIGIN)
		if _check(combined.get("valid",false),"mixed digit/palm query valid"):
			_check(combined.segments.size()==3 and combined.segments[1].guide_kind==&"palm_target"
				and combined.segments[2].witness.source_id=="skin/2","group queries retain original edge order and ownership")
			_check(combined.any_exceeds and not combined.material_safe,"one exceeding digit prevents combined material safety")
		var crossing := _segment(0.01,0.0005,false)
		crossing.a = Vector2(0,0.011)
		crossing.b = Vector2(0,0.007)
		var crossed := _query.evaluate(prepared,[crossing],ORIGIN)
		if _check(crossed.get("valid",false),"crossing edge evaluated"):
			var witness: Dictionary = crossed.segments[0].material_witness
			_check(witness.witness_kind == &"deepest_sampled_inside_lower_bound" and witness.signed_clearance_m < -0.0029,
				"deepest inside witness replaces crossing's zero-distance witness")
			_check(witness.skin_segment_t > 0.9 and witness.skin_segment_t <= 1.0,"deepest witness retains original segment parameter")
		var corner := _segment(0.011,0.0005,false)
		corner.a = Vector2(0.01,0.011)
		corner.b = Vector2(0.01,0.012)
		var ambiguous := _query.evaluate(prepared,[corner],ORIGIN)
		_check(ambiguous.get("valid",false) and ambiguous.segments[0].material_witness.tangent_ambiguous,
			"target corner has explicit tangent ambiguity")
		_check(ambiguous.get("valid",false) and not ambiguous.segments[0].material_witness.gradient_ambiguous
			and ambiguous.segments[0].material_witness.target_outward_normal.distance_to(Vector2.DOWN)<0.000001,
			"positive gap outside corner retains unique signed-distance gradient")
		corner.a=Vector2(0.01,0.01)
		var at_corner := _query.evaluate(prepared,[corner],ORIGIN)
		_check(at_corner.get("valid",false) and at_corner.segments[0].material_witness.gradient_ambiguous,
			"zero gap at genuine corner has ambiguous signed-distance gradient")
		var medial := _query.evaluate(prepared,[_segment(0.0,0.0005,false)],ORIGIN)
		_check(medial.get("valid",false) and medial.segments[0].material_witness.gradient_ambiguous
			and medial.segments[0].material_witness.gradient_nearest_target_points.size()>1,
			"inside medial-axis tie with distinct target points remains gradient ambiguous")
		var subdivided := _section(false)
		subdivided.handle.polygon.insert(3,Vector2(0,0.01))
		var collinear := _query.prepare(subdivided)
		var touching := _segment(0.01,0.0005,false)
		touching.a=Vector2(0,0.01);touching.b=Vector2(0,0.012)
		var flat_joint := _query.evaluate(collinear,[touching],ORIGIN)
		_check(flat_joint.get("valid",false) and not flat_joint.segments[0].material_witness.gradient_ambiguous,
			"zero gap at collinear polygon subdivision retains a unique normal")
		var zero_cap := _segment(0.012,0.0,false)
		zero_cap.allowance_unassigned = true
		var zero_result := _query.evaluate(prepared,[zero_cap],ORIGIN)
		_check(zero_result.get("valid",false) and zero_result.any_unresolved and not zero_result.material_safe,
			"zero cap retains mature numeric unresolved status without invented allowance")
		_check(zero_result.get("valid",false) and zero_result.material_constraint_safe and zero_result.guide_constraint_safe
			and zero_result.segments[0].material_strictly_exterior,"zero-cap exterior is safe through complete exterior evidence")
		zero_cap.a=Vector2(0,0.011);zero_cap.b=Vector2(0,0.007)
		var zero_crossing := _query.evaluate(prepared,[zero_cap],ORIGIN)
		_check(zero_crossing.get("valid",false) and not zero_crossing.material_constraint_safe
			and not zero_crossing.segments[0].material_strictly_exterior,"zero-cap crossing cannot use exterior exception")
		zero_cap.a=Vector2(-0.001,0.01);zero_cap.b=Vector2(0.001,0.01)
		var zero_touch := _query.evaluate(prepared,[zero_cap],ORIGIN)
		_check(zero_touch.get("valid",false) and not zero_touch.material_constraint_safe,
			"zero-cap exact-boundary contact remains unresolved without strict exterior separation")
		var unknown := _segment(0.0097,0.0005,false)
		unknown.allowance_unassigned=true
		var inherited := _query.evaluate(prepared,[unknown],ORIGIN)
		_check(inherited.get("valid",false) and inherited.segments[0].material_cap_status==&"exceeds"
			and not inherited.material_constraint_safe and inherited.segments[0].max_inward_depth_m==0.0
			and inherited.segments[0].segment.max_inward_depth_m==0.0005,
			"unassigned inherited cap is measured at zero while original source metadata is retained")
		_check(zero_result.material_measurement_ms>=0.0 and zero_result.guide_measurement_ms>=0.0
			and zero_result.witness_normalization_ms>=0.0 and prepared.preparation_ms>=0.0,"stage timing fields exposed")
		_check(not _query.evaluate(prepared,[_segment(0.012,0.0005,false)],&"WrongPlane").get("valid",false),"mixed evaluation origin rejected")
		_check(var_to_bytes(prepared)==before,"measurements leave prepared packets unchanged")
		var corrupted: Dictionary = prepared.duplicate(true)
		corrupted.digit_target.polygon[0] += Vector2(0.0002,0)
		_check(_query.prepare(section).digit_target.polygon==section.digit_target.polygon,"caller edits cannot mutate exact cache")
		var reverse := _query.prepare(_section(true))
		if _check(reverse.get("valid",false),"reverse winding prepares"):
			for y: float in [0.012,0.0097,0.0085,0.0077]:
				var skin: Array = [_segment(y,0.0005,false)]
				var first := _query.evaluate(prepared,skin,ORIGIN)
				var second := _query.evaluate(reverse,skin,ORIGIN)
				if not _check(first.get("valid",false) and second.get("valid",false),"both winding observations valid"): continue
				var a: Dictionary = first.segments[0]
				var b: Dictionary = second.segments[0]
				_check(absf(a.guide_gap_m-b.guide_gap_m)<0.00000001 and absf(a.material_gap_m-b.material_gap_m)<0.00000001,
					"winding does not change guide/material signed distance")
				_check(a.witness.target_outward_normal.distance_to(b.witness.target_outward_normal)<0.000001
					and a.material_cap_status==b.material_cap_status,"winding retains outward normal and physical acceptance")
	_check(var_to_bytes(section)==original,"source section untouched")
	var missing := section.duplicate(true)
	missing.palm_target.erase("origin_id")
	_check(not _query.prepare(missing).get("valid",false),"missing target origin rejected")
	var invalid := section.duplicate(true)
	invalid.digit_target.polygon=PackedVector2Array([Vector2(-1,-1),Vector2(1,1),Vector2(-1,1),Vector2(1,-1)])
	_check(not _query.prepare(invalid).get("valid",false),"self-crossing saved target rejected without repair")
	_verify_cache_lifecycle(section)
	var report := {"schema":"saved_wrapper_skin_contact_verification_v1","checks":_checks,"failures":_failures,
		"all_passed":_failures.is_empty(),"duration_ms":float(Time.get_ticks_usec()-started)/1000.0,
		"scope":"exact_saved_polygons_and_planar_contact_policy_not_whole_grip"}
	var path := "C:/WORKSPACE/test_artifacts/saved_wrapper_skin_contact_"+Time.get_datetime_string_from_system().replace(":","-")+".json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: _check(false,"report write")
	else: file.store_string(JSON.stringify(report,"\t")); file.close()
	print("SAVED_WRAPPER_SKIN_CONTACT_VERIFY: %s (%d checks) %s" % ["PASS" if _failures.is_empty() else "FAIL",_checks,path])
	quit(0 if _failures.is_empty() else 1)


func _verify_cache_lifecycle(section: Dictionary) -> void:
	var helper := Query.new()
	var target := helper.prepare(section)
	var segments: Array = [_segment(0.012,0.0005,false),_segment(0.0097,0.0005,false),_segment(0.0077,0.0025,true)]
	var uncached := helper.evaluate(target,segments,ORIGIN)
	_check(helper.cache_statistics().entry_count==0 and helper.cache_statistics().cache_bypasses==6,
		"without explicit acquisition all six material/guide edges use original computation")
	_check(helper.begin_acquisition(&"wrapper-cached-comparison"),"cache comparison acquisition begins")
	_check(helper.cache_statistics().prepared_section_count==0,"new hand acquisition resets prepared target storage")
	target=helper.prepare(section)
	var cold := helper.evaluate(target,segments,ORIGIN)
	var calls: int = helper.cache_statistics().actual_segment_calls
	var warm := helper.evaluate(target,segments,ORIGIN)
	_check(helper.cache_statistics().actual_segment_calls==calls and helper.cache_statistics().cache_hits==6,
		"warm wrapper query avoids all six repeated depth calculations")
	_check(var_to_bytes(_measurement_only(uncached))==var_to_bytes(_measurement_only(cold))
		and var_to_bytes(_measurement_only(cold))==var_to_bytes(_measurement_only(warm)),
		"uncached cold and warm wrapper observations match exactly excluding durations")
	_check(helper.reset() and helper.cache_statistics().entry_count==0 and helper.cache_statistics().target_count==0
		and helper.cache_statistics().prepared_section_count==0,"public reset releases both bounded cache layers")
	_check(not helper.begin_acquisition(&""),"empty acquisition identity rejected")


func _measurement_only(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	for field: String in ["material_measurement_ms","guide_measurement_ms","witness_normalization_ms","evaluation_ms"]:
		result.erase(field)
	return result


func _measure(prepared: Dictionary,label: String,y: float,cap: float,palm: bool,guide_gap: float,material_gap: float,status: StringName) -> void:
	var segment := _segment(y,cap,palm)
	var before := var_to_bytes(segment)
	var result := _query.evaluate(prepared,[segment],ORIGIN)
	if not _check(result.get("valid",false),label+": measurement valid"): return
	var item: Dictionary = result.segments[0]
	_check(absf(item.guide_gap_m-guide_gap)<0.0000001,label+": expected guide distance")
	_check(absf(item.material_gap_m-material_gap)<0.0000001,label+": independent material distance")
	_check(item.material_cap_status==status and result.material_safe==(status==&"within"),label+": physical cap decision")
	_check(item.max_inward_depth_m==cap,label+": supplied cap unchanged")
	_check(item.guide_kind==(&"palm_target" if palm else &"digit_target"),label+": correct saved target selected")
	_check(item.witness.origin_id==ORIGIN and item.witness.source_id==segment.source_id,label+": witness provenance")
	_check(var_to_bytes(segment)==before,label+": source skin unchanged")


func _section(reverse: bool) -> Dictionary:
	var result := {"origin_id":ORIGIN,"center":Vector2.ZERO}
	for kind: StringName in Query.KINDS:
		var extent := 0.010 if kind==&"handle" else (0.0085 if kind==&"digit_target" else 0.007)
		var polygon := PackedVector2Array([Vector2(-extent,-extent),Vector2(extent,-extent),Vector2(extent,extent),Vector2(-extent,extent)])
		if reverse: polygon.reverse()
		result[kind]={"valid":true,"complete":true,"origin_id":ORIGIN,"source_id":SOURCE,"polygon":polygon}
	return result


func _segment(y: float,cap: float,palm: bool) -> Dictionary:
	return {"a":Vector2(-0.001,y),"b":Vector2(0.001,y),"origin_id":ORIGIN,"source_id":"skin/0",
		"max_inward_depth_m":cap,"section_owner":-1 if palm else 1,"palm_owned":palm,"allowance_unassigned":false}


func _check(condition: bool,label: String) -> bool:
	_checks+=1
	if not condition: _failures.append(label); push_error(label)
	return condition
