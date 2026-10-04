extends RefCounted

## Accessibility of one attraction connector in one CURRENT named digit plane.
## This is not a swept-motion, 3D self-collision or material-depth certificate.
## The original skin segments, physical ownership and overlap caps stay intact.
const REVISION := &"current_digit_plane_target_visibility_v1"
const EPSILON_M := 0.0000001


func prepare(skin: Dictionary, state: Dictionary) -> Dictionary:
	var origin: Variant = skin.get("plane_origin_id")
	if not skin.get("valid", false) or not _named(origin) or state.get("plane_origin_id") != origin:
		return _fail("missing_or_mismatched_named_digit_plane")
	var frame: Variant = state.get("plane_to_world")
	if not frame is Transform3D or not _metric_frame(frame): return _fail("invalid_metric_digit_plane")
	var segments: Variant = skin.get("segments")
	if not segments is Array or segments.is_empty(): return _fail("missing_current_skin_segments")
	var sources := {}
	for index: int in segments.size():
		var edge: Variant = segments[index]
		if not edge is Dictionary or edge.get("origin_id") != origin or not _named(edge.get("source_id")):
			return _fail("missing_skin_origin_or_source")
		if not _point(edge.get("a")) or not _point(edge.get("b")) or edge.a == edge.b:
			return _fail("invalid_current_skin_segment")
		var source := String(edge.source_id)
		if not sources.has(source): sources[source] = []
		sources[source].append(index)
	var world: Variant = state.get("joint_origins_world")
	if not world is Array or world.size() != 3 or not _world_point(state.get("tip_world")):
		return _fail("missing_finite_joint_chain_or_true_tip")
	var inverse: Transform3D = frame.affine_inverse()
	var chain: Array[Vector2] = []
	for value: Variant in world:
		if not _world_point(value): return _fail("invalid_world_joint_origin")
		chain.append(_project(inverse, value))
	chain.append(_project(inverse, state.tip_world))
	for index: int in 3:
		if chain[index].distance_to(chain[index + 1]) <= EPSILON_M:
			return _fail("degenerate_projected_joint_or_terminal_span")
	var wrist: Variant = null
	if state.get("hand_to_world") is Transform3D and _named(state.get("hand_origin_id")):
		var hand: Transform3D = state.hand_to_world
		if hand.origin.is_finite(): wrist = _project(inverse, hand.origin)
	return {"valid":true, "revision":REVISION, "plane_origin_id":origin,
		"segments":segments, "source_indices":sources, "joint_chain_m":chain, "wrist_m":wrist,
		"coordinate_origin_id":origin, "metric_units":&"meters", "physical_geometry_changed":false,
		"scope":&"current_slice_connector_only", "actual_3d_grip_verified":false}


func evaluate(prepared: Dictionary, edge: Dictionary, witness: Dictionary) -> Dictionary:
	if not prepared.get("valid", false) or prepared.get("revision") != REVISION:
		return _fail("invalid_prepared_visibility")
	var origin: Variant = prepared.plane_origin_id
	if edge.get("origin_id") != origin or witness.get("origin_id") != origin or not _named(edge.get("source_id")) or witness.get("source_id") != edge.source_id:
		return _fail("connector_origin_or_source_mismatch")
	if not witness.get("valid", true) or not _point(witness.get("skin_point_m")):
		return _fail("invalid_skin_witness")
	var target: Variant = witness.get("target_point_m", witness.get("circle_point_m"))
	if not _point(target): return _fail("missing_finite_target_point")
	if not _point(edge.get("a")) or not _point(edge.get("b")) or edge.a == edge.b:
		return _fail("invalid_source_edge")
	var found := false
	for index: int in prepared.source_indices.get(String(edge.source_id), []):
		if _same_segment(edge, prepared.segments[index]): found = true; break
	if not found: return _fail("source_edge_not_in_current_skin")
	if not edge.get("grip_attraction_eligible", false): return _blocked("source_is_not_gripping_surface")
	var p: Vector2 = witness.skin_point_m
	var q: Vector2 = target
	if p.distance_to(Geometry2D.get_closest_point_to_segment(p, edge.a, edge.b)) > EPSILON_M:
		return _fail("skin_witness_not_on_source_edge")
	var chain: Array = prepared.joint_chain_m
	# Bones include their finite ends. A skin witness on a bone is not exempt.
	for index: int in 3:
		if p == q:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, chain[index], chain[index + 1])) <= EPSILON_M:
				return _blocked("connector_intersects_joint_chain", {"bone_section":index + 1, "blocking_point_m":p})
			continue
		var hit := _intersection(p, q, chain[index], chain[index + 1])
		if not hit.is_empty():
			return _blocked("connector_intersects_joint_chain", {"bone_section":index + 1,
				"blocking_point_m":hit.point_m, "connector_fraction":hit.start_t})
	if p == q: return _allowed("coincident_eligible_contact")
	for other: Dictionary in prepared.segments:
		var hit := _intersection(p, q, other.a, other.b)
		if hit.is_empty(): continue
		if float(hit.end_t) * p.distance_to(q) <= EPSILON_M and _incident_at_start(edge, other, p): continue
		return _blocked("connector_intersects_other_skin", {"blocking_source_id":other.source_id,
			"blocking_point_m":hit.point_m, "connector_fraction":hit.start_t})
	# An inward connector may end inside tissue without crossing a second skin
	# edge. Orient this edge's perpendicular away from its OWN finite skeleton
	# span, rather than orienting it toward the desired weapon/guide position.
	var owner := int(edge.get("section_owner", -1))
	var bone_a: Vector2
	var bone_b: Vector2
	if owner >= 0 and owner < 3:
		bone_a = chain[owner]; bone_b = chain[owner + 1]
	elif edge.get("palm_owned", false) and _point(prepared.get("wrist_m")):
		bone_a = prepared.wrist_m; bone_b = chain[0]
		if bone_a.distance_to(bone_b) <= EPSILON_M: return _fail("degenerate_projected_palm_span")
	else:
		return _fail("missing_local_section_or_palm_span")
	var tangent: Vector2 = (edge.b - edge.a).normalized()
	var outward := Vector2(-tangent.y, tangent.x)
	var skeleton_point := Geometry2D.get_closest_point_to_segment(p, bone_a, bone_b)
	var side: float = outward.dot(p - skeleton_point)
	if absf(side) <= EPSILON_M: return _fail("ambiguous_source_surface_normal")
	outward *= signf(side)
	var approach_m: float = outward.dot(q - p)
	if approach_m < 0.0:
		var cap: Variant = edge.get("max_inward_depth_m")
		if not (cap is float or cap is int) or not is_finite(float(cap)) or float(cap) < 0.0:
			return _fail("missing_local_overlap_allowance")
		# A local pad correction is bounded by FULL connector length, not just
		# its normal projection. This cannot exempt a long tangential tissue path.
		# No epsilon is added to the existing cap; material safety still runs.
		if edge.get("allowance_unassigned", true) or p.distance_to(q) > float(cap):
			return _blocked("target_approaches_through_local_skin", {"approach_m":approach_m,
				"connector_length_m":p.distance_to(q), "local_cap_m":cap})
		return _allowed("local_pad_contact_within_existing_cap", {"approach_m":approach_m,
			"connector_length_m":p.distance_to(q), "local_cap_m":cap})
	return _allowed("accessible_from_gripping_surface", {"approach_m":approach_m})


## Godot's segment intersection excludes parallel/collinear pairs. For those,
## project only the collinear finite overlap; closest-pair evidence also catches
## endpoint contact within the established slice epsilon. No cap is enlarged.
func _intersection(p: Vector2, q: Vector2, a: Vector2, b: Vector2) -> Dictionary:
	var direction := q - p
	var length_m := direction.length()
	if length_m == 0.0: return {}
	var unit := direction / length_m
	if absf(unit.cross(a - p)) <= EPSILON_M and absf(unit.cross(b - p)) <= EPSILON_M:
		var a_t: float = unit.dot(a - p) / length_m
		var b_t: float = unit.dot(b - p) / length_m
		var lower := maxf(0.0, minf(a_t, b_t))
		var upper := minf(1.0, maxf(a_t, b_t))
		if lower <= upper: return {"start_t":lower, "end_t":upper, "point_m":p.lerp(q, lower)}
		return {}
	var point: Variant = Geometry2D.segment_intersects_segment(p, q, a, b)
	if point is Vector2 and (point as Vector2).distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)) <= EPSILON_M:
		var parameter := clampf(unit.dot((point as Vector2) - p) / length_m, 0.0, 1.0)
		return {"start_t":parameter, "end_t":parameter, "point_m":point}
	# Once nonparallel crossings are tested, a finite 2D closest pair includes
	# an endpoint. Use native point projections: the native segment-pair helper
	# treats squared lengths <= CMP_EPSILON as points, too coarse for these mm
	# skin edges (Godot 4.7 geometry_2d.h). This does not widen our own epsilon.
	var pairs: Array = [[p, Geometry2D.get_closest_point_to_segment(p, a, b)],
		[q, Geometry2D.get_closest_point_to_segment(q, a, b)],
		[Geometry2D.get_closest_point_to_segment(a, p, q), a],
		[Geometry2D.get_closest_point_to_segment(b, p, q), b]]
	for pair: Array in pairs:
		if (pair[0] as Vector2).distance_to(pair[1]) <= EPSILON_M:
			var parameter := clampf(unit.dot((pair[0] as Vector2) - p) / length_m, 0.0, 1.0)
			return {"start_t":parameter, "end_t":parameter, "point_m":pair[0]}
	return {}


func _incident_at_start(edge: Dictionary, other: Dictionary, p: Vector2) -> bool:
	if _same_segment(edge, other): return true
	# Adjacent fragments of one original triangle keep its source ID. They are
	# incident only at their shared actual endpoint, never by source ID alone.
	for first: String in ["a", "b"]:
		if (edge[first] as Vector2).distance_to(p) > EPSILON_M: continue
		for second: String in ["a", "b"]:
			if (other[second] as Vector2).distance_to(p) > EPSILON_M: continue
			if edge.source_id == other.source_id: return true
			var a_source: Dictionary = edge.get(first + "_source", {})
			var b_source: Dictionary = other.get(second + "_source", {})
			if not a_source.get("topology_ambiguous", false) and not b_source.get("topology_ambiguous", false) and _named(a_source.get("topology_key")) and a_source.get("topology_key") == b_source.get("topology_key"):
				return true
	return false


func _same_segment(first: Dictionary, second: Dictionary) -> bool:
	return first.source_id == second.source_id and ((first.a == second.a and first.b == second.b) or (first.a == second.b and first.b == second.a))


func _metric_frame(frame: Transform3D) -> bool:
	if not frame.is_finite(): return false
	var basis := frame.basis
	return absf(basis.x.length_squared() - 1.0) <= 0.00001 and absf(basis.y.length_squared() - 1.0) <= 0.00001 and absf(basis.z.length_squared() - 1.0) <= 0.00001 and absf(basis.x.dot(basis.y)) <= 0.00001 and absf(basis.x.dot(basis.z)) <= 0.00001 and absf(basis.y.dot(basis.z)) <= 0.00001


func _project(inverse: Transform3D, point: Vector3) -> Vector2:
	var local := inverse * point
	return Vector2(local.x, local.y)


func _point(value: Variant) -> bool:
	return value is Vector2 and (value as Vector2).is_finite()


func _world_point(value: Variant) -> bool:
	return value is Vector3 and (value as Vector3).is_finite()


func _named(value: Variant) -> bool:
	return (value is String or value is StringName) and not String(value).is_empty()


func _fail(reason: String) -> Dictionary:
	return {"valid":false, "accessible":false, "revision":REVISION, "reason":reason,
		"physical_geometry_changed":false, "actual_3d_grip_verified":false}


func _blocked(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"valid":true, "accessible":false, "revision":REVISION, "reason":reason, "details":details,
		"physical_geometry_changed":false, "actual_3d_grip_verified":false}


func _allowed(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"valid":true, "accessible":true, "revision":REVISION, "reason":reason, "details":details,
		"physical_geometry_changed":false, "actual_3d_grip_verified":false}
