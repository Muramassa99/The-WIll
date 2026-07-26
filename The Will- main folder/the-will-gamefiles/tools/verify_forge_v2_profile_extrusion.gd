extends SceneTree

const ForgeV2AuthoringStateScript = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const ForgeV2MaterialBodyScript = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const ForgeV2ProfileShapeLibraryScript = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")

const RESULT_PATH := "C:/WORKSPACE/godot_runs/verify_forge_v2_profile_extrusion_2026-06-27.txt"

var result_lines: PackedStringArray = []

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var handle_profiles: Array[Dictionary] = ForgeV2ProfileShapeLibraryScript.build_handle_profile_entries()
	if handle_profiles.is_empty():
		_fail("no handle profiles resolved from stage 1 profile library")
		return
	var profile_id: StringName = StringName(handle_profiles[0].get("id", StringName()))
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Forge V2 Profile Extrusion Verify")
	state.call("set_active_tool_id", ForgeV2AuthoringStateScript.TOOL_HANDLES)
	state.call("set_active_profile_id", profile_id)
	state.call("append_spline_line_point", Vector3(0.0, 0.0, 0.0))
	state.call("append_spline_line_point", Vector3(0.14, 0.0, 0.03))
	state.call("append_spline_line_point", Vector3(0.30, 0.0, 0.0))
	var generated := bool(state.call("generate_profile_extrusion_from_spline"))
	if not generated:
		_fail("handle profile extrusion did not generate")
		return
	var body: Resource = state.call("get_selected_material_body") as Resource
	if body == null:
		_fail("generated handle body was not selected")
		return
	if StringName(body.get("body_kind")) != ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE:
		_fail("generated body was not marked as handle profile")
		return
	if StringName(body.get("shape_kind")) != ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH:
		_fail("generated body was not marked as spline profile path")
		return
	var profile_polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	if profile_polygon.size() < 3:
		_fail("generated body did not carry profile polygon data")
		return
	var usage_summary: Dictionary = state.call("get_material_usage_summary") as Dictionary
	if float(usage_summary.get("total_rough_volume_cell_equivalents", 0.0)) <= 0.0:
		_fail("profile body did not contribute occupied material volume")
		return
	var body_id: StringName = StringName(body.get("body_id"))
	var committed_layer: Resource = state.call("commit_material_body_as_layer", body_id) as Resource
	if committed_layer == null:
		_fail("profile body did not commit as a layer")
		return
	var layer_records: Array = committed_layer.get("input_shape_records") as Array
	if layer_records.is_empty():
		_fail("committed layer did not retain input shape records")
		return
	var layer_record: Dictionary = layer_records[0] as Dictionary
	if StringName(layer_record.get("profile_id", StringName())) != profile_id:
		_fail("committed layer did not retain profile id")
		return
	result_lines.append("ok=true")
	result_lines.append("profile_id=%s" % String(profile_id))
	result_lines.append("profile_points=%d" % profile_polygon.size())
	result_lines.append("body_kind=%s" % String(body.get("body_kind")))
	result_lines.append("shape_kind=%s" % String(body.get("shape_kind")))
	result_lines.append("volume_cell_equivalents=%.3f" % float(body.get("rough_volume_cell_equivalents")))
	result_lines.append("layer_record_profile_id=%s" % String(layer_record.get("profile_id", StringName())))
	_write_results()
	quit(0)

func _fail(message: String) -> void:
	result_lines.append("ok=false")
	result_lines.append("error=%s" % message)
	_write_results()
	push_error(message)
	quit(1)

func _write_results() -> void:
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(result_lines))
		file.close()
