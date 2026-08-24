extends SceneTree

const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const ForgeV2WorkspacePreviewScript = preload(
	"res://runtime/forge_v2/forge_v2_workspace_preview.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_pending_body_visibility_regression.json"
)

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	await _verify_generated_handle_stays_visible()
	await _verify_generated_noodle_stays_visible()
	await _verify_rejected_ready_freehand_stays_visible()
	await _verify_default_capsule_consecutive_commits_stay_bounded()
	var report := {
		"schema": "forge_v2_pending_body_visibility_regression",
		"schema_version": 1,
		"ok": _failures.is_empty(),
		"checks": _checks,
		"failures": _failures,
	}
	_write_report(report)
	if not _failures.is_empty():
		push_error("Forge V2 pending-body regression failed: %s" % "; ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _verify_generated_handle_stays_visible() -> void:
	var fixture: Dictionary = await _create_presented_fixture("GeneratedHandle")
	var controller := fixture.get("controller", null) as Node
	var presenter := fixture.get("presenter", null) as Node3D
	if controller == null or presenter == null:
		_record_check(
			"generated_handle_pending_preview",
			false,
			{"reason": "fixture_missing"}
		)
		await _dispose_fixture(fixture)
		return
	controller.call("reset_active_handle_profile_builder")
	for point: Vector3 in [
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.15, 0.0, 0.025),
		Vector3(0.32, 0.0, 0.0),
	]:
		controller.call("append_spline_line_point", point, Vector3.UP)
	controller.call("finish_spline_line")
	var generated := bool(controller.call(
		"generate_profile_extrusion_from_spline"
	))
	await _settle()
	var state := controller.call("get_active_authoring_state") as Resource
	var body := (
		state.call("get_selected_material_body") as Resource
		if state != null
		else null
	)
	var body_id := (
		StringName(body.get("body_id")) if body != null else StringName()
	)
	var first_evidence := _pending_preview_evidence(presenter, body_id)
	controller.call("adjust_brush_radius_steps", 1)
	await _settle()
	var stable_evidence := _pending_preview_evidence(presenter, body_id)
	var ok: bool = (
		generated
		and body != null
		and StringName(body.get("body_kind"))
		== ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
		and StringName(body.get("committed_layer_id")) == StringName()
		and int(state.call("get_pending_material_body_count")) == 1
		and bool(first_evidence.get("visible", false))
		and bool(stable_evidence.get("visible", false))
	)
	_record_check("generated_handle_pending_preview", ok, {
		"generated": generated,
		"body_id": String(body_id),
		"body_kind": String(body.get("body_kind")) if body != null else "",
		"committed": (
			StringName(body.get("committed_layer_id")) != StringName()
			if body != null
			else false
		),
		"pending_count": (
			int(state.call("get_pending_material_body_count"))
			if state != null
			else -1
		),
		"initial_preview": first_evidence,
		"preview_after_unrelated_state_refresh": stable_evidence,
	})
	await _dispose_fixture(fixture)


func _verify_generated_noodle_stays_visible() -> void:
	var fixture: Dictionary = await _create_presented_fixture("GeneratedNoodle")
	var controller := fixture.get("controller", null) as Node
	var presenter := fixture.get("presenter", null) as Node3D
	if controller == null or presenter == null:
		_record_check(
			"generated_noodle_pending_preview",
			false,
			{"reason": "fixture_missing"}
		)
		await _dispose_fixture(fixture)
		return
	controller.call("set_active_tool_id", &"tool_spline_line")
	controller.call("append_spline_line_point", Vector3.ZERO, Vector3.UP)
	controller.call(
		"append_spline_line_point",
		Vector3(0.18, 0.0, 0.035),
		Vector3.UP
	)
	controller.call("finish_spline_line")
	var generated := bool(controller.call("generate_spline_line_csg_noodle"))
	await _settle()
	var state := controller.call("get_active_authoring_state") as Resource
	var body := (
		state.call("get_selected_material_body") as Resource
		if state != null
		else null
	)
	var body_id := (
		StringName(body.get("body_id")) if body != null else StringName()
	)
	var first_evidence := _pending_preview_evidence(presenter, body_id)
	controller.call("adjust_brush_radius_steps", 1)
	await _settle()
	var stable_evidence := _pending_preview_evidence(presenter, body_id)
	var ok: bool = (
		generated
		and body != null
		and StringName(body.get("shape_kind"))
		== ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_CAPSULE_PATH
		and StringName(body.get("committed_layer_id")) == StringName()
		and int(state.call("get_pending_material_body_count")) == 1
		and bool(first_evidence.get("visible", false))
		and bool(stable_evidence.get("visible", false))
	)
	_record_check("generated_noodle_pending_preview", ok, {
		"generated": generated,
		"body_id": String(body_id),
		"shape_kind": String(body.get("shape_kind")) if body != null else "",
		"committed": (
			StringName(body.get("committed_layer_id")) != StringName()
			if body != null
			else false
		),
		"pending_count": (
			int(state.call("get_pending_material_body_count"))
			if state != null
			else -1
		),
		"initial_preview": first_evidence,
		"preview_after_unrelated_state_refresh": stable_evidence,
	})
	await _dispose_fixture(fixture)


func _verify_rejected_ready_freehand_stays_visible() -> void:
	var fixture: Dictionary = await _create_presented_fixture("RejectedReady")
	var controller := fixture.get("controller", null) as Node
	var presenter := fixture.get("presenter", null) as Node3D
	if controller == null or presenter == null:
		_record_check(
			"rejected_ready_freehand_pending_preview",
			false,
			{"reason": "fixture_missing"}
		)
		await _dispose_fixture(fixture)
		return
	var profile_selected := bool(controller.call(
		"select_active_saved_basic_profile",
		_build_fixed_basic_profile()
	))
	var first_id := StringName(controller.call(
		"begin_material_body_path",
		Vector3(-0.18, 0.0, 0.0),
		Vector3.UP,
		Vector3.DOWN
	))
	controller.call(
		"extend_material_body_path",
		Vector3(-0.03, 0.0, 0.0),
		true,
		Vector3.UP,
		Vector3.DOWN
	)
	controller.call("finish_material_body_path")
	await _settle()
	var state := controller.call("get_active_authoring_state") as Resource
	var first_body := _find_body(state, first_id)
	var first_committed := (
		first_body != null
		and StringName(first_body.get("committed_layer_id")) != StringName()
	)
	var native_before := (
		presenter.call("get_native_static_sync_diagnostics") as Dictionary
		if presenter.has_method("get_native_static_sync_diagnostics")
		else {}
	)

	controller.call("set_active_primitive_id", &"primitive_blob")
	controller.call(
		"set_placement_policy",
		ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY
	)
	var rejected_id := StringName(controller.call(
		"begin_material_body_path",
		Vector3(0.08, 0.0, 0.0),
		Vector3.UP,
		Vector3.ZERO
	))
	controller.call(
		"extend_material_body_path",
		Vector3(0.24, 0.0, 0.0),
		true,
		Vector3.UP,
		Vector3.ZERO
	)
	var ready_before_finish := bool(state.call(
		"is_material_body_commit_ready",
		rejected_id
	))
	controller.call("finish_material_body_path")
	await _settle()
	var finish_result := controller.call(
		"get_last_material_body_finish_result"
	) as Dictionary
	var rejected_body := _find_body(state, rejected_id)
	var first_evidence := _pending_preview_evidence(presenter, rejected_id)
	controller.call("adjust_brush_radius_steps", 1)
	await _settle()
	var stable_evidence := _pending_preview_evidence(presenter, rejected_id)
	var ok: bool = (
		profile_selected
		and first_committed
		and ready_before_finish
		and StringName(finish_result.get("status", StringName()))
		== &"commit_rejected"
		and bool(finish_result.get("pending", false))
		and not bool(finish_result.get("removed", true))
		and controller.call("get_active_placement_body_id") == StringName()
		and rejected_body != null
		and StringName(rejected_body.get("committed_layer_id")) == StringName()
		and bool(rejected_body.get("layer_active"))
		and int(state.call("get_pending_material_body_count")) == 1
		and bool(first_evidence.get("visible", false))
		and bool(stable_evidence.get("visible", false))
	)
	_record_check("rejected_ready_freehand_pending_preview", ok, {
		"profile_selected": profile_selected,
		"first_body_committed": first_committed,
		"native_lifecycle_before_rejection": String(native_before.get(
			"lifecycle",
			"unavailable"
		)),
		"native_authoritative_before_rejection": bool(native_before.get(
			"authoritative",
			false
		)),
		"ready_before_finish": ready_before_finish,
		"rejected_body_id": String(rejected_id),
		"finish_status": String(finish_result.get("status", StringName())),
		"reported_pending": bool(finish_result.get("pending", false)),
		"reported_removed": bool(finish_result.get("removed", false)),
		"body_survived": rejected_body != null,
		"pending_count": int(state.call("get_pending_material_body_count")),
		"initial_preview": first_evidence,
		"preview_after_unrelated_state_refresh": stable_evidence,
	})
	await _dispose_fixture(fixture)


func _verify_default_capsule_consecutive_commits_stay_bounded() -> void:
	var controller := ForgeV2StageControllerScript.new() as Node
	controller.name = "DefaultPrimitiveFallbackController"
	root.add_child(controller)
	await process_frame
	var body_ids: Array[StringName] = []
	var finish_statuses: Array[String] = []
	for stroke_index in range(2):
		var x_offset := float(stroke_index) * 0.35
		var body_id := StringName(controller.call(
			"begin_material_body_path",
			Vector3(x_offset, 0.0, 0.0),
			Vector3.UP,
			Vector3.ZERO
		))
		body_ids.append(body_id)
		controller.call(
			"extend_material_body_path",
			Vector3(x_offset + 0.16, 0.0, 0.0),
			true,
			Vector3.UP,
			Vector3.ZERO
		)
		controller.call("finish_material_body_path")
		var finish_result := controller.call(
			"get_last_material_body_finish_result"
		) as Dictionary
		finish_statuses.append(String(finish_result.get(
			"status",
			StringName()
		)))
	var state := controller.call("get_active_authoring_state") as Resource
	var both_committed := true
	for body_id: StringName in body_ids:
		var body := _find_body(state, body_id)
		both_committed = (
			both_committed
			and body != null
			and StringName(body.get("committed_layer_id")) != StringName()
		)
	var layer_count := int(state.call("get_committed_layer_count"))
	var pending_count := int(state.call("get_pending_material_body_count"))
	var suspended_reason := StringName(state.get(
		"bounded_history_suspended_reason"
	))
	var ok: bool = (
		both_committed
		and finish_statuses == ["committed", "committed"]
		and layer_count == 2
		and pending_count == 0
		and suspended_reason == &"none"
	)
	_record_check("default_capsule_consecutive_commits_stay_bounded", ok, {
		"body_ids": [String(body_ids[0]), String(body_ids[1])],
		"finish_statuses": finish_statuses,
		"both_committed": both_committed,
		"committed_layer_count": layer_count,
		"pending_count": pending_count,
		"bounded_history_suspended_reason": String(suspended_reason),
	})
	controller.queue_free()
	await process_frame


func _create_presented_fixture(label: String) -> Dictionary:
	var controller := ForgeV2StageControllerScript.new() as Node
	controller.name = "%sController" % label
	root.add_child(controller)
	var workspace := ForgeV2WorkspacePreviewScript.new() as Node3D
	workspace.name = "%sWorkspace" % label
	root.add_child(workspace)
	await process_frame
	workspace.call("bind_stage_controller", controller)
	await _settle()
	return {
		"controller": controller,
		"workspace": workspace,
		"presenter": workspace.get("volume_preview_presenter") as Node3D,
	}


func _dispose_fixture(fixture: Dictionary) -> void:
	var workspace := fixture.get("workspace", null) as Node3D
	var controller := fixture.get("controller", null) as Node
	if workspace != null and is_instance_valid(workspace):
		workspace.call("clear_stage_controller")
		workspace.queue_free()
	if controller != null and is_instance_valid(controller):
		controller.queue_free()
	await process_frame


func _settle() -> void:
	await process_frame
	await process_frame


func _pending_preview_evidence(
	presenter: Node3D,
	body_id: StringName
) -> Dictionary:
	var evidence := {
		"found": false,
		"root_visible": false,
		"node_visible": false,
		"visible": false,
		"mesh_surface_count": 0,
		"non_authoritative": false,
	}
	if presenter == null or body_id == StringName():
		return evidence
	var preview_root := presenter.get("csg_active_body_root") as Node3D
	if preview_root == null or not is_instance_valid(preview_root):
		return evidence
	evidence["root_visible"] = preview_root.visible
	for child: Node in preview_root.get_children():
		if StringName(child.get_meta(
			"forge_v2_pending_body_id",
			StringName()
		)) != body_id:
			continue
		evidence["found"] = true
		evidence["node_visible"] = bool(child.get("visible"))
		evidence["non_authoritative"] = bool(child.get_meta(
			"forge_v2_non_authoritative_pending_preview",
			false
		))
		if child is MeshInstance3D:
			var mesh := (child as MeshInstance3D).mesh
			evidence["mesh_surface_count"] = (
				mesh.get_surface_count() if mesh != null else 0
			)
		evidence["visible"] = (
			bool(evidence["root_visible"])
			and bool(evidence["node_visible"])
			and int(evidence["mesh_surface_count"]) > 0
			and bool(evidence["non_authoritative"])
		)
		break
	return evidence


func _build_fixed_basic_profile() -> Dictionary:
	var square := PackedVector2Array([
		Vector2(-0.02, -0.02),
		Vector2(0.02, -0.02),
		Vector2(0.02, 0.02),
		Vector2(-0.02, 0.02),
	])
	return {
		"profile_id": &"pending_visibility_fixed_basic",
		"id": &"pending_visibility_fixed_basic",
		"label": "Pending Visibility Fixed Basic",
		"family": ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC,
		"base_polygon_2d_meters": square,
		"polygon_2d_meters": square,
		"base_anchor_2d_meters": Vector2(0.0, -0.02),
		"anchor_x_meters": 0.0,
		"anchor_y_meters": -0.02,
		"rotation_degrees": 0.0,
	}


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


func _record_check(name: String, ok: bool, evidence: Dictionary) -> void:
	var row := evidence.duplicate(true)
	row["ok"] = ok
	_checks[name] = row
	if not ok:
		_failures.append(name)


func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % RESULT_PATH)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
