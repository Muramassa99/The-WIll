extends SceneTree

const UserSettingsStateScript = preload("res://core/models/user_settings_state.gd")
const UserSettingsRuntimeScript = preload("res://runtime/system/user_settings_runtime.gd")
const SystemMenuScene = preload("res://scenes/ui/system_menu_overlay.tscn")

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)
	await process_frame

	var save_path: String = "res://tools/test_system_menu_state.tres"
	var settings_state: UserSettingsState = UserSettingsStateScript.load_or_create(save_path)
	settings_state.reset_all_to_defaults(true)
	settings_state.window_mode = UserSettingsStateScript.FULLSCREEN
	settings_state.resolution = Vector2i(1920, 1080)
	settings_state.vsync_enabled = false
	settings_state.max_fps = 60
	settings_state.render_scale_preset = UserSettingsStateScript.SCALE_SMALL
	settings_state.master_volume_linear = 0.42
	settings_state.master_muted = true
	settings_state.ui_scale_preset = UserSettingsStateScript.SCALE_LARGE
	settings_state.text_scale_preset = UserSettingsStateScript.SCALE_SMALL

	var rebound_event: InputEventKey = InputEventKey.new()
	rebound_event.physical_keycode = KEY_F9
	rebound_event.keycode = KEY_F9
	settings_state.set_keybinding_event(&"menu_toggle", rebound_event)

	var persisted_ok: bool = settings_state.persist()
	var reloaded_state: UserSettingsState = UserSettingsStateScript.load_or_create(save_path)
	UserSettingsRuntimeScript.ensure_input_actions(reloaded_state)
	UserSettingsRuntimeScript.apply_settings(reloaded_state, get_root())

	var menu_overlay: SystemMenuOverlay = SystemMenuScene.instantiate() as SystemMenuOverlay
	get_root().add_child(menu_overlay)
	await process_frame
	menu_overlay.configure(null, reloaded_state)
	menu_overlay.open_page(&"settings")
	await process_frame
	await process_frame
	var panel_control: Control = menu_overlay.get_node("Panel") as Control
	var page_scroll: ScrollContainer = menu_overlay.get_node("Panel/MarginContainer/RootVBox/MainHBox/ContentPanel/MarginContainer/ContentVBox/PageScroll") as ScrollContainer
	var panel_rect_1280x720: Rect2 = panel_control.get_global_rect()
	var viewport_rect_1280x720: Rect2 = get_root().get_visible_rect()
	var layout_inside_1280x720: bool = viewport_rect_1280x720.encloses(panel_rect_1280x720)
	var page_scroll_size_1280x720: Vector2 = page_scroll.size
	menu_overlay.reset_active_page_to_defaults()
	menu_overlay.open_page(&"interface")
	menu_overlay.reset_active_page_to_defaults()
	UserSettingsRuntimeScript.apply_settings(reloaded_state, get_root())
	get_root().size = Vector2i(1024, 576)
	menu_overlay.open_page(&"controls")
	await process_frame
	await process_frame
	var panel_rect_1024x576: Rect2 = panel_control.get_global_rect()
	var viewport_rect_1024x576: Rect2 = get_root().get_visible_rect()
	var layout_inside_1024x576: bool = viewport_rect_1024x576.encloses(panel_rect_1024x576)
	var page_scroll_size_1024x576: Vector2 = page_scroll.size

	var lines: PackedStringArray = []
	lines.append("persisted_ok=%s" % str(persisted_ok))
	lines.append("menu_overlay_loaded=%s" % str(menu_overlay != null))
	lines.append("current_page=%s" % String(menu_overlay.get_current_page_id()))
	lines.append("layout_inside_1280x720=%s" % str(layout_inside_1280x720))
	lines.append("panel_rect_1280x720=%s" % str(panel_rect_1280x720))
	lines.append("viewport_rect_1280x720=%s" % str(viewport_rect_1280x720))
	lines.append("page_scroll_size_1280x720=%s" % str(page_scroll_size_1280x720))
	lines.append("layout_inside_1024x576=%s" % str(layout_inside_1024x576))
	lines.append("panel_rect_1024x576=%s" % str(panel_rect_1024x576))
	lines.append("viewport_rect_1024x576=%s" % str(viewport_rect_1024x576))
	lines.append("page_scroll_size_1024x576=%s" % str(page_scroll_size_1024x576))
	lines.append("window_mode_after_reset=%s" % String(reloaded_state.window_mode))
	lines.append("resolution_after_reset=%s" % str(reloaded_state.resolution))
	lines.append("vsync_after_reset=%s" % str(reloaded_state.vsync_enabled))
	lines.append("master_volume_after_reset=%s" % str(reloaded_state.master_volume_linear))
	lines.append("master_muted_after_reset=%s" % str(reloaded_state.master_muted))
	lines.append("ui_scale_after_reset=%s" % String(reloaded_state.ui_scale_preset))
	lines.append("text_scale_after_reset=%s" % String(reloaded_state.text_scale_preset))
	lines.append("menu_toggle_label=%s" % UserSettingsRuntimeScript.get_keybinding_label(reloaded_state.get_keybinding_data(&"menu_toggle")))
	lines.append("menu_toggle_event_count=%d" % InputMap.action_get_events(&"menu_toggle").size())

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/system_menu_verify_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	quit()
