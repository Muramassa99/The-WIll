extends "res://tools/diagnose_skill_crafter_elbow_correction.gd"

## Uses the existing isolated-library station harness. Original player files are
## read-only; all edits and optional Save belong to the cloned fixture library.
## Example: --weapon=Broken_Balde_v1 --slot=skill_slot_2 --hands=R,L
## --elevations=0 --reuse-station=true --out=<fresh directory>
var allocation_report: Dictionary = {}

func _run_thrust(ui: CombatAnimationStationUI, side: String, _elevation: float) -> Dictionary:
	allocation_report = {"complete": false, "side": side, "checks": [], "requests": [],
		"scope": "Actual SC APIs on isolated weapon clone; fixed contact, late writers, R recording, F and isolated Save. No original player save modified."}
	if ui.active_wip_library == null or not ui.active_wip_library.save_file_path.begins_with(output_dir + "/isolated_"):
		return allocation_report.merged({"reason": "isolated_library_required"})
	# The inherited exploration harness suppresses persistence. This verifier
	# explicitly exercises the real Save path, restricted to its isolated clone.
	ui.set_meta("verification_skip_persistence", false)
	if not ui.reset_active_draft_to_baseline():
		return allocation_report.merged({"reason": "reset_failed"})
	var ready: Dictionary = await _await_recorded_reset_baseline(ui)
	allocation_report.readiness = ready
	if not ready.get("ready", false):
		return allocation_report.merged({"reason": "baseline_not_ready", "grip_readiness": _grip_readiness(ui, side), "status": ui.footer_status_label.text})
	var actor: PlayerHumanoidRig = _get_preview_actor(ui) as PlayerHumanoidRig
	var prop: Node3D = _get_preview_held_item(ui)
	var sk: Skeleton3D = actor.skeleton
	var hand_index := sk.find_bone("CC_Base_" + side + "_Hand")
	var relation: Transform3D = prop.global_transform.affine_inverse() * sk.global_transform * sk.get_bone_global_pose(hand_index)
	if DisplayServer.get_name() != "headless":
		allocation_report.baseline_image = await _capture_frame(ui, actor, side, output_dir.path_join(side + "_baseline.png"))
	ui.set_selected_motion_node_transition_duration(0.2, false)
	var progress := 0
	var request_index := 0
	var retained_tip_anchor: Variant = null
	for degrees: float in [3.0, -1.0, 3.0, -1.0]:
		request_index += 1
		var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
		var display: CombatAnimationMotionNode = ui.call("_build_authoring_motion_node_baseline", node)
		var orbit: Dictionary = ui.preview_presenter.resolve_motion_node_tip_grip_orbit(ui.preview_subviewport, display, display.tip_position_local)
		if not orbit.get("available", false):
			return allocation_report.merged({"reason": "grip_orbit_unavailable", "orbit": orbit})
		var pivot: Vector3 = orbit.tip_grip_pivot_local
		var requested := pivot + Basis(Vector3.RIGHT, deg_to_rad(degrees)) * (display.tip_position_local - pivot)
		var scoped := request_index == 4
		var started: int = Time.get_ticks_usec()
		if scoped: ui.call("_begin_preview_authoring_lookup_scope")
		var changed: bool = ui.set_selected_motion_node_tip_position(requested, false)
		if scoped: ui.call("_end_preview_authoring_lookup_scope")
		var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
		await _wait_frames(3)
		var after_node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
		var after_display: CombatAnimationMotionNode = ui.call("_build_authoring_motion_node_baseline", after_node)
		var after_orbit: Dictionary = ui.preview_presenter.resolve_motion_node_tip_grip_orbit(ui.preview_subviewport, after_display, after_display.tip_position_local)
		var actual_hand: Transform3D = sk.global_transform * sk.get_bone_global_pose(hand_index)
		var expected_hand: Transform3D = prop.global_transform * relation
		var details: Dictionary = _live_allocation_details(ui, actor)
		var manipulator_state: Dictionary = ui.preview_presenter.weapon_motion_manipulator.capture_state()
		var anchor: Variant = manipulator_state.get("contact_anchor_world")
		if retained_tip_anchor == null and anchor is Vector3: retained_tip_anchor = anchor
		var anchor_unchanged: bool = anchor is Vector3 and retained_tip_anchor is Vector3 and (anchor as Vector3).is_equal_approx(retained_tip_anchor)
		var retained_error := (prop.global_transform * (manipulator_state.get("contact_local", Vector3.ZERO) as Vector3)).distance_to(retained_tip_anchor as Vector3) if retained_tip_anchor is Vector3 else INF
		details.merge({"control": "tip", "degrees": degrees, "changed": changed, "setter_ms": elapsed_ms, "lookup_scope": scoped,
			"hand_error_m": actual_hand.origin.distance_to(expected_hand.origin),
			"hand_error_degrees": rad_to_deg(_allocation_basis_error(actual_hand.basis, expected_hand.basis)),
			"pivot_error_local": (after_orbit.get("tip_grip_pivot_local", pivot) as Vector3).distance_to(pivot)})
		allocation_report.requests.append(details)
		_check_allocation(anchor_unchanged and retained_error <= 0.00005, "tip_retains_original_gesture_anchor_%d" % request_index, {"anchor_unchanged": anchor_unchanged, "error_m": retained_error})
		if changed: progress += 1
		_check_allocation(details.hand_error_m <= 0.00005 and details.hand_error_degrees <= 0.025, "tip_retains_hand_attachment_after_frames_%s" % degrees, details)
		_check_allocation(actor.validate_authoring_forearm_hand_indexing().get("valid", false), "tip_wrist_valid_%s" % degrees)
	_check_allocation(progress > 0, "tip_input_produces_accepted_motion")
	if DisplayServer.get_name() != "headless":
		allocation_report.tip_image = await _capture_frame(ui, actor, side, output_dir.path_join(side + "_tip.png"))
	var before: Transform3D = prop.global_transform
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var display: CombatAnimationMotionNode = ui.call("_build_authoring_motion_node_baseline", node)
	var moved := ui.set_selected_motion_node_pommel_position(display.pommel_position_local + Vector3(0.002, 0.002, 0.0), false)
	await _wait_frames(3)
	allocation_report.requests.append(_live_allocation_details(ui, actor).merged({"control": "pommel", "changed": moved}))
	_check_allocation(moved, "pommel_small_motion_accepted")
	_check_allocation(_allocation_basis_error(before.basis, prop.global_basis) <= deg_to_rad(0.025), "pommel_preserves_orientation_after_frames")
	var roll_before: float = (ui.call("_get_active_motion_node") as CombatAnimationMotionNode).weapon_roll_degrees
	var rolled := ui.set_selected_motion_node_weapon_roll(roll_before + 1.0, false)
	await _wait_frames(3)
	allocation_report.requests.append(_live_allocation_details(ui, actor).merged({"control": "roll", "changed": rolled}))
	_check_allocation(rolled, "roll_small_motion_accepted")
	_check_allocation(actor.validate_authoring_forearm_hand_indexing().get("valid", false), "roll_wrist_valid_after_frames")
	var pointer := await _exercise_allocation_pointer(ui, actor, prop, sk, hand_index, relation)
	allocation_report.pointer = pointer
	_check_allocation(pointer.picked and pointer.picked_target == "tip" and pointer.authored_tip_delta_m > 0.0000001 and pointer.scope_depth == 0 and pointer.hand_error_m <= 0.00005 and pointer.hand_error_degrees <= 0.025, "mouse_tip_route_moves_keeps_contact_and_closes_lookup_scope", pointer)
	var added := ui.insert_motion_node_after_selection()
	var recording := await _await_allocation_recording(ui)
	_check_allocation(added and recording.ready, "R_records_accepted_pose_and_adds_node", recording)
	if not recording.ready:
		return _complete_allocation()
	node = ui.call("_get_active_motion_node")
	display = ui.call("_build_authoring_motion_node_baseline", node)
	var second_orbit: Dictionary = ui.preview_presenter.resolve_motion_node_tip_grip_orbit(ui.preview_subviewport, display, display.tip_position_local)
	if second_orbit.get("available", false):
		var pivot: Vector3 = second_orbit.tip_grip_pivot_local
		ui.set_selected_motion_node_tip_position(pivot + Basis(Vector3.RIGHT, deg_to_rad(-2.0)) * (display.tip_position_local - pivot), false)
	await _wait_frames(3)
	var playback: Dictionary = await _exercise_allocation_f(ui, actor)
	allocation_report.playback = playback
	_check_allocation(playback.played and playback.rejections.is_empty(), "F_prepares_and_plays_accepted_nodes", playback)
	if playback.played:
		ui.call("_manual_save_active_editor_state")
		var deadline: int = Time.get_ticks_msec() + 60000
		while (ui.manual_save_in_progress or ui.is_motion_node_recording_pending()) and Time.get_ticks_msec() < deadline:
			await _wait_frames(1)
		allocation_report.save_status = ui.footer_status_label.text
		allocation_report.isolated_save_path = ui.active_wip_library.save_file_path
		_check_allocation(not ui.manual_save_in_progress and not ui.footer_status_label.text.begins_with("Not saved"), "isolated_save_finishes", {"status": ui.footer_status_label.text})
		var reloaded := ResourceLoader.load(ui.active_wip_library.save_file_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState
		var persisted_clip: CombatRuntimeClip
		var persisted_node_count := 0
		if reloaded != null:
			for saved_weapon: CraftedItemWIP in reloaded.saved_wips:
				if saved_weapon.wip_id != ui.active_wip.wip_id:
					continue
				var station := saved_weapon.combat_animation_station_state as CombatAnimationStationState
				for saved_draft: CombatAnimationDraft in station.skill_drafts:
					if saved_draft.legal_slot_id == StringName(String(options.get("slot", "skill_slot_2"))):
						persisted_clip = saved_draft.baked_runtime_clip
						persisted_node_count = saved_draft.get_action_motion_node_chain().size()
		_check_allocation(persisted_clip != null and persisted_clip.has_solved_replay_track() and persisted_node_count >= 2, "isolated_disk_reload_has_solved_clip", {
			"visible_nodes": persisted_node_count, "frames": persisted_clip.get_frame_count() if persisted_clip != null else 0})
		if String(options.get("prepare-idle", "false")) == "true":
			allocation_report.idle_fixture = await _prepare_allocation_idle_fixture(ui)
			_check_allocation(allocation_report.idle_fixture.ready, "isolated_idle_prepared_through_own_UI", allocation_report.idle_fixture)
	return _complete_allocation()

func _prepare_allocation_idle_fixture(ui: CombatAnimationStationUI) -> Dictionary:
	if not ui.select_authoring_mode(CombatAnimationStationState.AUTHORING_MODE_IDLE) or not ui.select_draft(CombatAnimationDraft.IDLE_CONTEXT_COMBAT, true):
		return {"ready": false, "reason": "idle_page_selection_failed"}
	if not ui.reset_active_draft_to_baseline():
		return {"ready": false, "reason": "idle_reset_failed"}
	var readiness := await _await_recorded_reset_baseline(ui)
	if not readiness.ready:
		return {"ready": false, "readiness": readiness}
	ui.call("_manual_save_active_editor_state")
	var deadline := Time.get_ticks_msec() + 60000
	while (ui.manual_save_in_progress or ui.is_motion_node_recording_pending()) and Time.get_ticks_msec() < deadline:
		await _wait_frames(1)
	return {"ready": not ui.manual_save_in_progress and not ui.footer_status_label.text.begins_with("Not saved"),
		"status": ui.footer_status_label.text, "readiness": readiness,
		"scope": "Independent combat-idle Reset/Save on this isolated fixture; no production fallback or original idle changed."}

func _exercise_allocation_pointer(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, prop: Node3D,
		sk: Skeleton3D, hand_index: int, relation: Transform3D) -> Dictionary:
	ui.session_state.current_focus = CombatAnimationSessionState.FOCUS_TIP
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	var display: CombatAnimationMotionNode = ui.call("_build_display_motion_node_for_viewport_pick", node)
	var camera: Camera3D = ui.call("_get_preview_camera")
	var trajectory: Node3D = ui.call("_get_preview_trajectory_root")
	var point := camera.unproject_position(trajectory.to_global(display.tip_position_local))
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = point
	ui.call("_on_preview_gui_input", down)
	var picked := ui.motion_node_editor.is_dragging()
	var picked_target := String(ui.motion_node_editor.get_drag_target())
	var motion := InputEventMouseMotion.new()
	motion.position = point + Vector2(2, 0)
	motion.relative = Vector2(2, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	var started := Time.get_ticks_usec()
	ui.call("_on_preview_gui_input", motion)
	await create_timer(0.15).timeout
	ui.call("_flush_pending_preview_drag_refresh")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = motion.position
	ui.call("_on_preview_gui_input", release)
	var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
	await _wait_frames(3)
	var actual_hand := sk.global_transform * sk.get_bone_global_pose(hand_index)
	var expected_hand := prop.global_transform * relation
	return _live_allocation_details(ui, actor).merged({"picked": picked,
		"picked_target": picked_target, "authored_tip_delta_m": (ui.call("_build_authoring_motion_node_baseline", ui.call("_get_active_motion_node")) as CombatAnimationMotionNode).tip_position_local.distance_to(display.tip_position_local),
		"scope_depth": ui.preview_authoring_lookup_scope_depth, "gesture_ms_including_150ms_wait": elapsed_ms,
		"hand_error_m": actual_hand.origin.distance_to(expected_hand.origin),
		"hand_error_degrees": rad_to_deg(_allocation_basis_error(actual_hand.basis, expected_hand.basis))})

func _await_allocation_recording(ui: CombatAnimationStationUI) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + 40000
	while ui.is_motion_node_recording_pending() and Time.get_ticks_msec() < deadline:
		await _wait_frames(1)
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
	return {"ready": not ui.is_motion_node_recording_pending() and node != null,
		"selected_index": ui.get_selected_motion_node_index(), "status": ui.footer_status_label.text}

func _exercise_allocation_f(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig) -> Dictionary:
	var result := {"played": false, "samples": 0, "rejections": []}
	var started := Time.get_ticks_msec()
	ui.call("_toggle_preview_playback")
	while Time.get_ticks_msec() - started < 80000:
		await _wait_frames(1)
		if ui.chain_player.is_playing():
			if not result.played: result.prepare_ms = Time.get_ticks_msec() - started
			result.played = true
			result.samples += 1
			var validation: Dictionary = actor.get_meta("last_solved_body_replay_validation", {})
			if not validation.get("valid", false): result.rejections.append(validation)
		elif result.played or (not ui.preview_prepare_in_progress and not ui.is_motion_node_recording_pending()):
			break
	result.status = ui.footer_status_label.text
	return result

func _live_allocation_details(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig) -> Dictionary:
	var preview: Node3D = _get_preview_root(ui)
	var allocation: Dictionary = preview.get_meta("weapon_motion_allocation_result", {})
	var compact := allocation.duplicate()
	compact.erase("accepted_pose")
	compact.erase("accepted_payload")
	compact.erase("motion_adapter")
	return {"allocation": compact, "status": ui.footer_status_label.text}

func _allocation_basis_error(a: Basis, b: Basis) -> float:
	var difference := (a.orthonormalized().get_rotation_quaternion().inverse() * b.orthonormalized().get_rotation_quaternion()).normalized()
	return 2.0 * atan2(Vector3(difference.x, difference.y, difference.z).length(), absf(difference.w))

func _check_allocation(passed: bool, label: String, details: Dictionary = {}) -> void:
	allocation_report.checks.append({"passed": passed, "check": label, "details": details})
	if not passed: push_error("WEAPON_MOTION_STATION " + label + " " + JSON.stringify(details))

func _complete_allocation() -> Dictionary:
	allocation_report.complete = true
	for check: Dictionary in allocation_report.checks:
		if not check.passed: allocation_report.complete = false
	print("WEAPON_MOTION_STATION " + JSON.stringify(allocation_report))
	return allocation_report
