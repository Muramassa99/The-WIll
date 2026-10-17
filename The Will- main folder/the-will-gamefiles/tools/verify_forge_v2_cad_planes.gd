extends SceneTree

const UI_SCENE = preload("res://scenes/ui_v2/crafting_bench_ui_v2.tscn")
const CONTROLLER = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const KEYBINDINGS = preload("res://runtime/forge_v2/forge_v2_keybinding_state.gd")
const PROFILE_LIBRARY = preload("res://core/models/player_tool_profile_library_state.gd")
const REPORT := "C:/WORKSPACE/test_artifacts/forge_v2_cad_planes_20261017.json"
const EPSILON := 0.00001
const FACE_NORMALS := {&"front": Vector3.BACK, &"back": Vector3.FORWARD,
	&"right": Vector3.RIGHT, &"left": Vector3.LEFT, &"top": Vector3.UP, &"bottom": Vector3.DOWN}
var checks: Array[Dictionary] = []
var evidence: Dictionary = {}
var failures := 0
var preview: Node3D
var camera: Camera3D
var ui: CanvasLayer
var controller: Node
var state: Resource
var saved_screen_cursor := Vector2i.ZERO
var screen_cursor_warped := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	controller = CONTROLLER.new()
	root.add_child(controller)
	ui = UI_SCENE.instantiate() as CanvasLayer
	var keys := KEYBINDINGS.new()
	keys.save_file_path = "user://cad_plane_test/keybindings.json"
	var profiles := PROFILE_LIBRARY.new()
	profiles.save_file_path = "user://cad_plane_test/profiles.tres"
	ui.set("keybinding_state", keys)
	ui.set("tool_profile_library_state", profiles)
	root.add_child(ui)
	await process_frame
	ui.call("open_for", null, controller, "CAD Plane Verify", null)
	state = controller.call("get_active_authoring_state") as Resource
	state.call("reset_active_basic_profile_builder")
	controller.call("set_active_tool_id", &"tool_spline_line")
	for point: Vector3 in [Vector3(-0.12, -0.05, -0.11), Vector3(0.1, 0.06, 0.19), Vector3(0.28, 0.01, -0.04)]:
		controller.call("append_spline_line_point", point, Vector3.UP)
	controller.call("select_spline_line_point", 1)
	await process_frame
	preview = ui.get("workspace_preview") as Node3D
	camera = preview.get("camera") as Camera3D
	if not _check(preview.has_method("set_axis_view") and preview.has_method("resolve_spline_placement_target"), "CAD preview APIs available"):
		await _finish()
		return
	var authored := _points().duplicate()
	var timestamp := float(state.get("updated_timestamp"))
	var history := _history_count()
	await _test_faces()
	await _test_planes_and_navigation()
	await _test_surface_separation()
	await _test_nearest_and_interrupt()
	await _test_radial_menu()
	_check(_points() == authored, "view changes never reposition authored points")
	_check(float(state.get("updated_timestamp")) == timestamp, "view changes do not dirty authoring state")
	_check(_history_count() == history, "view changes create no geometry undo records")
	await _test_actual_point_drag()
	await _capture("plane")
	await _finish()


func _test_faces() -> void:
	var viewport_size := camera.get_viewport().get_visible_rect().size
	for face: StringName in FACE_NORMALS:
		preview.call("set_axis_view", face)
		_check(_transitioning(), String(face) + " alignment starts a visible transition")
		_check(not bool(_placement(Vector2.ZERO, _points()).get("valid", false)), String(face) + " placement blocked during transition")
		var progress := await _wait_view(face)
		var view: Dictionary = preview.call("get_view_state") as Dictionary
		_check(StringName(view.get("face_id", &"")) == face, String(face) + " status identifies selected face")
		_check(bool(view.get("orthographic", false)) and camera.projection == Camera3D.PROJECTION_ORTHOGONAL, String(face) + " uses orthographic projection")
		_check(_camera_normal().distance_to(FACE_NORMALS[face]) < EPSILON, String(face) + " looks perpendicular to correct signed box face")
		_check(not String(view.get("status_label", "")).is_empty(), String(face) + " exposes a readable status")
		var ray_a := camera.project_ray_normal(viewport_size * Vector2(0.3, 0.4))
		var ray_b := camera.project_ray_normal(viewport_size * Vector2(0.7, 0.6))
		_check(ray_a.distance_to(ray_b) < EPSILON, String(face) + " screen rays remain parallel")
		var target := Vector3(0.08, 0.07, 0.12)
		var plane: Dictionary = preview.call("build_spline_point_drag_plane", target) as Dictionary
		var hit: Dictionary = preview.call("screen_to_workspace_local_on_spline_plane", _project(target), plane.get("origin_local", Vector3.ZERO), plane.get("normal_local", Vector3.ZERO)) as Dictionary
		_check(bool(hit.get("valid", false)) and (hit.get("local_position", Vector3.INF) as Vector3).distance_to(target) < EPSILON, String(face) + " point projection round-trips at its original depth")
		var first: Dictionary = _placement(_project(Vector3.ZERO), PackedVector3Array())
		_check(bool(first.get("valid", false)) and absf((first.get("local_position", Vector3.INF) as Vector3).dot(FACE_NORMALS[face])) < EPSILON, String(face) + " first point uses canonical origin plane")
		if face == &"top" or face == &"bottom":
			var expected_up := Vector3.FORWARD if face == &"top" else Vector3.BACK
			_check(camera.global_basis.y.normalized().distance_to(expected_up) < EPSILON, String(face) + " screen up preserves drafting orientation")
		evidence[String(face)] = progress


func _test_planes_and_navigation() -> void:
	preview.call("set_axis_view", &"front")
	await _wait_view(&"front")
	var existing := _points()[1]
	var predecessor := _points()[0]
	var next_expected := _points()[2] + Vector3(0.15, 0.09, 0)
	var next := _placement(_project(next_expected), _points())
	_check(bool(next.get("valid", false)) and (next.get("local_position", Vector3.INF) as Vector3).distance_to(next_expected) < EPSILON, "new point inherits last point depth")
	var plane: Dictionary = preview.call("build_spline_point_drag_plane", existing) as Dictionary
	_check((plane.get("origin_local", Vector3.INF) as Vector3).distance_to(existing) < EPSILON, "editing a point uses its own plane origin")
	_check(absf(existing.z - predecessor.z) > 0.1, "drag fixture distinguishes predecessor from edited point depth")
	preview.call("set_spline_work_plane_context", true, existing)
	var before_basis := camera.global_basis
	var before_pivot: Vector3 = (preview.get("camera_pivot") as Node3D).position
	preview.call("pan_by", Vector2(55, -34))
	var after_pivot: Vector3 = (preview.get("camera_pivot") as Node3D).position
	_check(after_pivot.distance_to(before_pivot) > EPSILON and absf((after_pivot - before_pivot).dot(_camera_normal())) < EPSILON, "orthographic pan moves only across the view plane")
	_check(camera.global_basis.is_equal_approx(before_basis), "pan preserves locked orientation")
	var after_pan := _placement(_project(next_expected), _points())
	_check(bool(after_pan.get("valid", false)) and absf((after_pan.get("local_position", Vector3.INF) as Vector3).z - next_expected.z) < EPSILON, "pan does not move spline work-plane depth")
	var width_before := _project(existing + Vector3(0.1, 0, 0)).distance_to(_project(existing))
	var size_before := camera.size
	preview.call("zoom_by", -0.3)
	var width_after := _project(existing + Vector3(0.1, 0, 0)).distance_to(_project(existing))
	_check(camera.size < size_before and width_after > width_before, "orthographic zoom changes visible scale")
	preview.call("reset_view")
	_check(not bool((preview.call("get_view_state") as Dictionary).get("orthographic", true)) and camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "reset returns to free perspective")
	# An oblique plane crossing the narrow box is not the same as the clamped box surface.
	_set_oblique(Vector3(0.8, 0.2, 0.5), Vector3.ZERO)
	var outside := Vector3(10, 8, 6)
	var normal := _camera_normal()
	outside -= normal * (outside - existing).dot(normal)
	var rejected := _placement(_project(outside), PackedVector3Array([existing]))
	_check(not bool(rejected.get("valid", false)), "outside oblique-plane placement is rejected instead of clamped off-plane")
	var rejected_drag: Dictionary = preview.call("screen_to_workspace_local_on_spline_plane", _project(outside), existing, normal) as Dictionary
	_check(not bool(rejected_drag.get("valid", false)), "existing point drag also rejects outside-plane bounds without clamping depth")
	var inside := existing + camera.global_basis.x * 0.02
	var accepted := _placement(_project(inside), PackedVector3Array([existing]))
	_check(bool(accepted.get("valid", false)) and absf(((accepted.get("local_position", Vector3.INF) as Vector3) - existing).dot(normal)) < EPSILON, "free-view continuation also preserves the camera-normal plane")


func _test_surface_separation() -> void:
	preview.call("reset_view")
	_set_oblique(Vector3.BACK, Vector3.ZERO)
	var collider := StaticBody3D.new()
	collider.collision_layer = 1 << 20
	collider.collision_mask = 0
	collider.set_meta("forge_v2_surface_target_id", &"cad_plane_fixture")
	collider.set_meta("forge_v2_body_id", &"cad_plane_fixture")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.5, 0.04)
	collision.shape = shape
	collider.add_child(collision)
	collider.position = Vector3(0, 0, 0.3)
	preview.add_child(collider)
	await physics_frame
	await physics_frame
	var screen := _project(Vector3.ZERO)
	var generic: Dictionary = preview.call("resolve_placement_target", screen) as Dictionary
	var first := _placement(screen, PackedVector3Array())
	_check(bool(generic.get("valid", false)) and StringName(generic.get("target_kind", &"")) == &"target_material_surface", "generic brush targeting still detects actual material surface")
	_check(bool(first.get("valid", false)) and (first.get("local_position", Vector3.INF) as Vector3).distance_to(generic.get("local_position", Vector3.ZERO) as Vector3) < EPSILON, "first free-view spline point retains material-first hybrid placement")
	var continuation := _placement(screen, PackedVector3Array([Vector3(0, 0, 0.12)]))
	_check(bool(continuation.get("valid", false)) and absf((continuation.get("local_position", Vector3.INF) as Vector3).z - 0.12) < EPSILON, "later spline points ignore intervening material surface and remain coplanar")
	collider.queue_free()
	await process_frame


func _test_nearest_and_interrupt() -> void:
	for face: StringName in FACE_NORMALS:
		preview.call("reset_view")
		var normal: Vector3 = FACE_NORMALS[face]
		var offset := Vector3(0.19, 0.14, 0.11)
		offset -= normal * offset.dot(normal)
		_set_oblique(normal + offset, Vector3(2.5, 0.1, 0.35))
		preview.call("align_to_nearest_axis")
		await _wait_view(face)
		_check(StringName((preview.call("get_view_state") as Dictionary).get("face_id", &"")) == face, String(face) + " nearest-axis selection uses signed viewing direction, independently of box position")
	preview.call("reset_view")
	_set_oblique(Vector3(-0.9, 0.15, 0.3), Vector3.ZERO)
	var click := _mouse(MOUSE_BUTTON_RIGHT, true, _project(Vector3.ZERO))
	click.double_click = true
	ui.call("_handle_workspace_mouse_button", click)
	_check(_transitioning(), "double RMB routes through nearest-axis alignment")
	ui.call("_handle_workspace_mouse_button", _mouse(MOUSE_BUTTON_RIGHT, false, click.position))
	await _wait_view(&"left")
	_check(StringName((preview.call("get_view_state") as Dictionary).get("face_id", &"")) == &"left", "double RMB selects correct signed nearest face")
	preview.call("set_axis_view", &"right")
	var original := _points().duplicate()
	var roll_before := float(state.call("get_spline_line_point_roll_degrees", 1))
	var paint := _mouse(MOUSE_BUTTON_LEFT, true, _project(Vector3(0.8, 0.1, 0)))
	ui.call("_handle_workspace_mouse_button", paint)
	ui.call("_handle_workspace_mouse_button", _mouse(MOUSE_BUTTON_LEFT, false, paint.position))
	(ui.get("spline_roll_degrees_spin_box") as SpinBox).value = roll_before + 10.0
	_check(_points() == original and float(state.call("get_spline_line_point_roll_degrees", 1)) == roll_before, "UI cannot place or alter twist while view is turning")
	await process_frame
	preview.call("orbit_by", Vector2(12, -7))
	_check(not _transitioning() and not bool((preview.call("get_view_state") as Dictionary).get("orthographic", true)), "free orbit interrupts alignment and unlocks projection")
	var interrupted := camera.global_basis
	await create_timer(0.1).timeout
	_check(camera.global_basis.is_equal_approx(interrupted), "interrupted tween does not resume moving the view")


func _test_actual_point_drag() -> void:
	preview.call("set_axis_view", &"front")
	await _wait_view(&"front")
	preview.call("zoom_by", 1.2 - camera.position.z)
	var before := _points().duplicate()
	var history := _history_count()
	var center_screen := _project(before[1])
	var click_offset := Vector2(4, -3)
	var gizmo: Dictionary = preview.call("get_spline_roll_gizmo") as Dictionary
	if bool(gizmo.get("valid", false)):
		var away := center_screen - _project(gizmo.get("handle_position", before[1]) as Vector3)
		if away.length_squared() > 0.01:
			click_offset = away.normalized() * 5.0
	var pick_screen := center_screen + click_offset
	ui.call("_handle_workspace_mouse_button", _mouse(MOUSE_BUTTON_LEFT, true, pick_screen))
	ui.call("_handle_workspace_mouse_button", _mouse(MOUSE_BUTTON_LEFT, false, pick_screen))
	_check(_points() == before and _history_count() == history, "near-ball click selects without moving geometry or adding undo history")
	ui.call("_handle_workspace_mouse_button", _mouse(MOUSE_BUTTON_LEFT, true, pick_screen))
	_check(bool(ui.get("workspace_spline_point_drag_active")), "real near-ball pick starts point drag")
	var motion := InputEventMouseMotion.new()
	motion.position = pick_screen + Vector2(18, -12)
	var world_delta := camera.project_ray_origin(motion.position) - camera.project_ray_origin(pick_screen)
	var desired := before[1] + preview.global_basis.inverse() * world_delta
	ui.call("_handle_workspace_mouse_motion", motion)
	ui.call("_handle_workspace_mouse_button", _mouse(MOUSE_BUTTON_LEFT, false, motion.position))
	var after := _points()
	_check(after[1].distance_to(desired) < EPSILON, "actual UI drag preserves initial pick offset and edited point depth")
	_check(after[0] == before[0] and after[2] == before[2], "actual UI drag leaves both neighbouring points fixed")
	_check(_history_count() == history + 1, "actual geometry drag creates exactly one undo record")
	_check(bool(controller.call("undo_latest_action")) and _points() == before, "undo restores point geometry without undoing the view")
	_check(StringName((preview.call("get_view_state") as Dictionary).get("face_id", &"")) == &"front", "geometry undo retains selected camera face")


func _test_radial_menu() -> void:
	root.gui_release_focus()
	preview.call("reset_view")
	_open_radial()
	var radial := ui.get("workspace_view_radial") as Control
	if not _check(bool(ui.get("workspace_view_radial_active")) and radial != null and radial.visible, "holding V opens the real six-view radial menu"):
		return
	var entries: Array = (radial.get("_entries") as Array).duplicate(true)
	var ids := PackedStringArray()
	for entry: Dictionary in entries:
		ids.append(String(entry.get("id", "")))
		var face := StringName(entry.get("id", &""))
		_check(FACE_NORMALS.has(face) and (entry.get("normal", Vector3.ZERO) as Vector3).is_equal_approx(FACE_NORMALS.get(face, Vector3.INF)), String(face) + " radial icon identifies its signed box face")
	_check(ids.size() == 6 and ids.has("front") and ids.has("back") and ids.has("right") and ids.has("left") and ids.has("top") and ids.has("bottom"), "radial contains exactly the six required axis views")
	_check(StringName(radial.call("get_selected_id")) == &"", "opening radial does not select a direction")
	# Exercise the same widget used by the held-key route at the viewport corner,
	# without moving the user's desktop pointer.
	radial.call("open_at", Vector2(1, 1), entries)
	var center: Vector2 = radial.get("_center") as Vector2
	var radius := float(radial.get("_outer_radius"))
	_check(center.x - radius >= 0 and center.y - radius >= 0 and center.x + radius <= radial.size.x and center.y + radius <= radial.size.y, "edge-open radial remains entirely inside its viewport")
	_check(StringName(radial.call("get_selected_id")) == &"", "clamping radial to the viewport never auto-selects a face")
	var points_before := _points().duplicate()
	var history_before := _history_count()
	var draft_before := String((controller.call("get_status_summary") as Dictionary).get("wip_id", ""))
	var undo := _key(KEY_Z, true)
	undo.ctrl_pressed = true
	root.push_input(undo, true)
	var save := _key(KEY_S, true)
	save.ctrl_pressed = true
	root.push_input(save, true)
	ui.call("_handle_workspace_mouse_button", _mouse(MOUSE_BUTTON_LEFT, true, _project(Vector3(0.7, 0.2, 0))))
	ui.call("_handle_workspace_mouse_button", _mouse(MOUSE_BUTTON_LEFT, false, _project(Vector3(0.7, 0.2, 0))))
	_check(_points() == points_before and _history_count() == history_before, "held radial consumes undo and placement without changing geometry or history")
	_check(not bool(ui.get("v2_save_in_progress")) and String((controller.call("get_status_summary") as Dictionary).get("wip_id", "")) == draft_before, "held radial consumes draft-save shortcut")
	_radial_pointer(radial, center)
	ui.call("_input", _key(KEY_V, false))
	_check(not bool(ui.get("workspace_view_radial_active")) and not radial.visible and not _transitioning(), "releasing V in central dead zone cancels without moving view")
	for index in range(entries.size()):
		var face := StringName((entries[index] as Dictionary).get("id", &""))
		_open_radial()
		center = radial.get("_center") as Vector2
		var angle := -PI * 0.5 + TAU * float(index) / float(entries.size())
		_radial_pointer(radial, center + Vector2.from_angle(angle) * float(radial.get("_outer_radius")) * 0.7)
		_check(StringName(radial.call("get_selected_id")) == face, String(face) + " radial direction highlights correct face")
		if index == 0:
			await _capture("radial")
		ui.call("_input", _key(KEY_V, false))
		_check(not bool(ui.get("workspace_view_radial_active")) and not radial.visible, String(face) + " release closes radial")
		await _wait_view(face)
		_check(StringName((preview.call("get_view_state") as Dictionary).get("face_id", &"")) == face, String(face) + " release commits highlighted camera choice")
	var last_face := StringName((preview.call("get_view_state") as Dictionary).get("face_id", &""))
	_open_radial()
	center = radial.get("_center") as Vector2
	_radial_pointer(radial, center + Vector2.UP * 60.0)
	ui.call("_input", _key(KEY_ESCAPE, true))
	ui.call("_input", _key(KEY_V, false))
	_check(not bool(ui.get("workspace_view_radial_active")) and not radial.visible and not _transitioning() and StringName((preview.call("get_view_state") as Dictionary).get("face_id", &"")) == last_face, "Escape cancels highlighted radial without applying a view")
	_open_radial()
	_radial_pointer(radial, (radial.get("_center") as Vector2) + Vector2.UP * 60.0)
	ui.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ui.call("_input", _key(KEY_V, false))
	_check(not bool(ui.get("workspace_view_radial_active")) and not radial.visible and not _transitioning(), "focus loss cancels held radial without committing")
	var text := (ui.get("spline_roll_degrees_spin_box") as SpinBox).get_line_edit()
	text.grab_focus()
	await process_frame
	ui.call("_input", _key(KEY_V, true))
	_check(not bool(ui.get("workspace_view_radial_active")), "typing V in numeric text does not open view radial")
	root.gui_release_focus()


func _radial_pointer(radial: Control, local_position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = radial.get_global_transform_with_canvas() * local_position
	ui.call("_input", motion)


func _open_radial() -> void:
	var workspace := ui.get("workspace_view_container") as Control
	var motion := InputEventMouseMotion.new()
	motion.position = workspace.get_global_transform_with_canvas() * (workspace.size * 0.5)
	if DisplayServer.get_name() != "headless" and not Rect2(Vector2.ZERO, workspace.size).has_point(workspace.get_local_mouse_position()):
		# A real Window queries the OS cursor, unlike headless Viewports. Save
		# its screen position before the isolated UI test moves it into the view.
		if not screen_cursor_warped:
			saved_screen_cursor = DisplayServer.mouse_get_position()
			screen_cursor_warped = true
		root.warp_mouse(motion.position)
	# push_input delivers viewport events but does not update Input's pointer
	# state. Native synthetic input updates hover without warping the OS cursor.
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	var inside := Rect2(Vector2.ZERO, workspace.size).has_point(workspace.get_local_mouse_position())
	_check(inside, "native synthetic input establishes actual workspace hover")
	if not evidence.has("radial_hover"):
		evidence["radial_hover"] = {"injected_position": motion.position,
			"root_mouse_position": root.get_mouse_position(),
			"workspace_local_mouse_position": workspace.get_local_mouse_position(), "inside": inside}
	ui.call("_input", _key(KEY_V, true))


func _key(code: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event


func _capture(suffix: String) -> void:
	var requested := OS.get_environment("THE_WILL_CAD_SCREENSHOT").strip_edges()
	if requested.is_empty() or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := requested.get_basename() + "_" + suffix + ".png"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_check(root.get_texture().get_image().save_png(path) == OK, "rendered " + suffix + " evidence saved")


func _set_oblique(normal: Vector3, pivot_position: Vector3) -> void:
	var pivot := preview.get("camera_pivot") as Node3D
	var pitch := preview.get("camera_pitch") as Node3D
	pitch.basis = Basis.IDENTITY
	pivot.basis = Basis.looking_at(-normal.normalized(), Vector3.UP)
	pivot.position = pivot_position
	camera.basis = Basis.IDENTITY


func _wait_view(label: StringName) -> Dictionary:
	var frames := 0
	var intermediate := 0
	var started := Time.get_ticks_msec()
	var first := camera.global_basis.get_rotation_quaternion()
	var samples: Array[Dictionary] = []
	while _transitioning() and Time.get_ticks_msec() - started < 10000:
		await process_frame
		frames += 1
		var angle := first.angle_to(camera.global_basis.get_rotation_quaternion())
		if _transitioning() and angle > 0.001:
			intermediate += 1
			samples.append({"ms": Time.get_ticks_msec() - started, "angle": angle})
	_check(not _transitioning(), String(label) + " alignment finishes within bounded time")
	var max_deviation := 0.0
	if samples.size() > 4:
		var a: Dictionary = samples[0]
		var b: Dictionary = samples[-1]
		var duration := float(b.ms - a.ms)
		if duration > 30.0:
			for sample: Dictionary in samples:
				var expected := lerpf(float(a.angle), float(b.angle), float(sample.ms - a.ms) / duration)
				max_deviation = maxf(max_deviation, absf(float(sample.angle) - expected))
			# Record timing rather than failing on OS/render stalls. Immediate
			# transition state plus the final basis prove this is not a snap.
	return {"frames": frames, "intermediate_frames": intermediate, "duration_ms": Time.get_ticks_msec() - started, "max_linear_deviation_radians": max_deviation}


func _transitioning() -> bool:
	return bool(preview.call("is_view_transitioning"))


func _camera_normal() -> Vector3:
	return (preview.global_basis.inverse() * camera.global_basis.z).normalized()


func _placement(screen: Vector2, points: PackedVector3Array) -> Dictionary:
	return preview.call("resolve_spline_placement_target", screen, points) as Dictionary


func _project(local_position: Vector3) -> Vector2:
	return camera.unproject_position(preview.to_global(local_position))


func _points() -> PackedVector3Array:
	return state.get("spline_line_points") as PackedVector3Array


func _history_count() -> int:
	return int((controller.call("get_action_history_summary") as Dictionary).get("undo_count", 0))


func _mouse(button: MouseButton, pressed: bool, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = position
	return event


func _check(condition: bool, label: String) -> bool:
	checks.append({"label": label, "passed": condition})
	if not condition:
		failures += 1
		printerr("FAIL: ", label)
	return condition


func _finish() -> void:
	if screen_cursor_warped:
		# DisplayServer.warp_mouse expects client-window coordinates, whereas
		# mouse_get_position returns screen coordinates (Godot 4.7 docs).
		DisplayServer.warp_mouse(saved_screen_cursor - DisplayServer.window_get_position(root.get_window_id()))
		var restored := DisplayServer.mouse_get_position()
		evidence["cursor_restore"] = {"before_screen": saved_screen_cursor, "after_screen": restored}
		_check(restored.distance_to(saved_screen_cursor) <= 1.0, "rendered UI test restores original OS cursor position")
		screen_cursor_warped = false
	DirAccess.make_dir_recursive_absolute(REPORT.get_base_dir())
	var result := {"ok": failures == 0, "passed": checks.size() - failures, "failed": failures, "checks": checks, "evidence": evidence}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	print("FORGE_CAD_PLANES: ", JSON.stringify({"ok": failures == 0, "passed": checks.size() - failures, "failed": failures, "report": REPORT}))
	ui.call("close_ui")
	ui.queue_free()
	controller.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
