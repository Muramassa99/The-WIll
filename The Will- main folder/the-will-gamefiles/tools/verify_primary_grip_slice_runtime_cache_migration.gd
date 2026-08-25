extends SceneTree

const CombatAnimationMotionNodeScript = preload(
	"res://core/models/combat_animation_motion_node.gd"
)
const CombatRuntimeClipScript = preload(
	"res://core/models/combat_runtime_clip.gd"
)
const PlayerRuntimeSkillPlaybackPresenterScript = preload(
	"res://runtime/player/player_runtime_skill_playback_presenter.gd"
)


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var presenter = PlayerRuntimeSkillPlaybackPresenterScript.new()
	var legacy_clip = _build_legacy_solved_source_clip()
	var legacy_result := {
		"baked_runtime_clip": legacy_clip,
	}
	var legacy_rejected := (
		presenter.call("_resolve_cached_runtime_clip", legacy_result) == null
	)
	var current_clip = legacy_clip.duplicate_clip()
	current_clip.solved_replay_track_source = (
		CombatRuntimeClipScript
		.SOLVED_REPLAY_TRACK_SOURCE_SKILL_CRAFTER_F_PLAYBACK
	)
	var current_result := {
		"baked_runtime_clip": current_clip,
	}
	var current_accepted := (
		presenter.call("_resolve_cached_runtime_clip", current_result) != null
	)
	if legacy_rejected and current_accepted:
		print("Primary grip slice runtime-cache migration verifier passed")
		quit(0)
		return
	push_error(
		"Grip slice cache migration failed: legacy_rejected=%s current_accepted=%s"
		% [legacy_rejected, current_accepted]
	)
	quit(1)


func _build_legacy_solved_source_clip() -> CombatRuntimeClip:
	var clip: CombatRuntimeClip = CombatRuntimeClipScript.new()
	var motion_node = CombatAnimationMotionNodeScript.new()
	var motion_node_chain: Array[Resource] = [motion_node]
	clip.motion_node_chain = motion_node_chain
	clip.baked_frame_times = PackedFloat32Array([0.0])
	clip.baked_upper_body_bone_names = [&"VerifierBone"]
	clip.baked_upper_body_bone_pose_rotations = [
		PackedVector4Array([Vector4(0.0, 0.0, 0.0, 1.0)]),
	]
	clip.upper_body_pose_track_source = (
		CombatRuntimeClipScript
		.UPPER_BODY_POSE_TRACK_SOURCE_SKILL_CRAFTER_AUTHORED_POSE
	)
	clip.solved_replay_track_source = &"skill_crafter_f_playback"
	return clip
