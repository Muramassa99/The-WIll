extends SceneTree

const Baker = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const Clip = preload("res://core/models/combat_runtime_clip.gd")
const MotionNode = preload("res://core/models/combat_animation_motion_node.gd")
const ChainPlayer = preload("res://runtime/combat/combat_animation_chain_player.gd")
const Incremental = preload("res://core/resolvers/combat_runtime_clip_incremental_resolver.gd")

var _checks: int = 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_verify_case("short", 3, 1.0)
	_verify_case("twenty_one_second_nodes", 20, 1.0)
	_verify_case("off_grid", 3, 0.23)
	_verify_cancellation()
	_verify_empty_and_single_node()
	print(JSON.stringify({"verifier": "runtime_clip_terminal_sample", "checks": _checks,
		"passed": _failures.is_empty(), "failures": _failures}))
	quit(0 if _failures.is_empty() else 1)

func _verify_case(label: String, visible_nodes: int, duration: float) -> void:
	var nodes: Array = []
	for index: int in range(visible_nodes + 1):
		nodes.append(_node(index, duration))
	# Projection makes a nearly finished interpolation visibly distinct from
	# the authoritative terminal node, whose state normal completion applies.
	var volume: Dictionary = {"enabled": true, "origin_local": Vector3.ZERO,
		"min_radius_meters": 0.0, "max_radius_meters": 0.2,
		"pivot_ratio_from_pommel": 0.5}
	var baker: CombatRuntimeClipBaker = Baker.new()
	var clip: CombatRuntimeClip = baker.bake_from_motion_node_chain(nodes, {
		"sample_rate_hz": 60.0, "trajectory_volume_config": volume,
	}) as CombatRuntimeClip
	var player: CombatAnimationChainPlayer = ChainPlayer.new()
	player.prepare(clip.motion_node_chain, baker.build_tip_curve(clip.motion_node_chain),
		baker.build_pommel_curve(clip.motion_node_chain), 1.0, false, volume)
	player.start()
	var reference: CombatRuntimeClip = Clip.new()
	baker._append_chain_player_frame(reference, player, 0.0)
	# Reproduce the original sample clock exactly for every preterminal frame.
	var step: float = 1.0 / clip.sample_rate_hz
	var elapsed: float = 0.0
	while elapsed + step < clip.total_duration_seconds - 0.0001:
		elapsed += step
		player.advance(step)
		baker._append_chain_player_frame(reference, player, elapsed)
	var prefix_count: int = reference.get_frame_count()
	_check(clip.get_frame_count() == prefix_count + 1, label + ":frame_count")
	for field: StringName in Incremental.INPUT_FRAME_FIELDS:
		var actual: Variant = clip.get(field)
		var expected: Variant = reference.get(field)
		_check(actual.slice(0, prefix_count) == expected, label + ":unchanged_prefix:" + String(field))
	var final_delta: float = maxf(clip.total_duration_seconds - elapsed, 0.0)
	if final_delta > 0.0001 and player.is_playing():
		player.advance(final_delta)
	if visible_nodes == 20:
		_check(player.is_playing(), label + ":reproduces_segment_clock_shortfall")
		_check(player.current_tip_position != (clip.motion_node_chain.back() as CombatAnimationMotionNode).tip_position_local,
			label + ":legacy_terminal_still_projected")
	# Complete through the normal player API. Its terminal state is the
	# independent oracle for every input channel, including discrete channels.
	player.advance(duration + 1.0)
	_check(not player.is_playing(), label + ":reference_finished")
	var terminal: CombatRuntimeClip = Clip.new()
	baker._append_chain_player_frame(terminal, player, clip.total_duration_seconds)
	for field: StringName in Incremental.INPUT_FRAME_FIELDS:
		var actual: Variant = clip.get(field)
		var expected: Variant = terminal.get(field)
		_check(actual[actual.size() - 1] == expected[0], label + ":exact_terminal:" + String(field))
	var last_node: CombatAnimationMotionNode = clip.motion_node_chain.back() as CombatAnimationMotionNode
	_check(clip.baked_tip_positions_local[-1] == last_node.tip_position_local, label + ":exact_tip")
	_check(clip.baked_pommel_positions_local[-1] == last_node.pommel_position_local, label + ":exact_pommel")
	_verify_sliced(nodes, volume, clip, label)

func _verify_sliced(nodes: Array, volume: Dictionary, synchronous: CombatRuntimeClip, label: String) -> void:
	for budget_usec: int in [1, 20000]:
		var job: RefCounted = Baker.new().begin_bake_from_motion_node_chain(nodes, {
			"sample_rate_hz": 60.0, "trajectory_volume_config": volume,
		})
		var case_label: String = "%s:sliced_%dus" % [label, budget_usec]
		_check(not job.done and job.clip.get_frame_count() == 0, case_label + ":begin_does_not_sample")
		var steps: int = 0
		var result: Dictionary = {}
		while not job.done and steps <= synchronous.get_frame_count() + 1:
			result = job.step(budget_usec)
			steps += 1
		_check(job.done and not job.cancelled, case_label + ":completed")
		_check(bool(result.get("done", false)) and not bool(result.get("cancelled", true)), case_label + ":result_completed")
		_check(int(result.get("sampled_frames", -1)) == synchronous.get_frame_count(), case_label + ":sample_count")
		_check(float(result.get("max_slice_ms", -1.0)) >= 0.0, case_label + ":slice_measurement")
		if budget_usec == 1 and synchronous.get_frame_count() > 1:
			_check(steps > 1, case_label + ":actually_resumed")
		_check(job.clip.total_duration_seconds == synchronous.total_duration_seconds, case_label + ":duration")
		for field: StringName in Incremental.INPUT_FRAME_FIELDS + Incremental.INPUT_METADATA_FIELDS:
			_check(job.clip.get(field) == synchronous.get(field), case_label + ":exact:" + String(field))
		var completed_result: Dictionary = job.step(0)
		job.cancel()
		_check(completed_result == result and not job.cancelled, case_label + ":finished_job_is_stable")

func _verify_cancellation() -> void:
	var nodes: Array = []
	for index: int in range(21):
		nodes.append(_node(index, 1.0))
	for sample_first: bool in [false, true]:
		var job: RefCounted = Baker.new().begin_bake_from_motion_node_chain(nodes, {"sample_rate_hz": 60.0})
		if sample_first:
			job.step(1)
		_check(not job.done, "cancel:job_was_pending")
		var before: Dictionary = {}
		for field: StringName in Incremental.INPUT_FRAME_FIELDS:
			before[field] = job.clip.get(field).duplicate()
		# A value normalization would clamp proves cancel never finalizes.
		job.clip.playback_speed_scale = 0.0
		job.cancel()
		var result: Dictionary = job.step(0)
		_check(job.done and job.cancelled and result.get("reason") == "cancelled", "cancel:terminal_state")
		_check(job.clip.playback_speed_scale == 0.0, "cancel:no_normalize")
		for field: StringName in Incremental.INPUT_FRAME_FIELDS:
			_check(job.clip.get(field) == before[field], "cancel:no_additional_work:" + String(field))
		_check(int(result.sampled_frames) == before[&"baked_frame_times"].size(), "cancel:partial_count")
		_check(job.step(20000) == result, "cancel:repeated_step_is_stable")

func _verify_empty_and_single_node() -> void:
	for nodes: Array in [[], [_node(0, 1.0)]]:
		var synchronous: CombatRuntimeClip = Baker.new().bake_from_motion_node_chain(nodes, {"sample_rate_hz": 60.0})
		_check(synchronous.get_frame_count() == nodes.size(), "zero_duration:frame_count")
		_verify_sliced(nodes, {}, synchronous, "zero_duration_%d_nodes" % nodes.size())

func _node(index: int, duration: float) -> CombatAnimationMotionNode:
	var node: CombatAnimationMotionNode = MotionNode.new()
	node.node_id = StringName("terminal_probe_%d" % index)
	node.node_index = index
	node.transition_duration_seconds = duration
	var offset: float = float(index) * 0.01
	node.tip_position_local = Vector3(offset, 0.3, -1.1)
	node.pommel_position_local = Vector3(offset, 0.3, -0.1)
	node.weapon_orientation_authored = true
	node.weapon_orientation_degrees = Vector3(offset, offset * 2.0, offset * 3.0)
	node.weapon_roll_degrees = float(index) * 1.37
	node.axial_reposition_offset = offset
	node.grip_seat_slide_offset = 0.2 + offset
	node.secondary_grip_seat_slide_offset = 0.1 + offset
	node.body_support_blend = 0.3 + offset
	node.right_upperarm_roll_degrees = float(index) * 0.7
	node.left_upperarm_roll_degrees = -float(index) * 0.8
	node.right_hand_proxy_authored = index % 2 == 0
	node.left_hand_proxy_authored = index % 2 != 0
	node.right_hand_proxy_tip_position_local = Vector3(offset, 0.2, -0.7)
	node.right_hand_proxy_pommel_position_local = Vector3(offset, 0.2, -0.5)
	node.left_hand_proxy_tip_position_local = Vector3(-offset, 0.1, -0.6)
	node.left_hand_proxy_pommel_position_local = Vector3(-offset, 0.1, -0.4)
	node.primary_hand_slot = MotionNode.PRIMARY_HAND_RIGHT
	node.two_hand_state = MotionNode.TWO_HAND_STATE_ONE_HAND
	return node

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
