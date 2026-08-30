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
const MeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)

const EXTENSION_PATH := (
	"res://native/forge_v2_manifold/forge_v2_manifold.gdextension"
)
const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_default_capsule_bounded_integration.json"
)
const MATERIAL_VARIANT_ID := &"mat_iron_gray"
const ADD_STROKE_COUNT := 20
const TAIL_CAPACITY := 5
const EXPECTED_CHECKPOINT_AT_N20 := 15
const WAIT_FRAME_LIMIT := 240
const OPERAND_SURFACE_LIMIT_METERS := 0.000001
const OPERAND_VOLUME_LIMIT_CUBIC_METERS := 0.000000001

var _controller: Node = null
var _workspace: Node3D = null
var _presenter: Node3D = null
var _state: Resource = null
var _failures: Array[String] = []
var _deposit_rows: Array[Dictionary] = []
var _navigation_rows: Array[Dictionary] = []
var _bodies: Array[Resource] = []
var _stroke_endpoints: Array[Vector3] = []
var _stroke_end_directions: Array[Vector3] = []
var _forced_timeout_controller: Node = null
var _forced_timeout_events: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var extension_resource := load(EXTENSION_PATH)
	if (
		extension_resource == null
		or not ClassDB.class_exists(&"ForgeV2ManifoldBoolean")
	):
		_finish_fixture_failure("native ForgeV2ManifoldBoolean is unavailable")
		return

	_controller = StageControllerScript.new()
	_controller.name = "DefaultCapsuleBoundedIntegrationController"
	root.add_child(_controller)
	_workspace = WorkspacePreviewScript.new()
	_workspace.name = "DefaultCapsuleBoundedIntegrationWorkspace"
	root.add_child(_workspace)
	await process_frame
	_workspace.call("bind_stage_controller", _controller)
	await process_frame
	await physics_frame
	await process_frame
	_presenter = _workspace.get("volume_preview_presenter") as Node3D
	_state = _controller.call("get_active_authoring_state") as Resource
	if _presenter == null or _state == null:
		_finish_fixture_failure("real controller/workspace presenter fixture is incomplete")
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
	await process_frame

	var initial := _capture_contract_snapshot()
	_expect(
		int(_state.call("get_user_material_body_count")) == 0,
		"fresh_state_contains_user_material"
	)
	_expect(
		int(_state.call("get_committed_layer_count")) == 0,
		"fresh_state_contains_committed_layers"
	)
	_expect(
		bool(initial.get("bounded_history_active", false)),
		"bounded_history_not_active_in_fresh_state"
	)

	for stroke_index in range(ADD_STROKE_COUNT):
		var row := await _deposit_default_capsule(stroke_index)
		_deposit_rows.append(row)

	var n20 := _capture_contract_snapshot()
	var n20_controller_summary := _controller.call(
		"get_status_summary"
	) as Dictionary
	var n20_action_history := n20_controller_summary.get(
		"action_history",
		{}
	) as Dictionary
	_expect(
		int(n20.get("lifetime_operation_count", -1)) == ADD_STROKE_COUNT,
		"n20_lifetime_operation_count_mismatch"
	)
	_expect(
		int(n20.get("checkpoint_operation_count", -1))
		== EXPECTED_CHECKPOINT_AT_N20,
		"n20_checkpoint_is_not_15"
	)
	_expect(
		int(n20.get("active_tail_layer_count", -1)) == TAIL_CAPACITY,
		"n20_tail_is_not_5"
	)
	_expect(
		int(n20.get("active_tail_body_count", -1)) == TAIL_CAPACITY,
		"n20_tail_body_count_is_not_5"
	)
	_expect(
		int(n20.get("logical_body_count", -1)) == 1 + TAIL_CAPACITY,
		"n20_logical_body_count_is_not_checkpoint_plus_five"
	)
	_expect(
		int(n20.get("redo_tail_layer_count", -1)) == 0,
		"n20_redo_tail_not_empty"
	)
	_expect(
		int(n20_controller_summary.get("action_undo_count", -1))
		== TAIL_CAPACITY,
		"action_history_did_not_stop_at_acknowledged_checkpoint_floor"
	)
	_expect(
		int(n20_action_history.get("checkpoint_prune_count", -1))
		== EXPECTED_CHECKPOINT_AT_N20,
		"action_history_checkpoint_prune_count_mismatch"
	)
	_expect(
		int(n20.get("capsule_operand_request_count", -1))
		== ADD_STROKE_COUNT,
		"n20_capsule_request_count_mismatch"
	)
	_expect(
		int(n20.get("capsule_operand_bake_count", -1))
		== ADD_STROKE_COUNT,
		"n20_capsule_bake_count_mismatch"
	)
	_assert_steady_native_contract(n20, "n20")

	# A held Undo gesture may cross several committed CSG records. Its single
	# Redo batch must advance the logical and native cursors once per record,
	# rather than publishing only the final overwritten transition.
	var batch_diagnostics_before := _native_diagnostics()
	var batch_prior_revision := int(batch_diagnostics_before.get(
		"published_revision",
		0
	))
	_expect(
		bool(_controller.call("begin_action_history_undo_batch")),
		"action_batch_begin_failed"
	)
	_expect(
		bool(_controller.call("undo_latest_action")),
		"action_batch_first_undo_failed"
	)
	_expect(
		bool(_controller.call("undo_latest_action")),
		"action_batch_second_undo_failed"
	)
	_expect(
		bool(_controller.call("end_action_history_undo_batch")),
		"action_batch_end_failed"
	)
	var batch_undo_ready := await _await_native_transition(
		"undo",
		batch_prior_revision,
		StringName()
	)
	var batch_undo_snapshot := _capture_contract_snapshot()
	var batch_undo_summary := _controller.call("get_status_summary") as Dictionary
	var batch_diagnostics_after_undo := _native_diagnostics()
	_expect(bool(batch_undo_ready.get("ok", false)), "action_batch_undo_not_ready")
	_expect(
		int(batch_undo_snapshot.get("active_tail_layer_count", -1))
		== TAIL_CAPACITY - 2,
		"action_batch_undo_tail_count_mismatch"
	)
	_expect(
		int(batch_undo_summary.get("action_undo_count", -1))
		== TAIL_CAPACITY - 2,
		"action_batch_undo_journal_count_mismatch"
	)
	_expect(
		int(batch_undo_summary.get("action_redo_count", -1)) == 1,
		"held_undo_was_not_one_redo_batch"
	)
	_expect(
		int(batch_diagnostics_after_undo.get("undo_count", -1))
		== int(batch_diagnostics_before.get("undo_count", 0)) + 2,
		"held_undo_did_not_move_native_cursor_twice"
	)

	var batch_redo_prior_revision := int(batch_diagnostics_after_undo.get(
		"published_revision",
		0
	))
	_expect(
		bool(_controller.call("redo_latest_action")),
		"action_batch_redo_failed"
	)
	var batch_redo_ready := await _await_native_transition(
		"redo",
		batch_redo_prior_revision,
		StringName()
	)
	var batch_redo_snapshot := _capture_contract_snapshot()
	var batch_redo_summary := _controller.call("get_status_summary") as Dictionary
	var batch_diagnostics_after_redo := _native_diagnostics()
	_expect(bool(batch_redo_ready.get("ok", false)), "action_batch_redo_not_ready")
	_expect(
		int(batch_redo_snapshot.get("active_tail_layer_count", -1))
		== TAIL_CAPACITY,
		"action_batch_redo_tail_count_mismatch"
	)
	_expect(
		int(batch_redo_snapshot.get("redo_tail_layer_count", -1)) == 0,
		"action_batch_redo_stack_not_empty"
	)
	_expect(
		int(batch_redo_summary.get("action_undo_count", -1)) == TAIL_CAPACITY
		and int(batch_redo_summary.get("action_redo_count", -1)) == 0,
		"action_batch_redo_journal_not_restored"
	)
	_expect(
		int(batch_diagnostics_after_redo.get("redo_count_total", -1))
		== int(batch_diagnostics_after_undo.get("redo_count_total", 0)) + 2,
		"batched_redo_did_not_move_native_cursor_twice"
	)
	_assert_steady_native_contract(batch_redo_snapshot, "action_batch_redo")

	for undo_index in range(TAIL_CAPACITY):
		var prior_revision := int(_native_diagnostics().get(
			"published_revision",
			0
		))
		var transition_started_usec := Time.get_ticks_usec()
		var changed := bool(_state.call("undo_latest_layer"))
		_expect(changed, "undo_%d_failed" % (undo_index + 1))
		_controller.call("_emit_state_changed")
		var ready := await _await_native_transition(
			"undo",
			prior_revision,
			StringName()
		)
		var snapshot := _capture_contract_snapshot()
		_navigation_rows.append({
			"action": "undo_%d" % (undo_index + 1),
			"ready": ready,
			"elapsed_ms": float(
				Time.get_ticks_usec() - transition_started_usec
			) / 1000.0,
			"snapshot": snapshot,
		})
		_expect(bool(ready.get("ok", false)), "undo_publication_not_ready")
		_expect(
			int(snapshot.get("checkpoint_operation_count", -1))
			== EXPECTED_CHECKPOINT_AT_N20,
			"undo_changed_checkpoint"
		)
		_expect(
			int(snapshot.get("active_tail_layer_count", -1))
			== TAIL_CAPACITY - undo_index - 1,
			"undo_tail_count_mismatch_%d" % (undo_index + 1)
		)
		_expect(
			int(snapshot.get("redo_tail_layer_count", -1))
			== undo_index + 1,
			"undo_redo_count_mismatch_%d" % (undo_index + 1)
		)
		_assert_steady_native_contract(snapshot, "undo_%d" % (undo_index + 1))

	var sixth_undo_succeeded := bool(_state.call("undo_latest_layer"))
	_expect(not sixth_undo_succeeded, "sixth_undo_exceeded_five_step_window")

	for redo_index in range(TAIL_CAPACITY):
		var prior_revision := int(_native_diagnostics().get(
			"published_revision",
			0
		))
		var transition_started_usec := Time.get_ticks_usec()
		var changed := bool(_state.call("redo_latest_layer"))
		_expect(changed, "redo_%d_failed" % (redo_index + 1))
		_controller.call("_emit_state_changed")
		var ready := await _await_native_transition(
			"redo",
			prior_revision,
			StringName()
		)
		var snapshot := _capture_contract_snapshot()
		_navigation_rows.append({
			"action": "redo_%d" % (redo_index + 1),
			"ready": ready,
			"elapsed_ms": float(
				Time.get_ticks_usec() - transition_started_usec
			) / 1000.0,
			"snapshot": snapshot,
		})
		_expect(bool(ready.get("ok", false)), "redo_publication_not_ready")
		_expect(
			int(snapshot.get("active_tail_layer_count", -1))
			== redo_index + 1,
			"redo_tail_count_mismatch_%d" % (redo_index + 1)
		)
		_expect(
			int(snapshot.get("redo_tail_layer_count", -1))
			== TAIL_CAPACITY - redo_index - 1,
			"redo_stack_count_mismatch_%d" % (redo_index + 1)
		)
		_assert_steady_native_contract(snapshot, "redo_%d" % (redo_index + 1))

	for branch_undo_index in range(2):
		var prior_revision := int(_native_diagnostics().get(
			"published_revision",
			0
		))
		var changed := bool(_state.call("undo_latest_layer"))
		_expect(changed, "branch_setup_undo_failed")
		_controller.call("_emit_state_changed")
		var ready := await _await_native_transition(
			"undo",
			prior_revision,
			StringName()
		)
		_expect(
			bool(ready.get("ok", false)),
			"branch_setup_undo_publication_failed"
		)

	var pre_branch := _capture_contract_snapshot()
	_expect(
		int(pre_branch.get("checkpoint_operation_count", -1))
		== EXPECTED_CHECKPOINT_AT_N20
		and int(pre_branch.get("active_tail_layer_count", -1)) == 3
		and int(pre_branch.get("redo_tail_layer_count", -1)) == 2,
		"branch_setup_is_not_checkpoint15_tail3_redo2"
	)
	var branch_row := await _deposit_branch_capsule()
	_deposit_rows.append(branch_row)
	var branch_body := branch_row.get("body", null) as Resource
	branch_row.erase("body")
	var branch := _capture_contract_snapshot()
	_expect(
		int(branch.get("checkpoint_operation_count", -1))
		== EXPECTED_CHECKPOINT_AT_N20,
		"branch_changed_checkpoint"
	)
	_expect(
		int(branch.get("active_tail_layer_count", -1)) == 4,
		"branch_tail_is_not_four"
	)
	_expect(
		int(branch.get("redo_tail_layer_count", -1)) == 0,
		"branch_did_not_clear_redo"
	)
	_expect(
		int(branch.get("logical_body_count", -1)) == 5,
		"branch_logical_body_count_is_not_checkpoint_plus_four"
	)
	_expect(
		not bool(_state.call("redo_latest_layer")),
		"redo_succeeded_after_branch"
	)
	_assert_steady_native_contract(branch, "branch")

	var operand_parity := await _compare_cached_operand_to_current_csg(
		branch_body
	)
	_expect(
		bool(operand_parity.get("ok", false)),
		"cached_capsule_operand_does_not_match_current_csg"
	)
	var no_presenter_timeout := await _verify_no_presenter_ack_timeout()
	_expect(
		bool(no_presenter_timeout.get("ok", false)),
		"no_presenter_ack_guard_did_not_timeout_safely"
	)
	var rapid_promotion := await _verify_rapid_superseded_promotion()
	_expect(
		bool(rapid_promotion.get("ok", false)),
		"rapid_superseded_promotion_did_not_settle_exactly"
	)
	var pending_undo := await _verify_pending_operand_undo_supersession()
	_expect(
		bool(pending_undo.get("ok", false)),
		"pending_operand_undo_supersession_did_not_settle_exactly"
	)
	var forced_timeout_fifo := await _verify_forced_timeout_fifo_requeue()
	_expect(
		bool(forced_timeout_fifo.get("ok", false)),
		"forced_timeout_fifo_requeue_did_not_preserve_commit_order"
	)

	var final_snapshot := _capture_contract_snapshot()
	_expect(
		int(_state.call("get_pending_material_body_count")) == 0,
		"final_authoring_pending_body_count_nonzero"
	)
	_expect(
		int(final_snapshot.get("capsule_operand_pending_count", -1)) == 0,
		"final_native_capsule_pending_count_nonzero"
	)
	_expect(
		_count_all_pending_overlays() == 0,
		"final_pending_overlay_not_cleared"
	)
	_expect(
		int(final_snapshot.get("capsule_operand_request_count", -1))
		== ADD_STROKE_COUNT + 1,
		"final_capsule_request_count_mismatch"
	)
	_expect(
		int(final_snapshot.get("capsule_operand_bake_count", -1))
		== ADD_STROKE_COUNT + 1,
		"final_capsule_bake_count_mismatch"
	)

	var release_times: Array[float] = []
	var overlay_checked_count := 0
	var overlay_survived_count := 0
	for row: Dictionary in _deposit_rows:
		release_times.append(float(row.get(
			"release_to_publication_ms",
			0.0
		)))
		if bool(row.get("overlay_checked", false)):
			overlay_checked_count += 1
		if bool(row.get("overlay_contract_ok", false)):
			overlay_survived_count += 1
	var report := {
		"schema": "forge_v2_default_capsule_bounded_integration",
		"schema_version": 1,
		"ok": _failures.is_empty(),
		"production_files_touched_by_harness": false,
		"contract": {
			"real_stage_controller": true,
			"real_workspace_presenter": true,
			"fresh_default_state": true,
			"shape_kind": String(
				MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH
			),
			"sequential_add_strokes": ADD_STROKE_COUNT,
			"tail_capacity": TAIL_CAPACITY,
			"expected_n20_shape": "checkpoint15_plus_tail5",
			"undo_count": TAIL_CAPACITY,
			"redo_count": TAIL_CAPACITY,
			"branch_after_undo_count": 2,
		},
		"initial": initial,
		"n20": n20,
		"pre_branch": pre_branch,
		"branch": branch,
		"final": final_snapshot,
		"operand_parity": operand_parity,
		"no_presenter_ack_timeout": no_presenter_timeout,
		"rapid_superseded_promotion": rapid_promotion,
		"pending_operand_undo_supersession": pending_undo,
		"forced_timeout_fifo_requeue": forced_timeout_fifo,
		"pending_overlay_summary": {
			"checked_deposits": overlay_checked_count,
			"passed_deposits": overlay_survived_count,
		},
		"release_to_publication_ms": _summarize_times(release_times),
		"deposit_rows": _deposit_rows,
		"navigation_rows": _navigation_rows,
		"failures": _failures,
	}
	_write_report(report)
	_workspace.call("clear_stage_controller")
	_workspace.queue_free()
	_controller.queue_free()
	await process_frame
	if not _failures.is_empty():
		push_error("Default capsule bounded integration failed: %s" % (
			"; ".join(_failures)
		))
	quit(0 if _failures.is_empty() else 1)


func _deposit_default_capsule(stroke_index: int) -> Dictionary:
	var path := PackedVector3Array()
	if stroke_index == 0:
		path.append(Vector3(-0.52, -0.05, 0.0))
	else:
		var prior_end := _stroke_endpoints[stroke_index - 1]
		var prior_direction := _stroke_end_directions[stroke_index - 1]
		var side := -1.0 if stroke_index % 2 == 0 else 1.0
		var depth := -1.0 if stroke_index % 3 == 0 else 1.0
		var start := prior_end - prior_direction * 0.030
		var bend := Vector3(0.0, side * 0.018, depth * 0.010)
		var middle := prior_end + Vector3(0.036, 0.0, 0.0) + bend
		var endpoint := prior_end + Vector3(0.078, 0.0, 0.0) + bend * 1.55
		path.append(start)
		path.append(middle)
		path.append(endpoint)
	var row := await _commit_capsule_path(
		"deposit_%02d" % (stroke_index + 1),
		path,
		(
			"reset"
			if stroke_index == 0
			else "append"
			if stroke_index < TAIL_CAPACITY
			else "promotion_append"
		)
	)
	var body := row.get("body", null) as Resource
	if body != null:
		_bodies.append(body)
	var endpoint := path[path.size() - 1]
	var end_direction := Vector3.RIGHT
	if path.size() >= 2:
		end_direction = (path[path.size() - 1] - path[path.size() - 2]).normalized()
	_stroke_endpoints.append(endpoint)
	_stroke_end_directions.append(end_direction)
	_expect(
		body != null
		and StringName(body.get("shape_kind"))
		== MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH,
		"deposit_%02d_not_default_capsule" % (stroke_index + 1)
	)
	if body != null:
		var committed_points: PackedVector3Array = body.get("path_points")
		if stroke_index == 0:
			_expect(
				committed_points.size() == 1,
				"one_point_click_was_not_preserved"
			)
		else:
			_expect(
				committed_points.size() >= 3,
				"multi_point_capsule_has_fewer_than_three_points"
			)
			_expect(
				_path_is_bent(committed_points),
				"multi_point_capsule_is_not_bent"
			)
	row.erase("body")
	return row


func _deposit_branch_capsule() -> Dictionary:
	var prior_end := _stroke_endpoints[17]
	var prior_direction := _stroke_end_directions[17]
	var path := PackedVector3Array([
		prior_end - prior_direction * 0.030,
		prior_end + Vector3(0.032, -0.026, 0.020),
		prior_end + Vector3(0.075, -0.052, 0.036),
	])
	return await _commit_capsule_path("branch_after_two_undos", path, "append")


func _commit_capsule_path(
	label: String,
	path: PackedVector3Array,
	expected_mode: String
) -> Dictionary:
	var before := _native_diagnostics()
	var prior_published_revision := int(before.get("published_revision", 0))
	var before_request_count := int(before.get(
		"capsule_operand_request_count",
		0
	))
	var before_bake_count := int(before.get("capsule_operand_bake_count", 0))
	var release_started_usec := Time.get_ticks_usec()
	var body_id := StringName(_controller.call(
		"begin_material_body_path",
		path[0],
		Vector3.FORWARD,
		Vector3.ZERO
	))
	_expect(body_id != StringName(), "%s_begin_failed" % label)
	for point_index in range(1, path.size()):
		var extended := bool(_controller.call(
			"extend_material_body_path",
			path[point_index],
			true,
			Vector3.FORWARD,
			Vector3.ZERO
		))
		_expect(extended, "%s_extend_%d_failed" % [label, point_index])
	var body_before_finish := _find_body(body_id)
	var finish_returned := bool(_controller.call("finish_material_body_path"))
	var finish_result := _controller.call(
		"get_last_material_body_finish_result"
	) as Dictionary
	var body := _find_body(body_id)
	if body == null:
		body = body_before_finish
	var immediate := _native_diagnostics()
	var immediate_overlay := _has_pending_overlay(body_id)
	var immediate_pending_count := int(immediate.get(
		"capsule_operand_pending_count",
		0
	))
	_expect(finish_returned, "%s_finish_returned_false" % label)
	var finish_status := StringName(finish_result.get(
		"status",
		StringName()
	))
	_expect(
		finish_status == &"committed",
		"%s_finish_status_not_committed" % label
	)
	_expect(
		body != null
		and StringName(body.get("committed_layer_id")) != StringName(),
		"%s_body_not_committed" % label
	)
	_expect(
		int(_state.call("get_pending_material_body_count")) == 0,
		"%s_authoring_body_remained_pending" % label
	)
	_expect(
		immediate_pending_count > 0,
		"%s_exact_operand_was_not_deferred" % label
	)
	_expect(
		immediate_overlay,
		"%s_pending_overlay_missing_immediately" % label
	)
	var ready := await _await_native_transition(
		expected_mode,
		prior_published_revision,
		body_id
	)
	await physics_frame
	var after := _capture_contract_snapshot()
	var collision_contract := _capture_published_collision_contract()
	var release_to_publication_ms := float(
		Time.get_ticks_usec() - release_started_usec
	) / 1000.0
	var request_delta := int(after.get(
		"capsule_operand_request_count",
		0
	)) - before_request_count
	var bake_delta := int(after.get(
		"capsule_operand_bake_count",
		0
	)) - before_bake_count
	_expect(bool(ready.get("ok", false)), "%s_publication_not_ready" % label)
	_expect(
		bool(collision_contract.get("ok", false)),
		"%s_published_collision_not_targetable" % label
	)
	_expect(request_delta == 1, "%s_capsule_request_delta_not_one" % label)
	_expect(bake_delta == 1, "%s_capsule_bake_delta_not_one" % label)
	_expect(
		int(after.get("capsule_operand_failure_count", -1)) == 0,
		"%s_capsule_operand_failure_recorded" % label
	)
	_expect(
		int(after.get("capsule_operand_pending_count", -1)) == 0,
		"%s_capsule_operand_still_pending" % label
	)
	_expect(
		not _has_pending_overlay(body_id),
		"%s_pending_overlay_not_cleared_after_publication" % label
	)
	_assert_steady_native_contract(after, label)
	return {
		"label": label,
		"body_id": String(body_id),
		"body": body,
		"input_path_point_count": path.size(),
		"committed_path_point_count": (
			(body.get("path_points") as PackedVector3Array).size()
			if body != null
			else 0
		),
		"finish_status": String(finish_status),
		"immediate_operand_pending_count": immediate_pending_count,
		"immediate_overlay_visible": immediate_overlay,
		"request_delta": request_delta,
		"bake_delta": bake_delta,
		"release_to_publication_ms": release_to_publication_ms,
		"wait": ready,
		"collision_contract": collision_contract,
		"overlay_checked": true,
		"overlay_contract_ok": (
			immediate_overlay
			and int(ready.get("overlay_missing_while_pending", 0)) == 0
			and bool(ready.get("overlay_cleared_after_publication", false))
		),
		"snapshot": after,
	}


func _capture_published_collision_contract() -> Dictionary:
	var revision := _presenter.get("native_static_published_node") as Node3D
	if revision == null or not is_instance_valid(revision):
		return {"ok": false, "reason": "published_revision_missing"}
	var body := revision.get_node_or_null(
		"NativeStaticMaterialBodyCollision"
	) as StaticBody3D
	var shape_node := revision.get_node_or_null(
		"NativeStaticMaterialBodyCollision/NativeStaticMaterialBodyShape"
	) as CollisionShape3D
	var shape := (
		shape_node.shape as ConcavePolygonShape3D
		if shape_node != null
		else null
	)
	var faces := shape.get_faces() if shape != null else PackedVector3Array()
	var forward_ray_hit := Dictionary()
	var reverse_ray_hit := Dictionary()
	var ray_from := Vector3.ZERO
	var ray_to := Vector3.ZERO
	if body != null and faces.size() >= 3:
		var local_a := faces[0]
		var local_b := faces[1]
		var local_c := faces[2]
		var local_center := (local_a + local_b + local_c) / 3.0
		var local_normal := (local_b - local_a).cross(local_c - local_a).normalized()
		if local_normal.length_squared() > 0.000001:
			var world_center := body.to_global(local_center)
			var world_normal := (body.global_transform.basis * local_normal).normalized()
			ray_from = world_center + world_normal * 0.01
			ray_to = world_center - world_normal * 0.01
			var query := PhysicsRayQueryParameters3D.create(
				ray_from,
				ray_to,
				1 << 20
			)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			query.hit_back_faces = true
			forward_ray_hit = _workspace.get_world_3d().direct_space_state.intersect_ray(
				query
			)
			var reverse_query := PhysicsRayQueryParameters3D.create(
				ray_to,
				ray_from,
				1 << 20
			)
			reverse_query.collide_with_areas = false
			reverse_query.collide_with_bodies = true
			reverse_query.hit_back_faces = true
			reverse_ray_hit = _workspace.get_world_3d().direct_space_state.intersect_ray(
				reverse_query
			)
	return {
		"ok": (
			body != null
			and body.is_inside_tree()
			and body.collision_layer == (1 << 20)
			and shape_node != null
			and not shape_node.disabled
			and shape != null
			and shape.backface_collision
			and not faces.is_empty()
			and not forward_ray_hit.is_empty()
			and forward_ray_hit.get("collider", null) == body
			and not reverse_ray_hit.is_empty()
			and reverse_ray_hit.get("collider", null) == body
		),
		"revision_visible": revision.visible,
		"body_present": body != null,
		"body_inside_tree": body != null and body.is_inside_tree(),
		"collision_layer": body.collision_layer if body != null else -1,
		"shape_present": shape_node != null,
		"shape_disabled": shape_node.disabled if shape_node != null else true,
		"backface_collision": shape.backface_collision if shape != null else false,
		"face_count": faces.size() / 3,
		"ray_from": ray_from,
		"ray_to": ray_to,
		"forward_ray_hit": not forward_ray_hit.is_empty(),
		"forward_ray_hit_expected_body": (
			body != null and forward_ray_hit.get("collider", null) == body
		),
		"reverse_ray_hit": not reverse_ray_hit.is_empty(),
		"reverse_ray_hit_expected_body": (
			body != null and reverse_ray_hit.get("collider", null) == body
		),
		"material_surface_meta": (
			bool(body.get_meta("forge_v2_material_surface", false))
			if body != null
			else false
		),
		"publication_pending_meta": (
			bool(body.get_meta("forge_v2_publication_pending", true))
			if body != null
			else true
		),
	}


func _await_native_transition(
	expected_mode: String,
	prior_published_revision: int,
	overlay_body_id: StringName
) -> Dictionary:
	var transition := _state.call(
		"get_bounded_history_transition"
	) as Dictionary
	var expected_transition_revision := int(transition.get("revision", -1))
	var started_usec := Time.get_ticks_usec()
	var overlay_seen := false
	var overlay_observation_count := 0
	var overlay_missing_while_pending := 0
	for frame_index in range(WAIT_FRAME_LIMIT):
		var before_wait := _observe_transition_overlay(
			prior_published_revision,
			overlay_body_id
		)
		if bool(before_wait.get("pending_window", false)):
			overlay_observation_count += 1
			overlay_seen = overlay_seen or bool(before_wait.get("overlay", false))
			if not bool(before_wait.get("overlay", false)):
				overlay_missing_while_pending += 1
		var ready_before_wait := _transition_is_ready(
			expected_mode,
			expected_transition_revision,
			prior_published_revision
		)
		if ready_before_wait:
			return _build_wait_result(
				frame_index,
				started_usec,
				overlay_body_id,
				overlay_seen,
				overlay_observation_count,
				overlay_missing_while_pending
			)
		await process_frame
		var after_process := _observe_transition_overlay(
			prior_published_revision,
			overlay_body_id
		)
		if bool(after_process.get("pending_window", false)):
			overlay_observation_count += 1
			overlay_seen = overlay_seen or bool(after_process.get("overlay", false))
			if not bool(after_process.get("overlay", false)):
				overlay_missing_while_pending += 1
		if _transition_is_ready(
			expected_mode,
			expected_transition_revision,
			prior_published_revision
		):
			return _build_wait_result(
				frame_index + 1,
				started_usec,
				overlay_body_id,
				overlay_seen,
				overlay_observation_count,
				overlay_missing_while_pending
			)
		await physics_frame
	return {
		"ok": false,
		"expected_mode": expected_mode,
		"expected_transition_revision": expected_transition_revision,
		"prior_published_revision": prior_published_revision,
		"overlay_seen": overlay_seen,
		"overlay_observation_count": overlay_observation_count,
		"overlay_missing_while_pending": overlay_missing_while_pending,
		"diagnostics": _native_diagnostics(),
		"snapshot": _capture_contract_snapshot(),
	}


func _observe_transition_overlay(
	prior_published_revision: int,
	body_id: StringName
) -> Dictionary:
	var diagnostics := _native_diagnostics()
	var pending_window := (
		body_id != StringName()
		and (
			int(diagnostics.get("capsule_operand_pending_count", 0)) > 0
			or bool(diagnostics.get("publication_pending", false))
			or int(diagnostics.get("published_revision", 0))
			<= prior_published_revision
		)
	)
	return {
		"pending_window": pending_window,
		"overlay": _has_pending_overlay(body_id) if body_id != StringName() else false,
	}


func _transition_is_ready(
	expected_mode: String,
	expected_transition_revision: int,
	prior_published_revision: int
) -> bool:
	var diagnostics := _native_diagnostics()
	var publication := _presenter.get("native_static_published_node") as Node3D
	return (
		String(diagnostics.get("last_mode", "")) == expected_mode
		and String(diagnostics.get("lifecycle", "")) == "active"
		and bool(diagnostics.get("authoritative", false))
		and not bool(diagnostics.get("publication_pending", true))
		and int(diagnostics.get("published_revision", 0))
		> prior_published_revision
		and int(diagnostics.get("bounded_transition_revision", -1))
		== expected_transition_revision
		and int(diagnostics.get("capsule_operand_pending_count", -1)) == 0
		and int(diagnostics.get("fallback_count", -1)) == 0
		and String(diagnostics.get("last_failure_reason", "")).is_empty()
		and publication != null
		and is_instance_valid(publication)
		and publication.visible
	)


func _build_wait_result(
	waited_process_frames: int,
	started_usec: int,
	overlay_body_id: StringName,
	overlay_seen: bool,
	overlay_observation_count: int,
	overlay_missing_while_pending: int
) -> Dictionary:
	return {
		"ok": true,
		"waited_process_frames": waited_process_frames,
		"elapsed_ms": float(Time.get_ticks_usec() - started_usec) / 1000.0,
		"overlay_seen": overlay_seen,
		"overlay_observation_count": overlay_observation_count,
		"overlay_missing_while_pending": overlay_missing_while_pending,
		"overlay_cleared_after_publication": (
			overlay_body_id == StringName()
			or not _has_pending_overlay(overlay_body_id)
		),
	}


func _capture_contract_snapshot() -> Dictionary:
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
		"native_history_window_enabled": bool(diagnostics.get(
			"history_window_enabled",
			false
		)),
		"native_history_window_capacity": int(diagnostics.get(
			"history_window_capacity",
			-1
		)),
		"native_retained_state_count": int(diagnostics.get(
			"retained_state_count",
			-1
		)),
		"native_fallback_count": int(diagnostics.get("fallback_count", -1)),
		"native_last_failure_reason": String(diagnostics.get(
			"last_failure_reason",
			""
		)),
		"native_boolean_count": int(diagnostics.get("boolean_count", -1)),
		"native_promotion_count": int(diagnostics.get("promotion_count", -1)),
		"native_restore_count": int(diagnostics.get("restore_count", 0)),
		"capsule_operand_superseded_count": int(diagnostics.get(
			"capsule_operand_superseded_count",
			0
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
		"capsule_operand_last_ready_ms": float(diagnostics.get(
			"capsule_operand_last_ready_ms",
			0.0
		)),
		"capsule_operand_last_bake_ms": float(diagnostics.get(
			"capsule_operand_last_bake_ms",
			0.0
		)),
		"pending_overlay_count": _count_all_pending_overlays(),
	}


func _assert_steady_native_contract(snapshot: Dictionary, context: String) -> void:
	_expect(
		bool(snapshot.get("bounded_history_active", false)),
		"%s_bounded_history_suspended" % context
	)
	_expect(
		String(snapshot.get(
			"bounded_history_suspended_reason",
			"none"
		)) in ["", "none"],
		"%s_bounded_history_has_suspension_reason" % context
	)
	_expect(
		bool(snapshot.get("native_authoritative", false)),
		"%s_native_not_authoritative" % context
	)
	_expect(
		bool(snapshot.get("native_history_window_enabled", false))
		and int(snapshot.get("native_history_window_capacity", -1))
		== TAIL_CAPACITY,
		"%s_native_history_window_contract_failed" % context
	)
	_expect(
		int(snapshot.get("native_fallback_count", -1)) == 0,
		"%s_native_fallback_observed" % context
	)
	_expect(
		String(snapshot.get("native_last_failure_reason", "")).is_empty(),
		"%s_native_failure_reason_nonempty" % context
	)
	_expect(
		int(snapshot.get("capsule_operand_failure_count", -1)) == 0,
		"%s_capsule_operand_failure_observed" % context
	)
	_expect(
		int(snapshot.get("capsule_operand_pending_count", -1)) == 0,
		"%s_capsule_operand_pending_after_settle" % context
	)
	_expect(
		int(snapshot.get("authoring_pending_body_count", -1)) == 0,
		"%s_authoring_body_pending_after_settle" % context
	)
	_expect(
		not bool(snapshot.get("pending_native_ack", true)),
		"%s_pending_native_ack_after_settle" % context
	)


func _compare_cached_operand_to_current_csg(body: Resource) -> Dictionary:
	if body == null:
		return {"ok": false, "reason": "body_missing"}
	var signature := String(_presenter.call(
		"_build_native_static_body_signature",
		body
	))
	var cache := _presenter.get("native_capsule_operand_cache") as Dictionary
	if signature.is_empty() or not cache.has(signature):
		return {
			"ok": false,
			"reason": "cached_operand_missing",
			"signature": signature,
			"cache_count": cache.size(),
		}
	var packet := cache.get(signature, {}) as Dictionary
	var cached_mesh := _build_packet_mesh(
		packet.get("vertices", PackedVector3Array()) as PackedVector3Array,
		packet.get("indices", PackedInt32Array()) as PackedInt32Array
	)
	if cached_mesh == null:
		return {"ok": false, "reason": "cached_packet_mesh_invalid"}
	var oracle_root := CSGCombiner3D.new()
	oracle_root.name = "DefaultCapsuleCachedOperandOracle"
	oracle_root.operation = CSGShape3D.OPERATION_UNION
	oracle_root.calculate_tangents = false
	oracle_root.visible = false
	_workspace.add_child(oracle_root)
	if not bool(_presenter.call(
		"_append_csg_body_shape",
		oracle_root,
		body,
		StringName(body.get("material_variant_id")),
		false,
		0
	)):
		oracle_root.free()
		return {"ok": false, "reason": "oracle_shape_build_failed"}
	var oracle_ready := false
	for _frame in range(4):
		await process_frame
		for value: Variant in oracle_root.get_meshes():
			if value is Mesh and (value as Mesh).get_surface_count() > 0:
				oracle_ready = true
				break
		if oracle_ready:
			break
	var oracle_mesh := oracle_root.bake_static_mesh() if oracle_ready else null
	oracle_root.free()
	if oracle_mesh == null or oracle_mesh.get_surface_count() <= 0:
		return {"ok": false, "reason": "oracle_bake_failed"}
	var cached_analysis := MeshAnalyzerScript.analyze_mesh(cached_mesh)
	var oracle_analysis := MeshAnalyzerScript.analyze_mesh(oracle_mesh)
	var surface := MeshAnalyzerScript.compare_surfaces(
		cached_analysis,
		oracle_analysis
	)
	var surface_max := float(surface.get("bidirectional_max_meters", INF))
	var volume_delta := absf(
		float(cached_analysis.get("absolute_volume_cubic_meters", 0.0))
		- float(oracle_analysis.get("absolute_volume_cubic_meters", 0.0))
	)
	var same_unoriented := (
		String(cached_analysis.get("geometry_signature_unoriented", ""))
		== String(oracle_analysis.get("geometry_signature_unoriented", ""))
	)
	var same_oriented := (
		String(cached_analysis.get("geometry_signature_oriented", ""))
		== String(oracle_analysis.get("geometry_signature_oriented", ""))
	)
	var topology_ok := (
		bool(cached_analysis.get("strict_watertight", false))
		and bool(oracle_analysis.get("strict_watertight", false))
		and int(cached_analysis.get("strict_boundary_edge_count", -1)) == 0
		and int(oracle_analysis.get("strict_boundary_edge_count", -1)) == 0
		and int(cached_analysis.get("strict_nonmanifold_edge_count", -1)) == 0
		and int(oracle_analysis.get("strict_nonmanifold_edge_count", -1)) == 0
	)
	return {
		"ok": (
			bool(packet.get("ok", false))
			and String(packet.get("source", "")) == "deferred_exact_csg"
			and same_unoriented
			and same_oriented
			and surface_max <= OPERAND_SURFACE_LIMIT_METERS
			and volume_delta <= OPERAND_VOLUME_LIMIT_CUBIC_METERS
			and topology_ok
		),
		"signature": signature,
		"packet_source": packet.get("source", ""),
		"packet_vertex_count": packet.get("vertex_count", 0),
		"packet_triangle_count": packet.get("triangle_count", 0),
		"same_unoriented_signature": same_unoriented,
		"same_oriented_signature": same_oriented,
		"surface_max_meters": surface_max,
		"surface_limit_meters": OPERAND_SURFACE_LIMIT_METERS,
		"volume_delta_cubic_meters": volume_delta,
		"volume_limit_cubic_meters": OPERAND_VOLUME_LIMIT_CUBIC_METERS,
		"strict_topology_ok": topology_ok,
		"cached": MeshAnalyzerScript.strip_transient_arrays(cached_analysis),
		"current_csg_oracle": MeshAnalyzerScript.strip_transient_arrays(
			oracle_analysis
		),
	}


func _verify_rapid_superseded_promotion() -> Dictionary:
	var failure_start := _failures.size()
	var fixture := await _begin_isolated_fixture("RapidSupersededPromotion")
	if not bool(fixture.get("ok", false)):
		_expect(false, "rapid_promotion_fixture_setup_failed")
		return {
			"ok": false,
			"reason": fixture.get("reason", "fixture_setup_failed"),
		}
	var bodies: Array[Resource] = []
	var body_ids: Array[StringName] = []
	var commit_rows: Array[Dictionary] = []
	var overlay_observations: Array[Dictionary] = []
	var prior_endpoint := Vector3.ZERO
	for stroke_index in range(7):
		var path := _build_rapid_capsule_path(stroke_index, prior_endpoint)
		prior_endpoint = path[path.size() - 1]
		var commit := _commit_capsule_path_without_frame(
			"rapid_promotion_%d" % (stroke_index + 1),
			path
		)
		var body := commit.get("body", null) as Resource
		var body_id := StringName(commit.get("body_id", StringName()))
		if body != null:
			bodies.append(body)
		if body_id != StringName():
			body_ids.append(body_id)
		commit.erase("body")
		commit_rows.append(commit)
		var visible_ids: Array[String] = []
		var missing_ids: Array[String] = []
		for intended_id: StringName in body_ids:
			if _has_pending_overlay(intended_id):
				visible_ids.append(String(intended_id))
			else:
				missing_ids.append(String(intended_id))
		overlay_observations.append({
			"after_stroke": stroke_index + 1,
			"visible_body_ids": visible_ids,
			"missing_body_ids": missing_ids,
		})
		_expect(
			missing_ids.is_empty(),
			"rapid_promotion_overlay_vanished_after_stroke_%d"
				% (stroke_index + 1)
		)
		_expect(
			String(commit.get("finish_status", ""))
			== ("committed" if stroke_index < 6 else "commit_deferred"),
			"rapid_promotion_stroke_%d_finish_status_mismatch"
				% (stroke_index + 1)
		)

	var immediate_transition := _state.call(
		"get_bounded_history_transition"
	) as Dictionary
	var immediate_presentation := _state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	var immediate_diagnostics := _native_diagnostics()
	_expect(bodies.size() == 7, "rapid_promotion_did_not_create_seven_bodies")
	_expect(
		StringName(immediate_transition.get("kind", StringName()))
		== &"promotion_append",
		"rapid_promotion_sixth_transition_not_promotion_append"
	)
	_expect(
		bool(immediate_transition.get("requires_native_ack", false))
		and bool(immediate_presentation.get("pending_native_ack", false)),
		"rapid_promotion_native_ack_not_pending_immediately"
	)
	_expect(
		int(immediate_presentation.get("lifetime_operation_count", -1)) == 6
		and int((immediate_presentation.get(
			"active_tail_layers",
			[]
		) as Array).size()) == 5
		and int(immediate_presentation.get(
			"checkpoint_operation_count",
			-1
		)) == 0,
		"rapid_promotion_immediate_authoring_shape_is_not_pending_zero_plus_five"
	)
	_expect(
		int(immediate_diagnostics.get(
			"capsule_operand_superseded_count",
			0
		)) > 0,
		"rapid_promotion_did_not_record_superseded_transition"
	)
	_expect(
		int(immediate_diagnostics.get("capsule_operand_request_count", 0)) == 6,
		"rapid_promotion_did_not_stage_all_six_exact_operands"
	)
	var deferred_mutation_guards := _verify_deferred_queue_mutation_guards()
	_expect(
		bool(deferred_mutation_guards.get("ok", false)),
		"rapid_promotion_deferred_mutation_guard_failed"
	)

	var eighth_path := _build_rapid_capsule_path(7, prior_endpoint)
	prior_endpoint = eighth_path[eighth_path.size() - 1]
	var held_eighth := _begin_capsule_path_without_finish(
		"rapid_promotion_8_held",
		eighth_path
	)
	var eighth_body := held_eighth.get("body", null) as Resource
	var eighth_id := StringName(held_eighth.get("body_id", StringName()))
	if eighth_body != null:
		bodies.append(eighth_body)
	if eighth_id != StringName():
		body_ids.append(eighth_id)
	var active_hold := await _hold_active_path_across_deferred_drain(
		body_ids[6],
		eighth_id,
		bodies[6]
	)
	_expect(
		bool(active_hold.get("ok", false)),
		"rapid_promotion_active_hold_did_not_preserve_deferred_stroke"
	)
	var eighth_finish := _finish_active_capsule_without_frame(
		"rapid_promotion_8"
	)
	commit_rows.append(eighth_finish)
	_expect(
		String(eighth_finish.get("finish_status", "")) == "commit_deferred",
		"rapid_promotion_eighth_finish_was_not_deferred"
	)
	var queue_after_eighth := _controller_deferred_queue_ids()
	_expect(
		queue_after_eighth == [String(body_ids[6]), String(eighth_id)],
		"rapid_promotion_deferred_fifo_is_not_seven_then_eight"
	)
	_expect(
		_has_pending_overlay(body_ids[6])
		and _has_pending_overlay(eighth_id),
		"rapid_promotion_deferred_overlays_missing_after_eighth_finish"
	)

	var settle := await _await_exact_isolated_settle(
		3,
		5,
		0,
		[eighth_id]
	)
	_expect(
		bool(settle.get("ok", false)),
		"rapid_promotion_publication_did_not_settle"
	)
	var final_presentation := _state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	var final_snapshot := _capture_contract_snapshot()
	var final_diagnostics := _native_diagnostics()
	var tail_ids := _stringify_id_array(
		final_presentation.get("active_tail_body_ids", []) as Array
	)
	var expected_tail_ids: Array[String] = []
	for body_index in range(3, body_ids.size()):
		expected_tail_ids.append(String(body_ids[body_index]))
	var native_order := _stringify_id_array(
		_presenter.get("native_static_body_order_snapshot") as Array
	)
	_expect(
		int(final_presentation.get("checkpoint_operation_count", -1)) == 3
		and int((final_presentation.get(
			"active_tail_layers",
			[]
		) as Array).size()) == 5
		and int(final_presentation.get("logical_body_count", -1)) == 6,
		"rapid_promotion_final_shape_is_not_checkpoint_three_plus_tail_five"
	)
	_expect(
		tail_ids == expected_tail_ids,
		"rapid_promotion_tail_body_identity_mismatch"
	)
	_expect(
		native_order == expected_tail_ids,
		"rapid_promotion_native_tail_snapshot_identity_mismatch"
	)
	_expect(
		int(final_snapshot.get("native_retained_state_count", -1)) == 6,
		"rapid_promotion_native_history_did_not_retain_six_states"
	)
	for body_index in range(bodies.size()):
		var committed_body := bodies[body_index]
		_expect(
			committed_body != null
			and StringName(committed_body.get("committed_layer_id"))
			!= StringName()
			and bool(committed_body.get("layer_active")),
			"rapid_promotion_body_%d_not_eventually_committed_active"
				% (body_index + 1)
		)
	_expect(
		int(final_diagnostics.get("restore_count", 0)) > 0
		and int(final_diagnostics.get(
			"capsule_operand_superseded_count",
			0
		)) > 0,
		"rapid_promotion_restore_or_superseded_diagnostic_missing"
	)
	_expect(
		int(final_diagnostics.get("fallback_count", -1)) == 0
		and int(final_diagnostics.get("capsule_operand_failure_count", -1)) == 0
		and int(final_diagnostics.get("capsule_operand_pending_count", -1)) == 0
		and int(final_diagnostics.get("capsule_operand_request_count", -1)) == 8
		and int(final_diagnostics.get("capsule_operand_bake_count", -1)) == 8
		and int(_state.call("get_pending_material_body_count")) == 0
		and not bool(final_presentation.get("pending_native_ack", true)),
		"rapid_promotion_final_native_contract_failed"
	)
	_expect(
		_count_all_pending_overlays() == 0,
		"rapid_promotion_overlays_not_cleared_after_publication"
	)
	var geometry := _compare_current_native_to_exact_replay(bodies)
	_expect(
		bool(geometry.get("ok", false)),
		"rapid_promotion_full_geometry_does_not_match_eight_body_replay"
	)
	var post_drain_export := _controller.call(
		"build_authoring_export_snapshot"
	) as Dictionary
	var post_drain_undo := bool(_controller.call("undo_latest_layer"))
	var post_drain_undo_settle := await _await_exact_isolated_settle(
		3,
		4,
		1,
		[]
	)
	var post_undo_export := _controller.call(
		"build_authoring_export_snapshot"
	) as Dictionary
	var post_drain_redo := bool(_controller.call("redo_latest_layer"))
	var post_drain_redo_settle := await _await_exact_isolated_settle(
		3,
		5,
		0,
		[]
	)
	_expect(
		not post_drain_export.is_empty()
		and post_drain_undo
		and bool(post_drain_undo_settle.get("ok", false))
		and not post_undo_export.is_empty()
		and post_drain_redo
		and bool(post_drain_redo_settle.get("ok", false)),
		"rapid_promotion_post_drain_undo_redo_or_export_failed"
	)
	var result := {
		"ok": _failures.size() == failure_start,
		"no_process_frame_between_releases": true,
		"released_stroke_count": 8,
		"immediate_committed_count": 6,
		"immediate_deferred_count": 2,
		"commit_rows": commit_rows,
		"overlay_observations": overlay_observations,
		"deferred_mutation_guards": deferred_mutation_guards,
		"held_eighth": _json_safe_body_hold(held_eighth),
		"active_hold": active_hold,
		"queue_after_eighth_finish": queue_after_eighth,
		"immediate_transition": _json_safe_transition(immediate_transition),
		"immediate_presentation": _summarize_presentation(
			immediate_presentation
		),
		"immediate_diagnostics": immediate_diagnostics,
		"settle": settle,
		"final_presentation": _summarize_presentation(final_presentation),
		"final_snapshot": final_snapshot,
		"final_diagnostics": final_diagnostics,
		"expected_tail_body_ids": expected_tail_ids,
		"actual_tail_body_ids": tail_ids,
		"native_tail_snapshot_body_ids": native_order,
		"geometry": geometry,
		"post_drain_operations": {
			"export_nonempty": not post_drain_export.is_empty(),
			"export_lifetime_operation_count": int(post_drain_export.get(
				"bounded_history",
				{}
			).get("lifetime_operation_count", -1)),
			"undo_succeeded": post_drain_undo,
			"undo_settle": post_drain_undo_settle,
			"post_undo_export_nonempty": not post_undo_export.is_empty(),
			"redo_succeeded": post_drain_redo,
			"redo_settle": post_drain_redo_settle,
		},
	}
	await _end_isolated_fixture(fixture)
	result["case_failures"] = _failure_slice(failure_start)
	result["ok"] = (result["case_failures"] as Array).is_empty()
	return result


func _verify_pending_operand_undo_supersession() -> Dictionary:
	var failure_start := _failures.size()
	var fixture := await _begin_isolated_fixture("PendingOperandUndo")
	if not bool(fixture.get("ok", false)):
		_expect(false, "pending_undo_fixture_setup_failed")
		return {
			"ok": false,
			"reason": fixture.get("reason", "fixture_setup_failed"),
		}
	var first_path := _build_rapid_capsule_path(0, Vector3.ZERO)
	var second_path := _build_rapid_capsule_path(
		1,
		first_path[first_path.size() - 1]
	)
	var first_commit := _commit_capsule_path_without_frame(
		"pending_undo_first",
		first_path
	)
	var second_commit := _commit_capsule_path_without_frame(
		"pending_undo_second",
		second_path
	)
	var first_body := first_commit.get("body", null) as Resource
	var second_body := second_commit.get("body", null) as Resource
	var first_id := StringName(first_commit.get("body_id", StringName()))
	var second_id := StringName(second_commit.get("body_id", StringName()))
	var overlays_before_undo := {
		"first": _has_pending_overlay(first_id),
		"second": _has_pending_overlay(second_id),
	}
	_expect(
		bool(overlays_before_undo.get("first", false))
		and bool(overlays_before_undo.get("second", false)),
		"pending_undo_overlay_missing_before_undo"
	)
	var undo_succeeded := bool(_state.call("undo_latest_layer"))
	_controller.call("_emit_state_changed")
	var undo_transition := _state.call(
		"get_bounded_history_transition"
	) as Dictionary
	var overlays_after_undo := {
		"active_first": _has_pending_overlay(first_id),
		"intentionally_inactive_second": _has_pending_overlay(second_id),
	}
	_expect(undo_succeeded, "pending_operand_undo_was_rejected")
	_expect(
		StringName(undo_transition.get("kind", StringName())) == &"undo",
		"pending_operand_undo_transition_kind_mismatch"
	)
	_expect(
		bool(overlays_after_undo.get("active_first", false)),
		"pending_operand_undo_removed_active_overlay"
	)
	_expect(
		not bool(overlays_after_undo.get(
			"intentionally_inactive_second",
			true
		)),
		"pending_operand_undo_kept_intentionally_inactive_overlay"
	)
	var settle := await _await_exact_isolated_settle(
		0,
		1,
		1,
		[first_id]
	)
	_expect(
		bool(settle.get("ok", false)),
		"pending_operand_undo_publication_did_not_settle"
	)
	var final_presentation := _state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	var final_diagnostics := _native_diagnostics()
	var active_ids := _stringify_id_array(
		final_presentation.get("active_tail_body_ids", []) as Array
	)
	var redo_ids := _stringify_id_array(
		final_presentation.get("redo_tail_body_ids", []) as Array
	)
	_expect(
		active_ids == [String(first_id)]
		and redo_ids == [String(second_id)],
		"pending_operand_undo_active_or_redo_identity_mismatch"
	)
	_expect(
		int(final_diagnostics.get(
			"capsule_operand_superseded_count",
			0
		)) > 0
		and int(final_diagnostics.get("restore_count", 0)) > 0,
		"pending_operand_undo_did_not_use_superseded_restore"
	)
	_expect(
		int(final_diagnostics.get("fallback_count", -1)) == 0
		and int(final_diagnostics.get("capsule_operand_failure_count", -1)) == 0
		and int(final_diagnostics.get("capsule_operand_pending_count", -1)) == 0
		and _count_all_pending_overlays() == 0,
		"pending_operand_undo_final_native_contract_failed"
	)
	var geometry := _compare_current_native_to_exact_replay([first_body])
	_expect(
		bool(geometry.get("ok", false)),
		"pending_operand_undo_geometry_does_not_match_active_body"
	)
	first_commit.erase("body")
	second_commit.erase("body")
	var result := {
		"ok": _failures.size() == failure_start,
		"no_process_frame_before_undo": true,
		"first_commit": first_commit,
		"second_commit": second_commit,
		"overlays_before_undo": overlays_before_undo,
		"undo_succeeded": undo_succeeded,
		"undo_transition": _json_safe_transition(undo_transition),
		"overlays_after_undo": overlays_after_undo,
		"settle": settle,
		"final_presentation": _summarize_presentation(final_presentation),
		"final_diagnostics": final_diagnostics,
		"geometry": geometry,
	}
	await _end_isolated_fixture(fixture)
	result["case_failures"] = _failure_slice(failure_start)
	result["ok"] = (result["case_failures"] as Array).is_empty()
	return result


func _verify_deferred_queue_mutation_guards() -> Dictionary:
	var before := _capture_transaction_fingerprint()
	var original_state := _state
	var undo_succeeded := bool(_controller.call("undo_latest_layer"))
	var redo_succeeded := bool(_controller.call("redo_latest_layer"))
	var export_snapshot := _controller.call(
		"build_authoring_export_snapshot"
	) as Dictionary
	var replacement_prepared := bool(_controller.call(
		"_prepare_active_authoring_state_for_replacement",
		&"verifier_deferred_queue_must_block_replacement"
	))
	var save_candidate: Variant = _controller.call(
		"build_crafted_item_wip_for_save"
	)
	var replacement_result := _controller.call(
		"start_new_draft",
		"Verifier Must Not Replace Deferred State"
	) as Resource
	var after := _capture_transaction_fingerprint()
	var unchanged := before == after
	return {
		"ok": (
			not undo_succeeded
			and not redo_succeeded
			and export_snapshot.is_empty()
			and not replacement_prepared
			and save_candidate == null
			and replacement_result == original_state
			and _state == original_state
			and unchanged
		),
		"queue_count": int(_controller.call(
			"get_deferred_material_body_commit_count"
		)),
		"queue_body_ids": _controller_deferred_queue_ids(),
		"undo_succeeded": undo_succeeded,
		"redo_succeeded": redo_succeeded,
		"export_was_empty": export_snapshot.is_empty(),
		"replacement_prepared": replacement_prepared,
		"save_candidate_was_null": save_candidate == null,
		"start_new_draft_returned_same_state": replacement_result == original_state,
		"state_instance_unchanged": _state == original_state,
		"transaction_fingerprint_unchanged": unchanged,
		"before": before,
		"after": after,
	}


func _capture_transaction_fingerprint() -> Dictionary:
	var presentation := _state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	var transition := _state.call(
		"get_bounded_history_transition"
	) as Dictionary
	var body_rows: Array[Dictionary] = []
	for body_variant: Variant in _state.get("material_bodies") as Array:
		var body := body_variant as Resource
		if body == null:
			continue
		body_rows.append({
			"body_id": String(body.get("body_id")),
			"committed_layer_id": String(body.get("committed_layer_id")),
			"layer_active": bool(body.get("layer_active")),
			"path_point_count": (body.get(
				"path_points"
			) as PackedVector3Array).size(),
		})
	return {
		"state_instance_id": int(_state.get_instance_id()),
		"project_name": String(_state.get("project_name")),
		"source_wip_id": String(_state.get("source_wip_id")),
		"updated_timestamp": float(_state.get("updated_timestamp")),
		"transition": _json_safe_transition(transition),
		"presentation": _summarize_presentation(presentation),
		"pending_material_body_count": int(_state.call(
			"get_pending_material_body_count"
		)),
		"committed_layer_count": int(_state.call("get_committed_layer_count")),
		"body_rows": body_rows,
		"queue_body_ids": _controller_deferred_queue_ids(),
		"active_placement_body_id": String(_controller.call(
			"get_active_placement_body_id"
		)),
	}


func _begin_capsule_path_without_finish(
	label: String,
	path: PackedVector3Array
) -> Dictionary:
	var body_id := StringName(_controller.call(
		"begin_material_body_path",
		path[0],
		Vector3.FORWARD,
		Vector3.ZERO
	))
	var all_extended := true
	for point_index in range(1, path.size()):
		all_extended = bool(_controller.call(
			"extend_material_body_path",
			path[point_index],
			true,
			Vector3.FORWARD,
			Vector3.ZERO
		)) and all_extended
	var body := _find_body(body_id)
	_expect(body_id != StringName(), "%s_begin_failed" % label)
	_expect(all_extended, "%s_extend_failed" % label)
	_expect(body != null, "%s_active_body_missing" % label)
	return {
		"label": label,
		"body_id": body_id,
		"body": body,
		"path_point_count": path.size(),
		"active_placement_body_id": String(_controller.call(
			"get_active_placement_body_id"
		)),
	}


func _finish_active_capsule_without_frame(label: String) -> Dictionary:
	var body_id := StringName(_controller.call("get_active_placement_body_id"))
	var finish_returned := bool(_controller.call("finish_material_body_path"))
	var finish_result := _controller.call(
		"get_last_material_body_finish_result"
	) as Dictionary
	var finish_status := StringName(finish_result.get(
		"status",
		StringName()
	))
	_expect(finish_returned, "%s_finish_returned_false" % label)
	_expect(
		finish_status in [&"committed", &"commit_deferred"],
		"%s_finish_status_not_committed_or_deferred" % label
	)
	return {
		"label": label,
		"body_id": body_id,
		"finish_returned": finish_returned,
		"finish_status": String(finish_status),
		"committed": bool(finish_result.get("committed", false)),
		"deferred": bool(finish_result.get("deferred", false)),
		"pending": bool(finish_result.get("pending", false)),
		"queue_body_ids": _controller_deferred_queue_ids(),
		"overlay_visible": _has_pending_overlay(body_id),
	}


func _hold_active_path_across_deferred_drain(
	queued_body_id: StringName,
	active_body_id: StringName,
	queued_body: Resource
) -> Dictionary:
	var observations: Array[Dictionary] = []
	var violations: Array[String] = []
	var saw_pending_ack := false
	var saw_cleared_ack := false
	for frame_index in range(8):
		var observation := _capture_active_hold_observation(
			frame_index,
			"before_process",
			queued_body_id,
			active_body_id,
			queued_body
		)
		observations.append(observation)
		saw_pending_ack = saw_pending_ack or bool(observation.get(
			"pending_native_ack",
			false
		))
		saw_cleared_ack = saw_cleared_ack or not bool(observation.get(
			"pending_native_ack",
			true
		))
		_append_active_hold_violations(observation, violations)
		await process_frame
		await physics_frame
		var after := _capture_active_hold_observation(
			frame_index + 1,
			"after_physics",
			queued_body_id,
			active_body_id,
			queued_body
		)
		observations.append(after)
		saw_pending_ack = saw_pending_ack or bool(after.get(
			"pending_native_ack",
			false
		))
		saw_cleared_ack = saw_cleared_ack or not bool(after.get(
			"pending_native_ack",
			true
		))
		_append_active_hold_violations(after, violations)
	var final_presentation := _state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	return {
		"ok": (
			violations.is_empty()
			and saw_pending_ack
			and int(final_presentation.get(
				"lifetime_operation_count",
				-1
			)) == 6
			and int(_controller.call(
				"get_deferred_material_body_commit_count"
			)) == 1
		),
		"held_process_frames": 8,
		"saw_pending_ack": saw_pending_ack,
		"saw_cleared_ack": saw_cleared_ack,
		"violations": violations,
		"observations": observations,
		"final_presentation": _summarize_presentation(final_presentation),
	}


func _capture_active_hold_observation(
	frame_index: int,
	phase: String,
	queued_body_id: StringName,
	active_body_id: StringName,
	queued_body: Resource
) -> Dictionary:
	var presentation := _state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	return {
		"frame": frame_index,
		"phase": phase,
		"active_placement_body_id": String(_controller.call(
			"get_active_placement_body_id"
		)),
		"expected_active_body_id": String(active_body_id),
		"queue_body_ids": _controller_deferred_queue_ids(),
		"expected_queued_body_id": String(queued_body_id),
		"queued_body_overlay_visible": _has_pending_overlay(queued_body_id),
		"queued_body_committed": (
			queued_body != null
			and StringName(queued_body.get("committed_layer_id"))
			!= StringName()
		),
		"pending_native_ack": bool(presentation.get(
			"pending_native_ack",
			false
		)),
		"checkpoint_operation_count": int(presentation.get(
			"checkpoint_operation_count",
			-1
		)),
		"active_tail_layer_count": int((presentation.get(
			"active_tail_layers",
			[]
		) as Array).size()),
		"lifetime_operation_count": int(presentation.get(
			"lifetime_operation_count",
			-1
		)),
		"native_fallback_count": int(_native_diagnostics().get(
			"fallback_count",
			-1
		)),
	}


func _append_active_hold_violations(
	observation: Dictionary,
	violations: Array[String]
) -> void:
	var label := "frame_%d_%s" % [
		int(observation.get("frame", -1)),
		String(observation.get("phase", "unknown")),
	]
	if String(observation.get("active_placement_body_id", "")) != String(
		observation.get("expected_active_body_id", "")
	):
		violations.append("%s_active_body_changed" % label)
	if (observation.get("queue_body_ids", []) as Array) != [String(
		observation.get("expected_queued_body_id", "")
	)]:
		violations.append("%s_deferred_queue_changed" % label)
	if not bool(observation.get("queued_body_overlay_visible", false)):
		violations.append("%s_queued_overlay_missing" % label)
	if bool(observation.get("queued_body_committed", false)):
		violations.append("%s_queued_body_committed_during_active_hold" % label)
	if int(observation.get("native_fallback_count", -1)) != 0:
		violations.append("%s_native_fallback_observed" % label)


func _controller_deferred_queue_ids() -> Array[String]:
	if _controller == null or not is_instance_valid(_controller):
		return []
	return _stringify_id_array(
		_controller.get("_deferred_material_body_commit_queue") as Array
	)


func _json_safe_body_hold(hold: Dictionary) -> Dictionary:
	return {
		"label": String(hold.get("label", "")),
		"body_id": String(hold.get("body_id", "")),
		"path_point_count": int(hold.get("path_point_count", 0)),
		"active_placement_body_id": String(hold.get(
			"active_placement_body_id",
			""
		)),
	}


func _begin_isolated_fixture(label: String) -> Dictionary:
	var saved := {
		"controller": _controller,
		"workspace": _workspace,
		"presenter": _presenter,
		"state": _state,
	}
	var controller := StageControllerScript.new() as Node
	controller.name = "%sController" % label
	root.add_child(controller)
	var workspace := WorkspacePreviewScript.new() as Node3D
	workspace.name = "%sWorkspace" % label
	root.add_child(workspace)
	await process_frame
	workspace.call("bind_stage_controller", controller)
	await process_frame
	await physics_frame
	await process_frame
	var presenter := workspace.get("volume_preview_presenter") as Node3D
	var state := controller.call("get_active_authoring_state") as Resource
	if presenter == null or state == null:
		workspace.queue_free()
		controller.queue_free()
		await process_frame
		return {
			"ok": false,
			"reason": "isolated_fixture_incomplete",
			"saved": saved,
		}
	_controller = controller
	_workspace = workspace
	_presenter = presenter
	_state = state
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
	await process_frame
	return {"ok": true, "saved": saved}


func _end_isolated_fixture(fixture: Dictionary) -> void:
	var isolated_workspace := _workspace
	var isolated_controller := _controller
	if isolated_workspace != null and is_instance_valid(isolated_workspace):
		isolated_workspace.call("clear_stage_controller")
		isolated_workspace.queue_free()
	if isolated_controller != null and is_instance_valid(isolated_controller):
		isolated_controller.queue_free()
	await process_frame
	var saved := fixture.get("saved", {}) as Dictionary
	_controller = saved.get("controller", null) as Node
	_workspace = saved.get("workspace", null) as Node3D
	_presenter = saved.get("presenter", null) as Node3D
	_state = saved.get("state", null) as Resource


func _build_rapid_capsule_path(
	stroke_index: int,
	prior_endpoint: Vector3
) -> PackedVector3Array:
	if stroke_index == 0:
		return PackedVector3Array([
			Vector3(-0.62, 0.18, -0.02),
			Vector3(-0.56, 0.195, -0.008),
			Vector3(-0.50, 0.205, 0.0),
		])
	var side := -1.0 if stroke_index % 2 == 0 else 1.0
	var depth := -1.0 if stroke_index % 3 == 0 else 1.0
	return PackedVector3Array([
		prior_endpoint - Vector3.RIGHT * 0.018,
		prior_endpoint + Vector3(0.040, side * 0.018, depth * 0.010),
		prior_endpoint + Vector3(0.085, side * 0.028, depth * 0.015),
	])


func _commit_capsule_path_without_frame(
	label: String,
	path: PackedVector3Array
) -> Dictionary:
	var body_id := StringName(_controller.call(
		"begin_material_body_path",
		path[0],
		Vector3.FORWARD,
		Vector3.ZERO
	))
	var all_extended := true
	for point_index in range(1, path.size()):
		all_extended = bool(_controller.call(
			"extend_material_body_path",
			path[point_index],
			true,
			Vector3.FORWARD,
			Vector3.ZERO
		)) and all_extended
	var body_before_finish := _find_body(body_id)
	var finish_returned := bool(_controller.call("finish_material_body_path"))
	var finish_result := _controller.call(
		"get_last_material_body_finish_result"
	) as Dictionary
	var body := _find_body(body_id)
	if body == null:
		body = body_before_finish
	var transition := _state.call(
		"get_bounded_history_transition"
	) as Dictionary
	_expect(body_id != StringName(), "%s_begin_failed" % label)
	_expect(all_extended, "%s_extend_failed" % label)
	_expect(finish_returned, "%s_finish_returned_false" % label)
	var finish_status := StringName(finish_result.get(
		"status",
		StringName()
	))
	_expect(
		finish_status in [&"committed", &"commit_deferred"],
		"%s_finish_status_not_committed_or_deferred" % label
	)
	_expect(body != null, "%s_committed_body_missing" % label)
	return {
		"label": label,
		"body_id": body_id,
		"body": body,
		"path_point_count": path.size(),
		"finish_returned": finish_returned,
		"finish_status": String(finish_status),
		"transition_kind": String(transition.get("kind", "")),
		"transition_revision": int(transition.get("revision", -1)),
		"overlay_visible": _has_pending_overlay(body_id),
		"diagnostics": _native_diagnostics(),
	}


func _await_exact_isolated_settle(
	expected_checkpoint_count: int,
	expected_tail_count: int,
	expected_redo_count: int,
	active_overlay_ids: Array[StringName]
) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var overlay_observation_count := 0
	var missing_observations: Array[Dictionary] = []
	for frame_index in range(WAIT_FRAME_LIMIT):
		var snapshot := _capture_contract_snapshot()
		if _isolated_state_is_settled(
			snapshot,
			expected_checkpoint_count,
			expected_tail_count,
			expected_redo_count
		):
			return {
				"ok": missing_observations.is_empty(),
				"waited_process_frames": frame_index,
				"elapsed_ms": float(
					Time.get_ticks_usec() - started_usec
				) / 1000.0,
				"overlay_observation_count": overlay_observation_count,
				"missing_overlay_observations": missing_observations,
				"final_snapshot": snapshot,
			}
		overlay_observation_count += 1
		var missing_ids: Array[String] = []
		for body_id: StringName in active_overlay_ids:
			if not _has_pending_overlay(body_id):
				missing_ids.append(String(body_id))
		if not missing_ids.is_empty():
			missing_observations.append({
				"frame": frame_index,
				"phase": "before_process",
				"body_ids": missing_ids,
				"snapshot": snapshot,
			})
		await process_frame
		var after_process := _capture_contract_snapshot()
		if not _isolated_state_is_settled(
			after_process,
			expected_checkpoint_count,
			expected_tail_count,
			expected_redo_count
		):
			overlay_observation_count += 1
			var missing_after_process: Array[String] = []
			for body_id: StringName in active_overlay_ids:
				if not _has_pending_overlay(body_id):
					missing_after_process.append(String(body_id))
			if not missing_after_process.is_empty():
				missing_observations.append({
					"frame": frame_index + 1,
					"phase": "after_process",
					"body_ids": missing_after_process,
					"snapshot": after_process,
				})
		await physics_frame
	return {
		"ok": false,
		"reason": "settle_frame_limit_exceeded",
		"waited_process_frames": WAIT_FRAME_LIMIT,
		"elapsed_ms": float(Time.get_ticks_usec() - started_usec) / 1000.0,
		"overlay_observation_count": overlay_observation_count,
		"missing_overlay_observations": missing_observations,
		"final_snapshot": _capture_contract_snapshot(),
	}


func _isolated_state_is_settled(
	snapshot: Dictionary,
	expected_checkpoint_count: int,
	expected_tail_count: int,
	expected_redo_count: int
) -> bool:
	var publication := _presenter.get("native_static_published_node") as Node3D
	return (
		bool(snapshot.get("bounded_history_active", false))
		and int(snapshot.get("checkpoint_operation_count", -1))
		== expected_checkpoint_count
		and int(snapshot.get("active_tail_layer_count", -1))
		== expected_tail_count
		and int(snapshot.get("redo_tail_layer_count", -1))
		== expected_redo_count
		and not bool(snapshot.get("pending_native_ack", true))
		and String(snapshot.get("native_lifecycle", "")) == "active"
		and bool(snapshot.get("native_authoritative", false))
		and not bool(snapshot.get("native_publication_pending", true))
		and int(snapshot.get("capsule_operand_pending_count", -1)) == 0
		and int(snapshot.get("native_fallback_count", -1)) == 0
		and String(snapshot.get("native_last_failure_reason", "")).is_empty()
		and publication != null
		and is_instance_valid(publication)
		and publication.visible
	)


func _compare_current_native_to_exact_replay(
	bodies: Array[Resource]
) -> Dictionary:
	if bodies.is_empty():
		return {"ok": false, "reason": "expected_body_list_empty"}
	var cache := _presenter.get("native_capsule_operand_cache") as Dictionary
	var packets: Array[Dictionary] = []
	var signatures: Array[String] = []
	for body: Resource in bodies:
		if body == null:
			return {"ok": false, "reason": "expected_body_missing"}
		var signature := String(_presenter.call(
			"_build_native_static_body_signature",
			body
		))
		if signature.is_empty() or not cache.has(signature):
			return {
				"ok": false,
				"reason": "exact_operand_cache_entry_missing",
				"signature": signature,
				"cache_count": cache.size(),
			}
		var packet := cache.get(signature, {}) as Dictionary
		if (
			not bool(packet.get("ok", false))
			or String(packet.get("source", "")) != "deferred_exact_csg"
		):
			return {
				"ok": false,
				"reason": "exact_operand_cache_packet_invalid",
				"signature": signature,
			}
		packets.append(packet)
		signatures.append(signature)
	var backend := ClassDB.instantiate(&"ForgeV2ManifoldBoolean") as Object
	if backend == null:
		return {"ok": false, "reason": "replay_backend_missing"}
	if backend.has_method("set_history_window_enabled"):
		var enabled := backend.call("set_history_window_enabled", true) as Dictionary
		if not bool(enabled.get("ok", false)):
			return {"ok": false, "reason": "replay_history_enable_failed"}
	var replay_result: Dictionary = {}
	for packet_index in range(packets.size()):
		var packet := packets[packet_index]
		replay_result = backend.call(
			"reset_mesh" if packet_index == 0 else "add_mesh",
			packet.get("vertices", PackedVector3Array()),
			packet.get("indices", PackedInt32Array())
		) as Dictionary
		if not bool(replay_result.get("ok", false)):
			return {
				"ok": false,
				"reason": "exact_replay_failed_at_%d" % (packet_index + 1),
				"native_result": replay_result,
			}
	var actual_vertices := _presenter.get(
		"native_static_active_vertices"
	) as PackedVector3Array
	var actual_indices := _presenter.get(
		"native_static_active_indices"
	) as PackedInt32Array
	var expected_vertices := replay_result.get(
		"vertices",
		PackedVector3Array()
	) as PackedVector3Array
	var expected_indices := replay_result.get(
		"indices",
		PackedInt32Array()
	) as PackedInt32Array
	var actual_mesh := _build_packet_mesh(actual_vertices, actual_indices)
	var expected_mesh := _build_packet_mesh(expected_vertices, expected_indices)
	if actual_mesh == null or expected_mesh == null:
		return {"ok": false, "reason": "actual_or_replay_mesh_invalid"}
	var actual_analysis := MeshAnalyzerScript.analyze_mesh(actual_mesh)
	var expected_analysis := MeshAnalyzerScript.analyze_mesh(expected_mesh)
	var surface := MeshAnalyzerScript.compare_surfaces(
		actual_analysis,
		expected_analysis
	)
	var surface_max := float(surface.get("bidirectional_max_meters", INF))
	var volume_delta := absf(
		float(actual_analysis.get("absolute_volume_cubic_meters", 0.0))
		- float(expected_analysis.get("absolute_volume_cubic_meters", 0.0))
	)
	var bounds_delta := _analysis_bounds_delta(
		actual_analysis,
		expected_analysis
	)
	var same_unoriented := (
		String(actual_analysis.get("geometry_signature_unoriented", ""))
		== String(expected_analysis.get("geometry_signature_unoriented", ""))
	)
	var same_oriented := (
		String(actual_analysis.get("geometry_signature_oriented", ""))
		== String(expected_analysis.get("geometry_signature_oriented", ""))
	)
	var topology_ok := (
		bool(actual_analysis.get("strict_watertight", false))
		and bool(expected_analysis.get("strict_watertight", false))
		and int(actual_analysis.get("strict_boundary_edge_count", -1)) == 0
		and int(expected_analysis.get("strict_boundary_edge_count", -1)) == 0
		and int(actual_analysis.get("strict_nonmanifold_edge_count", -1)) == 0
		and int(expected_analysis.get("strict_nonmanifold_edge_count", -1)) == 0
	)
	var topology_metrics_identical := true
	for topology_field: String in [
		"emitted_vertex_count",
		"emitted_triangle_count",
		"welded_vertex_count",
		"triangle_count",
		"degenerate_triangle_count",
		"component_count",
		"boundary_edge_count",
		"nonmanifold_edge_count",
		"directed_edge_mismatch_count",
		"strict_welded_vertex_count",
		"strict_triangle_count",
		"strict_degenerate_triangle_collapse_count",
		"strict_component_count",
		"strict_boundary_edge_count",
		"strict_nonmanifold_edge_count",
		"strict_directed_edge_mismatch_count",
	]:
		if actual_analysis.get(topology_field) != expected_analysis.get(
			topology_field
		):
			topology_metrics_identical = false
			break
	return {
		"ok": (
			same_unoriented
			and same_oriented
			and surface_max <= OPERAND_SURFACE_LIMIT_METERS
			and volume_delta <= OPERAND_VOLUME_LIMIT_CUBIC_METERS
			and bounds_delta <= OPERAND_SURFACE_LIMIT_METERS
			and topology_metrics_identical
		),
		"body_count": bodies.size(),
		"exact_operand_signatures": signatures,
		"replay_last_mode": String(replay_result.get("last_mode", "")),
		"replay_checkpoint_operation_count": int(replay_result.get(
			"checkpoint_operation_count",
			-1
		)),
		"same_unoriented_signature": same_unoriented,
		"same_oriented_signature": same_oriented,
		"surface_max_meters": surface_max,
		"surface_limit_meters": OPERAND_SURFACE_LIMIT_METERS,
		"volume_delta_cubic_meters": volume_delta,
		"volume_limit_cubic_meters": OPERAND_VOLUME_LIMIT_CUBIC_METERS,
		"bounds_delta_meters": bounds_delta,
		"bounds_limit_meters": OPERAND_SURFACE_LIMIT_METERS,
		"topology_metrics_identical": topology_metrics_identical,
		"strict_topology_ok": topology_ok,
		"actual": MeshAnalyzerScript.strip_transient_arrays(actual_analysis),
		"exact_replay": MeshAnalyzerScript.strip_transient_arrays(
			expected_analysis
		),
	}


func _analysis_bounds_delta(first: Dictionary, second: Dictionary) -> float:
	var maximum := 0.0
	for suffix: String in [
		"position_x",
		"position_y",
		"position_z",
		"size_x",
		"size_y",
		"size_z",
	]:
		maximum = maxf(maximum, absf(
			float(first.get("aabb_%s" % suffix, INF))
			- float(second.get("aabb_%s" % suffix, -INF))
		))
	return maximum


func _stringify_id_array(values: Array) -> Array[String]:
	var strings: Array[String] = []
	for value: Variant in values:
		strings.append(String(value))
	return strings


func _summarize_presentation(presentation: Dictionary) -> Dictionary:
	return {
		"bounded_history_enabled": bool(presentation.get(
			"bounded_history_enabled",
			false
		)),
		"suspended_reason": String(presentation.get("suspended_reason", "")),
		"transition_revision": int(presentation.get("transition_revision", -1)),
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
		"active_tail_body_ids": _stringify_id_array(
			presentation.get("active_tail_body_ids", []) as Array
		),
		"redo_tail_layer_count": int((presentation.get(
			"redo_tail_layers",
			[]
		) as Array).size()),
		"redo_tail_body_ids": _stringify_id_array(
			presentation.get("redo_tail_body_ids", []) as Array
		),
		"logical_body_count": int(presentation.get("logical_body_count", -1)),
		"pending_native_ack": bool(presentation.get("pending_native_ack", false)),
	}


func _json_safe_transition(transition: Dictionary) -> Dictionary:
	return {
		"kind": String(transition.get("kind", "")),
		"revision": int(transition.get("revision", -1)),
		"requires_native_ack": bool(transition.get("requires_native_ack", false)),
		"pending_native_ack": bool(transition.get("pending_native_ack", false)),
		"promoted_body_ids": _stringify_id_array(
			transition.get("promoted_body_ids", []) as Array
		),
		"expected_checkpoint_operation_count": int(transition.get(
			"expected_checkpoint_operation_count",
			-1
		)),
	}


func _failure_slice(start_index: int) -> Array[String]:
	var result: Array[String] = []
	for failure_index in range(start_index, _failures.size()):
		result.append(_failures[failure_index])
	return result


func _verify_forced_timeout_fifo_requeue() -> Dictionary:
	var failure_start := _failures.size()
	var controller := StageControllerScript.new() as Node
	controller.name = "ForcedPromotionTimeoutFifoController"
	root.add_child(controller)
	await process_frame
	var state := controller.call("get_active_authoring_state") as Resource
	if state == null:
		controller.queue_free()
		await process_frame
		_expect(false, "forced_timeout_state_missing")
		return {"ok": false, "reason": "authoring_state_missing"}
	controller.call("set_active_tool_id", &"tool_volume_stroke")
	controller.call("set_active_primitive_id", &"primitive_blob")
	controller.call(
		"set_active_operation_mode",
		VolumeStrokeScript.OPERATION_ADD_MATERIAL
	)
	controller.call(
		"set_placement_policy",
		VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	)
	_forced_timeout_controller = controller
	_forced_timeout_events.clear()
	controller.connect(
		"authoring_state_changed",
		Callable(self, "_on_forced_timeout_state_changed")
	)
	var bodies: Array[Resource] = []
	var body_ids: Array[StringName] = []
	var commit_rows: Array[Dictionary] = []
	var prior_endpoint := Vector3.ZERO
	for stroke_index in range(7):
		var path := _build_rapid_capsule_path(stroke_index, prior_endpoint)
		prior_endpoint = path[path.size() - 1]
		var row := _commit_capsule_on_controller_without_frame(
			controller,
			state,
			"forced_timeout_%d" % (stroke_index + 1),
			path
		)
		var body := row.get("body", null) as Resource
		var body_id := StringName(row.get("body_id", StringName()))
		if body != null:
			bodies.append(body)
		if body_id != StringName():
			body_ids.append(body_id)
		row.erase("body")
		commit_rows.append(row)
		_expect(
			String(row.get("finish_status", ""))
			== ("committed" if stroke_index < 6 else "commit_deferred"),
			"forced_timeout_stroke_%d_finish_status_mismatch"
				% (stroke_index + 1)
		)
	var immediate_transition := state.call(
		"get_bounded_history_transition"
	) as Dictionary
	var immediate_presentation := state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	var immediate_queue := _stringify_id_array(
		controller.get("_deferred_material_body_commit_queue") as Array
	)
	_expect(
		body_ids.size() == 7
		and immediate_queue == [String(body_ids[6])],
		"forced_timeout_initial_deferred_queue_is_not_body_seven"
	)
	_expect(
		StringName(immediate_transition.get("kind", StringName()))
		== &"promotion_append"
		and bool(immediate_presentation.get("pending_native_ack", false)),
		"forced_timeout_sixth_promotion_not_pending"
	)
	var frame_rows: Array[Dictionary] = []
	var settled := false
	for frame_index in range(20):
		await process_frame
		var presentation := state.call(
			"get_bounded_presentation_descriptor"
		) as Dictionary
		var queue_ids := _stringify_id_array(
			controller.get("_deferred_material_body_commit_queue") as Array
		)
		var row := {
			"process_frame": frame_index + 1,
			"queue_body_ids": queue_ids,
			"pending_material_body_count": int(state.call(
				"get_pending_material_body_count"
			)),
			"pending_native_ack": bool(presentation.get(
				"pending_native_ack",
				false
			)),
			"lifetime_operation_count": int(presentation.get(
				"lifetime_operation_count",
				-1
			)),
			"active_tail_layer_count": int((presentation.get(
				"active_tail_layers",
				[]
			) as Array).size()),
			"bounded_history_enabled": bool(presentation.get(
				"bounded_history_enabled",
				false
			)),
			"suspended_reason": String(presentation.get(
				"suspended_reason",
				""
			)),
		}
		frame_rows.append(row)
		if (
			queue_ids.is_empty()
			and not bool(presentation.get("pending_native_ack", true))
			and int(state.call("get_pending_material_body_count")) == 0
			and int(presentation.get("lifetime_operation_count", -1)) == 7
		):
			settled = true
			break
	var final_presentation := state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	var final_transition := state.call(
		"get_bounded_history_transition"
	) as Dictionary
	var final_layer_body_ids := _collect_state_layer_body_ids(state)
	var expected_all_ids := _stringify_id_array(body_ids)
	var requeue_event: Dictionary = {}
	for event: Dictionary in _forced_timeout_events:
		if (
			(event.get("queue_body_ids", []) as Array)
			== [String(body_ids[5]), String(body_ids[6])]
			and String(event.get("suspended_reason", ""))
			== "native_promotion_was_not_acknowledged"
		):
			requeue_event = event
			break
	var export_snapshot := controller.call(
		"build_authoring_export_snapshot"
	) as Dictionary
	_expect(settled, "forced_timeout_queue_did_not_settle")
	_expect(
		not requeue_event.is_empty(),
		"forced_timeout_body_six_was_not_requeued_ahead_of_body_seven"
	)
	_expect(
		final_layer_body_ids == expected_all_ids,
		"forced_timeout_final_layer_body_order_mismatch"
	)
	_expect(
		not bool(final_presentation.get("bounded_history_enabled", true))
		and String(final_presentation.get("suspended_reason", "")) in [
			"native_promotion_was_not_acknowledged",
			"unsupported_committed_layer",
		]
		and StringName(final_transition.get("kind", StringName()))
		== &"fallback_full_refresh",
		"forced_timeout_did_not_finish_in_explicit_fallback"
	)
	_expect(
		int(final_presentation.get("lifetime_operation_count", -1)) == 7
		and int((final_presentation.get(
			"active_tail_layers",
			[]
		) as Array).size()) == 7
		and int(state.call("get_pending_material_body_count")) == 0
		and int(controller.call(
			"get_deferred_material_body_commit_count"
		)) == 0,
		"forced_timeout_final_authoring_counts_mismatch"
	)
	for body_index in [5, 6]:
		var recovered_body := bodies[body_index]
		_expect(
			recovered_body != null
			and StringName(recovered_body.get("committed_layer_id"))
			!= StringName()
			and bool(recovered_body.get("layer_active")),
			"forced_timeout_recovered_body_%d_not_committed"
				% (body_index + 1)
		)
	_expect(
		not export_snapshot.is_empty(),
		"forced_timeout_final_export_is_empty"
	)
	var result := {
		"ok": _failures.size() == failure_start,
		"presenter_bound": false,
		"forced_guard_timeout": true,
		"commit_rows": commit_rows,
		"immediate_transition": _json_safe_transition(immediate_transition),
		"immediate_presentation": _summarize_presentation(
			immediate_presentation
		),
		"immediate_queue_body_ids": immediate_queue,
		"frame_rows": frame_rows,
		"state_change_events": _forced_timeout_events.duplicate(true),
		"requeue_event": requeue_event,
		"final_presentation": _summarize_presentation(final_presentation),
		"final_transition": _json_safe_transition(final_transition),
		"expected_layer_body_ids": expected_all_ids,
		"actual_layer_body_ids": final_layer_body_ids,
		"final_export_nonempty": not export_snapshot.is_empty(),
	}
	controller.disconnect(
		"authoring_state_changed",
		Callable(self, "_on_forced_timeout_state_changed")
	)
	_forced_timeout_controller = null
	controller.queue_free()
	await process_frame
	result["case_failures"] = _failure_slice(failure_start)
	result["ok"] = (result["case_failures"] as Array).is_empty()
	return result


func _commit_capsule_on_controller_without_frame(
	controller: Node,
	state: Resource,
	label: String,
	path: PackedVector3Array
) -> Dictionary:
	var body_id := StringName(controller.call(
		"begin_material_body_path",
		path[0],
		Vector3.FORWARD,
		Vector3.ZERO
	))
	var all_extended := true
	for point_index in range(1, path.size()):
		all_extended = bool(controller.call(
			"extend_material_body_path",
			path[point_index],
			true,
			Vector3.FORWARD,
			Vector3.ZERO
		)) and all_extended
	var body_before_finish := _find_body_in_state(state, body_id)
	var finish_returned := bool(controller.call("finish_material_body_path"))
	var finish_result := controller.call(
		"get_last_material_body_finish_result"
	) as Dictionary
	var body := _find_body_in_state(state, body_id)
	if body == null:
		body = body_before_finish
	var finish_status := StringName(finish_result.get(
		"status",
		StringName()
	))
	_expect(body_id != StringName(), "%s_begin_failed" % label)
	_expect(all_extended, "%s_extend_failed" % label)
	_expect(finish_returned, "%s_finish_returned_false" % label)
	_expect(
		finish_status in [&"committed", &"commit_deferred"],
		"%s_finish_status_not_committed_or_deferred" % label
	)
	return {
		"label": label,
		"body_id": body_id,
		"body": body,
		"finish_returned": finish_returned,
		"finish_status": String(finish_status),
		"deferred": bool(finish_result.get("deferred", false)),
		"queue_body_ids": _stringify_id_array(
			controller.get("_deferred_material_body_commit_queue") as Array
		),
	}


func _find_body_in_state(state: Resource, body_id: StringName) -> Resource:
	if state == null or body_id == StringName():
		return null
	for body_variant: Variant in state.get("material_bodies") as Array:
		var body := body_variant as Resource
		if body != null and StringName(body.get("body_id")) == body_id:
			return body
	return null


func _collect_state_layer_body_ids(state: Resource) -> Array[String]:
	var result: Array[String] = []
	if state == null:
		return result
	for layer_variant: Variant in state.get("forge_layers") as Array:
		var layer := layer_variant as Resource
		if layer == null:
			continue
		for body_id_variant: Variant in layer.get("body_ids") as Array:
			result.append(String(body_id_variant))
	return result


func _on_forced_timeout_state_changed(authoring_state: Resource) -> void:
	if (
		_forced_timeout_controller == null
		or not is_instance_valid(_forced_timeout_controller)
		or authoring_state == null
	):
		return
	var presentation := authoring_state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	var transition := authoring_state.call(
		"get_bounded_history_transition"
	) as Dictionary
	_forced_timeout_events.append({
		"queue_body_ids": _stringify_id_array(
			_forced_timeout_controller.get(
				"_deferred_material_body_commit_queue"
			) as Array
		),
		"transition_kind": String(transition.get("kind", "")),
		"transition_revision": int(transition.get("revision", -1)),
		"pending_native_ack": bool(presentation.get(
			"pending_native_ack",
			false
		)),
		"bounded_history_enabled": bool(presentation.get(
			"bounded_history_enabled",
			false
		)),
		"suspended_reason": String(presentation.get(
			"suspended_reason",
			""
		)),
		"lifetime_operation_count": int(presentation.get(
			"lifetime_operation_count",
			-1
		)),
		"pending_material_body_count": int(authoring_state.call(
			"get_pending_material_body_count"
		)),
		"layer_body_ids": _collect_state_layer_body_ids(authoring_state),
	})


func _verify_no_presenter_ack_timeout() -> Dictionary:
	var controller := StageControllerScript.new() as Node
	controller.name = "NoPresenterBoundedAckTimeoutController"
	root.add_child(controller)
	await process_frame
	var state := controller.call("get_active_authoring_state") as Resource
	if state == null:
		controller.free()
		return {"ok": false, "reason": "no_presenter_state_missing"}
	controller.call("set_active_tool_id", &"tool_volume_stroke")
	controller.call("set_active_primitive_id", &"primitive_blob")
	controller.call(
		"set_active_operation_mode",
		VolumeStrokeScript.OPERATION_ADD_MATERIAL
	)
	controller.call(
		"set_placement_policy",
		VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	)
	var commit_results: Array[Dictionary] = []
	for stroke_index in range(6):
		var start := Vector3(
			-0.40 + float(stroke_index) * 0.055,
			0.42,
			0.0
		)
		var endpoint := start + Vector3(0.080, 0.0, 0.0)
		var body_id := StringName(controller.call(
			"begin_material_body_path",
			start,
			Vector3.FORWARD,
			Vector3.ZERO
		))
		var extended := bool(controller.call(
			"extend_material_body_path",
			endpoint,
			true,
			Vector3.FORWARD,
			Vector3.ZERO
		))
		var finished := bool(controller.call("finish_material_body_path"))
		commit_results.append({
			"stroke": stroke_index + 1,
			"body_created": body_id != StringName(),
			"extended": extended,
			"finished": finished,
			"finish_status": String((controller.call(
				"get_last_material_body_finish_result"
			) as Dictionary).get("status", "")),
		})
	var immediate_transition := state.call(
		"get_bounded_history_transition"
	) as Dictionary
	var pending_revision := int(immediate_transition.get("revision", -1))
	var immediate_pending := bool(state.call(
		"has_pending_bounded_history_promotion"
	))
	var stable_revision_frames := 0
	var waited_process_frames := 0
	var per_frame: Array[Dictionary] = []
	while (
		bool(state.call("has_pending_bounded_history_promotion"))
		and waited_process_frames < 12
	):
		await process_frame
		waited_process_frames += 1
		var transition := state.call(
			"get_bounded_history_transition"
		) as Dictionary
		var still_pending := bool(state.call(
			"has_pending_bounded_history_promotion"
		))
		var same_revision := int(transition.get("revision", -2)) == pending_revision
		if still_pending and same_revision:
			stable_revision_frames += 1
		per_frame.append({
			"process_frame": waited_process_frames,
			"pending": still_pending,
			"transition_revision": int(transition.get("revision", -1)),
			"transition_kind": String(transition.get("kind", "")),
		})
	var final_transition := state.call(
		"get_bounded_history_transition"
	) as Dictionary
	var final_presentation := state.call(
		"get_bounded_presentation_descriptor"
	) as Dictionary
	var all_six_committed := true
	for result: Dictionary in commit_results:
		all_six_committed = (
			all_six_committed
			and bool(result.get("body_created", false))
			and bool(result.get("extended", false))
			and bool(result.get("finished", false))
			and String(result.get("finish_status", "")) == "committed"
		)
	var result := {
		"ok": (
			all_six_committed
			and immediate_pending
			and String(immediate_transition.get("kind", ""))
			== "promotion_append"
			and bool(immediate_transition.get("requires_native_ack", false))
			and stable_revision_frames >= 3
			and waited_process_frames >= 4
			and not bool(state.call(
				"has_pending_bounded_history_promotion"
			))
			and String(final_transition.get("kind", ""))
			== "fallback_full_refresh"
			and not bool(final_presentation.get(
				"bounded_history_enabled",
				true
			))
			and String(final_presentation.get("suspended_reason", ""))
			== "native_promotion_was_not_acknowledged"
			and not bool(final_presentation.get("pending_native_ack", true))
		),
		"presenter_bound": false,
		"commit_results": commit_results,
		"immediate_pending": immediate_pending,
		"pending_revision": pending_revision,
		"immediate_transition_kind": String(immediate_transition.get(
			"kind",
			""
		)),
		"immediate_requires_native_ack": bool(immediate_transition.get(
			"requires_native_ack",
			false
		)),
		"stable_same_revision_frames": stable_revision_frames,
		"waited_process_frames": waited_process_frames,
		"per_frame": per_frame,
		"final_pending": bool(state.call(
			"has_pending_bounded_history_promotion"
		)),
		"final_transition_kind": String(final_transition.get("kind", "")),
		"final_transition_revision": int(final_transition.get("revision", -1)),
		"final_bounded_history_active": bool(final_presentation.get(
			"bounded_history_enabled",
			true
		)),
		"final_suspended_reason": String(final_presentation.get(
			"suspended_reason",
			""
		)),
		"final_pending_native_ack": bool(final_presentation.get(
			"pending_native_ack",
			true
		)),
	}
	controller.free()
	return result


func _build_packet_mesh(
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> ArrayMesh:
	if vertices.is_empty() or indices.is_empty() or indices.size() % 3 != 0:
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _find_body(body_id: StringName) -> Resource:
	if body_id == StringName():
		return null
	for body_variant: Variant in _state.get("material_bodies") as Array:
		var body := body_variant as Resource
		if body != null and StringName(body.get("body_id")) == body_id:
			return body
	return null


func _path_is_bent(points: PackedVector3Array) -> bool:
	if points.size() < 3:
		return false
	var baseline := points[points.size() - 1] - points[0]
	if baseline.length_squared() <= 0.000000001:
		return false
	for point_index in range(1, points.size() - 1):
		var offset := points[point_index] - points[0]
		if baseline.cross(offset).length() > 0.0001:
			return true
	return false


func _has_pending_overlay(body_id: StringName) -> bool:
	if body_id == StringName():
		return false
	var active_root := _presenter.get("csg_active_body_root") as Node
	if active_root == null or not is_instance_valid(active_root):
		return false
	for child: Node in active_root.get_children():
		if (
			bool(child.get_meta(
				"forge_v2_non_authoritative_pending_preview",
				false
			))
			and StringName(child.get_meta(
				"forge_v2_pending_body_id",
				StringName()
			)) == body_id
		):
			return child is MeshInstance3D and (child as MeshInstance3D).visible
	return false


func _count_all_pending_overlays() -> int:
	var active_root := _presenter.get("csg_active_body_root") as Node
	if active_root == null or not is_instance_valid(active_root):
		return 0
	var count := 0
	for child: Node in active_root.get_children():
		if bool(child.get_meta(
			"forge_v2_non_authoritative_pending_preview",
			false
		)):
			count += 1
	return count


func _native_diagnostics() -> Dictionary:
	return _presenter.call(
		"get_native_static_sync_diagnostics"
	) as Dictionary


func _expect(condition: bool, failure: String) -> void:
	if condition:
		return
	if not _failures.has(failure):
		_failures.append(failure)


func _summarize_times(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value: float in sorted:
		total += value
	return {
		"count": sorted.size(),
		"min": sorted[0],
		"mean": total / float(sorted.size()),
		"p50": _percentile(sorted, 0.50),
		"p95": _percentile(sorted, 0.95),
		"max": sorted[sorted.size() - 1],
	}


func _percentile(sorted: Array[float], fraction: float) -> float:
	var index := clampi(
		ceili(float(sorted.size()) * fraction) - 1,
		0,
		sorted.size() - 1
	)
	return sorted[index]


func _finish_fixture_failure(message: String) -> void:
	_failures.append(message)
	_write_report({
		"schema": "forge_v2_default_capsule_bounded_integration",
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
	file.store_string(JSON.stringify(report, "  ", false) + "\n")
	file.close()
