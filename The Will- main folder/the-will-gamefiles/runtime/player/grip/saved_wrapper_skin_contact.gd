extends RefCounted

## Exact saved-section target observation; never builds, offsets or repairs a
## wrapper. Named material geometry remains the authority for every skin cap.
## Geometry2D's native nearest-segment query is used only to identify a selected
## depth witness's feature ambiguity; mature Depth owns contact/depth decisions.
const Depth = preload("res://runtime/player/grip/native_cached_planar_skin_overlap_budget.gd")
const Contact = preload("res://runtime/player/grip/skin_plane_contact_query.gd")
const Chronology = preload("res://runtime/player/grip/grip_chronology.gd")
const REVISION := &"saved_wrapper_skin_contact_v1"
const KINDS: Array[StringName] = [&"handle", &"digit_target", &"palm_target"]
const MAX_PREPARED_CACHE := 64
const DEFAULT_USE_NATIVE := true
const DEFAULT_USE_NATIVE_BATCH := true
# A 0.05 mm bound changed cap decisions and lost a recorded contact. Keep the
# proven 0.01 mm bound; the user's accuracy allowance does not relax skin caps.
const DEPTH_CONFIG := {"max_evaluations_per_segment":64,"depth_bound_tolerance_m":0.00001,"refine_depth_after_cap":false}
var _depth := Depth.new()
var _depth_config: Dictionary = DEPTH_CONFIG.duplicate(true)
var _cache: Dictionary = {}
var _cache_order: Array[String] = []
var _native_batch: RefCounted
var _native_requested := DEFAULT_USE_NATIVE
var _batch_requested := DEFAULT_USE_NATIVE_BATCH
var _acquisition_id := StringName()
var _backend_fallbacks := 0


func _init() -> void:
	if not _select_backend(DEFAULT_USE_NATIVE, DEFAULT_USE_NATIVE_BATCH):
		_backend_fallbacks += 1
		_select_backend(false, false)
		push_warning("Requested grip contact extension unavailable; using the reference evaluator. Fallback usage is recorded in statistics.")


## Configure before acquisition; reset explicitly before changing an existing
## acquisition's backend or tolerance. Defaults use C++ and the proven 0.01 mm.
func configure_evaluation(use_native: bool, depth_tolerance_m: float) -> bool:
	if _acquisition_id != &"" or not is_finite(depth_tolerance_m) or depth_tolerance_m <= 0.0:
		return false
	if not _select_backend(use_native, _batch_requested): return false
	_depth_config["depth_bound_tolerance_m"] = depth_tolerance_m
	return true


## Select before acquisition. The complete batch and old segment adapter are
## exclusive backends; the reference remains available for measured comparisons.
func configure_native_batch(enabled: bool) -> bool:
	if _acquisition_id != &"": return false
	return _select_backend(_native_requested, enabled)


func _select_backend(use_native: bool, use_batch: bool) -> bool:
	var selected: RefCounted
	if use_native and use_batch:
		if not ClassDB.class_exists(&"GripSavedContactKernel"): return false
		selected = ClassDB.instantiate(&"GripSavedContactKernel") as RefCounted
		if selected == null: return false
	if not _depth.configure_native_kernel(use_native and not use_batch): return false
	_native_batch = selected
	_native_requested = use_native
	_batch_requested = use_batch
	_cache.clear()
	_cache_order.clear()
	return true


## One explicit epoch per hand acquisition. Never reset per pose/section query:
## the batch retains exact prepared geometry; the old adapter retains its own
## bounded segment-result cache when explicitly selected.
func begin_acquisition(identity: StringName) -> bool:
	if _native_batch != null:
		if not _native_batch.begin_acquisition(identity): return false
	elif not _depth.begin_acquisition(identity): return false
	_acquisition_id = identity
	_cache.clear()
	_cache_order.clear()
	return true


func reset() -> bool:
	if _native_batch != null:
		if not _native_batch.reset(): return false
	elif not _depth.clear_cache(): return false
	_acquisition_id = &""
	_cache.clear()
	_cache_order.clear()
	return true


func cache_statistics() -> Dictionary:
	var result: Dictionary = _native_batch.statistics() if _native_batch != null else _depth.cache_statistics()
	if _native_batch == null: result["prepared_section_count"] = _cache.size()
	result["native_batch_enabled"] = _native_batch != null
	result["native_batch_requested"] = _native_requested and _batch_requested
	result["backend_selection_fallbacks"] = _backend_fallbacks
	result["contact_backend"] = "cpp" if _native_requested else "gdscript"
	result["maximum_prepared_sections"] = MAX_PREPARED_CACHE
	result["depth_bound_tolerance_m"] = _depth_config.depth_bound_tolerance_m
	return result


func prepare(section: Dictionary) -> Dictionary:
	if _native_batch != null: return _native_batch.prepare(section)
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


## Single point attraction on an already prepared, unchanged saved target.
## Reuse existing nearest-feature/tie normalization; this never certifies a
## section cap, whole-edge depth, material contact or completed grip.
func evaluate_point(segment: Dictionary, t: float, target: Dictionary) -> Dictionary:
	if not target.get("valid", false) or target.get("revision") != _depth.REVISION or not target.get("complete", false):
		return _fail("invalid_prepared_attraction_target")
	if not is_finite(t) or t < 0.0 or t > 1.0: return _fail("invalid_attraction_point_parameter")
	var source: Variant = segment.get("source_id")
	if target.get("origin_id", &"") == &"" or segment.get("origin_id") != target.origin_id or not (source is String or source is StringName) or String(source).is_empty():
		return _fail("missing_or_mismatched_skin_origin_or_source")
	if not segment.get("a") is Vector2 or not segment.get("b") is Vector2: return _fail("missing_skin_endpoints")
	var a: Vector2 = segment.a
	var b: Vector2 = segment.b
	if not a.is_finite() or not b.is_finite() or a == b: return _fail("nonfinite_or_zero_length_skin_segment")
	var point := Vector2(float(a.x) + t * (float(b.x) - float(a.x)), float(a.y) + t * (float(b.y) - float(a.y)))
	var scale_m := maxf(float(target.coordinate_scale_m), maxf(absf(point.x), absf(point.y)))
	var epsilon := maxf(float(_depth_config.get("numeric_epsilon_m", 0.000000001)), maxf(1.0e-12, scale_m * 1.0e-12))
	var intersections: Array[Dictionary] = []
	intersections.resize(target.edges.size()); intersections.fill({})
	var nearest: Dictionary = _depth._nearest_contact(point, point, target, epsilon, intersections, true)
	if not is_finite(float(nearest.get("distance_m", INF))): return _fail("attraction_point_nearest_feature_unavailable")
	var depth: float = nearest.distance_m if Geometry2D.is_point_in_polygon(point, target.polygon) else 0.0
	var lower := {}
	if depth > 0.0:
		lower = {"skin_point_m": point, "nearest_target_point_m": nearest.target_point_m,
			"target_edge_index": nearest.target_edge_index}
	var measured := {"contact": nearest, "numeric_epsilon_m": epsilon, "max_sampled_inward_depth_m": depth,
		"depth_lower_bound_witness": lower, "max_inward_depth_lower_m": depth,
		"max_inward_depth_upper_m": depth, "cap_status": &"not_assessed_attraction_only"}
	var witness := _witness(segment, measured, target)
	if not witness.get("valid", false): return witness
	# Keep the requested parameter, not a round-trip projection of float Vector2.
	witness.skin_segment_t = t
	witness["witness_kind"] = &"caller_selected_point_on_skin_edge"
	witness["attraction_only"] = true
	witness["point_parameter_frozen_for_response"] = true
	witness["depth_is_bounded_not_exact"] = false
	witness["depth_scope"] = &"one_point_only_not_whole_edge_or_skin"
	witness["whole_skin_clearance_verified"] = false
	witness["actual_3d_grip_verified"] = false
	witness["grip_accepted"] = false
	return witness


func evaluate(prepared: Dictionary, segments: Array, origin_id: StringName) -> Dictionary:
	if _native_batch != null:
		var span := Chronology.begin("saved_contact.native_batch", {"plane_origin_id":origin_id,
			"skin_segments":segments.size(),"depth_bound_tolerance_m":_depth_config.depth_bound_tolerance_m}) if Chronology.enabled() else 0
		var result: Dictionary = _native_batch.evaluate(prepared, segments, origin_id, _depth_config)
		if span != 0:
			Chronology.finish(span, {"valid":result.get("valid",false),"reason":result.get("reason",""),
				"material_measurement_ms":result.get("material_measurement_ms",0.0),
				"guide_measurement_ms":result.get("guide_measurement_ms",0.0),
				"witness_normalization_ms":result.get("witness_normalization_ms",0.0),
				"material_depth_evaluations":result.get("material_depth_evaluations",0),
				"guide_depth_evaluations":result.get("guide_depth_evaluations",0),
				"material_constraint_safe":result.get("material_constraint_safe",false),
				"guide_constraint_safe":result.get("guide_constraint_safe",false)})
		return result
	var started := Time.get_ticks_usec()
	if not prepared.get("valid", false) or prepared.get("revision") != REVISION or prepared.get("origin_id") != origin_id:
		return _fail("invalid_prepared_saved_wrapper_contact")
	var query_segments: Array = []
	for source: Variant in segments:
		if not source is Dictionary: return _fail("invalid_skin_segment")
		if source.has("grip_attraction_eligible") and not source.grip_attraction_eligible is bool:
			return _fail("invalid_grip_attraction_eligibility")
		var cap: float = float(source.get("max_inward_depth_m",-1.0))
		if not is_finite(cap) or cap<0.0: return _fail("invalid_skin_segment_or_cap")
		var query: Dictionary = source.duplicate(false)
		if source.get("allowance_unassigned",true): query.max_inward_depth_m=0.0
		query_segments.append(query)
	var material := _depth.evaluate_segments(query_segments, prepared.handle, origin_id, _depth_config)
	if not material.get("valid", false): return _fail("saved_handle_material_measurement_failed", material)
	var material_ms := float(Time.get_ticks_usec()-started)/1000.0
	var guide_started := Time.get_ticks_usec()
	var groups := {&"digit_target":[], &"palm_target":[]}
	var indices := {&"digit_target":[], &"palm_target":[]}
	var guide_segment_count := 0
	for index: int in segments.size():
		# Anatomical attraction eligibility never removes material collision work.
		# Keep one output record per original edge so response indices stay stable.
		if not bool(segments[index].get("grip_attraction_eligible", true)): continue
		var kind: StringName = &"palm_target" if segments[index].get("palm_owned", false) else &"digit_target"
		groups[kind].append(query_segments[index])
		indices[kind].append(index)
		guide_segment_count += 1
	var guides: Array = []
	guides.resize(segments.size())
	var guide_evaluations := 0
	for kind: StringName in [&"digit_target", &"palm_target"]:
		if groups[kind].is_empty(): continue
		var result := _depth.evaluate_segments(groups[kind], prepared[kind], origin_id, _depth_config)
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
		var guide_evaluated: bool = bool(segments[index].get("grip_attraction_eligible", true))
		var guide: Dictionary = guides[index] if guide_evaluated else {}
		var actual: Dictionary = material.segments[index]
		var witness: Dictionary = _witness(segments[index], guide.measurement, prepared[guide.kind]) if guide_evaluated else {}
		var material_witness := _witness(segments[index], actual, prepared.handle)
		if (guide_evaluated and not witness.get("valid", false)) or not material_witness.get("valid", false):
			return _fail("saved_contact_witness_invalid", {"index":index,"guide":witness,"material":material_witness})
		unresolved += int(actual.cap_status == &"unresolved")
		exceeding += int(actual.cap_status == &"exceeds")
		var material_exterior := _strictly_exterior(actual)
		var guide_exterior: bool = _strictly_exterior(guide.measurement) if guide_evaluated else false
		# Unassigned edges may retain a known contributing bone's numeric cap,
		# but that is not an allowance for the unassigned blend. They require the
		# separate exterior proof, preserving the live controller's zero policy.
		var assigned: bool = not bool(segments[index].get("allowance_unassigned",true))
		var material_edge_safe: bool = (assigned and actual.cap_status == &"within") or material_exterior
		var guide_edge_safe: bool = not guide_evaluated or (assigned and guide.measurement.cap_status == &"within") or guide_exterior
		material_constraint_safe = material_constraint_safe and material_edge_safe
		guide_constraint_safe = guide_constraint_safe and guide_edge_safe
		records.append({"segment":segments[index].duplicate(true),"witness":witness,"guide_evaluated":guide_evaluated,
			"guide_kind":guide.kind if guide_evaluated else &"not_evaluated",
			"guide_gap_m":witness.signed_clearance_m if guide_evaluated else INF,
			"guide_cap_status":guide.measurement.cap_status if guide_evaluated else &"not_evaluated",
			"guide_depth_lower_m":guide.measurement.max_inward_depth_lower_m if guide_evaluated else null,
			"guide_depth_upper_m":guide.measurement.max_inward_depth_upper_m if guide_evaluated else null,
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
		"material_segment_count":segments.size(),"guide_evaluated_segment_count":guide_segment_count,
		"guide_skipped_segment_count":segments.size()-guide_segment_count,
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
