extends RefCounted

## Anatomical attraction eligibility only. All original skin edges still belong
## to collision/overlap evaluation. No weapon or current finger pose chooses
## the gripping side: it is prepared from reference skin and authored flexion.
const HandSkin = preload("res://runtime/player/grip/prepared_hand_skin_query.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const ROOT := &"RL_BoneRoot"
const REVISION := &"prepared_reference_digit_gripping_half_v1"
const EPSILON_M := 0.0000001
const POLICY := &"both_source_endpoints_strictly_inside_authored_reference_closing_half"


func prepare(adapter: Dictionary, digit_id: StringName) -> Dictionary:
	var started := Time.get_ticks_usec()
	if not adapter.get("valid", false) or adapter.get("revision") != &"prepared_hand_candidate_pose_v1":
		return _fail("requires_prepared_hand_candidate")
	if not adapter.get("digit_inputs", {}).get(digit_id) is Dictionary or not adapter.get("skin_prepared") is Dictionary:
		return _fail("missing_prepared_digit_or_skin")
	var input: Dictionary = adapter.digit_inputs[digit_id]
	var skin: Dictionary = adapter.skin_prepared
	var slot := StringName(adapter.get("slot", &""))
	var chain: Array = Rules.get_chain_rules(slot, digit_id)
	if not input.get("valid", false) or skin.get("revision") != HandSkin.REVISION or chain.size() != 3:
		return _fail("invalid_prepared_digit_or_reference_skin")
	if skin.get("anatomy_signature") != adapter.get("anatomy_signature") or skin.get("weights_normalized_by_tool", true):
		return _fail("reference_skin_identity_or_original_weights_required")
	var snapshot: Dictionary = input.get("snapshot", {})
	var digit: Dictionary = input.get("digit", {})
	if snapshot.get("bone_names", []).size() != 3 or snapshot.get("hinge_axes_local", []).size() != 3 or snapshot.get("hinge_axis_origin_ids", []).size() != 3:
		return _fail("missing_named_section_hinges")
	var machine: Variant = adapter.get("base_packet", {}).get("machine_to_world")
	if not HandSkin.new()._valid_frame(machine): return _fail("missing_reference_presentation")
	var checked: Dictionary = HandSkin.new()._registry(skin.reference_origin_records, &"bake_time")
	if not checked.get("valid", false): return _fail("invalid_reference_origin_chain")
	var registry: RefCounted = checked.registry
	var mapping := {}
	for bone: StringName in skin.bind_bone_names: mapping[bone] = bone
	# Reuse the original-weight skin evaluator. Raw source XYZ need not equal
	# evaluated reference skin when original influence sums are nonunit.
	var reference: Dictionary = HandSkin.new().pose(skin, {
		"anatomy_signature":adapter.anatomy_signature, "root_origin_id":ROOT,
		"pose_id":&"DigitGrippingSurfaceReferenceRest", "resolve_phase":&"bake_time",
		"machine_to_world":machine, "origin_records":skin.reference_origin_records,
		"bone_origin_ids":mapping, "mesh_origin_id":skin.reference_vertices_origin_id})
	if not reference.get("valid", false): return _fail("reference_skin_evaluation_failed")
	var frames: Array[Transform3D] = []
	for section: int in 3:
		var bone := StringName(snapshot.bone_names[section])
		if bone != chain[section].bone or snapshot.hinge_axis_origin_ids[section] != bone or not registry.has_origin(bone):
			return _fail("section_hinge_or_reference_origin_mismatch")
		frames.append(machine * registry.resolve_transform_to_machine(bone))
	var terminal: Variant = digit.get("terminal_skin_offset_local")
	if not terminal is Vector3 or not terminal.is_finite() or digit.get("terminal_skin_offset_origin_id") != snapshot.bone_names[2]:
		return _fail("missing_named_terminal_reference_span")
	var sides: Array = []
	var sections: Array = []
	for section: int in 3:
		var frame: Transform3D = frames[section]
		var span: Vector3 = frame.basis.inverse() * (frames[section + 1].origin - frame.origin) if section < 2 else terminal
		var axis: Variant = snapshot.hinge_axes_local[section]
		var direction := signf(float(chain[section].closed_degrees) - float(chain[section].open_degrees))
		if not axis is Vector3 or not axis.is_finite() or direction == 0.0:
			return _fail("missing_authored_closing_direction")
		# B*(axis cross span) is the authored local rotation derivative. Applying
		# B after the cross also preserves mirrored/scaled imported bone frames.
		var velocity: Vector3 = frame.basis * (axis as Vector3).cross(span) * direction
		if not velocity.is_finite() or velocity.length_squared() <= 1.0e-16:
			return _fail("degenerate_reference_closing_direction")
		var inward: Vector3 = velocity.normalized()
		var distances := PackedFloat64Array()
		distances.resize(reference.vertices_world.size())
		for vertex: int in distances.size():
			distances[vertex] = ((reference.vertices_world[vertex] as Vector3) - frame.origin).dot(inward)
		sides.append(distances)
		sections.append({"section":section + 1, "bone_origin_id":snapshot.bone_names[section],
			"reference_origin_world":frame.origin, "inward_direction_world":inward,
			"vectors_origin_id":ROOT, "motion_direction_sign":direction,
			"reference_span_local":span, "reference_span_origin_id":snapshot.bone_names[section]})
	return {"valid":true, "revision":REVISION, "digit_id":digit_id, "slot":slot,
		"anatomy_signature":adapter.anatomy_signature, "vertex_count":reference.vertices_world.size(),
		"section_reference_sides_m":sides, "sections":sections, "vectors_origin_id":ROOT,
		"reference_origin_records":skin.reference_origin_records, "machine_to_world":machine,
		"policy":POLICY, "reference_evaluated_with_original_weights":true,
		"weapon_dependent":false, "current_pose_dependent":false,
		"physical_geometry_changed":false, "production_pose_written":false,
		"preparation_ms":float(Time.get_ticks_usec() - started) / 1000.0}


func annotate(prepared: Dictionary, segments: Array, plane_origin_id: StringName) -> Dictionary:
	var valid: bool = prepared.get("valid", false) and prepared.get("revision") == REVISION and plane_origin_id != &""
	var report := {"valid":valid, "revision":REVISION, "policy":POLICY,
		"plane_origin_id":plane_origin_id, "eligible_segments":0, "collision_only_segments":0,
		"owned_segments":0, "reason_counts":{}, "physical_geometry_changed":false,
		"physical_collision_geometry_changed":false}
	for value: Variant in segments:
		if not value is Dictionary: continue
		var edge: Dictionary = value
		edge["grip_attraction_eligible"] = false
		edge["grip_surface_reason"] = "not_owned_by_this_digit"
		for key: String in ["grip_reference_side_a_m", "grip_reference_side_b_m", "grip_surface_reference_section_origin_id"]:
			edge.erase(key)
		var section := int(edge.get("section_owner", -1))
		if section >= 0 and section < 3:
			report.owned_segments += 1
			if not valid:
				edge.grip_surface_reason = "reference_gripping_side_unavailable"
			elif edge.get("origin_id") != plane_origin_id:
				edge.grip_surface_reason = "slice_origin_mismatch"
			elif prepared.digit_id == &"thumb" and section == 0:
				edge.grip_surface_reason = "thumb_proximal_section_has_no_attraction"
			elif edge.get("coplanar", false):
				edge.grip_surface_reason = "coplanar_source_is_not_attraction_evidence"
			else:
				var distances: PackedFloat64Array = prepared.section_reference_sides_m[section]
				var a := _source_side(edge.get("a_source", {}), distances)
				var b := _source_side(edge.get("b_source", {}), distances)
				if not is_finite(a) or not is_finite(b):
					edge.grip_surface_reason = "missing_or_ambiguous_reference_source"
				else:
					edge["grip_reference_side_a_m"] = a
					edge["grip_reference_side_b_m"] = b
					edge["grip_surface_reference_section_origin_id"] = prepared.sections[section].bone_origin_id
					edge.grip_attraction_eligible = minf(a, b) > EPSILON_M
					edge.grip_surface_reason = "anatomical_gripping_side" if edge.grip_attraction_eligible else (
						"anatomical_back_side" if maxf(a, b) < -EPSILON_M else "reference_side_boundary_or_crossing")
		if edge.grip_attraction_eligible:
			report.eligible_segments += 1
		else:
			report.collision_only_segments += 1
			edge.erase("location_bias")
		var reason: String = edge.grip_surface_reason
		report.reason_counts[reason] = int(report.reason_counts.get(reason, 0)) + 1
	if not valid: report["reason"] = "invalid_prepared_gripping_surface_or_plane"
	return report


## Original, globally indexed source vertices only. No posed-space welding,
## normal guessing, nearest-side fallback, or normalization of skin weights.
func _source_side(source: Variant, distances: PackedFloat64Array) -> float:
	if not source is Dictionary or source.get("coplanar", false) or source.get("topology_ambiguous", false): return NAN
	var ids: Variant = source.get("vertex_ids")
	if not ids is PackedInt32Array: return NAN
	for vertex: int in ids:
		if vertex < 0 or vertex >= distances.size() or not is_finite(distances[vertex]): return NAN
	if source.get("kind") == "vertex" and ids.size() == 1:
		return distances[ids[0]] if source.get("topology_key") == "v:%d" % ids[0] else NAN
	if source.get("kind") != "edge" or ids.size() != 2 or ids[0] >= ids[1] or source.get("topology_key") != "e:%d:%d" % [ids[0], ids[1]]: return NAN
	var parameter: Variant = source.get("t")
	if not (parameter is float or parameter is int) or not is_finite(float(parameter)) or float(parameter) < 0.0 or float(parameter) > 1.0: return NAN
	return lerpf(distances[ids[0]], distances[ids[1]], float(parameter))


func _fail(reason: String) -> Dictionary:
	return {"valid":false, "revision":REVISION, "reason":reason,
		"physical_geometry_changed":false, "production_pose_written":false}
