extends "res://tools/verify_prepared_skill_equipped_playback.gd"

## Same actual equipped lifecycle as the parent diagnostic, with an independent
## FK check of every generated entry sample. Requires a fresh attached cache.
## --live-entry starts from the actual already-drawn rig/weapon pose without
## requiring a prepared Combat Idle. It does not certify idle or recovery.
const Entry = preload("res://runtime/combat/combat_runtime_entry_transition.gd")
const Arm = preload("res://core/resolvers/combat_prepared_arm_frame_resolver.gd")
const Attachment = preload("res://core/resolvers/combat_prepared_attachment_resolver.gd")
var _entry_incoming: Dictionary = {}
var _entry_checked := false
var _entry_ok := false
var _live_entry := false

func _prepare_combat_idle() -> bool:
	_live_entry = OS.get_cmdline_user_args().has("--live-entry")
	if _live_entry:
		_report["combat_idle_preparation"] = {
			"mode": "not_required_for_active_skill_test",
			"skipped": true,
			"scope": "Actual live already-drawn current pose; no idle or recovery proof.",
		}
		_report["entry_test_mode"] = "live_already_drawn_current_pose"
	else:
		var ready: bool = await super._prepare_combat_idle()
		if not ready: return false
	var slot: StringName = &"skill_slot_1"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--slot="): slot = StringName(argument.trim_prefix("--slot="))
	var body: Resource
	for wip: Resource in _library.saved_wips:
		if wip.get("wip_id") != _weapon_id: continue
		var station: Resource = wip.get("combat_animation_station_state")
		for draft: Resource in station.get("skill_drafts"):
			if draft.get("legal_slot_id") == slot: body = draft.get("baked_runtime_clip")
	if body == null or body.prepared_entry_destination.is_empty():
		_report["entry_capture_failure"] = "attached_prepared_destination_missing"
		return false
	# Use the same current-owner context as actual activation, including hand
	# intent retained after the rig releases live acquisition bookkeeping.
	_entry_incoming = _player.runtime_skill_playback_presenter.call("_capture_runtime_solved_replay_bridge_snapshot", _player.humanoid_rig, _weapon, body)
	_report["entry_incoming_capture"] = {"valid": _entry_incoming.get("valid", false), "reason": _entry_incoming.get("reason", ""), "primary_slot": _entry_incoming.get("primary_hand_slot", ""), "nonarm_translation_differences": _entry_incoming.get("entry_nonarm_translation_differences", [])}
	if not bool(_entry_incoming.get("valid", false)): return false
	return _check_calibration_guards(body.prepared_entry_destination) and _check_attachment_scale_guards()

func _check_attachment_scale_guards() -> bool:
	var hand_scale := Vector3.ONE * 0.764165
	var rotation_a := Basis(Quaternion(Vector3(1, 2, 3).normalized(), 0.3))
	var rotation_b := Basis(Quaternion(Vector3(2, -1, 3).normalized(), -0.5))
	var a := {"weapon_scale_reference_local": hand_scale,
		"primary_hand_in_weapon": Transform3D(rotation_a, Vector3(0.02, 0.04, -0.01))}
	var b := {"weapon_scale_reference_local": Vector3.ONE,
		"primary_hand_in_weapon": Transform3D(rotation_b.scaled(hand_scale), Vector3(-0.01, 0.06, 0.03))}
	var original: PackedByteArray = var_to_bytes([a, b])
	var rows: Array[Dictionary] = []
	var valid := true
	for weight: float in [0.0, 0.030291522, 0.25, 0.5, 0.75, 0.95, 1.0]:
		var weapon_scale: Vector3 = hand_scale.lerp(Vector3.ONE, weight)
		var weapon_basis := Basis(Quaternion(Vector3.UP, weight)).scaled(weapon_scale)
		var sampled: Dictionary = Attachment.sample_relationship(a, b, "primary", weight, weapon_basis)
		var expected_relation: Transform3D = (a.primary_hand_in_weapon as Transform3D).interpolate_with(b.primary_hand_in_weapon, weight)
		var frame_valid: bool = bool(sampled.get("valid", false))
		var scale_error := INF
		if frame_valid:
			var actual_relation: Transform3D = sampled.transform
			var composed: Basis = weapon_basis * actual_relation.basis
			scale_error = composed.get_scale().distance_to(hand_scale)
			frame_valid = composed.get_scale().is_equal_approx(hand_scale) and actual_relation.origin == expected_relation.origin and actual_relation.basis.orthonormalized().is_equal_approx(expected_relation.basis.orthonormalized())
			if weight == 0.0: frame_valid = frame_valid and actual_relation == a.primary_hand_in_weapon
			if weight == 1.0: frame_valid = frame_valid and actual_relation == b.primary_hand_in_weapon
		rows.append({"weight": weight, "valid": frame_valid, "scale_error": scale_error})
		valid = valid and frame_valid
	# The denominator must be the supplied sample, not a second interpolation
	# guessed from the endpoints. Origin and orientation remain unchanged.
	var actual_sample_basis := Basis(Quaternion(Vector3.RIGHT, 0.7)).scaled(Vector3.ONE * 0.9)
	var actual_sample: Dictionary = Attachment.sample_relationship(a, b, "primary", 0.5, actual_sample_basis)
	var uses_actual_sample: bool = bool(actual_sample.get("valid", false)) and (actual_sample_basis * (actual_sample.transform as Transform3D).basis).get_scale().is_equal_approx(hand_scale)
	var invalid_bases: Array[Basis] = [Basis.from_scale(Vector3(1, 2, 1)), Basis.from_scale(Vector3(-1, 1, 1)), Basis.from_scale(Vector3.ZERO), Basis(Vector3.RIGHT, Vector3(0.1, 1, 0), Vector3.BACK)]
	var invalid_rejected := true
	for basis: Basis in invalid_bases:
		invalid_rejected = invalid_rejected and not bool(Attachment.sample_relationship(a, b, "primary", 0.5, basis).get("valid", false))
	var malformed: Dictionary = a.duplicate(true)
	malformed.weapon_scale_reference_local = Vector3(1, 2, 1)
	invalid_rejected = invalid_rejected and not bool(Attachment.sample_relationship(malformed, b, "primary", 0.5, actual_sample_basis).get("valid", false))
	# Wrong captured physical hand size must still be rejected by the actual
	# arm resolver; the fix must never substitute the rig's scale for bad data.
	var bad: Dictionary = _entry_incoming.duplicate(true)
	var bad_relation: Transform3D = bad.primary_hand_in_weapon
	bad_relation.basis = bad_relation.basis.scaled(Vector3.ONE * 1.02)
	bad.primary_hand_in_weapon = bad_relation
	var weapon_basis := Basis(bad.weapon_rotation_reference_local).scaled(bad.weapon_scale_reference_local)
	var mismatch: Dictionary = Attachment.sample_relationship(bad, bad, "primary", 0.5, weapon_basis)
	var mismatch_rejected := false
	if bool(mismatch.get("valid", false)):
		var weapon := Transform3D(weapon_basis, bad.weapon_position_reference_local)
		var resolved: Dictionary = Arm.resolve(_entry_incoming, weapon * (mismatch.transform as Transform3D), _entry_incoming.arm_constraints_by_slot[_entry_incoming.primary_hand_slot])
		mismatch_rejected = not bool(resolved.get("valid", false)) and resolved.get("reason", "") == "requested_hand_scale_differs_from_rig"
	var unchanged: bool = var_to_bytes([a, b]) == original
	valid = valid and uses_actual_sample and invalid_rejected and mismatch_rejected and unchanged
	_report["attachment_scale_guards"] = {"ok": valid, "frames": rows, "actual_sample_basis_used": uses_actual_sample,
		"unsupported_bases_rejected": invalid_rejected, "genuine_hand_scale_mismatch_rejected": mismatch_rejected, "inputs_unchanged": unchanged}
	return valid

func _check_calibration_guards(destination: Dictionary) -> bool:
	var missing: Dictionary = _entry_incoming.duplicate(true)
	for packet: Dictionary in missing.arm_constraints_by_slot.values():
		packet["twist_neutral_rotations"] = {}
	var baseline_hash: int = hash(destination)
	var matching: Dictionary = missing.duplicate(true)
	var matches: bool = bool(Entry._supply_matching_saved_neutrals(matching, destination).get("valid", false))
	var changed_rest: Dictionary = missing.duplicate(true)
	var rest: Transform3D = changed_rest.bone_rest_transforms[0]
	rest.origin.x += 0.01
	changed_rest.bone_rest_transforms[0] = rest
	var rejects_rest: bool = not bool(Entry._supply_matching_saved_neutrals(changed_rest, destination).get("valid", false))
	var changed_arm: Dictionary = missing.duplicate(true)
	var hand_index: int = changed_arm.bone_names.find(changed_arm.primary_hand_bone_name)
	changed_arm.pose_positions[hand_index] += Vector3(0.01, 0.0, 0.0)
	var rejects_arm: bool = not bool(Entry._supply_matching_saved_neutrals(changed_arm, destination).get("valid", false))
	var changed_limit: Dictionary = missing.duplicate(true)
	changed_limit.arm_constraints_by_slot[_entry_incoming.primary_hand_slot].elbow_max_degrees += 1.0
	var rejects_limit: bool = not bool(Entry._supply_matching_saved_neutrals(changed_limit, destination).get("valid", false))
	var changed_neutral: Dictionary = missing.duplicate(true)
	var slot: StringName = _entry_incoming.primary_hand_slot
	var bone: StringName = destination.arm_constraints_by_slot[slot].twist_neutral_rotations.keys()[0]
	changed_neutral.arm_constraints_by_slot[slot].twist_neutral_rotations[bone] = Quaternion(Vector3.UP, 0.2) * destination.arm_constraints_by_slot[slot].twist_neutral_rotations[bone]
	var rejects_neutral: bool = not bool(Entry._supply_matching_saved_neutrals(changed_neutral, destination).get("valid", false))
	var unchanged: bool = baseline_hash == hash(destination)
	var valid: bool = matches and rejects_rest and rejects_arm and rejects_limit and rejects_neutral and unchanged
	_report["entry_neutral_calibration_guards"] = {"ok": valid, "matching_skeleton_accepted": matches, "changed_rest_rejected": rejects_rest, "changed_arm_length_rejected": rejects_arm, "changed_limits_rejected": rejects_limit, "existing_different_neutral_rejected": rejects_neutral, "saved_destination_unchanged": unchanged, "actual_restored_bones": _entry_incoming.get("entry_restored_neutral_bones", [])}
	return valid

func _settle_rig(chain: CombatAnimationChainPlayer) -> void:
	await super._settle_rig(chain)
	if _entry_checked or _entry_incoming.is_empty() or not is_instance_valid(_player): return
	var presenter: PlayerRuntimeSkillPlaybackPresenter = _player.runtime_skill_playback_presenter
	if chain != presenter.chain_player or presenter.active_runtime_clip == null: return
	_audit_entry(presenter.active_runtime_clip)

func _audit_entry(clip: Resource) -> void:
	_entry_checked = true
	var destination: Dictionary = clip.prepared_entry_destination
	var diagnostics: Dictionary = clip.get_meta("entry_attachment_diagnostics", {})
	var rows: Array[Dictionary] = []
	var maximum_position := 0.0
	var maximum_angle := 0.0
	var maximum_scale_error := 0.0
	var maximum_unrelated_rotation := 0.0
	var flags: Array = clip.get_meta("baked_solved_replay_bridge_frame", [])
	var prefix_count := 0
	var all_valid: bool = not destination.is_empty() and not diagnostics.is_empty()
	for frame: int in clip.get_frame_count():
		if frame >= flags.size() or not flags[frame]: break
		prefix_count += 1
		var weight: float = float(clip.baked_frame_times[frame]) / Entry.ENTRY_DURATION_SECONDS
		weight = weight * weight * (3.0 - 2.0 * weight)
		var pose: Dictionary = _entry_incoming.duplicate(true)
		pose.pose_positions = clip.baked_solved_upper_body_pose_positions[frame]
		pose.pose_rotations = clip.baked_solved_upper_body_pose_rotations[frame]
		pose.pose_scales = clip.baked_solved_upper_body_pose_scales[frame]
		for index: int in pose.parent_reference_transforms.size():
			pose.parent_reference_transforms[index] = (_entry_incoming.parent_reference_transforms[index] as Transform3D).interpolate_with(destination.parent_reference_transforms[index], weight)
		var fk: Dictionary = Arm.forward_kinematics(pose)
		if not fk.get("valid", false):
			all_valid = false
			rows.append({"frame": frame, "reason": fk.get("reason", "")})
			continue
		var q: Vector4 = clip.baked_solved_weapon_rotations_reference_local[frame]
		var weapon := Transform3D(Basis(Quaternion(q.x, q.y, q.z, q.w)).scaled(clip.baked_solved_weapon_scales_reference_local[frame]), clip.baked_solved_weapon_positions_reference_local[frame])
		var relation: Dictionary = Attachment.sample_relationship(_entry_incoming, destination, "primary", weight, weapon.basis)
		if not bool(relation.get("valid", false)):
			all_valid = false
			rows.append({"frame": frame, "reason": relation.get("reason", "")})
			continue
		var expected: Transform3D = weapon * relation.transform
		var hand_index: int = pose.bone_names.find(_entry_incoming.primary_hand_bone_name)
		var actual: Transform3D = fk.transforms[hand_index]
		var position_error: float = actual.origin.distance_to(expected.origin)
		var scale_error: float = actual.basis.get_scale().distance_to(expected.basis.get_scale())
		maximum_scale_error = maxf(maximum_scale_error, scale_error)
		all_valid = all_valid and actual.basis.get_scale().is_equal_approx(expected.basis.get_scale())
		var delta: Quaternion = (actual.basis.orthonormalized().get_rotation_quaternion().inverse() * expected.basis.orthonormalized().get_rotation_quaternion()).normalized()
		var angle_error: float = 2.0 * atan2(Vector3(delta.x, delta.y, delta.z).length(), absf(delta.w))
		maximum_position = maxf(maximum_position, position_error)
		maximum_angle = maxf(maximum_angle, angle_error)
		for index: int in pose.bone_names.size():
			var name: String = pose.bone_names[index]
			if name.ends_with("_Clavicle") or name.ends_with("_Upperarm") or name.ends_with("_Forearm") or name.ends_with("_Hand"): continue
			var a: Vector4 = _entry_incoming.pose_rotations[index]
			var b: Vector4 = destination.pose_rotations[index]
			var original: Quaternion = Quaternion(a.x, a.y, a.z, a.w).slerp(Quaternion(b.x, b.y, b.z, b.w), weight).normalized()
			var current: Vector4 = pose.pose_rotations[index]
			var difference: Quaternion = (original.inverse() * Quaternion(current.x, current.y, current.z, current.w)).normalized()
			maximum_unrelated_rotation = maxf(maximum_unrelated_rotation, 2.0 * atan2(Vector3(difference.x, difference.y, difference.z).length(), absf(difference.w)))
		rows.append({"frame": frame, "time": clip.baked_frame_times[frame], "position_error_m": position_error, "orientation_error_rad": angle_error, "scale_error": scale_error})
	_entry_ok = all_valid and prefix_count == 10 and maximum_position <= Arm.POSITION_TOLERANCE_METERS and maximum_angle <= Arm.ANGULAR_TOLERANCE_RADIANS and maximum_unrelated_rotation <= 0.00005 and int(diagnostics.get("acquisition_calls", -1)) == 0
	var entry_scope: String = (
		"Production equipped activation from the actual live already-drawn current pose; primary same-hand entry. No idle or recovery proof."
		if _live_entry else
		"Production equipped idle-to-skill activation output; primary same-hand entry."
	)
	_report["entry_attachment_audit"] = {"ok": _entry_ok, "prefix_count": prefix_count, "max_position_error_m": maximum_position, "max_orientation_error_rad": maximum_angle, "max_scale_error": maximum_scale_error, "max_nonarm_rotation_change_rad": maximum_unrelated_rotation, "live_source_weapon_distance_to_destination_m": (_entry_incoming.weapon_position_reference_local as Vector3).distance_to(destination.weapon_position_reference_local), "follow_calls": diagnostics.get("arm_follow_calls", -1), "frames": rows, "scope": entry_scope + " Parent verifies unchanged body channels,60Hz,160ms and no new acquisitions."}

func _finish(success: bool, reason: String) -> void:
	if success and (not _entry_checked or not _entry_ok):
		success = false
		reason = "equipped_entry_attachment_check_failed"
	if _live_entry and _activation_solve_start_count >= 0:
		# Preserve the parent's acquisition assertion with the correct starting
		# state description. Disable only its duplicate report/count afterward.
		Chronology.event("audit.equipped_samples_complete", {"terminal": true})
		var final_count: int = _count_acquisition_starts()
		var no_new_acquisition: bool = final_count == _activation_solve_start_count
		_report["grip_acquisitions_during_activation_and_playback"] = {
			"before_activation": _activation_solve_start_count,
			"after_samples": final_count,
			"new_acquisitions": final_count - _activation_solve_start_count if final_count >= 0 else -1,
			"ok": no_new_acquisition,
			"scope": "Actual owner.solve_started events from live already-drawn current-pose activation through sampled playback; no prepared idle prerequisite or recovery proof.",
		}
		_activation_solve_start_count = -1
		if not no_new_acquisition:
			success = false
			if reason.is_empty():
				reason = "equipped_playback_started_new_grip_acquisition"
	super._finish(success, reason)
