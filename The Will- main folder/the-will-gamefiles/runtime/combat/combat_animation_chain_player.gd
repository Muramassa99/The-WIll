extends RefCounted
class_name CombatAnimationChainPlayer

signal playback_finished
signal node_reached(node_index: int)

const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationTrajectoryVolumeResolverScript = preload("res://core/resolvers/combat_animation_trajectory_volume_resolver.gd")

const CURVE_INTERVAL_EPSILON_METERS := 0.000001

var tip_curve: Curve3D = null
var pommel_curve: Curve3D = null
var motion_node_chain: Array = []
var speed_scale: float = 1.0
var loop_enabled: bool = false
var trajectory_volume_config: Dictionary = {}
var trajectory_volume_resolver = CombatAnimationTrajectoryVolumeResolverScript.new()
var runtime_clip = null

var _playing: bool = false
var _uses_runtime_clip: bool = false
var _current_segment_index: int = 0
var _segment_elapsed: float = 0.0
var _segment_durations: Array[float] = []
var _segment_tip_offsets: Array[float] = []
var _segment_pommel_offsets: Array[float] = []
var _total_tip_length: float = 0.0
var _total_pommel_length: float = 0.0
var _clip_elapsed: float = 0.0
var _clip_frame_index: int = 0
var _clip_total_duration: float = 0.0

var current_tip_position: Vector3 = Vector3.ZERO
var current_pommel_position: Vector3 = Vector3.ZERO
var current_weapon_orientation_degrees: Vector3 = Vector3.ZERO
var current_weapon_roll: float = 0.0
var current_axial_reposition: float = 0.0
var current_grip_seat_slide: float = 0.0
var current_body_support_blend: float = 0.0
var current_right_upperarm_roll: float = 0.0
var current_left_upperarm_roll: float = 0.0
var current_two_hand_state: StringName = CombatAnimationMotionNodeScript.TWO_HAND_STATE_AUTO
var current_primary_hand_slot: StringName = CombatAnimationMotionNodeScript.PRIMARY_HAND_AUTO
var current_preferred_grip_style_mode: StringName = &"grip_normal"
var current_contact_grip_axis_local: Vector3 = Vector3.ZERO
var current_contact_grip_axis_local_override_active: bool = false
var current_trajectory_volume_state: Dictionary = {}

func is_playing() -> bool:
	return _playing

func prepare(
	chain: Array,
	tip: Curve3D,
	pommel: Curve3D,
	playback_speed: float = 1.0,
	should_loop: bool = false,
	valid_volume_config: Dictionary = {}
) -> void:
	motion_node_chain = chain
	tip_curve = tip
	pommel_curve = pommel
	speed_scale = maxf(playback_speed, 0.01)
	loop_enabled = should_loop
	trajectory_volume_config = valid_volume_config.duplicate(true)
	runtime_clip = null
	_uses_runtime_clip = false
	_build_segment_data()

func prepare_runtime_clip(clip, playback_speed: float = 1.0, should_loop: bool = false) -> void:
	runtime_clip = clip
	motion_node_chain = clip.motion_node_chain if clip != null else []
	tip_curve = null
	pommel_curve = null
	speed_scale = maxf(playback_speed, 0.01)
	loop_enabled = should_loop
	trajectory_volume_config = {}
	_uses_runtime_clip = clip != null and clip.has_method("get_frame_count") and int(clip.call("get_frame_count")) > 0
	_clip_elapsed = 0.0
	_clip_frame_index = 0
	_clip_total_duration = _resolve_runtime_clip_total_duration()

func set_trajectory_volume_config(valid_volume_config: Dictionary) -> void:
	trajectory_volume_config = valid_volume_config.duplicate(true)

func clear_trajectory_volume_config() -> void:
	trajectory_volume_config = {}

func start() -> void:
	if _uses_runtime_clip:
		if runtime_clip == null:
			return
		_playing = true
		_clip_elapsed = 0.0
		_clip_frame_index = 0
		_apply_runtime_clip_sample(0.0)
		node_reached.emit(0)
		return
	if motion_node_chain.size() < 2:
		return
	_playing = true
	_current_segment_index = 1
	_segment_elapsed = 0.0
	_apply_node_state(0)
	node_reached.emit(0)

func stop() -> void:
	_playing = false

func advance(delta: float) -> void:
	if _uses_runtime_clip:
		_advance_runtime_clip(delta)
		return
	if not _playing or motion_node_chain.size() < 2:
		return
	_segment_elapsed += delta * speed_scale
	var segment_duration: float = _segment_durations[_current_segment_index] if _current_segment_index < _segment_durations.size() else 0.18
	if segment_duration <= 0.00001:
		segment_duration = 0.01
	while _segment_elapsed >= segment_duration:
		_segment_elapsed -= segment_duration
		_apply_node_state(_current_segment_index)
		node_reached.emit(_current_segment_index)
		_current_segment_index += 1
		if _current_segment_index >= motion_node_chain.size():
			if loop_enabled:
				_current_segment_index = 1
				_segment_elapsed = 0.0
				_apply_node_state(0)
				node_reached.emit(0)
			else:
				_playing = false
				playback_finished.emit()
				return
		segment_duration = _segment_durations[_current_segment_index] if _current_segment_index < _segment_durations.size() else 0.18
		if segment_duration <= 0.00001:
			segment_duration = 0.01
	var ratio: float = clampf(_segment_elapsed / segment_duration, 0.0, 1.0)
	_interpolate_between_nodes(_current_segment_index - 1, _current_segment_index, ratio)

func _advance_runtime_clip(delta: float) -> void:
	if not _playing or runtime_clip == null:
		return
	if _clip_total_duration <= 0.000001:
		_apply_runtime_clip_sample(0.0)
		if not loop_enabled:
			_playing = false
			playback_finished.emit()
		return
	_clip_elapsed += delta * speed_scale
	while _clip_elapsed >= _clip_total_duration:
		if loop_enabled:
			_clip_elapsed -= _clip_total_duration
			_clip_frame_index = 0
			node_reached.emit(0)
		else:
			_clip_elapsed = _clip_total_duration
			_apply_runtime_clip_sample(_clip_elapsed)
			_playing = false
			playback_finished.emit()
			return
	_apply_runtime_clip_sample(_clip_elapsed)

func _resolve_runtime_clip_total_duration() -> float:
	if runtime_clip == null:
		return 0.0
	var duration: float = float(runtime_clip.get("total_duration_seconds"))
	if duration > 0.0:
		return duration
	var frame_times: PackedFloat32Array = runtime_clip.get("baked_frame_times") as PackedFloat32Array
	if not frame_times.is_empty():
		return maxf(float(frame_times[frame_times.size() - 1]), 0.0)
	return 0.0

func _apply_runtime_clip_sample(time_seconds: float) -> void:
	if runtime_clip == null:
		return
	var frame_times: PackedFloat32Array = runtime_clip.get("baked_frame_times") as PackedFloat32Array
	var frame_count: int = frame_times.size()
	if frame_count <= 0:
		return
	if frame_count == 1 or time_seconds <= frame_times[0]:
		_apply_runtime_clip_frame(0)
		return
	if time_seconds >= frame_times[frame_count - 1]:
		_apply_runtime_clip_frame(frame_count - 1)
		return
	_clip_frame_index = clampi(_clip_frame_index, 0, frame_count - 2)
	while _clip_frame_index < frame_count - 2 and time_seconds > frame_times[_clip_frame_index + 1]:
		_clip_frame_index += 1
	while _clip_frame_index > 0 and time_seconds < frame_times[_clip_frame_index]:
		_clip_frame_index -= 1
	var from_index: int = _clip_frame_index
	var to_index: int = mini(from_index + 1, frame_count - 1)
	var from_time: float = frame_times[from_index]
	var to_time: float = frame_times[to_index]
	var ratio: float = 0.0
	if to_time > from_time:
		ratio = clampf((time_seconds - from_time) / (to_time - from_time), 0.0, 1.0)
	_interpolate_runtime_clip_frames(from_index, to_index, ratio)

func _apply_runtime_clip_frame(frame_index: int) -> void:
	current_tip_position = _get_runtime_clip_vector3("baked_tip_positions_local", frame_index, current_tip_position)
	current_pommel_position = _get_runtime_clip_vector3("baked_pommel_positions_local", frame_index, current_pommel_position)
	current_weapon_orientation_degrees = _get_runtime_clip_vector3("baked_weapon_orientation_degrees", frame_index, current_weapon_orientation_degrees)
	current_weapon_roll = _get_runtime_clip_float("baked_weapon_roll_degrees", frame_index, current_weapon_roll)
	current_axial_reposition = _get_runtime_clip_float("baked_axial_reposition_offsets", frame_index, current_axial_reposition)
	current_grip_seat_slide = _get_runtime_clip_float("baked_grip_seat_slide_offsets", frame_index, current_grip_seat_slide)
	current_body_support_blend = _get_runtime_clip_float("baked_body_support_blends", frame_index, current_body_support_blend)
	current_right_upperarm_roll = _get_runtime_clip_float("baked_right_upperarm_roll_degrees", frame_index, current_right_upperarm_roll)
	current_left_upperarm_roll = _get_runtime_clip_float("baked_left_upperarm_roll_degrees", frame_index, current_left_upperarm_roll)
	current_contact_grip_axis_local = _get_runtime_clip_vector3("baked_contact_grip_axes_local", frame_index, current_contact_grip_axis_local)
	current_contact_grip_axis_local_override_active = _get_runtime_clip_bool("baked_contact_axis_override_active", frame_index, false)
	current_two_hand_state = _get_runtime_clip_string_name("baked_two_hand_states", frame_index, current_two_hand_state)
	current_primary_hand_slot = _get_runtime_clip_string_name("baked_primary_hand_slots", frame_index, current_primary_hand_slot)
	current_preferred_grip_style_mode = _get_runtime_clip_string_name("baked_grip_style_modes", frame_index, current_preferred_grip_style_mode)
	current_trajectory_volume_state = {"source": &"baked_runtime_clip"}

func _interpolate_runtime_clip_frames(from_index: int, to_index: int, ratio: float) -> void:
	var clean_ratio: float = clampf(ratio, 0.0, 1.0)
	current_tip_position = _get_runtime_clip_vector3("baked_tip_positions_local", from_index, current_tip_position).lerp(
		_get_runtime_clip_vector3("baked_tip_positions_local", to_index, current_tip_position),
		clean_ratio
	)
	current_pommel_position = _get_runtime_clip_vector3("baked_pommel_positions_local", from_index, current_pommel_position).lerp(
		_get_runtime_clip_vector3("baked_pommel_positions_local", to_index, current_pommel_position),
		clean_ratio
	)
	_apply_runtime_clip_length_lock(from_index, to_index, clean_ratio)
	current_weapon_orientation_degrees = _get_runtime_clip_vector3("baked_weapon_orientation_degrees", from_index, current_weapon_orientation_degrees).lerp(
		_get_runtime_clip_vector3("baked_weapon_orientation_degrees", to_index, current_weapon_orientation_degrees),
		clean_ratio
	)
	current_weapon_roll = lerpf(
		_get_runtime_clip_float("baked_weapon_roll_degrees", from_index, current_weapon_roll),
		_get_runtime_clip_float("baked_weapon_roll_degrees", to_index, current_weapon_roll),
		clean_ratio
	)
	current_axial_reposition = lerpf(
		_get_runtime_clip_float("baked_axial_reposition_offsets", from_index, current_axial_reposition),
		_get_runtime_clip_float("baked_axial_reposition_offsets", to_index, current_axial_reposition),
		clean_ratio
	)
	current_grip_seat_slide = lerpf(
		_get_runtime_clip_float("baked_grip_seat_slide_offsets", from_index, current_grip_seat_slide),
		_get_runtime_clip_float("baked_grip_seat_slide_offsets", to_index, current_grip_seat_slide),
		clean_ratio
	)
	current_body_support_blend = lerpf(
		_get_runtime_clip_float("baked_body_support_blends", from_index, current_body_support_blend),
		_get_runtime_clip_float("baked_body_support_blends", to_index, current_body_support_blend),
		clean_ratio
	)
	current_right_upperarm_roll = lerpf(
		_get_runtime_clip_float("baked_right_upperarm_roll_degrees", from_index, current_right_upperarm_roll),
		_get_runtime_clip_float("baked_right_upperarm_roll_degrees", to_index, current_right_upperarm_roll),
		clean_ratio
	)
	current_left_upperarm_roll = lerpf(
		_get_runtime_clip_float("baked_left_upperarm_roll_degrees", from_index, current_left_upperarm_roll),
		_get_runtime_clip_float("baked_left_upperarm_roll_degrees", to_index, current_left_upperarm_roll),
		clean_ratio
	)
	current_contact_grip_axis_local = _get_runtime_clip_vector3("baked_contact_grip_axes_local", from_index, current_contact_grip_axis_local).lerp(
		_get_runtime_clip_vector3("baked_contact_grip_axes_local", to_index, current_contact_grip_axis_local),
		clean_ratio
	)
	current_contact_grip_axis_local_override_active = (
		_get_runtime_clip_bool("baked_contact_axis_override_active", from_index, false)
		if clean_ratio < 0.5
		else _get_runtime_clip_bool("baked_contact_axis_override_active", to_index, false)
	)
	current_two_hand_state = (
		_get_runtime_clip_string_name("baked_two_hand_states", from_index, current_two_hand_state)
		if clean_ratio < 0.5
		else _get_runtime_clip_string_name("baked_two_hand_states", to_index, current_two_hand_state)
	)
	current_primary_hand_slot = (
		_get_runtime_clip_string_name("baked_primary_hand_slots", from_index, current_primary_hand_slot)
		if clean_ratio < 0.5
		else _get_runtime_clip_string_name("baked_primary_hand_slots", to_index, current_primary_hand_slot)
	)
	current_preferred_grip_style_mode = (
		_get_runtime_clip_string_name("baked_grip_style_modes", from_index, current_preferred_grip_style_mode)
		if clean_ratio < 0.5
		else _get_runtime_clip_string_name("baked_grip_style_modes", to_index, current_preferred_grip_style_mode)
	)
	current_trajectory_volume_state = {"source": &"baked_runtime_clip"}

func _apply_runtime_clip_length_lock(from_index: int, to_index: int, ratio: float) -> void:
	var from_tip: Vector3 = _get_runtime_clip_vector3("baked_tip_positions_local", from_index, current_tip_position)
	var from_pommel: Vector3 = _get_runtime_clip_vector3("baked_pommel_positions_local", from_index, current_pommel_position)
	var to_tip: Vector3 = _get_runtime_clip_vector3("baked_tip_positions_local", to_index, current_tip_position)
	var to_pommel: Vector3 = _get_runtime_clip_vector3("baked_pommel_positions_local", to_index, current_pommel_position)
	var from_length: float = from_tip.distance_to(from_pommel)
	var to_length: float = to_tip.distance_to(to_pommel)
	var target_length: float = lerpf(from_length, to_length, clampf(ratio, 0.0, 1.0))
	if target_length <= 0.000001:
		return
	var axis: Vector3 = current_tip_position - current_pommel_position
	if axis.length_squared() <= 0.000001:
		axis = (to_tip - to_pommel) + (from_tip - from_pommel)
	if axis.length_squared() <= 0.000001:
		return
	var center: Vector3 = current_pommel_position.lerp(current_tip_position, 0.5)
	axis = axis.normalized()
	current_tip_position = center + axis * target_length * 0.5
	current_pommel_position = center - axis * target_length * 0.5

func _get_runtime_clip_vector3(property_name: StringName, frame_index: int, fallback: Vector3) -> Vector3:
	if runtime_clip == null:
		return fallback
	var values: PackedVector3Array = runtime_clip.get(property_name) as PackedVector3Array
	if frame_index < 0 or frame_index >= values.size():
		return fallback
	return values[frame_index]

func _get_runtime_clip_float(property_name: StringName, frame_index: int, fallback: float) -> float:
	if runtime_clip == null:
		return fallback
	var values: PackedFloat32Array = runtime_clip.get(property_name) as PackedFloat32Array
	if frame_index < 0 or frame_index >= values.size():
		return fallback
	return float(values[frame_index])

func _get_runtime_clip_bool(property_name: StringName, frame_index: int, fallback: bool) -> bool:
	if runtime_clip == null:
		return fallback
	var values: Array = runtime_clip.get(property_name) as Array
	if frame_index < 0 or frame_index >= values.size():
		return fallback
	return bool(values[frame_index])

func _get_runtime_clip_string_name(property_name: StringName, frame_index: int, fallback: StringName) -> StringName:
	if runtime_clip == null:
		return fallback
	var values: Array = runtime_clip.get(property_name) as Array
	if frame_index < 0 or frame_index >= values.size():
		return fallback
	return StringName(values[frame_index])

func _build_segment_data() -> void:
	_segment_durations.clear()
	_segment_tip_offsets.clear()
	_segment_pommel_offsets.clear()
	_total_tip_length = _resolve_safe_curve_baked_length(tip_curve)
	_total_pommel_length = _resolve_safe_curve_baked_length(pommel_curve)
	for node_index: int in range(motion_node_chain.size()):
		var motion_node: CombatAnimationMotionNode = motion_node_chain[node_index] as CombatAnimationMotionNode
		var duration: float = motion_node.transition_duration_seconds if motion_node != null else 0.18
		_segment_durations.append(maxf(duration, 0.01))
		if tip_curve != null and tip_curve.point_count > node_index:
			var tip_offset_fallback: float = _segment_tip_offsets[_segment_tip_offsets.size() - 1] if not _segment_tip_offsets.is_empty() else 0.0
			_segment_tip_offsets.append(_resolve_curve_point_offset(tip_curve, node_index, tip_offset_fallback, _total_tip_length))
		else:
			_segment_tip_offsets.append(0.0)
		if pommel_curve != null and pommel_curve.point_count > node_index:
			var pommel_offset_fallback: float = _segment_pommel_offsets[_segment_pommel_offsets.size() - 1] if not _segment_pommel_offsets.is_empty() else 0.0
			_segment_pommel_offsets.append(_resolve_curve_point_offset(pommel_curve, node_index, pommel_offset_fallback, _total_pommel_length))
		else:
			_segment_pommel_offsets.append(0.0)

func _apply_node_state(node_index: int) -> void:
	if node_index < 0 or node_index >= motion_node_chain.size():
		return
	var motion_node: CombatAnimationMotionNode = motion_node_chain[node_index] as CombatAnimationMotionNode
	if motion_node == null:
		return
	current_tip_position = motion_node.tip_position_local
	current_pommel_position = motion_node.pommel_position_local
	current_weapon_orientation_degrees = _resolve_effective_weapon_orientation_degrees(motion_node)
	current_weapon_roll = motion_node.weapon_roll_degrees
	current_axial_reposition = motion_node.axial_reposition_offset
	current_grip_seat_slide = motion_node.grip_seat_slide_offset
	current_body_support_blend = motion_node.body_support_blend
	current_right_upperarm_roll = motion_node.right_upperarm_roll_degrees
	current_left_upperarm_roll = motion_node.left_upperarm_roll_degrees
	current_two_hand_state = motion_node.two_hand_state
	current_primary_hand_slot = motion_node.primary_hand_slot
	current_preferred_grip_style_mode = motion_node.preferred_grip_style_mode
	current_contact_grip_axis_local = _resolve_motion_node_contact_axis(motion_node)
	current_contact_grip_axis_local_override_active = false
	current_trajectory_volume_state = {}

func _interpolate_between_nodes(from_index: int, to_index: int, ratio: float) -> void:
	var from_node: CombatAnimationMotionNode = motion_node_chain[from_index] as CombatAnimationMotionNode if from_index < motion_node_chain.size() else null
	var to_node: CombatAnimationMotionNode = motion_node_chain[to_index] as CombatAnimationMotionNode if to_index < motion_node_chain.size() else null
	if from_node == null or to_node == null:
		return
	var sampled_tip_position: Vector3 = _sample_curve_segment_position(
		tip_curve,
		_total_tip_length,
		_segment_tip_offsets,
		from_index,
		to_index,
		ratio,
		from_node.tip_position_local,
		to_node.tip_position_local
	)
	var sampled_pommel_position: Vector3 = _sample_curve_segment_position(
		pommel_curve,
		_total_pommel_length,
		_segment_pommel_offsets,
		from_index,
		to_index,
		ratio,
		from_node.pommel_position_local,
		to_node.pommel_position_local
	)
	var resolved_segment: Dictionary = _resolve_rigid_segment_sample(
		from_node,
		to_node,
		ratio,
		sampled_tip_position,
		sampled_pommel_position
	)
	current_tip_position = resolved_segment.get("tip_position", sampled_tip_position) as Vector3
	current_pommel_position = resolved_segment.get("pommel_position", sampled_pommel_position) as Vector3
	_apply_trajectory_volume_to_current_segment(from_node, to_node)
	current_weapon_orientation_degrees = _resolve_effective_weapon_orientation_degrees(from_node).lerp(
		_resolve_effective_weapon_orientation_degrees(to_node),
		ratio
	)
	current_weapon_roll = lerpf(from_node.weapon_roll_degrees, to_node.weapon_roll_degrees, ratio)
	current_axial_reposition = lerpf(from_node.axial_reposition_offset, to_node.axial_reposition_offset, ratio)
	current_grip_seat_slide = lerpf(from_node.grip_seat_slide_offset, to_node.grip_seat_slide_offset, ratio)
	current_body_support_blend = lerpf(from_node.body_support_blend, to_node.body_support_blend, ratio)
	current_right_upperarm_roll = lerpf(from_node.right_upperarm_roll_degrees, to_node.right_upperarm_roll_degrees, ratio)
	current_left_upperarm_roll = lerpf(from_node.left_upperarm_roll_degrees, to_node.left_upperarm_roll_degrees, ratio)
	current_two_hand_state = from_node.two_hand_state if ratio < 0.5 else to_node.two_hand_state
	current_primary_hand_slot = from_node.primary_hand_slot if ratio < 0.5 else to_node.primary_hand_slot
	if _is_grip_style_swap_segment(from_node, to_node):
		current_preferred_grip_style_mode = from_node.preferred_grip_style_mode
		current_contact_grip_axis_local = _resolve_grip_swap_source_contact_axis(from_node, to_node)
		current_contact_grip_axis_local_override_active = true
	else:
		current_preferred_grip_style_mode = from_node.preferred_grip_style_mode if ratio < 0.5 else to_node.preferred_grip_style_mode
		current_contact_grip_axis_local = _resolve_axis_between_positions(current_pommel_position, current_tip_position)
		current_contact_grip_axis_local_override_active = false

func _resolve_curve_point_offset(curve: Curve3D, node_index: int, fallback_offset: float, total_length: float) -> float:
	if curve == null or node_index < 0 or node_index >= curve.point_count:
		return _sanitize_curve_offset(fallback_offset, 0.0, total_length)
	if total_length <= CURVE_INTERVAL_EPSILON_METERS:
		return 0.0
	var point_position: Vector3 = curve.get_point_position(node_index)
	if not _is_finite_vector3(point_position):
		return _sanitize_curve_offset(fallback_offset, 0.0, total_length)
	return _sanitize_curve_offset(curve.get_closest_offset(point_position), fallback_offset, total_length)

func _resolve_safe_curve_baked_length(curve: Curve3D) -> float:
	if curve == null or curve.point_count < 2:
		return 0.0
	if not _curve_has_non_zero_interval(curve):
		return 0.0
	return _sanitize_curve_length(curve.get_baked_length())

func _curve_has_non_zero_interval(curve: Curve3D) -> bool:
	if curve == null or curve.point_count < 2:
		return false
	var previous_point: Vector3 = curve.get_point_position(0)
	for point_index: int in range(1, curve.point_count):
		var current_point: Vector3 = curve.get_point_position(point_index)
		if (
			_is_finite_vector3(previous_point)
			and _is_finite_vector3(current_point)
			and previous_point.distance_squared_to(current_point) > CURVE_INTERVAL_EPSILON_METERS * CURVE_INTERVAL_EPSILON_METERS
		):
			return true
		previous_point = current_point
	return false

func _sample_curve_segment_position(
	curve: Curve3D,
	total_length: float,
	segment_offsets: Array[float],
	from_index: int,
	to_index: int,
	ratio: float,
	from_position: Vector3,
	to_position: Vector3
) -> Vector3:
	var clean_ratio: float = clampf(ratio, 0.0, 1.0)
	var fallback_position: Vector3 = from_position.lerp(to_position, clean_ratio)
	if curve == null or total_length <= 0.00001:
		return fallback_position
	var from_offset_raw: float = segment_offsets[from_index] if from_index >= 0 and from_index < segment_offsets.size() else 0.0
	var from_offset: float = _sanitize_curve_offset(from_offset_raw, 0.0, total_length)
	var to_offset_raw: float = segment_offsets[to_index] if to_index >= 0 and to_index < segment_offsets.size() else from_offset
	var to_offset: float = _sanitize_curve_offset(to_offset_raw, from_offset, total_length)
	var current_offset: float = _sanitize_curve_offset(lerpf(from_offset, to_offset, clean_ratio), from_offset, total_length)
	return _sample_baked_polyline_position(curve, current_offset, fallback_position)

func _sample_baked_polyline_position(curve: Curve3D, offset: float, fallback_position: Vector3) -> Vector3:
	var baked_points: PackedVector3Array = curve.get_baked_points()
	if baked_points.is_empty():
		return fallback_position
	var previous_point: Vector3 = baked_points[0]
	if not _is_finite_vector3(previous_point):
		return fallback_position
	if baked_points.size() == 1 or offset <= 0.0:
		return previous_point
	var walked_length: float = 0.0
	for point_index: int in range(1, baked_points.size()):
		var current_point: Vector3 = baked_points[point_index]
		if not _is_finite_vector3(current_point):
			continue
		var interval_length: float = previous_point.distance_to(current_point)
		if interval_length <= 0.000001:
			previous_point = current_point
			continue
		var next_walked_length: float = walked_length + interval_length
		if next_walked_length >= offset:
			var interval_ratio: float = clampf((offset - walked_length) / interval_length, 0.0, 1.0)
			return previous_point.lerp(current_point, interval_ratio)
		walked_length = next_walked_length
		previous_point = current_point
	return previous_point

func _sanitize_curve_length(length: float) -> float:
	return length if _is_finite_float(length) and length > 0.0 else 0.0

func _sanitize_curve_offset(offset: float, fallback_offset: float, total_length: float) -> float:
	var clean_total_length: float = total_length if _is_finite_float(total_length) and total_length > 0.0 else 0.0
	var clean_offset: float = offset if _is_finite_float(offset) else fallback_offset
	if not _is_finite_float(clean_offset):
		clean_offset = 0.0
	return clampf(clean_offset, 0.0, clean_total_length)

func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)

func _is_finite_vector3(value: Vector3) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y) and _is_finite_float(value.z)

func _resolve_rigid_segment_sample(
	from_node: CombatAnimationMotionNode,
	to_node: CombatAnimationMotionNode,
	ratio: float,
	sampled_tip_position: Vector3,
	sampled_pommel_position: Vector3
) -> Dictionary:
	var target_length: float = _resolve_segment_weapon_length(from_node, to_node, ratio)
	if target_length <= 0.00001:
		return {
			"tip_position": sampled_tip_position,
			"pommel_position": sampled_pommel_position,
		}
	if _is_grip_style_swap_segment(from_node, to_node):
		return _resolve_fixed_pivot_grip_swap_sample(from_node, to_node, sampled_tip_position, sampled_pommel_position, target_length)
	return _resolve_length_locked_segment_sample(from_node, to_node, sampled_tip_position, sampled_pommel_position, target_length)

func _resolve_segment_weapon_length(from_node: CombatAnimationMotionNode, to_node: CombatAnimationMotionNode, ratio: float) -> float:
	var from_length: float = from_node.tip_position_local.distance_to(from_node.pommel_position_local) if from_node != null else 0.0
	var to_length: float = to_node.tip_position_local.distance_to(to_node.pommel_position_local) if to_node != null else 0.0
	if from_length > 0.00001 and to_length > 0.00001:
		return lerpf(from_length, to_length, clampf(ratio, 0.0, 1.0))
	return maxf(from_length, to_length)

func _is_grip_style_swap_segment(from_node: CombatAnimationMotionNode, to_node: CombatAnimationMotionNode) -> bool:
	return (
		from_node != null
		and to_node != null
		and bool(to_node.generated_transition_node)
		and to_node.generated_transition_kind == CombatAnimationMotionNodeScript.TRANSITION_KIND_GRIP_STYLE_SWAP
		and from_node.preferred_grip_style_mode != to_node.preferred_grip_style_mode
	)

func _resolve_fixed_pivot_grip_swap_sample(
	from_node: CombatAnimationMotionNode,
	to_node: CombatAnimationMotionNode,
	sampled_tip_position: Vector3,
	sampled_pommel_position: Vector3,
	target_length: float
) -> Dictionary:
	var fixed_pivot: Vector3 = _resolve_grip_swap_fixed_pivot(from_node, to_node)
	var pivot_ratio_from_pommel: float = _resolve_pivot_ratio_from_pommel(from_node, fixed_pivot)
	var sampled_axis: Vector3 = _resolve_sample_axis(from_node, to_node, sampled_tip_position, sampled_pommel_position)
	return {
		"tip_position": fixed_pivot + sampled_axis * target_length * (1.0 - pivot_ratio_from_pommel),
		"pommel_position": fixed_pivot - sampled_axis * target_length * pivot_ratio_from_pommel,
	}

func _resolve_length_locked_segment_sample(
	from_node: CombatAnimationMotionNode,
	to_node: CombatAnimationMotionNode,
	sampled_tip_position: Vector3,
	sampled_pommel_position: Vector3,
	target_length: float
) -> Dictionary:
	var sampled_axis: Vector3 = _resolve_sample_axis(from_node, to_node, sampled_tip_position, sampled_pommel_position)
	var center_position: Vector3 = sampled_pommel_position.lerp(sampled_tip_position, 0.5)
	return {
		"tip_position": center_position + sampled_axis * target_length * 0.5,
		"pommel_position": center_position - sampled_axis * target_length * 0.5,
	}

func _resolve_sample_axis(
	from_node: CombatAnimationMotionNode,
	to_node: CombatAnimationMotionNode,
	sampled_tip_position: Vector3,
	sampled_pommel_position: Vector3
) -> Vector3:
	var sampled_axis: Vector3 = sampled_tip_position - sampled_pommel_position
	if sampled_axis.length_squared() > 0.000001:
		return sampled_axis.normalized()
	var fallback_axis: Vector3 = Vector3.ZERO
	if from_node != null:
		fallback_axis += from_node.tip_position_local - from_node.pommel_position_local
	if to_node != null:
		fallback_axis += to_node.tip_position_local - to_node.pommel_position_local
	if fallback_axis.length_squared() > 0.000001:
		return fallback_axis.normalized()
	return Vector3.FORWARD

func _resolve_grip_swap_fixed_pivot(from_node: CombatAnimationMotionNode, to_node: CombatAnimationMotionNode) -> Vector3:
	var tip_midpoint: Vector3 = from_node.tip_position_local.lerp(to_node.tip_position_local, 0.5)
	var pommel_midpoint: Vector3 = from_node.pommel_position_local.lerp(to_node.pommel_position_local, 0.5)
	return tip_midpoint.lerp(pommel_midpoint, 0.5)

func _resolve_pivot_ratio_from_pommel(motion_node: CombatAnimationMotionNode, pivot_position: Vector3) -> float:
	if motion_node == null:
		return 0.5
	var segment_axis: Vector3 = motion_node.tip_position_local - motion_node.pommel_position_local
	var segment_length_squared: float = segment_axis.length_squared()
	if segment_length_squared <= 0.000001:
		return 0.5
	return clampf((pivot_position - motion_node.pommel_position_local).dot(segment_axis) / segment_length_squared, 0.0, 1.0)

func _resolve_grip_swap_source_contact_axis(from_node: CombatAnimationMotionNode, to_node: CombatAnimationMotionNode) -> Vector3:
	if from_node == null:
		return Vector3.ZERO
	var fixed_pivot: Vector3 = _resolve_grip_swap_fixed_pivot(from_node, to_node) if to_node != null else from_node.pommel_position_local
	return _resolve_axis_between_positions(fixed_pivot, from_node.tip_position_local)

func _resolve_motion_node_contact_axis(motion_node: CombatAnimationMotionNode) -> Vector3:
	if motion_node == null:
		return Vector3.ZERO
	return _resolve_axis_between_positions(motion_node.pommel_position_local, motion_node.tip_position_local)

func _resolve_axis_between_positions(from_position: Vector3, to_position: Vector3) -> Vector3:
	var axis: Vector3 = to_position - from_position
	if axis.length_squared() <= 0.000001:
		return Vector3.ZERO
	return axis.normalized()

func _apply_trajectory_volume_to_current_segment(from_node: CombatAnimationMotionNode, to_node: CombatAnimationMotionNode) -> void:
	current_trajectory_volume_state = {}
	if trajectory_volume_resolver == null or trajectory_volume_config.is_empty():
		return
	if not bool(trajectory_volume_config.get("enabled", false)):
		return
	var resolved_config: Dictionary = trajectory_volume_config.duplicate(true)
	if _is_grip_style_swap_segment(from_node, to_node):
		var fixed_pivot: Vector3 = _resolve_grip_swap_fixed_pivot(from_node, to_node)
		resolved_config["pivot_ratio_from_pommel"] = _resolve_pivot_ratio_from_pommel(from_node, fixed_pivot)
	var volume_result: Dictionary = trajectory_volume_resolver.project_segment_to_valid_volume(
		current_tip_position,
		current_pommel_position,
		resolved_config
	)
	current_tip_position = volume_result.get("tip_position", current_tip_position) as Vector3
	current_pommel_position = volume_result.get("pommel_position", current_pommel_position) as Vector3
	current_trajectory_volume_state = volume_result

func _resolve_effective_weapon_orientation_degrees(motion_node: CombatAnimationMotionNode) -> Vector3:
	if motion_node == null:
		return Vector3.ZERO
	if motion_node.weapon_orientation_authored:
		return motion_node.weapon_orientation_degrees
	if not motion_node.weapon_orientation_degrees.is_zero_approx():
		return motion_node.weapon_orientation_degrees
	return Vector3.ZERO
