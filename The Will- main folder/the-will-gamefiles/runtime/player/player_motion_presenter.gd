extends RefCounted
class_name PlayerMotionPresenter

const UserSettingsRuntimeScript = preload("res://runtime/system/user_settings_runtime.gd")
const PlayerAimContextScript = preload("res://core/models/player_aim_context.gd")

func ensure_runtime_input_actions(user_settings_state: UserSettingsState) -> void:
	UserSettingsRuntimeScript.ensure_input_actions(user_settings_state)

func has_runtime_input_actions() -> bool:
	return InputMap.has_action(&"move_left") \
		and InputMap.has_action(&"move_right") \
		and InputMap.has_action(&"move_forward") \
		and InputMap.has_action(&"move_back") \
		and InputMap.has_action(&"jump") \
		and InputMap.has_action(&"sprint") \
		and InputMap.has_action(&"menu_toggle") \
		and InputMap.has_action(&"interact")

func apply_mouse_look(
		camera_pivot: Node3D,
		motion_event: InputEventMouseMotion,
		mouse_sensitivity: float,
		min_pitch_degrees: float,
		max_pitch_degrees: float
	) -> void:
	if camera_pivot == null or motion_event == null:
		return
	camera_pivot.rotation.y -= motion_event.screen_relative.x * mouse_sensitivity
	camera_pivot.rotation.x -= motion_event.screen_relative.y * mouse_sensitivity
	camera_pivot.rotation.x = clampf(
		camera_pivot.rotation.x,
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)

func get_move_direction(camera_pivot: Node3D, input_vector: Vector2) -> Vector3:
	if camera_pivot == null or input_vector.is_zero_approx():
		return Vector3.ZERO
	var movement_basis: Basis = camera_pivot.global_basis
	var forward: Vector3 = -movement_basis.z
	var right: Vector3 = movement_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	return (right * input_vector.x + forward * -input_vector.y).normalized()

func resolve_target_move_speed(
		move_speed: float,
		sprint_speed: float,
		backpedal_speed_multiplier: float,
		input_vector: Vector2,
		sprinting: bool
	) -> float:
	var target_speed: float = sprint_speed if sprinting else move_speed
	if input_vector.y > 0.01:
		target_speed *= backpedal_speed_multiplier
	return target_speed

func apply_vertical_motion(body: CharacterBody3D, gravity: float, delta: float) -> void:
	if body == null:
		return
	if not body.is_on_floor():
		body.velocity.y -= gravity * delta
	elif body.velocity.y < 0.0:
		body.velocity.y = -0.01

func update_visual_facing(visual_root: Node3D, move_direction: Vector3, turn_speed: float, delta: float) -> void:
	if visual_root == null or move_direction.is_zero_approx():
		return
	var target_yaw: float = atan2(move_direction.x, move_direction.z)
	visual_root.rotation.y = lerp_angle(
		visual_root.rotation.y,
		target_yaw,
		maxf(turn_speed, 0.01) * delta
	)

func sync_humanoid_locomotion(
		humanoid_rig: Node3D,
		velocity: Vector3,
		target_move_speed: float,
		grounded: bool,
		vertical_velocity: float,
		sprinting: bool
	) -> void:
	if humanoid_rig == null:
		return
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	humanoid_rig.update_locomotion_state(
		horizontal_speed,
		maxf(target_move_speed, 0.001),
		grounded,
		vertical_velocity,
		sprinting
	)

func refresh_aim_context(current_aim_context, camera: Camera3D, aim_max_range_meters: float):
	var resolved_aim_context = current_aim_context
	if resolved_aim_context == null:
		resolved_aim_context = PlayerAimContextScript.new()
	if camera == null:
		return resolved_aim_context
	var forward: Vector3 = -camera.global_basis.z
	resolved_aim_context.camera_origin = camera.global_position
	resolved_aim_context.camera_direction = forward.normalized()
	resolved_aim_context.aim_point = camera.global_position + forward.normalized() * aim_max_range_meters
	resolved_aim_context.aim_distance = aim_max_range_meters
	var flat_direction := Vector3(forward.x, 0.0, forward.z)
	resolved_aim_context.flat_direction = flat_direction.normalized() if flat_direction.length_squared() > 0.0 else Vector3.ZERO
	return resolved_aim_context
