extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const CombatAnimationSessionStateScript = preload("res://core/models/combat_animation_session_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/skill_crafter_space_button_focus_guard_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/verify_skill_crafter_space_button_focus_guard_library.tres"

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
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library_state.save_file_path = TEMP_SAVE_FILE_PATH
	library_state.saved_wips.clear()
	library_state.selected_wip_id = StringName()

	var source_wip: CraftedItemWIP = CraftedItemWIPScript.new()
	source_wip.forge_project_name = "Space Button Focus Guard"
	CraftedItemWIPScript.apply_builder_path_defaults(
		source_wip,
		CraftedItemWIPScript.BUILDER_PATH_MELEE,
		CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	)
	var saved_wip: CraftedItemWIP = library_state.save_wip(source_wip)

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Space Guard Verifier")
	await process_frame
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(saved_wip.wip_id if saved_wip != null else StringName(), &"hand_right", false, true)
	await process_frame
	var select_ok: bool = ui.select_skill_slot(&"skill_slot_1", true)
	await process_frame

	var action_buttons_focus_none: bool = (
		ui.add_point_button.focus_mode == Control.FOCUS_NONE
		and ui.duplicate_point_button.focus_mode == Control.FOCUS_NONE
		and ui.remove_point_button.focus_mode == Control.FOCUS_NONE
		and ui.reset_draft_button.focus_mode == Control.FOCUS_NONE
		and ui.save_button.focus_mode == Control.FOCUS_NONE
		and ui.play_preview_button.focus_mode == Control.FOCUS_NONE
	)

	ui.session_state.current_focus = CombatAnimationSessionStateScript.FOCUS_TIP
	var initial_count: int = _get_motion_node_count(ui)
	ui.add_point_button.emit_signal("pressed")
	await process_frame
	var after_add_count: int = _get_motion_node_count(ui)
	var after_add_focus: StringName = ui.session_state.current_focus
	ui.call("_input", _build_space_key_event())
	await process_frame
	var after_add_space_count: int = _get_motion_node_count(ui)
	var after_add_space_focus: StringName = ui.session_state.current_focus

	ui.insert_motion_node_after_selection()
	await process_frame
	ui.select_motion_node(_get_motion_node_count(ui) - 1)
	await process_frame
	var before_delete_button_count: int = _get_motion_node_count(ui)
	ui.remove_point_button.emit_signal("pressed")
	await process_frame
	var after_delete_count: int = _get_motion_node_count(ui)
	var after_delete_focus: StringName = ui.session_state.current_focus
	ui.call("_input", _build_space_key_event())
	await process_frame
	var after_delete_space_count: int = _get_motion_node_count(ui)
	var after_delete_space_focus: StringName = ui.session_state.current_focus

	var lines: PackedStringArray = []
	lines.append("open_ok=%s" % str(open_ok))
	lines.append("select_ok=%s" % str(select_ok))
	lines.append("action_buttons_focus_none=%s" % str(action_buttons_focus_none))
	lines.append("initial_count=%d" % initial_count)
	lines.append("after_add_count=%d" % after_add_count)
	lines.append("after_add_focus=%s" % String(after_add_focus))
	lines.append("after_add_space_count=%d" % after_add_space_count)
	lines.append("after_add_space_focus=%s" % String(after_add_space_focus))
	lines.append("space_after_add_did_not_repeat_add=%s" % str(after_add_space_count == after_add_count))
	lines.append("space_after_add_cycled_focus=%s" % str(after_add_space_focus == CombatAnimationSessionStateScript.FOCUS_POMMEL))
	lines.append("before_delete_button_count=%d" % before_delete_button_count)
	lines.append("after_delete_count=%d" % after_delete_count)
	lines.append("after_delete_focus=%s" % String(after_delete_focus))
	lines.append("after_delete_space_count=%d" % after_delete_space_count)
	lines.append("after_delete_space_focus=%s" % String(after_delete_space_focus))
	lines.append("space_after_delete_did_not_repeat_delete=%s" % str(after_delete_space_count == after_delete_count))
	lines.append("space_after_delete_cycled_focus=%s" % str(after_delete_space_focus == CombatAnimationSessionStateScript.FOCUS_WEAPON))
	lines.append("all_checks_passed=%s" % str(
		open_ok
		and select_ok
		and action_buttons_focus_none
		and after_add_count == initial_count + 1
		and after_add_space_count == after_add_count
		and after_add_space_focus == CombatAnimationSessionStateScript.FOCUS_POMMEL
		and after_delete_count == before_delete_button_count - 1
		and after_delete_space_count == after_delete_count
		and after_delete_space_focus == CombatAnimationSessionStateScript.FOCUS_WEAPON
	))
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _build_space_key_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	return event

func _get_motion_node_count(ui: CombatAnimationStationUI) -> int:
	var draft: Resource = ui.call("_get_active_draft") as Resource
	if draft == null:
		return 0
	return (draft.get("motion_node_chain") as Array).size()
