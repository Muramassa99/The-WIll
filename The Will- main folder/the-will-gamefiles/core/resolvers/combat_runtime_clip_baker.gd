extends RefCounted
class_name CombatRuntimeClipBaker

const CombatRuntimeClipScript = preload("res://core/models/combat_runtime_clip.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationChainPlayerScript = preload("res://runtime/combat/combat_animation_chain_player.gd")

const DEFAULT_SAMPLE_RATE_HZ := 30.0

func bake_from_motion_node_chain(motion_node_chain: Array, options: Dictionary = {}):
	var clip = CombatRuntimeClipScript.new()
	clip.clip_kind = StringName(options.get("clip_kind", CombatRuntimeClipScript.CLIP_KIND_SKILL_PLAYBACK))
	clip.clip_id = _resolve_clip_id(clip.clip_kind, options)
	clip.source_draft_id = StringName(options.get("source_draft_id", StringName()))
	clip.source_skill_slot_id = StringName(options.get("source_skill_slot_id", StringName()))
	clip.source_idle_context_id = StringName(options.get("source_idle_context_id", StringName()))
	clip.source_equipment_slot_id = StringName(options.get("source_equipment_slot_id", StringName()))
	clip.source_weapon_wip_id = StringName(options.get("source_weapon_wip_id", StringName()))
	clip.source_weapon_length_meters = maxf(float(options.get("source_weapon_length_meters", 0.0)), 0.0)
	clip.playback_speed_scale = maxf(float(options.get("playback_speed_scale", 1.0)), 0.01)
	clip.loop_enabled = bool(options.get("loop_enabled", false))
	clip.sample_rate_hz = maxf(float(options.get("sample_rate_hz", DEFAULT_SAMPLE_RATE_HZ)), 1.0)
	clip.compile_diagnostics = (options.get("compile_diagnostics", []) as Array).duplicate(true)
	clip.retargeted_count = int(options.get("retargeted_count", 0))
	clip.degraded_node_count = int(options.get("degraded_node_count", 0))
	clip.hand_swap_bridge_count = int(options.get("hand_swap_bridge_count", 0))
	clip.motion_node_chain = _duplicate_motion_node_chain(motion_node_chain)
	clip.total_duration_seconds = _resolve_total_duration_seconds(clip.motion_node_chain)
	_sample_clip_frames(
		clip,
		options.get("trajectory_volume_config", {}) as Dictionary
	)
	clip.normalize()
	return clip

func build_tip_curve(motion_node_chain: Array) -> Curve3D:
	var curve := Curve3D.new()
	for motion_node_variant: Variant in motion_node_chain:
		var motion_node: CombatAnimationMotionNode = motion_node_variant as CombatAnimationMotionNode
		if motion_node == null:
			continue
		curve.add_point(
			motion_node.tip_position_local,
			motion_node.tip_curve_in_handle,
			motion_node.tip_curve_out_handle
		)
	return curve

func build_pommel_curve(motion_node_chain: Array) -> Curve3D:
	var curve := Curve3D.new()
	for motion_node_variant: Variant in motion_node_chain:
		var motion_node: CombatAnimationMotionNode = motion_node_variant as CombatAnimationMotionNode
		if motion_node == null:
			continue
		curve.add_point(
			motion_node.pommel_position_local,
			motion_node.pommel_curve_in_handle,
			motion_node.pommel_curve_out_handle
		)
	return curve

func _resolve_clip_id(clip_kind: StringName, options: Dictionary) -> StringName:
	var explicit_clip_id: StringName = StringName(options.get("clip_id", StringName()))
	if explicit_clip_id != StringName():
		return explicit_clip_id
	var draft_id: StringName = StringName(options.get("source_draft_id", StringName()))
	var slot_id: StringName = StringName(options.get("source_skill_slot_id", StringName()))
	var idle_context_id: StringName = StringName(options.get("source_idle_context_id", StringName()))
	var base_id: String = String(clip_kind)
	if slot_id != StringName():
		base_id += "_%s" % String(slot_id)
	elif idle_context_id != StringName():
		base_id += "_%s" % String(idle_context_id)
	elif draft_id != StringName():
		base_id += "_%s" % String(draft_id)
	return StringName(base_id)

func _duplicate_motion_node_chain(motion_node_chain: Array) -> Array[Resource]:
	var duplicated_chain: Array[Resource] = []
	for node_variant: Variant in motion_node_chain:
		var source_node: CombatAnimationMotionNode = node_variant as CombatAnimationMotionNode
		if source_node == null:
			continue
		var duplicate_node: CombatAnimationMotionNode = source_node.duplicate_node()
		duplicate_node.node_index = duplicated_chain.size()
		duplicate_node.normalize()
		duplicated_chain.append(duplicate_node)
	return duplicated_chain

func _resolve_total_duration_seconds(motion_node_chain: Array) -> float:
	if motion_node_chain.size() < 2:
		return 0.0
	var total_duration := 0.0
	for node_index: int in range(1, motion_node_chain.size()):
		var motion_node: CombatAnimationMotionNode = motion_node_chain[node_index] as CombatAnimationMotionNode
		if motion_node == null:
			continue
		total_duration += maxf(motion_node.transition_duration_seconds, 0.01)
	return total_duration

func _sample_clip_frames(clip, trajectory_volume_config: Dictionary) -> void:
	_clear_frame_data(clip)
	if clip.motion_node_chain.is_empty():
		return
	if clip.motion_node_chain.size() == 1:
		_append_motion_node_frame(clip, clip.motion_node_chain[0] as CombatAnimationMotionNode, 0.0)
		return
	var chain_player: CombatAnimationChainPlayer = CombatAnimationChainPlayerScript.new()
	chain_player.prepare(
		clip.motion_node_chain,
		build_tip_curve(clip.motion_node_chain),
		build_pommel_curve(clip.motion_node_chain),
		1.0,
		false,
		trajectory_volume_config
	)
	chain_player.start()
	_append_chain_player_frame(clip, chain_player, 0.0)
	var sample_step: float = 1.0 / maxf(clip.sample_rate_hz, 1.0)
	var elapsed_seconds := 0.0
	var total_duration: float = maxf(clip.total_duration_seconds, 0.0)
	while elapsed_seconds + sample_step < total_duration - 0.0001:
		elapsed_seconds += sample_step
		chain_player.advance(sample_step)
		_append_chain_player_frame(clip, chain_player, elapsed_seconds)
	var final_delta: float = maxf(total_duration - elapsed_seconds, 0.0)
	if final_delta > 0.0001 and chain_player.is_playing():
		chain_player.advance(final_delta)
	if clip.baked_frame_times.is_empty() or absf(clip.baked_frame_times[clip.baked_frame_times.size() - 1] - total_duration) > 0.0001:
		_append_chain_player_frame(clip, chain_player, total_duration)

func _clear_frame_data(clip) -> void:
	clip.baked_frame_times.clear()
	clip.baked_tip_positions_local.clear()
	clip.baked_pommel_positions_local.clear()
	clip.baked_weapon_orientation_degrees.clear()
	clip.baked_weapon_roll_degrees.clear()
	clip.baked_axial_reposition_offsets.clear()
	clip.baked_grip_seat_slide_offsets.clear()
	clip.baked_body_support_blends.clear()
	clip.baked_right_upperarm_roll_degrees.clear()
	clip.baked_left_upperarm_roll_degrees.clear()
	clip.baked_contact_grip_axes_local.clear()
	clip.baked_contact_axis_override_active.clear()
	clip.baked_two_hand_states.clear()
	clip.baked_primary_hand_slots.clear()
	clip.baked_grip_style_modes.clear()

func _append_chain_player_frame(
	clip,
	chain_player: CombatAnimationChainPlayer,
	time_seconds: float
) -> void:
	clip.baked_frame_times.append(maxf(time_seconds, 0.0))
	clip.baked_tip_positions_local.append(chain_player.current_tip_position)
	clip.baked_pommel_positions_local.append(chain_player.current_pommel_position)
	clip.baked_weapon_orientation_degrees.append(chain_player.current_weapon_orientation_degrees)
	clip.baked_weapon_roll_degrees.append(chain_player.current_weapon_roll)
	clip.baked_axial_reposition_offsets.append(chain_player.current_axial_reposition)
	clip.baked_grip_seat_slide_offsets.append(chain_player.current_grip_seat_slide)
	clip.baked_body_support_blends.append(chain_player.current_body_support_blend)
	clip.baked_right_upperarm_roll_degrees.append(chain_player.current_right_upperarm_roll)
	clip.baked_left_upperarm_roll_degrees.append(chain_player.current_left_upperarm_roll)
	clip.baked_contact_grip_axes_local.append(chain_player.current_contact_grip_axis_local)
	clip.baked_contact_axis_override_active.append(chain_player.current_contact_grip_axis_local_override_active)
	clip.baked_two_hand_states.append(chain_player.current_two_hand_state)
	clip.baked_primary_hand_slots.append(chain_player.current_primary_hand_slot)
	clip.baked_grip_style_modes.append(chain_player.current_preferred_grip_style_mode)

func _append_motion_node_frame(
	clip,
	motion_node: CombatAnimationMotionNode,
	time_seconds: float
) -> void:
	if motion_node == null:
		return
	clip.baked_frame_times.append(maxf(time_seconds, 0.0))
	clip.baked_tip_positions_local.append(motion_node.tip_position_local)
	clip.baked_pommel_positions_local.append(motion_node.pommel_position_local)
	clip.baked_weapon_orientation_degrees.append(_resolve_effective_weapon_orientation_degrees(motion_node))
	clip.baked_weapon_roll_degrees.append(motion_node.weapon_roll_degrees)
	clip.baked_axial_reposition_offsets.append(motion_node.axial_reposition_offset)
	clip.baked_grip_seat_slide_offsets.append(motion_node.grip_seat_slide_offset)
	clip.baked_body_support_blends.append(motion_node.body_support_blend)
	clip.baked_right_upperarm_roll_degrees.append(motion_node.right_upperarm_roll_degrees)
	clip.baked_left_upperarm_roll_degrees.append(motion_node.left_upperarm_roll_degrees)
	clip.baked_contact_grip_axes_local.append(_resolve_axis_between_positions(
		motion_node.pommel_position_local,
		motion_node.tip_position_local
	))
	clip.baked_contact_axis_override_active.append(false)
	clip.baked_two_hand_states.append(motion_node.two_hand_state)
	clip.baked_primary_hand_slots.append(motion_node.primary_hand_slot)
	clip.baked_grip_style_modes.append(motion_node.preferred_grip_style_mode)

func _resolve_effective_weapon_orientation_degrees(motion_node: CombatAnimationMotionNode) -> Vector3:
	if motion_node == null:
		return Vector3.ZERO
	if motion_node.weapon_orientation_authored:
		return motion_node.weapon_orientation_degrees
	if not motion_node.weapon_orientation_degrees.is_zero_approx():
		return motion_node.weapon_orientation_degrees
	return Vector3.ZERO

func _resolve_axis_between_positions(from_position: Vector3, to_position: Vector3) -> Vector3:
	var axis: Vector3 = to_position - from_position
	if axis.length_squared() <= 0.000001:
		return Vector3.ZERO
	return axis.normalized()
