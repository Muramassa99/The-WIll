extends RefCounted
class_name CombatAnimationMotionNodeEditor

## Raycasts mouse input onto local editing surfaces and returns constrained positions.

const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationSessionStateScript = preload("res://core/models/combat_animation_session_state.gd")

const DRAG_TARGET_TIP: StringName = &"tip"
const DRAG_TARGET_POMMEL: StringName = &"pommel"
const DRAG_TARGET_WEAPON_ROTATION: StringName = &"weapon_rotation"
const DRAG_TARGET_TIP_CURVE_IN: StringName = &"tip_curve_in"
const DRAG_TARGET_TIP_CURVE_OUT: StringName = &"tip_curve_out"
const DRAG_TARGET_POMMEL_CURVE_IN: StringName = &"pommel_curve_in"
const DRAG_TARGET_POMMEL_CURVE_OUT: StringName = &"pommel_curve_out"
const CONTROL_SCREEN_PICK_RADIUS_PIXELS: float = 20.0
const CURVE_HANDLE_SCREEN_PICK_RADIUS_PIXELS: float = 34.0
const CURVE_HANDLE_MIN_LENGTH_METERS: float = 0.0001
const AUTO_CURVE_HANDLE_MIN_LENGTH_METERS: float = 0.025
const AUTO_CURVE_ENDPOINT_STRENGTH: float = 0.3333333
const AUTO_CURVE_MIDDLE_STRENGTH: float = 0.1666667
const WEAPON_ROTATION_HANDLE_DISTANCE_METERS: float = 0.22

var _dragging: bool = false
var _drag_target: StringName = StringName()

## Intersect a camera ray with a camera-facing drag plane through the current
## pommel. The pommel is the free translation handle for the whole weapon.
func raycast_pommel_on_view_drag_plane(
	camera: Camera3D,
	screen_position: Vector2,
	motion_node: CombatAnimationMotionNode,
	trajectory_root: Node3D
) -> Variant:
	if camera == null or motion_node == null or trajectory_root == null:
		return null
	var plane_normal: Vector3 = camera.global_transform.basis.z.normalized()
	var plane_origin: Vector3 = trajectory_root.global_transform * motion_node.pommel_position_local
	var hit_plane := Plane(plane_normal.normalized(), plane_origin)
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var intersection: Variant = hit_plane.intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		return null
	return trajectory_root.global_transform.affine_inverse() * (intersection as Vector3)

## Intersect a camera ray with the tip sphere centered at the pommel
## position with radius = weapon_total_length. Returns the closest hit
## position in trajectory-root local space, or null on miss.
func raycast_tip_on_sphere(
	camera: Camera3D,
	screen_position: Vector2,
	motion_node: CombatAnimationMotionNode,
	trajectory_root: Node3D,
	weapon_total_length: float
) -> Variant:
	if camera == null or motion_node == null or trajectory_root == null:
		return null
	var sphere_radius: float = maxf(weapon_total_length, 0.01)
	var sphere_center_global: Vector3 = trajectory_root.global_transform * motion_node.pommel_position_local
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position).normalized()
	var oc: Vector3 = ray_origin - sphere_center_global
	var a: float = ray_direction.dot(ray_direction)
	var b: float = 2.0 * oc.dot(ray_direction)
	var c: float = oc.dot(oc) - sphere_radius * sphere_radius
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0:
		return null
	var sqrt_disc: float = sqrt(discriminant)
	var t1: float = (-b - sqrt_disc) / (2.0 * a)
	var t2: float = (-b + sqrt_disc) / (2.0 * a)
	var t: float = t1 if t1 > 0.001 else t2
	if t < 0.001:
		return null
	var hit_global: Vector3 = ray_origin + ray_direction * t
	return trajectory_root.global_transform.affine_inverse() * hit_global

## Intersect a camera ray with a camera-facing drag plane through the current
## tip. The caller can then constrain the result back to the tip orbit sphere.
func raycast_tip_on_view_drag_plane(
	camera: Camera3D,
	screen_position: Vector2,
	motion_node: CombatAnimationMotionNode,
	trajectory_root: Node3D
) -> Variant:
	if camera == null or motion_node == null or trajectory_root == null:
		return null
	var plane_normal: Vector3 = camera.global_transform.basis.z.normalized()
	var plane_origin: Vector3 = trajectory_root.global_transform * motion_node.tip_position_local
	var hit_plane := Plane(plane_normal.normalized(), plane_origin)
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var intersection: Variant = hit_plane.intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		return null
	return trajectory_root.global_transform.affine_inverse() * (intersection as Vector3)

## Project a tip position onto the surface of the constraint sphere so that
## it remains at exactly weapon_total_length from the pommel.
func constrain_tip_to_sphere(
	pommel_position_local: Vector3,
	tip_position_local: Vector3,
	weapon_total_length: float
) -> Vector3:
	var radius: float = maxf(weapon_total_length, 0.01)
	var direction: Vector3 = tip_position_local - pommel_position_local
	if direction.length_squared() < 0.000001:
		return pommel_position_local + Vector3.UP * radius
	return pommel_position_local + direction.normalized() * radius

func get_weapon_center_local(motion_node: CombatAnimationMotionNode) -> Vector3:
	if motion_node == null:
		return Vector3.ZERO
	return motion_node.tip_position_local.lerp(motion_node.pommel_position_local, 0.5)

func get_weapon_axis_local(motion_node: CombatAnimationMotionNode) -> Vector3:
	if motion_node == null:
		return Vector3.FORWARD
	var axis: Vector3 = motion_node.tip_position_local - motion_node.pommel_position_local
	if axis.length_squared() <= 0.000001:
		return Vector3.FORWARD
	return axis.normalized()

func get_weapon_rotation_normal_local(motion_node: CombatAnimationMotionNode) -> Vector3:
	if motion_node == null:
		return Vector3.UP
	var orientation_rad: Vector3 = motion_node.weapon_orientation_degrees * (PI / 180.0)
	var rotation_basis: Basis = Basis.from_euler(orientation_rad)
	var axis: Vector3 = get_weapon_axis_local(motion_node)
	var desired_normal: Vector3 = rotation_basis * Vector3.UP
	desired_normal -= axis * desired_normal.dot(axis)
	if desired_normal.length_squared() <= 0.000001:
		desired_normal = Vector3.UP - axis * Vector3.UP.dot(axis)
	if desired_normal.length_squared() <= 0.000001:
		desired_normal = Vector3.RIGHT - axis * Vector3.RIGHT.dot(axis)
	return desired_normal.normalized()

func get_weapon_rotation_handle_local(
	motion_node: CombatAnimationMotionNode,
	handle_distance_meters: float = WEAPON_ROTATION_HANDLE_DISTANCE_METERS
) -> Vector3:
	return get_weapon_center_local(motion_node) + get_weapon_rotation_normal_local(motion_node) * handle_distance_meters

func build_tip_curve(motion_node_chain: Array, bake_interval: float = 0.015) -> Curve3D:
	return build_endpoint_curve(motion_node_chain, true, bake_interval)

func build_pommel_curve(motion_node_chain: Array, bake_interval: float = 0.015) -> Curve3D:
	return build_endpoint_curve(motion_node_chain, false, bake_interval)

func build_endpoint_curve(motion_node_chain: Array, use_tip_endpoint: bool, bake_interval: float = 0.015) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = bake_interval
	for node_index: int in range(motion_node_chain.size()):
		var motion_node: CombatAnimationMotionNode = motion_node_chain[node_index] as CombatAnimationMotionNode
		if motion_node == null:
			continue
		curve.add_point(
			_get_endpoint_position(motion_node, use_tip_endpoint),
			resolve_effective_curve_handle(motion_node_chain, node_index, use_tip_endpoint, true),
			resolve_effective_curve_handle(motion_node_chain, node_index, use_tip_endpoint, false)
		)
	return curve

func apply_effective_curve_handles_to_motion_node(
	motion_node: CombatAnimationMotionNode,
	motion_node_chain: Array,
	node_index: int
) -> void:
	if motion_node == null:
		return
	motion_node.tip_curve_in_handle = resolve_effective_curve_handle(motion_node_chain, node_index, true, true)
	motion_node.tip_curve_out_handle = resolve_effective_curve_handle(motion_node_chain, node_index, true, false)
	motion_node.pommel_curve_in_handle = resolve_effective_curve_handle(motion_node_chain, node_index, false, true)
	motion_node.pommel_curve_out_handle = resolve_effective_curve_handle(motion_node_chain, node_index, false, false)

func resolve_effective_curve_handle(
	motion_node_chain: Array,
	node_index: int,
	use_tip_endpoint: bool,
	use_in_handle: bool
) -> Vector3:
	if node_index < 0 or node_index >= motion_node_chain.size():
		return Vector3.ZERO
	var motion_node: CombatAnimationMotionNode = motion_node_chain[node_index] as CombatAnimationMotionNode
	if motion_node == null:
		return Vector3.ZERO
	var authored_handle: Vector3 = _get_endpoint_curve_handle(motion_node, use_tip_endpoint, use_in_handle)
	if authored_handle.length() >= CURVE_HANDLE_MIN_LENGTH_METERS:
		return authored_handle
	return _resolve_auto_curve_handle(motion_node_chain, node_index, use_tip_endpoint, use_in_handle)

func pick_drag_target(
	camera: Camera3D,
	screen_position: Vector2,
	motion_node: CombatAnimationMotionNode,
	trajectory_root: Node3D,
	fallback_focus: StringName
) -> StringName:
	if camera == null or motion_node == null or trajectory_root == null:
		return StringName()
	if fallback_focus == CombatAnimationSessionStateScript.FOCUS_WEAPON:
		var weapon_center: Vector3 = get_weapon_center_local(motion_node)
		var weapon_handle: Vector3 = get_weapon_rotation_handle_local(motion_node)
		var center_distance: float = _get_screen_pick_distance_pixels(camera, trajectory_root, weapon_center, screen_position)
		var handle_distance: float = _get_screen_pick_distance_pixels(camera, trajectory_root, weapon_handle, screen_position)
		if center_distance <= CONTROL_SCREEN_PICK_RADIUS_PIXELS or handle_distance <= CONTROL_SCREEN_PICK_RADIUS_PIXELS:
			return DRAG_TARGET_WEAPON_ROTATION
		return StringName()
	if fallback_focus == CombatAnimationSessionStateScript.FOCUS_POMMEL:
		var pommel_candidates: Array = []
		pommel_candidates.append([DRAG_TARGET_POMMEL, motion_node.pommel_position_local, CONTROL_SCREEN_PICK_RADIUS_PIXELS])
		if motion_node.pommel_curve_in_handle.length() >= CURVE_HANDLE_MIN_LENGTH_METERS:
			pommel_candidates.append([DRAG_TARGET_POMMEL_CURVE_IN, motion_node.pommel_position_local + motion_node.pommel_curve_in_handle, CURVE_HANDLE_SCREEN_PICK_RADIUS_PIXELS])
		if motion_node.pommel_curve_out_handle.length() >= CURVE_HANDLE_MIN_LENGTH_METERS:
			pommel_candidates.append([DRAG_TARGET_POMMEL_CURVE_OUT, motion_node.pommel_position_local + motion_node.pommel_curve_out_handle, CURVE_HANDLE_SCREEN_PICK_RADIUS_PIXELS])
		return _pick_best_screen_target(
			camera,
			trajectory_root,
			screen_position,
			pommel_candidates
		)
	var tip_candidates: Array = []
	tip_candidates.append([DRAG_TARGET_TIP, motion_node.tip_position_local, CONTROL_SCREEN_PICK_RADIUS_PIXELS])
	if motion_node.tip_curve_in_handle.length() >= CURVE_HANDLE_MIN_LENGTH_METERS:
		tip_candidates.append([DRAG_TARGET_TIP_CURVE_IN, motion_node.tip_position_local + motion_node.tip_curve_in_handle, CURVE_HANDLE_SCREEN_PICK_RADIUS_PIXELS])
	if motion_node.tip_curve_out_handle.length() >= CURVE_HANDLE_MIN_LENGTH_METERS:
		tip_candidates.append([DRAG_TARGET_TIP_CURVE_OUT, motion_node.tip_position_local + motion_node.tip_curve_out_handle, CURVE_HANDLE_SCREEN_PICK_RADIUS_PIXELS])
	return _pick_best_screen_target(
		camera,
		trajectory_root,
		screen_position,
		tip_candidates
	)

func raycast_curve_handle_on_view_drag_plane(
	camera: Camera3D,
	screen_position: Vector2,
	motion_node: CombatAnimationMotionNode,
	trajectory_root: Node3D,
	drag_target: StringName
) -> Variant:
	if camera == null or motion_node == null or trajectory_root == null:
		return null
	var handle_local: Vector3 = _resolve_curve_handle_local_position(motion_node, drag_target)
	var plane_normal: Vector3 = camera.global_transform.basis.z.normalized()
	var plane_origin: Vector3 = trajectory_root.global_transform * handle_local
	var hit_plane := Plane(plane_normal.normalized(), plane_origin)
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var intersection: Variant = hit_plane.intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		return null
	return trajectory_root.global_transform.affine_inverse() * (intersection as Vector3)

func begin_drag(target: StringName, _screen_position: Vector2 = Vector2.ZERO, _motion_node: CombatAnimationMotionNode = null) -> void:
	_dragging = true
	_drag_target = target

func end_drag() -> void:
	_dragging = false
	_drag_target = StringName()

func is_dragging() -> bool:
	return _dragging

func get_drag_target() -> StringName:
	return _drag_target

func resolve_weapon_orientation_drag(
	camera: Camera3D,
	screen_position: Vector2,
	motion_node: CombatAnimationMotionNode,
	trajectory_root: Node3D,
	handle_distance_meters: float = WEAPON_ROTATION_HANDLE_DISTANCE_METERS
) -> Variant:
	if camera == null or motion_node == null or trajectory_root == null:
		return null
	var weapon_center_local: Vector3 = get_weapon_center_local(motion_node)
	var weapon_center_global: Vector3 = trajectory_root.global_transform * weapon_center_local
	var hit_global: Variant = _raycast_global_sphere(
		camera,
		screen_position,
		weapon_center_global,
		maxf(handle_distance_meters, 0.01)
	)
	if hit_global == null:
		return null
	var hit_local: Vector3 = trajectory_root.global_transform.affine_inverse() * (hit_global as Vector3)
	var desired_normal: Vector3 = hit_local - weapon_center_local
	var weapon_axis: Vector3 = get_weapon_axis_local(motion_node)
	desired_normal -= weapon_axis * desired_normal.dot(weapon_axis)
	if desired_normal.length_squared() < 0.000001:
		return motion_node.weapon_orientation_degrees
	return _resolve_orientation_from_normal(desired_normal.normalized())

func _get_screen_pick_distance_pixels(
	camera: Camera3D,
	trajectory_root: Node3D,
	local_position: Vector3,
	screen_position: Vector2
) -> float:
	if camera == null or trajectory_root == null:
		return INF
	var world_position: Vector3 = trajectory_root.global_transform * local_position
	var projected: Vector2 = camera.unproject_position(world_position)
	return projected.distance_to(screen_position)

func _is_screen_position_near_local_point(
	camera: Camera3D,
	trajectory_root: Node3D,
	local_position: Vector3,
	screen_position: Vector2,
	pick_radius_pixels: float = CONTROL_SCREEN_PICK_RADIUS_PIXELS
) -> bool:
	return _get_screen_pick_distance_pixels(
		camera,
		trajectory_root,
		local_position,
		screen_position
	) <= pick_radius_pixels

func _pick_curve_handle_target(
	camera: Camera3D,
	trajectory_root: Node3D,
	screen_position: Vector2,
	candidates: Array
) -> StringName:
	var best_target: StringName = StringName()
	var best_distance: float = INF
	for candidate_variant: Variant in candidates:
		var candidate: Array = candidate_variant as Array
		if candidate.size() < 2:
			continue
		var candidate_target: StringName = candidate[0] as StringName
		var candidate_position: Vector3 = candidate[1] as Vector3
		var candidate_distance: float = _get_screen_pick_distance_pixels(
			camera,
			trajectory_root,
			candidate_position,
			screen_position
		)
		if candidate_distance < best_distance:
			best_distance = candidate_distance
			best_target = candidate_target
	if best_distance <= CURVE_HANDLE_SCREEN_PICK_RADIUS_PIXELS:
		return best_target
	return StringName()

func _pick_best_screen_target(
	camera: Camera3D,
	trajectory_root: Node3D,
	screen_position: Vector2,
	candidates: Array
) -> StringName:
	var best_target: StringName = StringName()
	var best_distance: float = INF
	for candidate_variant: Variant in candidates:
		var candidate: Array = candidate_variant as Array
		if candidate.size() < 3:
			continue
		var candidate_target: StringName = candidate[0] as StringName
		var candidate_position: Vector3 = candidate[1] as Vector3
		var candidate_radius: float = float(candidate[2])
		var candidate_distance: float = _get_screen_pick_distance_pixels(
			camera,
			trajectory_root,
			candidate_position,
			screen_position
		)
		if candidate_distance <= candidate_radius and candidate_distance < best_distance:
			best_distance = candidate_distance
			best_target = candidate_target
	return best_target

func _resolve_curve_handle_local_position(
	motion_node: CombatAnimationMotionNode,
	drag_target: StringName
) -> Vector3:
	if motion_node == null:
		return Vector3.ZERO
	match drag_target:
		DRAG_TARGET_TIP_CURVE_IN:
			return motion_node.tip_position_local + motion_node.tip_curve_in_handle
		DRAG_TARGET_TIP_CURVE_OUT:
			return motion_node.tip_position_local + motion_node.tip_curve_out_handle
		DRAG_TARGET_POMMEL_CURVE_IN:
			return motion_node.pommel_position_local + motion_node.pommel_curve_in_handle
		DRAG_TARGET_POMMEL_CURVE_OUT:
			return motion_node.pommel_position_local + motion_node.pommel_curve_out_handle
		_:
			return motion_node.tip_position_local

func _get_endpoint_position(motion_node: CombatAnimationMotionNode, use_tip_endpoint: bool) -> Vector3:
	if motion_node == null:
		return Vector3.ZERO
	if use_tip_endpoint:
		return motion_node.tip_position_local
	return motion_node.pommel_position_local

func _get_endpoint_curve_handle(
	motion_node: CombatAnimationMotionNode,
	use_tip_endpoint: bool,
	use_in_handle: bool
) -> Vector3:
	if motion_node == null:
		return Vector3.ZERO
	if use_tip_endpoint:
		return motion_node.tip_curve_in_handle if use_in_handle else motion_node.tip_curve_out_handle
	return motion_node.pommel_curve_in_handle if use_in_handle else motion_node.pommel_curve_out_handle

func _resolve_auto_curve_handle(
	motion_node_chain: Array,
	node_index: int,
	use_tip_endpoint: bool,
	use_in_handle: bool
) -> Vector3:
	var current_node: CombatAnimationMotionNode = motion_node_chain[node_index] as CombatAnimationMotionNode
	if current_node == null:
		return Vector3.ZERO
	var current_position: Vector3 = _get_endpoint_position(current_node, use_tip_endpoint)
	var previous_position: Variant = null
	var next_position: Variant = null
	if node_index > 0:
		var previous_node: CombatAnimationMotionNode = motion_node_chain[node_index - 1] as CombatAnimationMotionNode
		if previous_node != null:
			previous_position = _get_endpoint_position(previous_node, use_tip_endpoint)
	if node_index < motion_node_chain.size() - 1:
		var next_node: CombatAnimationMotionNode = motion_node_chain[node_index + 1] as CombatAnimationMotionNode
		if next_node != null:
			next_position = _get_endpoint_position(next_node, use_tip_endpoint)
	var auto_handle: Vector3 = Vector3.ZERO
	if previous_position is Vector3 and next_position is Vector3:
		var smooth_tangent: Vector3 = ((next_position as Vector3) - (previous_position as Vector3)) * AUTO_CURVE_MIDDLE_STRENGTH
		auto_handle = -smooth_tangent if use_in_handle else smooth_tangent
	elif use_in_handle and previous_position is Vector3:
		auto_handle = ((previous_position as Vector3) - current_position) * AUTO_CURVE_ENDPOINT_STRENGTH
	elif not use_in_handle and next_position is Vector3:
		auto_handle = ((next_position as Vector3) - current_position) * AUTO_CURVE_ENDPOINT_STRENGTH
	if auto_handle.length() < AUTO_CURVE_HANDLE_MIN_LENGTH_METERS:
		return Vector3.ZERO
	return auto_handle

func _raycast_global_sphere(
	camera: Camera3D,
	screen_position: Vector2,
	sphere_center_global: Vector3,
	sphere_radius: float
) -> Variant:
	if camera == null:
		return null
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position).normalized()
	var oc: Vector3 = ray_origin - sphere_center_global
	var a: float = ray_direction.dot(ray_direction)
	var b: float = 2.0 * oc.dot(ray_direction)
	var c: float = oc.dot(oc) - sphere_radius * sphere_radius
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0:
		return null
	var sqrt_disc: float = sqrt(discriminant)
	var t1: float = (-b - sqrt_disc) / (2.0 * a)
	var t2: float = (-b + sqrt_disc) / (2.0 * a)
	var t: float = t1 if t1 > 0.001 else t2
	if t < 0.001:
		return null
	return ray_origin + ray_direction * t

func _resolve_orientation_from_normal(desired_normal: Vector3) -> Vector3:
	var normalized_normal: Vector3 = desired_normal.normalized()
	var base_up: Vector3 = Vector3.UP
	var dot_value: float = clampf(base_up.dot(normalized_normal), -1.0, 1.0)
	var basis: Basis
	if dot_value >= 0.9999:
		basis = Basis.IDENTITY
	elif dot_value <= -0.9999:
		basis = Basis(Vector3.RIGHT, PI)
	else:
		var rotation_axis: Vector3 = base_up.cross(normalized_normal).normalized()
		var rotation_angle: float = acos(dot_value)
		basis = Basis(rotation_axis, rotation_angle)
	var euler_degrees: Vector3 = basis.get_euler() * (180.0 / PI)
	return Vector3(
		snappedf(euler_degrees.x, 0.1),
		snappedf(euler_degrees.y, 0.1),
		snappedf(euler_degrees.z, 0.1)
	)
