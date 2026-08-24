extends SceneTree

const StressFixtureScript = preload(
	"res://tools/forge_v2_workpiece_stress_fixture.gd"
)
const MeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)
const ChunkedBackendScript = preload(
	"res://tools/forge_v2_chunked_labelled_solid_backend.gd"
)

const BENCHMARK_SCHEMA_VERSION := 2
const RESULT_PREFIX := (
	"C:/WORKSPACE/godot_runs/forge_v2_workpiece_chunked_contact_locality"
)
const DEFAULT_OPERATION_COUNT := 10001
const CELL_SIZE_METERS := 0.004
const CHUNK_CELL_COUNT := 16
const PROCESSING_HALO_CHUNK_RINGS := 2
const TIMING_BIN_SIZE := 100
const PROJECTED_WALL_WARNING_SECONDS := 2.0 * 60.0 * 60.0
const VOLUME_ABSOLUTE_TOLERANCE_CUBIC_METERS := 0.000000000001
const BACKEND_SOURCE_PATH := (
	"res://tools/forge_v2_chunked_labelled_solid_backend.gd"
)
const PROTOTYPE_SCOPE := (
	"4mm labelled voxel/block geometry is a locality-and-scaling proof only; "
	+ "it is not organic-fidelity geometry, an SDF implementation, or the "
	+ "final Forge V2 workpiece backend"
)
const OCCUPANCY_MESH_SEMANTICS := (
	"the combined mesh is the boundary of the occupied voxel union; its "
	+ "volume is expected to equal occupied_cell_count * cell_size^3 within "
	+ "packed-float mesh-coordinate and analysis tolerance"
)
const PACKED_FLOAT_VOLUME_RELATIVE_TOLERANCE := 0.000005
const LATTICE_SNAP_TOLERANCE_METERS := CELL_SIZE_METERS * 0.000025

var errors: Array[String] = []
var warnings: Array[String] = []
var checkpoint_rows: Array[Dictionary] = []
var timing_bins: Array[Dictionary] = []
var raw_operation_rows: Array[Dictionary] = []
var operation_count := DEFAULT_OPERATION_COUNT
var completed_operation_count := 0
var run_id := ""
var run_result_base_path := ""
var run_started_usec := 0
var preflight_result: Dictionary = {}
var stream_digest := ""
var initial_static_memory_bytes := 0
var peak_static_memory_bytes := 0
var previous_checkpoint_volume := -1.0
var final_backend_summary: Dictionary = {}
var backend_source_audit: Dictionary = {}
var projected_wall_warning: Dictionary = {}

var bin_operation_start := 1
var bin_total_times_ms: Array[float] = []
var bin_raster_times_ms: Array[float] = []
var bin_update_times_ms: Array[float] = []
var bin_remesh_times_ms: Array[float] = []
var bin_apply_wall_times_ms: Array[float] = []
var bin_candidate_cells: Array[float] = []
var bin_changed_cells: Array[float] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PREFIX.get_base_dir())
	operation_count = _read_environment_int(
		"FORGE_V2_CHUNKED_FIELD_MAX_OPERATIONS",
		DEFAULT_OPERATION_COUNT,
		1,
		StressFixtureScript.MAX_OPERATION_COUNT
	)
	run_id = "%s_%d_pid%d_%dops" % [
		Time.get_datetime_string_from_system().replace(":", "").replace("-", ""),
		Time.get_ticks_usec(),
		OS.get_process_id(),
		operation_count,
	]
	run_result_base_path = RESULT_PREFIX + "_" + run_id
	print(
		"Forge V2 chunked-field proof: operations=%d cell=%.3fmm chunk=%d"
		% [operation_count, CELL_SIZE_METERS * 1000.0, CHUNK_CELL_COUNT]
	)

	backend_source_audit = _audit_backend_source()
	if not bool(backend_source_audit.get("pass", false)):
		errors.append("backend_contains_builtin_csg_dependency_or_class_reference")

	var preflight_started := Time.get_ticks_usec()
	preflight_result = StressFixtureScript.preflight(operation_count)
	var preflight_ms := _elapsed_milliseconds(preflight_started)
	if not bool(preflight_result.get("ok", false)):
		errors.append("stress_fixture_preflight_failed")
		for error_variant: Variant in preflight_result.get("errors", []):
			_append_error(String(error_variant))
		_finish(false, preflight_ms)
		return

	var backend = ChunkedBackendScript.new()
	var initialize_result: Dictionary = backend.initialize(
		CELL_SIZE_METERS,
		CHUNK_CELL_COUNT,
		PROCESSING_HALO_CHUNK_RINGS
	)
	if not bool(initialize_result.get("ok", false)):
		_append_error(String(initialize_result.get(
			"error",
			"chunked_field_initialization_failed"
		)))
		_dispose_backend(backend)
		_finish(false, preflight_ms)
		return

	var seed_body: Resource = StressFixtureScript.build_seed_body()
	var seed_result: Dictionary = backend.initialize_seed(seed_body)
	stream_digest = (
		"schema=%d|fixture=%s"
		% [
			StressFixtureScript.FIXTURE_SCHEMA_VERSION,
			String(StressFixtureScript.FIXTURE_ID),
		]
	).sha256_text()
	stream_digest = StressFixtureScript.extend_digest(stream_digest, seed_body)
	seed_body = null
	if not bool(seed_result.get("ok", false)):
		_append_error(String(seed_result.get(
			"error",
			"chunked_field_seed_failed"
		)))
		_dispose_backend(backend)
		_finish(false, preflight_ms)
		return
	var seed_summary: Dictionary = backend.get_summary()
	var seed_invariant := _validate_summary_invariants(seed_summary, 0)
	if not seed_invariant.is_empty():
		_append_error(seed_invariant)
		_dispose_backend(backend)
		_finish(false, preflight_ms)
		return
	if _count_csg_nodes(root) != 0:
		_append_error("seed_retained_builtin_csg_node")
		_dispose_backend(backend)
		_finish(false, preflight_ms)
		return

	initial_static_memory_bytes = OS.get_static_memory_usage()
	peak_static_memory_bytes = initial_static_memory_bytes
	run_started_usec = Time.get_ticks_usec()
	var checkpoint_lookup: Dictionary = {}
	for checkpoint: int in StressFixtureScript.build_checkpoint_list(
		operation_count
	):
		checkpoint_lookup[checkpoint] = true

	for operation_index in range(operation_count):
		var revision := operation_index + 1
		var body: Resource = StressFixtureScript.build_operation_body(
			operation_index
		)
		if body == null:
			_append_error("operation_%d_body_missing" % revision)
			break
		stream_digest = StressFixtureScript.extend_digest(stream_digest, body)
		var apply_started := Time.get_ticks_usec()
		var operation_result: Dictionary = backend.apply_add_body(body)
		var apply_wall_ms := _elapsed_milliseconds(apply_started)
		body = null
		if not bool(operation_result.get("ok", false)):
			_append_error(
				"operation_%d_backend_error_%s"
				% [revision, String(operation_result.get("error", "unknown"))]
			)
			break
		var summary: Dictionary = backend.get_summary()
		var invariant_error := _validate_summary_invariants(summary, revision)
		if not invariant_error.is_empty():
			_append_error(invariant_error)
			break
		if _count_csg_nodes(root) != 0:
			_append_error("operation_%d_retained_builtin_csg_node" % revision)
			break

		var phase_timings := _extract_operation_timings(
			operation_result,
			apply_wall_ms
		)
		if not bool(phase_timings.get("valid", false)):
			_append_error("operation_%d_invalid_timing_payload" % revision)
			break
		var candidate_cells := _extract_count(
			operation_result,
			summary,
			["candidate_cell_count", "last_candidate_cell_count"]
		)
		var changed_cells := _extract_count(
			operation_result,
			summary,
			["changed_cell_count", "last_changed_cell_count"]
		)
		if candidate_cells < 0 or changed_cells < 0:
			_append_error("operation_%d_missing_cell_work_counts" % revision)
			break
		if changed_cells > candidate_cells:
			_append_error("operation_%d_changed_cells_exceed_candidates" % revision)
			break
		var examined_cells := int(operation_result.get(
			"examined_cell_count",
			-1
		))
		var world_aabb_cells := int(operation_result.get(
			"world_aabb_cell_count",
			-1
		))
		if (
			examined_cells < candidate_cells
			or world_aabb_cells < examined_cells
		):
			_append_error("operation_%d_invalid_local_raster_counts" % revision)
			break
		var candidate_components := int(operation_result.get(
			"candidate_component_count",
			-1
		))
		var attached_components := int(operation_result.get(
			"attached_component_count",
			-2
		))
		var remeshed_chunks := int(operation_result.get(
			"remeshed_chunk_count",
			-1
		))
		var component_counts_valid := (
			candidate_components == 0
			and attached_components == 0
			and remeshed_chunks == 0
			if changed_cells == 0
			else (
				candidate_components > 0
				and candidate_components == attached_components
			)
		)
		if (
			not component_counts_valid
			or int(operation_result.get("contact_chunk_count", 0)) <= 0
			or int(operation_result.get(
				"processing_context_chunk_count",
				0
			)) <= 0
		):
			_append_error("operation_%d_invalid_contact_locality" % revision)
			break
		_append_timing_sample(
			phase_timings,
			apply_wall_ms,
			candidate_cells,
			changed_cells
		)
		_append_raw_operation_row(
			revision,
			phase_timings,
			apply_wall_ms,
			operation_result,
			summary
		)
		completed_operation_count = revision
		_sample_static_memory()

		if bin_total_times_ms.size() == TIMING_BIN_SIZE:
			_flush_timing_bin(revision)
			_update_projection_warning(revision)

		if checkpoint_lookup.has(revision):
			var checkpoint_row := _capture_checkpoint(
				backend,
				summary,
				operation_result,
				revision
			)
			checkpoint_rows.append(checkpoint_row)
			if bool(checkpoint_row.get("geometry_pass", false)):
				previous_checkpoint_volume = float(checkpoint_row.get(
					"exact_lattice_volume_cubic_meters",
					previous_checkpoint_volume
				))
			else:
				_append_error(
					"operation_%d_checkpoint_geometry_failed" % revision
				)
			if not _persist_checkpoint(revision, summary):
				_append_error(
					"operation_%d_checkpoint_persistence_failed" % revision
				)
			if not errors.is_empty():
				break

	if not bin_total_times_ms.is_empty():
		_flush_timing_bin(completed_operation_count)
		_update_projection_warning(completed_operation_count)
	final_backend_summary = backend.get_summary().duplicate(true)
	var expected_digest := String(preflight_result.get("stream_digest", ""))
	if completed_operation_count == operation_count and stream_digest != expected_digest:
		_append_error("executed_stream_digest_mismatch")
	var passed := (
		errors.is_empty()
		and completed_operation_count == operation_count
		and stream_digest == expected_digest
	)
	_dispose_backend(backend)
	_finish(passed, preflight_ms)


func _validate_summary_invariants(summary: Dictionary, revision: int) -> String:
	if _summary_int(summary, ["revision", "accepted_revision"], -1) != revision:
		return "operation_%d_revision_mismatch" % revision
	if _summary_int(
		summary,
		["source_count", "source_body_count", "accepted_source_body_count"],
		-1
	) != revision + 1:
		return "operation_%d_source_count_mismatch" % revision
	if _summary_int(
		summary,
		["occupied_cell_count", "occupied_cells", "cell_count"],
		-1
	) <= 0:
		return "operation_%d_has_no_occupied_cells" % revision
	if _summary_int(
		summary,
		["active_chunk_count", "chunk_count", "chunks"],
		-1
	) <= 0:
		return "operation_%d_has_no_active_chunks" % revision
	if _summary_bool(summary, ["uses_csg", "uses_builtin_csg"], false):
		return "operation_%d_summary_reports_csg_dependency" % revision
	if _summary_int(
		summary,
		[
			"live_csg_node_count",
			"csg_node_count",
			"retained_csg_node_count",
		],
		0
	) != 0:
		return "operation_%d_summary_reports_csg_nodes" % revision
	return ""


func _extract_operation_timings(
	result: Dictionary,
	apply_wall_ms: float
) -> Dictionary:
	var total_ms := _first_float(
		result,
		["total_ms", "operation_total_ms", "apply_total_ms"],
		apply_wall_ms
	)
	var raster_ms := _first_float(
		result,
		["raster_ms", "rasterize_ms", "rasterization_ms"],
		-1.0
	)
	var update_ms := _first_float(
		result,
		["update_ms", "occupancy_update_ms", "field_update_ms"],
		-1.0
	)
	var remesh_ms := _first_float(
		result,
		["remesh_ms", "mesh_update_ms", "chunk_remesh_ms"],
		-1.0
	)
	var validation_ms := _first_float(result, ["validation_ms"], -1.0)
	var attachment_ms := _first_float(result, ["attachment_ms"], -1.0)
	var context_build_ms := _first_float(result, ["context_build_ms"], -1.0)
	var backend_entry_to_exit_ms := _first_float(
		result,
		["backend_entry_to_exit_ms"],
		total_ms
	)
	var valid := (
		total_ms >= 0.0
		and raster_ms >= 0.0
		and update_ms >= 0.0
		and remesh_ms >= 0.0
		and is_finite(total_ms)
		and is_finite(raster_ms)
		and is_finite(update_ms)
		and is_finite(remesh_ms)
		and validation_ms >= 0.0
		and attachment_ms >= 0.0
		and context_build_ms >= 0.0
		and backend_entry_to_exit_ms >= 0.0
		and is_finite(validation_ms)
		and is_finite(attachment_ms)
		and is_finite(context_build_ms)
		and is_finite(backend_entry_to_exit_ms)
		and is_finite(apply_wall_ms)
	)
	return {
		"valid": valid,
		"total_ms": total_ms,
		"raster_ms": raster_ms,
		"update_ms": update_ms,
		"remesh_ms": remesh_ms,
		"validation_ms": validation_ms,
		"attachment_ms": attachment_ms,
		"context_build_ms": context_build_ms,
		"backend_entry_to_exit_ms": backend_entry_to_exit_ms,
	}


func _append_timing_sample(
	timings: Dictionary,
	apply_wall_ms: float,
	candidate_cells: int,
	changed_cells: int
) -> void:
	bin_total_times_ms.append(float(timings.get("total_ms", 0.0)))
	bin_raster_times_ms.append(float(timings.get("raster_ms", 0.0)))
	bin_update_times_ms.append(float(timings.get("update_ms", 0.0)))
	bin_remesh_times_ms.append(float(timings.get("remesh_ms", 0.0)))
	bin_apply_wall_times_ms.append(apply_wall_ms)
	bin_candidate_cells.append(float(candidate_cells))
	bin_changed_cells.append(float(changed_cells))


func _append_raw_operation_row(
	revision: int,
	timings: Dictionary,
	apply_wall_ms: float,
	result: Dictionary,
	summary: Dictionary
) -> void:
	raw_operation_rows.append({
		"revision": revision,
		"total_ms": float(timings.get("total_ms", 0.0)),
		"backend_entry_to_exit_ms": float(timings.get(
			"backend_entry_to_exit_ms",
			0.0
		)),
		"apply_wall_ms": apply_wall_ms,
		"validation_ms": float(timings.get("validation_ms", 0.0)),
		"raster_ms": float(timings.get("raster_ms", 0.0)),
		"attachment_ms": float(timings.get("attachment_ms", 0.0)),
		"context_build_ms": float(timings.get("context_build_ms", 0.0)),
		"update_ms": float(timings.get("update_ms", 0.0)),
		"remesh_ms": float(timings.get("remesh_ms", 0.0)),
		"world_aabb_cell_count": int(result.get(
			"world_aabb_cell_count",
			-1
		)),
		"examined_cell_count": int(result.get("examined_cell_count", -1)),
		"centerline_chunk_count": int(result.get(
			"centerline_chunk_count",
			-1
		)),
		"broadphase_chunk_count": int(result.get(
			"broadphase_chunk_count",
			-1
		)),
		"intersecting_chunk_count": int(result.get(
			"intersecting_chunk_count",
			-1
		)),
		"candidate_cell_count": int(result.get("candidate_cell_count", -1)),
		"candidate_chunk_count": int(result.get("candidate_chunk_count", -1)),
		"candidate_component_count": int(result.get(
			"candidate_component_count",
			-1
		)),
		"attached_component_count": int(result.get(
			"attached_component_count",
			-1
		)),
		"contact_cell_count": int(result.get("contact_cell_count", -1)),
		"contact_chunk_count": int(result.get("contact_chunk_count", -1)),
		"new_only_chunk_count": int(result.get("new_only_chunk_count", -1)),
		"processing_context_chunk_count": int(result.get(
			"processing_context_chunk_count",
			-1
		)),
		"resident_context_chunk_count": int(result.get(
			"resident_context_chunk_count",
			-1
		)),
		"changed_cell_count": int(result.get("changed_cell_count", -1)),
		"changed_chunk_count": int(result.get("changed_chunk_count", -1)),
		"remeshed_chunk_count": int(result.get("remeshed_chunk_count", -1)),
		"remesh_scanned_cell_count": int(result.get(
			"remesh_scanned_cell_count",
			-1
		)),
		"remeshed_occupied_cell_count": int(result.get(
			"remeshed_occupied_cell_count",
			-1
		)),
		"remeshed_occupied_cell_min": int(result.get(
			"remeshed_occupied_cell_min",
			-1
		)),
		"remeshed_occupied_cell_max": int(result.get(
			"remeshed_occupied_cell_max",
			-1
		)),
		"rebuilt_quad_count": int(result.get("rebuilt_quad_count", -1)),
		"rebuilt_vertex_count": int(result.get("rebuilt_vertex_count", -1)),
		"rebuilt_index_count": int(result.get("rebuilt_index_count", -1)),
		"resident_chunk_count": int(summary.get("chunk_count", -1)),
		"occupied_cell_count": int(summary.get("occupied_cell_count", -1)),
		"resident_triangle_count": int(summary.get("total_triangle_count", -1)),
		"live_csg_node_count": int(summary.get("live_csg_node_count", -1)),
	})


func _flush_timing_bin(operation_end: int) -> void:
	if bin_total_times_ms.is_empty():
		return
	var row := {
		"operation_start": bin_operation_start,
		"operation_end": operation_end,
		"sample_count": bin_total_times_ms.size(),
		"total_p50_ms": _percentile(bin_total_times_ms, 0.50),
		"total_p95_ms": _percentile(bin_total_times_ms, 0.95),
		"total_p99_ms": _percentile(bin_total_times_ms, 0.99),
		"total_max_ms": _maximum(bin_total_times_ms),
		"raster_p50_ms": _percentile(bin_raster_times_ms, 0.50),
		"raster_p95_ms": _percentile(bin_raster_times_ms, 0.95),
		"raster_max_ms": _maximum(bin_raster_times_ms),
		"update_p50_ms": _percentile(bin_update_times_ms, 0.50),
		"update_p95_ms": _percentile(bin_update_times_ms, 0.95),
		"update_max_ms": _maximum(bin_update_times_ms),
		"remesh_p50_ms": _percentile(bin_remesh_times_ms, 0.50),
		"remesh_p95_ms": _percentile(bin_remesh_times_ms, 0.95),
		"remesh_max_ms": _maximum(bin_remesh_times_ms),
		"apply_wall_p50_ms": _percentile(bin_apply_wall_times_ms, 0.50),
		"apply_wall_p95_ms": _percentile(bin_apply_wall_times_ms, 0.95),
		"apply_wall_max_ms": _maximum(bin_apply_wall_times_ms),
		"candidate_cells_p50": _percentile(bin_candidate_cells, 0.50),
		"candidate_cells_p95": _percentile(bin_candidate_cells, 0.95),
		"candidate_cells_max": int(_maximum(bin_candidate_cells)),
		"changed_cells_p50": _percentile(bin_changed_cells, 0.50),
		"changed_cells_p95": _percentile(bin_changed_cells, 0.95),
		"changed_cells_max": int(_maximum(bin_changed_cells)),
		"sampled_static_memory_bytes": OS.get_static_memory_usage(),
		"sampled_static_memory_peak_bytes": peak_static_memory_bytes,
	}
	timing_bins.append(row)
	print(
		"FIELD %d/%d total_p95=%.3fms raster=%.3fms update=%.3fms remesh=%.3fms memory=%.1fMiB"
		% [
			operation_end,
			operation_count,
			float(row["total_p95_ms"]),
			float(row["raster_p95_ms"]),
			float(row["update_p95_ms"]),
			float(row["remesh_p95_ms"]),
			float(row["sampled_static_memory_bytes"]) / 1048576.0,
		]
	)
	bin_operation_start = operation_end + 1
	bin_total_times_ms.clear()
	bin_raster_times_ms.clear()
	bin_update_times_ms.clear()
	bin_remesh_times_ms.clear()
	bin_apply_wall_times_ms.clear()
	bin_candidate_cells.clear()
	bin_changed_cells.clear()


func _capture_checkpoint(
	backend: RefCounted,
	summary: Dictionary,
	operation_result: Dictionary,
	revision: int
) -> Dictionary:
	var mesh: ArrayMesh = backend.get_combined_mesh()
	var analyze_started := Time.get_ticks_usec()
	var analysis: Dictionary = MeshAnalyzerScript.analyze_mesh(mesh)
	var analyze_ms := _elapsed_milliseconds(analyze_started)
	var strict_pass := (
		bool(analysis.get("strict_watertight", false))
		and int(analysis.get("strict_component_count", 0)) == 1
		and int(analysis.get("strict_boundary_edge_count", -1)) == 0
		and int(analysis.get("strict_nonmanifold_edge_count", -1)) == 0
		and int(analysis.get("strict_directed_edge_mismatch_count", -1)) == 0
		and int(analysis.get(
			"strict_degenerate_triangle_collapse_count",
			-1
		)) == 0
	)
	var authoring_pass := (
		bool(analysis.get("watertight", false))
		and int(analysis.get("component_count", 0)) == 1
		and int(analysis.get("boundary_edge_count", -1)) == 0
		and int(analysis.get("nonmanifold_edge_count", -1)) == 0
		and int(analysis.get("directed_edge_mismatch_count", -1)) == 0
		and int(analysis.get("degenerate_triangle_count", -1)) == 0
		and int(analysis.get("nonfinite_vertex_count", -1)) == 0
	)
	var analyzer_volume := float(analysis.get(
		"absolute_volume_cubic_meters",
		NAN
	))
	var local_origin_volume := _calculate_local_origin_mesh_volume(mesh)
	var volume_finite := (
		is_finite(analyzer_volume)
		and analyzer_volume > 0.0
		and is_finite(local_origin_volume)
		and local_origin_volume > 0.0
	)
	var occupied_cells := _summary_int(
		summary,
		["occupied_cell_count", "occupied_cells", "cell_count"],
		-1
	)
	var expected_occupied_volume := (
		float(occupied_cells)
		* float(CELL_SIZE_METERS * CELL_SIZE_METERS * CELL_SIZE_METERS)
	)
	var lattice_oracle := _analyze_integer_lattice_volume(
		mesh,
		occupied_cells
	)
	var exact_lattice_volume_cubic_meters := (
		float(lattice_oracle.get("exact_lattice_volume_cells", 0.0))
		* float(CELL_SIZE_METERS * CELL_SIZE_METERS * CELL_SIZE_METERS)
	)
	var volume_monotonic := (
		previous_checkpoint_volume < 0.0
		or exact_lattice_volume_cubic_meters
		+ VOLUME_ABSOLUTE_TOLERANCE_CUBIC_METERS
		>= previous_checkpoint_volume
	)
	var occupancy_volume_error := absf(
		local_origin_volume - expected_occupied_volume
	)
	var occupancy_volume_tolerance := maxf(
		VOLUME_ABSOLUTE_TOLERANCE_CUBIC_METERS,
		expected_occupied_volume * PACKED_FLOAT_VOLUME_RELATIVE_TOLERANCE
	)
	var packed_float_volume_diagnostic_pass := (
		occupied_cells > 0
		and volume_finite
		and occupancy_volume_error <= occupancy_volume_tolerance
	)
	var occupancy_volume_pass := bool(lattice_oracle.get("pass", false))
	var summary_revision_pass := (
		_validate_summary_invariants(summary, revision).is_empty()
	)
	var no_csg_pass := (
		bool(backend_source_audit.get("pass", false))
		and _count_csg_nodes(root) == 0
	)
	var row := MeshAnalyzerScript.strip_transient_arrays(analysis)
	row.merge({
		"operation_count": revision,
		"geometry_pass": (
			strict_pass
			and authoring_pass
			and volume_finite
			and volume_monotonic
			and occupancy_volume_pass
			and summary_revision_pass
			and no_csg_pass
		),
		"strict_topology_pass": strict_pass,
		"authoring_topology_pass": authoring_pass,
		"strict_edge_manifold_watertight_pass": strict_pass,
		"authoring_edge_manifold_watertight_pass": authoring_pass,
		"volume_finite": volume_finite,
		"volume_monotonic": volume_monotonic,
		"analyzer_absolute_volume_cubic_meters": analyzer_volume,
		"local_origin_absolute_volume_cubic_meters": local_origin_volume,
		"expected_occupied_volume_cubic_meters": expected_occupied_volume,
		"exact_lattice_volume_cubic_meters": exact_lattice_volume_cubic_meters,
		"occupancy_volume_error_cubic_meters": occupancy_volume_error,
		"occupancy_volume_tolerance_cubic_meters": occupancy_volume_tolerance,
		"packed_float_volume_diagnostic_pass": (
			packed_float_volume_diagnostic_pass
		),
		"occupancy_volume_relation_pass": occupancy_volume_pass,
		"integer_lattice_volume_oracle": lattice_oracle,
		"occupancy_mesh_semantics": OCCUPANCY_MESH_SEMANTICS,
		"summary_revision_source_pass": summary_revision_pass,
		"no_builtin_csg_pass": no_csg_pass,
		"checkpoint_analyze_ms": analyze_ms,
		"revision": _summary_int(summary, ["revision", "accepted_revision"], -1),
		"source_count": _summary_int(
			summary,
			["source_count", "source_body_count", "accepted_source_body_count"],
			-1
		),
		"active_chunk_count": _summary_int(
			summary,
			["active_chunk_count", "chunk_count", "chunks"],
			-1
		),
		"occupied_cell_count": occupied_cells,
		"quad_count": _summary_int(
			summary,
			[
				"total_quad_count",
				"quads",
				"quad_count",
				"exposed_quad_count",
				"mesh_quad_count",
			],
			-1
		),
		"summary_triangle_count": _summary_int(
			summary,
			[
				"total_triangle_count",
				"triangles",
				"triangle_count",
				"mesh_triangle_count",
			],
			-1
		),
		"candidate_cell_count": _extract_count(
			operation_result,
			summary,
			["candidate_cell_count", "last_candidate_cell_count"]
		),
		"changed_cell_count": _extract_count(
			operation_result,
			summary,
			["changed_cell_count", "last_changed_cell_count"]
		),
		"sampled_static_memory_bytes": OS.get_static_memory_usage(),
		"sampled_static_memory_peak_bytes": peak_static_memory_bytes,
		"backend_summary": summary.duplicate(true),
	}, true)
	return row


func _persist_checkpoint(revision: int, summary: Dictionary) -> bool:
	var payload := {
		"status": "running",
		"benchmark_schema": BENCHMARK_SCHEMA_VERSION,
		"run_id": run_id,
		"prototype_scope": PROTOTYPE_SCOPE,
		"occupancy_mesh_semantics": OCCUPANCY_MESH_SEMANTICS,
		"target_operation_count": operation_count,
		"completed_operation_count": revision,
		"cell_size_meters": CELL_SIZE_METERS,
		"chunk_cell_count": CHUNK_CELL_COUNT,
		"processing_halo_chunk_rings": PROCESSING_HALO_CHUNK_RINGS,
		"stream_digest": stream_digest,
		"backend_summary": summary.duplicate(true),
		"checkpoints": checkpoint_rows,
		"timing_bins": timing_bins,
		"raw_operation_rows": raw_operation_rows,
		"current_partial_timing_bin": _build_partial_timing_bin(revision),
		"sampled_static_memory_bytes": OS.get_static_memory_usage(),
		"sampled_static_memory_peak_bytes": peak_static_memory_bytes,
		"last_update_unix": Time.get_unix_time_from_system(),
	}
	return _write_json_atomic(
		"%s_checkpoint_%05d.json" % [run_result_base_path, revision],
		payload
	)


func _build_partial_timing_bin(operation_end: int) -> Dictionary:
	if bin_total_times_ms.is_empty():
		return {}
	return {
		"operation_start": bin_operation_start,
		"operation_end": operation_end,
		"sample_count": bin_total_times_ms.size(),
		"total_p95_ms": _percentile(bin_total_times_ms, 0.95),
		"raster_p95_ms": _percentile(bin_raster_times_ms, 0.95),
		"update_p95_ms": _percentile(bin_update_times_ms, 0.95),
		"remesh_p95_ms": _percentile(bin_remesh_times_ms, 0.95),
		"candidate_cells_p95": _percentile(bin_candidate_cells, 0.95),
		"changed_cells_p95": _percentile(bin_changed_cells, 0.95),
	}


func _update_projection_warning(revision: int) -> void:
	if revision <= 0 or run_started_usec <= 0:
		return
	var elapsed_seconds := (
		float(Time.get_ticks_usec() - run_started_usec) / 1000000.0
	)
	var projected_seconds := (
		elapsed_seconds * float(operation_count) / float(revision)
	)
	if projected_seconds <= PROJECTED_WALL_WARNING_SECONDS:
		return
	if projected_wall_warning.is_empty():
		projected_wall_warning = {
			"first_observed_operation": revision,
			"projected_total_seconds": projected_seconds,
			"warning_only": true,
		}
		warnings.append(
			"projected_wall_time_exceeded_2_hours_warning_only_at_%d"
			% revision
		)


func _finish(passed: bool, preflight_ms: float) -> void:
	var elapsed_seconds := (
		float(Time.get_ticks_usec() - run_started_usec) / 1000000.0
		if run_started_usec > 0
		else 0.0
	)
	var payload := {
		"ok": passed,
		"benchmark_schema": BENCHMARK_SCHEMA_VERSION,
		"run_id": run_id,
		"run_result_base_path": run_result_base_path,
		"backend_id": String(ChunkedBackendScript.BACKEND_ID),
		"backend_schema": ChunkedBackendScript.BACKEND_SCHEMA_VERSION,
		"fixture_schema": StressFixtureScript.FIXTURE_SCHEMA_VERSION,
		"fixture_id": String(StressFixtureScript.FIXTURE_ID),
		"prototype_scope": PROTOTYPE_SCOPE,
		"occupancy_mesh_semantics": OCCUPANCY_MESH_SEMANTICS,
		"cell_size_meters": CELL_SIZE_METERS,
		"chunk_cell_count": CHUNK_CELL_COUNT,
		"processing_halo_chunk_rings": PROCESSING_HALO_CHUNK_RINGS,
		"target_operation_count": operation_count,
		"completed_operation_count": completed_operation_count,
		"elapsed_seconds": elapsed_seconds,
		"preflight_ms": preflight_ms,
		"stream_digest": stream_digest,
		"expected_stream_digest": String(preflight_result.get(
			"stream_digest",
			""
		)),
		"preflight": preflight_result,
		"backend_source_audit": backend_source_audit,
		"final_backend_summary": final_backend_summary,
		"timing_bin_size": TIMING_BIN_SIZE,
		"timing_bins": timing_bins,
		"raw_operation_rows": raw_operation_rows,
		"checkpoints": checkpoint_rows,
		"initial_static_memory_bytes": initial_static_memory_bytes,
		"peak_sampled_static_memory_bytes": peak_static_memory_bytes,
		"final_static_memory_bytes": OS.get_static_memory_usage(),
		"projected_wall_time_warning": projected_wall_warning,
		"errors": errors,
		"warnings": warnings,
		"live_player_library_accessed": false,
		"protected_live_wips": ["Test Glave", "Test sword for animations"],
	}
	var output_ok := true
	output_ok = _write_json_atomic(run_result_base_path + ".json", payload) and output_ok
	output_ok = _write_csv_atomic(run_result_base_path + ".csv") and output_ok
	output_ok = _write_raw_operations_csv_atomic(
		run_result_base_path + ".operations.csv"
	) and output_ok
	output_ok = _write_text_atomic(run_result_base_path + ".txt", payload) and output_ok
	if not output_ok:
		passed = false
		_append_error("result_output_write_failed")
		payload["ok"] = false
		payload["errors"] = errors
		_write_json_atomic(run_result_base_path + ".json", payload)
		_write_text_atomic(run_result_base_path + ".txt", payload)
	print(
		"Forge V2 chunked-field proof %s: %d/%d operations in %.3fs (%s)"
		% [
			"PASS" if passed else "FAIL",
			completed_operation_count,
			operation_count,
			elapsed_seconds,
			run_result_base_path,
		]
	)
	if not passed:
		push_error("Forge V2 chunked-field proof failed: %s" % str(errors))
	quit(0 if passed else 1)


func _write_csv_atomic(path: String) -> bool:
	var lines := PackedStringArray([
		"row_type,operation_start,operation_end,operation_count,sample_count,total_p50_ms,total_p95_ms,total_p99_ms,total_max_ms,raster_p50_ms,raster_p95_ms,raster_max_ms,update_p50_ms,update_p95_ms,update_max_ms,remesh_p50_ms,remesh_p95_ms,remesh_max_ms,apply_wall_p95_ms,candidate_cells_p95,candidate_cells_max,changed_cells_p95,changed_cells_max,active_chunk_count,occupied_cell_count,quad_count,triangle_count,strict_watertight,authoring_watertight,component_count,absolute_volume_cubic_meters,occupancy_volume_relation_pass,checkpoint_analyze_ms,static_memory_bytes"
	])
	for row: Dictionary in timing_bins:
		var cells := PackedStringArray()
		cells.resize(34)
		cells.fill("")
		cells[0] = "timing_bin"
		cells[1] = str(row.get("operation_start", 0))
		cells[2] = str(row.get("operation_end", 0))
		cells[4] = str(row.get("sample_count", 0))
		cells[5] = _csv_float(row.get("total_p50_ms", 0.0))
		cells[6] = _csv_float(row.get("total_p95_ms", 0.0))
		cells[7] = _csv_float(row.get("total_p99_ms", 0.0))
		cells[8] = _csv_float(row.get("total_max_ms", 0.0))
		cells[9] = _csv_float(row.get("raster_p50_ms", 0.0))
		cells[10] = _csv_float(row.get("raster_p95_ms", 0.0))
		cells[11] = _csv_float(row.get("raster_max_ms", 0.0))
		cells[12] = _csv_float(row.get("update_p50_ms", 0.0))
		cells[13] = _csv_float(row.get("update_p95_ms", 0.0))
		cells[14] = _csv_float(row.get("update_max_ms", 0.0))
		cells[15] = _csv_float(row.get("remesh_p50_ms", 0.0))
		cells[16] = _csv_float(row.get("remesh_p95_ms", 0.0))
		cells[17] = _csv_float(row.get("remesh_max_ms", 0.0))
		cells[18] = _csv_float(row.get("apply_wall_p95_ms", 0.0))
		cells[19] = _csv_float(row.get("candidate_cells_p95", 0.0))
		cells[20] = str(row.get("candidate_cells_max", 0))
		cells[21] = _csv_float(row.get("changed_cells_p95", 0.0))
		cells[22] = str(row.get("changed_cells_max", 0))
		cells[33] = str(row.get("sampled_static_memory_bytes", 0))
		lines.append(",".join(cells))
	for row: Dictionary in checkpoint_rows:
		var cells := PackedStringArray()
		cells.resize(34)
		cells.fill("")
		cells[0] = "checkpoint"
		cells[3] = str(row.get("operation_count", 0))
		cells[23] = str(row.get("active_chunk_count", 0))
		cells[24] = str(row.get("occupied_cell_count", 0))
		cells[25] = str(row.get("quad_count", 0))
		cells[26] = str(row.get("triangle_count", 0))
		cells[27] = str(row.get("strict_watertight", false)).to_lower()
		cells[28] = str(row.get("watertight", false)).to_lower()
		cells[29] = str(row.get("strict_component_count", 0))
		cells[30] = "%.12f" % float(row.get("absolute_volume_cubic_meters", 0.0))
		cells[31] = str(row.get("occupancy_volume_relation_pass", false)).to_lower()
		cells[32] = _csv_float(row.get("checkpoint_analyze_ms", 0.0))
		cells[33] = str(row.get("sampled_static_memory_bytes", 0))
		lines.append(",".join(cells))
	return _write_file_atomic(path, "\n".join(lines) + "\n")


func _write_raw_operations_csv_atomic(path: String) -> bool:
	var fields := PackedStringArray([
		"revision", "total_ms", "backend_entry_to_exit_ms", "apply_wall_ms",
		"validation_ms", "raster_ms", "attachment_ms", "context_build_ms",
		"update_ms", "remesh_ms", "world_aabb_cell_count",
		"examined_cell_count", "centerline_chunk_count",
		"broadphase_chunk_count", "intersecting_chunk_count",
		"candidate_cell_count", "candidate_chunk_count",
		"candidate_component_count", "attached_component_count",
		"contact_cell_count", "contact_chunk_count", "new_only_chunk_count",
		"processing_context_chunk_count", "resident_context_chunk_count",
		"changed_cell_count", "changed_chunk_count", "remeshed_chunk_count",
		"remesh_scanned_cell_count", "remeshed_occupied_cell_count",
		"remeshed_occupied_cell_min", "remeshed_occupied_cell_max",
		"rebuilt_quad_count",
		"rebuilt_vertex_count", "rebuilt_index_count", "resident_chunk_count",
		"occupied_cell_count", "resident_triangle_count", "live_csg_node_count",
	])
	var float_fields := {
		"total_ms": true,
		"backend_entry_to_exit_ms": true,
		"apply_wall_ms": true,
		"validation_ms": true,
		"raster_ms": true,
		"attachment_ms": true,
		"context_build_ms": true,
		"update_ms": true,
		"remesh_ms": true,
	}
	var lines := PackedStringArray([",".join(fields)])
	for row: Dictionary in raw_operation_rows:
		var values := PackedStringArray()
		for field: String in fields:
			values.append(
				_csv_float(row.get(field, 0.0))
				if float_fields.has(field)
				else str(row.get(field, ""))
			)
		lines.append(",".join(values))
	return _write_file_atomic(path, "\n".join(lines) + "\n")


func _write_text_atomic(path: String, payload: Dictionary) -> bool:
	var lines := PackedStringArray([
		"Forge V2 Chunked Labelled Solid Locality/Scaling Proof",
		"ok=%s" % str(payload.get("ok", false)).to_lower(),
		"scope=%s" % PROTOTYPE_SCOPE,
		"mesh_semantics=%s" % OCCUPANCY_MESH_SEMANTICS,
		"completed_operations=%d/%d" % [
			completed_operation_count,
			operation_count,
		],
		"elapsed_seconds=%.3f" % float(payload.get("elapsed_seconds", 0.0)),
		"cell_size_meters=%.6f" % CELL_SIZE_METERS,
		"chunk_cell_count=%d" % CHUNK_CELL_COUNT,
		"stream_digest=%s" % stream_digest,
		"warnings=%s" % str(warnings),
		"errors=%s" % str(errors),
	])
	for row: Dictionary in checkpoint_rows:
		lines.append(
			"checkpoint=%d chunks=%d cells=%d quads=%d triangles=%d strict=%s authoring=%s components=%d volume=%.12f occupancy_match=%s analyze_ms=%.3f"
			% [
				int(row.get("operation_count", 0)),
				int(row.get("active_chunk_count", 0)),
				int(row.get("occupied_cell_count", 0)),
				int(row.get("quad_count", 0)),
				int(row.get("triangle_count", 0)),
				str(row.get("strict_topology_pass", false)).to_lower(),
				str(row.get("authoring_topology_pass", false)).to_lower(),
				int(row.get("strict_component_count", 0)),
				float(row.get("absolute_volume_cubic_meters", 0.0)),
				str(row.get("occupancy_volume_relation_pass", false)).to_lower(),
				float(row.get("checkpoint_analyze_ms", 0.0)),
			]
		)
	return _write_file_atomic(path, "\n".join(lines) + "\n")


func _audit_backend_source() -> Dictionary:
	var file := FileAccess.open(BACKEND_SOURCE_PATH, FileAccess.READ)
	var source_text := ""
	if file != null:
		source_text = file.get_as_text()
		file.close()
	var banned_class_tokens := [
		"CSGShape3D",
		"CSGCombiner3D",
		"CSGPolygon3D",
		"CSGMesh3D",
		"CSGBox3D",
		"CSGCylinder3D",
		"CSGSphere3D",
		"CSGTorus3D",
	]
	var matched_tokens: Array[String] = []
	for token: String in banned_class_tokens:
		if source_text.contains(token):
			matched_tokens.append(token)
	var dependencies := Array(ResourceLoader.get_dependencies(BACKEND_SOURCE_PATH))
	var csg_dependencies: Array[String] = []
	for dependency_variant: Variant in dependencies:
		var dependency := String(dependency_variant)
		if dependency.to_lower().contains("csg"):
			csg_dependencies.append(dependency)
	return {
		"pass": (
			file != null
			and matched_tokens.is_empty()
			and csg_dependencies.is_empty()
		),
		"source_readable": file != null,
		"matched_builtin_csg_class_tokens": matched_tokens,
		"csg_named_resource_dependencies": csg_dependencies,
		"resource_dependencies": dependencies,
	}


func _extract_count(
	result: Dictionary,
	summary: Dictionary,
	keys: Array[String]
) -> int:
	for key: String in keys:
		if result.has(key):
			return int(result[key])
	for key: String in keys:
		if summary.has(key):
			return int(summary[key])
	return -1


func _summary_int(
	summary: Dictionary,
	keys: Array[String],
	fallback: int
) -> int:
	for key: String in keys:
		if summary.has(key):
			return int(summary[key])
	return fallback


func _summary_bool(
	summary: Dictionary,
	keys: Array[String],
	fallback: bool
) -> bool:
	for key: String in keys:
		if summary.has(key):
			return bool(summary[key])
	return fallback


func _first_float(
	dictionary: Dictionary,
	keys: Array[String],
	fallback: float
) -> float:
	for key: String in keys:
		if dictionary.has(key):
			return float(dictionary[key])
	return fallback


func _sample_static_memory() -> void:
	peak_static_memory_bytes = maxi(
		peak_static_memory_bytes,
		OS.get_static_memory_usage()
	)


func _count_csg_nodes(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if node is CSGShape3D else 0
	for child: Node in node.get_children():
		count += _count_csg_nodes(child)
	return count


func _calculate_local_origin_mesh_volume(mesh: ArrayMesh) -> float:
	if mesh == null or mesh.get_surface_count() <= 0:
		return 0.0
	var origin := mesh.get_aabb().get_center()
	var signed_volume := 0.0
	for surface_index in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for offset in range(0, indices.size(), 3):
			var first := vertices[indices[offset]] - origin
			var second := vertices[indices[offset + 1]] - origin
			var third := vertices[indices[offset + 2]] - origin
			signed_volume += first.dot(second.cross(third)) / 6.0
	return absf(signed_volume)


func _analyze_integer_lattice_volume(
	mesh: ArrayMesh,
	expected_occupied_cell_count: int
) -> Dictionary:
	var signed_six_lattice_volume := 0
	var maximum_snap_error_meters := 0.0
	var triangle_count := 0
	var nonfinite_vertex_count := 0
	if mesh == null:
		return {"pass": false, "error": "mesh_missing"}
	for surface_index in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var lattice_vertices: Array[Vector3i] = []
		lattice_vertices.resize(vertices.size())
		for vertex_index in range(vertices.size()):
			var vertex := vertices[vertex_index]
			if not vertex.is_finite():
				nonfinite_vertex_count += 1
				continue
			var lattice_vertex := Vector3i(
				roundi(vertex.x / CELL_SIZE_METERS),
				roundi(vertex.y / CELL_SIZE_METERS),
				roundi(vertex.z / CELL_SIZE_METERS)
			)
			lattice_vertices[vertex_index] = lattice_vertex
			var snapped := Vector3(lattice_vertex) * CELL_SIZE_METERS
			var vertex_snap_error := maxf(
				absf(vertex.x - snapped.x),
				maxf(
					absf(vertex.y - snapped.y),
					absf(vertex.z - snapped.z)
				)
			)
			maximum_snap_error_meters = maxf(
				maximum_snap_error_meters,
				vertex_snap_error
			)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for offset in range(0, indices.size(), 3):
			var first := lattice_vertices[indices[offset]]
			var second := lattice_vertices[indices[offset + 1]]
			var third := lattice_vertices[indices[offset + 2]]
			signed_six_lattice_volume += _integer_scalar_triple(
				first,
				second,
				third
			)
			triangle_count += 1
	var absolute_six_lattice_volume := absi(signed_six_lattice_volume)
	var expected_six_lattice_volume := expected_occupied_cell_count * 6
	return {
		"pass": (
			expected_occupied_cell_count > 0
			and nonfinite_vertex_count == 0
			and maximum_snap_error_meters <= LATTICE_SNAP_TOLERANCE_METERS
			and absolute_six_lattice_volume == expected_six_lattice_volume
			and absolute_six_lattice_volume % 6 == 0
		),
		"triangle_count": triangle_count,
		"nonfinite_vertex_count": nonfinite_vertex_count,
		"signed_six_lattice_volume": signed_six_lattice_volume,
		"absolute_six_lattice_volume": absolute_six_lattice_volume,
		"expected_six_lattice_volume": expected_six_lattice_volume,
		"exact_lattice_volume_cells": float(absolute_six_lattice_volume) / 6.0,
		"expected_occupied_cell_count": expected_occupied_cell_count,
		"maximum_lattice_snap_error_meters": maximum_snap_error_meters,
		"lattice_snap_tolerance_meters": LATTICE_SNAP_TOLERANCE_METERS,
	}


func _integer_scalar_triple(
	first: Vector3i,
	second: Vector3i,
	third: Vector3i
) -> int:
	return (
		first.x * (second.y * third.z - second.z * third.y)
		+ first.y * (second.z * third.x - second.x * third.z)
		+ first.z * (second.x * third.y - second.y * third.x)
	)


func _dispose_backend(backend: Variant) -> void:
	if backend == null:
		return
	if backend.has_method("dispose"):
		backend.call("dispose")
	elif backend.has_method("reset"):
		backend.call("reset")


func _percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var index := clampi(
		int(ceil(float(sorted_values.size()) * ratio)) - 1,
		0,
		sorted_values.size() - 1
	)
	return sorted_values[index]


func _maximum(values: Array[float]) -> float:
	var result := 0.0
	for value: float in values:
		result = maxf(result, value)
	return result


func _read_environment_int(
	key: String,
	fallback: int,
	minimum: int,
	maximum: int
) -> int:
	var value := OS.get_environment(key).strip_edges()
	if value.is_valid_int():
		return clampi(value.to_int(), minimum, maximum)
	return clampi(fallback, minimum, maximum)


func _append_error(error: String) -> void:
	if errors.size() < 64 and not errors.has(error):
		errors.append(error)


func _csv_float(value: Variant) -> String:
	return "%.6f" % float(value)


func _write_json_atomic(path: String, payload: Dictionary) -> bool:
	return _write_file_atomic(path, JSON.stringify(payload, "\t") + "\n")


func _write_file_atomic(path: String, text: String) -> bool:
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	if FileAccess.file_exists(path):
		var remove_error := DirAccess.remove_absolute(path)
		if remove_error != OK:
			DirAccess.remove_absolute(temporary_path)
			return false
	var rename_error := DirAccess.rename_absolute(temporary_path, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary_path)
		return false
	return true


func _elapsed_milliseconds(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0
