extends RefCounted

const SliceScript = preload("res://core/resolvers/primary_grip_seat_resolver.gd")
const DISTANCE_EPSILON: float = SliceScript.SLICE_DISTANCE_EPSILON_METERS

## Candidate geometry only. The caller retains the complete surface for 3D checks.
## Plane axes are orthonormal: returned coordinates and reach are physical meters.
func slice(surface: Dictionary, plane_to_world: Transform3D, plane_origin_id: StringName, reach_m: float, skin_padding_m: float) -> Dictionary:
	var result := {"valid": false, "segments": [], "contours": [], "origin_id": plane_origin_id,
		"reach_m": reach_m, "skin_padding_m": skin_padding_m, "classification_incomplete": true,
		"counts": {}, "status": "invalid_input"}
	if plane_origin_id == StringName() or not _valid_plane(plane_to_world):
		result["status"] = "invalid_plane_origin_or_metric_frame"
		return result
	if not is_finite(reach_m) or reach_m <= 0.0 or not is_finite(skin_padding_m) or skin_padding_m < 0.0:
		return result
	var radius: float = reach_m + skin_padding_m
	if not is_finite(radius) or not is_finite(radius * radius):
		return result
	if not bool(surface.get("valid", false)) or not surface.get("triangles_world") is PackedVector3Array:
		return result
	if StringName(surface.get("surface_source_origin_id", &"")) == StringName() or StringName(surface.get("resolved_world_origin_id", &"")) == StringName():
		result["status"] = "missing_surface_origins"
		return result
	var triangles: PackedVector3Array = surface["triangles_world"]
	if triangles.is_empty() or triangles.size() % 3 != 0:
		return result
	var counts := {"triangles_total": triangles.size() / 3, "triangles_visited": 0,
		"triangles_reach_pruned": 0, "triangles_local": 0, "triangles_intersected": 0,
		"coplanar_triangles": 0, "segments_before_clip": 0, "segments_clipped": 0,
		"segments_outside_disk": 0, "segments_emitted": 0, "contours_closed": 0,
		"open_or_branched_vertices": 0, "bvh_used": false}
	result["counts"] = counts
	var points: Array[Vector2] = []
	var buckets: Dictionary = {}
	var edges: Dictionary = {}
	var coplanar: Dictionary = {}
	for offset: int in range(0, triangles.size(), 3):
		counts["triangles_visited"] += 1
		var a: Vector3 = triangles[offset]
		var b: Vector3 = triangles[offset + 1]
		var c: Vector3 = triangles[offset + 2]
		if not a.is_finite() or not b.is_finite() or not c.is_finite():
			result["status"] = "nonfinite_triangle"
			return result
		var bounds := AABB(a, Vector3.ZERO).expand(b).expand(c)
		var closest := plane_to_world.origin.clamp(bounds.position, bounds.end)
		if closest.distance_squared_to(plane_to_world.origin) > radius * radius:
			counts["triangles_reach_pruned"] += 1
			continue
		counts["triangles_local"] += 1
		var vertices := PackedVector3Array([a, b, c])
		var distances: Array[float] = []
		for vertex: Vector3 in vertices:
			distances.append((vertex - plane_to_world.origin).dot(plane_to_world.basis.z))
		var all_on: bool = absf(distances[0]) <= DISTANCE_EPSILON and absf(distances[1]) <= DISTANCE_EPSILON and absf(distances[2]) <= DISTANCE_EPSILON
		var ids := PackedInt32Array()
		for edge_index: int in range(3):
			var following: int = (edge_index + 1) % 3
			if absf(distances[edge_index]) <= DISTANCE_EPSILON:
				var point_id: int = _world_point_id(points, buckets, vertices[edge_index], plane_to_world)
				if not ids.has(point_id):
					ids.append(point_id)
			if (distances[edge_index] > DISTANCE_EPSILON and distances[following] < -DISTANCE_EPSILON) or (distances[edge_index] < -DISTANCE_EPSILON and distances[following] > DISTANCE_EPSILON):
				var crossing: Vector3 = vertices[edge_index].lerp(vertices[following], distances[edge_index] / (distances[edge_index] - distances[following]))
				var point_id: int = _world_point_id(points, buckets, crossing, plane_to_world)
				if not ids.has(point_id):
					ids.append(point_id)
		if all_on:
			counts["coplanar_triangles"] += 1
			for index: int in range(ids.size()):
				SliceScript._increment_slice_edge_count(coplanar, ids[index], ids[(index + 1) % ids.size()])
		elif ids.size() >= 2:
			counts["triangles_intersected"] += 1
			var pair: Vector2i = SliceScript._resolve_farthest_slice_point_pair(ids, points)
			edges[SliceScript._build_slice_edge_key(pair.x, pair.y)] = true
	for edge: Vector2i in coplanar:
		if int(coplanar[edge]) % 2 == 1:
			edges[edge] = true
	counts["segments_before_clip"] = edges.size()
	var clipped_points: Array[Vector2] = []
	var clipped_buckets: Dictionary = {}
	var clipped_edges: Dictionary = {}
	var cut_vertices: Dictionary = {}
	for edge: Vector2i in edges:
		var clipped: Dictionary = _clip_to_disk(points[edge.x], points[edge.y], radius)
		if clipped.is_empty():
			counts["segments_outside_disk"] += 1
			continue
		var first: int = _plane_point_id(clipped_points, clipped_buckets, clipped["a"])
		var last: int = _plane_point_id(clipped_points, clipped_buckets, clipped["b"])
		if bool(clipped["clipped"]):
			counts["segments_clipped"] += 1
			# Even near-coincident cut ends must never fabricate a closed contour.
			cut_vertices[first] = true
			cut_vertices[last] = true
		if first != last:
			clipped_edges[SliceScript._build_slice_edge_key(first, last)] = true
	var adjacency: Dictionary = {}
	for edge: Vector2i in clipped_edges:
		result["segments"].append([clipped_points[edge.x], clipped_points[edge.y]])
		for directed: Vector2i in [edge, Vector2i(edge.y, edge.x)]:
			if not adjacency.has(directed.x):
				adjacency[directed.x] = []
			adjacency[directed.x].append(directed.y)
	for neighbors: Array in adjacency.values():
		neighbors.sort()
		if neighbors.size() != 2:
			counts["open_or_branched_vertices"] += 1
	result["contours"] = _closed_contours(clipped_points, clipped_edges, adjacency, cut_vertices)
	counts["segments_emitted"] = result["segments"].size()
	counts["contours_closed"] = result["contours"].size()
	var topology: Dictionary = surface.get("capsule_surface_topology", {})
	# Pruning can hide a contour surrounding the whole disk. Retained loops remain
	# genuine, but cannot alone certify the full solid's inside/outside relation.
	var incomplete: bool = not bool(topology.get("closed", false)) or counts["triangles_reach_pruned"] > 0 or counts["segments_clipped"] > 0 or counts["segments_outside_disk"] > 0 or counts["coplanar_triangles"] > 0 or counts["open_or_branched_vertices"] > 0
	result["classification_incomplete"] = incomplete
	result["search_radius_m"] = radius
	result["valid"] = true
	result["status"] = "partial_local_slice" if incomplete else "complete_closed_slice"
	if counts["segments_emitted"] == 0:
		result["status"] = "no_local_segments"
	return result


func _valid_plane(plane: Transform3D) -> bool:
	if not plane.is_finite():
		return false
	var basis: Basis = plane.basis
	return absf(basis.x.length_squared() - 1.0) < 0.000001 and absf(basis.y.length_squared() - 1.0) < 0.000001 and absf(basis.z.length_squared() - 1.0) < 0.000001 and absf(basis.x.dot(basis.y)) < 0.000001 and absf(basis.x.dot(basis.z)) < 0.000001 and absf(basis.y.dot(basis.z)) < 0.000001 and basis.determinant() > 0.999999


func _world_point_id(points: Array[Vector2], buckets: Dictionary, point: Vector3, plane: Transform3D) -> int:
	return SliceScript._resolve_welded_slice_point_id(points, buckets, point, plane.origin, plane.basis.x, plane.basis.y)


func _plane_point_id(points: Array[Vector2], buckets: Dictionary, point: Vector2) -> int:
	# Explicit 2D meter coordinates lifted solely for the existing welding helper.
	return SliceScript._resolve_welded_slice_point_id(points, buckets, Vector3(point.x, point.y, 0.0), Vector3.ZERO, Vector3.RIGHT, Vector3.UP)


func _clip_to_disk(a: Vector2, b: Vector2, radius: float) -> Dictionary:
	var delta: Vector2 = b - a
	var length_squared: float = delta.length_squared()
	if length_squared <= 0.000000000001:
		return {}
	var projection: float = a.dot(delta)
	var discriminant: float = projection * projection - length_squared * (a.length_squared() - radius * radius)
	if discriminant < 0.0:
		return {}
	var root: float = sqrt(discriminant)
	var lower: float = maxf(0.0, (-projection - root) / length_squared)
	var upper: float = minf(1.0, (-projection + root) / length_squared)
	if upper <= lower:
		return {}
	var first: Vector2 = a + delta * lower
	var last: Vector2 = a + delta * upper
	# Remove floating point overshoot; never create a disk-boundary connecting edge.
	if first.length() > radius:
		first *= radius / first.length()
	if last.length() > radius:
		last *= radius / last.length()
	return {"a": first, "b": last, "clipped": lower > 0.0 or upper < 1.0}


func _closed_contours(points: Array[Vector2], edges: Dictionary, adjacency: Dictionary, cut_vertices: Dictionary) -> Array[PackedVector2Array]:
	var contours: Array[PackedVector2Array] = []
	var visited: Dictionary = {}
	var node_ids: Array = adjacency.keys()
	node_ids.sort()
	for start: int in node_ids:
		var neighbors: Array = adjacency[start]
		if neighbors.size() != 2 or visited.has(SliceScript._build_slice_edge_key(start, int(neighbors[0]))):
			continue
		var contour := PackedVector2Array()
		var previous: int = -1
		var current: int = start
		var has_cut: bool = false
		for _step: int in range(edges.size() + 1):
			if (adjacency[current] as Array).size() != 2:
				break
			has_cut = has_cut or cut_vertices.has(current)
			contour.append(points[current])
			var options: Array = adjacency[current]
			var following: int = int(options[0]) if int(options[0]) != previous else int(options[1])
			var edge: Vector2i = SliceScript._build_slice_edge_key(current, following)
			if visited.has(edge):
				break
			visited[edge] = true
			previous = current
			current = following
			if current == start:
				if not has_cut and contour.size() >= 3 and bool(SliceScript._calculate_polygon_centroid_state(contour).get("valid", false)):
					contour.append(contour[0])
					contours.append(contour)
				break
	return contours
