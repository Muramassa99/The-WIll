extends SceneTree

const UI_SCENE = preload("res://scenes/ui_v2/crafting_bench_ui_v2.tscn")
const CONTROLLER = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const KEYBINDINGS = preload("res://runtime/forge_v2/forge_v2_keybinding_state.gd")
const PROFILE_LIBRARY = preload("res://core/models/player_tool_profile_library_state.gd")
const REPORT := "C:/WORKSPACE/test_artifacts/forge_v2_axis_indicator_20261017.json"
const SCREENSHOT := "C:/WORKSPACE/test_artifacts/forge_v2_axis_indicator_20261017.png"
const AXES := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
# Expected coordinates of workspace +X/+Y/+Z as seen from each face.
const FACE_AXES := {
	&"front": [Vector3.RIGHT, Vector3.UP, Vector3.BACK],
	&"back": [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
	&"right": [Vector3.BACK, Vector3.UP, Vector3.LEFT],
	&"left": [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	&"top": [Vector3.RIGHT, Vector3.BACK, Vector3.DOWN],
	&"bottom": [Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
}
var ui: CanvasLayer
var controller: Node
var state: Resource
var preview: Node3D
var camera: Camera3D
var indicator: Control
var pivot: Node3D
var indicator_viewport: SubViewport
var checks: Array[Dictionary] = []
var evidence: Dictionary = {}
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	controller = CONTROLLER.new()
	root.add_child(controller)
	ui = UI_SCENE.instantiate() as CanvasLayer
	var keys := KEYBINDINGS.new()
	keys.save_file_path = "user://axis_indicator_test/keybindings.json"
	var profiles := PROFILE_LIBRARY.new()
	profiles.save_file_path = "user://axis_indicator_test/profiles.tres"
	ui.set("keybinding_state", keys)
	ui.set("tool_profile_library_state", profiles)
	root.add_child(ui)
	await process_frame
	ui.call("open_for", null, controller, "Workspace Axis Indicator Verify", null)
	state = controller.call("get_active_authoring_state") as Resource
	controller.call("set_active_tool_id", &"tool_spline_line")
	controller.call("append_spline_line_point", Vector3(-0.12, 0.03, -0.04), Vector3.UP)
	controller.call("append_spline_line_point", Vector3(0.14, 0.05, 0.06), Vector3.UP)
	await process_frame
	if not _check(DisplayServer.get_name() != "headless", "diagnostic uses an actual renderer"):
		await _finish()
		return
	if not _read_bindings():
		await _finish()
		return
	await _draw_frame()
	var points := (state.get("spline_line_points") as PackedVector3Array).duplicate()
	var timestamp := float(state.get("updated_timestamp"))
	var history := _history()
	_check(indicator.is_visible_in_tree(), "passive indicator visible inside actual Forge workspace")
	_check(indicator.get("source_camera") == camera and indicator.get("workspace_root") == preview, "indicator binds the current workspace and camera")
	_check(indicator.mouse_filter == Control.MOUSE_FILTER_IGNORE, "indicator does not intercept workspace mouse input")
	var textures := indicator.find_children("*", "TextureRect", true, false)
	_check(textures.size() == 1 and (textures[0] as TextureRect).texture != null, "own viewport is displayed through one textured control")
	for texture: TextureRect in textures:
		_check(texture.mouse_filter == Control.MOUSE_FILTER_IGNORE, "viewport texture is also passive to mouse input")
	_check(indicator.find_children("*", "SubViewportContainer", true, false).is_empty(), "indicator has no interactive SubViewportContainer")
	var visible_meshes := 0
	for mesh: MeshInstance3D in pivot.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh != null and mesh.is_visible_in_tree():
			visible_meshes += 1
	_check(visible_meshes > 0, "existing orientation asset contains visible mesh geometry")
	evidence["visible_mesh_count"] = visible_meshes
	_check_corner("initial")
	await _test_orientation()
	await _test_idle_and_lifecycle()
	root.size = Vector2i(1024, 720)
	for _frame in range(3):
		await _draw_frame()
	_check_corner("resized")
	_check(indicator_viewport.size.x >= 2 and indicator_viewport.size.y >= 2, "resized indicator retains a drawable viewport")
	_check((state.get("spline_line_points") as PackedVector3Array) == points, "indicator and view lifecycle preserve authored geometry")
	_check(float(state.get("updated_timestamp")) == timestamp and _history() == history, "indicator creates no authored dirty state or history")
	preview.call("reset_view")
	preview.call("orbit_by", Vector2(-58, 18))
	preview.call("zoom_by", 1.5 - camera.position.z)
	await _draw_frame()
	_check(_orientation_error() < 0.0001, "final oblique orientation follows camera")
	var screenshot := OS.get_environment("THE_WILL_AXIS_INDICATOR_SCREENSHOT").strip_edges()
	if screenshot.is_empty():
		screenshot = SCREENSHOT
	DirAccess.make_dir_recursive_absolute(screenshot.get_base_dir())
	_check(root.get_texture().get_image().save_png(screenshot) == OK, "oblique rendered screenshot saved")
	evidence["screenshot"] = screenshot
	await _finish()


func _read_bindings() -> bool:
	preview = ui.get("workspace_preview") as Node3D
	indicator = ui.get("workspace_axis_indicator") as Control
	if not _check(preview != null and indicator != null, "actual UI exposes workspace and axis indicator"):
		return false
	camera = preview.get("camera") as Camera3D
	pivot = indicator.get("gizmo_pivot") as Node3D
	indicator_viewport = indicator.get("viewport_3d") as SubViewport
	return _check(camera != null and pivot != null and indicator_viewport != null, "indicator owns valid camera-relative geometry and viewport")


func _test_orientation() -> void:
	for face: StringName in FACE_AXES:
		preview.call("set_axis_view", face)
		var deadline := Time.get_ticks_msec() + 10000
		var max_error := 0.0
		var moving_frames := 0
		while bool(preview.call("is_view_transitioning")) and Time.get_ticks_msec() < deadline:
			# Observe after all viewports draw: a process-frame sample can precede
			# the camera Tween and would incorrectly accept a frame of lag.
			await _draw_frame()
			max_error = maxf(max_error, _orientation_error())
			moving_frames += 1
		await _draw_frame()
		_check(not bool(preview.call("is_view_transitioning")), String(face) + " camera transition completes")
		_check(max_error < 0.0001, String(face) + " indicator tracks current rendered camera throughout transition")
		var expected: Array = FACE_AXES[face]
		var final_error := 0.0
		for index in range(3):
			final_error = maxf(final_error, (pivot.basis * AXES[index]).distance_to(expected[index]))
		_check(final_error < 0.0001, String(face) + " shows independently expected signed workspace axes")
		evidence[String(face)] = {"moving_frames": moving_frames, "max_frame_error": max_error, "final_axis_error": final_error}
	preview.call("orbit_by", Vector2(21, -12))
	await _draw_frame()
	_check(_orientation_error() < 0.0001, "ordinary free orbit updates indicator orientation")


func _test_idle_and_lifecycle() -> void:
	await _draw_frame()
	_check(_render_idle(), "one rendered update returns to disabled")
	evidence["idle_update_modes"] = {"node_requested_mode": indicator_viewport.render_target_update_mode,
		"renderer_actual_mode": RenderingServer.viewport_get_update_mode(indicator_viewport.get_viewport_rid())}
	var before := pivot.basis
	preview.call("pan_by", Vector2(32, -19))
	preview.call("zoom_by", -0.1)
	await _draw_frame()
	_check(pivot.basis.is_equal_approx(before), "pan and zoom leave orientation unchanged")
	_check(_render_idle(), "pan and zoom do not keep indicator rendering")
	for _frame in range(3):
		await _draw_frame()
	_check(_render_idle(), "stationary visible indicator stays idle")
	ui.call("close_ui")
	await _draw_frame()
	_check(not indicator.is_visible_in_tree() and _render_idle(), "closing Forge hides and stops indicator rendering")
	preview.call("orbit_by", Vector2(27, 8))
	await _draw_frame()
	_check(_render_idle(), "hidden indicator remains idle while source orientation changes")
	ui.call("open_for", null, controller, "Workspace Axis Indicator Verify", null)
	await _draw_frame()
	if not _read_bindings():
		return
	await _draw_frame()
	_check(indicator.is_visible_in_tree() and _orientation_error() < 0.0001, "reopening binds and redraws current orientation")
	_check(_render_idle(), "reopened indicator returns to idle after drawing")


func _render_idle() -> bool:
	# The node caches the requested UPDATE_ONCE value; the rendering server owns
	# its automatic transition to DISABLED. Query actual state only in this test.
	return RenderingServer.viewport_get_update_mode(indicator_viewport.get_viewport_rid()) == RenderingServer.VIEWPORT_UPDATE_DISABLED


func _orientation_error() -> float:
	var maximum := 0.0
	var right := camera.global_basis.x.normalized()
	var up := camera.global_basis.y.normalized()
	var back := camera.global_basis.z.normalized()
	for axis: Vector3 in AXES:
		var world_axis := (preview.global_basis * axis).normalized()
		var projected := Vector3(world_axis.dot(right), world_axis.dot(up), world_axis.dot(back))
		maximum = maxf(maximum, (pivot.basis * axis).distance_to(projected))
	return maximum


func _check_corner(label: String) -> void:
	var workspace := ui.get("workspace_view_container") as Control
	_check(indicator.get_parent() == workspace, label + " indicator is anchored to actual preview, not outer panel")
	_check(indicator.size.distance_to(Vector2(86, 86)) < 0.01, label + " indicator retains compact 86-pixel dimensions")
	var gap := workspace.size - indicator.position - indicator.size
	_check(gap.distance_to(Vector2(12, 12)) < 0.01, label + " indicator remains pinned twelve pixels from lower-right corner")
	_check(Rect2(Vector2.ZERO, workspace.size).encloses(indicator.get_rect()), label + " indicator remains inside preview bounds")


func _draw_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw


func _history() -> int:
	return int((controller.call("get_action_history_summary") as Dictionary).get("undo_count", 0))


func _check(condition: bool, label: String) -> bool:
	checks.append({"label": label, "passed": condition})
	if not condition:
		failures += 1
		printerr("FAIL: ", label)
	return condition


func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(REPORT.get_base_dir())
	var result := {"ok": failures == 0, "passed": checks.size() - failures, "failed": failures, "checks": checks, "evidence": evidence}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	print("FORGE_AXIS_INDICATOR: ", JSON.stringify({"ok": failures == 0, "passed": checks.size() - failures, "failed": failures, "report": REPORT}))
	ui.call("close_ui")
	ui.queue_free()
	controller.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
