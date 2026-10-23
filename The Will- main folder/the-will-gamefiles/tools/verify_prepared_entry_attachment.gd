extends "res://tools/verify_prepared_skill_equipped_playback.gd"

## Same actual equipped lifecycle as the parent diagnostic, with an independent
## FK check of every generated entry sample. Requires a fresh attached cache.
const Entry = preload("res://runtime/combat/combat_runtime_entry_transition.gd")
const Arm = preload("res://core/resolvers/combat_prepared_arm_frame_resolver.gd")
const Attachment = preload("res://core/resolvers/combat_prepared_attachment_resolver.gd")
var _entry_incoming: Dictionary = {}
var _entry_checked := false
var _entry_ok := false

func _prepare_combat_idle() -> bool:
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
	return _check_calibration_guards(body.prepared_entry_destination)

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
		var relation: Dictionary = Attachment.sample_relationship(_entry_incoming, destination, "primary", weight)
		var expected: Transform3D = weapon * relation.transform
		var hand_index: int = pose.bone_names.find(_entry_incoming.primary_hand_bone_name)
		var actual: Transform3D = fk.transforms[hand_index]
		var position_error: float = actual.origin.distance_to(expected.origin)
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
		rows.append({"frame": frame, "time": clip.baked_frame_times[frame], "position_error_m": position_error, "orientation_error_rad": angle_error})
	_entry_ok = all_valid and prefix_count == 10 and maximum_position <= 0.00005 and maximum_angle <= 0.00005 and maximum_unrelated_rotation <= 0.00005 and int(diagnostics.get("acquisition_calls", -1)) == 0
	_report["entry_attachment_audit"] = {"ok": _entry_ok, "prefix_count": prefix_count, "max_position_error_m": maximum_position, "max_orientation_error_rad": maximum_angle, "max_nonarm_rotation_change_rad": maximum_unrelated_rotation, "live_source_weapon_distance_to_destination_m": (_entry_incoming.weapon_position_reference_local as Vector3).distance_to(destination.weapon_position_reference_local), "follow_calls": diagnostics.get("arm_follow_calls", -1), "frames": rows, "scope": "Production equipped idle-to-skill activation output; primary same-hand entry. Parent verifies unchanged body channels,60Hz,160ms and no new acquisitions."}

func _finish(success: bool, reason: String) -> void:
	if success and (not _entry_checked or not _entry_ok):
		success = false
		reason = "equipped_entry_attachment_check_failed"
	super._finish(success, reason)
