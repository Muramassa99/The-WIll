extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	get_root().add_child(forge_controller)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_for(null, forge_controller, "Verifier Bench")
	await process_frame
	await process_frame

	var panel_control: Control = crafting_ui.get_node("Panel") as Control
	var main_hbox: HBoxContainer = crafting_ui.get_node("Panel/MarginContainer/RootVBox/MainHBox") as HBoxContainer
	var left_panel: Control = crafting_ui.get_node("Panel/MarginContainer/RootVBox/MainHBox/LeftPanel") as Control
	var center_panel: Control = crafting_ui.get_node("Panel/MarginContainer/RootVBox/MainHBox/CenterPanel") as Control
	var right_panel: Control = crafting_ui.get_node("Panel/MarginContainer/RootVBox/MainHBox/RightPanel") as Control
	var viewport_split: HBoxContainer = crafting_ui.get_node("Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/ViewportSplit") as HBoxContainer
	var plane_view_panel: Control = crafting_ui.get_node("Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/ViewportSplit/PlaneViewPanel") as Control
	var free_view_panel: Control = crafting_ui.get_node("Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/ViewportSplit/FreeViewPanel") as Control
	var free_view_container: SubViewportContainer = crafting_ui.get_node("Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/ViewportSplit/FreeViewPanel/FreeVBox/FreeViewContainer") as SubViewportContainer
	var free_subviewport: SubViewport = crafting_ui.get_node("Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/ViewportSplit/FreeViewPanel/FreeVBox/FreeViewContainer/FreeSubViewport") as SubViewport

	var panel_rect_1280x720: Rect2 = panel_control.get_global_rect()
	var viewport_rect_1280x720: Rect2 = get_root().get_visible_rect()
	var layout_inside_1280x720: bool = viewport_rect_1280x720.encloses(panel_rect_1280x720)
	var split_vertical_1280x720: bool = false
	var free_view_container_size_1280x720: Vector2 = free_view_container.size
	var free_subviewport_size_1280x720: Vector2i = free_subviewport.size

	get_root().size = Vector2i(1024, 576)
	await process_frame
	await process_frame

	var panel_rect_1024x576: Rect2 = panel_control.get_global_rect()
	var viewport_rect_1024x576: Rect2 = get_root().get_visible_rect()
	var layout_inside_1024x576: bool = viewport_rect_1024x576.encloses(panel_rect_1024x576)
	var split_vertical_1024x576: bool = false
	var free_view_container_size_1024x576: Vector2 = free_view_container.size
	var free_subviewport_size_1024x576: Vector2i = free_subviewport.size

	var lines: PackedStringArray = []
	lines.append("crafting_ui_loaded=%s" % str(crafting_ui != null))
	lines.append("last_layout_viewport_size_1280x720=%s" % str(crafting_ui.last_layout_viewport_size))
	lines.append("last_layout_compact_mode_1280x720=%s" % str(crafting_ui.last_layout_compact_mode))
	lines.append("layout_inside_1280x720=%s" % str(layout_inside_1280x720))
	lines.append("panel_rect_1280x720=%s" % str(panel_rect_1280x720))
	lines.append("viewport_rect_1280x720=%s" % str(viewport_rect_1280x720))
	lines.append("split_vertical_1280x720=%s" % str(split_vertical_1280x720))
	lines.append("free_view_container_size_1280x720=%s" % str(free_view_container_size_1280x720))
	lines.append("free_subviewport_size_1280x720=%s" % str(free_subviewport_size_1280x720))
	lines.append("layout_inside_1024x576=%s" % str(layout_inside_1024x576))
	lines.append("last_layout_viewport_size_1024x576=%s" % str(crafting_ui.last_layout_viewport_size))
	lines.append("last_layout_compact_mode_1024x576=%s" % str(crafting_ui.last_layout_compact_mode))
	lines.append("panel_rect_1024x576=%s" % str(panel_rect_1024x576))
	lines.append("viewport_rect_1024x576=%s" % str(viewport_rect_1024x576))
	lines.append("split_vertical_1024x576=%s" % str(split_vertical_1024x576))
	lines.append("panel_combined_min_size=%s" % str(panel_control.get_combined_minimum_size()))
	lines.append("main_hbox_combined_min_size=%s" % str(main_hbox.get_combined_minimum_size()))
	lines.append("left_panel_combined_min_size=%s" % str(left_panel.get_combined_minimum_size()))
	lines.append("center_panel_combined_min_size=%s" % str(center_panel.get_combined_minimum_size()))
	lines.append("right_panel_combined_min_size=%s" % str(right_panel.get_combined_minimum_size()))
	lines.append("viewport_split_combined_min_size=%s" % str(viewport_split.get_combined_minimum_size()))
	lines.append("plane_view_panel_combined_min_size=%s" % str(plane_view_panel.get_combined_minimum_size()))
	lines.append("free_view_panel_combined_min_size=%s" % str(free_view_panel.get_combined_minimum_size()))
	lines.append("free_view_container_size_1024x576=%s" % str(free_view_container_size_1024x576))
	lines.append("free_subviewport_size_1024x576=%s" % str(free_subviewport_size_1024x576))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/crafting_bench_layout_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
