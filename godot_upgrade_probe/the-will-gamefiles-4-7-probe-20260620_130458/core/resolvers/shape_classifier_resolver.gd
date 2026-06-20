extends RefCounted
class_name ShapeClassifierResolver

func get_pierce_tip_hint_score(segment: SegmentAtom) -> float:
	if segment == null:
		return 0.0

	var slice_metrics: Dictionary = _build_slice_metrics(segment)
	if slice_metrics.is_empty():
		return 0.0

	var slice_indices: Array[int] = []
	for slice_index_value in slice_metrics.keys():
		slice_indices.append(int(slice_index_value))
	slice_indices.sort()
	if slice_indices.size() < 2:
		return 0.0

	var front_tip_score: float = _calculate_tip_score(slice_metrics, slice_indices[0], slice_indices[1])
	var back_tip_score: float = _calculate_tip_score(slice_metrics, slice_indices[slice_indices.size() - 1], slice_indices[slice_indices.size() - 2])
	return maxf(front_tip_score, back_tip_score)

func is_edge_valid_segment(segment: SegmentAtom) -> bool:
	if segment == null:
		return false
	if segment.profile_state != &"beveled_blade":
		return false
	if not segment.has_opposing_bevel_pair:
		return false
	return segment.cross_width_voxels >= 3 and segment.cross_thickness_voxels >= 2

func is_blunt_valid_segment(segment: SegmentAtom) -> bool:
	if segment == null:
		return false
	if is_edge_valid_segment(segment):
		return false
	return maxi(segment.cross_width_voxels, segment.cross_thickness_voxels) >= 3

func get_guard_span_score(segment: SegmentAtom) -> float:
	if segment == null:
		return 0.0
	if segment.cross_width_voxels < 2:
		return 0.0
	if segment.cross_thickness_voxels < 1:
		return 0.0

	var width_score: float = clampf(float(segment.cross_width_voxels) / 4.0, 0.0, 1.0)
	var thickness_score: float = clampf(float(segment.cross_thickness_voxels) / 3.0, 0.0, 1.0)
	return (width_score + thickness_score) * 0.5

func _build_slice_metrics(segment: SegmentAtom) -> Dictionary:
	var slice_metrics: Dictionary = {}
	if segment == null:
		return slice_metrics

	for cell: CellAtom in segment.member_cells:
		if cell == null:
			continue
		var slice_index: int = _get_axis_component(cell.grid_position, segment.major_axis)
		var minor_a_value: int = _get_axis_component(cell.grid_position, segment.minor_axis_a)
		var minor_b_value: int = _get_axis_component(cell.grid_position, segment.minor_axis_b)
		if not slice_metrics.has(slice_index):
			slice_metrics[slice_index] = {
				"min_a": minor_a_value,
				"max_a": minor_a_value,
				"min_b": minor_b_value,
				"max_b": minor_b_value,
				"count": 0,
			}

		var metric: Dictionary = slice_metrics[slice_index]
		metric["min_a"] = mini(int(metric.get("min_a", minor_a_value)), minor_a_value)
		metric["max_a"] = maxi(int(metric.get("max_a", minor_a_value)), minor_a_value)
		metric["min_b"] = mini(int(metric.get("min_b", minor_b_value)), minor_b_value)
		metric["max_b"] = maxi(int(metric.get("max_b", minor_b_value)), minor_b_value)
		metric["count"] = int(metric.get("count", 0)) + 1
		slice_metrics[slice_index] = metric

	return slice_metrics

func _calculate_tip_score(slice_metrics: Dictionary, tip_slice_index: int, neighbor_slice_index: int) -> float:
	var tip_metric: Dictionary = slice_metrics.get(tip_slice_index, {})
	var neighbor_metric: Dictionary = slice_metrics.get(neighbor_slice_index, {})
	if tip_metric.is_empty() or neighbor_metric.is_empty():
		return 0.0

	var tip_width: int = _get_metric_width(tip_metric)
	var tip_thickness: int = _get_metric_thickness(tip_metric)
	var tip_area: int = int(tip_metric.get("count", 0))
	var neighbor_area: int = int(neighbor_metric.get("count", 0))
	if tip_width > 2 or tip_thickness > 2:
		return 0.0
	if tip_area > 2:
		return 0.0
	if neighbor_area <= tip_area:
		return 0.0

	var narrowness_score: float = 1.0 - clampf(float(maxi(tip_width, tip_thickness) - 1), 0.0, 1.0)
	var taper_score: float = clampf(float(neighbor_area - tip_area) / maxf(float(neighbor_area), 1.0), 0.0, 1.0)
	return (narrowness_score + taper_score) * 0.5

func _get_metric_width(metric: Dictionary) -> int:
	return (int(metric.get("max_a", 0)) - int(metric.get("min_a", 0))) + 1

func _get_metric_thickness(metric: Dictionary) -> int:
	return (int(metric.get("max_b", 0)) - int(metric.get("min_b", 0))) + 1

func _get_axis_component(value: Vector3i, axis: Vector3i) -> int:
	if axis == Vector3i.UP:
		return value.y
	if axis == Vector3i.BACK:
		return value.z
	return value.x