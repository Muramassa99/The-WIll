extends RefCounted

## Analytic derivative of the existing coherent, blended skin slice. This is
## contact IK's local linearization, not another source of pose or skin geometry.
## Derivatives include original skin weights and moving triangle/plane cuts.
## The selected skin edge and nearest-point branch must be remeasured after a
## proposed step. A derivative does not certify a contact or swept movement.
const ROOT := &"RL_BoneRoot"
const REVISION := &"skin_contact_hinge_jacobian_v1"
const Candidate = preload("res://runtime/player/grip/prepared_hand_candidate_pose.gd")
const HandSkin = preload("res://runtime/player/grip/prepared_hand_skin_query.gd")
const Slice = preload("res://runtime/player/grip/weighted_skin_plane_slicer.gd")
const Palm = preload("res://runtime/player/grip/prepared_palmar_slice_region.gd")
const MATCH_EPSILON_M: float = 0.000002


func prepare(adapter: Dictionary, digit_id: StringName, palm_region: Dictionary = {}) -> Dictionary:
	if not adapter.get("valid", false) or adapter.get("revision") != Candidate.REVISION:
		return _fail("requires_prepared_hand_candidate")
	if not adapter.get("digit_inputs", {}).has(digit_id):
		return _fail("missing_prepared_digit")
	var skin: Dictionary = adapter.skin_prepared
	if skin.get("revision") != HandSkin.REVISION or skin.get("weights_normalized_by_tool", true):
		return _fail("requires_original_weighted_skin")
	var input: Dictionary = adapter.digit_inputs[digit_id]
	var snapshot: Dictionary = input.snapshot
	if not palm_region.is_empty():
		if not palm_region.get("valid", false) or palm_region.get("revision") != Palm.REVISION or palm_region.get("anatomy_signature") != adapter.anatomy_signature or palm_region.get("source_pose_id") != adapter.base_packet.pose_id or palm_region.get("slot") != adapter.slot:
			return _fail("palm_region_source_mismatch")
	if snapshot.bone_names.size() != 3 or snapshot.hinge_axes_local.size() != 3:
		return _fail("requires_three_prepared_hinges")
	var masks := PackedInt32Array()
	for name: StringName in skin.bind_bone_names:
		var mask: int = 0
		var current: StringName = name
		var visited: Dictionary = {}
		while current != ROOT:
			if current == &"" or visited.has(current) or not adapter.source_parent_ids.has(current):
				return _fail("missing_source_bone_ancestry")
			visited[current] = true
			var hinge: int = snapshot.bone_names.find(current)
			if hinge >= 0: mask |= 1 << hinge
			current = adapter.source_parent_ids[current]
		masks.append(mask)
	var triangles: Dictionary = {}
	for index: int in skin.triangle_count:
		var key: String = "%d/%d" % [skin.triangle_surface_ids[index], skin.triangle_local_ids[index]]
		if triangles.has(key): return _fail("duplicate_skin_triangle_source")
		triangles[key] = index
	return {"valid": true, "revision": REVISION, "digit_id": digit_id,
		"source_pose_id": adapter.base_packet.pose_id, "anatomy_signature": adapter.anatomy_signature,
		"resolve_phase": adapter.base_packet.resolve_phase, "machine_to_world": adapter.base_packet.machine_to_world,
		"plane_origin_id": input.plane_origin_id, "plane_to_world": input.plane_to_world,
		"bone_names": snapshot.bone_names.duplicate(), "hinge_axes_local": snapshot.hinge_axes_local.duplicate(),
		"hinge_axis_origin_ids": snapshot.hinge_axis_origin_ids.duplicate(),
		"skin": skin, "bind_hinge_masks": masks, "triangles": triangles, "palm_region": palm_region,
		"hand_to_world": adapter.baseline_hand_to_world, "production_pose_written": false}


## circle_witness is produced by planar_circle_skin_contact for skin_segment.
## Its nearest-point parameter may slide; only the current contact branch is
## linearized. The output vectors are meters/radian in origin_id's named plane.
func evaluate(prepared: Dictionary, candidate: Dictionary, skin_segment: Dictionary, circle_witness: Dictionary) -> Dictionary:
	return _evaluate_witness(prepared, candidate, skin_segment, circle_witness, true)


## Point kinematics for a caller-owned polygon/contact feature. No circle or
## assumed target normal is constructed. The parameter is held on the current
## sliced edge; the edge's endpoints still follow their moving triangle/plane
## and palmar-domain intersections. Thus this is NOT a fixed mesh vertex or
## fixed material barycentric point, nor a derivative of nearest-feature search.
func evaluate_point(prepared: Dictionary, candidate: Dictionary, skin_segment: Dictionary, skin_t: float) -> Dictionary:
	if not is_finite(skin_t) or skin_t < 0.0 or skin_t > 1.0:
		return _fail("invalid_skin_contact_parameter")
	if not skin_segment.get("a") is Vector2 or not skin_segment.get("b") is Vector2:
		return _fail("missing_skin_segment_endpoints")
	var witness := {"source_id":skin_segment.get("source_id"),"origin_id":skin_segment.get("origin_id"),
		"skin_segment_t":skin_t,"skin_point_m":(skin_segment.a as Vector2).lerp(skin_segment.b,skin_t)}
	return _evaluate_witness(prepared,candidate,skin_segment,witness,false)


func _evaluate_witness(prepared: Dictionary, candidate: Dictionary, skin_segment: Dictionary, circle_witness: Dictionary, circle_mode: bool) -> Dictionary:
	if not prepared.get("valid", false) or prepared.get("revision") != REVISION:
		return _fail("invalid_prepared_skin_jacobian")
	if not candidate.get("valid", false) or not candidate.get("posed") is Dictionary or not candidate.get("pose_packet") is Dictionary:
		return _fail("requires_coherent_candidate")
	var packet: Dictionary = candidate.pose_packet
	var posed: Dictionary = candidate.posed
	if packet.get("source_pose_id") != prepared.source_pose_id or packet.get("anatomy_signature") != prepared.anatomy_signature or posed.get("anatomy_signature") != prepared.anatomy_signature:
		return _fail("candidate_source_or_anatomy_mismatch")
	if packet.get("pose_id") != posed.get("pose_id") or packet.get("resolve_phase") != prepared.resolve_phase or posed.get("resolved_world_origin_id") != ROOT:
		return _fail("candidate_pose_or_frame_mismatch")
	if not packet.get("machine_to_world") is Transform3D or not _same_frame(packet.machine_to_world, prepared.machine_to_world):
		return _fail("candidate_machine_frame_changed")
	if not candidate.get("hand_to_world") is Transform3D or not _same_frame(candidate.hand_to_world, prepared.hand_to_world):
		return _fail("jacobian_requires_fixed_hand")
	if not candidate.get("digit_states", {}).has(prepared.digit_id):
		return _fail("candidate_missing_digit")
	var state: Dictionary = candidate.digit_states[prepared.digit_id]
	var plane: Transform3D = state.plane_to_world
	if state.plane_origin_id != prepared.plane_origin_id or not _same_frame(plane, prepared.plane_to_world):
		return _fail("jacobian_requires_same_fixed_named_digit_plane")
	var source: String = str(skin_segment.get("source_id", ""))
	if source.is_empty() or not prepared.triangles.has(source) or str(circle_witness.get("source_id", "")) != source:
		return _fail("contact_triangle_source_mismatch")
	if skin_segment.get("origin_id") != prepared.plane_origin_id or circle_witness.get("origin_id") != prepared.plane_origin_id:
		return _fail("contact_plane_origin_mismatch")
	if not circle_witness.get("skin_point_m") is Vector2:
		return _fail("missing_skin_contact_point")
	if circle_mode and (circle_witness.get("tangent_ambiguous", true) or not circle_witness.get("circle_outward_normal") is Vector2):
		return _fail("ambiguous_or_missing_circle_witness")
	var skin: Dictionary = prepared.skin
	if posed.get("triangle_indices") != skin.triangle_indices or not posed.get("bone_transforms_to_machine") is Dictionary:
		return _fail("candidate_skin_source_mismatch")
	var triangle: int = prepared.triangles[source]
	var points: Array[Vector3] = []
	var derivatives: Array = []
	var distances: Array[float] = []
	for corner: int in 3:
		var vertex: int = skin.triangle_indices[triangle * 3 + corner]
		var derivative: Dictionary = _vertex_derivatives(prepared, candidate, vertex)
		if not derivative.get("valid", false): return derivative
		var point: Vector3 = posed.vertices_world[vertex]
		points.append(point)
		derivatives.append(derivative.world_derivatives_m_per_rad)
		distances.append((point - plane.origin).dot(plane.basis.z))
	var cuts: Array = []
	var smooth: bool = not bool(skin_segment.get("coplanar", false))
	for corner: int in 3:
		var following: int = (corner + 1) % 3
		if absf(distances[corner]) <= Slice.EPSILON_M:
			smooth = false
			cuts.append(_cut(plane, points[corner], derivatives[corner], "on_plane_vertex"))
		if (distances[corner] > Slice.EPSILON_M and distances[following] < -Slice.EPSILON_M) or (distances[corner] < -Slice.EPSILON_M and distances[following] > Slice.EPSILON_M):
			var denominator: float = distances[corner] - distances[following]
			var ratio: float = distances[corner] / denominator
			var cut_derivatives: Array[Vector3] = []
			for hinge: int in 3:
				var first_derivative: Vector3 = derivatives[corner][hinge]
				var last_derivative: Vector3 = derivatives[following][hinge]
				var first_distance_derivative: float = first_derivative.dot(plane.basis.z)
				var last_distance_derivative: float = last_derivative.dot(plane.basis.z)
				var ratio_derivative: float = (first_distance_derivative * denominator - distances[corner] * (first_distance_derivative - last_distance_derivative)) / (denominator * denominator)
				cut_derivatives.append(first_derivative.lerp(last_derivative, ratio) + (points[following] - points[corner]) * ratio_derivative)
			cuts.append(_cut(plane, points[corner].lerp(points[following], ratio), cut_derivatives, "crossing_edge"))
	var first: Dictionary = _endpoint_cut(prepared, skin_segment, "a", cuts, plane, points, derivatives, distances)
	var last: Dictionary = _endpoint_cut(prepared, skin_segment, "b", cuts, plane, points, derivatives, distances)
	if not first.get("valid", false): return first
	if not last.get("valid", false): return last
	smooth = smooth and first.get("smooth", true) and last.get("smooth", true)
	var a: Vector2 = skin_segment.a
	var b: Vector2 = skin_segment.b
	var direction: Vector2 = b - a
	var length_squared: float = direction.length_squared()
	if length_squared <= Slice.EPSILON_M * Slice.EPSILON_M: return _fail("degenerate_contact_skin_edge")
	var t: float = float(circle_witness.skin_segment_t)
	if not is_finite(t) or t < 0.0 or t > 1.0: return _fail("invalid_skin_contact_parameter")
	var point: Vector2 = a.lerp(b, t)
	if point.distance_to(circle_witness.skin_point_m) > MATCH_EPSILON_M: return _fail("skin_witness_not_on_measured_edge")
	var normal: Vector2 = circle_witness.circle_outward_normal if circle_mode else Vector2.ZERO
	# These direction differences are needed only by the circle's sliding
	# nearest-point branch. Point mode does not invent a target or coordinate.
	var center_from_a: Vector2 = point - a - normal * float(circle_witness.distance_to_center_m) if circle_mode else Vector2.ZERO
	var numerator: float = center_from_a.dot(direction)
	var result: Array[Vector2] = []
	var clearance: Array[float] = []
	for hinge: int in 3:
		var da: Vector2 = first.derivatives_m_per_rad[hinge]
		var db: Vector2 = last.derivatives_m_per_rad[hinge]
		var dd: Vector2 = db - da
		var dt: float = 0.0
		if circle_mode and t > 0.0 and t < 1.0:
			var dn: float = -da.dot(direction) + center_from_a.dot(dd)
			dt = (dn * length_squared - numerator * 2.0 * direction.dot(dd)) / (length_squared * length_squared)
		var dp: Vector2 = da.lerp(db, t) + direction * dt
		if not dp.is_finite(): return _fail("nonfinite_skin_contact_derivative")
		result.append(dp)
		if circle_mode: clearance.append(normal.dot(dp))
	return {"valid": true, "revision": REVISION, "digit_id": prepared.digit_id,
		"origin_id": prepared.plane_origin_id, "source_id": source, "pose_id": packet.pose_id,
		"point_m": point, "derivatives_m_per_rad": result, "clearance_derivatives_m_per_rad": clearance,
		"hinge_origin_ids": prepared.bone_names.duplicate(), "skin_segment_t": t,
		"smooth_triangle_cut_branch": smooth, "nearest_point_branch": ("edge_interior" if t > 0.0 and t < 1.0 else "edge_endpoint") if circle_mode else "not_evaluated_fixed_parameter",
		"original_blended_weights_used": true, "triangle_plane_cut_derivative_included": true,
		"nearest_point_sliding_derivative_included": circle_mode, "finite_difference_evaluations": 0,
		"derivative_scope": &"circle_nearest_point_on_current_skin_edge" if circle_mode else &"current_slice_segment_at_fixed_parameter",
		"fixed_material_barycentric_derivative": false,
		"palmar_reference_clip_derivative_included": first.get("reference_clip", false) or last.get("reference_clip", false),
		"contact_preservation_verified": false, "production_pose_written": false}


func _vertex_derivatives(prepared: Dictionary, candidate: Dictionary, vertex: int) -> Dictionary:
	var out: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var skin: Dictionary = prepared.skin
	var machine: Transform3D = candidate.pose_packet.machine_to_world
	var frames: Dictionary = candidate.posed.bone_transforms_to_machine
	var state: Dictionary = candidate.digit_states[prepared.digit_id]
	for influence: int in range(skin.vertex_offsets[vertex], skin.vertex_offsets[vertex + 1]):
		var bind: int = skin.influence_binds[influence]
		var mask: int = prepared.bind_hinge_masks[bind]
		if mask == 0: continue
		var name: StringName = skin.bind_bone_names[bind]
		if not frames.has(name): return _fail("missing_contributing_bone_frame")
		var frame: Transform3D = machine * (frames[name] as Transform3D)
		var weight: float = skin.influence_weights[influence]
		var weighted_position: Vector3 = frame.basis * (skin.weighted_bind_points[influence] as Vector3) + frame.origin * weight
		for hinge: int in 3:
			if (mask & (1 << hinge)) == 0: continue
			if prepared.hinge_axis_origin_ids[hinge] != prepared.bone_names[hinge]: return _fail("hinge_axis_origin_mismatch")
			var joint: Transform3D = state.joint_transforms_world[hinge]
			if not joint.is_finite() or absf(joint.basis.determinant()) <= 1.0e-12: return _fail("invalid_hinge_frame")
			var axis: Vector3 = (prepared.hinge_axes_local[hinge] as Vector3).normalized()
			# B * [axis]x * B^-1 remains correct for affine ancestor scales;
			# a normalized world-axis cross product would silently discard them.
			var lever: Vector3 = joint.basis.inverse() * (weighted_position - joint.origin * weight)
			out[hinge] += joint.basis * axis.cross(lever)
	return {"valid": true, "world_derivatives_m_per_rad": out, "world_derivative_origin_id": ROOT}


func _cut(plane: Transform3D, point: Vector3, derivatives: Array, branch: String) -> Dictionary:
	var projected: Array[Vector2] = []
	for derivative: Vector3 in derivatives:
		projected.append(Vector2(derivative.dot(plane.basis.x), derivative.dot(plane.basis.y)))
	var relative: Vector3 = point - plane.origin
	return {"valid": true, "point_m": Vector2(relative.dot(plane.basis.x), relative.dot(plane.basis.y)),
		"derivatives_m_per_rad": projected, "branch": branch}


## A palmar fragment boundary is a line in the immutable reference triangle.
## Its barycentrics satisfy sum(b)=1, q.dot(b)=0 and h.dot(b)=0, where h are
## current vertex distances to the fixed slice plane. Differentiate all three:
## sum(db)=0, q.dot(db)=0, h.dot(db)=-dh.dot(b). This includes the changing
## clipping fraction; holding source_segment_t fixed would lose that motion.
func _endpoint_cut(prepared: Dictionary, edge: Dictionary, endpoint: String, cuts: Array, plane: Transform3D,
		points: Array[Vector3], derivatives: Array, distances: Array[float]) -> Dictionary:
	var parameter_key: String = "source_segment_t0" if endpoint == "a" else "source_segment_t1"
	var fraction: float = float(edge.get(parameter_key, 0.0 if endpoint == "a" else 1.0))
	if fraction <= 0.0 or fraction >= 1.0:
		var original: Dictionary = _matching_cut(cuts, edge[endpoint])
		return original if not original.is_empty() else _fail("measured_skin_edge_not_reconstructed_from_source_triangle")
	var source: String = str(edge.get("original_source_id", edge.get("source_id", "")))
	var region: Dictionary = prepared.palm_region
	if region.is_empty() or not region.get("faces", {}).has(source): return _fail("clipped_skin_edge_requires_matching_palmar_reference_face")
	var face: Dictionary = region.faces[source]
	var bary_key: String = "source_barycentric_" + endpoint
	if not edge.get(bary_key) is Vector3: return _fail("clipped_skin_edge_missing_source_barycentrics")
	var bary: Vector3 = edge[bary_key]
	var polygon: PackedVector2Array = face.reference_polygon_m
	var reference: Vector2 = polygon[0] * bary.x + polygon[1] * bary.y + polygon[2] * bary.z
	var world: Vector3 = points[0] * bary.x + points[1] * bary.y + points[2] * bary.z
	var relative: Vector3 = world - plane.origin
	var projected := Vector2(relative.dot(plane.basis.x), relative.dot(plane.basis.y))
	if projected.distance_to(edge[endpoint]) > MATCH_EPSILON_M: return _fail("clipped_skin_barycentric_point_mismatch")
	var fields: Array[Vector3] = []
	var boundaries: Array = face.domains_m.duplicate()
	boundaries.append_array(face.occluders_m)
	for boundary: PackedVector2Array in boundaries:
		for index: int in boundary.size():
			var start: Vector2 = boundary[index]
			var direction: Vector2 = boundary[(index + 1) % boundary.size()] - start
			var length_squared: float = direction.length_squared()
			if length_squared <= 1.0e-20: continue
			var nearest: Vector2 = start + direction * clampf((reference - start).dot(direction) / length_squared, 0.0, 1.0)
			if nearest.distance_to(reference) > MATCH_EPSILON_M: continue
			var q := Vector3(direction.cross(polygon[0] - start), direction.cross(polygon[1] - start), direction.cross(polygon[2] - start))
			if q.length_squared() <= 1.0e-30: continue
			fields.append(q.normalized())
	if fields.is_empty(): return _fail("clipped_skin_reference_boundary_not_identified")
	var heights := Vector3(distances[0], distances[1], distances[2])
	var selected: Array = []
	for field: Vector3 in fields:
		var direction: Vector3 = Vector3.ONE.cross(field)
		var denominator: float = heights.dot(direction)
		if absf(denominator) <= 1.0e-12: return _fail("clipped_skin_boundary_parallel_to_slice")
		var values: Array[Vector3] = []
		for hinge: int in 3:
			var first_derivative: Vector3 = derivatives[0][hinge]
			var middle_derivative: Vector3 = derivatives[1][hinge]
			var last_derivative: Vector3 = derivatives[2][hinge]
			var height_derivatives := Vector3(first_derivative.dot(plane.basis.z), middle_derivative.dot(plane.basis.z), last_derivative.dot(plane.basis.z))
			var db: Vector3 = direction * (-height_derivatives.dot(bary) / denominator)
			# sum(db)=0: use relative edges to avoid multiplying world-position
			# translations by cancelling floating-point barycentric derivatives.
			values.append(first_derivative * bary.x + middle_derivative * bary.y + last_derivative * bary.z
				+ (points[1] - points[0]) * db.y + (points[2] - points[0]) * db.z)
		if selected.is_empty(): selected = values
		else:
			for hinge: int in 3:
				if (selected[hinge] as Vector3).distance_to(values[hinge]) > 0.00001:
					return _fail("clipped_skin_reference_corner_has_multiple_derivatives")
	var result: Dictionary = _cut(plane, world, selected, "moving_palmar_reference_boundary")
	result["reference_clip"] = true
	result["smooth"] = fields.size() == 1
	return result


func _matching_cut(cuts: Array, point: Vector2) -> Dictionary:
	var selected: Dictionary = {}
	var distance: float = MATCH_EPSILON_M
	for cut: Dictionary in cuts:
		var current: float = point.distance_to(cut.point_m)
		if current <= distance:
			selected = cut
			distance = current
	return selected


func _same_frame(a: Transform3D, b: Transform3D) -> bool:
	return a.is_finite() and b.is_finite() and a.origin.distance_to(b.origin) <= MATCH_EPSILON_M and a.basis.x.distance_to(b.basis.x) <= MATCH_EPSILON_M and a.basis.y.distance_to(b.basis.y) <= MATCH_EPSILON_M and a.basis.z.distance_to(b.basis.z) <= MATCH_EPSILON_M


func _fail(reason: String) -> Dictionary:
	return {"valid": false, "revision": REVISION, "reason": reason, "production_pose_written": false}
