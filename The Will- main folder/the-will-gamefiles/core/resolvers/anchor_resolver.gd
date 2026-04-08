extends RefCounted
class_name AnchorResolver

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")

var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE
var material_runtime_resolver = MaterialRuntimeResolverScript.new()

func _init(rules: ForgeRulesDef = null) -> void:
	forge_rules = rules if rules != null else DEFAULT_FORGE_RULES_RESOURCE

func resolve_anchors(segments: Array[SegmentAtom], material_lookup: Dictionary = {}) -> Array[AnchorAtom]:
	return detect_primary_grip_candidates(segments, material_lookup)

func detect_primary_grip_candidates(segments: Array[SegmentAtom], material_lookup: Dictionary) -> Array[AnchorAtom]:
	var anchors: Array[AnchorAtom] = []
	for segment: SegmentAtom in segments:
		if segment == null:
			continue
		for grip_span: Dictionary in _build_primary_grip_spans(segment, material_lookup):
			anchors.append(build_primary_grip_anchor(segment, grip_span))
	return anchors

func validate_primary_grip(segment: SegmentAtom, material_lookup: Dictionary) -> bool:
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
	return not _build_primary_grip_spans(segment, material_lookup).is_empty()

func build_primary_grip_anchor(segment: SegmentAtom, grip_span: Dictionary = {}) -> AnchorAtom:
	var anchor: AnchorAtom = AnchorAtom.new()
	var span_start_index: int = int(grip_span.get("start_index", 0))
	var span_end_index: int = int(grip_span.get("end_index", maxi(segment.length_voxels - 1, 0)))
	anchor.anchor_id = StringName("primary_grip_%s_%d_%d" % [String(segment.segment_id), span_start_index, span_end_index])
	anchor.anchor_type = "primary_grip"
	anchor.local_position = grip_span.get("center_position", _calculate_segment_center(segment))
	anchor.local_axis = _calculate_segment_axis(segment)
	anchor.span_length = int(grip_span.get("span_length", segment.length_voxels))
	anchor.span_start_local_position = grip_span.get("start_position", anchor.local_position)
	anchor.span_end_local_position = grip_span.get("end_position", anchor.local_position)
	anchor.span_start_index = span_start_index
	anchor.span_end_index = span_end_index
	anchor.span_anchor_material_ratio = float(grip_span.get("anchor_material_ratio", segment.anchor_material_ratio))
	return anchor

func calculate_primary_grip_offset(center_of_mass: Vector3, grip_position: Vector3) -> Vector3:
	return center_of_mass - grip_position

func resolve_primary_grip_contact_position(anchor: AnchorAtom, desired_position: Vector3 = Vector3.ZERO) -> Vector3:
	if anchor == null:
		return Vector3.ZERO
	var span_start: Vector3 = anchor.span_start_local_position
	var span_end: Vector3 = anchor.span_end_local_position
	if span_start.is_equal_approx(span_end):
		return anchor.local_position
	var span_vector: Vector3 = span_end - span_start
	var span_length_squared: float = span_vector.length_squared()
	if span_length_squared <= 0.00001:
		return anchor.local_position
	var projected_ratio: float = (desired_position - span_start).dot(span_vector) / span_length_squared
	return span_start + span_vector * clampf(projected_ratio, 0.0, 1.0)

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

func _build_primary_grip_spans(segment: SegmentAtom, material_lookup: Dictionary) -> Array[Dictionary]:
	var grip_spans: Array[Dictionary] = []
	if segment == null or segment.member_cells.is_empty():
		return grip_spans
	if _overlaps_edge_span(segment):
		return grip_spans

	var slice_lookup: Dictionary = _build_slice_grip_data(segment, material_lookup)
	if slice_lookup.is_empty():
		return grip_spans

	var ordered_slice_indices: Array = slice_lookup.keys()
	ordered_slice_indices.sort()

	var current_span_slices: Array[Dictionary] = []
	var previous_slice_index: int = -2147483648
	for slice_index_value in ordered_slice_indices:
		var slice_index: int = int(slice_index_value)
		var slice_data: Dictionary = slice_lookup.get(slice_index, {})
		if not _is_grip_eligible_slice(slice_data):
			_append_grip_span_if_valid(grip_spans, current_span_slices)
			current_span_slices.clear()
			previous_slice_index = -2147483648
			continue
		if not current_span_slices.is_empty() and slice_index != previous_slice_index + 1:
			_append_grip_span_if_valid(grip_spans, current_span_slices)
			current_span_slices.clear()
		current_span_slices.append(slice_data)
		previous_slice_index = slice_index
	_append_grip_span_if_valid(grip_spans, current_span_slices)
	return grip_spans

func _build_slice_grip_data(segment: SegmentAtom, material_lookup: Dictionary) -> Dictionary:
	var slice_lookup: Dictionary = {}
	for cell: CellAtom in segment.member_cells:
		if cell == null:
			continue
		var slice_index: int = _get_axis_component(cell.grid_position, segment.major_axis)
		var minor_a_value: int = _get_axis_component(cell.grid_position, segment.minor_axis_a)
		var minor_b_value: int = _get_axis_component(cell.grid_position, segment.minor_axis_b)
		if not slice_lookup.has(slice_index):
			slice_lookup[slice_index] = {
				"slice_index": slice_index,
				"cells": [],
				"min_a": minor_a_value,
				"max_a": minor_a_value,
				"min_b": minor_b_value,
				"max_b": minor_b_value,
				"count": 0,
				"occupied": {},
				"anchor_supporting_cells": 0,
			}
		var slice_data: Dictionary = slice_lookup[slice_index]
		var slice_cells: Array = slice_data.get("cells", [])
		slice_cells.append(cell)
		slice_data["cells"] = slice_cells
		slice_data["min_a"] = mini(int(slice_data.get("min_a", minor_a_value)), minor_a_value)
		slice_data["max_a"] = maxi(int(slice_data.get("max_a", minor_a_value)), minor_a_value)
		slice_data["min_b"] = mini(int(slice_data.get("min_b", minor_b_value)), minor_b_value)
		slice_data["max_b"] = maxi(int(slice_data.get("max_b", minor_b_value)), minor_b_value)
		slice_data["count"] = int(slice_data.get("count", 0)) + 1
		var occupied: Dictionary = slice_data.get("occupied", {})
		occupied[Vector2i(minor_a_value, minor_b_value)] = true
		slice_data["occupied"] = occupied
		if _supports_anchor_for_cell(cell, material_lookup):
			slice_data["anchor_supporting_cells"] = int(slice_data.get("anchor_supporting_cells", 0)) + 1
		slice_lookup[slice_index] = slice_data

	for slice_index_value in slice_lookup.keys():
		var slice_index: int = int(slice_index_value)
		var slice_data: Dictionary = slice_lookup.get(slice_index, {})
		var width: int = (int(slice_data.get("max_a", 0)) - int(slice_data.get("min_a", 0))) + 1
		var thickness: int = (int(slice_data.get("max_b", 0)) - int(slice_data.get("min_b", 0))) + 1
		var slice_cells: Array = slice_data.get("cells", [])
		var supporting_cells: int = int(slice_data.get("anchor_supporting_cells", 0))
		var cell_count: int = int(slice_data.get("count", 0))
		slice_data["width"] = width
		slice_data["thickness"] = thickness
		slice_data["profile_state"] = _resolve_slice_profile_state(slice_data)
		slice_data["anchor_material_ratio"] = float(supporting_cells) / float(maxi(cell_count, 1))
		slice_data["slice_anchor_valid"] = not slice_cells.is_empty() and supporting_cells == cell_count
		slice_data["center_position"] = _calculate_slice_center(slice_cells)
		slice_lookup[slice_index] = slice_data
	return slice_lookup

func _is_grip_eligible_slice(slice_data: Dictionary) -> bool:
	if slice_data.is_empty():
		return false
	var rules: ForgeRulesDef = forge_rules
	var width: int = int(slice_data.get("width", 0))
	var thickness: int = int(slice_data.get("thickness", 0))
	if width < rules.primary_grip_min_width_voxels or width > rules.primary_grip_max_width_voxels:
		return false
	if thickness < rules.primary_grip_min_thickness_voxels or thickness > rules.primary_grip_max_thickness_voxels:
		return false
	if float(slice_data.get("anchor_material_ratio", 0.0)) < rules.primary_grip_min_anchor_ratio:
		return false
	if not _is_grip_safe_profile_state(StringName(slice_data.get("profile_state", StringName()))):
		return false
	return true

func _append_grip_span_if_valid(grip_spans: Array[Dictionary], current_span_slices: Array[Dictionary]) -> void:
	if current_span_slices.is_empty():
		return
	if current_span_slices.size() < forge_rules.primary_grip_min_length_voxels:
		return
	var first_slice: Dictionary = current_span_slices.front()
	var last_slice: Dictionary = current_span_slices.back()
	if not bool(first_slice.get("slice_anchor_valid", false)) or not bool(last_slice.get("slice_anchor_valid", false)):
		return
	var span_anchor_ratio_total: float = 0.0
	var span_centers: Array[Vector3] = []
	for slice_data: Dictionary in current_span_slices:
		span_anchor_ratio_total += float(slice_data.get("anchor_material_ratio", 0.0))
		span_centers.append(slice_data.get("center_position", Vector3.ZERO))
	var span_anchor_ratio: float = span_anchor_ratio_total / float(current_span_slices.size())
	if span_anchor_ratio < forge_rules.primary_grip_min_anchor_ratio:
		return
	grip_spans.append({
		"start_index": int(first_slice.get("slice_index", -1)),
		"end_index": int(last_slice.get("slice_index", -1)),
		"span_length": current_span_slices.size(),
		"start_position": first_slice.get("center_position", Vector3.ZERO),
		"end_position": last_slice.get("center_position", Vector3.ZERO),
		"center_position": _average_positions(span_centers),
		"anchor_material_ratio": span_anchor_ratio,
	})

func _resolve_slice_profile_state(slice_data: Dictionary) -> StringName:
	var width: int = (int(slice_data.get("max_a", 0)) - int(slice_data.get("min_a", 0))) + 1
	var thickness: int = (int(slice_data.get("max_b", 0)) - int(slice_data.get("min_b", 0))) + 1
	var expected_cell_count: int = width * thickness
	var occupied_count: int = int(slice_data.get("count", 0))
	if occupied_count == expected_cell_count:
		return &"square"
	if _slice_has_opposing_bevel_pair(slice_data):
		return &"chamfered_hex"
	return &""

func _slice_has_opposing_bevel_pair(slice_data: Dictionary) -> bool:
	var min_a: int = int(slice_data.get("min_a", 0))
	var max_a: int = int(slice_data.get("max_a", 0))
	var min_b: int = int(slice_data.get("min_b", 0))
	var max_b: int = int(slice_data.get("max_b", 0))
	var width: int = (max_a - min_a) + 1
	var thickness: int = (max_b - min_b) + 1
	var expected_cell_count: int = width * thickness
	if width < 3 or thickness < 2:
		return false
	if int(slice_data.get("count", 0)) != expected_cell_count - 2:
		return false
	var occupied: Dictionary = slice_data.get("occupied", {})
	var diagonal_a_missing: bool = not occupied.has(Vector2i(min_a, min_b)) and not occupied.has(Vector2i(max_a, max_b))
	var diagonal_b_missing: bool = not occupied.has(Vector2i(min_a, max_b)) and not occupied.has(Vector2i(max_a, min_b))
	return diagonal_a_missing or diagonal_b_missing

func _is_grip_safe_profile_state(profile_state: StringName) -> bool:
	return profile_state == &"square" \
		or profile_state == &"chamfered_hex" \
		or profile_state == &"rounded"

func _calculate_slice_center(slice_cells: Array) -> Vector3:
	if slice_cells.is_empty():
		return Vector3.ZERO
	var position_sum: Vector3 = Vector3.ZERO
	for cell in slice_cells:
		if cell == null:
			continue
		position_sum += cell.get_center_position()
	return position_sum / float(slice_cells.size())

func _average_positions(positions: Array[Vector3]) -> Vector3:
	if positions.is_empty():
		return Vector3.ZERO
	var position_sum: Vector3 = Vector3.ZERO
	for position: Vector3 in positions:
		position_sum += position
	return position_sum / float(positions.size())

func _supports_anchor_for_cell(cell: CellAtom, material_lookup: Dictionary) -> bool:
	if cell == null:
		return false
	var base_material: BaseMaterialDef = material_runtime_resolver.resolve_base_material_for_cell(cell, material_lookup)
	if base_material == null:
		return false
	return base_material.can_be_anchor_material or base_material.can_be_grip_profile

func _get_axis_component(value: Vector3i, axis: Vector3i) -> int:
	if axis == Vector3i.UP:
		return value.y
	if axis == Vector3i.BACK:
		return value.z
	return value.x
