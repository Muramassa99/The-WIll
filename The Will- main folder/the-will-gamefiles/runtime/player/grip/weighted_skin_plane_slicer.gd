extends RefCounted

const EPSILON_M := 1.0e-7

# Complete triangle-plane intersection soup. Preserve source triangle identity;
# coplanar faces remain explicit, and no crop-boundary closure is invented.
func _slice_triangles(query: Dictionary, vertices: PackedVector3Array, triangle_ids: PackedInt32Array, dynamic: bool) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var plane: Transform3D = query["plane_to_world"]
	var indices: PackedInt32Array = query["triangle_indices"]
	var weights: PackedVector3Array = query["selected_weights"]
	for triangle: int in triangle_ids:
		var points: Array[Vector3] = []
		var selected: Array[Vector3] = []
		var distances: Array[float] = []
		for corner: int in range(3):
			var vertex: int = indices[triangle * 3 + corner]
			points.append(vertices[vertex])
			selected.append(weights[vertex])
			distances.append((vertices[vertex] - plane.origin).dot(plane.basis.z))
		if (distances[0] > EPSILON_M and distances[1] > EPSILON_M and distances[2] > EPSILON_M) or (distances[0] < -EPSILON_M and distances[1] < -EPSILON_M and distances[2] < -EPSILON_M):
			continue
		var coplanar := absf(distances[0]) <= EPSILON_M and absf(distances[1]) <= EPSILON_M and absf(distances[2]) <= EPSILON_M
		if coplanar:
			for corner: int in range(3):
				_append_segment(segments, query, triangle, points[corner], points[(corner + 1) % 3], selected[corner], selected[(corner + 1) % 3], dynamic, true,
					_vertex_source(indices[triangle * 3 + corner], true), _vertex_source(indices[triangle * 3 + (corner + 1) % 3], true))
			continue
		var cuts: Array[Vector3] = []
		var cut_weights: Array[Vector3] = []
		var cut_sources: Array[Dictionary] = []
		for corner: int in range(3):
			var following := (corner + 1) % 3
			if absf(distances[corner]) <= EPSILON_M:
				_add_cut(cuts, cut_weights, cut_sources, points[corner], selected[corner], _vertex_source(indices[triangle * 3 + corner], false))
			if (distances[corner] > EPSILON_M and distances[following] < -EPSILON_M) or (distances[corner] < -EPSILON_M and distances[following] > EPSILON_M):
				var ratio: float = distances[corner] / (distances[corner] - distances[following])
				_add_cut(cuts, cut_weights, cut_sources, points[corner].lerp(points[following], ratio), selected[corner].lerp(selected[following], ratio),
					_edge_source(indices[triangle * 3 + corner], indices[triangle * 3 + following], ratio))
		if cuts.size() >= 2:
			var first := 0
			var last := 1
			var longest := cuts[0].distance_squared_to(cuts[1])
			for a: int in range(cuts.size()):
				for b: int in range(a + 1, cuts.size()):
					var distance := cuts[a].distance_squared_to(cuts[b])
					if distance > longest:
						first = a
						last = b
						longest = distance
			_append_segment(segments, query, triangle, cuts[first], cuts[last], cut_weights[first], cut_weights[last], dynamic, false, cut_sources[first], cut_sources[last])
	return segments

func _add_cut(points: Array[Vector3], weights: Array[Vector3], sources: Array[Dictionary], point: Vector3, selected: Vector3, source: Dictionary) -> void:
	for index: int in range(points.size()):
		if points[index].distance_squared_to(point) <= EPSILON_M * EPSILON_M:
			# Preserve the original first point/weights. A geometric merge is not
			# proof that different original mesh vertices or edges are connected.
			if sources[index].topology_key != source.topology_key:
				sources[index]["topology_ambiguous"] = true
				if not sources[index].has("discarded_sources"):
					sources[index]["discarded_sources"] = []
				sources[index].discarded_sources.append(source)
			return
	points.append(point)
	weights.append(selected)
	sources.append(source)


## IDs index the original global vertex array. Edge t runs from the lower ID
## toward the higher ID, independently of triangle winding. Keys describe source
## topology only; they do not certify a manifold contour or join separate seams.
func _vertex_source(vertex: int, coplanar: bool) -> Dictionary:
	return {"kind": "vertex", "topology_key": "v:%d" % vertex,
		"vertex_ids": PackedInt32Array([vertex]), "t": 0.0,
		"coplanar": coplanar, "topology_ambiguous": false}


func _edge_source(first: int, last: int, ratio: float) -> Dictionary:
	var lower: int = mini(first, last)
	var upper: int = maxi(first, last)
	return {"kind": "edge", "topology_key": "e:%d:%d" % [lower, upper],
		"vertex_ids": PackedInt32Array([lower, upper]), "t": ratio if first == lower else 1.0 - ratio,
		"coplanar": false, "topology_ambiguous": false}


func _append_segment(output: Array[Dictionary], query: Dictionary, triangle: int, first: Vector3, last: Vector3, first_weights: Vector3, last_weights: Vector3, dynamic: bool, coplanar: bool, first_source: Dictionary, last_source: Dictionary) -> void:
	var plane: Transform3D = query["plane_to_world"]
	var a3 := first - plane.origin
	var b3 := last - plane.origin
	var a := Vector2(a3.dot(plane.basis.x), a3.dot(plane.basis.y))
	var b := Vector2(b3.dot(plane.basis.x), b3.dot(plane.basis.y))
	if a.distance_squared_to(b) <= EPSILON_M * EPSILON_M:
		return
	output.append({"a": a, "b": b, "a_selected_weights": first_weights, "b_selected_weights": last_weights,
		"a_source": first_source, "b_source": last_source,
		"bone_ids": query["bone_ids"], "origin_id": query["plane_origin_id"], "dynamic": dynamic, "coplanar": coplanar,
		"surface_index": query["triangle_surface_ids"][triangle], "surface_triangle_index": query["triangle_local_ids"][triangle]})
