extends RefCounted
class_name ForgeWorkspaceShapeToolPresenter

const FAMILY_FREEHAND: StringName = &"freehand"
const FAMILY_RECTANGLE: StringName = &"rectangle"
const FAMILY_CIRCLE: StringName = &"circle"
const FAMILY_OVAL: StringName = &"oval"
const FAMILY_TRIANGLE: StringName = &"triangle"

const MODIFIER_ADD: StringName = &"add"
const MODIFIER_REMOVE: StringName = &"remove"
const MODIFIER_PICK: StringName = &"pick"

const TOOL_RECTANGLE_PLACE: StringName = &"rectangle_place"
const TOOL_RECTANGLE_ERASE: StringName = &"rectangle_erase"
const TOOL_CIRCLE_PLACE: StringName = &"circle_place"
const TOOL_CIRCLE_ERASE: StringName = &"circle_erase"
const TOOL_OVAL_PLACE: StringName = &"oval_place"
const TOOL_OVAL_ERASE: StringName = &"oval_erase"
const TOOL_TRIANGLE_PLACE: StringName = &"triangle_place"
const TOOL_TRIANGLE_ERASE: StringName = &"triangle_erase"

func is_shape_tool(tool_id: StringName) -> bool:
	return (
		is_rectangle_tool(tool_id)
		or is_circle_tool(tool_id)
		or is_oval_tool(tool_id)
		or is_triangle_tool(tool_id)
	)

func is_rectangle_tool(tool_id: StringName) -> bool:
	return tool_id == TOOL_RECTANGLE_PLACE or tool_id == TOOL_RECTANGLE_ERASE

func is_circle_tool(tool_id: StringName) -> bool:
	return tool_id == TOOL_CIRCLE_PLACE or tool_id == TOOL_CIRCLE_ERASE

func is_oval_tool(tool_id: StringName) -> bool:
	return tool_id == TOOL_OVAL_PLACE or tool_id == TOOL_OVAL_ERASE

func is_triangle_tool(tool_id: StringName) -> bool:
	return tool_id == TOOL_TRIANGLE_PLACE or tool_id == TOOL_TRIANGLE_ERASE

func is_stage1_tool_family(family_id: StringName) -> bool:
	return (
		family_id == FAMILY_FREEHAND
		or family_id == FAMILY_RECTANGLE
		or family_id == FAMILY_CIRCLE
		or family_id == FAMILY_OVAL
		or family_id == FAMILY_TRIANGLE
	)

func is_shape_family(family_id: StringName) -> bool:
	return (
		family_id == FAMILY_RECTANGLE
		or family_id == FAMILY_CIRCLE
		or family_id == FAMILY_OVAL
		or family_id == FAMILY_TRIANGLE
	)

func is_additive_shape_tool(tool_id: StringName) -> bool:
	return (
		tool_id == TOOL_RECTANGLE_PLACE
		or tool_id == TOOL_CIRCLE_PLACE
		or tool_id == TOOL_OVAL_PLACE
		or tool_id == TOOL_TRIANGLE_PLACE
	)

func is_subtractive_shape_tool(tool_id: StringName) -> bool:
	return (
		tool_id == TOOL_RECTANGLE_ERASE
		or tool_id == TOOL_CIRCLE_ERASE
		or tool_id == TOOL_OVAL_ERASE
		or tool_id == TOOL_TRIANGLE_ERASE
	)

func resolve_stage1_tool_family(tool_id: StringName) -> StringName:
	if is_rectangle_tool(tool_id) or tool_id == FAMILY_RECTANGLE:
		return FAMILY_RECTANGLE
	if is_circle_tool(tool_id) or tool_id == FAMILY_CIRCLE:
		return FAMILY_CIRCLE
	if is_oval_tool(tool_id) or tool_id == FAMILY_OVAL:
		return FAMILY_OVAL
	if is_triangle_tool(tool_id) or tool_id == FAMILY_TRIANGLE:
		return FAMILY_TRIANGLE
	return FAMILY_FREEHAND

func resolve_stage1_modifier(tool_id: StringName) -> StringName:
	if tool_id == &"pick":
		return MODIFIER_PICK
	if tool_id == TOOL_RECTANGLE_ERASE or tool_id == TOOL_CIRCLE_ERASE or tool_id == TOOL_OVAL_ERASE or tool_id == TOOL_TRIANGLE_ERASE:
		return MODIFIER_REMOVE
	if tool_id == TOOL_RECTANGLE_PLACE or tool_id == TOOL_CIRCLE_PLACE or tool_id == TOOL_OVAL_PLACE or tool_id == TOOL_TRIANGLE_PLACE:
		return MODIFIER_ADD
	if tool_id == &"erase":
		return MODIFIER_REMOVE
	return MODIFIER_ADD

func compose_stage1_tool_id(family_id: StringName, modifier_id: StringName) -> StringName:
	if modifier_id == MODIFIER_PICK:
		return &"pick"
	match family_id:
		FAMILY_RECTANGLE:
			return TOOL_RECTANGLE_ERASE if modifier_id == MODIFIER_REMOVE else TOOL_RECTANGLE_PLACE
		FAMILY_CIRCLE:
			return TOOL_CIRCLE_ERASE if modifier_id == MODIFIER_REMOVE else TOOL_CIRCLE_PLACE
		FAMILY_OVAL:
			return TOOL_OVAL_ERASE if modifier_id == MODIFIER_REMOVE else TOOL_OVAL_PLACE
		FAMILY_TRIANGLE:
			return TOOL_TRIANGLE_ERASE if modifier_id == MODIFIER_REMOVE else TOOL_TRIANGLE_PLACE
		_:
			return &"erase" if modifier_id == MODIFIER_REMOVE else &"place"

func get_stage1_tool_display_name(family_id: StringName) -> String:
	match family_id:
		FAMILY_RECTANGLE:
			return "Rectangle"
		FAMILY_CIRCLE:
			return "Circle"
		FAMILY_OVAL:
			return "Oval"
		FAMILY_TRIANGLE:
			return "Triangle"
		_:
			return "Freehand"

func build_shape_footprint(
	tool_id: StringName,
	anchor_grid_position: Vector3i,
	current_grid_position: Vector3i,
	active_plane: StringName,
	active_layer: int,
	grid_size: Vector3i,
	rotation_quadrant: int = 0
) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	if is_rectangle_tool(tool_id):
		cells = build_rectangle_footprint(anchor_grid_position, current_grid_position, active_plane, active_layer)
	elif is_circle_tool(tool_id):
		cells = build_circle_footprint(anchor_grid_position, current_grid_position, active_plane, active_layer, grid_size)
	elif is_oval_tool(tool_id):
		cells = build_oval_footprint(anchor_grid_position, current_grid_position, active_plane, active_layer, grid_size)
	elif is_triangle_tool(tool_id):
		cells = build_triangle_footprint(anchor_grid_position, current_grid_position, active_plane, active_layer, grid_size)
	return _rotate_shape_footprint(cells, active_plane, active_layer, grid_size, rotation_quadrant)

func build_rectangle_footprint(
	anchor_grid_position: Vector3i,
	current_grid_position: Vector3i,
	active_plane: StringName,
	active_layer: int
) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	match active_plane:
		&"zx":
			var min_z: int = mini(anchor_grid_position.z, current_grid_position.z)
			var max_z: int = maxi(anchor_grid_position.z, current_grid_position.z)
			var min_x: int = mini(anchor_grid_position.x, current_grid_position.x)
			var max_x: int = maxi(anchor_grid_position.x, current_grid_position.x)
			for x in range(min_x, max_x + 1):
				for z in range(min_z, max_z + 1):
					cells.append(Vector3i(x, active_layer, z))
		&"zy":
			var min_z: int = mini(anchor_grid_position.z, current_grid_position.z)
			var max_z: int = maxi(anchor_grid_position.z, current_grid_position.z)
			var min_y: int = mini(anchor_grid_position.y, current_grid_position.y)
			var max_y: int = maxi(anchor_grid_position.y, current_grid_position.y)
			for y in range(min_y, max_y + 1):
				for z in range(min_z, max_z + 1):
					cells.append(Vector3i(active_layer, y, z))
		_:
			var min_x: int = mini(anchor_grid_position.x, current_grid_position.x)
			var max_x: int = maxi(anchor_grid_position.x, current_grid_position.x)
			var min_y: int = mini(anchor_grid_position.y, current_grid_position.y)
			var max_y: int = maxi(anchor_grid_position.y, current_grid_position.y)
			for x in range(min_x, max_x + 1):
				for y in range(min_y, max_y + 1):
					cells.append(Vector3i(x, y, active_layer))
	return cells

func build_circle_footprint(
	anchor_grid_position: Vector3i,
	current_grid_position: Vector3i,
	active_plane: StringName,
	active_layer: int,
	grid_size: Vector3i
) -> Array[Vector3i]:
	var bounds: Rect2i = _build_plane_bounds(anchor_grid_position, current_grid_position, active_plane, grid_size)
	var width: int = bounds.size.x
	var height: int = bounds.size.y
	if width <= 0 or height <= 0:
		return []
	var diameter_cells: int = mini(width, height)
	var center_x: float = bounds.position.x + float(width) * 0.5
	var center_y: float = bounds.position.y + float(height) * 0.5
	var radius: float = maxf(float(diameter_cells) * 0.5, 0.5)
	return _build_ellipse_footprint(bounds, active_plane, active_layer, grid_size, center_x, center_y, radius, radius)

func build_oval_footprint(
	anchor_grid_position: Vector3i,
	current_grid_position: Vector3i,
	active_plane: StringName,
	active_layer: int,
	grid_size: Vector3i
) -> Array[Vector3i]:
	var bounds: Rect2i = _build_plane_bounds(anchor_grid_position, current_grid_position, active_plane, grid_size)
	var width: int = bounds.size.x
	var height: int = bounds.size.y
	if width <= 0 or height <= 0:
		return []
	var center_x: float = bounds.position.x + float(width) * 0.5
	var center_y: float = bounds.position.y + float(height) * 0.5
	var radius_x: float = maxf(float(width) * 0.5, 0.5)
	var radius_y: float = maxf(float(height) * 0.5, 0.5)
	return _build_ellipse_footprint(bounds, active_plane, active_layer, grid_size, center_x, center_y, radius_x, radius_y)

func build_triangle_footprint(
	anchor_grid_position: Vector3i,
	current_grid_position: Vector3i,
	active_plane: StringName,
	active_layer: int,
	grid_size: Vector3i
) -> Array[Vector3i]:
	var bounds: Rect2i = _build_plane_bounds(anchor_grid_position, current_grid_position, active_plane, grid_size)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return []
	var anchor_plane_position: Vector2i = _grid_to_plane_position(anchor_grid_position, active_plane, grid_size)
	var current_plane_position: Vector2i = _grid_to_plane_position(current_grid_position, active_plane, grid_size)
	var min_x: float = float(bounds.position.x)
	var max_x: float = float(bounds.position.x + bounds.size.x)
	var min_y: float = float(bounds.position.y)
	var max_y: float = float(bounds.position.y + bounds.size.y)
	var apex_on_top: bool = current_plane_position.y <= anchor_plane_position.y
	var apex: Vector2 = Vector2((min_x + max_x) * 0.5, min_y if apex_on_top else max_y)
	var base_left: Vector2 = Vector2(min_x, max_y if apex_on_top else min_y)
	var base_right: Vector2 = Vector2(max_x, max_y if apex_on_top else min_y)
	var cells: Array[Vector3i] = []
	for plane_y: int in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for plane_x: int in range(bounds.position.x, bounds.position.x + bounds.size.x):
			var point: Vector2 = Vector2(float(plane_x) + 0.5, float(plane_y) + 0.5)
			if not _point_in_triangle(point, apex, base_left, base_right):
				continue
			cells.append(_plane_to_grid_position(Vector2i(plane_x, plane_y), active_plane, active_layer, grid_size))
	return cells

func _get_additive_shape_tool_id(tool_id: StringName) -> StringName:
	if tool_id == FAMILY_CIRCLE or is_circle_tool(tool_id):
		return TOOL_CIRCLE_PLACE
	if tool_id == FAMILY_OVAL or is_oval_tool(tool_id):
		return TOOL_OVAL_PLACE
	if tool_id == FAMILY_TRIANGLE or is_triangle_tool(tool_id):
		return TOOL_TRIANGLE_PLACE
	return TOOL_RECTANGLE_PLACE

func _get_subtractive_shape_tool_id(tool_id: StringName) -> StringName:
	if tool_id == FAMILY_CIRCLE or is_circle_tool(tool_id):
		return TOOL_CIRCLE_ERASE
	if tool_id == FAMILY_OVAL or is_oval_tool(tool_id):
		return TOOL_OVAL_ERASE
	if tool_id == FAMILY_TRIANGLE or is_triangle_tool(tool_id):
		return TOOL_TRIANGLE_ERASE
	return TOOL_RECTANGLE_ERASE

func _build_plane_bounds(
	anchor_grid_position: Vector3i,
	current_grid_position: Vector3i,
	active_plane: StringName,
	grid_size: Vector3i
) -> Rect2i:
	var anchor_plane_position: Vector2i = _grid_to_plane_position(anchor_grid_position, active_plane, grid_size)
	var current_plane_position: Vector2i = _grid_to_plane_position(current_grid_position, active_plane, grid_size)
	var min_x: int = mini(anchor_plane_position.x, current_plane_position.x)
	var max_x: int = maxi(anchor_plane_position.x, current_plane_position.x)
	var min_y: int = mini(anchor_plane_position.y, current_plane_position.y)
	var max_y: int = maxi(anchor_plane_position.y, current_plane_position.y)
	return Rect2i(min_x, min_y, (max_x - min_x) + 1, (max_y - min_y) + 1)

func _build_ellipse_footprint(
	bounds: Rect2i,
	active_plane: StringName,
	active_layer: int,
	grid_size: Vector3i,
	center_x: float,
	center_y: float,
	radius_x: float,
	radius_y: float
) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for plane_y: int in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for plane_x: int in range(bounds.position.x, bounds.position.x + bounds.size.x):
			var normalized_x: float = ((float(plane_x) + 0.5) - center_x) / maxf(radius_x, 0.0001)
			var normalized_y: float = ((float(plane_y) + 0.5) - center_y) / maxf(radius_y, 0.0001)
			if normalized_x * normalized_x + normalized_y * normalized_y > 1.0:
				continue
			cells.append(_plane_to_grid_position(Vector2i(plane_x, plane_y), active_plane, active_layer, grid_size))
	return cells

func _grid_to_plane_position(
	grid_position: Vector3i,
	active_plane: StringName,
	grid_size: Vector3i
) -> Vector2i:
	match active_plane:
		&"zx":
			return Vector2i(grid_position.z, (grid_size.x - 1) - grid_position.x)
		&"zy":
			return Vector2i(grid_position.z, (grid_size.y - 1) - grid_position.y)
		_:
			return Vector2i(grid_position.x, (grid_size.y - 1) - grid_position.y)

func _plane_to_grid_position(
	plane_position: Vector2i,
	active_plane: StringName,
	active_layer: int,
	grid_size: Vector3i
) -> Vector3i:
	match active_plane:
		&"zx":
			return Vector3i((grid_size.x - 1) - plane_position.y, active_layer, plane_position.x)
		&"zy":
			return Vector3i(active_layer, (grid_size.y - 1) - plane_position.y, plane_position.x)
		_:
			return Vector3i(plane_position.x, (grid_size.y - 1) - plane_position.y, active_layer)

func _point_in_triangle(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var denominator: float = ((b.y - c.y) * (a.x - c.x)) + ((c.x - b.x) * (a.y - c.y))
	if is_zero_approx(denominator):
		return false
	var alpha: float = (((b.y - c.y) * (point.x - c.x)) + ((c.x - b.x) * (point.y - c.y))) / denominator
	var beta: float = (((c.y - a.y) * (point.x - c.x)) + ((a.x - c.x) * (point.y - c.y))) / denominator
	var gamma: float = 1.0 - alpha - beta
	return alpha >= 0.0 and beta >= 0.0 and gamma >= 0.0

func get_rotation_degrees(rotation_quadrant: int) -> int:
	return _normalize_rotation_quadrant(rotation_quadrant) * 90

func _rotate_shape_footprint(
	cells: Array[Vector3i],
	active_plane: StringName,
	active_layer: int,
	grid_size: Vector3i,
	rotation_quadrant: int
) -> Array[Vector3i]:
	var normalized_rotation_quadrant: int = _normalize_rotation_quadrant(rotation_quadrant)
	if normalized_rotation_quadrant == 0 or cells.is_empty():
		return cells.duplicate()
	var plane_positions: Array[Vector2i] = []
	var min_x: int = 2147483647
	var max_x: int = -2147483648
	var min_y: int = 2147483647
	var max_y: int = -2147483648
	for grid_position: Vector3i in cells:
		var plane_position: Vector2i = _grid_to_plane_position(grid_position, active_plane, grid_size)
		plane_positions.append(plane_position)
		min_x = mini(min_x, plane_position.x)
		max_x = maxi(max_x, plane_position.x)
		min_y = mini(min_y, plane_position.y)
		max_y = maxi(max_y, plane_position.y)
	var center_x: float = (float(min_x) + float(max_x) + 1.0) * 0.5
	var center_y: float = (float(min_y) + float(max_y) + 1.0) * 0.5
	var rotated_cells: Array[Vector3i] = []
	var visited: Dictionary = {}
	for plane_position: Vector2i in plane_positions:
		var rotated_plane_position: Vector2i = _rotate_plane_position_around_center(
			plane_position,
			center_x,
			center_y,
			normalized_rotation_quadrant
		)
		if not _is_plane_position_in_bounds(rotated_plane_position, active_plane, grid_size):
			continue
		var rotated_grid_position: Vector3i = _plane_to_grid_position(rotated_plane_position, active_plane, active_layer, grid_size)
		if visited.has(rotated_grid_position):
			continue
		visited[rotated_grid_position] = true
		rotated_cells.append(rotated_grid_position)
	return rotated_cells

func _rotate_plane_position_around_center(
	plane_position: Vector2i,
	center_x: float,
	center_y: float,
	rotation_quadrant: int
) -> Vector2i:
	var offset_x: float = (float(plane_position.x) + 0.5) - center_x
	var offset_y: float = (float(plane_position.y) + 0.5) - center_y
	var rotated_offset: Vector2 = Vector2(offset_x, offset_y)
	match rotation_quadrant:
		1:
			rotated_offset = Vector2(-offset_y, offset_x)
		2:
			rotated_offset = Vector2(-offset_x, -offset_y)
		3:
			rotated_offset = Vector2(offset_y, -offset_x)
	var rotated_center_x: float = center_x + rotated_offset.x
	var rotated_center_y: float = center_y + rotated_offset.y
	return Vector2i(
		int(round(rotated_center_x - 0.5)),
		int(round(rotated_center_y - 0.5))
	)

func _is_plane_position_in_bounds(
	plane_position: Vector2i,
	active_plane: StringName,
	grid_size: Vector3i
) -> bool:
	var plane_width: int = 0
	var plane_height: int = 0
	match active_plane:
		&"zx":
			plane_width = grid_size.z
			plane_height = grid_size.x
		&"zy":
			plane_width = grid_size.z
			plane_height = grid_size.y
		_:
			plane_width = grid_size.x
			plane_height = grid_size.y
	return (
		plane_position.x >= 0
		and plane_position.y >= 0
		and plane_position.x < plane_width
		and plane_position.y < plane_height
	)

func _normalize_rotation_quadrant(rotation_quadrant: int) -> int:
	return posmod(rotation_quadrant, 4)
