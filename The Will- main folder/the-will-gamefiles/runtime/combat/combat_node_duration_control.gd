extends Control
class_name CombatNodeDurationControl

signal duration_changed(duration_ms: int)
signal edit_finished

const MotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const MIN_DURATION_MS := int(MotionNodeScript.MIN_AUTHORED_TRANSITION_DURATION_SECONDS * 1000.0)
const MAX_DURATION_MS := int(MotionNodeScript.MAX_AUTHORED_TRANSITION_DURATION_SECONDS * 1000.0)
const STEP_MS := int(MotionNodeScript.TRANSITION_DURATION_STEP_SECONDS * 1000.0)
const REPEAT_DELAY_SECONDS := 0.2
const REPEAT_INTERVAL_SECONDS := 0.05
const MARK_VALUES := [100, 250, 500, 1000, 2000]
const MARK_SLOPES := [400.0, 750.0, 1350.0, 2700.0, 5000.0]
const MARK_COLOR := Color(0.25, 0.76, 0.48, 0.95)

static var _duration_curve: Curve = null

var slider: VSlider = null
var up_button: Button = null
var down_button: Button = null
var value_edit: LineEdit = null
var _repeat_timer: Timer = null
var _duration_ms: int = 1000
var _hold_direction: int = 0
var _interaction_active: bool = false
var _numeric_dirty: bool = false
var _syncing: bool = false

static func sample_duration_ms(ratio: float) -> float:
	if _duration_curve == null:
		_duration_curve = Curve.new()
		_duration_curve.max_value = float(MAX_DURATION_MS)
		_duration_curve.min_value = float(MIN_DURATION_MS)
		for index: int in MARK_VALUES.size():
			_duration_curve.add_point(Vector2(float(index) / 4.0, float(MARK_VALUES[index])),
				MARK_SLOPES[index], MARK_SLOPES[index], Curve.TANGENT_FREE, Curve.TANGENT_FREE)
	return _duration_curve.sample(clampf(ratio, 0.0, 1.0))

static func duration_ms_to_ratio(value_ms: float) -> float:
	if value_ms <= float(MIN_DURATION_MS):
		return 0.0
	if value_ms >= float(MAX_DURATION_MS):
		return 1.0
	var lower := 0.0
	var upper := 1.0
	for _iteration: int in range(20):
		var middle := (lower + upper) * 0.5
		if sample_duration_ms(middle) < value_ms:
			lower = middle
		else:
			upper = middle
	return (lower + upper) * 0.5

func _ready() -> void:
	custom_minimum_size = Vector2(100.0, 190.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	tooltip_text = "Default duration for new motion nodes. Existing nodes keep their timing."
	slider = VSlider.new()
	slider.name = "DurationSlider"
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.0
	slider.scrollable = false
	slider.focus_mode = Control.FOCUS_NONE
	slider.mouse_force_pass_scroll_events = false
	add_child(slider)
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(0.06, 0.07, 0.085, 0.78)
	rail.border_color = Color(0.4, 0.43, 0.46, 0.7)
	rail.set_border_width_all(1)
	slider.add_theme_stylebox_override("slider", rail)
	up_button = _make_arrow("IncreaseDuration", "▲", 1)
	down_button = _make_arrow("DecreaseDuration", "▼", -1)
	value_edit = LineEdit.new()
	value_edit.name = "DurationMilliseconds"
	value_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_edit.add_theme_constant_override("minimum_character_width", 0)
	value_edit.select_all_on_focus = true
	value_edit.tooltip_text = "New node duration in milliseconds (100–2000, steps of 10)."
	value_edit.mouse_force_pass_scroll_events = false
	add_child(value_edit)
	_repeat_timer = Timer.new()
	_repeat_timer.one_shot = true
	_repeat_timer.ignore_time_scale = true
	_repeat_timer.timeout.connect(_on_repeat_timeout)
	add_child(_repeat_timer)
	slider.value_changed.connect(_on_slider_changed)
	slider.drag_started.connect(_on_slider_drag_started)
	slider.drag_ended.connect(_on_slider_drag_ended)
	value_edit.text_changed.connect(_on_numeric_changed)
	value_edit.text_submitted.connect(_on_numeric_submitted)
	value_edit.focus_exited.connect(finish_interaction)
	resized.connect(_layout_controls)
	visibility_changed.connect(_on_visibility_changed)
	get_window().focus_exited.connect(finish_interaction)
	_sync_controls(true)
	_layout_controls()

func _make_arrow(node_name: String, caption: String, direction: int) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.mouse_force_pass_scroll_events = false
	button.tooltip_text = "%s 10 ms. Hold to repeat." % ("Add" if direction > 0 else "Subtract")
	add_child(button)
	button.pressed.connect(_on_arrow_down.bind(direction))
	button.button_up.connect(finish_interaction)
	button.mouse_exited.connect(_on_arrow_exited.bind(direction))
	return button

func _layout_controls() -> void:
	if slider == null:
		return
	var rail_x := maxf(size.x - 30.0, 70.0)
	var bottom_y := maxf(size.y - 72.0, 118.0)
	up_button.position = Vector2(rail_x, 22.0)
	up_button.size = Vector2(26.0, 32.0)
	slider.position = Vector2(rail_x + 3.0, 58.0)
	slider.size = Vector2(20.0, bottom_y - 62.0)
	down_button.position = Vector2(rail_x, bottom_y)
	down_button.size = Vector2(26.0, 32.0)
	var value_font := value_edit.get_theme_font("font")
	var digit_width := value_font.get_string_size("0000", HORIZONTAL_ALIGNMENT_LEFT, -1.0, value_edit.get_theme_font_size("font_size")).x
	var box_width := ceilf(digit_width + value_edit.get_theme_stylebox("normal").get_minimum_size().x + 8.0)
	value_edit.size = Vector2(box_width, value_edit.get_combined_minimum_size().y)
	value_edit.position = Vector2(rail_x + down_button.size.x - value_edit.size.x, bottom_y + 36.0)
	queue_redraw()

func _draw() -> void:
	if slider == null:
		return
	var font := get_theme_default_font()
	draw_string(font, Vector2(4.0, 14.0), "New node (ms)", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.8, 0.83, 0.85))
	var grabber := slider.get_theme_icon("grabber")
	var inset: float = float(grabber.get_height()) * 0.5 if grabber != null else 8.0
	var usable := maxf(slider.size.y - inset * 2.0, 1.0)
	for index: int in MARK_VALUES.size():
		var y := slider.position.y + inset + (1.0 - float(index) / 4.0) * usable
		draw_string(font, Vector2(4.0, y - 4.0), str(MARK_VALUES[index]), HORIZONTAL_ALIGNMENT_RIGHT, slider.position.x - 7.0, 12, MARK_COLOR)
		draw_line(Vector2(slider.position.x - 17.0, y), Vector2(slider.position.x - 3.0, y), MARK_COLOR)

func get_duration_ms() -> int:
	return _duration_ms

func set_duration_ms(value_ms: int) -> void:
	var resolved := _quantize(value_ms)
	if resolved == _duration_ms:
		return
	_duration_ms = resolved
	_numeric_dirty = false
	_sync_controls(true)

func _quantize(value_ms: float) -> int:
	return clampi(roundi(value_ms / float(STEP_MS)) * STEP_MS, MIN_DURATION_MS, MAX_DURATION_MS)

func _sync_controls(move_slider: bool) -> void:
	if slider == null:
		return
	_syncing = true
	value_edit.text = str(_duration_ms)
	if move_slider:
		slider.set_value_no_signal(duration_ms_to_ratio(float(_duration_ms)))
	_syncing = false

func _on_slider_drag_started() -> void:
	finish_interaction()
	_interaction_active = true

func _on_slider_changed(ratio: float) -> void:
	if _syncing:
		return
	_interaction_active = true
	_set_user_duration(_quantize(sample_duration_ms(ratio)), false)

func _on_slider_drag_ended(_changed: bool) -> void:
	finish_interaction()

func _set_user_duration(value_ms: int, move_slider: bool) -> void:
	var previous := _duration_ms
	_duration_ms = _quantize(value_ms)
	_sync_controls(move_slider)
	if previous != _duration_ms:
		duration_changed.emit(_duration_ms)

func _on_arrow_down(direction: int) -> void:
	finish_interaction()
	_interaction_active = true
	_hold_direction = direction
	_set_user_duration(_duration_ms + direction * STEP_MS, true)
	if _can_repeat():
		_repeat_timer.start(REPEAT_DELAY_SECONDS)
	else:
		finish_interaction()

func _can_repeat() -> bool:
	return (_hold_direction > 0 and _duration_ms < MAX_DURATION_MS) or (_hold_direction < 0 and _duration_ms > MIN_DURATION_MS)

func _on_repeat_timeout() -> void:
	if not is_visible_in_tree() or not _can_repeat():
		finish_interaction()
		return
	_set_user_duration(_duration_ms + _hold_direction * STEP_MS, true)
	if _can_repeat():
		_repeat_timer.start(REPEAT_INTERVAL_SECONDS)
	else:
		finish_interaction()

func _on_arrow_exited(direction: int) -> void:
	if _hold_direction == direction:
		finish_interaction()

func _on_numeric_changed(_text: String) -> void:
	if not _syncing:
		_numeric_dirty = true
		_interaction_active = true

func _on_numeric_submitted(_text: String) -> void:
	finish_interaction()
	value_edit.release_focus()

func finish_interaction() -> void:
	_hold_direction = 0
	if _repeat_timer != null:
		_repeat_timer.stop()
	if _numeric_dirty and value_edit != null:
		_numeric_dirty = false
		if value_edit.text.is_valid_float() and is_finite(value_edit.text.to_float()):
			_set_user_duration(_quantize(value_edit.text.to_float()), true)
		else:
			_sync_controls(false)
	if _interaction_active:
		_interaction_active = false
		edit_finished.emit()

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		finish_interaction()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		finish_interaction()
