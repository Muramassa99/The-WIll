extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var player: PlayerController3D = PlayerScene.instantiate() as PlayerController3D
	get_root().add_child(player)
	await process_frame
	await process_frame

	var save_path: String = "c:/WORKSPACE/test_project_load_state.tres"
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create(save_path)
	library_state.saved_wips.clear()
	library_state.selected_wip_id = StringName()
	library_state.persist()

	var alpha_wip: CraftedItemWIP = _make_saved_wip("alpha", "Alpha Sword", "alpha notes")
	var beta_wip: CraftedItemWIP = _make_saved_wip("beta", "Beta Spear", "beta notes")
	var saved_alpha: CraftedItemWIP = library_state.save_wip(alpha_wip)
	var saved_beta: CraftedItemWIP = library_state.save_wip(beta_wip)
	var initial_selected_saved_id: StringName = library_state.selected_wip_id
	player.forge_wip_library_state = library_state

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	get_root().add_child(forge_controller)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_for(player, forge_controller, "Project Load Bench")
	await process_frame
	await process_frame

	var auto_loaded_wip: CraftedItemWIP = forge_controller.active_wip
	var auto_restore_selected_beta: bool = auto_loaded_wip != null and auto_loaded_wip.wip_id == saved_beta.wip_id

	var alpha_project_index: int = _find_project_index(crafting_ui.project_catalog, saved_alpha.wip_id)
	if alpha_project_index >= 0:
		crafting_ui.project_list.select(alpha_project_index)
		crafting_ui.load_project_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var manually_loaded_alpha: bool = forge_controller.active_wip != null and forge_controller.active_wip.wip_id == saved_alpha.wip_id

	crafting_ui.close_ui()
	await process_frame

	var second_forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	get_root().add_child(second_forge_controller)
	var second_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(second_ui)
	await process_frame
	await process_frame

	second_ui.open_for(player, second_forge_controller, "Project Load Bench 2")
	await process_frame
	await process_frame

	var reopened_selected_alpha: bool = second_forge_controller.active_wip != null and second_forge_controller.active_wip.wip_id == saved_alpha.wip_id

	var lines: PackedStringArray = []
	lines.append("saved_alpha_id=%s" % String(saved_alpha.wip_id if saved_alpha != null else &""))
	lines.append("saved_beta_id=%s" % String(saved_beta.wip_id if saved_beta != null else &""))
	lines.append("library_saved_count=%d" % library_state.saved_wips.size())
	lines.append("initial_selected_wip_id=%s" % String(initial_selected_saved_id))
	lines.append("auto_restore_selected_beta=%s" % str(auto_restore_selected_beta))
	lines.append("alpha_project_index=%d" % alpha_project_index)
	lines.append("manually_loaded_alpha=%s" % str(manually_loaded_alpha))
	lines.append("selected_wip_id_after_manual_load=%s" % String(player.forge_wip_library_state.selected_wip_id))
	lines.append("reopened_selected_alpha=%s" % str(reopened_selected_alpha))
	lines.append("load_button_disabled_after_refresh=%s" % str(crafting_ui.load_project_button.disabled))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/crafting_bench_project_load_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _make_saved_wip(suffix: String, project_name: String, project_notes: String) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = StringName("draft_%s" % suffix)
	wip.forge_project_name = project_name
	wip.forge_project_notes = project_notes
	wip.creator_id = &"project_load_verifier"
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	return wip

func _find_project_index(project_catalog: Array[Dictionary], saved_wip_id: StringName) -> int:
	for project_index: int in range(project_catalog.size()):
		var entry: Dictionary = project_catalog[project_index]
		if entry.get("entry_type", &"") != &"saved":
			continue
		if entry.get("saved_wip_id", &"") == saved_wip_id:
			return project_index
	return -1
