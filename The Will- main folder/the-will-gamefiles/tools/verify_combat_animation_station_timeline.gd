extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const ForgeV2AuthoringStateScript = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const PreviewPresenter = preload("res://runtime/combat/combat_animation_station_preview_presenter.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_animation_station_timeline_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/verify_combat_animation_station_timeline_library.tres"

class TimelinePresenter extends PreviewPresenter:
	# This fixture has no Forge geometry. Inject an explicitly valid frame only
	# at the presenter seam to test UI insertion/selection/locking. Actual frame
	# reconstruction is covered by verify_grip_style_transition.gd.
	func resolve_grip_style_transition_seed(_viewport: SubViewport,
			motion: CombatAnimationMotionNode, _style: StringName) -> Dictionary:
		return {"available": true, "tip_position_local": Vector3(0, 0, -0.7),
			"pommel_position_local": Vector3(0, 0, 0.3),
			"tip_position_origin_id": Origins.ORIGIN_TRAJECTORY_AUTHORING,
			"pommel_position_origin_id": Origins.ORIGIN_TRAJECTORY_AUTHORING,
			"weapon_orientation_degrees": Vector3.ZERO,
			"weapon_roll_degrees": motion.weapon_roll_degrees,
			"grip_style_transition_pivot_local": Vector3.ZERO,
			"grip_style_transition_axis_local": Vector3.UP,
			"grip_style_transition_source_tip_local": Vector3(0, 0, 0.7),
			"grip_style_transition_source_pommel_local": Vector3(0, 0, -0.3)}

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
	source_wip.forge_project_name = "Combat Timeline Test WIP"
	CraftedItemWIPScript.apply_builder_path_defaults(
		source_wip,
		CraftedItemWIPScript.BUILDER_PATH_MELEE,
		CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	)
	source_wip.forge_v2_authoring_state = ForgeV2AuthoringStateScript.new()
	source_wip.forge_v2_authoring_state.call("reset_new_draft", source_wip.forge_project_name)
	var saved_wip: CraftedItemWIP = library_state.save_wip(source_wip)

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	get_root().add_child(fake_player)

	var ui = CombatAnimationStationUIScene.instantiate()
	get_root().add_child(ui)
	await process_frame
	ui.open_for(fake_player, "TimelineVerifier")
	await process_frame
	ui.open_saved_wip_with_hand_setup(saved_wip.wip_id if saved_wip != null else StringName(), &"hand_right", false, true)
	await process_frame
	ui.select_skill_slot(&"skill_slot_6")
	ui.set_active_draft_skill_name("Timeline Alpha")
	await process_frame

	var insert_ok: bool = ui.insert_motion_node_after_selection()
	await process_frame
	ui.set_selected_motion_node_transition_duration(0.33)
	ui.select_motion_node(2)
	ui.set_selected_motion_node_transition_duration(0.67)
	ui.set_selected_motion_node_as_continuity()
	await process_frame

	var active_draft: Resource = ui.call("_get_active_draft") as Resource
	var timestamps_before_delete: Array = []
	if active_draft != null:
		timestamps_before_delete = active_draft.call("get_motion_node_timestamps") as Array

	ui.select_motion_node(1)
	var delete_ok: bool = ui.remove_selected_motion_node()
	await process_frame

	active_draft = ui.call("_get_active_draft") as Resource
	var timestamps_after_delete: Array = []
	if active_draft != null:
		timestamps_after_delete = active_draft.call("get_motion_node_timestamps") as Array
	var continuity_index_after_delete: int = int(active_draft.get("continuity_motion_node_index")) if active_draft != null else -1
	var selected_index_after_delete: int = int(active_draft.get("selected_motion_node_index")) if active_draft != null else -1
	var remaining_chain: Array = active_draft.get("motion_node_chain") as Array if active_draft != null else []
	var remaining_node_transition: float = 0.0
	if remaining_chain.size() > 1:
		var remaining_node: Resource = remaining_chain[1] as Resource
		remaining_node_transition = float(remaining_node.get("transition_duration_seconds")) if remaining_node != null else 0.0

	ui.select_motion_node(1)
	var before_empty_preview_count: int = active_draft.motion_node_chain.size()
	var empty_preview_refused: bool = not ui.set_selected_motion_node_preferred_grip_style(CraftedItemWIPScript.GRIP_REVERSE)
	var empty_preview_preserved_chain: bool = active_draft.motion_node_chain.size() == before_empty_preview_count
	ui.preview_presenter = TimelinePresenter.new()
	var grip_swap_insert_ok: bool = ui.set_selected_motion_node_preferred_grip_style(CraftedItemWIPScript.GRIP_REVERSE)
	await process_frame
	active_draft = ui.call("_get_active_draft") as Resource
	var generated_chain: Array = active_draft.get("motion_node_chain") as Array if active_draft != null else []
	var generated_selected_index: int = int(active_draft.get("selected_motion_node_index")) if active_draft != null else -1
	# A style swap now selects its editable continuation; explicitly select the
	# preceding generated bridge to retain this proof's locked-endpoint checks.
	var generated_follow_on: Resource = generated_chain[generated_selected_index] as Resource if generated_selected_index >= 0 and generated_selected_index < generated_chain.size() else null
	var generated_follow_on_editable: bool = generated_follow_on != null and not bool(generated_follow_on.get("locked_for_authoring")) and not bool(generated_follow_on.get("generated_transition_node"))
	var generated_bridge_index: int = generated_selected_index - 1
	var generated_bridge: Resource = generated_chain[generated_bridge_index] as Resource if generated_bridge_index >= 0 and generated_bridge_index < generated_chain.size() else null
	ui.select_motion_node(generated_bridge_index)
	var generated_bridge_locked: bool = bool(generated_bridge.get("locked_for_authoring")) if generated_bridge != null else false
	var generated_bridge_kind: StringName = generated_bridge.get("generated_transition_kind") if generated_bridge != null else StringName()
	var generated_bridge_grip: StringName = generated_bridge.get("preferred_grip_style_mode") if generated_bridge != null else StringName()
	var generated_bridge_tip_before: Vector3 = generated_bridge.get("tip_position_local") if generated_bridge != null else Vector3.ZERO
	var generated_edit_rejected: bool = not ui.set_selected_motion_node_tip_position(generated_bridge_tip_before + Vector3(1.0, 0.0, 0.0))
	var generated_bridge_tip_after: Vector3 = generated_bridge.get("tip_position_local") if generated_bridge != null else Vector3.ZERO
	var generated_edit_preserved_tip: bool = generated_bridge_tip_after.is_equal_approx(generated_bridge_tip_before)
	var generated_delete_ok: bool = ui.remove_selected_motion_node()
	await process_frame

	var lines: PackedStringArray = []
	lines.append("insert_ok=%s" % str(insert_ok))
	lines.append("delete_ok=%s" % str(delete_ok))
	lines.append("timestamps_before_delete=%s" % str(timestamps_before_delete))
	lines.append("timestamps_after_delete=%s" % str(timestamps_after_delete))
	lines.append("selected_index_after_delete=%d" % selected_index_after_delete)
	lines.append("continuity_index_after_delete=%d" % continuity_index_after_delete)
	lines.append("remaining_motion_node_count=%d" % remaining_chain.size())
	lines.append("remaining_node_transition=%s" % str(snapped(remaining_node_transition, 0.0001)))
	lines.append("empty_preview_refused=%s" % str(empty_preview_refused))
	lines.append("empty_preview_preserved_chain=%s" % str(empty_preview_preserved_chain))
	lines.append("transition_frame_source=explicit_timeline_presenter_fixture")
	lines.append("grip_swap_insert_ok=%s" % str(grip_swap_insert_ok))
	lines.append("generated_selected_index=%d" % generated_selected_index)
	lines.append("generated_follow_on_editable=%s" % str(generated_follow_on_editable))
	lines.append("generated_bridge_index=%d" % generated_bridge_index)
	lines.append("generated_bridge_locked=%s" % str(generated_bridge_locked))
	lines.append("generated_bridge_kind=%s" % String(generated_bridge_kind))
	lines.append("generated_bridge_grip=%s" % String(generated_bridge_grip))
	lines.append("generated_edit_rejected=%s" % str(generated_edit_rejected))
	lines.append("generated_edit_preserved_tip=%s" % str(generated_edit_preserved_tip))
	lines.append("generated_delete_ok=%s" % str(generated_delete_ok))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	var passed := insert_ok and delete_ok and empty_preview_refused and empty_preview_preserved_chain \
		and grip_swap_insert_ok and generated_follow_on_editable and generated_bridge_locked \
		and generated_edit_rejected and generated_edit_preserved_tip and generated_delete_ok
	quit(0 if passed else 1)
