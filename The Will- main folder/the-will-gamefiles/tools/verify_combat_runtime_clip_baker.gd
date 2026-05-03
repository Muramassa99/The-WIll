extends SceneTree

const CombatRuntimeClipBakerScript = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const CombatRuntimeClipScript = preload("res://core/models/combat_runtime_clip.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationChainPlayerScript = preload("res://runtime/combat/combat_animation_chain_player.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_runtime_clip_baker_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var chain: Array = [
		_build_motion_node(0, Vector3(0.0, 0.0, -0.55), Vector3(0.0, 0.0, 0.15), 0.01),
		_build_motion_node(1, Vector3(0.2, 0.05, -0.6), Vector3(0.2, 0.05, 0.1), 0.25),
		_build_motion_node(2, Vector3(0.35, 0.1, -0.45), Vector3(0.35, 0.1, 0.25), 0.25),
	]
	var baker = CombatRuntimeClipBakerScript.new()
	var clip = baker.bake_from_motion_node_chain(
		chain,
		{
			"clip_kind": CombatRuntimeClipScript.CLIP_KIND_SKILL_PLAYBACK,
			"source_draft_id": &"verify_runtime_clip",
			"source_skill_slot_id": &"skill_slot_1",
			"source_equipment_slot_id": &"hand_right",
			"source_weapon_wip_id": &"verify_weapon",
			"source_weapon_length_meters": 0.7,
			"sample_rate_hz": 30.0,
			"playback_speed_scale": 1.0,
		}
	)
	var first_tip: Vector3 = clip.baked_tip_positions_local[0] if clip != null and not clip.baked_tip_positions_local.is_empty() else Vector3.INF
	var final_tip: Vector3 = (
		clip.baked_tip_positions_local[clip.baked_tip_positions_local.size() - 1]
		if clip != null and not clip.baked_tip_positions_local.is_empty()
		else Vector3.INF
	)
	var clip_player: CombatAnimationChainPlayer = CombatAnimationChainPlayerScript.new()
	clip_player.prepare_runtime_clip(clip, 1.0, false)
	clip_player.start()
	clip_player.advance(0.125)
	var runtime_sample_length: float = clip_player.current_tip_position.distance_to(clip_player.current_pommel_position)
	var final_node: CombatAnimationMotionNode = chain[chain.size() - 1] as CombatAnimationMotionNode
	var final_right_upperarm_roll: float = (
		clip.baked_right_upperarm_roll_degrees[clip.baked_right_upperarm_roll_degrees.size() - 1]
		if clip != null and not clip.baked_right_upperarm_roll_degrees.is_empty()
		else INF
	)
	var final_left_upperarm_roll: float = (
		clip.baked_left_upperarm_roll_degrees[clip.baked_left_upperarm_roll_degrees.size() - 1]
		if clip != null and not clip.baked_left_upperarm_roll_degrees.is_empty()
		else INF
	)
	var upperarm_roll_samples_match: bool = (
		clip != null
		and clip.baked_right_upperarm_roll_degrees.size() == clip.get_frame_count()
		and clip.baked_left_upperarm_roll_degrees.size() == clip.get_frame_count()
		and absf(final_right_upperarm_roll - final_node.right_upperarm_roll_degrees) <= 0.0001
		and absf(final_left_upperarm_roll - final_node.left_upperarm_roll_degrees) <= 0.0001
	)
	var all_checks_passed: bool = (
		clip != null
		and clip.is_playable()
		and clip.get_frame_count() > 2
		and first_tip.distance_to((chain[0] as CombatAnimationMotionNode).tip_position_local) <= 0.0001
		and final_tip.distance_to(final_node.tip_position_local) <= 0.0001
		and clip.baked_grip_style_modes.size() == clip.get_frame_count()
		and absf(runtime_sample_length - 0.7) <= 0.0001
		and upperarm_roll_samples_match
	)
	var lines: PackedStringArray = []
	lines.append("clip_exists=%s" % str(clip != null))
	lines.append("clip_playable=%s" % str(clip != null and clip.is_playable()))
	lines.append("clip_kind=%s" % String(clip.clip_kind if clip != null else StringName()))
	lines.append("clip_motion_node_count=%d" % int(clip.motion_node_chain.size() if clip != null else 0))
	lines.append("clip_frame_count=%d" % int(clip.get_frame_count() if clip != null else 0))
	lines.append("clip_duration_seconds=%.2f" % float(clip.total_duration_seconds if clip != null else 0.0))
	lines.append("clip_has_multiple_frames=%s" % str(clip != null and clip.get_frame_count() > 2))
	lines.append("clip_first_tip_matches=%s" % str(first_tip.distance_to((chain[0] as CombatAnimationMotionNode).tip_position_local) <= 0.0001))
	lines.append("clip_final_tip_matches=%s" % str(final_tip.distance_to(final_node.tip_position_local) <= 0.0001))
	lines.append("clip_grip_state_samples_match=%s" % str(clip != null and clip.baked_grip_style_modes.size() == clip.get_frame_count()))
	lines.append("clip_player_runtime_length_locked=%s" % str(absf(runtime_sample_length - 0.7) <= 0.0001))
	lines.append("clip_upperarm_roll_samples_match=%s" % str(upperarm_roll_samples_match))
	lines.append("clip_final_right_upperarm_roll=%.2f" % final_right_upperarm_roll)
	lines.append("clip_final_left_upperarm_roll=%.2f" % final_left_upperarm_roll)
	lines.append("clip_player_trajectory_source=%s" % String(clip_player.current_trajectory_volume_state.get("source", StringName())))
	lines.append("all_checks_passed=%s" % str(all_checks_passed))
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(0 if all_checks_passed else 1)

func _build_motion_node(
	node_index: int,
	tip_position: Vector3,
	pommel_position: Vector3,
	transition_duration_seconds: float
) -> CombatAnimationMotionNode:
	var motion_node: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
	motion_node.node_index = node_index
	motion_node.node_id = StringName("verify_node_%02d" % node_index)
	motion_node.tip_position_local = tip_position
	motion_node.pommel_position_local = pommel_position
	motion_node.tip_curve_in_handle = Vector3(-0.04, 0.0, 0.0) if node_index > 0 else Vector3.ZERO
	motion_node.tip_curve_out_handle = Vector3(0.04, 0.0, 0.0) if node_index < 2 else Vector3.ZERO
	motion_node.pommel_curve_in_handle = Vector3(-0.04, 0.0, 0.0) if node_index > 0 else Vector3.ZERO
	motion_node.pommel_curve_out_handle = Vector3(0.04, 0.0, 0.0) if node_index < 2 else Vector3.ZERO
	motion_node.transition_duration_seconds = transition_duration_seconds
	motion_node.weapon_orientation_degrees = Vector3(0.0, 0.0, 0.0)
	motion_node.weapon_orientation_authored = true
	motion_node.right_upperarm_roll_degrees = -15.0 + float(node_index) * 22.5
	motion_node.left_upperarm_roll_degrees = 12.0 - float(node_index) * 18.0
	motion_node.preferred_grip_style_mode = &"grip_normal"
	motion_node.normalize()
	return motion_node
