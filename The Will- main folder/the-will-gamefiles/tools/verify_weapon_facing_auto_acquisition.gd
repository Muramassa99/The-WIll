extends "res://tools/verify_grip_alignment_entry.gd"

## Isolated real cube input: press/hold suspends fitting; release resumes once.
## --phase=write --hands=R --weapon=Broken_Balde_v1 --slot=skill_slot_2 --out=<fresh-dir>
## Inherited --phase=read --input=<write-dir> exercises a separate cold process.
## --phase=read --legacy=true --legacy-facing=true tests old manual-only warnings.
func _reopen_read(ui: CombatAnimationStationUI, side: String, solve_before: int, legacy: bool) -> void:
	if not legacy or String(options.get("legacy-facing", "false")) != "true":
		await super._reopen_read(ui, side, solve_before, legacy)
		return
	var ready := await _reopen_await_bound(ui, side)
	_check_allocation(ready.ready, "old_facing_warning_automatically_recovers_on_open", ready)
	if not ready.ready: return
	await _reopen_capture(ui)
	_check_allocation(_reopen_solve_count() - solve_before == 1, "one_automatic_acquisition_on_cold_open")
	_check_allocation(not ui.preview_presenter.is_weapon_facing_reacquisition_required(ui.preview_subviewport) and _reopen_has_packet(ui.call("_get_active_motion_node")), "old_manual_warning_replaced_with_current_grip")
	var draft: CombatAnimationDraft = ui.call("_get_active_draft")
	for index: int in range(1, draft.motion_node_chain.size()):
		ui.select_motion_node(index)
		await _await_allocation_recording(ui)
		ready = await _reopen_await_bound(ui, side)
		_check_allocation(ready.ready, "legacy_facing_N%02d_recovers_without_button" % index, ready)
		if not ready.ready: return
		await _reopen_capture(ui)
	var completed := _reopen_solve_count()
	ui.call("_refresh_preview_scene")
	await _wait_frames(5)
	_check_allocation(_reopen_solve_count() == completed, "legacy_facing_refresh_does_not_repeat")
	await _facing_preview_once(ui)
	await _reopen_save(ui)
	_check_allocation(_reopen_solve_count() == completed, "legacy_facing_F_Save_reuse_recovery")

func _reopen_write(ui: CombatAnimationStationUI, side: String) -> void:
	_check_allocation(ui.reset_active_draft_to_baseline(), "isolated_reset")
	var ready := await _await_recorded_reset_baseline(ui)
	_check_allocation(ready.get("ready", false), "baseline_recorded", ready)
	if not ready.get("ready", false): return
	ui.set_selected_motion_node_transition_duration(0.2, false)
	ui.session_state.current_focus = &"weapon_facing"
	ui.call("_refresh_preview_scene")
	await _wait_frames(3)
	var actor := _get_preview_actor(ui) as PlayerHumanoidRig
	var weapon := _get_preview_held_item(ui)
	var owner: Node = actor.get_node("PreparedGripAcquisition")
	var context: Dictionary = ui.preview_presenter.call("_weapon_roll_context", ui.preview_subviewport)
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var display: CombatAnimationMotionNode = ui.call("_build_display_motion_node_for_viewport_pick", node)
	var camera: Camera3D = ui.call("_get_preview_camera")
	var handle: Vector3 = ui.motion_node_editor.get_weapon_facing_handle_local(display)
	var pointer: Vector2 = camera.unproject_position((context.trajectory as Node3D).to_global(handle))
	var initial_frame := weapon.global_transform
	var all_bones := _facing_all_bones(actor.skeleton)
	var solve_count := _reopen_solve_count()
	_facing_button(ui, pointer, true)
	_check_allocation(ui.preview_weapon_facing_dragging, "cube_press_starts_gesture")
	await _wait_frames(3)
	_facing_button(ui, pointer, false)
	await _wait_frames(5)
	_check_allocation(_reopen_solve_count() == solve_count and not owner.is_manual_reacquisition_required(), "settled_no_motion_click_does_not_acquire")
	_check_allocation(weapon.global_transform.is_equal_approx(initial_frame) and _facing_all_bones_match(actor.skeleton, all_bones), "no_motion_click_preserves_weapon_and_all_bones")
	_facing_button(ui, pointer, true)
	var previous := pointer
	for offset: float in [10.0, 24.0]:
		var event := InputEventMouseMotion.new()
		event.position = pointer + Vector2(offset, 0.0)
		event.relative = event.position - previous
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		ui.call("_on_preview_gui_input", event)
		previous = event.position
		await _wait_frames(3)
		_check_allocation(_facing_all_bones_match(actor.skeleton, all_bones), "held_cube_keeps_all_bones_fixed_%d" % int(offset))
		_check_allocation(_reopen_solve_count() == solve_count, "held_cube_does_not_start_acquisition_%d" % int(offset))
	var chosen := weapon.global_transform
	_check_allocation(not chosen.basis.is_equal_approx(initial_frame.basis), "cube_rotates_weapon")
	var expected_basis := _facing_aligned_basis(actor, weapon, side, chosen.basis)
	var body := _alignment_body_snapshot(actor.skeleton)
	_facing_button(ui, previous, false)
	_check_allocation(not ui.preview_weapon_facing_dragging, "release_ends_gesture")
	ready = await _reopen_await_bound(ui, side)
	_check_allocation(ready.ready, "release_automatically_reacquires", ready)
	if not ready.ready: return
	await _reopen_capture(ui)
	_check_allocation(_reopen_solve_count() - solve_count == 1, "release_starts_exactly_one_primary_solve")
	_check_allocation(not owner.is_manual_reacquisition_required() and owner.pending_authoring_frame_serial() == -1, "automatic_result_recorded_and_receipt_consumed")
	var angular_error := _facing_basis_error(expected_basis, weapon.global_basis)
	_check_allocation(angular_error <= 0.025, "acquisition_preserves_chosen_facing_with_required_axis_alignment", {"error_degrees": angular_error, "swing_from_user_frame_degrees": _facing_basis_error(chosen.basis, expected_basis)})
	_check_allocation(_alignment_body_unchanged(actor.skeleton, body), "automatic_acquisition_keeps_body_and_wrists_fixed", {"differences": alignment_body_differences.duplicate(true)})
	var frame := ui.preview_presenter.get_prepared_grip_display_state(ui.preview_subviewport, node)
	_check_allocation(frame.get("available", false) and node.tip_position_local.distance_to(frame.get("tip_position_local", Vector3.INF)) <= 0.000005 and node.pommel_position_local.distance_to(frame.get("pommel_position_local", Vector3.INF)) <= 0.000005, "corrected_endpoints_written_back")
	_check_allocation(node.prepared_pose_signature == BoundaryPose.node_pose_signature(node) and _reopen_has_packet(node), "current_node_records_pose_and_grip")
	var preview_root: Node3D = ui.call("_get_preview_root")
	_check_allocation((preview_root.get_meta("display_selected_tip_position_local", Vector3.INF) as Vector3).distance_to(node.tip_position_local) <= 0.000005 and not String(preview_root.get_meta("trajectory_static_visual_signature", "")).is_empty(), "trajectory_display_synchronized")
	var after_solve := _reopen_solve_count()
	for repeat: int in 3:
		ui.call("_refresh_preview_scene")
		await _wait_frames(3)
	_check_allocation(_reopen_solve_count() == after_solve and not owner.is_manual_reacquisition_required(), "refresh_does_not_repeat_acquisition")
	var added := ui.insert_motion_node_after_selection()
	var recording := await _await_allocation_recording(ui)
	_check_allocation(added and recording.ready, "R_records_automatic_grip_and_adds_node")
	if not recording.ready: return
	var moved := await _reopen_small_movements(ui, side)
	_check_allocation(moved.valid, "next_node_remains_editable", moved)
	await _reopen_capture(ui)
	await _facing_preview_once(ui)
	await _reopen_save(ui)
	var disk := _reopen_saved_draft(ui)
	_check_allocation(disk != null and disk.baked_runtime_clip != null and _reopen_has_packet(disk.motion_node_chain[1]), "automatic_grip_saved_for_cold_reuse")
	_check_allocation(_reopen_solve_count() == after_solve, "R_F_Save_reuse_automatic_grip")

func _facing_button(ui: CombatAnimationStationUI, pointer: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pointer
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	ui.call("_on_preview_gui_input", event)

func _facing_all_bones(skeleton: Skeleton3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for index: int in skeleton.get_bone_count(): result.append(skeleton.get_bone_global_pose(index))
	return result

func _facing_all_bones_match(skeleton: Skeleton3D, previous: Array[Transform3D]) -> bool:
	if previous.size() != skeleton.get_bone_count(): return false
	for index: int in previous.size():
		if not previous[index].is_equal_approx(skeleton.get_bone_global_pose(index)): return false
	return true

func _facing_aligned_basis(actor: PlayerHumanoidRig, weapon: Node3D, side: String, chosen: Basis) -> Basis:
	var skeleton := actor.skeleton
	var index := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("CC_Base_%s_Index1" % side)).origin
	var pinky := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("CC_Base_%s_Pinky1" % side)).origin
	var target := (index - pinky).normalized()
	if weapon.get_meta("grip_style_mode", CraftedItemWIP.GRIP_NORMAL) == CraftedItemWIP.GRIP_REVERSE: target = -target
	var axis: Vector3 = chosen * ((weapon.get_meta("primary_grip_span_end_local") as Vector3) - (weapon.get_meta("primary_grip_span_start_local") as Vector3))
	var tip: Vector3 = chosen * ((weapon.get_meta("weapon_tip_local") as Vector3) - (weapon.get_meta("weapon_pommel_local") as Vector3))
	if axis.dot(tip) < 0.0: axis = -axis
	return Basis(Quaternion(axis.normalized(), target)) * chosen

func _facing_basis_error(a: Basis, b: Basis) -> float:
	var relative := (a.orthonormalized().get_rotation_quaternion() * b.orthonormalized().get_rotation_quaternion().inverse()).normalized()
	return rad_to_deg(2.0 * atan2(Vector3(relative.x, relative.y, relative.z).length(), absf(relative.w)))

func _facing_preview_once(ui: CombatAnimationStationUI) -> void:
	ui.call("_toggle_preview_playback")
	var deadline := Time.get_ticks_msec() + 60000
	while not ui.chain_player.is_playing() and Time.get_ticks_msec() < deadline:
		if not ui.preview_prepare_in_progress and not ui.is_motion_node_recording_pending(): break
		await _wait_frames(1)
	var started := ui.chain_player.is_playing()
	_check_allocation(started, "F_plays_automatically_reacquired_grip", {"status": ui.footer_status_label.text})
	while ui.chain_player.is_playing() and Time.get_ticks_msec() < deadline: await _wait_frames(1)
	_check_allocation(started and not ui.chain_player.is_playing(), "F_completes")
