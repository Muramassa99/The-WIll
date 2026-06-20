extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/arm_authority_layer_isolation_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_arm_authority_layer_isolation_library.tres"
const TARGET_PROJECT_NAME := "Test sword for animations"
const TARGET_SLOT_ID: StringName = &"skill_slot_1"
const DOMINANT_SLOT_ID: StringName = &"hand_right"

const RIGHT_AXIS_BONES := [
	"CC_Base_R_Upperarm",
	"CC_Base_R_UpperarmTwist01",
	"CC_Base_R_UpperarmTwist02",
	"CC_Base_R_Forearm",
	"CC_Base_R_ForearmTwist01",
	"CC_Base_R_ForearmTwist02",
	"CC_Base_R_Hand",
]

const REFERENCE_SEGMENTS := {
	"CC_Base_R_Upperarm": ["CC_Base_R_Upperarm", "CC_Base_R_Forearm"],
	"CC_Base_R_UpperarmTwist01": ["CC_Base_R_Upperarm", "CC_Base_R_Forearm"],
	"CC_Base_R_UpperarmTwist02": ["CC_Base_R_Upperarm", "CC_Base_R_Forearm"],
	"CC_Base_R_Forearm": ["CC_Base_R_Forearm", "CC_Base_R_Hand"],
	"CC_Base_R_ForearmTwist01": ["CC_Base_R_Forearm", "CC_Base_R_Hand"],
	"CC_Base_R_ForearmTwist02": ["CC_Base_R_Forearm", "CC_Base_R_Hand"],
	"CC_Base_R_Hand": ["CC_Base_R_Forearm", "CC_Base_R_Hand"],
}

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

var lines: PackedStringArray = []
var diagnostic_library: PlayerForgeWipLibraryState = null
var diagnostic_wip: CraftedItemWIP = null

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	lines.append("audit_scope=arm_authority_layer_isolation")
	lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)
	if not _prepare_diagnostic_wip():
		_write_results()
		quit()
		return
	var scenarios := [
		{"name": "baseline_all_authoring_layers"},
		{"name": "no_limb_twist_distribution", "disable_limb_twist": true},
		{"name": "no_contact_wrist_basis", "disable_contact_wrist_basis": true},
		{"name": "no_upper_body_pose", "disable_upper_body": true},
		{"name": "no_finger_ik", "disable_finger_ik": true},
		{"name": "no_support_ik_target_solver", "disable_support_ik": true},
		{"name": "no_contact_basis_no_limb_twist", "disable_contact_wrist_basis": true, "disable_limb_twist": true},
		{"name": "no_upper_body_no_limb_twist", "disable_upper_body": true, "disable_limb_twist": true},
	]
	for scenario: Dictionary in scenarios:
		await _run_scenario(scenario)
	_write_results()
	quit()

func _prepare_diagnostic_wip() -> bool:
	var source_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var source_wip: CraftedItemWIP = _find_saved_wip_by_project_name(source_library, TARGET_PROJECT_NAME)
	lines.append("source_library_loaded=%s" % str(source_library != null))
	lines.append("source_wip_found=%s" % str(source_wip != null))
	if source_wip == null:
		return false
	diagnostic_library = PlayerForgeWipLibraryStateScript.new()
	diagnostic_library.save_file_path = TEMP_SAVE_FILE_PATH
	diagnostic_library.saved_wips.clear()
	diagnostic_wip = source_wip.duplicate(true) as CraftedItemWIP
	diagnostic_wip.wip_id = StringName("%s_authority_layer_isolation" % String(source_wip.wip_id))
	diagnostic_wip.forge_project_name = "%s Authority Layer Isolation Diagnostic" % source_wip.forge_project_name
	diagnostic_wip.ensure_combat_animation_station_state()
	diagnostic_library.saved_wips.append(diagnostic_wip)
	diagnostic_library.selected_wip_id = diagnostic_wip.wip_id
	diagnostic_library.persist()
	lines.append("diagnostic_save_path=%s" % TEMP_SAVE_FILE_PATH)
	lines.append("diagnostic_wip_id=%s" % String(diagnostic_wip.wip_id))
	return true

func _run_scenario(scenario: Dictionary) -> void:
	var scenario_name: String = String(scenario.get("name", "unnamed"))
	lines.append("")
	lines.append("[%s]" % scenario_name)
	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = diagnostic_library
	root.add_child(fake_player)
	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Arm Authority Layer Isolation")
	await _wait_frames(8)
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(diagnostic_wip.wip_id, DOMINANT_SLOT_ID, false, false)
	await _wait_frames(8)
	var select_slot_ok: bool = ui.select_skill_slot(TARGET_SLOT_ID, true)
	await _wait_frames(8)
	_select_first_visible_skill_node(ui)
	await _wait_frames(4)
	_apply_scenario_flags(_get_preview_actor(ui), scenario)
	var reset_ok: bool = ui.reset_active_draft_to_baseline()
	await _wait_frames(8)
	_select_first_visible_skill_node(ui)
	await _wait_frames(2)
	_apply_scenario_flags(_get_preview_actor(ui), scenario)
	ui.call("_refresh_preview_scene")
	await _wait_frames(10)
	_select_first_visible_skill_node(ui)
	await _wait_frames(2)
	lines.append("%s_open_ok=%s" % [scenario_name, str(open_ok)])
	lines.append("%s_select_skill_slot_1_ok=%s" % [scenario_name, str(select_slot_ok)])
	lines.append("%s_reset_ok=%s" % [scenario_name, str(reset_ok)])
	_capture_scenario_result(ui, scenario_name)
	ui.queue_free()
	fake_player.queue_free()
	await _wait_frames(2)

func _apply_scenario_flags(actor: Node3D, scenario: Dictionary) -> void:
	var rig: PlayerHumanoidRig = actor as PlayerHumanoidRig
	if rig == null:
		return
	rig.enable_authoring_limb_twist_distribution = not bool(scenario.get("disable_limb_twist", false))
	rig.enable_authoring_contact_wrist_basis = not bool(scenario.get("disable_contact_wrist_basis", false))
	rig.enable_upper_body_authoring_pose = not bool(scenario.get("disable_upper_body", false))
	rig.enable_finger_grip_ik = not bool(scenario.get("disable_finger_ik", false))
	rig.enable_support_arm_ik = not bool(scenario.get("disable_support_ik", false))

func _capture_scenario_result(ui: CombatAnimationStationUI, prefix: String) -> void:
	var actor: Node3D = _get_preview_actor(ui)
	var rig: PlayerHumanoidRig = actor as PlayerHumanoidRig
	var skeleton: Skeleton3D = actor.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if actor != null else null
	var debug_state: Dictionary = ui.get_preview_debug_state()
	var grip_debug: Dictionary = debug_state.get("grip_contact_debug_state", {}) as Dictionary
	lines.append("%s_actor_exists=%s" % [prefix, str(actor != null)])
	lines.append("%s_enable_upper_body_authoring_pose=%s" % [prefix, str(rig.enable_upper_body_authoring_pose if rig != null else false)])
	lines.append("%s_enable_contact_wrist_basis=%s" % [prefix, str(rig.enable_authoring_contact_wrist_basis if rig != null else false)])
	lines.append("%s_enable_limb_twist_distribution=%s" % [prefix, str(rig.enable_authoring_limb_twist_distribution if rig != null else false)])
	lines.append("%s_enable_support_arm_ik=%s" % [prefix, str(rig.enable_support_arm_ik if rig != null else false)])
	lines.append("%s_enable_finger_grip_ik=%s" % [prefix, str(rig.enable_finger_grip_ik if rig != null else false)])
	lines.append("%s_dominant_grip_error_m=%.6f" % [prefix, float(debug_state.get("dominant_grip_alignment_error_meters", -1.0))])
	lines.append("%s_collision_pose_legal=%s" % [prefix, str(bool(debug_state.get("collision_pose_legal", true)))])
	lines.append("%s_body_self_collision_legal=%s" % [prefix, str(bool(debug_state.get("body_self_collision_legal", true)))])
	lines.append("%s_right_twist_requested_deg=%.6f" % [prefix, float(grip_debug.get("right_authoring_twist_requested_degrees", 0.0))])
	lines.append("%s_right_forearm_twist_applied_deg=%.6f" % [prefix, float(grip_debug.get("right_authoring_forearm_twist_applied_degrees", 0.0))])
	lines.append("%s_right_upperarm_twist_applied_deg=%.6f" % [prefix, float(grip_debug.get("right_authoring_upperarm_twist_applied_degrees", 0.0))])
	lines.append("%s_right_twist_bone_applied_count=%d" % [prefix, int(grip_debug.get("right_authoring_twist_bone_applied_count", 0))])
	for bone_name_variant: Variant in RIGHT_AXIS_BONES:
		var bone_name := String(bone_name_variant)
		var summary: Dictionary = _capture_bone_axis_summary(skeleton, bone_name)
		lines.append(
			"%s_%s_current_best=%s current_dots=%s local_pose_delta_deg=%.4f" % [
				prefix,
				bone_name,
				String(summary.get("best_axis", "")),
				str(summary.get("dots", {})),
				float(summary.get("local_pose_delta_deg", 0.0)),
			]
		)

func _capture_bone_axis_summary(skeleton: Skeleton3D, bone_name: String) -> Dictionary:
	var result := {
		"best_axis": "missing",
		"dots": {},
		"local_pose_delta_deg": 0.0,
	}
	var bone_index: int = skeleton.find_bone(bone_name) if skeleton != null else -1
	if bone_index < 0:
		return result
	var reference_pair: Array = REFERENCE_SEGMENTS.get(bone_name, []) as Array
	var reference_a := String(reference_pair[0]) if reference_pair.size() >= 2 else ""
	var reference_b := String(reference_pair[1]) if reference_pair.size() >= 2 else ""
	var reference_dir: Vector3 = _resolve_reference_dir(skeleton, reference_a, reference_b)
	var pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
	var axis_summary: Dictionary = _build_axis_summary(pose.basis, reference_dir)
	result["best_axis"] = axis_summary.get("best_axis", "none")
	result["dots"] = axis_summary.get("dots", {})
	result["local_pose_delta_deg"] = _resolve_quaternion_delta_degrees(
		skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion().normalized(),
		skeleton.get_bone_pose_rotation(bone_index).normalized()
	)
	return result

func _build_axis_summary(basis: Basis, reference_dir: Vector3) -> Dictionary:
	var result := {
		"best_axis": "none",
		"best_abs_dot": -1.0,
		"dots": {},
	}
	if reference_dir.length_squared() <= 0.000001:
		return result
	var dir: Vector3 = reference_dir.normalized()
	var axes := {
		"+X": basis.x.normalized(),
		"-X": -basis.x.normalized(),
		"+Y": basis.y.normalized(),
		"-Y": -basis.y.normalized(),
		"+Z": basis.z.normalized(),
		"-Z": -basis.z.normalized(),
	}
	var dots := {}
	for axis_name: String in axes.keys():
		var dot_value: float = (axes.get(axis_name, Vector3.ZERO) as Vector3).dot(dir)
		dots[axis_name] = snappedf(dot_value, 0.0001)
		if absf(dot_value) > float(result.get("best_abs_dot", -1.0)):
			result["best_abs_dot"] = absf(dot_value)
			result["best_axis"] = axis_name
	result["dots"] = dots
	return result

func _resolve_reference_dir(skeleton: Skeleton3D, from_bone: String, to_bone: String) -> Vector3:
	var from_index: int = skeleton.find_bone(from_bone) if skeleton != null else -1
	var to_index: int = skeleton.find_bone(to_bone) if skeleton != null else -1
	if from_index < 0 or to_index < 0:
		return Vector3.ZERO
	return skeleton.get_bone_global_pose(to_index).origin - skeleton.get_bone_global_pose(from_index).origin

func _resolve_quaternion_delta_degrees(first: Quaternion, second: Quaternion) -> float:
	var delta: Quaternion = (first.inverse() * second).normalized()
	return rad_to_deg(2.0 * acos(clampf(absf(delta.w), -1.0, 1.0)))

func _select_first_visible_skill_node(ui: CombatAnimationStationUI) -> void:
	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	if draft == null or draft.motion_node_chain.size() <= 0:
		return
	ui.select_motion_node(1 if draft.motion_node_chain.size() > 1 else 0)

func _find_saved_wip_by_project_name(library_state: PlayerForgeWipLibraryState, project_name: String) -> CraftedItemWIP:
	if library_state == null:
		return null
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip != null and saved_wip.forge_project_name == project_name:
			return saved_wip
	return null

func _get_preview_root(ui: CombatAnimationStationUI) -> Node3D:
	if ui == null or ui.preview_subviewport == null:
		return null
	return ui.preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D

func _get_preview_actor(ui: CombatAnimationStationUI) -> Node3D:
	var preview_root: Node3D = _get_preview_root(ui)
	return preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D if preview_root != null else null

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame

func _write_results() -> void:
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
