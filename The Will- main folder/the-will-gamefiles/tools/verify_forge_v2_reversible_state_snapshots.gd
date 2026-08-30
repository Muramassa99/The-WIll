extends SceneTree

const ForgeV2AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_reversible_state_snapshots.json"
)

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	_verify_editor_transient_round_trip()
	_verify_pending_body_bundle_round_trip()
	_verify_protected_handle_round_trip()
	_verify_explicit_body_id_group_commit()
	_verify_layer_redo_helpers()
	var report := {
		"schema": "forge_v2_reversible_state_snapshots",
		"schema_version": 1,
		"ok": _failures.is_empty(),
		"checks": _checks,
		"failures": _failures,
	}
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	if not _failures.is_empty():
		push_error(
			"Forge V2 reversible-state verifier failed: %s"
			% "; ".join(_failures)
		)
	quit(0 if _failures.is_empty() else 1)


func _verify_editor_transient_round_trip() -> void:
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Editor Snapshot Verifier")
	state.call("reset_active_handle_profile_builder")
	state.call("set_active_handle_path_mode_id", &"handle_path_3_point_linear")
	state.set("active_profile_display_name", "Round-trip Handle")
	state.set("active_handle_source_profile_id", &"profile_handle_round_trip")
	state.set("active_handle_grid_snapping_enabled", true)
	state.set("active_basic_control_points_2d_meters", PackedVector2Array([
		Vector2(-0.04, -0.03),
		Vector2(0.04, -0.03),
		Vector2(0.05, 0.025),
		Vector2(-0.05, 0.025),
	]))
	var basic_metadata: Array[Dictionary] = [
		{"corner_id": &"corner_a", "nested": {"tag": "a"}},
		{"corner_id": &"corner_b", "radius_meters": 0.004},
		{"corner_id": &"corner_c"},
		{"corner_id": &"corner_d"},
	]
	state.set("active_basic_corner_metadata", basic_metadata)
	state.set("active_basic_next_corner_serial", 17)
	state.set("active_basic_grid_snapping_enabled", true)
	for point: Vector3 in [
		Vector3.ZERO,
		Vector3(0.16, 0.025, 0.01),
		Vector3(0.34, 0.0, 0.02),
	]:
		state.call("append_spline_line_point", point, Vector3.UP)
	state.call("finish_spline_line")
	var first_snapshot := state.call(
		"capture_editor_transient_snapshot"
	) as Dictionary
	# Establish the normalized canonical packet once, then test exact replay.
	state.call("restore_editor_transient_snapshot", first_snapshot)
	var expected_handle_snapshot := state.call(
		"capture_editor_transient_snapshot"
	) as Dictionary
	var checkpoint: Resource = state.get("bounded_history_checkpoint") as Resource
	var ledger: Resource = state.get("material_ledger") as Resource
	var transition_revision := int(state.get(
		"bounded_history_transition_revision"
	))
	var sentinel_body: Resource = state.call(
		"append_point_material_body",
		Vector3(0.7, 0.0, 0.0)
	) as Resource
	var sentinel_body_id := StringName(sentinel_body.get("body_id"))
	var material_count_with_sentinel := (
		(state.get("material_bodies") as Array).size()
	)
	var mutated_basic_metadata := (
		state.get("active_basic_corner_metadata") as Array
	)
	var mutated_first_corner := (
		mutated_basic_metadata[0] as Dictionary
	).duplicate()
	var mutated_nested_corner := (
		mutated_first_corner.get("nested", {}) as Dictionary
	).duplicate()
	mutated_nested_corner["tag"] = "mutated_after_capture"
	mutated_first_corner["nested"] = mutated_nested_corner
	mutated_basic_metadata[0] = mutated_first_corner
	state.set("active_basic_corner_metadata", mutated_basic_metadata)
	state.set("active_tool_id", &"tool_volume_stroke")
	state.set("active_profile_id", StringName())
	state.set("active_profile_display_name", "mutated")
	state.set("active_handle_control_points_2d_meters", PackedVector2Array())
	state.set("active_basic_corner_metadata", [])
	state.set("spline_line_points", PackedVector3Array())
	state.set("spline_line_surface_normals", PackedVector3Array())
	var handle_restored := bool(state.call(
		"restore_editor_transient_snapshot",
		expected_handle_snapshot
	))
	var actual_handle_snapshot := state.call(
		"capture_editor_transient_snapshot"
	) as Dictionary
	var handle_ok: bool = (
		handle_restored
		and actual_handle_snapshot == expected_handle_snapshot
		and _count_resources(expected_handle_snapshot) == 0
		and not _contains_full_state_key(expected_handle_snapshot)
		and state.get("bounded_history_checkpoint") == checkpoint
		and state.get("material_ledger") == ledger
		and int(state.get("bounded_history_transition_revision"))
		== transition_revision
		and (state.get("material_bodies") as Array).size()
		== material_count_with_sentinel
		and _find_body(state, sentinel_body_id) == sentinel_body
	)
	_record("editor_handle_profile_and_path_round_trip", handle_ok, {
		"restored": handle_restored,
		"resource_count": _count_resources(expected_handle_snapshot),
		"snapshot_keys": expected_handle_snapshot.keys(),
		"transition_revision_before": transition_revision,
		"transition_revision_after": int(state.get(
			"bounded_history_transition_revision"
		)),
	})

	state.call("set_active_tool_id", &"tool_detailing_brush")
	var detail_replaced := bool(state.call(
		"replace_detailing_brush_path_solution",
		PackedVector3Array([
			Vector3(0.0, 0.0, 0.0),
			Vector3(0.24, 0.0, 0.0),
		]),
		PackedVector3Array([Vector3.UP, Vector3.UP]),
		&"body",
		&"surface_round_trip",
		PackedVector3Array([
			Vector3(0.0, 0.0, 0.0),
			Vector3(0.12, 0.02, 0.0),
			Vector3(0.24, 0.0, 0.0),
		]),
		PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP]),
		PackedInt32Array([0, 2]),
		[true],
		[&"none"],
		true,
		&"none",
		1,
		PackedVector3Array([Vector3.DOWN, Vector3.DOWN]),
		PackedVector3Array([
			Vector3.DOWN,
			Vector3.DOWN,
			Vector3.DOWN,
		])
	))
	var detail_snapshot := state.call(
		"capture_editor_transient_snapshot"
	) as Dictionary
	state.call("restore_editor_transient_snapshot", detail_snapshot)
	var expected_detail_snapshot := state.call(
		"capture_editor_transient_snapshot"
	) as Dictionary
	var detail_transition_revision := int(state.get(
		"bounded_history_transition_revision"
	))
	state.call("set_active_tool_id", &"tool_spline_line")
	var detail_restored := bool(state.call(
		"restore_editor_transient_snapshot",
		expected_detail_snapshot
	))
	var actual_detail_snapshot := state.call(
		"capture_editor_transient_snapshot"
	) as Dictionary
	var detail_ok: bool = (
		detail_replaced
		and detail_restored
		and actual_detail_snapshot == expected_detail_snapshot
		and _count_resources(expected_detail_snapshot) == 0
		and int(state.get("bounded_history_transition_revision"))
		== detail_transition_revision
		and state.get("bounded_history_checkpoint") == checkpoint
	)
	_record("editor_detailing_solution_round_trip", detail_ok, {
		"solution_authored": detail_replaced,
		"restored": detail_restored,
		"resource_count": _count_resources(expected_detail_snapshot),
		"solution_valid": bool(state.get("detailing_solution_valid")),
		"resolved_point_count": (
			(state.get("detailing_resolved_path_points")
			as PackedVector3Array).size()
		),
	})


func _verify_pending_body_bundle_round_trip() -> void:
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Pending Bundle Verifier")
	state.call("append_point_material_body", Vector3(-0.25, 0.0, 0.0))
	var target: Resource = state.call(
		"append_point_material_body",
		Vector3.ZERO
	) as Resource
	state.call("append_point_material_body", Vector3(0.25, 0.0, 0.0))
	var target_id := StringName(target.get("body_id"))
	var source_id := &"legacy_source_round_trip"
	target.set("source_record_id", source_id)
	target.set("radius_meters", 0.075)
	target.set("handle_profile_authoring_snapshot", {
		"deep_copy_probe": {"value": "captured"},
	})
	target.call("normalize")
	var source_stroke: Resource = ForgeV2VolumeStrokeScript.new()
	source_stroke.set("stroke_id", source_id)
	source_stroke.set("path_points", PackedVector3Array([
		Vector3(-0.02, 0.0, 0.0),
		Vector3(0.02, 0.0, 0.0),
	]))
	source_stroke.set("radius_meters", 0.075)
	source_stroke.call("normalize")
	var stroke_array: Array[Resource] = []
	stroke_array.append(source_stroke)
	state.set("volume_strokes", stroke_array)
	state.call("select_material_body", target_id)
	var checkpoint: Resource = state.get("bounded_history_checkpoint") as Resource
	var transition_revision := int(state.get(
		"bounded_history_transition_revision"
	))
	var bundle := state.call("capture_pending_body_bundle", target_id) as Dictionary
	var captured_body := bundle.get("body", null) as Resource
	var captured_stroke := bundle.get("source_stroke", null) as Resource
	var captured_body_token := _resource_storage_token(captured_body)
	var captured_stroke_token := _resource_storage_token(captured_stroke)
	var body_index := int(bundle.get("body_index", -1))
	var stroke_index := int(bundle.get("source_stroke_index", -1))
	target.set("radius_meters", 0.19)
	var mutated_body_authoring := (
		target.get("handle_profile_authoring_snapshot") as Dictionary
	)
	var mutated_body_probe := (
		mutated_body_authoring.get("deep_copy_probe", {}) as Dictionary
	)
	mutated_body_probe["value"] = "mutated_after_capture"
	mutated_body_authoring["deep_copy_probe"] = mutated_body_probe
	target.set("handle_profile_authoring_snapshot", mutated_body_authoring)
	source_stroke.set("path_points", PackedVector3Array([Vector3(9.0, 9.0, 9.0)]))
	var removed := bool(state.call("remove_pending_body_bundle", target_id))
	var absent_after_remove := _find_body(state, target_id) == null
	var restored := bool(state.call("restore_pending_body_bundle", bundle))
	var restored_body := _find_body(state, target_id)
	var restored_stroke := _find_stroke(state, source_id)
	var duplicate_restore_rejected := not bool(state.call(
		"restore_pending_body_bundle",
		bundle
	))
	var pending_ok: bool = (
		bool(bundle.get("ok", false))
		and captured_body != null
		and captured_stroke != null
		and captured_body != target
		and captured_stroke != source_stroke
		and _count_resources(bundle) == 2
		and not _contains_full_state_key(bundle)
		and removed
		and absent_after_remove
		and restored
		and duplicate_restore_rejected
		and restored_body != null
		and restored_stroke != null
		and (state.get("material_bodies") as Array).find(restored_body)
		== body_index
		and (state.get("volume_strokes") as Array).find(restored_stroke)
		== stroke_index
		and _resource_storage_token(restored_body) == captured_body_token
		and _resource_storage_token(restored_stroke) == captured_stroke_token
		and StringName(state.get("selected_material_body_id")) == target_id
		and state.get("bounded_history_checkpoint") == checkpoint
		and int(state.get("bounded_history_transition_revision"))
		== transition_revision
	)
	_record("pending_body_bundle_exact_round_trip", pending_ok, {
		"captured": bool(bundle.get("ok", false)),
		"removed": removed,
		"restored": restored,
		"body_index": body_index,
		"restored_body_index": (
			(state.get("material_bodies") as Array).find(restored_body)
		),
		"stroke_index": stroke_index,
		"restored_stroke_index": (
			(state.get("volume_strokes") as Array).find(restored_stroke)
		),
		"resource_count": _count_resources(bundle),
	})
	if restored_body != null:
		restored_body.set("committed_layer_id", &"fake_committed_layer")
	var committed_capture_rejected := not bool((state.call(
		"capture_pending_body_bundle",
		target_id
	) as Dictionary).get("ok", false))
	var committed_remove_rejected := not bool(state.call(
		"remove_pending_body_bundle",
		target_id
	))
	_record(
		"pending_bundle_rejects_committed_body",
		committed_capture_rejected and committed_remove_rejected,
		{
			"capture_rejected": committed_capture_rejected,
			"remove_rejected": committed_remove_rejected,
		}
	)


func _verify_protected_handle_round_trip() -> void:
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Protected Handle Snapshot Verifier")
	var ordinary_body: Resource = state.call(
		"append_point_material_body",
		Vector3(-0.45, 0.0, 0.0)
	) as Resource
	var ordinary_layer: Resource = state.call(
		"commit_material_body_as_layer",
		StringName(ordinary_body.get("body_id"))
	) as Resource
	state.call("reset_active_handle_profile_builder")
	for point: Vector3 in [
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.16, 0.03, 0.0),
		Vector3(0.34, 0.0, 0.0),
	]:
		state.call("append_spline_line_point", point, Vector3.UP)
	var finished := bool(state.call("finish_spline_line"))
	var generated := bool(state.call("generate_profile_extrusion_from_spline"))
	var handle_body: Resource = state.call("get_selected_material_body") as Resource
	var handle_layer: Resource = state.call(
		"commit_material_body_as_layer",
		StringName(handle_body.get("body_id"))
	) as Resource
	var snapshot := state.call(
		"capture_protected_handle_snapshot"
	) as Dictionary
	var captured_body := snapshot.get("body", null) as Resource
	var captured_layer := snapshot.get("layer", null) as Resource
	var captured_body_token := _resource_storage_token(captured_body)
	var captured_layer_token := _resource_storage_token(captured_layer)
	var checkpoint: Resource = state.get("bounded_history_checkpoint") as Resource
	var ledger: Resource = state.get("material_ledger") as Resource
	var ordinary_body_id := StringName(ordinary_body.get("body_id"))
	var ordinary_layer_id := StringName(ordinary_layer.get("layer_id"))
	var empty_state: Resource = ForgeV2AuthoringStateScript.new()
	empty_state.call("reset_new_draft", "Empty Handle Snapshot")
	var empty_snapshot := empty_state.call(
		"capture_protected_handle_snapshot"
	) as Dictionary
	if handle_body != null:
		handle_body.set("path_points", PackedVector3Array([
			Vector3.ZERO,
			Vector3(8.0, 0.0, 0.0),
			Vector3(9.0, 0.0, 0.0),
		]))
		var mutated_handle_authoring := (
			handle_body.get("handle_profile_authoring_snapshot") as Dictionary
		)
		mutated_handle_authoring["deep_copy_probe"] = {
			"value": "mutated_after_capture",
		}
		handle_body.set(
			"handle_profile_authoring_snapshot",
			mutated_handle_authoring
		)
	if handle_layer != null:
		var mutated_ledger_delta := (
			handle_layer.get("ledger_delta") as Dictionary
		)
		mutated_ledger_delta[&"mutated"] = {"value": 999}
		handle_layer.set("ledger_delta", mutated_ledger_delta)
	var empty_revision_before := int(state.get(
		"bounded_history_transition_revision"
	))
	var emptied := bool(state.call(
		"restore_protected_handle_snapshot",
		empty_snapshot
	))
	var empty_transition := state.call(
		"get_bounded_history_transition"
	) as Dictionary
	var empty_ok: bool = (
		bool(empty_snapshot.get("ok", false))
		and bool(empty_snapshot.get("empty", false))
		and _count_resources(empty_snapshot) == 0
		and emptied
		and int(state.get("bounded_history_transition_revision"))
		== empty_revision_before + 1
		and StringName(empty_transition.get("kind", StringName()))
		== &"protected_changed"
		and (state.get("protected_forge_layers") as Array).is_empty()
		and int(state.call("get_handle_material_body_count")) == 0
		and _find_body(state, ordinary_body_id) == ordinary_body
		and _find_layer(state.get("forge_layers") as Array, ordinary_layer_id)
		== ordinary_layer
		and state.get("bounded_history_checkpoint") == checkpoint
		and state.get("material_ledger") == ledger
	)
	_record("protected_handle_empty_snapshot_apply", empty_ok, {
		"restored": emptied,
		"resource_count": _count_resources(empty_snapshot),
		"transition_kind": String(empty_transition.get("kind", StringName())),
		"handle_count": int(state.call("get_handle_material_body_count")),
	})
	var restore_revision_before := int(state.get(
		"bounded_history_transition_revision"
	))
	var restored := bool(state.call(
		"restore_protected_handle_snapshot",
		snapshot
	))
	var restored_body := _find_body(
		state,
		StringName(snapshot.get("body_id", StringName()))
	)
	var restored_layer := _find_layer(
		state.get("protected_forge_layers") as Array,
		StringName(snapshot.get("layer_id", StringName()))
	)
	var restore_transition := state.call(
		"get_bounded_history_transition"
	) as Dictionary
	var protected_ok: bool = (
		finished
		and generated
		and handle_layer != null
		and bool(snapshot.get("ok", false))
		and not bool(snapshot.get("empty", true))
		and captured_body != null
		and captured_layer != null
		and captured_body != handle_body
		and captured_layer != handle_layer
		and _count_resources(snapshot) == 2
		and not _contains_full_state_key(snapshot)
		and restored
		and restored_body != null
		and restored_layer != null
		and restored_body != captured_body
		and restored_layer != captured_layer
		and _resource_storage_token(restored_body) == captured_body_token
		and _resource_storage_token(restored_layer) == captured_layer_token
		and (state.get("material_bodies") as Array).find(restored_body)
		== int(snapshot.get("body_index", -1))
		and (state.get("protected_forge_layers") as Array).find(restored_layer)
		== int(snapshot.get("layer_index", -1))
		and int(state.get("bounded_history_transition_revision"))
		== restore_revision_before + 1
		and StringName(restore_transition.get("kind", StringName()))
		== &"protected_changed"
		and _find_body(state, ordinary_body_id) == ordinary_body
		and _find_layer(state.get("forge_layers") as Array, ordinary_layer_id)
		== ordinary_layer
		and state.get("bounded_history_checkpoint") == checkpoint
		and state.get("material_ledger") == ledger
	)
	_record("protected_handle_exact_round_trip", protected_ok, {
		"finished": finished,
		"generated": generated,
		"committed": handle_layer != null,
		"captured": bool(snapshot.get("ok", false)),
		"restored": restored,
		"resource_count": _count_resources(snapshot),
		"body_index": int(snapshot.get("body_index", -1)),
		"restored_body_index": (
			(state.get("material_bodies") as Array).find(restored_body)
		),
		"layer_index": int(snapshot.get("layer_index", -1)),
		"restored_layer_index": (
			(state.get("protected_forge_layers") as Array).find(restored_layer)
		),
	})
	if restored_body != null:
		var duplicate_handle := restored_body.duplicate(true) as Resource
		duplicate_handle.set("body_id", &"duplicate_handle_for_rejection")
		duplicate_handle.set("committed_layer_id", StringName())
		(state.get("material_bodies") as Array).append(duplicate_handle)
		var invalid_capture := state.call(
			"capture_protected_handle_snapshot"
		) as Dictionary
		_record(
			"protected_handle_snapshot_enforces_single_handle",
			not bool(invalid_capture.get("ok", false)),
			{"reason": String(invalid_capture.get("reason", StringName()))}
		)


func _verify_explicit_body_id_group_commit() -> void:
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Explicit Body Group Verifier")
	var first_body: Resource = state.call(
		"append_point_material_body",
		Vector3(-0.3, 0.0, 0.0)
	) as Resource
	var middle_body: Resource = state.call(
		"append_point_material_body",
		Vector3.ZERO
	) as Resource
	var last_body: Resource = state.call(
		"append_point_material_body",
		Vector3(0.3, 0.0, 0.0)
	) as Resource
	if first_body == null or middle_body == null or last_body == null:
		_record("explicit_body_id_group_setup", false, {
			"first_created": first_body != null,
			"middle_created": middle_body != null,
			"last_created": last_body != null,
		})
		return
	var first_body_id := StringName(first_body.get("body_id"))
	var middle_body_id := StringName(middle_body.get("body_id"))
	var last_body_id := StringName(last_body.get("body_id"))
	var empty_ids: Array[StringName] = []
	var duplicate_ids: Array[StringName] = [first_body_id, first_body_id]
	var missing_ids: Array[StringName] = [
		first_body_id,
		&"missing_body_id",
	]
	var empty_rejected := state.call(
		"commit_material_body_ids_as_layer",
		empty_ids
	) == null
	var duplicate_rejected := state.call(
		"commit_material_body_ids_as_layer",
		duplicate_ids
	) == null
	var missing_rejected := state.call(
		"commit_material_body_ids_as_layer",
		missing_ids
	) == null
	middle_body.set("source_record_id", &"source_alias_must_not_resolve")
	var alias_ids: Array[StringName] = [&"source_alias_must_not_resolve"]
	var alias_rejected := state.call(
		"commit_material_body_ids_as_layer",
		alias_ids
	) == null
	middle_body.set("layer_active", false)
	var inactive_ids: Array[StringName] = [middle_body_id]
	var inactive_rejected := state.call(
		"commit_material_body_ids_as_layer",
		inactive_ids
	) == null
	middle_body.set("layer_active", true)
	middle_body.set("shape_kind", &"shape_kind_profile_path")
	var not_ready_ids: Array[StringName] = [first_body_id, middle_body_id]
	var not_ready_rejected := state.call(
		"commit_material_body_ids_as_layer",
		not_ready_ids
	) == null
	middle_body.set("shape_kind", &"shape_kind_capsule_path")
	var invalid_requests_were_atomic := (
		(state.get("forge_layers") as Array).is_empty()
		and StringName(first_body.get("committed_layer_id")) == StringName()
		and StringName(middle_body.get("committed_layer_id")) == StringName()
		and StringName(last_body.get("committed_layer_id")) == StringName()
	)
	_record("explicit_body_id_group_rejects_invalid_requests", (
		empty_rejected
		and duplicate_rejected
		and missing_rejected
		and alias_rejected
		and inactive_rejected
		and not_ready_rejected
		and invalid_requests_were_atomic
	), {
		"empty_rejected": empty_rejected,
		"duplicate_rejected": duplicate_rejected,
		"missing_rejected": missing_rejected,
		"source_alias_rejected": alias_rejected,
		"inactive_rejected": inactive_rejected,
		"not_ready_rejected": not_ready_rejected,
		"invalid_requests_were_atomic": invalid_requests_were_atomic,
	})
	var ordered_ids: Array[StringName] = [last_body_id, first_body_id]
	var layer: Resource = state.call(
		"commit_material_body_ids_as_layer",
		ordered_ids
	) as Resource
	var layer_body_ids: Array = []
	if layer != null:
		layer_body_ids = layer.get("body_ids") as Array
	var layer_id := (
		StringName(layer.get("layer_id")) if layer != null else StringName()
	)
	var repeat_rejected := state.call(
		"commit_material_body_ids_as_layer",
		ordered_ids
	) == null
	var ordered_group_ok := (
		layer != null
		and layer_body_ids == ordered_ids
		and StringName(last_body.get("committed_layer_id")) == layer_id
		and StringName(first_body.get("committed_layer_id")) == layer_id
		and StringName(middle_body.get("committed_layer_id")) == StringName()
		and bool(state.call("is_material_body_commit_ready", middle_body_id))
		and (state.get("forge_layers") as Array).size() == 1
		and repeat_rejected
	)
	_record("explicit_body_id_group_preserves_requested_order", ordered_group_ok, {
		"requested_body_ids": ordered_ids,
		"layer_body_ids": layer_body_ids,
		"middle_remains_pending": (
			StringName(middle_body.get("committed_layer_id")) == StringName()
		),
		"repeat_rejected": repeat_rejected,
	})


func _verify_layer_redo_helpers() -> void:
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Layer Redo Helper Verifier")
	var first_body: Resource = state.call(
		"append_point_material_body",
		Vector3(-0.2, 0.0, 0.0)
	) as Resource
	var first_layer: Resource = state.call(
		"commit_material_body_as_layer",
		StringName(first_body.get("body_id"))
	) as Resource
	var second_body: Resource = state.call(
		"append_point_material_body",
		Vector3(0.2, 0.0, 0.0)
	) as Resource
	var second_body_id := StringName(second_body.get("body_id"))
	var second_layer: Resource = state.call(
		"commit_material_body_as_layer",
		second_body_id
	) as Resource
	var second_layer_id := StringName(second_layer.get("layer_id"))
	var undo_peek_before := StringName(state.call("peek_latest_undo_layer_id"))
	var undone := bool(state.call("undo_latest_layer"))
	var undo_peek_after := StringName(state.call("peek_latest_undo_layer_id"))
	var redo_peek := StringName(state.call("peek_latest_redo_layer_id"))
	var revision_before_discard := int(state.get(
		"bounded_history_transition_revision"
	))
	var discarded := bool(state.call("discard_abandoned_layer_redo"))
	var redo_peek_after := StringName(state.call("peek_latest_redo_layer_id"))
	var helper_ok := (
		first_layer != null
		and second_layer != null
		and undo_peek_before == second_layer_id
		and undone
		and undo_peek_after == StringName(first_layer.get("layer_id"))
		and redo_peek == second_layer_id
		and discarded
		and redo_peek_after == StringName()
		and int(state.call("get_undone_layer_count")) == 0
		and _find_body(state, second_body_id) == null
		and int(state.get("bounded_history_transition_revision"))
		== revision_before_discard
		and not bool(state.call("discard_abandoned_layer_redo"))
	)
	_record("explicit_layer_redo_helpers", helper_ok, {
		"undo_peek_before": String(undo_peek_before),
		"undo_peek_after": String(undo_peek_after),
		"redo_peek": String(redo_peek),
		"redo_peek_after_discard": String(redo_peek_after),
		"discarded": discarded,
	})


func _find_body(state: Resource, body_id: StringName) -> Resource:
	if state == null or body_id == StringName():
		return null
	for body_variant: Variant in state.get("material_bodies") as Array:
		if not body_variant is Resource or body_variant == null:
			continue
		var body := body_variant as Resource
		if StringName(body.get("body_id")) == body_id:
			return body
	return null


func _find_stroke(state: Resource, stroke_id: StringName) -> Resource:
	if state == null or stroke_id == StringName():
		return null
	for stroke_variant: Variant in state.get("volume_strokes") as Array:
		if not stroke_variant is Resource or stroke_variant == null:
			continue
		var stroke := stroke_variant as Resource
		if StringName(stroke.get("stroke_id")) == stroke_id:
			return stroke
	return null


func _find_layer(layers: Array, layer_id: StringName) -> Resource:
	for layer_variant: Variant in layers:
		if not layer_variant is Resource or layer_variant == null:
			continue
		var layer := layer_variant as Resource
		if StringName(layer.get("layer_id")) == layer_id:
			return layer
	return null


func _resource_storage_token(resource: Resource) -> Dictionary:
	var token := {}
	if resource == null:
		return token
	for property_variant: Variant in resource.get_property_list():
		var property := property_variant as Dictionary
		if int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var property_name := StringName(property.get("name", StringName()))
		if property_name in [&"script", &"resource_path", &"resource_name"]:
			continue
		var value: Variant = resource.get(property_name)
		if value is Object:
			continue
		token[property_name] = var_to_str(value)
	return token


func _count_resources(value: Variant) -> int:
	if value is Resource:
		return 1
	var count := 0
	if value is Dictionary:
		for nested_value: Variant in (value as Dictionary).values():
			count += _count_resources(nested_value)
	elif value is Array:
		for nested_value: Variant in value as Array:
			count += _count_resources(nested_value)
	return count


func _contains_full_state_key(snapshot: Dictionary) -> bool:
	for forbidden_key: String in [
		"material_bodies",
		"volume_strokes",
		"forge_layers",
		"undone_forge_layers",
		"protected_forge_layers",
		"bounded_history_checkpoint",
		"material_ledger",
	]:
		if snapshot.has(forbidden_key):
			return true
	return false


func _record(check_name: String, ok: bool, evidence: Dictionary) -> void:
	_checks[check_name] = {
		"ok": ok,
		"evidence": evidence,
	}
	if not ok:
		_failures.append(check_name)
