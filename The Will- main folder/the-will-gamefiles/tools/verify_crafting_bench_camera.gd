extends SceneTree

const CraftingBenchScene = preload("res://scenes/ui/crafting_bench_ui.tscn")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	get_root().add_child(forge_controller)

	var crafting_ui: CraftingBenchUI = CraftingBenchScene.instantiate() as CraftingBenchUI
	get_root().add_child(crafting_ui)
	await process_frame
	await process_frame

	crafting_ui.open_for(null, forge_controller, "Verifier Bench")
	await process_frame
	await process_frame

	var preview: ForgeWorkspacePreview = crafting_ui.free_workspace_preview
	var free_view_container: SubViewportContainer = crafting_ui.free_view_container
	var free_view_panel: PanelContainer = crafting_ui.free_view_panel
	var axis_indicator = crafting_ui.axis_indicator_control
	var axis_panel: Control = crafting_ui.get_node("Panel/MarginContainer/RootVBox/MainHBox/CenterPanel/MarginContainer/CenterVBox/WorkspaceStage/MainViewportHost/AxisIndicatorPanel")
	var axis_stylebox: StyleBoxFlat = axis_panel.get_theme_stylebox("panel") as StyleBoxFlat if axis_panel is PanelContainer else null
	var preview_box_mesh: BoxMesh = preview.occupied_cells_instance.multimesh.mesh as BoxMesh if preview != null and preview.occupied_cells_instance != null and preview.occupied_cells_instance.multimesh != null else null
	var initial_distance: float = preview.camera.position.z if preview != null and preview.camera != null else -1.0
	var initial_pivot: Vector3 = preview.camera_pivot.position if preview != null and preview.camera_pivot != null else Vector3.ZERO
	var initial_rotation_y: float = preview.camera_pivot.rotation.y if preview != null and preview.camera_pivot != null else 0.0
	var initial_axis_x: Vector2 = axis_indicator.get_axis_screen_vector(&"x") if axis_indicator != null else Vector2.ZERO
	var initial_axis_y: Vector2 = axis_indicator.get_axis_screen_vector(&"y") if axis_indicator != null else Vector2.ZERO
	var initial_axis_z: Vector2 = axis_indicator.get_axis_screen_vector(&"z") if axis_indicator != null else Vector2.ZERO
	var initial_light_forward: Vector3 = preview.light.global_transform.basis.z if preview != null and preview.light != null else Vector3.ZERO
	var initial_mouse_mode: Input.MouseMode = Input.get_mouse_mode()
	var plane_position: Vector3 = preview.active_plane_instance.position if preview != null and preview.active_plane_instance != null else Vector3.ZERO
	var cell_world_size: float = forge_controller.get_cell_world_size_meters()
	var expected_plane_z: float = (float(crafting_ui.active_layer) * cell_world_size) - ((float(forge_controller.grid_size.z - 1) * cell_world_size) * 0.5)
	var plane_centered_xy: bool = is_zero_approx(plane_position.x) and is_zero_approx(plane_position.y) and is_equal_approx(plane_position.z, expected_plane_z)
	var preview_cells_touching: bool = preview_box_mesh != null and preview_box_mesh.size.is_equal_approx(Vector3.ONE * cell_world_size)

	var panel_wheel_zoom_event: InputEventMouseButton = InputEventMouseButton.new()
	panel_wheel_zoom_event.button_index = MOUSE_BUTTON_WHEEL_UP
	panel_wheel_zoom_event.pressed = true
	panel_wheel_zoom_event.position = Vector2(8.0, 8.0)
	crafting_ui.call("_on_free_view_panel_gui_input", panel_wheel_zoom_event)
	await process_frame

	var distance_after_panel_zoom: float = preview.camera.position.z if preview != null and preview.camera != null else initial_distance

	if preview != null:
		preview.zoom_by(-100.0)
		preview.pan_by(Vector2(160.0, 0.0))
	await process_frame

	var edited_distance: float = preview.camera.position.z if preview != null and preview.camera != null else -1.0
	var edited_pivot: Vector3 = preview.camera_pivot.position if preview != null and preview.camera_pivot != null else Vector3.ZERO

	crafting_ui.call("_refresh_all")
	await process_frame
	await process_frame

	var distance_after_refresh: float = preview.camera.position.z if preview != null and preview.camera != null else -1.0
	var pivot_after_refresh: Vector3 = preview.camera_pivot.position if preview != null and preview.camera_pivot != null else Vector3.ZERO

	crafting_ui.call("_refresh_all", false)
	await process_frame
	await process_frame

	var distance_after_reset_refresh: float = preview.camera.position.z if preview != null and preview.camera != null else -1.0
	var pivot_after_reset_refresh: Vector3 = preview.camera_pivot.position if preview != null and preview.camera_pivot != null else Vector3.ZERO

	var orbit_press: InputEventMouseButton = InputEventMouseButton.new()
	orbit_press.button_index = MOUSE_BUTTON_RIGHT
	orbit_press.pressed = true
	orbit_press.position = free_view_container.size * 0.5
	crafting_ui.call("_on_free_view_gui_input", orbit_press)
	await process_frame

	var orbit_captured_mouse: bool = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	var orbit_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	orbit_motion.relative = Vector2(18.0, -9.0)
	crafting_ui.call("_unhandled_input", orbit_motion)
	await process_frame

	var rotation_after_orbit_drag: float = preview.camera_pivot.rotation.y if preview != null and preview.camera_pivot != null else initial_rotation_y
	var light_forward_after_orbit: Vector3 = preview.light.global_transform.basis.z if preview != null and preview.light != null else initial_light_forward
	var camera_forward_after_orbit: Vector3 = preview.camera.global_transform.basis.z if preview != null and preview.camera != null else Vector3.ZERO
	var axis_x_after_orbit: Vector2 = axis_indicator.get_axis_screen_vector(&"x") if axis_indicator != null else Vector2.ZERO
	var axis_y_after_orbit: Vector2 = axis_indicator.get_axis_screen_vector(&"y") if axis_indicator != null else Vector2.ZERO
	var axis_z_after_orbit: Vector2 = axis_indicator.get_axis_screen_vector(&"z") if axis_indicator != null else Vector2.ZERO

	var orbit_release: InputEventMouseButton = InputEventMouseButton.new()
	orbit_release.button_index = MOUSE_BUTTON_RIGHT
	orbit_release.pressed = false
	crafting_ui.call("_unhandled_input", orbit_release)
	await process_frame

	var mouse_restored_after_orbit: bool = Input.get_mouse_mode() == initial_mouse_mode

	var pan_key_down: InputEventKey = InputEventKey.new()
	pan_key_down.keycode = KEY_C
	pan_key_down.pressed = true
	Input.parse_input_event(pan_key_down)
	await process_frame

	var pan_press: InputEventMouseButton = InputEventMouseButton.new()
	pan_press.button_index = MOUSE_BUTTON_RIGHT
	pan_press.pressed = true
	pan_press.position = free_view_container.size * 0.5
	crafting_ui.call("_on_free_view_gui_input", pan_press)
	await process_frame

	var pivot_before_pan_drag: Vector3 = preview.camera_pivot.position if preview != null and preview.camera_pivot != null else Vector3.ZERO
	var pan_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	pan_motion.relative = Vector2(14.0, 0.0)
	crafting_ui.call("_unhandled_input", pan_motion)
	await process_frame

	var pivot_after_pan_drag: Vector3 = preview.camera_pivot.position if preview != null and preview.camera_pivot != null else pivot_before_pan_drag

	var pan_release: InputEventMouseButton = InputEventMouseButton.new()
	pan_release.button_index = MOUSE_BUTTON_RIGHT
	pan_release.pressed = false
	crafting_ui.call("_unhandled_input", pan_release)
	await process_frame

	var pan_key_up: InputEventKey = InputEventKey.new()
	pan_key_up.keycode = KEY_C
	pan_key_up.pressed = false
	Input.parse_input_event(pan_key_up)
	await process_frame

	var mouse_restored_after_pan: bool = Input.get_mouse_mode() == initial_mouse_mode

	var lines: PackedStringArray = []
	lines.append("preview_loaded=%s" % str(preview != null))
	lines.append("axis_indicator_exists=%s" % str(axis_indicator != null))
	lines.append("axis_panel_parent_is_main_host=%s" % str(axis_panel != null and axis_panel.get_parent() == crafting_ui.main_viewport_host))
	lines.append("axis_panel_bottom_right=%s" % str(
		axis_panel != null and
		is_equal_approx(axis_panel.anchor_left, 1.0) and
		is_equal_approx(axis_panel.anchor_top, 1.0) and
		is_equal_approx(axis_panel.anchor_right, 1.0) and
		is_equal_approx(axis_panel.anchor_bottom, 1.0) and
		axis_panel.offset_right < 0.0 and
		axis_panel.offset_bottom < 0.0
	))
	lines.append("axis_panel_style_transparent=%s" % str(
		axis_stylebox != null and
		is_zero_approx(axis_stylebox.bg_color.a) and
		axis_stylebox.border_width_left == 0 and
		axis_stylebox.border_width_top == 0 and
		axis_stylebox.border_width_right == 0 and
		axis_stylebox.border_width_bottom == 0
	))
	lines.append("initial_axis_x=%s" % str(initial_axis_x))
	lines.append("initial_axis_y=%s" % str(initial_axis_y))
	lines.append("initial_axis_z=%s" % str(initial_axis_z))
	lines.append("plane_position=%s" % str(plane_position))
	lines.append("expected_plane_z=%s" % str(expected_plane_z))
	lines.append("plane_centered_xy=%s" % str(plane_centered_xy))
	lines.append("preview_cells_touching=%s" % str(preview_cells_touching))
	lines.append("panel_wheel_zoom_changed_distance=%s" % str(distance_after_panel_zoom < initial_distance))
	lines.append("initial_distance=%s" % str(initial_distance))
	lines.append("edited_distance=%s" % str(edited_distance))
	lines.append("distance_after_refresh=%s" % str(distance_after_refresh))
	lines.append("zoom_persisted_after_refresh=%s" % str(is_equal_approx(distance_after_refresh, edited_distance)))
	lines.append("close_zoom_below_one_meter=%s" % str(edited_distance > 0.0 and edited_distance < 1.0))
	lines.append("initial_pivot=%s" % str(initial_pivot))
	lines.append("edited_pivot=%s" % str(edited_pivot))
	lines.append("pivot_after_refresh=%s" % str(pivot_after_refresh))
	lines.append("pan_persisted_after_refresh=%s" % str(pivot_after_refresh.distance_to(edited_pivot) <= 0.0001))
	lines.append("distance_after_reset_refresh=%s" % str(distance_after_reset_refresh))
	lines.append("pivot_after_reset_refresh=%s" % str(pivot_after_reset_refresh))
	lines.append("reset_refresh_recenters_view=%s" % str(
		distance_after_reset_refresh > edited_distance and
		pivot_after_reset_refresh.distance_to(Vector3.ZERO) <= 0.0001
	))
	lines.append("orbit_captured_mouse=%s" % str(orbit_captured_mouse))
	lines.append("orbit_changed_rotation=%s" % str(not is_equal_approx(rotation_after_orbit_drag, initial_rotation_y)))
	lines.append("axis_indicator_changed_with_orbit=%s" % str(
		axis_x_after_orbit.distance_to(initial_axis_x) > 0.0001 or
		axis_y_after_orbit.distance_to(initial_axis_y) > 0.0001 or
		axis_z_after_orbit.distance_to(initial_axis_z) > 0.0001
	))
	lines.append("light_parent_is_camera=%s" % str(preview != null and preview.light != null and preview.camera != null and preview.light.get_parent() == preview.camera))
	lines.append("light_changed_with_orbit=%s" % str(light_forward_after_orbit.distance_to(initial_light_forward) > 0.0001))
	lines.append("light_aligned_to_camera=%s" % str(light_forward_after_orbit.distance_to(camera_forward_after_orbit) <= 0.0001))
	lines.append("mouse_restored_after_orbit=%s" % str(mouse_restored_after_orbit))
	lines.append("pan_changed_pivot=%s" % str(pivot_after_pan_drag.distance_to(pivot_before_pan_drag) > 0.0001))
	lines.append("mouse_restored_after_pan=%s" % str(mouse_restored_after_pan))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/crafting_bench_camera_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
