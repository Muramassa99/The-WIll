extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_animation_station_workflow_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/verify_combat_animation_station_workflow_library.tres"

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
	source_wip.forge_project_name = "Combat Editor Test WIP"
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
	ui.open_for(fake_player, "Verifier")
	await process_frame

	var opened: bool = ui.is_open()
	var selected_wip_before: StringName = ui.get_active_saved_wip_id()
	var created_skill_id: StringName = ui.create_skill_draft(&"skill_custom_alpha", "Custom Alpha")
	await process_frame
	var selected_draft_after_create: StringName = ui.get_active_draft_identifier()
	var add_node_ok: bool = ui.insert_motion_node_after_selection()
	await process_frame
	var node_selection_after_insert: int = ui.get_selected_motion_node_index()
	var tip_position_ok: bool = ui.set_selected_motion_node_tip_position(Vector3(0.15, 0.02, -0.21))
	var plane_orientation_ok: bool = ui.set_selected_motion_node_plane_orientation(Vector3(-12.0, 6.0, 18.0))
	var transition_update_ok: bool = ui.set_selected_motion_node_transition_duration(0.44)
	var support_blend_ok: bool = ui.set_selected_motion_node_body_support_blend(0.35)
	var two_hand_ok: bool = ui.set_selected_motion_node_two_hand_state(&"two_hand_two_hand")
	var notes_ok: bool = ui.set_active_draft_notes("Verifier notes")
	await process_frame

	var reloaded_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create(TEMP_SAVE_FILE_PATH)
	var reloaded_wip: CraftedItemWIP = reloaded_library.get_saved_wip(saved_wip.wip_id if saved_wip != null else StringName())
	var reloaded_station_state: Resource = reloaded_wip.combat_animation_station_state if reloaded_wip != null else null
	var reloaded_skill_drafts: Array = reloaded_station_state.get("skill_drafts") as Array if reloaded_station_state != null else []
	var reloaded_custom_draft: Resource = _find_skill_draft(reloaded_skill_drafts, created_skill_id)
	var reloaded_motion_nodes: Array = reloaded_custom_draft.get("motion_node_chain") as Array if reloaded_custom_draft != null else []
	var reloaded_node: Resource = reloaded_motion_nodes[1] as Resource if reloaded_motion_nodes.size() > 1 else null

	var lines: PackedStringArray = []
	lines.append("station_opened=%s" % str(opened))
	lines.append("player_ui_mode_enabled=%s" % str(fake_player.ui_mode_enabled))
	lines.append("selected_wip_before=%s" % String(selected_wip_before))
	lines.append("created_skill_id=%s" % String(created_skill_id))
	lines.append("selected_draft_after_create=%s" % String(selected_draft_after_create))
	lines.append("skill_draft_created=%s" % str(reloaded_custom_draft != null))
	lines.append("insert_node_ok=%s" % str(add_node_ok))
	lines.append("node_selection_after_insert=%d" % node_selection_after_insert)
	lines.append("reloaded_motion_node_count=%d" % reloaded_motion_nodes.size())
	lines.append("tip_position_ok=%s" % str(tip_position_ok))
	lines.append("plane_orientation_ok=%s" % str(plane_orientation_ok))
	lines.append("transition_update_ok=%s" % str(transition_update_ok))
	lines.append("support_blend_ok=%s" % str(support_blend_ok))
	lines.append("two_hand_ok=%s" % str(two_hand_ok))
	lines.append("notes_ok=%s" % str(notes_ok))
	lines.append("reloaded_node_tip_position=%s" % str(reloaded_node.get("tip_position_local") if reloaded_node != null else Vector3.ZERO))
	lines.append("reloaded_node_plane_orientation=%s" % str(reloaded_node.get("trajectory_plane_orientation_degrees") if reloaded_node != null else Vector3.ZERO))
	lines.append("reloaded_node_transition=%s" % str(snapped(float(reloaded_node.get("transition_duration_seconds")) if reloaded_node != null else -1.0, 0.0001)))
	lines.append("reloaded_node_support_blend=%s" % str(snapped(float(reloaded_node.get("body_support_blend")) if reloaded_node != null else -1.0, 0.0001)))
	lines.append("reloaded_node_two_hand_state=%s" % String(reloaded_node.get("two_hand_state") if reloaded_node != null else StringName()))
	lines.append("reloaded_notes=%s" % String(reloaded_custom_draft.get("draft_notes") if reloaded_custom_draft != null else ""))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _find_skill_draft(skill_drafts: Array, skill_id: StringName) -> Resource:
	for draft_variant: Variant in skill_drafts:
		var draft: Resource = draft_variant as Resource
		if draft != null and draft.get("owning_skill_id") == skill_id:
			return draft
	return null
