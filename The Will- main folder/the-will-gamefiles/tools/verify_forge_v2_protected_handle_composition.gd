extends SceneTree

const ForgeV2AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const ForgeV2LayerDataScript = preload(
	"res://runtime/forge_v2/forge_v2_layer_data.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2MaterialCompositionPolicyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_composition_policy.gd"
)
const ForgeV2MaterialVolumeResolverScript = preload(
	"res://runtime/forge_v2/forge_v2_material_volume_resolver.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_protected_handle_composition_2026-08-10.txt"
)
const HANDLE_MATERIAL := &"mat_iron_gray"
const ORDINARY_MATERIAL := &"mat_copper"
const SECOND_HANDLE_MATERIAL := &"mat_steel"

var result_lines: PackedStringArray = []


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var resolver: RefCounted = ForgeV2MaterialVolumeResolverScript.new()

	var handle := _make_body(
		&"handle",
		ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE,
		HANDLE_MATERIAL,
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING,
		Vector3.ZERO
	)
	var ordinary_replace := _make_body(
		&"ordinary_replace",
		ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE,
		ORDINARY_MATERIAL,
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING,
		Vector3.ZERO
	)
	var ordinary_empty := _make_body(
		&"ordinary_empty",
		ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE,
		ORDINARY_MATERIAL,
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY,
		Vector3(0.035, 0.0, 0.0)
	)
	var remove_body := _make_body(
		&"void",
		ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE,
		&"mat_void",
		ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING,
		Vector3.ZERO
	)
	var second_handle := _make_body(
		&"second_handle",
		ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE,
		SECOND_HANDLE_MATERIAL,
		ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL,
		ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING,
		Vector3.ZERO
	)

	if not _summary_has_only_material(
		resolver.call("build_usage_summary", [handle, ordinary_replace]),
		HANDLE_MATERIAL
	):
		_fail("later ordinary Replace Existing changed protected Handle cells")
		return
	_pass_line("later ordinary Replace Existing cannot change protected Handle cells")

	if not _summary_has_only_material(
		resolver.call("build_usage_summary", [ordinary_replace, handle]),
		HANDLE_MATERIAL
	):
		_fail("later Handle did not claim overlap from ordinary material")
		return
	_pass_line("Handle claims ordinary overlap independent of chronology")

	if not _summary_has_only_material(
		resolver.call("build_usage_summary", [handle, remove_body]),
		HANDLE_MATERIAL
	):
		_fail("VOID removed protected Handle cells")
		return
	_pass_line("VOID stops at protected Handle cells")

	var partial_empty_summary: Dictionary = resolver.call(
		"build_usage_summary",
		[handle, ordinary_empty]
	) as Dictionary
	if (
		not _summary_has_material(partial_empty_summary, HANDLE_MATERIAL)
		or not _summary_has_material(partial_empty_summary, ORDINARY_MATERIAL)
	):
		_fail("Empty Space Only did not preserve Handle and fill available outside cells")
		return
	_pass_line("Empty Space Only preserves Handle overlap and still fills outside it")

	if not _summary_has_only_material(
		resolver.call("build_usage_summary", [ordinary_replace, _duplicate_body_with_material(
			ordinary_replace,
			&"ordinary_replace_later",
			SECOND_HANDLE_MATERIAL
		)]),
		SECOND_HANDLE_MATERIAL
	):
		_fail("ordinary Replace Existing behavior outside Handle protection regressed")
		return
	_pass_line("ordinary Replace Existing behavior remains chronological outside Handles")

	if not _summary_is_empty(
		resolver.call("build_usage_summary", [ordinary_replace, remove_body])
	):
		_fail("VOID behavior outside Handle protection regressed")
		return
	_pass_line("VOID still removes ordinary material outside Handles")

	if not _summary_has_only_material(
		resolver.call("build_usage_summary", [handle, second_handle]),
		SECOND_HANDLE_MATERIAL
	):
		_fail("later Handle authoring could not mutate overlapping Handle cells")
		return
	_pass_line("later Handle authoring may overlap and extend Handle authority")

	var persisted_handle_record := _body_to_layer_record(handle)
	persisted_handle_record["operation_mode"] = (
		ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL
	)
	persisted_handle_record["placement_policy"] = (
		ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY
	)
	var persisted_layer: Resource = ForgeV2LayerDataScript.new()
	var persisted_input_records: Array[Dictionary] = []
	persisted_input_records.append(persisted_handle_record)
	persisted_layer.set("input_shape_records", persisted_input_records)
	var persisted_records: Array = persisted_layer.get("input_shape_records")
	persisted_records.append(_body_to_layer_record(ordinary_replace))
	var persisted_summary: Dictionary = resolver.call(
		"build_usage_summary",
		persisted_records
	) as Dictionary
	if not _summary_has_only_material(persisted_summary, HANDLE_MATERIAL):
		_fail(
			"persisted Dictionary Handle record lost semantic protection: %s"
			% str({"records": persisted_records, "summary": persisted_summary})
		)
		return
	_pass_line("persisted layer Dictionary records use body_kind as Handle authority")

	var authored_state: Resource = ForgeV2AuthoringStateScript.new()
	authored_state.call("reset_new_draft", "Protected Handle Verifier")
	authored_state.set(
		"active_operation_mode",
		ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL
	)
	authored_state.set(
		"placement_policy",
		ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY
	)
	authored_state.set(
		"spline_line_points",
		PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.2, 0.0)])
	)
	var authored_handle: Resource = authored_state.call(
		"_append_profile_extrusion_material_body",
		true
	) as Resource
	if (
		authored_handle == null
		or not ForgeV2MaterialCompositionPolicyScript.is_protected_handle_entry(
			authored_handle
		)
		or StringName(authored_handle.get("operation_mode"))
		!= ForgeV2VolumeStrokeScript.OPERATION_ADD_MATERIAL
		or StringName(authored_handle.get("placement_policy"))
		!= ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
	):
		_fail("new Handle profile inherited active VOID/Empty Space semantics")
		return
	_pass_line("new Handle profile authoring forces additive protected semantics")

	var presenter: Node = ForgeV2VolumePreviewPresenterScript.new()
	if not _visual_policy_matches(presenter, handle, ordinary_replace, remove_body, second_handle):
		presenter.free()
		return
	presenter.free()

	_pass()


func _visual_policy_matches(
	presenter: Node,
	handle: Resource,
	ordinary: Resource,
	remove_body: Resource,
	second_handle: Resource
) -> bool:
	var handle_then_ordinary: Array = [handle, ordinary]
	var handle_clips: Array = presenter.call(
		"_collect_csg_clip_bodies_for_add_body",
		handle_then_ordinary,
		0
	) as Array
	var ordinary_clips: Array = presenter.call(
		"_collect_csg_clip_bodies_for_add_body",
		handle_then_ordinary,
		1
	) as Array
	if not handle_clips.is_empty() or not ordinary_clips.has(handle):
		_fail("CSG visual policy disagreed with protected Handle chronology")
		return false

	var ordinary_then_handle: Array = [ordinary, handle]
	ordinary_clips = presenter.call(
		"_collect_csg_clip_bodies_for_add_body",
		ordinary_then_handle,
		0
	) as Array
	handle_clips = presenter.call(
		"_collect_csg_clip_bodies_for_add_body",
		ordinary_then_handle,
		1
	) as Array
	if not ordinary_clips.has(handle) or not handle_clips.is_empty():
		_fail("CSG Handle overlap ownership depended on body chronology")
		return false

	handle_clips = presenter.call(
		"_collect_csg_clip_bodies_for_add_body",
		[handle, remove_body],
		0
	) as Array
	if handle_clips.has(remove_body):
		_fail("CSG visual policy allowed VOID to clip protected Handle")
		return false

	handle_clips = presenter.call(
		"_collect_csg_clip_bodies_for_add_body",
		[handle, second_handle],
		0
	) as Array
	if not handle_clips.has(second_handle):
		_fail("CSG visual policy blocked later Handle authoring overlap")
		return false

	_pass_line("CSG visual clipping matches protected Handle accounting")
	return true


func _make_body(
	body_id: StringName,
	body_kind: StringName,
	material_variant_id: StringName,
	operation_mode: StringName,
	placement_policy: StringName,
	center: Vector3
) -> Resource:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	body.set("body_id", body_id)
	body.set("source_record_id", body_id)
	body.set("body_kind", body_kind)
	body.set("material_variant_id", material_variant_id)
	body.set("operation_mode", operation_mode)
	body.set("placement_policy", placement_policy)
	body.set("shape_kind", ForgeV2MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH)
	body.set("path_points", PackedVector3Array([center]))
	body.set("path_surface_normals", PackedVector3Array([Vector3.UP]))
	body.set("radius_meters", 0.03)
	body.call("normalize")
	return body


func _duplicate_body_with_material(
	body: Resource,
	body_id: StringName,
	material_variant_id: StringName
) -> Resource:
	return _make_body(
		body_id,
		StringName(body.get("body_kind")),
		material_variant_id,
		StringName(body.get("operation_mode")),
		StringName(body.get("placement_policy")),
		(body.get("path_points") as PackedVector3Array)[0]
	)


func _body_to_layer_record(body: Resource) -> Dictionary:
	return {
		"body_id": StringName(body.get("body_id")),
		"body_kind": StringName(body.get("body_kind")),
		"material_variant_id": StringName(body.get("material_variant_id")),
		"operation_mode": StringName(body.get("operation_mode")),
		"placement_policy": StringName(body.get("placement_policy")),
		"shape_kind": StringName(body.get("shape_kind")),
		"path_points": body.get("path_points"),
		"path_surface_normals": body.get("path_surface_normals"),
		"radius_meters": float(body.get("radius_meters")),
		"layer_active": true,
	}


func _summary_has_material(summary_variant: Variant, material_id: StringName) -> bool:
	var summary: Dictionary = summary_variant as Dictionary
	var materials: Dictionary = summary.get("materials", {}) as Dictionary
	return (
		materials.has(material_id)
		and float((materials[material_id] as Dictionary).get(
			"rough_volume_cell_equivalents",
			0.0
		)) > 0.0
	)


func _summary_has_only_material(
	summary_variant: Variant,
	material_id: StringName
) -> bool:
	var summary: Dictionary = summary_variant as Dictionary
	var materials: Dictionary = summary.get("materials", {}) as Dictionary
	return materials.size() == 1 and _summary_has_material(summary, material_id)


func _summary_is_empty(summary_variant: Variant) -> bool:
	var summary: Dictionary = summary_variant as Dictionary
	return (
		(summary.get("materials", {}) as Dictionary).is_empty()
		and float(summary.get("total_rough_volume_cell_equivalents", -1.0))
		<= 0.0
	)


func _pass_line(message: String) -> void:
	result_lines.append("PASS: %s" % message)


func _pass() -> void:
	result_lines.append("ok=true")
	_write_result()
	print("Forge V2 protected Handle composition verifier passed")
	quit(0)


func _fail(message: String) -> void:
	result_lines.append("FAIL: %s" % message)
	result_lines.append("ok=false")
	_write_result()
	push_error(message)
	quit(1)


func _write_result() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(result_lines) + "\n")
