extends SceneTree

const FixtureScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_fixture.gd"
)
const MeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)
const RollingBackendScript = preload(
	"res://tools/forge_v2_rolling_csg_workpiece_backend.gd"
)
const ForgeV2MaterialVolumeResolverScript = preload(
	"res://runtime/forge_v2/forge_v2_material_volume_resolver.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)

const BENCHMARK_SCHEMA_VERSION := 1
const RESULT_BASE_PATH := (
	"C:/WORKSPACE/godot_runs/forge_v2_workpiece_benchmark_rolling"
)
const RESULT_CSV_PATH := RESULT_BASE_PATH + ".csv"
const RESULT_JSON_PATH := RESULT_BASE_PATH + ".json"
const RESULT_TEXT_PATH := RESULT_BASE_PATH + ".txt"
const FRAME_SETTLE_COUNT := 3
const AABB_TOLERANCE_METERS := 0.00001
const VOLUME_RELATIVE_TOLERANCE := 0.001
const SURFACE_DISTANCE_TOLERANCE_METERS := 0.00002
const GENUS_TOLERANCE := 0.000001

var benchmark_errors: Array[String] = []
var legacy_reference_analyses: Dictionary = {}
var parity_cache: Dictionary = {}
var absorption_window_size := 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_BASE_PATH.get_base_dir())
	var max_operation_count := _read_environment_int(
		"FORGE_V2_BENCHMARK_MAX_OPERATIONS",
		FixtureScript.MAX_OPERATION_COUNT,
		1,
		FixtureScript.MAX_OPERATION_COUNT
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
	absorption_window_size = _read_environment_int(
		"FORGE_V2_ROLLING_ABSORPTION_WINDOW",
		1,
		1,
		RollingBackendScript.MAX_ABSORPTION_WINDOW_SIZE
	)
	var checkpoints := FixtureScript.get_scaling_checkpoints(
		max_operation_count
	)
	print(
		"Forge V2 rolling benchmark: operations=%d repeats=%d window=%d"
		% [max_operation_count, repeat_count, absorption_window_size]
	)
	var fixture_result: Dictionary = FixtureScript.save_fixture_wip(
		FixtureScript.FIXTURE_WIP_PATH,
		FixtureScript.MAX_OPERATION_COUNT
	)
	_require(
		bool(fixture_result.get("ok", false)),
		"fixture did not save/reload deterministically: %s"
		% str(fixture_result.get("errors", fixture_result.get("error", "unknown")))
	)
	if not benchmark_errors.is_empty():
		_finish_benchmark(
			false,
			fixture_result,
			[],
			[],
			max_operation_count,
			repeat_count,
			measure_collision
		)
		return

	var full_body_sequence := FixtureScript.build_body_sequence(
		max_operation_count
	)
	print("Building legacy geometry oracles at fixed checkpoints")
	legacy_reference_analyses = await _build_legacy_reference_analyses(
		full_body_sequence,
		checkpoints
	)
	for checkpoint: int in checkpoints:
		_require(
			legacy_reference_analyses.has(checkpoint),
			"legacy oracle missing at operation %d" % checkpoint
		)
	if not benchmark_errors.is_empty():
		_finish_benchmark(
			false,
			fixture_result,
			[],
			[],
			max_operation_count,
			repeat_count,
			measure_collision
		)
		return

	var warmup_count := mini(max_operation_count, 10)
	print("Rolling warm-up: %d accepted operations + one direct seed" % warmup_count)
	await _run_rolling_sequence(
		FixtureScript.build_body_sequence(warmup_count),
		PackedInt32Array([warmup_count]),
		-1,
		false,
		false
	)

	var rows: Array[Dictionary] = []
	for repeat_index in range(repeat_count):
		print("Rolling repeat %d/%d" % [repeat_index + 1, repeat_count])
		var repeat_rows: Array[Dictionary] = await _run_rolling_sequence(
			FixtureScript.build_body_sequence(max_operation_count),
			checkpoints,
			repeat_index,
			measure_collision,
			true
		)
		rows.append_array(repeat_rows)
	var summaries := _summarize_rows(rows, checkpoints)
	var all_rows_pass := rows.size() == checkpoints.size() * repeat_count
	for row: Dictionary in rows:
		if not bool(row.get("candidate_pass", false)):
			all_rows_pass = false
			break
	_finish_benchmark(
		benchmark_errors.is_empty() and all_rows_pass,
		fixture_result,
		rows,
		summaries,
		max_operation_count,
		repeat_count,
		measure_collision
	)


func _run_rolling_sequence(
	bodies: Array[Resource],
	checkpoints: PackedInt32Array,
	repeat_index: int,
	measure_collision: bool,
	capture_rows: bool
) -> Array[Dictionary]:
	var result_rows: Array[Dictionary] = []
	if bodies.size() < 2:
		return result_rows
	var presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	presenter.name = "RollingBenchmarkPresenter"
	root.add_child(presenter)
	var backend_host := Node3D.new()
	backend_host.name = "RollingBenchmarkHost"
	root.add_child(backend_host)
	await process_frame
	var backend = RollingBackendScript.new()
	var initialize_result: Dictionary = backend.initialize(
		backend_host,
		presenter,
		absorption_window_size
	)
	if not bool(initialize_result.get("ok", false)):
		benchmark_errors.append("rolling backend initialization failed")
		_cleanup_sequence_nodes(backend, backend_host, presenter)
		await process_frame
		return result_rows
	var seed_result: Dictionary = backend.initialize_seed(bodies[0])
	if not bool(seed_result.get("ok", false)):
		benchmark_errors.append(
			"rolling seed initialization failed: %s"
			% String(seed_result.get("error", "unknown"))
		)
		_cleanup_sequence_nodes(backend, backend_host, presenter)
		await process_frame
		return result_rows
	var cumulative_compile_ms := 0.0
	var prefix_max_operation_compile_ms := 0.0
	var prefix_max_frame_gap_ms := 0.0
	for operation_index in range(1, bodies.size()):
		var operation_count := operation_index
		var operation_result: Dictionary = await backend.apply_add_body(
			bodies[operation_index],
			FRAME_SETTLE_COUNT,
			false
		)
		if not bool(operation_result.get("ok", false)):
			benchmark_errors.append(
				"rolling operation %d failed: %s"
				% [
					operation_count,
					String(operation_result.get("error", "unknown")),
				]
			)
			break
		cumulative_compile_ms += float(operation_result.get(
			"operation_compile_total_ms",
			0.0
		))
		prefix_max_operation_compile_ms = maxf(
			prefix_max_operation_compile_ms,
			float(operation_result.get("operation_compile_total_ms", 0.0))
		)
		prefix_max_frame_gap_ms = maxf(
			prefix_max_frame_gap_ms,
			float(operation_result.get("max_frame_gap_ms", 0.0))
		)
		if not capture_rows or not checkpoints.has(operation_count):
			continue
		print(
			"Capture rolling repeat %d at operation %d"
			% [repeat_index + 1, operation_count]
		)
		var row := _capture_rolling_checkpoint(
			backend,
			bodies,
			operation_count,
			repeat_index,
			operation_result,
			cumulative_compile_ms,
			prefix_max_operation_compile_ms,
			prefix_max_frame_gap_ms,
			measure_collision
		)
		result_rows.append(row)
	_cleanup_sequence_nodes(backend, backend_host, presenter)
	await process_frame
	return result_rows


func _capture_rolling_checkpoint(
	backend: Variant,
	bodies: Array[Resource],
	operation_count: int,
	repeat_index: int,
	operation_result: Dictionary,
	cumulative_compile_ms: float,
	prefix_max_operation_compile_ms: float,
	prefix_max_frame_gap_ms: float,
	measure_collision: bool
) -> Dictionary:
	var accepted_mesh: ArrayMesh = backend.call("get_accepted_mesh") as ArrayMesh
	var rolling_analysis: Dictionary = MeshAnalyzerScript.analyze_mesh(
		accepted_mesh
	)
	var legacy_analysis: Dictionary = legacy_reference_analyses.get(
		operation_count,
		{}
	) as Dictionary
	var parity := _compare_checkpoint_geometry(
		rolling_analysis,
		legacy_analysis,
		operation_count
	)
	var collision_bake_ms := 0.0
	var collision_face_count := 0
	if measure_collision:
		var collision_started := Time.get_ticks_usec()
		var collision_shape := accepted_mesh.create_trimesh_shape()
		if collision_shape != null:
			collision_face_count = int(collision_shape.get_faces().size() / 3.0)
		collision_bake_ms = _elapsed_milliseconds(collision_started)
	var bodies_at_checkpoint := _slice_body_sequence(
		bodies,
		operation_count + 1
	)
	var material_started := Time.get_ticks_usec()
	var resolver = ForgeV2MaterialVolumeResolverScript.new()
	var usage_summary: Dictionary = resolver.call(
		"build_usage_summary",
		bodies_at_checkpoint
	) as Dictionary
	var material_resolve_ms := _elapsed_milliseconds(material_started)
	var topology_pass := (
		bool(rolling_analysis.get("watertight", false))
		and int(rolling_analysis.get("component_count", 0)) == 1
		and int(rolling_analysis.get("boundary_edge_count", 0)) == 0
		and int(rolling_analysis.get("nonmanifold_edge_count", 0)) == 0
		and int(rolling_analysis.get("directed_edge_mismatch_count", 0)) == 0
		and int(rolling_analysis.get("degenerate_triangle_count", 0)) == 0
		and int(rolling_analysis.get("nonfinite_vertex_count", 0)) == 0
		and absf(float(rolling_analysis.get("genus", 0.0)))
		<= GENUS_TOLERANCE
	)
	var strict_topology_pass := (
		bool(rolling_analysis.get("strict_watertight", false))
		and int(rolling_analysis.get("strict_component_count", 0)) == 1
		and int(rolling_analysis.get("strict_boundary_edge_count", 0)) == 0
		and int(rolling_analysis.get(
			"strict_nonmanifold_edge_count",
			0
		)) == 0
		and int(rolling_analysis.get(
			"strict_directed_edge_mismatch_count",
			0
		)) == 0
		and int(rolling_analysis.get(
			"strict_degenerate_triangle_collapse_count",
			0
		)) == 0
	)
	var bounded_state_pass := (
		int(operation_result.get("compile_csg_operand_count", 99))
		<= absorption_window_size + 1
		and int(operation_result.get("steady_csg_operand_count", 99)) == 0
		and int(operation_result.get("steady_csg_shape_count", 99)) == 0
		and int(operation_result.get("accepted_display_mesh_count", 0)) == 1
		and int(operation_result.get("accepted_surface_count", 0)) == 1
		and int(backend.call("get_accepted_revision")) == operation_count
	)
	var parity_pass := bool(parity.get("parity_pass", false))
	var candidate_pass := (
		topology_pass
		and strict_topology_pass
		and bounded_state_pass
		and parity_pass
	)
	var row := {
		"benchmark_schema": BENCHMARK_SCHEMA_VERSION,
		"backend_id": _get_backend_run_id(),
		"fixture_schema": FixtureScript.FIXTURE_SCHEMA_VERSION,
		"fixture_id": String(FixtureScript.FIXTURE_ID),
		"fixture_signature": FixtureScript.build_fixture_signature(
			operation_count
		),
		"repeat": repeat_index + 1,
		"operation_count": operation_count,
		"seed_count": 1,
		"logical_body_count": operation_count + 1,
		"path_samples_per_body": FixtureScript.PATH_SAMPLE_COUNT,
		"accepted_revision": int(backend.call("get_accepted_revision")),
		"accepted_source_body_count": int(operation_result.get(
			"accepted_source_body_count",
			0
		)),
		"accepted_base_revision": int(operation_result.get(
			"accepted_base_revision",
			0
		)),
		"pending_body_count": int(operation_result.get(
			"pending_body_count",
			0
		)),
		"absorption_window_size": int(operation_result.get(
			"absorption_window_size",
			absorption_window_size
		)),
		"accepted_display_mesh_count": int(operation_result.get(
			"accepted_display_mesh_count",
			0
		)),
		"accepted_surface_count": int(operation_result.get(
			"accepted_surface_count",
			0
		)),
		"compile_scene_node_count": int(operation_result.get(
			"compile_scene_node_count",
			0
		)),
		"compile_csg_shape_count": int(operation_result.get(
			"compile_csg_shape_count",
			0
		)),
		"compile_csg_combiner_count": int(operation_result.get(
			"compile_csg_combiner_count",
			0
		)),
		"compile_csg_operand_count": int(operation_result.get(
			"compile_csg_operand_count",
			0
		)),
		"steady_csg_shape_count": int(operation_result.get(
			"steady_csg_shape_count",
			0
		)),
		"steady_csg_operand_count": int(operation_result.get(
			"steady_csg_operand_count",
			0
		)),
		"node_build_ms": float(operation_result.get("node_build_ms", 0.0)),
		"settle_wall_ms": float(operation_result.get("settle_wall_ms", 0.0)),
		"max_frame_gap_ms": float(operation_result.get("max_frame_gap_ms", 0.0)),
		"static_bake_ms": float(operation_result.get("static_bake_ms", 0.0)),
		"surface_consolidation_ms": float(operation_result.get(
			"surface_consolidation_ms",
			0.0
		)),
		"operation_compile_total_ms": float(operation_result.get(
			"operation_compile_total_ms",
			0.0
		)),
		"cumulative_compile_ms": cumulative_compile_ms,
		"prefix_max_operation_compile_ms": prefix_max_operation_compile_ms,
		"prefix_max_frame_gap_ms": prefix_max_frame_gap_ms,
		"collision_bake_ms": collision_bake_ms,
		"collision_face_count": collision_face_count,
		"material_resolve_ms": material_resolve_ms,
		"material_count": (
			(usage_summary.get("materials", {}) as Dictionary).size()
		),
		"rough_material_units": float(usage_summary.get(
			"total_rough_material_units",
			0.0
		)),
		"material_summary_signature": _build_material_summary_signature(
			usage_summary
		),
		"topology_pass": topology_pass,
		"strict_topology_pass": strict_topology_pass,
		"bounded_state_pass": bounded_state_pass,
		"candidate_pass": candidate_pass,
	}
	row.merge(MeshAnalyzerScript.strip_transient_arrays(
		rolling_analysis
	), true)
	row.merge(parity, true)
	return row


func _build_legacy_reference_analyses(
	bodies: Array[Resource],
	checkpoints: PackedInt32Array
) -> Dictionary:
	var result: Dictionary = {}
	var presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	presenter.name = "RollingLegacyOraclePresenter"
	root.add_child(presenter)
	await process_frame
	for checkpoint: int in checkpoints:
		var harness_root := Node3D.new()
		harness_root.name = "LegacyOracle_%03d" % checkpoint
		root.add_child(harness_root)
		var checkpoint_bodies := _slice_body_sequence(
			bodies,
			checkpoint + 1
		)
		var zones: Array = presenter.call(
			"_build_csg_body_zones",
			checkpoint_bodies
		) as Array
		if zones.size() != 1:
			benchmark_errors.append(
				"legacy oracle operation %d produced %d zones"
				% [checkpoint, zones.size()]
			)
			root.remove_child(harness_root)
			harness_root.free()
			continue
		var zone_node: CSGCombiner3D = presenter.call(
			"_build_csg_zone_node",
			zones[0] as Dictionary,
			false,
			"RollingLegacyOracle"
		) as CSGCombiner3D
		if zone_node == null:
			benchmark_errors.append(
				"legacy oracle operation %d node missing" % checkpoint
			)
			root.remove_child(harness_root)
			harness_root.free()
			continue
		harness_root.add_child(zone_node)
		for _frame_index in range(FRAME_SETTLE_COUNT):
			await process_frame
		var mesh := zone_node.bake_static_mesh()
		if mesh == null or mesh.get_surface_count() <= 0:
			benchmark_errors.append(
				"legacy oracle operation %d mesh missing" % checkpoint
			)
		else:
			result[checkpoint] = MeshAnalyzerScript.analyze_mesh(mesh)
		root.remove_child(harness_root)
		harness_root.free()
		await process_frame
	root.remove_child(presenter)
	presenter.free()
	await process_frame
	return result


func _compare_checkpoint_geometry(
	rolling_analysis: Dictionary,
	legacy_analysis: Dictionary,
	operation_count: int
) -> Dictionary:
	if rolling_analysis.is_empty() or legacy_analysis.is_empty():
		return {
			"parity_pass": false,
			"parity_error": "analysis_missing",
		}
	var aabb_max_delta := _calculate_aabb_max_delta(
		rolling_analysis,
		legacy_analysis
	)
	var rolling_volume := float(rolling_analysis.get(
		"absolute_volume_cubic_meters",
		0.0
	))
	var legacy_volume := float(legacy_analysis.get(
		"absolute_volume_cubic_meters",
		0.0
	))
	var volume_absolute_delta := absf(rolling_volume - legacy_volume)
	var volume_relative_delta := (
		volume_absolute_delta / legacy_volume
		if legacy_volume > 0.000000000001
		else INF
	)
	var cache_key := str(operation_count)
	var rolling_signature := String(rolling_analysis.get(
		"geometry_signature_oriented",
		""
	))
	var surface_comparison: Dictionary = {}
	var cached: Dictionary = parity_cache.get(cache_key, {}) as Dictionary
	if (
		not cached.is_empty()
		and String(cached.get("rolling_signature", "")) == rolling_signature
	):
		surface_comparison = cached.get(
			"surface_comparison",
			{}
		) as Dictionary
	else:
		surface_comparison = MeshAnalyzerScript.compare_surfaces(
			rolling_analysis,
			legacy_analysis
		)
		parity_cache[cache_key] = {
			"rolling_signature": rolling_signature,
			"surface_comparison": surface_comparison,
		}
	var surface_distance := float(surface_comparison.get(
		"bidirectional_max_meters",
		INF
	))
	var signed_direction_matches := (
		float(rolling_analysis.get("signed_volume_sign", 0.0))
		== float(legacy_analysis.get("signed_volume_sign", 0.0))
	)
	var topology_matches := (
		int(rolling_analysis.get("component_count", -1))
		== int(legacy_analysis.get("component_count", -2))
		and absf(
			float(rolling_analysis.get("genus", INF))
			- float(legacy_analysis.get("genus", -INF))
		) <= GENUS_TOLERANCE
	)
	var parity_pass := (
		aabb_max_delta <= AABB_TOLERANCE_METERS
		and volume_relative_delta <= VOLUME_RELATIVE_TOLERANCE
		and surface_distance <= SURFACE_DISTANCE_TOLERANCE_METERS
		and signed_direction_matches
		and topology_matches
	)
	return {
		"parity_pass": parity_pass,
		"aabb_max_delta_meters": aabb_max_delta,
		"aabb_tolerance_meters": AABB_TOLERANCE_METERS,
		"volume_absolute_delta_cubic_meters": volume_absolute_delta,
		"volume_relative_delta": volume_relative_delta,
		"volume_relative_tolerance": VOLUME_RELATIVE_TOLERANCE,
		"surface_bidirectional_max_meters": surface_distance,
		"surface_distance_tolerance_meters": (
			SURFACE_DISTANCE_TOLERANCE_METERS
		),
		"signed_volume_direction_matches": signed_direction_matches,
		"topology_matches": topology_matches,
		"exact_unoriented_signature_matches": (
			String(rolling_analysis.get(
				"geometry_signature_unoriented",
				""
			))
			== String(legacy_analysis.get(
				"geometry_signature_unoriented",
				""
			))
		),
		"exact_oriented_signature_matches": (
			rolling_signature
			== String(legacy_analysis.get(
				"geometry_signature_oriented",
				""
			))
		),
		"legacy_triangle_count": int(legacy_analysis.get(
			"triangle_count",
			0
		)),
		"legacy_surface_count": int(legacy_analysis.get(
			"surface_count",
			0
		)),
		"legacy_absolute_volume_cubic_meters": legacy_volume,
		"legacy_geometry_signature_oriented": String(legacy_analysis.get(
			"geometry_signature_oriented",
			""
		)),
	}


func _calculate_aabb_max_delta(
	first: Dictionary,
	second: Dictionary
) -> float:
	var maximum_delta := 0.0
	for field_name: String in [
		"aabb_position_x",
		"aabb_position_y",
		"aabb_position_z",
		"aabb_size_x",
		"aabb_size_y",
		"aabb_size_z",
	]:
		maximum_delta = maxf(
			maximum_delta,
			absf(float(first.get(field_name, 0.0)) - float(second.get(
				field_name,
				0.0
			)))
		)
	return maximum_delta


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
		var oriented_signatures: Dictionary = {}
		var material_signatures: Dictionary = {}
		var all_pass := true
		var strict_topology_pass := true
		var strict_watertight := true
		var strict_boundary_edge_count := 0
		var strict_nonmanifold_edge_count := 0
		var strict_directed_edge_mismatch_count := 0
		var strict_component_count := 0
		var strict_degenerate_triangle_collapse_count := 0
		for row: Dictionary in checkpoint_rows:
			oriented_signatures[String(row.get(
				"geometry_signature_oriented",
				""
			))] = true
			material_signatures[String(row.get(
				"material_summary_signature",
				""
			))] = true
			if not bool(row.get("candidate_pass", false)):
				all_pass = false
			strict_topology_pass = (
				strict_topology_pass
				and bool(row.get("strict_topology_pass", false))
			)
			strict_watertight = (
				strict_watertight
				and bool(row.get("strict_watertight", false))
			)
			strict_boundary_edge_count = maxi(
				strict_boundary_edge_count,
				int(row.get("strict_boundary_edge_count", 0))
			)
			strict_nonmanifold_edge_count = maxi(
				strict_nonmanifold_edge_count,
				int(row.get("strict_nonmanifold_edge_count", 0))
			)
			strict_directed_edge_mismatch_count = maxi(
				strict_directed_edge_mismatch_count,
				int(row.get("strict_directed_edge_mismatch_count", 0))
			)
			strict_component_count = maxi(
				strict_component_count,
				int(row.get("strict_component_count", 0))
			)
			strict_degenerate_triangle_collapse_count = maxi(
				strict_degenerate_triangle_collapse_count,
				int(row.get(
					"strict_degenerate_triangle_collapse_count",
					0
				))
			)
		var summary := {
			"operation_count": checkpoint,
			"sample_count": checkpoint_rows.size(),
			"operation_compile_ms_median": _row_statistic(
				checkpoint_rows,
				"operation_compile_total_ms",
				0.5
			),
			"operation_compile_ms_p95": _row_statistic(
				checkpoint_rows,
				"operation_compile_total_ms",
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
			"cumulative_compile_ms_median": _row_statistic(
				checkpoint_rows,
				"cumulative_compile_ms",
				0.5
			),
			"prefix_max_operation_compile_ms_median": _row_statistic(
				checkpoint_rows,
				"prefix_max_operation_compile_ms",
				0.5
			),
			"prefix_max_operation_compile_ms_p95": _row_statistic(
				checkpoint_rows,
				"prefix_max_operation_compile_ms",
				0.95
			),
			"prefix_max_frame_gap_ms_p95": _row_statistic(
				checkpoint_rows,
				"prefix_max_frame_gap_ms",
				0.95
			),
			"collision_bake_ms_p95": _row_statistic(
				checkpoint_rows,
				"collision_bake_ms",
				0.95
			),
			"triangle_count": int(checkpoint_rows[0].get(
				"triangle_count",
				0
			)),
			"legacy_triangle_count": int(checkpoint_rows[0].get(
				"legacy_triangle_count",
				0
			)),
			"accepted_surface_count": int(checkpoint_rows[0].get(
				"accepted_surface_count",
				0
			)),
			"peak_csg_operand_count": int(checkpoint_rows[0].get(
				"compile_csg_operand_count",
				0
			)),
			"steady_csg_operand_count": int(checkpoint_rows[0].get(
				"steady_csg_operand_count",
				0
			)),
			"aabb_max_delta_meters": float(checkpoint_rows[0].get(
				"aabb_max_delta_meters",
				INF
			)),
			"volume_relative_delta": float(checkpoint_rows[0].get(
				"volume_relative_delta",
				INF
			)),
			"surface_bidirectional_max_meters": float(
				checkpoint_rows[0].get(
					"surface_bidirectional_max_meters",
					INF
				)
			),
			"strict_topology_weld_tolerance_meters": float(
				checkpoint_rows[0].get(
					"strict_topology_weld_tolerance_meters",
					MeshAnalyzerScript.STRICT_POSITION_WELD_METERS
				)
			),
			"strict_watertight": strict_watertight,
			"strict_boundary_edge_count": strict_boundary_edge_count,
			"strict_nonmanifold_edge_count": (
				strict_nonmanifold_edge_count
			),
			"strict_directed_edge_mismatch_count": (
				strict_directed_edge_mismatch_count
			),
			"strict_component_count": strict_component_count,
			"strict_degenerate_triangle_collapse_count": (
				strict_degenerate_triangle_collapse_count
			),
			"strict_topology_pass": strict_topology_pass,
			"rolling_geometry_signature_count": oriented_signatures.size(),
			"material_summary_signature_count": material_signatures.size(),
			"deterministic": (
				oriented_signatures.size() == 1
				and material_signatures.size() == 1
			),
			"candidate_pass": all_pass,
		}
		summaries.append(summary)
	return summaries


func _finish_benchmark(
	ok: bool,
	fixture_result: Dictionary,
	rows: Array[Dictionary],
	summaries: Array[Dictionary],
	max_operation_count: int,
	repeat_count: int,
	measure_collision: bool
) -> void:
	var metadata := {
		"benchmark_schema": BENCHMARK_SCHEMA_VERSION,
		"backend_id": _get_backend_run_id(),
		"backend_schema": RollingBackendScript.BACKEND_SCHEMA_VERSION,
		"absorption_window_size": absorption_window_size,
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
		"fixture_path": FixtureScript.FIXTURE_WIP_PATH,
		"max_operation_count": max_operation_count,
		"repeat_count": repeat_count,
		"frame_settle_count": FRAME_SETTLE_COUNT,
		"collision_lane_enabled": measure_collision,
		"aabb_tolerance_meters": AABB_TOLERANCE_METERS,
		"volume_relative_tolerance": VOLUME_RELATIVE_TOLERANCE,
		"surface_distance_tolerance_meters": (
			SURFACE_DISTANCE_TOLERANCE_METERS
		),
		"topology_weld_tolerance_meters": (
			MeshAnalyzerScript.POSITION_WELD_METERS
		),
		"strict_topology_weld_tolerance_meters": (
			MeshAnalyzerScript.STRICT_POSITION_WELD_METERS
		),
		"supported_semantics": (
			"single_material_connected_add_explicit_profile_path_only"
		),
		"benchmark_only_surface_normalization": true,
		"protected_live_wips": ["Test Glave", "Test sword for animations"],
		"live_player_library_accessed": false,
		"result_base_path": RESULT_BASE_PATH,
	}
	var payload := {
		"ok": ok,
		"candidate_pass": ok,
		"metadata": metadata,
		"fixture": fixture_result,
		"errors": benchmark_errors,
		"rows": rows,
		"summaries": summaries,
		"legacy_reference_summaries": _build_serializable_legacy_references(),
	}
	_write_json_result(payload)
	_write_csv_result(rows)
	_write_text_result(payload)
	if ok:
		print("Forge V2 rolling benchmark PASS: %s" % RESULT_TEXT_PATH)
	else:
		push_error(
			"Forge V2 rolling benchmark did not pass all gates: %s"
			% "; ".join(benchmark_errors)
		)
	quit(0 if ok else 1)


func _build_serializable_legacy_references() -> Dictionary:
	var result: Dictionary = {}
	for checkpoint_variant: Variant in legacy_reference_analyses.keys():
		var checkpoint := int(checkpoint_variant)
		result[str(checkpoint)] = MeshAnalyzerScript.strip_transient_arrays(
			legacy_reference_analyses[checkpoint] as Dictionary
		)
	return result


func _write_json_result(payload: Dictionary) -> void:
	var file := FileAccess.open(RESULT_JSON_PATH, FileAccess.WRITE)
	if file == null:
		benchmark_errors.append("rolling_json_result_open_failed")
		return
	file.store_string(JSON.stringify(payload, "\t", false) + "\n")
	file.close()


func _write_csv_result(rows: Array[Dictionary]) -> void:
	var headers: Array[String] = [
		"backend_id", "repeat", "operation_count", "logical_body_count",
		"absorption_window_size", "accepted_base_revision",
		"pending_body_count",
		"accepted_revision", "accepted_source_body_count",
		"accepted_display_mesh_count", "accepted_surface_count",
		"compile_scene_node_count", "compile_csg_shape_count",
		"compile_csg_combiner_count", "compile_csg_operand_count",
		"steady_csg_shape_count", "steady_csg_operand_count",
		"node_build_ms", "settle_wall_ms", "max_frame_gap_ms",
		"static_bake_ms", "surface_consolidation_ms",
		"operation_compile_total_ms", "cumulative_compile_ms",
		"prefix_max_operation_compile_ms", "prefix_max_frame_gap_ms",
		"collision_bake_ms", "collision_face_count", "material_resolve_ms",
		"surface_count", "emitted_vertex_count", "welded_vertex_count",
		"triangle_count", "legacy_triangle_count",
		"degenerate_triangle_count", "nonfinite_vertex_count",
		"boundary_edge_count", "nonmanifold_edge_count",
		"directed_edge_mismatch_count", "component_count",
		"euler_characteristic", "genus", "watertight",
		"strict_topology_weld_tolerance_meters",
		"strict_welded_vertex_count", "strict_triangle_count",
		"strict_degenerate_triangle_collapse_count",
		"strict_boundary_edge_count", "strict_nonmanifold_edge_count",
		"strict_directed_edge_mismatch_count", "strict_component_count",
		"strict_euler_characteristic", "strict_genus",
		"strict_watertight", "strict_topology_pass",
		"absolute_volume_cubic_meters", "legacy_absolute_volume_cubic_meters",
		"aabb_max_delta_meters", "volume_relative_delta",
		"surface_bidirectional_max_meters", "material_count",
		"rough_material_units", "material_summary_signature",
		"geometry_signature_unoriented", "geometry_signature_oriented",
		"exact_unoriented_signature_matches",
		"exact_oriented_signature_matches", "topology_pass",
		"bounded_state_pass", "parity_pass", "candidate_pass",
	]
	var lines := PackedStringArray([",".join(headers)])
	for row: Dictionary in rows:
		var values := PackedStringArray()
		for header: String in headers:
			values.append(_escape_csv_value(row.get(header, "")))
		lines.append(",".join(values))
	var file := FileAccess.open(RESULT_CSV_PATH, FileAccess.WRITE)
	if file == null:
		benchmark_errors.append("rolling_csv_result_open_failed")
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()


func _write_text_result(payload: Dictionary) -> void:
	var metadata: Dictionary = payload.get("metadata", {}) as Dictionary
	var fixture: Dictionary = payload.get("fixture", {}) as Dictionary
	var lines := PackedStringArray([
		"Forge V2 Rolling Built-in CSG Workpiece Benchmark",
		"ok=%s" % str(bool(payload.get("ok", false))).to_lower(),
		"candidate_pass=%s" % str(
			bool(payload.get("candidate_pass", false))
		).to_lower(),
		"backend_id=%s" % String(metadata.get("backend_id", "")),
		"absorption_window_size=%d" % int(metadata.get(
			"absorption_window_size",
			0
		)),
		"supported_semantics=%s" % String(metadata.get(
			"supported_semantics",
			""
		)),
		"benchmark_only_surface_normalization=true",
		"machine_label=%s" % String(metadata.get("machine_label", "")),
		"run_notes=%s" % String(metadata.get("run_notes", "")),
		"fixture_signature=%s" % String(fixture.get("signature", "")),
		"max_operation_count=%d" % int(metadata.get("max_operation_count", 0)),
		"repeat_count=%d" % int(metadata.get("repeat_count", 0)),
		"authoring_topology_weld_m=%.9f" % float(metadata.get(
			"topology_weld_tolerance_meters",
			0.0
		)),
		"strict_topology_weld_m=%.9f" % float(metadata.get(
			"strict_topology_weld_tolerance_meters",
			0.0
		)),
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
				"ops=%d peak_operands=%d steady_operands=%d surfaces=%d "
				+ "triangles=%d legacy_triangles=%d operation_p95_ms=%.3f "
				+ "frame_p95_ms=%.3f prefix_frame_p95_ms=%.3f "
				+ "cumulative_median_ms=%.3f "
				+ "aabb_delta_m=%.9f volume_rel_delta=%.9f "
				+ "surface_delta_m=%.9f strict_watertight=%s "
				+ "strict_boundary=%d strict_nonmanifold=%d "
				+ "strict_directed_mismatch=%d strict_components=%d "
				+ "strict_degenerate_collapse=%d strict_pass=%s "
				+ "deterministic=%s pass=%s"
			) % [
				int(summary.get("operation_count", 0)),
				int(summary.get("peak_csg_operand_count", 0)),
				int(summary.get("steady_csg_operand_count", 0)),
				int(summary.get("accepted_surface_count", 0)),
				int(summary.get("triangle_count", 0)),
				int(summary.get("legacy_triangle_count", 0)),
				float(summary.get("operation_compile_ms_p95", 0.0)),
				float(summary.get("max_frame_gap_ms_p95", 0.0)),
				float(summary.get("prefix_max_frame_gap_ms_p95", 0.0)),
				float(summary.get("cumulative_compile_ms_median", 0.0)),
				float(summary.get("aabb_max_delta_meters", 0.0)),
				float(summary.get("volume_relative_delta", 0.0)),
				float(summary.get("surface_bidirectional_max_meters", 0.0)),
				str(bool(summary.get("strict_watertight", false))).to_lower(),
				int(summary.get("strict_boundary_edge_count", 0)),
				int(summary.get("strict_nonmanifold_edge_count", 0)),
				int(summary.get(
					"strict_directed_edge_mismatch_count",
					0
				)),
				int(summary.get("strict_component_count", 0)),
				int(summary.get(
					"strict_degenerate_triangle_collapse_count",
					0
				)),
				str(bool(summary.get(
					"strict_topology_pass",
					false
				))).to_lower(),
				str(bool(summary.get("deterministic", false))).to_lower(),
				str(bool(summary.get("candidate_pass", false))).to_lower(),
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
		benchmark_errors.append("rolling_text_result_open_failed")
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()


func _cleanup_sequence_nodes(
	backend: Variant,
	backend_host: Node3D,
	presenter: Node3D
) -> void:
	if backend != null:
		backend.call("dispose")
	if backend_host != null and is_instance_valid(backend_host):
		if backend_host.get_parent() != null:
			backend_host.get_parent().remove_child(backend_host)
		backend_host.free()
	if presenter != null and is_instance_valid(presenter):
		if presenter.get_parent() != null:
			presenter.get_parent().remove_child(presenter)
		presenter.free()


func _slice_body_sequence(
	bodies: Array[Resource],
	requested_size: int
) -> Array[Resource]:
	var result: Array[Resource] = []
	var safe_size := mini(maxi(requested_size, 0), bodies.size())
	for body_index in range(safe_size):
		result.append(bodies[body_index])
	return result


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


func _get_backend_run_id() -> String:
	return "%s_window_%d" % [
		String(RollingBackendScript.BACKEND_ID),
		absorption_window_size,
	]


func _elapsed_milliseconds(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	benchmark_errors.append(message)
