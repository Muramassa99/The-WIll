extends SceneTree

const CONTROLLER = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const WORKSPACE = preload("res://runtime/forge_v2/forge_v2_workspace_preview.gd")
const PREFS = preload("res://core/models/forge_v2_editor_settings_state.gd")
const REPORT := "C:/WORKSPACE/test_artifacts/forge_retained_edit_integration_20261018.json"
var controller: Node
var workspace: Node3D
var presenter: Node3D
var state: Resource
var checks: Array[Dictionary] = []
var failures := 0
var callback_to_fail: Callable
var publication_result: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	controller = CONTROLLER.new()
	var prefs = PREFS.new()
	prefs.save_file_path = "user://diagnostics/retained_edit/preferences.tres"
	controller.editor_settings = prefs
	root.add_child(controller)
	workspace = WORKSPACE.new()
	root.add_child(workspace)
	await process_frame
	workspace.call("bind_stage_controller", controller)
	await process_frame
	presenter = workspace.get("volume_preview_presenter") as Node3D
	state = controller.call("get_active_authoring_state") as Resource
	controller.call("set_active_tool_id", &"tool_spline_line")
	controller.call("set_active_primitive_id", &"primitive_blob")
	for index in range(7):
		if not await _append_spline(index):
			await _finish()
			return
	var entries := state.call("get_retained_spline_editable_entries") as Array
	_check(entries.size() == 5, "seven spline operations retain five editable slots")
	_check(int(state.call("get_bounded_presentation_descriptor").get("checkpoint_operation_count", 0)) == 2,
		"older two operations became checkpoint")
	if entries.size() != 5:
		await _finish()
		return
	for index in [0, 2, 4]:
		await _edit_roundtrip(StringName(entries[index].body_id), index)
		if failures > 0:
			await _finish()
			return
	await _cancel_and_failure(StringName(entries[2].body_id))
	await _native_failure_guards(StringName(entries[2].body_id))
	await _mixed_batch(StringName(entries[4].body_id))
	await _promotion_retires_edits(StringName(entries[4].body_id))
	await _save_reload()
	await _finish()

func _append_spline(index: int) -> bool:
	controller.call("set_active_tool_id", &"tool_spline_line")
	var x := -0.28 + index * 0.07
	for p in [Vector3(x, 0, 0), Vector3(x + 0.04, 0.008, 0), Vector3(x + 0.08, 0, 0)]:
		controller.call("append_spline_line_point", p, Vector3.FORWARD)
	if not _check(bool(controller.call("generate_spline_line_csg_noodle")), "generate spline %d" % index):
		return false
	var layer := controller.call("commit_pending_material_bodies_as_layer") as Resource
	if not _check(layer != null, "commit spline %d" % index):
		return false
	await _settle()
	return _check(_native_ready(), "native publication ready after spline %d" % index)

func _edit_roundtrip(body_id: StringName, index: int) -> void:
	var body := _body(body_id)
	var before := (body.get("path_points") as PackedVector3Array).duplicate()
	var identity := [body.body_id, body.source_record_id, body.committed_layer_id, body.created_timestamp]
	var layers := _layer_ids()
	var lifetime := int(state.get("bounded_history_lifetime_operation_count"))
	var action_count := int(controller.call("get_action_history_summary").undo_count)
	_check(bool(controller.call("begin_retained_spline_change", body_id)), "begin retained %d" % index)
	_check(controller.call("get_action_history_summary").scope == &"retained_spline_edit", "edit uses local Undo")
	_check(bool(controller.call("set_spline_line_point", 1, before[1] + Vector3(0, 0.014, 0))), "move retained point")
	_check(_body(body_id).path_points == before, "point edits leave committed source unchanged")
	_check(bool(controller.call("undo_latest_action")), "local point Undo")
	_check(state.spline_line_points == before, "local Undo restores original point")
	_check(bool(controller.call("redo_latest_action")), "local point Redo")
	_check(bool(controller.call("set_spline_line_point_roll_degrees", 1, 45.0)), "twist retained point")
	_check(bool(controller.call("apply_retained_spline_change")), "Apply candidate accepted")
	_check(not bool(controller.call("set_spline_line_point", 1, Vector3.ZERO)), "pending Apply blocks another point mutation")
	await _settle()
	_check(not bool(controller.call("is_retained_spline_change_active")), "published Apply exits edit")
	_check(bool(controller.last_retained_spline_change_result.get("ok", false)), "candidate publishes successfully")
	body = _body(body_id)
	_check(body != null and [body.body_id, body.source_record_id, body.committed_layer_id, body.created_timestamp] == identity,
		"Apply preserves body/source/layer identity and age")
	_check(_layer_ids() == layers, "Apply preserves chronological layer order")
	_check(int(state.get("bounded_history_lifetime_operation_count")) == lifetime, "Apply consumes no new retention slot")
	_check(int(controller.call("get_action_history_summary").undo_count) == action_count + 1, "Apply is exactly one global action")
	var after := (body.path_points as PackedVector3Array).duplicate()
	_check(after != before and is_equal_approx(body.path_roll_degrees[1], 45.0), "source point and twist changed")
	_check(bool(controller.call("undo_latest_action")), "global replacement Undo requested")
	await _settle()
	_check(_body(body_id).path_points == before, "replacement Undo restores source")
	_check(bool(controller.call("redo_latest_action")), "global replacement Redo requested")
	await _settle()
	_check(_body(body_id).path_points == after, "replacement Redo restores edited source")
	_check(_native_ready(), "replacement native publication remains usable")

func _cancel_and_failure(body_id: StringName) -> void:
	var before := (_body(body_id).path_points as PackedVector3Array).duplicate()
	var context := state.call("capture_editor_transient_snapshot") as Dictionary
	_check(bool(controller.call("begin_retained_spline_change", body_id)), "begin Cancel case")
	controller.call("set_spline_line_point", 1, before[1] + Vector3(0, 0.01, 0))
	_check(bool(controller.call("cancel_retained_spline_change")), "Cancel edit")
	_check(state.call("capture_editor_transient_snapshot") == context, "Cancel restores pre-E tool/profile/point context")
	_check(_body(body_id).path_points == before, "Cancel keeps original committed geometry")
	var provider: Callable = controller.get("_retained_spline_change_provider")
	controller.call("set_retained_spline_change_provider", _hold_publication)
	controller.call("begin_retained_spline_change", body_id)
	controller.call("set_spline_line_point", 1, before[1] + Vector3(0, 0.01, 0))
	var undo_count := int(controller.get("_action_history").get_undo_count())
	_check(bool(controller.call("apply_retained_spline_change")), "failure fixture starts pending candidate")
	_check(_body(body_id).path_points == before, "pending candidate keeps original source")
	callback_to_fail.call(false, {"reason": &"injected_candidate_failure"})
	_check(_body(body_id).path_points == before and bool(controller.call("is_retained_spline_change_active")),
		"failed candidate keeps original and editable draft")
	_check(int(controller.get("_action_history").get_undo_count()) == undo_count, "failure does not advance journal")
	controller.call("set_retained_spline_change_provider", provider)
	controller.call("cancel_retained_spline_change")
	callback_to_fail.call(true, {})
	_check(_body(body_id).path_points == before, "late callback cannot publish a cancelled request")

func _hold_publication(_candidate: Dictionary, completed: Callable) -> bool:
	callback_to_fail = completed
	return true

func _native_failure_guards(body_id: StringName) -> void:
	var old_publication: Node3D = presenter.get("native_static_published_node")
	var old_backend: Object = presenter.get("native_static_manifold_backend")
	var old_points := (_body(body_id).path_points as PackedVector3Array).duplicate()
	controller.call("begin_retained_spline_change", body_id)
	controller.call("set_spline_line_point", 1, old_points[1] + Vector3(0, 0.005, 0))
	var candidate := state.call("build_retained_spline_change_candidate") as Dictionary
	for body: Resource in candidate.candidate_tail_bodies:
		if body.body_id == body_id:
			body.path_points = PackedVector3Array()
	publication_result = {}
	var provider: Callable = controller.get("_retained_spline_change_provider")
	_check(bool(provider.call(candidate, _capture_publication_result)), "invalid operand request reaches native candidate preparation")
	await _wait_publication_result()
	_check(not bool(publication_result.get("ok", true)), "native candidate rejects invalid operand")
	_check(presenter.get("native_static_published_node") == old_publication \
		and presenter.get("native_static_manifold_backend") == old_backend \
		and _body(body_id).path_points == old_points, "invalid operand keeps original backend, publication and source")
	candidate = state.call("build_retained_spline_change_candidate") as Dictionary
	publication_result = {}
	_check(bool(provider.call(candidate, _capture_publication_result)), "stale candidate accepted for preparation")
	controller.call("cancel_retained_spline_change")
	await _wait_publication_result()
	_check(not bool(publication_result.get("ok", true)), "cancelled candidate fails its token check")
	_check(presenter.get("native_static_published_node") == old_publication \
		and presenter.get("native_static_manifold_backend") == old_backend, "stale candidate cannot replace live publication")

func _capture_publication_result(ok: bool, result: Dictionary) -> void:
	publication_result = result.duplicate()
	publication_result["ok"] = ok

func _wait_publication_result() -> void:
	for frame in range(200):
		await process_frame
		if not publication_result.is_empty():
			return
	_check(false, "native failure completion timeout")

func _mixed_batch(body_id: StringName) -> void:
	var before := (_body(body_id).path_points as PackedVector3Array).duplicate()
	controller.call("begin_retained_spline_change", body_id)
	controller.call("set_spline_line_point", 1, before[1] + Vector3(0, 0.012, 0))
	controller.call("apply_retained_spline_change")
	await _settle()
	var after := (_body(body_id).path_points as PackedVector3Array).duplicate()
	controller.call("append_spline_line_point", Vector3(0.2, 0.2, 0), Vector3.FORWARD)
	_check(bool(controller.call("begin_action_history_undo_batch")), "begin held mixed Undo")
	_check(bool(controller.call("undo_latest_action")), "held Undo removes later transient")
	_check(bool(controller.call("undo_latest_action")), "held Undo requests replacement")
	_check(bool(controller.call("end_action_history_undo_batch")), "key release defers batch seal while candidate pending")
	await _settle()
	_check(_body(body_id).path_points == before, "held replacement Undo restored source")
	_check(bool(controller.call("redo_latest_action")), "mixed Redo batch accepted")
	await _settle()
	_check(_body(body_id).path_points == after and state.spline_line_points.size() == 1,
		"mixed Redo atomically restores replacement plus later transient")
	controller.call("cancel_spline_line")

func _promotion_retires_edits(body_id: StringName) -> void:
	controller.call("begin_retained_spline_change", body_id)
	var p: Vector3 = state.spline_line_points[1]
	controller.call("set_spline_line_point", 1, p + Vector3(0, 0.005, 0))
	controller.call("apply_retained_spline_change")
	await _settle()
	await _append_spline(7)
	_check(_body(body_id) == null, "oldest edited source becomes fused on next append")
	var found := false
	for record: Dictionary in controller.get("_action_history").get_undo_records():
		if record.payload.get("body_id", &"") == body_id:
			found = true
	_check(not found, "promotion retires later replacement actions of fused owner")
	_check(not bool(controller.call("begin_retained_spline_change", body_id)), "fused owner cannot reopen")

func _save_reload() -> void:
	_check(bool(state.call("materialize_bounded_history_checkpoint_for_persistence")), "checkpoint materializes for save")
	var path := "user://diagnostics/retained_edit/source_state.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	_check(ResourceSaver.save(state, path) == OK, "edited state saves")
	var reloaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
	_check(reloaded != null, "edited state reloads")
	if reloaded != null:
		reloaded.call("normalize")
		_check((reloaded.call("get_retained_spline_editable_entries") as Array).size() == 5, "reloaded retained sources remain editable")

func _body(id: StringName) -> Resource:
	for body: Resource in state.material_bodies:
		if body.body_id == id:
			return body
	return null

func _layer_ids() -> Array:
	var result: Array = []
	for layer: Resource in state.forge_layers:
		result.append(layer.layer_id)
	return result

func _native_ready() -> bool:
	return bool(presenter.get("native_static_authoritative")) and not bool(presenter.get("native_static_publication_pending"))

func _settle() -> void:
	for frame in range(300):
		await process_frame
		if frame > 3 and not bool(controller.call("is_retained_spline_change_pending")) \
			and not bool(state.call("has_pending_bounded_history_promotion")) and _native_ready():
			await physics_frame
			await process_frame
			return
	_check(false, "settle timeout")

func _check(ok: bool, label: String) -> bool:
	checks.append({"ok": ok, "check": label})
	if not ok:
		failures += 1
		push_error(label)
	return ok

func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(REPORT.get_base_dir())
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": failures == 0, "checks": checks, "failures": failures}, "\t"))
	print("RETAINED_EDIT_INTEGRATION ", checks.size() - failures, "/", checks.size())
	workspace.queue_free()
	controller.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
