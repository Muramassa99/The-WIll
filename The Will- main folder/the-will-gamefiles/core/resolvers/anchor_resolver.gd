extends RefCounted
class_name AnchorResolver

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")
const PrimaryGripSliceProfileLibraryScript = preload("res://core/defs/primary_grip_slice_profile_library.gd")

var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE
var material_runtime_resolver = MaterialRuntimeResolverScript.new()
var valid_grip_slice_mask_lookup: Dictionary = {}

func _init(rules: ForgeRulesDef = null) -> void:
	forge_rules = rules if rules != null else DEFAULT_FORGE_RULES_RESOURCE
	valid_grip_slice_mask_lookup = PrimaryGripSliceProfileLibraryScript.build_valid_mask_lookup()

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

	var slice_lookup: Dictionary = _build_slice_grip_data(segment, material_lookup)
	if slice_lookup.is_empty():
		return grip_spans

	var ordered_slice_indices: Array = slice_lookup.keys()
	ordered_slice_indices.sort()

	var candidates_by_slice: Dictionary = {}
	var candidate_lookup: Dictionary = {}
	var next_candidate_id: int = 0

	for slice_index_value in ordered_slice_indices:
		var slice_index: int = int(slice_index_value)
		var slice_data: Dictionary = slice_lookup.get(slice_index, {})
		var grip_candidates: Array = slice_data.get("grip_candidates", [])
		for candidate: Dictionary in grip_candidates:
			candidate["candidate_id"] = next_candidate_id
			candidate["best_prev_id"] = -1
			candidate["best_length"] = 1
			candidate_lookup[next_candidate_id] = candidate
			next_candidate_id += 1
		candidates_by_slice[slice_index] = grip_candidates

	var previous_slice_index: int = -2147483648
	var previous_candidates: Array = []
	for slice_index_value in ordered_slice_indices:
		var slice_index: int = int(slice_index_value)
		var current_candidates: Array = candidates_by_slice.get(slice_index, [])
		if current_candidates.is_empty():
			previous_candidates.clear()
			previous_slice_index = -2147483648
			continue
		if not previous_candidates.is_empty() and slice_index == previous_slice_index + 1:
			for current_candidate: Dictionary in current_candidates:
				var best_prev_id: int = -1
				var best_prev_length: int = 0
				for previous_candidate: Dictionary in previous_candidates:
					if not _are_grip_slice_candidates_contiguous(previous_candidate, current_candidate):
						continue
					var previous_length: int = int(previous_candidate.get("best_length", 1))
					if previous_length > best_prev_length:
						best_prev_length = previous_length
						best_prev_id = int(previous_candidate.get("candidate_id", -1))
				if best_prev_id >= 0:
					current_candidate["best_prev_id"] = best_prev_id
					current_candidate["best_length"] = best_prev_length + 1
		previous_candidates = current_candidates
		previous_slice_index = slice_index

	var recorded_span_keys: Dictionary = {}
	for slice_index_value in ordered_slice_indices:
		var slice_index: int = int(slice_index_value)
		var current_candidates: Array = candidates_by_slice.get(slice_index, [])
		var next_candidates: Array = candidates_by_slice.get(slice_index + 1, [])
		for candidate: Dictionary in current_candidates:
			if int(candidate.get("best_length", 1)) < forge_rules.primary_grip_min_length_voxels:
				continue
			if _candidate_has_best_successor(candidate, next_candidates):
				continue
			var chain: Array[Dictionary] = _reconstruct_candidate_chain(candidate, candidate_lookup)
			var span: Dictionary = _build_grip_span_from_candidate_chain(chain)
			if span.is_empty():
				continue
			var span_key: String = "%d_%d_%s_%s" % [
				int(span.get("start_index", -1)),
				int(span.get("end_index", -1)),
				str(span.get("start_position", Vector3.ZERO)),
				str(span.get("end_position", Vector3.ZERO)),
			]
			if recorded_span_keys.has(span_key):
				continue
			recorded_span_keys[span_key] = true
			grip_spans.append(span)
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
				"occupied": {},
				"cells_by_coord": {},
				"supporting": {},
			}
		var slice_data: Dictionary = slice_lookup[slice_index]
		var slice_cells: Array = slice_data.get("cells", [])
		slice_cells.append(cell)
		slice_data["cells"] = slice_cells
		var coord: Vector2i = Vector2i(minor_a_value, minor_b_value)
		var occupied: Dictionary = slice_data.get("occupied", {})
		occupied[coord] = true
		slice_data["occupied"] = occupied
		var cells_by_coord: Dictionary = slice_data.get("cells_by_coord", {})
		cells_by_coord[coord] = cell
		slice_data["cells_by_coord"] = cells_by_coord
		if _supports_anchor_for_cell(cell, material_lookup):
			var supporting: Dictionary = slice_data.get("supporting", {})
			supporting[coord] = true
			slice_data["supporting"] = supporting
		slice_lookup[slice_index] = slice_data

	for slice_index_value in slice_lookup.keys():
		var slice_index: int = int(slice_index_value)
		var slice_data: Dictionary = slice_lookup.get(slice_index, {})
		var components: Array[Dictionary] = _resolve_slice_components(slice_data)
		var grip_candidates: Array[Dictionary] = []
		for component: Dictionary in components:
			if _is_grip_eligible_slice_component(component, slice_data):
				component["slice_index"] = slice_index
				grip_candidates.append(component)
		slice_data["components"] = components
		slice_data["grip_candidates"] = grip_candidates
		slice_lookup[slice_index] = slice_data
	return slice_lookup

func _resolve_slice_components(slice_data: Dictionary) -> Array[Dictionary]:
	var components: Array[Dictionary] = []
	var remaining: Dictionary = (slice_data.get("occupied", {}) as Dictionary).duplicate(true)
	var cells_by_coord: Dictionary = slice_data.get("cells_by_coord", {})
	var supporting: Dictionary = slice_data.get("supporting", {})
	while not remaining.is_empty():
		var remaining_keys: Array = remaining.keys()
		if remaining_keys.is_empty():
			break
		var start_coord: Vector2i = remaining_keys[0]
		var stack: Array[Vector2i] = [start_coord]
		var component_positions: Array[Vector2i] = []
		var component_cells: Array = []
		var supporting_count: int = 0
		while not stack.is_empty():
			var current_coord: Vector2i = stack.pop_back()
			if not remaining.has(current_coord):
				continue
			remaining.erase(current_coord)
			component_positions.append(current_coord)
			var cell: CellAtom = cells_by_coord.get(current_coord, null)
			if cell != null:
				component_cells.append(cell)
			if supporting.has(current_coord):
				supporting_count += 1
			for neighbor_coord: Vector2i in _get_neighbor_coords(current_coord, true):
				if remaining.has(neighbor_coord):
					stack.append(neighbor_coord)
		components.append(_build_slice_component(component_cells, component_positions, supporting_count))
	return components

func _build_slice_component(component_cells: Array, component_positions: Array[Vector2i], supporting_count: int) -> Dictionary:
	var component_lookup: Dictionary = {}
	var min_a: int = 2147483647
	var max_a: int = -2147483648
	var min_b: int = 2147483647
	var max_b: int = -2147483648
	for coord: Vector2i in component_positions:
		component_lookup[coord] = true
		min_a = mini(min_a, coord.x)
		max_a = maxi(max_a, coord.x)
		min_b = mini(min_b, coord.y)
		max_b = maxi(max_b, coord.y)
	var count: int = component_positions.size()
	return {
		"cells": component_cells,
		"positions": component_positions,
		"occupied_lookup": component_lookup,
		"count": count,
		"supporting_count": supporting_count,
		"anchor_material_ratio": float(supporting_count) / float(maxi(count, 1)),
		"slice_anchor_valid": count > 0 and supporting_count == count,
		"min_a": min_a if count > 0 else 0,
		"max_a": max_a if count > 0 else -1,
		"min_b": min_b if count > 0 else 0,
		"max_b": max_b if count > 0 else -1,
		"width": (max_a - min_a) + 1 if count > 0 else 0,
		"thickness": (max_b - min_b) + 1 if count > 0 else 0,
		"center_position": _calculate_slice_center(component_cells),
	}

func _is_grip_eligible_slice_component(component: Dictionary, slice_data: Dictionary) -> bool:
	if component.is_empty():
		return false
	if int(component.get("count", 0)) < 4:
		return false
	if float(component.get("anchor_material_ratio", 0.0)) < forge_rules.primary_grip_min_anchor_ratio:
		return false
	if not _is_grip_slice_shape_valid(component):
		return false
	if not _has_slice_component_clearance(component, slice_data.get("occupied", {})):
		return false
	return true

func _is_grip_slice_shape_valid(component: Dictionary) -> bool:
	var positions: Array[Vector2i] = component.get("positions", [])
	if positions.is_empty():
		return false
	var canonical_key: String = PrimaryGripSliceProfileLibraryScript.build_canonical_mask_key_from_positions(positions)
	return not canonical_key.is_empty() and valid_grip_slice_mask_lookup.has(canonical_key)

func _has_slice_component_clearance(component: Dictionary, slice_occupied_lookup: Dictionary) -> bool:
	var occupied_lookup: Dictionary = component.get("occupied_lookup", {})
	var clearance_voxels: int = maxi(forge_rules.primary_grip_slice_clearance_voxels, 1)
	for coord: Vector2i in occupied_lookup.keys():
		for delta_x in range(-clearance_voxels, clearance_voxels + 1):
			for delta_y in range(-clearance_voxels, clearance_voxels + 1):
				if delta_x == 0 and delta_y == 0:
					continue
				if maxi(abs(delta_x), abs(delta_y)) > clearance_voxels:
					continue
				var neighbor_coord: Vector2i = coord + Vector2i(delta_x, delta_y)
				if occupied_lookup.has(neighbor_coord):
					continue
				if slice_occupied_lookup.has(neighbor_coord):
					return false
	return true

func _candidate_has_best_successor(candidate: Dictionary, next_candidates: Array) -> bool:
	var candidate_id: int = int(candidate.get("candidate_id", -1))
	for next_candidate: Dictionary in next_candidates:
		if int(next_candidate.get("best_prev_id", -1)) == candidate_id:
			return true
	return false

func _reconstruct_candidate_chain(candidate: Dictionary, candidate_lookup: Dictionary) -> Array[Dictionary]:
	var chain: Array[Dictionary] = []
	var current_candidate: Dictionary = candidate
	while not current_candidate.is_empty():
		chain.append(current_candidate)
		var previous_id: int = int(current_candidate.get("best_prev_id", -1))
		if previous_id < 0 or not candidate_lookup.has(previous_id):
			break
		current_candidate = candidate_lookup.get(previous_id, {})
	chain.reverse()
	return chain

func _build_grip_span_from_candidate_chain(chain: Array[Dictionary]) -> Dictionary:
	if chain.is_empty():
		return {}
	if chain.size() < forge_rules.primary_grip_min_length_voxels:
		return {}
	var first_candidate: Dictionary = chain.front()
	var last_candidate: Dictionary = chain.back()
	if not bool(first_candidate.get("slice_anchor_valid", false)) or not bool(last_candidate.get("slice_anchor_valid", false)):
		return {}
	var span_anchor_ratio_total: float = 0.0
	var span_centers: Array[Vector3] = []
	for candidate: Dictionary in chain:
		span_anchor_ratio_total += float(candidate.get("anchor_material_ratio", 0.0))
		span_centers.append(candidate.get("center_position", Vector3.ZERO))
	var span_anchor_ratio: float = span_anchor_ratio_total / float(chain.size())
	if span_anchor_ratio < forge_rules.primary_grip_min_anchor_ratio:
		return {}
	return {
		"start_index": int(first_candidate.get("slice_index", -1)),
		"end_index": int(last_candidate.get("slice_index", -1)),
		"span_length": chain.size(),
		"start_position": first_candidate.get("center_position", Vector3.ZERO),
		"end_position": last_candidate.get("center_position", Vector3.ZERO),
		"center_position": _average_positions(span_centers),
		"anchor_material_ratio": span_anchor_ratio,
	}

func _are_grip_slice_candidates_contiguous(previous_candidate: Dictionary, current_candidate: Dictionary) -> bool:
	var previous_positions: Array[Vector2i] = previous_candidate.get("positions", [])
	var current_positions: Array[Vector2i] = current_candidate.get("positions", [])
	if previous_positions.is_empty() or current_positions.is_empty():
		return false
	return _calculate_component_hausdorff_chebyshev_distance(previous_positions, current_positions) <= forge_rules.primary_grip_slice_max_drift_voxels

func _calculate_component_hausdorff_chebyshev_distance(
	source_positions: Array[Vector2i],
	target_positions: Array[Vector2i]
) -> int:
	return maxi(
		_calculate_directed_component_distance(source_positions, target_positions),
		_calculate_directed_component_distance(target_positions, source_positions)
	)

func _calculate_directed_component_distance(
	source_positions: Array[Vector2i],
	target_positions: Array[Vector2i]
) -> int:
	var max_distance: int = 0
	for source_coord: Vector2i in source_positions:
		var nearest_distance: int = 2147483647
		for target_coord: Vector2i in target_positions:
			var chebyshev_distance: int = maxi(abs(source_coord.x - target_coord.x), abs(source_coord.y - target_coord.y))
			nearest_distance = mini(nearest_distance, chebyshev_distance)
		max_distance = maxi(max_distance, nearest_distance)
	return max_distance

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

func _get_neighbor_coords(coord: Vector2i, include_diagonals: bool) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for delta_x in range(-1, 2):
		for delta_y in range(-1, 2):
			if delta_x == 0 and delta_y == 0:
				continue
			if not include_diagonals and abs(delta_x) + abs(delta_y) != 1:
				continue
			neighbors.append(coord + Vector2i(delta_x, delta_y))
	return neighbors

func _get_axis_component(value: Vector3i, axis: Vector3i) -> int:
	if axis == Vector3i.UP:
		return value.y
	if axis == Vector3i.BACK:
		return value.z
	return value.x
