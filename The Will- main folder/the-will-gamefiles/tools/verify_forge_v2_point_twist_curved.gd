extends SceneTree

const Body = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const Presenter = preload("res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd")
const Roll = preload("res://runtime/forge_v2/forge_v2_path_roll.gd")
const OUTPUT := "C:/WORKSPACE/test_artifacts/forge_v2_point_twist_curved_20261017.json"
const TOLERANCE_METERS := 0.00005
var checks := 0
var failures := PackedStringArray()
var evidence: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_usec()
	var presenter := Presenter.new()
	root.add_child(presenter)
	for handle: bool in [true, false]:
		await _verify_family(presenter, handle)
	presenter.free()
	var report := {"ok": failures.is_empty(), "checks": checks, "failures": failures,
		"duration_ms": float(Time.get_ticks_usec() - started) / 1000.0, "evidence": evidence}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	for failure in failures:
		push_error(failure)
	print("Forge V2 curved point twist: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _fixture(handle: bool, rolls: PackedFloat64Array) -> Resource:
	var body := Body.new()
	body.body_kind = Body.BODY_KIND_HANDLE_PROFILE if handle else Body.BODY_KIND_VOLUME_STROKE
	body.shape_kind = Body.SHAPE_KIND_SPLINE_PROFILE_PATH
	body.path_points = PackedVector3Array([Vector3(-0.12, 0, -0.03), Vector3(0, 0.035, 0.05), Vector3(0.13, -0.02, 0.04)])
	body.path_surface_normals = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	body.path_roll_degrees = rolls
	body.radius_meters = 0.03
	body.profile_runtime_schema_version = 1
	body.profile_contact_direction_2d = Vector2(0, -1)
	body.profile_polygon_2d_meters = PackedVector2Array([
		Vector2(-0.025, -0.013), Vector2(0.018, -0.013),
		Vector2(0.018, 0.019), Vector2(-0.025, 0.019)])
	body.normalize()
	return body


func _verify_family(presenter: Node3D, handle: bool) -> void:
	var label := "Handle" if handle else "Spline"
	var zero_body := _fixture(handle, PackedFloat64Array([0, 0, 0]))
	var uniform_body := _fixture(handle, PackedFloat64Array([360, 360, 360]))
	var middle_body := _fixture(handle, PackedFloat64Array([0, 90, 0]))
	var zero := await _bake(presenter, zero_body)
	var uniform := await _bake(presenter, uniform_body)
	var middle := await _bake(presenter, middle_body)
	if not _check(not zero.is_empty() and not uniform.is_empty() and not middle.is_empty(), label + " actual CSG meshes bake"):
		return
	var error := maxf(_surface_error(zero, uniform), _surface_error(uniform, zero))
	_check(error <= TOLERANCE_METERS, label + " uniform360 preserves curved baseline surface; error=" + str(error))
	var points: PackedVector3Array = zero_body.get("path_points")
	var base_curve := Roll.build_base_curve(zero_body, 0.00625)
	var endpoint_error := 0.0
	for at_end: bool in [false, true]:
		var offset := base_curve.get_baked_length() if at_end else 0.0
		var frame := Roll.sample_base_frame(base_curve, offset, handle)
		var center: Vector3 = points[points.size() - 1] if at_end else points[0]
		var tangent: Vector3 = frame.tangent
		var endpoint_count := 0
		for vertex: Vector3 in zero.vertices:
			if absf((vertex - center).dot(tangent)) < 0.000002:
				endpoint_count += 1
				endpoint_error = maxf(endpoint_error, _mesh_distance(vertex, middle))
		_check(endpoint_count >= 3, label + " endpoint plane represented in baseline")
	_check(endpoint_error <= TOLERANCE_METERS, label + " middle90 leaves end sections unchanged; error=" + str(endpoint_error))
	var curve := Roll.build_body_curve(middle_body, 0.00625)
	var data: Dictionary = curve.get_meta(Roll.FRAME_METADATA)
	var peak := Roll.sample_frame(curve, float(data.source_offsets[1]))
	_check(absf(float(peak.roll_degrees) - 90.0) < 0.0001, label + " curved midpoint retains90degrees")
	evidence[label] = {"uniform_surface_error_m": error, "untouched_end_error_m": endpoint_error,
		"zero_triangles": zero.indices.size() / 3, "uniform_triangles": uniform.indices.size() / 3}


func _bake(presenter: Node3D, body: Resource) -> Dictionary:
	var shape := CSGCombiner3D.new()
	shape.calculate_tangents = false
	presenter.add_child(shape)
	if not bool(presenter.call("_append_csg_body_shape", shape, body, &"mat_iron_gray", false, 0)):
		shape.free()
		return {}
	var ready := false
	for _frame in range(120):
		await process_frame
		if bool(presenter.call("_csg_shape_generated_mesh_is_ready", shape)):
			ready = true
			break
	if not ready:
		shape.free()
		return {}
	var packet: Dictionary = presenter.call("_flatten_native_protected_handle_baked_mesh", shape.bake_static_mesh(), "curved_twist")
	shape.free()
	return packet if bool(packet.get("ok", false)) else {}


func _surface_error(source: Dictionary, target: Dictionary) -> float:
	var vertices: PackedVector3Array = source.vertices
	var maximum := 0.0
	var stride := maxi(1, vertices.size() / 120)
	for index in range(0, vertices.size(), stride):
		maximum = maxf(maximum, _mesh_distance(vertices[index], target))
	return maximum


func _mesh_distance(point: Vector3, mesh: Dictionary) -> float:
	var vertices: PackedVector3Array = mesh.vertices
	var indices: PackedInt32Array = mesh.indices
	var nearest := INF
	for index in range(0, indices.size(), 3):
		nearest = minf(nearest, _triangle_distance(point, vertices[indices[index]], vertices[indices[index + 1]], vertices[indices[index + 2]]))
	return nearest


func _triangle_distance(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() > 0.0000000000000001:
		var projected := point - normal * ((point - a).dot(normal) / normal.length_squared())
		if ((b - a).cross(projected - a).dot(normal) >= -0.000000000000001
			and (c - b).cross(projected - b).dot(normal) >= -0.000000000000001
			and (a - c).cross(projected - c).dot(normal) >= -0.000000000000001):
			return projected.distance_to(point)
	return minf(point.distance_to(Geometry3D.get_closest_point_to_segment(point, a, b)),
		minf(point.distance_to(Geometry3D.get_closest_point_to_segment(point, b, c)),
		point.distance_to(Geometry3D.get_closest_point_to_segment(point, c, a))))


func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
	return condition
