extends SceneTree

const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_csg_profile_handedness_oracle_2026-08-12.txt"
)
const POSITION_EPSILON := 0.0002
const PLANE_EPSILON := 0.0002


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	root.add_child(presenter)
	var body: Resource = ForgeV2MaterialBodyScript.new()
	body.body_kind = ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE
	body.shape_kind = ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
	body.material_variant_id = &"mat_iron_gray"
	body.path_points = PackedVector3Array([
		Vector3.ZERO,
		Vector3(0.2, 0.0, 0.0),
	])
	body.path_surface_normals = PackedVector3Array([
		Vector3.UP,
		Vector3.UP,
	])
	body.profile_polygon_2d_meters = PackedVector2Array([
		Vector2(-0.032, -0.024),
		Vector2(0.012, -0.028),
		Vector2(0.037, -0.006),
		Vector2(0.026, 0.031),
		Vector2(-0.029, 0.022),
	])
	body.profile_contact_direction_2d = (
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
	)
	body.profile_contact_distance_meters = 0.024
	body.profile_runtime_schema_version = 1
	body.normalize()

	var tangent := Vector3.RIGHT
	var legacy_frame: Dictionary = (
		ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
			tangent,
			Vector3.UP,
			body.profile_contact_direction_2d,
			0.0
		)
	)
	var live_axis_x := legacy_frame.get("axis_x", Vector3.ZERO) as Vector3
	var live_axis_y := legacy_frame.get("axis_y", Vector3.ZERO) as Vector3
	_require(
		live_axis_x.length_squared() > 0.9
		and live_axis_y.length_squared() > 0.9,
		"legacy live frame was degenerate"
	)

	var live_mesh: ArrayMesh = presenter.call(
		"_build_active_material_body_sweep_mesh",
		body
	) as ArrayMesh
	_require(
		live_mesh != null and live_mesh.get_surface_count() > 0,
		"live profile sweep mesh was not generated"
	)
	var live_start_ring := _collect_profile_coordinates_at_plane(
		live_mesh,
		Vector3.ZERO,
		tangent,
		live_axis_x,
		live_axis_y
	)
	_require(
		_profile_vertex_set_matches(
			live_start_ring,
			body.profile_polygon_2d_meters
		),
		"live ring did not map through its declared legacy frame"
	)

	var csg_root := Node3D.new()
	csg_root.name = "CsgHandednessOracleRoot"
	root.add_child(csg_root)
	_require(
		bool(presenter.call(
			"_append_csg_body_shape",
			csg_root,
			body,
			&"mat_iron_gray",
			false,
			0
		)),
		"static CSG profile path was not generated"
	)
	await process_frame
	await process_frame
	var csg_polygon := _find_csg_polygon(csg_root)
	_require(csg_polygon != null, "generated CSG polygon was not found")
	var final_mesh := csg_polygon.bake_static_mesh()
	_require(
		final_mesh != null and final_mesh.get_surface_count() > 0,
		"generated CSG polygon could not be baked"
	)
	var final_start_ring := _collect_profile_coordinates_at_plane(
		final_mesh,
		Vector3.ZERO,
		tangent,
		live_axis_x,
		live_axis_y
	)
	_require(
		final_start_ring.size() >= body.profile_polygon_2d_meters.size(),
		"baked CSG endpoint ring could not be isolated"
	)

	var mapping := _classify_profile_mapping(
		final_start_ring,
		body.profile_polygon_2d_meters
	)
	_require(not mapping.is_empty(), "baked CSG mapping was not classifiable")
	var mapping_id := StringName(mapping.get("id", StringName()))
	_require(
		mapping_id == &"mirror_x",
		"legacy CSG authored-handedness oracle changed from mirror_x"
	)
	var mapped_axis_x_2d := mapping.get("axis_x", Vector2.ZERO) as Vector2
	var mapped_axis_y_2d := mapping.get("axis_y", Vector2.ZERO) as Vector2
	var final_axis_x := (
		live_axis_x * mapped_axis_x_2d.x
		+ live_axis_y * mapped_axis_x_2d.y
	).normalized()
	var final_axis_y := (
		live_axis_x * mapped_axis_y_2d.x
		+ live_axis_y * mapped_axis_y_2d.y
	).normalized()
	var live_handedness := live_axis_x.cross(live_axis_y).dot(tangent)
	var final_handedness := final_axis_x.cross(final_axis_y).dot(tangent)
	_require(
		live_handedness > 0.999 and final_handedness < -0.999,
		"legacy live/final handedness oracle signs changed"
	)
	var live_and_final_same := _profile_vertex_set_matches(
		final_start_ring,
		body.profile_polygon_2d_meters
	)

	_write_result([
		"ok=true",
		"mapping_id=%s" % String(mapping_id),
		"live_handedness_sign=%d" % _sign_with_epsilon(live_handedness),
		"final_handedness_sign=%d" % _sign_with_epsilon(final_handedness),
		"live_and_final_same_mapping=%s" % str(live_and_final_same),
		"live_axis_x=%s" % str(live_axis_x),
		"live_axis_y=%s" % str(live_axis_y),
		"final_axis_x=%s" % str(final_axis_x),
		"final_axis_y=%s" % str(final_axis_y),
	])
	quit(0)


func _collect_profile_coordinates_at_plane(
	mesh: Mesh,
	plane_origin: Vector3,
	path_tangent: Vector3,
	axis_x: Vector3,
	axis_y: Vector3
) -> PackedVector2Array:
	var result := PackedVector2Array()
	if mesh == null:
		return result
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


func _classify_profile_mapping(
	actual_coordinates: PackedVector2Array,
	authored_polygon: PackedVector2Array
) -> Dictionary:
	var candidates: Array[Dictionary] = [
		{
			"id": &"same_xy",
			"axis_x": Vector2.RIGHT,
			"axis_y": Vector2.DOWN,
			"transform": Transform2D(Vector2.RIGHT, Vector2.DOWN, Vector2.ZERO),
		},
		{
			"id": &"mirror_x",
			"axis_x": Vector2.LEFT,
			"axis_y": Vector2.DOWN,
			"transform": Transform2D(Vector2.LEFT, Vector2.DOWN, Vector2.ZERO),
		},
		{
			"id": &"mirror_y",
			"axis_x": Vector2.RIGHT,
			"axis_y": Vector2.UP,
			"transform": Transform2D(Vector2.RIGHT, Vector2.UP, Vector2.ZERO),
		},
		{
			"id": &"rotate_180",
			"axis_x": Vector2.LEFT,
			"axis_y": Vector2.UP,
			"transform": Transform2D(Vector2.LEFT, Vector2.UP, Vector2.ZERO),
		},
		{
			"id": &"swap_xy",
			"axis_x": Vector2.DOWN,
			"axis_y": Vector2.RIGHT,
			"transform": Transform2D(Vector2.DOWN, Vector2.RIGHT, Vector2.ZERO),
		},
		{
			"id": &"swap_mirror_x",
			"axis_x": Vector2.UP,
			"axis_y": Vector2.RIGHT,
			"transform": Transform2D(Vector2.UP, Vector2.RIGHT, Vector2.ZERO),
		},
		{
			"id": &"swap_mirror_y",
			"axis_x": Vector2.DOWN,
			"axis_y": Vector2.LEFT,
			"transform": Transform2D(Vector2.DOWN, Vector2.LEFT, Vector2.ZERO),
		},
		{
			"id": &"swap_rotate_180",
			"axis_x": Vector2.UP,
			"axis_y": Vector2.LEFT,
			"transform": Transform2D(Vector2.UP, Vector2.LEFT, Vector2.ZERO),
		},
	]
	for candidate: Dictionary in candidates:
		var transform := candidate.get(
			"transform",
			Transform2D.IDENTITY
		) as Transform2D
		var transformed := PackedVector2Array()
		for point: Vector2 in authored_polygon:
			transformed.append(transform * point)
		if _profile_vertex_set_matches(actual_coordinates, transformed):
			return candidate
	return {}


func _profile_vertex_set_matches(
	actual_coordinates: PackedVector2Array,
	expected_polygon: PackedVector2Array
) -> bool:
	if actual_coordinates.size() < expected_polygon.size():
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


func _sign_with_epsilon(value: float) -> int:
	if value > 0.0001:
		return 1
	if value < -0.0001:
		return -1
	return 0


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
