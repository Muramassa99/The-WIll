extends RefCounted
class_name ForgeBenchStartMenuPresenter

const DEFAULT_MENU_SUBTITLE := "Continue the last saved forge state or start a new crafting path. Melee is the current full workflow. Ranged Physical, Shield, and Magic now have their own entry paths and will diverge further as their dedicated builders come online."

func apply_menu_visibility(
	menu_visible: bool,
	start_menu_panel: Control,
	main_hbox: Control
) -> void:
	start_menu_panel.visible = menu_visible
	main_hbox.visible = not menu_visible

func apply_menu_surface(
	bench_name: String,
	title_label: Label,
	subtitle_label: Label
) -> void:
	title_label.text = "%s Forge Station" % bench_name
	subtitle_label.text = DEFAULT_MENU_SUBTITLE

func apply_editor_surface(
	bench_name: String,
	builder_path_id: StringName,
	title_label: Label,
	subtitle_label: Label
) -> void:
	title_label.text = "%s Forge Station" % bench_name
	subtitle_label.text = _resolve_editor_subtitle(builder_path_id)

func apply_continue_last_button_state(
	wip_library: PlayerForgeWipLibraryState,
	continue_last_button: BaseButton
) -> void:
	if continue_last_button == null:
		return
	var has_saved_projects: bool = wip_library != null and wip_library.has_saved_wips()
	var has_selected_saved_project: bool = (
		wip_library != null
		and wip_library.selected_wip_id != StringName()
		and wip_library.get_saved_wip(wip_library.selected_wip_id) != null
	)
	continue_last_button.disabled = not has_saved_projects and not has_selected_saved_project

func _resolve_editor_subtitle(builder_path_id: StringName) -> String:
	match CraftedItemWIP.normalize_builder_path_id(builder_path_id):
		CraftedItemWIP.BUILDER_PATH_RANGED_PHYSICAL:
			return "Ranged Physical Weapon authoring path. Bow and Quiver now have their own component tabs inside the shared forge shell while the dedicated ranged package, string-anchor, and quiver-shell systems are still being built."
		CraftedItemWIP.BUILDER_PATH_SHIELD:
			return "Shield authoring path. This currently shares the forge shell while the restricted-volume shield builder and fixed-handle foundation are being built."
		CraftedItemWIP.BUILDER_PATH_MAGIC:
			return "Magic Weapon authoring path. This currently shares the forge shell while the dedicated magical weapon builder and layout are being defined."
		_:
			return "Melee weapon authoring path. The right side manages processed material stacks, the center edits one shared WIP, and the top menus group project, status, view, build, and workflow actions."
