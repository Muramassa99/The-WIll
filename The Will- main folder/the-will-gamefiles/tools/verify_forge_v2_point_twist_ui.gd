extends SceneTree

const UI_SCENE = preload("res://scenes/ui_v2/crafting_bench_ui_v2.tscn")
const CONTROLLER = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const KEYBINDINGS = preload("res://runtime/forge_v2/forge_v2_keybinding_state.gd")
const PROFILE_LIBRARY = preload("res://core/models/player_tool_profile_library_state.gd")
const DEFAULT_REPORT := "C:/WORKSPACE/test_artifacts/forge_v2_point_twist_ui_20261017.json"

var checks: Array[Dictionary] = []
var failure_count := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var controller := CONTROLLER.new()
	root.add_child(controller)
	var ui := UI_SCENE.instantiate() as CanvasLayer
	var keys := KEYBINDINGS.new()
	keys.save_file_path = "user://twist_ui_test/keybindings.json"
	var profiles := PROFILE_LIBRARY.new()
	profiles.save_file_path = "user://twist_ui_test/profiles.tres"
	ui.set("keybinding_state", keys)
	ui.set("tool_profile_library_state", profiles)
	root.add_child(ui)
	await process_frame
	ui.call("open_for", null, controller, "Point Twist UI Verify", null)
	var state := controller.get_active_authoring_state() as Resource
	state.call("reset_active_basic_profile_builder")
	controller.set_active_tool_id(&"tool_spline_line")
	controller.append_spline_line_point(Vector3(0, 0, -0.1), Vector3.UP)
	controller.select_spline_line_point(0)
	var degree_box := ui.get("spline_roll_degrees_spin_box") as SpinBox
	var turns_box := ui.get("spline_roll_twist_spin_box") as SpinBox
	_check(degree_box.allow_greater and degree_box.allow_lesser, "single point has no false density cap")
	_check(is_finite(degree_box.min_value) and is_finite(degree_box.max_value), "single point UI range remains finite")
	degree_box.value = 2500.0
	_check(_roll(state, 0) == 2500.0 and degree_box.value == 2500.0, "single point accepts an unwrapped total beyond one turn")
	turns_box.value += turns_box.step
	_check(_roll(state, 0) == 2501.0, "Twist arrow increment changes one whole degree")
	degree_box.value = 0.0
	for position: Vector3 in [Vector3.ZERO, Vector3(0, 0, 0.1)]:
		controller.append_spline_line_point(position, Vector3.UP)
	controller.select_spline_line_point(0)
	await process_frame
	_check((state.get("spline_line_points") as PackedVector3Array).size() == 3, "three authored points")
	_check((ui.get("spline_roll_controls") as Control).visible, "selected point controls are visible")
	var space := _space_event()
	var reverse := _space_event(true)
	for expected_index: int in [1, 2, 0]:
		ui.call("_input", space)
		_check(int(state.get("selected_spline_point_index")) == expected_index, "Space placement-order loop %d" % expected_index)
	for expected_index: int in [2, 1, 0]:
		ui.call("_input", reverse)
		_check(int(state.get("selected_spline_point_index")) == expected_index, "Shift Space reverse loop %d" % expected_index)
	var echo := _space_event()
	echo.echo = true
	ui.call("_input", echo)
	_check(int(state.get("selected_spline_point_index")) == 0, "held Space does not repeat")
	degree_box.get_line_edit().grab_focus()
	await process_frame
	_check(root.gui_get_focus_owner() == degree_box.get_line_edit(), "numeric text focus established")
	ui.call("_input", space)
	_check(int(state.get("selected_spline_point_index")) == 0, "Space leaves text input alone")
	root.gui_release_focus()
	controller.select_spline_line_point(1)
	degree_box.value = 810.0
	_check(_roll(state, 1) == 810.0 and is_equal_approx(turns_box.value, 2.25), "degree signal updates Twist as the same total")
	turns_box.value = -1.25
	_check(_roll(state, 1) == -450.0 and degree_box.value == -450.0, "Twist signal updates negative total degrees")
	turns_box.value = 0.25
	_check(_roll(state, 1) == 90.0 and degree_box.value == 90.0, "fractional turn means ninety degrees")
	_check(_roll(state, 0) == 0.0 and _roll(state, 2) == 0.0, "numeric edits preserve neighbouring totals")
	var limits: Vector2 = state.call("get_spline_line_point_roll_limits", 1) as Vector2
	degree_box.value = limits.y + 10000.0
	_check(_roll(state, 1) == limits.y, "numeric field respects adjacent spacing cap")
	degree_box.value = 350.0
	var preview := ui.get("workspace_preview") as Node3D
	var camera := preview.get("camera") as Camera3D
	camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 1.0))
	camera.fov = 45.0
	await process_frame
	var frame: Dictionary = preview.call("get_spline_roll_gizmo") as Dictionary
	if not _check(bool(frame.get("valid", false)), "real presenter supplies rod frame"):
		await _finish(ui, controller)
		return
	var start_screen := _project(preview, frame.get("handle_position", Vector3.ZERO) as Vector3)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start_screen
	var history_before := int(controller.get_action_history_summary().get("undo_count", 0))
	ui.call("_handle_workspace_mouse_button", press)
	if not _check(bool(ui.get("workspace_spline_roll_drag_active")), "actual rod hit begins twist gesture"):
		await _finish(ui, controller)
		return
	var active_capture := OS.get_environment("THE_WILL_TWIST_UI_SCREENSHOT").strip_edges()
	if not active_capture.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(active_capture.get_basename() + "_selected.png")
	var center: Vector3 = frame.get("center", Vector3.ZERO) as Vector3
	var axis_x: Vector3 = frame.get("axis_x", Vector3.RIGHT) as Vector3
	var axis_y: Vector3 = frame.get("axis_y", Vector3.UP) as Vector3
	var radius := float(frame.get("radius_meters", 0.1))
	var last_screen := start_screen
	for step_index in range(1, 9):
		var authored_degrees := 350.0 + float(step_index) * 60.0
		var phase := -deg_to_rad(authored_degrees)
		last_screen = _project(preview, center + radius * (axis_x * cos(phase) + axis_y * sin(phase)))
		var motion := InputEventMouseMotion.new()
		motion.position = last_screen
		ui.call("_handle_workspace_mouse_motion", motion)
		_check(absf(_roll(state, 1) - authored_degrees) < 0.1, "projected tangent drag preserves total at %d degrees" % roundi(authored_degrees))
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = last_screen
	ui.call("_handle_workspace_mouse_button", release)
	_check(not bool(ui.get("workspace_spline_roll_drag_active")), "release finishes rod gesture")
	_check(int(controller.get_action_history_summary().get("undo_count", 0)) == history_before + 1, "multiple drag updates create one undo record")
	_check(controller.undo_latest_action() and _roll(state, 1) == 350.0, "one undo restores gesture start")
	_check(controller.redo_latest_action() and _roll(state, 1) == 830.0, "redo restores unwrapped multi-turn total")
	_check(_roll(state, 0) == 0.0 and _roll(state, 2) == 0.0, "drag preserves neighbouring totals")
	_check(is_equal_approx(turns_box.value, 830.0 / 360.0), "drag total stays synchronized in Twist field")
	var points_before: PackedVector3Array = state.get("spline_line_points") as PackedVector3Array
	_check(points_before == PackedVector3Array([Vector3(0, 0, -0.1), Vector3.ZERO, Vector3(0, 0, 0.1)]), "rod drag does not move the spine")
	# Both authoring tools use the same input, without enabling it for strokes.
	controller.set_active_tool_id(&"tool_handles")
	controller.select_spline_line_point(0)
	ui.call("_input", space)
	_check(int(state.get("selected_spline_point_index")) == 1, "Handles uses the same Space selection")
	controller.set_active_tool_id(&"tool_volume_stroke")
	ui.call("_input", space)
	_check(int(state.get("selected_spline_point_index")) == 1, "stroke tool does not cycle spline points")
	controller.set_active_tool_id(&"tool_spline_line")
	state.call("reset_active_basic_profile_builder")
	controller.set_active_tool_id(&"tool_spline_line")
	controller.select_spline_line_point(1)
	ui.call("_open_profile_builder_popup")
	await process_frame
	var profile_preview := ui.get("profile_builder_preview") as Control
	var profile_popup := ui.get("profile_builder_popup") as PopupPanel
	profile_popup.grab_focus()
	await process_frame
	_check(profile_popup.visible, "real profile popup is open")
	_check(not bool(ui.call("_try_handle_spline_point_cycle_input", space)), "visible profile excludes 3D point cycling")
	profile_preview.call("pan_metric_view_by", Vector2(31, 23))
	var before_center: Dictionary = profile_preview.call("get_metric_view_state") as Dictionary
	_check(not (before_center.get("view_center_profile_meters", Vector2.ZERO) as Vector2).is_zero_approx(), "profile fixture is panned")
	var handled := bool(ui.call("_handle_profile_builder_metric_view_input", space, profile_preview.size * 0.5))
	var after_center: Dictionary = profile_preview.call("get_metric_view_state") as Dictionary
	_check(handled and (after_center.get("view_center_profile_meters", Vector2.ONE) as Vector2).is_zero_approx(), "2D Space recenter remains functional")
	_check(int(state.get("selected_spline_point_index")) == 1, "profile recenter leaves selected 3D point unchanged")
	ui.call("_close_profile_builder_popup")
	await process_frame
	var screenshot_path := OS.get_environment("THE_WILL_TWIST_UI_SCREENSHOT").strip_edges()
	if not screenshot_path.is_empty() and DisplayServer.get_name() != "headless":
		# The drag proof looks directly down the rotation axis. Use an oblique
		# inspection view for the artifact so all three dots and both rails show.
		camera.global_position = Vector3(0.40, 0.22, 0.38)
		camera.look_at(Vector3.ZERO, Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		_check(screenshot != null and screenshot.save_png(screenshot_path) == OK, "requested rendered UI screenshot saved")
	await _finish(ui, controller)

func _space_event(reverse: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	event.shift_pressed = reverse
	return event

func _project(preview: Node3D, local_position: Vector3) -> Vector2:
	var result: Dictionary = preview.call("project_workspace_local_to_screen", local_position) as Dictionary
	return result.get("screen_position", Vector2.ZERO) as Vector2

func _roll(state: Resource, point_index: int) -> float:
	return float(state.call("get_spline_line_point_roll_degrees", point_index))

func _check(condition: bool, label: String) -> bool:
	checks.append({"label": label, "passed": condition})
	if not condition:
		failure_count += 1
		printerr("FAIL: ", label)
	return condition

func _finish(ui: CanvasLayer, controller: Node) -> void:
	var report_path := OS.get_environment("THE_WILL_TWIST_UI_REPORT").strip_edges()
	if report_path.is_empty():
		report_path = DEFAULT_REPORT
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var report := {"ok": failure_count == 0, "passed": checks.size() - failure_count, "failed": failure_count, "checks": checks}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("FORGE_TWIST_UI: ", JSON.stringify({"ok": report.ok, "passed": report.passed, "failed": report.failed, "report": report_path}))
	ui.call("close_ui")
	ui.queue_free()
	controller.queue_free()
	await process_frame
	quit(0 if failure_count == 0 else 1)
