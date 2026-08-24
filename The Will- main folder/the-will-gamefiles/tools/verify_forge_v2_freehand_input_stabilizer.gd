extends SceneTree

const ForgeV2FreehandInputStabilizerScript = preload(
	"res://runtime/forge_v2/forge_v2_freehand_input_stabilizer.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_freehand_input_stabilizer_2026-08-10.txt"
)
const EPSILON := 0.00001

var result_lines := PackedStringArray()

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())

	var direct_error := _verify_direct_mode()
	if not direct_error.is_empty():
		_fail(direct_error)
		return

	var cadence_error := _verify_fixed_cadence_delay()
	if not cadence_error.is_empty():
		_fail(cadence_error)
		return

	var stationary_error := _verify_stationary_advance()
	if not stationary_error.is_empty():
		_fail(stationary_error)
		return

	var frequency_error := _verify_raw_frequency_independence()
	if not frequency_error.is_empty():
		_fail(frequency_error)
		return

	var smoothing_error := _verify_jitter_reduction()
	if not smoothing_error.is_empty():
		_fail(smoothing_error)
		return

	var release_error := _verify_release_contract()
	if not release_error.is_empty():
		_fail(release_error)
		return

	var invalid_release_error := _verify_invalid_release_contract()
	if not invalid_release_error.is_empty():
		_fail(invalid_release_error)
		return

	var memory_error := _verify_bounded_memory_and_reset()
	if not memory_error.is_empty():
		_fail(memory_error)
		return

	var catch_up_bound_error := _verify_pathological_catch_up_bound()
	if not catch_up_bound_error.is_empty():
		_fail(catch_up_bound_error)
		return

	result_lines.append("ok=true")
	result_lines.append("direct_mode=true")
	result_lines.append("fixed_cadence_delay=true")
	result_lines.append("stationary_cursor_catch_up=true")
	result_lines.append("raw_frequency_independent=true")
	result_lines.append("weighted_jitter_reduction=true")
	result_lines.append("release_drain_exact_endpoint=true")
	result_lines.append("invalid_release_uses_last_valid=true")
	result_lines.append("bounded_memory=true")
	result_lines.append("bounded_pathological_catch_up=true")
	result_lines.append("reset_contract=true")
	_write_results()
	quit(0)

func _verify_direct_mode() -> String:
	var stabilizer = ForgeV2FreehandInputStabilizerScript.new()
	var output := PackedVector2Array()
	output.append_array(stabilizer.call(
		"begin",
		Vector2(1.0, 2.0),
		100,
		0
	) as PackedVector2Array)
	output.append_array(stabilizer.call(
		"push",
		Vector2(3.0, 4.0),
		200
	) as PackedVector2Array)
	output.append_array(stabilizer.call(
		"release",
		Vector2(5.0, 6.0),
		300,
		true
	) as PackedVector2Array)
	var expected := PackedVector2Array([
		Vector2(1.0, 2.0),
		Vector2(3.0, 4.0),
		Vector2(5.0, 6.0),
	])
	if not _arrays_match(output, expected):
		return "smoothness zero did not pass raw samples through directly"
	if stabilizer.call("is_active"):
		return "direct stabilizer remained active after release"
	return ""

func _verify_fixed_cadence_delay() -> String:
	var stabilizer = ForgeV2FreehandInputStabilizerScript.new()
	var interval_usec := int(stabilizer.call("get_sample_interval_usec"))
	var begin_output: PackedVector2Array = stabilizer.call(
		"begin",
		Vector2.ZERO,
		0,
		3
	) as PackedVector2Array
	if begin_output != PackedVector2Array([Vector2.ZERO]):
		return "smoothed mode did not preserve the exact initial sample"
	var delayed_output: PackedVector2Array = stabilizer.call(
		"push",
		Vector2(3.0, 0.0),
		interval_usec * 3
	) as PackedVector2Array
	if not delayed_output.is_empty():
		return "smoothed output escaped before its three-tick lookahead"
	var ready_output: PackedVector2Array = stabilizer.call(
		"push",
		Vector2(4.0, 0.0),
		interval_usec * 4
	) as PackedVector2Array
	if ready_output.size() != 1:
		return "fixed cadence did not release the first delayed center on time"
	if ready_output[0].x <= 0.0 or ready_output[0].x >= 4.0:
		return "weighted delayed center escaped its source window"
	return ""

func _verify_stationary_advance() -> String:
	var stabilizer = ForgeV2FreehandInputStabilizerScript.new()
	var interval_usec := int(stabilizer.call("get_sample_interval_usec"))
	stabilizer.call("begin", Vector2.ZERO, 0, 3)
	var delayed_output: PackedVector2Array = stabilizer.call(
		"push",
		Vector2(3.0, 0.0),
		interval_usec * 3
	) as PackedVector2Array
	if not delayed_output.is_empty():
		return "stationary advance setup escaped before lookahead"
	var catch_up_output: PackedVector2Array = stabilizer.call(
		"advance",
		interval_usec * 4
	) as PackedVector2Array
	if catch_up_output.size() != 1:
		return "stationary cursor did not release its ready delayed center"
	if not (stabilizer.call(
		"advance",
		interval_usec * 4
	) as PackedVector2Array).is_empty():
		return "same-timestamp advance emitted a duplicate center"
	return ""

func _verify_raw_frequency_independence() -> String:
	var coarse_output := _run_linear_trace(0)
	var frequent_output := _run_linear_trace(7)
	if not _arrays_match(coarse_output, frequent_output, 0.0001):
		return "fixed-cadence output changed with collinear raw event frequency"
	var repeated_output := _run_linear_trace(7)
	if not _arrays_match(frequent_output, repeated_output):
		return "identical timestamped input did not produce deterministic output"
	return ""

func _run_linear_trace(raw_push_interval_ticks: int) -> PackedVector2Array:
	var stabilizer = ForgeV2FreehandInputStabilizerScript.new()
	var sample_interval_usec := int(stabilizer.call(
		"get_sample_interval_usec"
	))
	var final_tick := 120
	var output := PackedVector2Array()
	output.append_array(stabilizer.call(
		"begin",
		_linear_trace_position(0),
		0,
		4
	) as PackedVector2Array)
	if raw_push_interval_ticks > 0:
		var push_tick := raw_push_interval_ticks
		while push_tick < final_tick:
			output.append_array(stabilizer.call(
				"push",
				_linear_trace_position(push_tick),
				push_tick * sample_interval_usec
			) as PackedVector2Array)
			push_tick += raw_push_interval_ticks
	output.append_array(stabilizer.call(
		"release",
		_linear_trace_position(final_tick),
		final_tick * sample_interval_usec,
		true
	) as PackedVector2Array)
	return output

func _linear_trace_position(sample_tick: int) -> Vector2:
	return Vector2(
		float(sample_tick) * 0.75,
		float(sample_tick) * -0.25
	)

func _verify_jitter_reduction() -> String:
	var stabilizer = ForgeV2FreehandInputStabilizerScript.new()
	var sample_interval_usec := int(stabilizer.call(
		"get_sample_interval_usec"
	))
	var output := PackedVector2Array()
	output.append_array(stabilizer.call(
		"begin",
		Vector2.ZERO,
		0,
		5
	) as PackedVector2Array)
	for sample_tick in range(1, 121):
		var jitter_y := 6.0 if sample_tick % 2 == 0 else -6.0
		output.append_array(stabilizer.call(
			"push",
			Vector2(float(sample_tick), jitter_y),
			sample_tick * sample_interval_usec
		) as PackedVector2Array)
	var final_position := Vector2(121.0, 0.0)
	output.append_array(stabilizer.call(
		"release",
		final_position,
		121 * sample_interval_usec,
		true
	) as PackedVector2Array)
	if output.size() < 40:
		return "jitter trace produced too few stabilized samples"
	var interior_absolute_y_sum := 0.0
	var interior_count := 0
	for sample_index in range(10, output.size() - 10):
		interior_absolute_y_sum += absf(output[sample_index].y)
		interior_count += 1
	if interior_count <= 0:
		return "jitter trace had no stable interior sample window"
	var average_absolute_y := interior_absolute_y_sum / float(interior_count)
	if average_absolute_y >= 2.0:
		return "weighted smoothing did not materially reduce alternating jitter"
	for sample_index in range(1, output.size()):
		if output[sample_index].x + EPSILON < output[sample_index - 1].x:
			return "stabilized output order moved backward along a monotonic trace"
	return ""

func _verify_release_contract() -> String:
	var stabilizer = ForgeV2FreehandInputStabilizerScript.new()
	var sample_interval_usec := int(stabilizer.call(
		"get_sample_interval_usec"
	))
	var final_position := Vector2(999.25, -88.5)
	var output := PackedVector2Array()
	output.append_array(stabilizer.call(
		"begin",
		Vector2.ZERO,
		0,
		10
	) as PackedVector2Array)
	for sample_tick in range(1, 31):
		output.append_array(stabilizer.call(
			"push",
			Vector2(float(sample_tick), float(sample_tick) * 0.2),
			sample_tick * sample_interval_usec
		) as PackedVector2Array)
	output.append_array(stabilizer.call(
		"release",
		final_position,
		31 * sample_interval_usec,
		true
	) as PackedVector2Array)
	if output.is_empty() or output[output.size() - 1] != final_position:
		return "release did not end on the exact final valid sample"
	var exact_final_count := 0
	for sample_position: Vector2 in output:
		if sample_position == final_position:
			exact_final_count += 1
	if exact_final_count != 1:
		return "release emitted the exact final sample more than once"
	if stabilizer.call("is_active"):
		return "stabilizer remained active after smoothed release"
	if int(stabilizer.call("get_buffered_sample_count")) != 0:
		return "release retained buffered samples"
	if not (stabilizer.call(
		"release",
		final_position,
		32 * sample_interval_usec,
		true
	) as PackedVector2Array).is_empty():
		return "second release emitted data after the stroke ended"
	if not (stabilizer.call(
		"push",
		Vector2.ONE,
		33 * sample_interval_usec
	) as PackedVector2Array).is_empty():
		return "push emitted data after the stroke ended"
	return ""

func _verify_invalid_release_contract() -> String:
	var stabilizer = ForgeV2FreehandInputStabilizerScript.new()
	var sample_interval_usec := int(stabilizer.call(
		"get_sample_interval_usec"
	))
	var last_valid_position := Vector2(12.0, 4.0)
	var invalid_position := Vector2(5000.0, 5000.0)
	var output := PackedVector2Array()
	output.append_array(stabilizer.call(
		"begin",
		Vector2.ZERO,
		0,
		4
	) as PackedVector2Array)
	output.append_array(stabilizer.call(
		"push",
		last_valid_position,
		12 * sample_interval_usec
	) as PackedVector2Array)
	output.append_array(stabilizer.call(
		"release",
		invalid_position,
		16 * sample_interval_usec,
		false
	) as PackedVector2Array)
	if output.is_empty() or output[output.size() - 1] != last_valid_position:
		return "invalid release did not drain to the last valid raw sample"
	for sample_position: Vector2 in output:
		if sample_position == invalid_position:
			return "invalid release position entered stabilized output"
	return ""

func _verify_bounded_memory_and_reset() -> String:
	var stabilizer = ForgeV2FreehandInputStabilizerScript.new()
	var sample_interval_usec := int(stabilizer.call(
		"get_sample_interval_usec"
	))
	var max_buffered_sample_count := int(stabilizer.call(
		"get_max_buffered_sample_count"
	))
	stabilizer.call("begin", Vector2.ZERO, 0, 10)
	for sample_tick in range(1, 1001):
		stabilizer.call(
			"push",
			Vector2(float(sample_tick), sin(float(sample_tick))),
			sample_tick * sample_interval_usec
		)
		if int(stabilizer.call("get_buffered_sample_count")) > max_buffered_sample_count:
			return "uniform history exceeded its declared bounded capacity"
	stabilizer.call("reset")
	if stabilizer.call("is_active"):
		return "reset did not end the active stroke"
	if int(stabilizer.call("get_buffered_sample_count")) != 0:
		return "reset did not clear the uniform history"
	if int(stabilizer.call("get_smoothing_steps")) != 0:
		return "reset did not clear the active smoothing strength"
	if not (stabilizer.call(
		"push",
		Vector2.ONE,
		1002 * sample_interval_usec
	) as PackedVector2Array).is_empty():
		return "reset stabilizer accepted input before a new begin"
	return ""

func _verify_pathological_catch_up_bound() -> String:
	var stabilizer = ForgeV2FreehandInputStabilizerScript.new()
	var sample_interval_usec := int(stabilizer.call("get_sample_interval_usec"))
	var max_samples_per_call := int(stabilizer.call(
		"get_max_uniform_samples_per_call"
	))
	stabilizer.call("begin", Vector2.ZERO, 0, 10)
	var output: PackedVector2Array = stabilizer.call(
		"push",
		Vector2(5000.0, 2000.0),
		(max_samples_per_call + 5000) * sample_interval_usec
	) as PackedVector2Array
	if output.size() > max_samples_per_call:
		return "long input stall returned an unbounded catch-up batch"
	if int(stabilizer.call("get_buffered_sample_count")) > int(
		stabilizer.call("get_max_buffered_sample_count")
	):
		return "long input stall exceeded bounded retained history"
	return ""

func _arrays_match(
	first_points: PackedVector2Array,
	second_points: PackedVector2Array,
	epsilon: float = EPSILON
) -> bool:
	if first_points.size() != second_points.size():
		return false
	for point_index in range(first_points.size()):
		if first_points[point_index].distance_to(
			second_points[point_index]
		) > epsilon:
			return false
	return true

func _fail(message: String) -> void:
	result_lines.append("ok=false")
	result_lines.append("error=%s" % message)
	_write_results()
	push_error(message)
	quit(1)

func _write_results() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(result_lines))
		file.close()
