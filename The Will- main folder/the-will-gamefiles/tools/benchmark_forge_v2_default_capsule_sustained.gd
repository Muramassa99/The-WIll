extends SceneTree

const StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const WorkspacePreviewScript = preload(
	"res://runtime/forge_v2/forge_v2_workspace_preview.gd"
)
const MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const EXTENSION_PATH := (
	"res://native/forge_v2_manifold/forge_v2_manifold.gdextension"
)
const RESULT_DIRECTORY := "C:/WORKSPACE/godot_runs"
const LATEST_RESULT_PATH := (
	RESULT_DIRECTORY + "/forge_v2_default_capsule_sustained_latest.json"
)
const LATEST_HEARTBEAT_PATH := (
	RESULT_DIRECTORY + "/forge_v2_default_capsule_sustained_latest.heartbeat.txt"
)
const DEFAULT_STROKE_COUNT := 30
const MAX_STROKE_COUNT := 1000
const DEFAULT_BOUNDS_SCALE := 10.0
const TAIL_CAPACITY := 5
const LOGICAL_BODY_LIMIT := 1 + TAIL_CAPACITY
const NATIVE_RETAINED_STATE_LIMIT := 1 + TAIL_CAPACITY
const OPERAND_CACHE_LIMIT := 12
const OPERAND_ACK_FRAME_LIMIT := 240
const PUBLICATION_DRAIN_FRAME_LIMIT := 600
const FIXTURE_GRID_COLUMNS := 101
const FIXTURE_GRID_PITCH_METERS := 0.004
const FIXTURE_PATH_SAMPLE_COUNT := 5
const FIXTURE_X_MIN := -0.22
const FIXTURE_X_MAX := 0.22
const FIXTURE_CENTER_Y_MIN := -0.20
const FIXTURE_CENTER_Z_MIN := -0.198

var _controller: Node = null
var _workspace: Node3D = null
var _presenter: Node3D = null
var _state: Resource = null
var _rows: Array[Dictionary] = []
var _failures: Array[String] = []
var _stroke_count := DEFAULT_STROKE_COUNT
var _bounds_scale := DEFAULT_BOUNDS_SCALE
var _result_path := ""
var _fixture_bounds := AABB()
var _fixture_bounds_initialized := false
var _measurement_started_usec := 0
var _measurement_ack_finished_usec := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_DIRECTORY)
	_stroke_count = _read_int_environment(
		"FORGE_V2_DEFAULT_CAPSULE_STROKE_COUNT",
		DEFAULT_STROKE_COUNT,
		1,
		MAX_STROKE_COUNT
	)
	_bounds_scale = _read_float_environment(
		"FORGE_V2_DEFAULT_CAPSULE_BOUNDS_SCALE",
		DEFAULT_BOUNDS_SCALE,
		1.0,
		10.0
	)
	var run_id := _build_run_id()
	_result_path = (
		RESULT_DIRECTORY
		+ "/forge_v2_default_capsule_sustained_"
		+ run_id
		+ ".json"
	)
	_write_heartbeat("setup strokes=%d run_id=%s" % [_stroke_count, run_id])

	var extension_resource := load(EXTENSION_PATH)
	if (
		extension_resource == null
		or not ClassDB.class_exists(&"ForgeV2ManifoldBoolean")
	):
		_finish_setup_failure("native ForgeV2ManifoldBoolean is unavailable")
		return

	_controller = StageControllerScript.new()
	_controller.name = "DefaultCapsuleSustainedController"
	root.add_child(_controller)
	_workspace = WorkspacePreviewScript.new()
	_workspace.name = "DefaultCapsuleSustainedWorkspace"
	root.add_child(_workspace)
	await process_frame
	_workspace.call("bind_stage_controller", _controller)
	await process_frame
	await physics_frame
	await process_frame
	_presenter = _workspace.get("volume_preview_presenter") as Node3D
	_state = _controller.call("get_active_authoring_state") as Resource
	if _presenter == null or _state == null:
		_finish_setup_failure("real controller/workspace presenter fixture is incomplete")
		return

	_controller.call("set_active_tool_id", &"tool_volume_stroke")
	_controller.call("set_active_primitive_id", &"primitive_blob")
	_controller.call(
		"set_active_operation_mode",
		VolumeStrokeScript.OPERATION_ADD_MATERIAL
	)
	_controller.call(
		"set_placement_policy",
		VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	)
	var workspace_bounds := _apply_test_workspace_bounds_scale(_bounds_scale)
	if not bool(workspace_bounds.get("ok", false)):
		_record_failure("test-only workspace bounds override failed")
	await process_frame

	var initial := _capture_snapshot()
	if not bool(initial.get("bounded_history_active", false)):
		_record_failure("bounded history is not active in fresh state")
	if int(initial.get("lifetime_operation_count", -1)) != 0:
		_record_failure("fresh state lifetime operation count is not zero")

	_measurement_started_usec = Time.get_ticks_usec()
	for stroke_zero_index in range(_stroke_count):
		if not _failures.is_empty():
			break
		var row := await _run_one_stroke(stroke_zero_index)
		if not _rows.is_empty():
			var prior_row := _rows[_rows.size() - 1]
			var next_start_usec := int(row.get("action_started_usec", 0))
			var prior_ack_usec := int(prior_row.get("native_ack_usec", 0))
			var prior_start_usec := int(prior_row.get("action_started_usec", 0))
			if next_start_usec > 0 and prior_ack_usec > 0:
				prior_row["ack_to_next_action_ms"] = float(
					next_start_usec - prior_ack_usec
				) / 1000.0
			if next_start_usec > 0 and prior_start_usec > 0:
				prior_row["cycle_start_to_next_start_ms"] = float(
					next_start_usec - prior_start_usec
				) / 1000.0
			_rows[_rows.size() - 1] = prior_row
		_rows.append(row)
		if not bool(row.get("ok", false)):
			_record_failure(
				"stroke %d failed: %s" % [
					stroke_zero_index + 1,
					String(row.get("failure", "unknown")),
				]
			)
			break
		var invariant_result := _validate_post_ack_invariants(
			row.get("snapshot", {}) as Dictionary,
			stroke_zero_index + 1
		)
		row["bounded_invariants"] = invariant_result
		_rows[_rows.size() - 1] = row
		if not bool(invariant_result.get("ok", false)):
			_record_failure(
				"stroke %d bounded invariant failed: %s" % [
					stroke_zero_index + 1,
					str(invariant_result.get("failures", [])),
				]
			)
			break
		if (stroke_zero_index + 1) % 25 == 0:
			_write_heartbeat(
				"stroke=%d ack_max_ms=%.3f finish_max_ms=%.3f" % [
					stroke_zero_index + 1,
					_maximum_metric(_rows, "release_to_native_ack_ms"),
					_maximum_metric(_rows, "finish_call_ms"),
				]
			)
	_measurement_ack_finished_usec = Time.get_ticks_usec()

	var before_drain := _capture_snapshot()
	var final_publication_drain := await _drain_final_publication()
	var final_snapshot := _capture_snapshot()
	var workspace_bounds_restore := _restore_test_workspace_bounds(
		workspace_bounds
	)
	if not bool(final_publication_drain.get("ok", false)):
		_record_failure("final native publication did not drain")
	if _rows.size() == _stroke_count:
		var final_invariants := _validate_final_invariants(final_snapshot)
		if not bool(final_invariants.get("ok", false)):
			_record_failure(
				"final bounded/publication invariant failed: %s"
				% str(final_invariants.get("failures", []))
			)

	var finished_usec := Time.get_ticks_usec()
	var summary := _build_summary(_rows)
	var report := {
		"schema": "forge_v2_default_capsule_sustained",
		"schema_version": 1,
		"ok": _failures.is_empty() and _rows.size() == _stroke_count,
		"run_id": run_id,
		"requested_stroke_count": _stroke_count,
		"completed_stroke_count": _rows.size(),
		"production_files_touched_by_benchmark": false,
		"measurement_scope": (
			"real StageController + WorkspacePreview presenter; default "
			+ "CAPSULE_PATH Add/Replace; each exact operand and native transition "
			+ "is accepted before the next stroke; collision publication is "
			+ "allowed to remain deferred until one final drain"
		),
		"primary_metric": "finish/release_to_exact_operand_and_native_ack_ms",
		"tail_priority": "max_then_p95; a flatter tail is preferred over a lower minimum",
		"percentile_definition": (
			"nearest-rank p95: the smallest measured value at or above the "
			+ "95th percentile; 95% of measured strokes are no slower than it"
		),
		"fixture": {
			"shape_kind": String(MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH),
			"operation_mode": String(VolumeStrokeScript.OPERATION_ADD_MATERIAL),
			"placement_policy": String(
				VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
			),
			"path_samples_per_stroke": FIXTURE_PATH_SAMPLE_COUNT,
			"path_mix": ["straight", "planar_bend", "spatial_bend", "s_bend"],
			"grid_columns": FIXTURE_GRID_COLUMNS,
			"grid_pitch_meters": FIXTURE_GRID_PITCH_METERS,
			"bounds": _fixture_bounds,
			"consecutive_strokes_overlap": true,
		},
		"test_workspace_bounds": {
			"requested_scale": _bounds_scale,
			"override": workspace_bounds,
			"restore": workspace_bounds_restore,
		},
		"limits": {
			"tail_capacity": TAIL_CAPACITY,
			"logical_body_limit": LOGICAL_BODY_LIMIT,
			"native_retained_state_limit": NATIVE_RETAINED_STATE_LIMIT,
			"operand_cache_limit": OPERAND_CACHE_LIMIT,
		},
		"timing": {
			"ack_paced_elapsed_ms": float(
				_measurement_ack_finished_usec - _measurement_started_usec
			) / 1000.0,
			"including_final_publication_drain_ms": float(
				finished_usec - _measurement_started_usec
			) / 1000.0,
			"final_publication_drain": final_publication_drain,
		},
		"initial": initial,
		"before_final_publication_drain": before_drain,
		"final": final_snapshot,
		"summary": summary,
		"rows": _rows,
		"failures": _failures,
		"nonclaims": [
			"This is deterministic engine-capacity SPM, not human drawing speed.",
			"Headless timing is not rendered-editor FPS.",
			"The benchmark preserves the production default capsule CSG geometry path.",
			"Only the final publication drain includes collision readiness as a hard wait.",
		],
	}
	_write_report(_result_path, report)
	_write_report(LATEST_RESULT_PATH, report)
	_write_heartbeat(
		"done ok=%s strokes=%d spm=%.2f ack_max_ms=%.3f drain_ms=%.3f" % [
			str(report["ok"]),
			_rows.size(),
			float(summary.get("ack_paced_spm", 0.0)),
			float((summary.get(
				"release_to_native_ack_ms",
				{}
			) as Dictionary).get("max", 0.0)),
			float(final_publication_drain.get("elapsed_ms", 0.0)),
		]
	)
	_workspace.call("clear_stage_controller")
	_workspace.queue_free()
	_controller.queue_free()
	await process_frame
	quit(0 if bool(report["ok"]) else 1)


func _run_one_stroke(stroke_zero_index: int) -> Dictionary:
	var stroke_number := stroke_zero_index + 1
	var path := _build_fixture_path(stroke_zero_index)
	_include_path_in_fixture_bounds(path)
	var before := _native_diagnostics()
	var prior_expected_revision := int(before.get("expected_revision", 0))
	var before_request_count := int(before.get(
		"capsule_operand_request_count",
		0
	))
	var before_bake_count := int(before.get("capsule_operand_bake_count", 0))
	var action_started_usec := Time.get_ticks_usec()
	var begin_started_usec := action_started_usec
	var body_id := StringName(_controller.call(
		"begin_material_body_path",
		path[0],
		Vector3.FORWARD,
		Vector3.ZERO
	))
	var begin_finished_usec := Time.get_ticks_usec()
	if body_id == StringName():
		return _failed_stroke_row(
			stroke_number,
			"begin_rejected",
			action_started_usec
		)
	var extend_started_usec := Time.get_ticks_usec()
	var extended_count := 0
	for point_index in range(1, path.size()):
		if bool(_controller.call(
			"extend_material_body_path",
			path[point_index],
			true,
			Vector3.FORWARD,
			Vector3.ZERO
		)):
			extended_count += 1
	var extend_finished_usec := Time.get_ticks_usec()
	var body_before_finish := _find_body(body_id)
	var release_started_usec := Time.get_ticks_usec()
	var finish_returned := bool(_controller.call("finish_material_body_path"))
	var finish_returned_usec := Time.get_ticks_usec()
	var finish_result := _controller.call(
		"get_last_material_body_finish_result"
	) as Dictionary
	var body := _find_body(body_id)
	if body == null:
		body = body_before_finish
	# Commit assigns the layer ID and updates the timestamp. Both deliberately
	# participate in the presenter's exact operand cache key.
	var operand_signature := ""
	if body != null:
		operand_signature = String(_presenter.call(
			"_build_native_static_body_signature",
			body
		))
	var transition := _state.call(
		"get_bounded_history_transition"
	) as Dictionary
	var expected_transition_revision := int(transition.get("revision", -1))
	var expected_mode := _expected_mode_for_stroke(stroke_number)
	var wait := await _await_operand_and_native_ack(
		expected_mode,
		expected_transition_revision,
		prior_expected_revision,
		operand_signature,
		release_started_usec
	)
	var native_ack_usec := int(wait.get(
		"native_ack_usec",
		Time.get_ticks_usec()
	))
	var snapshot := _capture_snapshot()
	var committed_points := PackedVector3Array()
	var shape_kind := StringName()
	if body != null:
		committed_points = body.get("path_points") as PackedVector3Array
		shape_kind = StringName(body.get("shape_kind"))
	var request_delta := int(snapshot.get(
		"capsule_operand_request_count",
		0
	)) - before_request_count
	var bake_delta := int(snapshot.get(
		"capsule_operand_bake_count",
		0
	)) - before_bake_count
	var row_ok := (
		finish_returned
		and StringName(finish_result.get("status", StringName())) == &"committed"
		and extended_count == path.size() - 1
		and shape_kind == MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH
		and committed_points.size() == path.size()
		and request_delta == 1
		and bake_delta == 1
		and bool(wait.get("ok", false))
	)
	var failure := ""
	if not finish_returned:
		failure = "finish_returned_false"
	elif StringName(finish_result.get("status", StringName())) != &"committed":
		failure = "finish_status_%s" % String(finish_result.get("status", ""))
	elif extended_count != path.size() - 1:
		failure = "extend_count_mismatch"
	elif shape_kind != MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH:
		failure = "committed_shape_is_not_default_capsule"
	elif committed_points.size() != path.size():
		failure = "committed_path_sample_count_changed"
	elif request_delta != 1:
		failure = "operand_request_delta_%d" % request_delta
	elif bake_delta != 1:
		failure = "operand_bake_delta_%d" % bake_delta
	elif not bool(wait.get("ok", false)):
		failure = String(wait.get("failure", "native_ack_timeout"))
	return {
		"ok": row_ok,
		"failure": failure,
		"stroke": stroke_number,
		"fixture_kind": _fixture_path_kind(stroke_zero_index),
		"body_id": String(body_id),
		"shape_kind": String(shape_kind),
		"input_path_point_count": path.size(),
		"committed_path_point_count": committed_points.size(),
		"extended_point_count": extended_count,
		"finish_status": String(finish_result.get("status", "")),
		"expected_native_mode": expected_mode,
		"transition_revision": expected_transition_revision,
		"operand_signature": operand_signature,
		"request_delta": request_delta,
		"bake_delta": bake_delta,
		"action_started_usec": action_started_usec,
		"native_ack_usec": native_ack_usec,
		"begin_call_ms": float(begin_finished_usec - begin_started_usec) / 1000.0,
		"extend_calls_ms": float(
			extend_finished_usec - extend_started_usec
		) / 1000.0,
		"finish_call_ms": float(finish_returned_usec - release_started_usec) / 1000.0,
		"action_through_finish_ms": float(
			finish_returned_usec - action_started_usec
		) / 1000.0,
		"finish_return_to_native_ack_ms": float(
			native_ack_usec - finish_returned_usec
		) / 1000.0,
		"release_to_operand_ready_ms": float(wait.get(
			"release_to_operand_ready_ms",
			0.0
		)),
		"operand_ready_to_native_ack_ms": float(wait.get(
			"operand_ready_to_native_ack_ms",
			0.0
		)),
		"release_to_native_ack_ms": float(
			native_ack_usec - release_started_usec
		) / 1000.0,
		"cycle_start_to_native_ack_ms": float(
			native_ack_usec - action_started_usec
		) / 1000.0,
		"operand_internal_ready_ms": float(wait.get(
			"operand_internal_ready_ms",
			0.0
		)),
		"operand_bake_ms": float(wait.get("operand_bake_ms", 0.0)),
		"native_boolean_ms": float(wait.get("native_boolean_ms", 0.0)),
		"waited_process_frames": int(wait.get("waited_process_frames", 0)),
		"publication_pending_at_ack": bool(snapshot.get(
			"native_publication_pending",
			false
		)),
		"publication_revision_lag_at_ack": int(snapshot.get(
			"native_expected_revision",
			0
		)) - int(snapshot.get("native_published_revision", 0)),
		"snapshot": snapshot,
	}


func _await_operand_and_native_ack(
	expected_mode: String,
	expected_transition_revision: int,
	prior_expected_revision: int,
	operand_signature: String,
	release_started_usec: int
) -> Dictionary:
	var operand_ready_usec := 0
	var started_usec := Time.get_ticks_usec()
	for frame_index in range(OPERAND_ACK_FRAME_LIMIT + 1):
		var now_usec := Time.get_ticks_usec()
		var diagnostics := _native_diagnostics()
		var cache := _presenter.get("native_capsule_operand_cache") as Dictionary
		if (
			operand_ready_usec <= 0
			and not operand_signature.is_empty()
			and cache.has(operand_signature)
		):
			operand_ready_usec = now_usec
		var ack_ready := (
			operand_ready_usec > 0
			and int(diagnostics.get("bounded_transition_revision", -1))
			== expected_transition_revision
			and int(diagnostics.get("expected_revision", -1))
			> prior_expected_revision
			and not bool(_state.call(
				"has_pending_bounded_history_promotion"
			))
			and String(diagnostics.get("last_mode", "")) == expected_mode
			and int(diagnostics.get("fallback_count", -1)) == 0
			and int(diagnostics.get("capsule_operand_failure_count", -1)) == 0
			and String(diagnostics.get("last_failure_reason", "")).is_empty()
		)
		if ack_ready:
			return {
				"ok": true,
				"waited_process_frames": frame_index,
				"wait_elapsed_ms": float(now_usec - started_usec) / 1000.0,
				"operand_ready_usec": operand_ready_usec,
				"native_ack_usec": now_usec,
				"release_to_operand_ready_ms": float(
					operand_ready_usec - release_started_usec
				) / 1000.0,
				"operand_ready_to_native_ack_ms": float(
					now_usec - operand_ready_usec
				) / 1000.0,
				"operand_internal_ready_ms": float(diagnostics.get(
					"capsule_operand_last_ready_ms",
					0.0
				)),
				"operand_bake_ms": float(diagnostics.get(
					"capsule_operand_last_bake_ms",
					0.0
				)),
				"native_boolean_ms": float(diagnostics.get(
					"last_native_total_ms",
					0.0
				)),
				"diagnostics": diagnostics,
			}
		if frame_index >= OPERAND_ACK_FRAME_LIMIT:
			break
		await process_frame
	return {
		"ok": false,
		"failure": "operand_or_native_ack_timeout",
		"waited_process_frames": OPERAND_ACK_FRAME_LIMIT,
		"wait_elapsed_ms": float(Time.get_ticks_usec() - started_usec) / 1000.0,
		"operand_ready_usec": operand_ready_usec,
		"native_ack_usec": Time.get_ticks_usec(),
		"diagnostics": _native_diagnostics(),
		"snapshot": _capture_snapshot(),
	}


func _drain_final_publication() -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	for frame_index in range(PUBLICATION_DRAIN_FRAME_LIMIT + 1):
		var diagnostics := _native_diagnostics()
		var expected_revision := int(diagnostics.get("expected_revision", 0))
		var published_revision := int(diagnostics.get("published_revision", 0))
		var ready := (
			not bool(diagnostics.get("publication_pending", false))
			and published_revision == expected_revision
			and int(diagnostics.get("staged_revision", 0)) == 0
			and int(diagnostics.get("capsule_operand_pending_count", -1)) == 0
			and int(diagnostics.get("fallback_count", -1)) == 0
			and int(diagnostics.get("capsule_operand_failure_count", -1)) == 0
			and String(diagnostics.get("last_failure_reason", "")).is_empty()
		)
		if ready:
			return {
				"ok": true,
				"waited_process_physics_cycles": frame_index,
				"elapsed_ms": float(
					Time.get_ticks_usec() - started_usec
				) / 1000.0,
				"expected_revision": expected_revision,
				"published_revision": published_revision,
				"diagnostics": diagnostics,
			}
		if frame_index >= PUBLICATION_DRAIN_FRAME_LIMIT:
			break
		await process_frame
		await physics_frame
	return {
		"ok": false,
		"waited_process_physics_cycles": PUBLICATION_DRAIN_FRAME_LIMIT,
		"elapsed_ms": float(Time.get_ticks_usec() - started_usec) / 1000.0,
		"diagnostics": _native_diagnostics(),
	}


func _capture_snapshot() -> Dictionary:
	var presentation := _state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	var diagnostics := _native_diagnostics()
	return {
		"bounded_history_active": bool(presentation.get(
			"bounded_history_enabled",
			false
		)),
		"bounded_history_suspended_reason": String(presentation.get(
			"suspended_reason",
			StringName()
		)),
		"lifetime_operation_count": int(presentation.get(
			"lifetime_operation_count",
			-1
		)),
		"checkpoint_operation_count": int(presentation.get(
			"checkpoint_operation_count",
			-1
		)),
		"active_tail_layer_count": int((presentation.get(
			"active_tail_layers",
			[]
		) as Array).size()),
		"active_tail_body_count": int((presentation.get(
			"active_tail_bodies",
			[]
		) as Array).size()),
		"redo_tail_layer_count": int((presentation.get(
			"redo_tail_layers",
			[]
		) as Array).size()),
		"logical_body_count": int(presentation.get("logical_body_count", -1)),
		"pending_native_ack": bool(presentation.get(
			"pending_native_ack",
			false
		)),
		"authoring_pending_body_count": int(_state.call(
			"get_pending_material_body_count"
		)),
		"native_lifecycle": String(diagnostics.get("lifecycle", "")),
		"native_last_mode": String(diagnostics.get("last_mode", "")),
		"native_authoritative": bool(diagnostics.get("authoritative", false)),
		"native_publication_pending": bool(diagnostics.get(
			"publication_pending",
			false
		)),
		"native_expected_revision": int(diagnostics.get("expected_revision", -1)),
		"native_published_revision": int(diagnostics.get("published_revision", -1)),
		"native_staged_revision": int(diagnostics.get("staged_revision", -1)),
		"native_bounded_transition_revision": int(diagnostics.get(
			"bounded_transition_revision",
			-1
		)),
		"native_history_window_enabled": bool(diagnostics.get(
			"history_window_enabled",
			false
		)),
		"native_history_window_capacity": int(diagnostics.get(
			"history_window_capacity",
			-1
		)),
		"native_checkpoint_operation_count": int(diagnostics.get(
			"checkpoint_operation_count",
			-1
		)),
		"native_retained_state_count": int(diagnostics.get(
			"retained_state_count",
			-1
		)),
		"native_boolean_count": int(diagnostics.get("boolean_count", -1)),
		"native_promotion_count": int(diagnostics.get("promotion_count", -1)),
		"native_fallback_count": int(diagnostics.get("fallback_count", -1)),
		"native_last_failure_reason": String(diagnostics.get(
			"last_failure_reason",
			""
		)),
		"capsule_operand_request_count": int(diagnostics.get(
			"capsule_operand_request_count",
			-1
		)),
		"capsule_operand_cache_hit_count": int(diagnostics.get(
			"capsule_operand_cache_hit_count",
			-1
		)),
		"capsule_operand_bake_count": int(diagnostics.get(
			"capsule_operand_bake_count",
			-1
		)),
		"capsule_operand_failure_count": int(diagnostics.get(
			"capsule_operand_failure_count",
			-1
		)),
		"capsule_operand_pending_count": int(diagnostics.get(
			"capsule_operand_pending_count",
			-1
		)),
		"capsule_operand_cache_count": int(diagnostics.get(
			"capsule_operand_cache_count",
			-1
		)),
		"capsule_operand_superseded_count": int(diagnostics.get(
			"capsule_operand_superseded_count",
			0
		)),
		"capsule_operand_last_ready_ms": float(diagnostics.get(
			"capsule_operand_last_ready_ms",
			0.0
		)),
		"capsule_operand_last_bake_ms": float(diagnostics.get(
			"capsule_operand_last_bake_ms",
			0.0
		)),
		"last_native_total_ms": float(diagnostics.get(
			"last_native_total_ms",
			0.0
		)),
	}


func _validate_post_ack_invariants(snapshot: Dictionary, stroke_number: int) -> Dictionary:
	var failures: Array[String] = []
	var expected_checkpoint := maxi(stroke_number - TAIL_CAPACITY, 0)
	var expected_tail := mini(stroke_number, TAIL_CAPACITY)
	var expected_logical := expected_tail + (1 if expected_checkpoint > 0 else 0)
	_append_check_failure(
		failures,
		bool(snapshot.get("bounded_history_active", false)),
		"bounded_history_suspended"
	)
	_append_check_failure(
		failures,
		String(snapshot.get("bounded_history_suspended_reason", "")) in ["", "none"],
		"bounded_history_suspension_reason"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("lifetime_operation_count", -1)) == stroke_number,
		"lifetime_operation_count"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("checkpoint_operation_count", -1)) == expected_checkpoint,
		"checkpoint_operation_count"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("active_tail_layer_count", -1)) == expected_tail,
		"active_tail_layer_count"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("active_tail_body_count", -1)) == expected_tail,
		"active_tail_body_count"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("logical_body_count", -1)) == expected_logical,
		"logical_body_count"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("logical_body_count", -1)) <= LOGICAL_BODY_LIMIT,
		"logical_body_limit"
	)
	_append_check_failure(
		failures,
		not bool(snapshot.get("pending_native_ack", true)),
		"pending_native_ack"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("authoring_pending_body_count", -1)) == 0,
		"authoring_pending_body_count"
	)
	_append_check_failure(
		failures,
		bool(snapshot.get("native_history_window_enabled", false)),
		"native_history_window_disabled"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("native_history_window_capacity", -1)) == TAIL_CAPACITY,
		"native_history_window_capacity"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("native_retained_state_count", -1))
		<= NATIVE_RETAINED_STATE_LIMIT,
		"native_retained_state_limit"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("native_fallback_count", -1)) == 0,
		"native_fallback"
	)
	_append_check_failure(
		failures,
		String(snapshot.get("native_last_failure_reason", "")).is_empty(),
		"native_failure_reason"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("capsule_operand_failure_count", -1)) == 0,
		"capsule_operand_failure"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("capsule_operand_cache_count", -1)) <= OPERAND_CACHE_LIMIT,
		"capsule_operand_cache_limit"
	)
	return {
		"ok": failures.is_empty(),
		"failures": failures,
		"expected_checkpoint_operation_count": expected_checkpoint,
		"expected_tail_count": expected_tail,
		"expected_logical_body_count": expected_logical,
	}


func _validate_final_invariants(snapshot: Dictionary) -> Dictionary:
	var result := _validate_post_ack_invariants(snapshot, _stroke_count)
	var failures: Array[String] = result.get("failures", []) as Array[String]
	_append_check_failure(
		failures,
		not bool(snapshot.get("native_publication_pending", true)),
		"final_publication_pending"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("native_expected_revision", -1))
		== int(snapshot.get("native_published_revision", -2)),
		"final_publication_revision_lag"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("native_staged_revision", -1)) == 0,
		"final_staged_revision"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("capsule_operand_pending_count", -1)) == 0,
		"final_capsule_operand_pending"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("capsule_operand_request_count", -1)) == _stroke_count,
		"final_capsule_operand_request_count"
	)
	_append_check_failure(
		failures,
		int(snapshot.get("capsule_operand_bake_count", -1)) == _stroke_count,
		"final_capsule_operand_bake_count"
	)
	result["ok"] = failures.is_empty()
	result["failures"] = failures
	return result


func _build_fixture_path(stroke_zero_index: int) -> PackedVector3Array:
	var cell := _resolve_fixture_cell(stroke_zero_index)
	var center_y := FIXTURE_CENTER_Y_MIN + float(cell.x) * FIXTURE_GRID_PITCH_METERS
	var center_z := FIXTURE_CENTER_Z_MIN + float(cell.y) * FIXTURE_GRID_PITCH_METERS
	var path := PackedVector3Array()
	for point_index in range(FIXTURE_PATH_SAMPLE_COUNT):
		var ratio := float(point_index) / float(FIXTURE_PATH_SAMPLE_COUNT - 1)
		var point := Vector3(
			lerpf(FIXTURE_X_MIN, FIXTURE_X_MAX, ratio),
			center_y,
			center_z
		)
		match stroke_zero_index % 4:
			1:
				point.y += sin(ratio * PI) * 0.008
			2:
				point.z += sin(ratio * PI) * 0.006
			3:
				point.y += sin(ratio * TAU) * 0.006
				point.z += sin(ratio * PI) * 0.004
		path.append(point)
	if stroke_zero_index % 2 == 1:
		path.reverse()
	return path


func _resolve_fixture_cell(stroke_zero_index: int) -> Vector2i:
	var row := int(stroke_zero_index / FIXTURE_GRID_COLUMNS)
	var column_in_row := stroke_zero_index % FIXTURE_GRID_COLUMNS
	var column := (
		column_in_row
		if row % 2 == 0
		else FIXTURE_GRID_COLUMNS - 1 - column_in_row
	)
	return Vector2i(column, row)


func _fixture_path_kind(stroke_zero_index: int) -> String:
	match stroke_zero_index % 4:
		0:
			return "straight"
		1:
			return "planar_bend"
		2:
			return "spatial_bend"
		_:
			return "s_bend"


func _expected_mode_for_stroke(stroke_number: int) -> String:
	if stroke_number == 1:
		return "reset"
	if stroke_number <= TAIL_CAPACITY:
		return "append"
	return "promotion_append"


func _include_path_in_fixture_bounds(path: PackedVector3Array) -> void:
	for point: Vector3 in path:
		if not _fixture_bounds_initialized:
			_fixture_bounds = AABB(point, Vector3.ZERO)
			_fixture_bounds_initialized = true
		else:
			_fixture_bounds = _fixture_bounds.expand(point)


func _find_body(body_id: StringName) -> Resource:
	if body_id == StringName() or _state == null:
		return null
	for body_variant: Variant in _state.get("material_bodies") as Array:
		var body := body_variant as Resource
		if body != null and StringName(body.get("body_id")) == body_id:
			return body
	return null


func _native_diagnostics() -> Dictionary:
	return _presenter.call(
		"get_native_static_sync_diagnostics"
	) as Dictionary


func _apply_test_workspace_bounds_scale(scale: float) -> Dictionary:
	if _controller == null or not _controller.has_method("get_workspace_contract"):
		return {"ok": false, "reason": "workspace_contract_unavailable"}
	var contract := _controller.call("get_workspace_contract") as Resource
	if contract == null:
		return {"ok": false, "reason": "workspace_contract_missing"}
	var original_min := contract.get("local_min") as Vector3
	var original_max := contract.get("local_max") as Vector3
	var original_fit_size := float(contract.get("fit_size_meters"))
	var normalized_scale := clampf(scale, 1.0, 10.0)
	var center := (original_min + original_max) * 0.5
	var half_size := (original_max - original_min) * 0.5
	var effective_min := center - half_size * normalized_scale
	var effective_max := center + half_size * normalized_scale
	contract.set("local_min", effective_min)
	contract.set("local_max", effective_max)
	contract.set(
		"fit_size_meters",
		original_fit_size * normalized_scale
	)
	return {
		"ok": true,
		"applied": normalized_scale > 1.0,
		"scale": normalized_scale,
		"original_min": original_min,
		"original_max": original_max,
		"original_fit_size_meters": original_fit_size,
		"effective_min": effective_min,
		"effective_max": effective_max,
		"effective_fit_size_meters": float(contract.get("fit_size_meters")),
	}


func _restore_test_workspace_bounds(override: Dictionary) -> Dictionary:
	if _controller == null or not _controller.has_method("get_workspace_contract"):
		return {"ok": false, "reason": "workspace_contract_unavailable"}
	var contract := _controller.call("get_workspace_contract") as Resource
	if contract == null or not bool(override.get("ok", false)):
		return {"ok": false, "reason": "workspace_bounds_override_missing"}
	var original_min := override.get("original_min", Vector3.ZERO) as Vector3
	var original_max := override.get("original_max", Vector3.ZERO) as Vector3
	var original_fit_size := float(override.get("original_fit_size_meters", 6.0))
	contract.set("local_min", original_min)
	contract.set("local_max", original_max)
	contract.set("fit_size_meters", original_fit_size)
	return {
		"ok": (
			(contract.get("local_min") as Vector3).is_equal_approx(original_min)
			and (contract.get("local_max") as Vector3).is_equal_approx(original_max)
			and is_equal_approx(
				float(contract.get("fit_size_meters")),
				original_fit_size
			)
		),
		"restored_min": contract.get("local_min"),
		"restored_max": contract.get("local_max"),
		"restored_fit_size_meters": float(contract.get("fit_size_meters")),
	}


func _build_summary(source_rows: Array[Dictionary]) -> Dictionary:
	if source_rows.is_empty():
		return {}
	var head_count := mini(10, source_rows.size())
	var tail_count := mini(10, source_rows.size())
	var head_rows: Array[Dictionary] = []
	var tail_rows: Array[Dictionary] = []
	for index in range(head_count):
		head_rows.append(source_rows[index])
	for index in range(source_rows.size() - tail_count, source_rows.size()):
		tail_rows.append(source_rows[index])
	var ack_elapsed_seconds := maxf(
		float(_measurement_ack_finished_usec - _measurement_started_usec)
		/ 1000000.0,
		0.000001
	)
	var head_summary := _build_window_summary(head_rows)
	var tail_summary := _build_window_summary(tail_rows)
	return {
		"stroke_count": source_rows.size(),
		"ack_paced_spm": float(source_rows.size()) * 60.0 / ack_elapsed_seconds,
		"action_through_finish_ms": _metric_summary(
			source_rows,
			"action_through_finish_ms"
		),
		"finish_call_ms": _metric_summary(source_rows, "finish_call_ms"),
		"release_to_operand_ready_ms": _metric_summary(
			source_rows,
			"release_to_operand_ready_ms"
		),
		"operand_ready_to_native_ack_ms": _metric_summary(
			source_rows,
			"operand_ready_to_native_ack_ms"
		),
		"release_to_native_ack_ms": _metric_summary(
			source_rows,
			"release_to_native_ack_ms"
		),
		"cycle_start_to_native_ack_ms": _metric_summary(
			source_rows,
			"cycle_start_to_native_ack_ms"
		),
		"operand_internal_ready_ms": _metric_summary(
			source_rows,
			"operand_internal_ready_ms"
		),
		"operand_bake_ms": _metric_summary(source_rows, "operand_bake_ms"),
		"native_boolean_ms": _metric_summary(source_rows, "native_boolean_ms"),
		"head": head_summary,
		"tail": tail_summary,
		"head_to_tail": _compare_windows(head_summary, tail_summary),
		"max_publication_revision_lag_at_ack": int(_maximum_metric(
			source_rows,
			"publication_revision_lag_at_ack"
		)),
		"max_capsule_operand_pending_at_ack": _maximum_nested_metric(
			source_rows,
			"snapshot",
			"capsule_operand_pending_count"
		),
		"max_operand_cache_count": _maximum_nested_metric(
			source_rows,
			"snapshot",
			"capsule_operand_cache_count"
		),
		"max_logical_body_count": _maximum_nested_metric(
			source_rows,
			"snapshot",
			"logical_body_count"
		),
		"max_native_retained_state_count": _maximum_nested_metric(
			source_rows,
			"snapshot",
			"native_retained_state_count"
		),
		"last_four_completed_cycles": _last_rows(source_rows, 4),
	}


func _build_window_summary(source_rows: Array[Dictionary]) -> Dictionary:
	if source_rows.is_empty():
		return {}
	var elapsed_seconds := maxf(
		float(
			int(source_rows[source_rows.size() - 1].get("native_ack_usec", 0))
			- int(source_rows[0].get("action_started_usec", 0))
		) / 1000000.0,
		0.000001
	)
	return {
		"first_stroke": int(source_rows[0].get("stroke", 0)),
		"last_stroke": int(source_rows[source_rows.size() - 1].get("stroke", 0)),
		"stroke_count": source_rows.size(),
		"spm": float(source_rows.size()) * 60.0 / elapsed_seconds,
		"finish_call_ms": _metric_summary(source_rows, "finish_call_ms"),
		"release_to_operand_ready_ms": _metric_summary(
			source_rows,
			"release_to_operand_ready_ms"
		),
		"release_to_native_ack_ms": _metric_summary(
			source_rows,
			"release_to_native_ack_ms"
		),
		"cycle_start_to_native_ack_ms": _metric_summary(
			source_rows,
			"cycle_start_to_native_ack_ms"
		),
		"native_boolean_ms": _metric_summary(source_rows, "native_boolean_ms"),
	}


func _compare_windows(head: Dictionary, tail: Dictionary) -> Dictionary:
	var head_ack := head.get("release_to_native_ack_ms", {}) as Dictionary
	var tail_ack := tail.get("release_to_native_ack_ms", {}) as Dictionary
	var head_finish := head.get("finish_call_ms", {}) as Dictionary
	var tail_finish := tail.get("finish_call_ms", {}) as Dictionary
	return {
		"spm_ratio_tail_over_head": _safe_ratio(
			float(tail.get("spm", 0.0)),
			float(head.get("spm", 0.0))
		),
		"ack_p95_ratio_tail_over_head": _safe_ratio(
			float(tail_ack.get("p95", 0.0)),
			float(head_ack.get("p95", 0.0))
		),
		"ack_max_ratio_tail_over_head": _safe_ratio(
			float(tail_ack.get("max", 0.0)),
			float(head_ack.get("max", 0.0))
		),
		"finish_p95_ratio_tail_over_head": _safe_ratio(
			float(tail_finish.get("p95", 0.0)),
			float(head_finish.get("p95", 0.0))
		),
		"finish_max_ratio_tail_over_head": _safe_ratio(
			float(tail_finish.get("max", 0.0)),
			float(head_finish.get("max", 0.0))
		),
	}


func _metric_summary(source_rows: Array[Dictionary], key: String) -> Dictionary:
	var values: Array[float] = []
	for row: Dictionary in source_rows:
		values.append(float(row.get(key, 0.0)))
	if values.is_empty():
		return {}
	values.sort()
	var total := 0.0
	for value: float in values:
		total += value
	return {
		"count": values.size(),
		"min": values[0],
		"mean": total / float(values.size()),
		"p50": _nearest_rank(values, 0.50),
		"p95": _nearest_rank(values, 0.95),
		"p99": _nearest_rank(values, 0.99),
		"max": values[values.size() - 1],
		"total": total,
	}


func _nearest_rank(sorted_values: Array[float], fraction: float) -> float:
	var index := clampi(
		ceili(float(sorted_values.size()) * fraction) - 1,
		0,
		sorted_values.size() - 1
	)
	return sorted_values[index]


func _maximum_metric(source_rows: Array[Dictionary], key: String) -> float:
	var maximum := 0.0
	for row: Dictionary in source_rows:
		maximum = maxf(maximum, float(row.get(key, 0.0)))
	return maximum


func _maximum_nested_metric(
	source_rows: Array[Dictionary],
	nested_key: String,
	metric_key: String
) -> int:
	var maximum := 0
	for row: Dictionary in source_rows:
		var nested := row.get(nested_key, {}) as Dictionary
		maximum = maxi(maximum, int(nested.get(metric_key, 0)))
	return maximum


func _last_rows(source_rows: Array[Dictionary], count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var first_index := maxi(source_rows.size() - count, 0)
	for index in range(first_index, source_rows.size()):
		result.append(source_rows[index])
	return result


func _safe_ratio(numerator: float, denominator: float) -> float:
	if denominator <= 0.0:
		return 0.0
	return numerator / denominator


func _append_check_failure(
	failures: Array[String],
	condition: bool,
	failure: String
) -> void:
	if not condition and not failures.has(failure):
		failures.append(failure)


func _failed_stroke_row(
	stroke_number: int,
	failure: String,
	action_started_usec: int
) -> Dictionary:
	var now_usec := Time.get_ticks_usec()
	return {
		"ok": false,
		"failure": failure,
		"stroke": stroke_number,
		"action_started_usec": action_started_usec,
		"native_ack_usec": now_usec,
		"cycle_start_to_native_ack_ms": float(
			now_usec - action_started_usec
		) / 1000.0,
		"snapshot": _capture_snapshot(),
	}


func _record_failure(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish_setup_failure(message: String) -> void:
	_record_failure(message)
	var report := {
		"schema": "forge_v2_default_capsule_sustained",
		"schema_version": 1,
		"ok": false,
		"requested_stroke_count": _stroke_count,
		"completed_stroke_count": 0,
		"failures": _failures,
	}
	if _result_path.is_empty():
		_result_path = LATEST_RESULT_PATH
	_write_report(_result_path, report)
	_write_report(LATEST_RESULT_PATH, report)
	push_error(message)
	quit(1)


func _write_report(path: String, report: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return
	file.store_string(JSON.stringify(report, "  ", false) + "\n")
	file.close()


func _write_heartbeat(message: String) -> void:
	var file := FileAccess.open(LATEST_HEARTBEAT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(message + "\n")
	file.close()


func _build_run_id() -> String:
	var timestamp := Time.get_datetime_string_from_system(false, true)
	return timestamp.replace("-", "").replace(":", "").replace("T", "_")


func _read_int_environment(
	name: String,
	fallback: int,
	minimum: int,
	maximum: int
) -> int:
	var raw := OS.get_environment(name).strip_edges()
	if raw.is_empty() or not raw.is_valid_int():
		return fallback
	return clampi(int(raw), minimum, maximum)


func _read_float_environment(
	name: String,
	fallback: float,
	minimum: float,
	maximum: float
) -> float:
	var raw := OS.get_environment(name).strip_edges()
	if raw.is_empty() or not raw.is_valid_float():
		return fallback
	return clampf(float(raw), minimum, maximum)
