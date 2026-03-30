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
	var workspace_stage: Control = crafting_ui.get_node("Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage") as Control
	var main_viewport_host: Control = crafting_ui.get_node("Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/MainViewportHost") as Control
	var inset_viewport_host: Control = crafting_ui.get_node("Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/InsetViewportHost") as Control
	var plane_view_panel: Control = crafting_ui.plane_view_panel
	var free_view_panel: Control = crafting_ui.free_view_panel
	var free_view_container: SubViewportContainer = crafting_ui.free_view_container
	var plane_viewport: Control = crafting_ui.plane_viewport
	var flip_view_button: Button = crafting_ui.flip_view_button
	var debug_info_button: Button = crafting_ui.debug_info_button
	var debug_popup: PopupPanel = crafting_ui.debug_popup
	var debug_text: RichTextLabel = crafting_ui.status_text

	var panel_rect_1280x720: Rect2 = panel_control.get_global_rect()
	var viewport_rect_1280x720: Rect2 = get_root().get_visible_rect()
	var workspace_rect_1280x720: Rect2 = workspace_stage.get_global_rect()
	var inset_rect_1280x720: Rect2 = inset_viewport_host.get_global_rect()
	var layout_inside_1280x720: bool = viewport_rect_1280x720.encloses(panel_rect_1280x720)
	var inset_inside_workspace_1280x720: bool = workspace_rect_1280x720.encloses(inset_rect_1280x720)
	var default_main_workspace_mode: String = String(crafting_ui.main_workspace_mode)
	var free_is_primary_1280x720: bool = free_view_panel.get_parent() == main_viewport_host
	var plane_is_inset_1280x720: bool = plane_view_panel.get_parent() == inset_viewport_host
	var free_view_container_size_1280x720: Vector2 = free_view_container.size
	var plane_viewport_size_1280x720: Vector2 = plane_viewport.size
	var plane_zoom_before: float = plane_viewport.plane_zoom_scale
	var wheel_event: InputEventMouseButton = InputEventMouseButton.new()
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_event.pressed = true
	wheel_event.position = plane_viewport.size * 0.5
	plane_viewport._gui_input(wheel_event)
	await process_frame
	var plane_zoom_increased: bool = plane_viewport.plane_zoom_scale > plane_zoom_before

	get_root().size = Vector2i(1024, 576)
	await process_frame
	await process_frame

	var panel_rect_1024x576: Rect2 = panel_control.get_global_rect()
	var viewport_rect_1024x576: Rect2 = get_root().get_visible_rect()
	var workspace_rect_1024x576: Rect2 = workspace_stage.get_global_rect()
	var inset_rect_1024x576: Rect2 = inset_viewport_host.get_global_rect()
	var layout_inside_1024x576: bool = viewport_rect_1024x576.encloses(panel_rect_1024x576)
	var inset_inside_workspace_1024x576: bool = workspace_rect_1024x576.encloses(inset_rect_1024x576)
	var free_view_container_size_1024x576: Vector2 = free_view_container.size
	var plane_viewport_size_1024x576: Vector2 = plane_viewport.size

	flip_view_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var plane_is_primary_after_flip: bool = plane_view_panel.get_parent() == main_viewport_host
	var free_is_inset_after_flip: bool = free_view_panel.get_parent() == inset_viewport_host

	debug_info_button.emit_signal("pressed")
	await process_frame
	await process_frame

	var debug_popup_visible: bool = debug_popup.visible
	var debug_text_has_content: bool = not debug_text.text.strip_edges().is_empty()

	var lines: PackedStringArray = []
	lines.append("crafting_ui_loaded=%s" % str(crafting_ui != null))
	lines.append("layout_inside_1280x720=%s" % str(layout_inside_1280x720))
	lines.append("inset_inside_workspace_1280x720=%s" % str(inset_inside_workspace_1280x720))
	lines.append("panel_rect_1280x720=%s" % str(panel_rect_1280x720))
	lines.append("workspace_rect_1280x720=%s" % str(workspace_rect_1280x720))
	lines.append("inset_rect_1280x720=%s" % str(inset_rect_1280x720))
	lines.append("default_main_workspace_mode=%s" % default_main_workspace_mode)
	lines.append("free_is_primary_1280x720=%s" % str(free_is_primary_1280x720))
	lines.append("plane_is_inset_1280x720=%s" % str(plane_is_inset_1280x720))
	lines.append("free_view_container_size_1280x720=%s" % str(free_view_container_size_1280x720))
	lines.append("plane_viewport_size_1280x720=%s" % str(plane_viewport_size_1280x720))
	lines.append("plane_zoom_increased=%s" % str(plane_zoom_increased))
	lines.append("layout_inside_1024x576=%s" % str(layout_inside_1024x576))
	lines.append("inset_inside_workspace_1024x576=%s" % str(inset_inside_workspace_1024x576))
	lines.append("panel_rect_1024x576=%s" % str(panel_rect_1024x576))
	lines.append("workspace_rect_1024x576=%s" % str(workspace_rect_1024x576))
	lines.append("inset_rect_1024x576=%s" % str(inset_rect_1024x576))
	lines.append("free_view_container_size_1024x576=%s" % str(free_view_container_size_1024x576))
	lines.append("plane_viewport_size_1024x576=%s" % str(plane_viewport_size_1024x576))
	lines.append("main_workspace_mode_after_flip=%s" % String(crafting_ui.main_workspace_mode))
	lines.append("plane_is_primary_after_flip=%s" % str(plane_is_primary_after_flip))
	lines.append("free_is_inset_after_flip=%s" % str(free_is_inset_after_flip))
	lines.append("debug_popup_visible=%s" % str(debug_popup_visible))
	lines.append("debug_text_has_content=%s" % str(debug_text_has_content))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/crafting_bench_layout_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
