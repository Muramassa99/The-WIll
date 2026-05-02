extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const CombatAnimationSessionStateScript = preload("res://core/models/combat_animation_session_state.gd")

const TARGET_PROJECT_NAME := "Test sword for animations"
const RESULT_FILE_PATH := "C:/WORKSPACE/skill_slot_1_space_focus_cycle_results.txt"
const SAMPLE_FILE_PATH := "C:/WORKSPACE/skill_slot_1_space_focus_cycle_samples.csv"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_skill_slot_1_space_focus_cycle_library.tres"
const OBSERVE_SECONDS_PER_PRESS := 1.0
const SAMPLE_INTERVAL_SECONDS := 1.0 / 60.0
const PRESS_COUNT := 3

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

var result_lines: PackedStringArray = []
var sample_lines: PackedStringArray = []
var previous_weapon_position: Vector3 = Vector3.INF
var previous_weapon_basis: Basis = Basis.IDENTITY
var has_previous_weapon_basis: bool = false
var sample_index: int = 0
var total_seconds: float = 0.0
var current_press: int = 0

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	sample_lines.append(
		"sample,total_seconds,press,press_seconds,focus,selected_index,node_grip,node_tip,node_pommel,resolved_tip,resolved_pommel,display_tip,display_pommel,weapon_pos,weapon_step,weapon_basis_step_degrees,dominant_error,dominant_finger_distance,dominant_readiness,collision_pose_legal,body_self_legal,right_hand_y_forearm_dot,left_hand_y_forearm_dot,right_hand_x_tip_plane_dot,left_hand_x_tip_plane_dot"
	)
	result_lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)
	result_lines.append("target_slot=skill_slot_1")
	result_lines.append("start_focus=pommel")
	result_lines.append("space_press_count=%d" % PRESS_COUNT)
	result_lines.append("observe_seconds_per_press=%.4f" % OBSERVE_SECONDS_PER_PRESS)

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
	diagnostic_wip.wip_id = StringName("%s_space_focus_cycle" % String(source_wip.wip_id))
	diagnostic_wip.forge_project_name = "%s Space Focus Cycle Diagnostic" % source_wip.forge_project_name
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
	ui.open_for(fake_player, "Skill Slot 1 Space Focus Diagnostic")
	await _wait_frames(8)
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(diagnostic_wip.wip_id, &"hand_right", false, false)
	await _wait_frames(8)
	var select_slot_ok: bool = ui.select_skill_slot(&"skill_slot_1", true)
	await _wait_frames(6)
	if ui.session_state != null:
		ui.session_state.current_focus = CombatAnimationSessionStateScript.FOCUS_POMMEL
		ui.call("_refresh_focus_indicators")
		ui.call("_refresh_preview_scene")
	await _wait_frames(4)

	result_lines.append("diagnostic_save_path=%s" % TEMP_SAVE_FILE_PATH)
	result_lines.append("source_wip_id=%s" % String(source_wip.wip_id))
	result_lines.append("diagnostic_wip_id=%s" % String(diagnostic_wip.wip_id))
	result_lines.append("open_ok=%s" % str(open_ok))
	result_lines.append("select_skill_slot_1_ok=%s" % str(select_slot_ok))
	result_lines.append_array(_snapshot_lines(ui, "initial"))
	_sample_ui(ui, 0.0)

	for press_index: int in range(PRESS_COUNT):
		current_press = press_index + 1
		ui.call("_cycle_focus")
		await _wait_frames(2)
		result_lines.append_array(_snapshot_lines(ui, "after_space_%d_immediate" % current_press))
		await _observe(ui, OBSERVE_SECONDS_PER_PRESS)
		result_lines.append_array(_snapshot_lines(ui, "after_space_%d_observed" % current_press))

	result_lines.append("sample_count=%d" % sample_index)
	result_lines.append("observed_seconds=%.4f" % total_seconds)
	_write_outputs()
	quit()

func _observe(ui: CombatAnimationStationUI, seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		await create_timer(SAMPLE_INTERVAL_SECONDS).timeout
		elapsed += SAMPLE_INTERVAL_SECONDS
		total_seconds += SAMPLE_INTERVAL_SECONDS
		_sample_ui(ui, elapsed)

func _sample_ui(ui: CombatAnimationStationUI, press_seconds: float) -> void:
	sample_index += 1
	var actor: Node3D = _get_preview_actor(ui)
	var held_item: Node3D = _get_preview_held_item(ui)
	var skeleton: Skeleton3D = actor.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if actor != null else null
	var motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var debug_state: Dictionary = ui.get_preview_debug_state()
	var weapon_position: Vector3 = held_item.global_position if held_item != null else Vector3.ZERO
	var weapon_step: float = 0.0
	if previous_weapon_position != Vector3.INF:
		weapon_step = previous_weapon_position.distance_to(weapon_position)
	previous_weapon_position = weapon_position
	var basis_step_degrees: float = 0.0
	if held_item != null:
		if has_previous_weapon_basis:
			basis_step_degrees = rad_to_deg(previous_weapon_basis.get_rotation_quaternion().angle_to(held_item.global_basis.get_rotation_quaternion()))
		previous_weapon_basis = held_item.global_basis
		has_previous_weapon_basis = true
	var grip_to_tip_world: Vector3 = _resolve_grip_to_tip_axis(held_item)
	var right_hand_basis: Basis = _get_bone_world_basis(skeleton, "CC_Base_R_Hand")
	var left_hand_basis: Basis = _get_bone_world_basis(skeleton, "CC_Base_L_Hand")
	var right_hand_y_forearm_dot: float = _resolve_hand_y_forearm_dot(skeleton, "CC_Base_R_Hand", "CC_Base_R_Forearm", right_hand_basis)
	var left_hand_y_forearm_dot: float = _resolve_hand_y_forearm_dot(skeleton, "CC_Base_L_Hand", "CC_Base_L_Forearm", left_hand_basis)
	var right_hand_x_tip_plane_dot: float = _resolve_hand_x_tip_plane_dot(right_hand_basis, grip_to_tip_world)
	var left_hand_x_tip_plane_dot: float = _resolve_hand_x_tip_plane_dot(left_hand_basis, grip_to_tip_world)
	sample_lines.append("%d,%.4f,%d,%.4f,%s,%d,%s,%s,%s,%s,%s,%s,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%s,%s,%.6f,%.6f,%.6f,%.6f" % [
		sample_index,
		total_seconds,
		current_press,
		press_seconds,
		String(ui.session_state.current_focus if ui.session_state != null else StringName()),
		ui.get_selected_motion_node_index(),
		String(motion_node.preferred_grip_style_mode if motion_node != null else StringName()),
		_fmt_vec(motion_node.tip_position_local if motion_node != null else Vector3.ZERO),
		_fmt_vec(motion_node.pommel_position_local if motion_node != null else Vector3.ZERO),
		_fmt_vec(debug_state.get("resolved_tip_position_local", Vector3.ZERO) as Vector3),
		_fmt_vec(debug_state.get("resolved_pommel_position_local", Vector3.ZERO) as Vector3),
		_fmt_vec(debug_state.get("display_selected_tip_position_local", Vector3.ZERO) as Vector3),
		_fmt_vec(debug_state.get("display_selected_pommel_position_local", Vector3.ZERO) as Vector3),
		_fmt_vec(weapon_position),
		weapon_step,
		basis_step_degrees,
		float(debug_state.get("dominant_grip_alignment_error_meters", -1.0)),
		float(debug_state.get("dominant_finger_contact_distance_meters", -1.0)),
		float(debug_state.get("dominant_finger_contact_readiness", -1.0)),
		str(bool(debug_state.get("collision_pose_legal", true))),
		str(bool(debug_state.get("body_self_collision_legal", true))),
		right_hand_y_forearm_dot,
		left_hand_y_forearm_dot,
		right_hand_x_tip_plane_dot,
		left_hand_x_tip_plane_dot,
	])

func _snapshot_lines(ui: CombatAnimationStationUI, prefix: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	var held_item: Node3D = _get_preview_held_item(ui)
	var motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var debug_state: Dictionary = ui.get_preview_debug_state()
	lines.append("%s_focus=%s" % [prefix, String(ui.session_state.current_focus if ui.session_state != null else StringName())])
	lines.append("%s_selected_motion_node_index=%d" % [prefix, ui.get_selected_motion_node_index()])
	if motion_node != null:
		lines.append("%s_node_tip_position_local=%s" % [prefix, str(motion_node.tip_position_local)])
		lines.append("%s_node_pommel_position_local=%s" % [prefix, str(motion_node.pommel_position_local)])
		lines.append("%s_node_weapon_orientation_degrees=%s" % [prefix, str(motion_node.weapon_orientation_degrees)])
		lines.append("%s_node_preferred_grip_style=%s" % [prefix, String(motion_node.preferred_grip_style_mode)])
	lines.append("%s_resolved_tip_position_local=%s" % [prefix, str(debug_state.get("resolved_tip_position_local", Vector3.ZERO))])
	lines.append("%s_resolved_pommel_position_local=%s" % [prefix, str(debug_state.get("resolved_pommel_position_local", Vector3.ZERO))])
	lines.append("%s_display_tip_position_local=%s" % [prefix, str(debug_state.get("display_selected_tip_position_local", Vector3.ZERO))])
	lines.append("%s_display_pommel_position_local=%s" % [prefix, str(debug_state.get("display_selected_pommel_position_local", Vector3.ZERO))])
	lines.append("%s_weapon_position=%s" % [prefix, str(held_item.global_position if held_item != null else Vector3.ZERO)])
	lines.append("%s_dominant_grip_error=%.6f" % [prefix, float(debug_state.get("dominant_grip_alignment_error_meters", -1.0))])
	lines.append("%s_collision_pose_legal=%s" % [prefix, str(bool(debug_state.get("collision_pose_legal", true)))])
	lines.append("%s_body_self_collision_legal=%s" % [prefix, str(bool(debug_state.get("body_self_collision_legal", true)))])
	return lines

func _find_saved_wip_by_project_name(library: PlayerForgeWipLibraryState, project_name: String) -> CraftedItemWIP:
	if library == null:
		return null
	for wip_variant: Variant in library.saved_wips:
		var wip: CraftedItemWIP = wip_variant as CraftedItemWIP
		if wip != null and wip.forge_project_name == project_name:
			return wip
	return null

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

func _get_bone_world_basis(skeleton: Skeleton3D, bone_name: String) -> Basis:
	if skeleton == null:
		return Basis.IDENTITY
	var bone_index: int = skeleton.find_bone(bone_name)
	if bone_index < 0:
		return Basis.IDENTITY
	return (skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)).basis.orthonormalized()

func _resolve_hand_y_forearm_dot(skeleton: Skeleton3D, hand_bone: String, forearm_bone: String, hand_basis: Basis) -> float:
	if skeleton == null:
		return 0.0
	var hand_index: int = skeleton.find_bone(hand_bone)
	var forearm_index: int = skeleton.find_bone(forearm_bone)
	if hand_index < 0 or forearm_index < 0:
		return 0.0
	var hand_position: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)).origin
	var forearm_position: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(forearm_index)).origin
	var forearm_to_hand: Vector3 = hand_position - forearm_position
	if forearm_to_hand.length_squared() <= 0.000001:
		return 0.0
	return forearm_to_hand.normalized().dot(hand_basis.y.normalized())

func _resolve_hand_x_tip_plane_dot(hand_basis: Basis, grip_to_tip_world: Vector3) -> float:
	if grip_to_tip_world.length_squared() <= 0.000001:
		return 0.0
	var y_axis: Vector3 = hand_basis.y.normalized()
	var x_axis: Vector3 = hand_basis.x.normalized()
	var projected_tip_axis: Vector3 = grip_to_tip_world - y_axis * grip_to_tip_world.dot(y_axis)
	if projected_tip_axis.length_squared() <= 0.000001:
		return 0.0
	return projected_tip_axis.normalized().dot(x_axis)

func _resolve_grip_to_tip_axis(held_item: Node3D) -> Vector3:
	if held_item == null:
		return Vector3.ZERO
	var primary_grip: Node3D = held_item.get_node_or_null("PrimaryGripAnchor") as Node3D
	var local_tip: Vector3 = held_item.get_meta("weapon_tip_local", Vector3.ZERO) as Vector3
	var tip_world: Vector3 = held_item.to_global(local_tip)
	var grip_world: Vector3 = primary_grip.global_position if primary_grip != null else held_item.global_position
	var axis: Vector3 = tip_world - grip_world
	return axis.normalized() if axis.length_squared() > 0.000001 else Vector3.ZERO

func _fmt_vec(value: Vector3) -> String:
	return "(%.5f %.5f %.5f)" % [value.x, value.y, value.z]

func _wait_frames(frame_count: int) -> void:
	for _index: int in range(maxi(frame_count, 0)):
		await process_frame

func _write_outputs() -> void:
	var result_file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if result_file != null:
		result_file.store_string("\n".join(result_lines))
	var sample_file := FileAccess.open(SAMPLE_FILE_PATH, FileAccess.WRITE)
	if sample_file != null:
		sample_file.store_string("\n".join(sample_lines))
