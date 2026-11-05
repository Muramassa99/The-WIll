extends SceneTree

const DragInput = preload("res://runtime/combat/combat_marker_drag_input.gd")
const SpeedControl = preload("res://runtime/combat/combat_drag_speed_control.gd")

var checks: Dictionary = {}
var speed_signal_count := 0
var last_signalled_speed := 0.0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var output_dir := "C:/WORKSPACE/godot_runs/combat_marker_drag_input"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output_dir = argument.trim_prefix("--out=")
	_check_input_valve()
	await _check_speed_control()
	var passed := not checks.values().has(false)
	var report := {"passed": passed, "checks": checks,
		"scope": "Deterministic input valve and real speed-widget signals/lifecycle only; no anatomical solve, full station capture or OS pointer certification"}
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("results.json"), FileAccess.WRITE)
	if file == null:
		push_error("Could not write marker input verifier report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("Marker drag input: %s (%d checks)" % ["PASS" if passed else "FAIL", checks.size()])
	quit(0 if passed else 1)

func _check_input_valve() -> void:
	var valve := DragInput.new()
	valve.begin(&"tip", Vector2(100.0, 200.0), 1000000)
	_expect(valve.active and valve.target == &"tip" and valve.pointer_position == Vector2(100.0, 200.0), "begin_preserves_target_and_pointer")
	valve.add_motion(Vector2(30.0, 40.0))
	var accepted: Vector2 = valve.take_motion(1010000)
	_expect(accepted.is_equal_approx(Vector2(1.08, 1.44)), "diagonal_uses_vector_length_cap")
	_expect(valve.take_motion(1020000) == Vector2.ZERO, "burst_has_no_leftover_demand")
	valve.add_motion(Vector2(0.5, -0.25))
	_expect(valve.take_motion(1030000) == Vector2(0.5, -0.25), "slow_motion_is_unchanged")
	valve.add_motion(Vector2(500.0, 0.0))
	_expect(is_equal_approx(valve.take_motion(2030000).length(), 3.0), "one_second_stall_cannot_bank_more_than_one_sixtieth")
	_expect(valve.take_motion(12030000) == Vector2.ZERO, "idle_hold_has_no_motion")
	valve.add_motion(Vector2(500.0, 0.0))
	_expect(is_equal_approx(valve.take_motion(12040000).length(), 1.8), "idle_time_is_not_available_to_next_input")
	valve.add_motion(Vector2(-500.0, 0.0))
	_expect(valve.take_motion(12050000).is_equal_approx(Vector2(-1.8, 0.0)), "reversal_does_not_repay_excess_motion")
	valve.add_motion(Vector2(NAN, 0.0))
	_expect(valve.take_motion(12060000) == Vector2.ZERO, "nonfinite_mouse_motion_ignored")
	valve.add_motion(Vector2(10.0, 0.0))
	_expect(valve.take_motion(12060000) == Vector2.ZERO, "zero_elapsed_has_no_budget")
	_expect(valve.take_motion(12070000) == Vector2.ZERO, "zero_elapsed_does_not_queue_jump")
	valve.add_motion(Vector2(10.0, 0.0))
	valve.finish()
	_expect(not valve.active and valve.target == StringName(), "finish_clears_gesture")
	_expect(valve.take_motion(12080000) == Vector2.ZERO, "finish_discards_pending_input")
	valve.add_motion(Vector2(10.0, 0.0))
	_expect(valve.take_motion(12090000) == Vector2.ZERO, "inactive_input_ignored")
	var distance_60 := _sample_one_second(60)
	var distance_120 := _sample_one_second(120)
	_expect(absf(distance_60 - 180.0) < 0.01, "sixty_hz_matches_selected_speed")
	_expect(absf(distance_120 - 180.0) < 0.01, "one_twenty_hz_matches_selected_speed")
	_expect(absf(distance_60 - distance_120) < 0.01, "speed_independent_of_sixty_vs_one_twenty_hz")

func _sample_one_second(frequency: int) -> float:
	var valve := DragInput.new()
	valve.begin(&"pommel", Vector2.ZERO, 1000000)
	var travelled := 0.0
	for index: int in range(1, frequency + 1):
		valve.add_motion(Vector2(100.0, 0.0))
		travelled += valve.take_motion(1000000 + roundi(float(index) * 1000000.0 / float(frequency))).length()
	return travelled

func _check_speed_control() -> void:
	var previous_mouse_mode := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var widget := SpeedControl.new()
	widget.size = Vector2(110.0, 420.0)
	root.add_child(widget)
	await process_frame
	widget.speed_changed.connect(func(value: float):
		speed_signal_count += 1
		last_signalled_speed = value)
	_expect(widget.get_speed_pixels_per_second() == 180.0, "widget_default_180")
	_expect(is_equal_approx(SpeedControl.sample_speed_pixels_per_second(0.0), 10.0), "slider_minimum_10")
	_expect(is_equal_approx(SpeedControl.sample_speed_pixels_per_second(1.0), 20000.0), "slider_maximum_20000")
	for ratio: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		_expect(absf(SpeedControl.speed_pixels_per_second_to_ratio(SpeedControl.sample_speed_pixels_per_second(ratio)) - ratio) < 0.00001, "slider_inverse_%s" % ratio)
	_expect(SpeedControl.sample_speed_pixels_per_second(0.11) - SpeedControl.sample_speed_pixels_per_second(0.1) < SpeedControl.sample_speed_pixels_per_second(0.81) - SpeedControl.sample_speed_pixels_per_second(0.8), "lower_band_has_finer_precision")
	widget.set_speed_pixels_per_second(185.0)
	_expect(widget.get_speed_pixels_per_second() == 190.0 and speed_signal_count == 0, "silent_setter_quantizes_by_ten")
	widget.up_button.pressed.emit()
	_expect(widget.get_speed_pixels_per_second() == 200.0 and last_signalled_speed == 200.0, "arrow_changes_value_by_ten")
	_expect(is_equal_approx(widget._repeat_timer.wait_time, 0.2) and not widget._repeat_timer.is_stopped(), "arrow_initial_repeat_delay_200ms")
	widget._on_repeat_timeout()
	_expect(widget.get_speed_pixels_per_second() == 210.0 and is_equal_approx(widget._repeat_timer.wait_time, 0.05), "held_arrow_repeat_interval_50ms")
	widget.up_button.button_up.emit()
	_expect(widget._repeat_timer.is_stopped() and widget._hold_direction == 0, "arrow_release_stops_repeat")
	_set_numeric(widget, "999999")
	_expect(widget.get_speed_pixels_per_second() == 20000.0, "numeric_upper_bound")
	widget.up_button.pressed.emit()
	_expect(widget._repeat_timer.is_stopped() and widget.get_speed_pixels_per_second() == 20000.0, "upper_boundary_does_not_repeat")
	_set_numeric(widget, "-999")
	_expect(widget.get_speed_pixels_per_second() == 10.0, "numeric_lower_bound")
	_set_numeric(widget, "243")
	_expect(widget.get_speed_pixels_per_second() == 240.0, "numeric_quantization")
	_set_numeric(widget, "nan")
	_set_numeric(widget, "1e999")
	widget.set_speed_pixels_per_second(NAN)
	widget.set_speed_pixels_per_second(INF)
	_expect(widget.get_speed_pixels_per_second() == 240.0 and widget.value_edit.text == "240", "nonfinite_values_preserve_last_speed")
	widget.slider.value = SpeedControl.speed_pixels_per_second_to_ratio(1230.0)
	_expect(widget.get_speed_pixels_per_second() == 1230.0 and last_signalled_speed == 1230.0, "native_slider_signal_changes_speed")
	widget.up_button.pressed.emit()
	widget.value_edit.focus_exited.emit()
	_expect(widget._repeat_timer.is_stopped(), "focus_exit_finishes_interaction")
	widget.down_button.pressed.emit()
	widget.hide()
	_expect(widget._repeat_timer.is_stopped() and widget._hold_direction == 0, "hiding_finishes_interaction")
	widget.show()
	widget._on_slider_drag_started()
	widget.finish_interaction()
	var before: float = widget.get_speed_pixels_per_second()
	widget._on_slider_changed(1.0)
	_expect(widget.get_speed_pixels_per_second() == before, "cancelled_slider_gesture_cannot_change_value")
	widget._on_slider_drag_ended(false)
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "speed_widget_never_captures_mouse")
	widget.queue_free()
	await process_frame
	Input.mouse_mode = previous_mouse_mode

func _set_numeric(widget, text: String) -> void:
	widget.value_edit.text = text
	widget.value_edit.text_changed.emit(text)
	widget.value_edit.text_submitted.emit(text)

func _expect(condition: bool, name: String) -> void:
	checks[name] = condition
	if not condition:
		push_error("FAILED: " + name)
