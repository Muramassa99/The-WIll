extends "res://tools/diagnose_skill3_curve_roll.gd"

## Observe the saved Skill3 node3 right -> left -> right Tip symptom. The
## inherited harness clones its source library; no Reset, Save, F or pose
## fabrication. Only real captured-input edits and camera framing are applied.
## --phase=write --hands=R --weapon=Broken_Balde_v1 --slot=skill_slot_3
## --out=C:/WORKSPACE/godot_runs/<fresh> [--input=<library.tres>]
## --zoom-out=6 --cap=180 [--camera-pitch=30 --camera-yaw=24]
## --right-px=100 --right-seconds=1 --left-px=35 --left-seconds=0.35
## --step-px=3 --right-steps=12 --left-steps=12 selects fixed sample counts.
## --separate-holds=true repeats from the complete pre-gesture checkpoint.
## Optional --control=tip|pommel --drag-axis=x|y --first-direction=-1 (default +1).
var direction_sample_serial := 0
var trace_file: FileAccess

func _reopen_write(ui: CombatAnimationStationUI, side: String) -> void:
	circle_ui = ui
	root.size = Vector2i(2476, 1364)
	root.content_scale_size = Vector2i(2476, 1364)
	await _wait_frames(3)
	allocation_report["scope"] = "Read-only source; isolated saved Skill3 node3 selected-marker forward/reverse/forward with actual captured input. No optimization, Reset, Save, F or authored-pose overrides."
	allocation_report["input_selection"] = {"control": String(_control_target()), "axis": options.get("drag-axis", "x"), "first_direction": float(options.get("first-direction", "1"))}
	allocation_report["opening_grip"] = await _reopen_await_bound(ui, side)
	circle_actor = _get_preview_actor(ui) as PlayerHumanoidRig
	circle_weapon = _get_preview_held_item(ui)
	circle_camera = ui.call("_get_preview_camera")
	circle_root = ui.call("_get_preview_root")
	_check_allocation(circle_actor != null and circle_weapon != null and circle_camera != null, "scene_ready")
	if circle_actor == null or circle_weapon == null or circle_camera == null:
		return
	var draft: CombatAnimationDraft = ui.call("_get_active_draft")
	var actions := draft.get_action_motion_node_chain()
	_check_allocation(actions.size() >= 3, "saved_node3_exists", {"visible_nodes": actions.size()})
	if actions.size() < 3:
		return
	allocation_report["authored_before_open_node3"] = _authored_nodes(draft)
	var index: int = draft.motion_node_chain.find(actions[2])
	_check_allocation(ui.select_motion_node(index), "selected_saved_node3", {"index": index})
	allocation_report["selection_recording"] = await _await_allocation_recording(ui)
	allocation_report["node3_grip"] = await _reopen_await_bound(ui, side)
	ui.preview_drag_speed_control._set_user_speed(float(options.get("cap", "180")), true)
	ui.zoom_preview_camera(int(options.get("zoom-out", "6")))
	var camera_state: Dictionary = ui.preview_presenter.capture_camera_state(ui.preview_subviewport)
	# Start from the real default view with modest zoom. Exact framing can be
	# supplied after comparing the first screenshot; no pose values are changed.
	for spec: Array in [["camera-yaw", "orbit_yaw_degrees"], ["camera-pitch", "orbit_pitch_degrees"], ["camera-distance", "distance"]]:
		if options.has(spec[0]):
			camera_state[spec[1]] = float(options[spec[0]])
	ui.preview_presenter.restore_camera_state(ui.preview_subviewport, camera_state)
	_focus_tip()
	await _wait_frames(4)
	allocation_report["camera"] = _json(ui.preview_presenter.capture_camera_state(ui.preview_subviewport))
	allocation_report["speed_cap_px_s"] = ui.marker_drag_input.speed_pixels_per_second
	allocation_report["spine_isolation_enabled"] = circle_actor.is_authoring_arm_spine_isolation_enabled()
	allocation_report["screenshot_reference"] = {"tip": [-0.647, -0.284, 2.686],
		"orientation": [12.34, -17.65, -110.31], "weapon_roll": -65.6,
		"arm_R": -100.4, "body_support_blend": 1.0, "cap": 180,
		"note": "Comparison reference only. Loaded values are not overwritten to match a screenshot."}
	allocation_report["loaded_node3"] = _node(ui.call("_get_active_motion_node"))
	var skeleton_info := []
	for bone_index: int in circle_actor.skeleton.get_bone_count():
		skeleton_info.append({"name": circle_actor.skeleton.get_bone_name(bone_index),
			"parent": circle_actor.skeleton.get_bone_parent(bone_index),
			"rest": _transform(circle_actor.skeleton.get_bone_rest(bone_index))})
	allocation_report["skeleton"] = skeleton_info
	trace_file = FileAccess.open(output_dir.path_join("bone_trace.jsonl"), FileAccess.WRITE)
	_snapshot("node3_ready")
	await _image("node3_ready")
	# Capture after any screenshot wait so no asynchronous preparation is
	# accidentally attributed to the first click.
	var baseline_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node").duplicate(true)
	var checkpoint := CircleCheckpoint.capture(ui.preview_presenter, {"preview_root": circle_root,
		"actor_pivot": circle_root.get_node_or_null(ui.preview_presenter.PREVIEW_ACTOR_PIVOT_NAME),
		"trajectory_root": ui.call("_get_preview_trajectory_root")}, false)
	allocation_report["checkpoint_captured"] = not checkpoint.is_empty()
	_snapshot("continuous_baseline")
	allocation_report["gestures"] = [await _direction_sequence("continuous", false)]
	if String(options.get("separate-holds", "false")) == "true" and not checkpoint.is_empty():
		ui.motion_node_editor.end_drag()
		ui.call("_clear_preview_drag_override")
		ui.call("_release_marker_pointer")
		draft.motion_node_chain[index] = baseline_node.duplicate(true)
		ui.call("_invalidate_preview_drag_motion_chain_cache")
		var restored := CircleCheckpoint.restore(ui.preview_presenter, checkpoint)
		_check_allocation(restored, "separate_holds_checkpoint_restored",
			{} if restored else CircleCheckpoint.describe_restore_failure(checkpoint))
		if restored:
			ui.preview_presenter.restore_camera_state(ui.preview_subviewport, camera_state)
			_focus_tip()
			await _wait_frames(2)
			_snapshot("separate_baseline")
			var original: Dictionary = snapshots.continuous_baseline
			var restored_row: Dictionary = snapshots.separate_baseline
			allocation_report["restored_baseline_exact_equality"] = {
				"bones": original.bones == restored_row.bones,
				"weapon_world": original.weapon_world == restored_row.weapon_world,
				"node": original.node == restored_row.node,
				"wrist_cache": original.wrist_cache == restored_row.wrist_cache}
			allocation_report.gestures.append(await _direction_sequence("separate", true))
	allocation_report["authored_after_unsaved"] = _authored_nodes(draft)
	allocation_report["snapshots"] = snapshots
	allocation_report["images"] = capture_images
	allocation_report["trace_rows"] = direction_sample_serial
	if trace_file != null:
		trace_file.close()
		trace_file = null

func _control_target() -> StringName:
	return &"pommel" if String(options.get("control", "tip")) == "pommel" else &"tip"

func _drag_delta(distance_px: float) -> Vector2:
	return Vector2(0.0, distance_px) if String(options.get("drag-axis", "x")) == "y" else Vector2(distance_px, 0.0)

func _focus_tip() -> void:
	circle_ui.session_state.current_focus = _control_target()
	circle_ui.preview_presenter.refresh_focus_visuals(circle_ui.preview_view_container, circle_ui.preview_subviewport,
		circle_ui.call("_get_active_draft"), circle_ui.get_selected_motion_node_index(), _control_target(), circle_ui.call("_get_active_baked_profile"))

func _controlled_screen_now() -> Variant:
	var point: Vector3 = circle_weapon.to_global(circle_weapon.get_meta("weapon_" + String(_control_target()) + "_local", Vector3.ZERO))
	return null if circle_camera.is_position_behind(point) else circle_camera.unproject_position(point)

func _direction_sequence(label: String, separate_holds: bool) -> Dictionary:
	var result := {"label": label, "separate_holds": separate_holds, "stages": [], "engaged": false}
	var press_position := Vector2.ZERO
	var right_px := maxf(float(options.get("right-px", "100")), 1.0)
	var right_seconds := maxf(float(options.get("right-seconds", "1")), 0.05)
	var left_px := maxf(float(options.get("left-px", "35")), 1.0)
	var left_seconds := maxf(float(options.get("left-seconds", "0.35")), 0.05)
	var stages := [["right_first", right_px, right_seconds],
		["left_backtrack", -left_px, left_seconds], ["right_again", right_px, right_seconds]]
	for stage: Array in stages: stage[1] *= -1.0 if float(options.get("first-direction", "1")) < 0.0 else 1.0
	for stage_index: int in stages.size():
		var spec: Array = stages[stage_index]
		var stage_label := label + "_" + String(spec[0])
		if stage_index == 0 or separate_holds:
			var marker: Variant = circle_ui.preview_presenter.get_authoring_marker_screen_position(
				circle_ui.preview_subviewport, circle_camera, _control_target())
			_check_allocation(marker is Vector2, stage_label + "_visible_" + String(_control_target()) + "_marker")
			if not marker is Vector2:
				break
			press_position = marker
			_snapshot(stage_label + "_before_press")
			_engine_button(press_position, true)
			var engaged: bool = circle_ui.motion_node_editor.get_drag_target() == _control_target() and circle_ui.marker_drag_input.active
			_check_allocation(engaged, stage_label + "_engaged_" + String(_control_target()),
				{"picked": String(circle_ui.motion_node_editor.get_drag_target()), "position": _vec(press_position)})
			result.engaged = engaged
			_sample(stage_label + "_pressed")
			if not engaged:
				_engine_button(press_position, false)
				break
		var stage: Dictionary = await _linear_input(stage_label, float(spec[1]), float(spec[2]))
		stage["stage_end_drain"] = await _await_direction_input_drained(stage_label + "_stage_end")
		result.stages.append(stage)
		_snapshot(stage_label + "_end")
		if separate_holds or stage_index == stages.size() - 1 or not bool(stage.stage_end_drain.drained):
			var release_started := Time.get_ticks_usec()
			_engine_button(press_position, false)
			var release_ms := float(Time.get_ticks_usec() - release_started) / 1000.0
			_sample(stage_label + "_released", {"release_ms": release_ms})
			for settle: int in 4:
				await process_frame
				_sample(stage_label + "_settle")
			await _image(stage_label + "_released")
		if not bool(stage.stage_end_drain.drained):
			break
	_snapshot(label + "_finished")
	return result

func _linear_input(label: String, distance_px: float, seconds: float) -> Dictionary:
	if options.has("step-px"):
		return await _fixed_step_input(label, signf(distance_px))
	var started := Time.get_ticks_usec()
	var previous := 0.0
	var samples := 0
	var largest_gap_ms := 0.0
	var last := started
	var first_row: Dictionary = _sample(label + "_start")
	var max_screen_distance := 0.0
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		largest_gap_ms = maxf(largest_gap_ms, float(now - last) / 1000.0)
		last = now
		var ratio := clampf(float(now - started) / (seconds * 1000000.0), 0.0, 1.0)
		var offset := distance_px * ratio
		var delta := _drag_delta(offset - previous)
		previous = offset
		var before: Dictionary = _sample(label + "_before_input", {"stage_fraction": ratio})
		var event := InputEventMouseMotion.new()
		event.screen_relative = delta
		event.relative = delta
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		samples += 1
		_sample(label + "_after_input", {"stage_fraction": ratio, "requested_relative_px": _vec(delta), "requested_total_px": offset})
		if before.controlled_screen is Array and first_row.controlled_screen is Array:
			var point := Vector2(before.controlled_screen[0], before.controlled_screen[1])
			var start := Vector2(first_row.controlled_screen[0], first_row.controlled_screen[1])
			max_screen_distance = maxf(max_screen_distance, point.distance_to(start))
		if ratio >= 1.0:
			break
	_check_allocation(samples > 0, label + "_input_delivered", {"samples": samples})
	return {"label": label, "requested_distance_px": distance_px, "requested_seconds": seconds,
		"delivered_samples": samples, "elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"max_frame_gap_ms": largest_gap_ms, "observed_max_controlled_screen_displacement_px": max_screen_distance}

func _fixed_step_input(label: String, direction: float) -> Dictionary:
	var step_px := maxf(float(options.get("step-px", "3")), 0.01)
	var count := clampi(int(options.get("right-steps" if direction > 0.0 else "left-steps", "12")), 1, 100)
	var started := Time.get_ticks_usec()
	var delivered := 0
	var steps: Array = []
	_sample(label + "_start")
	for step_index: int in count:
		# Each event gets its own process frame and a completed input/solve drain.
		# Wall-clock stalls therefore cannot erase the left/backtrack stage.
		await process_frame
		var details := {"step_index": step_index + 1, "requested_steps": count,
			"requested_relative_px": _vec(_drag_delta(step_px * direction)),
			"requested_total_px": (step_index + 1) * step_px * direction}
		_sample(label + "_before_input", details)
		var event := InputEventMouseMotion.new()
		event.screen_relative = _drag_delta(step_px * direction)
		event.relative = event.screen_relative
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		delivered += 1
		_sample(label + "_after_input", details)
		var drain: Dictionary = await _await_direction_input_drained(label + "_step_%02d" % (step_index + 1))
		steps.append({"step_index": step_index + 1, "drain": drain})
		if not bool(drain.drained):
			break
	_check_allocation(delivered == count, label + "_fixed_inputs_delivered", {"requested": count, "delivered": delivered})
	return {"label": label, "mode": "fixed_samples", "step_px": step_px * direction,
		"requested_steps": count, "requested_distance_px": count * step_px * direction,
		"delivered_samples": delivered, "steps": steps,
		"elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0}

func _await_direction_input_drained(label: String) -> Dictionary:
	var started := Time.get_ticks_msec()
	var deadline := started + 5000
	var frames := 0
	var drained := false
	while Time.get_ticks_msec() < deadline:
		await process_frame
		frames += 1
		var pending_input: Vector2 = circle_ui.marker_drag_input.get("_pending_relative")
		drained = pending_input.is_zero_approx() and not circle_ui.preview_drag_refresh_pending
		if drained:
			break
	var result := {"drained": drained, "frames_waited": frames, "elapsed_ms": Time.get_ticks_msec() - started}
	_sample(label + "_drained" if drained else label + "_drain_timeout", result)
	_check_allocation(drained, label + "_input_and_solver_drained", result)
	return result

func _sample(label: String, extra: Dictionary = {}) -> Dictionary:
	var row: Dictionary = super._sample(label, extra)
	direction_sample_serial += 1
	row["serial"] = direction_sample_serial
	row["process_frame"] = Engine.get_process_frames()
	row["monotonic_usec"] = Time.get_ticks_usec()
	row["body_support_blend"] = (circle_ui.call("_get_active_motion_node") as CombatAnimationMotionNode).body_support_blend
	row["candidate"] = _node(circle_ui.preview_drag_override_node)
	row["transaction_target"] = String(circle_ui.preview_drag_target)
	row["input_pending_relative_px"] = _vec(circle_ui.marker_drag_input.get("_pending_relative"))
	row["input_sample_usec"] = circle_ui.marker_drag_input.get("_sample_usec")
	row["drag_last_refresh_msec"] = circle_ui.preview_drag_last_refresh_msec
	row["drag_refresh_interval_msec"] = circle_ui.call("_get_preview_drag_refresh_interval_msec")
	row["forearm_failure"] = _json(circle_ui.preview_drag_forearm_failure)
	var tip_world: Vector3 = circle_weapon.to_global(circle_weapon.get_meta("weapon_tip_local", Vector3.ZERO))
	row["tip_screen"] = _vec(circle_camera.unproject_position(tip_world)) if not circle_camera.is_position_behind(tip_world) else null
	var controlled: Variant = _controlled_screen_now()
	row["controlled_screen"] = _vec(controlled) if controlled is Vector2 else null
	row["controlled_marker"] = String(_control_target())
	row["manipulator"] = _json(circle_ui.preview_presenter.weapon_motion_manipulator.capture_state())
	var allocation: Dictionary = circle_root.get_meta("weapon_motion_allocation_result", {})
	var adapter: Variant = allocation.get("motion_adapter")
	if adapter is Object and is_instance_valid(adapter):
		var context := {}
		for key: String in ["q", "lower", "upper", "groups", "arms", "torso", "policy", "start_allowance", "timings", "storage_validation_failures", "storage_validation_last_failure", "allocation_start_usec"]:
			var value: Variant = adapter.get(key)
			context[key] = _json(Array(value)) if value is PackedFloat64Array else _json(value)
		var request: Dictionary = adapter.get("request")
		var request_values := {}
		for key: String in ["mode", "previous_weapon", "target_weapon", "contact_local", "primary_slot", "support_slot", "hand_in_weapon_by_slot", "contact_anchor_world"]:
			if request.has(key):
				request_values[key] = _json(request[key])
		context["request"] = request_values
		row["adapter_context"] = context
	# Bones are already fully recorded. Avoid repeating the accepted-payload
	# skeleton a second time in every row; retain search/limits/cost/result facts.
	for key: String in ["accepted_pose", "accepted_payload", "motion_adapter"]:
		(row.allocator as Dictionary).erase(key)
	if trace_file != null:
		trace_file.store_line(JSON.stringify(row))
	# Stream the full trace to disk rather than keeping all skeleton copies live.
	trace_rows.clear()
	return row

func _node(node: CombatAnimationMotionNode) -> Dictionary:
	var result: Dictionary = super._node(node)
	if node != null:
		result["body_support_blend"] = node.body_support_blend
	return result
