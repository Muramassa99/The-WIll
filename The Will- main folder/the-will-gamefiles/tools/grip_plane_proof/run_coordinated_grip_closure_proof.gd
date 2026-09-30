extends "res://tools/grip_plane_proof/diagnose_coherent_grip_placement.gd"

const CandidatePose = preload("res://tools/grip_plane_proof/prepared_hand_candidate_pose.gd")
const DepthBudget = preload("res://tools/grip_plane_proof/planar_skin_overlap_budget.gd")
const DigitRules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const ProfileShape = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const SeatSlice = preload("res://core/resolvers/primary_grip_seat_resolver.gd")

# Isolated Middle/Thumb acquisition experiment. The captured weapon is fixed
# AFTER the existing handle-% positioning. This never applies a candidate pose.
# Skin-weight majority is a trial section attribution, not palm segmentation.
var _candidate_adapter := CandidatePose.new()
var _depth_query := DepthBudget.new()
var _trial_cache: Dictionary = {}
var _trial_count := 0
var _trial_ms := 0.0

func _run() -> void:
	var started := Time.get_ticks_usec()
	var loaded: Dictionary = Store.new().load_matching(Runner.DEFINITION_PATH, Runner.SIGNATURE, "rest_middle_thumb_surface_measurements_v1")
	if not loaded.get("valid", false):
		push_error(str(loaded)); quit(1); return
	var report := {"schema": "coordinated_grip_closure_proof_v1", "cases": [], "failures": [],
		"production_pose_written": false, "actual_3d_grip_verified": false,
		"arm_realization_verified": false, "palm_contact_verified": false,
		"anatomy_recomputed": false, "anatomy_signature": loaded.resource.source_signature,
		"scope": "one_digit_and_shared_skin_observation_with_station_preserving_hand_slide",
		"hand_geometry_governs_wrap": true, "independent_membrane_curvature_implemented": false,
		"closure_guide": "decreasing_radius_soft_target_then_actual_surface_contact",
		"handle_percent_positioning_changed": false}
	var paths := OS.get_environment("THE_WILL_GRIP_PLACEMENT_PATHS").split(";", false)
	if paths.is_empty():
		report.failures.append("missing_explicit_workspace_placement_trace_paths")
	for requested: String in paths:
		var path := requested.replace("\\", "/").simplify_path()
		if not _workspace_trace_path(path):
			report.failures.append("invalid_workspace_trace_path"); continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			report.failures.append("unreadable_trace"); continue
		var trace: Variant = file.get_var(false)
		file.close()
		if not trace is Dictionary or trace.get("schema") != "grip_placement_trace_v1" or not trace.get("valid", false) or not trace.get("validation", {}).get("valid", false) or not trace.get("capture_errors", []).is_empty() or trace.get("anatomy_signature") != loaded.resource.source_signature:
			report.failures.append("invalid_trace"); continue
		var chosen: Dictionary = {}
		for transaction: Dictionary in trace.transactions:
			if transaction.slot == trace.slot and transaction.get("result", {}).get("applied", false) and not transaction.get("finger_inputs", []).is_empty():
				chosen = transaction
		if chosen.is_empty():
			report.failures.append("no_accepted_seat_with_coherent_finger_input"); continue
		var stage: Dictionary = chosen.finger_inputs[chosen.finger_inputs.size() - 1]
		for digit_id: StringName in [&"middle", &"thumb"]:
			var context := _prepare_trial(loaded.resource, chosen, stage, digit_id)
			if not context.get("valid", false):
				report.failures.append({"slot": trace.slot, "digit": digit_id, "details": context}); continue
			var kinds: Array[String] = ["actual", "area_matched_circle", "area_matched_square"]
			if OS.get_environment("THE_WILL_CLOSURE_ACTUAL_ONLY") == "1":
				kinds = ["actual"]
			for kind: String in kinds:
				var result := _run_case(context, kind)
				result["source_trace"] = path
				result["source_trace_sha256"] = FileAccess.get_sha256(path)
				report.cases.append(result)
				if not result.get("valid", false):
					report.failures.append({"slot": trace.slot, "digit": digit_id, "kind": kind, "reason": result.get("reason")})
				print("COORDINATED_CLOSURE_CASE=" + JSON.stringify(_numbers(_case_brief(result))))
	report["ok"] = report.failures.is_empty()
	report["total_diagnostic_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	var path := "C:/WORKSPACE/test_artifacts/coordinated_grip_closure_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write closure report"); quit(1); return
	file.store_string(JSON.stringify(_numbers(report), "\t")); file.close()
	print("COORDINATED_CLOSURE_RESULT=" + path)
	print("COORDINATED_CLOSURE_SUMMARY=" + JSON.stringify({"ok": report.ok, "failures": report.failures, "total_ms": report.total_diagnostic_ms}))
	quit(0 if report.ok else 1)

func _prepare_trial(definition: Resource, transaction: Dictionary, stage: Dictionary, digit_id: StringName) -> Dictionary:
	var started := Time.get_ticks_usec()
	var adapter: Dictionary = _candidate_adapter.prepare(definition, stage.posed_character, transaction.slot, [digit_id])
	if not adapter.get("valid", false): return adapter
	var validation := _measure_stage(HandSkin.new(), adapter.skin_prepared, definition, transaction, stage, &"finger_solve_input")
	if not validation.get("valid", false): return validation
	var input: Dictionary = adapter.digit_inputs[digit_id]
	var plane: Transform3D = input.plane_to_world
	# A fixed measurement frame must not reuse the moving anatomical-plane ID.
	var plane_id := StringName("ClosureFrozenPlane_%s_%s" % [transaction.slot, digit_id])
	var plane_record := {"origin_id": plane_id, "parent_origin_id": &"RL_BoneRoot",
		"transform_to_parent": (stage.posed_character.machine_to_world as Transform3D).affine_inverse() * plane,
		"owner_system": &"coordinated_grip_closure_proof", "resolve_phase": &"editor_preview",
		"space_type": &"bone_frame", "is_dynamic": false}
	var plane_records: Array = stage.posed_character.origin_records.duplicate(true)
	plane_records.append(plane_record)
	var registered: Dictionary = HandSkin.new()._registry(plane_records, &"editor_preview")
	if not registered.get("valid", false): return registered
	var object: Dictionary = stage.object
	var surface := {"valid": true, "triangles_world": (object.mesh_to_world as Transform3D) * (object.local_faces as PackedVector3Array),
		"surface_source_origin_id": object.local_faces_origin_id, "resolved_world_origin_id": &"RL_BoneRoot"}
	var outer_bound := 0.0
	for vertex: Vector3 in surface.triangles_world:
		outer_bound = maxf(outer_bound, vertex.distance_to(plane.origin))
	# Complete slice is used for polygon sign, never to grant unreachable contacts.
	var sliced: Dictionary = Slicer.new().slice(surface, plane, plane_id, outer_bound + 0.0001, 0.0)
	if not sliced.get("valid", false) or sliced.contours.size() != 1 or sliced.counts.segments_clipped != 0 or sliced.counts.open_or_branched_vertices != 0 or sliced.counts.coplanar_triangles != 0:
		return {"valid": false, "reason": "proof_requires_one_complete_uncropped_object_loop", "slice": sliced.get("counts")}
	var polygon: PackedVector2Array = sliced.contours[0].duplicate()
	if polygon.size() > 1 and polygon[0] == polygon[polygon.size() - 1]: polygon.remove_at(polygon.size() - 1)
	var centroid: Dictionary = SeatSlice._calculate_polygon_centroid_state(polygon)
	if not centroid.get("valid", false): return {"valid": false, "reason": "invalid_object_slice_centroid"}
	for end: String in ["start", "end"]:
		if not object.get("primary_grip_span_" + end + "_local") is Vector3 or object.get("primary_grip_span_" + end + "_origin_id") != object.weapon_origin_record.origin_id:
			return {"valid": false, "reason": "missing_same_stage_weapon_span"}
	var axis: Vector3 = (object.weapon_to_world as Transform3D).basis * ((object.primary_grip_span_end_local as Vector3) - (object.primary_grip_span_start_local as Vector3))
	if not axis.is_finite() or axis.length_squared() < 0.000000000001: return {"valid": false, "reason": "invalid_station_axis"}
	axis = axis.normalized()
	var slide: Vector3 = plane.basis.z.cross(axis)
	if slide.length_squared() < 0.00000001:
		slide = plane.basis.x - axis * plane.basis.x.dot(axis)
	if slide.length_squared() < 0.00000001: return {"valid": false, "reason": "no_station_preserving_trial_slide"}
	slide = slide.normalized()
	# One measured direction only in this first proof; no 2D seating or arm claim.
	if absf(slide.dot(plane.basis.z)) > 0.00001 or absf(slide.dot(axis)) > 0.00001:
		return {"valid": false, "reason": "trial_slide_does_not_preserve_both_planes"}
	var template_radius := 0.0
	for point: Vector2 in ProfileShape.get_handle_builder_limit_polygon(): template_radius = maxf(template_radius, point.length())
	var actual_radius := 0.0
	for point: Vector2 in polygon: actual_radius = maxf(actual_radius, point.distance_to(centroid.centroid))
	var radius := maxf(template_radius * 1.3, actual_radius + 0.00001)
	var groups: Dictionary = _prepare_weight_groups(definition.reference_skin, adapter.skin_prepared, input.digit.bone_names)
	var region := _source_region(adapter, definition.reference_skin, input.digit, groups)
	var reach := 0.0
	for length_m: float in input.digit.section_lengths_m: reach += length_m
	return {"valid": true, "adapter": adapter, "digit": digit_id, "slot": transaction.slot, "input": input,
		"plane": plane, "plane_origin_id": plane_id, "plane_origin_records": plane_records,
		"plane_origin_record": plane_record, "region": region, "groups": groups,
		"actual_polygon": polygon, "slice_center_m": centroid.centroid, "slice_area_m2": absf(centroid.area),
		"guide_initial_radius_m": radius, "template_radius_m": template_radius,
		"slide_direction_world": slide, "slide_direction_world_origin_id": &"RL_BoneRoot",
		"station_axis_world": axis, "station_axis_world_origin_id": &"RL_BoneRoot", "reach_m": reach,
		"weapon_to_world": object.weapon_to_world, "weapon_to_world_origin_id": &"RL_BoneRoot",
		"setup_ms": float(Time.get_ticks_usec() - started) / 1000.0}

func _source_region(adapter: Dictionary, reference: Dictionary, digit: Dictionary, groups: Dictionary) -> Dictionary:
	var skin: Dictionary = adapter.skin_prepared
	var names: Array = skin.bind_bone_names
	var section_caps := {}
	var section_targets: Array = []
	var selected_caps: Array = []
	var side_rules: Dictionary = DigitRules.get_surface_solver_side_rules(digit.slot_id)
	var legacy = Spatial.new()
	for rule: Dictionary in side_rules.digits:
		var cap: float = side_rules.max_overlap_meters
		if rule.is_thumb: cap = minf(maxf(cap, rule.section_target_overlaps_meters[1] + Spatial.SECTION_TARGET_TOLERANCE_METERS), Spatial.THUMB_PROXIMAL_MAX_ALLOWED_OVERLAP_METERS)
		for index: int in range(3):
			section_caps[rule.bone_names[index]] = legacy._resolve_serial_section_max_allowed_overlap(rule, index, rule.section_target_overlaps_meters[index], cap)
		if rule.digit_id == digit.digit_id:
			section_targets = rule.section_target_overlaps_meters.duplicate()
			for name: StringName in rule.bone_names: selected_caps.append(section_caps[name])
	var triangles := PackedInt32Array()
	var metadata := {}
	var hand_names: Array = adapter.descendant_bones.keys()
	for triangle: int in range(skin.triangle_count):
		var relevant := false
		var total_max := 0.0
		var cap := INF
		var has_unassigned := false
		for corner: int in range(3):
			var vertex: int = skin.triangle_indices[triangle * 3 + corner]
			var total := 0.0
			for influence: int in range(skin.vertex_offsets[vertex], skin.vertex_offsets[vertex + 1]):
				var name: StringName = names[skin.influence_binds[influence]]
				total += skin.influence_weights[influence]
				relevant = relevant or hand_names.has(name)
				if section_caps.has(name): cap = minf(cap, section_caps[name])
				else: has_unassigned = true
			total_max = maxf(total_max, total)
		if relevant:
			triangles.append(triangle)
			var key := "%d/%d" % [skin.triangle_surface_ids[triangle], skin.triangle_local_ids[triangle]]
			metadata[key] = {"total_weight_upper": total_max, "known_cap_m": cap, "has_unassigned_influences": has_unassigned}
	return {"triangle_ids": triangles, "metadata": metadata, "targets_m": section_targets, "caps_m": selected_caps,
		"scope": "all_source_triangles_with_positive_Hand_or_descendant_influence",
		"section_ownership": "same_bone_strict_majority_of_total_original_weight_at_both_edge_ends",
		"safety_cap_policy": "trial_majority_owned_edge_uses_own_section_cap_other_tissue_uses_minimum_known_cap_or_remains_unassigned"}

func _run_case(context: Dictionary, kind: String) -> Dictionary:
	var polygon: PackedVector2Array = context.actual_polygon.duplicate()
	var center: Vector2 = context.slice_center_m
	if kind == "area_matched_circle":
		polygon.clear()
		var radius := sqrt(context.slice_area_m2 / PI)
		for index: int in range(48): polygon.append(center + Vector2.from_angle(TAU * float(index) / 48.0) * radius)
	elif kind == "area_matched_square":
		var half: float = sqrt(context.slice_area_m2) * 0.5
		polygon = PackedVector2Array([center + Vector2(-half,-half), center + Vector2(half,-half), center + Vector2(half,half), center + Vector2(-half,half)])
	var target: Dictionary = _depth_query.prepare_target(polygon, context.plane_origin_id, StringName("ClosureTrial_" + kind), true)
	if not target.get("valid", false): return {"valid": false, "reason": "target_rejected", "details": target}
	_trial_cache.clear(); _trial_count = 0; _trial_ms = 0.0
	var start := Time.get_ticks_usec()
	var preferred: Array = context.input.snapshot.preferred_angles_rad
	var parameters: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var history: Array = []
	var initial := _trial(context, target, parameters)
	if not initial.get("valid", false): return initial
	var current := initial
	# Fixed work order/budget: decrease the guide radius, update every angle in
	# coordinated proposals, and also allow one joint/placement to redistribute.
	for phase: int in range(5):
		var guide_radius: float = context.guide_initial_radius_m * (1.0 - float(phase + 1) / 5.0)
		for level: int in range(3):
			var best := current
			var step_fraction := 0.25 / pow(2.0, float(level) + floorf(float(phase) / 2.0))
			var directions: Array = [[1,1,1,0],[-1,-1,-1,0],[1,0,0,0],[-1,0,0,0],[0,1,0,0],[0,-1,0,0],[0,0,1,0],[0,0,-1,0],[0,0,0,1],[0,0,0,-1]]
			for direction: Array in directions:
				var values: Array[float] = []
				for index: int in range(3):
					var low: float = context.input.snapshot.min_angles_rad[index]
					var high: float = context.input.snapshot.max_angles_rad[index]
					var sign_close := signf(float(preferred[index]))
					values.append(clampf(float(current.parameters[index]) + float(direction[index]) * sign_close * (high - low) * step_fraction, low, high))
				values.append(clampf(float(current.parameters[3]) + float(direction[3]) * context.guide_initial_radius_m * step_fraction, -context.guide_initial_radius_m, context.guide_initial_radius_m))
				var candidate := _trial(context, target, values)
				if candidate.get("valid", false) and _trial_better(candidate, best, guide_radius, phase): best = candidate
			current = best
		var snapshot := _trial_brief(current)
		snapshot["guide_radius_m"] = guide_radius
		history.append(snapshot)
	var final := _trial(context, target, current.parameters, true)
	var saved_initial := _trial(context, target, initial.parameters, true)
	return {"valid": final.get("valid", false), "slot": context.slot, "digit": context.digit, "kind": kind,
		"initial": saved_initial, "selected": final, "closure_stages": history,
		"target_polygon_m": polygon, "plane_to_world": context.plane, "plane_origin_id": context.plane_origin_id,
		"plane_origin_records": context.plane_origin_records, "machine_to_world": context.adapter.base_packet.machine_to_world,
		"source_stage": "post_existing_surface_seat_finger_input", "initial_pose": "prepared_zero_angles_not_captured_articulation",
		"slice_center_m": center, "slice_center_origin_id": context.plane_origin_id,
		"guide_initial_radius_m": context.guide_initial_radius_m, "template_radius_m": context.template_radius_m,
		"slide_direction_world": context.slide_direction_world, "slide_direction_world_origin_id": &"RL_BoneRoot",
		"station_axis_world": context.station_axis_world, "station_axis_world_origin_id": &"RL_BoneRoot",
		"weapon_to_world": context.weapon_to_world, "weapon_to_world_origin_id": &"RL_BoneRoot",
		"section_targets_m": context.region.targets_m, "section_caps_m": context.region.caps_m,
		"section_ownership": context.region.section_ownership, "safety_cap_policy": context.region.safety_cap_policy,
		"evaluation_count": _trial_count, "candidate_total_ms": _trial_ms, "setup_ms": context.setup_ms,
		"total_search_ms": float(Time.get_ticks_usec() - start) / 1000.0,
		"grip_accepted": false, "palm_contact_verified": false, "arm_realization_verified": false,
		"actual_3d_grip_verified": false, "production_pose_written": false,
		"termination": "deterministic_staged_search_budget_not_proof_of_optimum_or_infeasibility"}

func _trial(context: Dictionary, target: Dictionary, parameters: Array, keep_geometry: bool = false) -> Dictionary:
	var cache_key := var_to_bytes(parameters).hex_encode()
	if not keep_geometry and _trial_cache.has(cache_key): return _trial_cache[cache_key]
	var started := Time.get_ticks_usec()
	var angles: Array[float] = [parameters[0], parameters[1], parameters[2]]
	var translation: Vector3 = context.slide_direction_world * float(parameters[3])
	var candidate: Dictionary = _candidate_adapter.evaluate(context.adapter, {context.digit: angles}, translation, &"RL_BoneRoot")
	if not candidate.get("valid", false): return candidate
	var skin: Dictionary = context.adapter.skin_prepared
	var slice_started := Time.get_ticks_usec()
	var query := {"plane_to_world": context.plane, "plane_origin_id": context.plane_origin_id,
		"triangle_indices": skin.triangle_indices, "triangle_surface_ids": skin.triangle_surface_ids,
		"triangle_local_ids": skin.triangle_local_ids, "selected_weights": context.groups.weights,
		"bone_ids": context.input.digit.bone_names}
	var sliced: Array = SkinQuery.new()._slice_triangles(query, candidate.posed.vertices_world, context.region.triangle_ids, true)
	var slice_ms := float(Time.get_ticks_usec() - slice_started) / 1000.0
	var segments: Array[Dictionary] = []
	var owned: Array = [[], [], []]
	var unassigned_count := 0
	var root_world: Vector3 = candidate.digit_states[context.digit].joint_origins_world[0]
	var root_local: Vector3 = (context.plane as Transform3D).affine_inverse() * root_world
	var reach_center := Vector2(root_local.x, root_local.y)
	for original: Dictionary in sliced:
		var key := "%d/%d" % [original.surface_index, original.surface_triangle_index]
		var meta: Dictionary = context.region.metadata[key]
		var edge := original.duplicate()
		edge["source_id"] = key
		edge["max_inward_depth_m"] = meta.known_cap_m if is_finite(meta.known_cap_m) else 0.0
		edge["allowance_unassigned"] = not is_finite(meta.known_cap_m) or meta.has_unassigned_influences
		edge["section_owner"] = -1
		for section: int in range(3):
			if 2.0 * float(edge.a_selected_weights[section]) > meta.total_weight_upper + 0.0000001 and 2.0 * float(edge.b_selected_weights[section]) > meta.total_weight_upper + 0.0000001:
				edge.section_owner = section
				edge.max_inward_depth_m = context.region.caps_m[section]
				edge.allowance_unassigned = false
				edge["allowance_assignment_is_trial"] = true
				owned[section].append(segments.size())
		unassigned_count += int(edge.allowance_unassigned)
		segments.append(edge)
	var depth_started := Time.get_ticks_usec()
	var measured: Dictionary = _depth_query.evaluate_segments(segments, target, context.plane_origin_id,
		{"max_evaluations_per_segment": 96, "depth_bound_tolerance_m": 0.00001, "refine_depth_after_cap": true})
	var depth_ms := float(Time.get_ticks_usec() - depth_started) / 1000.0
	if not measured.get("valid", false): return {"valid": false, "reason": "candidate_depth_query_failed", "details": measured}
	var regions: Array = []
	var total_error := 0.0
	var excess := 0.0
	var unknown_depth := 0.0
	var unknown_depth_upper := 0.0
	var unresolved := 0
	var exceeding := 0
	var missing_required := 0
	var guide_points: Array[Vector2] = []
	for index: int in range(segments.size()):
		var record: Dictionary = measured.segments[index]
		if segments[index].allowance_unassigned:
			unknown_depth = maxf(unknown_depth, float(record.max_inward_depth_lower_m))
			unknown_depth_upper = maxf(unknown_depth_upper, float(record.max_inward_depth_upper_m))
		else:
			excess = maxf(excess, maxf(float(record.max_inward_depth_lower_m) - float(segments[index].max_inward_depth_m), 0.0))
			unresolved += int(record.cap_status == "unresolved")
			exceeding += int(record.cap_status == "exceeds")
	for section: int in range(3):
		var nearest := INF
		var depth := 0.0
		var depth_upper := 0.0
		var chosen_point := Vector2.INF
		var section_cap_ok := true
		var reachable_count := 0
		var gap_epsilon := 0.0
		for index: int in owned[section]:
			var record: Dictionary = measured.segments[index]
			section_cap_ok = section_cap_ok and record.cap_status == "within" and not segments[index].allowance_unassigned
			# Whole-loop geometry classifies solid depth, but only a witness within
			# measured digit reach may attract this digit. No infinite-range target.
			var witness: Dictionary = record.depth_lower_bound_witness
			if not witness.is_empty() and (witness.nearest_target_point_m as Vector2).distance_to(reach_center) <= context.reach_m:
				depth = maxf(depth, float(record.max_inward_depth_lower_m))
				depth_upper = maxf(depth_upper, float(record.max_inward_depth_upper_m))
			if (record.contact.target_point_m as Vector2).distance_to(reach_center) <= context.reach_m:
				reachable_count += 1
				if float(record.contact.distance_m) < nearest:
					nearest = record.contact.distance_m
					chosen_point = record.contact.skin_point_m
					gap_epsilon = record.contact.numeric_epsilon_m
		var contact_lo := depth if depth_upper > 0.0 else -nearest - gap_epsilon
		var contact_hi := depth_upper if depth_upper > 0.0 else -maxf(nearest - gap_epsilon, 0.0)
		var error: float = maxf(absf(contact_lo - float(context.region.targets_m[section])), absf(contact_hi - float(context.region.targets_m[section]))) if is_finite(contact_lo) else context.guide_initial_radius_m
		# Preserve the existing Thumb1 exemption from required contact.
		var contact_required: bool = not (context.digit == &"thumb" and section == 0)
		missing_required += int(contact_required and reachable_count == 0 and depth_upper == 0.0)
		if contact_required: total_error += error
		if chosen_point.is_finite(): guide_points.append(chosen_point)
		regions.append({"section": section + 1, "owned_segments": owned[section].size(), "nearest_gap_m": nearest,
			"depth_lower_m": depth, "depth_upper_m": depth_upper,
			"target_error_upper_m": error, "contact_required": contact_required,
			"reachable_contact_witness_count": reachable_count, "section_cap_verified": section_cap_ok and not owned[section].is_empty(),
			"cap_verification_scope": "provisional_majority_owned_planar_edges_only",
			"source_ownership_is_trial": true})
	var result := {"valid": true, "parameters": parameters.duplicate(), "angles_rad": angles,
		"translation_world": translation, "translation_world_origin_id": &"RL_BoneRoot",
		"axial_translation_m": translation.dot(context.station_axis_world), "regions": regions,
		"target_error_upper_sum_m": total_error, "known_excess_depth_lower_m": excess,
		"unassigned_skin_depth_lower_m": unknown_depth, "unassigned_segment_count": unassigned_count,
		"unassigned_skin_depth_upper_m": unknown_depth_upper, "missing_required_contact_regions": missing_required,
		"unresolved_known_segment_count": unresolved, "exceeding_known_segment_count": exceeding, "guide_points_m": guide_points,
		"slice_center_m": context.slice_center_m, "reach_center_m": reach_center, "reach_m": context.reach_m,
		"guide_points_origin_id": context.plane_origin_id,
		"candidate_pose_ms": candidate.get("evaluation_ms"), "affected_vertex_count": candidate.get("affected_vertex_count"),
		"skin_slice_ms": slice_ms, "depth_query_ms": depth_ms, "depth_evaluations": measured.depth_evaluations,
		"all_contributors_preserved": true, "grip_accepted": false}
	if keep_geometry:
		result["skin_segments"] = segments
		result["depth_measurements"] = measured
		result["pose_id"] = candidate.pose_packet.pose_id
		var records: Array = candidate.pose_packet.origin_records.duplicate(true)
		records.append(context.plane_origin_record)
		result["pose_origin_records"] = records
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	result["trial_ms"] = elapsed
	_trial_count += 1; _trial_ms += elapsed
	if not keep_geometry: _trial_cache[cache_key] = result
	return result

func _trial_better(a: Dictionary, b: Dictionary, radius: float, phase: int) -> bool:
	# Feasibility evidence before contact attraction. Unassigned shared tissue is
	# an observation penalty only, not an invented zero-overlap acceptance rule.
	var a_excess: float = a.known_excess_depth_lower_m
	var b_excess: float = b.known_excess_depth_lower_m
	if absf(a_excess - b_excess) > 0.000001: return a_excess < b_excess
	if a.exceeding_known_segment_count != b.exceeding_known_segment_count: return a.exceeding_known_segment_count < b.exceeding_known_segment_count
	if a.unresolved_known_segment_count != b.unresolved_known_segment_count: return a.unresolved_known_segment_count < b.unresolved_known_segment_count
	if a.missing_required_contact_regions != b.missing_required_contact_regions: return a.missing_required_contact_regions < b.missing_required_contact_regions
	var a_score: float = a.target_error_upper_sum_m + a.unassigned_skin_depth_upper_m
	var b_score: float = b.target_error_upper_sum_m + b.unassigned_skin_depth_upper_m
	if phase < 4:
		for point: Vector2 in a.guide_points_m: a_score += maxf(point.distance_to(a.slice_center_m) - radius, 0.0) * 0.1
		for point: Vector2 in b.guide_points_m: b_score += maxf(point.distance_to(b.slice_center_m) - radius, 0.0) * 0.1
	return a_score < b_score - 0.0000001

func _trial_brief(value: Dictionary) -> Dictionary:
	var result := value.duplicate()
	for key: String in ["skin_segments", "depth_measurements", "pose_origin_records"]: result.erase(key)
	return result

func _case_brief(value: Dictionary) -> Dictionary:
	return {"valid": value.get("valid"), "slot": value.get("slot"), "digit": value.get("digit"), "kind": value.get("kind"),
		"reason": value.get("reason"), "evaluations": value.get("evaluation_count"), "total_ms": value.get("total_search_ms"),
		"initial": _trial_brief(value.get("initial", {})), "selected": _trial_brief(value.get("selected", {}))}
