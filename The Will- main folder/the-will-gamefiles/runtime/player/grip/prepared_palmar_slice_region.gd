extends RefCounted

const HandSkin = preload("res://runtime/player/grip/prepared_hand_skin_query.gd")
const Palmar = preload("res://runtime/player/grip/palmar_reference_geometry.gd")
const ROOT := &"RL_BoneRoot"
const REVISION := &"clipped_reference_palmar_core_regions_v2"
const PALM_CAP_M := 0.0025
const EPSILON_M := 0.0000001
const POLYGON_SCALE := 100000.0


## Diagnostic region preparation, not a full palm segmentation or solid proof.
## The reference skeleton determines a core footprint and authored closing side.
## Original skin faces must also be the first positive surface over that core;
## skin weights alone never establish palmar orientation or anatomical position.
func prepare(context: Dictionary, definition: Resource) -> Dictionary:
	var started := Time.get_ticks_usec()
	if definition == null or not context.get("adapter") is Dictionary:
		return _fail("missing_context_or_definition")
	var adapter: Dictionary = context.adapter
	if not adapter.get("valid", false) or not adapter.get("skin_prepared") is Dictionary or not adapter.get("base_packet") is Dictionary:
		return _fail("missing_prepared_coherent_skin")
	var signature := str(definition.get("source_signature"))
	if signature.is_empty() or signature != adapter.get("anatomy_signature"):
		return _fail("palm_anatomy_signature_mismatch")
	var skin: Dictionary = adapter.skin_prepared
	var machine: Variant = adapter.base_packet.get("machine_to_world")
	if not machine is Transform3D or not HandSkin.new()._valid_frame(machine):
		return _fail("missing_reference_presentation")
	var preparer := Palmar.new()
	var metric: Dictionary = preparer._validate_metric(definition.source_manifest.get("character_metric", {}), machine)
	if not metric.get("valid", false): return metric
	var source: Dictionary = preparer._validate_reference_hashes(definition.reference_skin, definition.source_manifest)
	if not source.get("valid", false): return source
	var mapping := {}
	for bone: StringName in skin.bind_bone_names: mapping[bone] = bone
	var packet := {"anatomy_signature": signature, "root_origin_id": ROOT,
		"pose_id": &"PalmarSliceReferenceRest", "resolve_phase": &"bake_time",
		"machine_to_world": machine, "origin_records": skin.reference_origin_records.duplicate(true),
		"bone_origin_ids": mapping, "mesh_origin_id": skin.reference_vertices_origin_id}
	var posed: Dictionary = HandSkin.new().pose(skin, packet)
	if not posed.get("valid", false): return posed
	var checked: Dictionary = HandSkin.new()._registry(packet.origin_records, &"bake_time")
	if not checked.get("valid", false): return checked
	var slot: StringName = context.get("slot", &"")
	var core: Dictionary = preparer._measure_slot(slot, skin, posed, checked.registry, machine)
	# Partial paired-ray coverage does not invalidate the independently derived
	# bone footprint/polarity. It also must never become a complete-palm claim.
	if not core.get("origin_record") is Dictionary or not core.has("closing_evidence"):
		return _fail("missing_unambiguous_reference_palmar_frame")
	var hand: StringName = core.hand_bone_name
	var hand_world: Transform3D = machine * checked.registry.resolve_transform_to_machine(hand)
	var frame: Transform3D = hand_world * core.origin_record.transform_to_parent
	var inverse := frame.affine_inverse()
	var footprint := PackedVector2Array()
	for bone: StringName in core.footprint_bone_origin_ids:
		var point: Vector3 = inverse * (machine * checked.registry.resolve_transform_to_machine(bone)).origin
		footprint.append(Vector2(point.x, point.y))
	var points: PackedVector3Array = inverse * (posed.vertices_world as PackedVector3Array)
	var hand_weights := PackedFloat64Array()
	var totals := PackedFloat64Array()
	var foreign_weights := PackedFloat64Array()
	var contributors: Array[Dictionary] = []
	hand_weights.resize(skin.vertex_count); totals.resize(skin.vertex_count); foreign_weights.resize(skin.vertex_count)
	for vertex: int in range(skin.vertex_count):
		var weights := {}
		for influence: int in range(skin.vertex_offsets[vertex], skin.vertex_offsets[vertex + 1]):
			var weight: float = skin.influence_weights[influence]
			var bone: StringName = skin.bind_bone_names[skin.influence_binds[influence]]
			weights[bone] = float(weights.get(bone, 0.0)) + weight
			totals[vertex] += weight
			if bone == hand: hand_weights[vertex] += weight
			if bone != hand and not adapter.descendant_bones.has(bone): foreign_weights[vertex] += weight
		contributors.append(weights)
	var compiled := _compile(points, skin.triangle_indices, skin.triangle_surface_ids,
		skin.triangle_local_ids, hand_weights, totals, footprint, foreign_weights, contributors)
	if not compiled.get("valid", false): return compiled
	compiled.merge({"revision": REVISION, "anatomy_signature": signature, "slot": slot,
		"source_pose_id": adapter.base_packet.pose_id, "hand_bone_name": hand,
		"vertex_count": skin.vertex_count, "triangle_indices": skin.triangle_indices,
		"triangle_surface_ids": skin.triangle_surface_ids, "triangle_local_ids": skin.triangle_local_ids,
		"reference_frame_origin_id": core.frame_origin_id,
		"reference_origin_records": packet.origin_records + [core.origin_record],
		"footprint_m": footprint, "footprint_origin_id": core.frame_origin_id,
		"closing_evidence": core.closing_evidence, "paired_core_samples_complete": core.get("complete", false),
		"paired_core_accepted_sample_count": core.get("accepted_sample_count", 0),
		"max_inward_depth_m": PALM_CAP_M,
		"complete_palm_partition_verified": false, "solid_enclosure_verified": false,
		"coverage": "clipped_first_positive_reference_surface_inside_bone_triangle_only",
		"ownership_evidence": "geometric_palmar_core_plus_positive_Hand_and_same_hand_subtree_contributors",
		"preparation_ms": float(Time.get_ticks_usec() - started) / 1000.0}, true)
	return compiled


## Preserve edge identity, geometry, original weights and digit ownership. Only
## attributable portions of unowned faces receive palm policy. The source edge
## is partitioned at exact reference-domain crossings; the skin is never moved.
func annotate(prepared: Dictionary, candidate: Dictionary, slice: Dictionary, plane_to_world: Transform3D) -> Dictionary:
	if not prepared.get("valid", false) or prepared.get("revision") != REVISION:
		return _fail("invalid_prepared_palmar_core")
	if not candidate.get("valid", false) or not candidate.get("posed") is Dictionary or not candidate.get("pose_packet") is Dictionary or not slice.get("valid", false):
		return _fail("invalid_palm_candidate_or_slice")
	var packet: Dictionary = candidate.pose_packet
	var posed: Dictionary = candidate.posed
	if packet.get("anatomy_signature") != prepared.anatomy_signature or posed.get("anatomy_signature") != prepared.anatomy_signature or packet.get("source_pose_id") != prepared.source_pose_id:
		return _fail("palm_source_identity_mismatch")
	if packet.get("root_origin_id") != ROOT or posed.get("resolved_world_origin_id") != ROOT or not posed.get("all_contributing_poses_supplied", false) or posed.get("weights_normalized_by_tool", true):
		return _fail("palm_missing_original_weight_pose")
	if posed.get("triangle_indices") != prepared.triangle_indices or posed.get("triangle_surface_ids") != prepared.triangle_surface_ids or posed.get("triangle_local_ids") != prepared.triangle_local_ids or not posed.get("vertices_world") is PackedVector3Array or posed.vertices_world.size() != prepared.vertex_count:
		return _fail("palm_source_topology_mismatch")
	if slice.get("slot") != prepared.slot or slice.get("pose_id") != packet.get("pose_id") or posed.get("pose_id") != packet.get("pose_id") or not slice.get("segments") is Array:
		return _fail("palm_slice_pose_or_slot_mismatch")
	if not HandSkin.new()._valid_frame(plane_to_world) or not packet.get("machine_to_world") is Transform3D:
		return _fail("invalid_palmar_slice_frame")
	var checked: Dictionary = HandSkin.new()._registry(packet.get("origin_records", []), packet.get("resolve_phase", &""))
	if not checked.get("valid", false) or not checked.registry.has_origin(slice.get("plane_origin_id", &"")):
		return _fail("missing_registered_palmar_slice_plane")
	var resolved: Transform3D = packet.machine_to_world * checked.registry.resolve_transform_to_machine(slice.plane_origin_id)
	if _frame_error(resolved, plane_to_world) > 0.00001:
		return _fail("palmar_slice_plane_frame_mismatch")
	var output: Dictionary = slice.duplicate(false)
	var edges: Array[Dictionary] = []
	var palm_indices: Array[int] = []
	var unassigned := 0
	var owned: Array = [[], [], []]
	for original_index: int in range(slice.segments.size()):
		var original: Dictionary = slice.segments[original_index]
		if original.get("origin_id") != slice.plane_origin_id:
			return _fail("palmar_edge_origin_mismatch")
		var source_id := "%d/%d" % [int(original.get("surface_index", -1)), int(original.get("surface_triangle_index", -1))]
		var fragments: Array[Dictionary] = [original.duplicate(true)]
		if int(original.get("section_owner", -1)) == -1 and prepared.faces.has(source_id):
			var split: Dictionary = _fragment_edge(original, prepared.faces[source_id], posed.vertices_world, plane_to_world)
			if not split.get("valid", false): return split
			fragments = split.fragments
		for edge: Dictionary in fragments:
			edge["original_segment_index"] = original_index
			edge["original_source_id"] = original.get("source_id", source_id)
			if edge.has("palmar_reference_a_m"): edge["palmar_reference_origin_id"] = prepared.reference_frame_origin_id
			if edge.get("palm_owned", false):
				edge["section_id"] = &"palm"
				edge["max_inward_depth_m"] = PALM_CAP_M
				edge["allowance_unassigned"] = false
				edge["palmar_region_revision"] = REVISION
				edge["palmar_source_face_id"] = source_id
				edge["palmar_reference_origin_id"] = prepared.reference_frame_origin_id
				edge["palmar_source_vertex_contributors"] = prepared.faces[source_id].source_vertex_contributors
				edge["palm_partition_complete"] = false
				palm_indices.append(edges.size())
			var owner := int(edge.get("section_owner", -1))
			if owner >= 0 and owner < 3: owned[owner].append(edges.size())
			unassigned += int(edge.get("allowance_unassigned", true))
			edges.append(edge)
	output["segments"] = edges
	output["palm_owned"] = palm_indices
	output["owned"] = owned
	output["unassigned_segment_count"] = unassigned
	output["palm_region_coverage"] = prepared.coverage
	output["complete_palm_partition_verified"] = false
	output["palm_counts_as_one_distinct_section"] = true
	return output


func _compile(points: PackedVector3Array, indices: PackedInt32Array, surfaces: PackedInt32Array, locals: PackedInt32Array, hand_weights: PackedFloat64Array, totals: PackedFloat64Array, footprint: PackedVector2Array, foreign_weights: PackedFloat64Array, contributors: Array = []) -> Dictionary:
	if indices.size() % 3 != 0 or surfaces.size() != indices.size() / 3 or locals.size() != surfaces.size() or points.size() != hand_weights.size() or totals.size() != points.size() or foreign_weights.size() != points.size() or footprint.size() != 3:
		return _fail("invalid_reference_core_arrays")
	if absf((footprint[1] - footprint[0]).cross(footprint[2] - footprint[0])) <= 1.0e-12:
		return _fail("degenerate_reference_core_footprint")
	var faces: Array[Dictionary] = []
	var candidates: Array[int] = []
	var rejected := {"outside_footprint_or_nonpalmar": 0, "missing_same_hand_source_evidence": 0, "fully_occluded_by_one_face": 0}
	for triangle: int in range(surfaces.size()):
		var p: Array[Vector3] = []
		var polygon := PackedVector2Array()
		var hands: Array[float] = []
		var foreign: Array[float] = []
		var source_contributors: Array = []
		for corner: int in range(3):
			var vertex := indices[triangle * 3 + corner]
			if vertex < 0 or vertex >= points.size() or not points[vertex].is_finite(): return _fail("invalid_reference_core_vertex")
			p.append(points[vertex]); polygon.append(Vector2(p[-1].x, p[-1].y))
			if not is_finite(hand_weights[vertex]) or not is_finite(totals[vertex]) or not is_finite(foreign_weights[vertex]) or totals[vertex] <= 0.0:
				return _fail("invalid_reference_influence_weights")
			hands.append(hand_weights[vertex] - 0.0000001)
			foreign.append(0.0000001 - foreign_weights[vertex])
			if contributors.size() == points.size(): source_contributors.append(contributors[vertex].duplicate())
		var cross := (polygon[1] - polygon[0]).cross(polygon[2] - polygon[0])
		if absf(cross) <= 1.0e-14: continue
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for point: Vector2 in polygon: bounds = bounds.expand(point)
		var face := {"source_id": "%d/%d" % [surfaces[triangle], locals[triangle]], "points": p,
			"vertex_indices": [indices[triangle * 3], indices[triangle * 3 + 1], indices[triangle * 3 + 2]],
			"polygon": polygon, "bounds": bounds, "max_z": maxf(p[0].z, maxf(p[1].z, p[2].z)),
			"source_vertex_contributors": source_contributors, "weights_normalized": false, "domains": []}
		faces.append(face)
		if face.max_z <= EPSILON_M: rejected.outside_footprint_or_nonpalmar += 1; continue
		var intersections: Array[PackedVector2Array] = Geometry2D.intersect_polygons(_scaled(polygon), _scaled(footprint))
		var geometry_found := false
		for raw: PackedVector2Array in intersections:
			var domain := _clip_positive(raw, face)
			if domain.size() < 3: continue
			geometry_found = true
			domain = _clip_field(domain, face, hands)
			domain = _clip_field(domain, face, foreign)
			if domain.size() >= 3: face.domains.append(_unscaled(domain))
		if not face.domains.is_empty(): candidates.append(faces.size() - 1)
		elif not geometry_found: rejected.outside_footprint_or_nonpalmar += 1
		else: rejected.missing_same_hand_source_evidence += 1
	var accepted := {}
	for candidate_index: int in candidates:
		var face: Dictionary = faces[candidate_index]
		var occluders: Array[PackedVector2Array] = []
		for other_index: int in range(faces.size()):
			if other_index == candidate_index: continue
			var other: Dictionary = faces[other_index]
			if other.max_z <= EPSILON_M or not (face.bounds as Rect2).intersects(other.bounds): continue
			var differences: Array[float] = []
			for point: Vector2 in face.polygon: differences.append(_height(face, point) - _height(other, point) - EPSILON_M)
			for domain: PackedVector2Array in face.domains:
				var overlap: Array[PackedVector2Array] = Geometry2D.intersect_polygons(_scaled(domain), _scaled(other.polygon))
				for raw: PackedVector2Array in overlap:
					var positive := _clip_positive(raw, other)
					var nearer := _clip_field(positive, face, differences)
					if nearer.size() >= 3: occluders.append(_unscaled(nearer))
		var domains: Array[PackedVector2Array] = []
		for domain: PackedVector2Array in face.domains:
			var hidden := false
			for occluder: PackedVector2Array in occluders:
				var all_inside := true
				for point: Vector2 in domain: all_inside = all_inside and Geometry2D.is_point_in_polygon(point, occluder)
				if all_inside: hidden = true; break
			if not hidden: domains.append(domain)
		if not domains.is_empty():
			accepted[face.source_id] = {"source_id": face.source_id, "vertex_indices": face.vertex_indices,
				"reference_polygon_m": face.polygon, "domains_m": domains, "occluders_m": occluders,
				"source_vertex_contributors": face.source_vertex_contributors, "weights_normalized": false,
				"whole_source_face_verified": false, "reference_first_positive_surface": true,
				"positive_Hand_and_same_hand_subtree": true}
		else: rejected.fully_occluded_by_one_face += 1
	return {"valid": true, "faces": accepted, "accepted_face_count": accepted.size(),
		"candidate_face_count": candidates.size(), "rejected_face_counts": rejected}


func _scaled(polygon: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in polygon: result.append(point * POLYGON_SCALE)
	return result


func _unscaled(polygon: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in polygon: result.append(point / POLYGON_SCALE)
	return result


func _height(face: Dictionary, point: Vector2) -> float:
	return _field(face, point, [float(face.points[0].z), float(face.points[1].z), float(face.points[2].z)])


func _field(face: Dictionary, point: Vector2, values: Array) -> float:
	var p: PackedVector2Array = face.polygon
	var offset := point - p[0]
	var u := p[1] - p[0]
	var v := p[2] - p[0]
	var denominator := u.cross(v)
	var b := offset.cross(v) / denominator
	var c := u.cross(offset) / denominator
	return float(values[0]) * (1.0 - b - c) + float(values[1]) * b + float(values[2]) * c


func _clip_positive(polygon: PackedVector2Array, face: Dictionary) -> PackedVector2Array:
	return _clip_field(polygon, face, [float(face.points[0].z) - EPSILON_M, float(face.points[1].z) - EPSILON_M, float(face.points[2].z) - EPSILON_M])


func _clip_field(polygon: PackedVector2Array, face: Dictionary, values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	if polygon.is_empty(): return result
	var previous: Vector2 = polygon[-1]
	var previous_value := _field(face, previous / POLYGON_SCALE, values)
	for current: Vector2 in polygon:
		var value := _field(face, current / POLYGON_SCALE, values)
		if (value >= 0.0) != (previous_value >= 0.0):
			result.append(previous.lerp(current, previous_value / (previous_value - value)))
		if value >= 0.0: result.append(current)
		previous = current; previous_value = value
	return result


## Mapping a posed source edge back through its triangle barycentrics preserves
## the exact source skin domain. This partitions observation edges, not the mesh.
func _fragment_edge(edge: Dictionary, face: Dictionary, vertices: PackedVector3Array, plane: Transform3D) -> Dictionary:
	var reference: Array[Vector2] = []
	var barycentrics: Array[Vector3] = []
	for key: String in ["a", "b"]:
		if not edge.get(key) is Vector2 or not (edge[key] as Vector2).is_finite(): return _fail("invalid_palmar_edge_point")
		var point: Vector2 = edge[key]
		var bary: Vector3 = _source_barycentric(plane * Vector3(point.x, point.y, 0), face, vertices)
		if not bary.is_finite(): return _fail("palmar_edge_does_not_match_current_source_face")
		barycentrics.append(bary)
		var polygon: PackedVector2Array = face.reference_polygon_m
		reference.append(polygon[0] * bary.x + polygon[1] * bary.y + polygon[2] * bary.z)
	var intervals: Array[Vector2] = []
	for domain: PackedVector2Array in face.domains_m:
		var interval := _inside_interval(reference[0], reference[1], domain, face.reference_polygon_m)
		if interval.is_finite(): intervals.append(interval)
	for occluder: PackedVector2Array in face.occluders_m:
		var blocked := _inside_interval(reference[0], reference[1], occluder)
		if not blocked.is_finite(): continue
		var remaining: Array[Vector2] = []
		for interval: Vector2 in intervals:
			if blocked.y <= interval.x or blocked.x >= interval.y: remaining.append(interval); continue
			if blocked.x > interval.x: remaining.append(Vector2(interval.x, minf(blocked.x, interval.y)))
			if blocked.y < interval.y: remaining.append(Vector2(maxf(blocked.y, interval.x), interval.y))
		intervals = remaining
	var cuts: Array[float] = [0.0, 1.0]
	for interval: Vector2 in intervals: cuts.append(clampf(interval.x, 0, 1)); cuts.append(clampf(interval.y, 0, 1))
	cuts.sort()
	var fragments: Array[Dictionary] = []
	for index: int in range(cuts.size() - 1):
		var lower: float = cuts[index]
		var upper: float = cuts[index + 1]
		if upper <= lower: continue
		var middle := (lower + upper) * 0.5
		var palm := false
		for interval: Vector2 in intervals: palm = palm or (middle >= interval.x and middle <= interval.y)
		var fragment := edge.duplicate(true)
		fragment.a = (edge.a as Vector2).lerp(edge.b, lower)
		fragment.b = (edge.a as Vector2).lerp(edge.b, upper)
		if edge.get("a_selected_weights") is Vector3 and edge.get("b_selected_weights") is Vector3:
			fragment.a_selected_weights = (edge.a_selected_weights as Vector3).lerp(edge.b_selected_weights, lower)
			fragment.b_selected_weights = (edge.a_selected_weights as Vector3).lerp(edge.b_selected_weights, upper)
		fragment["source_segment_t0"] = lower
		fragment["source_segment_t1"] = upper
		fragment["source_barycentric_a"] = barycentrics[0].lerp(barycentrics[1], lower)
		fragment["source_barycentric_b"] = barycentrics[0].lerp(barycentrics[1], upper)
		fragment["palm_owned"] = palm
		fragment["palmar_reference_a_m"] = reference[0].lerp(reference[1], lower)
		fragment["palmar_reference_b_m"] = reference[0].lerp(reference[1], upper)
		fragments.append(fragment)
	return _coalesce_unrepresentable_fragments(fragments)


## A reference-domain crossing can fall between two equal Float32 endpoints.
## Keep its complete scalar interval but join it to an adjacent representable
## edge. Mixed classifications retain the stricter original skin policy.
func _coalesce_unrepresentable_fragments(fragments: Array[Dictionary]) -> Dictionary:
	var result: Array[Dictionary] = []
	var pending: Dictionary = {}
	for raw: Dictionary in fragments:
		var fragment := raw.duplicate(true)
		if not pending.is_empty():
			fragment.a = pending.a
			fragment.source_segment_t0 = pending.source_segment_t0
			fragment.source_barycentric_a = pending.source_barycentric_a
			fragment.palmar_reference_a_m = pending.palmar_reference_a_m
			fragment.palm_owned = fragment.palm_owned and pending.palm_owned
			fragment["numeric_boundary_coalesced"] = true
			pending = {}
		if fragment.a == fragment.b:
			if result.is_empty(): pending = fragment
			else:
				var previous: Dictionary = result[-1]
				previous.b = fragment.b
				previous.source_segment_t1 = fragment.source_segment_t1
				previous.source_barycentric_b = fragment.source_barycentric_b
				previous.palmar_reference_b_m = fragment.palmar_reference_b_m
				previous.palm_owned = previous.palm_owned and fragment.palm_owned
				previous["numeric_boundary_coalesced"] = true
		else: result.append(fragment)
	if not pending.is_empty() or result.is_empty(): return _fail("unrepresentable_entire_palmar_source_edge")
	return {"valid": true, "fragments": result}


## Vector2 here contains scalar segment parameters (lower, upper), not a point.
func _inside_interval(a: Vector2, b: Vector2, polygon: PackedVector2Array, source_polygon: PackedVector2Array = PackedVector2Array()) -> Vector2:
	if polygon.size() < 3: return Vector2.INF
	var lower := 0.0
	var upper := 1.0
	var winding := -1.0 if Geometry2D.is_polygon_clockwise(polygon) else 1.0
	for index: int in range(polygon.size()):
		var start: Vector2 = polygon[index]
		var direction: Vector2 = polygon[(index + 1) % polygon.size()] - start
		var first := direction.cross(a - start) * winding
		var last := direction.cross(b - start) * winding
		# Only a boundary inherited from the original source triangle can receive
		# this numerical correction. Genuine footprint/occluder cuts stay strict.
		# Reconstructing a Float32 slice through world and reference frames can
		# put its endpoint nanometres outside that same source edge.
		if _is_source_boundary(start, start + direction, source_polygon):
			var tolerance := EPSILON_M * direction.length()
			if first < 0.0 and first >= -tolerance: first = 0.0
			if last < 0.0 and last >= -tolerance: last = 0.0
		if first < 0 and last < 0: return Vector2.INF
		if (first < 0) != (last < 0):
			var crossing := first / (first - last)
			if first < 0: lower = maxf(lower, crossing)
			else: upper = minf(upper, crossing)
		if upper <= lower: return Vector2.INF
	return Vector2(lower, upper)


func _is_source_boundary(a: Vector2, b: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() != 3: return false
	for index: int in range(3):
		var start: Vector2 = polygon[index]
		var direction: Vector2 = polygon[(index + 1) % 3] - start
		var length := direction.length()
		if length <= EPSILON_M: continue
		var delta_a := a - start
		var delta_b := b - start
		if absf(direction.cross(delta_a)) > EPSILON_M * length or absf(direction.cross(delta_b)) > EPSILON_M * length: continue
		var along_a := direction.dot(delta_a) / length
		var along_b := direction.dot(delta_b) / length
		if minf(along_a, along_b) >= -EPSILON_M and maxf(along_a, along_b) <= length + EPSILON_M: return true
	return false


func _frame_error(a: Transform3D, b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin), maxf(a.basis.x.distance_to(b.basis.x), maxf(a.basis.y.distance_to(b.basis.y), a.basis.z.distance_to(b.basis.z))))


func _source_barycentric(world: Vector3, face: Dictionary, vertices: PackedVector3Array) -> Vector3:
	var a: Vector3 = vertices[face.vertex_indices[0]]
	var u: Vector3 = vertices[face.vertex_indices[1]] - a
	var v: Vector3 = vertices[face.vertex_indices[2]] - a
	var uu := u.dot(u)
	var uv := u.dot(v)
	var vv := v.dot(v)
	var denominator := uu * vv - uv * uv
	if denominator <= 1.0e-20: return Vector3.INF
	var delta := world - a
	var b := (delta.dot(u) * vv - delta.dot(v) * uv) / denominator
	var c := (delta.dot(v) * uu - delta.dot(u) * uv) / denominator
	if b < -0.0001 or c < -0.0001 or b + c > 1.0001 or (a + u * b + v * c).distance_to(world) > 0.000002: return Vector3.INF
	var bary := Vector3(1.0 - b - c, b, c)
	if minf(bary.x, minf(bary.y, bary.z)) < 0.0:
		# These are interpolation coordinates, never the original bone weights.
		# Correct source-simplex roundoff only when both physical reconstructions
		# move by at most the existing numerical epsilon; actual skin stays put.
		var bounded := Vector3(maxf(bary.x, 0.0), maxf(bary.y, 0.0), maxf(bary.z, 0.0))
		bounded /= bounded.x + bounded.y + bounded.z
		var polygon: PackedVector2Array = face.reference_polygon_m
		var raw_reference := polygon[0] * bary.x + polygon[1] * bary.y + polygon[2] * bary.z
		var bounded_reference := polygon[0] * bounded.x + polygon[1] * bounded.y + polygon[2] * bounded.z
		if (u * (bounded.y - bary.y) + v * (bounded.z - bary.z)).length() <= EPSILON_M and raw_reference.distance_to(bounded_reference) <= EPSILON_M:
			bary = bounded
	return bary


func _fail(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason, "complete_palm_partition_verified": false}
