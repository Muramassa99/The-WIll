extends SceneTree

## Independent frozen Contact oracle. The frozen overlap kernel preloads the
## current Contact file, so it cannot alone verify changes to these primitives.
## Exact packet bytes preserve tie ordering, numeric types and signed zero.
const Current = preload("res://runtime/player/grip/skin_plane_contact_query.gd")
const ORACLE_PATH := "C:/WORKSPACE/test_artifacts/skin_plane_contact_query_pre_duration_2026-09-30.gd"
const ORACLE_HASH := "56a7ac7dd64852be9a5bddbb1349fabac890b9bc1acf877fc0ecb631a24c135c"
const RANDOM_SEED: int = 1497218309
var _current := Current.new()
var _oracle: Variant
var _checks: Array = []
var _cases: Array = []
var _failures: int = 0
var _legacy_noncallable: Array = []
var _started: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_started = Time.get_ticks_usec()
	if not _check(FileAccess.get_sha256(ORACLE_PATH) == ORACLE_HASH,"frozen Contact oracle hash"):
		_finish(); return
	var script: GDScript = ResourceLoader.load(ORACLE_PATH,"GDScript",ResourceLoader.CACHE_MODE_IGNORE)
	if not _check(script != null,"load independent absolute-path Contact oracle"):
		_finish(); return
	_oracle = script.new()
	var named: Array = [
		["proper_crossing",Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1)],
		["parallel_equal_distance_tie",Vector2(-1,0),Vector2(1,0),Vector2(-1,1),Vector2(1,1)],
		["disjoint_endpoint_tie",Vector2(-1,0),Vector2(1,0),Vector2(0,1),Vector2(0,2)],
		["collinear_identical",Vector2(-1,0),Vector2(1,0),Vector2(-1,0),Vector2(1,0)],
		["collinear_reversed",Vector2(-1,0),Vector2(1,0),Vector2(1,0),Vector2(-1,0)],
		["collinear_partial",Vector2(-1,0),Vector2(1,0),Vector2(0,0),Vector2(2,0)],
		["collinear_separate",Vector2(-2,0),Vector2(-1,0),Vector2(1,0),Vector2(2,0)],
		["shared_a_c",Vector2(0,0),Vector2(1,0),Vector2(0,0),Vector2(0,1)],
		["shared_a_d",Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(0,0)],
		["shared_b_c",Vector2(0,0),Vector2(1,0),Vector2(1,0),Vector2(1,1)],
		["shared_b_d",Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(1,0)],
		["signed_zero_a_first",Vector2(-0.0,0.0),Vector2(1,0),Vector2(0.0,-0.0),Vector2(0,1)],
		["signed_zero_b_first",Vector2(-1,0),Vector2(-0.0,-0.0),Vector2(0.0,0.0),Vector2(0,1)],
		["negative_coordinates",Vector2(-2,-3),Vector2(-1,-1),Vector2(-3,-2),Vector2(-1,-2)],
		["zero_length_skin",Vector2(0,0),Vector2(0,0),Vector2(-1,0),Vector2(1,0)],
		["zero_length_target",Vector2(-1,0),Vector2(1,0),Vector2(0,0),Vector2(0,0)],
		["two_equal_points",Vector2(0,0),Vector2(0,0),Vector2(0,0),Vector2(0,0)],
		["two_different_points",Vector2(0,0),Vector2(0,0),Vector2(1,1),Vector2(1,1)],
		["infinite_skin_component",Vector2(INF,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1)],
		["negative_infinite_target",Vector2(-1,0),Vector2(1,0),Vector2(-INF,-1),Vector2(0,1)],
		["nan_skin_component",Vector2(NAN,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1)],
		["nan_target_component",Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,NAN)]]
	for fixture: Array in named:
		_case(fixture[0],fixture[1],fixture[2],fixture[3],fixture[4])
	# Same relationships at several representable scales and translations.
	# The smallest scales also exercise legacy real_t squared-length underflow.
	for scale: float in [1.0e-22,1.0e-7,0.001,1.0,1000.0]:
		for translation: Vector2 in [Vector2.ZERO,Vector2(-0.137,-0.213),Vector2(1000.0,-1000.0)]:
			_case("scaled_translated_crossing/" + str(scale) + "/" + str(translation),
				Vector2(-1.0,0.25)*scale+translation,Vector2(1.0,0.25)*scale+translation,
				Vector2(0.125,-1.0)*scale+translation,Vector2(0.125,1.0)*scale+translation)
	var rng := RandomNumberGenerator.new()
	rng.seed = RANDOM_SEED
	for index: int in 96:
		var a := _random_point(rng)
		var b := _random_point(rng)
		var c := _random_point(rng)
		var d := _random_point(rng)
		# One third of the fixed corpus explicitly exercises endpoint-hit order.
		if index % 3 == 0:
			match index % 4:
				0: c = a
				1: d = a
				2: c = b
				3: d = b
		_case("deterministic_finite/" + str(index),a,b,c,d)
	_check(FileAccess.get_sha256(ORACLE_PATH) == ORACLE_HASH,"frozen Contact oracle unchanged")
	_finish()


func _random_point(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(rng.randf_range(-0.2,0.2),rng.randf_range(-0.2,0.2))


func _case(label: String, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	var projections: Array = [[a,c,d],[b,c,d],[c,a,b],[d,a,b]]
	for index: int in projections.size():
		var values: Array = projections[index]
		var old_projection: Variant = _oracle._project(values[0],values[1],values[2])
		var new_projection: Variant = _current._project(values[0],values[1],values[2])
		_same(old_projection,new_projection,label + ": exact projection " + str(index))
	var old_hit: Variant = _oracle._intersection(a,b,c,d)
	var new_hit: Variant = _current._intersection(a,b,c,d)
	var intersection_equal: bool = _same(old_hit,new_hit,label + ": exact intersection bytes")
	var record := {"name":label,"intersection_equal":intersection_equal,
		"finite_inputs":a.is_finite() and b.is_finite() and c.is_finite() and d.is_finite(),
		"degenerate_input":a == b or c == d,"nearest_comparisons":0}
	if old_hit is Dictionary and new_hit is Dictionary:
		var immutable_hits: PackedByteArray = var_to_bytes([old_hit,new_hit])
		# Isolate _nearest from its caller, then verify the composed path too.
		var old_old: Variant = _oracle._nearest(a,b,c,d,old_hit)
		var new_old: Variant = _current._nearest(a,b,c,d,old_hit)
		_same(old_old,new_old,label + ": nearest using frozen intersection")
		var old_new: Variant = _oracle._nearest(a,b,c,d,new_hit)
		var new_new: Variant = _current._nearest(a,b,c,d,new_hit)
		_same(old_new,new_new,label + ": nearest using current intersection")
		_same(old_old,new_new,label + ": composed intersection and nearest bytes")
		_check(var_to_bytes([old_hit,new_hit]) == immutable_hits,label + ": hit packets immutable")
		record.nearest_comparisons = 3
	else:
		_legacy_noncallable.append({"name":label,"primitive":"intersection","old_type":typeof(old_hit),"new_type":typeof(new_hit)})
	# Even a crossing pair exercises all four ordered endpoint projections when
	# the caller explicitly supplies no hit. Preserve that primitive behavior.
	var old_empty: Variant = _oracle._nearest(a,b,c,d,{})
	var new_empty: Variant = _current._nearest(a,b,c,d,{})
	_same(old_empty,new_empty,label + ": nearest empty-hit projection path")
	if not old_empty is Dictionary:
		_legacy_noncallable.append({"name":label,"primitive":"nearest_empty_hit","old_type":typeof(old_empty),"new_type":typeof(new_empty)})
	record.nearest_comparisons += 1
	_cases.append(record)


func _same(before: Variant, after: Variant, label: String) -> bool:
	var same: bool = var_to_bytes(before) == var_to_bytes(after)
	if not same:
		label += " | before=" + str(before).left(220) + " after=" + str(after).left(220)
	return _check(same,label)


func _check(condition: bool, label: String) -> bool:
	_checks.append({"passed":condition,"label":label})
	if not condition:
		_failures += 1
		push_error(label)
	return condition


func _finish() -> void:
	var prefix: String = "C:/WORKSPACE/test_artifacts/skin_contact_primitives_" + Time.get_datetime_string_from_system().replace(":","-")
	var report := {"passed":_failures == 0,"checks":_checks,"cases":_cases,"legacy_noncallable":_legacy_noncallable,
		"oracle_path":ORACLE_PATH,"oracle_sha256":ORACLE_HASH,"random_seed":RANDOM_SEED,
		"total_ms":float(Time.get_ticks_usec()-_started)/1000.0,
		"scope":"exact _project, _intersection and _nearest packet bytes against independent frozen Contact; no geometric, tolerance, or grip-acceptance changes",
		"production_pose_written":false}
	var file := FileAccess.open(prefix + ".json",FileAccess.WRITE)
	if file == null:
		_check(false,"write Contact primitive equivalence report")
	else:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	print("SKIN_CONTACT_PRIMITIVES ","PASS" if _failures == 0 else "FAIL"," checks=",_checks.size(),
		" cases=",_cases.size()," failures=",_failures," noncallable=",_legacy_noncallable.size()," report=",prefix + ".json")
	quit(0 if _failures == 0 else 1)
