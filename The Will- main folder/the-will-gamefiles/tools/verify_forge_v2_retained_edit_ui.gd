extends SceneTree

## Actual Forge workspace input, publication and final-surface selection.
## Uses isolated diagnostic preferences; does not open or alter player saves.
const UI = preload("res://scenes/ui_v2/crafting_bench_ui_v2.tscn")
const CONTROLLER = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const PREFS = preload("res://core/models/forge_v2_editor_settings_state.gd")
const KEYS = preload("res://runtime/forge_v2/forge_v2_keybinding_state.gd")
const PROFILES = preload("res://core/models/player_tool_profile_library_state.gd")
const BODY = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const OUTPUT := "C:/WORKSPACE/test_artifacts/forge_retained_edit_ui_20261018"
var ui: CanvasLayer
var controller: Node
var state: Resource
var workspace: Node3D
var presenter: Node3D
var view: Control
var actions: Node
var checks: Array[Dictionary] = []
var failures := 0
var body_ids: Array[StringName] = []
var handle_id := StringName()
var saved_cursor := Vector2i.ZERO
var cursor_warped := false
var finished := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		_check(false, "UI integration watchdog")
		_finish())
	root.size = Vector2i(1280, 900)
	controller = CONTROLLER.new()
	var preferences = PREFS.new()
	preferences.save_file_path = "user://diagnostics/retained_edit_ui/preferences.tres"
	controller.editor_settings = preferences
	root.add_child(controller)
	ui = UI.instantiate() as CanvasLayer
	var keys = KEYS.new()
	keys.save_file_path = "user://diagnostics/retained_edit_ui/keys.json"
	ui.set("keybinding_state", keys)
	var profiles = PROFILES.new()
	profiles.save_file_path = "user://diagnostics/retained_edit_ui/profiles.tres"
	ui.set("tool_profile_library_state", profiles)
	root.add_child(ui)
	await process_frame
	ui.call("open_for", null, controller, "Retained Shape Editing", null)
	await process_frame
	state = controller.call("get_active_authoring_state") as Resource
	workspace = ui.get("workspace_preview") as Node3D
	presenter = workspace.get("volume_preview_presenter") as Node3D
	view = ui.get("workspace_view_container") as Control
	actions = ui.get("workspace_action_menu") as Node
	state.set("active_brush_radius_meters", 0.012)
	controller.call("set_active_primitive_id", &"primitive_blob")
	for index in range(7):
		if not await _append_operation(index):
			await _finish()
			return
	await _append_handle()
	if failures > 0:
		await _finish()
		return
	workspace.call("set_axis_view", &"front")
	for frame in range(120):
		await process_frame
		if not bool(workspace.call("is_view_transitioning")):
			break
	var camera := workspace.get("camera") as Camera3D
	var pivot := workspace.get("camera_pivot") as Node3D
	pivot.position = Vector3(-0.04, -0.035, 0)
	camera.position.z = 0.82
	workspace.call("_sync_orthographic_size")
	_key(KEY_E)
	await _wait_selection()
	_check(bool(ui.get("retained_edit_mode")), "real E input enters selection")
	_check((state.call("get_retained_spline_editable_entries") as Array).size() == 3,
		"five ordinary slots contain three editable splines plus two freehand operations")
	_check(int(state.call("get_bounded_presentation_descriptor").get("checkpoint_operation_count", 0)) == 2,
		"older two splines are fused")
	await _test_colours_and_hover()
	await _capture("selection")
	if failures == 0:
		await _test_spline_edit()
	if failures == 0:
		await _test_handle_edit()
	await _capture("selection_after_edits")
	await _finish()

func _append_operation(index: int) -> bool:
	var y := _row_y(index)
	if index in [3, 5]:
		controller.call("set_active_tool_id", &"tool_volume_stroke")
		var id := StringName(controller.call("begin_material_body_path", Vector3(-0.16, y, 0), Vector3.FORWARD))
		body_ids.append(id)
		controller.call("extend_material_body_path", Vector3(0.04, y, 0), true, Vector3.FORWARD)
		controller.call("finish_material_body_path", Vector3(0.24, y, 0), true, Vector3.FORWARD)
		if not _check(id != StringName(), "freehand operation %d created" % index):
			return false
	else:
		controller.call("set_active_tool_id", &"tool_spline_line")
		for point in [Vector3(-0.16, y, 0), Vector3(0.04, y + 0.012, 0), Vector3(0.24, y, 0)]:
			controller.call("append_spline_line_point", point, Vector3.FORWARD)
		if not _check(bool(controller.call("generate_spline_line_csg_noodle")), "spline operation %d generated" % index):
			return false
		var layer := controller.call("commit_pending_material_bodies_as_layer") as Resource
		if not _check(layer != null, "spline operation %d committed" % index):
			return false
		var latest := (state.get("material_bodies") as Array).back() as Resource
		body_ids.append(StringName(latest.get("body_id")))
	await _settle()
	return _check(_native_ready(), "operation %d has a ready final mesh" % index)

func _append_handle() -> void:
	controller.call("set_active_tool_id", &"tool_handles")
	controller.call("reset_active_handle_profile_builder")
	controller.call("set_active_profile_width_meters", 0.030)
	controller.call("set_active_profile_height_meters", 0.030)
	for point in [Vector3(-0.29, -0.22, 0), Vector3(-0.29, 0, 0), Vector3(-0.29, 0.18, 0)]:
		controller.call("append_spline_line_point", point, Vector3.FORWARD)
	_check(bool(controller.call("generate_profile_extrusion_from_spline")), "protected Handle generated")
	controller.call("commit_pending_material_bodies_as_layer")
	await _settle()
	for body: Resource in state.get("material_bodies"):
		if StringName(body.get("profile_role")) == BODY.PROFILE_ROLE_HANDLE:
			handle_id = StringName(body.get("body_id"))
	_check(handle_id != StringName(), "protected Handle has stable identity")

func _test_colours_and_hover() -> void:
	var selection = presenter.get("retained_edit_selection")
	var colours := {2: Color("d87928"), 4: Color("e9d34e"), 6: Color("48bf72")}
	for index in range(7):
		var hit := _hit(_row_center(index))
		_check(bool(hit.get("valid", false)), "row %d has a final visible surface" % index)
		var editable := index in [2, 4, 6]
		_check(bool(hit.get("editable", false)) == editable, "row %d editability matches retained source" % index)
		var id := StringName(hit.get("body_id", StringName()))
		if index >= 2:
			_check(id == body_ids[index], "row %d picking identifies its own retained source" % index)
		var material := (selection.get("materials") as Dictionary).get(id) as ShaderMaterial
		var expected: Color = colours.get(index, Color("c64f4f"))
		_check(material != null and _rgb_equal(material.get_shader_parameter("tint"), expected), "row %d tint matches editable rank / unavailable red" % index)
	var handle_hit := _hit(Vector3(-0.29, 0, 0))
	_check(bool(handle_hit.get("is_handle", false)) and bool(handle_hit.get("editable", false))
		and StringName(handle_hit.get("body_id", StringName())) == handle_id, "Handle pick uses protected source")
	var handle_material := (selection.get("materials") as Dictionary).get(handle_id) as ShaderMaterial
	_check(handle_material != null and _rgb_equal(handle_material.get_shader_parameter("tint"), Color("a77ad9")), "Handle has purple tint")
	await _move(_screen(_row_center(6)))
	_check(StringName(ui.get("retained_edit_hover_body")) == body_ids[6], "mouse hover selects same owner as final-surface ray")
	var hovered := (selection.get("materials") as Dictionary).get(body_ids[6]) as ShaderMaterial
	_check(hovered != null and _rgb_equal(hovered.get_shader_parameter("tint"), Color("48bf72").lightened(0.3)), "hover brightens only selected spline")
	var undo_count := int(controller.call("get_action_history_summary").undo_count)
	for index in [0, 3]:
		await _click(_screen(_row_center(index)))
		_check(not bool(controller.call("is_retained_spline_change_active")) and not bool(state.call("is_handle_change_active"))
			and (state.get("spline_line_points") as PackedVector3Array).is_empty(), "red row %d click cannot reopen or deposit geometry" % index)
	_check(int(controller.call("get_action_history_summary").undo_count) == undo_count, "unavailable-surface clicks do not add Undo records")
	await _move(Vector2(10, 10))

func _test_spline_edit() -> void:
	var id := body_ids[6]
	var before := (_body(id).get("path_points") as PackedVector3Array).duplicate()
	var old_rolls := (_body(id).get("path_roll_degrees") as PackedFloat64Array).duplicate()
	var actions_before := int(controller.call("get_action_history_summary").undo_count)
	await _click(_screen(_row_center(6)))
	if not _check(bool(controller.call("is_retained_spline_change_active")), "LMB on visible editable spline opens its retained draft"):
		return
	_check(state.get("spline_line_points") == before, "selected source restores its exact original points")
	await process_frame
	var destination := before[1] + Vector3(0, 0.017, 0)
	await _drag(_screen(before[1]), _screen(destination))
	var edited: PackedVector3Array = state.get("spline_line_points")
	_check(edited[1].distance_to(destination) < 0.0003, "real point drag moves existing point in its plane")
	_check(_body(id).get("path_points") == before, "drag leaves authoritative original unchanged before Apply")
	var degrees := ui.get("spline_roll_degrees_spin_box") as SpinBox
	degrees.value = 35.0
	_check(is_equal_approx(float(state.call("get_spline_line_point_roll_degrees", 1)), 35.0), "Degrees control updates selected retained point")
	await _capture("editing")
	_key(KEY_S)
	await _popup_click("Apply")
	await _settle()
	await process_frame
	if not _check(not bool(controller.call("is_retained_spline_change_active")) and not bool(actions.call("is_popup_open")), "S Apply waits for publication then closes only its popup"):
		return
	_check(bool(ui.get("retained_edit_mode")), "successful Apply returns to E selection")
	_check(int(controller.call("get_action_history_summary").undo_count) == actions_before + 1, "UI Apply is one global Undo action")
	_check((_body(id).get("path_points") as PackedVector3Array)[1].distance_to(destination) < 0.0003
		and is_equal_approx((_body(id).get("path_roll_degrees") as PackedFloat64Array)[1], 35.0), "published source contains dragged point and twist")
	_key(KEY_Z, true)
	await _settle()
	_check(_body(id).get("path_points") == before and _body(id).get("path_roll_degrees") == old_rolls, "Ctrl+Z restores pre-edit source")
	_key(KEY_Y, true)
	await _settle()
	await _wait_selection()
	var published := (_body(id).get("path_points") as PackedVector3Array).duplicate()
	_check(published[1].distance_to(destination) < 0.0003, "Ctrl+Y restores edited source")
	await _click(_screen(published[1]))
	if not _check(bool(controller.call("is_retained_spline_change_active")), "edited final surface can be reopened"):
		return
	controller.call("set_spline_line_point", 1, published[1] + Vector3(0.01, 0.01, 0))
	_key(KEY_S)
	await _popup_click("Cancel")
	await _wait_selection()
	_check(not bool(controller.call("is_retained_spline_change_active")) and _body(id).get("path_points") == published, "S Cancel keeps published shape and discards only the draft")

func _test_handle_edit() -> void:
	var before := (_body(handle_id).get("path_points") as PackedVector3Array).duplicate()
	await _click(_screen(Vector3(-0.29, 0, 0)))
	if not _check(bool(state.call("is_handle_change_active")) and bool(ui.get("retained_edit_handle_active")), "purple Handle click enters existing Handle editing"):
		return
	controller.call("set_spline_line_point", 1, before[1] + Vector3(-0.015, 0, 0))
	_key(KEY_S)
	await _popup_click("Cancel")
	await _wait_selection()
	_check(not bool(state.call("is_handle_change_active")) and _body(handle_id).get("path_points") == before, "Handle Cancel restores its protected source and selection")

func _row_y(index: int) -> float:
	return -0.24 + index * 0.065

func _row_center(index: int) -> Vector3:
	return Vector3(0.04, _row_y(index) + (0.0 if index in [3, 5] else 0.012), 0)

func _body(id: StringName) -> Resource:
	for body: Resource in state.get("material_bodies"):
		if StringName(body.get("body_id")) == id:
			return body
	return null

func _screen(point: Vector3) -> Vector2:
	return (workspace.call("project_workspace_local_to_screen", point) as Dictionary).get("screen_position", Vector2.ZERO)

func _hit(point: Vector3) -> Dictionary:
	return workspace.call("resolve_retained_edit_selection", _screen(point)) as Dictionary

func _key(code: Key, control := false) -> void:
	root.gui_release_focus()
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.ctrl_pressed = control
		event.pressed = pressed
		root.push_input(event, true)

func _move(local_pointer: Vector2, held := false) -> void:
	var pointer := view.get_global_transform_with_canvas() * local_pointer
	await _root_move(pointer, held)

func _root_move(pointer: Vector2, held := false, input_window: Window = null) -> void:
	if input_window == null:
		input_window = root
	if DisplayServer.get_name() != "headless":
		if not cursor_warped:
			saved_cursor = DisplayServer.mouse_get_position()
			cursor_warped = true
		input_window.warp_mouse(pointer)
	var event := InputEventMouseMotion.new()
	event.position = pointer
	event.global_position = pointer
	event.window_id = input_window.get_window_id()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	input_window.push_input(event, true)
	await process_frame

func _button(pointer: Vector2, pressed: bool, input_window: Window = null) -> void:
	if input_window == null:
		input_window = root
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pointer
	event.global_position = pointer
	event.window_id = input_window.get_window_id()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	input_window.push_input(event, true)

func _click(local_pointer: Vector2) -> void:
	await _move(local_pointer)
	var pointer := view.get_global_transform_with_canvas() * local_pointer
	_button(pointer, true)
	_button(pointer, false)
	await process_frame
	await process_frame

func _drag(from: Vector2, to: Vector2) -> void:
	await _move(from)
	_button(view.get_global_transform_with_canvas() * from, true)
	await _move(to, true)
	_button(view.get_global_transform_with_canvas() * to, false)
	await process_frame

func _popup_click(button_name: String) -> void:
	await process_frame
	var popup := actions.get("context_popup") as PopupPanel
	if not _check(is_instance_valid(popup) and popup.visible, "S " + button_name + " popup is visible"):
		return
	var button := popup.find_child(button_name, true, false) as Button
	if not _check(button != null and not button.disabled, "S " + button_name + " is enabled"):
		return
	var input_window: Window = root if popup.is_embedded() else popup
	var screen_pointer := button.get_screen_transform() * (button.size * 0.5)
	var pointer := input_window.get_screen_transform().affine_inverse() * screen_pointer
	await _root_move(pointer, false, input_window)
	_button(pointer, true, input_window)
	_button(pointer, false, input_window)
	await process_frame

func _native_ready() -> bool:
	return bool(presenter.get("native_static_authoritative")) and not bool(presenter.get("native_static_publication_pending"))

func _settle() -> void:
	for frame in range(360):
		await process_frame
		if frame > 4 and not bool(controller.call("is_retained_spline_change_pending")) and not bool(state.call("has_pending_bounded_history_promotion")) and _native_ready():
			await physics_frame
			await process_frame
			return
	_check(false, "native publication settles")

func _wait_selection() -> void:
	for frame in range(180):
		await process_frame
		if frame > 2 and int(presenter.get("retained_edit_selection").get("face_count")) > 0:
			return
	_check(false, "final-surface selection becomes ready")

func _rgb_equal(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.0001

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	_check(root.get_texture().get_image().save_png(OUTPUT.path_join(label + ".png")) == OK, "rendered " + label + " screenshot saved")

func _check(ok: bool, label: String) -> bool:
	checks.append({"ok": ok, "check": label})
	if not ok:
		failures += 1
		push_error(label)
	return ok

func _finish() -> void:
	if finished:
		return
	finished = true
	if cursor_warped:
		DisplayServer.warp_mouse(saved_cursor - DisplayServer.window_get_position(root.get_window_id()))
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var file := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": failures == 0, "failures": failures, "checks": checks}, "\t"))
	print("RETAINED_EDIT_UI ", checks.size() - failures, "/", checks.size())
	if is_instance_valid(ui):
		ui.queue_free()
	if is_instance_valid(controller):
		controller.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
