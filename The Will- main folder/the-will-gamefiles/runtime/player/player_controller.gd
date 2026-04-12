extends CharacterBody3D
class_name PlayerController3D

const UserSettingsStateScript = preload("res://core/models/user_settings_state.gd")
const UserSettingsRuntimeScript = preload("res://runtime/system/user_settings_runtime.gd")
const PlayerAimContextScript = preload("res://core/models/player_aim_context.gd")
const MaterialPipelineServiceScript = preload("res://services/material_pipeline_service.gd")
const ForgeServiceScript = preload("res://services/forge_service.gd")
const TestPrintMeshBuilderScript = preload("res://runtime/forge/test_print_mesh_builder.gd")
const PlayerInteractionPresenterScript = preload("res://runtime/player/player_interaction_presenter.gd")
const PlayerRuntimeStatePresenterScript = preload("res://runtime/player/player_runtime_state_presenter.gd")
const PlayerForgeTestPresenterScript = preload("res://runtime/player/player_forge_test_presenter.gd")
const PlayerEquippedItemPresenterScript = preload("res://runtime/player/player_equipped_item_presenter.gd")
const PlayerUiSurfacePresenterScript = preload("res://runtime/player/player_ui_surface_presenter.gd")
const PlayerMotionPresenterScript = preload("res://runtime/player/player_motion_presenter.gd")
const PlayerGameplayHudOverlayScript = preload("res://runtime/ui/player_gameplay_hud_overlay.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")
const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const DEFAULT_FORGE_VIEW_TUNING_RESOURCE: ForgeViewTuningDef = preload("res://core/defs/forge/forge_view_tuning_default.tres")

@export var move_speed: float = 5.5
@export var sprint_speed: float = 8.0
@export_range(0.1, 1.0, 0.01) var backpedal_speed_multiplier: float = 0.9
@export var acceleration: float = 18.0
@export var air_control: float = 8.0
@export var jump_velocity: float = 6.0
@export var turn_speed: float = 10.0
@export var mouse_sensitivity: float = 0.0025
@export var min_pitch_degrees: float = -40.0
@export var max_pitch_degrees: float = 80.0
@export var aim_max_range_meters: float = 60.0
@export var interaction_distance: float = 4.5
@export var weapons_drawn: bool = true

@onready var visual_root: Node3D = $VisualRoot
@onready var humanoid_rig: Node3D = $VisualRoot/PlayerHumanoidRig
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var interaction_raycast: RayCast3D = $CameraPivot/SpringArm3D/Camera3D/InteractionRayCast3D
@onready var system_menu_overlay: CanvasLayer = $SystemMenuOverlay
@onready var player_inventory_overlay: CanvasLayer = $PlayerInventoryOverlay
@onready var crosshair_overlay: Control = $PlayerCrosshairOverlay/Crosshair
@onready var gameplay_hud_overlay: CanvasLayer = $PlayerGameplayHudOverlay

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var ui_mode_enabled: bool = false
var user_settings_state: UserSettingsState = UserSettingsStateScript.load_or_create()
var body_inventory_state = null
var personal_storage_state = null
var equipment_state = null
var forge_inventory_state: PlayerForgeInventoryState = null
var forge_wip_library_state: PlayerForgeWipLibraryState = null
var material_pipeline_service = MaterialPipelineServiceScript.new()
var forge_service: ForgeService = ForgeServiceScript.new(DEFAULT_FORGE_RULES_RESOURCE)
var held_item_mesh_builder: TestPrintMeshBuilder = TestPrintMeshBuilderScript.new()
var interaction_presenter = PlayerInteractionPresenterScript.new()
var state_presenter = PlayerRuntimeStatePresenterScript.new()
var forge_test_presenter = PlayerForgeTestPresenterScript.new()
var equipped_item_presenter = PlayerEquippedItemPresenterScript.new()
var ui_surface_presenter = PlayerUiSurfacePresenterScript.new()
var motion_presenter = PlayerMotionPresenterScript.new()
var cached_material_lookup: Dictionary = {}
var held_item_nodes: Dictionary = {}
var current_aim_context = PlayerAimContextScript.new()

func _enter_tree() -> void:
	_ensure_runtime_input_actions()

func _ready() -> void:
	_ensure_runtime_input_actions()
	UserSettingsRuntimeScript.apply_settings(user_settings_state, get_tree().root)
	cached_material_lookup = material_pipeline_service.build_base_material_lookup()
	if system_menu_overlay != null and system_menu_overlay.has_method("configure"):
		system_menu_overlay.configure(self, user_settings_state)
	if interaction_raycast != null:
		interaction_raycast.target_position = Vector3(0.0, 0.0, -interaction_distance)
	if spring_arm != null:
		spring_arm.add_excluded_object(get_rid())
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_refresh_aim_context()
	_sync_crosshair_visibility()
	_sync_equipped_test_meshes()
	if gameplay_hud_overlay != null and gameplay_hud_overlay.has_method("configure"):
		gameplay_hud_overlay.configure(self)

func _unhandled_input(event: InputEvent) -> void:
	if not _has_runtime_input_actions():
		_ensure_runtime_input_actions()
		if not _has_runtime_input_actions():
			return
	if ui_mode_enabled:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var motion_event: InputEventMouseMotion = event
		motion_presenter.apply_mouse_look(
			camera_pivot,
			motion_event,
			mouse_sensitivity,
			min_pitch_degrees,
			max_pitch_degrees
		)
		_refresh_aim_context()
		return

	if event.is_action_pressed(&"ui_settings"):
		_open_system_menu_page(&"settings")
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"ui_social"):
		_open_system_menu_page(&"social")
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"ui_inventory"):
		_toggle_player_inventory_page(&"inventory", "Player Inventory")
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"ui_character"):
		_toggle_player_inventory_page(&"equipment", "Character Equipment")
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"menu_toggle"):
		_toggle_system_menu()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"interact"):
		_try_interact()
		return

	if event.is_action_pressed(&"skill_block"):
		_activate_skill_slot(&"skill_block")
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"skill_evade"):
		_activate_skill_slot(&"skill_evade")
		get_viewport().set_input_as_handled()
		return

	for slot_id: StringName in PlayerSkillSlotStateScript.SKILL_SLOT_IDS:
		if event.is_action_pressed(slot_id):
			_activate_skill_slot(slot_id)
			get_viewport().set_input_as_handled()
			return

func _physics_process(delta: float) -> void:
	if not _has_runtime_input_actions():
		_ensure_runtime_input_actions()
	if ui_mode_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_vertical_motion(delta)
		move_and_slide()
		_sync_humanoid_locomotion(0.0, false)
		return

	var input_vector: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var move_direction: Vector3 = _get_move_direction(input_vector)
	var sprinting: bool = Input.is_action_pressed(&"sprint") and not input_vector.is_zero_approx()
	var target_move_speed: float = _resolve_target_move_speed(input_vector, sprinting)
	var desired_velocity: Vector3 = move_direction * target_move_speed
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var blend_rate: float = acceleration if is_on_floor() else air_control
	horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, blend_rate * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if is_on_floor() and Input.is_action_just_pressed(&"jump"):
		velocity.y = jump_velocity

	_apply_vertical_motion(delta)
	move_and_slide()
	_refresh_aim_context()
	_update_visual_facing(move_direction, delta)
	_sync_humanoid_locomotion(target_move_speed, sprinting)

func _apply_vertical_motion(delta: float) -> void:
	motion_presenter.apply_vertical_motion(self, gravity, delta)

func _get_move_direction(input_vector: Vector2) -> Vector3:
	return motion_presenter.get_move_direction(camera_pivot, input_vector)

func _update_visual_facing(move_direction: Vector3, delta: float) -> void:
	motion_presenter.update_visual_facing(visual_root, move_direction, turn_speed, delta)

func _try_interact() -> void:
	interaction_presenter.try_interact(
		interaction_raycast,
		camera,
		global_position,
		interaction_distance,
		get_tree(),
		self
	)

func _activate_skill_slot(slot_id: StringName) -> void:
	if gameplay_hud_overlay != null:
		gameplay_hud_overlay.activate_skill_slot(slot_id)

func _toggle_system_menu() -> void:
	ui_surface_presenter.toggle_system_menu(system_menu_overlay)

func _open_system_menu_page(page_id: StringName) -> void:
	ui_surface_presenter.open_system_menu_page(system_menu_overlay, page_id)

func _toggle_player_inventory_page(page_id: StringName, source_label: String = "Player Inventory") -> void:
	ui_surface_presenter.toggle_player_inventory_page(player_inventory_overlay, self, page_id, source_label)

func open_player_inventory_page(page_id: StringName, source_label: String = "Player Inventory") -> void:
	ui_surface_presenter.open_player_inventory_page(player_inventory_overlay, self, page_id, source_label)

func set_ui_mode_enabled(enabled: bool) -> void:
	ui_mode_enabled = enabled
	if enabled:
		velocity.x = 0.0
		velocity.z = 0.0
	ui_surface_presenter.set_mouse_mode_for_ui(enabled)
	_refresh_aim_context()
	_sync_crosshair_visibility()
	if gameplay_hud_overlay != null and gameplay_hud_overlay.has_method("set_hud_visible"):
		gameplay_hud_overlay.set_hud_visible(not enabled)

func get_humanoid_standing_height_meters() -> float:
	if humanoid_rig != null:
		return humanoid_rig.get_standing_height_meters()
	return 0.0

func get_body_inventory_state():
	body_inventory_state = state_presenter.get_body_inventory_state(body_inventory_state)
	return body_inventory_state

func get_personal_storage_state():
	personal_storage_state = state_presenter.get_personal_storage_state(personal_storage_state)
	return personal_storage_state

func get_equipment_state():
	equipment_state = state_presenter.get_equipment_state(equipment_state)
	return equipment_state

func get_forge_inventory_state() -> PlayerForgeInventoryState:
	forge_inventory_state = state_presenter.get_forge_inventory_state(forge_inventory_state)
	return forge_inventory_state

func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
	forge_wip_library_state = state_presenter.get_forge_wip_library_state(forge_wip_library_state)
	return forge_wip_library_state

func ensure_body_inventory_seeded(seed_def: Resource = null) -> void:
	state_presenter.ensure_body_inventory_seeded(get_body_inventory_state(), seed_def)

func ensure_forge_inventory_seeded(
		material_lookup: Dictionary,
		inventory_seed_def: Resource = null,
		fallback_quantity: int = 0,
		debug_bonus_quantity: int = 0
	) -> void:
	if material_lookup.is_empty():
		return
	state_presenter.ensure_forge_inventory_seeded(
		get_forge_inventory_state(),
		material_lookup,
		inventory_seed_def,
		fallback_quantity,
		debug_bonus_quantity
	)

func set_selected_forge_wip_id(saved_wip_id: StringName) -> void:
	state_presenter.set_selected_forge_wip_id(get_forge_wip_library_state(), saved_wip_id)

func preview_saved_wip_test_status(saved_wip_id: StringName) -> Dictionary:
	return forge_test_presenter.preview_saved_wip_test_status(
		saved_wip_id,
		get_forge_wip_library_state(),
		forge_service,
		_get_material_lookup()
	)

func preview_saved_wip_grip_hold_layout(saved_wip_id: StringName, dominant_slot_id: StringName) -> Dictionary:
	return forge_test_presenter.preview_saved_wip_grip_hold_layout(
		saved_wip_id,
		dominant_slot_id,
		get_forge_wip_library_state(),
		forge_service,
		_get_material_lookup(),
		humanoid_rig,
		DEFAULT_FORGE_RULES_RESOURCE.cell_world_size_meters
	)

func equip_saved_wip_to_hand(saved_wip_id: StringName, slot_id: StringName) -> Dictionary:
	return forge_test_presenter.equip_saved_wip_to_hand(
		saved_wip_id,
		slot_id,
		get_forge_wip_library_state(),
		forge_service,
		_get_material_lookup(),
		get_equipment_state(),
		Callable(self, "_sync_equipped_test_meshes"),
		equipped_item_presenter
	)

func clear_equipment_slot(slot_id: StringName) -> void:
	forge_test_presenter.clear_equipment_slot(
		slot_id,
		get_equipment_state(),
		Callable(self, "_sync_equipped_test_meshes")
	)

func set_weapons_drawn(draw_weapons: bool) -> void:
	if weapons_drawn == draw_weapons:
		return
	weapons_drawn = draw_weapons
	_sync_equipped_test_meshes()

func get_current_aim_context():
	return current_aim_context

func get_current_aim_point() -> Vector3:
	return current_aim_context.aim_point if current_aim_context != null else global_position

func _sync_equipped_test_meshes() -> void:
	forge_test_presenter.sync_equipped_test_meshes(
		humanoid_rig,
		held_item_nodes,
		get_equipment_state(),
		get_forge_wip_library_state(),
		weapons_drawn,
		forge_service,
		_get_material_lookup(),
		held_item_mesh_builder,
		DEFAULT_FORGE_RULES_RESOURCE,
		DEFAULT_FORGE_VIEW_TUNING_RESOURCE,
		equipped_item_presenter
	)

func _get_hand_anchor(slot_id: StringName) -> Node3D:
	return forge_test_presenter.get_hand_anchor(humanoid_rig, slot_id, equipped_item_presenter)

func _get_material_lookup() -> Dictionary:
	cached_material_lookup = state_presenter.get_material_lookup(material_pipeline_service, cached_material_lookup)
	return cached_material_lookup

func _ensure_runtime_input_actions() -> void:
	motion_presenter.ensure_runtime_input_actions(user_settings_state)

func _has_runtime_input_actions() -> bool:
	return motion_presenter.has_runtime_input_actions()

func _sync_humanoid_locomotion(target_move_speed: float, sprinting: bool) -> void:
	motion_presenter.sync_humanoid_locomotion(
		humanoid_rig,
		velocity,
		target_move_speed,
		is_on_floor(),
		velocity.y,
		sprinting
	)

func _resolve_target_move_speed(input_vector: Vector2, sprinting: bool) -> float:
	return motion_presenter.resolve_target_move_speed(
		move_speed,
		sprint_speed,
		backpedal_speed_multiplier,
		input_vector,
		sprinting
	)

func _refresh_aim_context() -> void:
	current_aim_context = motion_presenter.refresh_aim_context(
		current_aim_context,
		camera,
		aim_max_range_meters
	)

func _refresh_minimal_aim_context() -> void:
	_refresh_aim_context()

func _sync_crosshair_visibility() -> void:
	ui_surface_presenter.sync_crosshair_visibility(crosshair_overlay, ui_mode_enabled)
