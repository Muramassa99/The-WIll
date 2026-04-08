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

	var save_path: String = "c:/WORKSPACE/test_start_menu_state.tres"
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create(save_path)
	library_state.saved_wips.clear()
	library_state.selected_wip_id = StringName()
	library_state.persist()

	var saved_wip: CraftedItemWIP = _make_saved_wip("menu_beta", "Menu Beta", CraftedItemWIPScript.BUILDER_PATH_SHIELD)
	var persisted_saved_wip: CraftedItemWIP = library_state.save_wip(saved_wip)
	player.forge_wip_library_state = library_state

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	get_root().add_child(forge_controller)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_start_menu_for(player, forge_controller, "Start Menu Bench")
	await process_frame
	await process_frame

	var start_menu_visible_on_open: bool = crafting_ui.start_menu_panel.visible and not crafting_ui.main_hbox.visible
	var continue_last_enabled: bool = not crafting_ui.start_menu_continue_last_button.disabled
	var project_list_enabled: bool = not crafting_ui.start_menu_project_list_button.disabled
	var background_saved_wip_loaded: bool = forge_controller.active_wip != null and forge_controller.active_wip.wip_id == persisted_saved_wip.wip_id
	var background_saved_wip_is_shield: bool = forge_controller.active_wip != null and forge_controller.active_wip.forge_builder_path_id == CraftedItemWIPScript.BUILDER_PATH_SHIELD
	var background_saved_wip_grid_ok: bool = forge_controller.grid_size == Vector3i(100, 80, 30)

	crafting_ui.start_menu_continue_last_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var continue_last_loaded_shield: bool = forge_controller.active_wip != null and forge_controller.active_wip.forge_builder_path_id == CraftedItemWIPScript.BUILDER_PATH_SHIELD
	var continue_last_grid_ok: bool = forge_controller.grid_size == Vector3i(100, 80, 30)

	crafting_ui.close_ui()
	await process_frame
	crafting_ui.open_start_menu_for(player, forge_controller, "Start Menu Bench")
	await process_frame
	await process_frame

	crafting_ui.start_menu_project_list_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var project_list_opened_editor_shell: bool = not crafting_ui.start_menu_panel.visible and crafting_ui.main_hbox.visible
	var project_manager_popup_visible: bool = crafting_ui.project_manager_popup.visible
	var project_list_has_saved_entry: bool = _find_saved_project_index(crafting_ui.project_catalog, persisted_saved_wip.wip_id) >= 0

	crafting_ui.close_ui()
	await process_frame
	crafting_ui.open_start_menu_for(player, forge_controller, "Start Menu Bench")
	await process_frame
	await process_frame

	crafting_ui.start_menu_new_ranged_physical_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var ranged_wip: CraftedItemWIP = forge_controller.active_wip
	var ranged_path_ok: bool = ranged_wip != null and ranged_wip.forge_builder_path_id == CraftedItemWIPScript.BUILDER_PATH_RANGED_PHYSICAL
	var ranged_intent_ok: bool = ranged_wip != null and ranged_wip.forge_intent == &"intent_ranged"
	var ranged_context_ok: bool = ranged_wip != null and ranged_wip.equipment_context == &"ctx_weapon"
	var ranged_grid_ok: bool = forge_controller.grid_size == Vector3i(160, 80, 30)
	var menu_hidden_after_ranged: bool = not crafting_ui.start_menu_panel.visible and crafting_ui.main_hbox.visible

	crafting_ui.new_project_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var repeated_ranged_wip: CraftedItemWIP = forge_controller.active_wip
	var new_project_kept_ranged_path: bool = repeated_ranged_wip != null and repeated_ranged_wip.forge_builder_path_id == CraftedItemWIPScript.BUILDER_PATH_RANGED_PHYSICAL

	crafting_ui.close_ui()
	await process_frame

	crafting_ui.open_start_menu_for(player, forge_controller, "Start Menu Bench")
	await process_frame
	await process_frame
	crafting_ui.start_menu_new_shield_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var shield_wip: CraftedItemWIP = forge_controller.active_wip
	var shield_path_ok: bool = shield_wip != null and shield_wip.forge_builder_path_id == CraftedItemWIPScript.BUILDER_PATH_SHIELD
	var shield_intent_ok: bool = shield_wip != null and shield_wip.forge_intent == &"intent_shield"
	var shield_context_ok: bool = shield_wip != null and shield_wip.equipment_context == &"ctx_shield"
	var shield_grid_ok: bool = forge_controller.grid_size == Vector3i(100, 80, 30)

	crafting_ui.close_ui()
	await process_frame

	crafting_ui.open_start_menu_for(player, forge_controller, "Start Menu Bench")
	await process_frame
	await process_frame
	crafting_ui.start_menu_new_melee_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var melee_wip: CraftedItemWIP = forge_controller.active_wip
	var melee_path_ok: bool = melee_wip != null and melee_wip.forge_builder_path_id == CraftedItemWIPScript.BUILDER_PATH_MELEE
	var melee_grid_ok: bool = forge_controller.grid_size == Vector3i(240, 80, 40)

	crafting_ui.close_ui()
	await process_frame

	crafting_ui.open_start_menu_for(player, forge_controller, "Start Menu Bench")
	await process_frame
	await process_frame
	crafting_ui.start_menu_new_magic_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var magic_wip: CraftedItemWIP = forge_controller.active_wip
	var magic_path_ok: bool = magic_wip != null and magic_wip.forge_builder_path_id == CraftedItemWIPScript.BUILDER_PATH_MAGIC
	var magic_intent_ok: bool = magic_wip != null and magic_wip.forge_intent == &"intent_magic"
	var magic_context_ok: bool = magic_wip != null and magic_wip.equipment_context == &"ctx_focus"
	var magic_grid_ok: bool = forge_controller.grid_size == Vector3i(100, 30, 30)

	var lines: PackedStringArray = []
	lines.append("start_menu_visible_on_open=%s" % str(start_menu_visible_on_open))
	lines.append("continue_last_enabled=%s" % str(continue_last_enabled))
	lines.append("project_list_enabled=%s" % str(project_list_enabled))
	lines.append("background_saved_wip_loaded=%s" % str(background_saved_wip_loaded))
	lines.append("background_saved_wip_is_shield=%s" % str(background_saved_wip_is_shield))
	lines.append("background_saved_wip_grid_ok=%s" % str(background_saved_wip_grid_ok))
	lines.append("continue_last_loaded_shield=%s" % str(continue_last_loaded_shield))
	lines.append("continue_last_grid_ok=%s" % str(continue_last_grid_ok))
	lines.append("project_list_opened_editor_shell=%s" % str(project_list_opened_editor_shell))
	lines.append("project_manager_popup_visible=%s" % str(project_manager_popup_visible))
	lines.append("project_list_has_saved_entry=%s" % str(project_list_has_saved_entry))
	lines.append("melee_path_ok=%s" % str(melee_path_ok))
	lines.append("melee_grid_ok=%s" % str(melee_grid_ok))
	lines.append("ranged_path_ok=%s" % str(ranged_path_ok))
	lines.append("ranged_intent_ok=%s" % str(ranged_intent_ok))
	lines.append("ranged_context_ok=%s" % str(ranged_context_ok))
	lines.append("ranged_grid_ok=%s" % str(ranged_grid_ok))
	lines.append("menu_hidden_after_ranged=%s" % str(menu_hidden_after_ranged))
	lines.append("new_project_kept_ranged_path=%s" % str(new_project_kept_ranged_path))
	lines.append("shield_path_ok=%s" % str(shield_path_ok))
	lines.append("shield_intent_ok=%s" % str(shield_intent_ok))
	lines.append("shield_context_ok=%s" % str(shield_context_ok))
	lines.append("shield_grid_ok=%s" % str(shield_grid_ok))
	lines.append("magic_path_ok=%s" % str(magic_path_ok))
	lines.append("magic_intent_ok=%s" % str(magic_intent_ok))
	lines.append("magic_context_ok=%s" % str(magic_context_ok))
	lines.append("magic_grid_ok=%s" % str(magic_grid_ok))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/crafting_bench_start_menu_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _make_saved_wip(suffix: String, project_name: String, builder_path_id: StringName) -> CraftedItemWIP:
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = StringName("draft_%s" % suffix)
	wip.forge_project_name = project_name
	wip.creator_id = &"start_menu_verifier"
	CraftedItemWIPScript.apply_builder_path_defaults(wip, builder_path_id)
	return wip

func _find_saved_project_index(project_catalog: Array[Dictionary], saved_wip_id: StringName) -> int:
	for project_index: int in range(project_catalog.size()):
		var entry: Dictionary = project_catalog[project_index]
		if entry.get("entry_type", &"") != &"saved":
			continue
		if entry.get("saved_wip_id", &"") == saved_wip_id:
			return project_index
	return -1
