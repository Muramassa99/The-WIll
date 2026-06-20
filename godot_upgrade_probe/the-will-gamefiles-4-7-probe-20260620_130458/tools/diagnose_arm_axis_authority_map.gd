extends SceneTree

const PlayerRigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/arm_axis_authority_map_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_arm_axis_authority_map_library.tres"
const TARGET_PROJECT_NAME := "Test sword for animations"
const TARGET_SLOT_ID: StringName = &"skill_slot_1"
const DOMINANT_SLOT_ID: StringName = &"hand_right"

const AXIS_BONES := [
	"CC_Base_R_Clavicle",
	"CC_Base_R_Upperarm",
	"CC_Base_R_UpperarmTwist01",
	"CC_Base_R_UpperarmTwist02",
	"CC_Base_R_Forearm",
	"CC_Base_R_ForearmTwist01",
	"CC_Base_R_ForearmTwist02",
	"CC_Base_R_Hand",
	"CC_Base_R_Index1",
	"CC_Base_R_Pinky1",
	"CC_Base_L_Clavicle",
	"CC_Base_L_Upperarm",
	"CC_Base_L_UpperarmTwist01",
	"CC_Base_L_UpperarmTwist02",
	"CC_Base_L_Forearm",
	"CC_Base_L_ForearmTwist01",
	"CC_Base_L_ForearmTwist02",
	"CC_Base_L_Hand",
	"CC_Base_L_Index1",
	"CC_Base_L_Pinky1",
]

const REFERENCE_SEGMENTS := {
	"CC_Base_R_Clavicle": ["CC_Base_R_Clavicle", "CC_Base_R_Upperarm"],
	"CC_Base_R_Upperarm": ["CC_Base_R_Upperarm", "CC_Base_R_Forearm"],
	"CC_Base_R_UpperarmTwist01": ["CC_Base_R_Upperarm", "CC_Base_R_Forearm"],
	"CC_Base_R_UpperarmTwist02": ["CC_Base_R_Upperarm", "CC_Base_R_Forearm"],
	"CC_Base_R_Forearm": ["CC_Base_R_Forearm", "CC_Base_R_Hand"],
	"CC_Base_R_ForearmTwist01": ["CC_Base_R_Forearm", "CC_Base_R_Hand"],
	"CC_Base_R_ForearmTwist02": ["CC_Base_R_Forearm", "CC_Base_R_Hand"],
	"CC_Base_R_Hand": ["CC_Base_R_Forearm", "CC_Base_R_Hand"],
	"CC_Base_R_Index1": ["CC_Base_R_Pinky1", "CC_Base_R_Index1"],
	"CC_Base_R_Pinky1": ["CC_Base_R_Pinky1", "CC_Base_R_Index1"],
	"CC_Base_L_Clavicle": ["CC_Base_L_Clavicle", "CC_Base_L_Upperarm"],
	"CC_Base_L_Upperarm": ["CC_Base_L_Upperarm", "CC_Base_L_Forearm"],
	"CC_Base_L_UpperarmTwist01": ["CC_Base_L_Upperarm", "CC_Base_L_Forearm"],
	"CC_Base_L_UpperarmTwist02": ["CC_Base_L_Upperarm", "CC_Base_L_Forearm"],
	"CC_Base_L_Forearm": ["CC_Base_L_Forearm", "CC_Base_L_Hand"],
	"CC_Base_L_ForearmTwist01": ["CC_Base_L_Forearm", "CC_Base_L_Hand"],
	"CC_Base_L_ForearmTwist02": ["CC_Base_L_Forearm", "CC_Base_L_Hand"],
	"CC_Base_L_Hand": ["CC_Base_L_Forearm", "CC_Base_L_Hand"],
	"CC_Base_L_Index1": ["CC_Base_L_Index1", "CC_Base_L_Pinky1"],
	"CC_Base_L_Pinky1": ["CC_Base_L_Index1", "CC_Base_L_Pinky1"],
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

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	lines.append("audit_scope=arm_axis_authority_map")
	lines.append("official_godot_coordinate_rule=Skeleton3D bone global pose is skeleton-space; world transform requires skeleton.global_transform multiplication.")
	lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)
	await _capture_player_ready_axis_map()
	await _capture_station_reset_axis_map()
	_write_results()
	quit()

func _capture_player_ready_axis_map() -> void:
	var rig: PlayerHumanoidRig = PlayerRigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await _wait_frames(4)
	var skeleton: Skeleton3D = rig.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if rig != null else null
	lines.append("")
	lines.append("[player_ready]")
	_capture_rig_flags(rig, "player_ready")
	_capture_skeleton_modifier_map(skeleton, "player_ready")
	_capture_axis_map(skeleton, "player_ready")
	rig.queue_free()

func _capture_station_reset_axis_map() -> void:
	var source_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var source_wip: CraftedItemWIP = _find_saved_wip_by_project_name(source_library, TARGET_PROJECT_NAME)
	lines.append("")
	lines.append("[station_setup]")
	lines.append("source_library_loaded=%s" % str(source_library != null))
	lines.append("source_wip_found=%s" % str(source_wip != null))
	if source_wip == null:
		return
	var temp_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	temp_library.save_file_path = TEMP_SAVE_FILE_PATH
	temp_library.saved_wips.clear()
	var diagnostic_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	diagnostic_wip.wip_id = StringName("%s_axis_authority_map" % String(source_wip.wip_id))
	diagnostic_wip.forge_project_name = "%s Axis Authority Map Diagnostic" % source_wip.forge_project_name
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
	ui.open_for(fake_player, "Arm Axis Authority Map Diagnostic")
	await _wait_frames(8)
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(diagnostic_wip.wip_id, DOMINANT_SLOT_ID, false, false)
	await _wait_frames(8)
	var select_slot_ok: bool = ui.select_skill_slot(TARGET_SLOT_ID, true)
	await _wait_frames(8)
	_select_first_visible_skill_node(ui)
	await _wait_frames(4)
	var reset_ok: bool = ui.reset_active_draft_to_baseline()
	await _wait_frames(10)
	_select_first_visible_skill_node(ui)
	await _wait_frames(4)
	lines.append("diagnostic_save_path=%s" % TEMP_SAVE_FILE_PATH)
	lines.append("source_wip_id=%s" % String(source_wip.wip_id))
	lines.append("diagnostic_wip_id=%s" % String(diagnostic_wip.wip_id))
	lines.append("open_ok=%s" % str(open_ok))
	lines.append("select_skill_slot_1_ok=%s" % str(select_slot_ok))
	lines.append("reset_ok=%s" % str(reset_ok))
	_capture_station_context(ui, "station_after_reset")
	var actor: Node3D = _get_preview_actor(ui)
	var rig: PlayerHumanoidRig = actor as PlayerHumanoidRig
	var skeleton: Skeleton3D = actor.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if actor != null else null
	lines.append("")
	lines.append("[station_after_reset]")
	_capture_rig_flags(rig, "station_after_reset")
	_capture_skeleton_modifier_map(skeleton, "station_after_reset")
	_capture_axis_map(skeleton, "station_after_reset")
	ui.queue_free()
	fake_player.queue_free()

func _capture_station_context(ui: CombatAnimationStationUI, prefix: String) -> void:
	var debug_state: Dictionary = ui.get_preview_debug_state()
	var actor: Node3D = _get_preview_actor(ui)
	var held_item: Node3D = _get_preview_held_item(ui)
	var motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	lines.append("%s_active_draft_identifier=%s" % [prefix, String(ui.get_active_draft_identifier())])
	lines.append("%s_selected_motion_node_index=%d" % [prefix, ui.get_selected_motion_node_index()])
	lines.append("%s_actor_exists=%s" % [prefix, str(actor != null)])
	lines.append("%s_held_item_exists=%s" % [prefix, str(held_item != null)])
	if motion_node != null:
		lines.append("%s_node_tip_local=%s" % [prefix, str(motion_node.tip_position_local)])
		lines.append("%s_node_pommel_local=%s" % [prefix, str(motion_node.pommel_position_local)])
		lines.append("%s_node_grip=%s" % [prefix, String(motion_node.preferred_grip_style_mode)])
		lines.append("%s_node_two_hand=%s" % [prefix, String(motion_node.two_hand_state)])
	lines.append("%s_dominant_grip_error_m=%.6f" % [prefix, float(debug_state.get("dominant_grip_alignment_error_meters", -1.0))])
	lines.append("%s_collision_pose_legal=%s" % [prefix, str(bool(debug_state.get("collision_pose_legal", true)))])
	lines.append("%s_collision_pose_region=%s" % [prefix, String(debug_state.get("collision_pose_region", ""))])
	lines.append("%s_body_self_collision_legal=%s" % [prefix, str(bool(debug_state.get("body_self_collision_legal", true)))])
	lines.append("%s_body_self_illegal_pair_count=%d" % [prefix, int(debug_state.get("body_self_collision_illegal_pair_count", 0))])

func _capture_rig_flags(rig: PlayerHumanoidRig, prefix: String) -> void:
	lines.append("%s_rig_exists=%s" % [prefix, str(rig != null)])
	if rig == null:
		return
	lines.append("%s_authoring_preview_mode_enabled=%s" % [prefix, str(rig.authoring_preview_mode_enabled)])
	lines.append("%s_upper_body_auto_apply=%s" % [prefix, str(rig.upper_body_authoring_auto_apply_enabled)])
	lines.append("%s_enable_upper_body_authoring_pose=%s" % [prefix, str(rig.enable_upper_body_authoring_pose)])
	lines.append("%s_enable_support_arm_ik=%s" % [prefix, str(rig.enable_support_arm_ik)])
	lines.append("%s_enable_finger_grip_ik=%s" % [prefix, str(rig.enable_finger_grip_ik)])
	lines.append("%s_enable_contact_wrist_basis=%s" % [prefix, str(rig.enable_authoring_contact_wrist_basis)])
	lines.append("%s_enable_limb_twist_distribution=%s" % [prefix, str(rig.enable_authoring_limb_twist_distribution)])
	lines.append("%s_usable_arm_motion_range_ratio=%.4f" % [prefix, rig.get_usable_arm_motion_range_ratio()])
	lines.append("%s_upper_body_state=%s" % [prefix, str(rig.get_upper_body_authoring_state())])
	lines.append("%s_grip_contact_debug=%s" % [prefix, str(rig.get_grip_contact_debug_state())])

func _capture_skeleton_modifier_map(skeleton: Skeleton3D, prefix: String) -> void:
	lines.append("%s_skeleton_exists=%s" % [prefix, str(skeleton != null)])
	if skeleton == null:
		return
	lines.append("%s_skeleton_global_transform=%s" % [prefix, str(skeleton.global_transform)])
	lines.append("%s_modifier_callback_mode_process=%d" % [prefix, int(skeleton.modifier_callback_mode_process)])
	for child: Node in skeleton.get_children():
		if child is SkeletonModifier3D:
			var modifier: SkeletonModifier3D = child as SkeletonModifier3D
			lines.append(
				"%s_modifier=%s class=%s active=%s influence=%.4f process_mode=%d" % [
					prefix,
					child.name,
					child.get_class(),
					str(modifier.active),
					modifier.influence,
					int(child.process_mode),
				]
			)

func _capture_axis_map(skeleton: Skeleton3D, prefix: String) -> void:
	if skeleton == null:
		return
	for bone_name_variant: Variant in AXIS_BONES:
		var bone_name := String(bone_name_variant)
		var bone_index: int = skeleton.find_bone(bone_name)
		if bone_index < 0:
			lines.append("%s_axis_%s_exists=false" % [prefix, bone_name])
			continue
		var reference_pair: Array = REFERENCE_SEGMENTS.get(bone_name, []) as Array
		var reference_a := String(reference_pair[0]) if reference_pair.size() >= 2 else ""
		var reference_b := String(reference_pair[1]) if reference_pair.size() >= 2 else ""
		var rest_pose: Transform3D = _get_bone_global_rest_transform(skeleton, bone_index)
		var current_pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
		var parent_index: int = skeleton.get_bone_parent(bone_index)
		var parent_name := skeleton.get_bone_name(parent_index) if parent_index >= 0 else ""
		var rest_reference_dir: Vector3 = _resolve_reference_dir(skeleton, reference_a, reference_b, true)
		var current_reference_dir: Vector3 = _resolve_reference_dir(skeleton, reference_a, reference_b, false)
		var rest_axis_summary: Dictionary = _build_axis_summary(rest_pose.basis, rest_reference_dir)
		var current_axis_summary: Dictionary = _build_axis_summary(current_pose.basis, current_reference_dir)
		var local_pose_delta_degrees: float = _resolve_quaternion_delta_degrees(
			skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion().normalized(),
			skeleton.get_bone_pose_rotation(bone_index).normalized()
		)
		lines.append("%s_axis_%s_exists=true parent=%s reference=%s_to_%s" % [prefix, bone_name, parent_name, reference_a, reference_b])
		lines.append("%s_axis_%s_rest_best=%s rest_dots=%s" % [prefix, bone_name, String(rest_axis_summary.get("best_axis", "")), str(rest_axis_summary.get("dots", {}))])
		lines.append("%s_axis_%s_current_best=%s current_dots=%s" % [prefix, bone_name, String(current_axis_summary.get("best_axis", "")), str(current_axis_summary.get("dots", {}))])
		lines.append("%s_axis_%s_rest_origin=%s current_origin=%s local_pose_delta_deg=%.4f" % [prefix, bone_name, str(rest_pose.origin), str(current_pose.origin), local_pose_delta_degrees])

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

func _resolve_reference_dir(skeleton: Skeleton3D, from_bone: String, to_bone: String, use_rest: bool) -> Vector3:
	var from_index: int = skeleton.find_bone(from_bone) if skeleton != null else -1
	var to_index: int = skeleton.find_bone(to_bone) if skeleton != null else -1
	if from_index < 0 or to_index < 0:
		return Vector3.ZERO
	var from_pose: Transform3D = _get_bone_global_rest_transform(skeleton, from_index) if use_rest else skeleton.get_bone_global_pose(from_index)
	var to_pose: Transform3D = _get_bone_global_rest_transform(skeleton, to_index) if use_rest else skeleton.get_bone_global_pose(to_index)
	return to_pose.origin - from_pose.origin

func _get_bone_global_rest_transform(skeleton: Skeleton3D, bone_index: int) -> Transform3D:
	if skeleton == null or bone_index < 0:
		return Transform3D.IDENTITY
	var bone_rest: Transform3D = skeleton.get_bone_rest(bone_index)
	var parent_index: int = skeleton.get_bone_parent(bone_index)
	if parent_index < 0:
		return bone_rest
	return _get_bone_global_rest_transform(skeleton, parent_index) * bone_rest

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

func _get_preview_held_item(ui: CombatAnimationStationUI) -> Node3D:
	var preview_root: Node3D = _get_preview_root(ui)
	return preview_root.get_meta("preview_held_item", null) as Node3D if preview_root != null else null

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame

func _write_results() -> void:
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
