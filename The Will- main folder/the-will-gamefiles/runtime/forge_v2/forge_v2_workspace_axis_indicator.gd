extends Control
## Passive workspace compass. Uses the surviving Forge gizmo asset without any
## dependency on the retired Forge controller or authored geometry/history.

const GIZMO_SCENE: PackedScene = preload("res://scenes/ui/assets/transform_gizmo.glb")
const GIZMO_TARGET_SIZE := 1.45

var source_camera: Camera3D
var workspace_root: Node3D
var viewport_3d: SubViewport
var gizmo_pivot: Node3D
var texture_rect: TextureRect
var _redraw_needed := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_build_gizmo()
	# Tweens run after node processing. Sync immediately before rendering so the
	# compass and workspace use the same camera orientation, including in travel.
	RenderingServer.frame_pre_draw.connect(_sync_orientation)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_orientation):
		RenderingServer.frame_pre_draw.disconnect(_sync_orientation)


func bind_workspace(root: Node3D, camera: Camera3D) -> void:
	workspace_root = root
	source_camera = camera
	_redraw_needed = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_redraw_needed = true


func _sync_orientation() -> void:
	if not is_visible_in_tree() or not is_instance_valid(source_camera) or not is_instance_valid(workspace_root):
		viewport_3d.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_redraw_needed = true
		return
	var target_size := Vector2i(maxi(roundi(texture_rect.size.x), 2), maxi(roundi(texture_rect.size.y), 2))
	if viewport_3d.size != target_size:
		viewport_3d.size = target_size
		_redraw_needed = true
	# Workspace axes, expressed in the current camera frame; translation, zoom
	# and projection changes cannot rotate the compass or change its screen size.
	var orientation := source_camera.global_basis.orthonormalized().inverse() * workspace_root.global_basis.orthonormalized()
	if not gizmo_pivot.basis.is_equal_approx(orientation):
		gizmo_pivot.basis = orientation
		_redraw_needed = true
	if _redraw_needed:
		viewport_3d.render_target_update_mode = SubViewport.UPDATE_ONCE
		_redraw_needed = false


func _build_gizmo() -> void:
	viewport_3d = SubViewport.new()
	viewport_3d.name = "GizmoSubViewport"
	viewport_3d.size = Vector2i(74, 74)
	viewport_3d.own_world_3d = true
	viewport_3d.transparent_bg = true
	viewport_3d.gui_disable_input = true
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport_3d.msaa_3d = Viewport.MSAA_2X
	add_child(viewport_3d)

	# A TextureRect keeps update ownership here. A SubViewportContainer manages
	# its child's update policy and would keep rendering while visible.
	texture_rect = TextureRect.new()
	texture_rect.name = "GizmoTexture"
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.texture = viewport_3d.get_texture()
	add_child(texture_rect)
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_rect.offset_left = 6.0
	texture_rect.offset_top = 6.0
	texture_rect.offset_right = -6.0
	texture_rect.offset_bottom = -6.0

	gizmo_pivot = Node3D.new()
	gizmo_pivot.name = "GizmoPivot"
	viewport_3d.add_child(gizmo_pivot)
	var model := GIZMO_SCENE.instantiate() as Node3D
	var bounds := _collect_visual_aabb(model, Transform3D.IDENTITY)
	var fit := Node3D.new()
	var largest_dimension := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if largest_dimension > 0.0001:
		var fit_scale := GIZMO_TARGET_SIZE / largest_dimension
		fit.scale = Vector3.ONE * fit_scale
		fit.position = -bounds.get_center() * fit_scale
	gizmo_pivot.add_child(fit)
	fit.add_child(model)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.4
	camera.position.z = 3.0
	viewport_3d.add_child(camera)
	camera.make_current()
	var light := DirectionalLight3D.new()
	light.light_energy = 1.45
	light.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	viewport_3d.add_child(light)


func _collect_visual_aabb(node: Node3D, parent_transform: Transform3D) -> AABB:
	var combined := AABB()
	var current_transform := parent_transform * node.transform
	if node is VisualInstance3D:
		combined = current_transform * (node as VisualInstance3D).get_aabb()
	for child: Node in node.get_children():
		if child is Node3D:
			var child_bounds := _collect_visual_aabb(child as Node3D, current_transform)
			if child_bounds.size != Vector3.ZERO:
				combined = child_bounds if combined.size == Vector3.ZERO else combined.merge(child_bounds)
	return combined
