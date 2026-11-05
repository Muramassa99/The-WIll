extends "res://tools/diagnose_weapon_motion_boundary_reentry.gd"

## Actual R/F/Save APIs on an isolated clone. Finite bad anatomy is deliberately
## seeded in the displayed rig to verify preservation, not to bypass recording.
## No original player file is written; no production code is changed by this tool.
const QualityWrist = preload("res://core/resolvers/combat_wrist_motion_resolver.gd")
const QualityHinge = preload("res://core/resolvers/combat_arm_hinge_frame_resolver.gd")
const QualityEntry = preload("res://runtime/combat/combat_runtime_entry_transition.gd")
const QualityChain = preload("res://runtime/combat/combat_animation_chain_player.gd")
const QualityChannels = preload("res://core/resolvers/combat_runtime_clip_incremental_resolver.gd")

func _run_thrust(ui: CombatAnimationStationUI, side: String, _elevation: float) -> Dictionary:
	allocation_report = {"complete": false, "checks": [], "side": side,
		"scope": "Isolated real station: normal node, finite invalid elbow/wrist plus manual-grip-warning nodes; actual R/F/Save/reload, shared equipped entry and frame writer. No original save writes."}
	if ui.active_wip_library == null or not ui.active_wip_library.save_file_path.begins_with(output_dir + "/isolated_"):
		return allocation_report.merged({"reason": "isolated_library_required"})
	ui.set_meta("verification_skip_persistence", false)
	if not ui.reset_active_draft_to_baseline(): return allocation_report.merged({"reason": "reset_failed"})
	var ready := await _await_recorded_reset_baseline(ui)
	allocation_report.readiness = ready
	_check_allocation(ready.get("ready", false), "baseline_ready", ready)
	if not ready.get("ready", false): return _complete_allocation()
	var actor := _get_preview_actor(ui) as PlayerHumanoidRig
	var prop := _get_preview_held_item(ui)
	var authored: Array[CombatAnimationMotionNode] = []
	var expected: Array[Dictionary] = []
	ui.set_selected_motion_node_transition_duration(0.2, false)
	for index: int in 3:
		var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
		if index > 0:
			var facing := ui.apply_selected_motion_node_weapon_facing_delta(3.0, true)
			_check_allocation(facing, "node_%d_manual_facing_edit" % (index + 1))
			var seeded := _quality_seed_bad_pose(actor, side, index)
			allocation_report["node_%d_fixture" % (index + 1)] = seeded
			_check_allocation(seeded.valid, "node_%d_finite_bad_anatomy_seeded" % (index + 1), seeded)
			_check_allocation(ui.preview_presenter.is_weapon_facing_reacquisition_required(ui.preview_subviewport), "node_%d_manual_grip_warning_present" % (index + 1))
			# A diagnostic direct bone edit has no UI event to invalidate the node.
			# Clear only this clone's cached recording; R/F must capture actual bones.
			node.prepared_pose = {}
			node.prepared_pose_signature = ""
		authored.append(node)
		expected.append(_boundary_bone_channels(actor))
		if index < 2:
			var added := ui.insert_motion_node_after_selection()
			var recording := await _await_allocation_recording(ui)
			var selected: CombatAnimationMotionNode = ui.call("_get_active_motion_node")
			_check_allocation(added and recording.ready and selected != node, "R_records_node_%d_and_advances" % (index + 1), recording)
			_check_allocation(BoundaryPose.validate(node.prepared_pose).get("valid", false), "recorded_node_%d_has_valid_data" % (index + 1))
			var error := _boundary_packet_error(node.prepared_pose, expected[index])
			_check_allocation(error.valid, "R_preserves_node_%d_exact_body" % (index + 1), error)
			if not recording.ready or selected == node: return _complete_allocation()
	var playback := await _exercise_allocation_f(ui, actor)
	allocation_report.playback = playback
	_check_allocation(playback.played and playback.rejections.is_empty(), "F_prepares_and_completes_warning_skill", playback)
	for index: int in authored.size():
		var packet_error := _boundary_packet_error(authored[index].prepared_pose, expected[index])
		_check_allocation(packet_error.valid, "F_preserves_authored_node_%d_body" % (index + 1), packet_error)
		if index > 0:
			_check_allocation(not (authored[index].prepared_pose.get("quality_warnings", []) as Array).is_empty(), "node_%d_retains_quality_warnings" % (index + 1))
	if not playback.played: return _complete_allocation()
	ui.call("_manual_save_active_editor_state")
	var deadline := Time.get_ticks_msec() + 60000
	while (ui.manual_save_in_progress or ui.is_motion_node_recording_pending()) and Time.get_ticks_msec() < deadline: await _wait_frames(1)
	_check_allocation(not ui.manual_save_in_progress and not ui.footer_status_label.text.begins_with("Not saved"), "Save_finishes_with_quality_warnings", {"status": ui.footer_status_label.text})
	allocation_report.isolated_save_path = ui.active_wip_library.save_file_path
	var loaded := ResourceLoader.load(ui.active_wip_library.save_file_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState
	var saved: CombatAnimationDraft
	if loaded != null:
		for weapon: CraftedItemWIP in loaded.saved_wips:
			if weapon.wip_id != ui.active_wip.wip_id: continue
			for draft: CombatAnimationDraft in weapon.combat_animation_station_state.skill_drafts:
				if draft.legal_slot_id == StringName(String(options.get("slot", "skill_slot_2"))): saved = draft
	_check_allocation(saved != null and saved.baked_runtime_clip != null and saved.baked_runtime_clip.has_solved_replay_track(), "saved_warning_skill_reloads")
	if saved == null or saved.baked_runtime_clip == null: return _complete_allocation()
	for index: int in authored.size():
		var found := false
		for node: CombatAnimationMotionNode in saved.get_action_motion_node_chain():
			if node.node_id != authored[index].node_id: continue
			found = true
			var error := _boundary_packet_error(node.prepared_pose, expected[index])
			_check_allocation(error.valid, "disk_node_%d_preserves_body" % (index + 1), error)
		_check_allocation(found, "disk_node_%d_present" % (index + 1))
	_check_allocation(not saved.baked_runtime_clip.compile_diagnostics.is_empty(), "saved_clip_retains_quality_diagnostics")
	allocation_report.entry_and_writer = _quality_entry_and_writer(actor, prop, saved)
	_check_allocation(allocation_report.entry_and_writer.valid, "equipped_entry_and_shared_writer_complete_warning_skill", allocation_report.entry_and_writer)
	allocation_report.endcap_replay = _quality_endcap_replay(ui, actor, prop, saved)
	_check_allocation(allocation_report.endcap_replay.valid, "endcap_warning_applies_but_missing_anchor_is_fatal", allocation_report.endcap_replay)
	if String(options.get("prepare-idle", "false")) == "true":
		allocation_report.idle_fixture = await _prepare_allocation_idle_fixture(ui)
		_check_allocation(allocation_report.idle_fixture.ready, "isolated_idle_prepared_through_own_UI", allocation_report.idle_fixture)
	return _complete_allocation()

func _quality_endcap_replay(ui: CombatAnimationStationUI, actor: PlayerHumanoidRig, prop: Node3D, draft: CombatAnimationDraft) -> Dictionary:
	var packet: Dictionary = draft.get_action_motion_node_chain().back().prepared_pose
	var frame := {
		"active": true, "primary_hand_slot": packet.primary_hand_slot,
		"two_hand_state": CombatAnimationMotionNode.TWO_HAND_STATE_ONE_HAND,
		"solved_upper_body_bone_names": Array(packet.bone_names),
		"solved_upper_body_pose_positions": Array(packet.pose_positions),
		"solved_upper_body_pose_rotations": Array(packet.pose_rotations),
		"solved_upper_body_pose_scales": Array(packet.pose_scales),
		"solved_replay_reference_bone_name": packet.reference_bone_name,
		"solved_weapon_position_reference_local": packet.weapon_position_reference_local,
		"solved_weapon_rotation_reference_local": packet.weapon_rotation_reference_local,
		"solved_weapon_scale_reference_local": packet.weapon_scale_reference_local,
		"solved_anchor_node_paths": Array(packet.anchor_node_paths),
		"solved_anchor_positions_weapon_local": Array(packet.anchor_positions_weapon_local),
		"solved_anchor_rotations_weapon_local": Array(packet.anchor_rotations_weapon_local),
		"solved_anchor_scales_weapon_local": Array(packet.anchor_scales_weapon_local),
	}
	var index: int = frame.solved_anchor_node_paths.find(&"PrimaryGripAnchor")
	if index < 0: return {"valid": false, "reason": "fixture_primary_anchor_missing"}
	var start: Vector3 = prop.get_meta("primary_grip_span_start_local", Vector3.ZERO)
	var end: Vector3 = prop.get_meta("primary_grip_span_end_local", Vector3.ZERO)
	# Deliberately finite and outside the handle: a quality fault, not corrupt data.
	frame.solved_anchor_positions_weapon_local[index] = end + (end - start)
	var root_node := _get_preview_root(ui)
	var state := {"preview_root": root_node, "actor_pivot": actor.get_parent()}
	var result: Dictionary = ui.preview_presenter.call("_apply_solved_runtime_clip_preview_pose", state, ui.active_wip, frame)
	var warning_applied: bool = result.get("solved_replay_applied", false) and result.get("grip_endcap_replay_warning", false) and not result.get("grip_endcap_replay_invalid", false)
	var body_error := _boundary_packet_error(packet, _boundary_bone_channels(actor))
	var before := var_to_bytes(_boundary_bone_channels(actor))
	var before_state := var_to_bytes(actor.runtime_solved_replay_pose_state)
	var bad := frame.duplicate(true)
	bad.solved_anchor_node_paths[index] = &"MissingPrimaryGripAnchor"
	var rejected: Dictionary = ui.preview_presenter.call("_apply_solved_runtime_clip_preview_pose", state, ui.active_wip, bad)
	var malformed_rejected: bool = rejected.get("grip_endcap_replay_invalid", false) and not rejected.get("solved_replay_applied", true) and before == var_to_bytes(_boundary_bone_channels(actor)) and before_state == var_to_bytes(actor.runtime_solved_replay_pose_state)
	return {"valid": warning_applied and body_error.valid and malformed_rejected,
		"finite_endcap_warning_applied": warning_applied, "body_packet_applied": body_error,
		"warning_reason": result.get("grip_endcap_replay_reason", ""),
		"malformed_anchor_rejected_atomically": malformed_rejected,
		"malformed_reason": rejected.get("grip_endcap_replay_reason", "")}

func _quality_seed_bad_pose(actor: PlayerHumanoidRig, side: String, variation: int) -> Dictionary:
	var sk := actor.skeleton
	var upper := sk.find_bone("CC_Base_" + side + "_Upperarm")
	var forearm := sk.find_bone("CC_Base_" + side + "_Forearm")
	var hand := sk.find_bone("CC_Base_" + side + "_Hand")
	var hinge := QualityHinge.calibration(sk.get_bone_rest(forearm), sk.get_bone_rest(hand))
	if not hinge.get("valid", false): return {"valid": false, "reason": "hinge_calibration_missing"}
	var u := sk.get_bone_global_pose(upper)
	var f := sk.get_bone_global_pose(forearm)
	var a: Basis = u.basis.orthonormalized() * hinge.frame_in_upperarm
	var shaft := (f.origin - u.origin).normalized()
	var direction := (sk.get_bone_global_pose(hand).origin - f.origin).normalized()
	var signed_flexion := atan2(a.x.dot(shaft.cross(direction)), shaft.dot(direction))
	var desired := Basis(a.x.normalized(), deg_to_rad(-1.0 - variation) - signed_flexion) * f.basis.orthonormalized()
	sk.set_bone_pose_rotation(forearm, (u.basis.orthonormalized().inverse() * desired).get_rotation_quaternion().normalized())
	sk.force_update_all_bone_transforms()
	var slot := _boundary_slot(side)
	var calibration: Dictionary = actor.capture_wrist_constraint_calibration(slot)
	var profile: Dictionary = actor.wrist_motion_profile.call("as_dictionary")
	var state := {"rho": 0.0, "beta": float(profile.extension_limit_radians) + deg_to_rad(4.0 + variation), "gamma": 0.0}
	var sampled := QualityWrist.sample_kinematics(sk.get_bone_global_pose(forearm), sk.get_bone_global_pose(hand), calibration, profile, state)
	if not sampled.get("valid", false): return sampled
	sk.set_bone_pose_rotation(hand, (sk.get_bone_global_pose(forearm).basis.inverse() * (sampled.hand_basis as Basis)).get_rotation_quaternion().normalized())
	sk.force_update_all_bone_transforms()
	var measured := QualityWrist.measure_state(sk.get_bone_global_pose(forearm), sk.get_bone_global_pose(hand), calibration, profile, state)
	var strict := actor.validate_authoring_forearm_hand_indexing()
	return {"valid": measured.get("valid", false) and not strict.get("valid", true), "measured_wrist": measured,
		"intended_elbow_degrees": -1.0 - variation, "strict_anatomy": strict}

func _quality_entry_and_writer(actor: PlayerHumanoidRig, prop: Node3D, draft: CombatAnimationDraft) -> Dictionary:
	var clip: CombatRuntimeClip = draft.baked_runtime_clip
	var incoming := QualityEntry.capture(actor, prop, clip, {"primary_hand_slot": &"hand_right", "support_enabled": false})
	var result := {"valid": false, "incoming_valid": BoundaryPose.validate(incoming).get("valid", false)}
	if not result.incoming_valid:
		result["incoming_failure"] = incoming
		return result
	var combined: CombatRuntimeClip = QualityEntry.build(clip, incoming, draft.get_action_motion_node_chain().back())
	if combined == null: return result.merged({"reason": "entry_build_failed"})
	var prefix := combined.get_frame_count() - clip.get_frame_count()
	var unchanged := prefix >= 0
	for field: StringName in QualityChannels.SOLVED_FRAME_FIELDS:
		if field == &"baked_frame_times": continue
		unchanged = unchanged and combined.get(field).slice(prefix) == clip.get(field)
	result["body_channels_unchanged"] = unchanged
	result["entry_duration_s"] = combined.get_meta("entry_duration_seconds", 0.0)
	var chain := QualityChain.new()
	chain.prepare_runtime_clip(combined, 1.0, false)
	chain.start()
	var frames := 0
	var rejected := 0
	while chain.is_playing() and frames < 300:
		chain.advance(1.0 / 60.0)
		var written := actor.apply_runtime_solved_upper_body_pose_frame(chain.current_solved_upper_body_bone_names,
			chain.current_solved_upper_body_pose_positions, chain.current_solved_upper_body_pose_rotations,
			chain.current_solved_upper_body_pose_scales, 1.0, chain.current_solved_forearm_hand_calibration)
		var weapon_written := actor.set_runtime_solved_replay_weapon_frame(prop, chain.current_solved_replay_reference_bone_name,
			chain.current_solved_weapon_position_reference_local, chain.current_solved_weapon_rotation_reference_local,
			chain.current_solved_weapon_scale_reference_local, chain.current_solved_anchor_node_paths,
			chain.current_solved_anchor_positions_weapon_local, chain.current_solved_anchor_rotations_weapon_local,
			chain.current_solved_anchor_scales_weapon_local)
		if not written or not weapon_written: rejected += 1
		frames += 1
	result["frames_applied"] = frames
	result["rejected_frames"] = rejected
	result["finished"] = not chain.is_playing()
	var last: CombatAnimationMotionNode = draft.get_action_motion_node_chain().back()
	result["terminal_body_matches_saved"] = _boundary_packet_error(last.prepared_pose, _boundary_bone_channels(actor))
	var before := var_to_bytes(_boundary_bone_channels(actor))
	var before_state := var_to_bytes(actor.runtime_solved_replay_pose_state)
	var malformed := chain.current_solved_upper_body_pose_positions.duplicate()
	malformed[malformed.size() - 1] = Vector3(NAN, 0.0, 0.0)
	var corrupt_accepted := actor.apply_runtime_solved_upper_body_pose_frame(chain.current_solved_upper_body_bone_names,
		malformed, chain.current_solved_upper_body_pose_rotations, chain.current_solved_upper_body_pose_scales,
		1.0, chain.current_solved_forearm_hand_calibration)
	result["corrupt_frame_rejected_atomically"] = not corrupt_accepted and before == var_to_bytes(_boundary_bone_channels(actor)) and before_state == var_to_bytes(actor.runtime_solved_replay_pose_state)
	var mismatch_checks: Array[Dictionary] = []
	var mismatches_rejected := true
	for channel: int in 4:
		for extra: bool in [false, true]:
			var channels: Array = [chain.current_solved_upper_body_bone_names.duplicate(),
				chain.current_solved_upper_body_pose_positions.duplicate(),
				chain.current_solved_upper_body_pose_rotations.duplicate(),
				chain.current_solved_upper_body_pose_scales.duplicate()]
			if extra:
				channels[channel].append(channels[channel].back())
			else:
				channels[channel].pop_back()
			var accepted := actor.apply_runtime_solved_upper_body_pose_frame(channels[0], channels[1], channels[2], channels[3],
				1.0, chain.current_solved_forearm_hand_calibration)
			var atomic := not accepted and before == var_to_bytes(_boundary_bone_channels(actor)) and before_state == var_to_bytes(actor.runtime_solved_replay_pose_state)
			mismatch_checks.append({"channel": channel, "extra": extra, "rejected_atomically": atomic})
			mismatches_rejected = mismatches_rejected and atomic
	result["mismatched_channels_rejected_atomically"] = mismatches_rejected
	result["mismatch_checks"] = mismatch_checks
	var empty_accepted := actor.apply_runtime_solved_upper_body_pose_frame([], [], [], [])
	result["empty_frame_remains_no_op"] = not empty_accepted and before == var_to_bytes(_boundary_bone_channels(actor)) and before_state == var_to_bytes(actor.runtime_solved_replay_pose_state)
	# A packet may intentionally update only one bone. Equal channel lengths
	# must remain sufficient; requiring the entire skeleton would reject this.
	var partial_accepted := actor.apply_runtime_solved_upper_body_pose_frame(
		chain.current_solved_upper_body_bone_names.slice(0, 1), chain.current_solved_upper_body_pose_positions.slice(0, 1),
		chain.current_solved_upper_body_pose_rotations.slice(0, 1), chain.current_solved_upper_body_pose_scales.slice(0, 1))
	result["equal_partial_frame_accepted"] = partial_accepted and (actor.runtime_solved_replay_pose_state.get("bone_names", []) as Array).size() == 1
	result["valid"] = unchanged and absf(float(result.entry_duration_s) - 0.16) < 0.000001 and frames > 1 and rejected == 0 and result.finished and result.terminal_body_matches_saved.valid and result.corrupt_frame_rejected_atomically and mismatches_rejected and result.empty_frame_remains_no_op and result.equal_partial_frame_accepted
	return result
