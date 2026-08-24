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
const ForgeV2SplinePathSamplerScript = preload(
	"res://runtime/forge_v2/forge_v2_spline_path_sampler.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_detailing_brush_presenter_2026-08-10.txt"
)
const EPSILON := 0.00001
const PREVIEW_LINE_RADIUS_METERS := 0.014
const PREVIEW_POINT_RADIUS_METERS := 0.028
const PREVIEW_SELECTED_POINT_RADIUS_METERS := 0.038
const TUBE_INDEX_COUNT_PER_SEGMENT := 12 * 6
const SPHERE_INDEX_COUNT_PER_MARKER := 6 * 12 * 6


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	root.add_child(presenter)

	var detail_state: Resource = ForgeV2AuthoringStateScript.new()
	detail_state.active_tool_id = (
		ForgeV2AuthoringStateScript.TOOL_DETAILING_BRUSH
	)
	detail_state.spline_line_points = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.18, 0.0, 0.0),
		Vector3(0.36, 0.0, 0.0),
	])
	detail_state.spline_line_surface_normals = PackedVector3Array([
		Vector3.UP,
		Vector3.BACK,
		Vector3(0.0, 1.0, 1.0).normalized(),
	])
	detail_state.selected_spline_point_index = 1
	detail_state.spline_line_finished = false
	detail_state.detailing_surface_target_kind = &"material_surface"
	detail_state.detailing_surface_target_id = &"surface_zone_verify"
	detail_state.detailing_resolved_path_points = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.06, 0.01, 0.14),
		Vector3(0.12, 0.02, 0.16),
		Vector3(0.18, 0.0, 0.0),
		Vector3(0.25, -0.01, -0.13),
		Vector3(0.36, 0.0, 0.0),
	])
	detail_state.detailing_resolved_surface_normals = PackedVector3Array([
		Vector3.UP,
		Vector3.UP,
		Vector3.BACK,
		Vector3.BACK,
		Vector3(0.0, 1.0, 1.0).normalized(),
		Vector3(0.0, 1.0, 1.0).normalized(),
	])
	detail_state.detailing_span_offsets = PackedInt32Array([0, 3, 5])
	var detail_span_validity: Array[bool] = [true, false]
	detail_state.detailing_span_validity = detail_span_validity
	var detail_span_reasons: Array[StringName] = [
		&"none",
		&"target_miss",
	]
	detail_state.detailing_span_reasons = detail_span_reasons
	detail_state.detailing_solution_valid = false
	detail_state.detailing_solution_reason = &"target_miss"

	presenter.call("_sync_spline_preview_mesh", detail_state)
	var normal_instance := presenter.get_node_or_null(
		"SplineLinePreviewMesh"
	) as MeshInstance3D
	var invalid_instance := presenter.get_node_or_null(
		"SplineLineInvalidPreviewMesh"
	) as MeshInstance3D
	_require(
		normal_instance != null
		and normal_instance.visible
		and normal_instance.mesh != null,
		"Detailing Brush normal preview mesh was not presented"
	)
	_require(
		invalid_instance != null
		and invalid_instance.visible
		and invalid_instance.mesh != null,
		"Detailing Brush invalid span did not get a red preview mesh"
	)
	var normal_mesh := normal_instance.mesh
	var invalid_mesh := invalid_instance.mesh
	_require(
		_mesh_index_count(normal_mesh)
		== (
			3 * TUBE_INDEX_COUNT_PER_SEGMENT
			+ 3 * SPHERE_INDEX_COUNT_PER_MARKER
		),
		"valid-span/marker partition emitted an unexpected index count"
	)
	_require(
		_mesh_index_count(invalid_mesh)
		== 2 * TUBE_INDEX_COUNT_PER_SEGMENT,
		"invalid-span partition did not isolate its two dense segments"
	)
	_require(
		_mesh_all_colors_match(
			invalid_mesh,
			Color(1.0, 0.08, 0.04, 0.98),
			0.01
		),
		"invalid span vertex color was not clear red"
	)
	_require(
		_mesh_bounds(normal_mesh).end.z > 0.12,
		"normal preview rebuilt a second control spline instead of using dense points"
	)
	_require(
		_mesh_bounds(invalid_mesh).position.z < -0.1,
		"invalid preview ignored the authoritative dense invalid span"
	)
	_require(
		_mesh_contains_vertex(
			normal_mesh,
			detail_state.spline_line_points[0]
			+ Vector3.UP * PREVIEW_POINT_RADIUS_METERS,
			EPSILON
		)
		and _mesh_contains_vertex(
			normal_mesh,
			detail_state.spline_line_points[1]
			+ Vector3.UP * PREVIEW_SELECTED_POINT_RADIUS_METERS,
			EPSILON
		)
		and _mesh_contains_vertex(
			normal_mesh,
			detail_state.spline_line_points[2]
			+ Vector3.UP * PREVIEW_POINT_RADIUS_METERS,
			EPSILON
		),
		"control dots were not retained as exact pass-through markers"
	)
	_require(
		normal_instance.get_meta(
			"forge_v2_detail_control_points"
		) == detail_state.spline_line_points,
		"presenter metadata did not retain exact authored control points"
	)
	_require(
		normal_instance.get_meta(
			"forge_v2_detail_resolved_points"
		) == detail_state.detailing_resolved_path_points,
		"presenter did not consume the authoritative resolved point array"
	)
	_require(
		normal_instance.get_meta(
			"forge_v2_detail_span_offsets"
		) == detail_state.detailing_span_offsets,
		"presenter changed the authoritative span offsets"
	)
	_require(
		_invalid_material_is_red(invalid_instance.material_override),
		"invalid span material was not independently red-emissive"
	)

	var free_control_points := PackedVector3Array([
		Vector3.ZERO,
		Vector3(0.11, 0.07, 0.02),
		Vector3(0.22, -0.03, 0.01),
	])
	var presenter_free_curve: Curve3D = presenter.call(
		"_build_spline_curve",
		free_control_points,
		0.015
	) as Curve3D
	var shared_free_curve := ForgeV2SplinePathSamplerScript.build_auto_curve(
		free_control_points,
		0.015,
		true
	)
	_require(
		_curves_match(presenter_free_curve, shared_free_curve),
		"free spline output changed while moving its handle law to the shared sampler"
	)

	var detail_body: Resource = ForgeV2MaterialBodyScript.new()
	detail_body.body_kind = ForgeV2MaterialBodyScript.BODY_KIND_DETAILING_BRUSH
	detail_body.shape_kind = ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
	detail_body.surface_target_kind = &"material_surface"
	detail_body.surface_target_id = &"surface_zone_verify"
	detail_body.material_variant_id = &"mat_iron_gray"
	detail_body.path_points = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.09, 0.01, 0.025),
		Vector3(0.19, 0.045, 0.015),
	])
	detail_body.path_surface_normals = PackedVector3Array([
		Vector3.UP,
		Vector3.BACK,
		Vector3(0.0, 1.0, 1.0).normalized(),
	])
	detail_body.profile_polygon_2d_meters = PackedVector2Array([
		Vector2(-0.026, -0.012),
		Vector2(0.031, -0.008),
		Vector2(0.018, 0.024),
		Vector2(-0.021, 0.019),
	])
	detail_body.profile_contact_direction_2d = Vector2(0.32, -0.95).normalized()
	detail_body.profile_rotation_bias_degrees = 23.0
	detail_body.profile_runtime_schema_version = 1
	detail_body.normalize()
	_require(
		detail_body.body_kind
		== ForgeV2MaterialBodyScript.BODY_KIND_DETAILING_BRUSH
		and detail_body.shape_kind
		== ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH,
		"Detail body lost its semantic kind or linear profile shape"
	)

	var live_mesh: ArrayMesh = presenter.call(
		"_build_active_material_body_sweep_mesh",
		detail_body
	) as ArrayMesh
	_require(
		live_mesh != null and live_mesh.get_surface_count() > 0,
		"generated Detail body did not pass through live sweep preview"
	)
	for point_index in range(detail_body.path_points.size()):
		var tangent := _resolve_linear_tangent(
			detail_body.path_points,
			point_index
		)
		var frame := ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
			tangent,
			detail_body.path_surface_normals[point_index],
			detail_body.profile_contact_direction_2d,
			detail_body.profile_rotation_bias_degrees
		)
		var expected_ring_vertex: Vector3 = (
			detail_body.path_points[point_index]
			+ (frame.get("axis_x", Vector3.RIGHT) as Vector3)
			* detail_body.profile_polygon_2d_meters[0].x
			+ (frame.get("axis_y", Vector3.UP) as Vector3)
			* detail_body.profile_polygon_2d_meters[0].y
		)
		_require(
			_mesh_contains_vertex(live_mesh, expected_ring_vertex, EPSILON),
			"live Detail sweep did not align ring %d to its paired normal"
			% point_index
		)

	var csg_parent := Node3D.new()
	root.add_child(csg_parent)
	_require(
		bool(presenter.call(
			"_append_csg_body_shape",
			csg_parent,
			detail_body,
			&"mat_iron_gray",
			false,
			0
		)),
		"generated Detail body did not pass through static CSG presentation"
	)
	var detail_path := _find_path_child(csg_parent)
	_require(
		detail_path != null and detail_path.curve != null,
		"static Detail profile did not create a CSG path"
	)
	var detail_curve := detail_path.curve
	_require(
		detail_curve.point_count == detail_body.path_points.size(),
		"static Detail profile resampled or curved its authoritative linear path"
	)
	var previous_expected_tilt := 0.0
	var has_previous_expected_tilt := false
	for point_index in range(detail_curve.point_count):
		_require(
			detail_curve.get_point_position(point_index).is_equal_approx(
				detail_body.path_points[point_index]
			)
			and detail_curve.get_point_in(point_index) == Vector3.ZERO
			and detail_curve.get_point_out(point_index) == Vector3.ZERO,
			"static Detail path was not kept linear at point %d" % point_index
		)
		var tangent := _resolve_linear_tangent(
			detail_body.path_points,
			point_index
		)
		var frame := ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
			tangent,
			detail_body.path_surface_normals[point_index],
			detail_body.profile_contact_direction_2d,
			detail_body.profile_rotation_bias_degrees
		)
		var expected_tilt := float(frame.get("tilt_radians", 0.0))
		if has_previous_expected_tilt:
			while expected_tilt - previous_expected_tilt > PI:
				expected_tilt -= TAU
			while expected_tilt - previous_expected_tilt < -PI:
				expected_tilt += TAU
		_require(
			is_equal_approx(
				detail_curve.get_point_tilt(point_index),
				expected_tilt
			),
			"static Detail path ignored aligned normal %d" % point_index
		)
		previous_expected_tilt = expected_tilt
		has_previous_expected_tilt = true

	_write_result([
		"ok=true",
		"authoritative_dense_preview=true",
		"valid_invalid_span_partition=true",
		"invalid_span_is_clear_red=true",
		"exact_control_markers=true",
		"free_spline_shared_sampler_equivalent=true",
		"detail_live_sweep_normals_aligned=true",
		"detail_static_linear_normals_aligned=true",
	])
	quit(0)


func _mesh_index_count(mesh: Mesh) -> int:
	if mesh == null or mesh.get_surface_count() <= 0:
		return 0
	return mesh.surface_get_array_index_len(0)


func _mesh_all_colors_match(
	mesh: Mesh,
	expected_color: Color,
	epsilon: float
) -> bool:
	if mesh == null or mesh.get_surface_count() <= 0:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	if colors.is_empty():
		return false
	for color: Color in colors:
		if not color.is_equal_approx(expected_color):
			if (
				absf(color.r - expected_color.r) > epsilon
				or absf(color.g - expected_color.g) > epsilon
				or absf(color.b - expected_color.b) > epsilon
				or absf(color.a - expected_color.a) > epsilon
			):
				return false
	return true


func _mesh_bounds(mesh: Mesh) -> AABB:
	return mesh.get_aabb() if mesh != null else AABB()


func _mesh_contains_vertex(
	mesh: Mesh,
	expected_vertex: Vector3,
	epsilon: float
) -> bool:
	if mesh == null or mesh.get_surface_count() <= 0:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for vertex: Vector3 in vertices:
		if vertex.distance_to(expected_vertex) <= epsilon:
			return true
	return false


func _invalid_material_is_red(material: Material) -> bool:
	var standard := material as StandardMaterial3D
	return (
		standard != null
		and standard.emission_enabled
		and standard.albedo_color.r > 0.9
		and standard.albedo_color.g < 0.2
		and standard.albedo_color.b < 0.2
	)


func _curves_match(curve_a: Curve3D, curve_b: Curve3D) -> bool:
	if (
		curve_a == null
		or curve_b == null
		or curve_a.point_count != curve_b.point_count
		or not is_equal_approx(curve_a.bake_interval, curve_b.bake_interval)
	):
		return false
	for point_index in range(curve_a.point_count):
		if (
			not curve_a.get_point_position(point_index).is_equal_approx(
				curve_b.get_point_position(point_index)
			)
			or not curve_a.get_point_in(point_index).is_equal_approx(
				curve_b.get_point_in(point_index)
			)
			or not curve_a.get_point_out(point_index).is_equal_approx(
				curve_b.get_point_out(point_index)
			)
		):
			return false
	return true


func _find_path_child(parent: Node) -> Path3D:
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if child is Path3D:
			return child as Path3D
		var nested := _find_path_child(child)
		if nested != null:
			return nested
	return null


func _resolve_linear_tangent(
	path_points: PackedVector3Array,
	point_index: int
) -> Vector3:
	var current_point: Vector3 = path_points[point_index]
	var tangent := Vector3.ZERO
	if point_index > 0:
		tangent += current_point - path_points[point_index - 1]
	if point_index < path_points.size() - 1:
		tangent += path_points[point_index + 1] - current_point
	if tangent.length_squared() > 0.000001:
		return tangent.normalized()
	return Vector3.RIGHT


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_write_result(["ok=false", "error=%s" % message])
	push_error(message)
	quit(1)


func _write_result(lines: Array[String]) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(lines))
