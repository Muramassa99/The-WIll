extends SceneTree

const SettingsScript = preload("res://core/models/combat_animation_editor_settings_state.gd")
const DraftScript = preload("res://core/models/combat_animation_draft.gd")
const EntryScript = preload("res://runtime/combat/combat_runtime_entry_transition.gd")
const DurationControlScript = preload("res://runtime/combat/combat_node_duration_control.gd")

class CountedSettings extends CombatAnimationEditorSettingsState:
	var persist_count: int = 0

	func persist() -> bool:
		persist_count += 1
		# Persist the production resource rather than this inner test class:
		# serialized inner-script identity is not a supported settings format.
		var payload = SettingsScript.new()
		payload.save_file_path = save_file_path
		payload.default_transition_duration_seconds = default_transition_duration_seconds
		return payload.persist()

# Exercise real UI preference signals, node insertion, local timing edits and
# duplication. This fixture deliberately supplies already-captured endpoints;
# it is not a grip, animation, camera or equipped-playback certification.
class DurationUI extends CombatAnimationStationUI:
	var fixture_draft: CombatAnimationDraft

	func _ready() -> void:
		_build_ui()
		transition_spin_box.value_changed.connect(_on_transition_changed)
		_populate_static_options()
		visible = false
		set_process(false)

	func _get_active_draft() -> Resource:
		return fixture_draft

	func capture_selected_prepared_pose(_allow_preparation: bool = false) -> Dictionary:
		return {"valid": true}

	func _stage_active_wip_edit(_status_message: String = "",
			_runtime_cache_mode: StringName = PERSIST_RUNTIME_CACHE_DIRTY_ACTIVE) -> void:
		editor_state_dirty = true

	func _refresh_active_editor_surface(_status_message: String = "", _refresh_pose: bool = true) -> void:
		pass

	func _apply_grip_style_bridge_weapon_frame(_bridge: CombatAnimationMotionNode,
			_source: CombatAnimationMotionNode, _style: StringName) -> bool:
		# Timing-only fixture: actual flip geometry has its own verifier.
		return true

var checks: Dictionary = {}
var measurements: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_dir := "C:/WORKSPACE/godot_runs/combat_editor_node_duration"
	var visual := false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.trim_prefix("--output-dir=")
		elif argument == "--visual":
			visual = true
	DirAccess.make_dir_recursive_absolute(output_dir)
	var settings := CountedSettings.new()
	settings.save_file_path = output_dir.path_join("editor_settings.tres")
	_expect(is_equal_approx(settings.default_transition_duration_seconds, 1.0), "fresh_default_is_one_second")
	var ui := DurationUI.new()
	ui.editor_settings = settings
	ui.fixture_draft = DraftScript.create_default_skill_baseline(&"duration_fixture", "Duration", &"skill_slot_1")
	ui.fixture_draft.selected_motion_node_index = 1
	get_root().add_child(ui)
	await process_frame
	_expect(is_equal_approx(ui.default_transition_spin_box.value, 1.0), "control_displays_default")
	ui.default_transition_spin_box.value = 0.2
	_expect(is_equal_approx(ui.get_default_motion_node_transition_duration(), 0.2), "control_sets_preference")
	_expect(not ui.editor_state_dirty, "preference_does_not_dirty_skill")
	for index: int in range(3):
		_expect(ui.insert_motion_node_after_selection(), "r_insertion_%d" % index)
		_expect(is_equal_approx(ui._get_active_motion_node().transition_duration_seconds, 0.2), "new_node_%d_uses_point_two" % index)
	_expect(ui.set_selected_motion_node_transition_duration(0.65, false, false, false, false, false), "local_duration_edit")
	var local_node: CombatAnimationMotionNode = ui._get_active_motion_node()
	_expect(is_equal_approx(ui.get_default_motion_node_transition_duration(), 0.2), "local_override_preserves_default")
	_expect(ui.insert_motion_node_after_selection(), "r_after_local_override")
	_expect(is_equal_approx(ui._get_active_motion_node().transition_duration_seconds, 0.2), "r_does_not_copy_local_duration")
	var before: Array[float] = _durations(ui.fixture_draft)
	ui.editor_state_dirty = false
	ui.default_transition_spin_box.value = 0.4
	_expect(_durations(ui.fixture_draft) == before, "changing_default_preserves_existing_nodes")
	_expect(not ui.editor_state_dirty, "second_preference_change_does_not_dirty_skill")
	_expect(ui.insert_motion_node_after_selection(), "r_after_default_change")
	_expect(is_equal_approx(ui._get_active_motion_node().transition_duration_seconds, 0.4), "next_node_uses_new_default")
	ui.fixture_draft.selected_motion_node_index = ui.fixture_draft.motion_node_chain.find(local_node)
	_expect(ui.duplicate_selected_motion_node(), "explicit_duplicate")
	_expect(is_equal_approx(ui._get_active_motion_node().transition_duration_seconds, 0.65), "explicit_duplicate_keeps_source_duration")
	_expect(ui._insert_generated_grip_style_transition_after_selection(&"grip_reverse", false, false, false, false, false), "generated_transition_insertion")
	var selected: int = ui.fixture_draft.selected_motion_node_index
	_expect(is_equal_approx(ui.fixture_draft.motion_node_chain[selected - 1].transition_duration_seconds, 0.65), "generated_bridge_keeps_source_duration")
	_expect(is_equal_approx(ui.fixture_draft.motion_node_chain[selected].transition_duration_seconds, 0.4), "generated_following_authored_node_uses_default")
	var loaded = ResourceLoader.load(settings.save_file_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var valid_loaded: bool = loaded is CombatAnimationEditorSettingsState
	_expect(valid_loaded and is_equal_approx(loaded.default_transition_duration_seconds, 0.4), "preference_persisted_to_disk")
	if not valid_loaded:
		# Keep writing the failed report instead of crashing before quit().
		loaded = SettingsScript.new()
		loaded.save_file_path = settings.save_file_path
		loaded.default_transition_duration_seconds = 0.4
	var reopened := DurationUI.new()
	reopened.editor_settings = loaded
	reopened.fixture_draft = ui.fixture_draft
	get_root().add_child(reopened)
	await process_frame
	_expect(is_equal_approx(reopened.default_transition_spin_box.value, 0.4), "reopened_ui_displays_saved_default")
	_expect(is_equal_approx(EntryScript.ENTRY_DURATION_SECONDS, 0.160), "entry_duration_remains_160ms")
	await _check_curve()
	_check_bounds_and_legacy(ui)
	await _check_native_input(ui, settings, output_dir, visual)
	var passed: bool = not checks.values().has(false)
	var report := {"passed": passed, "checks": checks,
		"measurements": measurements,
		"scope": "UI preference and node timing; prepared-pose/geometry fixture, no live grip or playback claim"}
	var file := FileAccess.open(output_dir.path_join("results.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print(JSON.stringify(report))
	ui.queue_free()
	reopened.queue_free()
	await process_frame
	quit(0 if passed else 1)

func _durations(draft: CombatAnimationDraft) -> Array[float]:
	var values: Array[float] = []
	for node: Resource in draft.motion_node_chain:
		values.append(node.transition_duration_seconds)
	return values

func _expect(condition: bool, label: String) -> void:
	checks[label] = condition

func _check_curve() -> void:
	var anchors_ok := true
	var anchors: Array[int] = [100, 250, 500, 1000, 2000]
	for index: int in anchors.size():
		anchors_ok = anchors_ok and absf(DurationControlScript.sample_duration_ms(index / 4.0) - anchors[index]) < 0.02
	_expect(anchors_ok, "nonlinear_curve_passes_all_five_anchors")
	var increasing := true
	var previous: float = DurationControlScript.sample_duration_ms(0.0)
	for index: int in range(1, 1001):
		var sampled: float = DurationControlScript.sample_duration_ms(index / 1000.0)
		increasing = increasing and sampled > previous
		previous = sampled
	_expect(increasing, "curve_strictly_increases_across_full_travel")
	var smooth := true
	var derivatives: Array = []
	for knot: float in [0.25, 0.5, 0.75]:
		var epsilon := 0.0001
		var center: float = DurationControlScript.sample_duration_ms(knot)
		var left: float = (center - DurationControlScript.sample_duration_ms(knot - epsilon)) / epsilon
		var right: float = (DurationControlScript.sample_duration_ms(knot + epsilon) - center) / epsilon
		derivatives.append({"ratio": knot, "left_slope": left, "right_slope": right})
		smooth = smooth and absf(left - right) / maxf(left, right) < 0.01
	_expect(smooth, "sensitivity_is_continuous_at_internal_knots")
	measurements["curve_knot_derivatives"] = derivatives
	var control = DurationControlScript.new()
	get_root().add_child(control)
	control.hide()
	var reachable := true
	var maximum_inverse_error := 0.0
	for value_ms: int in range(100, 2001, 10):
		var ratio: float = DurationControlScript.duration_ms_to_ratio(value_ms)
		maximum_inverse_error = maxf(maximum_inverse_error, absf(DurationControlScript.sample_duration_ms(ratio) - value_ms))
		control.slider.value = ratio
		reachable = reachable and control.get_duration_ms() == value_ms
	_expect(reachable, "all_191_numeric_values_reachable_via_continuous_slider")
	_expect(is_zero_approx(control.slider.step), "native_slider_position_is_continuous")
	_expect(maximum_inverse_error < 0.02, "inverse_curve_error_below_point_zero_two_ms")
	measurements["max_inverse_error_ms"] = maximum_inverse_error
	control.queue_free()
	await process_frame

func _check_bounds_and_legacy(ui: DurationUI) -> void:
	ui.fixture_draft.selected_motion_node_index = 1
	var node: CombatAnimationMotionNode = ui._get_active_motion_node()
	node.transition_duration_seconds = 0.04
	node.normalize()
	ui._refresh_editor_fields()
	_expect(is_equal_approx(node.transition_duration_seconds, 0.04), "legacy_short_duration_unchanged_by_model_and_field_refresh")
	ui.set_selected_motion_node_transition_duration(0.001, false, false, false, false, false)
	_expect(is_equal_approx(node.transition_duration_seconds, 0.1), "deliberate_local_edit_clamps_to_100ms")
	ui.set_selected_motion_node_transition_duration(3.0, false, false, false, false, false)
	_expect(is_equal_approx(node.transition_duration_seconds, 2.0), "deliberate_local_edit_clamps_to_2000ms")
	ui.set_selected_motion_node_transition_duration(0.736, false, false, false, false, false)
	_expect(is_equal_approx(node.transition_duration_seconds, 0.74), "local_duration_uses_ten_ms_steps")
	ui.set_default_motion_node_transition_duration(0.001)
	_expect(is_equal_approx(ui.get_default_motion_node_transition_duration(), 0.1), "default_clamps_to_100ms")
	ui.set_default_motion_node_transition_duration(5.0)
	_expect(is_equal_approx(ui.get_default_motion_node_transition_duration(), 2.0), "default_clamps_to_2000ms")
	ui.default_transition_spin_box.value = 0.73
	_expect(ui.preview_duration_control.get_duration_ms() == 730, "settings_field_syncs_viewport_control")
	_expect(is_equal_approx(node.transition_duration_seconds, 0.74), "default_changes_preserve_local_duration")

func _check_native_input(ui: DurationUI, settings: CountedSettings, output_dir: String, visual: bool) -> void:
	get_root().size = Vector2i(1600, 900)
	ui.workflow_step = ui.WORKFLOW_STEP_EDITOR
	ui._refresh_workflow_visibility()
	ui.visible = true
	ui.panel.show()
	ui.backdrop.show()
	ui.title_label.text = "SKILL CRAFTER — DURATION INPUT CHECK"
	ui.footer_status_label.text = "Timing-only UI fixture: no live weapon or grip is being tested."
	await process_frame
	await process_frame
	ui._layout_preview_duration_control()
	await process_frame
	var control = ui.preview_duration_control
	_expect(control.is_visible_in_tree() and control.size.y >= 190.0, "duration_control_visible_in_real_editor_layout")
	ui.set_default_motion_node_transition_duration(1.0)
	var writes_before: int = settings.persist_count
	var arrow_point: Vector2 = control.up_button.get_global_rect().get_center()
	await _move(arrow_point)
	_button(arrow_point, true)
	await process_frame
	_expect(control.get_duration_ms() == 1010, "native_arrow_press_immediately_adds_ten_ms")
	await create_timer(0.1).timeout
	_expect(control.get_duration_ms() == 1010, "arrow_does_not_repeat_before_initial_delay")
	await create_timer(0.35).timeout
	var held_value: int = control.get_duration_ms()
	_expect(held_value >= 1040 and held_value <= 1090, "held_arrow_repeats_after_delay")
	_expect(settings.persist_count == writes_before, "held_arrow_does_not_write_settings_each_repeat")
	_button(arrow_point, false)
	await process_frame
	_expect(settings.persist_count == writes_before + 1, "arrow_release_persists_once")
	await create_timer(0.1).timeout
	_expect(control.get_duration_ms() == held_value, "arrow_release_stops_repeat")
	measurements["held_arrow_duration_ms"] = held_value
	await _check_lower_arrow_and_stop_conditions(ui, settings)
	ui.set_default_motion_node_transition_duration(0.5)
	writes_before = settings.persist_count
	var rect: Rect2 = control.slider.get_global_rect()
	var center := rect.get_center()
	var grabber: Texture2D = control.slider.get_theme_icon("grabber")
	var usable_height: float = rect.size.y - float(grabber.get_height())
	var target_ratio: float = DurationControlScript.duration_ms_to_ratio(1234.0)
	var upper := Vector2(center.x, center.y - (target_ratio - 0.5) * usable_height)
	await _move(center)
	_button(center, true)
	await process_frame
	await _move(upper, true)
	var drag_value: int = control.get_duration_ms()
	var raw_drag_ratio: float = control.slider.value
	var quantized_ratio: float = DurationControlScript.duration_ms_to_ratio(drag_value)
	_expect(drag_value > 500 and drag_value < 2000, "native_slider_drag_changes_duration")
	_expect(absf(raw_drag_ratio - quantized_ratio) > 0.000001, "slider_drag_position_is_not_snapped_to_numeric_inverse")
	_expect(is_equal_approx(ui.default_transition_spin_box.value, drag_value / 1000.0), "viewport_drag_syncs_settings_field")
	_expect(settings.persist_count == writes_before, "slider_drag_defers_disk_write")
	_button(upper, false)
	await process_frame
	_expect(settings.persist_count == writes_before + 1, "slider_release_persists_once")
	_expect(absf(control.slider.value - raw_drag_ratio) < 0.000001, "slider_release_preserves_continuous_drag_position")
	measurements["slider_drag_duration_ms"] = drag_value
	measurements["slider_drag_raw_ratio"] = raw_drag_ratio
	measurements["slider_drag_numeric_inverse_ratio"] = quantized_ratio
	var numeric_point: Vector2 = control.value_edit.get_global_rect().get_center()
	await _move(numeric_point)
	_button(numeric_point, true)
	_button(numeric_point, false)
	await process_frame
	control.value_edit.select_all()
	writes_before = settings.persist_count
	for character: String in "735":
		_key(character.unicode_at(0), character.unicode_at(0))
	await process_frame
	_expect(settings.persist_count == writes_before, "typing_numeric_duration_defers_disk_write")
	_key(KEY_ENTER)
	await process_frame
	_expect(control.get_duration_ms() == 740 and is_equal_approx(ui.default_transition_spin_box.value, 0.74), "native_numeric_edit_rounds_and_syncs_to_ten_ms")
	_expect(settings.persist_count == writes_before + 1, "numeric_commit_persists_once")
	ui.preview_camera_orbiting = true
	_button(numeric_point, false, MOUSE_BUTTON_RIGHT)
	await process_frame
	_expect(not ui.preview_camera_orbiting, "right_release_over_control_clears_camera_orbit")
	if visual and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot := get_root().get_texture().get_image()
		_expect(screenshot.save_png(output_dir.path_join("duration_control.png")) == OK, "editor_layout_screenshot_saved")
	ui.hide()

func _check_lower_arrow_and_stop_conditions(ui: DurationUI, settings: CountedSettings) -> void:
	var control = ui.preview_duration_control
	ui.set_default_motion_node_transition_duration(1.0)
	var writes_before: int = settings.persist_count
	var down_point: Vector2 = control.down_button.get_global_rect().get_center()
	await _move(down_point)
	_button(down_point, true)
	await process_frame
	_expect(control.get_duration_ms() == 990, "native_lower_arrow_immediately_subtracts_ten_ms")
	await create_timer(0.1).timeout
	_expect(control.get_duration_ms() == 990, "lower_arrow_waits_before_repeat")
	await create_timer(0.35).timeout
	var held_value: int = control.get_duration_ms()
	_expect(held_value >= 910 and held_value <= 960, "held_lower_arrow_repeats_after_delay")
	_expect(settings.persist_count == writes_before, "lower_arrow_repeat_defers_persistence")
	_button(down_point, false)
	await create_timer(0.1).timeout
	_expect(control.get_duration_ms() == held_value and settings.persist_count == writes_before + 1, "lower_arrow_release_stops_and_persists_once")
	measurements["held_lower_arrow_duration_ms"] = held_value
	for upper_bound: bool in [true, false]:
		ui.set_default_motion_node_transition_duration(1.99 if upper_bound else 0.11)
		var point: Vector2 = control.up_button.get_global_rect().get_center() if upper_bound else down_point
		writes_before = settings.persist_count
		await _move(point)
		_button(point, true)
		await create_timer(0.3).timeout
		var expected: int = 2000 if upper_bound else 100
		_expect(control.get_duration_ms() == expected, "arrow_stops_at_%dms_boundary" % expected)
		_button(point, false)
		await process_frame
		_expect(settings.persist_count == writes_before + 1, "boundary_%dms_finishes_only_once" % expected)
	for stop_reason: String in ["hidden", "window_focus_lost"]:
		ui.set_default_motion_node_transition_duration(1.0)
		var up_point: Vector2 = control.up_button.get_global_rect().get_center()
		writes_before = settings.persist_count
		# Re-enter the button after showing the previously hidden control so
		# the synthetic pointer refreshes Godot's hover target before pressing.
		await _move(up_point + Vector2(-60.0, 0.0))
		await _move(up_point)
		_button(up_point, true)
		await process_frame
		var value_before_stop: int = control.get_duration_ms()
		if stop_reason == "hidden":
			control.hide()
		else:
			# Exercise the connected Window signal without manipulating OS focus.
			get_root().focus_exited.emit()
		await create_timer(0.3).timeout
		measurements["stop_%s" % stop_reason] = {"before_ms": value_before_stop,
			"after_ms": control.get_duration_ms(), "writes_before": writes_before,
			"writes_after": settings.persist_count, "arrow_pressed": control.up_button.button_pressed,
			"hold_direction": control.get("_hold_direction")}
		_expect(control.get_duration_ms() == value_before_stop and value_before_stop == 1010, "arrow_repeat_stops_when_%s" % stop_reason)
		_expect(settings.persist_count == writes_before + 1, "interrupted_arrow_persists_once_when_%s" % stop_reason)
		_button(up_point, false)
		control.show()
		await process_frame

func _move(point: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.window_id = get_root().get_window_id()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	get_root().push_input(event, true)
	await process_frame

func _button(point: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.window_id = get_root().get_window_id()
	event.button_index = button
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	event.pressed = pressed
	get_root().push_input(event, true)

func _key(code: int, unicode_value: int = 0) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = unicode_value
		event.pressed = pressed
		get_root().push_input(event, true)
