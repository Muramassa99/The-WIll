extends "res://tools/diagnose_skill3_tip_full_range.gd"

## Companion to the straight sweep: intentional circular pointer overdrive,
## clockwise then counterclockwise. Default3 pointer revolutions per direction
## at15-degree input increments. Does NOT claim the weapon itself turns1080deg.
## --revolutions=3 --circle-step-degrees=15 --cap=900
## --separate-holds=true also repeats from the inherited isolated checkpoint
## with a fresh capture for each direction. No source Save/Reset/reacquisition.

func _reopen_write(ui: CombatAnimationStationUI, side: String) -> void:
	await super._reopen_write(ui, side)
	allocation_report["scope"] = "Saved Skill3 isolated copy: projected selected-grip-centre circular pointer input, clockwise then counterclockwise, intentionally continuing past stalls. Actual weapon/arm motion recorded separately; requested pointer turns are not assumed weapon turns. Final skeleton_updated poses recorded as final_skin."
	allocation_report["circular_input"] = {"requested_revolutions_per_direction": _requested_revolutions(),
		"step_degrees": _circle_step_degrees(), "speed_cap_px_s": circle_ui.marker_drag_input.speed_pixels_per_second,
		"pivot_contract": "Selected Handle slice -> TrajectoryAuthoringOrigin -> world -> Camera3D screen. Fixed screen circle per capture; actual accepted grip may travel."}

func _requested_revolutions() -> float:
	return clampf(float(options.get("revolutions", "3")), 1.0, 5.0)

func _circle_step_degrees() -> float:
	return clampf(float(options.get("circle-step-degrees", "15")), 5.0, 45.0)

func _circle_pivot() -> Dictionary:
	var node: CombatAnimationMotionNode = circle_ui.call("_get_active_motion_node")
	var local: Variant = circle_ui.preview_presenter.resolve_motion_node_primary_grip_seat_local(circle_ui.preview_subviewport, node)
	var trajectory: Node3D = circle_ui.call("_get_preview_trajectory_root")
	if not local is Vector3 or trajectory == null:
		return {"valid": false, "reason": "selected_grip_station_unavailable"}
	var world: Vector3 = trajectory.to_global(local)
	if circle_camera.is_position_behind(world):
		return {"valid": false, "reason": "grip_behind_camera"}
	return {"valid": true, "trajectory_local": local, "world": world,
		"screen": circle_camera.unproject_position(world), "origin_id": "TrajectoryAuthoringOrigin"}

func _direction_sequence(label: String, separate_holds: bool) -> Dictionary:
	var result := {"label": label, "separate_holds": separate_holds, "stages": [], "engaged": false,
		"mode": "circular_pointer_overdrive"}
	var press_position := Vector2.ZERO
	var radius_vector := Vector2.ZERO
	var pivot := {}
	for stage_index: int in 2:
		var direction := 1.0 if stage_index == 0 else -1.0
		var stage_label := label + ("_clockwise" if stage_index == 0 else "_counterclockwise")
		if stage_index == 0 or separate_holds:
			var marker: Variant = circle_ui.preview_presenter.get_authoring_marker_screen_position(
				circle_ui.preview_subviewport, circle_camera, &"tip")
			pivot = _circle_pivot()
			_check_allocation(marker is Vector2 and bool(pivot.get("valid", false)), stage_label + "_circle_geometry_available", _json(pivot))
			if not marker is Vector2 or not bool(pivot.get("valid", false)): break
			press_position = marker
			radius_vector = press_position - (pivot.screen as Vector2)
			_check_allocation(radius_vector.length() >= 2.0, stage_label + "_nondegenerate_circle", {"radius_px": radius_vector.length()})
			if radius_vector.length() < 2.0: break
			_snapshot(stage_label + "_before_press")
			_engine_button(press_position, true)
			var engaged: bool = circle_ui.motion_node_editor.get_drag_target() == &"tip" and circle_ui.marker_drag_input.active
			result.engaged = engaged
			_check_allocation(engaged, stage_label + "_engaged_tip")
			_sample(stage_label + "_pressed")
			if not engaged:
				_engine_button(press_position, false)
				break
		var stage: Dictionary = await _circle_input(stage_label, direction, radius_vector, pivot)
		radius_vector = radius_vector.rotated(deg_to_rad(float(stage.requested_degrees)))
		stage["stage_end_drain"] = await _await_direction_input_drained(stage_label + "_stage_end")
		result.stages.append(stage)
		_snapshot(stage_label + "_end")
		await _image(stage_label + "_end")
		if separate_holds or stage_index == 1 or not bool(stage.stage_end_drain.drained) or not bool(stage.completed):
			_engine_button(press_position, false)
			_sample(stage_label + "_released")
			for settle: int in 4:
				await process_frame
				_sample(stage_label + "_settle")
			await _image(stage_label + "_released")
		if not bool(stage.stage_end_drain.drained) or not bool(stage.completed): break
	_snapshot(label + "_finished")
	return result

func _circle_input(label: String, direction: float, radius_vector: Vector2, pivot: Dictionary) -> Dictionary:
	var total_degrees := 360.0 * _requested_revolutions()
	var count := int(ceil(total_degrees / _circle_step_degrees()))
	var previous_angle := 0.0
	var started := Time.get_ticks_usec()
	var steps: Array[Dictionary] = []
	var delivered := 0
	var actual_travel := 0.0
	var stalled_events := 0
	var reason := "completed_requested_pointer_revolutions"
	print("TIP_CIRCLE_STAGE_BEGIN ", label, " requested_degrees=", direction * total_degrees,
		" events=", count, " radius_px=", radius_vector.length())
	_sample(label + "_start", {"circle_pivot": _json(pivot), "radius_px": radius_vector.length()})
	for step_index: int in count:
		await process_frame
		await RenderingServer.frame_post_draw
		var before_tip: Variant = _tip_screen_now()
		var before_sequence := final_skin_sequence
		var angle := direction * minf((step_index + 1) * _circle_step_degrees(), total_degrees)
		var relative := radius_vector.rotated(deg_to_rad(angle)) - radius_vector.rotated(deg_to_rad(previous_angle))
		var details := {"step_index": step_index + 1, "requested_events": count,
			"requested_angle_degrees": angle, "requested_relative_px": _vec(relative)}
		_sample(label + "_before_input", details)
		var step_started := Time.get_ticks_usec()
		var chord: Dictionary = await _deliver_circle_chord(label + "_step_%03d" % (step_index + 1), relative)
		var drain: Dictionary = chord.drain
		if bool(chord.complete):
			delivered += 1
			previous_angle = angle
		_sample(label + "_after_input", details.merged({"chord_delivery": chord}))
		var after_tip: Variant = _tip_screen_now()
		var travel := INF
		if before_tip is Vector2 and after_tip is Vector2:
			travel = (before_tip as Vector2).distance_to(after_tip)
			actual_travel += travel
		if is_finite(travel) and travel < _stall_pixels(): stalled_events += 1
		var step := details.duplicate()
		step.merge({"drain": drain, "chord_delivery": chord, "actual_tip_travel_px": travel if is_finite(travel) else null,
			"tip_before": _vec(before_tip) if before_tip is Vector2 else null,
			"tip_after": _vec(after_tip) if after_tip is Vector2 else null,
			"elapsed_ms": float(Time.get_ticks_usec() - step_started) / 1000.0,
			"final_signal_before": before_sequence, "final_signal_after": final_skin_sequence,
			"post_draw_weapon_world": _transform(circle_weapon.global_transform)})
		steps.append(step)
		_sample(label + "_visible_after_input", step)
		if delivered % 20 == 0:
			print("TIP_CIRCLE_PROGRESS ", label, " events=", delivered, " requested_degrees=", angle,
				" actual_travel_px=", actual_travel, " stalled_events=", stalled_events)
		if not bool(drain.drained):
			reason = "input_drain_timeout"
			break
		if not bool(chord.complete):
			reason = "bounded_pointer_delivery_failed"
			break
		if not circle_ui.marker_drag_input.active:
			reason = "capture_lost"
			break
	print("TIP_CIRCLE_STAGE_END ", label, " events=", delivered, " stop=", reason,
		" requested_degrees=", previous_angle, " actual_travel_px=", actual_travel)
	_check_allocation(delivered == count, label + "_requested_pointer_revolutions_delivered", {"requested": count, "delivered": delivered, "stop_reason": reason})
	return {"label": label, "mode": "circular_pointer_overdrive", "requested_degrees": previous_angle, "completed": delivered == count,
		"requested_revolutions": direction * _requested_revolutions(), "planned_events": count,
		"delivered_samples": delivered, "stalled_events": stalled_events, "actual_tip_travel_px": actual_travel,
		"stop_reason": reason, "pivot": _json(pivot), "radius_px": radius_vector.length(),
		"elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0, "steps": steps}

## The editor discards excess over its per-frame speed cap. Deliver each screen
## chord in <=10 physical-pixel pieces, measure the actual virtual-pointer
## advance, and resend only the remainder. Do not advance circle phase unless
## its full chord was delivered. This never moves the weapon/pose directly.
func _deliver_circle_chord(label: String, requested_preview: Vector2) -> Dictionary:
	var remaining := requested_preview
	var canvas: Transform2D = circle_ui.preview_view_container.get_screen_transform()
	var physical_length: float = canvas.basis_xform(remaining).length()
	var maximum := clampi(int(ceil(physical_length / 10.0)) * 4 + 8, 8, 256)
	var pieces: Array[Dictionary] = []
	var drain := {"drained": true, "frames_waited": 0, "elapsed_ms": 0}
	for piece_index: int in maximum:
		canvas = circle_ui.preview_view_container.get_screen_transform()
		if canvas.basis_xform(remaining).length() <= 0.01: break
		await process_frame
		var before: Vector2 = circle_ui.marker_drag_input.pointer_position
		var sent: Vector2 = canvas.basis_xform(remaining).limit_length(10.0)
		var event := InputEventMouseMotion.new()
		event.device = TEST_MOUSE_DEVICE
		event.screen_relative = sent
		event.relative = sent
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		drain = await _await_direction_input_drained(label + "_piece_%03d" % (piece_index + 1))
		await RenderingServer.frame_post_draw
		var actual: Vector2 = circle_ui.marker_drag_input.pointer_position - before
		remaining -= actual
		var piece := {"piece": piece_index + 1, "sent_physical_px": _vec(sent),
			"delivered_preview_px": _vec(actual), "delivered_physical_px": _vec(canvas.basis_xform(actual)),
			"remaining_physical_px": canvas.basis_xform(remaining).length(), "drain": drain}
		pieces.append(piece)
		_sample(label + "_piece_visible", piece)
		if not bool(drain.drained) or not circle_ui.marker_drag_input.active: break
	var complete: bool = canvas.basis_xform(remaining).length() <= 0.01
	return {"complete": complete, "requested_preview_px": _vec(requested_preview),
		"delivered_preview_px": _vec(requested_preview - remaining),
		"remaining_physical_px": canvas.basis_xform(remaining).length(),
		"pieces": pieces, "maximum_pieces": maximum, "drain": drain}
