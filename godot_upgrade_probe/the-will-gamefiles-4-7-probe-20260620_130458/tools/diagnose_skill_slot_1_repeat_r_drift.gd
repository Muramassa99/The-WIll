extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const TARGET_PROJECT_NAMES := [
	"Test sword for animations",
	"test sword for animations",
]
const TARGET_SLOT_ID: StringName = &"skill_slot_1"
const DOMINANT_SLOT_ID: StringName = &"hand_right"
const OPEN_TWO_HAND := true
const REPEAT_COUNT := 5
const RESULT_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/skill_slot_1_repeat_r_drift_2026-05-10.log"
const NODE_CSV_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/skill_slot_1_repeat_r_drift_nodes_2026-05-10.csv"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_skill_slot_1_repeat_r_drift_library.tres"

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

var result_lines: PackedStringArray = []
var node_csv_lines: PackedStringArray = []
var snapshots: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/DEBUG-LOGS")
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	node_csv_lines.append(
		"phase,node_index,selected,node_id,tip_x,tip_y,tip_z,pommel_x,pommel_y,pommel_z,axis_len,center_x,center_y,center_z,transition_s,body_support_blend,right_upperarm_roll,left_upperarm_roll,weapon_roll,axial_reposition,grip_slide,secondary_grip_slide,two_hand_state,primary_hand,grip_style,generated,locked,prev_tip_delta,prev_pommel_delta,prev_center_delta"
	)
	result_lines.append("diagnostic=skill_slot_1_repeat_r_drift")
	result_lines.append("target_project_names=%s" % str(TARGET_PROJECT_NAMES))
	result_lines.append("target_slot_id=%s" % String(TARGET_SLOT_ID))
	result_lines.append("dominant_slot_id=%s" % String(DOMINANT_SLOT_ID))
	result_lines.append("open_two_hand=%s" % str(OPEN_TWO_HAND))
	result_lines.append("selection_policy=last_motion_node_before_repeat_r")
	result_lines.append("repeat_count=%d" % REPEAT_COUNT)

	var source_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var source_wip: CraftedItemWIP = _find_saved_wip_by_project_names(source_library, TARGET_PROJECT_NAMES)
	result_lines.append("source_library_loaded=%s" % str(source_library != null))
	result_lines.append("source_wip_found=%s" % str(source_wip != null))
	if source_wip == null:
		_write_outputs()
		quit()
		return
	result_lines.append("source_wip_id=%s" % String(source_wip.wip_id))
	result_lines.append("source_project_name=%s" % source_wip.forge_project_name)

	var temp_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	temp_library.save_file_path = TEMP_SAVE_FILE_PATH
	temp_library.saved_wips.clear()
	var diagnostic_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	diagnostic_wip.wip_id = StringName("%s_repeat_r_drift" % String(source_wip.wip_id))
	diagnostic_wip.forge_project_name = "%s Repeat R Drift Diagnostic" % source_wip.forge_project_name
	diagnostic_wip.ensure_combat_animation_station_state()
	temp_library.saved_wips.append(diagnostic_wip)
	temp_library.selected_wip_id = diagnostic_wip.wip_id
	temp_library.persist()
	result_lines.append("diagnostic_wip_id=%s" % String(diagnostic_wip.wip_id))
	result_lines.append("diagnostic_save_path=%s" % TEMP_SAVE_FILE_PATH)

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = temp_library
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	ui.set_meta("trace_editor_action_latency", true)
	ui.set_meta("trace_editor_surface_latency", true)
	root.add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Skill Slot 1 Repeat R Drift Diagnostic")
	await _wait_frames(8)
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(diagnostic_wip.wip_id, DOMINANT_SLOT_ID, OPEN_TWO_HAND, false)
	await _wait_frames(8)
	var select_slot_ok: bool = ui.select_skill_slot(TARGET_SLOT_ID, true)
	await _wait_frames(10)
	var selected_last_ok: bool = _select_last_motion_node(ui)
	await _wait_frames(10)
	result_lines.append("open_ok=%s" % str(open_ok))
	result_lines.append("select_skill_slot_1_ok=%s" % str(select_slot_ok))
	result_lines.append("select_last_motion_node_ok=%s" % str(selected_last_ok))
	result_lines.append("active_draft_identifier=%s" % String(ui.get_active_draft_identifier()))
	result_lines.append("active_open_slot=%s" % String(ui.get_active_open_dominant_slot_id()))
	result_lines.append("active_open_two_hand=%s" % str(ui.is_active_open_two_hand()))

	await _sample_phase(ui, "initial")
	for repeat_index: int in range(REPEAT_COUNT):
		var before_usec: int = Time.get_ticks_usec()
		var inserted_ok: bool = ui.insert_motion_node_after_selection()
		var after_insert_usec: int = Time.get_ticks_usec()
		await _wait_frames(10)
		var after_refresh_usec: int = Time.get_ticks_usec()
		var phase_name: String = "after_r_%d" % (repeat_index + 1)
		result_lines.append("%s_insert_ok=%s" % [phase_name, str(inserted_ok)])
		result_lines.append("%s_insert_call_ms=%.3f" % [phase_name, _elapsed_ms(before_usec, after_insert_usec)])
		result_lines.append("%s_insert_plus_wait_ms=%.3f" % [phase_name, _elapsed_ms(before_usec, after_refresh_usec)])
		_append_trace_lines(ui, phase_name, "editor_action", "last_editor_action_latency_trace")
		_append_trace_lines(ui, phase_name, "editor_surface", "last_editor_surface_latency_trace")
		await _sample_phase(ui, phase_name)

	_append_delta_report()
	_write_outputs()
	quit()

func _sample_phase(ui: CombatAnimationStationUI, phase_name: String) -> void:
	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	var selected_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var debug_state: Dictionary = ui.get_preview_debug_state()
	var grip_debug: Dictionary = debug_state.get("grip_contact_debug_state", {}) as Dictionary
	var preview_root: Node3D = _get_preview_root(ui)
	var actor: Node3D = _get_preview_actor(ui)
	var held_item: Node3D = _get_preview_held_item(ui)
	var snapshot: Dictionary = {
		"phase": phase_name,
		"selected_index": ui.get_selected_motion_node_index(),
		"node_count": draft.motion_node_chain.size() if draft != null else 0,
		"selected_tip": selected_node.tip_position_local if selected_node != null else Vector3.ZERO,
		"selected_pommel": selected_node.pommel_position_local if selected_node != null else Vector3.ZERO,
		"display_tip": debug_state.get("display_selected_tip_position_local", Vector3.ZERO) as Vector3,
		"display_pommel": debug_state.get("display_selected_pommel_position_local", Vector3.ZERO) as Vector3,
		"resolved_tip": debug_state.get("resolved_tip_position_local", Vector3.ZERO) as Vector3,
		"resolved_pommel": debug_state.get("resolved_pommel_position_local", Vector3.ZERO) as Vector3,
		"dominant_error": float(debug_state.get("dominant_grip_alignment_error_meters", -1.0)),
		"support_error": float(debug_state.get("support_grip_alignment_error_meters", -1.0)),
		"dominant_slot": debug_state.get("dominant_slot_id", StringName()) as StringName,
		"collision_pose_legal": bool(debug_state.get("collision_pose_legal", true)),
		"collision_path_legal": bool(debug_state.get("collision_path_legal", true)),
	}
	snapshots.append(snapshot)

	result_lines.append("")
	result_lines.append("[%s]" % phase_name)
	result_lines.append("%s_selected_index=%d" % [phase_name, int(snapshot.get("selected_index", -1))])
	result_lines.append("%s_node_count=%d" % [phase_name, int(snapshot.get("node_count", 0))])
	if selected_node != null:
		result_lines.append("%s_selected_node_id=%s" % [phase_name, String(selected_node.node_id)])
		result_lines.append("%s_selected_tip=%s" % [phase_name, _fmt_vec(selected_node.tip_position_local)])
		result_lines.append("%s_selected_pommel=%s" % [phase_name, _fmt_vec(selected_node.pommel_position_local)])
		result_lines.append("%s_selected_axis_len=%.6f" % [phase_name, selected_node.tip_position_local.distance_to(selected_node.pommel_position_local)])
		result_lines.append("%s_selected_center=%s" % [phase_name, _fmt_vec((selected_node.tip_position_local + selected_node.pommel_position_local) * 0.5)])
		result_lines.append("%s_selected_grip=%s two_hand=%s primary=%s body_blend=%.4f" % [
			phase_name,
			String(selected_node.preferred_grip_style_mode),
			String(selected_node.two_hand_state),
			String(selected_node.primary_hand_slot),
			selected_node.body_support_blend,
		])
		result_lines.append("%s_selected_rolls right_upper=%.3f left_upper=%.3f weapon=%.3f" % [
			phase_name,
			selected_node.right_upperarm_roll_degrees,
			selected_node.left_upperarm_roll_degrees,
			selected_node.weapon_roll_degrees,
		])
	result_lines.append("%s_display_tip=%s" % [phase_name, _fmt_vec(snapshot.get("display_tip", Vector3.ZERO) as Vector3)])
	result_lines.append("%s_display_pommel=%s" % [phase_name, _fmt_vec(snapshot.get("display_pommel", Vector3.ZERO) as Vector3)])
	result_lines.append("%s_resolved_tip=%s" % [phase_name, _fmt_vec(snapshot.get("resolved_tip", Vector3.ZERO) as Vector3)])
	result_lines.append("%s_resolved_pommel=%s" % [phase_name, _fmt_vec(snapshot.get("resolved_pommel", Vector3.ZERO) as Vector3)])
	if selected_node != null:
		result_lines.append("%s_selected_to_display_tip_delta=%.6f" % [
			phase_name,
			selected_node.tip_position_local.distance_to(snapshot.get("display_tip", Vector3.ZERO) as Vector3),
		])
		result_lines.append("%s_selected_to_display_pommel_delta=%.6f" % [
			phase_name,
			selected_node.pommel_position_local.distance_to(snapshot.get("display_pommel", Vector3.ZERO) as Vector3),
		])
		result_lines.append("%s_selected_to_resolved_tip_delta=%.6f" % [
			phase_name,
			selected_node.tip_position_local.distance_to(snapshot.get("resolved_tip", Vector3.ZERO) as Vector3),
		])
		result_lines.append("%s_selected_to_resolved_pommel_delta=%.6f" % [
			phase_name,
			selected_node.pommel_position_local.distance_to(snapshot.get("resolved_pommel", Vector3.ZERO) as Vector3),
		])
	result_lines.append("%s_dominant_slot=%s" % [phase_name, String(snapshot.get("dominant_slot", StringName()))])
	result_lines.append("%s_dominant_grip_error=%.6f" % [phase_name, float(snapshot.get("dominant_error", -1.0))])
	result_lines.append("%s_support_grip_error=%.6f" % [phase_name, float(snapshot.get("support_error", -1.0))])
	result_lines.append("%s_weapon_tip_alignment_error=%.6f" % [phase_name, float(debug_state.get("weapon_tip_alignment_error_meters", -1.0))])
	result_lines.append("%s_weapon_pommel_alignment_error=%.6f" % [phase_name, float(debug_state.get("weapon_pommel_alignment_error_meters", -1.0))])
	result_lines.append("%s_collision_pose_legal=%s" % [phase_name, str(bool(snapshot.get("collision_pose_legal", true)))])
	result_lines.append("%s_collision_path_legal=%s" % [phase_name, str(bool(snapshot.get("collision_path_legal", true)))])
	result_lines.append("%s_collision_path_illegal_pose_count=%d" % [phase_name, int(debug_state.get("collision_path_illegal_pose_count", 0))])
	result_lines.append("%s_speed_state_samples=%d" % [phase_name, int(debug_state.get("speed_state_sample_count", 0))])
	result_lines.append("%s_speed_state_max_effective=%.6f" % [phase_name, float(debug_state.get("speed_state_max_effective_speed_mps", 0.0))])
	result_lines.append("%s_curve_baked_point_count=%d" % [phase_name, int(debug_state.get("curve_baked_point_count", 0))])
	_append_metric_dict(phase_name, "authoring_endpoint_legality", debug_state.get("authoring_endpoint_legality_result", {}) as Dictionary)
	_append_metric_dict(phase_name, "contact_clearance", debug_state.get("contact_clearance_settle_metrics", {}) as Dictionary)
	_append_metric_dict(phase_name, "final_anchor", debug_state.get("final_anchor_reseat_metrics", {}) as Dictionary)
	_append_metric_dict(phase_name, "contact_coupling", debug_state.get("contact_coupling_metrics", {}) as Dictionary)
	_append_metric_dict(phase_name, "support_coupling", debug_state.get("support_coupling_metrics", {}) as Dictionary)
	_append_metric_dict(phase_name, "last_two_hand_right", ((grip_debug.get("last_two_hand_solve_result", {}) as Dictionary).get(&"hand_right", {}) as Dictionary))
	_append_metric_dict(phase_name, "last_two_hand_left", ((grip_debug.get("last_two_hand_solve_result", {}) as Dictionary).get(&"hand_left", {}) as Dictionary))
	result_lines.append("%s_right_arm_guidance_active=%s left_arm_guidance_active=%s" % [
		phase_name,
		str(bool(grip_debug.get("right_arm_guidance_active", false))),
		str(bool(grip_debug.get("left_arm_guidance_active", false))),
	])
	result_lines.append("%s_right_ik_distance=%.6f left_ik_distance=%.6f" % [
		phase_name,
		float(grip_debug.get("right_hand_ik_target_distance_meters", -1.0)),
		float(grip_debug.get("left_hand_ik_target_distance_meters", -1.0)),
	])
	result_lines.append("%s_right_upperarm_twist_applied=%.6f left_upperarm_twist_applied=%.6f" % [
		phase_name,
		float(grip_debug.get("right_authoring_upperarm_twist_applied_degrees", 0.0)),
		float(grip_debug.get("left_authoring_upperarm_twist_applied_degrees", 0.0)),
	])
	if preview_root != null:
		result_lines.append("%s_preview_root=%s" % [phase_name, String(preview_root.name)])
	if actor != null:
		result_lines.append("%s_actor_global=%s" % [phase_name, _fmt_vec(actor.global_position)])
	if held_item != null:
		result_lines.append("%s_weapon_global=%s" % [phase_name, _fmt_vec(held_item.global_position)])
		result_lines.append("%s_weapon_basis=%s" % [phase_name, _fmt_basis(held_item.global_basis)])
	_append_chain_report(draft, phase_name)

func _append_chain_report(draft: CombatAnimationDraft, phase_name: String) -> void:
	if draft == null:
		result_lines.append("%s_chain_missing=true" % phase_name)
		return
	var selected_index: int = int(draft.selected_motion_node_index)
	var duplicate_neighbor_count: int = 0
	var zero_tip_segments: int = 0
	var zero_pommel_segments: int = 0
	var zero_center_segments: int = 0
	var previous_node: CombatAnimationMotionNode = null
	for node_index: int in range(draft.motion_node_chain.size()):
		var motion_node: CombatAnimationMotionNode = draft.motion_node_chain[node_index] as CombatAnimationMotionNode
		if motion_node == null:
			continue
		var center: Vector3 = (motion_node.tip_position_local + motion_node.pommel_position_local) * 0.5
		var prev_tip_delta: float = -1.0
		var prev_pommel_delta: float = -1.0
		var prev_center_delta: float = -1.0
		if previous_node != null:
			prev_tip_delta = previous_node.tip_position_local.distance_to(motion_node.tip_position_local)
			prev_pommel_delta = previous_node.pommel_position_local.distance_to(motion_node.pommel_position_local)
			var previous_center: Vector3 = (previous_node.tip_position_local + previous_node.pommel_position_local) * 0.5
			prev_center_delta = previous_center.distance_to(center)
			if prev_tip_delta <= 0.000001:
				zero_tip_segments += 1
			if prev_pommel_delta <= 0.000001:
				zero_pommel_segments += 1
			if prev_center_delta <= 0.000001:
				zero_center_segments += 1
			if prev_tip_delta <= 0.000001 and prev_pommel_delta <= 0.000001:
				duplicate_neighbor_count += 1
		node_csv_lines.append("%s,%d,%s,%s,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%s,%s,%s,%s,%s,%.9f,%.9f,%.9f" % [
			phase_name,
			node_index,
			str(node_index == selected_index),
			String(motion_node.node_id),
			motion_node.tip_position_local.x,
			motion_node.tip_position_local.y,
			motion_node.tip_position_local.z,
			motion_node.pommel_position_local.x,
			motion_node.pommel_position_local.y,
			motion_node.pommel_position_local.z,
			motion_node.tip_position_local.distance_to(motion_node.pommel_position_local),
			center.x,
			center.y,
			center.z,
			motion_node.transition_duration_seconds,
			motion_node.body_support_blend,
			motion_node.right_upperarm_roll_degrees,
			motion_node.left_upperarm_roll_degrees,
			motion_node.weapon_roll_degrees,
			motion_node.axial_reposition_offset,
			motion_node.grip_seat_slide_offset,
			motion_node.secondary_grip_seat_slide_offset,
			String(motion_node.two_hand_state),
			String(motion_node.primary_hand_slot),
			String(motion_node.preferred_grip_style_mode),
			str(motion_node.generated_transition_node),
			str(motion_node.locked_for_authoring),
			prev_tip_delta,
			prev_pommel_delta,
			prev_center_delta,
		])
		previous_node = motion_node
	result_lines.append("%s_zero_tip_segments=%d" % [phase_name, zero_tip_segments])
	result_lines.append("%s_zero_pommel_segments=%d" % [phase_name, zero_pommel_segments])
	result_lines.append("%s_zero_center_segments=%d" % [phase_name, zero_center_segments])
	result_lines.append("%s_duplicate_neighbor_segments=%d" % [phase_name, duplicate_neighbor_count])

func _select_last_motion_node(ui: CombatAnimationStationUI) -> bool:
	if ui == null:
		return false
	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	if draft == null or draft.motion_node_chain.is_empty():
		return false
	return ui.select_motion_node(draft.motion_node_chain.size() - 1)

func _append_delta_report() -> void:
	result_lines.append("")
	result_lines.append("[cross_phase_deltas]")
	for snapshot_index: int in range(1, snapshots.size()):
		var previous: Dictionary = snapshots[snapshot_index - 1]
		var current: Dictionary = snapshots[snapshot_index]
		var phase_name: String = String(current.get("phase", "phase_%d" % snapshot_index))
		result_lines.append("%s_selected_tip_delta_from_previous=%.9f" % [
			phase_name,
			(previous.get("selected_tip", Vector3.ZERO) as Vector3).distance_to(current.get("selected_tip", Vector3.ZERO) as Vector3),
		])
		result_lines.append("%s_selected_pommel_delta_from_previous=%.9f" % [
			phase_name,
			(previous.get("selected_pommel", Vector3.ZERO) as Vector3).distance_to(current.get("selected_pommel", Vector3.ZERO) as Vector3),
		])
		result_lines.append("%s_display_tip_delta_from_previous=%.9f" % [
			phase_name,
			(previous.get("display_tip", Vector3.ZERO) as Vector3).distance_to(current.get("display_tip", Vector3.ZERO) as Vector3),
		])
		result_lines.append("%s_display_pommel_delta_from_previous=%.9f" % [
			phase_name,
			(previous.get("display_pommel", Vector3.ZERO) as Vector3).distance_to(current.get("display_pommel", Vector3.ZERO) as Vector3),
		])
		result_lines.append("%s_resolved_tip_delta_from_previous=%.9f" % [
			phase_name,
			(previous.get("resolved_tip", Vector3.ZERO) as Vector3).distance_to(current.get("resolved_tip", Vector3.ZERO) as Vector3),
		])
		result_lines.append("%s_resolved_pommel_delta_from_previous=%.9f" % [
			phase_name,
			(previous.get("resolved_pommel", Vector3.ZERO) as Vector3).distance_to(current.get("resolved_pommel", Vector3.ZERO) as Vector3),
		])
		result_lines.append("%s_dominant_error_delta_from_previous=%.9f" % [
			phase_name,
			float(current.get("dominant_error", -1.0)) - float(previous.get("dominant_error", -1.0)),
		])
		result_lines.append("%s_support_error_delta_from_previous=%.9f" % [
			phase_name,
			float(current.get("support_error", -1.0)) - float(previous.get("support_error", -1.0)),
		])

func _append_metric_dict(phase_name: String, label: String, metrics: Dictionary) -> void:
	if metrics.is_empty():
		result_lines.append("%s_%s_empty=true" % [phase_name, label])
		return
	for key: Variant in metrics.keys():
		var value: Variant = metrics.get(key)
		if value is Vector3:
			result_lines.append("%s_%s_%s=%s" % [phase_name, label, String(key), _fmt_vec(value as Vector3)])
		elif value is float:
			result_lines.append("%s_%s_%s=%.6f" % [phase_name, label, String(key), float(value)])
		elif value is int:
			result_lines.append("%s_%s_%s=%d" % [phase_name, label, String(key), int(value)])
		elif value is bool:
			result_lines.append("%s_%s_%s=%s" % [phase_name, label, String(key), str(bool(value))])
		elif value is StringName:
			result_lines.append("%s_%s_%s=%s" % [phase_name, label, String(key), String(value)])
		elif value is String:
			result_lines.append("%s_%s_%s=%s" % [phase_name, label, String(key), String(value)])

func _append_trace_lines(target: Object, phase_name: String, label: String, meta_name: String) -> void:
	if target == null or not target.has_meta(meta_name):
		result_lines.append("%s_%s_trace_available=false" % [phase_name, label])
		return
	var trace: Array = target.get_meta(meta_name, []) as Array
	result_lines.append("%s_%s_trace_available=true" % [phase_name, label])
	for trace_index: int in range(trace.size()):
		result_lines.append("%s_%s_trace_%d=%s" % [
			phase_name,
			label,
			trace_index,
			String(trace[trace_index]),
		])

func _find_saved_wip_by_project_names(library_state: PlayerForgeWipLibraryState, project_names: Array) -> CraftedItemWIP:
	if library_state == null:
		return null
	for target_name: Variant in project_names:
		var exact_match: CraftedItemWIP = _find_saved_wip_by_project_name(library_state, String(target_name))
		if exact_match != null:
			return exact_match
	var normalized_targets: Array[String] = []
	for target_name: Variant in project_names:
		normalized_targets.append(_normalize_name(String(target_name)))
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip == null:
			continue
		if normalized_targets.has(_normalize_name(saved_wip.forge_project_name)):
			return saved_wip
	return null

func _find_saved_wip_by_project_name(library_state: PlayerForgeWipLibraryState, project_name: String) -> CraftedItemWIP:
	if library_state == null:
		return null
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip != null and saved_wip.forge_project_name == project_name:
			return saved_wip
	return null

func _normalize_name(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "").replace("_", "").replace("-", "")

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

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 1)):
		await process_frame

func _elapsed_ms(start_usec: int, end_usec: int) -> float:
	return float(end_usec - start_usec) / 1000.0

func _fmt_vec(value: Vector3) -> String:
	return "(%.6f, %.6f, %.6f)" % [value.x, value.y, value.z]

func _fmt_basis(value: Basis) -> String:
	var basis: Basis = value.orthonormalized()
	return "x=%s y=%s z=%s" % [_fmt_vec(basis.x), _fmt_vec(basis.y), _fmt_vec(basis.z)]

func _write_outputs() -> void:
	var result_file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if result_file != null:
		result_file.store_string("\n".join(result_lines))
	var csv_file := FileAccess.open(NODE_CSV_FILE_PATH, FileAccess.WRITE)
	if csv_file != null:
		csv_file.store_string("\n".join(node_csv_lines))
