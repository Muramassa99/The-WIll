extends SceneTree

const Entry = preload("res://runtime/combat/combat_runtime_entry_transition.gd")
const Baker = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const Clip = preload("res://core/models/combat_runtime_clip.gd")
const MotionNode = preload("res://core/models/combat_animation_motion_node.gd")
const Channels = preload("res://core/resolvers/combat_runtime_clip_incremental_resolver.gd")
const ChainPlayer = preload("res://runtime/combat/combat_animation_chain_player.gd")

var _checks: int = 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var body: CombatRuntimeClip = _body(false)
	var incoming: Dictionary = _incoming(body)
	var source: CombatAnimationMotionNode = _node(0, -0.5, 1.0)
	var body_before: Dictionary = _snapshot(body)
	var source_before: Dictionary = _snapshot(source)
	var incoming_before: Dictionary = incoming.duplicate(true)
	var combined: CombatRuntimeClip = Entry.build(body, incoming, source)
	_check(body.sample_rate_hz == 60.0 and body.get_frame_count() == 61, "fixture:60hz_one_second_body")
	_check(body.has_solved_replay_track() and body.has_upper_body_pose_track(), "fixture:complete_solved_and_legacy_tracks")
	_check(combined != null, "build:valid_packet")
	if combined != null:
		_verify_arrays(body, combined, incoming)
		for speed: float in [0.11, 1.0, 2.0]:
			_verify_playback(body, combined, incoming, speed)
			_verify_loop(body, combined, speed)
	_check(_snapshot(body) == body_before, "ownership:body_unchanged_after_build_and_playback")
	_check(_snapshot(source) == source_before, "ownership:source_node_unchanged")
	_check(incoming == incoming_before, "ownership:incoming_snapshot_unchanged")
	_check(not body.has_meta("entry_duration_seconds"), "ownership:entry_metadata_only_on_transient_clip")
	_verify_rejections(body, incoming, source)
	_verify_single_pose(source)
	print(JSON.stringify({"verifier": "combat_runtime_entry_transition", "checks": _checks,
		"passed": _failures.is_empty(), "failures": _failures}))
	quit(0 if _failures.is_empty() else 1)

func _verify_arrays(body: CombatRuntimeClip, combined: CombatRuntimeClip, incoming: Dictionary) -> void:
	var prefix_count: int = combined.get_frame_count() - body.get_frame_count()
	_check(prefix_count == 10, "build:ten_prefix_samples_before_160ms")
	_check(is_equal_approx(combined.total_duration_seconds, body.total_duration_seconds + 0.160), "build:duration_includes_entry_once")
	_check(is_equal_approx(float(combined.get_meta("entry_duration_seconds", -1.0)), 0.160), "build:entry_metadata")
	_check(combined.has_solved_replay_track() and combined.has_upper_body_pose_track(), "build:complete_tracks")
	_check(combined.motion_node_chain.size() == body.motion_node_chain.size() + 1, "build:transient_source_node_added")
	var expected_times := PackedFloat32Array()
	for time: float in body.baked_frame_times:
		expected_times.append(time + 0.160)
	_check(combined.baked_frame_times.slice(prefix_count) == expected_times, "arrays:body_times_shifted_only")
	for field: StringName in Channels.INPUT_FRAME_FIELDS + Channels.SOLVED_FRAME_FIELDS:
		if field == &"baked_frame_times":
			continue
		var actual: Variant = combined.get(field)
		_check(actual.size() == combined.get_frame_count(), "arrays:complete:" + String(field))
		_check(actual.slice(prefix_count) == body.get(field), "arrays:exact_body_tail:" + String(field))
	_check(combined.baked_upper_body_bone_pose_rotations.slice(prefix_count) == body.baked_upper_body_bone_pose_rotations,
		"arrays:exact_legacy_body_tail")
	for field: StringName in Channels.INPUT_METADATA_FIELDS + Channels.SOLVED_METADATA_FIELDS:
		_check(combined.get(field) == body.get(field), "metadata:unchanged:" + String(field))
	for index: int in combined.get_frame_count():
		if index > 0:
			_check(combined.baked_frame_times[index] > combined.baked_frame_times[index - 1], "clock:strictly_increasing_%d" % index)
		_check(bool(combined.baked_solved_replay_frame_available[index]), "availability:%d" % index)
	var flags: Array = combined.get_meta("baked_solved_replay_bridge_frame", [])
	_check(flags.size() == combined.get_frame_count(), "bridge:flag_count")
	for index: int in flags.size():
		_check(bool(flags[index]) == (index < prefix_count), "bridge:flag_%d" % index)
	_check(is_equal_approx(combined.baked_frame_times[prefix_count], 0.160), "bridge:exact_endpoint_timestamp")
	_check(combined.baked_solved_upper_body_pose_positions[0] == incoming.pose_positions, "start:current_bone_positions")
	_check(combined.baked_solved_upper_body_pose_scales[0] == incoming.pose_scales, "start:current_bone_scales")
	_check(combined.baked_solved_weapon_positions_reference_local[0] == incoming.weapon_position_reference_local, "start:current_weapon_position")
	_check(combined.baked_solved_anchor_positions_weapon_local[0] == incoming.anchor_positions_weapon_local, "start:current_anchor_positions")
	for bone: int in body.baked_solved_upper_body_bone_names.size():
		_check(_quat(combined.baked_solved_upper_body_pose_rotations[0][bone]).is_equal_approx(_quat(incoming.pose_rotations[bone])),
			"start:current_bone_rotation_%d" % bone)
	_check(_quat(combined.baked_solved_weapon_rotations_reference_local[0]).is_equal_approx(incoming.weapon_rotation_reference_local),
		"start:current_weapon_rotation")
	# Check a sampled interior point independently of the helper's interpolation.
	var index: int = 3
	var ratio: float = float(combined.baked_frame_times[index]) / 0.160
	var smooth: float = ratio * ratio * (3.0 - 2.0 * ratio)
	var expected: Vector3 = incoming.weapon_position_reference_local.lerp(body.baked_solved_weapon_positions_reference_local[0], smooth)
	_check(combined.baked_solved_weapon_positions_reference_local[index].distance_to(expected) < 0.000001, "bridge:smooth_current_to_destination")

func _verify_playback(body: CombatRuntimeClip, combined: CombatRuntimeClip, incoming: Dictionary, speed: float) -> void:
	var label: String = "speed_%s:" % str(speed)
	var player: CombatAnimationChainPlayer = ChainPlayer.new()
	player.prepare_runtime_clip(combined, speed, false)
	player.start()
	_check(player.current_solved_replay_available and player.current_solved_replay_bridge_frame, label + "current_pose_available_at_start")
	_check(player.current_solved_weapon_position_reference_local == incoming.weapon_position_reference_local, label + "starts_current_pose")
	player.advance(0.08)
	_check(absf(player._clip_elapsed - 0.08) < 0.0000001 and player.current_solved_replay_bridge_frame, label + "half_entry_uses_wall_time")
	player.advance(0.08)
	_check(absf(player._clip_elapsed - 0.160) < 0.0000001, label + "160ms_reaches_destination")
	_check(not player.current_solved_replay_bridge_frame, label + "destination_releases_bridge_authority")
	_check(player.current_solved_weapon_position_reference_local.distance_to(body.baked_solved_weapon_positions_reference_local[0]) < 0.000001,
		label + "destination_matches_body_first_frame")
	player.advance(0.1)
	_check(absf(player._clip_elapsed - (0.160 + 0.1 * speed)) < 0.0000001, label + "body_uses_authored_speed")
	var crossing: CombatAnimationChainPlayer = ChainPlayer.new()
	crossing.prepare_runtime_clip(combined, speed, false)
	crossing.start()
	crossing.advance(0.200)
	_check(absf(crossing._clip_elapsed - (0.160 + 0.040 * speed)) < 0.0000001, label + "boundary_crossing_preserves_unused_wall_time")
	var terminal: CombatAnimationChainPlayer = ChainPlayer.new()
	terminal.prepare_runtime_clip(combined, speed, false)
	terminal.start()
	var total_wall: float = 0.160 + body.total_duration_seconds / speed
	terminal.advance(total_wall - 0.0001)
	_check(terminal.is_playing(), label + "not_finished_before_terminal_wall_time")
	terminal.advance(0.0002)
	_check(not terminal.is_playing() and not terminal.current_solved_replay_bridge_frame, label + "finishes_at_expected_wall_time")
	_check(terminal.current_solved_weapon_position_reference_local == body.baked_solved_weapon_positions_reference_local[-1], label + "exact_terminal_frame")

func _verify_loop(body: CombatRuntimeClip, combined: CombatRuntimeClip, speed: float) -> void:
	var label: String = "loop_%s:" % str(speed)
	var player: CombatAnimationChainPlayer = ChainPlayer.new()
	player.prepare_runtime_clip(combined, speed, true)
	player.start()
	player.advance(0.160 + (body.total_duration_seconds + 0.1) / speed)
	_check(player.is_playing() and not player.current_solved_replay_bridge_frame, label + "loops_body_without_entry")
	_check(absf(player._clip_elapsed - 0.260) < 0.000001, label + "first_loop_preserves_overshoot")
	player.advance((body.total_duration_seconds * 2.0 + 0.1) / speed)
	_check(absf(player._clip_elapsed - 0.360) < 0.000001, label + "multiple_loops_skip_entry")
	_check(not player.current_solved_replay_bridge_frame, label + "no_return_to_incoming_pose")

func _verify_rejections(body: CombatRuntimeClip, incoming: Dictionary, source: CombatAnimationMotionNode) -> void:
	_check(Entry.build(null, incoming, source) == null, "reject:null_body")
	_check(Entry.build(body, incoming, null) == null, "reject:null_current_node")
	_check(Entry.build(body, {}, source) == null, "reject:missing_incoming")
	for field: String in ["reference_origin_id", "weapon_reference_origin_id", "anchor_origin_id", "reference_bone_name"]:
		var changed: Dictionary = incoming.duplicate(true)
		changed[field] = &"WrongCoordinateFrame"
		_check(Entry.build(body, changed, source) == null, "reject:mismatched_" + field)
	for field: String in ["bone_names", "anchor_node_paths", "pose_positions", "anchor_positions_weapon_local"]:
		var changed: Dictionary = incoming.duplicate(true)
		changed[field] = []
		_check(Entry.build(body, changed, source) == null, "reject:incomplete_" + field)
	var unavailable: CombatRuntimeClip = body.duplicate_clip()
	unavailable.baked_solved_replay_frame_available[0] = false
	_check(Entry.build(unavailable, incoming, source) == null, "reject:unavailable_destination")

func _verify_single_pose(source: CombatAnimationMotionNode) -> void:
	var body: CombatRuntimeClip = _body(true)
	var before: Dictionary = _snapshot(body)
	var combined: CombatRuntimeClip = Entry.build(body, _incoming(body), source)
	_check(body.get_frame_count() == 1 and body.total_duration_seconds == 0.0, "single:one_visible_pose_fixture")
	_check(combined != null, "single:build")
	if combined == null:
		return
	_check(combined.get_frame_count() == 11 and is_equal_approx(combined.total_duration_seconds, 0.160), "single:entry_then_one_endpoint")
	for speed: float in [0.11, 1.0, 2.0]:
		for loop: bool in [false, true]:
			var label: String = "single_speed_%s_loop_%s:" % [str(speed), str(loop)]
			var player: CombatAnimationChainPlayer = ChainPlayer.new()
			player.prepare_runtime_clip(combined, speed, loop)
			player.start()
			player.advance(0.160)
			_check(player.is_playing() == loop, label + "expected_playing_state")
			_check(not player.current_solved_replay_bridge_frame, label + "entry_completed")
			_check(player.current_solved_weapon_position_reference_local == body.baked_solved_weapon_positions_reference_local[0], label + "holds_destination")
			player.advance(4.0)
			_check(player.current_solved_weapon_position_reference_local == body.baked_solved_weapon_positions_reference_local[0], label + "never_loops_entry")
	_check(_snapshot(body) == before, "single:body_unchanged")

func _body(single: bool) -> CombatRuntimeClip:
	var nodes: Array = [_node(0, 0.0, 1.0)]
	if not single:
		nodes.append(_node(1, 0.2, 0.4))
		nodes.append(_node(2, 0.5, 0.6))
	var body: CombatRuntimeClip = Baker.new().bake_from_motion_node_chain(nodes, {
		"sample_rate_hz": 60.0, "source_weapon_length_meters": 1.0, "playback_speed_scale": 0.11,
	})
	body.solved_replay_track_source = Clip.SOLVED_REPLAY_TRACK_SOURCE_SKILL_CRAFTER_F_PLAYBACK
	body.upper_body_pose_track_source = Clip.UPPER_BODY_POSE_TRACK_SOURCE_SKILL_CRAFTER_AUTHORED_POSE
	body.baked_solved_upper_body_bone_names = [&"CC_Base_Hip", &"CC_Base_Spine02"]
	body.baked_upper_body_bone_names = [&"CC_Base_Spine02"]
	body.baked_solved_anchor_node_paths = [&"PrimaryGripAnchor", &"PrimaryGripAnchor/PrimaryGripBasisAnchor"]
	for time: float in body.baked_frame_times:
		var rotations: PackedVector4Array = _pack_rotations([Quaternion(Vector3.UP, time * 0.1), Quaternion(Vector3.RIGHT, time * 0.2)])
		body.baked_solved_replay_frame_available.append(true)
		body.baked_solved_upper_body_pose_positions.append(PackedVector3Array([Vector3(time * 0.01, 0.0, 0.0), Vector3(0.0, 0.2 + time, 0.0)]))
		body.baked_solved_upper_body_pose_rotations.append(rotations)
		body.baked_solved_upper_body_pose_scales.append(PackedVector3Array([Vector3.ONE, Vector3(1.0, 1.0 + time * 0.01, 1.0)]))
		body.baked_upper_body_bone_pose_rotations.append(PackedVector4Array([rotations[1]]))
		body.baked_solved_weapon_positions_reference_local.append(Vector3(time, 0.2, 0.3))
		body.baked_solved_weapon_rotations_reference_local.append(_pack(Quaternion(Vector3.UP, time * 0.3)))
		body.baked_solved_weapon_scales_reference_local.append(Vector3.ONE)
		body.baked_solved_anchor_positions_weapon_local.append(PackedVector3Array([Vector3(0.0, time * 0.01, 0.0), Vector3(0.0, 0.1, 0.0)]))
		body.baked_solved_anchor_rotations_weapon_local.append(_pack_rotations([Quaternion.IDENTITY, Quaternion(Vector3.FORWARD, time * 0.1)]))
		body.baked_solved_anchor_scales_weapon_local.append(PackedVector3Array([Vector3.ONE, Vector3.ONE]))
	body.normalize()
	return body

func _incoming(body: CombatRuntimeClip) -> Dictionary:
	return {"valid": true, "bone_names": body.baked_solved_upper_body_bone_names.duplicate(),
		"pose_positions": PackedVector3Array([Vector3(-0.1, 0.0, 0.0), Vector3(0.0, 0.1, -0.1)]),
		"pose_rotations": _pack_rotations([Quaternion(Vector3.UP, -0.4), Quaternion(Vector3.RIGHT, -0.2)]),
		"pose_scales": PackedVector3Array([Vector3.ONE, Vector3(1.0, 0.98, 1.0)]),
		"reference_bone_name": body.solved_replay_reference_bone_name,
		"reference_origin_id": body.solved_replay_reference_origin_id,
		"weapon_reference_origin_id": body.baked_solved_weapon_reference_origin_id,
		"weapon_position_reference_local": Vector3(-0.4, 0.1, -0.2),
		"weapon_rotation_reference_local": Quaternion(Vector3.UP, -0.5),
		"weapon_scale_reference_local": Vector3(0.9, 0.9, 0.9),
		"anchor_node_paths": body.baked_solved_anchor_node_paths.duplicate(),
		"anchor_positions_weapon_local": PackedVector3Array([Vector3(0.0, -0.1, 0.0), Vector3(0.0, 0.05, 0.0)]),
		"anchor_rotations_weapon_local": _pack_rotations([Quaternion(Vector3.RIGHT, -0.2), Quaternion.IDENTITY]),
		"anchor_scales_weapon_local": PackedVector3Array([Vector3.ONE, Vector3.ONE]),
		"anchor_origin_id": body.baked_solved_anchor_origin_id}

func _node(index: int, x: float, duration: float) -> CombatAnimationMotionNode:
	var node: CombatAnimationMotionNode = MotionNode.new()
	node.node_index = index
	node.node_id = StringName("entry_fixture_%d" % index)
	node.tip_position_local = Vector3(x, 0.0, 0.5)
	node.pommel_position_local = Vector3(x, 0.0, -0.5)
	node.grip_seat_slide_offset = 0.4
	node.transition_duration_seconds = duration
	node.normalize()
	return node

func _snapshot(resource: Resource) -> Dictionary:
	var result: Dictionary = {}
	for info: Dictionary in resource.get_property_list():
		if int(info.usage) & PROPERTY_USAGE_STORAGE == 0 or info.name == "script":
			continue
		var value: Variant = resource.get(info.name)
		if value is Resource:
			result[info.name] = _snapshot(value)
		elif value is Array:
			var values: Array = []
			for item: Variant in value:
				values.append(_snapshot(item) if item is Resource else item)
			result[info.name] = values.duplicate(true)
		else:
			result[info.name] = value
	return result.duplicate(true)

func _pack_rotations(rotations: Array) -> PackedVector4Array:
	var result := PackedVector4Array()
	for rotation: Quaternion in rotations:
		result.append(_pack(rotation))
	return result

func _pack(value: Quaternion) -> Vector4:
	return Vector4(value.x, value.y, value.z, value.w)

func _quat(value: Vector4) -> Quaternion:
	return Quaternion(value.x, value.y, value.z, value.w)

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
