extends SceneTree

## Duration-only equivalence against the frozen pre-optimization kernel.
## Exact semantic packets must match; only work_counts and the prepared
## target's derived edge_tree are excluded. No grip pose is generated here.
const Current = preload("res://runtime/player/grip/planar_skin_overlap_budget.gd")
const ORACLE_PATH := "C:/WORKSPACE/test_artifacts/planar_skin_overlap_budget_pre_duration_2026-09-30.gd"
const ORACLE_HASH := "8c7b38ecbb94869dbba794cb83755bf7f5e845164074ea73a5d1c3e5ae67ac98"
const CAPTURE_PATH := "C:/WORKSPACE/test_artifacts/contact_driven_preparation_2026-09-30T11-49-45.json"
const CAPTURE_HASH := "285dd0b63dd49037b2422c67a023beefc7c7353c63867be576dd3df89ab58c7a"
const PLANE := &"OverlapAccelerationProofPlaneOrigin"
const LIVE_CONFIG := {"max_evaluations_per_segment":64,"depth_bound_tolerance_m":0.00001,"refine_depth_after_cap":false}
var _current := Current.new()
var _oracle: Variant
var _checks: Array = []
var _results: Array = []
var _failures: int = 0
var _before_usec: int = 0
var _after_usec: int = 0
var _captured_targets: int = 0
var _started: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_started = Time.get_ticks_usec()
	if not _check(FileAccess.get_sha256(ORACLE_PATH) == ORACLE_HASH,"frozen pre-duration oracle hash"):
		_finish(); return
	if not _check(FileAccess.get_sha256(CAPTURE_PATH) == CAPTURE_HASH,"accepted behavior capture hash"):
		_finish(); return
	var oracle_script: GDScript = ResourceLoader.load(ORACLE_PATH,"GDScript",ResourceLoader.CACHE_MODE_IGNORE)
	if not _check(oracle_script != null,"load frozen absolute-path GDScript oracle"):
		_finish(); return
	_oracle = oracle_script.new()
	_synthetic_cases()
	_captured_cases()
	_check(_captured_targets == 12,"two hands, Middle plus follower, three saved target polygons each")
	_check(FileAccess.get_sha256(ORACLE_PATH) == ORACLE_HASH,"frozen oracle file unchanged")
	_check(FileAccess.get_sha256(CAPTURE_PATH) == CAPTURE_HASH,"accepted capture file unchanged")
	_finish()


func _synthetic_cases() -> void:
	var square := PackedVector2Array([Vector2(-0.01,-0.01),Vector2(0.01,-0.01),Vector2(0.01,0.01),Vector2(-0.01,0.01)])
	var concave := PackedVector2Array([Vector2(-0.012,-0.012),Vector2(-0.002,-0.012),Vector2(-0.002,-0.004),
		Vector2(0.012,-0.004),Vector2(0.012,0.004),Vector2(-0.002,0.004),Vector2(-0.002,0.012),Vector2(-0.012,0.012)])
	var tiny_edges := PackedVector2Array([Vector2(-0.01,-0.01),Vector2(0.0,-0.01),Vector2(0.0000001,-0.01),
		Vector2(0.01,-0.01),Vector2(0.01,0.01),Vector2(-0.01,0.01)])
	var reversed: PackedVector2Array = square.duplicate()
	reversed.reverse()
	var closed: PackedVector2Array = square.duplicate()
	closed.append(closed[0])
	var shifted: PackedVector2Array = []
	var shift := Vector2(-0.137,-0.213)
	for point: Vector2 in concave: shifted.append(point+shift)
	var contours: Array = [
		{"name":"square","polygon":square,"shift":Vector2.ZERO},
		{"name":"concave_recess","polygon":concave,"shift":Vector2.ZERO},
		{"name":"sub_weld_tiny_edges","polygon":tiny_edges,"shift":Vector2.ZERO},
		{"name":"clockwise","polygon":reversed,"shift":Vector2.ZERO},
		{"name":"explicit_closed_endpoint","polygon":closed,"shift":Vector2.ZERO},
		{"name":"negative_coordinates","polygon":shifted,"shift":shift}]
	for contour: Dictionary in contours:
		var segments := _synthetic_segments(contour.shift)
		var configurations: Array = [
			{"name":"default_pruning","config":LIVE_CONFIG.duplicate(true)},
			{"name":"exhaustive_reference","config":_config({"use_boundary_pruning":false})},
			{"name":"minimal_budget","config":_config({"max_evaluations_per_segment":3})},
			{"name":"refine_after_cap","config":_config({"refine_depth_after_cap":true,"max_evaluations_per_segment":32})}]
		_compare_fixture("synthetic/" + contour.name,contour.polygon,segments,PLANE,configurations,true,true)
	# The unordered/mesh-soup preparation path remains covered separately.
	_compare_fixture("synthetic/square_mesh_prepare",square,_synthetic_segments(Vector2.ZERO),PLANE,
		[{"name":"default_pruning","config":LIVE_CONFIG.duplicate(true)}],false,true)
	var bow_tie := PackedVector2Array([Vector2(-0.01,-0.01),Vector2(0.01,0.01),Vector2(-0.01,0.01),Vector2(0.01,-0.01)])
	var backtracking := PackedVector2Array([Vector2(-0.01,-0.01),Vector2(0.01,-0.01),Vector2(0.0,-0.01),
		Vector2(0.01,0.01),Vector2(-0.01,0.01)])
	var zero_edge := square.duplicate()
	zero_edge.insert(1,zero_edge[0])
	for invalid: Dictionary in [{"name":"crossing","polygon":bow_tie},{"name":"backtracking","polygon":backtracking},{"name":"coincident_vertex","polygon":zero_edge}]:
		_compare_fixture("invalid/" + invalid.name,invalid.polygon,_synthetic_segments(Vector2.ZERO),PLANE,[],true,false)


func _synthetic_segments(shift: Vector2) -> Array:
	var samples: Array = [
		[Vector2(-0.03,0.03),Vector2(0.03,0.03),0.0,"outside"],
		[Vector2(-0.02,0.0),Vector2(0.02,0.0),0.0005,"crossing"],
		[Vector2(-0.005,-0.003),Vector2(0.006,0.004),0.002,"inside"],
		[Vector2(-0.02,-0.01),Vector2(0.02,-0.01),0.0,"coincident_edge"],
		[Vector2(-0.02,-0.02),Vector2(-0.01,-0.01),0.0,"corner_contact"],
		[Vector2(-0.015,0.01),Vector2(0.015,0.01),0.0,"top_tangent"],
		[Vector2(-0.02,0.02),Vector2(0.02,-0.02),0.0005,"corner_crossing"],
		[Vector2(-0.0000001,0.0),Vector2(0.0000001,0.0),0.01,"tiny_skin_and_equidistant_edges"],
		[Vector2(-0.002,0.0),Vector2(0.002,0.0),0.01,"nearest_edge_ties"],
		[Vector2(-0.2,-0.3),Vector2(-0.19,-0.28),0.0,"far_negative"]]
	var segments: Array = []
	for sample: Array in samples:
		segments.append({"a":sample[0]+shift,"b":sample[1]+shift,"max_inward_depth_m":sample[2],
			"origin_id":PLANE,"source_id":StringName(sample[3])})
	return segments


func _config(changes: Dictionary) -> Dictionary:
	var config := LIVE_CONFIG.duplicate(true)
	config.merge(changes,true)
	return config


func _captured_cases() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAPTURE_PATH))
	if not _check(raw is Dictionary and raw.get("cases") is Array,"parse frozen captured geometry"):
		return
	for hand: Dictionary in raw.cases:
		var follower: Dictionary = {}
		for stage: Dictionary in hand.stages:
			if stage.label == "follower_response_fixed_weapon":
				follower = stage
				break
		if follower.is_empty():
			for stage: Dictionary in hand.stages:
				if stage.label == "follower_unbound_diagnostic":
					follower = stage
					break
		if not _check(not follower.is_empty(),str(hand.slot) + ": one recorded follower response exists"):
			continue
		for stage: Dictionary in [hand.selected,follower]:
			if not _check(stage.get("digits") is Array and stage.digits.size() == 1,str(hand.slot) + ": one explicit digit plane"):
				continue
			var digit: Dictionary = stage.digits[0]
			var origin := StringName(digit.origin_id)
			var segments: Array = []
			for stored: Dictionary in digit.skin_segments:
				var segment: Dictionary = stored.duplicate(true)
				segment.a = _point(stored.a)
				segment.b = _point(stored.b)
				segment.origin_id = StringName(stored.origin_id)
				segment.source_id = StringName(stored.source_id)
				# Match SavedContact's existing unassigned-skin policy; do not give
				# a blended/unclassified segment a contributing bone's allowance.
				if stored.get("allowance_unassigned",true): segment.max_inward_depth_m = 0.0
				segments.append(segment)
			for field: String in ["handle_polygon","wrapper_polygon","palm_polygon"]:
				var polygon := PackedVector2Array()
				for point: Array in digit[field]: polygon.append(_point(point))
				var label: String = "captured/" + str(hand.slot) + "/" + str(digit.digit) + "/" + field
				_compare_fixture(label,polygon,segments,origin,
					[{"name":"captured_default_pruning","config":LIVE_CONFIG.duplicate(true)}],true,true)
				_captured_targets += 1


func _point(pair: Array) -> Vector2:
	return Vector2(float(pair[0]),float(pair[1]))


func _compare_fixture(label: String, polygon: PackedVector2Array, segments: Array, origin: StringName,
		configurations: Array, ordered: bool, expected_valid: bool) -> void:
	var source := StringName(label)
	var before_input: PackedByteArray = var_to_bytes([polygon,segments])
	var started: int = Time.get_ticks_usec()
	var old_target: Dictionary = _oracle.prepare_ordered_target(polygon,origin,source,true) if ordered else _oracle.prepare_target(polygon,origin,source,true)
	var old_prepare_usec: int = Time.get_ticks_usec()-started
	started = Time.get_ticks_usec()
	var new_target: Dictionary = _current.prepare_ordered_target(polygon,origin,source,true) if ordered else _current.prepare_target(polygon,origin,source,true)
	var new_prepare_usec: int = Time.get_ticks_usec()-started
	var old_semantic: Dictionary = old_target.duplicate(true)
	var new_semantic: Dictionary = new_target.duplicate(true)
	old_semantic.erase("edge_tree")
	new_semantic.erase("edge_tree")
	var difference: String = _difference(old_semantic,new_semantic,"prepared")
	_check(difference.is_empty(),label + ": exact prepared semantics " + difference)
	_check(bool(old_target.get("valid",false)) == expected_valid and bool(new_target.get("valid",false)) == expected_valid,label + ": expected preparation outcome")
	_results.append({"name":label + "/prepare","semantic_match":difference.is_empty(),"first_difference":difference,
		"before_usec":old_prepare_usec,"after_usec":new_prepare_usec,"ordered":ordered,"valid":new_target.get("valid",false),
		"edge_count":polygon.size(),"skin_segment_count":segments.size()})
	if not old_target.get("valid",false) or not new_target.get("valid",false):
		_check(var_to_bytes([polygon,segments]) == before_input,label + ": source geometry immutable")
		return
	var target_bytes_before: PackedByteArray = var_to_bytes([old_target,new_target])
	for configuration: Dictionary in configurations:
		var config: Dictionary = configuration.config
		var immutable_config: PackedByteArray = var_to_bytes(config)
		# Alternate measurement order to avoid always favoring one cache position.
		# Timing excludes preparation, comparison, hashing and report serialization.
		var old_result: Dictionary
		var new_result: Dictionary
		var old_usec: int
		var new_usec: int
		if _results.size() % 2 == 0:
			started = Time.get_ticks_usec()
			new_result = _current.evaluate_segments(segments,new_target,origin,config)
			new_usec = Time.get_ticks_usec()-started
			started = Time.get_ticks_usec()
			old_result = _oracle.evaluate_segments(segments,old_target,origin,config)
			old_usec = Time.get_ticks_usec()-started
		else:
			started = Time.get_ticks_usec()
			old_result = _oracle.evaluate_segments(segments,old_target,origin,config)
			old_usec = Time.get_ticks_usec()-started
			started = Time.get_ticks_usec()
			new_result = _current.evaluate_segments(segments,new_target,origin,config)
			new_usec = Time.get_ticks_usec()-started
		_before_usec += old_usec
		_after_usec += new_usec
		var old_packet: Variant = _without_work_counts(old_result)
		var new_packet: Variant = _without_work_counts(new_result)
		difference = _difference(old_packet,new_packet,"result")
		var name: String = label + "/" + configuration.name
		_check(difference.is_empty(),name + ": exact complete result semantics " + difference)
		_check(old_result.get("valid",false) and new_result.get("valid",false),name + ": both queries valid")
		_check(new_result.get("use_boundary_pruning") == bool(config.get("use_boundary_pruning",true)),name + ": existing pruning mode unchanged")
		_check(var_to_bytes(config) == immutable_config,name + ": caller configuration immutable")
		_results.append({"name":name,"semantic_match":difference.is_empty(),"first_difference":difference,
			"before_usec":old_usec,"after_usec":new_usec,"before_work_counts":old_result.get("work_counts",{}),
			"after_work_counts":new_result.get("work_counts",{}),"cap_status":new_result.get("cap_status",""),
			"depth_evaluations":new_result.get("depth_evaluations",0),"skin_segment_count":segments.size(),
			"edge_count":polygon.size(),"use_boundary_pruning":config.get("use_boundary_pruning",true)})
	_check(var_to_bytes([old_target,new_target]) == target_bytes_before,label + ": prepared targets immutable during queries")
	_check(var_to_bytes([polygon,segments]) == before_input,label + ": source geometry immutable")
	print("OVERLAP_EQUIVALENCE_FIXTURE ",label," complete")


func _without_work_counts(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			if key != "work_counts": result[key] = _without_work_counts(value[key])
		return result
	if value is Array:
		var result: Array = value.duplicate(true)
		for index: int in result.size(): result[index] = _without_work_counts(value[index])
		return result
	return value


func _difference(before: Variant, after: Variant, path: String) -> String:
	if typeof(before) != typeof(after): return path + ": value types differ"
	if var_to_bytes(before) == var_to_bytes(after): return ""
	if before is Dictionary:
		if before.size() != after.size(): return path + ": key count differs"
		for key: Variant in before:
			if not after.has(key): return path + ": missing key " + str(key)
			var difference := _difference(before[key],after[key],path + "." + str(key))
			if not difference.is_empty(): return difference
		return ""
	if before is Array:
		if before.size() != after.size(): return path + ": array size differs"
		for index: int in before.size():
			var difference := _difference(before[index],after[index],path + "[" + str(index) + "]")
			if not difference.is_empty(): return difference
		return ""
	return path + ": " + str(before).left(180) + " != " + str(after).left(180)


func _check(condition: bool, label: String) -> bool:
	_checks.append({"passed":condition,"label":label})
	if not condition:
		_failures += 1
		push_error(label)
	return condition


func _finish() -> void:
	var prefix: String = "C:/WORKSPACE/test_artifacts/planar_overlap_acceleration_" + Time.get_datetime_string_from_system().replace(":","-")
	var report := {"passed":_failures == 0,"checks":_checks,"fixtures":_results,
		"oracle_path":ORACLE_PATH,"oracle_sha256":ORACLE_HASH,"capture_path":CAPTURE_PATH,"capture_sha256":CAPTURE_HASH,
		"before_evaluation_usec":_before_usec,"after_evaluation_usec":_after_usec,
		"evaluation_speedup":float(_before_usec)/float(maxi(1,_after_usec)),
		"total_ms":float(Time.get_ticks_usec()-_started)/1000.0,
		"excluded_fields":["work_counts","prepared.edge_tree"],
		"timing_scope":"one timed query per fixture/configuration, alternating before/after order; local kernel timings, not full grip duration",
		"captured_scope":"final Middle and one follower per hand, all captured skin edges tested against each saved polygon; includes unsafe follower outcomes and broader-than-live palm grouping",
		"production_pose_written":false,"grip_acceptance_claimed":false}
	var file := FileAccess.open(prefix + ".json",FileAccess.WRITE)
	if file == null:
		_check(false,"write overlap acceleration verification report")
	else:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	print("PLANAR_OVERLAP_ACCELERATION ","PASS" if _failures == 0 else "FAIL"," checks=",_checks.size(),
		" failures=",_failures," before_ms=",float(_before_usec)/1000.0," after_ms=",float(_after_usec)/1000.0," report=",prefix + ".json")
	quit(0 if _failures == 0 else 1)
