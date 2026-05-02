extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")

const TARGET_PROJECT_NAME := "Test sword for animations"
const RESULT_FILE_PATH := "C:/WORKSPACE/combat_idle_reset_shake_results.txt"
const SAMPLE_FILE_PATH := "C:/WORKSPACE/combat_idle_reset_shake_samples.csv"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_combat_idle_reset_shake_library.tres"
const SAMPLE_INTERVAL_SECONDS := 1.0 / 60.0
const OBSERVE_SECONDS_PER_RESET := 3.0
const RESET_COUNT := 3

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
var previous_vectors: Dictionary = {}
var previous_bases: Dictionary = {}
var sample_lines: PackedStringArray = []
var reset_lines: PackedStringArray = []
var current_sample_index: int = 0
var current_phase_index: int = 0
var current_phase_seconds: float = 0.0
var current_total_seconds: float = 0.0

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	sample_lines.append(
		"sample,total_seconds,phase,phase_seconds,weapon_pos,right_hand,left_hand,right_ik,left_ik,right_target_error,left_target_error,dominant_error,support_error,right_guidance,left_guidance,right_ik_active,left_ik_active"
	)

	var source_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var source_wip: CraftedItemWIP = _find_saved_wip_by_project_name(source_library, TARGET_PROJECT_NAME)
	var lines: PackedStringArray = []
	lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)
	lines.append("source_library_loaded=%s" % str(source_library != null))
	lines.append("source_wip_found=%s" % str(source_wip != null))
	if source_wip == null:
		_write_results(lines)
		quit()
		return

	var temp_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	temp_library.save_file_path = TEMP_SAVE_FILE_PATH
	temp_library.saved_wips.clear()
	var diagnostic_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
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
	ui.open_for(fake_player, "Idle Reset Shake Diagnostic")
	await _wait_frames(6)

	var select_idle_mode_ok: bool = ui.select_authoring_mode(CombatAnimationStationStateScript.AUTHORING_MODE_IDLE)
	await _wait_frames(3)
	var select_combat_idle_ok: bool = ui.select_draft(CombatAnimationStationStateScript.IDLE_CONTEXT_COMBAT, true)
	await _wait_frames(3)

	lines.append("diagnostic_save_path=%s" % TEMP_SAVE_FILE_PATH)
	lines.append("source_wip_id=%s" % String(source_wip.wip_id))
	lines.append("opened_wip_id=%s" % String(ui.get_active_saved_wip_id()))
	lines.append("select_idle_mode_ok=%s" % str(select_idle_mode_ok))
	lines.append("select_combat_idle_ok=%s" % str(select_combat_idle_ok))
	lines.append("active_draft_identifier=%s" % String(ui.get_active_draft_identifier()))
	lines.append("active_open_slot=%s" % String(ui.get_active_open_dominant_slot_id()))
	lines.append("active_open_two_hand=%s" % str(ui.is_active_open_two_hand()))
	lines.append("selected_motion_node_index=%d" % ui.get_selected_motion_node_index())
	lines.append_array(_build_motion_node_report(ui, "before_reset"))

	_sample_ui(ui)
	for reset_index: int in range(RESET_COUNT):
		current_phase_index = reset_index + 1
		current_phase_seconds = 0.0
		var reset_ok: bool = ui.reset_active_draft_to_baseline()
		await _wait_frames(2)
		reset_lines.append("reset_%d_ok=%s" % [reset_index + 1, str(reset_ok)])
		reset_lines.append_array(_build_motion_node_report(ui, "after_reset_%d" % (reset_index + 1)))
		_sample_ui(ui)
		await _observe(ui, OBSERVE_SECONDS_PER_RESET)

	lines.append_array(reset_lines)
	lines.append("sample_count=%d" % current_sample_index)
	lines.append("observed_seconds=%.4f" % current_total_seconds)
	lines.append_array(_build_stat_lines())

	var final_debug: Dictionary = ui.get_preview_debug_state()
	var final_grip_debug: Dictionary = final_debug.get("grip_contact_debug_state", {}) as Dictionary
	lines.append("final_dominant_slot_id=%s" % String(final_debug.get("dominant_slot_id", StringName())))
	lines.append("final_default_two_hand=%s" % str(bool(final_debug.get("default_two_hand", false))))
	lines.append("final_dominant_grip_alignment_error_meters=%.6f" % float(final_debug.get("dominant_grip_alignment_error_meters", -1.0)))
	lines.append("final_support_grip_alignment_error_meters=%.6f" % float(final_debug.get("support_grip_alignment_error_meters", -1.0)))
	lines.append("final_right_arm_guidance_active=%s" % str(bool(final_grip_debug.get("right_arm_guidance_active", false))))
	lines.append("final_left_arm_guidance_active=%s" % str(bool(final_grip_debug.get("left_arm_guidance_active", false))))
	lines.append("final_right_arm_ik_active=%s" % str(bool(final_grip_debug.get("right_arm_ik_active", false))))
	lines.append("final_left_arm_ik_active=%s" % str(bool(final_grip_debug.get("left_arm_ik_active", false))))
	lines.append("final_right_hand_ik_distance_meters=%.6f" % float(final_grip_debug.get("right_hand_ik_target_distance_meters", -1.0)))
	lines.append("final_left_hand_ik_distance_meters=%.6f" % float(final_grip_debug.get("left_hand_ik_target_distance_meters", -1.0)))

	_write_results(lines)
	var sample_file: FileAccess = FileAccess.open(SAMPLE_FILE_PATH, FileAccess.WRITE)
	if sample_file != null:
		sample_file.store_string("\n".join(sample_lines))
		sample_file.close()
	quit()

func _observe(ui: CombatAnimationStationUI, seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		await create_timer(SAMPLE_INTERVAL_SECONDS).timeout
		elapsed += SAMPLE_INTERVAL_SECONDS
		current_phase_seconds = elapsed
		current_total_seconds += SAMPLE_INTERVAL_SECONDS
		_sample_ui(ui)

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame

func _sample_ui(ui: CombatAnimationStationUI) -> void:
	current_sample_index += 1
	var preview_subviewport: SubViewport = ui.preview_subviewport
	var preview_root: Node3D = preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D if preview_subviewport != null else null
	var actor: Node3D = preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D if preview_root != null else null
	var held_item: Node3D = preview_root.get_meta("preview_held_item", null) as Node3D if preview_root != null else null
	var skeleton: Skeleton3D = actor.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if actor != null else null
	var right_ik: Node3D = actor.get_node_or_null("IkTargets/RightHandIkTarget") as Node3D if actor != null else null
	var left_ik: Node3D = actor.get_node_or_null("IkTargets/LeftHandIkTarget") as Node3D if actor != null else null
	var right_hand_anchor: Node3D = actor.call("get_right_hand_item_anchor") as Node3D if actor != null and actor.has_method("get_right_hand_item_anchor") else null
	var left_hand_anchor: Node3D = actor.call("get_left_hand_item_anchor") as Node3D if actor != null and actor.has_method("get_left_hand_item_anchor") else null
	var primary_grip_anchor: Node3D = held_item.find_child("PrimaryGripAnchor", true, false) as Node3D if held_item != null else null
	var support_grip_anchor: Node3D = held_item.find_child("SecondaryGripAnchor", true, false) as Node3D if held_item != null else null

	var right_hand_world: Vector3 = _get_bone_world_position(skeleton, "CC_Base_R_Hand")
	var left_hand_world: Vector3 = _get_bone_world_position(skeleton, "CC_Base_L_Hand")
	var right_forearm_world: Vector3 = _get_bone_world_position(skeleton, "CC_Base_R_Forearm")
	var left_forearm_world: Vector3 = _get_bone_world_position(skeleton, "CC_Base_L_Forearm")
	var right_upperarm_world: Vector3 = _get_bone_world_position(skeleton, "CC_Base_R_Upperarm")
	var left_upperarm_world: Vector3 = _get_bone_world_position(skeleton, "CC_Base_L_Upperarm")
	var right_clavicle_world: Vector3 = _get_bone_world_position(skeleton, "CC_Base_R_Clavicle")
	var left_clavicle_world: Vector3 = _get_bone_world_position(skeleton, "CC_Base_L_Clavicle")
	var weapon_pos: Vector3 = held_item.global_position if held_item != null else Vector3.ZERO
	var right_ik_pos: Vector3 = right_ik.global_position if right_ik != null else Vector3.ZERO
	var left_ik_pos: Vector3 = left_ik.global_position if left_ik != null else Vector3.ZERO
	var right_anchor_pos: Vector3 = right_hand_anchor.global_position if right_hand_anchor != null else Vector3.ZERO
	var left_anchor_pos: Vector3 = left_hand_anchor.global_position if left_hand_anchor != null else Vector3.ZERO
	var primary_grip_pos: Vector3 = primary_grip_anchor.global_position if primary_grip_anchor != null else Vector3.ZERO
	var support_grip_pos: Vector3 = support_grip_anchor.global_position if support_grip_anchor != null else Vector3.ZERO

	_record_vector("weapon_position", weapon_pos)
	_record_vector("right_hand_bone", right_hand_world)
	_record_vector("left_hand_bone", left_hand_world)
	_record_vector("right_forearm_bone", right_forearm_world)
	_record_vector("left_forearm_bone", left_forearm_world)
	_record_vector("right_upperarm_bone", right_upperarm_world)
	_record_vector("left_upperarm_bone", left_upperarm_world)
	_record_vector("right_clavicle_bone", right_clavicle_world)
	_record_vector("left_clavicle_bone", left_clavicle_world)
	_record_vector("right_ik_target", right_ik_pos)
	_record_vector("left_ik_target", left_ik_pos)
	_record_vector("right_hand_anchor", right_anchor_pos)
	_record_vector("left_hand_anchor", left_anchor_pos)
	_record_vector("primary_grip_anchor", primary_grip_pos)
	_record_vector("support_grip_anchor", support_grip_pos)
	if held_item != null:
		_record_basis("weapon_basis", held_item.global_basis)
	if skeleton != null:
		_record_basis("right_hand_basis", _get_bone_world_basis(skeleton, "CC_Base_R_Hand"))
		_record_basis("left_hand_basis", _get_bone_world_basis(skeleton, "CC_Base_L_Hand"))
		_record_basis("right_forearm_basis", _get_bone_world_basis(skeleton, "CC_Base_R_Forearm"))
		_record_basis("left_forearm_basis", _get_bone_world_basis(skeleton, "CC_Base_L_Forearm"))

	var debug_state: Dictionary = ui.get_preview_debug_state()
	var grip_debug: Dictionary = debug_state.get("grip_contact_debug_state", {}) as Dictionary
	var right_target_error: float = right_hand_world.distance_to(right_ik_pos) if right_ik != null else -1.0
	var left_target_error: float = left_hand_world.distance_to(left_ik_pos) if left_ik != null else -1.0
	sample_lines.append("%d,%.4f,%d,%.4f,%s,%s,%s,%s,%s,%.6f,%.6f,%.6f,%.6f,%s,%s,%s,%s" % [
		current_sample_index,
		current_total_seconds,
		current_phase_index,
		current_phase_seconds,
		_fmt_vec(weapon_pos),
		_fmt_vec(right_hand_world),
		_fmt_vec(left_hand_world),
		_fmt_vec(right_ik_pos),
		_fmt_vec(left_ik_pos),
		right_target_error,
		left_target_error,
		float(debug_state.get("dominant_grip_alignment_error_meters", -1.0)),
		float(debug_state.get("support_grip_alignment_error_meters", -1.0)),
		str(bool(grip_debug.get("right_arm_guidance_active", false))),
		str(bool(grip_debug.get("left_arm_guidance_active", false))),
		str(bool(grip_debug.get("right_arm_ik_active", false))),
		str(bool(grip_debug.get("left_arm_ik_active", false))),
	])

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
	return lines

func _build_motion_node_report(ui: CombatAnimationStationUI, prefix: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	var draft: Resource = ui.call("_get_active_draft") as Resource
	var motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	lines.append("%s_draft_exists=%s" % [prefix, str(draft != null)])
	lines.append("%s_motion_node_exists=%s" % [prefix, str(motion_node != null)])
	if draft != null:
		lines.append("%s_draft_id=%s" % [prefix, String(draft.get("draft_id"))])
		lines.append("%s_display_name=%s" % [prefix, String(draft.get("display_name"))])
		lines.append("%s_context_id=%s" % [prefix, String(draft.get("context_id"))])
		lines.append("%s_motion_node_count=%d" % [prefix, int((draft.get("motion_node_chain") as Array).size())])
	if motion_node != null:
		lines.append("%s_tip_position_local=%s" % [prefix, str(motion_node.tip_position_local)])
		lines.append("%s_pommel_position_local=%s" % [prefix, str(motion_node.pommel_position_local)])
		lines.append("%s_weapon_orientation_degrees=%s" % [prefix, str(motion_node.weapon_orientation_degrees)])
		lines.append("%s_weapon_roll_degrees=%.6f" % [prefix, motion_node.weapon_roll_degrees])
		lines.append("%s_two_hand_state=%s" % [prefix, String(motion_node.two_hand_state)])
		lines.append("%s_primary_hand_slot=%s" % [prefix, String(motion_node.primary_hand_slot)])
		lines.append("%s_body_support_blend=%.6f" % [prefix, motion_node.body_support_blend])
	return lines

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
	return Vector3(
		minf(first.x, second.x),
		minf(first.y, second.y),
		minf(first.z, second.z)
	)

func _max_vec(first: Vector3, second: Vector3) -> Vector3:
	return Vector3(
		maxf(first.x, second.x),
		maxf(first.y, second.y),
		maxf(first.z, second.z)
	)

func _fmt_vec(value: Vector3) -> String:
	return "\"(%.5f %.5f %.5f)\"" % [value.x, value.y, value.z]

func _write_results(lines: PackedStringArray) -> void:
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
