extends Control
class_name PlayerCrosshairOverlay

@export_range(0.0, 64.0, 1.0) var crosshair_gap_px: float = 8.0
@export_range(1.0, 64.0, 1.0) var crosshair_line_length_px: float = 12.0
@export_range(1.0, 8.0, 1.0) var crosshair_line_thickness_px: float = 2.0
@export_range(0.0, 8.0, 1.0) var outline_thickness_px: float = 1.0
@export var crosshair_color: Color = Color(0.92, 0.94, 0.97, 0.9)
@export var outline_color: Color = Color(0.05, 0.06, 0.08, 0.9)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func set_crosshair_visible_state(enabled: bool) -> void:
	visible = enabled
	if enabled:
		queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	_draw_crosshair_line(center + Vector2(-(crosshair_gap_px + crosshair_line_length_px), 0.0), center + Vector2(-crosshair_gap_px, 0.0))
	_draw_crosshair_line(center + Vector2(crosshair_gap_px, 0.0), center + Vector2(crosshair_gap_px + crosshair_line_length_px, 0.0))
	_draw_crosshair_line(center + Vector2(0.0, -(crosshair_gap_px + crosshair_line_length_px)), center + Vector2(0.0, -crosshair_gap_px))
	_draw_crosshair_line(center + Vector2(0.0, crosshair_gap_px), center + Vector2(0.0, crosshair_gap_px + crosshair_line_length_px))

func _draw_crosshair_line(from_point: Vector2, to_point: Vector2) -> void:
	if outline_thickness_px > 0.0:
		draw_line(from_point, to_point, outline_color, crosshair_line_thickness_px + outline_thickness_px * 2.0, true)
	draw_line(from_point, to_point, crosshair_color, crosshair_line_thickness_px, true)

func _set_full_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
