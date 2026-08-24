extends RefCounted

# Preserve the established authoring-scale lane for historical comparisons.
const POSITION_WELD_METERS := 0.00001
# A second lane checks whether re-fed baked meshes close without relying on the
# much more permissive authoring-scale weld.
const STRICT_POSITION_WELD_METERS := 0.0000001
const TRIANGLE_AREA_EPSILON_SQUARED := 0.0000000000000001
const SURFACE_SAMPLE_LIMIT := 2048


static func analyze_mesh(mesh: ArrayMesh) -> Dictionary:
	var meshes: Array[ArrayMesh] = []
	if mesh != null:
		meshes.append(mesh)
	return analyze_meshes(meshes)


static func analyze_mesh_surface_subset(
	mesh: ArrayMesh,
	surface_indices: PackedInt32Array
) -> Dictionary:
	var subset := ArrayMesh.new()
	if mesh == null:
		return analyze_mesh(subset)
	for surface_index: int in surface_indices:
		if surface_index < 0 or surface_index >= mesh.get_surface_count():
			continue
		subset.add_surface_from_arrays(
			mesh.surface_get_primitive_type(surface_index),
			mesh.surface_get_arrays(surface_index)
		)
	return analyze_mesh(subset)


static func analyze_meshes(meshes: Array[ArrayMesh]) -> Dictionary:
	var welded_point_ids: Dictionary = {}
	var welded_points: Array[Vector3] = []
	var triangles: Array[PackedInt32Array] = []
	var triangle_positions: Array[PackedVector3Array] = []
	var unoriented_triangle_keys: Array[String] = []
	var oriented_triangle_keys: Array[String] = []
	var surface_count := 0
	var emitted_vertex_count := 0
	var emitted_triangle_count := 0
	var index_count := 0
	var degenerate_triangle_count := 0
	var nonfinite_vertex_count := 0
	var signed_volume := 0.0
	var bounds := AABB()
	var has_bounds := false
	for mesh: ArrayMesh in meshes:
		if mesh == null:
			continue
		for surface_index in range(mesh.get_surface_count()):
			surface_count += 1
			var arrays: Array = mesh.surface_get_arrays(surface_index)
			if arrays.size() <= Mesh.ARRAY_VERTEX:
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices := PackedInt32Array()
			if (
				arrays.size() > Mesh.ARRAY_INDEX
				and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array
			):
				indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			emitted_vertex_count += vertices.size()
			index_count += indices.size()
			for vertex: Vector3 in vertices:
				if not vertex.is_finite():
					nonfinite_vertex_count += 1
					continue
				if not has_bounds:
					bounds = AABB(vertex, Vector3.ZERO)
					has_bounds = true
				else:
					bounds = bounds.expand(vertex)
			var triangle_source_count := (
				indices.size() if not indices.is_empty() else vertices.size()
			)
			for source_index in range(0, triangle_source_count - 2, 3):
				emitted_triangle_count += 1
				var first_index := (
					indices[source_index]
					if not indices.is_empty()
					else source_index
				)
				var second_index := (
					indices[source_index + 1]
					if not indices.is_empty()
					else source_index + 1
				)
				var third_index := (
					indices[source_index + 2]
					if not indices.is_empty()
					else source_index + 2
				)
				if (
					first_index < 0
					or second_index < 0
					or third_index < 0
					or first_index >= vertices.size()
					or second_index >= vertices.size()
					or third_index >= vertices.size()
				):
					degenerate_triangle_count += 1
					continue
				var first := vertices[first_index]
				var second := vertices[second_index]
				var third := vertices[third_index]
				if (
					not first.is_finite()
					or not second.is_finite()
					or not third.is_finite()
					or (
						(second - first).cross(third - first).length_squared()
						<= TRIANGLE_AREA_EPSILON_SQUARED
					)
				):
					degenerate_triangle_count += 1
					continue
				var welded_triangle := PackedInt32Array([
					_get_or_append_welded_point_id(
						first,
						welded_point_ids,
						welded_points
					),
					_get_or_append_welded_point_id(
						second,
						welded_point_ids,
						welded_points
					),
					_get_or_append_welded_point_id(
						third,
						welded_point_ids,
						welded_points
					),
				])
				if (
					welded_triangle[0] == welded_triangle[1]
					or welded_triangle[1] == welded_triangle[2]
					or welded_triangle[2] == welded_triangle[0]
				):
					degenerate_triangle_count += 1
					continue
				triangles.append(welded_triangle)
				triangle_positions.append(PackedVector3Array([
					first,
					second,
					third,
				]))
				signed_volume += first.dot(second.cross(third)) / 6.0
				var first_key := _vector3i_key(_quantize_position(first))
				var second_key := _vector3i_key(_quantize_position(second))
				var third_key := _vector3i_key(_quantize_position(third))
				unoriented_triangle_keys.append(_unoriented_triangle_key(
					first_key,
					second_key,
					third_key
				))
				oriented_triangle_keys.append(_oriented_triangle_key(
					first_key,
					second_key,
					third_key
				))
	unoriented_triangle_keys.sort()
	oriented_triangle_keys.sort()
	var topology := _analyze_topology(triangles, welded_points.size())
	var strict_topology := _analyze_topology_lane(
		meshes,
		STRICT_POSITION_WELD_METERS
	)
	return {
		"mesh_count": meshes.size(),
		"surface_count": surface_count,
		"emitted_vertex_count": emitted_vertex_count,
		"emitted_triangle_count": emitted_triangle_count,
		"welded_vertex_count": welded_points.size(),
		"index_count": index_count,
		"triangle_count": triangles.size(),
		"degenerate_triangle_count": degenerate_triangle_count,
		"nonfinite_vertex_count": nonfinite_vertex_count,
		"signed_volume_cubic_meters": signed_volume,
		"absolute_volume_cubic_meters": absf(signed_volume),
		"signed_volume_sign": signf(signed_volume),
		"aabb_position_x": bounds.position.x if has_bounds else 0.0,
		"aabb_position_y": bounds.position.y if has_bounds else 0.0,
		"aabb_position_z": bounds.position.z if has_bounds else 0.0,
		"aabb_size_x": bounds.size.x if has_bounds else 0.0,
		"aabb_size_y": bounds.size.y if has_bounds else 0.0,
		"aabb_size_z": bounds.size.z if has_bounds else 0.0,
		"geometry_signature_unoriented": "\n".join(
			PackedStringArray(unoriented_triangle_keys)
		).sha256_text(),
		"geometry_signature_oriented": "\n".join(
			PackedStringArray(oriented_triangle_keys)
		).sha256_text(),
		"triangle_positions": triangle_positions,
		"surface_sample_points": _build_surface_sample_points(
			triangle_positions
		),
		"watertight": bool(topology.get("watertight", false)),
		"component_count": int(topology.get("component_count", 0)),
		"boundary_edge_count": int(topology.get("boundary_edge_count", 0)),
		"nonmanifold_edge_count": int(topology.get(
			"nonmanifold_edge_count",
			0
		)),
		"directed_edge_mismatch_count": int(topology.get(
			"directed_edge_mismatch_count",
			0
		)),
		"edge_count": int(topology.get("edge_count", 0)),
		"euler_characteristic": int(topology.get(
			"euler_characteristic",
			0
		)),
		"genus": float(topology.get("genus", 0.0)),
		"strict_topology_weld_tolerance_meters": (
			STRICT_POSITION_WELD_METERS
		),
		"strict_welded_vertex_count": int(strict_topology.get(
			"welded_vertex_count",
			0
		)),
		"strict_triangle_count": int(strict_topology.get(
			"triangle_count",
			0
		)),
		"strict_degenerate_triangle_collapse_count": int(
			strict_topology.get(
				"degenerate_triangle_collapse_count",
				0
			)
		),
		"strict_watertight": bool(strict_topology.get(
			"watertight",
			false
		)),
		"strict_component_count": int(strict_topology.get(
			"component_count",
			0
		)),
		"strict_boundary_edge_count": int(strict_topology.get(
			"boundary_edge_count",
			0
		)),
		"strict_nonmanifold_edge_count": int(strict_topology.get(
			"nonmanifold_edge_count",
			0
		)),
		"strict_directed_edge_mismatch_count": int(
			strict_topology.get(
				"directed_edge_mismatch_count",
				0
			)
		),
		"strict_edge_count": int(strict_topology.get("edge_count", 0)),
		"strict_euler_characteristic": int(strict_topology.get(
			"euler_characteristic",
			0
		)),
		"strict_genus": float(strict_topology.get("genus", 0.0)),
	}


static func _analyze_topology_lane(
	meshes: Array[ArrayMesh],
	weld_tolerance_meters: float
) -> Dictionary:
	var welded_point_ids: Dictionary = {}
	var welded_points: Array[Vector3] = []
	var triangles: Array[PackedInt32Array] = []
	var degenerate_triangle_collapse_count := 0
	for mesh: ArrayMesh in meshes:
		if mesh == null:
			continue
		for surface_index in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface_index)
			if arrays.size() <= Mesh.ARRAY_VERTEX:
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices := PackedInt32Array()
			if (
				arrays.size() > Mesh.ARRAY_INDEX
				and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array
			):
				indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			var triangle_source_count := (
				indices.size() if not indices.is_empty() else vertices.size()
			)
			for source_index in range(0, triangle_source_count - 2, 3):
				var first_index := (
					indices[source_index]
					if not indices.is_empty()
					else source_index
				)
				var second_index := (
					indices[source_index + 1]
					if not indices.is_empty()
					else source_index + 1
				)
				var third_index := (
					indices[source_index + 2]
					if not indices.is_empty()
					else source_index + 2
				)
				if (
					first_index < 0
					or second_index < 0
					or third_index < 0
					or first_index >= vertices.size()
					or second_index >= vertices.size()
					or third_index >= vertices.size()
				):
					continue
				var first := vertices[first_index]
				var second := vertices[second_index]
				var third := vertices[third_index]
				if (
					not first.is_finite()
					or not second.is_finite()
					or not third.is_finite()
					or (
						(second - first).cross(third - first).length_squared()
						<= TRIANGLE_AREA_EPSILON_SQUARED
					)
				):
					continue
				var welded_triangle := PackedInt32Array([
					_get_or_append_welded_point_id(
						first,
						welded_point_ids,
						welded_points,
						weld_tolerance_meters
					),
					_get_or_append_welded_point_id(
						second,
						welded_point_ids,
						welded_points,
						weld_tolerance_meters
					),
					_get_or_append_welded_point_id(
						third,
						welded_point_ids,
						welded_points,
						weld_tolerance_meters
					),
				])
				if (
					welded_triangle[0] == welded_triangle[1]
					or welded_triangle[1] == welded_triangle[2]
					or welded_triangle[2] == welded_triangle[0]
				):
					degenerate_triangle_collapse_count += 1
					continue
				triangles.append(welded_triangle)
	var topology := _analyze_topology(triangles, welded_points.size())
	topology["welded_vertex_count"] = welded_points.size()
	topology["triangle_count"] = triangles.size()
	topology["degenerate_triangle_collapse_count"] = (
		degenerate_triangle_collapse_count
	)
	return topology


static func compare_surfaces(
	first_analysis: Dictionary,
	second_analysis: Dictionary
) -> Dictionary:
	var first_samples: Array = first_analysis.get(
		"surface_sample_points",
		[]
	) as Array
	var second_samples: Array = second_analysis.get(
		"surface_sample_points",
		[]
	) as Array
	var first_triangles: Array = first_analysis.get(
		"triangle_positions",
		[]
	) as Array
	var second_triangles: Array = second_analysis.get(
		"triangle_positions",
		[]
	) as Array
	var first_witness := _max_sample_distance_witness(
		first_samples,
		second_triangles
	)
	var second_witness := _max_sample_distance_witness(
		second_samples,
		first_triangles
	)
	var first_to_second := float(first_witness.get("distance_meters", INF))
	var second_to_first := float(second_witness.get("distance_meters", INF))
	return {
		"first_to_second_max_meters": first_to_second,
		"second_to_first_max_meters": second_to_first,
		"bidirectional_max_meters": maxf(
			first_to_second,
			second_to_first
		),
		"first_sample_count": first_samples.size(),
		"second_sample_count": second_samples.size(),
		"first_to_second_witness": first_witness,
		"second_to_first_witness": second_witness,
	}


static func absolute_winding_number(
	point: Vector3,
	analysis: Dictionary
) -> float:
	var triangles := analysis.get("triangle_positions", []) as Array
	var solid_angle_sum := 0.0
	for triangle_variant: Variant in triangles:
		if not triangle_variant is PackedVector3Array:
			continue
		var triangle := triangle_variant as PackedVector3Array
		if triangle.size() < 3:
			continue
		var first := triangle[0] - point
		var second := triangle[1] - point
		var third := triangle[2] - point
		var first_length := first.length()
		var second_length := second.length()
		var third_length := third.length()
		if minf(
			first_length,
			minf(second_length, third_length)
		) <= 0.000000000001:
			# Winding is conventionally half-valued directly on the shell.
			return 0.5
		var numerator := first.dot(second.cross(third))
		var denominator := (
			first_length * second_length * third_length
			+ first.dot(second) * third_length
			+ second.dot(third) * first_length
			+ third.dot(first) * second_length
		)
		solid_angle_sum += 2.0 * atan2(numerator, denominator)
	# TAU is 2*PI, so 2*TAU normalizes the solid-angle sum by 4*PI.
	return absf(solid_angle_sum) / (2.0 * TAU)


static func strip_transient_arrays(analysis: Dictionary) -> Dictionary:
	var result := analysis.duplicate(false)
	result.erase("triangle_positions")
	result.erase("surface_sample_points")
	return result


static func _build_surface_sample_points(
	triangle_positions: Array[PackedVector3Array]
) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if triangle_positions.is_empty():
		return result
	var sample_step := maxi(
		int(ceil(float(triangle_positions.size()) / float(SURFACE_SAMPLE_LIMIT))),
		1
	)
	for triangle_index in range(0, triangle_positions.size(), sample_step):
		var triangle := triangle_positions[triangle_index]
		if triangle.size() < 3:
			continue
		result.append(triangle[0])
		result.append(triangle[1])
		result.append(triangle[2])
		result.append((triangle[0] + triangle[1] + triangle[2]) / 3.0)
	return result


static func _max_sample_distance_to_triangles(
	samples: Array,
	triangles: Array
) -> float:
	return float(_max_sample_distance_witness(
		samples,
		triangles
	).get("distance_meters", INF))


static func _max_sample_distance_witness(
	samples: Array,
	triangles: Array
) -> Dictionary:
	if samples.is_empty() or triangles.is_empty():
		return {
			"distance_meters": INF,
			"sample": Vector3.ZERO,
			"closest": Vector3.ZERO,
		}
	var maximum_distance_squared := 0.0
	var maximum_sample := Vector3.ZERO
	var maximum_closest := Vector3.ZERO
	for sample_variant: Variant in samples:
		if not (sample_variant is Vector3):
			continue
		var sample: Vector3 = sample_variant as Vector3
		var closest_distance_squared := INF
		var closest_point := Vector3.ZERO
		for triangle_variant: Variant in triangles:
			if not (triangle_variant is PackedVector3Array):
				continue
			var triangle: PackedVector3Array = (
				triangle_variant as PackedVector3Array
			)
			if triangle.size() < 3:
				continue
			var closest := Geometry3D.get_closest_point_to_segment(
				sample,
				triangle[0],
				triangle[1]
			)
			var edge_distance_squared := sample.distance_squared_to(closest)
			var triangle_closest := closest
			closest = Geometry3D.get_closest_point_to_segment(
				sample,
				triangle[1],
				triangle[2]
			)
			var candidate_distance_squared := sample.distance_squared_to(closest)
			if candidate_distance_squared < edge_distance_squared:
				edge_distance_squared = candidate_distance_squared
				triangle_closest = closest
			closest = Geometry3D.get_closest_point_to_segment(
				sample,
				triangle[2],
				triangle[0]
			)
			candidate_distance_squared = sample.distance_squared_to(closest)
			if candidate_distance_squared < edge_distance_squared:
				edge_distance_squared = candidate_distance_squared
				triangle_closest = closest
			var plane := Plane(triangle[0], triangle[1], triangle[2])
			var projected := plane.project(sample)
			if _point_is_inside_triangle(projected, triangle):
				candidate_distance_squared = sample.distance_squared_to(projected)
				if candidate_distance_squared < edge_distance_squared:
					edge_distance_squared = candidate_distance_squared
					triangle_closest = projected
			if edge_distance_squared < closest_distance_squared:
				closest_distance_squared = edge_distance_squared
				closest_point = triangle_closest
			if closest_distance_squared <= 0.0:
				break
		if closest_distance_squared > maximum_distance_squared:
			maximum_distance_squared = closest_distance_squared
			maximum_sample = sample
			maximum_closest = closest_point
	return {
		"distance_meters": sqrt(maximum_distance_squared),
		"sample": maximum_sample,
		"closest": maximum_closest,
	}


static func _point_is_inside_triangle(
	point: Vector3,
	triangle: PackedVector3Array
) -> bool:
	var first_edge := triangle[1] - triangle[0]
	var second_edge := triangle[2] - triangle[0]
	var offset := point - triangle[0]
	var dot00 := first_edge.dot(first_edge)
	var dot01 := first_edge.dot(second_edge)
	var dot02 := first_edge.dot(offset)
	var dot11 := second_edge.dot(second_edge)
	var dot12 := second_edge.dot(offset)
	var denominator := dot00 * dot11 - dot01 * dot01
	# Keep this rejection aligned with the triangle-degeneracy gate above.
	# A fixed 1e-12 cutoff rejects valid small Forge triangles and turns an
	# interior point-to-triangle query into an edge-only distance, overstating
	# otherwise identical surfaces by fractions of a millimeter.
	if absf(denominator) <= TRIANGLE_AREA_EPSILON_SQUARED:
		return false
	var inverse_denominator := 1.0 / denominator
	var first_ratio := (dot11 * dot02 - dot01 * dot12) * inverse_denominator
	var second_ratio := (dot00 * dot12 - dot01 * dot02) * inverse_denominator
	return (
		first_ratio >= -0.000001
		and second_ratio >= -0.000001
		and first_ratio + second_ratio <= 1.000001
	)


static func _get_or_append_welded_point_id(
	point: Vector3,
	welded_point_ids: Dictionary,
	welded_points: Array[Vector3],
	weld_tolerance_meters: float = POSITION_WELD_METERS
) -> int:
	var key := _quantize_position(point, weld_tolerance_meters)
	if welded_point_ids.has(key):
		return int(welded_point_ids[key])
	var next_id := welded_points.size()
	welded_point_ids[key] = next_id
	welded_points.append(point)
	return next_id


static func _quantize_position(
	point: Vector3,
	weld_tolerance_meters: float = POSITION_WELD_METERS
) -> Vector3i:
	return Vector3i(
		roundi(point.x / weld_tolerance_meters),
		roundi(point.y / weld_tolerance_meters),
		roundi(point.z / weld_tolerance_meters)
	)


static func _vector3i_key(value: Vector3i) -> String:
	return "%d,%d,%d" % [value.x, value.y, value.z]


static func _unoriented_triangle_key(
	first: String,
	second: String,
	third: String
) -> String:
	var keys: Array[String] = [first, second, third]
	keys.sort()
	return ";".join(keys)


static func _oriented_triangle_key(
	first: String,
	second: String,
	third: String
) -> String:
	var rotations: Array[String] = [
		"%s;%s;%s" % [first, second, third],
		"%s;%s;%s" % [second, third, first],
		"%s;%s;%s" % [third, first, second],
	]
	rotations.sort()
	return rotations[0]


static func _find_int_parent(parents: PackedInt32Array, index: int) -> int:
	var current := index
	while parents[current] != current:
		parents[current] = parents[parents[current]]
		current = parents[current]
	return current


static func _union_int_parents(
	parents: PackedInt32Array,
	first_index: int,
	second_index: int
) -> void:
	var first_root := _find_int_parent(parents, first_index)
	var second_root := _find_int_parent(parents, second_index)
	if first_root != second_root:
		parents[second_root] = first_root


static func _analyze_topology(
	triangles: Array[PackedInt32Array],
	vertex_count: int
) -> Dictionary:
	if triangles.is_empty():
		return {
			"watertight": false,
			"component_count": 0,
			"boundary_edge_count": 0,
			"nonmanifold_edge_count": 0,
			"directed_edge_mismatch_count": 0,
			"edge_count": 0,
			"euler_characteristic": vertex_count,
			"genus": 0.0,
		}
	var edge_records: Dictionary = {}
	for triangle_index in range(triangles.size()):
		var triangle := triangles[triangle_index]
		for edge_index in range(3):
			var first_id := triangle[edge_index]
			var second_id := triangle[(edge_index + 1) % 3]
			var low_id := mini(first_id, second_id)
			var high_id := maxi(first_id, second_id)
			var edge_key := "%d:%d" % [low_id, high_id]
			var record: Dictionary = edge_records.get(edge_key, {
				"count": 0,
				"forward": 0,
				"reverse": 0,
				"triangles": [],
			}) as Dictionary
			record["count"] = int(record["count"]) + 1
			if first_id == low_id:
				record["forward"] = int(record["forward"]) + 1
			else:
				record["reverse"] = int(record["reverse"]) + 1
			var touching: Array = record["triangles"] as Array
			touching.append(triangle_index)
			record["triangles"] = touching
			edge_records[edge_key] = record
	var parents := PackedInt32Array()
	for triangle_index in range(triangles.size()):
		parents.append(triangle_index)
	var boundary_edge_count := 0
	var nonmanifold_edge_count := 0
	var directed_edge_mismatch_count := 0
	for edge_key: String in edge_records.keys():
		var record: Dictionary = edge_records[edge_key] as Dictionary
		var edge_count := int(record.get("count", 0))
		if edge_count == 1:
			boundary_edge_count += 1
		elif edge_count > 2:
			nonmanifold_edge_count += 1
		if (
			edge_count == 2
			and not (
				int(record.get("forward", 0)) == 1
				and int(record.get("reverse", 0)) == 1
			)
		):
			directed_edge_mismatch_count += 1
		var touching: Array = record.get("triangles", []) as Array
		if touching.size() >= 2:
			var first_triangle := int(touching[0])
			for touching_index in range(1, touching.size()):
				_union_int_parents(
					parents,
					first_triangle,
					int(touching[touching_index])
				)
	var component_roots: Dictionary = {}
	for triangle_index in range(triangles.size()):
		component_roots[_find_int_parent(parents, triangle_index)] = true
	var component_count := component_roots.size()
	var euler_characteristic := (
		vertex_count - edge_records.size() + triangles.size()
	)
	var genus := (
		float(2 * component_count - euler_characteristic) / 2.0
	)
	return {
		"watertight": (
			boundary_edge_count == 0
			and nonmanifold_edge_count == 0
			and directed_edge_mismatch_count == 0
		),
		"component_count": component_count,
		"boundary_edge_count": boundary_edge_count,
		"nonmanifold_edge_count": nonmanifold_edge_count,
		"directed_edge_mismatch_count": directed_edge_mismatch_count,
		"edge_count": edge_records.size(),
		"euler_characteristic": euler_characteristic,
		"genus": genus,
	}
