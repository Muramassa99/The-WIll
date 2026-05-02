extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const CombatAnimationChainPlayerScript = preload("res://runtime/combat/combat_animation_chain_player.gd")
const CombatAnimationMotionNodeEditorScript = preload("res://runtime/combat/combat_animation_motion_node_editor.gd")

const TARGET_PROJECT_NAME := "Test sword for animations"
const RESULT_FILE_PATH := "C:/WORKSPACE/skill_slot_1_grip_swap_path_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_skill_slot_1_grip_swap_path_library.tres"

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
	var test_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	test_wip.wip_id = StringName("%s_skill_slot_1_path" % String(source_wip.wip_id))
	test_wip.forge_project_name = "%s Skill Slot 1 Path" % source_wip.forge_project_name
	test_wip.ensure_combat_animation_station_state()
	temp_library.saved_wips.append(test_wip)
	temp_library.selected_wip_id = test_wip.wip_id
	temp_library.persist()

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = temp_library
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Skill Slot 1 Grip Swap Path Diagnostic")
	await _wait_frames(8)

	var open_ok: bool = ui.open_saved_wip_with_hand_setup(test_wip.wip_id, &"hand_right", false, false)
	await _wait_frames(8)
	var select_slot_ok: bool = ui.select_skill_slot(&"skill_slot_1", true)
	await _wait_frames(4)
	var reset_ok: bool = ui.reset_active_draft_to_baseline()
	await _wait_frames(8)
	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	var select_node_ok: bool = false
	if draft != null:
		select_node_ok = ui.select_motion_node(maxi(draft.motion_node_chain.size() - 1, 0))
		await _wait_frames(4)
	var source_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var authoring_grip_pivot: Vector3 = ui.call("_resolve_primary_grip_pivot_for_motion_node", source_node) as Vector3 if source_node != null else Vector3.ZERO
	var target_grip: StringName = _resolve_opposite_grip(source_node.preferred_grip_style_mode if source_node != null else test_wip.grip_style_mode)
	var bridge_ok: bool = ui.set_selected_motion_node_preferred_grip_style(target_grip)
	await _wait_frames(8)
	var bridge_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var generated_bridge_pivot: Vector3 = _resolve_fixed_pivot(source_node, bridge_node) if source_node != null and bridge_node != null else Vector3.ZERO
	var bridge_curve_edit_ok: bool = false
	if bridge_node != null:
		bridge_curve_edit_ok = (
			ui.set_selected_motion_node_tip_curve_in(Vector3(0.14, 0.09, -0.04), false)
			and ui.set_selected_motion_node_pommel_curve_in(Vector3(-0.08, 0.04, 0.02), false)
		)
		await _wait_frames(4)
	draft = ui.call("_get_active_draft") as CombatAnimationDraft
	lines.append("open_ok=%s" % str(open_ok))
	lines.append("select_slot_1_ok=%s" % str(select_slot_ok))
	lines.append("reset_ok=%s" % str(reset_ok))
	lines.append("select_last_node_ok=%s" % str(select_node_ok))
	lines.append("bridge_insert_ok=%s" % str(bridge_ok))
	lines.append("bridge_curve_edit_ok=%s" % str(bridge_curve_edit_ok))
	lines.append("authoring_grip_pivot=%s" % str(authoring_grip_pivot))
	lines.append("generated_bridge_pivot=%s" % str(generated_bridge_pivot))
	lines.append("bridge_uses_authoring_grip_pivot_ok=%s" % str(
		source_node != null
		and bridge_node != null
		and generated_bridge_pivot.distance_to(authoring_grip_pivot) <= 0.005
	))
	lines.append("draft_identifier=%s" % String(ui.get_active_draft_identifier()))
	lines.append("draft_node_count=%d" % (draft.motion_node_chain.size() if draft != null else 0))
	lines.append_array(_capture_chain_player_path_results(draft))

	_write_results(lines)
	quit()

func _capture_chain_player_path_results(draft: CombatAnimationDraft) -> PackedStringArray:
	var lines: PackedStringArray = []
	if draft == null or draft.motion_node_chain.size() < 2:
		lines.append("chain_capture_complete=false")
		return lines
	var bridge_index: int = draft.motion_node_chain.size() - 1
	var source_index: int = bridge_index - 1
	var source_node: CombatAnimationMotionNode = draft.motion_node_chain[source_index] as CombatAnimationMotionNode
	var bridge_node: CombatAnimationMotionNode = draft.motion_node_chain[bridge_index] as CombatAnimationMotionNode
	if source_node == null or bridge_node == null:
		lines.append("chain_capture_complete=false")
		return lines
	var motion_node_editor: CombatAnimationMotionNodeEditor = CombatAnimationMotionNodeEditorScript.new()
	var chain_player: CombatAnimationChainPlayer = CombatAnimationChainPlayerScript.new()
	var tip_curve: Curve3D = motion_node_editor.build_tip_curve(draft.motion_node_chain)
	var pommel_curve: Curve3D = motion_node_editor.build_pommel_curve(draft.motion_node_chain)
	chain_player.prepare(draft.motion_node_chain, tip_curve, pommel_curve, 1.0, false)
	chain_player.start()
	var elapsed_to_bridge_segment: float = 0.0
	for node_index: int in range(1, bridge_index):
		var node: CombatAnimationMotionNode = draft.motion_node_chain[node_index] as CombatAnimationMotionNode
		elapsed_to_bridge_segment += maxf(node.transition_duration_seconds if node != null else 0.18, 0.01)
	var bridge_duration: float = maxf(bridge_node.transition_duration_seconds, 0.01)
	chain_player.advance(elapsed_to_bridge_segment + bridge_duration * 0.5)
	var half_tip: Vector3 = chain_player.current_tip_position
	var half_pommel: Vector3 = chain_player.current_pommel_position
	var half_axis: Vector3 = half_tip - half_pommel
	var fixed_pivot: Vector3 = _resolve_fixed_pivot(source_node, bridge_node)
	var pivot_ratio: float = _resolve_pivot_ratio(source_node, fixed_pivot)
	var half_pivot: Vector3 = half_pommel + half_axis * pivot_ratio
	var target_length: float = source_node.tip_position_local.distance_to(source_node.pommel_position_local)
	var half_grip: StringName = chain_player.current_preferred_grip_style_mode
	var half_contact_axis: Vector3 = chain_player.current_contact_grip_axis_local
	var source_contact_axis: Vector3 = _safe_axis(source_node.tip_position_local - fixed_pivot)
	var half_contact_axis_override_active: bool = chain_player.current_contact_grip_axis_local_override_active
	chain_player.advance(bridge_duration * 0.51)
	lines.append("chain_capture_complete=true")
	lines.append("source_grip=%s" % String(source_node.preferred_grip_style_mode))
	lines.append("bridge_grip=%s" % String(bridge_node.preferred_grip_style_mode))
	lines.append("bridge_generated_grip_swap=%s" % str(
		bridge_node.generated_transition_node
		and bridge_node.generated_transition_kind == CombatAnimationMotionNode.TRANSITION_KIND_GRIP_STYLE_SWAP
	))
	lines.append("half_tip=%s" % str(half_tip))
	lines.append("half_pommel=%s" % str(half_pommel))
	lines.append("half_length=%.6f" % half_axis.length())
	lines.append("expected_length=%.6f" % target_length)
	lines.append("half_pivot=%s" % str(half_pivot))
	lines.append("fixed_pivot=%s" % str(fixed_pivot))
	lines.append("half_grip_mode=%s" % String(half_grip))
	lines.append("end_grip_mode=%s" % String(chain_player.current_preferred_grip_style_mode))
	lines.append("half_contact_axis=%s" % str(half_contact_axis))
	lines.append("source_contact_axis=%s" % str(source_contact_axis))
	lines.append("half_contact_axis_override_active=%s" % str(half_contact_axis_override_active))
	lines.append("rigid_length_ok=%s" % str(absf(half_axis.length() - target_length) <= 0.005))
	lines.append("fixed_pivot_ok=%s" % str(half_pivot.distance_to(fixed_pivot) <= 0.005))
	lines.append("source_grip_held_during_bridge_ok=%s" % str(half_grip == source_node.preferred_grip_style_mode))
	lines.append("target_grip_reached_after_bridge_ok=%s" % str(chain_player.current_preferred_grip_style_mode == bridge_node.preferred_grip_style_mode))
	lines.append("contact_axis_override_active_ok=%s" % str(half_contact_axis_override_active))
	lines.append("contact_axis_holds_source_ok=%s" % str(half_contact_axis.dot(source_contact_axis) >= 0.99))
	return lines

func _resolve_opposite_grip(grip_style: StringName) -> StringName:
	return CraftedItemWIP.GRIP_NORMAL if grip_style == CraftedItemWIP.GRIP_REVERSE else CraftedItemWIP.GRIP_REVERSE

func _resolve_fixed_pivot(source_node: CombatAnimationMotionNode, bridge_node: CombatAnimationMotionNode) -> Vector3:
	var tip_midpoint: Vector3 = source_node.tip_position_local.lerp(bridge_node.tip_position_local, 0.5)
	var pommel_midpoint: Vector3 = source_node.pommel_position_local.lerp(bridge_node.pommel_position_local, 0.5)
	return tip_midpoint.lerp(pommel_midpoint, 0.5)

func _resolve_pivot_ratio(source_node: CombatAnimationMotionNode, pivot: Vector3) -> float:
	var axis: Vector3 = source_node.tip_position_local - source_node.pommel_position_local
	if axis.length_squared() <= 0.000001:
		return 0.5
	return clampf((pivot - source_node.pommel_position_local).dot(axis) / axis.length_squared(), 0.0, 1.0)

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
