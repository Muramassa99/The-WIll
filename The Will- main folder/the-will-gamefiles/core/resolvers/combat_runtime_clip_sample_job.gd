extends RefCounted
class_name CombatRuntimeClipSampleJob

const ChainPlayer = preload("res://runtime/combat/combat_animation_chain_player.gd")

## Pure-data sampling only. The caller must not publish clip until done and
## not cancelled. A positive budget yields after a complete sample operation.
var clip
var done: bool = false
var cancelled: bool = false

var _baker
var _chain_player: CombatAnimationChainPlayer
var _sample_step: float = 0.0
var _elapsed_seconds: float = 0.0
var _total_duration: float = 0.0
var _started: bool = false
var _max_slice_ms: float = 0.0

func _init(baker, target_clip, trajectory_volume_config: Dictionary) -> void:
	_baker = baker
	clip = target_clip
	_baker._clear_frame_data(clip)
	_sample_step = 1.0 / maxf(clip.sample_rate_hz, 1.0)
	_total_duration = maxf(clip.total_duration_seconds, 0.0)
	if clip.motion_node_chain.size() >= 2:
		_chain_player = ChainPlayer.new()
		_chain_player.prepare(clip.motion_node_chain,
			_baker.build_tip_curve(clip.motion_node_chain),
			_baker.build_pommel_curve(clip.motion_node_chain),
			1.0, false, trajectory_volume_config)

func step(budget_usec: int = 20000) -> Dictionary:
	if done:
		return _result()
	var started_usec: int = Time.get_ticks_usec()
	while not done:
		if not _started:
			_started = true
			if clip.motion_node_chain.is_empty():
				_finish()
			elif clip.motion_node_chain.size() == 1:
				_baker._append_motion_node_frame(clip,
					clip.motion_node_chain[0] as CombatAnimationMotionNode, 0.0)
				_finish()
			else:
				_chain_player.start()
				_baker._append_chain_player_frame(clip, _chain_player, 0.0)
		elif _elapsed_seconds + _sample_step < _total_duration - 0.0001:
			# Keep the original cumulative sample clock, including its addition
			# order, independent of where cooperative slices end.
			_elapsed_seconds += _sample_step
			_chain_player.advance(_sample_step)
			_baker._append_chain_player_frame(clip, _chain_player, _elapsed_seconds)
		else:
			if clip.baked_frame_times.is_empty() or absf(clip.baked_frame_times[clip.baked_frame_times.size() - 1] - _total_duration) > 0.0001:
				# The player clock can remain infinitesimally short of the last
				# segment. The known terminal time always uses exact node state.
				_baker._append_motion_node_frame(clip,
					clip.motion_node_chain.back() as CombatAnimationMotionNode, _total_duration)
			_finish()
		if budget_usec > 0 and Time.get_ticks_usec() - started_usec >= budget_usec:
			break
	_max_slice_ms = maxf(_max_slice_ms, float(Time.get_ticks_usec() - started_usec) / 1000.0)
	return _result()

func cancel() -> void:
	if done:
		return
	cancelled = true
	done = true
	_chain_player = null
	_baker = null

func _finish() -> void:
	clip.normalize()
	done = true
	_chain_player = null
	_baker = null

func _result() -> Dictionary:
	return {"done": done, "cancelled": cancelled,
		"sampled_frames": clip.get_frame_count(), "max_slice_ms": _max_slice_ms,
		"reason": "cancelled" if cancelled else ""}
