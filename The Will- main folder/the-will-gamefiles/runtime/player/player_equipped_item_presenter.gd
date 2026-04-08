extends RefCounted
class_name PlayerEquippedItemPresenter

const BASE_WEAPON_HOLD_ROTATION_DEGREES := Vector3(180.0, 0.0, 0.0)
const LEFT_HAND_WEAPON_HOLD_ROTATION_DEGREES := Vector3(0.0, 180.0, 0.0)
const REVERSE_GRIP_ROTATION_DEGREES := Vector3(0.0, 180.0, 0.0)

func get_hand_anchor(humanoid_rig: Node3D, slot_id: StringName) -> Node3D:
	if humanoid_rig == null:
		return null
	if slot_id == &"hand_right":
		return humanoid_rig.get_right_hand_item_anchor()
	if slot_id == &"hand_left":
		return humanoid_rig.get_left_hand_item_anchor()
	return null

func get_stow_anchor(humanoid_rig: Node3D, slot_id: StringName, saved_wip: CraftedItemWIP) -> Node3D:
	if humanoid_rig == null or saved_wip == null:
		return null
	return humanoid_rig.get_weapon_stow_anchor(saved_wip.stow_position_mode, slot_id)

func get_equipped_visual_anchor(humanoid_rig: Node3D, weapons_drawn: bool, slot_id: StringName, saved_wip: CraftedItemWIP) -> Node3D:
	if weapons_drawn:
		return get_hand_anchor(humanoid_rig, slot_id)
	return get_stow_anchor(humanoid_rig, slot_id, saved_wip)

func build_equipped_item_node(
	saved_wip: CraftedItemWIP,
	slot_id: StringName,
	forge_service: ForgeService,
	material_lookup: Dictionary,
	held_item_mesh_builder: TestPrintMeshBuilder,
	humanoid_rig: Node3D,
	forge_rules: ForgeRulesDef,
	forge_view_tuning: ForgeViewTuningDef
) -> Node3D:
	if saved_wip == null:
		return null
	var test_print: TestPrintInstance = forge_service.build_test_print_from_wip(saved_wip, material_lookup)
	if test_print == null or test_print.baked_profile == null or not test_print.baked_profile.primary_grip_valid:
		return null
	var canonical_solid = test_print.canonical_solid if test_print.canonical_solid != null else held_item_mesh_builder.build_canonical_solid(test_print.display_cells)
	var canonical_geometry = test_print.canonical_geometry if test_print.canonical_geometry != null else held_item_mesh_builder.build_canonical_geometry(canonical_solid)
	var mesh: ArrayMesh = held_item_mesh_builder.build_mesh_from_canonical_geometry(canonical_geometry, material_lookup)
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	var held_root := Node3D.new()
	held_root.name = StringName("%sHeldItem" % ("Right" if slot_id == &"hand_right" else "Left"))
	var resolved_grip_style: StringName = CraftedItemWIP.resolve_supported_grip_style(saved_wip.grip_style_mode, saved_wip.forge_intent, saved_wip.equipment_context)
	held_root.transform.basis = build_weapon_hold_basis(resolved_grip_style, slot_id)
	held_root.set_meta("grip_style_mode", resolved_grip_style)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = build_held_item_material(forge_view_tuning)
	var cell_world_size: float = forge_rules.cell_world_size_meters
	var grip_hold_layout: Dictionary = {}
	if humanoid_rig != null and humanoid_rig.has_method("resolve_grip_hold_layout"):
		grip_hold_layout = humanoid_rig.resolve_grip_hold_layout(test_print.baked_profile, slot_id, cell_world_size)
	held_root.set_meta("grip_hold_layout", grip_hold_layout)
	var dominant_hand_local_position: Vector3 = test_print.baked_profile.primary_grip_contact_position
	var support_hand_local_position: Vector3 = Vector3.ZERO
	var two_hand_character_eligible: bool = false
	if bool(grip_hold_layout.get("valid", false)):
		var dominant_variant: Variant = grip_hold_layout.get("dominant_hand_local_position", dominant_hand_local_position)
		if dominant_variant is Vector3:
			dominant_hand_local_position = dominant_variant
		var support_variant: Variant = grip_hold_layout.get("support_hand_local_position", Vector3.ZERO)
		if support_variant is Vector3:
			support_hand_local_position = support_variant
		two_hand_character_eligible = bool(grip_hold_layout.get("two_hand_character_eligible", false))
	held_root.set_meta("two_hand_character_eligible", two_hand_character_eligible)
	mesh_instance.scale = Vector3.ONE * cell_world_size
	mesh_instance.position = -dominant_hand_local_position * cell_world_size
	held_root.add_child(mesh_instance)
	var primary_grip_guide := Node3D.new()
	primary_grip_guide.name = "PrimaryGripGuide"
	held_root.add_child(primary_grip_guide)
	if resolved_grip_style != CraftedItemWIP.GRIP_REVERSE and two_hand_character_eligible:
		var support_local_offset: Vector3 = (support_hand_local_position - dominant_hand_local_position) * cell_world_size
		if not support_local_offset.is_zero_approx():
			var secondary_grip_guide := Node3D.new()
			secondary_grip_guide.name = "SecondaryGripGuide"
			secondary_grip_guide.position = support_local_offset
			held_root.add_child(secondary_grip_guide)
	attach_weapon_bounds_area(held_root, canonical_geometry, test_print.baked_profile.primary_grip_contact_position, cell_world_size, held_item_mesh_builder)
	return held_root

func build_weapon_hold_basis(grip_style_mode: StringName, slot_id: StringName) -> Basis:
	var final_basis := basis_from_rotation_degrees(BASE_WEAPON_HOLD_ROTATION_DEGREES)
	final_basis *= resolve_hand_hold_basis(slot_id)
	final_basis *= resolve_grip_mode_hold_basis(grip_style_mode)
	return final_basis.orthonormalized()

func resolve_hand_hold_basis(slot_id: StringName) -> Basis:
	if slot_id == &"hand_left":
		return basis_from_rotation_degrees(LEFT_HAND_WEAPON_HOLD_ROTATION_DEGREES)
	return Basis.IDENTITY

func resolve_grip_mode_hold_basis(grip_style_mode: StringName) -> Basis:
	if grip_style_mode == CraftedItemWIP.GRIP_REVERSE:
		return basis_from_rotation_degrees(REVERSE_GRIP_ROTATION_DEGREES)
	return Basis.IDENTITY

func basis_from_rotation_degrees(rotation_vector_degrees: Vector3) -> Basis:
	return Basis.from_euler(Vector3(
		deg_to_rad(rotation_vector_degrees.x),
		deg_to_rad(rotation_vector_degrees.y),
		deg_to_rad(rotation_vector_degrees.z)
	))

func attach_weapon_bounds_area(
		held_root: Node3D,
		canonical_geometry,
		grip_contact_position: Vector3,
		cell_world_size: float,
		held_item_mesh_builder: TestPrintMeshBuilder
	) -> void:
	if held_root == null or canonical_geometry == null or held_item_mesh_builder == null:
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
	var bounds_data: Dictionary = held_item_mesh_builder.build_bounds_data_from_canonical_geometry(
		canonical_geometry,
		grip_contact_position,
		cell_world_size,
		1
	)
	box_shape.size = bounds_data.get("size_meters", Vector3.ONE)
	collision_shape.shape = box_shape
	collision_shape.position = bounds_data.get("center_local", Vector3.ZERO)
	bounds_area.add_child(collision_shape)
	held_root.add_child(bounds_area)
	held_root.set_meta("weapon_bounds_center_local", collision_shape.position)
	held_root.set_meta("weapon_bounds_size_meters", box_shape.size)
	held_root.set_meta("weapon_bounds_padding_cells", 1)

func build_held_item_material(forge_view_tuning: ForgeViewTuningDef) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = forge_view_tuning.test_print_material_roughness
	material.metallic = forge_view_tuning.test_print_material_metallic
	return material

func sync_rig_weapon_guidance(
	humanoid_rig: Node3D,
	held_item_nodes: Dictionary,
	weapons_drawn: bool,
	resolved_equipment_state
) -> void:
	if humanoid_rig == null:
		return
	if humanoid_rig.has_method("clear_arm_guidance_target"):
		humanoid_rig.call("clear_arm_guidance_target", &"hand_right")
		humanoid_rig.call("clear_arm_guidance_target", &"hand_left")
	if humanoid_rig.has_method("set_support_hand_active"):
		humanoid_rig.call("set_support_hand_active", &"hand_right", false)
		humanoid_rig.call("set_support_hand_active", &"hand_left", false)
	if not weapons_drawn:
		return

	var right_item: Node3D = held_item_nodes.get(&"hand_right") as Node3D
	var left_item: Node3D = held_item_nodes.get(&"hand_left") as Node3D
	if right_item != null and left_item == null:
		assign_support_weapon_guidance(humanoid_rig, right_item, &"hand_left", resolved_equipment_state)
	elif left_item != null and right_item == null:
		assign_support_weapon_guidance(humanoid_rig, left_item, &"hand_right", resolved_equipment_state)

func assign_support_weapon_guidance(
	humanoid_rig: Node3D,
	held_item: Node3D,
	support_slot_id: StringName,
	resolved_equipment_state
) -> void:
	if humanoid_rig == null or held_item == null:
		return
	if not bool(held_item.get_meta("two_hand_character_eligible", false)):
		return
	var secondary_guide: Node3D = held_item.get_node_or_null("SecondaryGripGuide") as Node3D
	if secondary_guide == null:
		return
	if resolved_equipment_state != null and resolved_equipment_state.get_equipped_slot(support_slot_id) != null:
		return
	if humanoid_rig.has_method("set_arm_guidance_target"):
		humanoid_rig.call("set_arm_guidance_target", support_slot_id, secondary_guide)
	if humanoid_rig.has_method("set_support_hand_active"):
		humanoid_rig.call("set_support_hand_active", support_slot_id, true)

func sync_equipped_test_meshes(
	humanoid_rig: Node3D,
	held_item_nodes: Dictionary,
	resolved_equipment_state,
	wip_library: PlayerForgeWipLibraryState,
	weapons_drawn: bool,
	forge_service: ForgeService,
	material_lookup: Dictionary,
	held_item_mesh_builder: TestPrintMeshBuilder,
	forge_rules: ForgeRulesDef,
	forge_view_tuning: ForgeViewTuningDef
) -> void:
	sync_equipped_slot_visual(
		&"hand_right",
		humanoid_rig,
		held_item_nodes,
		resolved_equipment_state,
		wip_library,
		weapons_drawn,
		forge_service,
		material_lookup,
		held_item_mesh_builder,
		forge_rules,
		forge_view_tuning
	)
	sync_equipped_slot_visual(
		&"hand_left",
		humanoid_rig,
		held_item_nodes,
		resolved_equipment_state,
		wip_library,
		weapons_drawn,
		forge_service,
		material_lookup,
		held_item_mesh_builder,
		forge_rules,
		forge_view_tuning
	)
	sync_rig_weapon_guidance(humanoid_rig, held_item_nodes, weapons_drawn, resolved_equipment_state)

func sync_equipped_slot_visual(
	slot_id: StringName,
	humanoid_rig: Node3D,
	held_item_nodes: Dictionary,
	resolved_equipment_state,
	wip_library: PlayerForgeWipLibraryState,
	weapons_drawn: bool,
	forge_service: ForgeService,
	material_lookup: Dictionary,
	held_item_mesh_builder: TestPrintMeshBuilder,
	forge_rules: ForgeRulesDef,
	forge_view_tuning: ForgeViewTuningDef
) -> void:
	clear_hand_slot_visual(slot_id, held_item_nodes)
	if resolved_equipment_state == null:
		return
	var equipped_entry = resolved_equipment_state.get_equipped_slot(slot_id)
	if equipped_entry == null or not equipped_entry.is_forge_test_wip():
		return
	if wip_library == null:
		return
	var saved_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(equipped_entry.source_wip_id)
	if saved_wip == null:
		resolved_equipment_state.clear_slot(slot_id)
		return
	var visual_anchor: Node3D = get_equipped_visual_anchor(humanoid_rig, weapons_drawn, slot_id, saved_wip)
	if visual_anchor == null:
		return
	var equipped_item_node: Node3D = build_equipped_item_node(
		saved_wip,
		slot_id,
		forge_service,
		material_lookup,
		held_item_mesh_builder,
		humanoid_rig,
		forge_rules,
		forge_view_tuning
	)
	if equipped_item_node == null:
		return
	visual_anchor.add_child(equipped_item_node)
	held_item_nodes[slot_id] = equipped_item_node

func clear_hand_slot_visual(slot_id: StringName, held_item_nodes: Dictionary) -> void:
	var existing_node: Node3D = held_item_nodes.get(slot_id) as Node3D
	if existing_node != null and is_instance_valid(existing_node):
		existing_node.queue_free()
	held_item_nodes.erase(slot_id)

func get_saved_wip_display_name(saved_wip: CraftedItemWIP) -> String:
	if saved_wip == null:
		return "Unnamed WIP"
	var cleaned_name: String = saved_wip.forge_project_name.strip_edges()
	if not cleaned_name.is_empty():
		return cleaned_name
	return String(saved_wip.wip_id)
