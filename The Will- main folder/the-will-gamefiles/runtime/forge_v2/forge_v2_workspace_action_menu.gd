extends Node

## Pointer-local command surfaces over the existing Forge authoring commands.
const Bindings = preload("res://runtime/forge_v2/forge_v2_keybinding_state.gd")
const Radial = preload("res://runtime/forge_v2/forge_v2_radial_menu.gd")
const WindowPolicy = preload("res://runtime/ui/ui_window_layer_policy.gd")
const Stroke = preload("res://runtime/forge_v2/forge_v2_volume_stroke.gd")
const TOOL_ENTRIES: Array[Dictionary] = [
	{"id": &"tool_volume_stroke", "label": "CSG Stroke", "icon": &"tool_stroke"},
	{"id": &"tool_detailing_brush", "label": "Detailing", "icon": &"tool_detail"},
	{"id": &"tool_handles", "label": "Handles", "icon": &"tool_handle"},
	{"id": &"tool_spline_line", "label": "Spline", "icon": &"tool_spline"},
]

var ui: Node = null
var radial: Control = null
var radial_active := false
var radial_binding: Dictionary = {}
var context_popup: PopupPanel = null
var context_tool := StringName()
var pending_tool := StringName()
var pending_action := Callable()
var waiting_for_tool := false
var waiting_for_retained_apply := false
var waiting_for_material_commit := false
var context_generation_completed := false


func configure(owner_ui: Node) -> void:
	ui = owner_ui
	set_process(false)


func _process(_delta: float) -> void:
	var controller := _controller()
	if waiting_for_retained_apply and is_popup_open() and controller != null:
		if bool(controller.call("is_retained_spline_change_pending")):
			return
		waiting_for_retained_apply = false
		if bool(controller.call("is_retained_spline_change_active")):
			# A failed candidate keeps both the original solid and the editable draft.
			var result: Dictionary = controller.get("last_retained_spline_change_result") as Dictionary
			ui.call("_set_v2_action_status_text", "Could not apply the edit (%s); the original shape and your edits are retained." % String(result.get("reason", "replacement failed")))
			_refresh_context_buttons()
			set_process(false)
			return
		_finish_context_action()
		return
	if waiting_for_tool and is_popup_open() and controller != null and bool(controller.call("can_select_tool_for_authoring")):
		_finish_context_action()


func is_popup_open() -> bool:
	return is_instance_valid(context_popup) and context_popup.visible


func blocks_workspace_input() -> bool:
	return radial_active or is_popup_open() or waiting_for_material_commit


func dismiss() -> void:
	_cancel_radial()
	_hide_context_popup()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		dismiss()


func handle_input(event: InputEvent) -> bool:
	if ui == null or not bool(ui.call("is_open")):
		return false
	if radial_active:
		if event is InputEventMouseMotion:
			var host: Control = ui.get("workspace_frame_host") as Control
			radial.call("update_pointer", host.get_global_transform_with_canvas().affine_inverse() * event.position)
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_cancel_radial()
		elif Bindings.event_releases_binding(radial_binding, event):
			var selection := StringName(radial.call("get_selected_id"))
			_cancel_radial()
			if selection == &"operation_add" or selection == &"operation_remove":
				select_operation(selection)
			elif selection != StringName():
				request_tool_change(selection)
		return true
	if is_popup_open():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_hide_context_popup()
		return true
	if waiting_for_material_commit:
		return true
	if (
		bool(ui.get("v2_save_in_progress"))
		or bool(ui.call("_is_retained_edit_pending"))
		or bool(ui.call("_is_keybinding_capture_active"))
		or bool(ui.call("_is_text_entry_focused"))
		or bool(ui.call("_has_focused_window_layer"))
		or bool(ui.call("_has_visible_popup_menu"))
	):
		return false
	if _matches(Bindings.ACTION_TOOL_RADIAL, event):
		var workspace: Control = ui.get("workspace_view_container") as Control
		if workspace == null or not Rect2(Vector2.ZERO, workspace.size).has_point(workspace.get_local_mouse_position()):
			return false
		_open_radial()
		return true
	if _matches(Bindings.ACTION_CONTEXT_ACTIONS, event):
		ui.call("_finish_workspace_edit_before_view_change")
		open_context_popup()
		return true
	for action: StringName in Bindings.PROFILE_SLOT_ACTIONS:
		if _matches(action, event):
			# Reserved independently of text entry; profile assignment is future work.
			return true
	return false


func _matches(action: StringName, event: InputEvent) -> bool:
	return bool(ui.call("_v2_event_matches_binding", action, event))


func _controller() -> Node:
	return ui.get("active_stage_controller") as Node if ui != null else null


func get_context() -> Dictionary:
	var controller := _controller()
	if controller == null:
		return {}
	var summary: Dictionary = controller.call("get_status_summary") as Dictionary
	var tool := StringName(summary.get("active_tool", &""))
	if context_generation_completed and tool == context_tool:
		# Generation has already consumed the path. A rejected commit can be
		# retried without generating a second shape or discarding pending work.
		return {"tool": tool, "unfinished": true, "commit_generated": true,
			"can_apply": not waiting_for_material_commit, "can_cancel": false}
	if controller.has_method("is_retained_spline_change_active") and bool(controller.call("is_retained_spline_change_active")):
		var pending := bool(controller.call("is_retained_spline_change_pending"))
		return {"tool": tool, "unfinished": true, "retained_edit": true,
			"apply_method": &"apply_retained_spline_change", "cancel_method": &"cancel_retained_spline_change",
			"can_apply": not pending, "can_cancel": not pending}
	var spline: Dictionary = summary.get("spline_line", {}) as Dictionary
	var unfinished := int(spline.get("point_count", 0)) > 0 or bool(summary.get("handle_change_active", false))
	var method := StringName()
	var can_apply := false
	match tool:
		&"tool_spline_line":
			method = &"generate_spline_line_csg_noodle"
			can_apply = bool(spline.get("can_generate_csg_noodle", false))
		&"tool_handles":
			method = &"generate_profile_extrusion_from_spline"
			can_apply = bool(summary.get("can_generate_profile_extrusion", false))
		&"tool_detailing_brush":
			method = &"generate_detailing_brush"
			can_apply = bool((spline.get("detailing_brush", {}) as Dictionary).get("can_generate", false))
	# A legacy draft can contain stranded path points in Stroke mode. Permit an
	# explicit Cancel of that draft, but never guess its original generation tool.
	return {"tool": tool, "unfinished": unfinished, "apply_method": method,
		"can_apply": can_apply, "can_cancel": unfinished}


func request_tool_change(tool: StringName, after_select: Callable = Callable()) -> void:
	if waiting_for_material_commit:
		return
	var context := get_context()
	if context.is_empty():
		return
	if tool == StringName(context.get("tool", &"")):
		if after_select.is_valid():
			after_select.call()
		return
	if bool(context.get("unfinished", false)):
		open_context_popup(tool, after_select)
	elif _select_tool(tool) and after_select.is_valid():
		after_select.call()


func _select_tool(tool: StringName) -> bool:
	var controller := _controller()
	if controller == null or not controller.has_method("select_tool_for_authoring"):
		return false
	ui.call("_finish_workspace_edit_before_view_change")
	if bool(controller.call("select_tool_for_authoring", tool)):
		ui.call("_set_retained_edit_mode", false)
		ui.set("editor_loaded_saved_profile_id", StringName())
		ui.call("_refresh_from_controller")
		ui.call("_refresh_profile_builder_popup")
		return true
	ui.call("_set_v2_action_status_text", "Finish the current material operation before changing tools.")
	return false


func select_operation(selection: StringName) -> void:
	var controller := _controller()
	if controller == null:
		return
	# Operation changes are intentionally not tool changes and never open a prompt.
	var operation: StringName = Stroke.OPERATION_ADD_MATERIAL if selection == &"operation_add" else Stroke.OPERATION_REMOVE_MATERIAL
	controller.call("set_active_operation_mode", operation)


func _open_radial() -> void:
	var host: Control = ui.get("workspace_frame_host") as Control
	if host == null:
		return
	ui.call("_end_action_history_hold")
	ui.call("_finish_workspace_edit_before_view_change")
	if radial == null:
		radial = Radial.new()
		radial.name = "WorkspaceToolRadial"
		host.add_child(radial)
		radial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var controller := _controller()
	var summary: Dictionary = controller.call("get_status_summary") as Dictionary if controller != null else {}
	var remove := StringName(summary.get("operation", &"")) == Stroke.OPERATION_REMOVE_MATERIAL
	var centre: Array[Dictionary] = [
		{"id": &"operation_add", "label": "Add", "selected": not remove},
		{"id": &"operation_remove", "label": "Remove", "selected": remove},
	]
	var bindings: Resource = ui.get("keybinding_state") as Resource
	radial_binding = bindings.call("get_binding_data", Bindings.ACTION_TOOL_RADIAL) as Dictionary
	radial_active = true
	radial.call("open_at", host.get_local_mouse_position(), TOOL_ENTRIES, centre)


func _cancel_radial() -> void:
	radial_active = false
	radial_binding.clear()
	if is_instance_valid(radial):
		radial.call("close_menu")


func open_context_popup(next_tool: StringName = StringName(), after_select: Callable = Callable()) -> void:
	if waiting_for_material_commit:
		return
	var context := get_context()
	if context.is_empty():
		return
	ui.call("_end_action_history_hold")
	_hide_context_popup()
	context_tool = StringName(context.get("tool", &""))
	pending_tool = next_tool
	pending_action = after_select
	var popup := PopupPanel.new()
	context_popup = popup
	popup.name = "WorkspaceContextActions"
	popup.unresizable = true
	WindowPolicy.configure_owned_popup(popup)
	ui.call("_apply_v2_popup_theme", popup)
	ui.add_child(popup)
	var profile_window := ui.get("profile_builder_popup") as Window
	if is_instance_valid(profile_window) and profile_window.visible and (profile_window.has_focus() or after_select.is_valid()):
		WindowPolicy.attach_owned_popup(profile_window, popup)
	popup.popup_hide.connect(_on_popup_hidden.bind(popup))
	var margin := MarginContainer.new()
	ui.call("_apply_margin", margin, 4)
	popup.add_child(margin)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 2)
	margin.add_child(buttons)
	var apply := Button.new()
	apply.name = "Apply"
	apply.text = "Apply"
	apply.custom_minimum_size = Vector2(136, 30)
	apply.disabled = not bool(context.get("can_apply", false))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#246a3b")
	apply.add_theme_stylebox_override("normal", normal)
	var bold := SystemFont.new()
	bold.font_names = PackedStringArray(["Segoe UI", "sans-serif"])
	bold.font_weight = 700
	apply.add_theme_font_override("font", bold)
	apply.pressed.connect(_execute_context_action.bind(true))
	buttons.add_child(apply)
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(136, 30)
	cancel.disabled = not bool(context.get("can_cancel", false))
	cancel.pressed.connect(_execute_context_action.bind(false))
	buttons.add_child(cancel)
	popup.popup(Rect2i(WindowPolicy.get_control_pointer_screen_position(ui.get("workspace_view_container") as Control), Vector2i(144, 70)))


func _execute_context_action(apply: bool) -> void:
	if waiting_for_tool or waiting_for_retained_apply or waiting_for_material_commit:
		return
	var context := get_context()
	if StringName(context.get("tool", &"")) != context_tool:
		_hide_context_popup()
		return
	var controller := _controller()
	var method := StringName(context.get("apply_method", &"")) if apply else StringName(context.get("cancel_method", &"cancel_spline_line"))
	if controller == null or not bool(context.get("can_apply" if apply else "can_cancel", false)):
		return
	ui.call("_finish_workspace_spline_point_drag")
	if not bool(context.get("commit_generated", false)) and not bool(controller.call(method)):
		ui.call("_set_v2_action_status_text", "Could not apply this operation; the current work is retained.")
		return
	if apply and bool(context.get("retained_edit", false)) and bool(controller.call("is_retained_spline_change_pending")):
		waiting_for_retained_apply = true
		_refresh_context_buttons()
		ui.call("_set_v2_action_status_text", "Applying the shape edit...")
		set_process(true)
		return
	if apply and not bool(context.get("retained_edit", false)):
		context_generation_completed = true
		waiting_for_material_commit = true
		_refresh_context_buttons()
		ui.call("_set_v2_action_status_text", "Finishing the shape...")
		var applied_popup := context_popup
		var applied_state: Resource = controller.get("active_authoring_state") as Resource
		# Reuse the same chronological commit and Undo finalization as Save,
		# without saving a file or baking/exporting the complete weapon.
		var result: Dictionary = await controller.call("commit_all_pending_material_bodies_as_layers")
		waiting_for_material_commit = false
		# Escape/focus loss can dismiss the popup while committing continues.
		# That abandons its queued tool switch, never the generated geometry.
		if not is_instance_valid(applied_popup) or context_popup != applied_popup or _controller() != controller:
			return
		if controller.get("active_authoring_state") != applied_state:
			_hide_context_popup()
			return
		if not bool(result.get("ok", false)):
			ui.call("_set_v2_action_status_text", "Could not finish the shape (%s). Generated work is retained; Apply retries." % String(result.get("reason", "commit failed")))
			_refresh_context_buttons()
			return
		context_generation_completed = false
		ui.call("_set_v2_action_status_text", "Shape applied.")
	_finish_context_action()


func _refresh_context_buttons() -> void:
	if not is_instance_valid(context_popup):
		return
	var context := get_context()
	for button_name: String in ["Apply", "Cancel"]:
		var button := context_popup.find_child(button_name, true, false) as Button
		if button != null:
			button.disabled = waiting_for_retained_apply or waiting_for_material_commit or waiting_for_tool or not bool(context.get("can_apply" if button_name == "Apply" else "can_cancel", false))


func _finish_context_action() -> void:
	ui.call("_refresh_retained_edit_mode")
	if pending_tool != StringName() and not _select_tool(pending_tool):
		# Apply can start a deferred material commit. Keep the user's requested
		# tool/profile until that finishes; do not execute Apply a second time.
		waiting_for_tool = true
		for button_name: String in ["Apply", "Cancel"]:
			var button := context_popup.find_child(button_name, true, false) as Button
			if button != null:
				button.disabled = true
		ui.call("_set_v2_action_status_text", "Finishing the material operation before changing tools. Escape keeps the current tool.")
		set_process(true)
		return
	var after_select := pending_action
	var owner_window := context_popup.get_parent() as Window
	_hide_context_popup()
	if after_select.is_valid():
		after_select.call()
	if is_instance_valid(owner_window) and owner_window.visible:
		owner_window.grab_focus()
	else:
		ui.call("_restore_v2_workspace_input_after_top_menu")


func _hide_context_popup() -> void:
	var popup := context_popup
	context_popup = null
	context_tool = StringName()
	pending_tool = StringName()
	pending_action = Callable()
	waiting_for_tool = false
	waiting_for_retained_apply = false
	context_generation_completed = false
	set_process(false)
	if is_instance_valid(popup):
		popup.hide()
		popup.queue_free()


func _on_popup_hidden(popup: PopupPanel) -> void:
	if context_popup == popup:
		_hide_context_popup()
