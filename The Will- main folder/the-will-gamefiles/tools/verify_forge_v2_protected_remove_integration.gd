extends "res://tools/verify_forge_v2_bounded_remove_integration.gd"

const PROFILE_LIBRARY = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const PROTECTED_REPORT := "C:/WORKSPACE/test_artifacts/forge_v2_protected_remove_integration_20261018.json"
var original_handle_digest := ""


func _run() -> void:
	controller = CONTROLLER.new()
	var prefs = PREFS.new()
	prefs.save_file_path = "user://diagnostics/protected_remove/preferences.tres"
	controller.editor_settings = prefs
	root.add_child(controller)
	workspace = WORKSPACE.new()
	root.add_child(workspace)
	await process_frame
	workspace.call("bind_stage_controller", controller)
	await process_frame
	presenter = workspace.get("volume_preview_presenter") as Node3D
	state = controller.call("get_active_authoring_state") as Resource
	controller.call("select_tool_for_authoring", &"tool_handles")
	controller.call("reset_active_handle_profile_builder")
	controller.call("set_active_profile_width_meters", 0.02)
	controller.call("set_active_profile_height_meters", 0.02)
	for point: Vector3 in [Vector3(-0.2, -0.03, 0), Vector3(0, -0.03, 0), Vector3(0.2, -0.03, 0)]:
		controller.call("append_spline_line_point", point, Vector3.UP)
	if not _check(bool(controller.call("generate_profile_extrusion_from_spline")), "generate real semantic Handle"):
		await _finish()
		return
	var commit: Dictionary = await controller.call("commit_all_pending_material_bodies_as_layers", 5000)
	if not _check(bool(commit.get("ok", false)), "commit protected Handle") or not await _settle():
		await _finish()
		return
	# Warm the authoritative Handle packet; it is produced by the same deferred
	# CSG path used by ordinary rendered Forge rather than synthetic test mesh.
	var initial_export: Dictionary = presenter.call("_provide_runtime_contract_mesh_export")
	for _frame in range(120):
		if bool(initial_export.get("ok", false)):
			break
		await process_frame
		initial_export = presenter.call("_provide_runtime_contract_mesh_export")
	_check(bool(initial_export.get("ok", false)), "initial Handle runtime export ready")
	original_handle_digest = _handle_digest()
	_check(not original_handle_digest.is_empty(), "capture real protected geometry baseline")
	if not await _spline(Vector3.ZERO):
		await _finish()
		return
	var original_volume := _volume()
	var before_cut: Dictionary = presenter.call("_provide_runtime_contract_mesh_export")
	_check(bool(before_cut.get("ok", false)), "Handle plus ordinary output exports before cut")
	if not await _saved_profile_cut():
		await _finish()
		return
	var cut_volume := _volume()
	print("PROTECTED_REMOVE_VOLUMES ", original_volume, " -> ", cut_volume)
	_check(cut_volume > 0.0 and cut_volume < original_volume * 0.95, "saved-profile Detailing Remove cuts actual ordinary solid")
	_assert_protected_publication("after saved-profile cut")
	_check(bool(controller.call("undo_latest_action")), "Undo saved-profile cut")
	await _settle()
	_check(is_equal_approx(_volume(), original_volume), "Undo restores ordinary pre-cut volume")
	_assert_protected_publication("after Undo")
	_check(bool(controller.call("redo_latest_action")), "Redo saved-profile cut")
	await _settle()
	_check(is_equal_approx(_volume(), cut_volume), "Redo restores saved-profile cut")
	_assert_protected_publication("after Redo")
	await _save_reload(false)
	_assert_protected_publication("after cut save/reload")
	var loaded_remove: Resource
	for body: Resource in state.material_bodies:
		if StringName(body.get("profile_id")) == &"protected_remove_saved_profile":
			loaded_remove = body
	_check(loaded_remove != null, "saved-profile cutter identity persists")
	_check(loaded_remove != null and StringName(loaded_remove.get("operation_mode")) == &"operation_remove_material", "saved-profile cutter subtraction persists")
	# This cutter covers the ordinary body AND the complete protected Handle.
	# Ordinary geometry must disappear; the Handle must stay rendered and usable.
	if not await _detail_cut(0.0, true):
		await _finish()
		return
	_check(_volume() == 0.0, "covering cutter erases all ordinary material")
	_assert_protected_publication("after covering full-erasure cut")
	var only_handle: Dictionary = presenter.call("_provide_runtime_contract_mesh_export")
	_check(bool(only_handle.get("ok", false)) and bool(only_handle.get("handle_only", false)), "full erase exports exact protected Handle-only runtime geometry")
	_check(bool(controller.call("undo_latest_action")), "Undo full erasure")
	await _settle()
	_check(is_equal_approx(_volume(), cut_volume), "Undo full erasure restores cut ordinary solid")
	_assert_protected_publication("after full-erasure Undo")
	_check(bool(controller.call("redo_latest_action")), "Redo full erasure")
	await _settle()
	_assert_protected_publication("after full-erasure Redo")
	await _save_reload(false)
	_assert_protected_publication("after Handle-only save/reload")
	_check(_volume() == 0.0, "reloaded Handle-only draft has no ghost ordinary solid")
	await _finish()


func _saved_profile_cut() -> bool:
	controller.call("select_tool_for_authoring", &"tool_detailing_brush")
	var polygon := PackedVector2Array([Vector2(-0.018, -0.008), Vector2(0.018, -0.008), Vector2(0.018, 0.008), Vector2(-0.018, 0.008)])
	var profile: Dictionary = PROFILE_LIBRARY.compile_basic_profile_runtime_data({
		"id": &"protected_remove_saved_profile", "profile_id": &"protected_remove_saved_profile",
		"family": PROFILE_LIBRARY.PROFILE_FAMILY_BASIC, "label": "Saved removal profile",
		"base_polygon_2d_meters": polygon, "polygon_2d_meters": polygon,
		"base_anchor_2d_meters": Vector2.ZERO, "anchor_x_meters": 0.0,
		"anchor_y_meters": 0.0, "rotation_degrees": 0.0,
	})
	_check(bool(controller.call("select_active_saved_basic_profile", profile)), "select real compiled saved cutter profile")
	controller.call("set_active_operation_mode", &"operation_remove_material")
	var points := PackedVector3Array([Vector3(-0.015, 0.006, 0), Vector3.ZERO + Vector3(0, 0.006, 0), Vector3(0.015, 0.006, 0)])
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	var contacts := PackedVector3Array([Vector3.DOWN, Vector3.DOWN, Vector3.DOWN])
	_check(bool(controller.call("replace_detailing_brush_path_solution", points, normals,
		&"target_material_surface", &"saved_profile_remove_surface", points, normals,
		PackedInt32Array([0, 1, 2]), [true, true], [&"none", &"none"], true, &"none", 0, contacts, contacts)), "install coherent saved-profile surface solution")
	if not _check(bool(controller.call("generate_detailing_brush")), "generate saved-profile Detailing Remove"):
		return false
	var cutter: Resource = state.material_bodies.back()
	_check(StringName(cutter.get("shape_kind")) == &"shape_kind_profile_path" and bool(cutter.call("uses_explicit_surface_contact_authority")), "Detail cutter uses explicit profile extrusion")
	var committed: Dictionary = await controller.call("commit_all_pending_material_bodies_as_layers", 5000)
	if not _check(bool(committed.get("ok", false)), "commit saved-profile Detailing Remove"):
		return false
	return await _settle()


func _handle_digest() -> String:
	var descriptor: Dictionary = state.call("get_bounded_presentation_descriptor")
	var protected: Array = descriptor.get("protected_bodies", [])
	if protected.size() != 1:
		return ""
	var packet: Dictionary = presenter.call("_resolve_authoritative_protected_handle_packet", protected[0])
	if not bool(packet.get("ok", false)):
		return ""
	return var_to_bytes([packet.get("vertices"), packet.get("indices")]).hex_encode().sha256_text()


func _assert_protected_publication(label: String) -> void:
	_check(_handle_digest() == original_handle_digest, label + ": protected geometry unchanged")
	var publication: Node3D = presenter.get("native_static_published_node")
	_check(publication != null and is_instance_valid(publication) and publication.visible, label + ": published geometry visible")
	if publication != null:
		_check(bool(presenter.call("_native_static_revision_node_is_complete", publication)), label + ": published render mesh and collider complete")
	var exported: Dictionary = presenter.call("_provide_runtime_contract_mesh_export")
	_check(bool(exported.get("ok", false)), label + ": final runtime export succeeds")
	_check(not (exported.get("vertices", PackedVector3Array()) as PackedVector3Array).is_empty(), label + ": export retains real geometry")


func _finish() -> void:
	var file := FileAccess.open(PROTECTED_REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": failures == 0, "checks": checks, "failures": failures}, "\t"))
	print("PROTECTED_REMOVE_INTEGRATION ", checks.size() - failures, "/", checks.size())
	workspace.queue_free()
	controller.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
