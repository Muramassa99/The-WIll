class_name ForgeV2RadialMenu
extends Control

## A transient visual selector. The owning UI commits the selection on key release.
## Entry order starts at twelve o'clock and continues clockwise.

const OUTER_RADIUS_PIXELS := 100.0
const INNER_RADIUS_PIXELS := 30.0
const EDGE_MARGIN_PIXELS := 8.0
const BACKGROUND := Color("#151c27")
const HOVER_BACKGROUND := Color("#294452")
const OUTER_COLOR := Color("#51d2e4")
const SEPARATOR_COLOR := Color("#ec963d")
const INNER_COLOR := Color("#e3cf58")
const ICON_COLOR := Color("#f2f5fa")

var _entries: Array[Dictionary] = []
var _requested_center := Vector2.ZERO
var _center := Vector2.ZERO
var _pointer := Vector2.ZERO
var _outer_radius := OUTER_RADIUS_PIXELS
var _inner_radius := INNER_RADIUS_PIXELS
var _selected_index := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	visible = false
	resized.connect(_on_resized)


func open_at(local_center: Vector2, entries: Array[Dictionary]) -> void:
	_entries.clear()
	for entry in entries:
		if StringName(entry.get("id", &"")) != &"":
			_entries.append(entry.duplicate())
	_requested_center = local_center
	_refresh_geometry()
	# Opening near an edge must not select a wedge merely because the menu moved.
	_pointer = _center
	_selected_index = -1
	visible = not _entries.is_empty()
	queue_redraw()


func update_pointer(local_position: Vector2) -> void:
	_pointer = local_position
	var previous_index := _selected_index
	_selected_index = _resolve_pointer_index()
	if previous_index != _selected_index:
		queue_redraw()


func get_selected_id() -> StringName:
	if not visible or _selected_index < 0 or _selected_index >= _entries.size():
		return &""
	return StringName(_entries[_selected_index].get("id", &""))


func close_menu() -> void:
	visible = false
	_selected_index = -1
	_entries.clear()
	queue_redraw()


func _on_resized() -> void:
	_refresh_geometry()
	if visible:
		_selected_index = _resolve_pointer_index()
		queue_redraw()


func _refresh_geometry() -> void:
	var shortest_side := maxf(minf(size.x, size.y), 0.0)
	var margin := minf(EDGE_MARGIN_PIXELS, shortest_side * 0.05)
	_outer_radius = maxf(minf(OUTER_RADIUS_PIXELS, shortest_side * 0.5 - margin), 0.0)
	_inner_radius = _outer_radius * INNER_RADIUS_PIXELS / OUTER_RADIUS_PIXELS
	var inset := _outer_radius + margin
	_center = Vector2(
		clampf(_requested_center.x, inset, maxf(inset, size.x - inset)),
		clampf(_requested_center.y, inset, maxf(inset, size.y - inset))
	)


func _resolve_pointer_index() -> int:
	if not visible or _entries.is_empty() or _outer_radius <= 0.0:
		return -1
	var offset := _pointer - _center
	if offset.length_squared() <= _inner_radius * _inner_radius:
		return -1
	# A hold gesture remains directional outside the drawn ring.
	var sector_angle := TAU / float(_entries.size())
	var angle := fposmod(offset.angle() + PI * 0.5 + sector_angle * 0.5, TAU)
	return mini(int(floor(angle / sector_angle)), _entries.size() - 1)


func _draw() -> void:
	if not visible or _entries.is_empty() or _outer_radius <= 0.0:
		return
	var visual_scale := _outer_radius / OUTER_RADIUS_PIXELS
	var line_width := maxf(1.0, 2.0 * visual_scale)
	var sector_angle := TAU / float(_entries.size())
	draw_circle(_center, _outer_radius, BACKGROUND, true, -1.0, true)
	if _selected_index >= 0:
		var start := -PI * 0.5 + (float(_selected_index) - 0.5) * sector_angle
		draw_colored_polygon(_annular_sector(start, start + sector_angle), HOVER_BACKGROUND)
	for index in _entries.size():
		var boundary_angle := -PI * 0.5 + (float(index) - 0.5) * sector_angle
		var direction := Vector2.from_angle(boundary_angle)
		draw_line(_center + direction * _inner_radius, _center + direction * _outer_radius,
			SEPARATOR_COLOR, line_width, true)
		_draw_entry(index, -PI * 0.5 + float(index) * sector_angle, visual_scale)
	draw_arc(_center, _outer_radius, 0.0, TAU, 96, OUTER_COLOR, line_width, true)
	draw_circle(_center, _inner_radius, BACKGROUND, true, -1.0, true)
	draw_arc(_center, _inner_radius, 0.0, TAU, 48, INNER_COLOR, line_width, true)
	_draw_centered_text("Cancel", _center + Vector2(0.0, 4.0 * visual_scale),
		maxi(8, roundi(12.0 * visual_scale)), INNER_COLOR)


func _annular_sector(start: float, finish: float) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	const SEGMENTS := 16
	for step in range(SEGMENTS + 1):
		var angle := lerpf(start, finish, float(step) / float(SEGMENTS))
		polygon.append(_center + Vector2.from_angle(angle) * _outer_radius)
	for step in range(SEGMENTS, -1, -1):
		var angle := lerpf(start, finish, float(step) / float(SEGMENTS))
		polygon.append(_center + Vector2.from_angle(angle) * _inner_radius)
	return polygon


func _draw_entry(index: int, angle: float, visual_scale: float) -> void:
	var entry: Dictionary = _entries[index]
	var anchor := _center + Vector2.from_angle(angle) * (_outer_radius * 0.66)
	var normal: Vector3 = entry.get("normal", Vector3.ZERO)
	_draw_face_icon(anchor - Vector2(0.0, 5.0 * visual_scale), normal, 12.0 * visual_scale)
	_draw_centered_text(String(entry.get("label", "")),
		anchor + Vector2(0.0, 21.0 * visual_scale), maxi(8, roundi(12.0 * visual_scale)), ICON_COLOR)


func _draw_centered_text(text: String, baseline_center: Vector2, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	if font == null:
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, baseline_center - Vector2(width * 0.5, 0.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_face_icon(center: Vector2, normal: Vector3, icon_scale: float) -> void:
	# Fixed isometric projection keeps all six signed face choices comparable.
	var corners := PackedVector3Array([
		Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1),
		Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1),
	])
	var projected := PackedVector2Array()
	for point in corners:
		projected.append(center + Vector2((point.x - point.z) * 0.72,
			(point.x + point.z) * 0.36 - point.y * 0.8) * icon_scale)
	var face := PackedInt32Array()
	if absf(normal.x) > 0.5:
		face = PackedInt32Array([1, 2, 6, 5]) if normal.x > 0.0 else PackedInt32Array([0, 3, 7, 4])
	elif absf(normal.y) > 0.5:
		face = PackedInt32Array([3, 2, 6, 7]) if normal.y > 0.0 else PackedInt32Array([0, 1, 5, 4])
	elif absf(normal.z) > 0.5:
		face = PackedInt32Array([4, 5, 6, 7]) if normal.z > 0.0 else PackedInt32Array([0, 1, 2, 3])
	if not face.is_empty():
		var face_polygon := PackedVector2Array()
		for corner_index in face:
			face_polygon.append(projected[corner_index])
		draw_colored_polygon(face_polygon, Color(1.0, 1.0, 1.0, 0.3))
	var edges := PackedInt32Array([0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 5, 6, 6, 7, 7, 4, 0, 4, 1, 5, 2, 6, 3, 7])
	for pair in range(0, edges.size(), 2):
		draw_line(projected[edges[pair]], projected[edges[pair + 1]],
			Color(0.94, 0.96, 0.98, 0.65), 1.0, true)
	for index in face.size():
		draw_line(projected[face[index]], projected[face[(index + 1) % face.size()]], ICON_COLOR, 1.5, true)
