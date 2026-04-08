extends RefCounted
class_name BowResolver

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")

var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE
var subsegment_resolver: SegmentResolver = SegmentResolver.new(DEFAULT_FORGE_RULES_RESOURCE)
var material_runtime_resolver = MaterialRuntimeResolverScript.new()

func _init(rules: ForgeRulesDef = null) -> void:
	forge_rules = rules if rules != null else DEFAULT_FORGE_RULES_RESOURCE
	subsegment_resolver = SegmentResolver.new(forge_rules)

func validate_bow_structure(
		segments: Array[SegmentAtom],
		material_lookup: Dictionary,
		forge_intent: StringName,
		equipment_context: StringName
	) -> Dictionary:
	_clear_segment_role_hints(segments)
	if not _is_ranged_context(forge_intent, equipment_context):
		return {
			"bow_valid": false,
			"upper_limb_valid": false,
			"lower_limb_valid": false,
			"upper_limb_flex_score": 0.0,
			"lower_limb_flex_score": 0.0,
			"string_tension_score": 0.0,
			"bow_asymmetry_score": 0.0,
			"validation_error": &"not_ranged_context",
		}

	var riser_segment: SegmentAtom = _find_riser_segment(segments)
	var bow_string_segment: SegmentAtom = _find_bow_string_segment(segments)
	var limb_pair: Dictionary = _resolve_limb_pair(segments, material_lookup, riser_segment)
	var upper_limb_segment: SegmentAtom = limb_pair.get("upper")
	var lower_limb_segment: SegmentAtom = limb_pair.get("lower")
	if riser_segment == null or bow_string_segment == null or upper_limb_segment == null or lower_limb_segment == null:
		var connected_regions: Dictionary = _resolve_connected_bow_regions(segments, material_lookup)
		if riser_segment == null:
			riser_segment = connected_regions.get("riser")
		if bow_string_segment == null:
			bow_string_segment = connected_regions.get("string")
		if upper_limb_segment == null:
			upper_limb_segment = connected_regions.get("upper")
		if lower_limb_segment == null:
			lower_limb_segment = connected_regions.get("lower")
		if upper_limb_segment != null:
			upper_limb_segment.is_upper_limb_candidate = true
		if lower_limb_segment != null:
			lower_limb_segment.is_lower_limb_candidate = true
		if riser_segment != null:
			riser_segment.is_riser_candidate = true
		if bow_string_segment != null:
			bow_string_segment.is_bow_string_candidate = true
	var reference_points: Dictionary = resolve_bow_reference_points(segments, riser_segment, upper_limb_segment, lower_limb_segment)
	var axes: Dictionary = resolve_bow_axes(reference_points.get("bow_reference_center", Vector3.ZERO))

	var upper_limb_valid: bool = _is_valid_limb_segment(upper_limb_segment, material_lookup)
	var lower_limb_valid: bool = _is_valid_limb_segment(lower_limb_segment, material_lookup)
	var bow_string_valid: bool = _is_valid_bow_string(bow_string_segment, material_lookup)
	var bow_valid: bool = riser_segment != null and upper_limb_valid and lower_limb_valid and bow_string_valid and not reference_points.get("projectile_pass_point", Vector3.ZERO).is_equal_approx(Vector3.ZERO)
	var upper_limb_flex_score: float = _calculate_limb_flex_score(upper_limb_segment, material_lookup) if upper_limb_valid else 0.0
	var lower_limb_flex_score: float = _calculate_limb_flex_score(lower_limb_segment, material_lookup) if lower_limb_valid else 0.0
	var string_tension_score: float = 1.0 if bow_string_valid else 0.0

	return {
		"bow_valid": bow_valid,
		"bow_reference_center": reference_points.get("bow_reference_center", Vector3.ZERO),
		"projectile_pass_point": reference_points.get("projectile_pass_point", Vector3.ZERO),
		"shoot_axis": axes.get("shoot_axis", Vector3.ZERO),
		"draw_axis": axes.get("draw_axis", Vector3.ZERO),
		"upper_string_anchor": reference_points.get("upper_string_anchor", Vector3.ZERO),
		"lower_string_anchor": reference_points.get("lower_string_anchor", Vector3.ZERO),
		"string_rest_path": [],
		"string_draw_path": [],
		"upper_limb_valid": upper_limb_valid,
		"lower_limb_valid": lower_limb_valid,
		"upper_limb_flex_score": upper_limb_flex_score,
		"lower_limb_flex_score": lower_limb_flex_score,
		"string_tension_score": string_tension_score,
		"bow_asymmetry_score": _calculate_bow_asymmetry_score(upper_limb_flex_score, lower_limb_flex_score),
		"validation_error": _resolve_validation_error(riser_segment, upper_limb_valid, lower_limb_valid, bow_string_valid, reference_points),
	}

func resolve_bow_reference_points(
		segments: Array[SegmentAtom],
		riser_segment: SegmentAtom = null,
		upper_limb_segment: SegmentAtom = null,
		lower_limb_segment: SegmentAtom = null
	) -> Dictionary:
	var reference_center: Vector3 = _get_segment_center(riser_segment)
	if reference_center.is_equal_approx(Vector3.ZERO):
		reference_center = _calculate_segments_center(segments)
	var projectile_pass_point: Vector3 = reference_center
	if riser_segment != null and riser_segment.projectile_pass_candidate:
		projectile_pass_point = reference_center
	var upper_anchor: Vector3 = _get_segment_center(upper_limb_segment)
	var lower_anchor: Vector3 = _get_segment_center(lower_limb_segment)
	if upper_anchor.is_equal_approx(Vector3.ZERO):
		upper_anchor = reference_center + Vector3.UP
	if lower_anchor.is_equal_approx(Vector3.ZERO):
		lower_anchor = reference_center + Vector3.DOWN
	return {
		"bow_reference_center": reference_center,
		"projectile_pass_point": projectile_pass_point,
		"upper_string_anchor": upper_anchor,
		"lower_string_anchor": lower_anchor,
	}

func resolve_bow_axes(_reference_center: Vector3) -> Dictionary:
	return {
		"shoot_axis": Vector3.RIGHT,
		"draw_axis": Vector3.BACK,
	}

func _is_ranged_context(forge_intent: StringName, equipment_context: StringName) -> bool:
	return forge_intent == &"intent_ranged" and equipment_context == &"ctx_weapon"

func _find_riser_segment(segments: Array[SegmentAtom]) -> SegmentAtom:
	var best_segment: SegmentAtom = null
	var best_distance: float = INF
	var reference_center: Vector3 = _calculate_segments_center(segments)
	for segment: SegmentAtom in segments:
		if segment == null or not segment.is_riser_candidate:
			continue
		var distance_to_center: float = _get_segment_center(segment).distance_squared_to(reference_center)
		if distance_to_center < best_distance:
			best_distance = distance_to_center
			best_segment = segment
	return best_segment

func _find_bow_string_segment(segments: Array[SegmentAtom]) -> SegmentAtom:
	for segment: SegmentAtom in segments:
		if segment != null and segment.is_bow_string_candidate:
			return segment
	return null

func _resolve_limb_pair(segments: Array[SegmentAtom], material_lookup: Dictionary, riser_segment: SegmentAtom) -> Dictionary:
	var limb_candidates: Array[SegmentAtom] = []
	for segment: SegmentAtom in segments:
		if _is_limb_candidate(segment, material_lookup):
			limb_candidates.append(segment)

	if limb_candidates.size() < 2:
		return {"upper": null, "lower": null}

	var reference_center: Vector3 = _get_segment_center(riser_segment)
	if reference_center.is_equal_approx(Vector3.ZERO):
		reference_center = _calculate_segments_center(limb_candidates)
	var split_axis: Vector3 = _resolve_limb_split_axis(limb_candidates, reference_center)
	var negative_segment: SegmentAtom = null
	var positive_segment: SegmentAtom = null
	var negative_distance: float = -INF
	var positive_distance: float = -INF

	for segment: SegmentAtom in limb_candidates:
		var offset: Vector3 = _get_segment_center(segment) - reference_center
		var projection: float = offset.dot(split_axis)
		if projection < 0.0 and absf(projection) > negative_distance:
			negative_distance = absf(projection)
			negative_segment = segment
		elif projection > 0.0 and projection > positive_distance:
			positive_distance = projection
			positive_segment = segment

	if negative_segment != null:
		negative_segment.is_upper_limb_candidate = true
	if positive_segment != null:
		positive_segment.is_lower_limb_candidate = true

	return {
		"upper": negative_segment,
		"lower": positive_segment,
	}

func _resolve_connected_bow_regions(segments: Array[SegmentAtom], material_lookup: Dictionary) -> Dictionary:
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

func _resolve_limb_split_axis(limb_candidates: Array[SegmentAtom], reference_center: Vector3) -> Vector3:
	var axis_scores := {
		Vector3.RIGHT: 0.0,
		Vector3.UP: 0.0,
		Vector3.BACK: 0.0,
	}
	for segment: SegmentAtom in limb_candidates:
		var offset: Vector3 = _get_segment_center(segment) - reference_center
		axis_scores[Vector3.RIGHT] = maxf(float(axis_scores[Vector3.RIGHT]), absf(offset.x))
		axis_scores[Vector3.UP] = maxf(float(axis_scores[Vector3.UP]), absf(offset.y))
		axis_scores[Vector3.BACK] = maxf(float(axis_scores[Vector3.BACK]), absf(offset.z))

	var best_axis: Vector3 = Vector3.RIGHT
	var best_score: float = float(axis_scores[Vector3.RIGHT])
	for axis: Vector3 in axis_scores.keys():
		var axis_score: float = float(axis_scores[axis])
		if axis_score > best_score:
			best_score = axis_score
			best_axis = axis
	return best_axis

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

func _is_valid_bow_string(segment: SegmentAtom, material_lookup: Dictionary) -> bool:
	if segment == null:
		return false
	if maxi(segment.cross_width_voxels, segment.cross_thickness_voxels) != forge_rules.bow_string_required_cross_span_voxels:
		return false
	for cell: CellAtom in segment.member_cells:
		var base_material: BaseMaterialDef = _resolve_base_material_for_cell(cell, material_lookup)
		if base_material == null or not base_material.can_be_bow_string:
			return false
	return true

func _is_limb_candidate(segment: SegmentAtom, material_lookup: Dictionary) -> bool:
	if segment == null:
		return false
	if segment.is_riser_candidate or segment.is_bow_string_candidate:
		return false
	if segment.cross_width_voxels < forge_rules.bow_limb_min_cross_width_voxels or segment.cross_thickness_voxels < forge_rules.bow_limb_min_cross_thickness_voxels:
		return false
	if segment.length_voxels < forge_rules.bow_limb_min_length_voxels:
		return false
	for cell: CellAtom in segment.member_cells:
		var base_material: BaseMaterialDef = _resolve_base_material_for_cell(cell, material_lookup)
		if base_material == null or not base_material.can_be_bow_limb:
			return false
	return true

func _is_valid_limb_segment(segment: SegmentAtom, material_lookup: Dictionary) -> bool:
	if segment == null:
		return false
	if segment.cross_width_voxels < forge_rules.bow_limb_min_cross_width_voxels or segment.cross_thickness_voxels < forge_rules.bow_limb_min_cross_thickness_voxels:
		return false
	if segment.length_voxels < forge_rules.bow_limb_min_length_voxels:
		return false
	for cell: CellAtom in segment.member_cells:
		var base_material: BaseMaterialDef = _resolve_base_material_for_cell(cell, material_lookup)
		if base_material == null or not base_material.can_be_bow_limb:
			return false
	return true

func _calculate_bow_asymmetry_score(upper_flex: float, lower_flex: float) -> float:
	return absf(upper_flex - lower_flex)

func _calculate_limb_flex_score(segment: SegmentAtom, material_lookup: Dictionary) -> float:
	if segment == null or segment.member_cells.is_empty():
		return 0.0
	var flex_supporting_cells: int = 0
	for cell: CellAtom in segment.member_cells:
		var base_material: BaseMaterialDef = _resolve_base_material_for_cell(cell, material_lookup)
		if base_material != null and material_runtime_resolver.has_positive_capability_bias_for_cell(cell, material_lookup, &"cap_flex"):
			flex_supporting_cells += 1
	var material_ratio: float = float(flex_supporting_cells) / float(segment.member_cells.size())
	var geometry_ratio: float = clampf(float(segment.length_voxels) / forge_rules.bow_limb_flex_length_reference_voxels, 0.0, 1.0)
	return material_ratio * geometry_ratio

func _calculate_segments_center(segments: Array[SegmentAtom]) -> Vector3:
	var position_sum: Vector3 = Vector3.ZERO
	var cell_count: int = 0
	for segment: SegmentAtom in segments:
		if segment == null:
			continue
		for cell: CellAtom in segment.member_cells:
			if cell == null:
				continue
			position_sum += cell.get_center_position()
			cell_count += 1
	if cell_count == 0:
		return Vector3.ZERO
	return position_sum / float(cell_count)

func _get_segment_center(segment: SegmentAtom) -> Vector3:
	if segment == null:
		return Vector3.ZERO
	return _calculate_segments_center([segment])

func _resolve_validation_error(
		riser_segment: SegmentAtom,
		upper_limb_valid: bool,
		lower_limb_valid: bool,
		bow_string_valid: bool,
		reference_points: Dictionary
	) -> StringName:
	if riser_segment == null:
		return &"missing_riser"
	if not upper_limb_valid:
		return &"missing_upper_limb"
	if not lower_limb_valid:
		return &"missing_lower_limb"
	if not bow_string_valid:
		return &"missing_bow_string"
	if reference_points.get("projectile_pass_point", Vector3.ZERO).is_equal_approx(Vector3.ZERO):
		return &"missing_projectile_pass_point"
	return &""

func _resolve_base_material_for_cell(cell: CellAtom, material_lookup: Dictionary) -> BaseMaterialDef:
	return material_runtime_resolver.resolve_base_material_for_cell(cell, material_lookup)

func _clear_segment_role_hints(segments: Array[SegmentAtom]) -> void:
	for segment: SegmentAtom in segments:
		if segment == null:
			continue
		segment.is_upper_limb_candidate = false
		segment.is_lower_limb_candidate = false
