extends "res://tools/verify_prepared_skill_equipped_playback.gd"

## Runs the inherited actual PlayerController activation/read-only saved replay,
## then exercises advisory vs malformed endcaps through that runtime presenter.
## The source library is never changed. Same --source/--slot/--out arguments.

func _finish(success: bool, reason: String) -> void:
	if success:
		var endcaps := _quality_equipped_endcaps()
		_report["quality_endcaps"] = endcaps
		if not endcaps.valid:
			success = false
			reason = "equipped_quality_endcaps_failed"
	super._finish(success, reason)

func _quality_equipped_endcaps() -> Dictionary:
	var presenter: PlayerRuntimeSkillPlaybackPresenter = _player.runtime_skill_playback_presenter
	var actor := _player.humanoid_rig
	var frame: Dictionary = presenter.last_runtime_pose_state.duplicate(true)
	var paths: Array = frame.get("solved_anchor_node_paths", [])
	var index := paths.find(&"PrimaryGripAnchor")
	if index < 0: return {"valid": false, "reason": "fixture_primary_anchor_missing"}
	var start: Vector3 = _weapon.get_meta("primary_grip_span_start_local", Vector3.ZERO)
	var end: Vector3 = _weapon.get_meta("primary_grip_span_end_local", Vector3.ZERO)
	frame.solved_anchor_positions_weapon_local[index] = end + (end - start)
	# Also prove a previous structural failure flag cannot survive an advisory
	# frame and make its caller reject a pose that was actually applied.
	frame["grip_endcap_replay_invalid"] = true
	var applied: bool = presenter.call("_apply_solved_runtime_replay_frame", actor,
		_player.held_item_nodes, _weapon, frame, &"hand_right", &"hand_left", false)
	var warning_applied: bool = applied and frame.get("grip_endcap_replay_warning", false) and not frame.get("grip_endcap_replay_invalid", false)
	var body_applied := true
	var sk: Skeleton3D = actor.get("skeleton")
	for bone_index: int in (frame.solved_upper_body_bone_names as Array).size():
		var bone := sk.find_bone(String(frame.solved_upper_body_bone_names[bone_index]))
		if bone < 0:
			body_applied = false
			continue
		body_applied = body_applied and sk.get_bone_pose_position(bone).distance_to(frame.solved_upper_body_pose_positions[bone_index]) < 0.000001
		body_applied = body_applied and sk.get_bone_pose_scale(bone).distance_to(frame.solved_upper_body_pose_scales[bone_index]) < 0.000001
		var actual := sk.get_bone_pose_rotation(bone).normalized()
		var expected: Quaternion = frame.solved_upper_body_pose_rotations[bone_index]
		body_applied = body_applied and absf(actual.dot(expected.normalized())) > 0.999999
	var before_bones := _quality_bone_channels(sk)
	var before_state := var_to_bytes(actor.get("runtime_solved_replay_pose_state"))
	var malformed := frame.duplicate(true)
	malformed.solved_anchor_node_paths[index] = &"MissingPrimaryGripAnchor"
	var malformed_applied: bool = presenter.call("_apply_solved_runtime_replay_frame", actor,
		_player.held_item_nodes, _weapon, malformed, &"hand_right", &"hand_left", false)
	var malformed_rejected: bool = not malformed_applied and malformed.get("grip_endcap_replay_invalid", false) and before_bones == _quality_bone_channels(sk) and before_state == var_to_bytes(actor.get("runtime_solved_replay_pose_state"))
	return {"valid": warning_applied and body_applied and malformed_rejected,
		"finite_endcap_warning_applied": warning_applied, "body_channels_applied": body_applied,
		"warning_reason": frame.get("grip_endcap_replay_reason", ""),
		"malformed_anchor_rejected_atomically": malformed_rejected,
		"malformed_reason": malformed.get("grip_endcap_replay_reason", "")}

func _quality_bone_channels(sk: Skeleton3D) -> PackedByteArray:
	var channels: Array = []
	for bone: int in sk.get_bone_count():
		channels.append([sk.get_bone_pose_position(bone), sk.get_bone_pose_rotation(bone), sk.get_bone_pose_scale(bone)])
	return var_to_bytes(channels)
