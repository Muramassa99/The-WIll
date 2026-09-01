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
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const PlayerToolProfileLibraryStateScript = preload(
	"res://core/models/player_tool_profile_library_state.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_katana_spline_commit_orientation_2026-08-31.txt"
)
const STATE_PATH_PREFIX := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_katana_spline_commit_orientation_state"
)
const KATANA_PROFILE_LABEL := "katana_blade_body"
const POSITION_EPSILON := 0.0002
const PLANE_EPSILON := 0.0002


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var profile_library: Resource = ResourceLoader.load(
		PlayerToolProfileLibraryStateScript.DEFAULT_SAVE_FILE_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Resource
	if profile_library == null:
		_fail("saved profile library could not be loaded")
		return
	var katana_profile := _find_katana_profile(profile_library)
	if katana_profile.is_empty():
		_fail("Katana saved Basic profile was not found")
		return
	if not ForgeV2ProfileShapeLibraryScript.is_compiled_basic_profile_runtime_valid(
		katana_profile
	):
		_fail("Katana saved Basic profile runtime data was invalid")
		return

	# A straight witness makes the intentional A/B draw-order reversal exactly
	# comparable. The curved witnesses exercise the real three-point workflow;
	# each must independently retain its pending orientation through commit and
	# disk reload.
	var point_a := Vector3.ZERO
	var point_b := Vector3(0.4, 0.0, 0.0)
	var forward := await _verify_ordered_case(
		&"forward",
		katana_profile,
		PackedVector3Array([point_a, point_b])
	)
	if not bool(forward.get("ok", false)):
		_fail(String(forward.get("error", "forward case failed")))
		return
	var reverse := await _verify_ordered_case(
		&"reverse",
		katana_profile,
		PackedVector3Array([point_b, point_a])
	)
	if not bool(reverse.get("ok", false)):
		_fail(String(reverse.get("error", "reverse case failed")))
		return

	var forward_axis_x := forward.get("axis_x", Vector3.ZERO) as Vector3
	var forward_axis_y := forward.get("axis_y", Vector3.ZERO) as Vector3
	var reverse_axis_x := reverse.get("axis_x", Vector3.ZERO) as Vector3
	var reverse_axis_y := reverse.get("axis_y", Vector3.ZERO) as Vector3
	if (
		forward_axis_x.dot(reverse_axis_x) > -0.999
		or forward_axis_y.dot(reverse_axis_y) < 0.999
	):
		_fail("forward/reverse authored A/B handedness was not retained")
		return

	var curve_a := Vector3(-0.32, -0.04, 0.01)
	var curve_b := Vector3(0.02, 0.08, -0.02)
	var curve_c := Vector3(0.38, -0.09, 0.03)
	var curved_forward := await _verify_ordered_case(
		&"curved_forward",
		katana_profile,
		PackedVector3Array([curve_a, curve_b, curve_c])
	)
	if not bool(curved_forward.get("ok", false)):
		_fail(String(curved_forward.get("error", "curved forward case failed")))
		return
	var curved_reverse := await _verify_ordered_case(
		&"curved_reverse",
		katana_profile,
		PackedVector3Array([curve_c, curve_b, curve_a])
	)
	if not bool(curved_reverse.get("ok", false)):
		_fail(String(curved_reverse.get("error", "curved reverse case failed")))
		return

	_write_result([
		"ok=true",
		"profile_label=%s" % String(katana_profile.get("label", "")),
		"profile_id=%s" % String(katana_profile.get("profile_id", StringName())),
		"profile_point_count=%d" % int(forward.get("profile_point_count", 0)),
		"forward_pending_mapping=%s" % String(forward.get("pending_mapping", StringName())),
		"forward_committed_mapping=%s" % String(forward.get("committed_mapping", StringName())),
		"forward_reloaded_mapping=%s" % String(forward.get("reloaded_mapping", StringName())),
		"reverse_pending_mapping=%s" % String(reverse.get("pending_mapping", StringName())),
		"reverse_committed_mapping=%s" % String(reverse.get("committed_mapping", StringName())),
		"reverse_reloaded_mapping=%s" % String(reverse.get("reloaded_mapping", StringName())),
		"curved_forward_pending_mapping=%s" % String(curved_forward.get("pending_mapping", StringName())),
		"curved_forward_committed_mapping=%s" % String(curved_forward.get("committed_mapping", StringName())),
		"curved_forward_reloaded_mapping=%s" % String(curved_forward.get("reloaded_mapping", StringName())),
		"curved_reverse_pending_mapping=%s" % String(curved_reverse.get("pending_mapping", StringName())),
		"curved_reverse_committed_mapping=%s" % String(curved_reverse.get("committed_mapping", StringName())),
		"curved_reverse_reloaded_mapping=%s" % String(curved_reverse.get("reloaded_mapping", StringName())),
		"forward_reverse_axis_x_dot=%.6f" % forward_axis_x.dot(reverse_axis_x),
		"forward_reverse_axis_y_dot=%.6f" % forward_axis_y.dot(reverse_axis_y),
		"commit_preserved_body_data=true",
		"disk_roundtrip_preserved_orientation=true",
	])
	quit(0)


func _verify_ordered_case(
	case_id: StringName,
	profile: Dictionary,
	ordered_points: PackedVector3Array
) -> Dictionary:
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Katana Spline Orientation %s" % String(case_id))
	if not bool(state.call("select_active_saved_basic_profile", profile)):
		return {"ok": false, "error": "%s Katana profile selection failed" % String(case_id)}
	state.call("set_active_tool_id", ForgeV2AuthoringStateScript.TOOL_SPLINE_LINE)
	for point: Vector3 in ordered_points:
		if int(state.call("append_spline_line_point", point, Vector3.UP)) < 0:
			return {"ok": false, "error": "%s spline point append failed" % String(case_id)}
	if not bool(state.call("generate_spline_line_csg_noodle")):
		return {"ok": false, "error": "%s CSG noodle generation failed" % String(case_id)}
	var body: Resource = state.call("get_selected_material_body") as Resource
	if body == null:
		return {"ok": false, "error": "%s pending body missing" % String(case_id)}
	if (
		StringName(body.get("shape_kind"))
		!= ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
		or String(body.get("profile_display_name")) != KATANA_PROFILE_LABEL
	):
		return {"ok": false, "error": "%s did not generate the Katana spline profile" % String(case_id)}

	var path_before := (
		body.get("path_points") as PackedVector3Array
	).duplicate()
	var normals_before := (
		body.get("path_surface_normals") as PackedVector3Array
	).duplicate()
	var polygon_before := (
		body.get("profile_polygon_2d_meters") as PackedVector2Array
	).duplicate()
	var body_id := StringName(body.get("body_id"))
	var tangent := (path_before[1] - path_before[0]).normalized()
	var frame := ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
		tangent,
		normals_before[0],
		body.get("profile_contact_direction_2d") as Vector2,
		float(body.get("profile_rotation_bias_degrees"))
	)
	var axis_x := frame.get("axis_x", Vector3.ZERO) as Vector3
	var axis_y := frame.get("axis_y", Vector3.ZERO) as Vector3
	if axis_x.length_squared() < 0.9 or axis_y.length_squared() < 0.9:
		return {"ok": false, "error": "%s pending frame was degenerate" % String(case_id)}

	var presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	root.add_child(presenter)
	var pending_mesh := presenter.call(
		"_build_active_material_body_sweep_mesh",
		body
	) as ArrayMesh
	var pending_coordinates := _collect_profile_coordinates_at_plane(
		pending_mesh,
		path_before[0],
		tangent,
		axis_x,
		axis_y
	)
	var pending_mapping := _classify_endpoint_mapping(
		pending_mesh,
		path_before[0],
		tangent,
		axis_x,
		axis_y,
		polygon_before
	)
	if pending_mapping != &"same_xy":
		var pending_exact := _profile_vertex_set_matches(
			pending_coordinates,
			polygon_before
		)
		return {
			"ok": false,
			"error": (
				"%s pending Katana mapping was %s (direct_match=%s actual=%d expected=%d nearest=%s actual_points=%s expected_points=%s)"
				% [
					String(case_id),
					String(pending_mapping),
					str(pending_exact),
					pending_coordinates.size(),
					polygon_before.size(),
					_build_nearest_distance_report(pending_coordinates, polygon_before),
					str(pending_coordinates),
					str(polygon_before),
				]
			),
		}

	var committed_layer: Resource = state.call(
		"commit_pending_material_bodies_as_layer"
	) as Resource
	if committed_layer == null:
		return {"ok": false, "error": "%s direct commit failed" % String(case_id)}
	if (
		StringName(body.get("committed_layer_id")) == StringName()
		or (body.get("path_points") as PackedVector3Array) != path_before
		or (body.get("path_surface_normals") as PackedVector3Array) != normals_before
		or (body.get("profile_polygon_2d_meters") as PackedVector2Array) != polygon_before
	):
		return {"ok": false, "error": "%s commit mutated authored body data" % String(case_id)}
	var committed_mapping := await _build_static_mapping(
		presenter,
		body,
		path_before[0],
		tangent,
		axis_x,
		axis_y,
		polygon_before,
		"%s committed" % String(case_id)
	)
	if committed_mapping != pending_mapping:
		return {"ok": false, "error": "%s commit changed Katana orientation from %s to %s" % [String(case_id), String(pending_mapping), String(committed_mapping)]}

	var state_path := "%s_%s.tres" % [STATE_PATH_PREFIX, String(case_id)]
	if ResourceSaver.save(state, state_path) != OK:
		return {"ok": false, "error": "%s state save failed" % String(case_id)}
	var reloaded_state: Resource = ResourceLoader.load(
		state_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Resource
	if reloaded_state == null:
		return {"ok": false, "error": "%s state reload failed" % String(case_id)}
	var reloaded_body := _find_body(reloaded_state, body_id)
	if reloaded_body == null:
		return {"ok": false, "error": "%s reloaded committed body missing" % String(case_id)}
	if (
		(reloaded_body.get("path_points") as PackedVector3Array) != path_before
		or (reloaded_body.get("path_surface_normals") as PackedVector3Array) != normals_before
		or (reloaded_body.get("profile_polygon_2d_meters") as PackedVector2Array) != polygon_before
	):
		return {"ok": false, "error": "%s disk roundtrip mutated authored body data" % String(case_id)}
	var reloaded_mapping := await _build_static_mapping(
		presenter,
		reloaded_body,
		path_before[0],
		tangent,
		axis_x,
		axis_y,
		polygon_before,
		"%s reloaded" % String(case_id)
	)
	if reloaded_mapping != pending_mapping:
		return {"ok": false, "error": "%s disk roundtrip changed Katana orientation from %s to %s" % [String(case_id), String(pending_mapping), String(reloaded_mapping)]}

	presenter.queue_free()
	return {
		"ok": true,
		"axis_x": axis_x,
		"axis_y": axis_y,
		"profile_point_count": polygon_before.size(),
		"pending_mapping": pending_mapping,
		"committed_mapping": committed_mapping,
		"reloaded_mapping": reloaded_mapping,
	}


func _build_static_mapping(
	presenter: Node3D,
	body: Resource,
	plane_origin: Vector3,
	tangent: Vector3,
	axis_x: Vector3,
	axis_y: Vector3,
	authored_polygon: PackedVector2Array,
	context: String
) -> StringName:
	var csg_root := Node3D.new()
	csg_root.name = "KatanaStatic_%s" % context.replace(" ", "_")
	root.add_child(csg_root)
	if not bool(presenter.call(
		"_append_csg_body_shape",
		csg_root,
		body,
		StringName(body.get("material_variant_id")),
		false,
		0
	)):
		csg_root.queue_free()
		return StringName()
	await process_frame
	await process_frame
	var csg_polygon := _find_csg_polygon(csg_root)
	if csg_polygon == null:
		csg_root.queue_free()
		return StringName()
	var mesh := csg_polygon.bake_static_mesh()
	var mapping := _classify_endpoint_mapping(
		mesh,
		plane_origin,
		tangent,
		axis_x,
		axis_y,
		authored_polygon
	)
	csg_root.queue_free()
	return mapping


func _find_katana_profile(profile_library: Resource) -> Dictionary:
	if profile_library == null or not profile_library.has_method("get_saved_profiles"):
		return {}
	var fallback: Dictionary = {}
	var profiles: Array = profile_library.call(
		"get_saved_profiles",
		ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC
	) as Array
	for profile_variant: Variant in profiles:
		var profile := profile_variant as Dictionary
		var label := String(profile.get("label", "")).strip_edges().to_lower()
		if label == KATANA_PROFILE_LABEL:
			return profile.duplicate(true)
		if fallback.is_empty() and label.contains("katana"):
			fallback = profile.duplicate(true)
	return fallback


func _find_body(state: Resource, body_id: StringName) -> Resource:
	if state == null:
		return null
	var bodies: Array = state.get("material_bodies") as Array
	for body_variant: Variant in bodies:
		var body := body_variant as Resource
		if body != null and StringName(body.get("body_id")) == body_id:
			return body
	return null


func _classify_endpoint_mapping(
	mesh: Mesh,
	plane_origin: Vector3,
	path_tangent: Vector3,
	axis_x: Vector3,
	axis_y: Vector3,
	authored_polygon: PackedVector2Array
) -> StringName:
	if mesh == null:
		return StringName()
	var actual_coordinates := _collect_profile_coordinates_at_plane(
		mesh,
		plane_origin,
		path_tangent,
		axis_x,
		axis_y
	)
	var candidates: Array[Dictionary] = [
		{"id": &"same_xy", "scale": Vector2(1.0, 1.0)},
		{"id": &"mirror_x", "scale": Vector2(-1.0, 1.0)},
		{"id": &"mirror_y", "scale": Vector2(1.0, -1.0)},
		{"id": &"rotate_180", "scale": Vector2(-1.0, -1.0)},
	]
	for candidate: Dictionary in candidates:
		var scale := candidate.get("scale", Vector2.ONE) as Vector2
		var expected := PackedVector2Array()
		for point: Vector2 in authored_polygon:
			expected.append(point * scale)
		if _profile_vertex_set_matches(actual_coordinates, expected):
			return StringName(candidate.get("id", StringName()))
	return StringName()


func _collect_profile_coordinates_at_plane(
	mesh: Mesh,
	plane_origin: Vector3,
	path_tangent: Vector3,
	axis_x: Vector3,
	axis_y: Vector3
) -> PackedVector2Array:
	var result := PackedVector2Array()
	for surface_index in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			var offset := vertex - plane_origin
			if absf(offset.dot(path_tangent)) > PLANE_EPSILON:
				continue
			_append_unique_vector2(
				result,
				Vector2(offset.dot(axis_x), offset.dot(axis_y))
			)
	return result


func _profile_vertex_set_matches(
	actual_coordinates: PackedVector2Array,
	expected_polygon: PackedVector2Array
) -> bool:
	if actual_coordinates.is_empty() or expected_polygon.is_empty():
		return false
	for expected_point: Vector2 in expected_polygon:
		var found := false
		for actual_point: Vector2 in actual_coordinates:
			if actual_point.distance_to(expected_point) <= POSITION_EPSILON:
				found = true
				break
		if not found:
			return false
	return true


func _build_nearest_distance_report(
	actual_coordinates: PackedVector2Array,
	expected_polygon: PackedVector2Array
) -> String:
	var entries := PackedStringArray()
	for expected_point: Vector2 in expected_polygon:
		var nearest := INF
		for actual_point: Vector2 in actual_coordinates:
			nearest = minf(nearest, actual_point.distance_to(expected_point))
		entries.append("%.9f" % nearest)
	return ",".join(entries)


func _append_unique_vector2(points: PackedVector2Array, point: Vector2) -> void:
	for existing: Vector2 in points:
		if existing.distance_to(point) <= POSITION_EPSILON:
			return
	points.append(point)


func _find_csg_polygon(node: Node) -> CSGPolygon3D:
	if node is CSGPolygon3D:
		return node as CSGPolygon3D
	for child: Node in node.get_children():
		var found := _find_csg_polygon(child)
		if found != null:
			return found
	return null


func _fail(message: String) -> void:
	_write_result(["ok=false", "error=%s" % message])
	push_error(message)
	quit(1)


func _write_result(lines: Array[String]) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
