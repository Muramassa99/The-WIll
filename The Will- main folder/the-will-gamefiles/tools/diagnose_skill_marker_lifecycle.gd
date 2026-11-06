extends "res://tools/diagnose_skill3_tip_full_range.gd"

## Narrow click lifecycle measurement. Reuses isolated saved Skill3 loading and
## test-only mouse isolation; replaces all sweeps with two captures/releases:
## one stationary click and one10-physical-pixel Tip movement. No source Save.
## --phase=write --hands=R --weapon=Broken_Balde_v1 --slot=skill_slot_3
## --out=<fresh-directory> --cap=900 (existing camera arguments are supported)
## Optional production tracing is enabled only on this UI instance by metadata.
var lifecycle_buttons: Array[Dictionary] = []
var lifecycle_label := "setup"
var last_button_timing: Dictionary = {}

func _reopen_write(ui: CombatAnimationStationUI, side: String) -> void:
	ui.set_meta("marker_lifecycle_profile_enabled", false)
	ui.set_meta("marker_lifecycle_profile_events", [])
	options["separate-holds"] = "false"
	await super._reopen_write(ui, side)
	allocation_report["scope"] = "Isolated source Skill3 node3: stationary Tip click/release and one10px Tip drag/release, synchronous button wall timings plus optional UI lifecycle phase timings. No Reset, F, Save, reacquisition between gestures, or range sweeps."
	allocation_report["marker_lifecycle_buttons"] = lifecycle_buttons
	allocation_report["marker_lifecycle_profile_events"] = _json(_lifecycle_events(ui))
	ui.set_meta("marker_lifecycle_profile_enabled", false)

func _lifecycle_events(ui: CombatAnimationStationUI) -> Array:
	var value: Variant = ui.get_meta("marker_lifecycle_profile_events", [])
	return value if value is Array else []

func _engine_button(local_position: Vector2, pressed: bool) -> void:
	circle_ui.set_meta("marker_lifecycle_profile_events", [])
	circle_ui.set_meta("marker_lifecycle_profile_enabled", true)
	var before_frame := Engine.get_process_frames()
	var before_status: String = circle_ui.footer_status_label.text
	var started := Time.get_ticks_usec()
	super._engine_button(local_position, pressed)
	var finished := Time.get_ticks_usec()
	circle_ui.set_meta("marker_lifecycle_profile_enabled", false)
	var events: Array = _lifecycle_events(circle_ui)
	last_button_timing = {"gesture": lifecycle_label, "pressed": pressed,
		"start_usec": started, "finish_usec": finished, "elapsed_usec": finished - started,
		"elapsed_ms": float(finished - started) / 1000.0,
		"frame_before": before_frame, "frame_after": Engine.get_process_frames(),
		"status_before": before_status, "status_after": circle_ui.footer_status_label.text,
		"captured_after": circle_ui.marker_drag_input.active,
		"drag_target_after": String(circle_ui.motion_node_editor.get_drag_target()),
		"refresh_pending_after": circle_ui.preview_drag_refresh_pending,
		"ui_profile_events": _json(events)}
	lifecycle_buttons.append(last_button_timing.duplicate(true))
	print("MARKER_LIFECYCLE_BUTTON ", lifecycle_label, " pressed=", pressed,
		" elapsed_ms=", last_button_timing.elapsed_ms,
		" profile_events=", events.size())

func _direction_sequence(label: String, _separate_holds: bool) -> Dictionary:
	var result := {"label": label, "mode": "two_click_lifecycle_only", "stages": [], "engaged": false}
	for move: bool in [false, true]:
		lifecycle_label = "tip_move10px" if move else "tip_stationary_click"
		var marker: Variant = circle_ui.preview_presenter.get_authoring_marker_screen_position(
			circle_ui.preview_subviewport, circle_camera, &"tip")
		_check_allocation(marker is Vector2, lifecycle_label + "_marker_available")
		if not marker is Vector2: break
		var position: Vector2 = marker
		var stage := {"gesture": lifecycle_label, "move": move}
		_snapshot(lifecycle_label + "_before_press")
		_engine_button(position, true)
		stage["press"] = last_button_timing.duplicate(true)
		var engaged: bool = circle_ui.motion_node_editor.get_drag_target() == &"tip" and circle_ui.marker_drag_input.active
		result.engaged = engaged
		_check_allocation(engaged, lifecycle_label + "_engaged_tip")
		_sample(lifecycle_label + "_after_press", {"button_timing": last_button_timing})
		if not engaged:
			_engine_button(position, false)
			stage["release"] = last_button_timing.duplicate(true)
			result.stages.append(stage)
			break
		for settle: int in 3: await process_frame
		await RenderingServer.frame_post_draw
		_snapshot(lifecycle_label + "_held_before_motion")
		if move:
			var before: Vector2 = circle_ui.marker_drag_input.pointer_position
			var before_count := _lifecycle_events(circle_ui).size()
			var movement_started := Time.get_ticks_usec()
			var event := InputEventMouseMotion.new()
			event.device = TEST_MOUSE_DEVICE
			event.screen_relative = Vector2(10.0, 0.0)
			event.relative = event.screen_relative
			event.button_mask = MOUSE_BUTTON_MASK_LEFT
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			var injected := Time.get_ticks_usec()
			var drain: Dictionary = await _await_direction_input_drained(lifecycle_label + "_move")
			await RenderingServer.frame_post_draw
			var actual: Vector2 = circle_ui.marker_drag_input.pointer_position - before
			stage["movement"] = {"requested_physical_px": [10.0, 0.0],
				"actual_virtual_pointer_preview_px": _vec(actual),
				"actual_virtual_pointer_physical_px": _vec(circle_ui.preview_view_container.get_screen_transform().basis_xform(actual)),
				"synchronous_injection_usec": injected - movement_started,
				"through_post_draw_usec": Time.get_ticks_usec() - movement_started,
				"drain": drain, "ui_profile_events": _json(_lifecycle_events(circle_ui).slice(before_count))}
			_sample(lifecycle_label + "_after_motion", {"movement": stage.movement})
		_snapshot(lifecycle_label + "_before_release")
		_engine_button(position, false)
		stage["release"] = last_button_timing.duplicate(true)
		_sample(lifecycle_label + "_after_release", {"button_timing": last_button_timing})
		var settle_started := Time.get_ticks_usec()
		for settle: int in 4:
			await process_frame
			_sample(lifecycle_label + "_release_settle", {"settle_frame": settle + 1,
				"since_release_usec": Time.get_ticks_usec() - settle_started})
		await RenderingServer.frame_post_draw
		stage["release_settle_through_post_draw_usec"] = Time.get_ticks_usec() - settle_started
		_snapshot(lifecycle_label + "_settled")
		var before_row: Dictionary = snapshots[lifecycle_label + "_before_press"]
		var after_row: Dictionary = snapshots[lifecycle_label + "_settled"]
		stage["authored_node_before"] = before_row.node
		stage["authored_node_after"] = after_row.node
		stage["authored_node_unchanged"] = before_row.node == after_row.node
		stage["input_bone_poses_unchanged"] = before_row.bones == after_row.bones
		stage["weapon_world_unchanged"] = before_row.weapon_world == after_row.weapon_world
		stage["snapshot_before"] = lifecycle_label + "_before_press"
		stage["snapshot_after"] = lifecycle_label + "_settled"
		await _image(lifecycle_label + "_settled")
		result.stages.append(stage)
	_snapshot(label + "_lifecycle_finished")
	return result
