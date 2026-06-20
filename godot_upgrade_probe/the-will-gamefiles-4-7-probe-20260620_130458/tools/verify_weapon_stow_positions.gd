extends SceneTree

const PlayerBodyInventoryStateScript = preload("res://core/models/player_body_inventory_state.gd")
const PlayerPersonalStorageStateScript = preload("res://core/models/player_personal_storage_state.gd")
const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_weapon_stow_results.txt"
const TEMP_STATE_DIR := "C:/WORKSPACE/test_artifacts"
const UPPER_BACK_STOW_OFFSET_METERS := 0.18
const HIP_SIDE_STOW_OFFSET_METERS := 0.23
const LOWER_BACK_STOW_OFFSET_METERS := 0.20

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var player_scene: PackedScene = load("res://scenes/player/player_character.tscn") as PackedScene
	var player_root: Node = player_scene.instantiate()
	var player := player_root as PlayerController3D
	var body_state = PlayerBodyInventoryStateScript.new()
	body_state.save_file_path = "%s/verify_stow_body_inventory_state.tres" % TEMP_STATE_DIR
	var personal_state = PlayerPersonalStorageStateScript.new()
	personal_state.save_file_path = "%s/verify_stow_personal_storage_state.tres" % TEMP_STATE_DIR
	var equipment_state = PlayerEquipmentStateScript.new()
	equipment_state.save_file_path = "%s/verify_stow_player_equipment_state.tres" % TEMP_STATE_DIR
	var wip_library = PlayerForgeWipLibraryStateScript.new()
	wip_library.save_file_path = "%s/verify_stow_player_wip_library_state.tres" % TEMP_STATE_DIR
	var skill_slot_state = PlayerSkillSlotStateScript.new()
	skill_slot_state.save_file_path = "%s/verify_stow_player_skill_slot_state.tres" % TEMP_STATE_DIR

	player.body_inventory_state = body_state
	player.personal_storage_state = personal_state
	player.equipment_state = equipment_state
	player.forge_wip_library_state = wip_library
	player.player_skill_slot_state = skill_slot_state
	root.add_child(player_root)
	await process_frame
	await physics_frame
	await process_frame

	player._sync_equipped_test_meshes()
	var rig: PlayerHumanoidRig = player.humanoid_rig as PlayerHumanoidRig if player != null else null

	var shoulder_wip: CraftedItemWIP = wip_library.save_wip(_build_stow_test_wip(&"verify_shoulder_wip", CraftedItemWIP.STOW_SHOULDER_HANGING))
	var side_hip_wip: CraftedItemWIP = wip_library.save_wip(_build_stow_test_wip(&"verify_side_hip_wip", CraftedItemWIP.STOW_SIDE_HIP))
	var lower_back_wip: CraftedItemWIP = wip_library.save_wip(_build_stow_test_wip(&"verify_lower_back_wip", CraftedItemWIP.STOW_LOWER_BACK))

	var shoulder_right_valid: bool = await _equip_and_stow(player, shoulder_wip.wip_id, &"hand_right")
	var shoulder_right_anchor: Node3D = rig.get_weapon_stow_anchor(CraftedItemWIP.STOW_SHOULDER_HANGING, &"hand_right") if rig != null else null
	var shoulder_right_node: Node3D = player.held_item_nodes.get(&"hand_right") as Node3D
	var shoulder_right_parent_matches: bool = shoulder_right_node != null and shoulder_right_node.get_parent() == shoulder_right_anchor
	var shoulder_right_anchor_bone: StringName = _resolve_attachment_bone_name(shoulder_right_anchor)
	var shoulder_right_anchor_error: float = _resolve_anchor_offset_error(
		rig,
		shoulder_right_anchor,
		&"CC_Base_L_Clavicle",
		Vector3(0.0, 0.0, -1.0),
		UPPER_BACK_STOW_OFFSET_METERS
	)

	var side_left_valid: bool = await _equip_and_stow(player, side_hip_wip.wip_id, &"hand_left")
	var side_left_anchor: Node3D = rig.get_weapon_stow_anchor(CraftedItemWIP.STOW_SIDE_HIP, &"hand_left") if rig != null else null
	var side_left_node: Node3D = player.held_item_nodes.get(&"hand_left") as Node3D
	var side_left_parent_matches: bool = side_left_node != null and side_left_node.get_parent() == side_left_anchor
	var side_left_anchor_bone: StringName = _resolve_attachment_bone_name(side_left_anchor)
	var side_left_anchor_side_error: float = _resolve_side_hip_anchor_error(rig, side_left_anchor)

	var lower_right_valid: bool = await _equip_and_stow(player, lower_back_wip.wip_id, &"hand_right")
	var lower_right_anchor: Node3D = rig.get_weapon_stow_anchor(CraftedItemWIP.STOW_LOWER_BACK, &"hand_right") if rig != null else null
	var lower_left_anchor: Node3D = rig.get_weapon_stow_anchor(CraftedItemWIP.STOW_LOWER_BACK, &"hand_left") if rig != null else null
	var lower_right_node: Node3D = player.held_item_nodes.get(&"hand_right") as Node3D
	var lower_right_parent_matches: bool = lower_right_node != null and lower_right_node.get_parent() == lower_right_anchor
	var lower_right_anchor_bone: StringName = _resolve_attachment_bone_name(lower_right_anchor)
	var lower_right_anchor_error: float = _resolve_anchor_offset_error(
		rig,
		lower_right_anchor,
		&"CC_Base_Hip",
		Vector3(0.0, 0.0, -1.0),
		LOWER_BACK_STOW_OFFSET_METERS
	)
	var lower_back_shared_anchor_error: float = (
		lower_right_anchor.global_position.distance_to(lower_left_anchor.global_position)
		if lower_right_anchor != null and lower_left_anchor != null
		else INF
	)
	var bounds_area: Area3D = lower_right_node.get_node_or_null("WeaponBoundsArea") as Area3D if lower_right_node != null else null
	var bounds_shape: CollisionShape3D = bounds_area.get_node_or_null("WeaponBoundsShape") as CollisionShape3D if bounds_area != null else null
	var bounds_size: Vector3 = (bounds_shape.shape as BoxShape3D).size if bounds_shape != null and bounds_shape.shape is BoxShape3D else Vector3.ZERO
	var lower_stow_motion_applied: bool = bool(lower_right_node.get_meta("station_stow_motion_node_applied", false)) if lower_right_node != null else false
	var stow_tip_error: float = _resolve_stow_endpoint_error(lower_right_node, lower_right_anchor, "weapon_tip_local", "station_stow_tip_position_local")
	var stow_pommel_error: float = _resolve_stow_endpoint_error(lower_right_node, lower_right_anchor, "weapon_pommel_local", "station_stow_pommel_position_local")

	var lines: PackedStringArray = []
	lines.append("shoulder_right_preview_valid=%s" % str(shoulder_right_valid))
	lines.append("shoulder_right_parent_matches=%s" % str(shoulder_right_parent_matches))
	lines.append("shoulder_right_anchor_bone=%s" % String(shoulder_right_anchor_bone))
	lines.append("shoulder_right_anchor_error=%s" % str(snapped(shoulder_right_anchor_error, 0.0001)))
	lines.append("side_left_preview_valid=%s" % str(side_left_valid))
	lines.append("side_left_parent_matches=%s" % str(side_left_parent_matches))
	lines.append("side_left_anchor_bone=%s" % String(side_left_anchor_bone))
	lines.append("side_left_anchor_side_error=%s" % str(snapped(side_left_anchor_side_error, 0.0001)))
	lines.append("lower_right_preview_valid=%s" % str(lower_right_valid))
	lines.append("lower_right_parent_matches=%s" % str(lower_right_parent_matches))
	lines.append("lower_right_anchor_bone=%s" % String(lower_right_anchor_bone))
	lines.append("lower_right_anchor_error=%s" % str(snapped(lower_right_anchor_error, 0.0001)))
	lines.append("lower_back_shared_anchor_error=%s" % str(snapped(lower_back_shared_anchor_error, 0.0001)))
	lines.append("runtime_stow_anchor_alignment_ok=%s" % str(
		shoulder_right_anchor_bone == &"CC_Base_L_Clavicle"
		and shoulder_right_anchor_error >= 0.0
		and shoulder_right_anchor_error < 0.002
		and side_left_anchor_bone == &"CC_Base_Hip"
		and side_left_anchor_side_error >= 0.0
		and side_left_anchor_side_error < 0.002
		and lower_right_anchor_bone == &"CC_Base_Hip"
		and lower_right_anchor_error >= 0.0
		and lower_right_anchor_error < 0.002
		and lower_back_shared_anchor_error < 0.002
	))
	lines.append("weapon_bounds_area_exists=%s" % str(bounds_area != null))
	lines.append("weapon_bounds_shape_exists=%s" % str(bounds_shape != null))
	lines.append("weapon_bounds_size=%s" % str(bounds_size))
	lines.append("weapon_bounds_has_padding=%s" % str(bounds_size.x > 0.0 and bounds_size.y > 0.0 and bounds_size.z > 0.0))
	lines.append("lower_stow_motion_applied=%s" % str(lower_stow_motion_applied))
	lines.append("lower_stow_tip_error=%s" % str(snapped(stow_tip_error, 0.0001)))
	lines.append("lower_stow_pommel_error=%s" % str(snapped(stow_pommel_error, 0.0001)))
	lines.append("lower_stow_motion_matches_authored=%s" % str(
		lower_stow_motion_applied
		and stow_tip_error >= 0.0
		and stow_tip_error < 0.002
		and stow_pommel_error >= 0.0
		and stow_pommel_error < 0.002
	))
	lines.append("weapons_drawn_after_stow=%s" % str(player.weapons_drawn))

	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _equip_and_stow(player: PlayerController3D, saved_wip_id: StringName, slot_id: StringName) -> bool:
	player.clear_equipment_slot(&"hand_right")
	player.clear_equipment_slot(&"hand_left")
	player.set_weapons_drawn(true)
	var equip_result: Dictionary = player.equip_saved_wip_to_hand(saved_wip_id, slot_id)
	player.set_weapons_drawn(false)
	for _i in range(6):
		await physics_frame
		await process_frame
	return bool(equip_result.get("success", false))

func _build_stow_test_wip(wip_id: StringName, stow_mode: StringName) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIP.new()
	wip.wip_id = wip_id
	wip.forge_project_name = "%s Test" % String(wip_id)
	wip.creator_id = &"verify"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.stow_position_mode = stow_mode
	var layer_a: LayerAtom = LayerAtom.new()
	layer_a.layer_index = 20
	layer_a.cells = _build_handle_cells(20)
	var layer_b: LayerAtom = LayerAtom.new()
	layer_b.layer_index = 21
	layer_b.cells = _build_handle_cells(21)
	wip.layers = [layer_a, layer_b]
	_seed_station_stow_authoring(wip, stow_mode)
	return wip

func _seed_station_stow_authoring(wip: CraftedItemWIP, stow_mode: StringName) -> void:
	if wip == null:
		return
	var station_state: CombatAnimationStationState = wip.ensure_combat_animation_station_state() as CombatAnimationStationState
	if station_state == null:
		return
	var noncombat_draft: CombatAnimationDraft = station_state.get_or_create_idle_draft(
		CombatAnimationStationState.IDLE_CONTEXT_NONCOMBAT,
		"Noncombat Idle",
		wip.grip_style_mode,
		stow_mode
	) as CombatAnimationDraft
	if noncombat_draft == null:
		return
	noncombat_draft.stow_anchor_mode = CombatAnimationDraft.normalize_stow_anchor_mode(stow_mode)
	noncombat_draft.ensure_minimum_baseline_nodes()
	if noncombat_draft.motion_node_chain.is_empty():
		return
	var motion_node: CombatAnimationMotionNode = noncombat_draft.motion_node_chain[0] as CombatAnimationMotionNode
	if motion_node == null:
		return
	motion_node.tip_position_local = Vector3(0.05, 0.04, -0.18)
	motion_node.pommel_position_local = Vector3(-0.04, -0.03, 0.12)
	motion_node.weapon_orientation_degrees = Vector3(6.0, -164.0, 22.0)
	motion_node.weapon_orientation_authored = true
	motion_node.weapon_roll_degrees = 8.0
	motion_node.normalize()

func _resolve_stow_endpoint_error(
	held_item: Node3D,
	stow_anchor: Node3D,
	weapon_endpoint_meta: String,
	stow_endpoint_meta: String
) -> float:
	if held_item == null or stow_anchor == null:
		return -1.0
	var weapon_endpoint_local: Vector3 = held_item.get_meta(weapon_endpoint_meta, Vector3.ZERO) as Vector3
	var expected_anchor_local: Vector3 = held_item.get_meta(stow_endpoint_meta, Vector3.INF) as Vector3
	if expected_anchor_local == Vector3.INF:
		return -1.0
	var actual_anchor_local: Vector3 = stow_anchor.to_local(held_item.to_global(weapon_endpoint_local))
	return actual_anchor_local.distance_to(expected_anchor_local)

func _resolve_attachment_bone_name(anchor: Node3D) -> StringName:
	var attachment: BoneAttachment3D = _resolve_anchor_attachment(anchor)
	if attachment == null:
		return StringName()
	return StringName(attachment.bone_name)

func _resolve_anchor_attachment(anchor: Node3D) -> BoneAttachment3D:
	var node: Node = anchor
	while node != null:
		if node is BoneAttachment3D:
			return node as BoneAttachment3D
		node = node.get_parent()
	return null

func _resolve_anchor_offset_error(
	rig: PlayerHumanoidRig,
	anchor: Node3D,
	bone_name: StringName,
	local_direction: Vector3,
	offset_meters: float
) -> float:
	if rig == null or rig.skeleton == null or anchor == null or local_direction.length_squared() <= 0.000001:
		return INF
	var bone_index: int = rig.skeleton.find_bone(String(bone_name))
	if bone_index < 0:
		return INF
	var bone_world: Transform3D = rig.skeleton.global_transform * rig.skeleton.get_bone_global_pose(bone_index)
	var direction_world: Vector3 = (bone_world.basis.orthonormalized() * local_direction.normalized()).normalized()
	if direction_world.length_squared() <= 0.000001:
		return INF
	var expected_position: Vector3 = bone_world.origin + direction_world * offset_meters
	return expected_position.distance_to(anchor.global_position)

func _resolve_side_hip_anchor_error(rig: PlayerHumanoidRig, anchor: Node3D) -> float:
	if rig == null or rig.skeleton == null or anchor == null:
		return INF
	var plus_error: float = _resolve_anchor_offset_error(
		rig,
		anchor,
		&"CC_Base_Hip",
		Vector3(1.0, 0.0, 0.0),
		HIP_SIDE_STOW_OFFSET_METERS
	)
	var minus_error: float = _resolve_anchor_offset_error(
		rig,
		anchor,
		&"CC_Base_Hip",
		Vector3(-1.0, 0.0, 0.0),
		HIP_SIDE_STOW_OFFSET_METERS
	)
	return minf(plus_error, minus_error)

func _build_handle_cells(layer_index: int) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	for x in range(20, 48):
		for y in range(10, 13):
			var cell: CellAtom = CellAtom.new()
			cell.grid_position = Vector3i(x, y, layer_index)
			cell.layer_index = layer_index
			cell.material_variant_id = &"mat_wood_gray"
			cells.append(cell)
	return cells
