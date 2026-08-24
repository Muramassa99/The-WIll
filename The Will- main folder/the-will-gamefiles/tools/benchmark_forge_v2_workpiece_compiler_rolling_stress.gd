extends SceneTree

const StressFixtureScript = preload(
	"res://tools/forge_v2_workpiece_stress_fixture.gd"
)
const MeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)
const RollingBackendScript = preload(
	"res://tools/forge_v2_rolling_csg_workpiece_backend.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)

const STRESS_SCHEMA_VERSION := 2
const RESULT_BASE_PATH := (
	"C:/WORKSPACE/godot_runs/forge_v2_workpiece_rolling_stress"
)
const RESULT_JSON_PATH := RESULT_BASE_PATH + ".json"
const RESULT_CSV_PATH := RESULT_BASE_PATH + ".csv"
const RESULT_TEXT_PATH := RESULT_BASE_PATH + ".txt"
const HEARTBEAT_PATH := RESULT_BASE_PATH + "_heartbeat.json"
const DEFAULT_OPERATION_COUNT := 1000
const DEFAULT_ABSORPTION_WINDOW_SIZE := 5
const FRAME_SETTLE_COUNT := 3
const HEARTBEAT_INTERVAL := 100
const SINGLE_OPERATION_ABORT_MS := 10000.0
const CONSECUTIVE_SLOW_ABORT_MS := 2000.0
const CONSECUTIVE_SLOW_ABORT_COUNT := 3
const SOFT_P95_WARNING_MS := 100.0
const STATIC_MEMORY_DELTA_ABORT_BYTES := 4 * 1024 * 1024 * 1024
const STATIC_MEMORY_TOTAL_ABORT_BYTES := 8 * 1024 * 1024 * 1024
const PROJECTED_WALL_WARNING_SECONDS := 2.0 * 60.0 * 60.0
const COLLISION_CHECKPOINTS := [100, 1000, 5000, 10000, 10001]

var errors: Array[String] = []
var warnings: Array[String] = []
var checkpoint_rows: Array[Dictionary] = []
var compile_times_ms: Array[float] = []
var frame_gaps_ms: Array[float] = []
var node_build_times_ms: Array[float] = []
var settle_wall_times_ms: Array[float] = []
var static_bake_times_ms: Array[float] = []
var consolidation_times_ms: Array[float] = []
var top_slow_operations: Array[Dictionary] = []
var operation_count := DEFAULT_OPERATION_COUNT
var absorption_window_size := DEFAULT_ABSORPTION_WINDOW_SIZE
var collision_enabled := true
var run_started_usec := 0
var initial_static_memory_bytes := 0
var peak_observed_static_memory_bytes := 0
var completed_operation_count := 0
var stream_digest := ""
var preflight_result: Dictionary = {}
var abort_reason := ""
var run_id := ""
var run_result_base_path := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_BASE_PATH.get_base_dir())
	operation_count = _read_environment_int(
		"FORGE_V2_STRESS_MAX_OPERATIONS",
		DEFAULT_OPERATION_COUNT,
		1,
		StressFixtureScript.MAX_OPERATION_COUNT
	)
	absorption_window_size = _read_environment_int(
		"FORGE_V2_ROLLING_ABSORPTION_WINDOW",
		DEFAULT_ABSORPTION_WINDOW_SIZE,
		1,
		RollingBackendScript.MAX_ABSORPTION_WINDOW_SIZE
	)
	collision_enabled = _read_environment_bool(
		"FORGE_V2_STRESS_COLLISION",
		true
	)
	run_id = "%d_ops_%d_window_%d" % [
		int(Time.get_unix_time_from_system()),
		operation_count,
		absorption_window_size,
	]
	run_result_base_path = RESULT_BASE_PATH + "_" + run_id
	print(
		"Forge V2 rolling soak: operations=%d window=%d collision=%s"
		% [operation_count, absorption_window_size, str(collision_enabled)]
	)
	var preflight_started := Time.get_ticks_usec()
	preflight_result = StressFixtureScript.preflight(operation_count)
	var preflight_ms := _elapsed_milliseconds(preflight_started)
	if not bool(preflight_result.get("ok", false)):
		errors.append("stress_fixture_preflight_failed")
		for error_variant: Variant in preflight_result.get("errors", []):
			errors.append(String(error_variant))
		_finish(false, preflight_ms)
		return

	var presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	presenter.name = "RollingStressPresenter"
	root.add_child(presenter)
	var backend_host := Node3D.new()
	backend_host.name = "RollingStressHost"
	root.add_child(backend_host)
	await process_frame
	var backend = RollingBackendScript.new()
	var initialize_result: Dictionary = backend.initialize(
		backend_host,
		presenter,
		absorption_window_size
	)
	if not bool(initialize_result.get("ok", false)):
		errors.append(String(initialize_result.get(
			"error",
			"rolling_backend_initialization_failed"
		)))
		_cleanup(backend, backend_host, presenter)
		_finish(false, preflight_ms)
		return

	var seed_body: Resource = StressFixtureScript.build_seed_body()
	var seed_result: Dictionary = backend.initialize_seed(seed_body)
	if not bool(seed_result.get("ok", false)):
		errors.append(String(seed_result.get(
			"error",
			"rolling_backend_seed_failed"
		)))
		_cleanup(backend, backend_host, presenter)
		_finish(false, preflight_ms)
		return
	stream_digest = (
		"schema=%d|fixture=%s"
		% [
			StressFixtureScript.FIXTURE_SCHEMA_VERSION,
			String(StressFixtureScript.FIXTURE_ID),
		]
	).sha256_text()
	stream_digest = StressFixtureScript.extend_digest(stream_digest, seed_body)
	seed_body = null
	initial_static_memory_bytes = OS.get_static_memory_usage()
	peak_observed_static_memory_bytes = initial_static_memory_bytes
	run_started_usec = Time.get_ticks_usec()
	var checkpoint_lookup: Dictionary = {}
	for checkpoint: int in StressFixtureScript.build_checkpoint_list(
		operation_count
	):
		checkpoint_lookup[checkpoint] = true
	var previous_checkpoint_volume := -1.0
	var consecutive_slow_operations := 0
	for operation_index in range(operation_count):
		var body: Resource = StressFixtureScript.build_operation_body(
			operation_index
		)
		if body == null:
			_abort("operation_%d_body_missing" % (operation_index + 1))
			break
		stream_digest = StressFixtureScript.extend_digest(stream_digest, body)
		var result: Dictionary = await backend.apply_add_body(
			body,
			FRAME_SETTLE_COUNT,
			false
		)
		body = null
		var accepted_operation := operation_index + 1
		if not bool(result.get("ok", false)):
			_abort(
				"operation_%d_backend_error_%s"
				% [accepted_operation, String(result.get("error", "unknown"))]
			)
			break
		completed_operation_count = accepted_operation
		var compile_ms := float(result.get(
			"operation_compile_total_ms",
			INF
		))
		var frame_gap_ms := float(result.get("max_frame_gap_ms", INF))
		compile_times_ms.append(compile_ms)
		frame_gaps_ms.append(frame_gap_ms)
		node_build_times_ms.append(float(result.get("node_build_ms", 0.0)))
		settle_wall_times_ms.append(float(result.get("settle_wall_ms", 0.0)))
		static_bake_times_ms.append(float(result.get("static_bake_ms", 0.0)))
		consolidation_times_ms.append(float(result.get(
			"surface_consolidation_ms",
			0.0
		)))
		_record_slow_operation(accepted_operation, compile_ms, frame_gap_ms)
		var invariant_error := _validate_operation_invariants(
			result,
			accepted_operation
		)
		if not invariant_error.is_empty():
			_abort(invariant_error)
			break
		if compile_ms > SINGLE_OPERATION_ABORT_MS or frame_gap_ms > SINGLE_OPERATION_ABORT_MS:
			_abort("operation_%d_exceeded_10_second_gate" % accepted_operation)
			break
		if compile_ms > CONSECUTIVE_SLOW_ABORT_MS:
			consecutive_slow_operations += 1
		else:
			consecutive_slow_operations = 0
		if consecutive_slow_operations >= CONSECUTIVE_SLOW_ABORT_COUNT:
			_abort("three_consecutive_operations_exceeded_2_seconds")
			break

		if checkpoint_lookup.has(accepted_operation):
			var checkpoint_result := _capture_checkpoint(
				backend,
				result,
				accepted_operation,
				previous_checkpoint_volume
			)
			checkpoint_rows.append(checkpoint_result)
			if not _persist_checkpoint_progress(accepted_operation):
				_abort(
					"operation_%d_checkpoint_persistence_failed"
					% accepted_operation
				)
				break
			if bool(checkpoint_result.get("geometry_pass", false)):
				previous_checkpoint_volume = float(checkpoint_result.get(
					"absolute_volume_cubic_meters",
					previous_checkpoint_volume
				))
			else:
				_abort(
					"operation_%d_checkpoint_geometry_failed"
					% accepted_operation
				)
				break

		if (
			accepted_operation % HEARTBEAT_INTERVAL == 0
			or checkpoint_lookup.has(accepted_operation)
		):
			var memory_error := _sample_memory_and_write_heartbeat(
				accepted_operation,
				backend
			)
			if not memory_error.is_empty():
				_abort(memory_error)
				break
			if accepted_operation >= 1000:
				var elapsed_seconds := float(
					Time.get_ticks_usec() - run_started_usec
				) / 1000000.0
				var projected_total_seconds := (
					elapsed_seconds
					* float(operation_count)
					/ float(accepted_operation)
				)
				if projected_total_seconds > PROJECTED_WALL_WARNING_SECONDS:
					var warning := "projected_wall_time_exceeded_2_hours_at_%d" % accepted_operation
					if not warnings.has(warning):
						warnings.append(warning)

	var expected_digest := String(preflight_result.get("stream_digest", ""))
	if completed_operation_count == operation_count and stream_digest != expected_digest:
		errors.append("executed_stream_digest_mismatch")
	var passed := (
		errors.is_empty()
		and abort_reason.is_empty()
		and completed_operation_count == operation_count
		and stream_digest == expected_digest
	)
	_cleanup(backend, backend_host, presenter)
	_finish(passed, preflight_ms)


func _validate_operation_invariants(result: Dictionary, revision: int) -> String:
	if int(result.get("accepted_revision", -1)) != revision:
		return "operation_%d_revision_mismatch" % revision
	if int(result.get("accepted_source_body_count", -1)) != revision + 1:
		return "operation_%d_source_count_mismatch" % revision
	var expected_pending := revision % absorption_window_size
	if int(result.get("pending_body_count", -1)) != expected_pending:
		return "operation_%d_pending_count_mismatch" % revision
	if int(result.get("accepted_base_revision", -1)) != revision - expected_pending:
		return "operation_%d_base_revision_mismatch" % revision
	if int(result.get("compile_csg_operand_count", 999999)) > absorption_window_size + 1:
		return "operation_%d_peak_operand_bound_failed" % revision
	if int(result.get("steady_csg_operand_count", -1)) != 0:
		return "operation_%d_retained_csg_operand" % revision
	if int(result.get("accepted_display_mesh_count", -1)) != 1:
		return "operation_%d_display_mesh_count_changed" % revision
	if int(result.get("accepted_surface_count", -1)) != 1:
		return "operation_%d_surface_count_changed" % revision
	return ""


func _capture_checkpoint(
	backend: RefCounted,
	operation_result: Dictionary,
	revision: int,
	previous_volume: float
) -> Dictionary:
	var mesh: ArrayMesh = backend.get_accepted_mesh()
	var analyze_started := Time.get_ticks_usec()
	var analysis: Dictionary = MeshAnalyzerScript.analyze_mesh(mesh)
	var analyze_ms := _elapsed_milliseconds(analyze_started)
	var strict_pass := (
		bool(analysis.get("strict_watertight", false))
		and int(analysis.get("strict_component_count", 0)) == 1
		and int(analysis.get("strict_boundary_edge_count", -1)) == 0
		and int(analysis.get("strict_nonmanifold_edge_count", -1)) == 0
		and int(analysis.get("strict_directed_edge_mismatch_count", -1)) == 0
		and int(analysis.get("strict_degenerate_triangle_collapse_count", -1)) == 0
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
	var volume := float(analysis.get("absolute_volume_cubic_meters", 0.0))
	var volume_monotonic := (
		previous_volume < 0.0
		or volume + 0.000000000001 >= previous_volume
	)
	var collision_ms := 0.0
	var collision_face_count := 0
	var collision_required := collision_enabled and COLLISION_CHECKPOINTS.has(revision)
	var collision_pass := not collision_required
	if collision_required:
		var collision_started := Time.get_ticks_usec()
		var collision_shape := mesh.create_trimesh_shape()
		collision_ms = _elapsed_milliseconds(collision_started)
		if collision_shape != null:
			collision_face_count = int(collision_shape.get_faces().size() / 3.0)
			collision_pass = collision_face_count > 0
	var row := MeshAnalyzerScript.strip_transient_arrays(analysis)
	row.merge({
		"operation_count": revision,
		"geometry_pass": (
			strict_pass
			and authoring_pass
			and volume_monotonic
			and collision_pass
		),
		"strict_topology_pass": strict_pass,
		"authoring_topology_pass": authoring_pass,
		"strict_edge_manifold_watertight_pass": strict_pass,
		"authoring_edge_manifold_watertight_pass": authoring_pass,
		"volume_monotonic": volume_monotonic,
		"checkpoint_analyze_ms": analyze_ms,
		"collision_required": collision_required,
		"collision_pass": collision_pass,
		"collision_bake_ms": collision_ms,
		"collision_face_count": collision_face_count,
		"operation_compile_ms": float(operation_result.get(
			"operation_compile_total_ms",
			0.0
		)),
		"operation_headless_settle_frame_gap_ms": float(operation_result.get(
			"max_frame_gap_ms",
			0.0
		)),
		"operation_frame_gap_ms": float(operation_result.get(
			"max_frame_gap_ms",
			0.0
		)),
		"node_build_ms": float(operation_result.get("node_build_ms", 0.0)),
		"settle_wall_ms": float(operation_result.get("settle_wall_ms", 0.0)),
		"static_bake_ms": float(operation_result.get("static_bake_ms", 0.0)),
		"surface_consolidation_ms": float(operation_result.get(
			"surface_consolidation_ms",
			0.0
		)),
		"compile_csg_operand_count": int(operation_result.get(
			"compile_csg_operand_count",
			0
		)),
		"steady_csg_operand_count": int(operation_result.get(
			"steady_csg_operand_count",
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
	}, true)
	analysis = {}
	return row


func _sample_memory_and_write_heartbeat(
	revision: int,
	backend: RefCounted
) -> String:
	var static_memory_bytes := OS.get_static_memory_usage()
	peak_observed_static_memory_bytes = maxi(
		peak_observed_static_memory_bytes,
		static_memory_bytes
	)
	var memory_delta := static_memory_bytes - initial_static_memory_bytes
	var recent_compile := _tail_values(compile_times_ms, HEARTBEAT_INTERVAL)
	var recent_frames := _tail_values(frame_gaps_ms, HEARTBEAT_INTERVAL)
	var recent_node_build := _tail_values(node_build_times_ms, HEARTBEAT_INTERVAL)
	var recent_settle := _tail_values(settle_wall_times_ms, HEARTBEAT_INTERVAL)
	var recent_static_bake := _tail_values(static_bake_times_ms, HEARTBEAT_INTERVAL)
	var recent_consolidation := _tail_values(
		consolidation_times_ms,
		HEARTBEAT_INTERVAL
	)
	var elapsed_seconds := float(Time.get_ticks_usec() - run_started_usec) / 1000000.0
	var payload := {
		"status": "running",
		"operation_count": revision,
		"target_operation_count": operation_count,
		"elapsed_seconds": elapsed_seconds,
		"recent_compile_p50_ms": _percentile(recent_compile, 0.50),
		"recent_compile_p95_ms": _percentile(recent_compile, 0.95),
		"recent_compile_p99_ms": _percentile(recent_compile, 0.99),
		"recent_compile_max_ms": _maximum(recent_compile),
		"recent_headless_settle_frame_gap_p95_ms": _percentile(recent_frames, 0.95),
		"recent_frame_p95_ms": _percentile(recent_frames, 0.95),
		"recent_node_build_p95_ms": _percentile(recent_node_build, 0.95),
		"recent_settle_wall_p95_ms": _percentile(recent_settle, 0.95),
		"recent_static_bake_p95_ms": _percentile(recent_static_bake, 0.95),
		"recent_surface_consolidation_p95_ms": _percentile(
			recent_consolidation,
			0.95
		),
		"sampled_godot_static_memory_bytes": static_memory_bytes,
		"sampled_godot_static_memory_delta_bytes": memory_delta,
		"sampled_godot_static_memory_peak_bytes": peak_observed_static_memory_bytes,
		"static_memory_bytes": static_memory_bytes,
		"static_memory_delta_bytes": memory_delta,
		"static_memory_peak_bytes": peak_observed_static_memory_bytes,
		"accepted_revision": backend.get_accepted_revision(),
		"last_update_unix": Time.get_unix_time_from_system(),
	}
	if not _write_json(HEARTBEAT_PATH, payload):
		return "heartbeat_output_write_failed"
	print(
		"SOAK %d/%d elapsed=%.1fs compile_p95=%.2fms frame_p95=%.2fms memory=%.1fMiB"
		% [
			revision,
			operation_count,
			elapsed_seconds,
			float(payload["recent_compile_p95_ms"]),
			float(payload["recent_frame_p95_ms"]),
			float(static_memory_bytes) / 1048576.0,
		]
	)
	if float(payload["recent_compile_p95_ms"]) > SOFT_P95_WARNING_MS:
		var warning := "recent_compile_p95_exceeded_100ms_at_%d" % revision
		if not warnings.has(warning):
			warnings.append(warning)
	if static_memory_bytes > STATIC_MEMORY_TOTAL_ABORT_BYTES:
		return "static_memory_exceeded_8GiB"
	if memory_delta > STATIC_MEMORY_DELTA_ABORT_BYTES:
		return "static_memory_delta_exceeded_4GiB"
	return ""


func _record_slow_operation(
	revision: int,
	compile_ms: float,
	frame_gap_ms: float
) -> void:
	top_slow_operations.append({
		"operation_count": revision,
		"compile_ms": compile_ms,
		"frame_gap_ms": frame_gap_ms,
	})
	top_slow_operations.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return float(first.get("compile_ms", 0.0)) > float(second.get("compile_ms", 0.0))
	)
	if top_slow_operations.size() > 32:
		top_slow_operations.resize(32)


func _build_timing_bins() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for start_index in range(0, compile_times_ms.size(), HEARTBEAT_INTERVAL):
		var end_index := mini(
			start_index + HEARTBEAT_INTERVAL,
			compile_times_ms.size()
		)
		var compile_slice := compile_times_ms.slice(start_index, end_index)
		var frame_slice := frame_gaps_ms.slice(start_index, end_index)
		var node_build_slice := node_build_times_ms.slice(start_index, end_index)
		var settle_slice := settle_wall_times_ms.slice(start_index, end_index)
		var static_bake_slice := static_bake_times_ms.slice(start_index, end_index)
		var consolidation_slice := consolidation_times_ms.slice(start_index, end_index)
		result.append({
			"operation_start": start_index + 1,
			"operation_end": end_index,
			"sample_count": end_index - start_index,
			"compile_p50_ms": _percentile(compile_slice, 0.50),
			"compile_p95_ms": _percentile(compile_slice, 0.95),
			"compile_p99_ms": _percentile(compile_slice, 0.99),
			"compile_max_ms": _maximum(compile_slice),
			"frame_p50_ms": _percentile(frame_slice, 0.50),
			"frame_p95_ms": _percentile(frame_slice, 0.95),
			"frame_p99_ms": _percentile(frame_slice, 0.99),
			"frame_max_ms": _maximum(frame_slice),
			"headless_settle_frame_gap_p95_ms": _percentile(frame_slice, 0.95),
			"node_build_p95_ms": _percentile(node_build_slice, 0.95),
			"settle_wall_p95_ms": _percentile(settle_slice, 0.95),
			"static_bake_p95_ms": _percentile(static_bake_slice, 0.95),
			"surface_consolidation_p95_ms": _percentile(
				consolidation_slice,
				0.95
			),
		})
	return result


func _finish(passed: bool, preflight_ms: float) -> void:
	var elapsed_seconds := (
		float(Time.get_ticks_usec() - run_started_usec) / 1000000.0
		if run_started_usec > 0
		else 0.0
	)
	var bins := _build_timing_bins()
	var payload := {
		"ok": passed,
		"stress_schema": STRESS_SCHEMA_VERSION,
		"backend_id": (
			String(RollingBackendScript.BACKEND_ID)
			+ "_window_%d" % absorption_window_size
		),
		"fixture_schema": StressFixtureScript.FIXTURE_SCHEMA_VERSION,
		"fixture_id": String(StressFixtureScript.FIXTURE_ID),
		"target_operation_count": operation_count,
		"completed_operation_count": completed_operation_count,
		"absorption_window_size": absorption_window_size,
		"frame_settle_count": FRAME_SETTLE_COUNT,
		"frame_gap_metric_scope": "headless_process_frame_settle_before_bake_and_consolidation",
		"topology_metric_scope": "quantized_edge_manifold_and_watertight_only",
		"memory_metric_scope": "sampled_godot_static_memory_not_process_or_gpu_peak",
		"collision_checkpoint_lane_enabled": collision_enabled,
		"elapsed_seconds": elapsed_seconds,
		"preflight_ms": preflight_ms,
		"stream_digest": stream_digest,
		"expected_stream_digest": String(preflight_result.get(
			"stream_digest",
			""
		)),
		"initial_static_memory_bytes": initial_static_memory_bytes,
		"peak_observed_static_memory_bytes": peak_observed_static_memory_bytes,
		"final_static_memory_bytes": OS.get_static_memory_usage(),
		"run_id": run_id,
		"run_result_base_path": run_result_base_path,
		"abort_reason": abort_reason,
		"errors": errors,
		"warnings": warnings,
		"preflight": preflight_result,
		"checkpoints": checkpoint_rows,
		"timing_bins": bins,
		"top_slow_operations": top_slow_operations,
		"protected_live_wips": ["Test Glave", "Test sword for animations"],
		"live_player_library_accessed": false,
	}
	var output_ok := true
	output_ok = _write_json(RESULT_JSON_PATH, payload) and output_ok
	output_ok = _write_json(run_result_base_path + ".json", payload) and output_ok
	output_ok = _write_csv(checkpoint_rows, bins, RESULT_CSV_PATH) and output_ok
	output_ok = _write_csv(
		checkpoint_rows,
		bins,
		run_result_base_path + ".csv"
	) and output_ok
	output_ok = _write_text(payload, RESULT_TEXT_PATH) and output_ok
	output_ok = _write_text(payload, run_result_base_path + ".txt") and output_ok
	if not output_ok:
		passed = false
		if not errors.has("result_output_write_failed"):
			errors.append("result_output_write_failed")
		payload["ok"] = false
		payload["errors"] = errors
		_write_json(RESULT_JSON_PATH, payload)
		_write_json(run_result_base_path + ".json", payload)
		_write_text(payload, RESULT_TEXT_PATH)
		_write_text(payload, run_result_base_path + ".txt")
	var heartbeat_ok := _write_json(HEARTBEAT_PATH, {
		"status": "complete" if passed else "failed",
		"ok": passed,
		"completed_operation_count": completed_operation_count,
		"target_operation_count": operation_count,
		"elapsed_seconds": elapsed_seconds,
		"abort_reason": abort_reason,
		"last_update_unix": Time.get_unix_time_from_system(),
		"run_id": run_id,
	})
	if not heartbeat_ok:
		passed = false
		if not errors.has("heartbeat_output_write_failed"):
			errors.append("heartbeat_output_write_failed")
		payload["ok"] = false
		payload["errors"] = errors
		_write_json(RESULT_JSON_PATH, payload)
		_write_json(run_result_base_path + ".json", payload)
		_write_text(payload, RESULT_TEXT_PATH)
		_write_text(payload, run_result_base_path + ".txt")
	print(
		"Forge V2 rolling soak %s: %d/%d operations in %.2fs"
		% [
			"PASS" if passed else "FAIL",
			completed_operation_count,
			operation_count,
			elapsed_seconds,
		]
	)
	if not passed:
		push_error(
			"Forge V2 rolling soak failed: %s"
			% (abort_reason if not abort_reason.is_empty() else str(errors))
		)
	quit(0 if passed else 1)


func _write_csv(
	checkpoints: Array[Dictionary],
	bins: Array[Dictionary],
	path: String
) -> bool:
	var lines := PackedStringArray([
		"row_type,operation_start,operation_end,operation_count,sample_count,compile_p50_ms,compile_p95_ms,compile_p99_ms,compile_max_ms,headless_settle_frame_gap_p50_ms,headless_settle_frame_gap_p95_ms,headless_settle_frame_gap_p99_ms,headless_settle_frame_gap_max_ms,node_build_p95_ms,settle_wall_p95_ms,static_bake_p95_ms,surface_consolidation_p95_ms,triangle_count,strict_edge_manifold_watertight,strict_component_count,absolute_volume_cubic_meters,checkpoint_analyze_ms,collision_bake_ms,collision_pass"
	])
	for bin: Dictionary in bins:
		lines.append(",".join(PackedStringArray([
			"timing_bin",
			str(bin.get("operation_start", 0)),
			str(bin.get("operation_end", 0)),
			"",
			str(bin.get("sample_count", 0)),
			"%.6f" % float(bin.get("compile_p50_ms", 0.0)),
			"%.6f" % float(bin.get("compile_p95_ms", 0.0)),
			"%.6f" % float(bin.get("compile_p99_ms", 0.0)),
			"%.6f" % float(bin.get("compile_max_ms", 0.0)),
			"%.6f" % float(bin.get("frame_p50_ms", 0.0)),
			"%.6f" % float(bin.get("frame_p95_ms", 0.0)),
			"%.6f" % float(bin.get("frame_p99_ms", 0.0)),
			"%.6f" % float(bin.get("frame_max_ms", 0.0)),
			"%.6f" % float(bin.get("node_build_p95_ms", 0.0)),
			"%.6f" % float(bin.get("settle_wall_p95_ms", 0.0)),
			"%.6f" % float(bin.get("static_bake_p95_ms", 0.0)),
			"%.6f" % float(bin.get("surface_consolidation_p95_ms", 0.0)),
			"", "", "", "", "", "", "",
		])))
	for checkpoint: Dictionary in checkpoints:
		var cells := PackedStringArray()
		cells.resize(24)
		cells.fill("")
		cells[0] = "checkpoint"
		cells[3] = str(checkpoint.get("operation_count", 0))
		cells[17] = str(checkpoint.get("triangle_count", 0))
		cells[18] = str(checkpoint.get("strict_watertight", false)).to_lower()
		cells[19] = str(checkpoint.get("strict_component_count", 0))
		cells[20] = "%.12f" % float(checkpoint.get(
			"absolute_volume_cubic_meters",
			0.0
		))
		cells[21] = "%.6f" % float(checkpoint.get(
			"checkpoint_analyze_ms",
			0.0
		))
		cells[22] = "%.6f" % float(checkpoint.get("collision_bake_ms", 0.0))
		cells[23] = str(checkpoint.get("collision_pass", true)).to_lower()
		lines.append(",".join(cells))
	return _write_text_file_atomic(path, "\n".join(lines) + "\n")


func _write_text(payload: Dictionary, path: String) -> bool:
	var lines := PackedStringArray([
		"Forge V2 Rolling Workpiece Stress",
		"ok=%s" % str(payload.get("ok", false)).to_lower(),
		"completed_operations=%d/%d" % [
			int(payload.get("completed_operation_count", 0)),
			int(payload.get("target_operation_count", 0)),
		],
		"absorption_window=%d" % absorption_window_size,
		"elapsed_seconds=%.3f" % float(payload.get("elapsed_seconds", 0.0)),
		"abort_reason=%s" % String(payload.get("abort_reason", "")),
		"stream_digest=%s" % String(payload.get("stream_digest", "")),
		"warnings=%s" % str(warnings),
		"errors=%s" % str(errors),
	])
	for row: Dictionary in checkpoint_rows:
		lines.append(
			"checkpoint=%d triangles=%d strict=%s components=%d volume=%.12f compile_ms=%.3f frame_ms=%.3f analyze_ms=%.3f collision_ms=%.3f"
			% [
				int(row.get("operation_count", 0)),
				int(row.get("triangle_count", 0)),
				str(row.get("strict_topology_pass", false)).to_lower(),
				int(row.get("strict_component_count", 0)),
				float(row.get("absolute_volume_cubic_meters", 0.0)),
				float(row.get("operation_compile_ms", 0.0)),
				float(row.get("operation_frame_gap_ms", 0.0)),
				float(row.get("checkpoint_analyze_ms", 0.0)),
				float(row.get("collision_bake_ms", 0.0)),
			]
		)
	return _write_text_file_atomic(path, "\n".join(lines) + "\n")


func _abort(reason: String) -> void:
	abort_reason = reason
	if not errors.has(reason):
		errors.append(reason)


func _cleanup(backend, backend_host: Node3D, presenter: Node3D) -> void:
	if backend != null:
		backend.dispose()
	if backend_host != null and is_instance_valid(backend_host):
		if backend_host.get_parent() != null:
			backend_host.get_parent().remove_child(backend_host)
		backend_host.free()
	if presenter != null and is_instance_valid(presenter):
		if presenter.get_parent() != null:
			presenter.get_parent().remove_child(presenter)
		presenter.free()


func _tail_values(values: Array[float], count: int) -> Array[float]:
	var start_index := maxi(values.size() - count, 0)
	return values.slice(start_index, values.size())


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


func _read_environment_bool(key: String, fallback: bool) -> bool:
	var value := OS.get_environment(key).strip_edges().to_lower()
	if value in ["1", "true", "yes", "on"]:
		return true
	if value in ["0", "false", "no", "off"]:
		return false
	return fallback


func _persist_checkpoint_progress(revision: int) -> bool:
	var payload := {
		"status": "running",
		"run_id": run_id,
		"stress_schema": STRESS_SCHEMA_VERSION,
		"fixture_id": String(StressFixtureScript.FIXTURE_ID),
		"target_operation_count": operation_count,
		"completed_operation_count": revision,
		"absorption_window_size": absorption_window_size,
		"stream_digest": stream_digest,
		"checkpoints": checkpoint_rows,
		"timing_bins": _build_timing_bins(),
		"last_update_unix": Time.get_unix_time_from_system(),
	}
	return _write_json(
		"%s_checkpoint_%05d.json" % [run_result_base_path, revision],
		payload
	)


func _write_json(path: String, payload: Dictionary) -> bool:
	return _write_text_file_atomic(path, JSON.stringify(payload, "\t") + "\n")


func _write_text_file_atomic(path: String, text: String) -> bool:
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
