extends RefCounted

## A working guide approaches the already saved Forge target. It never builds
## an envelope, reapplies an inward offset, moves skin, or decides a grip cap.
## K(p) = enclosing circle intersect outward-offset(saved target, (1-p)*D).
## D = initial radius + greatest saved-target vertex distance from the center.
## Exact endpoint packets bypass polygon clipping. Intermediate single loops
## use native Geometry2D operations in the established metric scale.
const Geometry = preload("res://runtime/player/grip/planar_grip_guide_progression.gd")
const Depth = preload("res://runtime/player/grip/planar_skin_overlap_budget.gd")
const REVISION := &"saved_wrapper_guide_progression_v1"
const KINDS: Array[StringName] = [&"digit_target", &"palm_target"]
const MAX_CACHE_ENTRIES := 64
const SCALE := Geometry.SCALE
const CIRCLE_OUTER_ERROR_M := Geometry.CIRCLE_OUTER_ERROR_M
const NUMERIC_CONTAINMENT_TOLERANCE_M := Geometry.NUMERIC_CONTAINMENT_TOLERANCE_M
var _geometry := Geometry.new()
var _depth := Depth.new()
var _cache := {}
var _order: Array[String] = []
var _hits := 0
var _misses := 0


func reset() -> void:
	_cache.clear()
	_order.clear()
	_hits = 0
	_misses = 0


func statistics() -> Dictionary:
	return {"revision":REVISION, "cache_entries":_cache.size(), "maximum_cache_entries":MAX_CACHE_ENTRIES,
		"cache_hits":_hits, "cache_misses":_misses, "key_policy":&"exact_input_variant_bytes_no_quantization"}


func sample(section: Dictionary, radius_m: float, progress: float) -> Dictionary:
	var started := Time.get_ticks_usec()
	if not is_finite(radius_m) or radius_m <= 0.0 or not is_finite(progress) or progress < 0.0 or progress > 1.0:
		return _fail("invalid_working_guide_radius_or_progress")
	if section.has("working_guide"):
		return _fail("working_guide_is_not_saved_source")
	var origin := StringName(section.get("origin_id", &""))
	var center_value: Variant = section.get("center")
	if origin == &"" or origin == &"RL_BoneRoot" or not center_value is Vector2 or not center_value.is_finite():
		return _fail("missing_named_saved_section_center")
	if section.has("center_origin_id") and section.center_origin_id != origin:
		return _fail("saved_section_center_origin_mismatch")
	var center: Vector2 = center_value
	# Include every source field: a same-shape section with different provenance
	# must never retrieve another caller's metadata from a geometry-only cache.
	var key := var_to_bytes([REVISION, section, radius_m, progress]).hex_encode()
	if _cache.has(key):
		_hits += 1
		var cached: Dictionary = _cache[key].duplicate(true)
		cached.cache_hit = true
		cached.sample_ms = float(Time.get_ticks_usec() - started) / 1000.0
		return cached
	_misses += 1
	for kind: StringName in [&"handle", &"digit_target", &"palm_target"]:
		var surface: Variant = section.get(kind)
		if not surface is Dictionary or not surface.get("valid", false) or not surface.get("complete", false):
			return _fail("incomplete_saved_surface", {"kind":kind})
		var source: Variant = surface.get("source_id")
		if surface.get("origin_id") != origin or not (source is String or source is StringName) or String(source).is_empty():
			return _fail("saved_surface_origin_or_source_mismatch", {"kind":kind})
		if not surface.get("polygon") is PackedVector2Array:
			return _fail("missing_saved_surface_polygon", {"kind":kind})
		var validated: Dictionary = _depth.prepare_ordered_target(surface.polygon, origin, StringName(source), true)
		if not validated.get("valid", false):
			return _fail("invalid_saved_surface_polygon", {"kind":kind, "detail":validated})
	var circle: Dictionary = _geometry._circumscribed_circle(center, radius_m)
	if not circle.get("valid", false): return _fail("working_circle_unavailable", circle)
	var result_section: Dictionary = section.duplicate(true)
	var targets := {}
	for kind: StringName in KINDS:
		var saved_polygon: PackedVector2Array = section[kind].polygon
		var farthest := 0.0
		for point: Vector2 in saved_polygon: farthest = maxf(farthest, point.distance_to(center))
		# Convexity of the circle makes checking vertices sufficient for each
		# saved straight edge. Never grow the caller's radius to hide bad input.
		if farthest > radius_m:
			return _fail("saved_target_outside_initial_circle", {"kind":kind, "required_radius_m":farthest, "supplied_radius_m":radius_m})
		var distance_m: float = (1.0 - progress) * (radius_m + farthest)
		var polygon: PackedVector2Array
		if progress == 0.0:
			polygon = circle.polygon.duplicate()
		elif progress == 1.0:
			polygon = saved_polygon.duplicate()
		else:
			var intermediate := _intermediate(saved_polygon, circle.polygon, center, distance_m, origin, StringName(section[kind].source_id))
			if not intermediate.get("valid", false): return _fail("working_target_unavailable", {"kind":kind, "detail":intermediate})
			polygon = intermediate.polygon
		var contains_final: Dictionary = _geometry._containment(saved_polygon, polygon, center)
		var within_circle: Dictionary = _geometry._containment(polygon, circle.polygon, center)
		if not contains_final.get("within_numeric_tolerance", false) or not within_circle.get("within_numeric_tolerance", false):
			return _fail("working_target_containment_failed", {"kind":kind, "contains_final":contains_final, "within_circle":within_circle})
		result_section[kind].polygon = polygon
		targets[kind] = {"source_id":section[kind].source_id, "origin_id":origin,
			"outward_distance_m":distance_m, "maximum_saved_vertex_radius_m":farthest,
			"contains_saved_target":contains_final, "within_initial_circle":within_circle,
			"is_exact_saved_polygon":progress == 1.0, "is_initial_circle":progress == 0.0,
			"saved_surface_metadata_retained":true}
	var working := {"revision":REVISION, "progress":progress, "initial_radius_m":radius_m,
		"center":center, "origin_id":origin, "center_origin_id":origin,
		"construction":&"circle_intersection_with_decreasing_outward_saved_target_offset",
		"circle_sides":circle.sides, "circle_maximum_outer_error_m":circle.maximum_radial_excess_m,
		"numeric_units_per_meter":SCALE, "nominal_offset_arc_tolerance_m":0.25 / SCALE,
		"numeric_containment_tolerance_m":NUMERIC_CONTAINMENT_TOLERANCE_M,
		"targets":targets, "saved_target_regenerated":false, "inward_offset_reapplied":false,
		"physical_material_changed":false, "radial_or_star_shape_required":false,
		"continuous_tangency_verified":false, "continuous_curvature_certified":false}
	result_section["working_guide"] = working.duplicate(true)
	var result := {"valid":true, "revision":REVISION, "section":result_section,
		"progress":progress, "initial_radius_m":radius_m, "working_guide":working,
		"cache_hit":false, "sample_ms":float(Time.get_ticks_usec() - started) / 1000.0,
		"production_pose_written":false, "grip_accepted":false}
	if _order.size() >= MAX_CACHE_ENTRIES: _cache.erase(_order.pop_front())
	_cache[key] = result.duplicate(true)
	_order.append(key)
	return result


func _intermediate(saved_polygon: PackedVector2Array, circle: PackedVector2Array, center: Vector2,
		distance_m: float, origin: StringName, source: StringName) -> Dictionary:
	var target_scaled := _scaled(saved_polygon, center)
	var circle_scaled := _scaled(circle, center)
	if target_scaled.is_empty() or circle_scaled.is_empty() or not is_finite(distance_m * SCALE) or distance_m * SCALE > 100000000.0:
		return _fail("working_target_outside_numeric_range")
	var expanded: Array[PackedVector2Array] = Geometry2D.offset_polygon(target_scaled, distance_m * SCALE, Geometry2D.JOIN_ROUND)
	if expanded.size() != 1:
		return _fail("outward_saved_target_not_one_loop", {"loop_count":expanded.size()})
	var loops: Array[PackedVector2Array] = Geometry2D.intersect_polygons(circle_scaled, expanded[0])
	if loops.size() != 1:
		return _fail("working_intersection_not_one_loop", {"loop_count":loops.size()})
	var polygon := PackedVector2Array()
	for point: Vector2 in loops[0]:
		var restored: Vector2 = point / SCALE + center
		# Metric real_t conversion can create exactly zero-length edges. Preserve
		# every nonzero edge; no welding, smoothing or island selection occurs.
		if polygon.is_empty() or polygon[-1] != restored: polygon.append(restored)
	if polygon.size() > 1 and polygon[0] == polygon[-1]: polygon.resize(polygon.size() - 1)
	var checked: Dictionary = _depth.prepare_ordered_target(polygon, origin, source, true)
	if not checked.get("valid", false): return _fail("invalid_working_target_polygon", checked)
	return {"valid":true, "polygon":polygon}


func _scaled(polygon: PackedVector2Array, center: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in polygon:
		var value: Vector2 = (point - center) * SCALE
		if not value.is_finite() or value.length() > 100000000.0: return PackedVector2Array()
		result.append(value)
	return result


func _fail(reason: String, detail: Dictionary = {}) -> Dictionary:
	return {"valid":false, "revision":REVISION, "reason":reason, "detail":detail,
		"production_pose_written":false, "grip_accepted":false}
