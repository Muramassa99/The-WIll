extends CharacterBody3D
class_name PlayerController3D

const UserSettingsStateScript = preload("res://core/models/user_settings_state.gd")
const UserSettingsRuntimeScript = preload("res://runtime/system/user_settings_runtime.gd")
const PlayerBodyInventoryStateScript = preload("res://core/models/player_body_inventory_state.gd")
const PlayerPersonalStorageStateScript = preload("res://core/models/player_personal_storage_state.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerAimContextScript = preload("res://core/models/player_aim_context.gd")
const StoredItemInstanceScript = preload("res://core/models/stored_item_instance.gd")
const MaterialPipelineServiceScript = preload("res://services/material_pipeline_service.gd")
const ForgeServiceScript = preload("res://services/forge_service.gd")
const TestPrintMeshBuilderScript = preload("res://runtime/forge/test_print_mesh_builder.gd")
const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const BASE_WEAPON_HOLD_ROTATION_DEGREES := Vector3(180.0, 0.0, 0.0)
const LEFT_HAND_WEAPON_HOLD_ROTATION_DEGREES := Vector3(0.0, 180.0, 0.0)
const REVERSE_GRIP_ROTATION_DEGREES := Vector3(0.0, 180.0, 0.0)

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

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var ui_mode_enabled: bool = false
var user_settings_state: UserSettingsState = UserSettingsStateScript.load_or_create()
var body_inventory_state = PlayerBodyInventoryStateScript.load_or_create()
var personal_storage_state = PlayerPersonalStorageStateScript.load_or_create()
var equipment_state = PlayerEquipmentStateScript.load_or_create()
var forge_inventory_state: PlayerForgeInventoryState = PlayerForgeInventoryState.new()
var forge_wip_library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryState.load_or_create()
var material_pipeline_service = MaterialPipelineServiceScript.new()
var forge_service: ForgeService = ForgeServiceScript.new(DEFAULT_FORGE_RULES_RESOURCE)
var held_item_mesh_builder: TestPrintMeshBuilder = TestPrintMeshBuilderScript.new()
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
	_refresh_minimal_aim_context()
	_sync_crosshair_visibility()
	_sync_equipped_test_meshes()

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
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
		_refresh_minimal_aim_context()
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
	_refresh_minimal_aim_context()
	_update_visual_facing(move_direction, delta)
	_sync_humanoid_locomotion(target_move_speed, sprinting)

func _apply_vertical_motion(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.01

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
	if visual_root == null or move_direction.is_zero_approx():
		return
	var target_yaw: float = atan2(move_direction.x, move_direction.z)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, maxf(turn_speed, 0.01) * delta)

func _try_interact() -> void:
	if interaction_raycast == null:
		return
	interaction_raycast.force_raycast_update()

	var interactable: Object = null
	if interaction_raycast.is_colliding():
		interactable = _resolve_interactable(interaction_raycast.get_collider())
	if interactable == null:
		interactable = _find_nearby_interactable()
	if interactable != null:
		interactable.call("interact", self)

func _resolve_interactable(candidate: Object) -> Object:
	var current: Object = candidate
	while current != null:
		if current.has_method("interact"):
			return current
		if current is Node:
			current = (current as Node).get_parent()
			continue
		break
	return null

func _find_nearby_interactable() -> Object:
	if camera == null:
		return null
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

func _toggle_system_menu() -> void:
	if system_menu_overlay == null:
		return
	system_menu_overlay.toggle_menu()

func _open_system_menu_page(page_id: StringName) -> void:
	if system_menu_overlay == null:
		return
	if system_menu_overlay.has_method("open_page"):
		system_menu_overlay.call("open_page", page_id)
	else:
		system_menu_overlay.call("toggle_menu")

func _toggle_player_inventory_page(page_id: StringName, source_label: String = "Player Inventory") -> void:
	if player_inventory_overlay == null:
		return
	if player_inventory_overlay.has_method("toggle_page_for"):
		player_inventory_overlay.call("toggle_page_for", self, page_id, source_label)
	else:
		player_inventory_overlay.call("open_page_for", self, page_id, source_label)

func open_player_inventory_page(page_id: StringName, source_label: String = "Player Inventory") -> void:
	if player_inventory_overlay != null and player_inventory_overlay.has_method("open_page_for"):
		player_inventory_overlay.call("open_page_for", self, page_id, source_label)

func set_ui_mode_enabled(enabled: bool) -> void:
	ui_mode_enabled = enabled
	if enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_refresh_minimal_aim_context()
	_sync_crosshair_visibility()

func get_humanoid_standing_height_meters() -> float:
	if humanoid_rig != null:
		return humanoid_rig.get_standing_height_meters()
	return 0.0

func get_body_inventory_state():
	if body_inventory_state == null:
		body_inventory_state = PlayerBodyInventoryStateScript.load_or_create()
	return body_inventory_state

func get_personal_storage_state():
	if personal_storage_state == null:
		personal_storage_state = PlayerPersonalStorageStateScript.load_or_create()
	return personal_storage_state

func get_equipment_state():
	if equipment_state == null:
		equipment_state = PlayerEquipmentStateScript.load_or_create()
	return equipment_state

func get_forge_inventory_state() -> PlayerForgeInventoryState:
	if forge_inventory_state == null:
		forge_inventory_state = PlayerForgeInventoryState.new()
	return forge_inventory_state

func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
	if forge_wip_library_state == null:
		forge_wip_library_state = PlayerForgeWipLibraryState.load_or_create()
	return forge_wip_library_state

func ensure_body_inventory_seeded(seed_def: Resource = null) -> void:
	var body_state = get_body_inventory_state()
	if body_state == null or seed_def == null or seed_def.is_empty():
		return
	if not body_state.get_owned_items().is_empty():
		return
	for seed_entry in seed_def.entries:
		if seed_entry == null or seed_entry.stack_count <= 0:
			continue
		if seed_entry.item_kind == &"raw_drop" and seed_entry.raw_drop_id == StringName():
			continue
		var stored_item = StoredItemInstanceScript.new()
		stored_item.item_kind = seed_entry.item_kind
		stored_item.display_name = seed_entry.display_name.strip_edges()
		stored_item.stack_count = seed_entry.stack_count
		stored_item.raw_drop_id = seed_entry.raw_drop_id
		stored_item.is_disassemblable = seed_entry.is_disassemblable
		body_state.add_item(stored_item)

func ensure_forge_inventory_seeded(
		material_lookup: Dictionary,
		inventory_seed_def: Resource = null,
		fallback_quantity: int = 0,
		debug_bonus_quantity: int = 0
	) -> void:
	if material_lookup.is_empty():
		return
	var inventory_state: PlayerForgeInventoryState = get_forge_inventory_state()
	if inventory_seed_def != null and not inventory_seed_def.is_empty():
		var applied_seed_floor: bool = false
		for seed_entry in inventory_seed_def.entries:
			if seed_entry == null or seed_entry.material_id == StringName() or seed_entry.quantity <= 0:
				continue
			if not material_lookup.has(seed_entry.material_id):
				continue
			var target_quantity: int = seed_entry.quantity + maxi(debug_bonus_quantity, 0)
			if inventory_state.get_quantity(seed_entry.material_id) < target_quantity:
				inventory_state.set_quantity(seed_entry.material_id, target_quantity)
			applied_seed_floor = true
		if applied_seed_floor:
			return
	if fallback_quantity <= 0:
		return
	var resolved_fallback_quantity: int = fallback_quantity + maxi(debug_bonus_quantity, 0)
	for material_id_value in material_lookup.keys():
		var material_id: StringName = material_id_value
		if inventory_state.get_quantity(material_id) < resolved_fallback_quantity:
			inventory_state.set_quantity(material_id, resolved_fallback_quantity)

func set_selected_forge_wip_id(saved_wip_id: StringName) -> void:
	var wip_library = get_forge_wip_library_state()
	if wip_library != null:
		wip_library.set_selected_wip_id(saved_wip_id)

func preview_saved_wip_test_status(saved_wip_id: StringName) -> Dictionary:
	var wip_library = get_forge_wip_library_state()
	if wip_library == null or saved_wip_id == StringName():
		return {"valid": false, "message": "No saved WIP selected."}
	var saved_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(saved_wip_id)
	if saved_wip == null:
		return {"valid": false, "message": "Saved WIP could not be found."}
	var baked_profile: BakedProfile = forge_service.bake_wip(saved_wip, _get_material_lookup())
	if baked_profile == null:
		return {"valid": false, "message": "Bake did not return a profile."}
	if not baked_profile.primary_grip_valid:
		var failure_text: String = baked_profile.validation_error if not baked_profile.validation_error.is_empty() else "No valid primary grip area yet."
		return {"valid": false, "message": failure_text, "baked_profile": baked_profile}
	return {"valid": true, "message": "Valid primary grip area detected.", "baked_profile": baked_profile}

func equip_saved_wip_to_hand(saved_wip_id: StringName, slot_id: StringName) -> Dictionary:
	if slot_id != &"hand_right" and slot_id != &"hand_left":
		return {"success": false, "message": "Only hand slots support forge test equips."}
	var wip_library = get_forge_wip_library_state()
	if wip_library == null:
		return {"success": false, "message": "No WIP library is available for this character."}
	var saved_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(saved_wip_id)
	if saved_wip == null:
		return {"success": false, "message": "The selected saved WIP could not be found."}
	var status_preview: Dictionary = preview_saved_wip_test_status(saved_wip_id)
	if not bool(status_preview.get("valid", false)):
		return {"success": false, "message": String(status_preview.get("message", "The selected WIP is not valid for forge hand testing yet."))}
	var resolved_equipment_state = get_equipment_state()
	if resolved_equipment_state == null:
		return {"success": false, "message": "No equipment state is available for this character."}
	resolved_equipment_state.equip_forge_test_wip(slot_id, saved_wip)
	_sync_equipped_test_meshes()
	return {"success": true, "message": "Equipped %s into %s." % [_get_saved_wip_display_name(saved_wip), String(slot_id).replace("_", " ")]}

func clear_equipment_slot(slot_id: StringName) -> void:
	var resolved_equipment_state = get_equipment_state()
	if resolved_equipment_state == null:
		return
	resolved_equipment_state.clear_slot(slot_id)
	_sync_equipped_test_meshes()

func set_weapons_drawn(draw_weapons: bool) -> void:
	if weapons_drawn == draw_weapons:
		return
	weapons_drawn = draw_weapons
	_sync_equipped_test_meshes()

func get_current_aim_context():
	return current_aim_context

func get_current_aim_point() -> Vector3:
	return current_aim_context.aim_point if current_aim_context != null else global_position

func request_skill_face_crosshair(_duration_seconds: float = -1.0) -> void:
	pass

func _sync_equipped_test_meshes() -> void:
	_sync_equipped_slot_visual(&"hand_right")
	_sync_equipped_slot_visual(&"hand_left")

func _sync_equipped_slot_visual(slot_id: StringName) -> void:
	_clear_hand_slot_visual(slot_id)
	var resolved_equipment_state = get_equipment_state()
	if resolved_equipment_state == null:
		return
	var equipped_entry = resolved_equipment_state.get_equipped_slot(slot_id)
	if equipped_entry == null or not equipped_entry.is_forge_test_wip():
		return
	var wip_library = get_forge_wip_library_state()
	if wip_library == null:
		return
	var saved_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(equipped_entry.source_wip_id)
	if saved_wip == null:
		resolved_equipment_state.clear_slot(slot_id)
		return
	var visual_anchor: Node3D = _get_equipped_visual_anchor(slot_id, saved_wip)
	if visual_anchor == null:
		return
	var equipped_item_node: Node3D = _build_equipped_item_node(saved_wip, slot_id)
	if equipped_item_node == null:
		return
	visual_anchor.add_child(equipped_item_node)
	held_item_nodes[slot_id] = equipped_item_node

func _clear_hand_slot_visual(slot_id: StringName) -> void:
	var existing_node: Node3D = held_item_nodes.get(slot_id) as Node3D
	if existing_node != null and is_instance_valid(existing_node):
		existing_node.queue_free()
	held_item_nodes.erase(slot_id)

func _get_hand_anchor(slot_id: StringName) -> Node3D:
	if humanoid_rig == null:
		return null
	if slot_id == &"hand_right":
		return humanoid_rig.get_right_hand_item_anchor()
	if slot_id == &"hand_left":
		return humanoid_rig.get_left_hand_item_anchor()
	return null

func _get_equipped_visual_anchor(slot_id: StringName, saved_wip: CraftedItemWIP) -> Node3D:
	if weapons_drawn:
		return _get_hand_anchor(slot_id)
	return _get_stow_anchor(slot_id, saved_wip)

func _get_stow_anchor(slot_id: StringName, saved_wip: CraftedItemWIP) -> Node3D:
	if humanoid_rig == null or saved_wip == null:
		return null
	return humanoid_rig.get_weapon_stow_anchor(saved_wip.stow_position_mode, slot_id)

func _build_equipped_item_node(saved_wip: CraftedItemWIP, slot_id: StringName) -> Node3D:
	if saved_wip == null:
		return null
	var material_lookup: Dictionary = _get_material_lookup()
	var test_print: TestPrintInstance = forge_service.build_test_print_from_wip(saved_wip, material_lookup)
	if test_print == null or test_print.baked_profile == null or not test_print.baked_profile.primary_grip_valid:
		return null
	var mesh: ArrayMesh = held_item_mesh_builder.build_mesh(test_print.display_cells, material_lookup)
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	var held_root := Node3D.new()
	held_root.name = StringName("%sHeldItem" % ("Right" if slot_id == &"hand_right" else "Left"))
	var resolved_grip_style: StringName = CraftedItemWIP.resolve_supported_grip_style(saved_wip.grip_style_mode, saved_wip.forge_intent, saved_wip.equipment_context)
	held_root.transform.basis = _build_weapon_hold_basis(resolved_grip_style, slot_id)
	held_root.set_meta("grip_style_mode", resolved_grip_style)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	var cell_world_size: float = DEFAULT_FORGE_RULES_RESOURCE.cell_world_size_meters
	mesh_instance.scale = Vector3.ONE * cell_world_size
	mesh_instance.position = -test_print.baked_profile.primary_grip_contact_position * cell_world_size
	held_root.add_child(mesh_instance)
	_attach_weapon_bounds_area(held_root, test_print, cell_world_size)
	return held_root

func _build_weapon_hold_basis(grip_style_mode: StringName, slot_id: StringName) -> Basis:
	var final_basis := _basis_from_rotation_degrees(BASE_WEAPON_HOLD_ROTATION_DEGREES)
	final_basis *= _resolve_hand_hold_basis(slot_id)
	final_basis *= _resolve_grip_mode_hold_basis(grip_style_mode)
	return final_basis.orthonormalized()

func _resolve_hand_hold_basis(slot_id: StringName) -> Basis:
	if slot_id == &"hand_left":
		return _basis_from_rotation_degrees(LEFT_HAND_WEAPON_HOLD_ROTATION_DEGREES)
	return Basis.IDENTITY

func _resolve_grip_mode_hold_basis(grip_style_mode: StringName) -> Basis:
	if grip_style_mode == CraftedItemWIP.GRIP_REVERSE:
		return _basis_from_rotation_degrees(REVERSE_GRIP_ROTATION_DEGREES)
	return Basis.IDENTITY

func _basis_from_rotation_degrees(rotation_degrees: Vector3) -> Basis:
	return Basis.from_euler(Vector3(
		deg_to_rad(rotation_degrees.x),
		deg_to_rad(rotation_degrees.y),
		deg_to_rad(rotation_degrees.z)
	))

func _attach_weapon_bounds_area(held_root: Node3D, test_print: TestPrintInstance, cell_world_size: float) -> void:
	if held_root == null or test_print == null or test_print.baked_profile == null:
		return
	var bounds_area := Area3D.new()
	bounds_area.name = "WeaponBoundsArea"
	bounds_area.collision_layer = 0
	bounds_area.collision_mask = 0
	bounds_area.monitoring = false
	bounds_area.monitorable = false
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "WeaponBoundsShape"
	var box_shape := BoxShape3D.new()
	var bounds_data: Dictionary = _build_weapon_bounds_data(test_print, cell_world_size)
	box_shape.size = bounds_data.get("size_meters", Vector3.ONE)
	collision_shape.shape = box_shape
	collision_shape.position = bounds_data.get("center_local", Vector3.ZERO)
	bounds_area.add_child(collision_shape)
	held_root.add_child(bounds_area)
	held_root.set_meta("weapon_bounds_center_local", collision_shape.position)
	held_root.set_meta("weapon_bounds_size_meters", box_shape.size)
	held_root.set_meta("weapon_bounds_padding_cells", 1)

func _build_weapon_bounds_data(test_print: TestPrintInstance, cell_world_size: float) -> Dictionary:
	if test_print == null or test_print.baked_profile == null or test_print.display_cells.is_empty():
		return {"center_local": Vector3.ZERO, "size_meters": Vector3.ONE * cell_world_size}
	var min_position: Vector3 = Vector3(test_print.display_cells[0].grid_position)
	var max_position: Vector3 = min_position
	for cell: CellAtom in test_print.display_cells:
		var cell_position: Vector3 = Vector3(cell.grid_position)
		min_position.x = minf(min_position.x, cell_position.x)
		min_position.y = minf(min_position.y, cell_position.y)
		min_position.z = minf(min_position.z, cell_position.z)
		max_position.x = maxf(max_position.x, cell_position.x)
		max_position.y = maxf(max_position.y, cell_position.y)
		max_position.z = maxf(max_position.z, cell_position.z)
	var padded_min: Vector3 = min_position - Vector3.ONE
	var padded_max: Vector3 = max_position + Vector3.ONE
	var local_center_cells: Vector3 = (padded_min + padded_max) * 0.5 - test_print.baked_profile.primary_grip_contact_position
	var size_cells: Vector3 = (padded_max - padded_min) + Vector3.ONE
	return {"center_local": local_center_cells * cell_world_size, "size_meters": size_cells * cell_world_size}

func _get_material_lookup() -> Dictionary:
	if cached_material_lookup.is_empty():
		cached_material_lookup = material_pipeline_service.build_base_material_lookup()
	return cached_material_lookup

func _get_saved_wip_display_name(saved_wip: CraftedItemWIP) -> String:
	if saved_wip == null:
		return "Unnamed WIP"
	var cleaned_name: String = saved_wip.forge_project_name.strip_edges()
	if not cleaned_name.is_empty():
		return cleaned_name
	return String(saved_wip.wip_id)

func _ensure_runtime_input_actions() -> void:
	UserSettingsRuntimeScript.ensure_input_actions(user_settings_state)

func _has_runtime_input_actions() -> bool:
	return InputMap.has_action(&"move_left") \
		and InputMap.has_action(&"move_right") \
		and InputMap.has_action(&"move_forward") \
		and InputMap.has_action(&"move_back") \
		and InputMap.has_action(&"jump") \
		and InputMap.has_action(&"sprint") \
		and InputMap.has_action(&"menu_toggle") \
		and InputMap.has_action(&"interact")

func _sync_humanoid_locomotion(target_move_speed: float, sprinting: bool) -> void:
	if humanoid_rig == null:
		return
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	humanoid_rig.update_locomotion_state(
		horizontal_speed,
		maxf(target_move_speed, 0.001),
		is_on_floor(),
		velocity.y,
		sprinting
	)

func _resolve_target_move_speed(input_vector: Vector2, sprinting: bool) -> float:
	var target_speed: float = sprint_speed if sprinting else move_speed
	if input_vector.y > 0.01:
		target_speed *= backpedal_speed_multiplier
	return target_speed

func _refresh_minimal_aim_context() -> void:
	if current_aim_context == null:
		current_aim_context = PlayerAimContextScript.new()
	if camera == null:
		return
	var forward: Vector3 = -camera.global_basis.z
	current_aim_context.camera_origin = camera.global_position
	current_aim_context.camera_direction = forward.normalized()
	current_aim_context.aim_point = camera.global_position + forward.normalized() * 60.0
	current_aim_context.aim_distance = 60.0
	var flat_direction := Vector3(forward.x, 0.0, forward.z)
	current_aim_context.flat_direction = flat_direction.normalized() if flat_direction.length_squared() > 0.0 else Vector3.ZERO

func _sync_crosshair_visibility() -> void:
	if crosshair_overlay == null:
		return
	crosshair_overlay.set_crosshair_visible_state(not ui_mode_enabled and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED)
