extends SceneTree

## Source correspondence only; this does not certify a contour or a grip.
const Slicer = preload("res://runtime/player/grip/weighted_skin_plane_slicer.gd")

var _slicer := Slicer.new()
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_shared_edge()
	_vertex_and_coplanar()
	_disconnected_coincident_sources()
	_merge_retains_first()
	print("WEIGHTED_SKIN_SLICE_PROVENANCE=" + JSON.stringify({"passed": _failures.is_empty(),
		"checks": _checks, "failures": _failures, "files_written": false,
		"production_pose_written": false, "actual_3d_grip_verified": false}))
	quit(0 if _failures.is_empty() else 1)


func _shared_edge() -> void:
	var packet := _slice(PackedVector3Array([Vector3(0, 0, -1), Vector3(0, 0, 3),
		Vector3(2, 0, 1), Vector3(0, 2, 1)]), PackedInt32Array([0, 1, 2, 1, 0, 3]), "shared edge")
	var edges: Array = packet.edges
	if not _check(edges.size() == 2, "shared edge emits two original segments"): return
	_check(edges[0].a == Vector2.ZERO and edges[0].b == Vector2(1, 0), "first triangle geometry and endpoint order")
	_check(edges[1].a == Vector2.ZERO and edges[1].b == Vector2(0, 1), "opposite winding geometry and endpoint order")
	_check(edges[0].a_source.topology_key == "e:0:1" and edges[1].a_source.topology_key == "e:0:1", "shared edge identity independent of winding")
	_check(edges[0].a_source.t == 0.25 and edges[1].a_source.t == 0.25, "canonical interpolation independent of winding")
	_check(edges[0].surface_triangle_index == 100 and edges[1].surface_triangle_index == 103, "original face identities preserved")
	_check(edges[0].dynamic and edges[1].dynamic, "dynamic flag preserved")


func _vertex_and_coplanar() -> void:
	var packet := _slice(PackedVector3Array([Vector3.ZERO, Vector3(2, 0, 1), Vector3(0, 2, -1)]),
		PackedInt32Array([0, 1, 2]), "vertex cut")
	if _check(packet.edges.size() == 1, "vertex cut emits original segment"):
		var edge: Dictionary = packet.edges[0]
		_check(edge.a == Vector2.ZERO and edge.b == Vector2(1, 1), "vertex cut geometry")
		_check(edge.a_source.kind == "vertex" and edge.a_source.topology_key == "v:0" and edge.a_source.vertex_ids == PackedInt32Array([0]), "on-plane vertex keeps original ID")
		_check(not edge.a_source.coplanar and edge.a_source.t == 0.0, "on-plane vertex is not a coplanar face")
	packet = _slice(PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0), Vector3(0, 1, 0)]),
		PackedInt32Array([0, 1, 2]), "coplanar face")
	if _check(packet.edges.size() == 3, "coplanar face retains all three original edges"):
		for index: int in range(3):
			var edge: Dictionary = packet.edges[index]
			_check(edge.coplanar and edge.a_source.coplanar and edge.b_source.coplanar, "coplanar provenance explicit " + str(index))
			_check(edge.a_source.topology_key == "v:%d" % index and edge.b_source.topology_key == "v:%d" % ((index + 1) % 3), "coplanar endpoint source order " + str(index))
	packet = _slice(PackedVector3Array([Vector3(0, 0, Slicer.EPSILON_M * 0.5), Vector3(2, 0, 1), Vector3(0, 2, -1)]),
		PackedInt32Array([0, 1, 2]), "within plane tolerance")
	if _check(packet.edges.size() == 1, "within-tolerance vertex still emits segment"):
		_check(packet.edges[0].a_source.topology_key == "v:0" and packet.edges[0].a == Vector2.ZERO, "existing on-plane tolerance retains vertex identity")


func _disconnected_coincident_sources() -> void:
	var points := PackedVector3Array([Vector3(0, 0, -1), Vector3(0, 0, 3), Vector3(2, 0, 1),
		Vector3(99, 99, 99), Vector3(0, 0, -1), Vector3(0, 0, 3), Vector3(2, 0, 1)])
	var packet := _slice(points, PackedInt32Array([0, 1, 2, 4, 5, 6]), "disconnected coincident faces")
	if not _check(packet.edges.size() == 2, "coincident faces remain separate segments"): return
	var first: Dictionary = packet.edges[0]
	var second: Dictionary = packet.edges[1]
	_check(first.a == second.a and first.b == second.b, "fixture has coincident output geometry")
	_check(first.a_source.topology_key == "e:0:1" and second.a_source.topology_key == "e:4:5", "coincident source topology stays distinct with global IDs")
	_check(first.b_source.topology_key != second.b_source.topology_key, "both disconnected endpoints stay distinct")


func _merge_retains_first() -> void:
	# Exercise the existing point-merge boundary directly: a retained endpoint
	# must not acquire the discarded source identity or its selected weights.
	var points: Array[Vector3] = []
	var weights: Array[Vector3] = []
	var sources: Array[Dictionary] = []
	_slicer._add_cut(points, weights, sources, Vector3.ZERO, Vector3(0.7, 0.2, 0.1), _slicer._vertex_source(8, false))
	_slicer._add_cut(points, weights, sources, Vector3(Slicer.EPSILON_M * 0.5, 0, 0), Vector3.ONE, _slicer._vertex_source(9, false))
	_check(points.size() == 1 and weights.size() == 1 and sources.size() == 1, "within-tolerance cuts retain original merge count")
	_check(points[0] == Vector3.ZERO and weights[0] == Vector3(0.7, 0.2, 0.1), "merged cut preserves first point and weights")
	_check(sources[0].topology_key == "v:8" and sources[0].topology_ambiguous, "distinct merged source marks ambiguity without replacing identity")
	_check(sources[0].discarded_sources.size() == 1 and sources[0].discarded_sources[0].topology_key == "v:9", "discarded source retained explicitly")
	_slicer._add_cut(points, weights, sources, Vector3(Slicer.EPSILON_M * 2.0, 0, 0), Vector3.ONE, _slicer._vertex_source(10, false))
	_check(points.size() == 2 and sources[1].topology_key == "v:10" and not sources[1].topology_ambiguous, "outside-tolerance cut remains separate")


func _slice(vertices: PackedVector3Array, indices: PackedInt32Array, label: String) -> Dictionary:
	var triangle_ids := PackedInt32Array()
	var surfaces := PackedInt32Array()
	var local_faces := PackedInt32Array()
	var weights := PackedVector3Array()
	for offset: int in range(0, indices.size(), 3):
		triangle_ids.append(offset / 3)
		surfaces.append(4)
		local_faces.append(100 + offset)
	# Deliberately unnormalized: provenance must preserve original weight values.
	for vertex: int in range(vertices.size()): weights.append(Vector3(vertex + 0.1, vertex + 0.2, vertex + 0.3))
	var query := {"plane_to_world": Transform3D.IDENTITY, "plane_origin_id": &"ProvenanceTestPlane",
		"triangle_indices": indices, "triangle_surface_ids": surfaces, "triangle_local_ids": local_faces,
		"selected_weights": weights, "bone_ids": [&"S1", &"S2", &"S3"]}
	var before: PackedByteArray = var_to_bytes([query, vertices, triangle_ids])
	var edges: Array = _slicer._slice_triangles(query, vertices, triangle_ids, true)
	_check(var_to_bytes([query, vertices, triangle_ids]) == before, label + " input remains unchanged")
	for edge: Dictionary in edges:
		_check(edge.surface_index == 4 and edge.origin_id == &"ProvenanceTestPlane" and edge.bone_ids == query.bone_ids, label + " existing source fields retained")
		for endpoint: String in ["a", "b"]:
			var source: Dictionary = edge[endpoint + "_source"]
			var ids: PackedInt32Array = source.vertex_ids
			var expected_point: Vector3 = vertices[ids[0]]
			var expected_weights: Vector3 = weights[ids[0]]
			if ids.size() == 2:
				_check(ids[0] < ids[1] and source.t > 0.0 and source.t < 1.0, label + " canonical original edge IDs and interior factor")
				expected_point = expected_point.lerp(vertices[ids[1]], source.t)
				expected_weights = expected_weights.lerp(weights[ids[1]], source.t)
			_check((edge[endpoint] as Vector2).distance_to(Vector2(expected_point.x, expected_point.y)) <= 0.000001, label + " source reconstructs projected endpoint")
			_check((edge[endpoint + "_selected_weights"] as Vector3).distance_to(expected_weights) <= 0.000001, label + " source reconstructs original interpolated weights")
	return {"edges": edges}


func _check(passed: bool, label: String) -> bool:
	_checks += 1
	if not passed:
		_failures.append(label)
		push_error(label)
	return passed
