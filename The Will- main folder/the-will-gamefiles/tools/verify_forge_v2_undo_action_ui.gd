extends SceneTree

const CraftingBenchUIV2Scene = preload(
	"res://scenes/ui_v2/crafting_bench_ui_v2.tscn"
)
const ForgeV2KeybindingStateScript = preload(
	"res://runtime/forge_v2/forge_v2_keybinding_state.gd"
)
const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const ForgeV2AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/verify_forge_v2_undo_action_ui.txt"
)


class ActionControllerSpy:
	extends Node

	var undo_available := false
	var redo_available := false
	var undo_call_count := 0
	var redo_call_count := 0
	var undo_batch_begin_count := 0
	var undo_batch_end_count := 0

	func can_undo_action() -> bool:
		return undo_available

	func can_redo_action() -> bool:
		return redo_available

	func undo_latest_action() -> bool:
		undo_call_count += 1
		return undo_available

	func redo_latest_action() -> bool:
		redo_call_count += 1
		return redo_available

	func begin_action_history_undo_batch() -> bool:
		undo_batch_begin_count += 1
		return true

	func end_action_history_undo_batch() -> bool:
		undo_batch_end_count += 1
		return true


var result_lines: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var keybindings: Resource = ForgeV2KeybindingStateScript.new()
	var ctrl_z := _build_ctrl_key_event(KEY_Z)
	var ctrl_y := _build_ctrl_key_event(KEY_Y)
	if not _check(
		bool(keybindings.call(
			"event_matches_action",
			ForgeV2KeybindingStateScript.ACTION_UNDO,
			ctrl_z
		))
		and bool(keybindings.call(
			"event_matches_action",
			ForgeV2KeybindingStateScript.ACTION_REDO,
			ctrl_y
		))
		and not bool(keybindings.call(
			"event_matches_action",
			ForgeV2KeybindingStateScript.ACTION_UNDO,
			ctrl_y
		)),
		"Undo/Redo default keybindings are not Ctrl+Z/Ctrl+Y"
	):
		return
	result_lines.append("default_shortcuts=true")
	var ctrl_z_release := _build_ctrl_key_event(KEY_Z)
	ctrl_z_release.pressed = false
	var ctrl_modifier_release := InputEventKey.new()
	ctrl_modifier_release.pressed = false
	ctrl_modifier_release.physical_keycode = KEY_CTRL
	ctrl_modifier_release.keycode = KEY_CTRL
	if not _check(
		bool(keybindings.call(
			"event_releases_action",
			ForgeV2KeybindingStateScript.ACTION_UNDO,
			ctrl_z_release
		))
		and bool(keybindings.call(
			"event_releases_action",
			ForgeV2KeybindingStateScript.ACTION_UNDO,
			ctrl_modifier_release
		)),
		"Undo hold did not stop on primary-key or modifier-first release"
	):
		return
	result_lines.append("keyboard_primary_and_modifier_release_stop=true")

	keybindings.call(
		"set_binding_data",
		ForgeV2KeybindingStateScript.ACTION_UNDO,
		{
			"physical_keycode": KEY_U,
			"keycode": KEY_U,
			"ctrl": true,
		}
	)
	if not _check(
		bool(keybindings.call(
			"event_matches_action",
			ForgeV2KeybindingStateScript.ACTION_UNDO,
			_build_ctrl_key_event(KEY_U)
		))
		and not bool(keybindings.call(
			"event_matches_action",
			ForgeV2KeybindingStateScript.ACTION_UNDO,
			ctrl_z
		)),
		"Undo keybinding is not configurable"
	):
		return
	result_lines.append("shortcuts_configurable=true")

	keybindings.call(
		"set_binding_data",
		ForgeV2KeybindingStateScript.ACTION_UNDO,
		{"mouse_button": MOUSE_BUTTON_XBUTTON1}
	)
	keybindings.call(
		"set_binding_data",
		ForgeV2KeybindingStateScript.ACTION_REDO,
		{"mouse_button": MOUSE_BUTTON_XBUTTON2}
	)
	var mouse_4 := _build_mouse_button_event(MOUSE_BUTTON_XBUTTON1)
	var mouse_5 := _build_mouse_button_event(MOUSE_BUTTON_XBUTTON2)
	if not _check(
		bool(keybindings.call(
			"event_matches_action",
			ForgeV2KeybindingStateScript.ACTION_UNDO,
			mouse_4
		))
		and bool(keybindings.call(
			"event_matches_action",
			ForgeV2KeybindingStateScript.ACTION_REDO,
			mouse_5
		))
		and String(keybindings.call(
			"get_binding_label",
			ForgeV2KeybindingStateScript.ACTION_UNDO
		)) == "Mouse 4"
		and String(keybindings.call(
			"get_binding_label",
			ForgeV2KeybindingStateScript.ACTION_REDO
		)) == "Mouse 5",
		"Undo/Redo do not accept or label Mouse 4/Mouse 5 bindings"
	):
		return
	result_lines.append("mouse_4_mouse_5_supported=true")

	var ui_keybindings: Resource = ForgeV2KeybindingStateScript.new()
	ui_keybindings.set(
		"save_file_path",
		"C:/WORKSPACE/godot_runs/verify_undo_action_ui_keybindings.json"
	)
	var controller := ActionControllerSpy.new()
	get_root().add_child(controller)
	var ui := CraftingBenchUIV2Scene.instantiate() as CanvasLayer
	ui.set("keybinding_state", ui_keybindings)
	get_root().add_child(ui)
	await process_frame
	ui.set("active_stage_controller", controller)
	ui.visible = true
	var panel := ui.get("panel") as PanelContainer
	panel.visible = true
	ui.call("_ensure_keybindings_popup")
	ui.call("_rebuild_keybindings_list")
	var keybinding_buttons := ui.get("keybinding_buttons_by_action") as Dictionary
	if not _check(
		keybinding_buttons.has(ForgeV2KeybindingStateScript.ACTION_UNDO)
		and keybinding_buttons.has(ForgeV2KeybindingStateScript.ACTION_REDO),
		"Undo/Redo were not exposed in the keybinding menu"
	):
		return
	result_lines.append("keybinding_menu_entries=true")

	var undo_binding_button := keybinding_buttons.get(
		ForgeV2KeybindingStateScript.ACTION_UNDO
	) as Button
	ui.call(
		"_begin_keybinding_capture",
		ForgeV2KeybindingStateScript.ACTION_UNDO,
		undo_binding_button
	)
	ui.call("_handle_keybinding_capture_input", mouse_4)
	keybinding_buttons = ui.get("keybinding_buttons_by_action") as Dictionary
	var redo_binding_button := keybinding_buttons.get(
		ForgeV2KeybindingStateScript.ACTION_REDO
	) as Button
	ui.call(
		"_begin_keybinding_capture",
		ForgeV2KeybindingStateScript.ACTION_REDO,
		redo_binding_button
	)
	ui.call("_handle_keybinding_capture_input", mouse_5)
	if not _check(
		bool(ui_keybindings.call(
			"event_matches_action",
			ForgeV2KeybindingStateScript.ACTION_UNDO,
			mouse_4
		))
		and bool(ui_keybindings.call(
			"event_matches_action",
			ForgeV2KeybindingStateScript.ACTION_REDO,
			mouse_5
		)),
		"Keybinding-menu capture did not store Mouse 4/Mouse 5"
	):
		return
	result_lines.append("keybinding_menu_mouse_capture=true")
	var reloaded_keybindings := ForgeV2KeybindingStateScript.load_or_create(
		String(ui_keybindings.get("save_file_path"))
	)
	if not _check(
		reloaded_keybindings != null
		and bool(reloaded_keybindings.call(
			"event_matches_action",
			ForgeV2KeybindingStateScript.ACTION_UNDO,
			mouse_4
		))
		and bool(reloaded_keybindings.call(
			"event_matches_action",
			ForgeV2KeybindingStateScript.ACTION_REDO,
			mouse_5
		)),
		"Mouse 4/Mouse 5 bindings did not survive persistence reload"
	):
		return
	result_lines.append("mouse_bindings_persist=true")
	ui_keybindings.call("reset_all_to_defaults")
	ui.call("_rebuild_keybindings_list")

	controller.undo_available = true
	controller.redo_available = false
	ui.call("_rebuild_v2_layers_menu", {})
	var undo_menu := _find_layers_menu_action(ui, "Undo")
	var redo_menu := _find_layers_menu_action(ui, "Redo")
	if not _check(
		bool(undo_menu.get("found", false))
		and StringName(undo_menu.get("action", StringName())) == &"undo"
		and not bool(undo_menu.get("disabled", true))
		and bool(redo_menu.get("found", false))
		and StringName(redo_menu.get("action", StringName())) == &"redo"
		and bool(redo_menu.get("disabled", false))
		and not _layers_menu_has_label(ui, "Undo Layer")
		and not _layers_menu_has_label(ui, "Redo Layer"),
		"Layers menu did not expose semantic Undo/Redo availability"
	):
		return
	result_lines.append("semantic_menu_actions=true")

	var undo_button := ui.get("undo_button") as Button
	var redo_button := ui.get("redo_button") as Button
	if not _check(
		undo_button != null
		and redo_button != null
		and undo_button.text == "Undo"
		and redo_button.text == "Redo",
		"Undo/Redo buttons do not expose action labels"
	):
		return
	undo_button.pressed.emit()
	redo_button.pressed.emit()
	if not _check(
		controller.undo_call_count == 1
		and controller.redo_call_count == 1,
		"Undo/Redo buttons did not call the semantic controller API"
	):
		return
	result_lines.append("buttons_route_action_api=true")

	ui.call("_unhandled_input", ctrl_z)
	ui.call("_unhandled_input", ctrl_y)
	if not _check(
		controller.undo_call_count == 2
		and controller.redo_call_count == 2,
		"Undo/Redo keyboard shortcuts did not call the semantic controller API"
	):
		return
	result_lines.append("keyboard_routes_action_api=true")

	var focused_line_edit := LineEdit.new()
	focused_line_edit.name = "FocusedTextEntryProbe"
	ui.add_child(focused_line_edit)
	focused_line_edit.grab_focus()
	await process_frame
	var calls_before_text_input := (
		controller.undo_call_count + controller.redo_call_count
	)
	ui.call("_unhandled_input", ctrl_z)
	ui.call("_unhandled_input", ctrl_y)
	if not _check(
		controller.undo_call_count + controller.redo_call_count
		== calls_before_text_input,
		"Focused text entry did not retain Undo/Redo input ownership"
	):
		return
	result_lines.append("focused_text_input_safe=true")
	focused_line_edit.release_focus()
	await process_frame
	ui.call("_ensure_profile_builder_popup")
	var profile_builder_popup := ui.get("profile_builder_popup") as PopupPanel
	var popup_line_edit := LineEdit.new()
	popup_line_edit.name = "PopupFocusedTextEntryProbe"
	profile_builder_popup.add_child(popup_line_edit)
	profile_builder_popup.popup_centered(Vector2i(720, 520))
	await process_frame
	popup_line_edit.grab_focus()
	await process_frame
	if not _check(
		profile_builder_popup.gui_get_focus_owner() == popup_line_edit
		and not bool(ui.call("_try_handle_action_history_binding", mouse_4)),
		"Profile Builder text entry did not retain Undo/Redo input ownership"
	):
		return
	result_lines.append("popup_text_input_safe=true")
	profile_builder_popup.hide()
	popup_line_edit.queue_free()
	await process_frame

	var popup_menu_probe := PopupMenu.new()
	popup_menu_probe.name = "VisiblePopupMenuHistoryBlockerProbe"
	popup_menu_probe.add_item("Probe")
	ui.add_child(popup_menu_probe)
	popup_menu_probe.popup(Rect2i(10, 10, 120, 40))
	await process_frame
	if not _check(
		popup_menu_probe.visible
		and not bool(ui.call("_try_handle_action_history_binding", mouse_4)),
		"Visible PopupMenu did not block pre-GUI Undo/Redo input"
	):
		return
	result_lines.append("visible_popup_menu_safe=true")
	popup_menu_probe.hide()
	popup_menu_probe.queue_free()
	await process_frame

	ui_keybindings.call(
		"set_binding_data",
		ForgeV2KeybindingStateScript.ACTION_UNDO,
		{"mouse_button": MOUSE_BUTTON_XBUTTON1}
	)
	ui_keybindings.call(
		"set_binding_data",
		ForgeV2KeybindingStateScript.ACTION_REDO,
		{"mouse_button": MOUSE_BUTTON_XBUTTON2}
	)
	controller.undo_available = true
	controller.redo_available = true
	var undo_calls_before_mouse_input := controller.undo_call_count
	var redo_calls_before_mouse_input := controller.redo_call_count
	mouse_4.position = Vector2(20.0, 20.0)
	mouse_4.global_position = mouse_4.position
	mouse_5.position = Vector2(20.0, 20.0)
	mouse_5.global_position = mouse_5.position
	var mouse_4_release := _build_mouse_button_event(
		MOUSE_BUTTON_XBUTTON1,
		false
	)
	mouse_4_release.position = mouse_4.position
	mouse_4_release.global_position = mouse_4.global_position
	var mouse_5_release := _build_mouse_button_event(
		MOUSE_BUTTON_XBUTTON2,
		false
	)
	mouse_5_release.position = mouse_5.position
	mouse_5_release.global_position = mouse_5.global_position
	Input.parse_input_event(mouse_4)
	await process_frame
	Input.parse_input_event(mouse_4_release)
	await process_frame
	Input.parse_input_event(mouse_5)
	await process_frame
	Input.parse_input_event(mouse_5_release)
	await process_frame
	if not _check(
		controller.undo_call_count == undo_calls_before_mouse_input + 1
		and controller.redo_call_count == redo_calls_before_mouse_input + 1,
		"Mouse 4/Mouse 5 bindings did not execute through real GUI input"
	):
		return
	result_lines.append("mouse_bindings_execute_before_gui_stop=true")

	var undo_calls_before_hold := controller.undo_call_count
	var undo_batch_begins_before_hold := controller.undo_batch_begin_count
	var undo_batch_ends_before_hold := controller.undo_batch_end_count
	ui.call(
		"_begin_action_history_hold",
		ForgeV2KeybindingStateScript.ACTION_UNDO
	)
	ui.call("_advance_action_history_hold", 0.8, false)
	var undo_calls_during_hold := controller.undo_call_count
	ui.call("_try_handle_action_history_binding", mouse_4_release)
	ui.call("_advance_action_history_hold", 1.0, false)
	if not _check(
		undo_calls_during_hold > undo_calls_before_hold + 1
		and controller.undo_call_count == undo_calls_during_hold
		and controller.undo_batch_begin_count
		== undo_batch_begins_before_hold + 1
		and controller.undo_batch_end_count == undo_batch_ends_before_hold + 1,
		(
			"held Undo did not accelerate, batch, or stop immediately on release "
			+ "calls=%d/%d/%d begin=%d/%d end=%d/%d"
		) % [
			undo_calls_before_hold,
			undo_calls_during_hold,
			controller.undo_call_count,
			undo_batch_begins_before_hold,
			controller.undo_batch_begin_count,
			undo_batch_ends_before_hold,
			controller.undo_batch_end_count,
		]
	):
		return
	result_lines.append("held_undo_accelerates_and_stops_on_release=true")

	var calls_before_focus_loss_hold := controller.undo_call_count
	var ends_before_focus_loss_hold := controller.undo_batch_end_count
	ui.call(
		"_begin_action_history_hold",
		ForgeV2KeybindingStateScript.ACTION_UNDO
	)
	ui.call("_notification", NOTIFICATION_APPLICATION_FOCUS_OUT)
	ui.call("_advance_action_history_hold", 1.0, false)
	if not _check(
		controller.undo_call_count == calls_before_focus_loss_hold + 1
		and controller.undo_batch_end_count == ends_before_focus_loss_hold + 1
		and StringName(ui.get("action_history_hold_action")) == StringName(),
		"focus loss did not terminate held Undo before another repeat"
	):
		return
	result_lines.append("focus_loss_stops_held_undo=true")

	var active_hold_popup := PopupMenu.new()
	active_hold_popup.name = "ActiveHoldPopupBlockerProbe"
	active_hold_popup.add_item("Probe")
	ui.add_child(active_hold_popup)
	var calls_before_popup_hold := controller.undo_call_count
	var ends_before_popup_hold := controller.undo_batch_end_count
	ui.call(
		"_begin_action_history_hold",
		ForgeV2KeybindingStateScript.ACTION_UNDO
	)
	active_hold_popup.popup(Rect2i(10, 10, 120, 40))
	await process_frame
	ui.call("_advance_action_history_hold", 1.0, false)
	if not _check(
		controller.undo_call_count == calls_before_popup_hold + 1
		and controller.undo_batch_end_count == ends_before_popup_hold + 1
		and StringName(ui.get("action_history_hold_action")) == StringName(),
		"opening a popup did not terminate held Undo"
	):
		return
	result_lines.append("popup_stops_held_undo=true")
	active_hold_popup.hide()
	active_hold_popup.queue_free()
	await process_frame

	var real_controller := ForgeV2StageControllerScript.new()
	get_root().add_child(real_controller)
	real_controller.call("start_new_draft", "Mouse Binding Integration")
	real_controller.call(
		"set_active_tool_id",
		ForgeV2AuthoringStateScript.TOOL_SPLINE_LINE
	)
	real_controller.call(
		"append_spline_line_point",
		Vector3.ZERO,
		Vector3.UP
	)
	ui.set("active_stage_controller", real_controller)
	ui.call("_connect_stage_controller")
	Input.parse_input_event(mouse_4)
	await process_frame
	Input.parse_input_event(mouse_4_release)
	await process_frame
	var real_undo_summary := real_controller.call("get_status_summary") as Dictionary
	var redo_enabled_after_undo_release := not redo_button.disabled
	Input.parse_input_event(mouse_5)
	await process_frame
	var real_redo_summary := real_controller.call("get_status_summary") as Dictionary
	Input.parse_input_event(mouse_5_release)
	await process_frame
	if not _check(
		int(real_undo_summary.get("spline_line_point_count", -1)) == 0
		and not bool(real_undo_summary.get("can_undo_action", true))
		and bool(real_undo_summary.get("can_redo_action", false))
		and redo_enabled_after_undo_release
		and int(real_redo_summary.get("spline_line_point_count", -1)) == 1
		and bool(real_redo_summary.get("can_undo_action", false))
		and not bool(real_redo_summary.get("can_redo_action", true)),
		"Mouse bindings did not drive real controller Undo/Redo state"
	):
		return
	result_lines.append("mouse_bindings_drive_real_controller=true")

	ui.call("_open_profile_builder_popup")
	await process_frame
	ui.call("_begin_profile_builder_action_transaction", "Interrupted Profile Drag")
	real_controller.call("set_active_profile_rotation_degrees", 17.0)
	var profile_preview := ui.get("profile_builder_preview") as Control
	profile_preview.set("is_dragging_control_point", true)
	profile_preview.set("active_control_point_index", 0)
	ui.call("_close_profile_builder_popup")
	await process_frame
	var settled_summary := real_controller.call("get_status_summary") as Dictionary
	var settled_history := settled_summary.get("action_history", {}) as Dictionary
	if not _check(
		not bool(ui.get("profile_builder_action_transaction_active"))
		and not bool(profile_preview.call("has_active_drag_state"))
		and not bool(settled_history.get("blocked", true))
		and String(settled_history.get("undo_label", ""))
		== "Interrupted Profile Drag",
		"closing Profile Builder did not settle its owned edit transaction"
	):
		return
	result_lines.append("profile_builder_close_settles_transaction=true")

	ui.call("_open_profile_builder_popup")
	await process_frame
	ui.call("_begin_profile_builder_action_transaction", "Hidden Profile Drag")
	real_controller.call("set_active_profile_rotation_degrees", 23.0)
	var profile_popup := ui.get("profile_builder_popup") as PopupPanel
	profile_popup.hide()
	await process_frame
	settled_summary = real_controller.call("get_status_summary") as Dictionary
	settled_history = settled_summary.get("action_history", {}) as Dictionary
	if not _check(
		not bool(ui.get("profile_builder_action_transaction_active"))
		and not bool(settled_history.get("blocked", true))
		and String(settled_history.get("undo_label", "")) == "Hidden Profile Drag",
		"native Profile Builder hide stranded its edit transaction"
	):
		return
	result_lines.append("profile_builder_hide_settles_transaction=true")
	var close_hold_summary := real_controller.call(
		"get_status_summary"
	) as Dictionary
	var close_hold_undo_count := int(close_hold_summary.get(
		"action_undo_count",
		0
	))
	if close_hold_undo_count <= 0:
		real_controller.call(
			"append_spline_line_point",
			Vector3(0.1, 0.0, 0.0),
			Vector3.UP
		)
	ui.call(
		"_begin_action_history_hold",
		ForgeV2KeybindingStateScript.ACTION_UNDO
	)
	ui.call("close_ui")
	ui.call("_advance_action_history_hold", 1.0, false)
	var closed_history_summary := real_controller.call(
		"get_action_history_summary"
	) as Dictionary
	if not _check(
		StringName(ui.get("action_history_hold_action")) == StringName()
		and not bool(closed_history_summary.get("undo_batch_active", true)),
		"closing Forge did not terminate and seal held Undo"
	):
		return
	result_lines.append("forge_close_stops_held_undo=true")
	real_controller.queue_free()

	_finish(true)


func _build_ctrl_key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.ctrl_pressed = true
	event.physical_keycode = keycode
	event.keycode = keycode
	return event


func _build_mouse_button_event(
	button_index: MouseButton,
	pressed: bool = true
) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.pressed = pressed
	event.button_index = button_index
	return event


func _find_layers_menu_action(ui: CanvasLayer, label: String) -> Dictionary:
	var layers_button := ui.get("layers_menu_button") as MenuButton
	if layers_button == null:
		return {}
	var popup := layers_button.get_popup()
	var action_lookup := ui.get("menu_action_lookup") as Dictionary
	for item_index in range(popup.get_item_count()):
		if popup.get_item_text(item_index) != label:
			continue
		var menu_id := popup.get_item_id(item_index)
		var entry := action_lookup.get(menu_id, {}) as Dictionary
		return {
			"found": true,
			"action": entry.get("action", StringName()),
			"disabled": popup.is_item_disabled(item_index),
		}
	return {}


func _layers_menu_has_label(ui: CanvasLayer, label: String) -> bool:
	var layers_button := ui.get("layers_menu_button") as MenuButton
	if layers_button == null:
		return false
	var popup := layers_button.get_popup()
	for item_index in range(popup.get_item_count()):
		if popup.get_item_text(item_index) == label:
			return true
	return false


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
	var result_file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if result_file != null:
		result_file.store_string("\n".join(output_lines) + "\n")
	if passed:
		print("FORGE_V2_UNDO_ACTION_UI_VERIFY: PASS")
		quit()
		return
	push_error("FORGE_V2_UNDO_ACTION_UI_VERIFY: FAIL: %s" % message)
	quit(1)
