extends SceneTree

const CombatAnimationChainPlayerScript = preload("res://runtime/combat/combat_animation_chain_player.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatRuntimeClipScript = preload("res://core/models/combat_runtime_clip.gd")
const PlayerRuntimeSkillPlaybackPresenterScript = preload("res://runtime/player/player_runtime_skill_playback_presenter.gd")
const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/verify_runtime_solved_replay_track_bridge_offset_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var presenter = PlayerRuntimeSkillPlaybackPresenterScript.new()
	var source_clip = _build_source_clip_with_solved_replay_track()
	var target_clip = _build_target_bridge_clip()
	var copied: bool = presenter.call("_copy_cached_upper_body_pose_track", target_clip, source_clip, 0.2)
	var frame_available: Array = target_clip.baked_solved_replay_frame_available
	var bridge_frame_unavailable: bool = frame_available.size() > 1 and not bool(frame_available[0]) and not bool(frame_available[1])
	var authored_frame_available: bool = frame_available.size() > 2 and bool(frame_available[2])
	var solved_track_known: bool = target_clip.has_solved_replay_track()

	var target_clip_with_bridge_snapshot = _build_target_bridge_clip()
	var bridge_snapshot: Dictionary = _build_bridge_source_snapshot()
	var copied_with_snapshot: bool = presenter.call(
		"_copy_cached_upper_body_pose_track",
		target_clip_with_bridge_snapshot,
		source_clip,
		0.2,
		bridge_snapshot
	)
	var snapshot_frame_available: Array = target_clip_with_bridge_snapshot.baked_solved_replay_frame_available
	var snapshot_bridge_frames_available: bool = snapshot_frame_available.size() > 2 and bool(snapshot_frame_available[0]) and bool(snapshot_frame_available[1]) and bool(snapshot_frame_available[2])

	var chain_player = CombatAnimationChainPlayerScript.new()
	chain_player.prepare_runtime_clip(target_clip, 1.0, false)
	chain_player.start()
	var solved_available_during_bridge: bool = bool(chain_player.current_solved_replay_available)
	chain_player.advance(0.21)
	var solved_available_after_bridge: bool = bool(chain_player.current_solved_replay_available)
	var solved_bone_count_after_bridge: int = chain_player.current_solved_upper_body_bone_names.size()
	var solved_anchor_count_after_bridge: int = chain_player.current_solved_anchor_node_paths.size()
	var weapon_position_after_bridge: Vector3 = chain_player.current_solved_weapon_position_reference_local

	var snapshot_chain_player = CombatAnimationChainPlayerScript.new()
	snapshot_chain_player.prepare_runtime_clip(target_clip_with_bridge_snapshot, 1.0, false)
	snapshot_chain_player.start()
	var solved_available_with_snapshot_at_start: bool = bool(snapshot_chain_player.current_solved_replay_available)
	var snapshot_weapon_position_at_start: Vector3 = snapshot_chain_player.current_solved_weapon_position_reference_local
	snapshot_chain_player.advance(0.1)
	var snapshot_weapon_position_mid_bridge: Vector3 = snapshot_chain_player.current_solved_weapon_position_reference_local
	snapshot_chain_player.advance(0.11)
	var snapshot_weapon_position_after_bridge: Vector3 = snapshot_chain_player.current_solved_weapon_position_reference_local

	var all_checks_passed: bool = (
		copied
		and solved_track_known
		and bridge_frame_unavailable
		and authored_frame_available
		and not solved_available_during_bridge
		and solved_available_after_bridge
		and solved_bone_count_after_bridge == 2
		and solved_anchor_count_after_bridge == 2
		and weapon_position_after_bridge.distance_to(Vector3(0.0, 0.2, 0.3)) < 0.0001
		and copied_with_snapshot
		and snapshot_bridge_frames_available
		and solved_available_with_snapshot_at_start
		and snapshot_weapon_position_at_start.distance_to(Vector3(-0.2, 0.1, 0.0)) < 0.0001
		and snapshot_weapon_position_mid_bridge.distance_to(Vector3(-0.1, 0.15, 0.15)) < 0.0001
		and snapshot_weapon_position_after_bridge.distance_to(Vector3(0.0, 0.2, 0.3)) < 0.0001
	)

	var lines: PackedStringArray = []
	lines.append("copied=%s" % str(copied))
	lines.append("solved_track_known=%s" % str(solved_track_known))
	lines.append("bridge_frame_unavailable=%s" % str(bridge_frame_unavailable))
	lines.append("authored_frame_available=%s" % str(authored_frame_available))
	lines.append("solved_available_during_bridge=%s" % str(solved_available_during_bridge))
	lines.append("solved_available_after_bridge=%s" % str(solved_available_after_bridge))
	lines.append("solved_bone_count_after_bridge=%d" % solved_bone_count_after_bridge)
	lines.append("solved_anchor_count_after_bridge=%d" % solved_anchor_count_after_bridge)
	lines.append("weapon_position_after_bridge=%s" % str(weapon_position_after_bridge))
	lines.append("copied_with_snapshot=%s" % str(copied_with_snapshot))
	lines.append("snapshot_bridge_frames_available=%s" % str(snapshot_bridge_frames_available))
	lines.append("solved_available_with_snapshot_at_start=%s" % str(solved_available_with_snapshot_at_start))
	lines.append("snapshot_weapon_position_at_start=%s" % str(snapshot_weapon_position_at_start))
	lines.append("snapshot_weapon_position_mid_bridge=%s" % str(snapshot_weapon_position_mid_bridge))
	lines.append("snapshot_weapon_position_after_bridge=%s" % str(snapshot_weapon_position_after_bridge))
	lines.append("all_checks_passed=%s" % str(all_checks_passed))
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(0 if all_checks_passed else 1)

func _build_source_clip_with_solved_replay_track():
	var clip = CombatRuntimeClipScript.new()
	clip.clip_kind = CombatRuntimeClipScript.CLIP_KIND_SKILL_PLAYBACK
	clip.total_duration_seconds = 0.2
	var motion_node_chain: Array[Resource] = []
	motion_node_chain.append(_build_motion_node())
	clip.motion_node_chain = motion_node_chain
	clip.baked_frame_times = PackedFloat32Array([0.0, 0.1, 0.2])
	clip.baked_solved_replay_frame_available = [true, true, true]
	clip.solved_replay_track_source = CombatRuntimeClipScript.SOLVED_REPLAY_TRACK_SOURCE_SKILL_CRAFTER_F_PLAYBACK
	clip.solved_replay_reference_bone_name = CombatRuntimeClipScript.SOLVED_REPLAY_REFERENCE_BONE_NAME
	var bone_names: Array[StringName] = [&"CC_Base_Hip", &"CC_Base_Spine02"]
	clip.baked_solved_upper_body_bone_names = bone_names
	clip.baked_solved_upper_body_pose_positions = [
		PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.1, 0.0)]),
		PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.2, 0.0)]),
		PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.3, 0.0)]),
	]
	clip.baked_solved_upper_body_pose_rotations = [
		_pack_rotations([Quaternion.IDENTITY, Quaternion.IDENTITY]),
		_pack_rotations([Quaternion.IDENTITY, Quaternion(Vector3.RIGHT, 0.1)]),
		_pack_rotations([Quaternion.IDENTITY, Quaternion(Vector3.RIGHT, 0.2)]),
	]
	clip.baked_solved_upper_body_pose_scales = [
		PackedVector3Array([Vector3.ONE, Vector3.ONE]),
		PackedVector3Array([Vector3.ONE, Vector3.ONE]),
		PackedVector3Array([Vector3.ONE, Vector3.ONE]),
	]
	clip.baked_solved_weapon_positions_reference_local = PackedVector3Array([
		Vector3(0.0, 0.2, 0.3),
		Vector3(0.1, 0.2, 0.3),
		Vector3(0.2, 0.2, 0.3),
	])
	clip.baked_solved_weapon_rotations_reference_local = _pack_rotations([
		Quaternion.IDENTITY,
		Quaternion.IDENTITY,
		Quaternion.IDENTITY,
	])
	clip.baked_solved_weapon_scales_reference_local = PackedVector3Array([Vector3.ONE, Vector3.ONE, Vector3.ONE])
	var anchor_paths: Array[StringName] = [&"PrimaryGripAnchor", &"PrimaryGripAnchor/PrimaryGripBasisAnchor"]
	clip.baked_solved_anchor_node_paths = anchor_paths
	clip.baked_solved_anchor_positions_weapon_local = [
		PackedVector3Array([Vector3.ZERO, Vector3.ZERO]),
		PackedVector3Array([Vector3(0.1, 0.0, 0.0), Vector3(0.1, 0.0, 0.0)]),
		PackedVector3Array([Vector3(0.2, 0.0, 0.0), Vector3(0.2, 0.0, 0.0)]),
	]
	clip.baked_solved_anchor_rotations_weapon_local = [
		_pack_rotations([Quaternion.IDENTITY, Quaternion.IDENTITY]),
		_pack_rotations([Quaternion.IDENTITY, Quaternion.IDENTITY]),
		_pack_rotations([Quaternion.IDENTITY, Quaternion.IDENTITY]),
	]
	clip.baked_solved_anchor_scales_weapon_local = [
		PackedVector3Array([Vector3.ONE, Vector3.ONE]),
		PackedVector3Array([Vector3.ONE, Vector3.ONE]),
		PackedVector3Array([Vector3.ONE, Vector3.ONE]),
	]
	clip.normalize()
	return clip

func _build_bridge_source_snapshot() -> Dictionary:
	return {
		"valid": true,
		"bone_names": [&"CC_Base_Hip", &"CC_Base_Spine02"],
		"pose_positions": PackedVector3Array([Vector3(-0.05, 0.0, 0.0), Vector3(-0.03, 0.05, 0.0)]),
		"pose_rotations": _pack_rotations([Quaternion.IDENTITY, Quaternion.IDENTITY]),
		"pose_scales": PackedVector3Array([Vector3.ONE, Vector3.ONE]),
		"reference_bone_name": CombatRuntimeClipScript.SOLVED_REPLAY_REFERENCE_BONE_NAME,
		"reference_origin_id": CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE,
		"weapon_position_reference_local": Vector3(-0.2, 0.1, 0.0),
		"weapon_rotation_reference_local": Quaternion.IDENTITY,
		"weapon_scale_reference_local": Vector3.ONE,
		"weapon_reference_origin_id": CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE,
		"anchor_node_paths": [&"PrimaryGripAnchor", &"PrimaryGripAnchor/PrimaryGripBasisAnchor"],
		"anchor_positions_weapon_local": PackedVector3Array([Vector3(-0.1, 0.0, 0.0), Vector3(-0.1, 0.0, 0.0)]),
		"anchor_rotations_weapon_local": _pack_rotations([Quaternion.IDENTITY, Quaternion.IDENTITY]),
		"anchor_scales_weapon_local": PackedVector3Array([Vector3.ONE, Vector3.ONE]),
		"anchor_origin_id": CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
	}

func _build_target_bridge_clip():
	var clip = CombatRuntimeClipScript.new()
	clip.clip_kind = CombatRuntimeClipScript.CLIP_KIND_SKILL_PLAYBACK
	clip.total_duration_seconds = 0.4
	var motion_node_chain: Array[Resource] = []
	motion_node_chain.append(_build_motion_node())
	clip.motion_node_chain = motion_node_chain
	clip.baked_frame_times = PackedFloat32Array([0.0, 0.1, 0.2, 0.3, 0.4])
	clip.normalize()
	return clip

func _build_motion_node():
	var motion_node = CombatAnimationMotionNodeScript.new()
	motion_node.tip_position_local = Vector3(0.0, 0.0, 0.5)
	motion_node.pommel_position_local = Vector3(0.0, 0.0, -0.5)
	motion_node.transition_duration_seconds = 0.1
	motion_node.normalize()
	return motion_node

func _pack_rotations(rotations: Array) -> PackedVector4Array:
	var packed := PackedVector4Array()
	for rotation_variant: Variant in rotations:
		var rotation: Quaternion = rotation_variant as Quaternion
		rotation = rotation.normalized()
		packed.append(Vector4(rotation.x, rotation.y, rotation.z, rotation.w))
	return packed
