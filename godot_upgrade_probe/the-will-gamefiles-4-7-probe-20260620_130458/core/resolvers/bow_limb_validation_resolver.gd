extends RefCounted
class_name BowLimbValidationResolver

const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")

var forge_rules: ForgeRulesDef
var material_runtime_resolver = MaterialRuntimeResolverScript.new()

func _init(rules: ForgeRulesDef = null) -> void:
	forge_rules = rules

func find_riser_segment(
	segments: Array[SegmentAtom],
	calculate_segments_center: Callable,
	get_segment_center: Callable
) -> SegmentAtom:
	var best_segment: SegmentAtom = null
	var best_distance: float = INF
	var reference_center: Vector3 = calculate_segments_center.call(segments)
	for segment: SegmentAtom in segments:
		if segment == null or not segment.is_riser_candidate:
			continue
		var distance_to_center: float = (get_segment_center.call(segment) as Vector3).distance_squared_to(reference_center)
		if distance_to_center < best_distance:
			best_distance = distance_to_center
			best_segment = segment
	return best_segment

func find_bow_string_segment(segments: Array[SegmentAtom]) -> SegmentAtom:
	for segment: SegmentAtom in segments:
		if segment != null and segment.is_bow_string_candidate:
			return segment
	return null

func resolve_limb_pair(
	segments: Array[SegmentAtom],
	material_lookup: Dictionary,
	riser_segment: SegmentAtom,
	calculate_segments_center: Callable,
	get_segment_center: Callable
) -> Dictionary:
	var limb_candidates: Array[SegmentAtom] = []
	for segment: SegmentAtom in segments:
		if _is_limb_candidate(segment, material_lookup):
			limb_candidates.append(segment)

	if limb_candidates.size() < 2:
		return {"upper": null, "lower": null}

	var reference_center: Vector3 = get_segment_center.call(riser_segment) as Vector3
	if reference_center.is_equal_approx(Vector3.ZERO):
		reference_center = calculate_segments_center.call(limb_candidates)
	var split_axis: Vector3 = _resolve_limb_split_axis(limb_candidates, reference_center, get_segment_center)
	var negative_segment: SegmentAtom = null
	var positive_segment: SegmentAtom = null
	var negative_distance: float = -INF
	var positive_distance: float = -INF

	for segment: SegmentAtom in limb_candidates:
		var offset: Vector3 = (get_segment_center.call(segment) as Vector3) - reference_center
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

func is_valid_bow_string(segment: SegmentAtom, material_lookup: Dictionary) -> bool:
	if segment == null:
		return false
	if maxi(segment.cross_width_voxels, segment.cross_thickness_voxels) != forge_rules.bow_string_required_cross_span_voxels:
		return false
	for cell: CellAtom in segment.member_cells:
		var base_material: BaseMaterialDef = _resolve_base_material_for_cell(cell, material_lookup)
		if base_material == null or not base_material.can_be_bow_string:
			return false
	return true

func is_valid_limb_segment(segment: SegmentAtom, material_lookup: Dictionary) -> bool:
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

func calculate_bow_asymmetry_score(upper_flex: float, lower_flex: float) -> float:
	return absf(upper_flex - lower_flex)

func calculate_limb_flex_score(segment: SegmentAtom, material_lookup: Dictionary) -> float:
	if segment == null or segment.member_cells.is_empty():
		return 0.0
	var flex_supporting_cells: int = 0
	for cell: CellAtom in segment.member_cells:
		if material_runtime_resolver.has_positive_capability_bias_for_cell(cell, material_lookup, &"cap_flex"):
			flex_supporting_cells += 1
	var material_ratio: float = float(flex_supporting_cells) / float(segment.member_cells.size())
	var geometry_ratio: float = clampf(float(segment.length_voxels) / forge_rules.bow_limb_flex_length_reference_voxels, 0.0, 1.0)
	return material_ratio * geometry_ratio

func _resolve_limb_split_axis(
	limb_candidates: Array[SegmentAtom],
	reference_center: Vector3,
	get_segment_center: Callable
) -> Vector3:
	var axis_scores := {
		Vector3.RIGHT: 0.0,
		Vector3.UP: 0.0,
		Vector3.BACK: 0.0,
	}
	for segment: SegmentAtom in limb_candidates:
		var offset: Vector3 = (get_segment_center.call(segment) as Vector3) - reference_center
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

func _resolve_base_material_for_cell(cell: CellAtom, material_lookup: Dictionary) -> BaseMaterialDef:
	return material_runtime_resolver.resolve_base_material_for_cell(cell, material_lookup)
