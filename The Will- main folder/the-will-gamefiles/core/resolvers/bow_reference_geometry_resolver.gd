extends RefCounted
class_name BowReferenceGeometryResolver

func resolve_bow_reference_points(
	segments: Array[SegmentAtom],
	riser_segment: SegmentAtom = null,
	upper_limb_segment: SegmentAtom = null,
	lower_limb_segment: SegmentAtom = null,
	explicit_string_anchor_pair: Dictionary = {}
) -> Dictionary:
	var reference_center: Vector3 = get_segment_center(riser_segment)
	if reference_center.is_equal_approx(Vector3.ZERO):
		reference_center = calculate_segments_center(segments)
	var upper_anchor: Vector3 = Vector3.ZERO
	var lower_anchor: Vector3 = Vector3.ZERO
	if bool(explicit_string_anchor_pair.get("valid", false)):
		var endpoint_one_cell: CellAtom = explicit_string_anchor_pair.get("endpoint_one_cell") as CellAtom
		var endpoint_two_cell: CellAtom = explicit_string_anchor_pair.get("endpoint_two_cell") as CellAtom
		var endpoint_one_position: Vector3 = endpoint_one_cell.get_center_position() if endpoint_one_cell != null else Vector3.ZERO
		var endpoint_two_position: Vector3 = endpoint_two_cell.get_center_position() if endpoint_two_cell != null else Vector3.ZERO
		if endpoint_one_position.y >= endpoint_two_position.y:
			upper_anchor = endpoint_one_position
			lower_anchor = endpoint_two_position
		else:
			upper_anchor = endpoint_two_position
			lower_anchor = endpoint_one_position
	if upper_anchor.is_equal_approx(Vector3.ZERO):
		upper_anchor = get_segment_center(upper_limb_segment)
	if lower_anchor.is_equal_approx(Vector3.ZERO):
		lower_anchor = get_segment_center(lower_limb_segment)
	if upper_anchor.is_equal_approx(Vector3.ZERO):
		upper_anchor = reference_center + Vector3.UP
	if lower_anchor.is_equal_approx(Vector3.ZERO):
		lower_anchor = reference_center + Vector3.DOWN
	var projectile_pass_point: Vector3 = reference_center
	if projectile_pass_point.is_equal_approx(Vector3.ZERO):
		projectile_pass_point = (upper_anchor + lower_anchor) * 0.5
	if riser_segment != null and riser_segment.projectile_pass_candidate and not reference_center.is_equal_approx(Vector3.ZERO):
		projectile_pass_point = reference_center
	return {
		"bow_reference_center": reference_center,
		"projectile_pass_point": projectile_pass_point,
		"upper_string_anchor": upper_anchor,
		"lower_string_anchor": lower_anchor,
		"string_anchor_source": (
			&"explicit_authored_pair"
			if bool(explicit_string_anchor_pair.get("valid", false))
			else &"segment_inferred"
		),
		"string_anchor_pair_id": explicit_string_anchor_pair.get("pair_id", StringName()),
	}

func resolve_bow_axes(_reference_center: Vector3) -> Dictionary:
	return {
		"shoot_axis": Vector3.RIGHT,
		"draw_axis": Vector3.BACK,
	}

func calculate_segments_center(segments: Array[SegmentAtom]) -> Vector3:
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

func get_segment_center(segment: SegmentAtom) -> Vector3:
	if segment == null:
		return Vector3.ZERO
	return calculate_segments_center([segment])
