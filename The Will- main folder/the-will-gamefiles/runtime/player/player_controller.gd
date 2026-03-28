extends CharacterBody3D
class_name PlayerController3D

const UserSettingsStateScript = preload("res://core/models/user_settings_state.gd")
const UserSettingsRuntimeScript = preload("res://runtime/system/user_settings_runtime.gd")
@export var move_speed: float = 5.5
@export var acceleration: float = 18.0
@export var air_control: float = 8.0
@export var jump_velocity: float = 6.0
@export var turn_speed: float = 10.0
@export var mouse_sensitivity: float = 0.0025
@export var min_pitch_degrees: float = -40.0
@export var max_pitch_degrees: float = 80.0
@export var interaction_distance: float = 4.5

@onready var visual_root: Node3D = $VisualRoot
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var interaction_raycast: RayCast3D = $CameraPivot/SpringArm3D/Camera3D/InteractionRayCast3D
@onready var system_menu_overlay: CanvasLayer = $SystemMenuOverlay

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var ui_mode_enabled: bool = false
var forge_inventory_state: PlayerForgeInventoryState = PlayerForgeInventoryState.new()
var forge_wip_library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryState.new()
var user_settings_state: Resource = null

func _enter_tree() -> void:
	_ensure_runtime_input_actions()

func _ready() -> void:
	_ensure_runtime_input_actions()
	UserSettingsRuntimeScript.apply_settings(user_settings_state, get_tree().root)
	forge_wip_library_state = PlayerForgeWipLibraryState.load_or_create()
	if system_menu_overlay != null:
		system_menu_overlay.configure(self, user_settings_state)
	interaction_raycast.target_position = Vector3(0.0, 0.0, -interaction_distance)
	spring_arm.add_excluded_object(get_rid())
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if not _has_runtime_input_actions():
		_ensure_runtime_input_actions()
		if not _has_runtime_input_actions():
			return
	if ui_mode_enabled:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var motion_event: InputEventMouseMotion = event
		camera_pivot.rotation.y -= motion_event.screen_relative.x * mouse_sensitivity
		camera_pivot.rotation.x -= motion_event.screen_relative.y * mouse_sensitivity
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)
		return

	if event.is_action_pressed(&"ui_settings"):
		_open_system_menu_page(&"settings")
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"ui_social"):
		_open_system_menu_page(&"social")
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"menu_toggle"):
		_toggle_system_menu()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"interact"):
		_try_interact()
		return

func _physics_process(delta: float) -> void:
	if not _has_runtime_input_actions():
		_ensure_runtime_input_actions()
		if not _has_runtime_input_actions():
			velocity.x = 0.0
			velocity.z = 0.0
			if not is_on_floor():
				velocity.y -= gravity * delta
			elif velocity.y < 0.0:
				velocity.y = -0.01
			move_and_slide()
			return
	if ui_mode_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		elif velocity.y < 0.0:
			velocity.y = -0.01
		move_and_slide()
		return

	var input_vector: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var move_direction: Vector3 = _get_move_direction(input_vector)
	var desired_velocity: Vector3 = move_direction * move_speed
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var blend_rate: float = acceleration if is_on_floor() else air_control
	horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, blend_rate * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if is_on_floor() and Input.is_action_just_pressed(&"jump"):
		velocity.y = jump_velocity

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.01

	move_and_slide()
	_update_visual_facing(move_direction, delta)

func _get_move_direction(input_vector: Vector2) -> Vector3:
	if input_vector.is_zero_approx():
		return Vector3.ZERO

	var movement_basis: Basis = camera_pivot.global_basis
	var forward: Vector3 = -movement_basis.z
	var right: Vector3 = movement_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	return (right * input_vector.x + forward * -input_vector.y).normalized()

func _update_visual_facing(move_direction: Vector3, delta: float) -> void:
	if move_direction == Vector3.ZERO:
		return
	var target_yaw: float = atan2(move_direction.x, move_direction.z)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, turn_speed * delta)

func _try_interact() -> void:
	interaction_raycast.force_raycast_update()

	var interactable: Object = null
	if interaction_raycast.is_colliding():
		interactable = _resolve_interactable(interaction_raycast.get_collider())

	if interactable == null:
		interactable = _find_nearby_interactable()

	if interactable == null:
		print("PlayerController3D: no interactable found")
		return

	interactable.call("interact", self)

func _resolve_interactable(candidate: Object) -> Object:
	var current: Object = candidate
	while current != null:
		if current.has_method("interact"):
			return current
		if current is Node:
			var current_node: Node = current
			current = current_node.get_parent()
			continue
		break
	return null

func _find_nearby_interactable() -> Object:
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var best_candidate: Node3D = null
	var best_distance: float = interaction_distance + 0.75
	for candidate_node: Node in get_tree().get_nodes_in_group("interactable"):
		if not candidate_node is Node3D:
			continue
		var candidate: Node3D = candidate_node
		var to_candidate: Vector3 = candidate.global_position - global_position
		var distance: float = to_candidate.length()
		if distance > best_distance:
			continue
		var flat_direction: Vector3 = to_candidate
		flat_direction.y = 0.0
		if not flat_direction.is_zero_approx() and forward.dot(flat_direction.normalized()) < 0.2:
			continue
		best_candidate = candidate
		best_distance = distance

	return best_candidate

func _toggle_mouse_capture() -> void:
	if ui_mode_enabled:
		return
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _toggle_system_menu() -> void:
	if system_menu_overlay == null:
		_toggle_mouse_capture()
		return
	system_menu_overlay.toggle_menu()

func _open_system_menu_page(page_id: StringName) -> void:
	if system_menu_overlay == null:
		_toggle_mouse_capture()
		return
	if system_menu_overlay.has_method("open_page"):
		system_menu_overlay.call("open_page", page_id)
		return
	system_menu_overlay.call("toggle_menu")

func set_ui_mode_enabled(enabled: bool) -> void:
	ui_mode_enabled = enabled
	if enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func get_forge_inventory_state() -> PlayerForgeInventoryState:
	if forge_inventory_state == null:
		forge_inventory_state = PlayerForgeInventoryState.new()
	return forge_inventory_state

func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
	if forge_wip_library_state == null:
		forge_wip_library_state = PlayerForgeWipLibraryState.new()
	return forge_wip_library_state

func ensure_debug_forge_inventory(material_lookup: Dictionary, default_quantity: int) -> void:
	if default_quantity <= 0:
		return
	var inventory_state: PlayerForgeInventoryState = get_forge_inventory_state()
	if inventory_state.has_any_material_stacks():
		return
	var material_ids: Array = material_lookup.keys()
	material_ids.sort()
	for material_id_value in material_ids:
		var material_id: StringName = material_id_value
		inventory_state.set_quantity(material_id, default_quantity)

func _ensure_runtime_input_actions() -> void:
	if user_settings_state == null:
		user_settings_state = UserSettingsStateScript.load_or_create()
	UserSettingsRuntimeScript.ensure_input_actions(user_settings_state)

func _has_runtime_input_actions() -> bool:
	return InputMap.has_action(&"move_left") \
		and InputMap.has_action(&"move_right") \
		and InputMap.has_action(&"move_forward") \
		and InputMap.has_action(&"move_back") \
		and InputMap.has_action(&"jump") \
		and InputMap.has_action(&"menu_toggle") \
		and InputMap.has_action(&"interact")
