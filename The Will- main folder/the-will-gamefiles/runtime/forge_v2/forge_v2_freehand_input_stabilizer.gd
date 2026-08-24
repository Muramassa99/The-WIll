extends RefCounted
class_name ForgeV2FreehandInputStabilizer

const SMOOTHING_STEP_MIN := 0
const SMOOTHING_STEP_MAX := 10
const SAMPLE_CADENCE_HZ := 60
const SAMPLE_INTERVAL_USEC := 16_667
const MAX_UNIFORM_SAMPLES_PER_CALL := 120

var _active := false
var _smoothing_steps := 0
var _first_screen_position := Vector2.ZERO
var _last_raw_screen_position := Vector2.ZERO
var _last_raw_timestamp_usec := 0
var _next_uniform_timestamp_usec := 0

var _uniform_screen_positions := PackedVector2Array()
var _uniform_sample_base_index := 0
var _latest_uniform_sample_index := -1
var _next_center_sample_index := 1

var _has_last_emitted_position := false
var _last_emitted_screen_position := Vector2.ZERO

func reset() -> void:
	_active = false
	_smoothing_steps = 0
	_first_screen_position = Vector2.ZERO
	_last_raw_screen_position = Vector2.ZERO
	_last_raw_timestamp_usec = 0
	_next_uniform_timestamp_usec = 0
	_uniform_screen_positions = PackedVector2Array()
	_uniform_sample_base_index = 0
	_latest_uniform_sample_index = -1
	_next_center_sample_index = 1
	_has_last_emitted_position = false
	_last_emitted_screen_position = Vector2.ZERO

func begin(
	screen_position: Vector2,
	timestamp_usec: int,
	smoothing_steps: int
) -> PackedVector2Array:
	reset()
	_active = true
	_smoothing_steps = clampi(
		smoothing_steps,
		SMOOTHING_STEP_MIN,
		SMOOTHING_STEP_MAX
	)
	_first_screen_position = screen_position
	_last_raw_screen_position = screen_position
	_last_raw_timestamp_usec = maxi(timestamp_usec, 0)
	_next_uniform_timestamp_usec = (
		_last_raw_timestamp_usec
		+ SAMPLE_INTERVAL_USEC
	)

	var outputs := PackedVector2Array()
	if _smoothing_steps <= 0:
		_append_direct_output(outputs, screen_position)
		return outputs

	_uniform_screen_positions.append(screen_position)
	_latest_uniform_sample_index = 0
	_append_smoothed_output(outputs, screen_position)
	return outputs

func push(
	screen_position: Vector2,
	timestamp_usec: int
) -> PackedVector2Array:
	var outputs := PackedVector2Array()
	if not _active:
		return outputs
	var normalized_timestamp_usec := maxi(
		timestamp_usec,
		_last_raw_timestamp_usec
	)
	if _smoothing_steps <= 0:
		_last_raw_screen_position = screen_position
		_last_raw_timestamp_usec = normalized_timestamp_usec
		_append_direct_output(outputs, screen_position)
		return outputs

	_consume_raw_segment(
		screen_position,
		normalized_timestamp_usec,
		outputs
	)
	return outputs

func advance(timestamp_usec: int) -> PackedVector2Array:
	var outputs := PackedVector2Array()
	if not _active or _smoothing_steps <= 0:
		return outputs
	_consume_raw_segment(
		_last_raw_screen_position,
		maxi(timestamp_usec, _last_raw_timestamp_usec),
		outputs
	)
	return outputs

func release(
	screen_position: Vector2,
	timestamp_usec: int,
	final_sample_valid: bool = true
) -> PackedVector2Array:
	var outputs := PackedVector2Array()
	if not _active:
		return outputs
	var normalized_timestamp_usec := maxi(
		timestamp_usec,
		_last_raw_timestamp_usec
	)
	var final_screen_position := (
		screen_position
		if final_sample_valid
		else _last_raw_screen_position
	)

	if _smoothing_steps <= 0:
		_last_raw_screen_position = final_screen_position
		_last_raw_timestamp_usec = normalized_timestamp_usec
		_append_terminal_output(outputs, final_screen_position)
		reset()
		return outputs

	_consume_raw_segment(
		final_screen_position,
		normalized_timestamp_usec,
		outputs
	)
	_append_uniform_sample(final_screen_position, outputs)
	var terminal_sample_index := _latest_uniform_sample_index
	var final_center_sample_index := (
		terminal_sample_index
		+ _smoothing_steps
	)
	var required_latest_sample_index := (
		final_center_sample_index
		+ _smoothing_steps
	)
	while _latest_uniform_sample_index < required_latest_sample_index:
		_append_uniform_sample(final_screen_position, outputs)
	_append_terminal_output(outputs, final_screen_position)
	reset()
	return outputs

func is_active() -> bool:
	return _active

func get_smoothing_steps() -> int:
	return _smoothing_steps

func get_sample_cadence_hz() -> int:
	return SAMPLE_CADENCE_HZ

func get_sample_interval_usec() -> int:
	return SAMPLE_INTERVAL_USEC

func get_buffered_sample_count() -> int:
	return _uniform_screen_positions.size()

func get_max_buffered_sample_count() -> int:
	return (SMOOTHING_STEP_MAX * 2) + 1

func get_max_uniform_samples_per_call() -> int:
	return MAX_UNIFORM_SAMPLES_PER_CALL

func _consume_raw_segment(
	next_screen_position: Vector2,
	next_timestamp_usec: int,
	outputs: PackedVector2Array
) -> void:
	var segment_duration_usec := (
		next_timestamp_usec
		- _last_raw_timestamp_usec
	)
	var pending_uniform_sample_count := 0
	if _next_uniform_timestamp_usec <= next_timestamp_usec:
		pending_uniform_sample_count = (
			int(
				floor(
					float(
						next_timestamp_usec
						- _next_uniform_timestamp_usec
					) / float(SAMPLE_INTERVAL_USEC)
				)
			)
			+ 1
		)
	if pending_uniform_sample_count > MAX_UNIFORM_SAMPLES_PER_CALL:
		_next_uniform_timestamp_usec = (
			next_timestamp_usec
			- (MAX_UNIFORM_SAMPLES_PER_CALL - 1) * SAMPLE_INTERVAL_USEC
		)
	while _next_uniform_timestamp_usec <= next_timestamp_usec:
		var segment_ratio := 1.0
		if segment_duration_usec > 0:
			segment_ratio = clampf(
				float(
					_next_uniform_timestamp_usec
					- _last_raw_timestamp_usec
				) / float(segment_duration_usec),
				0.0,
				1.0
			)
		var uniform_screen_position := _last_raw_screen_position.lerp(
			next_screen_position,
			segment_ratio
		)
		_append_uniform_sample(uniform_screen_position, outputs)
		_next_uniform_timestamp_usec += SAMPLE_INTERVAL_USEC
	_last_raw_screen_position = next_screen_position
	_last_raw_timestamp_usec = next_timestamp_usec

func _append_uniform_sample(
	screen_position: Vector2,
	outputs: PackedVector2Array
) -> void:
	_uniform_screen_positions.append(screen_position)
	_latest_uniform_sample_index += 1
	_drain_ready_centers(outputs)

func _drain_ready_centers(outputs: PackedVector2Array) -> void:
	while (
		_next_center_sample_index + _smoothing_steps
		<= _latest_uniform_sample_index
	):
		_append_smoothed_output(
			outputs,
			_resolve_weighted_center(_next_center_sample_index)
		)
		_next_center_sample_index += 1
		_trim_uniform_buffer()

func _resolve_weighted_center(center_sample_index: int) -> Vector2:
	var weighted_screen_position := Vector2.ZERO
	var total_weight := 0.0
	for sample_offset in range(
		-_smoothing_steps,
		_smoothing_steps + 1
	):
		var sample_weight := float(
			_smoothing_steps
			+ 1
			- absi(sample_offset)
		)
		weighted_screen_position += (
			_resolve_uniform_sample(
				center_sample_index + sample_offset
			)
			* sample_weight
		)
		total_weight += sample_weight
	if total_weight <= 0.0:
		return _resolve_uniform_sample(center_sample_index)
	return weighted_screen_position / total_weight

func _resolve_uniform_sample(sample_index: int) -> Vector2:
	if sample_index < 0:
		return _first_screen_position
	var local_sample_index := (
		sample_index
		- _uniform_sample_base_index
	)
	if local_sample_index < 0:
		return _uniform_screen_positions[0]
	if local_sample_index >= _uniform_screen_positions.size():
		return _uniform_screen_positions[
			_uniform_screen_positions.size() - 1
		]
	return _uniform_screen_positions[local_sample_index]

func _trim_uniform_buffer() -> void:
	var first_required_sample_index := maxi(
		_next_center_sample_index - _smoothing_steps,
		0
	)
	while (
		_uniform_sample_base_index < first_required_sample_index
		and not _uniform_screen_positions.is_empty()
	):
		_uniform_screen_positions.remove_at(0)
		_uniform_sample_base_index += 1

func _append_direct_output(
	outputs: PackedVector2Array,
	screen_position: Vector2
) -> void:
	outputs.append(screen_position)
	_has_last_emitted_position = true
	_last_emitted_screen_position = screen_position

func _append_smoothed_output(
	outputs: PackedVector2Array,
	screen_position: Vector2
) -> void:
	if (
		_has_last_emitted_position
		and _last_emitted_screen_position == screen_position
	):
		return
	outputs.append(screen_position)
	_has_last_emitted_position = true
	_last_emitted_screen_position = screen_position

func _append_terminal_output(
	outputs: PackedVector2Array,
	screen_position: Vector2
) -> void:
	if (
		_has_last_emitted_position
		and _last_emitted_screen_position == screen_position
	):
		return
	outputs.append(screen_position)
	_has_last_emitted_position = true
	_last_emitted_screen_position = screen_position
