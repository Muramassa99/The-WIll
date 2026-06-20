extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const TARGET_PROJECT_NAME := "Test sword for animations"
const RESULT_FILE_PATH := "C:/WORKSPACE/grip_swap_hand_orientation_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_grip_swap_hand_orientation_library.tres"
const RIGHT_HAND_BONE := "CC_Base_R_Hand"
const RIGHT_FOREARM_BONE := "CC_Base_R_Forearm"

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	var lines: PackedStringArray = []
	lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)

	var source_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var source_wip: CraftedItemWIP = _find_saved_wip_by_project_name(source_library, TARGET_PROJECT_NAME)
	lines.append("source_wip_found=%s" % str(source_wip != null))
	if source_wip == null:
		_write_results(lines)
		quit()
		return

	var temp_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	temp_library.save_file_path = TEMP_SAVE_FILE_PATH
	temp_library.saved_wips.clear()
	var reverse_source_wip: CraftedItemWIP = _build_variant_wip(source_wip, &"hand_orientation_reverse_source", CraftedItemWIP.GRIP_REVERSE)
	temp_library.saved_wips.append(reverse_source_wip)
	temp_library.selected_wip_id = reverse_source_wip.wip_id
	temp_library.persist()

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = temp_library
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Grip Swap Hand Orientation Diagnostic")
	await _wait_frames(8)

	var open_ok: bool = ui.open_saved_wip_with_hand_setup(reverse_source_wip.wip_id, &"hand_right", false, false)
	await _wait_frames(8)
	var skill_slot_ok: bool = ui.select_skill_slot(&"skill_slot_1", true)
	await _wait_frames(4)
	var reset_ok: bool = ui.reset_active_draft_to_baseline()
	await _wait_frames(8)
	var source_draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	if source_draft != null:
		ui.select_motion_node(maxi(source_draft.motion_node_chain.size() - 1, 0))
		await _wait_frames(4)
	lines.append("open_ok=%s" % str(open_ok))
	lines.append("skill_slot_1_ok=%s" % str(skill_slot_ok))
	lines.append("reset_ok=%s" % str(reset_ok))
	lines.append_array(_capture_selected(ui, "node_0_reverse_source"))

	var normal_bridge_ok: bool = ui.set_selected_motion_node_preferred_grip_style(CraftedItemWIP.GRIP_NORMAL)
	await _wait_frames(10)
	lines.append("normal_bridge_insert_ok=%s" % str(normal_bridge_ok))
	lines.append_array(_capture_selected(ui, "node_1_normal_bridge"))

	var reverse_bridge_ok: bool = ui.set_selected_motion_node_preferred_grip_style(CraftedItemWIP.GRIP_REVERSE)
	await _wait_frames(10)
	lines.append("reverse_bridge_insert_ok=%s" % str(reverse_bridge_ok))
	lines.append_array(_capture_selected(ui, "node_2_reverse_bridge"))

	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	lines.append("final_node_count=%d" % (draft.motion_node_chain.size() if draft != null else 0))
	lines.append_array(_capture_chain_curve_edit_permissions(ui, draft))

	_write_results(lines)
	quit()

func _build_variant_wip(source_wip: CraftedItemWIP, suffix: StringName, grip_style_mode: StringName) -> CraftedItemWIP:
	var variant_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	variant_wip.wip_id = StringName("%s_%s" % [String(source_wip.wip_id), String(suffix)])
	variant_wip.forge_project_name = "%s %s" % [source_wip.forge_project_name, String(suffix)]
	variant_wip.grip_style_mode = grip_style_mode
	variant_wip.ensure_combat_animation_station_state()
	return variant_wip

func _capture_selected(ui: CombatAnimationStationUI, label: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D if ui.preview_subviewport != null else null
	var actor: Node3D = preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D if preview_root != null else null
	var held_item: Node3D = preview_root.get_meta("preview_held_item", null) as Node3D if preview_root != null else null
	var motion_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var skeleton: Skeleton3D = actor.get_node_or_null("JosieModel/Josie/Skeleton3D") as Skeleton3D if actor != null else null
	if actor == null or held_item == null or skeleton == null or motion_node == null:
		lines.append("%s_capture_complete=false" % label)
		return lines
	var hand_index: int = skeleton.find_bone(RIGHT_HAND_BONE)
	var forearm_index: int = skeleton.find_bone(RIGHT_FOREARM_BONE)
	if hand_index < 0 or forearm_index < 0:
		lines.append("%s_capture_complete=false" % label)
		return lines
	var local_tip: Vector3 = held_item.get_meta("weapon_tip_local", Vector3.ZERO) as Vector3
	var local_grip: Vector3 = held_item.get_meta("primary_grip_contact_local", Vector3.ZERO) as Vector3
	var tip_world: Vector3 = held_item.global_transform * local_tip
	var grip_world: Vector3 = held_item.global_transform * local_grip
	var grip_to_tip_world: Vector3 = _safe_axis(tip_world - grip_world)
	var hand_basis: Basis = (skeleton.global_basis * skeleton.get_bone_global_pose(hand_index).basis).orthonormalized()
	var hand_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(hand_index).origin)
	var forearm_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(forearm_index).origin)
	var forearm_to_hand_world: Vector3 = _safe_axis(hand_world - forearm_world)
	var hand_anchor: Node3D = actor.get_right_hand_item_anchor()
	var anchor_basis: Basis = hand_anchor.global_basis.orthonormalized() if hand_anchor != null else Basis.IDENTITY
	var hand_x_dot: float = grip_to_tip_world.dot(hand_basis.x.normalized())
	var hand_y_dot: float = grip_to_tip_world.dot(hand_basis.y.normalized())
	var hand_z_dot: float = grip_to_tip_world.dot(hand_basis.z.normalized())
	var anchor_x_dot: float = grip_to_tip_world.dot(anchor_basis.x.normalized())
	var hand_y_forearm_dot: float = forearm_to_hand_world.dot(hand_basis.y.normalized()) if forearm_to_hand_world.length_squared() > 0.000001 else 0.0
	var projected_grip_axis_world: Vector3 = grip_to_tip_world - hand_basis.y.normalized() * grip_to_tip_world.dot(hand_basis.y.normalized())
	projected_grip_axis_world = _safe_axis(projected_grip_axis_world)
	var hand_x_projected_grip_dot: float = projected_grip_axis_world.dot(hand_basis.x.normalized()) if projected_grip_axis_world.length_squared() > 0.000001 else 0.0
	var expected_hand_x_dot: float = -1.0 if motion_node.preferred_grip_style_mode == CraftedItemWIP.GRIP_REVERSE else 1.0
	lines.append("%s_capture_complete=true" % label)
	lines.append("%s_selected_index=%d" % [label, ui.get_selected_motion_node_index()])
	lines.append("%s_grip=%s" % [label, String(motion_node.preferred_grip_style_mode)])
	lines.append("%s_generated=%s" % [label, str(motion_node.generated_transition_node)])
	lines.append("%s_locked=%s" % [label, str(motion_node.locked_for_authoring)])
	lines.append("%s_tip_world=%s" % [label, str(tip_world)])
	lines.append("%s_grip_world=%s" % [label, str(grip_world)])
	lines.append("%s_grip_to_tip_world=%s" % [label, str(grip_to_tip_world)])
	lines.append("%s_forearm_to_hand_world=%s" % [label, str(forearm_to_hand_world)])
	lines.append("%s_projected_grip_axis_on_hand_y_plane_world=%s" % [label, str(projected_grip_axis_world)])
	lines.append("%s_hand_x_world=%s" % [label, str(hand_basis.x.normalized())])
	lines.append("%s_hand_y_world=%s" % [label, str(hand_basis.y.normalized())])
	lines.append("%s_hand_z_world=%s" % [label, str(hand_basis.z.normalized())])
	lines.append("%s_hand_x_dot_grip_to_tip=%.6f" % [label, hand_x_dot])
	lines.append("%s_hand_y_dot_grip_to_tip=%.6f" % [label, hand_y_dot])
	lines.append("%s_hand_z_dot_grip_to_tip=%.6f" % [label, hand_z_dot])
	lines.append("%s_anchor_x_dot_grip_to_tip=%.6f" % [label, anchor_x_dot])
	lines.append("%s_hand_y_dot_forearm_to_hand=%.6f" % [label, hand_y_forearm_dot])
	lines.append("%s_hand_x_dot_projected_grip_to_tip=%.6f" % [label, hand_x_projected_grip_dot])
	lines.append("%s_expected_hand_x_dot_projected_grip_to_tip=%.6f" % [label, expected_hand_x_dot])
	lines.append("%s_hand_y_anatomical_ok=%s" % [label, str(hand_y_forearm_dot >= 0.85)])
	lines.append("%s_hand_x_weapon_side_ok=%s" % [label, str(absf(hand_x_projected_grip_dot - expected_hand_x_dot) <= 0.20)])
	return lines

func _capture_chain_curve_edit_permissions(ui: CombatAnimationStationUI, draft: CombatAnimationDraft) -> PackedStringArray:
	var lines: PackedStringArray = []
	if draft == null or draft.motion_node_chain.size() < 2:
		lines.append("curve_permission_capture_complete=false")
		return lines
	var bridge_index: int = -1
	for node_index: int in range(draft.motion_node_chain.size()):
		var candidate: CombatAnimationMotionNode = draft.motion_node_chain[node_index] as CombatAnimationMotionNode
		if candidate != null and candidate.generated_transition_node:
			bridge_index = node_index
			break
	if bridge_index < 0:
		lines.append("curve_permission_capture_complete=false")
		return lines
	ui.select_motion_node(bridge_index)
	var bridge: CombatAnimationMotionNode = draft.motion_node_chain[bridge_index] as CombatAnimationMotionNode
	var original_tip: Vector3 = bridge.tip_position_local if bridge != null else Vector3.ZERO
	var original_pommel: Vector3 = bridge.pommel_position_local if bridge != null else Vector3.ZERO
	var curve_edit_ok: bool = ui.set_selected_motion_node_tip_curve_out(Vector3(0.11, 0.07, -0.03), false)
	var position_edit_ok: bool = ui.set_selected_motion_node_tip_position(original_tip + Vector3(0.1, 0.0, 0.0), false)
	lines.append("curve_permission_capture_complete=true")
	lines.append("bridge_curve_edit_ok=%s" % str(curve_edit_ok))
	lines.append("bridge_position_edit_blocked=%s" % str(not position_edit_ok))
	lines.append("bridge_tip_position_preserved=%s" % str(bridge != null and bridge.tip_position_local.is_equal_approx(original_tip)))
	lines.append("bridge_pommel_position_preserved=%s" % str(bridge != null and bridge.pommel_position_local.is_equal_approx(original_pommel)))
	lines.append("bridge_tip_curve_out=%s" % str(bridge.tip_curve_out_handle if bridge != null else Vector3.ZERO))
	return lines

func _safe_axis(vector: Vector3) -> Vector3:
	if vector.length_squared() <= 0.000001:
		return Vector3.ZERO
	return vector.normalized()

func _find_saved_wip_by_project_name(library_state: PlayerForgeWipLibraryState, project_name: String) -> CraftedItemWIP:
	if library_state == null:
		return null
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip == null:
			continue
		if saved_wip.forge_project_name == project_name:
			return saved_wip
	return null

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame

func _write_results(lines: PackedStringArray) -> void:
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
