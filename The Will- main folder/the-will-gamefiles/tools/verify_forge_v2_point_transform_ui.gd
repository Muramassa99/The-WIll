extends SceneTree

# Focused real-UI routing check. Uses isolated in-memory drafting resources and
# test-only profile/keybinding paths; does not open or save the player's WIPs.
const UI_SCENE = preload("res://scenes/ui_v2/crafting_bench_ui_v2.tscn")
const CONTROLLER = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const KEYBINDINGS = preload("res://runtime/forge_v2/forge_v2_keybinding_state.gd")
const PROFILE_LIBRARY = preload("res://core/models/player_tool_profile_library_state.gd")
const DEFAULT_REPORT := "C:/WORKSPACE/test_artifacts/forge_v2_point_transform_ui_20261108.json"

var checks: Array[Dictionary] = []
var failure_count := 0
var publication_evidence: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var controller := CONTROLLER.new()
	root.add_child(controller)
	var ui := UI_SCENE.instantiate() as CanvasLayer
	var keys := KEYBINDINGS.new()
	keys.save_file_path = "user://point_transform_ui_test/keybindings.json"
	var profiles := PROFILE_LIBRARY.new()
	profiles.save_file_path = "user://point_transform_ui_test/profiles.tres"
	ui.set("keybinding_state", keys)
	ui.set("tool_profile_library_state", profiles)
	root.add_child(ui)
	await process_frame
	ui.call("open_for", null, controller, "Point Transform UI Verify", null)
	var state := controller.get_active_authoring_state() as Resource
	state.call("reset_active_basic_profile_builder")
	controller.set_active_tool_id(&"tool_spline_line")
	var points := PackedVector3Array([Vector3(-0.2, 0, 0), Vector3(0, 0.04, 0), Vector3(0.2, 0, 0)])
	for point: Vector3 in points:
		controller.append_spline_line_point(point, Vector3.UP)
	var preview := ui.get("workspace_preview") as Node3D
	var camera := preview.get("camera") as Camera3D
	camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 1))
	camera.fov = 45.0
	await process_frame
	await process_frame
	var middle_screen := _project(preview, points[1])
	_right_click(ui, _project(preview, points[0]))
	_check(ui.get("spline_transform_x") == null, "unassigned point exposes selection actions without expansion fields")
	_press_role(ui, 0)
	_right_click(ui, middle_screen)
	_press_role(ui, 1)
	_right_click(ui, _project(preview, points[2]))
	_press_role(ui, 2)
	_check(ui.get("spline_transform_selection") == PackedInt32Array([0, 1, 2]), "Point1 fixed / Point2 expand / Point3 fixed selected through context buttons")
	var history_before := int(controller.get_action_history_summary().get("undo_count", 0))
	_right_click(ui, middle_screen)
	var popup := ui.get("spline_transform_popup") as PopupPanel
	if not _check(is_instance_valid(popup) and popup.visible, "RMB routed through real workspace handler opens Transform on a point"):
		await _finish(ui, controller)
		return
	_check(int(state.get("selected_spline_point_index")) == 1, "RMB selects the clicked interior point")
	_check(not bool(ui.get("workspace_drag_active")), "point RMB does not start camera orbit")
	var x := ui.get("spline_transform_x") as SpinBox
	var y := ui.get("spline_transform_y") as SpinBox
	_check(x.min_value == -95.0 and y.min_value == -95.0 and x.max_value == 100.0 and y.max_value == 100.0, "interior fields expose independent minus95 to plus100 percent limits")
	_check(x.value == 0.0 and y.value == 0.0, "original profile displays zero change")
	x.value = -50.0
	_check(_selected_scale(ui, state).is_equal_approx(Vector2(0.5, 1.0)), "Expand X changes only profile X")
	y.value = 25.0
	_check(_selected_scale(ui, state).is_equal_approx(Vector2(0.5, 1.25)), "Expand Y changes only profile Y")
	_check(is_instance_valid(popup) and popup.visible, "live changes retain their own popup")
	_check(_scale(state, 0) == Vector2.ONE and _scale(state, 2) == Vector2.ONE, "popup leaves neighbouring point scale values intact")
	_check(state.get("spline_line_points") == points, "popup leaves the authored centreline intact")
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	ui.call("_input", space)
	_check(int(state.get("selected_spline_point_index")) == 1, "popup owns keys and blocks underlying Space point cycling")
	_check(int(controller.get_action_history_summary().get("undo_count", 0)) == history_before, "live edits remain inside one pending history transaction")
	ui.call("_finish_spline_transform_popup")
	_check(ui.get("spline_transform_popup") == null and int(ui.get("spline_transform_point_index")) == -1, "Done clears popup and target")
	_check(int(controller.get_action_history_summary().get("undo_count", 0)) == history_before + 1, "both axis changes produce one history record")
	_check(controller.undo_latest_action() and _scale(state, 1) == Vector2.ONE, "one Undo restores both axes")
	_check(controller.redo_latest_action() and _selected_scale(ui, state).is_equal_approx(Vector2(0.5, 1.25)), "Redo restores independent axis changes")
	await process_frame
	_check(not is_instance_valid(popup), "dismissed context popup is freed")
	_right_click(ui, middle_screen)
	x = ui.get("spline_transform_x") as SpinBox
	x.get_line_edit().text = "-25"
	x.get_line_edit().text_changed.emit("-25")
	_check(_selected_scale(ui, state).is_equal_approx(Vector2(0.5, 1.25)), "typed text remains pending until committed")
	ui.call("_finish_spline_transform_popup")
	_check(_selected_scale(ui, state).is_equal_approx(Vector2(0.75, 1.25)), "Done applies pending typed text without resetting the untouched axis")
	_check(controller.undo_latest_action() and _selected_scale(ui, state).is_equal_approx(Vector2(0.5, 1.25)), "typed popup edit remains one undoable action")
	_right_click(ui, middle_screen)
	x = ui.get("spline_transform_x") as SpinBox
	x.get_line_edit().text = "20"
	x.get_line_edit().text_changed.emit("20")
	ui.call("_on_spline_transform_popup_input", _history_key(KEY_Z))
	_check(ui.get("spline_transform_popup") == null and _selected_scale(ui, state).is_equal_approx(Vector2(0.5, 1.25)), "popup Ctrl+Z commits pending text then undoes the grouped taper")
	_check(ui.get("spline_transform_selection") == PackedInt32Array([0, 1, 2]), "geometry undo retains valid Transform role selection")
	ui.call("_input", _history_key(KEY_Y))
	ui.call("_input", _history_key(KEY_Y, false))
	_check(_selected_scale(ui, state).is_equal_approx(Vector2(1.2, 1.25)), "closed-popup Ctrl+Y redoes the taper through Forge keyboard history")
	ui.call("_input", _history_key(KEY_Z))
	ui.call("_input", _history_key(KEY_Z, false))
	_check(_selected_scale(ui, state).is_equal_approx(Vector2(0.5, 1.25)), "closed-popup Ctrl+Z undoes the taper through Forge keyboard history")
	_right_click(ui, middle_screen)
	ui.call("_input", _history_key(KEY_Y))
	_check(ui.get("spline_transform_popup") == null and _selected_scale(ui, state).is_equal_approx(Vector2(1.2, 1.25)), "popup Ctrl+Y redoes geometry instead of editing only numerical text")
	_check(state.get("spline_line_points") == points, "keyboard taper history preserves centreline positions")
	controller.undo_latest_action()
	_right_click(ui, middle_screen)
	_press_role(ui, 0)
	_right_click(ui, _project(preview, points[2]))
	_press_role(ui, 1)
	_right_click(ui, _project(preview, points[2]))
	popup = ui.get("spline_transform_popup") as PopupPanel
	if not _check(is_instance_valid(popup) and popup.visible, "endpoint opens the same popup"):
		await _finish(ui, controller)
		return
	x = ui.get("spline_transform_x") as SpinBox
	y = ui.get("spline_transform_y") as SpinBox
	_check(x.min_value == -100.0 and y.min_value == -100.0, "endpoint fields permit exact collapse")
	var endpoint_before := _selected_scale(ui, state)
	x.value = -100.0
	_check(_selected_scale(ui, state) == Vector2.ZERO and x.value == -100.0 and y.value == -100.0, "collapsing endpoint X also collapses Y and displays both as a point")
	x.value = -80.0
	_check(_selected_scale(ui, state).is_equal_approx(Vector2(0.2, 0.2)) and is_equal_approx(y.value, -80.0), "raising endpoint X out of point mode reopens both axes equally")
	y.value = -50.0
	_check(_selected_scale(ui, state).is_equal_approx(Vector2(0.2, 0.5)), "positive-size endpoint axes become independently editable again")
	y.value = -100.0
	_check(_selected_scale(ui, state) == Vector2.ZERO and x.value == -100.0, "collapsing endpoint Y also collapses X")
	y.value = -90.0
	_check(_selected_scale(ui, state).is_equal_approx(Vector2(0.1, 0.1)) and is_equal_approx(x.value, -90.0), "raising endpoint Y out of point mode reopens both axes equally")
	x.value = 50.0
	_check(_selected_scale(ui, state).is_equal_approx(Vector2(1.5, 0.1)), "independent endpoint X editing resumes after reopening with Y")
	x.value = -100.0
	_check(_selected_scale(ui, state) == Vector2.ZERO, "endpoint remains a paired-axis apex for preview and history")
	var screenshot_path := OS.get_environment("THE_WILL_TRANSFORM_UI_SCREENSHOT").strip_edges()
	if not screenshot_path.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(screenshot_path.get_base_dir())
		await process_frame
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		_check(screenshot != null and screenshot.save_png(screenshot_path) == OK, "rendered Transform popup screenshot saved")
	popup.hide()
	_check(ui.get("spline_transform_popup") == null and not bool(ui.get("spline_transform_transaction_active")), "native popup dismissal commits and clears transaction")
	_check(ui.get("spline_transform_selection") == PackedInt32Array([1, 2]), "popup dismissal preserves selected transform roles")
	_check(controller.undo_latest_action() and _selected_scale(ui, state).is_equal_approx(endpoint_before), "one Undo restores endpoint before paired collapse and reopening edits")
	_check(controller.redo_latest_action() and _selected_scale(ui, state) == Vector2.ZERO, "one Redo restores the endpoint's paired-axis point")
	await process_frame
	_right_click(ui, middle_screen)
	_check(is_instance_valid(ui.get("spline_transform_popup")), "another point can be reopened")
	controller.select_spline_line_point(0)
	_check(ui.get("spline_transform_popup") == null, "external selection change discards stale popup target")
	_right_click(ui, middle_screen)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	ui.call("_input", escape)
	_check(ui.get("spline_transform_popup") == null and bool(ui.call("is_open")), "Escape closes only Transform and keeps Forge open")
	await process_frame
	# The Handle tool must retain its original RMB/camera behavior. The
	# authoring controller deliberately preserves the working points on this
	# simple tool switch, making the exact same hit an exclusion check.
	controller.set_active_tool_id(&"tool_handles")
	_check((ui.get("spline_transform_selection") as PackedInt32Array).is_empty(), "switching tools clears transient transform roles")
	_right_click(ui, _project(preview, points[1]))
	_check(ui.get("spline_transform_popup") == null, "Handles never expose Transform")
	_check(bool(ui.get("workspace_drag_active")), "RMB over a Handle point retains camera orbit")
	_right_release(ui, middle_screen)
	_check(not bool(ui.get("workspace_drag_active")), "RMB release ends Handle camera orbit")
	controller.set_active_tool_id(&"tool_detailing_brush")
	var detail_normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	var detail_contacts := PackedVector3Array([Vector3.DOWN, Vector3.DOWN, Vector3.DOWN])
	_check(controller.replace_detailing_brush_path_solution(
		points, detail_normals, &"target_material_surface", &"transform_ui_surface",
		points, detail_normals, PackedInt32Array([0, 1, 2]),
		[true, true], [&"none", &"none"], true, &"none", 1,
		detail_contacts, detail_contacts
	), "Detailing fixture uses its resolved path API")
	await process_frame
	_right_click(ui, _project(preview, points[0]))
	_press_role(ui, 0)
	_right_click(ui, _project(preview, points[1]))
	_press_role(ui, 1)
	_right_click(ui, _project(preview, points[2]))
	_press_role(ui, 2)
	_right_click(ui, _project(preview, points[1]))
	popup = ui.get("spline_transform_popup") as PopupPanel
	if _check(is_instance_valid(popup) and popup.visible, "Detailing Brush points expose Transform"):
		x = ui.get("spline_transform_x") as SpinBox
		y = ui.get("spline_transform_y") as SpinBox
		x.value = 100.0
		y.value = -75.0
		_check(_selected_scale(ui, state).is_equal_approx(Vector2(2.0, 0.25)), "Detail popup writes the same profile-local scale data")
		_check(state.get("detailing_resolved_path_points") == points, "Detail transform preserves surface-resolved path")
		ui.call("_finish_spline_transform_popup")
	await process_frame
	controller.cancel_spline_line()
	controller.set_active_tool_id(&"tool_spline_line")
	var range_points := PackedVector3Array([
		Vector3(-0.3, 0, 0), Vector3(-0.15, 0.03, 0), Vector3(0, 0.03, 0),
		Vector3(0.15, 0.03, 0), Vector3(0.3, 0.03, 0),
	])
	for point: Vector3 in range_points:
		controller.append_spline_line_point(point, Vector3.UP)
	await process_frame
	_right_click(ui, _project(preview, range_points[1]))
	_press_role(ui, 0)
	_right_click(ui, _project(preview, range_points[4]))
	_press_role(ui, 1)
	_check(ui.get("spline_transform_selection") == PackedInt32Array([1, 4]), "two-role range can span spline points2 through5")
	_right_click(ui, _project(preview, range_points[4]))
	x = ui.get("spline_transform_x") as SpinBox
	y = ui.get("spline_transform_y") as SpinBox
	if _check(x != null and y != null, "only Point2 exposes expansion fields across a multi-span range"):
		x.value = 80.0
		y.value = -70.0
		_check(_scale(state, 0) == Vector2.ONE and _scale(state, 1) == Vector2.ONE, "range leaves outside point1 and fixed boundary point2 unchanged")
		_check(_selected_scale(ui, state).is_equal_approx(Vector2(1.8, 0.3)), "range writes expansion at chosen Point2 spline point5")
		_check(_scale(state, 2).x > 1.0 and _scale(state, 2).x < _scale(state, 3).x and _scale(state, 3).x < 1.8, "intermediate spline points follow the range taper")
		ui.call("_finish_spline_transform_popup")
	_right_click(ui, _project(preview, range_points[0]))
	_press_role(ui, 0)
	_right_click(ui, _project(preview, range_points[2]))
	_press_role(ui, 1)
	_right_click(ui, _project(preview, range_points[1]))
	popup = ui.get("spline_transform_popup") as PopupPanel
	_check(popup.find_child("SelectTransformPoint3", true, false) == null, "Point3 cannot be selected on the same side of Point2 as Point1")
	_check(ui.get("spline_transform_x") == null, "unselected middle point has no expansion inputs")
	ui.call("_finish_spline_transform_popup")
	_right_click(ui, _project(preview, range_points[4]))
	_press_role(ui, 2)
	_check(ui.get("spline_transform_selection") == PackedInt32Array([0, 2, 4]), "three roles can span intervening spline points on both sides")
	controller.set_spline_line_point(0, range_points[0] + Vector3(0, 0.005, 0))
	_check(ui.get("spline_transform_selection") == PackedInt32Array([0, 2, 4]), "moving a selected point preserves its role identity")
	var geometry_before_clear: PackedVector2Array = state.call("get_spline_line_resolved_profile_scales")
	_right_click(ui, _project(preview, range_points[2]))
	popup = ui.get("spline_transform_popup") as PopupPanel
	var clear_button := popup.find_child("ClearTransformSelection", true, false) as Button
	clear_button.pressed.emit()
	_check((ui.get("spline_transform_selection") as PackedInt32Array).is_empty(), "Clear Transform Selection clears only role selection")
	_check(state.call("get_spline_line_resolved_profile_scales") == geometry_before_clear, "clearing selection keeps authored geometry")
	_right_click(ui, _project(preview, range_points[1]))
	_press_role(ui, 0)
	controller.append_spline_line_point(Vector3(0.4, 0.03, 0), Vector3.UP)
	_check((ui.get("spline_transform_selection") as PackedInt32Array).is_empty(), "point-count change clears stale transform roles")
	await _test_transform_context_actions(ui, controller, state, preview)
	var blank := Vector2(12, 12)
	_check(int(ui.call("_find_nearest_spline_point_at_screen", blank)) == -1, "blank-space fixture misses all points")
	_right_click(ui, blank)
	_check(ui.get("spline_transform_popup") == null and bool(ui.get("workspace_drag_active")), "blank-space RMB retains orbit instead of opening Transform")
	_right_release(ui, blank)
	_check(not bool(ui.get("workspace_drag_active")), "blank-space RMB release clears orbit")
	var double_click := InputEventMouseButton.new()
	double_click.button_index = MOUSE_BUTTON_RIGHT
	double_click.pressed = true
	double_click.double_click = true
	double_click.position = _project(preview, points[1])
	ui.call("_handle_workspace_mouse_button", double_click)
	var view_state: Dictionary = preview.call("get_view_state") as Dictionary
	_check(ui.get("spline_transform_popup") == null and StringName(view_state.get("face_id", StringName())) != StringName(), "double RMB keeps nearest-axis alignment even over a point")
	await _finish(ui, controller)

func _test_transform_context_actions(ui: CanvasLayer, controller: Node, state: Resource, preview: Node3D) -> void:
	controller.call("cancel_spline_line")
	controller.call("set_active_tool_id", &"tool_spline_line")
	var points := PackedVector3Array([Vector3(-0.15, 0, 0), Vector3(0, 0.025, 0), Vector3(0.15, 0, 0)])
	var menu := ui.get("workspace_action_menu") as Node
	var body_count_before := (state.get("material_bodies") as Array).size()
	for point: Vector3 in points:
		controller.call("append_spline_line_point", point, Vector3.UP)
	await process_frame
	_open_middle_transform(ui, preview, points)
	var x := ui.get("spline_transform_x") as SpinBox
	if not _check(x != null, "S context fixture opens Transform fields"):
		return
	x.get_line_edit().grab_focus()
	x.get_line_edit().text = "30"
	x.get_line_edit().text_changed.emit("30")
	ui.call("_input", _plain_key(KEY_S))
	_check(ui.get("spline_transform_popup") == null and bool(menu.call("is_popup_open")),
		"S from focused Transform numbers opens the current-task Apply/Cancel menu")
	_check((state.call("get_spline_line_profile_transform_scale", PackedInt32Array([0, 1, 2])) as Vector2).is_equal_approx(Vector2(1.3, 1.0)),
		"S commits pending typed Transform input before resolving current task")
	_check((ui.get("spline_transform_selection") as PackedInt32Array).is_empty(), "direct S finishes the Transform role selection")
	_check(StringName((menu.call("get_context") as Dictionary).get("apply_method")) == &"generate_spline_line_csg_noodle",
		"new Spline taper routes Apply to actual shape generation")
	_press_context_action(menu, false)
	_check((state.get("spline_line_points") as PackedVector3Array).is_empty()
		and (state.get("material_bodies") as Array).size() == body_count_before,
		"S Cancel cancels the entire unfinished Spline task without generating a body")
	for point: Vector3 in points:
		controller.call("append_spline_line_point", point, Vector3.UP)
	await process_frame
	_open_middle_transform(ui, preview, points)
	x = ui.get("spline_transform_x") as SpinBox
	if not _check(x != null, "S Apply fixture reopens Transform fields"):
		return
	x.get_line_edit().text = "50"
	x.get_line_edit().text_changed.emit("50")
	_press_transform_done(ui)
	_check((ui.get("spline_transform_selection") as PackedInt32Array).is_empty()
		and state.get("spline_line_points") == points,
		"Done ends role selection while preserving every authored spline point")
	_check((state.call("get_spline_line_profile_transform_scale", PackedInt32Array([0, 1, 2])) as Vector2).is_equal_approx(Vector2(1.5, 1.0)),
		"Done applies pending numerical input without deleting taper geometry")
	await process_frame
	ui.call("_input", _plain_key(KEY_S))
	_check(bool(menu.call("is_popup_open")), "root S after the actual Done button opens task confirmation")
	_press_context_action(menu, true)
	if not await _wait_context_action(menu, controller, "S Apply finishes production generation and layer commit"):
		return
	var body := state.call("get_selected_material_body") as Resource
	if not _check(body != null and (state.get("material_bodies") as Array).size() == body_count_before + 1,
		"S Apply creates exactly one real material body"):
		return
	var body_id := StringName(body.get("body_id"))
	var ranges: Array = body.get("path_profile_transform_ranges")
	_check(ranges.size() == 1 and (ranges[0].get("scale") as Vector2).is_equal_approx(Vector2(1.5, 1.0)),
		"S-generated source contains the typed taper, not the old profile")
	_check(StringName(body.get("committed_layer_id")) != StringName()
		and (state.get("spline_line_points") as PackedVector3Array).is_empty(),
		"S Apply commits the generated layer and consumes its authoring path")
	var published_before := await _verify_published_geometry(preview, "done_apply_new")
	var source_before := var_to_bytes(state.call("_build_material_body_export_snapshot", body))
	ui.call("_set_retained_edit_mode", true)
	if not _check(bool(controller.call("begin_retained_spline_change", body_id)), "generated taper opens a real retained E edit"):
		return
	await process_frame
	_open_middle_transform(ui, preview, points)
	x = ui.get("spline_transform_x") as SpinBox
	if not _check(x != null, "retained E edit opens Transform fields"):
		return
	x.value = -40.0
	var bindings := ui.get("keybinding_state") as Resource
	var original_binding: Dictionary = bindings.call("get_binding_data", KEYBINDINGS.ACTION_CONTEXT_ACTIONS)
	bindings.call("set_binding_data", KEYBINDINGS.ACTION_CONTEXT_ACTIONS, {"physical_keycode": KEY_K, "keycode": KEY_K})
	ui.call("_input", _plain_key(KEY_S))
	_check(is_instance_valid(ui.get("spline_transform_popup")) and not bool(menu.call("is_popup_open")),
		"Transform respects a remapped confirmation action instead of hard-coding S")
	# PopupPanel has its own input callback; exercise the native route too.
	ui.call("_on_spline_transform_popup_input", _plain_key(KEY_K))
	bindings.call("set_binding_data", KEYBINDINGS.ACTION_CONTEXT_ACTIONS, original_binding)
	var context: Dictionary = menu.call("get_context")
	_check(bool(menu.call("is_popup_open")) and bool(context.get("retained_edit", false))
		and StringName(context.get("cancel_method")) == &"cancel_retained_spline_change",
		"remapped confirmation resolves retained E cancellation rather than new-shape cancellation")
	_press_context_action(menu, false)
	body = state.call("_find_material_body_by_id", body_id) as Resource
	_check(not bool(controller.call("is_retained_spline_change_active"))
		and var_to_bytes(state.call("_build_material_body_export_snapshot", body)) == source_before,
		"retained S Cancel discards the whole edit and preserves committed source")
	if not _check(bool(controller.call("begin_retained_spline_change", body_id)), "retained E source reopens for Apply check"):
		return
	await process_frame
	_open_middle_transform(ui, preview, points)
	x = ui.get("spline_transform_x") as SpinBox
	if not _check(x != null, "retained Apply fixture exposes Transform fields"):
		return
	x.get_line_edit().text = "25"
	x.get_line_edit().text_changed.emit("25")
	_press_transform_done(ui)
	_check((ui.get("spline_transform_selection") as PackedInt32Array).is_empty()
		and bool(controller.call("is_retained_spline_change_active")),
		"retained Done clears roles while keeping the actual E edit open for confirmation")
	await process_frame
	ui.call("_input", _plain_key(KEY_S))
	_check(bool(menu.call("is_popup_open")), "root S after retained Done opens task confirmation")
	context = menu.call("get_context")
	_check(bool(context.get("retained_edit", false)) and StringName(context.get("apply_method")) == &"apply_retained_spline_change",
		"retained S Apply routes to replacement, not duplicate generation")
	_press_context_action(menu, true)
	if not await _wait_context_action(menu, controller, "retained S Apply completes replacement publication"):
		return
	body = state.call("_find_material_body_by_id", body_id) as Resource
	ranges = body.get("path_profile_transform_ranges") if body != null else []
	_check(body != null and ranges.size() == 1
		and (ranges[0].get("scale") as Vector2).is_equal_approx(Vector2(1.25, 1.0))
		and (state.get("material_bodies") as Array).size() == body_count_before + 1,
		"retained S Apply installs the typed taper on the existing body without duplication")
	_check(not bool(controller.call("is_retained_spline_change_active")), "retained Apply exits the edit session")
	var published_after := await _verify_published_geometry(preview, "done_apply_retained")
	_check(not published_before.is_empty() and not published_after.is_empty() and published_before != published_after,
		"retained Done then S Apply publishes changed triangle geometry, not the old mesh")
	ui.call("_set_retained_edit_mode", false)

func _press_transform_done(ui: CanvasLayer) -> void:
	var popup := ui.get("spline_transform_popup") as PopupPanel
	if not _check(is_instance_valid(popup), "Done button's Transform popup is open"):
		return
	var button := popup.find_child("Done", true, false) as Button
	if _check(button != null, "actual Transform Done button is present"):
		button.pressed.emit()
	_check(ui.get("spline_transform_popup") == null and not bool(ui.get("spline_transform_transaction_active")),
		"Done closes the popup and finishes its history transaction")

func _verify_published_geometry(preview: Node3D, label: String) -> PackedByteArray:
	var presenter := preview.get("volume_preview_presenter") as Node3D
	var deadline := Time.get_ticks_msec() + 15000
	var published: Node3D = null
	var render_records: Array[Dictionary] = []
	while Time.get_ticks_msec() < deadline:
		# The first publication can legitimately use the exact CSG fallback;
		# a later retained replacement may switch it to the native lane. Inspect
		# the authoritative drawable output, not one backend's optional pointer.
		published = presenter.get("native_static_published_node") as Node3D \
			if bool(presenter.get("native_static_authoritative")) \
			else presenter.get("csg_static_body_root") as Node3D
		if is_instance_valid(published) and published.is_visible_in_tree():
			render_records = _published_render_records(published)
			if not render_records.is_empty() and not bool(presenter.get("native_static_publication_pending")):
				break
		await process_frame
	publication_evidence.append({"label": label,
		"native_authoritative": presenter.get("native_static_authoritative"),
		"native_lifecycle": presenter.get("native_static_lifecycle"),
		"native_publication_pending": presenter.get("native_static_publication_pending"),
		"render_record_count": render_records.size(),
		"native_diagnostics": (presenter.get("native_static_sync_diagnostics") as Dictionary).duplicate(true),
		"csg_diagnostics": (presenter.get("csg_static_sync_diagnostics") as Dictionary).duplicate(true)})
	if not _check(is_instance_valid(published) and published.is_visible_in_tree(), label + " has a visible authoritative solid publication"):
		return PackedByteArray()
	var visible_meshes: Array[Node3D] = []
	var geometry: Array = []
	var triangle_count := 0
	for record: Dictionary in render_records:
		var instance := record.instance as Node3D
		var mesh := record.mesh as Mesh
		visible_meshes.append(instance)
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangle_count += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
			geometry.append([vertices, indices])
	if not _check(not visible_meshes.is_empty() and triangle_count > 0, label + " presents actual triangle surfaces to the renderer"):
		return PackedByteArray()
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var viewport := preview.get_viewport()
		var visible_image := viewport.get_texture().get_image()
		for instance: Node3D in visible_meshes:
			instance.visible = false
		await process_frame
		await RenderingServer.frame_post_draw
		var hidden_image := viewport.get_texture().get_image()
		for instance: Node3D in visible_meshes:
			instance.visible = true
		await process_frame
		await RenderingServer.frame_post_draw
		var changed_pixels := 0
		if visible_image != null and hidden_image != null and visible_image.get_size() == hidden_image.get_size():
			for y in range(0, visible_image.get_height(), 2):
				for x in range(0, visible_image.get_width(), 2):
					var a := visible_image.get_pixel(x, y)
					var b := hidden_image.get_pixel(x, y)
					if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.03:
						changed_pixels += 1
		_check(changed_pixels >= 4, label + " solid contributes visible viewport pixels (%d sampled pixels)" % changed_pixels)
		if visible_image != null:
			var screenshot_path := OS.get_environment("THE_WILL_TRANSFORM_UI_SCREENSHOT").strip_edges()
			if screenshot_path.is_empty():
				screenshot_path = DEFAULT_REPORT.get_basename() + ".png"
			screenshot_path = screenshot_path.get_basename() + "_" + label + ".png"
			DirAccess.make_dir_recursive_absolute(screenshot_path.get_base_dir())
			_check(visible_image.save_png(screenshot_path) == OK, label + " rendered solid screenshot saved")
	return var_to_bytes(geometry)

func _published_render_records(published: Node3D) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var candidates: Array[Node] = [published]
	candidates.append_array(published.find_children("*", "Node3D", true, false))
	for child: Node in candidates:
		var instance := child as Node3D
		if instance == null or not instance.is_visible_in_tree():
			continue
		var mesh: Mesh = null
		if instance is MeshInstance3D:
			mesh = (instance as MeshInstance3D).mesh
		elif instance is CSGShape3D and (instance as CSGShape3D).is_root_shape():
			mesh = (instance as CSGShape3D).bake_static_mesh()
		if mesh != null and mesh.get_surface_count() > 0:
			records.append({"instance": instance, "mesh": mesh})
	return records

func _open_middle_transform(ui: CanvasLayer, preview: Node3D, points: PackedVector3Array) -> void:
	_right_click(ui, _project(preview, points[0]))
	_press_role(ui, 0)
	_right_click(ui, _project(preview, points[1]))
	_press_role(ui, 1)
	_right_click(ui, _project(preview, points[2]))
	_press_role(ui, 2)
	_right_click(ui, _project(preview, points[1]))

func _press_context_action(menu: Node, apply: bool) -> void:
	var popup := menu.get("context_popup") as PopupPanel
	if not _check(is_instance_valid(popup) and popup.visible, "task confirmation popup is available"):
		return
	var button := popup.find_child("Apply" if apply else "Cancel", true, false) as Button
	if _check(button != null and not button.disabled, "current task action is enabled"):
		button.pressed.emit()

func _wait_context_action(menu: Node, controller: Node, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if not bool(menu.call("is_popup_open")) and not bool(menu.get("waiting_for_material_commit")) \
			and not bool(controller.call("is_retained_spline_change_pending")):
			return _check(true, label)
		await process_frame
	return _check(false, label + "; " + str(controller.get("last_retained_spline_change_result")))

func _plain_key(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	return event

func _right_click(ui: CanvasLayer, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = position
	ui.call("_handle_workspace_mouse_button", press)

func _right_release(ui: CanvasLayer, position: Vector2) -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	release.position = position
	ui.call("_handle_workspace_mouse_button", release)

func _press_role(ui: CanvasLayer, role: int) -> void:
	var popup := ui.get("spline_transform_popup") as PopupPanel
	if not _check(is_instance_valid(popup), "role selection popup exists"):
		return
	var button := popup.find_child("SelectTransformPoint%d" % (role + 1), true, false) as Button
	if _check(button != null, "Point%d selection action is available" % (role + 1)):
		button.pressed.emit()

func _history_key(key: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.ctrl_pressed = true
	event.pressed = pressed
	return event

func _project(preview: Node3D, position: Vector3) -> Vector2:
	var projected: Dictionary = preview.call("project_workspace_local_to_screen", position) as Dictionary
	return projected.get("screen_position", Vector2.ZERO) as Vector2

func _selected_scale(ui: CanvasLayer, state: Resource) -> Vector2:
	return state.call("get_spline_line_profile_transform_scale", ui.get("spline_transform_selection")) as Vector2

func _scale(state: Resource, index: int) -> Vector2:
	var scales: PackedVector2Array = state.call("get_spline_line_resolved_profile_scales")
	return scales[index] if index >= 0 and index < scales.size() else Vector2.ONE

func _check(condition: bool, label: String) -> bool:
	checks.append({"label": label, "passed": condition})
	if not condition:
		failure_count += 1
		printerr("FAIL: ", label)
	return condition

func _finish(ui: CanvasLayer, controller: Node) -> void:
	var report_path := OS.get_environment("THE_WILL_TRANSFORM_UI_REPORT").strip_edges()
	if report_path.is_empty():
		report_path = DEFAULT_REPORT
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var report := {"ok": failure_count == 0, "passed": checks.size() - failure_count, "failed": failure_count,
		"checks": checks, "publication_evidence": publication_evidence}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("FORGE_TRANSFORM_UI: ", JSON.stringify({"ok": report.ok, "passed": report.passed, "failed": report.failed, "report": report_path}))
	ui.call("close_ui")
	ui.queue_free()
	controller.queue_free()
	await process_frame
	quit(0 if failure_count == 0 else 1)
