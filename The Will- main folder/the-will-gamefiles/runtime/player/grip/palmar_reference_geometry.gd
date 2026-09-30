extends RefCounted

const HandSkin = preload("res://runtime/player/grip/prepared_hand_skin_query.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const Fingerprint = preload("res://runtime/player/grip/character_anatomy_source_signature.gd")
const ROOT := &"RL_BoneRoot"
const RAY_EPSILON_M := 0.0000001
const BARYCENTRIC_EPSILON := 0.0000001
const GRAM_EPSILON := 0.00001
# Direction-quality gate, not a measured palm dimension or motion limit.
const MIN_CLOSING_ALIGNMENT := 0.1
const SAMPLE_PARAMETERS: Array[float] = [0.25, 0.5, 0.75]



func _measure_slot(slot: StringName, prepared: Dictionary, posed: Dictionary, registry: RefCounted, machine: Transform3D) -> Dictionary:
	var side: Dictionary = Rules.get_surface_solver_side_rules(slot)
	if side.is_empty():
		return _fail("missing_declared_hand_mapping")
	var hand: StringName = side.hand_bone_name
	var index_rules: Array = Rules.get_chain_rules(slot, &"index")
	var pinky_rules: Array = Rules.get_chain_rules(slot, &"pinky")
	if index_rules.size() != 3 or pinky_rules.size() != 3:
		return _fail("missing_core_footprint_bones")
	var index_name: StringName = index_rules[0].bone
	var pinky_name: StringName = pinky_rules[0].bone
	for name: StringName in [hand, index_name, pinky_name]:
		if not registry.has_origin(name):
			return _fail("missing_core_footprint_origin", {"bone": name})
	var hand_world: Transform3D = machine * registry.resolve_transform_to_machine(hand)
	var wrist: Vector3 = hand_world.origin
	var index: Vector3 = (machine * registry.resolve_transform_to_machine(index_name)).origin
	var pinky: Vector3 = (machine * registry.resolve_transform_to_machine(pinky_name)).origin
	var area_vector: Vector3 = (index - wrist).cross(pinky - wrist)
	if area_vector.length_squared() <= 1.0e-16:
		return _fail("degenerate_core_bone_footprint")
	var unsigned_normal := area_vector.normalized()
	var evidence: Array[Dictionary] = []
	var polarity := 0.0
	for digit: StringName in [&"middle", &"ring", &"pinky"]:
		var chain: Array = Rules.get_chain_rules(slot, digit)
		if chain.size() != 3 or not registry.has_origin(chain[0].bone) or not registry.has_origin(chain[1].bone):
			return _fail("missing_closing_direction_reference", {"digit": digit})
		var first: Transform3D = machine * registry.resolve_transform_to_machine(chain[0].bone)
		var second: Vector3 = (machine * registry.resolve_transform_to_machine(chain[1].bone)).origin
		var local_span: Vector3 = first.basis.inverse() * (second - first.origin)
		var direction_sign := signf(float(chain[0].closed_degrees) - float(chain[0].open_degrees))
		var velocity: Vector3 = first.basis * (chain[0].hinge_axis_local as Vector3).cross(local_span) * direction_sign
		if velocity.length_squared() <= 1.0e-16:
			return _fail("degenerate_authored_closing_direction", {"digit": digit})
		var alignment := unsigned_normal.dot(velocity.normalized())
		evidence.append({"digit": digit, "bone": chain[0].bone, "unsigned_normal_alignment": alignment,
			"direction_source": "reference_first_joint_local_hinge_closing_derivative"})
		if absf(alignment) < MIN_CLOSING_ALIGNMENT:
			return _fail("ambiguous_palmar_polarity", {"closing_evidence": evidence})
		if polarity != 0.0 and signf(alignment) != polarity:
			return _fail("ordinary_closing_directions_disagree", {"closing_evidence": evidence})
		polarity = signf(alignment)
	var palmar_normal: Vector3 = unsigned_normal * polarity
	var across: Vector3 = (pinky - index).normalized()
	var core_frame := Transform3D(Basis(across, palmar_normal.cross(across).normalized(), palmar_normal), wrist)
	var frame_id := StringName(String(hand) + "PalmarCoreReferenceOrigin")
	var frame_inverse := core_frame.affine_inverse()
	var frame_record := {"origin_id": frame_id, "parent_origin_id": hand,
		"transform_to_parent": hand_world.affine_inverse() * core_frame,
		"owner_system": &"palmar_core_character_preparation", "resolve_phase": &"bake_time",
		"space_type": &"bone_frame", "is_dynamic": false}
	var hand_weights := PackedFloat64Array()
	hand_weights.resize(prepared.vertex_count)
	for vertex: int in range(prepared.vertex_count):
		for influence: int in range(prepared.vertex_offsets[vertex], prepared.vertex_offsets[vertex + 1]):
			if prepared.bind_bone_names[prepared.influence_binds[influence]] == hand:
				hand_weights[vertex] += prepared.influence_weights[influence]
	var triangles := PackedInt32Array()
	for triangle: int in range(prepared.triangle_count):
		var relevant := false
		for corner: int in range(3):
			relevant = relevant or hand_weights[prepared.triangle_indices[triangle * 3 + corner]] > 0.0
		if relevant:
			triangles.append(triangle)
	if triangles.is_empty():
		return _fail("no_hand_influenced_reference_faces")
	var samples: Array[Dictionary] = []
	var rejected: Array[Dictionary] = []
	for row: int in range(SAMPLE_PARAMETERS.size()):
		for column: int in range(SAMPLE_PARAMETERS.size()):
			var u: float = SAMPLE_PARAMETERS[row]
			var v: float = SAMPLE_PARAMETERS[column]
			# Three scalar interpolation weights, not a spatial Vector3.
			var barycentric := Vector3(1.0 - u, u * (1.0 - v), u * v)
			var seed: Vector3 = wrist * barycentric.x + index * barycentric.y + pinky * barycentric.z
			var sample_id := StringName("%s_core_%d_%d" % [slot, row, column])
			var palmar := _first_hit(prepared, posed, triangles, seed, palmar_normal, hand, frame_inverse, frame_id)
			var dorsal := _first_hit(prepared, posed, triangles, seed, -palmar_normal, hand, frame_inverse, frame_id)
			var reason := ""
			if not palmar.get("valid", false) or not dorsal.get("valid", false):
				reason = "missing_or_unowned_paired_first_hits"
			elif float(palmar.normal_ray_dot) * float(dorsal.normal_ray_dot) <= 0.0:
				reason = "paired_face_winding_disagrees"
			var sample := {"sample_id": sample_id, "footprint_barycentric": barycentric,
				"seed_point_m": frame_inverse * seed, "seed_point_origin_id": frame_id,
				"palmar_hit": palmar, "dorsal_hit": dorsal,
				"two_sided_bracketing_verified": reason.is_empty(), "solid_enclosure_verified": false,
				"source_face_is_sample_carrier_not_whole_palmar_face": true}
			if reason.is_empty():
				samples.append(sample)
			else:
				sample["reason"] = reason
				rejected.append(sample)
	return {"valid": rejected.is_empty() and samples.size() == 9,
		"complete": rejected.is_empty() and samples.size() == 9, "samples": samples,
		"rejected_samples": rejected, "expected_sample_count": 9, "accepted_sample_count": samples.size(),
		"slot_id": slot, "hand_bone_name": hand, "frame_origin_id": frame_id, "origin_record": frame_record,
		"footprint_bone_origin_ids": [hand, index_name, pinky_name], "closing_evidence": evidence,
		"palmar_direction_local": Vector3(0.0, 0.0, 1.0), "palmar_direction_origin_id": frame_id,
		"hand_influenced_triangle_count": triangles.size(), "ray_domain": "unchanged_reference_faces_with_any_positive_Hand_influence",
		"ownership_policy": "first_hit_on_each_side_must_have_strict_Hand_majority_of_all_original_weights",
		"sampling_policy": "u_v_in_quarters_barycentric_1_minus_u_u_times_1_minus_v_u_times_v",
		"solid_enclosure_verified": false, "complete_palm_partition_verified": false}


func _first_hit(prepared: Dictionary, posed: Dictionary, triangles: PackedInt32Array, seed: Vector3, direction: Vector3, hand: StringName, to_frame: Transform3D, frame_id: StringName) -> Dictionary:
	var nearest := INF
	var chosen := {}
	var seed_on_surface := false
	for triangle: int in triangles:
		var ids: Array[int] = []
		for corner: int in range(3): ids.append(prepared.triangle_indices[triangle * 3 + corner])
		var a: Vector3 = posed.vertices_world[ids[0]]
		var edge1: Vector3 = posed.vertices_world[ids[1]] - a
		var edge2: Vector3 = posed.vertices_world[ids[2]] - a
		var p: Vector3 = direction.cross(edge2)
		var determinant := edge1.dot(p)
		if absf(determinant) < 1.0e-14: continue
		var offset: Vector3 = seed - a
		var u := offset.dot(p) / determinant
		var q := offset.cross(edge1)
		var v := direction.dot(q) / determinant
		if u < -BARYCENTRIC_EPSILON or v < -BARYCENTRIC_EPSILON or u + v > 1.0 + BARYCENTRIC_EPSILON: continue
		var distance := edge2.dot(q) / determinant
		if absf(distance) <= RAY_EPSILON_M:
			seed_on_surface = true
		if distance <= RAY_EPSILON_M or distance > nearest + RAY_EPSILON_M: continue
		if absf(distance - nearest) <= RAY_EPSILON_M and not chosen.is_empty() and triangle > int(chosen.global_triangle_index): continue
		var barycentric := Vector3(maxf(1.0 - u - v, 0.0), maxf(u, 0.0), maxf(v, 0.0))
		barycentric /= barycentric.x + barycentric.y + barycentric.z
		var hit: Vector3 = posed.vertices_world[ids[0]] * barycentric.x + posed.vertices_world[ids[1]] * barycentric.y + posed.vertices_world[ids[2]] * barycentric.z
		if hit.distance_to(seed + direction * distance) > RAY_EPSILON_M * 4.0: continue
		var weights := {}
		var total := 0.0
		for corner: int in range(3):
			for influence: int in range(prepared.vertex_offsets[ids[corner]], prepared.vertex_offsets[ids[corner] + 1]):
				var name: StringName = prepared.bind_bone_names[prepared.influence_binds[influence]]
				var weight: float = prepared.influence_weights[influence] * barycentric[corner]
				weights[name] = float(weights.get(name, 0.0)) + weight
				total += weight
		var surface: int = prepared.triangle_surface_ids[triangle]
		var first_vertex: int = prepared.surface_ranges[surface].first_vertex
		var normal_ray_dot := edge1.cross(edge2).normalized().dot(direction)
		chosen = {"valid": true, "surface_index": surface, "surface_triangle_index": prepared.triangle_local_ids[triangle],
			"global_triangle_index": triangle, "source_vertex_indices": PackedInt32Array([ids[0] - first_vertex, ids[1] - first_vertex, ids[2] - first_vertex]),
			"barycentric": barycentric, "reference_point_m": to_frame * hit, "reference_point_origin_id": frame_id,
			"ray_distance_m": distance, "normal_ray_dot": normal_ray_dot,
			"original_interpolated_influences": weights, "hand_weight": float(weights.get(hand, 0.0)), "total_weight": total,
			"weights_normalized": false, "barycentric_roundoff_clamped": u < 0.0 or v < 0.0 or u + v > 1.0}
		nearest = distance
	if seed_on_surface: return _fail("core_seed_on_reference_surface")
	if chosen.is_empty(): return _fail("no_positive_reference_skin_hit")
	if 2.0 * float(chosen.hand_weight) <= float(chosen.total_weight) + BARYCENTRIC_EPSILON:
		chosen["valid"] = false
		chosen["reason"] = "first_hit_not_strict_Hand_majority"
	if absf(float(chosen.normal_ray_dot)) <= 0.00001:
		chosen["valid"] = false
		chosen["reason"] = "grazing_reference_skin_hit"
	return chosen


func _validate_metric(expected: Dictionary, machine: Transform3D) -> Dictionary:
	if not HandSkin.new()._valid_frame(machine) or not expected.get("gram_matrix") is Array or expected.gram_matrix.size() != 3:
		return _fail("missing_or_invalid_character_metric")
	if int(expected.get("determinant_sign", 0)) != (-1 if machine.basis.determinant() < 0.0 else 1):
		return _fail("character_metric_handedness_changed")
	for row: int in range(3):
		if not expected.gram_matrix[row] is Array or expected.gram_matrix[row].size() != 3:
			return _fail("invalid_character_metric_gram")
		for column: int in range(3):
			var value: float = expected.gram_matrix[row][column]
			if not is_finite(value) or absf(machine.basis[row].dot(machine.basis[column]) - value) > GRAM_EPSILON * maxf(1.0, absf(value)):
				return _fail("character_metric_changed_requires_new_preparation")
	return {"valid": true}


func _validate_reference_hashes(reference: Dictionary, manifest: Dictionary) -> Dictionary:
	if not manifest.get("component_hashes") is Dictionary or not manifest.get("surface_component_hashes") is Array:
		return _fail("missing_reference_hash_manifest")
	var hasher := Fingerprint.new()
	for key: String in ["bind_bone_names", "bind_poses", "bind_global_rests", "hand_global_rests"]:
		if not reference.has(key) or hasher._hash(reference[key]) != manifest.component_hashes.get(key):
			return _fail("reference_content_does_not_match_anatomy_signature", {"field": key})
	if not reference.get("surfaces") is Array or reference.surfaces.size() != manifest.surface_component_hashes.size():
		return _fail("reference_surface_count_mismatch")
	for index: int in range(reference.surfaces.size()):
		for key: String in ["vertices", "indices", "bones", "weights"]:
			if not reference.surfaces[index].has(key) or hasher._hash(reference.surfaces[index][key]) != manifest.surface_component_hashes[index].get(key):
				return _fail("reference_surface_hash_mismatch", {"surface": index, "field": key})
	var frames := {"vertices_origin_id": reference.get("vertices_origin_id"), "mesh_origin_record": reference.get("mesh_origin_record"), "bone_origin_records": reference.get("bone_origin_records")}
	if hasher._hash(frames) != manifest.component_hashes.get("named_reference_frames"):
		return _fail("reference_origin_hash_mismatch")
	return {"valid": true}


func _fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"valid": false, "complete": false, "reason": reason, "details": details,
		"solid_enclosure_verified": false, "actual_3d_grip_verified": false}
