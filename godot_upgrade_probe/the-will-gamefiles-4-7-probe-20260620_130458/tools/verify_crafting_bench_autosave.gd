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

	var save_path: String = "c:/WORKSPACE/test_crafting_bench_autosave_state.tres"
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create(save_path)
	library_state.saved_wips.clear()
	library_state.selected_wip_id = StringName()
	library_state.persist()
	player.forge_wip_library_state = library_state

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	get_root().add_child(forge_controller)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_for(player, forge_controller, "Autosave Verifier Bench")
	await process_frame
	await process_frame

	var material_ids: Array[StringName] = forge_controller.get_material_catalog_ids()
	var first_material_id: StringName = material_ids[0] if not material_ids.is_empty() else StringName()

	if first_material_id != StringName():
		forge_controller.set_material_at(Vector3i(2, 2, 2), first_material_id)
	crafting_ui.project_name_edit.text = "Autosave Close Test"
	crafting_ui.project_notes_edit.text = "close autosave"
	await process_frame

	crafting_ui.close_ui()
	await process_frame
	await process_frame

	var saved_after_close_count: int = library_state.get_saved_wips().size()
	var saved_after_close_wip: CraftedItemWIP = library_state.get_saved_wip(library_state.selected_wip_id)
	var close_autosave_exists: bool = saved_after_close_wip != null
	var close_autosave_has_cells: bool = _count_cells(saved_after_close_wip) > 0

	crafting_ui.open_for(player, forge_controller, "Autosave Verifier Bench")
	await process_frame
	await process_frame

	if first_material_id != StringName():
		forge_controller.set_material_at(Vector3i(3, 3, 3), first_material_id)
	crafting_ui.project_name_edit.text = "Switch Save Test"
	crafting_ui.project_notes_edit.text = "switch autosave"
	await process_frame

	crafting_ui.call("_create_new_blank_project_for_builder_path", CraftedItemWIPScript.BUILDER_PATH_SHIELD)
	await process_frame
	await process_frame

	var saved_after_switch_count: int = library_state.get_saved_wips().size()
	var switch_autosave_saved: bool = false
	var switch_autosave_has_cells: bool = false
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip == null:
			continue
		if saved_wip.forge_project_name != "Switch Save Test":
			continue
		switch_autosave_saved = true
		switch_autosave_has_cells = _count_cells(saved_wip) > 0
		break
	var switched_to_shield_path: bool = (
		forge_controller.active_wip != null
		and forge_controller.active_wip.forge_builder_path_id == CraftedItemWIPScript.BUILDER_PATH_SHIELD
	)

	var lines: PackedStringArray = []
	lines.append("close_autosave_exists=%s" % str(close_autosave_exists))
	lines.append("close_autosave_has_cells=%s" % str(close_autosave_has_cells))
	lines.append("saved_after_close_count=%d" % saved_after_close_count)
	lines.append("switch_autosave_saved=%s" % str(switch_autosave_saved))
	lines.append("switch_autosave_has_cells=%s" % str(switch_autosave_has_cells))
	lines.append("saved_after_switch_count=%d" % saved_after_switch_count)
	lines.append("switched_to_shield_path=%s" % str(switched_to_shield_path))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/crafting_bench_autosave_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()

func _count_cells(wip: CraftedItemWIP) -> int:
	if wip == null:
		return 0
	var count: int = 0
	for layer_atom: LayerAtom in wip.layers:
		if layer_atom == null:
			continue
		count += layer_atom.cells.size()
	return count
