extends RefCounted
class_name ForgeV2ProfileShapeLibrary

const PrimaryGripSliceProfileLibraryScript = preload("res://core/defs/primary_grip_slice_profile_library.gd")

const PROFILE_FAMILY_BASIC := &"profile_family_basic"
const PROFILE_FAMILY_HANDLE := &"profile_family_handle"
const PROFILE_ROLE_NONE := &"profile_role_none"
const PROFILE_ROLE_HANDLE := &"profile_role_handle"
const PROFILE_2D_BUILDER := &"profile_2d_builder"
const PROFILE_CIRCLE := &"profile_circle"
const PROFILE_SQUARE := &"profile_square"
const PROFILE_TRIANGLE := &"profile_triangle"
const PROFILE_HANDLE_BUILDER := &"profile_handle_builder"

const DEFAULT_CELL_WORLD_SIZE_METERS := 0.0125
const DEFAULT_RADIUS_METERS := 0.025
const DEFAULT_CIRCLE_SIDES := 24
const BASIC_BUILDER_DEFAULT_WIDTH_METERS := DEFAULT_RADIUS_METERS * 2.0
const BASIC_BUILDER_DEFAULT_HEIGHT_METERS := DEFAULT_RADIUS_METERS * 2.0
const BASIC_BUILDER_LIMIT_PRESET_ID := PrimaryGripSliceProfileLibraryScript.PRESET_HEX_24
const BASIC_BUILDER_GRID_STEP_METERS := DEFAULT_CELL_WORLD_SIZE_METERS * 0.5
const BASIC_FILLET_RADIUS_MIN_METERS := 0.001
const BASIC_FILLET_RADIUS_DEFAULT_METERS := 0.01
const BASIC_FILLET_RADIUS_INPUT_MAX_METERS := 0.3
const BASIC_FILLET_EDGE_BUDGET_RATIO := 0.99
const BASIC_FILLET_SEGMENTS := 5
const BASIC_FILLET_GEOMETRY_EPSILON := 0.000001
const BASIC_FILLET_CROSS_EPSILON := 0.0000000001
const BASIC_FILLET_AREA_EPSILON := 0.000000000001
const BASIC_FILLET_ANGLE_EPSILON := 0.0001
const HANDLE_FACE_COUNT_RECTANGLE := 4
const HANDLE_FACE_COUNT_OCTAGON := 8
const HANDLE_DEFAULT_WIDTH_METERS := DEFAULT_CELL_WORLD_SIZE_METERS * 2.0
const HANDLE_DEFAULT_HEIGHT_METERS := DEFAULT_CELL_WORLD_SIZE_METERS * 3.0
const HANDLE_DEFAULT_CORNER_RADIUS_METERS := DEFAULT_CELL_WORLD_SIZE_METERS * 0.25
const HANDLE_CORNER_RADIUS_MAX_RATIO := 0.49
const HANDLE_ROUNDED_CORNER_SEGMENTS := 5
const HANDLE_BUILDER_LIMIT_PRESET_ID := PrimaryGripSliceProfileLibraryScript.PRESET_HEX_24
const HANDLE_BUILDER_GRID_STEP_METERS := DEFAULT_CELL_WORLD_SIZE_METERS * 0.5

static func get_default_profile_id() -> StringName:
	return PROFILE_CIRCLE

static func get_default_basic_builder_profile_id() -> StringName:
	return PROFILE_2D_BUILDER

static func get_default_handle_profile_id() -> StringName:
	return PROFILE_HANDLE_BUILDER

static func normalize_profile_id(profile_id: StringName, profile_family: StringName = StringName()) -> StringName:
	if not get_profile_record(profile_id, DEFAULT_RADIUS_METERS).is_empty():
		if profile_family == StringName() or StringName(get_profile_record(profile_id, DEFAULT_RADIUS_METERS).get("family", StringName())) == profile_family:
			return profile_id
	if profile_family == PROFILE_FAMILY_HANDLE:
		return get_default_handle_profile_id()
	if profile_family == PROFILE_FAMILY_BASIC:
		return get_default_basic_builder_profile_id()
	return get_default_profile_id()

static func get_profile_label(profile_id: StringName) -> String:
	var record := get_profile_record(profile_id, DEFAULT_RADIUS_METERS)
	return String(record.get("label", String(profile_id))) if not record.is_empty() else String(profile_id)

static func build_profile_entries(profile_family: StringName = StringName()) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in _build_basic_profile_entries():
		if profile_family == StringName() or StringName(entry.get("family", StringName())) == profile_family:
			entries.append(entry)
	for entry: Dictionary in _build_handle_profile_entries():
		if profile_family == StringName() or StringName(entry.get("family", StringName())) == profile_family:
			entries.append(entry)
	return entries

static func build_handle_profile_entries() -> Array[Dictionary]:
	return _build_handle_profile_entries()

static func get_profile_record(profile_id: StringName, radius_meters: float = DEFAULT_RADIUS_METERS) -> Dictionary:
	for entry: Dictionary in _build_basic_profile_entries(radius_meters):
		if StringName(entry.get("id", StringName())) == profile_id:
			return entry
	for entry: Dictionary in _build_handle_profile_entries():
		if StringName(entry.get("id", StringName())) == profile_id:
			return entry
	return {}

static func resolve_profile_polygon(profile_id: StringName, radius_meters: float = DEFAULT_RADIUS_METERS) -> PackedVector2Array:
	var record := get_profile_record(profile_id, radius_meters)
	if record.is_empty():
		return build_circle_polygon(radius_meters)
	var polygon: PackedVector2Array = record.get("polygon", PackedVector2Array())
	return polygon if polygon.size() >= 3 else build_circle_polygon(radius_meters)

static func resolve_profile_anchor(profile_id: StringName) -> Vector2:
	var record := get_profile_record(profile_id, DEFAULT_RADIUS_METERS)
	if record.is_empty():
		return Vector2.ZERO
	return record.get("anchor_2d_meters", Vector2.ZERO) as Vector2

static func calculate_polygon_area_meters_squared(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var area := 0.0
	for point_index in range(polygon.size()):
		var current_point: Vector2 = polygon[point_index]
		var next_point: Vector2 = polygon[(point_index + 1) % polygon.size()]
		area += current_point.x * next_point.y
		area -= next_point.x * current_point.y
	return absf(area) * 0.5

static func calculate_polygon_max_radius_meters(polygon: PackedVector2Array) -> float:
	var max_radius := 0.0
	for point: Vector2 in polygon:
		max_radius = maxf(max_radius, point.length())
	return max_radius

static func calculate_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
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

static func calculate_polygon_size_meters(polygon: PackedVector2Array) -> Vector2:
	var bounds := calculate_polygon_bounds(polygon)
	return Vector2(maxf(bounds.size.x, 0.0), maxf(bounds.size.y, 0.0))

static func transform_profile_polygon(
	polygon: PackedVector2Array,
	target_size_meters: Vector2,
	anchor_2d_meters: Vector2 = Vector2.ZERO,
	rotation_degrees: float = 0.0
) -> PackedVector2Array:
	if polygon.size() < 3:
		return polygon
	var bounds := calculate_polygon_bounds(polygon)
	var source_size := Vector2(maxf(bounds.size.x, 0.000001), maxf(bounds.size.y, 0.000001))
	var scale := Vector2(
		maxf(target_size_meters.x, 0.000001) / source_size.x,
		maxf(target_size_meters.y, 0.000001) / source_size.y
	)
	var center := bounds.position + bounds.size * 0.5
	var rotation_radians := deg_to_rad(rotation_degrees)
	var transformed := PackedVector2Array()
	for point: Vector2 in polygon:
		var local_point := Vector2((point.x - center.x) * scale.x, (point.y - center.y) * scale.y)
		transformed.append(local_point.rotated(rotation_radians) - anchor_2d_meters)
	return transformed

static func build_circle_polygon(radius_meters: float, side_count: int = DEFAULT_CIRCLE_SIDES) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var resolved_side_count := maxi(side_count, 8)
	var resolved_radius := maxf(radius_meters, 0.001)
	for side_index in range(resolved_side_count):
		var angle := TAU * float(side_index) / float(resolved_side_count)
		polygon.append(Vector2(cos(angle), sin(angle)) * resolved_radius)
	return polygon

static func build_default_basic_control_points(
	width_meters: float = BASIC_BUILDER_DEFAULT_WIDTH_METERS,
	height_meters: float = BASIC_BUILDER_DEFAULT_HEIGHT_METERS
) -> PackedVector2Array:
	var half_width := maxf(width_meters, DEFAULT_CELL_WORLD_SIZE_METERS) * 0.5
	var half_height := maxf(height_meters, DEFAULT_CELL_WORLD_SIZE_METERS) * 0.5
	return PackedVector2Array([
		Vector2(-half_width, -half_height),
		Vector2(half_width, -half_height),
		Vector2(half_width, half_height),
		Vector2(-half_width, half_height),
	])

static func build_basic_builder_polygon(
	control_points: PackedVector2Array,
	corner_metadata: Array = []
) -> PackedVector2Array:
	var resolved_geometry := resolve_basic_builder_fillet_geometry(control_points, corner_metadata)
	return resolved_geometry.get("polygon", control_points) as PackedVector2Array

static func resolve_basic_builder_fillet_geometry(
	control_points: PackedVector2Array,
	corner_metadata: Array = []
) -> Dictionary:
	var point_count := control_points.size()
	var corner_results: Array[Dictionary] = []
	var requested_radii: Array[float] = []
	var requested_tangents: Array[float] = []
	var signed_turns: Array[float] = []
	var eligible_corners: Array[bool] = []
	var corner_types: Array[StringName] = []
	var arc_paths: Array = []
	requested_radii.resize(point_count)
	requested_tangents.resize(point_count)
	signed_turns.resize(point_count)
	eligible_corners.resize(point_count)
	corner_types.resize(point_count)
	arc_paths.resize(point_count)

	for point_index in range(point_count):
		var metadata: Dictionary = {}
		if point_index < corner_metadata.size() and corner_metadata[point_index] is Dictionary:
			metadata = corner_metadata[point_index] as Dictionary
		var corner_id := StringName(String(metadata.get("corner_id", "")))
		if corner_id == StringName():
			corner_id = StringName("basic_corner_%d" % point_index)
		var has_radius_metadata := metadata.has("radius_meters")
		var requested_radius := 0.0
		var radius_is_valid := false
		if has_radius_metadata:
			var radius_value: Variant = metadata.get("radius_meters")
			if typeof(radius_value) == TYPE_FLOAT or typeof(radius_value) == TYPE_INT:
				requested_radius = float(radius_value)
				radius_is_valid = (
					is_finite(requested_radius)
					and requested_radius >= BASIC_FILLET_RADIUS_MIN_METERS
					and requested_radius <= BASIC_FILLET_RADIUS_INPUT_MAX_METERS
				)
		var initial_status := &"pending"
		if not has_radius_metadata:
			initial_status = &"sharp_missing_radius"
		elif not radius_is_valid:
			initial_status = &"sharp_invalid_radius"
		corner_results.append({
			"corner_id": corner_id,
			"index": point_index,
			"has_fillet": radius_is_valid,
			"requested": requested_radius if radius_is_valid else 0.0,
			"effective": 0.0,
			"requested_radius_meters": requested_radius if radius_is_valid else 0.0,
			"effective_radius_meters": 0.0,
			"status": initial_status,
			"arc_points": PackedVector2Array(),
		})
		requested_radii[point_index] = requested_radius if radius_is_valid else 0.0
		requested_tangents[point_index] = 0.0
		signed_turns[point_index] = 0.0
		eligible_corners[point_index] = radius_is_valid
		corner_types[point_index] = StringName()
		arc_paths[point_index] = PackedVector2Array()

	var raw_polygon_valid := _basic_fillet_polygon_is_valid(control_points)
	if not raw_polygon_valid:
		for point_index in range(point_count):
			if not eligible_corners[point_index]:
				continue
			var invalid_result: Dictionary = corner_results[point_index]
			invalid_result["status"] = &"sharp_invalid_raw_polygon"
			corner_results[point_index] = invalid_result
		var raw_fallback := (
			build_default_basic_control_points()
			if point_count < 3
			else control_points
		)
		return {
			"polygon": raw_fallback,
			"raw_polygon_valid": false,
			"output_valid": _basic_fillet_polygon_is_valid(raw_fallback),
			"used_all_sharp_fallback": true,
			"corner_results": corner_results,
		}

	var raw_signed_area := _calculate_signed_polygon_area(control_points)
	var winding_sign := 1.0 if raw_signed_area > 0.0 else -1.0
	for point_index in range(point_count):
		if not eligible_corners[point_index]:
			continue
		var previous_point := control_points[(point_index - 1 + point_count) % point_count]
		var current_point := control_points[point_index]
		var next_point := control_points[(point_index + 1) % point_count]
		var incoming_edge := current_point - previous_point
		var outgoing_edge := next_point - current_point
		if (
			incoming_edge.length() <= BASIC_FILLET_GEOMETRY_EPSILON
			or outgoing_edge.length() <= BASIC_FILLET_GEOMETRY_EPSILON
		):
			eligible_corners[point_index] = false
			var degenerate_result: Dictionary = corner_results[point_index]
			degenerate_result["status"] = &"sharp_degenerate_corner"
			corner_results[point_index] = degenerate_result
			continue
		var incoming_direction := incoming_edge.normalized()
		var outgoing_direction := outgoing_edge.normalized()
		var signed_turn := atan2(
			incoming_direction.cross(outgoing_direction),
			incoming_direction.dot(outgoing_direction)
		)
		var absolute_turn := absf(signed_turn)
		if (
			not is_finite(signed_turn)
			or absolute_turn <= BASIC_FILLET_ANGLE_EPSILON
			or PI - absolute_turn <= BASIC_FILLET_ANGLE_EPSILON
		):
			eligible_corners[point_index] = false
			var unsafe_turn_result: Dictionary = corner_results[point_index]
			unsafe_turn_result["status"] = &"sharp_unsafe_turn"
			corner_results[point_index] = unsafe_turn_result
			continue
		var tangent_distance := (
			requested_radii[point_index]
			* tan(absolute_turn * 0.5)
		)
		if not is_finite(tangent_distance) or tangent_distance <= BASIC_FILLET_GEOMETRY_EPSILON:
			eligible_corners[point_index] = false
			var tangent_result: Dictionary = corner_results[point_index]
			tangent_result["status"] = &"sharp_unsafe_turn"
			corner_results[point_index] = tangent_result
			continue
		requested_tangents[point_index] = tangent_distance
		signed_turns[point_index] = signed_turn
		corner_types[point_index] = (
			&"convex"
			if (1.0 if signed_turn > 0.0 else -1.0) == winding_sign
			else &"concave"
		)

	var edge_factors: Array[float] = []
	edge_factors.resize(point_count)
	for point_index in range(point_count):
		var next_index := (point_index + 1) % point_count
		var edge_length := control_points[point_index].distance_to(control_points[next_index])
		var tangent_demand := (
			requested_tangents[point_index]
			+ requested_tangents[next_index]
		)
		edge_factors[point_index] = 1.0
		if tangent_demand > BASIC_FILLET_GEOMETRY_EPSILON:
			edge_factors[point_index] = minf(
				1.0,
				(BASIC_FILLET_EDGE_BUDGET_RATIO * edge_length) / tangent_demand
			)

	for point_index in range(point_count):
		if not eligible_corners[point_index]:
			continue
		var previous_edge_index := (point_index - 1 + point_count) % point_count
		var corner_scale := minf(
			edge_factors[previous_edge_index],
			edge_factors[point_index]
		)
		var effective_radius := requested_radii[point_index] * corner_scale
		var effective_tangent := requested_tangents[point_index] * corner_scale
		if (
			effective_radius <= BASIC_FILLET_GEOMETRY_EPSILON
			or effective_tangent <= BASIC_FILLET_GEOMETRY_EPSILON
		):
			eligible_corners[point_index] = false
			var budget_result: Dictionary = corner_results[point_index]
			budget_result["status"] = &"sharp_budget_too_small"
			corner_results[point_index] = budget_result
			continue
		var previous_point := control_points[(point_index - 1 + point_count) % point_count]
		var current_point := control_points[point_index]
		var next_point := control_points[(point_index + 1) % point_count]
		var incoming_direction := (current_point - previous_point).normalized()
		var outgoing_direction := (next_point - current_point).normalized()
		var signed_turn := signed_turns[point_index]
		var turn_sign := 1.0 if signed_turn > 0.0 else -1.0
		var tangent_from_previous := current_point - incoming_direction * effective_tangent
		var tangent_to_next := current_point + outgoing_direction * effective_tangent
		var incoming_left_normal := Vector2(-incoming_direction.y, incoming_direction.x)
		var outgoing_left_normal := Vector2(-outgoing_direction.y, outgoing_direction.x)
		var center_from_previous := (
			tangent_from_previous
			+ incoming_left_normal * effective_radius * turn_sign
		)
		var center_from_next := (
			tangent_to_next
			+ outgoing_left_normal * effective_radius * turn_sign
		)
		var center_tolerance := maxf(
			BASIC_FILLET_GEOMETRY_EPSILON * 8.0,
			effective_radius * 0.001
		)
		if center_from_previous.distance_to(center_from_next) > center_tolerance:
			eligible_corners[point_index] = false
			var numerical_result: Dictionary = corner_results[point_index]
			numerical_result["status"] = &"sharp_numerical_failure"
			corner_results[point_index] = numerical_result
			continue
		var arc_center := (center_from_previous + center_from_next) * 0.5
		var start_angle := (tangent_from_previous - arc_center).angle()
		var arc_points := PackedVector2Array()
		for segment_index in range(BASIC_FILLET_SEGMENTS + 1):
			if segment_index == 0:
				arc_points.append(tangent_from_previous)
				continue
			if segment_index == BASIC_FILLET_SEGMENTS:
				arc_points.append(tangent_to_next)
				continue
			var segment_ratio := float(segment_index) / float(BASIC_FILLET_SEGMENTS)
			var arc_angle := start_angle + signed_turn * segment_ratio
			arc_points.append(
				arc_center
				+ Vector2(cos(arc_angle), sin(arc_angle)) * effective_radius
			)
		arc_paths[point_index] = arc_points
		var resolved_result: Dictionary = corner_results[point_index]
		resolved_result["effective"] = effective_radius
		resolved_result["effective_radius_meters"] = effective_radius
		resolved_result["status"] = (
			&"fillet_concave"
			if corner_types[point_index] == &"concave"
			else &"fillet_convex"
		)
		resolved_result["arc_points"] = arc_points
		corner_results[point_index] = resolved_result

	var candidate_polygon := PackedVector2Array()
	for point_index in range(point_count):
		var arc_points: PackedVector2Array = arc_paths[point_index]
		if arc_points.is_empty():
			_basic_fillet_append_unique(candidate_polygon, control_points[point_index])
			continue
		for arc_point: Vector2 in arc_points:
			_basic_fillet_append_unique(candidate_polygon, arc_point)
	if (
		candidate_polygon.size() > 1
		and candidate_polygon[0].distance_to(candidate_polygon[candidate_polygon.size() - 1])
		<= BASIC_FILLET_GEOMETRY_EPSILON
	):
		candidate_polygon.remove_at(candidate_polygon.size() - 1)

	var candidate_valid := (
		_basic_fillet_polygon_is_valid(candidate_polygon)
		and _calculate_signed_polygon_area(candidate_polygon) * raw_signed_area > 0.0
	)
	if not candidate_valid:
		for point_index in range(point_count):
			var fallback_result: Dictionary = corner_results[point_index]
			var fallback_arc: PackedVector2Array = fallback_result.get(
				"arc_points",
				PackedVector2Array()
			) as PackedVector2Array
			if not fallback_arc.is_empty():
				fallback_result["effective"] = 0.0
				fallback_result["effective_radius_meters"] = 0.0
				fallback_result["status"] = &"sharp_unsafe_candidate"
				fallback_result["arc_points"] = PackedVector2Array()
				corner_results[point_index] = fallback_result
		return {
			"polygon": control_points,
			"raw_polygon_valid": true,
			"output_valid": true,
			"used_all_sharp_fallback": true,
			"corner_results": corner_results,
		}

	return {
		"polygon": candidate_polygon,
		"raw_polygon_valid": true,
		"output_valid": true,
		"used_all_sharp_fallback": false,
		"corner_results": corner_results,
	}

static func _basic_fillet_append_unique(points: PackedVector2Array, point: Vector2) -> void:
	if (
		not points.is_empty()
		and points[points.size() - 1].distance_to(point)
		<= BASIC_FILLET_GEOMETRY_EPSILON
	):
		return
	points.append(point)

static func _basic_fillet_polygon_is_valid(polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	for point_index in range(polygon.size()):
		var point := polygon[point_index]
		var next_point := polygon[(point_index + 1) % polygon.size()]
		if not is_finite(point.x) or not is_finite(point.y):
			return false
		if point.distance_to(next_point) <= BASIC_FILLET_GEOMETRY_EPSILON:
			return false
	if absf(_calculate_signed_polygon_area(polygon)) <= BASIC_FILLET_AREA_EPSILON:
		return false
	if not _basic_fillet_polygon_is_simple(polygon):
		return false
	return Geometry2D.triangulate_polygon(polygon).size() >= 3

static func _basic_fillet_polygon_is_simple(polygon: PackedVector2Array) -> bool:
	var edge_count := polygon.size()
	for first_edge_index in range(edge_count):
		var first_edge_end_index := (first_edge_index + 1) % edge_count
		var first_a := polygon[first_edge_index]
		var first_b := polygon[first_edge_end_index]
		for second_edge_index in range(first_edge_index + 1, edge_count):
			var second_edge_end_index := (second_edge_index + 1) % edge_count
			if (
				first_edge_index == second_edge_index
				or first_edge_end_index == second_edge_index
				or second_edge_end_index == first_edge_index
			):
				continue
			if _basic_fillet_segments_intersect(
				first_a,
				first_b,
				polygon[second_edge_index],
				polygon[second_edge_end_index]
			):
				return false
	return true

static func _basic_fillet_segments_intersect(
	first_a: Vector2,
	first_b: Vector2,
	second_a: Vector2,
	second_b: Vector2
) -> bool:
	var first_edge := first_b - first_a
	var second_edge := second_b - second_a
	var cross_first_a := first_edge.cross(second_a - first_a)
	var cross_first_b := first_edge.cross(second_b - first_a)
	var cross_second_a := second_edge.cross(first_a - second_a)
	var cross_second_b := second_edge.cross(first_b - second_a)
	if (
		_basic_fillet_crosses_opposite_sides(cross_first_a, cross_first_b)
		and _basic_fillet_crosses_opposite_sides(cross_second_a, cross_second_b)
	):
		return true
	if (
		absf(cross_first_a) <= BASIC_FILLET_CROSS_EPSILON
		and _basic_fillet_point_on_segment(second_a, first_a, first_b)
	):
		return true
	if (
		absf(cross_first_b) <= BASIC_FILLET_CROSS_EPSILON
		and _basic_fillet_point_on_segment(second_b, first_a, first_b)
	):
		return true
	if (
		absf(cross_second_a) <= BASIC_FILLET_CROSS_EPSILON
		and _basic_fillet_point_on_segment(first_a, second_a, second_b)
	):
		return true
	if (
		absf(cross_second_b) <= BASIC_FILLET_CROSS_EPSILON
		and _basic_fillet_point_on_segment(first_b, second_a, second_b)
	):
		return true
	return false

static func _basic_fillet_crosses_opposite_sides(first_cross: float, second_cross: float) -> bool:
	return (
		(
			first_cross > BASIC_FILLET_CROSS_EPSILON
			and second_cross < -BASIC_FILLET_CROSS_EPSILON
		)
		or (
			first_cross < -BASIC_FILLET_CROSS_EPSILON
			and second_cross > BASIC_FILLET_CROSS_EPSILON
		)
	)

static func _basic_fillet_point_on_segment(
	point: Vector2,
	segment_a: Vector2,
	segment_b: Vector2
) -> bool:
	return (
		point.x >= minf(segment_a.x, segment_b.x) - BASIC_FILLET_GEOMETRY_EPSILON
		and point.x <= maxf(segment_a.x, segment_b.x) + BASIC_FILLET_GEOMETRY_EPSILON
		and point.y >= minf(segment_a.y, segment_b.y) - BASIC_FILLET_GEOMETRY_EPSILON
		and point.y <= maxf(segment_a.y, segment_b.y) + BASIC_FILLET_GEOMETRY_EPSILON
	)

static func normalize_handle_face_count(face_count: int) -> int:
	return HANDLE_FACE_COUNT_OCTAGON if face_count >= 6 else HANDLE_FACE_COUNT_RECTANGLE

static func build_default_handle_control_points(
	face_count: int = HANDLE_FACE_COUNT_RECTANGLE,
	width_meters: float = HANDLE_DEFAULT_WIDTH_METERS,
	height_meters: float = HANDLE_DEFAULT_HEIGHT_METERS
) -> PackedVector2Array:
	var resolved_face_count := normalize_handle_face_count(face_count)
	var half_width := maxf(width_meters, DEFAULT_CELL_WORLD_SIZE_METERS) * 0.5
	var half_height := maxf(height_meters, DEFAULT_CELL_WORLD_SIZE_METERS) * 0.5
	if resolved_face_count == HANDLE_FACE_COUNT_OCTAGON:
		var corner_cut := minf(half_width, half_height) * 0.45
		return PackedVector2Array([
			Vector2(-half_width + corner_cut, -half_height),
			Vector2(half_width - corner_cut, -half_height),
			Vector2(half_width, -half_height + corner_cut),
			Vector2(half_width, half_height - corner_cut),
			Vector2(half_width - corner_cut, half_height),
			Vector2(-half_width + corner_cut, half_height),
			Vector2(-half_width, half_height - corner_cut),
			Vector2(-half_width, -half_height + corner_cut),
		])
	return PackedVector2Array([
		Vector2(-half_width, -half_height),
		Vector2(half_width, -half_height),
		Vector2(half_width, half_height),
		Vector2(-half_width, half_height),
	])

static func build_handle_builder_polygon(
	control_points: PackedVector2Array,
	rounded_enabled: bool = true,
	corner_radius_meters: float = HANDLE_DEFAULT_CORNER_RADIUS_METERS
) -> PackedVector2Array:
	if control_points.size() < 3:
		return build_default_handle_control_points()
	if not rounded_enabled:
		return control_points
	var clamped_radius := clampf(
		corner_radius_meters,
		0.0,
		calculate_max_corner_radius_meters(control_points)
	)
	if clamped_radius <= 0.0:
		return control_points
	return _build_rounded_polygon(control_points, clamped_radius, HANDLE_ROUNDED_CORNER_SEGMENTS)

static func normalize_control_points_to_center(control_points: PackedVector2Array) -> PackedVector2Array:
	if control_points.is_empty():
		return control_points
	var bounds := calculate_polygon_bounds(control_points)
	var center := bounds.position + bounds.size * 0.5
	var centered_points := PackedVector2Array()
	for point: Vector2 in control_points:
		centered_points.append(point - center)
	return centered_points

static func scale_control_points_to_size(control_points: PackedVector2Array, target_size_meters: Vector2) -> PackedVector2Array:
	if control_points.size() < 3:
		return build_default_handle_control_points(
			HANDLE_FACE_COUNT_RECTANGLE,
			target_size_meters.x,
			target_size_meters.y
		)
	var centered_points := normalize_control_points_to_center(control_points)
	var bounds := calculate_polygon_bounds(centered_points)
	var source_size := Vector2(maxf(bounds.size.x, 0.000001), maxf(bounds.size.y, 0.000001))
	var target_size := Vector2(
		maxf(target_size_meters.x, DEFAULT_CELL_WORLD_SIZE_METERS),
		maxf(target_size_meters.y, DEFAULT_CELL_WORLD_SIZE_METERS)
	)
	var scale := Vector2(target_size.x / source_size.x, target_size.y / source_size.y)
	var scaled_points := PackedVector2Array()
	for point: Vector2 in centered_points:
		scaled_points.append(Vector2(point.x * scale.x, point.y * scale.y))
	return normalize_control_points_to_center(scaled_points)

static func calculate_shortest_side_length_meters(control_points: PackedVector2Array) -> float:
	if control_points.size() < 2:
		return 0.0
	var shortest_length := INF
	for point_index in range(control_points.size()):
		var next_index := (point_index + 1) % control_points.size()
		var side_length := control_points[point_index].distance_to(control_points[next_index])
		if side_length > 0.0:
			shortest_length = minf(shortest_length, side_length)
	return 0.0 if is_inf(shortest_length) else shortest_length

static func calculate_max_corner_radius_meters(control_points: PackedVector2Array) -> float:
	return maxf(calculate_shortest_side_length_meters(control_points) * HANDLE_CORNER_RADIUS_MAX_RATIO, 0.0)

static func get_handle_builder_limit_polygon() -> PackedVector2Array:
	return _build_mask_boundary_polygon(
		_get_primary_grip_preset_rows(HANDLE_BUILDER_LIMIT_PRESET_ID),
		DEFAULT_CELL_WORLD_SIZE_METERS
	)

static func get_basic_builder_limit_polygon() -> PackedVector2Array:
	return _build_mask_boundary_polygon(
		_get_primary_grip_preset_rows(BASIC_BUILDER_LIMIT_PRESET_ID),
		DEFAULT_CELL_WORLD_SIZE_METERS
	)

static func get_basic_builder_limit_size_meters() -> Vector2:
	return calculate_polygon_size_meters(get_basic_builder_limit_polygon())

static func get_handle_builder_limit_size_meters() -> Vector2:
	return calculate_polygon_size_meters(get_handle_builder_limit_polygon())

static func build_basic_builder_grid_segments(grid_step_meters: float = BASIC_BUILDER_GRID_STEP_METERS) -> Array:
	return _build_grid_segments_for_limit_polygon(get_basic_builder_limit_polygon(), grid_step_meters)

static func build_handle_builder_grid_segments(grid_step_meters: float = HANDLE_BUILDER_GRID_STEP_METERS) -> Array:
	return _build_grid_segments_for_limit_polygon(get_handle_builder_limit_polygon(), grid_step_meters)

static func build_basic_builder_grid_snap_points(grid_step_meters: float = BASIC_BUILDER_GRID_STEP_METERS) -> PackedVector2Array:
	return _build_grid_snap_points_for_limit_polygon(get_basic_builder_limit_polygon(), grid_step_meters)

static func build_handle_builder_grid_snap_points(grid_step_meters: float = HANDLE_BUILDER_GRID_STEP_METERS) -> PackedVector2Array:
	return _build_grid_snap_points_for_limit_polygon(get_handle_builder_limit_polygon(), grid_step_meters)

static func constrain_basic_builder_point(
	point: Vector2,
	grid_snapping_enabled: bool = false,
	grid_step_meters: float = BASIC_BUILDER_GRID_STEP_METERS
) -> Vector2:
	if not grid_snapping_enabled:
		return point
	return snap_point_to_grid(point, grid_step_meters)

static func constrain_basic_builder_points(
	points: PackedVector2Array,
	grid_snapping_enabled: bool = false,
	grid_step_meters: float = BASIC_BUILDER_GRID_STEP_METERS
) -> PackedVector2Array:
	var constrained_points := PackedVector2Array()
	for point: Vector2 in points:
		constrained_points.append(constrain_basic_builder_point(point, grid_snapping_enabled, grid_step_meters))
	return constrained_points

static func fit_centered_points_inside_basic_builder_limit(points: PackedVector2Array) -> PackedVector2Array:
	return _fit_centered_points_inside_limit(points, get_basic_builder_limit_polygon())

static func snap_point_to_grid(
	point: Vector2,
	grid_step_meters: float = BASIC_BUILDER_GRID_STEP_METERS,
	grid_rotation_degrees: float = 0.0
) -> Vector2:
	var step := maxf(grid_step_meters, 0.000001)
	var inverse_rotation := -deg_to_rad(grid_rotation_degrees)
	var grid_local_point := point.rotated(inverse_rotation)
	var snapped_grid_local_point := Vector2(
		roundf(grid_local_point.x / step) * step,
		roundf(grid_local_point.y / step) * step
	)
	return snapped_grid_local_point.rotated(-inverse_rotation)

static func snap_point_to_grid_inside_polygon(
	point: Vector2,
	polygon: PackedVector2Array,
	grid_step_meters: float = BASIC_BUILDER_GRID_STEP_METERS,
	grid_rotation_degrees: float = 0.0
) -> Vector2:
	if polygon.size() < 3:
		return snap_point_to_grid(point, grid_step_meters, grid_rotation_degrees)
	var step := maxf(grid_step_meters, 0.000001)
	var inverse_rotation := -deg_to_rad(grid_rotation_degrees)
	var grid_local_polygon := PackedVector2Array()
	for polygon_point: Vector2 in polygon:
		grid_local_polygon.append(polygon_point.rotated(inverse_rotation))
	var grid_local_point := point.rotated(inverse_rotation)
	var clamped_grid_local_point := clamp_point_to_polygon(
		grid_local_point,
		grid_local_polygon
	)
	var center_x_index := roundi(clamped_grid_local_point.x / step)
	var center_y_index := roundi(clamped_grid_local_point.y / step)
	var bounds := calculate_polygon_bounds(grid_local_polygon)
	var minimum_x_index := int(floor(bounds.position.x / step)) - 1
	var maximum_x_index := int(ceil(bounds.end.x / step)) + 1
	var minimum_y_index := int(floor(bounds.position.y / step)) - 1
	var maximum_y_index := int(ceil(bounds.end.y / step)) + 1
	var maximum_ring := maxi(
		maxi(
			absi(center_x_index - minimum_x_index),
			absi(maximum_x_index - center_x_index)
		),
		maxi(
			absi(center_y_index - minimum_y_index),
			absi(maximum_y_index - center_y_index)
		)
	)
	var nearest_grid_point := clamped_grid_local_point
	var nearest_distance_squared := INF
	for ring_index in range(maximum_ring + 1):
		var ring_min_x := center_x_index - ring_index
		var ring_max_x := center_x_index + ring_index
		var ring_min_y := center_y_index - ring_index
		var ring_max_y := center_y_index + ring_index
		for x_index in range(ring_min_x, ring_max_x + 1):
			for y_index in range(ring_min_y, ring_max_y + 1):
				if (
					ring_index > 0
					and x_index > ring_min_x
					and x_index < ring_max_x
					and y_index > ring_min_y
					and y_index < ring_max_y
				):
					continue
				if (
					x_index < minimum_x_index
					or x_index > maximum_x_index
					or y_index < minimum_y_index
					or y_index > maximum_y_index
				):
					continue
				var candidate := Vector2(
					float(x_index) * step,
					float(y_index) * step
				)
				if not _is_point_inside_or_on_polygon(candidate, grid_local_polygon):
					continue
				var distance_squared := candidate.distance_squared_to(
					clamped_grid_local_point
				)
				if distance_squared >= nearest_distance_squared:
					continue
				nearest_distance_squared = distance_squared
				nearest_grid_point = candidate
		if nearest_distance_squared < INF:
			var next_ring := ring_index + 1
			var next_left_x := float(center_x_index - next_ring) * step
			var next_right_x := float(center_x_index + next_ring) * step
			var next_bottom_y := float(center_y_index - next_ring) * step
			var next_top_y := float(center_y_index + next_ring) * step
			var minimum_unsearched_distance := minf(
				minf(
					absf(next_left_x - clamped_grid_local_point.x),
					absf(next_right_x - clamped_grid_local_point.x)
				),
				minf(
					absf(next_bottom_y - clamped_grid_local_point.y),
					absf(next_top_y - clamped_grid_local_point.y)
				)
			)
			if (
				nearest_distance_squared
				<= minimum_unsearched_distance * minimum_unsearched_distance
				+ 0.0000000001
			):
				break
	return nearest_grid_point.rotated(-inverse_rotation)

static func _build_grid_segments_for_limit_polygon(limit_polygon: PackedVector2Array, grid_step_meters: float) -> Array:
	if limit_polygon.size() < 3:
		return []
	var step := maxf(grid_step_meters, DEFAULT_CELL_WORLD_SIZE_METERS * 0.25)
	var bounds := calculate_polygon_bounds(limit_polygon)
	var min_x_index := int(floor(bounds.position.x / step))
	var max_x_index := int(ceil((bounds.position.x + bounds.size.x) / step))
	var min_y_index := int(floor(bounds.position.y / step))
	var max_y_index := int(ceil((bounds.position.y + bounds.size.y) / step))
	var segments: Array = []
	for y_index in range(min_y_index, max_y_index + 1):
		var y := float(y_index) * step
		for x_index in range(min_x_index, max_x_index):
			var point_a := Vector2(float(x_index) * step, y)
			var point_b := Vector2(float(x_index + 1) * step, y)
			if _is_point_inside_or_on_polygon((point_a + point_b) * 0.5, limit_polygon):
				segments.append(PackedVector2Array([point_a, point_b]))
	for x_index in range(min_x_index, max_x_index + 1):
		var x := float(x_index) * step
		for y_index in range(min_y_index, max_y_index):
			var point_a := Vector2(x, float(y_index) * step)
			var point_b := Vector2(x, float(y_index + 1) * step)
			if _is_point_inside_or_on_polygon((point_a + point_b) * 0.5, limit_polygon):
				segments.append(PackedVector2Array([point_a, point_b]))
	return segments

static func _build_grid_snap_points_for_limit_polygon(limit_polygon: PackedVector2Array, grid_step_meters: float) -> PackedVector2Array:
	if limit_polygon.size() < 3:
		return PackedVector2Array()
	var step := maxf(grid_step_meters, DEFAULT_CELL_WORLD_SIZE_METERS * 0.25)
	var bounds := calculate_polygon_bounds(limit_polygon)
	var min_x_index := int(floor(bounds.position.x / step))
	var max_x_index := int(ceil((bounds.position.x + bounds.size.x) / step))
	var min_y_index := int(floor(bounds.position.y / step))
	var max_y_index := int(ceil((bounds.position.y + bounds.size.y) / step))
	var points := PackedVector2Array()
	for y_index in range(min_y_index, max_y_index + 1):
		for x_index in range(min_x_index, max_x_index + 1):
			var point := Vector2(float(x_index) * step, float(y_index) * step)
			if _is_point_inside_or_on_polygon(point, limit_polygon):
				points.append(point)
	return points

static func constrain_handle_builder_point(
	point: Vector2,
	grid_snapping_enabled: bool = false,
	grid_step_meters: float = HANDLE_BUILDER_GRID_STEP_METERS
) -> Vector2:
	return _constrain_point_to_limit_polygon(
		point,
		get_handle_builder_limit_polygon(),
		build_handle_builder_grid_snap_points(grid_step_meters),
		grid_snapping_enabled
	)

static func _constrain_point_to_limit_polygon(
	point: Vector2,
	limit_polygon: PackedVector2Array,
	snap_points: PackedVector2Array,
	grid_snapping_enabled: bool
) -> Vector2:
	if limit_polygon.size() < 3:
		return point
	var clamped_point := clamp_point_to_polygon(point, limit_polygon)
	if not grid_snapping_enabled:
		return clamped_point
	if snap_points.is_empty():
		return clamped_point
	var nearest_point: Vector2 = snap_points[0]
	var nearest_distance := nearest_point.distance_squared_to(clamped_point)
	for snap_point: Vector2 in snap_points:
		var distance := snap_point.distance_squared_to(clamped_point)
		if distance >= nearest_distance:
			continue
		nearest_distance = distance
		nearest_point = snap_point
	return nearest_point

static func constrain_handle_builder_points(
	points: PackedVector2Array,
	grid_snapping_enabled: bool = false,
	grid_step_meters: float = HANDLE_BUILDER_GRID_STEP_METERS
) -> PackedVector2Array:
	var constrained_points := PackedVector2Array()
	for point: Vector2 in points:
		constrained_points.append(constrain_handle_builder_point(point, grid_snapping_enabled, grid_step_meters))
	return constrained_points

static func fit_centered_points_inside_handle_builder_limit(points: PackedVector2Array) -> PackedVector2Array:
	return _fit_centered_points_inside_limit(points, get_handle_builder_limit_polygon())

static func _fit_centered_points_inside_limit(points: PackedVector2Array, limit_polygon: PackedVector2Array) -> PackedVector2Array:
	var centered_points := normalize_control_points_to_center(points)
	if _are_points_inside_limit(centered_points, limit_polygon):
		return centered_points
	var fitted_points := PackedVector2Array()
	var low_scale := 0.0
	var high_scale := 1.0
	for iteration in range(24):
		var test_scale := (low_scale + high_scale) * 0.5
		var test_points := _scale_points_from_origin(centered_points, test_scale)
		if _are_points_inside_limit(test_points, limit_polygon):
			low_scale = test_scale
			fitted_points = test_points
		else:
			high_scale = test_scale
	if fitted_points.is_empty():
		return _scale_points_from_origin(centered_points, 0.0)
	return fitted_points

static func clamp_point_to_polygon(point: Vector2, polygon: PackedVector2Array) -> Vector2:
	if polygon.size() < 3:
		return point
	if _is_point_inside_or_on_polygon(point, polygon):
		return point
	var nearest_point: Vector2 = polygon[0]
	var nearest_distance := INF
	for point_index in range(polygon.size()):
		var segment_a: Vector2 = polygon[point_index]
		var segment_b: Vector2 = polygon[(point_index + 1) % polygon.size()]
		var candidate := _closest_point_on_segment(point, segment_a, segment_b)
		var distance := candidate.distance_squared_to(point)
		if distance >= nearest_distance:
			continue
		nearest_distance = distance
		nearest_point = candidate
	return nearest_point

static func _are_points_inside_handle_builder_limit(points: PackedVector2Array) -> bool:
	return _are_points_inside_limit(points, get_handle_builder_limit_polygon())

static func _are_points_inside_limit(points: PackedVector2Array, limit_polygon: PackedVector2Array) -> bool:
	if limit_polygon.size() < 3:
		return true
	for point: Vector2 in points:
		if not _is_point_inside_or_on_polygon(point, limit_polygon):
			return false
	return true

static func _scale_points_from_origin(points: PackedVector2Array, scale: float) -> PackedVector2Array:
	var scaled_points := PackedVector2Array()
	for point: Vector2 in points:
		scaled_points.append(point * scale)
	return scaled_points

static func _build_basic_profile_entries(radius_meters: float = DEFAULT_RADIUS_METERS) -> Array[Dictionary]:
	var radius := maxf(radius_meters, 0.001)
	var builder_control_points := build_default_basic_control_points(
		BASIC_BUILDER_DEFAULT_WIDTH_METERS,
		BASIC_BUILDER_DEFAULT_HEIGHT_METERS
	)
	return [
		_build_profile_record(
			PROFILE_2D_BUILDER,
			"2D Shape Builder",
			PROFILE_FAMILY_BASIC,
			PROFILE_ROLE_NONE,
			build_basic_builder_polygon(builder_control_points),
			Vector2.ZERO,
			{
				"source_library": &"forge_v2_2d_profile_builder",
				"control_points_2d_meters": builder_control_points,
			}
		),
		_build_profile_record(
			PROFILE_CIRCLE,
			"Circle",
			PROFILE_FAMILY_BASIC,
			PROFILE_ROLE_NONE,
			build_circle_polygon(radius),
			Vector2.ZERO
		),
		_build_profile_record(
			PROFILE_SQUARE,
			"Square",
			PROFILE_FAMILY_BASIC,
			PROFILE_ROLE_NONE,
			PackedVector2Array([
				Vector2(-radius, -radius),
				Vector2(radius, -radius),
				Vector2(radius, radius),
				Vector2(-radius, radius),
			]),
			Vector2.ZERO
		),
		_build_profile_record(
			PROFILE_TRIANGLE,
			"Triangle",
			PROFILE_FAMILY_BASIC,
			PROFILE_ROLE_NONE,
			PackedVector2Array([
				Vector2(0.0, radius),
				Vector2(radius * 0.8660254, -radius * 0.5),
				Vector2(-radius * 0.8660254, -radius * 0.5),
			]),
			Vector2.ZERO
		),
	]

static func _build_handle_profile_entries() -> Array[Dictionary]:
	var control_points := build_default_handle_control_points(
		HANDLE_FACE_COUNT_RECTANGLE,
		HANDLE_DEFAULT_WIDTH_METERS,
		HANDLE_DEFAULT_HEIGHT_METERS
	)
	var polygon := build_handle_builder_polygon(control_points, true, HANDLE_DEFAULT_CORNER_RADIUS_METERS)
	return [_build_profile_record(
		PROFILE_HANDLE_BUILDER,
		"Handle Builder",
		PROFILE_FAMILY_HANDLE,
		PROFILE_ROLE_HANDLE,
		polygon,
		Vector2.ZERO,
		{
			"source_library": &"forge_v2_handle_builder",
			"face_count": HANDLE_FACE_COUNT_RECTANGLE,
			"rounded_enabled": true,
			"corner_radius_meters": HANDLE_DEFAULT_CORNER_RADIUS_METERS,
			"control_points_2d_meters": control_points,
		}
	)]

static func _build_profile_record(
	profile_id: StringName,
	label: String,
	family: StringName,
	role: StringName,
	polygon: PackedVector2Array,
	anchor_2d_meters: Vector2,
	extras: Dictionary = {}
) -> Dictionary:
	var record := {
		"id": profile_id,
		"profile_id": profile_id,
		"label": label,
		"family": family,
		"role": role,
		"polygon": _apply_profile_anchor(polygon, anchor_2d_meters),
		"anchor_2d_meters": anchor_2d_meters,
		"area_meters_squared": calculate_polygon_area_meters_squared(_apply_profile_anchor(polygon, anchor_2d_meters)),
		"max_radius_meters": calculate_polygon_max_radius_meters(_apply_profile_anchor(polygon, anchor_2d_meters)),
	}
	for key: Variant in extras.keys():
		record[key] = extras[key]
	return record

static func _apply_profile_anchor(polygon: PackedVector2Array, anchor_2d_meters: Vector2) -> PackedVector2Array:
	if anchor_2d_meters == Vector2.ZERO:
		return polygon
	var shifted := PackedVector2Array()
	for point: Vector2 in polygon:
		shifted.append(point - anchor_2d_meters)
	return shifted

static func _build_rounded_polygon(
	control_points: PackedVector2Array,
	corner_radius_meters: float,
	corner_segments: int
) -> PackedVector2Array:
	if control_points.size() < 3:
		return control_points
	var rounded_polygon := PackedVector2Array()
	var signed_area := _calculate_signed_polygon_area(control_points)
	var is_clockwise := signed_area < 0.0
	var segment_count := maxi(corner_segments, 2)
	for point_index in range(control_points.size()):
		var previous_point: Vector2 = control_points[(point_index - 1 + control_points.size()) % control_points.size()]
		var current_point: Vector2 = control_points[point_index]
		var next_point: Vector2 = control_points[(point_index + 1) % control_points.size()]
		var previous_edge_length := current_point.distance_to(previous_point)
		var next_edge_length := current_point.distance_to(next_point)
		if previous_edge_length <= 0.000001 or next_edge_length <= 0.000001:
			rounded_polygon.append(current_point)
			continue
		var previous_direction := (previous_point - current_point).normalized()
		var next_direction := (next_point - current_point).normalized()
		var angle := acos(clampf(previous_direction.dot(next_direction), -1.0, 1.0))
		if angle <= 0.0001 or angle >= PI - 0.0001:
			rounded_polygon.append(current_point)
			continue
		var tangent_distance := corner_radius_meters / maxf(tan(angle * 0.5), 0.000001)
		tangent_distance = minf(tangent_distance, previous_edge_length * HANDLE_CORNER_RADIUS_MAX_RATIO)
		tangent_distance = minf(tangent_distance, next_edge_length * HANDLE_CORNER_RADIUS_MAX_RATIO)
		if tangent_distance <= 0.000001:
			rounded_polygon.append(current_point)
			continue
		var actual_radius := tangent_distance * tan(angle * 0.5)
		var tangent_from_previous := current_point + previous_direction * tangent_distance
		var tangent_to_next := current_point + next_direction * tangent_distance
		var bisector := (previous_direction + next_direction).normalized()
		if bisector.length_squared() <= 0.000001:
			rounded_polygon.append(current_point)
			continue
		var center_distance := actual_radius / maxf(sin(angle * 0.5), 0.000001)
		var arc_center := current_point + bisector * center_distance
		var start_angle := (tangent_from_previous - arc_center).angle()
		var end_angle := (tangent_to_next - arc_center).angle()
		if is_clockwise:
			while end_angle > start_angle:
				end_angle -= TAU
		else:
			while end_angle < start_angle:
				end_angle += TAU
		for segment_index in range(segment_count + 1):
			var segment_t := float(segment_index) / float(segment_count)
			var arc_angle := lerpf(start_angle, end_angle, segment_t)
			rounded_polygon.append(arc_center + Vector2(cos(arc_angle), sin(arc_angle)) * actual_radius)
	return rounded_polygon

static func _calculate_signed_polygon_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var area := 0.0
	for point_index in range(polygon.size()):
		var current_point: Vector2 = polygon[point_index]
		var next_point: Vector2 = polygon[(point_index + 1) % polygon.size()]
		area += current_point.x * next_point.y
		area -= next_point.x * current_point.y
	return area * 0.5

static func _get_primary_grip_preset_rows(preset_id: StringName) -> Array[String]:
	for preset_def: Dictionary in PrimaryGripSliceProfileLibraryScript.PRESET_DEFS:
		if StringName(preset_def.get("preset_id", StringName())) != preset_id:
			continue
		var rows: Array[String] = []
		for row_variant: Variant in preset_def.get("rows", []):
			rows.append(String(row_variant))
		return rows
	return []

static func _is_point_inside_or_on_polygon(
	point: Vector2,
	polygon: PackedVector2Array,
	tolerance_meters: float = 0.00001
) -> bool:
	if polygon.size() < 3:
		return false
	if Geometry2D.is_point_in_polygon(point, polygon):
		return true
	var tolerance_squared := tolerance_meters * tolerance_meters
	for point_index in range(polygon.size()):
		var segment_a: Vector2 = polygon[point_index]
		var segment_b: Vector2 = polygon[(point_index + 1) % polygon.size()]
		if _closest_point_on_segment(point, segment_a, segment_b).distance_squared_to(point) <= tolerance_squared:
			return true
	return false

static func _closest_point_on_segment(point: Vector2, segment_a: Vector2, segment_b: Vector2) -> Vector2:
	var segment := segment_b - segment_a
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0000000001:
		return segment_a
	var t := clampf((point - segment_a).dot(segment) / segment_length_squared, 0.0, 1.0)
	return segment_a + segment * t

static func _build_mask_boundary_polygon(rows: Array, cell_size_meters: float) -> PackedVector2Array:
	var occupied: Dictionary = {}
	var row_count := rows.size()
	var max_width := 0
	for row_variant: Variant in rows:
		max_width = maxi(max_width, String(row_variant).length())
	if row_count <= 0 or max_width <= 0:
		return PackedVector2Array()
	for row_index in range(row_count):
		var row_text := String(rows[row_index])
		for column_index in range(row_text.length()):
			var marker := row_text.substr(column_index, 1)
			if marker != "1":
				continue
			occupied[Vector2i(column_index, row_index)] = true
	if occupied.is_empty():
		return PackedVector2Array()
	var edges: Dictionary = {}
	for cell_coord: Vector2i in occupied.keys():
		var x := cell_coord.x
		var y := cell_coord.y
		if not occupied.has(Vector2i(x, y + 1)):
			edges[Vector2i(x, y + 1)] = Vector2i(x + 1, y + 1)
		if not occupied.has(Vector2i(x + 1, y)):
			edges[Vector2i(x + 1, y + 1)] = Vector2i(x + 1, y)
		if not occupied.has(Vector2i(x, y - 1)):
			edges[Vector2i(x + 1, y)] = Vector2i(x, y)
		if not occupied.has(Vector2i(x - 1, y)):
			edges[Vector2i(x, y)] = Vector2i(x, y + 1)
	if edges.is_empty():
		return PackedVector2Array()
	var start: Vector2i = _resolve_boundary_start(edges.keys())
	var current := start
	var polygon := PackedVector2Array([_grid_corner_to_profile_point(start, max_width, row_count, cell_size_meters)])
	var guard := edges.size() + 4
	while guard > 0:
		guard -= 1
		if not edges.has(current):
			break
		var next: Vector2i = edges[current]
		current = next
		if current == start:
			break
		polygon.append(_grid_corner_to_profile_point(current, max_width, row_count, cell_size_meters))
	return polygon

static func _resolve_boundary_start(points: Array) -> Vector2i:
	var best: Vector2i = points[0]
	for point_variant: Variant in points:
		var point: Vector2i = point_variant
		if point.y < best.y or (point.y == best.y and point.x < best.x):
			best = point
	return best

static func _grid_corner_to_profile_point(
	corner: Vector2i,
	width_cells: int,
	height_cells: int,
	cell_size_meters: float
) -> Vector2:
	return Vector2(
		(float(corner.x) - float(width_cells) * 0.5) * cell_size_meters,
		(float(height_cells) * 0.5 - float(corner.y)) * cell_size_meters
	)
