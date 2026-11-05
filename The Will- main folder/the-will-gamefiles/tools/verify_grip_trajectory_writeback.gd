extends "res://tools/verify_grip_alignment_entry.gd"

## Real station, isolated library. Existing-node acquisition must reconcile
## stale trajectory endpoints with the displayed acquired weapon, once only.
## --phase=write --hands=R --weapon=Broken_Balde_v1 --slot=skill_slot_2 --out=<fresh-dir>
## A separate --phase=read --input=<write-dir> uses the inherited cold checks.
## The fixture simulates stale authored coordinates, not a complete Forge rebuild.
func _reopen_write(ui: CombatAnimationStationUI, side: String) -> void:
	_check_allocation(ui.reset_active_draft_to_baseline(), "isolated_reset")
	var ready := await _await_recorded_reset_baseline(ui)
	_check_allocation(ready.get("ready", false), "baseline_recorded", ready)
	if not ready.get("ready", false): return
	ui.set_selected_motion_node_transition_duration(0.2, false)
	await _reopen_capture(ui)
	for index: int in [2, 3]:
		var added := ui.insert_motion_node_after_selection()
		var recording := await _await_allocation_recording(ui)
		_check_allocation(added and recording.ready, "R_adds_N%02d" % index, recording)
		if not recording.ready: return
		var moved := await _reopen_small_movements(ui, side)
		_check_allocation(moved.valid, "N%02d_UI_positions" % index, moved)
		ui.set_selected_motion_node_transition_duration(0.1 * float(index + 1), false)
		await _reopen_capture(ui)
	var draft: CombatAnimationDraft = ui.call("_get_active_draft")
	_check_allocation(ui.select_motion_node(2), "select_existing_middle_node")
	await _await_allocation_recording(ui)
	ready = await _reopen_await_bound(ui, side)
	if not ready.ready:
		_check_allocation(false, "middle_node_binding_ready", ready)
		return
	_check_allocation(ui.set_selected_motion_node_pommel_curve_in(Vector3(0.0, 0.003, 0.0), false), "explicit_curve_offset_authored")
	await _reopen_capture(ui)
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var visible: Array = draft.get_action_motion_node_chain()
	var neighbour_signatures := [BoundaryPose.node_pose_signature(visible[0]), BoundaryPose.node_pose_signature(visible[2])]
	var settings := _trajectory_settings(visible)
	var actor := _get_preview_actor(ui) as PlayerHumanoidRig
	var weapon := _get_preview_held_item(ui)
	var owner: Node = actor.get_node("PreparedGripAcquisition")
	var preview_root: Node3D = ui.call("_get_preview_root")
	var body := _alignment_body_snapshot(actor.skeleton)

	# Deliberately leave old trajectory coordinates beside a genuine solved pose.
	# Perturbing the weapon alone could return it to identical old coordinates,
	# failing to exercise writeback. No solved packets or bone poses are fabricated.
	var stale_offset := Vector3(0.06, 0.04, -0.03)
	node.tip_position_local += stale_offset
	node.pommel_position_local += stale_offset
	var stale_tip := node.tip_position_local
	var stale_pommel := node.pommel_position_local
	var resolved: Dictionary = preview_root.get_meta("resolved_playback_state", {}).duplicate(true)
	for key: StringName in [&"tip_position_local", &"tip_position_origin_id", &"pommel_position_local", &"pommel_position_origin_id"]:
		resolved[key] = node.get(key)
	resolved.erase("trajectory_static_visual_signature")
	preview_root.set_meta("resolved_playback_state", resolved)
	preview_root.remove_meta("trajectory_static_visual_signature")
	ui.call("_refresh_endpoint_motion_visuals")
	var stale_visual_signature: String = preview_root.get_meta("trajectory_static_visual_signature", "")
	var stale_mesh := _trajectory_mesh_hash(preview_root)
	var stale_tangent := ui.motion_node_editor.resolve_effective_curve_handle(visible, 0, true, false)
	var solve_count := _reopen_solve_count()
	ui.grip_reacquire_button.pressed.emit()
	ready = await _reopen_await_bound(ui, side)
	_check_allocation(ready.ready, "existing_node_reacquired", ready)
	if not ready.ready: return
	await _reopen_capture(ui)
	var frame := ui.preview_presenter.get_prepared_grip_display_state(ui.preview_subviewport, node)
	_check_allocation(frame.get("available", false), "live_acquired_frame_available")
	if not frame.get("available", false): return
	var error := maxf(node.tip_position_local.distance_to(frame.tip_position_local), node.pommel_position_local.distance_to(frame.pommel_position_local))
	_check_allocation(error <= 0.000005, "recorded_endpoints_equal_live_weapon", {"maximum_error_m": error})
	_check_allocation(node.tip_position_local.distance_to(stale_tip) > 0.01 and node.pommel_position_local.distance_to(stale_pommel) > 0.01, "stale_endpoints_replaced_without_pointer_nudge")
	_check_allocation(node.weapon_orientation_degrees.is_equal_approx(frame.weapon_orientation_degrees) and is_equal_approx(node.weapon_roll_degrees, frame.weapon_roll_degrees), "recorded_orientation_matches_live_weapon")
	_check_allocation(node.prepared_pose_signature == BoundaryPose.node_pose_signature(node) and _reopen_has_packet(node), "corrected_pose_signature_and_grip_packet")
	_check_allocation(owner.pending_authoring_frame_serial() == -1, "completion_receipt_consumed")
	_check_allocation(_alignment_body_unchanged(actor.skeleton, body), "acquisition_writeback_preserves_body_and_wrists", {"differences": alignment_body_differences.duplicate(true)})
	_check_allocation(_trajectory_settings(visible) == settings, "timings_and_explicit_curve_offsets_preserved")
	_check_allocation(neighbour_signatures == [BoundaryPose.node_pose_signature(visible[0]), BoundaryPose.node_pose_signature(visible[2])], "neighbour_endpoint_poses_unchanged")
	var visual_signature: String = preview_root.get_meta("trajectory_static_visual_signature", "")
	_check_allocation(not visual_signature.is_empty() and visual_signature != stale_visual_signature, "guide_signature_rebuilt_immediately")
	var updated_mesh := _trajectory_mesh_hash(preview_root)
	_check_allocation(not updated_mesh.is_empty() and updated_mesh != stale_mesh, "actual_guide_mesh_rebuilt")
	var display_tip: Vector3 = preview_root.get_meta("display_selected_tip_position_local", Vector3.INF)
	var display_pommel: Vector3 = preview_root.get_meta("display_selected_pommel_position_local", Vector3.INF)
	_check_allocation(display_tip.distance_to(node.tip_position_local) <= 0.000005 and display_pommel.distance_to(node.pommel_position_local) <= 0.000005, "displayed_endpoints_match_recorded_endpoints")
	var updated_tangent := ui.motion_node_editor.resolve_effective_curve_handle(visible, 0, true, false)
	_check_allocation(not updated_tangent.is_equal_approx(stale_tangent), "adjacent_automatic_tangent_adapts")
	_check_allocation(_reopen_solve_count() - solve_count == 1, "one_primary_acquisition_for_correction", {"new_acquisitions": _reopen_solve_count() - solve_count})
	var after_solve := _reopen_solve_count()
	var recorded := BoundaryPose.node_pose_signature(node)
	for repeat: int in 3:
		ui.call("_refresh_preview_scene")
		await _wait_frames(3)
	_check_allocation(_reopen_solve_count() == after_solve and recorded == BoundaryPose.node_pose_signature(node), "unchanged_refresh_neither_reacquires_nor_rewrites")
	_check_allocation((await _reopen_await_bound(ui, side)).ready, "unchanged_refresh_retains_binding")
	await _trajectory_preview_once(ui)
	await _reopen_save(ui)
	var disk := _reopen_saved_draft(ui)
	_check_allocation(disk != null and disk.baked_runtime_clip != null, "corrected_three_node_skill_saved")
	if disk != null:
		var saved: CombatAnimationMotionNode = disk.motion_node_chain[2]
		_check_allocation(BoundaryPose.node_pose_signature(saved) == recorded and _reopen_has_packet(saved), "saved_middle_node_keeps_corrected_endpoints_and_grip")
	_check_allocation(_reopen_solve_count() == after_solve, "F_and_Save_reuse_acquisition")

func _trajectory_settings(nodes: Array) -> PackedByteArray:
	var values: Array = []
	for node: CombatAnimationMotionNode in nodes:
		values.append([node.transition_duration_seconds, node.tip_curve_in_handle, node.tip_curve_out_handle,
			node.pommel_curve_in_handle, node.pommel_curve_out_handle])
	return var_to_bytes(values)

func _trajectory_mesh_hash(preview_root: Node3D) -> String:
	var mesh_instance := preview_root.find_child("TrajectoryMesh", true, false) as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null: return ""
	var data: Array = []
	for surface: int in mesh_instance.mesh.get_surface_count():
		data.append(mesh_instance.mesh.surface_get_arrays(surface))
	return var_to_bytes(data).hex_encode().sha256_text() if not data.is_empty() else ""

func _trajectory_preview_once(ui: CombatAnimationStationUI) -> void:
	ui.call("_toggle_preview_playback")
	var deadline := Time.get_ticks_msec() + 60000
	while not ui.chain_player.is_playing() and Time.get_ticks_msec() < deadline:
		if not ui.preview_prepare_in_progress and not ui.is_motion_node_recording_pending(): break
		await _wait_frames(1)
	var started := ui.chain_player.is_playing()
	_check_allocation(started, "F_reads_corrected_chain", {"status": ui.footer_status_label.text})
	while ui.chain_player.is_playing() and Time.get_ticks_msec() < deadline:
		await _wait_frames(1)
	_check_allocation(started and not ui.chain_player.is_playing(), "F_corrected_chain_completes")
