extends RefCounted

## Exact saved-section target observation; never builds, offsets or repairs a
## wrapper. Named material geometry remains the authority for every skin cap.
## Geometry2D's native nearest-segment query is used only to identify a selected
## depth witness's feature ambiguity; mature Depth owns contact/depth decisions.
const Depth = preload("res://runtime/player/grip/exact_cached_planar_skin_overlap_budget.gd")
const Contact = preload("res://runtime/player/grip/skin_plane_contact_query.gd")
const REVISION := &"saved_wrapper_skin_contact_v1"
const KINDS: Array[StringName] = [&"handle", &"digit_target", &"palm_target"]
const MAX_PREPARED_CACHE := 64
const DEPTH_CONFIG := {"max_evaluations_per_segment":64,"depth_bound_tolerance_m":0.00001,"refine_depth_after_cap":false}
var _depth := Depth.new()
var _cache: Dictionary = {}
var _cache_order: Array[String] = []


## One explicit epoch per hand acquisition. Never reset per pose/section query:
## exact repeat measurements retain the mature bounded cache's full key policy.
func begin_acquisition(identity: StringName) -> bool:
	if not _depth.begin_acquisition(identity): return false
	_cache.clear()
	_cache_order.clear()
	return true


func reset() -> bool:
	if not _depth.clear_cache(): return false
	_cache.clear()
	_cache_order.clear()
	return true


func cache_statistics() -> Dictionary:
	var result: Dictionary = _depth.cache_statistics()
	result["prepared_section_count"] = _cache.size()
	result["maximum_prepared_sections"] = MAX_PREPARED_CACHE
	return result


func prepare(section: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	var origin := StringName(section.get("origin_id", &""))
	if origin == &"" or origin == &"RL_BoneRoot" or not section.get("center") is Vector2 or not section.center.is_finite():
		return _fail("missing_named_saved_section")
	var identity: Array = [REVISION, origin, section.center]
	for kind: StringName in KINDS:
		var surface: Variant = section.get(kind)
		if not surface is Dictionary or not surface.get("valid", false) or not surface.get("complete", false):
			return _fail("incomplete_saved_section_surface", {"kind":kind})
		if surface.get("origin_id") != origin or not surface.get("polygon") is PackedVector2Array:
			return _fail("saved_section_surface_origin_or_polygon_mismatch", {"kind":kind})
		var source: Variant = surface.get("source_id")
		if not (source is String or source is StringName) or String(source).is_empty():
			return _fail("saved_section_surface_source_missing", {"kind":kind})
		identity.append([kind, source, surface.polygon])
	# Exact bytes, not quantized coordinates or a hash with possible collisions.
	var key := var_to_bytes(identity).hex_encode()
	if _cache.has(key):
		var hit: Dictionary = _cache[key].duplicate(true)
		hit["cache_hit"] = true
		hit["preparation_ms"] = float(Time.get_ticks_usec()-started)/1000.0
		return hit
	var prepared := {"valid":true,"revision":REVISION,"origin_id":origin,"center":section.center,
		"center_origin_id":origin,"metric_units":&"meters","cache_hit":false,
		"wrapper_generated":false,"target_offset_applied":false,"production_pose_written":false}
	for kind: StringName in KINDS:
		var source: Dictionary = section[kind]
		var target := _depth.prepare_ordered_target(source.polygon, origin, StringName(source.source_id), true)
		if not target.get("valid", false): return _fail("saved_section_target_invalid", {"kind":kind,"result":target})
		prepared[kind] = target
	if _cache_order.size() >= MAX_PREPARED_CACHE: _cache.erase(_cache_order.pop_front())
	_cache[key] = prepared.duplicate(true)
	_cache_order.append(key)
	prepared["preparation_ms"] = float(Time.get_ticks_usec()-started)/1000.0
	return prepared


func evaluate(prepared: Dictionary, segments: Array, origin_id: StringName) -> Dictionary:
	var started := Time.get_ticks_usec()
	if not prepared.get("valid", false) or prepared.get("revision") != REVISION or prepared.get("origin_id") != origin_id:
		return _fail("invalid_prepared_saved_wrapper_contact")
	var query_segments: Array = []
	for source: Variant in segments:
		if not source is Dictionary: return _fail("invalid_skin_segment")
		var cap: float = float(source.get("max_inward_depth_m",-1.0))
		if not is_finite(cap) or cap<0.0: return _fail("invalid_skin_segment_or_cap")
		var query: Dictionary = source.duplicate(false)
		if source.get("allowance_unassigned",true): query.max_inward_depth_m=0.0
		query_segments.append(query)
	var material := _depth.evaluate_segments(query_segments, prepared.handle, origin_id, DEPTH_CONFIG)
	if not material.get("valid", false): return _fail("saved_handle_material_measurement_failed", material)
	var material_ms := float(Time.get_ticks_usec()-started)/1000.0
	var guide_started := Time.get_ticks_usec()
	var groups := {&"digit_target":[], &"palm_target":[]}
	var indices := {&"digit_target":[], &"palm_target":[]}
	for index: int in segments.size():
		var kind: StringName = &"palm_target" if segments[index].get("palm_owned", false) else &"digit_target"
		groups[kind].append(query_segments[index])
		indices[kind].append(index)
	var guides: Array = []
	guides.resize(segments.size())
	var guide_evaluations := 0
	for kind: StringName in [&"digit_target", &"palm_target"]:
		if groups[kind].is_empty(): continue
		var result := _depth.evaluate_segments(groups[kind], prepared[kind], origin_id, DEPTH_CONFIG)
		if not result.get("valid", false): return _fail("saved_wrapper_guide_measurement_failed", {"kind":kind,"result":result})
		guide_evaluations += int(result.depth_evaluations)
		for local_index: int in indices[kind].size():
			guides[indices[kind][local_index]] = {"kind":kind,"measurement":result.segments[local_index]}
	var guide_ms := float(Time.get_ticks_usec()-guide_started)/1000.0
	var witnesses_started := Time.get_ticks_usec()
	var records: Array = []
	var unresolved := 0
	var exceeding := 0
	var material_constraint_safe := true
	var guide_constraint_safe := true
	for index: int in segments.size():
		var guide: Dictionary = guides[index]
		var actual: Dictionary = material.segments[index]
		var witness := _witness(segments[index], guide.measurement, prepared[guide.kind])
		var material_witness := _witness(segments[index], actual, prepared.handle)
		if not witness.get("valid", false) or not material_witness.get("valid", false):
			return _fail("saved_contact_witness_invalid", {"index":index,"guide":witness,"material":material_witness})
		unresolved += int(actual.cap_status == &"unresolved")
		exceeding += int(actual.cap_status == &"exceeds")
		var material_exterior := _strictly_exterior(actual)
		var guide_exterior := _strictly_exterior(guide.measurement)
		# Unassigned edges may retain a known contributing bone's numeric cap,
		# but that is not an allowance for the unassigned blend. They require the
		# separate exterior proof, preserving the live controller's zero policy.
		var assigned: bool = not bool(segments[index].get("allowance_unassigned",true))
		var material_edge_safe: bool = (assigned and actual.cap_status == &"within") or material_exterior
		var guide_edge_safe: bool = (assigned and guide.measurement.cap_status == &"within") or guide_exterior
		material_constraint_safe = material_constraint_safe and material_edge_safe
		guide_constraint_safe = guide_constraint_safe and guide_edge_safe
		records.append({"segment":segments[index].duplicate(true),"witness":witness,"guide_kind":guide.kind,
			"guide_gap_m":witness.signed_clearance_m,"guide_cap_status":guide.measurement.cap_status,
			"guide_depth_lower_m":guide.measurement.max_inward_depth_lower_m,
			"guide_depth_upper_m":guide.measurement.max_inward_depth_upper_m,
			"material_witness":material_witness,"material_gap_m":material_witness.signed_clearance_m,
			"material_cap_status":actual.cap_status,"max_inward_depth_m":actual.max_inward_depth_m,
			"source_max_inward_depth_m":segments[index].max_inward_depth_m,
			"material_constraint_safe":material_edge_safe,"guide_constraint_safe":guide_edge_safe,
			"material_strictly_exterior":material_exterior,"guide_strictly_exterior":guide_exterior,
			"depth_lower_m":actual.max_inward_depth_lower_m,"depth_upper_m":actual.max_inward_depth_upper_m,
			"material_budget_exhausted":actual.budget_exhausted,"material_evaluations":actual.depth_evaluations})
	return {"valid":true,"revision":REVISION,"origin_id":origin_id,"segments":records,
		"material_safe":material.all_segments_within_cap,"any_exceeds":exceeding>0,"any_unresolved":unresolved>0,
		"material_constraint_safe":material_constraint_safe,"guide_constraint_safe":guide_constraint_safe,
		"exceeding_segments":exceeding,"unresolved_segments":unresolved,
		"material_depth_evaluations":material.depth_evaluations,"guide_depth_evaluations":guide_evaluations,
		"material_measurement_ms":material_ms,"guide_measurement_ms":guide_ms,
		"witness_normalization_ms":float(Time.get_ticks_usec()-witnesses_started)/1000.0,
		"evaluation_ms":float(Time.get_ticks_usec()-started)/1000.0,
		"metric_units":&"meters","grip_accepted":false,"actual_3d_grip_verified":false,
		"production_pose_written":false,"scope":&"supplied_planar_skin_edges_only"}


func _strictly_exterior(measured: Dictionary) -> bool:
	# Mature Depth splits at every boundary intersection and classifies each
	# resulting interval. No inside interval plus no missing interval certifies
	# its exterior classification; require positive guarded boundary separation
	# too. This never subtracts epsilon from penetration or enlarges a skin cap.
	var contact: Dictionary = measured.contact
	var guard := maxf(float(measured.numeric_epsilon_m),float(contact.numeric_epsilon_m))
	return int(measured.inside_interval_count)==0 and int(measured.unmeasured_interval_count)==0 \
		and float(measured.max_sampled_inward_depth_m)==0.0 and measured.depth_lower_bound_witness.is_empty() \
		and is_finite(float(contact.distance_m)) and float(contact.distance_m)>guard


func _witness(segment: Dictionary, measured: Dictionary, target: Dictionary) -> Dictionary:
	var chosen: Dictionary = measured.contact.duplicate(true)
	var gap: float = float(chosen.distance_m)
	var kind := &"nearest_boundary"
	var lower_witness: Dictionary = measured.depth_lower_bound_witness
	if float(measured.max_sampled_inward_depth_m) > 0.0 and not lower_witness.is_empty():
		chosen = lower_witness.duplicate(true)
		chosen["target_point_m"] = chosen.nearest_target_point_m
		gap = -float(measured.max_sampled_inward_depth_m)
		kind = &"deepest_sampled_inside_lower_bound"
	var index := int(chosen.get("target_edge_index", -1))
	if index < 0 or index >= target.edges.size(): return _fail("witness_edge_missing")
	var edge: Array = target.edges[index]
	var tangent: Vector2 = ((edge[1] as Vector2) - (edge[0] as Vector2)).normalized()
	var outward := Vector2(tangent.y, -tangent.x) * float(target.winding_sign)
	var skin_point: Vector2 = chosen.skin_point_m
	var target_point: Vector2 = chosen.target_point_m
	var parameter := _depth._parameter(skin_point, segment.a, segment.b)
	var epsilon := maxf(float(measured.numeric_epsilon_m), Contact.EPS_M)
	var ties: Array = chosen.get("tied_target_edge_indices", []).duplicate()
	var distance: float = skin_point.distance_to(target_point)
	if kind == &"deepest_sampled_inside_lower_bound":
		ties.clear()
		for candidate: int in target.edges.size():
			var endpoints: Array = target.edges[candidate]
			var nearest := Geometry2D.get_closest_point_to_segment(skin_point,endpoints[0],endpoints[1])
			if absf(skin_point.distance_to(nearest)-distance) <= epsilon: ties.append(candidate)
	var corner: bool = target_point.distance_to(edge[0]) <= epsilon or target_point.distance_to(edge[1]) <= epsilon
	# A vertex has two edge tangents, but at positive distance its point-distance
	# gradient is still unique. Test ties at THIS skin point: global edge/edge
	# nearest ties may refer to different skin points along the same skin edge.
	var gradient_epsilon := maxf(float(measured.numeric_epsilon_m), maxf(float(target.coordinate_scale_m)*0.0000002,0.000000000001))
	var nearest_points: Array[Vector2] = []
	var nearest_normals: Array[Vector2] = []
	for candidate: int in ties:
		var endpoints: Array = target.edges[candidate]
		var nearest := Geometry2D.get_closest_point_to_segment(skin_point,endpoints[0],endpoints[1])
		if absf(skin_point.distance_to(nearest)-distance)>gradient_epsilon: continue
		var already_present := false
		for point: Vector2 in nearest_points:
			if point.distance_to(nearest)<=gradient_epsilon: already_present=true; break
		if not already_present: nearest_points.append(nearest)
		var direction: Vector2 = ((endpoints[1] as Vector2)-(endpoints[0] as Vector2)).normalized()
		nearest_normals.append(Vector2(direction.y,-direction.x)*float(target.winding_sign))
	var gradient := outward
	var gradient_ambiguous := nearest_points.size()!=1
	if distance>gradient_epsilon:
		gradient = (target_point-skin_point).normalized() if gap<0.0 else (skin_point-target_point).normalized()
	else:
		# At contact, collinear subdivisions share one normal. A real corner has
		# multiple normals and must remain an explicitly ambiguous derivative.
		for normal: Vector2 in nearest_normals:
			if normal.distance_to(outward)>0.000001: gradient_ambiguous=true
	return {"valid":true,"source_id":segment.source_id,"origin_id":target.origin_id,
		"target_source_id":target.source_id,"skin_point_m":skin_point,"target_point_m":target_point,
		"skin_segment_t":clampf(parameter,0.0,1.0),"target_edge_index":index,
		"target_outward_normal":gradient,"target_edge_outward_normal":outward,"target_edge_tangent":tangent,
		"signed_clearance_m":gap,"witness_kind":kind,"corner_ambiguous":corner,
		"tied_target_edge_indices":ties,"tangent_ambiguous":corner or ties.size()!=1,
		"gradient_ambiguous":gradient_ambiguous,"gradient_nearest_target_points":nearest_points,
		"numeric_epsilon_m":measured.numeric_epsilon_m,
		"depth_lower_m":measured.max_inward_depth_lower_m,"depth_upper_m":measured.max_inward_depth_upper_m,
		"cap_status":measured.cap_status,"depth_is_bounded_not_exact":true}


func _fail(reason: String, detail: Dictionary = {}) -> Dictionary:
	return {"valid":false,"reason":reason,"detail":detail,"production_pose_written":false,"grip_accepted":false}
