extends SceneTree

const Reference = preload("res://tools/grip_plane_proof/planar_skin_overlap_budget.gd")
const Cached = preload("res://tools/grip_plane_proof/exact_cached_planar_skin_overlap_budget.gd")
const PLANE := &"ExactMemoizationTestPlane"
var _reference := Reference.new()
var _cached := Cached.new()
var _checks: int = 0
var _failures: Array[String] = []
var _cases: Array = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var target: Dictionary = _target(0.01,PLANE,&"MeasuredTestHandle")
	var segments: Array = _segments(PLANE)
	var config: Dictionary = {"depth_bound_tolerance_m":0.00001,"max_evaluations_per_segment":64,"refine_depth_after_cap":true}
	_check(_cached.begin_acquisition(&"exact-cache-verifier"),"explicit acquisition begins")
	var cold: Dictionary = _same("cold",segments,target,PLANE,config)
	var count: int = _cached.cache_statistics().actual_segment_calls
	_same("warm",segments,target,PLANE,config)
	_check(_cached.cache_statistics().actual_segment_calls==count and _cached.cache_statistics().cache_hits==segments.size(),"warm call reuses every exact edge without executing depth math")
	_check(_cached.cache_statistics().target_count==1 and _cached.cache_statistics().targets_interned==1 and _cached.cache_statistics().target_intern_hits==1,"complete target is interned once and reused across all edges and repeated calls")
	_check(_cached.cache_statistics().target_serialization_calls==2,"target serialized once per outer call, not per edge")
	_check(_cached.cache_statistics().maximum_edge_key_characters<var_to_bytes(target).hex_encode().length()+var_to_bytes([segments[0],0.00001,0.000000001,64,true,true]).hex_encode().length(),"edge key excludes the full target body")
	# Returned nested measurements must not share mutable state with storage.
	cold.segments[0].contact.distance_m=-999.0
	cold.segments[0].work_counts.intersection_tests=-99
	cold.segments[0].max_inward_depth_upper_m=999.0
	_same("returned-record-mutation",segments,target,PLANE,config)
	var reversed: Array = segments.duplicate(true); reversed.reverse()
	var reordered: Dictionary = _same("reordered",reversed,target,PLANE,config)
	for index: int in reordered.segments.size():
		_check(reordered.segments[index].segment_index==index and reordered.segments[index].source_id==reversed[index].source_id,"parent restores current call segment index")
	_check(_cached.cache_statistics().actual_segment_calls==count,"record mutation and reorder do not invalidate untouched stored results")
	_miss_change("endpoint",segments,target,config,"a",Vector2(-0.017,0.001))
	_miss_change("cap",segments,target,config,"max_inward_depth_m",0.0019)
	_miss_change("skin-source",segments,target,config,"source_id",&"ChangedSkinSource")
	_miss_change("full-segment-metadata",segments,target,config,"extra_metadata",{"ownership_revision":2})
	var changed_target: Dictionary = _target(0.011,PLANE,&"MeasuredTestHandle")
	_expect_misses("target-geometry",segments,changed_target,PLANE,config,segments.size())
	changed_target=target.duplicate(true); changed_target.source_id=&"OtherTargetSource"
	_expect_misses("target-source",segments,changed_target,PLANE,config,segments.size())
	changed_target=target.duplicate(true); changed_target["extra_prepared_metadata"]="new"
	_expect_misses("complete-target-metadata",segments,changed_target,PLANE,config,segments.size())
	var other_plane := &"OtherExactMemoizationPlane"
	_expect_misses("plane",_segments(other_plane),_target(0.01,other_plane,&"MeasuredTestHandle"),other_plane,config,segments.size())
	for entry: Array in [["depth_bound_tolerance_m",0.00002],["max_evaluations_per_segment",32],["refine_depth_after_cap",false],["use_boundary_pruning",false],["numeric_epsilon_m",0.000000002]]:
		var changed_config: Dictionary = config.duplicate(true); changed_config[entry[0]]=entry[1]
		_expect_misses("effective-config-"+str(entry[0]),segments,target,PLANE,changed_config,segments.size())
	_cached.cache_enabled=false
	count=_cached.cache_statistics().actual_segment_calls
	_same("cache-disabled",segments,target,PLANE,config)
	_check(_cached.cache_statistics().actual_segment_calls-count==segments.size(),"disabled cache executes all original segment work")
	_cached.cache_enabled=true
	_test_invalid_inputs(target,segments,config)
	_test_eviction(target,segments,config)
	_test_target_bounds(target,segments,config)
	_check(_cached.clear_cache() and _cached.cache_statistics().entry_count==0 and _cached.cache_statistics().target_count==0,"explicit cache clear removes edge and target acquisition data")
	_same("no-acquisition-bypasses-cache",segments,target,PLANE,config)
	_check(_cached.cache_statistics().entry_count==0 and _cached.cache_statistics().cache_bypasses==segments.size(),"cache requires explicit acquisition identity")
	_finish()

func _target(half_size: float, plane: StringName, source: StringName) -> Dictionary:
	return _reference.prepare_ordered_target(PackedVector2Array([
		Vector2(-half_size,-half_size),Vector2(half_size,-half_size),Vector2(half_size,half_size),Vector2(-half_size,half_size)]),plane,source,true)

func _segments(plane: StringName) -> Array:
	return [
		{"a":Vector2(-0.018,0.0),"b":Vector2(0.018,0.0),"origin_id":plane,"source_id":&"CrossingSkin","max_inward_depth_m":0.002},
		{"a":Vector2(-0.015,0.013),"b":Vector2(0.015,0.013),"origin_id":plane,"source_id":&"OutsideSkin","max_inward_depth_m":0.0005},
		{"a":Vector2(-0.004,0.004),"b":Vector2(0.004,0.004),"origin_id":plane,"source_id":&"InsideSkin","max_inward_depth_m":0.006}]

func _same(label: String, segments: Array, target: Dictionary, plane: StringName, config: Dictionary) -> Dictionary:
	var inputs_before: PackedByteArray = var_to_bytes([segments,target,config])
	var expected: Dictionary = _reference.evaluate_segments(segments,target,plane,config)
	var actual: Dictionary = _cached.evaluate_segments(segments,target,plane,config)
	# Measurement packets contain no profiling fields: compare complete bytes,
	# including source identities, witnesses, bounds, flags and logical work counts.
	_check(var_to_bytes(actual)==var_to_bytes(expected),label+": complete reference packet byte equality")
	_check(var_to_bytes([segments,target,config])==inputs_before,label+": input packets unchanged")
	_cases.append({"label":label,"valid":actual.get("valid",false),"reason":actual.get("reason",""),"cache":_cached.cache_statistics()})
	return actual

func _expect_misses(label: String, segments: Array, target: Dictionary, plane: StringName, config: Dictionary, expected_count: int) -> void:
	var before: int = _cached.cache_statistics().cache_misses
	_same(label,segments,target,plane,config)
	_check(_cached.cache_statistics().cache_misses-before==expected_count,label+": exact input change causes expected misses")

func _miss_change(label: String, segments: Array, target: Dictionary, config: Dictionary, field: String, value: Variant) -> void:
	var changed: Array = segments.duplicate(true); changed[0][field]=value
	_expect_misses(label,changed,target,PLANE,config,1)

func _test_invalid_inputs(target: Dictionary, segments: Array, config: Dictionary) -> void:
	_cached.begin_acquisition(&"invalid-outer-batch")
	var invalid: Array = segments.duplicate(true)
	invalid[1].origin_id=&"WrongPlane"
	var result: Dictionary = _same("invalid-after-valid-prefix",invalid,target,PLANE,config)
	_check(not result.valid and _cached.cache_statistics().entry_count==0 and _cached.cache_statistics().pending_entry_count==0 and _cached.cache_statistics().target_count==0,"invalid outer batch commits neither cached prefix nor target identity")
	_check(_cached.cache_statistics().discarded_pending_entries==1,"valid prefix staged then discarded")
	var bad_target: Dictionary = target.duplicate(true); bad_target.complete=false
	_same("incomplete-target",segments,bad_target,PLANE,config)
	var bad_config: Dictionary = config.duplicate(true); bad_config.max_evaluations_per_segment=2
	_same("invalid-configuration",segments,target,PLANE,bad_config)
	_same("empty-segments",[],target,PLANE,config)
	_same("mismatched-target-plane",segments,target,&"WrongPlane",config)
	_check(_cached.cache_statistics().entry_count==0 and _cached.cache_statistics().target_count==0,"outer validation failures never create edge or target entries")

func _test_eviction(target: Dictionary, segments: Array, config: Dictionary) -> void:
	_check(_cached.configure_cache(2,1024*1024) and _cached.begin_acquisition(&"entry-bound"),"bounded cache configured")
	for index: int in 3:
		_same("eviction-fill-"+str(index),[segments[index]],target,PLANE,config)
	_check(_cached.cache_statistics().entry_count==2 and _cached.cache_statistics().evictions==1,"FIFO evicts exactly the oldest stored edge")
	var before: int = _cached.cache_statistics().actual_segment_calls
	_same("evicted-edge-recomputed",[segments[0]],target,PLANE,config)
	_check(_cached.cache_statistics().actual_segment_calls==before+1 and _cached.cache_statistics().entry_count==2,"eviction recomputes same packet while preserving entry bound")
	_check(_cached.configure_cache(2,1) and _cached.begin_acquisition(&"byte-bound"),"small byte budget configured")
	_same("oversized-record-not-retained",segments,target,PLANE,config)
	_check(_cached.cache_statistics().entry_count==0 and _cached.cache_statistics().accounted_bytes<=1 and _cached.cache_statistics().unretained_entries==segments.size(),"oversized records bypass storage without changing queries")
	_check(_cached.cache_statistics().target_count==0,"unused target identity is not retained when all edge records exceed budget")

func _test_target_bounds(target: Dictionary, segments: Array, config: Dictionary) -> void:
	_check(_cached.configure_cache(8192,32*1024*1024,2,8*1024*1024) and _cached.begin_acquisition(&"target-count-bound"),"bounded exact target table configured")
	_same("target-table-first",segments,target,PLANE,config)
	var second: Dictionary = _target(0.011,PLANE,&"MeasuredTestHandle")
	_same("target-table-second",segments,second,PLANE,config)
	_check(_cached.cache_statistics().target_count==2 and _cached.cache_statistics().entry_count==6,"two exact targets own independent compact edge identities")
	_same("target-table-third-flush",segments,_target(0.012,PLANE,&"MeasuredTestHandle"),PLANE,config)
	_check(_cached.cache_statistics().target_count==1 and _cached.cache_statistics().target_table_flushes==1 and _cached.cache_statistics().entry_count==3,"target-count bound flushes targets and dependent edges together")
	var before: int = _cached.cache_statistics().actual_segment_calls
	_same("target-table-old-body-recomputed",segments,target,PLANE,config)
	_check(_cached.cache_statistics().actual_segment_calls-before==segments.size(),"flushed target never aliases newer compact identity")
	var target_bytes: int = var_to_bytes(target).hex_encode().length()*4+8
	_check(_cached.configure_cache(8192,32*1024*1024,128,target_bytes) and _cached.begin_acquisition(&"target-byte-bound"),"target byte bound configured")
	_same("target-byte-first",segments,target,PLANE,config)
	_same("target-byte-second-flush",segments,second,PLANE,config)
	_check(_cached.cache_statistics().target_count==1 and _cached.cache_statistics().target_table_flushes==1 and _cached.cache_statistics().target_accounted_bytes<=target_bytes,"target bytes remain bounded with deterministic dependent-edge flush")
	_check(_cached.configure_cache(8192,32*1024*1024,128,1) and _cached.begin_acquisition(&"oversized-target"),"oversized target bypass configured")
	_same("target-too-large",segments,target,PLANE,config)
	_check(_cached.cache_statistics().target_count==0 and _cached.cache_statistics().entry_count==0 and _cached.cache_statistics().target_storage_bypasses==1 and _cached.cache_statistics().actual_segment_calls==segments.size(),"oversized exact target uses unchanged uncached computation")
	# Exact dictionaries, rather than a digest-only table, resolve all identity
	# comparisons by the entire serialized body; no digest collision hook exists.

func _check(condition: bool, label: String) -> void:
	_checks+=1
	if not condition: _failures.append(label); push_error(label)

func _finish() -> void:
	var report: Dictionary = {"schema":"exact_planar_segment_cache_verifier_v1","ok":_failures.is_empty(),"checks":_checks,
		"failures":_failures,"cases":_cases,"production_pose_written":false,"solver_rules_changed":false,
		"source_sha256":{"reference":FileAccess.get_sha256("res://tools/grip_plane_proof/planar_skin_overlap_budget.gd"),
			"prototype":FileAccess.get_sha256("res://tools/grip_plane_proof/exact_cached_planar_skin_overlap_budget.gd"),"verifier":FileAccess.get_sha256(get_script().resource_path)}}
	var path: String = "C:/WORKSPACE/test_artifacts/verify_exact_cached_planar_skin_overlap_budget_"+Time.get_datetime_string_from_system().replace(":","-")+".json"
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	if file==null: push_error("Cannot save cache verifier"); quit(1); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("EXACT_SEGMENT_CACHE_RESULT="+path)
	print("EXACT_SEGMENT_CACHE_SUMMARY="+JSON.stringify({"ok":report.ok,"checks":_checks,"failures":_failures}))
	quit(0 if report.ok else 1)
