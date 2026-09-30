extends RefCounted

## Isolated prescribed guide geometry. No hand pose, overlap allowance, runtime
## rule, or physical grip certificate is created here. All points remain in the
## caller's named metric plane; center is never inferred from the wrapper.
## Godot 4.7 Geometry2D: convex_hull, offset_polygon, clip_polygons.
const Depth = preload("res://runtime/player/grip/planar_skin_overlap_budget.gd")
const Envelope = preload("res://runtime/player/grip/planar_contact_envelope.gd")
const REVISION: StringName = &"planar_grip_guide_progression_v1"
const NUMERIC_CONTAINMENT_TOLERANCE_M: float = 0.00001
const CIRCLE_OUTER_ERROR_M: float = 0.00001
const MAX_CIRCLE_SIDES: int = 512
const SCALE: float = 100000.0
const CONTACT_TARGET_REVISION: StringName = &"inward_guide_contact_target_v1"


func prepare(polygon: PackedVector2Array, center: Vector2, plane_origin_id: StringName, source_id: StringName, inward_min_radius_m: float) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	if not center.is_finite() or not is_finite(inward_min_radius_m) or inward_min_radius_m <= 0.0:
		return _fail("invalid_center_or_inward_radius")
	var source_target: Dictionary = Depth.new().prepare_ordered_target(polygon, plane_origin_id, source_id, true)
	if not source_target.get("valid", false): return _fail("invalid_source", source_target)
	var source: PackedVector2Array = source_target.polygon.duplicate()
	var hull: PackedVector2Array = Geometry2D.convex_hull(source)
	if hull.size() > 1 and hull[0] == hull[-1]: hull.resize(hull.size() - 1)
	if not Geometry2D.is_point_in_polygon(center, hull): return _fail("center_outside_source_hull")
	var built: Dictionary = Envelope.new().build(source, plane_origin_id, source_id, inward_min_radius_m, true)
	if not built.get("valid", false): return _fail("final_envelope_construction_failed", built)
	var envelope: PackedVector2Array = built.envelope_polygon_m.duplicate()
	var containment: Dictionary = _containment(source, envelope, center)
	if not containment.get("within_numeric_tolerance", false): return _fail("final_envelope_undercut_exceeds_numeric_tolerance", containment)
	var final_target: Dictionary = Depth.new().prepare_ordered_target(envelope, plane_origin_id, StringName(String(source_id) + ":grip_guide"), true)
	if not final_target.get("valid", false): return _fail("invalid_final_envelope", final_target)
	var enclosing: float = 0.0
	for point: Vector2 in source: enclosing = maxf(enclosing, point.distance_to(center))
	# Runtime identity uses explicit algorithm revisions; exported scripts need not
	# exist as readable source files. Geometry inputs remain fully represented.
	var identity: Array = [REVISION, source, center, plane_origin_id, source_id, inward_min_radius_m,
		Envelope.REVISION]
	return {"valid": true, "revision": REVISION, "source_polygon_m": source,
		"source_target": source_target, "hull_polygon_m": hull, "final_envelope_polygon_m": envelope,
		"center": center, "origin_id": plane_origin_id, "source_id": source_id,
		"inward_min_radius_m": inward_min_radius_m, "enclosing_radius_m": enclosing,
		"final_envelope_metadata": built, "final_source_containment": containment,
		"input_fingerprint": var_to_bytes(identity).hex_encode().sha256_text(), "sample_cache": {},
		"preparation_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"radial_source_representation_required": false, "production_pose_written": false}


func sample(prepared: Dictionary, phase: String, amount: float, radius: float, inward_target_offset_m: float = 0.0) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	if not prepared.get("valid", false) or prepared.get("revision") != REVISION:
		return _fail("invalid_prepared_progression")
	if phase != "hull_transition" and phase != "wrapper_transition": return _fail("unknown_guide_phase")
	if not is_finite(amount) or amount < 0.0 or amount > 1.0 or not is_finite(radius) or radius <= 0.0:
		return _fail("invalid_phase_amount_or_radius")
	if not is_finite(inward_target_offset_m) or inward_target_offset_m < 0.0:
		return _fail("invalid_inward_contact_target_offset")
	if phase == "hull_transition" and radius < float(prepared.enclosing_radius_m) - 0.000000001:
		return _fail("prescribed_circle_does_not_enclose_source")
	var key: String = var_to_bytes([phase, amount, radius] if inward_target_offset_m == 0.0 else [phase, amount, radius, inward_target_offset_m]).hex_encode()
	if prepared.sample_cache.has(key): return (prepared.sample_cache[key] as Dictionary).duplicate(true)
	var polygon: PackedVector2Array = PackedVector2Array()
	var construction: String = ""
	var bend_radius: float = INF
	var circle_error: float = 0.0
	var circle_sides: int = 0
	var build_ms: float = 0.0
	if phase == "hull_transition":
		if amount == 1.0:
			polygon = prepared.hull_polygon_m.duplicate()
			construction = "exact_source_convex_hull"
		else:
			var circle: Dictionary = _circumscribed_circle(prepared.center, radius)
			if not circle.get("valid", false): return circle
			circle_error = circle.maximum_radial_excess_m
			circle_sides = circle.sides
			if amount == 0.0:
				polygon = circle.polygon
			else:
				# Minkowski interpolation of two convex sets, both containing the
				# source hull. This does not assume that the raw profile is radial.
				var pairs: PackedVector2Array = PackedVector2Array()
				for outer: Vector2 in circle.polygon:
					for inner: Vector2 in prepared.hull_polygon_m:
						pairs.append(outer.lerp(inner, amount))
				polygon = Geometry2D.convex_hull(pairs)
				if polygon.size() > 1 and polygon[0] == polygon[-1]: polygon.resize(polygon.size() - 1)
			construction = "convex_minkowski_circle_to_source_hull"
	else:
		if amount == 0.0:
			polygon = prepared.hull_polygon_m.duplicate()
			construction = "exact_source_convex_hull"
		else:
			bend_radius = float(prepared.inward_min_radius_m) / amount
			if amount == 1.0:
				polygon = prepared.final_envelope_polygon_m.duplicate()
				construction = prepared.final_envelope_metadata.construction
			else:
				var built: Dictionary = Envelope.new().build(prepared.source_polygon_m, prepared.origin_id,
					prepared.source_id, bend_radius, true)
				if not built.get("valid", false): return _fail("intermediate_envelope_construction_failed", built)
				polygon = built.envelope_polygon_m
				construction = built.construction
				build_ms = built.total_build_ms
	var target: Dictionary = Depth.new().prepare_ordered_target(polygon, prepared.origin_id,
		StringName(String(prepared.source_id) + ":grip_guide"), true)
	if not target.get("valid", false): return _fail("invalid_intermediate_guide", target)
	var containment: Dictionary = _containment(prepared.source_polygon_m, polygon, prepared.center)
	if not containment.get("within_numeric_tolerance", false): return _fail("intermediate_guide_undercut_exceeds_numeric_tolerance", containment)
	var result: Dictionary = {"valid": true, "revision": REVISION, "phase": phase, "amount": amount,
		"polygon": polygon, "target": target, "center": prepared.center, "origin_id": prepared.origin_id,
		"source_id": prepared.source_id, "enclosing_radius_m": prepared.enclosing_radius_m,
		"prescribed_circle_radius_m": radius, "inward_min_radius_m": prepared.inward_min_radius_m,
		"construction_bend_radius_m": bend_radius, "construction": construction,
		"source_contained": containment.exact_difference_empty,
		"source_contained_within_numeric_tolerance": containment.within_numeric_tolerance,
		"source_containment": containment, "circle_polygon_sides": circle_sides,
		"circle_polygon_maximum_outer_error_m": circle_error,
		"input_fingerprint": prepared.input_fingerprint,
		"geometry_fingerprint": var_to_bytes([polygon, prepared.center, prepared.origin_id, prepared.source_id]).hex_encode().sha256_text(),
		"offset_build_ms": build_ms, "sample_build_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"continuous_curvature_certified": false, "continuous_sweep_certified": false,
		"actual_3d_grip_verified": false, "production_pose_written": false}
	if inward_target_offset_m > 0.0:
		result = inset_contact_target(result, inward_target_offset_m)
		if not result.get("valid", false): return result
	prepared.sample_cache[key] = result.duplicate(true)
	return result


## Change only the guide's attraction surface. The physical weapon polygon,
## per-section material caps and slice center remain separate authorities.
## The caller invokes this only once material contact is being assessed.
## Negative native offsets may split/disappear: report that condition rather
## than selecting an arbitrary island or inventing a replacement target.
func inset_contact_target(guide: Dictionary, distance_m: float) -> Dictionary:
	if not guide.get("valid", false) or not guide.get("center") is Vector2 or not guide.center.is_finite() or not guide.get("polygon") is PackedVector2Array:
		return _fail("invalid_guide_for_inward_contact_target")
	if StringName(guide.get("origin_id", &"")) == &"" or StringName(guide.get("source_id", &"")) == &"":
		return _fail("missing_inward_contact_target_provenance")
	if not is_finite(distance_m) or distance_m < 0.0:
		return _fail("invalid_inward_contact_target_offset")
	if distance_m == 0.0: return guide.duplicate(true)
	if guide.has("contact_target_offset_m"):
		return _fail("contact_target_already_offset")
	var result: Dictionary = guide.duplicate(true)
	result["contact_target_revision"] = CONTACT_TARGET_REVISION
	result["contact_target_offset_m"] = distance_m
	result["unoffset_guide_polygon_m"] = guide.polygon.duplicate()
	result["unoffset_guide_geometry_fingerprint"] = guide.get("geometry_fingerprint", "")
	result["physical_material_changed"] = false
	if guide.polygon.is_empty():
		var radius := float(guide.get("radius_m", -1.0))
		if not is_finite(radius) or radius <= distance_m:
			return _fail("inward_circle_target_collapsed")
		result["unoffset_guide_radius_m"] = radius
		result["radius_m"] = radius - distance_m
	else:
		var scaled := PackedVector2Array()
		for point: Vector2 in guide.polygon:
			if not point.is_finite(): return _fail("nonfinite_inward_target_source")
			var value: Vector2 = (point - guide.center) * SCALE
			if not value.is_finite() or value.length() > 100000000.0: return _fail("inward_target_outside_numeric_range")
			scaled.append(value)
		if not is_finite(distance_m * SCALE) or distance_m * SCALE > 100000000.0:
			return _fail("inward_target_offset_outside_numeric_range")
		var loops: Array[PackedVector2Array] = Geometry2D.offset_polygon(scaled, -distance_m * SCALE, Geometry2D.JOIN_ROUND)
		if loops.size() != 1:
			return _fail("inward_contact_target_not_one_loop", {"loop_count": loops.size(), "offset_m": distance_m})
		var polygon := PackedVector2Array()
		for point: Vector2 in loops[0]:
			var restored: Vector2 = point / SCALE + guide.center
			if polygon.is_empty() or restored != polygon[-1]: polygon.append(restored)
		if polygon.size() > 1 and polygon[0] == polygon[-1]: polygon.resize(polygon.size() - 1)
		var target: Dictionary = Depth.new().prepare_ordered_target(polygon, guide.origin_id,
			StringName(String(guide.source_id) + ":grip_guide"), true)
		if not target.get("valid", false): return _fail("invalid_inward_contact_target", target)
		var nesting: Dictionary = _containment(polygon, guide.polygon, guide.center)
		if not nesting.get("within_numeric_tolerance", false): return _fail("inward_target_extends_outside_original_guide", nesting)
		result["polygon"] = polygon
		result["target"] = target
		result["unoffset_source_containment"] = guide.get("source_containment", {}).duplicate(true)
		# Containment of the physical source is deliberately no longer asserted
		# for a target below its surface. Keep the old envelope evidence distinct.
		result.erase("source_containment")
		result.erase("source_contained")
		result.erase("source_contained_within_numeric_tolerance")
		result["inward_target_containment"] = nesting
		result["nominal_offset_arc_tolerance_m"] = 0.25 / SCALE
	result["geometry_fingerprint"] = var_to_bytes([CONTACT_TARGET_REVISION,
		guide.get("geometry_fingerprint", ""), result.polygon, result.get("radius_m", 0.0),
		guide.center, guide.origin_id, guide.source_id, distance_m]).hex_encode().sha256_text()
	return result


func _circumscribed_circle(center: Vector2, radius: float) -> Dictionary:
	var half_angle: float = acos(radius / (radius + CIRCLE_OUTER_ERROR_M))
	if not is_finite(half_angle) or half_angle <= 0.0: return _fail("circle_radius_outside_numeric_range")
	var count: float = ceil(PI / half_angle)
	if not is_finite(count) or count > float(MAX_CIRCLE_SIDES):
		return _fail("circle_approximation_exceeds_bounded_side_count", {"required_sides": count})
	var required: int = int(count)
	var sides: int = maxi(required, 16)
	if sides > MAX_CIRCLE_SIDES: return _fail("circle_approximation_exceeds_bounded_side_count", {"required_sides": sides})
	var outer_radius: float = radius / cos(PI / float(sides))
	var polygon: PackedVector2Array = PackedVector2Array()
	for index: int in sides:
		var angle: float = TAU * float(index) / float(sides)
		polygon.append(center + Vector2(cos(angle), sin(angle)) * outer_radius)
	return {"valid": true, "polygon": polygon, "sides": sides,
		"maximum_radial_excess_m": outer_radius - radius}


func _containment(source: PackedVector2Array, guide: PackedVector2Array, center: Vector2) -> Dictionary:
	# Explicit metric recentering/scaling matches the existing envelope tool.
	# Report unexpanded undercut; a small numeric allowance does not hide it.
	var a: PackedVector2Array = PackedVector2Array()
	var b: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in source: a.append((point - center) * SCALE)
	for point: Vector2 in guide: b.append((point - center) * SCALE)
	var outside: Array[PackedVector2Array] = Geometry2D.clip_polygons(a, b)
	var area: float = 0.0
	for loop: PackedVector2Array in outside: area += _signed_area(loop)
	var expanded: Array[PackedVector2Array] = Geometry2D.offset_polygon(b, NUMERIC_CONTAINMENT_TOLERANCE_M * SCALE, Geometry2D.JOIN_ROUND)
	if expanded.size() != 1: return {"valid": false, "within_numeric_tolerance": false, "reason": "numeric_containment_expansion_not_one_loop"}
	var beyond: Array[PackedVector2Array] = Geometry2D.clip_polygons(a, expanded[0])
	var beyond_area: float = 0.0
	for loop: PackedVector2Array in beyond: beyond_area += _signed_area(loop)
	return {"valid": true, "exact_difference_empty": outside.is_empty(),
		"outside_area_m2": absf(area) / (SCALE * SCALE), "outside_loop_count": outside.size(),
		"numeric_tolerance_m": NUMERIC_CONTAINMENT_TOLERANCE_M,
		"within_numeric_tolerance": beyond.is_empty(), "outside_expanded_area_m2": absf(beyond_area) / (SCALE * SCALE),
		"numeric_units_per_meter": SCALE, "comparison": "source_difference_and_source_difference_from_expanded_guide",
		"exact_real_arithmetic_certificate": false}


func _signed_area(polygon: PackedVector2Array) -> float:
	var twice: float = 0.0
	for index: int in polygon.size():
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		twice += float(a.x) * float(b.y) - float(a.y) * float(b.x)
	return twice * 0.5


func _fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"valid": false, "revision": REVISION, "reason": reason, "details": details,
		"continuous_curvature_certified": false, "production_pose_written": false}
