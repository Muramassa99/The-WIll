extends RefCounted
class_name BowConnectedRegionResolver

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")

var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE
var subsegment_resolver: SegmentResolver = SegmentResolver.new(DEFAULT_FORGE_RULES_RESOURCE)

func _init(rules: ForgeRulesDef = null) -> void:
	forge_rules = rules if rules != null else DEFAULT_FORGE_RULES_RESOURCE
	subsegment_resolver = SegmentResolver.new(forge_rules)

func resolve_connected_bow_regions(segments: Array[SegmentAtom], material_lookup: Dictionary) -> Dictionary:
	var all_cells: Array[CellAtom] = _collect_segment_cells(segments)
	if all_cells.is_empty():
		return {"riser": null, "upper": null, "lower": null, "string": null}

	var primary_axis: Vector3i = _resolve_primary_axis_from_cells(all_cells)
	var minor_axes: Array[Vector3i] = _resolve_minor_axes(primary_axis)
	var height_axis: Vector3i = _resolve_height_axis_from_cells(all_cells, minor_axes)
	var depth_axis: Vector3i = minor_axes[0] if minor_axes[1] == height_axis else minor_axes[1]
	var max_height_value: int = _get_extreme_axis_value(all_cells, height_axis, true)
	var string_cells: Array[CellAtom] = []
	var body_cells: Array[CellAtom] = []

	for cell: CellAtom in all_cells:
		if _get_axis_component(cell.grid_position, height_axis) == max_height_value:
			string_cells.append(cell)
		else:
			body_cells.append(cell)

	var riser_slice_range: Vector2i = _resolve_riser_slice_range(body_cells, primary_axis, depth_axis)
	var riser_cells: Array[CellAtom] = []
	var upper_limb_cells: Array[CellAtom] = []
	var lower_limb_cells: Array[CellAtom] = []
	for cell: CellAtom in body_cells:
		var slice_index: int = _get_axis_component(cell.grid_position, primary_axis)
		if slice_index >= riser_slice_range.x and slice_index <= riser_slice_range.y:
			riser_cells.append(cell)
		elif slice_index < riser_slice_range.x:
			upper_limb_cells.append(cell)
		else:
			lower_limb_cells.append(cell)

	var riser_segment: SegmentAtom = _build_synthetic_segment(riser_cells, material_lookup)
	var upper_segment: SegmentAtom = _build_synthetic_segment(upper_limb_cells, material_lookup)
	var lower_segment: SegmentAtom = _build_synthetic_segment(lower_limb_cells, material_lookup)
	var string_segment: SegmentAtom = _build_synthetic_segment(string_cells, material_lookup)
	if riser_segment != null:
		riser_segment.projectile_pass_candidate = true
	return {
		"riser": riser_segment,
		"upper": upper_segment,
		"lower": lower_segment,
		"string": string_segment,
	}

func _collect_segment_cells(segments: Array[SegmentAtom]) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	for segment: SegmentAtom in segments:
		if segment == null:
			continue
		for cell: CellAtom in segment.member_cells:
			if cell != null:
				cells.append(cell)
	return cells

func _resolve_primary_axis_from_cells(cells: Array[CellAtom]) -> Vector3i:
	var bounds: Dictionary = _build_cell_bounds(cells)
	var span_x: int = _get_axis_span_from_bounds(bounds, Vector3i.RIGHT)
	var span_y: int = _get_axis_span_from_bounds(bounds, Vector3i.UP)
	var span_z: int = _get_axis_span_from_bounds(bounds, Vector3i.BACK)
	if span_y > span_x and span_y >= span_z:
		return Vector3i.UP
	if span_z > span_x and span_z > span_y:
		return Vector3i.BACK
	return Vector3i.RIGHT

func _resolve_height_axis_from_cells(cells: Array[CellAtom], minor_axes: Array[Vector3i]) -> Vector3i:
	var bounds: Dictionary = _build_cell_bounds(cells)
	var first_span: int = _get_axis_span_from_bounds(bounds, minor_axes[0])
	var second_span: int = _get_axis_span_from_bounds(bounds, minor_axes[1])
	return minor_axes[0] if first_span >= second_span else minor_axes[1]

func _resolve_minor_axes(primary_axis: Vector3i) -> Array[Vector3i]:
	if primary_axis == Vector3i.UP:
		return [Vector3i.RIGHT, Vector3i.BACK]
	if primary_axis == Vector3i.BACK:
		return [Vector3i.RIGHT, Vector3i.UP]
	return [Vector3i.UP, Vector3i.BACK]

func _resolve_riser_slice_range(body_cells: Array[CellAtom], primary_axis: Vector3i, depth_axis: Vector3i) -> Vector2i:
	if body_cells.is_empty():
		return Vector2i.ZERO
	var slices: Dictionary = {}
	var min_slice: int = 2147483647
	var max_slice: int = -2147483648
	for cell: CellAtom in body_cells:
		var slice_index: int = _get_axis_component(cell.grid_position, primary_axis)
		min_slice = mini(min_slice, slice_index)
		max_slice = maxi(max_slice, slice_index)
		if not slices.has(slice_index):
			slices[slice_index] = []
		var slice_cells: Array = slices[slice_index]
		slice_cells.append(cell)
		slices[slice_index] = slice_cells

	var center_slice: float = float(min_slice + max_slice) * 0.5
	var best_slice: int = min_slice
	var best_score: float = -INF
	for slice_key in slices.keys():
		var slice_index: int = int(slice_key)
		var slice_cells: Array = slices[slice_key]
		var compactness: float = _calculate_slice_compactness(slice_cells, depth_axis)
		var center_bias: float = 1.0 / (1.0 + absf(float(slice_index) - center_slice))
		var score: float = compactness + center_bias
		if score > best_score:
			best_score = score
			best_slice = slice_index

	var lower_slice: int = best_slice
	var upper_slice: int = best_slice
	if slices.has(best_slice - 1) and _calculate_slice_compactness(slices[best_slice - 1], depth_axis) >= forge_rules.bow_riser_adjacent_slice_compactness_threshold:
		lower_slice = best_slice - 1
	if slices.has(best_slice + 1) and _calculate_slice_compactness(slices[best_slice + 1], depth_axis) >= forge_rules.bow_riser_adjacent_slice_compactness_threshold:
		upper_slice = best_slice + 1
	return Vector2i(lower_slice, upper_slice)

func _calculate_slice_compactness(slice_cells: Array, depth_axis: Vector3i) -> float:
	if slice_cells.is_empty():
		return 0.0
	var bounds: Dictionary = _build_cell_bounds(slice_cells)
	var depth_span: int = _get_axis_span_from_bounds(bounds, depth_axis)
	return float(slice_cells.size()) + float(depth_span)

func _build_cell_bounds(cells: Array) -> Dictionary:
	var first_position: Vector3i = cells[0].grid_position
	var min_position: Vector3i = first_position
	var max_position: Vector3i = first_position
	for cell: CellAtom in cells:
		if cell == null:
			continue
		var position: Vector3i = cell.grid_position
		min_position.x = mini(min_position.x, position.x)
		min_position.y = mini(min_position.y, position.y)
		min_position.z = mini(min_position.z, position.z)
		max_position.x = maxi(max_position.x, position.x)
		max_position.y = maxi(max_position.y, position.y)
		max_position.z = maxi(max_position.z, position.z)
	return {
		"min": min_position,
		"max": max_position,
	}

func _get_axis_span_from_bounds(bounds: Dictionary, axis: Vector3i) -> int:
	var min_position: Vector3i = bounds.get("min", Vector3i.ZERO)
	var max_position: Vector3i = bounds.get("max", Vector3i.ZERO)
	return (_get_axis_component(max_position, axis) - _get_axis_component(min_position, axis)) + 1

func _get_extreme_axis_value(cells: Array[CellAtom], axis: Vector3i, want_maximum: bool) -> int:
	if cells.is_empty():
		return 0
	var extreme: int = _get_axis_component(cells[0].grid_position, axis)
	for cell: CellAtom in cells:
		var current: int = _get_axis_component(cell.grid_position, axis)
		extreme = maxi(extreme, current) if want_maximum else mini(extreme, current)
	return extreme

func _get_axis_component(value: Vector3i, axis: Vector3i) -> int:
	if axis == Vector3i.UP:
		return value.y
	if axis == Vector3i.BACK:
		return value.z
	return value.x

func _build_synthetic_segment(member_cells: Array[CellAtom], material_lookup: Dictionary) -> SegmentAtom:
	if member_cells.is_empty():
		return null
	var resolved_segments: Array[SegmentAtom] = subsegment_resolver.resolve_segments(member_cells, material_lookup)
	if resolved_segments.is_empty():
		return null
	var best_segment: SegmentAtom = resolved_segments[0]
	for segment: SegmentAtom in resolved_segments:
		if segment != null and segment.member_cells.size() > best_segment.member_cells.size():
			best_segment = segment
	return best_segment
