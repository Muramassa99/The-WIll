extends SceneTree

const ForgeV2AuthoringStateScript = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const ForgeV2MaterialBodyScript = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const ForgeV2ProfileShapeLibraryScript = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const PlayerToolProfileLibraryStateScript = preload("res://core/models/player_tool_profile_library_state.gd")

const RESULT_PATH := "C:/WORKSPACE/godot_runs/verify_forge_v2_handle_builder_profiles_2026-07-05.txt"
const LIBRARY_PATH_PREFIX := "C:/WORKSPACE/godot_runs/verify_handle_builder_profile_library_state"
const EPSILON := 0.00001

var result_lines: PackedStringArray = []

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var state: Resource = _build_handle_state()
	var summary: Dictionary = state.call("get_status_summary") as Dictionary
	var profile_settings: Dictionary = summary.get("active_profile_settings", {}) as Dictionary
	var handle_settings: Dictionary = profile_settings.get("handle_builder", {}) as Dictionary
	if not bool(handle_settings.get("is_active", false)):
		_fail("handle builder was not active")
		return
	if int(handle_settings.get("face_count", 0)) != ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_RECTANGLE:
		_fail("default handle builder face count was not 4")
		return
	var default_polygon: PackedVector2Array = profile_settings.get("preview_polygon_2d_meters", PackedVector2Array())
	if default_polygon.size() <= 4:
		_fail("default rounded handle polygon did not add corner samples")
		return
	var guide_polygon: PackedVector2Array = handle_settings.get("guide_polygon_2d_meters", PackedVector2Array())
	var guide_grid_segments: Array = handle_settings.get("guide_grid_segments_2d_meters", [])
	var guide_snap_points: PackedVector2Array = handle_settings.get("guide_grid_snap_points_2d_meters", PackedVector2Array())
	var guide_bounds := ForgeV2ProfileShapeLibraryScript.calculate_polygon_bounds(guide_polygon)
	if guide_polygon.size() < 8:
		_fail("Hex 24 guide polygon was not present")
		return
	if not is_equal_approx(guide_bounds.size.x, 0.075) or not is_equal_approx(guide_bounds.size.y, 0.075):
		_fail("Hex 24 guide was not at the expected 0.075m scale")
		return
	if guide_grid_segments.is_empty() or guide_snap_points.is_empty():
		_fail("Hex 24 guide grid data was not generated")
		return

	state.call("set_active_handle_grid_snapping_enabled", false)
	state.call("set_active_handle_rounding_enabled", false)
	state.call("set_active_profile_rotation_degrees", 0.0)
	summary = state.call("get_status_summary") as Dictionary
	profile_settings = summary.get("active_profile_settings", {}) as Dictionary
	handle_settings = profile_settings.get("handle_builder", {}) as Dictionary
	var original_control_points: PackedVector2Array = handle_settings.get("control_points_2d_meters", PackedVector2Array())
	var moved_point := Vector2(-0.02, -0.02)
	state.call("set_active_handle_control_point_2d_meters", 0, moved_point)
	summary = state.call("get_status_summary") as Dictionary
	profile_settings = summary.get("active_profile_settings", {}) as Dictionary
	handle_settings = profile_settings.get("handle_builder", {}) as Dictionary
	var edited_control_points: PackedVector2Array = handle_settings.get("control_points_2d_meters", PackedVector2Array())
	if edited_control_points.size() != original_control_points.size():
		_fail("moving one handle control point changed the control point count")
		return
	if edited_control_points[0].distance_to(moved_point) > EPSILON:
		_fail("moved handle control point did not stay where it was placed")
		return
	for point_index in range(1, edited_control_points.size()):
		if edited_control_points[point_index].distance_to(original_control_points[point_index]) > EPSILON:
			_fail("moving one handle control point displaced another control point")
			return
	if not _packed_points_match(
		profile_settings.get("preview_polygon_2d_meters", PackedVector2Array()),
		edited_control_points
	):
		_fail("unrounded handle polygon did not follow its yellow control points")
		return

	var anchor_local := Vector2(0.005, 0.0)
	state.call("set_active_profile_anchor_2d_meters", anchor_local)
	summary = state.call("get_status_summary") as Dictionary
	profile_settings = summary.get("active_profile_settings", {}) as Dictionary
	handle_settings = profile_settings.get("handle_builder", {}) as Dictionary
	if _preview_anchor(profile_settings).distance_to(anchor_local) > EPSILON:
		_fail("handle anchor did not stay at the requested unrotated position")
		return
	if (handle_settings.get("base_anchor_2d_meters", Vector2.ZERO) as Vector2).distance_to(anchor_local) > EPSILON:
		_fail("handle anchor local storage did not match the requested unrotated position")
		return

	state.call("set_active_profile_rotation_degrees", 90.0)
	summary = state.call("get_status_summary") as Dictionary
	profile_settings = summary.get("active_profile_settings", {}) as Dictionary
	handle_settings = profile_settings.get("handle_builder", {}) as Dictionary
	var rotated_control_points: PackedVector2Array = handle_settings.get("control_points_2d_meters", PackedVector2Array())
	var expected_rotated_control_points := _rotate_points(edited_control_points, 90.0)
	if not _packed_points_match(rotated_control_points, expected_rotated_control_points):
		_fail("handle control points did not rotate with the profile")
		return
	if not _packed_points_match(
		profile_settings.get("preview_polygon_2d_meters", PackedVector2Array()),
		expected_rotated_control_points
	):
		_fail("unrounded blue handle polygon did not rotate with its yellow points")
		return
	var expected_rotated_anchor := anchor_local.rotated(deg_to_rad(90.0))
	if _preview_anchor(profile_settings).distance_to(expected_rotated_anchor) > EPSILON:
		_fail("red handle anchor did not rotate with the profile")
		return
	if not _packed_points_match(
		handle_settings.get("guide_polygon_2d_meters", PackedVector2Array()),
		_rotate_points(guide_polygon, 90.0)
	):
		_fail("Hex 24 guide polygon did not rotate with the profile")
		return
	var rotated_guide_snap_points: PackedVector2Array = handle_settings.get("guide_grid_snap_points_2d_meters", PackedVector2Array())
	if rotated_guide_snap_points.size() != guide_snap_points.size():
		_fail("rotated Hex 24 guide snap point count changed")
		return
	if rotated_guide_snap_points.size() > 0 and rotated_guide_snap_points[0].distance_to(guide_snap_points[0].rotated(deg_to_rad(90.0))) > EPSILON:
		_fail("Hex 24 guide snap points did not rotate with the profile")
		return

	var rotated_polygon_before_anchor_drag: PackedVector2Array = profile_settings.get("preview_polygon_2d_meters", PackedVector2Array())
	var dragged_anchor_local := Vector2(0.0, 0.005)
	var dragged_anchor_preview := dragged_anchor_local.rotated(deg_to_rad(90.0))
	state.call("set_active_profile_anchor_2d_meters", dragged_anchor_preview)
	summary = state.call("get_status_summary") as Dictionary
	profile_settings = summary.get("active_profile_settings", {}) as Dictionary
	handle_settings = profile_settings.get("handle_builder", {}) as Dictionary
	if not _packed_points_match(
		profile_settings.get("preview_polygon_2d_meters", PackedVector2Array()),
		rotated_polygon_before_anchor_drag
	):
		_fail("moving the red handle anchor changed the blue handle shape")
		return
	if _preview_anchor(profile_settings).distance_to(dragged_anchor_preview) > EPSILON:
		_fail("dragging the red handle anchor in rotated view did not keep the visible position")
		return
	if (handle_settings.get("base_anchor_2d_meters", Vector2.ZERO) as Vector2).distance_to(dragged_anchor_local) > EPSILON:
		_fail("dragging the red handle anchor in rotated view did not store the local anchor")
		return

	state.call("reset_active_profile_anchor_to_center")
	summary = state.call("get_status_summary") as Dictionary
	profile_settings = summary.get("active_profile_settings", {}) as Dictionary
	var expected_center := _bounds_center(edited_control_points).rotated(deg_to_rad(90.0))
	if _preview_anchor(profile_settings).distance_to(expected_center) > EPSILON:
		_fail("resetting the red handle anchor did not return it to the rotated shape center")
		return

	state.call("set_active_handle_grid_snapping_enabled", true)
	state.call("set_active_profile_anchor_2d_meters", Vector2(1.0, 1.0))
	summary = state.call("get_status_summary") as Dictionary
	profile_settings = summary.get("active_profile_settings", {}) as Dictionary
	handle_settings = profile_settings.get("handle_builder", {}) as Dictionary
	if not bool(handle_settings.get("grid_snapping_enabled", false)):
		_fail("handle grid snapping did not enable")
		return
	if not _point_inside_or_on_polygon(
		_preview_anchor(profile_settings),
		profile_settings.get("preview_polygon_2d_meters", PackedVector2Array())
	):
		_fail("handle anchor escaped the blue profile while grid snapping")
		return
	state.call("set_active_handle_control_point_2d_meters", 0, Vector2(1.0, 1.0))
	summary = state.call("get_status_summary") as Dictionary
	profile_settings = summary.get("active_profile_settings", {}) as Dictionary
	handle_settings = profile_settings.get("handle_builder", {}) as Dictionary
	var constrained_default_points: PackedVector2Array = handle_settings.get("control_points_2d_meters", PackedVector2Array())
	var current_guide_polygon: PackedVector2Array = handle_settings.get("guide_polygon_2d_meters", PackedVector2Array())
	for point: Vector2 in constrained_default_points:
		if point.distance_to(ForgeV2ProfileShapeLibraryScript.clamp_point_to_polygon(point, current_guide_polygon)) > EPSILON:
			_fail("handle control point escaped rotated Hex 24 guide")
			return

	var profile_state: Resource = _build_handle_state()
	profile_state.call("set_active_handle_grid_snapping_enabled", false)
	profile_state.call("set_active_handle_face_count", ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_OCTAGON)
	profile_state.call("set_active_handle_control_point_2d_meters", 0, Vector2(-0.018, -0.026))
	profile_state.call("set_active_handle_corner_radius_meters", 99.0)
	summary = profile_state.call("get_status_summary") as Dictionary
	profile_settings = summary.get("active_profile_settings", {}) as Dictionary
	handle_settings = profile_settings.get("handle_builder", {}) as Dictionary
	if int(handle_settings.get("face_count", 0)) != ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_OCTAGON:
		_fail("handle builder face count did not switch to 8")
		return
	var control_points: PackedVector2Array = handle_settings.get("control_points_2d_meters", PackedVector2Array())
	if control_points.size() != ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_OCTAGON:
		_fail("handle builder control point count was not 8")
		return
	var corner_radius := float(handle_settings.get("corner_radius_meters", -1.0))
	var corner_radius_max := float(handle_settings.get("corner_radius_max_meters", 0.0))
	if corner_radius < 0.0 or corner_radius > corner_radius_max + 0.000001:
		_fail("handle builder corner radius did not clamp to shortest-side max")
		return
	var library_path := "%s_%s.tres" % [
		LIBRARY_PATH_PREFIX,
		str(Time.get_unix_time_from_system()).replace(".", "_")
	]
	var profile_library: Resource = PlayerToolProfileLibraryStateScript.new()
	profile_library.set("save_file_path", library_path)
	var preset_data: Dictionary = profile_state.call("build_active_tool_profile_preset_data", "") as Dictionary
	var saved_first: Dictionary = profile_library.call("save_profile", preset_data, "") as Dictionary
	var saved_second: Dictionary = profile_library.call("save_profile", preset_data, "") as Dictionary
	if String(saved_first.get("label", "")) != "handle profile 1":
		_fail("first default saved handle profile name was not handle profile 1")
		return
	if String(saved_second.get("label", "")) != "handle profile 2":
		_fail("second default saved handle profile name was not handle profile 2")
		return
	if not bool(profile_library.call("remove_profile", StringName(saved_first.get("profile_id", StringName())))):
		_fail("first saved handle profile did not remove")
		return
	var saved_third: Dictionary = profile_library.call("save_profile", preset_data, "") as Dictionary
	if String(saved_third.get("label", "")) != "handle profile 1":
		_fail("default saved handle profile did not reuse removed profile 1 name")
		return
	if not bool(profile_state.call("apply_tool_profile_preset", saved_first)):
		_fail("saved handle profile did not apply")
		return
	var generated_anchor_local := Vector2(0.004, 0.0)
	profile_state.call("set_active_profile_anchor_2d_meters", generated_anchor_local)
	profile_state.call("set_active_profile_rotation_degrees", 90.0)
	profile_state.call("append_spline_line_point", Vector3(0.0, 0.0, 0.0))
	profile_state.call("append_spline_line_point", Vector3(0.15, 0.0, 0.025))
	profile_state.call("append_spline_line_point", Vector3(0.32, 0.0, 0.0))
	if not bool(profile_state.call("generate_profile_extrusion_from_spline")):
		_fail("handle builder profile extrusion did not generate")
		return
	var body: Resource = profile_state.call("get_selected_material_body") as Resource
	if body == null:
		_fail("generated handle builder body was not selected")
		return
	if StringName(body.get("body_kind")) != ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE:
		_fail("generated handle builder body was not marked as handle profile")
		return
	var body_polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	if body_polygon.size() <= control_points.size():
		_fail("generated handle builder body did not retain rounded polygon")
		return
	var body_anchor: Vector2 = body.get("profile_anchor_2d_meters")
	if body_anchor.distance_to(generated_anchor_local.rotated(deg_to_rad(90.0))) > EPSILON:
		_fail("generated handle builder body did not keep the rotated red anchor")
		return
	result_lines.append("ok=true")
	result_lines.append("default_polygon_points=%d" % default_polygon.size())
	result_lines.append("guide_size=%.5fx%.5f" % [guide_bounds.size.x, guide_bounds.size.y])
	result_lines.append("guide_grid_segments=%d" % guide_grid_segments.size())
	result_lines.append("guide_snap_points=%d" % guide_snap_points.size())
	result_lines.append("moved_point_preserved=true")
	result_lines.append("rotation_rotates_blue_yellow_red=true")
	result_lines.append("anchor_drag_keeps_shape=true")
	result_lines.append("anchor_reset_center=true")
	result_lines.append("guide_rotates_with_profile=true")
	result_lines.append("control_points=%d" % control_points.size())
	result_lines.append("corner_radius=%.5f" % corner_radius)
	result_lines.append("corner_radius_max=%.5f" % corner_radius_max)
	result_lines.append("saved_first=%s" % String(saved_first.get("label", "")))
	result_lines.append("saved_second=%s" % String(saved_second.get("label", "")))
	result_lines.append("saved_third=%s" % String(saved_third.get("label", "")))
	result_lines.append("library_path=%s" % library_path)
	result_lines.append("body_polygon_points=%d" % body_polygon.size())
	result_lines.append("body_anchor=%.5f,%.5f" % [body_anchor.x, body_anchor.y])
	_write_results()
	quit(0)

func _build_handle_state() -> Resource:
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Forge V2 Handle Builder Verify")
	state.call("set_active_tool_id", ForgeV2AuthoringStateScript.TOOL_HANDLES)
	state.call("set_active_profile_id", ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER)
	return state

func _preview_anchor(profile_settings: Dictionary) -> Vector2:
	return Vector2(
		float(profile_settings.get("anchor_x_meters", 0.0)),
		float(profile_settings.get("anchor_y_meters", 0.0))
	)

func _packed_points_match(first_points: PackedVector2Array, second_points: PackedVector2Array) -> bool:
	if first_points.size() != second_points.size():
		return false
	for point_index in range(first_points.size()):
		if first_points[point_index].distance_to(second_points[point_index]) > EPSILON:
			return false
	return true

func _rotate_points(points: PackedVector2Array, rotation_degrees: float) -> PackedVector2Array:
	var rotated := PackedVector2Array()
	for point: Vector2 in points:
		rotated.append(point.rotated(deg_to_rad(rotation_degrees)))
	return rotated

func _bounds_center(points: PackedVector2Array) -> Vector2:
	var bounds := ForgeV2ProfileShapeLibraryScript.calculate_polygon_bounds(points)
	return bounds.position + bounds.size * 0.5

func _point_inside_or_on_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	return point.distance_to(ForgeV2ProfileShapeLibraryScript.clamp_point_to_polygon(point, polygon)) <= EPSILON

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
