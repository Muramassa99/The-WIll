extends SceneTree

const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const ForgeV2VolumeStrokeScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_stroke.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_active_sweep_preview_2026-08-10.txt"
)
const EPSILON := 0.00001


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var controller: Node = ForgeV2StageControllerScript.new()
	var presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	root.add_child(controller)
	root.add_child(presenter)
	presenter.call("bind_stage_controller", controller)

	var primitive_body_id: StringName = controller.call(
		"begin_material_body_path",
		Vector3.ZERO,
		Vector3.UP
	)
	_require(primitive_body_id != StringName(), "primitive begin failed")
	controller.call(
		"extend_material_body_path_samples",
		PackedVector3Array([
			Vector3(0.04, 0.0, 0.0),
			Vector3(0.08, 0.0, 0.0),
		]),
		PackedVector3Array([Vector3.UP, Vector3.UP]),
		false
	)
	var active_mesh_instance := _get_active_mesh_instance(presenter)
	_require(
		active_mesh_instance != null
		and active_mesh_instance.visible
		and active_mesh_instance.mesh != null,
		"primitive active sweep mesh was not presented"
	)
	_require(
		_get_active_csg_child_count(presenter) == 0,
		"primitive live update created active CSG"
	)
	var first_primitive_index_count := _mesh_index_count(
		active_mesh_instance.mesh
	)
	controller.call(
		"extend_material_body_path_samples",
		PackedVector3Array([
			Vector3(0.12, 0.0, 0.0),
			Vector3(0.16, 0.0, 0.0),
		]),
		PackedVector3Array([Vector3.UP, Vector3.UP]),
		false
	)
	_require(
		_mesh_index_count(active_mesh_instance.mesh)
		> first_primitive_index_count,
		"primitive active sweep mesh did not grow with its path"
	)
	_require(
		_get_active_csg_child_count(presenter) == 0,
		"primitive batch refresh recreated active CSG"
	)
	_require(
		bool(controller.call(
			"finish_material_body_path",
			Vector3.ZERO,
			false,
			Vector3.FORWARD
		)),
		"primitive active sweep did not commit"
	)
	_require(
		not active_mesh_instance.visible
		and active_mesh_instance.mesh == null,
		"committed primitive left the active mesh visible"
	)
	_require(
		_get_active_csg_child_count(presenter) == 0
		and _get_static_csg_child_count(presenter) > 0,
		"primitive commit did not return to authoritative static CSG"
	)

	controller.call("start_new_draft", "Active Sweep Saved Profile Verify")
	var base_polygon := PackedVector2Array([
		Vector2(-0.034, -0.018),
		Vector2(0.041, -0.013),
		Vector2(0.026, 0.029),
		Vector2(-0.008, 0.038),
		Vector2(-0.037, 0.006),
	])
	var rotation_bias_degrees := 27.0
	var saved_profile := (
		ForgeV2ProfileShapeLibraryScript.compile_basic_profile_runtime_data({
			"profile_id": &"active_sweep_asymmetric_profile",
			"id": &"active_sweep_asymmetric_profile",
			"label": "Active Sweep Asymmetric Profile",
			"family": ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC,
			"base_polygon_2d_meters": base_polygon,
			"polygon_2d_meters": _rotate_points(
				base_polygon,
				rotation_bias_degrees
			),
			"base_anchor_2d_meters": Vector2(0.002, -0.003),
			"rotation_degrees": rotation_bias_degrees,
		})
	)
	_require(
		bool(controller.call("select_active_saved_basic_profile", saved_profile)),
		"compiled saved Basic profile could not be selected"
	)
	var profile_body_id: StringName = controller.call(
		"begin_material_body_path",
		Vector3.ZERO,
		Vector3.UP,
		Vector3.DOWN
	)
	controller.call(
		"extend_material_body_path_samples",
		PackedVector3Array([Vector3(0.08, 0.0, 0.0)]),
		PackedVector3Array([Vector3.BACK]),
		true,
		PackedVector3Array([Vector3.FORWARD])
	)
	var profile_body := _find_body(
		controller.call("get_active_authoring_state") as Resource,
		profile_body_id
	)
	_require(profile_body != null, "saved-profile active body was not retained")
	var deposition_polygon: PackedVector2Array = profile_body.get(
		"profile_polygon_2d_meters"
	)
	_require(
		deposition_polygon.size() == base_polygon.size(),
		"saved profile polygon vertex count changed before preview"
	)
	active_mesh_instance = _get_active_mesh_instance(presenter)
	_require(
		active_mesh_instance != null
		and active_mesh_instance.visible
		and active_mesh_instance.mesh != null,
		"saved-profile active sweep mesh was not presented"
	)
	_require(
		int(active_mesh_instance.get_meta(
			"forge_v2_profile_vertex_count",
			0
		)) == deposition_polygon.size(),
		"active sweep did not consume the saved polygon vertex count"
	)
	_require(
		int(active_mesh_instance.get_meta(
			"forge_v2_path_surface_normal_count",
			0
		)) == 2,
		"active sweep did not consume paired path surface normals"
	)
	var expected_index_count := (
		6 * deposition_polygon.size()
		+ 6 * (deposition_polygon.size() - 2)
	)
	_require(
		_mesh_index_count(active_mesh_instance.mesh) == expected_index_count,
		"active sweep triangle count did not use the saved polygon"
	)
	var contact_direction: Vector2 = profile_body.get(
		"profile_contact_direction_2d"
	)
	var contact_point_relative: Vector2 = profile_body.get(
		"profile_contact_point_relative_2d_meters"
	)
	var path_contact_directions: PackedVector3Array = profile_body.get(
		"path_contact_directions"
	)
	_require(
		path_contact_directions == PackedVector3Array([
			Vector3.DOWN,
			Vector3.FORWARD,
		]),
		"active sweep did not retain its explicit B-C samples"
	)
	var frame := (
		ForgeV2ProfileShapeLibraryScript.resolve_explicit_surface_profile_path_frame(
		Vector3.RIGHT,
		Vector3.UP,
		contact_direction,
		contact_point_relative,
		path_contact_directions[0],
		float(profile_body.get("profile_rotation_bias_degrees"))
		)
	)
	var expected_first_vertex := (
		(frame.get("axis_x", Vector3.RIGHT) as Vector3)
		* deposition_polygon[0].x
		+ (frame.get("axis_y", Vector3.UP) as Vector3)
		* deposition_polygon[0].y
	)
	_require(
		_mesh_contains_vertex(
			active_mesh_instance.mesh,
			expected_first_vertex,
			EPSILON
		),
		"active sweep ignored the contact/surface-normal/rotation frame"
	)
	var changed_normal_frame := (
		ForgeV2ProfileShapeLibraryScript.resolve_explicit_surface_profile_path_frame(
			Vector3.RIGHT,
			Vector3.BACK,
			contact_direction,
			contact_point_relative,
			path_contact_directions[1],
			float(profile_body.get("profile_rotation_bias_degrees"))
		)
	)
	var expected_changed_normal_vertex := (
		Vector3(0.08, 0.0, 0.0)
		+ (changed_normal_frame.get("axis_x", Vector3.RIGHT) as Vector3)
		* deposition_polygon[0].x
		+ (changed_normal_frame.get("axis_y", Vector3.UP) as Vector3)
		* deposition_polygon[0].y
	)
	_require(
		_mesh_contains_vertex(
			active_mesh_instance.mesh,
			expected_changed_normal_vertex,
			EPSILON
		),
		"active sweep did not reorient the next ring to its paired normal"
	)
	_require(
		is_equal_approx(
			float(active_mesh_instance.get_meta(
				"forge_v2_profile_rotation_bias_degrees",
				0.0
			)),
			rotation_bias_degrees
		),
		"active sweep did not retain the saved profile rotation bias"
	)
	_require(
		_get_active_csg_child_count(presenter) == 0,
		"saved-profile live update created active CSG"
	)
	_require(
		bool(controller.call(
			"finish_material_body_path",
			Vector3.ZERO,
			false,
			Vector3.FORWARD
		)),
		"saved-profile active sweep did not commit"
	)
	_require(
		not active_mesh_instance.visible
		and active_mesh_instance.mesh == null
		and _get_active_csg_child_count(presenter) == 0
		and _get_static_csg_child_count(presenter) > 0,
		"saved-profile commit did not return to authoritative static CSG"
	)

	controller.call("start_new_draft", "Active Sweep Remove Verify")
	controller.call(
		"set_active_operation_mode",
		ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL
	)
	controller.call(
		"begin_material_body_path",
		Vector3.ZERO,
		Vector3.UP
	)
	controller.call(
		"extend_material_body_path_samples",
		PackedVector3Array([Vector3(0.05, 0.0, 0.0)]),
		PackedVector3Array([Vector3.UP]),
		true
	)
	active_mesh_instance = _get_active_mesh_instance(presenter)
	var remove_colors := _mesh_colors(active_mesh_instance.mesh)
	_require(
		not remove_colors.is_empty()
		and remove_colors[0].r > 0.9
		and remove_colors[0].g < 0.2
		and remove_colors[0].b < 0.2,
		"remove operation did not use the clear red subtractive preview"
	)
	_require(
		_get_active_csg_child_count(presenter) == 0,
		"remove live update created active CSG"
	)

	_write_result([
		"ok=true",
		"active_csg_branch_empty=true",
		"primitive_sweep_mesh_grows=true",
		"saved_profile_polygon_consumed=true",
		"surface_normal_contact_rotation_frame_consumed=true",
		"remove_preview_is_red=true",
		"commit_returns_to_static_csg=true",
	])
	quit(0)


func _get_active_mesh_instance(presenter: Node) -> MeshInstance3D:
	return presenter.get_node_or_null(
		"ActiveMaterialBodySweepPreviewMesh"
	) as MeshInstance3D


func _get_active_csg_child_count(presenter: Node) -> int:
	var active_root := presenter.get_node_or_null(
		"MaterialBodyCsgRoot/ActiveMaterialBodyCsgRoot"
	)
	return active_root.get_child_count() if active_root != null else -1


func _get_static_csg_child_count(presenter: Node) -> int:
	var static_root := presenter.get_node_or_null(
		"MaterialBodyCsgRoot/StaticMaterialBodyCsgRoot"
	)
	return static_root.get_child_count() if static_root != null else -1


func _mesh_index_count(mesh: Mesh) -> int:
	if mesh == null or mesh.get_surface_count() <= 0:
		return 0
	return mesh.surface_get_array_index_len(0)


func _mesh_colors(mesh: Mesh) -> PackedColorArray:
	if mesh == null or mesh.get_surface_count() <= 0:
		return PackedColorArray()
	var arrays: Array = mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_COLOR] as PackedColorArray


func _mesh_contains_vertex(
	mesh: Mesh,
	expected_vertex: Vector3,
	epsilon: float
) -> bool:
	if mesh == null or mesh.get_surface_count() <= 0:
		return false
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for vertex: Vector3 in vertices:
		if vertex.distance_to(expected_vertex) <= epsilon:
			return true
	return false


func _find_body(state: Resource, body_id: StringName) -> Resource:
	if state == null or body_id == StringName():
		return null
	var bodies: Array = state.get("material_bodies")
	for body_variant: Variant in bodies:
		if not (body_variant is Resource):
			continue
		var body: Resource = body_variant as Resource
		if StringName(body.get("body_id")) == body_id:
			return body
	return null


func _rotate_points(
	points: PackedVector2Array,
	rotation_degrees: float
) -> PackedVector2Array:
	var rotated := PackedVector2Array()
	var rotation_radians := deg_to_rad(rotation_degrees)
	for point: Vector2 in points:
		rotated.append(point.rotated(rotation_radians))
	return rotated


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
