extends "res://tools/diagnose_skill_pointer_speed.gd"

## Real station integration, isolated library, no skill Save. Also keeps the
## continuous route samples for comparing flow rather than endpoints alone.
func _reopen_write(ui: CombatAnimationStationUI, side: String) -> void:
	await super._reopen_write(ui, side)
	allocation_report["scope"] = "Captured/rate-limited real station marker gestures and speed/duration overlay separation; isolated library, no skill Save."
	_check_allocation(ui.preview_drag_speed_control.position.x < ui.preview_duration_control.position.x, "speed_left_duration_right")
	_check_allocation(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pointer_visible_between_gestures")
	var duration: float = ui.get_default_motion_node_transition_duration()
	ui.preview_drag_speed_control._set_user_speed(50.0, true)
	_check_allocation(ui.marker_drag_input.speed_pixels_per_second == 50.0 and is_equal_approx(duration, ui.get_default_motion_node_transition_duration()), "speed_independent_of_node_duration")
	_check_allocation(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not ui.marker_drag_input.active, "speed_widget_keeps_pointer_visible")
	ui.preview_drag_speed_control._set_user_speed(180.0, true)
	# Dispatch actual engine input through Control hit testing, not the callback.
	for widget in [ui.preview_drag_speed_control, ui.preview_duration_control]:
		var point: Vector2 = widget.up_button.get_global_rect().get_center()
		_engine_button(point, true)
		await _wait_frames(2)
		_check_allocation(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not ui.marker_drag_input.active, String(widget.name) + "_arrow_input_keeps_pointer")
		_engine_button(point, false)
	ui.preview_drag_speed_control._set_user_speed(180.0, true)
	var camera: Camera3D = ui.call("_get_preview_camera")
	var tested := []
	# Tip routes above already exercise ordinary release. These additional tiny
	# gestures cover controls that use different UI movement paths.
	for spec: Array in [[&"pommel", &"pommel"], [&"right_arm_roll", &"right_upperarm_roll"], [&"left_hand_proxy", &"left_hand_proxy_pommel"], [&"weapon", &"weapon_rotation"], [&"weapon_facing", &"weapon_facing"]]:
		_select_marker_focus(ui, spec[0])
		await _wait_frames(2)
		var marker: Variant = ui.preview_presenter.get_authoring_marker_screen_position(ui.preview_subviewport, camera, spec[1])
		_check_allocation(marker is Vector2, String(spec[1]) + "_visible_marker")
		if not marker is Vector2: continue
		_speed_button(ui, marker, true)
		_check_allocation(ui.motion_node_editor.get_drag_target() == spec[1], String(spec[1]) + "_correct_target")
		if not ui.motion_node_editor.is_dragging(): continue
		var motion := InputEventMouseMotion.new()
		motion.screen_relative = Vector2(4, -1)
		motion.relative = motion.screen_relative
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		ui.call("_input", motion)
		await _wait_frames(4)
		_speed_button(ui, Vector2.ZERO, false)
		tested.append(String(spec[1]))
		await _wait_frames(3)
	allocation_report["additional_gestures"] = tested
	# Focus loss must never leave the cursor captured or a drag half active.
	_select_marker_focus(ui, &"tip")
	await _wait_frames(2)
	var tip: Variant = ui.preview_presenter.get_authoring_marker_screen_position(ui.preview_subviewport, camera, &"tip")
	if tip is Vector2:
		_speed_button(ui, tip, true)
		ui.call("_on_marker_window_focus_exited")
		_check_allocation(not ui.marker_drag_input.active and not ui.motion_node_editor.is_dragging() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "focus_loss_releases_capture")
		_speed_button(ui, tip, true)
		ui.call("_cycle_focus", 1)
		_check_allocation(not ui.marker_drag_input.active and not ui.motion_node_editor.is_dragging() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "space_navigation_releases_capture")
	await _wait_frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join("editor_controls.png"))

func _select_marker_focus(ui: CombatAnimationStationUI, focus: StringName) -> void:
	# Use the same rebuilding path as Space, including arm and roll gizmos.
	if ui.session_state.current_focus == focus:
		ui.preview_presenter.refresh_focus_visuals(ui.preview_view_container, ui.preview_subviewport,
			ui.call("_get_active_draft"), ui.get_selected_motion_node_index(), focus,
			ui.call("_get_active_baked_profile"))
		return
	for index in 12:
		ui.call("_cycle_focus", 1)
		if ui.session_state.current_focus == focus:
			return
	_check_allocation(false, "focus_available_" + String(focus))

func _speed_trial(ui: CombatAnimationStationUI, weapon: Node3D, camera: Camera3D,
		preview_root: Node3D, start: Vector2, route: PackedVector2Array, specification: Dictionary) -> Dictionary:
	_select_marker_focus(ui, &"tip")
	await _wait_frames(2)
	var marker: Variant = ui.preview_presenter.get_authoring_marker_screen_position(ui.preview_subviewport, camera, &"tip")
	_check_allocation(marker is Vector2, "tip_visible_marker")
	if not marker is Vector2:
		return {"completed": false, "reason": "tip_marker_absent"}
	var report := await super._speed_trial(ui, weapon, camera, preview_root, marker, route, specification)
	report["calculated_endpoint_screen"] = start
	report["marker_vs_calculated_endpoint_px"] = start.distance_to(marker)
	return report

func _speed_button(ui: CombatAnimationStationUI, position: Vector2, pressed: bool) -> void:
	_engine_button(ui.preview_view_container.get_global_transform_with_canvas() * position, pressed)
	if pressed:
		_check_allocation(ui.marker_drag_input.active and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "successful_marker_press_captures")
	else:
		_check_allocation(not ui.marker_drag_input.active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "release_restores_pointer")

func _engine_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
