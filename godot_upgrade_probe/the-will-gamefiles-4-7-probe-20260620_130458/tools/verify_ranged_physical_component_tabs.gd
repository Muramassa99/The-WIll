extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerScene = preload("res://scenes/player/player_character.tscn")
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var player: PlayerController3D = PlayerScene.instantiate() as PlayerController3D
	get_root().add_child(player)
	await process_frame
	await process_frame

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	get_root().add_child(forge_controller)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_start_menu_for(player, forge_controller, "Ranged Component Tabs Bench")
	await process_frame
	await process_frame

	crafting_ui.start_menu_new_ranged_physical_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var ranged_bow_wip: CraftedItemWIP = forge_controller.active_wip
	var ranged_tabs_visible: bool = crafting_ui.builder_component_tabs.visible
	var bow_button_active_on_open: bool = crafting_ui.builder_component_bow_button.button_pressed
	var quiver_button_inactive_on_open: bool = not crafting_ui.builder_component_quiver_button.button_pressed
	var ranged_bow_component_ok: bool = (
		ranged_bow_wip != null
		and ranged_bow_wip.forge_builder_component_id == CraftedItemWIPScript.BUILDER_COMPONENT_BOW
		and forge_controller.grid_size == Vector3i(320, 160, 60)
	)

	crafting_ui.builder_component_quiver_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var ranged_quiver_wip: CraftedItemWIP = forge_controller.active_wip
	var quiver_button_active_after_switch: bool = crafting_ui.builder_component_quiver_button.button_pressed
	var bow_button_inactive_after_switch: bool = not crafting_ui.builder_component_bow_button.button_pressed
	var ranged_quiver_component_ok: bool = (
		ranged_quiver_wip != null
		and ranged_quiver_wip.forge_builder_component_id == CraftedItemWIPScript.BUILDER_COMPONENT_QUIVER
		and forge_controller.grid_size == Vector3i(140, 60, 60)
		and crafting_ui.project_source_label.text.to_lower().contains("quiver")
	)

	crafting_ui.new_project_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var new_project_kept_quiver_component: bool = (
		forge_controller.active_wip != null
		and forge_controller.active_wip.forge_builder_path_id == CraftedItemWIPScript.BUILDER_PATH_RANGED_PHYSICAL
		and forge_controller.active_wip.forge_builder_component_id == CraftedItemWIPScript.BUILDER_COMPONENT_QUIVER
		and forge_controller.grid_size == Vector3i(140, 60, 60)
	)

	crafting_ui.close_ui()
	await process_frame

	crafting_ui.open_start_menu_for(player, forge_controller, "Ranged Component Tabs Bench")
	await process_frame
	await process_frame
	crafting_ui.start_menu_new_shield_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var shield_tabs_hidden: bool = not crafting_ui.builder_component_tabs.visible

	var lines: PackedStringArray = []
	lines.append("ranged_tabs_visible=%s" % str(ranged_tabs_visible))
	lines.append("bow_button_active_on_open=%s" % str(bow_button_active_on_open))
	lines.append("quiver_button_inactive_on_open=%s" % str(quiver_button_inactive_on_open))
	lines.append("ranged_bow_component_ok=%s" % str(ranged_bow_component_ok))
	lines.append("quiver_button_active_after_switch=%s" % str(quiver_button_active_after_switch))
	lines.append("bow_button_inactive_after_switch=%s" % str(bow_button_inactive_after_switch))
	lines.append("ranged_quiver_component_ok=%s" % str(ranged_quiver_component_ok))
	lines.append("new_project_kept_quiver_component=%s" % str(new_project_kept_quiver_component))
	lines.append("shield_tabs_hidden=%s" % str(shield_tabs_hidden))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/ranged_physical_component_tabs_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
