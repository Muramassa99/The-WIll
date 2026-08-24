extends SceneTree

const ForgeV2WorkpieceBenchmarkFixtureScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_fixture.gd"
)
const ForgeV2MaterialVolumeResolverScript = preload(
	"res://runtime/forge_v2/forge_v2_material_volume_resolver.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)

const BENCHMARK_SCHEMA_VERSION := 1
const BACKEND_ID := &"legacy_permanent_csg_tree"
const RESULT_BASE_PATH := (
	"C:/WORKSPACE/godot_runs/forge_v2_workpiece_benchmark_legacy"
)
const RESULT_CSV_PATH := RESULT_BASE_PATH + ".csv"
const RESULT_JSON_PATH := RESULT_BASE_PATH + ".json"
const RESULT_TEXT_PATH := RESULT_BASE_PATH + ".txt"
const FRAME_SETTLE_COUNT := 3
const POSITION_WELD_METERS := 0.00001
const TRIANGLE_AREA_EPSILON_SQUARED := 0.0000000000000001

var benchmark_errors: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_BASE_PATH.get_base_dir())
	var max_operation_count := _read_environment_int(
		"FORGE_V2_BENCHMARK_MAX_OPERATIONS",
		ForgeV2WorkpieceBenchmarkFixtureScript.MAX_OPERATION_COUNT,
		1,
		ForgeV2WorkpieceBenchmarkFixtureScript.MAX_OPERATION_COUNT
	)
	var repeat_count := _read_environment_int(
		"FORGE_V2_BENCHMARK_REPEATS",
		1,
		1,
		20
	)
	var measure_collision := _read_environment_bool(
		"FORGE_V2_BENCHMARK_COLLISION",
		true
	)
	var checkpoints := (
		ForgeV2WorkpieceBenchmarkFixtureScript.get_scaling_checkpoints(
			max_operation_count
		)
	)
	print(
		"Forge V2 workpiece benchmark: backend=%s operations=%d repeats=%d"
		% [String(BACKEND_ID), max_operation_count, repeat_count]
	)

	var fixture_save_started := Time.get_ticks_usec()
	var fixture_result: Dictionary = (
		ForgeV2WorkpieceBenchmarkFixtureScript.save_fixture_wip(
			ForgeV2WorkpieceBenchmarkFixtureScript.FIXTURE_WIP_PATH,
			ForgeV2WorkpieceBenchmarkFixtureScript.MAX_OPERATION_COUNT
		)
	)
	var fixture_save_ms := _elapsed_milliseconds(fixture_save_started)
	_require(
		bool(fixture_result.get("ok", false)),
		"deterministic benchmark WIP did not save and reload cleanly: %s"
		% str(fixture_result.get("errors", fixture_result.get("error", "unknown")))
	)
	if not benchmark_errors.is_empty():
		_finish_benchmark(
			false,
			fixture_result,
			fixture_save_ms,
			[],
			[],
			max_operation_count,
			repeat_count,
			measure_collision
		)
		return

	var warmup_count := mini(max_operation_count, 10)
	print("Warm-up: %d accepted operations + one seed" % warmup_count)
	var warmup_bodies := (
		ForgeV2WorkpieceBenchmarkFixtureScript.build_body_sequence(
			warmup_count
		)
	)
	await _measure_checkpoint(
		warmup_bodies,
		warmup_count,
		-1,
		false
	)

	var rows: Array[Dictionary] = []
	for repeat_index in range(repeat_count):
		var full_body_sequence := (
			ForgeV2WorkpieceBenchmarkFixtureScript.build_body_sequence(
				max_operation_count
			)
		)
		for checkpoint: int in checkpoints:
			print(
				"Measure repeat %d/%d at operation %d"
				% [repeat_index + 1, repeat_count, checkpoint]
			)
			var checkpoint_bodies := _slice_body_sequence(
				full_body_sequence,
				checkpoint + 1
			)
			var row: Dictionary = await _measure_checkpoint(
				checkpoint_bodies,
				checkpoint,
				repeat_index,
				measure_collision
			)
			rows.append(row)
			_require(
				bool(row.get("capture_ok", false)),
				"checkpoint %d repeat %d could not be captured"
				% [checkpoint, repeat_index + 1]
			)
	var summaries := _summarize_rows(rows, checkpoints)
	_finish_benchmark(
		benchmark_errors.is_empty(),
		fixture_result,
		fixture_save_ms,
		rows,
		summaries,
		max_operation_count,
		repeat_count,
		measure_collision
	)


func _measure_checkpoint(
	bodies: Array[Resource],
	operation_count: int,
	repeat_index: int,
	measure_collision: bool
) -> Dictionary:
	var capture_started := Time.get_ticks_usec()
	var presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	presenter.name = "BenchmarkPresenter"
	root.add_child(presenter)
	await process_frame
	var harness_root := Node3D.new()
	harness_root.name = "BenchmarkLegacyCSG_%03d" % operation_count
	root.add_child(harness_root)
	var memory_before_bytes := int(
		Performance.get_monitor(Performance.MEMORY_STATIC)
	)
	var object_count_before := int(
		Performance.get_monitor(Performance.OBJECT_COUNT)
	)

	var zone_started := Time.get_ticks_usec()
	var zones: Array = presenter.call("_build_csg_body_zones", bodies) as Array
	var zone_discovery_ms := _elapsed_milliseconds(zone_started)
	var zone_nodes: Array[CSGCombiner3D] = []
	var node_build_started := Time.get_ticks_usec()
	for zone_variant: Variant in zones:
		if not (zone_variant is Dictionary):
			continue
		var zone_node: CSGCombiner3D = presenter.call(
			"_build_csg_zone_node",
			zone_variant as Dictionary,
			false,
			"BenchmarkZone"
		) as CSGCombiner3D
		if zone_node == null:
			continue
		harness_root.add_child(zone_node)
		zone_nodes.append(zone_node)
	var node_build_ms := _elapsed_milliseconds(node_build_started)
	var node_counts := _count_scene_nodes(harness_root)

	var frame_gaps_ms: Array[float] = []
	var settle_started := Time.get_ticks_usec()
	for _frame_index in range(FRAME_SETTLE_COUNT):
		var frame_started := Time.get_ticks_usec()
		await process_frame
		frame_gaps_ms.append(_elapsed_milliseconds(frame_started))
	var settle_wall_ms := _elapsed_milliseconds(settle_started)
	var max_frame_gap_ms := _maximum_float(frame_gaps_ms)

	var baked_meshes: Array[ArrayMesh] = []
	var static_bake_started := Time.get_ticks_usec()
	for zone_node: CSGCombiner3D in zone_nodes:
		var baked_mesh := zone_node.bake_static_mesh()
		if baked_mesh != null and baked_mesh.get_surface_count() > 0:
			baked_meshes.append(baked_mesh)
	var static_bake_ms := _elapsed_milliseconds(static_bake_started)
	var geometry_metrics := _analyze_baked_meshes(baked_meshes)

	var collision_bake_ms := 0.0
	var collision_face_count := 0
	if measure_collision:
		var collision_started := Time.get_ticks_usec()
		for zone_node: CSGCombiner3D in zone_nodes:
			var collision_shape := zone_node.bake_collision_shape()
			if collision_shape != null:
				collision_face_count += collision_shape.get_faces().size() / 3
		collision_bake_ms = _elapsed_milliseconds(collision_started)

	var material_started := Time.get_ticks_usec()
	var volume_resolver = ForgeV2MaterialVolumeResolverScript.new()
	var usage_summary: Dictionary = volume_resolver.call(
		"build_usage_summary",
		bodies
	) as Dictionary
	var material_resolve_ms := _elapsed_milliseconds(material_started)
	var memory_after_bytes := int(
		Performance.get_monitor(Performance.MEMORY_STATIC)
	)
	var object_count_after := int(
		Performance.get_monitor(Performance.OBJECT_COUNT)
	)
	var expected_body_count := operation_count + 1
	var capture_ok := (
		bodies.size() == expected_body_count
		and zones.size() == 1
		and zone_nodes.size() == 1
		and not baked_meshes.is_empty()
		and int(geometry_metrics.get("triangle_count", 0)) > 0
	)
	var geometry_gate_pass := (
		bool(geometry_metrics.get("watertight", false))
		and int(geometry_metrics.get("component_count", 0)) == 1
		and int(geometry_metrics.get("degenerate_triangle_count", 0)) == 0
		and int(geometry_metrics.get("nonfinite_vertex_count", 0)) == 0
	)
	var row := {
		"benchmark_schema": BENCHMARK_SCHEMA_VERSION,
		"backend_id": String(BACKEND_ID),
		"fixture_schema": ForgeV2WorkpieceBenchmarkFixtureScript.FIXTURE_SCHEMA_VERSION,
		"fixture_id": String(ForgeV2WorkpieceBenchmarkFixtureScript.FIXTURE_ID),
		"fixture_signature": (
			ForgeV2WorkpieceBenchmarkFixtureScript.build_fixture_signature(
				operation_count
			)
		),
		"repeat": repeat_index + 1,
		"operation_count": operation_count,
		"seed_count": 1,
		"logical_body_count": bodies.size(),
		"path_samples_per_body": (
			ForgeV2WorkpieceBenchmarkFixtureScript.PATH_SAMPLE_COUNT
		),
		"zone_count": zones.size(),
		"zone_discovery_ms": zone_discovery_ms,
		"node_build_ms": node_build_ms,
		"settle_wall_ms": settle_wall_ms,
		"max_frame_gap_ms": max_frame_gap_ms,
		"static_bake_ms": static_bake_ms,
		"collision_bake_ms": collision_bake_ms,
		"collision_face_count": collision_face_count,
		"material_resolve_ms": material_resolve_ms,
		"capture_total_ms": _elapsed_milliseconds(capture_started),
		"memory_before_bytes": memory_before_bytes,
		"memory_after_bytes": memory_after_bytes,
		"memory_delta_bytes": memory_after_bytes - memory_before_bytes,
		"object_count_before": object_count_before,
		"object_count_after": object_count_after,
		"object_count_delta": object_count_after - object_count_before,
		"material_count": (
			(usage_summary.get("materials", {}) as Dictionary).size()
		),
		"rough_material_units": float(usage_summary.get(
			"total_rough_material_units",
			0.0
		)),
		"rough_volume_cell_equivalents": float(usage_summary.get(
			"total_rough_volume_cell_equivalents",
			0.0
		)),
		"material_summary_signature": _build_material_summary_signature(
			usage_summary
		),
		"capture_ok": capture_ok,
		"geometry_gate_pass": geometry_gate_pass,
	}
	row.merge(node_counts, true)
	row.merge(geometry_metrics, true)

	root.remove_child(harness_root)
	harness_root.free()
	root.remove_child(presenter)
	presenter.free()
	await process_frame
	return row


func _finish_benchmark(
	ok: bool,
	fixture_result: Dictionary,
	fixture_save_ms: float,
	rows: Array[Dictionary],
	summaries: Array[Dictionary],
	max_operation_count: int,
	repeat_count: int,
	measure_collision: bool
) -> void:
	var all_geometry_gates_pass := not rows.is_empty()
	for row: Dictionary in rows:
		if not bool(row.get("geometry_gate_pass", false)):
			all_geometry_gates_pass = false
			break
	var metadata := {
		"benchmark_schema": BENCHMARK_SCHEMA_VERSION,
		"backend_id": String(BACKEND_ID),
		"engine_version": Engine.get_version_info(),
		"machine_label": _read_environment_string(
			"FORGE_V2_BENCHMARK_MACHINE_LABEL",
			"local_unspecified"
		),
		"run_notes": _read_environment_string(
			"FORGE_V2_BENCHMARK_RUN_NOTES",
			""
		),
		"os_name": OS.get_name(),
		"processor_count": OS.get_processor_count(),
		"fixture_path": ForgeV2WorkpieceBenchmarkFixtureScript.FIXTURE_WIP_PATH,
		"fixture_save_ms": fixture_save_ms,
		"max_operation_count": max_operation_count,
		"repeat_count": repeat_count,
		"frame_settle_count": FRAME_SETTLE_COUNT,
		"collision_lane_enabled": measure_collision,
		"protected_live_wips": ["Test Glave", "Test sword for animations"],
		"live_player_library_accessed": false,
		"result_base_path": RESULT_BASE_PATH,
	}
	var payload := {
		"ok": ok,
		"baseline_capture_ok": ok,
		"all_geometry_gates_pass": all_geometry_gates_pass,
		"metadata": metadata,
		"fixture": fixture_result,
		"errors": benchmark_errors,
		"rows": rows,
		"summaries": summaries,
	}
	_write_json_result(payload)
	_write_csv_result(rows)
	_write_text_result(payload)
	if ok:
		print(
			"Forge V2 workpiece benchmark complete: %s"
			% RESULT_TEXT_PATH
		)
	else:
		push_error(
			"Forge V2 workpiece benchmark failed: %s"
			% "; ".join(benchmark_errors)
		)
	quit(0 if ok else 1)


func _slice_body_sequence(
	bodies: Array[Resource],
	requested_size: int
) -> Array[Resource]:
	var result: Array[Resource] = []
	var safe_size := mini(maxi(requested_size, 0), bodies.size())
	for body_index in range(safe_size):
		result.append(bodies[body_index])
	return result


func _count_scene_nodes(parent: Node) -> Dictionary:
	var counts := {
		"scene_node_count": 0,
		"csg_shape_count": 0,
		"csg_combiner_count": 0,
		"csg_operand_count": 0,
		"csg_mesh_operand_count": 0,
		"csg_polygon_operand_count": 0,
	}
	_count_scene_nodes_recursive(parent, counts)
	return counts


func _count_scene_nodes_recursive(node: Node, counts: Dictionary) -> void:
	if node == null:
		return
	counts["scene_node_count"] = int(counts["scene_node_count"]) + 1
	if node is CSGShape3D:
		counts["csg_shape_count"] = int(counts["csg_shape_count"]) + 1
		if node is CSGCombiner3D:
			counts["csg_combiner_count"] = int(
				counts["csg_combiner_count"]
			) + 1
		else:
			counts["csg_operand_count"] = int(
				counts["csg_operand_count"]
			) + 1
			if node is CSGMesh3D:
				counts["csg_mesh_operand_count"] = int(
					counts["csg_mesh_operand_count"]
				) + 1
			elif node is CSGPolygon3D:
				counts["csg_polygon_operand_count"] = int(
					counts["csg_polygon_operand_count"]
				) + 1
	for child: Node in node.get_children():
		_count_scene_nodes_recursive(child, counts)


func _analyze_baked_meshes(meshes: Array[ArrayMesh]) -> Dictionary:
	var welded_point_ids: Dictionary = {}
	var welded_points: Array[Vector3] = []
	var triangles: Array[PackedInt32Array] = []
	var canonical_triangles: Array[String] = []
	var surface_count := 0
	var emitted_vertex_count := 0
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
				var vertex_indices := PackedInt32Array([
					indices[source_index] if not indices.is_empty() else source_index,
					indices[source_index + 1] if not indices.is_empty() else source_index + 1,
					indices[source_index + 2] if not indices.is_empty() else source_index + 2,
				])
				if (
					vertex_indices[0] < 0
					or vertex_indices[1] < 0
					or vertex_indices[2] < 0
					or vertex_indices[0] >= vertices.size()
					or vertex_indices[1] >= vertices.size()
					or vertex_indices[2] >= vertices.size()
				):
					degenerate_triangle_count += 1
					continue
				var first := vertices[vertex_indices[0]]
				var second := vertices[vertex_indices[1]]
				var third := vertices[vertex_indices[2]]
				if (
					not first.is_finite()
					or not second.is_finite()
					or not third.is_finite()
				):
					degenerate_triangle_count += 1
					continue
				if (
					(second - first).cross(third - first).length_squared()
					<= TRIANGLE_AREA_EPSILON_SQUARED
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
				signed_volume += first.dot(second.cross(third)) / 6.0
				canonical_triangles.append(_canonical_triangle_key(
					_quantize_position(first),
					_quantize_position(second),
					_quantize_position(third)
				))
	canonical_triangles.sort()
	var topology := _analyze_triangle_topology(triangles)
	var geometry_signature := "\n".join(
		PackedStringArray(canonical_triangles)
	).sha256_text()
	return {
		"baked_mesh_count": meshes.size(),
		"surface_count": surface_count,
		"emitted_vertex_count": emitted_vertex_count,
		"welded_vertex_count": welded_points.size(),
		"index_count": index_count,
		"triangle_count": triangles.size(),
		"degenerate_triangle_count": degenerate_triangle_count,
		"nonfinite_vertex_count": nonfinite_vertex_count,
		"signed_volume_cubic_meters": signed_volume,
		"absolute_volume_cubic_meters": absf(signed_volume),
		"aabb_position_x": bounds.position.x if has_bounds else 0.0,
		"aabb_position_y": bounds.position.y if has_bounds else 0.0,
		"aabb_position_z": bounds.position.z if has_bounds else 0.0,
		"aabb_size_x": bounds.size.x if has_bounds else 0.0,
		"aabb_size_y": bounds.size.y if has_bounds else 0.0,
		"aabb_size_z": bounds.size.z if has_bounds else 0.0,
		"geometry_signature": geometry_signature,
		"watertight": bool(topology.get("watertight", false)),
		"component_count": int(topology.get("component_count", 0)),
		"boundary_edge_count": int(topology.get("boundary_edge_count", 0)),
		"nonmanifold_edge_count": int(topology.get(
			"nonmanifold_edge_count",
			0
		)),
	}


func _get_or_append_welded_point_id(
	point: Vector3,
	welded_point_ids: Dictionary,
	welded_points: Array[Vector3]
) -> int:
	var key := _quantize_position(point)
	if welded_point_ids.has(key):
		return int(welded_point_ids[key])
	var next_id := welded_points.size()
	welded_point_ids[key] = next_id
	welded_points.append(point)
	return next_id


func _quantize_position(point: Vector3) -> Vector3i:
	return Vector3i(
		roundi(point.x / POSITION_WELD_METERS),
		roundi(point.y / POSITION_WELD_METERS),
		roundi(point.z / POSITION_WELD_METERS)
	)


func _canonical_triangle_key(
	first: Vector3i,
	second: Vector3i,
	third: Vector3i
) -> String:
	var vertex_keys: Array[String] = [
		_vector3i_key(first),
		_vector3i_key(second),
		_vector3i_key(third),
	]
	vertex_keys.sort()
	return ";".join(vertex_keys)


func _vector3i_key(value: Vector3i) -> String:
	return "%d,%d,%d" % [value.x, value.y, value.z]


func _build_material_summary_signature(summary: Dictionary) -> String:
	var lines := PackedStringArray([
		"total_cells=%.9f" % float(summary.get(
			"total_rough_volume_cell_equivalents",
			0.0
		)),
		"total_centi=%d" % int(summary.get(
			"total_rough_material_centi_units",
			0
		)),
	])
	var materials: Dictionary = summary.get("materials", {}) as Dictionary
	var material_ids: Array[String] = []
	for material_id_variant: Variant in materials.keys():
		material_ids.append(String(material_id_variant))
	material_ids.sort()
	for material_id: String in material_ids:
		var entry: Dictionary = materials.get(
			StringName(material_id),
			materials.get(material_id, {})
		) as Dictionary
		lines.append(
			"%s|%.9f|%d" % [
				material_id,
				float(entry.get("rough_volume_cell_equivalents", 0.0)),
				int(entry.get("rough_material_centi_units", 0)),
			]
		)
	return "\n".join(lines).sha256_text()


func _analyze_triangle_topology(
	triangles: Array[PackedInt32Array]
) -> Dictionary:
	if triangles.is_empty():
		return {
			"watertight": false,
			"component_count": 0,
			"boundary_edge_count": 0,
			"nonmanifold_edge_count": 0,
		}
	var edge_counts: Dictionary = {}
	var edge_triangle_ids: Dictionary = {}
	for triangle_index in range(triangles.size()):
		var triangle := triangles[triangle_index]
		for edge_index in range(3):
			var first_id := triangle[edge_index]
			var second_id := triangle[(edge_index + 1) % 3]
			var edge_key := _undirected_edge_key(first_id, second_id)
			edge_counts[edge_key] = int(edge_counts.get(edge_key, 0)) + 1
			var touching_triangles: Array = edge_triangle_ids.get(
				edge_key,
				[]
			) as Array
			touching_triangles.append(triangle_index)
			edge_triangle_ids[edge_key] = touching_triangles
	var parents := PackedInt32Array()
	for triangle_index in range(triangles.size()):
		parents.append(triangle_index)
	var boundary_edge_count := 0
	var nonmanifold_edge_count := 0
	for edge_key: String in edge_counts.keys():
		var edge_count := int(edge_counts[edge_key])
		if edge_count == 1:
			boundary_edge_count += 1
		elif edge_count > 2:
			nonmanifold_edge_count += 1
		var touching_triangles: Array = edge_triangle_ids.get(
			edge_key,
			[]
		) as Array
		if touching_triangles.size() < 2:
			continue
		var first_triangle := int(touching_triangles[0])
		for touching_index in range(1, touching_triangles.size()):
			_union_int_parents(
				parents,
				first_triangle,
				int(touching_triangles[touching_index])
			)
	var component_roots: Dictionary = {}
	for triangle_index in range(triangles.size()):
		component_roots[_find_int_parent(parents, triangle_index)] = true
	return {
		"watertight": (
			boundary_edge_count == 0
			and nonmanifold_edge_count == 0
		),
		"component_count": component_roots.size(),
		"boundary_edge_count": boundary_edge_count,
		"nonmanifold_edge_count": nonmanifold_edge_count,
	}


func _undirected_edge_key(first_id: int, second_id: int) -> String:
	if first_id <= second_id:
		return "%d:%d" % [first_id, second_id]
	return "%d:%d" % [second_id, first_id]


func _find_int_parent(parents: PackedInt32Array, index: int) -> int:
	var current := index
	while parents[current] != current:
		parents[current] = parents[parents[current]]
		current = parents[current]
	return current


func _union_int_parents(
	parents: PackedInt32Array,
	first_index: int,
	second_index: int
) -> void:
	var first_root := _find_int_parent(parents, first_index)
	var second_root := _find_int_parent(parents, second_index)
	if first_root != second_root:
		parents[second_root] = first_root


func _summarize_rows(
	rows: Array[Dictionary],
	checkpoints: PackedInt32Array
) -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for checkpoint: int in checkpoints:
		var checkpoint_rows: Array[Dictionary] = []
		for row: Dictionary in rows:
			if int(row.get("operation_count", -1)) == checkpoint:
				checkpoint_rows.append(row)
		if checkpoint_rows.is_empty():
			continue
		var summary := {
			"operation_count": checkpoint,
			"sample_count": checkpoint_rows.size(),
			"node_build_ms_median": _row_statistic(
				checkpoint_rows,
				"node_build_ms",
				0.5
			),
			"node_build_ms_p95": _row_statistic(
				checkpoint_rows,
				"node_build_ms",
				0.95
			),
			"max_frame_gap_ms_median": _row_statistic(
				checkpoint_rows,
				"max_frame_gap_ms",
				0.5
			),
			"max_frame_gap_ms_p95": _row_statistic(
				checkpoint_rows,
				"max_frame_gap_ms",
				0.95
			),
			"static_bake_ms_median": _row_statistic(
				checkpoint_rows,
				"static_bake_ms",
				0.5
			),
			"capture_total_ms_median": _row_statistic(
				checkpoint_rows,
				"capture_total_ms",
				0.5
			),
			"capture_total_ms_p95": _row_statistic(
				checkpoint_rows,
				"capture_total_ms",
				0.95
			),
			"logical_body_count": int(checkpoint_rows[0].get(
				"logical_body_count",
				0
			)),
			"csg_operand_count": int(checkpoint_rows[0].get(
				"csg_operand_count",
				0
			)),
			"triangle_count": int(checkpoint_rows[0].get(
				"triangle_count",
				0
			)),
			"geometry_signature": String(checkpoint_rows[0].get(
				"geometry_signature",
				""
			)),
			"geometry_gate_pass": bool(checkpoint_rows[0].get(
				"geometry_gate_pass",
				false
			)),
		}
		summaries.append(summary)
	return summaries


func _row_statistic(
	rows: Array[Dictionary],
	field_name: String,
	ratio: float
) -> float:
	var values: Array[float] = []
	for row: Dictionary in rows:
		values.append(float(row.get(field_name, 0.0)))
	if values.is_empty():
		return 0.0
	values.sort()
	var index := clampi(
		int(ceil(float(values.size()) * clampf(ratio, 0.0, 1.0))) - 1,
		0,
		values.size() - 1
	)
	return values[index]


func _write_json_result(payload: Dictionary) -> void:
	var file := FileAccess.open(RESULT_JSON_PATH, FileAccess.WRITE)
	if file == null:
		benchmark_errors.append("json_result_open_failed")
		return
	file.store_string(JSON.stringify(payload, "\t", false) + "\n")
	file.close()


func _write_csv_result(rows: Array[Dictionary]) -> void:
	var headers: Array[String] = [
		"backend_id",
		"repeat",
		"operation_count",
		"seed_count",
		"logical_body_count",
		"path_samples_per_body",
		"zone_count",
		"scene_node_count",
		"csg_shape_count",
		"csg_combiner_count",
		"csg_operand_count",
		"zone_discovery_ms",
		"node_build_ms",
		"settle_wall_ms",
		"max_frame_gap_ms",
		"static_bake_ms",
		"collision_bake_ms",
		"collision_face_count",
		"material_resolve_ms",
		"capture_total_ms",
		"memory_delta_bytes",
		"object_count_delta",
		"surface_count",
		"emitted_vertex_count",
		"welded_vertex_count",
		"triangle_count",
		"degenerate_triangle_count",
		"nonfinite_vertex_count",
		"boundary_edge_count",
		"nonmanifold_edge_count",
		"component_count",
		"watertight",
		"absolute_volume_cubic_meters",
		"aabb_position_x",
		"aabb_position_y",
		"aabb_position_z",
		"aabb_size_x",
		"aabb_size_y",
		"aabb_size_z",
		"material_count",
		"rough_material_units",
		"rough_volume_cell_equivalents",
		"material_summary_signature",
		"geometry_signature",
		"capture_ok",
		"geometry_gate_pass",
	]
	var lines := PackedStringArray([",".join(headers)])
	for row: Dictionary in rows:
		var values := PackedStringArray()
		for header: String in headers:
			values.append(_escape_csv_value(row.get(header, "")))
		lines.append(",".join(values))
	var file := FileAccess.open(RESULT_CSV_PATH, FileAccess.WRITE)
	if file == null:
		benchmark_errors.append("csv_result_open_failed")
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()


func _write_text_result(payload: Dictionary) -> void:
	var metadata: Dictionary = payload.get("metadata", {}) as Dictionary
	var fixture: Dictionary = payload.get("fixture", {}) as Dictionary
	var lines := PackedStringArray([
		"Forge V2 Workpiece Compiler Baseline Benchmark",
		"ok=%s" % str(bool(payload.get("ok", false))).to_lower(),
		"baseline_capture_ok=%s" % str(
			bool(payload.get("baseline_capture_ok", false))
		).to_lower(),
		"all_geometry_gates_pass=%s" % str(
			bool(payload.get("all_geometry_gates_pass", false))
		).to_lower(),
		"backend_id=%s" % String(metadata.get("backend_id", "")),
		"machine_label=%s" % String(metadata.get("machine_label", "")),
		"run_notes=%s" % String(metadata.get("run_notes", "")),
		"fixture_path=%s" % String(metadata.get("fixture_path", "")),
		"fixture_signature=%s" % String(fixture.get("signature", "")),
		"fixture_bytes=%d" % int(fixture.get("bytes", -1)),
		"fixture_save_ms=%.3f" % float(metadata.get("fixture_save_ms", 0.0)),
		"max_operation_count=%d" % int(metadata.get("max_operation_count", 0)),
		"repeat_count=%d" % int(metadata.get("repeat_count", 0)),
		"live_player_library_accessed=false",
		"protected_live_wips=Test Glave | Test sword for animations",
		"",
		"Checkpoint summaries:",
	])
	var summaries: Array = payload.get("summaries", []) as Array
	for summary_variant: Variant in summaries:
		if not (summary_variant is Dictionary):
			continue
		var summary: Dictionary = summary_variant as Dictionary
		lines.append(
			(
				"ops=%d bodies=%d operands=%d triangles=%d "
				+ "node_build_median_ms=%.3f max_frame_p95_ms=%.3f "
				+ "capture_p95_ms=%.3f geometry_gate=%s"
			) % [
				int(summary.get("operation_count", 0)),
				int(summary.get("logical_body_count", 0)),
				int(summary.get("csg_operand_count", 0)),
				int(summary.get("triangle_count", 0)),
				float(summary.get("node_build_ms_median", 0.0)),
				float(summary.get("max_frame_gap_ms_p95", 0.0)),
				float(summary.get("capture_total_ms_p95", 0.0)),
				str(bool(summary.get("geometry_gate_pass", false))).to_lower(),
			]
		)
	var errors: Array = payload.get("errors", []) as Array
	if not errors.is_empty():
		lines.append("")
		lines.append("Errors:")
		for error_variant: Variant in errors:
			lines.append("- %s" % String(error_variant))
	var file := FileAccess.open(RESULT_TEXT_PATH, FileAccess.WRITE)
	if file == null:
		benchmark_errors.append("text_result_open_failed")
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()


func _escape_csv_value(value: Variant) -> String:
	var text := str(value)
	if text.contains(",") or text.contains("\"") or text.contains("\n"):
		return "\"%s\"" % text.replace("\"", "\"\"")
	return text


func _read_environment_int(
	variable_name: String,
	default_value: int,
	minimum_value: int,
	maximum_value: int
) -> int:
	var raw_value := OS.get_environment(variable_name).strip_edges()
	if raw_value.is_empty() or not raw_value.is_valid_int():
		return default_value
	return clampi(raw_value.to_int(), minimum_value, maximum_value)


func _read_environment_bool(
	variable_name: String,
	default_value: bool
) -> bool:
	var raw_value := OS.get_environment(variable_name).strip_edges().to_lower()
	if raw_value.is_empty():
		return default_value
	return raw_value in ["1", "true", "yes", "on"]


func _read_environment_string(
	variable_name: String,
	default_value: String
) -> String:
	var raw_value := OS.get_environment(variable_name).strip_edges()
	return default_value if raw_value.is_empty() else raw_value


func _elapsed_milliseconds(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _maximum_float(values: Array[float]) -> float:
	var result := 0.0
	for value: float in values:
		result = maxf(result, value)
	return result


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	benchmark_errors.append(message)
