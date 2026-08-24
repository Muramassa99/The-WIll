extends SceneTree

const AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const CraftedItemWIPScript = preload(
	"res://core/models/crafted_item_wip.gd"
)
const VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_handle_axial_span_authority_2026-08-22.txt"
)
const MIN_AXIAL_SPAN_METERS := 0.25
var _folded_path := PackedVector3Array([
	Vector3.ZERO,
	Vector3(0.30, 0.0, 0.0),
	Vector3(0.01, 0.0, 0.0),
])
var _valid_boundary_path := PackedVector3Array([
	Vector3.ZERO,
	Vector3(0.12, 0.05, 0.0),
	Vector3(0.25, 0.0, 0.0),
])

var _result_lines: PackedStringArray = []


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	if not _verify_folded_handle_generation_is_rejected():
		return
	if not _verify_handle_commit_gate_and_boundary():
		return
	if not _verify_folded_ordinary_noodle_is_unchanged():
		return
	if not _verify_handle_span_preview_feedback():
		return
	_result_lines.append("ok=true")
	_write_results()
	print("Forge V2 Handle axial-span authority verifier passed")
	quit(0)


func _verify_folded_handle_generation_is_rejected() -> bool:
	if _polyline_length(_folded_path) < MIN_AXIAL_SPAN_METERS:
		return _fail("folded Handle fixture does not exceed minimum polyline length")
	if _endpoint_span(_folded_path) >= MIN_AXIAL_SPAN_METERS:
		return _fail("folded Handle fixture unexpectedly has valid endpoint span")
	var state := _build_handle_state()
	_append_path(state, _folded_path)
	if bool(state.call("can_generate_profile_extrusion_from_spline")):
		return _fail("folded Handle passed generation readiness on polyline length")
	var status := String(state.call("get_profile_extrusion_status_label"))
	if not status.contains("axial span") or not status.contains("currently"):
		return _fail("folded Handle status does not explain axial-span rejection: %s" % status)
	if bool(state.call("generate_profile_extrusion_from_spline")):
		return _fail("folded Handle generated despite invalid endpoint axial span")
	if int(state.call("get_pending_material_body_count")) != 0:
		return _fail("rejected folded Handle left a pending material body")
	_result_lines.append(
		"PASS: long folded polyline rejected by short p0-to-p2 axial span"
	)
	_result_lines.append("folded_status=%s" % status)
	return true


func _verify_handle_commit_gate_and_boundary() -> bool:
	if not is_equal_approx(_endpoint_span(_valid_boundary_path), MIN_AXIAL_SPAN_METERS):
		return _fail("valid boundary fixture is not exactly 0.25 m endpoint span")
	var state := _build_handle_state()
	_append_path(state, _valid_boundary_path)
	if not bool(state.call("can_generate_profile_extrusion_from_spline")):
		return _fail("Handle at exact 0.25 m endpoint span was not generation-ready")
	var status := String(state.call("get_profile_extrusion_status_label"))
	if not status.contains("ready") or not status.contains("axial span"):
		return _fail("valid Handle status does not report ready axial span: %s" % status)
	if not bool(state.call("generate_profile_extrusion_from_spline")):
		return _fail("Handle at exact 0.25 m endpoint span did not generate")
	var body: Resource = state.call("get_selected_material_body") as Resource
	if body == null:
		return _fail("valid generated Handle body is missing")
	if (
		StringName(body.get("body_kind"))
		!= MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
	):
		return _fail("valid generated body lost semantic Handle authority")
	var body_id := StringName(body.get("body_id"))
	body.set("path_points", _folded_path)
	body.call("normalize")
	if bool(state.call("is_material_body_commit_ready", body_id)):
		return _fail("pending Handle commit gate accepted folded endpoint span")
	if state.call("commit_material_body_as_layer", body_id) != null:
		return _fail("folded pending Handle committed despite invalid endpoint span")
	body.set("path_points", _valid_boundary_path)
	body.call("normalize")
	if not bool(state.call("is_material_body_commit_ready", body_id)):
		return _fail("commit gate rejected Handle restored to exact 0.25 m span")
	var layer: Resource = state.call("commit_material_body_as_layer", body_id) as Resource
	if layer == null:
		return _fail("valid Handle did not commit after endpoint-span restoration")
	_result_lines.append(
		"PASS: commit gate rejects folded Handle and accepts exact 0.25 m boundary"
	)
	_result_lines.append("boundary_status=%s" % status)
	return true


func _verify_folded_ordinary_noodle_is_unchanged() -> bool:
	var state: Resource = AuthoringStateScript.new()
	state.call("reset_new_draft", "Ordinary Noodle Axial-Span Control")
	state.call("set_active_tool_id", AuthoringStateScript.TOOL_VOLUME_STROKE)
	_append_path(state, _folded_path)
	if not bool(state.call("can_generate_spline_line_csg_noodle")):
		return _fail("ordinary folded noodle lost its existing polyline readiness")
	if not bool(state.call("generate_spline_line_csg_noodle")):
		return _fail("ordinary folded noodle no longer generates")
	var body: Resource = state.call("get_selected_material_body") as Resource
	if body == null:
		return _fail("ordinary folded noodle body is missing")
	if (
		StringName(body.get("body_kind"))
		== MaterialBodyScript.BODY_KIND_HANDLE_PROFILE
	):
		return _fail("ordinary folded noodle acquired Handle authority")
	var body_id := StringName(body.get("body_id"))
	if not bool(state.call("is_material_body_commit_ready", body_id)):
		return _fail("ordinary folded noodle became subject to Handle commit rule")
	if state.call("commit_material_body_as_layer", body_id) == null:
		return _fail("ordinary folded noodle no longer commits")
	_result_lines.append(
		"PASS: ordinary/noodle polyline generation and commit behavior is unchanged"
	)
	return true


func _verify_handle_span_preview_feedback() -> bool:
	var presenter: Node3D = VolumePreviewPresenterScript.new()
	root.add_child(presenter)

	var incomplete_state := _build_handle_state()
	_append_path(
		incomplete_state,
		PackedVector3Array([_folded_path[0], _folded_path[1]])
	)
	presenter.call("_sync_spline_preview_mesh", incomplete_state)
	if _invalid_spline_preview_is_visible(presenter):
		presenter.free()
		return _fail("incomplete two-point Handle preview was incorrectly red")
	if not _normal_preview_contains_color(
		presenter,
		Color(0.18, 0.52, 1.0, 0.92)
	):
		presenter.free()
		return _fail("incomplete Handle lost its normal blue connection guide")

	var non_ranged_paths: Array[StringName] = [
		CraftedItemWIPScript.BUILDER_PATH_MELEE,
		CraftedItemWIPScript.BUILDER_PATH_SHIELD,
		CraftedItemWIPScript.BUILDER_PATH_MAGIC,
	]
	for builder_path_id: StringName in non_ranged_paths:
		var invalid_state := _build_handle_state(builder_path_id)
		_append_path(invalid_state, _folded_path)
		if bool(invalid_state.call(
			"can_generate_profile_extrusion_from_spline"
		)):
			presenter.free()
			return _fail(
				"%s accepted an under-minimum endpoint span"
				% String(builder_path_id)
			)
		presenter.call("_sync_spline_preview_mesh", invalid_state)
		if not _invalid_spline_preview_is_visible(presenter):
			presenter.free()
			return _fail(
				"%s did not show the under-minimum Handle guide in red"
				% String(builder_path_id)
			)
		if not _invalid_preview_is_clear_red(presenter):
			presenter.free()
			return _fail(
				"%s invalid Handle guide did not carry the clear-red color"
				% String(builder_path_id)
			)
		if not bool(invalid_state.call("finish_spline_line")):
			presenter.free()
			return _fail("under-minimum Handle could not finish its editable line")
		presenter.call("_sync_spline_preview_mesh", invalid_state)
		if not _invalid_spline_preview_is_visible(presenter):
			presenter.free()
			return _fail("finished under-minimum Handle stopped showing red")

		var valid_state := _build_handle_state(builder_path_id)
		_append_path(valid_state, _valid_boundary_path)
		if not bool(valid_state.call(
			"can_generate_profile_extrusion_from_spline"
		)):
			presenter.free()
			return _fail(
				"%s rejected the exact minimum endpoint span"
				% String(builder_path_id)
			)
		presenter.call("_sync_spline_preview_mesh", valid_state)
		if _invalid_spline_preview_is_visible(presenter):
			presenter.free()
			return _fail(
				"%s kept a valid Handle boundary red"
				% String(builder_path_id)
			)
		if not _normal_preview_contains_color(
			presenter,
			Color(0.18, 0.52, 1.0, 0.92)
		):
			presenter.free()
			return _fail(
				"%s valid editing Handle did not restore the blue guide"
				% String(builder_path_id)
			)
		var scope_summary := valid_state.call(
			"get_status_summary",
			false
		) as Dictionary
		if StringName(scope_summary.get("builder_path", StringName())) != (
			builder_path_id
		):
			presenter.free()
			return _fail("Handle feedback changed the active builder path")

	var ordinary_state: Resource = AuthoringStateScript.new()
	ordinary_state.call("reset_new_draft", "Ordinary Spline Preview Control")
	ordinary_state.call(
		"set_active_tool_id",
		AuthoringStateScript.TOOL_SPLINE_LINE
	)
	_append_path(ordinary_state, _folded_path)
	presenter.call("_sync_spline_preview_mesh", ordinary_state)
	if _invalid_spline_preview_is_visible(presenter):
		presenter.free()
		return _fail("ordinary folded spline incorrectly acquired Handle-red feedback")

	var ranged_state := _build_handle_state(
		CraftedItemWIPScript.BUILDER_PATH_RANGED_PHYSICAL,
		CraftedItemWIPScript.BUILDER_COMPONENT_BOW
	)
	var ranged_before := ranged_state.call(
		"get_status_summary",
		false
	) as Dictionary
	var ranged_seed_count_before := int(
		ranged_state.call("get_seed_material_body_count")
	)
	_append_path(ranged_state, _folded_path)
	presenter.call("_sync_spline_preview_mesh", ranged_state)
	var ranged_after := ranged_state.call(
		"get_status_summary",
		false
	) as Dictionary
	if (
		StringName(ranged_after.get("builder_path", StringName()))
		!= CraftedItemWIPScript.BUILDER_PATH_RANGED_PHYSICAL
		or StringName(ranged_after.get("builder_component", StringName()))
		!= CraftedItemWIPScript.BUILDER_COMPONENT_BOW
		or StringName(ranged_after.get("forge_intent", StringName()))
		!= StringName(ranged_before.get("forge_intent", StringName()))
		or StringName(ranged_after.get("equipment_context", StringName()))
		!= StringName(ranged_before.get("equipment_context", StringName()))
		or int(ranged_state.call("get_seed_material_body_count"))
		!= ranged_seed_count_before
	):
		presenter.free()
		return _fail("generic Handle feedback changed ranged-physical authority")

	presenter.free()
	_result_lines.append(
		"PASS: three-point under-minimum Handle guides are red for melee, shield, and magic"
	)
	_result_lines.append(
		"PASS: incomplete/valid/ordinary previews remain normal and ranged authority is unchanged"
	)
	return true


func _invalid_spline_preview_is_visible(presenter: Node3D) -> bool:
	var invalid_instance := presenter.get_node_or_null(
		"SplineLineInvalidPreviewMesh"
	) as MeshInstance3D
	return (
		invalid_instance != null
		and invalid_instance.visible
		and invalid_instance.mesh != null
		and invalid_instance.mesh.get_surface_count() > 0
	)


func _invalid_preview_is_clear_red(presenter: Node3D) -> bool:
	var invalid_instance := presenter.get_node_or_null(
		"SplineLineInvalidPreviewMesh"
	) as MeshInstance3D
	if invalid_instance == null or invalid_instance.mesh == null:
		return false
	return _mesh_all_colors_match(
		invalid_instance.mesh,
		Color(1.0, 0.08, 0.04, 0.98),
		0.01
	)


func _normal_preview_contains_color(
	presenter: Node3D,
	expected_color: Color
) -> bool:
	var normal_instance := presenter.get_node_or_null(
		"SplineLinePreviewMesh"
	) as MeshInstance3D
	if normal_instance == null or normal_instance.mesh == null:
		return false
	return _mesh_contains_color(normal_instance.mesh, expected_color, 0.01)


func _mesh_all_colors_match(
	mesh: Mesh,
	expected_color: Color,
	epsilon: float
) -> bool:
	if mesh == null or mesh.get_surface_count() <= 0:
		return false
	for surface_index in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_index)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		if colors.is_empty():
			return false
		for color: Color in colors:
			if not _colors_match(color, expected_color, epsilon):
				return false
	return true


func _mesh_contains_color(
	mesh: Mesh,
	expected_color: Color,
	epsilon: float
) -> bool:
	if mesh == null or mesh.get_surface_count() <= 0:
		return false
	for surface_index in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_index)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for color: Color in colors:
			if _colors_match(color, expected_color, epsilon):
				return true
	return false


func _colors_match(
	actual: Color,
	expected: Color,
	epsilon: float
) -> bool:
	return (
		absf(actual.r - expected.r) <= epsilon
		and absf(actual.g - expected.g) <= epsilon
		and absf(actual.b - expected.b) <= epsilon
		and absf(actual.a - expected.a) <= epsilon
	)


func _build_handle_state(
	builder_path_id: StringName = CraftedItemWIPScript.BUILDER_PATH_MELEE,
	builder_component_id: StringName = StringName()
) -> Resource:
	var entries: Array[Dictionary] = (
		ProfileShapeLibraryScript.build_handle_profile_entries()
	)
	if entries.is_empty():
		return null
	var state: Resource = AuthoringStateScript.new()
	state.call("reset_new_draft", "Handle Axial-Span Authority")
	state.call("set_builder_path", builder_path_id, builder_component_id)
	state.call("set_active_tool_id", AuthoringStateScript.TOOL_HANDLES)
	state.call(
		"set_active_profile_id",
		StringName(entries[0].get("id", StringName()))
	)
	return state


func _append_path(state: Resource, points: PackedVector3Array) -> void:
	for point: Vector3 in points:
		state.call("append_spline_line_point", point, Vector3.UP)


func _endpoint_span(points: PackedVector3Array) -> float:
	if points.size() < 2:
		return 0.0
	return points[0].distance_to(points[points.size() - 1])


func _polyline_length(points: PackedVector3Array) -> float:
	var length := 0.0
	for point_index in range(points.size() - 1):
		length += points[point_index].distance_to(points[point_index + 1])
	return length


func _fail(message: String) -> bool:
	_result_lines.append("FAIL: %s" % message)
	_result_lines.append("ok=false")
	_write_results()
	push_error(message)
	quit(1)
	return false


func _write_results() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_result_lines) + "\n")
