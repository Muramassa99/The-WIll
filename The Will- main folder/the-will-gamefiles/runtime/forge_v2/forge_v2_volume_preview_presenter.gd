extends Node3D
class_name ForgeV2VolumePreviewPresenter

const ForgeV2VolumeStrokeScript = preload("res://runtime/forge_v2/forge_v2_volume_stroke.gd")

const PREVIEW_TUBE_SIDES := 12
const PREVIEW_SPHERE_RINGS := 6
const PREVIEW_SPHERE_SIDES := 12
const DEFAULT_PREVIEW_RADIUS_METERS := 0.06

var active_stage_controller: Node = null
var preview_mesh_instance: MeshInstance3D = null
var placement_cursor_mesh_instance: MeshInstance3D = null

func _ready() -> void:
	_ensure_preview_mesh_instance()
	_ensure_placement_cursor_mesh_instance()

func bind_stage_controller(stage_controller: Node) -> void:
	if active_stage_controller == stage_controller:
		_sync_from_controller()
		return
	_disconnect_stage_controller()
	active_stage_controller = stage_controller
	_connect_stage_controller()
	_sync_from_controller()

func clear_stage_controller() -> void:
	_disconnect_stage_controller()
	active_stage_controller = null
	_sync_preview_mesh(null)
	_sync_placement_cursor(Vector3.ZERO, false, DEFAULT_PREVIEW_RADIUS_METERS)

func _connect_stage_controller() -> void:
	if active_stage_controller == null:
		return
	if not active_stage_controller.has_signal("authoring_state_changed"):
		return
	if not active_stage_controller.authoring_state_changed.is_connected(_on_authoring_state_changed):
		active_stage_controller.authoring_state_changed.connect(_on_authoring_state_changed)
	if active_stage_controller.has_signal("placement_cursor_changed"):
		if not active_stage_controller.placement_cursor_changed.is_connected(_on_placement_cursor_changed):
			active_stage_controller.placement_cursor_changed.connect(_on_placement_cursor_changed)
	if active_stage_controller.has_method("get_placement_cursor_state"):
		var cursor_state: Dictionary = active_stage_controller.call("get_placement_cursor_state")
		_sync_placement_cursor(
			cursor_state.get("local_position", Vector3.ZERO) as Vector3,
			bool(cursor_state.get("is_valid", false)),
			float(cursor_state.get("radius_meters", DEFAULT_PREVIEW_RADIUS_METERS))
		)

func _disconnect_stage_controller() -> void:
	if active_stage_controller == null:
		return
	if not active_stage_controller.has_signal("authoring_state_changed"):
		return
	if active_stage_controller.authoring_state_changed.is_connected(_on_authoring_state_changed):
		active_stage_controller.authoring_state_changed.disconnect(_on_authoring_state_changed)
	if active_stage_controller.has_signal("placement_cursor_changed"):
		if active_stage_controller.placement_cursor_changed.is_connected(_on_placement_cursor_changed):
			active_stage_controller.placement_cursor_changed.disconnect(_on_placement_cursor_changed)

func _on_authoring_state_changed(_state: Resource) -> void:
	_sync_from_controller()

func _on_placement_cursor_changed(local_position: Vector3, is_valid: bool, radius_meters: float) -> void:
	_sync_placement_cursor(local_position, is_valid, radius_meters)

func _sync_from_controller() -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("get_active_authoring_state"):
		_sync_preview_mesh(null)
		return
	var authoring_state: Resource = active_stage_controller.call("get_active_authoring_state") as Resource
	_sync_preview_mesh(authoring_state)

func _sync_preview_mesh(authoring_state: Resource) -> void:
	_ensure_preview_mesh_instance()
	if preview_mesh_instance == null:
		return
	if authoring_state == null:
		preview_mesh_instance.visible = false
		preview_mesh_instance.mesh = null
		return
	var volume_records: Array = authoring_state.get("material_bodies")
	if volume_records.is_empty():
		volume_records = authoring_state.get("volume_strokes")
	var preview_mesh: ArrayMesh = _build_preview_mesh(volume_records)
	if preview_mesh == null or preview_mesh.get_surface_count() <= 0:
		preview_mesh_instance.visible = false
		preview_mesh_instance.mesh = null
		return
	preview_mesh_instance.mesh = preview_mesh
	preview_mesh_instance.material_override = _build_preview_material()
	preview_mesh_instance.visible = true

func _ensure_preview_mesh_instance() -> void:
	if preview_mesh_instance != null and is_instance_valid(preview_mesh_instance):
		return
	preview_mesh_instance = get_node_or_null("VolumeStrokePreviewMesh") as MeshInstance3D
	if preview_mesh_instance != null:
		return
	preview_mesh_instance = MeshInstance3D.new()
	preview_mesh_instance.name = "VolumeStrokePreviewMesh"
	add_child(preview_mesh_instance)

func _ensure_placement_cursor_mesh_instance() -> void:
	if placement_cursor_mesh_instance != null and is_instance_valid(placement_cursor_mesh_instance):
		return
	placement_cursor_mesh_instance = get_node_or_null("PlacementCursorMesh") as MeshInstance3D
	if placement_cursor_mesh_instance == null:
		placement_cursor_mesh_instance = MeshInstance3D.new()
		placement_cursor_mesh_instance.name = "PlacementCursorMesh"
		add_child(placement_cursor_mesh_instance)
	placement_cursor_mesh_instance.visible = false
	placement_cursor_mesh_instance.material_override = _build_placement_cursor_material()

func _sync_placement_cursor(local_position: Vector3, is_valid: bool, radius_meters: float) -> void:
	_ensure_placement_cursor_mesh_instance()
	if placement_cursor_mesh_instance == null:
		return
	placement_cursor_mesh_instance.visible = is_valid
	if not is_valid:
		return
	var sphere_mesh: SphereMesh = placement_cursor_mesh_instance.mesh as SphereMesh
	if sphere_mesh == null:
		sphere_mesh = SphereMesh.new()
		placement_cursor_mesh_instance.mesh = sphere_mesh
	var cursor_radius: float = maxf(radius_meters, 0.004)
	sphere_mesh.radius = cursor_radius
	sphere_mesh.height = cursor_radius * 2.0
	placement_cursor_mesh_instance.position = local_position

func _build_preview_mesh(volume_strokes: Array) -> ArrayMesh:
	if volume_strokes.is_empty():
		return ArrayMesh.new()
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var added_vertices := 0
	for stroke: Resource in volume_strokes:
		if stroke == null:
			continue
		if stroke.has_method("normalize"):
			stroke.call("normalize")
		if stroke.get("layer_active") is bool and not bool(stroke.get("layer_active")):
			continue
		added_vertices += _append_stroke_preview(surface_tool, stroke)
	if added_vertices <= 0:
		return ArrayMesh.new()
	surface_tool.index()
	surface_tool.generate_normals()
	return surface_tool.commit()

func _append_stroke_preview(surface_tool: SurfaceTool, stroke: Resource) -> int:
	var path_points: PackedVector3Array = stroke.get("path_points")
	if path_points.is_empty():
		return 0
	var raw_radius_meters := float(stroke.get("radius_meters"))
	var radius_meters := raw_radius_meters if raw_radius_meters > 0.0 else DEFAULT_PREVIEW_RADIUS_METERS
	var color: Color = _resolve_stroke_color(stroke)
	var added_vertices := 0
	if path_points.size() == 1:
		return _append_sphere(surface_tool, path_points[0], radius_meters, color)
	for point_index in range(path_points.size() - 1):
		var from_point: Vector3 = path_points[point_index]
		var to_point: Vector3 = path_points[point_index + 1]
		if from_point.distance_squared_to(to_point) <= 0.000001:
			continue
		added_vertices += _append_tube_segment(surface_tool, from_point, to_point, radius_meters, color)
	for point: Vector3 in path_points:
		added_vertices += _append_sphere(surface_tool, point, radius_meters, color)
	return added_vertices

func _append_tube_segment(
	surface_tool: SurfaceTool,
	from_point: Vector3,
	to_point: Vector3,
	radius_meters: float,
	color: Color
) -> int:
	var tangent: Vector3 = (to_point - from_point).normalized()
	if tangent == Vector3.ZERO:
		return 0
	var normal: Vector3 = _resolve_perpendicular_normal(tangent)
	var binormal: Vector3 = tangent.cross(normal).normalized()
	var added_vertices := 0
	for side_index in range(PREVIEW_TUBE_SIDES):
		var next_side_index := (side_index + 1) % PREVIEW_TUBE_SIDES
		var angle_a := TAU * float(side_index) / float(PREVIEW_TUBE_SIDES)
		var angle_b := TAU * float(next_side_index) / float(PREVIEW_TUBE_SIDES)
		var offset_a: Vector3 = (normal * cos(angle_a) + binormal * sin(angle_a)) * radius_meters
		var offset_b: Vector3 = (normal * cos(angle_b) + binormal * sin(angle_b)) * radius_meters
		var from_a: Vector3 = from_point + offset_a
		var from_b: Vector3 = from_point + offset_b
		var to_a: Vector3 = to_point + offset_a
		var to_b: Vector3 = to_point + offset_b
		added_vertices += _append_triangle(surface_tool, from_a, to_a, to_b, color)
		added_vertices += _append_triangle(surface_tool, from_a, to_b, from_b, color)
	return added_vertices

func _append_sphere(
	surface_tool: SurfaceTool,
	center_point: Vector3,
	radius_meters: float,
	color: Color
) -> int:
	var added_vertices := 0
	for ring_index in range(PREVIEW_SPHERE_RINGS):
		var theta_a := PI * float(ring_index) / float(PREVIEW_SPHERE_RINGS)
		var theta_b := PI * float(ring_index + 1) / float(PREVIEW_SPHERE_RINGS)
		for side_index in range(PREVIEW_SPHERE_SIDES):
			var next_side_index := (side_index + 1) % PREVIEW_SPHERE_SIDES
			var phi_a := TAU * float(side_index) / float(PREVIEW_SPHERE_SIDES)
			var phi_b := TAU * float(next_side_index) / float(PREVIEW_SPHERE_SIDES)
			var point_aa: Vector3 = center_point + _sphere_offset(theta_a, phi_a, radius_meters)
			var point_ab: Vector3 = center_point + _sphere_offset(theta_a, phi_b, radius_meters)
			var point_ba: Vector3 = center_point + _sphere_offset(theta_b, phi_a, radius_meters)
			var point_bb: Vector3 = center_point + _sphere_offset(theta_b, phi_b, radius_meters)
			added_vertices += _append_triangle(surface_tool, point_aa, point_ba, point_bb, color)
			added_vertices += _append_triangle(surface_tool, point_aa, point_bb, point_ab, color)
	return added_vertices

func _append_triangle(
	surface_tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	color: Color
) -> int:
	surface_tool.set_color(color)
	surface_tool.add_vertex(point_a)
	surface_tool.set_color(color)
	surface_tool.add_vertex(point_b)
	surface_tool.set_color(color)
	surface_tool.add_vertex(point_c)
	return 3

func _sphere_offset(theta: float, phi: float, radius_meters: float) -> Vector3:
	var sin_theta := sin(theta)
	return Vector3(
		sin_theta * cos(phi),
		cos(theta),
		sin_theta * sin(phi)
	) * radius_meters

func _resolve_perpendicular_normal(tangent: Vector3) -> Vector3:
	var reference := Vector3.UP
	if absf(tangent.dot(reference)) > 0.92:
		reference = Vector3.RIGHT
	var normal: Vector3 = reference.cross(tangent).normalized()
	if normal == Vector3.ZERO:
		return Vector3.FORWARD
	return normal

func _resolve_stroke_color(stroke: Resource) -> Color:
	if stroke.get("operation_mode") == ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL:
		return Color(0.95, 0.22, 0.18, 0.74)
	var material_variant_id: StringName = stroke.get("material_variant_id")
	if material_variant_id == &"mat_iron_gray" or material_variant_id == &"iron_gray":
		return Color(0.62, 0.66, 0.67, 1.0)
	return Color(0.35, 0.78, 0.7, 1.0)

func _build_preview_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.64
	material.metallic = 0.08
	return material

func _build_placement_cursor_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.86, 0.78, 0.46)
	material.emission_enabled = true
	material.emission = Color(0.16, 0.62, 0.58, 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
