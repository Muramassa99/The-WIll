extends "res://tools/verify_skill_grip_reopen.gd"

## Observe the user's saved Skill 3 in an isolated in-memory library. No Reset,
## no skill Save, no anatomy/solver overrides. Synthetic engine input exercises
## the real captured-mouse route; full skeleton samples are stored as JSONL.
const CircleCheckpoint = preload("res://runtime/combat/combat_animation_render_checkpoint.gd")
var trace_rows: Array = []
var phase := "open"
var snapshots := {}
var circle_ui: CombatAnimationStationUI
var circle_actor: PlayerHumanoidRig
var circle_weapon: Node3D
var circle_camera: Camera3D
var circle_root: Node3D
var capture_images: Array = []

func _reopen_write(ui: CombatAnimationStationUI, side: String) -> void:
	circle_ui = ui
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = Vector2i(1600, 1000)
	await _wait_frames(3)
	var ready := await _reopen_await_bound(ui, side)
	allocation_report["scope"] = "Existing Skill 3 F playback, then node 3 same cube twice/opposite cube five circles in three seconds; paired Tip directions. No Reset/Save/production edits."
	allocation_report["opening_grip"] = ready
	circle_actor = _get_preview_actor(ui) as PlayerHumanoidRig
	circle_weapon = _get_preview_held_item(ui)
	circle_camera = ui.call("_get_preview_camera")
	circle_root = ui.call("_get_preview_root")
	if circle_actor == null or circle_weapon == null:
		_check_allocation(false, "actor_and_weapon_loaded")
		return
	ui.preview_drag_speed_control._set_user_speed(900.0, true)
	# Camera-only framing option; changing view does not author the skill.
	if options.has("zoom-out"):
		ui.zoom_preview_camera(int(options["zoom-out"]))
	var draft: CombatAnimationDraft = ui.call("_get_active_draft")
	var actions := draft.get_action_motion_node_chain()
	_check_allocation(actions.size() == 3, "saved_skill_has_three_visible_nodes", {"count": actions.size()})
	if actions.size() != 3: return
	allocation_report["authored_before"] = _authored_nodes(draft)
	allocation_report["spine_isolation_enabled"] = circle_actor.is_authoring_arm_spine_isolation_enabled()
	allocation_report["drag_speed"] = ui.marker_drag_input.speed_pixels_per_second
	var skeleton_info := []
	for i in circle_actor.skeleton.get_bone_count():
		skeleton_info.append({"name": circle_actor.skeleton.get_bone_name(i), "parent": circle_actor.skeleton.get_bone_parent(i), "rest": _transform(circle_actor.skeleton.get_bone_rest(i))})
	allocation_report["skeleton"] = skeleton_info
	_snapshot("before_F")
	await _image("before_F")
	var f_started := Time.get_ticks_msec()
	ui.call("_toggle_preview_playback")
	var deadline := Time.get_ticks_msec() + 120000
	while not ui.chain_player.is_playing() and Time.get_ticks_msec() < deadline:
		_sample("F_prepare")
		if not ui.preview_prepare_in_progress and not ui.is_motion_node_recording_pending(): break
		await process_frame
	allocation_report["F_preparation_ms"] = Time.get_ticks_msec() - f_started
	_check_allocation(ui.chain_player.is_playing(), "F_started", {"status": ui.footer_status_label.text})
	var playing_started := Time.get_ticks_msec()
	var image_at := 0
	while ui.chain_player.is_playing() and Time.get_ticks_msec() < deadline:
		_sample("F_playback")
		if Time.get_ticks_msec() - playing_started >= image_at and capture_images.size() < 18:
			await _image("F_%04d" % image_at)
			image_at += 200
		await process_frame
	_check_allocation(not ui.chain_player.is_playing(), "F_finished_naturally")
	await _wait_frames(3)
	_snapshot("after_F")
	await _image("after_F")
	# Last visible node is mandatory. Selection uses the real editor lifecycle.
	var index: int = draft.motion_node_chain.find(actions[2])
	_check_allocation(ui.select_motion_node(index), "selected_visible_node_3", {"index": index})
	await _await_allocation_recording(ui)
	allocation_report["node3_grip"] = await _reopen_await_bound(ui, side)
	_focus_tip()
	await _wait_frames(3)
	_snapshot("node3_before_cubes")
	await _image("node3_before_cubes")
	allocation_report["gestures"] = []
	for spec: Array in [["blue_in_1", &"tip_curve_in"], ["blue_in_2", &"tip_curve_in"], ["orange_out", &"tip_curve_out"]]:
		if spec[1] == &"tip_curve_out" and ui.preview_presenter.get_authoring_marker_screen_position(ui.preview_subviewport, circle_camera, &"tip_curve_out") == null:
			allocation_report["orange_unavailable"] = "Saved last node has zero outgoing handle and no following node; UI does not expose an outgoing cube. No replacement fabricated."
			continue
		var result := await _circle(spec[0], spec[1], 1.0)
		allocation_report.gestures.append(result)
		if not result.get("engaged", false): break
	_snapshot("after_all_cubes")
	# Compare Tip CW/CCW from exactly the same post-cube pose/camera/parameters.
	var trajectory: Node3D = ui.call("_get_preview_trajectory_root")
	var baseline_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node").duplicate(true)
	var checkpoint := CircleCheckpoint.capture(ui.preview_presenter, {"preview_root": circle_root,
		"actor_pivot": circle_root.get_node_or_null(ui.preview_presenter.PREVIEW_ACTOR_PIVOT_NAME), "trajectory_root": trajectory}, false)
	var camera_state := ui.preview_presenter.capture_camera_state(ui.preview_subviewport)
	for direction: float in [1.0, -1.0]:
		ui.motion_node_editor.end_drag()
		ui.call("_clear_preview_drag_override")
		draft.motion_node_chain[index] = baseline_node.duplicate(true)
		ui.call("_invalidate_preview_drag_motion_chain_cache")
		_check_allocation(CircleCheckpoint.restore(ui.preview_presenter, checkpoint), "tip_comparison_restored")
		ui.preview_presenter.restore_camera_state(ui.preview_subviewport, camera_state)
		_focus_tip()
		await _wait_frames(2)
		allocation_report.gestures.append(await _circle("tip_CW" if direction > 0 else "tip_CCW", &"tip", direction))
	allocation_report["authored_after_unsaved"] = _authored_nodes(draft)
	allocation_report["snapshots"] = snapshots
	allocation_report["images"] = capture_images
	allocation_report["trace_rows"] = trace_rows.size()
	var log := FileAccess.open(output_dir.path_join("bone_trace.jsonl"), FileAccess.WRITE)
	for row in trace_rows: log.store_line(JSON.stringify(row))
	log.close()

func _focus_tip() -> void:
	circle_ui.session_state.current_focus = &"tip"
	circle_ui.preview_presenter.refresh_focus_visuals(circle_ui.preview_view_container, circle_ui.preview_subviewport,
		circle_ui.call("_get_active_draft"), circle_ui.get_selected_motion_node_index(), &"tip", circle_ui.call("_get_active_baked_profile"))

func _circle(label: String, target: StringName, direction: float) -> Dictionary:
	_snapshot(label + "_before")
	await _image(label + "_before")
	var position: Variant = circle_ui.preview_presenter.get_authoring_marker_screen_position(circle_ui.preview_subviewport, circle_camera, target)
	var report := {"label": label, "target": String(target), "direction_screen": "CW" if direction > 0 else "CCW", "duration_requested_ms": 3000, "turns_requested": 5, "radius_screen_px": 40.0, "engaged": false}
	if not position is Vector2:
		_check_allocation(false, label + "_marker_exists")
		return report
	_engine_button(position, true)
	report["picked_target"] = String(circle_ui.motion_node_editor.get_drag_target())
	report.engaged = circle_ui.motion_node_editor.get_drag_target() == target and circle_ui.marker_drag_input.active
	_check_allocation(report.engaged, label + "_engaged_exact_target", report)
	if not report.engaged:
		_engine_button(position, false)
		return report
	_sample(label + "_pressed")
	var started := Time.get_ticks_usec()
	var previous := Vector2.ZERO
	var delivered := 0
	var last := started
	var largest_gap := 0.0
	var request_path := 0.0
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		largest_gap = maxf(largest_gap, float(now - last) / 1000.0)
		last = now
		var ratio := clampf(float(now - started) / 3000000.0, 0.0, 1.0)
		var angle := ratio * TAU * 5.0 * direction
		# Start/end at the selected marker; circle centre is 40 px left of it.
		var offset := Vector2(cos(angle) - 1.0, sin(angle)) * 40.0
		var delta := offset - previous
		previous = offset
		request_path += delta.length()
		var event := InputEventMouseMotion.new()
		event.screen_relative = delta
		event.relative = delta
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		delivered += 1
		_sample(label, {"requested_turns": ratio * 5.0, "requested_relative": _vec(delta), "requested_offset": _vec(offset)})
		if ratio >= 1.0: break
	report["drive_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	report["delivered_samples"] = delivered
	report["sampled_requested_path_px"] = request_path
	report["max_frame_gap_ms"] = largest_gap
	_snapshot(label + "_before_release")
	var release_start := Time.get_ticks_usec()
	_engine_button(position, false)
	report["release_ms"] = float(Time.get_ticks_usec() - release_start) / 1000.0
	_snapshot(label + "_immediate_release")
	for settle in 10:
		await process_frame
		_sample(label + "_settle")
	_snapshot(label + "_after")
	await _image(label + "_after")
	report["final_status"] = circle_ui.footer_status_label.text
	return report

func _engine_button(local_position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = circle_ui.preview_view_container.get_global_transform_with_canvas() * local_position
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _snapshot(label: String) -> void:
	var row := _sample(label)
	snapshots[label] = row
	print("CIRCLE_SNAPSHOT ", label, " ", circle_ui.footer_status_label.text)

func _sample(label: String, extra: Dictionary = {}) -> Dictionary:
	var skeleton := circle_actor.skeleton
	var bones := []
	for i in skeleton.get_bone_count():
		bones.append({"local": _transform(skeleton.get_bone_pose(i)), "world": _transform(skeleton.global_transform * skeleton.get_bone_global_pose(i))})
	var node: CombatAnimationMotionNode = circle_ui.call("_get_active_motion_node")
	var effective: CombatAnimationMotionNode = circle_ui.call("_get_effective_preview_motion_node")
	var row := {"ms": Time.get_ticks_msec(), "phase": label, "bones": bones,
		"skeleton_world": _transform(skeleton.global_transform), "weapon_world": _transform(circle_weapon.global_transform),
		"weapon_tip_world": _vec(circle_weapon.to_global(circle_weapon.get_meta("weapon_tip_local", Vector3.ZERO))),
		"weapon_pommel_world": _vec(circle_weapon.to_global(circle_weapon.get_meta("weapon_pommel_local", Vector3.ZERO))),
		"selected": circle_ui.get_selected_motion_node_index(), "node": _node(node), "effective_node": _node(effective),
		"playing": circle_ui.chain_player.is_playing(), "drag_target": String(circle_ui.motion_node_editor.get_drag_target()),
		"pointer": _vec(circle_ui.marker_drag_input.pointer_position), "pending": circle_ui.preview_drag_refresh_pending,
		"refresh_ms": circle_ui.preview_drag_last_refresh_cost_msec, "status": circle_ui.footer_status_label.text,
		"wrist_R": _json(circle_actor.capture_wrist_motion_start_state(&"hand_right")),
		"wrist_L": _json(circle_actor.capture_wrist_motion_start_state(&"hand_left")),
		"wrist_cache": _json(circle_actor.get("_wrist_motion_states")),
		"arm_R": _json(circle_actor.get_authoring_upperarm_roll_control_state(&"hand_right")),
		"arm_L": _json(circle_actor.get_authoring_upperarm_roll_control_state(&"hand_left")),
		"allocator": _json(circle_root.get_meta("weapon_motion_allocation_result", {})),
		"prepared_restore": _json(circle_root.get_meta("prepared_authoring_pose_restore", {})),
		"retained_grip": circle_root.has_meta("retained_authoring_grip_pose"),
		"resolved": _resolved_flags(circle_root.get_meta("resolved_playback_state", {}))}
	row.merge(extra)
	trace_rows.append(row)
	return row

func _resolved_flags(resolved: Dictionary) -> Dictionary:
	var result := {}
	for key: String in ["active", "prepared_grip_lock", "authoring_drag_lightweight", "selected_node_index", "tip_position_local", "pommel_position_local", "weapon_roll_degrees", "grip_resolve_reason"]:
		if resolved.has(key): result[key] = _json(resolved[key])
	return result

func _authored_nodes(draft: CombatAnimationDraft) -> Array:
	var result := []
	for motion: CombatAnimationMotionNode in draft.motion_node_chain: result.append(_node(motion))
	return result

func _node(node: CombatAnimationMotionNode) -> Dictionary:
	if node == null: return {}
	return {"id": String(node.node_id), "tip": _vec(node.tip_position_local), "pommel": _vec(node.pommel_position_local),
		"tip_in": _vec(node.tip_curve_in_handle), "tip_out": _vec(node.tip_curve_out_handle),
		"pom_in": _vec(node.pommel_curve_in_handle), "pom_out": _vec(node.pommel_curve_out_handle),
		"weapon_roll": node.weapon_roll_degrees, "orientation": _vec(node.weapon_orientation_degrees),
		"arm_R": node.right_upperarm_roll_degrees, "arm_L": node.left_upperarm_roll_degrees,
		"signature": BoundaryPose.node_pose_signature(node)}

func _transform(t: Transform3D) -> Dictionary:
	var q := t.basis.orthonormalized().get_rotation_quaternion().normalized()
	return {"p": _vec(t.origin), "q": [q.x, q.y, q.z, q.w], "scale": _vec(t.basis.get_scale())}

func _vec(v: Variant) -> Array:
	if v is Vector2: return [v.x, v.y]
	return [v.x, v.y, v.z]

func _json(value: Variant) -> Variant:
	if value is Vector2 or value is Vector3: return _vec(value)
	if value is Quaternion or value is Vector4: return [value.x, value.y, value.z, value.w]
	if value is Transform3D: return _transform(value)
	if value is Basis: return _transform(Transform3D(value, Vector3.ZERO))
	if value is Dictionary:
		var result := {}
		for key in value: result[String(key)] = _json(value[key])
		return result
	if value is Array or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedVector3Array or value is PackedVector4Array:
		var result := []
		for item in value: result.append(_json(item))
		return result
	if value is Object: return str(value)
	return value

func _image(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := output_dir.path_join(label + ".png")
	circle_ui.preview_subviewport.get_texture().get_image().save_png(path)
	capture_images.append(path)

func _complete_allocation() -> Dictionary:
	allocation_report.complete = true
	for check: Dictionary in allocation_report.checks:
		if not check.passed: allocation_report.complete = false
	print("CIRCLE_AUDIT technical_complete=%s gestures=%d" % [allocation_report.complete, allocation_report.get("gestures", []).size()])
	return allocation_report
