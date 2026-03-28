extends RefCounted
class_name AnchorResolver

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")

var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE

func _init(rules: ForgeRulesDef = null) -> void:
	forge_rules = rules if rules != null else DEFAULT_FORGE_RULES_RESOURCE

func resolve_anchors(segments: Array[SegmentAtom], material_lookup: Dictionary = {}) -> Array[AnchorAtom]:
	return detect_primary_grip_candidates(segments, material_lookup)

func detect_primary_grip_candidates(segments: Array[SegmentAtom], material_lookup: Dictionary) -> Array[AnchorAtom]:
	var anchors: Array[AnchorAtom] = []
	for segment: SegmentAtom in segments:
		if segment == null:
			continue
		if not validate_primary_grip(segment, material_lookup):
			continue
		anchors.append(build_primary_grip_anchor(segment))
	return anchors

func validate_primary_grip(segment: SegmentAtom, _material_lookup: Dictionary) -> bool:
	if segment == null:
		return false
	if not _is_valid_grip_envelope(segment):
		return false
	if not _has_valid_anchor_ratio(segment):
		return false
	if not _has_valid_grip_endcaps(segment):
		return false
	if not _is_grip_safe_profile(segment):
		return false
	if _overlaps_edge_span(segment):
		return false
	# TODO: material_lookup may enforce stricter anchor-material legality once segment ratios and lookup rules are both active.
	return true

func build_primary_grip_anchor(segment: SegmentAtom) -> AnchorAtom:
	var anchor: AnchorAtom = AnchorAtom.new()
	anchor.anchor_id = StringName("primary_grip_%s" % String(segment.segment_id))
	anchor.anchor_type = "primary_grip"
	anchor.local_position = _calculate_segment_center(segment)
	anchor.local_axis = _calculate_segment_axis(segment)
	anchor.span_length = segment.length_voxels
	return anchor

func calculate_primary_grip_offset(center_of_mass: Vector3, grip_position: Vector3) -> Vector3:
	return center_of_mass - grip_position

func _is_valid_grip_envelope(segment: SegmentAtom) -> bool:
	var rules: ForgeRulesDef = forge_rules
	if segment.length_voxels < rules.primary_grip_min_length_voxels:
		return false
	if segment.cross_thickness_voxels < rules.primary_grip_min_thickness_voxels \
			or segment.cross_thickness_voxels > rules.primary_grip_max_thickness_voxels:
		return false
	if segment.cross_width_voxels < rules.primary_grip_min_width_voxels \
			or segment.cross_width_voxels > rules.primary_grip_max_width_voxels:
		return false
	return true

func _has_valid_anchor_ratio(segment: SegmentAtom) -> bool:
	return segment.anchor_material_ratio >= forge_rules.primary_grip_min_anchor_ratio

func _has_valid_grip_endcaps(segment: SegmentAtom) -> bool:
	return segment.start_slice_anchor_valid and segment.end_slice_anchor_valid

func _is_grip_safe_profile(segment: SegmentAtom) -> bool:
	return segment.profile_state == &"square" \
		or segment.profile_state == &"chamfered_hex" \
		or segment.profile_state == &"rounded"

func _overlaps_edge_span(segment: SegmentAtom) -> bool:
	return segment.edge_span_overlap

func _calculate_segment_center(segment: SegmentAtom) -> Vector3:
	if segment.member_cells.is_empty():
		return Vector3.ZERO

	var position_sum: Vector3 = Vector3.ZERO
	for cell: CellAtom in segment.member_cells:
		position_sum += cell.get_center_position()
	return position_sum / float(segment.member_cells.size())

func _calculate_segment_axis(segment: SegmentAtom) -> Vector3:
	var axis: Vector3 = Vector3(segment.major_axis)
	if axis == Vector3.ZERO:
		return Vector3.ZERO
	return axis.normalized()
