extends RefCounted

## V6 preparation and sparse original-weight skin evaluation. No live slices,
## circles, scene writes, weapon placement or joint solver live in this owner.
const Candidate = preload("res://runtime/player/grip/prepared_hand_candidate_pose.gd")
const Palm = preload("res://runtime/player/grip/prepared_palmar_slice_region.gd")
const GrippingSide = preload("res://runtime/player/grip/prepared_digit_gripping_surface.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const Spatial = preload("res://runtime/player/player_finger_surface_grip_solver.gd")
const ROOT := &"RL_BoneRoot"
const REVISION := &"prepared_original_weight_surface_grip_v5"
const ALL_DIGITS: Array[StringName] = [&"index", &"middle", &"ring", &"pinky", &"thumb"]
const PEAKS := [20.0, 50.0, 60.0]
const SPREAD := 25.0
const EPS_M := 0.0000001
const CONTACT_SAMPLE_LIMIT := 12
const PALM_SAMPLE_LIMIT := 24
const COORDINATE_POLICY := &"prepared_mesh_edge_geodesic_between_original_skin_influence_crossings"
static var _geometry_cache := {}
static var _cache_order: Array[String] = []
static var _cache_mutex := Mutex.new()


func prepare(anatomy: Resource, stage: Dictionary, _config: Dictionary = {}) -> Dictionary:
	var started := Time.get_ticks_usec()
	if anatomy == null or not stage.get("posed_character") is Dictionary:
		return _fail("missing_character_or_coherent_capture")
	var adapter: Dictionary = Candidate.new().prepare(anatomy, stage.posed_character, stage.get("slot", &""), ALL_DIGITS)
	if not adapter.get("valid", false): return adapter
	var angles := {}
	var geometry_identity: Array = [REVISION, adapter.anatomy_signature, adapter.slot, PEAKS, _caps(adapter.slot), Palm.PALM_CAP_M]
	for digit: StringName in ALL_DIGITS:
		var input: Dictionary = adapter.digit_inputs[digit]
		var open: Array[float] = []
		for section: int in 3:
			var angle := deg_to_rad(Rules.get_open_degrees_for_joint(adapter.slot, digit, section + 1))
			if angle < float(input.snapshot.min_angles_rad[section]) or angle > float(input.snapshot.max_angles_rad[section]):
				return _fail("calibrated_open_angle_outside_prepared_limits")
			open.append(angle)
		angles[digit] = open
		geometry_identity.append([input.snapshot.relative_transforms, input.snapshot.neutral_local_rotations,
			input.snapshot.hinge_axes_local, input.digit.terminal_skin_offset_local])
	# One complete open pose establishes coherent skin and Thumb clearance. Live
	# iterations use pose_samples(), not this full-mesh preparation path.
	var opened: Dictionary = Candidate.new().evaluate(adapter, angles, Vector3.ZERO, ROOT)
	if not opened.get("valid", false): return opened
	var references := _references(adapter, opened)
	if not references.get("valid", false): return references
	# Rigid placement does not invalidate anatomy, but a metric scale/shear does.
	var metric_basis: Basis = opened.hand_to_world.basis
	geometry_identity.append([metric_basis.x.dot(metric_basis.x), metric_basis.x.dot(metric_basis.y),
		metric_basis.x.dot(metric_basis.z), metric_basis.y.dot(metric_basis.y),
		metric_basis.y.dot(metric_basis.z), metric_basis.z.dot(metric_basis.z), signf(metric_basis.determinant())])
	var key := var_to_bytes(geometry_identity).hex_encode()
	_cache_mutex.lock()
	var cached: bool = _geometry_cache.has(key)
	var geometry: Dictionary = _geometry_cache.get(key, {})
	_cache_mutex.unlock()
	if not cached:
		geometry = _prepare_geometry(adapter, anatomy, opened, references)
		if not geometry.get("valid", false): return geometry
		_cache_mutex.lock()
		if not _geometry_cache.has(key):
			if _cache_order.size() >= 4: _geometry_cache.erase(_cache_order.pop_front())
			_geometry_cache[key] = geometry
			_cache_order.append(key)
		_cache_mutex.unlock()
	var frames := {}
	var machine: Transform3D = opened.pose_packet.machine_to_world
	for bone: StringName in opened.posed.bone_transforms_to_machine:
		frames[bone] = machine * (opened.posed.bone_transforms_to_machine[bone] as Transform3D)
	var vertices := {}
	var skin: Dictionary = adapter.skin_prepared
	for vertex: int in geometry.used_vertex_ids:
		var fixed: Vector3 = opened.posed.vertices_world[vertex]
		var moving: Array = []
		for influence: int in range(skin.vertex_offsets[vertex], skin.vertex_offsets[vertex + 1]):
			var bone: StringName = skin.bind_bone_names[skin.influence_binds[influence]]
			var owner: StringName = bone
			while owner != &"" and owner != ROOT and not adapter.selected_bones.has(owner):
				owner = adapter.source_parent_ids.get(owner, &"")
			if not adapter.selected_bones.has(owner): continue
			var weighted: Vector3 = skin.weighted_bind_points[influence]
			var weight: float = skin.influence_weights[influence]
			var frame: Transform3D = frames[bone]
			fixed -= frame.basis * weighted + frame.origin * weight
			if owner != bone:
				var to_owner: Transform3D = (frames[owner] as Transform3D).affine_inverse() * frame
				weighted = to_owner.basis * weighted + to_owner.origin * weight
			moving.append({"bone":owner, "weighted_bind_point":weighted, "weight":weight,
				"weighted_bind_point_origin_id":owner, "original_bind_bone":bone})
		vertices[vertex] = {"fixed_world":fixed, "moving":moving, "origin_id":ROOT}
	var digits := {}
	for digit: StringName in ALL_DIGITS:
		digits[digit] = geometry.digits[digit].duplicate(true)
		digits[digit]["snapshot"] = adapter.digit_inputs[digit].snapshot
		digits[digit]["open_angles"] = angles[digit].duplicate()
		digits[digit]["joint_origin_ids"] = adapter.digit_inputs[digit].snapshot.bone_names.duplicate()
	return {"valid":true, "revision":REVISION, "adapter":adapter, "anatomy_signature":adapter.anatomy_signature,
		"slot":adapter.slot, "open_angles":angles, "open_candidate":opened, "open_frames_world":frames,
		"digits":digits, "palm_samples":geometry.palm_samples, "safety_samples":geometry.safety_samples,
		"safety_triangle_ids":geometry.safety_triangle_ids, "references":references,
		"vertices":vertices, "selected_bones":adapter.selected_bones, "vectors_origin_id":ROOT,
		"origin_records":opened.pose_packet.origin_records + [references.origin_record],
		"static_preparation_cache_hit":cached, "sample_counts":geometry.sample_counts,
		"coordinate_policy":COORDINATE_POLICY, "coordinate_differs_from_historical_slice_arclength":true,
		"original_skin_weights_preserved":true, "live_slice_performed":false,
		"thumb_contact_sections":[2, 3], "thumb_geometry_retained":true,
		"safety_coverage":&"all_hand_influenced_triangle_centroids_and_vertices",
		"whole_triangle_interiors_certified":false, "actual_3d_grip_verified":false,
		"preparation_ms":float(Time.get_ticks_usec() - started) / 1000.0}


## Overrides contain canonical bone names -> current world frames. Hand and all
## upstream transforms are fixed. Only the fifteen owned digit bones can move.
## Each actual mesh vertex is evaluated once per call, shared by its carriers.
func pose_samples(prepared: Dictionary, samples: Array, overrides: Dictionary = {}) -> Array:
	if not prepared.get("valid", false) or prepared.get("revision") != REVISION: return []
	for bone: Variant in overrides:
		if not prepared.selected_bones.has(bone) or not overrides[bone] is Transform3D or not (overrides[bone] as Transform3D).is_finite(): return []
	var posed := {}
	var result: Array = []
	for sample: Dictionary in samples:
		var points: Array[Vector3] = []
		for id: int in sample.vertex_ids:
			if not posed.has(id):
				if not prepared.vertices.has(id): return []
				var vertex: Dictionary = prepared.vertices[id]
				var point: Vector3 = vertex.fixed_world
				for influence: Dictionary in vertex.moving:
					var frame: Transform3D = overrides.get(influence.bone, prepared.open_frames_world[influence.bone])
					point += frame.basis * (influence.weighted_bind_point as Vector3) + frame.origin * float(influence.weight)
				if not point.is_finite(): return []
				posed[id] = point
			points.append(posed[id])
		var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0])
		if normal.length_squared() <= 1.0e-20: return []
		var bary: Vector3 = sample.barycentric
		var output: Dictionary = sample.duplicate()
		output["point_world"] = points[0] * bary.x + points[1] * bary.y + points[2] * bary.z
		output["triangle_world"] = points
		output["normal_world"] = normal.normalized() * float(sample.normal_sign)
		output["vectors_origin_id"] = ROOT
		result.append(output)
	return result


func _references(adapter: Dictionary, opened: Dictionary) -> Dictionary:
	var wrist: Vector3 = opened.hand_to_world.origin
	var index: Vector3 = opened.digit_states[&"index"].joint_origins_world[0]
	var pinky: Vector3 = opened.digit_states[&"pinky"].joint_origins_world[0]
	var across := pinky - index
	var normal := (index - wrist).cross(pinky - wrist)
	if across.length_squared() <= 1.0e-16 or normal.length_squared() <= 1.0e-16: return _fail("degenerate_current_hand_reference")
	across = across.normalized(); normal = normal.normalized()
	var polarity := 0.0
	for digit: StringName in [&"middle", &"ring", &"pinky"]:
		var state: Dictionary = opened.digit_states[digit]
		var frame: Transform3D = state.joint_transforms_world[0]
		var span: Vector3 = frame.basis.inverse() * ((state.joint_origins_world[1] as Vector3) - frame.origin)
		var rule: Dictionary = Rules.get_chain_rules(adapter.slot, digit)[0]
		var closing: Vector3 = frame.basis * (state.snapshot.hinge_axes_local[0] as Vector3).cross(span) * signf(float(rule.closed_degrees) - float(rule.open_degrees))
		var dot_value := normal.dot(closing.normalized())
		if absf(dot_value) < 0.1 or (polarity != 0.0 and signf(dot_value) != polarity): return _fail("ambiguous_current_palmar_approach")
		polarity = signf(dot_value)
	normal *= polarity
	var frame := Transform3D(Basis(across, normal.cross(across).normalized(), normal), wrist)
	var origin := StringName(String(adapter.hand_bone_name) + "SurfaceGripMetricOrigin")
	return {"valid":true, "wrist_world":wrist, "index_world":index, "pinky_world":pinky,
		"knuckle_midpoint_world":(index + pinky) * 0.5, "across_world":across,
		"palmar_out_world":normal, "approach_world":normal, "inward_translation_world":-normal,
		"approach_convention":&"outward_from_hand_toward_weapon_seating_moves_in_negative_direction",
		"wrist_to_index_world":index - wrist, "wrist_to_pinky_world":pinky - wrist,
		"bone_origin_ids":[adapter.hand_bone_name, adapter.digit_inputs[&"index"].snapshot.bone_names[0], adapter.digit_inputs[&"pinky"].snapshot.bone_names[0]],
		"vectors_origin_id":ROOT, "metric_frame_to_world":frame, "metric_frame_origin_id":origin,
		"origin_record":{"origin_id":origin, "parent_origin_id":adapter.hand_bone_name,
			"transform_to_parent":(opened.hand_to_world as Transform3D).affine_inverse() * frame,
			"owner_system":&"prepared_surface_grip_anatomy", "resolve_phase":&"editor_preview",
			"space_type":&"bone_frame", "is_dynamic":true}}


func _prepare_geometry(adapter: Dictionary, anatomy: Resource, opened: Dictionary, references: Dictionary) -> Dictionary:
	var skin: Dictionary = adapter.skin_prepared
	var points: PackedVector3Array = opened.posed.vertices_world
	var weights: Array = []
	for vertex: int in skin.vertex_count:
		var values := {}
		for influence: int in range(skin.vertex_offsets[vertex], skin.vertex_offsets[vertex + 1]):
			var bone: StringName = skin.bind_bone_names[skin.influence_binds[influence]]
			values[bone] = float(values.get(bone, 0.0)) + float(skin.influence_weights[influence])
		weights.append(values)
	var caps := _caps(adapter.slot)
	if caps.is_empty(): return _fail("missing_existing_digit_overlap_rules")
	var sides := {}
	var bone_owners := {}
	var digits := {}
	for digit: StringName in ALL_DIGITS:
		var prepared: Dictionary = GrippingSide.new().prepare(adapter, digit)
		if not prepared.get("valid", false): return prepared
		sides[digit] = prepared.section_reference_sides_m
		for section: int in 3:
			bone_owners[adapter.digit_inputs[digit].snapshot.bone_names[section]] = {"digit":digit, "section":section}
		var sections: Array = []
		for section: int in 3:
			sections.append({"samples":[], "cap_m":caps[adapter.digit_inputs[digit].snapshot.bone_names[section]],
				"attraction_enabled":_attraction_enabled(digit, section), "preference_enabled":digit != &"thumb",
				"peak_percent":PEAKS[section] if digit != &"thumb" else -1.0})
		digits[digit] = {"sections":sections, "safety_samples":[]}
	var palm: Dictionary = Palm.new().prepare({"adapter":adapter, "slot":adapter.slot}, anatomy)
	if not palm.get("valid", false): return palm
	var triangles := PackedInt32Array()
	var edges := {}
	for triangle: int in skin.triangle_count:
		var ids: PackedInt32Array = skin.triangle_indices.slice(triangle * 3, triangle * 3 + 3)
		var relevant := false
		for id: int in ids:
			for bone: Variant in weights[id]:
				if adapter.descendant_bones.has(bone): relevant = true; break
		if not relevant: continue
		triangles.append(triangle)
		for corner: int in 3:
			var a: int = skin.preference_vertex_aliases[ids[corner]]
			var b: int = skin.preference_vertex_aliases[ids[(corner + 1) % 3]]
			if a != b: edges[Vector2i(mini(a, b), maxi(a, b))] = [a, b]
	var fields := {}
	for digit: StringName in ALL_DIGITS:
		var names: Array = adapter.digit_inputs[digit].snapshot.bone_names
		var state: Dictionary = opened.digit_states[digit]
		for section: int in 3:
			var proximal: StringName = adapter.hand_bone_name if section == 0 else names[section - 1]
			var distal: StringName = names[section + 1] if section < 2 else &""
			fields[names[section]] = _surface_field(names[section], proximal, distal, weights, points, edges,
				state.joint_origins_world[2], state.tip_world)
	var palm_samples: Array = []
	var safety: Array = []
	var used := {}
	# Source centroids and source vertices are actual original-skin carriers.
	# They are a bounded sampled coverage policy, not an invented capsule shell
	# or a claim that every triangle interior has been checked continuously.
	for triangle: int in triangles:
		var ids: PackedInt32Array = skin.triangle_indices.slice(triangle * 3, triangle * 3 + 3)
		var source := "%d/%d" % [skin.triangle_surface_ids[triangle], skin.triangle_local_ids[triangle]]
		var normal: Vector3 = (points[ids[1]] - points[ids[0]]).cross(points[ids[2]] - points[ids[0]])
		if normal.length_squared() <= 1.0e-20: continue
		normal = normal.normalized()
		# A carrier's ray normal uses all three corners even when its barycentric
		# position sits on one fixed corner. Track the whole triangle's moving
		# dependencies, including skin-weighted descendants of a selected bone.
		var affected_digits: Array[StringName] = []
		for vertex: int in ids:
			for raw_bone: Variant in weights[vertex]:
				if float(weights[vertex][raw_bone]) <= 0.0: continue
				var ancestor := StringName(raw_bone)
				while ancestor != &"" and ancestor != ROOT and not bone_owners.has(ancestor):
					ancestor = adapter.source_parent_ids.get(ancestor, &"")
				if bone_owners.has(ancestor):
					var affected: StringName = bone_owners[ancestor].digit
					if not affected_digits.has(affected): affected_digits.append(affected)
		for bary: Vector3 in [Vector3.ONE / 3.0, Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]:
			var point: Vector3 = points[ids[0]] * bary.x + points[ids[1]] * bary.y + points[ids[2]] * bary.z
			var blend := _blend_weights(ids, bary, weights)
			var total := 0.0
			for weight: float in blend.values(): total += weight
			var owner := {}
			for bone: StringName in bone_owners:
				if 2.0 * float(blend.get(bone, 0.0)) > total + EPS_M:
					owner = bone_owners[bone].duplicate(); owner["bone"] = bone; break
			var palmar := _in_palm(palm, source, bary)
			var cap := 0.0
			var eligible := false
			var outward: Vector3 = references.palmar_out_world
			var digit_id := &""
			var section_id := -1
			var percent := -1.0
			var surface_length := 0.0
			if not owner.is_empty():
				digit_id = owner.digit; section_id = owner.section
				var side: PackedFloat64Array = sides[digit_id][section_id]
				var closing_side: float = side[ids[0]] * bary.x + side[ids[1]] * bary.y + side[ids[2]] * bary.z
				var state: Dictionary = opened.digit_states[digit_id]
				var a: Vector3 = state.joint_origins_world[section_id]
				var b: Vector3 = state.joint_origins_world[section_id + 1] if section_id < 2 else state.tip_world
				outward = point - Geometry3D.get_closest_point_to_segment(point, a, b)
				if closing_side > EPS_M:
					cap = caps[owner.bone]
					eligible = _attraction_enabled(digit_id, section_id)
				if fields.has(owner.bone):
					var coordinate := _coordinate(fields[owner.bone], ids, bary, points, skin.preference_vertex_aliases)
					percent = coordinate.percent; surface_length = coordinate.length_m
			elif palmar:
				cap = Palm.PALM_CAP_M
				eligible = true
			else:
				# Unassigned and dorsal tissue gets no implicit palm privilege.
				var height: float = ((references.metric_frame_to_world as Transform3D).affine_inverse() * point).z
				outward *= signf(height)
			var polarity := normal.dot(outward)
			if absf(polarity) <= EPS_M: eligible = false
			var sample := {"vertex_ids":ids, "barycentric":bary, "triangle_id":triangle,
				"source_id":source, "source_vertices_origin_id":skin.reference_vertices_origin_id,
				"normal_sign":1.0 if polarity >= 0.0 else -1.0, "normal_anatomically_oriented":absf(polarity) > EPS_M,
				"digit":digit_id, "section":section_id + 1 if section_id >= 0 else 0,
				"affected_digits":affected_digits,
				"cap_m":cap, "max_inward_depth_m":cap, "palm_owned":owner.is_empty() and palmar,
				"grip_attraction_eligible":eligible, "percent":percent, "section_length_m":surface_length,
				"preference_enabled":digit_id != &"thumb" and section_id >= 0,
				"bell":_preference_bell(digit_id, section_id, percent),
				"coordinate_policy":COORDINATE_POLICY, "reference_point_metric":(references.metric_frame_to_world as Transform3D).affine_inverse() * point,
				"reference_point_origin_id":references.metric_frame_origin_id, "weights_normalized":false}
			safety.append(sample)
			for id: int in ids: used[id] = true
			for affected: StringName in affected_digits:
				if digits.has(affected): digits[affected].safety_samples.append(sample)
			if not eligible: continue
			if owner.is_empty() and palmar: palm_samples.append(sample)
			elif digits.has(digit_id): digits[digit_id].sections[section_id].samples.append(sample)
	var counts := {"safety":safety.size(), "palm":0, "digits":{}}
	for digit: StringName in ALL_DIGITS:
		var per_section: Array = []
		for section: int in 3:
			var pool: Array = digits[digit].sections[section].samples
			if not _attraction_enabled(digit, section):
				per_section.append(0)
				continue
			if pool.is_empty(): return _fail("missing_anatomical_pad_samples", {"digit":digit, "section":section + 1})
			digits[digit].sections[section].samples = _spread_samples(pool, CONTACT_SAMPLE_LIMIT, digits[digit].sections[section].peak_percent)
			per_section.append(digits[digit].sections[section].samples.size())
		counts.digits[digit] = per_section
	if palm_samples.is_empty(): return _fail("missing_identified_palm_samples")
	palm_samples = _spread_samples(palm_samples, PALM_SAMPLE_LIMIT, 50.0)
	counts.palm = palm_samples.size()
	return {"valid":true, "digits":digits, "palm_samples":palm_samples, "safety_samples":safety,
		"safety_triangle_ids":triangles, "used_vertex_ids":PackedInt32Array(used.keys()), "sample_counts":counts}


## Thumb opposition remains an actuator with physical safety checks, but only
## S2/S3 attract. Their positions have no authored longitudinal preference yet.
func _attraction_enabled(digit: StringName, section: int) -> bool:
	return section >= 0 and section < 3 and (digit != &"thumb" or section > 0)


func _preference_bell(digit: StringName, section: int, percent: float) -> float:
	if digit == &"thumb": return 1.0
	if section < 0 or percent < 0.0: return 0.0
	return exp(-0.5 * pow((percent - PEAKS[section]) / SPREAD, 2.0))


func _caps(slot: StringName) -> Dictionary:
	var side: Dictionary = Rules.get_surface_solver_side_rules(slot)
	var result := {}
	var spatial := Spatial.new()
	for rule: Dictionary in side.get("digits", []):
		var cap: float = side.max_overlap_meters
		if rule.is_thumb: cap = minf(maxf(cap, rule.section_target_overlaps_meters[1] + Spatial.SECTION_TARGET_TOLERANCE_METERS), Spatial.THUMB_PROXIMAL_MAX_ALLOWED_OVERLAP_METERS)
		for section: int in 3:
			result[rule.bone_names[section]] = spatial._resolve_serial_section_max_allowed_overlap(rule, section, rule.section_target_overlaps_meters[section], cap)
	return result


func _blend_weights(ids: PackedInt32Array, bary: Vector3, weights: Array) -> Dictionary:
	var result := {}
	for corner: int in 3:
		for bone: Variant in weights[ids[corner]]:
			result[bone] = float(result.get(bone, 0.0)) + float(weights[ids[corner]][bone]) * bary[corner]
	return result


func _in_palm(prepared: Dictionary, source: String, bary: Vector3) -> bool:
	if not prepared.faces.has(source): return false
	var face: Dictionary = prepared.faces[source]
	var point: Vector2 = face.reference_polygon_m[0] * bary.x + face.reference_polygon_m[1] * bary.y + face.reference_polygon_m[2] * bary.z
	for domain: PackedVector2Array in face.domains_m:
		if Geometry2D.is_point_in_polygon(point, domain): return true
	return false


## Distances run over real source-mesh edges. Boundary seeds are interpolated
## at positive original-weight equality, including exact split-render aliases.
## This is a prepared 3D surface coordinate, NOT a bone-length percentage and
## NOT numerically identical to the retired live-slice contour arclength.
func _surface_field(bone: StringName, proximal: StringName, distal: StringName, weights: Array,
		points: PackedVector3Array, edges: Dictionary, terminal_start: Vector3, terminal_tip: Vector3) -> Dictionary:
	var graph := {}
	for pair: Array in edges.values():
		for id: int in pair:
			if graph.has(id): continue
			var own: float = weights[id].get(bone, 0.0)
			if own <= 0.0: continue
			var dominant := true
			for other: Variant in weights[id]:
				if float(weights[id][other]) > own + EPS_M: dominant = false; break
			if dominant: graph[id] = {}
	var first := {}
	var last := {}
	for pair: Array in edges.values():
		var a: int = pair[0]; var b: int = pair[1]
		var length_m := points[a].distance_to(points[b])
		if length_m <= EPS_M: continue
		if graph.has(a) and graph.has(b): graph[a][b] = length_m; graph[b][a] = length_m
		_seed_boundary(first, graph, a, b, length_m, weights, bone, proximal)
		if distal != &"": _seed_boundary(last, graph, a, b, length_m, weights, bone, distal)
	if distal == &"":
		var axis := (terminal_tip - terminal_start).normalized()
		var farthest := -INF
		for id: int in graph: farthest = maxf(farthest, (points[id] - terminal_start).dot(axis))
		for id: int in graph:
			if farthest - (points[id] - terminal_start).dot(axis) <= EPS_M: last[id] = 0.0
	if first.is_empty() or last.is_empty(): return {"valid":false, "reason":"missing_original_influence_boundary"}
	return {"valid":true, "proximal":_distances(graph, first), "distal":_distances(graph, last)}


func _seed_boundary(seeds: Dictionary, graph: Dictionary, a: int, b: int, length_m: float,
		weights: Array, own: StringName, neighbor: StringName) -> void:
	var a_delta: float = float(weights[a].get(own, 0.0)) - float(weights[a].get(neighbor, 0.0))
	var b_delta: float = float(weights[b].get(own, 0.0)) - float(weights[b].get(neighbor, 0.0))
	if a_delta * b_delta > 0.0: return
	if a_delta == b_delta:
		if float(weights[a].get(own, 0.0)) > 0.0 and graph.has(a): seeds[a] = 0.0
		if float(weights[b].get(own, 0.0)) > 0.0 and graph.has(b): seeds[b] = 0.0
		return
	var t: float = a_delta / (a_delta - b_delta)
	var weight: float = lerpf(weights[a].get(own, 0.0), weights[b].get(own, 0.0), t)
	if weight <= 0.0: return
	if graph.has(a): seeds[a] = minf(float(seeds.get(a, INF)), length_m * t)
	if graph.has(b): seeds[b] = minf(float(seeds.get(b, INF)), length_m * (1.0 - t))


func _distances(graph: Dictionary, seeds: Dictionary) -> Dictionary:
	var distance := seeds.duplicate()
	var pending := graph.duplicate()
	while not pending.is_empty():
		var selected := -1
		var nearest := INF
		for id: int in pending:
			if float(distance.get(id, INF)) < nearest: nearest = distance[id]; selected = id
		if selected < 0: break
		pending.erase(selected)
		for other: int in graph[selected]:
			if pending.has(other): distance[other] = minf(float(distance.get(other, INF)), nearest + float(graph[selected][other]))
	return distance


func _coordinate(field: Dictionary, ids: PackedInt32Array, bary: Vector3, points: PackedVector3Array, aliases: PackedInt32Array) -> Dictionary:
	if not field.get("valid", false): return {"percent":-1.0, "length_m":0.0}
	var point := points[ids[0]] * bary.x + points[ids[1]] * bary.y + points[ids[2]] * bary.z
	var proximal := INF
	var distal := INF
	for corner: int in 3:
		var id: int = aliases[ids[corner]]
		var offset := point.distance_to(points[id])
		proximal = minf(proximal, float(field.proximal.get(id, INF)) + offset)
		distal = minf(distal, float(field.distal.get(id, INF)) + offset)
	var length_m := proximal + distal
	if not is_finite(length_m) or length_m <= EPS_M: return {"percent":-1.0, "length_m":0.0}
	return {"percent":100.0 * clampf(proximal / length_m, 0.0, 1.0), "length_m":length_m}


## Deterministic, geometry-spread representatives. Start nearest the soft peak
## when one exists, otherwise use source order without a percentage preference;
## then fill gaps across the actual pad. Every result remains a mesh carrier.
func _spread_samples(pool: Array, limit: int, peak: float) -> Array:
	if pool.size() <= limit: return pool.duplicate()
	var selected: Array = []
	var first := 0
	var error := INF
	for index: int in pool.size():
		if peak < 0.0: break
		var difference := absf(float(pool[index].percent) - peak) if float(pool[index].percent) >= 0.0 else INF
		if difference < error: error = difference; first = index
	selected.append(pool[first])
	var indices := {first:true}
	while selected.size() < limit:
		var next := -1
		var largest := -1.0
		for index: int in pool.size():
			if indices.has(index): continue
			var nearest := INF
			for taken: Dictionary in selected:
				nearest = minf(nearest, (pool[index].reference_point_metric as Vector3).distance_squared_to(taken.reference_point_metric))
			if nearest > largest: largest = nearest; next = index
		if next < 0 or largest <= EPS_M * EPS_M: break
		selected.append(pool[next]); indices[next] = true
	return selected


func _fail(reason: String, detail: Dictionary = {}) -> Dictionary:
	return {"valid":false, "revision":REVISION, "reason":reason, "detail":detail,
		"production_pose_written":false, "live_slice_performed":false, "actual_3d_grip_verified":false}
