extends SceneTree

const CombatAnimationChainPlayerScript = preload("res://runtime/combat/combat_animation_chain_player.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatRuntimeClipScript = preload("res://core/models/combat_runtime_clip.gd")
const PlayerRuntimeSkillPlaybackPresenterScript = preload("res://runtime/player/player_runtime_skill_playback_presenter.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/verify_runtime_clip_pose_track_bridge_offset_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var presenter = PlayerRuntimeSkillPlaybackPresenterScript.new()
	var source_clip = _build_source_clip_with_pose_track()
	var target_clip = _build_target_bridge_clip()
	var copied: bool = presenter.call("_copy_cached_upper_body_pose_track", target_clip, source_clip, 0.2)
	var stale_source_clip = _build_source_clip_with_pose_track()
	stale_source_clip.upper_body_pose_track_source = StringName()
	var stale_target_clip = _build_target_bridge_clip()
	var stale_copied: bool = presenter.call("_copy_cached_upper_body_pose_track", stale_target_clip, stale_source_clip, 0.2)
	var pose_frames: Array = target_clip.baked_upper_body_bone_pose_rotations
	var first_bridge_frame_empty: bool = pose_frames.size() > 0 and (pose_frames[0] as PackedVector4Array).is_empty()
	var second_bridge_frame_empty: bool = pose_frames.size() > 1 and (pose_frames[1] as PackedVector4Array).is_empty()
	var first_authored_frame_present: bool = pose_frames.size() > 2 and not (pose_frames[2] as PackedVector4Array).is_empty()

	var chain_player = CombatAnimationChainPlayerScript.new()
	chain_player.prepare_runtime_clip(target_clip, 1.0, false)
	chain_player.start()
	var pose_available_during_bridge: bool = bool(chain_player.current_upper_body_pose_available)
	chain_player.advance(0.21)
	var pose_available_after_bridge: bool = bool(chain_player.current_upper_body_pose_available)

	var all_checks_passed: bool = (
		copied
		and not stale_copied
		and target_clip.has_upper_body_pose_track()
		and first_bridge_frame_empty
		and second_bridge_frame_empty
		and first_authored_frame_present
		and not pose_available_during_bridge
		and pose_available_after_bridge
	)

	var lines: PackedStringArray = []
	lines.append("copied=%s" % str(copied))
	lines.append("stale_copied=%s" % str(stale_copied))
	lines.append("target_has_pose_track=%s" % str(target_clip.has_upper_body_pose_track()))
	lines.append("first_bridge_frame_empty=%s" % str(first_bridge_frame_empty))
	lines.append("second_bridge_frame_empty=%s" % str(second_bridge_frame_empty))
	lines.append("first_authored_frame_present=%s" % str(first_authored_frame_present))
	lines.append("pose_available_during_bridge=%s" % str(pose_available_during_bridge))
	lines.append("pose_available_after_bridge=%s" % str(pose_available_after_bridge))
	lines.append("all_checks_passed=%s" % str(all_checks_passed))
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(0 if all_checks_passed else 1)

func _build_source_clip_with_pose_track():
	var clip = CombatRuntimeClipScript.new()
	clip.clip_kind = CombatRuntimeClipScript.CLIP_KIND_SKILL_PLAYBACK
	clip.total_duration_seconds = 0.2
	var motion_node_chain: Array[Resource] = []
	motion_node_chain.append(_build_motion_node())
	clip.motion_node_chain = motion_node_chain
	clip.baked_frame_times = PackedFloat32Array([0.0, 0.1, 0.2])
	var bone_names: Array[StringName] = [&"CC_Base_Spine02"]
	clip.baked_upper_body_bone_names = bone_names
	clip.baked_upper_body_bone_pose_rotations = [
		_pack_rotation(Quaternion.IDENTITY),
		_pack_rotation(Quaternion(Vector3.RIGHT, 0.15)),
		_pack_rotation(Quaternion(Vector3.RIGHT, 0.30)),
	]
	clip.upper_body_pose_track_source = CombatRuntimeClipScript.UPPER_BODY_POSE_TRACK_SOURCE_SKILL_CRAFTER_AUTHORED_POSE
	clip.normalize()
	return clip

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

func _build_motion_node() -> CombatAnimationMotionNode:
	var motion_node: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
	motion_node.node_id = &"verify_node"
	motion_node.normalize()
	return motion_node

func _pack_rotation(rotation: Quaternion) -> PackedVector4Array:
	var normalized_rotation: Quaternion = rotation.normalized()
	return PackedVector4Array([
		Vector4(normalized_rotation.x, normalized_rotation.y, normalized_rotation.z, normalized_rotation.w)
	])
