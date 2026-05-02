extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const TARGET_PROJECT_NAME := "Test sword for animations"
const RESULT_FILE_PATH := "C:/WORKSPACE/skill_slot_1_reset_observation_hands_results.txt"
const SAMPLE_FILE_PATH := "C:/WORKSPACE/skill_slot_1_reset_observation_hands_samples.csv"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_skill_slot_1_reset_observation_hands_library.tres"
const SAMPLE_INTERVAL_SECONDS := 1.0 / 60.0
const OBSERVE_SECONDS_PER_PHASE := 3.0
const PHASE_COUNT := 3
const DOMINANT_GRIP_ERROR_LIMIT_METERS := 0.02
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

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

var vector_stats: Dictionary = {}
var basis_stats: Dictionary = {}
var scalar_stats: Dictionary = {}
var previous_vectors: Dictionary = {}
var previous_bases: Dictionary = {}
var previous_scalars: Dictionary = {}
var sample_lines: PackedStringArray = []
var result_lines: PackedStringArray = []
var reset_lines: PackedStringArray = []
var current_sample_index: int = 0
var current_phase_index: int = 0
var current_phase_seconds: float = 0.0
var current_total_seconds: float = 0.0
var reset_count: int = 0

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	sample_lines.append(
		"sample,total_seconds,phase,phase_seconds,reset_count,selected_index,node_grip,node_two_hand,node_primary,dominant_slot,dominant_error,support_error,dominant_finger_distance,support_finger_distance,dominant_finger_readiness,support_finger_readiness,body_self_legal,body_self_illegal_count,collision_pose_legal,collision_path_legal,right_hand_y_forearm_dot,left_hand_y_forearm_dot,right_hand_x_tip_plane_dot,left_hand_x_tip_plane_dot,dominant_hand_y_error,dominant_hand_x_side_error,right_ik_error,left_ik_error,right_hand,right_ik,left_hand,left_ik,weapon_pos,right_index3,right_mid3,right_thumb3,left_index3,left_mid3,left_thumb3"
	)
	result_lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)
	result_lines.append("target_slot=skill_slot_1")
	result_lines.append("phase_count=%d" % PHASE_COUNT)
	result_lines.append("observe_seconds_per_phase=%.4f" % OBSERVE_SECONDS_PER_PHASE)
	result_lines.append("reset_pattern=one_reset_then_three_second_observation")

	var source_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var source_wip: CraftedItemWIP = _find_saved_wip_by_project_name(source_library, TARGET_PROJECT_NAME)
	result_lines.append("source_library_loaded=%s" % str(source_library != null))
	result_lines.append("source_wip_found=%s" % str(source_wip != null))
	if source_wip == null:
		_write_outputs()
		quit()
		return

	var temp_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	temp_library.save_file_path = TEMP_SAVE_FILE_PATH
	temp_library.saved_wips.clear()
	var diagnostic_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	diagnostic_wip.wip_id = StringName("%s_skill_slot_1_reset_observation" % String(source_wip.wip_id))
	diagnostic_wip.forge_project_name = "%s Skill Slot 1 Reset Observation Diagnostic" % source_wip.forge_project_name
	diagnostic_wip.ensure_combat_animation_station_state()
	temp_library.saved_wips.append(diagnostic_wip)
	temp_library.selected_wip_id = diagnostic_wip.wip_id
	temp_library.persist()

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = temp_library
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Skill Slot 1 Reset Observation Hand Diagnostic")
	await _wait_frames(8)
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(diagnostic_wip.wip_id, &"hand_right", false, false)
	await _wait_frames(8)
	var select_slot_ok: bool = ui.select_skill_slot(&"skill_slot_1", true)
	await _wait_frames(6)
	result_lines.append("diagnostic_save_path=%s" % TEMP_SAVE_FILE_PATH)
	result_lines.append("source_wip_id=%s" % String(source_wip.wip_id))
	result_lines.append("diagnostic_wip_id=%s" % String(diagnostic_wip.wip_id))
	result_lines.append("open_ok=%s" % str(open_ok))
	result_lines.append("select_skill_slot_1_ok=%s" % str(select_slot_ok))
	result_lines.append("active_draft_identifier=%s" % String(ui.get_active_draft_identifier()))
	result_lines.append("active_open_slot=%s" % String(ui.get_active_open_dominant_slot_id()))
	result_lines.append("active_open_two_hand=%s" % str(ui.is_active_open_two_hand()))
	result_lines.append_array(_build_motion_node_report(ui, "initial"))

	_sample_ui(ui)
	for phase_index: int in range(PHASE_COUNT):
		current_phase_index = phase_index + 1
		current_phase_seconds = 0.0
		var reset_ok: bool = ui.reset_active_draft_to_baseline()
		reset_count += 1
		reset_lines.append("reset_%d_phase=%d phase_seconds=0.0000 ok=%s" % [
			reset_count,
			current_phase_index,
			str(reset_ok),
		])
		await _wait_frames(2)
		_sample_ui(ui)
		await _observe(ui, OBSERVE_SECONDS_PER_PHASE)
		result_lines.append_array(_build_motion_node_report(ui, "after_phase_%d" % current_phase_index))

	result_lines.append_array(reset_lines)
	result_lines.append("total_reset_count=%d" % reset_count)
	result_lines.append("sample_count=%d" % current_sample_index)
	result_lines.append("observed_seconds=%.4f" % current_total_seconds)
	result_lines.append_array(_build_stat_lines())
	result_lines.append_array(_build_final_debug_lines(ui))
	_write_outputs()
	quit()

func _observe(ui: CombatAnimationStationUI, seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		await create_timer(SAMPLE_INTERVAL_SECONDS).timeout
		elapsed += SAMPLE_INTERVAL_SECONDS
		current_phase_seconds = elapsed
		current_total_seconds += SAMPLE_INTERVAL_SECONDS
		_sample_ui(ui)

func _sample_ui(ui: CombatAnimationStationUI) -> void:
	current_sample_index += 1
	var preview_root: Node3D = _get_preview_root(ui)
	var actor: Node3D = _get_preview_actor(ui)
	var held_item: Node3D = _get_preview_held_item(ui)
	var skeleton: Skeleton3D = actor.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if actor != null else null
	var right_ik: Node3D = actor.get_node_or_null("IkTargets/RightHandIkTarget") as Node3D if actor != null else null
	var left_ik: Node3D = actor.get_node_or_null("IkTargets/LeftHandIkTarget") as Node3D if actor != null else null
	var motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var debug_state: Dictionary = ui.get_preview_debug_state()
	var grip_debug: Dictionary = debug_state.get("grip_contact_debug_state", {}) as Dictionary
	var dominant_slot: StringName = debug_state.get("dominant_slot_id", StringName()) as StringName
	var grip_mode: StringName = motion_node.preferred_grip_style_mode if motion_node != null else StringName()
	var two_hand_state: StringName = motion_node.two_hand_state if motion_node != null else StringName()
	var primary_hand: StringName = motion_node.primary_hand_slot if motion_node != null else StringName()

	var right_hand_world: Vector3 = _get_bone_world_position(skeleton, "CC_Base_R_Hand")
	var left_hand_world: Vector3 = _get_bone_world_position(skeleton, "CC_Base_L_Hand")
	var right_ik_world: Vector3 = right_ik.global_position if right_ik != null else Vector3.ZERO
	var left_ik_world: Vector3 = left_ik.global_position if left_ik != null else Vector3.ZERO
	var weapon_pos: Vector3 = held_item.global_position if held_item != null else Vector3.ZERO
	var right_hand_basis: Basis = _get_bone_world_basis(skeleton, "CC_Base_R_Hand")
	var left_hand_basis: Basis = _get_bone_world_basis(skeleton, "CC_Base_L_Hand")
	var grip_to_tip_world: Vector3 = _resolve_grip_to_tip_axis(held_item)
	var right_hand_y_forearm_dot: float = _resolve_hand_y_forearm_dot(skeleton, "CC_Base_R_Hand", "CC_Base_R_Forearm", right_hand_basis)
	var left_hand_y_forearm_dot: float = _resolve_hand_y_forearm_dot(skeleton, "CC_Base_L_Hand", "CC_Base_L_Forearm", left_hand_basis)
	var right_hand_x_tip_plane_dot: float = _resolve_hand_x_tip_plane_dot(right_hand_basis, grip_to_tip_world)
	var left_hand_x_tip_plane_dot: float = _resolve_hand_x_tip_plane_dot(left_hand_basis, grip_to_tip_world)
	var dominant_expected_x_dot: float = _expected_hand_x_dot(grip_mode)
	var dominant_actual_y_dot: float = right_hand_y_forearm_dot if dominant_slot != &"hand_left" else left_hand_y_forearm_dot
	var dominant_actual_x_dot: float = right_hand_x_tip_plane_dot if dominant_slot != &"hand_left" else left_hand_x_tip_plane_dot
	var dominant_hand_y_error: float = absf(1.0 - dominant_actual_y_dot)
	var dominant_hand_x_side_error: float = absf(dominant_actual_x_dot - dominant_expected_x_dot) if dominant_expected_x_dot != 0.0 else 0.0
	var dominant_error: float = float(debug_state.get("dominant_grip_alignment_error_meters", -1.0))
	var support_error: float = float(debug_state.get("support_grip_alignment_error_meters", -1.0))
	var dominant_finger_distance: float = float(debug_state.get("dominant_finger_contact_distance_meters", -1.0))
	var support_finger_distance: float = float(debug_state.get("support_finger_contact_distance_meters", -1.0))
	var right_ik_error: float = right_hand_world.distance_to(right_ik_world) if right_ik != null else -1.0
	var left_ik_error: float = left_hand_world.distance_to(left_ik_world) if left_ik != null else -1.0

	_record_vector("weapon_position", weapon_pos)
	_record_vector("right_hand_bone", right_hand_world)
	_record_vector("left_hand_bone", left_hand_world)
	_record_vector("right_ik_target", right_ik_world)
	_record_vector("left_ik_target", left_ik_world)
	_record_scalar("dominant_grip_alignment_error_meters", dominant_error)
	_record_scalar("support_grip_alignment_error_meters", support_error)
	_record_scalar("dominant_finger_contact_distance_meters", dominant_finger_distance)
	_record_scalar("support_finger_contact_distance_meters", support_finger_distance)
	_record_scalar("dominant_hand_y_anatomical_error", dominant_hand_y_error)
	_record_scalar("dominant_hand_x_weapon_side_error", dominant_hand_x_side_error)
	_record_scalar("right_hand_ik_error", right_ik_error)
	_record_scalar("left_hand_ik_error", left_ik_error)
	_record_scalar("body_self_illegal_count", float(int(debug_state.get("body_self_collision_illegal_pair_count", 0))))
	_record_scalar("collision_path_illegal_pose_count", float(int(debug_state.get("collision_path_illegal_pose_count", 0))))
	if held_item != null:
		_record_basis("weapon_basis", held_item.global_basis)
	if skeleton != null:
		_record_basis("right_hand_basis", right_hand_basis)
		_record_basis("left_hand_basis", left_hand_basis)
		_record_basis("right_forearm_basis", _get_bone_world_basis(skeleton, "CC_Base_R_Forearm"))
		_record_basis("left_forearm_basis", _get_bone_world_basis(skeleton, "CC_Base_L_Forearm"))
	for label: String in FINGER_END_BONES.keys():
		var finger_position: Vector3 = _get_bone_world_position(skeleton, String(FINGER_END_BONES.get(label, "")))
		_record_vector("%s_end_bone" % label, finger_position)

	var right_index3: Vector3 = _get_bone_world_position(skeleton, "CC_Base_R_Index3")
	var right_mid3: Vector3 = _get_bone_world_position(skeleton, "CC_Base_R_Mid3")
	var right_thumb3: Vector3 = _get_bone_world_position(skeleton, "CC_Base_R_Thumb3")
	var left_index3: Vector3 = _get_bone_world_position(skeleton, "CC_Base_L_Index3")
	var left_mid3: Vector3 = _get_bone_world_position(skeleton, "CC_Base_L_Mid3")
	var left_thumb3: Vector3 = _get_bone_world_position(skeleton, "CC_Base_L_Thumb3")
	sample_lines.append("%d,%.4f,%d,%.4f,%d,%d,%s,%s,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%s,%d,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s" % [
		current_sample_index,
		current_total_seconds,
		current_phase_index,
		current_phase_seconds,
		reset_count,
		ui.get_selected_motion_node_index(),
		String(grip_mode),
		String(two_hand_state),
		String(primary_hand),
		String(dominant_slot),
		dominant_error,
		support_error,
		dominant_finger_distance,
		support_finger_distance,
		float(debug_state.get("dominant_finger_contact_readiness", -1.0)),
		float(debug_state.get("support_finger_contact_readiness", -1.0)),
		str(bool(debug_state.get("body_self_collision_legal", true))),
		int(debug_state.get("body_self_collision_illegal_pair_count", 0)),
		str(bool(debug_state.get("collision_pose_legal", true))),
		str(bool(debug_state.get("collision_path_legal", true))),
		right_hand_y_forearm_dot,
		left_hand_y_forearm_dot,
		right_hand_x_tip_plane_dot,
		left_hand_x_tip_plane_dot,
		dominant_hand_y_error,
		dominant_hand_x_side_error,
		right_ik_error,
		left_ik_error,
		_fmt_vec(right_hand_world),
		_fmt_vec(right_ik_world),
		_fmt_vec(left_hand_world),
		_fmt_vec(left_ik_world),
		_fmt_vec(weapon_pos),
		_fmt_vec(right_index3),
		_fmt_vec(right_mid3),
		_fmt_vec(right_thumb3),
		_fmt_vec(left_index3),
		_fmt_vec(left_mid3),
		_fmt_vec(left_thumb3),
	])

func _build_motion_node_report(ui: CombatAnimationStationUI, prefix: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	var motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	lines.append("%s_draft_exists=%s" % [prefix, str(draft != null)])
	lines.append("%s_motion_node_exists=%s" % [prefix, str(motion_node != null)])
	if draft != null:
		lines.append("%s_draft_id=%s" % [prefix, String(draft.draft_id)])
		lines.append("%s_owning_skill_id=%s" % [prefix, String(draft.owning_skill_id)])
		lines.append("%s_legal_slot_id=%s" % [prefix, String(draft.legal_slot_id)])
		lines.append("%s_motion_node_count=%d" % [prefix, draft.motion_node_chain.size()])
	if motion_node != null:
		lines.append("%s_selected_motion_node_index=%d" % [prefix, ui.get_selected_motion_node_index()])
		lines.append("%s_tip_position_local=%s" % [prefix, str(motion_node.tip_position_local)])
		lines.append("%s_pommel_position_local=%s" % [prefix, str(motion_node.pommel_position_local)])
		lines.append("%s_weapon_orientation_degrees=%s" % [prefix, str(motion_node.weapon_orientation_degrees)])
		lines.append("%s_preferred_grip_style=%s" % [prefix, String(motion_node.preferred_grip_style_mode)])
		lines.append("%s_two_hand_state=%s" % [prefix, String(motion_node.two_hand_state)])
		lines.append("%s_primary_hand_slot=%s" % [prefix, String(motion_node.primary_hand_slot)])
		lines.append("%s_generated_transition_node=%s" % [prefix, str(motion_node.generated_transition_node)])
		lines.append("%s_generated_transition_kind=%s" % [prefix, String(motion_node.generated_transition_kind)])
	return lines

func _build_final_debug_lines(ui: CombatAnimationStationUI) -> PackedStringArray:
	var lines: PackedStringArray = []
	var debug_state: Dictionary = ui.get_preview_debug_state()
	var grip_debug: Dictionary = debug_state.get("grip_contact_debug_state", {}) as Dictionary
	var contact_clearance_metrics: Dictionary = debug_state.get("contact_clearance_settle_metrics", {}) as Dictionary
	var final_anchor_metrics: Dictionary = debug_state.get("final_anchor_reseat_metrics", {}) as Dictionary
	lines.append("final_dominant_slot_id=%s" % String(debug_state.get("dominant_slot_id", StringName())))
	lines.append("final_default_two_hand=%s" % str(bool(debug_state.get("default_two_hand", false))))
	lines.append("final_contact_clearance_iterations=%d" % int(contact_clearance_metrics.get("iterations", 0)))
	lines.append("final_contact_clearance_stop=%s" % String(contact_clearance_metrics.get("stopped_reason", "")))
	lines.append("final_contact_clearance_reseat_delta_meters=%.6f" % float(contact_clearance_metrics.get("max_weapon_reseat_delta_meters", -1.0)))
	lines.append("final_contact_clearance_separation_delta_meters=%.6f" % float(contact_clearance_metrics.get("max_weapon_move_delta_meters", -1.0)))
	lines.append("final_contact_clearance_hand_authority_reseat_delta_meters=%.6f" % float(contact_clearance_metrics.get("final_hand_authority_reseat_delta_meters", -1.0)))
	lines.append("final_contact_clearance_hand_authority_separation_delta_meters=%.6f" % float(contact_clearance_metrics.get("final_hand_authority_separation_delta_meters", -1.0)))
	lines.append("final_contact_clearance_grip_error_before_meters=%.6f" % float(contact_clearance_metrics.get("dominant_grip_error_before_meters", -1.0)))
	lines.append("final_contact_clearance_grip_error_after_meters=%.6f" % float(contact_clearance_metrics.get("dominant_grip_error_after_meters", -1.0)))
	lines.append("final_anchor_reseat_delta_meters=%.6f" % float(final_anchor_metrics.get("max_reseat_delta_meters", -1.0)))
	lines.append("final_anchor_post_separation_delta_meters=%.6f" % float(final_anchor_metrics.get("post_anchor_separation_delta_meters", -1.0)))
	lines.append("final_anchor_reseat_grip_error_after_meters=%.6f" % float(final_anchor_metrics.get("grip_error_after_meters", -1.0)))
	lines.append("final_anchor_post_separation_grip_error_after_meters=%.6f" % float(final_anchor_metrics.get("grip_error_after_post_separation_meters", -1.0)))
	lines.append("final_dominant_grip_target_world=%s" % str(debug_state.get("dominant_grip_target_world", Vector3.ZERO)))
	lines.append("final_dominant_grip_anchor_world=%s" % str(debug_state.get("dominant_grip_anchor_world", Vector3.ZERO)))
	lines.append("final_dominant_grip_alignment_error_meters=%.6f" % float(debug_state.get("dominant_grip_alignment_error_meters", -1.0)))
	lines.append("final_support_grip_alignment_error_meters=%.6f" % float(debug_state.get("support_grip_alignment_error_meters", -1.0)))
	lines.append("final_dominant_finger_contact_distance_meters=%.6f" % float(debug_state.get("dominant_finger_contact_distance_meters", -1.0)))
	lines.append("final_support_finger_contact_distance_meters=%.6f" % float(debug_state.get("support_finger_contact_distance_meters", -1.0)))
	lines.append("final_dominant_finger_contact_readiness=%.6f" % float(debug_state.get("dominant_finger_contact_readiness", -1.0)))
	lines.append("final_support_finger_contact_readiness=%.6f" % float(debug_state.get("support_finger_contact_readiness", -1.0)))
	lines.append("final_right_arm_guidance_active=%s" % str(bool(grip_debug.get("right_arm_guidance_active", false))))
	lines.append("final_left_arm_guidance_active=%s" % str(bool(grip_debug.get("left_arm_guidance_active", false))))
	lines.append("final_right_arm_ik_active=%s" % str(bool(grip_debug.get("right_arm_ik_active", false))))
	lines.append("final_left_arm_ik_active=%s" % str(bool(grip_debug.get("left_arm_ik_active", false))))
	lines.append("final_right_hand_ik_distance_meters=%.6f" % float(grip_debug.get("right_hand_ik_target_distance_meters", -1.0)))
	lines.append("final_left_hand_ik_distance_meters=%.6f" % float(grip_debug.get("left_hand_ik_target_distance_meters", -1.0)))
	lines.append("final_body_self_collision_legal=%s" % str(bool(debug_state.get("body_self_collision_legal", true))))
	lines.append("final_body_self_collision_illegal_pair_count=%d" % int(debug_state.get("body_self_collision_illegal_pair_count", 0)))
	lines.append("final_body_self_collision_first_illegal_pair=%s" % str(debug_state.get("body_self_collision_first_illegal_pair", {})))
	lines.append("final_collision_pose_legal=%s" % str(bool(debug_state.get("collision_pose_legal", true))))
	lines.append("final_collision_pose_region=%s" % String(debug_state.get("collision_pose_region", "")))
	lines.append("final_collision_pose_sample=%s" % String(debug_state.get("collision_pose_sample", "")))
	lines.append("final_collision_pose_clearance_meters=%.6f" % float(debug_state.get("collision_pose_clearance_meters", -1.0)))
	lines.append("final_collision_path_legal=%s" % str(bool(debug_state.get("collision_path_legal", true))))
	lines.append("final_collision_path_illegal_pose_count=%d" % int(debug_state.get("collision_path_illegal_pose_count", 0)))
	return lines

func _build_stat_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for key: String in vector_stats.keys():
		var stat: Dictionary = vector_stats.get(key, {}) as Dictionary
		var count: int = int(stat.get("count", 0))
		var min_value: Vector3 = stat.get("min", Vector3.ZERO) as Vector3
		var max_value: Vector3 = stat.get("max", Vector3.ZERO) as Vector3
		var range_value: Vector3 = max_value - min_value
		lines.append("%s_range_meters=%.6f" % [key, range_value.length()])
		lines.append("%s_max_step_meters=%.6f" % [key, float(stat.get("max_step", 0.0))])
		lines.append("%s_average_step_meters=%.6f" % [key, float(stat.get("sum_step", 0.0)) / maxf(float(count - 1), 1.0)])
		lines.append("%s_max_step_at=sample:%d phase:%d phase_seconds:%.4f" % [
			key,
			int(stat.get("max_step_sample", -1)),
			int(stat.get("max_step_phase", -1)),
			float(stat.get("max_step_phase_seconds", -1.0)),
		])
	for key: String in basis_stats.keys():
		var stat: Dictionary = basis_stats.get(key, {}) as Dictionary
		var count: int = int(stat.get("count", 0))
		lines.append("%s_max_step_degrees=%.6f" % [key, float(stat.get("max_step_degrees", 0.0))])
		lines.append("%s_average_step_degrees=%.6f" % [key, float(stat.get("sum_step_degrees", 0.0)) / maxf(float(count - 1), 1.0)])
		lines.append("%s_max_step_at=sample:%d phase:%d phase_seconds:%.4f" % [
			key,
			int(stat.get("max_step_sample", -1)),
			int(stat.get("max_step_phase", -1)),
			float(stat.get("max_step_phase_seconds", -1.0)),
		])
	for key: String in scalar_stats.keys():
		var stat: Dictionary = scalar_stats.get(key, {}) as Dictionary
		var count: int = int(stat.get("count", 0))
		lines.append("%s_min=%.6f" % [key, float(stat.get("min", 0.0))])
		lines.append("%s_max=%.6f" % [key, float(stat.get("max", 0.0))])
		lines.append("%s_max_step=%.6f" % [key, float(stat.get("max_step", 0.0))])
		lines.append("%s_average_step=%.6f" % [key, float(stat.get("sum_step", 0.0)) / maxf(float(count - 1), 1.0)])
		lines.append("%s_max_step_at=sample:%d phase:%d phase_seconds:%.4f" % [
			key,
			int(stat.get("max_step_sample", -1)),
			int(stat.get("max_step_phase", -1)),
			float(stat.get("max_step_phase_seconds", -1.0)),
		])
	lines.append("dominant_grip_position_legal_threshold_meters=%.6f" % DOMINANT_GRIP_ERROR_LIMIT_METERS)
	lines.append("dominant_finger_contact_threshold_meters=%.6f" % FINGER_CONTACT_DISTANCE_LIMIT_METERS)
	lines.append("dominant_grip_position_legal=%s" % str(float((scalar_stats.get("dominant_grip_alignment_error_meters", {}) as Dictionary).get("max", 999.0)) <= DOMINANT_GRIP_ERROR_LIMIT_METERS))
	lines.append("dominant_finger_contact_legal=%s" % str(float((scalar_stats.get("dominant_finger_contact_distance_meters", {}) as Dictionary).get("max", 999.0)) <= FINGER_CONTACT_DISTANCE_LIMIT_METERS))
	var dominant_y_legal: bool = float((scalar_stats.get("dominant_hand_y_anatomical_error", {}) as Dictionary).get("max", 999.0)) <= 0.15
	var dominant_x_legal: bool = float((scalar_stats.get("dominant_hand_x_weapon_side_error", {}) as Dictionary).get("max", 999.0)) <= 0.20
	lines.append("dominant_hand_y_anatomical_legal=%s" % str(dominant_y_legal))
	lines.append("dominant_hand_x_weapon_side_legal=%s" % str(dominant_x_legal))
	lines.append("dominant_hand_orientation_legal=%s" % str(dominant_y_legal and dominant_x_legal))
	return lines

func _record_vector(key: String, value: Vector3) -> void:
	var stat: Dictionary = vector_stats.get(key, {}) as Dictionary
	var count: int = int(stat.get("count", 0))
	if count <= 0:
		stat["min"] = value
		stat["max"] = value
	else:
		stat["min"] = _min_vec(stat.get("min", value) as Vector3, value)
		stat["max"] = _max_vec(stat.get("max", value) as Vector3, value)
	if previous_vectors.has(key):
		var delta: float = (previous_vectors.get(key, value) as Vector3).distance_to(value)
		stat["sum_step"] = float(stat.get("sum_step", 0.0)) + delta
		if delta > float(stat.get("max_step", 0.0)):
			stat["max_step"] = delta
			stat["max_step_sample"] = current_sample_index
			stat["max_step_phase"] = current_phase_index
			stat["max_step_phase_seconds"] = current_phase_seconds
	stat["count"] = count + 1
	vector_stats[key] = stat
	previous_vectors[key] = value

func _record_basis(key: String, value: Basis) -> void:
	var stat: Dictionary = basis_stats.get(key, {}) as Dictionary
	var count: int = int(stat.get("count", 0))
	if previous_bases.has(key):
		var delta_degrees: float = _basis_delta_degrees(previous_bases.get(key, value) as Basis, value)
		stat["sum_step_degrees"] = float(stat.get("sum_step_degrees", 0.0)) + delta_degrees
		if delta_degrees > float(stat.get("max_step_degrees", 0.0)):
			stat["max_step_degrees"] = delta_degrees
			stat["max_step_sample"] = current_sample_index
			stat["max_step_phase"] = current_phase_index
			stat["max_step_phase_seconds"] = current_phase_seconds
	stat["count"] = count + 1
	basis_stats[key] = stat
	previous_bases[key] = value

func _record_scalar(key: String, value: float) -> void:
	if value < 0.0:
		return
	var stat: Dictionary = scalar_stats.get(key, {}) as Dictionary
	var count: int = int(stat.get("count", 0))
	if count <= 0:
		stat["min"] = value
		stat["max"] = value
	else:
		stat["min"] = minf(float(stat.get("min", value)), value)
		stat["max"] = maxf(float(stat.get("max", value)), value)
	if previous_scalars.has(key):
		var delta: float = absf(float(previous_scalars.get(key, value)) - value)
		stat["sum_step"] = float(stat.get("sum_step", 0.0)) + delta
		if delta > float(stat.get("max_step", 0.0)):
			stat["max_step"] = delta
			stat["max_step_sample"] = current_sample_index
			stat["max_step_phase"] = current_phase_index
			stat["max_step_phase_seconds"] = current_phase_seconds
	stat["count"] = count + 1
	scalar_stats[key] = stat
	previous_scalars[key] = value

func _resolve_grip_to_tip_axis(held_item: Node3D) -> Vector3:
	if held_item == null:
		return Vector3.ZERO
	var local_tip: Vector3 = held_item.get_meta("weapon_tip_local", Vector3.ZERO) as Vector3
	var local_grip: Vector3 = held_item.get_meta("primary_grip_contact_local", Vector3.ZERO) as Vector3
	var axis: Vector3 = (held_item.global_transform * local_tip) - (held_item.global_transform * local_grip)
	return axis.normalized() if axis.length_squared() > 0.000001 else Vector3.ZERO

func _resolve_hand_y_forearm_dot(skeleton: Skeleton3D, hand_bone: String, forearm_bone: String, hand_basis: Basis) -> float:
	var hand_axis: Vector3 = hand_basis.y.normalized()
	var forearm_to_hand: Vector3 = _get_bone_world_position(skeleton, hand_bone) - _get_bone_world_position(skeleton, forearm_bone)
	if hand_axis.length_squared() <= 0.000001 or forearm_to_hand.length_squared() <= 0.000001:
		return 0.0
	return forearm_to_hand.normalized().dot(hand_axis)

func _resolve_hand_x_tip_plane_dot(hand_basis: Basis, grip_to_tip_world: Vector3) -> float:
	if grip_to_tip_world.length_squared() <= 0.000001:
		return 0.0
	var y_axis: Vector3 = hand_basis.y.normalized()
	var x_axis: Vector3 = hand_basis.x.normalized()
	if y_axis.length_squared() <= 0.000001 or x_axis.length_squared() <= 0.000001:
		return 0.0
	var projected_tip_axis: Vector3 = grip_to_tip_world - y_axis * grip_to_tip_world.dot(y_axis)
	if projected_tip_axis.length_squared() <= 0.000001:
		return 0.0
	return projected_tip_axis.normalized().dot(x_axis)

func _expected_hand_x_dot(grip_mode: StringName) -> float:
	if grip_mode == CraftedItemWIP.GRIP_REVERSE:
		return -1.0
	if grip_mode == CraftedItemWIP.GRIP_NORMAL:
		return 1.0
	return 0.0

func _get_preview_root(ui: CombatAnimationStationUI) -> Node3D:
	if ui == null or ui.preview_subviewport == null:
		return null
	return ui.preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D

func _get_preview_actor(ui: CombatAnimationStationUI) -> Node3D:
	var preview_root: Node3D = _get_preview_root(ui)
	return preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D if preview_root != null else null

func _get_preview_held_item(ui: CombatAnimationStationUI) -> Node3D:
	var preview_root: Node3D = _get_preview_root(ui)
	return preview_root.get_meta("preview_held_item", null) as Node3D if preview_root != null else null

func _find_saved_wip_by_project_name(library_state: PlayerForgeWipLibraryState, project_name: String) -> CraftedItemWIP:
	if library_state == null:
		return null
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip != null and saved_wip.forge_project_name == project_name:
			return saved_wip
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

func _basis_delta_degrees(first: Basis, second: Basis) -> float:
	return maxf(
		_axis_delta_degrees(first.x, second.x),
		maxf(
			_axis_delta_degrees(first.y, second.y),
			_axis_delta_degrees(first.z, second.z)
		)
	)

func _axis_delta_degrees(first: Vector3, second: Vector3) -> float:
	if first.length_squared() <= 0.000001 or second.length_squared() <= 0.000001:
		return 0.0
	return rad_to_deg(acos(clampf(first.normalized().dot(second.normalized()), -1.0, 1.0)))

func _min_vec(first: Vector3, second: Vector3) -> Vector3:
	return Vector3(minf(first.x, second.x), minf(first.y, second.y), minf(first.z, second.z))

func _max_vec(first: Vector3, second: Vector3) -> Vector3:
	return Vector3(maxf(first.x, second.x), maxf(first.y, second.y), maxf(first.z, second.z))

func _fmt_vec(value: Vector3) -> String:
	return "\"(%.5f %.5f %.5f)\"" % [value.x, value.y, value.z]

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame

func _write_outputs() -> void:
	var result_file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if result_file != null:
		result_file.store_string("\n".join(result_lines))
		result_file.close()
	var sample_file: FileAccess = FileAccess.open(SAMPLE_FILE_PATH, FileAccess.WRITE)
	if sample_file != null:
		sample_file.store_string("\n".join(sample_lines))
		sample_file.close()
