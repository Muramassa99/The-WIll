extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")

const TARGET_PROJECT_NAME := "Test sword for animations"
const RESULT_FILE_PATH := "C:/WORKSPACE/grip_style_bridge_orientation_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_grip_style_bridge_orientation_library.tres"

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
	var reverse_source_wip: CraftedItemWIP = _build_variant_wip(source_wip, &"bridge_reverse_source", CraftedItemWIP.GRIP_REVERSE)
	var normal_source_wip: CraftedItemWIP = _build_variant_wip(source_wip, &"bridge_normal_source", CraftedItemWIP.GRIP_NORMAL)
	temp_library.saved_wips.append(reverse_source_wip)
	temp_library.saved_wips.append(normal_source_wip)
	temp_library.selected_wip_id = reverse_source_wip.wip_id
	temp_library.persist()

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = temp_library
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Grip Style Bridge Orientation Diagnostic")
	await _wait_frames(8)

	lines.append_array(await _run_bridge_case(
		ui,
		reverse_source_wip.wip_id,
		"reverse_to_normal",
		CraftedItemWIP.GRIP_NORMAL
	))
	lines.append_array(await _run_bridge_case(
		ui,
		normal_source_wip.wip_id,
		"normal_to_reverse",
		CraftedItemWIP.GRIP_REVERSE
	))
	_write_results(lines)
	quit()

func _build_variant_wip(source_wip: CraftedItemWIP, suffix: StringName, grip_style_mode: StringName) -> CraftedItemWIP:
	var variant_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	variant_wip.wip_id = StringName("%s_%s" % [String(source_wip.wip_id), String(suffix)])
	variant_wip.forge_project_name = "%s %s" % [source_wip.forge_project_name, String(suffix)]
	variant_wip.grip_style_mode = grip_style_mode
	variant_wip.ensure_combat_animation_station_state()
	return variant_wip

func _run_bridge_case(
	ui: CombatAnimationStationUI,
	wip_id: StringName,
	label: String,
	target_grip_mode: StringName
) -> PackedStringArray:
	var lines: PackedStringArray = []
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(wip_id, &"hand_right", false, false)
	await _wait_frames(8)
	var idle_ok: bool = ui.select_authoring_mode(CombatAnimationStationStateScript.AUTHORING_MODE_IDLE)
	await _wait_frames(3)
	var draft_ok: bool = ui.select_draft(CombatAnimationStationStateScript.IDLE_CONTEXT_COMBAT, true)
	await _wait_frames(3)
	var reset_ok: bool = ui.reset_active_draft_to_baseline()
	await _wait_frames(6)
	var expected_seed: Dictionary = ui.call("_resolve_active_weapon_authored_baseline_seed", false, target_grip_mode) as Dictionary
	var bridge_ok: bool = ui.set_selected_motion_node_preferred_grip_style(target_grip_mode)
	await _wait_frames(8)
	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	var source_node: CombatAnimationMotionNode = _get_node(draft, 0)
	var bridge_node: CombatAnimationMotionNode = _get_node(draft, 1)
	lines.append("%s_open_ok=%s" % [label, str(open_ok)])
	lines.append("%s_idle_ok=%s" % [label, str(idle_ok)])
	lines.append("%s_draft_ok=%s" % [label, str(draft_ok)])
	lines.append("%s_reset_ok=%s" % [label, str(reset_ok)])
	lines.append("%s_bridge_ok=%s" % [label, str(bridge_ok)])
	lines.append("%s_node_count=%d" % [label, draft.motion_node_chain.size() if draft != null else 0])
	lines.append("%s_source_grip=%s" % [label, String(source_node.preferred_grip_style_mode if source_node != null else StringName())])
	lines.append("%s_bridge_grip=%s" % [label, String(bridge_node.preferred_grip_style_mode if bridge_node != null else StringName())])
	lines.append("%s_bridge_generated=%s" % [label, str(bridge_node.generated_transition_node if bridge_node != null else false)])
	lines.append("%s_expected_orientation=%s" % [label, str(expected_seed.get("weapon_orientation_degrees", Vector3.ZERO))])
	lines.append("%s_bridge_orientation=%s" % [label, str(bridge_node.weapon_orientation_degrees if bridge_node != null else Vector3.ZERO)])
	lines.append("%s_bridge_orientation_matches_expected=%s" % [
		label,
		str(
			bridge_node != null
			and bridge_node.weapon_orientation_degrees.is_equal_approx(
				expected_seed.get("weapon_orientation_degrees", Vector3.INF) as Vector3
			)
		)
	])
	lines.append("%s_expected_tip=%s" % [label, str(expected_seed.get("tip_position_local", Vector3.ZERO))])
	lines.append("%s_bridge_tip=%s" % [label, str(bridge_node.tip_position_local if bridge_node != null else Vector3.ZERO)])
	lines.append("%s_expected_pommel=%s" % [label, str(expected_seed.get("pommel_position_local", Vector3.ZERO))])
	lines.append("%s_bridge_pommel=%s" % [label, str(bridge_node.pommel_position_local if bridge_node != null else Vector3.ZERO)])
	return lines

func _get_node(draft: CombatAnimationDraft, index: int) -> CombatAnimationMotionNode:
	if draft == null or index < 0 or index >= draft.motion_node_chain.size():
		return null
	return draft.motion_node_chain[index] as CombatAnimationMotionNode

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
