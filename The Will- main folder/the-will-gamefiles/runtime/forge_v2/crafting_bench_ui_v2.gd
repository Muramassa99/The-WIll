extends CanvasLayer
class_name CraftingBenchUIV2

signal closed

const ForgeV2WorkspacePreviewScript = preload("res://runtime/forge_v2/forge_v2_workspace_preview.gd")
const ForgeV2KeybindingStateScript = preload("res://runtime/forge_v2/forge_v2_keybinding_state.gd")
const ForgeV2ProfileShapeLibraryScript = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const PlayerToolProfileLibraryStateScript = preload("res://core/models/player_tool_profile_library_state.gd")
const MetricScaleRulerControlScript = preload("res://runtime/ui/metric_scale_ruler_control.gd")
const UiWindowLayerPolicyScript = preload("res://runtime/ui/ui_window_layer_policy.gd")

class ProfileBuilderPreviewControl:
	extends Control

	signal control_point_dragged(point_index: int, point_position_meters: Vector2)
	signal control_point_drag_finished(point_index: int)
	signal anchor_point_dragged(anchor_position_meters: Vector2)
	signal anchor_point_drag_finished()
	signal anchor_point_reset_requested()
	signal canvas_context_requested(
		target_kind: StringName,
		target_index: int,
		target_id: StringName,
		target_position_meters: Vector2
	)
	signal canvas_context_dismiss_requested()

	const POINT_PICK_RADIUS_PIXELS := 14.0
	const FILLET_PICK_RADIUS_PIXELS := 8.0
	const SEGMENT_PICK_RADIUS_PIXELS := 9.0
	const METRIC_VIEW_ZOOM_STEP_FACTOR := 1.2
	const METRIC_VIEW_NUMERIC_SCALE_EPSILON := 0.000001
	const METRIC_VIEW_MAX_VISIBLE_WIDTH_METERS := 1.2
	const METRIC_GRID_MIN_SPACING_PIXELS := 12.0

	var profile_polygon: PackedVector2Array = PackedVector2Array()
	var control_points: PackedVector2Array = PackedVector2Array()
	var corner_ids: Array[StringName] = []
	var fillet_corner_results: Array[Dictionary] = []
	var anchor_position: Vector2 = Vector2.ZERO
	var guide_polygon: PackedVector2Array = PackedVector2Array()
	var guide_grid_segments: Array = []
	var guide_snap_points: PackedVector2Array = PackedVector2Array()
	var guide_grid_step_meters: float = METRIC_VIEW_NUMERIC_SCALE_EPSILON
	var guide_grid_rotation_degrees: float = 0.0
	var grid_snapping_enabled: bool = false
	var rounded_enabled: bool = false
	var active_control_point_index: int = -1
	var is_dragging_control_point: bool = false
	var is_dragging_anchor_point: bool = false
	var metric_view_enabled: bool = false
	var metric_view_initialized: bool = false
	var minimum_scale_distance_meters: float = METRIC_VIEW_NUMERIC_SCALE_EPSILON
	var pixels_per_meter: float = 1.0
	var view_center_profile_meters: Vector2 = Vector2.ZERO
	var metric_scale_ruler: Control = null
	var metric_view_input_handler: Callable = Callable()
	var canvas_context_enabled: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_force_pass_scroll_events = false
		clip_contents = true
		resized.connect(_on_preview_resized)

	func _on_preview_resized() -> void:
		if not metric_view_enabled or not metric_view_initialized:
			return
		var next_scale := clampf(
			pixels_per_meter,
			_calculate_metric_view_minimum_scale(),
			_calculate_metric_view_maximum_scale()
		)
		if not is_equal_approx(next_scale, pixels_per_meter):
			pixels_per_meter = next_scale
			_update_metric_scale_ruler()
		queue_redraw()

	func set_profile_polygon(next_profile_polygon: PackedVector2Array) -> void:
		profile_polygon = next_profile_polygon
		queue_redraw()

	func set_profile_geometry(
		next_profile_polygon: PackedVector2Array,
		next_control_points: PackedVector2Array,
		next_rounded_enabled: bool,
		next_anchor_position: Vector2,
		next_corner_metadata: Array = [],
		next_fillet_corner_results: Array = []
	) -> void:
		profile_polygon = next_profile_polygon
		control_points = next_control_points
		corner_ids = []
		for point_index in range(control_points.size()):
			var corner_id := StringName()
			if point_index < next_corner_metadata.size():
				var metadata_variant: Variant = next_corner_metadata[point_index]
				if metadata_variant is Dictionary:
					corner_id = StringName(
						(metadata_variant as Dictionary).get(
							"corner_id",
							StringName()
						)
					)
			corner_ids.append(corner_id)
		fillet_corner_results = []
		for result_variant: Variant in next_fillet_corner_results:
			if result_variant is Dictionary:
				fillet_corner_results.append(
					(result_variant as Dictionary).duplicate(true)
				)
		rounded_enabled = next_rounded_enabled
		anchor_position = _constrain_anchor_position(next_anchor_position)
		queue_redraw()

	func configure_canvas_context(next_enabled: bool) -> void:
		canvas_context_enabled = next_enabled
		if not canvas_context_enabled:
			canvas_context_dismiss_requested.emit()

	func set_profile_guide(
		next_guide_polygon: PackedVector2Array,
		next_guide_grid_segments: Array,
		next_guide_snap_points: PackedVector2Array,
		next_grid_snapping_enabled: bool,
		next_guide_grid_step_meters: float = METRIC_VIEW_NUMERIC_SCALE_EPSILON,
		next_guide_grid_rotation_degrees: float = 0.0
	) -> void:
		guide_polygon = next_guide_polygon
		guide_grid_segments = next_guide_grid_segments
		guide_snap_points = next_guide_snap_points
		guide_grid_step_meters = maxf(
			next_guide_grid_step_meters,
			METRIC_VIEW_NUMERIC_SCALE_EPSILON
		)
		guide_grid_rotation_degrees = next_guide_grid_rotation_degrees
		grid_snapping_enabled = next_grid_snapping_enabled
		_ensure_metric_view_initialized()
		queue_redraw()

	func attach_metric_scale_ruler(next_ruler: Control) -> void:
		metric_scale_ruler = next_ruler
		_update_metric_scale_ruler()

	func set_metric_view_input_handler(next_handler: Callable) -> void:
		metric_view_input_handler = next_handler

	func configure_metric_view(next_enabled: bool, next_minimum_scale_distance_meters: float) -> void:
		var was_enabled := metric_view_enabled
		metric_view_enabled = next_enabled
		minimum_scale_distance_meters = maxf(
			next_minimum_scale_distance_meters,
			METRIC_VIEW_NUMERIC_SCALE_EPSILON
		)
		if metric_scale_ruler != null:
			metric_scale_ruler.visible = metric_view_enabled
		if metric_view_enabled and not was_enabled:
			metric_view_initialized = false
			view_center_profile_meters = Vector2.ZERO
		_ensure_metric_view_initialized()
		_update_metric_scale_ruler()
		queue_redraw()

	func is_metric_view_active() -> bool:
		return metric_view_enabled

	func reset_metric_view() -> void:
		metric_view_initialized = false
		view_center_profile_meters = Vector2.ZERO
		_ensure_metric_view_initialized()
		_update_metric_scale_ruler()
		queue_redraw()

	func zoom_metric_view_at(screen_position: Vector2, zoom_in: bool) -> bool:
		if not metric_view_enabled:
			return false
		_ensure_metric_view_initialized()
		var old_scale := maxf(pixels_per_meter, METRIC_VIEW_NUMERIC_SCALE_EPSILON)
		var maximum_scale := _calculate_metric_view_maximum_scale()
		var minimum_scale := _calculate_metric_view_minimum_scale()
		var zoom_factor := METRIC_VIEW_ZOOM_STEP_FACTOR if zoom_in else (1.0 / METRIC_VIEW_ZOOM_STEP_FACTOR)
		var next_scale := clampf(
			old_scale * zoom_factor,
			minimum_scale,
			maximum_scale
		)
		if is_equal_approx(next_scale, old_scale):
			return false
		var profile_under_pointer := _screen_to_profile_with_scale(screen_position, old_scale)
		var screen_delta := screen_position - size * 0.5
		view_center_profile_meters = profile_under_pointer - Vector2(
			screen_delta.x / next_scale,
			-screen_delta.y / next_scale
		)
		pixels_per_meter = next_scale
		_update_metric_scale_ruler()
		queue_redraw()
		return true

	func pan_metric_view_by(screen_delta: Vector2) -> bool:
		if not metric_view_enabled or screen_delta.is_zero_approx():
			return false
		_ensure_metric_view_initialized()
		var draw_scale := maxf(pixels_per_meter, METRIC_VIEW_NUMERIC_SCALE_EPSILON)
		view_center_profile_meters += Vector2(
			-screen_delta.x / draw_scale,
			screen_delta.y / draw_scale
		)
		queue_redraw()
		return true

	func center_metric_view() -> bool:
		if not metric_view_enabled or view_center_profile_meters.is_zero_approx():
			return false
		view_center_profile_meters = Vector2.ZERO
		queue_redraw()
		return true

	func get_metric_view_state() -> Dictionary:
		_ensure_metric_view_initialized()
		return {
			"enabled": metric_view_enabled,
			"pixels_per_meter": _calculate_view_scale(),
			"minimum_scale_distance_meters": minimum_scale_distance_meters,
			"maximum_pixels_per_meter": _calculate_metric_view_maximum_scale(),
			"minimum_pixels_per_meter": _calculate_metric_view_minimum_scale(),
			"maximum_visible_width_meters": METRIC_VIEW_MAX_VISIBLE_WIDTH_METERS,
			"visible_span_meters": Vector2(
				size.x / maxf(_calculate_view_scale(), METRIC_VIEW_NUMERIC_SCALE_EPSILON),
				size.y / maxf(_calculate_view_scale(), METRIC_VIEW_NUMERIC_SCALE_EPSILON)
			),
			"view_center_profile_meters": view_center_profile_meters,
		}

	func get_metric_scale_ruler_state() -> Dictionary:
		if metric_scale_ruler == null or not metric_scale_ruler.has_method("get_ruler_state"):
			return {}
		return metric_scale_ruler.call("get_ruler_state") as Dictionary

	func get_metric_grid_state() -> Dictionary:
		if not metric_view_enabled:
			return {"enabled": false}
		return _build_metric_grid_state(_calculate_view_scale())

	func _build_metric_grid_state(draw_scale: float) -> Dictionary:
		if (
			not metric_view_enabled
			or size.x <= 0.0
			or size.y <= 0.0
			or guide_grid_step_meters <= METRIC_VIEW_NUMERIC_SCALE_EPSILON
		):
			return {"enabled": false}
		var safe_scale := maxf(draw_scale, METRIC_VIEW_NUMERIC_SCALE_EPSILON)
		var lod_multiplier := 1
		while (
			guide_grid_step_meters * float(lod_multiplier) * safe_scale
			< METRIC_GRID_MIN_SPACING_PIXELS
			and lod_multiplier < 1073741824
		):
			lod_multiplier *= 2
		var visual_step_meters := guide_grid_step_meters * float(lod_multiplier)
		var rotation_radians := deg_to_rad(guide_grid_rotation_degrees)
		var inverse_rotation_radians := -rotation_radians
		var viewport_corners := PackedVector2Array([
			Vector2.ZERO,
			Vector2(size.x, 0.0),
			size,
			Vector2(0.0, size.y),
		])
		var visible_grid_min := Vector2(INF, INF)
		var visible_grid_max := Vector2(-INF, -INF)
		for screen_corner: Vector2 in viewport_corners:
			var profile_corner := _screen_to_profile_with_scale(screen_corner, safe_scale)
			var grid_corner := profile_corner.rotated(inverse_rotation_radians)
			visible_grid_min.x = minf(visible_grid_min.x, grid_corner.x)
			visible_grid_min.y = minf(visible_grid_min.y, grid_corner.y)
			visible_grid_max.x = maxf(visible_grid_max.x, grid_corner.x)
			visible_grid_max.y = maxf(visible_grid_max.y, grid_corner.y)
		var minimum_x_index := int(floor(visible_grid_min.x / visual_step_meters)) - 1
		var maximum_x_index := int(ceil(visible_grid_max.x / visual_step_meters)) + 1
		var minimum_y_index := int(floor(visible_grid_min.y / visual_step_meters)) - 1
		var maximum_y_index := int(ceil(visible_grid_max.y / visual_step_meters)) + 1
		var draw_grid_min := Vector2(
			float(minimum_x_index) * visual_step_meters,
			float(minimum_y_index) * visual_step_meters
		)
		var draw_grid_max := Vector2(
			float(maximum_x_index) * visual_step_meters,
			float(maximum_y_index) * visual_step_meters
		)
		var grid_segments_profile_meters: Array = []
		for x_index in range(minimum_x_index, maximum_x_index + 1):
			var grid_x := float(x_index) * visual_step_meters
			grid_segments_profile_meters.append(PackedVector2Array([
				Vector2(grid_x, draw_grid_min.y).rotated(rotation_radians),
				Vector2(grid_x, draw_grid_max.y).rotated(rotation_radians),
			]))
		for y_index in range(minimum_y_index, maximum_y_index + 1):
			var grid_y := float(y_index) * visual_step_meters
			grid_segments_profile_meters.append(PackedVector2Array([
				Vector2(draw_grid_min.x, grid_y).rotated(rotation_radians),
				Vector2(draw_grid_max.x, grid_y).rotated(rotation_radians),
			]))
		return {
			"enabled": true,
			"base_step_meters": guide_grid_step_meters,
			"visual_step_meters": visual_step_meters,
			"lod_multiplier": lod_multiplier,
			"spacing_pixels": visual_step_meters * safe_scale,
			"minimum_spacing_pixels": METRIC_GRID_MIN_SPACING_PIXELS,
			"rotation_degrees": guide_grid_rotation_degrees,
			"visible_grid_local_bounds": Rect2(
				visible_grid_min,
				visible_grid_max - visible_grid_min
			),
			"draw_grid_local_bounds": Rect2(
				draw_grid_min,
				draw_grid_max - draw_grid_min
			),
			"minimum_x_index": minimum_x_index,
			"maximum_x_index": maximum_x_index,
			"minimum_y_index": minimum_y_index,
			"maximum_y_index": maximum_y_index,
			"vertical_line_count": maximum_x_index - minimum_x_index + 1,
			"horizontal_line_count": maximum_y_index - minimum_y_index + 1,
			"segments_profile_meters": grid_segments_profile_meters,
		}

	func _draw_metric_grid(draw_scale: float) -> void:
		var grid_state := _build_metric_grid_state(draw_scale)
		if not bool(grid_state.get("enabled", false)):
			return
		var grid_segments: Array = grid_state.get("segments_profile_meters", []) as Array
		for segment_variant: Variant in grid_segments:
			var segment: PackedVector2Array = segment_variant
			if segment.size() < 2:
				continue
			draw_line(
				_profile_to_screen(segment[0], draw_scale),
				_profile_to_screen(segment[1], draw_scale),
				Color(0.50, 0.66, 0.70, 0.24),
				1.0
			)

	func _draw() -> void:
		_update_metric_scale_ruler()
		var preview_rect := Rect2(Vector2.ZERO, size)
		draw_rect(preview_rect, Color(0.025, 0.03, 0.034, 1.0), true)
		var draw_scale := _calculate_view_scale()
		var profile_origin_screen := _profile_to_screen(Vector2.ZERO, draw_scale)
		draw_line(
			Vector2(0.0, profile_origin_screen.y),
			Vector2(size.x, profile_origin_screen.y),
			Color(0.18, 0.27, 0.31, 0.7),
			1.0
		)
		draw_line(
			Vector2(profile_origin_screen.x, 0.0),
			Vector2(profile_origin_screen.x, size.y),
			Color(0.18, 0.27, 0.31, 0.7),
			1.0
		)
		var guide_draw_points := PackedVector2Array()
		if guide_polygon.size() >= 3:
			for point: Vector2 in guide_polygon:
				guide_draw_points.append(_profile_to_screen(point, draw_scale))
			draw_colored_polygon(guide_draw_points, Color(0.16, 0.26, 0.30, 0.44))
		if metric_view_enabled:
			_draw_metric_grid(draw_scale)
		elif guide_polygon.size() >= 3:
			for segment_variant: Variant in guide_grid_segments:
				var segment: PackedVector2Array = segment_variant
				if segment.size() < 2:
					continue
				draw_line(
					_profile_to_screen(segment[0], draw_scale),
					_profile_to_screen(segment[1], draw_scale),
					Color(0.50, 0.66, 0.70, 0.24),
					1.0
				)
		if guide_draw_points.size() >= 3:
			for point_index in range(guide_draw_points.size()):
				var next_index := (point_index + 1) % guide_draw_points.size()
				draw_line(guide_draw_points[point_index], guide_draw_points[next_index], Color(0.62, 0.80, 0.84, 0.66), 1.5)
		if profile_polygon.size() >= 3:
			var draw_points := PackedVector2Array()
			for point: Vector2 in profile_polygon:
				draw_points.append(_profile_to_screen(point, draw_scale))
			draw_colored_polygon(draw_points, Color(0.35, 0.78, 0.86, 0.62))
			for point_index in range(draw_points.size()):
				var next_index := (point_index + 1) % draw_points.size()
				draw_line(draw_points[point_index], draw_points[next_index], Color(0.80, 0.97, 1.0, 0.95), 2.0)
		if control_points.size() >= 3:
			var control_line_color := Color(1.0, 0.68, 0.18, 0.35 if rounded_enabled else 0.80)
			for point_index in range(control_points.size()):
				var next_index := (point_index + 1) % control_points.size()
				draw_line(
					_profile_to_screen(control_points[point_index], draw_scale),
					_profile_to_screen(control_points[next_index], draw_scale),
					control_line_color,
					1.0
				)
			for point_index in range(control_points.size()):
				var point_screen := _profile_to_screen(control_points[point_index], draw_scale)
				var point_color := Color(1.0, 0.73, 0.20, 1.0)
				if rounded_enabled:
					point_color.a = 0.86
				if point_index == active_control_point_index:
					draw_circle(point_screen, 8.0, Color(1.0, 0.88, 0.32, 1.0))
				draw_circle(point_screen, 5.0, point_color)
				draw_circle(point_screen, 5.5, Color(0.06, 0.04, 0.02, 0.85), false, 1.0)
		draw_circle(profile_origin_screen, 3.0, Color(1.0, 0.86, 0.24, 0.75))
		var anchor_screen := _profile_to_screen(anchor_position, draw_scale)
		draw_circle(anchor_screen, 7.0, Color(1.0, 0.18, 0.14, 1.0))
		draw_circle(anchor_screen, 7.5, Color(0.12, 0.02, 0.02, 0.95), false, 1.5)
		draw_rect(preview_rect, Color(0.18, 0.23, 0.25, 1.0), false, 1.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouse and metric_view_input_handler.is_valid():
			var metric_mouse_event := event as InputEventMouse
			if bool(metric_view_input_handler.call(event, metric_mouse_event.position)):
				accept_event()
				return
		if event is InputEventMouseButton:
			var mouse_button := event as InputEventMouseButton
			if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
				if not mouse_button.pressed:
					return
				if _is_near_anchor_point(mouse_button.position):
					canvas_context_dismiss_requested.emit()
					anchor_point_reset_requested.emit()
					accept_event()
					return
				if (
					canvas_context_enabled
					and not is_dragging_control_point
					and not is_dragging_anchor_point
				):
					var context_target := get_canvas_context_target(
						mouse_button.position
					)
					if context_target.is_empty():
						canvas_context_dismiss_requested.emit()
					else:
						canvas_context_requested.emit(
							StringName(context_target.get(
								"target_kind",
								StringName()
							)),
							int(context_target.get("target_index", -1)),
							StringName(context_target.get(
								"target_id",
								StringName()
							)),
							context_target.get(
								"target_position_meters",
								Vector2.ZERO
							) as Vector2
						)
					accept_event()
				return
			if mouse_button.button_index != MOUSE_BUTTON_LEFT:
				return
			if mouse_button.pressed:
				canvas_context_dismiss_requested.emit()
				if _is_near_anchor_point(mouse_button.position):
					is_dragging_anchor_point = true
					accept_event()
					queue_redraw()
					return
				var nearest_index := _find_nearest_control_point(mouse_button.position)
				if nearest_index < 0:
					return
				active_control_point_index = nearest_index
				is_dragging_control_point = true
				accept_event()
				queue_redraw()
			else:
				if is_dragging_control_point:
					var finished_index := active_control_point_index
					is_dragging_control_point = false
					active_control_point_index = -1
					control_point_drag_finished.emit(finished_index)
					accept_event()
					queue_redraw()
				elif is_dragging_anchor_point:
					is_dragging_anchor_point = false
					anchor_point_drag_finished.emit()
					accept_event()
					queue_redraw()
			return
		if event is InputEventMouseMotion and is_dragging_anchor_point:
			var motion := event as InputEventMouseMotion
			anchor_position = _constrain_anchor_position(_screen_to_profile(motion.position))
			anchor_point_dragged.emit(anchor_position)
			accept_event()
			queue_redraw()
			return
		if event is InputEventMouseMotion and is_dragging_control_point and active_control_point_index >= 0:
			var motion := event as InputEventMouseMotion
			var point_position := _constrain_control_point_position(_screen_to_profile(motion.position))
			control_points[active_control_point_index] = point_position
			control_point_dragged.emit(active_control_point_index, point_position)
			accept_event()
			queue_redraw()

	func _is_near_anchor_point(screen_position: Vector2) -> bool:
		var draw_scale := _calculate_view_scale()
		return _profile_to_screen(anchor_position, draw_scale).distance_squared_to(screen_position) <= POINT_PICK_RADIUS_PIXELS * POINT_PICK_RADIUS_PIXELS

	func _find_nearest_control_point(screen_position: Vector2) -> int:
		if control_points.is_empty():
			return -1
		var draw_scale := _calculate_view_scale()
		var nearest_index := -1
		var nearest_distance_squared := POINT_PICK_RADIUS_PIXELS * POINT_PICK_RADIUS_PIXELS
		for point_index in range(control_points.size()):
			var point_screen := _profile_to_screen(control_points[point_index], draw_scale)
			var distance_squared := point_screen.distance_squared_to(screen_position)
			if distance_squared > nearest_distance_squared:
				continue
			nearest_distance_squared = distance_squared
			nearest_index = point_index
		return nearest_index

	func get_canvas_context_target(screen_position: Vector2) -> Dictionary:
		if not canvas_context_enabled or control_points.size() < 3:
			return {}
		var point_index := _find_nearest_control_point(screen_position)
		if point_index >= 0:
			return {
				"target_kind": &"control_point",
				"target_index": point_index,
				"target_id": _get_corner_id(point_index),
				"target_position_meters": control_points[point_index],
			}
		var fillet_target := _find_nearest_fillet_arc(screen_position)
		if not fillet_target.is_empty():
			return fillet_target
		return _find_nearest_control_segment(screen_position)

	func _find_nearest_fillet_arc(screen_position: Vector2) -> Dictionary:
		var draw_scale := _calculate_view_scale()
		var nearest_target := {}
		var nearest_distance_squared := (
			FILLET_PICK_RADIUS_PIXELS * FILLET_PICK_RADIUS_PIXELS
		)
		for result_variant: Variant in fillet_corner_results:
			if not result_variant is Dictionary:
				continue
			var result := result_variant as Dictionary
			var arc_points: PackedVector2Array = result.get(
				"arc_points",
				PackedVector2Array()
			)
			if arc_points.size() < 2:
				continue
			for arc_index in range(arc_points.size() - 1):
				var arc_start_screen := _profile_to_screen(
					arc_points[arc_index],
					draw_scale
				)
				var arc_end_screen := _profile_to_screen(
					arc_points[arc_index + 1],
					draw_scale
				)
				var closest_screen := _closest_point_on_segment(
					screen_position,
					arc_start_screen,
					arc_end_screen
				)
				var distance_squared := closest_screen.distance_squared_to(
					screen_position
				)
				if distance_squared > nearest_distance_squared:
					continue
				nearest_distance_squared = distance_squared
				nearest_target = {
					"target_kind": &"fillet",
					"target_index": int(result.get("index", -1)),
					"target_id": StringName(result.get(
						"corner_id",
						StringName()
					)),
					"target_position_meters": _screen_to_profile(closest_screen),
				}
		return nearest_target

	func _find_nearest_control_segment(screen_position: Vector2) -> Dictionary:
		var draw_scale := _calculate_view_scale()
		var nearest_target := {}
		var nearest_distance_squared := (
			SEGMENT_PICK_RADIUS_PIXELS * SEGMENT_PICK_RADIUS_PIXELS
		)
		for segment_start_index in range(control_points.size()):
			var segment_end_index := (
				segment_start_index + 1
			) % control_points.size()
			var segment_start_screen := _profile_to_screen(
				control_points[segment_start_index],
				draw_scale
			)
			var segment_end_screen := _profile_to_screen(
				control_points[segment_end_index],
				draw_scale
			)
			var closest_screen := _closest_point_on_segment(
				screen_position,
				segment_start_screen,
				segment_end_screen
			)
			var distance_squared := closest_screen.distance_squared_to(
				screen_position
			)
			if distance_squared > nearest_distance_squared:
				continue
			nearest_distance_squared = distance_squared
			nearest_target = {
				"target_kind": &"segment",
				"target_index": segment_start_index,
				"target_id": _get_corner_id(segment_start_index),
				"target_position_meters": _screen_to_profile(closest_screen),
			}
		return nearest_target

	func _get_corner_id(point_index: int) -> StringName:
		if point_index < 0 or point_index >= corner_ids.size():
			return StringName()
		return corner_ids[point_index]

	func _profile_to_screen(profile_position: Vector2, draw_scale: float) -> Vector2:
		var center := size * 0.5
		var view_center := view_center_profile_meters if metric_view_enabled else Vector2.ZERO
		var relative_position := profile_position - view_center
		return center + Vector2(relative_position.x, -relative_position.y) * draw_scale

	func _screen_to_profile(screen_position: Vector2) -> Vector2:
		var draw_scale := maxf(_calculate_view_scale(), METRIC_VIEW_NUMERIC_SCALE_EPSILON)
		return _screen_to_profile_with_scale(screen_position, draw_scale)

	func _screen_to_profile_with_scale(screen_position: Vector2, draw_scale: float) -> Vector2:
		var center := size * 0.5
		var local_screen := screen_position - center
		var view_center := view_center_profile_meters if metric_view_enabled else Vector2.ZERO
		return view_center + Vector2(local_screen.x / draw_scale, -local_screen.y / draw_scale)

	func _calculate_view_scale() -> float:
		if metric_view_enabled:
			_ensure_metric_view_initialized()
			return maxf(pixels_per_meter, METRIC_VIEW_NUMERIC_SCALE_EPSILON)
		return _calculate_fit_scale()

	func _calculate_fit_scale() -> float:
		var max_extent := METRIC_VIEW_NUMERIC_SCALE_EPSILON
		var scale_points := guide_polygon if guide_polygon.size() >= 3 else profile_polygon
		for point: Vector2 in scale_points:
			max_extent = maxf(max_extent, absf(point.x) * 2.0)
			max_extent = maxf(max_extent, absf(point.y) * 2.0)
		return maxf((minf(size.x, size.y) - 56.0) / max_extent, 1.0)

	func _ensure_metric_view_initialized() -> void:
		if not metric_view_enabled or metric_view_initialized:
			return
		var maximum_scale := _calculate_metric_view_maximum_scale()
		pixels_per_meter = minf(_calculate_fit_scale(), maximum_scale)
		pixels_per_meter = maxf(pixels_per_meter, _calculate_metric_view_minimum_scale())
		metric_view_initialized = true

	func _calculate_metric_view_maximum_scale() -> float:
		var maximum_segment_width_pixels := 60.0
		if metric_scale_ruler != null and metric_scale_ruler.has_method("get_max_segment_width_pixels"):
			maximum_segment_width_pixels = float(metric_scale_ruler.call("get_max_segment_width_pixels"))
		return maximum_segment_width_pixels / maxf(
			minimum_scale_distance_meters,
			METRIC_VIEW_NUMERIC_SCALE_EPSILON
		)

	func _calculate_metric_view_minimum_scale() -> float:
		var viewport_width := maxf(
			size.x,
			METRIC_VIEW_NUMERIC_SCALE_EPSILON
		)
		return minf(
			viewport_width / METRIC_VIEW_MAX_VISIBLE_WIDTH_METERS,
			_calculate_metric_view_maximum_scale()
		)

	func _update_metric_scale_ruler() -> void:
		if metric_scale_ruler == null:
			return
		metric_scale_ruler.visible = metric_view_enabled
		if not metric_view_enabled or not metric_scale_ruler.has_method("configure_scale"):
			return
		_ensure_metric_view_initialized()
		metric_scale_ruler.call(
			"configure_scale",
			maxf(pixels_per_meter, METRIC_VIEW_NUMERIC_SCALE_EPSILON),
			minimum_scale_distance_meters
		)

	func _constrain_control_point_position(profile_position: Vector2) -> Vector2:
		if metric_view_enabled:
			if not grid_snapping_enabled:
				return profile_position
			return ForgeV2ProfileShapeLibraryScript.snap_point_to_grid(
				profile_position,
				guide_grid_step_meters,
				guide_grid_rotation_degrees
			)
		if guide_polygon.size() < 3:
			return profile_position
		var clamped_position := _clamp_point_to_polygon(profile_position, guide_polygon)
		if not grid_snapping_enabled or guide_snap_points.is_empty():
			return clamped_position
		var nearest_point: Vector2 = guide_snap_points[0]
		var nearest_distance := nearest_point.distance_squared_to(clamped_position)
		for snap_point: Vector2 in guide_snap_points:
			var distance := snap_point.distance_squared_to(clamped_position)
			if distance >= nearest_distance:
				continue
			nearest_distance = distance
			nearest_point = snap_point
		return nearest_point

	func _constrain_anchor_position(profile_position: Vector2) -> Vector2:
		if profile_polygon.size() < 3:
			return profile_position
		var clamped_position := _clamp_point_to_polygon(profile_position, profile_polygon)
		if not grid_snapping_enabled:
			return clamped_position
		if metric_view_enabled:
			return ForgeV2ProfileShapeLibraryScript.snap_point_to_grid_inside_polygon(
				clamped_position,
				profile_polygon,
				guide_grid_step_meters,
				guide_grid_rotation_degrees
			)
		if guide_snap_points.is_empty():
			return clamped_position
		var nearest_point := clamped_position
		var nearest_distance := INF
		for snap_point: Vector2 in guide_snap_points:
			if not _is_point_inside_or_on_polygon(snap_point, profile_polygon):
				continue
			var distance := snap_point.distance_squared_to(clamped_position)
			if distance >= nearest_distance:
				continue
			nearest_distance = distance
			nearest_point = snap_point
		return nearest_point

	func _clamp_point_to_polygon(profile_position: Vector2, polygon: PackedVector2Array) -> Vector2:
		if polygon.size() < 3:
			return profile_position
		if _is_point_inside_or_on_polygon(profile_position, polygon):
			return profile_position
		var nearest_point: Vector2 = polygon[0]
		var nearest_distance := INF
		for point_index in range(polygon.size()):
			var segment_a: Vector2 = polygon[point_index]
			var segment_b: Vector2 = polygon[(point_index + 1) % polygon.size()]
			var candidate := _closest_point_on_segment(profile_position, segment_a, segment_b)
			var distance := candidate.distance_squared_to(profile_position)
			if distance >= nearest_distance:
				continue
			nearest_distance = distance
			nearest_point = candidate
		return nearest_point

	func _is_point_inside_or_on_polygon(profile_position: Vector2, polygon: PackedVector2Array) -> bool:
		if polygon.size() < 3:
			return false
		if Geometry2D.is_point_in_polygon(profile_position, polygon):
			return true
		var tolerance_squared := 0.00001 * 0.00001
		for point_index in range(polygon.size()):
			var segment_a: Vector2 = polygon[point_index]
			var segment_b: Vector2 = polygon[(point_index + 1) % polygon.size()]
			if _closest_point_on_segment(profile_position, segment_a, segment_b).distance_squared_to(profile_position) <= tolerance_squared:
				return true
		return false

	func _closest_point_on_segment(point: Vector2, segment_a: Vector2, segment_b: Vector2) -> Vector2:
		var segment := segment_b - segment_a
		var segment_length_squared := segment.length_squared()
		if segment_length_squared <= 0.0000000001:
			return segment_a
		var t := clampf((point - segment_a).dot(segment) / segment_length_squared, 0.0, 1.0)
		return segment_a + segment * t

	func _calculate_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
		if polygon.is_empty():
			return Rect2()
		var min_point: Vector2 = polygon[0]
		var max_point: Vector2 = polygon[0]
		for point: Vector2 in polygon:
			min_point.x = minf(min_point.x, point.x)
			min_point.y = minf(min_point.y, point.y)
			max_point.x = maxf(max_point.x, point.x)
			max_point.y = maxf(max_point.y, point.y)
		return Rect2(min_point, max_point - min_point)

@onready var panel: PanelContainer = $Panel
@onready var root_margin: MarginContainer = $Panel/MarginContainer
@onready var root_vbox: VBoxContainer = $Panel/MarginContainer/RootVBox
@onready var header_vbox: VBoxContainer = $Panel/MarginContainer/RootVBox/HeaderVBox
@onready var title_label: Label = $Panel/MarginContainer/RootVBox/HeaderVBox/TitleLabel
@onready var subtitle_label: Label = $Panel/MarginContainer/RootVBox/HeaderVBox/SubtitleLabel
@onready var body_panel: PanelContainer = $Panel/MarginContainer/RootVBox/BodyPanel
@onready var body_margin: MarginContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin
@onready var body_scroll: ScrollContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll
@onready var body_vbox: VBoxContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox
@onready var status_label: Label = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/StatusLabel
@onready var new_draft_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/DraftButtonRow/NewDraftButton
@onready var clear_strokes_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/DraftButtonRow/ClearStrokesButton
@onready var builder_path_option: OptionButton = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/BuilderPathRow/BuilderPathOption
@onready var builder_component_row: HBoxContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/BuilderComponentRow
@onready var builder_component_option: OptionButton = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/BuilderComponentRow/BuilderComponentOption
@onready var operation_option: OptionButton = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/OperationRow/OperationOption
@onready var placement_policy_option: OptionButton = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/PlacementPolicyRow/PlacementPolicyOption
@onready var active_material_label: Label = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/MaterialPaletteRow/MaterialPaletteVBox/ActiveMaterialLabel
@onready var material_palette_grid: GridContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/MaterialPaletteRow/MaterialPaletteVBox/MaterialPaletteScroll/MaterialPaletteGrid
@onready var primitive_option: OptionButton = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/PrimitiveRow/PrimitiveOption
@onready var radius_value_label: Label = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/RadiusRow/RadiusValueLabel
@onready var radius_decrease_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/RadiusRow/RadiusDecreaseButton
@onready var radius_increase_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/RadiusRow/RadiusIncreaseButton
@onready var add_empty_stroke_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/StrokeButtonRow/AddEmptyStrokeButton
@onready var commit_pending_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/StrokeButtonRow/CommitPendingButton
@onready var undo_layer_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/StrokeButtonRow/UndoLayerButton
@onready var redo_layer_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/StrokeButtonRow/RedoLayerButton
@onready var body_stack_option: OptionButton = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/BodyStackRow/BodyStackOption
@onready var delete_selected_body_button: Button = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/BodyStackRow/DeleteSelectedBodyButton
@onready var platform_contract_label: Label = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/PlatformContractLabel
@onready var summary_label: Label = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/SummaryLabel
@onready var workspace_panel: PanelContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/WorkspacePanel
@onready var workspace_margin: MarginContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/WorkspacePanel/WorkspaceMargin
@onready var workspace_vbox: VBoxContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/WorkspacePanel/WorkspaceMargin/WorkspaceVBox
@onready var workspace_title_label: Label = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/WorkspacePanel/WorkspaceMargin/WorkspaceVBox/WorkspaceTitle
@onready var workspace_view_container: SubViewportContainer = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/WorkspacePanel/WorkspaceMargin/WorkspaceVBox/WorkspaceViewportContainer
@onready var workspace_subviewport: SubViewport = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/WorkspacePanel/WorkspaceMargin/WorkspaceVBox/WorkspaceViewportContainer/WorkspaceSubViewport
@onready var workspace_status_label: Label = $Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/WorkspacePanel/WorkspaceMargin/WorkspaceVBox/WorkspaceStatusLabel
@onready var footer_row: HBoxContainer = $Panel/MarginContainer/RootVBox/FooterRow
@onready var close_button: Button = $Panel/MarginContainer/RootVBox/FooterRow/CloseButton

const MATERIAL_PLACEHOLDER_ICON_PATH := "res://assets/ui_v2/material_placeholder_icon.png"
const MATERIAL_ICON_BUTTON_SIZE := Vector2(56, 56)
const COMPACT_LAYOUT_WIDTH := 1180.0
const COMPACT_LAYOUT_HEIGHT := 700.0
const ULTRA_COMPACT_LAYOUT_WIDTH := 860.0
const ULTRA_COMPACT_LAYOUT_HEIGHT := 560.0
const UI_FIT_SCALE_MIN := 0.58
const UI_FIT_PADDING_PX := 2.0
const WORKSPACE_VIEWPORT_ASPECT := 16.0 / 9.0
const MENU_ID_BASE := 1000
const PROFILE_BUILDER_MENU_ID_BASE := 50000
const WORKSPACE_ZOOM_STEP := 0.1
const SPLINE_POINT_SCREEN_PICK_RADIUS_PIXELS := 26.0
const PROFILE_BUILDER_POPUP_SIZE := Vector2i(960, 560)
const PROFILE_BUILDER_PREVIEW_SIZE := Vector2(420, 420)
const PROFILE_CANVAS_CONTEXT_POPUP_WIDTH := 148
const PROFILE_FILLET_DIALOG_SIZE := Vector2i(280, 178)
const PROFILE_BUILDER_SIZE_MIN_METERS := ForgeV2ProfileShapeLibraryScript.DEFAULT_CELL_WORLD_SIZE_METERS
const PROFILE_BUILDER_SIZE_MAX_METERS := 4.0

var active_player = null
var active_stage_controller: Node = null
var active_placement_space: Node3D = null
var current_bench_name: String = ""
var is_refreshing_ui: bool = false
var material_icon_texture: Texture2D = null
var workspace_preview: Node3D = null
var body_layout_hbox: HBoxContainer = null
var action_host_row: HBoxContainer = null
var draft_menu_button: MenuButton = null
var build_menu_button: MenuButton = null
var material_menu_button: MenuButton = null
var shape_menu_button: MenuButton = null
var profiles_button: Button = null
var layers_menu_button: MenuButton = null
var view_menu_button: MenuButton = null
var status_menu_button: MenuButton = null
var settings_button: Button = null
var action_status_label: Label = null
var keybinding_state: Resource = null
var settings_popup: PopupPanel = null
var freehand_smoothing_slider: HSlider = null
var freehand_smoothing_value_label: Label = null
var profile_builder_popup: PopupPanel = null
var profile_builder_basic_menu_button: MenuButton = null
var profile_builder_handle_button: Button = null
var profile_builder_saved_profiles_button: Button = null
var profile_saved_profiles_popup: PopupPanel = null
var profile_saved_profiles_item_list: ItemList = null
var profile_saved_profiles_context_panel: PopupPanel = null
var profile_canvas_context_panel: PopupPanel = null
var profile_canvas_context_target_kind: StringName = StringName()
var profile_canvas_context_target_index: int = -1
var profile_canvas_context_target_id: StringName = StringName()
var profile_canvas_context_target_position_meters: Vector2 = Vector2.ZERO
var profile_fillet_popup: PopupPanel = null
var profile_fillet_spin_box: SpinBox = null
var profile_fillet_pending_corner_id: StringName = StringName()
var profile_fillet_restore_profile_builder: bool = false
var profile_builder_preview: Control = null
var profile_metric_scale_ruler: Control = null
var profile_builder_metric_pan_active := false
var profile_builder_metric_pan_mouse_button := MOUSE_BUTTON_NONE
var profile_width_spin_box: SpinBox = null
var profile_height_spin_box: SpinBox = null
var profile_anchor_x_spin_box: SpinBox = null
var profile_anchor_y_spin_box: SpinBox = null
var profile_rotation_spin_box: SpinBox = null
var profile_rotation_slider: HSlider = null
var profile_handle_face_count_option: OptionButton = null
var profile_handle_rounded_check_box: CheckBox = null
var profile_handle_corner_radius_spin_box: SpinBox = null
var profile_handle_corner_radius_slider: HSlider = null
var profile_save_button: Button = null
var profile_grid_snap_check_box: CheckBox = null
var profile_name_popup: PopupPanel = null
var profile_name_line_edit: LineEdit = null
var profile_name_popup_title: Label = null
var profile_name_pending_action: StringName = StringName()
var profile_name_pending_profile_id: StringName = StringName()
var profile_name_restore_profile_builder: bool = false
var profile_name_restore_saved_profiles: bool = false
var tool_profile_library_state: Resource = null
var active_saved_profile_id: StringName = StringName()
var profile_saved_profiles_context_profile_id: StringName = StringName()
var profile_saved_profile_ids_by_index: Array[StringName] = []
var keybindings_popup: PopupPanel = null
var keybindings_list_vbox: VBoxContainer = null
var keybinding_buttons_by_action: Dictionary = {}
var keybinding_capture_action: StringName = StringName()
var keybinding_capture_button: Button = null
var keybinding_capture_keyboard_data: Dictionary = {}
var is_refreshing_settings_ui: bool = false
var is_refreshing_profile_builder_ui: bool = false
var menu_action_lookup: Dictionary = {}
var menu_next_id: int = MENU_ID_BASE
var profile_builder_action_lookup: Dictionary = {}
var profile_builder_next_id: int = PROFILE_BUILDER_MENU_ID_BASE
var last_ui_fit_scale := 1.0
var workspace_frame_host: Control = null
var workspace_drag_active := false
var workspace_drag_pan_mode := false
var workspace_brush_stroke_active := false
var workspace_spline_point_drag_active := false
var workspace_spline_drag_point_index := -1
var workspace_spline_drag_plane_origin_local: Vector3 = Vector3.ZERO
var workspace_spline_drag_plane_normal_local: Vector3 = Vector3.FORWARD

func _ready() -> void:
	visible = false
	panel.visible = false
	UiWindowLayerPolicyScript.configure_visual_input_surface(panel)
	material_icon_texture = _load_material_icon_texture()
	_ensure_keybinding_state()
	_ensure_tool_profile_library_state()
	_ensure_top_action_bar()
	_ensure_workspace_frame_host()
	_ensure_fullscreen_workspace_layout()
	new_draft_button.pressed.connect(_on_new_draft_pressed)
	clear_strokes_button.pressed.connect(_on_clear_strokes_pressed)
	builder_path_option.item_selected.connect(_on_builder_path_selected)
	builder_component_option.item_selected.connect(_on_builder_component_selected)
	operation_option.item_selected.connect(_on_operation_selected)
	placement_policy_option.item_selected.connect(_on_placement_policy_selected)
	primitive_option.item_selected.connect(_on_primitive_selected)
	radius_decrease_button.pressed.connect(_on_radius_decrease_pressed)
	radius_increase_button.pressed.connect(_on_radius_increase_pressed)
	add_empty_stroke_button.pressed.connect(_on_add_empty_stroke_pressed)
	commit_pending_button.pressed.connect(_on_commit_pending_pressed)
	undo_layer_button.pressed.connect(_on_undo_layer_pressed)
	redo_layer_button.pressed.connect(_on_redo_layer_pressed)
	body_stack_option.item_selected.connect(_on_body_stack_selected)
	delete_selected_body_button.pressed.connect(_on_delete_selected_body_pressed)
	workspace_view_container.gui_input.connect(_on_workspace_view_gui_input)
	workspace_view_container.mouse_exited.connect(_on_workspace_view_mouse_exited)
	workspace_view_container.resized.connect(_sync_workspace_subviewport_size)
	close_button.pressed.connect(close_ui)
	_ensure_workspace_preview()
	get_viewport().size_changed.connect(_apply_fullscreen_workspace_layout)
	call_deferred("_sync_workspace_subviewport_size")

func toggle_start_menu_for(player, stage_controller: Node, bench_name: String, placement_space: Node3D = null) -> void:
	if is_open():
		close_ui()
		return
	open_for(player, stage_controller, bench_name, placement_space)

func toggle_for(player, stage_controller: Node, bench_name: String, placement_space: Node3D = null) -> void:
	toggle_start_menu_for(player, stage_controller, bench_name, placement_space)

func open_for(player, stage_controller: Node, bench_name: String, placement_space: Node3D = null) -> void:
	active_player = player
	active_stage_controller = stage_controller
	active_placement_space = placement_space
	current_bench_name = bench_name
	title_label.text = "%s Forge Station V2" % current_bench_name
	subtitle_label.text = "Stage 1 V2 authoring surface"
	_connect_stage_controller()
	if active_stage_controller != null:
		active_stage_controller.ensure_authoring_state("%s V2 Draft" % current_bench_name)
	_ensure_workspace_preview()
	if workspace_preview != null and workspace_preview.has_method("bind_stage_controller"):
		workspace_preview.call("bind_stage_controller", active_stage_controller)
	call_deferred("_sync_workspace_subviewport_size")
	_configure_options_from_controller()
	_refresh_from_controller()
	visible = true
	panel.visible = true
	if active_player != null and active_player.has_method("set_ui_mode_enabled"):
		active_player.call("set_ui_mode_enabled", true)

func close_ui() -> void:
	if not is_open():
		return
	if workspace_brush_stroke_active:
		_finish_workspace_brush_stroke(Vector2.ZERO, false)
	_finish_workspace_spline_point_drag()
	_close_profile_fillet_popup(false)
	_hide_profile_canvas_context_menu()
	_close_keybindings_popup()
	_close_settings_popup()
	_close_profile_builder_popup()
	_close_profile_saved_profiles_popup()
	_close_profile_name_popup(false)
	panel.visible = false
	visible = false
	if active_player != null and active_player.has_method("set_ui_mode_enabled"):
		active_player.call("set_ui_mode_enabled", false)
	_disconnect_stage_controller()
	if workspace_preview != null and workspace_preview.has_method("clear_stage_controller"):
		workspace_preview.call("clear_stage_controller")
	workspace_drag_active = false
	workspace_brush_stroke_active = false
	workspace_spline_point_drag_active = false
	workspace_spline_drag_point_index = -1
	active_player = null
	active_stage_controller = null
	active_placement_space = null
	current_bench_name = ""
	closed.emit()

func is_open() -> bool:
	return panel.visible

func _ensure_top_action_bar() -> void:
	if root_vbox == null:
		return
	action_host_row = root_vbox.get_node_or_null("V2ActionHostRow") as HBoxContainer
	if action_host_row == null:
		action_host_row = HBoxContainer.new()
		action_host_row.name = "V2ActionHostRow"
		action_host_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_host_row.add_theme_constant_override("separation", 6)
		root_vbox.add_child(action_host_row)
	var target_index: int = header_vbox.get_index() + 1 if header_vbox != null else 0
	root_vbox.move_child(action_host_row, target_index)
	draft_menu_button = _ensure_action_menu_button("DraftMenuButton", "Draft")
	build_menu_button = _ensure_action_menu_button("BuildMenuButton", "Build")
	material_menu_button = _ensure_action_menu_button("MaterialMenuButton", "Material")
	shape_menu_button = _ensure_action_menu_button("ShapeMenuButton", "Shape")
	profiles_button = _ensure_action_button("ProfilesButton", "Profiles", Callable(self, "_open_profile_builder_popup"))
	layers_menu_button = _ensure_action_menu_button("LayersMenuButton", "Layers")
	view_menu_button = _ensure_action_menu_button("ViewMenuButton", "View")
	status_menu_button = _ensure_action_menu_button("StatusMenuButton", "Status")
	settings_button = _ensure_action_button("SettingsButton", "Settings", Callable(self, "_open_settings_popup"))
	_configure_v2_increment_popup(shape_menu_button.get_popup())
	action_status_label = action_host_row.get_node_or_null("ActionStatusLabel") as Label
	if action_status_label == null:
		action_status_label = Label.new()
		action_status_label.name = "ActionStatusLabel"
		action_host_row.add_child(action_status_label)
	action_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	action_status_label.clip_text = true
	if close_button != null:
		if close_button.get_parent() != action_host_row:
			close_button.reparent(action_host_row)
		close_button.text = "Close"
		close_button.custom_minimum_size = Vector2(92.0, 30.0)
	if footer_row != null:
		footer_row.visible = false
	_rebuild_v2_action_menus()

func _ensure_action_button(button_name: String, button_text: String, pressed_callback: Callable) -> Button:
	var button := action_host_row.get_node_or_null(button_name) as Button
	if button == null:
		button = Button.new()
		button.name = button_name
		action_host_row.add_child(button)
	button.text = button_text
	button.custom_minimum_size = Vector2(82.0, 30.0)
	button.focus_mode = Control.FOCUS_NONE
	if pressed_callback.is_valid() and not button.pressed.is_connected(pressed_callback):
		button.pressed.connect(pressed_callback)
	return button

func _ensure_action_menu_button(button_name: String, button_text: String) -> MenuButton:
	var button := action_host_row.get_node_or_null(button_name) as MenuButton
	if button == null:
		button = MenuButton.new()
		button.name = button_name
		action_host_row.add_child(button)
	button.text = button_text
	button.custom_minimum_size = Vector2(82.0, 30.0)
	button.switch_on_hover = true
	button.focus_mode = Control.FOCUS_NONE
	_connect_v2_popup(button.get_popup())
	return button

func _apply_margin(container: MarginContainer, margin_px: int) -> void:
	if container == null:
		return
	container.add_theme_constant_override("margin_left", margin_px)
	container.add_theme_constant_override("margin_top", margin_px)
	container.add_theme_constant_override("margin_right", margin_px)
	container.add_theme_constant_override("margin_bottom", margin_px)

func _configure_major_workspace_popup(popup: PopupPanel) -> void:
	UiWindowLayerPolicyScript.configure_major_workspace(popup)

func _apply_v2_popup_theme(control) -> void:
	if control == null:
		return
	control.add_theme_stylebox_override("panel", _build_v2_popup_panel_style())

func _build_v2_popup_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.052, 0.058, 1.0)
	style.border_color = Color(0.19, 0.24, 0.26, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style

func _apply_v2_header_layout(compact_layout: bool, ultra_compact_layout: bool) -> void:
	if header_vbox == null:
		return
	header_vbox.visible = not compact_layout
	header_vbox.add_theme_constant_override("separation", 2 if compact_layout else 6)
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", 16 if compact_layout else 20)
		title_label.clip_text = true
	if subtitle_label != null:
		subtitle_label.visible = not compact_layout

func _apply_v2_action_bar_layout(compact_layout: bool, ultra_compact_layout: bool) -> void:
	if action_host_row == null:
		return
	var menu_width: float = 50.0 if ultra_compact_layout else 68.0 if compact_layout else 82.0
	var menu_height: float = 26.0 if ultra_compact_layout else 28.0 if compact_layout else 30.0
	var button_entries: Array[Dictionary] = [
		{"button": draft_menu_button, "wide": "Draft", "compact": "Draft", "ultra": "Dft"},
		{"button": build_menu_button, "wide": "Build", "compact": "Build", "ultra": "Bld"},
		{"button": material_menu_button, "wide": "Material", "compact": "Mat", "ultra": "Mat"},
		{"button": shape_menu_button, "wide": "Shape", "compact": "Shape", "ultra": "Shp"},
		{"button": profiles_button, "wide": "Profiles", "compact": "Prof", "ultra": "Prf"},
		{"button": layers_menu_button, "wide": "Layers", "compact": "Layers", "ultra": "Lyr"},
		{"button": view_menu_button, "wide": "View", "compact": "View", "ultra": "View"},
		{"button": status_menu_button, "wide": "Status", "compact": "Info", "ultra": "Info"},
		{"button": settings_button, "wide": "Settings", "compact": "Set", "ultra": "Set"},
	]
	for entry: Dictionary in button_entries:
		var button := entry.get("button", null) as Button
		if button == null:
			continue
		button.text = String(entry.get("ultra" if ultra_compact_layout else "compact" if compact_layout else "wide", "Menu"))
		button.custom_minimum_size = Vector2(menu_width, menu_height)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	action_host_row.add_theme_constant_override("separation", 2 if ultra_compact_layout else 4 if compact_layout else 6)
	action_host_row.custom_minimum_size = Vector2.ZERO
	if action_status_label != null:
		action_status_label.visible = not compact_layout
		action_status_label.custom_minimum_size = Vector2.ZERO
		action_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if close_button != null:
		close_button.text = "X" if compact_layout else "Close"
		close_button.custom_minimum_size = Vector2(36.0 if ultra_compact_layout else 54.0 if compact_layout else 92.0, menu_height)

func _apply_v2_workspace_chrome_layout(compact_layout: bool) -> void:
	if workspace_title_label != null:
		workspace_title_label.visible = false
	if workspace_status_label != null:
		workspace_status_label.visible = not compact_layout
	if workspace_vbox != null:
		workspace_vbox.add_theme_constant_override("separation", 0 if compact_layout else 4)

func _ensure_workspace_frame_host() -> void:
	if workspace_vbox == null or workspace_view_container == null:
		return
	workspace_frame_host = workspace_vbox.get_node_or_null("WorkspaceFrameHost") as Control
	if workspace_frame_host == null:
		workspace_frame_host = Control.new()
		workspace_frame_host.name = "WorkspaceFrameHost"
		workspace_frame_host.clip_contents = true
		workspace_vbox.add_child(workspace_frame_host)
	workspace_frame_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_frame_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_frame_host.custom_minimum_size = Vector2.ZERO
	if workspace_view_container.get_parent() != workspace_frame_host:
		workspace_view_container.reparent(workspace_frame_host)
	workspace_view_container.custom_minimum_size = Vector2.ZERO
	workspace_view_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	workspace_view_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	workspace_view_container.mouse_filter = Control.MOUSE_FILTER_STOP
	var target_index := 1 if workspace_title_label != null else 0
	workspace_vbox.move_child(workspace_frame_host, mini(target_index, workspace_vbox.get_child_count() - 1))
	if workspace_status_label != null:
		workspace_vbox.move_child(workspace_status_label, workspace_vbox.get_child_count() - 1)
	if not workspace_frame_host.resized.is_connected(_sync_workspace_frame_layout):
		workspace_frame_host.resized.connect(_sync_workspace_frame_layout)
	call_deferred("_sync_workspace_frame_layout")

func _sync_workspace_frame_layout() -> void:
	if workspace_frame_host == null or workspace_view_container == null:
		return
	var available_size: Vector2 = workspace_frame_host.size
	if available_size.x <= 1.0 or available_size.y <= 1.0:
		return
	var target_size := Vector2(available_size.x, available_size.x / WORKSPACE_VIEWPORT_ASPECT)
	if target_size.y > available_size.y:
		target_size.y = available_size.y
		target_size.x = target_size.y * WORKSPACE_VIEWPORT_ASPECT
	target_size.x = maxf(floor(target_size.x), 1.0)
	target_size.y = maxf(floor(target_size.y), 1.0)
	var target_subviewport_size := Vector2i(int(target_size.x), int(target_size.y))
	if workspace_subviewport != null and workspace_subviewport.size != target_subviewport_size:
		workspace_subviewport.size = target_subviewport_size
	workspace_view_container.position = ((available_size - target_size) * 0.5).floor()
	workspace_view_container.size = target_size
	_sync_workspace_subviewport_size()

func _apply_v2_fit_scale(viewport_size: Vector2) -> void:
	if panel == null or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var minimum_size: Vector2 = panel.get_combined_minimum_size()
	minimum_size.x = maxf(minimum_size.x, 1.0)
	minimum_size.y = maxf(minimum_size.y, 1.0)
	var available_size := Vector2(
		maxf(viewport_size.x - UI_FIT_PADDING_PX, 1.0),
		maxf(viewport_size.y - UI_FIT_PADDING_PX, 1.0)
	)
	var fit_scale: float = minf(1.0, minf(
		available_size.x / minimum_size.x,
		available_size.y / minimum_size.y
	))
	fit_scale = clampf(fit_scale, UI_FIT_SCALE_MIN, 1.0)
	last_ui_fit_scale = fit_scale
	panel.scale = Vector2(fit_scale, fit_scale)
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = (viewport_size.x / fit_scale) - viewport_size.x
	panel.offset_bottom = (viewport_size.y / fit_scale) - viewport_size.y

func _connect_v2_popup(popup: PopupMenu) -> void:
	if popup == null:
		return
	_apply_v2_popup_theme(popup)
	if not popup.id_pressed.is_connected(_on_v2_menu_id_pressed):
		popup.id_pressed.connect(_on_v2_menu_id_pressed)

func _connect_profile_builder_popup_menu(popup: PopupMenu) -> void:
	if popup == null:
		return
	_apply_v2_popup_theme(popup)
	if not popup.id_pressed.is_connected(_on_profile_builder_menu_id_pressed):
		popup.id_pressed.connect(_on_profile_builder_menu_id_pressed)

func _configure_v2_increment_popup(popup: PopupMenu) -> void:
	if popup == null:
		return
	popup.hide_on_item_selection = false
	popup.hide_on_checkable_item_selection = false

func _ensure_keybinding_state() -> Resource:
	if keybinding_state == null:
		keybinding_state = ForgeV2KeybindingStateScript.load_or_create()
	return keybinding_state

func _ensure_tool_profile_library_state() -> Resource:
	if tool_profile_library_state == null:
		tool_profile_library_state = PlayerToolProfileLibraryStateScript.load_or_create()
	return tool_profile_library_state

func _get_saved_handle_profiles() -> Array:
	return _get_saved_profiles_for_family(ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE)

func _get_saved_basic_profiles() -> Array:
	return _get_saved_profiles_for_family(ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC)

func _get_saved_profiles_for_family(profile_family: StringName) -> Array:
	var profile_library: Resource = _ensure_tool_profile_library_state()
	if profile_library == null or not profile_library.has_method("get_saved_profiles"):
		return []
	return profile_library.call(
		"get_saved_profiles",
		profile_family
	) as Array

func _get_saved_profiles_for_active_builder_family() -> Array:
	return _get_saved_profiles_for_family(_resolve_active_profile_builder_family())

func _resolve_active_profile_builder_family() -> StringName:
	if active_stage_controller == null or not active_stage_controller.has_method("get_status_summary"):
		return ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC
	var summary: Dictionary = active_stage_controller.call("get_status_summary") as Dictionary
	var profile_settings: Dictionary = summary.get("active_profile_settings", {}) as Dictionary
	var profile_builder_settings: Dictionary = profile_settings.get("profile_builder", {}) as Dictionary
	var builder_family := StringName(profile_builder_settings.get("family", StringName()))
	if builder_family != StringName():
		return builder_family
	return (
		ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE
		if StringName(summary.get("active_tool", StringName())) == &"tool_handles"
		else ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC
	)

func _ensure_settings_popup() -> void:
	if is_instance_valid(settings_popup):
		return
	settings_popup = PopupPanel.new()
	settings_popup.name = "V2SettingsPopup"
	settings_popup.visible = false
	settings_popup.unresizable = true
	_configure_major_workspace_popup(settings_popup)
	_apply_v2_popup_theme(settings_popup)
	add_child(settings_popup)

	var popup_margin := MarginContainer.new()
	popup_margin.name = "SettingsMargin"
	_apply_margin(popup_margin, 12)
	settings_popup.add_child(popup_margin)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.name = "SettingsVBox"
	popup_vbox.add_theme_constant_override("separation", 12)
	popup_margin.add_child(popup_vbox)

	var header_row := HBoxContainer.new()
	header_row.name = "SettingsHeaderRow"
	header_row.add_theme_constant_override("separation", 8)
	popup_vbox.add_child(header_row)

	var title := Label.new()
	title.name = "SettingsTitle"
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	var settings_close_button := Button.new()
	settings_close_button.name = "SettingsCloseButton"
	settings_close_button.text = "X"
	settings_close_button.custom_minimum_size = Vector2(34.0, 28.0)
	settings_close_button.focus_mode = Control.FOCUS_NONE
	settings_close_button.pressed.connect(_close_settings_popup)
	header_row.add_child(settings_close_button)

	var smoothing_row := HBoxContainer.new()
	smoothing_row.name = "FreehandSmoothingRow"
	smoothing_row.add_theme_constant_override("separation", 10)
	popup_vbox.add_child(smoothing_row)

	var smoothing_label := Label.new()
	smoothing_label.name = "FreehandSmoothingLabel"
	smoothing_label.text = "Freehand Smoothing"
	smoothing_label.custom_minimum_size = Vector2(168.0, 0.0)
	smoothing_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	smoothing_row.add_child(smoothing_label)

	freehand_smoothing_slider = HSlider.new()
	freehand_smoothing_slider.name = "FreehandSmoothingSlider"
	freehand_smoothing_slider.min_value = 0.0
	freehand_smoothing_slider.max_value = 10.0
	freehand_smoothing_slider.step = 1.0
	freehand_smoothing_slider.rounded = true
	freehand_smoothing_slider.tick_count = 11
	freehand_smoothing_slider.ticks_on_borders = true
	freehand_smoothing_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	freehand_smoothing_slider.custom_minimum_size = Vector2(210.0, 0.0)
	freehand_smoothing_slider.value_changed.connect(_on_freehand_smoothing_value_changed)
	smoothing_row.add_child(freehand_smoothing_slider)

	freehand_smoothing_value_label = Label.new()
	freehand_smoothing_value_label.name = "FreehandSmoothingValueLabel"
	freehand_smoothing_value_label.custom_minimum_size = Vector2(36.0, 0.0)
	freehand_smoothing_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	freehand_smoothing_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	freehand_smoothing_value_label.text = "0"
	smoothing_row.add_child(freehand_smoothing_value_label)

	var keybindings_button := Button.new()
	keybindings_button.name = "OpenKeybindingsButton"
	keybindings_button.text = "Keybindings"
	keybindings_button.custom_minimum_size = Vector2(160.0, 32.0)
	keybindings_button.focus_mode = Control.FOCUS_NONE
	keybindings_button.pressed.connect(_open_keybindings_popup)
	popup_vbox.add_child(keybindings_button)

func _ensure_profile_builder_popup() -> void:
	if is_instance_valid(profile_builder_popup):
		return
	profile_builder_popup = PopupPanel.new()
	profile_builder_popup.name = "V2ProfileBuilderPopup"
	profile_builder_popup.visible = false
	profile_builder_popup.unresizable = true
	_configure_major_workspace_popup(profile_builder_popup)
	_apply_v2_popup_theme(profile_builder_popup)
	add_child(profile_builder_popup)
	profile_builder_popup.popup_hide.connect(_on_profile_builder_popup_hidden)

	var popup_margin := MarginContainer.new()
	popup_margin.name = "ProfileBuilderMargin"
	_apply_margin(popup_margin, 12)
	profile_builder_popup.add_child(popup_margin)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.name = "ProfileBuilderVBox"
	popup_vbox.custom_minimum_size = Vector2(float(PROFILE_BUILDER_POPUP_SIZE.x), float(PROFILE_BUILDER_POPUP_SIZE.y))
	popup_vbox.add_theme_constant_override("separation", 10)
	popup_margin.add_child(popup_vbox)

	var header_row := HBoxContainer.new()
	header_row.name = "ProfileBuilderHeaderRow"
	header_row.add_theme_constant_override("separation", 8)
	popup_vbox.add_child(header_row)

	var title := Label.new()
	title.name = "ProfileBuilderTitle"
	title.text = "Profiles"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	var close_button_local := Button.new()
	close_button_local.name = "ProfileBuilderCloseButton"
	close_button_local.text = "X"
	close_button_local.custom_minimum_size = Vector2(34.0, 28.0)
	close_button_local.focus_mode = Control.FOCUS_NONE
	close_button_local.pressed.connect(_close_profile_builder_popup)
	header_row.add_child(close_button_local)

	var internal_menu_row := HBoxContainer.new()
	internal_menu_row.name = "ProfileBuilderInternalMenuRow"
	internal_menu_row.add_theme_constant_override("separation", 6)
	popup_vbox.add_child(internal_menu_row)

	profile_builder_basic_menu_button = _build_profile_builder_menu_button("BasicProfileMenuButton", "2D Profiles")
	internal_menu_row.add_child(profile_builder_basic_menu_button)
	profile_builder_handle_button = _build_profile_builder_button("HandleProfileButton", "Handles", _on_profile_handles_button_pressed)
	internal_menu_row.add_child(profile_builder_handle_button)
	profile_builder_saved_profiles_button = _build_profile_builder_button("SavedProfileButton", "Saved Profiles", _open_profile_saved_profiles_popup)
	internal_menu_row.add_child(profile_builder_saved_profiles_button)

	var content_row := HBoxContainer.new()
	content_row.name = "ProfileBuilderContentRow"
	content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 12)
	popup_vbox.add_child(content_row)

	var preview_column := VBoxContainer.new()
	preview_column.name = "ProfilePreviewColumn"
	preview_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	preview_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	preview_column.add_theme_constant_override("separation", 8)
	content_row.add_child(preview_column)

	profile_builder_preview = ProfileBuilderPreviewControl.new()
	profile_builder_preview.name = "ProfilePreview"
	profile_builder_preview.custom_minimum_size = PROFILE_BUILDER_PREVIEW_SIZE
	profile_builder_preview.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	profile_builder_preview.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	profile_builder_preview.control_point_dragged.connect(_on_profile_control_point_dragged)
	profile_builder_preview.control_point_drag_finished.connect(_on_profile_control_point_drag_finished)
	profile_builder_preview.anchor_point_dragged.connect(_on_profile_anchor_point_dragged)
	profile_builder_preview.anchor_point_drag_finished.connect(_on_profile_anchor_point_drag_finished)
	profile_builder_preview.anchor_point_reset_requested.connect(_on_profile_anchor_point_reset_requested)
	profile_builder_preview.canvas_context_requested.connect(
		_on_profile_canvas_context_requested
	)
	profile_builder_preview.canvas_context_dismiss_requested.connect(
		_hide_profile_canvas_context_menu
	)
	profile_builder_preview.set_metric_view_input_handler(
		Callable(self, "_handle_profile_builder_metric_view_input")
	)
	profile_builder_preview.mouse_exited.connect(_cancel_profile_builder_metric_pan)
	preview_column.add_child(profile_builder_preview)

	profile_metric_scale_ruler = MetricScaleRulerControlScript.new()
	profile_metric_scale_ruler.name = "MetricScaleRuler"
	profile_metric_scale_ruler.visible = false
	profile_builder_preview.add_child(profile_metric_scale_ruler)
	profile_builder_preview.call("attach_metric_scale_ruler", profile_metric_scale_ruler)

	var preview_action_row := HBoxContainer.new()
	preview_action_row.name = "ProfilePreviewActionRow"
	preview_action_row.add_theme_constant_override("separation", 8)
	preview_column.add_child(preview_action_row)

	profile_save_button = Button.new()
	profile_save_button.name = "SaveProfileButton"
	profile_save_button.text = "Save Profile"
	profile_save_button.custom_minimum_size = Vector2(160.0, 32.0)
	profile_save_button.focus_mode = Control.FOCUS_NONE
	profile_save_button.pressed.connect(_on_profile_save_button_pressed)
	preview_action_row.add_child(profile_save_button)

	profile_grid_snap_check_box = CheckBox.new()
	profile_grid_snap_check_box.name = "GridSnappingCheckBox"
	profile_grid_snap_check_box.text = "Grid snapping"
	profile_grid_snap_check_box.focus_mode = Control.FOCUS_NONE
	profile_grid_snap_check_box.toggled.connect(_on_profile_grid_snapping_toggled)
	preview_action_row.add_child(profile_grid_snap_check_box)

	var preview_action_spacer := Control.new()
	preview_action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_action_row.add_child(preview_action_spacer)

	var adjuster_panel := PanelContainer.new()
	adjuster_panel.name = "ProfileAdjusterPanel"
	adjuster_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adjuster_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(adjuster_panel)

	var adjuster_margin := MarginContainer.new()
	adjuster_margin.name = "ProfileAdjusterMargin"
	_apply_margin(adjuster_margin, 10)
	adjuster_panel.add_child(adjuster_margin)

	var adjuster_scroll := ScrollContainer.new()
	adjuster_scroll.name = "ProfileAdjusterScroll"
	adjuster_scroll.custom_minimum_size = Vector2(400.0, PROFILE_BUILDER_PREVIEW_SIZE.y)
	adjuster_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adjuster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	adjuster_margin.add_child(adjuster_scroll)

	var adjuster_vbox := VBoxContainer.new()
	adjuster_vbox.name = "ProfileAdjusterVBox"
	adjuster_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adjuster_vbox.add_theme_constant_override("separation", 12)
	adjuster_scroll.add_child(adjuster_vbox)

	profile_width_spin_box = _add_profile_meter_adjuster(
		adjuster_vbox,
		"Width",
		"Width in meters for the selected 2D profile before extrusion."
	)
	profile_width_spin_box.value_changed.connect(_on_profile_width_value_changed)
	profile_height_spin_box = _add_profile_meter_adjuster(
		adjuster_vbox,
		"Height",
		"Height in meters for the selected 2D profile before extrusion."
	)
	profile_height_spin_box.value_changed.connect(_on_profile_height_value_changed)
	_add_profile_handle_builder_adjusters(adjuster_vbox)
	profile_anchor_x_spin_box = _add_profile_meter_adjuster(
		adjuster_vbox,
		"Anchor X",
		"Horizontal offset in meters between the cursor point and the profile center."
	)
	profile_anchor_x_spin_box.min_value = -PROFILE_BUILDER_SIZE_MAX_METERS
	profile_anchor_x_spin_box.value_changed.connect(_on_profile_anchor_x_value_changed)
	profile_anchor_y_spin_box = _add_profile_meter_adjuster(
		adjuster_vbox,
		"Anchor Y",
		"Vertical offset in meters between the cursor point and the profile center."
	)
	profile_anchor_y_spin_box.min_value = -PROFILE_BUILDER_SIZE_MAX_METERS
	profile_anchor_y_spin_box.value_changed.connect(_on_profile_anchor_y_value_changed)
	_add_profile_rotation_adjuster(adjuster_vbox)

func _ensure_profile_name_popup() -> void:
	if is_instance_valid(profile_name_popup):
		return
	_ensure_profile_builder_popup()
	profile_name_popup = PopupPanel.new()
	profile_name_popup.name = "V2ProfileNamePopup"
	profile_name_popup.visible = false
	profile_name_popup.unresizable = true
	_apply_v2_popup_theme(profile_name_popup)
	UiWindowLayerPolicyScript.attach_owned_popup(
		profile_builder_popup,
		profile_name_popup
	)

	var popup_margin := MarginContainer.new()
	popup_margin.name = "ProfileNameMargin"
	_apply_margin(popup_margin, 12)
	profile_name_popup.add_child(popup_margin)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.name = "ProfileNameVBox"
	popup_vbox.add_theme_constant_override("separation", 10)
	popup_margin.add_child(popup_vbox)

	profile_name_popup_title = Label.new()
	profile_name_popup_title.name = "ProfileNameTitle"
	profile_name_popup_title.text = "Save Profile"
	profile_name_popup_title.add_theme_font_size_override("font_size", 18)
	popup_vbox.add_child(profile_name_popup_title)

	profile_name_line_edit = LineEdit.new()
	profile_name_line_edit.name = "ProfileNameLineEdit"
	profile_name_line_edit.max_length = PlayerToolProfileLibraryStateScript.PROFILE_NAME_MAX_LENGTH
	profile_name_line_edit.custom_minimum_size = Vector2(360.0, 32.0)
	profile_name_line_edit.text_submitted.connect(func(_text: String) -> void: _confirm_profile_name_popup())
	popup_vbox.add_child(profile_name_line_edit)

	var button_row := HBoxContainer.new()
	button_row.name = "ProfileNameButtonRow"
	button_row.add_theme_constant_override("separation", 8)
	popup_vbox.add_child(button_row)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(spacer)

	var cancel_button := Button.new()
	cancel_button.name = "CancelButton"
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(90.0, 30.0)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(_close_profile_name_popup)
	button_row.add_child(cancel_button)

	var confirm_button := Button.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.text = "Save"
	confirm_button.custom_minimum_size = Vector2(90.0, 30.0)
	confirm_button.focus_mode = Control.FOCUS_NONE
	confirm_button.pressed.connect(_confirm_profile_name_popup)
	button_row.add_child(confirm_button)

func _build_profile_builder_menu_button(button_name: String, button_text: String) -> MenuButton:
	var button := MenuButton.new()
	button.name = button_name
	button.text = button_text
	button.custom_minimum_size = Vector2(112.0, 28.0)
	button.switch_on_hover = true
	button.focus_mode = Control.FOCUS_NONE
	_connect_profile_builder_popup_menu(button.get_popup())
	return button

func _build_profile_builder_button(button_name: String, button_text: String, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = button_text
	button.custom_minimum_size = Vector2(112.0, 28.0)
	button.focus_mode = Control.FOCUS_NONE
	if pressed_callback.is_valid() and not button.pressed.is_connected(pressed_callback):
		button.pressed.connect(pressed_callback)
	return button

func _add_profile_meter_adjuster(parent: VBoxContainer, title_text: String, description_text: String) -> SpinBox:
	var section := VBoxContainer.new()
	section.name = "%sSection" % title_text.replace(" ", "")
	section.add_theme_constant_override("separation", 4)
	parent.add_child(section)

	var description := Label.new()
	description.name = "Description"
	description.text = description_text
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(description)

	var spin_box := SpinBox.new()
	spin_box.name = "%sSpinBox" % title_text.replace(" ", "")
	spin_box.min_value = PROFILE_BUILDER_SIZE_MIN_METERS
	spin_box.max_value = PROFILE_BUILDER_SIZE_MAX_METERS
	spin_box.step = 0.0001
	spin_box.rounded = false
	spin_box.allow_greater = false
	spin_box.allow_lesser = false
	spin_box.suffix = " m"
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(spin_box)
	return spin_box

func _add_profile_handle_builder_adjusters(parent: VBoxContainer) -> void:
	var face_section := VBoxContainer.new()
	face_section.name = "HandleFaceCountSection"
	face_section.add_theme_constant_override("separation", 4)
	parent.add_child(face_section)

	var face_description := Label.new()
	face_description.name = "Description"
	face_description.text = "Handle control point count for the profile builder."
	face_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	face_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	face_section.add_child(face_description)

	profile_handle_face_count_option = OptionButton.new()
	profile_handle_face_count_option.name = "HandleFaceCountOption"
	profile_handle_face_count_option.add_item("4 points")
	profile_handle_face_count_option.set_item_metadata(0, ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_RECTANGLE)
	profile_handle_face_count_option.add_item("8 points")
	profile_handle_face_count_option.set_item_metadata(1, ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_OCTAGON)
	profile_handle_face_count_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_handle_face_count_option.item_selected.connect(_on_profile_handle_face_count_selected)
	face_section.add_child(profile_handle_face_count_option)

	var rounded_section := VBoxContainer.new()
	rounded_section.name = "HandleRoundedSection"
	rounded_section.add_theme_constant_override("separation", 4)
	parent.add_child(rounded_section)

	var rounded_description := Label.new()
	rounded_description.name = "Description"
	rounded_description.text = "Rounded corners soften the generated handle outline while keeping the control points editable."
	rounded_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rounded_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rounded_section.add_child(rounded_description)

	profile_handle_rounded_check_box = CheckBox.new()
	profile_handle_rounded_check_box.name = "HandleRoundedCheckBox"
	profile_handle_rounded_check_box.text = "Rounded"
	profile_handle_rounded_check_box.button_pressed = true
	profile_handle_rounded_check_box.toggled.connect(_on_profile_handle_rounded_toggled)
	rounded_section.add_child(profile_handle_rounded_check_box)

	var radius_section := VBoxContainer.new()
	radius_section.name = "HandleCornerRadiusSection"
	radius_section.add_theme_constant_override("separation", 4)
	parent.add_child(radius_section)

	var radius_header := HBoxContainer.new()
	radius_header.name = "CornerRadiusHeaderRow"
	radius_header.add_theme_constant_override("separation", 8)
	radius_section.add_child(radius_header)

	var radius_label := Label.new()
	radius_label.name = "CornerRadiusLabel"
	radius_label.text = "Corner radius"
	radius_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	radius_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radius_header.add_child(radius_label)

	profile_handle_corner_radius_spin_box = SpinBox.new()
	profile_handle_corner_radius_spin_box.name = "CornerRadiusSpinBox"
	profile_handle_corner_radius_spin_box.min_value = 0.0
	profile_handle_corner_radius_spin_box.max_value = PROFILE_BUILDER_SIZE_MAX_METERS
	profile_handle_corner_radius_spin_box.step = 0.0001
	profile_handle_corner_radius_spin_box.rounded = false
	profile_handle_corner_radius_spin_box.allow_greater = false
	profile_handle_corner_radius_spin_box.allow_lesser = false
	profile_handle_corner_radius_spin_box.suffix = " m"
	profile_handle_corner_radius_spin_box.custom_minimum_size = Vector2(130.0, 0.0)
	profile_handle_corner_radius_spin_box.value_changed.connect(_on_profile_handle_corner_radius_spin_value_changed)
	radius_header.add_child(profile_handle_corner_radius_spin_box)

	profile_handle_corner_radius_slider = HSlider.new()
	profile_handle_corner_radius_slider.name = "CornerRadiusSlider"
	profile_handle_corner_radius_slider.min_value = 0.0
	profile_handle_corner_radius_slider.max_value = PROFILE_BUILDER_SIZE_MAX_METERS
	profile_handle_corner_radius_slider.step = 0.0001
	profile_handle_corner_radius_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_handle_corner_radius_slider.value_changed.connect(_on_profile_handle_corner_radius_slider_value_changed)
	radius_section.add_child(profile_handle_corner_radius_slider)

func _add_profile_rotation_adjuster(parent: VBoxContainer) -> void:
	var section := VBoxContainer.new()
	section.name = "RotationSection"
	section.add_theme_constant_override("separation", 4)
	parent.add_child(section)

	var header_row := HBoxContainer.new()
	header_row.name = "RotationHeaderRow"
	header_row.add_theme_constant_override("separation", 8)
	section.add_child(header_row)

	var label := Label.new()
	label.name = "RotationLabel"
	label.text = "Rotation"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(label)

	profile_rotation_spin_box = SpinBox.new()
	profile_rotation_spin_box.name = "RotationSpinBox"
	profile_rotation_spin_box.min_value = -360.0
	profile_rotation_spin_box.max_value = 360.0
	profile_rotation_spin_box.step = 1.0
	profile_rotation_spin_box.rounded = true
	profile_rotation_spin_box.allow_greater = false
	profile_rotation_spin_box.allow_lesser = false
	profile_rotation_spin_box.suffix = " deg"
	profile_rotation_spin_box.custom_minimum_size = Vector2(120.0, 0.0)
	profile_rotation_spin_box.value_changed.connect(_on_profile_rotation_spin_value_changed)
	header_row.add_child(profile_rotation_spin_box)

	profile_rotation_slider = HSlider.new()
	profile_rotation_slider.name = "RotationSlider"
	profile_rotation_slider.min_value = -360.0
	profile_rotation_slider.max_value = 360.0
	profile_rotation_slider.step = 1.0
	profile_rotation_slider.rounded = true
	profile_rotation_slider.tick_count = 9
	profile_rotation_slider.ticks_on_borders = true
	profile_rotation_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_rotation_slider.value_changed.connect(_on_profile_rotation_slider_value_changed)
	section.add_child(profile_rotation_slider)

func _ensure_keybindings_popup() -> void:
	if is_instance_valid(keybindings_popup):
		return
	_ensure_settings_popup()
	keybindings_popup = PopupPanel.new()
	keybindings_popup.name = "V2KeybindingsPopup"
	keybindings_popup.visible = false
	keybindings_popup.unresizable = true
	_apply_v2_popup_theme(keybindings_popup)
	UiWindowLayerPolicyScript.attach_owned_popup(
		settings_popup,
		keybindings_popup
	)

	var popup_margin := MarginContainer.new()
	popup_margin.name = "KeybindingsMargin"
	_apply_margin(popup_margin, 12)
	keybindings_popup.add_child(popup_margin)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.name = "KeybindingsVBox"
	popup_vbox.add_theme_constant_override("separation", 10)
	popup_margin.add_child(popup_vbox)

	var header_row := HBoxContainer.new()
	header_row.name = "KeybindingsHeaderRow"
	header_row.add_theme_constant_override("separation", 8)
	popup_vbox.add_child(header_row)

	var title := Label.new()
	title.name = "KeybindingsTitle"
	title.text = "Forge V2 Keybindings"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	var reset_button := Button.new()
	reset_button.name = "ResetKeybindingsButton"
	reset_button.text = "Reset"
	reset_button.custom_minimum_size = Vector2(78.0, 28.0)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(_on_reset_keybindings_pressed)
	header_row.add_child(reset_button)

	var close_button_local := Button.new()
	close_button_local.name = "KeybindingsCloseButton"
	close_button_local.text = "X"
	close_button_local.custom_minimum_size = Vector2(34.0, 28.0)
	close_button_local.focus_mode = Control.FOCUS_NONE
	close_button_local.pressed.connect(_close_keybindings_popup)
	header_row.add_child(close_button_local)

	var scroll := ScrollContainer.new()
	scroll.name = "KeybindingsScroll"
	scroll.custom_minimum_size = Vector2(580.0, 360.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_vbox.add_child(scroll)

	keybindings_list_vbox = VBoxContainer.new()
	keybindings_list_vbox.name = "KeybindingsList"
	keybindings_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keybindings_list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(keybindings_list_vbox)
	_rebuild_keybindings_list()

func _open_settings_popup() -> void:
	_ensure_settings_popup()
	_refresh_settings_popup()
	settings_popup.popup_centered(Vector2i(520, 200))

func _close_settings_popup() -> void:
	_close_keybindings_popup()
	if is_instance_valid(settings_popup):
		settings_popup.hide()

func _open_profile_builder_popup() -> void:
	_ensure_profile_builder_popup()
	_cancel_profile_builder_metric_pan()
	_refresh_profile_builder_popup()
	profile_builder_popup.popup_centered(PROFILE_BUILDER_POPUP_SIZE)

func _close_profile_builder_popup() -> void:
	_cancel_profile_builder_metric_pan()
	_close_profile_name_popup(false)
	_close_profile_fillet_popup(false)
	_hide_profile_canvas_context_menu()
	_close_profile_saved_profiles_popup()
	if is_instance_valid(profile_builder_popup):
		profile_builder_popup.hide()

func _on_profile_builder_popup_hidden() -> void:
	_cancel_profile_builder_metric_pan()
	_hide_profile_canvas_context_menu()
	if profile_fillet_pending_corner_id == StringName():
		_close_profile_fillet_popup(false)

func _ensure_profile_saved_profiles_popup() -> void:
	if is_instance_valid(profile_saved_profiles_popup):
		return
	_ensure_profile_builder_popup()
	profile_saved_profiles_popup = PopupPanel.new()
	profile_saved_profiles_popup.name = "V2SavedProfilesPopup"
	profile_saved_profiles_popup.visible = false
	profile_saved_profiles_popup.unresizable = true
	_apply_v2_popup_theme(profile_saved_profiles_popup)
	UiWindowLayerPolicyScript.attach_owned_popup(
		profile_builder_popup,
		profile_saved_profiles_popup
	)

	var popup_margin := MarginContainer.new()
	popup_margin.name = "SavedProfilesMargin"
	_apply_margin(popup_margin, 8)
	profile_saved_profiles_popup.add_child(popup_margin)

	profile_saved_profiles_item_list = ItemList.new()
	profile_saved_profiles_item_list.name = "SavedProfilesItemList"
	profile_saved_profiles_item_list.custom_minimum_size = Vector2(300.0, 220.0)
	profile_saved_profiles_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_saved_profiles_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	profile_saved_profiles_item_list.select_mode = ItemList.SELECT_SINGLE
	profile_saved_profiles_item_list.allow_reselect = true
	profile_saved_profiles_item_list.allow_rmb_select = true
	profile_saved_profiles_item_list.item_clicked.connect(_on_profile_saved_profile_item_clicked)
	profile_saved_profiles_item_list.gui_input.connect(_on_profile_saved_profiles_list_gui_input)
	popup_margin.add_child(profile_saved_profiles_item_list)

func _build_profile_context_button(button_text: String, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(112.0, 28.0)
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(pressed_callback)
	return button

func _open_profile_saved_profiles_popup() -> void:
	_ensure_profile_saved_profiles_popup()
	_hide_saved_profile_context_menu()
	_refresh_profile_saved_profiles_popup()
	var popup_position := Vector2i.ZERO
	if profile_builder_saved_profiles_button != null:
		popup_position = UiWindowLayerPolicyScript.get_control_bottom_left_screen_position(
			profile_builder_saved_profiles_button
		)
		popup_position.y += 4
	else:
		popup_position = Vector2i(profile_builder_popup.position)
	profile_saved_profiles_popup.popup(Rect2i(popup_position, Vector2i(320, 240)))

func _close_profile_saved_profiles_popup() -> void:
	_hide_saved_profile_context_menu()
	if (
		is_instance_valid(profile_name_popup)
		and profile_name_popup.get_parent() == profile_saved_profiles_popup
	):
		_close_profile_name_popup(false)
	if is_instance_valid(profile_saved_profiles_popup):
		profile_saved_profiles_popup.hide()

func _refresh_profile_saved_profiles_popup() -> void:
	if profile_saved_profiles_item_list == null:
		return
	_hide_saved_profile_context_menu()
	profile_saved_profile_ids_by_index.clear()
	profile_saved_profiles_item_list.clear()
	var saved_profiles: Array = _get_saved_profiles_for_active_builder_family()
	if saved_profiles.is_empty():
		profile_saved_profiles_item_list.add_item("No saved profiles", null, false)
		profile_saved_profiles_item_list.set_item_disabled(0, true)
		return
	for profile_variant: Variant in saved_profiles:
		var profile: Dictionary = profile_variant as Dictionary
		if profile.is_empty():
			continue
		var label := String(profile.get("label", "Unnamed profile"))
		var profile_id := StringName(profile.get("profile_id", StringName()))
		var item_index := profile_saved_profiles_item_list.add_item(label)
		profile_saved_profiles_item_list.set_item_metadata(item_index, profile_id)
		profile_saved_profile_ids_by_index.append(profile_id)
		if profile_id == active_saved_profile_id:
			profile_saved_profiles_item_list.select(item_index)

func _on_profile_saved_profile_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if profile_saved_profiles_item_list == null:
		return
	if index < 0 or index >= profile_saved_profiles_item_list.item_count:
		return
	if profile_saved_profiles_item_list.is_item_disabled(index):
		return
	var profile_id := StringName(profile_saved_profiles_item_list.get_item_metadata(index))
	if profile_id == StringName():
		return
	profile_saved_profiles_item_list.select(index)
	if mouse_button_index == MOUSE_BUTTON_LEFT:
		_hide_saved_profile_context_menu()
		_load_saved_tool_profile(profile_id)
		if is_instance_valid(profile_saved_profiles_popup) and profile_saved_profiles_popup.visible:
			_refresh_profile_saved_profiles_popup()

func _on_profile_saved_profiles_list_gui_input(event: InputEvent) -> void:
	if profile_saved_profiles_item_list == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_hide_saved_profile_context_menu()
			return
		if mouse_event.button_index != MOUSE_BUTTON_RIGHT:
			return
		var item_index := _get_saved_profile_item_index_at_position(mouse_event.position)
		if item_index < 0:
			_hide_saved_profile_context_menu()
			return
		_open_saved_profile_context_menu_for_item_index(item_index)
		profile_saved_profiles_item_list.accept_event()

func _get_saved_profile_item_index_at_position(local_position: Vector2) -> int:
	if profile_saved_profiles_item_list == null:
		return -1
	var item_index := profile_saved_profiles_item_list.get_item_at_position(local_position)
	if item_index < 0 or item_index >= profile_saved_profiles_item_list.item_count:
		return -1
	if profile_saved_profiles_item_list.is_item_disabled(item_index):
		return -1
	return item_index

func _open_saved_profile_context_menu_for_item_index(item_index: int) -> void:
	if profile_saved_profiles_item_list == null:
		return
	if item_index < 0 or item_index >= profile_saved_profiles_item_list.item_count:
		return
	var profile_id := StringName(profile_saved_profiles_item_list.get_item_metadata(item_index))
	if profile_id == StringName():
		return
	profile_saved_profiles_item_list.select(item_index)
	_open_saved_profile_context_menu(profile_id)

func _open_saved_profile_context_menu(profile_id: StringName) -> void:
	if profile_id == StringName():
		return
	_ensure_profile_saved_profiles_popup()
	_hide_saved_profile_context_menu()
	profile_saved_profiles_context_profile_id = profile_id
	profile_saved_profiles_context_panel = _build_saved_profile_context_panel()
	if not UiWindowLayerPolicyScript.attach_owned_popup(
		profile_saved_profiles_popup,
		profile_saved_profiles_context_panel
	):
		profile_saved_profiles_context_panel.queue_free()
		profile_saved_profiles_context_panel = null
		profile_saved_profiles_context_profile_id = StringName()
		return
	var mouse_position := (
		UiWindowLayerPolicyScript.get_control_pointer_screen_position(
			profile_saved_profiles_item_list
		)
	)
	var popup_size := Vector2i(124, 64)
	profile_saved_profiles_context_panel.popup(Rect2i(
		mouse_position,
		popup_size
	))

func _hide_saved_profile_context_menu() -> void:
	profile_saved_profiles_context_profile_id = StringName()
	var context_panel := profile_saved_profiles_context_panel
	profile_saved_profiles_context_panel = null
	if is_instance_valid(context_panel):
		context_panel.hide()
		context_panel.queue_free()

func _build_saved_profile_context_panel() -> PopupPanel:
	var context_panel := PopupPanel.new()
	context_panel.name = "SavedProfileContextPanel"
	context_panel.unresizable = true
	UiWindowLayerPolicyScript.configure_owned_popup(context_panel)
	context_panel.popup_hide.connect(_on_saved_profile_context_popup_hide.bind(context_panel))
	_apply_v2_popup_theme(context_panel)

	var context_margin := MarginContainer.new()
	context_margin.name = "SavedProfileContextMargin"
	_apply_margin(context_margin, 4)
	context_panel.add_child(context_margin)

	var context_vbox := VBoxContainer.new()
	context_vbox.name = "SavedProfileContextVBox"
	context_vbox.add_theme_constant_override("separation", 0)
	context_margin.add_child(context_vbox)

	context_vbox.add_child(_build_profile_context_button("Rename", _on_saved_profile_context_rename_pressed))
	context_vbox.add_child(_build_profile_context_button("Delete", _on_saved_profile_context_delete_pressed))
	return context_panel

func _on_saved_profile_context_popup_hide(context_panel: PopupPanel) -> void:
	if profile_saved_profiles_context_panel != context_panel:
		return
	profile_saved_profiles_context_profile_id = StringName()
	profile_saved_profiles_context_panel = null
	if is_instance_valid(context_panel):
		context_panel.queue_free()

func _on_saved_profile_context_rename_pressed() -> void:
	var profile_id := profile_saved_profiles_context_profile_id
	_hide_saved_profile_context_menu()
	if profile_id != StringName():
		_open_rename_profile_name_popup(profile_id)

func _on_saved_profile_context_delete_pressed() -> void:
	var profile_id := profile_saved_profiles_context_profile_id
	_hide_saved_profile_context_menu()
	if profile_id != StringName():
		_delete_saved_profile(profile_id)

func _on_profile_canvas_context_requested(
	target_kind: StringName,
	target_index: int,
	target_id: StringName,
	target_position_meters: Vector2
) -> void:
	if (
		not _is_basic_profile_canvas_context_available()
		or target_id == StringName()
		or not target_kind in [&"segment", &"control_point", &"fillet"]
	):
		_hide_profile_canvas_context_menu()
		return
	var actions := _build_profile_canvas_context_actions(target_kind, target_id)
	if actions.is_empty():
		_hide_profile_canvas_context_menu()
		return
	_cancel_profile_builder_metric_pan()
	_hide_profile_canvas_context_menu()
	profile_canvas_context_target_kind = target_kind
	profile_canvas_context_target_index = target_index
	profile_canvas_context_target_id = target_id
	profile_canvas_context_target_position_meters = target_position_meters
	profile_canvas_context_panel = _build_profile_canvas_context_panel(actions)
	if not UiWindowLayerPolicyScript.attach_owned_popup(
		profile_builder_popup,
		profile_canvas_context_panel
	):
		profile_canvas_context_panel.queue_free()
		profile_canvas_context_panel = null
		profile_canvas_context_target_kind = StringName()
		profile_canvas_context_target_index = -1
		profile_canvas_context_target_id = StringName()
		profile_canvas_context_target_position_meters = Vector2.ZERO
		return
	var mouse_position := (
		UiWindowLayerPolicyScript.get_control_pointer_screen_position(
			profile_builder_preview
		)
	)
	var popup_height := maxi(36, actions.size() * 28 + 8)
	profile_canvas_context_panel.popup(Rect2i(
		mouse_position,
		Vector2i(PROFILE_CANVAS_CONTEXT_POPUP_WIDTH, popup_height)
	))

func _hide_profile_canvas_context_menu() -> void:
	profile_canvas_context_target_kind = StringName()
	profile_canvas_context_target_index = -1
	profile_canvas_context_target_id = StringName()
	profile_canvas_context_target_position_meters = Vector2.ZERO
	var context_panel := profile_canvas_context_panel
	profile_canvas_context_panel = null
	if is_instance_valid(context_panel):
		context_panel.hide()
		context_panel.queue_free()

func _build_profile_canvas_context_actions(
	target_kind: StringName,
	target_id: StringName
) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var builder_settings := _get_active_basic_profile_builder_settings()
	if builder_settings.is_empty():
		return actions
	match target_kind:
		&"segment":
			actions.append({
				"label": "Add Point",
				"callback": Callable(self, "_on_profile_canvas_add_point_pressed"),
			})
		&"control_point":
			var control_points: PackedVector2Array = builder_settings.get(
				"control_points_2d_meters",
				PackedVector2Array()
			)
			var fillet_settings := _get_basic_corner_fillet_settings(target_id)
			if control_points.size() >= 4:
				actions.append({
					"label": "Remove",
					"callback": Callable(
						self,
						"_on_profile_canvas_remove_point_pressed"
					),
				})
			if not bool(fillet_settings.get("has_fillet", false)):
				actions.append({
					"label": "Fillet",
					"callback": Callable(
						self,
						"_on_profile_canvas_add_fillet_pressed"
					),
				})
		&"fillet":
			var fillet_settings := _get_basic_corner_fillet_settings(target_id)
			if bool(fillet_settings.get("has_fillet", false)):
				actions.append({
					"label": "Remove Fillet",
					"callback": Callable(
						self,
						"_on_profile_canvas_remove_fillet_pressed"
					),
				})
				actions.append({
					"label": "Fillet Size",
					"callback": Callable(
						self,
						"_on_profile_canvas_fillet_size_pressed"
					),
				})
	return actions

func _build_profile_canvas_context_panel(
	actions: Array[Dictionary]
) -> PopupPanel:
	var context_panel := PopupPanel.new()
	context_panel.name = "ProfileCanvasContextPanel"
	context_panel.unresizable = true
	UiWindowLayerPolicyScript.configure_owned_popup(context_panel)
	context_panel.popup_hide.connect(
		_on_profile_canvas_context_popup_hide.bind(context_panel)
	)
	_apply_v2_popup_theme(context_panel)

	var context_margin := MarginContainer.new()
	context_margin.name = "ProfileCanvasContextMargin"
	_apply_margin(context_margin, 4)
	context_panel.add_child(context_margin)

	var context_vbox := VBoxContainer.new()
	context_vbox.name = "ProfileCanvasContextVBox"
	context_vbox.add_theme_constant_override("separation", 0)
	context_margin.add_child(context_vbox)
	for action: Dictionary in actions:
		var callback: Callable = action.get("callback", Callable())
		if not callback.is_valid():
			continue
		context_vbox.add_child(_build_profile_context_button(
			String(action.get("label", "")),
			callback
		))
	return context_panel

func _on_profile_canvas_context_popup_hide(
	context_panel: PopupPanel
) -> void:
	if profile_canvas_context_panel != context_panel:
		return
	profile_canvas_context_panel = null
	profile_canvas_context_target_kind = StringName()
	profile_canvas_context_target_index = -1
	profile_canvas_context_target_id = StringName()
	profile_canvas_context_target_position_meters = Vector2.ZERO
	if is_instance_valid(context_panel):
		context_panel.queue_free()

func _is_basic_profile_canvas_context_available() -> bool:
	if (
		active_stage_controller == null
		or profile_builder_preview == null
		or not is_instance_valid(profile_builder_popup)
		or not profile_builder_popup.visible
	):
		return false
	return not _get_active_basic_profile_builder_settings().is_empty()

func _get_active_basic_profile_builder_settings() -> Dictionary:
	if (
		active_stage_controller == null
		or not active_stage_controller.has_method("get_status_summary")
	):
		return {}
	var summary: Dictionary = active_stage_controller.call(
		"get_status_summary"
	) as Dictionary
	var profile_settings := summary.get(
		"active_profile_settings",
		{}
	) as Dictionary
	var builder_settings := profile_settings.get(
		"profile_builder",
		{}
	) as Dictionary
	if (
		not bool(builder_settings.get("is_active", false))
		or StringName(builder_settings.get("family", StringName()))
		!= ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC
	):
		return {}
	return builder_settings

func _get_basic_corner_fillet_settings(
	corner_id: StringName
) -> Dictionary:
	if (
		corner_id == StringName()
		or active_stage_controller == null
		or not active_stage_controller.has_method(
			"get_active_basic_corner_fillet_settings"
		)
	):
		return {}
	return active_stage_controller.call(
		"get_active_basic_corner_fillet_settings",
		corner_id
	) as Dictionary

func _on_profile_canvas_add_point_pressed() -> void:
	var segment_start_corner_id := profile_canvas_context_target_id
	var target_position := profile_canvas_context_target_position_meters
	_hide_profile_canvas_context_menu()
	if (
		segment_start_corner_id == StringName()
		or active_stage_controller == null
		or not active_stage_controller.has_method(
			"insert_active_basic_control_point_on_segment"
		)
	):
		return
	var new_corner_id := StringName(active_stage_controller.call(
		"insert_active_basic_control_point_on_segment",
		segment_start_corner_id,
		target_position
	))
	if new_corner_id != StringName():
		_set_v2_action_status_text("Added profile control point")
		_refresh_profile_builder_popup()

func _on_profile_canvas_remove_point_pressed() -> void:
	var corner_id := profile_canvas_context_target_id
	_hide_profile_canvas_context_menu()
	if (
		corner_id == StringName()
		or active_stage_controller == null
		or not active_stage_controller.has_method(
			"remove_active_basic_control_point"
		)
	):
		return
	if bool(active_stage_controller.call(
		"remove_active_basic_control_point",
		corner_id
	)):
		_set_v2_action_status_text("Removed profile control point")
		_refresh_profile_builder_popup()

func _on_profile_canvas_add_fillet_pressed() -> void:
	var corner_id := profile_canvas_context_target_id
	_hide_profile_canvas_context_menu()
	if (
		corner_id == StringName()
		or active_stage_controller == null
		or not active_stage_controller.has_method(
			"add_active_basic_corner_fillet"
		)
	):
		return
	if bool(active_stage_controller.call(
		"add_active_basic_corner_fillet",
		corner_id
	)):
		_set_v2_action_status_text("Added 0.01 m profile fillet")
		_refresh_profile_builder_popup()

func _on_profile_canvas_remove_fillet_pressed() -> void:
	var corner_id := profile_canvas_context_target_id
	_hide_profile_canvas_context_menu()
	if (
		corner_id == StringName()
		or active_stage_controller == null
		or not active_stage_controller.has_method(
			"remove_active_basic_corner_fillet"
		)
	):
		return
	if bool(active_stage_controller.call(
		"remove_active_basic_corner_fillet",
		corner_id
	)):
		_set_v2_action_status_text("Removed profile fillet")
		_refresh_profile_builder_popup()

func _on_profile_canvas_fillet_size_pressed() -> void:
	var corner_id := profile_canvas_context_target_id
	_hide_profile_canvas_context_menu()
	if corner_id != StringName():
		_open_profile_fillet_size_popup(corner_id)

func _open_profile_fillet_size_popup(corner_id: StringName) -> void:
	var fillet_settings := _get_basic_corner_fillet_settings(corner_id)
	if not bool(fillet_settings.get("has_fillet", false)):
		return
	var restore_profile_builder := (
		is_instance_valid(profile_builder_popup)
		and profile_builder_popup.visible
	)
	_close_profile_fillet_popup(false)
	profile_fillet_pending_corner_id = corner_id
	profile_fillet_restore_profile_builder = restore_profile_builder
	profile_fillet_popup = _build_profile_fillet_popup(fillet_settings)
	if not UiWindowLayerPolicyScript.attach_owned_popup(
		profile_builder_popup,
		profile_fillet_popup
	):
		profile_fillet_popup.queue_free()
		profile_fillet_popup = null
		profile_fillet_pending_corner_id = StringName()
		profile_fillet_restore_profile_builder = false
		return
	profile_fillet_popup.popup_centered(PROFILE_FILLET_DIALOG_SIZE)
	if profile_fillet_spin_box != null:
		var line_edit := profile_fillet_spin_box.get_line_edit()
		line_edit.grab_focus()
		line_edit.select_all()

func _build_profile_fillet_popup(
	fillet_settings: Dictionary
) -> PopupPanel:
	var fillet_popup := PopupPanel.new()
	fillet_popup.name = "ProfileFilletSizePopup"
	fillet_popup.unresizable = true
	UiWindowLayerPolicyScript.configure_owned_popup(fillet_popup)
	fillet_popup.popup_hide.connect(
		_on_profile_fillet_popup_hide.bind(fillet_popup)
	)
	_apply_v2_popup_theme(fillet_popup)

	var popup_margin := MarginContainer.new()
	popup_margin.name = "ProfileFilletSizeMargin"
	_apply_margin(popup_margin, 12)
	fillet_popup.add_child(popup_margin)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.name = "ProfileFilletSizeVBox"
	popup_vbox.add_theme_constant_override("separation", 10)
	popup_margin.add_child(popup_vbox)

	var title := Label.new()
	title.name = "ProfileFilletSizeTitle"
	title.text = "Fillet Size"
	title.add_theme_font_size_override("font_size", 18)
	popup_vbox.add_child(title)

	var field_label := Label.new()
	field_label.name = "ProfileFilletSizeLabel"
	field_label.text = "Fillet size"
	popup_vbox.add_child(field_label)

	profile_fillet_spin_box = SpinBox.new()
	profile_fillet_spin_box.name = "ProfileFilletSizeSpinBox"
	profile_fillet_spin_box.min_value = float(fillet_settings.get(
		"minimum_radius_meters",
		ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_MIN_METERS
	))
	profile_fillet_spin_box.max_value = float(fillet_settings.get(
		"maximum_radius_meters",
		ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_INPUT_MAX_METERS
	))
	profile_fillet_spin_box.step = 0.001
	profile_fillet_spin_box.rounded = false
	profile_fillet_spin_box.allow_greater = false
	profile_fillet_spin_box.allow_lesser = false
	profile_fillet_spin_box.suffix = " m"
	profile_fillet_spin_box.custom_minimum_size = Vector2(240.0, 32.0)
	profile_fillet_spin_box.value = float(fillet_settings.get(
		"radius_meters",
		ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_DEFAULT_METERS
	))
	profile_fillet_spin_box.get_line_edit().text_submitted.connect(
		_on_profile_fillet_size_text_submitted,
		Object.CONNECT_DEFERRED
	)
	popup_vbox.add_child(profile_fillet_spin_box)

	var button_row := HBoxContainer.new()
	button_row.name = "ProfileFilletSizeButtonRow"
	button_row.add_theme_constant_override("separation", 8)
	popup_vbox.add_child(button_row)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(spacer)

	var cancel_button := Button.new()
	cancel_button.name = "CancelButton"
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(82.0, 30.0)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(_cancel_profile_fillet_size_popup)
	button_row.add_child(cancel_button)

	var apply_button := Button.new()
	apply_button.name = "ApplyButton"
	apply_button.text = "Apply"
	apply_button.custom_minimum_size = Vector2(82.0, 30.0)
	apply_button.focus_mode = Control.FOCUS_NONE
	apply_button.pressed.connect(_request_profile_fillet_size_apply)
	button_row.add_child(apply_button)
	return fillet_popup

func _request_profile_fillet_size_apply() -> void:
	if profile_fillet_spin_box != null:
		profile_fillet_spin_box.apply()

func _on_profile_fillet_size_text_submitted(
	_submitted_text: String
) -> void:
	_apply_profile_fillet_size_popup()

func _apply_profile_fillet_size_popup() -> void:
	var corner_id := profile_fillet_pending_corner_id
	var radius_meters := 0.0
	if profile_fillet_spin_box != null:
		radius_meters = clampf(
			profile_fillet_spin_box.value,
			profile_fillet_spin_box.min_value,
			profile_fillet_spin_box.max_value
		)
	var settings := _get_basic_corner_fillet_settings(corner_id)
	if (
		corner_id == StringName()
		or not bool(settings.get("has_fillet", false))
		or active_stage_controller == null
		or not active_stage_controller.has_method(
			"set_active_basic_corner_fillet_radius"
		)
	):
		_close_profile_fillet_popup(true)
		return
	var changed := bool(active_stage_controller.call(
		"set_active_basic_corner_fillet_radius",
		corner_id,
		radius_meters
	))
	if changed:
		_set_v2_action_status_text(
			"Profile fillet set to %.3f m" % radius_meters
		)
	_close_profile_fillet_popup(true)
	if changed:
		_refresh_from_controller()

func _cancel_profile_fillet_size_popup() -> void:
	_close_profile_fillet_popup(true)

func _close_profile_fillet_popup(
	restore_workspace: bool = true
) -> void:
	var should_restore_profile_builder := (
		profile_fillet_restore_profile_builder
	)
	var fillet_popup := profile_fillet_popup
	profile_fillet_popup = null
	profile_fillet_spin_box = null
	profile_fillet_pending_corner_id = StringName()
	profile_fillet_restore_profile_builder = false
	if is_instance_valid(fillet_popup):
		fillet_popup.hide()
		fillet_popup.queue_free()
	if restore_workspace and should_restore_profile_builder:
		call_deferred(
			"_restore_profile_builder_after_fillet_popup"
		)

func _on_profile_fillet_popup_hide(
	fillet_popup: PopupPanel
) -> void:
	if profile_fillet_popup != fillet_popup:
		return
	var should_restore_profile_builder := (
		profile_fillet_restore_profile_builder
	)
	profile_fillet_popup = null
	profile_fillet_spin_box = null
	profile_fillet_pending_corner_id = StringName()
	profile_fillet_restore_profile_builder = false
	if is_instance_valid(fillet_popup):
		fillet_popup.queue_free()
	if should_restore_profile_builder:
		call_deferred(
			"_restore_profile_builder_after_fillet_popup"
		)

func _restore_profile_builder_after_fillet_popup() -> void:
	if not is_open():
		return
	_ensure_profile_builder_popup()
	_refresh_profile_builder_popup()
	if not profile_builder_popup.visible:
		profile_builder_popup.popup_centered(PROFILE_BUILDER_POPUP_SIZE)

func _open_save_profile_name_popup() -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("build_active_tool_profile_preset_data"):
		return
	_ensure_profile_name_popup()
	_capture_profile_name_return_workspace()
	if not UiWindowLayerPolicyScript.attach_owned_popup(
		profile_builder_popup,
		profile_name_popup
	):
		return
	var profile_library: Resource = _ensure_tool_profile_library_state()
	var profile_family := _resolve_active_profile_builder_family()
	var default_name := "handle profile 1" if profile_family == ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE else "tool profile 1"
	if profile_library != null and profile_library.has_method("build_default_profile_name"):
		default_name = String(profile_library.call(
			"build_default_profile_name",
			profile_family
		))
	profile_name_pending_action = &"save_profile"
	profile_name_pending_profile_id = StringName()
	if profile_name_popup_title != null:
		profile_name_popup_title.text = "Save Profile"
	if profile_name_line_edit != null:
		profile_name_line_edit.text = default_name
		profile_name_line_edit.select_all()
	profile_name_popup.popup_centered(Vector2i(440, 150))
	if profile_name_line_edit != null:
		profile_name_line_edit.grab_focus()

func _on_profile_save_button_pressed() -> void:
	if active_saved_profile_id != StringName():
		_save_active_profile_over_existing(active_saved_profile_id)
	else:
		_open_save_profile_name_popup()

func _save_active_profile_over_existing(profile_id: StringName) -> void:
	if profile_id == StringName():
		_open_save_profile_name_popup()
		return
	if active_stage_controller == null or not active_stage_controller.has_method("build_active_tool_profile_preset_data"):
		return
	var profile_library: Resource = _ensure_tool_profile_library_state()
	if profile_library == null or not profile_library.has_method("get_saved_profile") or not profile_library.has_method("save_profile"):
		return
	var existing_profile: Dictionary = profile_library.call("get_saved_profile", profile_id) as Dictionary
	if existing_profile.is_empty():
		active_saved_profile_id = StringName()
		_open_save_profile_name_popup()
		return
	if StringName(existing_profile.get("family", StringName())) != _resolve_active_profile_builder_family():
		active_saved_profile_id = StringName()
		_open_save_profile_name_popup()
		return
	var profile_label := String(existing_profile.get("label", "Profile"))
	var profile_data: Dictionary = active_stage_controller.call("build_active_tool_profile_preset_data", profile_label) as Dictionary
	if profile_data.is_empty():
		return
	profile_data["profile_id"] = profile_id
	profile_data["id"] = profile_id
	profile_data["created_timestamp"] = existing_profile.get("created_timestamp", 0.0)
	var saved_profile: Dictionary = profile_library.call("save_profile", profile_data, profile_label) as Dictionary
	active_saved_profile_id = StringName(saved_profile.get("profile_id", profile_id))
	if active_stage_controller.has_method("set_active_profile_display_name"):
		active_stage_controller.call("set_active_profile_display_name", String(saved_profile.get("label", profile_label)))
	_set_v2_action_status_text("Saved profile: %s" % String(saved_profile.get("label", profile_label)))
	_refresh_from_controller()
	_refresh_profile_builder_popup()

func _open_rename_profile_name_popup(profile_id: StringName) -> void:
	if profile_id == StringName():
		return
	var profile_library: Resource = _ensure_tool_profile_library_state()
	if profile_library == null or not profile_library.has_method("get_saved_profile"):
		return
	var saved_profile: Dictionary = profile_library.call("get_saved_profile", profile_id) as Dictionary
	if saved_profile.is_empty():
		return
	_ensure_profile_name_popup()
	_capture_profile_name_return_workspace()
	var name_popup_owner: Window = profile_builder_popup
	if (
		is_instance_valid(profile_saved_profiles_popup)
		and profile_saved_profiles_popup.visible
	):
		name_popup_owner = profile_saved_profiles_popup
	if not UiWindowLayerPolicyScript.attach_owned_popup(
		name_popup_owner,
		profile_name_popup
	):
		return
	profile_name_pending_action = &"rename_profile"
	profile_name_pending_profile_id = profile_id
	if profile_name_popup_title != null:
		profile_name_popup_title.text = "Rename Profile"
	if profile_name_line_edit != null:
		profile_name_line_edit.text = String(saved_profile.get("label", ""))
		profile_name_line_edit.select_all()
	profile_name_popup.popup_centered(Vector2i(440, 150))
	if profile_name_line_edit != null:
		profile_name_line_edit.grab_focus()

func _delete_saved_profile(profile_id: StringName) -> void:
	var profile_library: Resource = _ensure_tool_profile_library_state()
	if profile_library == null or not profile_library.has_method("remove_profile"):
		return
	var removed := bool(profile_library.call("remove_profile", profile_id))
	if removed:
		if active_saved_profile_id == profile_id:
			active_saved_profile_id = StringName()
			if active_stage_controller != null and active_stage_controller.has_method("set_active_profile_display_name"):
				active_stage_controller.call("set_active_profile_display_name", "")
		_set_v2_action_status_text("Deleted profile")
	_refresh_from_controller()
	_refresh_profile_builder_popup()
	if is_instance_valid(profile_saved_profiles_popup) and profile_saved_profiles_popup.visible:
		_refresh_profile_saved_profiles_popup()

func _capture_profile_name_return_workspace() -> void:
	profile_name_restore_profile_builder = is_instance_valid(profile_builder_popup) and profile_builder_popup.visible
	profile_name_restore_saved_profiles = is_instance_valid(profile_saved_profiles_popup) and profile_saved_profiles_popup.visible

func _close_profile_name_popup(restore_workspace: bool = true) -> void:
	var should_restore_profile_builder := profile_name_restore_profile_builder
	var should_restore_saved_profiles := profile_name_restore_saved_profiles
	profile_name_pending_action = StringName()
	profile_name_pending_profile_id = StringName()
	profile_name_restore_profile_builder = false
	profile_name_restore_saved_profiles = false
	if is_instance_valid(profile_name_popup):
		profile_name_popup.hide()
	if restore_workspace and (should_restore_profile_builder or should_restore_saved_profiles):
		call_deferred(
			"_restore_profile_workspace_after_profile_name_popup",
			should_restore_profile_builder,
			should_restore_saved_profiles
		)

func _restore_profile_workspace_after_profile_name_popup(restore_profile_builder: bool, restore_saved_profiles: bool) -> void:
	if not is_open():
		return
	if restore_profile_builder:
		_ensure_profile_builder_popup()
		_refresh_profile_builder_popup()
		if not profile_builder_popup.visible:
			profile_builder_popup.popup_centered(PROFILE_BUILDER_POPUP_SIZE)
	if restore_saved_profiles:
		_ensure_profile_saved_profiles_popup()
		_refresh_profile_saved_profiles_popup()
		if not profile_saved_profiles_popup.visible:
			_open_profile_saved_profiles_popup()

func _confirm_profile_name_popup() -> void:
	if profile_name_pending_action == StringName():
		_close_profile_name_popup()
		return
	var submitted_name := profile_name_line_edit.text if profile_name_line_edit != null else ""
	var profile_library: Resource = _ensure_tool_profile_library_state()
	if profile_library == null:
		_close_profile_name_popup()
		return
	match profile_name_pending_action:
		&"save_profile":
			if active_stage_controller == null or not active_stage_controller.has_method("build_active_tool_profile_preset_data"):
				_close_profile_name_popup()
				return
			var profile_data: Dictionary = active_stage_controller.call("build_active_tool_profile_preset_data", submitted_name) as Dictionary
			if profile_data.is_empty() or not profile_library.has_method("save_profile"):
				_close_profile_name_popup()
				return
			var saved_profile: Dictionary = profile_library.call("save_profile", profile_data, submitted_name) as Dictionary
			active_saved_profile_id = StringName(saved_profile.get("profile_id", StringName()))
			if active_stage_controller.has_method("apply_tool_profile_preset"):
				active_stage_controller.call("apply_tool_profile_preset", saved_profile)
			_set_v2_action_status_text("Saved profile: %s" % String(saved_profile.get("label", "Profile")))
		&"rename_profile":
			if not profile_library.has_method("rename_profile"):
				_close_profile_name_popup()
				return
			var renamed_profile: Dictionary = profile_library.call("rename_profile", profile_name_pending_profile_id, submitted_name) as Dictionary
			if profile_name_pending_profile_id == active_saved_profile_id and active_stage_controller != null:
				if active_stage_controller.has_method("set_active_profile_display_name"):
					active_stage_controller.call("set_active_profile_display_name", String(renamed_profile.get("label", "Profile")))
			_set_v2_action_status_text("Renamed profile: %s" % String(renamed_profile.get("label", "Profile")))
	_close_profile_name_popup()
	_refresh_from_controller()
	_refresh_profile_builder_popup()
	if is_instance_valid(profile_saved_profiles_popup) and profile_saved_profiles_popup.visible:
		_refresh_profile_saved_profiles_popup()

func _open_keybindings_popup() -> void:
	_ensure_keybindings_popup()
	_rebuild_keybindings_list()
	keybindings_popup.popup_centered(Vector2i(660, 470))

func _close_keybindings_popup() -> void:
	_cancel_keybinding_capture()
	if is_instance_valid(keybindings_popup):
		keybindings_popup.hide()
	_persist_keybinding_state()

func _refresh_settings_popup() -> void:
	_ensure_settings_popup()
	if freehand_smoothing_slider == null or freehand_smoothing_value_label == null:
		return
	var smoothing_steps := 0
	if active_stage_controller != null and active_stage_controller.has_method("get_freehand_smoothing_steps"):
		smoothing_steps = int(active_stage_controller.call("get_freehand_smoothing_steps"))
	smoothing_steps = clampi(smoothing_steps, 0, 10)
	is_refreshing_settings_ui = true
	freehand_smoothing_slider.editable = active_stage_controller != null
	freehand_smoothing_slider.set_value_no_signal(float(smoothing_steps))
	freehand_smoothing_value_label.text = str(smoothing_steps)
	is_refreshing_settings_ui = false

func _on_freehand_smoothing_value_changed(value: float) -> void:
	if is_refreshing_settings_ui:
		return
	var smoothing_steps := clampi(roundi(value), 0, 10)
	is_refreshing_settings_ui = true
	if freehand_smoothing_slider != null:
		freehand_smoothing_slider.set_value_no_signal(float(smoothing_steps))
	if freehand_smoothing_value_label != null:
		freehand_smoothing_value_label.text = str(smoothing_steps)
	is_refreshing_settings_ui = false
	if active_stage_controller != null and active_stage_controller.has_method("set_freehand_smoothing_steps"):
		active_stage_controller.call("set_freehand_smoothing_steps", smoothing_steps)

func _refresh_profile_builder_popup() -> void:
	_ensure_profile_builder_popup()
	if active_stage_controller == null or profile_builder_preview == null:
		return
	var summary: Dictionary = active_stage_controller.call("get_status_summary") as Dictionary
	_rebuild_profile_builder_internal_menus(summary)
	var profile_settings: Dictionary = summary.get("active_profile_settings", {}) as Dictionary
	var profile_builder_settings: Dictionary = profile_settings.get("profile_builder", {}) as Dictionary
	var handle_builder_settings: Dictionary = profile_settings.get("handle_builder", {}) as Dictionary
	var profile_builder_active := bool(profile_builder_settings.get("is_active", false))
	var handle_builder_active := bool(handle_builder_settings.get("is_active", false))
	is_refreshing_profile_builder_ui = true
	var size_min := float(profile_settings.get("size_min_meters", PROFILE_BUILDER_SIZE_MIN_METERS))
	var size_max := float(profile_settings.get("size_max_meters", PROFILE_BUILDER_SIZE_MAX_METERS))
	var anchor_min := float(profile_settings.get("anchor_min_meters", -PROFILE_BUILDER_SIZE_MAX_METERS))
	var anchor_max := float(profile_settings.get("anchor_max_meters", PROFILE_BUILDER_SIZE_MAX_METERS))
	if profile_width_spin_box != null:
		profile_width_spin_box.min_value = size_min
		profile_width_spin_box.max_value = size_max
		profile_width_spin_box.editable = true
		profile_width_spin_box.set_value_no_signal(float(profile_settings.get("width_meters", size_min)))
	if profile_height_spin_box != null:
		profile_height_spin_box.min_value = size_min
		profile_height_spin_box.max_value = size_max
		profile_height_spin_box.editable = true
		profile_height_spin_box.set_value_no_signal(float(profile_settings.get("height_meters", size_min)))
	if profile_anchor_x_spin_box != null:
		profile_anchor_x_spin_box.min_value = anchor_min
		profile_anchor_x_spin_box.max_value = anchor_max
		profile_anchor_x_spin_box.editable = true
		profile_anchor_x_spin_box.set_value_no_signal(float(profile_settings.get("anchor_x_meters", 0.0)))
	if profile_anchor_y_spin_box != null:
		profile_anchor_y_spin_box.min_value = anchor_min
		profile_anchor_y_spin_box.max_value = anchor_max
		profile_anchor_y_spin_box.editable = true
		profile_anchor_y_spin_box.set_value_no_signal(float(profile_settings.get("anchor_y_meters", 0.0)))
	var rotation_degrees := float(profile_settings.get("rotation_degrees", 0.0))
	if profile_rotation_spin_box != null:
		profile_rotation_spin_box.set_value_no_signal(rotation_degrees)
	if profile_rotation_slider != null:
		profile_rotation_slider.set_value_no_signal(rotation_degrees)
	if profile_handle_face_count_option != null:
		profile_handle_face_count_option.disabled = not handle_builder_active
		_select_option_by_metadata(profile_handle_face_count_option, int(handle_builder_settings.get("face_count", ForgeV2ProfileShapeLibraryScript.HANDLE_FACE_COUNT_RECTANGLE)))
	if profile_handle_rounded_check_box != null:
		profile_handle_rounded_check_box.disabled = not handle_builder_active
		profile_handle_rounded_check_box.set_pressed_no_signal(bool(handle_builder_settings.get("rounded_enabled", true)))
	var corner_radius_max := float(handle_builder_settings.get("corner_radius_max_meters", 0.0))
	var corner_radius_value := float(handle_builder_settings.get("corner_radius_meters", 0.0))
	var corner_radius_editable := handle_builder_active and bool(handle_builder_settings.get("rounded_enabled", true))
	if profile_handle_corner_radius_spin_box != null:
		profile_handle_corner_radius_spin_box.max_value = maxf(corner_radius_max, 0.0)
		profile_handle_corner_radius_spin_box.editable = corner_radius_editable
		profile_handle_corner_radius_spin_box.set_value_no_signal(clampf(corner_radius_value, 0.0, maxf(corner_radius_max, 0.0)))
	if profile_handle_corner_radius_slider != null:
		profile_handle_corner_radius_slider.max_value = maxf(corner_radius_max, 0.0)
		profile_handle_corner_radius_slider.editable = corner_radius_editable
		profile_handle_corner_radius_slider.modulate = Color(1.0, 1.0, 1.0, 1.0) if corner_radius_editable else Color(0.55, 0.57, 0.58, 0.75)
		profile_handle_corner_radius_slider.set_value_no_signal(clampf(corner_radius_value, 0.0, maxf(corner_radius_max, 0.0)))
	if profile_save_button != null:
		profile_save_button.disabled = not profile_builder_active
	if profile_grid_snap_check_box != null:
		profile_grid_snap_check_box.disabled = not profile_builder_active
		profile_grid_snap_check_box.set_pressed_no_signal(bool(profile_builder_settings.get("grid_snapping_enabled", false)))
	is_refreshing_profile_builder_ui = false
	var preview_polygon: PackedVector2Array = profile_settings.get("preview_polygon_2d_meters", PackedVector2Array())
	var control_points: PackedVector2Array = profile_builder_settings.get("control_points_2d_meters", PackedVector2Array())
	var profile_builder_family := StringName(profile_builder_settings.get("family", StringName()))
	if profile_builder_preview.has_method("set_profile_guide"):
		profile_builder_preview.call(
			"set_profile_guide",
			profile_builder_settings.get("guide_polygon_2d_meters", PackedVector2Array()),
			profile_builder_settings.get("guide_grid_segments_2d_meters", []),
			profile_builder_settings.get("guide_grid_snap_points_2d_meters", PackedVector2Array()),
			bool(profile_builder_settings.get("grid_snapping_enabled", false)),
			float(profile_builder_settings.get(
				"guide_grid_step_meters",
				ForgeV2ProfileShapeLibraryScript.BASIC_BUILDER_GRID_STEP_METERS
			)),
			rotation_degrees
		)
	if profile_builder_preview.has_method("set_profile_geometry"):
		profile_builder_preview.call(
			"set_profile_geometry",
			preview_polygon,
			control_points,
			bool(profile_builder_settings.get("rounded_enabled", false)),
			Vector2(
				float(profile_settings.get("anchor_x_meters", 0.0)),
				float(profile_settings.get("anchor_y_meters", 0.0))
			),
			profile_builder_settings.get("corner_metadata", []),
			profile_builder_settings.get("fillet_corner_results", [])
		)
	elif profile_builder_preview.has_method("set_profile_polygon"):
		profile_builder_preview.call("set_profile_polygon", preview_polygon)
	if profile_builder_preview.has_method("configure_metric_view"):
		var metric_profile_view_enabled := (
			profile_builder_active
			and profile_builder_family == ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC
		)
		profile_builder_preview.call(
			"configure_metric_view",
			metric_profile_view_enabled,
			size_min
		)
		if profile_builder_preview.has_method("configure_canvas_context"):
			profile_builder_preview.call(
				"configure_canvas_context",
				metric_profile_view_enabled
			)
		if not metric_profile_view_enabled:
			_cancel_profile_builder_metric_pan()
			_hide_profile_canvas_context_menu()
			_close_profile_fillet_popup(false)

func _rebuild_profile_builder_internal_menus(summary: Dictionary) -> void:
	if profile_builder_basic_menu_button == null:
		return
	profile_builder_action_lookup.clear()
	profile_builder_next_id = PROFILE_BUILDER_MENU_ID_BASE
	var active_profile_id: StringName = StringName(summary.get("active_profile", StringName()))
	var basic_popup: PopupMenu = profile_builder_basic_menu_button.get_popup()
	basic_popup.clear()
	_add_profile_builder_option_items(
		basic_popup,
		ForgeV2ProfileShapeLibraryScript.build_profile_entries(ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC),
		&"profile_basic",
		active_profile_id
	)
	if is_instance_valid(profile_saved_profiles_popup) and profile_saved_profiles_popup.visible:
		_refresh_profile_saved_profiles_popup()

func _on_profile_width_value_changed(value: float) -> void:
	_call_profile_builder_float_setter(&"set_active_profile_width_meters", value)

func _on_profile_height_value_changed(value: float) -> void:
	_call_profile_builder_float_setter(&"set_active_profile_height_meters", value)

func _on_profile_anchor_x_value_changed(value: float) -> void:
	_call_profile_builder_float_setter(&"set_active_profile_anchor_x_meters", value)

func _on_profile_anchor_y_value_changed(value: float) -> void:
	_call_profile_builder_float_setter(&"set_active_profile_anchor_y_meters", value)

func _on_profile_rotation_spin_value_changed(value: float) -> void:
	_call_profile_builder_float_setter(&"set_active_profile_rotation_degrees", value)

func _on_profile_rotation_slider_value_changed(value: float) -> void:
	_call_profile_builder_float_setter(&"set_active_profile_rotation_degrees", value)

func _on_profile_handle_face_count_selected(index: int) -> void:
	if is_refreshing_profile_builder_ui:
		return
	if profile_handle_face_count_option == null:
		return
	var face_count := int(profile_handle_face_count_option.get_item_metadata(index))
	_call_profile_builder_int_setter(&"set_active_handle_face_count", face_count)

func _on_profile_handle_rounded_toggled(is_enabled: bool) -> void:
	_call_profile_builder_bool_setter(&"set_active_handle_rounding_enabled", is_enabled)

func _on_profile_grid_snapping_toggled(is_enabled: bool) -> void:
	var method_name := (
		&"set_active_handle_grid_snapping_enabled"
		if _resolve_active_profile_builder_family() == ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE
		else &"set_active_basic_grid_snapping_enabled"
	)
	_call_profile_builder_bool_setter(method_name, is_enabled)

func _on_profile_handle_corner_radius_spin_value_changed(value: float) -> void:
	_call_profile_builder_float_setter(&"set_active_handle_corner_radius_meters", value)

func _on_profile_handle_corner_radius_slider_value_changed(value: float) -> void:
	_call_profile_builder_float_setter(&"set_active_handle_corner_radius_meters", value)

func _on_profile_handles_button_pressed() -> void:
	_select_profile_builder_handle_builder()

func _select_profile_builder_basic_builder() -> void:
	if active_stage_controller == null:
		return
	active_saved_profile_id = StringName()
	if active_stage_controller.has_method("reset_active_basic_profile_builder"):
		active_stage_controller.call("reset_active_basic_profile_builder")
	else:
		if active_stage_controller.has_method("set_active_tool_id"):
			active_stage_controller.call("set_active_tool_id", &"tool_volume_stroke")
		if active_stage_controller.has_method("set_active_profile_id"):
			active_stage_controller.call("set_active_profile_id", ForgeV2ProfileShapeLibraryScript.PROFILE_2D_BUILDER)
	_refresh_from_controller()
	_refresh_profile_builder_popup()

func _on_profile_control_point_dragged(point_index: int, point_position_meters: Vector2) -> void:
	if active_stage_controller == null:
		return
	var method_name := (
		&"set_active_handle_control_point_2d_meters"
		if _resolve_active_profile_builder_family() == ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_HANDLE
		else &"set_active_basic_control_point_2d_meters"
	)
	if not active_stage_controller.has_method(method_name):
		return
	active_stage_controller.call(method_name, point_index, point_position_meters)

func _on_profile_control_point_drag_finished(_point_index: int) -> void:
	_refresh_profile_builder_popup()

func _on_profile_anchor_point_dragged(anchor_position_meters: Vector2) -> void:
	if active_stage_controller == null:
		return
	var clamped_position := _clamp_profile_anchor_position(anchor_position_meters)
	if active_stage_controller.has_method("set_active_profile_anchor_2d_meters"):
		active_stage_controller.call("set_active_profile_anchor_2d_meters", clamped_position)
	elif active_stage_controller.has_method("set_active_profile_anchor_x_meters"):
		active_stage_controller.call("set_active_profile_anchor_x_meters", clamped_position.x)
		if active_stage_controller.has_method("set_active_profile_anchor_y_meters"):
			active_stage_controller.call("set_active_profile_anchor_y_meters", clamped_position.y)
	is_refreshing_profile_builder_ui = true
	if profile_anchor_x_spin_box != null:
		profile_anchor_x_spin_box.set_value_no_signal(clamped_position.x)
	if profile_anchor_y_spin_box != null:
		profile_anchor_y_spin_box.set_value_no_signal(clamped_position.y)
	is_refreshing_profile_builder_ui = false

func _on_profile_anchor_point_drag_finished() -> void:
	_refresh_profile_builder_popup()

func _on_profile_anchor_point_reset_requested() -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("reset_active_profile_anchor_to_center"):
		return
	active_stage_controller.call("reset_active_profile_anchor_to_center")
	_refresh_profile_builder_popup()

func _select_profile_builder_handle_builder() -> void:
	if active_stage_controller == null:
		return
	active_saved_profile_id = StringName()
	if active_stage_controller.has_method("reset_active_handle_profile_builder"):
		active_stage_controller.call("reset_active_handle_profile_builder")
	else:
		if active_stage_controller.has_method("set_active_tool_id"):
			active_stage_controller.call("set_active_tool_id", &"tool_handles")
		if active_stage_controller.has_method("set_active_profile_id"):
			active_stage_controller.call("set_active_profile_id", ForgeV2ProfileShapeLibraryScript.PROFILE_HANDLE_BUILDER)
	_refresh_from_controller()
	_refresh_profile_builder_popup()

func _load_saved_tool_profile(profile_id: StringName) -> bool:
	if profile_id == StringName():
		return false
	if active_stage_controller == null or not active_stage_controller.has_method("apply_tool_profile_preset"):
		return false
	var profile_library: Resource = _ensure_tool_profile_library_state()
	if profile_library == null or not profile_library.has_method("get_saved_profile"):
		return false
	var saved_profile: Dictionary = profile_library.call("get_saved_profile", profile_id) as Dictionary
	if saved_profile.is_empty():
		return false
	var loaded := bool(active_stage_controller.call("apply_tool_profile_preset", saved_profile))
	if not loaded:
		return false
	active_saved_profile_id = profile_id
	_set_v2_action_status_text("Loaded profile: %s" % String(saved_profile.get("label", "Profile")))
	_refresh_from_controller()
	_refresh_profile_builder_popup()
	return true

func _clamp_profile_anchor_position(anchor_position_meters: Vector2) -> Vector2:
	var min_x := -PROFILE_BUILDER_SIZE_MAX_METERS
	var max_x := PROFILE_BUILDER_SIZE_MAX_METERS
	var min_y := -PROFILE_BUILDER_SIZE_MAX_METERS
	var max_y := PROFILE_BUILDER_SIZE_MAX_METERS
	if profile_anchor_x_spin_box != null:
		min_x = float(profile_anchor_x_spin_box.min_value)
		max_x = float(profile_anchor_x_spin_box.max_value)
	if profile_anchor_y_spin_box != null:
		min_y = float(profile_anchor_y_spin_box.min_value)
		max_y = float(profile_anchor_y_spin_box.max_value)
	return Vector2(
		clampf(anchor_position_meters.x, min_x, max_x),
		clampf(anchor_position_meters.y, min_y, max_y)
	)

func _call_profile_builder_float_setter(method_name: StringName, value: float) -> void:
	if is_refreshing_profile_builder_ui:
		return
	if active_stage_controller == null or not active_stage_controller.has_method(method_name):
		return
	active_stage_controller.call(method_name, value)
	_refresh_profile_builder_popup()

func _call_profile_builder_int_setter(method_name: StringName, value: int) -> void:
	if is_refreshing_profile_builder_ui:
		return
	if active_stage_controller == null or not active_stage_controller.has_method(method_name):
		return
	active_stage_controller.call(method_name, value)
	_refresh_profile_builder_popup()

func _call_profile_builder_bool_setter(method_name: StringName, value: bool) -> void:
	if is_refreshing_profile_builder_ui:
		return
	if active_stage_controller == null or not active_stage_controller.has_method(method_name):
		return
	active_stage_controller.call(method_name, value)
	_refresh_profile_builder_popup()

func _rebuild_keybindings_list() -> void:
	_ensure_keybinding_state()
	if keybindings_list_vbox == null:
		return
	for child: Node in keybindings_list_vbox.get_children():
		child.queue_free()
	keybinding_buttons_by_action.clear()
	var entries: Array = keybinding_state.call("get_action_entries") as Array
	for entry_variant in entries:
		var entry: Dictionary = entry_variant as Dictionary
		var action_name := StringName(entry.get("action", StringName()))
		var row := HBoxContainer.new()
		row.name = "KeybindingRow_%s" % String(action_name)
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keybindings_list_vbox.add_child(row)

		var action_label := Label.new()
		action_label.name = "ActionLabel"
		action_label.text = String(entry.get("display_name", String(action_name)))
		action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_label.clip_text = true
		row.add_child(action_label)

		var binding_button := Button.new()
		binding_button.name = "BindingButton"
		binding_button.text = String(entry.get("binding_label", "Unbound"))
		binding_button.custom_minimum_size = Vector2(190.0, 30.0)
		binding_button.focus_mode = Control.FOCUS_NONE
		binding_button.pressed.connect(_begin_keybinding_capture.bind(action_name, binding_button))
		row.add_child(binding_button)
		keybinding_buttons_by_action[action_name] = binding_button

func _begin_keybinding_capture(action_name: StringName, binding_button: Button) -> void:
	_cancel_keybinding_capture()
	keybinding_capture_action = action_name
	keybinding_capture_button = binding_button
	keybinding_capture_keyboard_data = {}
	if keybinding_capture_button != null:
		keybinding_capture_button.text = "Press keys to bind"
		keybinding_capture_button.modulate = Color(1.0, 1.0, 1.0, 0.5)

func _cancel_keybinding_capture() -> void:
	if keybinding_capture_button != null and keybinding_capture_action != StringName():
		keybinding_capture_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		keybinding_capture_button.text = _get_v2_binding_label(keybinding_capture_action)
	keybinding_capture_action = StringName()
	keybinding_capture_button = null
	keybinding_capture_keyboard_data = {}

func _commit_keybinding_capture(binding_data: Dictionary) -> void:
	if keybinding_capture_action == StringName():
		return
	_ensure_keybinding_state()
	var committed_action := keybinding_capture_action
	keybinding_state.call("set_binding_data", keybinding_capture_action, binding_data)
	_persist_keybinding_state()
	if keybinding_capture_button != null:
		keybinding_capture_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		keybinding_capture_button.text = _get_v2_binding_label(committed_action)
	keybinding_capture_action = StringName()
	keybinding_capture_button = null
	keybinding_capture_keyboard_data = {}
	_rebuild_keybindings_list()

func _is_keybinding_capture_active() -> bool:
	return keybinding_capture_action != StringName()

func _handle_keybinding_capture_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.echo:
			return
		if key_event.pressed:
			if key_event.physical_keycode == KEY_ESCAPE:
				_cancel_keybinding_capture()
				get_viewport().set_input_as_handled()
				return
			if keybinding_capture_keyboard_data.is_empty():
				keybinding_capture_keyboard_data = ForgeV2KeybindingStateScript.build_binding_data_from_key_event(key_event)
			else:
				keybinding_capture_keyboard_data = ForgeV2KeybindingStateScript.append_secondary_key_event(
					keybinding_capture_keyboard_data,
					key_event
				)
			get_viewport().set_input_as_handled()
			return
		if not keybinding_capture_keyboard_data.is_empty():
			_commit_keybinding_capture(keybinding_capture_keyboard_data)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		var binding_data := ForgeV2KeybindingStateScript.build_binding_data_from_mouse_event(
			mouse_event,
			keybinding_capture_keyboard_data
		)
		_commit_keybinding_capture(binding_data)
		get_viewport().set_input_as_handled()

func _on_reset_keybindings_pressed() -> void:
	_ensure_keybinding_state()
	keybinding_state.call("reset_all_to_defaults")
	_persist_keybinding_state()
	_cancel_keybinding_capture()
	_rebuild_keybindings_list()

func _persist_keybinding_state() -> void:
	if keybinding_state != null and keybinding_state.has_method("persist"):
		keybinding_state.call("persist")

func _get_v2_binding_label(action_name: StringName) -> String:
	_ensure_keybinding_state()
	return String(keybinding_state.call("get_binding_label", action_name))

func _v2_event_matches_binding(action_name: StringName, event: InputEvent) -> bool:
	_ensure_keybinding_state()
	return bool(keybinding_state.call("event_matches_action", action_name, event))

func _get_v2_binding_mouse_button(action_name: StringName) -> int:
	_ensure_keybinding_state()
	var binding_data: Dictionary = keybinding_state.call("get_binding_data", action_name) as Dictionary
	return int(binding_data.get("mouse_button", MOUSE_BUTTON_NONE))

func _prepare_v2_submenu(parent_popup: PopupMenu, submenu_name: String) -> PopupMenu:
	var submenu := parent_popup.get_node_or_null(submenu_name) as PopupMenu
	if submenu == null:
		submenu = PopupMenu.new()
		submenu.name = submenu_name
		parent_popup.add_child(submenu)
	submenu.clear()
	_connect_v2_popup(submenu)
	return submenu

func _register_v2_menu_action(action_id: StringName, action_value: Variant = null) -> int:
	var menu_id := menu_next_id
	menu_next_id += 1
	menu_action_lookup[menu_id] = {
		"action": action_id,
		"value": action_value,
	}
	return menu_id

func _add_v2_menu_action(
	popup: PopupMenu,
	label: String,
	action_id: StringName,
	action_value: Variant = null,
	disabled: bool = false
) -> void:
	popup.add_item(label, _register_v2_menu_action(action_id, action_value))
	if disabled:
		popup.set_item_disabled(popup.get_item_count() - 1, true)

func _add_v2_disabled_line(popup: PopupMenu, label: String) -> void:
	popup.add_item(label)
	popup.set_item_disabled(popup.get_item_count() - 1, true)

func _add_v2_option_items(
	popup: PopupMenu,
	options: Array,
	action_id: StringName,
	active_value: Variant
) -> void:
	if options.is_empty():
		_add_v2_disabled_line(popup, "No options")
		return
	for option in options:
		var option_dict: Dictionary = option as Dictionary
		var option_value: Variant = option_dict.get("id", StringName())
		var label := String(option_dict.get("label", String(option_value)))
		popup.add_radio_check_item(label, _register_v2_menu_action(action_id, option_value))
		popup.set_item_checked(popup.get_item_count() - 1, option_value == active_value)

func _add_v2_saved_profile_items(
	popup: PopupMenu,
	saved_profiles: Array,
	action_id: StringName,
	active_profile_id: StringName
) -> void:
	if saved_profiles.is_empty():
		_add_v2_disabled_line(popup, "No saved profiles")
		return
	for profile_variant: Variant in saved_profiles:
		var profile: Dictionary = profile_variant as Dictionary
		if profile.is_empty():
			continue
		var profile_id := StringName(profile.get("profile_id", StringName()))
		var label := String(profile.get("label", String(profile_id)))
		popup.add_radio_check_item(label, _register_v2_menu_action(action_id, profile_id))
		popup.set_item_checked(popup.get_item_count() - 1, profile_id == active_profile_id)

func _register_profile_builder_action(action_id: StringName, action_value: Variant = null) -> int:
	var menu_id := profile_builder_next_id
	profile_builder_next_id += 1
	profile_builder_action_lookup[menu_id] = {
		"action": action_id,
		"value": action_value,
	}
	return menu_id

func _add_profile_builder_disabled_line(popup: PopupMenu, label: String) -> void:
	popup.add_item(label)
	popup.set_item_disabled(popup.get_item_count() - 1, true)

func _add_profile_builder_option_items(
	popup: PopupMenu,
	options: Array,
	action_id: StringName,
	active_value: Variant
) -> void:
	if options.is_empty():
		_add_profile_builder_disabled_line(popup, "No options")
		return
	for option in options:
		var option_dict: Dictionary = option as Dictionary
		var option_value: Variant = option_dict.get("id", StringName())
		var label := String(option_dict.get("label", String(option_value)))
		popup.add_radio_check_item(label, _register_profile_builder_action(action_id, option_value))
		popup.set_item_checked(popup.get_item_count() - 1, option_value == active_value)

func _get_v2_controller_options(method_name: StringName) -> Array:
	if active_stage_controller == null or not active_stage_controller.has_method(method_name):
		return []
	return active_stage_controller.call(method_name) as Array

func _get_player_forge_wip_library_state() -> PlayerForgeWipLibraryState:
	if active_player == null or not active_player.has_method("get_forge_wip_library_state"):
		return null
	return active_player.call("get_forge_wip_library_state") as PlayerForgeWipLibraryState

func _collect_saved_v2_wips() -> Array[CraftedItemWIP]:
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	if wip_library == null:
		return []
	var saved_v2_wips: Array[CraftedItemWIP] = []
	for saved_wip: CraftedItemWIP in wip_library.get_saved_wips():
		if saved_wip == null or saved_wip.forge_v2_authoring_state == null:
			continue
		saved_v2_wips.append(saved_wip)
	return saved_v2_wips

func _format_saved_v2_wip_label(saved_wip: CraftedItemWIP) -> String:
	if saved_wip == null:
		return "Unnamed V2 Draft"
	var project_name := saved_wip.forge_project_name.strip_edges()
	return project_name if not project_name.is_empty() else String(saved_wip.wip_id)

func _rebuild_v2_action_menus() -> void:
	if draft_menu_button == null or build_menu_button == null or material_menu_button == null:
		return
	menu_action_lookup.clear()
	menu_next_id = MENU_ID_BASE
	var summary: Dictionary = active_stage_controller.get_status_summary() if active_stage_controller != null else {}
	_rebuild_v2_draft_menu(summary)
	_rebuild_v2_build_menu(summary)
	_rebuild_v2_material_menu(summary)
	_rebuild_v2_shape_menu(summary)
	_rebuild_v2_layers_menu(summary)
	_rebuild_v2_view_menu()
	_rebuild_v2_status_menu(summary)
	_sync_v2_action_status(summary)

func _rebuild_v2_draft_menu(summary: Dictionary) -> void:
	var popup: PopupMenu = draft_menu_button.get_popup()
	popup.clear()
	var has_draft := active_stage_controller != null
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	var saved_v2_wips: Array[CraftedItemWIP] = _collect_saved_v2_wips()
	var source_wip_id := StringName(summary.get("source_wip_id", StringName()))
	var saved_label := "Saved WIP: %s" % String(source_wip_id) if source_wip_id != StringName() else "Unsaved V2 draft"
	_add_v2_disabled_line(popup, saved_label)
	_add_v2_menu_action(popup, "Save Draft (Ctrl+S)", &"draft_save", null, not has_draft or wip_library == null)
	popup.add_separator()
	_add_v2_menu_action(popup, "New V2 Draft", &"draft_new", null, not has_draft)
	_add_v2_menu_action(
		popup,
		"Clear Pending Work",
		&"draft_clear",
		null,
		not has_draft or int(summary.get("pending_material_body_count", 0)) <= 0
	)
	popup.add_separator()
	var saved_submenu: PopupMenu = _prepare_v2_submenu(popup, "SavedV2DraftSubmenu")
	if saved_v2_wips.is_empty():
		_add_v2_disabled_line(saved_submenu, "No saved V2 drafts")
	else:
		for saved_wip: CraftedItemWIP in saved_v2_wips:
			_add_v2_menu_action(
				saved_submenu,
				_format_saved_v2_wip_label(saved_wip),
				&"draft_load_saved",
				saved_wip.wip_id
			)
	popup.add_submenu_item("Saved V2 Drafts", String(saved_submenu.name))
	popup.set_item_disabled(popup.get_item_count() - 1, saved_v2_wips.is_empty())
	popup.add_separator()
	_add_v2_menu_action(popup, "Close Forge", &"close")

func _rebuild_v2_build_menu(summary: Dictionary) -> void:
	var popup: PopupMenu = build_menu_button.get_popup()
	popup.clear()
	_add_v2_disabled_line(popup, "Path: %s" % String(summary.get("builder_scope", "No draft")))
	var path_submenu: PopupMenu = _prepare_v2_submenu(popup, "BuilderPathSubmenu")
	_add_v2_option_items(
		path_submenu,
		_get_v2_controller_options(&"get_builder_path_options"),
		&"builder_path",
		summary.get("builder_path", StringName())
	)
	popup.add_submenu_item("Builder Path", String(path_submenu.name))
	var component_submenu: PopupMenu = _prepare_v2_submenu(popup, "BuilderComponentSubmenu")
	_add_v2_option_items(
		component_submenu,
		_get_v2_controller_options(&"get_builder_component_options"),
		&"builder_component",
		summary.get("builder_component", StringName())
	)
	popup.add_submenu_item("Component", String(component_submenu.name))
	popup.add_separator()
	var operation_submenu: PopupMenu = _prepare_v2_submenu(popup, "OperationSubmenu")
	_add_v2_option_items(
		operation_submenu,
		_get_v2_controller_options(&"get_operation_options"),
		&"operation",
		summary.get("operation", StringName())
	)
	popup.add_submenu_item("Operation", String(operation_submenu.name))
	var placement_submenu: PopupMenu = _prepare_v2_submenu(popup, "PlacementPolicySubmenu")
	_add_v2_option_items(
		placement_submenu,
		_get_v2_controller_options(&"get_placement_policy_options"),
		&"placement_policy",
		summary.get("placement_policy", StringName())
	)
	popup.add_submenu_item("Placement Policy", String(placement_submenu.name))

func _rebuild_v2_material_menu(summary: Dictionary) -> void:
	var popup: PopupMenu = material_menu_button.get_popup()
	popup.clear()
	_add_v2_disabled_line(popup, "Active: %s" % String(summary.get("active_material_label", "No material")))
	var material_submenu: PopupMenu = _prepare_v2_submenu(popup, "MaterialVariantSubmenu")
	_add_v2_option_items(
		material_submenu,
		_get_v2_controller_options(&"get_material_palette_options"),
		&"material",
		summary.get("active_material", StringName())
	)
	popup.add_submenu_item("Material Variant", String(material_submenu.name))
	var tier_policy: Dictionary = summary.get("material_tier_policy", {}) as Dictionary
	if not tier_policy.is_empty():
		popup.add_separator()
		_add_v2_disabled_line(popup, String(tier_policy.get("summary", "Tier policy active")))

func _rebuild_v2_shape_menu(summary: Dictionary) -> void:
	var popup: PopupMenu = shape_menu_button.get_popup()
	popup.clear()
	_add_v2_disabled_line(popup, "Tool: %s" % String(summary.get("active_tool_label", "None")))
	var tool_submenu: PopupMenu = _prepare_v2_submenu(popup, "ToolSubmenu")
	_add_v2_option_items(
		tool_submenu,
		_get_v2_controller_options(&"get_tool_options"),
		&"tool",
		summary.get("active_tool", StringName())
	)
	popup.add_submenu_item("Tool", String(tool_submenu.name))
	popup.add_separator()
	var active_tool_id := StringName(summary.get("active_tool", StringName()))
	if active_tool_id == &"tool_handles":
		_add_v2_disabled_line(popup, "Profile: %s" % String(summary.get("active_profile_label", "None")))
		var handle_profiles_submenu: PopupMenu = _prepare_v2_submenu(popup, "HandleProfilesSubmenu")
		var saved_profiles_submenu: PopupMenu = _prepare_v2_submenu(handle_profiles_submenu, "HandleSavedProfilesSubmenu")
		_add_v2_saved_profile_items(
			saved_profiles_submenu,
			_get_saved_handle_profiles(),
			&"handle_saved_profile",
			active_saved_profile_id
		)
		handle_profiles_submenu.add_submenu_item("Saved Profiles", String(saved_profiles_submenu.name))
		var preset_profiles_submenu: PopupMenu = _prepare_v2_submenu(handle_profiles_submenu, "HandlePresetProfilesSubmenu")
		_add_v2_disabled_line(preset_profiles_submenu, "No presets yet")
		handle_profiles_submenu.add_submenu_item("Presets", String(preset_profiles_submenu.name))
		popup.add_submenu_item("Handle Profiles", String(handle_profiles_submenu.name))
		_add_v2_disabled_line(popup, String(summary.get("profile_extrusion_status_label", "Handle: needs 3 points")))
		_add_v2_menu_action(
			popup,
			"Generate Handle",
			&"profile_generate_extrusion",
			null,
			active_stage_controller == null or not bool(summary.get("can_generate_profile_extrusion", false))
		)
		popup.add_separator()
	elif active_tool_id == &"tool_volume_stroke" or active_tool_id == &"tool_spline_line":
		_add_v2_disabled_line(popup, "Profile: %s" % String(summary.get("active_profile_label", "None")))
		var tool_profiles_submenu: PopupMenu = _prepare_v2_submenu(popup, "Tool2DProfilesSubmenu")
		var saved_profiles_submenu: PopupMenu = _prepare_v2_submenu(tool_profiles_submenu, "Tool2DSavedProfilesSubmenu")
		_add_v2_saved_profile_items(
			saved_profiles_submenu,
			_get_saved_basic_profiles(),
			&"basic_saved_profile",
			active_saved_profile_id
		)
		tool_profiles_submenu.add_submenu_item("Saved Profiles", String(saved_profiles_submenu.name))
		var preset_profiles_submenu: PopupMenu = _prepare_v2_submenu(tool_profiles_submenu, "Tool2DPresetProfilesSubmenu")
		_add_v2_option_items(
			preset_profiles_submenu,
			_get_v2_controller_options(&"get_profile_options"),
			&"profile",
			summary.get("active_profile", StringName())
		)
		tool_profiles_submenu.add_submenu_item("Presets", String(preset_profiles_submenu.name))
		popup.add_submenu_item("2D Profiles", String(tool_profiles_submenu.name))
		popup.add_separator()
	_add_v2_disabled_line(popup, String(summary.get("spline_line_status_label", "Spline: no points")))
	var spline_point_count := int(summary.get("spline_line_point_count", 0))
	var spline_finished := bool(summary.get("spline_line_finished", false))
	var finish_spline_label := "Finish Handle Path" if active_tool_id == &"tool_handles" else "Finish Spline Line"
	_add_v2_menu_action(
		popup,
		finish_spline_label,
		&"spline_finish",
		null,
		active_stage_controller == null or spline_point_count < 2 or spline_finished
	)
	_add_v2_menu_action(
		popup,
		"Cancel Spline Line",
		&"spline_cancel",
		null,
		active_stage_controller == null or spline_point_count <= 0
	)
	var csg_noodle_enabled := bool(summary.get("spline_line_csg_noodle_enabled", false))
	_add_v2_disabled_line(popup, String(summary.get("spline_line_csg_noodle_status_label", "CSG noodle: needs 2 points")))
	_add_v2_menu_action(
		popup,
		"Generate CSG Noodle",
		&"spline_generate_csg_noodle",
		null,
		active_stage_controller == null or not bool(summary.get("can_generate_spline_line_csg_noodle", false))
	)
	_add_v2_menu_action(
		popup,
		"Clear CSG Noodle",
		&"spline_clear_csg_noodle",
		null,
		active_stage_controller == null or not csg_noodle_enabled
	)
	popup.add_separator()
	_add_v2_disabled_line(popup, "Primitive: %s" % String(summary.get("active_primitive_label", "None")))
	var primitive_submenu: PopupMenu = _prepare_v2_submenu(popup, "PrimitiveSubmenu")
	_add_v2_option_items(
		primitive_submenu,
		_get_v2_controller_options(&"get_primitive_options"),
		&"primitive",
		summary.get("active_primitive", StringName())
	)
	popup.add_submenu_item("Primitive", String(primitive_submenu.name))
	popup.add_separator()
	_add_v2_disabled_line(popup, String(summary.get("brush_radius_label", "Radius n/a")))
	_add_v2_menu_action(popup, "Radius -", &"radius_down", null, active_stage_controller == null)
	_add_v2_menu_action(popup, "Radius +", &"radius_up", null, active_stage_controller == null)

func _rebuild_v2_layers_menu(summary: Dictionary) -> void:
	var popup: PopupMenu = layers_menu_button.get_popup()
	popup.clear()
	var has_draft := active_stage_controller != null
	_add_v2_menu_action(popup, "Add Primitive Deposit", &"add_primitive", null, not has_draft)
	_add_v2_menu_action(
		popup,
		"Commit Pending Layer",
		&"commit_layer",
		null,
		not has_draft or int(summary.get("pending_material_body_count", 0)) <= 0
	)
	_add_v2_menu_action(
		popup,
		"Undo Layer",
		&"undo_layer",
		null,
		not has_draft or int(summary.get("committed_layer_count", 0)) <= 0
	)
	_add_v2_menu_action(
		popup,
		"Redo Layer",
		&"redo_layer",
		null,
		not has_draft or int(summary.get("undone_layer_count", 0)) <= 0
	)
	popup.add_separator()
	var body_submenu: PopupMenu = _prepare_v2_submenu(popup, "BodyStackSubmenu")
	_add_v2_option_items(
		body_submenu,
		_get_v2_controller_options(&"get_material_body_stack_options"),
		&"select_body",
		summary.get("selected_material_body_id", StringName())
	)
	popup.add_submenu_item("Body Stack", String(body_submenu.name))
	var selected_body_summary: Dictionary = summary.get("selected_material_body", {}) as Dictionary
	var delete_disabled := (
		not has_draft
		or selected_body_summary.is_empty()
		or bool(selected_body_summary.get("is_seed", false))
		or bool(selected_body_summary.get("is_committed", false))
	)
	_add_v2_menu_action(popup, "Delete Selected Body", &"delete_body", null, delete_disabled)

func _rebuild_v2_view_menu() -> void:
	var popup: PopupMenu = view_menu_button.get_popup()
	popup.clear()
	_add_v2_menu_action(popup, "Fit View", &"view_fit", null, workspace_preview == null)
	_add_v2_menu_action(popup, "Reset View", &"view_reset", null, workspace_preview == null)
	popup.add_separator()
	_add_v2_menu_action(popup, "Zoom In", &"view_zoom_in", null, workspace_preview == null)
	_add_v2_menu_action(popup, "Zoom Out", &"view_zoom_out", null, workspace_preview == null)

func _rebuild_v2_status_menu(summary: Dictionary) -> void:
	var popup: PopupMenu = status_menu_button.get_popup()
	popup.clear()
	_add_v2_disabled_line(popup, "Forge Status")
	_add_v2_disabled_line(popup, "Draft: %s" % String(summary.get("project_name", "No draft")))
	_add_v2_disabled_line(popup, "Build: %s" % String(summary.get("builder_scope", "n/a")))
	_add_v2_disabled_line(popup, "Operation: %s" % String(summary.get("operation_label", "n/a")))
	_add_v2_disabled_line(popup, "Placement: %s" % String(summary.get("placement_policy_label", "n/a")))
	_add_v2_disabled_line(popup, "Material: %s" % String(summary.get("active_material_label", "n/a")))
	_add_v2_disabled_line(popup, "Primitive: %s" % String(summary.get("active_primitive_label", "n/a")))
	_add_v2_disabled_line(popup, "Profile: %s" % String(summary.get("active_profile_label", "n/a")))
	_add_v2_disabled_line(popup, String(summary.get("brush_radius_label", "Radius n/a")))
	_add_v2_disabled_line(popup, "Bodies: %s user + %s seed, %s pending" % [
		str(int(summary.get("user_material_body_count", 0))),
		str(int(summary.get("seed_material_body_count", 0))),
		str(int(summary.get("pending_material_body_count", 0))),
	])
	_add_v2_disabled_line(popup, "Layers: %s committed, %s redo" % [
		str(int(summary.get("committed_layer_count", 0))),
		str(int(summary.get("undone_layer_count", 0))),
	])
	_add_v2_disabled_line(popup, String(summary.get("material_ledger_label", "Ledger n/a")))

func _sync_v2_action_status(summary: Dictionary) -> void:
	if action_status_label == null:
		return
	action_status_label.text = "%s | %s | %s | %s" % [
		String(summary.get("builder_scope", "No draft")),
		String(summary.get("active_tool_label", "No tool")),
		String(summary.get("active_material_label", "No material")),
		String(summary.get("brush_radius_label", "Radius n/a")),
	]

func _on_v2_menu_id_pressed(menu_id: int) -> void:
	var menu_entry: Dictionary = menu_action_lookup.get(menu_id, {}) as Dictionary
	if menu_entry.is_empty():
		return
	var action_id := StringName(menu_entry.get("action", StringName()))
	var action_value: Variant = menu_entry.get("value", null)
	var keep_shape_popup_open := _is_v2_shape_repeat_action(action_id)
	match action_id:
		&"draft_save":
			_save_current_v2_draft()
		&"draft_new":
			_on_new_draft_pressed()
		&"draft_clear":
			_on_clear_strokes_pressed()
		&"draft_load_saved":
			_load_saved_v2_draft(StringName(action_value))
		&"builder_path":
			if active_stage_controller != null:
				active_stage_controller.set_builder_path_id(StringName(action_value))
		&"builder_component":
			if active_stage_controller != null:
				active_stage_controller.set_builder_component_id(StringName(action_value))
		&"operation":
			if active_stage_controller != null:
				active_stage_controller.set_active_operation_mode(StringName(action_value))
		&"placement_policy":
			if active_stage_controller != null:
				active_stage_controller.set_placement_policy(StringName(action_value))
		&"material":
			if active_stage_controller != null:
				active_stage_controller.set_active_material_variant_id(StringName(action_value))
		&"primitive":
			if active_stage_controller != null:
				active_stage_controller.set_active_primitive_id(StringName(action_value))
		&"tool":
			var next_tool_id := StringName(action_value)
			if next_tool_id == &"tool_handles":
				_select_profile_builder_handle_builder()
			elif active_stage_controller != null:
				active_saved_profile_id = StringName()
				active_stage_controller.set_active_tool_id(next_tool_id)
		&"profile":
			if active_stage_controller != null and active_stage_controller.has_method("set_active_profile_id"):
				active_saved_profile_id = StringName()
				active_stage_controller.call("set_active_profile_id", StringName(action_value))
		&"basic_saved_profile":
			_load_saved_tool_profile(StringName(action_value))
		&"handle_saved_profile":
			_load_saved_tool_profile(StringName(action_value))
		&"spline_finish":
			_finish_active_spline_line()
		&"spline_cancel":
			_cancel_active_spline_line()
		&"spline_generate_csg_noodle":
			_generate_active_spline_csg_noodle()
		&"profile_generate_extrusion":
			_generate_active_profile_extrusion()
		&"spline_clear_csg_noodle":
			_clear_active_spline_csg_noodle()
		&"radius_down":
			_on_radius_decrease_pressed()
		&"radius_up":
			_on_radius_increase_pressed()
		&"add_primitive":
			_on_add_empty_stroke_pressed()
		&"commit_layer":
			_on_commit_pending_pressed()
		&"undo_layer":
			_on_undo_layer_pressed()
		&"redo_layer":
			_on_redo_layer_pressed()
		&"select_body":
			if active_stage_controller != null:
				active_stage_controller.select_material_body_id(StringName(action_value))
		&"delete_body":
			_on_delete_selected_body_pressed()
		&"view_fit":
			_call_workspace_preview_action(&"fit_view")
		&"view_reset":
			_call_workspace_preview_action(&"reset_view")
		&"view_zoom_in":
			_call_workspace_preview_action(&"zoom_by", -WORKSPACE_ZOOM_STEP)
		&"view_zoom_out":
			_call_workspace_preview_action(&"zoom_by", WORKSPACE_ZOOM_STEP)
		&"close":
			close_ui()
	if keep_shape_popup_open:
		_refresh_v2_shape_menu_popup_contents()
	else:
		_rebuild_v2_action_menus()

func _on_profile_builder_menu_id_pressed(menu_id: int) -> void:
	var menu_entry: Dictionary = profile_builder_action_lookup.get(menu_id, {}) as Dictionary
	if menu_entry.is_empty():
		return
	var action_id := StringName(menu_entry.get("action", StringName()))
	var action_value: Variant = menu_entry.get("value", null)
	if active_stage_controller == null:
		return
	match action_id:
		&"profile_basic":
			if StringName(action_value) == ForgeV2ProfileShapeLibraryScript.PROFILE_2D_BUILDER:
				_select_profile_builder_basic_builder()
			else:
				active_saved_profile_id = StringName()
				if active_stage_controller.has_method("set_active_tool_id"):
					active_stage_controller.call("set_active_tool_id", &"tool_volume_stroke")
				if active_stage_controller.has_method("set_active_profile_id"):
					active_stage_controller.call("set_active_profile_id", StringName(action_value))
		&"profile_handle":
			_select_profile_builder_handle_builder()
		&"profile_saved_load":
			_load_saved_tool_profile(StringName(action_value))
		&"profile_saved_rename":
			_hide_saved_profile_context_menu()
			_open_rename_profile_name_popup(StringName(action_value))
		&"profile_saved_delete":
			_hide_saved_profile_context_menu()
			_delete_saved_profile(StringName(action_value))
	if action_id != &"profile_handle" and action_id != &"profile_saved_load" and action_id != &"profile_saved_delete":
		_refresh_from_controller()
		_refresh_profile_builder_popup()

func _is_v2_shape_repeat_action(action_id: StringName) -> bool:
	return (
		action_id == &"radius_down"
		or action_id == &"radius_up"
	)

func _refresh_v2_shape_menu_popup_contents() -> void:
	if not is_instance_valid(shape_menu_button):
		return
	call_deferred("_refresh_v2_shape_menu_popup_contents_if_available")

func _refresh_v2_shape_menu_popup_contents_if_available() -> void:
	if not is_instance_valid(shape_menu_button):
		return
	var popup: PopupMenu = shape_menu_button.get_popup()
	var popup_visible: bool = popup.visible
	var summary: Dictionary = active_stage_controller.get_status_summary() if active_stage_controller != null else {}
	_rebuild_v2_shape_menu(summary)
	_sync_v2_action_status(summary)
	if popup_visible and not popup.visible:
		shape_menu_button.show_popup()

func _call_workspace_preview_action(method_name: StringName, argument: Variant = null) -> void:
	_ensure_workspace_preview()
	if workspace_preview == null or not workspace_preview.has_method(method_name):
		return
	if argument == null:
		workspace_preview.call(method_name)
	else:
		workspace_preview.call(method_name, argument)

func _set_active_v2_tool(tool_id: StringName) -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("set_active_tool_id"):
		return
	if workspace_brush_stroke_active:
		_finish_workspace_brush_stroke(Vector2.ZERO, false)
	_finish_workspace_spline_point_drag()
	if tool_id == &"tool_handles":
		_select_profile_builder_handle_builder()
	else:
		active_saved_profile_id = StringName()
		active_stage_controller.call("set_active_tool_id", tool_id)

func _finish_active_spline_line() -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("finish_spline_line"):
		return
	_finish_workspace_spline_point_drag()
	active_stage_controller.call("finish_spline_line")

func _cancel_active_spline_line() -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("cancel_spline_line"):
		return
	_finish_workspace_spline_point_drag()
	active_stage_controller.call("cancel_spline_line")

func _generate_active_spline_csg_noodle() -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("generate_spline_line_csg_noodle"):
		return
	_finish_workspace_spline_point_drag()
	active_stage_controller.call("generate_spline_line_csg_noodle")

func _generate_active_profile_extrusion() -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("generate_profile_extrusion_from_spline"):
		return
	_finish_workspace_spline_point_drag()
	active_stage_controller.call("generate_profile_extrusion_from_spline")

func _clear_active_spline_csg_noodle() -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("clear_spline_line_csg_noodle"):
		return
	active_stage_controller.call("clear_spline_line_csg_noodle")

func _save_current_v2_draft() -> bool:
	if active_stage_controller == null or not active_stage_controller.has_method("save_current_wip"):
		_set_v2_action_status_text("Save failed: no V2 draft")
		return false
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	if wip_library == null:
		_set_v2_action_status_text("Save failed: no WIP library")
		return false
	if workspace_brush_stroke_active:
		_finish_workspace_brush_stroke(Vector2.ZERO, false)
	_finish_workspace_spline_point_drag()
	var saved_wip: CraftedItemWIP = active_stage_controller.call("save_current_wip", wip_library) as CraftedItemWIP
	if saved_wip == null:
		_set_v2_action_status_text("Save failed")
		return false
	_configure_options_from_controller()
	_refresh_from_controller()
	_set_v2_action_status_text("Saved: %s" % _format_saved_v2_wip_label(saved_wip))
	return true

func _load_saved_v2_draft(saved_wip_id: StringName) -> bool:
	if active_stage_controller == null or not active_stage_controller.has_method("load_saved_wip"):
		_set_v2_action_status_text("Load failed: no V2 controller")
		return false
	var wip_library: PlayerForgeWipLibraryState = _get_player_forge_wip_library_state()
	if wip_library == null or saved_wip_id == StringName():
		_set_v2_action_status_text("Load failed: no saved draft")
		return false
	var saved_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(saved_wip_id, false)
	if saved_wip == null or saved_wip.forge_v2_authoring_state == null:
		_set_v2_action_status_text("Load failed: V2 data missing")
		return false
	if workspace_brush_stroke_active:
		_finish_workspace_brush_stroke(Vector2.ZERO, false)
	_finish_workspace_spline_point_drag()
	var loaded := bool(active_stage_controller.call("load_saved_wip", saved_wip))
	if not loaded:
		_set_v2_action_status_text("Load failed")
		return false
	wip_library.set_selected_wip_id(saved_wip_id)
	_configure_options_from_controller()
	_refresh_from_controller()
	_set_v2_action_status_text("Loaded: %s" % _format_saved_v2_wip_label(saved_wip))
	return true

func _set_v2_action_status_text(status_text: String) -> void:
	if action_status_label != null:
		action_status_label.text = status_text

func _is_v2_path_point_tool_active() -> bool:
	if active_stage_controller == null or not active_stage_controller.has_method("get_status_summary"):
		return false
	var summary: Dictionary = active_stage_controller.call("get_status_summary") as Dictionary
	var active_tool_id := StringName(summary.get("active_tool", StringName()))
	return active_tool_id == &"tool_spline_line" or active_tool_id == &"tool_handles"

func _ensure_fullscreen_workspace_layout() -> void:
	if body_margin == null or body_scroll == null or body_vbox == null or workspace_panel == null:
		return
	body_layout_hbox = body_margin.get_node_or_null("BodyHBox") as HBoxContainer
	if body_layout_hbox == null:
		body_layout_hbox = HBoxContainer.new()
		body_layout_hbox.name = "BodyHBox"
		body_layout_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_layout_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_layout_hbox.add_theme_constant_override("separation", 12)
		body_margin.add_child(body_layout_hbox)
	if body_scroll.get_parent() != body_layout_hbox:
		body_scroll.reparent(body_layout_hbox)
	if workspace_panel.get_parent() != body_layout_hbox:
		workspace_panel.reparent(body_layout_hbox)
	body_layout_hbox.move_child(body_scroll, 0)
	body_layout_hbox.move_child(workspace_panel, 1)
	_apply_fullscreen_workspace_layout()

func _apply_fullscreen_workspace_layout() -> void:
	if panel == null or body_panel == null or body_scroll == null or body_vbox == null or workspace_panel == null:
		return
	_ensure_workspace_frame_host()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var compact_layout: bool = viewport_size.x <= COMPACT_LAYOUT_WIDTH or viewport_size.y <= COMPACT_LAYOUT_HEIGHT
	var ultra_compact_layout: bool = viewport_size.x <= ULTRA_COMPACT_LAYOUT_WIDTH or viewport_size.y <= ULTRA_COMPACT_LAYOUT_HEIGHT
	var root_margin_px := 2 if ultra_compact_layout else 6 if compact_layout else 10
	var body_margin_px := 2 if ultra_compact_layout else 4 if compact_layout else 8
	var workspace_margin_px := 2 if ultra_compact_layout else 4 if compact_layout else 8
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	_apply_margin(root_margin, root_margin_px)
	_apply_margin(body_margin, body_margin_px)
	_apply_margin(workspace_margin, workspace_margin_px)
	if root_vbox != null:
		root_vbox.add_theme_constant_override("separation", 3 if ultra_compact_layout else 6 if compact_layout else 10)
	_apply_v2_header_layout(compact_layout, ultra_compact_layout)
	_apply_v2_action_bar_layout(compact_layout, ultra_compact_layout)
	_apply_v2_workspace_chrome_layout(compact_layout)
	body_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if body_layout_hbox != null:
		body_layout_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_layout_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_layout_hbox.add_theme_constant_override("separation", 0)
	body_scroll.visible = false
	body_scroll.custom_minimum_size = Vector2.ZERO
	body_scroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_vbox.custom_minimum_size = Vector2.ZERO
	workspace_panel.custom_minimum_size = Vector2.ZERO
	workspace_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if workspace_frame_host != null:
		workspace_frame_host.custom_minimum_size = Vector2.ZERO
		workspace_frame_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		workspace_frame_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_view_container.custom_minimum_size = Vector2.ZERO
	workspace_view_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	workspace_view_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if action_host_row != null:
		action_host_row.add_theme_constant_override("separation", 2 if ultra_compact_layout else 4 if compact_layout else 6)
	_apply_v2_fit_scale(viewport_size)
	call_deferred("_sync_workspace_frame_layout")

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if _is_keybinding_capture_active():
		if (
			is_instance_valid(keybindings_popup)
			and keybindings_popup.visible
			and keybindings_popup.has_focus()
		):
			_handle_keybinding_capture_input(event)
			return
		if (
			not is_instance_valid(keybindings_popup)
			or not keybindings_popup.visible
		):
			_cancel_keybinding_capture()
	if event is InputEventKey and not _is_text_entry_focused() and _handle_profile_builder_metric_view_input(
		event,
		profile_builder_preview.get_local_mouse_position() if profile_builder_preview != null else Vector2.ZERO
	):
		get_viewport().set_input_as_handled()

func _is_text_entry_focused() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit

func _handle_profile_builder_metric_view_input(event: InputEvent, local_pointer: Vector2) -> bool:
	if (
		not is_instance_valid(profile_builder_popup)
		or not profile_builder_popup.visible
		or profile_builder_preview == null
		or not profile_builder_preview.has_method("is_metric_view_active")
		or not bool(profile_builder_preview.call("is_metric_view_active"))
	):
		_cancel_profile_builder_metric_pan()
		return false
	if event is InputEventKey and not profile_builder_popup.has_focus():
		return false
	if event is InputEventMouseMotion and profile_builder_metric_pan_active:
		var motion_event := event as InputEventMouseMotion
		profile_builder_preview.call("pan_metric_view_by", motion_event.relative)
		return true
	if event is InputEventMouseButton and profile_builder_metric_pan_active:
		var active_button_event := event as InputEventMouseButton
		if (
			not active_button_event.pressed
			and active_button_event.button_index == profile_builder_metric_pan_mouse_button
		):
			_cancel_profile_builder_metric_pan()
			return true
	if is_instance_valid(profile_fillet_popup) and profile_fillet_popup.visible:
		return true
	if not Rect2(Vector2.ZERO, profile_builder_preview.size).has_point(local_pointer):
		return false
	if _is_plain_space_center_event(event):
		_cancel_profile_builder_metric_pan()
		_hide_profile_canvas_context_menu()
		profile_builder_preview.call("center_metric_view")
		return true
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_VIEW_ZOOM_IN, event):
		_hide_profile_canvas_context_menu()
		profile_builder_preview.call("zoom_metric_view_at", local_pointer, true)
		return true
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_VIEW_ZOOM_OUT, event):
		_hide_profile_canvas_context_menu()
		profile_builder_preview.call("zoom_metric_view_at", local_pointer, false)
		return true
	if event is InputEventMouseButton:
		var mouse_button_event := event as InputEventMouseButton
		if _is_profile_canvas_plain_context_rmb(mouse_button_event):
			return false
		if (
			mouse_button_event.pressed
			and (
				_v2_event_matches_binding(
					ForgeV2KeybindingStateScript.ACTION_VIEW_PAN,
					mouse_button_event
				)
				or _v2_event_matches_binding(
					ForgeV2KeybindingStateScript.ACTION_VIEW_PAN_SECONDARY,
					mouse_button_event
				)
			)
		):
			_hide_profile_canvas_context_menu()
			profile_builder_metric_pan_active = true
			profile_builder_metric_pan_mouse_button = mouse_button_event.button_index
			return true
	return false

func _is_profile_canvas_plain_context_rmb(
	mouse_event: InputEventMouseButton
) -> bool:
	if (
		not mouse_event.pressed
		or mouse_event.button_index != MOUSE_BUTTON_RIGHT
		or mouse_event.ctrl_pressed
		or mouse_event.shift_pressed
		or mouse_event.alt_pressed
		or mouse_event.meta_pressed
		or profile_builder_preview == null
		or not bool(profile_builder_preview.get("canvas_context_enabled"))
	):
		return false
	return not (
		_v2_mouse_event_matches_keyboard_chord(
			ForgeV2KeybindingStateScript.ACTION_VIEW_PAN,
			mouse_event
		)
		or _v2_mouse_event_matches_keyboard_chord(
			ForgeV2KeybindingStateScript.ACTION_VIEW_PAN_SECONDARY,
			mouse_event
		)
	)

func _v2_mouse_event_matches_keyboard_chord(
	action_name: StringName,
	mouse_event: InputEventMouseButton
) -> bool:
	_ensure_keybinding_state()
	var binding_data: Dictionary = keybinding_state.call(
		"get_binding_data",
		action_name
	) as Dictionary
	var has_keyboard_key := (
		int(binding_data.get("physical_keycode", KEY_NONE)) != KEY_NONE
		or int(binding_data.get("keycode", KEY_NONE)) != KEY_NONE
		or int(binding_data.get(
			"secondary_physical_keycode",
			KEY_NONE
		)) != KEY_NONE
		or int(binding_data.get(
			"secondary_keycode",
			KEY_NONE
		)) != KEY_NONE
	)
	return (
		has_keyboard_key
		and _v2_event_matches_binding(action_name, mouse_event)
	)

func _is_plain_space_center_event(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	if (
		key_event.ctrl_pressed
		or key_event.shift_pressed
		or key_event.alt_pressed
		or key_event.meta_pressed
	):
		return false
	return key_event.physical_keycode == KEY_SPACE or key_event.keycode == KEY_SPACE

func _cancel_profile_builder_metric_pan() -> void:
	profile_builder_metric_pan_active = false
	profile_builder_metric_pan_mouse_button = MOUSE_BUTTON_NONE

func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"ui_cancel"):
		if _close_focused_temporary_window_layer():
			get_viewport().set_input_as_handled()
			return
		if _close_focused_major_workspace():
			get_viewport().set_input_as_handled()
			return
		var root_window := get_window()
		if not is_instance_valid(root_window) or not root_window.has_focus():
			get_viewport().set_input_as_handled()
			return
		close_ui()
		get_viewport().set_input_as_handled()
		return
	if _has_focused_window_layer():
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_SAVE_DRAFT, event):
		_save_current_v2_draft()
		get_viewport().set_input_as_handled()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_VIEW_FIT, event):
		_call_workspace_preview_action(&"fit_view")
		get_viewport().set_input_as_handled()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_VIEW_RESET, event):
		_call_workspace_preview_action(&"reset_view")
		get_viewport().set_input_as_handled()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_SPLINE_FINISH, event):
		_finish_active_spline_line()
		get_viewport().set_input_as_handled()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_SPLINE_CANCEL, event):
		_cancel_active_spline_line()
		get_viewport().set_input_as_handled()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_SPLINE_GENERATE_CSG_NOODLE, event):
		_generate_active_spline_csg_noodle()
		get_viewport().set_input_as_handled()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_TOOL_VOLUME_STROKE, event):
		_set_active_v2_tool(&"tool_volume_stroke")
		get_viewport().set_input_as_handled()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_TOOL_SPLINE_LINE, event):
		_set_active_v2_tool(&"tool_spline_line")
		get_viewport().set_input_as_handled()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_TOOL_HANDLES, event):
		_set_active_v2_tool(&"tool_handles")
		get_viewport().set_input_as_handled()

func _close_focused_temporary_window_layer() -> bool:
	var temporary_layers: Array[Window] = [
		profile_fillet_popup,
		profile_canvas_context_panel,
		keybindings_popup,
		profile_name_popup,
		profile_saved_profiles_context_panel,
		profile_saved_profiles_popup,
	]
	var target_layer: Window = null
	for candidate: Window in temporary_layers:
		if (
			is_instance_valid(candidate)
			and candidate.visible
			and candidate.has_focus()
		):
			target_layer = candidate
			break
	if target_layer == null:
		var focused_major: Window = null
		if (
			is_instance_valid(settings_popup)
			and settings_popup.visible
			and settings_popup.has_focus()
		):
			focused_major = settings_popup
		elif (
			is_instance_valid(profile_builder_popup)
			and profile_builder_popup.visible
			and profile_builder_popup.has_focus()
		):
			focused_major = profile_builder_popup
		if focused_major != null:
			for candidate: Window in temporary_layers:
				if (
					is_instance_valid(candidate)
					and candidate.visible
					and focused_major.is_ancestor_of(candidate)
				):
					target_layer = candidate
					break
	if target_layer == null:
		return false
	if target_layer == profile_fillet_popup:
		_close_profile_fillet_popup(true)
	elif target_layer == profile_canvas_context_panel:
		_hide_profile_canvas_context_menu()
	elif target_layer == keybindings_popup:
		_close_keybindings_popup()
	elif target_layer == profile_name_popup:
		_close_profile_name_popup()
	elif target_layer == profile_saved_profiles_context_panel:
		_hide_saved_profile_context_menu()
	elif target_layer == profile_saved_profiles_popup:
		_close_profile_saved_profiles_popup()
	return true

func _close_focused_major_workspace() -> bool:
	if (
		is_instance_valid(settings_popup)
		and settings_popup.visible
		and settings_popup.has_focus()
	):
		_close_settings_popup()
		return true
	if (
		is_instance_valid(profile_builder_popup)
		and profile_builder_popup.visible
		and profile_builder_popup.has_focus()
	):
		_close_profile_builder_popup()
		return true
	return false

func _has_focused_window_layer() -> bool:
	var window_layers: Array[Window] = [
		profile_fillet_popup,
		profile_canvas_context_panel,
		keybindings_popup,
		profile_name_popup,
		profile_saved_profiles_context_panel,
		profile_saved_profiles_popup,
		settings_popup,
		profile_builder_popup,
	]
	for candidate: Window in window_layers:
		if (
			is_instance_valid(candidate)
			and candidate.visible
			and candidate.has_focus()
		):
			return true
	return false

func _connect_stage_controller() -> void:
	if active_stage_controller == null:
		return
	if not active_stage_controller.authoring_state_changed.is_connected(_on_authoring_state_changed):
		active_stage_controller.authoring_state_changed.connect(_on_authoring_state_changed)

func _disconnect_stage_controller() -> void:
	if active_stage_controller == null:
		return
	if active_stage_controller.authoring_state_changed.is_connected(_on_authoring_state_changed):
		active_stage_controller.authoring_state_changed.disconnect(_on_authoring_state_changed)

func _configure_options_from_controller() -> void:
	if active_stage_controller == null:
		return
	_configure_option_button(builder_path_option, active_stage_controller.get_builder_path_options())
	_configure_option_button(builder_component_option, active_stage_controller.get_builder_component_options())
	_configure_option_button(operation_option, active_stage_controller.get_operation_options())
	_configure_option_button(placement_policy_option, active_stage_controller.get_placement_policy_options())
	_configure_option_button(primitive_option, active_stage_controller.get_primitive_options())

func _configure_option_button(option_button: OptionButton, options: Array[Dictionary]) -> void:
	option_button.clear()
	for option: Dictionary in options:
		var item_index: int = option_button.get_item_count()
		option_button.add_item(String(option.get("label", "")))
		option_button.set_item_metadata(item_index, option.get("id", StringName()))

func _refresh_from_controller() -> void:
	if active_stage_controller == null:
		status_label.text = "No V2 stage controller is attached."
		summary_label.text = ""
		_rebuild_v2_action_menus()
		if is_instance_valid(settings_popup) and settings_popup.visible:
			_refresh_settings_popup()
		if is_instance_valid(profile_builder_popup) and profile_builder_popup.visible:
			_refresh_profile_builder_popup()
		return
	is_refreshing_ui = true
	var summary: Dictionary = active_stage_controller.get_status_summary()
	_configure_option_button(builder_component_option, active_stage_controller.get_builder_component_options())
	_rebuild_material_palette(
		active_stage_controller.get_material_palette_options(),
		StringName(summary.get("active_material", StringName()))
	)
	_configure_body_stack_options(active_stage_controller.get_material_body_stack_options())
	_select_option_by_metadata(builder_path_option, _resolve_builder_path_from_state())
	_select_option_by_metadata(builder_component_option, summary.get("builder_component", StringName()))
	_select_option_by_metadata(operation_option, summary.get("operation", StringName()))
	_select_option_by_metadata(placement_policy_option, summary.get("placement_policy", StringName()))
	_select_option_by_metadata(primitive_option, summary.get("active_primitive", StringName()))
	_select_option_by_metadata(body_stack_option, summary.get("selected_material_body_id", StringName()))
	builder_component_row.visible = builder_component_option.get_item_count() > 1
	var selected_body_summary: Dictionary = summary.get("selected_material_body", {}) as Dictionary
	delete_selected_body_button.disabled = (
		selected_body_summary.is_empty()
		or bool(selected_body_summary.get("is_seed", false))
		or bool(selected_body_summary.get("is_committed", false))
	)
	commit_pending_button.disabled = int(summary.get("pending_material_body_count", 0)) <= 0
	undo_layer_button.disabled = int(summary.get("committed_layer_count", 0)) <= 0
	redo_layer_button.disabled = int(summary.get("undone_layer_count", 0)) <= 0
	status_label.text = "%s | %s | %s" % [
		String(summary.get("builder_scope", "")),
		String(summary.get("operation_label", "")),
		String(summary.get("placement_policy_label", "")),
	]
	var active_tool_id := StringName(summary.get("active_tool", StringName()))
	var workspace_status_parts: Array[String] = [String(summary.get("active_tool_label", ""))]
	if active_tool_id == &"tool_spline_line":
		workspace_status_parts.append(String(summary.get("spline_line_status_label", "Spline: no points")))
		workspace_status_parts.append(String(summary.get("spline_line_csg_noodle_status_label", "CSG noodle: needs 2 points")))
		workspace_status_parts.append(String(summary.get("brush_radius_label", "")))
	elif active_tool_id == &"tool_handles":
		workspace_status_parts.append(String(summary.get("active_profile_label", "No profile")))
		workspace_status_parts.append(String(summary.get("spline_line_status_label", "Spline: no points")))
		workspace_status_parts.append(String(summary.get("profile_extrusion_status_label", "Handle: needs 3 points")))
	else:
		workspace_status_parts.append(String(summary.get("brush_radius_label", "")))
	workspace_status_label.text = " | ".join(workspace_status_parts)
	platform_contract_label.text = String(summary.get("platform_contract_summary", ""))
	active_material_label.text = "Active: %s" % String(summary.get("active_material_label", summary.get("active_material", "")))
	radius_value_label.text = String(summary.get("brush_radius_label", "Radius 0.0000 m"))
	var platform_contract: Dictionary = summary.get("platform_contract", {}) as Dictionary
	summary_label.text = "Draft: %s\nTool: %s\nPrimitive: %s\nProfile: %s\nActive material: %s\nCSG bodies: %s user + %s seed, %s pending\n%s\n%s\n%s\nLayers: %s committed, %s redo\nSelected: %s\n%s\n%s\n%s\n%s" % [
		String(summary.get("project_name", "")),
		String(summary.get("active_tool_label", "")),
		String(summary.get("active_primitive_label", "")),
		String(summary.get("active_profile_label", "")),
		String(summary.get("active_material_label", summary.get("active_material", ""))),
		str(int(summary.get("user_material_body_count", 0))),
		str(int(summary.get("seed_material_body_count", 0))),
		str(int(summary.get("pending_material_body_count", 0))),
		String(summary.get("spline_line_status_label", "Spline: no points")),
		String(summary.get("spline_line_csg_noodle_status_label", "CSG noodle: needs 2 points")),
		String(summary.get("profile_extrusion_status_label", "Handle: needs 3 points")),
		str(int(summary.get("committed_layer_count", 0))),
		str(int(summary.get("undone_layer_count", 0))),
		String(selected_body_summary.get("label", "none")),
		String(summary.get("brush_radius_label", "")),
		String(summary.get("material_ledger_label", "")),
		String(summary.get("material_usage_label", "")),
		String(platform_contract.get("validation_note", "")),
	]
	is_refreshing_ui = false
	_rebuild_v2_action_menus()
	if is_instance_valid(settings_popup) and settings_popup.visible:
		_refresh_settings_popup()
	if is_instance_valid(profile_builder_popup) and profile_builder_popup.visible:
		_refresh_profile_builder_popup()

func _configure_body_stack_options(options: Array[Dictionary]) -> void:
	body_stack_option.clear()
	if options.is_empty():
		body_stack_option.add_item("No material bodies")
		body_stack_option.set_item_metadata(0, StringName())
		body_stack_option.disabled = true
		return
	body_stack_option.disabled = false
	for option: Dictionary in options:
		var item_index: int = body_stack_option.get_item_count()
		body_stack_option.add_item(String(option.get("label", "")))
		body_stack_option.set_item_metadata(item_index, option.get("id", StringName()))

func _rebuild_material_palette(options: Array[Dictionary], active_material_id: StringName) -> void:
	for child: Node in material_palette_grid.get_children():
		child.queue_free()
	for option: Dictionary in options:
		var material_id: StringName = StringName(option.get("id", StringName()))
		if material_id == StringName():
			continue
		var material_button := Button.new()
		var is_active: bool = material_id == active_material_id
		var material_color: Color = option.get("albedo_color", Color(0.8, 0.82, 0.84, 1.0))
		material_button.custom_minimum_size = MATERIAL_ICON_BUTTON_SIZE
		material_button.tooltip_text = "%s\n%s" % [
			String(option.get("label", String(material_id))),
			String(material_id),
		]
		material_button.toggle_mode = true
		material_button.focus_mode = Control.FOCUS_NONE
		material_button.icon = material_icon_texture
		material_button.expand_icon = true
		material_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		material_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		material_button.set_pressed_no_signal(is_active)
		_apply_material_button_theme(material_button, material_color, is_active)
		material_button.pressed.connect(_on_material_palette_pressed.bind(material_id))
		material_palette_grid.add_child(material_button)

func _apply_material_button_theme(button: Button, material_color: Color, is_active: bool) -> void:
	var icon_color: Color = material_color.lightened(0.22 if is_active else 0.04)
	icon_color.a = 1.0 if is_active else 0.82
	button.add_theme_color_override("icon_normal_color", icon_color)
	button.add_theme_color_override("icon_hover_color", material_color.lightened(0.28))
	button.add_theme_color_override("icon_pressed_color", material_color.lightened(0.36))
	button.add_theme_color_override("icon_disabled_color", Color(0.35, 0.37, 0.38, 0.55))
	button.add_theme_stylebox_override("normal", _build_material_button_style(material_color, is_active, false))
	button.add_theme_stylebox_override("hover", _build_material_button_style(material_color, true, false))
	button.add_theme_stylebox_override("pressed", _build_material_button_style(material_color, true, true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _build_material_button_style(material_color: Color, highlighted: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.066, 0.076, 0.96) if not pressed else Color(0.075, 0.092, 0.102, 0.98)
	style.border_width_left = 2 if highlighted else 1
	style.border_width_top = 2 if highlighted else 1
	style.border_width_right = 2 if highlighted else 1
	style.border_width_bottom = 2 if highlighted else 1
	style.border_color = material_color.lightened(0.24) if highlighted else Color(0.26, 0.31, 0.34, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	return style

func _load_material_icon_texture() -> Texture2D:
	return load(MATERIAL_PLACEHOLDER_ICON_PATH) as Texture2D

func _resolve_builder_path_from_state() -> StringName:
	if active_stage_controller == null:
		return StringName()
	var state: Resource = active_stage_controller.get_active_authoring_state()
	return StringName(state.get("builder_path_id")) if state != null else StringName()

func _select_option_by_metadata(option_button: OptionButton, target_metadata: Variant) -> void:
	for item_index in range(option_button.get_item_count()):
		if option_button.get_item_metadata(item_index) == target_metadata:
			option_button.select(item_index)
			return

func _on_authoring_state_changed(_state) -> void:
	_refresh_from_controller()

func _on_new_draft_pressed() -> void:
	if active_stage_controller == null:
		return
	active_saved_profile_id = StringName()
	active_stage_controller.start_new_draft("%s V2 Draft" % current_bench_name)

func _on_clear_strokes_pressed() -> void:
	if active_stage_controller == null:
		return
	if active_stage_controller.has_method("clear_pending_material_bodies"):
		active_stage_controller.call("clear_pending_material_bodies")
	else:
		active_stage_controller.call("clear_volume_strokes")

func _on_builder_path_selected(index: int) -> void:
	if is_refreshing_ui or active_stage_controller == null:
		return
	active_stage_controller.set_builder_path_id(StringName(builder_path_option.get_item_metadata(index)))

func _on_builder_component_selected(index: int) -> void:
	if is_refreshing_ui or active_stage_controller == null:
		return
	active_stage_controller.set_builder_component_id(StringName(builder_component_option.get_item_metadata(index)))

func _on_operation_selected(index: int) -> void:
	if is_refreshing_ui or active_stage_controller == null:
		return
	active_stage_controller.set_active_operation_mode(StringName(operation_option.get_item_metadata(index)))

func _on_placement_policy_selected(index: int) -> void:
	if is_refreshing_ui or active_stage_controller == null:
		return
	active_stage_controller.set_placement_policy(StringName(placement_policy_option.get_item_metadata(index)))

func _on_material_palette_pressed(material_id: StringName) -> void:
	if is_refreshing_ui or active_stage_controller == null:
		return
	active_stage_controller.set_active_material_variant_id(material_id)

func _on_primitive_selected(index: int) -> void:
	if is_refreshing_ui or active_stage_controller == null:
		return
	active_stage_controller.set_active_primitive_id(StringName(primitive_option.get_item_metadata(index)))

func _on_radius_decrease_pressed() -> void:
	if active_stage_controller == null:
		return
	active_stage_controller.adjust_brush_radius_steps(-1)

func _on_radius_increase_pressed() -> void:
	if active_stage_controller == null:
		return
	active_stage_controller.adjust_brush_radius_steps(1)

func _on_add_empty_stroke_pressed() -> void:
	if active_stage_controller == null:
		return
	active_stage_controller.append_active_primitive_deposit()

func _on_commit_pending_pressed() -> void:
	if active_stage_controller == null:
		return
	active_stage_controller.commit_pending_material_bodies_as_layer()

func _on_undo_layer_pressed() -> void:
	if active_stage_controller == null:
		return
	active_stage_controller.undo_latest_layer()

func _on_redo_layer_pressed() -> void:
	if active_stage_controller == null:
		return
	active_stage_controller.redo_latest_layer()

func _on_body_stack_selected(index: int) -> void:
	if is_refreshing_ui or active_stage_controller == null:
		return
	active_stage_controller.select_material_body_id(StringName(body_stack_option.get_item_metadata(index)))

func _on_delete_selected_body_pressed() -> void:
	if active_stage_controller == null:
		return
	active_stage_controller.remove_selected_material_body()

func _ensure_workspace_preview() -> void:
	if workspace_preview != null and is_instance_valid(workspace_preview):
		return
	if workspace_subviewport == null:
		return
	workspace_subviewport.own_world_3d = true
	workspace_preview = ForgeV2WorkspacePreviewScript.new()
	workspace_preview.name = "ForgeV2WorkspacePreview"
	workspace_subviewport.add_child(workspace_preview)
	if active_stage_controller != null and workspace_preview.has_method("bind_stage_controller"):
		workspace_preview.call("bind_stage_controller", active_stage_controller)

func _sync_workspace_subviewport_size() -> void:
	if workspace_view_container == null or workspace_subviewport == null:
		return
	var target_size := Vector2i(
		maxi(int(round(workspace_view_container.size.x)), 1),
		maxi(int(round(workspace_view_container.size.y)), 1)
	)
	if workspace_subviewport.size != target_size:
		workspace_subviewport.size = target_size

func _on_workspace_view_gui_input(event: InputEvent) -> void:
	if active_stage_controller == null:
		return
	_ensure_workspace_preview()
	if workspace_preview == null:
		return
	if event is InputEventMouseButton:
		_handle_workspace_mouse_button(event as InputEventMouseButton)
		return
	if event is InputEventMouseMotion:
		_handle_workspace_mouse_motion(event as InputEventMouseMotion)

func _handle_workspace_mouse_button(mouse_button_event: InputEventMouseButton) -> void:
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_VIEW_ZOOM_IN, mouse_button_event):
		workspace_preview.call("zoom_by", -WORKSPACE_ZOOM_STEP)
		workspace_view_container.accept_event()
		return
	if _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_VIEW_ZOOM_OUT, mouse_button_event):
		workspace_preview.call("zoom_by", WORKSPACE_ZOOM_STEP)
		workspace_view_container.accept_event()
		return
	var orbit_mouse_button := _get_v2_binding_mouse_button(ForgeV2KeybindingStateScript.ACTION_VIEW_ORBIT)
	var pan_mouse_button := _get_v2_binding_mouse_button(ForgeV2KeybindingStateScript.ACTION_VIEW_PAN)
	var pan_secondary_mouse_button := _get_v2_binding_mouse_button(ForgeV2KeybindingStateScript.ACTION_VIEW_PAN_SECONDARY)
	var paint_mouse_button := _get_v2_binding_mouse_button(ForgeV2KeybindingStateScript.ACTION_PAINT_MATERIAL)
	if (
		mouse_button_event.button_index == orbit_mouse_button
		or mouse_button_event.button_index == pan_mouse_button
		or mouse_button_event.button_index == pan_secondary_mouse_button
	):
		workspace_drag_active = mouse_button_event.pressed
		workspace_drag_pan_mode = (
			_v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_VIEW_PAN, mouse_button_event)
			or _v2_event_matches_binding(ForgeV2KeybindingStateScript.ACTION_VIEW_PAN_SECONDARY, mouse_button_event)
		)
		workspace_view_container.accept_event()
		return
	if mouse_button_event.button_index != paint_mouse_button:
		return
	if mouse_button_event.pressed:
		if _is_v2_path_point_tool_active():
			_begin_workspace_spline_input(mouse_button_event.position)
		else:
			_begin_workspace_brush_stroke(mouse_button_event.position)
	else:
		if workspace_spline_point_drag_active:
			_finish_workspace_spline_point_drag()
		else:
			_finish_workspace_brush_stroke(mouse_button_event.position)
	workspace_view_container.accept_event()

func _handle_workspace_mouse_motion(motion_event: InputEventMouseMotion) -> void:
	if workspace_spline_point_drag_active:
		_update_workspace_spline_point_drag(motion_event.position)
		workspace_view_container.accept_event()
		return
	if workspace_brush_stroke_active:
		_extend_workspace_brush_stroke(motion_event.position)
		workspace_view_container.accept_event()
		return
	if workspace_drag_active:
		if workspace_drag_pan_mode:
			workspace_preview.call("pan_by", motion_event.relative)
		else:
			workspace_preview.call("orbit_by", motion_event.relative)
		workspace_view_container.accept_event()
		return
	_update_placement_cursor_from_workspace_position(motion_event.position)

func _on_workspace_view_mouse_exited() -> void:
	workspace_drag_active = false
	_finish_workspace_spline_point_drag()
	if workspace_brush_stroke_active:
		_finish_workspace_brush_stroke(Vector2.ZERO, false)
	if active_stage_controller != null and active_stage_controller.has_method("clear_placement_cursor"):
		active_stage_controller.call("clear_placement_cursor")

func _begin_workspace_spline_input(screen_position: Vector2) -> void:
	var nearest_point_index := _find_nearest_spline_point_at_screen(screen_position)
	if nearest_point_index >= 0:
		_begin_workspace_spline_point_drag(nearest_point_index, Vector3.ZERO)
		_update_workspace_spline_point_drag(screen_position)
		return
	var placement_result: Dictionary = _resolve_workspace_local_position(screen_position)
	if not bool(placement_result.get("valid", false)):
		return
	var local_position: Vector3 = placement_result.get("local_position", Vector3.ZERO) as Vector3
	if active_stage_controller != null and active_stage_controller.has_method("append_spline_line_point"):
		active_stage_controller.call("append_spline_line_point", local_position)

func _begin_workspace_spline_point_drag(point_index: int, fallback_local_position: Vector3) -> void:
	if workspace_preview == null or not workspace_preview.has_method("build_camera_facing_drag_plane"):
		return
	var point_origin: Vector3 = _get_spline_point_local_position(point_index, fallback_local_position)
	var drag_plane: Dictionary = workspace_preview.call("build_camera_facing_drag_plane", point_origin) as Dictionary
	if not bool(drag_plane.get("valid", false)):
		return
	workspace_spline_point_drag_active = true
	workspace_spline_drag_point_index = point_index
	workspace_spline_drag_plane_origin_local = drag_plane.get("origin_local", point_origin) as Vector3
	workspace_spline_drag_plane_normal_local = drag_plane.get("normal_local", Vector3.FORWARD) as Vector3
	if active_stage_controller != null and active_stage_controller.has_method("select_spline_line_point"):
		active_stage_controller.call("select_spline_line_point", point_index)

func _update_workspace_spline_point_drag(screen_position: Vector2) -> void:
	if not workspace_spline_point_drag_active:
		return
	if workspace_preview == null or not workspace_preview.has_method("screen_to_workspace_local_on_drag_plane"):
		return
	var drag_result: Dictionary = workspace_preview.call(
		"screen_to_workspace_local_on_drag_plane",
		screen_position,
		workspace_spline_drag_plane_origin_local,
		workspace_spline_drag_plane_normal_local
	) as Dictionary
	if not bool(drag_result.get("valid", false)):
		return
	var local_position: Vector3 = drag_result.get("local_position", Vector3.ZERO) as Vector3
	if active_stage_controller != null and active_stage_controller.has_method("set_spline_line_point"):
		active_stage_controller.call("set_spline_line_point", workspace_spline_drag_point_index, local_position)

func _finish_workspace_spline_point_drag() -> void:
	workspace_spline_point_drag_active = false
	workspace_spline_drag_point_index = -1
	workspace_spline_drag_plane_origin_local = Vector3.ZERO
	workspace_spline_drag_plane_normal_local = Vector3.FORWARD

func _find_nearest_spline_point_at_screen(screen_position: Vector2) -> int:
	if workspace_preview == null or not workspace_preview.has_method("find_nearest_local_point_by_screen"):
		return -1
	var spline_points: PackedVector3Array = _get_spline_points()
	return int(workspace_preview.call(
		"find_nearest_local_point_by_screen",
		spline_points,
		screen_position,
		SPLINE_POINT_SCREEN_PICK_RADIUS_PIXELS
	))

func _get_spline_point_local_position(point_index: int, fallback_local_position: Vector3) -> Vector3:
	var spline_points: PackedVector3Array = _get_spline_points()
	if point_index < 0 or point_index >= spline_points.size():
		return fallback_local_position
	return spline_points[point_index]

func _get_spline_points() -> PackedVector3Array:
	if active_stage_controller == null or not active_stage_controller.has_method("get_status_summary"):
		return PackedVector3Array()
	var summary: Dictionary = active_stage_controller.call("get_status_summary") as Dictionary
	var spline_summary: Dictionary = summary.get("spline_line", {}) as Dictionary
	return spline_summary.get("points", PackedVector3Array())

func _begin_workspace_brush_stroke(screen_position: Vector2) -> void:
	var placement_result: Dictionary = _resolve_workspace_local_position(screen_position)
	if not bool(placement_result.get("valid", false)):
		return
	var local_position: Vector3 = placement_result.get("local_position", Vector3.ZERO) as Vector3
	workspace_brush_stroke_active = true
	if active_stage_controller.has_method("begin_material_body_path"):
		active_stage_controller.call("begin_material_body_path", local_position)
	elif active_stage_controller.has_method("begin_placement_stroke"):
		active_stage_controller.call("begin_placement_stroke", local_position)
	else:
		active_stage_controller.call("append_point_material_body", local_position)

func _extend_workspace_brush_stroke(screen_position: Vector2, force_endpoint: bool = false) -> void:
	if not workspace_brush_stroke_active:
		return
	var placement_result: Dictionary = _resolve_workspace_local_position(screen_position)
	if not bool(placement_result.get("valid", false)):
		if active_stage_controller.has_method("clear_placement_cursor"):
			active_stage_controller.call("clear_placement_cursor")
		return
	var local_position: Vector3 = placement_result.get("local_position", Vector3.ZERO) as Vector3
	if active_stage_controller.has_method("extend_material_body_path"):
		active_stage_controller.call("extend_material_body_path", local_position, force_endpoint)
	elif active_stage_controller.has_method("extend_placement_stroke"):
		active_stage_controller.call("extend_placement_stroke", local_position, force_endpoint)
	elif force_endpoint:
		active_stage_controller.call("append_point_material_body", local_position)

func _finish_workspace_brush_stroke(screen_position: Vector2, use_screen_position: bool = true) -> void:
	if not workspace_brush_stroke_active:
		return
	var placement_result: Dictionary = _resolve_workspace_local_position(screen_position) if use_screen_position else {"valid": false}
	if active_stage_controller.has_method("finish_material_body_path"):
		active_stage_controller.call(
			"finish_material_body_path",
			placement_result.get("local_position", Vector3.ZERO) as Vector3,
			bool(placement_result.get("valid", false))
		)
	elif active_stage_controller.has_method("finish_placement_stroke"):
		active_stage_controller.call(
			"finish_placement_stroke",
			placement_result.get("local_position", Vector3.ZERO) as Vector3,
			bool(placement_result.get("valid", false))
		)
	workspace_brush_stroke_active = false

func _update_placement_cursor_from_workspace_position(screen_position: Vector2) -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("set_placement_cursor_local_position"):
		return
	var placement_result: Dictionary = _resolve_workspace_local_position(screen_position)
	if not bool(placement_result.get("valid", false)):
		active_stage_controller.call("clear_placement_cursor")
		return
	active_stage_controller.call(
		"set_placement_cursor_local_position",
		placement_result.get("local_position", Vector3.ZERO) as Vector3,
		true
	)

func _resolve_workspace_local_position(screen_position: Vector2) -> Dictionary:
	_ensure_workspace_preview()
	if workspace_preview == null or not workspace_preview.has_method("screen_to_workspace_local"):
		return {"valid": false}
	return workspace_preview.call("screen_to_workspace_local", screen_position) as Dictionary
