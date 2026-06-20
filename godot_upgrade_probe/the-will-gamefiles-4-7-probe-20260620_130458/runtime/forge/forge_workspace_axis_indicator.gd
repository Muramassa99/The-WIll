extends Control
class_name ForgeWorkspaceAxisIndicator

const GIZMO_SCENE_RESOURCE: PackedScene = preload("res://scenes/ui/assets/transform_gizmo.glb")
const DEFAULT_GIZMO_CAMERA_DISTANCE: float = 3.0
const DEFAULT_GIZMO_CAMERA_SIZE: float = 2.4
const DEFAULT_GIZMO_TARGET_SIZE: float = 1.45
const AXIS_IDS: Array[StringName] = [&"x", &"y", &"z"]

var axis_screen_vectors: Dictionary = {}
var axis_local_vectors: Dictionary = {}

var viewport_container: SubViewportContainer
var viewport_3d: SubViewport
var scene_root: Node3D
var gizmo_pivot: Node3D
var gizmo_camera: Camera3D
var gizmo_light: DirectionalLight3D
var gizmo_instance: Node3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_gizmo_scene()

func sync_from_preview(preview: ForgeWorkspacePreview) -> void:
	_ensure_gizmo_scene()
	_resync_viewport_size()
	if not is_instance_valid(preview):
		clear_state()
		return
	var state: Dictionary = preview.get_axis_indicator_state()
	axis_screen_vectors = state.get("screen_vectors", {})
	axis_local_vectors = state.get("local_vectors", {})
	if gizmo_pivot != null and preview.camera != null:
		gizmo_pivot.transform.basis = preview.camera.global_transform.basis.orthonormalized().inverse()

func clear_state() -> void:
	axis_screen_vectors.clear()
	axis_local_vectors.clear()
	if gizmo_pivot != null:
		gizmo_pivot.transform.basis = Basis.IDENTITY

func get_axis_screen_vector(axis_id: StringName) -> Vector2:
	return axis_screen_vectors.get(axis_id, Vector2.ZERO)

func _ensure_gizmo_scene() -> void:
	if viewport_container != null:
		return
	viewport_container = SubViewportContainer.new()
	viewport_container.name = "GizmoViewportContainer"
	viewport_container.stretch = false
	viewport_container.anchor_right = 1.0
	viewport_container.anchor_bottom = 1.0
	viewport_container.offset_left = 0.0
	viewport_container.offset_top = 0.0
	viewport_container.offset_right = 0.0
	viewport_container.offset_bottom = 0.0
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport_container)

	viewport_3d = SubViewport.new()
	viewport_3d.name = "GizmoSubViewport"
	viewport_3d.size = Vector2i(maxi(int(size.x), 1), maxi(int(size.y), 1))
	viewport_3d.own_world_3d = true
	viewport_3d.transparent_bg = true
	viewport_3d.handle_input_locally = false
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport_3d)

	scene_root = Node3D.new()
	scene_root.name = "GizmoRoot3D"
	viewport_3d.add_child(scene_root)

	gizmo_pivot = Node3D.new()
	gizmo_pivot.name = "GizmoPivot"
	scene_root.add_child(gizmo_pivot)

	gizmo_camera = Camera3D.new()
	gizmo_camera.name = "GizmoCamera3D"
	gizmo_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	gizmo_camera.size = DEFAULT_GIZMO_CAMERA_SIZE
	gizmo_camera.current = true
	gizmo_camera.look_at_from_position(Vector3(0.0, 0.0, DEFAULT_GIZMO_CAMERA_DISTANCE), Vector3.ZERO, Vector3.UP)
	scene_root.add_child(gizmo_camera)

	gizmo_light = DirectionalLight3D.new()
	gizmo_light.name = "GizmoLight3D"
	gizmo_light.light_energy = 1.45
	gizmo_light.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	scene_root.add_child(gizmo_light)

	gizmo_instance = _instantiate_gizmo_scene()
	if gizmo_instance != null:
		gizmo_pivot.add_child(gizmo_instance)

	_resync_viewport_size()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_resync_viewport_size()

func _resync_viewport_size() -> void:
	if viewport_3d == null:
		return
	var side_length: int = maxi(int(round(minf(size.x, size.y))), 1)
	var target_size: Vector2i = Vector2i(side_length, side_length)
	if viewport_3d.size != target_size:
		viewport_3d.size = target_size

func _instantiate_gizmo_scene() -> Node3D:
	var root_3d: Node3D = _load_gltf_scene_root()
	if root_3d == null:
		return null
	var aabb: AABB = _collect_visual_aabb(root_3d, Transform3D.IDENTITY)
	if aabb.size != Vector3.ZERO:
		var max_dimension: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		if max_dimension > 0.0001:
			var scale_factor: float = DEFAULT_GIZMO_TARGET_SIZE / max_dimension
			root_3d.scale = Vector3.ONE * scale_factor
			root_3d.position = -(aabb.get_center() * scale_factor)
	return root_3d

func _load_gltf_scene_root() -> Node3D:
	if GIZMO_SCENE_RESOURCE == null:
		return null
	var scene: Node = GIZMO_SCENE_RESOURCE.instantiate()
	if scene is Node3D:
		return scene as Node3D
	if scene != null:
		scene.queue_free()
	return null

func _collect_visual_aabb(node: Node, parent_transform: Transform3D) -> AABB:
	var combined: AABB = AABB()
	var has_value: bool = false
	var current_transform: Transform3D = parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform
	if node is VisualInstance3D:
		var visual: VisualInstance3D = node as VisualInstance3D
		var visual_aabb: AABB = visual.get_aabb()
		if visual_aabb.size != Vector3.ZERO:
			combined = current_transform * visual_aabb
			has_value = true
	for child: Node in node.get_children():
		if child is not Node3D:
			continue
		var child_aabb: AABB = _collect_visual_aabb(child, current_transform)
		if child_aabb.size == Vector3.ZERO:
			continue
		if not has_value:
			combined = child_aabb
			has_value = true
		else:
			combined = combined.merge(child_aabb)
	return combined if has_value else AABB()
