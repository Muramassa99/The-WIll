extends SceneTree

const AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const PlacementTargetResolverScript = preload(
	"res://runtime/forge_v2/forge_v2_placement_target_resolver.gd"
)
const StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const StressFixtureScript = preload(
	"res://tools/forge_v2_workpiece_stress_fixture.gd"
)
const WorkspacePreviewScript = preload(
	"res://runtime/forge_v2/forge_v2_workspace_preview.gd"
)
const MeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)
const VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const EXTENSION_PATH := (
	"res://native/forge_v2_manifold/forge_v2_manifold.gdextension"
)
const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/verify_forge_v2_bounded_add_history.json"
)
const SAVE_PATH := (
	"C:/WORKSPACE/godot_runs/verify_forge_v2_bounded_add_history_wip.tres"
)
const ADD_MATERIAL_ID := &"mat_iron_gray"
const HANDLE_MATERIAL_ID := &"mat_wood_gray"
const TOTAL_ADD_STROKES := 20
const TAIL_CAPACITY := 5
const LOGICAL_BODY_LIMIT := 7
const NATIVE_RETAINED_STATE_LIMIT := 6
const CACHE_BODY_TOKEN_LIMIT := 7
const READINESS_FRAME_LIMIT := 240
const SURFACE_DISTANCE_LIMIT_METERS := 0.00005
const ABSOLUTE_WINDING_INSIDE_MIN := 0.90
const BOUNDS_LIMIT_METERS := 0.00001
const VOLUME_ABSOLUTE_LIMIT_M3 := 0.0000000005
const VOLUME_RELATIVE_LIMIT := 0.0001
const TARGET_POSITION_LIMIT_METERS := 0.00030
const TARGET_NORMAL_DOT_MIN := 0.99
const TARGET_ABC_DOT_MAX := -0.99
const DIRECT_RAY_OFFSET_METERS := 0.004
const CAMERA_DISTANCE_METERS := 0.30
const DIRECT_PROTECTED_COMPOSITE_KIND := (
	&"native_protected_live_decomposition"
)
const CURRENT_CSG_PROTECTED_COMPOSITE_KIND := &"handle_composite"
const ORDINARY_SOURCE_ID := 0
const PROTECTED_HANDLE_SOURCE_ID := 1
const SUBTRACTION_SOURCE_ID := 2
const PROTECTED_HANDLE_BOOTSTRAP_NAME := (
	&"NativeProtectedHandleExactMeshBootstrap"
)

var _controller: Node
var _state: Resource
var _workspace: Node3D
var _presenter: Node3D
var _handle: Resource
var _add_bodies: Array[Resource] = []
var _failures: Array[String] = []
var _checkpoint_rows: Array[Dictionary] = []
var _mutation_rows: Array[Dictionary] = []
var _navigation_rows: Array[Dictionary] = []
var _parity_rows: Array[Dictionary] = []
var _target_rows: Array[Dictionary] = []
var _atomic_rejection_rows: Array[Dictionary] = []
var _protected_publication_rows: Array[Dictionary] = []
var _gates := {
	"production_controller_presenter_native_path": true,
	"one_real_protected_handle": true,
	"all_protected_publications_use_direct_native_composite": true,
	"zero_final_protected_composition_csg_fallback": true,
	"handle_only_final_publication_direct": true,
	"protected_handle_bootstrap_pending_only_and_final_revision_free": true,
	"direct_protected_composition_kind_or_current_csg_fallback": true,
	"direct_protected_composite_surface_count_or_current_csg_fallback": true,
	"direct_protected_composite_material_presence_or_current_csg_fallback": true,
	"direct_protected_composite_source_material_classified_or_current_csg_fallback": true,
	"direct_protected_composite_no_empty_surface_or_current_csg_fallback": true,
	"direct_protected_composite_one_concave_collider_or_current_csg_fallback": true,
	"direct_protected_composite_no_csg_node_or_current_csg_fallback": true,
	"live_decomposed_handle_and_clipped_rest_lanes": true,
	"n5_checkpoint0_tail5": true,
	"n6_checkpoint1_tail5": true,
	"n20_checkpoint15_tail5": true,
	"logical_and_native_state_bounded": true,
	"ledger_and_resolver_cache_bounded": true,
	"one_native_mutation_and_export_per_add": true,
	"promotion_has_no_extra_boolean_or_export": true,
	"hot_path_never_materializes_checkpoint": true,
	"exactly_five_undos_and_five_redos": true,
	"branch_clears_redo_and_preserves_checkpoint": true,
	"unsupported_and_mixed_material_rejection_atomic": true,
	"surface_target_identity_tracks_navigation": true,
	"real_resolver_abc_covers_ordinary_and_handle": true,
	"current_csg_surface_topology_bounds_volume_parity": true,
	"current_csg_material_and_normal_parity": true,
	"direct_protected_composite_exact_oracle_material_set_at_parity": true,
	"final_extraction_full_compose_single_watertight_component": true,
	"save_materialize_restore_and_controller_rebind": true,
}
var _report := {
	"schema": "forge_v2_bounded_add_history",
	"schema_version": 4,
	"ok": false,
	"production_files_touched": false,
	"runtime_executed_during_authoring": false,
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	var extension_resource := load(EXTENSION_PATH)
	if (
		extension_resource == null
		or not ClassDB.class_exists(&"ForgeV2ManifoldBoolean")
	):
		_finish_failure("native ForgeV2ManifoldBoolean is unavailable")
		return
	var fixture_preflight := StressFixtureScript.preflight(
		TOTAL_ADD_STROKES
	) as Dictionary
	if not bool(fixture_preflight.get("ok", false)):
		_finish_failure("deterministic connected fixture preflight failed")
		return

	_controller = StageControllerScript.new()
	_controller.name = "BoundedAddHistoryVerifierController"
	root.add_child(_controller)
	await process_frame
	_state = _controller.call("get_active_authoring_state") as Resource
	if _state == null:
		_finish_failure("production stage controller created no state")
		return
	_workspace = WorkspacePreviewScript.new()
	_workspace.name = "BoundedAddHistoryVerifierWorkspace"
	root.add_child(_workspace)
	await process_frame
	_presenter = _workspace.get("volume_preview_presenter") as Node3D
	if (
		_presenter == null
		or not _presenter.has_method("get_native_static_sync_diagnostics")
	):
		_finish_failure("production workspace created no native presenter")
		return
	_workspace.call("bind_stage_controller", _controller)
	await process_frame
	await physics_frame

	_handle = _build_real_handle()
	_append_pending_body(_state, _handle)
	var handle_layer := _state.call(
		"commit_material_body_as_layer",
		StringName(_handle.get("body_id"))
	) as Resource
	if handle_layer == null:
		_finish_failure("real Handle commit failed")
		return
	_emit_state_changed()
	var handle_ready := await _await_native_publication(
		"protected_changed"
	)
	if not bool(handle_ready.get("ok", false)):
		_finish_failure("Handle-only native publication did not become ready")
		return
	_verify_handle_lane(handle_layer)

	var boundary_targets := {}
	for add_index in range(TOTAL_ADD_STROKES):
		var body := (
			StressFixtureScript.build_seed_body()
			if add_index == 0
			else StressFixtureScript.build_operation_body(add_index - 1)
		) as Resource
		if body == null:
			_finish_failure("Add fixture body %d is missing" % add_index)
			return
		_add_bodies.append(body)
		_append_pending_body(_state, body)
		var before_native := _native_diagnostics()
		var layer := _state.call(
			"commit_material_body_as_layer",
			StringName(body.get("body_id"))
		) as Resource
		if layer == null:
			_finish_failure("Add commit failed at N=%d" % (add_index + 1))
			return
		_emit_state_changed()
		var deposited_count := add_index + 1
		var expected_mode := (
			"reset"
			if deposited_count == 1
			else "append"
			if deposited_count <= TAIL_CAPACITY
			else "promotion_append"
		)
		var ready := await _await_native_publication(expected_mode)
		if not bool(ready.get("ok", false)):
			_finish_failure(
				"native publication failed at N=%d" % deposited_count
			)
			return
		var after_native := _native_diagnostics()
		_record_add_counter_contract(
			deposited_count,
			before_native,
			after_native
		)
		_assert_hot_checkpoint_contract(
			after_native,
			"deposit_%02d" % deposited_count
		)
		if deposited_count in [5, 6, TOTAL_ADD_STROKES]:
			_capture_bounded_state_gate(deposited_count)
			var parity := await _capture_current_csg_parity(
				"N%d" % deposited_count,
				_body_prefix(_add_bodies, deposited_count)
			)
			_parity_rows.append(parity)
			if not bool(parity.get("ok", false)):
				_mark(
					"current_csg_surface_topology_bounds_volume_parity",
					false,
					"current-CSG parity failed at N=%d" % deposited_count
				)
			boundary_targets[deposited_count] = _publication_identity()

	var n20_publication := _capture_native_publication()
	var n20_mesh := _bake_publication_mesh(n20_publication)
	var abc := await _capture_real_resolver_abc(
		n20_publication,
		n20_mesh,
		"N20"
	)
	_target_rows.append_array(abc.get("rows", []) as Array[Dictionary])
	_mark(
		"real_resolver_abc_covers_ordinary_and_handle",
		bool(abc.get("ok", false)),
		"real resolver A/B/C did not cover ordinary, Handle, ordinary"
	)

	_verify_atomic_rejection(
		_build_rejection_body(
			&"bounded_reject_different_material",
			HANDLE_MATERIAL_ID,
			VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
		),
		"different_material"
	)
	_verify_atomic_rejection(
		_build_rejection_body(
			&"bounded_reject_empty_only",
			ADD_MATERIAL_ID,
			VolumeStrokeScript.PLACEMENT_EMPTY_ONLY
		),
		"unsupported_placement"
	)
	_assert_hot_checkpoint_contract(
		_native_diagnostics(),
		"after_atomic_rejections"
	)

	var navigation_target_ids: Array[StringName] = []
	navigation_target_ids.append(StringName(
		(boundary_targets.get(TOTAL_ADD_STROKES, {}) as Dictionary).get(
			"surface_target_id",
			StringName()
		)
	))
	for undo_index in range(TAIL_CAPACITY):
		var undo_before := _native_diagnostics()
		if not bool(_state.call("undo_latest_layer")):
			_finish_failure("undo %d of five failed" % (undo_index + 1))
			return
		_emit_state_changed()
		var undo_ready := await _await_native_publication("undo")
		if not bool(undo_ready.get("ok", false)):
			_finish_failure("undo publication %d failed" % (undo_index + 1))
			return
		var undo_after := _native_diagnostics()
		_record_navigation_counter_contract(
			"undo_%d" % (undo_index + 1),
			undo_before,
			undo_after
		)
		navigation_target_ids.append(StringName(
			_publication_identity().get("surface_target_id", StringName())
		))
	var before_failed_sixth := _atomic_state_snapshot()
	var before_failed_sixth_native := _native_diagnostics()
	var sixth_undo_succeeded := bool(_state.call("undo_latest_layer"))
	var after_failed_sixth := _atomic_state_snapshot()
	var after_failed_sixth_native := _native_diagnostics()
	_mark(
		"exactly_five_undos_and_five_redos",
		not sixth_undo_succeeded
		and _snapshot_digest(before_failed_sixth)
		== _snapshot_digest(after_failed_sixth)
		and _history_counters_equal(
			before_failed_sixth_native,
			after_failed_sixth_native
		),
		"sixth undo succeeded or mutated state"
	)

	for redo_index in range(TAIL_CAPACITY):
		var redo_before := _native_diagnostics()
		if not bool(_state.call("redo_latest_layer")):
			_finish_failure("redo %d of five failed" % (redo_index + 1))
			return
		_emit_state_changed()
		var redo_ready := await _await_native_publication("redo")
		if not bool(redo_ready.get("ok", false)):
			_finish_failure("redo publication %d failed" % (redo_index + 1))
			return
		var redo_after := _native_diagnostics()
		_record_navigation_counter_contract(
			"redo_%d" % (redo_index + 1),
			redo_before,
			redo_after
		)
		navigation_target_ids.append(StringName(
			_publication_identity().get("surface_target_id", StringName())
		))
	_mark(
		"exactly_five_undos_and_five_redos",
		int(_state.call("get_active_tail_layer_count")) == TAIL_CAPACITY
		and int(_state.call("get_undone_layer_count")) == 0,
		"five redos did not restore the full tail"
	)

	for branch_undo_index in range(2):
		if not bool(_state.call("undo_latest_layer")):
			_finish_failure("branch setup undo failed")
			return
		_emit_state_changed()
		if not bool((await _await_native_publication("undo")).get("ok", false)):
			_finish_failure("branch setup undo publication failed")
			return
		navigation_target_ids.append(StringName(
			_publication_identity().get("surface_target_id", StringName())
		))
	var branch_body := StressFixtureScript.build_operation_body(
		TOTAL_ADD_STROKES - 1
	) as Resource
	_append_pending_body(_state, branch_body)
	var before_branch := _native_diagnostics()
	var branch_layer := _state.call(
		"commit_material_body_as_layer",
		StringName(branch_body.get("body_id"))
	) as Resource
	if branch_layer == null:
		_finish_failure("branch Add commit failed")
		return
	_emit_state_changed()
	if not bool((await _await_native_publication("append")).get("ok", false)):
		_finish_failure("branch Add publication failed")
		return
	var after_branch := _native_diagnostics()
	_record_add_counter_contract(21, before_branch, after_branch, true)
	var branch_presentation := _presentation()
	var branch_shape_ok := (
		int(branch_presentation.get("checkpoint_operation_count", -1)) == 15
		and int((branch_presentation.get(
			"active_tail_layers", []
		) as Array).size()) == 4
		and int((branch_presentation.get(
			"redo_tail_layers", []
		) as Array).size()) == 0
		and int(branch_presentation.get("logical_body_count", -1)) == 6
		and int(after_branch.get("retained_state_count", -1)) == 5
		and int(after_branch.get("redo_count", -1)) == 0
	)
	_mark(
		"branch_clears_redo_and_preserves_checkpoint",
		branch_shape_ok
		and not bool(_state.call("redo_latest_layer")),
		"branch did not preserve checkpoint15/tail4 or clear redo"
	)
	var branch_target := _publication_identity()
	navigation_target_ids.append(StringName(branch_target.get(
		"surface_target_id",
		StringName()
	)))
	var branch_bodies := _body_prefix(_add_bodies, 18)
	branch_bodies.append(branch_body)
	var branch_parity := await _capture_current_csg_parity(
		"BranchN19",
		branch_bodies
	)
	_parity_rows.append(branch_parity)
	_mark(
		"branch_clears_redo_and_preserves_checkpoint",
		bool(branch_parity.get("ok", false)),
		"branch geometry failed current-CSG parity"
	)
	_assert_hot_checkpoint_contract(after_branch, "branch")
	_verify_target_identity_sequence(navigation_target_ids)

	var lifecycle := await _verify_save_restore_rebind(
		branch_bodies,
		StringName(branch_target.get("surface_target_id", StringName()))
	)
	_mark(
		"save_materialize_restore_and_controller_rebind",
		bool(lifecycle.get("ok", false)),
		"save/materialize/restore/controller-rebind lifecycle failed"
	)
	var final_extraction := _verify_final_extraction()
	_mark(
		"final_extraction_full_compose_single_watertight_component",
		bool(final_extraction.get("ok", false)),
		"retained full native compose did not extract one watertight shell"
	)
	var protected_publication_summary := (
		_build_protected_publication_summary()
	)
	var final_native_diagnostics := _native_diagnostics()
	_mark(
		"all_protected_publications_use_direct_native_composite",
		int(protected_publication_summary.get(
			"checked_publication_count", 0
		)) > 0
		and int(protected_publication_summary.get(
			"direct_publication_count", -1
		)) == int(protected_publication_summary.get(
			"checked_publication_count", -2
		))
		and int(protected_publication_summary.get(
			"current_csg_fallback_count", -1
		)) == 0,
		"not every protected publication used direct native composition"
	)
	_mark(
		"zero_final_protected_composition_csg_fallback",
		int(final_native_diagnostics.get(
			"protected_composition_csg_fallback_count", -1
		)) == 0
		and int(final_native_diagnostics.get("fallback_count", -1)) == 0
		and int(protected_publication_summary.get(
			"current_csg_fallback_count", -1
		)) == 0,
		"final protected-composition diagnostics retained a CSG fallback"
	)

	var passed := _failures.is_empty()
	for gate_value: Variant in _gates.values():
		passed = passed and bool(gate_value)
	_report.merge({
		"ok": passed,
		"outcome": "pass" if passed else "fail",
		"scope": {
			"ordinary_add_strokes": TOTAL_ADD_STROKES,
			"protected_handle_count": 1,
			"preferred_protected_publication_kind": String(
				DIRECT_PROTECTED_COMPOSITE_KIND
			),
			"accepted_protected_publication_fallback_kind": String(
				CURRENT_CSG_PROTECTED_COMPOSITE_KIND
			),
			"tail_capacity": TAIL_CAPACITY,
			"logical_body_limit_including_handle": LOGICAL_BODY_LIMIT,
			"native_retained_state_limit": NATIVE_RETAINED_STATE_LIMIT,
			"parity_boundaries": [5, 6, 20, "branch19", "restored_branch19"],
			"production_stage_controller": true,
			"production_workspace_presenter": true,
		},
		"fixture": {
			"fixture_id": fixture_preflight.get("fixture_id", ""),
			"stream_digest": fixture_preflight.get("stream_digest", ""),
		},
		"checkpoints": _checkpoint_rows,
		"mutations": _mutation_rows,
		"navigation": _navigation_rows,
		"parity": _parity_rows,
		"protected_publications": _protected_publication_rows,
		"protected_publication_summary": protected_publication_summary,
		"targeting": _target_rows,
		"atomic_rejections": _atomic_rejection_rows,
		"lifecycle": lifecycle,
		"final_extraction": final_extraction,
		"final_presentation": _presentation_summary(_presentation()),
		"final_native": _native_summary(final_native_diagnostics),
		"gates": _gates,
		"failures": _failures,
	}, true)
	_write_report()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if passed:
		print("FORGE_V2_BOUNDED_ADD_HISTORY: PASS")
		quit(0)
	else:
		push_error("FORGE_V2_BOUNDED_ADD_HISTORY: FAIL")
		quit(1)


func _build_real_handle() -> Resource:
	var body: Resource = MaterialBodyScript.new()
	var center_y := -0.20
	var center_z := -0.198
	body.set("body_id", &"bounded_real_handle")
	body.set("source_record_id", &"bounded_real_handle_command")
	body.set("body_kind", MaterialBodyScript.BODY_KIND_HANDLE_PROFILE)
	body.set("material_variant_id", HANDLE_MATERIAL_ID)
	body.set("operation_mode", VolumeStrokeScript.OPERATION_ADD_MATERIAL)
	body.set(
		"placement_policy",
		VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	)
	body.set("shape_kind", MaterialBodyScript.SHAPE_KIND_PROFILE_PATH)
	body.set("path_points", PackedVector3Array([
		Vector3(-0.36, center_y, center_z),
		Vector3(-0.18, center_y, center_z),
	]))
	body.set("path_surface_normals", PackedVector3Array([
		Vector3.BACK,
		Vector3.BACK,
	]))
	body.set("path_contact_directions", PackedVector3Array([
		Vector3.FORWARD,
		Vector3.FORWARD,
	]))
	body.set("profile_id", &"bounded_real_handle_rectangle")
	body.set("profile_display_name", "Bounded verifier real Handle")
	body.set("profile_polygon_2d_meters", PackedVector2Array([
		Vector2(-0.018, -0.014),
		Vector2(0.018, -0.014),
		Vector2(0.018, 0.014),
		Vector2(-0.018, 0.014),
	]))
	body.set("profile_anchor_2d_meters", Vector2.ZERO)
	body.set(
		"profile_contact_point_relative_2d_meters",
		Vector2(0.0, -0.014)
	)
	body.set("profile_contact_direction_2d", Vector2.DOWN)
	body.set("profile_contact_distance_meters", 0.014)
	body.set("profile_runtime_schema_version", 1)
	body.set("profile_rotation_bias_degrees", 0.0)
	body.set("created_timestamp", 1700001000.0)
	body.set("updated_timestamp", 1700001000.0)
	body.call("normalize")
	body.set("body_id", &"bounded_real_handle")
	body.set("source_record_id", &"bounded_real_handle_command")
	return body


func _build_rejection_body(
	body_id: StringName,
	material_variant_id: StringName,
	placement_policy: StringName
) -> Resource:
	var body := StressFixtureScript.build_operation_body(30) as Resource
	if body == null:
		return null
	body.set("body_id", body_id)
	body.set("source_record_id", StringName("%s_command" % String(body_id)))
	body.set("material_variant_id", material_variant_id)
	body.set("placement_policy", placement_policy)
	body.set("committed_layer_id", StringName())
	body.set("layer_active", true)
	body.call("normalize")
	body.set("body_id", body_id)
	body.set("source_record_id", StringName("%s_command" % String(body_id)))
	return body


func _append_pending_body(state: Resource, body: Resource) -> void:
	if state == null or body == null:
		return
	var bodies: Array[Resource] = state.get("material_bodies") as Array[Resource]
	bodies.append(body)
	state.set("material_bodies", bodies)


func _remove_pending_body(state: Resource, body_id: StringName) -> void:
	var retained: Array[Resource] = []
	for body_variant: Variant in state.get("material_bodies") as Array:
		var body := body_variant as Resource
		if body == null or StringName(body.get("body_id")) == body_id:
			continue
		retained.append(body)
	state.set("material_bodies", retained)


func _body_prefix(source: Array[Resource], count: int) -> Array[Resource]:
	var result: Array[Resource] = []
	for body_index in range(mini(count, source.size())):
		result.append(source[body_index])
	return result


func _emit_state_changed() -> void:
	_controller.call("_emit_state_changed")


func _presentation() -> Dictionary:
	return _state.call("get_bounded_presentation_descriptor") as Dictionary


func _native_diagnostics() -> Dictionary:
	return _presenter.call("get_native_static_sync_diagnostics") as Dictionary


func _verify_handle_lane(handle_layer: Resource) -> void:
	var presentation := _presentation()
	var publication := _capture_native_publication()
	var revision := publication.get("revision", null) as Node
	var protected_bodies := presentation.get("protected_bodies", []) as Array
	var protected_layers := presentation.get("protected_layers", []) as Array
	var publication_contract := (
		_protected_publication_rows[
			_protected_publication_rows.size() - 1
		] as Dictionary
		if not _protected_publication_rows.is_empty()
		else {}
	)
	var handle_source_ids := publication_contract.get(
		"surface_source_ids", []
	) as Array
	var handle_publication_direct := (
		String(publication_contract.get("accepted_path", ""))
		== "direct_native_protected_composite"
		and bool(publication_contract.get(
			"final_direct_revision_bootstrap_free", false
		))
		and int(publication_contract.get("mesh_surface_count", -1)) == 1
		and handle_source_ids.size() == 1
		and int(handle_source_ids[0]) == PROTECTED_HANDLE_SOURCE_ID
	)
	var handle_ok: bool = (
		handle_layer != null
		and protected_bodies.size() == 1
		and protected_bodies[0] == _handle
		and protected_layers.size() == 1
		and protected_layers[0] == handle_layer
		and int(presentation.get("protected_body_count", -1)) == 1
		and int(presentation.get("protected_layer_count", -1)) == 1
		and int(presentation.get("checkpoint_operation_count", -1)) == 0
		and int((presentation.get("active_tail_layers", []) as Array).size()) == 0
		and int(presentation.get("logical_body_count", -1)) == 1
		and StringName(_handle.get("body_kind"))
		== MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
		and StringName(_handle.get("profile_role"))
		== MaterialBodyScript.PROFILE_ROLE_HANDLE
		and (_handle.get("path_points") as PackedVector3Array).size() >= 2
		and bool(publication.get("complete", false))
		and bool(publication_contract.get("ok", false))
		and handle_publication_direct
		and revision != null
		and int(revision.get_meta("forge_v2_native_revision", -1)) == 0
	)
	_mark(
		"one_real_protected_handle",
		handle_ok,
		"Handle was not exactly one protected supported publication at revision0"
	)
	_mark(
		"handle_only_final_publication_direct",
		handle_publication_direct,
		"Handle-only final publication was not a one-surface direct revision"
	)
	var diagnostics := _native_diagnostics()
	_mark(
		"production_controller_presenter_native_path",
		String(diagnostics.get("last_mode", "")) == "protected_changed"
		and String(diagnostics.get("lifecycle", "")) == "active"
		and bool(diagnostics.get("authoritative", false))
		and int(diagnostics.get("fallback_count", -1)) == 0,
		"Handle commit did not use the production bounded native lane"
	)


func _record_add_counter_contract(
	deposited_count: int,
	before: Dictionary,
	after: Dictionary,
	is_branch: bool = false
) -> void:
	var is_first_reset := deposited_count == 1 and not is_branch
	var boolean_delta := (
		int(after.get("boolean_count", -1))
		- int(before.get("boolean_count", -1))
	)
	var export_delta := (
		int(after.get("export_count", -1))
		- int(before.get("export_count", -1))
	)
	var promotion_delta := (
		int(after.get("promotion_count", -1))
		- int(before.get("promotion_count", -1))
	)
	var expected_promotion_delta := (
		0 if is_branch or deposited_count <= TAIL_CAPACITY else 1
	)
	var expected_boolean_delta := 0 if is_first_reset else 1
	var promotion_extra_boolean_delta := (
		boolean_delta - expected_boolean_delta
	)
	var promotion_extra_export_delta := export_delta - 1
	var mutation_ok := (
		boolean_delta == expected_boolean_delta
		and export_delta == 1
	)
	var promotion_ok := (
		promotion_delta == expected_promotion_delta
		and promotion_extra_boolean_delta == 0
		and promotion_extra_export_delta == 0
	)
	_mark(
		"one_native_mutation_and_export_per_add",
		mutation_ok,
		"native Boolean/export delta changed at %s"
		% ("branch" if is_branch else "N%d" % deposited_count)
	)
	_mark(
		"promotion_has_no_extra_boolean_or_export",
		promotion_ok,
		"promotion added extra Boolean/export work at %s"
		% ("branch" if is_branch else "N%d" % deposited_count)
	)
	_mutation_rows.append({
		"label": "branch" if is_branch else "N%d" % deposited_count,
		"mode": String(after.get("last_mode", "")),
		"boolean_delta": boolean_delta,
		"export_delta": export_delta,
		"promotion_delta": promotion_delta,
		"promotion_extra_boolean_delta": promotion_extra_boolean_delta,
		"promotion_extra_export_delta": promotion_extra_export_delta,
		"ok": mutation_ok and promotion_ok,
	})


func _record_navigation_counter_contract(
	label: String,
	before: Dictionary,
	after: Dictionary
) -> void:
	var boolean_delta := (
		int(after.get("boolean_count", -1))
		- int(before.get("boolean_count", -1))
	)
	var export_delta := (
		int(after.get("export_count", -1))
		- int(before.get("export_count", -1))
	)
	var ok: bool = (
		boolean_delta == 0
		and export_delta == 1
		and int(after.get("promotion_count", -1))
		== int(before.get("promotion_count", -2))
	)
	_mark(
		"exactly_five_undos_and_five_redos",
		ok,
		"navigation counter contract changed at %s" % label
	)
	_navigation_rows.append({
		"label": label,
		"boolean_delta": boolean_delta,
		"export_delta": export_delta,
		"checkpoint": int(after.get("checkpoint_operation_count", -1)),
		"cursor": int(after.get("active_tail_cursor", -1)),
		"redo": int(after.get("redo_count", -1)),
		"retained_states": int(after.get("retained_state_count", -1)),
		"target": String(_publication_identity().get(
			"surface_target_id", StringName()
		)),
		"ok": ok,
	})


func _capture_bounded_state_gate(deposited_count: int) -> void:
	var presentation := _presentation()
	var diagnostics := _native_diagnostics()
	var ledger := _state.call("get_material_ledger_summary") as Dictionary
	var cache := _state.call(
		"get_committed_volume_cache_diagnostics"
	) as Dictionary
	var checkpoint_packet := presentation.get(
		"checkpoint_packet", {}
	) as Dictionary
	var expected_checkpoint := maxi(deposited_count - TAIL_CAPACITY, 0)
	var expected_tail := mini(deposited_count, TAIL_CAPACITY)
	var expected_logical := (
		(1 if expected_checkpoint > 0 else 0) + expected_tail + 1
	)
	var state_shape_ok := (
		bool(presentation.get("bounded_history_enabled", false))
		and not bool(presentation.get("recovery_blocked", true))
		and not bool(presentation.get("pending_native_ack", true))
		and int(presentation.get("checkpoint_operation_count", -1))
		== expected_checkpoint
		and int((presentation.get("active_tail_layers", []) as Array).size())
		== expected_tail
		and int((presentation.get("redo_tail_layers", []) as Array).size()) == 0
		and int(presentation.get("protected_body_count", -1)) == 1
		and int(presentation.get("protected_layer_count", -1)) == 1
		and int(presentation.get("logical_body_count", -1))
		== expected_logical
		and int(_state.call("get_committed_layer_count"))
		== deposited_count + 1
		and int(_state.call("get_user_material_body_count"))
		<= expected_tail + 1
	)
	var native_shape_ok := (
		bool(diagnostics.get("history_window_enabled", false))
		and int(diagnostics.get("history_window_capacity", -1))
		== TAIL_CAPACITY
		and int(diagnostics.get("checkpoint_operation_count", -1))
		== expected_checkpoint
		and int(diagnostics.get("prefix_body_count", -1)) == expected_tail
		and int(diagnostics.get("retained_state_count", -1))
		<= NATIVE_RETAINED_STATE_LIMIT
		and int(diagnostics.get("retained_state_count", -1)) > 0
		and int(diagnostics.get("fallback_count", -1)) == 0
		and String(diagnostics.get("last_failure_reason", "")).is_empty()
	)
	var bounded_storage := _bounded_storage_contract(
		presentation,
		ledger,
		cache
	)
	var gate_name := (
		"n5_checkpoint0_tail5"
		if deposited_count == 5
		else "n6_checkpoint1_tail5"
		if deposited_count == 6
		else "n20_checkpoint15_tail5"
	)
	_mark(
		gate_name,
		state_shape_ok and native_shape_ok,
		"bounded state shape changed at N=%d" % deposited_count
	)
	_mark(
		"logical_and_native_state_bounded",
		state_shape_ok and native_shape_ok,
		"logical/native retention exceeded bounds at N=%d" % deposited_count
	)
	_mark(
		"ledger_and_resolver_cache_bounded",
		bool(bounded_storage.get("ok", false)),
		"ledger/resolver cache exceeded live 1+5+Handle authority at N=%d"
		% deposited_count
	)
	_checkpoint_rows.append({
		"n": deposited_count,
		"checkpoint": expected_checkpoint,
		"tail": expected_tail,
		"logical_bodies": int(presentation.get("logical_body_count", -1)),
		"active_user_bodies": int(_state.call("get_user_material_body_count")),
		"native_retained_states": int(diagnostics.get(
			"retained_state_count", -1
		)),
		"native_retained_vertices": int(diagnostics.get(
			"retained_total_vertices", -1
		)),
		"native_retained_triangles": int(diagnostics.get(
			"retained_total_triangles", -1
		)),
		"checkpoint_cells": int((checkpoint_packet.get(
			"checkpoint_cell_materials", {}
		) as Dictionary).size()),
		"ledger_live_layer_ids": bounded_storage.get("ledger_layer_ids", []),
		"cache_body_tokens": int(cache.get("cached_body_count", -1)),
		"cache_cells": int(cache.get("cached_cell_count_current", -1)),
		"state_shape_ok": state_shape_ok,
		"native_shape_ok": native_shape_ok,
		"storage_ok": bool(bounded_storage.get("ok", false)),
	})


func _bounded_storage_contract(
	presentation: Dictionary,
	ledger: Dictionary,
	cache: Dictionary
) -> Dictionary:
	var live_layer_ids: Array[StringName] = []
	for collection_name: String in [
		"protected_layers",
		"active_tail_layers",
	]:
		for layer_variant: Variant in presentation.get(collection_name, []) as Array:
			var layer := layer_variant as Resource
			if layer == null:
				continue
			var layer_id := StringName(layer.get("layer_id"))
			if layer_id != StringName() and not live_layer_ids.has(layer_id):
				live_layer_ids.append(layer_id)
	var ledger_layer_ids: Array[StringName] = []
	var materials := ledger.get("materials", {}) as Dictionary
	for entry_variant: Variant in materials.values():
		if not entry_variant is Dictionary:
			continue
		for id_variant: Variant in (entry_variant as Dictionary).get(
			"layer_ids", []
		) as Array:
			var layer_id := StringName(id_variant)
			if layer_id != StringName() and not ledger_layer_ids.has(layer_id):
				ledger_layer_ids.append(layer_id)
	var ledger_subset_ok := true
	for layer_id: StringName in ledger_layer_ids:
		ledger_subset_ok = ledger_subset_ok and live_layer_ids.has(layer_id)
	var checkpoint_packet := presentation.get(
		"checkpoint_packet", {}
	) as Dictionary
	var checkpoint_cells := (checkpoint_packet.get(
		"checkpoint_cell_materials", {}
	) as Dictionary).size()
	var ok: bool = (
		live_layer_ids.size() <= 6
		and ledger_layer_ids.size() <= 6
		and ledger_subset_ok
		and int(ledger.get("removed_material_record_count", -1)) == 0
		and bool(cache.get("cache_valid", false))
		and not bool(cache.get("cache_candidate_pending", true))
		and int(cache.get("cached_body_count", -1)) <= CACHE_BODY_TOKEN_LIMIT
		and int(cache.get("cached_body_count", -1)) >= 1
		and int(cache.get("cached_cell_count_current", -1))
		<= int(cache.get("cache_cell_limit", 1000000))
		and checkpoint_cells <= int(cache.get("cache_cell_limit", 1000000))
	)
	return {
		"ok": ok,
		"live_layer_ids": _string_names(live_layer_ids),
		"ledger_layer_ids": _string_names(ledger_layer_ids),
		"ledger_subset_ok": ledger_subset_ok,
	}


func _assert_hot_checkpoint_contract(
	diagnostics: Dictionary,
	context: String
) -> void:
	var ok: bool = (
		int(diagnostics.get("hot_checkpoint_exports", -1)) == 0
		and int(diagnostics.get("lazy_checkpoint_exports", -1)) == 0
		and int(diagnostics.get(
			"checkpoint_materialization_attempt_count", -1
		)) == 0
		and int(diagnostics.get(
			"checkpoint_materialization_count", -1
		)) == 0
	)
	_mark(
		"hot_path_never_materializes_checkpoint",
		ok,
		"hot checkpoint materialization occurred during %s" % context
	)


func _await_native_publication(expected_mode: String) -> Dictionary:
	var bootstrap_observation := _new_bootstrap_observation()
	for frame_index in range(READINESS_FRAME_LIMIT):
		await process_frame
		await physics_frame
		var diagnostics := _native_diagnostics()
		_accumulate_bootstrap_observation(
			bootstrap_observation,
			diagnostics
		)
		var transition := _state.call(
			"get_bounded_history_transition"
		) as Dictionary
		var publication := _capture_native_publication()
		if (
			String(diagnostics.get("last_mode", "")) == expected_mode
			and String(diagnostics.get("lifecycle", "")) == "active"
			and bool(diagnostics.get("authoritative", false))
			and not bool(diagnostics.get("publication_pending", true))
			and int(diagnostics.get("bounded_transition_revision", -1))
			== int(transition.get("revision", -2))
			and int(diagnostics.get("fallback_count", -1)) == 0
			and String(diagnostics.get("last_failure_reason", "")).is_empty()
			and bool(publication.get("complete", false))
		):
			var presentation := _presentation()
			var has_logical_ordinary := (
				int(presentation.get(
					"checkpoint_operation_count", 0
				)) > 0
				or not (presentation.get(
					"active_tail_bodies", []
				) as Array).is_empty()
			)
			var publication_contract := (
				_capture_protected_publication_contract(
					"%s_transition_%d_native_%d" % [
						expected_mode,
						int(transition.get("revision", -1)),
						int(diagnostics.get("published_revision", -1)),
					],
					has_logical_ordinary,
					publication,
					null,
					has_logical_ordinary,
					[],
					diagnostics,
					bootstrap_observation
				)
			)
			_record_protected_publication_contract(publication_contract)
			return {
				"ok": true,
				"waited_process_physics_pairs": frame_index + 1,
				"protected_publication_contract": publication_contract,
			}
	return {
		"ok": false,
		"expected_mode": expected_mode,
		"diagnostics": _native_summary(_native_diagnostics()),
		"publication": _publication_summary(_capture_native_publication()),
	}


func _capture_native_publication() -> Dictionary:
	var targetable_colliders: Array[Node] = []
	_collect_targetable_colliders(_presenter, targetable_colliders)
	if targetable_colliders.size() != 1:
		return {
			"complete": false,
			"targetable_collider_count": targetable_colliders.size(),
		}
	var collider := targetable_colliders[0]
	var revision := _find_native_revision_ancestor(collider)
	if revision == null:
		return {
			"complete": false,
			"targetable_collider_count": 1,
			"collider": collider,
		}
	var generated_ready := true
	if collider is CSGShape3D:
		generated_ready = _csg_generated_mesh_is_ready(
			collider as CSGShape3D
		)
	elif collider is StaticBody3D:
		generated_ready = (
			_find_mesh_instance(revision) != null
			and _static_body_has_nonempty_concave_shape(
				collider as StaticBody3D
			)
		)
	else:
		generated_ready = false
	return {
		"complete": (
			revision.visible
			and generated_ready
			and bool(collider.get_meta(
				"forge_v2_material_surface",
				false
			))
			and not bool(collider.get_meta(
				"forge_v2_publication_pending",
				true
			))
		),
		"targetable_collider_count": 1,
		"revision": revision,
		"collider": collider,
		"generated_ready": generated_ready,
	}


func _capture_protected_publication_contract(
	label: String,
	expected_ordinary_material: bool,
	publication: Dictionary = {},
	mesh_override: ArrayMesh = null,
	allow_fully_swallowed_ordinary: bool = false,
	expected_material_signatures: Array[String] = [],
	diagnostics: Dictionary = {},
	bootstrap_observation: Dictionary = {}
) -> Dictionary:
	if publication.is_empty():
		publication = _capture_native_publication()
	if diagnostics.is_empty():
		diagnostics = _native_diagnostics()
	var revision := publication.get("revision", null) as Node
	var collider := publication.get("collider", null) as Node
	var revision_kind := (
		StringName(revision.get_meta(
			"forge_v2_native_revision_kind",
			StringName()
		))
		if revision != null
		else StringName()
	)
	var is_direct := (
		revision_kind == DIRECT_PROTECTED_COMPOSITE_KIND
		and collider is StaticBody3D
	)
	var is_current_csg_fallback := (
		revision_kind == CURRENT_CSG_PROTECTED_COMPOSITE_KIND
		and collider is CSGCombiner3D
	)
	var mesh := mesh_override
	if mesh == null and is_direct:
		mesh = _bake_publication_mesh(publication)
	var surface_contract := _analyze_protected_composite_surfaces(
		mesh,
		expected_ordinary_material,
		allow_fully_swallowed_ordinary,
		expected_material_signatures
	)
	var named_mesh_instance := (
		revision.get_node_or_null("NativeStaticMaterialBodyMesh")
		as MeshInstance3D
		if revision != null
		else null
	)
	var named_collision_body := (
		revision.get_node_or_null("NativeStaticMaterialBodyCollision")
		as StaticBody3D
		if revision != null
		else null
	)
	var named_collision_shape := (
		revision.get_node_or_null(
			"NativeStaticMaterialBodyCollision/NativeStaticMaterialBodyShape"
		) as CollisionShape3D
		if revision != null
		else null
	)
	var metadata_expected_surface_count := (
		int(revision.get_meta(
			"forge_v2_native_expected_surface_count", -1
		))
		if revision != null
		else -1
	)
	var metadata_surface_source_ids := PackedInt32Array()
	if revision != null:
		var source_ids_variant: Variant = revision.get_meta(
			"forge_v2_native_surface_source_ids",
			PackedInt32Array()
		)
		if source_ids_variant is PackedInt32Array:
			metadata_surface_source_ids = (
				source_ids_variant as PackedInt32Array
			)
	var metadata_ordinary_triangle_count := (
		int(revision.get_meta(
			"forge_v2_native_ordinary_triangle_count", -1
		))
		if revision != null
		else -1
	)
	var metadata_protected_triangle_count := (
		int(revision.get_meta(
			"forge_v2_native_protected_triangle_count", -1
		))
		if revision != null
		else -1
	)
	var metadata_subtraction_triangle_count := (
		int(revision.get_meta(
			"forge_v2_native_subtraction_triangle_count", -1
		))
		if revision != null
		else -1
	)
	var classified_ordinary_triangles := 0
	var classified_protected_triangles := 0
	var classified_subtraction_triangles := 0
	var source_metadata_matches_materials := (
		is_direct
		and metadata_expected_surface_count
		== int(surface_contract.get("surface_count", -1))
		and metadata_surface_source_ids.size()
		== int(surface_contract.get("surface_count", -1))
		and _packed_int32_values_are_unique(metadata_surface_source_ids)
		and _packed_int32_values_are_strictly_increasing(
			metadata_surface_source_ids
		)
	)
	var surface_rows := surface_contract.get("surface_rows", []) as Array
	if source_metadata_matches_materials:
		for surface_index in range(surface_rows.size()):
			var surface_row := surface_rows[surface_index] as Dictionary
			var source_id := metadata_surface_source_ids[surface_index]
			var classification := String(surface_row.get(
				"classification", "unexpected"
			))
			var triangle_count := int(surface_row.get(
				"triangle_count", 0
			))
			if (
				source_id == ORDINARY_SOURCE_ID
				and classification == "ordinary"
			):
				classified_ordinary_triangles += triangle_count
			elif (
				source_id == PROTECTED_HANDLE_SOURCE_ID
				and classification == "protected"
			):
				classified_protected_triangles += triangle_count
			elif (
				source_id == SUBTRACTION_SOURCE_ID
				and classification == "subtraction"
			):
				classified_subtraction_triangles += triangle_count
			else:
				source_metadata_matches_materials = false
				break
	if source_metadata_matches_materials:
		source_metadata_matches_materials = (
			metadata_ordinary_triangle_count
			== classified_ordinary_triangles
			and metadata_protected_triangle_count
			== classified_protected_triangles
			and metadata_subtraction_triangle_count
			== classified_subtraction_triangles
			and metadata_protected_triangle_count > 0
			and (
				metadata_ordinary_triangle_count > 0
				or not bool(surface_contract.get(
					"ordinary_material_present", false
				))
			)
			and (
				metadata_subtraction_triangle_count > 0
				or not bool(surface_contract.get(
					"subtraction_material_present", false
				))
			)
		)
	var source_material_classified_ok := (
		bool(surface_contract.get("source_material_classified", false))
		and source_metadata_matches_materials
	)
	var live_revision_metadata := _capture_live_revision_metadata(revision)
	var live_lane_contract := _analyze_live_decomposed_lanes(
		mesh,
		metadata_surface_source_ids,
		expected_ordinary_material,
		allow_fully_swallowed_ordinary,
		live_revision_metadata
	)
	var live_lane_contract_ok := bool(live_lane_contract.get(
		"ok",
		false
	))
	var collision_shapes: Array[CollisionShape3D] = []
	if collider != null:
		_collect_collision_shapes(collider, collision_shapes)
	var concave_shape_count := 0
	var nonempty_concave_shape_count := 0
	for collision_shape: CollisionShape3D in collision_shapes:
		if (
			collision_shape == null
			or collision_shape.disabled
			or not collision_shape.shape is ConcavePolygonShape3D
		):
			continue
		concave_shape_count += 1
		var concave_shape := (
			collision_shape.shape as ConcavePolygonShape3D
		)
		var faces: PackedVector3Array = concave_shape.get_faces()
		if not faces.is_empty() and faces.size() % 3 == 0:
			nonempty_concave_shape_count += 1
	var csg_composition_node_count := _count_csg_shape_descendants(
		revision
	)
	var final_bootstrap_nodes: Array[CSGCombiner3D] = []
	_collect_protected_handle_bootstrap_nodes(
		revision,
		final_bootstrap_nodes
	)
	var final_direct_revision_bootstrap_free := (
		is_direct and final_bootstrap_nodes.is_empty()
	)
	var bootstrap_pending_only_ok := (
		int(bootstrap_observation.get("violation_count", 0)) == 0
	)
	var composition_diagnostics := (
		_protected_composition_diagnostic_snapshot(diagnostics)
	)
	var one_direct_concave_collider_ok := (
		is_direct
		and int(publication.get("targetable_collider_count", -1)) == 1
		and collider == named_collision_body
		and named_collision_shape != null
		and named_mesh_instance != null
		and named_mesh_instance.mesh == mesh
		and collision_shapes.size() == 1
		and collision_shapes[0] == named_collision_shape
		and concave_shape_count == 1
		and nonempty_concave_shape_count == 1
	)
	var no_direct_csg_node_ok := (
		is_direct and csg_composition_node_count == 0
	)
	var direct_contract_ok := (
		is_direct
		and bool(publication.get("complete", false))
		and bool(surface_contract.get("surface_count_ok", false))
		and bool(surface_contract.get("material_presence_ok", false))
		and bool(surface_contract.get("material_set_parity_ok", false))
		and source_material_classified_ok
		and live_lane_contract_ok
		and bool(surface_contract.get("no_empty_surface", false))
		and one_direct_concave_collider_ok
		and no_direct_csg_node_ok
		and final_direct_revision_bootstrap_free
		and bootstrap_pending_only_ok
	)
	var current_csg_fallback_ok := (
		is_current_csg_fallback
		and bool(publication.get("complete", false))
		and int(publication.get("targetable_collider_count", -1)) == 1
		and csg_composition_node_count > 0
	)
	var accepted_path := "unsupported"
	if direct_contract_ok:
		accepted_path = "direct_native_protected_composite"
	elif current_csg_fallback_ok:
		accepted_path = "current_csg_fallback"
	return {
		"label": label,
		"ok": direct_contract_ok or current_csg_fallback_ok,
		"accepted_path": accepted_path,
		"preferred_path": "direct_native_protected_composite",
		"fallback_accepted": true,
		"revision_kind": String(revision_kind),
		"direct_composition_kind": is_direct,
		"current_csg_fallback_kind": is_current_csg_fallback,
		"complete": bool(publication.get("complete", false)),
		"targetable_collider_count": int(publication.get(
			"targetable_collider_count", -1
		)),
		"collider_class": collider.get_class() if collider != null else "",
		"named_mesh_instance_present": named_mesh_instance != null,
		"named_collision_body_present": named_collision_body != null,
		"named_collision_shape_present": named_collision_shape != null,
		"collision_shape_count": collision_shapes.size(),
		"concave_collision_shape_count": concave_shape_count,
		"nonempty_concave_collision_shape_count": (
			nonempty_concave_shape_count
		),
		"one_targetable_concave_collider": one_direct_concave_collider_ok,
		"csg_composition_node_count": csg_composition_node_count,
		"no_csg_composition_node": no_direct_csg_node_ok,
		"final_direct_revision_bootstrap_free": (
			final_direct_revision_bootstrap_free
		),
		"bootstrap_pending_only_ok": bootstrap_pending_only_ok,
		"bootstrap_observation": bootstrap_observation.duplicate(true),
		"protected_composition_diagnostics": composition_diagnostics,
		"expected_ordinary_material": expected_ordinary_material,
		"fully_swallowed_ordinary_allowed": (
			allow_fully_swallowed_ordinary
		),
		"mesh_surface_count": int(surface_contract.get(
			"surface_count", -1
		)),
		"expected_mesh_surface_count": int(surface_contract.get(
			"expected_surface_count", -1
		)),
		"expected_mesh_surface_count_contract": String(
			surface_contract.get("expected_surface_count_contract", "")
		),
		"surface_count_ok": bool(surface_contract.get(
			"surface_count_ok", false
		)),
		"ordinary_material_present": bool(surface_contract.get(
			"ordinary_material_present", false
		)),
		"protected_material_present": bool(surface_contract.get(
			"protected_material_present", false
		)),
		"subtraction_material_present": bool(surface_contract.get(
			"subtraction_material_present", false
		)),
		"material_presence_ok": bool(surface_contract.get(
			"material_presence_ok", false
		)),
		"material_set_parity_required": bool(surface_contract.get(
			"material_set_parity_required", false
		)),
		"material_set_parity_ok": bool(surface_contract.get(
			"material_set_parity_ok", false
		)),
		"expected_material_signatures": surface_contract.get(
			"expected_material_signatures", []
		),
		"source_material_classified": source_material_classified_ok,
		"surface_source_ids": Array(metadata_surface_source_ids),
		"metadata_expected_surface_count": (
			metadata_expected_surface_count
		),
		"metadata_ordinary_triangle_count": (
			metadata_ordinary_triangle_count
		),
		"metadata_protected_triangle_count": (
			metadata_protected_triangle_count
		),
		"metadata_subtraction_triangle_count": (
			metadata_subtraction_triangle_count
		),
		"classified_ordinary_triangle_count": (
			classified_ordinary_triangles
		),
		"classified_protected_triangle_count": (
			classified_protected_triangles
		),
		"classified_subtraction_triangle_count": (
			classified_subtraction_triangles
		),
		"source_metadata_matches_materials": (
			source_metadata_matches_materials
		),
		"live_decomposed_lanes": live_lane_contract,
		"live_revision_metadata": live_revision_metadata,
		"live_decomposed_lanes_ok": live_lane_contract_ok,
		"no_empty_surface": bool(surface_contract.get(
			"no_empty_surface", false
		)),
		"surface_material_signatures": surface_contract.get(
			"surface_material_signatures", []
		),
		"surface_classifications": surface_contract.get(
			"surface_classifications", []
		),
		"surface_rows": surface_contract.get("surface_rows", []),
		"kind_gate_ok": is_direct or current_csg_fallback_ok,
		"surface_count_gate_ok": (
			current_csg_fallback_ok
			or (is_direct and bool(surface_contract.get(
				"surface_count_ok", false
			)))
		),
		"material_presence_gate_ok": (
			current_csg_fallback_ok
			or (is_direct and bool(surface_contract.get(
				"material_presence_ok", false
			)))
		),
		"source_material_classified_gate_ok": (
			current_csg_fallback_ok
			or (is_direct and source_material_classified_ok)
		),
		"no_empty_surface_gate_ok": (
			current_csg_fallback_ok
			or (is_direct and bool(surface_contract.get(
				"no_empty_surface", false
			)))
		),
		"one_concave_collider_gate_ok": (
			current_csg_fallback_ok or one_direct_concave_collider_ok
		),
		"no_csg_node_gate_ok": (
			current_csg_fallback_ok or no_direct_csg_node_ok
		),
		"bootstrap_lifecycle_gate_ok": (
			current_csg_fallback_ok
			or (
				final_direct_revision_bootstrap_free
				and bootstrap_pending_only_ok
			)
		),
		"live_lane_topology_gate_ok": (
			current_csg_fallback_ok
			or (is_direct and live_lane_contract_ok)
		),
	}


func _analyze_protected_composite_surfaces(
	mesh: ArrayMesh,
	expected_ordinary_material: bool,
	allow_fully_swallowed_ordinary: bool = false,
	expected_material_signatures: Array[String] = []
) -> Dictionary:
	var expected_surface_count := -1
	var expected_surface_count_contract := (
		"1_to_3_nonempty_unique_source_surfaces"
	)
	var normalized_expected_materials := (
		_normalize_material_signatures(expected_material_signatures)
	)
	var material_set_parity_required := (
		not normalized_expected_materials.is_empty()
	)
	if mesh == null:
		return {
			"surface_count": -1,
			"expected_surface_count": expected_surface_count,
			"expected_surface_count_contract": (
				expected_surface_count_contract
			),
			"surface_count_ok": false,
			"ordinary_material_present": false,
			"protected_material_present": false,
			"subtraction_material_present": false,
			"material_presence_ok": false,
			"material_set_parity_required": (
				material_set_parity_required
			),
			"material_set_parity_ok": false,
			"expected_material_signatures": (
				normalized_expected_materials
			),
			"source_material_classified": false,
			"no_empty_surface": false,
			"surface_material_signatures": [],
			"surface_classifications": [],
			"surface_rows": [],
		}
	var ordinary_material := _presenter.call(
		"_build_csg_body_material",
		ADD_MATERIAL_ID,
		false
	) as Material
	var protected_material := _presenter.call(
		"_build_csg_body_material",
		HANDLE_MATERIAL_ID,
		false
	) as Material
	var subtraction_material := _presenter.call(
		"_build_csg_body_material",
		ADD_MATERIAL_ID,
		true
	) as Material
	var ordinary_signature := _material_signature(ordinary_material)
	var protected_signature := _material_signature(protected_material)
	var subtraction_signature := _material_signature(
		subtraction_material
	)
	var ordinary_surface_count := 0
	var protected_surface_count := 0
	var subtraction_surface_count := 0
	var unexpected_surface_count := 0
	var empty_surface_count := 0
	var surface_material_signatures: Array[String] = []
	var surface_classifications: Array[String] = []
	var surface_rows: Array[Dictionary] = []
	for surface_index in range(mesh.get_surface_count()):
		var material_signature := _material_signature(
			mesh.surface_get_material(surface_index)
		)
		var classification := "unexpected"
		if material_signature == ordinary_signature:
			classification = "ordinary"
			ordinary_surface_count += 1
		elif material_signature == protected_signature:
			classification = "protected"
			protected_surface_count += 1
		elif material_signature == subtraction_signature:
			classification = "subtraction"
			subtraction_surface_count += 1
		else:
			unexpected_surface_count += 1
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertex_count := 0
		var index_count := 0
		if arrays.size() >= Mesh.ARRAY_MAX:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			vertex_count = vertices.size()
			if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
				var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
				index_count = indices.size()
		var triangle_count := (
			index_count / 3 if index_count > 0 else vertex_count / 3
		)
		var surface_nonempty := (
			vertex_count > 0
			and triangle_count > 0
			and (
				(index_count > 0 and index_count % 3 == 0)
				or (index_count == 0 and vertex_count % 3 == 0)
			)
		)
		if not surface_nonempty:
			empty_surface_count += 1
		surface_material_signatures.append(material_signature)
		surface_classifications.append(classification)
		surface_rows.append({
			"surface": surface_index,
			"classification": classification,
			"material_signature": material_signature,
			"vertex_count": vertex_count,
			"index_count": index_count,
			"triangle_count": triangle_count,
			"nonempty": surface_nonempty,
		})
	var ordinary_material_present := ordinary_surface_count > 0
	var protected_material_present := protected_surface_count > 0
	var subtraction_material_present := subtraction_surface_count > 0
	var ordinary_classification_ok := (
		ordinary_surface_count <= 1
		if expected_ordinary_material and allow_fully_swallowed_ordinary
		else ordinary_surface_count
		== (1 if expected_ordinary_material else 0)
	)
	var subtraction_classification_ok := (
		subtraction_surface_count <= 1
		if expected_ordinary_material
		else subtraction_surface_count == 0
	)
	var expected_classification_ok := (
		ordinary_classification_ok
		and protected_surface_count == 1
		and subtraction_classification_ok
		and unexpected_surface_count == 0
	)
	var surface_count_ok := (
		mesh.get_surface_count() >= 1
		and mesh.get_surface_count() <= 3
	)
	var ordinary_presence_ok := (
		ordinary_surface_count in [0, 1]
		if expected_ordinary_material and allow_fully_swallowed_ordinary
		else ordinary_material_present == expected_ordinary_material
	)
	var actual_material_signatures := _mesh_material_signatures(mesh)
	var material_set_parity_ok := (
		not material_set_parity_required
		or actual_material_signatures == normalized_expected_materials
	)
	return {
		"surface_count": mesh.get_surface_count(),
		"expected_surface_count": expected_surface_count,
		"expected_surface_count_contract": expected_surface_count_contract,
		"surface_count_ok": surface_count_ok,
		"ordinary_material_present": ordinary_material_present,
		"protected_material_present": protected_material_present,
		"subtraction_material_present": subtraction_material_present,
		"material_presence_ok": (
			protected_material_present
			and ordinary_presence_ok
			and subtraction_classification_ok
			and unexpected_surface_count == 0
		),
		"material_set_parity_required": material_set_parity_required,
		"material_set_parity_ok": material_set_parity_ok,
		"expected_material_signatures": normalized_expected_materials,
		"source_material_classified": expected_classification_ok,
		"no_empty_surface": empty_surface_count == 0,
		"ordinary_surface_count": ordinary_surface_count,
		"protected_surface_count": protected_surface_count,
		"subtraction_surface_count": subtraction_surface_count,
		"unexpected_surface_count": unexpected_surface_count,
		"empty_surface_count": empty_surface_count,
		"surface_material_signatures": surface_material_signatures,
		"surface_classifications": surface_classifications,
		"surface_rows": surface_rows,
	}


func _capture_live_revision_metadata(revision: Node) -> Dictionary:
	if revision == null:
		return {}
	var clipped_source_ids := PackedInt32Array()
	var clipped_ids_variant: Variant = revision.get_meta(
		"forge_v2_native_live_clipped_source_ids",
		PackedInt32Array()
	)
	if clipped_ids_variant is PackedInt32Array:
		clipped_source_ids = clipped_ids_variant as PackedInt32Array
	var handle_source_ids := PackedInt32Array()
	var handle_ids_variant: Variant = revision.get_meta(
		"forge_v2_native_live_handle_source_ids",
		PackedInt32Array()
	)
	if handle_ids_variant is PackedInt32Array:
		handle_source_ids = handle_ids_variant as PackedInt32Array
	return {
		"live_unfused_geometry": bool(revision.get_meta(
			"forge_v2_native_live_unfused_geometry", false
		)),
		"live_lane_count": int(revision.get_meta(
			"forge_v2_native_live_lane_count", -1
		)),
		"live_logical_component_count": int(revision.get_meta(
			"forge_v2_native_live_logical_component_count", -1
		)),
		"handle_packet_reused": bool(revision.get_meta(
			"forge_v2_native_live_handle_packet_reused", false
		)),
		"combined_collision": bool(revision.get_meta(
			"forge_v2_native_live_combined_collision", false
		)),
		"final_union_performed": bool(revision.get_meta(
			"forge_v2_native_live_final_union_performed", true
		)),
		"clipped_vertex_count": int(revision.get_meta(
			"forge_v2_native_live_clipped_vertex_count", -1
		)),
		"clipped_triangle_count": int(revision.get_meta(
			"forge_v2_native_live_clipped_triangle_count", -1
		)),
		"clipped_ordinary_triangle_count": int(revision.get_meta(
			"forge_v2_native_live_clipped_ordinary_triangle_count", -1
		)),
		"clipped_subtraction_triangle_count": int(revision.get_meta(
			"forge_v2_native_live_clipped_subtraction_triangle_count", -1
		)),
		"clipped_source_ids": Array(clipped_source_ids),
		"handle_signature": String(revision.get_meta(
			"forge_v2_native_live_handle_signature", ""
		)),
		"handle_vertex_count": int(revision.get_meta(
			"forge_v2_native_live_handle_vertex_count", -1
		)),
		"handle_triangle_count": int(revision.get_meta(
			"forge_v2_native_live_handle_triangle_count", -1
		)),
		"handle_source_ids": Array(handle_source_ids),
		"source_state_revision": int(revision.get_meta(
			"forge_v2_native_live_source_state_revision", -1
		)),
		"backend_method": String(revision.get_meta(
			"forge_v2_native_live_backend_method", ""
		)),
		"final_compose_method": String(revision.get_meta(
			"forge_v2_native_final_compose_method", ""
		)),
		"final_compose_available": bool(revision.get_meta(
			"forge_v2_native_final_compose_available", false
		)),
		"ordinary_triangle_count": int(revision.get_meta(
			"forge_v2_native_ordinary_triangle_count", -1
		)),
		"protected_triangle_count": int(revision.get_meta(
			"forge_v2_native_protected_triangle_count", -1
		)),
		"subtraction_triangle_count": int(revision.get_meta(
			"forge_v2_native_subtraction_triangle_count", -1
		)),
	}


func _analyze_live_decomposed_lanes(
	mesh: ArrayMesh,
	surface_source_ids: PackedInt32Array,
	expected_ordinary_lane: bool,
	allow_empty_clipped_rest: bool,
	live_metadata: Dictionary
) -> Dictionary:
	if (
		mesh == null
		or surface_source_ids.size() != mesh.get_surface_count()
	):
		return {
			"ok": false,
			"reason": "live_lane_surface_metadata_invalid",
		}
	var clipped_rest_surfaces := PackedInt32Array()
	var handle_surfaces := PackedInt32Array()
	var expected_clipped_source_ids: Array[int] = []
	var unexpected_surface_count := 0
	for surface_index in range(surface_source_ids.size()):
		match surface_source_ids[surface_index]:
			ORDINARY_SOURCE_ID, SUBTRACTION_SOURCE_ID:
				clipped_rest_surfaces.append(surface_index)
				if not expected_clipped_source_ids.has(
					surface_source_ids[surface_index]
				):
					expected_clipped_source_ids.append(
						surface_source_ids[surface_index]
					)
			PROTECTED_HANDLE_SOURCE_ID:
				handle_surfaces.append(surface_index)
			_:
				unexpected_surface_count += 1
	var clipped_rest_analysis := (
		MeshAnalyzerScript.analyze_mesh_surface_subset(
			mesh,
			clipped_rest_surfaces
		)
	)
	var handle_analysis := MeshAnalyzerScript.analyze_mesh_surface_subset(
		mesh,
		handle_surfaces
	)
	var clipped_rest_present := not clipped_rest_surfaces.is_empty()
	var handle_present := not handle_surfaces.is_empty()
	var materialized_nonempty_lane_count := (
		(1 if clipped_rest_present else 0)
		+ (1 if handle_present else 0)
	)
	var conceptual_lane_count := 2 if expected_ordinary_lane else 1
	var clipped_rest_volume := float(clipped_rest_analysis.get(
		"absolute_volume_cubic_meters",
		0.0
	))
	var handle_volume := float(handle_analysis.get(
		"absolute_volume_cubic_meters",
		0.0
	))
	var clipped_rest_ok := (
		(
			(
				clipped_rest_present
				and _strict_watertight_any_component_count(
					clipped_rest_analysis
				)
				and is_finite(clipped_rest_volume)
				and clipped_rest_volume > 0.0
			)
			or (
				not clipped_rest_present
				and allow_empty_clipped_rest
			)
		)
		if expected_ordinary_lane
		else not clipped_rest_present
	)
	var handle_ok := (
		handle_surfaces.size() == 1
		and _strict_topology_passes(handle_analysis)
		and is_finite(handle_volume)
		and handle_volume > 0.0
	)
	expected_clipped_source_ids.sort()
	var expected_backend_method := (
		"clip_current_state_with_protected_mesh"
		if expected_ordinary_lane
		else "handle_only_cached_exact"
	)
	var final_compose_available := bool(live_metadata.get(
		"final_compose_available",
		false
	))
	var final_compose_availability_ok := (
		not expected_ordinary_lane or final_compose_available
	)
	var live_metadata_ok := (
		int(live_metadata.get("live_lane_count", -1))
		== materialized_nonempty_lane_count
		and int(live_metadata.get("live_logical_component_count", -1))
		== materialized_nonempty_lane_count
		and bool(live_metadata.get("handle_packet_reused", false))
		and bool(live_metadata.get("combined_collision", false))
		and not bool(live_metadata.get("final_union_performed", true))
		and bool(live_metadata.get("live_unfused_geometry", false))
		== clipped_rest_present
		and int(live_metadata.get("clipped_triangle_count", -1))
		== int(clipped_rest_analysis.get("emitted_triangle_count", -2))
		and int(live_metadata.get("clipped_ordinary_triangle_count", -1))
		== int(live_metadata.get("ordinary_triangle_count", -2))
		and int(live_metadata.get("clipped_subtraction_triangle_count", -1))
		== int(live_metadata.get("subtraction_triangle_count", -2))
		and int(live_metadata.get("clipped_triangle_count", -1))
		== (
			int(live_metadata.get("clipped_ordinary_triangle_count", -2))
			+ int(live_metadata.get(
				"clipped_subtraction_triangle_count", -2
			))
		)
		and int(live_metadata.get("handle_triangle_count", -1))
		== int(handle_analysis.get("emitted_triangle_count", -2))
		and int(live_metadata.get("handle_triangle_count", -1))
		== int(live_metadata.get("protected_triangle_count", -2))
		and (live_metadata.get("clipped_source_ids", []) as Array)
		== expected_clipped_source_ids
		and (live_metadata.get("handle_source_ids", []) as Array)
		== [PROTECTED_HANDLE_SOURCE_ID]
		and (
			int(live_metadata.get("clipped_vertex_count", -1)) > 0
			if clipped_rest_present
			else int(live_metadata.get("clipped_vertex_count", -1)) == 0
		)
		and int(live_metadata.get("handle_vertex_count", -1)) > 0
		and not String(live_metadata.get("handle_signature", "")).is_empty()
		and int(live_metadata.get("source_state_revision", -1)) >= 0
		and String(live_metadata.get("backend_method", ""))
		== expected_backend_method
		and String(live_metadata.get("final_compose_method", ""))
		== "compose_current_state_with_protected_mesh"
		and final_compose_availability_ok
	)
	return {
		"ok": (
			unexpected_surface_count == 0
			and clipped_rest_ok
			and handle_ok
			and live_metadata_ok
		),
		"contract": "two_live_solids_clipped_rest_plus_handle"
			if expected_ordinary_lane
			else "handle_only",
		"conceptual_lane_count": conceptual_lane_count,
		"expected_conceptual_lane_count": conceptual_lane_count,
		"materialized_nonempty_lane_count": materialized_nonempty_lane_count,
		"empty_clipped_rest_allowed": allow_empty_clipped_rest,
		"empty_clipped_rest_accepted": (
			expected_ordinary_lane
			and not clipped_rest_present
			and allow_empty_clipped_rest
			and handle_ok
		),
		"ordinary_history_retained_when_rest_empty": (
			expected_ordinary_lane and not clipped_rest_present
		),
		"final_compose_available": final_compose_available,
		"final_compose_required_available": expected_ordinary_lane,
		"final_compose_availability_ok": final_compose_availability_ok,
		"clipped_rest_surface_indices": Array(clipped_rest_surfaces),
		"handle_surface_indices": Array(handle_surfaces),
		"clipped_rest_ok": clipped_rest_ok,
		"handle_ok": handle_ok,
		"metadata_ok": live_metadata_ok,
		"combined_absolute_volume_m3": (
			clipped_rest_volume + handle_volume
		),
		"clipped_rest": MeshAnalyzerScript.strip_transient_arrays(
			clipped_rest_analysis
		),
		"handle": MeshAnalyzerScript.strip_transient_arrays(
			handle_analysis
		),
	}


func _apply_protected_publication_contract_gates(
	contract: Dictionary
) -> void:
	var label := String(contract.get("label", "unknown"))
	_mark(
		"direct_protected_composition_kind_or_current_csg_fallback",
		bool(contract.get("kind_gate_ok", false)),
		"unsupported protected publication kind at %s" % label
	)
	_mark(
		"direct_protected_composite_surface_count_or_current_csg_fallback",
		bool(contract.get("surface_count_gate_ok", false)),
		"direct protected publication surface count mismatch at %s" % label
	)
	_mark(
		"direct_protected_composite_material_presence_or_current_csg_fallback",
		bool(contract.get("material_presence_gate_ok", false)),
		"direct protected publication material presence mismatch at %s" % label
	)
	_mark(
		"direct_protected_composite_source_material_classified_or_current_csg_fallback",
		bool(contract.get("source_material_classified_gate_ok", false)),
		"direct protected publication source/material classification mismatch at %s" % label
	)
	_mark(
		"direct_protected_composite_no_empty_surface_or_current_csg_fallback",
		bool(contract.get("no_empty_surface_gate_ok", false)),
		"direct protected publication contains an empty surface at %s" % label
	)
	_mark(
		"direct_protected_composite_one_concave_collider_or_current_csg_fallback",
		bool(contract.get("one_concave_collider_gate_ok", false)),
		"direct protected publication did not have exactly one nonempty Concave collider at %s" % label
	)
	_mark(
		"direct_protected_composite_no_csg_node_or_current_csg_fallback",
		bool(contract.get("no_csg_node_gate_ok", false)),
		"direct protected publication retained a CSG composition node at %s" % label
	)
	_mark(
		"protected_handle_bootstrap_pending_only_and_final_revision_free",
		bool(contract.get("bootstrap_lifecycle_gate_ok", false)),
		"protected Handle bootstrap escaped pending staging at %s" % label
	)
	_mark(
		"live_decomposed_handle_and_clipped_rest_lanes",
		bool(contract.get("live_lane_topology_gate_ok", false)),
		"live Handle/clipped-Rest lanes were not independently valid at %s"
		% label
	)


func _record_protected_publication_contract(contract: Dictionary) -> void:
	_protected_publication_rows.append(contract)
	_apply_protected_publication_contract_gates(contract)
	_mark(
		"all_protected_publications_use_direct_native_composite",
		String(contract.get("accepted_path", ""))
		== "direct_native_protected_composite",
		"protected publication did not use direct native composition at %s"
		% String(contract.get("label", "unknown"))
	)


func _collect_collision_shapes(
	node: Node,
	result: Array[CollisionShape3D]
) -> void:
	if node == null:
		return
	if node is CollisionShape3D:
		result.append(node as CollisionShape3D)
	for child: Node in node.get_children():
		_collect_collision_shapes(child, result)


func _static_body_has_nonempty_concave_shape(body: StaticBody3D) -> bool:
	if body == null:
		return false
	var collision_shapes: Array[CollisionShape3D] = []
	_collect_collision_shapes(body, collision_shapes)
	for collision_shape: CollisionShape3D in collision_shapes:
		if (
			collision_shape == null
			or collision_shape.disabled
			or not collision_shape.shape is ConcavePolygonShape3D
		):
			continue
		var faces: PackedVector3Array = (
			collision_shape.shape as ConcavePolygonShape3D
		).get_faces()
		if not faces.is_empty() and faces.size() % 3 == 0:
			return true
	return false


func _count_csg_shape_descendants(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if node is CSGShape3D else 0
	for child: Node in node.get_children():
		count += _count_csg_shape_descendants(child)
	return count


func _collect_protected_handle_bootstrap_nodes(
	node: Node,
	result: Array[CSGCombiner3D]
) -> void:
	if node == null:
		return
	if (
		node is CSGCombiner3D
		and bool(node.get_meta(
			"forge_v2_native_protected_handle_bootstrap",
			false
		))
	):
		result.append(node as CSGCombiner3D)
	for child: Node in node.get_children():
		_collect_protected_handle_bootstrap_nodes(child, result)


func _new_bootstrap_observation() -> Dictionary:
	return {
		"sample_count": 0,
		"samples_with_bootstrap": 0,
		"observed_node_count": 0,
		"maximum_simultaneous_node_count": 0,
		"violation_count": 0,
		"observed_signatures": [],
		"latest": {},
	}


func _accumulate_bootstrap_observation(
	observation: Dictionary,
	diagnostics: Dictionary
) -> void:
	var nodes: Array[CSGCombiner3D] = []
	_collect_protected_handle_bootstrap_nodes(_presenter, nodes)
	var publication_pending := bool(diagnostics.get(
		"publication_pending",
		false
	))
	var sample_ok := true
	var signatures: Array[String] = []
	for bootstrap: CSGCombiner3D in nodes:
		var signature := String(bootstrap.get_meta(
			"forge_v2_native_protected_handle_signature",
			""
		))
		if not signature.is_empty() and not signatures.has(signature):
			signatures.append(signature)
		var parent := bootstrap.get_parent() as Node3D
		sample_ok = (
			sample_ok
			and publication_pending
			and bootstrap.name == PROTECTED_HANDLE_BOOTSTRAP_NAME
			and not signature.is_empty()
			and not bootstrap.use_collision
			and bootstrap.collision_layer == 0
			and bootstrap.collision_mask == 0
			and not bootstrap.is_visible_in_tree()
			and parent != null
			and not parent.visible
		)
	observation["sample_count"] = int(observation.get(
		"sample_count", 0
	)) + 1
	observation["observed_node_count"] = int(observation.get(
		"observed_node_count", 0
	)) + nodes.size()
	observation["maximum_simultaneous_node_count"] = maxi(
		int(observation.get("maximum_simultaneous_node_count", 0)),
		nodes.size()
	)
	if not nodes.is_empty():
		observation["samples_with_bootstrap"] = int(observation.get(
			"samples_with_bootstrap", 0
		)) + 1
	if not sample_ok:
		observation["violation_count"] = int(observation.get(
			"violation_count", 0
		)) + 1
	var observed_signatures := observation.get(
		"observed_signatures", []
	) as Array
	for signature: String in signatures:
		if not observed_signatures.has(signature):
			observed_signatures.append(signature)
	observed_signatures.sort()
	observation["observed_signatures"] = observed_signatures
	observation["latest"] = {
		"node_count": nodes.size(),
		"publication_pending": publication_pending,
		"safe_hidden_noncolliding": sample_ok,
		"signatures": signatures,
	}


func _collect_targetable_colliders(
	node: Node,
	result: Array[Node]
) -> void:
	if node == null:
		return
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		if (
			collision_object.collision_layer
			& PlacementTargetResolverScript.MATERIAL_SURFACE_COLLISION_LAYER
		) != 0:
			result.append(node)
	elif node is CSGShape3D:
		var csg_shape := node as CSGShape3D
		if (
			csg_shape.collision_layer
			& PlacementTargetResolverScript.MATERIAL_SURFACE_COLLISION_LAYER
		) != 0:
			result.append(node)
	for child: Node in node.get_children():
		_collect_targetable_colliders(child, result)


func _find_native_revision_ancestor(node: Node) -> Node3D:
	var cursor := node
	while cursor != null and cursor != _presenter:
		if cursor is Node3D and cursor.has_meta(
			"forge_v2_native_revision_kind"
		):
			return cursor as Node3D
		cursor = cursor.get_parent()
	return null


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node == null:
		return null
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null


func _csg_generated_mesh_is_ready(shape: CSGShape3D) -> bool:
	if shape == null or not shape.use_collision:
		return false
	for value: Variant in shape.get_meshes():
		if not value is Mesh:
			continue
		var mesh := value as Mesh
		if mesh != null and mesh.get_surface_count() > 0:
			return true
	return false


func _bake_publication_mesh(publication: Dictionary) -> ArrayMesh:
	var collider := publication.get("collider", null) as Node
	if collider is CSGShape3D:
		return (collider as CSGShape3D).bake_static_mesh()
	var revision := publication.get("revision", null) as Node
	var mesh_instance := _find_mesh_instance(revision)
	if mesh_instance != null and mesh_instance.mesh is ArrayMesh:
		return mesh_instance.mesh as ArrayMesh
	return null


func _publication_identity() -> Dictionary:
	var publication := _capture_native_publication()
	var collider := publication.get("collider", null) as Object
	var revision := publication.get("revision", null) as Node
	if collider == null:
		return {}
	return {
		"surface_target_id": StringName(collider.get_meta(
			"forge_v2_surface_target_id",
			StringName()
		)),
		"body_id": StringName(collider.get_meta(
			"forge_v2_body_id",
			StringName()
		)),
		"material_variant_id": StringName(collider.get_meta(
			"forge_v2_material_variant_id",
			StringName()
		)),
		"native_revision": int(collider.get_meta(
			"forge_v2_native_revision",
			-1
		)),
		"revision_kind": StringName(revision.get_meta(
			"forge_v2_native_revision_kind",
			StringName()
		)) if revision != null else StringName(),
	}


func _capture_current_csg_parity(
	label: String,
	ordinary_bodies: Array[Resource]
) -> Dictionary:
	var publication := _capture_native_publication()
	var actual_mesh := _bake_publication_mesh(publication)
	var oracle_result := await _build_independent_current_csg_oracle(
		ordinary_bodies
	)
	var oracle_mesh := oracle_result.get("mesh", null) as ArrayMesh
	if actual_mesh == null or oracle_mesh == null:
		var unavailable_oracle_materials: Array[String] = []
		if oracle_mesh != null:
			unavailable_oracle_materials = (
				_mesh_material_signatures(oracle_mesh)
			)
		var unavailable_contract := _capture_protected_publication_contract(
			label,
			not ordinary_bodies.is_empty(),
			publication,
			actual_mesh,
			not ordinary_bodies.is_empty(),
			unavailable_oracle_materials,
			_native_diagnostics()
		)
		_mark(
			"direct_protected_composite_exact_oracle_material_set_at_parity",
			false,
			"direct/current-CSG material set unavailable at %s" % label
		)
		return {
			"label": label,
			"ok": false,
			"error": "actual_or_oracle_mesh_missing",
			"protected_publication_contract": unavailable_contract,
		}
	var actual := MeshAnalyzerScript.analyze_mesh(actual_mesh)
	var oracle := MeshAnalyzerScript.analyze_mesh(oracle_mesh)
	var surface := MeshAnalyzerScript.compare_surfaces(actual, oracle)
	var actual_to_oracle_witness := surface.get(
		"first_to_second_witness", {}
	) as Dictionary
	var oracle_to_actual_witness := surface.get(
		"second_to_first_witness", {}
	) as Dictionary
	var actual_witness_winding := MeshAnalyzerScript.absolute_winding_number(
		actual_to_oracle_witness.get("sample", Vector3.ZERO) as Vector3,
		oracle
	)
	var oracle_witness_winding := MeshAnalyzerScript.absolute_winding_number(
		oracle_to_actual_witness.get("sample", Vector3.ZERO) as Vector3,
		actual
	)
	var actual_to_oracle_distance := float(surface.get(
		"first_to_second_max_meters",
		INF
	))
	var oracle_to_actual_distance := float(surface.get(
		"second_to_first_max_meters",
		INF
	))
	var surface_delta := float(surface.get(
		"bidirectional_max_meters",
		INF
	))
	var actual_to_oracle_visual_ok := (
		actual_to_oracle_distance <= SURFACE_DISTANCE_LIMIT_METERS
		or actual_witness_winding >= ABSOLUTE_WINDING_INSIDE_MIN
	)
	var oracle_to_actual_visual_ok := (
		oracle_to_actual_distance <= SURFACE_DISTANCE_LIMIT_METERS
		or oracle_witness_winding >= ABSOLUTE_WINDING_INSIDE_MIN
	)
	var bounds_delta := _bounds_delta(actual, oracle)
	var volume_delta := absf(
		float(actual.get("absolute_volume_cubic_meters", 0.0))
		- float(oracle.get("absolute_volume_cubic_meters", 0.0))
	)
	var volume_limit := maxf(
		VOLUME_ABSOLUTE_LIMIT_M3,
		float(oracle.get("absolute_volume_cubic_meters", 0.0))
		* VOLUME_RELATIVE_LIMIT
	)
	var actual_materials := _mesh_material_signatures(actual_mesh)
	var oracle_materials := _mesh_material_signatures(oracle_mesh)
	var expected_add_material := _presenter.call(
		"_build_csg_body_material",
		ADD_MATERIAL_ID,
		false
	) as Material
	var expected_handle_material := _presenter.call(
		"_build_csg_body_material",
		HANDLE_MATERIAL_ID,
		false
	) as Material
	var expected_add_signature := _material_signature(expected_add_material)
	var expected_handle_signature := _material_signature(
		expected_handle_material
	)
	var publication_contract := _capture_protected_publication_contract(
		label,
		oracle_materials.has(expected_add_signature),
		publication,
		actual_mesh,
		not ordinary_bodies.is_empty(),
		oracle_materials,
		_native_diagnostics()
	)
	var exact_material_set_parity_ok := bool(publication_contract.get(
		"material_set_parity_ok",
		false
	))
	var live_lane_contract := publication_contract.get(
		"live_decomposed_lanes", {}
	) as Dictionary
	var live_lane_topology_ok := bool(publication_contract.get(
		"live_decomposed_lanes_ok",
		false
	))
	var live_lane_volume := float(live_lane_contract.get(
		"combined_absolute_volume_m3",
		actual.get("absolute_volume_cubic_meters", 0.0)
	))
	volume_delta = absf(
		live_lane_volume
		- float(oracle.get("absolute_volume_cubic_meters", 0.0))
	)
	var material_ok := (
		actual_materials == oracle_materials
		and exact_material_set_parity_ok
		and actual_materials.has(expected_handle_signature)
	)
	var normals_ok := (
		_mesh_normals_are_finite_nonzero(actual_mesh)
		and _mesh_normals_are_finite_nonzero(oracle_mesh)
	)
	var geometry_ok := (
		live_lane_topology_ok
		and _strict_topology_passes(oracle)
		and actual_to_oracle_visual_ok
		and oracle_to_actual_visual_ok
		and bounds_delta <= BOUNDS_LIMIT_METERS
		and volume_delta <= volume_limit
	)
	_mark(
		"current_csg_surface_topology_bounds_volume_parity",
		geometry_ok,
		"surface/topology/bounds/volume mismatch at %s" % label
	)
	_mark(
		"current_csg_material_and_normal_parity",
		material_ok and normals_ok,
		"material/normal mismatch at %s" % label
	)
	_mark(
		"direct_protected_composite_exact_oracle_material_set_at_parity",
		exact_material_set_parity_ok,
		"direct material set did not exactly match current CSG at %s" % label
	)
	return {
		"label": label,
		"ok": (
			geometry_ok
			and material_ok
			and normals_ok
			and bool(publication_contract.get("ok", false))
		),
		"protected_publication_contract": publication_contract,
		"surface_max_meters": surface_delta,
		"actual_to_oracle_meters": float(surface.get(
			"first_to_second_max_meters", INF
		)),
		"oracle_to_actual_meters": float(surface.get(
			"second_to_first_max_meters", INF
		)),
		"actual_to_oracle_witness": _surface_witness_summary(
			actual_to_oracle_witness
		),
		"oracle_to_actual_witness": _surface_witness_summary(
			oracle_to_actual_witness
		),
		"actual_witness_absolute_winding_in_oracle": actual_witness_winding,
		"oracle_witness_absolute_winding_in_actual": oracle_witness_winding,
		"absolute_winding_inside_min": ABSOLUTE_WINDING_INSIDE_MIN,
		"actual_to_oracle_visual_ok": actual_to_oracle_visual_ok,
		"oracle_to_actual_visual_ok": oracle_to_actual_visual_ok,
		"surface_limit_meters": SURFACE_DISTANCE_LIMIT_METERS,
		"bounds_max_meters": bounds_delta,
		"bounds_limit_meters": BOUNDS_LIMIT_METERS,
		"volume_delta_m3": volume_delta,
		"live_lane_absolute_volume_m3": live_lane_volume,
		"volume_limit_m3": volume_limit,
		"actual_combined_strict_topology_diagnostic_only": (
			_strict_topology_passes(actual)
		),
		"live_lane_topology": live_lane_contract,
		"oracle_strict_topology": _strict_topology_passes(oracle),
		"actual_materials": actual_materials,
		"oracle_materials": oracle_materials,
		"exact_material_set_parity": exact_material_set_parity_ok,
		"finite_nonzero_normals": normals_ok,
		"actual": MeshAnalyzerScript.strip_transient_arrays(actual),
		"current_csg_oracle": MeshAnalyzerScript.strip_transient_arrays(oracle),
	}


func _verify_final_extraction() -> Dictionary:
	var backend := _presenter.get("native_static_manifold_backend") as Object
	if (
		backend == null
		or not is_instance_valid(backend)
		or not backend.has_method(
			"compose_current_state_with_protected_mesh"
		)
	):
		return {"ok": false, "reason": "full_compose_backend_unavailable"}
	var handle_packet := _presenter.call(
		"_resolve_authoritative_protected_handle_packet",
		_handle
	) as Dictionary
	if not bool(handle_packet.get("ok", false)):
		return {"ok": false, "reason": "final_handle_packet_invalid"}
	var state_before := backend.call("get_state_info") as Dictionary
	var publication_before := _capture_native_publication()
	var revision_before := publication_before.get("revision", null) as Node
	var live_mesh := _bake_publication_mesh(publication_before)
	if revision_before == null or live_mesh == null:
		return {"ok": false, "reason": "final_live_publication_missing"}
	var live_source_ids_variant: Variant = revision_before.get_meta(
		"forge_v2_native_surface_source_ids",
		PackedInt32Array()
	)
	if not live_source_ids_variant is PackedInt32Array:
		return {"ok": false, "reason": "final_live_source_ids_invalid"}
	var live_lanes := _analyze_live_decomposed_lanes(
		live_mesh,
		live_source_ids_variant as PackedInt32Array,
		true,
		true,
		_capture_live_revision_metadata(revision_before)
	)
	var target_before := _publication_identity()
	var authoring_before := _atomic_state_snapshot()
	var authoring_digest_before := _snapshot_digest(authoring_before)
	var compose_variant: Variant = backend.call(
		"compose_current_state_with_protected_mesh",
		handle_packet.get("vertices", PackedVector3Array()),
		handle_packet.get("indices", PackedInt32Array())
	)
	var state_after := backend.call("get_state_info") as Dictionary
	var publication_after := _capture_native_publication()
	var target_after := _publication_identity()
	var authoring_after := _atomic_state_snapshot()
	var authoring_digest_after := _snapshot_digest(authoring_after)
	if not compose_variant is Dictionary:
		return {"ok": false, "reason": "full_compose_result_not_dictionary"}
	var compose_result := compose_variant as Dictionary
	var vertices_variant: Variant = compose_result.get(
		"vertices", PackedVector3Array()
	)
	var indices_variant: Variant = compose_result.get(
		"indices", PackedInt32Array()
	)
	var source_ids_variant: Variant = compose_result.get(
		"source_original_ids",
		compose_result.get("source_ids", PackedInt32Array())
	)
	if (
		not vertices_variant is PackedVector3Array
		or not indices_variant is PackedInt32Array
		or not source_ids_variant is PackedInt32Array
	):
		return {"ok": false, "reason": "full_compose_packet_types_invalid"}
	var vertices := vertices_variant as PackedVector3Array
	var indices := indices_variant as PackedInt32Array
	var source_ids := source_ids_variant as PackedInt32Array
	var extracted_mesh := _build_native_packet_mesh(vertices, indices)
	if extracted_mesh == null:
		return {"ok": false, "reason": "full_compose_mesh_build_failed"}
	var extracted := MeshAnalyzerScript.analyze_mesh(extracted_mesh)
	var live_combined := MeshAnalyzerScript.analyze_mesh(live_mesh)
	var extraction_surface := MeshAnalyzerScript.compare_surfaces(
		extracted,
		live_combined
	)
	var extraction_to_live_distance := float(extraction_surface.get(
		"first_to_second_max_meters", INF
	))
	var live_to_extraction_distance := float(extraction_surface.get(
		"second_to_first_max_meters", INF
	))
	var live_to_extraction_witness := extraction_surface.get(
		"second_to_first_witness", {}
	) as Dictionary
	var live_witness_winding := MeshAnalyzerScript.absolute_winding_number(
		live_to_extraction_witness.get("sample", Vector3.ZERO) as Vector3,
		extracted
	)
	var exterior_surface_ok := (
		extraction_to_live_distance <= SURFACE_DISTANCE_LIMIT_METERS
		and (
			live_to_extraction_distance <= SURFACE_DISTANCE_LIMIT_METERS
			or live_witness_winding >= ABSOLUTE_WINDING_INSIDE_MIN
		)
	)
	var bounds_delta := _bounds_delta(extracted, live_combined)
	var native_volume := float(compose_result.get(
		"manifold_volume_m3", 0.0
	))
	var analyzer_volume := float(extracted.get(
		"absolute_volume_cubic_meters", 0.0
	))
	var live_lane_volume := float(live_lanes.get(
		"combined_absolute_volume_m3", 0.0
	))
	var volume_limit := maxf(
		VOLUME_ABSOLUTE_LIMIT_M3,
		native_volume * VOLUME_RELATIVE_LIMIT
	)
	var volume_ok := (
		is_finite(native_volume)
		and native_volume > 0.0
		and absf(analyzer_volume - native_volume) <= volume_limit
		and absf(live_lane_volume - native_volume) <= volume_limit
	)
	var source_counts := PackedInt32Array([0, 0, 0])
	var source_schema_ok := source_ids.size() == indices.size() / 3
	for source_id: int in source_ids:
		if source_id < ORDINARY_SOURCE_ID or source_id > SUBTRACTION_SOURCE_ID:
			source_schema_ok = false
			continue
		source_counts[source_id] += 1
	source_schema_ok = (
		source_schema_ok
		and source_counts[ORDINARY_SOURCE_ID]
		== int(compose_result.get("base_source_triangle_count", -1))
		and source_counts[PROTECTED_HANDLE_SOURCE_ID]
		== int(compose_result.get("protected_source_triangle_count", -1))
		and source_counts[SUBTRACTION_SOURCE_ID]
		== int(compose_result.get("subtraction_source_triangle_count", -1))
	)
	var native_state_before := _native_state_history_snapshot(state_before)
	var native_state_after := _native_state_history_snapshot(state_after)
	var state_unchanged := native_state_before == native_state_after
	var authoring_state_unchanged := (
		authoring_digest_before == authoring_digest_after
	)
	var publication_unchanged: bool = (
		publication_after.get("revision", null) == revision_before
		and target_after == target_before
		and bool(publication_after.get("complete", false))
	)
	var bounds_sensible := bounds_delta <= BOUNDS_LIMIT_METERS
	for suffix: String in ["x", "y", "z"]:
		var size_value := float(extracted.get(
			"aabb_size_%s" % suffix, 0.0
		))
		bounds_sensible = (
			bounds_sensible and is_finite(size_value) and size_value > 0.0
		)
	var native_contract_ok := (
		bool(compose_result.get("ok", false))
		and String(compose_result.get("status", "")) == "NoError"
		and bool(compose_result.get("watertight", false))
		and String(compose_result.get("operation", ""))
		== "compose_current_state_with_protected_mesh"
		and int(compose_result.get("source_state_revision", -1))
		== int(state_before.get("state_revision", -2))
	)
	var single_shell_ok := _strict_topology_passes(extracted)
	return {
		"ok": (
			native_contract_ok
			and source_schema_ok
			and single_shell_ok
			and bool(live_lanes.get("ok", false))
			and exterior_surface_ok
			and bounds_sensible
			and volume_ok
			and state_unchanged
			and authoring_state_unchanged
			and publication_unchanged
		),
		"method": "compose_current_state_with_protected_mesh",
		"native_contract_ok": native_contract_ok,
		"source_schema_ok": source_schema_ok,
		"source_triangle_counts": Array(source_counts),
		"single_watertight_component": single_shell_ok,
		"live_lanes_ok": bool(live_lanes.get("ok", false)),
		"live_lanes": live_lanes,
		"extraction_to_live_meters": extraction_to_live_distance,
		"live_to_extraction_meters": live_to_extraction_distance,
		"live_witness_absolute_winding_in_extraction": live_witness_winding,
		"exterior_surface_ok": exterior_surface_ok,
		"bounds_delta_meters": bounds_delta,
		"bounds_sensible": bounds_sensible,
		"native_volume_m3": native_volume,
		"analyzer_volume_m3": analyzer_volume,
		"live_lane_volume_m3": live_lane_volume,
		"volume_limit_m3": volume_limit,
		"volume_ok": volume_ok,
		"state_unchanged": state_unchanged,
		"native_state_before": native_state_before,
		"native_state_after": native_state_after,
		"authoring_state_unchanged": authoring_state_unchanged,
		"authoring_digest_before": authoring_digest_before.substr(0, 16),
		"authoring_digest_after": authoring_digest_after.substr(0, 16),
		"publication_and_target_unchanged": publication_unchanged,
		"analysis": MeshAnalyzerScript.strip_transient_arrays(extracted),
	}


func _native_state_history_snapshot(state_info: Dictionary) -> Dictionary:
	var result := {}
	for key: String in [
		"state_initialized",
		"state_revision",
		"state_vertex_count",
		"state_triangle_count",
		"state_volume_m3",
		"history_window_enabled",
		"history_window_capacity",
		"checkpoint_operation_count",
		"active_tail_cursor",
		"tail_timeline_count",
		"redo_count",
		"retained_state_count",
		"retained_total_vertices",
		"retained_total_triangles",
		"promotion_count",
		"boolean_count",
		"export_count",
	]:
		result[key] = state_info.get(key, null)
	return result


func _build_native_packet_mesh(
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> ArrayMesh:
	if vertices.is_empty() or indices.is_empty() or indices.size() % 3 != 0:
		return null
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index_value: int in indices:
		if index_value < 0 or index_value >= vertices.size():
			return null
		surface_tool.add_vertex(vertices[index_value])
	surface_tool.index()
	surface_tool.generate_normals()
	return surface_tool.commit()


func _surface_witness_summary(witness: Dictionary) -> Dictionary:
	var sample := witness.get("sample", Vector3.ZERO) as Vector3
	var closest := witness.get("closest", Vector3.ZERO) as Vector3
	return {
		"distance_meters": float(witness.get("distance_meters", INF)),
		"sample": [sample.x, sample.y, sample.z],
		"closest": [closest.x, closest.y, closest.z],
	}


func _build_independent_current_csg_oracle(
	ordinary_bodies: Array[Resource]
) -> Dictionary:
	var outer := CSGCombiner3D.new()
	outer.name = "BoundedAddIndependentOuter"
	outer.operation = CSGShape3D.OPERATION_UNION
	outer.calculate_tangents = false
	outer.visible = false
	_workspace.add_child(outer)
	var ordinary := CSGCombiner3D.new()
	ordinary.name = "BoundedAddIndependentOrdinaryMinusHandle"
	ordinary.operation = CSGShape3D.OPERATION_UNION
	ordinary.calculate_tangents = false
	outer.add_child(ordinary)
	for body_index in range(ordinary_bodies.size()):
		if not bool(_presenter.call(
			"_append_csg_body_shape",
			ordinary,
			ordinary_bodies[body_index],
			ADD_MATERIAL_ID,
			false,
			body_index
		)):
			outer.queue_free()
			return {"ok": false, "error": "ordinary_shape_rejected"}
	if not bool(_presenter.call(
		"_append_csg_body_shape",
		ordinary,
		_handle,
		ADD_MATERIAL_ID,
		true,
		ordinary_bodies.size()
	)):
		outer.queue_free()
		return {"ok": false, "error": "handle_subtraction_rejected"}
	if not bool(_presenter.call(
		"_append_csg_body_shape",
		outer,
		_handle,
		HANDLE_MATERIAL_ID,
		false,
		ordinary_bodies.size() + 1
	)):
		outer.queue_free()
		return {"ok": false, "error": "handle_union_rejected"}
	await process_frame
	await process_frame
	var baked := outer.bake_static_mesh()
	outer.queue_free()
	return {
		"ok": baked != null and baked.get_surface_count() > 0,
		"mesh": baked,
	}


func _strict_topology_passes(analysis: Dictionary) -> bool:
	return (
		int(analysis.get("triangle_count", 0)) > 0
		and int(analysis.get("nonfinite_vertex_count", -1)) == 0
		and int(analysis.get(
			"strict_degenerate_triangle_collapse_count", -1
		)) == 0
		and bool(analysis.get("strict_watertight", false))
		and int(analysis.get("strict_component_count", -1)) == 1
		and int(analysis.get("strict_boundary_edge_count", -1)) == 0
		and int(analysis.get("strict_nonmanifold_edge_count", -1)) == 0
		and int(analysis.get("strict_directed_edge_mismatch_count", -1)) == 0
	)


func _strict_watertight_any_component_count(
	analysis: Dictionary
) -> bool:
	return (
		int(analysis.get("triangle_count", 0)) > 0
		and int(analysis.get("nonfinite_vertex_count", -1)) == 0
		and int(analysis.get(
			"strict_degenerate_triangle_collapse_count", -1
		)) == 0
		and bool(analysis.get("strict_watertight", false))
		and int(analysis.get("strict_component_count", 0)) >= 1
		and int(analysis.get("strict_boundary_edge_count", -1)) == 0
		and int(analysis.get("strict_nonmanifold_edge_count", -1)) == 0
		and int(analysis.get(
			"strict_directed_edge_mismatch_count", -1
		)) == 0
	)


func _strict_topology_equivalent(
	first: Dictionary,
	second: Dictionary
) -> bool:
	for key: String in [
		"strict_component_count",
		"strict_euler_characteristic",
		"strict_genus",
		"strict_boundary_edge_count",
		"strict_nonmanifold_edge_count",
		"strict_directed_edge_mismatch_count",
	]:
		if first.get(key, null) != second.get(key, null):
			return false
	return bool(first.get("strict_watertight", false)) \
		== bool(second.get("strict_watertight", false))


func _bounds_delta(first: Dictionary, second: Dictionary) -> float:
	var maximum := 0.0
	for suffix: String in [
		"position_x", "position_y", "position_z",
		"size_x", "size_y", "size_z",
	]:
		maximum = maxf(maximum, absf(
			float(first.get("aabb_%s" % suffix, INF))
			- float(second.get("aabb_%s" % suffix, -INF))
		))
	return maximum


func _mesh_material_signatures(mesh: ArrayMesh) -> Array[String]:
	var result: Array[String] = []
	if mesh == null:
		return result
	for surface_index in range(mesh.get_surface_count()):
		var signature := _material_signature(
			mesh.surface_get_material(surface_index)
		)
		if not result.has(signature):
			result.append(signature)
	result.sort()
	return result


func _normalize_material_signatures(
	values: Array[String]
) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		if not result.has(value):
			result.append(value)
	result.sort()
	return result


func _packed_int32_values_are_unique(values: PackedInt32Array) -> bool:
	var seen := {}
	for value: int in values:
		if seen.has(value):
			return false
		seen[value] = true
	return true


func _packed_int32_values_are_strictly_increasing(
	values: PackedInt32Array
) -> bool:
	for index in range(1, values.size()):
		if values[index] <= values[index - 1]:
			return false
	return true


func _material_signature(material: Material) -> String:
	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		var color := standard.albedo_color
		return "standard:%.6f,%.6f,%.6f,%.6f:%.6f:%.6f" % [
			color.r,
			color.g,
			color.b,
			color.a,
			standard.metallic,
			standard.roughness,
		]
	if material == null:
		return "null"
	return "%s:%s" % [material.get_class(), material.resource_path]


func _mesh_normals_are_finite_nonzero(mesh: ArrayMesh) -> bool:
	if mesh == null or mesh.get_surface_count() <= 0:
		return false
	for surface_index in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays.size() < Mesh.ARRAY_MAX:
			return false
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if vertices.is_empty() or normals.size() != vertices.size():
			return false
		for normal: Vector3 in normals:
			if not normal.is_finite() or normal.length_squared() <= 0.25:
				return false
	return true


func _capture_real_resolver_abc(
	publication: Dictionary,
	mesh: ArrayMesh,
	label: String
) -> Dictionary:
	var collider := publication.get("collider", null) as Node3D
	if collider == null or mesh == null:
		return {"ok": false, "rows": [], "reason": "publication_missing"}
	var expected_identity := _publication_identity()
	var add_material := _presenter.call(
		"_build_csg_body_material",
		ADD_MATERIAL_ID,
		false
	) as Material
	var handle_material := _presenter.call(
		"_build_csg_body_material",
		HANDLE_MATERIAL_ID,
		false
	) as Material
	var categories := [
		{
			"probe": "A",
			"category": "ordinary",
			"material": _material_signature(add_material),
		},
		{
			"probe": "B",
			"category": "handle",
			"material": _material_signature(handle_material),
		},
		{
			"probe": "C",
			"category": "ordinary",
			"material": _material_signature(add_material),
		},
	]
	var used_triangles: Dictionary = {}
	var rows: Array[Dictionary] = []
	var all_ok := true
	for category_variant: Variant in categories:
		var category := category_variant as Dictionary
		var probe := await _probe_material_surface(
			mesh,
			collider,
			String(category.get("material", "")),
			expected_identity,
			used_triangles,
			"%s_%s" % [label, String(category.get("probe", ""))]
		)
		probe["probe"] = category.get("probe", "")
		probe["surface_category"] = category.get("category", "")
		rows.append(probe)
		all_ok = all_ok and bool(probe.get("ok", false))
	return {"ok": all_ok and rows.size() == 3, "rows": rows}


func _probe_material_surface(
	mesh: ArrayMesh,
	mesh_owner: Node3D,
	required_material_signature: String,
	expected_identity: Dictionary,
	used_triangles: Dictionary,
	label: String
) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for surface_index in range(mesh.get_surface_count()):
		if _material_signature(mesh.surface_get_material(surface_index)) \
			!= required_material_signature:
			continue
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays.size() < Mesh.ARRAY_MAX:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		if indices.is_empty():
			indices.resize(vertices.size())
			for vertex_index in range(vertices.size()):
				indices[vertex_index] = vertex_index
		for triangle_index in range(indices.size() / 3):
			var triangle_key := "%d:%d" % [surface_index, triangle_index]
			if used_triangles.has(triangle_key):
				continue
			var first_index := indices[triangle_index * 3]
			var second_index := indices[triangle_index * 3 + 1]
			var third_index := indices[triangle_index * 3 + 2]
			if (
				first_index < 0 or first_index >= vertices.size()
				or second_index < 0 or second_index >= vertices.size()
				or third_index < 0 or third_index >= vertices.size()
			):
				continue
			var a := vertices[first_index]
			var b := vertices[second_index]
			var c := vertices[third_index]
			var cross := (b - a).cross(c - a)
			if cross.length_squared() <= 0.000000000001:
				continue
			candidates.append({
				"key": triangle_key,
				"surface": surface_index,
				"triangle": triangle_index,
				"center": (a + b + c) / 3.0,
				"normal": cross.normalized(),
				"area_squared": cross.length_squared(),
			})
	candidates.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return float(first.get("area_squared", 0.0)) \
			> float(second.get("area_squared", 0.0))
	)
	for candidate_variant: Variant in candidates:
		var candidate := candidate_variant as Dictionary
		for normal_sign: float in [-1.0, 1.0]:
			var mesh_local_center := candidate.get(
				"center", Vector3.ZERO
			) as Vector3
			var mesh_local_normal := (
				candidate.get("normal", Vector3.ZERO) as Vector3
			) * normal_sign
			var workspace_center := _workspace.to_local(
				mesh_owner.to_global(mesh_local_center)
			)
			var workspace_normal := (
				_workspace.global_transform.basis.inverse()
				* (
					mesh_owner.global_transform.basis
					* mesh_local_normal
				)
			).normalized()
			var direct := _direct_surface_probe(
				workspace_center,
				workspace_normal,
				mesh_owner
			)
			if not bool(direct.get("ok", false)):
				continue
			var camera := _workspace.get("camera") as Camera3D
			if camera == null:
				return {"ok": false, "reason": "workspace_camera_missing"}
			var expected_position := direct.get(
				"local_position", workspace_center
			) as Vector3
			var expected_normal := direct.get(
				"local_normal", workspace_normal
			) as Vector3
			var up := (
				Vector3.UP
				if absf(expected_normal.dot(Vector3.UP)) < 0.94
				else Vector3.RIGHT
			)
			camera.global_position = _workspace.to_global(
				expected_position
				+ expected_normal * CAMERA_DISTANCE_METERS
			)
			camera.look_at(_workspace.to_global(expected_position), up)
			camera.current = true
			camera.near = 0.005
			camera.far = 2.0
			await process_frame
			var projection := _workspace.call(
				"project_workspace_local_to_screen",
				expected_position
			) as Dictionary
			if not bool(projection.get("valid", false)):
				continue
			var hit := _workspace.call(
				"resolve_strict_surface_target",
				projection.get("screen_position", Vector2.ZERO),
				PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE,
				StringName(expected_identity.get(
					"surface_target_id", StringName()
				))
			) as Dictionary
			var validation := _validate_target_hit(
				hit,
				expected_position,
				expected_normal,
				mesh_owner,
				expected_identity
			)
			if not bool(validation.get("ok", false)):
				continue
			used_triangles[candidate.get("key", "")] = true
			return {
				"ok": true,
				"label": label,
				"surface": int(candidate.get("surface", -1)),
				"triangle": int(candidate.get("triangle", -1)),
				"material_signature": required_material_signature,
				"surface_target_id": String(expected_identity.get(
					"surface_target_id", ""
				)),
				"position_error_meters": validation.get(
					"position_error_meters", INF
				),
				"normal_dot": validation.get("normal_dot", 0.0),
				"abc_dot": validation.get("abc_dot", 1.0),
			}
	return {
		"ok": false,
		"label": label,
		"reason": "no_resolver_valid_triangle_for_material",
		"material_signature": required_material_signature,
		"candidate_count": candidates.size(),
	}


func _direct_surface_probe(
	local_center: Vector3,
	local_normal: Vector3,
	expected_collider: Object
) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		_workspace.to_global(
			local_center + local_normal * DIRECT_RAY_OFFSET_METERS
		),
		_workspace.to_global(
			local_center - local_normal * DIRECT_RAY_OFFSET_METERS
		),
		PlacementTargetResolverScript.MATERIAL_SURFACE_COLLISION_LAYER
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := _workspace.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.get("collider", null) != expected_collider:
		return {"ok": false}
	var local_position := _workspace.to_local(
		hit.get("position", Vector3.ZERO) as Vector3
	)
	var local_hit_normal := (
		_workspace.global_transform.basis.inverse()
		* (hit.get("normal", Vector3.ZERO) as Vector3)
	).normalized()
	return {
		"ok": (
			local_position.distance_to(local_center)
			<= TARGET_POSITION_LIMIT_METERS
			and local_hit_normal.dot(local_normal) >= TARGET_NORMAL_DOT_MIN
		),
		"local_position": local_position,
		"local_normal": local_hit_normal,
	}


func _validate_target_hit(
	hit: Dictionary,
	expected_position: Vector3,
	expected_normal: Vector3,
	expected_collider: Object,
	expected_identity: Dictionary
) -> Dictionary:
	var actual_position := hit.get(
		"local_position", Vector3.ZERO
	) as Vector3
	var actual_normal := (
		hit.get("local_normal", Vector3.ZERO) as Vector3
	).normalized()
	var contact := (
		hit.get("local_contact_direction", Vector3.ZERO) as Vector3
	).normalized()
	var position_error := actual_position.distance_to(expected_position)
	var normal_dot := actual_normal.dot(expected_normal)
	var abc_dot := actual_normal.dot(contact)
	var ok: bool = (
		bool(hit.get("valid", false))
		and hit.get("collider", null) == expected_collider
		and StringName(hit.get("target_kind", StringName()))
		== PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE
		and StringName(hit.get("surface_target_id", StringName()))
		== StringName(expected_identity.get(
			"surface_target_id", StringName()
		))
		and StringName(hit.get("source_body_id", StringName()))
		== StringName(expected_identity.get("body_id", StringName()))
		and StringName(hit.get("source_record_id", StringName()))
		== StringName(expected_identity.get(
			"material_variant_id", StringName()
		))
		and not bool(hit.get("is_clamped", true))
		and position_error <= TARGET_POSITION_LIMIT_METERS
		and normal_dot >= TARGET_NORMAL_DOT_MIN
		and abc_dot <= TARGET_ABC_DOT_MAX
	)
	return {
		"ok": ok,
		"position_error_meters": position_error,
		"normal_dot": normal_dot,
		"abc_dot": abc_dot,
	}


func _verify_target_identity_sequence(
	identities: Array[StringName]
) -> void:
	var nonempty := true
	var changed_every_transition := true
	for identity_index in range(identities.size()):
		nonempty = nonempty and identities[identity_index] != StringName()
		if identity_index > 0:
			changed_every_transition = (
				changed_every_transition
				and identities[identity_index] != identities[identity_index - 1]
			)
	_mark(
		"surface_target_identity_tracks_navigation",
		nonempty and changed_every_transition and identities.size() == 14,
		"target identity was empty or stale across undo/redo/branch"
	)


func _verify_atomic_rejection(body: Resource, label: String) -> void:
	if body == null:
		_mark(
			"unsupported_and_mixed_material_rejection_atomic",
			false,
			"%s rejection fixture was null" % label
		)
		return
	_append_pending_body(_state, body)
	var before := _atomic_state_snapshot()
	var before_digest := _snapshot_digest(before)
	var before_target := StringName(
		_publication_identity().get("surface_target_id", StringName())
	)
	var layer := _state.call(
		"commit_material_body_as_layer",
		StringName(body.get("body_id"))
	) as Resource
	var after := _atomic_state_snapshot()
	var after_digest := _snapshot_digest(after)
	var after_target := StringName(
		_publication_identity().get("surface_target_id", StringName())
	)
	var cache := _state.call(
		"get_committed_volume_cache_diagnostics"
	) as Dictionary
	var ok: bool = (
		layer == null
		and before_digest == after_digest
		and StringName(body.get("committed_layer_id")) == StringName()
		and bool(body.get("layer_active"))
		and not bool(_state.call("has_pending_bounded_history_promotion"))
		and not bool(cache.get("cache_candidate_pending", true))
		and before_target == after_target
	)
	_mark(
		"unsupported_and_mixed_material_rejection_atomic",
		ok,
		"%s commit rejection mutated state/cache/target" % label
	)
	_atomic_rejection_rows.append({
		"label": label,
		"returned_null": layer == null,
		"state_digest_before": before_digest.substr(0, 16),
		"state_digest_after": after_digest.substr(0, 16),
		"state_equal": before_digest == after_digest,
		"body_still_pending": StringName(body.get("committed_layer_id"))
		== StringName(),
		"cache_candidate_pending": bool(cache.get(
			"cache_candidate_pending", true
		)),
		"target_unchanged": before_target == after_target,
		"ok": ok,
	})
	_remove_pending_body(_state, StringName(body.get("body_id")))


func _atomic_state_snapshot() -> Dictionary:
	var presentation := _presentation()
	var bodies: Array[Dictionary] = []
	for body_variant: Variant in _state.get("material_bodies") as Array:
		var body := body_variant as Resource
		if body != null:
			bodies.append(_body_snapshot(body))
	var tail_layers: Array[Dictionary] = []
	for layer_variant: Variant in _state.get("forge_layers") as Array:
		var layer := layer_variant as Resource
		if layer != null:
			tail_layers.append(_layer_snapshot(layer))
	var redo_layers: Array[Dictionary] = []
	for layer_variant: Variant in _state.get("undone_forge_layers") as Array:
		var layer := layer_variant as Resource
		if layer != null:
			redo_layers.append(_layer_snapshot(layer))
	var protected_layers: Array[Dictionary] = []
	for layer_variant: Variant in _state.get("protected_forge_layers") as Array:
		var layer := layer_variant as Resource
		if layer != null:
			protected_layers.append(_layer_snapshot(layer))
	var transition := _state.call(
		"get_bounded_history_transition"
	) as Dictionary
	return {
		"updated_timestamp": float(_state.get("updated_timestamp")),
		"lifetime_operation_count": int(_state.get(
			"bounded_history_lifetime_operation_count"
		)),
		"transition_revision": int(_state.get(
			"bounded_history_transition_revision"
		)),
		"suspended_reason": StringName(_state.get(
			"bounded_history_suspended_reason"
		)),
		"recovery_blocked_reason": StringName(_state.get(
			"bounded_history_recovery_blocked_reason"
		)),
		"selected_body_id": StringName(_state.get(
			"selected_material_body_id"
		)),
		"bodies": bodies,
		"tail_layers": tail_layers,
		"redo_layers": redo_layers,
		"protected_layers": protected_layers,
		"checkpoint_packet": (presentation.get(
			"checkpoint_packet", {}
		) as Dictionary).duplicate(true),
		"checkpoint_identity": (presentation.get(
			"checkpoint_identity", {}
		) as Dictionary).duplicate(true),
		"ledger": (_state.call(
			"get_material_ledger_summary"
		) as Dictionary).duplicate(true),
		"cache": (_state.call(
			"get_committed_volume_cache_diagnostics"
		) as Dictionary).duplicate(true),
		"transition": {
			"kind": StringName(transition.get("kind", StringName())),
			"revision": int(transition.get("revision", -1)),
			"requires_native_ack": bool(transition.get(
				"requires_native_ack", false
			)),
			"pending_native_ack": bool(transition.get(
				"pending_native_ack", false
			)),
			"appended_layer_id": StringName(transition.get(
				"appended_layer_id", StringName()
			)),
			"appended_body_id": StringName(transition.get(
				"appended_body_id", StringName()
			)),
		},
	}


func _body_snapshot(body: Resource) -> Dictionary:
	return {
		"body_id": StringName(body.get("body_id")),
		"source_record_id": StringName(body.get("source_record_id")),
		"body_kind": StringName(body.get("body_kind")),
		"material_variant_id": StringName(body.get("material_variant_id")),
		"operation_mode": StringName(body.get("operation_mode")),
		"placement_policy": StringName(body.get("placement_policy")),
		"shape_kind": StringName(body.get("shape_kind")),
		"path_points": body.get("path_points"),
		"path_surface_normals": body.get("path_surface_normals"),
		"path_contact_directions": body.get("path_contact_directions"),
		"radius_meters": float(body.get("radius_meters")),
		"profile_id": StringName(body.get("profile_id")),
		"profile_polygon": body.get("profile_polygon_2d_meters"),
		"profile_anchor": body.get("profile_anchor_2d_meters"),
		"profile_contact": body.get(
			"profile_contact_point_relative_2d_meters"
		),
		"profile_runtime_schema_version": int(body.get(
			"profile_runtime_schema_version"
		)),
		"committed_layer_id": StringName(body.get("committed_layer_id")),
		"layer_active": bool(body.get("layer_active")),
		"created_timestamp": float(body.get("created_timestamp")),
		"updated_timestamp": float(body.get("updated_timestamp")),
	}


func _layer_snapshot(layer: Resource) -> Dictionary:
	return {
		"layer_id": StringName(layer.get("layer_id")),
		"order_index": int(layer.get("order_index")),
		"operation_type": StringName(layer.get("operation_type")),
		"operation_material_id": StringName(layer.get(
			"operation_material_id"
		)),
		"csg_operation": StringName(layer.get("csg_operation")),
		"body_ids": (layer.get("body_ids") as Array).duplicate(true),
		"source_record_ids": (
			layer.get("source_record_ids") as Array
		).duplicate(true),
		"input_shape_records": (
			layer.get("input_shape_records") as Array
		).duplicate(true),
		"ledger_delta": (
			layer.get("ledger_delta") as Dictionary
		).duplicate(true),
		"removed_material_records": (
			layer.get("removed_material_records") as Array
		).duplicate(true),
		"undoable": bool(layer.get("undoable")),
	}


func _snapshot_digest(snapshot: Dictionary) -> String:
	return var_to_bytes(snapshot).hex_encode().sha256_text()


func _history_counters_equal(
	first: Dictionary,
	second: Dictionary
) -> bool:
	for key: String in [
		"boolean_count",
		"export_count",
		"promotion_count",
		"checkpoint_operation_count",
		"active_tail_cursor",
		"tail_timeline_count",
		"redo_count",
		"retained_state_count",
		"expected_revision",
		"published_revision",
	]:
		if first.get(key, null) != second.get(key, null):
			return false
	return true


func _verify_save_restore_rebind(
	branch_bodies: Array[Resource],
	pre_save_target_id: StringName
) -> Dictionary:
	var before_presentation := _presentation()
	var before_identity := (before_presentation.get(
		"checkpoint_identity", {}
	) as Dictionary).duplicate(true)
	var before_native := _native_diagnostics()
	var saved_wip := _controller.call(
		"build_crafted_item_wip_for_save"
	) as Resource
	var after_presentation := _presentation()
	var after_identity := (after_presentation.get(
		"checkpoint_identity", {}
	) as Dictionary).duplicate(true)
	var after_native := _native_diagnostics()
	var identity_logical_stable := (
		StringName(before_identity.get("checkpoint_id", StringName()))
		== StringName(after_identity.get("checkpoint_id", StringName()))
		and int(before_identity.get("checkpoint_revision", -1))
		== int(after_identity.get("checkpoint_revision", -2))
		and int(before_identity.get("checkpoint_operation_count", -1))
		== int(after_identity.get("checkpoint_operation_count", -2))
		and int(after_identity.get(
			"checkpoint_materialization_revision", -1
		)) == int(before_identity.get(
			"checkpoint_materialization_revision", -1
		)) + 1
	)
	var materialization_ok := (
		saved_wip != null
		and identity_logical_stable
		and bool(after_presentation.get("checkpoint_restore_ready", false))
		and not bool(after_presentation.get("checkpoint_mesh_dirty", true))
		and int(after_presentation.get(
			"materialized_mesh_operation_count", -1
		)) == 15
		and int(after_native.get("hot_checkpoint_exports", -1)) == 0
		and int(after_native.get("lazy_checkpoint_exports", -1))
		== int(before_native.get("lazy_checkpoint_exports", -1)) + 1
		and int(after_native.get(
			"checkpoint_materialization_attempt_count", -1
		)) == int(before_native.get(
			"checkpoint_materialization_attempt_count", -1
		)) + 1
		and int(after_native.get(
			"checkpoint_materialization_count", -1
		)) == int(before_native.get(
			"checkpoint_materialization_count", -1
		)) + 1
	)
	if saved_wip == null:
		return {
			"ok": false,
			"materialization_ok": false,
			"error": "controller_save_guard_returned_null",
		}
	var save_error := ResourceSaver.save(saved_wip, SAVE_PATH)
	var loaded_wip := ResourceLoader.load(
		SAVE_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Resource
	var disk_ok := save_error == OK and loaded_wip != null
	var load_ok := false
	if disk_ok:
		load_ok = bool(_controller.call("load_saved_wip", loaded_wip))
	if not load_ok:
		return {
			"ok": false,
			"materialization_ok": materialization_ok,
			"disk_roundtrip_ok": disk_ok,
			"load_ok": false,
		}
	_state = _controller.call("get_active_authoring_state") as Resource
	var load_ready := await _await_native_publication("restore")
	var loaded_presentation := _presentation()
	var loaded_native := _native_diagnostics()
	var loaded_target := _publication_identity()
	var loaded_shape_ok := (
		bool(load_ready.get("ok", false))
		and int(loaded_presentation.get("checkpoint_operation_count", -1)) == 15
		and int((loaded_presentation.get(
			"active_tail_layers", []
		) as Array).size()) == 4
		and int(loaded_presentation.get("protected_body_count", -1)) == 1
		and int(loaded_presentation.get("logical_body_count", -1)) == 6
		and bool(loaded_presentation.get("checkpoint_restore_ready", false))
		and not bool(loaded_presentation.get("recovery_blocked", true))
		and int(loaded_native.get("checkpoint_operation_count", -1)) == 15
		and int(loaded_native.get("retained_state_count", -1)) == 5
		and int(loaded_native.get("fallback_count", -1)) == 0
		and int(loaded_native.get(
			"checkpoint_materialization_attempt_count", -1
		)) == 0
		and int(loaded_native.get(
			"checkpoint_materialization_count", -1
		)) == 0
		and StringName(loaded_target.get(
			"surface_target_id", StringName()
		)) != StringName()
		and StringName(loaded_target.get(
			"surface_target_id", StringName()
		)) != pre_save_target_id
	)
	_workspace.call("clear_stage_controller")
	await process_frame
	await physics_frame
	_workspace.call("bind_stage_controller", _controller)
	var rebind_ready := await _await_native_publication("restore")
	var rebound_target := _publication_identity()
	var rebind_ok := (
		bool(rebind_ready.get("ok", false))
		and StringName(rebound_target.get(
			"surface_target_id", StringName()
		)) == StringName(loaded_target.get(
			"surface_target_id", StringName()
		))
		and not bool(_presentation().get("recovery_blocked", true))
		and int(_native_diagnostics().get("fallback_count", -1)) == 0
	)
	var restored_parity := await _capture_current_csg_parity(
		"RestoredBranchN19",
		branch_bodies
	)
	_parity_rows.append(restored_parity)
	return {
		"ok": (
			materialization_ok
			and disk_ok
			and loaded_shape_ok
			and rebind_ok
			and bool(restored_parity.get("ok", false))
		),
		"materialization_ok": materialization_ok,
		"logical_checkpoint_identity_stable": identity_logical_stable,
		"checkpoint_identity_before": before_identity,
		"checkpoint_identity_after": after_identity,
		"disk_roundtrip_ok": disk_ok,
		"load_restore_ok": loaded_shape_ok,
		"controller_rebind_ok": rebind_ok,
		"target_before_save": String(pre_save_target_id),
		"target_after_load": String(loaded_target.get(
			"surface_target_id", ""
		)),
		"target_after_rebind": String(rebound_target.get(
			"surface_target_id", ""
		)),
		"loaded_presentation": _presentation_summary(loaded_presentation),
		"loaded_native": _native_summary(loaded_native),
		"restored_parity_ok": bool(restored_parity.get("ok", false)),
	}


func _presentation_summary(presentation: Dictionary) -> Dictionary:
	return {
		"enabled": bool(presentation.get("bounded_history_enabled", false)),
		"suspended_reason": String(presentation.get("suspended_reason", "")),
		"recovery_blocked": bool(presentation.get("recovery_blocked", false)),
		"transition_revision": int(presentation.get("transition_revision", -1)),
		"checkpoint_operation_count": int(presentation.get(
			"checkpoint_operation_count", -1
		)),
		"checkpoint_mesh_dirty": bool(presentation.get(
			"checkpoint_mesh_dirty", false
		)),
		"checkpoint_restore_ready": bool(presentation.get(
			"checkpoint_restore_ready", false
		)),
		"checkpoint_identity": (presentation.get(
			"checkpoint_identity", {}
		) as Dictionary).duplicate(true),
		"tail_layer_count": (presentation.get(
			"active_tail_layers", []
		) as Array).size(),
		"redo_layer_count": (presentation.get(
			"redo_tail_layers", []
		) as Array).size(),
		"protected_body_count": int(presentation.get(
			"protected_body_count", -1
		)),
		"logical_body_count": int(presentation.get("logical_body_count", -1)),
		"pending_native_ack": bool(presentation.get(
			"pending_native_ack", false
		)),
	}


func _native_summary(diagnostics: Dictionary) -> Dictionary:
	var result := {}
	for key: String in [
		"lifecycle",
		"last_mode",
		"authoritative",
		"publication_pending",
		"bounded_transition_revision",
		"prefix_body_count",
		"expected_revision",
		"published_revision",
		"reset_count",
		"append_count",
		"undo_count",
		"redo_count_total",
		"restore_count",
		"hot_checkpoint_exports",
		"lazy_checkpoint_exports",
		"publication_count",
		"fallback_count",
		"last_failure_reason",
		"protected_composition_mode",
		"protected_composition_attempt_count",
		"protected_composition_success_count",
		"protected_composition_handle_only_count",
		"protected_composition_csg_fallback_count",
		"protected_composition_last_failure_reason",
		"protected_composition_backend_method",
		"protected_composition_source_state_revision",
		"protected_composition_total_ms",
		"protected_composition_subtract_ms",
		"protected_composition_union_ms",
		"protected_composition_export_ms",
		"protected_composition_output_vertices",
		"protected_composition_output_triangles",
		"protected_composition_ordinary_triangles",
		"protected_composition_protected_triangles",
		"protected_composition_subtraction_triangles",
		"protected_handle_cache_signature",
		"protected_handle_cache_ready",
		"protected_handle_cache_hit_count",
		"protected_handle_cache_miss_count",
		"protected_handle_bootstrap_count",
		"protected_handle_bootstrap_success_count",
		"protected_handle_bootstrap_failure_count",
		"protected_handle_bootstrap_last_failure_reason",
		"protected_handle_bootstrap_last_bake_ms",
		"protected_handle_bootstrap_pending",
		"protected_live_decomposition_attempt_count",
		"protected_live_decomposition_success_count",
		"protected_live_decomposition_last_failure_reason",
		"protected_live_backend_method",
		"protected_live_source_state_revision",
		"protected_live_clip_total_ms",
		"protected_live_clip_imports_ms",
		"protected_live_clip_subtract_ms",
		"protected_live_clip_export_ms",
		"protected_live_clip_vertices",
		"protected_live_clip_triangles",
		"protected_live_clip_ordinary_triangles",
		"protected_live_clip_subtraction_triangles",
		"protected_live_handle_vertices",
		"protected_live_handle_triangles",
		"protected_live_combined_vertices",
		"protected_live_combined_triangles",
		"protected_live_lane_count",
		"protected_live_unfused_geometry",
		"protected_live_full_compose_available",
		"protected_live_handle_packet_reused",
		"protected_live_combined_collision",
		"protected_live_final_union_performed",
		"history_window_enabled",
		"history_window_capacity",
		"checkpoint_operation_count",
		"checkpoint_materialization_attempt_count",
		"checkpoint_materialization_count",
		"promotion_count",
		"boolean_count",
		"export_count",
		"retained_state_count",
		"retained_total_vertices",
		"retained_total_triangles",
		"active_tail_cursor",
		"tail_timeline_count",
		"redo_count",
	]:
		result[key] = diagnostics.get(key, null)
	return result


func _protected_composition_diagnostic_snapshot(
	diagnostics: Dictionary
) -> Dictionary:
	var result := {}
	for key: String in [
		"protected_composition_mode",
		"protected_composition_last_failure_reason",
		"protected_composition_backend_method",
		"protected_composition_source_state_revision",
		"protected_composition_attempt_count",
		"protected_composition_success_count",
		"protected_composition_handle_only_count",
		"protected_composition_csg_fallback_count",
		"protected_composition_output_vertices",
		"protected_composition_output_triangles",
		"protected_composition_ordinary_triangles",
		"protected_composition_protected_triangles",
		"protected_composition_subtraction_triangles",
		"protected_handle_cache_signature",
		"protected_handle_cache_ready",
		"protected_handle_cache_hit_count",
		"protected_handle_cache_miss_count",
		"protected_handle_bootstrap_count",
		"protected_handle_bootstrap_success_count",
		"protected_handle_bootstrap_failure_count",
		"protected_handle_bootstrap_last_failure_reason",
		"protected_handle_bootstrap_last_bake_ms",
		"protected_handle_bootstrap_pending",
		"protected_live_decomposition_attempt_count",
		"protected_live_decomposition_success_count",
		"protected_live_decomposition_last_failure_reason",
		"protected_live_backend_method",
		"protected_live_source_state_revision",
		"protected_live_clip_total_ms",
		"protected_live_clip_imports_ms",
		"protected_live_clip_subtract_ms",
		"protected_live_clip_export_ms",
		"protected_live_clip_vertices",
		"protected_live_clip_triangles",
		"protected_live_clip_ordinary_triangles",
		"protected_live_clip_subtraction_triangles",
		"protected_live_handle_vertices",
		"protected_live_handle_triangles",
		"protected_live_combined_vertices",
		"protected_live_combined_triangles",
		"protected_live_lane_count",
		"protected_live_unfused_geometry",
		"protected_live_full_compose_available",
		"protected_live_handle_packet_reused",
		"protected_live_combined_collision",
		"protected_live_final_union_performed",
	]:
		result[key] = diagnostics.get(key, null)
	return result


func _publication_summary(publication: Dictionary) -> Dictionary:
	var revision := publication.get("revision", null) as Node
	var collider := publication.get("collider", null) as Object
	return {
		"complete": bool(publication.get("complete", false)),
		"targetable_collider_count": int(publication.get(
			"targetable_collider_count", -1
		)),
		"generated_ready": bool(publication.get("generated_ready", false)),
		"revision_name": String(revision.name) if revision != null else "",
		"revision_kind": String(revision.get_meta(
			"forge_v2_native_revision_kind", StringName()
		)) if revision != null else "",
		"collider_class": collider.get_class() if collider != null else "",
		"identity": _publication_identity() if collider != null else {},
	}


func _build_protected_publication_summary() -> Dictionary:
	var direct_count := 0
	var fallback_count := 0
	var unsupported_count := 0
	var all_rows_ok := not _protected_publication_rows.is_empty()
	for row: Dictionary in _protected_publication_rows:
		match String(row.get("accepted_path", "unsupported")):
			"direct_native_protected_composite":
				direct_count += 1
			"current_csg_fallback":
				fallback_count += 1
			_:
				unsupported_count += 1
		all_rows_ok = all_rows_ok and bool(row.get("ok", false))
	return {
		"preferred_kind": String(DIRECT_PROTECTED_COMPOSITE_KIND),
		"accepted_fallback_kind": String(
			CURRENT_CSG_PROTECTED_COMPOSITE_KIND
		),
		"direct_path_preferred": true,
		"direct_path_observed": direct_count > 0,
		"current_csg_fallback_observed": fallback_count > 0,
		"direct_publication_count": direct_count,
		"current_csg_fallback_count": fallback_count,
		"unsupported_publication_count": unsupported_count,
		"checked_publication_count": _protected_publication_rows.size(),
		"all_checked_publications_supported": all_rows_ok,
		"latest": (
			_protected_publication_rows[
				_protected_publication_rows.size() - 1
			].duplicate(true)
			if not _protected_publication_rows.is_empty()
			else {}
		),
	}


func _string_names(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	result.sort()
	return result


func _mark(gate: String, condition: bool, message: String) -> void:
	if not _gates.has(gate):
		_gates[gate] = true
	if condition:
		return
	_gates[gate] = false
	if not _failures.has(message):
		_failures.append(message)


func _finish_failure(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)
	_report.merge({
		"ok": false,
		"outcome": "fail",
		"failures": _failures,
		"gates": _gates,
		"protected_publications": _protected_publication_rows,
		"protected_publication_summary": (
			_build_protected_publication_summary()
		),
		"native": (
			_native_summary(_native_diagnostics())
			if _presenter != null
			else {}
		),
		"presentation": (
			_presentation_summary(_presentation())
			if _state != null
			else {}
		),
	}, true)
	_write_report()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	push_error("FORGE_V2_BOUNDED_ADD_HISTORY: %s" % message)
	quit(1)


func _write_report() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))
		file.close()
