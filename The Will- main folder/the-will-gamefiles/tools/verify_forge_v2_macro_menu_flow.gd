extends SceneTree

const CraftingBenchUIV2Scene = preload(
	"res://scenes/ui_v2/crafting_bench_ui_v2.tscn"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const ForgeV2KeybindingStateScript = preload(
	"res://runtime/forge_v2/forge_v2_keybinding_state.gd"
)
const PlayerToolProfileLibraryStateScript = preload(
	"res://core/models/player_tool_profile_library_state.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_macro_menu_flow_2026-08-10.txt"
)
const PROFILE_ID := &"verify_macro_menu_basic_profile"

var result_lines: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())

	var controller: Node = ForgeV2StageControllerScript.new()
	get_root().add_child(controller)
	await process_frame

	var ui: CanvasLayer = CraftingBenchUIV2Scene.instantiate() as CanvasLayer
	var isolated_ready_library: Resource = (
		PlayerToolProfileLibraryStateScript.new()
	)
	isolated_ready_library.set(
		"save_file_path",
		"C:/WORKSPACE/godot_runs/verify_macro_menu_ready_library.tres"
	)
	ui.set("tool_profile_library_state", isolated_ready_library)
	var isolated_keybindings: Resource = ForgeV2KeybindingStateScript.new()
	isolated_keybindings.set(
		"save_file_path",
		"C:/WORKSPACE/godot_runs/verify_macro_menu_keybindings.json"
	)
	ui.set("keybinding_state", isolated_keybindings)
	get_root().add_child(ui)
	await process_frame
	ui.call("open_for", null, controller, "Macro Menu Verify", null)
	await process_frame

	var draft_button := ui.get("draft_menu_button") as MenuButton
	var shape_button := ui.get("shape_menu_button") as MenuButton
	var view_button := ui.get("view_menu_button") as MenuButton
	var profiles_button := ui.get("profiles_button") as Button
	var settings_button := ui.get("settings_button") as Button
	var workspace := ui.get("workspace_view_container") as Control
	if not _check(
		is_instance_valid(draft_button)
		and is_instance_valid(shape_button)
		and is_instance_valid(view_button)
		and is_instance_valid(profiles_button)
		and is_instance_valid(settings_button)
		and is_instance_valid(workspace),
		"Forge V2 macro menu controls were not constructed"
	):
		return

	ui.call("_rebuild_v2_action_menus")
	var draft_popup := draft_button.get_popup()
	var draft_submenu := draft_popup.get_node_or_null(
		"SavedV2DraftSubmenu"
	) as PopupMenu
	if not _check(
		is_instance_valid(draft_submenu),
		"Draft submenu tree was not built"
	):
		return
	draft_button.show_popup()
	draft_submenu.popup(Rect2i(120, 120, 180, 90))
	await process_frame
	shape_button.show_popup()
	await process_frame
	if not _check(
		shape_button.get_popup().visible
		and not draft_popup.visible
		and not draft_submenu.visible,
		"opening Shape did not replace the complete Draft popup tree"
	):
		return
	result_lines.append("different_top_menu_replaces_tree=true")

	var shape_popup := shape_button.get_popup()
	var shape_profiles_submenu := shape_popup.get_node_or_null(
		"Tool2DProfilesSubmenu"
	) as PopupMenu
	var shape_saved_submenu := (
		shape_profiles_submenu.get_node_or_null("Tool2DSavedProfilesSubmenu")
		as PopupMenu
		if is_instance_valid(shape_profiles_submenu)
		else null
	)
	if not _check(
		is_instance_valid(shape_profiles_submenu)
		and is_instance_valid(shape_saved_submenu),
		"Shape -> 2D Profiles -> Saved Profiles tree was not built"
	):
		return
	shape_profiles_submenu.popup(Rect2i(160, 140, 200, 100))
	shape_saved_submenu.popup(Rect2i(220, 160, 220, 100))
	await process_frame
	shape_saved_submenu.window_input.emit(
		_build_left_click(profiles_button.get_global_rect().get_center())
	)
	await process_frame
	await process_frame
	var profile_workspace := ui.get("profile_builder_popup") as PopupPanel
	if not _check(
		is_instance_valid(profile_workspace)
		and profile_workspace.visible
		and not profile_workspace.popup_window
		and not profile_workspace.popup_wm_hint
		and not shape_popup.visible
		and not shape_profiles_submenu.visible
		and not shape_saved_submenu.visible,
		"Profiles did not replace the Shape tree or retain major-workspace lifetime"
	):
		return
	result_lines.append("profiles_top_level_replaces_tree=true")
	result_lines.append("major_workspace_background_persistent=true")
	shape_button.show_popup()
	await process_frame
	if not _check(
		shape_button.get_popup().visible
		and not profile_workspace.visible,
		"Shape did not replace the open Profiles major workspace"
	):
		return
	result_lines.append("menu_replaces_profiles_workspace=true")
	shape_button.get_popup().hide()
	await process_frame

	view_button.show_popup()
	await process_frame
	view_button.get_popup().window_input.emit(
		_build_left_click(settings_button.get_global_rect().get_center())
	)
	await process_frame
	await process_frame
	var settings_workspace := ui.get("settings_popup") as PopupPanel
	if not _check(
		is_instance_valid(settings_workspace)
		and settings_workspace.visible
		and not settings_workspace.popup_window
		and not settings_workspace.popup_wm_hint
		and not view_button.get_popup().visible,
		"Settings did not replace the View tree or retain major-workspace lifetime"
	):
		return
	result_lines.append("settings_top_level_replaces_tree=true")
	ui.call("_on_profiles_top_level_pressed")
	await process_frame
	if not _check(
		profile_workspace.visible
		and not settings_workspace.visible,
		"Profiles did not replace the open Settings major workspace"
	):
		return
	result_lines.append("profiles_replaces_settings_workspace=true")
	ui.call("_on_settings_top_level_pressed")
	await process_frame
	if not _check(
		settings_workspace.visible
		and not profile_workspace.visible,
		"Settings did not replace the open Profiles major workspace"
	):
		return
	result_lines.append("settings_replaces_profiles_workspace=true")
	ui.call("_close_settings_popup")
	await process_frame
	var tool_context_refresh_ok: bool = await _verify_tool_context_refresh(
		ui,
		controller,
		shape_button
	)
	if not tool_context_refresh_ok:
		return

	var profile_library: Resource = PlayerToolProfileLibraryStateScript.new()
	profile_library.set(
		"save_file_path",
		"C:/WORKSPACE/godot_runs/verify_macro_menu_profile_library.tres"
	)
	var profile := _build_saved_basic_profile()
	if not _check(
		ForgeV2ProfileShapeLibraryScript.is_compiled_basic_profile_runtime_valid(
			profile
		),
		"saved Basic verifier profile did not compile"
	):
		return
	var saved_profiles: Array[Dictionary] = [profile]
	profile_library.set("saved_profiles", saved_profiles)
	ui.set("tool_profile_library_state", profile_library)
	if not _check(
		StringName((profile_library.call(
			"get_saved_profile",
			PROFILE_ID
		) as Dictionary).get("profile_id", StringName())) == PROFILE_ID,
		"in-memory saved Basic profile was not available to the UI"
	):
		return
	controller.call("set_active_tool_id", &"tool_volume_stroke")
	ui.call("_rebuild_v2_action_menus")

	shape_popup = shape_button.get_popup()
	shape_profiles_submenu = shape_popup.get_node_or_null(
		"Tool2DProfilesSubmenu"
	) as PopupMenu
	shape_saved_submenu = shape_profiles_submenu.get_node_or_null(
		"Tool2DSavedProfilesSubmenu"
	) as PopupMenu
	shape_button.show_popup()
	shape_profiles_submenu.popup(Rect2i(160, 140, 200, 100))
	shape_saved_submenu.popup(Rect2i(220, 160, 220, 100))
	await process_frame
	var menu_id := int(ui.call(
		"_register_v2_menu_action",
		&"basic_saved_profile",
		PROFILE_ID
	))
	result_lines.append("registered_menu_id=%d" % menu_id)
	result_lines.append("registered_menu_entry=%s" % str(
		(ui.get("menu_action_lookup") as Dictionary).get(menu_id, {})
	))
	ui.call("_on_v2_menu_id_pressed", menu_id)
	await process_frame
	await process_frame
	var summary: Dictionary = controller.call("get_status_summary") as Dictionary
	result_lines.append("selected_profile_id=%s" % String(summary.get(
		"active_saved_basic_profile_id",
		StringName()
	)))
	result_lines.append("shape_popup_visible=%s" % str(shape_popup.visible))
	result_lines.append(
		"shape_profiles_submenu_visible=%s" % str(shape_profiles_submenu.visible)
	)
	result_lines.append(
		"shape_saved_submenu_visible=%s" % str(shape_saved_submenu.visible)
	)
	var root_window := ui.get_window()
	result_lines.append("root_window_has_focus=%s" % str(
		is_instance_valid(root_window) and root_window.has_focus()
	))
	if not _check(
		StringName(summary.get(
			"active_saved_basic_profile_id",
			StringName()
		)) == PROFILE_ID
		and not shape_popup.visible
		and not shape_profiles_submenu.visible
		and not shape_saved_submenu.visible
		and is_instance_valid(root_window)
		and root_window.has_focus(),
		"saved Basic Shape selection did not close its tree and restore workspace input"
	):
		return
	result_lines.append("saved_basic_selection_closes_shape_tree=true")
	result_lines.append("workspace_input_restored=true")
	_finish(true)


func _verify_tool_context_refresh(
	ui: CanvasLayer,
	controller: Node,
	shape_button: MenuButton
) -> bool:
	var cases: Array[Dictionary] = [
		{
			"tool_id": &"tool_handles",
			"header": "Tool: Handles",
			"required": "Generate Handle",
			"forbidden": "Generate Detailing Brush",
		},
		{
			"tool_id": &"tool_spline_line",
			"header": "Tool: Spline Line",
			"required": "Generate CSG Noodle",
			"forbidden": "Generate Handle",
		},
		{
			"tool_id": &"tool_detailing_brush",
			"header": "Tool: Detailing Brush",
			"required": "Generate Detailing Brush",
			"forbidden": "Generate CSG Noodle",
		},
		{
			"tool_id": &"tool_volume_stroke",
			"header": "Tool: CSG Material Stroke",
			"required": "2D Profiles",
			"forbidden": "Generate Handle",
		},
	]
	var shape_popup := shape_button.get_popup()
	shape_button.show_popup()
	await process_frame
	for case_data: Dictionary in cases:
		var tool_id := StringName(case_data.get("tool_id", StringName()))
		var menu_id := int(ui.call(
			"_register_v2_menu_action",
			&"tool",
			tool_id
		))
		ui.call("_on_v2_menu_id_pressed", menu_id)
		await process_frame
		await process_frame
		var summary := controller.call("get_status_summary") as Dictionary
		if not _check(
			StringName(summary.get("active_tool", StringName())) == tool_id,
			"tool selection did not reach the authoring state: %s"
			% String(tool_id)
		):
			return false
		if not _check(
			shape_popup.visible
			and _popup_has_item_label(
				shape_popup,
				String(case_data.get("header", ""))
			)
			and _popup_has_item_label(
				shape_popup,
				String(case_data.get("required", ""))
			)
			and not _popup_has_item_label(
				shape_popup,
				String(case_data.get("forbidden", ""))
			),
			"open Shape menu retained stale context after selecting %s"
			% String(tool_id)
		):
			return false
	result_lines.append("open_shape_menu_tracks_selected_tool=true")
	shape_popup.hide()
	await process_frame
	return true


func _popup_has_item_label(popup: PopupMenu, label: String) -> bool:
	if not is_instance_valid(popup):
		return false
	for item_index in range(popup.get_item_count()):
		if popup.get_item_text(item_index) == label:
			return true
	return false


func _build_saved_basic_profile() -> Dictionary:
	var polygon := PackedVector2Array([
		Vector2(-0.02, -0.015),
		Vector2(0.025, -0.015),
		Vector2(0.02, 0.02),
		Vector2(-0.015, 0.025),
	])
	return ForgeV2ProfileShapeLibraryScript.compile_basic_profile_runtime_data({
		"profile_id": PROFILE_ID,
		"id": PROFILE_ID,
		"label": "Macro Menu Basic Profile",
		"family": ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC,
		"base_polygon_2d_meters": polygon,
		"polygon_2d_meters": polygon,
		"base_anchor_2d_meters": Vector2.ZERO,
		"anchor_x_meters": 0.0,
		"anchor_y_meters": 0.0,
		"rotation_degrees": 0.0,
	})


func _build_left_click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	# Popup Window input can report a popup-local `position`; top-level controls
	# live in root-viewport coordinates, so routing must use `global_position`.
	event.position = Vector2(2.0, 2.0)
	event.global_position = position
	return event


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_finish(false, message)
	return false


func _finish(passed: bool, message: String = "") -> void:
	var output_lines := PackedStringArray([
		"ok=true" if passed else "ok=false",
	])
	output_lines.append_array(result_lines)
	if not passed:
		output_lines.append("failure=%s" % message)
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var result_file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if result_file != null:
		result_file.store_string("\n".join(output_lines) + "\n")
	if passed:
		print("FORGE_V2_MACRO_MENU_FLOW_VERIFY: PASS")
		quit()
		return
	push_error("FORGE_V2_MACRO_MENU_FLOW_VERIFY: FAIL: %s" % message)
	quit(1)
