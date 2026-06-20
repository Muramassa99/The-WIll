extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationSessionStateScript = preload("res://core/models/combat_animation_session_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_animation_station_hand_authoring_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/verify_combat_animation_station_hand_authoring_library.tres"
const HAND_SLOT_RIGHT: StringName = &"hand_right"
const HAND_SLOT_LEFT: StringName = &"hand_left"

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
	var lines: PackedStringArray = []
	var failures: PackedStringArray = []

	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library_state.save_file_path = TEMP_SAVE_FILE_PATH
	library_state.saved_wips.clear()
	library_state.selected_wip_id = StringName()

	var source_wip: CraftedItemWIP = CraftedItemWIPScript.new()
	source_wip.forge_project_name = "Hand Authoring Test WIP"
	CraftedItemWIPScript.apply_builder_path_defaults(
		source_wip,
		CraftedItemWIPScript.BUILDER_PATH_MELEE,
		CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	)
	var saved_wip: CraftedItemWIP = library_state.save_wip(source_wip)

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	get_root().add_child(fake_player)

	var ui = CombatAnimationStationUIScene.instantiate()
	get_root().add_child(ui)
	await process_frame
	ui.open_for(fake_player, "HandAuthoringVerifier")
	await process_frame

	var open_weapon_ok: bool = ui.open_saved_wip_with_hand_setup(
		saved_wip.wip_id if saved_wip != null else StringName(),
		HAND_SLOT_RIGHT,
		false,
		true
	)
	await process_frame
	ui.select_skill_slot(&"skill_slot_1")
	await process_frame
	var insert_weapon_node_ok: bool = ui.insert_motion_node_after_selection()
	await process_frame
	ui.set_selected_motion_node_primary_hand_slot(HAND_SLOT_RIGHT, true, true, true, true, true)
	ui.set_selected_motion_node_two_hand_state(
		CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND,
		true,
		true,
		true,
		true,
		true
	)
	await process_frame

	var one_hand_focus_ids: Array = ui.call("_resolve_available_focus_ids") as Array
	var one_hand_left_proxy_focus_available: bool = one_hand_focus_ids.has(CombatAnimationSessionStateScript.FOCUS_LEFT_HAND_PROXY)
	var one_hand_right_proxy_focus_blocked: bool = not one_hand_focus_ids.has(CombatAnimationSessionStateScript.FOCUS_RIGHT_HAND_PROXY)
	var one_hand_right_roll_focus_available: bool = one_hand_focus_ids.has(CombatAnimationSessionStateScript.FOCUS_RIGHT_ARM_ROLL)
	var one_hand_left_roll_focus_available: bool = one_hand_focus_ids.has(CombatAnimationSessionStateScript.FOCUS_LEFT_ARM_ROLL)

	var left_tip_request := Vector3(-0.18, 0.12, 0.26)
	var left_pommel_request := Vector3(-0.27, 0.06, 0.10)
	var left_proxy_update_ok: bool = ui.set_selected_motion_node_hand_proxy_segment(
		HAND_SLOT_LEFT,
		left_tip_request,
		left_pommel_request,
		true,
		true,
		true,
		true,
		true
	)
	await process_frame
	var weapon_node_after_left: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var left_proxy_authored_ok: bool = (
		weapon_node_after_left != null
		and weapon_node_after_left.left_hand_proxy_authored
		and weapon_node_after_left.left_hand_proxy_tip_position_local.distance_to(left_tip_request) <= 0.001
		and weapon_node_after_left.left_hand_proxy_pommel_position_local.distance_to(left_pommel_request) <= 0.001
	)
	var primary_hand_proxy_blocked_ok: bool = not ui.set_selected_motion_node_hand_proxy_segment(
		HAND_SLOT_RIGHT,
		Vector3(0.15, 0.18, 0.19),
		Vector3(0.08, 0.08, 0.05),
		true,
		true,
		true,
		true,
		true
	)

	ui.call("_manual_save_active_editor_state")
	await _wait_for_manual_save(ui)
	var saved_draft: Resource = ui.call("_get_active_draft") as Resource
	var saved_runtime_clip = saved_draft.get("baked_runtime_clip") if saved_draft != null else null
	var baked_left_proxy_any: bool = false
	var baked_left_proxy_frame_count: int = -1
	if saved_runtime_clip != null:
		var baked_left_proxy_authored: Array = saved_runtime_clip.get("baked_left_hand_proxy_authored") as Array
		baked_left_proxy_frame_count = baked_left_proxy_authored.size()
		for authored_variant: Variant in baked_left_proxy_authored:
			if bool(authored_variant):
				baked_left_proxy_any = true
				break

	ui.set_selected_motion_node_two_hand_state(
		CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND,
		true,
		true,
		true,
		true,
		true
	)
	await process_frame
	var two_hand_focus_ids: Array = ui.call("_resolve_available_focus_ids") as Array
	var two_hand_left_proxy_focus_blocked: bool = not two_hand_focus_ids.has(CombatAnimationSessionStateScript.FOCUS_LEFT_HAND_PROXY)
	var two_hand_right_proxy_focus_blocked: bool = not two_hand_focus_ids.has(CombatAnimationSessionStateScript.FOCUS_RIGHT_HAND_PROXY)
	var two_hand_proxy_edit_blocked_ok: bool = not ui.set_selected_motion_node_hand_proxy_segment(
		HAND_SLOT_LEFT,
		Vector3(-0.14, 0.16, 0.25),
		Vector3(-0.22, 0.09, 0.06),
		true,
		true,
		true,
		true,
		true
	)

	var unarmed_select_ok: bool = ui.select_unarmed_authoring(true, {"dominant_slot_id": HAND_SLOT_RIGHT})
	await process_frame
	ui.select_skill_slot(&"skill_slot_2")
	await process_frame
	var insert_unarmed_node_ok: bool = ui.insert_motion_node_after_selection()
	await process_frame
	var unarmed_focus_ids: Array = ui.call("_resolve_available_focus_ids") as Array
	var unarmed_right_proxy_focus_available: bool = unarmed_focus_ids.has(CombatAnimationSessionStateScript.FOCUS_RIGHT_HAND_PROXY)
	var unarmed_left_proxy_focus_available: bool = unarmed_focus_ids.has(CombatAnimationSessionStateScript.FOCUS_LEFT_HAND_PROXY)
	var unarmed_right_tip_request := Vector3(0.21, 0.04, 0.20)
	var unarmed_right_pommel_request := Vector3(0.06, -0.02, 0.04)
	var unarmed_left_tip_request := Vector3(-0.21, 0.04, 0.20)
	var unarmed_left_pommel_request := Vector3(-0.06, -0.02, 0.04)
	var unarmed_right_update_ok: bool = ui.set_selected_motion_node_hand_proxy_segment(
		HAND_SLOT_RIGHT,
		unarmed_right_tip_request,
		unarmed_right_pommel_request,
		true,
		true,
		true,
		true,
		true
	)
	var unarmed_left_update_ok: bool = ui.set_selected_motion_node_hand_proxy_segment(
		HAND_SLOT_LEFT,
		unarmed_left_tip_request,
		unarmed_left_pommel_request,
		true,
		true,
		true,
		true,
		true
	)
	await process_frame
	var unarmed_node_after_hands: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var unarmed_primary_uses_motion_segment_ok: bool = (
		unarmed_node_after_hands != null
		and unarmed_node_after_hands.tip_position_local.distance_to(unarmed_right_tip_request) <= 0.001
		and unarmed_node_after_hands.pommel_position_local.distance_to(unarmed_right_pommel_request) <= 0.001
		and not unarmed_node_after_hands.right_hand_proxy_authored
	)
	var unarmed_offhand_proxy_authored_ok: bool = (
		unarmed_node_after_hands != null
		and unarmed_node_after_hands.left_hand_proxy_authored
		and unarmed_node_after_hands.left_hand_proxy_tip_position_local.distance_to(unarmed_left_tip_request) <= 0.001
		and unarmed_node_after_hands.left_hand_proxy_pommel_position_local.distance_to(unarmed_left_pommel_request) <= 0.001
	)

	var right_roll_update_ok: bool = ui.set_selected_motion_node_upperarm_roll(
		HAND_SLOT_RIGHT,
		17.0,
		true,
		true,
		true,
		true,
		true
	)
	var left_roll_update_ok: bool = ui.set_selected_motion_node_upperarm_roll(
		HAND_SLOT_LEFT,
		-23.0,
		true,
		true,
		true,
		true,
		true
	)
	await process_frame
	var roll_node_after: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	var independent_upperarm_roll_ok: bool = (
		roll_node_after != null
		and is_equal_approx(roll_node_after.right_upperarm_roll_degrees, 17.0)
		and is_equal_approx(roll_node_after.left_upperarm_roll_degrees, -23.0)
	)

	_append_check(lines, failures, "open_weapon_ok", open_weapon_ok)
	_append_check(lines, failures, "insert_weapon_node_ok", insert_weapon_node_ok)
	_append_check(lines, failures, "one_hand_left_proxy_focus_available", one_hand_left_proxy_focus_available)
	_append_check(lines, failures, "one_hand_right_proxy_focus_blocked", one_hand_right_proxy_focus_blocked)
	_append_check(lines, failures, "one_hand_right_roll_focus_available", one_hand_right_roll_focus_available)
	_append_check(lines, failures, "one_hand_left_roll_focus_available", one_hand_left_roll_focus_available)
	_append_check(lines, failures, "left_proxy_update_ok", left_proxy_update_ok)
	_append_check(lines, failures, "left_proxy_authored_ok", left_proxy_authored_ok)
	_append_check(lines, failures, "primary_hand_proxy_blocked_ok", primary_hand_proxy_blocked_ok)
	_append_check(lines, failures, "baked_left_proxy_any", baked_left_proxy_any)
	lines.append("baked_left_proxy_frame_count=%d" % baked_left_proxy_frame_count)
	_append_check(lines, failures, "two_hand_left_proxy_focus_blocked", two_hand_left_proxy_focus_blocked)
	_append_check(lines, failures, "two_hand_right_proxy_focus_blocked", two_hand_right_proxy_focus_blocked)
	_append_check(lines, failures, "two_hand_proxy_edit_blocked_ok", two_hand_proxy_edit_blocked_ok)
	_append_check(lines, failures, "unarmed_select_ok", unarmed_select_ok)
	_append_check(lines, failures, "insert_unarmed_node_ok", insert_unarmed_node_ok)
	_append_check(lines, failures, "unarmed_right_proxy_focus_available", unarmed_right_proxy_focus_available)
	_append_check(lines, failures, "unarmed_left_proxy_focus_available", unarmed_left_proxy_focus_available)
	_append_check(lines, failures, "unarmed_right_update_ok", unarmed_right_update_ok)
	_append_check(lines, failures, "unarmed_left_update_ok", unarmed_left_update_ok)
	_append_check(lines, failures, "unarmed_primary_uses_motion_segment_ok", unarmed_primary_uses_motion_segment_ok)
	_append_check(lines, failures, "unarmed_offhand_proxy_authored_ok", unarmed_offhand_proxy_authored_ok)
	_append_check(lines, failures, "right_roll_update_ok", right_roll_update_ok)
	_append_check(lines, failures, "left_roll_update_ok", left_roll_update_ok)
	_append_check(lines, failures, "independent_upperarm_roll_ok", independent_upperarm_roll_ok)

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	if not failures.is_empty():
		push_error("Hand authoring verification failed: %s" % ", ".join(failures))
		quit(1)
		return
	quit()

func _append_check(lines: PackedStringArray, failures: PackedStringArray, key: String, value: bool) -> void:
	lines.append("%s=%s" % [key, str(value)])
	if not value:
		failures.append(key)

func _wait_for_manual_save(ui) -> void:
	var frame_count: int = 0
	while ui != null and bool(ui.get("manual_save_in_progress")) and frame_count < 240:
		await process_frame
		frame_count += 1
