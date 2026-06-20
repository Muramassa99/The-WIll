extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/skill_slot_1_arm_extension_authority_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_skill_slot_1_arm_extension_authority_library.tres"
const TARGET_SLOT_ID: StringName = &"skill_slot_1"
const DOMINANT_SLOT_ID: StringName = &"hand_right"

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

var lines: PackedStringArray = []

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	var source_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var source_wip: CraftedItemWIP = _resolve_latest_or_selected_wip(source_library)
	lines.append("source_library_loaded=%s" % str(source_library != null))
	lines.append("source_selected_wip_id=%s" % String(source_library.selected_wip_id if source_library != null else StringName()))
	lines.append("source_wip_found=%s" % str(source_wip != null))
	if source_wip == null:
		_write_results()
		quit()
		return
	lines.append("source_wip_id=%s" % String(source_wip.wip_id))
	lines.append("source_project_name=%s" % source_wip.forge_project_name)
	lines.append("source_created_timestamp=%.3f" % float(source_wip.created_timestamp))

	var temp_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	temp_library.save_file_path = TEMP_SAVE_FILE_PATH
	temp_library.saved_wips.clear()
	var diagnostic_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	diagnostic_wip.wip_id = StringName("%s_arm_extension_authority" % String(source_wip.wip_id))
	diagnostic_wip.forge_project_name = "%s Arm Extension Authority Diagnostic" % source_wip.forge_project_name
	diagnostic_wip.ensure_combat_animation_station_state()
	temp_library.saved_wips.append(diagnostic_wip)
	temp_library.selected_wip_id = diagnostic_wip.wip_id
	temp_library.persist()
	lines.append("diagnostic_save_path=%s" % TEMP_SAVE_FILE_PATH)
	lines.append("diagnostic_wip_id=%s" % String(diagnostic_wip.wip_id))

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = temp_library
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Skill Slot 1 Arm Extension Authority Diagnostic")
	await _wait_frames(8)
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(diagnostic_wip.wip_id, DOMINANT_SLOT_ID, false, false)
	await _wait_frames(8)
	var select_slot_ok: bool = ui.select_skill_slot(TARGET_SLOT_ID, true)
	await _wait_frames(8)
	_select_first_visible_skill_node(ui)
	await _wait_frames(4)
	lines.append("open_ok=%s" % str(open_ok))
	lines.append("select_skill_slot_1_ok=%s" % str(select_slot_ok))
	lines.append("active_draft_identifier=%s" % String(ui.get_active_draft_identifier()))
	lines.append("active_open_slot=%s" % String(ui.get_active_open_dominant_slot_id()))
	lines.append("active_open_two_hand=%s" % str(ui.is_active_open_two_hand()))

	var reset_ok: bool = ui.reset_active_draft_to_baseline()
	await _wait_frames(10)
	_select_first_visible_skill_node(ui)
	await _wait_frames(4)
	lines.append("reset_ok=%s" % str(reset_ok))
	_append_pose_report(ui, "after_reset")

	var t_target_world: Vector3 = _resolve_right_arm_target_world(ui, true)
	var t_result: Dictionary = _attempt_grip_translation_with_ui(ui, t_target_world)
	lines.append("t_pose_requested_grip_world=%s" % str(t_target_world))
	lines.append("t_pose_ui_setter_result=%s" % str(t_result))
	await _wait_frames(10)
	_append_pose_report(ui, "after_t_pose_ui_attempt")

	reset_ok = ui.reset_active_draft_to_baseline()
	await _wait_frames(8)
	_select_first_visible_skill_node(ui)
	await _wait_frames(4)
	var a_target_world: Vector3 = _resolve_right_arm_target_world(ui, false)
	var a_result: Dictionary = _attempt_grip_translation_with_ui(ui, a_target_world)
	lines.append("a_pose_reset_ok=%s" % str(reset_ok))
	lines.append("a_pose_requested_grip_world=%s" % str(a_target_world))
	lines.append("a_pose_ui_setter_result=%s" % str(a_result))
	await _wait_frames(10)
	_append_pose_report(ui, "after_a_pose_ui_attempt")

	reset_ok = ui.reset_active_draft_to_baseline()
	await _wait_frames(8)
	_select_first_visible_skill_node(ui)
	await _wait_frames(4)
	var raw_t_result: Dictionary = _attempt_grip_translation_raw(ui, t_target_world)
	lines.append("raw_t_pose_reset_ok=%s" % str(reset_ok))
	lines.append("raw_t_pose_result=%s" % str(raw_t_result))
	await _wait_frames(10)
	_append_pose_report(ui, "after_t_pose_raw_endpoint_attempt")

	_write_results()
	quit()

func _select_first_visible_skill_node(ui: CombatAnimationStationUI) -> void:
	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	if draft == null:
		return
	var node_count: int = draft.motion_node_chain.size()
	if node_count <= 0:
		return
	ui.select_motion_node(1 if node_count > 1 else 0)

func _attempt_grip_translation_with_ui(ui: CombatAnimationStationUI, desired_grip_world: Vector3) -> Dictionary:
	var motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var trajectory_root: Node3D = _get_trajectory_root(ui)
	var primary_anchor: Node3D = _get_primary_grip_anchor(ui)
	if motion_node == null or trajectory_root == null or primary_anchor == null:
		return {"attempted": false, "reason": "missing_context"}
	var current_grip_local: Vector3 = trajectory_root.to_local(primary_anchor.global_position)
	var desired_grip_local: Vector3 = trajectory_root.to_local(desired_grip_world)
	var translation_local: Vector3 = desired_grip_local - current_grip_local
	var requested_pommel: Vector3 = motion_node.pommel_position_local + translation_local
	var before_tip: Vector3 = motion_node.tip_position_local
	var before_pommel: Vector3 = motion_node.pommel_position_local
	var changed: bool = ui.set_selected_motion_node_pommel_position(
		requested_pommel,
		false,
		true,
		true,
		true,
		true
	)
	return {
		"attempted": true,
		"changed": changed,
		"current_grip_local": current_grip_local,
		"desired_grip_local": desired_grip_local,
		"translation_local": translation_local,
		"requested_pommel": requested_pommel,
		"before_tip": before_tip,
		"before_pommel": before_pommel,
		"after_tip": motion_node.tip_position_local,
		"after_pommel": motion_node.pommel_position_local,
	}

func _attempt_grip_translation_raw(ui: CombatAnimationStationUI, desired_grip_world: Vector3) -> Dictionary:
	var motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var trajectory_root: Node3D = _get_trajectory_root(ui)
	var primary_anchor: Node3D = _get_primary_grip_anchor(ui)
	if motion_node == null or trajectory_root == null or primary_anchor == null:
		return {"attempted": false, "reason": "missing_context"}
	var current_grip_local: Vector3 = trajectory_root.to_local(primary_anchor.global_position)
	var desired_grip_local: Vector3 = trajectory_root.to_local(desired_grip_world)
	var translation_local: Vector3 = desired_grip_local - current_grip_local
	var before_tip: Vector3 = motion_node.tip_position_local
	var before_pommel: Vector3 = motion_node.pommel_position_local
	motion_node.tip_position_local += translation_local
	motion_node.pommel_position_local += translation_local
	motion_node.normalize()
	ui.call("_refresh_preview_scene")
	return {
		"attempted": true,
		"current_grip_local": current_grip_local,
		"desired_grip_local": desired_grip_local,
		"translation_local": translation_local,
		"before_tip": before_tip,
		"before_pommel": before_pommel,
		"after_tip": motion_node.tip_position_local,
		"after_pommel": motion_node.pommel_position_local,
	}

func _resolve_right_arm_target_world(ui: CombatAnimationStationUI, t_pose: bool) -> Vector3:
	var actor: Node3D = _get_preview_actor(ui)
	var skeleton: Skeleton3D = actor.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if actor != null else null
	var left_clavicle: Vector3 = _get_bone_world_position(skeleton, "CC_Base_L_Clavicle")
	var right_clavicle: Vector3 = _get_bone_world_position(skeleton, "CC_Base_R_Clavicle")
	var chest: Vector3 = _get_bone_world_position(skeleton, "CC_Base_Spine02")
	var head: Vector3 = _get_bone_world_position(skeleton, "CC_Base_Head")
	var right_dir: Vector3 = right_clavicle - left_clavicle
	if right_dir.length_squared() <= 0.000001:
		right_dir = actor.global_basis.x if actor != null else Vector3.RIGHT
	right_dir = right_dir.normalized()
	var up_dir: Vector3 = head - chest
	if up_dir.length_squared() <= 0.000001:
		up_dir = actor.global_basis.y if actor != null else Vector3.UP
	up_dir = up_dir.normalized()
	if t_pose:
		return right_clavicle + right_dir * 0.58 - up_dir * 0.02
	return right_clavicle + right_dir * 0.44 - up_dir * 0.30

func _append_pose_report(ui: CombatAnimationStationUI, prefix: String) -> void:
	var actor: Node3D = _get_preview_actor(ui)
	var held_item: Node3D = _get_preview_held_item(ui)
	var skeleton: Skeleton3D = actor.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if actor != null else null
	var right_ik: Node3D = actor.get_node_or_null("IkTargets/RightHandIkTarget") as Node3D if actor != null else null
	var left_ik: Node3D = actor.get_node_or_null("IkTargets/LeftHandIkTarget") as Node3D if actor != null else null
	var motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var debug_state: Dictionary = ui.get_preview_debug_state()
	var grip_debug: Dictionary = debug_state.get("grip_contact_debug_state", {}) as Dictionary
	var contact_metrics: Dictionary = debug_state.get("contact_clearance_settle_metrics", {}) as Dictionary
	var anchor_metrics: Dictionary = debug_state.get("final_anchor_reseat_metrics", {}) as Dictionary
	var tether_metrics: Dictionary = debug_state.get("authoring_contact_tether_metrics", {}) as Dictionary
	var endpoint_legality: Dictionary = debug_state.get("authoring_endpoint_legality_result", {}) as Dictionary
	var right_hand: Vector3 = _get_bone_world_position(skeleton, "CC_Base_R_Hand")
	var right_clavicle: Vector3 = _get_bone_world_position(skeleton, "CC_Base_R_Clavicle")
	var right_forearm: Vector3 = _get_bone_world_position(skeleton, "CC_Base_R_Forearm")
	var primary_anchor: Node3D = _get_primary_grip_anchor(ui)
	lines.append("")
	lines.append("[%s]" % prefix)
	lines.append("%s_selected_motion_node_index=%d" % [prefix, ui.get_selected_motion_node_index()])
	if motion_node != null:
		lines.append("%s_node_tip_local=%s" % [prefix, str(motion_node.tip_position_local)])
		lines.append("%s_node_pommel_local=%s" % [prefix, str(motion_node.pommel_position_local)])
		lines.append("%s_node_two_hand=%s" % [prefix, String(motion_node.two_hand_state)])
		lines.append("%s_node_grip=%s" % [prefix, String(motion_node.preferred_grip_style_mode)])
	lines.append("%s_display_tip_local=%s" % [prefix, str(debug_state.get("display_selected_tip_position_local", Vector3.ZERO))])
	lines.append("%s_display_pommel_local=%s" % [prefix, str(debug_state.get("display_selected_pommel_position_local", Vector3.ZERO))])
	lines.append("%s_resolved_tip_local=%s" % [prefix, str(debug_state.get("resolved_tip_position_local", Vector3.ZERO))])
	lines.append("%s_resolved_pommel_local=%s" % [prefix, str(debug_state.get("resolved_pommel_position_local", Vector3.ZERO))])
	lines.append("%s_right_clavicle_world=%s" % [prefix, str(right_clavicle)])
	lines.append("%s_right_forearm_world=%s" % [prefix, str(right_forearm)])
	lines.append("%s_right_hand_world=%s" % [prefix, str(right_hand)])
	lines.append("%s_right_ik_target_world=%s" % [prefix, str(right_ik.global_position if right_ik != null else Vector3.ZERO)])
	lines.append("%s_left_ik_target_world=%s" % [prefix, str(left_ik.global_position if left_ik != null else Vector3.ZERO)])
	lines.append("%s_right_hand_from_clavicle=%s" % [prefix, str(right_hand - right_clavicle)])
	lines.append("%s_right_hand_reach_meters=%.6f" % [prefix, right_hand.distance_to(right_clavicle)])
	lines.append("%s_right_ik_reach_meters=%.6f" % [prefix, (right_ik.global_position if right_ik != null else Vector3.ZERO).distance_to(right_clavicle)])
	lines.append("%s_weapon_world=%s" % [prefix, str(held_item.global_position if held_item != null else Vector3.ZERO)])
	lines.append("%s_primary_grip_anchor_world=%s" % [prefix, str(primary_anchor.global_position if primary_anchor != null else Vector3.ZERO)])
	lines.append("%s_dominant_grip_target_world=%s" % [prefix, str(debug_state.get("dominant_grip_target_world", Vector3.ZERO))])
	lines.append("%s_dominant_grip_anchor_world=%s" % [prefix, str(debug_state.get("dominant_grip_anchor_world", Vector3.ZERO))])
	lines.append("%s_dominant_grip_alignment_error_meters=%.6f" % [prefix, float(debug_state.get("dominant_grip_alignment_error_meters", -1.0))])
	lines.append("%s_right_arm_guidance_active=%s" % [prefix, str(bool(grip_debug.get("right_arm_guidance_active", false)))])
	lines.append("%s_right_arm_ik_active=%s" % [prefix, str(bool(grip_debug.get("right_arm_ik_active", false)))])
	lines.append("%s_right_hand_ik_target_distance_meters=%.6f" % [prefix, float(grip_debug.get("right_hand_ik_target_distance_meters", -1.0))])
	lines.append("%s_last_two_hand_solve_result=%s" % [prefix, str(grip_debug.get("last_two_hand_solve_result", {}))])
	lines.append("%s_collision_pose_legal=%s" % [prefix, str(bool(debug_state.get("collision_pose_legal", true)))])
	lines.append("%s_collision_pose_region=%s" % [prefix, String(debug_state.get("collision_pose_region", ""))])
	lines.append("%s_collision_pose_clearance_meters=%.6f" % [prefix, float(debug_state.get("collision_pose_clearance_meters", -1.0))])
	lines.append("%s_body_self_collision_legal=%s" % [prefix, str(bool(debug_state.get("body_self_collision_legal", true)))])
	lines.append("%s_body_self_collision_illegal_pair_count=%d" % [prefix, int(debug_state.get("body_self_collision_illegal_pair_count", 0))])
	lines.append("%s_collision_path_legal=%s" % [prefix, str(bool(debug_state.get("collision_path_legal", true)))])
	lines.append("%s_collision_path_region=%s" % [prefix, String(debug_state.get("collision_path_region", ""))])
	lines.append("%s_tether_metrics=%s" % [prefix, str(tether_metrics)])
	lines.append("%s_endpoint_legality=%s" % [prefix, str(endpoint_legality)])
	lines.append("%s_contact_clearance_metrics=%s" % [prefix, str(contact_metrics)])
	lines.append("%s_final_anchor_metrics=%s" % [prefix, str(anchor_metrics)])
	lines.append("%s_joint_range_debug=%s" % [prefix, str(debug_state.get("joint_range_debug_state", {}))])

func _get_preview_root(ui: CombatAnimationStationUI) -> Node3D:
	if ui == null or ui.preview_subviewport == null:
		return null
	return ui.preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D

func _get_trajectory_root(ui: CombatAnimationStationUI) -> Node3D:
	var preview_root: Node3D = _get_preview_root(ui)
	return preview_root.get_node_or_null("TrajectoryRoot") as Node3D if preview_root != null else null

func _get_preview_actor(ui: CombatAnimationStationUI) -> Node3D:
	var preview_root: Node3D = _get_preview_root(ui)
	return preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D if preview_root != null else null

func _get_preview_held_item(ui: CombatAnimationStationUI) -> Node3D:
	var preview_root: Node3D = _get_preview_root(ui)
	return preview_root.get_meta("preview_held_item", null) as Node3D if preview_root != null else null

func _get_primary_grip_anchor(ui: CombatAnimationStationUI) -> Node3D:
	var held_item: Node3D = _get_preview_held_item(ui)
	return held_item.find_child("PrimaryGripAnchor", true, false) as Node3D if held_item != null else null

func _resolve_latest_or_selected_wip(library_state: PlayerForgeWipLibraryState) -> CraftedItemWIP:
	if library_state == null:
		return null
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip != null and saved_wip.wip_id == library_state.selected_wip_id:
			return saved_wip
	var latest_wip: CraftedItemWIP = null
	var latest_created: float = -INF
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip == null:
			continue
		if float(saved_wip.created_timestamp) > latest_created:
			latest_created = float(saved_wip.created_timestamp)
			latest_wip = saved_wip
	return latest_wip

func _get_bone_world_position(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	var bone_index: int = skeleton.find_bone(bone_name)
	if bone_index < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame

func _write_results() -> void:
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
