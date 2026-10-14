extends SceneTree

## The interpolation path must carry the same entry/exit contract as exact
## samples. Otherwise runtime omits bridge anchoring and reports an unfinished
## one-hand to two-hand transition as an ordinary, completed grip frame.
const Chain = preload("res://runtime/combat/combat_animation_chain_player.gd")
const Clip = preload("res://core/models/combat_runtime_clip.gd")
const Motion = preload("res://core/models/combat_animation_motion_node.gd")
const Presenter = preload("res://runtime/player/player_runtime_skill_playback_presenter.gd")
var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	_checks += 1
	if not value: _failures.append(label)

func _run() -> void:
	var clip := Clip.new()
	clip.total_duration_seconds = 3.0
	clip.baked_frame_times = PackedFloat32Array([0.0, 1.0, 2.0, 3.0])
	clip.solved_replay_track_source = Clip.SOLVED_REPLAY_TRACK_SOURCE_SKILL_CRAFTER_F_PLAYBACK
	clip.baked_solved_upper_body_bone_names.assign([&"CC_Base_R_Hand"])
	clip.set_meta("baked_solved_replay_bridge_frame", [false, true, false, false])
	for index: int in 4:
		clip.baked_tip_positions_local.append(Vector3(float(index), 1.0, 0.0))
		clip.baked_pommel_positions_local.append(Vector3(float(index), 0.0, 0.0))
		clip.baked_two_hand_states.append(Motion.TWO_HAND_STATE_ONE_HAND if index < 2 else Motion.TWO_HAND_STATE_TWO_HAND)
		clip.baked_solved_replay_frame_available.append(true)
		clip.baked_solved_upper_body_pose_positions.append(PackedVector3Array([Vector3.ZERO]))
		clip.baked_solved_upper_body_pose_rotations.append(PackedVector4Array([Vector4(0.0, 0.0, 0.0, 1.0)]))
		clip.baked_solved_upper_body_pose_scales.append(PackedVector3Array([Vector3.ONE]))
		clip.baked_solved_weapon_positions_reference_local.append(Vector3(float(index), 0.0, 0.0))
		clip.baked_solved_weapon_rotations_reference_local.append(Vector4(0.0, 0.0, 0.0, 1.0))
		clip.baked_solved_weapon_scales_reference_local.append(Vector3.ONE)
		clip.baked_solved_anchor_positions_weapon_local.append(PackedVector3Array())
		clip.baked_solved_anchor_rotations_weapon_local.append(PackedVector4Array())
		clip.baked_solved_anchor_scales_weapon_local.append(PackedVector3Array())
	var chain := Chain.new()
	chain.prepare_runtime_clip(clip)
	for sample: Dictionary in [
		{"time": 0.0, "bridge": false, "two": false},
		{"time": 0.001, "bridge": true, "two": false},
		{"time": 0.5, "bridge": true, "two": false},
		{"time": 1.0, "bridge": true, "two": false},
		{"time": 1.25, "bridge": true, "two": false},
		{"time": 1.75, "bridge": true, "two": true},
		{"time": 1.999, "bridge": true, "two": true},
		{"time": 2.0, "bridge": false, "two": true},
		{"time": 2.5, "bridge": false, "two": true},
		{"time": 3.0, "bridge": false, "two": true},
	]:
		chain._apply_runtime_clip_sample(sample.time)
		var label := " at " + str(sample.time)
		_check(chain.current_solved_replay_available, "valid replay" + label)
		_check(chain.current_solved_replay_bridge_frame == sample.bridge, "correct bridge status" + label)
		_check((chain.current_two_hand_state == Motion.TWO_HAND_STATE_TWO_HAND) == sample.two, "discrete support state unchanged" + label)
		_check(absf(chain.current_solved_weapon_position_reference_local.x - sample.time) < 0.00001, "continuous pose unchanged" + label)
	# Exact interpolator endpoints must not leak the adjacent bridge flag.
	chain._interpolate_runtime_clip_solved_replay_frames(0, 1, 0.0)
	_check(not chain.current_solved_replay_bridge_frame, "exact incoming ordinary endpoint")
	chain._interpolate_runtime_clip_solved_replay_frames(1, 2, 1.0)
	_check(not chain.current_solved_replay_bridge_frame, "exact completed outgoing endpoint")
	clip.baked_solved_replay_frame_available[2] = false
	chain._interpolate_runtime_clip_solved_replay_frames(1, 2, 0.7)
	_check(chain.current_solved_replay_available and chain.current_solved_replay_bridge_frame, "available bridge fallback retains bridge status")
	clip.baked_solved_replay_frame_available[1] = false
	chain._interpolate_runtime_clip_solved_replay_frames(1, 2, 0.7)
	_check(not chain.current_solved_replay_available and not chain.current_solved_replay_bridge_frame, "unavailable interval clears stale bridge status")
	# Decimal duration is float64, whereas the terminal sample timestamp is
	# PackedFloat32. Public completion must take the terminal frame exactly.
	clip.baked_solved_replay_frame_available.assign([true, true, true, true])
	clip.total_duration_seconds = 0.3
	clip.baked_frame_times = PackedFloat32Array([0.0, 0.1, 0.2, 0.3])
	clip.set_meta("baked_solved_replay_bridge_frame", [true, true, true, false])
	chain.prepare_runtime_clip(clip)
	chain.start()
	chain.advance(0.299)
	_check(chain.is_playing() and chain.current_solved_replay_bridge_frame, "decimal duration remains a bridge before completion")
	chain.advance(0.001)
	_check(not chain.is_playing(), "decimal duration stops playback")
	_check(not chain.current_solved_replay_bridge_frame and chain.current_solved_replay_available, "decimal completion applies ordinary terminal frame")
	_check(chain.current_solved_weapon_position_reference_local == Vector3(3.0, 0.0, 0.0), "decimal completion uses exact terminal pose")
	_check(chain.current_two_hand_state == Motion.TWO_HAND_STATE_TWO_HAND, "decimal completion retains terminal two-hand state")
	for node_count: int in [2, 3]: _check_cached_skill_body(node_count)
	var report := {"passed": _failures.is_empty(), "checks": _checks, "failures": _failures}
	var path := "C:/WORKSPACE/test_artifacts/solved_replay_bridge_status_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t"))
	print("Solved replay bridge status: ", _checks - _failures.size(), "/", _checks, " PASS; ", path)
	for failure: String in _failures: push_error(failure)
	quit(0 if _failures.is_empty() else 1)

func _check_cached_skill_body(node_count: int) -> void:
	var presenter := Presenter.new()
	var nodes: Array = []
	for index: int in node_count:
		var node := Motion.new()
		node.node_id = StringName("saved_body_" + str(index))
		node.node_index = index
		node.transition_duration_seconds = 0.3
		node.tip_position_local = Vector3(index * 0.01, 1.0, 0.0)
		node.pommel_position_local = Vector3(index * 0.01, 0.0, 0.0)
		node.two_hand_state = Motion.TWO_HAND_STATE_TWO_HAND
		nodes.append(node)
	var source: Resource = presenter._bake_runtime_playback_clip(nodes, {})
	source.solved_replay_track_source = Clip.SOLVED_REPLAY_TRACK_SOURCE_SKILL_CRAFTER_F_PLAYBACK
	source.baked_solved_upper_body_bone_names.assign([&"CC_Base_R_Hand"])
	for time: float in source.baked_frame_times:
		source.baked_solved_replay_frame_available.append(true)
		source.baked_solved_upper_body_pose_positions.append(PackedVector3Array([Vector3.ZERO]))
		source.baked_solved_upper_body_pose_rotations.append(PackedVector4Array([Vector4(0.0, 0.0, 0.0, 1.0)]))
		source.baked_solved_upper_body_pose_scales.append(PackedVector3Array([Vector3.ONE]))
		source.baked_solved_weapon_positions_reference_local.append(Vector3(time * 0.01, 0.0, 0.0))
		source.baked_solved_weapon_rotations_reference_local.append(Vector4(0.0, 0.0, 0.0, 1.0))
		source.baked_solved_weapon_scales_reference_local.append(Vector3.ONE)
		source.baked_solved_anchor_positions_weapon_local.append(PackedVector3Array())
		source.baked_solved_anchor_rotations_weapon_local.append(PackedVector4Array())
		source.baked_solved_anchor_scales_weapon_local.append(PackedVector3Array())
	var validated: Resource = presenter._resolve_cached_runtime_clip({"baked_runtime_clip": source})
	_check(validated != null and validated.has_solved_replay_track(), "saved complete cache accepted for " + str(node_count) + " nodes")
	var entry: Resource = nodes[0].duplicate_node()
	entry.tip_position_local.x -= 0.2
	entry.pommel_position_local.x -= 0.2
	entry.two_hand_state = Motion.TWO_HAND_STATE_ONE_HAND
	var prepared: Dictionary = presenter._build_runtime_skill_chain_with_entry(nodes, entry, validated)
	var prepared_nodes: Array = prepared.motion_node_chain
	_check(prepared_nodes.size() == node_count + 1, "entry preserves full saved node count " + str(node_count))
	for index: int in node_count:
		_check(prepared_nodes[index + 1].node_id == nodes[index].node_id, "entry preserves saved node order " + str(index))
	var legacy: Dictionary = presenter._build_runtime_skill_chain_with_entry(nodes, entry, null)
	_check(legacy.motion_node_chain.size() == node_count and legacy.motion_node_chain[1].node_id == nodes[1].node_id,
		"uncached entry retains historical index-one policy")
	var target: Resource = presenter._bake_runtime_playback_clip(prepared_nodes, {})
	var offset: float = prepared.entry_bridge_duration_seconds
	_check(absf(target.total_duration_seconds - source.total_duration_seconds - offset) < 0.000001,
		"entry duration adds to full saved body duration")
	var snapshot := {"valid": true, "bone_names": source.baked_solved_upper_body_bone_names,
		"reference_origin_id": source.solved_replay_reference_origin_id,
		"weapon_reference_origin_id": source.baked_solved_weapon_reference_origin_id,
		"anchor_origin_id": source.baked_solved_anchor_origin_id,
		"pose_positions": source.baked_solved_upper_body_pose_positions[0],
		"pose_rotations": source.baked_solved_upper_body_pose_rotations[0],
		"pose_scales": source.baked_solved_upper_body_pose_scales[0],
		"weapon_position_reference_local": Vector3(-0.2, 0.0, 0.0), "weapon_rotation_reference_local": Quaternion.IDENTITY,
		"weapon_scale_reference_local": Vector3.ONE, "anchor_node_paths": [],
		"anchor_positions_weapon_local": PackedVector3Array(), "anchor_rotations_weapon_local": PackedVector4Array(),
		"anchor_scales_weapon_local": PackedVector3Array()}
	_check(presenter._is_valid_solved_replay_bridge_snapshot(snapshot, source.baked_solved_upper_body_bone_names, []),
		"entry snapshot follows solved replay origin contract")
	_check(presenter._copy_cached_upper_body_pose_track(target, validated, offset, snapshot), "cached full track copies after entry")
	var replay := Chain.new()
	replay.prepare_runtime_clip(target)
	for ratio: float in [0.0, 0.5, 1.0]:
		var source_time: float = source.total_duration_seconds * ratio
		replay._apply_runtime_clip_sample(offset + source_time + (0.0000001 if ratio == 0.0 else 0.0))
		_check(replay.current_solved_replay_available and not replay.current_solved_replay_bridge_frame,
			"saved body sample is available and outside entry at ratio " + str(ratio))
		_check(replay.current_solved_weapon_position_reference_local.distance_to(Vector3(source_time * 0.01, 0.0, 0.0)) < 0.000001,
			"saved body first/middle/terminal pose identity at ratio " + str(ratio))
	replay.start()
	replay.advance(target.total_duration_seconds)
	_check(not replay.is_playing() and not replay.current_solved_replay_bridge_frame,
		"full cached skill reaches ordinary terminal frame")
	_check(replay.current_solved_weapon_position_reference_local == source.baked_solved_weapon_positions_reference_local[-1],
		"full cached skill reaches exact saved terminal transform")
