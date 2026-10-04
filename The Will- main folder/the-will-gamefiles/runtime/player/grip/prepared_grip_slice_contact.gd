extends RefCounted

const SkinQuery = preload("res://runtime/player/grip/weighted_skin_plane_slicer.gd")
const HandSkin = preload("res://runtime/player/grip/prepared_hand_skin_query.gd")
const DepthBudget = preload("res://runtime/player/grip/planar_skin_overlap_budget.gd")
const DigitRules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const Spatial = preload("res://runtime/player/player_finger_surface_grip_solver.gd")
const ContactPreference = preload("res://runtime/player/grip/skin_section_contact_preference.gd")
const GrippingSurface = preload("res://runtime/player/grip/prepared_digit_gripping_surface.gd")
const REVISION: StringName = &"prepared_grip_slice_contact_v1"
const ROOT: StringName = &"RL_BoneRoot"
const FRAME_EPSILON: float = 0.000005

var _skin_query: RefCounted = SkinQuery.new()
var _depth_query: RefCounted = DepthBudget.new()


## Pure observation extracted from run_coordinated_grip_closure_proof. Prepare
## once per selected digit; a caller may observe one combined candidate in both
## planes. No anatomy measurement, candidate pose generation or scene writes.
## Source-weight majority and recovered overlap allowances remain trial policy.
func prepare(adapter: Dictionary, digit_id: StringName) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	if not bool(adapter.get("valid", false)) or adapter.get("revision") != &"prepared_hand_candidate_pose_v1":
		return _fail("invalid_prepared_candidate_adapter")
	if not adapter.get("digit_inputs") is Dictionary or not adapter.digit_inputs.has(digit_id):
		return _fail("missing_prepared_digit_input")
	var input: Dictionary = adapter.digit_inputs[digit_id]
	var digit: Dictionary = input.digit
	var skin: Dictionary = adapter.skin_prepared
	if not bool(input.get("valid", false)) or not bool(skin.get("valid", false)) or skin.get("revision") != HandSkin.REVISION:
		return _fail("invalid_prepared_digit_or_coherent_skin")
	if digit.get("digit_id") != digit_id or digit.get("slot_id") != adapter.get("slot") or digit.bone_names.size() != 3:
		return _fail("prepared_digit_identity_mismatch")
	if skin.get("anatomy_signature") != adapter.get("anatomy_signature"):
		return _fail("prepared_skin_anatomy_mismatch")
	var names: Array = skin.bind_bone_names
	var selected_names: Array = digit.bone_names
	var weights: PackedVector3Array = PackedVector3Array()
	var preference_hand_weights := PackedFloat64Array()
	# HandSkin keeps every positive source influence in its original slot order.
	# These are three scalar weights, not spatial vectors, and are not normalized.
	for vertex: int in range(skin.vertex_count):
		var selected: Vector3 = Vector3.ZERO
		var hand_weight := 0.0
		for influence: int in range(skin.vertex_offsets[vertex], skin.vertex_offsets[vertex + 1]):
			var bone_name: StringName = names[skin.influence_binds[influence]]
			var joint: int = selected_names.find(bone_name)
			if joint >= 0:
				selected[joint] += float(skin.influence_weights[influence])
			if bone_name == adapter.hand_bone_name:
				hand_weight += float(skin.influence_weights[influence])
		weights.append(selected)
		preference_hand_weights.append(hand_weight)
	var section_caps: Dictionary = {}
	var section_targets: Array = []
	var selected_caps: Array = []
	var side_rules: Dictionary = DigitRules.get_surface_solver_side_rules(digit.slot_id)
	var legacy: RefCounted = Spatial.new()
	for rule: Dictionary in side_rules.digits:
		var cap: float = side_rules.max_overlap_meters
		if rule.is_thumb:
			cap = minf(maxf(cap, rule.section_target_overlaps_meters[1] + Spatial.SECTION_TARGET_TOLERANCE_METERS), Spatial.THUMB_PROXIMAL_MAX_ALLOWED_OVERLAP_METERS)
		for index: int in range(3):
			section_caps[rule.bone_names[index]] = legacy._resolve_serial_section_max_allowed_overlap(rule, index, rule.section_target_overlaps_meters[index], cap)
		if rule.digit_id == digit.digit_id:
			if rule.bone_names != digit.bone_names:
				return _fail("recovered_rule_bones_do_not_match_prepared_digit")
			section_targets = rule.section_target_overlaps_meters.duplicate()
			for name: StringName in rule.bone_names:
				selected_caps.append(section_caps[name])
	if section_targets.size() != 3 or selected_caps.size() != 3:
		return _fail("missing_recovered_section_targets_or_caps")
	var triangles: PackedInt32Array = PackedInt32Array()
	var metadata: Dictionary = {}
	var foreign_collision_sources: Dictionary = {}
	var hand_names: Array = adapter.descendant_bones.keys()
	for triangle: int in range(skin.triangle_count):
		var relevant: bool = false
		var total_max: float = 0.0
		var cap: float = INF
		var has_unassigned: bool = false
		# Vector3 contains three original corner WEIGHTS, not a spatial point.
		var foreign_corner_weights: Dictionary = {}
		var vertex_indices: PackedInt32Array = PackedInt32Array()
		for corner: int in range(3):
			var vertex: int = skin.triangle_indices[triangle * 3 + corner]
			vertex_indices.append(vertex)
			var total: float = 0.0
			for influence: int in range(skin.vertex_offsets[vertex], skin.vertex_offsets[vertex + 1]):
				var name: StringName = names[skin.influence_binds[influence]]
				total += skin.influence_weights[influence]
				relevant = relevant or hand_names.has(name)
				if section_caps.has(name):
					cap = minf(cap, section_caps[name])
					if not selected_names.has(name):
						var corner_weights: Vector3 = foreign_corner_weights.get(name, Vector3.ZERO)
						corner_weights[corner] += float(skin.influence_weights[influence])
						foreign_corner_weights[name] = corner_weights
				else:
					has_unassigned = true
			total_max = maxf(total_max, total)
		if relevant:
			triangles.append(triangle)
			var key: String = "%d/%d" % [skin.triangle_surface_ids[triangle], skin.triangle_local_ids[triangle]]
			metadata[key] = {"total_weight_upper": total_max, "known_cap_m": cap, "has_unassigned_influences": has_unassigned}
			if not foreign_corner_weights.is_empty():
				foreign_collision_sources[key] = {"vertex_indices": vertex_indices,
					"section_corner_weights": foreign_corner_weights}
	var reach: float = 0.0
	for length_m: float in digit.section_lengths_m:
		if not is_finite(length_m) or length_m <= 0.0:
			return _fail("invalid_prepared_digit_reach")
		reach += length_m
	if not is_finite(reach) or reach <= 0.0 or triangles.is_empty():
		return _fail("missing_hand_source_triangles_or_digit_reach")
	var gripping_surface := GrippingSurface.new().prepare(adapter, digit_id)
	if not gripping_surface.get("valid", false): return gripping_surface
	return {"valid": true, "revision": REVISION, "digit_id": digit_id, "digit": digit_id, "slot": adapter.slot,
		"anatomy_signature": adapter.anatomy_signature, "source_pose_id": adapter.base_packet.pose_id,
		"resolve_phase": adapter.base_packet.resolve_phase, "machine_to_world": adapter.base_packet.machine_to_world,
		"bone_ids": selected_names.duplicate(), "vertex_count": skin.vertex_count,
		"triangle_indices": skin.triangle_indices.duplicate(), "triangle_surface_ids": skin.triangle_surface_ids.duplicate(),
		"triangle_local_ids": skin.triangle_local_ids.duplicate(), "selected_weights": weights,
		"preference_hand_weights": preference_hand_weights,
		"preference_vertex_aliases": skin.get("preference_vertex_aliases", PackedInt32Array()),
		"gripping_surface": gripping_surface,
		"triangle_ids": triangles, "metadata": metadata, "targets_m": section_targets, "caps_m": selected_caps,
		"foreign_collision_sources": foreign_collision_sources, "collision_section_caps_m": section_caps,
		"reach_m": reach, "scope": "all_source_triangles_with_positive_Hand_or_descendant_influence",
		"section_ownership": "same_bone_strict_majority_of_total_original_weight_at_both_edge_ends",
		"safety_cap_policy": "trial_majority_owned_edge_uses_own_section_cap_other_tissue_uses_minimum_known_cap_or_remains_unassigned",
		"foreign_collision_cap_policy": "same_foreign_bone_strict_majority_at_both_slice_endpoints_uses_its_existing_cap_without_attraction",
		"weights_normalized_by_tool": false, "anatomy_recomputed": false,
		"preparation_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"actual_3d_grip_verified": false, "grip_accepted": false}


## guide_radius_m is the original guide radius used as the old missing-contact
## error fallback. The optimizer's current shrinking guide remains caller-owned.
## Every supplied plane must resolve from the same candidate's origin registry.
## A frozen comparison plane is valid only when its explicit record was added.
## Optional contact_target changes attraction only; target remains the actual
## material for the original cap aggregates and depth_measurements. Both queries
## observe exactly the same skin slice and retain the same recovered allowances.
func evaluate(prepared: Dictionary, candidate: Dictionary, plane_to_world: Transform3D, plane_origin_id: StringName, target: Dictionary, guide_radius_m: float, keep_geometry: bool = false, contact_target: Dictionary = {}) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	if not bool(prepared.get("valid", false)) or prepared.get("revision") != REVISION:
		return _fail("invalid_prepared_slice_contact")
	if plane_origin_id == StringName() or plane_origin_id == ROOT or target.get("origin_id") != plane_origin_id:
		return _fail("missing_or_mismatched_plane_origin")
	var has_contact_target: bool = not contact_target.is_empty()
	if has_contact_target:
		if not bool(contact_target.get("valid", false)) or contact_target.get("revision") != DepthBudget.REVISION or not bool(contact_target.get("complete", false)) or contact_target.get("metric_units") != &"meters":
			return _fail("invalid_prepared_contact_target")
		var contact_source: Variant = contact_target.get("source_id")
		if contact_target.get("origin_id") != plane_origin_id or not (contact_source is String or contact_source is StringName) or String(contact_source).is_empty():
			return _fail("missing_or_mismatched_contact_target_origin_or_source")
		if not contact_target.get("polygon") is PackedVector2Array or not contact_target.get("edges") is Array or not contact_target.get("edge_bounds") is Array or contact_target.polygon.size() < 3 or contact_target.edges.size() != contact_target.polygon.size() or contact_target.edge_bounds.size() != contact_target.edges.size():
			return _fail("incomplete_prepared_contact_target_geometry")
		for field: String in ["coordinate_scale_m", "diameter_upper_m", "winding_sign"]:
			var value: Variant = contact_target.get(field)
			if not (value is float or value is int) or not is_finite(float(value)):
				return _fail("invalid_prepared_contact_target_metric", {"field": field})
		if contact_target.coordinate_scale_m < 0.0 or contact_target.diameter_upper_m <= 0.0 or absf(float(contact_target.winding_sign)) != 1.0:
			return _fail("invalid_prepared_contact_target_metric")
	if not _metric_plane(plane_to_world) or not is_finite(guide_radius_m) or guide_radius_m < 0.0:
		return _fail("invalid_metric_plane_or_guide_radius")
	var candidate_slice: Dictionary = slice_candidate(prepared, candidate, plane_to_world, plane_origin_id)
	if not bool(candidate_slice.get("valid", false)):
		return candidate_slice
	var packet: Dictionary = candidate_slice.pose_packet
	var state: Dictionary = candidate_slice.digit_state
	var digit_id: StringName = candidate_slice.digit_id
	var segments: Array[Dictionary] = candidate_slice.segments
	var owned: Array = candidate_slice.owned
	var unassigned_count: int = candidate_slice.unassigned_segment_count
	var reach_center: Vector2 = candidate_slice.reach_center_m
	var validation_ms: float = candidate_slice.plane_origin_validation_ms
	var slice_ms: float = candidate_slice.skin_slice_ms
	var depth_started: int = Time.get_ticks_usec()
	var measured: Dictionary = _depth_query.evaluate_segments(segments, target, plane_origin_id,
		{"max_evaluations_per_segment": 96, "depth_bound_tolerance_m": 0.00001, "refine_depth_after_cap": true})
	var depth_ms: float = float(Time.get_ticks_usec() - depth_started) / 1000.0
	if not bool(measured.get("valid", false)):
		return _fail("candidate_depth_query_failed", measured)
	var contact_measured: Dictionary = measured
	var contact_depth_ms: float = 0.0
	if has_contact_target:
		var contact_depth_started: int = Time.get_ticks_usec()
		contact_measured = _depth_query.evaluate_segments(segments, contact_target, plane_origin_id,
			{"max_evaluations_per_segment": 96, "depth_bound_tolerance_m": 0.00001, "refine_depth_after_cap": true})
		contact_depth_ms = float(Time.get_ticks_usec() - contact_depth_started) / 1000.0
		if not bool(contact_measured.get("valid", false)):
			return _fail("candidate_contact_depth_query_failed", contact_measured)
	var regions: Array = []
	var total_error: float = 0.0
	var excess: float = 0.0
	var unknown_depth: float = 0.0
	var unknown_depth_upper: float = 0.0
	var unresolved: int = 0
	var exceeding: int = 0
	var missing_required: int = 0
	var contact_excess: float = 0.0
	var contact_unknown_depth: float = 0.0
	var contact_unknown_depth_upper: float = 0.0
	var contact_unresolved: int = 0
	var contact_exceeding: int = 0
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
		if has_contact_target:
			var contact_record: Dictionary = contact_measured.segments[index]
			if segments[index].allowance_unassigned:
				contact_unknown_depth = maxf(contact_unknown_depth, float(contact_record.max_inward_depth_lower_m))
				contact_unknown_depth_upper = maxf(contact_unknown_depth_upper, float(contact_record.max_inward_depth_upper_m))
			else:
				contact_excess = maxf(contact_excess, maxf(float(contact_record.max_inward_depth_lower_m) - float(segments[index].max_inward_depth_m), 0.0))
				contact_unresolved += int(contact_record.cap_status == "unresolved")
				contact_exceeding += int(contact_record.cap_status == "exceeds")
	for section: int in range(3):
		var nearest: float = INF
		var depth: float = 0.0
		var depth_upper: float = 0.0
		var chosen_point: Vector2 = Vector2.INF
		var section_cap_ok: bool = true
		var reachable_count: int = 0
		var gap_epsilon: float = 0.0
		var material_nearest: float = INF
		var material_depth: float = 0.0
		var material_depth_upper: float = 0.0
		var material_reachable_count: int = 0
		var material_section_cap_ok: bool = true
		for index: int in owned[section]:
			var record: Dictionary = contact_measured.segments[index]
			section_cap_ok = section_cap_ok and record.cap_status == "within" and not segments[index].allowance_unassigned
			if has_contact_target:
				material_section_cap_ok = material_section_cap_ok and measured.segments[index].cap_status == "within" and not segments[index].allowance_unassigned
			if not segments[index].get("grip_attraction_eligible", true): continue
			# Keep whole-loop depth classification, but only reachable witnesses
			# attract the selected digit. No contour crop or infinite-range target.
			var witness: Dictionary = record.depth_lower_bound_witness
			if not witness.is_empty() and (witness.nearest_target_point_m as Vector2).distance_to(reach_center) <= prepared.reach_m:
				depth = maxf(depth, float(record.max_inward_depth_lower_m))
				depth_upper = maxf(depth_upper, float(record.max_inward_depth_upper_m))
			if (record.contact.target_point_m as Vector2).distance_to(reach_center) <= prepared.reach_m:
				reachable_count += 1
				if float(record.contact.distance_m) < nearest:
					nearest = record.contact.distance_m
					chosen_point = record.contact.skin_point_m
					gap_epsilon = record.contact.numeric_epsilon_m
			if has_contact_target:
				var material_record: Dictionary = measured.segments[index]
				material_section_cap_ok = material_section_cap_ok and material_record.cap_status == "within" and not segments[index].allowance_unassigned
				var material_witness: Dictionary = material_record.depth_lower_bound_witness
				if not material_witness.is_empty() and (material_witness.nearest_target_point_m as Vector2).distance_to(reach_center) <= prepared.reach_m:
					material_depth = maxf(material_depth, float(material_record.max_inward_depth_lower_m))
					material_depth_upper = maxf(material_depth_upper, float(material_record.max_inward_depth_upper_m))
				if (material_record.contact.target_point_m as Vector2).distance_to(reach_center) <= prepared.reach_m:
					material_reachable_count += 1
					material_nearest = minf(material_nearest, float(material_record.contact.distance_m))
		var contact_lo: float = depth if depth_upper > 0.0 else -nearest - gap_epsilon
		var contact_hi: float = depth_upper if depth_upper > 0.0 else -maxf(nearest - gap_epsilon, 0.0)
		var error: float = maxf(absf(contact_lo - float(prepared.targets_m[section])), absf(contact_hi - float(prepared.targets_m[section]))) if is_finite(contact_lo) else guide_radius_m
		var contact_required: bool = not (digit_id == &"thumb" and section == 0)
		missing_required += int(contact_required and reachable_count == 0 and depth_upper == 0.0)
		if contact_required:
			total_error += error
		if chosen_point.is_finite():
			guide_points.append(chosen_point)
		regions.append({"section": section + 1, "owned_segments": owned[section].size(), "nearest_gap_m": nearest,
			"depth_lower_m": depth, "depth_upper_m": depth_upper,
			"target_error_upper_m": error, "contact_required": contact_required,
			"reachable_contact_witness_count": reachable_count, "section_cap_verified": section_cap_ok and not owned[section].is_empty(),
			"cap_verification_scope": "provisional_majority_owned_planar_edges_only", "source_ownership_is_trial": true})
		if has_contact_target:
			regions[-1]["contact_target_kind"] = &"separate_contact_envelope"
			regions[-1]["raw_material_nearest_gap_m"] = material_nearest
			regions[-1]["raw_material_depth_lower_m"] = material_depth
			regions[-1]["raw_material_depth_upper_m"] = material_depth_upper
			regions[-1]["raw_material_reachable_contact_witness_count"] = material_reachable_count
			regions[-1]["raw_material_section_cap_verified"] = material_section_cap_ok and not owned[section].is_empty()
			regions[-1]["raw_material_measurement_scope"] = &"same_reach_filtered_owned_edges_as_contact_regions"
	var result: Dictionary = {"valid": true, "revision": REVISION, "digit": digit_id, "slot": prepared.slot,
		"pose_id": packet.pose_id, "plane_origin_id": plane_origin_id, "angles_rad": state.angles_rad.duplicate(),
		"translation_world": candidate.translation_world, "translation_world_origin_id": ROOT,
		"regions": regions, "target_error_upper_sum_m": total_error, "known_excess_depth_lower_m": excess,
		"unassigned_skin_depth_lower_m": unknown_depth, "unassigned_segment_count": unassigned_count,
		"unassigned_skin_depth_upper_m": unknown_depth_upper, "missing_required_contact_regions": missing_required,
		"unresolved_known_segment_count": unresolved, "exceeding_known_segment_count": exceeding,
		"guide_points_m": guide_points, "guide_points_origin_id": plane_origin_id,
		"reach_center_m": reach_center, "reach_m": prepared.reach_m,
		"candidate_pose_ms": candidate.get("evaluation_ms"), "affected_vertex_count": candidate.get("affected_vertex_count"),
		"plane_origin_validation_ms": validation_ms, "skin_slice_ms": slice_ms, "depth_query_ms": depth_ms,
		"depth_evaluations": measured.depth_evaluations, "all_contributors_preserved": true,
		"anatomy_recomputed": false, "production_pose_written": false, "palm_contact_verified": false,
		"arm_realization_verified": false, "actual_3d_grip_verified": false, "grip_accepted": false}
	if has_contact_target:
		result["contact_target_kind"] = &"separate_contact_envelope"
		result["contact_target_source_id"] = contact_target.source_id
		result["contact_known_excess_depth_lower_m"] = contact_excess
		result["contact_exceeding_known_segment_count"] = contact_exceeding
		result["contact_unresolved_known_segment_count"] = contact_unresolved
		result["contact_unassigned_skin_depth_lower_m"] = contact_unknown_depth
		result["contact_unassigned_skin_depth_upper_m"] = contact_unknown_depth_upper
		result["contact_depth_query_ms"] = contact_depth_ms
		result["contact_depth_evaluations"] = contact_measured.depth_evaluations
		result["material_depth_measurements_preserved"] = true
	if keep_geometry:
		result["skin_segments"] = segments
		result["depth_measurements"] = measured
		result["pose_origin_records"] = packet.origin_records.duplicate(true)
		if has_contact_target:
			result["contact_depth_measurements"] = contact_measured
			result["contact_target_polygon_m"] = contact_target.polygon.duplicate()
	result["observation_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	return result


## One authoritative coherent-skin slicing path, independent of target geometry.
## Retains source weights, trial section ownership, allowance assignment, and the
## candidate's named plane. It observes without changing candidate or anatomy.
func slice_candidate(prepared: Dictionary, candidate: Dictionary, plane_to_world: Transform3D, plane_origin_id: StringName) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	if not bool(prepared.get("valid", false)) or prepared.get("revision") != REVISION:
		return _fail("invalid_prepared_slice_contact")
	if plane_origin_id == StringName() or plane_origin_id == ROOT:
		return _fail("missing_or_mismatched_plane_origin")
	if not _metric_plane(plane_to_world):
		return _fail("invalid_metric_plane")
	if not bool(candidate.get("valid", false)) or not candidate.get("posed") is Dictionary or not candidate.get("pose_packet") is Dictionary or not candidate.get("digit_states") is Dictionary:
		return _fail("invalid_coherent_candidate")
	var posed: Dictionary = candidate.posed
	var packet: Dictionary = candidate.pose_packet
	var digit_id: StringName = prepared.digit_id
	if not candidate.digit_states.has(digit_id):
		return _fail("candidate_missing_selected_digit")
	var state: Dictionary = candidate.digit_states[digit_id]
	if packet.get("source_pose_id") != prepared.source_pose_id or packet.get("anatomy_signature") != prepared.anatomy_signature or posed.get("anatomy_signature") != prepared.anatomy_signature:
		return _fail("candidate_source_or_anatomy_mismatch")
	if not bool(posed.get("valid", false)) or packet.get("pose_id") != posed.get("pose_id") or packet.get("resolve_phase") != prepared.resolve_phase or posed.get("resolve_phase") != prepared.resolve_phase:
		return _fail("candidate_pose_identity_or_phase_mismatch")
	if posed.get("resolved_world_origin_id") != ROOT or packet.get("root_origin_id") != ROOT or not bool(posed.get("all_contributing_poses_supplied", false)) or bool(posed.get("other_bones_use_hand_rebased_rest", true)) or bool(posed.get("weights_normalized_by_tool", true)):
		return _fail("candidate_missing_original_contributors_or_origin")
	if not posed.get("vertices_world") is PackedVector3Array or posed.vertices_world.size() != prepared.vertex_count or posed.get("triangle_indices") != prepared.triangle_indices or posed.get("triangle_surface_ids") != prepared.triangle_surface_ids or posed.get("triangle_local_ids") != prepared.triangle_local_ids:
		return _fail("candidate_geometry_source_mismatch")
	if not state.get("digit") is Dictionary or state.digit.get("slot_id") != prepared.slot or state.digit.get("digit_id") != digit_id or state.digit.get("bone_names") != prepared.bone_ids:
		return _fail("candidate_digit_identity_mismatch")
	if not state.get("joint_origins_world") is Array or state.joint_origins_world.size() != 3 or not state.joint_origins_world[0] is Vector3 or not state.joint_origins_world[0].is_finite():
		return _fail("candidate_missing_current_digit_root")
	if not packet.get("origin_records") is Array or not packet.get("machine_to_world") is Transform3D:
		return _fail("candidate_missing_plane_origin_chain")
	var machine: Transform3D = packet.machine_to_world
	if not machine.is_finite() or _frame_error(machine, prepared.machine_to_world) > FRAME_EPSILON:
		return _fail("candidate_machine_presentation_changed")
	var validation_started: int = Time.get_ticks_usec()
	var registered: Dictionary = HandSkin.new()._registry(packet.origin_records, packet.resolve_phase)
	if not bool(registered.get("valid", false)):
		return _fail("invalid_candidate_origin_registry", registered)
	var registry: RefCounted = registered.registry
	if not registry.has_origin(plane_origin_id):
		return _fail("missing_registered_measurement_plane")
	var resolved_plane: Transform3D = machine * registry.resolve_transform_to_machine(plane_origin_id)
	if _frame_error(resolved_plane, plane_to_world) > FRAME_EPSILON:
		return _fail("measurement_plane_does_not_match_registered_frame")
	var validation_ms: float = float(Time.get_ticks_usec() - validation_started) / 1000.0
	var slice_started: int = Time.get_ticks_usec()
	var query: Dictionary = {"plane_to_world": plane_to_world, "plane_origin_id": plane_origin_id,
		"triangle_indices": prepared.triangle_indices, "triangle_surface_ids": prepared.triangle_surface_ids,
		"triangle_local_ids": prepared.triangle_local_ids, "selected_weights": prepared.selected_weights,
		"bone_ids": prepared.bone_ids}
	# Use only the slicing helper: legacy per-digit pose would replace other
	# current contributors with rests. Here all vertices come from ONE candidate.
	var sliced: Array = _skin_query._slice_triangles(query, posed.vertices_world, prepared.triangle_ids, true)
	var slice_ms: float = float(Time.get_ticks_usec() - slice_started) / 1000.0
	var segments: Array[Dictionary] = []
	var owned: Array = [[], [], []]
	var unassigned_count: int = 0
	var root_world: Vector3 = state.joint_origins_world[0]
	var root_local: Vector3 = plane_to_world.affine_inverse() * root_world
	var reach_center: Vector2 = Vector2(root_local.x, root_local.y)
	for original: Dictionary in sliced:
		var key: String = "%d/%d" % [original.surface_index, original.surface_triangle_index]
		var meta: Dictionary = prepared.metadata[key]
		var edge: Dictionary = original.duplicate()
		edge["source_id"] = key
		edge["max_inward_depth_m"] = meta.known_cap_m if is_finite(meta.known_cap_m) else 0.0
		edge["allowance_unassigned"] = not is_finite(meta.known_cap_m) or meta.has_unassigned_influences
		edge["section_owner"] = -1
		for section: int in range(3):
			if 2.0 * float(edge.a_selected_weights[section]) > meta.total_weight_upper + 0.0000001 and 2.0 * float(edge.b_selected_weights[section]) > meta.total_weight_upper + 0.0000001:
				edge.section_owner = section
				edge.max_inward_depth_m = prepared.caps_m[section]
				edge.allowance_unassigned = false
				edge["allowance_assignment_is_trial"] = true
				owned[section].append(segments.size())
		if edge.section_owner < 0:
			_assign_foreign_collision_owner(edge, prepared, posed.vertices_world, plane_to_world)
		unassigned_count += int(edge.allowance_unassigned)
		segments.append(edge)
	# Preference coordinates are separate from section ownership and safety.
	# Percentage coordinates retain their contour definition. Anatomical surface
	# eligibility below limits both preference and ordinary attraction to the pad.
	var preference := {"enabled": false, "reason": "digit_outside_contact_preference_scope"}
	if digit_id in [&"index", &"middle", &"ring", &"pinky"]:
		var to_plane := plane_to_world.affine_inverse()
		var terminal_start_in_plane: Vector3 = to_plane * state.joint_origins_world[2]
		var terminal_tip_in_plane: Vector3 = to_plane * state.tip_world
		preference = ContactPreference.new().annotate(segments, prepared.get("preference_hand_weights", PackedFloat64Array()),
			Vector2(terminal_start_in_plane.x, terminal_start_in_plane.y),
			Vector2(terminal_tip_in_plane.x, terminal_tip_in_plane.y), plane_origin_id,
			prepared.get("preference_vertex_aliases", PackedInt32Array()))
	var gripping := GrippingSurface.new().annotate(prepared.gripping_surface, segments, plane_origin_id)
	if not gripping.get("valid", false): return gripping
	if preference.has("mapped_segments"):
		preference["all_contour_mapped_segments"] = preference.mapped_segments
		preference.mapped_segments = 0
		for edge: Dictionary in segments:
			if edge.has("location_bias"): preference.mapped_segments += 1
		preference.neutral_segments = preference.eligible_segments - preference.mapped_segments
	return {"valid": true, "revision": &"prepared_grip_candidate_slice_v1", "digit_id": digit_id,
		"slot": prepared.slot, "pose_id": packet.pose_id, "pose_packet": packet, "digit_state": state,
		"plane_origin_id": plane_origin_id, "segments": segments, "owned": owned,
		"unassigned_segment_count": unassigned_count, "reach_center_m": reach_center, "reach_m": prepared.reach_m,
		"plane_origin_validation_ms": validation_ms, "skin_slice_ms": slice_ms,
		"section_contact_preference": preference,
		"gripping_surface": gripping,
		"slice_candidate_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"anatomy_recomputed": false, "production_pose_written": false, "actual_3d_grip_verified": false, "grip_accepted": false}


## An Index plane may cut Thumb skin. Its collision allowance belongs to the
## actual contributing Thumb section; it must not become an Index attraction
## target. Test the two sliced endpoints, never a whole-face owner or a nearest
## bone. Original weights and the existing total-weight bound stay unnormalized.
func _assign_foreign_collision_owner(edge: Dictionary, prepared: Dictionary, vertices_world: PackedVector3Array, plane_to_world: Transform3D) -> void:
	if int(edge.get("section_owner", -1)) >= 0: return
	var key: String = edge.source_id
	var sources: Dictionary = prepared.foreign_collision_sources
	if not sources.has(key): return
	var source: Dictionary = sources[key]
	var indices: PackedInt32Array = source.vertex_indices
	var first: Vector3 = vertices_world[indices[0]]
	var second: Vector3 = vertices_world[indices[1]]
	var third: Vector3 = vertices_world[indices[2]]
	# Same source-face degeneracy guard used by palmar source correspondence.
	if (second - first).cross(third - first).length_squared() <= 1.0e-20: return
	var barycentrics: Array[Vector3] = []
	for endpoint: String in ["a", "b"]:
		var point: Vector2 = edge[endpoint]
		var world: Vector3 = plane_to_world * Vector3(point.x, point.y, 0.0)
		# https://docs.godotengine.org/en/4.7/classes/class_geometry3d.html#class-geometry3d-method-get-triangle-barycentric-coords
		var bary: Vector3 = Geometry3D.get_triangle_barycentric_coords(world, first, second, third)
		if not bary.is_finite() or bary.x < -0.0001 or bary.y < -0.0001 or bary.z < -0.0001:
			return
		if bary.x > 1.0001 or bary.y > 1.0001 or bary.z > 1.0001 or (first * bary.x + second * bary.y + third * bary.z).distance_to(world) > 0.000002:
			return
		barycentrics.append(bary)
	var total_upper: float = prepared.metadata[key].total_weight_upper
	for bone: StringName in source.section_corner_weights:
		var weights: Vector3 = source.section_corner_weights[bone]
		var weight_a: float = weights.dot(barycentrics[0])
		var weight_b: float = weights.dot(barycentrics[1])
		if 2.0 * weight_a <= total_upper + 0.0000001 or 2.0 * weight_b <= total_upper + 0.0000001:
			continue
		edge["collision_owner_bone"] = bone
		edge["collision_owner_weight_a"] = weight_a
		edge["collision_owner_weight_b"] = weight_b
		edge["collision_owner_total_weight_upper"] = total_upper
		edge.max_inward_depth_m = prepared.collision_section_caps_m[bone]
		edge.allowance_unassigned = false
		edge["allowance_assignment_is_trial"] = true
		return


func _metric_plane(frame: Transform3D) -> bool:
	if not frame.is_finite():
		return false
	var basis: Basis = frame.basis
	return absf(basis.x.length_squared() - 1.0) <= 0.00001 and absf(basis.y.length_squared() - 1.0) <= 0.00001 and absf(basis.z.length_squared() - 1.0) <= 0.00001 and absf(basis.x.dot(basis.y)) <= 0.00001 and absf(basis.x.dot(basis.z)) <= 0.00001 and absf(basis.y.dot(basis.z)) <= 0.00001


func _frame_error(a: Transform3D, b: Transform3D) -> float:
	if not a.is_finite() or not b.is_finite():
		return INF
	return maxf(a.origin.distance_to(b.origin), maxf(a.basis.x.distance_to(b.basis.x), maxf(a.basis.y.distance_to(b.basis.y), a.basis.z.distance_to(b.basis.z))))


func _fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"valid": false, "reason": reason, "details": details,
		"production_pose_written": false, "actual_3d_grip_verified": false, "grip_accepted": false}
