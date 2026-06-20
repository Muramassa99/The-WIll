extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/unarmed_proxy_translation_orientation_lock_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/verify_unarmed_proxy_translation_orientation_lock_library.tres"
const RIGHT_HAND_BONE := "CC_Base_R_Hand"
const RIGHT_INDEX1_BONE := "CC_Base_R_Index1"
const RIGHT_PINKY1_BONE := "CC_Base_R_Pinky1"

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library_state.save_file_path = TEMP_SAVE_FILE_PATH
	library_state.saved_wips.clear()
	library_state.selected_wip_id = StringName()

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Unarmed Proxy Translation Orientation Lock")
	await _wait_frames(6)

	var open_ok: bool = ui.select_unarmed_authoring(true)
	await _wait_frames(6)
	var skill_ok: bool = ui.select_skill_slot(&"skill_slot_1", true)
	await _wait_frames(4)
	var reset_ok: bool = ui.reset_active_draft_to_baseline()
	await _wait_frames(8)
	var select_editable_ok: bool = ui.select_motion_node(1)
	await _wait_frames(4)

	var before: Dictionary = _capture_pose(ui)
	var motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var move_ok: bool = false
	if motion_node != null:
		var pommel_target: Vector3 = motion_node.pommel_position_local + Vector3(0.012, 0.007, -0.005)
		move_ok = ui.set_selected_motion_node_pommel_position(pommel_target, false, true, true, true, true)
		await _wait_frames(8)
	var after: Dictionary = _capture_pose(ui)

	var axis_before: Vector3 = before.get("segment_axis", Vector3.ZERO) as Vector3
	var axis_after: Vector3 = after.get("segment_axis", Vector3.ZERO) as Vector3
	var grip_axis_before: Vector3 = before.get("grip_to_tip_axis", Vector3.ZERO) as Vector3
	var grip_axis_after: Vector3 = after.get("grip_to_tip_axis", Vector3.ZERO) as Vector3
	var hand_x_before: Vector3 = before.get("hand_x", Vector3.ZERO) as Vector3
	var hand_x_after: Vector3 = after.get("hand_x", Vector3.ZERO) as Vector3
	var hand_z_before: Vector3 = before.get("hand_z", Vector3.ZERO) as Vector3
	var hand_z_after: Vector3 = after.get("hand_z", Vector3.ZERO) as Vector3
	var finger_line_before: Vector3 = before.get("index_pinky_axis", Vector3.ZERO) as Vector3
	var finger_line_after: Vector3 = after.get("index_pinky_axis", Vector3.ZERO) as Vector3

	var lines: PackedStringArray = []
	lines.append("open_ok=%s" % str(open_ok))
	lines.append("skill_slot_1_ok=%s" % str(skill_ok))
	lines.append("reset_ok=%s" % str(reset_ok))
	lines.append("select_editable_ok=%s" % str(select_editable_ok))
	lines.append("move_ok=%s" % str(move_ok))
	lines.append("selected_motion_node_index=%d" % ui.get_selected_motion_node_index())
	lines.append("before_capture_complete=%s" % str(bool(before.get("capture_complete", false))))
	lines.append("after_capture_complete=%s" % str(bool(after.get("capture_complete", false))))
	lines.append("axis_before=%s" % str(axis_before))
	lines.append("axis_after=%s" % str(axis_after))
	lines.append("grip_axis_before=%s" % str(grip_axis_before))
	lines.append("grip_axis_after=%s" % str(grip_axis_after))
	lines.append("before_has_contact_axis_override=%s" % str(bool(before.get("has_contact_axis_override", false))))
	lines.append("after_has_contact_axis_override=%s" % str(bool(after.get("has_contact_axis_override", false))))
	lines.append("before_contact_axis_override=%s" % str(before.get("contact_axis_override", Vector3.ZERO) as Vector3))
	lines.append("after_contact_axis_override=%s" % str(after.get("contact_axis_override", Vector3.ZERO) as Vector3))
	lines.append("hand_x_before=%s" % str(hand_x_before))
	lines.append("hand_x_after=%s" % str(hand_x_after))
	lines.append("hand_z_before=%s" % str(hand_z_before))
	lines.append("hand_z_after=%s" % str(hand_z_after))
	lines.append("finger_line_before=%s" % str(finger_line_before))
	lines.append("finger_line_after=%s" % str(finger_line_after))
	lines.append("segment_axis_alignment=%.6f" % axis_before.dot(axis_after))
	lines.append("hand_x_translation_alignment=%.6f" % hand_x_before.dot(hand_x_after))
	lines.append("finger_line_translation_alignment=%.6f" % finger_line_before.dot(finger_line_after))
	lines.append("before_finger_line_dot_segment=%.6f" % finger_line_before.dot(axis_before))
	lines.append("after_finger_line_dot_segment=%.6f" % finger_line_after.dot(axis_after))
	lines.append("before_hand_z_dot_segment=%.6f" % hand_z_before.dot(axis_before))
	lines.append("after_hand_z_dot_segment=%.6f" % hand_z_after.dot(axis_after))
	lines.append("before_hand_z_dot_grip_axis=%.6f" % hand_z_before.dot(grip_axis_before))
	lines.append("after_hand_z_dot_grip_axis=%.6f" % hand_z_after.dot(grip_axis_after))
	lines.append("before_finger_line_dot_hand_z=%.6f" % finger_line_before.dot(hand_z_before))
	lines.append("after_finger_line_dot_hand_z=%.6f" % finger_line_after.dot(hand_z_after))
	lines.append("orientation_lock_ok=%s" % str(
		bool(before.get("capture_complete", false))
		and bool(after.get("capture_complete", false))
		and axis_before.dot(axis_after) >= 0.999
		and finger_line_before.dot(finger_line_after) >= 0.999
		and finger_line_after.dot(axis_after) >= 0.999
	))
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _capture_pose(ui: CombatAnimationStationUI) -> Dictionary:
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D if ui.preview_subviewport != null else null
	var actor: Node3D = preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D if preview_root != null else null
	var held_item: Node3D = preview_root.get_meta("preview_held_item", null) as Node3D if preview_root != null else null
	var skeleton: Skeleton3D = actor.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if actor != null else null
	if actor == null or held_item == null or skeleton == null:
		return {"capture_complete": false}
	var hand_index: int = skeleton.find_bone(RIGHT_HAND_BONE)
	var index_index: int = skeleton.find_bone(RIGHT_INDEX1_BONE)
	var pinky_index: int = skeleton.find_bone(RIGHT_PINKY1_BONE)
	if hand_index < 0 or index_index < 0 or pinky_index < 0:
		return {"capture_complete": false}
	var local_tip: Vector3 = held_item.get_meta("weapon_tip_local", Vector3.ZERO) as Vector3
	var local_pommel: Vector3 = held_item.get_meta("weapon_pommel_local", Vector3.ZERO) as Vector3
	var local_grip: Vector3 = held_item.get_meta("primary_grip_contact_local", Vector3.ZERO) as Vector3
	var tip_world: Vector3 = held_item.global_transform * local_tip
	var pommel_world: Vector3 = held_item.global_transform * local_pommel
	var grip_world: Vector3 = held_item.global_transform * local_grip
	var segment_axis: Vector3 = tip_world - pommel_world
	var grip_to_tip_axis: Vector3 = tip_world - grip_world
	if segment_axis.length_squared() <= 0.000001:
		return {"capture_complete": false}
	if grip_to_tip_axis.length_squared() <= 0.000001:
		return {"capture_complete": false}
	var index_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(index_index).origin)
	var pinky_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(pinky_index).origin)
	var index_pinky_axis: Vector3 = index_world - pinky_world
	if index_pinky_axis.length_squared() <= 0.000001:
		return {"capture_complete": false}
	var hand_basis: Basis = (skeleton.global_basis * skeleton.get_bone_global_pose(hand_index).basis).orthonormalized()
	return {
		"capture_complete": true,
		"segment_axis": segment_axis.normalized(),
		"grip_to_tip_axis": grip_to_tip_axis.normalized(),
		"hand_x": hand_basis.x.normalized(),
		"hand_z": hand_basis.z.normalized(),
		"index_pinky_axis": index_pinky_axis.normalized(),
		"has_contact_axis_override": held_item.has_meta("authoring_contact_grip_axis_world_override"),
		"contact_axis_override": held_item.get_meta("authoring_contact_grip_axis_world_override", Vector3.ZERO) as Vector3,
	}

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame
