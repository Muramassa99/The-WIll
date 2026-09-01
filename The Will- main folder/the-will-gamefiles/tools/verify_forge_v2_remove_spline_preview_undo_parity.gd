extends SceneTree

const ControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const WorkspaceScript = preload(
	"res://runtime/forge_v2/forge_v2_workspace_preview.gd"
)
const StateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const BodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ProfileScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const SplineSamplerScript = preload(
	"res://runtime/forge_v2/forge_v2_spline_path_sampler.gd"
)
const StrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_remove_spline_preview_undo_parity.json"
)
const POSITION_TOLERANCE_METERS := 0.00025

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var add_case := await _run_case(StrokeScript.OPERATION_ADD_MATERIAL)
	var remove_case := await _run_case(StrokeScript.OPERATION_REMOVE_MATERIAL)
	_record("add_u_spline", add_case)
	_record("remove_u_spline", remove_case)
	var geometry_parity := _geometry_parity(add_case, remove_case)
	_record("shared_add_remove_geometry", geometry_parity)
	var report := {
		"schema": "forge_v2_remove_spline_preview_undo_parity",
		"schema_version": 1,
		"ok": _failures.is_empty(),
		"checks": _checks,
		"failures": _failures,
	}
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("FORGE_V2_REMOVE_SPLINE_PREVIEW_UNDO_PARITY=" + JSON.stringify(
		report
	))
	if not _failures.is_empty():
		push_error("Remove spline preview/Undo parity failed: %s" % (
			"; ".join(_failures)
		))
	quit(0 if _failures.is_empty() else 1)


func _run_case(operation_mode: StringName) -> Dictionary:
	var fixture := await _fixture(String(operation_mode))
	var controller := fixture.controller as Node
	var presenter := fixture.presenter as Node3D
	var profile := _profile()
	var base := await _build_fallback_base(controller, presenter, profile)
	var configured := _configure(controller, operation_mode, profile)
	var controls := _u_points()
	var normals := PackedVector3Array()
	for point: Vector3 in controls:
		normals.append(Vector3.FORWARD)
		controller.call("append_spline_line_point", point, Vector3.FORWARD)
	var finished := bool(controller.call("finish_spline_line"))
	var generated := bool(controller.call("generate_spline_line_csg_noodle"))
	await _settle(8)

	var state := controller.call("get_active_authoring_state") as Resource
	var body := state.call("get_selected_material_body") as Resource
	var body_id := StringName(body.get("body_id")) if body != null else StringName()
	var preview := _preview_packet(presenter, body_id)
	var curve := _curve_parity(presenter, body, preview)
	var authored_points := (
		body.get("path_points") as PackedVector3Array
		if body != null else PackedVector3Array()
	)
	var authored_normals := (
		body.get("path_surface_normals") as PackedVector3Array
		if body != null else PackedVector3Array()
	)
	var before_undo := _visible_publication(presenter)
	var body_count_before := (state.get("material_bodies") as Array).size()
	var pending_before := int(state.call("get_pending_material_body_count"))
	var undone := bool(controller.call("undo_latest_action"))
	await _settle(12)
	var restored_points := state.get("spline_line_points") as PackedVector3Array
	var restored_normals := (
		state.get("spline_line_surface_normals") as PackedVector3Array
	)
	var after_undo := _visible_publication(presenter)
	var body_count_after := (state.get("material_bodies") as Array).size()
	var pending_after := int(state.call("get_pending_material_body_count"))

	var ok := (
		bool(base.ok)
		and configured
		and finished
		and generated
		and body != null
		and StringName(body.get("operation_mode")) == operation_mode
		and StringName(body.get("shape_kind"))
		== BodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
		and _same_points(authored_points, controls)
		and _same_points(authored_normals, normals)
		and bool(preview.visible)
		and bool(curve.ok)
		and body_count_before == 2
		and pending_before == 1
		and undone
		and body_count_after == 1
		and pending_after == 0
		and _same_points(restored_points, controls)
		and _same_points(restored_normals, normals)
		and bool(before_undo.visible)
		and bool(after_undo.visible)
	)
	var result := {
		"ok": ok,
		"operation_mode": String(operation_mode),
		"base": base,
		"configured": configured,
		"finished": finished,
		"generated": generated,
		"raw_control_count": authored_points.size(),
		"raw_points_retained": _same_points(authored_points, controls),
		"raw_normals_retained": _same_points(authored_normals, normals),
		"preview": _preview_report(preview),
		"curve": curve,
		"body_count_before_undo": body_count_before,
		"pending_before_undo": pending_before,
		"undone": undone,
		"body_count_after_undo": body_count_after,
		"pending_after_undo": pending_after,
		"dots_restored": _same_points(restored_points, controls),
		"normals_restored": _same_points(restored_normals, normals),
		"publication_before_undo": before_undo,
		"publication_after_undo": after_undo,
		"_vertices": preview.vertices,
		"_indices": preview.indices,
	}
	await _dispose(fixture)
	return result


func _build_fallback_base(
	controller: Node,
	presenter: Node3D,
	profile: Dictionary
) -> Dictionary:
	var configured := _configure(
		controller,
		StrokeScript.OPERATION_ADD_MATERIAL,
		profile
	)
	for point: Vector3 in [
		Vector3(-0.42, -0.34, 0.0),
		Vector3(0.42, -0.34, 0.0),
	]:
		controller.call("append_spline_line_point", point, Vector3.FORWARD)
	var finished := bool(controller.call("finish_spline_line"))
	var generated := bool(controller.call("generate_spline_line_csg_noodle"))
	var committed := (
		controller.call("commit_pending_material_bodies_as_layer") as Resource
		!= null
	)
	await _settle_until_idle(controller, 40)
	await _settle(8)
	var state := controller.call("get_active_authoring_state") as Resource
	var publication := _visible_publication(presenter)
	return {
		"ok": (
			configured and finished and generated and committed
			and int(state.call("get_committed_layer_count")) == 1
			and int(state.call("get_pending_material_body_count")) == 0
			and bool(publication.visible)
		),
		"committed": committed,
		"publication": publication,
	}


func _configure(
	controller: Node,
	operation_mode: StringName,
	profile: Dictionary
) -> bool:
	controller.call("set_active_operation_mode", operation_mode)
	controller.call("set_active_tool_id", StateScript.TOOL_SPLINE_LINE)
	var profile_selected := bool(controller.call(
		"select_active_saved_basic_profile",
		profile
	))
	var state := controller.call("get_active_authoring_state") as Resource
	return (
		profile_selected
		and StringName(state.get("active_operation_mode")) == operation_mode
		and StringName(state.get("active_tool_id"))
		== StateScript.TOOL_SPLINE_LINE
	)


func _curve_parity(
	presenter: Node3D,
	body: Resource,
	preview: Dictionary
) -> Dictionary:
	if body == null:
		return {"ok": false, "reason": "body_missing"}
	var source_points := body.get("path_points") as PackedVector3Array
	var source_normals := body.get("path_surface_normals") as PackedVector3Array
	var radius := maxf(float(body.get("radius_meters")), 0.001)
	if int(body.get("profile_runtime_schema_version")) > 0:
		radius = maxf(
			float(body.get("profile_contact_distance_meters")),
			ProfileScript.BASIC_PROFILE_ANCHOR_CLEARANCE_METERS
		)
	var interval := float(presenter.call(
		"_resolve_spline_csg_path_interval",
		radius
	))
	var curve := SplineSamplerScript.build_auto_curve(
		source_points,
		interval,
		true
	)
	var samples := curve.get_baked_points()
	var polygon := body.get("profile_polygon_2d_meters") as PackedVector2Array
	polygon = presenter.call(
		"_ensure_counter_clockwise_profile_polygon",
		polygon
	) as PackedVector2Array
	var vertices := preview.vertices as PackedVector3Array
	var matched_rings := 0
	var maximum_error := 0.0
	for sample_index in range(samples.size()):
		var center := samples[sample_index]
		var tangent := ProfileScript.resolve_linear_path_point_tangent(
			samples,
			sample_index
		)
		var normal := ProfileScript.resolve_path_surface_normal(
			center,
			source_points,
			source_normals
		)
		var frame := ProfileScript.resolve_profile_path_frame(
			tangent,
			normal,
			body.get("profile_contact_direction_2d") as Vector2,
			float(body.get("profile_rotation_bias_degrees"))
		)
		var ring_matches := true
		for profile_point: Vector2 in polygon:
			var expected := (
				center
				+ (frame.axis_x as Vector3) * profile_point.x
				+ (frame.axis_y as Vector3) * profile_point.y
			)
			var error := _nearest_distance(expected, vertices)
			maximum_error = maxf(maximum_error, error)
			if error > POSITION_TOLERANCE_METERS:
				ring_matches = false
		if ring_matches:
			matched_rings += 1
	var all_rings_match := (
		samples.size() > source_points.size()
		and matched_rings == samples.size()
	)
	return {
		"ok": all_rings_match,
		"authored_point_count": source_points.size(),
		"sampled_point_count": samples.size(),
		"sample_interval_meters": interval,
		"matched_ring_count": matched_rings,
		"maximum_error_meters": maximum_error,
		"tolerance_meters": POSITION_TOLERANCE_METERS,
	}


func _preview_packet(presenter: Node3D, body_id: StringName) -> Dictionary:
	var result := {
		"visible": false,
		"surface_count": 0,
		"vertices": PackedVector3Array(),
		"indices": PackedInt32Array(),
	}
	var preview_root := presenter.get("csg_active_body_root") as Node3D
	for child: Node in preview_root.get_children():
		if StringName(child.get_meta(
			"forge_v2_pending_body_id",
			StringName()
		)) != body_id or not child is MeshInstance3D:
			continue
		var mesh := (child as MeshInstance3D).mesh
		if mesh == null or mesh.get_surface_count() == 0:
			break
		var arrays := mesh.surface_get_arrays(0)
		result.surface_count = mesh.get_surface_count()
		result.vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		result.indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		result.visible = (
			preview_root.visible
			and (child as MeshInstance3D).visible
			and not (result.vertices as PackedVector3Array).is_empty()
		)
		break
	return result


func _preview_report(preview: Dictionary) -> Dictionary:
	return {
		"visible": bool(preview.visible),
		"surface_count": int(preview.surface_count),
		"vertex_count": (preview.vertices as PackedVector3Array).size(),
		"triangle_count": (preview.indices as PackedInt32Array).size() / 3,
	}


func _visible_publication(presenter: Node3D) -> Dictionary:
	var combined := presenter.get("csg_material_body_root") as Node3D
	var static_root := presenter.get("csg_static_body_root") as Node3D
	var native_root := presenter.get("native_static_body_root") as Node3D
	var static_surfaces := _visible_surface_count(static_root)
	var native_surfaces := _visible_surface_count(native_root)
	return {
		"visible": (
			combined != null and combined.visible
			and static_surfaces + native_surfaces > 0
		),
		"static_root_visible": static_root != null and static_root.visible,
		"native_root_visible": native_root != null and native_root.visible,
		"static_surface_count": static_surfaces,
		"native_surface_count": native_surfaces,
	}


func _visible_surface_count(node: Node) -> int:
	if node == null or (node is Node3D and not (node as Node3D).visible):
		return 0
	var count := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		count += (node as MeshInstance3D).mesh.get_surface_count()
	elif node is CSGShape3D:
		for value: Variant in (node as CSGShape3D).get_meshes():
			if value is Mesh:
				count += (value as Mesh).get_surface_count()
	for child: Node in node.get_children():
		count += _visible_surface_count(child)
	return count


func _geometry_parity(add_case: Dictionary, remove_case: Dictionary) -> Dictionary:
	var add_vertices := add_case._vertices as PackedVector3Array
	var remove_vertices := remove_case._vertices as PackedVector3Array
	var add_indices := add_case._indices as PackedInt32Array
	var remove_indices := remove_case._indices as PackedInt32Array
	var vertices_match := _same_points(add_vertices, remove_vertices)
	var indices_match := add_indices == remove_indices
	return {
		"ok": (
			bool(add_case.ok) and bool(remove_case.ok)
			and not add_vertices.is_empty()
			and vertices_match and indices_match
		),
		"vertices_match": vertices_match,
		"indices_match": indices_match,
		"add_vertex_count": add_vertices.size(),
		"remove_vertex_count": remove_vertices.size(),
	}


func _record(name: String, source: Dictionary) -> void:
	var evidence := source.duplicate(true)
	evidence.erase("_vertices")
	evidence.erase("_indices")
	_checks[name] = evidence
	if not bool(source.get("ok", false)):
		_failures.append(name)


func _profile() -> Dictionary:
	var square := PackedVector2Array([
		Vector2(-0.006, -0.006), Vector2(0.006, -0.006),
		Vector2(0.006, 0.006), Vector2(-0.006, 0.006),
	])
	return {
		"profile_id": &"remove_spline_parity_square",
		"id": &"remove_spline_parity_square",
		"label": "Remove Spline Parity Square",
		"family": ProfileScript.PROFILE_FAMILY_BASIC,
		"base_polygon_2d_meters": square,
		"polygon_2d_meters": square,
		"base_anchor_2d_meters": Vector2(0.0, -0.006),
		"anchor_x_meters": 0.0,
		"anchor_y_meters": -0.006,
		"rotation_degrees": 0.0,
	}


func _u_points() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-0.32, 0.20, 0.0), Vector3(-0.16, -0.18, 0.0),
		Vector3(0.16, -0.18, 0.0), Vector3(0.32, 0.20, 0.0),
	])


func _same_points(
	first: PackedVector3Array,
	second: PackedVector3Array
) -> bool:
	if first.size() != second.size():
		return false
	for index in range(first.size()):
		if first[index].distance_to(second[index]) > 0.000001:
			return false
	return true


func _nearest_distance(target: Vector3, vertices: PackedVector3Array) -> float:
	var nearest_squared := INF
	for vertex: Vector3 in vertices:
		nearest_squared = minf(
			nearest_squared,
			target.distance_squared_to(vertex)
		)
	return sqrt(nearest_squared)


func _fixture(label: String) -> Dictionary:
	var controller := ControllerScript.new() as Node
	controller.name = "%sController" % label
	root.add_child(controller)
	var workspace := WorkspaceScript.new() as Node3D
	workspace.name = "%sWorkspace" % label
	root.add_child(workspace)
	await process_frame
	workspace.call("bind_stage_controller", controller)
	await _settle(6)
	return {
		"controller": controller,
		"workspace": workspace,
		"presenter": workspace.get("volume_preview_presenter") as Node3D,
	}


func _dispose(fixture: Dictionary) -> void:
	var workspace := fixture.workspace as Node3D
	var controller := fixture.controller as Node
	workspace.call("clear_stage_controller")
	workspace.queue_free()
	controller.queue_free()
	await process_frame


func _settle(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await process_frame


func _settle_until_idle(controller: Node, frame_limit: int) -> void:
	for _frame_index in range(frame_limit):
		await process_frame
		var state := controller.call("get_active_authoring_state") as Resource
		if (
			int(controller.call("get_deferred_material_body_commit_count")) == 0
			and not bool(state.call("has_pending_bounded_history_promotion"))
		):
			await _settle(3)
			return
