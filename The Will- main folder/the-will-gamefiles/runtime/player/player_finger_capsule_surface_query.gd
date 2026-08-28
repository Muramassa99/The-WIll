extends RefCounted
class_name PlayerFingerCapsuleSurfaceQuery

## Pure closest-pair query between one finite capsule axis and an exact prepared
## triangle surface. The input surface is the Dictionary returned by
## PlayerFingerSurfaceGripSolver.prepare_surface(). No scene or physics state is
## read or mutated here.
##
## Every position/direction ending in `_world` is expressed in the coordinate
## space named by `resolved_world_origin_id`. Source origin IDs are separate
## provenance and are deliberately not required to match that coordinate origin.

const QUERY_REVISION: StringName = &"finger_capsule_exact_triangle_query_v1"
const GEOMETRY_EPSILON_METERS: float = 0.0000001
const DISTANCE_EPSILON_SQUARED: float = (
	GEOMETRY_EPSILON_METERS * GEOMETRY_EPSILON_METERS
)
const RELATIVE_PARALLEL_EPSILON: float = 0.000000001
const ABSOLUTE_DETERMINANT_EPSILON: float = 0.000000000000000001
const BARYCENTRIC_EDGE_EPSILON: float = 0.000001
const PARITY_HIT_MERGE_EPSILON_METERS: float = 0.0000002

const _INSIDE_RAY_DIRECTIONS: Array[Vector3] = [
	Vector3(0.811107, 0.324443, 0.486665),
	Vector3(-0.273266, 0.893937, 0.355246),
	Vector3(0.419821, -0.237113, 0.876109),
]


func get_revision() -> StringName:
	return QUERY_REVISION


func analyze_prepared_surface_topology(prepared_surface: Dictionary) -> Dictionary:
	var triangles: PackedVector3Array = prepared_surface.get(
		"triangles_world",
		PackedVector3Array()
	) as PackedVector3Array
	var triangle_count: int = triangles.size() / 3
	var result: Dictionary = {
		"valid": false,
		"closed": false,
		"status": &"invalid_prepared_triangles",
		"surface_signature": String(prepared_surface.get("surface_signature", "")),
		"triangle_count": triangle_count,
		"unique_edge_count": 0,
		"boundary_edge_count": 0,
		"manifold_edge_count": 0,
		"nonmanifold_edge_count": 0,
		"degenerate_edge_count": 0,
		"degenerate_triangle_count": 0,
	}
	if triangles.size() < 3 or triangles.size() % 3 != 0:
		return result
	var edge_incidence: Dictionary = {}
	for triangle_index: int in range(triangle_count):
		var vertex_offset: int = triangle_index * 3
		var a: Vector3 = triangles[vertex_offset]
		var b: Vector3 = triangles[vertex_offset + 1]
		var c: Vector3 = triangles[vertex_offset + 2]
		if (b - a).cross(c - a).length_squared() <= DISTANCE_EPSILON_SQUARED:
			result["degenerate_triangle_count"] = int(
				result.get("degenerate_triangle_count", 0)
			) + 1
		var vertex_keys: Array[String] = [
			_quantized_vertex_key(a),
			_quantized_vertex_key(b),
			_quantized_vertex_key(c),
		]
		for edge_index: int in range(3):
			var first_key: String = vertex_keys[edge_index]
			var second_key: String = vertex_keys[(edge_index + 1) % 3]
			if first_key == second_key:
				result["degenerate_edge_count"] = int(
					result.get("degenerate_edge_count", 0)
				) + 1
				continue
			var edge_key: String = (
				"%s|%s" % [first_key, second_key]
				if first_key < second_key
				else "%s|%s" % [second_key, first_key]
			)
			edge_incidence[edge_key] = int(edge_incidence.get(edge_key, 0)) + 1
	result["unique_edge_count"] = edge_incidence.size()
	for incidence_variant: Variant in edge_incidence.values():
		var incidence: int = int(incidence_variant)
		if incidence == 1:
			result["boundary_edge_count"] = int(result.get("boundary_edge_count", 0)) + 1
		elif incidence == 2:
			result["manifold_edge_count"] = int(result.get("manifold_edge_count", 0)) + 1
		else:
			result["nonmanifold_edge_count"] = int(
				result.get("nonmanifold_edge_count", 0)
			) + 1
	result["valid"] = true
	result["closed"] = (
		triangle_count >= 4
		and int(result.get("boundary_edge_count", 0)) == 0
		and int(result.get("nonmanifold_edge_count", 0)) == 0
		and int(result.get("degenerate_edge_count", 0)) == 0
		and int(result.get("degenerate_triangle_count", 0)) == 0
	)
	result["status"] = &"closed_manifold" if bool(result["closed"]) else &"surface_not_closed"
	return result


func query_prepared_surface(
	prepared_surface: Dictionary,
	segment_start_world: Vector3,
	segment_start_source_origin_id: StringName,
	segment_end_world: Vector3,
	segment_end_source_origin_id: StringName,
	radius_meters: float,
	surface_source_origin_id: StringName,
	resolved_world_origin_id: StringName,
	options: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = _make_empty_result(
		segment_start_world,
		segment_start_source_origin_id,
		segment_end_world,
		segment_end_source_origin_id,
		radius_meters,
		surface_source_origin_id,
		resolved_world_origin_id
	)
	result["surface_signature"] = String(prepared_surface.get("surface_signature", ""))
	var validation_status: StringName = _validate_query_input(
		prepared_surface,
		segment_start_world,
		segment_start_source_origin_id,
		segment_end_world,
		segment_end_source_origin_id,
		radius_meters,
		surface_source_origin_id,
		resolved_world_origin_id
	)
	if validation_status != &"ready":
		result["status"] = validation_status
		return result

	var counts: Dictionary = _make_empty_counts()
	var nearest: Dictionary = _query_nearest_triangle_pair(
		prepared_surface,
		segment_start_world,
		segment_end_world,
		counts
	)
	if not bool(nearest.get("valid", false)):
		result["status"] = &"no_triangle_candidate"
		result["counts"] = counts
		return result

	var nearest_distance: float = sqrt(maxf(
		float(nearest.get("distance_squared_meters", INF)),
		0.0
	))
	var closest_segment_point_world: Vector3 = nearest.get(
		"closest_segment_point_world",
		segment_start_world
	) as Vector3
	var closest_triangle_point_world: Vector3 = nearest.get(
		"closest_triangle_point_world",
		closest_segment_point_world
	) as Vector3
	var closest_triangle_normal_world: Vector3 = nearest.get(
		"closest_triangle_normal_world",
		Vector3.UP
	) as Vector3
	closest_triangle_normal_world = _safe_normalized(
		closest_triangle_normal_world,
		Vector3.UP
	)

	var on_surface: bool = nearest_distance <= GEOMETRY_EPSILON_METERS
	var classify_inside: bool = bool(options.get("classify_inside_solid", true))
	var topology_state: Dictionary = {
		"valid": false,
		"closed": false,
		"status": &"not_checked",
		"surface_signature": result["surface_signature"],
	}
	if classify_inside and not on_surface:
		topology_state = _resolve_surface_topology_state(prepared_surface, options)
	var inside_state: Dictionary = {
		"valid": not classify_inside,
		"inside": false,
		"status": &"classification_disabled",
		"crossing_count": 0,
		"ray_direction_world": Vector3.ZERO,
	}
	if classify_inside and not on_surface and bool(topology_state.get("closed", false)):
		inside_state = _classify_point_inside_prepared_surface(
			prepared_surface,
			closest_segment_point_world,
			counts
		)
	elif classify_inside and not on_surface:
		inside_state = {
			"valid": false,
			"inside": false,
			"status": &"surface_not_closed",
			"crossing_count": 0,
			"ray_direction_world": Vector3.ZERO,
		}
	elif classify_inside:
		inside_state = {
			"valid": true,
			"inside": false,
			"status": &"point_on_surface",
			"crossing_count": 0,
			"ray_direction_world": Vector3.ZERO,
		}

	var inside_solid: bool = bool(inside_state.get("inside", false))
	var signed_axis_distance: float = -nearest_distance if inside_solid else nearest_distance
	if on_surface:
		signed_axis_distance = 0.0
	var signed_overlap: float = radius_meters - signed_axis_distance
	var separation: Vector3 = closest_segment_point_world - closest_triangle_point_world
	var surface_to_axis_direction_world: Vector3 = _safe_normalized(
		separation,
		_closest_pair_zero_distance_direction(
			closest_triangle_normal_world,
			segment_end_world - segment_start_world
		)
	)
	var contact_escape_normal_world: Vector3 = (
		-surface_to_axis_direction_world if inside_solid
		else surface_to_axis_direction_world
	)
	contact_escape_normal_world = _safe_normalized(
		contact_escape_normal_world,
		closest_triangle_normal_world
	)

	result["valid"] = true
	result["status"] = &"ready"
	result["nearest_distance_meters"] = nearest_distance
	result["axis_surface_distance_meters"] = nearest_distance
	result["signed_axis_surface_distance_meters"] = signed_axis_distance
	result["capsule_surface_signed_distance_meters"] = signed_axis_distance - radius_meters
	result["signed_overlap_meters"] = signed_overlap
	result["penetration_meters"] = maxf(signed_overlap, 0.0)
	result["surface_gap_meters"] = maxf(-signed_overlap, 0.0)
	result["overlapping"] = signed_overlap >= -GEOMETRY_EPSILON_METERS
	result["segment_intersects_surface"] = on_surface
	result["segment_axis_inside_solid"] = inside_solid
	result["inside_classification_valid"] = bool(inside_state.get("valid", false))
	result["inside_classification_status"] = inside_state.get("status", &"unknown")
	result["surface_topology_valid"] = bool(topology_state.get("valid", false))
	result["surface_topology_closed"] = bool(topology_state.get("closed", false))
	result["surface_topology_status"] = topology_state.get("status", &"not_checked")
	result["surface_topology_boundary_edge_count"] = int(topology_state.get(
		"boundary_edge_count",
		0
	))
	result["surface_topology_nonmanifold_edge_count"] = int(topology_state.get(
		"nonmanifold_edge_count",
		0
	))
	result["signed_distance_valid"] = (
		not classify_inside
		or on_surface
		or bool(inside_state.get("valid", false))
	)
	result["inside_ray_crossing_count"] = int(inside_state.get("crossing_count", 0))
	result["inside_ray_direction_world"] = inside_state.get(
		"ray_direction_world",
		Vector3.ZERO
	) as Vector3
	result["inside_ray_direction_world_origin_id"] = resolved_world_origin_id
	result["closest_segment_point_world"] = closest_segment_point_world
	result["closest_segment_point_world_origin_id"] = resolved_world_origin_id
	result["closest_segment_point_source_start_origin_id"] = segment_start_source_origin_id
	result["closest_segment_point_source_end_origin_id"] = segment_end_source_origin_id
	result["closest_segment_fraction"] = float(nearest.get("segment_fraction", 0.0))
	result["closest_triangle_point_world"] = closest_triangle_point_world
	result["closest_triangle_point_world_origin_id"] = resolved_world_origin_id
	result["closest_triangle_point_source_origin_id"] = surface_source_origin_id
	result["closest_triangle_normal_world"] = closest_triangle_normal_world
	result["closest_triangle_normal_world_origin_id"] = resolved_world_origin_id
	result["closest_triangle_normal_source_origin_id"] = surface_source_origin_id
	result["surface_to_axis_direction_world"] = surface_to_axis_direction_world
	result["surface_to_axis_direction_world_origin_id"] = resolved_world_origin_id
	result["contact_escape_normal_world"] = contact_escape_normal_world
	result["contact_escape_normal_world_origin_id"] = resolved_world_origin_id
	result["closest_triangle_index"] = int(nearest.get("triangle_index", -1))
	result["closest_triangle_barycentric"] = nearest.get(
		"triangle_barycentric",
		Vector3.ZERO
	) as Vector3
	result["closest_triangle_barycentric_origin_id"] = surface_source_origin_id
	result["closest_feature"] = nearest.get("feature", &"unknown")
	result["counts"] = counts
	return result


func _validate_query_input(
	prepared_surface: Dictionary,
	segment_start_world: Vector3,
	segment_start_source_origin_id: StringName,
	segment_end_world: Vector3,
	segment_end_source_origin_id: StringName,
	radius_meters: float,
	surface_source_origin_id: StringName,
	resolved_world_origin_id: StringName
) -> StringName:
	if not bool(prepared_surface.get("valid", false)):
		return &"invalid_prepared_surface"
	var triangles: PackedVector3Array = prepared_surface.get(
		"triangles_world",
		PackedVector3Array()
	) as PackedVector3Array
	if triangles.size() < 3 or triangles.size() % 3 != 0:
		return &"invalid_prepared_triangles"
	if not _vector_is_finite(segment_start_world) or not _vector_is_finite(segment_end_world):
		return &"non_finite_segment"
	if not is_finite(radius_meters) or radius_meters < 0.0:
		return &"invalid_radius"
	if segment_start_source_origin_id == StringName():
		return &"segment_start_source_origin_missing"
	if segment_end_source_origin_id == StringName():
		return &"segment_end_source_origin_missing"
	if surface_source_origin_id == StringName():
		return &"surface_source_origin_missing"
	if resolved_world_origin_id == StringName():
		return &"resolved_world_origin_missing"
	return &"ready"


func _resolve_surface_topology_state(
	prepared_surface: Dictionary,
	options: Dictionary
) -> Dictionary:
	var expected_signature: String = String(prepared_surface.get("surface_signature", ""))
	var expected_triangle_count: int = int(prepared_surface.get("triangle_count", 0))
	var cached_variant: Variant = options.get("surface_topology_state", {})
	if cached_variant is Dictionary:
		var cached: Dictionary = cached_variant as Dictionary
		var cached_signature: String = String(cached.get("surface_signature", ""))
		var cached_triangle_count: int = int(cached.get("triangle_count", -1))
		if (
			bool(cached.get("valid", false))
			and cached_signature == expected_signature
			and cached_triangle_count == expected_triangle_count
		):
			return cached.duplicate(true)
	return analyze_prepared_surface_topology(prepared_surface)


func _query_nearest_triangle_pair(
	prepared_surface: Dictionary,
	segment_start_world: Vector3,
	segment_end_world: Vector3,
	counts: Dictionary
) -> Dictionary:
	var triangles: PackedVector3Array = prepared_surface.get(
		"triangles_world",
		PackedVector3Array()
	) as PackedVector3Array
	var normals: PackedVector3Array = prepared_surface.get(
		"triangle_normals_world",
		PackedVector3Array()
	) as PackedVector3Array
	var triangle_count: int = triangles.size() / 3
	counts["prepared_triangle_count"] = triangle_count
	var best: Dictionary = {
		"valid": false,
		"distance_squared_meters": INF,
		"triangle_index": -1,
	}
	var bvh_nodes: Array = prepared_surface.get("bvh_nodes", []) as Array
	var triangle_order: Array = prepared_surface.get("bvh_triangle_order", []) as Array
	var use_bvh: bool = not bvh_nodes.is_empty() and triangle_order.size() >= triangle_count
	counts["used_bvh"] = use_bvh
	if use_bvh:
		var segment_bounds: AABB = _segment_aabb(segment_start_world, segment_end_world)
		var stack: Array[int] = [0]
		while not stack.is_empty():
			var node_index: int = stack.pop_back()
			if node_index < 0 or node_index >= bvh_nodes.size():
				counts["malformed_bvh_node_count"] = int(
					counts.get("malformed_bvh_node_count", 0)
				) + 1
				continue
			counts["bvh_node_test_count"] = int(counts.get("bvh_node_test_count", 0)) + 1
			var node: Dictionary = bvh_nodes[node_index] as Dictionary
			var lower_distance_squared: float = _aabb_distance_squared(
				segment_bounds,
				node.get("bounds", AABB()) as AABB
			)
			if lower_distance_squared > float(best.get(
				"distance_squared_meters",
				INF
			)) + DISTANCE_EPSILON_SQUARED:
				counts["bvh_node_prune_count"] = int(counts.get("bvh_node_prune_count", 0)) + 1
				continue
			var leaf_count: int = int(node.get("count", 0))
			if leaf_count > 0:
				var leaf_start: int = int(node.get("start", 0))
				for order_index: int in range(leaf_start, leaf_start + leaf_count):
					if order_index < 0 or order_index >= triangle_order.size():
						counts["malformed_bvh_order_count"] = int(
							counts.get("malformed_bvh_order_count", 0)
						) + 1
						continue
					var triangle_index: int = int(triangle_order[order_index])
					_consider_triangle(
						triangles,
						normals,
						triangle_index,
						segment_start_world,
						segment_end_world,
						best,
						counts
					)
				continue
			var left_index: int = int(node.get("left", -1))
			var right_index: int = int(node.get("right", -1))
			var current_upper_bound_squared: float = float(best.get(
				"distance_squared_meters",
				INF
			))
			var left_lower_bound_squared: float = INF
			var right_lower_bound_squared: float = INF
			var left_is_candidate: bool = false
			var right_is_candidate: bool = false
			if left_index >= 0 and left_index < bvh_nodes.size():
				var left_node: Dictionary = bvh_nodes[left_index] as Dictionary
				left_lower_bound_squared = _aabb_distance_squared(
					segment_bounds,
					left_node.get("bounds", AABB()) as AABB
				)
				left_is_candidate = (
					left_lower_bound_squared
					<= current_upper_bound_squared + DISTANCE_EPSILON_SQUARED
				)
				if not left_is_candidate:
					counts["bvh_child_preprune_count"] = int(
						counts.get("bvh_child_preprune_count", 0)
					) + 1
			if right_index >= 0 and right_index < bvh_nodes.size():
				var right_node: Dictionary = bvh_nodes[right_index] as Dictionary
				right_lower_bound_squared = _aabb_distance_squared(
					segment_bounds,
					right_node.get("bounds", AABB()) as AABB
				)
				right_is_candidate = (
					right_lower_bound_squared
					<= current_upper_bound_squared + DISTANCE_EPSILON_SQUARED
				)
				if not right_is_candidate:
					counts["bvh_child_preprune_count"] = int(
						counts.get("bvh_child_preprune_count", 0)
					) + 1
			if left_is_candidate and right_is_candidate:
				counts["bvh_nearest_first_branch_count"] = int(
					counts.get("bvh_nearest_first_branch_count", 0)
				) + 1
				# The stack is LIFO: append the farther child first so the nearer
				# child establishes a tight exact upper bound before it is tested.
				if left_lower_bound_squared <= right_lower_bound_squared:
					stack.append(right_index)
					stack.append(left_index)
				else:
					stack.append(left_index)
					stack.append(right_index)
			elif left_is_candidate:
				stack.append(left_index)
			elif right_is_candidate:
				stack.append(right_index)
	else:
		for triangle_index: int in range(triangle_count):
			_consider_triangle(
				triangles,
				normals,
				triangle_index,
				segment_start_world,
				segment_end_world,
				best,
				counts
			)
	return best


func _consider_triangle(
	triangles: PackedVector3Array,
	normals: PackedVector3Array,
	triangle_index: int,
	segment_start_world: Vector3,
	segment_end_world: Vector3,
	best: Dictionary,
	counts: Dictionary
) -> void:
	var triangle_count: int = triangles.size() / 3
	if triangle_index < 0 or triangle_index >= triangle_count:
		counts["invalid_triangle_index_count"] = int(
			counts.get("invalid_triangle_index_count", 0)
		) + 1
		return
	var vertex_offset: int = triangle_index * 3
	var a: Vector3 = triangles[vertex_offset]
	var b: Vector3 = triangles[vertex_offset + 1]
	var c: Vector3 = triangles[vertex_offset + 2]
	counts["triangle_test_count"] = int(counts.get("triangle_test_count", 0)) + 1
	var pair: Dictionary = _closest_segment_triangle_pair(
		segment_start_world,
		segment_end_world,
		a,
		b,
		c,
		counts
	)
	var distance_squared: float = float(pair.get("distance_squared_meters", INF))
	if distance_squared >= float(best.get(
		"distance_squared_meters",
		INF
	)) - DISTANCE_EPSILON_SQUARED:
		return
	var triangle_normal: Vector3 = (
		normals[triangle_index]
		if triangle_index < normals.size()
		else (b - a).cross(c - a)
	)
	best["valid"] = true
	best["distance_squared_meters"] = maxf(distance_squared, 0.0)
	best["triangle_index"] = triangle_index
	best["closest_segment_point_world"] = pair.get(
		"closest_segment_point_world",
		segment_start_world
	)
	best["closest_triangle_point_world"] = pair.get(
		"closest_triangle_point_world",
		a
	)
	best["closest_triangle_normal_world"] = _safe_normalized(
		triangle_normal,
		Vector3.UP
	)
	best["segment_fraction"] = float(pair.get("segment_fraction", 0.0))
	best["triangle_barycentric"] = pair.get("triangle_barycentric", Vector3.ZERO)
	best["feature"] = pair.get("feature", &"unknown")


func _closest_segment_triangle_pair(
	segment_start: Vector3,
	segment_end: Vector3,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	counts: Dictionary
) -> Dictionary:
	counts["segment_triangle_intersection_test_count"] = int(
		counts.get("segment_triangle_intersection_test_count", 0)
	) + 1
	var intersection: Dictionary = _segment_triangle_intersection(
		segment_start,
		segment_end,
		a,
		b,
		c
	)
	if bool(intersection.get("hit", false)):
		var hit_point: Vector3 = intersection.get("point", segment_start) as Vector3
		return {
			"distance_squared_meters": 0.0,
			"closest_segment_point_world": hit_point,
			"closest_triangle_point_world": hit_point,
			"segment_fraction": float(intersection.get("segment_fraction", 0.0)),
			"triangle_barycentric": intersection.get("triangle_barycentric", Vector3.ZERO),
			"feature": &"segment_face_intersection",
		}

	var best: Dictionary = {
		"distance_squared_meters": INF,
		"closest_segment_point_world": segment_start,
		"closest_triangle_point_world": a,
		"segment_fraction": 0.0,
		"triangle_barycentric": Vector3(1.0, 0.0, 0.0),
		"feature": &"unknown",
	}
	counts["endpoint_triangle_test_count"] = int(
		counts.get("endpoint_triangle_test_count", 0)
	) + 2
	var start_triangle: Dictionary = _closest_point_on_triangle(segment_start, a, b, c)
	_consider_pair_candidate(
		best,
		segment_start,
		start_triangle.get("point", a) as Vector3,
		0.0,
		start_triangle.get("barycentric", Vector3(1.0, 0.0, 0.0)) as Vector3,
		&"segment_start_to_triangle"
	)
	var end_triangle: Dictionary = _closest_point_on_triangle(segment_end, a, b, c)
	_consider_pair_candidate(
		best,
		segment_end,
		end_triangle.get("point", a) as Vector3,
		1.0,
		end_triangle.get("barycentric", Vector3(1.0, 0.0, 0.0)) as Vector3,
		&"segment_end_to_triangle"
	)

	var triangle_edges: Array[Dictionary] = [
		{"start": a, "end": b, "bary_start": Vector3(1.0, 0.0, 0.0), "bary_end": Vector3(0.0, 1.0, 0.0), "feature": &"triangle_edge_ab"},
		{"start": b, "end": c, "bary_start": Vector3(0.0, 1.0, 0.0), "bary_end": Vector3(0.0, 0.0, 1.0), "feature": &"triangle_edge_bc"},
		{"start": c, "end": a, "bary_start": Vector3(0.0, 0.0, 1.0), "bary_end": Vector3(1.0, 0.0, 0.0), "feature": &"triangle_edge_ca"},
	]
	for edge: Dictionary in triangle_edges:
		counts["segment_edge_test_count"] = int(counts.get("segment_edge_test_count", 0)) + 1
		var edge_pair: Dictionary = _closest_points_between_segments(
			segment_start,
			segment_end,
			edge.get("start", a) as Vector3,
			edge.get("end", b) as Vector3
		)
		var edge_fraction: float = float(edge_pair.get("second_fraction", 0.0))
		var edge_barycentric: Vector3 = (
			(edge.get("bary_start", Vector3.ZERO) as Vector3).lerp(
				edge.get("bary_end", Vector3.ZERO) as Vector3,
				edge_fraction
			)
		)
		_consider_pair_candidate(
			best,
			edge_pair.get("first_point", segment_start) as Vector3,
			edge_pair.get("second_point", a) as Vector3,
			float(edge_pair.get("first_fraction", 0.0)),
			edge_barycentric,
			edge.get("feature", &"triangle_edge") as StringName
		)
	return best


func _consider_pair_candidate(
	best: Dictionary,
	segment_point: Vector3,
	triangle_point: Vector3,
	segment_fraction: float,
	triangle_barycentric: Vector3,
	feature: StringName
) -> void:
	var distance_squared: float = segment_point.distance_squared_to(triangle_point)
	if distance_squared >= float(best.get(
		"distance_squared_meters",
		INF
	)) - DISTANCE_EPSILON_SQUARED:
		return
	best["distance_squared_meters"] = maxf(distance_squared, 0.0)
	best["closest_segment_point_world"] = segment_point
	best["closest_triangle_point_world"] = triangle_point
	best["segment_fraction"] = clampf(segment_fraction, 0.0, 1.0)
	best["triangle_barycentric"] = triangle_barycentric
	best["feature"] = feature


func _segment_triangle_intersection(
	segment_start: Vector3,
	segment_end: Vector3,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> Dictionary:
	var direction: Vector3 = segment_end - segment_start
	if direction.length_squared() <= DISTANCE_EPSILON_SQUARED:
		return {"hit": false}
	var edge_ab: Vector3 = b - a
	var edge_ac: Vector3 = c - a
	var p_vector: Vector3 = direction.cross(edge_ac)
	var determinant: float = edge_ab.dot(p_vector)
	var determinant_scale: float = (
		edge_ab.length() * edge_ac.length() * direction.length()
	)
	var determinant_epsilon: float = maxf(
		ABSOLUTE_DETERMINANT_EPSILON,
		determinant_scale * RELATIVE_PARALLEL_EPSILON
	)
	if absf(determinant) <= determinant_epsilon:
		return {"hit": false, "coplanar_or_parallel": true}
	var inverse_determinant: float = 1.0 / determinant
	var t_vector: Vector3 = segment_start - a
	var u: float = t_vector.dot(p_vector) * inverse_determinant
	if u < -BARYCENTRIC_EDGE_EPSILON or u > 1.0 + BARYCENTRIC_EDGE_EPSILON:
		return {"hit": false}
	var q_vector: Vector3 = t_vector.cross(edge_ab)
	var v: float = direction.dot(q_vector) * inverse_determinant
	if v < -BARYCENTRIC_EDGE_EPSILON or u + v > 1.0 + BARYCENTRIC_EDGE_EPSILON:
		return {"hit": false}
	var segment_fraction: float = edge_ac.dot(q_vector) * inverse_determinant
	if segment_fraction < -BARYCENTRIC_EDGE_EPSILON or segment_fraction > 1.0 + BARYCENTRIC_EDGE_EPSILON:
		return {"hit": false}
	segment_fraction = clampf(segment_fraction, 0.0, 1.0)
	u = clampf(u, 0.0, 1.0)
	v = clampf(v, 0.0, 1.0 - u)
	return {
		"hit": true,
		"point": segment_start + direction * segment_fraction,
		"segment_fraction": segment_fraction,
		"triangle_barycentric": Vector3(1.0 - u - v, u, v),
	}


func _closest_point_on_triangle(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Dictionary:
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a
	if ab.cross(ac).length_squared() <= DISTANCE_EPSILON_SQUARED:
		return _closest_point_on_degenerate_triangle(point, a, b, c)
	var ap: Vector3 = point - a
	var d1: float = ab.dot(ap)
	var d2: float = ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return {"point": a, "barycentric": Vector3(1.0, 0.0, 0.0)}

	var bp: Vector3 = point - b
	var d3: float = ab.dot(bp)
	var d4: float = ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return {"point": b, "barycentric": Vector3(0.0, 1.0, 0.0)}

	var vc: float = d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		var v_ab: float = d1 / (d1 - d3)
		return {
			"point": a + ab * v_ab,
			"barycentric": Vector3(1.0 - v_ab, v_ab, 0.0),
		}

	var cp: Vector3 = point - c
	var d5: float = ab.dot(cp)
	var d6: float = ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return {"point": c, "barycentric": Vector3(0.0, 0.0, 1.0)}

	var vb: float = d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		var v_ac: float = d2 / (d2 - d6)
		return {
			"point": a + ac * v_ac,
			"barycentric": Vector3(1.0 - v_ac, 0.0, v_ac),
		}

	var va: float = d3 * d6 - d5 * d4
	if va <= 0.0 and d4 - d3 >= 0.0 and d5 - d6 >= 0.0:
		var v_bc: float = (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return {
			"point": b + (c - b) * v_bc,
			"barycentric": Vector3(0.0, 1.0 - v_bc, v_bc),
		}

	var denominator: float = va + vb + vc
	if absf(denominator) <= DISTANCE_EPSILON_SQUARED:
		return _closest_point_on_degenerate_triangle(point, a, b, c)
	var inverse_denominator: float = 1.0 / denominator
	var face_v: float = vb * inverse_denominator
	var face_w: float = vc * inverse_denominator
	return {
		"point": a + ab * face_v + ac * face_w,
		"barycentric": Vector3(1.0 - face_v - face_w, face_v, face_w),
	}


func _closest_point_on_degenerate_triangle(
	point: Vector3,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var ab: Dictionary = _closest_point_on_segment(point, a, b)
	candidates.append({
		"point": ab.get("point", a),
		"barycentric": Vector3(1.0 - float(ab.get("fraction", 0.0)), float(ab.get("fraction", 0.0)), 0.0),
	})
	var bc: Dictionary = _closest_point_on_segment(point, b, c)
	candidates.append({
		"point": bc.get("point", b),
		"barycentric": Vector3(0.0, 1.0 - float(bc.get("fraction", 0.0)), float(bc.get("fraction", 0.0))),
	})
	var ca: Dictionary = _closest_point_on_segment(point, c, a)
	candidates.append({
		"point": ca.get("point", c),
		"barycentric": Vector3(float(ca.get("fraction", 0.0)), 0.0, 1.0 - float(ca.get("fraction", 0.0))),
	})
	var best: Dictionary = candidates[0]
	var best_distance_squared: float = point.distance_squared_to(best.get("point", a) as Vector3)
	for candidate_index: int in range(1, candidates.size()):
		var candidate: Dictionary = candidates[candidate_index]
		var candidate_distance_squared: float = point.distance_squared_to(
			candidate.get("point", a) as Vector3
		)
		if candidate_distance_squared < best_distance_squared:
			best = candidate
			best_distance_squared = candidate_distance_squared
	return best


func _closest_point_on_segment(point: Vector3, start: Vector3, end: Vector3) -> Dictionary:
	var direction: Vector3 = end - start
	var length_squared: float = direction.length_squared()
	var fraction: float = 0.0
	if length_squared > DISTANCE_EPSILON_SQUARED:
		fraction = clampf((point - start).dot(direction) / length_squared, 0.0, 1.0)
	return {"point": start + direction * fraction, "fraction": fraction}


func _closest_points_between_segments(
	first_start: Vector3,
	first_end: Vector3,
	second_start: Vector3,
	second_end: Vector3
) -> Dictionary:
	var first_direction: Vector3 = first_end - first_start
	var second_direction: Vector3 = second_end - second_start
	var between_start: Vector3 = first_start - second_start
	var first_length_squared: float = first_direction.length_squared()
	var second_length_squared: float = second_direction.length_squared()
	var first_fraction: float = 0.0
	var second_fraction: float = 0.0
	if first_length_squared <= DISTANCE_EPSILON_SQUARED and second_length_squared <= DISTANCE_EPSILON_SQUARED:
		pass
	elif first_length_squared <= DISTANCE_EPSILON_SQUARED:
		second_fraction = clampf(
			second_direction.dot(first_start - second_start) / second_length_squared,
			0.0,
			1.0
		)
	elif second_length_squared <= DISTANCE_EPSILON_SQUARED:
		first_fraction = clampf(
			-first_direction.dot(between_start) / first_length_squared,
			0.0,
			1.0
		)
	else:
		var first_dot_second: float = first_direction.dot(second_direction)
		var first_dot_between: float = first_direction.dot(between_start)
		var second_dot_between: float = second_direction.dot(between_start)
		var denominator: float = (
			first_length_squared * second_length_squared
			- first_dot_second * first_dot_second
		)
		if denominator > DISTANCE_EPSILON_SQUARED:
			first_fraction = clampf(
				(
					first_dot_second * second_dot_between
					- second_length_squared * first_dot_between
				) / denominator,
				0.0,
				1.0
			)
		second_fraction = (
			first_dot_second * first_fraction + second_dot_between
		) / second_length_squared
		if second_fraction < 0.0:
			second_fraction = 0.0
			first_fraction = clampf(
				-first_dot_between / first_length_squared,
				0.0,
				1.0
			)
		elif second_fraction > 1.0:
			second_fraction = 1.0
			first_fraction = clampf(
				(first_dot_second - first_dot_between) / first_length_squared,
				0.0,
				1.0
			)
	return {
		"first_point": first_start + first_direction * first_fraction,
		"second_point": second_start + second_direction * second_fraction,
		"first_fraction": first_fraction,
		"second_fraction": second_fraction,
	}


func _classify_point_inside_prepared_surface(
	prepared_surface: Dictionary,
	point_world: Vector3,
	counts: Dictionary
) -> Dictionary:
	var attempts: Array[Dictionary] = []
	for raw_direction: Vector3 in _INSIDE_RAY_DIRECTIONS:
		var ray_direction_world: Vector3 = raw_direction.normalized()
		var attempt: Dictionary = _count_point_parity_crossings(
			prepared_surface,
			point_world,
			ray_direction_world,
			counts
		)
		attempts.append(attempt)
		if not bool(attempt.get("ambiguous", true)):
			return {
				"valid": true,
				"inside": int(attempt.get("crossing_count", 0)) % 2 == 1,
				"status": &"parity_resolved",
				"crossing_count": int(attempt.get("crossing_count", 0)),
				"ray_direction_world": ray_direction_world,
			}
		counts["inside_ray_retry_count"] = int(counts.get("inside_ray_retry_count", 0)) + 1

	var inside_vote_count: int = 0
	for attempt: Dictionary in attempts:
		if int(attempt.get("crossing_count", 0)) % 2 == 1:
			inside_vote_count += 1
	var majority_inside: bool = inside_vote_count > attempts.size() / 2
	var fallback_attempt: Dictionary = attempts[0] if not attempts.is_empty() else {}
	return {
		"valid": false,
		"inside": majority_inside,
		"status": &"parity_ambiguous_majority",
		"crossing_count": int(fallback_attempt.get("crossing_count", 0)),
		"ray_direction_world": (
			_INSIDE_RAY_DIRECTIONS[0].normalized()
			if not attempts.is_empty()
			else Vector3.ZERO
		),
	}


func _count_point_parity_crossings(
	prepared_surface: Dictionary,
	point_world: Vector3,
	ray_direction_world: Vector3,
	counts: Dictionary
) -> Dictionary:
	counts["inside_ray_count"] = int(counts.get("inside_ray_count", 0)) + 1
	var surface_bounds: AABB = _resolve_surface_bounds(prepared_surface)
	var ray_length: float = (
		point_world.distance_to(surface_bounds.get_center())
		+ maxf(surface_bounds.size.length() * 2.0, 1.0)
	)
	var ray_direction: Vector3 = _safe_normalized(ray_direction_world, Vector3.RIGHT)
	var ray_delta: Vector3 = ray_direction * ray_length
	var triangles: PackedVector3Array = prepared_surface.get(
		"triangles_world",
		PackedVector3Array()
	) as PackedVector3Array
	var triangle_count: int = triangles.size() / 3
	var bvh_nodes: Array = prepared_surface.get("bvh_nodes", []) as Array
	var triangle_order: Array = prepared_surface.get("bvh_triangle_order", []) as Array
	var use_bvh: bool = not bvh_nodes.is_empty() and triangle_order.size() >= triangle_count
	var hit_distances: Array[float] = []
	var ambiguous: bool = false
	if use_bvh:
		var stack: Array[int] = [0]
		while not stack.is_empty():
			var node_index: int = stack.pop_back()
			if node_index < 0 or node_index >= bvh_nodes.size():
				continue
			counts["inside_ray_bvh_node_test_count"] = int(
				counts.get("inside_ray_bvh_node_test_count", 0)
			) + 1
			var node: Dictionary = bvh_nodes[node_index] as Dictionary
			if not _segment_intersects_aabb(
				point_world,
				ray_delta,
				node.get("bounds", AABB()) as AABB
			):
				continue
			var leaf_count: int = int(node.get("count", 0))
			if leaf_count > 0:
				var leaf_start: int = int(node.get("start", 0))
				for order_index: int in range(leaf_start, leaf_start + leaf_count):
					if order_index < 0 or order_index >= triangle_order.size():
						continue
					var triangle_index: int = int(triangle_order[order_index])
					var hit_state: Dictionary = _parity_triangle_hit(
						triangles,
						triangle_index,
						point_world,
						ray_delta,
						ray_length,
						counts
					)
					if bool(hit_state.get("hit", false)):
						hit_distances.append(float(hit_state.get("distance_meters", 0.0)))
						ambiguous = ambiguous or bool(hit_state.get("edge_ambiguous", false))
				continue
			var left_index: int = int(node.get("left", -1))
			var right_index: int = int(node.get("right", -1))
			if right_index >= 0:
				stack.append(right_index)
			if left_index >= 0:
				stack.append(left_index)
	else:
		for triangle_index: int in range(triangle_count):
			var hit_state: Dictionary = _parity_triangle_hit(
				triangles,
				triangle_index,
				point_world,
				ray_delta,
				ray_length,
				counts
			)
			if bool(hit_state.get("hit", false)):
				hit_distances.append(float(hit_state.get("distance_meters", 0.0)))
				ambiguous = ambiguous or bool(hit_state.get("edge_ambiguous", false))

	hit_distances.sort()
	var unique_hit_distances: Array[float] = []
	for hit_distance: float in hit_distances:
		if hit_distance <= GEOMETRY_EPSILON_METERS:
			ambiguous = true
			continue
		if (
			unique_hit_distances.is_empty()
			or absf(hit_distance - unique_hit_distances[-1]) > PARITY_HIT_MERGE_EPSILON_METERS
		):
			unique_hit_distances.append(hit_distance)
	return {
		"crossing_count": unique_hit_distances.size(),
		"raw_hit_count": hit_distances.size(),
		"ambiguous": ambiguous,
	}


func _parity_triangle_hit(
	triangles: PackedVector3Array,
	triangle_index: int,
	ray_start: Vector3,
	ray_delta: Vector3,
	ray_length: float,
	counts: Dictionary
) -> Dictionary:
	counts["inside_ray_triangle_test_count"] = int(
		counts.get("inside_ray_triangle_test_count", 0)
	) + 1
	var triangle_count: int = triangles.size() / 3
	if triangle_index < 0 or triangle_index >= triangle_count:
		return {"hit": false}
	var vertex_offset: int = triangle_index * 3
	var hit: Dictionary = _segment_triangle_intersection(
		ray_start,
		ray_start + ray_delta,
		triangles[vertex_offset],
		triangles[vertex_offset + 1],
		triangles[vertex_offset + 2]
	)
	if not bool(hit.get("hit", false)):
		return {"hit": false}
	var barycentric: Vector3 = hit.get("triangle_barycentric", Vector3.ZERO) as Vector3
	var edge_ambiguous: bool = minf(
		barycentric.x,
		minf(barycentric.y, barycentric.z)
	) <= BARYCENTRIC_EDGE_EPSILON
	return {
		"hit": true,
		"distance_meters": float(hit.get("segment_fraction", 0.0)) * ray_length,
		"edge_ambiguous": edge_ambiguous,
	}


func _resolve_surface_bounds(prepared_surface: Dictionary) -> AABB:
	var bvh_nodes: Array = prepared_surface.get("bvh_nodes", []) as Array
	if not bvh_nodes.is_empty():
		var root_node: Dictionary = bvh_nodes[0] as Dictionary
		return root_node.get("bounds", AABB()) as AABB
	var triangles: PackedVector3Array = prepared_surface.get(
		"triangles_world",
		PackedVector3Array()
	) as PackedVector3Array
	if triangles.is_empty():
		return AABB()
	var minimum: Vector3 = triangles[0]
	var maximum: Vector3 = triangles[0]
	for vertex: Vector3 in triangles:
		minimum = minimum.min(vertex)
		maximum = maximum.max(vertex)
	return AABB(minimum, maximum - minimum)


func _segment_aabb(start: Vector3, end: Vector3) -> AABB:
	var minimum: Vector3 = start.min(end)
	var maximum: Vector3 = start.max(end)
	return AABB(minimum, maximum - minimum)


func _aabb_distance_squared(first: AABB, second: AABB) -> float:
	var first_end: Vector3 = first.end
	var second_end: Vector3 = second.end
	var distance_squared: float = 0.0
	for axis_index: int in range(3):
		var axis_distance: float = 0.0
		if first_end[axis_index] < second.position[axis_index]:
			axis_distance = second.position[axis_index] - first_end[axis_index]
		elif second_end[axis_index] < first.position[axis_index]:
			axis_distance = first.position[axis_index] - second_end[axis_index]
		distance_squared += axis_distance * axis_distance
	return distance_squared


func _segment_intersects_aabb(origin: Vector3, direction: Vector3, bounds: AABB) -> bool:
	var minimum_fraction: float = 0.0
	var maximum_fraction: float = 1.0
	var bounds_end: Vector3 = bounds.end
	for axis_index: int in range(3):
		var origin_component: float = origin[axis_index]
		var direction_component: float = direction[axis_index]
		var minimum_component: float = bounds.position[axis_index]
		var maximum_component: float = bounds_end[axis_index]
		if absf(direction_component) <= GEOMETRY_EPSILON_METERS:
			if origin_component < minimum_component or origin_component > maximum_component:
				return false
			continue
		var inverse_direction: float = 1.0 / direction_component
		var first_fraction: float = (
			minimum_component - origin_component
		) * inverse_direction
		var second_fraction: float = (
			maximum_component - origin_component
		) * inverse_direction
		if first_fraction > second_fraction:
			var swap_fraction: float = first_fraction
			first_fraction = second_fraction
			second_fraction = swap_fraction
		minimum_fraction = maxf(minimum_fraction, first_fraction)
		maximum_fraction = minf(maximum_fraction, second_fraction)
		if minimum_fraction > maximum_fraction:
			return false
	return true


func _closest_pair_zero_distance_direction(
	triangle_normal_world: Vector3,
	segment_direction_world: Vector3
) -> Vector3:
	var resolved_normal: Vector3 = _safe_normalized(triangle_normal_world, Vector3.UP)
	if segment_direction_world.length_squared() <= DISTANCE_EPSILON_SQUARED:
		return resolved_normal
	if resolved_normal.dot(segment_direction_world.normalized()) > 0.0:
		return -resolved_normal
	return resolved_normal


func _safe_normalized(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() > DISTANCE_EPSILON_SQUARED:
		return value.normalized()
	if fallback.length_squared() > DISTANCE_EPSILON_SQUARED:
		return fallback.normalized()
	return Vector3.UP


func _vector_is_finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


func _quantized_vertex_key(vertex: Vector3) -> String:
	return "%d,%d,%d" % [
		roundi(vertex.x / GEOMETRY_EPSILON_METERS),
		roundi(vertex.y / GEOMETRY_EPSILON_METERS),
		roundi(vertex.z / GEOMETRY_EPSILON_METERS),
	]


func _make_empty_counts() -> Dictionary:
	return {
		"prepared_triangle_count": 0,
		"used_bvh": false,
		"bvh_node_test_count": 0,
		"bvh_node_prune_count": 0,
		"bvh_child_preprune_count": 0,
		"bvh_nearest_first_branch_count": 0,
		"triangle_test_count": 0,
		"segment_triangle_intersection_test_count": 0,
		"endpoint_triangle_test_count": 0,
		"segment_edge_test_count": 0,
		"inside_ray_count": 0,
		"inside_ray_retry_count": 0,
		"inside_ray_bvh_node_test_count": 0,
		"inside_ray_triangle_test_count": 0,
		"malformed_bvh_node_count": 0,
		"malformed_bvh_order_count": 0,
		"invalid_triangle_index_count": 0,
	}


func _make_empty_result(
	segment_start_world: Vector3,
	segment_start_source_origin_id: StringName,
	segment_end_world: Vector3,
	segment_end_source_origin_id: StringName,
	radius_meters: float,
	surface_source_origin_id: StringName,
	resolved_world_origin_id: StringName
) -> Dictionary:
	return {
		"valid": false,
		"status": &"invalid_input",
		"query_revision": QUERY_REVISION,
		"segment_start_world": segment_start_world,
		"segment_start_world_origin_id": resolved_world_origin_id,
		"segment_start_source_origin_id": segment_start_source_origin_id,
		"segment_end_world": segment_end_world,
		"segment_end_world_origin_id": resolved_world_origin_id,
		"segment_end_source_origin_id": segment_end_source_origin_id,
		"radius_meters": radius_meters,
		"surface_source_origin_id": surface_source_origin_id,
		"resolved_world_origin_id": resolved_world_origin_id,
		"surface_signature": "",
		"nearest_distance_meters": INF,
		"axis_surface_distance_meters": INF,
		"signed_axis_surface_distance_meters": INF,
		"capsule_surface_signed_distance_meters": INF,
		"signed_overlap_meters": -INF,
		"penetration_meters": 0.0,
		"surface_gap_meters": INF,
		"overlapping": false,
		"segment_intersects_surface": false,
		"segment_axis_inside_solid": false,
		"inside_classification_valid": false,
		"inside_classification_status": &"not_run",
		"closest_triangle_index": -1,
		"counts": _make_empty_counts(),
	}
