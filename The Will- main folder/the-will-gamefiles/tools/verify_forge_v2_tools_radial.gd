extends SceneTree

## Presenter-only checks. Q/V keys, release, Escape and authoring commands belong
## to the owning UI verifier; this script never changes saved player state.
const RADIAL = preload("res://runtime/forge_v2/forge_v2_radial_menu.gd")
const DEFAULT_REPORT := "C:/WORKSPACE/test_artifacts/forge_v2_tools_radial_20261018.json"
const EPSILON := 0.0001

var radial: Control
var checks: Array[Dictionary] = []
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(640, 480)
	radial = RADIAL.new()
	root.add_child(radial)
	radial.size = Vector2(640, 480)
	await process_frame
	_test_tool_targets()
	await process_frame
	_test_reopen_and_entry_ownership()
	await _test_edges_and_resize()
	_test_view_compatibility()
	await process_frame
	await _capture()
	radial.queue_free()
	await process_frame
	_finish()


func _tool_entries() -> Array[Dictionary]:
	return [
		{"id": &"tool_volume_stroke", "label": "CSG Stroke", "icon": &"tool_stroke"},
		{"id": &"tool_spline_line", "label": "Spline Line", "icon": &"tool_spline"},
		{"id": &"tool_handles", "label": "Handles", "icon": &"tool_handle"},
		{"id": &"tool_detailing_brush", "label": "Detailing", "icon": &"tool_detail"},
	]


func _operation_entries(remove_selected: bool = false) -> Array[Dictionary]:
	return [
		{"id": &"add", "label": "Add", "selected": not remove_selected},
		{"id": &"remove", "label": "Remove", "selected": remove_selected},
	]


func _view_entries() -> Array[Dictionary]:
	return [
		{"id": &"top", "label": "Top", "normal": Vector3.UP},
		{"id": &"right", "label": "Right", "normal": Vector3.RIGHT},
		{"id": &"back", "label": "Back", "normal": Vector3.FORWARD},
		{"id": &"bottom", "label": "Bottom", "normal": Vector3.DOWN},
		{"id": &"left", "label": "Left", "normal": Vector3.LEFT},
		{"id": &"front", "label": "Front", "normal": Vector3.BACK},
	]


func _test_tool_targets() -> void:
	var tools := _tool_entries()
	radial.call("open_at", Vector2(320, 240), tools, _operation_entries())
	_check(radial.visible, "tool wheel opens")
	_check(radial.mouse_filter == Control.MOUSE_FILTER_IGNORE and radial.focus_mode == Control.FOCUS_NONE,
		"visual selector leaves input and focus ownership with the UI")
	_check(_selected() == &"add", "opening without movement preserves selected Add operation")
	var center := _center()
	var outer := _outer()
	var inner := _inner()
	_check((radial.get("_entries") as Array).size() == 4 and (radial.get("_center_entries") as Array).size() == 2,
		"tool wheel has four outer and two inner entries")
	for index in tools.size():
		var direction := Vector2.from_angle(-PI * 0.5 + float(index) * PI * 0.5)
		_expect_pointer(center + direction * (inner + outer) * 0.5, tools[index]["id"],
			String(tools[index]["id"]) + " is selectable in its outer direction")
		_expect_pointer(center + direction * (outer + 1.0), &"",
			String(tools[index]["id"]) + " cancels beyond the visible outer circle")
	_expect_pointer(center + Vector2.LEFT * inner * 0.6, &"add", "center left selects Add")
	_expect_pointer(center + Vector2.RIGHT * inner * 0.6, &"remove", "center right selects Remove")
	_expect_pointer(center + Vector2(-0.5, -0.5) * inner, &"add", "upper left center selects Add")
	_expect_pointer(center + Vector2(0.5, 0.5) * inner, &"remove", "lower right center selects Remove")
	_expect_pointer(center + Vector2.LEFT * 0.1, &"add", "no central dead zone on Add side")
	_expect_pointer(center + Vector2.RIGHT * 0.1, &"remove", "no central dead zone on Remove side")
	_expect_pointer(center + Vector2.LEFT * inner, &"add", "left inner boundary belongs to Add")
	_expect_pointer(center + Vector2.RIGHT * inner, &"remove", "right inner boundary belongs to Remove")
	_expect_pointer(center + Vector2.RIGHT * (inner + 0.1), &"tool_spline_line", "past inner boundary selects outer tool")
	_expect_pointer(center + Vector2.UP * outer, &"tool_volume_stroke", "outer boundary remains selectable")
	_expect_pointer(center, &"add", "exact center preserves selected Add operation")
	radial.call("open_at", center, tools, _operation_entries(true))
	_check(_selected() == &"remove", "opening without movement preserves selected Remove operation")
	_expect_pointer(center + Vector2.UP * inner * 0.5, &"remove", "center divider retains current Remove operation")
	_expect_pointer(center + Vector2.LEFT * inner * 0.5, &"add", "current Remove does not override explicit Add target")
	var unspecified: Array[Dictionary] = [{"id": &"add", "label": "Add"}, {"id": &"remove", "label": "Remove"}]
	radial.call("open_at", center, tools, unspecified)
	_check(_selected() == &"add", "unspecified current operation defaults to left center entry")


func _test_reopen_and_entry_ownership() -> void:
	var tools := _tool_entries()
	var operations := _operation_entries(true)
	radial.call("open_at", Vector2(320, 240), tools, operations)
	tools[0]["id"] = &"changed_after_open"
	operations[1]["id"] = &"changed_after_open"
	_expect_pointer(_center(), &"remove", "inner entry identity is copied on open")
	_expect_pointer(_center() + Vector2.UP * _outer() * 0.7, &"tool_volume_stroke", "outer entry identity is copied on open")
	radial.call("open_at", Vector2(400, 300), _tool_entries(), _operation_entries(true))
	_check(_selected() == &"remove" and _center().is_equal_approx(Vector2(400, 300)),
		"reopening repositions and resets old outer selection to current operation")
	radial.call("close_menu")
	_check(not radial.visible and _selected() == &"", "close hides wheel and clears selected action")
	_check((radial.get("_entries") as Array).is_empty() and (radial.get("_center_entries") as Array).is_empty(),
		"close drops both entry collections")
	_expect_pointer(Vector2.ZERO, &"", "pointer updates after close cannot revive an action")
	var invalid_left: Array[Dictionary] = [{"label": "No action"}, {"id": &"remove", "label": "Remove"}]
	radial.call("open_at", Vector2(320, 240), _tool_entries(), invalid_left)
	_expect_pointer(_center() + Vector2.LEFT * 20.0, &"", "invalid left center entry is inert")
	_expect_pointer(_center() + Vector2.RIGHT * 20.0, &"remove", "invalid left entry does not shift right action to left")
	var empty: Array[Dictionary] = []
	radial.call("open_at", Vector2.ZERO, empty, _operation_entries())
	_check(not radial.visible and _selected() == &"", "empty outer configuration cannot expose a stale action")


func _test_edges_and_resize() -> void:
	for dimensions: Vector2 in [Vector2(640, 480), Vector2(180, 120), Vector2(36, 24)]:
		radial.size = dimensions
		await process_frame
		for corner: Vector2 in [Vector2.ZERO, Vector2(dimensions.x, 0), dimensions, Vector2(0, dimensions.y)]:
			radial.call("open_at", corner, _tool_entries(), _operation_entries(true))
			var center := _center()
			var radius := _outer()
			var label := "%s at %s" % [dimensions, corner]
			_check(center.x - radius >= -EPSILON and center.y - radius >= -EPSILON
				and center.x + radius <= dimensions.x + EPSILON and center.y + radius <= dimensions.y + EPSILON,
				label + " keeps the full wheel inside its control")
			_check(_selected() == &"remove", label + " clamping preserves current operation on open")
			_expect_pointer(center + Vector2.LEFT * _inner() * 0.6, &"add", label + " retains left center hit testing")
			_expect_pointer(center + Vector2.RIGHT * _inner() * 0.6, &"remove", label + " retains right center hit testing")
			_expect_pointer(center + Vector2.UP * radius * 0.7, &"tool_volume_stroke", label + " retains outer hit testing")
			_expect_pointer(center + Vector2.UP * (radius + 0.1), &"", label + " cancels immediately beyond drawn circle")
		await process_frame
	radial.size = Vector2(640, 480)
	radial.call("open_at", Vector2(630, 470), _tool_entries(), _operation_entries(true))
	radial.size = Vector2(180, 120)
	await process_frame
	_check(_selected() == &"remove", "resize before pointer movement preserves current operation")
	_expect_pointer(_center() + Vector2.LEFT * _inner() * 0.6, &"add", "resized open wheel uses refreshed center for Add")
	radial.size = Vector2.ZERO
	await process_frame
	_expect_pointer(Vector2.ZERO, &"", "zero-sized wheel has no selectable target")
	radial.size = Vector2(640, 480)


func _test_view_compatibility() -> void:
	var views := _view_entries()
	# Intentionally exercise the existing two-argument API after a tool wheel.
	radial.call("open_at", Vector2(320, 240), views)
	_check(radial.visible and _selected() == &"", "original view API opens with no selected face")
	_check((radial.get("_center_entries") as Array).is_empty(), "view open drops previous tool operation entries")
	_check(is_equal_approx(_outer(), 150.0) and is_equal_approx(_inner(), 45.0), "view wheel radii use the shared 1.5 scale")
	var center := _center()
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_expect_pointer(center + direction * _inner() * 0.8, &"", "view center still cancels at " + str(direction))
	for index in views.size():
		var direction := Vector2.from_angle(-PI * 0.5 + float(index) * TAU / float(views.size()))
		_expect_pointer(center + direction * _outer() * 0.66, views[index]["id"], String(views[index]["id"]) + " view direction unchanged")
		_expect_pointer(center + direction * _outer() * 1.5, views[index]["id"], String(views[index]["id"]) + " view hold remains directional outside ring")
	radial.call("open_at", Vector2.ZERO, views)
	_check(_selected() == &"", "clamped view open never automatically selects a face")
	radial.size = Vector2(180, 120)
	_check(_selected() == &"", "view resize before movement still cancels")
	radial.call("close_menu")
	_check(_selected() == &"", "closing view wheel clears the last face")
	radial.size = Vector2(640, 480)


func _capture() -> void:
	var path := OS.get_environment("THE_WILL_TOOLS_RADIAL_SCREENSHOT")
	if path.is_empty() or DisplayServer.get_name() == "headless":
		return
	radial.call("open_at", Vector2(320, 240), _tool_entries(), _operation_entries())
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_check(root.get_texture().get_image().save_png(path) == OK, "rendered tool wheel capture saved")


func _center() -> Vector2:
	return radial.get("_center") as Vector2


func _outer() -> float:
	return float(radial.get("_outer_radius"))


func _inner() -> float:
	return float(radial.get("_inner_radius"))


func _selected() -> StringName:
	return StringName(radial.call("get_selected_id"))


func _expect_pointer(position: Vector2, expected: StringName, label: String) -> void:
	radial.call("update_pointer", position)
	_check(_selected() == expected, label)


func _check(condition: bool, label: String) -> void:
	checks.append({"label": label, "passed": condition})
	if not condition:
		failures += 1
		printerr("FAIL: ", label)


func _finish() -> void:
	var report := OS.get_environment("THE_WILL_TOOLS_RADIAL_REPORT")
	if report.is_empty():
		report = DEFAULT_REPORT
	DirAccess.make_dir_recursive_absolute(report.get_base_dir())
	var file := FileAccess.open(report, FileAccess.WRITE)
	if file == null:
		_check(false, "report file opens for writing")
	else:
		file.store_string(JSON.stringify({"ok": failures == 0, "passed": checks.size() - failures,
			"failed": failures, "checks": checks, "scope": "radial presenter; owning UI input is verified separately"}, "\t"))
		file.close()
	print("FORGE_TOOLS_RADIAL: ", JSON.stringify({"ok": failures == 0, "passed": checks.size() - failures,
		"failed": failures, "report": report}))
	quit(0 if failures == 0 else 1)
