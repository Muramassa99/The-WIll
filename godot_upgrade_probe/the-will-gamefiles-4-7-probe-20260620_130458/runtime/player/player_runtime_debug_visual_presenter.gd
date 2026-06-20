extends RefCounted
class_name PlayerRuntimeDebugVisualPresenter

const DEBUG_ROOT_NAME := "RuntimeVisualDebugRoot"
const COLLISION_DEBUG_COLOR_META := &"runtime_original_collision_debug_color"
const COLLISION_DEBUG_FILL_META := &"runtime_original_collision_debug_fill"
const RAYCAST_DEBUG_COLOR_META := &"runtime_original_raycast_debug_color"
const RAYCAST_DEBUG_THICKNESS_META := &"runtime_original_raycast_debug_thickness"
const HIDDEN_COLLISION_DEBUG_COLOR := Color(0.0, 0.0, 0.0, 0.0)
const HIDDEN_RAYCAST_DEBUG_COLOR := Color(0.0, 0.0, 0.001, 0.0)
const FALLBACK_COLLISION_DEBUG_COLOR := Color(0.1, 0.72, 1.0, 0.42)

func sync_debug_visuals(
	owner: Node3D,
	camera: Camera3D,
	interaction_raycast: RayCast3D,
	enabled: bool,
	scene_tree: SceneTree
) -> void:
	if owner == null:
		return
	var debug_root: Node3D = owner.get_node_or_null(DEBUG_ROOT_NAME) as Node3D
	if debug_root == null:
		return
	_clear_debug_root(debug_root)
	debug_root.visible = false

func sync_engine_collision_shape_debug_visuals(scene_tree: SceneTree, enabled: bool) -> void:
	if scene_tree == null or scene_tree.root == null:
		return
	_sync_collision_shape_debug_visuals_recursive(scene_tree.root, enabled)

func _clear_debug_root(debug_root: Node3D) -> void:
	if debug_root == null:
		return
	for child: Node in debug_root.get_children():
		debug_root.remove_child(child)
		child.queue_free()

func _sync_collision_shape_debug_visuals_recursive(node: Node, enabled: bool) -> void:
	if node == null:
		return
	var collision_shape: CollisionShape3D = node as CollisionShape3D
	if collision_shape != null:
		_apply_collision_shape_debug_visual(collision_shape, enabled)
	var raycast: RayCast3D = node as RayCast3D
	if raycast != null:
		_apply_raycast_debug_visual(raycast, enabled)
	for child: Node in node.get_children():
		_sync_collision_shape_debug_visuals_recursive(child, enabled)

func _apply_collision_shape_debug_visual(collision_shape: CollisionShape3D, enabled: bool) -> void:
	if collision_shape == null:
		return
	if not collision_shape.has_meta(COLLISION_DEBUG_COLOR_META):
		collision_shape.set_meta(COLLISION_DEBUG_COLOR_META, collision_shape.debug_color)
	if not collision_shape.has_meta(COLLISION_DEBUG_FILL_META):
		collision_shape.set_meta(COLLISION_DEBUG_FILL_META, collision_shape.debug_fill)
	if enabled:
		collision_shape.debug_color = _resolve_visible_collision_debug_color(collision_shape)
		collision_shape.debug_fill = bool(collision_shape.get_meta(COLLISION_DEBUG_FILL_META, true))
		return
	collision_shape.debug_color = HIDDEN_COLLISION_DEBUG_COLOR
	collision_shape.debug_fill = false

func _resolve_visible_collision_debug_color(collision_shape: CollisionShape3D) -> Color:
	var original_color: Color = collision_shape.get_meta(COLLISION_DEBUG_COLOR_META, HIDDEN_COLLISION_DEBUG_COLOR) as Color
	if original_color.a > 0.001:
		return original_color
	var project_color: Variant = ProjectSettings.get_setting("debug/shapes/collision/shape_color", FALLBACK_COLLISION_DEBUG_COLOR)
	if project_color is Color:
		var resolved_color: Color = project_color as Color
		if resolved_color.a > 0.001:
			return resolved_color
	return FALLBACK_COLLISION_DEBUG_COLOR

func _apply_raycast_debug_visual(raycast: RayCast3D, enabled: bool) -> void:
	if raycast == null:
		return
	if not raycast.has_meta(RAYCAST_DEBUG_COLOR_META):
		raycast.set_meta(RAYCAST_DEBUG_COLOR_META, raycast.debug_shape_custom_color)
	if not raycast.has_meta(RAYCAST_DEBUG_THICKNESS_META):
		raycast.set_meta(RAYCAST_DEBUG_THICKNESS_META, raycast.debug_shape_thickness)
	if enabled:
		raycast.debug_shape_custom_color = raycast.get_meta(RAYCAST_DEBUG_COLOR_META, Color(0.0, 0.0, 0.0, 1.0)) as Color
		raycast.debug_shape_thickness = int(raycast.get_meta(RAYCAST_DEBUG_THICKNESS_META, 2))
		return
	raycast.debug_shape_custom_color = HIDDEN_RAYCAST_DEBUG_COLOR
	raycast.debug_shape_thickness = 1
