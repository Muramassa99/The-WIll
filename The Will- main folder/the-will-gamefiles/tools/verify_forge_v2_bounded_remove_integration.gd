extends SceneTree

const CONTROLLER = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const WORKSPACE = preload("res://runtime/forge_v2/forge_v2_workspace_preview.gd")
const PREFS = preload("res://core/models/forge_v2_editor_settings_state.gd")
const REPORT := "C:/WORKSPACE/test_artifacts/forge_v2_bounded_remove_integration_20261018.json"
var controller: Node
var workspace: Node3D
var presenter: Node3D
var state: Resource
var checks: Array[Dictionary] = []
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	controller = CONTROLLER.new()
	var prefs = PREFS.new()
	prefs.save_file_path = "user://diagnostics/remove_integration/preferences.tres"
	controller.editor_settings = prefs
	root.add_child(controller)
	workspace = WORKSPACE.new()
	root.add_child(workspace)
	await process_frame
	workspace.call("bind_stage_controller", controller)
	await process_frame
	presenter = workspace.get("volume_preview_presenter") as Node3D
	state = controller.call("get_active_authoring_state") as Resource
	if not await _spline(Vector3.ZERO):
		await _finish()
		return
	var entries: Array = state.call("get_retained_spline_editable_entries")
	var first_id: StringName = entries[0].body_id
	var original_volume := _volume()
	if not await _detail_cut(0.008):
		await _finish()
		return
	var cut_volume := _volume()
	_check(cut_volume > 0.0 and cut_volume < original_volume * 0.95, "primitive Detailing Remove actually reduces solid volume")
	_check(bool(controller.call("undo_latest_action")), "Undo cut accepted")
	await _settle()
	_check(is_equal_approx(_volume(), original_volume), "Undo restores pre-cut geometry")
	_check(bool(controller.call("redo_latest_action")), "Redo cut accepted")
	await _settle()
	_check(is_equal_approx(_volume(), cut_volume), "Redo restores cut geometry")
	_check(bool(controller.call("begin_retained_spline_change", first_id)), "E can reopen Add preceding committed cut")
	controller.call("set_spline_line_point", 1, Vector3(0.025, 0.003, 0.0))
	_check(bool(controller.call("apply_retained_spline_change")), "E replacement starts")
	await _settle()
	_check(bool(controller.last_retained_spline_change_result.get("ok", false)), "E replacement replay publishes later cut")
	var cut_body: Resource = state.material_bodies.back()
	var cutter: Dictionary = presenter.call("_build_native_static_operand_packet", cut_body)
	var uncut_body: Resource = state.material_bodies[0]
	var uncut: Dictionary = presenter.call("_build_native_static_operand_packet", uncut_body)
	var expected: Object = ClassDB.instantiate(&"ForgeV2ManifoldBoolean")
	expected.call("reset_mesh", uncut.vertices, uncut.indices)
	var expected_cut: Dictionary = expected.call("subtract_mesh", cutter.vertices, cutter.indices)
	_check(bool(expected_cut.get("ok", false)) and is_equal_approx(_volume(), float(expected_cut.get("manifold_volume_m3", -1.0))), "E result equals edited Add minus later cutter")
	for i in range(5):
		if not await _spline(Vector3(0.08 + i * 0.06, 0, 0)):
			await _finish()
			return
	var descriptor: Dictionary = state.call("get_bounded_presentation_descriptor")
	_check(int(descriptor.get("checkpoint_operation_count", 0)) == 2, "Add and cut promoted into S0")
	_check((descriptor.active_tail_bodies as Array).size() == 5, "five-operation tail remains bounded")
	await _save_reload(false)
	# Erase everything through the same primitive Detailing path, then save and
	# reload the confirmed empty draft. A later Add must preserve this history.
	if not await _detail_cut(0.0, true):
		await _finish()
		return
	_check(_volume() == 0.0, "full erasure has zero native volume")
	_check(presenter.get("native_static_published_node") == null, "full erasure removes published mesh and collider")
	await _save_reload(true)
	state.set("active_brush_radius_meters", 0.0125)
	for i in range(5):
		if not await _spline(Vector3(-0.3 + i * 0.06, 0, 0)):
			await _finish()
			return
	_check(_volume() > 0.0, "Add after erasure works")
	_check(bool(state.call("materialize_bounded_history_checkpoint_for_persistence")), "empty S0 materializes")
	descriptor = state.call("get_bounded_presentation_descriptor")
	_check(bool(descriptor.checkpoint_packet.get("empty", false)), "full-erasure operation promotes to explicit empty checkpoint")
	await _save_reload(false)
	await _finish()

func _spline(offset: Vector3) -> bool:
	controller.call("select_tool_for_authoring", &"tool_spline_line")
	controller.call("set_active_primitive_id", &"primitive_blob")
	controller.call("set_active_operation_mode", &"operation_add_material")
	for p: Vector3 in [Vector3(-0.025, 0, 0), Vector3(0.025, 0, 0)]:
		controller.call("append_spline_line_point", p + offset, Vector3.UP)
	if not _check(bool(controller.call("generate_spline_line_csg_noodle")), "generate Add spline"):
		return false
	var committed: Dictionary = await controller.call("commit_all_pending_material_bodies_as_layers", 5000)
	_check(bool(committed.get("ok", false)), "commit Add spline")
	return await _settle()

func _detail_cut(y: float, erase_all: bool = false) -> bool:
	controller.call("select_tool_for_authoring", &"tool_detailing_brush")
	controller.call("set_active_primitive_id", &"primitive_blob")
	controller.call("set_active_operation_mode", &"operation_remove_material")
	if erase_all:
		state.call("set_brush_radius_meters", 0.2)
	var points := PackedVector3Array([Vector3(-0.01, y, 0), Vector3(0, y, 0), Vector3(0.01, y, 0)])
	if erase_all:
		points = PackedVector3Array([Vector3(-0.06, 0, 0), Vector3(0.16, 0, 0), Vector3(0.4, 0, 0)])
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	var contacts := PackedVector3Array([Vector3.DOWN, Vector3.DOWN, Vector3.DOWN])
	_check(bool(controller.call("replace_detailing_brush_path_solution", points, normals,
		&"target_material_surface", &"integration_surface", points, normals,
		PackedInt32Array([0, 1, 2]), [true, true], [&"none", &"none"], true, &"none", 0, contacts, contacts)), "install valid Detailing surface path")
	if not _check(bool(controller.call("generate_detailing_brush")), "generate primitive Detailing cut"):
		return false
	var committed: Dictionary = await controller.call("commit_all_pending_material_bodies_as_layers", 5000)
	if not _check(bool(committed.get("ok", false)), "S Apply commit accepts primitive Detailing Remove"):
		return false
	return await _settle()

func _save_reload(empty: bool) -> void:
	var volume_before := _volume()
	var prepared: Dictionary = await controller.call("prepare_pending_work_for_save", 5000)
	if not _check(bool(prepared.get("ok", false)), "Save preparation succeeds: " + str(prepared.get("reason", ""))):
		return
	_check((prepared.reason == &"ready_authoring_only") == empty, "empty result saves as authoring-only; real geometry exports")
	var wip: Resource = controller.call("build_crafted_item_wip_for_save", &"remove_integration", "Remove integration", prepared.runtime_mesh_packet)
	if not _check(wip != null, "build WIP with bounded removal"):
		return
	var path := "user://diagnostics/remove_integration/removed.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	_check(ResourceSaver.save(wip, path) == OK, "write isolated WIP")
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
	if not _check(loaded != null and bool(controller.call("load_saved_wip", loaded)), "load WIP through real controller"):
		return
	state = controller.call("get_active_authoring_state") as Resource
	await _settle()
	_check(is_equal_approx(_volume(), volume_before), "loaded publication matches saved volume")

func _volume() -> float:
	var backend: Object = presenter.get("native_static_manifold_backend")
	return float(backend.call("get_state_info").get("state_volume_m3", -1.0)) if backend != null else -1.0

func _settle() -> bool:
	for frame in range(300):
		await process_frame
		if frame > 4 and not bool(controller.call("is_retained_spline_change_pending")) \
			and not bool(state.call("has_pending_bounded_history_promotion")) \
			and bool(presenter.get("native_static_authoritative")) \
			and not bool(presenter.get("native_static_publication_pending")) \
			and int(presenter.get("native_static_consumed_transition_revision")) == int(state.call("get_bounded_history_transition").get("revision", -2)):
			await physics_frame
			return true
	print("REMOVE_SETTLE_DIAGNOSTICS ", presenter.get("native_static_sync_diagnostics"))
	return _check(false, "publication settle timeout")

func _check(ok: bool, label: String) -> bool:
	checks.append({"ok": ok, "check": label})
	if not ok:
		failures += 1
		push_error(label)
	return ok

func _finish() -> void:
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": failures == 0, "checks": checks, "failures": failures}, "\t"))
	print("BOUNDED_REMOVE_INTEGRATION ", checks.size() - failures, "/", checks.size())
	workspace.queue_free()
	controller.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
