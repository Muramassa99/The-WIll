extends SceneTree

# Isolated resources and production mesh/history owners. No player library,
# character, Handle wrapper, or full Forge scene is loaded by this verifier.
const State = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const Stage = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const Body = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const Profiles = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const Presenter = preload("res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd")
const Roll = preload("res://runtime/forge_v2/forge_v2_path_roll.gd")
const Scale = preload("res://runtime/forge_v2/forge_v2_path_scale.gd")
const VolumeResolver = preload("res://runtime/forge_v2/forge_v2_material_volume_resolver.gd")
const ProfileLibrary = preload("res://core/models/player_tool_profile_library_state.gd")
const REPORT := "C:/WORKSPACE/godot_runs/forge_v2_point_transform.json"
const STATE_PATH := "C:/WORKSPACE/godot_runs/forge_v2_point_transform_state.tres"
const EPSILON := 0.000002

var checks := 0
var failures := PackedStringArray()
var presenter: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_usec()
	presenter = Presenter.new()
	root.add_child(presenter)
	_test_defaults_and_limits()
	_test_paired_endpoint_collapse()
	_test_sampled_geometry()
	_test_collapsed_endpoints()
	_test_zero_volume_and_dormant_scales()
	_test_expanded_occupancy_and_bounds()
	_test_history()
	_test_range_endpoint_append_history()
	_test_transform_range()
	_test_range_easing()
	_test_real_fluted_ranges()
	_test_generated_and_retained_source()
	_test_detailing()
	presenter.free()
	var report := {"ok": failures.is_empty(), "checks": checks, "failures": failures,
		"duration_ms": float(Time.get_ticks_usec() - started) / 1000.0}
	DirAccess.make_dir_recursive_absolute(REPORT.get_base_dir())
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("Forge V2 point Transform: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _state(tool: StringName = State.TOOL_SPLINE_LINE) -> Resource:
	var state: Resource = State.new()
	state.call("reset_new_draft", "Point Transform verification")
	state.call("set_active_tool_id", tool)
	return state


func _seed(state: Resource) -> void:
	for point: Vector3 in [Vector3.ZERO, Vector3(0.04, 0.005, 0.0), Vector3(0.08, 0.0, 0.0)]:
		state.call("append_spline_line_point", point, Vector3.UP)


func _scales(state: Resource) -> PackedVector2Array:
	return state.get("spline_line_profile_scales") as PackedVector2Array


func _test_defaults_and_limits() -> void:
	var state := _state()
	_seed(state)
	_check(_scales(state) == PackedVector2Array([Vector2.ONE, Vector2.ONE, Vector2.ONE]), "new control points use original profile size")
	_check(bool(state.call("set_spline_line_point_profile_scale", 1, Vector2(0.05, 2.0))), "independent minimum X and maximum Y accepted")
	_check(_scales(state) == PackedVector2Array([Vector2.ONE, Vector2(0.05, 2.0), Vector2.ONE]), "editing one point preserves neighbours")
	state.call("set_spline_line_point_profile_scale", 1, Vector2(-10, 20))
	_check(_scales(state)[1].is_equal_approx(Vector2(0.05, 2.0)), "limits clamp to 5%-200% of original, never current size")
	var before := _scales(state).duplicate()
	_check(not bool(state.call("set_spline_line_point_profile_scale", 1, Vector2(NAN, 1))), "nonfinite transform rejected")
	_check(_scales(state) == before, "nonfinite edit preserves source")
	_check(bool(state.call("set_spline_line_point_profile_scale", 2, Vector2.ZERO)), "endpoint may collapse both axes to a point")
	_check(_scales(state)[2] == Vector2.ZERO, "endpoint zero is retained without an interior minimum clamp")
	var handle := _state(State.TOOL_HANDLES)
	handle.call("set_active_profile_id", Profiles.PROFILE_HANDLE_BUILDER)
	handle.call("set_active_handle_path_mode_id", State.HANDLE_PATH_MODE_THREE_POINT_LINEAR)
	_seed(handle)
	var original := handle.call("build_spline_roll_preview_body") as Resource
	_check(not bool(handle.call("set_spline_line_point_profile_scale", 1, Vector2(0.05, 2))), "Handles reject Transform")
	var unchanged := handle.call("build_spline_roll_preview_body") as Resource
	if _check(original != null and unchanged != null, "Handle comparison fixture exists"):
		_check(_mesh_bytes(original) == _mesh_bytes(unchanged), "rejected Handle edit preserves exact mesh")
	state.call("cancel_spline_line")
	_check(_scales(state).is_empty(), "Cancel clears transient Transform values")


func _body() -> Resource:
	var body: Resource = Body.new()
	body.set("shape_kind", Body.SHAPE_KIND_SPLINE_PROFILE_PATH)
	body.set("body_kind", Body.BODY_KIND_PROFILE_EXTRUSION)
	body.set("profile_polygon_2d_meters", PackedVector2Array([
		Vector2(-0.02, -0.01), Vector2(0.02, -0.01), Vector2(0.02, 0.01), Vector2(-0.02, 0.01)]))
	body.set("path_points", PackedVector3Array([
		Vector3.ZERO, Vector3(0, 0, 0.08), Vector3(0, 0, 0.16), Vector3(0, 0, 0.24), Vector3(0, 0, 0.32)]))
	body.set("path_surface_normals", PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]))
	body.call("normalize")
	return body


func _test_paired_endpoint_collapse() -> void:
	var normalized := Scale.normalize(PackedVector2Array([Vector2(0, 1), Vector2(0.3, 0.8)]), 2)
	_check(normalized == PackedVector2Array([Vector2.ZERO, Vector2(0.3, 0.8)]),
		"shared scales collapse both axes at zero while positive dimensions remain independent")
	var state := _state()
	_seed(state)
	state.call("set_spline_line_point_profile_scale", 2, Vector2(0, 0.8))
	_check(_scales(state)[2] == Vector2.ZERO, "endpoint X zero also closes Y to produce a point")
	state.call("set_spline_line_point_profile_scale", 2, Vector2.ONE)
	state.call("set_spline_line_point_profile_scale", 2, Vector2(0.7, 0))
	_check(_scales(state)[2] == Vector2.ZERO, "endpoint Y zero also closes X to produce a point")
	state.call("set_spline_line_point_profile_scale", 1, Vector2(0, 0.8))
	_check(_scales(state)[1].is_equal_approx(Vector2(0.05, 0.8)), "interior requested zero stays at 5% without collapsing its other axis")
	state.call("set_spline_line_profile_transform", PackedInt32Array([0, 2]), Vector2(0.7, 0))
	_check((state.call("get_spline_line_profile_transform_scale", PackedInt32Array([0, 2])) as Vector2) == Vector2.ZERO,
		"endpoint range Transform applies paired collapse")
	state.call("set_spline_line_profile_transform", PackedInt32Array([0, 1]), Vector2(0, 0.8))
	_check((state.call("get_spline_line_profile_transform_scale", PackedInt32Array([0, 1])) as Vector2).is_equal_approx(Vector2(0.05, 0.8)),
		"interior range target keeps the 5% floor and independent positive axis")
	var range_input := [{"fixed_a": 0, "scaled": 4, "fixed_b": -1,
		"fixed_a_scale": Vector2(0.7, 0), "fixed_b_scale": Vector2(0.2, 1.3), "scale": Vector2(0, 0.8)}]
	var ranges := Scale.normalize_ranges(range_input, 5)
	_check(ranges.size() == 1 and ranges[0].scale == Vector2.ZERO and ranges[0].fixed_a_scale == Vector2.ZERO
		and ranges[0].fixed_b_scale == Vector2(0.2, 1.3), "range normalization pairs zero targets and boundary snapshots without altering positive scales")
	var body := _body()
	body.set("path_profile_scales", PackedVector2Array([Vector2.ONE, Vector2.ONE, Vector2.ONE, Vector2.ONE, Vector2(0, 1)]))
	body.call("normalize")
	_check((body.get("path_profile_scales") as PackedVector2Array)[4] == Vector2.ZERO, "generic body normalization preserves a real point instead of a flat tip")


func _mesh_bytes(body: Resource) -> PackedByteArray:
	var mesh := presenter.call("_build_active_material_body_sweep_mesh", body) as ArrayMesh
	if mesh == null or mesh.get_surface_count() == 0:
		return PackedByteArray()
	return var_to_bytes(mesh.surface_get_arrays(0))


func _test_sampled_geometry() -> void:
	var baseline := _body()
	baseline.set("path_profile_scales", PackedVector2Array())
	var explicit := baseline.duplicate(true)
	explicit.set("path_profile_scales", Scale.normalize(PackedVector2Array(), 5))
	_check(not _mesh_bytes(baseline).is_empty(), "baseline sweep produces geometry")
	_check(_mesh_bytes(baseline) == _mesh_bytes(explicit), "absent and unit scales reproduce identical original mesh")
	var changed := explicit.duplicate(true)
	changed.set("path_profile_scales", PackedVector2Array([Vector2.ONE, Vector2.ONE, Vector2(2, 0.05), Vector2.ONE, Vector2.ONE]))
	var old_curve := Roll.build_body_curve(baseline, 0.004)
	var curve := Roll.build_body_curve(changed, 0.004)
	if not _check(old_curve != null and curve != null, "scaled and unscaled sweeps build"):
		return
	var old_data: Dictionary = old_curve.get_meta(Roll.FRAME_METADATA)
	var data: Dictionary = curve.get_meta(Roll.FRAME_METADATA)
	_check(data.points == old_data.points, "Transform leaves centreline samples unchanged without twist")
	var scale_values: PackedVector2Array = data.get("profile_scales", PackedVector2Array())
	var offsets: PackedFloat64Array = data.source_offsets
	var distances: PackedFloat64Array = data.distances
	if _check(scale_values.size() == distances.size(), "one profile scale accompanies each sweep sample"):
		var outside_unchanged := true
		for index in range(distances.size()):
			if distances[index] <= offsets[1] or distances[index] >= offsets[3]:
				outside_unchanged = outside_unchanged and scale_values[index].is_equal_approx(Vector2.ONE)
		_check(outside_unchanged, "interior edit affects only its two neighbouring spans")
	var middle := Roll.sample_frame(curve, offsets[2])
	_check((middle.get("profile_scale", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(2, 0.05)), "middle frame reaches independent requested limits")
	changed.set("path_profile_scales", PackedVector2Array([Vector2.ONE, Vector2.ONE, Vector2.ONE, Vector2.ONE, Vector2(0.05, 0.05)]))
	changed.set("path_roll_degrees", PackedFloat64Array([0, 20, 50, 70, 90]))
	curve = Roll.build_body_curve(changed, 0.004)
	if _check(curve != null, "twist and taper combine"):
		data = curve.get_meta(Roll.FRAME_METADATA)
		var last := Roll.sample_frame(curve, (data.distances as PackedFloat64Array)[-1])
		_check((last.get("profile_scale", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(0.05, 0.05)), "tip retains 5% cross-section rather than zero-area apex")
		_check(absf(float(last.roll_degrees) - 90.0) < 0.001, "endpoint twist survives taper")
		_assert_sample_ring_vertices(changed, curve, "twisted tapered solid")
	var weighted := Scale.weighted_path_length(PackedVector3Array([Vector3.ZERO, Vector3.RIGHT]), PackedVector2Array([Vector2.ONE, Vector2(2, 0.5)]))
	_check(absf(weighted - 13.0 / 12.0) < EPSILON, "rough volume integrates the product of independently linear dimensions")


func _assert_sample_ring_vertices(body: Resource, curve: Curve3D, label: String) -> void:
	var mesh := presenter.call("_build_active_material_body_sweep_mesh", body) as ArrayMesh
	if not _check(mesh != null and mesh.get_surface_count() > 0, label + " generated"):
		return
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var data: Dictionary = curve.get_meta(Roll.FRAME_METADATA)
	var offsets: PackedFloat64Array = data.source_offsets
	var distances: PackedFloat64Array = data.distances
	var polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	for offset_index in [0, int(offsets.size() / 2), offsets.size() - 1]:
		var ring_index := 0
		for candidate in range(distances.size()):
			if absf(distances[candidate] - offsets[offset_index]) < absf(distances[ring_index] - offsets[offset_index]):
				ring_index = candidate
		var frame := Roll.sample_frame_at_index(curve, ring_index)
		var scale_value: Vector2 = frame.get("profile_scale", Vector2.ONE)
		var present := true
		for point: Vector2 in polygon:
			var expected: Vector3 = frame.position + frame.axis_x * point.x * scale_value.x + frame.axis_y * point.y * scale_value.y
			var found := false
			for vertex: Vector3 in vertices:
				if vertex.distance_to(expected) < EPSILON:
					found = true
					break
			present = present and found
		_check(present, "%s includes scaled shared-frame ring %d" % [label, offset_index])


func _test_collapsed_endpoints() -> void:
	for endpoint_scale: Vector2 in [Vector2.ZERO, Vector2(0, 1), Vector2(1, 0)]:
		var body := _body()
		body.set("path_profile_scales", PackedVector2Array([Vector2.ONE, Vector2.ONE, Vector2.ONE, Vector2.ONE, endpoint_scale]))
		var mesh := presenter.call("_build_active_material_body_sweep_mesh", body) as ArrayMesh
		var label := "point tip from scale " + str(endpoint_scale)
		var curve := Roll.build_body_curve(body, 0.004)
		if _check(curve != null, label + " curve exists"):
			var data: Dictionary = curve.get_meta(Roll.FRAME_METADATA)
			_check((data.profile_scales as PackedVector2Array)[-1] == Vector2.ZERO, label + " ends at a biaxial point")
		if not _check(mesh != null and mesh.get_surface_count() > 0, label + " produces a mesh"):
			continue
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var nondegenerate := true
		var edge_counts: Dictionary = {}
		for triangle in range(0, indices.size(), 3):
			var a := vertices[indices[triangle]]
			var b := vertices[indices[triangle + 1]]
			var c := vertices[indices[triangle + 2]]
			nondegenerate = nondegenerate and (b - a).cross(c - a).length_squared() > 0.000000000000000001
			for edge: Array in [[a, b], [b, c], [c, a]]:
				var first := _vertex_key(edge[0])
				var second := _vertex_key(edge[1])
				var key := first + "/" + second if first < second else second + "/" + first
				edge_counts[key] = int(edge_counts.get(key, 0)) + 1
		var closed := not edge_counts.is_empty()
		for count: int in edge_counts.values():
			closed = closed and count == 2
		_check(nondegenerate, label + " emits no zero-area triangles")
		_check(closed, label + " is closed with two faces per geometric edge")


func _vertex_key(point: Vector3) -> String:
	# Test the emitted topology, not a quantized replacement. Rounding to
	# 0.1 micrometre merges distinct vertices near a curved point apex and
	# falsely reports extra edge owners. Canonicalize only signed zero.
	var exact := Vector3(0.0 if point.x == 0.0 else point.x,
		0.0 if point.y == 0.0 else point.y, 0.0 if point.z == 0.0 else point.z)
	return var_to_bytes(exact).hex_encode()


func _test_zero_volume_and_dormant_scales() -> void:
	var state := _state()
	state.call("append_spline_line_point", Vector3.ZERO, Vector3.UP)
	state.call("append_spline_line_point", Vector3(0.08, 0, 0), Vector3.UP)
	for point_index in range(2):
		state.call("set_spline_line_point_profile_scale", point_index, Vector2.ZERO)
	_check(_scales(state) == PackedVector2Array([Vector2.ZERO, Vector2.ZERO]), "fully collapsed endpoints remain editable values")
	_check(not bool(state.call("can_generate_spline_line_csg_noodle")), "fully collapsed two-point path cannot generate zero-volume material")
	_check(not bool(state.call("generate_spline_line_csg_noodle")) and (state.get("spline_line_points") as PackedVector3Array).size() == 2, "zero-volume Generate retains the editable path")
	_check(String(state.call("get_spline_line_csg_noodle_status_label")).contains("no volume"), "zero-volume path has an explanatory status")
	state.call("set_spline_line_point_profile_scale", 0, Vector2(0, 1))
	state.call("set_spline_line_point_profile_scale", 1, Vector2(0, 1))
	_check(not bool(state.call("can_generate_spline_line_csg_noodle")), "one-axis zero requests produce collapsed endpoints, not a sheet")
	state.call("set_spline_line_point_profile_scale", 1, Vector2(1, 0))
	_check(not bool(state.call("can_generate_spline_line_csg_noodle")), "opposite zero-axis requests remain two collapsed points without artificial volume")
	state.call("set_spline_line_point_profile_scale", 1, Vector2.ONE)
	_check(bool(state.call("can_generate_spline_line_csg_noodle")), "restoring one full endpoint gives the tapered path real volume")
	var before := _scales(state).duplicate()
	state.call("set_active_tool_id", State.TOOL_VOLUME_STROKE)
	state.call("set_active_tool_id", State.TOOL_SPLINE_LINE)
	_check(_scales(state) == before, "direct Manual detour preserves dormant spline scales with its existing points")
	_check(bool(state.call("generate_spline_line_csg_noodle")), "point-to-full endpoint spline generates")
	var body := state.call("get_selected_material_body") as Resource
	if _check(body != null and state.call("commit_pending_material_bodies_as_layer") != null, "point-to-full spline commits for retained-edit guard"):
		var body_id := StringName(body.get("body_id"))
		state.call("begin_retained_spline_change", body_id)
		state.call("set_spline_line_point_profile_scale", 0, Vector2.ZERO)
		state.call("set_spline_line_point_profile_scale", 1, Vector2.ZERO)
		var candidate := state.call("build_retained_spline_change_candidate") as Dictionary
		_check(not bool(candidate.get("ok", false)) and StringName(candidate.get("reason", &"")) == &"retained_spline_transform_zero_volume", "retained edit refuses zero-volume replacement while preserving source")
	var detail := _state(State.TOOL_DETAILING_BRUSH)
	var points := PackedVector3Array([Vector3.ZERO, Vector3(0.04, 0, 0), Vector3(0.08, 0, 0)])
	_check(bool(detail.call("replace_detailing_brush_path_solution",
		PackedVector3Array([points[0], points[2]]), PackedVector3Array([Vector3.UP, Vector3.UP]),
		&"target_material_surface", &"zero_volume_detail", points,
		PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP]), PackedInt32Array([0, 2]),
		[true], [&"none"], true, &"none", 1,
		PackedVector3Array([Vector3.DOWN, Vector3.DOWN]), PackedVector3Array([Vector3.DOWN, Vector3.DOWN, Vector3.DOWN]))), "two-control Detail path accepted")
	detail.call("set_spline_line_point_profile_scale", 0, Vector2(0, 1))
	detail.call("set_spline_line_point_profile_scale", 1, Vector2(0, 1))
	_check(not bool(detail.call("can_generate_detailing_brush")) and not bool(detail.call("generate_detailing_brush")), "Detail rejects zero-volume generation without changing its path")
	_check(String(detail.call("get_detailing_brush_status_label")).contains("no volume"), "Detail zero-volume status explains the scale problem")
	detail.call("set_spline_line_point_profile_scale", 1, Vector2(1, 0))
	_check(not bool(detail.call("can_generate_detailing_brush")), "Detail zero requests close both endpoint axes and cannot invent volume")
	detail.call("set_spline_line_point_profile_scale", 1, Vector2.ONE)
	_check(bool(detail.call("can_generate_detailing_brush")), "Detail with a restored full endpoint has positive resolved-span volume")


func _test_expanded_occupancy_and_bounds() -> void:
	var baseline := _body()
	var expanded := baseline.duplicate(true)
	expanded.set("path_profile_scales", PackedVector2Array([Vector2(2, 2), Vector2(2, 2), Vector2(2, 2), Vector2(2, 2), Vector2(2, 2)]))
	expanded.call("normalize")
	var resolver = VolumeResolver.new()
	var spacing := 0.005
	var original_cells: Dictionary = resolver.call("_collect_body_occupied_cells", baseline, spacing)
	var expanded_cells: Dictionary = resolver.call("_collect_body_occupied_cells", expanded, spacing)
	_check(not original_cells.is_empty() and expanded_cells.size() > original_cells.size(), "expanded profile increases occupied cells")
	var curve := Roll.build_body_curve(expanded, spacing)
	if _check(curve != null, "expanded occupancy shared frame exists"):
		var frame := Roll.sample_frame(curve, 0.16)
		var probe: Vector3 = frame.position + frame.axis_x * 0.03 + frame.axis_y * 0.0025
		var probe_cell := Vector3i(floori(probe.x / spacing), floori(probe.y / spacing), floori(probe.z / spacing))
		_check(expanded_cells.has(probe_cell) and not original_cells.has(probe_cell), "occupancy includes expanded material outside the original cross-section")
	var original_bounds: AABB = presenter.call("_build_csg_body_bounds", baseline)
	var expanded_bounds: AABB = presenter.call("_build_csg_body_bounds", expanded)
	_check(expanded_bounds.get_volume() > original_bounds.get_volume(), "operand bounds expand with profile scale")
	var mesh := presenter.call("_build_active_material_body_sweep_mesh", expanded) as ArrayMesh
	if _check(mesh != null and mesh.get_surface_count() > 0, "expanded bounds mesh exists"):
		var all_inside := true
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			all_inside = all_inside and expanded_bounds.grow(EPSILON).has_point(vertex)
		_check(all_inside, "expanded operand bounds contain the generated profile")


func _test_history() -> void:
	var stage: Node = Stage.new()
	root.add_child(stage)
	var state := _state()
	stage.set("active_authoring_state", state)
	stage.call("append_spline_line_point", Vector3.ZERO, Vector3.UP)
	stage.call("append_spline_line_point", Vector3(0.04, 0, 0), Vector3.UP)
	_check(bool(stage.call("set_spline_line_point_profile_scale", 1, Vector2(0.25, 1.5))), "controller accepts Transform")
	stage.call("append_spline_line_point", Vector3(0.08, 0, 0), Vector3.UP)
	_check(_scales(state) == PackedVector2Array([Vector2.ONE, Vector2(0.25, 1.5), Vector2.ONE]), "append supplies neutral size without changing previous transform")
	_check(bool(stage.call("undo_latest_action")), "append undo succeeds")
	_check(_scales(state) == PackedVector2Array([Vector2.ONE, Vector2(0.25, 1.5)]), "fast append undo keeps scale array aligned")
	stage.call("undo_latest_action")
	_check(_scales(state) == PackedVector2Array([Vector2.ONE, Vector2.ONE]), "Transform undo restores original size")
	stage.call("redo_latest_action")
	stage.call("redo_latest_action")
	_check(_scales(state) == PackedVector2Array([Vector2.ONE, Vector2(0.25, 1.5), Vector2.ONE]), "mixed redo restores exact values and indexing")
	stage.call("begin_editor_action_transaction", "Transform Path Point")
	stage.call("set_spline_line_point_profile_scale", 1, Vector2(0.5, 1.5))
	stage.call("set_spline_line_point_profile_scale", 1, Vector2(0.5, 2))
	stage.call("finish_editor_action_transaction")
	stage.call("undo_latest_action")
	_check(_scales(state)[1].is_equal_approx(Vector2(0.25, 1.5)), "popup changes form one undo action")
	stage.call("set_spline_line_point_profile_scale", 2, Vector2.ZERO)
	stage.call("append_spline_line_point", Vector3(0.12, 0, 0), Vector3.UP)
	_check(_scales(state)[2].is_equal_approx(Vector2(0.05, 0.05)), "appending converts previous zero endpoint into a valid interior cross-section")
	stage.call("undo_latest_action")
	_check(_scales(state).size() == 3 and _scales(state)[2] == Vector2.ZERO, "append undo restores previous collapsed endpoint exactly")
	stage.call("redo_latest_action")
	_check(_scales(state).size() == 4 and _scales(state)[2].is_equal_approx(Vector2(0.05, 0.05)), "append redo restores interior minimum and scale alignment")
	stage.free()


func _test_transform_range() -> void:
	var stage: Node = Stage.new()
	root.add_child(stage)
	var state := _state()
	stage.set("active_authoring_state", state)
	for point: Vector3 in [Vector3.ZERO, Vector3(0.02, 0, 0), Vector3(0.04, 0, 0), Vector3(0.08, 0, 0), Vector3(0.12, 0, 0), Vector3(0.16, 0, 0)]:
		state.call("append_spline_line_point", point, Vector3.UP)
	var baseline := state.call("capture_editor_transient_snapshot") as Dictionary
	_check(bool(stage.call("set_spline_line_profile_transform", PackedInt32Array([1, 3]), Vector2(2, 0.4))), "two-role Transform spans B to D in A through F")
	var range_scales := _scales(state).duplicate()
	var ranges := (state.get("spline_line_profile_transform_ranges") as Array).duplicate(true)
	_check(ranges.size() == 1, "range is stored as a bounded transform operation")
	var preview := state.call("build_spline_roll_preview_body") as Resource
	if _check(preview != null, "range Transform preview exists"):
		var curve := Roll.build_body_curve(preview, 0.002)
		if _check(curve != null, "range Transform sweep builds"):
			var data: Dictionary = curve.get_meta(Roll.FRAME_METADATA)
			var offsets: PackedFloat64Array = data.source_offsets
			var distances: PackedFloat64Array = data.distances
			var scales: PackedVector2Array = data.profile_scales
			var span_ok := true
			var incoming_at_d := false
			var outgoing_at_d := false
			for index in range(distances.size()):
				if absf(distances[index] - offsets[3]) < EPSILON:
					incoming_at_d = incoming_at_d or scales[index].is_equal_approx(Vector2(2, 0.4))
					outgoing_at_d = outgoing_at_d or scales[index].is_equal_approx(Vector2.ONE)
					continue
				var expected := Vector2.ONE
				if distances[index] > offsets[1] and distances[index] < offsets[3]:
					var ratio := (distances[index] - offsets[1]) / (offsets[3] - offsets[1])
					expected = _circular_expected(Vector2.ONE, Vector2(2, 0.4), ratio,
						offsets[3] - offsets[1], Scale.profile_extents(preview))
				span_ok = span_ok and scales[index].distance_to(expected) < EPSILON
			_check(span_ok, "only B-D tapers; A-B and D-F retain original dimensions")
			_check(incoming_at_d and outgoing_at_d, "D contains transformed incoming and unchanged outgoing cross-sections")
		_assert_native_closed_mesh(preview, "opposing X/Y range hard-stop")
	_check(bool(stage.call("undo_latest_action")), "one range Transform is undoable")
	_check(state.call("capture_editor_transient_snapshot") == baseline, "range Undo restores exact prior controls and transforms")
	_check(bool(stage.call("redo_latest_action")), "one range Transform redoes")
	_check(_scales(state) == range_scales and state.get("spline_line_profile_transform_ranges") == ranges, "range Redo restores values and bounded operation")
	var before_move: Vector2 = state.call("get_spline_line_point_profile_scale", 2)
	_check(bool(state.call("set_spline_line_point", 2, Vector3(0.04, 0.06, 0))), "intermediate geometric point moves within Transform range")
	var after_move: Vector2 = state.call("get_spline_line_point_profile_scale", 2)
	_check(before_move.distance_to(after_move) > 0.001, "moving intermediate point recalculates its scale from current span length")
	_check(state.get("spline_line_profile_transform_ranges") == ranges, "intermediate movement retains original transform boundaries")
	preview = state.call("build_spline_roll_preview_body") as Resource
	if preview != null:
		var moved_curve := Roll.build_body_curve(preview, 0.002)
		if moved_curve != null:
			var moved_data: Dictionary = moved_curve.get_meta(Roll.FRAME_METADATA)
			var offsets: PackedFloat64Array = moved_data.source_offsets
			var ratio := (offsets[2] - offsets[1]) / (offsets[3] - offsets[1])
			var expected := _circular_expected(Vector2.ONE, Vector2(2, 0.4), ratio,
				offsets[3] - offsets[1], Scale.profile_extents(preview))
			var at_moved := Roll.sample_frame(moved_curve, offsets[2])
			_check((at_moved.get("profile_scale", Vector2.ZERO) as Vector2).distance_to(expected) < 0.0001, "geometry movement keeps whole-range taper rather than freezing old intermediate sizes")
	_check(bool(state.call("generate_spline_line_csg_noodle")), "range-transformed source generates")
	var body := state.call("get_selected_material_body") as Resource
	if _check(body != null, "range generated source exists"):
		_check(body.get("path_profile_transform_ranges") == ranges, "generated source retains bounded Transform data")
		_check(state.call("commit_pending_material_bodies_as_layer") != null, "range source commits for retained editing")
		var body_id := StringName(body.get("body_id"))
		var range_path := STATE_PATH.get_basename() + "_range.tres"
		DirAccess.make_dir_recursive_absolute(range_path.get_base_dir())
		_check(ResourceSaver.save(state, range_path) == OK, "range source saves to isolated artifact")
		var loaded := ResourceLoader.load(range_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if _check(loaded != null, "range source cold reloads"):
			var restored := loaded.call("_find_material_body_by_id", body_id) as Resource
			_check(restored != null and restored.get("path_profile_transform_ranges") == ranges, "cold reload retains exact transform boundaries")
			_check(bool((loaded.call("begin_retained_spline_change", body_id) as Dictionary).get("ok", false)), "range source reopens in retained E editing")
			_check(loaded.get("spline_line_profile_transform_ranges") == ranges, "retained editing restores bounded transform rather than adjacent point scaling")
	var diamond := _state()
	for point: Vector3 in [Vector3.ZERO, Vector3(0.02, 0, 0), Vector3(0.04, 0, 0), Vector3(0.08, 0, 0), Vector3(0.12, 0, 0)]:
		diamond.call("append_spline_line_point", point, Vector3.UP)
	_check(bool(diamond.call("set_spline_line_profile_transform", PackedInt32Array([0, 2, 4]), Vector2(2, 0.2))), "three-role Transform expands only P2 between fixed boundaries")
	_check((diamond.get("spline_line_profile_transform_ranges") as Array).size() == 1, "three-role Transform is one bounded operation")
	_check((diamond.call("get_spline_line_point_profile_scale", 0) as Vector2).is_equal_approx(Vector2.ONE)
		and (diamond.call("get_spline_line_point_profile_scale", 4) as Vector2).is_equal_approx(Vector2.ONE)
		and (diamond.call("get_spline_line_point_profile_scale", 2) as Vector2).is_equal_approx(Vector2(2, 0.2)), "three-role boundaries remain fixed while target expands/contracts")
	var before_invalid := diamond.call("capture_editor_transient_snapshot") as Dictionary
	_check(not bool(diamond.call("set_spline_line_profile_transform", PackedInt32Array([0, 2, 1]), Vector2(1.4, 0.6))), "third role on wrong side of P2 is rejected")
	_check(diamond.call("capture_editor_transient_snapshot") == before_invalid, "invalid range does not mutate scales, transform records or context")
	_check(bool(diamond.call("set_spline_line_profile_transform", PackedInt32Array([4, 2, 0]), Vector2(1.4, 0.6))), "reversed boundary ordering is accepted")
	_check((diamond.call("get_spline_line_point_profile_scale", 2) as Vector2).is_equal_approx(Vector2(1.4, 0.6)), "reversed range retains P2 as the expansion target")
	stage.free()


func _test_range_easing() -> void:
	# Physical circle/tangent assertions distinguish a short lead-in from
	# a whole-range easing curve. Uneven controls expose per-span restarts.
	var points := PackedVector3Array([Vector3.ZERO, Vector3(0.2, 0, 0),
		Vector3(0.7, 0, 0), Vector3(1, 0, 0), Vector3(1.3, 0, 0)])
	var offsets := Scale.polyline_offsets(points)
	var values := Scale.normalize(PackedVector2Array(), points.size())
	var extents := Vector2(0.2, 0.15)
	var operation := {"fixed_a": 0, "scaled": 3, "fixed_b": -1,
		"fixed_a_scale": Vector2.ONE, "fixed_b_scale": Vector2.ONE, "scale": Vector2(2, 0.4)}
	var ranges: Array = [operation]
	_check(absf(Scale.taper_radius_meters(0.064249) - 0.00321) < 1.0e-12,
		"5 percent radius rounds 3.21245 mm to 3.21 mm")
	_check(absf(Scale.taper_radius_meters(0.0642999) - 0.00321) < 1.0e-12
		and absf(Scale.taper_radius_meters(0.0643) - 0.00322) < 1.0e-12
		and absf(Scale.taper_radius_meters(0.0643001) - 0.00322) < 1.0e-12,
		"radius decimal half-step rounds upward with correct neighbouring values")
	_check(_sample_range_offset(values, offsets, ranges, 0.0, extents) == Vector2.ONE
		and Scale.sample_span(values, offsets, ranges, 2, 1.0, extents).is_equal_approx(Vector2(2, 0.4)),
		"circular lead preserves exact fixed and selected dimensions")
	var radius := 0.05
	for axis in range(2):
		var height: float = absf((operation.scale as Vector2)[axis] - 1.0) * extents[axis]
		var slope := _circle_tangent_slope(1.0, height, radius)
		var tangent_x := radius * slope / sqrt(1.0 + slope * slope)
		var x := tangent_x * 0.5
		var sample := _sample_range_offset(values, offsets, ranges, x, extents)
		var y := absf(sample[axis] - 1.0) * extents[axis]
		_check(absf(x * x + (y - radius) * (y - radius) - radius * radius) < 1.0e-8,
			"axis %d lead contour lies on the specified physical-radius circle" % axis)
		var dx := tangent_x * 0.02
		var left := _sample_range_offset(values, offsets, ranges, tangent_x - dx, extents)
		var at_join := _sample_range_offset(values, offsets, ranges, tangent_x, extents)
		var right := _sample_range_offset(values, offsets, ranges, tangent_x + dx, extents)
		var incoming := absf(at_join[axis] - left[axis]) * extents[axis] / dx
		var outgoing := absf(right[axis] - at_join[axis]) * extents[axis] / dx
		_check(absf(incoming - slope) < 0.01 and absf(outgoing - slope) < 0.01,
			"axis %d circular lead and straight taper share their tangent" % axis)
	var quarter := _sample_range_offset(values, offsets, ranges, 0.25, extents)
	var middle := _sample_range_offset(values, offsets, ranges, 0.5, extents)
	var three_quarter := _sample_range_offset(values, offsets, ranges, 0.75, extents)
	_check((quarter + three_quarter - 2.0 * middle).length() < EPSILON
		and quarter.distance_to(_circular_expected(Vector2.ONE, Vector2(2, 0.4), 0.25, 1.0, extents)) < EPSILON,
		"remaining taper is straight after its short circular lead, not a full-span S curve")
	var monotonic := true
	var bounded := true
	var previous := Vector2.ONE
	for index in range(101):
		var sample := _sample_range_offset(values, offsets, ranges, float(index) / 100.0, extents)
		monotonic = monotonic and sample.x >= previous.x - EPSILON and sample.y <= previous.y + EPSILON
		bounded = bounded and sample.x >= 1.0 - EPSILON and sample.x <= 2.0 + EPSILON \
			and sample.y >= 0.4 - EPSILON and sample.y <= 1.0 + EPSILON
		previous = sample
	_check(monotonic and bounded, "circular lead has no overshoot for independent expansion and contraction")
	var delta := 0.001
	var entrance_slope := (_sample_range_offset(values, offsets, ranges, 0.00001, extents) - Vector2.ONE) / 0.00001
	var target_slope := (Vector2(2, 0.4) - _sample_range_offset(values, offsets, ranges, 1.0 - delta, extents)) / delta
	_check(entrance_slope.length() < 0.004 and target_slope.length() > 1.0,
		"only the fixed boundary is rounded; selected target keeps the straight taper slope")
	var before_control := _sample_range_offset(values, offsets, ranges, 0.2 - delta, extents)
	var at_control := _sample_range_offset(values, offsets, ranges, 0.2, extents)
	var after_control := _sample_range_offset(values, offsets, ranges, 0.2 + delta, extents)
	var incoming_slope := (at_control - before_control) / delta
	var outgoing_slope := (after_control - at_control) / delta
	_check(incoming_slope.distance_to(outgoing_slope) < 0.006 and incoming_slope.length() > 1.0
		and outgoing_slope.length() > 1.0, "intermediate control does not restart circular lead or change straight taper slope")
	_check(Scale.sample_span(values, offsets, ranges, 2, 1.0, extents).distance_to(Scale.sample_span(values, offsets, ranges, 3, 0.0, extents)) > 1.0
		and Scale.sample_span(values, offsets, ranges, 3, 0.5, extents) == Vector2.ONE,
		"circular lead retains the intentional hard T step and unchanged following span")
	var reversed := operation.duplicate(true)
	reversed.fixed_a = 3
	reversed.scaled = 0
	_check(_sample_range_offset(values, offsets, [reversed], 0.25, extents).distance_to(three_quarter) < EPSILON
		and _sample_range_offset(values, offsets, [reversed], 0.75, extents).distance_to(quarter) < EPSILON,
		"reversed role order starts its circular lead at the actual fixed boundary")
	var diamond := operation.duplicate(true)
	diamond.scaled = 2
	diamond.fixed_b = 4
	var diamond_target := Scale.sample_span(values, offsets, [diamond], 1, 1.0, extents)
	var diamond_left := _sample_range_offset(values, offsets, [diamond], offsets[2] - delta, extents)
	var diamond_right := _sample_range_offset(values, offsets, [diamond], offsets[2] + delta, extents)
	_check(diamond_target.distance_to(Vector2(2, 0.4)) < EPSILON
		and (diamond_target - diamond_left).length() / delta > 1.0
		and (diamond_right - diamond_target).length() / delta > 1.0,
		"diamond rounds its fixed boundaries but preserves its selected peak")
	var collapse := operation.duplicate(true)
	collapse.scale = Vector2.ZERO
	var asymmetric := operation.duplicate(true)
	asymmetric.fixed_a_scale = Vector2(0.3, 1.4)
	asymmetric.scale = Vector2(1.9, 0.2)
	for fixture: Dictionary in [{"name": "mixed-axis range", "ranges": ranges},
		{"name": "reversed range", "ranges": [reversed]}, {"name": "diamond", "ranges": [diamond]},
		{"name": "point collapse", "ranges": [collapse]}, {"name": "asymmetric boundary", "ranges": [asymmetric]}]:
		var volume := Scale.weighted_transformed_path_length(points, values, fixture.ranges, offsets, extents)
		var numerical := _numerical_weighted_range_length(points, values, fixture.ranges, extents)
		_check(absf(volume - numerical) < 0.000002, "circular " + String(fixture.name) + " volume matches independent fine midpoint integration")
	# Baseline direct point scales keep their existing linear interpolation.
	_check(Scale.sample_controls(PackedVector2Array([Vector2.ONE, Vector2(2, 0.4)]), 0, 0.25).distance_to(Vector2(1.25, 0.85)) < EPSILON,
		"legacy direct point scales remain linear outside authored Transform ranges")


func _circle_tangent_slope(length: float, height: float, radius: float) -> float:
	# Independent line-circle discriminant, rather than production's angles.
	return (length * (height - radius) + radius * sqrt(length * length + height * height - 2.0 * height * radius)) / (length * length - radius * radius)


func _circular_expected(start: Vector2, target: Vector2, ratio: float, length: float, extents: Vector2) -> Vector2:
	if ratio <= 0.0:
		return start
	if ratio >= 1.0:
		return target
	var radius := floorf(length * 5000.0 + 0.500000001) * 0.00001
	var result := start
	for axis in range(2):
		var height := absf(target[axis] - start[axis]) * extents[axis]
		if height <= 1.0e-12 or radius <= 0.0:
			result[axis] = lerpf(start[axis], target[axis], ratio)
			continue
		var slope := _circle_tangent_slope(length, height, radius)
		var tangent_x := radius * slope / sqrt(1.0 + slope * slope)
		var x := length * ratio
		var displacement := radius - sqrt(maxf(radius * radius - x * x, 0.0)) if x < tangent_x else height - slope * (length - x)
		result[axis] += signf(target[axis] - start[axis]) * displacement / extents[axis]
	return result


func _sample_range_offset(values: PackedVector2Array, offsets: PackedFloat64Array, ranges: Array, distance: float, extents: Vector2) -> Vector2:
	for span in range(offsets.size() - 1):
		if distance <= offsets[span + 1] + 0.000000001:
			var length := offsets[span + 1] - offsets[span]
			return Scale.sample_span(values, offsets, ranges, span,
				(distance - offsets[span]) / length if length > 0.0 else 0.0, extents)
	return Scale.sample_span(values, offsets, ranges, offsets.size() - 2, 1.0, extents)


func _numerical_weighted_range_length(points: PackedVector3Array, values: PackedVector2Array, ranges: Array, extents: Vector2) -> float:
	# Midpoint integration intentionally uses no production Gauss points/weights.
	var offsets := Scale.polyline_offsets(points)
	var integral := 0.0
	const STEPS := 2048
	for span in range(points.size() - 1):
		var area_sum := 0.0
		for sample_index in range(STEPS):
			var scale := Scale.sample_span(values, offsets, ranges, span, (float(sample_index) + 0.5) / float(STEPS), extents)
			area_sum += float(scale.x) * float(scale.y)
		integral += points[span].distance_to(points[span + 1]) * area_sum / float(STEPS)
	return integral


func _test_range_endpoint_append_history() -> void:
	var stage: Node = Stage.new()
	root.add_child(stage)
	var state := _state()
	stage.set("active_authoring_state", state)
	for point_index in range(3):
		stage.call("append_spline_line_point", Vector3(float(point_index) * 0.04, 0, 0), Vector3.UP)
	stage.call("set_spline_line_profile_transform", PackedInt32Array([0, 2]), Vector2.ZERO)
	stage.call("set_spline_line_profile_transform", PackedInt32Array([2, 1]), Vector2(0.75, 0.75))
	stage.call("set_spline_line_profile_transform", PackedInt32Array([0, 1, 2]), Vector2(1.25, 1.25))
	var before := state.call("capture_editor_transient_snapshot") as Dictionary
	var ranges: Array = state.get("spline_line_profile_transform_ranges")
	if _check(ranges.size() == 3, "collapsed endpoint can be reused as fixed boundaries in later ranges"):
		_check(ranges[1].fixed_a_scale == Vector2.ZERO and ranges[2].fixed_b_scale == Vector2.ZERO,
			"fixed boundary snapshots capture the collapsed endpoint before append")
		stage.call("append_spline_line_point", Vector3(0.12, 0, 0), Vector3.UP)
		ranges = state.get("spline_line_profile_transform_ranges")
		_check((ranges[0].scale as Vector2).is_equal_approx(Vector2(0.05, 0.05))
			and (ranges[1].fixed_a_scale as Vector2).is_equal_approx(Vector2(0.05, 0.05))
			and (ranges[2].fixed_b_scale as Vector2).is_equal_approx(Vector2(0.05, 0.05)),
			"append promotes every former endpoint reference to the interior minimum")
		_check(bool(stage.call("undo_latest_action")), "former endpoint range append undoes")
		_check(state.call("capture_editor_transient_snapshot") == before,
			"append Undo restores collapsed targets and fixed-boundary snapshots exactly")
	stage.free()


func _assert_native_closed_mesh(body: Resource, label: String, mesh: ArrayMesh = null) -> void:
	if mesh == null:
		mesh = presenter.call("_build_active_material_body_sweep_mesh", body) as ArrayMesh
	if not _check(mesh != null and mesh.get_surface_count() > 0, label + " yields a joined mesh"):
		return
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var edge_counts: Dictionary = {}
	var nonzero := true
	for triangle in range(0, indices.size(), 3):
		var a := vertices[indices[triangle]]
		var b := vertices[indices[triangle + 1]]
		var c := vertices[indices[triangle + 2]]
		nonzero = nonzero and (b - a).cross(c - a).length_squared() > 0.0
		for edge: Array in [[a, b], [b, c], [c, a]]:
			var first := _vertex_key(edge[0])
			var second := _vertex_key(edge[1])
			var key := first + "/" + second if first < second else second + "/" + first
			edge_counts[key] = int(edge_counts.get(key, 0)) + 1
	var closed := not edge_counts.is_empty()
	for count: int in edge_counts.values():
		closed = closed and count == 2
	_check(nonzero and closed, label + " has a closed nondegenerate boundary")
	if not _check(ClassDB.class_exists(&"ForgeV2ManifoldBoolean"), "native acceptance backend available"):
		return
	var backend := ClassDB.instantiate(&"ForgeV2ManifoldBoolean") as RefCounted
	var acceptance := backend.call("reset_mesh", vertices, indices) as Dictionary
	_check(bool(acceptance.get("ok", false)) and float(acceptance.get("manifold_volume_m3", 0.0)) > 0.0,
		label + " is accepted as a positive-volume native operand")


func _test_real_fluted_ranges() -> void:
	# Read the user's actual concave profile, but save only isolated verification
	# outputs. The saved profile library and player drafts are never rewritten.
	var library := ResourceLoader.load(ProfileLibrary.DEFAULT_SAVE_FILE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource
	if not _check(library != null, "actual saved profile library is available"):
		return
	var source_profiles: Array = library.get("saved_profiles")
	var source_bytes := var_to_bytes(source_profiles)
	var fluted: Dictionary = {}
	for profile: Dictionary in source_profiles:
		if String(profile.get("label", "")).to_lower() == "fluted blade":
			fluted = profile.duplicate(true)
			break
	if not _check(not fluted.is_empty(), "actual Fluted Blade profile was found"):
		return
	var fixtures: Array[Dictionary] = [
		{"name": "diamond", "roles": PackedInt32Array([0, 2, 4]), "scale": Vector2(2, 2)},
		{"name": "hard_stop_contract", "roles": PackedInt32Array([1, 3]), "scale": Vector2(0.05, 0.05)},
		{"name": "hard_stop_cross_axes", "roles": PackedInt32Array([1, 3]), "scale": Vector2(2, 0.5)},
		{"name": "pointed_tip", "roles": PackedInt32Array([0, 5]), "scale": Vector2.ZERO},
	]
	var artifact_dir := "C:/WORKSPACE/godot_runs/forge_profile_transform_fluted"
	DirAccess.make_dir_recursive_absolute(artifact_dir)
	for fixture: Dictionary in fixtures:
		var state := _state()
		var label := "Fluted Blade " + String(fixture.name)
		if not _check(bool(state.call("select_active_saved_basic_profile", fluted.duplicate(true))), label + " selects original profile"):
			continue
		for point_index in range(6):
			state.call("append_spline_line_point", Vector3(float(point_index) * 0.15, 0, 0), Vector3.UP)
		_check(bool(state.call("set_spline_line_profile_transform", fixture.roles, fixture.scale)), label + " applies selected range")
		var body := state.call("build_spline_roll_preview_body") as Resource
		if not _check(body != null, label + " prepares source"):
			continue
		var points: PackedVector3Array = body.get("path_points")
		var spacing_ok := points.size() == 6
		for point_index in range(points.size() - 1):
			spacing_ok = spacing_ok and absf(points[point_index].distance_to(points[point_index + 1]) - 0.15) < EPSILON
		_check(spacing_ok, label + " keeps six straight points 15cm apart")
		var mesh := presenter.call("_build_active_material_body_sweep_mesh", body) as ArrayMesh
		_assert_native_closed_mesh(body, label, mesh)
		_check(ResourceSaver.save(body, artifact_dir.path_join(String(fixture.name) + "_body.tres")) == OK, label + " source artifact saved")
		if mesh != null and mesh.get_surface_count() > 0:
			_check(ResourceSaver.save(mesh, artifact_dir.path_join(String(fixture.name) + "_mesh.res")) == OK, label + " mesh artifact saved for rendered inspection")
	_test_fluted_zero_fixed_boundary(fluted, artifact_dir)
	_check(var_to_bytes(source_profiles) == source_bytes, "real profile library remains unchanged during all fixtures")


func _test_fluted_zero_fixed_boundary(fluted: Dictionary, artifact_dir: String) -> void:
	var state := _state()
	if not _check(bool(state.call("select_active_saved_basic_profile", fluted.duplicate(true))), "Fluted Taper_test selects original profile"):
		return
	for point_index in range(5):
		state.call("append_spline_line_point", Vector3(float(point_index) * 0.15, 0, 0), Vector3.UP)
	for point_index in range(5):
		state.call("set_spline_line_point_profile_scale", point_index,
			Vector2.ZERO if point_index == 4 else Vector2(0.05, 0.05))
	var accepted := true
	for roles: PackedInt32Array in [PackedInt32Array([0, 1, 2]), PackedInt32Array([3, 2]), PackedInt32Array([4, 3])]:
		accepted = bool(state.call("set_spline_line_profile_transform", roles, Vector2(2, 2))) and accepted
	_check(accepted, "Fluted Taper_test applies the user's three ranges on five 15cm-spaced controls")
	var body := state.call("build_spline_roll_preview_body") as Resource
	if not _check(body != null, "Fluted Taper_test prepares its combined range source"):
		return
	var ranges: Array = body.get("path_profile_transform_ranges")
	_check(ranges.size() == 3 and int(ranges[2].fixed_a) == 4
		and ranges[2].fixed_a_scale == Vector2.ZERO and ranges[2].scale == Vector2(2, 2),
		"Fluted Taper_test retains its collapsed fixed boundary rather than only a collapsed target")
	var mesh := presenter.call("_build_active_material_body_sweep_mesh", body) as ArrayMesh
	_assert_native_closed_mesh(body, "Fluted Taper_test zero fixed boundary", mesh)
	_check(ResourceSaver.save(body, artifact_dir.path_join("zero_fixed_boundary_body.tres")) == OK,
		"Fluted Taper_test zero fixed boundary source artifact saved")
	if mesh != null and mesh.get_surface_count() > 0:
		_check(ResourceSaver.save(mesh, artifact_dir.path_join("zero_fixed_boundary_mesh.res")) == OK,
			"Fluted Taper_test zero fixed boundary mesh artifact saved")


func _test_generated_and_retained_source() -> void:
	var state := _state()
	_seed(state)
	state.call("set_spline_line_point_profile_scale", 2, Vector2(0.05, 0.25))
	_check(bool(state.call("generate_spline_line_csg_noodle")), "tapered spline generates")
	var body := state.call("get_selected_material_body") as Resource
	if not _check(body != null, "generated source exists"):
		return
	var scales: PackedVector2Array = body.get("path_profile_scales")
	_check(scales == PackedVector2Array([Vector2.ONE, Vector2.ONE, Vector2(0.05, 0.25)]), "generated source stores authored scales")
	_check(_scales(state).is_empty(), "Generate clears transient scales")
	_check(state.call("commit_pending_material_bodies_as_layer") != null, "tapered spline commits to retained history")
	var body_id := StringName(body.get("body_id"))
	_check(bool((state.call("begin_retained_spline_change", body_id) as Dictionary).get("ok", false)), "retained E source opens")
	_check(_scales(state) == scales, "retained edit restores scale data")
	state.call("set_spline_line_point_profile_scale", 1, Vector2(1.5, 0.5))
	var preview := state.call("build_spline_roll_preview_body") as Resource
	_check(preview != null and (preview.get("path_profile_scales") as PackedVector2Array)[1].is_equal_approx(Vector2(1.5, 0.5)), "retained preview contains edited scale")
	_check(body.get("path_profile_scales") == scales, "retained preview leaves committed source intact")
	state.call("cancel_retained_spline_change")
	state.call("begin_retained_spline_change", body_id)
	state.call("set_spline_line_point_profile_scale", 1, Vector2(1.5, 0.5))
	var candidate := state.call("build_retained_spline_change_candidate") as Dictionary
	if _check(bool(candidate.get("ok", false)), "retained Transform builds replacement candidate"):
		_check(bool(state.call("accept_retained_spline_change_candidate", candidate)), "retained Transform replacement installs")
		body = state.call("_find_material_body_by_id", body_id) as Resource
		if body != null:
			scales = body.get("path_profile_scales")
			_check(scales[1].is_equal_approx(Vector2(1.5, 0.5)), "accepted retained source keeps changed scale")
	else:
		state.call("cancel_retained_spline_change")
	DirAccess.make_dir_recursive_absolute(STATE_PATH.get_base_dir())
	_check(ResourceSaver.save(state, STATE_PATH) == OK, "authoring Resource saves to isolated artifact")
	var loaded := ResourceLoader.load(STATE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if _check(loaded != null, "authoring Resource reloads cold"):
		var reopened := loaded.call("_find_material_body_by_id", body_id) as Resource
		_check(reopened != null and reopened.get("path_profile_scales") == scales, "disk reload preserves generated scales")
		if reopened != null:
			_check(_mesh_bytes(body) == _mesh_bytes(reopened), "reopened source produces identical mesh")


func _test_detailing() -> void:
	var state := _state(State.TOOL_DETAILING_BRUSH)
	var polygon := PackedVector2Array([Vector2(-0.01, -0.005), Vector2(0.01, -0.005), Vector2(0.01, 0.005), Vector2(-0.01, 0.005)])
	_check(bool(state.call("select_active_saved_basic_profile", {
		"profile_id": &"transform_detail", "id": &"transform_detail", "label": "Transform Detail",
		"family": Profiles.PROFILE_FAMILY_BASIC, "base_polygon_2d_meters": polygon,
		"polygon_2d_meters": polygon, "base_anchor_2d_meters": Vector2.ZERO,
		"anchor_x_meters": 0.0, "anchor_y_meters": 0.0, "rotation_degrees": 0.0,
	})), "Detail profile selected")
	var points := PackedVector3Array([Vector3.ZERO, Vector3(0.01, 0, 0), Vector3(0.04, 0, 0), Vector3(0.07, 0, 0), Vector3(0.08, 0, 0)])
	var controls := PackedVector3Array([points[0], points[2], points[4]])
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	var control_normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	var contacts := PackedVector3Array([Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN])
	_check(bool(state.call("replace_detailing_brush_path_solution", controls, control_normals,
		&"target_material_surface", &"transform_detail_surface", points, normals,
		PackedInt32Array([0, 2, 4]), [true, true], [&"none", &"none"], true, &"none", 1,
		PackedVector3Array([Vector3.DOWN, Vector3.DOWN, Vector3.DOWN]), contacts)), "Detail resolved path accepted")
	_check(bool(state.call("set_spline_line_point_profile_scale", 1, Vector2(2, 0.2))), "Detail control accepts independent axes")
	var preview := state.call("build_spline_roll_preview_body") as Resource
	if not _check(preview != null, "Detail transform has detached shared preview source"):
		return
	var expected := PackedVector2Array([Vector2.ONE, Vector2(1.25, 0.8), Vector2(2, 0.2), Vector2(1.25, 0.8), Vector2.ONE])
	var scales: PackedVector2Array = preview.get("path_profile_scales")
	var matching := scales.size() == expected.size()
	for index in range(mini(scales.size(), expected.size())):
		matching = matching and scales[index].is_equal_approx(expected[index])
	_check(matching, "Detail resamples scales by span distance rather than sample number")
	_check(preview.get("path_points") == points, "Detail transform preserves surface-resolved centreline")
	var curve := Roll.build_body_curve(preview, 0.004)
	if _check(curve != null, "Detail frame source builds"):
		var original_frames: Dictionary = curve.get_meta(Roll.FRAME_METADATA)
		_check(original_frames.get("points") == points, "Detail without bounded Transform keeps its original sample count and positions")
		_assert_sample_ring_vertices(preview, curve, "surface-following transformed Detail")
	var range_state: Resource = state.duplicate(true)
	range_state.call("set_spline_line_point_profile_scale", 1, Vector2.ONE)
	_check(bool(range_state.call("set_spline_line_profile_transform", PackedInt32Array([0, 1]), Vector2(2, 0.5))), "Detail accepts hard-bounded range Transform")
	var range_preview := range_state.call("build_spline_roll_preview_body") as Resource
	if _check(range_preview != null, "Detail range produces shared preview source"):
		var mapped_ranges: Array = range_preview.get("path_profile_transform_ranges")
		_check(mapped_ranges.size() == 1 and int(mapped_ranges[0].fixed_a) == 0 and int(mapped_ranges[0].scaled) == 2,
			"Detail range boundaries map authored controls through resolved span offsets")
		var range_curve := Roll.build_body_curve(range_preview, 0.004)
		if _check(range_curve != null, "Detail hard-boundary frame source builds"):
			var range_data: Dictionary = range_curve.get_meta(Roll.FRAME_METADATA)
			var quarter_frame := Roll.sample_frame(range_curve, 0.01)
			var extents := Scale.profile_extents(range_preview)
			_check((quarter_frame.profile_scale as Vector2).distance_to(_circular_expected(Vector2.ONE, Vector2(2, 0.5), 0.25, 0.04, extents)) < EPSILON,
				"short Detail taper reaches its straight remainder after the circular lead")
			var range_points: PackedVector3Array = range_data.points
			var range_distances: PackedFloat64Array = range_data.distances
			var physical_arc_samples := 0
			var detail_radius := 0.002
			var detail_height := extents.x
			var detail_slope := _circle_tangent_slope(0.04, detail_height, detail_radius)
			var detail_arc_end := detail_radius * detail_slope / sqrt(1.0 + detail_slope * detail_slope)
			var circle_matches := true
			var unchanged_after_range := 0
			for sample_index in range(range_points.size()):
				if range_distances[sample_index] > 0.04 + EPSILON:
					unchanged_after_range += 1
				elif range_distances[sample_index] > 0.0 and range_distances[sample_index] < detail_arc_end:
					physical_arc_samples += 1
					var ring_frame := Roll.sample_frame_at_index(range_curve, sample_index)
					var physical_y := absf((ring_frame.profile_scale as Vector2).x - 1.0) * extents.x
					var physical_x := range_distances[sample_index]
					circle_matches = circle_matches and absf(physical_x * physical_x + pow(physical_y - detail_radius, 2) - detail_radius * detail_radius) < 1.0e-10
			_check(physical_arc_samples >= 7 and circle_matches, "Detail lead has actual mesh rings on its physical-radius circle")
			_check(range_points.size() > points.size() and unchanged_after_range == 2,
				"short Detail taper gains circular lead samples only within its selected extent")
			var preserved_frames: bool = range_preview.get("path_points") == points
			for source_index in range(points.size()):
				var original_frame := Profiles.resolve_explicit_surface_profile_path_frame(
					Profiles.resolve_linear_path_point_tangent(points, source_index), normals[source_index],
					range_preview.get("profile_contact_direction_2d"), range_preview.get("profile_contact_point_relative_2d_meters"),
					contacts[source_index], float(range_preview.get("profile_rotation_bias_degrees")))
				var sampled_frame := Roll.sample_frame(range_curve, points[source_index].x)
				preserved_frames = preserved_frames and (sampled_frame.position as Vector3).is_equal_approx(points[source_index]) \
					and (sampled_frame.axis_x as Vector3).is_equal_approx(original_frame.axis_x) \
					and (sampled_frame.axis_y as Vector3).is_equal_approx(original_frame.axis_y)
			_check(preserved_frames, "Detail easing retains every resolved source position and its explicit contact frame")
			var sections: PackedInt32Array = range_data.get("section_starts", PackedInt32Array())
			if _check(sections.size() == 2, "Detail splits transformed and original spans at one hard boundary"):
				var incoming := Roll.sample_frame_at_index(range_curve, sections[1] - 1)
				var outgoing := Roll.sample_frame_at_index(range_curve, sections[1])
				_check((incoming.position as Vector3).is_equal_approx(points[2]) and (outgoing.position as Vector3).is_equal_approx(points[2]),
					"Detail hard boundary duplicates the actual resolved surface point")
				_check((incoming.profile_scale as Vector2).is_equal_approx(Vector2(2, 0.5))
					and (outgoing.profile_scale as Vector2).is_equal_approx(Vector2.ONE), "Detail outgoing span remains untransformed")
				var frame := Profiles.resolve_explicit_surface_profile_path_frame(
					Profiles.resolve_linear_path_point_tangent(points, 2), normals[2],
					range_preview.get("profile_contact_direction_2d"), range_preview.get("profile_contact_point_relative_2d_meters"),
					contacts[2], float(range_preview.get("profile_rotation_bias_degrees")))
				_check((incoming.axis_x as Vector3).is_equal_approx(frame.axis_x)
					and (incoming.axis_y as Vector3).is_equal_approx(frame.axis_y)
					and incoming.axis_x == outgoing.axis_x and incoming.axis_y == outgoing.axis_y,
					"Detail incoming/outgoing rings preserve exact existing contact frames")
		_assert_native_closed_mesh(range_preview, "Detail opposed-axis hard boundary")
	_check(bool(state.call("generate_detailing_brush")), "transformed Detail generates")
	var generated := state.call("get_selected_material_body") as Resource
	if _check(generated != null, "generated Detail exists"):
		_check(generated.get("path_profile_scales") == scales, "Detail preview/generation scales agree")
		_check(generated.get("path_contact_directions") == contacts, "Detail retains explicit surface-contact directions")
		_check(_mesh_bytes(generated) == _mesh_bytes(preview), "Detail preview source and generated source yield identical geometry")


func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
	return condition
