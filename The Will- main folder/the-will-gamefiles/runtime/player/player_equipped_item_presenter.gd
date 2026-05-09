extends RefCounted
class_name PlayerEquippedItemPresenter

const PrimaryGripSliceProfileLibraryScript = preload("res://core/defs/primary_grip_slice_profile_library.gd")
const WeaponGripAnchorProviderScript = preload("res://runtime/player/weapon_grip_anchor_provider.gd")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")
const CombatAnimationWeaponFrameSolverScript = preload("res://runtime/combat/combat_animation_weapon_frame_solver.gd")
const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")
const BASE_WEAPON_HOLD_ROTATION_DEGREES := Vector3(180.0, 0.0, 0.0)
const LEFT_HAND_WEAPON_HOLD_ROTATION_DEGREES := Vector3(0.0, 180.0, 0.0)
const REVERSE_GRIP_ROTATION_DEGREES := Vector3(0.0, 180.0, 0.0)
const GRIP_CONTACT_COLLISION_LAYER := 1 << 24
const HAND_MOUNT_LOCAL_TRANSFORM_META := "hand_mount_local_transform"
const HAND_MOUNT_LOCAL_TRANSFORM_ORIGIN_META := "hand_mount_local_transform_origin_id"
const EQUIPPED_VISUAL_ANCHOR_ORIGIN_META := "equipped_visual_anchor_origin_id"
const EQUIPPED_REANCHOR_SOURCE_ORIGIN_META := "equipped_reanchor_source_origin_id"
const EQUIPPED_REANCHOR_TARGET_ORIGIN_META := "equipped_reanchor_target_origin_id"
const WEAPON_CLEARANCE_PROXY_OFFSET_METERS := 0.005
const MAX_WEAPON_BODY_PROXY_SURFACE_SAMPLES := 128
const MAX_WEAPON_BODY_PROXY_CELL_SAMPLES := 96
const STOW_AUTHORING_ROOT_BONE := &"RL_BoneRoot"

var weapon_grip_anchor_provider = WeaponGripAnchorProviderScript.new()
var weapon_frame_solver = CombatAnimationWeaponFrameSolverScript.new()

func _ensure_origin_meta(target: Object, meta_name: String, fallback_origin_id: StringName) -> void:
	if target == null:
		return
	var origin_id: StringName = StringName(target.get_meta(meta_name, StringName()))
	if origin_id == StringName():
		target.set_meta(meta_name, fallback_origin_id)

func _resolve_origin_meta_value(target: Object, meta_name: String, fallback_origin_id: StringName) -> StringName:
	var resolved_origin_id: StringName = fallback_origin_id
	if resolved_origin_id == StringName():
		resolved_origin_id = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
	if target == null:
		return resolved_origin_id
	var origin_id: StringName = StringName(target.get_meta(meta_name, StringName()))
	if origin_id != StringName():
		return origin_id
	target.set_meta(meta_name, resolved_origin_id)
	return resolved_origin_id

func _get_origin_tracked_vector3_meta(
	target: Object,
	value_meta_name: String,
	origin_meta_name: String,
	fallback_value: Vector3,
	fallback_origin_id: StringName
) -> Vector3:
	_resolve_origin_meta_value(target, origin_meta_name, fallback_origin_id)
	if target == null or not target.has_meta(value_meta_name):
		return fallback_value
	var value: Variant = target.get_meta(value_meta_name)
	if value is Vector3:
		return value as Vector3
	return fallback_value

func _resolve_origin_tracked_state_origin_id(
	source_state: Dictionary,
	origin_key: String,
	fallback_origin_id: StringName
) -> StringName:
	var resolved_origin_id: StringName = fallback_origin_id
	if resolved_origin_id == StringName():
		resolved_origin_id = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
	if not source_state.has(origin_key):
		source_state[origin_key] = resolved_origin_id
		return resolved_origin_id
	var origin_id: StringName = StringName(source_state.get(origin_key, StringName()))
	if origin_id == StringName():
		source_state[origin_key] = resolved_origin_id
		return resolved_origin_id
	return origin_id

func _get_origin_tracked_vector3_state(
	source_state: Dictionary,
	value_key: String,
	origin_key: String,
	fallback_value: Vector3,
	fallback_origin_id: StringName
) -> Vector3:
	_resolve_origin_tracked_state_origin_id(source_state, origin_key, fallback_origin_id)
	if not source_state.has(value_key):
		return fallback_value
	var value: Variant = source_state.get(value_key, fallback_value)
	if value is Vector3:
		return value as Vector3
	return fallback_value

func _resolve_hand_alignment_offset_state(humanoid_rig: Node3D, slot_id: StringName) -> Dictionary:
	var result := {
		"hand_alignment_offset_local": Vector3.ZERO,
		"hand_alignment_offset_origin_id": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT,
	}
	if humanoid_rig == null:
		return result
	if humanoid_rig.has_method("resolve_hand_grip_alignment_offset_state"):
		var state_variant: Variant = humanoid_rig.call("resolve_hand_grip_alignment_offset_state", slot_id)
		if state_variant is Dictionary:
			var source_state: Dictionary = state_variant as Dictionary
			_resolve_origin_tracked_state_origin_id(
				source_state,
				"hand_alignment_offset_origin_id",
				CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
			)
			return source_state
	if humanoid_rig.has_method("resolve_hand_grip_alignment_offset_origin_id"):
		var origin_variant: Variant = humanoid_rig.call("resolve_hand_grip_alignment_offset_origin_id", slot_id)
		if origin_variant is StringName or origin_variant is String:
			var origin_id: StringName = StringName(origin_variant)
			if origin_id != StringName():
				result["hand_alignment_offset_origin_id"] = origin_id
	if humanoid_rig.has_method("resolve_hand_grip_alignment_offset_local"):
		var alignment_variant: Variant = humanoid_rig.call("resolve_hand_grip_alignment_offset_local", slot_id)
		if alignment_variant is Vector3:
			result["hand_alignment_offset_local"] = alignment_variant
	return result

func _set_origin_tracked_vector3_meta(
	target: Object,
	value_meta_name: String,
	origin_meta_name: String,
	value: Vector3,
	origin_id: StringName
) -> void:
	if target == null:
		return
	var resolved_origin_id: StringName = origin_id
	if resolved_origin_id == StringName():
		resolved_origin_id = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
	target.set_meta(value_meta_name, value)
	target.set_meta(origin_meta_name, resolved_origin_id)

func _get_weapon_tip_meta(held_item: Object) -> Vector3:
	return _get_origin_tracked_vector3_meta(
		held_item,
		"weapon_tip_local",
		"weapon_tip_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)

func _get_weapon_pommel_meta(held_item: Object) -> Vector3:
	return _get_origin_tracked_vector3_meta(
		held_item,
		"weapon_pommel_local",
		"weapon_pommel_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)

func _get_primary_grip_contact_meta(held_item: Object) -> Vector3:
	return _get_origin_tracked_vector3_meta(
		held_item,
		"primary_grip_contact_local",
		"primary_grip_contact_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)

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
	return humanoid_rig.get_weapon_stow_anchor(_resolve_station_stow_anchor_mode(saved_wip), slot_id)

func _resolve_station_stow_anchor_mode(saved_wip: CraftedItemWIP) -> StringName:
	if saved_wip == null:
		return CombatAnimationDraftScript.STOW_ANCHOR_SHOULDER_HANGING
	var fallback_stow_mode: StringName = CombatAnimationDraftScript.normalize_stow_anchor_mode(saved_wip.stow_position_mode)
	var noncombat_idle_draft: CombatAnimationDraft = _resolve_station_noncombat_idle_draft(saved_wip)
	if noncombat_idle_draft != null:
		return CombatAnimationDraftScript.normalize_stow_anchor_mode(noncombat_idle_draft.stow_anchor_mode)
	return fallback_stow_mode

func _resolve_station_noncombat_idle_draft(saved_wip: CraftedItemWIP) -> CombatAnimationDraft:
	if saved_wip == null:
		return null
	var station_state: CombatAnimationStationState = saved_wip.ensure_combat_animation_station_state() as CombatAnimationStationState
	if station_state == null:
		return null
	station_state.normalize()
	for draft_variant: Variant in station_state.idle_drafts:
		var draft: CombatAnimationDraft = draft_variant as CombatAnimationDraft
		if draft == null or draft.context_id != CombatAnimationStationStateScript.IDLE_CONTEXT_NONCOMBAT:
			continue
		return draft
	return null

func get_equipped_visual_anchor(humanoid_rig: Node3D, weapons_drawn: bool, slot_id: StringName, saved_wip: CraftedItemWIP) -> Node3D:
	if weapons_drawn:
		return get_hand_anchor(humanoid_rig, slot_id)
	return get_stow_anchor(humanoid_rig, slot_id, saved_wip)

func reanchor_equipped_item_nodes(
	humanoid_rig: Node3D,
	held_item_nodes: Dictionary,
	resolved_equipment_state,
	weapons_drawn: bool
) -> bool:
	if humanoid_rig == null or resolved_equipment_state == null:
		return false
	for slot_id: StringName in [&"hand_right", &"hand_left"]:
		var held_item: Node3D = held_item_nodes.get(slot_id) as Node3D
		var equipped_entry = resolved_equipment_state.get_equipped_slot(slot_id)
		var has_equipped_wip: bool = equipped_entry != null and equipped_entry.has_method("is_forge_test_wip") and equipped_entry.is_forge_test_wip()
		if not has_equipped_wip:
			if held_item != null and is_instance_valid(held_item):
				return false
			continue
		if held_item == null or not is_instance_valid(held_item):
			return false
		if StringName(held_item.get_meta("source_wip_id", StringName())) != equipped_entry.source_wip_id:
			return false
		var target_anchor: Node3D = _resolve_cached_equipped_visual_anchor(humanoid_rig, weapons_drawn, slot_id, held_item)
		if target_anchor == null:
			return false
		var source_anchor_origin_id: StringName = _resolve_current_equipped_anchor_origin_id(held_item)
		var target_anchor_origin_id: StringName = _resolve_equipped_visual_anchor_origin_id(weapons_drawn)
		_reparent_held_item_to_anchor(
			held_item,
			target_anchor,
			source_anchor_origin_id,
			target_anchor_origin_id
		)
		if weapons_drawn:
			apply_hand_mount_transform(held_item)
		else:
			apply_cached_station_stow_transform(held_item, target_anchor)
	sync_rig_weapon_guidance(humanoid_rig, held_item_nodes, weapons_drawn, resolved_equipment_state)
	return true

func apply_hand_mount_transform(held_item: Node3D) -> void:
	if held_item == null:
		return
	_ensure_origin_meta(held_item, HAND_MOUNT_LOCAL_TRANSFORM_ORIGIN_META, CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT)
	held_item.transform = held_item.get_meta(HAND_MOUNT_LOCAL_TRANSFORM_META, held_item.transform) as Transform3D

func apply_cached_station_stow_transform(
	held_item: Node3D,
	stow_anchor: Node3D = null
) -> bool:
	if held_item == null:
		return false
	var anchor_node: Node3D = stow_anchor if stow_anchor != null else (held_item.get_parent() as Node3D)
	if anchor_node == null:
		return false
	if not bool(held_item.get_meta("station_stow_motion_node_available", false)):
		apply_hand_mount_transform(held_item)
		held_item.set_meta("station_stow_motion_node_applied", false)
		return false
	_ensure_origin_meta(held_item, "weapon_tip_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	_ensure_origin_meta(held_item, "weapon_pommel_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	_ensure_origin_meta(held_item, "station_stow_requested_tip_position_origin_id", CombatOriginRecordScript.ORIGIN_STOW_ANCHOR)
	_ensure_origin_meta(held_item, "station_stow_requested_pommel_position_origin_id", CombatOriginRecordScript.ORIGIN_STOW_ANCHOR)
	_ensure_origin_meta(held_item, "station_stow_pommel_position_origin_id", CombatOriginRecordScript.ORIGIN_STOW_ANCHOR)
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var local_tip_origin_id: StringName = _resolve_origin_meta_value(held_item, "weapon_tip_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	var local_pommel: Vector3 = _get_weapon_pommel_meta(held_item)
	var local_pommel_origin_id: StringName = _resolve_origin_meta_value(held_item, "weapon_pommel_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	var stow_tip_local: Vector3 = _get_origin_tracked_vector3_meta(
		held_item,
		"station_stow_requested_tip_position_local",
		"station_stow_requested_tip_position_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	)
	var stow_tip_origin_id: StringName = _resolve_origin_meta_value(held_item, "station_stow_requested_tip_position_origin_id", CombatOriginRecordScript.ORIGIN_STOW_ANCHOR)
	var stow_pommel_local: Vector3 = _get_origin_tracked_vector3_meta(
		held_item,
		"station_stow_pommel_position_local",
		"station_stow_pommel_position_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	)
	var stow_pommel_origin_id: StringName = _resolve_origin_meta_value(held_item, "station_stow_pommel_position_origin_id", CombatOriginRecordScript.ORIGIN_STOW_ANCHOR)
	if held_item.has_meta("station_stow_requested_pommel_position_local"):
		stow_pommel_local = _get_origin_tracked_vector3_meta(
			held_item,
			"station_stow_requested_pommel_position_local",
			"station_stow_requested_pommel_position_origin_id",
			stow_pommel_local,
			CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
		)
		stow_pommel_origin_id = _resolve_origin_meta_value(held_item, "station_stow_requested_pommel_position_origin_id", stow_pommel_origin_id)
	if local_tip.is_equal_approx(local_pommel) or stow_tip_local.is_equal_approx(stow_pommel_local):
		apply_hand_mount_transform(held_item)
		held_item.set_meta("station_stow_motion_node_applied", false)
		return false
	held_item.set_meta("cached_stow_compare_tip_origin_id", local_tip_origin_id)
	held_item.set_meta("cached_stow_compare_pommel_origin_id", local_pommel_origin_id)
	held_item.set_meta("cached_stow_compare_stow_tip_origin_id", stow_tip_origin_id)
	held_item.set_meta("cached_stow_compare_stow_pommel_origin_id", stow_pommel_origin_id)
	var local_axis: Vector3 = (local_tip - local_pommel).normalized()
	var local_axis_origin_id: StringName = local_tip_origin_id
	var local_up_reference_state: Dictionary = _resolve_weapon_local_up_reference_state(held_item, local_axis, local_axis_origin_id)
	var local_up_reference_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		local_up_reference_state,
		"up_reference_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var local_up_reference: Vector3 = _get_origin_tracked_vector3_state(
		local_up_reference_state,
		"local_up_reference",
		"up_reference_origin_id",
		Vector3.UP,
		local_up_reference_origin_id
	)
	var stow_authoring_basis: Basis = _resolve_station_stow_authoring_basis(anchor_node)
	var stow_anchor_world: Vector3 = anchor_node.global_position
	var authored_tip_world: Vector3 = stow_anchor_world + stow_authoring_basis * stow_tip_local
	var authored_pommel_world: Vector3 = stow_anchor_world + stow_authoring_basis * stow_pommel_local
	var authored_axis_world: Vector3 = authored_tip_world - authored_pommel_world
	if authored_axis_world.length_squared() <= 0.000001:
		authored_axis_world = stow_authoring_basis.z
	var weapon_segment_length: float = local_tip.distance_to(local_pommel)
	var resolved_tip_world: Vector3 = authored_pommel_world + authored_axis_world.normalized() * weapon_segment_length
	var segment_tip_origin_id: StringName = local_tip_origin_id
	var segment_pommel_origin_id: StringName = local_pommel_origin_id
	var segment_up_reference_origin_id: StringName = local_up_reference_origin_id
	held_item.set_meta("cached_stow_segment_tip_origin_id", segment_tip_origin_id)
	held_item.set_meta("cached_stow_segment_pommel_origin_id", segment_pommel_origin_id)
	held_item.set_meta("cached_stow_segment_up_reference_origin_id", segment_up_reference_origin_id)
	var solved_transform: Transform3D = weapon_frame_solver.solve_transform_from_segment(
		local_tip,
		local_pommel,
		resolved_tip_world,
		authored_pommel_world,
		local_up_reference,
		stow_authoring_basis,
		held_item.get_meta("station_stow_weapon_orientation_degrees", Vector3.ZERO) as Vector3,
		float(held_item.get_meta("station_stow_weapon_roll_degrees", 0.0)),
		segment_tip_origin_id,
		segment_pommel_origin_id,
		segment_up_reference_origin_id
	)
	held_item.global_transform = solved_transform
	held_item.set_meta("station_stow_motion_node_applied", true)
	held_item.set_meta("station_stow_origin_id", CombatOriginRecordScript.ORIGIN_NONCOMBAT_STOW)
	held_item.set_meta("station_stow_anchor_origin_id", CombatOriginRecordScript.ORIGIN_STOW_ANCHOR)
	_set_origin_tracked_vector3_meta(
		held_item,
		"station_stow_tip_position_local",
		"station_stow_tip_position_origin_id",
		anchor_node.to_local(resolved_tip_world),
		CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	)
	_set_origin_tracked_vector3_meta(
		held_item,
		"station_stow_pommel_position_local",
		"station_stow_pommel_position_origin_id",
		anchor_node.to_local(authored_pommel_world),
		CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	)
	held_item.set_meta("station_stow_contact_ratio", held_item.get_meta("station_stow_contact_ratio", CombatAnimationDraftScript.DEFAULT_STOW_CONTACT_RATIO))
	return true

func _resolve_cached_equipped_visual_anchor(
	humanoid_rig: Node3D,
	weapons_drawn: bool,
	slot_id: StringName,
	held_item: Node3D
) -> Node3D:
	if weapons_drawn:
		return get_hand_anchor(humanoid_rig, slot_id)
	if humanoid_rig == null or held_item == null:
		return null
	var stow_anchor_mode: StringName = CombatAnimationDraftScript.normalize_stow_anchor_mode(
		held_item.get_meta("station_stow_anchor_mode", CombatAnimationDraftScript.STOW_ANCHOR_SHOULDER_HANGING) as StringName
	)
	return humanoid_rig.get_weapon_stow_anchor(stow_anchor_mode, slot_id)

func _resolve_equipped_visual_anchor_origin_id(weapons_drawn: bool) -> StringName:
	if weapons_drawn:
		return CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	return CombatOriginRecordScript.ORIGIN_STOW_ANCHOR

func _resolve_current_equipped_anchor_origin_id(held_item: Node3D) -> StringName:
	if held_item == null:
		return CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
	var runtime_endpoint_origin_id: StringName = StringName(held_item.get_meta(
		"runtime_endpoint_authority_origin_id",
		StringName()
	))
	if bool(held_item.get_meta("runtime_endpoint_authority_active", false)) and runtime_endpoint_origin_id != StringName():
		return runtime_endpoint_origin_id
	var equipped_anchor_origin_id: StringName = StringName(held_item.get_meta(
		EQUIPPED_VISUAL_ANCHOR_ORIGIN_META,
		StringName()
	))
	if equipped_anchor_origin_id != StringName():
		return equipped_anchor_origin_id
	if bool(held_item.get_meta("station_stow_motion_node_applied", false)):
		return CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	return CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT

func _resolve_station_stow_authoring_basis(stow_anchor: Node3D) -> Basis:
	if stow_anchor == null:
		return Basis.IDENTITY
	var skeleton: Skeleton3D = _resolve_skeleton_from_stow_anchor(stow_anchor)
	if skeleton != null:
		var root_index: int = skeleton.find_bone(String(STOW_AUTHORING_ROOT_BONE))
		if root_index >= 0:
			return (skeleton.global_basis * skeleton.get_bone_global_pose(root_index).basis).orthonormalized()
	return stow_anchor.global_basis.orthonormalized()

func _resolve_skeleton_from_stow_anchor(stow_anchor: Node3D) -> Skeleton3D:
	var node: Node = stow_anchor
	while node != null:
		if node is Skeleton3D:
			return node as Skeleton3D
		node = node.get_parent()
	return null

func _reparent_held_item_to_anchor(
	held_item: Node3D,
	target_anchor: Node3D,
	source_anchor_origin_id: StringName = StringName(),
	target_anchor_origin_id: StringName = StringName()
) -> void:
	if held_item == null or target_anchor == null:
		return
	var resolved_source_origin_id: StringName = source_anchor_origin_id
	if resolved_source_origin_id == StringName():
		resolved_source_origin_id = _resolve_current_equipped_anchor_origin_id(held_item)
	var resolved_target_origin_id: StringName = target_anchor_origin_id
	if resolved_target_origin_id == StringName():
		resolved_target_origin_id = CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	held_item.set_meta(EQUIPPED_REANCHOR_SOURCE_ORIGIN_META, resolved_source_origin_id)
	held_item.set_meta(EQUIPPED_REANCHOR_TARGET_ORIGIN_META, resolved_target_origin_id)
	held_item.set_meta(EQUIPPED_VISUAL_ANCHOR_ORIGIN_META, resolved_target_origin_id)
	if held_item.get_parent() == target_anchor:
		return
	var current_parent: Node = held_item.get_parent()
	if current_parent != null:
		current_parent.remove_child(held_item)
	target_anchor.add_child(held_item)

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
	var preserved_baked_profile_snapshot: BakedProfile = (
		saved_wip.latest_baked_profile_snapshot.duplicate(true) as BakedProfile
		if saved_wip.latest_baked_profile_snapshot != null
		else null
	)
	var test_print: TestPrintInstance = forge_service.build_test_print_from_wip(saved_wip, material_lookup)
	if test_print == null or test_print.baked_profile == null or not test_print.baked_profile.primary_grip_valid:
		if preserved_baked_profile_snapshot != null:
			saved_wip.latest_baked_profile_snapshot = preserved_baked_profile_snapshot
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
	held_root.set_meta("source_wip_id", saved_wip.wip_id)
	held_root.set_meta("grip_style_mode", resolved_grip_style)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = build_held_item_material(forge_view_tuning)
	mesh_instance.set_meta("visual_mesh_source", test_print.visual_mesh_source)
	var cell_world_size: float = forge_rules.cell_world_size_meters
	var grip_hold_layout: Dictionary = {}
	if humanoid_rig != null and humanoid_rig.has_method("resolve_grip_hold_layout"):
		grip_hold_layout = humanoid_rig.resolve_grip_hold_layout(test_print.baked_profile, slot_id, cell_world_size)
	var dominant_hand_local_position: Vector3 = test_print.baked_profile.primary_grip_contact_position
	var dominant_hand_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var support_hand_local_position: Vector3 = Vector3.ZERO
	var support_hand_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var two_hand_character_eligible: bool = false
	if bool(grip_hold_layout.get("valid", false)):
		dominant_hand_position_origin_id = _resolve_origin_tracked_state_origin_id(
			grip_hold_layout,
			"dominant_hand_position_origin_id",
			dominant_hand_position_origin_id
		)
		dominant_hand_local_position = _get_origin_tracked_vector3_state(
			grip_hold_layout,
			"dominant_hand_local_position",
			"dominant_hand_position_origin_id",
			dominant_hand_local_position,
			dominant_hand_position_origin_id
		)
		support_hand_position_origin_id = _resolve_origin_tracked_state_origin_id(
			grip_hold_layout,
			"support_hand_position_origin_id",
			support_hand_position_origin_id
		)
		support_hand_local_position = _get_origin_tracked_vector3_state(
			grip_hold_layout,
			"support_hand_local_position",
			"support_hand_position_origin_id",
			support_hand_local_position,
			support_hand_position_origin_id
		)
		two_hand_character_eligible = bool(grip_hold_layout.get("two_hand_character_eligible", false))
	else:
		grip_hold_layout["dominant_hand_position_origin_id"] = dominant_hand_position_origin_id
		grip_hold_layout["support_hand_position_origin_id"] = support_hand_position_origin_id
	held_root.set_meta("grip_hold_layout", grip_hold_layout)
	held_root.set_meta("two_hand_character_eligible", two_hand_character_eligible)
	var dominant_grip_shell_data: Dictionary = _build_grip_contact_shell_data(
		test_print.display_cells,
		dominant_hand_local_position,
		cell_world_size,
		test_print.baked_profile,
		dominant_hand_position_origin_id
	)
	var dominant_grip_center_origin_id: StringName = dominant_hand_position_origin_id
	var dominant_grip_center_local: Vector3 = dominant_hand_local_position
	if not dominant_grip_shell_data.is_empty():
		dominant_grip_center_origin_id = _resolve_origin_tracked_state_origin_id(
			dominant_grip_shell_data,
			"slice_center_origin_id",
			dominant_grip_center_origin_id
		)
		dominant_grip_center_local = _get_origin_tracked_vector3_state(
			dominant_grip_shell_data,
			"slice_center_local",
			"slice_center_origin_id",
			dominant_hand_local_position,
			dominant_hand_position_origin_id
		)
	var support_grip_shell_data: Dictionary = {}
	var support_grip_center_local: Vector3 = support_hand_local_position
	var support_grip_center_origin_id: StringName = support_hand_position_origin_id
	if resolved_grip_style != CraftedItemWIP.GRIP_REVERSE and two_hand_character_eligible:
		support_grip_shell_data = _build_grip_contact_shell_data(
			test_print.display_cells,
			support_hand_local_position,
			cell_world_size,
			test_print.baked_profile,
			support_hand_position_origin_id
		)
		if not support_grip_shell_data.is_empty():
			support_grip_center_origin_id = _resolve_origin_tracked_state_origin_id(
				support_grip_shell_data,
				"slice_center_origin_id",
				support_grip_center_origin_id
			)
			support_grip_center_local = _get_origin_tracked_vector3_state(
				support_grip_shell_data,
				"slice_center_local",
				"slice_center_origin_id",
				support_hand_local_position,
				support_hand_position_origin_id
			)
	var hand_alignment_offset_state: Dictionary = _resolve_hand_alignment_offset_state(humanoid_rig, slot_id)
	var hand_alignment_offset_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		hand_alignment_offset_state,
		"hand_alignment_offset_origin_id",
		CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	)
	var hand_alignment_offset_local: Vector3 = _get_origin_tracked_vector3_state(
		hand_alignment_offset_state,
		"hand_alignment_offset_local",
		"hand_alignment_offset_origin_id",
		Vector3.ZERO,
		hand_alignment_offset_origin_id
	)
	mesh_instance.scale = Vector3.ONE * cell_world_size
	var dominant_grip_center_mesh_origin_id: StringName = dominant_grip_center_origin_id
	var mesh_visual_offset_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var mesh_visual_offset_local: Vector3 = -dominant_grip_center_local * cell_world_size
	mesh_instance.position = mesh_visual_offset_local
	mesh_instance.set_meta("dominant_grip_center_origin_id", dominant_grip_center_mesh_origin_id)
	_set_origin_tracked_vector3_meta(
		mesh_instance,
		"mesh_visual_offset_local",
		"mesh_visual_offset_origin_id",
		mesh_visual_offset_local,
		mesh_visual_offset_origin_id
	)
	held_root.add_child(mesh_instance)
	var primary_grip_guide := Node3D.new()
	primary_grip_guide.name = "PrimaryGripGuide"
	held_root.add_child(primary_grip_guide)
	var dominant_hand_position_guide_origin_id: StringName = dominant_hand_position_origin_id
	primary_grip_guide.set_meta("dominant_hand_position_origin_id", dominant_hand_position_guide_origin_id)
	if dominant_grip_shell_data.is_empty():
		_configure_grip_contact_guide(
			primary_grip_guide,
			test_print.display_cells,
			dominant_hand_local_position,
			cell_world_size,
			test_print.baked_profile,
			dominant_hand_position_guide_origin_id
		)
	else:
		_configure_grip_contact_guide_from_shell_data(primary_grip_guide, dominant_grip_shell_data, cell_world_size)
	var secondary_grip_guide: Node3D = null
	var support_grip_contact_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var support_grip_contact_local: Vector3 = Vector3.ZERO
	if resolved_grip_style != CraftedItemWIP.GRIP_REVERSE and two_hand_character_eligible:
		var support_hand_position_guide_origin_id: StringName = support_hand_position_origin_id
		var support_grip_center_offset_origin_id: StringName = support_grip_center_origin_id
		var dominant_grip_center_offset_origin_id: StringName = dominant_grip_center_origin_id
		var support_offset_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		var support_local_offset: Vector3 = (support_grip_center_local - dominant_grip_center_local) * cell_world_size
		if not support_local_offset.is_zero_approx():
			secondary_grip_guide = Node3D.new()
			secondary_grip_guide.name = "SecondaryGripGuide"
			secondary_grip_guide.position = support_local_offset
			secondary_grip_guide.set_meta("support_hand_position_origin_id", support_hand_position_guide_origin_id)
			secondary_grip_guide.set_meta("support_grip_center_origin_id", support_grip_center_offset_origin_id)
			secondary_grip_guide.set_meta("dominant_grip_center_origin_id", dominant_grip_center_offset_origin_id)
			_set_origin_tracked_vector3_meta(
				secondary_grip_guide,
				"support_local_offset",
				"support_offset_origin_id",
				support_local_offset,
				support_offset_origin_id
			)
			support_grip_contact_origin_id = support_offset_origin_id
			support_grip_contact_local = support_local_offset
			held_root.add_child(secondary_grip_guide)
			if support_grip_shell_data.is_empty():
				_configure_grip_contact_guide(
					secondary_grip_guide,
					test_print.display_cells,
					support_hand_local_position,
					cell_world_size,
					test_print.baked_profile,
					support_hand_position_guide_origin_id
				)
			else:
				_configure_grip_contact_guide_from_shell_data(secondary_grip_guide, support_grip_shell_data, cell_world_size)
	var dominant_grip_center_weapon_origin_id: StringName = dominant_grip_center_origin_id
	var weapon_tip_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var weapon_tip_local: Vector3 = (test_print.baked_profile.weapon_tip_point - dominant_grip_center_local) * cell_world_size
	var weapon_pommel_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var weapon_pommel_local: Vector3 = (test_print.baked_profile.weapon_pommel_point - dominant_grip_center_local) * cell_world_size
	var primary_grip_contact_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var primary_grip_contact_local: Vector3 = (test_print.baked_profile.primary_grip_contact_position - dominant_grip_center_local) * cell_world_size
	var primary_grip_span_start_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var primary_grip_span_start_local: Vector3 = (test_print.baked_profile.primary_grip_span_start - dominant_grip_center_local) * cell_world_size
	var primary_grip_span_end_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var primary_grip_span_end_local: Vector3 = (test_print.baked_profile.primary_grip_span_end - dominant_grip_center_local) * cell_world_size
	var primary_grip_slide_axis_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var primary_grip_slide_axis_local: Vector3 = test_print.baked_profile.primary_grip_slide_axis.normalized()
	held_root.set_meta("dominant_grip_center_weapon_origin_id", dominant_grip_center_weapon_origin_id)
	held_root.set_meta("weapon_tip_origin_id", weapon_tip_origin_id)
	held_root.set_meta("primary_grip_contact_origin_id", primary_grip_contact_origin_id)
	held_root.transform.basis = _resolve_signed_contact_axis_weapon_hold_basis(
		humanoid_rig,
		slot_id,
		resolved_grip_style,
		weapon_tip_local,
		weapon_tip_origin_id,
		primary_grip_contact_local,
		primary_grip_contact_origin_id,
		held_root.transform.basis
	)
	held_root.position = _resolve_hand_mount_origin_local(
		hand_alignment_offset_local,
		hand_alignment_offset_origin_id,
		primary_grip_contact_local,
		primary_grip_contact_origin_id,
		held_root.transform.basis
	)
	held_root.set_meta(HAND_MOUNT_LOCAL_TRANSFORM_META, held_root.transform)
	held_root.set_meta(HAND_MOUNT_LOCAL_TRANSFORM_ORIGIN_META, CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT)
	_set_origin_tracked_vector3_meta(held_root, "hand_alignment_offset_local", "hand_alignment_offset_origin_id", hand_alignment_offset_local, hand_alignment_offset_origin_id)
	_set_origin_tracked_vector3_meta(held_root, "weapon_tip_local", "weapon_tip_origin_id", weapon_tip_local, weapon_tip_origin_id)
	_set_origin_tracked_vector3_meta(held_root, "weapon_pommel_local", "weapon_pommel_origin_id", weapon_pommel_local, weapon_pommel_origin_id)
	held_root.set_meta("weapon_total_length_meters", float(test_print.baked_profile.weapon_total_length_meters))
	_set_origin_tracked_vector3_meta(held_root, "primary_grip_contact_local", "primary_grip_contact_origin_id", primary_grip_contact_local, primary_grip_contact_origin_id)
	held_root.set_meta("primary_grip_span_start_local", primary_grip_span_start_local)
	held_root.set_meta("primary_grip_span_start_origin_id", primary_grip_span_start_origin_id)
	held_root.set_meta("primary_grip_span_end_local", primary_grip_span_end_local)
	held_root.set_meta("primary_grip_span_end_origin_id", primary_grip_span_end_origin_id)
	held_root.set_meta("primary_grip_axis_ratio_from_span_start", float(test_print.baked_profile.primary_grip_axis_ratio_from_span_start))
	held_root.set_meta("primary_grip_slide_axis_local", primary_grip_slide_axis_local)
	held_root.set_meta("primary_grip_slide_axis_origin_id", primary_grip_slide_axis_origin_id)
	if secondary_grip_guide != null:
		_set_origin_tracked_vector3_meta(held_root, "support_grip_contact_local", "support_grip_contact_origin_id", support_grip_contact_local, support_grip_contact_origin_id)
	_cache_station_stow_pose_metadata(held_root, saved_wip)
	weapon_grip_anchor_provider.ensure_grip_anchor_nodes(held_root, primary_grip_guide, secondary_grip_guide)
	attach_weapon_bounds_area(held_root, canonical_geometry, dominant_grip_center_local, dominant_grip_center_origin_id, cell_world_size, held_item_mesh_builder)
	_attach_weapon_body_restriction_proxy(
		held_root,
		mesh,
		test_print.display_cells,
		dominant_grip_shell_data,
		dominant_grip_center_local,
		dominant_grip_center_origin_id,
		cell_world_size
	)
	return held_root

func _cache_station_stow_pose_metadata(held_item: Node3D, saved_wip: CraftedItemWIP) -> void:
	if held_item == null or saved_wip == null:
		return
	var stow_anchor_mode: StringName = _resolve_station_stow_anchor_mode(saved_wip)
	held_item.set_meta("station_stow_anchor_mode", stow_anchor_mode)
	held_item.set_meta("station_stow_motion_node_available", false)
	var noncombat_idle_draft: CombatAnimationDraft = _resolve_station_noncombat_idle_draft(saved_wip)
	if noncombat_idle_draft == null:
		return
	noncombat_idle_draft.ensure_minimum_baseline_nodes()
	if noncombat_idle_draft.motion_node_chain.is_empty():
		return
	var stow_motion_node: CombatAnimationMotionNode = noncombat_idle_draft.motion_node_chain[0] as CombatAnimationMotionNode
	if stow_motion_node == null:
		return
	var stow_contact_ratio: float = CombatAnimationDraftScript.normalize_stow_contact_ratio(noncombat_idle_draft.stow_contact_ratio)
	var stow_segment: Dictionary = _resolve_station_stow_anchor_local_segment(stow_motion_node, stow_contact_ratio)
	held_item.set_meta("station_stow_motion_node_available", true)
	held_item.set_meta("station_stow_origin_id", CombatOriginRecordScript.ORIGIN_NONCOMBAT_STOW)
	held_item.set_meta("station_stow_anchor_origin_id", CombatOriginRecordScript.ORIGIN_STOW_ANCHOR)
	held_item.set_meta("station_stow_contact_ratio", stow_contact_ratio)
	var stow_tip_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		stow_segment,
		"tip_position_origin_id",
		CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	)
	var stow_tip_local: Vector3 = _get_origin_tracked_vector3_state(
		stow_segment,
		"tip_position_local",
		"tip_position_origin_id",
		stow_motion_node.tip_position_local,
		stow_tip_origin_id
	)
	var stow_pommel_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		stow_segment,
		"pommel_position_origin_id",
		CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	)
	var stow_pommel_local: Vector3 = _get_origin_tracked_vector3_state(
		stow_segment,
		"pommel_position_local",
		"pommel_position_origin_id",
		stow_motion_node.pommel_position_local,
		stow_pommel_origin_id
	)
	_set_origin_tracked_vector3_meta(
		held_item,
		"station_stow_requested_tip_position_local",
		"station_stow_requested_tip_position_origin_id",
		stow_tip_local,
		stow_tip_origin_id
	)
	_set_origin_tracked_vector3_meta(
		held_item,
		"station_stow_requested_pommel_position_local",
		"station_stow_requested_pommel_position_origin_id",
		stow_pommel_local,
		stow_pommel_origin_id
	)
	_set_origin_tracked_vector3_meta(
		held_item,
		"station_stow_pommel_position_local",
		"station_stow_pommel_position_origin_id",
		stow_pommel_local,
		stow_pommel_origin_id
	)
	held_item.set_meta("station_stow_weapon_orientation_degrees", stow_motion_node.weapon_orientation_degrees)
	held_item.set_meta("station_stow_weapon_roll_degrees", stow_motion_node.weapon_roll_degrees)

func _resolve_station_stow_anchor_local_segment(stow_motion_node: CombatAnimationMotionNode, contact_ratio: float) -> Dictionary:
	if stow_motion_node == null:
		return {
			"tip_position_local": Vector3.ZERO,
			"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_STOW_ANCHOR,
			"pommel_position_local": Vector3.ZERO,
			"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_STOW_ANCHOR,
			"contact_position_local": Vector3.ZERO,
			"contact_position_origin_id": CombatOriginRecordScript.ORIGIN_STOW_ANCHOR,
		}
	var resolved_contact_ratio: float = CombatAnimationDraftScript.normalize_stow_contact_ratio(contact_ratio)
	var contact_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	var contact_position_state := {
		"contact_position_local": stow_motion_node.pommel_position_local.lerp(
			stow_motion_node.tip_position_local,
			resolved_contact_ratio
		),
		"contact_position_origin_id": contact_position_origin_id,
	}
	var contact_position_local: Vector3 = _get_origin_tracked_vector3_state(
		contact_position_state,
		"contact_position_local",
		"contact_position_origin_id",
		Vector3.ZERO,
		contact_position_origin_id
	)
	return {
		"tip_position_local": stow_motion_node.tip_position_local - contact_position_local,
		"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_STOW_ANCHOR,
		"pommel_position_local": stow_motion_node.pommel_position_local - contact_position_local,
		"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_STOW_ANCHOR,
		"contact_position_local": contact_position_local,
		"contact_position_origin_id": contact_position_origin_id,
	}

func _configure_grip_contact_guide(
	grip_guide: Node3D,
	display_cells: Array[CellAtom],
	contact_position_local: Vector3,
	cell_world_size: float,
	baked_profile: BakedProfile,
	contact_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
) -> void:
	if grip_guide == null or display_cells.is_empty() or baked_profile == null:
		return
	var grip_shell_data: Dictionary = _build_grip_contact_shell_data(
		display_cells,
		contact_position_local,
		cell_world_size,
		baked_profile,
		contact_position_origin_id
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
	var major_axis_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		grip_shell_data,
		"major_axis_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	_set_origin_tracked_vector3_meta(
		grip_center,
		"grip_shell_major_axis_local",
		"grip_shell_major_axis_origin_id",
		_get_origin_tracked_vector3_state(
			grip_shell_data,
			"major_axis_local",
			"major_axis_origin_id",
			Vector3.ZERO,
			major_axis_origin_id
		),
		major_axis_origin_id
	)
	var minor_axis_a_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		grip_shell_data,
		"minor_axis_a_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	_set_origin_tracked_vector3_meta(
		grip_center,
		"grip_shell_minor_axis_a_local",
		"grip_shell_minor_axis_a_origin_id",
		_get_origin_tracked_vector3_state(
			grip_shell_data,
			"minor_axis_a_local",
			"minor_axis_a_origin_id",
			Vector3.ZERO,
			minor_axis_a_origin_id
		),
		minor_axis_a_origin_id
	)
	var minor_axis_b_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		grip_shell_data,
		"minor_axis_b_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	_set_origin_tracked_vector3_meta(
		grip_center,
		"grip_shell_minor_axis_b_local",
		"grip_shell_minor_axis_b_origin_id",
		_get_origin_tracked_vector3_state(
			grip_shell_data,
			"minor_axis_b_local",
			"minor_axis_b_origin_id",
			Vector3.ZERO,
			minor_axis_b_origin_id
		),
		minor_axis_b_origin_id
	)
	grip_center.set_meta("grip_shell_profile_offsets_minor", grip_shell_data.get("profile_offsets_minor", []))
	var slice_center_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		grip_shell_data,
		"slice_center_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	_set_origin_tracked_vector3_meta(
		grip_center,
		"grip_shell_slice_center_local",
		"grip_shell_slice_center_origin_id",
		_get_origin_tracked_vector3_state(
			grip_shell_data,
			"slice_center_local",
			"slice_center_origin_id",
			Vector3.ZERO,
			slice_center_origin_id
		),
		slice_center_origin_id
	)
	grip_center.set_meta("grip_shell_collision_layer", GRIP_CONTACT_COLLISION_LAYER)
	_attach_grip_contact_area(grip_center, grip_shell_data, cell_world_size)

func _build_grip_contact_shell_data(
	display_cells: Array[CellAtom],
	contact_position_local: Vector3,
	cell_world_size: float,
	baked_profile: BakedProfile,
	contact_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
) -> Dictionary:
	var contact_position_state := {
		"contact_position_local": contact_position_local,
		"contact_position_origin_id": contact_position_origin_id,
	}
	var resolved_contact_position_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		contact_position_state,
		"contact_position_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var resolved_contact_position_local: Vector3 = _get_origin_tracked_vector3_state(
		contact_position_state,
		"contact_position_local",
		"contact_position_origin_id",
		contact_position_local,
		resolved_contact_position_origin_id
	)
	var major_axis_local: Vector3 = _resolve_primary_axis_vector(baked_profile.primary_grip_slide_axis)
	var major_axis_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	if major_axis_local.length_squared() <= 0.000001:
		return {}
	var major_axis_index: int = _resolve_axis_index(major_axis_local)
	if major_axis_index < 0:
		return {}
	var minor_axis_indices: Array[int] = _resolve_minor_axis_indices(major_axis_index)
	var slice_index: int = int(round(_get_vector_component(resolved_contact_position_local, major_axis_index)))
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
		var component_center_origin_id: StringName = resolved_contact_position_origin_id
		var distance_squared: float = component_center_local.distance_squared_to(resolved_contact_position_local)
		if best_component.is_empty() or distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_component = {
				"positions": component_coords,
				"center_local": component_center_local,
				"center_origin_id": component_center_origin_id,
			}
	if best_component.is_empty():
		return {}
	var center_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		best_component,
		"center_origin_id",
		resolved_contact_position_origin_id
	)
	var center_local: Vector3 = _get_origin_tracked_vector3_state(
		best_component,
		"center_local",
		"center_origin_id",
		resolved_contact_position_local,
		center_origin_id
	)
	var center_minor_a: float = _get_vector_component(center_local, minor_axis_indices[0])
	var center_minor_b: float = _get_vector_component(center_local, minor_axis_indices[1])
	var profile_offsets_minor: Array = []
	for coord_variant: Variant in best_component.get("positions", []):
		var coord: Vector2i = coord_variant as Vector2i
		profile_offsets_minor.append(Vector2(
			(float(coord.x) - center_minor_a) * cell_world_size,
			(float(coord.y) - center_minor_b) * cell_world_size
		))
	var guide_center_offset_origin_id: StringName = center_origin_id
	var guide_center_offset_local: Vector3 = (center_local - resolved_contact_position_local) * cell_world_size
	var slice_center_origin_id: StringName = center_origin_id
	var minor_axis_a_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var minor_axis_b_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	return {
		"guide_center_offset_local": guide_center_offset_local,
		"guide_center_offset_origin_id": guide_center_offset_origin_id,
		"slice_center_local": center_local,
		"slice_center_origin_id": slice_center_origin_id,
		"major_axis_local": major_axis_local,
		"major_axis_origin_id": major_axis_origin_id,
		"minor_axis_a_local": _axis_index_to_vector3(minor_axis_indices[0]),
		"minor_axis_a_origin_id": minor_axis_a_origin_id,
		"minor_axis_b_local": _axis_index_to_vector3(minor_axis_indices[1]),
		"minor_axis_b_origin_id": minor_axis_b_origin_id,
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
	var major_axis_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		grip_shell_data,
		"major_axis_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var major_axis_index: int = _resolve_axis_index(_get_origin_tracked_vector3_state(
		grip_shell_data,
		"major_axis_local",
		"major_axis_origin_id",
		Vector3.ZERO,
		major_axis_origin_id
	))
	if major_axis_index < 0:
		return
	var profile_offsets: Array = grip_shell_data.get("profile_offsets_minor", [])
	var minor_axis_a_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		grip_shell_data,
		"minor_axis_a_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var minor_axis_a_local: Vector3 = _get_origin_tracked_vector3_state(
		grip_shell_data,
		"minor_axis_a_local",
		"minor_axis_a_origin_id",
		Vector3.RIGHT,
		minor_axis_a_origin_id
	)
	var minor_axis_b_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		grip_shell_data,
		"minor_axis_b_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var minor_axis_b_local: Vector3 = _get_origin_tracked_vector3_state(
		grip_shell_data,
		"minor_axis_b_local",
		"minor_axis_b_origin_id",
		Vector3.UP,
		minor_axis_b_origin_id
	)
	var shape_size_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var local_shape_size: Vector3 = Vector3.ONE * cell_world_size
	local_shape_size = _set_axis_component(local_shape_size, major_axis_index, cell_world_size)
	for profile_index: int in range(profile_offsets.size()):
		var offset_minor: Vector2 = profile_offsets[profile_index] as Vector2
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "GripCellShape_%d" % profile_index
		var box_shape := BoxShape3D.new()
		box_shape.size = local_shape_size
		collision_shape.shape = box_shape
		collision_shape.set_meta("grip_contact_shape_size_origin_id", shape_size_origin_id)
		var minor_axis_a_offset_origin_id: StringName = minor_axis_a_origin_id
		var minor_axis_b_offset_origin_id: StringName = minor_axis_b_origin_id
		var contact_cell_offset_origin_id: StringName = minor_axis_a_offset_origin_id
		var contact_cell_offset_local: Vector3 = (
			minor_axis_a_local * offset_minor.x
			+ minor_axis_b_local * offset_minor.y
		)
		collision_shape.position = contact_cell_offset_local
		_set_origin_tracked_vector3_meta(
			collision_shape,
			"grip_contact_offset_local",
			"grip_contact_offset_origin_id",
			contact_cell_offset_local,
			contact_cell_offset_origin_id
		)
		collision_shape.set_meta("grip_contact_offset_minor_axis_a_origin_id", minor_axis_a_offset_origin_id)
		collision_shape.set_meta("grip_contact_offset_minor_axis_b_origin_id", minor_axis_b_offset_origin_id)
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
		grip_contact_position_local: Vector3,
		grip_contact_position_origin_id: StringName,
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
		grip_contact_position_local,
		cell_world_size,
		1
	)
	box_shape.size = bounds_data.get("size_meters", Vector3.ONE)
	collision_shape.shape = box_shape
	var bounds_center_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		bounds_data,
		"center_origin_id",
		grip_contact_position_origin_id
	)
	var bounds_center_local: Vector3 = _get_origin_tracked_vector3_state(
		bounds_data,
		"center_local",
		"center_origin_id",
		Vector3.ZERO,
		bounds_center_origin_id
	)
	collision_shape.position = bounds_center_local
	collision_shape.set_meta("weapon_bounds_center_origin_id", bounds_center_origin_id)
	bounds_area.add_child(collision_shape)
	held_root.add_child(bounds_area)
	_set_origin_tracked_vector3_meta(
		held_root,
		"weapon_bounds_center_local",
		"weapon_bounds_center_origin_id",
		bounds_center_local,
		bounds_center_origin_id
	)
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
	visual_mesh: ArrayMesh,
	display_cells: Array[CellAtom],
	grip_shell_data: Dictionary,
	grip_center_local: Vector3,
	grip_center_origin_id: StringName,
	cell_world_size: float
) -> void:
	if held_root == null:
		return
	var proxy_root: Node3D = held_root.get_node_or_null("WeaponBodyRestrictionProxy") as Node3D
	if proxy_root == null:
		proxy_root = Node3D.new()
		proxy_root.name = "WeaponBodyRestrictionProxy"
		held_root.add_child(proxy_root)
	proxy_root.transform = Transform3D.IDENTITY
	var sample_data: Dictionary = _build_weapon_body_proxy_samples(
		held_root,
		visual_mesh,
		display_cells,
		grip_shell_data,
		grip_center_local,
		grip_center_origin_id,
		cell_world_size,
		WEAPON_CLEARANCE_PROXY_OFFSET_METERS
	)
	var sample_offsets_meters: Array[Vector3] = sample_data.get("samples", []) as Array[Vector3]
	var sample_offsets_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		sample_data,
		"samples_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var desired_names: Array[String] = []
	for sample_index: int in range(sample_offsets_meters.size()):
		var sample_name: String = "WeaponBodySample_%d" % sample_index
		desired_names.append(sample_name)
		var sample_node: Node3D = proxy_root.get_node_or_null(sample_name) as Node3D
		if sample_node == null:
			sample_node = Node3D.new()
			sample_node.name = sample_name
			proxy_root.add_child(sample_node)
		sample_node.position = sample_offsets_meters[sample_index]
		_set_origin_tracked_vector3_meta(
			sample_node,
			"weapon_proxy_sample_local",
			"weapon_proxy_sample_origin_id",
			sample_offsets_meters[sample_index],
			sample_offsets_origin_id
		)
		sample_node.set_meta("proxy_source", &"stage2_geometry_derived")
		sample_node.set_meta("clearance_offset_meters", WEAPON_CLEARANCE_PROXY_OFFSET_METERS)
	for child_node: Node in proxy_root.get_children():
		if desired_names.has(String(child_node.name)):
			continue
		proxy_root.remove_child(child_node)
		child_node.queue_free()
	proxy_root.set_meta("proxy_source", sample_data.get("source", &"stage2_geometry_derived") as StringName)
	proxy_root.set_meta("grip_center_origin_id", grip_center_origin_id)
	proxy_root.set_meta("weapon_proxy_sample_origin_id", sample_offsets_origin_id)
	proxy_root.set_meta("clearance_offset_meters", WEAPON_CLEARANCE_PROXY_OFFSET_METERS)
	proxy_root.set_meta("weapon_proxy_sample_count", sample_offsets_meters.size())
	proxy_root.set_meta("weapon_proxy_uses_full_geometry", bool(sample_data.get("uses_full_geometry", false)))

func _build_weapon_body_proxy_samples(
	held_root: Node3D,
	visual_mesh: ArrayMesh,
	display_cells: Array[CellAtom],
	grip_shell_data: Dictionary,
	grip_center_local: Vector3,
	grip_center_origin_id: StringName,
	cell_world_size: float,
	clearance_offset_meters: float
) -> Dictionary:
	var grip_center_state := {
		"grip_center_local": grip_center_local,
		"grip_center_origin_id": grip_center_origin_id,
	}
	var resolved_grip_center_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		grip_center_state,
		"grip_center_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var resolved_grip_center_local: Vector3 = _get_origin_tracked_vector3_state(
		grip_center_state,
		"grip_center_local",
		"grip_center_origin_id",
		grip_center_local,
		resolved_grip_center_origin_id
	)
	var samples: Array[Vector3] = []
	_append_unique_proxy_sample(samples, Vector3.ZERO)
	var mesh_sample_count: int = _append_visual_mesh_proxy_samples(
		samples,
		visual_mesh,
		resolved_grip_center_local,
		resolved_grip_center_origin_id,
		cell_world_size,
		clearance_offset_meters
	)
	var source: StringName = &"visual_mesh_surface"
	if mesh_sample_count <= 0:
		_append_display_cell_proxy_samples(
			samples,
			display_cells,
			resolved_grip_center_local,
			resolved_grip_center_origin_id,
			cell_world_size,
			clearance_offset_meters
		)
		source = &"display_cell_surface"
	_ensure_origin_meta(held_root, "weapon_tip_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	_ensure_origin_meta(held_root, "weapon_pommel_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	var tip_local: Vector3 = _get_weapon_tip_meta(held_root)
	var pommel_local: Vector3 = _get_weapon_pommel_meta(held_root)
	if tip_local.length_squared() > 0.000001 or pommel_local.length_squared() > 0.000001:
		_append_unique_proxy_sample(samples, tip_local)
		_append_unique_proxy_sample(samples, pommel_local)
		for step_index: int in range(1, 6):
			_append_unique_proxy_sample(samples, pommel_local.lerp(tip_local, float(step_index) / 6.0))
	var slice_center_offset_origin_id: StringName = resolved_grip_center_origin_id
	if not grip_shell_data.is_empty():
		var slice_center_local: Vector3 = _get_origin_tracked_vector3_state(
			grip_shell_data,
			"slice_center_local",
			"slice_center_origin_id",
			resolved_grip_center_local,
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		)
		var major_axis_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
			grip_shell_data,
			"major_axis_origin_id",
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		)
		var major_axis_local: Vector3 = _get_origin_tracked_vector3_state(
			grip_shell_data,
			"major_axis_local",
			"major_axis_origin_id",
			Vector3.FORWARD,
			major_axis_origin_id
		).normalized()
		if major_axis_local.length_squared() <= 0.000001:
			major_axis_local = Vector3.FORWARD
		var slice_center_offset_meters: Vector3 = (slice_center_local - resolved_grip_center_local) * cell_world_size
		_append_unique_proxy_sample(samples, slice_center_offset_meters)
		_append_unique_proxy_sample(samples, slice_center_offset_meters + major_axis_local * cell_world_size * 2.0)
		_append_unique_proxy_sample(samples, slice_center_offset_meters - major_axis_local * cell_world_size * 2.0)
	return {
		"samples": samples,
		"source": source,
		"samples_origin_id": CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
		"slice_center_offset_origin_id": slice_center_offset_origin_id,
		"uses_full_geometry": mesh_sample_count > 0 or not display_cells.is_empty(),
	}

func _append_visual_mesh_proxy_samples(
	samples: Array[Vector3],
	visual_mesh: ArrayMesh,
	grip_center_local: Vector3,
	grip_center_origin_id: StringName,
	cell_world_size: float,
	clearance_offset_meters: float
) -> int:
	if visual_mesh == null or visual_mesh.get_surface_count() <= 0:
		return 0
	var grip_center_state := {
		"grip_center_local": grip_center_local,
		"grip_center_origin_id": grip_center_origin_id,
	}
	var resolved_grip_center_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		grip_center_state,
		"grip_center_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var resolved_grip_center_local: Vector3 = _get_origin_tracked_vector3_state(
		grip_center_state,
		"grip_center_local",
		"grip_center_origin_id",
		grip_center_local,
		resolved_grip_center_origin_id
	)
	var mesh_positions: Array[Vector3] = []
	for surface_index: int in range(visual_mesh.get_surface_count()):
		var surface_arrays: Array = visual_mesh.surface_get_arrays(surface_index)
		if surface_arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		var vertices_variant: Variant = surface_arrays[Mesh.ARRAY_VERTEX]
		if vertices_variant is not PackedVector3Array:
			continue
		var vertices: PackedVector3Array = vertices_variant
		for vertex: Vector3 in vertices:
			var proxy_surface_position_origin_id: StringName = resolved_grip_center_origin_id
			var proxy_surface_position_local: Vector3 = (vertex - resolved_grip_center_local) * cell_world_size
			_append_unique_proxy_sample(
				mesh_positions,
				_expand_weapon_proxy_surface_point(
					proxy_surface_position_local,
					clearance_offset_meters,
					proxy_surface_position_origin_id
				)
			)
		_append_visual_mesh_triangle_centroid_samples(
			mesh_positions,
			surface_arrays,
			resolved_grip_center_local,
			resolved_grip_center_origin_id,
			cell_world_size,
			clearance_offset_meters
		)
	if mesh_positions.is_empty():
		return 0
	var before_count: int = samples.size()
	_append_extreme_proxy_samples(samples, mesh_positions)
	var stride: int = maxi(1, int(ceil(float(mesh_positions.size()) / float(MAX_WEAPON_BODY_PROXY_SURFACE_SAMPLES))))
	for position_index: int in range(mesh_positions.size()):
		if position_index % stride != 0:
			continue
		_append_unique_proxy_sample(samples, mesh_positions[position_index])
	return samples.size() - before_count

func _append_visual_mesh_triangle_centroid_samples(
	mesh_positions: Array[Vector3],
	surface_arrays: Array,
	grip_center_local: Vector3,
	grip_center_origin_id: StringName,
	cell_world_size: float,
	clearance_offset_meters: float
) -> void:
	if surface_arrays.size() <= Mesh.ARRAY_VERTEX:
		return
	var grip_center_state := {
		"grip_center_local": grip_center_local,
		"grip_center_origin_id": grip_center_origin_id,
	}
	var resolved_grip_center_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		grip_center_state,
		"grip_center_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var resolved_grip_center_local: Vector3 = _get_origin_tracked_vector3_state(
		grip_center_state,
		"grip_center_local",
		"grip_center_origin_id",
		grip_center_local,
		resolved_grip_center_origin_id
	)
	var vertices_variant: Variant = surface_arrays[Mesh.ARRAY_VERTEX]
	if vertices_variant is not PackedVector3Array:
		return
	var vertices: PackedVector3Array = vertices_variant
	if vertices.size() < 3:
		return
	var indices: PackedInt32Array = PackedInt32Array()
	if surface_arrays.size() > Mesh.ARRAY_INDEX and surface_arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		indices = surface_arrays[Mesh.ARRAY_INDEX]
	if not indices.is_empty():
		for index_offset: int in range(0, indices.size() - 2, 3):
			var a_index: int = indices[index_offset]
			var b_index: int = indices[index_offset + 1]
			var c_index: int = indices[index_offset + 2]
			if a_index < 0 or b_index < 0 or c_index < 0:
				continue
			if a_index >= vertices.size() or b_index >= vertices.size() or c_index >= vertices.size():
				continue
			var centroid: Vector3 = (vertices[a_index] + vertices[b_index] + vertices[c_index]) / 3.0
			var proxy_surface_position_origin_id: StringName = resolved_grip_center_origin_id
			var proxy_surface_position_local: Vector3 = (centroid - resolved_grip_center_local) * cell_world_size
			_append_unique_proxy_sample(
				mesh_positions,
				_expand_weapon_proxy_surface_point(
					proxy_surface_position_local,
					clearance_offset_meters,
					proxy_surface_position_origin_id
				)
			)
		return
	for vertex_offset: int in range(0, vertices.size() - 2, 3):
		var centroid: Vector3 = (vertices[vertex_offset] + vertices[vertex_offset + 1] + vertices[vertex_offset + 2]) / 3.0
		var proxy_surface_position_origin_id: StringName = resolved_grip_center_origin_id
		var proxy_surface_position_local: Vector3 = (centroid - resolved_grip_center_local) * cell_world_size
		_append_unique_proxy_sample(
			mesh_positions,
			_expand_weapon_proxy_surface_point(
				proxy_surface_position_local,
				clearance_offset_meters,
				proxy_surface_position_origin_id
			)
		)

func _expand_weapon_proxy_surface_point(
	position_meters_local: Vector3,
	clearance_offset_meters: float,
	position_meters_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
) -> Vector3:
	var position_meters_state := {
		"position_meters_local": position_meters_local,
		"position_meters_origin_id": position_meters_origin_id,
	}
	var resolved_position_meters_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		position_meters_state,
		"position_meters_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var resolved_position_meters_local: Vector3 = _get_origin_tracked_vector3_state(
		position_meters_state,
		"position_meters_local",
		"position_meters_origin_id",
		position_meters_local,
		resolved_position_meters_origin_id
	)
	var clearance: float = maxf(clearance_offset_meters, 0.0)
	if clearance <= 0.000001 or resolved_position_meters_local.length_squared() <= 0.000001:
		return resolved_position_meters_local
	return resolved_position_meters_local + resolved_position_meters_local.normalized() * clearance

func _append_extreme_proxy_samples(samples: Array[Vector3], mesh_positions: Array[Vector3]) -> void:
	if mesh_positions.is_empty():
		return
	var min_x: Vector3 = mesh_positions[0]
	var max_x: Vector3 = mesh_positions[0]
	var min_y: Vector3 = mesh_positions[0]
	var max_y: Vector3 = mesh_positions[0]
	var min_z: Vector3 = mesh_positions[0]
	var max_z: Vector3 = mesh_positions[0]
	for position: Vector3 in mesh_positions:
		if position.x < min_x.x:
			min_x = position
		if position.x > max_x.x:
			max_x = position
		if position.y < min_y.y:
			min_y = position
		if position.y > max_y.y:
			max_y = position
		if position.z < min_z.z:
			min_z = position
		if position.z > max_z.z:
			max_z = position
	for extreme_position: Vector3 in [min_x, max_x, min_y, max_y, min_z, max_z]:
		_append_unique_proxy_sample(samples, extreme_position)

func _resolve_weapon_display_cell_bounds(
	display_cells: Array[CellAtom],
	grip_center_local: Vector3,
	grip_center_origin_id: StringName,
	cell_world_size: float,
	clearance_offset_meters: float
) -> Dictionary:
	if display_cells.is_empty():
		return {"valid": false}
	var grip_center_state := {
		"grip_center_local": grip_center_local,
		"grip_center_origin_id": grip_center_origin_id,
	}
	var resolved_grip_center_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		grip_center_state,
		"grip_center_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var resolved_grip_center_local: Vector3 = _get_origin_tracked_vector3_state(
		grip_center_state,
		"grip_center_local",
		"grip_center_origin_id",
		grip_center_local,
		resolved_grip_center_origin_id
	)
	var min_local := Vector3(INF, INF, INF)
	var max_local := Vector3(-INF, -INF, -INF)
	var half_cell := Vector3.ONE * cell_world_size * 0.5
	var cell_origin_id: StringName = resolved_grip_center_origin_id
	var min_origin_id: StringName = cell_origin_id
	var max_origin_id: StringName = cell_origin_id
	for cell: CellAtom in display_cells:
		if cell == null:
			continue
		var cell_local: Vector3 = (cell.get_center_position() - resolved_grip_center_local) * cell_world_size
		min_local = Vector3(
			minf(min_local.x, cell_local.x - half_cell.x),
			minf(min_local.y, cell_local.y - half_cell.y),
			minf(min_local.z, cell_local.z - half_cell.z)
		)
		max_origin_id = cell_origin_id
		max_local = Vector3(
			maxf(max_local.x, cell_local.x + half_cell.x),
			maxf(max_local.y, cell_local.y + half_cell.y),
			maxf(max_local.z, cell_local.z + half_cell.z)
		)
	if min_local.x == INF or max_local.x == -INF:
		return {"valid": false}
	var clearance := Vector3.ONE * maxf(clearance_offset_meters, 0.0)
	return {
		"valid": true,
		"min": min_local - clearance,
		"min_origin_id": min_origin_id,
		"max": max_local + clearance,
		"max_origin_id": max_origin_id,
	}

func _append_box_proxy_samples(samples: Array[Vector3], bounds_min: Vector3, bounds_max: Vector3) -> void:
	var center: Vector3 = bounds_min.lerp(bounds_max, 0.5)
	for x_index: int in range(2):
		for y_index: int in range(2):
			for z_index: int in range(2):
				_append_unique_proxy_sample(samples, Vector3(
					bounds_max.x if x_index == 1 else bounds_min.x,
					bounds_max.y if y_index == 1 else bounds_min.y,
					bounds_max.z if z_index == 1 else bounds_min.z
				))
	_append_unique_proxy_sample(samples, Vector3(bounds_min.x, center.y, center.z))
	_append_unique_proxy_sample(samples, Vector3(bounds_max.x, center.y, center.z))
	_append_unique_proxy_sample(samples, Vector3(center.x, bounds_min.y, center.z))
	_append_unique_proxy_sample(samples, Vector3(center.x, bounds_max.y, center.z))
	_append_unique_proxy_sample(samples, Vector3(center.x, center.y, bounds_min.z))
	_append_unique_proxy_sample(samples, Vector3(center.x, center.y, bounds_max.z))

func _append_display_cell_proxy_samples(
	samples: Array[Vector3],
	display_cells: Array[CellAtom],
	grip_center_local: Vector3,
	grip_center_origin_id: StringName,
	cell_world_size: float,
	clearance_offset_meters: float
) -> void:
	if display_cells.is_empty():
		return
	var grip_center_state := {
		"grip_center_local": grip_center_local,
		"grip_center_origin_id": grip_center_origin_id,
	}
	var resolved_grip_center_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		grip_center_state,
		"grip_center_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var resolved_grip_center_local: Vector3 = _get_origin_tracked_vector3_state(
		grip_center_state,
		"grip_center_local",
		"grip_center_origin_id",
		grip_center_local,
		resolved_grip_center_origin_id
	)
	var stride: int = maxi(1, int(ceil(float(display_cells.size()) / float(MAX_WEAPON_BODY_PROXY_CELL_SAMPLES))))
	var occupied_lookup: Dictionary = {}
	for cell: CellAtom in display_cells:
		if cell == null:
			continue
		occupied_lookup[cell.grid_position] = true
	for cell_index: int in range(display_cells.size()):
		if cell_index % stride != 0:
			continue
		var cell: CellAtom = display_cells[cell_index]
		if cell == null:
			continue
		var cell_center_state := {
			"cell_center_local": (cell.get_center_position() - resolved_grip_center_local) * cell_world_size,
			"cell_center_origin_id": resolved_grip_center_origin_id,
		}
		var cell_center_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
			cell_center_state,
			"cell_center_origin_id",
			resolved_grip_center_origin_id
		)
		var cell_center_local: Vector3 = _get_origin_tracked_vector3_state(
			cell_center_state,
			"cell_center_local",
			"cell_center_origin_id",
			Vector3.ZERO,
			cell_center_origin_id
		)
		_append_unique_proxy_sample(samples, cell_center_local)
		for normal: Vector3i in [
			Vector3i(1, 0, 0),
			Vector3i(-1, 0, 0),
			Vector3i(0, 1, 0),
			Vector3i(0, -1, 0),
			Vector3i(0, 0, 1),
			Vector3i(0, 0, -1),
		]:
			if occupied_lookup.has(cell.grid_position + normal):
				continue
			var face_offset: Vector3 = Vector3(normal) * ((cell_world_size * 0.5) + maxf(clearance_offset_meters, 0.0))
			var face_sample_origin_id: StringName = cell_center_origin_id
			var face_sample_state := {
				"face_sample_local": cell_center_local + face_offset,
				"face_sample_origin_id": face_sample_origin_id,
			}
			face_sample_origin_id = _resolve_origin_tracked_state_origin_id(
				face_sample_state,
				"face_sample_origin_id",
				cell_center_origin_id
			)
			var face_sample_local: Vector3 = _get_origin_tracked_vector3_state(
				face_sample_state,
				"face_sample_local",
				"face_sample_origin_id",
				cell_center_local,
				face_sample_origin_id
			)
			_append_unique_proxy_sample(samples, face_sample_local)

func _append_unique_proxy_sample(samples: Array[Vector3], sample_position: Vector3) -> void:
	for existing: Vector3 in samples:
		if existing.distance_squared_to(sample_position) <= 0.00000025:
			return
	samples.append(sample_position)

func resolve_hand_mount_local_transform(held_item: Node3D) -> Transform3D:
	if held_item == null:
		return Transform3D.IDENTITY
	_ensure_origin_meta(held_item, HAND_MOUNT_LOCAL_TRANSFORM_ORIGIN_META, CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT)
	var stored_transform: Variant = held_item.get_meta(HAND_MOUNT_LOCAL_TRANSFORM_META, held_item.transform)
	return stored_transform as Transform3D if stored_transform is Transform3D else held_item.transform

func apply_held_item_grip_style_mode(
	held_item: Node3D,
	humanoid_rig: Node3D,
	slot_id: StringName,
	grip_style_mode: StringName
) -> void:
	if held_item == null or not is_instance_valid(held_item):
		return
	var resolved_grip_style: StringName = CraftedItemWIP.normalize_grip_style_mode(grip_style_mode)
	held_item.set_meta("grip_style_mode", resolved_grip_style)
	_ensure_origin_meta(held_item, "weapon_tip_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	_ensure_origin_meta(held_item, "primary_grip_contact_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var local_tip_origin_id: StringName = _resolve_origin_meta_value(held_item, "weapon_tip_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	var primary_grip_contact_local: Vector3 = _get_primary_grip_contact_meta(held_item)
	var primary_grip_contact_origin_id: StringName = _resolve_origin_meta_value(held_item, "primary_grip_contact_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	var fallback_basis: Basis = build_weapon_hold_basis(resolved_grip_style, slot_id)
	var resolved_basis: Basis = _resolve_signed_contact_axis_weapon_hold_basis(
		humanoid_rig,
		slot_id,
		resolved_grip_style,
		local_tip,
		local_tip_origin_id,
		primary_grip_contact_local,
		primary_grip_contact_origin_id,
		fallback_basis
	)
	var mount_transform: Transform3D = resolve_hand_mount_local_transform(held_item)
	var target_contact_local: Vector3 = mount_transform.origin + mount_transform.basis * primary_grip_contact_local
	var hand_alignment_offset_state: Dictionary = _resolve_hand_alignment_offset_state(humanoid_rig, slot_id)
	var target_contact_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		hand_alignment_offset_state,
		"hand_alignment_offset_origin_id",
		CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	)
	target_contact_local = _get_origin_tracked_vector3_state(
		hand_alignment_offset_state,
		"hand_alignment_offset_local",
		"hand_alignment_offset_origin_id",
		target_contact_local,
		target_contact_origin_id
	)
	mount_transform.basis = resolved_basis.orthonormalized()
	mount_transform.origin = _resolve_hand_mount_origin_local(
		target_contact_local,
		target_contact_origin_id,
		primary_grip_contact_local,
		primary_grip_contact_origin_id,
		mount_transform.basis
	)
	held_item.set_meta(HAND_MOUNT_LOCAL_TRANSFORM_META, mount_transform)
	held_item.set_meta(HAND_MOUNT_LOCAL_TRANSFORM_ORIGIN_META, CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT)
	_set_origin_tracked_vector3_meta(held_item, "hand_alignment_offset_local", "hand_alignment_offset_origin_id", target_contact_local, target_contact_origin_id)

func clear_rig_weapon_contact_guidance(humanoid_rig: Node3D) -> void:
	if humanoid_rig == null:
		return
	if humanoid_rig.has_method("clear_arm_guidance_target"):
		humanoid_rig.call("clear_arm_guidance_target", &"hand_right")
		humanoid_rig.call("clear_arm_guidance_target", &"hand_left")
	if humanoid_rig.has_method("clear_arm_guidance_active"):
		humanoid_rig.call("clear_arm_guidance_active", &"hand_right")
		humanoid_rig.call("clear_arm_guidance_active", &"hand_left")
	if humanoid_rig.has_method("clear_dominant_grip_slot"):
		humanoid_rig.call("clear_dominant_grip_slot")
	if humanoid_rig.has_method("clear_finger_grip_target"):
		humanoid_rig.call("clear_finger_grip_target", &"hand_right")
		humanoid_rig.call("clear_finger_grip_target", &"hand_left")
	if humanoid_rig.has_method("clear_authoring_contact_anchor_bases"):
		humanoid_rig.call("clear_authoring_contact_anchor_bases")
	if humanoid_rig.has_method("set_support_hand_active"):
		humanoid_rig.call("set_support_hand_active", &"hand_right", false)
		humanoid_rig.call("set_support_hand_active", &"hand_left", false)

func sync_single_weapon_contact_guidance(
	humanoid_rig: Node3D,
	held_item: Node3D,
	dominant_slot_id: StringName,
	use_support_hand: bool,
	claim_dominant_slot: bool,
	dominant_arm_guidance_active: bool,
	support_arm_guidance_active: bool,
	authoring_contact_basis_enabled: bool,
	clear_inactive_support: bool = true
) -> void:
	if humanoid_rig == null or held_item == null:
		return
	var resolved_dominant_slot_id: StringName = _normalize_hand_slot_id(dominant_slot_id)
	var support_slot_id: StringName = _resolve_support_slot_id(resolved_dominant_slot_id)
	var primary_guide: Node3D = held_item.get_node_or_null("PrimaryGripGuide") as Node3D
	var primary_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_anchor(held_item)
	_assign_slot_weapon_contact_guidance(
		humanoid_rig,
		held_item,
		resolved_dominant_slot_id,
		primary_anchor,
		primary_guide,
		dominant_arm_guidance_active,
		false,
		claim_dominant_slot,
		authoring_contact_basis_enabled
	)
	if not use_support_hand or not bool(held_item.get_meta("two_hand_character_eligible", false)):
		if clear_inactive_support:
			_clear_slot_weapon_contact_guidance(humanoid_rig, support_slot_id)
		return
	var secondary_guide: Node3D = held_item.get_node_or_null("SecondaryGripGuide") as Node3D
	if secondary_guide == null:
		if clear_inactive_support:
			_clear_slot_weapon_contact_guidance(humanoid_rig, support_slot_id)
		return
	var support_anchor: Node3D = weapon_grip_anchor_provider.get_support_grip_anchor(held_item)
	_assign_slot_weapon_contact_guidance(
		humanoid_rig,
		held_item,
		support_slot_id,
		support_anchor if support_anchor != null else secondary_guide,
		secondary_guide,
		support_arm_guidance_active,
		true,
		false,
		authoring_contact_basis_enabled
	)

func _assign_slot_weapon_contact_guidance(
	humanoid_rig: Node3D,
	held_item: Node3D,
	slot_id: StringName,
	arm_target_node: Node3D,
	finger_guide_node: Node3D,
	arm_guidance_active: bool,
	support_hand_active: bool,
	claim_dominant_slot: bool,
	authoring_contact_basis_enabled: bool
) -> void:
	if humanoid_rig == null:
		return
	if arm_target_node != null and humanoid_rig.has_method("set_arm_guidance_target"):
		humanoid_rig.call("set_arm_guidance_target", slot_id, arm_target_node)
	if humanoid_rig.has_method("set_arm_guidance_active"):
		humanoid_rig.call("set_arm_guidance_active", slot_id, arm_guidance_active)
	if finger_guide_node != null and humanoid_rig.has_method("set_finger_grip_target"):
		humanoid_rig.call("set_finger_grip_target", slot_id, finger_guide_node)
	if humanoid_rig.has_method("set_support_hand_active"):
		humanoid_rig.call("set_support_hand_active", slot_id, support_hand_active)
	if claim_dominant_slot and humanoid_rig.has_method("set_dominant_grip_slot"):
		humanoid_rig.call("set_dominant_grip_slot", slot_id)
	if authoring_contact_basis_enabled:
		_apply_slot_authoring_contact_basis(humanoid_rig, held_item, slot_id, finger_guide_node)

func _clear_slot_weapon_contact_guidance(humanoid_rig: Node3D, slot_id: StringName) -> void:
	if humanoid_rig == null:
		return
	if humanoid_rig.has_method("clear_arm_guidance_target"):
		humanoid_rig.call("clear_arm_guidance_target", slot_id)
	if humanoid_rig.has_method("clear_arm_guidance_active"):
		humanoid_rig.call("clear_arm_guidance_active", slot_id)
	if humanoid_rig.has_method("clear_finger_grip_target"):
		humanoid_rig.call("clear_finger_grip_target", slot_id)
	if humanoid_rig.has_method("clear_authoring_contact_anchor_basis"):
		humanoid_rig.call("clear_authoring_contact_anchor_basis", slot_id)
	if humanoid_rig.has_method("set_support_hand_active"):
		humanoid_rig.call("set_support_hand_active", slot_id, false)

func _apply_slot_authoring_contact_basis(
	humanoid_rig: Node3D,
	held_item: Node3D,
	slot_id: StringName,
	finger_guide_node: Node3D
) -> void:
	if humanoid_rig == null or held_item == null:
		return
	if not humanoid_rig.has_method("set_authoring_contact_anchor_basis"):
		return
	var basis_world: Basis = _resolve_slot_contact_anchor_basis_world(humanoid_rig, held_item, slot_id, finger_guide_node)
	humanoid_rig.call("set_authoring_contact_anchor_basis", slot_id, basis_world)

func _resolve_slot_contact_anchor_basis_world(
	humanoid_rig: Node3D,
	held_item: Node3D,
	slot_id: StringName,
	finger_guide_node: Node3D
) -> Basis:
	if held_item == null:
		return Basis.IDENTITY
	var desired_hand_basis_world: Basis = _resolve_slot_contact_hand_basis_world(
		humanoid_rig,
		held_item,
		slot_id,
		finger_guide_node
	)
	var hand_anchor: Node3D = get_hand_anchor(humanoid_rig, slot_id)
	if hand_anchor != null:
		return (desired_hand_basis_world * hand_anchor.transform.basis.orthonormalized()).orthonormalized()
	return desired_hand_basis_world

func _resolve_slot_contact_hand_basis_world(
	humanoid_rig: Node3D,
	held_item: Node3D,
	_slot_id: StringName,
	finger_guide_node: Node3D
) -> Basis:
	if held_item == null:
		return Basis.IDENTITY
	var grip_axis_world: Vector3 = _resolve_weapon_tip_axis_world(held_item, finger_guide_node)
	if grip_axis_world.length_squared() <= 0.000001:
		return held_item.global_basis.orthonormalized()
	var grip_style_mode: StringName = held_item.get_meta("grip_style_mode", CraftedItemWIP.GRIP_NORMAL) as StringName
	var x_sign: float = 1.0 if grip_style_mode == CraftedItemWIP.GRIP_NORMAL else -1.0
	var desired_contact_axis_world: Vector3 = grip_axis_world.normalized() * x_sign
	var desired_hand_y_world: Vector3 = _resolve_contact_hand_up_reference_world(
		humanoid_rig,
		held_item,
		finger_guide_node,
		desired_contact_axis_world
	)
	var contact_axis_state: Dictionary = _resolve_slot_contact_axis_state(humanoid_rig, _slot_id)
	var contact_axis_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		contact_axis_state,
		"contact_axis_origin_id",
		CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	)
	var contact_axis_local: Vector3 = _get_origin_tracked_vector3_state(
		contact_axis_state,
		"contact_axis_local",
		"contact_axis_origin_id",
		Vector3.RIGHT,
		contact_axis_origin_id
	)
	return _build_basis_aligning_local_axis(
		contact_axis_local,
		desired_contact_axis_world,
		desired_hand_y_world
	)

func _resolve_slot_contact_axis_local(humanoid_rig: Node3D, slot_id: StringName) -> Vector3:
	var contact_axis_state: Dictionary = _resolve_slot_contact_axis_state(humanoid_rig, slot_id)
	var contact_axis_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		contact_axis_state,
		"contact_axis_origin_id",
		CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	)
	return _get_origin_tracked_vector3_state(
		contact_axis_state,
		"contact_axis_local",
		"contact_axis_origin_id",
		Vector3.RIGHT,
		contact_axis_origin_id
	)

func _resolve_slot_contact_axis_state(humanoid_rig: Node3D, slot_id: StringName) -> Dictionary:
	var resolve_hand_index_pinky_axis_origin_id: StringName = CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	if humanoid_rig != null and humanoid_rig.has_method("resolve_hand_index_pinky_axis_local"):
		var resolved_axis: Vector3 = humanoid_rig.call("resolve_hand_index_pinky_axis_local", slot_id) as Vector3
		if resolved_axis.length_squared() > 0.000001:
			return {
				"contact_axis_local": resolved_axis.normalized(),
				"contact_axis_origin_id": resolve_hand_index_pinky_axis_origin_id,
				"resolve_hand_index_pinky_axis_origin_id": resolve_hand_index_pinky_axis_origin_id,
			}
	return {
		"contact_axis_local": Vector3.RIGHT,
		"contact_axis_origin_id": resolve_hand_index_pinky_axis_origin_id,
		"resolve_hand_index_pinky_axis_origin_id": resolve_hand_index_pinky_axis_origin_id,
	}

func _resolve_contact_hand_up_reference_world(
	humanoid_rig: Node3D,
	held_item: Node3D,
	finger_guide_node: Node3D,
	desired_contact_axis_world: Vector3
) -> Vector3:
	var basis_anchor: Node3D = _resolve_grip_basis_anchor_for_guide(held_item, finger_guide_node)
	if basis_anchor != null and is_instance_valid(basis_anchor):
		var authored_up_world: Vector3 = basis_anchor.global_basis.y.normalized()
		if authored_up_world.length_squared() > 0.000001:
			return authored_up_world
	return _resolve_roll_decoupled_contact_up_reference_world(humanoid_rig, desired_contact_axis_world)

func _resolve_grip_basis_anchor_for_guide(held_item: Node3D, finger_guide_node: Node3D) -> Node3D:
	if held_item == null:
		return null
	if finger_guide_node != null and String(finger_guide_node.name) == "SecondaryGripGuide":
		return weapon_grip_anchor_provider.get_support_grip_basis_anchor(held_item)
	return weapon_grip_anchor_provider.get_primary_grip_basis_anchor(held_item)

func _resolve_roll_decoupled_contact_up_reference_world(humanoid_rig: Node3D, grip_axis_world: Vector3) -> Vector3:
	var locked_axis: Vector3 = grip_axis_world.normalized()
	var character_basis: Basis = humanoid_rig.global_basis.orthonormalized() if humanoid_rig != null else Basis.IDENTITY
	var up_reference: Vector3 = character_basis.y
	up_reference = up_reference - locked_axis * up_reference.dot(locked_axis)
	if up_reference.length_squared() <= 0.000001:
		up_reference = character_basis.x - locked_axis * character_basis.x.dot(locked_axis)
	if up_reference.length_squared() <= 0.000001:
		up_reference = Vector3.UP - locked_axis * Vector3.UP.dot(locked_axis)
	if up_reference.length_squared() <= 0.000001:
		up_reference = Vector3.RIGHT
	return up_reference.normalized()

func _resolve_weapon_tip_axis_world(held_item: Node3D, finger_guide_node: Node3D) -> Vector3:
	if held_item == null:
		return Vector3.ZERO
	var contact_axis_override_world: Vector3 = held_item.get_meta("authoring_contact_grip_axis_world_override", Vector3.ZERO) as Vector3
	if contact_axis_override_world.length_squared() > 0.000001:
		return contact_axis_override_world.normalized()
	_ensure_origin_meta(held_item, "weapon_tip_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	var local_tip_origin_id: StringName = _resolve_origin_meta_value(held_item, "weapon_tip_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	var guide_origin_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var guide_local_origin: Vector3 = finger_guide_node.position if finger_guide_node != null else Vector3.ZERO
	var grip_center: Node3D = finger_guide_node.get_node_or_null("GripShellCenter") as Node3D if finger_guide_node != null else null
	if grip_center != null:
		guide_origin_origin_id = _resolve_origin_meta_value(grip_center, "grip_shell_slice_center_origin_id", guide_origin_origin_id)
		guide_local_origin += grip_center.position
	var guide_origin_state := {
		"guide_origin_local": guide_local_origin,
		"guide_origin_origin_id": guide_origin_origin_id,
	}
	guide_local_origin = _get_origin_tracked_vector3_state(
		guide_origin_state,
		"guide_origin_local",
		"guide_origin_origin_id",
		Vector3.ZERO,
		guide_origin_origin_id
	)
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var tip_direction_origin_id: StringName = local_tip_origin_id
	var tip_direction_state := {
		"tip_direction_local": local_tip - guide_local_origin,
		"tip_direction_origin_id": tip_direction_origin_id,
	}
	var local_tip_direction: Vector3 = _get_origin_tracked_vector3_state(
		tip_direction_state,
		"tip_direction_local",
		"tip_direction_origin_id",
		Vector3.ZERO,
		tip_direction_origin_id
	)
	if local_tip_direction.length_squared() > 0.000001:
		return (held_item.global_basis * local_tip_direction.normalized()).normalized()
	var grip_axis_local: Vector3 = Vector3.ZERO
	var grip_axis_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	if grip_center != null:
		grip_axis_origin_id = _resolve_origin_meta_value(
			grip_center,
			"grip_shell_major_axis_origin_id",
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		)
		grip_axis_local = _get_origin_tracked_vector3_meta(
			grip_center,
			"grip_shell_major_axis_local",
			"grip_shell_major_axis_origin_id",
			Vector3.ZERO,
			grip_axis_origin_id
		)
	if grip_axis_local.length_squared() <= 0.000001:
		grip_axis_origin_id = _resolve_origin_meta_value(
			held_item,
			"primary_grip_slide_axis_origin_id",
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		)
		grip_axis_local = _get_origin_tracked_vector3_meta(
			held_item,
			"primary_grip_slide_axis_local",
			"primary_grip_slide_axis_origin_id",
			Vector3.ZERO,
			grip_axis_origin_id
		)
	if grip_axis_local.length_squared() <= 0.000001:
		grip_axis_origin_id = tip_direction_origin_id
		grip_axis_local = local_tip_direction
	if grip_axis_local.length_squared() <= 0.000001:
		return Vector3.ZERO
	var grip_axis_state := {
		"grip_axis_local": grip_axis_local.normalized(),
		"grip_axis_origin_id": grip_axis_origin_id,
	}
	grip_axis_origin_id = _resolve_origin_tracked_state_origin_id(
		grip_axis_state,
		"grip_axis_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	grip_axis_local = _get_origin_tracked_vector3_state(
		grip_axis_state,
		"grip_axis_local",
		"grip_axis_origin_id",
		Vector3.FORWARD,
		grip_axis_origin_id
	)
	var tip_direction_alignment_origin_id: StringName = tip_direction_origin_id
	var tip_direction_alignment_state := {
		"tip_direction_alignment_local": local_tip_direction,
		"tip_direction_alignment_origin_id": tip_direction_alignment_origin_id,
	}
	var tip_direction_alignment_local: Vector3 = _get_origin_tracked_vector3_state(
		tip_direction_alignment_state,
		"tip_direction_alignment_local",
		"tip_direction_alignment_origin_id",
		Vector3.ZERO,
		tip_direction_alignment_origin_id
	)
	tip_direction_alignment_origin_id = _resolve_origin_tracked_state_origin_id(
		tip_direction_alignment_state,
		"tip_direction_alignment_origin_id",
		tip_direction_alignment_origin_id
	)
	var grip_axis_alignment_origin_id: StringName = grip_axis_origin_id
	var grip_axis_alignment_state := {
		"grip_axis_alignment_local": grip_axis_local,
		"grip_axis_alignment_origin_id": grip_axis_alignment_origin_id,
	}
	var grip_axis_alignment_local: Vector3 = _get_origin_tracked_vector3_state(
		grip_axis_alignment_state,
		"grip_axis_alignment_local",
		"grip_axis_alignment_origin_id",
		Vector3.FORWARD,
		grip_axis_alignment_origin_id
	)
	tip_direction_alignment_origin_id = _resolve_origin_tracked_state_origin_id(
		tip_direction_alignment_state,
		"tip_direction_alignment_origin_id",
		tip_direction_alignment_origin_id
	)
	if tip_direction_alignment_local.length_squared() > 0.000001 and grip_axis_alignment_local.dot(tip_direction_alignment_local.normalized()) < 0.0:
		grip_axis_alignment_local = -grip_axis_alignment_local
	return (held_item.global_basis * grip_axis_alignment_local).normalized()

func _resolve_grip_minor_axis_world(finger_guide_node: Node3D, axis_id: StringName) -> Vector3:
	if finger_guide_node == null:
		return Vector3.ZERO
	var grip_center: Node3D = finger_guide_node.get_node_or_null("GripShellCenter") as Node3D
	if grip_center == null:
		return Vector3.ZERO
	var meta_name: String = "grip_shell_minor_axis_b_local" if axis_id == &"b" else "grip_shell_minor_axis_a_local"
	var origin_meta_name: String = "grip_shell_minor_axis_b_origin_id" if axis_id == &"b" else "grip_shell_minor_axis_a_origin_id"
	var minor_axis_local: Vector3 = _get_origin_tracked_vector3_meta(
		grip_center,
		meta_name,
		origin_meta_name,
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	if minor_axis_local.length_squared() <= 0.000001:
		return Vector3.ZERO
	return (grip_center.global_basis * minor_axis_local.normalized()).normalized()

func _resolve_signed_contact_axis_weapon_hold_basis(
	humanoid_rig: Node3D,
	slot_id: StringName,
	grip_style_mode: StringName,
	weapon_tip_local: Vector3,
	weapon_tip_origin_id: StringName,
	primary_grip_contact_local: Vector3,
	primary_grip_contact_origin_id: StringName,
	fallback_basis: Basis
) -> Basis:
	var tip_axis_origin_id: StringName = weapon_tip_origin_id
	if tip_axis_origin_id == StringName():
		tip_axis_origin_id = primary_grip_contact_origin_id
	if tip_axis_origin_id == StringName():
		tip_axis_origin_id = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var tip_axis_state := {
		"tip_axis_local": weapon_tip_local - primary_grip_contact_local,
		"tip_axis_origin_id": tip_axis_origin_id,
	}
	var local_tip_axis: Vector3 = _get_origin_tracked_vector3_state(
		tip_axis_state,
		"tip_axis_local",
		"tip_axis_origin_id",
		Vector3.ZERO,
		tip_axis_origin_id
	)
	if local_tip_axis.length_squared() <= 0.000001:
		return fallback_basis.orthonormalized()
	local_tip_axis = local_tip_axis.normalized()
	var hand_anchor: Node3D = get_hand_anchor(humanoid_rig, slot_id)
	var target_contact_axis_state: Dictionary = _resolve_slot_contact_axis_state(humanoid_rig, slot_id)
	var target_contact_axis_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		target_contact_axis_state,
		"contact_axis_origin_id",
		CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	)
	var target_contact_axis_local: Vector3 = _get_origin_tracked_vector3_state(
		target_contact_axis_state,
		"contact_axis_local",
		"contact_axis_origin_id",
		Vector3.RIGHT,
		target_contact_axis_origin_id
	)
	if grip_style_mode == CraftedItemWIP.GRIP_REVERSE:
		target_contact_axis_local = -target_contact_axis_local
	var target_anchor_axis: Vector3 = target_contact_axis_local
	if hand_anchor != null:
		target_anchor_axis = (hand_anchor.transform.basis.inverse() * target_contact_axis_local).normalized()
	if target_anchor_axis.length_squared() <= 0.000001:
		target_anchor_axis = target_contact_axis_local
	var up_reference: Vector3 = fallback_basis.y.normalized()
	var tip_axis_alignment_origin_id: StringName = tip_axis_origin_id
	var tip_axis_alignment_state := {
		"tip_axis_alignment_local": local_tip_axis,
		"tip_axis_alignment_origin_id": tip_axis_alignment_origin_id,
	}
	var tip_axis_alignment_local: Vector3 = _get_origin_tracked_vector3_state(
		tip_axis_alignment_state,
		"tip_axis_alignment_local",
		"tip_axis_alignment_origin_id",
		Vector3.FORWARD,
		tip_axis_alignment_origin_id
	)
	return _build_basis_aligning_local_axis(tip_axis_alignment_local, target_anchor_axis.normalized(), up_reference)

func _resolve_hand_mount_origin_local(
	target_contact_local: Vector3,
	target_contact_origin_id: StringName,
	primary_grip_contact_local: Vector3,
	primary_grip_contact_origin_id: StringName,
	mount_basis: Basis
) -> Vector3:
	var mount_origin_origin_id: StringName = target_contact_origin_id
	if mount_origin_origin_id == StringName():
		mount_origin_origin_id = primary_grip_contact_origin_id
	if mount_origin_origin_id == StringName():
		mount_origin_origin_id = CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	var mount_origin_local: Vector3 = target_contact_local - mount_basis.orthonormalized() * primary_grip_contact_local
	var mount_origin_state := {
		"mount_origin_local": mount_origin_local,
		"mount_origin_origin_id": mount_origin_origin_id,
	}
	return _get_origin_tracked_vector3_state(
		mount_origin_state,
		"mount_origin_local",
		"mount_origin_origin_id",
		mount_origin_local,
		mount_origin_origin_id
	)

func _build_basis_aligning_local_axis(local_axis: Vector3, target_axis: Vector3, up_reference: Vector3) -> Basis:
	var source_axis: Vector3 = local_axis.normalized()
	var resolved_target_axis: Vector3 = target_axis.normalized()
	if source_axis.length_squared() <= 0.000001 or resolved_target_axis.length_squared() <= 0.000001:
		return Basis.IDENTITY
	var rotation_axis: Vector3 = source_axis.cross(resolved_target_axis)
	var rotation_angle: float = 0.0
	if rotation_axis.length_squared() <= 0.000001:
		if source_axis.dot(resolved_target_axis) < 0.0:
			rotation_axis = _resolve_perpendicular_axis(source_axis, up_reference)
			rotation_angle = PI
		else:
			return Basis.IDENTITY
	else:
		rotation_axis = rotation_axis.normalized()
		rotation_angle = source_axis.angle_to(resolved_target_axis)
	var aligned_basis: Basis = Basis(rotation_axis, rotation_angle).orthonormalized()
	var aligned_up: Vector3 = aligned_basis * Vector3.UP
	var roll_correction_axis: Vector3 = resolved_target_axis
	var projected_current_up: Vector3 = aligned_up - roll_correction_axis * aligned_up.dot(roll_correction_axis)
	var projected_target_up: Vector3 = up_reference - roll_correction_axis * up_reference.dot(roll_correction_axis)
	if projected_current_up.length_squared() > 0.000001 and projected_target_up.length_squared() > 0.000001:
		projected_current_up = projected_current_up.normalized()
		projected_target_up = projected_target_up.normalized()
		var roll_angle: float = atan2(
			roll_correction_axis.dot(projected_current_up.cross(projected_target_up)),
			clampf(projected_current_up.dot(projected_target_up), -1.0, 1.0)
		)
		aligned_basis = (Basis(roll_correction_axis, roll_angle) * aligned_basis).orthonormalized()
	return aligned_basis

func _build_basis_from_z_and_up(z_axis_world: Vector3, up_reference_world: Vector3) -> Basis:
	var z_axis: Vector3 = z_axis_world.normalized()
	if z_axis.length_squared() <= 0.000001:
		return Basis.IDENTITY
	var y_axis: Vector3 = up_reference_world - z_axis * up_reference_world.dot(z_axis)
	if y_axis.length_squared() <= 0.000001:
		y_axis = _resolve_perpendicular_axis(z_axis, Vector3.UP)
	y_axis = y_axis.normalized()
	var x_axis: Vector3 = y_axis.cross(z_axis).normalized()
	if x_axis.length_squared() <= 0.000001:
		x_axis = _resolve_perpendicular_axis(z_axis, Vector3.RIGHT)
	y_axis = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()

func _build_basis_from_y_and_x(y_axis_world: Vector3, x_reference_world: Vector3) -> Basis:
	var y_axis: Vector3 = y_axis_world.normalized()
	if y_axis.length_squared() <= 0.000001:
		return Basis.IDENTITY
	var x_axis: Vector3 = x_reference_world - y_axis * x_reference_world.dot(y_axis)
	if x_axis.length_squared() <= 0.000001:
		x_axis = _resolve_perpendicular_axis(y_axis, Vector3.RIGHT)
	x_axis = x_axis.normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	if z_axis.length_squared() <= 0.000001:
		z_axis = _resolve_perpendicular_axis(y_axis, Vector3.FORWARD)
	x_axis = y_axis.cross(z_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()

func _build_basis_from_x_and_y(x_axis_world: Vector3, y_reference_world: Vector3) -> Basis:
	var x_axis: Vector3 = x_axis_world.normalized()
	if x_axis.length_squared() <= 0.000001:
		return Basis.IDENTITY
	var y_axis: Vector3 = y_reference_world - x_axis * y_reference_world.dot(x_axis)
	if y_axis.length_squared() <= 0.000001:
		y_axis = Vector3.UP - x_axis * Vector3.UP.dot(x_axis)
	if y_axis.length_squared() <= 0.000001:
		y_axis = Vector3.FORWARD - x_axis * Vector3.FORWARD.dot(x_axis)
	if y_axis.length_squared() <= 0.000001:
		y_axis = _resolve_perpendicular_axis(x_axis, Vector3.UP)
	if y_axis.length_squared() <= 0.000001:
		return Basis.IDENTITY
	y_axis = y_axis.normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	if z_axis.length_squared() <= 0.000001:
		return Basis.IDENTITY
	y_axis = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()

func _resolve_anatomical_hand_y_axis_world(
	humanoid_rig: Node3D,
	slot_id: StringName,
	fallback_reference_world: Vector3
) -> Vector3:
	if humanoid_rig != null and humanoid_rig.has_method("resolve_hand_anatomical_y_axis_world"):
		var resolved_axis: Vector3 = humanoid_rig.call("resolve_hand_anatomical_y_axis_world", slot_id) as Vector3
		if resolved_axis.length_squared() > 0.000001:
			return resolved_axis.normalized()
	var hand_anchor: Node3D = get_hand_anchor(humanoid_rig, slot_id)
	if hand_anchor != null and is_instance_valid(hand_anchor):
		var hand_axis: Vector3 = hand_anchor.global_basis.y.normalized()
		if hand_axis.length_squared() > 0.000001:
			return hand_axis
	var character_basis: Basis = humanoid_rig.global_basis.orthonormalized() if humanoid_rig != null else Basis.IDENTITY
	var fallback_axis: Vector3 = character_basis.y - fallback_reference_world * character_basis.y.dot(fallback_reference_world)
	if fallback_axis.length_squared() <= 0.000001:
		fallback_axis = character_basis.z
	if fallback_axis.length_squared() <= 0.000001:
		fallback_axis = Vector3.UP
	return fallback_axis.normalized()

func _resolve_perpendicular_axis(axis: Vector3, preferred_axis: Vector3) -> Vector3:
	var resolved_axis: Vector3 = axis.normalized()
	var perpendicular: Vector3 = preferred_axis - resolved_axis * preferred_axis.dot(resolved_axis)
	if perpendicular.length_squared() <= 0.000001:
		perpendicular = Vector3.RIGHT - resolved_axis * Vector3.RIGHT.dot(resolved_axis)
	if perpendicular.length_squared() <= 0.000001:
		perpendicular = Vector3.UP - resolved_axis * Vector3.UP.dot(resolved_axis)
	if perpendicular.length_squared() <= 0.000001:
		perpendicular = Vector3.FORWARD
	return perpendicular.normalized()

func _normalize_hand_slot_id(slot_id: StringName) -> StringName:
	return &"hand_left" if slot_id == &"hand_left" else &"hand_right"

func _resolve_support_slot_id(dominant_slot_id: StringName) -> StringName:
	return &"hand_right" if _normalize_hand_slot_id(dominant_slot_id) == &"hand_left" else &"hand_left"

func sync_rig_weapon_guidance(
	humanoid_rig: Node3D,
	held_item_nodes: Dictionary,
	weapons_drawn: bool,
	_resolved_equipment_state
) -> void:
	if humanoid_rig == null:
		return
	clear_rig_weapon_contact_guidance(humanoid_rig)
	if not weapons_drawn:
		return

	var right_item: Node3D = held_item_nodes.get(&"hand_right") as Node3D
	var left_item: Node3D = held_item_nodes.get(&"hand_left") as Node3D
	if right_item != null:
		right_item.set_meta("dominant_contact_slot_id", &"hand_right")
		sync_single_weapon_contact_guidance(
			humanoid_rig,
			right_item,
			&"hand_right",
			left_item == null,
			left_item == null,
			false,
			true,
			true,
			left_item == null
		)
	if left_item != null:
		left_item.set_meta("dominant_contact_slot_id", &"hand_left")
		sync_single_weapon_contact_guidance(
			humanoid_rig,
			left_item,
			&"hand_left",
			right_item == null,
			right_item == null,
			false,
			true,
			true,
			right_item == null
		)

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
	equipped_item_node.set_meta(
		EQUIPPED_VISUAL_ANCHOR_ORIGIN_META,
		_resolve_equipped_visual_anchor_origin_id(weapons_drawn)
	)
	if not weapons_drawn:
		apply_station_stow_transform(equipped_item_node, saved_wip, visual_anchor)
	held_item_nodes[slot_id] = equipped_item_node

func apply_station_stow_transform(
	held_item: Node3D,
	saved_wip: CraftedItemWIP,
	stow_anchor: Node3D = null
) -> bool:
	if held_item == null or saved_wip == null:
		return false
	var anchor_node: Node3D = stow_anchor if stow_anchor != null else (held_item.get_parent() as Node3D)
	if anchor_node == null:
		return false
	var noncombat_idle_draft: CombatAnimationDraft = _resolve_station_noncombat_idle_draft(saved_wip)
	if noncombat_idle_draft == null:
		held_item.set_meta("station_stow_motion_node_applied", false)
		return false
	noncombat_idle_draft.ensure_minimum_baseline_nodes()
	if noncombat_idle_draft.motion_node_chain.is_empty():
		held_item.set_meta("station_stow_motion_node_applied", false)
		return false
	var stow_motion_node: CombatAnimationMotionNode = noncombat_idle_draft.motion_node_chain[0] as CombatAnimationMotionNode
	if stow_motion_node == null:
		held_item.set_meta("station_stow_motion_node_applied", false)
		return false
	_ensure_origin_meta(held_item, "weapon_tip_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	_ensure_origin_meta(held_item, "weapon_pommel_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	var local_tip: Vector3 = _get_weapon_tip_meta(held_item)
	var local_tip_origin_id: StringName = _resolve_origin_meta_value(held_item, "weapon_tip_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	var local_pommel: Vector3 = _get_weapon_pommel_meta(held_item)
	var local_pommel_origin_id: StringName = _resolve_origin_meta_value(held_item, "weapon_pommel_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	if local_tip.is_equal_approx(local_pommel):
		held_item.set_meta("station_stow_motion_node_applied", false)
		return false
	if stow_motion_node.tip_position_local.is_equal_approx(stow_motion_node.pommel_position_local):
		held_item.set_meta("station_stow_motion_node_applied", false)
		return false
	var stow_contact_ratio: float = CombatAnimationDraftScript.normalize_stow_contact_ratio(noncombat_idle_draft.stow_contact_ratio)
	var stow_segment: Dictionary = _resolve_station_stow_anchor_local_segment(stow_motion_node, stow_contact_ratio)
	var stow_tip_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		stow_segment,
		"tip_position_origin_id",
		CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	)
	var stow_tip_local: Vector3 = _get_origin_tracked_vector3_state(
		stow_segment,
		"tip_position_local",
		"tip_position_origin_id",
		stow_motion_node.tip_position_local,
		stow_tip_origin_id
	)
	var stow_pommel_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		stow_segment,
		"pommel_position_origin_id",
		CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	)
	var stow_pommel_local: Vector3 = _get_origin_tracked_vector3_state(
		stow_segment,
		"pommel_position_local",
		"pommel_position_origin_id",
		stow_motion_node.pommel_position_local,
		stow_pommel_origin_id
	)
	var local_axis: Vector3 = (local_tip - local_pommel).normalized()
	var local_axis_origin_id: StringName = local_tip_origin_id
	var local_up_reference_state: Dictionary = _resolve_weapon_local_up_reference_state(held_item, local_axis, local_axis_origin_id)
	var local_up_reference_origin_id: StringName = _resolve_origin_tracked_state_origin_id(
		local_up_reference_state,
		"up_reference_origin_id",
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var local_up_reference: Vector3 = _get_origin_tracked_vector3_state(
		local_up_reference_state,
		"local_up_reference",
		"up_reference_origin_id",
		Vector3.UP,
		local_up_reference_origin_id
	)
	var stow_authoring_basis: Basis = _resolve_station_stow_authoring_basis(anchor_node)
	var stow_anchor_world: Vector3 = anchor_node.global_position
	var authored_tip_world: Vector3 = stow_anchor_world + stow_authoring_basis * stow_tip_local
	var authored_pommel_world: Vector3 = stow_anchor_world + stow_authoring_basis * stow_pommel_local
	var authored_axis_world: Vector3 = authored_tip_world - authored_pommel_world
	if authored_axis_world.length_squared() <= 0.000001:
		authored_axis_world = stow_authoring_basis.z
	var weapon_segment_length: float = local_tip.distance_to(local_pommel)
	var resolved_tip_world: Vector3 = authored_pommel_world + authored_axis_world.normalized() * weapon_segment_length
	held_item.set_meta("station_stow_segment_tip_origin_id", local_tip_origin_id)
	held_item.set_meta("station_stow_segment_pommel_origin_id", local_pommel_origin_id)
	held_item.set_meta("station_stow_segment_up_reference_origin_id", local_up_reference_origin_id)
	var solved_transform: Transform3D = weapon_frame_solver.solve_transform_from_segment(
		local_tip,
		local_pommel,
		resolved_tip_world,
		authored_pommel_world,
		local_up_reference,
		stow_authoring_basis,
		stow_motion_node.weapon_orientation_degrees,
		stow_motion_node.weapon_roll_degrees,
		local_tip_origin_id,
		local_pommel_origin_id,
		local_up_reference_origin_id
	)
	held_item.global_transform = solved_transform
	held_item.set_meta("station_stow_motion_node_applied", true)
	held_item.set_meta("station_stow_anchor_mode", CombatAnimationDraftScript.normalize_stow_anchor_mode(noncombat_idle_draft.stow_anchor_mode))
	held_item.set_meta("station_stow_origin_id", CombatOriginRecordScript.ORIGIN_NONCOMBAT_STOW)
	held_item.set_meta("station_stow_anchor_origin_id", CombatOriginRecordScript.ORIGIN_STOW_ANCHOR)
	held_item.set_meta("station_stow_contact_ratio", stow_contact_ratio)
	_set_origin_tracked_vector3_meta(
		held_item,
		"station_stow_requested_tip_position_local",
		"station_stow_requested_tip_position_origin_id",
		stow_tip_local,
		stow_tip_origin_id
	)
	_set_origin_tracked_vector3_meta(
		held_item,
		"station_stow_requested_pommel_position_local",
		"station_stow_requested_pommel_position_origin_id",
		stow_pommel_local,
		stow_pommel_origin_id
	)
	_set_origin_tracked_vector3_meta(
		held_item,
		"station_stow_tip_position_local",
		"station_stow_tip_position_origin_id",
		anchor_node.to_local(resolved_tip_world),
		CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	)
	_set_origin_tracked_vector3_meta(
		held_item,
		"station_stow_pommel_position_local",
		"station_stow_pommel_position_origin_id",
		anchor_node.to_local(authored_pommel_world),
		CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	)
	held_item.set_meta("station_stow_weapon_orientation_degrees", stow_motion_node.weapon_orientation_degrees)
	held_item.set_meta("station_stow_weapon_roll_degrees", stow_motion_node.weapon_roll_degrees)
	return true

func _resolve_weapon_local_up_reference(held_item: Node3D, local_axis: Vector3) -> Vector3:
	var axis_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var up_reference_state: Dictionary = _resolve_weapon_local_up_reference_state(
		held_item,
		local_axis,
		axis_origin_id
	)
	return _get_origin_tracked_vector3_state(
		up_reference_state,
		"local_up_reference",
		"up_reference_origin_id",
		Vector3.UP,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)

func _resolve_weapon_local_up_reference_state(
	held_item: Node3D,
	local_axis: Vector3,
	local_axis_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
) -> Dictionary:
	var resolved_local_axis_origin_id: StringName = local_axis_origin_id
	if resolved_local_axis_origin_id == StringName():
		resolved_local_axis_origin_id = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var basis_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_basis_anchor(held_item)
	var local_up_reference: Vector3 = basis_anchor.transform.basis.y if basis_anchor != null else Vector3.UP
	local_up_reference = local_up_reference - local_axis * local_up_reference.dot(local_axis)
	if local_up_reference.length_squared() <= 0.000001:
		local_up_reference = Vector3.UP - local_axis * Vector3.UP.dot(local_axis)
	if local_up_reference.length_squared() <= 0.000001:
		local_up_reference = Vector3.RIGHT - local_axis * Vector3.RIGHT.dot(local_axis)
	return {
		"local_up_reference": local_up_reference.normalized(),
		"up_reference_origin_id": CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
		"local_axis_origin_id": resolved_local_axis_origin_id,
	}

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
