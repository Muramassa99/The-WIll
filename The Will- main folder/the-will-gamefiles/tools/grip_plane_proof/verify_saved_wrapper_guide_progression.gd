extends SceneTree

## Geometry-only checks. This does not actuate bones or certify a hand grip.
const Progression = preload("res://runtime/player/grip/saved_wrapper_guide_progression.gd")
const ORIGIN := &"SavedWrapperProgressionVerificationPlane"
const RADIUS_M := 0.05
const SCALE := 100000.0
const GUARD_M := 0.00001
var _assertions := 0
var _failures: Array[String] = []
var _cases: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_usec()
	var square := _section(_square(0.02), _square(0.0185), _square(0.017))
	_exercise("square_with_distinct_saved_insets", square, RADIUS_M)
	_square_distance_check(square)
	var nonradial := PackedVector2Array([Vector2(-0.02,-0.02), Vector2(0.02,-0.02),
		Vector2(0.02,0.02), Vector2(0.01,0.02), Vector2(0.01,-0.01),
		Vector2(-0.01,-0.01), Vector2(-0.01,0.02), Vector2(-0.02,0.02)])
	var u := _section(nonradial, _transform(nonradial, 0.9), _transform(nonradial, 0.8))
	_check(not Geometry2D.is_point_in_polygon(Vector2.ZERO, nonradial), "U fixture center lies outside material; no radial or center-inside premise")
	_exercise("nonradial_u", u, RADIUS_M)
	var translated: Dictionary = u.duplicate(true)
	var shift := Vector2(0.037, -0.023)
	translated.center = shift
	for kind: StringName in [&"handle", &"digit_target", &"palm_target"]:
		translated[kind].polygon = _transform(translated[kind].polygon, 1.0, shift)
		translated[kind].polygon.reverse()
	_exercise("translated_clockwise_nonradial_u", translated, 0.117115498049988)
	_rejections(square)
	_multi_loop_rejection()
	_cache_checks(square)
	var report := {"schema":"verify_saved_wrapper_guide_progression_v1", "ok":_failures.is_empty(),
		"assertions":_assertions, "failures":_failures, "cases":_cases,
		"helper_sha256":FileAccess.get_sha256("res://runtime/player/grip/saved_wrapper_guide_progression.gd"),
		"total_ms":float(Time.get_ticks_usec() - started) / 1000.0,
		"production_pose_written":false, "grip_accepted":false, "continuous_tangency_verified":false}
	var path := "C:/WORKSPACE/test_artifacts/verify_saved_wrapper_guide_progression_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot save saved-wrapper guide progression verification")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SAVED_WRAPPER_GUIDE_PROGRESSION_VERIFIER=" + path)
	print("SAVED_WRAPPER_GUIDE_PROGRESSION_SUMMARY=" + JSON.stringify({"ok":report.ok,
		"assertions":_assertions, "failures":_failures, "total_ms":report.total_ms}))
	quit(0 if _failures.is_empty() else 1)


func _exercise(id: String, section: Dictionary, radius: float) -> void:
	var tool := Progression.new()
	var source_bytes := var_to_bytes(section)
	var previous := {}
	var rows: Array = []
	for progress: float in [0.0, 0.125, 0.25, 0.5, 0.75, 0.875, 0.95, 0.99, 1.0]:
		var result: Dictionary = tool.sample(section, radius, progress)
		var label := "%s/%.3f" % [id, progress]
		_check(result.get("valid", false), label + " valid: " + str(result.get("reason", "")) + " " + str(result.get("detail", "")))
		if not result.get("valid", false):
			rows.append({"progress":progress, "failure":result})
			continue
		var working: Dictionary = result.section
		_check(var_to_bytes(section) == source_bytes, label + " entire saved source unchanged")
		_check(var_to_bytes(working.handle) == var_to_bytes(section.handle), label + " physical material and its metadata unchanged")
		_check(working.center == section.center and working.origin_id == ORIGIN and working.center_origin_id == ORIGIN, label + " named slice center retained")
		_check(result.progress == progress and result.initial_radius_m == radius, label + " explicit progress and radius retained")
		_check(not result.working_guide.saved_target_regenerated and not result.working_guide.inward_offset_reapplied, label + " no regeneration or second inset")
		_check(not result.grip_accepted and not result.production_pose_written and not result.working_guide.continuous_tangency_verified, label + " geometry cannot certify a grip")
		_check(result.working_guide.circle_maximum_outer_error_m <= GUARD_M + 1.0e-12, label + " analytic circle approximation at most 0.01 mm")
		for kind: StringName in [&"digit_target", &"palm_target"]:
			var polygon: PackedVector2Array = working[kind].polygon
			var original_metadata: Dictionary = section[kind].duplicate(true)
			var current_metadata: Dictionary = working[kind].duplicate(true)
			original_metadata.erase("polygon")
			current_metadata.erase("polygon")
			_check(var_to_bytes(original_metadata) == var_to_bytes(current_metadata), label + " " + String(kind) + " provenance and saved metadata retained")
			_check(_contained(section[kind].polygon, polygon, section.center), label + " " + String(kind) + " contains exact saved target")
			if previous.has(kind):
				_check(_contained(polygon, previous[kind], section.center), label + " " + String(kind) + " is nested inside previous sample")
			previous[kind] = polygon.duplicate()
			if progress == 0.0:
				for index: int in polygon.size():
					var a: Vector2 = polygon[index] - section.center
					var b: Vector2 = polygon[(index + 1) % polygon.size()] - section.center
					# Vector2 storage rounding is measured independently of the
					# helper's analytic bound; one extra tenth of a micron is allowed.
					_check(a.length() <= radius + GUARD_M + 0.0000001, label + " actual initial vertex obeys radial bound")
					_check(Geometry2D.get_closest_point_to_segment(Vector2.ZERO, a, b).length() >= radius - 0.0000001, label + " initial edge circumscribes prescribed circle")
			if progress == 1.0:
				_check(var_to_bytes(polygon) == var_to_bytes(section[kind].polygon), label + " " + String(kind) + " exact saved endpoint including winding/order")
		if progress == 0.0:
			_check(var_to_bytes(working.digit_target.polygon) == var_to_bytes(working.palm_target.polygon), label + " both regions start on same circle")
		if progress == 1.0:
			_check(working.digit_target.polygon != working.palm_target.polygon, label + " distinct saved digit and palm targets remain distinct")
		rows.append({"progress":progress, "digit_vertices":working.digit_target.polygon.size(),
			"palm_vertices":working.palm_target.polygon.size(), "sample_ms":result.sample_ms})
	_cases.append({"id":id, "samples":rows})


func _square_distance_check(section: Dictionary) -> void:
	var progress := 0.9
	var result: Dictionary = Progression.new().sample(section, RADIUS_M, progress)
	_check(result.get("valid", false), "square metric outward-offset sample valid")
	if not result.get("valid", false): return
	for kind: StringName in [&"digit_target", &"palm_target"]:
		var saved: PackedVector2Array = section[kind].polygon
		var expected_half_size: float = absf(saved[0].x) + (1.0 - progress) * (RADIUS_M + saved[0].length())
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for point: Vector2 in result.section[kind].polygon:
			low = low.min(point)
			high = high.max(point)
		_check(absf(low.x + expected_half_size) < 0.000005 and absf(low.y + expected_half_size) < 0.000005
			and absf(high.x - expected_half_size) < 0.000005 and absf(high.y - expected_half_size) < 0.000005,
			String(kind) + " square has independently expected outward distance in meters")


func _rejections(section: Dictionary) -> void:
	var tool := Progression.new()
	for parameters: Vector2 in [Vector2(0, 0.5), Vector2(-1, 0.5), Vector2(INF, 0.5),
		Vector2(RADIUS_M, -0.1), Vector2(RADIUS_M, 1.1), Vector2(RADIUS_M, NAN)]:
		_check(not tool.sample(section, parameters.x, parameters.y).get("valid", false), "invalid radius/progress rejected: " + str(parameters))
	var changed: Dictionary = section.duplicate(true)
	changed.erase("origin_id")
	_check(not tool.sample(changed, RADIUS_M, 0.5).valid, "anonymous center rejected")
	changed = section.duplicate(true)
	changed.center_origin_id = &"OtherPlane"
	_check(not tool.sample(changed, RADIUS_M, 0.5).valid, "center origin mismatch rejected")
	changed = section.duplicate(true)
	changed.palm_target.complete = false
	_check(not tool.sample(changed, RADIUS_M, 0.5).valid, "incomplete saved target rejected")
	changed = section.duplicate(true)
	changed.digit_target.source_id = &""
	_check(not tool.sample(changed, RADIUS_M, 0.5).valid, "anonymous target rejected")
	changed = section.duplicate(true)
	changed.digit_target.polygon = PackedVector2Array([Vector2(-0.02,-0.02), Vector2(0.02,0.02), Vector2(0.02,-0.02), Vector2(-0.02,0.02)])
	_check(not tool.sample(changed, RADIUS_M, 0.5).valid, "self-crossed target rejected")
	_check(not tool.sample(section, 0.01, 0.5).valid, "target outside initial circle rejected without radius inflation")
	var intermediate: Dictionary = tool.sample(section, RADIUS_M, 0.5)
	if intermediate.get("valid", false):
		_check(not tool.sample(intermediate.section, RADIUS_M, 0.75).valid, "intermediate cannot replace saved authority at next step")


func _multi_loop_rejection() -> void:
	# An outward offset seals this C-shaped entrance while leaving its cavity.
	# Two loops describe solid plus hole; silently choosing either is forbidden.
	var c := PackedVector2Array([Vector2(-0.02,-0.02), Vector2(0.02,-0.02),
		Vector2(0.02,-0.002), Vector2(0.01,-0.002), Vector2(0.01,-0.01),
		Vector2(-0.01,-0.01), Vector2(-0.01,0.01), Vector2(0.01,0.01),
		Vector2(0.01,0.002), Vector2(0.02,0.002), Vector2(0.02,0.02), Vector2(-0.02,0.02)])
	var section := _section(c, c, c)
	var progress: float = 1.0 - 0.003 / (RADIUS_M + c[0].length())
	var result: Dictionary = Progression.new().sample(section, RADIUS_M, progress)
	_check(not result.get("valid", false) and result.get("reason") == "working_target_unavailable"
		and result.get("detail", {}).get("detail", {}).get("reason") == "outward_saved_target_not_one_loop",
		"offset-created hole is explicit failure; no island or loop selected")


func _cache_checks(section: Dictionary) -> void:
	var tool := Progression.new()
	var first: Dictionary = tool.sample(section, RADIUS_M, 1.0)
	_check(first.get("valid", false) and not first.get("cache_hit", true), "first exact-key query builds result")
	if not first.get("valid", false): return
	first.section.digit_target.polygon[0] += Vector2.ONE
	first.section.handle.saved_metadata["mutated"] = true
	first.working_guide.targets.digit_target["mutated"] = true
	var again: Dictionary = tool.sample(section, RADIUS_M, 1.0)
	_check(again.cache_hit and again.section.digit_target.polygon == section.digit_target.polygon
		and not again.section.handle.saved_metadata.has("mutated")
		and not again.working_guide.targets.digit_target.has("mutated"), "cache protected from returned nested geometry and metadata mutation")
	var changed: Dictionary = section.duplicate(true)
	changed.digit_target.source_id = &"DifferentSavedDigitSource"
	var provenance: Dictionary = tool.sample(changed, RADIUS_M, 1.0)
	_check(provenance.valid and not provenance.cache_hit and provenance.section.digit_target.source_id == changed.digit_target.source_id, "same shape with new source cannot retrieve old provenance")
	var tiny_radius_change: Dictionary = tool.sample(section, RADIUS_M + 1.0e-12, 1.0)
	_check(tiny_radius_change.valid and not tiny_radius_change.cache_hit, "radius cache key is exact without rounding")
	var tiny_progress_change: Dictionary = tool.sample(section, RADIUS_M, 1.0 - 1.0e-12)
	_check(tiny_progress_change.valid and not tiny_progress_change.cache_hit, "progress cache key is exact without rounding")
	tool.reset()
	_check(tool.statistics().cache_entries == 0 and tool.statistics().cache_hits == 0 and tool.statistics().cache_misses == 0, "reset clears cache and counters")
	for index: int in Progression.MAX_CACHE_ENTRIES + 1:
		var unique: Dictionary = section.duplicate(true)
		unique["fixture_identity"] = index
		var result: Dictionary = tool.sample(unique, RADIUS_M, 1.0)
		_check(result.get("valid", false) and not result.get("cache_hit", true), "bounded cache accepts unique section " + str(index))
	_check(tool.statistics().cache_entries == Progression.MAX_CACHE_ENTRIES, "cache does not grow beyond explicit limit")
	var oldest: Dictionary = section.duplicate(true)
	oldest["fixture_identity"] = 0
	_check(not tool.sample(oldest, RADIUS_M, 1.0).cache_hit, "oldest cache entry evicted")


func _section(handle: PackedVector2Array, digit: PackedVector2Array, palm: PackedVector2Array) -> Dictionary:
	return {"origin_id":ORIGIN, "center_origin_id":ORIGIN, "center":Vector2.ZERO,
		"named_center_authority":&"physical_handle_slice", "handle":_surface(handle, &"SavedHandle", 0.0),
		"digit_target":_surface(digit, &"SavedDigitTarget", 0.0015),
		"palm_target":_surface(palm, &"SavedPalmTarget", 0.003)}


func _surface(polygon: PackedVector2Array, source: StringName, inset: float) -> Dictionary:
	return {"valid":true, "complete":true, "origin_id":ORIGIN, "source_id":source,
		"polygon":polygon.duplicate(), "saved_inward_offset_m":inset,
		"saved_metadata":{"fixture":true, "existing_fields_must_survive":[1, "saved", Vector2.ONE]}}


func _square(half_size: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-half_size,-half_size), Vector2(half_size,-half_size),
		Vector2(half_size,half_size), Vector2(-half_size,half_size)])


func _transform(polygon: PackedVector2Array, factor: float, translation: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in polygon: result.append(point * factor + translation)
	return result


func _contained(inner: PackedVector2Array, outer: PackedVector2Array, center: Vector2) -> bool:
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	for point: Vector2 in inner: a.append((point - center) * SCALE)
	for point: Vector2 in outer: b.append((point - center) * SCALE)
	var guarded: Array[PackedVector2Array] = Geometry2D.offset_polygon(b, GUARD_M * SCALE, Geometry2D.JOIN_ROUND)
	return guarded.size() == 1 and Geometry2D.clip_polygons(a, guarded[0]).is_empty()


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition: _failures.append(label)
