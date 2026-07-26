extends RefCounted
class_name ForgeV2MaterialVolumeResolver

const ForgeV2MaterialBodyScript = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const ForgeV2ProfileShapeLibraryScript = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const ForgeV2VolumeStrokeScript = preload("res://runtime/forge_v2/forge_v2_volume_stroke.gd")

const REFERENCE_CELL_WORLD_SIZE_METERS := ForgeV2MaterialBodyScript.REFERENCE_CELL_WORLD_SIZE_METERS
const CELL_EQUIVALENTS_PER_MATERIAL_UNIT := ForgeV2MaterialBodyScript.CELL_EQUIVALENTS_PER_MATERIAL_UNIT
const MATERIAL_UNIT_SCALE := ForgeV2MaterialBodyScript.MATERIAL_UNIT_SCALE
const SAMPLE_CELL_SIZE_MIN_METERS := REFERENCE_CELL_WORLD_SIZE_METERS
const SAMPLE_CELL_SIZE_MAX_METERS := REFERENCE_CELL_WORLD_SIZE_METERS * 2.0
const SAMPLE_RADIUS_RATIO := 0.5
const MAX_BODY_SAMPLE_SEGMENTS := 96
const SPLINE_AUTO_CURVE_HANDLE_MIN_LENGTH_METERS := 0.025
const SPLINE_AUTO_CURVE_ENDPOINT_STRENGTH := 0.3333333
const SPLINE_AUTO_CURVE_MIDDLE_STRENGTH := 0.1666667

func build_add_material_delta(add_bodies: Array, layer_id: StringName) -> Dictionary:
	var resolved_summary: Dictionary = build_usage_summary(add_bodies)
	var resolved_groups: Dictionary = resolved_summary.get("materials", {}) as Dictionary
	var ledger_delta: Dictionary = {}
	var total_volume_cell_equivalents := 0.0
	var total_material_centi_units := 0
	for material_variant_id: StringName in resolved_groups.keys():
		var group_entry: Dictionary = resolved_groups.get(material_variant_id, {}) as Dictionary
		var volume_cell_equivalents: float = float(group_entry.get("rough_volume_cell_equivalents", 0.0))
		var material_centi_units: int = _material_centi_units_from_volume_cell_equivalents(volume_cell_equivalents)
		var layer_ids: Array[StringName] = []
		if layer_id != StringName():
			layer_ids.append(layer_id)
		ledger_delta[material_variant_id] = {
			"material_variant_id": material_variant_id,
			"rough_volume_cell_equivalents": volume_cell_equivalents,
			"rough_material_centi_units": material_centi_units,
			"rough_material_units": float(material_centi_units) / float(MATERIAL_UNIT_SCALE),
			"layer_ids": layer_ids,
		}
		total_volume_cell_equivalents += volume_cell_equivalents
		total_material_centi_units += material_centi_units
	return {
		"ledger_delta": ledger_delta,
		"rough_volume_cell_equivalents_delta": total_volume_cell_equivalents,
		"rough_material_centi_units_delta": total_material_centi_units,
	}

func build_usage_summary(active_bodies: Array) -> Dictionary:
	if active_bodies.is_empty():
		return _build_usage_summary_from_cell_materials({}, 0.0)
	var sample_cell_size_meters: float = _resolve_group_sample_cell_size(active_bodies)
	var sample_volume_cell_equivalents: float = pow(sample_cell_size_meters / REFERENCE_CELL_WORLD_SIZE_METERS, 3.0)
	var cell_materials: Dictionary = {}
	for body: Variant in active_bodies:
		if body == null:
			continue
		_normalize_body_entry(body)
		if not _is_body_entry_active(body):
			continue
		var occupied_cells: Dictionary = _collect_body_occupied_cells(body, sample_cell_size_meters)
		if occupied_cells.is_empty():
			continue
		var operation_mode: StringName = _read_body_string_name(body, "operation_mode")
		if operation_mode == ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL:
			for cell_key: String in occupied_cells.keys():
				cell_materials.erase(cell_key)
			continue
		var material_variant_id: StringName = _read_body_string_name(body, "material_variant_id")
		if material_variant_id == StringName():
			continue
		var placement_policy: StringName = _read_body_string_name(
			body,
			"placement_policy",
			ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
		)
		for cell_key: String in occupied_cells.keys():
			if placement_policy == ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY and cell_materials.has(cell_key):
				continue
			cell_materials[cell_key] = material_variant_id
	return _build_usage_summary_from_cell_materials(cell_materials, sample_volume_cell_equivalents)

func _build_usage_summary_from_cell_materials(
	cell_materials: Dictionary,
	sample_volume_cell_equivalents: float
) -> Dictionary:
	var material_entries: Dictionary = {}
	for cell_key: String in cell_materials.keys():
		var material_variant_id: StringName = StringName(cell_materials.get(cell_key, StringName()))
		if material_variant_id == StringName():
			continue
		var material_entry: Dictionary = material_entries.get(material_variant_id, {
			"material_variant_id": material_variant_id,
			"rough_volume_cell_equivalents": 0.0,
			"rough_material_centi_units": 0,
			"rough_material_units": 0.0,
			"ratio": 0.0,
		}) as Dictionary
		material_entry["rough_volume_cell_equivalents"] = (
			float(material_entry.get("rough_volume_cell_equivalents", 0.0))
			+ sample_volume_cell_equivalents
		)
		material_entries[material_variant_id] = material_entry
	var total_centi_units := 0
	var total_volume_cell_equivalents := 0.0
	for material_variant_id: StringName in material_entries.keys():
		var material_entry: Dictionary = material_entries[material_variant_id]
		var volume_cell_equivalents: float = float(material_entry.get("rough_volume_cell_equivalents", 0.0))
		var material_centi_units: int = _material_centi_units_from_volume_cell_equivalents(volume_cell_equivalents)
		material_entry["rough_material_centi_units"] = material_centi_units
		material_entry["rough_material_units"] = float(material_centi_units) / float(MATERIAL_UNIT_SCALE)
		material_entries[material_variant_id] = material_entry
		total_centi_units += material_centi_units
		total_volume_cell_equivalents += volume_cell_equivalents
	for material_variant_id: StringName in material_entries.keys():
		var entry: Dictionary = material_entries[material_variant_id]
		entry["ratio"] = float(entry.get("rough_material_centi_units", 0)) / float(total_centi_units) if total_centi_units > 0 else 0.0
		material_entries[material_variant_id] = entry
	return {
		"total_rough_volume_cell_equivalents": total_volume_cell_equivalents,
		"total_rough_material_centi_units": total_centi_units,
		"total_rough_material_units": float(total_centi_units) / float(MATERIAL_UNIT_SCALE),
		"materials": material_entries,
	}

func resolve_add_material_groups(add_bodies: Array) -> Dictionary:
	var add_bodies_by_material: Dictionary = {}
	for body: Variant in add_bodies:
		if body == null:
			continue
		_normalize_body_entry(body)
		var material_variant_id: StringName = _read_body_string_name(body, "material_variant_id")
		var grouped_bodies: Array = add_bodies_by_material.get(material_variant_id, []) as Array
		grouped_bodies.append(body)
		add_bodies_by_material[material_variant_id] = grouped_bodies
	return resolve_grouped_add_material_bodies(add_bodies_by_material)

func resolve_grouped_add_material_bodies(add_bodies_by_material: Dictionary) -> Dictionary:
	var resolved_groups: Dictionary = {}
	for material_variant_id: StringName in add_bodies_by_material.keys():
		var add_bodies: Array = add_bodies_by_material.get(material_variant_id, []) as Array
		var volume_cell_equivalents: float = estimate_same_material_union_volume_cell_equivalents(add_bodies)
		resolved_groups[material_variant_id] = {
			"material_variant_id": material_variant_id,
			"rough_volume_cell_equivalents": volume_cell_equivalents,
		}
	return resolved_groups

func estimate_same_material_union_volume_cell_equivalents(add_bodies: Array) -> float:
	if add_bodies.is_empty():
		return 0.0
	var sample_cell_size_meters: float = _resolve_group_sample_cell_size(add_bodies)
	var sample_volume_cell_equivalents: float = pow(sample_cell_size_meters / REFERENCE_CELL_WORLD_SIZE_METERS, 3.0)
	var occupied_cells: Dictionary = {}
	for body: Variant in add_bodies:
		if body == null:
			continue
		_normalize_body_entry(body)
		var amount_ratio: float = 1.0
		if _is_profile_body_shape(body):
			_mark_profile_path_cells(occupied_cells, body, amount_ratio, sample_cell_size_meters)
			continue
		var radius_meters: float = maxf(_read_body_float(body, "radius_meters", 0.001), 0.001)
		var body_points: PackedVector3Array = _resolve_body_sample_points(body, sample_cell_size_meters)
		if body_points.is_empty():
			continue
		if body_points.size() == 1:
			_mark_sphere_cells(occupied_cells, body_points[0], radius_meters, amount_ratio, sample_cell_size_meters)
			continue
		for point_index in range(body_points.size() - 1):
			_mark_capsule_segment_cells(
				occupied_cells,
				body_points[point_index],
				body_points[point_index + 1],
				radius_meters,
				amount_ratio,
				sample_cell_size_meters
			)
	var volume_cell_equivalents := 0.0
	for cell_key: String in occupied_cells.keys():
		volume_cell_equivalents += float(occupied_cells.get(cell_key, 0.0)) * sample_volume_cell_equivalents
	return volume_cell_equivalents

func _resolve_group_sample_cell_size(add_bodies: Array) -> float:
	var min_radius_meters := INF
	for body: Variant in add_bodies:
		if body == null:
			continue
		min_radius_meters = minf(min_radius_meters, maxf(_read_body_float(body, "radius_meters", 0.001), 0.001))
	if min_radius_meters == INF:
		min_radius_meters = REFERENCE_CELL_WORLD_SIZE_METERS
	return clampf(
		min_radius_meters * SAMPLE_RADIUS_RATIO,
		SAMPLE_CELL_SIZE_MIN_METERS,
		SAMPLE_CELL_SIZE_MAX_METERS
	)

func _collect_body_occupied_cells(body: Variant, sample_cell_size_meters: float) -> Dictionary:
	var occupied_cells: Dictionary = {}
	if _is_profile_body_shape(body):
		_mark_profile_path_cells(occupied_cells, body, 1.0, sample_cell_size_meters)
		return occupied_cells
	var radius_meters: float = maxf(_read_body_float(body, "radius_meters", 0.001), 0.001)
	var body_points: PackedVector3Array = _resolve_body_sample_points(body, sample_cell_size_meters)
	if body_points.is_empty():
		return occupied_cells
	if body_points.size() == 1:
		_mark_sphere_cells(occupied_cells, body_points[0], radius_meters, 1.0, sample_cell_size_meters)
		return occupied_cells
	for point_index in range(body_points.size() - 1):
		_mark_capsule_segment_cells(
			occupied_cells,
			body_points[point_index],
			body_points[point_index + 1],
			radius_meters,
			1.0,
			sample_cell_size_meters
		)
	return occupied_cells

func _resolve_body_sample_points(body: Variant, sample_cell_size_meters: float) -> PackedVector3Array:
	if body == null:
		return PackedVector3Array()
	var path_points: PackedVector3Array = _read_body_path_points(body)
	if path_points.size() < 2:
		return _deduplicate_points(path_points)
	var shape_kind: StringName = _read_body_string_name(body, "shape_kind")
	if (
		shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_CAPSULE_PATH
		or shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
	):
		var curve: Curve3D = _build_spline_curve(path_points, _resolve_body_bake_interval(path_points, sample_cell_size_meters))
		var baked_points: PackedVector3Array = curve.get_baked_points()
		if baked_points.size() >= 2:
			return _deduplicate_points(baked_points)
	return _deduplicate_points(path_points)

func _is_profile_body_shape(body: Variant) -> bool:
	var shape_kind: StringName = _read_body_string_name(body, "shape_kind")
	return (
		shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
		or shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
	)

func _mark_profile_path_cells(
	occupied_cells: Dictionary,
	body: Variant,
	amount_ratio: float,
	sample_cell_size_meters: float
) -> void:
	var body_points: PackedVector3Array = _resolve_body_sample_points(body, sample_cell_size_meters)
	if body_points.size() < 2:
		return
	var profile_polygon: PackedVector2Array = _resolve_body_profile_polygon(body)
	if profile_polygon.size() < 3:
		return
	for point_index in range(body_points.size() - 1):
		_mark_profile_segment_cells(
			occupied_cells,
			body_points[point_index],
			body_points[point_index + 1],
			profile_polygon,
			amount_ratio,
			sample_cell_size_meters
		)

func _mark_profile_segment_cells(
	occupied_cells: Dictionary,
	from_point: Vector3,
	to_point: Vector3,
	profile_polygon: PackedVector2Array,
	amount_ratio: float,
	sample_cell_size_meters: float
) -> void:
	var segment: Vector3 = to_point - from_point
	var segment_length: float = segment.length()
	if segment_length <= 0.000001:
		return
	var tangent: Vector3 = segment / segment_length
	var normal: Vector3 = _resolve_perpendicular_normal(tangent)
	var binormal: Vector3 = tangent.cross(normal).normalized()
	var profile_radius: float = maxf(
		ForgeV2ProfileShapeLibraryScript.calculate_polygon_max_radius_meters(profile_polygon),
		0.001
	)
	var min_point: Vector3 = Vector3(
		minf(from_point.x, to_point.x) - profile_radius,
		minf(from_point.y, to_point.y) - profile_radius,
		minf(from_point.z, to_point.z) - profile_radius
	)
	var max_point: Vector3 = Vector3(
		maxf(from_point.x, to_point.x) + profile_radius,
		maxf(from_point.y, to_point.y) + profile_radius,
		maxf(from_point.z, to_point.z) + profile_radius
	)
	var min_index: Vector3i = _sample_index_floor(min_point, sample_cell_size_meters)
	var max_index: Vector3i = _sample_index_floor(max_point, sample_cell_size_meters)
	for x_index in range(min_index.x, max_index.x + 1):
		for y_index in range(min_index.y, max_index.y + 1):
			for z_index in range(min_index.z, max_index.z + 1):
				var sample_position := _sample_center_from_index(x_index, y_index, z_index, sample_cell_size_meters)
				var relative_position: Vector3 = sample_position - from_point
				var distance_along_path: float = relative_position.dot(tangent)
				if distance_along_path < 0.0 or distance_along_path > segment_length:
					continue
				var profile_center: Vector3 = from_point + tangent * distance_along_path
				var lateral_position: Vector3 = sample_position - profile_center
				var profile_point := Vector2(lateral_position.dot(normal), lateral_position.dot(binormal))
				if not _profile_polygon_contains_point(profile_polygon, profile_point):
					continue
				_mark_cell(occupied_cells, x_index, y_index, z_index, amount_ratio)

func _resolve_body_profile_polygon(body: Variant) -> PackedVector2Array:
	var profile_polygon: PackedVector2Array = _read_body_vector2_array(body, "profile_polygon_2d_meters")
	if profile_polygon.size() >= 3:
		return profile_polygon
	var radius_meters: float = maxf(_read_body_float(body, "radius_meters", 0.001), 0.001)
	var profile_id: StringName = _read_body_string_name(body, "profile_id")
	if profile_id != StringName():
		return ForgeV2ProfileShapeLibraryScript.resolve_profile_polygon(profile_id, radius_meters)
	return ForgeV2ProfileShapeLibraryScript.build_circle_polygon(radius_meters)

func _resolve_perpendicular_normal(tangent: Vector3) -> Vector3:
	var reference_axis := Vector3.UP
	if absf(tangent.normalized().dot(reference_axis)) > 0.95:
		reference_axis = Vector3.RIGHT
	var normal := reference_axis.cross(tangent).normalized()
	if normal.length_squared() <= 0.000001:
		return Vector3.FORWARD
	return normal

func _profile_polygon_contains_point(polygon: PackedVector2Array, point: Vector2) -> bool:
	var inside := false
	var previous_index := polygon.size() - 1
	for point_index in range(polygon.size()):
		var current_point: Vector2 = polygon[point_index]
		var previous_point: Vector2 = polygon[previous_index]
		if _distance_squared_to_2d_segment(point, current_point, previous_point) <= 0.00000001:
			return true
		var crosses_y := (current_point.y > point.y) != (previous_point.y > point.y)
		if crosses_y:
			var denominator := previous_point.y - current_point.y
			if absf(denominator) > 0.000001:
				var intersect_x := (
					(previous_point.x - current_point.x)
					* (point.y - current_point.y)
					/ denominator
					+ current_point.x
				)
				if point.x < intersect_x:
					inside = not inside
		previous_index = point_index
	return inside

func _distance_squared_to_2d_segment(point: Vector2, from_point: Vector2, to_point: Vector2) -> float:
	var segment: Vector2 = to_point - from_point
	var segment_length_squared: float = segment.length_squared()
	if segment_length_squared <= 0.000001:
		return point.distance_squared_to(from_point)
	var segment_ratio: float = clampf((point - from_point).dot(segment) / segment_length_squared, 0.0, 1.0)
	return point.distance_squared_to(from_point + segment * segment_ratio)

func _resolve_body_bake_interval(path_points: PackedVector3Array, sample_cell_size_meters: float) -> float:
	var path_length: float = _calculate_polyline_length(path_points)
	if path_length <= 0.0:
		return maxf(sample_cell_size_meters, 0.001)
	return maxf(sample_cell_size_meters, path_length / float(MAX_BODY_SAMPLE_SEGMENTS))

func _calculate_polyline_length(path_points: PackedVector3Array) -> float:
	var path_length := 0.0
	for point_index in range(path_points.size() - 1):
		path_length += path_points[point_index].distance_to(path_points[point_index + 1])
	return path_length

func _mark_capsule_segment_cells(
	occupied_cells: Dictionary,
	from_point: Vector3,
	to_point: Vector3,
	radius_meters: float,
	amount_ratio: float,
	sample_cell_size_meters: float
) -> void:
	if from_point.distance_squared_to(to_point) <= 0.000001:
		_mark_sphere_cells(occupied_cells, from_point, radius_meters, amount_ratio, sample_cell_size_meters)
		return
	var min_point: Vector3 = Vector3(
		minf(from_point.x, to_point.x) - radius_meters,
		minf(from_point.y, to_point.y) - radius_meters,
		minf(from_point.z, to_point.z) - radius_meters
	)
	var max_point: Vector3 = Vector3(
		maxf(from_point.x, to_point.x) + radius_meters,
		maxf(from_point.y, to_point.y) + radius_meters,
		maxf(from_point.z, to_point.z) + radius_meters
	)
	var min_index: Vector3i = _sample_index_floor(min_point, sample_cell_size_meters)
	var max_index: Vector3i = _sample_index_floor(max_point, sample_cell_size_meters)
	var radius_squared: float = radius_meters * radius_meters
	for x_index in range(min_index.x, max_index.x + 1):
		for y_index in range(min_index.y, max_index.y + 1):
			for z_index in range(min_index.z, max_index.z + 1):
				var sample_position := _sample_center_from_index(x_index, y_index, z_index, sample_cell_size_meters)
				if _distance_squared_to_segment(sample_position, from_point, to_point) > radius_squared:
					continue
				_mark_cell(occupied_cells, x_index, y_index, z_index, amount_ratio)

func _mark_sphere_cells(
	occupied_cells: Dictionary,
	center_point: Vector3,
	radius_meters: float,
	amount_ratio: float,
	sample_cell_size_meters: float
) -> void:
	var min_index: Vector3i = _sample_index_floor(center_point - Vector3.ONE * radius_meters, sample_cell_size_meters)
	var max_index: Vector3i = _sample_index_floor(center_point + Vector3.ONE * radius_meters, sample_cell_size_meters)
	var radius_squared: float = radius_meters * radius_meters
	for x_index in range(min_index.x, max_index.x + 1):
		for y_index in range(min_index.y, max_index.y + 1):
			for z_index in range(min_index.z, max_index.z + 1):
				var sample_position := _sample_center_from_index(x_index, y_index, z_index, sample_cell_size_meters)
				if sample_position.distance_squared_to(center_point) > radius_squared:
					continue
				_mark_cell(occupied_cells, x_index, y_index, z_index, amount_ratio)

func _mark_cell(
	occupied_cells: Dictionary,
	x_index: int,
	y_index: int,
	z_index: int,
	amount_ratio: float
) -> void:
	var key := "%d:%d:%d" % [x_index, y_index, z_index]
	occupied_cells[key] = maxf(float(occupied_cells.get(key, 0.0)), amount_ratio)

func _sample_index_floor(point: Vector3, sample_cell_size_meters: float) -> Vector3i:
	return Vector3i(
		int(floor(point.x / sample_cell_size_meters)),
		int(floor(point.y / sample_cell_size_meters)),
		int(floor(point.z / sample_cell_size_meters))
	)

func _sample_center_from_index(x_index: int, y_index: int, z_index: int, sample_cell_size_meters: float) -> Vector3:
	return Vector3(
		(float(x_index) + 0.5) * sample_cell_size_meters,
		(float(y_index) + 0.5) * sample_cell_size_meters,
		(float(z_index) + 0.5) * sample_cell_size_meters
	)

func _distance_squared_to_segment(point: Vector3, from_point: Vector3, to_point: Vector3) -> float:
	var segment: Vector3 = to_point - from_point
	var segment_length_squared: float = segment.length_squared()
	if segment_length_squared <= 0.000001:
		return point.distance_squared_to(from_point)
	var segment_ratio: float = clampf((point - from_point).dot(segment) / segment_length_squared, 0.0, 1.0)
	return point.distance_squared_to(from_point + segment * segment_ratio)

func _build_spline_curve(spline_points: PackedVector3Array, bake_interval: float) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = maxf(bake_interval, 0.001)
	var control_points := _deduplicate_points(spline_points)
	for point_index in range(control_points.size()):
		curve.add_point(
			control_points[point_index],
			_resolve_spline_auto_curve_handle(control_points, point_index, true),
			_resolve_spline_auto_curve_handle(control_points, point_index, false)
		)
	return curve

func _resolve_spline_auto_curve_handle(
	points: PackedVector3Array,
	point_index: int,
	use_in_handle: bool
) -> Vector3:
	if point_index < 0 or point_index >= points.size():
		return Vector3.ZERO
	var current_position: Vector3 = points[point_index]
	var previous_position: Variant = null
	var next_position: Variant = null
	if point_index > 0:
		previous_position = points[point_index - 1]
	if point_index < points.size() - 1:
		next_position = points[point_index + 1]
	var auto_handle := Vector3.ZERO
	if previous_position is Vector3 and next_position is Vector3:
		var smooth_tangent: Vector3 = ((next_position as Vector3) - (previous_position as Vector3)) * SPLINE_AUTO_CURVE_MIDDLE_STRENGTH
		auto_handle = -smooth_tangent if use_in_handle else smooth_tangent
	elif use_in_handle and previous_position is Vector3:
		auto_handle = ((previous_position as Vector3) - current_position) * SPLINE_AUTO_CURVE_ENDPOINT_STRENGTH
	elif not use_in_handle and next_position is Vector3:
		auto_handle = ((next_position as Vector3) - current_position) * SPLINE_AUTO_CURVE_ENDPOINT_STRENGTH
	if auto_handle.length() < SPLINE_AUTO_CURVE_HANDLE_MIN_LENGTH_METERS:
		return Vector3.ZERO
	return auto_handle

func _deduplicate_points(points: PackedVector3Array) -> PackedVector3Array:
	var deduplicated := PackedVector3Array()
	for point: Vector3 in points:
		if not deduplicated.is_empty() and deduplicated[deduplicated.size() - 1].distance_squared_to(point) <= 0.000001:
			continue
		deduplicated.append(point)
	return deduplicated

func _normalize_body_entry(body: Variant) -> void:
	if body is Resource and body.has_method("normalize"):
		body.call("normalize")

func _is_body_entry_active(body: Variant) -> bool:
	var layer_active_value: Variant = _read_body_variant(body, "layer_active", true)
	return not (layer_active_value is bool) or bool(layer_active_value)

func _read_body_variant(body: Variant, field_name: String, default_value: Variant = null) -> Variant:
	if body is Resource:
		var resource := body as Resource
		var value: Variant = resource.get(field_name)
		return default_value if value == null else value
	if body is Dictionary:
		return (body as Dictionary).get(field_name, default_value)
	return default_value

func _read_body_string_name(body: Variant, field_name: String, default_value: StringName = StringName()) -> StringName:
	return StringName(_read_body_variant(body, field_name, default_value))

func _read_body_float(body: Variant, field_name: String, default_value: float = 0.0) -> float:
	return float(_read_body_variant(body, field_name, default_value))

func _read_body_path_points(body: Variant) -> PackedVector3Array:
	var value: Variant = _read_body_variant(body, "path_points", PackedVector3Array())
	if value is PackedVector3Array:
		return value as PackedVector3Array
	return PackedVector3Array()

func _read_body_vector2_array(body: Variant, field_name: String) -> PackedVector2Array:
	var value: Variant = _read_body_variant(body, field_name, PackedVector2Array())
	if value is PackedVector2Array:
		return value as PackedVector2Array
	return PackedVector2Array()

func _material_centi_units_from_volume_cell_equivalents(volume_cell_equivalents: float) -> int:
	var raw_material_units: float = maxf(volume_cell_equivalents, 0.0) / CELL_EQUIVALENTS_PER_MATERIAL_UNIT
	var material_centi_units: int = int(round(raw_material_units * float(MATERIAL_UNIT_SCALE)))
	if volume_cell_equivalents > 0.0:
		material_centi_units = maxi(material_centi_units, 1)
	return material_centi_units
