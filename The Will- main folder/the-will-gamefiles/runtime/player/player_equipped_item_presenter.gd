extends RefCounted
class_name PlayerEquippedItemPresenter

const PrimaryGripSliceProfileLibraryScript = preload("res://core/defs/primary_grip_slice_profile_library.gd")
const WeaponGripAnchorProviderScript = preload("res://runtime/player/weapon_grip_anchor_provider.gd")
const BASE_WEAPON_HOLD_ROTATION_DEGREES := Vector3(180.0, 0.0, 0.0)
const LEFT_HAND_WEAPON_HOLD_ROTATION_DEGREES := Vector3(0.0, 180.0, 0.0)
const REVERSE_GRIP_ROTATION_DEGREES := Vector3(0.0, 180.0, 0.0)
const GRIP_CONTACT_COLLISION_LAYER := 1 << 24

var weapon_grip_anchor_provider = WeaponGripAnchorProviderScript.new()

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
	var mesh: ArrayMesh = held_item_mesh_builder.build_mesh_from_test_print(test_print, material_lookup)
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
	mesh_instance.set_meta("visual_mesh_source", test_print.visual_mesh_source)
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
	var dominant_grip_shell_data: Dictionary = _build_grip_contact_shell_data(
		test_print.display_cells,
		dominant_hand_local_position,
		cell_world_size,
		test_print.baked_profile
	)
	var dominant_grip_center_local: Vector3 = dominant_grip_shell_data.get(
		"slice_center_local",
		dominant_hand_local_position
	)
	var support_grip_shell_data: Dictionary = {}
	var support_grip_center_local: Vector3 = support_hand_local_position
	if resolved_grip_style != CraftedItemWIP.GRIP_REVERSE and two_hand_character_eligible:
		support_grip_shell_data = _build_grip_contact_shell_data(
			test_print.display_cells,
			support_hand_local_position,
			cell_world_size,
			test_print.baked_profile
		)
		support_grip_center_local = support_grip_shell_data.get(
			"slice_center_local",
			support_hand_local_position
		)
	var hand_alignment_offset_local: Vector3 = Vector3.ZERO
	if humanoid_rig != null and humanoid_rig.has_method("resolve_hand_grip_alignment_offset_local"):
		var alignment_variant: Variant = humanoid_rig.call("resolve_hand_grip_alignment_offset_local", slot_id)
		if alignment_variant is Vector3:
			hand_alignment_offset_local = alignment_variant
	held_root.position = hand_alignment_offset_local
	mesh_instance.scale = Vector3.ONE * cell_world_size
	mesh_instance.position = -dominant_grip_center_local * cell_world_size
	held_root.add_child(mesh_instance)
	var primary_grip_guide := Node3D.new()
	primary_grip_guide.name = "PrimaryGripGuide"
	held_root.add_child(primary_grip_guide)
	if dominant_grip_shell_data.is_empty():
		_configure_grip_contact_guide(
			primary_grip_guide,
			test_print.display_cells,
			dominant_hand_local_position,
			cell_world_size,
			test_print.baked_profile
		)
	else:
		_configure_grip_contact_guide_from_shell_data(primary_grip_guide, dominant_grip_shell_data, cell_world_size)
	var secondary_grip_guide: Node3D = null
	if resolved_grip_style != CraftedItemWIP.GRIP_REVERSE and two_hand_character_eligible:
		var support_local_offset: Vector3 = (support_grip_center_local - dominant_grip_center_local) * cell_world_size
		if not support_local_offset.is_zero_approx():
			secondary_grip_guide = Node3D.new()
			secondary_grip_guide.name = "SecondaryGripGuide"
			secondary_grip_guide.position = support_local_offset
			held_root.add_child(secondary_grip_guide)
			if support_grip_shell_data.is_empty():
				_configure_grip_contact_guide(
					secondary_grip_guide,
					test_print.display_cells,
					support_hand_local_position,
					cell_world_size,
					test_print.baked_profile
				)
			else:
				_configure_grip_contact_guide_from_shell_data(secondary_grip_guide, support_grip_shell_data, cell_world_size)
	weapon_grip_anchor_provider.ensure_grip_anchor_nodes(held_root, primary_grip_guide, secondary_grip_guide)
	attach_weapon_bounds_area(held_root, canonical_geometry, dominant_grip_center_local, cell_world_size, held_item_mesh_builder)
	_attach_weapon_body_restriction_proxy(held_root, dominant_grip_shell_data, cell_world_size)
	return held_root

func _configure_grip_contact_guide(
	grip_guide: Node3D,
	display_cells: Array[CellAtom],
	contact_position_local: Vector3,
	cell_world_size: float,
	baked_profile: BakedProfile
) -> void:
	if grip_guide == null or display_cells.is_empty() or baked_profile == null:
		return
	var grip_shell_data: Dictionary = _build_grip_contact_shell_data(
		display_cells,
		contact_position_local,
		cell_world_size,
		baked_profile
	)
	if grip_shell_data.is_empty():
		return
	_configure_grip_contact_guide_from_shell_data(grip_guide, grip_shell_data, cell_world_size)

func _configure_grip_contact_guide_from_shell_data(
	grip_guide: Node3D,
	grip_shell_data: Dictionary,
	cell_world_size: float
) -> void:
	if grip_guide == null or grip_shell_data.is_empty():
		return
	var grip_center: Node3D = grip_guide.get_node_or_null("GripShellCenter") as Node3D
	if grip_center == null:
		grip_center = Node3D.new()
		grip_center.name = "GripShellCenter"
		grip_guide.add_child(grip_center)
	grip_center.position = Vector3.ZERO
	grip_center.set_meta("grip_shell_valid", true)
	grip_center.set_meta("grip_shell_cell_world_size", cell_world_size)
	grip_center.set_meta("grip_shell_major_axis_local", grip_shell_data.get("major_axis_local", Vector3.ZERO))
	grip_center.set_meta("grip_shell_minor_axis_a_local", grip_shell_data.get("minor_axis_a_local", Vector3.ZERO))
	grip_center.set_meta("grip_shell_minor_axis_b_local", grip_shell_data.get("minor_axis_b_local", Vector3.ZERO))
	grip_center.set_meta("grip_shell_profile_offsets_minor", grip_shell_data.get("profile_offsets_minor", []))
	grip_center.set_meta("grip_shell_slice_center_local", grip_shell_data.get("slice_center_local", Vector3.ZERO))
	grip_center.set_meta("grip_shell_collision_layer", GRIP_CONTACT_COLLISION_LAYER)
	_attach_grip_contact_area(grip_center, grip_shell_data, cell_world_size)

func _build_grip_contact_shell_data(
	display_cells: Array[CellAtom],
	contact_position_local: Vector3,
	cell_world_size: float,
	baked_profile: BakedProfile
) -> Dictionary:
	var major_axis_local: Vector3 = _resolve_primary_axis_vector(baked_profile.primary_grip_slide_axis)
	if major_axis_local == Vector3.ZERO:
		return {}
	var major_axis_index: int = _resolve_axis_index(major_axis_local)
	if major_axis_index < 0:
		return {}
	var minor_axis_indices: Array[int] = _resolve_minor_axis_indices(major_axis_index)
	var slice_index: int = int(round(_get_vector_component(contact_position_local, major_axis_index)))
	var slice_cells: Array[CellAtom] = []
	for cell: CellAtom in display_cells:
		if cell == null:
			continue
		if _get_vector3i_component(cell.grid_position, major_axis_index) != slice_index:
			continue
		slice_cells.append(cell)
	if slice_cells.is_empty():
		return {}
	var cells_by_coord: Dictionary = {}
	var remaining: Dictionary = {}
	for cell: CellAtom in slice_cells:
		var coord := Vector2i(
			_get_vector3i_component(cell.grid_position, minor_axis_indices[0]),
			_get_vector3i_component(cell.grid_position, minor_axis_indices[1])
		)
		cells_by_coord[coord] = cell
		remaining[coord] = true
	var valid_mask_lookup: Dictionary = PrimaryGripSliceProfileLibraryScript.build_valid_mask_lookup()
	var best_component: Dictionary = {}
	var best_distance_squared: float = INF
	while not remaining.is_empty():
		var stack: Array[Vector2i] = [remaining.keys()[0]]
		var component_coords: Array[Vector2i] = []
		var component_cells: Array[CellAtom] = []
		while not stack.is_empty():
			var current_coord: Vector2i = stack.pop_back()
			if not remaining.has(current_coord):
				continue
			remaining.erase(current_coord)
			component_coords.append(current_coord)
			component_cells.append(cells_by_coord.get(current_coord, null))
			for neighbor_coord: Vector2i in _get_neighbor_coords(current_coord):
				if remaining.has(neighbor_coord):
					stack.append(neighbor_coord)
		var canonical_key: String = PrimaryGripSliceProfileLibraryScript.build_canonical_mask_key_from_positions(component_coords)
		if canonical_key.is_empty() or not valid_mask_lookup.has(canonical_key):
			continue
		var component_center_local: Vector3 = _average_cell_positions(component_cells)
		var distance_squared: float = component_center_local.distance_squared_to(contact_position_local)
		if best_component.is_empty() or distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_component = {
				"positions": component_coords,
				"center_local": component_center_local,
			}
	if best_component.is_empty():
		return {}
	var center_local: Vector3 = best_component.get("center_local", contact_position_local)
	var center_minor_a: float = _get_vector_component(center_local, minor_axis_indices[0])
	var center_minor_b: float = _get_vector_component(center_local, minor_axis_indices[1])
	var profile_offsets_minor: Array = []
	for coord_variant: Variant in best_component.get("positions", []):
		var coord: Vector2i = coord_variant as Vector2i
		profile_offsets_minor.append(Vector2(
			(float(coord.x) - center_minor_a) * cell_world_size,
			(float(coord.y) - center_minor_b) * cell_world_size
		))
	return {
		"guide_center_offset_local": (center_local - contact_position_local) * cell_world_size,
		"slice_center_local": center_local,
		"major_axis_local": major_axis_local,
		"minor_axis_a_local": _axis_index_to_vector3(minor_axis_indices[0]),
		"minor_axis_b_local": _axis_index_to_vector3(minor_axis_indices[1]),
		"profile_offsets_minor": profile_offsets_minor,
	}

func _attach_grip_contact_area(grip_center: Node3D, grip_shell_data: Dictionary, cell_world_size: float) -> void:
	if grip_center == null:
		return
	var grip_area: Area3D = grip_center.get_node_or_null("GripContactArea") as Area3D
	if grip_area == null:
		grip_area = Area3D.new()
		grip_area.name = "GripContactArea"
		grip_center.add_child(grip_area)
	grip_area.collision_layer = GRIP_CONTACT_COLLISION_LAYER
	grip_area.collision_mask = 0
	grip_area.monitoring = false
	grip_area.monitorable = true
	for child_node: Node in grip_area.get_children():
		child_node.queue_free()
	var major_axis_index: int = _resolve_axis_index(grip_shell_data.get("major_axis_local", Vector3.ZERO))
	if major_axis_index < 0:
		return
	var profile_offsets: Array = grip_shell_data.get("profile_offsets_minor", [])
	var minor_axis_a_local: Vector3 = grip_shell_data.get("minor_axis_a_local", Vector3.RIGHT)
	var minor_axis_b_local: Vector3 = grip_shell_data.get("minor_axis_b_local", Vector3.UP)
	var local_shape_size: Vector3 = Vector3.ONE * cell_world_size
	local_shape_size = _set_axis_component(local_shape_size, major_axis_index, cell_world_size)
	for profile_index: int in range(profile_offsets.size()):
		var offset_minor: Vector2 = profile_offsets[profile_index] as Vector2
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "GripCellShape_%d" % profile_index
		var box_shape := BoxShape3D.new()
		box_shape.size = local_shape_size
		collision_shape.shape = box_shape
		collision_shape.position = (
			minor_axis_a_local * offset_minor.x
			+ minor_axis_b_local * offset_minor.y
		)
		grip_area.add_child(collision_shape)

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

func _attach_weapon_body_restriction_proxy(
	held_root: Node3D,
	grip_shell_data: Dictionary,
	cell_world_size: float
) -> void:
	if held_root == null or grip_shell_data.is_empty():
		return
	var proxy_root: Node3D = held_root.get_node_or_null("WeaponBodyRestrictionProxy") as Node3D
	if proxy_root == null:
		proxy_root = Node3D.new()
		proxy_root.name = "WeaponBodyRestrictionProxy"
		held_root.add_child(proxy_root)
	proxy_root.transform = Transform3D.IDENTITY
	var slice_center_local: Vector3 = grip_shell_data.get("slice_center_local", Vector3.ZERO) as Vector3
	var major_axis_local: Vector3 = (grip_shell_data.get("major_axis_local", Vector3.FORWARD) as Vector3).normalized()
	if major_axis_local.length_squared() <= 0.000001:
		major_axis_local = Vector3.FORWARD
	var sample_offsets: Array[Vector3] = [
		Vector3.ZERO,
		major_axis_local * cell_world_size * 2.0,
		-major_axis_local * cell_world_size * 2.0,
	]
	for sample_index: int in range(sample_offsets.size()):
		var sample_name: String = "WeaponBodySample_%d" % sample_index
		var sample_node: Node3D = proxy_root.get_node_or_null(sample_name) as Node3D
		if sample_node == null:
			sample_node = Node3D.new()
			sample_node.name = sample_name
			proxy_root.add_child(sample_node)
		sample_node.position = (slice_center_local + sample_offsets[sample_index]) * cell_world_size

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
	if humanoid_rig.has_method("clear_dominant_grip_slot"):
		humanoid_rig.call("clear_dominant_grip_slot")
	if humanoid_rig.has_method("clear_finger_grip_target"):
		humanoid_rig.call("clear_finger_grip_target", &"hand_right")
		humanoid_rig.call("clear_finger_grip_target", &"hand_left")
	if humanoid_rig.has_method("set_support_hand_active"):
		humanoid_rig.call("set_support_hand_active", &"hand_right", false)
		humanoid_rig.call("set_support_hand_active", &"hand_left", false)
	if not weapons_drawn:
		return

	var right_item: Node3D = held_item_nodes.get(&"hand_right") as Node3D
	var left_item: Node3D = held_item_nodes.get(&"hand_left") as Node3D
	if right_item != null:
		var right_primary_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_anchor(right_item)
		if right_primary_anchor != null and humanoid_rig.has_method("set_arm_guidance_target"):
			humanoid_rig.call("set_arm_guidance_target", &"hand_right", right_primary_anchor)
		if humanoid_rig.has_method("set_support_hand_active"):
			humanoid_rig.call("set_support_hand_active", &"hand_right", false)
		if humanoid_rig.has_method("set_dominant_grip_slot") and left_item == null:
			humanoid_rig.call("set_dominant_grip_slot", &"hand_right")
	if right_item != null and humanoid_rig.has_method("set_finger_grip_target"):
		var right_primary_guide: Node3D = right_item.get_node_or_null("PrimaryGripGuide") as Node3D
		if right_primary_guide != null:
			humanoid_rig.call("set_finger_grip_target", &"hand_right", right_primary_guide)
	if left_item != null:
		var left_primary_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_anchor(left_item)
		if left_primary_anchor != null and humanoid_rig.has_method("set_arm_guidance_target"):
			humanoid_rig.call("set_arm_guidance_target", &"hand_left", left_primary_anchor)
		if humanoid_rig.has_method("set_support_hand_active"):
			humanoid_rig.call("set_support_hand_active", &"hand_left", false)
		if humanoid_rig.has_method("set_dominant_grip_slot") and right_item == null:
			humanoid_rig.call("set_dominant_grip_slot", &"hand_left")
	if left_item != null and humanoid_rig.has_method("set_finger_grip_target"):
		var left_primary_guide: Node3D = left_item.get_node_or_null("PrimaryGripGuide") as Node3D
		if left_primary_guide != null:
			humanoid_rig.call("set_finger_grip_target", &"hand_left", left_primary_guide)
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
		var support_anchor: Node3D = weapon_grip_anchor_provider.get_support_grip_anchor(held_item)
		humanoid_rig.call("set_arm_guidance_target", support_slot_id, support_anchor if support_anchor != null else secondary_guide)
	if humanoid_rig.has_method("set_finger_grip_target"):
		humanoid_rig.call("set_finger_grip_target", support_slot_id, secondary_guide)
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

func _resolve_primary_axis_vector(axis_vector: Vector3) -> Vector3:
	if axis_vector == Vector3.ZERO:
		return Vector3.ZERO
	var normalized_axis: Vector3 = axis_vector.normalized()
	var axis_index: int = _resolve_axis_index(normalized_axis)
	if axis_index < 0:
		return Vector3.ZERO
	var axis_sign: float = -1.0 if _get_vector_component(normalized_axis, axis_index) < 0.0 else 1.0
	return _axis_index_to_vector3(axis_index) * axis_sign

func _resolve_axis_index(axis_vector: Vector3) -> int:
	var abs_vector: Vector3 = Vector3(absf(axis_vector.x), absf(axis_vector.y), absf(axis_vector.z))
	if abs_vector.x >= abs_vector.y and abs_vector.x >= abs_vector.z and abs_vector.x > 0.0:
		return 0
	if abs_vector.y >= abs_vector.x and abs_vector.y >= abs_vector.z and abs_vector.y > 0.0:
		return 1
	if abs_vector.z > 0.0:
		return 2
	return -1

func _resolve_minor_axis_indices(major_axis_index: int) -> Array[int]:
	var indices: Array[int] = []
	for axis_index: int in range(3):
		if axis_index == major_axis_index:
			continue
		indices.append(axis_index)
	return indices

func _axis_index_to_vector3(axis_index: int) -> Vector3:
	match axis_index:
		0:
			return Vector3.RIGHT
		1:
			return Vector3.UP
		2:
			return Vector3.FORWARD
	return Vector3.ZERO

func _get_vector_component(value: Vector3, axis_index: int) -> float:
	match axis_index:
		0:
			return value.x
		1:
			return value.y
		2:
			return value.z
	return 0.0

func _get_vector3i_component(value: Vector3i, axis_index: int) -> int:
	match axis_index:
		0:
			return value.x
		1:
			return value.y
		2:
			return value.z
	return 0

func _set_axis_component(value: Vector3, axis_index: int, component_value: float) -> Vector3:
	match axis_index:
		0:
			value.x = component_value
		1:
			value.y = component_value
		2:
			value.z = component_value
	return value

func _get_neighbor_coords(coord: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for delta_x in range(-1, 2):
		for delta_y in range(-1, 2):
			if delta_x == 0 and delta_y == 0:
				continue
			neighbors.append(coord + Vector2i(delta_x, delta_y))
	return neighbors

func _average_cell_positions(cells: Array[CellAtom]) -> Vector3:
	if cells.is_empty():
		return Vector3.ZERO
	var position_sum: Vector3 = Vector3.ZERO
	var counted_cells: int = 0
	for cell: CellAtom in cells:
		if cell == null:
			continue
		position_sum += cell.get_center_position()
		counted_cells += 1
	if counted_cells <= 0:
		return Vector3.ZERO
	return position_sum / float(counted_cells)

func get_saved_wip_display_name(saved_wip: CraftedItemWIP) -> String:
	if saved_wip == null:
		return "Unnamed WIP"
	var cleaned_name: String = saved_wip.forge_project_name.strip_edges()
	if not cleaned_name.is_empty():
		return cleaned_name
	return String(saved_wip.wip_id)
