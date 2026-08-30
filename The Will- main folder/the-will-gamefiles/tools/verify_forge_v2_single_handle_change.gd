extends SceneTree

const ForgeV2AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_single_handle_change_2026-08-28.txt"
)
const EPSILON := 0.00001
const ORIGINAL_HANDLE_POINTS: Array[Vector3] = [
	Vector3(-0.20, 0.0, 0.0),
	Vector3.ZERO,
	Vector3(0.20, 0.0, 0.0),
]
const EDITED_MIDDLE_POINT := Vector3(0.0, 0.035, 0.02)

var result_lines: PackedStringArray = []


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Forge V2 Single Handle Change Verify")
	state.call("set_active_tool_id", ForgeV2AuthoringStateScript.TOOL_HANDLES)
	state.call(
		"set_active_profile_id",
		ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER
	)
	if not _author_handle(state, ORIGINAL_HANDLE_POINTS):
		_fail("could not author the initial pending Handle")
		return
	var original_body: Resource = state.call("get_selected_material_body") as Resource
	if not _expect_handle_body(original_body, "initial pending Handle"):
		return
	if not _expect_snapshot(
		original_body.get("handle_profile_authoring_snapshot") as Dictionary,
		ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_RECTANGLE,
		"initial pending Handle"
	):
		return
	if not _expect(
		bool(state.call("has_handle_material_body")),
		"initial pending Handle was not exposed through Handle authority"
	):
		return
	if not _expect_second_handle_rejected(state, "initial pending Handle"):
		return

	var original_body_instance_id := original_body.get_instance_id()
	var original_body_id := StringName(original_body.get("body_id"))
	var begin_pending: Variant = state.call("begin_handle_change")
	if not _expect(
		_result_ok(begin_pending) and bool(state.call("is_handle_change_active")),
		"pending Handle did not enter Change Handle mode"
	):
		return
	if not _expect(
		(state.get("material_bodies") as Array[Resource]).is_empty()
		and (state.get("protected_forge_layers") as Array[Resource]).is_empty(),
		"pending Handle remained in a live visual list while Change Handle was open"
	):
		return
	if not _expect(
		_points_match(
			state.get("spline_line_points") as PackedVector3Array,
			ORIGINAL_HANDLE_POINTS
		),
		"Change Handle did not restore the exact authored three-point path"
	):
		return
	if not _expect(
		bool(state.call("cancel_handle_change")),
		"pending Handle change did not cancel"
	):
		return
	var pending_restored: Resource = state.call("get_selected_material_body") as Resource
	if not _expect(
		pending_restored != null
		and pending_restored.get_instance_id() == original_body_instance_id
		and StringName(pending_restored.get("body_id")) == original_body_id,
		"cancel did not restore the exact pending Handle object"
	):
		return

	var original_layer: Resource = state.call(
		"commit_pending_material_bodies_as_layer"
	) as Resource
	if not _expect(
		original_layer != null
		and int(state.call("get_pending_material_body_count")) == 0
		and int(state.call("get_protected_layer_count")) == 1,
		"initial Handle did not commit as one protected layer"
	):
		return
	var original_layer_instance_id := original_layer.get_instance_id()
	var original_layer_id := StringName(original_layer.get("layer_id"))

	var begin_committed: Variant = state.call("begin_handle_change")
	if not _expect(
		_result_ok(begin_committed) and bool(state.call("is_handle_change_active")),
		"committed Handle did not enter Change Handle mode"
	):
		return
	if not _expect(
		(state.get("material_bodies") as Array[Resource]).is_empty()
		and (state.get("protected_forge_layers") as Array[Resource]).is_empty(),
		"committed Handle CSG remained live while its three-dot path was exposed"
	):
		return
	if not _expect(
		bool(state.call("has_handle_material_body")),
		"detached committed Handle stopped being the logical single Handle"
	):
		return
	if not _expect(
		bool(state.call("cancel_handle_change")),
		"committed Handle change did not cancel"
	):
		return
	var restored_bodies: Array[Resource] = state.get("material_bodies") as Array[Resource]
	var restored_layers: Array[Resource] = state.get(
		"protected_forge_layers"
	) as Array[Resource]
	if not _expect(
		restored_bodies.size() == 1
		and restored_layers.size() == 1
		and restored_bodies[0].get_instance_id() == original_body_instance_id
		and restored_layers[0].get_instance_id() == original_layer_instance_id
		and StringName(restored_bodies[0].get("body_id")) == original_body_id
		and StringName(restored_layers[0].get("layer_id")) == original_layer_id,
		"cancel did not restore the exact committed Handle body and protected layer"
	):
		return

	var begin_replacement: Variant = state.call("begin_handle_change")
	if not _expect(
		_result_ok(begin_replacement),
		"committed Handle could not begin its replacement transaction"
	):
		return
	if not _expect(
		bool(state.call("set_spline_line_point", 1, EDITED_MIDDLE_POINT)),
		"Change Handle path point could not be repositioned"
	):
		return
	state.call(
		"set_active_handle_face_count",
		ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_OCTAGON
	)
	var apply_result: Variant = state.call("apply_handle_change")
	if not _expect(
		_result_ok(apply_result)
		and not bool(state.call("is_handle_change_active")),
		"Handle replacement did not apply"
	):
		return
	if not _expect(
		int(state.call("get_material_body_count")) == 1
		and int(state.call("get_pending_material_body_count")) == 1
		and int(state.call("get_protected_layer_count")) == 0
		and bool(state.call("has_handle_material_body")),
		"Handle replacement did not leave exactly one pending Handle"
	):
		return
	var replacement: Resource = state.call("get_selected_material_body") as Resource
	if not _expect_handle_body(replacement, "pending replacement Handle"):
		return
	if not _expect(
		replacement.get_instance_id() != original_body_instance_id
		and StringName(replacement.get("committed_layer_id")) == StringName(),
		"applied Handle change reused the detached committed object or layer identity"
	):
		return
	var replacement_points: PackedVector3Array = replacement.get("path_points")
	if not _expect(
		replacement_points.size() == 3
		and replacement_points[1].distance_to(EDITED_MIDDLE_POINT) <= EPSILON,
		"pending replacement did not retain the edited three-point path"
	):
		return
	if not _expect_snapshot(
		replacement.get("handle_profile_authoring_snapshot") as Dictionary,
		ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_OCTAGON,
		"pending replacement Handle"
	):
		return
	if not _expect_second_handle_rejected(state, "pending replacement Handle"):
		return

	var persisted_state: Resource = state.duplicate(true)
	var persisted_bodies: Array[Resource] = persisted_state.get(
		"material_bodies"
	) as Array[Resource]
	if not _expect(
		persisted_bodies.size() == 1,
		"deep-duplicated authoring state did not retain exactly one Handle"
	):
		return
	if not _expect_snapshot(
		persisted_bodies[0].get("handle_profile_authoring_snapshot") as Dictionary,
		ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_OCTAGON,
		"deep-duplicated replacement Handle"
	):
		return
	if not _verify_legacy_handle_keeps_exact_compiled_polygon():
		return
	if not await _verify_save_preparation_auto_applies_handle_change(state):
		return

	result_lines.append("ok=true")
	result_lines.append("second_handle_prevented=true")
	result_lines.append("pending_cancel_restores_exact_body=true")
	result_lines.append("committed_cancel_restores_exact_body_and_layer=true")
	result_lines.append("change_hides_old_csg_from_live_lists=true")
	result_lines.append("apply_yields_one_pending_replacement=true")
	result_lines.append("profile_authoring_snapshot_persists=true")
	result_lines.append("legacy_handle_exact_compiled_polygon_preserved=true")
	result_lines.append("save_auto_applies_and_commits_open_handle_change=true")
	_write_results()
	print("FORGE_V2_SINGLE_HANDLE_CHANGE_VERIFY: PASS")
	quit(0)


func _verify_legacy_handle_keeps_exact_compiled_polygon() -> bool:
	var legacy_state: Resource = ForgeV2AuthoringStateScript.new()
	legacy_state.call("reset_new_draft", "Legacy Handle Change Verify")
	legacy_state.call(
		"set_active_tool_id",
		ForgeV2AuthoringStateScript.TOOL_HANDLES
	)
	legacy_state.call(
		"set_active_profile_id",
		ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER
	)
	if not _expect(
		_author_handle(legacy_state, ORIGINAL_HANDLE_POINTS),
		"could not author the simulated legacy Handle"
	):
		return false
	var legacy_body: Resource = legacy_state.call(
		"get_selected_material_body"
	) as Resource
	if not _expect_handle_body(legacy_body, "simulated legacy Handle"):
		return false
	var exact_polygon: PackedVector2Array = (
		legacy_body.get("profile_polygon_2d_meters") as PackedVector2Array
	).duplicate()
	legacy_body.set("handle_profile_authoring_snapshot", {})
	legacy_state.call(
		"set_active_handle_face_count",
		ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_OCTAGON
	)
	if not _expect(
		_result_ok(legacy_state.call("begin_handle_change")),
		"simulated legacy Handle did not enter Change Handle mode"
	):
		return false
	if not _expect(
		_result_ok(legacy_state.call("apply_handle_change")),
		"simulated legacy Handle did not apply without profile edits"
	):
		return false
	var replacement: Resource = legacy_state.call(
		"get_selected_material_body"
	) as Resource
	var replacement_polygon := (
		replacement.get("profile_polygon_2d_meters") as PackedVector2Array
		if replacement != null
		else PackedVector2Array()
	)
	return _expect(
		replacement != null
		and _vector2_points_match(exact_polygon, replacement_polygon)
		and not (
			replacement.get("handle_profile_authoring_snapshot") as Dictionary
		).is_empty(),
		(
			"legacy no-edit Apply did not preserve its exact compiled polygon "
			+ "while adding the new authoring snapshot"
		)
	)


func _verify_save_preparation_auto_applies_handle_change(
	state: Resource
) -> bool:
	var committed_replacement: Resource = state.call(
		"commit_pending_material_bodies_as_layer"
	) as Resource
	if not _expect(
		committed_replacement != null
		and int(state.call("get_pending_material_body_count")) == 0
		and int(state.call("get_protected_layer_count")) == 1,
		"replacement Handle could not be committed before Save preparation test"
	):
		return false

	var controller: Node = ForgeV2StageControllerScript.new()
	controller.name = "SingleHandleChangeSaveController"
	root.add_child(controller)
	await process_frame
	controller.set("active_authoring_state", state)
	var activation_result: Dictionary = controller.call(
		"activate_handle_tool"
	) as Dictionary
	if not _expect(
		bool(activation_result.get("ok", false))
		and bool(state.call("is_handle_change_active")),
		"StageController did not open Change Handle for the committed Handle"
	):
		controller.queue_free()
		return false
	var save_edited_point := EDITED_MIDDLE_POINT + Vector3(0.0, 0.015, 0.0)
	if not _expect(
		bool(state.call("set_spline_line_point", 1, save_edited_point)),
		"open Handle change could not be edited before Save preparation"
	):
		controller.queue_free()
		return false
	state.call(
		"set_runtime_contract_mesh_export_provider",
		Callable(self, "_build_valid_runtime_mesh_packet")
	)
	var save_result: Dictionary = await controller.call(
		"prepare_pending_work_for_save",
		1000
	) as Dictionary
	var live_bodies: Array[Resource] = state.get("material_bodies") as Array[Resource]
	var saved_body: Resource = live_bodies[0] if live_bodies.size() == 1 else null
	var saved_points := (
		saved_body.get("path_points") as PackedVector3Array
		if saved_body != null
		else PackedVector3Array()
	)
	var valid := _expect(
		bool(save_result.get("ok", false))
		and bool(save_result.get("committed_pending_work", false))
		and not bool(state.call("is_handle_change_active"))
		and int(state.call("get_pending_material_body_count")) == 0
		and int(state.call("get_material_body_count")) == 1
		and int(state.call("get_handle_material_body_count")) == 1
		and int(state.call("get_protected_layer_count")) == 1
		and saved_body != null
		and StringName(saved_body.get("committed_layer_id")) != StringName()
		and saved_points.size() == 3
		and saved_points[1].distance_to(save_edited_point) <= EPSILON,
		(
			"Save preparation did not auto-apply and commit exactly one "
			+ "protected Handle: %s" % str(save_result)
		)
	)
	controller.queue_free()
	return valid


func _build_valid_runtime_mesh_packet() -> Dictionary:
	return {
		"ok": true,
		"vertices": PackedVector3Array([
			Vector3(0.0, 0.0, 0.0),
			Vector3(0.1, 0.0, 0.0),
			Vector3(0.0, 0.1, 0.0),
			Vector3(0.0, 0.0, 0.1),
		]),
		"indices": PackedInt32Array([
			0, 2, 1,
			0, 1, 3,
			0, 3, 2,
			1, 2, 3,
		]),
	}


func _author_handle(state: Resource, path_points: Array[Vector3]) -> bool:
	for point: Vector3 in path_points:
		if int(state.call(
			"append_spline_line_point",
			point,
			Vector3.UP
		)) < 0:
			return false
	return bool(state.call("generate_profile_extrusion_from_spline"))


func _expect_second_handle_rejected(state: Resource, context: String) -> bool:
	var body_count_before := int(state.call("get_material_body_count"))
	var append_result := int(state.call(
		"append_spline_line_point",
		Vector3(-0.25, 0.0, 0.0),
		Vector3.UP
	))
	return _expect(
		append_result < 0
		and int(state.call("get_material_body_count")) == body_count_before,
		"a second Handle authoring path was accepted beside %s" % context
	)


func _expect_handle_body(body: Resource, context: String) -> bool:
	return _expect(
		body != null
		and StringName(body.get("body_kind"))
		== ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE,
		"%s was not a Handle profile body" % context
	)


func _expect_snapshot(
	snapshot: Dictionary,
	expected_face_count: int,
	context: String
) -> bool:
	var control_points: PackedVector2Array = snapshot.get(
		"control_points_2d_meters",
		PackedVector2Array()
	)
	return _expect(
		not snapshot.is_empty()
		and StringName(snapshot.get("family", StringName()))
		== ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE
		and int(snapshot.get("face_count", 0)) == expected_face_count
		and control_points.size() == expected_face_count,
		"%s did not retain its semantic editable profile snapshot" % context
	)


func _result_ok(result: Variant) -> bool:
	if result is Dictionary:
		return bool((result as Dictionary).get("ok", false))
	return bool(result)


func _points_match(
	first_points: PackedVector3Array,
	second_points: Array[Vector3]
) -> bool:
	if first_points.size() != second_points.size():
		return false
	for point_index in range(first_points.size()):
		if first_points[point_index].distance_to(second_points[point_index]) > EPSILON:
			return false
	return true


func _vector2_points_match(
	first_points: PackedVector2Array,
	second_points: PackedVector2Array
) -> bool:
	if first_points.size() != second_points.size():
		return false
	for point_index in range(first_points.size()):
		if first_points[point_index].distance_to(second_points[point_index]) > EPSILON:
			return false
	return true


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	result_lines.append("ok=false")
	result_lines.append("error=%s" % message)
	_write_results()
	push_error("FORGE_V2_SINGLE_HANDLE_CHANGE_VERIFY: FAIL: %s" % message)
	quit(1)


func _write_results() -> void:
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(result_lines) + "\n")
	file.close()
