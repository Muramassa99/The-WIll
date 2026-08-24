extends SceneTree

const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const ForgeV2WorkspacePreviewScript = preload(
	"res://runtime/forge_v2/forge_v2_workspace_preview.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const STROKE_COUNT := 30
const GRID_COLUMNS := 6
const GRID_SPACING_METERS := 0.16
const STROKE_LENGTH_METERS := 0.075
const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "forge_v2_default_capsule_fallback_baseline.json"
)

var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var controller := ForgeV2StageControllerScript.new() as Node
	controller.name = "DefaultCapsuleFallbackBaselineController"
	root.add_child(controller)
	var workspace := ForgeV2WorkspacePreviewScript.new() as Node3D
	workspace.name = "DefaultCapsuleFallbackBaselineWorkspace"
	root.add_child(workspace)
	await process_frame
	workspace.call("bind_stage_controller", controller)
	await _settle_presenter()
	var presenter := workspace.get("volume_preview_presenter") as Node3D
	var state := controller.call("get_active_authoring_state") as Resource
	if presenter == null or state == null:
		_finish_failure("production workspace presenter fixture was incomplete")
		return

	controller.call("set_active_tool_id", &"tool_volume_stroke")
	controller.call("set_active_primitive_id", &"primitive_blob")
	controller.call(
		"set_active_operation_mode",
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
	)
	controller.call(
		"set_placement_policy",
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	)
	await _settle_presenter()

	var initial := _capture_state_snapshot(state, presenter)
	var initial_seed_count := int(initial.get("seed_body_count", 0))
	var finish_usec_values: Array[float] = []
	var release_to_presented_usec_values: Array[float] = []
	var pending_failure_count := 0
	var commit_failure_count := 0
	var bounded_active_stroke_indices: Array[int] = []
	var native_history_window_stroke_indices: Array[int] = []
	var native_authoritative_stroke_indices: Array[int] = []
	var checkpoint_nonzero_stroke_indices: Array[int] = []

	for stroke_index in range(STROKE_COUNT):
		var start := _stroke_start(stroke_index)
		var endpoint := start + Vector3(STROKE_LENGTH_METERS, 0.0, 0.0)
		var begin_started_usec := Time.get_ticks_usec()
		var body_id := StringName(controller.call(
			"begin_material_body_path",
			start,
			Vector3.FORWARD,
			Vector3.ZERO
		))
		var begin_elapsed_usec := Time.get_ticks_usec() - begin_started_usec
		var extend_started_usec := Time.get_ticks_usec()
		var extended := bool(controller.call(
			"extend_material_body_path",
			endpoint,
			true,
			Vector3.FORWARD,
			Vector3.ZERO
		))
		var extend_elapsed_usec := Time.get_ticks_usec() - extend_started_usec
		var body_before_finish := _find_body(state, body_id)
		var ready_before_finish := (
			bool(state.call("is_material_body_commit_ready", body_id))
			if body_id != StringName()
			else false
		)
		var release_started_usec := Time.get_ticks_usec()
		var finish_returned := bool(controller.call("finish_material_body_path"))
		var finish_elapsed_usec := Time.get_ticks_usec() - release_started_usec
		var finish_result := controller.call(
			"get_last_material_body_finish_result"
		) as Dictionary
		await _settle_presenter()
		var release_to_presented_usec := (
			Time.get_ticks_usec() - release_started_usec
		)
		finish_usec_values.append(float(finish_elapsed_usec))
		release_to_presented_usec_values.append(float(
			release_to_presented_usec
		))

		var snapshot := _capture_state_snapshot(state, presenter)
		var body_after_finish := _find_body(state, body_id)
		var committed := (
			body_after_finish != null
			and StringName(body_after_finish.get("committed_layer_id"))
			!= StringName()
		)
		var pending_count := int(snapshot.get("pending_body_count", -1))
		if pending_count > 0:
			pending_failure_count += 1
		if not committed:
			commit_failure_count += 1
		if bool(snapshot.get("bounded_history_active", false)):
			bounded_active_stroke_indices.append(stroke_index + 1)
		if bool(snapshot.get("native_history_window_enabled", false)):
			native_history_window_stroke_indices.append(stroke_index + 1)
		if bool(snapshot.get("native_authoritative", false)):
			native_authoritative_stroke_indices.append(stroke_index + 1)
		if int(snapshot.get("checkpoint_operation_count", 0)) > 0:
			checkpoint_nonzero_stroke_indices.append(stroke_index + 1)

		var row := {
			"stroke_index": stroke_index + 1,
			"body_id": String(body_id),
			"body_shape_kind": (
				String(body_before_finish.get("shape_kind"))
				if body_before_finish != null
				else ""
			),
			"path_point_count": (
				(body_before_finish.get("path_points") as PackedVector3Array).size()
				if body_before_finish != null
				else 0
			),
			"begin_succeeded": body_id != StringName(),
			"extend_succeeded": extended,
			"ready_before_finish": ready_before_finish,
			"finish_returned": finish_returned,
			"finish_status": String(finish_result.get(
				"status",
				StringName()
			)),
			"committed": committed,
			"reported_pending": bool(finish_result.get("pending", false)),
			"reported_removed": bool(finish_result.get("removed", false)),
			"begin_elapsed_usec": begin_elapsed_usec,
			"extend_elapsed_usec": extend_elapsed_usec,
			"finish_elapsed_usec": finish_elapsed_usec,
			"finish_elapsed_ms": float(finish_elapsed_usec) / 1000.0,
			"release_to_presented_usec": release_to_presented_usec,
			"release_to_presented_ms": (
				float(release_to_presented_usec) / 1000.0
			),
		}
		row.merge(snapshot, true)
		_rows.append(row)

	var final_snapshot := _capture_state_snapshot(state, presenter)
	var linear_user_body_growth := true
	var linear_layer_growth := true
	var capsule_shape_only := true
	var all_finish_statuses_committed := true
	for row: Dictionary in _rows:
		var expected_count := int(row.get("stroke_index", 0))
		linear_user_body_growth = (
			linear_user_body_growth
			and int(row.get("user_body_count", -1)) == expected_count
		)
		linear_layer_growth = (
			linear_layer_growth
			and int(row.get("committed_layer_count", -1)) == expected_count
		)
		capsule_shape_only = (
			capsule_shape_only
			and StringName(row.get("body_shape_kind", StringName()))
			== ForgeV2MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH
		)
		all_finish_statuses_committed = (
			all_finish_statuses_committed
			and StringName(row.get("finish_status", StringName()))
			== &"committed"
		)

	var first_window := finish_usec_values.slice(0, 5)
	var last_window := finish_usec_values.slice(
		maxi(finish_usec_values.size() - 5, 0)
	)
	var timing_summary := {
		"finish_ms": _timing_summary(finish_usec_values),
		"release_to_presented_ms": _timing_summary(
			release_to_presented_usec_values
		),
		"finish_first_five_mean_ms": _mean(first_window) / 1000.0,
		"finish_last_five_mean_ms": _mean(last_window) / 1000.0,
		"finish_last_to_first_five_ratio": (
			_mean(last_window) / maxf(_mean(first_window), 1.0)
		),
		"finish_linear_slope_ms_per_stroke": (
			_linear_slope(finish_usec_values) / 1000.0
		),
	}
	var observations := {
		"bounded_history_active_initially": bool(initial.get(
			"bounded_history_active",
			false
		)),
		"bounded_history_active_after_release_indices": (
			bounded_active_stroke_indices
		),
		"first_suspension_reason": (
			String(_rows[0].get("bounded_suspended_reason", ""))
			if not _rows.is_empty()
			else ""
		),
		"native_history_window_enabled_indices": (
			native_history_window_stroke_indices
		),
		"native_authoritative_indices": native_authoritative_stroke_indices,
		"checkpoint_nonzero_indices": checkpoint_nonzero_stroke_indices,
		"linear_user_body_growth": linear_user_body_growth,
		"linear_committed_layer_growth": linear_layer_growth,
		"active_tail_exceeds_bounded_capacity": (
			int(final_snapshot.get("active_tail_layer_count", 0))
			> int(final_snapshot.get("bounded_tail_capacity", 0))
		),
		"final_active_tail_layer_count": int(final_snapshot.get(
			"active_tail_layer_count",
			-1
		)),
		"final_bounded_tail_capacity": int(final_snapshot.get(
			"bounded_tail_capacity",
			-1
		)),
		"final_csg_zone_count": int(final_snapshot.get(
			"csg_zone_count",
			-1
		)),
		"final_csg_snapshot_body_count": int(final_snapshot.get(
			"csg_snapshot_body_count",
			-1
		)),
		"final_native_retained_state_count": int(final_snapshot.get(
			"native_retained_state_count",
			-1
		)),
		"pending_failure_row_count": pending_failure_count,
		"commit_failure_count": commit_failure_count,
	}

	if not capsule_shape_only:
		_failures.append("non_capsule_shape_observed")
	if not all_finish_statuses_committed:
		_failures.append("finish_did_not_commit")
	if not linear_user_body_growth:
		_failures.append("user_body_growth_was_not_one_per_stroke")
	if not linear_layer_growth:
		_failures.append("layer_growth_was_not_one_per_stroke")
	if pending_failure_count > 0:
		_failures.append("pending_body_observed_after_release")
	if int(final_snapshot.get("user_body_count", -1)) != STROKE_COUNT:
		_failures.append("final_user_body_count_mismatch")
	if int(final_snapshot.get("committed_layer_count", -1)) != STROKE_COUNT:
		_failures.append("final_layer_count_mismatch")

	var report := {
		"schema": "forge_v2_default_capsule_fallback_baseline",
		"schema_version": 1,
		"ok": _failures.is_empty(),
		"contract": {
			"stroke_count": STROKE_COUNT,
			"shape_kind": String(
				ForgeV2MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH
			),
			"operation_mode": String(
				ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
			),
			"placement_policy": String(
				ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
			),
			"real_workspace_presenter": true,
			"settle_sequence": "process_frame, physics_frame, process_frame",
		},
		"initial": initial,
		"initial_seed_body_count": initial_seed_count,
		"final": final_snapshot,
		"observations": observations,
		"timing": timing_summary,
		"rows": _rows,
		"failures": _failures,
	}
	_write_report(report)
	workspace.call("clear_stage_controller")
	workspace.queue_free()
	controller.queue_free()
	await process_frame
	if not _failures.is_empty():
		push_error("Default capsule fallback baseline failed: %s" % "; ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _capture_state_snapshot(state: Resource, presenter: Node3D) -> Dictionary:
	var bounded := state.call("get_bounded_presentation_descriptor") as Dictionary
	var transition := state.call("get_bounded_history_transition") as Dictionary
	var native := presenter.call(
		"get_native_static_sync_diagnostics"
	) as Dictionary
	var csg := presenter.call("get_csg_static_sync_diagnostics") as Dictionary
	var zones := presenter.get("csg_static_zone_nodes") as Dictionary
	var csg_snapshot := presenter.get(
		"csg_static_body_order_snapshot"
	) as Array
	var native_snapshot := presenter.get(
		"native_static_body_order_snapshot"
	) as Array
	return {
		"material_body_count": int(state.call("get_material_body_count")),
		"seed_body_count": int(state.call("get_seed_material_body_count")),
		"user_body_count": int(state.call("get_user_material_body_count")),
		"pending_body_count": int(state.call("get_pending_material_body_count")),
		"committed_layer_count": int(state.call("get_committed_layer_count")),
		"active_tail_layer_count": int(state.call("get_active_tail_layer_count")),
		"bounded_history_active": bool(bounded.get(
			"bounded_history_enabled",
			false
		)),
		"bounded_history_configured": bool(bounded.get(
			"bounded_history_configured_enabled",
			false
		)),
		"bounded_suspended_reason": String(bounded.get(
			"suspended_reason",
			StringName()
		)),
		"bounded_tail_capacity": int(bounded.get("tail_capacity", -1)),
		"bounded_lifetime_operation_count": int(bounded.get(
			"lifetime_operation_count",
			-1
		)),
		"bounded_logical_body_count": int(bounded.get(
			"logical_body_count",
			-1
		)),
		"checkpoint_operation_count": int(bounded.get(
			"checkpoint_operation_count",
			0
		)),
		"bounded_transition_kind": String(transition.get(
			"kind",
			StringName()
		)),
		"bounded_transition_revision": int(transition.get("revision", -1)),
		"bounded_pending_native_ack": bool(bounded.get(
			"pending_native_ack",
			false
		)),
		"native_lifecycle": String(native.get("lifecycle", "unavailable")),
		"native_last_mode": String(native.get("last_mode", "unavailable")),
		"native_authoritative": bool(native.get("authoritative", false)),
		"native_state_initialized": bool(native.get("state_initialized", false)),
		"native_history_window_enabled": bool(native.get(
			"history_window_enabled",
			false
		)),
		"native_prefix_body_count": int(native.get("prefix_body_count", -1)),
		"native_snapshot_body_count": native_snapshot.size(),
		"native_append_count": int(native.get("append_count", 0)),
		"native_boolean_count": int(native.get("boolean_count", 0)),
		"native_export_count": int(native.get("export_count", 0)),
		"native_publication_count": int(native.get("publication_count", 0)),
		"native_fallback_count": int(native.get("fallback_count", 0)),
		"native_retained_state_count": int(native.get(
			"retained_state_count",
			0
		)),
		"native_output_vertices": int(native.get("output_vertices", 0)),
		"native_output_triangles": int(native.get("output_triangles", 0)),
		"native_last_failure_reason": String(native.get(
			"last_failure_reason",
			""
		)),
		"csg_last_mode": String(csg.get("last_mode", "unavailable")),
		"csg_no_op_count": int(csg.get("no_op_count", 0)),
		"csg_incremental_append_count": int(csg.get(
			"incremental_append_count",
			0
		)),
		"csg_full_rebuild_count": int(csg.get("full_rebuild_count", 0)),
		"csg_last_fallback_reason": String(csg.get(
			"last_fallback_reason",
			""
		)),
		"csg_zone_count": zones.size(),
		"csg_snapshot_body_count": csg_snapshot.size(),
		"static_memory_bytes": int(Performance.get_monitor(
			Performance.MEMORY_STATIC
		)),
	}


func _stroke_start(stroke_index: int) -> Vector3:
	var column := stroke_index % GRID_COLUMNS
	var row := stroke_index / GRID_COLUMNS
	return Vector3(
		-0.48 + float(column) * GRID_SPACING_METERS,
		-0.32 + float(row) * GRID_SPACING_METERS,
		0.0
	)


func _find_body(state: Resource, body_id: StringName) -> Resource:
	if state == null or body_id == StringName():
		return null
	for body_variant: Variant in state.get("material_bodies") as Array:
		if not body_variant is Resource:
			continue
		var body := body_variant as Resource
		if StringName(body.get("body_id")) == body_id:
			return body
	return null


func _settle_presenter() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _timing_summary(usec_values: Array[float]) -> Dictionary:
	if usec_values.is_empty():
		return {}
	return {
		"sample_count": usec_values.size(),
		"mean": _mean(usec_values) / 1000.0,
		"p50": _percentile(usec_values, 0.50) / 1000.0,
		"p95": _percentile(usec_values, 0.95) / 1000.0,
		"max": _percentile(usec_values, 1.0) / 1000.0,
	}


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(
		int(ceil(float(sorted.size()) * clampf(fraction, 0.0, 1.0))) - 1,
		0,
		sorted.size() - 1
	)
	return float(sorted[index])


func _linear_slope(values: Array[float]) -> float:
	if values.size() < 2:
		return 0.0
	var x_mean := float(values.size() - 1) * 0.5
	var y_mean := _mean(values)
	var numerator := 0.0
	var denominator := 0.0
	for index in range(values.size()):
		var x_delta := float(index) - x_mean
		numerator += x_delta * (values[index] - y_mean)
		denominator += x_delta * x_delta
	return numerator / denominator if denominator > 0.0 else 0.0


func _finish_failure(message: String) -> void:
	_failures.append(message)
	_write_report({
		"schema": "forge_v2_default_capsule_fallback_baseline",
		"schema_version": 1,
		"ok": false,
		"failures": _failures,
	})
	push_error(message)
	quit(1)


func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % RESULT_PATH)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
