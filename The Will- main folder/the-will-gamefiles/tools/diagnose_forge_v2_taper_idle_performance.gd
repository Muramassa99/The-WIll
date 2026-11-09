extends SceneTree

# Real UI and normal scene processing, with isolated in-memory draft data.
# Measured phases contain only idle, pointer hover, RMB orbit or MMB pan.
# No player library is written, and there are no point/profile edits in phases.
const UI_SCENE = preload("res://scenes/ui_v2/crafting_bench_ui_v2.tscn")
const CONTROLLER = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const KEYBINDINGS = preload("res://runtime/forge_v2/forge_v2_keybinding_state.gd")
const PROFILE_LIBRARY = preload("res://core/models/player_tool_profile_library_state.gd")
const AUTHORING_STATE = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const PROFILE_SHAPES = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const DEFAULT_REPORT := "C:/WORKSPACE/godot_runs/forge_v2_taper_idle_performance.json"

var ui: CanvasLayer
var controller: Node
var workspace: Node3D
var presenter: Node3D
var signals_seen := {"authoring": 0, "body_preview": 0, "cursor": 0, "view": 0}
var failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1440, 900)
	var samples := 40
	var samples_setting := OS.get_environment("THE_WILL_TAPER_PERF_SAMPLES")
	if samples_setting.is_valid_int():
		samples = clampi(int(samples_setting), 8, 180)
	var report_path := OS.get_environment("THE_WILL_TAPER_PERF_REPORT").strip_edges()
	if report_path.is_empty():
		report_path = DEFAULT_REPORT
	var library := ResourceLoader.load(PROFILE_LIBRARY.DEFAULT_SAVE_FILE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource
	var fluted: Dictionary = {}
	var original_profiles := PackedByteArray()
	if library != null:
		original_profiles = var_to_bytes(library.get("saved_profiles"))
		for profile: Dictionary in library.get("saved_profiles"):
			if String(profile.get("label", "")).to_lower() == "fluted blade":
				fluted = profile.duplicate(true)
				break
	if fluted.is_empty():
		failures.append("The real Fluted Blade profile is unavailable.")
		_finish({"ok": false, "failures": failures}, report_path)
		return
	controller = CONTROLLER.new()
	root.add_child(controller)
	ui = UI_SCENE.instantiate() as CanvasLayer
	var keys := KEYBINDINGS.new()
	keys.save_file_path = "user://taper_navigation_profile/keybindings.json"
	var isolated_profiles := PROFILE_LIBRARY.new()
	isolated_profiles.save_file_path = "user://taper_navigation_profile/profiles.tres"
	ui.set("keybinding_state", keys)
	ui.set("tool_profile_library_state", isolated_profiles)
	root.add_child(ui)
	await process_frame
	ui.call("open_for", null, controller, "Taper navigation profile", null)
	workspace = ui.get("workspace_preview") as Node3D
	presenter = workspace.get("volume_preview_presenter") as Node3D
	controller.connect("authoring_state_changed", func(_state): signals_seen.authoring += 1)
	controller.connect("material_body_preview_changed", func(_state): signals_seen.body_preview += 1)
	controller.connect("placement_cursor_changed", func(_position, _valid, _radius): signals_seen.cursor += 1)
	workspace.connect("view_state_changed", func(): signals_seen.view += 1)
	var report := {"ok": true, "display_server": DisplayServer.get_name(),
		"engine": Engine.get_version_info(), "engine_max_fps": Engine.max_fps,
		"samples_per_phase": samples, "normal_scene_processing": true,
		"synthetic_events": "one real UI motion-handler call per frame; no held paint button",
		"cases": []}
	for transformed: bool in [false, true]:
		_setup_draft(fluted, transformed)
		_reset_camera()
		for warmup in range(8):
			await process_frame
		var state: Resource = controller.call("get_active_authoring_state")
		var case_result := {"name": "tapered" if transformed else "untapered", "phases": [], "named_calls": {}}
		for phase: String in ["idle", "hover", "orbit", "pan"]:
			case_result.phases.append(await _measure_phase(phase, samples, state))
		case_result.named_calls = _measure_named_calls(state)
		report.cases.append(case_result)
	report["correctness_outside_timing"] = await _correctness_checks(fluted)
	if var_to_bytes(library.get("saved_profiles")) != original_profiles:
		failures.append("Read-only profile library data changed.")
	report["failures"] = failures
	report["ok"] = failures.is_empty()
	ui.call("close_ui")
	ui.queue_free()
	controller.queue_free()
	await process_frame
	_finish(report, report_path)


func _setup_draft(fluted: Dictionary, transformed: bool) -> void:
	controller.call("cancel_spline_line")
	controller.call("set_active_tool_id", &"tool_spline_line")
	var state: Resource = controller.call("get_active_authoring_state")
	state.call("select_active_saved_basic_profile", fluted.duplicate(true))
	for point_index in range(5):
		controller.call("append_spline_line_point", Vector3(float(point_index) * 0.15 - 0.3, 0, 0), Vector3.UP)
	if transformed:
		for point_index in range(5):
			state.call("set_spline_line_point_profile_scale", point_index,
				Vector2.ZERO if point_index == 4 else Vector2(0.05, 0.05))
		for roles: PackedInt32Array in [PackedInt32Array([0, 1, 2]), PackedInt32Array([3, 2]), PackedInt32Array([4, 3])]:
			state.call("set_spline_line_profile_transform", roles, Vector2(2, 2))
	controller.call("select_spline_line_point", 2)
	controller.emit_signal("authoring_state_changed", state)


func _correctness_checks(fluted: Dictionary) -> Array[Dictionary]:
	var checks: Array[Dictionary] = []
	# This is separate from the unchanged navigation timing phases.
	_reset_camera()
	ui.call("_refresh_spline_roll_controls")
	var state: Resource = controller.call("get_active_authoring_state")
	var before := var_to_bytes(state.call("capture_editor_transient_snapshot"))
	var degrees := ui.get("spline_roll_degrees_spin_box") as SpinBox
	var twist := ui.get("spline_roll_twist_spin_box") as SpinBox
	_record_check(checks, degrees.editable and twist.editable, "roll controls editable before view transition")
	# This is the same set_axis_view operation selected by the V radial.
	workspace.call("set_axis_view", &"right")
	_record_check(checks, bool(workspace.call("is_view_transitioning")) and not degrees.editable and not twist.editable,
		"axis-view tween disables both roll controls immediately")
	var deadline := Time.get_ticks_msec() + 6000
	while bool(workspace.call("is_view_transitioning")) and Time.get_ticks_msec() < deadline:
		await process_frame
	_record_check(checks, not bool(workspace.call("is_view_transitioning")) and degrees.editable and twist.editable,
		"axis-view completion restores both roll controls")
	_record_check(checks, var_to_bytes(state.call("capture_editor_transient_snapshot")) == before,
		"view transition leaves authored points, roll and taper unchanged")
	var controls := PackedVector3Array([Vector3(-0.2, 0, 0), Vector3.ZERO, Vector3(0.2, 0, 0)])
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	var contacts := PackedVector3Array([Vector3.DOWN, Vector3.DOWN, Vector3.DOWN])
	for tool: StringName in [AUTHORING_STATE.TOOL_SPLINE_LINE, AUTHORING_STATE.TOOL_HANDLES, AUTHORING_STATE.TOOL_DETAILING_BRUSH]:
		controller.call("cancel_spline_line")
		controller.call("set_active_tool_id", tool)
		state = controller.call("get_active_authoring_state")
		if tool == AUTHORING_STATE.TOOL_HANDLES:
			state.call("set_active_profile_id", PROFILE_SHAPES.PROFILE_HANDLE_BUILDER)
			state.call("set_active_handle_path_mode_id", AUTHORING_STATE.HANDLE_PATH_MODE_THREE_POINT_LINEAR)
		else:
			state.call("select_active_saved_basic_profile", fluted.duplicate(true))
		if tool == AUTHORING_STATE.TOOL_DETAILING_BRUSH:
			var accepted := bool(controller.call("replace_detailing_brush_path_solution", controls, normals,
				&"target_material_surface", &"navigation_detail_fixture", controls, normals,
				PackedInt32Array([0, 1, 2]), [true, true], [&"none", &"none"], true, &"none", 1, contacts, contacts))
			_record_check(checks, accepted, "Detail direct-read fixture uses accepted resolved path")
		else:
			for point: Vector3 in controls:
				controller.call("append_spline_line_point", point, Vector3.UP)
		var summary: Dictionary = controller.call("get_status_summary")
		var expected: PackedVector3Array = summary.detailing_brush.control_points if tool == AUTHORING_STATE.TOOL_DETAILING_BRUSH else summary.spline_line.points
		_record_check(checks, (ui.call("_get_spline_points") as PackedVector3Array) == expected and expected == controls,
			String(tool) + " direct point lookup matches authoritative status data")
		if tool == AUTHORING_STATE.TOOL_DETAILING_BRUSH:
			var direct: Dictionary = ui.call("_get_detailing_brush_summary")
			var previous: Dictionary = summary.detailing_brush
			for key: String in ["control_points", "control_surface_normals", "control_contact_directions",
				"locked_target_kind", "locked_target_id", "finished"]:
				_record_check(checks, direct.has(key) and previous.has(key) and direct[key] == previous[key],
					"Detail direct input field matches full-status payload: " + key)
	_envelope_cache_checks(fluted, checks)
	return checks


func _envelope_cache_checks(fluted: Dictionary, checks: Array[Dictionary]) -> void:
	# Detached state: deliberately alter nested profile data without touching
	# the player's library or the real UI timing fixture.
	var state: Resource = AUTHORING_STATE.new()
	state.call("reset_new_draft", "Envelope cache check")
	state.call("set_active_tool_id", AUTHORING_STATE.TOOL_SPLINE_LINE)
	if not bool(state.call("select_active_saved_basic_profile", fluted.duplicate(true))):
		_record_check(checks, false, "envelope cache fixture accepts actual profile")
		return
	var original: Dictionary = (state.get("active_saved_basic_profile_data") as Dictionary).duplicate(true)
	var original_radius := _profile_radius(original)
	var first := float(state.call("get_active_deposition_envelope_radius_meters"))
	var second := float(state.call("get_active_deposition_envelope_radius_meters"))
	_record_check(checks, is_equal_approx(first, original_radius) and first == second,
		"unchanged saved profile returns its exact envelope on repeated reads")
	var changed := _resize_profile(original, 1.5)
	var live: Dictionary = state.get("active_saved_basic_profile_data")
	var live_runtime: Dictionary = live.compiled_profile
	live_runtime.merge(changed.compiled_profile, true)
	for key: Variant in changed:
		if key != "compiled_profile":
			live[key] = changed[key]
	_record_check(checks, live.get("profile_id") == original.get("profile_id")
		and PROFILE_SHAPES.is_compiled_basic_profile_runtime_valid(live),
		"same-ID nested envelope mutation remains a valid compiled profile")
	var changed_radius := float(state.call("get_active_deposition_envelope_radius_meters"))
	_record_check(checks, is_equal_approx(changed_radius, _profile_radius(changed))
		and absf(changed_radius - first) > 0.0001,
		"same-ID nested geometry change invalidates the cached envelope")
	live_runtime["valid"] = false
	state.set("active_brush_radius_meters", 0.017)
	_record_check(checks, is_equal_approx(float(state.call("get_active_deposition_envelope_radius_meters")), 0.017),
		"valid-to-invalid saved profile falls back to the current brush radius")
	state.set("active_brush_radius_meters", 0.029)
	_record_check(checks, is_equal_approx(float(state.call("get_active_deposition_envelope_radius_meters")), 0.029),
		"invalid cached profile follows later brush-radius changes")
	state.call("select_active_saved_basic_profile", original.duplicate(true))
	_record_check(checks, is_equal_approx(float(state.call("get_active_deposition_envelope_radius_meters")), original_radius),
		"restoring a valid profile replaces invalid fallback state")
	state.set("active_basic_shape_source_id", AUTHORING_STATE.BASIC_SHAPE_SOURCE_PRIMITIVE)
	state.set("active_brush_radius_meters", 0.023)
	var primitive_first := float(state.call("get_active_deposition_envelope_radius_meters"))
	state.set("active_brush_radius_meters", 0.037)
	_record_check(checks, is_equal_approx(primitive_first, 0.023)
		and is_equal_approx(float(state.call("get_active_deposition_envelope_radius_meters")), 0.037),
		"primitive mode bypasses saved-profile memo and follows current brush size")
	state.call("select_active_saved_basic_profile", original.duplicate(true))
	state.set("active_tool_id", AUTHORING_STATE.TOOL_HANDLES)
	state.set("active_brush_radius_meters", 0.031)
	_record_check(checks, is_equal_approx(float(state.call("get_active_deposition_envelope_radius_meters")), 0.031),
		"Handle tool bypasses saved-profile envelope and retains its brush radius")
	state.set("active_tool_id", AUTHORING_STATE.TOOL_SPLINE_LINE)
	var swapped := _resize_profile(original, 0.7)
	swapped["profile_id"] = &"navigation_envelope_other_profile"
	swapped["id"] = &"navigation_envelope_other_profile"
	var switched := bool(state.call("select_active_saved_basic_profile", swapped))
	_record_check(checks, switched and is_equal_approx(float(state.call("get_active_deposition_envelope_radius_meters")), _profile_radius(swapped)),
		"switching saved profiles returns the new profile's envelope")
	var private_storage := false
	for property: Dictionary in state.get_property_list():
		if String(property.name).begins_with("_deposition_envelope_cache_"):
			private_storage = private_storage or (int(property.usage) & PROPERTY_USAGE_STORAGE) != 0
	_record_check(checks, not private_storage, "envelope memo remains private nonserialized state")


func _resize_profile(source: Dictionary, factor: float) -> Dictionary:
	var resized := source.duplicate(true)
	var polygon: PackedVector2Array = resized.base_polygon_2d_meters
	for index in range(polygon.size()):
		polygon[index] *= factor
	resized["base_polygon_2d_meters"] = polygon
	resized["polygon_2d_meters"] = polygon
	resized["base_anchor_2d_meters"] = (resized.get("base_anchor_2d_meters", Vector2.ZERO) as Vector2) * factor
	return PROFILE_SHAPES.compile_basic_profile_runtime_data(resized)


func _profile_radius(profile: Dictionary) -> float:
	var radius := 0.001
	for point: Vector2 in profile.compiled_profile.deposition_polygon_2d_meters:
		radius = maxf(radius, point.length())
	return radius


func _record_check(checks: Array[Dictionary], passed: bool, label: String) -> void:
	checks.append({"ok": passed, "label": label})
	if not passed:
		failures.append(label)


func _reset_camera() -> void:
	var pivot := workspace.get("camera_pivot") as Node3D
	var pitch := workspace.get("camera_pitch") as Node3D
	var camera := workspace.get("camera") as Camera3D
	pivot.transform = Transform3D.IDENTITY
	pitch.transform = Transform3D.IDENTITY
	camera.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 1.6))
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 45.0


func _measure_phase(phase: String, samples: int, state: Resource) -> Dictionary:
	_reset_camera()
	var container := ui.get("workspace_view_container") as Control
	var pointer := container.size * Vector2(0.73, 0.72)
	var button := MOUSE_BUTTON_RIGHT if phase == "orbit" else MOUSE_BUTTON_MIDDLE
	if phase == "orbit" or phase == "pan":
		_mouse_button(button, true, pointer)
	for warmup in range(3):
		await process_frame
	var before_bytes := var_to_bytes(state.call("capture_editor_transient_snapshot"))
	var mesh_before := _mesh_ids()
	var before_signals := signals_seen.duplicate()
	var frame_times := PackedFloat64Array()
	var handler_times := PackedFloat64Array()
	var process_times := PackedFloat64Array()
	var physics_times := PackedFloat64Array()
	var draw_counts := PackedFloat64Array()
	var previous := Time.get_ticks_usec()
	for index in range(samples):
		var angle := TAU * float(index) / float(samples)
		var relative := Vector2(cos(angle) * 3.0, sin(angle) * 2.0)
		if phase != "idle":
			pointer += relative
			var event := InputEventMouseMotion.new()
			event.position = pointer
			event.relative = relative
			event.button_mask = MOUSE_BUTTON_MASK_RIGHT if phase == "orbit" else (MOUSE_BUTTON_MASK_MIDDLE if phase == "pan" else 0)
			var started := Time.get_ticks_usec()
			ui.call("_handle_workspace_mouse_motion", event)
			handler_times.append(float(Time.get_ticks_usec() - started) / 1000.0)
		await process_frame
		var current := Time.get_ticks_usec()
		frame_times.append(float(current - previous) / 1000.0)
		previous = current
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		draw_counts.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if phase == "orbit" or phase == "pan":
		_mouse_button(button, false, pointer)
	var signal_delta := {}
	for key: String in signals_seen:
		signal_delta[key] = int(signals_seen[key]) - int(before_signals[key])
	var unchanged := var_to_bytes(state.call("capture_editor_transient_snapshot")) == before_bytes
	if not unchanged:
		failures.append("Authored draft changed during navigation phase: " + phase)
	var result := {"phase": phase, "frame_ms": _stats(frame_times), "motion_handler_ms": _stats(handler_times),
		"process_monitor_ms": _stats(process_times), "physics_monitor_ms": _stats(physics_times),
		"draw_calls": _stats(draw_counts), "signals": signal_delta, "authored_data_unchanged": unchanged,
		"meshes_before": mesh_before, "meshes_after": _mesh_ids(), "raw_frame_ms": frame_times,
		"raw_motion_handler_ms": handler_times}
	print("Taper navigation %s: frame mean %.3f ms, handler mean %.3f ms" % [phase, result.frame_ms.mean, result.motion_handler_ms.mean])
	return result


func _measure_named_calls(state: Resource) -> Dictionary:
	var container := ui.get("workspace_view_container") as Control
	var pointer := container.size * Vector2(0.73, 0.72)
	var selected := int(state.get("selected_spline_point_index"))
	var calls := {
		"ui_process_idle": Callable(ui, "_process").bind(1.0 / 60.0),
		"ui_roll_controls_refresh": Callable(ui, "_refresh_spline_roll_controls"),
		"state_roll_limits": Callable(state, "get_spline_line_point_roll_limits").bind(selected),
		"ui_get_spline_points": Callable(ui, "_get_spline_points"),
		"controller_status_summary": Callable(controller, "get_status_summary"),
		"ui_view_state_changed": Callable(ui, "_on_workspace_view_state_changed"),
		"workspace_plane_refresh": Callable(workspace, "_refresh_spline_work_plane_visuals"),
		"ui_placement_target": Callable(ui, "_resolve_workspace_spline_position").bind(pointer),
		"ui_cursor_hover": Callable(ui, "_update_placement_cursor_from_workspace_position").bind(pointer),
		"presenter_cursor_sync": Callable(presenter, "_sync_placement_cursor").bind(Vector3(0.1, 0.1, 0), true, 0.01),
	}
	var result := {}
	for name: String in calls:
		var times := PackedFloat64Array()
		for repetition in range(3):
			var started := Time.get_ticks_usec()
			(calls[name] as Callable).call()
			times.append(float(Time.get_ticks_usec() - started) / 1000.0)
		result[name] = _stats(times)
	return result


func _mouse_button(button: int, pressed: bool, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = position
	ui.call("_handle_workspace_mouse_button", event)


func _mesh_ids() -> Dictionary:
	var result := {}
	for property: String in ["preview_mesh_instance", "spline_preview_mesh_instance", "spline_roll_preview_mesh_instance", "active_material_body_preview_mesh_instance"]:
		var instance := presenter.get(property) as MeshInstance3D
		result[property] = instance.mesh.get_instance_id() if instance != null and instance.mesh != null else 0
	return result


func _stats(values: PackedFloat64Array) -> Dictionary:
	if values.is_empty():
		return {"count": 0, "mean": 0.0, "p50": 0.0, "p95": 0.0, "max": 0.0, "over_16ms": 0, "over_33ms": 0, "over_100ms": 0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	var over_16 := 0
	var over_33 := 0
	var over_100 := 0
	for value: float in values:
		total += value
		over_16 += int(value > 16.667)
		over_33 += int(value > 33.333)
		over_100 += int(value > 100.0)
	return {"count": values.size(), "mean": total / values.size(),
		"p50": sorted[int(floor((sorted.size() - 1) * 0.5))], "p95": sorted[int(ceil((sorted.size() - 1) * 0.95))],
		"max": sorted[-1], "over_16ms": over_16, "over_33ms": over_33, "over_100ms": over_100}


func _finish(report: Dictionary, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("Taper navigation profile: " + path)
	quit(0 if bool(report.get("ok", false)) else 1)
