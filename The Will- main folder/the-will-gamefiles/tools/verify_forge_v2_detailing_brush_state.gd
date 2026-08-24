extends SceneTree

const ForgeV2AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_detailing_brush_state_2026-08-10.txt"
)
const TARGET_KIND := &"target_material_surface"
const EPSILON := 0.000001


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	_test_controller_atomic_selection()
	_test_invalid_solution_rejected_by_generation()
	_test_tool_switching_and_free_spline()
	_test_detail_generation_and_disk_round_trip()
	_write_result([
		"ok=true",
		"controller_atomic_selection_preserved=true",
		"invalid_solution_persisted_but_not_generated=true",
		"tool_switching_clears_transient_paths=true",
		"free_spline_remains_spline=true",
		"primitive_detail_is_dense_linear=true",
		"saved_profile_detail_is_dense_linear=true",
		"surface_target_provenance_preserved=true",
		"explicit_contact_directions_preserved=true",
		"body_layer_wip_disk_roundtrip=true",
	])
	quit(0)


func _test_controller_atomic_selection() -> void:
	var controller := ForgeV2StageControllerScript.new()
	root.add_child(controller)
	controller.call(
		"set_active_tool_id",
		ForgeV2AuthoringStateScript.TOOL_DETAILING_BRUSH
	)
	var solution := _build_solution(&"controller_surface", true)
	_require(
		bool(controller.call(
			"replace_detailing_brush_path_solution",
			solution["controls"],
			solution["control_normals"],
			TARGET_KIND,
			&"controller_surface",
			solution["points"],
			solution["normals"],
			solution["span_offsets"],
			solution["span_validity"],
			solution["span_reasons"],
			true,
			&"none",
			0,
			solution["control_contacts"],
			solution["contacts"]
		)),
		"controller rejected a coherent Detail solution"
	)
	var state: Resource = controller.call("get_active_authoring_state") as Resource
	_require(
		int(state.get("selected_spline_point_index")) == 0,
		"dragged control 0 selection jumped to the last control"
	)
	controller.queue_free()


func _test_invalid_solution_rejected_by_generation() -> void:
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Invalid Detail")
	state.call(
		"set_active_tool_id",
		ForgeV2AuthoringStateScript.TOOL_DETAILING_BRUSH
	)
	var invalid_solution := _build_solution(&"invalid_surface", false)
	_require(
		_apply_solution(state, invalid_solution, 0),
		"structurally coherent invalid spans were not persistable"
	)
	_require(
		int(state.get("selected_spline_point_index")) == 0,
		"invalid Detail replacement did not preserve selected control 0"
	)
	_require(
		not bool(state.call("can_generate_detailing_brush"))
		and not bool(state.call("generate_detailing_brush")),
		"invalid Detail solution generated material"
	)
	var summary: Dictionary = state.call("get_status_summary", false) as Dictionary
	var detail: Dictionary = summary.get("detailing_brush", {}) as Dictionary
	_require(
		not bool(detail.get("valid", true))
		and StringName(detail.get("reason", StringName())) == &"target_miss"
		and String(detail.get("status_label", "")).contains("target miss"),
		"Detail status did not expose the invalid reason"
	)
	_require(bool(state.call("cancel_spline_line")), "Detail cancel did not clear state")
	_require(_detail_state_is_clear(state), "Detail cancel left transient fields behind")


func _test_tool_switching_and_free_spline() -> void:
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Switching Detail")
	state.call(
		"set_active_tool_id",
		ForgeV2AuthoringStateScript.TOOL_SPLINE_LINE
	)
	state.call("append_spline_line_point", Vector3.ZERO, Vector3.UP)
	state.call("append_spline_line_point", Vector3(0.1, 0.0, 0.0), Vector3.UP)
	state.call(
		"set_active_tool_id",
		ForgeV2AuthoringStateScript.TOOL_DETAILING_BRUSH
	)
	_require(
		(state.get("spline_line_points") as PackedVector3Array).is_empty(),
		"entering Detail reinterpreted a free Spline path"
	)
	var detail_solution := _build_solution(&"switch_surface", true)
	_require(_apply_solution(state, detail_solution, 0), "valid switch Detail failed")
	state.call(
		"set_active_tool_id",
		ForgeV2AuthoringStateScript.TOOL_SPLINE_LINE
	)
	_require(
		_detail_state_is_clear(state)
		and (state.get("spline_line_points") as PackedVector3Array).is_empty(),
		"leaving Detail reinterpreted its surface path as free Spline"
	)
	state.call("append_spline_line_point", Vector3.ZERO, Vector3.FORWARD)
	state.call(
		"append_spline_line_point",
		Vector3(0.12, 0.02, 0.0),
		Vector3.FORWARD
	)
	_require(
		bool(state.call("generate_spline_line_csg_noodle")),
		"free Spline no longer generated"
	)
	var free_body: Resource = state.call("get_selected_material_body") as Resource
	_require(
		free_body != null
		and StringName(free_body.get("body_kind"))
		== ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE
		and StringName(free_body.get("shape_kind"))
		== ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_CAPSULE_PATH,
		"free Spline was converted into a Detail/linear body"
	)


func _test_detail_generation_and_disk_round_trip() -> void:
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Detail Round Trip")
	state.call(
		"set_active_tool_id",
		ForgeV2AuthoringStateScript.TOOL_DETAILING_BRUSH
	)
	state.call(
		"set_active_operation_mode",
		ForgeV2AuthoringStateScript.OPERATION_REMOVE_MATERIAL
	)
	state.call(
		"set_placement_policy",
		ForgeV2AuthoringStateScript.PLACEMENT_EMPTY_ONLY
	)
	var primitive_solution := _build_solution(&"primitive_surface", true)
	_require(_apply_solution(state, primitive_solution, 0), "primitive Detail failed")
	_require(bool(state.call("generate_detailing_brush")), "primitive Detail did not generate")
	var primitive_body: Resource = state.call("get_selected_material_body") as Resource
	_assert_detail_body(
		primitive_body,
		ForgeV2MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH,
		&"primitive_surface",
		primitive_solution
	)
	_require(
		StringName(primitive_body.get("operation_mode"))
		== ForgeV2AuthoringStateScript.OPERATION_REMOVE_MATERIAL
		and StringName(primitive_body.get("placement_policy"))
		== ForgeV2AuthoringStateScript.PLACEMENT_EMPTY_ONLY,
		"Detail body ignored current operation/policy"
	)
	var primitive_body_id := StringName(primitive_body.get("body_id"))
	var primitive_layer: Resource = state.call(
		"commit_material_body_as_layer",
		primitive_body_id
	) as Resource
	_require(primitive_layer != null, "primitive Detail layer commit failed")
	_assert_layer_record(
		primitive_layer,
		primitive_body_id,
		&"primitive_surface",
		primitive_solution
	)

	state.call(
		"set_active_operation_mode",
		ForgeV2AuthoringStateScript.OPERATION_ADD_MATERIAL
	)
	state.call(
		"set_placement_policy",
		ForgeV2AuthoringStateScript.PLACEMENT_REPLACE_EXISTING
	)
	var compiled_profile := _build_compiled_saved_profile()
	_require(
		bool(state.call("select_active_saved_basic_profile", compiled_profile)),
		"saved Basic profile was not selectable for Detail"
	)
	var profile_solution := _build_solution(&"profile_surface", true, 0.35)
	_require(_apply_solution(state, profile_solution, 1), "profile Detail failed")
	_require(bool(state.call("generate_detailing_brush")), "profile Detail did not generate")
	var profile_body: Resource = state.call("get_selected_material_body") as Resource
	_assert_detail_body(
		profile_body,
		ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH,
		&"profile_surface",
		profile_solution
	)
	_require(
		(profile_body.get("profile_polygon_2d_meters") as PackedVector2Array).size() >= 3,
		"saved-profile Detail lost its polygon"
	)
	var profile_body_id := StringName(profile_body.get("body_id"))
	var profile_layer: Resource = state.call(
		"commit_material_body_as_layer",
		profile_body_id
	) as Resource
	_require(profile_layer != null, "profile Detail layer commit failed")
	_assert_layer_record(
		profile_layer,
		profile_body_id,
		&"profile_surface",
		profile_solution
	)

	# Keep a third solved path transient so the same WIP round trip proves both
	# generated body/layer provenance and the editable span solution.
	var transient_solution := _build_solution(&"transient_surface", true, 0.7)
	_require(
		_apply_solution(state, transient_solution, 0),
		"transient Detail solution failed before WIP save"
	)
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = &"verify_detail_wip"
	wip.forge_project_name = "Detail Round Trip"
	wip.forge_v2_authoring_state = state
	var wip_path := "C:/WORKSPACE/godot_runs/verify_detail_wip_%s.tres" % str(
		Time.get_ticks_usec()
	)
	_require(ResourceSaver.save(wip, wip_path) == OK, "Detail WIP disk save failed")
	var loaded_wip: CraftedItemWIP = ResourceLoader.load(
		wip_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as CraftedItemWIP
	_require(
		loaded_wip != null and loaded_wip.forge_v2_authoring_state != null,
		"Detail WIP disk reload failed"
	)
	var loaded_state: Resource = loaded_wip.forge_v2_authoring_state
	loaded_state.call("normalize")
	_assert_transient_solution(loaded_state, transient_solution)
	var loaded_primitive := _find_body(loaded_state, primitive_body_id)
	var loaded_profile := _find_body(loaded_state, profile_body_id)
	_assert_detail_body(
		loaded_primitive,
		ForgeV2MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH,
		&"primitive_surface",
		primitive_solution
	)
	_assert_detail_body(
		loaded_profile,
		ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH,
		&"profile_surface",
		profile_solution
	)
	var loaded_layers: Array = loaded_state.get("forge_layers") as Array
	_require(loaded_layers.size() == 2, "Detail layers did not survive WIP reload")
	_assert_layer_record(
		loaded_layers[0] as Resource,
		primitive_body_id,
		&"primitive_surface",
		primitive_solution
	)
	_assert_layer_record(
		loaded_layers[1] as Resource,
		profile_body_id,
		&"profile_surface",
		profile_solution
	)
	var export_snapshot: Dictionary = loaded_state.call(
		"build_authoring_export_snapshot"
	) as Dictionary
	var exported_detail: Dictionary = export_snapshot.get(
		"detailing_brush",
		{}
	) as Dictionary
	_require(
		StringName(exported_detail.get("locked_target_id", StringName()))
		== &"transient_surface",
		"authoring export lost transient Detail provenance"
	)
	var exported_primitive := _find_snapshot_by_id(
		export_snapshot.get("material_bodies", []) as Array,
		"body_id",
		primitive_body_id
	)
	_require(
		StringName(exported_primitive.get("surface_target_kind", StringName()))
		== TARGET_KIND
		and StringName(exported_primitive.get("surface_target_id", StringName()))
		== &"primitive_surface",
		"material body export snapshot lost Detail target provenance"
	)
	var exported_layers: Array = export_snapshot.get("forge_layers", []) as Array
	_require(exported_layers.size() == 2, "layer export snapshots were incomplete")
	var exported_first_layer := exported_layers[0] as Dictionary
	var exported_first_record := _find_snapshot_by_id(
		exported_first_layer.get("input_shape_records", []) as Array,
		"body_id",
		primitive_body_id
	)
	_require(
		StringName(exported_first_record.get("surface_target_id", StringName()))
		== &"primitive_surface",
		"layer export snapshot lost Detail target provenance"
	)
	DirAccess.remove_absolute(wip_path)


func _build_solution(
	target_id: StringName,
	is_valid: bool,
	x_offset: float = 0.0
) -> Dictionary:
	var controls := PackedVector3Array([
		Vector3(x_offset + 0.00, 0.00, 0.01),
		Vector3(x_offset + 0.10, 0.03, 0.015),
		Vector3(x_offset + 0.22, 0.01, 0.02),
	])
	var control_normals := PackedVector3Array([
		Vector3.UP,
		Vector3(0.0, 1.0, 0.1).normalized(),
		Vector3(0.1, 1.0, 0.0).normalized(),
	])
	var points := PackedVector3Array([
		controls[0],
		Vector3(x_offset + 0.05, 0.018, 0.012),
		controls[1],
		Vector3(x_offset + 0.16, 0.024, 0.018),
		controls[2],
	])
	var normals := PackedVector3Array([
		control_normals[0],
		Vector3(0.0, 1.0, 0.04).normalized(),
		control_normals[1],
		Vector3(0.05, 1.0, 0.03).normalized(),
		control_normals[2],
	])
	var control_contacts := PackedVector3Array()
	for normal: Vector3 in control_normals:
		control_contacts.append(-normal)
	var contacts := PackedVector3Array()
	for normal: Vector3 in normals:
		contacts.append(-normal)
	return {
		"target_id": target_id,
		"controls": controls,
		"control_normals": control_normals,
		"points": points,
		"normals": normals,
		"control_contacts": control_contacts,
		"contacts": contacts,
		"span_offsets": PackedInt32Array([0, 2, 4]),
		"span_validity": [is_valid, true],
		"span_reasons": [
			&"none" if is_valid else &"target_miss",
			&"none",
		],
		"valid": is_valid,
		"reason": &"none" if is_valid else &"target_miss",
	}


func _apply_solution(
	state: Resource,
	solution: Dictionary,
	selected_point_index: int
) -> bool:
	return bool(state.call(
		"replace_detailing_brush_path_solution",
		solution["controls"],
		solution["control_normals"],
		TARGET_KIND,
		StringName(solution["target_id"]),
		solution["points"],
		solution["normals"],
		solution["span_offsets"],
		solution["span_validity"],
		solution["span_reasons"],
		bool(solution["valid"]),
		StringName(solution["reason"]),
		selected_point_index,
		solution["control_contacts"],
		solution["contacts"]
	))


func _build_compiled_saved_profile() -> Dictionary:
	var square := PackedVector2Array([
		Vector2(-0.02, -0.02),
		Vector2(0.02, -0.02),
		Vector2(0.02, 0.02),
		Vector2(-0.02, 0.02),
	])
	return ForgeV2ProfileShapeLibraryScript.compile_basic_profile_runtime_data({
		"profile_id": &"detail_saved_profile",
		"id": &"detail_saved_profile",
		"label": "Detail Saved Profile",
		"family": ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC,
		"base_polygon_2d_meters": square,
		"polygon_2d_meters": square,
		"base_anchor_2d_meters": Vector2.ZERO,
		"anchor_x_meters": 0.0,
		"anchor_y_meters": 0.0,
		"rotation_degrees": 0.0,
	})


func _assert_detail_body(
	body: Resource,
	expected_shape_kind: StringName,
	expected_target_id: StringName,
	solution: Dictionary
) -> void:
	_require(body != null, "expected Detail body was missing")
	_require(
		StringName(body.get("body_kind"))
		== ForgeV2MaterialBodyScript.BODY_KIND_DETAILING_BRUSH
		and StringName(body.get("shape_kind")) == expected_shape_kind,
		"Detail body was not authoritative dense linear geometry"
	)
	_require(
		StringName(body.get("surface_target_kind")) == TARGET_KIND
		and StringName(body.get("surface_target_id")) == expected_target_id,
		"Detail body lost locked surface target provenance"
	)
	_require(
		_packed_vector3_arrays_match(
			body.get("path_points") as PackedVector3Array,
			solution["points"] as PackedVector3Array
		)
		and _packed_vector3_arrays_match(
			body.get("path_surface_normals") as PackedVector3Array,
			solution["normals"] as PackedVector3Array
		),
		"Detail body did not use the authoritative resolved path/normals"
	)
	if expected_shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH:
		_require(
			_packed_vector3_arrays_match(
				body.get("path_contact_directions") as PackedVector3Array,
				solution["contacts"] as PackedVector3Array
			),
			"saved-profile Detail body lost explicit B-C samples"
		)
	_require(
		StringName(body.get("shape_kind"))
		not in [
			ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_CAPSULE_PATH,
			ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH,
		],
		"Detail body retained a spline shape kind"
	)


func _assert_layer_record(
	layer: Resource,
	body_id: StringName,
	expected_target_id: StringName,
	solution: Dictionary
) -> void:
	_require(layer != null, "expected Detail layer was missing")
	for record_variant: Variant in layer.get("input_shape_records") as Array:
		if not record_variant is Dictionary:
			continue
		var record := record_variant as Dictionary
		if StringName(record.get("body_id", StringName())) != body_id:
			continue
		_require(
			StringName(record.get("surface_target_kind", StringName()))
			== TARGET_KIND
			and StringName(record.get("surface_target_id", StringName()))
			== expected_target_id,
			"Detail layer record lost target provenance"
		)
		_require(
			_packed_vector3_arrays_match(
				record.get("path_points", PackedVector3Array()) as PackedVector3Array,
				solution["points"] as PackedVector3Array
			)
			and _packed_vector3_arrays_match(
				record.get("path_surface_normals", PackedVector3Array()) as PackedVector3Array,
				solution["normals"] as PackedVector3Array
			),
			"Detail layer record lost resolved geometry"
		)
		if (
			StringName(record.get("shape_kind", StringName()))
			== ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
		):
			_require(
				_packed_vector3_arrays_match(
					record.get(
						"path_contact_directions",
						PackedVector3Array()
					) as PackedVector3Array,
					solution["contacts"] as PackedVector3Array
				),
				"saved-profile Detail layer lost explicit B-C samples"
			)
		return
	_require(false, "Detail body was absent from its layer input records")


func _assert_transient_solution(state: Resource, solution: Dictionary) -> void:
	_require(
		StringName(state.get("detailing_surface_target_kind")) == TARGET_KIND
		and StringName(state.get("detailing_surface_target_id"))
		== StringName(solution["target_id"])
		and bool(state.get("detailing_solution_valid")),
		"WIP reload lost transient Detail target/validity"
	)
	_require(
		_packed_vector3_arrays_match(
			state.get("spline_line_points") as PackedVector3Array,
			solution["controls"] as PackedVector3Array
		)
		and _packed_vector3_arrays_match(
			state.get("spline_line_surface_normals") as PackedVector3Array,
			solution["control_normals"] as PackedVector3Array
		)
		and _packed_vector3_arrays_match(
			state.get("detailing_resolved_path_points") as PackedVector3Array,
			solution["points"] as PackedVector3Array
		)
		and _packed_vector3_arrays_match(
			state.get("detailing_resolved_surface_normals") as PackedVector3Array,
			solution["normals"] as PackedVector3Array
		)
		and _packed_vector3_arrays_match(
			state.get(
				"detailing_control_contact_directions"
			) as PackedVector3Array,
			solution["control_contacts"] as PackedVector3Array
		)
		and _packed_vector3_arrays_match(
			state.get(
				"detailing_resolved_contact_directions"
			) as PackedVector3Array,
			solution["contacts"] as PackedVector3Array
		),
		"WIP reload lost transient Detail path/normals/B-C samples"
	)
	_require(
		(state.get("detailing_span_offsets") as PackedInt32Array)
		== (solution["span_offsets"] as PackedInt32Array)
		and (state.get("detailing_span_validity") as Array)
		== (solution["span_validity"] as Array)
		and (state.get("detailing_span_reasons") as Array)
		== (solution["span_reasons"] as Array),
		"WIP reload lost transient Detail span solution"
	)


func _find_body(state: Resource, body_id: StringName) -> Resource:
	for body_variant: Variant in state.get("material_bodies") as Array:
		var body := body_variant as Resource
		if body != null and StringName(body.get("body_id")) == body_id:
			return body
	return null


func _find_snapshot_by_id(
	snapshots: Array,
	id_key: String,
	expected_id: StringName
) -> Dictionary:
	for snapshot_variant: Variant in snapshots:
		if not snapshot_variant is Dictionary:
			continue
		var snapshot := snapshot_variant as Dictionary
		if StringName(snapshot.get(id_key, StringName())) == expected_id:
			return snapshot
	return {}


func _detail_state_is_clear(state: Resource) -> bool:
	return (
		StringName(state.get("detailing_surface_target_kind")) == StringName()
		and StringName(state.get("detailing_surface_target_id")) == StringName()
		and (state.get("detailing_resolved_path_points") as PackedVector3Array).is_empty()
		and (state.get("detailing_resolved_surface_normals") as PackedVector3Array).is_empty()
		and (state.get(
			"detailing_control_contact_directions"
		) as PackedVector3Array).is_empty()
		and (state.get(
			"detailing_resolved_contact_directions"
		) as PackedVector3Array).is_empty()
		and (state.get("detailing_span_offsets") as PackedInt32Array).is_empty()
		and (state.get("detailing_span_validity") as Array).is_empty()
		and (state.get("detailing_span_reasons") as Array).is_empty()
		and not bool(state.get("detailing_solution_valid"))
	)


func _packed_vector3_arrays_match(
	first: PackedVector3Array,
	second: PackedVector3Array
) -> bool:
	if first.size() != second.size():
		return false
	for point_index in range(first.size()):
		if first[point_index].distance_to(second[point_index]) > EPSILON:
			return false
	return true


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_write_result(["ok=false", "error=%s" % message])
	push_error(message)
	quit(1)


func _write_result(lines: Array[String]) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
