extends SceneTree

const PlayerEquipmentStateScript = preload("res://core/models/player_equipment_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")
const CombatCollisionLegalityResolverScript = preload("res://runtime/combat/combat_collision_legality_resolver.gd")
const HandTargetConstraintSolverScript = preload("res://runtime/player/hand_target_constraint_solver.gd")
const MainScene = preload("res://node_3d.tscn")

const TARGET_PROJECT_NAME := "Test sword for animations"
const TARGET_SLOT_ID: StringName = &"skill_slot_1"
const DOMINANT_EQUIPMENT_SLOT_ID: StringName = &"hand_right"
const RESULT_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/runtime_skill_slot_1_posture_weapon_legality_30s_2026-05-03.log"
const SAMPLE_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/runtime_skill_slot_1_posture_weapon_legality_30s_samples_2026-05-03.csv"
const TEMP_LIBRARY_SAVE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_runtime_skill_slot_1_posture_weapon_legality_library.tres"
const TEMP_SKILL_SLOT_SAVE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_runtime_skill_slot_1_posture_weapon_legality_slots.tres"
const TEMP_EQUIPMENT_SAVE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_runtime_skill_slot_1_posture_weapon_legality_equipment.tres"

const OBSERVE_SECONDS := 30.0
const ENDPOINT_ERROR_LIMIT_METERS := 0.02
const DOMINANT_GRIP_TARGET_ERROR_LIMIT_METERS := 0.04
const DOMINANT_HAND_IK_ERROR_LIMIT_METERS := 0.10
const FINGER_CONTACT_DISTANCE_LIMIT_METERS := 0.08

const FINGER_END_BONES := {
	"right_thumb": "CC_Base_R_Thumb3",
	"right_index": "CC_Base_R_Index3",
	"right_mid": "CC_Base_R_Mid3",
	"right_ring": "CC_Base_R_Ring3",
	"right_pinky": "CC_Base_R_Pinky3",
	"left_thumb": "CC_Base_L_Thumb3",
	"left_index": "CC_Base_L_Index3",
	"left_mid": "CC_Base_L_Mid3",
	"left_ring": "CC_Base_L_Ring3",
	"left_pinky": "CC_Base_L_Pinky3",
}

var result_lines: PackedStringArray = []
var sample_lines: PackedStringArray = []
var scalar_stats: Dictionary = {}
var previous_scalars: Dictionary = {}
var first_illegal_weapon_body_sample: Dictionary = {}
var first_illegal_body_self_sample: Dictionary = {}
var current_record_sample_index: int = -1

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/DEBUG-LOGS")
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	_reset_outputs()
	result_lines.append("diagnostic=runtime_skill_slot_1_posture_weapon_legality")
	result_lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)
	result_lines.append("target_slot_id=%s" % String(TARGET_SLOT_ID))
	result_lines.append("dominant_equipment_slot_id=%s" % String(DOMINANT_EQUIPMENT_SLOT_ID))
	result_lines.append("observe_seconds=%.3f" % OBSERVE_SECONDS)

	var source_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var source_wip: CraftedItemWIP = _find_saved_wip_by_project_name(source_library, TARGET_PROJECT_NAME)
	result_lines.append("source_library_loaded=%s" % str(source_library != null))
	result_lines.append("source_wip_found=%s" % str(source_wip != null))
	if source_wip == null:
		_write_outputs()
		quit(1)
		return

	var diagnostic_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	diagnostic_wip.wip_id = StringName("%s_runtime_legality_diagnostic" % String(source_wip.wip_id))
	diagnostic_wip.forge_project_name = "%s Runtime Legality Diagnostic" % source_wip.forge_project_name
	diagnostic_wip.ensure_combat_animation_station_state()
	var temp_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	temp_library.save_file_path = TEMP_LIBRARY_SAVE_PATH
	temp_library.saved_wips.clear()
	temp_library.saved_wips.append(diagnostic_wip)
	temp_library.selected_wip_id = diagnostic_wip.wip_id
	temp_library.persist()

	var equipment_state: PlayerEquipmentState = PlayerEquipmentStateScript.new()
	equipment_state.save_file_path = TEMP_EQUIPMENT_SAVE_PATH
	equipment_state.equipped_slots.clear()
	var equipped_entry = equipment_state.equip_forge_test_wip(DOMINANT_EQUIPMENT_SLOT_ID, diagnostic_wip)

	var skill_slot_state: PlayerSkillSlotState = PlayerSkillSlotStateScript.new()
	skill_slot_state.save_file_path = TEMP_SKILL_SLOT_SAVE_PATH
	skill_slot_state.slot_assignments.clear()

	var root_scene: Node = MainScene.instantiate()
	var player: PlayerController3D = root_scene.get_node_or_null("PlayerCharacter") as PlayerController3D
	if player == null:
		player = _find_player_controller(root_scene)
	result_lines.append("main_scene_loaded=%s" % str(root_scene != null))
	result_lines.append("main_scene_player_found=%s" % str(player != null))
	if player == null:
		_write_outputs()
		quit(1)
		return

	player.equipment_state = equipment_state
	player.forge_wip_library_state = temp_library
	player.player_skill_slot_state = skill_slot_state
	player.weapons_drawn = true
	player.velocity = Vector3.ZERO
	root.add_child(root_scene)
	await _wait_frames(8)
	await _wait_until_player_grounded(player, 90)
	player.call("_sync_equipped_test_meshes")
	player.call("_sync_equipped_skill_slots")
	await _wait_frames(6)
	await _wait_physics_frames(2)

	result_lines.append("source_wip_id=%s" % String(source_wip.wip_id))
	result_lines.append("diagnostic_wip_id=%s" % String(diagnostic_wip.wip_id))
	result_lines.append("diagnostic_save_path=%s" % TEMP_LIBRARY_SAVE_PATH)
	result_lines.append("equipment_entry_exists=%s" % str(equipped_entry != null))
	result_lines.append("main_scene_player_path=%s" % str(player.get_path()))
	result_lines.append("held_item_count=%d" % player.held_item_nodes.size())
	result_lines.append("held_item_slots=%s" % ", ".join(_string_name_keys(player.held_item_nodes)))
	result_lines.append("player_grounded_before_activation=%s" % str(player.is_on_floor()))
	result_lines.append("player_global_position_before_activation=%s" % str(player.global_position))
	result_lines.append_array(_build_seating_debug_lines(player, "pre_activation"))

	var preview_result: Dictionary = player.preview_runtime_skill_slot_activation(TARGET_SLOT_ID)
	result_lines.append("preview_success=%s" % str(bool(preview_result.get("success", false))))
	result_lines.append("preview_message=%s" % String(preview_result.get("message", "")))
	result_lines.append("preview_source_weapon_name=%s" % String(preview_result.get("source_weapon_name", "")))
	result_lines.append("preview_motion_node_count=%d" % int(preview_result.get("motion_node_count", 0)))
	result_lines.append("preview_source_equipment_slot_id=%s" % String(preview_result.get("source_equipment_slot_id", StringName())))

	player.call("_activate_skill_slot", TARGET_SLOT_ID)
	await _wait_physics_frames(1)
	await _wait_frames(1)
	var activation_result: Dictionary = player.get_last_skill_activation_result()
	var runtime_debug_initial: Dictionary = player.get_runtime_skill_playback_debug_state()
	var clip_debug: Dictionary = runtime_debug_initial.get("runtime_clip_debug_state", {}) as Dictionary
	result_lines.append("activation_success=%s" % str(bool(activation_result.get("success", false))))
	result_lines.append("runtime_playback_started=%s" % str(bool(activation_result.get("runtime_playback_started", false))))
	result_lines.append("runtime_playback_message=%s" % String(activation_result.get("runtime_playback_message", "")))
	result_lines.append("activation_source_equipment_slot_id=%s" % String(activation_result.get("source_equipment_slot_id", StringName())))
	result_lines.append("runtime_active_initial=%s" % str(bool(runtime_debug_initial.get("active", false))))
	result_lines.append("runtime_clip_active_initial=%s" % str(bool(runtime_debug_initial.get("runtime_clip_active", false))))
	result_lines.append("runtime_clip_frame_count=%d" % int(clip_debug.get("frame_count", 0)))
	result_lines.append("runtime_clip_duration_seconds=%.4f" % float(clip_debug.get("total_duration_seconds", 0.0)))
	result_lines.append("runtime_compile_diagnostic_count=%d" % int((runtime_debug_initial.get("runtime_compile_diagnostics", []) as Array).size()))
	result_lines.append("runtime_compile_degraded_node_count=%d" % int(runtime_debug_initial.get("runtime_compile_degraded_node_count", 0)))
	result_lines.append("runtime_compile_retargeted_count=%d" % int(runtime_debug_initial.get("runtime_compile_retargeted_count", 0)))

	var elapsed: float = 0.0
	var sample_index: int = 0
	while elapsed <= OBSERVE_SECONDS:
		_sample_runtime(player, sample_index, elapsed)
		if sample_index == 0:
			result_lines.append_array(_build_seating_debug_lines(player, "active_sample_0"))
		await physics_frame
		await process_frame
		elapsed += 1.0 / 60.0
		sample_index += 1

	var final_runtime_debug: Dictionary = player.get_runtime_skill_playback_debug_state()
	var final_idle_debug: Dictionary = player.get_runtime_idle_pose_debug_state()
	var final_grip_debug: Dictionary = _get_grip_debug(player)
	var final_body_self: Dictionary = _get_body_self_debug(player)
	var final_body_clearance: Dictionary = _get_body_clearance_debug(player)
	result_lines.append("sample_count=%d" % sample_index)
	result_lines.append("runtime_active_final=%s" % str(bool(final_runtime_debug.get("active", false))))
	result_lines.append("runtime_idle_active_final=%s" % str(bool(final_idle_debug.get("active", false))))
	result_lines.append("runtime_finished_pending_final=%s" % str(bool(final_runtime_debug.get("playback_finished_pending", false))))
	result_lines.append("hidden_bridge_state_final=%s" % str(final_runtime_debug.get("hidden_bridge_state", {})))
	result_lines.append("player_grounded_final=%s" % str(player.is_on_floor()))
	result_lines.append("player_global_position_final=%s" % str(player.global_position))
	result_lines.append("upper_body_authoring_active_final=%s" % str(bool((_get_upper_body_state(player).get("active", false)))))
	result_lines.append("final_body_clearance_proxy_source=%s" % str(final_body_clearance.get("body_clearance_proxy_source", StringName())))
	result_lines.append("final_body_clearance_attachment_count=%d" % int(final_body_clearance.get("body_clearance_attachment_count", 0)))
	result_lines.append("final_body_self_legal=%s" % str(bool(final_body_self.get("legal", true))))
	result_lines.append("final_body_self_illegal_pair_count=%d" % int(final_body_self.get("illegal_pair_count", 0)))
	result_lines.append("final_body_self_first_illegal_pair=%s" % str(final_body_self.get("first_illegal_pair", {})))
	result_lines.append("final_right_hand_ik_target_distance_meters=%.6f" % float(final_grip_debug.get("right_hand_ik_target_distance_meters", -1.0)))
	result_lines.append("final_left_hand_ik_target_distance_meters=%.6f" % float(final_grip_debug.get("left_hand_ik_target_distance_meters", -1.0)))
	result_lines.append_array(_build_stat_lines())
	result_lines.append_array(_build_legality_summary())
	_write_outputs()
	quit(0 if _all_core_legality_checks_passed() else 1)

func _reset_outputs() -> void:
	sample_lines.clear()
	sample_lines.append(
		"sample,seconds,player_grounded,runtime_active,runtime_clip_active,idle_active,idle_clip_active,hidden_bridge_active,hidden_bridge_kind,entry_bridge_current,recovery_bridge_current,direct_authoring_solver_mode,right_arm_ik_active,left_arm_ik_active,two_hand,grip_style,dominant_slot,tip_pose_error_m,pommel_pose_error_m,tip_clip_to_pose_error_m,pommel_clip_to_pose_error_m,dominant_grip_to_ik_m,dominant_hand_ik_error_m,dominant_finger_distance_m,dominant_finger_readiness,body_self_legal,body_self_illegal_count,body_self_min_clearance_m,weapon_body_legal,weapon_body_illegal_samples,weapon_body_region,weapon_body_sample,weapon_body_clearance_m,hand_y_forearm_dot,hand_x_tip_plane_dot,tip_world,pommel_world,primary_anchor_world,dominant_ik_world,dominant_hand_world"
	)

func _sample_runtime(player: PlayerController3D, sample_index: int, elapsed_seconds: float) -> void:
	current_record_sample_index = sample_index
	var runtime_debug: Dictionary = player.get_runtime_skill_playback_debug_state()
	var idle_debug: Dictionary = player.get_runtime_idle_pose_debug_state()
	var pose_state: Dictionary = runtime_debug.get("last_runtime_pose_state", {}) as Dictionary
	var active: bool = bool(runtime_debug.get("active", false))
	var runtime_clip_active: bool = bool(runtime_debug.get("runtime_clip_active", false))
	var idle_active: bool = bool(idle_debug.get("active", false))
	var idle_clip_active: bool = bool(idle_debug.get("runtime_clip_active", false))
	var hidden_bridge_state: Dictionary = runtime_debug.get("hidden_bridge_state", {}) as Dictionary
	var hidden_bridge_active: bool = bool(hidden_bridge_state.get("active", false))
	var hidden_bridge_kind: StringName = hidden_bridge_state.get("kind", StringName()) as StringName
	var entry_bridge_active: bool = hidden_bridge_active and (hidden_bridge_kind == &"skill_entry" or hidden_bridge_kind == &"skill_interrupt_entry" or hidden_bridge_kind == &"draw_to_combat_idle")
	var recovery_bridge_active: bool = hidden_bridge_active and (hidden_bridge_kind == &"skill_recovery" or hidden_bridge_kind == &"stow_to_noncombat_idle")
	var dominant_slot_id: StringName = runtime_debug.get("dominant_slot_id", DOMINANT_EQUIPMENT_SLOT_ID) as StringName
	if dominant_slot_id == StringName():
		dominant_slot_id = DOMINANT_EQUIPMENT_SLOT_ID
	var held_item: Node3D = player.held_item_nodes.get(dominant_slot_id) as Node3D
	var rig: Node3D = player.humanoid_rig
	var skeleton: Skeleton3D = _get_skeleton(player)
	var chain_player = player.runtime_skill_playback_presenter.chain_player
	var trajectory_transform: Transform3D = _resolve_trajectory_transform(player)
	var local_tip: Vector3 = held_item.get_meta("weapon_tip_local", Vector3.ZERO) as Vector3 if held_item != null else Vector3.ZERO
	var local_pommel: Vector3 = held_item.get_meta("weapon_pommel_local", Vector3.ZERO) as Vector3 if held_item != null else Vector3.ZERO
	var actual_tip_world: Vector3 = held_item.to_global(local_tip) if held_item != null else Vector3.ZERO
	var actual_pommel_world: Vector3 = held_item.to_global(local_pommel) if held_item != null else Vector3.ZERO
	var clip_tip_local: Vector3 = chain_player.current_tip_position if chain_player != null else pose_state.get("tip_position_local", Vector3.ZERO) as Vector3
	var clip_pommel_local: Vector3 = chain_player.current_pommel_position if chain_player != null else pose_state.get("pommel_position_local", Vector3.ZERO) as Vector3
	var pose_tip_local: Vector3 = pose_state.get("tip_position_local", clip_tip_local) as Vector3
	var pose_pommel_local: Vector3 = pose_state.get("pommel_position_local", clip_pommel_local) as Vector3
	var pose_tip_world: Vector3 = pose_state.get("tip_world", trajectory_transform * pose_tip_local) as Vector3
	var pose_pommel_world: Vector3 = pose_state.get("pommel_world", trajectory_transform * pose_pommel_local) as Vector3
	var clip_tip_world: Vector3 = trajectory_transform * clip_tip_local
	var clip_pommel_world: Vector3 = trajectory_transform * clip_pommel_local
	var tip_pose_error: float = actual_tip_world.distance_to(pose_tip_world) if held_item != null else -1.0
	var pommel_pose_error: float = actual_pommel_world.distance_to(pose_pommel_world) if held_item != null else -1.0
	var tip_clip_to_pose_error: float = clip_tip_world.distance_to(pose_tip_world)
	var pommel_clip_to_pose_error: float = clip_pommel_world.distance_to(pose_pommel_world)
	var primary_anchor: Node3D = held_item.get_node_or_null("PrimaryGripAnchor") as Node3D if held_item != null else null
	var primary_guide: Node3D = held_item.get_node_or_null("PrimaryGripGuide") as Node3D if held_item != null else null
	var grip_debug: Dictionary = _get_grip_debug(player)
	var upper_body_state: Dictionary = _get_upper_body_state(player)
	var two_hand: bool = bool(upper_body_state.get("two_hand", false))
	var grip_style: StringName = pose_state.get("preferred_grip_style_mode", StringName()) as StringName
	if grip_style == StringName() and chain_player != null:
		grip_style = chain_player.current_preferred_grip_style_mode
	var dominant_ik_world: Vector3 = _resolve_grip_debug_vector(grip_debug, dominant_slot_id, "hand_ik_target_world")
	var dominant_hand_world: Vector3 = _resolve_grip_debug_vector(grip_debug, dominant_slot_id, "hand_world")
	var dominant_grip_to_ik: float = primary_anchor.global_position.distance_to(dominant_ik_world) if primary_anchor != null else -1.0
	var dominant_hand_ik_error: float = dominant_hand_world.distance_to(dominant_ik_world) if dominant_ik_world.length_squared() > 0.000001 else -1.0
	var dominant_finger_distance: float = _resolve_finger_contact_meta(primary_guide, "finger_grip_contact_distance_meters", -1.0)
	var dominant_finger_readiness: float = _resolve_finger_contact_meta(primary_guide, "finger_grip_contact_readiness", -1.0)
	var body_self: Dictionary = _get_body_self_debug(player)
	var weapon_pose: Dictionary = _evaluate_weapon_body_pose(player, held_item)
	var direct_authoring_solver_mode: bool = bool(grip_debug.get("direct_authoring_solver_mode", false))
	var right_arm_ik_active: bool = bool(grip_debug.get("right_arm_ik_active", false))
	var left_arm_ik_active: bool = bool(grip_debug.get("left_arm_ik_active", false))
	var hand_basis: Basis = _get_bone_world_basis(skeleton, _resolve_hand_bone(dominant_slot_id))
	var hand_y_forearm_dot: float = _resolve_hand_y_forearm_dot(skeleton, dominant_slot_id, hand_basis)
	var hand_x_tip_plane_dot: float = _resolve_hand_x_tip_plane_dot(hand_basis, actual_tip_world - (primary_anchor.global_position if primary_anchor != null else actual_pommel_world))

	if active:
		_record_scalar("active_tip_pose_error_meters", tip_pose_error)
		_record_scalar("active_pommel_pose_error_meters", pommel_pose_error)
		_record_scalar("active_tip_clip_to_pose_error_meters", tip_clip_to_pose_error)
		_record_scalar("active_pommel_clip_to_pose_error_meters", pommel_clip_to_pose_error)
		_record_scalar("active_dominant_grip_to_ik_meters", dominant_grip_to_ik)
		_record_scalar("active_dominant_hand_ik_error_meters", dominant_hand_ik_error)
		_record_scalar("active_dominant_finger_contact_distance_meters", dominant_finger_distance)
		_record_scalar("active_dominant_finger_contact_readiness", dominant_finger_readiness)
		_record_scalar("active_body_self_illegal_pair_count", float(int(body_self.get("illegal_pair_count", 0))))
		_record_scalar("active_body_self_minimum_clearance_meters", float(body_self.get("minimum_clearance_meters", -1.0)))
		_record_scalar("active_weapon_body_illegal_sample_count", float(int(weapon_pose.get("illegal_sample_count", 0))))
		_record_scalar("active_weapon_body_clearance_meters", float(weapon_pose.get("estimated_clearance_meters", -1.0)))
		_record_scalar("active_dominant_hand_y_forearm_dot", hand_y_forearm_dot)
		_record_scalar("active_dominant_hand_x_tip_plane_dot", hand_x_tip_plane_dot)
		for label: String in FINGER_END_BONES.keys():
			var finger_position: Vector3 = _get_bone_world_position(skeleton, String(FINGER_END_BONES.get(label, "")))
			if primary_anchor != null:
				_record_scalar("active_%s_to_primary_anchor_meters" % label, finger_position.distance_to(primary_anchor.global_position))

	if active and not bool(body_self.get("legal", true)) and first_illegal_body_self_sample.is_empty():
		first_illegal_body_self_sample = {
			"sample": sample_index,
			"seconds": elapsed_seconds,
			"state": body_self.duplicate(true),
		}
	if active and not bool(weapon_pose.get("legal", true)) and first_illegal_weapon_body_sample.is_empty():
		first_illegal_weapon_body_sample = {
			"sample": sample_index,
			"seconds": elapsed_seconds,
			"state": weapon_pose.duplicate(true),
		}

	sample_lines.append("%d,%.4f,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%s,%d,%.6f,%s,%d,%s,%s,%.6f,%.6f,%.6f,%s,%s,%s,%s,%s" % [
		sample_index,
		elapsed_seconds,
		str(player.is_on_floor()),
		str(active),
		str(runtime_clip_active),
		str(idle_active),
		str(idle_clip_active),
		str(hidden_bridge_active),
		String(hidden_bridge_kind),
		str(entry_bridge_active),
		str(recovery_bridge_active),
		str(direct_authoring_solver_mode),
		str(right_arm_ik_active),
		str(left_arm_ik_active),
		str(two_hand),
		String(grip_style),
		String(dominant_slot_id),
		tip_pose_error,
		pommel_pose_error,
		tip_clip_to_pose_error,
		pommel_clip_to_pose_error,
		dominant_grip_to_ik,
		dominant_hand_ik_error,
		dominant_finger_distance,
		dominant_finger_readiness,
		str(bool(body_self.get("legal", true))),
		int(body_self.get("illegal_pair_count", 0)),
		float(body_self.get("minimum_clearance_meters", -1.0)),
		str(bool(weapon_pose.get("legal", true))),
		int(weapon_pose.get("illegal_sample_count", 0)),
		String(weapon_pose.get("colliding_body_region", "")).replace(",", ";"),
		String(weapon_pose.get("colliding_sample_name", "")).replace(",", ";"),
		float(weapon_pose.get("estimated_clearance_meters", -1.0)),
		hand_y_forearm_dot,
		hand_x_tip_plane_dot,
		_fmt_vec(actual_tip_world),
		_fmt_vec(actual_pommel_world),
		_fmt_vec(primary_anchor.global_position if primary_anchor != null else Vector3.ZERO),
		_fmt_vec(dominant_ik_world),
		_fmt_vec(dominant_hand_world),
	])

func _evaluate_weapon_body_pose(player: PlayerController3D, held_item: Node3D) -> Dictionary:
	var rig: Node3D = player.humanoid_rig
	var skeleton: Skeleton3D = _get_skeleton(player)
	var body_root: Node3D = rig.call("get_body_restriction_root") as Node3D if rig != null and rig.has_method("get_body_restriction_root") else null
	var constraint_solver = HandTargetConstraintSolverScript.new()
	if body_root != null and skeleton != null:
		constraint_solver.call("sync_body_restriction_root", body_root, skeleton)
	var resolver = CombatCollisionLegalityResolverScript.new()
	return resolver.evaluate_weapon_pose(body_root, held_item, held_item.global_transform if held_item != null else Transform3D.IDENTITY, constraint_solver)

func _get_grip_debug(player: PlayerController3D) -> Dictionary:
	if player == null or player.humanoid_rig == null or not player.humanoid_rig.has_method("get_grip_contact_debug_state"):
		return {}
	return player.humanoid_rig.call("get_grip_contact_debug_state") as Dictionary

func _get_upper_body_state(player: PlayerController3D) -> Dictionary:
	if player == null or player.humanoid_rig == null or not player.humanoid_rig.has_method("get_upper_body_authoring_state"):
		return {}
	return player.humanoid_rig.call("get_upper_body_authoring_state") as Dictionary

func _get_body_self_debug(player: PlayerController3D) -> Dictionary:
	if player == null or player.humanoid_rig == null or not player.humanoid_rig.has_method("get_body_self_collision_debug_state"):
		return {}
	return player.humanoid_rig.call("get_body_self_collision_debug_state") as Dictionary

func _get_body_clearance_debug(player: PlayerController3D) -> Dictionary:
	if player == null or player.humanoid_rig == null or not player.humanoid_rig.has_method("get_body_clearance_debug_state"):
		return {}
	return player.humanoid_rig.call("get_body_clearance_debug_state") as Dictionary

func _resolve_trajectory_transform(player: PlayerController3D) -> Transform3D:
	if player == null or player.runtime_skill_playback_presenter == null:
		return Transform3D.IDENTITY
	var live_pose_presenter = player.runtime_skill_playback_presenter.live_pose_presenter
	if live_pose_presenter == null:
		return Transform3D.IDENTITY
	return live_pose_presenter.call("_resolve_trajectory_authoring_transform", player.humanoid_rig) as Transform3D

func _resolve_grip_debug_vector(grip_debug: Dictionary, slot_id: StringName, suffix: String) -> Vector3:
	var prefix: String = "left" if slot_id == &"hand_left" else "right"
	return grip_debug.get("%s_%s" % [prefix, suffix], Vector3.ZERO) as Vector3

func _resolve_finger_contact_meta(guide_node: Node3D, meta_key: String, default_value: float) -> float:
	if guide_node == null or not is_instance_valid(guide_node):
		return default_value
	if guide_node.has_meta(meta_key):
		return float(guide_node.get_meta(meta_key, default_value))
	var center_node: Node3D = guide_node.get_node_or_null("GripShellCenter") as Node3D
	if center_node != null and center_node.has_meta(meta_key):
		return float(center_node.get_meta(meta_key, default_value))
	return default_value

func _build_stat_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for key: String in scalar_stats.keys():
		var stat: Dictionary = scalar_stats.get(key, {}) as Dictionary
		var count: int = int(stat.get("count", 0))
		lines.append("%s_min=%.6f" % [key, float(stat.get("min", 0.0))])
		lines.append("%s_max=%.6f" % [key, float(stat.get("max", 0.0))])
		lines.append("%s_avg=%.6f" % [key, float(stat.get("sum", 0.0)) / maxf(float(count), 1.0)])
		lines.append("%s_max_step=%.6f" % [key, float(stat.get("max_step", 0.0))])
		lines.append("%s_max_at_sample=%d" % [key, int(stat.get("max_sample", -1))])
	lines.append("first_illegal_body_self_sample=%s" % str(first_illegal_body_self_sample))
	lines.append("first_illegal_weapon_body_sample=%s" % str(first_illegal_weapon_body_sample))
	return lines

func _build_legality_summary() -> PackedStringArray:
	var lines: PackedStringArray = []
	var endpoint_max: float = maxf(_stat_max("active_tip_pose_error_meters"), _stat_max("active_pommel_pose_error_meters"))
	var dominant_grip_max: float = _stat_max("active_dominant_grip_to_ik_meters")
	var dominant_ik_max: float = _stat_max("active_dominant_hand_ik_error_meters")
	var finger_max: float = _stat_max("active_dominant_finger_contact_distance_meters")
	var body_self_illegal_max: float = _stat_max("active_body_self_illegal_pair_count")
	var weapon_body_illegal_max: float = _stat_max("active_weapon_body_illegal_sample_count")
	var finger_known: bool = _stat_count("active_dominant_finger_contact_distance_meters") > 0
	lines.append("endpoint_error_limit_meters=%.6f" % ENDPOINT_ERROR_LIMIT_METERS)
	lines.append("dominant_grip_target_error_limit_meters=%.6f" % DOMINANT_GRIP_TARGET_ERROR_LIMIT_METERS)
	lines.append("dominant_hand_ik_error_limit_meters=%.6f" % DOMINANT_HAND_IK_ERROR_LIMIT_METERS)
	lines.append("finger_contact_distance_limit_meters=%.6f" % FINGER_CONTACT_DISTANCE_LIMIT_METERS)
	lines.append("runtime_weapon_endpoint_legal=%s" % str(endpoint_max <= ENDPOINT_ERROR_LIMIT_METERS))
	lines.append("dominant_grip_target_legal=%s" % str(dominant_grip_max <= DOMINANT_GRIP_TARGET_ERROR_LIMIT_METERS))
	lines.append("dominant_hand_ik_legal=%s" % str(dominant_ik_max <= DOMINANT_HAND_IK_ERROR_LIMIT_METERS))
	lines.append("dominant_finger_contact_known=%s" % str(finger_known))
	lines.append("dominant_finger_contact_legal=%s" % str((not finger_known) or finger_max <= FINGER_CONTACT_DISTANCE_LIMIT_METERS))
	lines.append("body_self_collision_legal_all_samples=%s" % str(body_self_illegal_max <= 0.0))
	lines.append("weapon_body_collision_legal_all_samples=%s" % str(weapon_body_illegal_max <= 0.0))
	lines.append("all_core_legality_checks_passed=%s" % str(_all_core_legality_checks_passed()))
	return lines

func _build_seating_debug_lines(player: PlayerController3D, label: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	var slot_id: StringName = DOMINANT_EQUIPMENT_SLOT_ID
	var held_item: Node3D = player.held_item_nodes.get(slot_id) as Node3D if player != null else null
	var skeleton: Skeleton3D = _get_skeleton(player)
	var humanoid_rig: Node3D = player.humanoid_rig if player != null else null
	var hand_anchor: Node3D = _get_hand_anchor(player, slot_id)
	var primary_anchor: Node3D = held_item.get_node_or_null("PrimaryGripAnchor") as Node3D if held_item != null else null
	var primary_guide: Node3D = held_item.get_node_or_null("PrimaryGripGuide") as Node3D if held_item != null else null
	var grip_center: Node3D = primary_guide.get_node_or_null("GripShellCenter") as Node3D if primary_guide != null else null
	var hand_bone_world: Vector3 = _get_bone_world_position(skeleton, _resolve_hand_bone(slot_id))
	var forearm_bone_world: Vector3 = _get_bone_world_position(skeleton, _resolve_forearm_bone(slot_id))
	var index_world: Vector3 = _get_bone_world_position(skeleton, "CC_Base_R_Index1")
	var pinky_world: Vector3 = _get_bone_world_position(skeleton, "CC_Base_R_Pinky1")
	if slot_id == &"hand_left":
		index_world = _get_bone_world_position(skeleton, "CC_Base_L_Index1")
		pinky_world = _get_bone_world_position(skeleton, "CC_Base_L_Pinky1")
	var index_pinky_center_world: Vector3 = index_world.lerp(pinky_world, 0.5)
	var anatomical_grip_world: Vector3 = (
		humanoid_rig.call("resolve_hand_grip_alignment_world_position", slot_id) as Vector3
		if humanoid_rig != null and humanoid_rig.has_method("resolve_hand_grip_alignment_world_position")
		else Vector3.ZERO
	)
	var grip_debug: Dictionary = _get_grip_debug(player)
	var primary_anchor_world: Vector3 = primary_anchor.global_position if primary_anchor != null else Vector3.ZERO
	var hand_anchor_world: Vector3 = hand_anchor.global_position if hand_anchor != null else Vector3.ZERO
	var ik_world: Vector3 = _resolve_grip_debug_vector(grip_debug, slot_id, "hand_ik_target_world")
	var desired_hand_bone_world: Vector3 = primary_anchor_world
	if anatomical_grip_world.length_squared() > 0.000001 and hand_bone_world.length_squared() > 0.000001:
		desired_hand_bone_world = primary_anchor_world - (anatomical_grip_world - hand_bone_world)
	lines.append("%s_held_item_parent=%s" % [label, str(held_item.get_parent().get_path() if held_item != null and held_item.get_parent() != null else NodePath(""))])
	lines.append("%s_upper_body_auto_apply_enabled=%s" % [label, str(bool(grip_debug.get("upper_body_authoring_auto_apply_enabled", true)))])
	lines.append("%s_authoring_preview_mode_enabled=%s" % [label, str(bool(grip_debug.get("authoring_preview_mode_enabled", false)))])
	lines.append("%s_direct_authoring_solver_mode=%s" % [label, str(bool(grip_debug.get("direct_authoring_solver_mode", false)))])
	lines.append("%s_right_arm_ik_active=%s" % [label, str(bool(grip_debug.get("right_arm_ik_active", false)))])
	lines.append("%s_left_arm_ik_active=%s" % [label, str(bool(grip_debug.get("left_arm_ik_active", false)))])
	lines.append("%s_primary_anchor_local=%s" % [label, _fmt_vec(primary_anchor.position if primary_anchor != null else Vector3.ZERO)])
	lines.append("%s_primary_guide_local=%s" % [label, _fmt_vec(primary_guide.position if primary_guide != null else Vector3.ZERO)])
	lines.append("%s_grip_center_local=%s" % [label, _fmt_vec(grip_center.position if grip_center != null else Vector3.ZERO)])
	lines.append("%s_primary_grip_contact_local=%s" % [label, _fmt_vec(held_item.get_meta("primary_grip_contact_local", Vector3.ZERO) as Vector3 if held_item != null else Vector3.ZERO)])
	lines.append("%s_preview_primary_grip_seat_local=%s" % [label, _fmt_vec(held_item.get_meta("preview_primary_grip_seat_local", Vector3.ZERO) as Vector3 if held_item != null else Vector3.ZERO)])
	lines.append("%s_hand_bone_world=%s" % [label, _fmt_vec(hand_bone_world)])
	lines.append("%s_forearm_bone_world=%s" % [label, _fmt_vec(forearm_bone_world)])
	lines.append("%s_hand_anchor_world=%s" % [label, _fmt_vec(hand_anchor_world)])
	lines.append("%s_anatomical_grip_world=%s" % [label, _fmt_vec(anatomical_grip_world)])
	lines.append("%s_index_pinky_center_world=%s" % [label, _fmt_vec(index_pinky_center_world)])
	lines.append("%s_primary_anchor_world=%s" % [label, _fmt_vec(primary_anchor_world)])
	lines.append("%s_ik_target_world=%s" % [label, _fmt_vec(ik_world)])
	lines.append("%s_desired_hand_bone_for_primary_anchor_world=%s" % [label, _fmt_vec(desired_hand_bone_world)])
	lines.append("%s_primary_anchor_to_hand_bone_meters=%.6f" % [label, primary_anchor_world.distance_to(hand_bone_world)])
	lines.append("%s_primary_anchor_to_hand_anchor_meters=%.6f" % [label, primary_anchor_world.distance_to(hand_anchor_world)])
	lines.append("%s_primary_anchor_to_anatomical_grip_meters=%.6f" % [label, primary_anchor_world.distance_to(anatomical_grip_world)])
	lines.append("%s_primary_anchor_to_index_pinky_center_meters=%.6f" % [label, primary_anchor_world.distance_to(index_pinky_center_world)])
	lines.append("%s_anatomical_grip_to_hand_bone_meters=%.6f" % [label, anatomical_grip_world.distance_to(hand_bone_world)])
	lines.append("%s_anatomical_grip_to_hand_anchor_meters=%.6f" % [label, anatomical_grip_world.distance_to(hand_anchor_world)])
	lines.append("%s_ik_to_desired_hand_bone_meters=%.6f" % [label, ik_world.distance_to(desired_hand_bone_world)])
	lines.append("%s_hand_bone_to_desired_hand_bone_meters=%.6f" % [label, hand_bone_world.distance_to(desired_hand_bone_world)])
	return lines

func _all_core_legality_checks_passed() -> bool:
	var endpoint_max: float = maxf(_stat_max("active_tip_pose_error_meters"), _stat_max("active_pommel_pose_error_meters"))
	return (
		endpoint_max <= ENDPOINT_ERROR_LIMIT_METERS
		and _stat_max("active_dominant_grip_to_ik_meters") <= DOMINANT_GRIP_TARGET_ERROR_LIMIT_METERS
		and _stat_max("active_dominant_hand_ik_error_meters") <= DOMINANT_HAND_IK_ERROR_LIMIT_METERS
		and _stat_max("active_body_self_illegal_pair_count") <= 0.0
		and _stat_max("active_weapon_body_illegal_sample_count") <= 0.0
	)

func _record_scalar(key: String, value: float) -> void:
	if value < 0.0 or is_nan(value) or is_inf(value):
		return
	var stat: Dictionary = scalar_stats.get(key, {}) as Dictionary
	var count: int = int(stat.get("count", 0))
	if count <= 0:
		stat["min"] = value
		stat["max"] = value
	else:
		stat["min"] = minf(float(stat.get("min", value)), value)
		if value > float(stat.get("max", value)):
			stat["max"] = value
			stat["max_sample"] = current_record_sample_index
	stat["sum"] = float(stat.get("sum", 0.0)) + value
	if previous_scalars.has(key):
		var delta: float = absf(float(previous_scalars.get(key, value)) - value)
		if delta > float(stat.get("max_step", 0.0)):
			stat["max_step"] = delta
	stat["count"] = count + 1
	if not stat.has("max_sample"):
		stat["max_sample"] = current_record_sample_index
	scalar_stats[key] = stat
	previous_scalars[key] = value

func _stat_max(key: String) -> float:
	var stat: Dictionary = scalar_stats.get(key, {}) as Dictionary
	return float(stat.get("max", 999.0))

func _stat_count(key: String) -> int:
	var stat: Dictionary = scalar_stats.get(key, {}) as Dictionary
	return int(stat.get("count", 0))

func _find_saved_wip_by_project_name(library_state: PlayerForgeWipLibraryState, project_name: String) -> CraftedItemWIP:
	if library_state == null:
		return null
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip != null and saved_wip.forge_project_name == project_name:
			return saved_wip
	return null

func _find_player_controller(source_root: Node) -> PlayerController3D:
	if source_root == null:
		return null
	if source_root is PlayerController3D:
		return source_root as PlayerController3D
	for child: Node in source_root.get_children():
		var player: PlayerController3D = _find_player_controller(child)
		if player != null:
			return player
	return null

func _get_skeleton(player: PlayerController3D) -> Skeleton3D:
	if player == null or player.humanoid_rig == null:
		return null
	return player.humanoid_rig.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D

func _resolve_hand_bone(slot_id: StringName) -> String:
	return "CC_Base_L_Hand" if slot_id == &"hand_left" else "CC_Base_R_Hand"

func _resolve_forearm_bone(slot_id: StringName) -> String:
	return "CC_Base_L_Forearm" if slot_id == &"hand_left" else "CC_Base_R_Forearm"

func _get_hand_anchor(player: PlayerController3D, slot_id: StringName) -> Node3D:
	if player == null or player.humanoid_rig == null:
		return null
	if slot_id == &"hand_left" and player.humanoid_rig.has_method("get_left_hand_item_anchor"):
		return player.humanoid_rig.call("get_left_hand_item_anchor") as Node3D
	if player.humanoid_rig.has_method("get_right_hand_item_anchor"):
		return player.humanoid_rig.call("get_right_hand_item_anchor") as Node3D
	return null

func _get_bone_world_position(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var bone_index: int = skeleton.find_bone(bone_name)
	if bone_index < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)

func _get_bone_world_basis(skeleton: Skeleton3D, bone_name: String) -> Basis:
	if skeleton == null:
		return Basis.IDENTITY
	var bone_index: int = skeleton.find_bone(bone_name)
	if bone_index < 0:
		return Basis.IDENTITY
	return (skeleton.global_basis * skeleton.get_bone_global_pose(bone_index).basis).orthonormalized()

func _resolve_hand_y_forearm_dot(skeleton: Skeleton3D, slot_id: StringName, hand_basis: Basis) -> float:
	var hand_axis: Vector3 = hand_basis.y.normalized()
	var forearm_to_hand: Vector3 = _get_bone_world_position(skeleton, _resolve_hand_bone(slot_id)) - _get_bone_world_position(skeleton, _resolve_forearm_bone(slot_id))
	if hand_axis.length_squared() <= 0.000001 or forearm_to_hand.length_squared() <= 0.000001:
		return 0.0
	return forearm_to_hand.normalized().dot(hand_axis)

func _resolve_hand_x_tip_plane_dot(hand_basis: Basis, grip_to_tip_world: Vector3) -> float:
	if grip_to_tip_world.length_squared() <= 0.000001:
		return 0.0
	var y_axis: Vector3 = hand_basis.y.normalized()
	var x_axis: Vector3 = hand_basis.x.normalized()
	var projected_tip_axis: Vector3 = grip_to_tip_world - y_axis * grip_to_tip_world.dot(y_axis)
	if projected_tip_axis.length_squared() <= 0.000001:
		return 0.0
	return projected_tip_axis.normalized().dot(x_axis)

func _string_name_keys(source: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = []
	for key_variant: Variant in source.keys():
		keys.append(String(key_variant))
	return keys

func _fmt_vec(value: Vector3) -> String:
	return "\"(%.5f %.5f %.5f)\"" % [value.x, value.y, value.z]

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame

func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await physics_frame

func _wait_until_player_grounded(player: PlayerController3D, max_physics_frames: int) -> void:
	for _frame_index: int in range(maxi(max_physics_frames, 0)):
		await physics_frame
		await process_frame
		if player != null and player.is_on_floor():
			return

func _write_outputs() -> void:
	var result_file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if result_file != null:
		result_file.store_string("\n".join(result_lines))
		result_file.close()
	var sample_file := FileAccess.open(SAMPLE_FILE_PATH, FileAccess.WRITE)
	if sample_file != null:
		sample_file.store_string("\n".join(sample_lines))
		sample_file.close()
