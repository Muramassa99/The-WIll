extends SceneTree

const ControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const CraftedItemWIPScript = preload(
	"res://core/models/crafted_item_wip.gd"
)
const ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_action_undo_integration_2026-08-30.txt"
)

var controller: Node
var failure_message := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	controller = ControllerScript.new()
	root.add_child(controller)
	await process_frame
	_verify_pointwise_path_history()
	_stop_if_failed()
	_verify_held_undo_batch_roundtrip()
	_stop_if_failed()
	_verify_generate_commit_roundtrip()
	_stop_if_failed()
	await _verify_deferred_commit_preserves_action_chronology()
	_stop_if_failed()
	await _verify_multiple_pending_actions_commit_independently()
	_stop_if_failed()
	_verify_stroke_history_and_branching()
	_stop_if_failed()
	await _verify_rejected_promotion_rebinds_action_record()
	_stop_if_failed()
	_verify_native_layer_compatibility()
	_stop_if_failed()
	_verify_handle_create_and_atomic_change()
	_stop_if_failed()
	_verify_handle_replay_preserves_unrelated_pending()
	_stop_if_failed()
	_verify_unbounded_compact_point_actions()
	_stop_if_failed()
	_verify_save_reload_lifetime_boundary()
	_stop_if_failed()
	_write_result([
		"ok=true",
		"pointwise_path_undo_redo=true",
		"first_path_point_is_undoable=true",
		"held_undo_redoes_as_one_gesture=true",
		"generate_returns_to_point_placement=true",
		"redo_restores_generated_body=true",
		"commit_is_not_extra_action=true",
		"deferred_commit_preserves_original_action_slot=true",
		"deferred_commit_preserves_original_transient_after_state=true",
		"multiple_pending_actions_commit_independently=true",
		"one_stroke_is_one_action=true",
		"rejected_bounded_promotion_rebinds_action_record=true",
		"new_action_discards_action_and_native_redo=true",
		"native_layer_compatibility_api_isolated=true",
		"protected_handle_create_undo_redo=true",
		"handle_local_edit_undo_redo=true",
		"protected_handle_change_is_one_atomic_action=true",
		"protected_handle_replay_preserves_unrelated_pending=true",
		"point_actions_unbounded_by_count=true",
		"point_action_storage_is_compact=true",
		"save_reload_preserves_history=true",
		"explicit_load_clears_history=true",
	])
	print("FORGE_V2_ACTION_UNDO_INTEGRATION_VERIFY: PASS")
	controller.queue_free()
	quit(0)


func _verify_pointwise_path_history() -> void:
	_new_draft("Pointwise Path")
	controller.call("set_active_tool_id", AuthoringStateScript.TOOL_SPLINE_LINE)
	var points := [
		Vector3.ZERO,
		Vector3(0.12, 0.02, 0.0),
		Vector3(0.24, 0.0, 0.0),
	]
	for point: Vector3 in points:
		_require(
			int(controller.call(
				"append_spline_line_point",
				point,
				Vector3.UP
			)) >= 0,
			"path point placement failed"
		)
	_require(_point_count() == 3, "three placed path points were not retained")
	for expected_count in [2, 1, 0]:
		_require(bool(controller.call("undo_latest_action")), "path-point Undo failed")
		_require(
			_point_count() == expected_count,
			"path-point Undo did not remove exactly one latest point"
		)
	_require(
		StringName(_summary().get("active_tool", StringName()))
		== AuthoringStateScript.TOOL_SPLINE_LINE,
		"undoing the first point left the selected path tool"
	)
	for expected_count in [1, 2, 3]:
		_require(bool(controller.call("redo_latest_action")), "path-point Redo failed")
		_require(
			_point_count() == expected_count,
			"path-point Redo did not restore exactly one point"
		)


func _verify_held_undo_batch_roundtrip() -> void:
	_new_draft("Held Undo Batch")
	controller.call("set_active_tool_id", AuthoringStateScript.TOOL_SPLINE_LINE)
	for point_index in range(6):
		controller.call(
			"append_spline_line_point",
			Vector3(float(point_index) * 0.05, 0.0, 0.0),
			Vector3.UP
		)
	_require(
		bool(controller.call("begin_action_history_undo_batch")),
		"controller held Undo batch did not begin"
	)
	for _undo_index in range(5):
		_require(
			bool(controller.call("undo_latest_action")),
			"controller held Undo step failed"
		)
	_require(_point_count() == 1, "held Undo did not traverse five point actions")
	_require(
		not bool(controller.call("can_redo_action")),
		"held Undo exposed an incomplete Redo gesture"
	)
	_require(
		bool(controller.call("end_action_history_undo_batch")),
		"controller held Undo batch did not end"
	)
	_require(
		bool(controller.call("redo_latest_action")),
		"one Redo could not restore the held Undo gesture"
	)
	_require(_point_count() == 6, "held Undo Redo did not restore all five actions")


func _verify_generate_commit_roundtrip() -> void:
	_new_draft("Generate Roundtrip")
	controller.call("set_active_tool_id", AuthoringStateScript.TOOL_SPLINE_LINE)
	controller.call("append_spline_line_point", Vector3.ZERO, Vector3.UP)
	controller.call(
		"append_spline_line_point",
		Vector3(0.18, 0.0, 0.035),
		Vector3.UP
	)
	_require(bool(controller.call("finish_spline_line")), "path Finish failed")
	_require(
		bool(controller.call("generate_spline_line_csg_noodle")),
		"CSG noodle generation failed"
	)
	_require(_pending_count() == 1, "generated noodle was not pending")
	_require(bool(controller.call("undo_latest_action")), "generated-body Undo failed")
	_require(_pending_count() == 0, "generated-body Undo retained its pending body")
	_require(_point_count() == 2, "generated-body Undo did not restore path points")
	_require(
		not bool(_summary().get("spline_line_finished", true)),
		"generated-body Undo did not return to point-placement mode"
	)
	_require(bool(controller.call("redo_latest_action")), "generated-body Redo failed")
	_require(_pending_count() == 1, "generated-body Redo did not restore body")
	var count_before_commit := int(_summary().get("action_undo_count", -1))
	var layer := controller.call("commit_pending_material_bodies_as_layer") as Resource
	_require(layer != null, "generated-body commit failed")
	_require(
		int(_summary().get("action_undo_count", -1)) == count_before_commit,
		"structural Commit became an extra user action"
	)
	_require(bool(controller.call("undo_latest_action")), "committed generation Undo failed")
	_require(
		int(_summary().get("active_tail_layer_count", -1)) == 0,
		"committed generation Undo retained its active layer"
	)
	_require(_point_count() == 2, "committed generation Undo lost its source path")
	_require(bool(controller.call("redo_latest_action")), "committed generation Redo failed")
	_require(
		int(_summary().get("active_tail_layer_count", -1)) == 1,
		"committed generation Redo did not restore its layer"
	)


func _verify_stroke_history_and_branching() -> void:
	_new_draft("Stroke Branch")
	_add_stroke(Vector3(-0.10, 0.0, 0.0), Vector3(-0.02, 0.0, 0.0))
	_add_stroke(Vector3(0.02, 0.0, 0.0), Vector3(0.10, 0.0, 0.0))
	_require(
		int(_summary().get("action_undo_count", -1)) == 2,
		"two completed strokes were not two actions"
	)
	_require(bool(controller.call("undo_latest_action")), "latest stroke Undo failed")
	_require(
		int(_summary().get("active_tail_layer_count", -1)) == 1,
		"latest stroke Undo changed more than one layer"
	)
	controller.call("set_active_tool_id", AuthoringStateScript.TOOL_SPLINE_LINE)
	controller.call("append_spline_line_point", Vector3(0.0, 0.1, 0.0), Vector3.UP)
	_require(not bool(controller.call("can_redo_action")), "new point retained action Redo")
	_require(
		int(_summary().get("undone_layer_count", -1)) == 0,
		"new point retained abandoned native material Redo"
	)


func _verify_deferred_commit_preserves_action_chronology() -> void:
	_new_draft("Deferred Chronology")
	controller.call("set_active_tool_id", AuthoringStateScript.TOOL_SPLINE_LINE)
	controller.call("append_spline_line_point", Vector3.ZERO, Vector3.UP)
	controller.call(
		"append_spline_line_point",
		Vector3(0.16, 0.0, 0.025),
		Vector3.UP
	)
	_require(bool(controller.call("finish_spline_line")), "deferred fixture Finish failed")
	_require(
		bool(controller.call("generate_spline_line_csg_noodle")),
		"deferred fixture Generate failed"
	)
	var state := controller.call("get_active_authoring_state") as Resource
	var body_id := _first_pending_body_id(state)
	_require(body_id != StringName(), "deferred fixture pending body missing")
	_require(
		bool(controller.call(
			"_enqueue_deferred_material_body_commit",
			state,
			body_id
		)),
		"deferred fixture queue failed"
	)
	controller.call(
		"append_spline_line_point",
		Vector3(0.0, 0.12, 0.0),
		Vector3.UP
	)
	for _frame_index in range(12):
		await process_frame
		if (
			int(controller.call("get_deferred_material_body_commit_count")) == 0
			and not bool(state.call("has_pending_bounded_history_promotion"))
		):
			break
	_require(_pending_count() == 0, "deferred body did not commit")
	_require(
		int(_summary().get("active_tail_layer_count", -1)) == 1,
		"deferred commit did not publish exactly one layer"
	)
	_require(_point_count() == 1, "later path edit was lost during deferred commit")
	_require(bool(controller.call("undo_latest_action")), "later edit Undo failed")
	_require(
		_point_count() == 0
		and int(_summary().get("active_tail_layer_count", -1)) == 1,
		"deferred finalization moved the earlier action behind the later edit"
	)
	_require(bool(controller.call("undo_latest_action")), "deferred material Undo failed")
	_require(
		int(_summary().get("active_tail_layer_count", -1)) == 0
		and _point_count() == 2,
		"deferred material Undo did not restore its own source path"
	)
	_require(bool(controller.call("redo_latest_action")), "deferred material Redo failed")
	_require(
		int(_summary().get("active_tail_layer_count", -1)) == 1
		and _point_count() == 0,
		"deferred material Redo leaked the later path edit into its after-state"
	)
	_require(bool(controller.call("redo_latest_action")), "later edit Redo failed")
	_require(_point_count() == 1, "later path edit did not return on its own Redo")


func _verify_multiple_pending_actions_commit_independently() -> void:
	_new_draft("Independent Pending Actions")
	controller.call("append_sample_material_body")
	controller.call("append_sample_material_body")
	_require(_pending_count() == 2, "two pending action fixtures were not created")
	_require(
		int(_summary().get("action_undo_count", -1)) == 2,
		"two pending user actions were not journaled independently"
	)
	var first_layer := controller.call(
		"commit_pending_material_bodies_as_layer"
	) as Resource
	_require(first_layer != null, "first pending action commit failed")
	_require(
		_pending_count() == 1
		and int(_summary().get("active_tail_layer_count", -1)) == 1,
		"first commit consumed more than one pending action"
	)
	var second_layer := controller.call(
		"commit_pending_material_bodies_as_layer"
	) as Resource
	_require(second_layer != null, "second pending action commit failed")
	_require(
		_pending_count() == 0
		and int(_summary().get("active_tail_layer_count", -1)) == 2,
		"second pending action did not commit independently"
	)
	_require(bool(controller.call("undo_latest_action")), "second pending action Undo failed")
	_require(
		int(_summary().get("active_tail_layer_count", -1)) == 1,
		"second pending action Undo changed more than one layer"
	)
	_require(bool(controller.call("undo_latest_action")), "first pending action Undo failed")
	_require(
		int(_summary().get("active_tail_layer_count", -1)) == 0,
		"first pending action Undo retained its layer"
	)
	_new_draft("Commit All Pending Actions")
	controller.call("append_sample_material_body")
	controller.call("append_sample_material_body")
	var commit_all_result := await controller.call(
		"commit_all_pending_material_bodies_as_layers"
	) as Dictionary
	_require(
		bool(commit_all_result.get("ok", false))
		and int(commit_all_result.get("committed_layer_count", -1)) == 2,
		"manual Commit Pending did not finish both user actions"
	)
	_require(
		_pending_count() == 0
		and int(_summary().get("active_tail_layer_count", -1)) == 2,
		"manual Commit Pending left work behind or merged action layers"
	)


func _verify_unbounded_compact_point_actions() -> void:
	_new_draft("Unbounded Point Actions")
	controller.call("set_active_tool_id", AuthoringStateScript.TOOL_SPLINE_LINE)
	const POINT_ACTION_COUNT := 5000
	for point_index in range(POINT_ACTION_COUNT):
		controller.call(
			"append_spline_line_point",
			Vector3(float(point_index) * 0.05, 0.0, 0.0),
			Vector3.UP
		)
	_require(
		int(_summary().get("action_undo_count", -1)) == POINT_ACTION_COUNT,
		"action journal discarded point actions before a CSG checkpoint"
	)
	var history = controller.get("_action_history")
	var records := history.call("get_undo_records") as Array[Dictionary]
	var stored_path_values := 0
	for record: Dictionary in records:
		var payload := record.get("payload", {}) as Dictionary
		_require(
			not payload.has("before") and not payload.has("after"),
			"point action retained complete transient snapshots"
		)
		var delta := payload.get("delta", {}) as Dictionary
		var changes := delta.get("changes", {}) as Dictionary
		for path_key in ["spline_line_points", "spline_line_surface_normals"]:
			var change := changes.get(path_key, {}) as Dictionary
			stored_path_values += (
				(change.get("before_middle", []) as Array).size()
				+ (change.get("after_middle", []) as Array).size()
			)
	_require(
		stored_path_values <= POINT_ACTION_COUNT * 2,
		"point-action storage grew with complete path length"
	)
	for _undo_index in range(POINT_ACTION_COUNT):
		_require(bool(controller.call("undo_latest_action")), "point action Undo failed")
	_require(not bool(controller.call("can_undo_action")), "extra point action remained undoable")
	_require(
		not bool(controller.call("undo_latest_action")),
		"extra point Undo unexpectedly succeeded"
	)
	_require(_point_count() == 0, "point Undo did not reach tool-selection state")
	for _redo_index in range(POINT_ACTION_COUNT):
		_require(bool(controller.call("redo_latest_action")), "point action Redo failed")
	_require(not bool(controller.call("can_redo_action")), "extra point Redo remained available")
	_require(
		not bool(controller.call("redo_latest_action")),
		"extra point Redo unexpectedly succeeded"
	)
	_require(
		_point_count() == POINT_ACTION_COUNT,
		"point Redos did not restore the authored path"
	)


func _verify_rejected_promotion_rebinds_action_record() -> void:
	_new_draft("Promotion Rebind")
	for stroke_index in range(6):
		var start_x := -0.22 + (float(stroke_index) * 0.075)
		_add_stroke(
			Vector3(start_x, 0.0, 0.0),
			Vector3(start_x + 0.045, 0.0, 0.0)
		)
	var state := controller.call("get_active_authoring_state") as Resource
	_require(
		bool(state.call("has_pending_bounded_history_promotion")),
		"sixth stroke did not stage the bounded-promotion fixture"
	)
	var transition_before_handle_activation := state.call(
		"get_bounded_history_transition"
	) as Dictionary
	var handle_activation := controller.call("activate_handle_tool") as Dictionary
	_require(
		not bool(handle_activation.get("ok", true))
		and StringName(handle_activation.get("reason", StringName()))
		== &"material_or_async_action_busy",
		"Handle activation interrupted an in-flight bounded promotion"
	)
	var transition_after_handle_activation := state.call(
		"get_bounded_history_transition"
	) as Dictionary
	_require(
		transition_after_handle_activation == transition_before_handle_activation,
		"rejected Handle activation mutated the pending transition"
	)
	# No presenter is attached in this verifier, so the controller's finite ACK
	# guard rejects the staged promotion, restores its body to pending, and then
	# recommits it through the fallback path.
	for _frame_index in range(24):
		await process_frame
		if (
			not bool(state.call("has_pending_bounded_history_promotion"))
			and int(controller.call("get_deferred_material_body_commit_count")) == 0
			and _pending_count() == 0
		):
			break
	_require(
		not bool(state.call("has_pending_bounded_history_promotion"))
		and int(controller.call("get_deferred_material_body_commit_count")) == 0,
		"rejected promotion did not settle"
	)
	_require(_pending_count() == 0, "rolled-back promotion body remained pending")
	_require(
		int(_summary().get("action_undo_count", -1)) == 6,
		"promotion retry duplicated or discarded an action record"
	)
	var layer_count_before_undo := int(_summary().get("active_tail_layer_count", -1))
	_require(bool(controller.call("undo_latest_action")), "retried layer action Undo failed")
	_require(
		int(_summary().get("active_tail_layer_count", -1))
		== layer_count_before_undo - 1,
		"retried layer action retained the stale pre-rollback layer identity"
	)


func _verify_native_layer_compatibility() -> void:
	_new_draft("Native Layer Compatibility")
	_add_stroke(Vector3(-0.08, 0.0, 0.0), Vector3(0.08, 0.0, 0.0))
	_require(
		int(_summary().get("action_undo_count", -1)) == 1,
		"native compatibility fixture did not begin with one action"
	)
	_require(bool(controller.call("undo_latest_layer")), "native layer Undo failed")
	_require(
		int(_summary().get("active_tail_layer_count", -1)) == 0,
		"native layer Undo retained the material layer"
	)
	_require(
		int(_summary().get("action_undo_count", -1)) == 0,
		"native layer mutation retained a stale action journal"
	)
	_require(bool(controller.call("redo_latest_layer")), "native layer Redo failed")
	_require(
		int(_summary().get("active_tail_layer_count", -1)) == 1,
		"native layer Redo did not restore the material layer"
	)
	_require(
		int(_summary().get("action_undo_count", -1)) == 0,
		"native layer Redo repopulated the player-facing action journal"
	)


func _verify_handle_create_and_atomic_change() -> void:
	_new_draft("Handle Actions")
	controller.call("set_active_tool_id", AuthoringStateScript.TOOL_HANDLES)
	controller.call(
		"set_active_profile_id",
		ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER
	)
	var original_points := [
		Vector3(-0.18, 0.0, 0.0),
		Vector3.ZERO,
		Vector3(0.18, 0.0, 0.0),
	]
	for point: Vector3 in original_points:
		controller.call("append_spline_line_point", point, Vector3.UP)
	_require(
		bool(controller.call("generate_profile_extrusion_from_spline")),
		"initial Handle generation failed"
	)
	var handle_layer := controller.call(
		"commit_pending_material_bodies_as_layer"
	) as Resource
	_require(handle_layer != null, "initial Handle commit failed")
	var state := controller.call("get_active_authoring_state") as Resource
	var original_handle := state.call("get_selected_material_body") as Resource
	_require(original_handle != null, "committed Handle body missing")
	var original_body_id := StringName(original_handle.get("body_id"))
	var count_before_create_undo := int(_summary().get("action_undo_count", -1))
	_require(bool(controller.call("undo_latest_action")), "Handle creation Undo failed")
	_require(
		int(_summary().get("protected_layer_count", -1)) == 0
		and _point_count() == 3,
		"Handle creation Undo did not restore its editable path"
	)
	_require(bool(controller.call("redo_latest_action")), "Handle creation Redo failed")
	_require(
		int(_summary().get("protected_layer_count", -1)) == 1,
		"Handle creation Redo did not restore protected Handle"
	)
	_require(
		int(_summary().get("action_undo_count", -1)) == count_before_create_undo,
		"Handle creation Undo/Redo changed the action count"
	)

	var activation := controller.call("activate_handle_tool") as Dictionary
	_require(
		bool(activation.get("ok", false))
		and bool(activation.get("handle_change_active", false)),
		"committed Handle did not enter Change Handle"
	)
	var first_edit := Vector3(0.0, 0.03, 0.01)
	_require(
		bool(controller.call("set_spline_line_point", 1, first_edit)),
		"local Handle point edit failed"
	)
	_require(bool(controller.call("undo_latest_action")), "local Handle edit Undo failed")
	_require(
		(_summary().get("spline_line", {}) as Dictionary)
		.get("points", PackedVector3Array())[1]
		== Vector3.ZERO,
		"local Handle edit Undo did not restore its point"
	)
	_require(bool(controller.call("redo_latest_action")), "local Handle edit Redo failed")
	var final_edit := Vector3(0.0, 0.045, 0.02)
	_require(
		bool(controller.call("set_spline_line_point", 1, final_edit)),
		"final local Handle point edit failed"
	)
	_require(
		bool(controller.call("generate_profile_extrusion_from_spline")),
		"Handle replacement apply failed"
	)
	var rotation_before_later_action := float(
		(controller.call("get_active_authoring_state") as Resource).get(
			"active_profile_rotation_degrees"
		)
	)
	controller.call("set_active_profile_rotation_degrees", 19.0)
	var replacement_layer := controller.call(
		"commit_pending_material_bodies_as_layer"
	) as Resource
	_require(replacement_layer != null, "Handle replacement commit failed")
	state = controller.call("get_active_authoring_state") as Resource
	var replacement_handle := state.call("get_selected_material_body") as Resource
	_require(replacement_handle != null, "replacement Handle body missing")
	var replacement_body_id := StringName(replacement_handle.get("body_id"))
	_require(replacement_body_id != original_body_id, "Handle replacement reused old identity")
	var count_before_change_undo := int(_summary().get("action_undo_count", -1))
	_require(
		bool(controller.call("undo_latest_action")),
		"later profile-rotation Undo failed"
	)
	state = controller.call("get_active_authoring_state") as Resource
	var handle_after_later_undo := state.call("get_selected_material_body") as Resource
	_require(
		handle_after_later_undo != null
		and StringName(handle_after_later_undo.get("body_id")) == replacement_body_id
		and is_equal_approx(
			float(state.get("active_profile_rotation_degrees")),
			rotation_before_later_action
		),
		"late Handle finalization reordered or absorbed the later edit"
	)
	_require(bool(controller.call("undo_latest_action")), "atomic Handle change Undo failed")
	state = controller.call("get_active_authoring_state") as Resource
	var restored_handle := state.call("get_selected_material_body") as Resource
	_require(
		restored_handle != null
		and StringName(restored_handle.get("body_id")) == original_body_id,
		"atomic Handle change Undo did not restore the original Handle"
	)
	_require(bool(controller.call("redo_latest_action")), "atomic Handle change Redo failed")
	state = controller.call("get_active_authoring_state") as Resource
	var redone_handle := state.call("get_selected_material_body") as Resource
	_require(
		redone_handle != null
		and StringName(redone_handle.get("body_id")) == replacement_body_id,
		"atomic Handle change Redo did not restore replacement Handle"
	)
	_require(
		is_equal_approx(
			float(state.get("active_profile_rotation_degrees")),
			rotation_before_later_action
		),
		"atomic Handle Redo leaked the later profile rotation"
	)
	_require(
		bool(controller.call("redo_latest_action")),
		"later profile-rotation Redo failed"
	)
	state = controller.call("get_active_authoring_state") as Resource
	_require(
		is_equal_approx(float(state.get("active_profile_rotation_degrees")), 19.0),
		"later profile rotation did not return on its own Redo"
	)
	_require(
		int(_summary().get("action_undo_count", -1)) == count_before_change_undo,
		"Handle replacement was not retained as one atomic action"
	)


func _verify_handle_replay_preserves_unrelated_pending() -> void:
	_new_draft("Handle Isolation")
	controller.call("set_active_tool_id", AuthoringStateScript.TOOL_HANDLES)
	controller.call(
		"set_active_profile_id",
		ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER
	)
	for point: Vector3 in [
		Vector3(-0.16, 0.0, 0.0),
		Vector3.ZERO,
		Vector3(0.16, 0.0, 0.0),
	]:
		controller.call("append_spline_line_point", point, Vector3.UP)
	_require(
		bool(controller.call("generate_profile_extrusion_from_spline")),
		"Handle-isolation generation failed"
	)
	_require(
		controller.call("commit_pending_material_bodies_as_layer") as Resource != null,
		"Handle-isolation commit failed"
	)
	var state := controller.call("get_active_authoring_state") as Resource
	# Add an unrelated pending body directly so Handle remains the latest user
	# action. A Handle replay is only allowed to touch the protected Handle lane.
	var unrelated_body := state.call("append_sample_material_body") as Resource
	_require(unrelated_body != null, "unrelated pending fixture creation failed")
	var unrelated_body_id := StringName(unrelated_body.get("body_id"))
	_require(
		bool((state.call(
			"capture_pending_body_bundle",
			unrelated_body_id
		) as Dictionary).get("ok", false)),
		"unrelated pending fixture was not editable"
	)
	_require(bool(controller.call("undo_latest_action")), "isolated Handle Undo failed")
	_require(
		int(_summary().get("protected_layer_count", -1)) == 0,
		"isolated Handle Undo retained the protected Handle"
	)
	_require(
		bool((state.call(
			"capture_pending_body_bundle",
			unrelated_body_id
		) as Dictionary).get("ok", false)),
		"Handle Undo removed unrelated pending work"
	)
	_require(bool(controller.call("redo_latest_action")), "isolated Handle Redo failed")
	_require(
		int(_summary().get("protected_layer_count", -1)) == 1,
		"isolated Handle Redo did not restore the protected Handle"
	)
	_require(
		bool((state.call(
			"capture_pending_body_bundle",
			unrelated_body_id
		) as Dictionary).get("ok", false)),
		"Handle Redo replaced unrelated pending work"
	)


func _verify_save_reload_lifetime_boundary() -> void:
	_new_draft("Save Lifetime")
	controller.call("set_active_tool_id", AuthoringStateScript.TOOL_SPLINE_LINE)
	controller.call("append_spline_line_point", Vector3.ZERO, Vector3.UP)
	var state := controller.call("get_active_authoring_state") as Resource
	var wip: Resource = CraftedItemWIPScript.new()
	wip.set("wip_id", &"verify_action_history_wip")
	wip.set("forge_project_name", "Save Lifetime")
	wip.set("forge_project_notes", "")
	wip.set("forge_builder_path_id", state.get("builder_path_id"))
	wip.set("forge_builder_component_id", state.get("builder_component_id"))
	wip.set("forge_intent", state.get("forge_intent"))
	wip.set("equipment_context", state.get("equipment_context"))
	wip.set("forge_v2_authoring_state", state.duplicate(true))
	_require(
		bool(controller.call("load_saved_wip", wip, true)),
		"save-style internal reload failed"
	)
	var preserved_count := int(_summary().get("action_undo_count", -1))
	_require(bool(controller.call("can_undo_action")), "save-style reload cleared history")
	_require(bool(controller.call("undo_latest_action")), "preserved Undo did not execute")
	_require(_point_count() == 0, "preserved Undo did not restore pre-action state")
	_require(bool(controller.call("redo_latest_action")), "preserved Redo did not execute")
	_require(_point_count() == 1, "preserved Redo did not restore saved state")
	_require(
		int(_summary().get("action_undo_count", -1)) == preserved_count,
		"save-style reload changed the action-history count"
	)
	_require(
		bool(controller.call("load_saved_wip", wip)),
		"explicit project load failed"
	)
	_require(
		not bool(controller.call("can_undo_action")),
		"explicit project load retained prior-session history"
	)


func _new_draft(label: String) -> void:
	controller.call("start_new_draft", label)
	_require(
		int(_summary().get("action_undo_count", -1)) == 0,
		"New Draft did not clear action history"
	)


func _add_stroke(start: Vector3, finish: Vector3) -> void:
	var body_id := StringName(controller.call(
		"begin_material_body_path",
		start,
		Vector3.UP
	))
	_require(body_id != StringName(), "stroke begin failed")
	_require(
		bool(controller.call(
			"finish_material_body_path",
			finish,
			true,
			Vector3.UP
		)),
		"stroke finish failed"
	)
	var finish_result := controller.call(
		"get_last_material_body_finish_result"
	) as Dictionary
	_require(
		bool(finish_result.get("committed", false)),
		"stroke was not synchronously committed"
	)


func _summary() -> Dictionary:
	return controller.call("get_status_summary") as Dictionary


func _point_count() -> int:
	return int(_summary().get("spline_line_point_count", -1))


func _pending_count() -> int:
	return int(_summary().get("pending_material_body_count", -1))


func _first_pending_body_id(state: Resource) -> StringName:
	if state == null:
		return StringName()
	for body_variant: Variant in state.get("material_bodies") as Array:
		var body := body_variant as Resource
		if body == null:
			continue
		var body_id := StringName(body.get("body_id"))
		if body_id == StringName():
			continue
		var bundle := state.call("capture_pending_body_bundle", body_id) as Dictionary
		if bool(bundle.get("ok", false)):
			return body_id
	return StringName()


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	if failure_message.is_empty():
		failure_message = message
	push_error(message)


func _stop_if_failed() -> void:
	if failure_message.is_empty():
		return
	_write_result(["ok=false", "error=%s" % failure_message])
	if controller != null and is_instance_valid(controller):
		controller.queue_free()
	quit(1)
	assert(false, failure_message)


func _write_result(lines: Array[String]) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
