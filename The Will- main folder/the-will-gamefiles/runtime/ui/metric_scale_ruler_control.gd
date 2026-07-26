extends Control
class_name MetricScaleRulerControl

const CONTROL_SIZE := Vector2(136.0, 34.0)
const VIEWPORT_INSET_PIXELS := 6.0
const BAR_RECT := Rect2(6.0, 20.0, 124.0, 10.0)
const MAX_SEGMENT_WIDTH_PIXELS := 60.0
const MIN_DISTANCE_METERS_FALLBACK := 0.000001
const SCALE_STEP_EPSILON := 0.000001
const LABEL_FONT_SIZE := 10
const NICE_DISTANCE_MULTIPLIERS := [1.0, 1.25, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0]

var pixels_per_meter: float = 1.0
var minimum_distance_meters: float = MIN_DISTANCE_METERS_FALLBACK
var segment_distance_meters: float = MIN_DISTANCE_METERS_FALLBACK
var segment_width_pixels: float = 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 100
	custom_minimum_size = CONTROL_SIZE
	set_anchor(SIDE_LEFT, 1.0)
	set_anchor(SIDE_TOP, 1.0)
	set_anchor(SIDE_RIGHT, 1.0)
	set_anchor(SIDE_BOTTOM, 1.0)
	offset_left = -CONTROL_SIZE.x - VIEWPORT_INSET_PIXELS
	offset_top = -CONTROL_SIZE.y - VIEWPORT_INSET_PIXELS
	offset_right = -VIEWPORT_INSET_PIXELS
	offset_bottom = -VIEWPORT_INSET_PIXELS


func configure_scale(next_pixels_per_meter: float, next_minimum_distance_meters: float) -> void:
	pixels_per_meter = maxf(next_pixels_per_meter, MIN_DISTANCE_METERS_FALLBACK)
	minimum_distance_meters = maxf(next_minimum_distance_meters, MIN_DISTANCE_METERS_FALLBACK)
	segment_distance_meters = _resolve_segment_distance_meters()
	segment_width_pixels = segment_distance_meters * pixels_per_meter
	queue_redraw()


func get_max_segment_width_pixels() -> float:
	return MAX_SEGMENT_WIDTH_PIXELS


func get_ruler_state() -> Dictionary:
	var zero_x := BAR_RECT.position.x
	var a_x := zero_x + segment_width_pixels
	var b_x := a_x + segment_width_pixels
	var remaining_width_pixels := BAR_RECT.end.x - b_x
	return {
		"pixels_per_meter": pixels_per_meter,
		"minimum_distance_meters": minimum_distance_meters,
		"segment_distance_meters": segment_distance_meters,
		"segment_width_pixels": segment_width_pixels,
		"zero_value_meters": 0.0,
		"a_value_meters": segment_distance_meters,
		"b_value_meters": segment_distance_meters * 2.0,
		"zero_label": "0",
		"a_label": _format_meter_value(segment_distance_meters),
		"b_label": "%s m" % _format_meter_value(segment_distance_meters * 2.0),
		"container_rect": BAR_RECT,
		"minimum_segment_width_pixels": BAR_RECT.size.x / 3.0,
		"remaining_width_pixels": remaining_width_pixels,
		"zero_x": zero_x,
		"a_x": a_x,
		"b_x": b_x,
		"black_rect": Rect2(Vector2(a_x, BAR_RECT.position.y), Vector2(segment_width_pixels, BAR_RECT.size.y)),
	}


func _draw() -> void:
	var ruler_state := get_ruler_state()
	var zero_x := float(ruler_state.get("zero_x", BAR_RECT.position.x))
	var a_x := float(ruler_state.get("a_x", BAR_RECT.position.x))
	var b_x := float(ruler_state.get("b_x", BAR_RECT.position.x))
	var first_segment_rect := Rect2(
		Vector2(zero_x, BAR_RECT.position.y),
		Vector2(segment_width_pixels, BAR_RECT.size.y)
	)
	var second_segment_rect: Rect2 = ruler_state.get("black_rect", Rect2())
	draw_rect(BAR_RECT, Color(0.42, 0.43, 0.44, 1.0), true)
	draw_rect(first_segment_rect, Color(0.88, 0.89, 0.90, 1.0), true)
	draw_rect(second_segment_rect, Color(0.035, 0.04, 0.045, 1.0), true)
	draw_rect(BAR_RECT, Color(0.88, 0.90, 0.91, 1.0), false, 1.0)
	for boundary_x: float in [zero_x, a_x, b_x]:
		draw_line(
			Vector2(boundary_x, BAR_RECT.position.y - 2.0),
			Vector2(boundary_x, BAR_RECT.end.y + 1.0),
			Color(0.88, 0.90, 0.91, 1.0),
			1.0
		)

	var font := get_theme_default_font()
	if font == null:
		return
	_draw_boundary_label(font, String(ruler_state.get("zero_label", "0")), zero_x, HORIZONTAL_ALIGNMENT_LEFT)
	_draw_boundary_label(font, String(ruler_state.get("a_label", "")), a_x, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_boundary_label(font, String(ruler_state.get("b_label", "")), b_x, HORIZONTAL_ALIGNMENT_CENTER)


func _resolve_segment_distance_meters() -> float:
	var minimum_segment_width_pixels := BAR_RECT.size.x / 3.0
	var minimum_visible_distance := minimum_segment_width_pixels / pixels_per_meter
	if minimum_visible_distance <= minimum_distance_meters * (1.0 + SCALE_STEP_EPSILON):
		return minimum_distance_meters
	var maximum_visible_distance := MAX_SEGMENT_WIDTH_PIXELS / pixels_per_meter
	var stepped_distance := _ceil_nice_distance(minimum_visible_distance)
	return clampf(
		stepped_distance,
		minimum_distance_meters,
		maximum_visible_distance
	)


func _ceil_nice_distance(distance_meters: float) -> float:
	var safe_distance := maxf(distance_meters, MIN_DISTANCE_METERS_FALLBACK)
	var exponent := floorf(log(safe_distance) / log(10.0))
	var magnitude := pow(10.0, exponent)
	var normalized := safe_distance / magnitude
	for multiplier: float in NICE_DISTANCE_MULTIPLIERS:
		if normalized <= multiplier * (1.0 + SCALE_STEP_EPSILON):
			return multiplier * magnitude
	return 10.0 * magnitude


func _draw_boundary_label(font: Font, label_text: String, boundary_x: float, alignment: HorizontalAlignment) -> void:
	var label_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_FONT_SIZE)
	var label_x := boundary_x
	match alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			label_x -= label_size.x * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			label_x -= label_size.x
	label_x = clampf(label_x, 0.0, maxf(size.x - label_size.x, 0.0))
	draw_string(
		font,
		Vector2(label_x, 14.0),
		label_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		LABEL_FONT_SIZE,
		Color(0.90, 0.92, 0.93, 1.0)
	)


func _format_meter_value(value_meters: float) -> String:
	var formatted := "%.6f" % maxf(value_meters, 0.0)
	while formatted.contains(".") and formatted.ends_with("0"):
		formatted = formatted.left(formatted.length() - 1)
	if formatted.ends_with("."):
		formatted = formatted.left(formatted.length() - 1)
	return formatted
