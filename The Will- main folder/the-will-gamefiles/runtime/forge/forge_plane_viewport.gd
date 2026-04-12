extends Control
class_name ForgePlaneViewport

signal cell_place_requested(grid_position)
signal cell_remove_requested(grid_position)
signal cell_pick_requested(grid_position)
signal drag_started(grid_position, button_index)
signal drag_updated(grid_position, button_index)
signal stroke_finished
signal hover_grid_position_updated(grid_position)
signal hover_cleared

const PLANE_XY: StringName = &"xy"
const PLANE_ZX: StringName = &"zx"
const PLANE_ZY: StringName = &"zy"

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const DEFAULT_FORGE_VIEW_TUNING_RESOURCE: ForgeViewTuningDef = preload("res://core/defs/forge/forge_view_tuning_default.tres")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")

@export var grid_size: Vector3i = DEFAULT_FORGE_RULES_RESOURCE.grid_size
@export var forge_view_tuning: ForgeViewTuningDef = DEFAULT_FORGE_VIEW_TUNING_RESOURCE

var active_plane: StringName = PLANE_XY
var active_layer: int = DEFAULT_FORGE_RULES_RESOURCE.grid_size.z >> 1
var active_wip: CraftedItemWIP
var material_lookup: Dictionary = {}
var material_runtime_resolver = MaterialRuntimeResolverScript.new()
var plane_zoom_scale: float = 1.0
var plane_zoom_focus: Vector2 = Vector2(0.5, 0.5)
var plane_pan_offset_pixels: Vector2 = Vector2.ZERO
var plane_pan_active: bool = false
var active_drag_button: MouseButton = MOUSE_BUTTON_NONE
var drag_has_last_grid: bool = false
var drag_last_grid_position: Vector3i = Vector3i.ZERO
var drag_has_last_plane_position: bool = false
var drag_last_plane_position: Vector2i = Vector2i.ZERO
var structural_shape_preview_cells: Array[Vector3i] = []
var structural_shape_preview_material_id: StringName = &""
var structural_shape_preview_remove_mode: bool = false

func set_grid_size(value: Vector3i) -> void:
	grid_size = value
	queue_redraw()

func set_active_plane(value: StringName) -> void:
	active_plane = value
	queue_redraw()

func set_active_layer(value: int) -> void:
	active_layer = clampi(value, 0, _get_max_layer_index())
	queue_redraw()

func set_active_wip(value: CraftedItemWIP) -> void:
	active_wip = value
	queue_redraw()

func set_material_lookup(value: Dictionary) -> void:
	material_lookup = value
	queue_redraw()

func set_view_tuning(value: ForgeViewTuningDef) -> void:
	forge_view_tuning = value if value != null else DEFAULT_FORGE_VIEW_TUNING_RESOURCE
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if not mouse_event.pressed:
			if plane_pan_active and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				plane_pan_active = false
				accept_event()
				return
			if mouse_event.button_index == active_drag_button:
				_clear_drag_state()
				emit_signal("stroke_finished")
			return
		var plane_rect: Rect2 = _get_plane_draw_rect()
		if not plane_rect.has_point(mouse_event.position):
			return

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_plane_at(mouse_event.position, 1.0)
			accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_plane_at(mouse_event.position, -1.0)
			accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and _is_pan_modifier_pressed():
			plane_pan_active = true
			_clear_drag_state()
			accept_event()
			return
		if mouse_event.ctrl_pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_emit_pick_action(mouse_event.position)
			_clear_drag_state()
			accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT or mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			active_drag_button = mouse_event.button_index
			var drag_grid_position_variant: Variant = _screen_to_grid(mouse_event.position)
			if drag_grid_position_variant is Vector3i:
				emit_signal("drag_started", drag_grid_position_variant, active_drag_button)
			_emit_drag_action(mouse_event.position, active_drag_button)
			accept_event()
			return
		return

	if event is InputEventMouseMotion and plane_pan_active:
		var pan_motion_event: InputEventMouseMotion = event
		_pan_plane_by(pan_motion_event.relative)
		accept_event()
		return
	if event is InputEventMouseMotion and active_drag_button != MOUSE_BUTTON_NONE:
		var motion_event: InputEventMouseMotion = event
		_emit_drag_action(motion_event.position, active_drag_button)
		accept_event()
		return
	if event is InputEventMouseMotion:
		var hover_motion_event: InputEventMouseMotion = event
		var plane_rect: Rect2 = _get_plane_draw_rect()
		if not plane_rect.has_point(hover_motion_event.position):
			emit_signal("hover_cleared")
			return
		var hover_grid_variant: Variant = _screen_to_grid(hover_motion_event.position)
		if hover_grid_variant is Vector3i:
			emit_signal("hover_grid_position_updated", hover_grid_variant)

func _draw() -> void:
	var plane_rect: Rect2 = _get_plane_draw_rect()
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	draw_rect(plane_rect, tuning.plane_empty_color, true)
	draw_rect(plane_rect, tuning.plane_frame_color, false, 2.0)

	var plane_dimensions: Vector2i = _get_plane_dimensions()
	if plane_dimensions.x <= 0 or plane_dimensions.y <= 0:
		return

	var cell_size: Vector2 = Vector2(
		plane_rect.size.x / float(plane_dimensions.x),
		plane_rect.size.y / float(plane_dimensions.y)
	)

	if active_wip != null:
		for layer_atom: LayerAtom in active_wip.layers:
			if layer_atom == null:
				continue
			for cell: CellAtom in layer_atom.cells:
				if cell == null:
					continue
				var plane_position: Variant = _grid_to_plane(cell.grid_position)
				if plane_position == null:
					continue
				var resolved_plane_position: Vector2i = plane_position
				var cell_rect: Rect2 = Rect2(
					plane_rect.position + Vector2(float(resolved_plane_position.x) * cell_size.x, float(resolved_plane_position.y) * cell_size.y),
					cell_size
				)
				draw_rect(cell_rect.grow(-tuning.plane_cell_inset_pixels), _resolve_material_color(cell.material_variant_id), true)
		_draw_builder_markers(plane_rect, cell_size)
	_draw_structural_shape_preview(plane_rect, cell_size)

	for x in range(plane_dimensions.x + 1):
		var x_pos: float = plane_rect.position.x + (float(x) * cell_size.x)
		draw_line(Vector2(x_pos, plane_rect.position.y), Vector2(x_pos, plane_rect.end.y), tuning.plane_grid_color, 1.0)
	for y in range(plane_dimensions.y + 1):
		var y_pos: float = plane_rect.position.y + (float(y) * cell_size.y)
		draw_line(Vector2(plane_rect.position.x, y_pos), Vector2(plane_rect.end.x, y_pos), tuning.plane_grid_color, 1.0)

func _get_plane_draw_rect() -> Rect2:
	var margin: float = _get_view_tuning().plane_margin_pixels
	var available: Rect2 = Rect2(Vector2(margin, margin), size - Vector2.ONE * margin * 2.0)
	var plane_dimensions: Vector2i = _get_plane_dimensions()
	if available.size.x <= 0.0 or available.size.y <= 0.0 or plane_dimensions.x <= 0 or plane_dimensions.y <= 0:
		return Rect2(Vector2.ZERO, Vector2.ZERO)

	var plane_aspect: float = float(plane_dimensions.x) / float(plane_dimensions.y)
	var target_size: Vector2 = available.size
	if available.size.x / maxf(available.size.y, 0.001) > plane_aspect:
		target_size.x = available.size.y * plane_aspect
	else:
		target_size.y = available.size.x / plane_aspect
	var zoomed_size: Vector2 = target_size * plane_zoom_scale
	var centered_position: Vector2 = available.position + (available.size - zoomed_size) * 0.5
	var draw_position: Vector2 = centered_position
	if plane_zoom_scale > 1.0:
		var focus_offset: Vector2 = Vector2(
			clampf(plane_zoom_focus.x, 0.0, 1.0) * zoomed_size.x,
			clampf(plane_zoom_focus.y, 0.0, 1.0) * zoomed_size.y
		)
		var base_draw_position: Vector2 = available.get_center() - focus_offset
		draw_position = _clamp_plane_draw_position(base_draw_position + plane_pan_offset_pixels, centered_position, available, zoomed_size)
		plane_pan_offset_pixels = draw_position - base_draw_position
	else:
		plane_pan_offset_pixels = Vector2.ZERO
	return Rect2(draw_position, zoomed_size)

func _get_plane_dimensions() -> Vector2i:
	match active_plane:
		PLANE_ZX:
			return Vector2i(grid_size.z, grid_size.x)
		PLANE_ZY:
			return Vector2i(grid_size.z, grid_size.y)
		_:
			return Vector2i(grid_size.x, grid_size.y)

func _get_max_layer_index() -> int:
	match active_plane:
		PLANE_ZX:
			return maxi(grid_size.y - 1, 0)
		PLANE_ZY:
			return maxi(grid_size.x - 1, 0)
		_:
			return maxi(grid_size.z - 1, 0)

func _screen_to_grid(screen_position: Vector2) -> Variant:
	var plane_rect: Rect2 = _get_plane_draw_rect()
	var plane_dimensions: Vector2i = _get_plane_dimensions()
	if plane_rect.size.x <= 0.0 or plane_rect.size.y <= 0.0:
		return null
	var local: Vector2 = screen_position - plane_rect.position
	var u: int = clampi(int(floor((local.x / plane_rect.size.x) * float(plane_dimensions.x))), 0, plane_dimensions.x - 1)
	var v: int = clampi(int(floor((local.y / plane_rect.size.y) * float(plane_dimensions.y))), 0, plane_dimensions.y - 1)
	return _plane_to_grid(Vector2i(u, v))

func _plane_to_grid(plane_position: Vector2i) -> Vector3i:
	var plane_dimensions: Vector2i = _get_plane_dimensions()
	var flipped_y: int = (plane_dimensions.y - 1) - plane_position.y
	match active_plane:
		PLANE_ZX:
			return Vector3i(flipped_y, active_layer, plane_position.x)
		PLANE_ZY:
			return Vector3i(active_layer, flipped_y, plane_position.x)
		_:
			return Vector3i(plane_position.x, flipped_y, active_layer)

func _get_material_at(grid_position: Vector3i) -> StringName:
	if active_wip == null:
		return StringName()
	for layer_atom: LayerAtom in active_wip.layers:
		if layer_atom == null:
			continue
		for cell: CellAtom in layer_atom.cells:
			if cell == null:
				continue
			if cell.grid_position == grid_position:
				return cell.material_variant_id
	return StringName()

func _grid_to_plane(grid_position: Vector3i) -> Variant:
	match active_plane:
		PLANE_ZX:
			if grid_position.y != active_layer:
				return null
			return Vector2i(grid_position.z, (grid_size.x - 1) - grid_position.x)
		PLANE_ZY:
			if grid_position.x != active_layer:
				return null
			return Vector2i(grid_position.z, (grid_size.y - 1) - grid_position.y)
		_:
			if grid_position.z != active_layer:
				return null
			return Vector2i(grid_position.x, (grid_size.y - 1) - grid_position.y)

func _resolve_material_color(material_id: StringName) -> Color:
	return material_runtime_resolver.resolve_material_color(
		material_id,
		material_lookup,
		_get_view_tuning().unknown_material_color
	)

func _draw_builder_markers(plane_rect: Rect2, cell_size: Vector2) -> void:
	if active_wip == null:
		return
	var font: Font = get_theme_default_font()
	var font_size: int = maxi(get_theme_default_font_size() - 2, 10)
	for marker_cell: CellAtom in CraftedItemWIPScript.collect_builder_marker_cells(active_wip):
		if marker_cell == null:
			continue
		var plane_position: Variant = _grid_to_plane(marker_cell.grid_position)
		if plane_position == null:
			continue
		var resolved_plane_position: Vector2i = plane_position
		var cell_rect: Rect2 = Rect2(
			plane_rect.position + Vector2(float(resolved_plane_position.x) * cell_size.x, float(resolved_plane_position.y) * cell_size.y),
			cell_size
		)
		var marker_color: Color = _resolve_material_color(marker_cell.material_variant_id)
		var center: Vector2 = cell_rect.get_center()
		var radius: float = minf(cell_rect.size.x, cell_rect.size.y) * 0.28
		draw_circle(center, radius, Color(marker_color.r, marker_color.g, marker_color.b, 0.28))
		draw_arc(center, radius, 0.0, TAU, 24, marker_color, 2.0)
		draw_circle(center, maxf(radius * 0.22, 2.0), Color(1.0, 1.0, 1.0, 0.9))
		if font == null:
			continue
		var label: String = CraftedItemWIPScript.get_builder_marker_short_label(marker_cell.material_variant_id)
		var label_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var label_position: Vector2 = center - Vector2(label_size.x * 0.5, -label_size.y * 0.35)
		draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, marker_color.lightened(0.5))

func _zoom_plane_at(screen_position: Vector2, direction: float) -> void:
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	var previous_zoom: float = plane_zoom_scale
	var plane_rect: Rect2 = _get_plane_draw_rect()
	if plane_rect.size.x <= 0.0 or plane_rect.size.y <= 0.0:
		return
	plane_zoom_focus = Vector2(
		clampf((screen_position.x - plane_rect.position.x) / plane_rect.size.x, 0.0, 1.0),
		clampf((screen_position.y - plane_rect.position.y) / plane_rect.size.y, 0.0, 1.0)
	)
	plane_zoom_scale = clampf(
		plane_zoom_scale + direction * tuning.plane_zoom_step,
		tuning.plane_zoom_min_scale,
		tuning.plane_zoom_max_scale
	)
	if is_equal_approx(previous_zoom, plane_zoom_scale):
		return
	if is_equal_approx(plane_zoom_scale, tuning.plane_zoom_min_scale):
		plane_zoom_focus = Vector2(0.5, 0.5)
		plane_pan_offset_pixels = Vector2.ZERO
	queue_redraw()

func _pan_plane_by(relative: Vector2) -> void:
	if plane_zoom_scale <= _get_view_tuning().plane_zoom_min_scale:
		plane_pan_offset_pixels = Vector2.ZERO
		return
	plane_pan_offset_pixels += relative
	queue_redraw()

func _emit_pick_action(screen_position: Vector2) -> void:
	var grid_position: Variant = _screen_to_grid(screen_position)
	if grid_position == null:
		return
	emit_signal("cell_pick_requested", grid_position)

func _emit_drag_action(screen_position: Vector2, button_index: MouseButton) -> void:
	var plane_rect: Rect2 = _get_plane_draw_rect()
	if not plane_rect.has_point(screen_position):
		return
	var grid_position_variant: Variant = _screen_to_grid(screen_position)
	if grid_position_variant == null:
		return
	var grid_position: Vector3i = grid_position_variant
	var plane_position_variant: Variant = _grid_to_plane(grid_position)
	if plane_position_variant is not Vector2i:
		return
	var current_plane_position: Vector2i = plane_position_variant
	for plane_position: Vector2i in _build_drag_plane_path(current_plane_position):
		var drag_grid_position: Vector3i = _plane_to_grid(plane_position)
		emit_signal("drag_updated", drag_grid_position, button_index)
		if drag_has_last_grid and drag_grid_position == drag_last_grid_position:
			continue
		drag_has_last_grid = true
		drag_last_grid_position = drag_grid_position
		if button_index == MOUSE_BUTTON_RIGHT:
			emit_signal("cell_remove_requested", drag_grid_position)
		else:
			emit_signal("cell_place_requested", drag_grid_position)
	drag_has_last_plane_position = true
	drag_last_plane_position = current_plane_position

func has_active_drag_action() -> bool:
	return drag_has_last_plane_position and (
		active_drag_button == MOUSE_BUTTON_LEFT
		or active_drag_button == MOUSE_BUTTON_RIGHT
	)

func emit_active_drag_action_for_current_layer() -> bool:
	if not has_active_drag_action():
		return false
	var grid_position: Vector3i = _plane_to_grid(drag_last_plane_position)
	if drag_has_last_grid and grid_position == drag_last_grid_position:
		return false
	drag_has_last_grid = true
	drag_last_grid_position = grid_position
	if active_drag_button == MOUSE_BUTTON_RIGHT:
		emit_signal("cell_remove_requested", grid_position)
		return true
	emit_signal("cell_place_requested", grid_position)
	return true

func set_structural_shape_preview_state(
	grid_positions: Array[Vector3i],
	material_id: StringName,
	remove_mode: bool
) -> void:
	structural_shape_preview_cells = grid_positions.duplicate()
	structural_shape_preview_material_id = material_id
	structural_shape_preview_remove_mode = remove_mode
	queue_redraw()

func clear_structural_shape_preview_state() -> void:
	structural_shape_preview_cells.clear()
	structural_shape_preview_material_id = StringName()
	structural_shape_preview_remove_mode = false
	queue_redraw()

func _draw_structural_shape_preview(plane_rect: Rect2, cell_size: Vector2) -> void:
	if structural_shape_preview_cells.is_empty():
		return
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	var preview_color: Color = tuning.plane_shape_remove_preview_color if structural_shape_preview_remove_mode else _resolve_material_color(structural_shape_preview_material_id)
	if not structural_shape_preview_remove_mode:
		preview_color = Color(preview_color.r, preview_color.g, preview_color.b, tuning.plane_shape_add_preview_alpha)
	for grid_position: Vector3i in structural_shape_preview_cells:
		var plane_position_variant: Variant = _grid_to_plane(grid_position)
		if plane_position_variant == null:
			continue
		var plane_position: Vector2i = plane_position_variant
		var cell_rect: Rect2 = Rect2(
			plane_rect.position + Vector2(float(plane_position.x) * cell_size.x, float(plane_position.y) * cell_size.y),
			cell_size
		)
		draw_rect(cell_rect.grow(-tuning.plane_cell_inset_pixels), preview_color, true)
		draw_rect(cell_rect.grow(-tuning.plane_cell_inset_pixels), preview_color.lightened(0.2), false, 1.0)

func _clear_drag_state() -> void:
	active_drag_button = MOUSE_BUTTON_NONE
	drag_has_last_grid = false
	drag_has_last_plane_position = false

func _clamp_plane_draw_position(
	draw_position: Vector2,
	centered_position: Vector2,
	available: Rect2,
	zoomed_size: Vector2
) -> Vector2:
	var clamped_position: Vector2 = draw_position
	if zoomed_size.x > available.size.x:
		clamped_position.x = clampf(clamped_position.x, available.end.x - zoomed_size.x, available.position.x)
	else:
		clamped_position.x = centered_position.x
	if zoomed_size.y > available.size.y:
		clamped_position.y = clampf(clamped_position.y, available.end.y - zoomed_size.y, available.position.y)
	else:
		clamped_position.y = centered_position.y
	return clamped_position

func _is_pan_modifier_pressed() -> bool:
	return Input.is_key_pressed(_get_view_tuning().workspace_pan_modifier_keycode)

func _build_drag_plane_path(current_plane_position: Vector2i) -> Array[Vector2i]:
	if not drag_has_last_plane_position:
		return [current_plane_position]
	return _build_plane_line(drag_last_plane_position, current_plane_position)

func _build_plane_line(start_plane_position: Vector2i, end_plane_position: Vector2i) -> Array[Vector2i]:
	var resolved_positions: Array[Vector2i] = []
	var delta_x: int = end_plane_position.x - start_plane_position.x
	var delta_y: int = end_plane_position.y - start_plane_position.y
	var step_count: int = maxi(abs(delta_x), abs(delta_y))
	if step_count <= 0:
		resolved_positions.append(end_plane_position)
		return resolved_positions
	var visited: Dictionary = {}
	for step_index: int in range(step_count + 1):
		var interpolation_ratio: float = float(step_index) / float(step_count)
		var plane_position: Vector2i = Vector2i(
			int(round(lerpf(float(start_plane_position.x), float(end_plane_position.x), interpolation_ratio))),
			int(round(lerpf(float(start_plane_position.y), float(end_plane_position.y), interpolation_ratio)))
		)
		if visited.has(plane_position):
			continue
		visited[plane_position] = true
		resolved_positions.append(plane_position)
	return resolved_positions

func _get_view_tuning() -> ForgeViewTuningDef:
	return forge_view_tuning if forge_view_tuning != null else DEFAULT_FORGE_VIEW_TUNING_RESOURCE
