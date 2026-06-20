extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")

func _init() -> void:
	var save_path: String = "user://forge/test_player_wip_library_state.tres"
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create(save_path)
	library_state.saved_wips.clear()
	library_state.selected_wip_id = StringName()
	var source_wip: CraftedItemWIP = CraftedItemWIPScript.new()
	source_wip.wip_id = &"draft_test"
	source_wip.forge_project_name = "Forge Temp Alpha"
	source_wip.forge_project_notes = "initial notes"
	source_wip.creator_id = &"test_runner"
	source_wip.forge_intent = &"intent_melee"
	source_wip.equipment_context = &"ctx_weapon"
	var saved_wip: CraftedItemWIP = library_state.save_wip(source_wip)
	var duplicated_wip: CraftedItemWIP = library_state.duplicate_saved_wip(saved_wip.wip_id if saved_wip != null else StringName())
	var deleted_duplicate: bool = library_state.delete_saved_wip(duplicated_wip.wip_id if duplicated_wip != null else StringName())
	var reloaded_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create(save_path)
	var reloaded_wip: CraftedItemWIP = reloaded_state.get_saved_wip(reloaded_state.selected_wip_id)
	var lines: PackedStringArray = []
	lines.append("saved_count=%d" % reloaded_state.saved_wips.size())
	lines.append("selected_wip_id=%s" % String(reloaded_state.selected_wip_id))
	lines.append("saved_copy_id=%s" % String(saved_wip.wip_id if saved_wip != null else &""))
	lines.append("reloaded_project_name=%s" % String(reloaded_wip.forge_project_name if reloaded_wip != null else ""))
	lines.append("reloaded_project_notes=%s" % String(reloaded_wip.forge_project_notes if reloaded_wip != null else ""))
	lines.append("duplicate_deleted=%s" % str(deleted_duplicate))
	lines.append("post_delete_saved_count=%d" % reloaded_state.saved_wips.size())
	lines.append("reloaded_creator_id=%s" % String(reloaded_wip.creator_id if reloaded_wip != null else &""))
	var file: FileAccess = FileAccess.open("c:/WORKSPACE/godot_forge_project_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()